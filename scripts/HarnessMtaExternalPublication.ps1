function New-MtaExternalStage {
    param($Location)
    $token=[guid]::NewGuid().ToString('N')
    $path=Resolve-ProjectPath (Join-Path $Location.Root ('.harness-mta-em-preparo/'+$token)) $Location.Root
    $null=[IO.Directory]::CreateDirectory($path)
    [pscustomobject]@{Root=$Location.Root;Token=$token;Path=$path;Output=(Join-Path $path 'saida')}
}

function Remove-MtaExternalStage {
    param($Stage)
    $expected=Join-Path $Stage.Root ('.harness-mta-em-preparo/'+$Stage.Token)
    $path=Resolve-ProjectPath $Stage.Path $Stage.Root
    if ($Stage.Token -notmatch '^[a-f0-9]{32}$' -or $path -ine $expected) { throw 'Identidade da saida temporaria MTA divergiu; preserve os arquivos.' }
    if (-not (Test-Path -LiteralPath $path -PathType Container)) { return }
    $pending=New-Object 'Collections.Generic.Stack[IO.DirectoryInfo]'
    $pending.Push((Get-Item -LiteralPath $path))
    while ($pending.Count) {
        foreach ($child in $pending.Pop().EnumerateFileSystemInfos()) {
            if ($child.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Link/junction na saida temporaria MTA; limpeza recusada.' }
            if ($child -is [IO.DirectoryInfo]) { $pending.Push($child) }
        }
    }
    [IO.Directory]::Delete($path,$true)
}

function Publish-MtaExternalReport {
    param($Project,$Location,$Stage,$Mta,[string]$Previous,[string]$Association)
    $access=Enter-HarnessProjectAccess $Project
    try {
        $current=Read-HarnessProjectFiles $Project @('projeto.json')
        if ($current['projeto.json'] -cne $Previous) { throw 'Associacao MTA editada durante a analise; publicacao interrompida.' }
        $parent=Resolve-ProjectPath $Location.Directory $Project.Root
        $output=Resolve-ProjectPath $Stage.Output $Project.Root
        $null=[IO.Directory]::CreateDirectory($parent)
        $destination=Join-Path $parent ([DateTime]::Now.ToString('yyMMdd-HHmmss-fff',[Globalization.CultureInfo]::InvariantCulture))
        # Move on the same external volume publishes a complete set; never overwrite a run.
        $null=Resolve-ProjectPath $destination $Project.Root
        [IO.Directory]::Move($output,$destination)
        if ($Association -cne $Previous) {
            Publish-HarnessProjectFiles $Project @{'projeto.json'=$Association} @{'projeto.json'=$Previous}
        }
        Join-Path $destination $Mta.ReportPath.Substring($output.Length+1)
    } finally { $access.ReleaseMutex(); $access.Dispose() }
}
