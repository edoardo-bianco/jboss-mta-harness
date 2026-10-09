#requires -Version 5.1
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
. (Join-Path $root 'scripts/HarnessSprintSimulation.ps1')
function Assert($condition,[string]$message) { if (-not $condition) { throw $message } }
function Expect-Error([scriptblock]$Action,[string]$message) {
    $failed=$false; try { & $Action | Out-Null } catch { $failed=$true }
    Assert $failed $message
}
function Issue([string]$id='I1',[string]$source='C:/app') { [pscustomobject]@{Source=$source;Id=$id} }
function Work([string]$id='W1',[decimal]$dev=5,[decimal]$arch=0,[decimal]$ops=0,[string]$phase='IMPLEMENTATION') {
    [pscustomobject]@{Id=$id;Title=$id;Phase=$phase;Priority=1;DependsOn=@();Issues=@((Issue));
        Effort=[pscustomobject]@{Dev=[pscustomobject]@{Min=$dev;Reference=$dev;Max=$dev};Architect=[pscustomobject]@{Min=$arch;Reference=$arch;Max=$arch};DevOps=[pscustomobject]@{Min=$ops;Reference=$ops;Max=$ops}};
        EstimateSource='fixture';Confidence='ALTA';Assumptions='Equipes distintas';NotBefore=$null;Deadline=$null;Acceptance='evidencia';References=@();Remaining=$true}
}
function New-TestData {
    [pscustomobject]@{SchemaVersion=1;Purpose='sprint-planning';PlanningId='fixture';RevisionId='r1';
        Constraints=[pscustomobject]@{SprintStartDate='2026-12-21';ProductionDeadline='2027-01-17';ReferenceDate='2026-12-21';MaxPreparationSprints=2;MaxImplementationSprints=2;MaxTestSprints=2;MaxTotalSprints=$null;MaxDevelopers=2};
        Team=[pscustomobject]@{WorkWeek=@(1,2,3,4,5);Holidays=@();Staffing=@(1,2 | ForEach-Object { [pscustomobject]@{Sprint=$_;Developers=2;DeveloperAvailability=1;ArchitectAvailability=1;DevOpsAvailability=1;ReservePercent=0;AbsenceDays=[pscustomobject]@{Dev=0;Architect=0;DevOps=0}} })};
        Baseline=[pscustomobject]@{Id='B0';Known=$true;Issues=@((Issue));Accepted=@()};Changes=[pscustomobject]@{New=@();Reopened=@();Excluded=@()};Work=@((Work))}
}
$data=New-TestData; $before=$data | ConvertTo-Json -Depth 30
$result=Get-HarnessSprintSimulation -Data $data
Assert ($result.Sprints.Count -eq 2 -and $result.Sprints[0].Start -eq '2026-12-21' -and $result.Sprints[0].End -eq '2027-01-03' -and $result.Sprints[1].Start -eq '2027-01-04') 'Calendario inclusivo de 14 dias deve atravessar ano.'
Assert ($result.Sprints[0].Capacity.Dev -eq 20 -and $result.Sprints[0].Capacity.Architect -eq 10) 'Capacidade deve permanecer separada por papel.'
Assert ($result.Feasibility -eq 'NAO_AVALIAVEL' -and $result.Sprints[0].ForecastPercent -eq 100 -and $result.Sprints[0].ActualPercent -eq 0) 'Previsao nao pode virar realizado ou producao sem implantacao.'
Assert (($data | ConvertTo-Json -Depth 30) -ceq $before) 'Motor nao pode alterar entrada.'
Assert (($result | ConvertTo-Json -Depth 40) -ceq ((Get-HarnessSprintSimulation $data) | ConvertTo-Json -Depth 40)) 'Mesma entrada deve produzir mesma saida.'

$data=New-TestData; $data.Constraints.ProductionDeadline='2026-12-23';$data.Team.Holidays=@('2026-12-22');$data.Work=@((Work 'W' 4))
$result=Get-HarnessSprintSimulation $data
Assert ($result.Sprints[0].End -eq '2027-01-03' -and $result.Sprints[0].Capacity.Dev -eq 4) 'Prazo no meio da sprint e feriado reduzem capacidade sem encurtar sprint.'
Assert ($result.Unscheduled.Count -eq 0) 'Carga no corte exato deve caber, ainda sem confirmar producao.'
$data.Work[0].Effort.Dev.Reference=5;$data.Work[0].Effort.Dev.Max=5
Assert ((Get-HarnessSprintSimulation $data).Feasibility -eq 'NAO_CABE') 'Carga alem do prazo deve falhar.'

