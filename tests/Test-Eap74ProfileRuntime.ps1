#requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $root 'scripts/HarnessJbossRuntime.psm1') -Force -DisableNameChecking
$module=Get-Module HarnessJbossRuntime
function Assert($ok,$message) { if (-not $ok) { throw $message } }
$area=Join-Path $root ('.harness/tests/profile-runtime-'+[guid]::NewGuid().ToString('N').Substring(0,8))
$eap=Join-Path $area 'eap local'
$null=[IO.Directory]::CreateDirectory((Join-Path $eap 'bin'))
@'
@echo off
setlocal
if not defined STANDALONE_CONF set "STANDALONE_CONF=%JBOSS_HOME%\bin\standalone.conf.bat"
call "%STANDALONE_CONF%"
echo OPTIONS=%JAVA_OPTS%
echo ARGS=%*
echo DEBUG_BIND=%DEBUG_PORT%
exit /b 0
'@ | Set-Content -LiteralPath (Join-Path $eap 'bin/standalone.bat') -Encoding ASCII
$globalJvm=Join-Path $eap 'bin/standalone.conf.bat'
Set-Content -LiteralPath $globalJvm 'set "JAVA_OPTS=-Dfixture.cor=legado"' -Encoding ASCII
$beforeGlobal=(Get-FileHash $globalJvm).Hash
foreach ($name in @('azul','verde')) {
    @(('rem EAP74 PREPARO CONFIG='+$name+'.xml'),'rem BEGIN EAP74 PREPARO JVM','set "JAVA_HOME=C:\jdk8"',('set "JAVA_OPTS=-Dfixture.cor='+$name+'"'),'rem END EAP74 PREPARO') |
        Set-Content -LiteralPath (Join-Path $eap ('bin/eap74-preparo-'+$name+'.conf.bat')) -Encoding ASCII
}
$oldConf=$env:STANDALONE_CONF
try {
    $env:STANDALONE_CONF='conf-herdada-indevida'
    foreach ($name in @('azul','verde','legado')) {
        foreach ($debug in @($false,$true)) {
            $run=Join-Path $area ($name+'-'+$debug)
            $null=[IO.Directory]::CreateDirectory($run)
            $server=[pscustomobject]@{Home=$eap;Base=(Join-Path $eap 'standalone');Jdk='c:\JDK8';Version='7.4';Settings=[pscustomobject]@{standaloneConfig=($name+'.xml');portOffset=100;debugPort=8799}}
            $process=& $module {param($s,$r,$d) Start-JbossProcess $s $r -DebugMode:$d} $server $run $debug
            try { Assert ($process.WaitForExit(10000)) 'Launcher simulado nao encerrou.' } finally { $process.Dispose() }
            $output=Get-Content -LiteralPath (Join-Path $run 'stdout.log') -Raw
            Assert ($output.Contains('OPTIONS=-Dfixture.cor='+$name)) ('JVM incorreta no inicio do perfil '+$name)
            Assert ($output.Contains('-c '+$name+'.xml')) 'Inicio perdeu o XML selecionado.'
            if ($debug) { Assert ($output.Contains('--debug 8799') -and $output.Contains('DEBUG_BIND=127.0.0.1:8799')) 'Debug perdeu porta/bind local.' }
            else { Assert (-not $output.Contains('--debug')) 'Inicio normal ativou debug.' }
            Assert ($env:STANDALONE_CONF -ceq 'conf-herdada-indevida') 'Inicio nao restaurou ambiente do processo pai.'
        }
    }
} finally { $env:STANDALONE_CONF=$oldConf }
Assert ((Get-FileHash $globalJvm).Hash -ceq $beforeGlobal) 'Runtime alterou JVM global.'
# Um JAVA_HOME humano anterior nao pode mascarar divergencia no bloco efetivo.
$profileJvm=Join-Path $eap 'bin/eap74-preparo-azul.conf.bat'
$text=[IO.File]::ReadAllText($profileJvm)
[IO.File]::WriteAllText($profileJvm,('set "JAVA_HOME=C:\jdk8"'+"`r`n"+$text.Replace('JAVA_HOME=C:\jdk8','JAVA_HOME=C:\outro-jdk')))
$failure=$null
try { $null=& $module {param($path) Resolve-HarnessJbossJvmConfig $path 'azul.xml' 'C:\jdk8'} $eap } catch { $failure=$_ }
Assert ($null -ne $failure -and $failure.Exception.Message -match 'JDK') 'JAVA_HOME fora do bloco mascarou JDK divergente.'
Write-Output 'PASS: inicio normal/debug seleciona JVM por XML e preserva fallback legado.'
