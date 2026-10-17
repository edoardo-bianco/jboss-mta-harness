function Convert-ConversionSprintIssues($State,$Data) {
    $issues=@($Data.Baseline.Issues)+@(Get-LegacyValue $Data.Baseline 'Accepted' @())+@($Data.Changes.New)+@($Data.Changes.Reopened)+@($Data.Changes.Excluded)
    foreach ($work in $Data.Work) { $issues+=@($work.Issues) }
    foreach ($issue in $issues) {
        $source=Resolve-ProjectPath $issue.Source $State.Project.Root
        $matches=@($State.Participants | Where-Object LegacySource -IEQ $source)
        if ($matches.Count -ne 1) { throw ('Issue historica de sprints sem associacao explicita: '+$source) }
        $issue.Source=$matches[0].Project.Source
        $issue|Add-Member Project $matches[0].Project.Name -Force
    }
}

function Resolve-ConversionSprintReference($State,[string]$Path) {
    if ($Path -match '^https?://') { return $Path }
    $origin=Resolve-ProjectPath $Path $State.Project.Root
    if ($State.Map.ContainsKey($origin)) { return $State.Map[$origin] }
    $matches=@($State.Participants | Where-Object { $origin -ieq $_.LegacySource -or $origin.StartsWith($_.LegacySource+'\',[StringComparison]::OrdinalIgnoreCase) } | Sort-Object @{Expression={$_.LegacySource.Length};Descending=$true})
    if ($matches.Count) {
        $suffix=$origin.Substring($matches[0].LegacySource.Length).TrimStart('\')
        if ($suffix) { return Join-Path $matches[0].Project.Source $suffix }
        return $matches[0].Project.Source
    }
    if ($origin.StartsWith($State.Inputs.Session.DataRoot+'\',[StringComparison]::OrdinalIgnoreCase)) { throw ('Referencia de sprints sem destino corrente: '+$origin) }
    $origin
}

function Add-ConversionSprintEvidence($State,$Scenario) {
    $documents=@(); $queue=New-Object 'Collections.Generic.Queue[string]'
    foreach ($revision in @($Scenario.History.Selected,$Scenario.History.Published) | Where-Object { $_ }) {
        foreach ($work in $revision.Data.Work) { foreach ($path in $work.References) { $queue.Enqueue($path) } }
        foreach ($reference in @(Get-LegacyValue $revision.Data 'EstimateEvidence' @())) { $queue.Enqueue($reference.Path) }
        foreach ($path in @(Get-ConversionLinks $revision.Markdown $revision.Context.SprintPlanPath $State.Inputs.Session)) { $queue.Enqueue($path) }
    }
    $visited=@{}; $destinations=@{}
    while ($queue.Count) {
        $path=$queue.Dequeue()
        if ($path -match '^https?://') { continue }
        $path=Resolve-ProjectPath $path $State.Project.Root
        if ($visited.ContainsKey($path)) { continue }
        $visited[$path]=$true
        if ($State.Map.ContainsKey($path) -or -not $path.StartsWith($State.Inputs.Session.DataRoot+'\',[StringComparison]::OrdinalIgnoreCase)) { continue }
        $leaf=[IO.Path]::GetFileName($path)
        if ($leaf -match '^(context(?:o)?(?:-.*)?|preparo|validacao|atual|manifest|result|project)\.json$|^output\.js$') { throw ('Referencia operacional de sprints nao consolidada: '+$path) }
        $relative='evidencias/sprints/'+(ConvertTo-HarnessFunctionalPath $Scenario.Scenario)+'/'+$leaf
        if ($destinations.ContainsKey($relative) -and $destinations[$relative] -ine $path) { throw 'Anexos distintos de sprints disputam o mesmo nome; esclareca a origem.' }
        $destinations[$relative]=$path
        $State.Map[$path]=Join-Path $Scenario.Master.Folder $relative
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            $State.Diagnostics.Add('Anexo de sprints indisponivel: '+$path); continue
        }
        if ([IO.Path]::GetExtension($path) -ieq '.md') {
            $text=Read-ConversionText $State.Inputs.Session $path
            $documents+=@([pscustomobject]@{Path=$path;Relative=$relative;Text=$text})
            foreach ($link in @(Get-ConversionLinks $text $path $State.Inputs.Session)) { $queue.Enqueue($link) }
        } else { $State.Files[$relative]=Read-ConversionBytes $State $path }
    }
    foreach ($document in $documents) { $State.Files[$document.Relative]=Convert-ConversionMarkdown $document.Text $document.Path $State.Map[$document.Path] $State }
}

function Set-ConversionSprintReferences($State,$Data) {
    foreach ($work in $Data.Work) { $work.References=@(foreach ($path in $work.References) { Resolve-ConversionSprintReference $State $path }) }
    foreach ($reference in @(Get-LegacyValue $Data 'EstimateEvidence' @())) {
        $reference.Path=Resolve-ConversionSprintReference $State $reference.Path
        $reference.PSObject.Properties.Remove('Sha256')
    }
    $simulation=Get-LegacyValue $Data 'Simulation'
    if ($simulation) {
        foreach ($variant in @($simulation,$simulation.Scenarios.Min,$simulation.Scenarios.Max)) {
            foreach ($gap in @($variant.Unscheduled)) {
                if (Get-LegacyValue $gap 'Source') { $gap.Source=Resolve-ConversionSprintReference $State $gap.Source }
            }
        }
    }
}

function Add-ConversionSprintDocuments($State,$Scenarios) {
    $codeRoot=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    foreach ($scenario in $Scenarios) {
        if ($scenario.Master.Name -cne $State.Project.Name) { continue }
        $paths=$scenario.Paths; $selected=$scenario.History.Selected
        $legacy=$selected.Context
        Add-ConversionSprintEvidence $State $scenario
        $projects=@(foreach ($entry in $scenario.Participants) {
            $project=$entry.Project
            [pscustomobject]@{Project=$project.Name;Label=$project.Name;Source=$project.Source;Pom=$project.Pom;MigrationPath=$project.MigrationPath}
        })
        $current=[pscustomobject][ordered]@{SchemaVersion=1;Purpose='current-sprint-planning';Scenario=$scenario.Scenario;MasterProject=$scenario.Master.Name;
            SelectionMode=$legacy.SelectionMode;Projects=$projects;Reason=$legacy.Reason;NeedsReview=$true;
            ContextPath=$paths.ContextPath;PromptPath=$paths.PromptPath;ReviewPromptPath=$paths.ReviewPromptPath;SprintDataPath=$paths.SprintDataPath;SprintPlanPath=$paths.SprintPlanPath;ValidationPath=$paths.ValidationPath;
            WorkTemplate=$legacy.WorkTemplate;StaffingTemplate=$legacy.StaffingTemplate}
        $data=$selected.Data|ConvertTo-Json -Depth 60|ConvertFrom-Json
        foreach ($name in @('PlanningId','RevisionId','Simulation','EstimateEvidence')) { $data.PSObject.Properties.Remove($name) }
        $data.Purpose='current-sprint-planning'; $data.State='RASCUNHO'
        $data|Add-Member Scenario $scenario.Scenario -Force
        $data.EvidenceReview=[pscustomobject]@{Reviewed=$false;Reason='Premissas convertidas; revisar fontes e alcance das decisoes humanas.'}
        Convert-ConversionSprintIssues $State $data
        Set-ConversionSprintReferences $State $data
        $current.WorkTemplate=$current.WorkTemplate|ConvertTo-Json -Depth 60|ConvertFrom-Json
        Convert-ConversionSprintIssues $State ([pscustomobject]@{Baseline=@{Issues=@();Accepted=@()};Changes=@{New=@();Reopened=@();Excluded=@()};Work=@($current.WorkTemplate)})
        $current.WorkTemplate.References=@(foreach ($path in $current.WorkTemplate.References) { Resolve-ConversionSprintReference $State $path })
        $markdown=Convert-ConversionMarkdown $selected.Markdown $legacy.SprintPlanPath $paths.SprintPlanPath $State
        # A narrativa da revisao escolhida permanece. O bloco publicado descreve
        # exclusivamente as premissas comprovadas anteriores, sem recalculo.
        $published=$scenario.History.Published
        if ($published) {
            $proven=$published.Data|ConvertTo-Json -Depth 60|ConvertFrom-Json
            Convert-ConversionSprintIssues $State $proven
            Set-ConversionSprintReferences $State $proven
            $result=[ordered]@{SchemaVersion=1;Purpose='current-sprint-result';Scenario=$scenario.Scenario;Status='CONVERTED';NeedsReview=$true;Feasibility=$proven.Simulation.Feasibility;
                Baseline=@{Id=$proven.Baseline.Id;Known=$proven.Baseline.Known;Issues=@($proven.Baseline.Issues)};NewIssues=@($proven.Changes.New);
                SprintStartDate=$proven.Constraints.SprintStartDate;ReferenceDate=$proven.Constraints.ReferenceDate;Simulation=$proven.Simulation;Diagnostics=@($proven.Simulation.Diagnostics);
                EstimateEvidence=@(Get-LegacyValue $proven 'EstimateEvidence' @());SprintPlanPath=$paths.SprintPlanPath;ContextPath=$paths.ContextPath;ReviewPromptPath=$paths.ReviewPromptPath}
            $view=[pscustomobject]@{Scenario=$scenario.Scenario;Projects=@($projects | ForEach-Object { [pscustomobject]@{Project=$_.Project;Label=$_.Label;Issues=@();Diagnostics=@()} });References=@();SprintPlanPath=$paths.SprintPlanPath;SprintDataPath=$paths.SprintDataPath}
            $markdown=ConvertTo-SprintMarkdown $view $proven $markdown
            $State.Files[$paths.Relative+'/resultado.json']=$result|ConvertTo-Json -Depth 60
        } else { $markdown=New-SprintDraftMarkdown $current $markdown '' }
        $markdown=Set-ProjectManagedBlock $markdown 'sprints:conversao' 'Conversao preliminar. O ultimo calculo comprovado preserva premissas historicas e pode diferir das premissas editaveis. Revisao local pendente; nao concede GO nem aceite.'
        $State.Files[$paths.Relative+'/contexto.json']=$current|ConvertTo-Json -Depth 60
        $State.Files[$paths.Relative+'/planejamento-sprints.json']=$data|ConvertTo-Json -Depth 60
        $State.Files[$paths.Relative+'/plano.md']=$markdown
        $promptInputs=[pscustomobject]@{References=@();Projects=@($projects|ForEach-Object {
            [pscustomobject]@{Project=$_.Project;Source=$_.Source;References=@([pscustomobject]@{Path=$_.MigrationPath;Kind='Registro';Status='DISPONIVEL'})}
        })}
        foreach ($pair in @(@('PromptPath','planejar-sprints.prompt.md'),@('ReviewPromptPath','revisar-sprints.prompt.md'))) {
            $template=[IO.File]::ReadAllText((Join-Path $codeRoot ('.github/prompts/'+$pair[1])))
            $State.Files[$paths.Relative+'/'+$pair[1]]=Get-SprintPrompt $template '' $paths.($pair[0]) $current $promptInputs
        }
    }
}
