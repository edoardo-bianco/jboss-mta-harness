function Read-TransferText {
    param($Archive,[string]$Entry)
    $item=$Archive.GetEntry($Entry)
    if (-not $item -or $item.Length -gt 32MB) { throw 'Documento do pacote ausente ou maior que 32 MiB.' }
    $reader=New-Object IO.StreamReader($item.Open())
    try {
        $buffer=New-Object char[] 8192; $text=[Text.StringBuilder]::new()
        while (($count=$reader.Read($buffer,0,$buffer.Length)) -gt 0) {
            if ($text.Length+$count -gt 32MB) { throw 'Texto descompactado excede 32 MiB.' }
            $null=$text.Append($buffer,0,$count)
        }
        $text.ToString()
    } finally { $reader.Dispose() }
}
function Convert-TransferDocument {
    param([string]$Text,[string]$OriginPath,$Mapping,[switch]$Register)
    # Resolver primeiro os links relativos na pasta original. Nao remapear duas vezes.
    $linked=[regex]::Replace($Text,'\]\((?:<(?<target>[^>\r\n]+)>|(?<target>[^\s)]+))\)',[Text.RegularExpressions.MatchEvaluator]{param($match)
        $target=$match.Groups['target'].Value
        if ($target -match '^(?:#|[a-zA-Z][a-zA-Z0-9+.-]*://|mailto:)' -or [IO.Path]::IsPathRooted($target)) { return $match.Value }
        $parts=$target -split '#',2
        $absolute=[IO.Path]::GetFullPath((Join-Path (Split-Path $OriginPath -Parent) $parts[0]))
        $mapped=Convert-TransferText $absolute $Mapping
        if ($mapped -ieq $absolute) { return $match.Value }
        # O remapeamento absoluto abaixo substitui este destino uma unica vez.
        $suffix=if ($parts.Count -gt 1) { '#'+$parts[1] } else { '' }
        '](<'+$absolute+$suffix+'>)'
    })
    if ($Register) { Convert-TransferRegisterText $linked $Mapping } else { Convert-TransferText $linked $Mapping }
}
function New-TransferMapping {
    param([Collections.IDictionary]$Paths)
    $replacements=@{}
    foreach ($key in $Paths.Keys) {
        foreach ($style in @('windows','slash','json')) {
            $old=([string]$key).Replace('/','\'); $new=([string]$Paths[$key]).Replace('/','\')
            if ($style -eq 'slash') { $old=$old.Replace('\','/'); $new=$new.Replace('\','/') }
            if ($style -eq 'json') { $old=$old.Replace('\','\\'); $new=$new.Replace('\','\\') }
            if ($old -ine $new) { $replacements[$old]=$new }
        }
    }
    $keys=@($replacements.Keys | Sort-Object Length -Descending | ForEach-Object { [regex]::Escape($_) })
    $pattern=if ($keys.Count) { '(?i)(?:'+($keys -join '|')+')(?=$|[\\/\s)#>"''\],])' } else { '(?!)' }
    [pscustomobject]@{Regex=[regex]::new($pattern);Replacements=$replacements}
}
function Convert-TransferText {
    param([string]$Text,$Mapping)
    $values=$Mapping.Replacements
    $Mapping.Regex.Replace($Text,[Text.RegularExpressions.MatchEvaluator]{param($m) [string]$values[$m.Value]})
}
function Convert-TransferValue {
    param($Value,$Mapping)
    if ($null -eq $Value) { return $null }
    if ($Value -is [string]) { return Convert-TransferText $Value $Mapping }
    if ($Value -is [Array]) { return ,@(foreach ($item in $Value) { Convert-TransferValue $item $Mapping }) }
    if ($Value -is [pscustomobject]) {
        $copy=[ordered]@{}
        foreach ($property in $Value.PSObject.Properties) {
            $copy[$property.Name]=Convert-TransferValue $property.Value $Mapping
            if ($property.Name -eq 'MtaOrigin' -and $property.Value) {
                # O Run e um localizador operacional; identidade da analise e historica.
                $copy[$property.Name].Source=$property.Value.Source
                $copy[$property.Name].Project=$property.Value.Project
            }
        }
        return [pscustomobject]$copy
    }
    $Value
}
function Get-TransferBytes {
    param([string]$Text)
    ,([Text.Encoding]::UTF8.GetBytes($Text))
}
function Convert-TransferRegisterText {
    param([string]$Text,$Mapping)
    $origins=@{}
    $masked=[regex]::Replace($Text,'<!-- MTA (\{[^\r\n]+\}) -->',[Text.RegularExpressions.MatchEvaluator]{param($match)
        $key='TRANSFER_ORIGIN_'+[guid]::NewGuid().ToString('N')
        $origin=$match.Groups[1].Value | ConvertFrom-Json
        $local=Convert-TransferValue $origin $Mapping
        $local.Source=$origin.Source; $local.Project=$origin.Project
        $origins[$key]='<!-- MTA '+($local | ConvertTo-Json -Depth 30 -Compress)+' -->'
        $key
    })
    $result=Convert-TransferText $masked $Mapping
    foreach ($key in $origins.Keys) { $result=$result.Replace($key,$origins[$key]) }
    $result
}
function Get-TransferBytesHash {
    param([byte[]]$Bytes)
    $stream=[IO.MemoryStream]::new($Bytes,$false)
    try { Get-TransferStreamHash $stream } finally { $stream.Dispose() }
}
function Add-TransferWrite {
    param($Writes,[string]$Path,[byte[]]$Bytes,[string]$Entry)
    if ($Writes.ContainsKey($Path)) { throw "Destino duplicado no pacote: $Path" }
    $Writes[$Path]=[pscustomobject]@{Path=$Path;Bytes=$Bytes;Entry=$Entry}
}
function Get-TransferWriteHash {
    param($Writes,[string]$Path,$Manifest)
    if (-not $Writes.ContainsKey($Path)) { return $null }
    $write=$Writes[$Path]
    if ($null -ne $write.Bytes) { return Get-TransferBytesHash $write.Bytes }
    (@($Manifest.Files | Where-Object Entry -CEQ $write.Entry)[0]).Sha256
}
