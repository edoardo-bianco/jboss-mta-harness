function Get-HarnessIssueProgressFiles {
    param($Project,[string]$Migration,[string]$Index)
    $progress=Get-HarnessIssueProgress -Rows @(Read-ProjectDecisionRows $Migration)
    $files=@{'migracao.md'=(Set-HarnessIssueProgressBlock $Migration (Get-HarnessIssueProgressText $progress $Project.MigrationPath $Project.MigrationPath))}
    if ($Index) {
        $indexText=Set-ProjectManagedBlock $Index 'issues:totais' (Get-HarnessMigrationCountText $Migration)
        $files['indice.md']=Set-HarnessIssueProgressBlock $indexText (Get-HarnessIssueProgressText $progress $Project.IndexPath $Project.MigrationPath)
    }
    $files
}

function Update-HarnessIssueProgress {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)]$Context,$RequiredProject)
    # Escopo explicito: nao descobrir projetos, catalogos nem fontes MTA.
    $projects=@(); $names=New-Object 'Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    foreach ($item in $Context.Projects) {
        $project=Get-HarnessProjectStorage $Context.Root (Join-Path $item.path 'pom.xml') -ReadCommitted
        if (-not $names.Add($project.Name)) { throw 'artifactId duplicado no escopo do recalculo.' }
        $projects+=$project
    }
    if ($RequiredProject -and @($projects | Where-Object Folder -IEQ $RequiredProject.Folder).Count -ne 1) { throw 'O escopo do recalculo nao inclui o projeto publicado.' }
    $warnings=@(); $rows=@(); $readProjects=@(); $missingProjects=@(); $summaries=@{}
    foreach ($project in $projects) {
        $lease=$null
        try {
            $lease=Enter-HarnessProjectAccess $project -ForOperation
            $old=Read-HarnessProjectFiles $project @('migracao.md','indice.md') -ReadCommitted
            if (-not $old['migracao.md']) { throw 'Registro ausente.' }
            $issueRows=@(Read-ProjectDecisionRows $old['migracao.md'])
            $summaries[$project.Name]=Get-HarnessIssueProgress -Rows $issueRows
            $files=Get-HarnessIssueProgressFiles $project $old['migracao.md'] $old['indice.md']
            foreach ($key in @($files.Keys)) { if ($files[$key] -ceq $old[$key]) { $files.Remove($key) } }
            if ($files.Count) { Publish-HarnessProjectFiles $project $files $old }
            if (-not $old['indice.md']) { $warnings+=($project.Name+': indice do projeto pendente; reconstruir pela Run Task existente.') }
            foreach ($row in $issueRows) {
                $row | Add-Member NoteProperty Project $project.Name
                $row | Add-Member NoteProperty MigrationPath $project.MigrationPath
            }
            $rows+=$issueRows; $readProjects+=$project.Name
        } catch {
            $summaries.Remove($project.Name); $missingProjects+=$project.Name
            $warnings+=($project.Name+': resumo pendente: '+$_.Exception.Message)
        } finally { if ($lease) { $lease.ReleaseMutex(); $lease.Dispose() } }
    }
    $index=Join-Path $Context.Root '.harness/indices/projetos.md'
    try { Update-HarnessWorkspaceProgress $Context.Root $projects $summaries $rows $readProjects $missingProjects $warnings }
    catch { $warnings+=('Dashboard pendente: '+$_.Exception.Message) }
    [pscustomobject]@{IndexPath=$index;Synchronized=($warnings.Count -eq 0);Warnings=@($warnings);Projects=@($projects)}
}

function Update-HarnessWorkspaceProgress {
    param([string]$Root,$Projects,$Summaries,$Rows,$ReadProjects,$MissingProjects,$Warnings)
    $folder=Resolve-ProjectPath '.harness/indices' $Root
    $storage=[pscustomobject]@{Folder=$folder;TemporaryPath=(Join-Path $folder 'temporarios')}
    $index=Join-Path $folder 'projetos.md'
    $lease=Enter-HarnessProjectAccess $storage -ReadCommitted
    try {
        $old=Read-HarnessProjectFiles $storage @('projetos.md') -ReadCommitted
        $text=$old['projetos.md']
        if (-not $text -or -not $text.Contains('| Andamento registrado |')) { throw 'Reconstrua o indice pela Run Task existente antes do recalculo documental.' }
        $lines=$text -split '(?<=\n)'
        $projectLines=@($lines | Where-Object { $_.StartsWith('| ') -and $_.Contains('<br>[POM]') })
        if ($projectLines.Count -ne $Projects.Count) { throw 'Escopo difere dos projetos do dashboard; informe o workspace completo ou reconstrua o indice.' }
        $manualCount=0
        foreach ($project in $Projects) {
            $pom=Get-HarnessSourceLink $index $project.Pom 'POM'
            $positions=@(for ($i=0;$i -lt $lines.Count;$i++) { if ($lines[$i].StartsWith('| ') -and $lines[$i].Contains('<br>'+$pom)) { $i } })
            if ($positions.Count -ne 1) { throw ('Projeto ausente/ambiguo no dashboard: '+$project.Name) }
            $position=$positions[0]; $cells=$lines[$position].TrimEnd() -split '\|'
            if ($cells.Count -ne 9) { throw 'Tabela do dashboard alterada; reconstruir antes do recalculo.' }
            $progress=$Summaries[$project.Name]
            $manual=if ($null -ne $progress) { @($Rows | Where-Object { $_.Project -ceq $project.Name -and $_.Presence -ceq 'MANUAL' }).Count } else { '-' }
            if ($manual -is [int]) { $manualCount+=$manual }
            $cells[3]=$cells[3] -replace 'Manuais: [0-9-]+ / -',('Manuais: '+$manual+' / -')
            $cells[4]=$cells[4] -replace '<br>manual: [0-9-]+ / -',('<br>manual: '+$manual+' / -')
            $cells[5]=' '+(Get-HarnessIssueProgressCompact $progress $index $project.MigrationPath)+' '
            $lines[$position]=($cells -join '|')+"`n"
        }
        $text=$lines -join ''
        $manualTotal=if ($ReadProjects.Count) { [string]$manualCount } else { '-' }
        $text=$text -replace '(?m)^\| manual \| [0-9-]+ \| - \|\r?$',('| manual | '+$manualTotal+' | - |')
        $coverage="Issues manuais registradas: $manualTotal, fora dos totais MTA. Registros legiveis: $($ReadProjects.Count) de $($Projects.Count) projetos."
        if ($MissingProjects.Count) { $coverage+=' Total manual parcial.' }
        $text=$text -replace '(?m)^Issues manuais registradas:[^\r\n]*',$coverage
        $content=Get-HarnessWorkspaceProgressText $Rows $ReadProjects $MissingProjects $index
        if ($Warnings.Count) { $content+="`n`nResumos locais pendentes:`n"+(@($Warnings | ForEach-Object { '- '+(ConvertTo-ProjectCell $_) }) -join "`n") }
        $text=Set-HarnessIssueProgressBlock $text $content
        if ($text -cne $old['projetos.md']) { Publish-HarnessProjectFiles $storage @{'projetos.md'=$text} $old }
    } finally { $lease.ReleaseMutex(); $lease.Dispose() }
}
