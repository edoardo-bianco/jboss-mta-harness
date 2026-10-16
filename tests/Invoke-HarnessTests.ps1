#requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string[]]$Test,
    [string]$ResultsPath
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot)).TrimEnd('\')
$names=@($Test | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Select-Object -Unique)
foreach ($name in $names) {
    if ($name -notmatch '^Test-[A-Za-z0-9-]+\.ps1$' -or -not (Test-Path -LiteralPath (Join-Path $PSScriptRoot $name) -PathType Leaf)) { throw "Suite invalida: $name" }
    if ($name -in @('Test-JbossReal.ps1','Test-BuildCoverage.ps1')) { throw 'Ensaios com ferramentas reais exigem checkout separado e parametros explicitos.' }
}
$raw=(& git -C $root -c core.quotepath=false ls-files -z) -join "`n"
if ($LASTEXITCODE -ne 0) { throw 'Execute a partir de um checkout Git do harness.' }
$files=@($raw.Split([char[]]@([char]0),[StringSplitOptions]::RemoveEmptyEntries))
foreach ($name in $names) {
    if ('tests/'+$name -notin $files) { throw "Adicione tests/$name ao Git antes de testa-lo; a copia usa somente arquivos versionados." }
}
$tempBase=[IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')
if ($tempBase -ieq $root -or $tempBase.StartsWith($root+'\',[StringComparison]::OrdinalIgnoreCase)) { throw 'TEMP deve ficar fora do checkout operacional.' }
$token=[guid]::NewGuid().ToString('N')
$area=Join-Path $tempBase ('harness-test-'+$token.Substring(0,12))
$copy=Join-Path $area 'checkout'
$marker=Join-Path $area 'owner.txt'
$results=New-Object 'Collections.Generic.List[object]'
$failed=$false
$null=[IO.Directory]::CreateDirectory($copy)
[IO.File]::WriteAllText($marker,$token)
try {
    foreach ($relative in $files) {
        if ($relative -match '^(\.harness/|\.git/|mcp/issues/node_modules/)' -or $relative -match '(^|/)[^/]*\.local\.' -or $relative -in @('.codex/config.toml','.vscode/mcp.json')) { continue }
        $source=[IO.Path]::GetFullPath((Join-Path $root $relative))
        if (-not $source.StartsWith($root+'\',[StringComparison]::OrdinalIgnoreCase)) { throw 'Arquivo versionado fora do checkout.' }
        if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { continue } # Exclusao local ainda nao adicionada ao indice.
        $cursor=$source
        while ($cursor -ine $root) {
            if ((Get-Item -LiteralPath $cursor -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "Link na entrada de teste: $relative" }
            $cursor=Split-Path -Parent $cursor
        }
        $destination=Join-Path $copy $relative
        $null=[IO.Directory]::CreateDirectory((Split-Path -Parent $destination))
        [IO.File]::Copy($source,$destination)
    }
    if ($ResultsPath) {
        $ResultsPath=[IO.Path]::GetFullPath($ResultsPath)
        $null=[IO.Directory]::CreateDirectory($ResultsPath)
    }
    foreach ($name in $names) {
        $log=Join-Path $area ($name+'.log')
        $started=[DateTime]::UtcNow
        # Cada suite tem um processo PS5.1 proprio e nenhum estado da maquina copiado.
        $previous=$ErrorActionPreference
        Push-Location $copy
        try {
            $ErrorActionPreference='Continue'
            & powershell.exe -NoProfile -NonInteractive -File (Join-Path $copy ('tests/'+$name)) *> $log
            $code=$LASTEXITCODE
        } finally { $ErrorActionPreference=$previous; Pop-Location }
        $results.Add([pscustomobject]@{Test=$name;ExitCode=$code;Seconds=[math]::Round(([DateTime]::UtcNow-$started).TotalSeconds,2)})
        $status=if ($code -eq 0) { 'PASS' } else { 'FAIL' }
        Write-Host ($status+': '+$name)
        if ($code -ne 0) { $failed=$true; Get-Content -LiteralPath $log -Tail 35 | Write-Host }
        if ($ResultsPath) { Copy-Item -LiteralPath $log -Destination (Join-Path $ResultsPath ($name+'.log')) }
    }
} finally {
    # Apagar somente o diretorio unico criado por esta chamada; nunca seguir links.
    if ([IO.Path]::GetFullPath((Split-Path $area -Parent)) -ine $tempBase -or (Split-Path $area -Leaf) -cne ('harness-test-'+$token.Substring(0,12)) -or [IO.File]::ReadAllText($marker) -cne $token) { throw 'Identidade do diretorio temporario mudou; limpeza recusada.' }
    $pending=New-Object 'Collections.Generic.Stack[IO.DirectoryInfo]'
    $directories=New-Object 'Collections.Generic.List[string]'
    $pending.Push((New-Object IO.DirectoryInfo ('\\?\'+$area)))
    while ($pending.Count) {
        $directory=$pending.Pop(); $directories.Add($directory.FullName)
        foreach ($item in $directory.EnumerateFileSystemInfos()) {
            if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
                if ($item -is [IO.DirectoryInfo]) { [IO.Directory]::Delete($item.FullName) } else { [IO.File]::Delete($item.FullName) }
            } elseif ($item -is [IO.DirectoryInfo]) { $pending.Push($item) }
            else { [IO.File]::SetAttributes($item.FullName,[IO.FileAttributes]::Normal); [IO.File]::Delete($item.FullName) }
        }
    }
    foreach ($directory in @($directories | Sort-Object Length -Descending)) { [IO.Directory]::Delete($directory) }
    if ($ResultsPath) {
        [pscustomobject]@{TemporaryRoot=$area;TemporaryRemoved=(-not [IO.Directory]::Exists($area));Tests=@($results.ToArray())} | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $ResultsPath 'resultado.json') -Encoding UTF8
    }
}
if ($failed) { exit 1 }
