#requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'HarnessProject.psm1') -DisableNameChecking
Import-Module (Join-Path $PSScriptRoot 'HarnessPrioritization.psm1') -DisableNameChecking
Import-Module (Join-Path $PSScriptRoot 'HarnessMtaLocation.psm1') -DisableNameChecking

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
    $location=Get-HarnessMtaExternalLocation $Context $Project
    $lease=Enter-HarnessProjectAccess $Project -ForOperation
    try {
        $mta=Read-HarnessMtaDirectory $Project $location.Directory
        $association=Get-HarnessMtaExternalAssociationText $Project $location $old['projeto.json']
        Publish-HarnessProjectFiles $Project @{'projeto.json'=$association} @{'projeto.json'=$old['projeto.json']}
        return $mta
    } finally { $lease.ReleaseMutex(); $lease.Dispose() }
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
    $warnings=@(); $lines=@('# Projetos Maven','', 'Escolha o projeto; decisoes, plano e fontes ficam em seus caminhos correntes.','')
    foreach ($project in $projects) {
        $project=Initialize-HarnessProjectStorage $Context.Root $project.Pom
        $mta=$null; $limits=@()
        try { $mta=Read-ProjectIndexMta $Context $project } catch { $limits+=('MTA indisponivel: '+$_.Exception.Message) }
        Update-HarnessProjectDocuments $project -Mta $mta -UpdateIssues:$UpdateMigration -Warnings $limits
        $lines+='- '+(Get-HarnessSourceLink $index $project.IndexPath $project.Name)
        foreach ($limit in $limits) { $warnings+=($project.Name+': '+$limit) }
        if ($mta) { foreach ($limit in $mta.Diagnostics) { $warnings+=($project.Name+': '+$limit) } }
    }
    if ($warnings.Count) { $lines+=@('','Limites da leitura:')+@($warnings | ForEach-Object { '- '+($_ -replace '[\r\n]+',' ') }) }
    $prioritization=Update-HarnessPrioritizationIndex $Context.Root -RefreshSources
    $warnings+=@($prioritization.Warnings)
    if (Test-Path -LiteralPath $prioritization.IndexPath -PathType Leaf) { $lines+=@('',(Get-HarnessSourceLink $index $prioritization.IndexPath 'Priorizacoes correntes')) }
    Import-Module (Join-Path $PSScriptRoot 'HarnessSprintPlanning.psm1') -DisableNameChecking
    Update-HarnessSprintIndex $Context.Root
    $path=Publish-HarnessWorkspaceIndex $Context.Root (($lines -join "`n")+"`n")
    [pscustomobject]@{IndexPath=$path;Warnings=@($warnings);Projects=@($projects)}
}
Export-ModuleMember -Function New-HarnessProjectIndex
