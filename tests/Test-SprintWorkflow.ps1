#requires -Version 5.1
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $root 'scripts/HarnessSprintPlanning.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $root 'scripts/Harness.psm1') -Force -DisableNameChecking
function Assert($value,$message) { if (-not $value) { throw $message } }
function Save($path,$data) { [IO.File]::WriteAllText($path,($data | ConvertTo-Json -Depth 60),(New-Object Text.UTF8Encoding($false))) }
$fixture=Join-Path $root ('.harness/tests/sprint-workflow-'+[guid]::NewGuid().ToString('N'))
foreach ($relative in @('.github/prompts/planejar-sprints.prompt.md','doc/modelos/planejamento-sprints.template.md','doc/features/planejamento-macro-sprints.md','doc/especificacoes/planejamento-sprints.md')) {
    $target=Join-Path $fixture $relative
    $null=[IO.Directory]::CreateDirectory((Split-Path $target -Parent))
    Copy-Item -LiteralPath (Join-Path $root $relative) -Destination $target
}
$source=Join-Path $fixture 'app com espacos'; $null=[IO.Directory]::CreateDirectory($source)
[IO.File]::WriteAllText((Join-Path $source 'pom.xml'),'<project><artifactId>app</artifactId></project>')
$project=[pscustomobject]@{name='app';label='app';path=$source}
$register=Initialize-HarnessMigration $fixture $project
$text=[IO.File]::ReadAllText($register.MigrationPath)
foreach ($item in @(@('I1','mandatory'),@('I2','mandatory'),@('OPT1','optional'))) {
    $text=$text.Replace('<!-- mta:fim -->',("| {0} | Corrigir API | {1} | 1 | PRESENTE | A DEFINIR | NAO ANALISADA | Fixture |`n<!-- mta:fim -->" -f $item[0],$item[1]))
}
[IO.File]::WriteAllText($register.MigrationPath,$text)
$before=(Get-FileHash -LiteralPath $register.MigrationPath).Hash
$context=[pscustomobject]@{Root=$fixture;Projects=@($project);Active=$null}
$receipt=New-HarnessSprintContext $context -All
$data=Get-Content -LiteralPath $receipt.SprintDataPath -Raw | ConvertFrom-Json
Assert ($data.Baseline.Issues.Count -eq 2 -and $receipt.Projects[0].Issues.Count -eq 3) 'Default mandatory deve manter optional disponivel como referencia.'
$data.State='PROPOSTA'
$data.Constraints=[pscustomobject]@{SprintStartDate='2026-10-12';ReferenceDate='2026-10-12';ProductionDeadline='2026-11-08';MaxPreparationSprints=1;MaxImplementationSprints=2;MaxTestSprints=1;MaxTotalSprints=2;MaxDevelopers=2}
$data.Team.RolesAreDistinct=$true
$data.Team.Staffing=@(foreach ($n in 1..2) { [pscustomobject]@{Sprint=$n;Developers=2;DeveloperAvailability=1;ArchitectAvailability=1;DevOpsAvailability=1;ReservePercent=0;AbsenceDays=@{Dev=0;Architect=0;DevOps=0}} })
$evidence=Join-Path $fixture 'estimativa fornecida.md'; [IO.File]::WriteAllText($evidence,'Fixture: premissas de estimativa examinadas.')
$issues=@($data.Baseline.Issues)
function Work($id,$phase,$priority,$deps,$dev,$arq,$ops,$links) {
    [pscustomobject]@{Id=$id;Title=$id;Phase=$phase;Priority=$priority;DependsOn=$deps;Issues=$links;Effort=@{Dev=@{Min=$dev;Reference=$dev;Max=$dev};Architect=@{Min=$arq;Reference=$arq;Max=$arq};DevOps=@{Min=$ops;Reference=$ops;Max=$ops}};EstimateSource='Fixture';Confidence='alta';Assumptions=@('Fixture');NotBefore=$null;Deadline=$null;Acceptance='Fixture verificavel';References=@($evidence);Remaining=$true}
}
$data.Work=@((Work 'Preparar-JBoss-subsystems' 'PREPARATION' 1 @() 0 1 1 @()),(Work 'Migrar-APIs' 'IMPLEMENTATION' 2 @('Preparar-JBoss-subsystems') 4 0 0 $issues),(Work 'Testar-integracao' 'TEST' 3 @('Migrar-APIs') 2 0 0 $issues),(Work 'Implantar-producao' 'DEPLOYMENT' 4 @('Testar-integracao') 0 0 1 @()))
Save $receipt.SprintDataPath $data
[IO.File]::AppendAllText($receipt.SprintPlanPath,"`nContribuicao manual: HU S1 valida as APIs e a implantacao; S2 reserva para revisao.`n")
$result=Complete-HarnessSprintPlan $fixture $receipt.ContextPath
Assert ($result.Feasibility -eq 'CABE_NAS_PREMISSAS') ('Fixture deveria caber: '+($result.Diagnostics -join '; '))
Assert ($result.DataSnapshot.Simulation.ProductionDate -eq '2026-10-16') 'Dependencias devem liberar implantacao no quinto dia util.'
Assert ($result.DataSnapshot.Simulation.Sprints[0].ForecastPercent -eq 100 -and $result.DataSnapshot.Simulation.Sprints[0].ActualCount -eq 0) 'Previsto 100% nao e realizado.'
$markdown=[IO.File]::ReadAllText($receipt.SprintPlanPath)
Assert ($markdown.Contains('```mermaid') -and $markdown.Contains('Contribuicao manual') -and $markdown.Contains('Preparar-JBoss-subsystems')) 'Saida deve ter diagrama, capacidade e preservar narrativa.'
Assert ($result.DataSnapshot.EstimateEvidence[0].Sha256 -eq (Get-FileHash $evidence).Hash) 'Arquivo fornecido nao entrou na origem da estimativa.'
$resume=New-HarnessSprintContext $context -PreviousContextPath $receipt.ContextPath
Assert ($resume.Reused) 'Retomar publicacao com arquivo adicional inalterado deve reutilizar.'
[IO.File]::AppendAllText($evidence,' Nova premissa muda esforco.')
$revision=New-HarnessSprintContext $context -PreviousContextPath $receipt.ContextPath -Reason 'Reestimar com nova evidencia'
Assert (@($revision.InputChanges | Where-Object Path -EQ $evidence).Count -eq 1) 'Mudanca de arquivo fornecido nao aparece para reestimativa.'
$data=Get-Content $revision.SprintDataPath -Raw | ConvertFrom-Json
$data.EvidenceReview=[pscustomobject]@{Reviewed=$true;Reason='Nova premissa aumenta esforco Dev em 2 dias-pessoa.'}
$data.Work[1].Effort.Dev=[pscustomobject]@{Min=6;Reference=6;Max=6}
Save $revision.SprintDataPath $data
$updated=Complete-HarnessSprintPlan $fixture $revision.ContextPath
Assert ($updated.DataSnapshot.Simulation.ProductionDate -eq '2026-10-19') 'Nova evidencia/estimativa deveria deslocar producao, respeitando fim de semana.'
Assert ((Get-Content $receipt.ValidationPath -Raw | ConvertFrom-Json).DataSnapshot.Simulation.ProductionDate -eq '2026-10-16') 'Reestimativa apagou previsao anterior.'
Assert ((Get-FileHash $register.MigrationPath).Hash -eq $before) 'Planejamento macro alterou registro de migracao.'
Write-Output ('PASS: fluxo completo com JBoss, issues mandatory, testes, producao, Gantt e reestimativa rastreavel. Fixture: '+$fixture)
