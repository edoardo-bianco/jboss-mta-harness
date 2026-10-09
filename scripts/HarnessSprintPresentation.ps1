# Editorial text lives outside the calculated markers and is never replaced.
function Get-SprintCalculatedBlock {
    param([string]$Markdown)
    $matches=[regex]::Matches($Markdown,'(?s)<!-- sprints:inicio -->.*?<!-- sprints:fim -->')
    if ($matches.Count -ne 1 -or [regex]::Matches($Markdown,'<!-- sprints:inicio -->').Count -ne 1 -or [regex]::Matches($Markdown,'<!-- sprints:fim -->').Count -ne 1) { throw 'Markdown exige um unico bloco sprints:inicio/fim; preserve a narrativa e restaure os marcadores.' }
    $matches[0].Value
}

function New-SprintDraftMarkdown {
    param($Receipt,[string]$PreviousMarkdown,[string]$Template)
    $block="<!-- sprints:inicio -->`r`n`r`nCalculos pendentes. Execute o prompt e depois Validar e gerar cronograma na mesma Run Task.`r`n`r`n<!-- sprints:fim -->"
    if ($PreviousMarkdown) {
        $old=Get-SprintCalculatedBlock $PreviousMarkdown
        $previous=$PreviousMarkdown.Replace($old,$block)
        return "<!-- Revisao $($Receipt.RevisionId); origem $($Receipt.Previous.RevisionId) -->`r`n$previous"
    }
    $labels=($Receipt.Projects | ForEach-Object Label) -join ', '
    $old=Get-SprintCalculatedBlock $Template
    $Template.Replace($old,$block).Replace('{{PROJECTS}}',$labels).Replace('{{REASON}}',$(if ($Receipt.Reason) {$Receipt.Reason} else {'Primeira proposta; preencher a partir das fontes e das respostas humanas.'}))
}

function Format-SprintCell {
    param($Value)
    if ($null -eq $Value -or [string]::IsNullOrWhiteSpace([string]$Value)) { return 'N/A' }
    ([string]$Value).Replace('|','\|').Replace("`r",' ').Replace("`n",' ')
}

function Format-SprintNumber {
    param($Value)
    if ($null -eq $Value) { return 'N/A' }
    ([decimal]$Value).ToString('0.##',[Globalization.CultureInfo]::InvariantCulture)
}

function Format-SprintLimit {
    param($Constraints,[string]$Field,[string]$Phase)
    if ($Phase -and $Phase -in @(Get-HarnessSprintValue $Constraints 'UnboundedPhases')) { return 'Sem teto adicional' }
    $value=Get-HarnessSprintValue $Constraints $Field
    if ($null -eq $value) { if ($Field -eq 'MaxTotalSprints') { return 'Sem teto total adicional' };return 'Nao informado' }
    Format-SprintNumber $value
}

function Get-SprintCurrentCompletion {
    param($Activities,$Simulation,[string]$Id,[string]$ReferenceDate)
    if (@($Simulation.Unscheduled | Where-Object Id -CEQ $Id).Count) { return }
    $Activities | Where-Object { $_.Completed -and (Get-HarnessSprintValue $_ 'CompletionDate') -and (!$ReferenceDate -or $_.CompletionDate -ge $ReferenceDate) } | Sort-Object CompletionDate | Select-Object -Last 1
}

