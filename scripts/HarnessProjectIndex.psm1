#requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'HarnessProject.psm1') -DisableNameChecking
Import-Module (Join-Path $PSScriptRoot 'HarnessPrioritization.psm1') -DisableNameChecking
Import-Module (Join-Path $PSScriptRoot 'HarnessMtaLocation.psm1') -DisableNameChecking
Import-Module (Join-Path $PSScriptRoot 'HarnessDocumentTemplates.psm1') -DisableNameChecking

function Read-ProjectIndexMta {
    param($Context,$Project)
    $old=Read-HarnessProjectFiles $Project @('projeto.json')
    $config=ConvertFrom-Json $old['projeto.json']
    if ($config.mta.diretorio) { return Read-HarnessProjectMta $Project }
    # Keep historical internal diagnostics readable when no external root was chosen.
    $configured=$Context.PSObject.Properties['Config'] -and $Context.Config -and
        $Context.Config.PSObject.Properties['mta'] -and $Context.Config.mta -and
        $Context.Config.mta.PSObject.Properties['runsPath'] -and $Context.Config.mta.runsPath
    if (-not $configured -and (Test-Path -LiteralPath (Join-Path $Project.Folder 'atual/diagnosticos/mta'))) {
        return Read-HarnessProjectMta $Project
    }
    $lease=Enter-HarnessProjectAccess $Project -ForOperation
    try {
        try {
            $location=Get-HarnessMtaExternalLocation $Context $Project
            $mta=Read-HarnessMtaDirectory $Project $location.Directory
        } catch {
            $externalFailure=$_.Exception.Message
            if (-not (Test-Path -LiteralPath (Join-Path $Project.Folder 'atual/diagnosticos/mta'))) { throw }
            $access=Enter-HarnessProjectAccess $Project
            try {
                $current=Read-HarnessProjectFiles $Project @('projeto.json')
                if ($current['projeto.json'] -cne $old['projeto.json']) { throw 'Associacao MTA editada durante a descoberta externa; atualize novamente o indice.' }
                $mta=Read-HarnessProjectMta $Project
                $mta.Diagnostics+=('Origem externa ainda nao associada: '+$externalFailure+' Diagnostico interno historico mantido: '+$mta.ReportPath)
                return $mta
            } finally { $access.ReleaseMutex(); $access.Dispose() }
        }
        $association=Get-HarnessMtaExternalAssociationText $Project $location $old['projeto.json']
        Publish-HarnessProjectFiles $Project @{'projeto.json'=$association} @{'projeto.json'=$old['projeto.json']}
        return $mta
    } finally { $lease.ReleaseMutex(); $lease.Dispose() }
}

function Get-ProjectSummaryRow {
    param($Project,$Mta,[string]$Index)
    $report='Indisponivel'; $counts='-'; $categories='-'
    if ($Mta) {
        $report=Get-HarnessSourceLink $Index $Mta.ReportPath ($Mta.DateUtc.ToString('yyyy-MM-dd HH:mm:ss'))
        $occurrences=0; foreach ($issue in $Mta.Issues) { $occurrences+=$issue.Count }
        $counts=(@($Mta.Issues).Count.ToString()+' / '+$occurrences)
        $categories=(@($Mta.Issues | Group-Object Category -CaseSensitive | Sort-Object Name | ForEach-Object {
            $sum=0; foreach ($issue in $_.Group) { $sum+=$issue.Count }
            (ConvertTo-ProjectCell $_.Name)+': '+$_.Count+' / '+$sum
        }) -join '<br>')
        if (-not $categories) { $categories='Sem issues' }
    }
    $read=Read-HarnessProjectFiles $Project @('atual/operacao.json')
    $attempts=@()
    if ($read['atual/operacao.json']) {
        $operations=ConvertFrom-Json $read['atual/operacao.json']
        foreach ($entry in @($operations.PSObject.Properties | Sort-Object Name)) {
            $state=$entry.Value
            $label=ConvertTo-ProjectCell ($entry.Name+': '+$state.Status)
            if ($state.LogPath -and (Test-Path -LiteralPath $state.LogPath -PathType Leaf)) {
                $label=Get-HarnessSourceLink $Index $state.LogPath $label
            }
            $attempts+=($label+' ('+(ConvertTo-ProjectCell $state.DateUtc)+')')
        }
    }
    if (-not $attempts.Count) { $attempts=@('Sem tentativa registrada') }
    $documents=@()
    foreach ($entry in @(
        @('migracao.md','Registro'),@('atual/planejamento/plano.md','Plano'),
        @('atual/planejamento/tarefas.md','Tarefas'),@('atual/planejamento/planejar-lotes.prompt.md','Preparo'),
        @('evidencias/LEIA-ME.md','Evidencias'),@('atual/diagnosticos/sonar/RESUMO.md','Sonar'))) {
        $path=Join-Path $Project.Folder $entry[0]
        if (Test-Path -LiteralPath $path -PathType Leaf) { $documents+=Get-HarnessSourceLink $Index $path $entry[1] }
    }
    if (-not (Test-Path -LiteralPath $Project.PlanPath -PathType Leaf) -and -not (Test-Path -LiteralPath $Project.TodoPath -PathType Leaf)) { $documents+='Proposta ausente' }
    $projectLink=(Get-HarnessSourceLink $Index $Project.IndexPath (ConvertTo-ProjectCell $Project.Name))+'<br>'+(Get-HarnessSourceLink $Index $Project.Pom 'POM')
    '| '+(@($projectLink,$report,$counts,$categories,($attempts -join '<br>'),($documents -join '<br>')) -join ' | ')+' |'
}