$data=New-TestData;$data.Constraints.ReferenceDate='2026-12-28';$data.Team.Staffing[0].ReservePercent=20;$data.Team.Staffing[0].AbsenceDays.Dev=2
$result=Get-HarnessSprintSimulation $data
Assert ($result.Sprints[0].Capacity.Dev -eq 6.4) 'Descontar passado, ausencia em dias-pessoa restantes e reserva uma vez.'
$data=New-TestData;$data.Work=@((Work 'W' 0 21 0))
Assert ((Get-HarnessSprintSimulation $data).Feasibility -eq 'NAO_CABE') 'Capacidade dev nao substitui arquiteto.'
$data=New-TestData;$data.Team.Staffing=@();$result=Get-HarnessSprintSimulation $data
Assert ($result.Feasibility -eq 'NAO_AVALIAVEL' -and $null -eq $result.Sprints[0].Capacity.Dev) 'Staffing ausente nao vira capacidade zero conhecida.'

$data=New-TestData;$a=Work 'A' 20;$b=Work 'B' 2;$b.DependsOn=@('A');$data.Work=@($b,$a)
$result=Get-HarnessSprintSimulation $data
Assert ($result.Sprints[0].ForecastCount -eq 0 -and $result.Sprints[1].ForecastCount -eq 1) 'Issue com varios trabalhos so termina quando todos concluem, sem duplicar.'
Assert ($result.Sprints[1].Activities[0].Id -eq 'B') 'Dependencia deve ser respeitada mesmo com ordem invertida.'
$data.Constraints.MaxImplementationSprints=1
Assert ((Get-HarnessSprintSimulation $data).Feasibility -eq 'NAO_CABE') 'Limite por fase conta sprints com carga.'

$data=New-TestData;$a=Work 'A' 2;$b=Work 'B' 2;$b.Issues=@((Issue 'I1' 'C:/other'));$data.Work=@($a,$b);$data.Baseline.Issues=@((Issue),(Issue 'I1' 'C:/other'),(Issue))
$result=Get-HarnessSprintSimulation $data
Assert ($result.BaselineCount -eq 2 -and $result.Sprints[0].ForecastCount -eq 2) 'Source/Id unico, mesmo ID em Sources diferentes e duplicata da baseline.'
$data.Baseline.Known=$false;$result=Get-HarnessSprintSimulation $data
Assert ($null -eq $result.BaselineCount -and $null -eq $result.Sprints[0].ForecastPercent) 'Base desconhecida exige percentual N/A.'
$data.Baseline.Known=$true;$data.Baseline.Issues=@();$result=Get-HarnessSprintSimulation $data
Assert ($result.BaselineCount -eq 0 -and $null -eq $result.Sprints[0].ForecastPercent) 'Base vazia exige percentual N/A.'

$data=New-TestData;$data.Work=@();$data.Baseline.Accepted=@([pscustomobject]@{Source='C:/app';Id='I1';Evidence='teste';AcceptedBy='humano'})
Assert ((Get-HarnessSprintSimulation $data).Sprints[0].ActualCount -eq 1) 'Aceite comprovado anterior entra no realizado.'
$data.Changes.Reopened=@((Issue));Assert ((Get-HarnessSprintSimulation $data).Sprints[0].ActualCount -eq 0) 'Reabertura reduz realizado atual.'
$data.Changes.Reopened=@();$data.Changes.Excluded=@((Issue));Assert ((Get-HarnessSprintSimulation $data).Sprints[0].ForecastCount -eq 0) 'Exclusao nao conta corretiva concluida.'
$data=New-TestData;$data.Baseline.Accepted=@([pscustomobject]@{Source='C:/app';Id='I1';Evidence=$null;AcceptedBy='humano'});
Assert ((Get-HarnessSprintSimulation $data).Sprints[0].ActualCount -eq 0) 'Sem evidencia nao ha aceite comprovado.'

