function Get-SprintBaseline {
    param($Projects,$Categories)
    foreach ($project in $Projects) { foreach ($issue in $project.Issues | Where-Object Category -In $Categories) {
        [pscustomobject]@{Project=$project.Project;Source=$project.Source;Id=$issue.Id}
    } }
}

function Set-SprintIssueSources {
    param($Data,$Projects,$EarlierProjects=@())
    $issues=@($Data.Baseline.Issues)+@($Data.Baseline.Accepted)+@($Data.Changes.New)+@($Data.Changes.Reopened)+@($Data.Changes.Excluded)
    foreach ($work in $Data.Work) { $issues+=@($work.Issues) }
    foreach ($issue in $issues) {
        $name=Get-SprintInputValue $issue 'Project'
        if (-not $name) {
            $matches=@(@($Projects)+@($EarlierProjects) | Where-Object Source -IEQ $issue.Source | Select-Object -ExpandProperty Project -Unique)
            if ($matches.Count -ne 1) { throw 'Issue sem projeto funcional reconhecido; confira Project/Source/Id.' }
            $name=$matches[0]
            $issue | Add-Member -NotePropertyName Project -NotePropertyValue $name
        }
        $project=@($Projects | Where-Object Project -CEQ $name)
        if ($project.Count -eq 1) { $issue.Source=$project[0].Source }
    }
}

function Get-SprintIssueSet {
    param($Issues,[string]$Name)
    $set=[Collections.Generic.Dictionary[string,object]]::new([StringComparer]::Ordinal)
    foreach ($issue in @($Issues)) {
        if ($null -eq $issue) { continue }
        $key=Get-HarnessSprintIssueKey $issue
        if ($set.ContainsKey($key)) { throw "$Name contem Source/ID duplicado." }
        $set[$key]=$issue
    }
    return ,$set
}

