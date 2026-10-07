#requires -Version 5.1
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $root 'scripts/Harness.psm1') -Force -DisableNameChecking
function Assert($condition, $message) { if (-not $condition) { throw $message } }
function Reject($action, $message) {
    $failed = $false
    try { & $action | Out-Null } catch { $failed = $true }
    Assert $failed $message
}
$area = Join-Path $root ('.harness/tests/priorizacao-' + [guid]::NewGuid().ToString('N'))
$fixture = Join-Path $area 'harness'
$projects = @(foreach ($name in @('app-a','app-b','sem-registro')) {
    $source = Join-Path $area $name
    $null = [IO.Directory]::CreateDirectory($source)
    Set-Content (Join-Path $source 'pom.xml') '<project/>'
    [pscustomobject]@{name=$name;label=$name;path=$source}
})
$context = [pscustomobject]@{Root=$fixture;Projects=$projects;WorkspacePath=$null;ConfigPath=(Join-Path $fixture 'config.json')}
foreach ($project in $projects[0..1]) {
    $register = Initialize-HarnessMigration $fixture $project
    $text = [IO.File]::ReadAllText($register.MigrationPath)
    $text = $text.Replace('<!-- mta:fim -->', "| r::1 | Regra | mandatory | 30 | PRESENTE | A DEFINIR | NAO ANALISADA | teste |`n<!-- mta:fim -->")
    [IO.File]::WriteAllText($register.MigrationPath, $text)
}
$index = Join-Path $fixture '.harness/projetos/indice-projetos.md'
Set-Content $index '# Indice: dados de teste'
foreach ($relative in @('doc/especificacoes/planejamento-copilot.md','.github/prompts/priorizar-issues.prompt.md')) {
    $destination = Join-Path $fixture $relative
    $null = [IO.Directory]::CreateDirectory((Split-Path $destination -Parent))
    if (Test-Path (Join-Path $root $relative)) { Copy-Item (Join-Path $root $relative) $destination }
}
$before = @(Get-ChildItem $area -Recurse -File | Get-FileHash)
Import-Module (Join-Path $root 'scripts/HarnessPrioritization.psm1') -Force -DisableNameChecking
$prepared = New-HarnessPrioritizationContext $context -Percentage 10 -Mode Recreate
$receipt = Get-Content $prepared.ContextPath -Raw | ConvertFrom-Json
Assert ($receipt.Purpose -eq 'issue-prioritization' -and $receipt.Percentage -eq 10 -and $receipt.InitialTotal -eq 0 -and $receipt.SliceSize -eq 0) 'Tipo/limite incorreto.'
Assert ($receipt.Projects.Count -eq 3 -and $receipt.Projects[2].MigrationSnapshot -eq $null) 'Projetos ausentes devem permanecer visiveis sem registro inventado.'
Assert ($receipt.Projects[0].Source -eq $projects[0].path -and $receipt.Projects[0].MigrationSnapshot.Contains('r::1')) 'Registro nao vinculado ao Source.'
Assert ($receipt.Projects[0].Diagnostics.Count -gt 0) 'Ausencia de origem MTA nao informada.'
$promptText = [IO.File]::ReadAllText($prepared.PromptPath)
$frontmatter = [regex]::Match($promptText, '(?s)\A---\s*\r?\n(.*?)\r?\n---').Groups[1].Value
Assert ($frontmatter -match '(?m)^agent: devsquad\s*$') 'Priorizacao perdeu o condutor DevSquad.'
$toolLine = [regex]::Match($frontmatter, '(?m)^tools: \[(.*?)\]').Groups[1].Value
$mcpTools = @([regex]::Matches($toolLine, '[''"](harnessissues/[^''"]+)[''"]', 'IgnoreCase') | ForEach-Object { $_.Groups[1].Value })
Assert (@(Compare-Object @('harnessissues/auditar_base','harnessissues/listar_issues','harnessissues/obter_issue') $mcpTools -CaseSensitive).Count -eq 0) 'Priorizacao nao propagou as tres referencias MCP exatas.'
$selection = [regex]::Match($promptText, '(?s)```json\s*(\{[^`]*\})\s*```\s*$').Groups[1].Value | ConvertFrom-Json
Assert ($selection.RequestId -eq $receipt.RequestId -and $selection.ContextPath -eq $prepared.ContextPath -and $selection.RankingPath -eq $prepared.RankingPath -and $selection.Percentage -eq 10) 'Prompt nao espelha o recibo preparado.'
Assert ($receipt.ProjectIndexSnapshot -eq [IO.File]::ReadAllText($index) -and $receipt.ContractSnapshot -eq [IO.File]::ReadAllText((Join-Path $fixture 'doc/especificacoes/planejamento-copilot.md'))) 'Snapshots nao preservam o contexto.'
Assert (-not (Test-Path $prepared.RankingPath)) 'Preparo inventou ranking.'
foreach ($file in $before) { Assert ((Get-FileHash $file.Path).Hash -eq $file.Hash) 'Preparo alterou entradas.' }
$again = New-HarnessPrioritizationContext $context -Percentage 10 -Mode Recreate
Assert ($again.RequestId -ne $prepared.RequestId -and (Test-Path $prepared.PromptPath)) 'Historico sobrescrito.'
foreach ($invalid in @('0','0,001','100.01','101','-1','NaN','1e1','1,000.00','')) {
    Reject { New-HarnessPrioritizationContext $context -Percentage $invalid -Mode Recreate } ('Percentual invalido aceito: ' + $invalid)
}
foreach ($valid in @('0,01','0.01%','50','100,00%')) {
    $null = New-HarnessPrioritizationContext $context -Percentage $valid -Mode Recreate
}
$lease = [IO.File]::Open((Join-Path $fixture '.harness/planning.lock'), 'OpenOrCreate','ReadWrite','None')
try { Reject { New-HarnessPrioritizationContext $context -Percentage 10 -Mode Recreate } 'Lock ignorado.' } finally { $lease.Dispose() }
Move-Item $index ($index + '.saved')
Reject { New-HarnessPrioritizationContext $context -Percentage 10 -Mode Recreate } 'Indice ausente aceito.'
Move-Item ($index + '.saved') $index
Write-Output 'PASS: priorizacao multi-projeto, limites, lacunas, preservacao e historico.'

