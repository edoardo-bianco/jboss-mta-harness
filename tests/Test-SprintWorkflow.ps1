#requires -Version 5.1
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $root 'scripts/HarnessSprintPlanning.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $root 'scripts/Harness.psm1') -Force -DisableNameChecking
function Assert($value,$message) { if (-not $value) { throw $message } }
function Save($path,$data) { [IO.File]::WriteAllText($path,($data | ConvertTo-Json -Depth 60),(New-Object Text.UTF8Encoding($false))) }
$fixture=Join-Path $root ('.harness/tests/sprint-workflow-'+[guid]::NewGuid().ToString('N'))
foreach ($relative in @('.github/prompts/planejar-sprints.prompt.md','.github/prompts/revisar-sprints.prompt.md','doc/modelos/planejamento-sprints.template.md','doc/features/planejamento-macro-sprints.md','doc/especificacoes/planejamento-sprints.md')) {
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
Assert ($receipt.PSObject.Properties['ReviewPromptPath'] -and (Test-Path -LiteralPath $receipt.ReviewPromptPath)) 'Preparo deve capturar prompt de analise com destinos desta revisao.'
$reviewText=[IO.File]::ReadAllText($receipt.ReviewPromptPath)
Assert ($reviewText.Contains($receipt.ValidationPath) -and $reviewText.Contains($receipt.ContextPath) -and $reviewText.Contains('somente leitura')) 'Analise deve usar validacao/contexto vinculados e preservar arquivos publicados.'
[IO.File]::AppendAllText($receipt.ReviewPromptPath,' Adulteracao fixture.')
$rejected=$false
try { $null=Read-HarnessSprintContext $fixture $receipt.ContextPath } catch { $rejected=$_.Exception.Message -like '*Prompt de revisao alterado*' }
Assert $rejected 'Prompt capturado adulterado deve ser recusado.'
[IO.File]::WriteAllText($receipt.ReviewPromptPath,$reviewText,(New-Object Text.UTF8Encoding($false)))
$draft=[IO.File]::ReadAllText($receipt.SprintPlanPath)
Assert ($draft.Contains('Decisoes confirmadas') -and $draft.Contains('Entregas e criterios de aceite') -and $draft -notmatch '\{\{') 'Preparo deve aplicar template claro, sem placeholders obscuros.'
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
Assert ($result.ReviewPromptPath -eq $receipt.ReviewPromptPath) 'Validacao deve oferecer prompt de analise capturado.'
$publishedHashes=@($receipt.ContextPath,$receipt.SprintDataPath,$receipt.SprintPlanPath,$receipt.ValidationPath,$receipt.ReviewPromptPath | ForEach-Object { (Get-FileHash -LiteralPath $_).Hash }) -join '|'
$retry=Complete-HarnessSprintPlan $fixture $receipt.ContextPath
Assert (($publishedHashes -ceq (@($receipt.ContextPath,$receipt.SprintDataPath,$receipt.SprintPlanPath,$receipt.ValidationPath,$receipt.ReviewPromptPath | ForEach-Object { (Get-FileHash -LiteralPath $_).Hash }) -join '|')) -and $retry.ReviewPromptPath -eq $receipt.ReviewPromptPath) 'Retry deve preservar bytes dos artefatos e prompt.'
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
Assert ($revision.ReviewPromptPath -ne $receipt.ReviewPromptPath -and [IO.File]::ReadAllText($revision.ReviewPromptPath).Contains($revision.ValidationPath)) 'Nova revisao exige prompt com destinos proprios.'
Assert (@($revision.InputChanges | Where-Object Path -EQ $evidence).Count -eq 1) 'Mudanca de arquivo fornecido nao aparece para reestimativa.'
$data=Get-Content $revision.SprintDataPath -Raw | ConvertFrom-Json
$data.EvidenceReview=[pscustomobject]@{Reviewed=$true;Reason='Nova premissa aumenta esforco Dev em 2 dias-pessoa.'}
$data.Work[1].Effort.Dev=[pscustomobject]@{Min=6;Reference=6;Max=6}
Save $revision.SprintDataPath $data
$updated=Complete-HarnessSprintPlan $fixture $revision.ContextPath
Assert ($updated.DataSnapshot.Simulation.ProductionDate -eq '2026-10-19') 'Nova evidencia/estimativa deveria deslocar producao, respeitando fim de semana.'
Assert ((Get-Content $receipt.ValidationPath -Raw | ConvertFrom-Json).DataSnapshot.Simulation.ProductionDate -eq '2026-10-16') 'Reestimativa apagou previsao anterior.'
Assert ((Get-FileHash $register.MigrationPath).Hash -eq $before) 'Planejamento macro alterou registro de migracao.'
$historyRevision=New-HarnessSprintContext $context -PreviousContextPath $revision.ContextPath -Reason 'Revisar trabalho restante na segunda sprint'
$data=Get-Content $historyRevision.SprintDataPath -Raw | ConvertFrom-Json
$data.Constraints.ReferenceDate='2026-10-26'
$data.Work[0].Effort=[pscustomobject]@{Dev=@{Min=0;Reference=0;Max=0};Architect=@{Min=0;Reference=0;Max=0};DevOps=@{Min=0;Reference=0;Max=0}}
Save $historyRevision.SprintDataPath $data
$remaining=Complete-HarnessSprintPlan $fixture $historyRevision.ContextPath
Assert ($remaining.Feasibility -eq 'NAO_CABE') 'Teste restante nao pode reutilizar o limite consumido de campanha de testes.'
Assert (($remaining.DataSnapshot.Simulation.Sprints[0] | ConvertTo-Json -Depth 40) -ceq ($updated.DataSnapshot.Simulation.Sprints[0] | ConvertTo-Json -Depth 40)) 'Integracao deve preservar sprint encerrada antes de calcular capacidade restante.'
$reason=@($remaining.DataSnapshot.Simulation.Unscheduled | Where-Object Id -EQ 'Testar-integracao')[0].Reason
Assert ($reason -like '*MaxTestSprints esgotado: 1 de 1*' -and $reason -like '*Dev=2*') 'Retorno deve justificar deterministicamente limite e esforco que nao couberam.'
$markdown=[IO.File]::ReadAllText($historyRevision.SprintPlanPath)
Assert ($markdown.Contains($reason) -and $markdown.Contains('Conferencia deterministica') -and $markdown.Contains('Composicao e movimentos')) 'Markdown deve mostrar os mesmos motivos e limites do JSON.'

$shortDeadline=New-HarnessSprintContext $context -All
$shortData=Get-Content $shortDeadline.SprintDataPath -Raw | ConvertFrom-Json
$shortData.Constraints=$updated.DataSnapshot.Constraints | ConvertTo-Json | ConvertFrom-Json
$shortData.Constraints.ProductionDeadline='2026-10-14'
$shortData.Team=$updated.DataSnapshot.Team
$shortData.Work=$updated.DataSnapshot.Work
Save $shortDeadline.SprintDataPath $shortData
$tooShort=Complete-HarnessSprintPlan $fixture $shortDeadline.ContextPath
Assert ($tooShort.Feasibility -eq 'NAO_CABE' -and $null -eq $tooShort.DataSnapshot.Simulation.ProductionDate) 'Prazo menor que a sequencia exigida nao pode receber CABE.'
$deployReason=@($tooShort.DataSnapshot.Simulation.Unscheduled | Where-Object Id -EQ 'Implantar-producao')[0].Reason
Assert ($deployReason -like '*Dependencias nao concluidas: Testar-integracao*' -and $deployReason -like '*2026-10-14*') 'Prazo nao atendido exige causa e horizonte calculados.'
$riskReceipt=New-HarnessSprintContext $context -All
$riskData=$shortData | ConvertTo-Json -Depth 60 | ConvertFrom-Json
$riskData.PlanningId=$riskReceipt.PlanningId;$riskData.RevisionId=$riskReceipt.RevisionId
$riskData.Constraints.ProductionDeadline='2026-11-08';$riskData.Work[1].Effort.Dev.Max=50
Save $riskReceipt.SprintDataPath $riskData
$riskResult=Complete-HarnessSprintPlan $fixture $riskReceipt.ContextPath
Assert ($riskResult.Feasibility -eq 'EM_RISCO' -and $riskResult.DataSnapshot.Simulation.Unscheduled.Count -eq 0) 'Referencia deve caber e deixar risco somente na faixa superior.'
$riskReason=@($riskResult.DataSnapshot.Simulation.Scenarios.Max.Unscheduled | Where-Object Id -EQ 'Migrar-APIs')[0].Reason
$riskMarkdown=[IO.File]::ReadAllText($riskReceipt.SprintPlanPath)
Assert ($riskMarkdown.Contains('Sensibilidade ao esforco superior') -and $riskMarkdown.Contains($riskReason)) 'Risco da faixa superior exige justificativa deterministica visivel mesmo sem sobra na referencia.'

# A legacy receipt does not acquire an uncaptured prompt on validation.
$legacy=New-HarnessSprintContext $context -All
$legacy.PSObject.Properties.Remove('ReviewPromptPath')
Save $legacy.ContextPath $legacy
$sealPath=Join-Path (Split-Path $legacy.ContextPath -Parent) 'preparo.json'
$seal=Get-Content $sealPath -Raw | ConvertFrom-Json
$seal.PSObject.Properties.Remove('ReviewPromptSha256');$seal.ContextSha256=(Get-FileHash $legacy.ContextPath).Hash
Save $sealPath $seal
$legacyResult=Complete-HarnessSprintPlan $fixture $legacy.ContextPath
Assert (-not $legacyResult.PSObject.Properties['ReviewPromptPath']) 'Legado nao pode ganhar prompt silenciosamente.'
$capturedHash=(Get-FileHash $riskReceipt.ReviewPromptPath).Hash
[IO.File]::AppendAllText((Join-Path $fixture '.github/prompts/revisar-sprints.prompt.md'),"`nNova orientacao fixture.")
$rejected=$false
try { $null=Complete-HarnessSprintPlan $fixture $riskReceipt.ContextPath } catch { $rejected=$_.Exception.Message -like '*Revisar*' }
Assert $rejected 'Mudanca do contrato de revisao exige Revisar.'
Assert ((Get-FileHash $riskReceipt.ReviewPromptPath).Hash -ceq $capturedHash) 'Template novo nao pode reescrever prompt capturado.'
$withNewContract=New-HarnessSprintContext $context -PreviousContextPath $riskReceipt.ContextPath -Reason 'Adotar contrato atualizado'
Assert ([IO.File]::ReadAllText($withNewContract.ReviewPromptPath).Contains('Nova orientacao fixture.')) 'Revisar deve capturar a nova orientacao.'
Write-Output ('PASS: fluxo completo com JBoss, issues mandatory, testes, producao, Gantt e reestimativa rastreavel. Fixture: '+$fixture)
