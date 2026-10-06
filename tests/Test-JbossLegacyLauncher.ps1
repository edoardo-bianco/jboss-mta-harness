#requires -Version 5.1
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $root 'scripts/HarnessJbossRuntime.psm1') -Force -DisableNameChecking
function Assert($condition,$message) { if (-not $condition) { throw $message } }
$module=Get-Module HarnessJbossRuntime
$area=Join-Path $root ('.harness/tests/legacy '+[guid]::NewGuid().ToString('N').Substring(0,8))
$eapHome=Join-Path $area 'eap 70'
$null=[IO.Directory]::CreateDirectory((Join-Path $eapHome 'bin'))
$launcher=Join-Path $eapHome 'bin/standalone.bat'
# Reproduz a ordem do launcher antigo: --debug sobrescreve DEBUG_PORT antes da conf.
@'
@echo off
setlocal
set "DEBUG_PORT=8787"
set "DEBUG_MODE=false"
:args
if "%~1"=="" goto config
if "%~1"=="--debug" (
  set "DEBUG_PORT=%~2"
  set "DEBUG_MODE=true"
)
shift
goto args
:config
if not defined STANDALONE_CONF set "STANDALONE_CONF=%JBOSS_HOME%\bin\standalone.conf.bat"
call "%STANDALONE_CONF%"
echo BIND=%DEBUG_PORT%
echo DEBUG=%DEBUG_MODE%
echo OPTIONS=%JAVA_OPTS%
'@ | Set-Content -LiteralPath $launcher -Encoding ASCII
$conf=Join-Path $eapHome 'bin/standalone.conf.bat'
Set-Content -LiteralPath $conf 'set "JAVA_OPTS=-Xms64m -Xmx512m"' -Encoding ASCII
$before=(Get-FileHash $conf).Hash
$server=[pscustomobject]@{Home=$eapHome;Base=(Join-Path $eapHome 'standalone');Jdk='C:\jdk8';Version='7.0';Settings=[pscustomobject]@{standaloneConfig='standalone.xml';portOffset=0;debugPort=8799}}
$oldConf=$env:STANDALONE_CONF; $oldDebug=$env:DEBUG_PORT
try {
    $env:STANDALONE_CONF='config-do-pai'; $env:DEBUG_PORT='porta-do-pai'
    foreach ($debug in @($false,$true)) {
        $run=Join-Path $area ('run-'+$debug); $null=[IO.Directory]::CreateDirectory($run)
        $process=& $module {param($s,$r,$d) Start-JbossProcess $s $r -DebugMode:$d} $server $run $debug
        try { Assert ($process.WaitForExit(10000)) 'Launcher simulado nao encerrou.' } finally { $process.Dispose() }
        $output=Get-Content -LiteralPath (Join-Path $run 'stdout.log') -Raw
        Assert ($output.Contains('OPTIONS=-Xms64m -Xmx512m')) 'Configuracao JVM original nao foi preservada.'
        if ($debug) { Assert ($output.Contains('BIND=127.0.0.1:8799') -and $output.Contains('DEBUG=true')) 'Debug legado perdeu bind local/porta.' }
        else { Assert ($output.Contains('DEBUG=false')) 'Start normal ativou debug.' }
        Assert ($env:STANDALONE_CONF -eq 'config-do-pai' -and $env:DEBUG_PORT -eq 'porta-do-pai') 'Ambiente do processo pai nao foi restaurado.'
    }
} finally { $env:STANDALONE_CONF=$oldConf; $env:DEBUG_PORT=$oldDebug }
Assert ((Get-FileHash $conf).Hash -eq $before) 'Configuracao instalada foi alterada.'
Write-Output 'PASS: launcher 7.0 simulado preserva conf/JVM e limita debug a loopback.'
