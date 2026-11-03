#requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $root 'doc/estrategia-migracao-ambientes-jboss-eap-7.4/jboss-eap7.4-configuracao/scripts/Eap74Preparation.psm1') -Force -DisableNameChecking
$module=Get-Module Eap74Preparation
function Assert($ok,[string]$message) { if (-not $ok) { throw $message } }
function Write-File([string]$path,[string]$text) {
    $null=[IO.Directory]::CreateDirectory((Split-Path -Parent $path))
    [IO.File]::WriteAllText($path,$text,(New-Object Text.UTF8Encoding $false))
}
function Reject([scriptblock]$action,[string]$reason) {
    $errorRecord=$null
    try { $null=& $action } catch { $errorRecord=$_ }
    Assert ($null -ne $errorRecord) ('Operacao deveria falhar: '+$reason)
    Assert ($errorRecord.Exception.Message -match $reason) ('Motivo inesperado: '+$errorRecord.Exception.Message)
}
$area=Join-Path $root ('.harness/tests/profiles-'+[guid]::NewGuid().ToString('N').Substring(0,8))
$eap=Join-Path $area 'eap destino'
$jdk=Join-Path $area 'jdk 8'
$configPath=Join-Path $area 'preparo.json'
Write-File (Join-Path $eap 'version.txt') 'JBoss EAP - Version 7.4.11.GA'
Write-File (Join-Path $eap 'bin/standalone.bat') '@echo fixture'
Write-File (Join-Path $eap 'bin/standalone.conf.bat') '@rem configuracao humana global'
Write-File (Join-Path $jdk 'release') 'JAVA_VERSION="1.8.0_442"'
Write-File (Join-Path $jdk 'bin/java.exe') 'nao executar'
Write-File (Join-Path $area 'modulos.json') '{"modules":[]}'
$config=[ordered]@{schemaVersion=2;eapHome=$eap;jdkHome=$jdk;expectedVersion='7.4.11.GA';modules='modulos.json';files=@();portOffset=100;logSql=$false;profiles=[ordered]@{}}
foreach ($name in @('azul','verde')) {
    Write-File (Join-Path $area ($name+'/template.xml')) '<server xmlns="urn:jboss:domain:16.0"><system-properties><property name="cor" value="__COR__" /></system-properties></server>'
    Write-File (Join-Path $area ($name+'/valores.properties')) ('__COR__='+$name)
    Write-File (Join-Path $area ($name+'/jvm.txt')) ('-Dfixture.cor='+$name)
    $config.profiles[$name]=[ordered]@{standaloneConfig=($name+'.xml');template=($name+'/template.xml');values=($name+'/valores.properties');jvmOptions=($name+'/jvm.txt');output=('saida/'+$name)}
}
function Save-Config { Write-File $configPath ($config | ConvertTo-Json -Depth 8) }
Save-Config
& $module { function script:Assert-EapStopped { param($Config) } }

# Selecionar apenas um perfil; nenhuma escrita no servidor ao gerar.
$beforeGlobal=(Get-FileHash (Join-Path $eap 'bin/standalone.conf.bat')).Hash
$result=Invoke-EapPreparation -ConfigPath $configPath -Profile azul
$blueXml=Join-Path $area 'saida/azul/standalone/configuration/azul.xml'
Assert ([IO.File]::ReadAllText($blueXml).Contains('value="azul"')) 'Perfil azul usou valores de outro perfil.'
Assert ($result.Profile -ceq 'azul') 'Resultado nao informa o perfil selecionado.'
Assert (-not (Test-Path (Join-Path $area 'saida/verde'))) 'Geracao publicou outro perfil.'
$blueHash=(Get-FileHash $blueXml).Hash
$null=Invoke-EapPreparation -ConfigPath $configPath -Profile verde
Assert ([IO.File]::ReadAllText((Join-Path $area 'saida/verde/standalone/configuration/verde.xml')).Contains('value="verde"')) 'Perfil verde usou valores incorretos.'
Assert ((Get-FileHash $blueXml).Hash -ceq $blueHash) 'Geracao alterou saida de outro perfil.'
Assert ((Get-FileHash (Join-Path $eap 'bin/standalone.conf.bat')).Hash -ceq $beforeGlobal) 'Geracao alterou JVM instalada.'

