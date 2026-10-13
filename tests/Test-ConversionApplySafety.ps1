#requires -Version 5.1
$ErrorActionPreference='Stop'; Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'ConversionFixture.ps1')
Import-Module (Join-Path $root 'scripts/HarnessProject.psm1') -Force -DisableNameChecking
$conversionModule=Import-Module (Join-Path $root 'tools/transicao/ConversaoPublicacao.psm1') -Force -DisableNameChecking -PassThru
$f=New-ConversionFixture
$plan=Add-ConversionPlan $f ('a'*32)
Write-ConversionFile $f.Register ([IO.File]::ReadAllText($f.Register).Replace('Conferir contrato',('[Plano](<'+$plan.PlanPath+'>)')))
$newPom=Join-Path $f.Area 'novo-checkout/pom.xml'; Write-ConversionFile $newPom '<project><artifactId>api</artifactId></project>'
$oldSourceFile=Join-Path $f.Source 'Classe.java'; Write-ConversionFile $oldSourceFile 'class Classe {}'
Write-ConversionFile (Join-Path (Split-Path $newPom -Parent) 'Classe.java') 'class Classe {}'
Write-ConversionFile $plan.PlanPath ("# Plano`n[Codigo](<"+$f.Source+">)`n[Classe](<"+$oldSourceFile+">)`n")
$result=Invoke-ConversionApply $f.Workspace $newPom -SourceLegado $f.Source
$project=Get-HarnessProjectReference $f.Workspace $newPom
$data=Get-Content -Raw $project.ContextPath|ConvertFrom-Json
Assert ($data.SelectedIssues[0].Scope -notmatch '\.harness[/\\]planning') 'Scope deve usar observacao convertida.'
$text=Get-Content -Raw $project.PlanPath
Assert ($text -match 'novo-checkout' -and $text -notmatch 'aplicacao[/\\]?%?') 'Raiz e arquivo do Source devem acompanhar associacao explicita.'
$f=New-ConversionFixture
Write-ConversionFile $f.Register ([IO.File]::ReadAllText($f.Register).Replace('<!-- mta:inicio -->','<!-- mta:inicio -->'+"`n"+'<!-- MTA {"RunId":"origem-nao-informada"} -->'))
$before=Get-ConversionState $f
Reject { Invoke-ConversionApply $f.Workspace $f.Pom } 'Registro MTA sem origem exige escolha explicita.'
Assert ((Get-ConversionState $f) -ceq $before) 'Origem nao resolvida nao autoriza publicacao parcial.'
# Simular editor externo tentando trocar artifactId durante preparo/publicacao.
$f=New-ConversionFixture
& $conversionModule {
    param($Pom)
    $script:originalConversionBuilder=${function:New-ConversionCoreFiles}
    $script:protectedPom=$Pom
    function script:New-ConversionCoreFiles($Inputs) {
        $refused=$false
        try { [IO.File]::WriteAllText($script:protectedPom,'<project><artifactId>trocado</artifactId></project>') } catch { $refused=$true }
        if (-not $refused) { throw 'POM foi alterado durante a conversao.' }
        & $script:originalConversionBuilder $Inputs
    }
} $f.Pom
try { $result=Invoke-ConversionApply $f.Workspace $f.Pom }
finally { & $conversionModule { Set-Item function:script:New-ConversionCoreFiles $script:originalConversionBuilder } }
Assert ($result.Project -eq 'api' -and [IO.File]::ReadAllText($f.Pom) -notmatch 'trocado') 'POM deve ficar estavel ate a publicacao terminar.'
Write-Host 'PASS: Scope, Source, origem MTA isolada e POM protegido.'
