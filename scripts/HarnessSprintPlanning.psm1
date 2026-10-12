#requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'Harness.psm1') -DisableNameChecking
Import-Module (Join-Path $PSScriptRoot 'HarnessProject.psm1') -DisableNameChecking
Import-Module (Join-Path $PSScriptRoot 'HarnessPlanning.psm1') -DisableNameChecking
. (Join-Path $PSScriptRoot 'HarnessSprintSources.ps1')
. (Join-Path $PSScriptRoot 'HarnessSprintPresentation.ps1')
. (Join-Path $PSScriptRoot 'HarnessSprintState.ps1')
. (Join-Path $PSScriptRoot 'HarnessSprintSimulation.ps1')
. (Join-Path $PSScriptRoot 'HarnessSprintValidation.ps1')

function New-HarnessSprintContext {
    [CmdletBinding()]
    param($Context,[switch]$All,[string[]]$Sources,[string]$ContextPath,[string]$Scenario='migracao',[string]$MasterProject,[string]$Reason)
    $root=$Context.Root
    $scenarioLease=Enter-SprintAccess $root
    try {
    if ($All -and $Sources) { throw 'Escolha todos OU subconjunto.' }
    $current=$null
    if ($ContextPath) {
        $current=Read-HarnessSprintContext $root $ContextPath
        $Scenario=$current.Scenario; $MasterProject=$current.MasterProject
        if (($All -or $Sources) -and [string]::IsNullOrWhiteSpace($Reason)) { throw 'Alterar escopo exige motivo explicito.' }
    }
    if ($All) { $selected=@($Context.Projects) }
    elseif ($Sources) {
        $selected=@(foreach ($source in $Sources) {
            $matches=@($Context.Projects | Where-Object path -IEQ $source)
            if ($matches.Count -ne 1) { throw "Projeto ausente/ambiguo no workspace: $source" }
            $matches[0]
        })
    } elseif ($current) {
        $selected=@(foreach ($participant in $current.Projects) {
            $matches=@($Context.Projects | Where-Object { (Get-HarnessProjectReference $root (Join-Path $_.path 'pom.xml')).Name -ceq $participant.Project })
            if ($matches.Count -ne 1) { throw "Participante ausente/ambiguo: $($participant.Project). Atualize o escopo explicitamente." }
            $matches[0]
        })
    } else { throw 'Informe Todos ou os Sources dos projetos; Active nao define escopo macro.' }
    if (-not $selected.Count) { throw 'Nenhum projeto selecionado.' }
    $inputs=Get-HarnessSprintSources $Context $selected
    $existing=@(Get-HarnessSprintScenarios $root | Where-Object Scenario -CEQ $Scenario)
    if ($existing.Count -gt 1) { throw 'Cenario com mais de um mestre; concilie os documentos antes de continuar.' }
    if (-not $current -and $existing.Count) {
        $current=$existing[0]
        if ($MasterProject -and $MasterProject -cne $current.MasterProject) { throw 'Cenario ja possui mestre; retome o conjunto existente.' }
        $MasterProject=$current.MasterProject
        if ((@($current.Projects.Project | Sort-Object) -join '|') -cne (@($inputs.Projects.Project | Sort-Object) -join '|') -and -not $Reason) { throw 'Alterar participantes do cenario exige motivo explicito.' }
    }
    if (-not $MasterProject) {
        if ($inputs.Projects.Count -ne 1) { throw 'Escolha MasterProject entre os participantes do cenario.' }
        $MasterProject=$inputs.Projects[0].Project
    }
    $masters=@($inputs.Projects | Where-Object Project -CEQ $MasterProject)
    if ($masters.Count -ne 1) { throw 'O mestre deve permanecer participante; escolha outro cenario ou concilie explicitamente sua transferencia.' }
    $master=Get-HarnessProjectStorage $root $masters[0].Pom
    $paths=Get-SprintPaths $master $Scenario
    $lease=Enter-HarnessProjectAccess $master -ForOperation
    try {
        $rel=$paths.Relative
        $names=@('contexto.json','planejamento-sprints.json','plano.md','resultado.json','planejar-sprints.prompt.md','revisar-sprints.prompt.md')
        $old=Read-HarnessProjectFiles $master @($names | ForEach-Object { $rel+'/'+$_ })
        if ($old[$rel+'/contexto.json']) { $current=Read-HarnessSprintContext $root $paths.ContextPath }
        elseif (@($old.Values | Where-Object { $null -ne $_ }).Count) { throw 'Documentos sem contexto no destino; preserve e concilie antes de preparar.' }
        $mode=if ($All) {'ALL'} elseif ($Sources) {'SUBSET'} else {$current.SelectionMode}
        $next=[pscustomobject][ordered]@{SchemaVersion=1;Purpose='current-sprint-planning';Scenario=$Scenario;MasterProject=$MasterProject;SelectionMode=$mode;
            Projects=@($inputs.Projects | Select-Object Project,Label,Source,Pom,MigrationPath);
            Reason=$Reason;ContextPath=$paths.ContextPath;PromptPath=$paths.PromptPath;ReviewPromptPath=$paths.ReviewPromptPath;
            SprintDataPath=$paths.SprintDataPath;SprintPlanPath=$paths.SprintPlanPath;ValidationPath=$paths.ValidationPath;
            WorkTemplate=(New-SprintWorkTemplate);StaffingTemplate=[ordered]@{Sprint=1;Developers=$null;DeveloperAvailability=$null;ArchitectAvailability=$null;DevOpsAvailability=$null;ReservePercent=$null;AbsenceDays=@{Dev=0;Architect=0;DevOps=0}}}
        $known=@($inputs.Projects | Where-Object { -not $_.RegisterValid }).Count -eq 0
        if ($current) {
            if (-not $old[$rel+'/planejamento-sprints.json'] -or -not $old[$rel+'/plano.md']) { throw 'Dados/plano correntes ausentes; preserve o contexto e recupere o documento.' }
            $data=ConvertFrom-Json $old[$rel+'/planejamento-sprints.json']
            $result=if ($old[$rel+'/resultado.json']) { ConvertFrom-Json $old[$rel+'/resultado.json'] } else { $null }
            $null=Set-SprintIssueSources $data $inputs.Projects $current.Projects
            if (-not $result -or -not $result.Baseline.Known) {
                $data.Baseline.Known=$known
                $data.Baseline.Issues=@(Get-SprintBaseline $inputs.Projects $data.ScopeCategories)
            }
            if ($Reason -or (@($current.Projects | ConvertTo-Json -Depth 10 -Compress) -cne @($next.Projects | ConvertTo-Json -Depth 10 -Compress))) {
                $data.State='RASCUNHO'; $data.EvidenceReview=[pscustomobject]@{Reviewed=$false;Reason=$null}
            }
            $markdown=$old[$rel+'/plano.md']
        } else {
            $data=[pscustomobject][ordered]@{SchemaVersion=1;Purpose='current-sprint-planning';Scenario=$Scenario;State='RASCUNHO';ScopeCategories=@('mandatory');ScopeDecision=$null;
                Constraints=[ordered]@{SprintStartDate=$null;ProductionDeadline=$null;ReferenceDate=$null;MaxPreparationSprints=$null;MaxImplementationSprints=$null;MaxTestSprints=$null;MaxTotalSprints=$null;MaxDevelopers=$null;UnboundedPhases=@()};
                Team=[ordered]@{RolesAreDistinct=$null;WorkWeek=@(1,2,3,4,5);Holidays=@();Staffing=@()};
                Baseline=[ordered]@{Id='B0';Known=$known;Issues=@(Get-SprintBaseline $inputs.Projects @('mandatory'));Accepted=@()};
                Changes=[ordered]@{New=@();Reopened=@();Excluded=@()};Work=@();Assumptions=@();Decisions=@();
                Estimation=@{AiDeveloperReductionPercent=$null};EvidenceReview=@{Reviewed=$false;Reason=$null}}
            $markdown=New-SprintDraftMarkdown $next '' ([IO.File]::ReadAllText((Join-Path $root 'doc/modelos/planejamento-sprints.template.md')))
        }
        $writes=@{}
        $writes[$rel+'/contexto.json']=$next | ConvertTo-Json -Depth 30
        $writes[$rel+'/planejamento-sprints.json']=$data | ConvertTo-Json -Depth 60
        $writes[$rel+'/plano.md']=$markdown
        foreach ($name in @('planejar-sprints.prompt.md','revisar-sprints.prompt.md')) {
            $template=[IO.File]::ReadAllText((Join-Path $root ('.github/prompts/'+$name)))
            $writes[$rel+'/'+$name]=Get-SprintPrompt $template ([string]$old[$rel+'/'+$name]) (Join-Path (Split-Path $paths.ContextPath -Parent) $name) $next
        }
        Assert-SprintReferences $inputs $root
        Publish-HarnessProjectFiles $master $writes $old
    } finally { $lease.ReleaseMutex(); $lease.Dispose() }
    Update-HarnessSprintIndex $root
    $next | Add-Member -NotePropertyName Reused -NotePropertyValue ([bool]$current)
    $next
    } finally { $scenarioLease.ReleaseMutex(); $scenarioLease.Dispose() }
}

Export-ModuleMember -Function Get-HarnessSprintSources,New-HarnessSprintContext,Read-HarnessSprintContext,Get-HarnessSprintScenarios,Update-HarnessSprintIndex,Complete-HarnessSprintPlan,Get-HarnessSprintSimulation