$data=New-TestData;$data.Work[0].Effort.Dev.Reference=$null;$result=Get-HarnessSprintSimulation $data
Assert ($result.State -eq 'RASCUNHO' -and $result.Feasibility -eq 'NAO_AVALIAVEL' -and $result.Unscheduled.Count -eq 1) 'Estimativa ausente nao e zero.'
$data=New-TestData;$data.Constraints.SprintStartDate=$null;$result=Get-HarnessSprintSimulation $data
Assert ($result.State -eq 'RASCUNHO' -and $result.Sprints.Count -eq 0) 'Inicio ausente produz rascunho.'
$data=New-TestData;$data.Work[0].Effort.Dev.Max=41;$deploy=Work 'DEPLOY' 0 0 1 'DEPLOYMENT';$deploy.Issues=@();$deploy.DependsOn=@('W1');$data.Work+=$deploy;$result=Get-HarnessSprintSimulation $data
Assert ($result.Feasibility -eq 'EM_RISCO' -and $result.Scenarios.Max.Feasibility -eq 'NAO_CABE') 'Sensibilidade superior deve revelar risco.'

$data=New-TestData;$deploy=Work 'DEPLOY' 0 0 1 'DEPLOYMENT';$deploy.DependsOn=@('W1');$deploy.Issues=@();$data.Work+= $deploy
$result=Get-HarnessSprintSimulation $data
Assert ($result.ProductionDate -eq '2026-12-24') 'Producao depende do fim real da implantacao e precedencia.'
$data=New-TestData;$data.Constraints.MaxTotalSprints=1;$data.Work=@((Work 'W' 21));Assert ((Get-HarnessSprintSimulation $data).Feasibility -eq 'NAO_CABE') 'Limite total corta horizonte mesmo com prazo posterior.'
$data=New-TestData;$data.Work[0].NotBefore='2027-01-04';$result=Get-HarnessSprintSimulation $data
Assert ($result.Sprints[0].Activities.Count -eq 0 -and $result.Sprints[1].Activities.Count -eq 1) 'NotBefore deve adiar alocacao.'
$data.Work[0].Deadline='2026-12-30';Expect-Error { Get-HarnessSprintSimulation $data } 'Janela invertida deve ser invalida.'

