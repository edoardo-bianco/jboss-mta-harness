#requires -Version 5.1
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$root=Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $root 'scripts/HarnessProject.psm1') -Force -DisableNameChecking
function Assert($condition,[string]$message) { if (-not $condition) { throw $message } }
$area=Join-Path $root ('.harness/tests/mta-ativo-'+[guid]::NewGuid().ToString('N').Substring(0,8))
$app=Join-Path $area 'app'; $null=[IO.Directory]::CreateDirectory($app)
[IO.File]::WriteAllText((Join-Path $app 'pom.xml'),'<project><artifactId>api</artifactId></project>')
$project=Initialize-HarnessProjectStorage $area (Join-Path $app 'pom.xml')
$child=Join-Path $area 'produzir.ps1'
$body=@'
param($Module,$Area)
$ErrorActionPreference='Stop'
Import-Module $Module -DisableNameChecking
$project=Get-HarnessProjectStorage $Area 'app/pom.xml'
$lease=Enter-HarnessProjectAccess $project -ForOperation
try {
    $temporary=Get-HarnessProjectTemporary $project 'mta'
    $null=[IO.Directory]::CreateDirectory($temporary)
    $log=Join-Path $temporary 'console.log'
    [IO.File]::WriteAllText($log,'EM-ANDAMENTO')
    Set-HarnessProjectOperation $project 'mta' 'RUNNING' -LogPath $log
    [IO.File]::WriteAllText((Join-Path $Area 'pronto'),'pronto')
    while (-not (Test-Path (Join-Path $Area 'liberar'))) { Start-Sleep -Milliseconds 100 }
    Set-HarnessProjectOperation $project 'mta' 'SUCCEEDED' -LogPath (Join-Path $project.Folder 'atual/diagnosticos/mta-console.log') -Files @{'atual/diagnosticos/mta-console.log'='CONCLUIDO'}
    Remove-HarnessProjectTemporary $project 'mta'
} finally { $lease.ReleaseMutex(); $lease.Dispose() }
'@
[IO.File]::WriteAllText($child,$body)
$start=New-Object Diagnostics.ProcessStartInfo
$start.FileName=Join-Path $env:WINDIR 'System32/WindowsPowerShell/v1.0/powershell.exe'
$start.Arguments='-NoProfile -File "'+$child+'" -Module "'+(Join-Path $root 'scripts/HarnessProject.psm1')+'" -Area "'+$area+'"'
$start.UseShellExecute=$false; $start.CreateNoWindow=$true
$process=[Diagnostics.Process]::Start($start)
try {
    $deadline=[DateTime]::UtcNow.AddSeconds(20)
    while (-not (Test-Path (Join-Path $area 'pronto')) -and [DateTime]::UtcNow -lt $deadline -and -not $process.HasExited) { Start-Sleep -Milliseconds 100 }
    Assert (Test-Path (Join-Path $area 'pronto')) 'Produtor nao iniciou.'
    $active=Get-HarnessProjectMtaLog $project
    Assert ($active.Running -and $active.Status -eq 'RUNNING' -and [IO.File]::ReadAllText($active.Path) -ceq 'EM-ANDAMENTO') 'Log deve acompanhar processo ativo do projeto sem ponteiro global.'
} finally {
    [IO.File]::WriteAllText((Join-Path $area 'liberar'),'liberar')
    if (-not $process.WaitForExit(10000)) { $process.Kill() }
    $process.Dispose()
}
$finished=Get-HarnessProjectMtaLog $project
Assert (-not $finished.Running -and $finished.Status -eq 'SUCCEEDED' -and [IO.File]::ReadAllText($finished.Path) -ceq 'CONCLUIDO') 'Log deve passar ao destino corrente ao terminar.'
Assert (-not (Test-Path (Join-Path $area '.harness/active-mta.json'))) 'Nao criar ponteiro global de execucao.'
'PASS: log acompanha produtor real e transita para resultado corrente sem IDs.'
