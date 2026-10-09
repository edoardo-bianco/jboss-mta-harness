#requires -Version 5.1
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $root 'scripts/HarnessSprintSimulation.ps1')
. (Join-Path $root 'scripts/HarnessSprintPresentation.ps1')

function Assert($condition, [string]$message) { if (-not $condition) { throw $message } }
function Reject([scriptblock]$action, [string]$message) {
    $rejected = $false
    try { $null = & $action } catch { $rejected = $true }
    Assert $rejected $message
}
function Near($actual, [decimal]$expected, [string]$message) {
    Assert ($null -ne $actual -and [math]::Abs([decimal]$actual - $expected) -lt 0.000000001) $message
}
function Issue { [pscustomobject]@{Source='C:/fixture/api';Id='I1'} }
function Work([string]$id, [decimal]$dev=0, [decimal]$arch=0, [decimal]$ops=0, [string]$phase='IMPLEMENTATION') {
    [pscustomobject]@{
        Id=$id;Title=$id;Phase=$phase;Priority=2;DependsOn=@();Issues=@()
        Effort=[pscustomobject]@{
            Dev=[pscustomobject]@{Min=$dev;Reference=$dev;Max=$dev}
            Architect=[pscustomobject]@{Min=$arch;Reference=$arch;Max=$arch}
            DevOps=[pscustomobject]@{Min=$ops;Reference=$ops;Max=$ops}
        }
        EstimateSource='Estimativa humana desta fixture';Confidence='ALTA';Assumptions=@('Pessoas distintas por papel')
        NotBefore=$null;Deadline=$null;Acceptance='Evidencia conferida';References=@();Remaining=$true
    }
}
function New-TestData {
    $implementation = Work 'IMPLEMENTAR' 2 2
    $implementation.Issues = @((Issue))
    $deployment = Work 'DEPLOY' 0 0 1 'DEPLOYMENT'
    $deployment.NotBefore = '2026-10-30'
    [pscustomobject]@{
        SchemaVersion=1;Purpose='sprint-planning';PlanningId='fixture';RevisionId='r1';State='RASCUNHO';ScopeCategories=@('mandatory')
        Constraints=[pscustomobject]@{SprintStartDate='2026-10-05';ReferenceDate='2026-10-05';ProductionDeadline='2026-10-30';MaxPreparationSprints=3;MaxImplementationSprints=3;MaxTestSprints=3;MaxTotalSprints=$null;MaxDevelopers=1}
        Team=[pscustomobject]@{RolesAreDistinct=$true;WorkWeek=@(1,2,3,4,5);Holidays=@();Staffing=@(1,2,3 | ForEach-Object {
            [pscustomobject]@{Sprint=$_;Developers=1;DeveloperAvailability=1;ArchitectAvailability=1;DevOpsAvailability=1;ReservePercent=0;AbsenceDays=[pscustomobject]@{Dev=0;Architect=0;DevOps=0}}
        })}
        Baseline=[pscustomobject]@{Id='B0';Known=$true;Issues=@((Issue));Accepted=@()}
        Changes=[pscustomobject]@{New=@();Reopened=@();Excluded=@()};Work=@($implementation,$deployment);Simulation=$null
    }
}
function Add-Support($data, [decimal]$arch=9) {
    $support = Work 'SUPORTE' 0 $arch 0 'PREPARATION'
    $support.Priority = 1
    $support.NotBefore = '2026-10-05'
    $support.Deadline = '2026-10-30'
    $support | Add-Member -NotePropertyName AllocationMode -NotePropertyValue 'DISTRIBUTED'
    $data.Work = @($support) + @($data.Work)
    $support
}
function Activities($result, [string]$id) {
    @($result.Sprints | ForEach-Object { $_.Activities } | Where-Object Id -CEQ $id)
}
function Daily($result, [string]$id) {
    @(Activities $result $id | ForEach-Object { $_.DailyAllocations } | Where-Object { $null -ne $_ } | Sort-Object Date)
}
function New-AiData($percent=20) {
    $data = New-TestData
    $data | Add-Member -NotePropertyName Estimation -NotePropertyValue ([pscustomobject]@{AiDeveloperReductionPercent=$percent})
    $data.Work[0] | Add-Member -NotePropertyName AiAssisted -NotePropertyValue $true
    $data.Work[0].Effort.Dev=[pscustomobject]@{Min=5;Reference=10;Max=15}
    $data.Work[0].Effort.DevOps=[pscustomobject]@{Min=1;Reference=1;Max=1}
    $data
}
function Role-Total($result, [string]$id, [string]$role) {
    $total = [decimal]0
    foreach ($day in @(Daily $result $id)) { $total += $day.Effort.$role }
    $total
}
function New-HistoricalCompletionFixture {
    $data = New-TestData
    $previous = Get-HarnessSprintSimulation $data
    Assert (@($previous.Sprints[0].Activities | Where-Object { $_.Id -ceq 'IMPLEMENTAR' -and $_.Completed }).Count -eq 1) 'Fixture exige previsao historica de conclusao em S1.'
    $data.Constraints.ReferenceDate='2026-10-19'
    foreach ($scenario in @('Min','Reference','Max')) { $data.Work[0].Effort.Dev.$scenario=100 }
    $result = Get-HarnessSprintSimulation -Data $data -PreviousSimulation $previous
    Assert (@($result.Unscheduled | Where-Object Id -CEQ 'IMPLEMENTAR').Count -eq 1) 'Nova estimativa deveria continuar pendente alem de S2.'
    Assert (($result.Sprints[0] | ConvertTo-Json -Depth 40) -ceq ($previous.Sprints[0] | ConvertTo-Json -Depth 40)) 'Revisao alterou a previsao historica de S1.'
    [pscustomobject]@{Data=$data;Result=$result}
}
function Render($data, $result) {
    $data.Simulation = $result
    $receipt = [pscustomobject]@{RevisionId='r1';Projects=@();References=@();SprintDataPath='C:/fixture/dados.json';ContextPath='C:/fixture/contexto.json';Previous=$null}
    ConvertTo-SprintMarkdown $receipt $data "Narrativa humana.`r`n<!-- sprints:inicio -->`r`nPendente.`r`n<!-- sprints:fim -->"
}
function Gantt-Rows([string]$markdown) {
    $fence = [regex]::Match($markdown, '(?s)```mermaid\s+gantt\b(.*?)```')
    if (-not $fence.Success) { return @() }
    foreach ($line in ($fence.Groups[1].Value -split '\r?\n')) {
        if ($line -notmatch '^\s*[^:]+:\s*(.+)$') { continue }
        $body = $Matches[1]
        $dates = [regex]::Matches($body, '\d{4}-\d{2}-\d{2}')
        if (-not $dates.Count) { continue }
        $end = $null
        if ($dates.Count -gt 1) { $end = $dates[1].Value }
        elseif ($body -match ',\s*(\d+)d\s*$') { $end = ([datetime]::ParseExact($dates[0].Value,'yyyy-MM-dd',[cultureinfo]::InvariantCulture)).AddDays([int]$Matches[1]).ToString('yyyy-MM-dd') }
        [pscustomobject]@{Start=$dates[0].Value;End=$end;Milestone=($body -match '\bmilestone\b');Text=$line}
    }
}