# Rodada recebida: origem pode diferir do Source local, sem escolher ultimo MTA.
$runId = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
$run = Join-Path $area 'mta recebido'
foreach ($folder in @('input','rules','output/static-report')) { $null = [IO.Directory]::CreateDirectory((Join-Path $run $folder)) }
Write-HarnessJson (Join-Path $run 'manifest.json') @{RunId=$runId;Project='origem';Source='Z:/colega/app';CreatedAtUtc='2026-10-01T10:00:00Z'}
Write-HarnessJson (Join-Path $run 'result.json') @{RunId=$runId;Project='origem';Status='SUCCEEDED';ExitCode=0;SourceUnchanged=$true;SnapshotOriginalFilesUnchanged=$true;RulesUnchanged=$true;UnexpectedAddedFiles=@()}
foreach ($file in @('output/output.yaml','output/dependencies.yaml','output/static-report/index.html')) { Set-Content (Join-Path $run $file) 'fixture' }
$paths = Get-HarnessMigrationPaths $fixture $projects[0]
$original = [IO.File]::ReadAllText($paths.MigrationPath)
$origin = @{RunId=$runId;Project='origem';Source='Z:/colega/app';Run=$run} | ConvertTo-Json -Compress
$record = $original.Replace("`nAGUARDANDO MTA", ("`n<!-- MTA " + $origin + " -->`nRodada MTA: $runId."))
[IO.File]::WriteAllText($paths.MigrationPath, $record)
$received = New-HarnessPrioritizationContext $context -Percentage 10 -Mode Recreate
$receipt = Get-Content $received.ContextPath -Raw | ConvertFrom-Json
Assert ($receipt.Projects[0].Mta.RunId -eq $runId -and $receipt.Projects[0].Mta.MtaOrigin.Source -eq 'Z:/colega/app') 'Origem recebida nao preservada.'
Assert ($receipt.Projects[0].Mta.AnalysisSource -eq (Join-Path $run 'input') -and $receipt.Projects[0].Source -eq $projects[0].path) 'Snapshot confundido com Source.'
Assert ($receipt.Projects[0].Mta.EvidenceHashes.Findings -eq (Get-FileHash (Join-Path $run 'output/output.yaml')).Hash) 'Hash ausente.'
Assert ($receipt.Projects[1].Mta -eq $null) 'MTA do primeiro projeto vazou para outro.'
[IO.File]::WriteAllText($paths.MigrationPath, $record.Replace('Rodada MTA: ' + $runId, ('Rodada MTA: ' + ('b' * 32))))
$conflict = New-HarnessPrioritizationContext $context -Percentage 10 -Mode Recreate
$conflictReceipt = Get-Content $conflict.ContextPath -Raw | ConvertFrom-Json
Assert ($conflictReceipt.Projects[0].Mta -eq $null -and ($conflictReceipt.Projects[0].Diagnostics -join ' ') -match 'diverge') 'Conflito de rodada foi aceito.'
[IO.File]::WriteAllText($paths.MigrationPath, $record.Replace($projects[0].path, $projects[1].path))
$conflict = New-HarnessPrioritizationContext $context -Percentage 10 -Mode Recreate
Assert (((Get-Content $conflict.ContextPath -Raw | ConvertFrom-Json).Projects[0].Diagnostics -join ' ') -match 'Source') 'Registro de outro projeto aceito.'
[IO.File]::WriteAllText($paths.MigrationPath, $record)

