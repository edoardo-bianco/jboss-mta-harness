#requires -Version 5.1
$ErrorActionPreference='Stop'; Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'PlanningCurrentFixture.ps1')
$f=New-PlanningFixture 1
$p=$f.Projects[0]
Set-ManualPlanningChoice $p
$prepared=New-HarnessCurrentPlanning $f.Context
Publish-HarnessProjectFiles $p @{'atual/planejamento/plano.md'='GO humano na origem';'atual/planejamento/tarefas.md'='Tarefas humanas'}
Assert (-not $prepared.NeedsReview) 'Primeiro preparo nao deve sinalizar mudanca inexistente.'
$source=Join-Path $f.Root 'outro-checkout'
$null=[IO.Directory]::CreateDirectory($source)
Copy-Item -LiteralPath $p.Pom -Destination (Join-Path $source 'pom.xml')
Publish-HarnessProjectFiles $p @{'projeto.json'=(@{pom=(Join-Path $source 'pom.xml')} | ConvertTo-Json)}
$f.Context.Projects[0].path=$source
$prepared=New-HarnessCurrentPlanning $f.Context
Assert ($prepared.NeedsReview -and (Read-Prepared $prepared).Source -eq $source) 'Reassociar Source/POM deve atualizar referencias e exigir revisao do alcance do GO.'
Assert ([IO.File]::ReadAllText($p.PlanPath).Contains('GO humano na origem')) 'Declaracao humana deve permanecer para revisao.'
'PASS: reassociacao explicita do POM no mesmo workspace exige revisao da autorizacao.'
