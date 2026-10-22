#requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
. $PSScriptRoot/Eap74Inputs.ps1
. $PSScriptRoot/Eap74Modules.ps1
. $PSScriptRoot/Eap74Publication.ps1

function Invoke-EapPreparation {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$ConfigPath,[switch]$Apply,[switch]$LogSql)
    $config=Read-EapPreparationConfig $ConfigPath
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
        [IO.File]::WriteAllText((Join-Path $stage 'bin/standalone.conf.bat'),$jvm,(New-Object Text.UTF8Encoding $false))
        $modules=@(New-EapModules $config $stage)
        Assert-EapModulesCompatible $config $stage $modules
        Assert-EapOwnedOutput $config.output
        $receipt=[ordered]@{schemaVersion=1;files=(Get-EapTreeFiles $stage)}
        [IO.File]::WriteAllText((Join-Path $stage '.eap-preparo.json'),($receipt | ConvertTo-Json -Depth 5),(New-Object Text.UTF8Encoding $false))
        Assert-EapStopped $config
        if (Test-Path -LiteralPath $config.output) { [IO.Directory]::Move($config.output,$previous); $saved=$true }
        [IO.Directory]::Move($stage,$config.output); $published=$true
        if ($Apply) {
            Assert-EapStopped $config
            Assert-EapModulesCompatible $config $config.output $modules
            Publish-EapTarget $config $config.output $modules
        }
    } catch {
        if ($published) { [IO.Directory]::Move($config.output,$stage) }
        if ($saved) { [IO.Directory]::Move($previous,$config.output); $saved=$false }
        throw
    } finally {
        Remove-EapStage $stage $parent
        if ($saved) { Remove-EapStage $previous $parent }
    }
    [pscustomobject]@{Output=$config.output;Applied=$Apply.IsPresent;StandaloneConfig=$config.standaloneConfig;Modules=$modules.Count;LogSql=($LogSql.IsPresent -or $config.logSql)}
}

function Start-EapPrepared {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$ConfigPath,[switch]$AdminOnly)
    $config=Read-EapPreparationConfig $ConfigPath
    Assert-EapStopped $config
    $xml=Join-Path $config.eapHome ('standalone/configuration/'+$config.standaloneConfig)
    if (-not [IO.File]::Exists($xml)) { throw 'XML preparado ausente no servidor. Execute o preparo com -Aplicar primeiro.' }
    $null=ConvertTo-EapXmlDocument ([IO.File]::ReadAllText($xml))
    if ([IO.File]::ReadAllText((Join-Path $config.eapHome 'bin/standalone.conf.bat')) -notmatch 'rem BEGIN EAP74 PREPARO JVM') { throw 'Configuracao JVM compartilhada ausente. Execute o preparo com -Aplicar primeiro.' }
    if (-not [IO.File]::ReadAllText((Join-Path $config.eapHome 'bin/standalone.conf.bat')).Contains('set "JAVA_HOME='+$config.jdkHome+'"')) { throw 'JDK configurado difere do preparo instalado. Confira o ambiente e aplique o preparo com o servidor parado.' }
    $variables=@('JAVA_HOME','JAVA','JAVA_OPTS','JAVA_TOOL_OPTIONS','_JAVA_OPTIONS','JDK_JAVA_OPTIONS','JBOSS_HOME','JBOSS_BASE_DIR','JBOSS_CONFIG_DIR','JBOSS_LOG_DIR','STANDALONE_CONF','DEBUG','DEBUG_PORT','NOPAUSE')
    $before=@{}
    foreach ($name in $variables) { $before[$name]=[Environment]::GetEnvironmentVariable($name,'Process'); [Environment]::SetEnvironmentVariable($name,$null,'Process') }
    try {
        $env:JAVA_HOME=$config.jdkHome; $env:JBOSS_HOME=$config.eapHome; $env:JBOSS_BASE_DIR=Join-Path $config.eapHome 'standalone'; $env:NOPAUSE='true'
        $arguments=@(('-Djboss.server.base.dir='+$env:JBOSS_BASE_DIR),'-c',$config.standaloneConfig,'-b=127.0.0.1','-bmanagement=127.0.0.1',('-Djboss.socket.binding.port-offset='+$config.portOffset))
        if ($AdminOnly) { $arguments+='--admin-only' }
        & (Join-Path $config.eapHome 'bin/standalone.bat') @arguments
        if ($LASTEXITCODE -ne 0) { throw "JBoss terminou com codigo $LASTEXITCODE. Consulte o log do servidor." }
    } finally { foreach ($name in $variables) { [Environment]::SetEnvironmentVariable($name,$before[$name],'Process') } }
}
Export-ModuleMember -Function Invoke-EapPreparation,Start-EapPrepared