$failures = New-Object 'Collections.Generic.List[string]'
$passed = 0
function Test-Case([string]$name, [scriptblock]$action) {
    try { $null = & $action; $script:passed++; Write-Output ('PASS: ' + $name) }
    catch { $script:failures.Add($name + ': ' + $_.Exception.Message); Write-Output ('FAIL: ' + $name + ': ' + $_.Exception.Message) }
}

Test-Case 'Fixture numerica conhecida permite avaliar a entrega' {
    $result = Get-HarnessSprintSimulation (New-TestData)
    Assert ($result.Feasibility -eq 'CABE_NAS_PREMISSAS' -and $result.ProductionDate -eq '2026-10-30') 'Controle positivo da fixture nao cabe.'
}
Test-Case 'Fases explicitamente sem limite permitem avaliar tetos null' {
    $data = New-TestData
    $data.Constraints.MaxPreparationSprints=$null; $data.Constraints.MaxImplementationSprints=$null; $data.Constraints.MaxTestSprints=$null
    $data.Constraints | Add-Member -NotePropertyName UnboundedPhases -NotePropertyValue @('PREPARATION','IMPLEMENTATION','TEST')
    $before = $data | ConvertTo-Json -Depth 40
    $result = Get-HarnessSprintSimulation $data
    Assert ($result.Feasibility -eq 'CABE_NAS_PREMISSAS' -and $result.ProductionDate -eq '2026-10-30') 'Declaracao humana sem limite foi tratada como lacuna.'
    Assert (($data | ConvertTo-Json -Depth 40) -ceq $before) 'Simulador alterou a entrada declarada.'
}
foreach ($declaration in @('ausente','vazia')) {
    Test-Case ('Tetos null com declaracao ' + $declaration + ' continuam desconhecidos') {
        $data = New-TestData
        $data.Constraints.MaxPreparationSprints=$null; $data.Constraints.MaxImplementationSprints=$null; $data.Constraints.MaxTestSprints=$null
        if ($declaration -eq 'vazia') { $data.Constraints | Add-Member -NotePropertyName UnboundedPhases -NotePropertyValue @() }
        Assert ((Get-HarnessSprintSimulation $data).Feasibility -eq 'NAO_AVALIAVEL') 'Ausencia de limite virou autorizacao implicita.'
    }
}
foreach ($invalid in @(@('INVALIDA'), @('DEPLOYMENT'), @('PREPARATION','PREPARATION'))) {
    Test-Case ('UnboundedPhases rejeita ' + ($invalid -join ',')) {
        $data = New-TestData
        $data.Constraints.MaxPreparationSprints=$null
        $data.Constraints | Add-Member -NotePropertyName UnboundedPhases -NotePropertyValue $invalid
        Reject { Get-HarnessSprintSimulation $data } 'Fase invalida ou duplicada foi aceita.'
    }
}
Test-Case 'Fase sem limite rejeita teto numerico conflitante' {
    $data = New-TestData
    $data.Constraints | Add-Member -NotePropertyName UnboundedPhases -NotePropertyValue @('PREPARATION')
    Reject { Get-HarnessSprintSimulation $data } 'Declaracao sem limite e teto numerico foram aceitos simultaneamente.'
}
foreach ($field in @('NotBefore','Deadline')) {
    Test-Case ('DISTRIBUTED exige ' + $field) {
        $data = New-TestData
        $support = Add-Support $data
        $support.$field = $null
        Reject { Get-HarnessSprintSimulation $data } 'Alocacao distribuida sem janela completa foi aceita.'
    }
}
Test-Case 'AllocationMode desconhecido e rejeitado' {
    $data = New-TestData
    $data.Work[0] | Add-Member -NotePropertyName AllocationMode -NotePropertyValue 'ALEATORIO'
    Reject { Get-HarnessSprintSimulation $data } 'Modo desconhecido foi ignorado.'
}
Test-Case 'Suporte prioritario de nove dias Arq se distribui e compartilha capacidade' {
    $data = New-TestData
    $null = Add-Support $data
    $result = Get-HarnessSprintSimulation $data
    $daily = @(Daily $result 'SUPORTE')
    Assert ($daily.Count -eq 20) 'Suporte deve ocupar os 20 dias uteis da janela, sem concentracao inicial.'
    foreach ($day in $daily) { Near $day.Effort.Architect 0.45 'Suporte nao respeitou 0,45 dia Arq/dia.'; Near $day.Effort.Dev 0 'Suporte usou Dev indevidamente.' }
    $implementation = @(Daily $result 'IMPLEMENTAR')
    Assert ($implementation.Count -gt 0 -and $implementation[0].Date -eq '2026-10-05') 'Suporte prioritario monopolizou a capacidade inicial do arquiteto.'
    Near $implementation[0].Effort.Architect 0.55 'Implementacao deve compartilhar o saldo Arq do primeiro dia.'
    Assert ($result.Feasibility -eq 'CABE_NAS_PREMISSAS' -and $result.ProductionDate -eq '2026-10-30') 'Suporte independente concluido no dia do deploy impediu producao valida.'
}
Test-Case 'Datas e carga diaria reconciliam atividade parcial e concluida por sprint' {
    $data = New-TestData
    $null = Add-Support $data
    $result = Get-HarnessSprintSimulation $data
    $activities = @(Activities $result 'SUPORTE')
    Assert ($activities.Count -eq 2) 'Distribuicao deve atravessar duas sprints.'
    Assert ($activities[0].FirstWorkDate -eq '2026-10-05' -and $activities[0].LastWorkDate -eq '2026-10-16' -and -not $activities[0].Completed -and $null -eq $activities[0].CompletionDate) 'Primeira sprint precisa de datas reais e conclusao parcial.'
    Assert ($activities[1].FirstWorkDate -eq '2026-10-19' -and $activities[1].LastWorkDate -eq '2026-10-30' -and $activities[1].Completed -and $activities[1].CompletionDate -eq '2026-10-30') 'Segunda sprint perdeu a data real de conclusao.'
    foreach ($activity in $activities) {
        foreach ($role in @('Dev','Architect','DevOps')) {
            $sum = [decimal]0
            foreach ($day in $activity.DailyAllocations) { $sum += $day.Effort.$role }
            Near $sum $activity.Effort.$role ('Carga diaria diverge do agregado ' + $role)
        }
    }
}
Test-Case 'Default legado ASAP preserva a primeira capacidade disponivel' {
    $data = New-TestData
    $result = Get-HarnessSprintSimulation $data
    $activity = @(Activities $result 'IMPLEMENTAR')[0]
    $daily = @(Daily $result 'IMPLEMENTAR')
    Assert ($daily.Count -eq 2 -and $daily[0].Date -eq '2026-10-05' -and $daily[1].Date -eq '2026-10-06') 'Modo ausente deve manter alocacao ASAP.'
    Assert ($activity.Completed -and $activity.CompletionDate -eq '2026-10-06') 'ASAP deve expor a data real de conclusao.'
}
foreach ($cut in @('ProductionDeadline','MaxTotalSprints')) {
    Test-Case ('Corte por ' + $cut + ' nao comprime janela DISTRIBUTED') {
        $data = New-TestData
        $null = Add-Support $data
        if ($cut -eq 'ProductionDeadline') { $data.Constraints.ProductionDeadline='2026-10-16' } else { $data.Constraints.MaxTotalSprints=1 }
        $result = Get-HarnessSprintSimulation $data
        $daily = @(Daily $result 'SUPORTE')
        Assert ($daily.Count -eq 10) 'Corte deve manter apenas os dez dias uteis visiveis.'
        foreach ($day in $daily) { Near $day.Effort.Architect 0.45 'Horizonte cortado comprimiu a carga da janela completa.' }
        $pending = @($result.Unscheduled | Where-Object Id -CEQ 'SUPORTE')
        Assert ($pending.Count -eq 1) 'Trabalho depois do corte desapareceu.'
        Near $pending[0].RemainingEffort.Architect 4.5 'Restante depois do corte deveria ser 4,5 dias Arq.'
        $activity = @(Activities $result 'SUPORTE')[0]
        Assert (-not $activity.Completed -and $null -eq $activity.CompletionDate) 'Alocacao parcial recebeu conclusao.'
    }
}
Test-Case 'ReferenceDate distribui somente esforco restante nos dias futuros da janela' {
    $data = New-TestData
    $data.Constraints.ReferenceDate='2026-10-19'
    $null = Add-Support $data
    $daily = @(Daily (Get-HarnessSprintSimulation $data) 'SUPORTE')
    Assert ($daily.Count -eq 10 -and $daily[0].Date -eq '2026-10-19') 'Data de referencia nao delimitou os dias restantes.'
    foreach ($day in $daily) { Near $day.Effort.Architect 0.9 'Esforco restante foi dividido por dias ja passados.' }
}
Test-Case 'Feriado reduz os dias da janela distribuida sem alocar carga nele' {
    $data = New-TestData
    $data.Team.Holidays=@('2026-10-12')
    $null = Add-Support $data 9.5
    $daily = @(Daily (Get-HarnessSprintSimulation $data) 'SUPORTE')
    Assert ($daily.Count -eq 19 -and @($daily | Where-Object Date -CEQ '2026-10-12').Count -eq 0) 'Feriado entrou na alocacao diaria.'
    foreach ($day in $daily) { Near $day.Effort.Architect 0.5 'Distribuicao nao considerou os 19 dias uteis.' }
}
Test-Case 'Suporte requerido depois do deploy impede confirmar producao' {
    $data = New-TestData
    $null = Add-Support $data
    ($data.Work | Where-Object Id -CEQ 'DEPLOY').NotBefore='2026-10-29'
    $result = Get-HarnessSprintSimulation $data
    Assert ($null -eq $result.ProductionDate -and $result.Feasibility -eq 'NAO_AVALIAVEL') 'Deploy anterior ao fim do suporte confirmou producao.'
}
Test-Case 'Dependencia explicita de suporte libera deploy no proximo dia util' {
    $data = New-TestData
    $null = Add-Support $data
    $data.Constraints.ProductionDeadline='2026-11-02'
    $deployment = $data.Work | Where-Object Id -CEQ 'DEPLOY'
    $deployment.DependsOn=@('SUPORTE')
    $deployment.NotBefore=$null
    $result = Get-HarnessSprintSimulation $data
    Assert ($result.ProductionDate -eq '2026-11-02') 'Dependencia liberou deploy no mesmo dia da conclusao do suporte.'
    Assert (@(Daily $result 'DEPLOY')[0].Date -eq '2026-11-02') 'Calendario do deploy ignorou o fim de semana apos a dependencia.'
}
Test-Case 'Distribuicao respeita capacidade diaria insuficiente e preserva o restante' {
    $data = New-TestData
    $null = Add-Support $data
    foreach ($staffing in $data.Team.Staffing) { $staffing.ArchitectAvailability=0.2 }
    $result = Get-HarnessSprintSimulation $data
    $daily = @(Daily $result 'SUPORTE')
    Assert ($daily.Count -eq 20 -and $result.Feasibility -eq 'NAO_CABE') 'Capacidade insuficiente nao preservou o trabalho pendente.'
    foreach ($day in $daily) { Near $day.Effort.Architect 0.2 'Suporte ultrapassou a capacidade diaria conhecida.' }
    $pending = @($result.Unscheduled | Where-Object Id -CEQ 'SUPORTE')
    Assert ($pending.Count -eq 1) 'Suporte sem capacidade suficiente desapareceu das pendencias.'
    Near $pending[0].RemainingEffort.Architect 5 'Suporte deveria alocar quatro e manter cinco dias Arq pendentes.'
    foreach ($sprint in $result.Sprints) {
        Near $sprint.Load.Architect $sprint.Capacity.Architect 'Carga agregada deve consumir exatamente a capacidade disponivel do arquiteto, dentro da tolerancia numerica.'
    }
}
Test-Case 'Suporte distribuido aguarda dependencia e reparte o restante da janela' {
    $data = New-TestData
    $support = Add-Support $data
    $support.DependsOn=@('IMPLEMENTAR')
    $result = Get-HarnessSprintSimulation $data
    $daily = @(Daily $result 'SUPORTE')
    Assert ($daily.Count -eq 18 -and $daily[0].Date -eq '2026-10-07' -and $daily[-1].Date -eq '2026-10-30') 'Suporte iniciou antes da dependencia ou saiu da janela.'
    foreach ($day in $daily) { Near $day.Effort.Architect 0.5 'Esforco nao foi repartido pelos 18 dias uteis apos a dependencia.' }
    Assert ($result.Feasibility -eq 'CABE_NAS_PREMISSAS') 'Dependencia conhecida deixou a distribuicao artificialmente pendente.'
}
Test-Case 'Distribuicao nao ignora teto numerico de uma sprint de fase' {
    $data = New-TestData
    $null = Add-Support $data
    $data.Constraints.MaxPreparationSprints=1
    $result = Get-HarnessSprintSimulation $data
    $daily = @(Daily $result 'SUPORTE')
    Assert ($daily.Count -eq 10 -and $daily[-1].Date -eq '2026-10-16' -and $result.PhaseSprintCounts.Preparation -eq 1) 'Suporte distribuido consumiu uma segunda sprint alem do teto.'
    foreach ($day in $daily) { Near $day.Effort.Architect 0.45 'Teto de fase comprimiu o esforco de toda a janela.' }
    $pending = @($result.Unscheduled | Where-Object Id -CEQ 'SUPORTE')
    Assert ($result.Feasibility -eq 'NAO_CABE' -and $pending.Count -eq 1) 'Teto de fase nao apontou o suporte restante.'
    Near $pending[0].RemainingEffort.Architect 4.5 'Teto de fase perdeu os 4,5 dias Arq pendentes.'
}
Test-Case 'Revisao distribui esforco ja restante sem descontar duas vezes o historico' {
    $data = New-TestData
    $support = Add-Support $data
    $previous = Get-HarnessSprintSimulation $data
    $previousJson = $previous | ConvertTo-Json -Depth 50
    $data.Constraints.ReferenceDate='2026-10-19'
    foreach ($scenario in @('Min','Reference','Max')) { $support.Effort.Architect.$scenario=4.5 }
    $result = Get-HarnessSprintSimulation -Data $data -PreviousSimulation $previous
    Assert (($result.Sprints[0] | ConvertTo-Json -Depth 40) -ceq ($previous.Sprints[0] | ConvertTo-Json -Depth 40)) 'Revisao alterou a sprint encerrada.'
    $future = @($result.Sprints[1].Activities | Where-Object Id -CEQ 'SUPORTE')[0]
    Assert ($future.DailyAllocations.Count -eq 10 -and $future.Completed -and $future.CompletionDate -eq '2026-10-30') 'Revisao perdeu o suporte restante.'
    foreach ($day in $future.DailyAllocations) { Near $day.Effort.Architect 0.45 'Historico foi subtraido novamente do esforco restante.' }
    Assert (($previous | ConvertTo-Json -Depth 50) -ceq $previousJson) 'Revisao mutou a simulacao anterior.'
}
Test-Case 'Janela distribuida passada em revisao mantem pendencia sem novas alocacoes' {
    $data = New-TestData
    $support = Add-Support $data
    $previous = Get-HarnessSprintSimulation $data
    $previousJson = $previous | ConvertTo-Json -Depth 50
    $data.Constraints.ReferenceDate='2026-11-02'; $data.Constraints.ProductionDeadline='2026-11-13'
    foreach ($scenario in @('Min','Reference','Max')) { $support.Effort.Architect.$scenario=1 }
    $deployment = $data.Work | Where-Object Id -CEQ 'DEPLOY'
    $deployment.NotBefore='2026-11-02'
    $data.Work=@($support,$deployment)
    $data.Baseline.Accepted=@([pscustomobject]@{Source='C:/fixture/api';Id='I1';Evidence='Aceite humano da fixture';AcceptedBy='Revisor'})
    $result = Get-HarnessSprintSimulation -Data $data -PreviousSimulation $previous
    Assert ($result.Sprints.Count -eq 3 -and @($result.Sprints[2].Activities | Where-Object Id -CEQ 'SUPORTE').Count -eq 0) 'Revisao ressuscitou dias fora da janela passada.'
    $pending = @($result.Unscheduled | Where-Object Id -CEQ 'SUPORTE')
    Assert ($pending.Count -eq 1 -and $result.Feasibility -eq 'NAO_CABE' -and $null -eq $result.ProductionDate) 'Historico concluido foi confundido com o novo esforco restante.'
    Near $pending[0].RemainingEffort.Architect 1 'Janela passada perdeu o dia Arq que continua pendente.'
    Assert (($result.Sprints[0..1] | ConvertTo-Json -Depth 40) -ceq ($previous.Sprints | ConvertTo-Json -Depth 40)) 'Revisao alterou as sprints historicas fechadas.'
    Assert (($previous | ConvertTo-Json -Depth 50) -ceq $previousJson) 'Revisao mutou a simulacao anterior.'
}
Test-Case 'Gantt divide datas alocadas por fim de semana feriado e lacuna' {
    $data = New-TestData
    $work = Work 'CALENDARIO' 5
    $work.Issues=@((Issue)); $data.Work=@($work)
    $result = Get-HarnessSprintSimulation $data
    $days = @('2026-10-09','2026-10-13','2026-10-14','2026-10-16','2026-10-19')
    $first = [pscustomobject]@{Id=$work.Id;Title=$work.Title;Phase=$work.Phase;Completed=$false;CompletionDate=$null;FirstWorkDate=$days[0];LastWorkDate=$days[3];Effort=[pscustomobject]@{Dev=4;Architect=0;DevOps=0};DailyAllocations=@($days[0..3] | ForEach-Object { [pscustomobject]@{Date=$_;Effort=[pscustomobject]@{Dev=1;Architect=0;DevOps=0}} })}
    $last = [pscustomobject]@{Id=$work.Id;Title=$work.Title;Phase=$work.Phase;Completed=$true;CompletionDate=$days[4];FirstWorkDate=$days[4];LastWorkDate=$days[4];Effort=[pscustomobject]@{Dev=1;Architect=0;DevOps=0};DailyAllocations=@([pscustomobject]@{Date=$days[4];Effort=[pscustomobject]@{Dev=1;Architect=0;DevOps=0}})}
    $result.Sprints[0].Activities=@($first); $result.Sprints[1].Activities=@($last)
    $rows = @(Gantt-Rows (Render $data $result) | Where-Object { -not $_.Milestone })
    $intervals = @($rows | ForEach-Object { $_.Start + '/' + $_.End } | Sort-Object)
    Assert (($intervals -join ',') -ceq '2026-10-09/2026-10-10,2026-10-13/2026-10-15,2026-10-16/2026-10-17,2026-10-19/2026-10-20') ('Gantt inventou ocupacao entre dias sem alocacao: ' + ($intervals -join ','))
}
Test-Case 'Gantt parcial termina no ultimo dia alocado sem marco de conclusao' {
    $data = New-TestData
    $work = Work 'PARCIAL' 20
    $work.Issues=@((Issue)); $data.Work=@($work)
    $data.Constraints.ProductionDeadline='2026-10-06'
    $result = Get-HarnessSprintSimulation $data
    $rows = @(Gantt-Rows (Render $data $result))
    Assert (@($rows | Where-Object Milestone).Count -eq 0) 'Trabalho parcial recebeu marco de conclusao.'
    $bars = @($rows | Where-Object { -not $_.Milestone })
    Assert ($bars.Count -eq 1 -and $bars[0].Start -eq '2026-10-05' -and $bars[0].End -eq '2026-10-07') 'Barra parcial usou a borda da sprint em vez dos dias alocados.'
}
Test-Case 'Gantt legado sem DailyAllocations nao inventa barras diarias' {
    $data = New-TestData
    $result = Get-HarnessSprintSimulation $data
    foreach ($activity in @($result.Sprints | ForEach-Object { $_.Activities })) { $activity.PSObject.Properties.Remove('DailyAllocations') }
    $bars = @(Gantt-Rows (Render $data $result) | Where-Object { -not $_.Milestone })
    Assert ($bars.Count -eq 0) 'Historico sem alocacoes diarias ganhou barras inferidas das bordas da sprint.'
}
Test-Case 'Ganho IA declarado reduz somente Dev nas tres faixas sem mutar estimativa fonte' {
    $data = New-AiData 20
    $before = $data | ConvertTo-Json -Depth 40
    $result = Get-HarnessSprintSimulation $data
    Near (Role-Total $result.Scenarios.Min 'IMPLEMENTAR' 'Dev') 4 'Min Dev deveria reduzir de cinco para quatro dias.'
    Near (Role-Total $result 'IMPLEMENTAR' 'Dev') 8 'Reference Dev deveria reduzir de dez para oito dias.'
    Near (Role-Total $result.Scenarios.Max 'IMPLEMENTAR' 'Dev') 12 'Max Dev deveria reduzir de quinze para doze dias.'
    foreach ($scenario in @($result.Scenarios.Min,$result,$result.Scenarios.Max)) {
        Near (Role-Total $scenario 'IMPLEMENTAR' 'Architect') 2 'Ganho IA reduziu esforco do arquiteto.'
        Near (Role-Total $scenario 'IMPLEMENTAR' 'DevOps') 1 'Ganho IA reduziu esforco DevOps.'
    }
    $adjustment = @($result.EffortAdjustments | Where-Object Id -CEQ 'IMPLEMENTAR')[0]
    Assert ($adjustment.ReductionPercent -eq 20 -and $adjustment.OriginalDev.Min -eq 5 -and $adjustment.OriginalDev.Reference -eq 10 -and $adjustment.OriginalDev.Max -eq 15) 'Rastreabilidade perdeu a estimativa Dev original.'
    Assert ($adjustment.EffectiveDev.Min -eq 4 -and $adjustment.EffectiveDev.Reference -eq 8 -and $adjustment.EffectiveDev.Max -eq 12) 'Rastreabilidade diverge do esforco Dev calculado.'
    Assert (($data | ConvertTo-Json -Depth 40) -ceq $before) 'Calculo com IA sobrescreveu a estimativa humana de origem.'
    $again = Get-HarnessSprintSimulation $data
    Near (Role-Total $again 'IMPLEMENTAR' 'Dev') 8 'Segunda chamada aplicou desconto IA repetido.'
    Assert (($again | ConvertTo-Json -Depth 50) -ceq ($result | ConvertTo-Json -Depth 50)) 'Mesma entrada de IA nao produziu resultado deterministico.'
}
foreach ($flag in @('ausente','false')) {
    Test-Case ('Ganho IA nao altera trabalho com AiAssisted ' + $flag) {
        $data = New-AiData 20
        if ($flag -eq 'ausente') { $data.Work[0].PSObject.Properties.Remove('AiAssisted') } else { $data.Work[0].AiAssisted=$false }
        $result = Get-HarnessSprintSimulation $data
        Near (Role-Total $result 'IMPLEMENTAR' 'Dev') 10 'Percentual global descontou atividade sem assistencia IA declarada.'
        Assert ($result.Feasibility -eq 'CABE_NAS_PREMISSAS') 'Trabalho legado conhecido passou a exigir ganho IA.'
    }
}
foreach ($percent in @(0,100)) {
    Test-Case ('Ganho IA aceita limite inclusivo ' + $percent + ' por cento') {
        $result = Get-HarnessSprintSimulation (New-AiData $percent)
        Near (Role-Total $result 'IMPLEMENTAR' 'Dev') (10 * (1 - $percent/100)) 'Limite valido de ganho IA foi aplicado incorretamente.'
        Near (Role-Total $result 'IMPLEMENTAR' 'Architect') 2 'Limite de ganho IA alterou esforco do arquiteto.'
        Assert ($result.Feasibility -eq 'CABE_NAS_PREMISSAS') 'Limite valido de ganho IA foi tratado como lacuna.'
    }
}
foreach ($missing in @('null','ausente')) {
    Test-Case ('Atividade IA com percentual ' + $missing + ' permanece nao avaliavel') {
        $data = New-AiData $null
        if ($missing -eq 'ausente') { $data.PSObject.Properties.Remove('Estimation') }
        $result = Get-HarnessSprintSimulation $data
        Assert ($result.Feasibility -eq 'NAO_AVALIAVEL' -and $null -eq $result.ProductionDate) 'Ganho IA desconhecido foi presumido na avaliacao de producao.'
    }
}
foreach ($percent in @(-1,101,$true,$false)) {
    Test-Case ('Percentual IA rejeita ' + $percent.GetType().Name + ' ' + [string]$percent) {
        $data = New-AiData $percent
        Reject { Get-HarnessSprintSimulation $data } 'Percentual IA invalido foi aceito.'
    }
}
foreach ($flag in @('true','false')) {
    Test-Case ('AiAssisted rejeita string ' + $flag) {
        $data = New-AiData 20
        $data.Work[0].AiAssisted=$flag
        Reject { Get-HarnessSprintSimulation $data } 'String AiAssisted foi interpretada como booleano.'
    }
}
foreach ($percent in @(0,100)) {
    Test-Case ('Dev desconhecido permanece null com ganho IA de ' + $percent + ' por cento') {
        $data = New-AiData $percent
        $data.Work[0].Effort.Dev=[pscustomobject]@{Min=$null;Reference=$null;Max=$null}
        $result = Get-HarnessSprintSimulation $data
        Assert ($result.Feasibility -eq 'NAO_AVALIAVEL' -and $null -eq $result.ProductionDate) 'Ganho IA transformou estimativa ausente em zero conhecido.'
        Assert (@($result.Unscheduled | Where-Object Id -CEQ 'IMPLEMENTAR').Count -eq 1) 'Atividade sem estimativa deixou de constar como pendente.'
        $adjustment = @($result.EffortAdjustments | Where-Object Id -CEQ 'IMPLEMENTAR')[0]
        foreach ($scenario in @('Min','Reference','Max')) {
            Assert ($null -eq $adjustment.OriginalDev.$scenario -and $null -eq $adjustment.EffectiveDev.$scenario) 'Original e efetivo precisam preservar null em todas as faixas.'
        }
    }
}
Test-Case 'IA e DISTRIBUTED combinam desconto Dev com a janela inteira declarada' {
    $data = New-AiData 20
    $work = $data.Work[0]
    $work | Add-Member -NotePropertyName AllocationMode -NotePropertyValue 'DISTRIBUTED'
    $work.NotBefore='2026-10-05'; $work.Deadline='2026-10-30'
    foreach ($scenario in @('Min','Reference','Max')) { $data.Work[1].Effort.DevOps.$scenario=0.5 }
    $result = Get-HarnessSprintSimulation $data
    $daily = @(Daily $result 'IMPLEMENTAR')
    Assert ($daily.Count -eq 20 -and $result.Feasibility -eq 'CABE_NAS_PREMISSAS' -and $result.ProductionDate -eq '2026-10-30') 'Desconto IA concentrou trabalho ou alterou a janela distribuida.'
    foreach ($day in $daily) {
        Near $day.Effort.Dev 0.4 'Dev deveria distribuir oito dias por vinte dias uteis.'
        Near $day.Effort.Architect 0.1 'Arquiteto deveria manter os dois dias de origem.'
        Near $day.Effort.DevOps 0.05 'DevOps deveria manter o dia de origem.'
    }
    $last = @(Activities $result 'IMPLEMENTAR')[-1]
    Assert ($last.Completed -and $last.CompletionDate -eq '2026-10-30') 'IA antecipou indevidamente a conclusao da atividade distribuida.'
}
Test-Case 'Revisao com ganho IA diferente preserva passado e ajusta somente nova estimativa restante' {
    $data = New-AiData 20
    $work = $data.Work[0]
    $work | Add-Member -NotePropertyName AllocationMode -NotePropertyValue 'DISTRIBUTED'
    $work.NotBefore='2026-10-05'; $work.Deadline='2026-10-30'
    foreach ($scenario in @('Min','Reference','Max')) { $work.Effort.Dev.$scenario=20; $data.Work[1].Effort.DevOps.$scenario=0.5 }
    $previous = Get-HarnessSprintSimulation $data
    $previousJson = $previous | ConvertTo-Json -Depth 50
    Near $previous.Sprints[0].Load.Dev 8 'Fixture historica deve conter oito dias Dev ja previstos na primeira sprint.'
    $data.Constraints.ReferenceDate='2026-10-19'
    $data.Estimation.AiDeveloperReductionPercent=50
    foreach ($scenario in @('Min','Reference','Max')) {
        $work.Effort.Dev.$scenario=10; $work.Effort.Architect.$scenario=1; $work.Effort.DevOps.$scenario=0.5
    }
    $inputJson = $data | ConvertTo-Json -Depth 40
    $result = Get-HarnessSprintSimulation -Data $data -PreviousSimulation $previous
    Assert (($result.Sprints[0] | ConvertTo-Json -Depth 40) -ceq ($previous.Sprints[0] | ConvertTo-Json -Depth 40)) 'Novo percentual IA reescreveu a sprint encerrada.'
    Near $result.Sprints[1].Load.Dev 5 'Nova estimativa bruta de dez dias deve gerar cinco dias Dev futuros.'
    $adjustment = @($result.EffortAdjustments | Where-Object Id -CEQ 'IMPLEMENTAR')[0]
    Assert ($adjustment.OriginalDev.Reference -eq 10 -and $adjustment.EffectiveDev.Reference -eq 5 -and $adjustment.ReductionPercent -eq 50) 'Nova revisao perdeu a origem e a hipotese de ganho atual.'
    $again = Get-HarnessSprintSimulation -Data $data -PreviousSimulation $previous
    Near $again.Sprints[1].Load.Dev 5 'Recalculo da revisao reaplicou desconto no esforco efetivo.'
    Assert (($data | ConvertTo-Json -Depth 40) -ceq $inputJson -and ($previous | ConvertTo-Json -Depth 50) -ceq $previousJson) 'Revisao com IA mutou entrada ou historia.'
}
Test-Case 'Cenario Max com IA ainda altera viabilidade quando supera a janela' {
    $data = New-AiData 20
    $data.Constraints.ProductionDeadline='2026-10-16'
    $data.Work[1].NotBefore='2026-10-16'
    foreach ($scenario in @('Min','Reference','Max')) { $data.Work[1].Effort.DevOps.$scenario=0.5 }
    $result = Get-HarnessSprintSimulation $data
    Assert ($result.Feasibility -eq 'EM_RISCO' -and $result.ProductionDate -eq '2026-10-16' -and $result.Scenarios.Max.Feasibility -eq 'NAO_CABE') 'Ganho IA ocultou o risco da faixa superior.'
    $pending = @($result.Scenarios.Max.Unscheduled | Where-Object Id -CEQ 'IMPLEMENTAR')
    Assert ($pending.Count -eq 1) 'Faixa Max acima da capacidade ficou sem pendencia.'
    Near $pending[0].RemainingEffort.Dev 2 'Max efetivo de doze dias deve manter dois dias Dev alem da janela de dez.'
    $data.Estimation.AiDeveloperReductionPercent=50
    $result = Get-HarnessSprintSimulation $data
    Assert ($result.Feasibility -eq 'CABE_NAS_PREMISSAS' -and $result.Scenarios.Max.Feasibility -eq 'CABE_NAS_PREMISSAS') 'Ganho humano revisado nao foi refletido na faixa superior.'
}
Test-Case 'Gantt nao converte conclusao historica em previsao vigente para trabalho restante parcial' {
    $fixture = New-HistoricalCompletionFixture
    $rows = @(Gantt-Rows (Render $fixture.Data $fixture.Result) | Where-Object { $_.Text -match '\bIMPLEMENTAR\b' })
    Assert (@($rows | Where-Object Milestone).Count -eq 0) 'Gantt mostrou conclusao historica como marco da previsao vigente apesar de trabalho nao alocado.'
    $currentBars = @($rows | Where-Object { -not $_.Milestone -and $_.Start -ge '2026-10-19' })
    Assert ($currentBars.Count -gt 0) 'Fixture precisa mostrar trabalho atual alocado parcialmente.'
    foreach ($bar in $currentBars) { Assert ($bar.Text -match '\bparcial\b') 'Barra atual herdou conclusao historica em vez de declarar trabalho parcial.' }
}
Test-Case 'Tabela deixa conclusao prevista N/A quando so o historico concluiu o mesmo Work' {
    $fixture = New-HistoricalCompletionFixture
    $markdown = Render $fixture.Data $fixture.Result
    $row = [regex]::Match($markdown, '(?m)^\|\s*IMPLEMENTAR\s*\|[^\r\n]*')
    Assert $row.Success 'Tabela de prazos nao exibiu a atividade IMPLEMENTAR.'
    $cells = @($row.Value -split '\|')
    Assert ($cells.Count -eq 7 -and $cells[5].Trim() -ceq 'N/A') ('Conclusao prevista da atividade parcial deveria ser N/A: ' + $row.Value)
}

if ($failures.Count) { throw ('SprintEnsaio: ' + $failures.Count + ' falha(s), ' + $passed + ' caso(s) passaram.' + "`n" + ($failures -join "`n")) }
Write-Output ('PASS: SprintEnsaio ' + $passed + ' casos de limites declarados, distribuicao, calendario, Gantt e ganho IA.')
