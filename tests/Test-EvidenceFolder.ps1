#requires -Version 5.1
$ErrorActionPreference='Stop'; Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'PlanningCurrentFixture.ps1')
$f=New-PlanningFixture 2
$cli=Install-PlanningCli $f
$project=$f.Projects[0]
$register=[IO.File]::ReadAllText($project.MigrationPath)
$entry='criar-pasta-evidencias.ps1'
$result=Invoke-PlanningCli $cli $entry @{Target=$project.Source;NoOpen=$true;IssueId='java::mandatory-1'}
Assert ($result.Code -eq 0) ('Indice corrente nao foi criado: '+$result.Output)
$index=Join-Path $project.EvidencePath 'LEIA-ME.md'
Assert ((Test-Path -LiteralPath $index) -and [IO.File]::ReadAllText($index).Contains('| Issue |')) 'Indice deve permitir relacionar anexos por issue.'
[IO.File]::AppendAllText($index,"`n| java::mandatory-1 | [Falha](<observacao.md>) | Texto humano |")
$before=Get-PlanningFixtureState $f
$result=Invoke-PlanningCli $cli $entry @{Target=$project.Source;NoOpen=$true}
Assert ($result.Code -eq 0 -and (Get-PlanningFixtureState $f) -ceq $before) 'Retomada deve preservar indice e arquivos; varias issues nao exigem novo seletor.'
$result=Invoke-PlanningCli $cli $entry @{Target=$project.Source;NoOpen=$true;IssueId='DEV-ALHEIA'}
Assert ($result.Code -eq 1 -and (Get-PlanningFixtureState $f) -ceq $before) 'Issue alheia deve ser recusada sem escrita.'
Assert ([IO.File]::ReadAllText($project.MigrationPath) -ceq $register) 'Pasta de evidencias nao deve modificar decisoes.'
Assert (-not (Test-Path -LiteralPath (Join-Path $f.Root '.harness/planning'))) 'Evidencias nao devem inicializar layout legado.'
'PASS: pasta corrente de evidencias, indice por issue, preservacao e recusa sem escrita.'
