#requires -Version 5.1
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $root 'scripts/Harness.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $root 'scripts/HarnessPlanning.psm1') -Force -DisableNameChecking
function Assert($condition, $message) { if (-not $condition) { throw $message } }
function Reject($action, $message) {
    $failed = $false
    try { & $action | Out-Null } catch { $failed = $true }
    Assert $failed $message
}
$area = Join-Path $root ('.harness/tests/v' + [guid]::NewGuid().ToString('N').Substring(0,8))
$run = Join-Path $area 'recebido/260930-154744'
$id = '161c1bd4ce7a4da78641091c58557e44'
foreach ($folder in @('input','rules','output/static-report')) { $null = New-Item -ItemType Directory -Path (Join-Path $run $folder) -Force }
Set-Content (Join-Path $run 'input/pom.xml') '<project xmlns="http://maven.apache.org/POM/4.0.0"><parent><groupId>org.exemplo</groupId><artifactId>parent</artifactId><version>1</version></parent><artifactId>app</artifactId></project>'
Set-Content (Join-Path $run 'rules/test.yaml') '[]'
Set-Content (Join-Path $run 'output/output.yaml') '[]'
Set-Content (Join-Path $run 'output/dependencies.yaml') '[]'
Set-Content (Join-Path $run 'output/static-report/index.html') '<html />'
Set-Content (Join-Path $run 'output/static-report/output.js') 'window["apps"] = [{"id":"0000","rulesets":[{"name":"teste","violations":{"regra":{"description":"Issue recebida","category":"mandatory","incidents":[{"uri":"file:///antigo/a.java"}]}}}]}]'
$manifest = @{RunId=$id;Project='projeto-na-origem';Source='Z:/maquina-origem/repositorio';CreatedAtUtc='2026-09-30T18:47:44Z';Git=@{Branch='branch-origem';Head='historico'};IndexPath='Z:/harness/.harness/runs/inexistente'}
$result = @{RunId=$id;Project=$manifest.Project;Status='SUCCEEDED';ExitCode=0;SourceUnchanged=$true;SnapshotOriginalFilesUnchanged=$true;RulesUnchanged=$true;UnexpectedAddedFiles=@();ReportPath='Z:/origem/relatorio.html'}
Write-HarnessJson (Join-Path $run 'manifest.json') $manifest
Write-HarnessJson (Join-Path $run 'result.json') $result
$before = @(Get-ChildItem $run -Recurse -File | Get-FileHash)
$selected = Get-MtaPlanningRunFromPath -RunPath $run -Root $root
Assert ($selected.RunId -ceq $id -and $selected.Run -eq $run -and $selected.Eligible) 'Pasta recebida depende da maquina/checkout de origem.'
$reportEntry = Join-Path $root 'scripts/abrir-relatorio-mta.ps1'
$reportOutput = & powershell.exe -NoProfile -File $reportEntry -RunPath $run -NoOpen 2>&1 | Out-String
Assert ($LASTEXITCODE -eq 0 -and $reportOutput.Contains((Join-Path $run 'output/static-report/index.html')) -and $reportOutput.Contains($id)) 'Abertura por pasta depende de cadastro ou caminho da origem.'
$result.RunId = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
Write-HarnessJson (Join-Path $run 'result.json') $result
Reject { Get-MtaPlanningRunFromPath -RunPath $run -Root $root } 'Resultado de outra rodada aceito.'
$reportOutput = & powershell.exe -NoProfile -File $reportEntry -RunPath $run -NoOpen 2>&1 | Out-String
Assert ($LASTEXITCODE -eq 1 -and $reportOutput.Contains('mesma rodada MTA')) 'Abertura aceitou resultado de outra rodada.'
$result.RunId = $id
Write-HarnessJson (Join-Path $run 'result.json') $result
$dependencyFile = Join-Path $run 'output/dependencies.yaml'
$dependencyBytes = [IO.File]::ReadAllBytes($dependencyFile)
Remove-Item -LiteralPath $dependencyFile
Reject { Get-MtaPlanningRunFromPath -RunPath $run -Root $root } 'Rodada incompleta aceita.'
[IO.File]::WriteAllBytes($dependencyFile, $dependencyBytes)
foreach ($file in $before) { Assert ((Get-FileHash -LiteralPath $file.Path).Hash -eq $file.Hash) 'Recebimento reescreveu evidencia.' }

