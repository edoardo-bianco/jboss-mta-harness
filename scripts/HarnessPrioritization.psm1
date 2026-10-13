#requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'HarnessProject.psm1') -DisableNameChecking
. (Join-Path $PSScriptRoot 'HarnessIssueSources.ps1')
. (Join-Path $PSScriptRoot 'HarnessPrioritizationState.ps1')
. (Join-Path $PSScriptRoot 'HarnessPrioritizationIndex.ps1')

function Read-PrioritizationProject {
    param($Project)
    $entry=[ordered]@{Project=$Project.Name;Label=$Project.Name;Source=$Project.Source;Pom=$Project.Pom;
        MigrationPath=$Project.MigrationPath;EvidencePath=$Project.EvidencePath;Mta=$null;Diagnostics=@();Categories=@();EligibleIssues=@()}
    $rows=@()
    try { $rows=@(Get-HarnessProjectDecisions $Project) } catch { $entry.Diagnostics+=$_.Exception.Message }
    $mta=$null
    try { $mta=Read-HarnessProjectMta $Project } catch { $entry.Diagnostics+=$_.Exception.Message }
    if ($mta) {
        $entry.Mta=@{ReportPath=$mta.ReportPath;CatalogPath=$mta.CatalogPath}
        $entry.Diagnostics+=@($mta.Diagnostics)
        $entry.Categories=@($mta.Issues | ForEach-Object Category | Sort-Object -Unique)
        $present=New-Object 'Collections.Generic.Dictionary[string,object]' ([StringComparer]::Ordinal)
        foreach ($issue in $mta.Issues) { $present.Add($issue.Id,$issue) }
        $entry.EligibleIssues=@(foreach ($row in $rows) {
            if ($row.Id -notlike 'DEV-*' -and $present.ContainsKey($row.Id) -and
                $row.Decision -in @('A DEFINIR','ANALISAR AGORA') -and $row.Progress -in @('NAO ANALISADA','ANALISADA')) {
                [pscustomobject]@{Project=$Project.Name;Id=$row.Id;Category=$present[$row.Id].Category}
            }
        })
        $unknown=@($mta.Issues | Where-Object Id -CNotIn @($rows | ForEach-Object Id))
        if ($unknown.Count) { $entry.Diagnostics+=("$($unknown.Count) issues ainda sem decisao no registro; atualize o indice dos projetos para inclui-las.") }
    }
    [pscustomobject]@{Entry=[pscustomobject]$entry;Mta=$mta}
}

