#requires -Version 5.1
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
function Assert($value, $message) { if (-not $value) { throw $message } }
function Reject($action, $message) { $failed=$false; try { & $action } catch { $failed=$true }; Assert $failed $message }
Import-Module (Join-Path $root 'scripts/HarnessSprintPlanning.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $root 'scripts/Harness.psm1') -Force -DisableNameChecking
$fixture=Join-Path $root ('.harness/tests/sprints-'+[guid]::NewGuid().ToString('N'))
$null=New-Item -ItemType Directory -Path $fixture -Force
$projects=@(foreach ($name in @('api um','agregador','sem registro')) {
    $source=Join-Path $fixture $name
    $null=New-Item -ItemType Directory -Path $source
    [IO.File]::WriteAllText((Join-Path $source 'pom.xml'),'<project><modelVersion>4.0.0</modelVersion><groupId>test</groupId><artifactId>sample</artifactId><version>1</version><packaging>pom</packaging></project>')
    [pscustomobject]@{name=$name.Replace(' ','-');label=$name;path=$source}
})
foreach ($file in @('.github/prompts/planejar-sprints.prompt.md','doc/modelos/planejamento-sprints.template.md','doc/features/planejamento-macro-sprints.md')) {
    $target=Join-Path $fixture $file
    $null=New-Item -ItemType Directory -Path (Split-Path $target -Parent) -Force
    if (Test-Path (Join-Path $root $file)) { Copy-Item -LiteralPath (Join-Path $root $file) -Destination $target }
    else { [IO.File]::WriteAllText($target,'Fixture de contrato') }
}
foreach ($project in $projects[0..1]) { $null=Initialize-HarnessMigration $fixture $project }
$register=(Get-HarnessMigrationPaths $fixture $projects[0]).MigrationPath
$text=[IO.File]::ReadAllText($register).Replace('<!-- mta:fim -->',"| issue-1 | Migrar API | mandatory | 2 | PRESENTE | ANALISAR AGORA | NAO ANALISADA | Evidencia pendente |`n<!-- mta:fim -->")
[IO.File]::WriteAllText($register,$text)
$hash=(Get-FileHash $register).Hash
$context=[pscustomobject]@{Root=$fixture;Projects=$projects;Active=$projects[0];WorkspacePath=(Join-Path $fixture 'teste.code-workspace')}
Reject { New-HarnessSprintContext -Context $context } 'Escopo nao pode vir implicitamente de Active.'
$receipt=New-HarnessSprintContext -Context $context -All
Assert ($receipt.Projects.Count -eq 3) 'Todos inclui agregador e projeto com lacuna.'
Assert ($receipt.SelectionMode -eq 'ALL' -and $receipt.Projects[2].Diagnostics.Count) 'Escopo/lacunas persistidos.'
$data=Get-Content -LiteralPath $receipt.SprintDataPath -Raw | ConvertFrom-Json
Assert ($null -eq $data.Constraints.SprintStartDate -and $null -eq $data.Constraints.MaxDevelopers) 'Datas/equipe devem ser obtidas pelo prompt, nao inventadas.'
Assert (-not $data.Baseline.Known -and @($data.Baseline.Issues).Count -eq 1) 'Registro ausente deixa denominador desconhecido, preservando issues conhecidas.'
Assert ((Get-FileHash $register).Hash -eq $hash) 'Preparo alterou registro.'
Assert (-not (Test-Path (Join-Path (Split-Path (Split-Path $receipt.ContextPath -Parent) -Parent) '../atual.json'))) 'Preparo nao publica ponteiro.'
$next=New-HarnessSprintContext -Context $context -PreviousContextPath $receipt.ContextPath
Assert ($next.RevisionId -eq $receipt.RevisionId -and $next.Reused) 'Entradas iguais devem retomar.'
$context.Projects += [pscustomobject]@{name='adicionado';label='adicionado';path=(Join-Path $fixture 'adicionado')}
$resumed=New-HarnessSprintContext -Context $context -PreviousContextPath $receipt.ContextPath
Assert ($resumed.Projects.Count -eq 3 -and $resumed.RevisionId -eq $receipt.RevisionId) 'Retomar ALL nao inclui novos projetos.'
[IO.File]::AppendAllText($register,"`nNova evidencia humana.`n")
Reject { New-HarnessSprintContext -Context $context -PreviousContextPath $receipt.ContextPath } 'Mudanca exige revisao explicita com motivo.'
$revised=New-HarnessSprintContext -Context $context -PreviousContextPath $receipt.ContextPath -Reason 'Atualizar evidencia'
Assert ($revised.PlanningId -eq $receipt.PlanningId -and $revised.RevisionId -ne $receipt.RevisionId) 'Revisao preserva cenario e historico.'
Assert ((Get-Content $receipt.ContextPath -Raw | ConvertFrom-Json).RevisionId -eq $receipt.RevisionId) 'Revisao sobrescreveu origem.'
$subset=New-HarnessSprintContext -Context $context -Sources @($projects[1].path)
Assert ($subset.Projects.Count -eq 1 -and $subset.SelectionMode -eq 'SUBSET') 'Subconjunto deve ser concreto.'
Reject { New-HarnessSprintContext -Context $context -Sources @('C:\fora-do-workspace') } 'Source fora do workspace foi aceito.'
$lock=[IO.File]::Open((Join-Path $fixture '.harness/sprints.lock'),[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
try { Reject { New-HarnessSprintContext -Context $context -All } 'Preparo concorrente deve falhar.' } finally { $lock.Dispose() }
Write-Output 'PASS: escopo, lacunas, hashes, retomada, revisao e preservacao de entradas de sprints.'
