#requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'Harness.psm1') -DisableNameChecking
Import-Module (Join-Path $PSScriptRoot 'HarnessPlanning.psm1') -DisableNameChecking
. (Join-Path $PSScriptRoot 'HarnessSprintSources.ps1')
. (Join-Path $PSScriptRoot 'HarnessSprintPresentation.ps1')
# Calculation is isolated from all file operations.
if (Test-Path (Join-Path $PSScriptRoot 'HarnessSprintSimulation.ps1')) { . (Join-Path $PSScriptRoot 'HarnessSprintSimulation.ps1') }

function Write-SprintJson {
    param([string]$Path,$Value)
    [IO.File]::WriteAllText($Path,($Value | ConvertTo-Json -Depth 60),(New-Object Text.UTF8Encoding($false)))
}

function Read-HarnessSprintContext {
    param([string]$Root,[string]$ContextPath)
    $path=Resolve-HarnessPath $ContextPath $Root
    $receipt=Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($receipt.SchemaVersion -ne 1 -or $receipt.Purpose -cne 'sprint-planning' -or $receipt.PlanningId -cnotmatch '^[a-f0-9]{32}$' -or $receipt.RevisionId -cnotmatch '^[a-f0-9]{32}$') { throw 'Identidade/versao do contexto de sprints invalida.' }
    $expected=Resolve-HarnessPath (Join-Path $Root ('.harness/sprints/'+$receipt.PlanningId+'/revisoes/'+$receipt.RevisionId)) $Root
    if ($path -ine (Join-Path $expected 'contexto.json')) { throw 'Contexto fora do destino do cenario/revisao.' }
    foreach ($pair in @(@('ContextPath','contexto.json'),@('PromptPath','planejar-sprints.prompt.md'),@('SprintDataPath','planejamento-sprints.json'),@('SprintPlanPath','planejamento-sprints.md'),@('ValidationPath','validacao.json'))) {
        if ((Resolve-HarnessPath $receipt.($pair[0]) $Root) -ine (Join-Path $expected $pair[1])) { throw 'Destino divergente no contexto de sprints.' }
    }
    $seal=Get-Content -LiteralPath (Join-Path $expected 'preparo.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($seal.ContextSha256 -cne (Get-FileHash -LiteralPath $path).Hash) { throw 'Contexto alterado depois do preparo. Preserve-o e prepare uma revisao.' }
    $receipt
}

function Get-HarnessSprintHistory {
    param([string]$Root)
    $base=Join-Path $Root '.harness/sprints'
    if (-not (Test-Path -LiteralPath $base)) { return }
    foreach ($scenario in Get-ChildItem -LiteralPath $base -Directory | Sort-Object Name) {
        $revisions=Join-Path $scenario.FullName 'revisoes'
        if (-not (Test-Path -LiteralPath $revisions)) { continue }
        foreach ($revision in Get-ChildItem -LiteralPath $revisions -Directory | Sort-Object Name) {
            $contextPath=Join-Path $revision.FullName 'contexto.json'
            if (-not (Test-Path -LiteralPath $contextPath)) { continue }
            Read-HarnessSprintContext $Root $contextPath
        }
    }
}

function Get-SprintValidatedAncestors {
    param($Receipt,[string]$Root)
    $visited=@{}; $current=$Receipt
    while ($current.Previous) {
        $path=$current.Previous.ContextPath
        if ($visited.ContainsKey($path)) { throw 'Ciclo na cadeia de revisoes.' }
        $visited[$path]=$true
        $parent=Read-HarnessSprintContext $Root $path
        if ($parent.PlanningId -cne $Receipt.PlanningId -or $parent.RevisionId -cne $current.Previous.RevisionId) { throw 'Ancestral de outro cenario/revisao.' }
        if (Test-Path -LiteralPath $parent.ValidationPath) {
            $validation=Get-Content -LiteralPath $parent.ValidationPath -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($validation.ContextSha256 -cne (Get-FileHash -LiteralPath $parent.ContextPath).Hash -or $validation.RevisionId -cne $parent.RevisionId -or $validation.PlanningId -cne $parent.PlanningId) { throw 'Validacao ancestral inconsistente.' }
            [pscustomobject]@{Receipt=$parent;Validation=$validation}
        }
        $current=$parent
    }
}

function New-SprintWorkTemplate {
    [pscustomobject][ordered]@{Id='atividade-1';Title='Descrever entrega';Phase='IMPLEMENTATION';Priority=$null;DependsOn=@();Issues=@();Effort=[ordered]@{Dev=@{Min=$null;Reference=$null;Max=$null};Architect=@{Min=$null;Reference=$null;Max=$null};DevOps=@{Min=$null;Reference=$null;Max=$null}};EstimateSource=$null;Confidence=$null;Assumptions=@();NotBefore=$null;Deadline=$null;Acceptance=$null;References=@();Remaining=$true}
}

function New-HarnessSprintContext {
    [CmdletBinding()]
    param($Context,[switch]$All,[string[]]$Sources,[string]$PreviousContextPath,[string]$Reason)
    $root=$Context.Root
    $state=Resolve-HarnessPath (Join-Path $root '.harness') $root
    $null=[IO.Directory]::CreateDirectory($state)
    try { $lease=[IO.File]::Open((Join-Path $state 'sprints.lock'),'OpenOrCreate','ReadWrite','None') }
    catch { throw 'Planejamento de sprints em andamento; aguarde antes de gravar.' }
    try {
        $previous=$null
        if ($All -and $Sources) { throw 'Escolha todos OU subconjunto.' }
        if ($PreviousContextPath) {
            $previous=Read-HarnessSprintContext $root $PreviousContextPath
            if (($All -or $Sources) -and [string]::IsNullOrWhiteSpace($Reason)) { throw 'Alterar escopo exige revisao explicita com motivo.' }
            $selected=if ($All) { @($Context.Projects) } elseif ($Sources) { @(foreach ($source in $Sources) {
                $matches=@($Context.Projects | Where-Object path -IEQ $source)
                if ($matches.Count -ne 1) { throw "Projeto ausente/ambiguo no workspace: $source" }
                $matches[0]
            }) } else { @(foreach ($item in $previous.Projects) {
                $matches=@($Context.Projects | Where-Object path -IEQ $item.Source)
                if ($matches.Count -eq 1) { $matches[0] } else { [pscustomobject]@{name=$item.Project;label=$item.Label;path=$item.Source} }
            }) }
            $mode=if ($All) {'ALL'} elseif ($Sources) {'SUBSET'} else {$previous.SelectionMode}
        } else {
            if (-not $All -and -not $Sources) { throw 'Informe Todos ou os Sources dos projetos; Active nao define escopo macro.' }
            $selected=if ($All) { @($Context.Projects) } else { @(foreach ($source in $Sources) {
                $matches=@($Context.Projects | Where-Object path -IEQ $source)
                if ($matches.Count -ne 1) { throw "Projeto ausente/ambiguo no workspace: $source" }
                $matches[0]
            }) }
            $mode=if ($All) {'ALL'} else {'SUBSET'}
        }
        $selected=@($selected | Sort-Object path -Unique)
        if (-not $selected.Count) { throw 'Nenhum projeto selecionado.' }
        $inputs=Get-HarnessSprintSources $Context $selected
        $inputChanges=@()
        $previousFingerprint=$null
        if ($previous) {
            $previousData=Get-Content -LiteralPath $previous.SprintDataPath -Raw -Encoding UTF8 | ConvertFrom-Json
            $estimateEvidence=@(Get-SprintInputValue $previousData 'EstimateEvidence' @())
            foreach ($reference in $estimateEvidence) { $inputs.References+=Get-SprintReference $reference.Path $root 'Estimativa' }
            $inputs.References=@($inputs.References | Sort-Object Path -Unique)
            $inputs.Fingerprint=Get-SprintJsonHash ([ordered]@{Projects=$inputs.Projects;References=$inputs.References})
            $previousReferences=@(@($previous.References)+@($estimateEvidence) | Sort-Object Path -Unique)
            $previousFingerprint=Get-SprintJsonHash ([ordered]@{Projects=$previous.Projects;References=$previousReferences})
            $inputChanges=@(Get-SprintReferenceChanges $previousReferences $inputs.References)
        }
        if ($previous -and $inputs.Fingerprint -ceq $previousFingerprint -and -not $Reason) {
            $previous | Add-Member -NotePropertyName Reused -NotePropertyValue $true -Force
            return $previous
        }
        if ($previous -and [string]::IsNullOrWhiteSpace($Reason)) { throw 'Entradas mudaram. Use Revisar e informe motivo antes de preparar outra revisao.' }
        $planningId=if ($previous) {$previous.PlanningId} else {[guid]::NewGuid().ToString('N')}
        $revisionId=[guid]::NewGuid().ToString('N')
        $directory=Resolve-HarnessPath (Join-Path $state ('sprints/'+$planningId+'/revisoes/'+$revisionId)) $root
        $receipt=[pscustomobject][ordered]@{SchemaVersion=1;Purpose='sprint-planning';PlanningId=$planningId;RevisionId=$revisionId;PreparedAtUtc=[DateTime]::UtcNow.ToString('o');SelectionMode=$mode;Projects=$inputs.Projects;References=$inputs.References;InputFingerprint=$inputs.Fingerprint;Previous=$null;Reason=$Reason;ContextPath=(Join-Path $directory 'contexto.json');PromptPath=(Join-Path $directory 'planejar-sprints.prompt.md');SprintDataPath=(Join-Path $directory 'planejamento-sprints.json');SprintPlanPath=(Join-Path $directory 'planejamento-sprints.md');ValidationPath=(Join-Path $directory 'validacao.json');WorkTemplate=(New-SprintWorkTemplate);StaffingTemplate=[ordered]@{Sprint=1;Developers=$null;DeveloperAvailability=$null;ArchitectAvailability=$null;DevOpsAvailability=$null;ReservePercent=$null;AbsenceDays=@{Dev=0;Architect=0;DevOps=0}};Reused=$false}
        $receipt | Add-Member -NotePropertyName InputChanges -NotePropertyValue $inputChanges
        $historicalIssues=@()
        if ($previous) {
            $historicalIssues+=@(Get-SprintInputValue $previous 'HistoricalIssues' @())
            $historicalIssues+=@(foreach ($project in $previous.Projects) { foreach ($issue in $project.Issues) { [pscustomobject]@{Source=$project.Source;Id=$issue.Id} } })
        }
        $receipt | Add-Member -NotePropertyName HistoricalIssues -NotePropertyValue @($historicalIssues | Sort-Object Source,Id -Unique)
        $baseline=@(foreach ($project in $inputs.Projects) { foreach ($issue in $project.Issues | Where-Object Category -EQ 'mandatory') { [pscustomobject]@{Source=$project.Source;Id=$issue.Id} } })
        $data=[pscustomobject][ordered]@{SchemaVersion=1;Purpose='sprint-planning';PlanningId=$planningId;RevisionId=$revisionId;State='RASCUNHO';ScopeCategories=@('mandatory');ScopeDecision=$null;Constraints=[ordered]@{SprintStartDate=$null;ProductionDeadline=$null;ReferenceDate=$null;MaxPreparationSprints=$null;MaxImplementationSprints=$null;MaxTestSprints=$null;MaxTotalSprints=$null;MaxDevelopers=$null};Team=[ordered]@{RolesAreDistinct=$null;WorkWeek=@(1,2,3,4,5);Holidays=@();Staffing=@()};Baseline=[ordered]@{Id='B0';Known=(@($inputs.Projects | Where-Object { -not $_.RegisterValid }).Count -eq 0);Issues=$baseline;Accepted=@()};Changes=[ordered]@{New=@();Reopened=@();Excluded=@()};Work=@();Assumptions=@();Decisions=@();Simulation=$null}
        $data | Add-Member -NotePropertyName EstimateEvidence -NotePropertyValue @()
        $data | Add-Member -NotePropertyName EvidenceReview -NotePropertyValue ([pscustomobject]@{Reviewed=$false;Reason=$null})
        $editorial=$null
        if ($previous) {
            $receipt.Previous=[pscustomobject]@{PlanningId=$previous.PlanningId;RevisionId=$previous.RevisionId;ContextPath=$previous.ContextPath;SprintPlanPath=$previous.SprintPlanPath;SprintDataPath=$previous.SprintDataPath;DataSha256=(Get-FileHash -LiteralPath $previous.SprintDataPath).Hash;PlanSha256=(Get-FileHash -LiteralPath $previous.SprintPlanPath).Hash}
            $data=Get-Content -LiteralPath $previous.SprintDataPath -Raw -Encoding UTF8 | ConvertFrom-Json
            $data.RevisionId=$revisionId
            $data.State='RASCUNHO'
            $data.Simulation=$null
            $data.EvidenceReview=[pscustomobject]@{Reviewed=($inputChanges.Count -eq 0);Reason=$null}
            $formed=@(Get-SprintValidatedAncestors $receipt $root | Where-Object { $_.Validation.BaselineFrozen })
            if (-not $formed.Count) {
                $data.Baseline.Known=@($inputs.Projects | Where-Object { -not $_.RegisterValid }).Count -eq 0
                $data.Baseline.Issues=@(foreach ($project in $inputs.Projects) { foreach ($issue in $project.Issues | Where-Object { $_.Category -in $data.ScopeCategories }) { [pscustomobject]@{Source=$project.Source;Id=$issue.Id} } })
            }
            $editorial=[IO.File]::ReadAllText($previous.SprintPlanPath)
        }
        # Validate inputs again before any durable revision. The context receipt is written last.
        Assert-SprintReferences $receipt $root
        $null=[IO.Directory]::CreateDirectory($directory)
        Write-SprintJson $receipt.SprintDataPath $data
        $markdown=New-SprintDraftMarkdown $receipt $editorial
        [IO.File]::WriteAllText($receipt.SprintPlanPath,$markdown,(New-Object Text.UTF8Encoding($false)))
        $template=[IO.File]::ReadAllText((Join-Path $root '.github/prompts/planejar-sprints.prompt.md'))
        $template += "`r`n`r`n## Contexto desta solicitacao`r`n`r`nContextPath: $($receipt.ContextPath)`r`nSprintDataPath: $($receipt.SprintDataPath)`r`nSprintPlanPath: $($receipt.SprintPlanPath)`r`nValidationPath: $($receipt.ValidationPath)`r`nPlanningId: $planningId`r`nRevisionId: $revisionId`r`n"
        [IO.File]::WriteAllText($receipt.PromptPath,$template,(New-Object Text.UTF8Encoding($false)))
        Write-SprintJson $receipt.ContextPath $receipt
        Write-SprintJson (Join-Path $directory 'preparo.json') ([ordered]@{ContextSha256=(Get-FileHash -LiteralPath $receipt.ContextPath).Hash;CalculatedBlockSha256=(Get-SprintJsonHash (Get-SprintCalculatedBlock $markdown))})
        $receipt
    } finally { $lease.Dispose() }
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
    param($Data,$Receipt,[string]$Root)
    if ($Data.SchemaVersion -ne 1 -or $Data.Purpose -cne 'sprint-planning' -or $Data.PlanningId -cne $Receipt.PlanningId -or $Data.RevisionId -cne $Receipt.RevisionId) { throw 'Identidade dos dados diverge do contexto.' }
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
    $first=$true
    $ancestors=@()
    if ($Receipt.Previous) {
        $ancestors=@(Get-SprintValidatedAncestors $Receipt $Root)
        $frozen=@($ancestors | Where-Object { $_.Validation.BaselineFrozen } | Select-Object -First 1)
        if ($frozen.Count) {
            $previous=$frozen[0].Validation.DataSnapshot
            $first=$false
            if ((Get-SprintJsonHash $Data.Baseline.Issues) -cne (Get-SprintJsonHash $previous.Baseline.Issues) -or $Data.Baseline.Id -cne $previous.Baseline.Id -or $Data.Baseline.Known -ne $previous.Baseline.Known) { throw 'B0 validada e fixa. Registre inclusoes/reaberturas/exclusoes em Changes.' }
        }
    }
    $actual=Get-SprintIssueSet $Data.Baseline.Issues 'Baseline.Issues'
    if ($first) {
        if ($actual.Count -ne $expected.Count -or @($expected.Keys | Where-Object { -not $actual.ContainsKey($_) }).Count) { throw 'B0 deve conter exatamente as issues das categorias selecionadas do contexto; aceite comprovado entra em Accepted.' }
        $isKnown=@($Receipt.Projects | Where-Object { -not $_.RegisterValid }).Count -eq 0
        if ($Data.Baseline.Known -ne $isKnown) { throw 'Denominador conhecido diverge das lacunas dos registros.' }
    }
    $historicalNew=Get-SprintIssueSet @() 'Historical.New'
    foreach ($ancestor in $ancestors) { foreach ($issue in $ancestor.Validation.DataSnapshot.Changes.New) { $historicalNew[(Get-HarnessSprintIssueKey $issue)]=$issue } }
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

function Publish-SprintPointer {
    param([string]$Root,$Receipt,$Validation)
    $directory=Split-Path $Receipt.ContextPath -Parent
    $scenario=Split-Path (Split-Path $directory -Parent) -Parent
    $pointer=Join-Path $scenario 'atual.json'
    $pointerHash=$null
    $ancestors=@(Get-SprintValidatedAncestors $Receipt $Root)
    if (Test-Path -LiteralPath $pointer) {
        $pointerHash=(Get-FileHash -LiteralPath $pointer).Hash
        $current=Get-Content -LiteralPath $pointer -Raw -Encoding UTF8 | ConvertFrom-Json
        $currentReceipt=Read-HarnessSprintContext $Root $current.ContextPath
        if ($currentReceipt.PlanningId -cne $Receipt.PlanningId -or $currentReceipt.RevisionId -cne $current.RevisionId -or $current.ValidationPath -ine $currentReceipt.ValidationPath -or $current.ValidationSha256 -cne (Get-FileHash -LiteralPath $currentReceipt.ValidationPath).Hash) { throw 'Ponteiro atual inconsistente; preserve historico e confira a publicacao.' }
        if ($current.RevisionId -ceq $Receipt.RevisionId) { return }
        if (-not $ancestors.Count -or $current.RevisionId -cne $ancestors[0].Receipt.RevisionId) { throw 'Outra revisao ja foi publicada; escolha sua base explicitamente antes de publicar.' }
    }
    $temporary=Join-Path $scenario ('atual-'+[guid]::NewGuid().ToString('N')+'.tmp')
    try {
        Write-SprintJson $temporary ([ordered]@{PlanningId=$Receipt.PlanningId;RevisionId=$Receipt.RevisionId;ContextPath=$Receipt.ContextPath;ValidationPath=$Receipt.ValidationPath;ValidationSha256=(Get-FileHash -LiteralPath $Receipt.ValidationPath).Hash})
        if ($null -ne $pointerHash) {
            # Windows may briefly hold a newly written file open. Retry only errors
            # which leave both names intact; never delete the previous pointer.
            # https://learn.microsoft.com/windows/win32/api/winbase/nf-winbase-replacefilew
            for ($attempt=0;$attempt -lt 8;$attempt++) {
                if (-not (Test-Path -LiteralPath $pointer) -or (Get-FileHash -LiteralPath $pointer).Hash -cne $pointerHash) { throw 'Ponteiro editado durante a publicacao; preserve a outra contribuicao e confira o historico.' }
                try { [IO.File]::Replace($temporary,$pointer,[System.Management.Automation.Language.NullString]::Value);break }
                catch {
                    $code=$_.Exception.GetBaseException().HResult -band 0xffff
                    if ($code -notin @(32,1175) -or $attempt -eq 7) { throw }
                    Start-Sleep -Milliseconds 200
                }
            }
        } else { [IO.File]::Move($temporary,$pointer) }
    } finally { if (Test-Path -LiteralPath $temporary) { Remove-Item -LiteralPath $temporary -Force } }
}

function Complete-HarnessSprintPlan {
    [CmdletBinding()]
    param([string]$Root,[string]$ContextPath)
    $state=Resolve-HarnessPath (Join-Path $Root '.harness') $Root
    try { $lease=[IO.File]::Open((Join-Path $state 'sprints.lock'),'OpenOrCreate','ReadWrite','None') }
    catch { throw 'Outra operacao de sprints esta em andamento.' }
    try {
        $receipt=Read-HarnessSprintContext $Root $ContextPath
        Assert-SprintReferences $receipt $Root
        $dataHash=(Get-FileHash -LiteralPath $receipt.SprintDataPath).Hash
        $planHash=(Get-FileHash -LiteralPath $receipt.SprintPlanPath).Hash
        if (Test-Path -LiteralPath $receipt.ValidationPath) {
            $valid=Get-Content -LiteralPath $receipt.ValidationPath -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($valid.DataSha256 -ceq $dataHash -and $valid.PlanSha256 -ceq $planHash) {
                Assert-SprintReferences ([pscustomobject]@{References=$valid.DataSnapshot.EstimateEvidence}) $Root
                Publish-SprintPointer $Root $receipt $valid
                return $valid
            }
            throw 'Revisao ja validada foi editada. Use Revisar com motivo; a publicacao anterior permanece preservada em validacao.json.'
        }
        $data=Get-Content -LiteralPath $receipt.SprintDataPath -Raw -Encoding UTF8 | ConvertFrom-Json
        Assert-SprintDataScope $data $receipt $Root
        $ancestors=@(Get-SprintValidatedAncestors $receipt $Root)
        $seal=Get-Content -LiteralPath (Join-Path (Split-Path $receipt.ContextPath -Parent) 'preparo.json') -Raw -Encoding UTF8 | ConvertFrom-Json
        $inputMarkdown=[IO.File]::ReadAllText($receipt.SprintPlanPath)
        if ($seal.CalculatedBlockSha256 -cne (Get-SprintJsonHash (Get-SprintCalculatedBlock $inputMarkdown))) { throw 'Bloco calculado foi editado manualmente. Preserve a contribuicao na narrativa e restaure o bloco preparado antes de calcular.' }
        $estimateEvidence=@(foreach ($work in $data.Work) { foreach ($path in $work.References) {
            if ($path -isnot [string]) { throw 'Work.References exige caminhos/URLs como strings.' }
            Get-SprintReference $path $Root 'Estimativa'
        } })
        $data.EstimateEvidence=@($estimateEvidence | Sort-Object Path -Unique)
        if ($null -ne $data.Simulation) { throw 'Simulation e calculada pela tarefa. Preserve a contribuicao na narrativa e restaure Simulation=null antes de validar.' }
        $previousSimulation=$null
        if ($ancestors.Count) {
            $previousData=$ancestors[0].Validation.DataSnapshot
            if ($previousData.Constraints.SprintStartDate -and $data.Constraints.SprintStartDate -ne $previousData.Constraints.SprintStartDate) { throw 'Inicio das sprints ja publicadas e fixo; para outro calendario crie um cenario separado.' }
            if ($previousData.Constraints.ReferenceDate -and (-not $data.Constraints.ReferenceDate -or $data.Constraints.ReferenceDate -lt $previousData.Constraints.ReferenceDate)) { throw 'Data de referencia nao pode retroceder nem ser removida numa revisao.' }
            $previousSimulation=$previousData.Simulation
        }
        $simulation=Get-HarnessSprintSimulation -Data $data -PreviousSimulation $previousSimulation
        $data.Simulation=$simulation
        if ($simulation.Feasibility -eq 'NAO_AVALIAVEL') { $data.State='RASCUNHO' }
        $contextDiagnostics=@()
        # Sharing people across roles requires explicit distribution; do not assume extra capacity.
        if ((Get-SprintInputValue $data.Team 'RolesAreDistinct') -ne $true) {
            $contextDiagnostics+= 'Confirme pessoas distintas por papel (Team.RolesAreDistinct); acumulo de papeis exige redistribuir disponibilidade sem dupla contagem.'
        }
        if (@($receipt.Projects | Where-Object { -not $_.RegisterValid }).Count) {
            $contextDiagnostics+='Escopo com registros ausentes/invalidos: trabalho total desconhecido.'
        }
        if (@($receipt.InputChanges).Count -and (-not $data.EvidenceReview.Reviewed -or [string]::IsNullOrWhiteSpace($data.EvidenceReview.Reason))) {
            $contextDiagnostics+='Evidencias mudaram: compare InputChanges e justifique EvidenceReview antes de confiar nas estimativas.'
        }
        if (@($data.EstimateEvidence | Where-Object { $_.Status -in @('AUSENTE','INVALIDA') }).Count) {
            $contextDiagnostics+='Arquivo usado para estimar esta ausente; confira EstimateEvidence.'
        }
        if ($contextDiagnostics.Count) {
            $data.State='RASCUNHO'
            foreach ($scenario in @($simulation,$simulation.Scenarios.Min,$simulation.Scenarios.Max)) {
                $scenario.Feasibility='NAO_AVALIAVEL';$scenario.State='RASCUNHO';$scenario.ProductionDate=$null
                $scenario.Diagnostics+=$contextDiagnostics
            }
            $simulation.Scenarios.Reference.Feasibility='NAO_AVALIAVEL';$simulation.Scenarios.Reference.ProductionDate=$null
        }
        $markdown=ConvertTo-SprintMarkdown $receipt $data ([IO.File]::ReadAllText($receipt.SprintPlanPath))
        $directory=Split-Path $receipt.ContextPath -Parent
        $scenario=Split-Path (Split-Path $directory -Parent) -Parent
        $pointer=Join-Path $scenario 'atual.json'
        if (Test-Path -LiteralPath $pointer) {
            $current=Get-Content -LiteralPath $pointer -Raw -Encoding UTF8 | ConvertFrom-Json
            if (-not $ancestors.Count -or $current.RevisionId -ne $ancestors[0].Receipt.RevisionId) { throw 'Outra revisao ja foi publicada; escolha sua base explicitamente antes de publicar.' }
        }
        if ((Get-FileHash -LiteralPath $receipt.SprintDataPath).Hash -cne $dataHash -or (Get-FileHash -LiteralPath $receipt.SprintPlanPath).Hash -cne $planHash) { throw 'Arquivos editados durante a validacao; tente novamente apos finalizar a edicao.' }
        Assert-SprintReferences $receipt $Root
        Assert-SprintReferences ([pscustomobject]@{References=$data.EstimateEvidence}) $Root
        # Recoverable writes: no pointer refers to this revision until both files and validation exist.
        Write-SprintJson $receipt.SprintDataPath $data
        [IO.File]::WriteAllText($receipt.SprintPlanPath,$markdown,(New-Object Text.UTF8Encoding($false)))
        $validation=[pscustomobject][ordered]@{SchemaVersion=1;Purpose='sprint-planning-validation';PlanningId=$receipt.PlanningId;RevisionId=$receipt.RevisionId;Status='VALIDATED';Feasibility=$simulation.Feasibility;CheckedAtUtc=[DateTime]::UtcNow.ToString('o');DataSha256=(Get-FileHash -LiteralPath $receipt.SprintDataPath).Hash;PlanSha256=(Get-FileHash -LiteralPath $receipt.SprintPlanPath).Hash;ContextSha256=(Get-FileHash -LiteralPath $receipt.ContextPath).Hash;Diagnostics=$simulation.Diagnostics;DataSnapshot=$data;SprintPlanPath=$receipt.SprintPlanPath;ContextPath=$receipt.ContextPath}
        $validation | Add-Member -NotePropertyName BaselineFrozen -NotePropertyValue ([bool]$data.Baseline.Known)
        Write-SprintJson $receipt.ValidationPath $validation
        Publish-SprintPointer $Root $receipt $validation
        $validation
    } finally { $lease.Dispose() }
}

Export-ModuleMember -Function Get-HarnessSprintSources,New-HarnessSprintContext,Read-HarnessSprintContext,Get-HarnessSprintHistory,Complete-HarnessSprintPlan,Get-HarnessSprintSimulation
