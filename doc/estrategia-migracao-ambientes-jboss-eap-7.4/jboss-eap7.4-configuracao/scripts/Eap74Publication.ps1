function Assert-EapPlainPath {
    param([string]$Path)
    $cursor=[IO.Path]::GetFullPath($Path)
    while ($cursor) {
        if (Test-Path -LiteralPath $cursor) {
            if ((Get-Item -LiteralPath $cursor -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Destino com link/junction nao permitido.' }
        }
        $cursor=Split-Path -Parent $cursor
    }
}
function Assert-EapStopped {
    param($Config)
    try {
        $processes=@(Get-CimInstance Win32_Process -ErrorAction Stop | Where-Object { $_.Name -in @('java.exe','javaw.exe','cmd.exe') })
        $listeners=@(Get-NetTCPConnection -ErrorAction Stop | Where-Object State -eq Listen)
    } catch { throw 'Nao foi possivel verificar processos/portas. Preparo/inicio recusado; confira permissoes de leitura do Windows.' }
    foreach ($process in $processes) {
        $command=[string]$process.CommandLine
        if (-not $command -and $process.Name -in @('java.exe','javaw.exe')) { throw 'Processo Java sem linha de comando acessivel; nao e possivel confirmar servidor parado.' }
        $normalized=$command.Replace('/','\')
        if ($normalized.IndexOf($Config.eapHome,[StringComparison]::OrdinalIgnoreCase) -ge 0 -and $command -match '(?i)jboss|standalone') { throw 'Servidor alvo ativo ou iniciando. Pare-o antes de preparar/iniciar novamente.' }
    }
    if (@($listeners | Where-Object { $_.LocalPort -in @((8080+$Config.portOffset),(9990+$Config.portOffset)) }).Count) { throw 'Porta HTTP/management ocupada: servidor possivelmente ativo. Nada sera preparado.' }
}
function Remove-EapStage {
    param([string]$Path,[string]$Parent)
    $resolved=[IO.Path]::GetFullPath($Path)
    if ((Split-Path -Parent $resolved) -ine [IO.Path]::GetFullPath($Parent) -or (Split-Path -Leaf $resolved) -notmatch '^\.eap-preparo-[0-9a-f]{32}$') { throw 'Limpeza temporaria fora do destino esperado recusada.' }
    if (Test-Path -LiteralPath $resolved) {
        $null=Get-EapTreeFiles $resolved
        Remove-Item -LiteralPath $resolved -Recurse -Force -ErrorAction Stop
    }
}
function Assert-EapOwnedOutput {
    param([string]$Output)
    Assert-EapPlainPath $Output
    if (-not (Test-Path -LiteralPath $Output)) { return }
    $marker=Join-Path $Output '.eap-preparo.json'
    if (-not (Test-Path -LiteralPath $marker -PathType Leaf)) { throw 'Consolidado existente desconhecido: sem manifesto de preparo. Preserve-o e escolha outra pasta output.' }
    $receipt=Read-EapJson $marker
    if ($receipt.schemaVersion -ne 1) { throw 'Manifesto do consolidado desconhecido.' }
    $actual=Get-EapTreeFiles $Output; $actual.Remove('.eap-preparo.json')
    $expected=@($receipt.files.PSObject.Properties)
    if ($actual.Count -ne $expected.Count) { throw 'Consolidado alterado: arquivos extras/ausentes. Preserve-o para analise e escolha outra pasta output.' }
    foreach ($file in $expected) {
        if (-not $actual.ContainsKey($file.Name) -or $actual[$file.Name] -cne $file.Value) { throw 'Consolidado alterado manualmente. Preserve-o para analise e escolha outra pasta output.' }
    }
}
function Write-EapAtomicFile {
    param([string]$Path,[byte[]]$Bytes)
    Assert-EapPlainPath $Path
    $temporary=$Path+'.eap-'+[guid]::NewGuid().ToString('N')
    try {
        [IO.File]::WriteAllBytes($temporary,$Bytes)
        if ([IO.File]::Exists($Path)) { [IO.File]::Replace($temporary,$Path,[NullString]::Value) }
        else { [IO.File]::Move($temporary,$Path) }
    } finally { if ([IO.File]::Exists($temporary)) { [IO.File]::Delete($temporary) } }
}
function Publish-EapTarget {
    param($Config,[string]$Source,[string[]]$Modules)
    $files=@(('standalone\configuration\'+$Config.standaloneConfig),'bin\standalone.conf.bat')
    foreach ($module in $Modules) {
        if (Test-Path -LiteralPath (Join-Path $Config.eapHome $module)) { continue } # Compatibilidade ja conferida; preservar datas.
        foreach ($file in (Get-EapTreeFiles (Join-Path $Source $module)).Keys) { $files+=Join-Path $module $file }
    }
    $changed=New-Object 'Collections.Generic.List[object]'
    $directories=New-Object 'Collections.Generic.List[string]'
    foreach ($relative in $files) { Assert-EapPlainPath (Join-Path $Config.eapHome $relative) }
    try {
        foreach ($relative in $files) {
            $target=Join-Path $Config.eapHome $relative; $origin=Join-Path $Source $relative
            $hash=(Get-FileHash -LiteralPath $origin -Algorithm SHA256).Hash
            if ([IO.File]::Exists($target) -and (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash -ceq $hash) { continue }
            $parent=Split-Path -Parent $target; $missing=@(); $cursor=$parent
            while (-not (Test-Path -LiteralPath $cursor)) { $missing+=$cursor; $cursor=Split-Path -Parent $cursor }
            foreach ($directory in $missing) { $directories.Add($directory) }
            $null=[IO.Directory]::CreateDirectory($parent)
            $before=$null; $time=$null
            if ([IO.File]::Exists($target)) { $before=[IO.File]::ReadAllBytes($target); $time=[IO.File]::GetLastWriteTimeUtc($target) }
            Write-EapAtomicFile $target ([IO.File]::ReadAllBytes($origin))
            $changed.Add([pscustomobject]@{Path=$target;Before=$before;Time=$time;Hash=$hash})
        }
    } catch {
        $failure=$_
        for ($i=$changed.Count-1; $i -ge 0; $i--) {
            $entry=$changed[$i]
            if (-not [IO.File]::Exists($entry.Path) -or (Get-FileHash -LiteralPath $entry.Path -Algorithm SHA256).Hash -cne $entry.Hash) { throw 'Publicacao interrompida e alteracao concorrente detectada; arquivos preservados para analise.' }
            if ($null -eq $entry.Before) { [IO.File]::Delete($entry.Path) }
            else { Write-EapAtomicFile $entry.Path $entry.Before; [IO.File]::SetLastWriteTimeUtc($entry.Path,$entry.Time) }
        }
        foreach ($directory in @($directories | Sort-Object Length -Descending)) {
            Assert-EapPlainPath $directory
            if ((Test-Path -LiteralPath $directory) -and -not @(Get-ChildItem -LiteralPath $directory -Force).Count) { [IO.Directory]::Delete($directory) }
        }
        throw $failure
    }
}
