#requires -Version 5.1
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $root 'scripts/Harness.psm1') -Force
function Assert($condition, $message) { if (-not $condition) { throw $message } }
foreach ($readable in @($false,$true)) {
$fixture = Join-Path $root ('.harness/tests/a' + [guid]::NewGuid().ToString('N').Substring(0,8))
$null = New-Item -ItemType Directory -Path (Join-Path $fixture 'scripts') -Force
foreach ($name in @('Harness.psm1','acompanhar-log-mta.ps1')) { Copy-Item -LiteralPath (Join-Path $root "scripts/$name") -Destination (Join-Path $fixture "scripts/$name") }
$entry = Join-Path $fixture 'scripts/acompanhar-log-mta.ps1'
# Nao ha JSON local nem workspace: observabilidade independe da selecao de projeto.
$output = & powershell.exe -NoProfile -File $entry -Active -Once 2>&1 | Out-String
Assert ($LASTEXITCODE -eq 1 -and $output.Contains('Nenhuma analise MTA em execucao')) 'Monitor deve informar ausencia de MTA, sem pedir configuracao/projeto.'
$runId = '11111111111111111111111111111111'
$run = Join-Path $fixture ".harness/runs/projeto-em-execucao/$runId"
if ($readable) { $run = Join-Path $fixture ('.harness/runs/Aplicacao__' + (Get-HarnessProjectKey 'projeto-em-execucao') + '/mta_2026-09-27_10-00-00-0300__111111111111') }
$pointer = Join-Path $fixture '.harness/active-mta.json'
Write-HarnessJson (Join-Path $run 'manifest.json') @{RunId=$runId; Project='projeto-em-execucao'; Source='C:\fixture\aplicacao'; CreatedAtUtc='2026-09-27T13:00:00Z'}
Set-Content -LiteralPath (Join-Path $run 'console.log') 'LOG-DA-ANALISE-ATIVA'
$null = New-Item -ItemType Directory -Path (Join-Path $run '.metadata') -Force
Set-Content -LiteralPath (Join-Path $run '.metadata/.log') '!MESSAGE ATIVIDADE-DA-ANALISE-ATIVA'
$record = @{RunId=$runId; Project='projeto-em-execucao'; Label='Aplicacao em execucao'}
Write-HarnessJson $pointer $record
# O lock exclusivo geral tambem e usado por builds; sozinho nao comprova MTA ativo.
$buildLock = [IO.File]::Open((Join-Path $fixture '.harness/mta.lock'), 'OpenOrCreate', 'ReadWrite', 'None')
$leasePath = Join-Path $run 'active.lock'
$lease = [IO.File]::Open($leasePath, 'OpenOrCreate', 'ReadWrite', 'Read')
try {
    $output = & powershell.exe -NoProfile -File $entry -Active -Once 2>&1 | Out-String
    Assert ($LASTEXITCODE -eq 0 -and $output.Contains('Aplicacao em execucao') -and $output.Contains('LOG-DA-ANALISE-ATIVA')) 'Monitor nao se vinculou a rodada ativa.'
    $output = & powershell.exe -NoProfile -File $entry -Active -Detalhado -Once 2>&1 | Out-String
    Assert ($LASTEXITCODE -eq 0 -and $output.Contains('ATIVIDADE-DA-ANALISE-ATIVA')) 'Monitor interno nao usou a rodada ativa.'
    # Rejeitar ponteiro que tenta escapar da pasta de rodadas.
    Write-HarnessJson $pointer @{RunId=$runId; Project='../outro'; Label='invalido'}
    $output = & powershell.exe -NoProfile -File $entry -Active -Once 2>&1 | Out-String
    Assert ($LASTEXITCODE -eq 1 -and -not $output.Contains('LOG-DA-ANALISE-ATIVA')) 'Ponteiro invalido aceito.'
    Write-HarnessJson $pointer $record
} finally { $lease.Dispose() }
try {
    $output = & powershell.exe -NoProfile -File $entry -Active -Once 2>&1 | Out-String
    Assert ($LASTEXITCODE -eq 1 -and $output.Contains('Nenhuma analise MTA em execucao') -and -not $output.Contains('LOG-DA-ANALISE-ATIVA')) 'Registro antigo/build em execucao foi confundido com MTA ativo.'
} finally { $buildLock.Dispose() }
}
Write-Output 'PASS: MTA ativo sem projeto/configuracao, console, atividade interna, registro antigo e lock de build.'