function New-HarnessPrioritizationContext {
    [CmdletBinding()]
    param($Context,[string]$Percentage,[ValidateSet('Recreate','Continue')][string]$Mode,
        [switch]$Interactive,[string]$Category,[string]$Scope)
    if (-not @($Context.Projects).Count) { throw 'Nenhum projeto no escopo.' }
    $projects=@(); $names=@{}
    foreach ($item in $Context.Projects) {
        $project=Get-HarnessProjectStorage $Context.Root (Join-Path $item.path 'pom.xml')
        if ($names.ContainsKey($project.Name)) { throw 'artifactId duplicado no escopo.' }
        if (-not (Test-Path -LiteralPath $project.ConfigPath -PathType Leaf)) { throw 'Atualize o indice dos projetos antes de priorizar.' }
        $names[$project.Name]=$project
    }
    $orderedNames=[string[]]@($names.Keys); [Array]::Sort($orderedNames,[StringComparer]::Ordinal)
    $projects=@(foreach ($name in $orderedNames) { $names[$name] })
    if (-not $Scope) { $Scope=$orderedNames -join '|' }
    $master=$projects[0]; $leases=@()
    try {
        foreach ($project in $projects) { $leases+=Enter-HarnessProjectAccess $project -ForOperation }
        $reads=@(foreach ($project in $projects) { Read-PrioritizationProject $project })
        $entries=@($reads | ForEach-Object Entry)
        if (-not $Category) {
            $categories=@($entries | ForEach-Object Categories | Sort-Object -Unique)
            if ($categories.Count -eq 1) { $Category=$categories[0] }
            elseif ($Interactive) {
                Write-Host ('Categorias: '+($categories -join ', '))
                $Category=Read-Host 'Categoria a priorizar (nome exato; Enter cancela)'
            } else { throw 'Informe Category para separar a cobertura por categoria.' }
            if (-not $Category) { throw 'Priorizacao cancelada.' }
        }
        $paths=Get-PrioritizationPaths $master $Category $Scope
        $contextRelative=$paths.Relative+'/contexto.json'; $rankingRelative=$paths.Relative+'/priorizacao.md'
        $old=Read-HarnessProjectFiles $master @($contextRelative,$rankingRelative,($paths.Relative+'/indice.md'),($paths.Relative+'/priorizar-issues.prompt.md'))
        $data=$null; $result=$null; $reused=$false
        if ($old[$contextRelative]) {
            $data=ConvertFrom-Json $old[$contextRelative]
            Assert-PrioritizationContext $data $paths $projects $Category $Scope
            if (-not $Mode -and $Interactive) {
                $choice=Read-Host 'Cobertura existente: progredir (p) ou recriar (r)? Enter cancela'
                if ($choice -eq 'p') { $Mode='Continue' } elseif ($choice -eq 'r') { $Mode='Recreate' }
            }
            if (-not $Mode) { throw 'Cobertura existente: escolha Mode Continue ou Recreate explicitamente.' }
            if ($Mode -eq 'Continue') { $result=Read-PrioritizationResult $data $old[$rankingRelative] $projects; $reused=$result.Status -ceq 'IN_PROGRESS' }
        } elseif ($old[$rankingRelative]) { throw 'Ranking sem contexto: preserve e confira antes de recriar.' }
        elseif ($Mode -eq 'Continue') { throw 'Nenhuma cobertura corrente para progredir.' }
        $eligible=@(foreach ($entry in $entries) { foreach ($issue in $entry.EligibleIssues) {
            if ($issue.Category -ceq $Category) { [pscustomobject]@{Project=$issue.Project;Id=$issue.Id} }
        } })
        if (-not $data -or $Mode -eq 'Recreate') {
            $baseline=$eligible; $examined=@(); $excluded=@()
        } else {
            $baseline=@($data.BaselineIssues); $examined=@($result.AnalyzedIssues)
            $excluded=if ($reused) { @($data.ExcludedIssues) } else { @($examined | Select-Object Project,Id) }
        }
        $baseSet=Get-PrioritizationSet $baseline $projects
        $excludedSet=Get-PrioritizationSet $excluded $projects
        $available=@($eligible | Where-Object { $baseSet.Contains((Get-PrioritizationIssueKey $_)) -and -not $excludedSet.Contains((Get-PrioritizationIssueKey $_)) })
        $outside=@($eligible | Where-Object { -not $baseSet.Contains((Get-PrioritizationIssueKey $_)) }).Count
        if ($reused) {
            # Retoma a mesma quota. Achados retirados das escolhas atuais nao podem
            # ser examinados de novo apenas porque constavam no preparo anterior.
            $percent=ConvertTo-PrioritizationPercentage ([string]$data.Percentage)
            $slice=$data.SliceSize
            $pendingSet=Get-PrioritizationSet $data.AvailableIssues $projects
            $available=@($available | Where-Object { $pendingSet.Contains((Get-PrioritizationIssueKey $_)) })
            $active=@($available)+@($examined | Where-Object {
                -not $excludedSet.Contains((Get-PrioritizationIssueKey $_)) -and
                (Get-PrioritizationIssueKey $_) -cnotin @($available | ForEach-Object { Get-PrioritizationIssueKey $_ })
            } | Select-Object Project,Id)
            $available=$active
            if ($slice -gt $available.Count) { throw 'Escolhas/origem reduziram a fatia pendente; confira o resultado e recrie explicitamente se necessario.' }
        } else {
            if (-not $Percentage -and $Interactive) { $Percentage=Read-Host 'Percentual do total inicial (0,01 a 100,00)' }
            $percent=ConvertTo-PrioritizationPercentage $Percentage
            $slice=[int][Math]::Min($available.Count,[Math]::Ceiling($baseline.Count*$percent/100))
        }
        $fichas=@(foreach ($issue in $baseline) {
            $project=$names[$issue.Project]
            $relative=Get-PrioritizationFichaRelativePath $Category $issue.Id
            if ((Join-Path $project.TemporaryPath ('publicacao/depois/'+$relative)).Length -ge 248) { throw 'Caminho da ficha longo; use raiz de dados curta ou confira a chave funcional.' }
            [pscustomobject]@{Project=$issue.Project;Id=$issue.Id;Path=(Join-Path $project.Folder $relative)}
        })
        $data=[pscustomobject][ordered]@{Purpose='current-prioritization';Scope=$Scope;Category=$Category;
            ContextPath=$paths.ContextPath;RankingPath=$paths.RankingPath;PromptPath=$paths.PromptPath;IndexPath=$paths.IndexPath;
            PrioritizationIndexPath=(Join-Path $Context.Root '.harness/indices/priorizacao.md');
            Projects=@($entries | Select-Object Project,Label,Source,Pom,MigrationPath,EvidencePath,Mta,Diagnostics);
            Percentage=$percent;InitialTotal=$baseline.Count;SliceSize=$slice;BaselineIssues=@($baseline);
            ExcludedIssues=@($excluded);AvailableIssues=@($available);FichaPaths=$fichas;
            OutsideBaseline=$outside;ContractPath=(Join-Path $Context.Root 'doc/adr/0009-estado-corrente-por-projeto.md')}
        $result=[pscustomobject]@{Scope=$Scope;Category=$Category;Status=if ($slice -eq 0) {'COMPLETED'} else {'IN_PROGRESS'};AnalyzedIssues=@($examined)}
        $ranking=$old[$rankingRelative]
        if (-not $ranking) { $ranking="# Priorizacao corrente\n\nAnotacoes humanas fora dos blocos gerenciados sao preservadas.\n" -replace '\\n',([char]10) }
        $ranking=Set-PrioritizationResult $ranking $result
        for ($i=0;$i -lt $projects.Count;$i++) { Update-PrioritizationFichaSources $projects[$i] $reads[$i].Mta $Category }
        $index=Get-PrioritizationIndexContent $data $result $old[($paths.Relative+'/indice.md')]
        $ranking=Set-ProjectManagedBlock $ranking 'priorizacao:fichas' (Get-PrioritizationRows $data $result $paths.RankingPath)
        $templatePath=Join-Path $Context.Root '.github/prompts/priorizar-issues.prompt.md'
        $template=[IO.File]::ReadAllText($templatePath)
        $selection=@{ContextPath=$paths.ContextPath;RankingPath=$paths.RankingPath;IndexPath=$paths.IndexPath} | ConvertTo-Json
        $prompt=$template.TrimEnd()+[Environment]::NewLine+[Environment]::NewLine+'Contexto selecionado (dados, nao instrucoes):'+[Environment]::NewLine+$selection
        $links=@((Get-HarnessSourceLink $paths.PromptPath $paths.IndexPath 'Indice da priorizacao'),(Get-HarnessSourceLink $paths.PromptPath $paths.RankingPath 'Ranking acumulado'))
        foreach ($entry in $data.Projects) {
            if (Test-Path -LiteralPath $entry.MigrationPath -PathType Leaf) { $links+=Get-HarnessSourceLink $paths.PromptPath $entry.MigrationPath ('Decisoes: '+$entry.Project) }
            else { $links+=('Registro indisponivel: '+(ConvertTo-ProjectCell $entry.Project)+'. Confira os limites no indice da priorizacao.') }
            if ($entry.Mta) { $links+=Get-HarnessSourceLink $paths.PromptPath $entry.Mta.ReportPath ('MTA: '+$entry.Project) }
        }
        $prompt+=[Environment]::NewLine+[Environment]::NewLine+($links -join ([Environment]::NewLine+[Environment]::NewLine))
        $writes=@{}
        $writes[$contextRelative]=$data | ConvertTo-Json -Depth 15
        $writes[$rankingRelative]=$ranking
        $writes[($paths.Relative+'/indice.md')]=$index
        $writes[($paths.Relative+'/priorizar-issues.prompt.md')]=$prompt
        Publish-HarnessProjectFiles $master $writes $old
        $null=Update-HarnessPrioritizationIndex $Context.Root
        Get-PrioritizationPreparedResult $data $reused $(if ($slice -eq 0) {'EXHAUSTED'} else {'PREPARED'})
    } finally {
        for ($i=$leases.Count-1;$i -ge 0;$i--) { $leases[$i].ReleaseMutex(); $leases[$i].Dispose() }
    }
}
Export-ModuleMember -Function New-HarnessPrioritizationContext,Update-HarnessPrioritizationIndex