function Assert-SprintDataScope {
    param($Data,$Receipt,$Previous)
    if ($Data.SchemaVersion -ne 1 -or $Data.Purpose -cne 'current-sprint-planning' -or $Data.Scenario -cne $Receipt.Scenario) { throw 'Identidade dos dados diverge do contexto.' }
    if ($Data.State -notin @('RASCUNHO','PROPOSTA','REVISADO')) { throw 'Estado editorial invalido.' }
    $categories=@($Data.ScopeCategories)
    if ('mandatory' -notin $categories -or @($categories | Where-Object { $_ -notin @('mandatory','optional') }).Count -or @($categories | Sort-Object -Unique).Count -ne $categories.Count) { throw 'Escopo exige mandatory e permite optional somente por decisao explicita.' }
    if ('optional' -in $categories -and -not $Data.ScopeDecision) { throw 'Incluir opcionais exige registrar a decisao humana em ScopeDecision.' }
    foreach ($pair in @(@($Data.Team,'RolesAreDistinct'),@($Data.EvidenceReview,'Reviewed'),@($Data.Baseline,'Known'))) {
        $value=Get-SprintInputValue $pair[0] $pair[1]
        if ($null -ne $value -and $value -isnot [bool]) { throw "$($pair[1]) exige booleano real ou null." }
    }
    $known=[Collections.Generic.Dictionary[string,object]]::new([StringComparer]::Ordinal)
    $expected=[Collections.Generic.Dictionary[string,object]]::new([StringComparer]::Ordinal)
    $selectedSources=@{}
    foreach ($project in $Receipt.Projects) { foreach ($issue in $project.Issues) {
        $key=Get-HarnessSprintIssueKey ([pscustomobject]@{Source=$project.Source;Id=$issue.Id})
        $known[$key]=$true
        if ($issue.Category -in $categories) { $expected[$key]=$true }
    } }
    foreach ($project in $Receipt.Projects) { $selectedSources[$project.Source.Replace('\','/').TrimEnd('/').ToLowerInvariant()]=$true }
    $first=(-not $Previous -or -not $Previous.Baseline.Known)
    if (-not $first) {
        $fixed=Get-SprintIssueSet $Previous.Baseline.Issues 'B0 calculada'
        $edited=Get-SprintIssueSet $Data.Baseline.Issues 'B0 editada'
        if ($fixed.Count -ne $edited.Count -or @($fixed.Keys | Where-Object { -not $edited.ContainsKey($_) }).Count -or $Data.Baseline.Id -cne $Previous.Baseline.Id -or $Data.Baseline.Known -ne $Previous.Baseline.Known) { throw 'B0 validada e fixa. Registre inclusoes/reaberturas/exclusoes em Changes.' }
    }
    $actual=Get-SprintIssueSet $Data.Baseline.Issues 'Baseline.Issues'
    if ($first) {
        if ($actual.Count -ne $expected.Count -or @($expected.Keys | Where-Object { -not $actual.ContainsKey($_) }).Count) { throw 'B0 deve conter exatamente as issues das categorias selecionadas do contexto; aceite comprovado entra em Accepted.' }
        $isKnown=@($Receipt.Projects | Where-Object { -not $_.RegisterValid }).Count -eq 0
        if ($Data.Baseline.Known -ne $isKnown) { throw 'Denominador conhecido diverge das lacunas dos registros.' }
    }
    $historicalNew=Get-SprintIssueSet @(Get-SprintInputValue $Previous 'NewIssues' @()) 'Inclusoes acumuladas'
    $new=Get-SprintIssueSet $Data.Changes.New 'Changes.New'
    if (@($historicalNew.Keys | Where-Object { -not $new.ContainsKey($_) }).Count) { throw 'Inclusao historica validada deve permanecer em Changes.New; registre exclusao explicita com motivo/evidencia.' }
    foreach ($key in $new.Keys) {
        if ($actual.ContainsKey($key)) { throw 'Changes.New nao pode repetir uma issue de B0.' }
        if (-not $expected.ContainsKey($key) -and -not $historicalNew.ContainsKey($key)) { throw 'Issue nova deve pertencer as categorias selecionadas do contexto ou a inclusao historica validada.' }
        $actual[$key]=$new[$key]
    }
    if (@($expected.Keys | Where-Object { -not $actual.ContainsKey($_) }).Count) { throw 'Issues atuais do recorte faltam na B0/Changes.New. Inclua todas, mesmo ainda a estimar.' }
    $excluded=Get-SprintIssueSet $Data.Changes.Excluded 'Changes.Excluded'
    $reopened=Get-SprintIssueSet $Data.Changes.Reopened 'Changes.Reopened'
    $accepted=Get-SprintIssueSet $Data.Baseline.Accepted 'Baseline.Accepted'
    foreach ($set in @($excluded,$reopened,$accepted)) {
        foreach ($key in $set.Keys) { if (-not $actual.ContainsKey($key)) { throw 'Changes/Accepted deve referenciar Source/ID de B0 ou Changes.New.' } }
    }
    foreach ($key in $reopened.Keys) { if ($excluded.ContainsKey($key)) { throw 'Issue nao pode estar simultaneamente reaberta e excluida.' } }
    foreach ($key in $actual.Keys) {
        $source=([string]$actual[$key].Source).Replace('\','/').TrimEnd('/').ToLowerInvariant()
        if ((-not $selectedSources.ContainsKey($source) -or ($known.ContainsKey($key) -and -not $expected.ContainsKey($key))) -and -not $excluded.ContainsKey($key)) { throw 'Issue historica fora dos projetos/categorias selecionados exige exclusao explicita, preservando B0.' }
    }
    foreach ($work in $Data.Work) {
        $workIssues=Get-SprintIssueSet $work.Issues "Work $($work.Id).Issues"
        foreach ($key in $workIssues.Keys) {
            if (-not $actual.ContainsKey($key)) { throw 'Work.Issues deve referenciar Source/ID de B0 ou Changes.New.' }
            if ($excluded.ContainsKey($key)) { throw 'Work nao pode alocar issue excluida; concilie a atividade com a decisao de escopo.' }
        }
    }
}


function Complete-HarnessSprintPlan {
    [CmdletBinding()]
    param([string]$Root,[string]$ContextPath)
    $scenarioLease=Enter-SprintAccess $Root
    try {
    $master=Get-SprintMaster $Root $ContextPath
    $lease=Enter-HarnessProjectAccess $master -ForOperation
    try {
        $current=Read-HarnessSprintContext $Root $ContextPath
        if (@(Get-HarnessSprintScenarios $Root | Where-Object Scenario -CEQ $current.Scenario).Count -ne 1) { throw 'Cenario com mais de um mestre; concilie antes de validar.' }
        $paths=Get-SprintPaths $master $current.Scenario; $rel=$paths.Relative
        $files=Read-HarnessProjectFiles $master @('contexto.json','planejamento-sprints.json','plano.md','resultado.json' | ForEach-Object { $rel+'/'+$_ })
        if (-not $files[$rel+'/planejamento-sprints.json'] -or -not $files[$rel+'/plano.md']) { throw 'Dados/plano correntes ausentes.' }
        $data=ConvertFrom-Json $files[$rel+'/planejamento-sprints.json']
        $previous=if ($files[$rel+'/resultado.json']) { ConvertFrom-Json $files[$rel+'/resultado.json'] } else {$null}
        if ($previous -and ($previous.Purpose -cne 'current-sprint-result' -or $previous.Scenario -cne $current.Scenario)) { throw 'Resultado corrente de outro cenario/formato.' }
        $selected=@($current.Projects | ForEach-Object { [pscustomobject]@{path=$_.Source} })
        $inputs=Get-HarnessSprintSources ([pscustomobject]@{Root=$Root}) $selected
        if ((@($inputs.Projects.Project | Sort-Object) -join '|') -cne (@($current.Projects.Project | Sort-Object) -join '|')) { throw 'Participantes divergem do POM; atualize o contexto.' }
        Set-SprintIssueSources $data $inputs.Projects
        if ($previous) {
            foreach ($issue in @($previous.Baseline.Issues)+@($previous.NewIssues)) {
                $participant=@($inputs.Projects | Where-Object Project -CEQ $issue.Project)
                if ($participant.Count -eq 1) { $issue.Source=$participant[0].Source }
            }
            if ($previous.SprintStartDate -and $data.Constraints.SprintStartDate -ne $previous.SprintStartDate) { throw 'Inicio das sprints ja publicadas e fixo; para outro calendario crie um cenario separado.' }
            if ($previous.ReferenceDate -and (-not $data.Constraints.ReferenceDate -or $data.Constraints.ReferenceDate -lt $previous.ReferenceDate)) { throw 'Data de referencia nao pode retroceder nem ser removida.' }
        }
        $view=[pscustomobject]@{Scenario=$current.Scenario;Projects=$inputs.Projects;References=$inputs.References;SprintDataPath=$current.SprintDataPath;SprintPlanPath=$current.SprintPlanPath}
        Assert-SprintDataScope $data $view $previous
        $null=Get-SprintCalculatedBlock $files[$rel+'/plano.md']
        $evidence=@(foreach ($work in $data.Work) { foreach ($path in $work.References) {
            if ($path -isnot [string]) { throw 'Work.References exige caminhos/URLs como strings.' }
            Get-SprintReference $path $Root 'Estimativa'
        } }) | Sort-Object Path -Unique
        if ($data.PSObject.Properties['Simulation']) { throw 'Simulation fica somente no resultado calculado, fora das premissas editaveis.' }
        $simulation=Get-HarnessSprintSimulation -Data $data -PreviousSimulation (Get-SprintInputValue $previous 'Simulation')
        $diagnostics=@()
        if ($data.Team.RolesAreDistinct -ne $true) { $diagnostics+='Confirme pessoas distintas por papel (Team.RolesAreDistinct); acumulo exige redistribuir disponibilidade sem dupla contagem.' }
        if (@($inputs.Projects | Where-Object { -not $_.RegisterValid }).Count) { $diagnostics+='Escopo com registros ausentes/invalidos: trabalho total desconhecido.' }
        if (-not $data.EvidenceReview.Reviewed -or [string]::IsNullOrWhiteSpace($data.EvidenceReview.Reason)) { $diagnostics+='Confira as fontes atuais e justifique EvidenceReview antes de confiar nas estimativas.' }
        if (@($evidence | Where-Object { $_.Status -in @('AUSENTE','INVALIDA') }).Count) { $diagnostics+='Arquivo usado para estimar esta ausente/invalido; confira as referencias das atividades.' }
        if ($diagnostics.Count) {
            foreach ($scenario in @($simulation,$simulation.Scenarios.Min,$simulation.Scenarios.Max)) {
                $scenario.Feasibility='NAO_AVALIAVEL'; $scenario.State='RASCUNHO'; $scenario.ProductionDate=$null; $scenario.Diagnostics+=$diagnostics
            }
            $simulation.Scenarios.Reference.Feasibility='NAO_AVALIAVEL'; $simulation.Scenarios.Reference.ProductionDate=$null
        }
        if ($simulation.Feasibility -eq 'NAO_AVALIAVEL') { $data.State='RASCUNHO' }
        $data | Add-Member -NotePropertyName Simulation -NotePropertyValue $simulation
        $markdown=ConvertTo-SprintMarkdown $view $data $files[$rel+'/plano.md']
        $data.PSObject.Properties.Remove('Simulation')
        $result=[pscustomobject][ordered]@{SchemaVersion=1;Purpose='current-sprint-result';Scenario=$current.Scenario;Status='VALIDATED';Feasibility=$simulation.Feasibility;
            Baseline=[ordered]@{Id=$data.Baseline.Id;Known=$data.Baseline.Known;Issues=@($data.Baseline.Issues)};NewIssues=@($data.Changes.New);
            SprintStartDate=$data.Constraints.SprintStartDate;ReferenceDate=$data.Constraints.ReferenceDate;Simulation=$simulation;Diagnostics=$simulation.Diagnostics;
            EstimateEvidence=@($evidence | Select-Object Path,Kind,Status);SprintPlanPath=$current.SprintPlanPath;ContextPath=$current.ContextPath;ReviewPromptPath=$current.ReviewPromptPath}
        Assert-SprintReferences $inputs $Root
        Assert-SprintReferences ([pscustomobject]@{References=@($evidence)}) $Root
        $writes=@{}
        $writes[$rel+'/planejamento-sprints.json']=$data | ConvertTo-Json -Depth 60
        $writes[$rel+'/plano.md']=$markdown
        $writes[$rel+'/resultado.json']=$result | ConvertTo-Json -Depth 60
        Publish-HarnessProjectFiles $master $writes $files
    } finally { $lease.ReleaseMutex(); $lease.Dispose() }
    Update-HarnessSprintIndex $Root
    $result
    } finally { $scenarioLease.ReleaseMutex(); $scenarioLease.Dispose() }
}
