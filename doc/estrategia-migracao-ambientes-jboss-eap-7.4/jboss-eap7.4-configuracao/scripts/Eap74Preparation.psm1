#requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot '../../../../scripts/HarnessJbossConfig.psm1') -DisableNameChecking
. $PSScriptRoot/Eap74Inputs.ps1
. $PSScriptRoot/Eap74Profiles.ps1
. $PSScriptRoot/Eap74Modules.ps1
. $PSScriptRoot/Eap74Publication.ps1
. $PSScriptRoot/Eap74Files.ps1

function Invoke-EapPreparation {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$ConfigPath,[switch]$Apply,[switch]$LogSql,[string]$Profile,[switch]$ReplaceXml)
    if ($ReplaceXml -and -not $Apply) { throw '-SubstituirXml exige -Aplicar (ReplaceXml exige Apply).' }
    $config=Read-EapPreparationConfig $ConfigPath $Profile
    if ($Apply -and $config.schemaVersion -eq 1 -and (Test-Path -LiteralPath (Join-Path $config.eapHome ('bin/'+(Get-HarnessJbossJvmFileName $config.standaloneConfig))))) { throw 'XML ja possui JVM por perfil. Use o preparo v2 para atualizar essa configuracao.' }
    Assert-EapStopped $config
    Assert-EapPlainPath $config.output
    $xml=New-EapXml $config ($LogSql.IsPresent -or $config.logSql)
    $jvm=New-EapJvmConfig $config
    $parent=Split-Path -Parent $config.output
    $stage=Join-Path $parent ('.eap-preparo-'+[guid]::NewGuid().ToString('N'))
    $previous=Join-Path $parent ('.eap-preparo-'+[guid]::NewGuid().ToString('N'))
    $published=$false; $saved=$false
    try {
        $null=[IO.Directory]::CreateDirectory((Join-Path $stage 'standalone/configuration'))
        $null=[IO.Directory]::CreateDirectory((Join-Path $stage 'bin'))
        [IO.File]::WriteAllText((Join-Path $stage ('standalone/configuration/'+$config.standaloneConfig)),$xml,(New-Object Text.UTF8Encoding $false))
        [IO.File]::WriteAllText((Join-Path $stage $config.JvmRelativePath),$jvm,(New-Object Text.UTF8Encoding $false))
        $modules=@(New-EapModules $config $stage)
        $files=@(New-EapFiles $config $stage)
        Assert-EapModulesCompatible $config $stage $modules
        Assert-EapFilesCompatible $config $stage $files
        Assert-EapOwnedOutput $config.output
        $receipt=[ordered]@{schemaVersion=1;files=(Get-EapTreeFiles $stage)}
        [IO.File]::WriteAllText((Join-Path $stage '.eap-preparo.json'),($receipt | ConvertTo-Json -Depth 5),(New-Object Text.UTF8Encoding $false))
        Assert-EapStopped $config
        if (Test-Path -LiteralPath $config.output) { [IO.Directory]::Move($config.output,$previous); $saved=$true }
        [IO.Directory]::Move($stage,$config.output); $published=$true
        if ($Apply) {
            Assert-EapStopped $config
            Assert-EapModulesCompatible $config $config.output $modules
            Assert-EapFilesCompatible $config $config.output $files
            Publish-EapTarget $config $config.output $modules $files -ReplaceXml:$ReplaceXml
        }
    } catch {
        if ($published) { [IO.Directory]::Move($config.output,$stage) }
        if ($saved) { [IO.Directory]::Move($previous,$config.output); $saved=$false }
        throw
    } finally {
        Remove-EapStage $stage $parent
        if ($saved) { Remove-EapStage $previous $parent }
    }
    [pscustomobject]@{Profile=$config.Profile;Output=$config.output;Applied=$Apply.IsPresent;StandaloneConfig=$config.standaloneConfig;JvmConfig=$config.JvmRelativePath;Modules=$modules.Count;Files=$files.Count;LogSql=($LogSql.IsPresent -or $config.logSql)}
}

function Start-EapPrepared {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$ConfigPath,[switch]$AdminOnly,[string]$Profile)
    $config=Read-EapPreparationConfig $ConfigPath $Profile
    Assert-EapStopped $config
    $xml=Join-Path $config.eapHome ('standalone/configuration/'+$config.standaloneConfig)
    if (-not [IO.File]::Exists($xml)) { throw 'XML preparado ausente no servidor. Execute o preparo com -Aplicar primeiro.' }
    $null=ConvertTo-EapXmlDocument ([IO.File]::ReadAllText($xml))
    $jvmPath=Resolve-HarnessJbossJvmConfig $config.eapHome $config.standaloneConfig $config.jdkHome
    $installed=[regex]::Matches([IO.File]::ReadAllText($jvmPath),'(?ms)^rem BEGIN EAP74 PREPARO JVM\r?\n.*?^rem END EAP74 PREPARO')
    $expected=[regex]::Match((New-EapJvmConfig $config),'(?ms)^rem BEGIN EAP74 PREPARO JVM\r?\n.*?^rem END EAP74 PREPARO').Value
    if ($installed.Count -ne 1 -or $installed[0].Value.Replace("`r`n","`n") -cne $expected.Replace("`r`n","`n")) { throw 'JVM instalada difere das opcoes/JDK do preparo. Confira e aplique com o servidor parado.' }
    $variables=@('JAVA_HOME','JAVA','JAVA_OPTS','JAVA_TOOL_OPTIONS','_JAVA_OPTIONS','JDK_JAVA_OPTIONS','JBOSS_HOME','JBOSS_BASE_DIR','JBOSS_CONFIG_DIR','JBOSS_LOG_DIR','STANDALONE_CONF','DEBUG','DEBUG_PORT','NOPAUSE')
    $before=@{}
    foreach ($name in $variables) { $before[$name]=[Environment]::GetEnvironmentVariable($name,'Process'); [Environment]::SetEnvironmentVariable($name,$null,'Process') }
    try {
        $env:JAVA_HOME=$config.jdkHome; $env:JBOSS_HOME=$config.eapHome; $env:JBOSS_BASE_DIR=Join-Path $config.eapHome 'standalone'; $env:NOPAUSE='true'
        if ($config.schemaVersion -eq 2 -or $jvmPath -ine (Join-Path $config.eapHome 'bin/standalone.conf.bat')) { $env:STANDALONE_CONF=$jvmPath }
        $arguments=@(('-Djboss.server.base.dir='+$env:JBOSS_BASE_DIR),'-c',$config.standaloneConfig,'-b=127.0.0.1','-bmanagement=127.0.0.1',('-Djboss.socket.binding.port-offset='+$config.portOffset))
        if ($AdminOnly) { $arguments+='--admin-only' }
        & (Join-Path $config.eapHome 'bin/standalone.bat') @arguments
        if ($LASTEXITCODE -ne 0) { throw "JBoss terminou com codigo $LASTEXITCODE. Consulte o log do servidor." }
    } finally { foreach ($name in $variables) { [Environment]::SetEnvironmentVariable($name,$before[$name],'Process') } }
}
Export-ModuleMember -Function Invoke-EapPreparation,Start-EapPrepared
