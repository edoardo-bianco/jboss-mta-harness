#requires -Version 5.1
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'SprintCurrentFixture.ps1')
$f=New-SprintFixture
$current=New-HarnessSprintContext $f.Context -All
Assert ($current.MasterProject -ceq 'a' -and $current.SprintPlanPath -eq (Join-Path $f.Projects[0].Folder 'atual/sprints/migracao/plano.md')) 'Destino deve ser o cenario funcional no participante.'
$initialFiles=@(Get-ChildItem -LiteralPath (Split-Path $current.ContextPath -Parent) -File | ForEach-Object Name)
Assert ($initialFiles.Count -eq 5 -and $initialFiles -notcontains 'preparo.json') 'Preparo nao deve criar selo/recibo/historico.'
$data=Read-SprintData $current
Assert ($data.Baseline.Issues.Count -eq 2 -and -not $data.PSObject.Properties['Simulation']) 'Baseline inicial e dados editaveis incorretos.'
Set-SprintPremises $data
$evidence=Join-Path $f.Projects[0].EvidencePath 'estimativa.md'
[IO.File]::WriteAllText($evidence,'Premissa humana sintetica.')
$issues=@($data.Baseline.Issues)
$data.Work=@((New-SprintWork 'Preparar-JBoss' PREPARATION 1 @() 0 1 1 @() @($evidence)),
    (New-SprintWork 'Migrar-APIs' IMPLEMENTATION 2 @('Preparar-JBoss') 4 0 0 $issues @($evidence)),
    (New-SprintWork 'Testar-integracao' TEST 3 @('Migrar-APIs') 2 0 0 $issues @($evidence)),
    (New-SprintWork 'Implantar-producao' DEPLOYMENT 4 @('Testar-integracao') 0 0 1 @() @($evidence)))
Save-SprintData $current $data
[IO.File]::AppendAllText($current.SprintPlanPath,([Environment]::NewLine+'Contribuicao humana preservada.'+[Environment]::NewLine))
$registerBefore=[IO.File]::ReadAllText($f.Projects[0].MigrationPath)
$result=Complete-HarnessSprintPlan $f.Root $current.ContextPath
Assert ($result.Feasibility -eq 'CABE_NAS_PREMISSAS' -and $result.Simulation.ProductionDate -eq '2026-10-16') 'Mesmo calculo deve implantar no quinto dia util.'
Assert ($result.Simulation.Sprints[0].ForecastPercent -eq 100 -and $result.Simulation.Sprints[0].ActualCount -eq 0) 'Previsao nao pode virar realizado.'
Assert (-not $result.PSObject.Properties['DataSnapshot'] -and -not $result.PSObject.Properties['RevisionId']) 'Resultado corrente nao deve duplicar os dados ou recibos.'
$markdown=[IO.File]::ReadAllText($current.SprintPlanPath)
Assert ($markdown.Contains('Contribuicao humana') -and $markdown.Contains('mermaid') -and $markdown.Contains('Ultimo calculo publicado')) 'Plano deve preservar notas, Gantt e limite da validacao.'
$before=Get-PlanningFixtureState $f
$retry=Complete-HarnessSprintPlan $f.Root $current.ContextPath
Assert ((Get-PlanningFixtureState $f) -ceq $before) 'Validacao repetida deve manter mesmos bytes/numeros.'
$resume=New-HarnessSprintContext $f.Context -ContextPath $current.ContextPath
Assert ($resume.Reused -and $resume.ContextPath -eq $current.ContextPath) 'Retomar deve usar mesmos documentos.'
$resultBefore=[IO.File]::ReadAllText($current.ValidationPath)
$revised=New-HarnessSprintContext $f.Context -ContextPath $current.ContextPath -Reason 'Nova premissa de esforco'
Assert ([IO.File]::ReadAllText($current.ValidationPath) -ceq $resultBefore) 'Preparo nao pode apagar ultimo calculo.'
$data=Read-SprintData $current
$data.Work[1].Effort.Dev=[pscustomobject]@{Min=6;Reference=6;Max=6}
$data.EvidenceReview=[pscustomobject]@{Reviewed=$true;Reason='Evidencia atual relida; mais dois dias-pessoa Dev.'}
Save-SprintData $current $data
$updated=Complete-HarnessSprintPlan $f.Root $current.ContextPath
Assert ($updated.Simulation.ProductionDate -eq '2026-10-19') 'Reestimativa deve respeitar fim de semana.'
$data=Read-SprintData $current
$data.Constraints.ReferenceDate='2026-10-26'
$data.Work[0].Effort=[pscustomobject]@{Dev=@{Min=0;Reference=0;Max=0};Architect=@{Min=0;Reference=0;Max=0};DevOps=@{Min=0;Reference=0;Max=0}}
Save-SprintData $current $data
$remaining=Complete-HarnessSprintPlan $f.Root $current.ContextPath
Assert ($remaining.Feasibility -eq 'NAO_CABE') 'Fase teste consumida nao pode ser reutilizada.'
Assert (($remaining.Simulation.Sprints[0] | ConvertTo-Json -Depth 40) -ceq ($updated.Simulation.Sprints[0] | ConvertTo-Json -Depth 40)) 'Sprint encerrada deve permanecer no cenario corrente.'
$reason=@($remaining.Simulation.Unscheduled | Where-Object Id -EQ 'Testar-integracao')[0].Reason
Assert ($reason -like '*MaxTestSprints esgotado: 1 de 1*' -and [IO.File]::ReadAllText($current.SprintPlanPath).Contains($reason)) 'Plano deve mostrar consumo e motivo calculados.'
Assert ([IO.File]::ReadAllText($f.Projects[0].MigrationPath) -ceq $registerBefore) 'Sprints nao altera decisoes de migracao.'
Assert (-not (Test-Path (Join-Path $f.Root '.harness/sprints'))) 'Fluxo nao deve criar raiz legada.'
$short=New-HarnessSprintContext $f.Context -All -Scenario 'prazo-curto'
$shortData=Read-SprintData $short; Set-SprintPremises $shortData
$shortData.Work=$data.Work; $shortData.Work[0].Effort.Architect.Reference=1; $shortData.Work[0].Effort.Architect.Min=1; $shortData.Work[0].Effort.Architect.Max=1
$shortData.Constraints.ProductionDeadline='2026-10-14'
Save-SprintData $short $shortData
$tooShort=Complete-HarnessSprintPlan $f.Root $short.ContextPath
Assert ($tooShort.Feasibility -eq 'NAO_CABE' -and $null -eq $tooShort.Simulation.ProductionDate) 'Janela curta nao recebe CABE.'
$risk=New-HarnessSprintContext $f.Context -All -Scenario risco
$riskData=Read-SprintData $risk; Set-SprintPremises $riskData
$riskData.Work=$shortData.Work; $riskData.Work[1].Effort.Dev.Max=50
Save-SprintData $risk $riskData
$riskResult=Complete-HarnessSprintPlan $f.Root $risk.ContextPath
Assert ($riskResult.Feasibility -eq 'EM_RISCO') 'Faixa superior deve explicitar risco.'
Assert ([IO.File]::ReadAllText($risk.SprintPlanPath).Contains('Sensibilidade ao esforco superior')) 'Risco deve ter explicacao legivel.'
Write-Host 'PASS: sprints correntes, paridade do calculo, continuidade, risco, Gantt e notas humanas.'
