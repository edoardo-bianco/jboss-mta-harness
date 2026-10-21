#requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'HarnessProject.psm1') -DisableNameChecking
Import-Module (Join-Path $PSScriptRoot 'HarnessPrioritization.psm1') -DisableNameChecking
Import-Module (Join-Path $PSScriptRoot 'HarnessMtaLocation.psm1') -DisableNameChecking
Import-Module (Join-Path $PSScriptRoot 'HarnessDocumentTemplates.psm1') -DisableNameChecking

function Read-ProjectIndexMta {
    param($Context,$Project)
    $old=Read-HarnessProjectFiles $Project @('projeto.json') -ReadCommitted
    $configText=$old['projeto.json']
    if (-not $configText) { $configText=[ordered]@{pom=$Project.Pom;mta=[ordered]@{diretorio=$null}} | ConvertTo-Json }
    $config=ConvertFrom-Json $configText
    $result=[pscustomobject]@{Mta=$null;Association=$null;Previous=$old['projeto.json'];Configuration=$configText}
    if ($config.mta.diretorio) {
        $result.Mta=Read-HarnessMtaDirectory $Project $config.mta.diretorio
        return $result
    }
    # Keep historical internal diagnostics readable when no external root was chosen.
    $configured=$Context.PSObject.Properties['Config'] -and $Context.Config -and
        $Context.Config.PSObject.Properties['mta'] -and $Context.Config.mta -and
        $Context.Config.mta.PSObject.Properties['runsPath'] -and $Context.Config.mta.runsPath
    if (-not $configured -and (Test-Path -LiteralPath (Join-Path $Project.Folder 'atual/diagnosticos/mta'))) {
        $result.Mta=Read-HarnessMtaDirectory $Project (Join-Path $Project.Folder 'atual/diagnosticos/mta')
        return $result
    }
    try {
        $location=Get-HarnessMtaExternalLocation $Context $Project
        $result.Mta=Read-HarnessMtaDirectory $Project $location.Directory
    } catch {
        $externalFailure=$_.Exception.Message
        if (-not (Test-Path -LiteralPath (Join-Path $Project.Folder 'atual/diagnosticos/mta'))) { throw }
        $result.Mta=Read-HarnessMtaDirectory $Project (Join-Path $Project.Folder 'atual/diagnosticos/mta')
        $result.Mta.Diagnostics+=('Origem externa ainda nao associada: '+$externalFailure+' Diagnostico interno historico mantido: '+$result.Mta.ReportPath)
        return $result
    }
    $result.Association=Get-HarnessMtaExternalAssociationText $Project $location $configText
    $result
}

function Get-ProjectSummaryRow {
    param($Project,$Mta,[string]$Index,[Collections.Generic.List[string]]$LocalWarnings)
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
    $attempts=@()
    try {
        $read=Read-HarnessProjectFiles $Project @('atual/operacao.json') -ReadCommitted
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
    } catch { $LocalWarnings.Add('Leitura das operacoes locais falhou: '+$_.Exception.Message); $attempts=@('Leitura local indisponivel') }
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
    if ($LocalWarnings.Count) { $documents+='Atualizacao local pendente' }
    $projectLabel=ConvertTo-ProjectCell $Project.Name
    $projectLink=if (Test-Path -LiteralPath $Project.IndexPath -PathType Leaf) { Get-HarnessSourceLink $Index $Project.IndexPath $projectLabel } else { $projectLabel }
    $projectLink+='<br>'+(Get-HarnessSourceLink $Index $Project.Pom 'POM')
    '| '+(@($projectLink,$report,$counts,$categories,($attempts -join '<br>'),($documents -join '<br>')) -join ' | ')+' |'
}


