#requires -Version 5.1
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'PlanningCurrentFixture.ps1')
Import-Module (Join-Path $root 'scripts/HarnessSprintPlanning.psm1') -Force -DisableNameChecking
$f=New-PlanningFixture 2 @('a','b')
$plan=New-HarnessCurrentPlanning $f.Context -Target a
$priority=New-HarnessPrioritizationContext $f.Context -Mode Recreate -Percentage 100 -Category mandatory
$null=Complete-Slice $f $priority
[IO.File]::WriteAllText($f.Projects[0].PlanPath,'Proposta humana corrente.')
$before=Get-PlanningFixtureState $f
$input=Get-HarnessSprintSources $f.Context $f.Context.Projects
Assert ($input.Projects.Count -eq 2 -and $input.Projects[0].Issues.Count -eq 2) 'Inventario corrente deve preservar projetos/issues.'
Assert ($input.Projects[0].RegisterValid -and $input.Projects[0].Issues[0].FichaPaths.Count -eq 1) 'Ficha corrente deve acompanhar a issue.'
Assert (@($input.References | Where-Object Path -EQ $f.Projects[0].PlanPath).Count -eq 1) 'Plano corrente ausente nas referencias.'
Assert (-not $input.PSObject.Properties['Fingerprint'] -and -not $input.Projects[0].PSObject.Properties['MigrationSnapshot']) 'Coleta nao deve criar snapshot/recibo.'
Assert ((Get-PlanningFixtureState $f) -ceq $before) 'Inventario gravou dados.'
$original=[IO.File]::ReadAllText($f.Projects[1].MigrationPath)
[IO.File]::WriteAllText($f.Projects[1].MigrationPath,'Registro sem tabela valida')
$missing=Get-HarnessSprintSources $f.Context $f.Context.Projects
Assert (-not $missing.Projects[1].RegisterValid -and $missing.Projects[0].Issues.Count -eq 2) 'Lacuna de um projeto nao deve eliminar outro.'
[IO.File]::WriteAllText($f.Projects[1].MigrationPath,$original)
Write-Host 'PASS: fontes correntes de sprints, fichas, plano, lacunas e nenhuma escrita.'