foreach ($invalid in @('2026-02-30','2026-1-01','texto')) { $data=New-TestData;$data.Constraints.SprintStartDate=$invalid;Expect-Error { Get-HarnessSprintSimulation $data } 'Data invalida aceita.' }
$data=New-TestData;$data.Constraints.ProductionDeadline='2026-12-20';Expect-Error { Get-HarnessSprintSimulation $data } 'Prazo antes do inicio aceito.'
$data=New-TestData;$data.Constraints.MaxPreparationSprints=-1;Expect-Error { Get-HarnessSprintSimulation $data } 'Limite negativo aceito.'
$data=New-TestData;$data.Team.Staffing[0].Developers=3;Expect-Error { Get-HarnessSprintSimulation $data } 'Equipe acima do teto aceita.'
$data=New-TestData;$data.Work[0].DependsOn=@('missing');Expect-Error { Get-HarnessSprintSimulation $data } 'Dependencia inexistente aceita.'
$data=New-TestData;$data.Work[0].DependsOn=@('W1');Expect-Error { Get-HarnessSprintSimulation $data } 'Autociclo aceito.'
$data=New-TestData;$a=Work 'A';$b=Work 'B';$a.DependsOn=@('B');$b.DependsOn=@('A');$data.Work=@($a,$b);Expect-Error { Get-HarnessSprintSimulation $data } 'Ciclo aceito.'
$data=New-TestData;$data.Work[0].Effort.Dev.Min=6;Expect-Error { Get-HarnessSprintSimulation $data } 'Faixa invertida aceita.'
$data=New-TestData;$data.Work[0].Effort.Dev.Reference=-1;Expect-Error { Get-HarnessSprintSimulation $data } 'Esforco negativo aceito.'
$result=Get-HarnessSprintSimulation $null;Assert ($result.State -eq 'RASCUNHO' -and $result.Feasibility -eq 'NAO_AVALIAVEL') 'Data null exige rascunho.'
$data=New-TestData;$data.Baseline.Issues+=(Issue 'SEM-FICHA');$result=Get-HarnessSprintSimulation $data
Assert ($result.Feasibility -eq 'NAO_AVALIAVEL' -and $result.Unscheduled[0].Id -eq 'SEM-FICHA') 'Issue fora das fichas tambem exige trabalho.'
$data=New-TestData;$data.Changes.New=@((Issue 'NOVA'));$result=Get-HarnessSprintSimulation $data
Assert ($result.BaselineCount -eq 1 -and $result.Unscheduled[0].Id -eq 'NOVA') 'Mudanca exige trabalho sem alterar B0.'
$data=New-TestData;$data.Baseline.Issues+=Issue 'i1';$result=Get-HarnessSprintSimulation $data
Assert ($result.BaselineCount -eq 2 -and $result.Sprints[0].ForecastCount -eq 1 -and $result.Unscheduled.Count -eq 1) 'ID diferencia maiusculas; Source normaliza separadores.'
$data=New-TestData;$deploy=Work 'DEPLOY' 0 0 1 'DEPLOYMENT';$deploy.Issues=@();$data.Work+=$deploy;$result=Get-HarnessSprintSimulation $data
Assert ($null -eq $result.ProductionDate -and $result.Feasibility -eq 'NAO_AVALIAVEL') 'Deploy anterior ao fim do trabalho nao comprova producao.'
$data=New-TestData;$data.Work[0].Effort.Dev.Reference=$null;$blocked=Work 'BLOCKED' 100;$blocked.DependsOn=@('W1');$data.Work+=$blocked
Assert ((Get-HarnessSprintSimulation $data).Feasibility -eq 'NAO_AVALIAVEL') 'Lacuna essencial prevalece sobre falta de alocacao dependente.'
$data=New-TestData;$data.Constraints.ProductionDeadline=$null;$data.Constraints.MaxTotalSprints=2
$deploy=Work 'DEPLOY' 0 0 1 'DEPLOYMENT';$deploy.Issues=@();$deploy.DependsOn=@('W1');$data.Work+=$deploy
$result=Get-HarnessSprintSimulation $data
Assert ($result.Feasibility -eq 'NAO_AVALIAVEL' -and $result.State -eq 'RASCUNHO' -and $null -eq $result.ProductionDate) 'Sem prazo de producao, limite total nao pode comprovar viabilidade.'
Assert ($result.Sprints.Count -eq 2) 'Horizonte informado deve continuar disponivel no rascunho sem prazo.'

