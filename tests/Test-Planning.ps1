#requires -Version 5.1
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $root 'scripts/Harness.psm1') -Force -DisableNameChecking
function Assert($condition, $message) { if (-not $condition) { throw $message } }
function Reject($action, $message) {
    $rejected = $false
    try { & $action | Out-Null } catch { $rejected = $true }
    Assert $rejected $message
}
$area = Join-Path $root ('.harness/tests/p' + [guid]::NewGuid().ToString('N').Substring(0,8))
$fixture = Join-Path $area 'h'
$contractDestination = Join-Path $fixture 'doc/especificacoes/planejamento-copilot.md'
$null = [IO.Directory]::CreateDirectory((Split-Path $contractDestination -Parent))
Copy-Item (Join-Path $root 'doc/especificacoes/planejamento-copilot.md') $contractDestination
$app = Join-Path $area 'aplicacao com espacos'
$other = Join-Path $area 'outra aplicacao'
foreach ($path in @($fixture,$app,$other)) { $null = New-Item -ItemType Directory -Path $path -Force }
foreach ($path in @($app,$other)) { Set-Content -LiteralPath (Join-Path $path 'pom.xml') '<project />' }
$config = Get-Content (Join-Path $root 'config/harness.example.json') -Raw | ConvertFrom-Json
$config.repositories = @()
$config.activeProject = $null
# Campo legado deliberadamente invalido: nao pode criar menus ou bloquear preparacao.
$config | Add-Member NoteProperty gitPolicies @(@{source=$null;workBranch='antiga'},@{source=$null;workBranch='duplicada'})
$configPath = Join-Path $fixture 'config.json'
$workspacePath = Join-Path $area 'projetos.code-workspace'
Write-HarnessJson $configPath $config
Write-HarnessJson $workspacePath @{folders=@(@{name='Aplicacao';path=$app},@{name='Outra';path=$other})}
$context = Read-HarnessConfig $configPath $fixture -WorkspacePath $workspacePath -Target $app
$otherContext = Read-HarnessConfig $configPath $fixture -WorkspacePath $workspacePath -Target $other
function Add-Run($ctx, $id, $date, $status = 'SUCCEEDED', $readable = $false) {
    $run = Join-Path $fixture ('.harness/runs/' + $ctx.Active.name + '/' + $id)
    if ($readable) {
        $run = Join-Path $fixture ('.harness/runs/' + (Get-HarnessProjectFolder $ctx.Active) + '/mta_' + (Format-HarnessDate $date -ForPath) + '__' + $id.Substring(0,12))
    }
    $manifest = @{Project=$ctx.Active.name;RunId=$id;Source=$ctx.Active.path;CreatedAtUtc=$date}
    if ($readable) {
        $index = $run
        $external = Join-Path $area 'mta-runs'
        $relative = 'Aplicacao/' + ([DateTimeOffset]::Parse($date)).ToLocalTime().ToString('yyMMdd-HHmmss')
        $run = Join-Path $external $relative
        $manifest.IndexPath = $index
        Write-HarnessJson (Join-Path $index 'location.json') @{Project=$ctx.Active.name;RunId=$id;Source=$ctx.Active.path;RunsPath=$external;RunRelativePath=$relative}
    }
    Write-HarnessJson (Join-Path $run 'manifest.json') $manifest
    Write-HarnessJson (Join-Path $run 'result.json') @{Project=$ctx.Active.name;RunId=$id;Status=$status;ExitCode=0;SourceUnchanged=$true;SnapshotOriginalFilesUnchanged=$true;RulesUnchanged=$true;UnexpectedAddedFiles=@()}
    foreach ($file in @('output/output.yaml','output/dependencies.yaml','output/static-report/index.html','rules/regra.yaml')) {
        $path = Join-Path $run $file
        $null = New-Item -ItemType Directory -Path (Split-Path -Parent $path) -Force
        Set-Content -LiteralPath $path 'fixture'
    }
    return $run
}
$oldId = '11111111111111111111111111111111'
$newId = '22222222222222222222222222222222'
$failedId = '33333333333333333333333333333333'
$oldRun = Add-Run $context $oldId '2026-09-24T10:00:00Z'
$newRun = Add-Run $context $newId '2026-09-25T10:00:00Z' 'SUCCEEDED' $true
$failedRun = Add-Run $context $failedId '2026-09-26T10:00:00Z' 'FAILED'
$otherRun = Add-Run $otherContext '44444444444444444444444444444444' '2026-09-27T10:00:00Z'
foreach ($pair in @(@($oldId,$oldRun),@($newId,$newRun))) {
    Write-HarnessJson (Join-Path $fixture ('.harness/last-' + $context.Active.name + '.json')) @{RunId=$pair[0]}
    Assert ((Get-LastMtaReport $context) -eq (Join-Path $pair[1] 'output/static-report/index.html')) 'Ponteiro do ultimo relatorio nao resolveu o formato antigo/novo.'
}
Import-Module (Join-Path $root 'scripts/HarnessPlanning.psm1') -Force -DisableNameChecking
$runs = @(Get-MtaPlanningRuns $context)
Assert ($runs.Count -eq 3 -and $runs[0].RunId -eq $failedId) 'Historico deve ser ordenado pela data do manifesto e isolado por projeto.'
& (Get-Module HarnessPlanning) { function script:Read-Host { param($Prompt) '' } }
$messages = Select-MtaPlanningRun $context -Interactive 6>&1
$selected = @($messages | Where-Object { $_ -isnot [System.Management.Automation.InformationRecord] })[-1]
Assert ($selected.RunId -eq $newId) 'Enter deve escolher a ultima rodada elegivel.'
$localNew = ([DateTimeOffset]::Parse('2026-09-25T10:00:00Z')).ToLocalTime().ToString('yyyy-MM-dd HH:mm:ss zzz')
Assert (($messages | Out-String).Contains("Ultima elegivel: $localNew |")) 'Ultima elegivel deve mostrar horario local com fuso.'
Assert (($messages | Out-String).Contains($failedId)) 'Tentativa mais recente com falha ficou oculta.'
Assert ((Select-MtaPlanningRun $context -RunId $oldId).RunId -eq $oldId) 'Selecao explicita perdeu rodada antiga.'
& (Get-Module HarnessPlanning) {
    $script:answers = New-Object 'Collections.Generic.Queue[string]'
    $script:answers.Enqueue('h'); $script:answers.Enqueue('3')
    function script:Read-Host { param($Prompt) $script:answers.Dequeue() }
}
$historyMessages = Select-MtaPlanningRun $context -Interactive 6>&1
$historySelected = @($historyMessages | Where-Object { $_ -isnot [System.Management.Automation.InformationRecord] })[-1]
Assert ($historySelected.RunId -eq $oldId) 'Historico nao respeitou selecao por numero.'
$localOld = ([DateTimeOffset]::Parse('2026-09-24T10:00:00Z')).ToLocalTime().ToString('yyyy-MM-dd HH:mm:ss zzz')
Assert (($historyMessages | Out-String).Contains("3. $localOld |")) 'Historico deve mostrar horario local com fuso.'
& (Get-Module HarnessPlanning) { function script:Read-Host { param($Prompt) 'q' } }
Reject { Select-MtaPlanningRun $context -Interactive } 'Cancelamento aceito.'
Reject { Select-MtaPlanningRun $context -RunId $failedId } 'Rodada com falha aceita.'
Reject { Select-MtaPlanningRun $context -RunId '../fora' } 'RunId invalido aceito.'
Reject { Select-MtaPlanningRun $context -RunId '44444444444444444444444444444444' } 'Aceitou rodada de outro projeto.'
# Fonte divergente e evidencia ausente nao podem produzir um contexto valido.
$manifestPath = Join-Path $oldRun 'manifest.json'
$manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
$manifest.Source = $other
Write-HarnessJson $manifestPath $manifest
Reject { Select-MtaPlanningRun $context -RunId $oldId } 'Aceitou manifesto com fonte divergente.'
Write-HarnessJson (Join-Path $fixture ('.harness/last-' + $context.Active.name + '.json')) @{RunId=$oldId}
Reject { Get-LastMtaReport $context } 'Relatorio aceitou fonte divergente.'
$manifest.Source = $app
Write-HarnessJson $manifestPath $manifest
$dependencyPath = Join-Path $oldRun 'output/dependencies.yaml'
Move-Item -LiteralPath $dependencyPath -Destination ($dependencyPath + '.saved')
Reject { Select-MtaPlanningRun $context -RunId $oldId } 'Aceitou rodada sem dependencias.'
Move-Item -LiteralPath ($dependencyPath + '.saved') -Destination $dependencyPath
Write-Output 'PASS: selecao MTA isolada, ultima elegivel, historico, cancelamento e evidencias invalidas.'

