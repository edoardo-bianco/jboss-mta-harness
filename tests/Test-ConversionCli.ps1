#requires -Version 5.1
$ErrorActionPreference='Stop'; Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'ConversionFixture.ps1')
$f=New-ConversionFixture
$plan=Add-ConversionPlan $f ('a'*32)
[IO.File]::AppendAllText($f.Register,("`n[Plano](<"+$plan.PlanPath+">)`n"))
$cli=Join-Path $root 'tools/transicao/Converter-RegistrosProjeto.ps1'
$before=Get-ConversionState $f
$json=& powershell.exe -NoProfile -File $cli -Workspace $f.Workspace -Pom $f.Pom -Formato Json
Assert ($LASTEXITCODE -eq 0) 'CLI JSON deve funcionar no PS5.1.'
$preview=($json -join "`n")|ConvertFrom-Json
Assert ($preview.Mode -eq 'Previa' -and $preview.Project -eq 'api') 'Modo padrao deve ser previa derivada do POM.'
$text=& $cli -Workspace $f.Workspace -Pom $f.Pom
Assert (($text -join "`n") -match 'Previa sem escrita' -and ($text -join "`n") -match 'PRELIMINAR') 'CLI deve mostrar limites e destino para revisao.'
foreach ($mode in @('Aplicar','Validar','Limpar')) { Reject { & $cli -Workspace $f.Workspace -Pom $f.Pom -Modo $mode } 'Modo futuro deve recusar sem escrita.' }
Assert ((Get-ConversionState $f) -ceq $before) 'CLI, JSON e modos nao entregues nao podem alterar arquivos.'
# O runtime permanente nao importa o utilitario descartavel.
$callers=@(Get-ChildItem (Join-Path $root 'scripts') -File | Select-String -Pattern 'ConversaoPrevia|Converter-RegistrosProjeto|tools[/\\]transicao')
Assert ($callers.Count -eq 0) 'Nucleo nao pode depender do conversor.'
Write-Host 'PASS: CLI PS5.1, JSON, recusas e independencia do runtime.'
