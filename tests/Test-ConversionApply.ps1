#requires -Version 5.1
$ErrorActionPreference='Stop'; Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'ConversionFixture.ps1')
Import-Module (Join-Path $root 'scripts/HarnessProject.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $root 'tools/transicao/ConversaoPublicacao.psm1') -Force -DisableNameChecking
$f=New-ConversionFixture
$plan=Add-ConversionPlan $f ('a'*32)
[IO.File]::AppendAllText($f.Register,("`n[Plano](<"+$plan.PlanPath+">)`n"))
Write-ConversionFile $plan.PlanPath ("# Plano humano`n`nDecisao anterior: GO concedido para o escopo antigo.`n[Tarefas](<"+$plan.TodoPath+">)`n")
$originalRegister=[IO.File]::ReadAllBytes($f.Register)
$originalPlan=[IO.File]::ReadAllBytes($plan.PlanPath)
$result=Invoke-ConversionApply -Workspace $f.Workspace -Pom $f.Pom
$project=Get-HarnessProjectReference $f.Workspace $f.Pom
Assert ($result.Status -eq 'CONVERTIDO' -and (Test-Path $project.PlanPath)) 'Aplicar deve publicar arquivos correntes.'
$data=Get-Content -Raw $project.ContextPath|ConvertFrom-Json
Assert ($data.Purpose -eq 'current-planning' -and $data.NeedsReview -and $data.SelectedIssues[0].Id -eq 'java::regra') 'Contexto deve conservar escopo funcional e exigir revisao.'
Assert (-not $data.PSObject.Properties['RequestId'] -and -not $data.PSObject.Properties['Previous']) 'Contexto corrente nao pode ser recibo com outro nome.'
Assert (([Convert]::ToBase64String([IO.File]::ReadAllBytes($f.Register))) -ceq ([Convert]::ToBase64String($originalRegister))) 'Registro original deve permanecer intacto.'
Assert (([Convert]::ToBase64String([IO.File]::ReadAllBytes($plan.PlanPath))) -ceq ([Convert]::ToBase64String($originalPlan))) 'Plano original deve permanecer intacto.'
$converted=Get-Content -Raw $project.PlanPath
Assert ($converted -match 'GO concedido para o escopo antigo' -and $converted -match 'revisao' -and $converted -notmatch '\.harness[/\\]planning') 'Preservar declaracao humana, sem herdar GO nem depender do caminho antigo.'
$before=Get-ConversionState $f
$again=Invoke-ConversionApply -Workspace $f.Workspace -Pom $f.Pom
Assert ($again.Status -eq 'EQUIVALENTE' -and (Get-ConversionState $f) -ceq $before) 'Reaplicacao equivalente nao deve regravar arquivos.'
[IO.File]::AppendAllText($project.PlanPath,"`nTrabalho posterior do desenvolvedor.`n")
$before=Get-ConversionState $f
Reject { Invoke-ConversionApply -Workspace $f.Workspace -Pom $f.Pom } 'Trabalho posterior deve impedir sobrescrita.'
Assert ((Get-ConversionState $f) -ceq $before) 'Conflito deve preservar todos os arquivos.'
# Leitor permanente em processo limpo: nenhuma importacao do conversor/legado.
$reader=Join-Path $f.Area 'ler-corrente.ps1'
$readerText=@'
param($HarnessRoot,$Workspace,$Source)
$ErrorActionPreference='Stop'
Import-Module (Join-Path $HarnessRoot 'scripts/HarnessPlanning.psm1') -DisableNameChecking
$context=[pscustomobject]@{Root=$Workspace;Projects=@([pscustomobject]@{path=$Source;name='api';label='api'})}
$result=Get-HarnessCurrentPlanning $context -Target api
if (-not (Test-Path -LiteralPath $result.PlanPath) -or (Get-Module ConversaoPublicacao)) { throw 'Leitor depende da conversao.' }
Write-Host 'PASS: consumidor corrente sem modulo de conversao.'
'@
Write-ConversionFile $reader $readerText
$legacy=Join-Path $f.Workspace '.harness/planning'
$offline=Join-Path $f.Area 'legado-fora-do-workspace'
$fixtureRoot=[IO.Path]::GetFullPath((Join-Path $root '.harness/tests'))+'\'
foreach ($path in @($legacy,$offline)) { Assert ([IO.Path]::GetFullPath($path).StartsWith($fixtureRoot,[StringComparison]::OrdinalIgnoreCase)) 'Movimento deve ficar na fixture.' }
Move-Item -LiteralPath $legacy -Destination $offline
& powershell.exe -NoProfile -File $reader -HarnessRoot $root -Workspace $f.Workspace -Source $f.Source
Assert ($LASTEXITCODE -eq 0) 'Planejamento corrente deve abrir com os controles legados inacessiveis.'
Write-Host 'PASS: conversao corrente, originais intactos, GO revisavel, reaplicacao e conflito.'
