#requires -Version 5.1
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $root 'scripts/Harness.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $root 'scripts/HarnessPlanning.psm1') -Force -DisableNameChecking
function Assert($condition, $message) { if (-not $condition) { throw $message } }
function Reject($action, $message) {
    $rejected = $false
    try { & $action | Out-Null } catch { $rejected = $true }
    Assert $rejected $message
}
$area = Join-Path $root ('.harness/tests/i' + [guid]::NewGuid().ToString('N').Substring(0,8))
$fixture = Join-Path $area 'h'
$app = Join-Path $area 'app com espacos'
$other = Join-Path $area 'outra'
foreach ($path in @($fixture,$app,$other)) { $null = [IO.Directory]::CreateDirectory($path) }
Set-Content -LiteralPath (Join-Path $app 'pom.xml') '<project/>'
$context = [pscustomobject]@{Root=$fixture;Active=[pscustomobject]@{name='app';label='Aplicacao';path=$app}}
$runId = '11111111111111111111111111111111'
$requestId = '22222222222222222222222222222222'
$run = Join-Path $fixture ('.harness/runs/app/' + $runId)
Write-HarnessJson (Join-Path $run 'manifest.json') @{Project='app';RunId=$runId;Source=$app;CreatedAtUtc='2026-09-30T10:00:00Z'}
Write-HarnessJson (Join-Path $run 'result.json') @{Project='app';RunId=$runId;Status='SUCCEEDED';ExitCode=0;SourceUnchanged=$true;SnapshotOriginalFilesUnchanged=$true;RulesUnchanged=$true;UnexpectedAddedFiles=@()}
foreach ($file in @('output/output.yaml','output/dependencies.yaml','output/static-report/index.html','rules/regra.yaml')) {
    $path = Join-Path $run $file
    $null = [IO.Directory]::CreateDirectory((Split-Path -Parent $path))
    Set-Content -LiteralPath $path 'fixture'
}
$folder = Join-Path $fixture ('.harness/planning/app/' + $runId + '/' + $requestId)
$plan = Join-Path $folder 'plan.md'
$todo = Join-Path $folder 'todo.md'
$receipt = Join-Path $folder 'context.json'
$hashes = @{}
foreach ($pair in @(@('Manifest','manifest.json'),@('Result','result.json'),@('Findings','output/output.yaml'),@('Dependencies','output/dependencies.yaml'))) {
    $hashes[$pair[0]] = (Get-FileHash -LiteralPath (Join-Path $run $pair[1])).Hash
}
$record = @{RequestId=$requestId;RunId=$runId;Project='app';Source=$app;Purpose='application-remediation';PreparedAtUtc='2026-09-30T11:00:00Z';CreatedAtUtc='2026-09-30T10:00:00Z';ContextPath=$receipt;PlanPath=$plan;TodoPath=$todo;EvidenceHashes=$hashes}
Write-HarnessJson $receipt $record
Set-Content -LiteralPath $plan 'LOTE-001: PROPOSTA - NAO APROVADA'
Set-Content -LiteralPath $todo '- [ ] GO humano'
$templates = Join-Path $fixture '.github/prompts'
$null = [IO.Directory]::CreateDirectory($templates)
$template = Join-Path $root '.github/prompts/implementar-lote.prompt.md'
if (Test-Path -LiteralPath $template) { Copy-Item -LiteralPath $template -Destination $templates }
$before = @(Get-ChildItem -LiteralPath $area -Recurse -File | Get-FileHash)
$prepared = New-MtaImplementationPrompt $context -RequestId $requestId
$content = Get-Content -LiteralPath $prepared.PromptPath -Raw -Encoding UTF8
$data = [regex]::Match($content, '(?s)```json\s*(\{.*?\})\s*```').Groups[1].Value | ConvertFrom-Json
Assert ($data.RequestId -eq $requestId -and $data.RunId -eq $runId -and $data.Project -eq 'app') 'Identidade da proposta perdida.'
Assert ($data.PlanPath -eq $plan.Replace('\','/') -and $data.TodoPath -eq $todo.Replace('\','/')) 'Destinos divergentes.'
Assert ($data.ContextSha256 -eq (Get-FileHash $receipt).Hash -and $data.PlanSha256 -eq (Get-FileHash $plan).Hash -and $data.TodoSha256 -eq (Get-FileHash $todo).Hash) 'Versao dos documentos nao vinculada.'
Assert ((Split-Path -Parent $prepared.PromptPath) -eq $folder) 'Prompt fora da solicitacao.'
Assert ($content.StartsWith((Get-Content -LiteralPath $template -Raw -Encoding UTF8).TrimEnd())) 'Contrato nao propagado.'
foreach ($file in $before) { Assert ((Get-FileHash -LiteralPath $file.Path).Hash -eq $file.Hash) 'Preparo alterou fonte, evidencias ou documentos.' }
$again = New-MtaImplementationPrompt $context -RequestId $requestId
Assert ($again.PromptPath -ne $prepared.PromptPath -and (Test-Path $prepared.PromptPath)) 'Repeticao sobrescreveu prompt.'
Assert ((Get-Content $plan -Raw).Contains('NAO APROVADA')) 'Preparo concedeu GO.'
$promptCount = @(Get-ChildItem $folder -Filter '*.prompt.md').Count
Reject { New-MtaImplementationPrompt $context -RequestId '../fora' } 'RequestId invalido aceito.'
$otherContext = [pscustomobject]@{Root=$fixture;Active=[pscustomobject]@{name='app';label='Outra';path=$other}}
Reject { New-MtaImplementationPrompt $otherContext -RequestId $requestId } 'Aceitou outra fonte.'
$record.PlanPath = Join-Path $other 'plan.md'
Write-HarnessJson $receipt $record
Reject { New-MtaImplementationPrompt $context -RequestId $requestId } 'Aceitou destino fora da solicitacao.'
$record.PlanPath = $plan
Write-HarnessJson $receipt $record
Move-Item -LiteralPath $todo -Destination ($todo + '.saved')
Reject { New-MtaImplementationPrompt $context -RequestId $requestId } 'Aceitou par incompleto.'
Move-Item -LiteralPath ($todo + '.saved') -Destination $todo
$findings = Join-Path $run 'output/output.yaml'
$original = [IO.File]::ReadAllBytes($findings)
Add-Content -LiteralPath $findings 'evidencia adulterada'
Reject { New-MtaImplementationPrompt $context -RequestId $requestId } 'Aceitou hash MTA divergente.'
[IO.File]::WriteAllBytes($findings, $original)
$lease = [IO.File]::Open((Join-Path $fixture '.harness/planning.lock'), 'OpenOrCreate','ReadWrite','None')
try { Reject { New-MtaImplementationPrompt $context -RequestId $requestId } 'Ignorou limpeza concorrente.' } finally { $lease.Dispose() }
Assert (@(Get-ChildItem $folder -Filter '*.prompt.md').Count -eq $promptCount) 'Falha criou prompt.'
Write-Output 'PASS: preparo de implementacao vinculado, sem GO inferido, isolado e com historico preservado.'

# Entrada real, sem Maven/MTA/Copilot: ferramentas deliberadamente nao configuradas.
$scripts = Join-Path $fixture 'scripts'
$null = [IO.Directory]::CreateDirectory($scripts)
foreach ($name in @('Harness.psm1','HarnessPlanning.psm1','preparar-implementacao.ps1')) {
    Copy-Item -LiteralPath (Join-Path $root ('scripts/' + $name)) -Destination $scripts
}
$config = Get-Content -LiteralPath (Join-Path $root 'config/harness.example.json') -Raw | ConvertFrom-Json
$config.repositories = @(@{name='app';path=$app})
$config.activeProject = 'app'
$configPath = Join-Path $fixture 'config.json'
Write-HarnessJson $configPath $config
$entry = Join-Path $scripts 'preparar-implementacao.ps1'
$cliArgs = @('-NoProfile','-File',$entry,'-ConfigPath',$configPath,'-Target','app','-NoOpen')
$protected = @(@($receipt,$plan,$todo,$configPath,(Join-Path $app 'pom.xml'),$findings) | ForEach-Object { Get-FileHash -LiteralPath $_ })
foreach ($answer in @('q','','99')) {
    $output = $answer | & powershell.exe @cliArgs 2>&1 | Out-String
    Assert ($LASTEXITCODE -eq 1 -and $output.Contains('cancelada')) "Entrada aceitou cancelamento/invalido: $answer"
    Assert (@(Get-ChildItem $folder -Filter '*.prompt.md').Count -eq $promptCount) 'Cancelar criou prompt.'
}
$editor = Join-Path $scripts 'editor simulado.ps1'
@'
param([Parameter(ValueFromRemainingArguments=$true)][string[]]$EditorArguments)
$EditorArguments | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $PSScriptRoot 'editor-args.json') -Encoding UTF8
'@ | Set-Content -LiteralPath $editor -Encoding UTF8
$output = '1' | & powershell.exe -NoProfile -File $entry -ConfigPath $configPath -Target app -EditorPath $editor 2>&1 | Out-String
Assert ($LASTEXITCODE -eq 0 -and $output.Contains('/implementar-lote ') -and $output.Contains($requestId)) "Menu real nao preparou a solicitacao: $output"
$editorArgs = Get-Content -LiteralPath (Join-Path $scripts 'editor-args.json') -Raw | ConvertFrom-Json
Assert ($editorArgs.Count -eq 2 -and $editorArgs[0] -eq '--reuse-window' -and (Test-Path -LiteralPath $editorArgs[1])) 'Editor recebeu envio/chat ou arquivo inexistente.'
Assert ((Split-Path -Leaf $editorArgs[1]) -match '^implementar-lote_[a-f0-9]{12}\.prompt\.md$') 'Editor abriu documento errado.'
$output = & powershell.exe @cliArgs -RequestId $requestId 2>&1 | Out-String
Assert ($LASTEXITCODE -eq 0 -and $output.Contains('Prompt preparado:')) 'Selecao explicita/NoOpen falhou.'
$output = & powershell.exe -NoProfile -File $entry -ConfigPath $configPath -Target app -RequestId $requestId -EditorPath (Join-Path $fixture 'ausente.exe') 2>&1 | Out-String
Assert ($LASTEXITCODE -eq 0 -and $output.Contains('Prompt salvo; nao foi possivel abrir')) 'Falha do editor perdeu alternativa de abertura.'
foreach ($file in $protected) { Assert ((Get-FileHash -LiteralPath $file.Path).Hash -eq $file.Hash) 'CLI alterou fonte/configuracao/evidencias/documentos.' }
# Atualizar o plano nao reescreve o prompt antigo; preparar de novo fixa a versao nova.
Add-Content -LiteralPath $plan 'Observacao posterior do desenvolvedor'
$newVersion = New-MtaImplementationPrompt $context -RequestId $requestId
$newText = Get-Content -LiteralPath $newVersion.PromptPath -Raw
$newData = [regex]::Match($newText, '(?s)```json\s*(\{.*?\})\s*```').Groups[1].Value | ConvertFrom-Json
Assert ($newData.PlanSha256 -ne $data.PlanSha256 -and (Get-Content $prepared.PromptPath -Raw) -eq $content) 'Versionamento alterou historico ou ignorou edicao.'
Write-Output 'PASS: menus reais, cancelamento, editor sem envio, NoOpen, falha de editor e nova versao de documentos.'

# Formato atual legivel: reutilizar os mesmos destinos sem nova solicitacao.
$record.RequestId = '33333333333333333333333333333333'
$readableFolder = Join-Path $fixture ('.harness/planning/' + (Get-HarnessProjectFolder $context.Active) + '/mta_2026-09-30_07-00-00-0300__111111111111/plano_2026-09-30_08-00-00-0300__333333333333')
$record.ContextPath = Join-Path $readableFolder 'context.json'
$record.PlanPath = Join-Path $readableFolder 'plan.md'
$record.TodoPath = Join-Path $readableFolder 'todo.md'
Write-HarnessJson $record.ContextPath $record
Copy-Item -LiteralPath $plan -Destination $record.PlanPath
Copy-Item -LiteralPath $todo -Destination $record.TodoPath
$readable = New-MtaImplementationPrompt $context -RequestId $record.RequestId
Assert ((Split-Path -Parent $readable.PromptPath) -eq $readableFolder -and $readable.PlanPath -eq $record.PlanPath) 'Formato legivel nao preservou solicitacao/destinos.'
Write-Output 'PASS: formato atual legivel e formato legado selecionaveis sem mover historico.'
