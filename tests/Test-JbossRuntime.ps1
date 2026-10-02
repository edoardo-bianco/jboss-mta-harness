#requires -Version 5.1
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $root 'scripts/HarnessJbossRuntime.psm1') -Force -DisableNameChecking
function Assert($condition,$message) { if (-not $condition) { throw $message } }
$module=Get-Module HarnessJbossRuntime
$server=[pscustomobject]@{Home='C:\EAP';Base='C:\EAP\standalone';Version='7.4';ManagementPort=10090;HttpPort=8180;Settings=[pscustomobject]@{standaloneConfig='standalone.xml';debugPort=8788;timeoutSeconds=10}}
& $module {
    $script:output='{"outcome" => "success", "result" => "C:\\Program Files\\JBoss"}'
    function script:Invoke-JbossCli { param($Server,$Command) $script:output }
}
$value=& $module {param($s) Read-JbossValue $s ':test'} $server
Assert ($value -eq 'C:\Program Files\JBoss') 'Parser DMR alterou escapes de caminhos.'
& $module {$script:output='{"outcome" => "failed", "result" => "running"}'}
$rejected=$false; try { & $module {param($s) Read-JbossValue $s ':test'} $server } catch {$rejected=$true}
Assert $rejected 'Outcome failed aceito.'
& $module {
    $script:listening=$false; $script:starting=$false; $script:wrongHome=$false
    function script:Get-JbossListener { param($Port)
        if ($script:listening -and $Port -eq 10090) {[pscustomobject]@{OwningProcess=$PID;LocalAddress='127.0.0.1'}}
    }
    function script:Get-JbossLocalProcesses { param($Server) if ($script:starting) {[pscustomobject]@{ProcessId=42}} }
    function script:Read-JbossValue { param($Server,$Command)
        switch -Regex ($Command) {
            'name=home-dir' {if ($script:wrongHome) {'C:\outro'} else {'C:\EAP'};break}
            'name=base-dir' {'C:\EAP\standalone';break}
            'name=config-file' {'C:\EAP\standalone\configuration\standalone.xml';break}
            'name=product-version' {'7.4.0.GA';break}
            'java.version' {'1.8.0_504';break}
            'name=server-state' {'running';break}
            default {throw "Consulta inesperada: $Command"}
        }
    }
}
Assert ((Get-HarnessJbossStatus $server).State -eq 'STOPPED') 'Ausencia de processo/listener deve mostrar parado.'
& $module {$script:starting=$true}
Assert ((Get-HarnessJbossStatus $server).State -eq 'UNREACHABLE') 'Processo sem listener nao deve ser declarado parado.'
& $module {$script:listening=$true}
$status=Get-HarnessJbossStatus $server
Assert ($status.State -eq 'RUNNING' -and $status.Identity -eq 'MATCHED') 'Identidade valida recusada.'
Assert ((Start-HarnessJboss $server 'nao-utilizado').State -eq 'RUNNING') 'Start de servidor running deve ser idempotente.'
$rejected=$false; try {Start-HarnessJboss $server 'nao-utilizado' -DebugMode} catch {$rejected=$true}
Assert $rejected 'Start debug nao pode alegar debug de servidor normal.'
& $module {$script:wrongHome=$true}
$rejected=$false; try {Stop-HarnessJboss $server} catch {$rejected=$true}
Assert $rejected 'Stop de outra instalacao aceito.'
& $module {
    $script:shutdownSent=$false; $script:canExit=$true; $script:lastShutdown=''
    $script:fakeStart=Get-Date
    function script:Get-HarnessJbossStatus { param($Server)
        if ($script:shutdownSent -and $script:canExit) { return [pscustomobject]@{State='STOPPED'} }
        [pscustomobject]@{State='RUNNING';Identity='MATCHED';ProcessId=42;ProcessStartUtc=$script:fakeStart.ToUniversalTime().ToString('o')}
    }
    function script:Get-Process { param($Id,$ErrorAction)
        $p=[pscustomobject]@{StartTime=$script:fakeStart;Exited=$script:canExit}
        $p | Add-Member ScriptMethod WaitForExit {param($milliseconds) return $this.Exited}
        $p
    }
    function script:Invoke-JbossCli { param($Server,$Command) $script:lastShutdown=$Command;$script:shutdownSent=$true }
}
foreach ($version in @('7.1','7.4')) {
    & $module {$script:shutdownSent=$false}
    $server.Version=$version
    Assert ((Stop-HarnessJboss $server).State -eq 'STOPPED') 'Shutdown nao confirmou a saida.'
    $command=& $module {$script:lastShutdown}
    if ($version -eq '7.1') {Assert ($command -eq 'shutdown --timeout=10') 'EAP 7.1 exige --timeout.'}
    else {Assert ($command -eq 'shutdown --suspend-timeout=10') 'EAP 7.4 exige --suspend-timeout.'}
}
& $module {$script:shutdownSent=$false;$script:canExit=$false}
$rejected=$false; try {Stop-HarnessJboss $server} catch {$rejected=$true}
Assert $rejected 'Shutdown sem saida foi tratado como sucesso.'
Write-Output 'PASS: DMR EAP 7.1/7.4, identidade, estados, idempotencia e protecao de stop.'
