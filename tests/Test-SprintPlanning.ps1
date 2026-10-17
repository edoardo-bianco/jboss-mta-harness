#requires -Version 5.1
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'SprintCurrentFixture.ps1')
$f=New-SprintFixture @('a','b')
Reject { New-HarnessSprintContext $f.Context } 'Active nao define escopo macro.'
Reject { New-HarnessSprintContext $f.Context -All -Sources @($f.Projects[0].Source) } 'Todos e subconjunto nao podem coexistir.'
Reject { New-HarnessSprintContext $f.Context -Sources @('C:\fora-do-workspace') } 'Source fora do workspace nao pode entrar.'
$current=New-HarnessSprintContext $f.Context -All -MasterProject a
$data=Read-SprintData $current
Assert ($null -eq $data.Constraints.SprintStartDate -and $null -eq $data.Constraints.MaxDevelopers) 'Preparo nao inventa datas/equipe.'
Assert ($current.Projects.Count -eq 2 -and $current.SelectionMode -eq 'ALL') 'Escopo deve conter participantes concretos.'
foreach ($project in $f.Projects) {
    Assert ([IO.File]::ReadAllText($project.IndexPath).Contains('sprints/migracao/plano.md')) 'Participante deve apontar ao unico mestre.'
}
[IO.File]::AppendAllText($current.PromptPath,([Environment]::NewLine+'Nota humana do prompt.'))
$resumed=New-HarnessSprintContext $f.Context -ContextPath $current.ContextPath
Assert ($resumed.Reused -and $resumed.ContextPath -eq $current.ContextPath -and [IO.File]::ReadAllText($current.PromptPath).Contains('Nota humana')) 'Retomada deve preservar destino/notas.'
# Retomar ALL preserva lista original, mesmo quando o workspace ganha projeto.
$newSource=Join-Path $f.Root 'novo-projeto'; $null=[IO.Directory]::CreateDirectory($newSource)
[IO.File]::WriteAllText((Join-Path $newSource 'pom.xml'),'<project><artifactId>novo</artifactId></project>')
$f.Context.Projects+=@([pscustomobject]@{name='novo';label='novo';path=$newSource})
$resumed=New-HarnessSprintContext $f.Context -ContextPath $current.ContextPath
Assert ($resumed.Projects.Count -eq 2) 'Retomar nao pode ampliar ALL implicitamente.'
$f.Context.Projects=@($f.Context.Projects | Where-Object name -NE novo)
$cli=Install-PlanningCli $f
$new=Invoke-PlanningCli $cli 'preparar-sprints.ps1' @{Action='New';All=$true;Scenario='cli';MasterProject='a';NoOpen=$true;OutputFormat='Json'}
Assert ($new.Code -eq 0) ('CLI deve preparar cenario: '+$new.Output)
$prepared=$new.Output | ConvertFrom-Json
$next=Invoke-PlanningCli $cli 'preparar-sprints.ps1' @{Action='Resume';ContextPath=$prepared.ContextPath;NoOpen=$true;OutputFormat='Json'}
Assert ($next.Code -eq 0 -and ($next.Output | ConvertFrom-Json).ContextPath -eq $prepared.ContextPath) 'CLI deve retomar sem revisao.'
$validated=Invoke-PlanningCli $cli 'preparar-sprints.ps1' @{Action='Validate';ContextPath=$prepared.ContextPath;NoOpen=$true;OutputFormat='Json'}
Assert ($validated.Code -eq 0 -and ($validated.Output | ConvertFrom-Json).Feasibility -eq 'NAO_AVALIAVEL') ('Rascunho incompleto deve explicitar lacunas: '+$validated.Output)
$raw=[IO.File]::ReadAllText($prepared.ContextPath)
Assert ($raw -notmatch '"(PlanningId|RevisionId|Previous|InputFingerprint|MigrationSnapshot|Sha256)"') 'Contexto nao pode exigir rastreamento legado.'
Write-Host 'PASS: escopo explicito, mestre, retomada, notas e CLI corrente de sprints.'