function New-HarnessProjectIndex {
    param($Context,[switch]$UpdateMigration)
    $index=Join-Path $Context.Root '.harness/indices/projetos.md'
    $projects=@(); $names=@{}
    # Resolve the complete scope before creating any project association.
    foreach ($item in $Context.Projects) {
        $pom=Join-Path $item.path 'pom.xml'
        try { $project=Get-HarnessProjectStorage $Context.Root $pom -ReadCommitted }
        catch {
            # A real journal must be recovered before its association can be
            # trusted. No fallback to another origin or bypass of a conflict.
            $project=Get-HarnessProjectStorage $Context.Root $pom
        }
        if ($names.ContainsKey($project.Name)) { throw "artifactId duplicado no escopo: $($project.Name). Use outra raiz para o projeto distinto." }
        $names[$project.Name]=$true; $projects+=$project
    }
    $warnings=@(); $rows=@(); $available=0; $issueCount=0; $occurrenceCount=0
    $categoryTotals=New-Object 'Collections.Generic.Dictionary[string,object]' ([StringComparer]::Ordinal)
    foreach ($project in $projects) {
        $mta=$null; $reading=$null; $limits=@()
        $localWarnings=New-Object 'Collections.Generic.List[string]'
        try {
            $reading=Read-ProjectIndexMta $Context $project
            $current=Read-HarnessProjectFiles $project @('projeto.json') -ReadCommitted
            if ($current['projeto.json'] -cne $reading.Previous) { throw 'Associacao MTA editada durante a leitura; atualize novamente o indice.' }
            $mta=$reading.Mta
        } catch { $reading=$null; $limits+=('MTA indisponivel: '+$_.Exception.Message) }
        try {
            if ($reading -and $reading.Association) {
                $lease=Enter-HarnessProjectAccess $project -ForOperation
                try { Publish-HarnessProjectFiles $project @{'projeto.json'=$reading.Association} @{'projeto.json'=$reading.Previous} }
                finally { $lease.ReleaseMutex(); $lease.Dispose() }
            } else { $null=Initialize-HarnessProjectStorage $Context.Root $project.Pom }
            $expected=@{}
            if ($reading) {
                $expected['projeto.json']=if ($reading.Association) { $reading.Association } else { $reading.Configuration }
            }
            Update-HarnessProjectDocuments $project -Mta $mta -UpdateIssues:$UpdateMigration -Warnings $limits -Expected $expected
        } catch { $localWarnings.Add($_.Exception.Message) }
        $rows+=Get-ProjectSummaryRow $project $mta $index $localWarnings
        if ($mta) {
            $available++; $issueCount+=@($mta.Issues).Count
            foreach ($issue in $mta.Issues) {
                $occurrenceCount+=$issue.Count
                $category=[string]$issue.Category
                if (-not $categoryTotals.ContainsKey($category)) {
                    $categoryTotals.Add($category,[pscustomobject]@{Issues=0;Occurrences=0})
                }
                $categoryTotals[$category].Issues++
                $categoryTotals[$category].Occurrences+=$issue.Count
            }
        }
        foreach ($limit in $limits) { $warnings+=($project.Name+': '+$limit) }
        foreach ($limit in $localWarnings) { $warnings+=($project.Name+': Atualizacao local pendente: '+$limit) }
        if ($mta) { foreach ($limit in $mta.Diagnostics) { $warnings+=($project.Name+': '+$limit) } }
    }
    $prioritizationPath=Join-Path $Context.Root '.harness/indices/priorizacao.md'
    try {
        $prioritization=Update-HarnessPrioritizationIndex $Context.Root -RefreshSources
        $prioritizationPath=$prioritization.IndexPath
        $warnings+=@($prioritization.Warnings)
    } catch { $warnings+=('Atualizacao local pendente nas priorizacoes: '+$_.Exception.Message) }
    Import-Module (Join-Path $PSScriptRoot 'HarnessSprintPlanning.psm1') -DisableNameChecking
    try { Update-HarnessSprintIndex $Context.Root } catch { $warnings+=('Atualizacao local pendente nos sprints: '+$_.Exception.Message) }
    if (-not $rows.Count) { $rows=@('| Nenhum projeto Maven no escopo. | - | - | - | - | - |') }
    $categoryRows=@($categoryTotals.Keys | Sort-Object -CaseSensitive | ForEach-Object {
        $label=if ([string]::IsNullOrWhiteSpace($_)) { 'Sem categoria informada' } else { ConvertTo-ProjectCell $_ }
        '| '+$label+' | '+$categoryTotals[$_].Issues+' | '+$categoryTotals[$_].Occurrences+' |'
    })
    if (-not $categoryRows.Count) {
        $categoryRows=@(if ($available) { '| Sem issues no MTA utilizavel | 0 | 0 |' } else { '| Indisponivel: nenhum MTA utilizavel | - | - |' })
    }
    $knownTotals=if ($available) { "$issueCount issues / $occurrenceCount ocorrencias" } else { 'indisponiveis' }
    $values=@{
        UpdatedAt=[DateTime]::UtcNow.ToString('yyyy-MM-dd HH:mm:ss')
        ProjectRows=($rows -join [Environment]::NewLine)
        Coverage="MTA utilizavel: $available de $($projects.Count) projetos. Totais conhecidos: $knownTotals."
        CategoryRows=($categoryRows -join [Environment]::NewLine)
        Warnings=if ($warnings.Count) { (@($warnings | ForEach-Object { '- '+(ConvertTo-ProjectCell $_) }) -join [Environment]::NewLine) } else { 'Nenhuma lacuna identificada nesta leitura.' }
        Prioritization=if (Test-Path -LiteralPath $prioritizationPath -PathType Leaf) { Get-HarnessSourceLink $index $prioritizationPath 'Priorizacoes correntes' } else { 'Nenhuma priorizacao corrente disponivel.' }
    }
    $path=Publish-HarnessWorkspaceIndex $Context.Root (Expand-HarnessDocumentTemplate 'indice-projetos' $values)
    [pscustomobject]@{IndexPath=$path;Warnings=@($warnings);Projects=@($projects)}
}
Export-ModuleMember -Function New-HarnessProjectIndex
