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
foreach ($problem in @('xml-repetido','saida-dentro-outra','saida-entrada-outra','campo-compartilhado','perfil-incompleto')) {
    $bad=$originalConfig | ConvertFrom-Json
    switch ($problem) {
        'xml-repetido' { $bad.profiles.verde.standaloneConfig='AZUL.xml' }
        'saida-dentro-outra' { $bad.profiles.verde.output='saida/azul/filho' }
        'saida-entrada-outra' { $bad.profiles.verde.output='azul' }
        'campo-compartilhado' { $bad.profiles.verde | Add-Member modules 'outro.json' }
        'perfil-incompleto' { $bad.profiles.verde.PSObject.Properties.Remove('values') }
    }
    Write-File $configPath ($bad | ConvertTo-Json -Depth 8)
    Reject { Invoke-EapPreparation -ConfigPath $configPath -Profile azul } 'perfil|profiles|saida|XML|campo|output'
    Assert ((Get-FileHash $blueXml).Hash -ceq $blueHash) ('Validacao tardia modificou saida: '+$problem)
}
Save-Config
Write-Output 'PASS: perfis genericos, selecao, saidas isoladas e validacao antes de escrita.'