# Integridade e evidencias essenciais nao podem virar recomendacao confiavel.
$resultPath = Join-Path $run 'result.json'
$resultText = [IO.File]::ReadAllText($resultPath)
$failedRun = $resultText | ConvertFrom-Json
$failedRun.SourceUnchanged = $false
Write-HarnessJson $resultPath $failedRun
$conflict = New-HarnessPrioritizationContext $context -Percentage 10 -Mode Recreate
$conflictReceipt = Get-Content $conflict.ContextPath -Raw | ConvertFrom-Json
Assert ($conflictReceipt.Projects[0].Mta -eq $null -and ($conflictReceipt.Projects[0].Diagnostics -join ' ') -match 'Integridade') 'Integridade invalida aceita.'
[IO.File]::WriteAllText($resultPath, $resultText)
Move-Item (Join-Path $run 'input') (Join-Path $run 'input.saved')
$missing = New-HarnessPrioritizationContext $context -Percentage 10 -Mode Recreate
Assert (((Get-Content $missing.ContextPath -Raw | ConvertFrom-Json).Projects[0].Diagnostics -join ' ') -match 'Snapshot') 'Snapshot ausente aceito.'
Move-Item (Join-Path $run 'input.saved') (Join-Path $run 'input')
$catalog = Join-Path $run 'output/static-report/output.js'
Set-Content $catalog 'catalogo original'
$hashedOrigin = $origin | ConvertFrom-Json
$hashedOrigin | Add-Member NoteProperty CatalogSha256 (Get-FileHash $catalog).Hash
$hashedRecord = $record.Replace($origin, ($hashedOrigin | ConvertTo-Json -Compress))
[IO.File]::WriteAllText($paths.MigrationPath, $hashedRecord)
$checked = New-HarnessPrioritizationContext $context -Percentage 10 -Mode Recreate
Assert ((Get-Content $checked.ContextPath -Raw | ConvertFrom-Json).Projects[0].Mta.CatalogPath -eq $catalog) 'Catalogo integro recusado.'
Set-Content $catalog 'catalogo alterado'
$conflict = New-HarnessPrioritizationContext $context -Percentage 10 -Mode Recreate
$conflictReceipt = Get-Content $conflict.ContextPath -Raw | ConvertFrom-Json
Assert ($conflictReceipt.Projects[0].Mta -eq $null -and ($conflictReceipt.Projects[0].Diagnostics -join ' ') -match 'hash') 'Catalogo alterado aceito.'
[IO.File]::WriteAllText($paths.MigrationPath, $record)

