# Editorial text lives outside the calculated markers and is never replaced.
function Get-SprintCalculatedBlock {
    param([string]$Markdown)
    $matches=[regex]::Matches($Markdown,'(?s)<!-- sprints:inicio -->.*?<!-- sprints:fim -->')
    if ($matches.Count -ne 1 -or [regex]::Matches($Markdown,'<!-- sprints:inicio -->').Count -ne 1 -or [regex]::Matches($Markdown,'<!-- sprints:fim -->').Count -ne 1) { throw 'Markdown exige um unico bloco sprints:inicio/fim; preserve a narrativa e restaure os marcadores.' }
    $matches[0].Value
}

function New-SprintDraftMarkdown {
    param($Receipt,[string]$PreviousMarkdown)
    $block="<!-- sprints:inicio -->`r`n`r`nCalculos pendentes. Execute o prompt e depois Validar e gerar cronograma na mesma Run Task.`r`n`r`n<!-- sprints:fim -->"
    if ($PreviousMarkdown) {
        $old=Get-SprintCalculatedBlock $PreviousMarkdown
        $previous=$PreviousMarkdown.Replace($old,$block)
        return "<!-- Revisao $($Receipt.RevisionId); origem $($Receipt.Previous.RevisionId) -->`r`n$previous"
    }
    $labels=($Receipt.Projects | ForEach-Object Label) -join ', '
    @"
# Planejamento da migracao - $labels

## Escopo e resultado esperado

Rascunho preparado. O prompt coleta datas/equipe, confirma opcionais e preenche
estimativas com fontes. Categorias iniciais: mandatory. Nenhum GO ou aceite.

## Cronograma calculado

$block

## Objetivo da HU por sprint

A detalhar pelo executor: objetivo, beneficio, aceite resumido e referencias
para cada sprint, conforme o template. Conferir as datas apos calcular.

## Impedimentos e decisoes

Registrar premissas, decisoes humanas e a resolucao das lacunas das fontes.

## Mudancas desta revisao

$(if ($Receipt.Reason) {$Receipt.Reason} else {'Primeira preparacao; estimativas ainda nao elaboradas.'})
"@
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
    foreach ($name in @('SprintStartDate','ProductionDeadline','MaxPreparationSprints','MaxImplementationSprints','MaxTestSprints','MaxTotalSprints','MaxDevelopers')) { $lines.Add(('| {0} | {1} |' -f $name,(Format-SprintCell $Data.Constraints.$name))) }
    $lines.Add(('| Base B0 / categorias | {0} / {1} |' -f (Format-SprintNumber $simulation.BaselineCount),($Data.ScopeCategories -join ', ')))
    $lines.Add(('| Producao prevista | {0} |' -f (Format-SprintCell $simulation.ProductionDate)))
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
        $lines.Add('```mermaid')
        $lines.Add('gantt')
        $lines.Add('    title Previsao por sprint - conferir matriz e lacunas')
        $lines.Add('    dateFormat YYYY-MM-DD')
        $i=0
        foreach ($work in $Data.Work) {
            $allocated=@($simulation.Sprints | Where-Object { @($_.Activities | Where-Object Id -CEQ $work.Id).Count })
            if (-not $allocated.Count) { continue }
            $title=([regex]::Replace([string]$work.Title,'[^\p{L}\p{N} _-]',' ')).Trim()
            $end=([DateTime]::ParseExact($allocated[-1].End,'yyyy-MM-dd',[Globalization.CultureInfo]::InvariantCulture)).AddDays(1).ToString('yyyy-MM-dd')
            $lines.Add(('    {0} :a{1}, {2}, {3}' -f $title,$i,$allocated[0].Start,$end))
            $i++
        }
        $lines.Add('```')
        $lines.Add('Barras mostram as sprints com trabalho, nao uma promessa de ocupacao continua. O termino da sprint permanece 14 dias mesmo quando o prazo corta sua capacidade.')
    }
    $lines.Add('')
    $lines.Add('### Fora do horizonte / a estimar')
    $lines.Add('')
    $lines.Add('| Atividade / issue | Motivo |')
    $lines.Add('| --- | --- |')
    foreach ($item in $simulation.Unscheduled) { $lines.Add(('| {0} | {1} |' -f (Format-SprintCell $item.Id),(Format-SprintCell $item.Reason))) }
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