# A revision consumes the original phase allowance, including a partly elapsed sprint.
$data=New-TestData;$data.Constraints.MaxImplementationSprints=1
$deploy=Work 'DEPLOY' 0 0 1 'DEPLOYMENT';$deploy.Issues=@();$deploy.DependsOn=@('W1');$data.Work+=$deploy
$previous=Get-HarnessSprintSimulation $data;$previousJson=$previous | ConvertTo-Json -Depth 50
$data.Constraints.ReferenceDate='2027-01-04'
$result=Get-HarnessSprintSimulation -Data $data -PreviousSimulation $previous
Assert ($result.Feasibility -eq 'NAO_CABE' -and $result.PhaseSprintCounts.Implementation -eq 1) 'Revisao nao pode reutilizar limite de fase ja consumido.'
Assert (($result.Sprints[0] | ConvertTo-Json -Depth 30) -ceq ($previous.Sprints[0] | ConvertTo-Json -Depth 30)) 'Sprint encerrada deve permanecer identica ao historico.'
Assert (($previous | ConvertTo-Json -Depth 50) -ceq $previousJson) 'Revisao nao pode mutar a simulacao anterior.'
$data.Constraints.MaxImplementationSprints=2
$result=Get-HarnessSprintSimulation -Data $data -PreviousSimulation $previous
Assert ($result.Feasibility -eq 'CABE_NAS_PREMISSAS' -and $result.PhaseSprintCounts.Implementation -eq 2 -and $result.Sprints[1].Load.Dev -eq 5) 'Revisao deve alocar apenas o esforco restante no limite total ampliado.'
$data.Constraints.MaxImplementationSprints=0;$data.Work=@($deploy);$data.Work[0].DependsOn=@();$data.Baseline.Accepted=@([pscustomobject]@{Source='C:/app';Id='I1';Evidence='teste';AcceptedBy='humano'})
$result=Get-HarnessSprintSimulation -Data $data -PreviousSimulation $previous
Assert ($result.Feasibility -eq 'NAO_CABE') 'Reduzir teto abaixo do historico exige violacao mesmo sem trabalho restante na fase.'
$data=New-TestData;$data.Constraints.MaxImplementationSprints=1;$data.Constraints.ReferenceDate='2026-12-28';$data.Work[0].Effort.Dev.Min=11;$data.Work[0].Effort.Dev.Reference=11;$data.Work[0].Effort.Dev.Max=11
$result=Get-HarnessSprintSimulation -Data $data -PreviousSimulation $previous
Assert ($result.Feasibility -eq 'NAO_CABE' -and $result.PhaseSprintCounts.Implementation -eq 1 -and $result.Sprints[0].Load.Dev -eq 10) 'Sprint em andamento conta uma vez e usa somente capacidade restante.'
$data=New-TestData;$data.Constraints.SprintStartDate=$null;$data.Constraints.MaxTotalSprints=3
$result=Get-HarnessSprintSimulation $data
Assert ($result.Sprints.Count -eq 3 -and $result.Sprints[2].Number -eq 3 -and $null -eq $result.Sprints[0].Start -and $null -eq $result.Sprints[0].Capacity.Dev -and $result.Feasibility -eq 'NAO_AVALIAVEL') 'Rascunho relativo deve mostrar Sprint 1..N sem datas ou capacidade inventadas.'
$data=New-TestData;$data.Constraints.ReferenceDate='2026-12-28';$data.Work=@();$data.Baseline.Accepted=@([pscustomobject]@{Source='C:/app';Id='I1';Evidence='teste';AcceptedBy='humano'})
$intermediate=Get-HarnessSprintSimulation -Data $data -PreviousSimulation $previous
$data=New-TestData;$data.Constraints.ReferenceDate='2027-01-04';$data.Constraints.MaxImplementationSprints=1
$result=Get-HarnessSprintSimulation -Data $data -PreviousSimulation $intermediate
Assert ($result.Feasibility -eq 'NAO_CABE' -and $result.PhaseSprintCounts.Implementation -eq 1) 'Revisoes sucessivas nao podem esquecer fase consumida em sprint antes em andamento.'
$data=New-TestData;$data.Work=@((Work 'W' 0));$data.Constraints.MaxImplementationSprints=0
$deploy=Work 'DEPLOY' 0 0 1 'DEPLOYMENT';$deploy.DependsOn=@('W');$deploy.Issues=@();$data.Work+=$deploy
$result=Get-HarnessSprintSimulation $data
Assert ($result.Feasibility -eq 'CABE_NAS_PREMISSAS' -and $result.PhaseSprintCounts.Implementation -eq 0) 'Marco de esforco zero nao deve consumir limite de fase nem bloquear dependentes.'
$data=New-TestData;$previous=Get-HarnessSprintSimulation $data
$data.Constraints.ReferenceDate='2027-01-04';$data.Team.Staffing=@($data.Team.Staffing[1]);$data.Work=@((Work 'W' 25))
$result=Get-HarnessSprintSimulation -Data $data -PreviousSimulation $previous
Assert ($result.Feasibility -eq 'NAO_CABE') 'Staffing de sprint encerrada nao pode contaminar capacidade futura conhecida.'
Assert ($result.Unscheduled[0].Reason -like '*Dev=5*' -and $result.Unscheduled[0].Reason -like '*2027-01-17*') 'Nao cabe deve explicar esforco nao alocado e horizonte deterministico.'
$data=New-TestData;$data.Work[0].Effort.Dev=[pscustomobject]@{Min=5;Reference=25;Max=30}
$previous=Get-HarnessSprintSimulation $data
$data.Constraints.ReferenceDate='2027-01-18';$data.Constraints.ProductionDeadline='2027-01-31';$data.Work=@()
$result=Get-HarnessSprintSimulation -Data $data -PreviousSimulation $previous
Assert ($result.PhaseSprintCounts.Implementation -eq 2 -and $result.Scenarios.Min.PhaseSprintCounts.Implementation -eq 2 -and $result.Scenarios.Max.PhaseSprintCounts.Implementation -eq 2) 'Cenarios variam somente o futuro, preservando o mesmo passado publicado.'
Write-Host 'PASS: SprintSimulation calendario, capacidade, precedencias, baseline, cenarios, revisoes e lacunas.'
