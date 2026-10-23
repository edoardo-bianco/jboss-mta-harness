#requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'

function New-HarnessJbossLogCursor {
    param([string]$Eap,[string]$Path,[ValidateRange(0,10000)][int]$Tail=100)
    [pscustomobject]@{Eap=$Eap;Path=$Path;Tail=$Tail;Position=0L;Created=$null;
        Initialized=$false;Missing=$false;Anchor='';Pending='';Decoder=[Text.Encoding]::UTF8.GetDecoder()}
}

function Read-HarnessJbossLog {
    param($Cursor)
    if (-not [IO.File]::Exists($Cursor.Path)) { $Cursor.Missing=$true; return }
    $stream=$null
    try {
        # Nao bloquear escrita, renomeacao ou exclusao pelo JBoss.
        $stream=[IO.File]::Open($Cursor.Path,'Open','Read',([IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete))
        $created=[IO.File]::GetCreationTimeUtc($Cursor.Path)
        $limit=$stream.Length
        $first=-not $Cursor.Initialized
        $reset=$first -or $Cursor.Missing -or $Cursor.Created -ne $created -or $limit -lt $Cursor.Position
        # Detectar tambem truncamento que voltou a crescer entre duas leituras.
        if (-not $reset -and $Cursor.Position -gt 0) {
            $count=[int][Math]::Min(64,$Cursor.Position)
            $anchor=New-Object byte[] $count
            $null=$stream.Seek($Cursor.Position-$count,'Begin')
            $read=$stream.Read($anchor,0,$count)
            $reset=$read -ne $count -or [Convert]::ToBase64String($anchor) -cne $Cursor.Anchor
        }
        if ($reset) { $Cursor.Position=0L; $Cursor.Pending=''; $Cursor.Decoder=[Text.Encoding]::UTF8.GetDecoder() }
        $Cursor.Created=$created; $Cursor.Missing=$false
        $null=$stream.Seek($Cursor.Position,'Begin')
        $buffer=New-Object byte[] 65536
        $chars=New-Object char[] ([Text.Encoding]::UTF8.GetMaxCharCount($buffer.Length))
        $tailLines=New-Object 'Collections.Generic.Queue[string]'
        while ($stream.Position -lt $limit) {
            $read=$stream.Read($buffer,0,[int][Math]::Min($buffer.Length,$limit-$stream.Position))
            if ($read -eq 0) { break }
            $count=$Cursor.Decoder.GetChars($buffer,0,$read,$chars,0,$false)
            $text=$Cursor.Pending+[string]::new($chars,0,$count)
            $lines=$text.Split([char]10)
            for ($i=0; $i -lt $lines.Length-1; $i++) {
                $line=$lines[$i].TrimEnd([char]13).TrimStart([char]0xFEFF)
                if ($first) {
                    $tailLines.Enqueue($line)
                    while ($tailLines.Count -gt $Cursor.Tail) { $null=$tailLines.Dequeue() }
                } else { Write-Output $line }
            }
            $Cursor.Pending=$lines[$lines.Length-1]
        }
        $Cursor.Position=$stream.Position
        $count=[int][Math]::Min(64,$Cursor.Position)
        $anchor=New-Object byte[] $count
        $null=$stream.Seek($Cursor.Position-$count,'Begin')
        $read=$stream.Read($anchor,0,$count)
        if ($read -ne $count) { $Cursor.Missing=$true }
        $Cursor.Anchor=[Convert]::ToBase64String($anchor)
        $Cursor.Initialized=$true
        if ($first) { $tailLines.ToArray() }
    } catch [IO.FileNotFoundException] { $Cursor.Missing=$true }
    catch [IO.DirectoryNotFoundException] { $Cursor.Missing=$true }
    finally { if ($stream) { $stream.Dispose() } }
}
Export-ModuleMember -Function New-HarnessJbossLogCursor,Read-HarnessJbossLog