function Get-SprintGanttLines {
    param($Work,$Simulation,[string]$ReferenceDate)
    $rows=New-Object 'Collections.Generic.List[string]';$legacy=$false;$index=0
    foreach ($item in $Work) {
        $activities=@($Simulation.Sprints | ForEach-Object { $_.Activities } | Where-Object Id -CEQ $item.Id)
        $days=@(foreach ($activity in $activities) {
            if ($null -eq $activity.PSObject.Properties['DailyAllocations']) { $legacy=$true;continue }
            foreach ($allocation in $activity.DailyAllocations) {
                if (@('Dev','Architect','DevOps' | Where-Object { (Get-HarnessSprintValue $allocation.Effort $_) -gt 0 }).Count) { $allocation.Date }
            }
        }) | Sort-Object -Unique
        $title=([regex]::Replace([string]$item.Title,'[^\p{L}\p{N} _-]',' ')).Trim()
        $completion=@(Get-SprintCurrentCompletion $activities $Simulation $item.Id $ReferenceDate)
        $partial=if ($completion.Count) {''} else {' - parcial'}
        $segments=@();$first=$null;$last=$null
        foreach ($value in $days) {
            $day=[DateTime]::ParseExact($value,'yyyy-MM-dd',[cultureinfo]::InvariantCulture)
            if ($null -ne $last -and ($day -ne $last.AddDays(1) -or ($ReferenceDate -and $value -ge $ReferenceDate -and $last.ToString('yyyy-MM-dd') -lt $ReferenceDate))) { $segments+=@{Start=$first;End=$last.AddDays(1)};$first=$null }
            if ($null -eq $first) { $first=$day };$last=$day
        }
        if ($null -ne $first) { $segments+=@{Start=$first;End=$last.AddDays(1)} }
        foreach ($segment in $segments) {
            $label=if ($ReferenceDate -and $segment.Start.ToString('yyyy-MM-dd') -lt $ReferenceDate) {' - historico'} else {$partial}
            $rows.Add(('    {0}{1} :a{2}, {3}, {4}' -f $title,$label,$index,$segment.Start.ToString('yyyy-MM-dd'),$segment.End.ToString('yyyy-MM-dd')));$index++
        }
        if ($completion.Count) { $rows.Add(('    Conclusao prevista - {0} :milestone, a{1}, {2}, 0d' -f $title,$index,$completion[0].CompletionDate));$index++ }
    }
    if ($rows.Count) {
        '```mermaid';'gantt';'    title Dias alocados - previsao de referencia';'    dateFormat YYYY-MM-DD';'    axisFormat %d/%m'
        $rows.ToArray();'```'
        'Cada trecho mostra apenas dias com esforco alocado. Fins de semana, feriados e lacunas ficam sem barra; o limite direito e exclusivo. Marcos indicam conclusao prevista vigente, nunca aceite realizado. Trechos historicos preservam a previsao anterior, sem concluir trabalho reaberto.'
    } else { 'Sem alocacoes diarias para desenhar o Gantt.' }
    if ($legacy) { 'Historico legado sem alocacoes diarias: consulte a matriz por sprint. Nao foram inventadas datas exatas para essas atividades.' }
}

