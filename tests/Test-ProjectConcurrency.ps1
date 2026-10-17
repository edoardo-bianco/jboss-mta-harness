#requires -Version 5.1
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$root=Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $root 'scripts/HarnessProject.psm1') -Force -DisableNameChecking
function Assert($condition,[string]$message) { if (-not $condition) { throw $message } }
function Reject([scriptblock]$action,[string]$message) { $failed=$false; try { & $action | Out-Null } catch { $failed=$true }; Assert $failed $message }
$area=Join-Path $root ('.harness/tests/concorrencia-'+[guid]::NewGuid().ToString('N').Substring(0,8))
$app=Join-Path $area 'app'; $null=[IO.Directory]::CreateDirectory($app)
[IO.File]::WriteAllText((Join-Path $app 'pom.xml'),'<project><artifactId>servico</artifactId></project>')
$project=Initialize-HarnessProjectStorage $area (Join-Path $app 'pom.xml')
Publish-HarnessProjectFiles $project @{'atual/planejamento/plano.md'='completo'}
$child=Join-Path $area 'segurar.ps1'
$body=@'
param($Module,$Area,$Mode)
$ErrorActionPreference='Stop'
Import-Module $Module -DisableNameChecking
$project=Get-HarnessProjectStorage $Area 'app/pom.xml'
$lease=Enter-HarnessProjectAccess $project -ForOperation:($Mode -eq 'operation')
try {
    [IO.File]::WriteAllText((Join-Path $Area 'pronto'),'pronto')
    while (-not (Test-Path (Join-Path $Area 'liberar'))) { Start-Sleep -Milliseconds 100 }
} finally { $lease.ReleaseMutex(); $lease.Dispose() }
'@
[IO.File]::WriteAllText($child,$body)
foreach ($mode in @('operation','publication')) {
    foreach ($signal in @('pronto','liberar')) { [IO.File]::Delete((Join-Path $area $signal)) }
    $start=New-Object Diagnostics.ProcessStartInfo
    $start.FileName=Join-Path $env:WINDIR 'System32/WindowsPowerShell/v1.0/powershell.exe'
    $start.Arguments='-NoProfile -File "'+$child+'" -Module "'+(Join-Path $root 'scripts/HarnessProject.psm1')+'" -Area "'+$area+'" -Mode '+$mode
    $start.UseShellExecute=$false; $start.CreateNoWindow=$true
    $process=[Diagnostics.Process]::Start($start)
    try {
        $deadline=[DateTime]::UtcNow.AddSeconds(20)
        while (-not (Test-Path (Join-Path $area 'pronto')) -and [DateTime]::UtcNow -lt $deadline -and -not $process.HasExited) { Start-Sleep -Milliseconds 100 }
        Assert (Test-Path (Join-Path $area 'pronto')) 'Processo auxiliar nao adquiriu o bloqueio.'
        if ($mode -eq 'operation') {
            $current=Read-HarnessProjectFiles $project @('atual/planejamento/plano.md')
            Assert ($current['atual/planejamento/plano.md'] -ceq 'completo') 'Ferramenta em execucao deve permitir ler o conjunto corrente.'
            Reject { Enter-HarnessProjectAccess $project -ForOperation } 'Duas ferramentas nao podem executar ao mesmo tempo no projeto.'
        } else { Reject { Read-HarnessProjectFiles $project @('atual/planejamento/plano.md') } 'Leitor nao pode observar publicacao parcial.' }
    } finally {
        [IO.File]::WriteAllText((Join-Path $area 'liberar'),'liberar')
        if (-not $process.WaitForExit(10000)) { $process.Kill() }
        $process.Dispose()
    }
}
'PASS: duas ferramentas serializadas e leitor isolado somente durante publicacao.'
