#requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $root 'scripts/HarnessJboss.psm1') -Force -DisableNameChecking
$module=Get-Module HarnessJboss
$area=Join-Path $root ('.harness/tests/restart-'+[guid]::NewGuid().ToString('N'))
$server=[pscustomobject]@{Eap='eap74';Home=$area;Base=(Join-Path $area 'standalone');State=(Join-Path $area 'state');Settings=@{standaloneConfig='standalone.xml'}}
function Assert($condition,$message) { if (-not $condition) { throw $message } }
& $module {
    $script:calls=@(); $script:stopFailure=$false; $script:startFailure=$false; $script:stoppedState='STOPPED'
    function script:Test-OperationLock($Server) {
        try { $other=[IO.File]::Open((Join-Path $Server.State 'operation.lock'),'OpenOrCreate','ReadWrite','None') }
        catch { return }
        $other.Dispose(); throw 'Restart liberou lock entre stop/start.'
    }
    function script:Stop-HarnessJboss($Server) {
        Test-OperationLock $Server
        $script:calls+='Stop'
        if ($script:stopFailure) { throw 'Parada falhou; processo preservado.' }
        [pscustomobject]@{State=$script:stoppedState}
    }
    function script:Start-HarnessJboss($Server,$Run,[switch]$DebugMode) {
        Test-OperationLock $Server
        $script:calls+=('Start:'+([bool]$DebugMode))
        if ($script:startFailure) { throw 'Porta ocupada durante start.' }
        [pscustomobject]@{State='RUNNING';Debug=[bool]$DebugMode}
    }
}
foreach ($mode in @('Restart','RestartDebug')) {
    & $module { $script:calls=@() }
    $result=Invoke-HarnessJbossOperation ([pscustomobject]@{Root=$root}) $server $mode
    $calls=@(& $module { $script:calls })
    $debug=$mode -eq 'RestartDebug'
    Assert ($result.Status -eq 'SUCCEEDED' -and $result.Observed.State -eq 'RUNNING' -and $result.Observed.Debug -eq $debug) 'Restart nao confirmou modo/estado.'
    Assert (($calls -join ',') -eq ('Stop,Start:'+ $debug)) 'Restart nao respeitou ordem stop/start.'
}
foreach ($failure in @('exception','unreachable')) {
    & $module { param($f) $script:calls=@(); $script:stopFailure=$f -eq 'exception'; $script:stoppedState='UNREACHABLE' } $failure
    $result=Invoke-HarnessJbossOperation ([pscustomobject]@{Root=$root}) $server Restart
    Assert ($result.Status -eq 'FAILED' -and (@(& $module {$script:calls}) -join ',') -eq 'Stop') 'Restart iniciou outro processo apos parada nao confirmada.'
    $receipt=Get-Content (Join-Path $server.State 'ultima-operacao.json') -Raw | ConvertFrom-Json
    Assert ($receipt.Status -eq 'FAILED' -and $receipt.Error -and $receipt.Phase -eq 'Stop') 'Falha de restart nao foi registrada com fase.'
}
& $module { $script:calls=@(); $script:stopFailure=$false; $script:stoppedState='STOPPED'; $script:startFailure=$true }
$result=Invoke-HarnessJbossOperation ([pscustomobject]@{Root=$root}) $server Restart
Assert ($result.Status -eq 'FAILED' -and $result.Phase -eq 'Start' -and (@(& $module {$script:calls}) -join ',') -eq 'Stop,Start:False') 'Falha do start nao foi propagada ou provocou nova tentativa.'
$lock=[IO.File]::Open((Join-Path $server.State 'operation.lock'),'OpenOrCreate','ReadWrite','None')
$lock.Dispose()
Write-Output 'PASS: restart normal/debug, ordem, lock unico, falha/estado indeterminado impedem start; fronteiras de processo simuladas.'
