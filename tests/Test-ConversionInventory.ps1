#requires -Version 5.1
$ErrorActionPreference='Stop'; Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'ConversionFixture.ps1')
Import-Module (Join-Path $root 'tools/transicao/ConversaoPrevia.psm1') -Force -DisableNameChecking
$f=New-ConversionFixture
$plan=Add-ConversionPlan $f ('a'*32)
# Cabecalho real do legado e links relativos com espacos escapados.
$text=[IO.File]::ReadAllText($f.Register).Replace('| ID | Issue |','| ID (ruleset::regra) | Issue |')
$text+="`n[Anexo](<../../../../anexo-inexistente.md>)`n[Em uso](<"+$plan.PlanPath+">)`n<!-- reconciliacao:inicio -->`nEstado: CONCLUIDA`nSolicitacao: $('c'*32)`n<!-- reconciliacao:fim -->`n"
Write-ConversionFile $f.Register $text
$snapshot=Join-Path $f.Workspace '.harness/planning/apelido/registro/solicitacao/snapshot.md'
Write-ConversionFile $snapshot $text
$maintenance=@{Purpose='migration-register';Source=$f.Source;RequestId=('c'*32);MigrationPath=$f.Register;MigrationSnapshot=$text.Replace('Estado: CONCLUIDA','Estado: PENDENTE');PreviousMigration=@{Snapshot=$text}}
Write-ConversionFile (Join-Path (Split-Path $snapshot -Parent) 'context.json') ($maintenance|ConvertTo-Json -Depth 12)
$ranking=Join-Path $f.Workspace '.harness/priorizacao/categoria/priorizacao.md'
Write-ConversionFile $ranking '# Ranking com cobertura humana'
$priority=@{Purpose='issue-prioritization';SchemaVersion=4;Category='optional';Projects=@(@{Source=$f.Source});RankingPath=$ranking;FichaPaths=@()}
Write-ConversionFile (Join-Path (Split-Path $ranking -Parent) 'context.json') ($priority|ConvertTo-Json -Depth 12)
$sprint=@{Purpose='sprint-planning';Projects=@(@{Source=$f.Source});PlanningId=('d'*32);RevisionId=('e'*32);SprintDataPath=(Join-Path $f.Workspace '.harness/sprints/plano/revisoes/uma/planejamento-sprints.json')}
Write-ConversionFile $sprint.SprintDataPath '{"baseline":"manter"}'
Write-ConversionFile (Join-Path (Split-Path $sprint.SprintDataPath -Parent) 'contexto.json') ($sprint|ConvertTo-Json -Depth 12)
$build=@{Source=$f.Source;Status='FAILED';RunId='antigo';LogPath=(Join-Path $f.Workspace '.harness/builds/projeto/tentativa/build.log')}
Write-ConversionFile $build.LogPath 'Falhou, preservar tentativa.'
Write-ConversionFile (Join-Path (Split-Path $build.LogPath -Parent) 'result.json') ($build|ConvertTo-Json)
# Original importado nao pode competir com o contexto adaptado localmente.
Write-ConversionFile (Join-Path $f.Workspace '.harness/importacoes/pacote/original/context.json') ($plan|ConvertTo-Json -Depth 15)
Write-ConversionFile $plan.PlanPath ("# Plano humano`n[Fonte](<"+(Join-Path $f.Source 'classe-ausente.java')+">)`n")
$before=Get-ConversionState $f
$preview=Get-ConversionPreview $f.Workspace $f.Pom
Assert ($preview.Planning.ContextPath -eq $plan.ContextPath -and $preview.Register.Decisions[0].Id -ceq 'java::regra') 'Original importado nao concorre; tabela antiga preserva ID.'
Assert ($preview.Reconciliation.State -ceq 'PRELIMINAR' -and $preview.Reconciliation.Declarations.Count -eq 3) 'Declaracoes atual/anterior devem ser exibidas sem inventar prova.'
Assert (@($preview.Reconciliation.Declarations|Where-Object State -EQ 'CONCLUIDA').Count -eq 2) 'CONCLUIDA humana deve ser preservada e conferida.'
Assert (@($preview.Related|Where-Object Kind -EQ 'PRIORIZACAO').Count -eq 1 -and @($preview.Related|Where-Object Kind -EQ 'SPRINT').Count -eq 1 -and @($preview.Related|Where-Object Kind -EQ 'BUILDS').Count -eq 1) 'Inventariar priorizacao, sprint e tentativa de build.'
Assert (@($preview.References|Where-Object { -not $_.Available }).Count -ge 2) 'Links indisponiveis precisam aparecer.'
Assert (-not $preview.DeletionAuthorized -and $preview.DiscardCandidates.Count -gt 0) 'Escopo de descarte e informativo, sem autorizacao.'
Assert ((Get-ConversionState $f) -ceq $before) 'Inventario e declaracoes nao escrevem dados.'
Write-Host 'PASS: inventario, decisoes antigas, declaracoes, anexos e referencias indisponiveis.'
