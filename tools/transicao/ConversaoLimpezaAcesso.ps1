function Get-ConversionDiscardReference($Project) {
    $folder=Resolve-ProjectPath '.harness' $Project.Root
    [pscustomobject]@{Folder=$folder;TemporaryPath=(Join-Path $folder 'temporarios/conversao-descarte')}
}
function Assert-ConversionDiscardPath([string]$Path,$Access) {
    $path=Resolve-ProjectPath $Path $Access.Project.Root
    $prefix=$Access.Discard.Folder+'\'
    if (-not $path.StartsWith($prefix,[StringComparison]::OrdinalIgnoreCase)) { throw 'Descarte fora das familias legadas recusado.' }
    $relative=$path.Substring($prefix.Length).Replace('\','/')
    if ($relative -cnotmatch '^(projetos|planning|priorizacao|sprints|builds|sonar|runs|importacoes)/[^/]+/.+' -or
        $relative -match '(^|/)temporarios(/|$)|^importacoes/[^/]+/original(/|$)|^runs/[^/]+/[^/]+/(source|input)(/|$)') { throw 'Caminho nao elegivel para descarte legado.' }
    foreach ($peer in $Access.Projects) {
        if ($path -ieq $peer.Folder -or $path.StartsWith($peer.Folder+'\',[StringComparison]::OrdinalIgnoreCase)) { throw 'Dados correntes nao podem entrar no descarte legado.' }
    }
    Assert-CleanupProtectedPath $path $Access.Project.Root $Access.Associations
    if (Test-Path -LiteralPath $path -PathType Container) { throw 'Selecione arquivos exatos; diretorios ou raizes compartilhadas nao sao descartados.' }
    $path
}
function Open-ConversionCleanupAccess([string]$Workspace,[string]$Pom) {
    $project=Get-HarnessProjectReference $Workspace $Pom
    $associations=Get-CleanupAssociations $project.Root
    $projects=@(); $guards=@(); $leases=@()
    $discard=Get-ConversionDiscardReference $project
    try {
        $leases+=Enter-SprintAccess $project.Root
        # A limpeza e offline: conservar todas as associacoes atuais durante a
        # analise de consumidores compartilhados e a eventual recuperacao.
        $names=[string[]]@($associations.Items | ForEach-Object Name); [Array]::Sort($names,[StringComparer]::Ordinal)
        foreach ($name in $names) {
            $entry=@($associations.Items | Where-Object Name -CEQ $name)[0]
            $guards+=[IO.File]::Open($entry.Pom,'Open','Read','Read')
            $peer=Get-HarnessProjectReference $project.Root $entry.Pom
            if ($peer.Name -cne $name -or $peer.Folder -ine $entry.Folder) { throw 'Associacao Maven divergente; descarte recusado.' }
            $projects+=$peer
        }
        if ($project.Pom -notin @($projects | ForEach-Object Pom)) { throw 'Destino ainda nao convertido/associado.' }
        foreach ($peer in $projects) {
            $leases+=Enter-HarnessProjectAccess $peer -ReadOnly
            $leases+=Enter-HarnessProjectAccess $peer -ForOperation
        }
        # Mutex exclusivo do adaptador: serializa previa, descarte e recuperacao
        # sem executar a recuperacao como efeito colateral da inspecao.
        $sha=[Security.Cryptography.SHA256]::Create()
        try { $name=[BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($discard.Folder.ToLowerInvariant()))).Replace('-','') }
        finally { $sha.Dispose() }
        $mutex=New-Object Threading.Mutex($false,('Local\HarnessConversionCleanup_'+$name))
        $acquired=$false
        try {
            try {$acquired=$mutex.WaitOne(0)} catch [Threading.AbandonedMutexException] {$acquired=$true}
            if (-not $acquired) { throw 'Outro descarte esta em andamento.' }
            $leases+=$mutex
        } catch { $mutex.Dispose(); throw }
        Assert-CleanupAssociationsUnchanged $project.Root $associations
        [pscustomobject]@{Project=$project;Projects=$projects;Associations=$associations;Discard=$discard;Leases=$leases;Guards=$guards}
    } catch {
        for ($i=$leases.Count-1;$i -ge 0;$i--) { $leases[$i].ReleaseMutex(); $leases[$i].Dispose() }
        foreach ($guard in $guards) { $guard.Dispose() }
        throw
    }
}
function Close-ConversionCleanupAccess($Access) {
    for ($i=$Access.Leases.Count-1;$i -ge 0;$i--) { $Access.Leases[$i].ReleaseMutex(); $Access.Leases[$i].Dispose() }
    foreach ($guard in $Access.Guards) { $guard.Dispose() }
}
function Get-ConversionDiscardRecovery($Access) {
    $area=Resolve-ProjectPath (Join-Path $Access.Discard.TemporaryPath 'publicacao') $Access.Project.Root
    if (-not (Test-Path -LiteralPath $area)) { return $null }
    $tree=Get-CleanupFileTree $area
    $journal=Join-Path $area 'recuperacao.json'; $paths=@()
    if (Test-Path -LiteralPath $journal -PathType Leaf) {
        $entries=ConvertFrom-Json ([IO.File]::ReadAllText($journal))
        foreach ($entry in $entries) {
            if ($entry.Remove -isnot [bool] -or -not $entry.Remove -or $entry.Existed -isnot [bool] -or -not $entry.Existed -or
                ($entry.PSObject.Properties['TemporaryRemoval'] -and $entry.TemporaryRemoval)) { throw 'Journal de descarte invalido; preserve a area de recuperacao.' }
            if ([IO.Path]::IsPathRooted($entry.Path) -or $entry.Path -match '(^|[\\/])\.\.([\\/]|$)') { throw 'Destino de recuperacao invalido.' }
            $paths+=Assert-ConversionDiscardPath (Join-Path $Access.Discard.Folder $entry.Path) $Access
        }
        if (-not $paths.Count) { throw 'Journal vazio; preserve a area de recuperacao.' }
    } else {
        foreach ($path in $tree.Files.Keys) {
            $relative=$path.Substring($area.Length+1).Replace('\','/')
            if ($relative -in @('restaurar.tmp','recuperacao.tmp')) { continue }
            if ($relative -notmatch '^(antes|depois)/(.+)$') { throw 'Arquivo desconhecido na area de recuperacao; preservar.' }
            $null=Assert-ConversionDiscardPath (Join-Path $Access.Discard.Folder $matches[2]) $Access
        }
    }
    [pscustomobject]@{Path=$area;Paths=$paths;Tree=$tree}
}
