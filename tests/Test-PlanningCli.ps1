#requires -Version 5.1
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $root 'scripts/Harness.psm1') -Force -DisableNameChecking
function Assert($condition, $message) { if (-not $condition) { throw $message } }
$area = Join-Path $root ('.harness/tests/cli' + [guid]::NewGuid().ToString('N').Substring(0,8))
$fixture = Join-Path $area 'h'
$app = Join-Path $area 'aplicacao com espacos'
$other = Join-Path $area 'outra aplicacao'
foreach ($path in @($app,$other)) {
    $null = [IO.Directory]::CreateDirectory($path)
    Set-Content -LiteralPath (Join-Path $path 'pom.xml') '<project />'
}
foreach ($file in @('scripts/Harness.psm1','scripts/HarnessGit.psm1','scripts/HarnessPlanning.psm1','scripts/HarnessPlanningInput.ps1','scripts/HarnessIssuePlanning.ps1','scripts/HarnessPrioritizationEvidence.ps1','scripts/preparar-planejamento.ps1',
    'doc/especificacoes/planejamento-copilot.md','.github/prompts/planejar-lotes.prompt.md','.github/prompts/revisar-lote.prompt.md','.github/prompts/manter-migracao.prompt.md')) {
    $destination = Join-Path $fixture $file
    $null = [IO.Directory]::CreateDirectory((Split-Path $destination -Parent))
    Copy-Item -LiteralPath (Join-Path $root $file) -Destination $destination
}
$config = Get-Content (Join-Path $root 'config/harness.example.json') -Raw | ConvertFrom-Json
$config.repositories = @(); $config.activeProject = $null
$configPath = Join-Path $fixture 'config.json'
$workspacePath = Join-Path $area 'projetos.code-workspace'
Write-HarnessJson $configPath $config
Write-HarnessJson $workspacePath @{folders=@(@{name='Aplicacao';path=$app},@{name='Outra';path=$other})}
$context = Read-HarnessConfig $configPath $fixture -WorkspacePath $workspacePath -Target $app -SkipMigrationInitialization
$runId = '11111111111111111111111111111111'
$run = Join-Path $fixture ('.harness/runs/' + $context.Active.name + '/' + $runId)
Write-HarnessJson (Join-Path $run 'manifest.json') @{Project=$context.Active.name;Source=$app;RunId=$runId;CreatedAtUtc='2026-10-03T10:00:00Z'}
Write-HarnessJson (Join-Path $run 'result.json') @{Project=$context.Active.name;RunId=$runId;Status='SUCCEEDED';ExitCode=0;SourceUnchanged=$true;SnapshotOriginalFilesUnchanged=$true;RulesUnchanged=$true;UnexpectedAddedFiles=@()}
foreach ($file in @('input/pom.xml','rules/regra.yaml','output/output.yaml','output/dependencies.yaml','output/static-report/index.html')) {
    $path = Join-Path $run $file
    $null = [IO.Directory]::CreateDirectory((Split-Path $path -Parent))
    Set-Content -LiteralPath $path 'fixture'
}
Set-Content -LiteralPath (Join-Path $run 'output/static-report/output.js') 'window["apps"] = [{"rulesets":[]}]'
$entry = Join-Path $fixture 'scripts/preparar-planejamento.ps1'
function Invoke-Cli($choices) {
    $arguments = @('-NoProfile','-NonInteractive','-File',$entry,'-ConfigPath',$configPath,'-WorkspacePath',$workspacePath,'-OutputFormat','Json')
    foreach ($key in $choices.Keys) {
        if ($choices[$key] -is [bool]) { if ($choices[$key]) { $arguments += '-' + $key } }
        else { $arguments += @(('-' + $key), [string]$choices[$key]) }
    }
    $ErrorActionPreference = 'Continue'
    $output = & powershell.exe @arguments 2>&1 | Out-String
    $code = $LASTEXITCODE
    $ErrorActionPreference = 'Stop'
    try { $result = $output | ConvertFrom-Json } catch { throw "CLI nao retornou JSON unico: $output" }
    Assert ($result.SchemaVersion -eq 1 -and $result.ExitCode -eq $code) 'Schema/codigo do processo divergente.'
    $result
}
function Get-State {
    @(Get-ChildItem -LiteralPath $fixture -Recurse -File | Sort-Object FullName | ForEach-Object {
        $_.FullName + ':' + (Get-FileHash -LiteralPath $_.FullName).Hash
    }) -join "`n"
}
function Reject-Cli($choices, $status, $missing) {
    $before = Get-State
    $result = Invoke-Cli $choices
    Assert ($result.Status -eq $status) "Estado inesperado: $($result | ConvertTo-Json -Depth 5)"
    Assert (-not $result.WritesStarted -and $result.ChangedFiles.Count -eq 0) 'Entrada rejeitada iniciou escrita.'
    Assert ((Get-State) -ceq $before) 'Entrada rejeitada alterou arquivos.'
    if ($missing) { Assert ($missing -in $result.Error.MissingInputs) "Falta nao identificada: $missing" }
}
Reject-Cli @{NonInteractive=$true;NoOpen=$true} 'INPUT_REQUIRED' 'Target'
Reject-Cli @{NonInteractive=$true;NoOpen=$true;Target=$app;Operation='planejar-lotes';NewPlan=$true} 'INPUT_REQUIRED' 'RunId|RunPath'
Reject-Cli @{NonInteractive=$true;NoOpen=$true;Target=$app;Operation='planejar-lotes';RunId=$runId} 'INPUT_REQUIRED' 'NewPlan|PreviousRequestId'
Reject-Cli @{NonInteractive=$true;Target=$app;Operation='manter-migracao';WithoutMta=$true} 'INPUT_REQUIRED' 'NoOpen'
$base = @{NonInteractive=$true;NoOpen=$true;Target=$app;Operation='planejar-lotes';RunId=$runId;NewPlan=$true}
foreach ($override in @(@{SelectTarget=$true},@{SelectOperation=$true},@{EditorPath='code'},@{RunPath=$run},@{PreviousRequestId=('a'*32)},
    @{WithoutMta=$true},@{Target=$other},@{RunId=('b'*32)},@{EvidenceIndexPath='ausente.md'},@{Target='desconhecido'},@{NonInteractive=$false})) {
    $args = $base.Clone(); foreach ($key in $override.Keys) { $args[$key] = $override[$key] }
    Reject-Cli $args 'FAILED'
}
$args = $base.Clone(); $args.Remove('NewPlan'); $args.PreviousRequestId = 'a'*32
Reject-Cli $args 'FAILED'
$args.Operation = 'revisar-lote'
Reject-Cli $args 'INPUT_REQUIRED' 'EvidenceIndexPath'
$prepared = Invoke-Cli $base
Assert ($prepared.Status -eq 'PREPARED' -and $prepared.ExitCode -eq 0 -and $prepared.WritesStarted) ("Preparo explicito falhou: " + ($prepared | ConvertTo-Json -Depth 6))
Assert ($prepared.Project -eq $context.Active.name -and $prepared.Source -eq $app -and $prepared.RunId -eq $runId) 'Perdeu identidade escolhida.'
Assert ($prepared.Diagnostics.Count -gt 0) 'Aviso do POM nao foi preservado nos diagnosticos.'
Assert (Test-Path -LiteralPath $prepared.Artifacts.ContextPath) 'Recibo ausente.'
Assert (-not (Test-Path -LiteralPath $prepared.Artifacts.PlanPath)) 'Preparo executou planejamento.'
Assert (@(Get-ChildItem (Join-Path $fixture '.harness/projetos') -Directory).Count -eq 1) 'Inicializou projeto nao selecionado.'
$receipt = Get-Content -LiteralPath $prepared.Artifacts.ContextPath -Raw | ConvertFrom-Json
Assert ($receipt.RequestId -eq $prepared.RequestId) 'Resposta difere do recibo.'
Set-Content -LiteralPath $prepared.Artifacts.PlanPath 'PROPOSTA - NAO APROVADA'
Set-Content -LiteralPath $prepared.Artifacts.TodoPath 'GO pendente'
$protectedHash = (Get-FileHash -LiteralPath $prepared.Artifacts.ContextPath).Hash
$args = $base.Clone(); $args.Remove('NewPlan'); $args.PreviousRequestId = $prepared.RequestId
$args.Operation = 'revisar-lote'; $args.EvidenceIndexPath = $prepared.Artifacts.EvidenceIndexPath
$review = Invoke-Cli $args
Assert ($review.Status -eq 'PREPARED' -and $review.Artifacts.PromptPath.EndsWith('revisar-lote.prompt.md')) 'Revisao nao retornou entrada correta.'
$reviewReceipt = Get-Content -LiteralPath $review.Artifacts.ContextPath -Raw | ConvertFrom-Json
Assert ($reviewReceipt.Previous.RequestId -eq $prepared.RequestId) 'Revisao perdeu Previous.'
Assert ((Get-FileHash -LiteralPath $prepared.Artifacts.ContextPath).Hash -eq $protectedHash) 'Alterou recibo anterior.'
$args = $base.Clone(); $args.Remove('RunId'); $args.RunPath = $run
$received = Invoke-Cli $args
Assert ($received.Status -eq 'PREPARED' -and $received.RequestId -ne $prepared.RequestId) 'Pasta explicita nao gerou solicitacao independente.'
$maintenance = @{NonInteractive=$true;NoOpen=$true;Target=$app;Operation='manter-migracao';WithoutMta=$true}
$maintained = Invoke-Cli $maintenance
Assert ($maintained.Status -eq 'PREPARED' -and $null -eq $maintained.RunId -and $maintained.RequestId) 'WithoutMta escolheu rodada ou perdeu recibo.'
Assert ($null -eq $maintained.Artifacts.PlanPath) 'Manutencao retornou plano.'
$withMta = $maintenance.Clone(); $withMta.Remove('WithoutMta'); $withMta.RunPath = $run
$withMtaResult = Invoke-Cli $withMta
Assert ($withMtaResult.RunId -eq $runId -and $withMtaResult.Status -eq 'PREPARED') ('Manutencao com rodada explicita falhou: ' + ($withMtaResult | ConvertTo-Json -Depth 6))
# Evidencia complementar nao lida pelo preparo pode estar em uso por outra ferramenta.
$unrelated = Join-Path (Split-Path $maintained.Artifacts.EvidenceIndexPath -Parent) 'evidencia-em-coleta.zip'
Set-Content -LiteralPath $unrelated 'arquivo bloqueado'
$lease = [IO.File]::Open($unrelated, 'Open', 'ReadWrite', 'None')
try { $whileCollecting = Invoke-Cli $base } finally { $lease.Dispose() }
Assert ($whileCollecting.Status -eq 'PREPARED') 'Rastreio bloqueou preparo por evidencia complementar nao utilizada.'
# Outra preparacao detem o lease: nao iniciar rastreio/escrita nem atribuir arquivos.
$lease = [IO.File]::Open((Join-Path $fixture '.harness/planning.lock'), 'Open', 'ReadWrite', 'None')
try { $busy = Invoke-Cli $base } finally { $lease.Dispose() }
Assert ($busy.Status -eq 'FAILED' -and -not $busy.WritesStarted -and $busy.ChangedFiles.Count -eq 0) 'Tentativa sem lease iniciou escrita/rastreio.'
# Falha apos salvar prompt/recibo: diagnostico nao deve sugerir reexecucao cega.
Add-Content -LiteralPath $maintained.Artifacts.MigrationPath '<!-- reconciliacao:inicio -->invalida<!-- reconciliacao:fim -->'
$failed = Invoke-Cli $maintenance
Assert ($failed.Status -eq 'FAILED' -and $failed.WritesStarted -and $failed.ChangedFiles.Count -ge 2) 'Falha parcial perdeu arquivos produzidos.'
Assert (@($failed.ChangedFiles | Where-Object { $_.Path.EndsWith('context.json') -and $_.Change -eq 'Created' }).Count -eq 1) 'Recibo parcial nao identificado.'
Write-Output 'PASS: CLI explicita, JSON, validacao sem escrita, tres operacoes, isolamento e falha parcial.'
