#requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $root 'scripts/HarnessJbossRuntime.psm1') -Force -DisableNameChecking
$module=Get-Module HarnessJbossRuntime
function Assert($condition,$message) { if (-not $condition) { throw $message } }
$area=Join-Path $root ('.harness/tests/admin-only-'+[guid]::NewGuid().ToString('N'))
$eapHome=Join-Path $area 'eap com espacos'
$null=[IO.Directory]::CreateDirectory((Join-Path $eapHome 'bin'))
Set-Content -LiteralPath (Join-Path $eapHome 'bin/standalone.bat') -Value "@echo off`r`necho ARGUMENTOS=%*" -Encoding ASCII
Set-Content -LiteralPath (Join-Path $eapHome 'bin/standalone.conf.bat') -Value '@rem fixture' -Encoding ASCII
$server=[pscustomobject]@{Home=$eapHome;Base=(Join-Path $eapHome 'standalone');Jdk='C:\jdk8';Version='7.0';ManagementPort=10090;HttpPort=8180;Settings=@{standaloneConfig='standalone.xml';portOffset=100;debugPort=8788;timeoutSeconds=0}}
foreach ($version in @('7.0','7.1','7.4')) {
    $server.Version=$version
    $run=Join-Path $area $version; $null=[IO.Directory]::CreateDirectory($run)
    $process=& $module {param($s,$r) Start-JbossProcess $s $r -AdminOnly} $server $run
    try { Assert ($process.WaitForExit(10000)) 'Launcher simulado nao encerrou.' } finally {$process.Dispose()}
    $output=Get-Content (Join-Path $run 'stdout.log') -Raw
    $expected=if ($version -eq '7.0') {'--admin-only'} else {'--start-mode=admin-only'}
    Assert ($output.Contains($expected) -and -not $output.Contains('--debug')) ('Flag admin-only ausente/incorreta para '+$version)
    Assert ($output.Contains('-c standalone.xml') -and $output.Contains('-Djboss.socket.binding.port-offset=100')) 'Admin-only perdeu config/portas escolhidas.'
}
& $module {
    $script:started=$false; $script:mode='ADMIN_ONLY'; $script:checkedPorts=@()
    function script:Get-HarnessJbossStatus($Server) {
        $state=if ($script:started) {'RUNNING'} else {'STOPPED'}
        [pscustomobject]@{State=$state;Identity='MATCHED';RunningMode=$script:mode;Debug=$false}
    }
    function script:Get-JbossListener($Port) {
        $script:checkedPorts+=@($Port)
        if ($Port -eq 8180) { [pscustomobject]@{OwningProcess=999} }
    }
    function script:Invoke-JbossJava($Server,$Arguments) { [pscustomobject]@{ExitCode=0;Output='java version "1.8.0_504"'} }
    function script:Start-JbossProcess($Server,$Run,[switch]$DebugMode,[switch]$AdminOnly) {
        if (-not $AdminOnly -or $DebugMode) { throw 'Start nao administrativo.' }
        $script:started=$true
        [pscustomobject]@{Id=42;StartTime=(Get-Date);HasExited=$false}
    }
}
$start=Start-HarnessJboss $server (Join-Path $area 'start') -AdminOnly
Assert ($start.RunningMode -eq 'ADMIN_ONLY') 'Inicio nao confirmou running-mode administrativo.'
Assert ((@(& $module {$script:checkedPorts}) -join ',') -eq '10090') 'Admin-only nao deve exigir porta HTTP das aplicacoes livre.'
$rejected=$false; try {Start-HarnessJboss $server 'nao-utilizado'} catch {$rejected=$true}
Assert $rejected 'Start normal nao pode declarar sucesso sobre servidor admin-only.'
& $module {$script:mode='NORMAL'}
$rejected=$false; try {Start-HarnessJboss $server 'nao-utilizado' -AdminOnly} catch {$rejected=$true}
Assert $rejected 'Start administrativo nao pode alegar ter alterado servidor normal.'
& $module {$script:started=$false}
$rejected=$false; try {Start-HarnessJboss $server (Join-Path $area 'mismatch') -AdminOnly} catch {$rejected=$true}
Assert $rejected 'Boot em modo diferente foi declarado sucesso.'
Write-Output 'PASS: flags admin-only 7.0/7.1/7.4, config/offset, somente porta administrativa, verificacao de modo e idempotencia; launcher/CLI simulados.'