function New-HarnessProjectIndex {
    param($Context,[switch]$UpdateMigration)
    $index=Join-Path $Context.Root '.harness/indices/projetos.md'
    $projects=@(); $names=@{}
    # Resolve the complete scope before creating any project association.
    foreach ($item in $Context.Projects) {
        $project=Get-HarnessProjectStorage $Context.Root (Join-Path $item.path 'pom.xml')
        if ($names.ContainsKey($project.Name)) { throw "artifactId duplicado no escopo: $($project.Name). Use outra raiz para o projeto distinto." }
        $names[$project.Name]=$true; $projects+=$project
    }
    $warnings=@(); $rows=@(); $available=0; $issueCount=0; $occurrenceCount=0
    foreach ($project in $projects) {
        $project=Initialize-HarnessProjectStorage $Context.Root $project.Pom
        $mta=$null; $limits=@()
        try { $mta=Read-ProjectIndexMta $Context $project } catch { $limits+=('MTA indisponivel: '+$_.Exception.Message) }
        Update-HarnessProjectDocuments $project -Mta $mta -UpdateIssues:$UpdateMigration -Warnings $limits
        $rows+=Get-ProjectSummaryRow $project $mta $index
        if ($mta) { $available++; $issueCount+=@($mta.Issues).Count; foreach ($issue in $mta.Issues) { $occurrenceCount+=$issue.Count } }
        foreach ($limit in $limits) { $warnings+=($project.Name+': '+$limit) }
        if ($mta) { foreach ($limit in $mta.Diagnostics) { $warnings+=($project.Name+': '+$limit) } }
    }
    $prioritization=Update-HarnessPrioritizationIndex $Context.Root -RefreshSources
    $warnings+=@($prioritization.Warnings)
    Import-Module (Join-Path $PSScriptRoot 'HarnessSprintPlanning.psm1') -DisableNameChecking
    Update-HarnessSprintIndex $Context.Root
    if (-not $rows.Count) { $rows=@('| Nenhum projeto Maven no escopo. | - | - | - | - | - |') }
    $values=@{
        UpdatedAt=[DateTime]::UtcNow.ToString('yyyy-MM-dd HH:mm:ss')
        ProjectRows=($rows -join [Environment]::NewLine)
        Coverage="MTA utilizavel: $available de $($projects.Count) projetos. Totais conhecidos: $issueCount issues / $occurrenceCount ocorrencias."
        Warnings=if ($warnings.Count) { (@($warnings | ForEach-Object { '- '+(ConvertTo-ProjectCell $_) }) -join [Environment]::NewLine) } else { 'Nenhuma lacuna identificada nesta leitura.' }
        Prioritization=if (Test-Path -LiteralPath $prioritization.IndexPath -PathType Leaf) { Get-HarnessSourceLink $index $prioritization.IndexPath 'Priorizacoes correntes' } else { 'Nenhuma priorizacao corrente disponivel.' }
    }
    $path=Publish-HarnessWorkspaceIndex $Context.Root (Expand-HarnessDocumentTemplate 'indice-projetos' $values)
    [pscustomobject]@{IndexPath=$path;Warnings=@($warnings);Projects=@($projects)}
}
Export-ModuleMember -Function New-HarnessProjectIndex