Reject { Invoke-EapPreparation -ConfigPath $configPath } 'Perfil|Profile'
Reject { Invoke-EapPreparation -ConfigPath $configPath -Profile inexistente } 'inexistente|disponiveis'
$originalConfig=$config | ConvertTo-Json -Depth 8
foreach ($problem in @('xml-repetido','saida-dentro-outra','saida-entrada-outra','campo-compartilhado','perfil-incompleto','arquivo-sobre-outro-xml','jar-dentro-saida')) {
    $bad=$originalConfig | ConvertFrom-Json
    switch ($problem) {
        'xml-repetido' { $bad.profiles.verde.standaloneConfig='AZUL.xml' }
        'saida-dentro-outra' { $bad.profiles.verde.output='saida/azul/filho' }
        'saida-entrada-outra' { $bad.profiles.verde.output='azul' }
        'campo-compartilhado' { $bad.profiles.verde | Add-Member modules 'outro.json' }
        'perfil-incompleto' { $bad.profiles.verde.PSObject.Properties.Remove('values') }
        'arquivo-sobre-outro-xml' { $bad.files=@(@{source='azul/template.xml';target='VERDE.xml'}) }
        'jar-dentro-saida' {
            Write-File (Join-Path $area 'manifesto-invalido.json') '{"modules":[{"artifacts":[{"source":"file","path":"saida/verde/modulo.jar"}]}]}'
            $bad.modules='manifesto-invalido.json'
        }
    }
    Write-File $configPath ($bad | ConvertTo-Json -Depth 8)
    Reject { Invoke-EapPreparation -ConfigPath $configPath -Profile azul } 'perfil|profiles|saida|XML|campo|output'
    Assert ((Get-FileHash $blueXml).Hash -ceq $blueHash) ('Validacao tardia modificou saida: '+$problem)
}
Save-Config

# Instalar os perfis nao pode modificar a JVM global que outro servidor ja usa.
foreach ($name in @('azul','verde')) { $null=Invoke-EapPreparation -ConfigPath $configPath -Profile $name -Apply }
Assert ((Get-FileHash (Join-Path $eap 'bin/standalone.conf.bat')).Hash -ceq $beforeGlobal) 'Aplicar perfil modificou JVM global existente.'
foreach ($name in @('azul','verde')) {
    $jvmFile=Join-Path $eap ('bin/eap74-preparo-'+$name+'.conf.bat')
    Assert ([IO.File]::ReadAllText($jvmFile).Contains('-Dfixture.cor='+$name)) 'JVM instalada nao corresponde ao XML.'
}

# O BAT sintetico segue a escolha STANDALONE_CONF feita pelo launcher real.
Write-File (Join-Path $eap 'bin/standalone.bat') @'
@echo off
setlocal
if not defined STANDALONE_CONF set "STANDALONE_CONF=%JBOSS_HOME%\bin\standalone.conf.bat"
call "%STANDALONE_CONF%"
echo ARGS=%*
echo OPTIONS=%JAVA_OPTS%
exit /b 0
'@
$installedBlue=Join-Path $eap 'standalone/configuration/azul.xml'
$withDeployment=[IO.File]::ReadAllText($installedBlue).Replace('</server>','<deployments><deployment name="manual.war" runtime-name="manual.war"><content sha1="1234567890123456789012345678901234567890" /></deployment></deployments></server>')
Write-File $installedBlue $withDeployment
$installedHash=(Get-FileHash $installedBlue).Hash
$oldConf=$env:STANDALONE_CONF
try {
    $env:STANDALONE_CONF='heranca-a-restaurar'
    foreach ($name in @('azul','verde','azul')) {
        $lines=@(Start-EapPrepared -ConfigPath $configPath -Profile $name)
        $captured=$lines -join "`n"
        Assert ($captured.Contains('-c '+$name+'.xml')) 'Inicio perdeu selecao do XML.'
        Assert ($captured.Contains('-Dfixture.cor='+$name)) 'Inicio usou JVM de outro perfil.'
        Assert ($env:STANDALONE_CONF -ceq 'heranca-a-restaurar') 'Inicio nao restaurou ambiente do pai.'
        Assert ((Get-FileHash $installedBlue).Hash -ceq $installedHash) 'Alternancia apagou deployment da CLI.'
        Assert ((Get-FileHash (Join-Path $eap 'bin/standalone.conf.bat')).Hash -ceq $beforeGlobal) 'Inicio alterou JVM global.'
    }
} finally { $env:STANDALONE_CONF=$oldConf }

