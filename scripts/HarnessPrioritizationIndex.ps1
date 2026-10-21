function Get-PrioritizationRows {
    param($Data,$Result,[string]$From)
    $lines=@('| Posicao | Projeto | Issue / ficha | Motivo |','| --- | --- | --- | --- |')
    foreach ($issue in @($Result.AnalyzedIssues | Sort-Object @{Expression={if ($null -eq $_.Position) {[int]::MaxValue} else {$_.Position}}},Project,Id)) {
        $ficha=@($Data.FichaPaths | Where-Object { $_.Project -ceq $issue.Project -and $_.Id -ceq $issue.Id })
        if ($ficha.Count -ne 1) { throw 'Destino de ficha ausente/duplicado no contexto.' }
        $position=if ($null -eq $issue.Position) {'Sem posicao'} else {[string]$issue.Position}
        $lines+='| '+$position+' | '+(ConvertTo-ProjectCell $issue.Project)+' | '+(Get-HarnessSourceLink $From $ficha[0].Path (ConvertTo-ProjectCell $issue.Id))+' | '+(ConvertTo-ProjectCell $issue.Reason)+' |'
    }
    $lines -join [Environment]::NewLine
}

function Get-PrioritizationNextStep {
    param($Data,[string]$From)
    $links=@(foreach ($project in $Data.Projects) {
        if (Test-Path -LiteralPath $project.MigrationPath -PathType Leaf) {
            '- '+(Get-HarnessSourceLink $From $project.MigrationPath (ConvertTo-ProjectCell ($project.Project+': registro')))
        } else { '- Registro indisponivel: '+(ConvertTo-ProjectCell $project.Project)+'. Atualize o indice dos projetos.' }
    })
    Expand-HarnessDocumentTemplate 'orientacao-priorizacao' @{MigrationLinks=($links -join [Environment]::NewLine)}
}

function Merge-PrioritizationDocument {
    param([string]$Name,$Values,[string]$Text,[string[]]$Blocks)
    $rendered=Expand-HarnessDocumentTemplate $Name $Values
    if (-not $Text) { return $rendered }
    foreach ($name in $Blocks) {
        $block=Find-ProjectManagedBlock $rendered $name
        if (-not $block) { throw "Template $Name sem bloco $name." }
        $body=($block.Value -split '\r?\n' | Select-Object -Skip 1 | Select-Object -SkipLast 1) -join [Environment]::NewLine
        $Text=Set-ProjectManagedBlock $Text $name $body
    }
    $Text
}

function Get-PrioritizationRankingContent {
    param($Data,$Result,[string]$Text)
    $values=@{
        Scope=(ConvertTo-ProjectCell $Data.Scope);Category=(ConvertTo-ProjectCell $Data.Category)
        Examined=@($Result.AnalyzedIssues).Count;InitialTotal=$Data.InitialTotal;Status=$Result.Status
        ResultJson=($Result | ConvertTo-Json -Depth 10)
        Rows=(Get-PrioritizationRows $Data $Result $Data.RankingPath)
        NextStep=(Get-PrioritizationNextStep $Data $Data.RankingPath)
    }
    Merge-PrioritizationDocument 'priorizacao' $values $Text @('priorizacao:resultado','priorizacao:fichas','priorizacao:orientacao')
}

