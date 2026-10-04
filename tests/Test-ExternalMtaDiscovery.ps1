#requires -Version 5.1
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $root 'scripts/Harness.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $root 'scripts/HarnessPlanning.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $root 'scripts/HarnessProjectIndex.psm1') -Force -DisableNameChecking
function Assert($condition, $message) { if (-not $condition) { throw $message } }
function Read-ProjectSummary($path) {
    # Conferir estado na linha do projeto, sem confundir com exemplos da legenda.
    ([IO.File]::ReadAllText($path) -split "`n" | Where-Object { $_.StartsWith('| ') -and $_.Contains($app) }) -join "`n"
}
$area = Join-Path $root ('.harness/tests/descoberta-' + [guid]::NewGuid().ToString('N'))
$fixture = Join-Path $area 'harness'
$app = Join-Path $area 'app'
$external = Join-Path $area 'mta-runs'
$null = [IO.Directory]::CreateDirectory($app)
Set-Content (Join-Path $app 'pom.xml') '<project />'
$config = Get-Content (Join-Path $root 'config/harness.example.json') -Raw | ConvertFrom-Json
$config.repositories = @(); $config.activeProject = $null; $config.mta.runsPath = $external
$configPath = Join-Path $fixture 'config.json'
Write-HarnessJson $configPath $config
$workspace = Join-Path $area 'workspace.code-workspace'
Write-HarnessJson $workspace @{folders=@(@{name='Aplicacao';path=$app})}
$context = Read-HarnessConfig $configPath $fixture -WorkspacePath $workspace -Target $app -SkipMigrationInitialization
foreach ($relative in @('doc/especificacoes/planejamento-copilot.md','.github/prompts/manter-migracao.prompt.md')) {
    $destination = Join-Path $fixture $relative
    $null = [IO.Directory]::CreateDirectory((Split-Path $destination -Parent))
    Copy-Item (Join-Path $root $relative) $destination
}
function Add-External($relative, $id, $date, $source, $status = 'SUCCEEDED') {
    $run = Join-Path $external $relative
    Write-HarnessJson (Join-Path $run 'manifest.json') @{Source=$source;Project='origem';RunId=$id;CreatedAtUtc=$date}
    Write-HarnessJson (Join-Path $run 'result.json') @{Project='origem';RunId=$id;Status=$status;ExitCode=0;SourceUnchanged=$true;SnapshotOriginalFilesUnchanged=$true;RulesUnchanged=$true;UnexpectedAddedFiles=@()}
    foreach ($relativeFile in @('input/pom.xml','output/output.yaml','output/dependencies.yaml','output/static-report/index.html','rules/regra.yaml')) {
        $file = Join-Path $run $relativeFile
        $null = [IO.Directory]::CreateDirectory((Split-Path $file -Parent))
        Set-Content -LiteralPath $file 'fixture'
    }
    $apps = @(@{rulesets=@(@{name='java';violations=@{rule=@{description='Regra';category='mandatory';incidents=@(@{uri='x'})}}})})
    [IO.File]::WriteAllText((Join-Path $run 'output/static-report/output.js'), ('window["apps"] = ' + (ConvertTo-Json -InputObject $apps -Depth 12)))
    $run
}
$old = Add-External ('p__antigo/' + ('a'*32)) ('a'*32) '2026-09-29T12:00:00Z' $app
$latest = Add-External 'Aplicacao/260930-100000' ('b'*32) '2026-09-30T13:00:00Z' $app
$foreign = Add-External 'colega/261001-100000' ('c'*32) '2026-10-01T13:00:00Z' 'C:/outra-maquina/app'
$hashes = @(Get-ChildItem $external -Recurse -File | Get-FileHash)
$runs = @(Get-MtaPlanningRuns $context)
Assert ($runs.Count -eq 2 -and $runs[0].RunId -eq ('b'*32) -and $runs[0].Eligible) 'Descoberta sem indice falhou ou associou Source estrangeiro.'
Assert (-not (Test-Path "$fixture/.harness/runs")) 'Descoberta nao deve recriar referencias locais.'
$index = New-HarnessProjectIndex $context
$text = [IO.File]::ReadAllText($index.IndexPath)
Assert ($text.Contains('CATALOGO NAO CARREGADO') -and $text.Contains('b'*32) -and -not $text.Contains('c'*32)) 'Indice nao mostra MTA externo/registro pendente isolado.'
Assert ($text.Contains('**Total MTA contabilizado: 1 issues / 1 ocorrencias**') -and (Read-ProjectSummary $index.IndexPath).Contains('| 1 / 1 |')) 'MTA deve mostrar contagens antes de carregar registro.'
$migrationPaths = Get-HarnessMigrationPaths $fixture $context.Active
Assert (-not (Test-Path -LiteralPath $migrationPaths.MigrationPath)) 'Consulta do indice nao deve inicializar registro.'
# A tarefa cria registro ausente/carrega catalogo inicial sem manutencao obrigatoria.
$automatic = New-HarnessProjectIndex $context -UpdateMigration
$autoRegister = Initialize-HarnessMigration $fixture $context.Active
$autoText = [IO.File]::ReadAllText($autoRegister.MigrationPath)
Assert ($autoText.Contains('Rodada MTA: ' + ('b'*32)) -and -not $autoText.Contains('Estado: PENDENTE')) 'Carga inicial deve vincular MTA sem criar pendencia de reconciliacao.'
$initialOrigin = [regex]::Match($autoText, '<!-- MTA (.*?) -->').Groups[1].Value | ConvertFrom-Json
Assert ($initialOrigin.RunId -ceq ('b'*32) -and $initialOrigin.Project -ceq 'origem' -and $initialOrigin.Source -ieq $app -and $initialOrigin.Run -ieq $latest) 'Carga inicial perdeu identidade ou origem externa.'
Assert (-not (Test-Path "$fixture/.harness/planning")) 'Atualizar indice nao deve preparar prompt de manutencao por rotina.'
Assert (-not (Read-ProjectSummary $automatic.IndexPath).Contains('PENDENTE (historico')) 'Indice criou pendencia sem conflito ou pedido de manutencao.'
$autoText = $autoText.Replace('| A DEFINIR | NAO ANALISADA |', '| ADIAR | ANALISADA |') + "`nNota humana: preservar a decisao.`n"
[IO.File]::WriteAllText($autoRegister.MigrationPath,$autoText)
$humanHash = (Get-FileHash $autoRegister.MigrationPath).Hash
$null = New-HarnessProjectIndex $context -UpdateMigration
Assert ((Get-FileHash $autoRegister.MigrationPath).Hash -eq $humanHash -and -not (Test-Path "$fixture/.harness/planning")) 'Repetir indice deve preservar integralmente registro humano e nao gerar prompt.'
Set-Content -LiteralPath (Join-Path (Split-Path $autoRegister.EvidenceIndexPath -Parent) 'nova-evidencia.txt') -Value 'Evidencia complementar do comportamento observado.'
Add-Content -LiteralPath $autoRegister.EvidenceIndexPath -Value '| nova-evidencia.txt | Comportamento observado para a issue escolhida pelo desenvolvedor. |'
$evidenceUpdate = New-HarnessProjectIndex $context -UpdateMigration
Assert ((Get-FileHash $autoRegister.MigrationPath).Hash -eq $humanHash -and -not (Test-Path "$fixture/.harness/planning")) 'Nova evidencia complementar nao deve criar contexto, trocar base ou reconciliacao automaticamente.'
# Preparar manutencao carrega catalogo sem executar agente, mesmo com Project de origem diferente.
$prepared = New-MtaMigrationPrompt $context -RunId ('b'*32)
$md = [IO.File]::ReadAllText($prepared.MigrationPath)
Assert ($md.Contains('Rodada MTA: ' + ('b'*32)) -and $md.Contains('Total MTA: 1 issues') -and $md.Contains('Estado: PENDENTE')) 'Manutencao explicita deve carregar catalogo externo e registrar a reconciliacao solicitada.'
Assert ((Test-Path $prepared.PromptPath) -and @(Get-ChildItem "$fixture/.harness/planning" -Recurse -Filter 'manter-migracao.prompt.md').Count -eq 1) 'Pedido explicito deve preparar exatamente um prompt de manutencao.'
$md = $md.Replace('| A DEFINIR | NAO ANALISADA |', '| ADIAR | ANALISADA |')
[IO.File]::WriteAllText($prepared.MigrationPath, $md)
$registerHash = (Get-FileHash $prepared.MigrationPath).Hash
$index = New-HarnessProjectIndex $context
Assert ((Read-ProjectSummary $index.IndexPath).Contains('MESMA RODADA')) 'Registro carregado nao reconhecido.'
$pending = New-HarnessProjectIndex $context -UpdateMigration
Assert ((Get-FileHash $prepared.MigrationPath).Hash -eq $registerHash -and (Read-ProjectSummary $pending.IndexPath).Contains('PENDENTE (historico; conferir motivo)')) 'Atualizar indice nao deve concluir reconciliacao solicitada nem tornar o estado gate generico.'
[IO.File]::WriteAllText($prepared.MigrationPath,$md.Replace('Estado: PENDENTE','Estado: CONCLUIDA'))
$completedHash = (Get-FileHash $prepared.MigrationPath).Hash
$completed = New-HarnessProjectIndex $context -UpdateMigration
Assert ((Read-ProjectSummary $completed.IndexPath).Contains('CONCLUIDA (declarada no registro)') -and (Get-FileHash $prepared.MigrationPath).Hash -eq $completedHash) 'Conclusao declarada deve permanecer visivel sem nova pendencia artificial.'
Assert (@(Get-ChildItem "$fixture/.harness/planning" -Recurse -Filter 'manter-migracao.prompt.md').Count -eq 1) 'Registro concluido nao deve gerar novo prompt por rotina.'
$registerHash = $completedHash
$new = Add-External 'Aplicacao/261001-110000' ('d'*32) '2026-10-01T14:00:00Z' $app
$index = New-HarnessProjectIndex $context
Assert ((Read-ProjectSummary $index.IndexPath).Contains('RODADA DIFERENTE')) 'Nova copia externa nao gerou aviso.'
Assert ((Get-FileHash $prepared.MigrationPath).Hash -eq $registerHash) 'Indice atualizou registro silenciosamente.'
$automaticNew = New-HarnessProjectIndex $context -UpdateMigration
$afterNew = [IO.File]::ReadAllText($prepared.MigrationPath)
Assert ((Get-FileHash $prepared.MigrationPath).Hash -eq $registerHash -and $afterNew.Contains('Rodada MTA: ' + ('b'*32)) -and $afterNew.Contains('Estado: CONCLUIDA') -and $afterNew.Contains('| ADIAR | ANALISADA |')) 'Nova rodada descoberta deve preservar base, decisao, conclusao e todo conteudo do registro.'
Assert ((Read-ProjectSummary $automaticNew.IndexPath).Contains('RODADA DIFERENTE') -and (Read-ProjectSummary $automaticNew.IndexPath).Contains('troca somente por escolha explicita')) 'Outra rodada deve ser informada sem eleicao automatica.'
Assert (@(Get-ChildItem "$fixture/.harness/planning" -Recurse -Filter 'manter-migracao.prompt.md').Count -eq 1) 'Descobrir novo MTA nao deve preparar manutencao automaticamente.'
$prepared = New-MtaMigrationPrompt $context -RunId ('d'*32)
$adopted = [IO.File]::ReadAllText($prepared.MigrationPath)
Assert ($adopted.Contains('| ADIAR | ANALISADA |') -and $adopted.Contains('Rodada MTA: ' + ('d'*32)) -and $adopted.Contains('Estado: PENDENTE') -and $adopted.Contains('Nota humana: preservar a decisao.')) 'Adocao explicita deve atualizar rodada preservando decisao/notas e registrar reconciliacao real.'
$failed = Add-External 'Aplicacao/261001-120000' ('e'*32) '2026-10-01T15:00:00Z' $app 'FAILED'
$hashBeforeFailure = (Get-FileHash $prepared.MigrationPath).Hash
$syncFailed = New-HarnessProjectIndex $context -UpdateMigration
Assert ((Get-FileHash $prepared.MigrationPath).Hash -eq $hashBeforeFailure) 'Ultima falha nao deve modificar o registro.'
$otherSource = Join-Path $area 'outra-app'
$null = [IO.Directory]::CreateDirectory($otherSource)
Set-Content (Join-Path $otherSource 'pom.xml') '<project />'
Write-HarnessJson $workspace @{folders=@(@{name='Aplicacao';path=$app},@{name='Outra';path=$otherSource})}
# Read-HarnessConfig pode criar um registro vazio antes do indice: ainda e carga inicial.
$autoInitialized = Read-HarnessConfig $configPath $fixture -WorkspacePath $workspace -Target $otherSource
$secondProject = $autoInitialized.Active
$context.Projects += $secondProject
$otherRun = Add-External 'Outra/261001-120000' ('9'*32) '2026-10-01T15:00:00Z' $otherSource
$otherRegister = Get-HarnessMigrationPaths $fixture $secondProject
Assert ((Test-Path $otherRegister.MigrationPath) -and [IO.File]::ReadAllText($otherRegister.MigrationPath).Contains('AGUARDANDO MTA')) 'Fixture deve iniciar registro vazio criado pela leitura da configuracao.'
$mixed = New-HarnessProjectIndex $context -UpdateMigration
$otherText = [IO.File]::ReadAllText($otherRegister.MigrationPath)
Assert ($otherText.Contains('Rodada MTA: ' + ('9'*32)) -and $otherText.Contains('Total MTA: 1 issues') -and -not $otherText.Contains('Estado: PENDENTE')) 'Registro vazio inicializado deve receber catalogo sem pendencia; falha de outro projeto nao pode impedir sua carga.'
Assert ((Get-FileHash $prepared.MigrationPath).Hash -eq $hashBeforeFailure) 'Carga do outro projeto alterou o registro preservado.'
$index = New-HarnessProjectIndex $context
Assert ((Read-ProjectSummary $index.IndexPath).Contains('ULTIMA TENTATIVA FAILED')) 'Falha recente nao ficou explicita.'
$selected = Select-MtaPlanningRun $context
Assert ($selected.RunId -eq ('d'*32)) 'Planejamento nao deve carregar falha recente.'
# Referencia local mais descoberta direta da mesma pasta nao duplicam a rodada.
$local = Join-Path $fixture ('.harness/runs/origem/mta_2026-10-01_11-00-00-0300__' + ('d'*12))
$manifest = Get-Content (Join-Path $new 'manifest.json') -Raw | ConvertFrom-Json
$manifest | Add-Member NoteProperty IndexPath $local
Write-HarnessJson (Join-Path $new 'manifest.json') $manifest
Write-HarnessJson (Join-Path $local 'location.json') @{Project='origem';Source=$app;RunId=('d'*32);RunsPath=$external;RunRelativePath='Aplicacao/261001-110000'}
$deduplicated = @(Get-HarnessMtaRuns $fixture 'origem' $app $external)
Assert ($deduplicated.Count -eq 4) 'Referencia local duplicou rodada externa.'
$index = New-HarnessProjectIndex $context
Assert ($index.Warnings.Count -eq 0) 'Referencia local mais externa gerou ambiguidade falsa.'
# Duas pastas com mesmo RunId sao ambiguas, nunca escolhidas por ordem de diretorio.
$duplicate = Add-External 'copia/261001-130000' ('d'*32) '2026-10-01T16:00:00Z' $app
$rejected = $false
try { Get-MtaPlanningRuns $context | Out-Null } catch { $rejected = $_.Exception.Message.Contains('ambiguo') }
Assert $rejected 'RunId duplicado deve exigir resolucao humana.'
$index = New-HarnessProjectIndex $context
Assert ((Read-ProjectSummary $index.IndexPath).Contains('COMPARACAO INDISPONIVEL')) 'Ambiguidade ficou oculta no indice.'
$invalidRun = Add-External 'Aplicacao/261001-140000' 'id-invalido' '2026-10-01T17:00:00Z' $app
$index = New-HarnessProjectIndex $context
Assert ([IO.File]::ReadAllText($index.IndexPath).Contains('Identidade MTA externa invalida')) 'Indice ignorou validacao da identidade externa.'
foreach ($file in $hashes) { Assert ((Get-FileHash $file.Path).Hash -eq $file.Hash) 'Leitura/preparo alterou MTA externo.' }
$context.Config.mta.runsPath = Join-Path $area 'pasta-indisponivel'
$index = New-HarnessProjectIndex $context
Assert ([IO.File]::ReadAllText($index.IndexPath).Contains('Pasta MTA externa indisponivel')) 'Raiz externa inacessivel deve avisar leitura parcial.'
Write-Output 'PASS: descoberta externa, Source, comparacao do catalogo, preparo sem agente, decisoes e ambiguidades.'