# CLI real, workspace escolhido, JSON e editor simulado, sem agente ou ferramentas externas.
$scripts = Join-Path $fixture 'scripts'
$null = [IO.Directory]::CreateDirectory($scripts)
foreach ($name in @('Harness.psm1','HarnessPlanning.psm1','HarnessPlanningInput.ps1','HarnessIssuePlanning.ps1','HarnessPrioritizationEvidence.ps1','HarnessPrioritization.psm1','HarnessPrioritizationState.ps1','HarnessPrioritizationEvidence.ps1','preparar-priorizacao.ps1')) { Copy-Item (Join-Path $root ('scripts/' + $name)) $scripts }
$config = Get-Content (Join-Path $root 'config/harness.example.json') -Raw | ConvertFrom-Json
$config.repositories = $projects; $config.activeProject = 'app-a'
Write-HarnessJson $context.ConfigPath $config
$workspace = Join-Path $area 'workspace com espacos.code-workspace'
Write-HarnessJson $workspace @{folders=@(@{path=$projects[0].path},@{path=$projects[2].path})}
$cli = Join-Path $scripts 'preparar-priorizacao.ps1'
$output = & powershell.exe -NoProfile -File $cli -ConfigPath $context.ConfigPath -WorkspacePath $workspace -Percentage 10 -Mode Recreate -NoOpen -OutputFormat Json 2>&1 | Out-String
Assert ($LASTEXITCODE -eq 0) ('CLI falhou: ' + $output)
$response = $output | ConvertFrom-Json
Assert ($response.Status -eq 'PREPARED' -and $response.Projects.Count -eq 2 -and $response.Projects[0].Source -eq $projects[0].path) 'CLI ignorou workspace.'
$count = @(Get-ChildItem (Join-Path $fixture '.harness/priorizacao') -Directory).Count
$output = 'q' | & powershell.exe -NoProfile -File $cli -ConfigPath $context.ConfigPath -Interactive 2>&1 | Out-String
Assert ($LASTEXITCODE -eq 1 -and $output.Contains('cancelada') -and @(Get-ChildItem (Join-Path $fixture '.harness/priorizacao') -Directory).Count -eq $count) 'Cancelamento gravou contexto.'
$output = & powershell.exe -NoProfile -File $cli -ConfigPath $context.ConfigPath -Interactive -NoOpen -OutputFormat Json 2>&1 | Out-String
Assert ($LASTEXITCODE -eq 1 -and ($output | ConvertFrom-Json).Status -eq 'FAILED' -and @(Get-ChildItem (Join-Path $fixture '.harness/priorizacao') -Directory).Count -eq $count) 'JSON interativo aceito ou gravou contexto.'
$editor = Join-Path $scripts 'editor.ps1'
Set-Content $editor '$args | ConvertTo-Json | Set-Content (Join-Path $PSScriptRoot "editor-args.json")' -Encoding UTF8
$output = & powershell.exe -NoProfile -File $cli -ConfigPath $context.ConfigPath -Percentage 10 -Mode Recreate -EditorPath $editor 2>&1 | Out-String
Assert ($LASTEXITCODE -eq 0) ('Editor: ' + $output)
$editorArgs = Get-Content (Join-Path $scripts 'editor-args.json') -Raw | ConvertFrom-Json
Assert ($editorArgs.Count -eq 2 -and $editorArgs[0] -eq '--reuse-window' -and (Split-Path $editorArgs[1] -Leaf) -eq 'priorizar-issues.prompt.md') 'Editor nao abriu somente o prompt.'
Assert (-not (Test-Path (Get-HarnessMigrationPaths $fixture $projects[2]).MigrationPath)) 'CLI inicializou registro ausente.'
$beforeMenu = @(Get-ChildItem (Join-Path $fixture '.harness/priorizacao') -Directory | ForEach-Object Name)
$output = '2' | & powershell.exe -NoProfile -File $cli -ConfigPath $context.ConfigPath -Interactive -NoOpen 2>&1 | Out-String
Assert ($LASTEXITCODE -eq 0 -and $output.Contains('Retomando') -and -not $output.Contains('Percentual de issues a examinar:')) 'Menu progredir deve retomar preparo sem pedir percentual.'
Assert (@(Get-ChildItem (Join-Path $fixture '.harness/priorizacao') -Directory).Count -eq $beforeMenu.Count) 'Retomada pelo menu duplicou preparo.'
$output = @('1','0,01') | & powershell.exe -NoProfile -File $cli -ConfigPath $context.ConfigPath -Interactive -NoOpen 2>&1 | Out-String
Assert ($LASTEXITCODE -eq 0) ('Menu recriar: ' + $output)
$added = @(Get-ChildItem (Join-Path $fixture '.harness/priorizacao') -Directory | Where-Object Name -NotIn $beforeMenu)
Assert ($added.Count -eq 1) 'Recriacao pelo menu deve gerar somente um contexto.'
$menuReceipt = Get-Content (Join-Path $added[0].FullName 'context.json') -Raw | ConvertFrom-Json
Assert ($menuReceipt.Percentage -eq 0.01 -and $menuReceipt.Mode -eq 'Recreate') 'Menu ignorou percentual com virgula ou modo.'
$output = @('1','q') | & powershell.exe -NoProfile -File $cli -ConfigPath $context.ConfigPath -Interactive -NoOpen 2>&1 | Out-String
Assert ($LASTEXITCODE -eq 1 -and @(Get-ChildItem (Join-Path $fixture '.harness/priorizacao') -Directory).Count -eq ($beforeMenu.Count+1)) 'Cancelamento do percentual gravou preparo.'
Write-Output 'PASS: origem MTA, conflitos, isolamento, CLI/workspace, cancelamento e editor.'