function Get-PrioritizationIndexContent {
    param($Data,$Result,[string]$Text)
    $values=@{
        Scope=(ConvertTo-ProjectCell $Data.Scope);Category=(ConvertTo-ProjectCell $Data.Category)
        Examined=@($Result.AnalyzedIssues).Count;InitialTotal=$Data.InitialTotal;Status=$Result.Status
        OutsideBaseline=if ($null -eq $Data.OutsideBaseline) {'nao informado; conferir origem atual'} else {[string]$Data.OutsideBaseline}
        RankingLink=(Get-HarnessSourceLink $Data.IndexPath $Data.RankingPath 'Ranking acumulado')
        PromptLink=(Get-HarnessSourceLink $Data.IndexPath $Data.PromptPath 'Orientacao da priorizacao')
        ContractLink=(Get-HarnessSourceLink $Data.IndexPath $Data.ContractPath 'Contrato')
        Rows=(Get-PrioritizationRows $Data $Result $Data.IndexPath)
        Diagnostics=(@(foreach ($project in $Data.Projects) { foreach ($diagnostic in $project.Diagnostics) { ConvertTo-ProjectCell ($project.Project+': '+$diagnostic) } }) -join [Environment]::NewLine)
        NextStep=(Get-PrioritizationNextStep $Data $Data.IndexPath)
    }
    Merge-PrioritizationDocument 'indice-priorizacao' $values $Text @('priorizacao:indice')
}
function Update-HarnessPrioritizationIndex {
    param([string]$Root,[switch]$RefreshSources)
    $base=Join-Path $Root '.harness/projetos'
    $globalFolder=Join-Path $Root '.harness/indices'
    $destination=[pscustomobject]@{Folder=$globalFolder;TemporaryPath=(Join-Path $globalFolder 'temporarios')}
    $globalPath=Join-Path $globalFolder 'priorizacao.md'
    $globalOld=Read-HarnessProjectFiles $destination @('priorizacao.md')
    $lines=@(); $warnings=@(); $links=@{}; $stores=@{}; $mtas=@{}; $refreshed=@{}
    if (Test-Path -LiteralPath $base -PathType Container) {
        foreach ($folder in Get-ChildItem -LiteralPath $base -Directory) {
            $configPath=Join-Path $folder.FullName 'projeto.json'
            if (-not (Test-Path -LiteralPath $configPath -PathType Leaf)) { continue }
            try {
                $config=Get-Content -LiteralPath $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
                $project=Get-HarnessProjectStorage $Root $config.pom
                $stores[$project.Name]=$project; $links[$project.Name]=@()
            } catch {
                $warnings+=($folder.Name+': '+$_.Exception.Message)
                $lines+='- Associacao indisponivel: '+(Get-HarnessSourceLink $globalPath $configPath $folder.Name)+'. '+(ConvertTo-ProjectCell $_.Exception.Message)
            }
        }
    }
    foreach ($master in @($stores.Values | Sort-Object Name)) {
        $directory=Join-Path $master.Folder 'atual/priorizacao'
        if (-not (Test-Path -LiteralPath $directory -PathType Container)) { continue }
        foreach ($file in Get-ChildItem -LiteralPath $directory -Filter contexto.json -File -Recurse) {
            $relative=$file.FullName.Substring($master.Folder.Length+1)
            $leases=@(); $paths=$null; $data=$null
            try {
                $read=Read-HarnessProjectFiles $master @($relative)
                $data=ConvertFrom-Json $read[$relative]
                $paths=Get-PrioritizationPaths $master $data.Category $data.Scope
                if ($paths.ContextPath -ine $file.FullName) { $paths=$null; throw 'Contexto fora do destino funcional.' }
                $projects=@(foreach ($entry in $data.Projects) {
                    if (-not $stores.ContainsKey($entry.Project)) { throw 'Projeto participante nao associado.' }
                    $stores[$entry.Project]
                })
                $projectNames=[string[]]@($projects.Name); [Array]::Sort($projectNames,[StringComparer]::Ordinal)
                if (($projectNames -join '|') -cne (@($projects.Name) -join '|') -or $projectNames[0] -cne $master.Name) { throw 'Mestre/ordem dos participantes divergente.' }
                foreach ($project in $projects) { $leases+=Enter-HarnessProjectAccess $project -ForOperation }
                Assert-PrioritizationContext $data $paths $projects $data.Category $data.Scope
                if ($RefreshSources) {
                    foreach ($project in $projects) {
                        if (-not $mtas.ContainsKey($project.Name)) {
                            try { $mtas[$project.Name]=Read-HarnessProjectMta $project }
                            catch { $mtas[$project.Name]=$null; $warnings+=($project.Name+': '+$_.Exception.Message) }
                        }
                        $key=$project.Name+'|'+$data.Category
                        if (-not $refreshed.ContainsKey($key)) {
                            Update-PrioritizationFichaSources $project $mtas[$project.Name] $data.Category
                            $refreshed[$key]=$true
                        }
                    }
                }
                # Nao confiar em destinos editados dentro de FichaPaths.
                $expectedFichas=@(foreach ($issue in $data.BaselineIssues) {
                    $store=$stores[$issue.Project]
                    [pscustomobject]@{Project=$issue.Project;Id=$issue.Id;Path=(Join-Path $store.Folder (Get-PrioritizationFichaRelativePath $data.Category $issue.Id))}
                })
                if ((ConvertTo-Json -InputObject @($data.FichaPaths) -Compress) -cne (ConvertTo-Json -InputObject $expectedFichas -Compress)) { throw 'Destinos de fichas divergentes.' }
                $rankRel=$paths.Relative+'/priorizacao.md'; $indexRel=$paths.Relative+'/indice.md'
                $old=Read-HarnessProjectFiles $master @($relative,$rankRel,$indexRel)
                if ($old[$relative] -cne $read[$relative]) { throw 'Contexto mudou durante a leitura.' }
                $result=Read-PrioritizationResult $data $old[$rankRel] $projects
                $writes=@{}
                $writes[$indexRel]=Get-PrioritizationIndexContent $data $result $old[$indexRel]
                $writes[$rankRel]=Get-PrioritizationRankingContent $data $result $old[$rankRel]
                Publish-HarnessProjectFiles $master $writes $old
                $lines+='- '+(Get-HarnessSourceLink $globalPath $paths.IndexPath ($data.Scope+' / '+$data.Category))+" - $(@($result.AnalyzedIssues).Count)/$($data.InitialTotal) examinadas; $($result.Status)."
                foreach ($project in $projects) { $links[$project.Name]+=$paths.IndexPath }
            } catch {
                $warnings+=($file.FullName+': '+$_.Exception.Message)
                $lines+='- Cobertura nao validada: '+(Get-HarnessSourceLink $globalPath $file.FullName 'conferir contexto')+'. '+(ConvertTo-ProjectCell $_.Exception.Message)
                if ($paths -and $data) {
                    foreach ($entry in $data.Projects) { if ($links.ContainsKey($entry.Project)) { $links[$entry.Project]+=$paths.IndexPath } }
                }
                # Nao exibir cobertura antiga como valida quando ficha/resultado sumiu.
                $indexRelative=(Split-Path $relative -Parent)+'/indice.md'
                $before=Read-HarnessProjectFiles $master @($indexRelative)
                if ($before[$indexRelative] -and $paths -and $data -and $leases.Count -gt 0 -and $leases.Count -eq @($data.Projects).Count) {
                    $writes=@{}; $writes[$indexRelative]=Set-ProjectManagedBlock $before[$indexRelative] 'priorizacao:indice' ('Cobertura nao validada: '+(ConvertTo-ProjectCell $_.Exception.Message))
                    Publish-HarnessProjectFiles $master $writes $before
                }
            } finally {
                for ($i=$leases.Count-1;$i -ge 0;$i--) { $leases[$i].ReleaseMutex(); $leases[$i].Dispose() }
            }
        }
    }
    if ($lines.Count -or $globalOld['priorizacao.md']) {
        $values=@{
            Entries=($lines -join [Environment]::NewLine)
            NextStep=(Expand-HarnessDocumentTemplate 'orientacao-priorizacao' @{MigrationLinks='Abra o escopo/categoria acima para acessar os registros dos projetos e suas fichas.'})
        }
        $text=Merge-PrioritizationDocument 'indice-priorizacoes' $values $globalOld['priorizacao.md'] @('priorizacao:indice')
        Publish-HarnessProjectFiles $destination @{'priorizacao.md'=$text} $globalOld
    }
    foreach ($project in $stores.Values) {
        $old=Read-HarnessProjectFiles $project @('indice.md')
        if (-not $links[$project.Name].Count -and -not (Find-ProjectManagedBlock ([string]$old['indice.md']) 'priorizacao')) { continue }
        $refs=@($links[$project.Name] | ForEach-Object { '- '+(Get-HarnessSourceLink $project.IndexPath $_ 'Priorizacao corrente') })
        $text=Set-ProjectManagedBlock ([string]$old['indice.md']) 'priorizacao' ($refs -join [Environment]::NewLine)
        Publish-HarnessProjectFiles $project @{'indice.md'=$text} $old
    }
    [pscustomobject]@{IndexPath=$globalPath;Warnings=$warnings}
}
