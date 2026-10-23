#requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $root 'scripts/HarnessJbossLogs.psm1') -Force -DisableNameChecking
function Assert($condition,$message) { if (-not $condition) { throw $message } }
$area=Join-Path $root ('.harness/tests/logs-'+[guid]::NewGuid().ToString('N'))
$null=[IO.Directory]::CreateDirectory($area)
$a=New-HarnessJbossLogCursor 'eap71' (Join-Path $area 'a.log') 2
$b=New-HarnessJbossLogCursor 'eap74' (Join-Path $area 'b.log') 2
Assert (@(Read-HarnessJbossLog $a).Count -eq 0) 'Arquivo ausente deve aguardar sua criacao.'
[IO.File]::WriteAllText($a.Path,"antigo`num`ndois`n",(New-Object Text.UTF8Encoding $false))
[IO.File]::WriteAllText($b.Path,"outro`n",(New-Object Text.UTF8Encoding $false))
Assert ((@(Read-HarnessJbossLog $a) -join '|') -ceq 'um|dois') 'Tail inicial incorreto.'
Assert ((@(Read-HarnessJbossLog $b) -join '|') -ceq 'outro') 'Cursores de servidores interferem entre si.'
Assert (@(Read-HarnessJbossLog $a).Count -eq 0) 'Linhas repetidas sem alteracao.'
[IO.File]::AppendAllText($a.Path,'parcial')
Assert (@(Read-HarnessJbossLog $a).Count -eq 0) 'Linha parcial foi emitida antes de terminar.'
[IO.File]::AppendAllText($a.Path," completa`n")
Assert ((@(Read-HarnessJbossLog $a) -join '|') -ceq 'parcial completa') 'Linha parcial perdida/duplicada.'
$unicode='a'+[char]0xE7+[char]0xE3+'o'
$bytes=[Text.Encoding]::UTF8.GetBytes($unicode+"`n")
$stream=[IO.File]::Open($a.Path,'Append','Write','ReadWrite')
try { $stream.Write($bytes,0,2) } finally { $stream.Dispose() }
Assert (@(Read-HarnessJbossLog $a).Count -eq 0) 'UTF8 incompleto foi emitido.'
$stream=[IO.File]::Open($a.Path,'Append','Write','ReadWrite')
try { $stream.Write($bytes,2,$bytes.Length-2) } finally { $stream.Dispose() }
Assert ((@(Read-HarnessJbossLog $a) -join '|') -ceq $unicode) 'UTF8 partido entre leituras foi corrompido.'
[IO.File]::Move($a.Path,($a.Path+'.anterior'))
[IO.File]::WriteAllText($a.Path,"novo`n")
Assert ((@(Read-HarnessJbossLog $a) -join '|') -ceq 'novo') 'Rotacao nao reabriu arquivo pelo caminho.'
[IO.File]::WriteAllText($a.Path,"x`n")
Assert ((@(Read-HarnessJbossLog $a) -join '|') -ceq 'x') 'Truncamento nao reiniciou leitura.'
[IO.File]::WriteAllText($a.Path,"outra mensagem maior`n")
Assert ((@(Read-HarnessJbossLog $a) -join '|') -ceq 'outra mensagem maior') 'Truncamento seguido de crescimento perdeu inicio.'
[IO.File]::Delete($a.Path)
Assert (@(Read-HarnessJbossLog $a).Count -eq 0) 'Remocao durante acompanhamento falhou.'
[IO.File]::WriteAllText($a.Path,"recriado`n")
Assert ((@(Read-HarnessJbossLog $a) -join '|') -ceq 'recriado') 'Recriacao nao retomou leitura.'
Write-Output 'PASS: logs com tail, cursores independentes, append parcial/UTF8, ausencia, rotacao e truncamento; arquivos reais, nenhum servidor.'
if ($PSVersionTable.PSVersion.Major -eq 5) {
    $pwsh=Get-Command pwsh.exe -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($pwsh) {
        & $pwsh.Source -NoProfile -NonInteractive -File $PSCommandPath
        Assert ($LASTEXITCODE -eq 0) 'Suite de logs falhou em PS7.'
    }
}
