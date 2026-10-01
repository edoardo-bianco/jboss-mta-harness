#requires -Version 5.1
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $root 'scripts/Harness.psm1') -Force -DisableNameChecking
function Assert($value, $message) { if (-not $value) { throw $message } }
function Reject($action, $expected) {
    $failure = $null
    try { & $action } catch { $failure = $_.Exception.Message }
    Assert ($failure -and $failure.Contains($expected)) "Erro esperado: $expected; recebido: $failure"
}
$area = Join-Path $root ('.harness/tests/editor ' + [guid]::NewGuid().ToString('N'))
$bin = Join-Path $area 'VS Code portable/bin'
$null = [IO.Directory]::CreateDirectory($bin)
$exe = Join-Path (Split-Path -Parent $bin) 'Code.exe'
[IO.File]::WriteAllText($exe,'Nao executar o aplicativo diretamente.')
$cli = Join-Path $bin 'code.cmd'
$capture = Join-Path $bin 'args.txt'
$success = @'
@echo off
> "%~dp0args.txt" echo "%~1"
>> "%~dp0args.txt" echo "%~2"
>> "%~dp0args.txt" echo "%~3"
exit /b 0
'@
[IO.File]::WriteAllText($cli,$success.Replace("`n","`r`n"),[Text.Encoding]::ASCII)
$files = @((Join-Path $area 'prompt & teste.md'), (Join-Path $area 'todo.md'))
foreach ($file in $files) { [IO.File]::WriteAllText($file,'Preservar conteudo.') }
$hashes = @($files | ForEach-Object { (Get-FileHash -LiteralPath $_).Hash })
Open-HarnessEditor -EditorPath $exe -FilePaths $files -Root $root
$actual = @(Get-Content -LiteralPath $capture | ForEach-Object { $_.Trim('"') })
Assert ($actual.Count -eq 3 -and $actual[0] -eq '--reuse-window' -and $actual[1] -eq $files[0] -and $actual[2] -eq $files[1]) 'CLI deve receber somente abertura e caminhos literais, sem chat/envio.'
Open-HarnessEditor -EditorPath $cli -FilePaths $files[0] -Root $root
$insiders = Join-Path (Split-Path -Parent $bin) 'Code - Insiders.exe'
[IO.File]::WriteAllText($insiders,'Nao executar o aplicativo diretamente.')
Copy-Item -LiteralPath $cli -Destination (Join-Path $bin 'code-insiders.cmd')
Open-HarnessEditor -EditorPath $insiders -FilePaths $files[0] -Root $root
Reject { Open-HarnessEditor -EditorPath (Join-Path $area 'ausente.exe') -FilePaths $files -Root $root } 'Executavel do editor nao encontrado'
Reject { Open-HarnessEditor -EditorPath $cli -FilePaths (Join-Path $area 'ausente.md') -Root $root } 'Arquivo para abrir nao encontrado'
$missingCliExe = Join-Path $area 'Code.exe'
[IO.File]::WriteAllText($missingCliExe,'Nao usar outra instalacao pelo PATH.')
Reject { Open-HarnessEditor -EditorPath $missingCliExe -FilePaths $files -Root $root } 'CLI do VS Code nao encontrada'
[IO.File]::WriteAllText($cli,"@echo off`r`nexit /b 23",[Text.Encoding]::ASCII)
Reject { Open-HarnessEditor -EditorPath $exe -FilePaths $files -Root $root } 'Editor retornou codigo 23'
for ($i=0; $i -lt $files.Count; $i++) { Assert ((Get-FileHash -LiteralPath $files[$i]).Hash -eq $hashes[$i]) 'A abertura alterou documento.' }
Write-Output 'PASS: CLI da mesma instalacao, portable/Insiders, caminhos com espacos, multiplos arquivos, falhas e preservacao.'
