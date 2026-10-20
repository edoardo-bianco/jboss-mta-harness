function Get-DiscardJsonStrings($Value) {
    if ($null -eq $Value) { return }
    if ($Value -is [string]) { $Value; return }
    if ($Value -is [Collections.IDictionary]) { foreach ($key in $Value.Keys) { Get-DiscardJsonStrings $Value[$key] }; return }
    if ($Value -is [Array]) { foreach ($item in $Value) { Get-DiscardJsonStrings $item }; return }
    if ($Value -is [pscustomobject]) { foreach ($property in $Value.PSObject.Properties) { Get-DiscardJsonStrings $property.Value } }
}
function Get-DiscardRecordSources([string]$Path,[string]$Text,[string]$Root) {
    if ([IO.Path]::GetExtension($Path) -ieq '.md') {
        $values=@([regex]::Matches($Text,'(?m)^Source:\s*([^\r\n]+)') | ForEach-Object {$_.Groups[1].Value.Trim()})
    } else {
        $data=ConvertFrom-Json $Text
        $values=@(Get-LegacyValue $data 'Source')+@(Get-LegacyValue $data 'Projects' @() | ForEach-Object {Get-LegacyValue $_ 'Source'})
    }
    @($values | Where-Object {$_} | ForEach-Object {Resolve-ProjectPath $_ $Root} | Sort-Object -Unique)
}
function Get-DiscardSourcePaths($Value,[string]$Root) {
    if ($Value -is [Array]) { foreach ($entry in $Value) { Get-DiscardSourcePaths $entry $Root }; return }
    if ($Value -isnot [pscustomobject]) { return }
    foreach ($property in $Value.PSObject.Properties) {
        if ($property.Name -in @('Source','AnalysisSource') -and $property.Value -is [string] -and $property.Value) { Resolve-ProjectPath $property.Value $Root }
        else { Get-DiscardSourcePaths $property.Value $Root }
    }
}
function Get-ConversionDiscardTextInventory($Access) {
    $paths=@(); $queue=New-Object 'Collections.Generic.Stack[string]'; $count=0
    foreach ($family in @('projetos','planning','priorizacao','sprints','builds','sonar','runs','importacoes')) {
        $directory=Join-Path $Access.Discard.Folder $family
        if (Test-Path -LiteralPath $directory -PathType Container) { $queue.Push($directory) }
    }
    while ($queue.Count) {
        $directory=Resolve-ProjectPath ($queue.Pop()) $Access.Project.Root
        foreach ($entry in Get-ChildItem -LiteralPath $directory -Force) {
            if (++$count -gt 50000) { throw 'Inventario textual excede 50000 entradas; delimite o legado antes de descartar.' }
            $path=Resolve-ProjectPath $entry.FullName $Access.Project.Root
            $relative=$path.Substring($Access.Discard.Folder.Length+1).Replace('\','/')
            if ($relative -match '^runs/[^/]+/[^/]+/(source|input)(/|$)|^importacoes/[^/]+/original(/|$)') { continue }
            if (@($Access.Projects | Where-Object {$path -ieq $_.Folder}).Count) { continue }
            if ($entry.PSIsContainer) { $queue.Push($path) }
            elseif ($path -match '\.(md|json)$') { $paths+=$path }
        }
    }
    $paths | Sort-Object -Unique
}
function Get-ConversionDiscardConsumers($State,$Access,$CurrentTrees) {
    $session=$State.Inputs.Session; $queue=New-Object 'Collections.Generic.Queue[object]'
    $protectedSources=@($State.Inputs.Preview.LegacySource)
    foreach ($record in $State.Inputs.Inventory) {
        $text=Read-ConversionText $session $record.Path
        $sources=@(Get-DiscardRecordSources $record.Path $text $Access.Project.Root)
        $protectedSources+=$sources
        if ($record.Path -match '\.json$') { $protectedSources+=@(Get-DiscardSourcePaths (ConvertFrom-Json $text) $Access.Project.Root) }
        if (-not $sources.Count) { $sources=@('ORIGEM_DESCONHECIDA: '+$record.Path) }
        foreach ($source in $sources) { $queue.Enqueue([pscustomobject]@{Path=$record.Path;Source=$source}) }
    }
    foreach ($entry in $CurrentTrees) {
        foreach ($path in $entry.Tree.Files.Keys | Where-Object {$_ -match '\.(md|json)$'}) {
            $relative=$path.Substring($entry.Project.Folder.Length+1).Replace('\','/')
            $source=if ($relative -match '^(recebido|temporarios)/') {'PENDENTE: '+$path} else {$entry.Project.Source}
            $queue.Enqueue([pscustomobject]@{Path=$path;Source=$source})
        }
    }
    $textInventory=@(Get-ConversionDiscardTextInventory $Access)
    $seen=@{}; $reached=@{}; $consumers=@{}; $folders=@{}; $unknownSeeded=$false
    while ($queue.Count -or -not $unknownSeeded) {
        if (-not $queue.Count) {
            $unknownSeeded=$true
            foreach ($path in $textInventory) {
                if (-not $reached.ContainsKey($path)) { $queue.Enqueue([pscustomobject]@{Path=$path;Source=('ORIGEM_DESCONHECIDA: '+$path)}) }
            }
            if (-not $queue.Count) { break }
        }
        $item=$queue.Dequeue(); $path=Resolve-ProjectPath $item.Path $Access.Project.Root
        $key=$item.Source+'|'+$path
        if ($seen.ContainsKey($key)) { continue }; $seen[$key]=$true
        $reached[$path]=$true
        if ($seen.Count -gt 50000) { throw 'Grafo de consumidores excede 50000 entradas; descarte exige escopo menor.' }
        if ($State.Map.ContainsKey($path)) {
            if (-not $consumers.ContainsKey($path)) { $consumers[$path]=@{} }
            $consumers[$path][$item.Source]=$true
        }
        if (Test-Path -LiteralPath $path -PathType Container) {
            $tree=Get-CleanupFileTree $path; $folders[$path]=$tree
            foreach ($child in $tree.Files.Keys) { $queue.Enqueue([pscustomobject]@{Path=$child;Source=$item.Source}) }
            continue
        }
        if (-not (Test-Path -LiteralPath $path -PathType Leaf) -or $path -notmatch '\.(md|json)$') { continue }
        $text=Read-ConversionText $session $path
        $links=@(Get-ConversionLinks $text $path $session)
        if ($path -match '\.json$') {
            foreach ($value in @(Get-DiscardJsonStrings (ConvertFrom-Json $text))) {
                if (-not $value -or $value -match '[\r\n]|^https?://|^#|[*?\x00-\x1f]') { continue }
                foreach ($base in @((Split-Path $path -Parent),$Access.Project.Root)) {
                    try { $candidate=Resolve-ProjectPath $value $base } catch { continue }
                    if (Test-Path -LiteralPath $candidate) { $links+=$candidate }
                }
            }
        }
        foreach ($link in $links | Select-Object -Unique) {
            # O grafo nao percorre codigo-fonte, snapshots ou origens externas.
            # Caminhos correntes ja foram adicionados como raizes independentes.
            if (-not $link.StartsWith($session.DataRoot+'\',[StringComparison]::OrdinalIgnoreCase)) { continue }
            $relative=$link.Substring($session.DataRoot.Length+1).Replace('\','/')
            if ($relative -notmatch '^(projetos|planning|priorizacao|sprints|builds|sonar|runs|importacoes)(/|$)' -or
                $relative -match '^runs/[^/]+/[^/]+/(source|input)(/|$)|^importacoes/[^/]+/original(/|$)') { continue }
            if (@($Access.Projects | Where-Object {$link -ieq $_.Folder -or $link.StartsWith($_.Folder+'\',[StringComparison]::OrdinalIgnoreCase)}).Count) { continue }
            $queue.Enqueue([pscustomobject]@{Path=$link;Source=$item.Source})
        }
    }
    [pscustomobject]@{Consumers=$consumers;Folders=@($folders.Values);ProtectedSources=@($protectedSources | Select-Object -Unique);TextInventory=$textInventory}
}
function New-ConversionCleanupSelection($Access,$Options) {
    $valid=Test-ConversionCurrent $Access.Project.Root $Access.Project.Pom
    if (-not $valid.Valid) { throw ('Destino corrente pendente: '+($valid.Diagnostics -join ' ')) }
    $state=Invoke-ConversionApply @Options -VerifyOnly
    $trees=@(foreach ($peer in $Access.Projects) {
        # Temporarios/recebido tambem sao observados, mas nao viram candidatos.
        [pscustomobject]@{Project=$peer;Tree=(Get-CleanupFileTree $peer.Folder)}
    })
    $graph=Get-ConversionDiscardConsumers $state $Access $trees
    $unknownPending=@(foreach ($entry in $trees) {
        foreach ($path in $entry.Tree.Files.Keys) {
            $relative=$path.Substring($entry.Project.Folder.Length+1).Replace('\','/')
            if ($relative -match '^recebido/|^temporarios/reconciliacao/' -and $path -notmatch '\.(md|json)$') { $path }
        }
    })
    $candidates=@(); $files=@{}
    foreach ($path in @($state.Map.Keys | Sort-Object)) {
        # Destinos apenas enderecados no preparo nunca foram arquivos legados.
        if (-not (Test-Path -LiteralPath $path)) { continue }
        $destination=$state.Map[$path]; $reason='Transformado e exclusivo do Source selecionado.'; $eligible=$true
        try {
            $null=Assert-ConversionDiscardPath $path $Access
            if ($unknownPending.Count) { throw 'Material recebido/conciliacao sem referencias interpretaveis; conclua a conciliacao antes do descarte.' }
            foreach ($source in $graph.ProtectedSources) {
                if (($source -ieq $state.Inputs.Session.DataRoot -or $source.StartsWith($state.Inputs.Session.DataRoot+'\',[StringComparison]::OrdinalIgnoreCase)) -and
                    ($path -ieq $source -or $path.StartsWith($source+'\',[StringComparison]::OrdinalIgnoreCase))) { throw 'Arquivo pertence a Source/AnalysisSource legado; preservar fonte.' }
            }
            if (-not $destination.StartsWith($Access.Project.Folder+'\',[StringComparison]::OrdinalIgnoreCase)) { throw 'Destino pertence a origem externa ou outro projeto.' }
            if (-not (Test-Path -LiteralPath $path -PathType Leaf) -or -not (Test-Path -LiteralPath $destination -PathType Leaf)) { throw 'Origem ou destino ausente.' }
            if (-not $graph.Consumers.ContainsKey($path) -or $graph.Consumers[$path].Count -ne 1 -or -not $graph.Consumers[$path].ContainsKey($state.Inputs.Preview.LegacySource)) { throw 'Consumidor externo, compartilhado ou desconhecido; preservar origem.' }
            $files[$path]=[pscustomobject]@{Bytes=[IO.File]::ReadAllBytes($path);Ticks=[IO.File]::GetLastWriteTimeUtc($path).Ticks}
        } catch { $eligible=$false; $reason=$_.Exception.Message }
        $candidates+=[pscustomobject]@{Path=$path;Destination=$destination;Eligible=$eligible;Reason=$reason}
    }
    $origins=@(foreach ($directory in @($files.Keys | ForEach-Object {Split-Path $_ -Parent} | Sort-Object -Unique)) { Get-CleanupFileTree $directory })
    Assert-ConversionUnchanged $state.Inputs.Session $state.Inputs.Inventory
    [pscustomobject]@{State=$state;CurrentTrees=$trees;OriginTrees=$origins;Graph=$graph;Candidates=$candidates;Files=$files}
}
