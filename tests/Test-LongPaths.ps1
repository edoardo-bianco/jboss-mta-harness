#requires -Version 5.1
param([string]$HarnessModule)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
if (-not $HarnessModule) { $HarnessModule = Join-Path $root 'scripts/Harness.psm1' }
$module = Import-Module $HarnessModule -Force -PassThru -DisableNameChecking
function Assert($condition, $message) { if (-not $condition) { throw $message } }
$area = Join-Path $root ('.harness/tests/long-' + [guid]::NewGuid().ToString('N').Substring(0,8))
$source = Join-Path $area 'source'
$destination = Join-Path $area ('snapshot/' + ('segmento/' * 24) + 'input')
$null = [IO.Directory]::CreateDirectory($source)
[IO.File]::WriteAllText((Join-Path $source 'pom.xml'), '<project/>')
$files = @(Get-HarnessFiles $source)
Assert ((Join-Path $destination 'pom.xml').Length -gt 260) 'Fixture de destino nao ultrapassou MAX_PATH.'
& $module { param($s,$d,$f) Copy-HarnessFiles $s $d $f } $source $destination $files
Assert ((@(Get-HarnessFiles $destination) | ConvertTo-Json -Compress) -ceq ($files | ConvertTo-Json -Compress)) 'Copia longa perdeu arquivo/hash.'
# Fonte longa, unicode, espacos, colchetes literais e arquivo binario.
$relative = ('pacote/' * 24) + ([char]0x00e7) + 'odigo [v2]/AutorizacaoPreviaRedirecionamentoDTO.java'
$file = Join-Path $source $relative
$null = [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName(('\\?\' + $file)))
$bytes = [byte[]](0..255)
[IO.File]::WriteAllBytes(('\\?\' + $file), $bytes)
Assert ($file.Length -gt 260) 'Fonte longa nao foi exercitada.'
foreach ($entry in @('target/ignorar.txt','.git/config','.harness/state','.mvn/maven.config','modulo/pom.xml','modulo/target/ignorar.txt','livre/target/manter.txt')) {
    $path = Join-Path $source $entry
    $null = [IO.Directory]::CreateDirectory((Split-Path -Parent $path))
    [IO.File]::WriteAllText($path, 'fixture')
}
$files = @(Get-HarnessFiles $source)
Assert ($files.path -contains $relative) 'Nome relativo longo foi alterado.'
Assert ($files.path -contains '.mvn/maven.config' -and $files.path -contains 'livre/target/manter.txt') 'Exclusao removeu entrada valida.'
Assert (-not ($files.path -match '^target/|^\.git/|^\.harness/|^modulo/target/')) 'Exclusoes foram perdidas.'
$copy = Join-Path $area 'copy'
& $module { param($s,$d,$f) Copy-HarnessFiles $s $d $f } $source $copy $files
Assert ((@(Get-HarnessFiles $copy) | ConvertTo-Json -Compress) -ceq ($files | ConvertTo-Json -Compress)) 'Hashes de fonte longa divergiram.'
[IO.File]::WriteAllText(('\\?\' + (Join-Path $copy $relative)), 'mudanca')
Assert ((Get-HarnessFiles $copy | Where-Object path -CEQ $relative).sha256 -cne ($files | Where-Object path -CEQ $relative).sha256) 'Alteracao longa nao detectada.'
[IO.File]::WriteAllText(('\\?\' + $file), 'mudanca durante copia')
$rejected = $false
try { & $module { param($s,$d,$f) Copy-HarnessFiles $s $d $f } $source (Join-Path $area 'stale') $files } catch { $rejected = $_.Exception.Message -match 'Entrada mudou' }
Assert $rejected 'Copia aceitou hash antigo.'
$link = Join-Path $source 'junction'
$null = New-Item -ItemType Junction -Path $link -Target $copy
try {
    $rejected = $false
    try { Get-HarnessFiles $source | Out-Null } catch { $rejected = $_.Exception.Message -match 'Link/junction' }
    Assert $rejected 'Enumeracao aceitou junction.'
} finally { [IO.Directory]::Delete($link) }
Write-Output 'PASS: destino/fonte >260, nomes literais, hashes, exclusoes, alteracao e junction.'