function ConvertTo-SprintMarkdown {
    param($Receipt,$Data,[string]$Markdown)
    $old=Get-SprintCalculatedBlock $Markdown
    $simulation=$Data.Simulation
    $lines=New-Object 'Collections.Generic.List[string]'
    $lines.Add('<!-- sprints:inicio -->')
    $lines.Add('')
    $lines.Add(('**Revisao:** {0} | **Estado:** {1} | **Viabilidade:** {2}' -f $Receipt.RevisionId,$Data.State,$simulation.Feasibility))
    $lines.Add(('Data de referencia: {0}. Sprints de 14 dias corridos; carga em dias-pessoa por papel.' -f (Format-SprintCell $Data.Constraints.ReferenceDate)))
    $lines.Add('')
    $lines.Add('| Restricao | Valor |')
    $lines.Add('| --- | --- |')
    foreach ($pair in @(@('Inicio das sprints','SprintStartDate',''),@('Prazo de producao','ProductionDeadline',''),@('Sprints de preparacao','MaxPreparationSprints','PREPARATION'),@('Sprints de implementacao','MaxImplementationSprints','IMPLEMENTATION'),@('Sprints de testes','MaxTestSprints','TEST'),@('Total de sprints','MaxTotalSprints',''),@('Teto de desenvolvedores','MaxDevelopers',''))) {
        $value=if ($pair[1] -like 'Max*') { Format-SprintLimit $Data.Constraints $pair[1] $pair[2] } else { Format-SprintCell $Data.Constraints.($pair[1]) }
        $lines.Add(('| {0} | {1} |' -f $pair[0],$value))
    }
    $lines.Add(('| Base B0 / categorias | {0} / {1} |' -f (Format-SprintNumber $simulation.BaselineCount),($Data.ScopeCategories -join ', ')))
    $lines.Add(('| Producao prevista | {0} |' -f (Format-SprintCell $simulation.ProductionDate)))
    $lines.Add('')
    $lines.Add('### Conferencia deterministica dos prazos e limites')
    $lines.Add('')
    $lines.Add(('- Prazo de producao informado: {0}; horizonte efetivo: {1}; producao calculada: {2}.' -f (Format-SprintCell $Data.Constraints.ProductionDeadline),(Format-SprintCell $simulation.Horizon),(Format-SprintCell $simulation.ProductionDate)))
    $lines.Add('| Fase | Maximo informado | Sprints com esforco, incluindo historico |')
    $lines.Add('| --- | --- | --- |')
    foreach ($pair in @(@('Preparation','MaxPreparationSprints'),@('Implementation','MaxImplementationSprints'),@('Test','MaxTestSprints'))) {
        $lines.Add(('| {0} | {1} | {2} |' -f $pair[0],(Format-SprintLimit $Data.Constraints $pair[1] $pair[0].ToUpperInvariant()),(Format-SprintNumber $simulation.PhaseSprintCounts.($pair[0]))))
    }
    $lines.Add('Atividades nao alocadas e limites esgotados estao justificados abaixo. Respeitar o teto no trabalho alocado nao comprova que todo o trabalho cabe. Sem producao calculada, o atendimento ao prazo nao foi demonstrado.')
    $lines.Add('')
    $lines.Add('| Atividade | Inicio permitido | Prazo humano | Ultimo dia alocado | Conclusao prevista |')
    $lines.Add('| --- | --- | --- | --- | --- |')
    foreach ($work in $Data.Work) {
        $allocations=@($simulation.Sprints | ForEach-Object { $_.Activities } | Where-Object Id -CEQ $work.Id)
        $last=@($allocations | ForEach-Object { Get-HarnessSprintValue $_ 'LastWorkDate' } | Sort-Object | Select-Object -Last 1)
        $done=@(Get-SprintCurrentCompletion $allocations $simulation $work.Id $Data.Constraints.ReferenceDate | ForEach-Object CompletionDate)
        $lines.Add(('| {0} | {1} | {2} | {3} | {4} |' -f (Format-SprintCell $work.Id),(Format-SprintCell $work.NotBefore),(Format-SprintCell $work.Deadline),(Format-SprintCell ($last -join '')),(Format-SprintCell ($done -join ''))))
    }
    $adjustments=@(Get-HarnessSprintValue $simulation 'EffortAdjustments' | Where-Object { $null -ne $_ })
    if ($adjustments.Count) {
        $lines.Add('')
        $lines.Add('### Hipotese de ganho com IA')
        $lines.Add('')
        $lines.Add('Reducao aplicada uma vez ao esforco restante de Dev nas atividades selecionadas. Faixas Min / Referencia / Max em dias-pessoa; capacidades e esforcos de Arq/DevOps permanecem iguais. Ganho proposto, nao economia realizada.')
        $lines.Add('')
        $lines.Add('| Atividade | Reducao informada | Dev original | Dev usado no calculo | Reducao em dias-pessoa |')
        $lines.Add('| --- | --- | --- | --- | --- |')
        foreach ($adjustment in $adjustments) {
            $original=@();$effective=@();$reduction=@()
            foreach ($range in @('Min','Reference','Max')) {
                $original+=Format-SprintNumber $adjustment.OriginalDev.$range
                $effective+=Format-SprintNumber $adjustment.EffectiveDev.$range
                $delta=$null;if ($null -ne $adjustment.OriginalDev.$range -and $null -ne $adjustment.EffectiveDev.$range) { $delta=$adjustment.OriginalDev.$range-$adjustment.EffectiveDev.$range }
                $reduction+=Format-SprintNumber $delta
            }
            $lines.Add(('| {0} | {1}% | {2} | {3} | {4} |' -f (Format-SprintCell $adjustment.Id),(Format-SprintNumber $adjustment.ReductionPercent),($original -join ' / '),($effective -join ' / '),($reduction -join ' / ')))
        }
    }
    $lines.Add('')
    $lines.Add('### Composicao e movimentos do escopo')
    $lines.Add('')
    $lines.Add(('B0 preservada: {0}; escopo atual conhecido (B0 + novas - excluidas): {1}. Reabertura nao aumenta o denominador.' -f (Format-SprintNumber $simulation.BaselineCount),(Format-SprintNumber $simulation.CurrentScopeCount)))
    $lines.Add('| Movimento | Source / ID | Motivo | Evidencia |')
    $lines.Add('| --- | --- | --- | --- |')
    foreach ($kind in @('New','Reopened','Excluded')) {
        foreach ($issue in $Data.Changes.$kind) {
            $lines.Add(('| {0} | {1} / {2} | {3} | {4} |' -f $kind,(Format-SprintCell $issue.Source),(Format-SprintCell $issue.Id),(Format-SprintCell (Get-HarnessSprintValue $issue 'Reason')),(Format-SprintCell (Get-HarnessSprintValue $issue 'Evidence'))))
        }
    }
    $lines.Add('')
    $lines.Add('### Sprints, metas e capacidade')
    $lines.Add('')
    $lines.Add('| Sprint / periodo | Entregas previstas | Previsto acumulado B0 | Realizado comprovado B0 | Dev carga/cap. | Arq carga/cap. | Ops carga/cap. |')
    $lines.Add('| --- | --- | --- | --- | --- | --- | --- |')
    foreach ($sprint in $simulation.Sprints) {
        $titles=(@($sprint.Activities | ForEach-Object { $_.Title + $(if ($_.Completed) {' (conclusao)'} else {' (parcial)'}) }) -join '; ')
        $lines.Add(('| S{0} / {1} a {2} | {3} | {4} / {5}% | {6} / {7}% | {8}/{9} | {10}/{11} | {12}/{13} |' -f $sprint.Number,(Format-SprintCell $sprint.Start),(Format-SprintCell $sprint.End),(Format-SprintCell $titles),(Format-SprintNumber $sprint.ForecastCount),(Format-SprintNumber $sprint.ForecastPercent),(Format-SprintNumber $sprint.ActualCount),(Format-SprintNumber $sprint.ActualPercent),(Format-SprintNumber $sprint.Load.Dev),(Format-SprintNumber $sprint.Capacity.Dev),(Format-SprintNumber $sprint.Load.Architect),(Format-SprintNumber $sprint.Capacity.Architect),(Format-SprintNumber $sprint.Load.DevOps),(Format-SprintNumber $sprint.Capacity.DevOps)))
    }
    $lines.Add('')
    $lines.Add('Previsto e realizado sao distintos; conclusao parcial nao aumenta o percentual de issues resolvidas. N/A nao significa zero. As capacidades consideram apenas os dias restantes dentro do horizonte.')
    $lines.Add('')
    $lines.Add('### Linha do tempo (matriz)')
    $lines.Add('')
    $columns=@($simulation.Sprints | ForEach-Object { 'S'+$_.Number })
    $lines.Add(('| Macroatividade | '+($columns -join ' | ')+' |'))
    $lines.Add(('| --- | '+(@($columns | ForEach-Object {'---'}) -join ' | ')+' |'))
    foreach ($work in $Data.Work) {
        $cells=@(foreach ($sprint in $simulation.Sprints) {
            $activities=@($sprint.Activities | Where-Object Id -CEQ $work.Id)
            if ($activities.Count) { if (@($activities | Where-Object Completed).Count) {'Concluir'} else {'Trabalhar'} } else {'-'}
        })
        $lines.Add(('| '+(Format-SprintCell $work.Title)+' | '+($cells -join ' | ')+' |'))
    }
    if ($Data.Constraints.SprintStartDate -and @($simulation.Sprints).Count) {
        $lines.Add('')
        foreach ($line in @(Get-SprintGanttLines $Data.Work $simulation $Data.Constraints.ReferenceDate)) { $lines.Add($line) }
    }
    $lines.Add('')
    $lines.Add('### Fora do horizonte / a estimar')
    $lines.Add('')
    $lines.Add('As atividades abaixo continuam no escopo: falta alocar parte ou todo o esforco. Somente Changes.Excluded registra exclusao; uma atividade parcial nao conclui suas issues.')
    $lines.Add('')
    $lines.Add('| Atividade / issue | Motivo |')
    $lines.Add('| --- | --- |')
    foreach ($item in $simulation.Unscheduled) { $lines.Add(('| {0} | {1} |' -f (Format-SprintCell $item.Id),(Format-SprintCell $item.Reason))) }
    if ($simulation.Feasibility -eq 'EM_RISCO' -and $simulation.Scenarios.Max.Feasibility -ne 'CABE_NAS_PREMISSAS') {
        $lines.Add('')
        $lines.Add('### Sensibilidade ao esforco superior (Max)')
        $lines.Add('')
        $lines.Add(('A referencia cabe; a faixa superior resulta em {0}. Motivos calculados:' -f $simulation.Scenarios.Max.Feasibility))
        $lines.Add('| Atividade / issue | Motivo na faixa superior |')
        $lines.Add('| --- | --- |')
        foreach ($item in $simulation.Scenarios.Max.Unscheduled) { $lines.Add(('| {0} | {1} |' -f (Format-SprintCell $item.Id),(Format-SprintCell $item.Reason))) }
        foreach ($item in $simulation.Scenarios.Max.Diagnostics | Where-Object { $_ -notin $simulation.Diagnostics }) { $lines.Add('- '+(Format-SprintCell $item)) }
    }
    $lines.Add('')
    $lines.Add('### Lacunas e verificacoes')
    $lines.Add('')
    foreach ($item in $simulation.Diagnostics) { $lines.Add('- '+(Format-SprintCell $item)) }
    foreach ($project in $Receipt.Projects) {
        foreach ($item in $project.Diagnostics) { $lines.Add('- '+(Format-SprintCell ($project.Label+': '+$item))) }
        $missing=@($project.Issues | Where-Object { $_.Category -in $Data.ScopeCategories -and @($_.FichaPaths).Count -eq 0 })
        if ($missing.Count) { $lines.Add('- '+(Format-SprintCell ($project.Label+': '+$missing.Count+' issues sem ficha; confira contexto.json.'))) }
    }
    $lines.Add('')
    $lines.Add('### Documentos de referencia')
    $lines.Add('')
    foreach ($reference in $Receipt.References | Where-Object { $_.Kind -in @('Indice','Registro','Contrato','Ranking candidato','Plano candidato') }) {
        $path=$reference.Path.Replace('\','/')
        $lines.Add(('- [{0}](<{1}>) - {2}' -f (Format-SprintCell $reference.Kind),$path,$reference.Status))
    }
    $lines.Add(('- [Dados desta revisao](<{0}>) e [contexto com fichas, anexos e hashes](<{1}>).' -f $Receipt.SprintDataPath.Replace('\','/'),$Receipt.ContextPath.Replace('\','/')))
    if ($Receipt.Previous) { $lines.Add(('- [Revisao anterior](<{0}>).' -f $Receipt.Previous.SprintPlanPath.Replace('\','/'))) }
    $lines.Add('')
    $lines.Add('Validacao aritmetica nao concede GO, aceite humano ou aprovacao do Quality Gate corporativo.')
    $lines.Add('<!-- sprints:fim -->')
    $Markdown.Replace($old,($lines -join "`r`n"))
}