# Preparar contextos unicos sem tocar em evidencias, configuracao ou fontes.
$promptSource = Join-Path $fixture '.github/prompts/planejar-lotes.prompt.md'
$null = New-Item -ItemType Directory -Path (Split-Path -Parent $promptSource) -Force
Copy-Item -LiteralPath (Join-Path $root '.github/prompts/planejar-lotes.prompt.md') -Destination $promptSource
$before = @(Get-ChildItem -LiteralPath $area -Recurse -File | Get-FileHash)
$prepared = New-MtaPlanningContext $context -RunId $oldId
$promptText = Get-Content -LiteralPath $prepared.PromptPath -Raw -Encoding UTF8
# O prompt sobrescreve as ferramentas do condutor: delegacao precisa chegar ao cliente.
$frontmatter = [regex]::Match($promptText, '(?s)\A---\s*\r?\n(.*?)\r?\n---').Groups[1].Value
Assert ($frontmatter -match '(?m)^agent: devsquad\s*$') 'Planejamento perdeu o condutor DevSquad.'
$toolLine = [regex]::Match($frontmatter, '(?m)^tools: \[(.*?)\]').Groups[1].Value
$toolNames = @([regex]::Matches($toolLine, "'([^']+)'") | ForEach-Object { $_.Groups[1].Value })
$allowedTools = @('agent','read/readFile','search/listDirectory','search/fileSearch','search/textSearch','edit/createFile','edit/editFiles')
Assert (@(Compare-Object $allowedTools $toolNames).Count -eq 0) 'Prompt deve permitir delegacao, leitura e edicao, sem terminal ou outras ferramentas.'
$requestFolder = Split-Path -Parent $prepared.PromptPath
$runFolder = Split-Path -Parent $requestFolder
$projectFolder = Split-Path -Parent $runFolder
Assert ((Split-Path -Leaf $projectFolder) -match '^Aplicacao__[a-f0-9]{12}$') 'Pasta deve mostrar nome e chave estavel do projeto.'
Assert ((Split-Path -Leaf $runFolder) -match '^mta_\d{4}-\d{2}-\d{2}_\d{2}-\d{2}-\d{2}[+-]\d{4}__111111111111$') 'Pasta MTA deve mostrar data, fuso e ID curto.'
Assert ((Split-Path -Leaf $requestFolder) -match ('^plano_\d{4}-\d{2}-\d{2}_\d{2}-\d{2}-\d{2}[+-]\d{4}__' + $prepared.RequestId.Substring(0,12) + '$')) 'Solicitacao deve mostrar data de preparacao, fuso e ID curto.'
Assert ($prepared.PlanPath -eq (Join-Path $requestFolder 'plan.md') -and $prepared.TodoPath -eq (Join-Path $requestFolder 'todo.md')) 'Saidas de corretivas fora da pasta da solicitacao.'
Assert (-not (Test-Path -LiteralPath $prepared.PlanPath) -and -not (Test-Path -LiteralPath $prepared.TodoPath)) 'Harness nao deve simular um plano produzido pelo Copilot.'
$jsonBlock = [regex]::Match($promptText, '(?s)```json\s*(\{.*?\})\s*```').Groups[1].Value | ConvertFrom-Json
Assert ($jsonBlock.PlanPath -eq $prepared.PlanPath.Replace('\','/') -and $jsonBlock.TodoPath -eq $prepared.TodoPath.Replace('\','/')) 'Prompt nao informa as saidas autorizadas.'
Assert ($jsonBlock.ProjectIndexPath -eq (Join-Path $fixture '.harness/projetos/indice-projetos.md').Replace('\','/')) 'Prompt nao referencia indice do harness selecionado.'
# Simular documentos existentes para provar que preparar outra solicitacao nao os sobrescreve.
Set-Content -LiteralPath $prepared.PlanPath 'PLANO-DE-CORRETIVAS-EXISTENTE'
Set-Content -LiteralPath $prepared.TodoPath 'TAREFAS-DE-CORRETIVAS-EXISTENTES'
$plansBefore = @(@($prepared.PlanPath,$prepared.TodoPath) | ForEach-Object { Get-FileHash -LiteralPath $_ })
Assert ($prepared.RunId -eq $oldId -and $promptText.Contains($oldId)) 'Prompt nao fixou a rodada escolhida.'
Assert ($promptText.Contains('ContextPath') -and $promptText.Contains('Estado atual dos fontes: NAO VERIFICADO')) 'Contexto sem evidencias ou sem limite historico.'
Assert ($promptText.StartsWith((Get-Content -LiteralPath $promptSource -Raw -Encoding UTF8).TrimEnd())) 'Prompt gerado divergiu das instrucoes versionadas.'
$again = New-MtaPlanningContext $context -RunId $oldId
Assert ($again.PromptPath -ne $prepared.PromptPath) 'Nova solicitacao sobrescreveu a anterior.'
foreach ($file in $plansBefore) { Assert ((Get-FileHash -LiteralPath $file.Path).Hash -eq $file.Hash) 'Preparacao alterou plano/todo de corretivas existente.' }
$otherPrepared = New-MtaPlanningContext $otherContext -RunId '44444444444444444444444444444444'
Assert ((Split-Path -Parent $otherPrepared.PlanPath) -ne $requestFolder) 'Saidas de projetos diferentes se misturaram.'
$receipt = Get-Content -LiteralPath $prepared.ContextPath -Raw -Encoding UTF8 | ConvertFrom-Json
Assert ($receipt.RunId -eq $oldId -and $receipt.RequestId -eq $prepared.RequestId) 'Recibo nao identifica planejamento e rodada.'
Assert ($receipt.EvidenceHashes.Findings -eq (Get-FileHash -LiteralPath (Join-Path $oldRun 'output/output.yaml')).Hash) 'Recibo sem hash do MTA selecionado.'
$history = @(Get-MtaPlanningHistory $context)
Assert ($history.Count -eq 1 -and $history[0].RequestId -eq $prepared.RequestId) 'Historico deve listar somente propostas persistidas do projeto.'
& (Get-Module HarnessPlanning) { function script:Read-Host { param($Prompt) '1' } }
$menuOutput = Select-MtaPreviousPlanning $context 6>&1
$menuText = $menuOutput | Out-String
Assert ($menuText.Contains('Aplicacao') -and $menuText.Contains('Planejado:') -and $menuText.Contains('MTA:')) 'Menu deve identificar projeto e ambas as datas.'
Assert (@($menuOutput | Where-Object { $_ -isnot [System.Management.Automation.InformationRecord] })[-1].RequestId -eq $prepared.RequestId) 'Menu nao vinculou proposta anterior.'
$continued = New-MtaPlanningContext $context -RunId $newId -PreviousRequestId $prepared.RequestId
$nextReceipt = Get-Content -LiteralPath $continued.ContextPath -Raw -Encoding UTF8 | ConvertFrom-Json
Assert ($nextReceipt.RunId -eq $newId -and $nextReceipt.Previous.RunId -eq $oldId) 'Nova rodada substituiu a origem da proposta anterior.'
Assert ($nextReceipt.Previous.PlanSha256 -eq (Get-FileHash -LiteralPath $prepared.PlanPath).Hash) 'Vinculo nao identifica a versao do plano anterior.'
Reject { New-MtaPlanningContext $otherContext -RunId '44444444444444444444444444444444' -PreviousRequestId $prepared.RequestId } 'Aceitou continuidade entre projetos diferentes.'
$findingsPath = Join-Path $oldRun 'output/output.yaml'
$findingsBytes = [IO.File]::ReadAllBytes($findingsPath)
Set-Content -LiteralPath $findingsPath 'evidencia alterada'
Reject { New-MtaPlanningContext $context -RunId $newId -PreviousRequestId $prepared.RequestId } 'Aceitou MTA anterior alterado desde o planejamento.'
[IO.File]::WriteAllBytes($findingsPath, $findingsBytes)
foreach ($file in $plansBefore) { Assert ((Get-FileHash -LiteralPath $file.Path).Hash -eq $file.Hash) 'Continuidade modificou plano/todo anterior.' }
$savedHash = (Get-FileHash -LiteralPath $prepared.PromptPath).Hash
$null = Add-Run $context '55555555555555555555555555555555' '2026-09-28T10:00:00Z'
Assert ((Get-FileHash -LiteralPath $prepared.PromptPath).Hash -eq $savedHash) 'Nova rodada alterou o contexto anterior.'
foreach ($file in $before) { Assert ((Get-FileHash -LiteralPath $file.Path).Hash -eq $file.Hash) "Preparacao alterou $($file.Path)." }
$resultPath = Join-Path $oldRun 'result.json'
$savedResult = Get-Content -LiteralPath $resultPath -Raw -Encoding UTF8 | ConvertFrom-Json
$savedResult.RunId = $newId
Write-HarnessJson $resultPath $savedResult
Reject { New-MtaPlanningContext $context -RunId $oldId } 'Preparacao nao revalidou identidade do resultado.'
Reject { Get-LastMtaReport $context } 'Relatorio aceitou identidade de resultado divergente.'
$savedResult.RunId = $oldId
$savedResult.SourceUnchanged = $false
Write-HarnessJson $resultPath $savedResult
Reject { New-MtaPlanningContext $context -RunId $oldId } 'Preparacao aceitou integridade historica falha.'
$savedResult.SourceUnchanged = $true
Write-HarnessJson $resultPath $savedResult

# Entrada real em fixture: ferramentas de build/MTA do config nao existem.
$scripts = Join-Path $fixture 'scripts'
$null = New-Item -ItemType Directory -Path $scripts -Force
foreach ($name in @('Harness.psm1','HarnessGit.psm1','HarnessPlanning.psm1','HarnessPlanningInput.ps1','HarnessIssuePlanning.ps1','HarnessPrioritizationEvidence.ps1','preparar-planejamento.ps1')) {
    Copy-Item -LiteralPath (Join-Path $root "scripts/$name") -Destination (Join-Path $scripts $name)
}
$entry = Join-Path $scripts 'preparar-planejamento.ps1'
$cliArgs = @('-NoProfile','-File',$entry,'-ConfigPath',$configPath,'-WorkspacePath',$workspacePath,'-SelectTarget','-NoOpen','-NewPlan')
$count = @(Get-ChildItem -LiteralPath (Join-Path $fixture '.harness/planning') -Recurse -Filter '*.prompt.md' -File).Count
$output = @('1','q') | & powershell.exe @cliArgs 2>&1 | Out-String
Assert ($LASTEXITCODE -eq 1 -and $output.Contains('Selecao cancelada')) 'Entrada real nao respeitou cancelamento.'
Assert (@(Get-ChildItem -LiteralPath (Join-Path $fixture '.harness/planning') -Recurse -Filter '*.prompt.md' -File).Count -eq $count) 'Cancelamento gerou contexto.'
$output = @('1','h','4') | & powershell.exe @cliArgs 2>&1 | Out-String
Assert ($LASTEXITCODE -eq 0 -and $output.Contains($oldId) -and $output.Contains('Prompt preparado:')) 'Entrada real nao preparou a rodada escolhida no historico.'
Assert (-not $output.Contains('Branches ainda nao declaradas') -and -not $output.Contains('conferir Git do lote')) 'Preparacao ainda exige cadastro/conferencia Git.'
Assert (@(Get-ChildItem -LiteralPath (Join-Path $fixture '.harness/planning') -Recurse -Filter '*.prompt.md' -File).Count -eq ($count+1)) 'Entrada real nao gerou uma unica solicitacao.'
# Continuidade pela entrada real: cancelar nao grava; escolher fixa ambas as rodadas.
$continuationArgs = @('-NoProfile','-File',$entry,'-ConfigPath',$configPath,'-WorkspacePath',$workspacePath,'-Target',$app,'-RunId',$newId,'-NoOpen')
$count = @(Get-ChildItem -LiteralPath (Join-Path $fixture '.harness/planning') -Recurse -Filter '*.prompt.md' -File).Count
$output = 'q' | & powershell.exe @continuationArgs 2>&1 | Out-String
Assert ($LASTEXITCODE -eq 1 -and $output.Contains('Selecao de planejamento cancelada')) 'Menu real anterior nao respeitou cancelamento.'
Assert (@(Get-ChildItem -LiteralPath (Join-Path $fixture '.harness/planning') -Recurse -Filter '*.prompt.md' -File).Count -eq $count) 'Cancelar continuidade gerou contexto.'
$output = '1' | & powershell.exe @continuationArgs 2>&1 | Out-String
Assert ($LASTEXITCODE -eq 0 -and $output.Contains('Planejamento anterior vinculado: ' + $prepared.RequestId)) 'Menu real nao vinculou a proposta escolhida.'
$receiptLine = @($output -split '\r?\n' | Where-Object { $_.StartsWith('Recibo de contexto e hashes: ') })
Assert ($receiptLine.Count -eq 1) 'Entrada nao informou um unico recibo.'
$cliReceipt = Get-Content -LiteralPath ($receiptLine[0].Substring('Recibo de contexto e hashes: '.Length)) -Raw -Encoding UTF8 | ConvertFrom-Json
Assert ($cliReceipt.RunId -eq $newId -and $cliReceipt.Previous.RunId -eq $oldId -and $cliReceipt.Previous.RequestId -eq $prepared.RequestId) 'Entrada real confundiu as identidades atual/anterior.'
# Editor simulado: comprovar que recebe apenas abertura de arquivo, nunca chat/envio.
$editorPath = Join-Path $scripts 'editor simulado.ps1'
@'
param([Parameter(ValueFromRemainingArguments=$true)][string[]]$EditorArguments)
$EditorArguments | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $PSScriptRoot 'editor-args.json') -Encoding UTF8
'@ | Set-Content -LiteralPath $editorPath -Encoding UTF8
$output = & powershell.exe -NoProfile -File $entry -ConfigPath $configPath -WorkspacePath $workspacePath -Target $app -RunId $oldId -NewPlan -EditorPath $editorPath 2>&1 | Out-String
Assert ($LASTEXITCODE -eq 0) 'Preparacao com editor falhou.'
$editorArgs = Get-Content -LiteralPath (Join-Path $scripts 'editor-args.json') -Raw | ConvertFrom-Json
Assert ($editorArgs.Count -eq 2 -and $editorArgs[0] -eq '--reuse-window' -and (Test-Path -LiteralPath $editorArgs[1])) 'Editor recebeu argumentos diferentes de abertura do prompt.'
$failedEditor = Join-Path $scripts 'editor falho.cmd'
Set-Content -LiteralPath $failedEditor -Encoding ASCII -Value "@echo off`r`nexit /b 23"
$output = & powershell.exe -NoProfile -File $entry -ConfigPath $configPath -WorkspacePath $workspacePath -Target $app -RunId $oldId -NewPlan -EditorPath $failedEditor 2>&1 | Out-String
Assert ($LASTEXITCODE -eq 0 -and $output.Contains('Contexto salvo; nao foi possivel abrir o editor:') -and $output.Contains('23')) 'Falha do editor deve ser informada sem perder o contexto preparado.'
$savedPrompt = @($output -split '\r?\n' | Where-Object { $_.StartsWith('Prompt preparado: ') })[0].Substring('Prompt preparado: '.Length)
Assert (Test-Path -LiteralPath $savedPrompt) 'Falha do editor apagou o prompt preparado.'
Write-Output 'PASS: contexto unico e fixo, preservacao de evidencias/fontes, revalidacao e entrada real sem ferramentas externas.'

# Compatibilidade: revisao antiga explicita continua legivel; novo menu usa planejamento unico.
Copy-Item -LiteralPath (Join-Path $root '.github/prompts/revisar-lote.prompt.md') -Destination (Join-Path $fixture '.github/prompts/revisar-lote.prompt.md')
$indexPath = Join-Path $fixture '.harness/evidencias/pasta com espacos/LEIA-ME.md'
$null = New-Item -ItemType Directory -Path (Split-Path -Parent $indexPath) -Force
Set-Content -LiteralPath $indexPath 'Indice de teste: somente observacoes, sem novas evidencias.' -Encoding UTF8
$protected = @(@($prepared.ContextPath,$prepared.PlanPath,$prepared.TodoPath,$indexPath) | ForEach-Object { Get-FileHash -LiteralPath $_ })
Reject { Select-MtaPreviousPlanning $otherContext -Required } 'Revisao sem proposta persistida aceita.'
Reject { New-MtaPlanningContext $context -RunId $oldId -Operation revisar-lote -EvidenceIndexPath $indexPath } 'Revisao sem Previous aceita pela API.'
Reject { New-MtaPlanningContext $context -RunId $oldId -Operation revisar-lote -PreviousRequestId $prepared.RequestId } 'Revisao sem indice aceita pela API.'
$reviewArgs = @('-NoProfile','-File',$entry,'-ConfigPath',$configPath,'-WorkspacePath',$workspacePath,'-Target',$app,'-RunId',$oldId,'-Operation','revisar-lote','-EditorPath',$editorPath)
$output = @('1',$indexPath) | & powershell.exe @reviewArgs 2>&1 | Out-String
Assert ($LASTEXITCODE -eq 0) "Preparo de revisao pelo menu falhou: $output"
Assert ($output.Contains('Alternativa no chat: /revisar-lote ') -and -not $output.Contains('Alternativa no chat: /planejar-lotes ')) 'Revisao deve orientar somente o comando adequado.'
Assert ($output.Contains($indexPath)) 'Chamada nao inclui o indice explicito.'
$receiptLine = @($output -split '\r?\n' | Where-Object { $_.StartsWith('Recibo de contexto e hashes: ') })
$reviewReceipt = Get-Content -LiteralPath ($receiptLine[0].Substring('Recibo de contexto e hashes: '.Length)) -Raw -Encoding UTF8 | ConvertFrom-Json
Assert ($reviewReceipt.Previous.RequestId -eq $prepared.RequestId -and $reviewReceipt.RunId -eq $oldId) 'Revisao perdeu Previous ou trocou MTA.'
Assert ($reviewReceipt.Operation -eq 'revisar-lote' -and $reviewReceipt.EvidenceIndexPath -eq $indexPath.Replace('\','/')) 'Recibo nao identifica modo e indice.'
Assert (@($reviewReceipt.EvidenceHashes.PSObject.Properties).Count -eq 4) 'Evidencias complementares nao devem receber hashes.'
$editorArgs = Get-Content -LiteralPath (Join-Path $scripts 'editor-args.json') -Raw | ConvertFrom-Json
Assert ((Split-Path -Leaf $editorArgs[1]) -eq 'revisar-lote.prompt.md') 'Editor abriu planejamento em vez de revisao.'
$reviewPrompt = Get-Content -LiteralPath $editorArgs[1] -Raw -Encoding UTF8
Assert ($reviewPrompt.StartsWith((Get-Content -LiteralPath (Join-Path $fixture '.github/prompts/revisar-lote.prompt.md') -Raw -Encoding UTF8).TrimEnd())) 'Prompt de revisao perdeu seu contrato.'
Assert ($reviewPrompt.Contains($indexPath.Replace('\','/')) -and $reviewPrompt.Contains('planejar-lotes.prompt.md')) 'Prompt executavel nao fornece os dois caminhos ao revisor.'
$count = @(Get-ChildItem -LiteralPath (Join-Path $fixture '.harness/planning') -Recurse -Filter 'context.json' -File).Count
foreach ($answers in @(@('q'),@(''),@('1','q'),@('1',''),@('1',(Join-Path $fixture 'ausente.md')))) {
    $output = $answers | & powershell.exe @reviewArgs 2>&1 | Out-String
    Assert ($LASTEXITCODE -eq 1) "Revisao aceitou selecao cancelada/incompleta: $answers"
    Assert (@(Get-ChildItem -LiteralPath (Join-Path $fixture '.harness/planning') -Recurse -Filter 'context.json' -File).Count -eq $count) 'Entrada invalida gerou contexto.'
}
foreach ($file in $protected) { Assert ((Get-FileHash -LiteralPath $file.Path).Hash -eq $file.Hash) 'Revisao modificou proposta anterior ou indice.' }
# CLI explicita deve ter os mesmos vinculos; o modo Planejar continua disponivel no menu.
$explicitArgs = @('-NoProfile','-File',$entry,'-ConfigPath',$configPath,'-WorkspacePath',$workspacePath,'-Target',$app,'-RunId',$oldId,'-NoOpen')
$output = & powershell.exe @explicitArgs -Operation revisar-lote -PreviousRequestId $prepared.RequestId -EvidenceIndexPath $indexPath 2>&1 | Out-String
Assert ($LASTEXITCODE -eq 0 -and $output.Contains('Alternativa no chat: /revisar-lote ')) 'Revisao por parametros falhou.'
$output = & powershell.exe @explicitArgs -Operation revisar-lote -NewPlan 2>&1 | Out-String
Assert ($LASTEXITCODE -eq 1 -and $output.Contains('nao use NewPlan')) 'Revisao aceitou iniciar independente.'
$output = '1' | & powershell.exe @explicitArgs -SelectOperation -NewPlan 2>&1 | Out-String
Assert ($LASTEXITCODE -eq 0 -and $output.Contains('Alternativa no chat: /planejar-lotes ') -and -not $output.Contains('Alternativa no chat: /revisar-lote ')) 'Menu perdeu modo de planejamento.'
Write-Output 'PASS: revisao explicita, Previous obrigatorio, indice, comando/editor corretos e cancelamento sem escrita.'
# Evidencias desde a proposta inicial e revisao no mesmo prompt.
$initialWithEvidence = New-MtaPlanningContext $context -RunId $oldId -EvidenceIndexPath $indexPath
$initialReceipt = Get-Content $initialWithEvidence.ContextPath -Raw | ConvertFrom-Json
Assert ($initialReceipt.Previous -eq $null -and $initialReceipt.EvidenceIndexPath -eq $indexPath.Replace('\','/')) 'Proposta inicial nao aceita evidencias.'
Assert ($initialReceipt.MigrationSnapshot -and (Test-Path $initialReceipt.MigrationPath)) 'Registro e escolhas nao vinculados ao recibo.'
$updatedUnified = New-MtaPlanningContext $context -RunId $oldId -PreviousRequestId $prepared.RequestId -EvidenceIndexPath $indexPath
Assert (-not $updatedUnified.ReviewPromptPath -and (Split-Path $updatedUnified.PromptPath -Leaf) -eq 'planejar-lotes.prompt.md') 'Atualizacao ainda exige segundo prompt.'
Copy-Item (Join-Path $root '.github/prompts/manter-migracao.prompt.md') (Join-Path $fixture '.github/prompts/manter-migracao.prompt.md')
$maintenanceArgs = @('-NoProfile','-File',$entry,'-ConfigPath',$configPath,'-WorkspacePath',$workspacePath,'-Target',$app,'-NoOpen')
$registerBeforeMaintenance = [IO.File]::ReadAllText($initialReceipt.MigrationPath)
$output = @('2','2') | & powershell.exe @maintenanceArgs -SelectOperation 2>&1 | Out-String
Assert ($LASTEXITCODE -eq 0 -and $output.Contains('manter-migracao.prompt.md')) 'Menu deve preparar manutencao sem novo MTA.'
$registerAfterMaintenance = [IO.File]::ReadAllText($initialReceipt.MigrationPath)
$withoutReconciliation = [regex]::Replace($registerAfterMaintenance, '(?s)<!-- reconciliacao:inicio -->.*?<!-- reconciliacao:fim -->\r?\n\r?\n', '')
Assert ($withoutReconciliation -ceq $registerBeforeMaintenance -and $registerAfterMaintenance.Contains('Estado: PENDENTE')) 'Manutencao deve preservar catalogo/texto e acrescentar apenas pendencia de reconciliacao.'
$output = & powershell.exe @maintenanceArgs -Operation manter-migracao -WithoutMta -MigrationSourcePath $prepared.PlanPath -EvidenceIndexPath $indexPath 2>&1 | Out-String
Assert ($LASTEXITCODE -eq 0) 'Documento-base e indice existentes recusados.'
$count = @(Get-ChildItem (Join-Path $fixture '.harness/planning') -Filter context.json -Recurse).Count
$output = @('2','q') | & powershell.exe @maintenanceArgs -SelectOperation 2>&1 | Out-String
Assert ($LASTEXITCODE -eq 1 -and @(Get-ChildItem (Join-Path $fixture '.harness/planning') -Filter context.json -Recurse).Count -eq $count) 'Cancelar manutencao criou contexto.'
Write-Output 'PASS: menu unificado, manutencao sem scan e documento/evidencias existentes.'


# Historico antigo continua acessivel sem mover documentos ou reescrever recibos.
$legacy = $receipt | ConvertTo-Json -Depth 12 | ConvertFrom-Json
$legacy.RequestId = '66666666666666666666666666666666'
$legacy | Add-Member NoteProperty Git ([pscustomobject]@{Status='VERIFIED';Branch='branch-antiga';Head='historico';Policy=@{workBranch='inexistente'}}) -Force
$legacy.PreparedAtUtc = '2026-09-23T10:00:00Z'
$legacyFolder = Join-Path $fixture ('.harness/planning/' + $context.Active.name + '/' + $oldId + '/' + $legacy.RequestId)
foreach ($pair in @(@('ContextPath','context.json'),@('PlanPath','plan.md'),@('TodoPath','todo.md'))) {
    $legacy.($pair[0]) = (Join-Path $legacyFolder $pair[1]).Replace('\','/')
}
Write-HarnessJson $legacy.ContextPath $legacy
Set-Content -LiteralPath $legacy.PlanPath 'PLANO-ANTIGO'
Set-Content -LiteralPath $legacy.TodoPath 'TODO-ANTIGO'
$legacyBefore = @(@($legacy.ContextPath,$legacy.PlanPath,$legacy.TodoPath) | ForEach-Object { Get-FileHash -LiteralPath $_ })
$history = @(Get-MtaPlanningHistory $context)
Assert ($history.Count -eq 2 -and $history[1].RequestId -eq $legacy.RequestId) 'Historico deve combinar formatos e ordenar pela data do recibo.'
$renamedContext = $context | ConvertTo-Json -Depth 12 | ConvertFrom-Json
$renamedContext.Active.label = 'Nome / renomeado: projeto'
Assert (@(Get-MtaPlanningHistory $renamedContext).Count -eq 2) 'Renomear rotulo perdeu historico do mesmo projeto.'
$renamed = New-MtaPlanningContext $renamedContext -RunId $newId -PreviousRequestId $legacy.RequestId
$renamedReceipt = Get-Content -LiteralPath $renamed.ContextPath -Raw | ConvertFrom-Json
Assert ($renamedReceipt.Previous.RequestId -eq $legacy.RequestId) 'Novo formato perdeu vinculo com planejamento antigo.'
Assert ($renamedReceipt.Run -eq $newRun.Replace('\','/')) 'Contexto perdeu o caminho real do MTA com nome legivel apos renomear rotulo.'
$renamedProject = Split-Path -Leaf (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $renamed.PromptPath)))
Assert ($renamedProject -match '^Nome---renomeado--projet__[a-f0-9]{12}$') 'Rotulo com separadores nao foi convertido em nome de pasta seguro e limitado.'
$otherContext.Active.label = $context.Active.label
$sameLabel = New-MtaPlanningContext $otherContext -RunId '44444444444444444444444444444444'
Assert ((Split-Path -Parent $sameLabel.PlanPath) -ne $requestFolder) 'Projetos homonimos compartilharam destinos.'
Reject { Select-MtaPreviousPlanning $otherContext -ForOpen -RequestId $legacy.RequestId } 'Abertura aceitou planejamento de outro projeto.'
$legacy.TodoPath = $otherPrepared.TodoPath.Replace('\','/')
Write-HarnessJson $legacy.ContextPath $legacy
Assert (@(Get-MtaPlanningHistory $context).Count -eq 1) 'Historico aceitou destino de outro projeto no recibo.'
$legacy.TodoPath = (Join-Path $legacyFolder 'todo.md').Replace('\','/')
Write-HarnessJson $legacy.ContextPath $legacy

# Abrir pelos argumentos da tarefa: selecionar projeto, depois documento, sem gerar contexto.
$openEntry = Join-Path $scripts 'abrir-planejamento.ps1'
Copy-Item -LiteralPath (Join-Path $root 'scripts/abrir-planejamento.ps1') -Destination $openEntry
$openArgs = @('-NoProfile','-File',$openEntry,'-ConfigPath',$configPath,'-WorkspacePath',$workspacePath,'-SelectTarget','-EditorPath',$editorPath)
$documentsBefore = @(Get-ChildItem -LiteralPath (Join-Path $fixture '.harness/planning') -Recurse -File | Get-FileHash)
$output = @('1','2') | & powershell.exe @openArgs 2>&1 | Out-String
Assert ($LASTEXITCODE -eq 0 -and $output.Contains('Planejado:') -and $output.Contains($legacy.RequestId)) 'Abertura nao chegou ao historico antigo por projeto/data.'
$editorArgs = Get-Content -LiteralPath (Join-Path $scripts 'editor-args.json') -Raw | ConvertFrom-Json
Assert ($editorArgs.Count -eq 3 -and $editorArgs[0] -eq '--reuse-window' -and $editorArgs[1] -eq $legacy.PlanPath -and $editorArgs[2] -eq $legacy.TodoPath) 'Editor nao recebeu somente o plano e to-do selecionados.'
$editorHash = (Get-FileHash -LiteralPath (Join-Path $scripts 'editor-args.json')).Hash
$output = @('1','q') | & powershell.exe @openArgs 2>&1 | Out-String
Assert ($LASTEXITCODE -eq 1 -and $output.Contains('cancelada')) 'Abertura nao respeitou cancelamento.'
Assert ((Get-FileHash -LiteralPath (Join-Path $scripts 'editor-args.json')).Hash -eq $editorHash) 'Cancelar acionou o editor.'
$output = & powershell.exe -NoProfile -File $openEntry -ConfigPath $configPath -WorkspacePath $workspacePath -Target $app -RequestId $prepared.RequestId -EditorPath $editorPath 2>&1 | Out-String
Assert ($LASTEXITCODE -eq 0) 'Abertura por RequestId do formato novo falhou.'
Assert (-not $output.Contains('Git antes de retomar') -and -not $output.Contains('conferir Git do lote')) 'Abertura ainda exige gate Git.'
$editorArgs = Get-Content -LiteralPath (Join-Path $scripts 'editor-args.json') -Raw | ConvertFrom-Json
Assert ($editorArgs[1] -eq $receipt.PlanPath -and $editorArgs[2] -eq $receipt.TodoPath) 'Abertura do formato novo escolheu outro planejamento.'
foreach ($file in @($documentsBefore) + @($legacyBefore)) {
    Assert ((Get-FileHash -LiteralPath $file.Path).Hash -eq $file.Hash) 'Abertura/continuidade alterou documento existente.'
}
Assert (@(Get-ChildItem -LiteralPath (Join-Path $fixture '.harness/planning') -Recurse -File).Count -eq $documentsBefore.Count) 'Abertura criou documentos.'
Write-Output 'PASS: pastas legiveis, historico antigo preservado, renomeacao, homonimos e abertura/cancelamento reais.'

# Nomes amigaveis nao autorizam escolher silenciosamente entre copias da rodada.
$duplicateRun = Join-Path $fixture ('.harness/runs/Copia__' + (Get-HarnessProjectKey $context.Active.name) + '/mta_2026-09-25_07-00-00-0300__222222222222')
Write-HarnessJson (Join-Path $duplicateRun 'manifest.json') (Get-Content (Join-Path $newRun 'manifest.json') -Raw | ConvertFrom-Json)
Reject { Select-MtaPlanningRun $context -RunId $newId } 'RunId duplicado foi selecionado silenciosamente.'
Write-HarnessJson (Join-Path $fixture ('.harness/last-' + $context.Active.name + '.json')) @{RunId=$newId}
Reject { Get-LastMtaReport $context } 'Ultimo relatorio aceitou RunId ambiguo.'
Write-Output 'PASS: rodadas ambiguas recusadas no planejamento e no relatorio.'
