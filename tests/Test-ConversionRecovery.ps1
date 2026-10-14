#requires -Version 5.1
$ErrorActionPreference='Stop'; Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'ConversionFixture.ps1')
Import-Module (Join-Path $root 'scripts/HarnessProject.psm1') -DisableNameChecking
Import-Module (Join-Path $root 'tools/transicao/ConversaoPublicacao.psm1') -DisableNameChecking
Import-Module (Join-Path $root 'tools/transicao/ConversaoValidacao.psm1') -DisableNameChecking
$f=New-ConversionFixture
$plan=Add-ConversionPlan $f ('a'*32)
[IO.File]::AppendAllText($f.Register,("`n[Plano](<"+$plan.PlanPath+">)`n"))
$origins=@($f.Pom,$f.Register,$plan.ContextPath,$plan.PlanPath,$plan.TodoPath)
$originalState=@($origins|ForEach-Object { $_+' '+(Get-Item -LiteralPath $_).LastWriteTimeUtc.Ticks+' '+(Get-FileHash -LiteralPath $_).Hash }) -join "`n"
$child=Join-Path $f.Area 'interromper-conversao.ps1'
Write-ConversionFile $child @'
param($HarnessRoot,$Workspace,$Pom)
$ErrorActionPreference='Stop'
Import-Module (Join-Path $HarnessRoot 'scripts/HarnessProject.psm1') -DisableNameChecking
Import-Module (Join-Path $HarnessRoot 'tools/transicao/ConversaoPublicacao.psm1') -DisableNameChecking
& (Get-Module HarnessProject) {
    $script:originalConversionWrite=${function:Write-ProjectPublishedFile}; $script:conversionWriteCount=0
    function script:Write-ProjectPublishedFile {
        param($Source,$Destination)
        & $script:originalConversionWrite $Source $Destination
        $script:conversionWriteCount++
        if ($script:conversionWriteCount -eq 1) { [Environment]::Exit(71) }
    }
}
$null=Invoke-ConversionApply -Workspace $Workspace -Pom $Pom
throw 'Fixture nao interrompeu a publicacao.'
'@
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $child -HarnessRoot $root -Workspace $f.Workspace -Pom $f.Pom
Assert ($LASTEXITCODE -eq 71) 'Processo filho deve morrer depois do primeiro arquivo publicado.'
$project=Get-HarnessProjectReference $f.Workspace $f.Pom
Assert (Test-Path -LiteralPath (Join-Path $project.TemporaryPath 'publicacao/recuperacao.json')) 'Publicacao interrompida conserva instrucoes de recuperacao.'
$before=Get-ConversionState $f
$checked=Test-ConversionCurrent $f.Workspace $f.Pom
Assert (-not $checked.Valid -and $checked.Status -ceq 'PENDENTE') 'Validar deve indicar recuperacao pendente, sem executa-la.'
Assert ((Get-ConversionState $f) -ceq $before) 'Leitura de validacao nao altera a publicacao interrompida.'
$result=Invoke-ConversionApply -Workspace $f.Workspace -Pom $f.Pom
Assert ($result.Status -ceq 'CONVERTIDO') 'Retomar Aplicar recupera a escrita parcial e publica o conjunto completo.'
Assert (-not (Test-Path -LiteralPath $project.TemporaryPath)) 'Retomada concluida encerra os temporarios de recuperacao.'
$afterOrigins=@($origins|ForEach-Object { $_+' '+(Get-Item -LiteralPath $_).LastWriteTimeUtc.Ticks+' '+(Get-FileHash -LiteralPath $_).Hash }) -join "`n"
Assert ($afterOrigins -ceq $originalState) 'Interrupcao e retomada preservam bytes e datas das fontes originais.'
$before=Get-ConversionState $f
$checked=Test-ConversionCurrent $f.Workspace $f.Pom
Assert $checked.Valid ('Conjunto retomado deve validar: '+($checked.Diagnostics|ConvertTo-Json -Compress))
Assert ((Invoke-ConversionApply -Workspace $f.Workspace -Pom $f.Pom).Status -ceq 'EQUIVALENTE') 'Reaplicar apos recuperar deve ser equivalente.'
Assert ((Get-ConversionState $f) -ceq $before) 'Validacao e reaplicacao nao regravam o conjunto recuperado.'
'PASS: morte apos primeiro arquivo, validacao sem recuperacao, retomada atomica e originais intactos.'
