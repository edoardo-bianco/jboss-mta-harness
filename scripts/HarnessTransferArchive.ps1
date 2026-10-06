# ZIP e manifesto sao dados; nenhum caminho recebido autoriza escrita fora do destino.
function Assert-TransferRelativePath {
    param([string]$Path)
    if (-not $Path -or $Path.Length -gt 220 -or $Path.Contains('\') -or $Path.StartsWith('/') -or $Path -match '[\x00-\x1f:<>"|?*]') { throw "Caminho de pacote invalido: $Path" }
    foreach ($part in $Path.Split('/')) {
        if (-not $part -or $part -in @('.','..') -or $part -match '[. ]$|^(?i:CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(?:\.|$)') { throw "Caminho de pacote invalido: $Path" }
    }
}
function Assert-TransferRegularPath {
    param([string]$Path)
    $item=Get-Item -LiteralPath $Path -Force
    while ($item) {
        if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "Link/junction nao permitido no compartilhamento: $Path" }
        $item=if ($item -is [IO.DirectoryInfo]) { $item.Parent } else { $item.Directory }
    }
}
function Get-TransferStreamHash {
    param([IO.Stream]$Stream,[long]$ExpectedLength=-1)
    $sha=[Security.Cryptography.SHA256]::Create()
    try {
        $buffer=New-Object byte[] 65536; [long]$total=0
        while (($count=$Stream.Read($buffer,0,$buffer.Length)) -gt 0) {
            $total += $count
            if ($total -gt 512MB -or ($ExpectedLength -ge 0 -and $total -gt $ExpectedLength)) { throw 'Conteudo descompactado excede tamanho declarado/limite.' }
            $null=$sha.TransformBlock($buffer,0,$count,$buffer,0)
        }
        if ($ExpectedLength -ge 0 -and $total -ne $ExpectedLength) { throw 'Tamanho descompactado diverge do inventario.' }
        $null=$sha.TransformFinalBlock([byte[]]@(),0,0)
        ([BitConverter]::ToString($sha.Hash)).Replace('-','')
    } finally { $sha.Dispose() }
}
function Read-HarnessContextPackage {
    param([Parameter(Mandatory=$true)][string]$PackagePath)
    Assert-TransferRegularPath $PackagePath
    $zip=[IO.Compression.ZipFile]::OpenRead((Resolve-HarnessPath $PackagePath (Get-Location).Path))
    try {
        $entries=@{}; [long]$total=0
        if ($zip.Entries.Count -gt 20000) { throw 'Pacote excede 20000 entradas.' }
        foreach ($entry in $zip.Entries) {
            Assert-TransferRelativePath $entry.FullName
            if ($entries.ContainsKey($entry.FullName)) { throw 'Entrada ZIP duplicada (inclusive diferenca de caixa).' }
            if (($entry.ExternalAttributes -band 0x400) -or (($entry.ExternalAttributes -shr 16) -band 0xf000) -eq 0xa000) { throw 'Link em pacote ZIP recusado.' }
            $total += $entry.Length
            if ($entry.Length -gt 512MB -or $total -gt 2GB) { throw 'Pacote excede limite de 512 MiB por arquivo ou 2 GiB descompactados.' }
            $entries[$entry.FullName]=$entry
        }
        if (-not $entries.ContainsKey('manifest.json') -or $entries['manifest.json'].Length -gt 8MB) { throw 'Manifesto ausente ou maior que 8 MiB.' }
        $manifest=Read-TransferText $zip 'manifest.json' | ConvertFrom-Json
        if ($manifest.SchemaVersion -ne 1 -or $manifest.PackageId -cnotmatch '^[a-f0-9]{32}$' -or $manifest.Kind -notin @('PLANEJAMENTO','ANALISE')) { throw 'Versao/tipo/identidade de pacote nao suportado.' }
        $seen=@{}; $origins=@{}
        foreach ($file in $manifest.Files) {
            $origin=Get-TransferCanonicalPath $file.OriginPath
            if ($origins.ContainsKey($origin) -or $file.Role -notin @('CONTEXT','REGISTER','INDEX','INPUT_INDEX','ANNEX','DOCUMENT','PROMPT','EVIDENCE','MTA','RANKING','FICHA','INCIDENT')) { throw 'Origem duplicada ou papel desconhecido no inventario.' }
            $origins[$origin]=$true
            Assert-TransferRelativePath $file.Entry
            if ($file.Entry -eq 'manifest.json' -or $seen.ContainsKey($file.Entry) -or -not $entries.ContainsKey($file.Entry)) { throw 'Inventario duplicado ou arquivo ausente no ZIP.' }
            $seen[$file.Entry]=$true
            $entry=$entries[$file.Entry]
            if ($file.Sha256 -cnotmatch '^[A-Fa-f0-9]{64}$' -or [long]$file.Length -ne $entry.Length) { throw 'Metadados de integridade invalidos.' }
            $stream=$entry.Open()
            try { if ((Get-TransferStreamHash $stream $entry.Length) -ine $file.Sha256) { throw "Arquivo adulterado: $($file.Entry)" } } finally { $stream.Dispose() }
        }
        if ($seen.Count -ne ($entries.Count-1) -or -not $seen.ContainsKey($manifest.ContextEntry)) { throw 'Arquivo fora do inventario ou contexto ausente.' }
        $manifest
    } finally { $zip.Dispose() }
}
function Write-TransferArchive {
    param($Manifest,[string]$PackagePath)
    $path=Resolve-HarnessPath $PackagePath (Get-Location).Path
    if (Test-Path -LiteralPath $path) { throw 'Pacote ja existe; escolha outro destino.' }
    $parent=Split-Path $path -Parent
    if (-not (Test-Path -LiteralPath $parent -PathType Container)) { throw 'Pasta de destino do pacote ausente.' }
    Assert-TransferRegularPath $parent
    $temporary=$path+'.partial-'+[guid]::NewGuid().ToString('N')
    try {
        $zip=[IO.Compression.ZipFile]::Open($temporary,[IO.Compression.ZipArchiveMode]::Create)
        try {
            foreach ($file in $Manifest.Files) {
                Assert-TransferRegularPath $file.OriginPath
                $null=[IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip,$file.OriginPath,$file.Entry,[IO.Compression.CompressionLevel]::Optimal)
            }
            $writer=New-Object IO.StreamWriter($zip.CreateEntry('manifest.json').Open(),(New-Object Text.UTF8Encoding($false)))
            $transport=[ordered]@{}
            foreach ($key in $Manifest.Keys) { if ($key -ne '_FileIndex') { $transport[$key]=$Manifest[$key] } }
            try { $writer.Write(($transport | ConvertTo-Json -Depth 60)) } finally { $writer.Dispose() }
        } finally { $zip.Dispose() }
        $null=Read-HarnessContextPackage $temporary
        [IO.File]::Move($temporary,$path)
    } finally { if ([IO.File]::Exists($temporary)) { [IO.File]::Delete($temporary) } }
    [pscustomobject]@{PackageId=$Manifest.PackageId;Kind=$Manifest.Kind;PackagePath=$path;Files=$Manifest.Files.Count;Missing=$Manifest.Missing}
}