# Mesmo projeto, raiz e identidade derivada do caminho diferentes nesta maquina.
$fixture = Join-Path $area 'h'
$contractDestination = Join-Path $fixture 'doc/especificacoes/planejamento-copilot.md'
$null = [IO.Directory]::CreateDirectory((Split-Path $contractDestination -Parent))
Copy-Item (Join-Path $root 'doc/especificacoes/planejamento-copilot.md') $contractDestination
$localSource = Join-Path $area 'checkout-local/repositorio'
$null = New-Item -ItemType Directory -Path $localSource -Force
Set-Content (Join-Path $localSource 'pom.xml') '<project><groupId>org.exemplo</groupId><artifactId>app</artifactId><version>2</version></project>'
$context = [pscustomobject]@{Root=$fixture;Active=[pscustomobject]@{name='projeto-local';label='app';path=$localSource}}
foreach ($name in @('planejar-lotes','revisar-lote','implementar-lote','revisar-resultado','manter-migracao')) {
    $destination = Join-Path $fixture ('.github/prompts/' + $name + '.prompt.md')
    $null = New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force
    Copy-Item (Join-Path $root ('.github/prompts/' + $name + '.prompt.md')) $destination
}
$prepared = New-MtaPlanningContext $context -RunId $id -RunPath $run
$receipt = Get-Content $prepared.ContextPath -Raw | ConvertFrom-Json
Assert ($receipt.CatalogStatus -eq 'ATUALIZADO' -and $receipt.ContractSnapshot.Contains('Hibernate ORM 5.3')) 'Catalogo/decisoes nao foram preservados no contexto.'
Assert ($receipt.MigrationSnapshot.Contains('teste::regra') -and $receipt.MigrationSnapshot.Contains('| mandatory | 1 |')) 'Rodada recebida nao preencheu registro.'
$maintained = New-MtaMigrationPrompt $context -RunPath $run
$maintainedReceipt = Get-Content $maintained.ContextPath -Raw -Encoding UTF8 | ConvertFrom-Json
Assert ($maintainedReceipt.RunId -ceq $id -and $maintainedReceipt.MigrationPath.Replace('\','/') -eq $receipt.MigrationPath) 'Manutencao com MTA recebido perdeu origem ou registro.'
Assert ($receipt.Source -eq $localSource.Replace('\','/') -and $receipt.AnalysisSource -eq (Join-Path $run 'input').Replace('\','/')) 'Snapshot e aplicacao local foram confundidos.'
Assert ($receipt.MtaOrigin.Project -eq $manifest.Project -and $receipt.MtaOrigin.Source -eq $manifest.Source -and $receipt.RunId -eq $id) 'Origem MTA foi reatribuida ao checkout local.'
Assert (-not $receipt.PSObject.Properties['Git'] -and -not $receipt.PSObject.Properties['MtaGit']) 'Novo planejamento exige referencias Git.'
Assert ($receipt.PomComparison.Status -eq 'MATCH' -and $receipt.PomComparison.Snapshot.Coordinate -eq 'org.exemplo:app' -and $receipt.PomComparison.Warnings.Count -eq 1) 'Parent Maven ou versao separada nao conferidos.'
Assert (-not (Test-Path (Join-Path $fixture '.harness/runs'))) 'Preparo importou/copiou a rodada para o historico local.'
$prompt = Get-Content $prepared.PromptPath -Raw -Encoding UTF8
Assert ($prompt.Contains('AnalysisSource') -and $prompt.Contains('novo MTA') -and $prompt.Contains('ALERTA')) 'Falta contrato de snapshot e alerta de mudanca pertinente.'
Set-Content $prepared.PlanPath 'Lote ativo: TESTE-001'
Set-Content $prepared.TodoPath 'Lote ativo: TESTE-001'
$implementation = New-MtaImplementationPrompt $context -RequestId $prepared.RequestId
Assert (Test-Path $implementation.PromptPath) 'Planejamento recebido nao pode seguir para preparo da implementacao.'
$continued = New-MtaPlanningContext $context -RunId $id -RunPath $run -PreviousRequestId $prepared.RequestId
Assert ((Get-Content $continued.ContextPath -Raw | ConvertFrom-Json).Previous.RequestId -eq $prepared.RequestId) 'Continuidade perdeu a rodada recebida.'
Set-Content (Join-Path $localSource 'pom.xml') '<project><groupId>org.outro</groupId><artifactId>app</artifactId><version>2</version></project>'
$different = New-MtaPlanningContext $context -RunId $id -RunPath $run
Assert ((Get-Content $different.ContextPath -Raw | ConvertFrom-Json).PomComparison.Status -eq 'DIFFERENT') 'Diferenca de POM bloqueou proposta ou ficou oculta.'
Set-Content (Join-Path $localSource 'pom.xml') '<project><groupId>${grupo}</groupId><artifactId>app</artifactId></project>'
$unknown = New-MtaPlanningContext $context -RunId $id -RunPath $run
Assert ((Get-Content $unknown.ContextPath -Raw | ConvertFrom-Json).PomComparison.Status -eq 'UNVERIFIED') 'Propriedade nao resolvida foi tratada como identidade confirmada.'
foreach ($file in $before) { Assert ((Get-FileHash -LiteralPath $file.Path).Hash -eq $file.Hash) 'Planejamento reescreveu evidencia recebida.' }

# Run Task real: entrada p funciona mesmo sem nenhuma rodada no historico local.
$scriptFolder = Join-Path $fixture 'scripts'
$null = New-Item -ItemType Directory -Path $scriptFolder -Force
foreach ($file in @('Harness.psm1','HarnessPlanning.psm1','HarnessPlanningInput.ps1','preparar-planejamento.ps1','abrir-relatorio-mta.ps1')) { Copy-Item (Join-Path $root "scripts/$file") $scriptFolder }
$config = Get-Content (Join-Path $root 'config/harness.example.json') -Raw | ConvertFrom-Json
$config.repositories = @(@{name='app';path=$localSource})
$config.activeProject = 'app'
$configPath = Join-Path $fixture 'config.json'
Write-HarnessJson $configPath $config
$reportEntry = Join-Path $scriptFolder 'abrir-relatorio-mta.ps1'
$reportOutput = @('1',$run) | & powershell.exe -NoProfile -File $reportEntry -ConfigPath $configPath -SelectTarget -NoOpen 2>&1 | Out-String
Assert ($LASTEXITCODE -eq 0 -and $reportOutput.Contains('Ultimo relatorio indisponivel') -and $reportOutput.Contains($id)) 'Tarefa nao recuperou relatorio por pasta sem indice local.'
$reportOutput = @('1','q') | & powershell.exe -NoProfile -File $reportEntry -ConfigPath $configPath -SelectTarget -NoOpen 2>&1 | Out-String
Assert ($LASTEXITCODE -eq 1 -and $reportOutput.Contains('Abertura cancelada')) 'Cancelamento da abertura nao respeitado.'
Assert (-not (Test-Path (Join-Path $fixture '.harness/runs'))) 'Abertura cadastrou/copio rodada recebida.'
foreach ($file in $before) { Assert ((Get-FileHash -LiteralPath $file.Path).Hash -eq $file.Hash) 'Abertura reescreveu evidencia recebida.' }
$entry = Join-Path $scriptFolder 'preparar-planejamento.ps1'
$output = @('1','p',$run) | & powershell.exe -NoProfile -File $entry -ConfigPath $configPath -Target app -SelectOperation -NewPlan -NoOpen 2>&1 | Out-String
Assert ($LASTEXITCODE -eq 0 -and $output.Contains($id) -and $output.Contains('Prompt preparado:')) "Menu p nao preparou pasta recebida: $output"
$receiptLine = @($output -split '\r?\n' | Where-Object { $_.StartsWith('Recibo de contexto e hashes: ') })
$cliReceipt = Get-Content ($receiptLine[0].Substring('Recibo de contexto e hashes: '.Length)) -Raw | ConvertFrom-Json
Assert ($cliReceipt.MtaOrigin.Project -eq $manifest.Project -and $cliReceipt.Source -eq $localSource.Replace('\','/')) 'Menu confundiu origem MTA e aplicacao local.'
$output = & powershell.exe -NoProfile -File $entry -ConfigPath $configPath -Target app -RunPath $run -NewPlan -NoOpen 2>&1 | Out-String
Assert ($LASTEXITCODE -eq 0 -and $output.Contains($id)) 'Parametro RunPath nao preparou pasta recebida.'
foreach ($file in $before) { Assert ((Get-FileHash -LiteralPath $file.Path).Hash -eq $file.Hash) 'Entrada real alterou arquivos recebidos.' }
Write-Output 'PASS: rodada recebida independente de caminhos/Git da origem; coerencia e evidencias preservadas.'
