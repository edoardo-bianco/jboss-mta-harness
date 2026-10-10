function Set-HarnessProjectOperation {
    param($Project,[ValidatePattern('^[a-z][a-z0-9-]*$')][string]$Name,[ValidateSet('RUNNING','SUCCEEDED','FAILED')][string]$Status,[string]$ErrorMessage,[string]$LogPath,[Collections.IDictionary]$Files=@{})
    $old=Read-HarnessProjectFiles $Project @('atual/operacao.json')
    $operations=[ordered]@{}
    if ($old['atual/operacao.json']) {
        $current=ConvertFrom-Json $old['atual/operacao.json']
        foreach ($entry in $current.PSObject.Properties) { $operations[$entry.Name]=$entry.Value }
    }
    $operations[$Name]=[ordered]@{Status=$Status;DateUtc=[DateTime]::UtcNow.ToString('o');Error=$ErrorMessage;LogPath=$LogPath}
    $writes=@{'atual/operacao.json'=($operations | ConvertTo-Json -Depth 6)}
    foreach ($path in $Files.Keys) {
        if ($writes.ContainsKey($path)) { throw 'Situacao da operacao deve ser gerada pelo publicador.' }
        $writes[$path]=$Files[$path]
    }
    Publish-HarnessProjectFiles $Project $writes @{'atual/operacao.json'=$old['atual/operacao.json']}
}

function Get-HarnessProjectTemporary {
    param($Project,[ValidatePattern('^[a-z][a-z0-9-]*$')][string]$Name)
    if ($Name -eq 'publicacao') { throw 'Area de recuperacao reservada.' }
    Resolve-ProjectPath (Join-Path $Project.TemporaryPath $Name) $Project.Folder
}

function Remove-HarnessProjectTemporary {
    param($Project,[ValidatePattern('^[a-z][a-z0-9-]*$')][string]$Name)
    $path=Get-HarnessProjectTemporary $Project $Name
    if (-not $path.StartsWith($Project.Folder+'\temporarios\',[StringComparison]::OrdinalIgnoreCase)) { throw 'Destino temporario fora do projeto.' }
    if (-not (Test-Path -LiteralPath $path -PathType Container)) { return }
    $pending=New-Object 'Collections.Generic.Stack[IO.DirectoryInfo]'
    $pending.Push((Get-Item -LiteralPath $path))
    while ($pending.Count) {
        foreach ($child in $pending.Pop().EnumerateFileSystemInfos()) {
            if ($child.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Link/junction em temporarios; nao remover.' }
            if ($child -is [IO.DirectoryInfo]) { $pending.Push($child) }
        }
    }
    [IO.Directory]::Delete($path,$true)
    if (-not @(Get-ChildItem -LiteralPath $Project.TemporaryPath -Force).Count) { [IO.Directory]::Delete($Project.TemporaryPath) }
}

function Get-HarnessProjectTreePublication {
    param($Project,[string]$Prepared,[string]$Destination)
    $prepared=Resolve-ProjectPath $Prepared $Project.Folder
    if (-not (Test-Path -LiteralPath $prepared -PathType Container)) { throw 'Conjunto preparado ausente ou nao e uma pasta; diagnostico corrente preservado.' }
    $destination=Resolve-ProjectDocument $Project $Destination
    $writes=@{}
    foreach ($base in @($prepared,$destination)) {
        if (-not (Test-Path -LiteralPath $base -PathType Container)) { continue }
        $pending=New-Object 'Collections.Generic.Stack[IO.DirectoryInfo]'; $pending.Push((Get-Item -LiteralPath $base))
        while ($pending.Count) {
            foreach ($child in $pending.Pop().EnumerateFileSystemInfos()) {
                if ($child.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Link/junction no conjunto de diagnostico.' }
                if ($child -is [IO.DirectoryInfo]) { $pending.Push($child); continue }
                $relative=$Destination.TrimEnd('/','\')+'/'+$child.FullName.Substring($base.Length+1).Replace('\','/')
                if ($base -eq $prepared) { $writes[$relative]=[IO.File]::ReadAllBytes($child.FullName) }
                elseif (-not $writes.ContainsKey($relative)) { $writes[$relative]=$null }
            }
        }
    }
    $writes
}
