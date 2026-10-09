#requires -Version 5.1
# Pure simulation: no I/O, clock, input mutation or implicit estimates.
# Roles represent distinct teams. Availability is FTE per architect/DevOps team;
# developer availability is multiplied by Developers. AbsenceDays are remaining
# person-days, distributed evenly over the remaining working days of that sprint.
function Get-HarnessSprintValue {
    param($Object,[string]$Name)
    if ($null -eq $Object) { return $null }
    if ($Object -is [System.Collections.IDictionary]) { return $Object[$Name] }
    $p=$Object.PSObject.Properties[$Name]; if ($null -ne $p) { return $p.Value }
    return $null
}
function ConvertTo-HarnessSprintDate {
    param($Value,[string]$Name)
    if ($null -eq $Value -or [string]::IsNullOrWhiteSpace([string]$Value)) { return $null }
    $date=[datetime]::MinValue
    if (-not [datetime]::TryParseExact([string]$Value,'yyyy-MM-dd',[cultureinfo]::InvariantCulture,[Globalization.DateTimeStyles]::None,[ref]$date)) { throw "${Name}: data invalida; use yyyy-MM-dd." }
    return $date
}
function ConvertTo-HarnessSprintNumber {
    param($Value,[string]$Name,[switch]$Integer,$Maximum=$null,[switch]$Signed)
    if ($null -eq $Value) { return $null }
    $n=[decimal]0
    if ($Value -is [bool] -or -not [decimal]::TryParse([string]$Value,[Globalization.NumberStyles]::Float,[cultureinfo]::InvariantCulture,[ref]$n) -or (-not $Signed -and $n -lt 0) -or ($Integer -and $n -ne [decimal]::Truncate($n)) -or ($null -ne $Maximum -and $n -gt $Maximum)) { throw "${Name}: numero invalido." }
    return $n
}
function Get-HarnessSprintIssueKey {
    param($Issue)
    $source=[string](Get-HarnessSprintValue $Issue 'Source');$id=[string](Get-HarnessSprintValue $Issue 'Id')
    if ([string]::IsNullOrWhiteSpace($source) -or [string]::IsNullOrWhiteSpace($id)) { throw 'Issue exige Source e Id.' }
    return $source.Replace('\','/').TrimEnd('/').ToLowerInvariant()+[char]0+$id
}
function Get-HarnessSprintSimulation {
    [CmdletBinding()]param([AllowNull()]$Data)
    $roles=@('Dev','Architect','DevOps');$diagnostics=New-Object 'System.Collections.Generic.List[string]'
    $schema=Get-HarnessSprintValue $Data 'SchemaVersion';$purpose=Get-HarnessSprintValue $Data 'Purpose'
    if ($null -ne $schema -and $schema -ne 1) { throw 'SchemaVersion deve ser 1.' }
    if ($null -ne $purpose -and $purpose -cne 'sprint-planning') { throw 'Purpose deve ser sprint-planning.' }
    $constraints=Get-HarnessSprintValue $Data 'Constraints';$team=Get-HarnessSprintValue $Data 'Team'
    $start=ConvertTo-HarnessSprintDate (Get-HarnessSprintValue $constraints 'SprintStartDate') 'SprintStartDate'
    $deadline=ConvertTo-HarnessSprintDate (Get-HarnessSprintValue $constraints 'ProductionDeadline') 'ProductionDeadline'
    $reference=ConvertTo-HarnessSprintDate (Get-HarnessSprintValue $constraints 'ReferenceDate') 'ReferenceDate'
    if ($null -ne $start -and $null -ne $deadline -and $deadline -lt $start) { throw 'ProductionDeadline anterior a SprintStartDate.' }
    $limits=@{};foreach ($name in @('MaxPreparationSprints','MaxImplementationSprints','MaxTestSprints','MaxTotalSprints','MaxDevelopers')) { $limits[$name]=ConvertTo-HarnessSprintNumber (Get-HarnessSprintValue $constraints $name) $name -Integer }
    $week=@();foreach ($day in @(Get-HarnessSprintValue $team 'WorkWeek')) { if ($null -eq $day) { continue };$week+=ConvertTo-HarnessSprintNumber $day 'WorkWeek' -Integer -Maximum 6 }
    $holidays=@{};foreach ($day in @(Get-HarnessSprintValue $team 'Holidays')) { if ($null -ne $day) { $d=ConvertTo-HarnessSprintDate $day 'Holiday';if ($null -ne $d) { $holidays[$d.ToString('yyyy-MM-dd')]=$true } } }
    $staff=@{};foreach ($row in @(Get-HarnessSprintValue $team 'Staffing')) {
        if ($null -eq $row) { continue };$number=ConvertTo-HarnessSprintNumber (Get-HarnessSprintValue $row 'Sprint') 'Staffing.Sprint' -Integer
        if ($null -eq $number -or $number -lt 1 -or $staff.ContainsKey([int]$number)) { throw 'Staffing exige Sprint unica maior que zero.' }
        $dev=ConvertTo-HarnessSprintNumber (Get-HarnessSprintValue $row 'Developers') 'Developers' -Integer
        if ($null -ne $dev -and $null -ne $limits.MaxDevelopers -and $dev -gt $limits.MaxDevelopers) { throw 'Developers excede MaxDevelopers.' }
        $availability=@{};$absence=@{}
        foreach ($role in $roles) {
            $field=@{Dev='DeveloperAvailability';Architect='ArchitectAvailability';DevOps='DevOpsAvailability'}[$role]
            $availability[$role]=ConvertTo-HarnessSprintNumber (Get-HarnessSprintValue $row $field) $field -Maximum 1
            $absence[$role]=ConvertTo-HarnessSprintNumber (Get-HarnessSprintValue (Get-HarnessSprintValue $row 'AbsenceDays') $role) "AbsenceDays.$role"
        }
        $staff[[int]$number]=@{Developers=$dev;Availability=$availability;Absence=$absence;Reserve=(ConvertTo-HarnessSprintNumber (Get-HarnessSprintValue $row 'ReservePercent') 'ReservePercent' -Maximum 100)}
    }
    $baseline=Get-HarnessSprintValue $Data 'Baseline';$knownValue=Get-HarnessSprintValue $baseline 'Known'
    if ($null -ne $knownValue -and $knownValue -isnot [bool]) { throw 'Baseline.Known exige booleano.' };$known=$knownValue -eq $true
    $base=New-Object 'System.Collections.Generic.Dictionary[string,object]' ([StringComparer]::Ordinal)
    foreach ($issue in @(Get-HarnessSprintValue $baseline 'Issues')) { if ($null -ne $issue) { $base[(Get-HarnessSprintIssueKey $issue)]=$issue } }
    $changes=Get-HarnessSprintValue $Data 'Changes';$excluded=New-Object 'System.Collections.Generic.Dictionary[string,object]' ([StringComparer]::Ordinal);$reopened=New-Object 'System.Collections.Generic.Dictionary[string,object]' ([StringComparer]::Ordinal);$required=New-Object 'System.Collections.Generic.Dictionary[string,object]' ([StringComparer]::Ordinal)
    foreach ($key in $base.Keys) { $required[$key]=$base[$key] }
    foreach ($issue in @(Get-HarnessSprintValue $changes 'New')) { if ($null -ne $issue) { $required[(Get-HarnessSprintIssueKey $issue)]=$issue } }
    foreach ($issue in @(Get-HarnessSprintValue $changes 'Reopened')) { if ($null -ne $issue) { $key=Get-HarnessSprintIssueKey $issue;$reopened[$key]=$true;$required[$key]=$issue } }
    foreach ($issue in @(Get-HarnessSprintValue $changes 'Excluded')) { if ($null -ne $issue) { $excluded[(Get-HarnessSprintIssueKey $issue)]=$true } }
    $accepted=New-Object 'System.Collections.Generic.Dictionary[string,object]' ([StringComparer]::Ordinal);foreach ($issue in @(Get-HarnessSprintValue $baseline 'Accepted')) {
        if ($null -eq $issue) { continue };$key=Get-HarnessSprintIssueKey $issue
        if ((Get-HarnessSprintValue $issue 'Evidence') -and (Get-HarnessSprintValue $issue 'AcceptedBy') -and -not $excluded.ContainsKey($key) -and -not $reopened.ContainsKey($key)) { $accepted[$key]=$true }
        else { $diagnostics.Add('Aceite sem evidencia/humano ou issue reaberta/excluida nao entra no realizado.') }
    }
    $work=@();$ids=@{};$coverage=New-Object 'System.Collections.Generic.Dictionary[string,object]' ([StringComparer]::Ordinal)
    foreach ($item in @(Get-HarnessSprintValue $Data 'Work')) {
        if ($null -eq $item) { continue };$id=[string](Get-HarnessSprintValue $item 'Id');$phase=[string](Get-HarnessSprintValue $item 'Phase')
        if ([string]::IsNullOrWhiteSpace($id) -or $ids.ContainsKey($id)) { throw 'Work exige Id unico.' }
        if ($phase -notin @('PREPARATION','IMPLEMENTATION','TEST','DEPLOYMENT')) { throw "Work ${id}: Phase invalida." }
        $priority=ConvertTo-HarnessSprintNumber (Get-HarnessSprintValue $item 'Priority') "Work $id Priority" -Signed
        $notBefore=ConvertTo-HarnessSprintDate (Get-HarnessSprintValue $item 'NotBefore') "Work $id NotBefore"
        $workDeadline=ConvertTo-HarnessSprintDate (Get-HarnessSprintValue $item 'Deadline') "Work $id Deadline"
        if ($null -ne $notBefore -and $null -ne $workDeadline -and $workDeadline -lt $notBefore) { throw "Work ${id}: janela invertida." }
        $effort=@{};foreach ($role in $roles) {
            $range=@{};foreach ($scenario in @('Min','Reference','Max')) { $range[$scenario]=ConvertTo-HarnessSprintNumber (Get-HarnessSprintValue (Get-HarnessSprintValue (Get-HarnessSprintValue $item 'Effort') $role) $scenario) "Work $id $role $scenario" }
            if (($null -ne $range.Min -and $null -ne $range.Reference -and $range.Min -gt $range.Reference) -or ($null -ne $range.Reference -and $null -ne $range.Max -and $range.Reference -gt $range.Max) -or ($null -ne $range.Min -and $null -ne $range.Max -and $range.Min -gt $range.Max)) { throw "Work ${id}: faixa de esforco invertida." }
            $effort[$role]=$range
        }
        $keys=@();foreach ($issue in @(Get-HarnessSprintValue $item 'Issues')) { if ($null -ne $issue) { $key=Get-HarnessSprintIssueKey $issue;$keys+=$key;if (-not $coverage.ContainsKey($key)) { $coverage[$key]=@() };$coverage[$key]+=$id } }
        $remainingValue=Get-HarnessSprintValue $item 'Remaining';if ($null -ne $remainingValue -and $remainingValue -isnot [bool]) { throw "Work ${id}: Remaining exige booleano." }
        $entry=@{Id=$id;Title=[string](Get-HarnessSprintValue $item 'Title');Phase=$phase;Priority=$priority;DependsOn=@(Get-HarnessSprintValue $item 'DependsOn' | Where-Object {$null -ne $_});Effort=$effort;NotBefore=$notBefore;Deadline=$workDeadline;Issues=$keys;EstimateSource=(Get-HarnessSprintValue $item 'EstimateSource');Confidence=(Get-HarnessSprintValue $item 'Confidence');Acceptance=(Get-HarnessSprintValue $item 'Acceptance');Remaining=$remainingValue}
        $work+=$entry;$ids[$id]=$entry
    }
    # Kahn validation also covers self references and cycles independent of ordering.
    $visited=@{};while ($visited.Count -lt $work.Count) {
        $progress=$false;foreach ($item in $work) {
            if ($visited.ContainsKey($item.Id)) { continue };$ready=$true
            foreach ($dep in $item.DependsOn) { if (-not $ids.ContainsKey([string]$dep)) { throw "Dependencia inexistente: $dep." };if (-not $visited.ContainsKey([string]$dep)) { $ready=$false } }
            if ($ready) { $visited[$item.Id]=$true;$progress=$true }
        };if (-not $progress) { throw 'Ciclo nas dependencias de Work.' }
    }
    $work=@($work | Sort-Object @{Expression={$_.Priority}},@{Expression={$_.Id}})
    $baselineCount=$null;if ($known) { $baselineCount=$base.Count }
    $actual=0;foreach ($key in $base.Keys) { if ($accepted.ContainsKey($key)) { $actual++ } }
    $gaps=New-Object 'System.Collections.Generic.List[object]'
    foreach ($issue in @(Get-HarnessSprintValue $changes 'Excluded')) { if ($null -ne $issue -and (-not (Get-HarnessSprintValue $issue 'Reason') -or -not (Get-HarnessSprintValue $issue 'Evidence'))) { $gaps.Add([pscustomobject]@{Id=$issue.Id;Source=$issue.Source;Reason='Exclusao exige motivo (Reason) e evidencia (Evidence), preservando B0.'}) } }
    foreach ($key in $required.Keys) { if (-not $accepted.ContainsKey($key) -and -not $excluded.ContainsKey($key) -and -not $coverage.ContainsKey($key)) { $gaps.Add([pscustomobject]@{Id=$required[$key].Id;Source=$required[$key].Source;Reason='Issue pendente sem trabalho/estimativa no escopo.'}) } }
    if (-not $known) { $diagnostics.Add('Baseline desconhecida; denominador e cobertura total nao avaliaveis.') }
    if ($gaps.Count -gt 0) { $diagnostics.Add('Ha issues pendentes sem trabalho/estimativa, inclusive fora das fichas priorizadas.') }
    $diagnostics.Add('Papeis usam equipes distintas. Ausencias sao dias-pessoa restantes; dependencias liberam no dia seguinte. Simulacao gulosa por prioridade/Id, nao prova otimo global.')
    $diagnostics.Add('ActualCount e fotografia dos aceites na ReferenceDate; nao representa uma serie historica de aceites.')
    $cutoff=$deadline
    if ($null -ne $start -and $null -ne $limits.MaxTotalSprints) { $totalEnd=$start.AddDays(14*[double]$limits.MaxTotalSprints-1);if ($null -eq $cutoff -or $totalEnd -lt $cutoff) { $cutoff=$totalEnd } }
    $missingCalendar=($null -eq $start -or $null -eq $reference -or $null -eq $cutoff -or $week.Count -eq 0)
    $sprints=@()
    if (-not $missingCalendar) {
        $number=1;for ($sprintStart=$start;$sprintStart -le $cutoff;$sprintStart=$sprintStart.AddDays(14)) {
            $end=$sprintStart.AddDays(13);$availableStart=$sprintStart;if ($reference -gt $availableStart) { $availableStart=$reference };$availableEnd=$end;if ($cutoff -lt $availableEnd) { $availableEnd=$cutoff }
            $days=@();for ($d=$availableStart;$d -le $availableEnd;$d=$d.AddDays(1)) { if ($week -contains [int]$d.DayOfWeek -and -not $holidays.ContainsKey($d.ToString('yyyy-MM-dd'))) { $days+=$d } }
            $capacity=@{};foreach ($role in $roles) {
                $capacity[$role]=$null
                if ($staff.ContainsKey($number)) {
                    $row=$staff[$number];$people=$row.Availability[$role];if ($role -eq 'Dev') { if ($null -eq $row.Developers -or $null -eq $people) { $people=$null } else { $people=$people*$row.Developers } }
                    if ($null -ne $people -and $null -ne $row.Reserve -and $null -ne $row.Absence[$role]) { $capacity[$role]=[math]::Max(0,($days.Count*$people-$row.Absence[$role]))*(1-$row.Reserve/100) }
                }
            }
            $sprints+=@{Number=$number;Start=$sprintStart;End=$end;Days=$days;Capacity=$capacity;AvailableStart=$availableStart;Cutoff=$availableEnd};$number++
        }
    }
    $model=@{Work=$work;Sprints=$sprints;Roles=$roles;Limits=$limits;Base=$base;Required=$required;Known=$known;BaselineCount=$baselineCount;Actual=$actual;Accepted=$accepted;Excluded=$excluded;Coverage=$coverage;Gaps=@($gaps.ToArray());MissingCalendar=$missingCalendar;Reference=$reference;Start=$start;Cutoff=$cutoff;Diagnostics=@($diagnostics.ToArray())}
    $results=@{};foreach ($scenario in @('Min','Reference','Max')) { $results[$scenario]=Invoke-HarnessSprintScenario -Model $model -Scenario $scenario }
    $result=$results.Reference
    if ($result.Feasibility -eq 'CABE_NAS_PREMISSAS' -and $results.Max.Feasibility -ne 'CABE_NAS_PREMISSAS') { $result.Feasibility='EM_RISCO';$result.Diagnostics+= 'Cenario superior nao confirma a entrega na janela.' }
    $result | Add-Member -NotePropertyName Scenarios -NotePropertyValue ([pscustomobject]@{Min=$results.Min;Reference=[pscustomobject]@{Feasibility=$result.Feasibility;ProductionDate=$result.ProductionDate};Max=$results.Max})
    return $result
}
function Invoke-HarnessSprintScenario {
    param($Model,[string]$Scenario)
    $remaining=@{};$completed=@{};$unknown=@{};$phaseSprints=@{PREPARATION=@{};IMPLEMENTATION=@{};TEST=@{};DEPLOYMENT=@{}}
    $diagnostics=@($Model.Diagnostics);$output=@();$unscheduled=New-Object 'System.Collections.Generic.List[object]';$risk=$false
    foreach ($gap in $Model.Gaps) { $unscheduled.Add($gap) }
    foreach ($item in $Model.Work) {
        $remaining[$item.Id]=@{};foreach ($role in $Model.Roles) { $remaining[$item.Id][$role]=$item.Effort[$role][$Scenario];if ($null -eq $item.Effort[$role][$Scenario]) { $unknown[$item.Id]='Estimativa ausente.' } }
        if ($null -eq $item.Priority) { $unknown[$item.Id]='Prioridade explicita ausente.' }
        if (-not $item.EstimateSource) { $unknown[$item.Id]='Fonte da estimativa ausente.' }
        if (-not $item.Confidence -or -not $item.Acceptance) { $risk=$true;$diagnostics+="Work $($item.Id): confianca ou criterio de aceite nao informado." }
        if ($item.Remaining -eq $false) { $unknown[$item.Id]='Trabalho nao restante exige tratamento explicito no planejamento; aceite de issue nao comprova esta atividade.' }
    }
    foreach ($sprint in $Model.Sprints) {
        $load=@{Dev=[decimal]0;Architect=[decimal]0;DevOps=[decimal]0};$activities=@{}
        foreach ($date in $sprint.Days) {
            $free=@{};foreach ($role in $Model.Roles) { $free[$role]=$null;if ($null -ne $sprint.Capacity[$role]) { $free[$role]=$sprint.Capacity[$role]/$sprint.Days.Count } }
            foreach ($item in $Model.Work) {
                if ($completed.ContainsKey($item.Id) -or $unknown.ContainsKey($item.Id)) { continue }
                if (($null -ne $item.NotBefore -and $date -lt $item.NotBefore) -or ($null -ne $item.Deadline -and $date -gt $item.Deadline)) { continue }
                $ready=$true;foreach ($dep in $item.DependsOn) { if (-not $completed.ContainsKey($dep) -or $completed[$dep] -ge $date) { $ready=$false } };if (-not $ready) { continue }
                $limitField=@{PREPARATION='MaxPreparationSprints';IMPLEMENTATION='MaxImplementationSprints';TEST='MaxTestSprints'}[$item.Phase]
                if ($limitField -and $null -ne $Model.Limits[$limitField] -and -not $phaseSprints[$item.Phase].ContainsKey($sprint.Number) -and $phaseSprints[$item.Phase].Count -ge $Model.Limits[$limitField]) { continue }
                $fraction=[decimal]1;foreach ($role in $Model.Roles) { if ($remaining[$item.Id][$role] -gt 0) { if ($null -eq $free[$role]) { $fraction=0 } else { $fraction=[math]::Min($fraction,$free[$role]/$remaining[$item.Id][$role]) } } }
                if ($fraction -le 0) { continue }
                if (-not $activities.ContainsKey($item.Id)) { $activities[$item.Id]=[pscustomobject]@{Id=$item.Id;Title=$item.Title;Phase=$item.Phase;Completed=$false;Effort=[pscustomobject]@{Dev=[decimal]0;Architect=[decimal]0;DevOps=[decimal]0}} }
                $total=[decimal]0;foreach ($role in $Model.Roles) {
                    $used=$remaining[$item.Id][$role]*$fraction;$remaining[$item.Id][$role]-=$used
                    if ([math]::Abs($remaining[$item.Id][$role]) -lt 0.000000001) { $remaining[$item.Id][$role]=[decimal]0 }
                    if ($null -ne $free[$role]) { $free[$role]-=$used };$load[$role]+=$used;$activities[$item.Id].Effort.$role+=$used;$total+=$remaining[$item.Id][$role]
                    if ($used -gt 0) { $phaseSprints[$item.Phase][$sprint.Number]=$true }
                }
                if ($total -eq 0) { $completed[$item.Id]=$date;$activities[$item.Id].Completed=$true }
            }
        }
        $forecast=0;foreach ($key in $Model.Base.Keys) {
            if ($Model.Excluded.ContainsKey($key)) { continue };$done=$Model.Accepted.ContainsKey($key)
            if (-not $done -and $Model.Coverage.ContainsKey($key)) { $done=$true;foreach ($id in $Model.Coverage[$key]) { if (-not $completed.ContainsKey($id)) { $done=$false } } }
            if ($done) { $forecast++ }
        }
        $forecastPercent=$null;$actualPercent=$null;if ($Model.Known -and $Model.BaselineCount -gt 0) { $forecastPercent=[math]::Round(100*$forecast/$Model.BaselineCount,2);$actualPercent=[math]::Round(100*$Model.Actual/$Model.BaselineCount,2) }
        $output += [pscustomobject]@{Number=$sprint.Number;Start=$sprint.Start.ToString('yyyy-MM-dd');End=$sprint.End.ToString('yyyy-MM-dd');AvailableStart=$sprint.AvailableStart.ToString('yyyy-MM-dd');Cutoff=$sprint.Cutoff.ToString('yyyy-MM-dd');Capacity=[pscustomobject]$sprint.Capacity;Load=[pscustomobject]$load;Activities=@($Model.Work | Where-Object {$activities.ContainsKey($_.Id)} | ForEach-Object {$activities[$_.Id]});ForecastCount=$forecast;ForecastPercent=$forecastPercent;ActualCount=$Model.Actual;ActualPercent=$actualPercent}
    }
    $missing=$Model.MissingCalendar -or -not $Model.Known -or $Model.Gaps.Count -gt 0;$failed=$false
    foreach ($field in @('MaxPreparationSprints','MaxImplementationSprints','MaxTestSprints','MaxDevelopers')) { if ($null -eq $Model.Limits[$field]) { $missing=$true;$diagnostics+="Limite nao informado: $field." } }
    foreach ($item in $Model.Work) {
        if ($completed.ContainsKey($item.Id)) { continue };$reason='Nao alocado dentro da capacidade, precedencias e limites informados.'
        if ($unknown.ContainsKey($item.Id)) { $missing=$true;$reason=$unknown[$item.Id] }
        elseif ($Model.MissingCalendar) { $missing=$true;$reason='Calendario minimo ausente (inicio, referencia, horizonte ou semana util).' }
        else {
            $capacityUnknown=$false;foreach ($sprint in $Model.Sprints) { foreach ($role in $Model.Roles) { if ($remaining[$item.Id][$role] -gt 0 -and $null -eq $sprint.Capacity[$role]) { $capacityUnknown=$true } } }
            if ($capacityUnknown) { $missing=$true;$reason='Capacidade por papel nao informada.' } else { $failed=$true }
        };$unscheduled.Add([pscustomobject]@{Id=$item.Id;Reason=$reason})
    }
    $essentialMissing=$missing
    $deployment=@($Model.Work | Where-Object {$_.Phase -eq 'DEPLOYMENT'});$production=$null
    if ($deployment.Count -eq 0) { $missing=$true;$diagnostics+='Implantacao/janela de producao nao planejada.' }
    elseif ($completed.Count -eq $Model.Work.Count -and -not $missing) {
        $lastDeployment=@($deployment | ForEach-Object {$completed[$_.Id]} | Sort-Object | Select-Object -Last 1)[0]
        $later=@($completed.Values | Where-Object {$_ -gt $lastDeployment})
        if ($later.Count -eq 0) { $production=$lastDeployment.ToString('yyyy-MM-dd') }
        else { $missing=$true;$essentialMissing=$true;$diagnostics+='Implantacao conclui antes de trabalho requerido; corrigir precedencias/janela de producao.' }
    }
    if ($Model.MissingCalendar) { $diagnostics+='Calendario minimo ausente; nenhuma data ou capacidade foi presumida.' }
    $feasibility='CABE_NAS_PREMISSAS';if ($essentialMissing) { $feasibility='NAO_AVALIAVEL' } elseif ($failed) { $feasibility='NAO_CABE' } elseif ($missing) { $feasibility='NAO_AVALIAVEL' }
    if ($feasibility -eq 'CABE_NAS_PREMISSAS' -and $risk) { $feasibility='EM_RISCO' }
    $state='SIMULADO';if ($missing) { $state='RASCUNHO' }
    $horizon=$null;if ($null -ne $Model.Cutoff) { $horizon=$Model.Cutoff.ToString('yyyy-MM-dd') }
    return [pscustomobject]@{Scenario=$Scenario;State=$state;Feasibility=$feasibility;Diagnostics=@($diagnostics);Sprints=@($output);Unscheduled=@($unscheduled.ToArray());ProductionDate=$production;BaselineCount=$Model.BaselineCount;Horizon=$horizon;PhaseSprintCounts=[pscustomobject]@{Preparation=$phaseSprints.PREPARATION.Count;Implementation=$phaseSprints.IMPLEMENTATION.Count;Test=$phaseSprints.TEST.Count;Deployment=$phaseSprints.DEPLOYMENT.Count}}
}
