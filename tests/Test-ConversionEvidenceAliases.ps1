#requires -Version 5.1
$ErrorActionPreference='Stop'; Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'ConversionFixture.ps1')
Import-Module (Join-Path $root 'tools/transicao/ConversaoPublicacao.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $root 'scripts/HarnessProject.psm1') -DisableNameChecking
$f=New-ConversionFixture
$sourceC=Join-Path $f.Area 'cliente'; $pomC=Join-Path $sourceC 'pom.xml'
Write-ConversionFile $pomC '<project><artifactId>cliente</artifactId></project>'
$registerC=Join-Path $f.Workspace '.harness/projetos/cliente__123456789abc/migracao.md'
Write-ConversionFile $registerC ([IO.File]::ReadAllText($f.Register).Replace($f.Source,$sourceC))
$fixtureC=[pscustomobject]@{Workspace=$f.Workspace;Source=$sourceC;Register=$registerC}
$a=Add-ConversionPlan $f ('a'*32) -ProjectFolder 'api'
$c=Add-ConversionPlan $fixtureC ('c'*32) -ProjectFolder 'cliente'
$origin=Join-Path $f.Area 'original/contrato.md'
Write-ConversionFile $origin '# Evidencia humana compartilhada e recebida em duas copias.'
foreach ($plan in @($a,$c)) {
    $copy=Join-Path (Split-Path $plan.ContextPath -Parent) 'copias/renomeada.md'
    Write-ConversionFile $copy ([IO.File]::ReadAllText($origin))
    $plan|Add-Member EvidenceInputs @([pscustomobject]@{Path=$copy;OriginPath=$origin;Relation='Contrato recebido'})
    Write-ConversionFile $plan.ContextPath ($plan|ConvertTo-Json -Depth 15)
    Write-ConversionFile $plan.PlanPath ('# Plano humano: [Contrato](copias/renomeada.md)')
}
$participants=@{}; $participants[$f.Source]=@{Pom=$f.Pom;Contexto=$a.ContextPath}; $participants[$sourceC]=@{Pom=$pomC;Contexto=$c.ContextPath}
$null=Invoke-ConversionApply $f.Workspace $pomC -Participantes $participants
$projectC=Get-HarnessProjectReference $f.Workspace $pomC; $projectA=Get-HarnessProjectReference $f.Workspace $f.Pom
$target=Join-Path $projectC.EvidencePath 'contrato.md'
Assert ((Test-Path -LiteralPath $target) -and [IO.File]::ReadAllText($target) -match 'duas copias') 'Proprietario publica representante canonico mesmo quando esta no contexto de outro projeto.'
Assert ([IO.File]::ReadAllText($projectC.PlanPath) -match 'evidencias/contrato.md' -and [IO.File]::ReadAllText($projectC.PlanPath) -notmatch 'referencia legada indisponivel') 'Alias local do proprietario abre o anexo corrente.'
$null=Invoke-ConversionApply $f.Workspace $f.Pom -Participantes $participants
Assert (-not (Test-Path -LiteralPath (Join-Path $projectA.EvidencePath 'contrato.md'))) 'Outro consumidor nao duplica o anexo.'
Assert ([IO.File]::ReadAllText($projectA.PlanPath) -match 'cliente/evidencias/contrato.md') 'Plano do outro consumidor aponta ao proprietario comum.'
$before=Get-ConversionState $f
Assert ((Invoke-ConversionApply $f.Workspace $pomC -Participantes $participants).Status -eq 'EQUIVALENTE') 'Proprietario reaplica sem depender do alvo da primeira chamada.'
Assert ((Invoke-ConversionApply $f.Workspace $f.Pom -Participantes $participants).Status -eq 'EQUIVALENTE') 'Consumidor reaplica equivalente.'
Assert ((Get-ConversionState $f) -ceq $before) 'Aliases nao causam regravacao nem duplicacao.'
'PASS: representante canonico entre planos, dono estavel, links e reaplicacao.'
