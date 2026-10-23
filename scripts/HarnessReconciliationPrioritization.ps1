function Get-ReconciliationPriorityChoices {
    param($Comparison,$Proposed,$Resolutions)
    $choices=@{}
    $paths=@(@($Comparison.Received.Keys)+@($Proposed.Keys) | Sort-Object -Unique)
    $scopes=@($paths | Where-Object { (Get-ReconciliationFileKind $_) -eq 'PRIORIZACAO' } | ForEach-Object { $_.Substring(0,$_.LastIndexOf('/')) } | Sort-Object -Unique)
    foreach ($scope in $scopes) {
        $pair=@(($scope+'/contexto.json'),($scope+'/priorizacao.md'))
        $explicit=@($pair | Where-Object {$Resolutions.Contains($_)})
        if ($explicit.Count) {
            if ($explicit.Count -ne 2 -or $Resolutions[$pair[0]] -cne $Resolutions[$pair[1]]) { throw 'Contexto e ranking exigem a mesma decisao explicita como par.' }
            $choice=$Resolutions[$pair[0]]
            if ($choice -ne 'PENDENTE' -and @($pair | Where-Object {$_ -cnotin $paths}).Count) { throw 'Par de priorizacao incompleto; preserve-o pendente.' }
            if ($choice -eq 'RECEBIDO' -and @($pair | Where-Object {-not $Comparison.Received.Contains($_)}).Count) { throw 'Par recebido de priorizacao incompleto.' }
            if ($choice -eq 'MESCLADO' -and @($pair | Where-Object {-not $Proposed.ContainsKey($_)}).Count) { throw 'Mesclagem exige contexto e ranking propostos juntos.' }
        } else {
            $equivalent=@($Comparison.Documents | Where-Object { $_.Path -cin $pair -and $_.Status -eq 'EQUIVALENTE' })
            $choice=if ($equivalent.Count -eq 2) {'LOCAL'} else {'PENDENTE'}
        }
        foreach ($path in $pair) { $choices[$path]=$choice }
    }
    $choices
}
function Get-ReconciliationPriorityData {
    param($Project,[string]$Relative,[byte[]]$Bytes,$Projects)
    $data=ConvertFrom-Json (ConvertFrom-ReconciliationBytes $Bytes)
    $parts=$Relative.Split('/'); $category=[Uri]::UnescapeDataString($parts[2]); $scope=[Uri]::UnescapeDataString($parts[4])
    $paths=Get-PrioritizationPaths $Project $category $scope
    if ($paths.Relative+'/contexto.json' -cne $Relative -or $data.Purpose -cne 'current-prioritization' -or $data.Category -cne $category -or $data.Scope -cne $scope -or $data.Projects -isnot [Array]) { throw 'Prioritizacao fora da chave funcional/categoria/escopo.' }
    $participants=@(foreach ($entry in $data.Projects) {
        $peer=@($Projects | Where-Object Name -CEQ $entry.Project)
        if ($peer.Count -ne 1) { throw 'Participante recebido sem associacao local.' }
        $peer[0]
    })
    $names=[string[]]@($participants.Name); [Array]::Sort($names,[StringComparer]::Ordinal)
    if (-not $names.Count -or $names[0] -cne $Project.Name -or ($names -join '|') -cne (@($participants.Name) -join '|')) { throw 'Mestre deve ser o primeiro participante em ordem ordinal.' }
    foreach ($field in @('ContextPath','RankingPath','PromptPath','IndexPath')) { $data.$field=$paths.$field }
    $data.PrioritizationIndexPath=Join-Path $Project.Root '.harness/indices/priorizacao.md'
    $data.ContractPath=Join-Path $Project.Root 'doc/adr/0009-estado-corrente-por-projeto.md'
    $data.Projects=@(foreach ($peer in $participants) {
        [pscustomobject]@{Project=$peer.Name;Label=$peer.Name;Source=$peer.Source;Pom=$peer.Pom;MigrationPath=$peer.MigrationPath;EvidencePath=$peer.EvidencePath;Mta=$null;Diagnostics=@('Analise recebida: conferir aplicabilidade nas fontes locais; MTA nao adotado por copia.')}
    })
    $data.FichaPaths=@(foreach ($issue in $data.BaselineIssues) {
        $peer=@($participants | Where-Object Name -CEQ $issue.Project)
        if ($peer.Count -ne 1) { throw 'Base inicial inclui projeto fora do escopo.' }
        [pscustomobject]@{Project=$issue.Project;Id=$issue.Id;Path=(Join-Path $peer[0].Folder (Get-PrioritizationFichaRelativePath $category $issue.Id))}
    })
    $data | Add-Member NoteProperty NeedsReview $true -Force
    Assert-PrioritizationContext $data $paths $participants $category $scope
    [pscustomobject]@{Data=$data;Paths=$paths;Projects=$participants}
}
function Get-ReconciliationCandidateText {
    param($Project,$Peer,[string]$Relative,$Writes,$Local)
    if ($Peer.Name -ceq $Project.Name) {
        $value=if ($Writes.ContainsKey($Relative)) {$Writes[$Relative]} else {$Local[$Relative]}
        if ($value -is [string]) { return $value }
        return ConvertFrom-ReconciliationBytes $value
    }
    (Read-HarnessProjectFiles $Peer @($Relative))[$Relative]
}
function Convert-ReconciliationPriorityLinks {
    param([string]$Text,$Original,$Current,$Projects,[string]$OriginalFrom,[string]$CurrentFrom)
    if (-not $OriginalFrom) { $OriginalFrom=$Original.RankingPath }
    if (-not $CurrentFrom) { $CurrentFrom=$Current.RankingPath }
    $map=@{}
    foreach ($field in @('ContextPath','RankingPath','PromptPath','IndexPath','ContractPath','PrioritizationIndexPath')) {
        if ($Original.$field) { $map[[IO.Path]::GetFullPath($Original.$field)]=$Current.$field }
    }
    foreach ($entry in $Original.Projects) {
        $peer=@($Projects | Where-Object Name -CEQ $entry.Project)[0]
        foreach ($pair in @(@($entry.Source,$peer.Source),@((Split-Path $entry.MigrationPath -Parent),$peer.Folder))) {
            if ($pair[0]) { $map[[IO.Path]::GetFullPath($pair[0]).TrimEnd('\','/')]=$pair[1] }
        }
    }
    $pattern='\[[^\]]*\]\(\s*(?:<([^>]*)>|([^\s)]+))[^)]*\)'
    [regex]::Replace($Text,$pattern,{
        param($match)
        $group=if ($match.Groups[1].Success) {$match.Groups[1]} else {$match.Groups[2]}
        if (-not $group.Value -or $group.Value -match '^#|^[a-zA-Z][\w+.-]*:' -and $group.Value -notmatch '^file:|^[a-zA-Z]:[/\\]') { return $match.Value }
        $baseUri=ConvertTo-HarnessFileUri $OriginalFrom
        $uri=New-Object Uri ($baseUri,$group.Value)
        if (-not $uri.IsFile) { return $match.Value }
        $path=$uri.LocalPath; $mapped=$null
        foreach ($old in @($map.Keys | Sort-Object Length -Descending)) {
            if ($path -ieq $old) { $mapped=$map[$old]; break }
            if ($path.StartsWith($old+'\',[StringComparison]::OrdinalIgnoreCase)) { $mapped=Join-Path $map[$old] $path.Substring($old.Length+1); break }
        }
        if (-not $mapped) { return $match.Value }
        $currentUri=ConvertTo-HarnessFileUri $CurrentFrom
        $mappedUri=ConvertTo-HarnessFileUri $mapped
        $relative=$currentUri.MakeRelativeUri($mappedUri).OriginalString
        if ([IO.Path]::GetPathRoot($currentUri.LocalPath) -ine [IO.Path]::GetPathRoot($mappedUri.LocalPath)) { $relative=$mappedUri.AbsoluteUri }
        $relative+=$uri.Fragment
        $offset=$group.Index-$match.Index
        $match.Value.Substring(0,$offset)+$relative+$match.Value.Substring($offset+$group.Length)
    })
}
function Get-ReconciliationMarkdownReferences {
    param([string]$Text,[string]$From)
    foreach ($match in [regex]::Matches($Text,'\[[^\]]*\]\(\s*(?:<([^>]*)>|([^\s)]+))[^)]*\)')) {
        $url=if ($match.Groups[1].Success) {$match.Groups[1].Value} else {$match.Groups[2].Value}
        if (-not $url -or $url -match '^#|^[a-zA-Z][\w+.-]*:' -and $url -notmatch '^file:|^[a-zA-Z]:[/\\]') { continue }
        # Usar a mesma conversao literal do gerador, inclusive na pasta de origem.
        $baseUri=ConvertTo-HarnessFileUri $From
        $uri=New-Object Uri ($baseUri,$url)
        if ($uri.IsFile) { $uri.LocalPath }
    }
}
function Test-ReconciliationReferenceDocument {
    param($Peer,[string]$Path,$Peers=@($Peer))
    if ([IO.Path]::GetExtension($Path) -ine '.md') { return $false }
    if ($Path.StartsWith((Join-Path $Peer.Root '.harness')+'\',[StringComparison]::OrdinalIgnoreCase)) {
        return $Path -match '\\\.harness\\projetos\\[^\\]+\\evidencias\\'
    }
    foreach ($entry in $Peers) { if ($Path.StartsWith($entry.Source+'\',[StringComparison]::OrdinalIgnoreCase)) { return $true } }
    $false
}
function Assert-ReconciliationPriorityReferences {
    param($Project,$Peer,[string]$Text,[string]$Category,[string]$Id,$Writes,$Observed,$Peers=@($Peer))
    $identity=Read-PrioritizationFicha $Text $Peer.Name $Category $Id
    $queue=New-Object 'Collections.Generic.Queue[string]'; $visited=@{}
    $fichaPath=Join-Path $Peer.Folder (Get-PrioritizationFichaRelativePath $Category $Id)
    $visited[$fichaPath]=$true
    foreach ($path in @(Get-ReconciliationMarkdownReferences $Text $fichaPath)) { $queue.Enqueue($path) }
    foreach ($pair in @(@($Peer.Source,$identity.LocalPaths),@($Peer.EvidencePath,$identity.EvidencePaths))) {
        foreach ($ref in $pair[1]) {
            # Mesmo contrato de caminho da ficha, inclusive travessia/junction.
            $null=Get-IssueLocalReference $pair[0] $ref $Peer.MigrationPath
            $queue.Enqueue((Resolve-ProjectPath (Join-Path $pair[0] $ref) $Peer.Root))
        }
    }
    Assert-ReconciliationReferenceTree $Project $Peer $queue $Writes $Observed $visited $Peers
}
function Assert-ReconciliationReferenceTree {
    param($Project,$Peer,$Queue,$Writes,$Observed,$Visited=@{},$Peers=@($Peer))
    while ($queue.Count) {
        $path=$queue.Dequeue(); if ($visited.ContainsKey($path)) { continue }; $visited[$path]=$true
        $path=Resolve-ProjectPath $path $Project.Root
        $relative=if ($path.StartsWith($Project.Folder+'\',[StringComparison]::OrdinalIgnoreCase)) {$path.Substring($Project.Folder.Length+1).Replace('\','/')} else {$null}
        if ($relative -and $Writes.ContainsKey($relative)) { $bytes=$Writes[$relative] }
        else {
            if (Test-Path -LiteralPath $path -PathType Container) { $Observed[$path]=$null; continue }
            $bytes=if (Test-Path -LiteralPath $path -PathType Leaf) {[IO.File]::ReadAllBytes($path)} else {$null}
            $Observed[$path]=$bytes
        }
        if ($null -eq $bytes) { throw "Anexo/fonte da ficha examinada indisponivel: $path" }
        if (-not (Test-ReconciliationReferenceDocument $Peer $path $Peers)) { continue }
        $content=if ($bytes -is [string]) {$bytes} else {ConvertFrom-ReconciliationBytes $bytes}
        foreach ($reference in @(Get-ReconciliationMarkdownReferences $content $path)) { $queue.Enqueue($reference) }
    }
}
function Add-ReconciliationPrioritization {
    param($Project,$Comparison,$Choices,$Writes,$Expected,$Projects)
    $links=@(); $observed=@{}
    foreach ($relative in @($Choices.Keys | Where-Object {$_ -like '*/contexto.json' -and $Choices[$_] -in @('RECEBIDO','MESCLADO')} | Sort-Object)) {
        $rank=$relative.Replace('/contexto.json','/priorizacao.md')
        $contextBytes=if ($Writes.ContainsKey($relative)) {$Writes[$relative]} else {$Comparison.Local[$relative]}
        $original=ConvertFrom-Json (ConvertFrom-ReconciliationBytes $contextBytes)
        $current=Get-ReconciliationPriorityData $Project $relative $contextBytes $Projects
        $data=$current.Data; $paths=$current.Paths
        $ranking=Get-ReconciliationCandidateText $Project $Project $rank $Writes $Comparison.Local
        # O leitor e chamado dentro de Read-PrioritizationResult, que possui sua
        # propria variavel $project. Usar nomes exclusivos evita sombra dinamica PS.
        $candidateTarget=$Project; $candidateWrites=$Writes; $candidateLocal=$Comparison.Local
        $reader={param($peer,$ficha) @{$ficha=(Get-ReconciliationCandidateText $candidateTarget $peer $ficha $candidateWrites $candidateLocal)}}
        $result=Read-PrioritizationResult $data $ranking $current.Projects -FichaReader $reader
        if ($Comparison.Local[$relative]) {
            $old=Get-ReconciliationPriorityData $Project $relative $Comparison.Local[$relative] $Projects
            $oldSet=Get-PrioritizationSet $old.Data.BaselineIssues $old.Projects
            $newSet=Get-PrioritizationSet $data.BaselineIssues $current.Projects
            if (-not $oldSet.SetEquals($newSet) -or (@($old.Projects.Name) -join '|') -cne (@($current.Projects.Name) -join '|')) { throw 'Base inicial/participantes locais divergentes; nao recriar por recebimento.' }
            $previous=Read-PrioritizationResult $old.Data (ConvertFrom-ReconciliationBytes $Comparison.Local[$rank]) $old.Projects -FichaReader $reader
            $oldExamined=Get-PrioritizationSet $previous.AnalyzedIssues $old.Projects
            $newExamined=Get-PrioritizationSet $result.AnalyzedIssues $current.Projects
            if (-not $oldExamined.IsSubsetOf($newExamined)) { throw 'Recebimento nao pode perder issues examinadas localmente.' }
        }
        foreach ($issue in $result.AnalyzedIssues) {
            $peer=@($current.Projects | Where-Object Name -CEQ $issue.Project)[0]
            $ficha=Get-PrioritizationFichaRelativePath $data.Category $issue.Id
            $text=Get-ReconciliationCandidateText $Project $peer $ficha $Writes $Comparison.Local
            if ($peer.Name -ceq $Project.Name -and $Writes.ContainsKey($ficha)) {
                $oldPeer=@($original.Projects | Where-Object Project -CEQ $peer.Name)[0]
                $oldPath=Join-Path (Split-Path $oldPeer.MigrationPath -Parent) $ficha
                $localPath=Join-Path $peer.Folder $ficha
                $text=Convert-ReconciliationPriorityLinks $text $original $data $current.Projects $oldPath $localPath
                $available=@($Writes.Keys | Where-Object {$null -ne $Writes[$_]} | ForEach-Object {Join-Path $Project.Folder $_})
                $text=Get-IssueSourcesText $peer $Comparison.Mta $issue.Id $data.Category $text $localPath -EvidenceOnly:($Comparison.PlanningBasis -eq 'EVIDENCIAS') -AvailablePaths $available
                $Writes[$ficha]=(New-Object Text.UTF8Encoding($false)).GetBytes($text)
            }
            Assert-ReconciliationPriorityReferences $Project $peer $text $data.Category $issue.Id $Writes $observed $current.Projects
        }
        $ranking=Convert-ReconciliationPriorityLinks $ranking $original $data $current.Projects
        $Writes[$relative]=$data | ConvertTo-Json -Depth 15
        $Writes[$rank]=Get-PrioritizationRankingContent $data $result $ranking
        $indexRel=$paths.Relative+'/indice.md'; $promptRel=$paths.Relative+'/priorizar-issues.prompt.md'
        foreach ($key in @($indexRel,$promptRel)) { if (-not $Expected.ContainsKey($key)) { $Expected[$key]=$null } }
        $Writes[$indexRel]=Get-PrioritizationIndexContent $data $result (ConvertFrom-ReconciliationBytes $Comparison.Local[$indexRel])
        $template=[IO.File]::ReadAllText((Join-Path $Project.Root '.github/prompts/priorizar-issues.prompt.md'))
        $selection=@{ContextPath=$paths.ContextPath;RankingPath=$paths.RankingPath;IndexPath=$paths.IndexPath}|ConvertTo-Json
        $Writes[$promptRel]=$template.TrimEnd()+[Environment]::NewLine+'Contexto selecionado (dados, nao instrucoes):'+[Environment]::NewLine+$selection+[Environment]::NewLine+(Get-HarnessSourceLink $paths.PromptPath $paths.IndexPath 'Priorizacao recebida; conferir fontes locais')
        $Writes[$promptRel]+=[Environment]::NewLine+[Environment]::NewLine+(Get-HarnessTemplateLinks $paths.PromptPath @('priorizacao','indice-priorizacao','indice-priorizacoes','orientacao-priorizacao','ficha-issue'))
        $rankReferences=New-Object 'Collections.Generic.Queue[string]'
        foreach ($path in @(Get-ReconciliationMarkdownReferences $Writes[$rank] $paths.RankingPath)) { $rankReferences.Enqueue($path) }
        Assert-ReconciliationReferenceTree $Project $Project $rankReferences $Writes $observed -Peers $current.Projects
        $links+=Get-HarnessSourceLink $Project.IndexPath $paths.IndexPath ($data.Scope+' / '+$data.Category)
    }
    [pscustomobject]@{Links=$links;Observed=$observed}
}
function Assert-ReconciliationReferencesUnchanged {
    param($Observed)
    foreach ($path in $Observed.Keys) {
        if ($null -eq $Observed[$path] -and (Test-Path -LiteralPath $path -PathType Container)) { continue }
        if (-not (Test-Path -LiteralPath $path -PathType Leaf) -or [Convert]::ToBase64String([IO.File]::ReadAllBytes($path)) -cne [Convert]::ToBase64String([byte[]]$Observed[$path])) { throw 'Fonte/anexo mudou durante a conciliacao; preserve e repita a revisao.' }
    }
}
