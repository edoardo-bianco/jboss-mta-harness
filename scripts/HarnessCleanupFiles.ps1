# Inventario transitório em memoria; nunca vira recibo ou autorizacao persistida.
function Get-CleanupNativePath {
    param([string]$Path)
    '\\?\'+$Path.Replace('/','\')
}
function Get-CleanupFileTree {
    param([string]$Path)
    $files=@{}; $directories=@()
    if (-not [IO.Directory]::Exists((Get-CleanupNativePath $Path))) { return [pscustomobject]@{Path=$Path;Files=$files;Directories=$directories} }
    $null=Resolve-ProjectPath $Path $Path
    $queue=New-Object 'Collections.Generic.Stack[IO.DirectoryInfo]'
    $queue.Push((New-Object IO.DirectoryInfo $Path))
    while ($queue.Count) {
        $directory=$queue.Pop(); $directories+=$directory.FullName
        foreach ($item in $directory.EnumerateFileSystemInfos()) {
            if (-not $item.FullName.StartsWith($Path+'\',[StringComparison]::OrdinalIgnoreCase) -or
                ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw 'Link/junction ou caminho fora da area de limpeza; nada removido.' }
            if ($item -is [IO.DirectoryInfo]) { $queue.Push($item) }
            else { $files[$item.FullName]=[pscustomobject]@{Bytes=[IO.File]::ReadAllBytes((Get-CleanupNativePath $item.FullName));Ticks=$item.LastWriteTimeUtc.Ticks} }
        }
    }
    [pscustomobject]@{Path=$Path;Files=$files;Directories=$directories}
}
function Assert-CleanupFileTreeUnchanged {
    param($Tree)
    $current=Get-CleanupFileTree $Tree.Path
    if ($current.Files.Count -ne $Tree.Files.Count) { throw 'Selecao de limpeza mudou; confira novamente antes de remover.' }
    foreach ($path in $Tree.Files.Keys) {
        if (-not $current.Files.ContainsKey($path) -or $current.Files[$path].Ticks -ne $Tree.Files[$path].Ticks -or
            [Convert]::ToBase64String($current.Files[$path].Bytes) -cne [Convert]::ToBase64String($Tree.Files[$path].Bytes)) { throw "Arquivo alterado durante a confirmacao: $path" }
    }
}
function Remove-CleanupEmptyDirectories {
    param([string[]]$Directories)
    foreach ($path in @($Directories | Select-Object -Unique | Sort-Object Length -Descending)) {
        $null=Resolve-ProjectPath $path $path
        $native=Get-CleanupNativePath $path
        if (-not [IO.Directory]::Exists($native)) { continue }
        try { [IO.Directory]::Delete($native,$false) }
        catch [IO.IOException] {
            if (@([IO.Directory]::EnumerateFileSystemEntries($native)).Count) { continue }
            throw
        }
    }
}
function Get-CleanupAssociations {
    param([string]$Root)
    $base=Join-Path $Root '.harness/projetos'; $associations=@(); $observed=@{}
    if (Test-Path -LiteralPath $base -PathType Container) {
        $null=Resolve-ProjectPath $base $Root
        foreach ($folder in Get-ChildItem -LiteralPath $base -Directory) {
            $configPath=Resolve-ProjectPath (Join-Path $folder.FullName 'projeto.json') $Root
            if (-not (Test-Path -LiteralPath $configPath -PathType Leaf)) { continue }
            $bytes=[IO.File]::ReadAllBytes($configPath); $observed[$configPath]=$bytes
            $data=ConvertFrom-Json ([Text.Encoding]::UTF8.GetString($bytes).TrimStart([char]0xfeff))
            $pom=Resolve-ProjectPath $data.pom $Root; $mta=$null
            if ($data.PSObject.Properties['mta'] -and $data.mta -and $data.mta.PSObject.Properties['diretorio'] -and $data.mta.diretorio) { $mta=Resolve-ProjectPath $data.mta.diretorio $Root }
            $associations+=[pscustomobject]@{Name=$folder.Name;Folder=$folder.FullName;Pom=$pom;Source=(Split-Path $pom -Parent);Mta=$mta}
        }
    }
    [pscustomobject]@{Items=$associations;Observed=$observed}
}
function Assert-CleanupProtectedPath {
    param([string]$Path,[string]$Root,$Associations)
    $state=(Join-Path $Root '.harness')+'\'
    foreach ($entry in $Associations.Items) {
        if ($entry.Source -ieq $Path -or $entry.Source.StartsWith($Path+'\',[StringComparison]::OrdinalIgnoreCase) -or
            ($entry.Source.StartsWith($state,[StringComparison]::OrdinalIgnoreCase) -and $Path.StartsWith($entry.Source+'\',[StringComparison]::OrdinalIgnoreCase))) { throw "Area de limpeza abrange Source configurado: $($entry.Source)" }
        if ($entry.Mta -and ($entry.Mta -ieq $Path -or $entry.Mta.StartsWith($Path+'\',[StringComparison]::OrdinalIgnoreCase) -or $Path.StartsWith($entry.Mta+'\',[StringComparison]::OrdinalIgnoreCase))) { throw "Area de limpeza abrange origem MTA externa: $($entry.Mta)" }
    }
}
function Assert-CleanupAssociationsUnchanged {
    param([string]$Root,$Before)
    $after=Get-CleanupAssociations $Root
    if ($after.Observed.Count -ne $Before.Observed.Count) { throw 'Associacoes mudaram durante a limpeza; repita a selecao.' }
    foreach ($path in $Before.Observed.Keys) {
        if (-not $after.Observed.ContainsKey($path) -or [Convert]::ToBase64String($after.Observed[$path]) -cne [Convert]::ToBase64String($Before.Observed[$path])) { throw 'Configuracao mudou durante a limpeza; repita a selecao.' }
    }
}
function Remove-CleanupBackupFiles {
    param($Tree)
    # Backups nao reservam subpastas tecnicas: ate uma atividade chamada
    # temporarios/publicacao continua sendo conteudo humano selecionado.
    foreach ($path in @($Tree.Files.Keys | Sort-Object)) {
        $null=Resolve-ProjectPath $path $Tree.Path
        $native=Get-CleanupNativePath $path
        $bytes=[IO.File]::ReadAllBytes($native)
        if ([Convert]::ToBase64String($bytes) -cne [Convert]::ToBase64String($Tree.Files[$path].Bytes) -or [IO.File]::GetLastWriteTimeUtc($native).Ticks -ne $Tree.Files[$path].Ticks) { throw 'Backup alterado durante a limpeza; arquivos restantes preservados.' }
        [IO.File]::Delete($native)
    }
    Remove-CleanupEmptyDirectories $Tree.Directories
}