# Reaplicar template divergente e uma escolha explicita, nunca efeito do start.
Reject { Invoke-EapPreparation -ConfigPath $configPath -Profile azul -Apply } 'SubstituirXml|ReplaceXml'
Assert ((Get-FileHash $installedBlue).Hash -ceq $installedHash) 'Reaplicacao recusada alterou XML instalado.'
Reject { Invoke-EapPreparation -ConfigPath $configPath -Profile azul -ReplaceXml } 'Aplicar|Apply'
$null=Invoke-EapPreparation -ConfigPath $configPath -Profile azul -Apply -ReplaceXml
Assert (-not [IO.File]::ReadAllText($installedBlue).Contains('manual.war')) 'Substituicao explicita nao publicou o template.'

Write-File (Join-Path $area 'verde/jvm.txt') '-Dfixture.cor=alterada'
Reject { Start-EapPrepared -ConfigPath $configPath -Profile verde } 'JVM|opcoes'
Write-File (Join-Path $area 'verde/jvm.txt') '-Dfixture.cor=verde'
$greenJvm=Join-Path $eap 'bin/eap74-preparo-verde.conf.bat'
$greenText=[IO.File]::ReadAllText($greenJvm)
Write-File $greenJvm ($greenText.Replace('CONFIG=verde.xml','CONFIG=azul.xml'))
Reject { Start-EapPrepared -ConfigPath $configPath -Profile verde } 'associacao|XML'
Write-File $greenJvm $greenText

# Adotar um XML legado em v2 nao exige reaplica-lo: JVM global compativel basta.
$legacyConfig=[ordered]@{schemaVersion=1}
foreach ($field in @('eapHome','jdkHome','expectedVersion','modules','files','portOffset','logSql')) { $legacyConfig[$field]=$config[$field] }
foreach ($field in @('standaloneConfig','template','values','jvmOptions','output')) { $legacyConfig[$field]=$config.profiles.azul[$field] }
$legacyConfig.standaloneConfig='legado.xml'; $legacyConfig.output='saida/legado'
Write-File $configPath ($legacyConfig | ConvertTo-Json -Depth 8)
$null=Invoke-EapPreparation -ConfigPath $configPath -Apply
$legacyXml=Join-Path $eap 'standalone/configuration/legado.xml'
$legacyHash=(Get-FileHash $legacyXml).Hash
$legacyGlobal=(Get-FileHash (Join-Path $eap 'bin/standalone.conf.bat')).Hash
$config.profiles.azul.standaloneConfig='legado.xml'
Save-Config
$adopted=@(Start-EapPrepared -ConfigPath $configPath -Profile azul) -join "`n"
Assert ($adopted.Contains('-c legado.xml') -and $adopted.Contains('-Dfixture.cor=azul')) 'Adocao v2 nao usou XML/JVM legados compativeis.'
Assert ((Get-FileHash $legacyXml).Hash -ceq $legacyHash -and (Get-FileHash (Join-Path $eap 'bin/standalone.conf.bat')).Hash -ceq $legacyGlobal) 'Adocao modificou instalacao legada.'
Assert (-not (Test-Path (Join-Path $eap 'bin/eap74-preparo-legado.conf.bat'))) 'Adocao instalou JVM sem Apply.'

# Um JSON antigo nao deve reaplicar a JVM global por cima de uma associacao v2.
$legacyConfig.standaloneConfig='verde.xml'
Write-File $configPath ($legacyConfig | ConvertTo-Json -Depth 8)
Reject { Invoke-EapPreparation -ConfigPath $configPath -Apply } 'perfil|v2'
Write-Output 'PASS: perfis genericos, saidas isoladas, JVM por XML, alternancia e preservacao de deployments.'
if ($PSVersionTable.PSVersion.Major -eq 5) {
    $pwsh=Get-Command pwsh.exe -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($pwsh) {
        & $pwsh.Source -NoProfile -NonInteractive -File $PSCommandPath
        Assert ($LASTEXITCODE -eq 0) 'Suite de perfis falhou em PowerShell 7.'
    }
}
