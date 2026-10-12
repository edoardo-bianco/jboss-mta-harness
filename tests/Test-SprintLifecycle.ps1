#requires -Version 5.1
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'SprintCurrentFixture.ps1')
$f=New-SprintFixture @('a','b')
Reject { New-HarnessSprintContext $f.Context -All } 'Multiprojeto deve exigir mestre.'
$register=[IO.File]::ReadAllText($f.Projects[1].MigrationPath)
[IO.File]::WriteAllText($f.Projects[1].MigrationPath,'Registro incompleto')
$current=New-HarnessSprintContext $f.Context -All -MasterProject a
$result=Complete-HarnessSprintPlan $f.Root $current.ContextPath
Assert (-not $result.Baseline.Known -and $result.Feasibility -eq 'NAO_AVALIAVEL') 'Lacuna de registro nao pode congelar B0 desconhecida.'
[IO.File]::WriteAllText($f.Projects[1].MigrationPath,$register)
$resume=New-HarnessSprintContext $f.Context -ContextPath $current.ContextPath -Reason 'Registro agora disponivel'
$data=Read-SprintData $resume
Assert ($data.Baseline.Known -and $data.Baseline.Issues.Count -eq 4) 'Preparo deve formar B0 conhecida quando lacuna for resolvida.'
Set-SprintPremises $data
Save-SprintData $current $data
$result=Complete-HarnessSprintPlan $f.Root $current.ContextPath
Assert ($result.Baseline.Known) 'B0 conhecida deve permanecer no resultado corrente.'
Reject { New-HarnessSprintContext $f.Context -All -MasterProject b } 'Mesmo cenario nao pode ganhar segundo mestre.'
Reject { New-HarnessSprintContext $f.Context -ContextPath $current.ContextPath -Sources @($f.Projects[1].Source) -Reason 'Retirar mestre' } 'Mestre deve permanecer participante.'
$initialResult=[IO.File]::ReadAllText($current.ValidationPath)
$data.Baseline.Id='outra-base'; Save-SprintData $current $data
Reject { Complete-HarnessSprintPlan $f.Root $current.ContextPath } 'Alterar B0 publicada deve falhar.'
Assert ([IO.File]::ReadAllText($current.ValidationPath) -ceq $initialResult) 'Falha nao pode alterar resultado anterior.'
$data.Baseline.Id='B0'; Save-SprintData $current $data
$path=$f.Projects[0].MigrationPath
$row='| I-nova | Nova issue | mandatory | 1 | PRESENTE | ADIAR | NAO ANALISADA | Conferir |'
[IO.File]::WriteAllText($path,[IO.File]::ReadAllText($path).Replace('<!-- mta:fim -->',($row+[Environment]::NewLine+'<!-- mta:fim -->')))
$resume=New-HarnessSprintContext $f.Context -ContextPath $current.ContextPath -Reason 'Nova issue'
Reject { Complete-HarnessSprintPlan $f.Root $current.ContextPath } 'Inclusao deve aparecer separada de B0.'
$data=Read-SprintData $current
$data.Changes.New=@([pscustomobject]@{Project='a';Source=$f.Projects[0].Source;Id='I-nova'})
$data.EvidenceReview=[pscustomobject]@{Reviewed=$true;Reason='Nova issue examinada.'}
Save-SprintData $current $data
$added=Complete-HarnessSprintPlan $f.Root $current.ContextPath
Assert ($added.Baseline.Issues.Count -eq 4 -and $added.NewIssues.Count -eq 1) 'Inclusao nao pode reescrever B0.'
$data.Constraints.SprintStartDate='2026-10-13'; Save-SprintData $current $data
Reject { Complete-HarnessSprintPlan $f.Root $current.ContextPath } 'Calendario publicado deve manter inicio.'
$data.Constraints.SprintStartDate='2026-10-12'; $data.Constraints.ReferenceDate='2026-10-01'; Save-SprintData $current $data
Reject { Complete-HarnessSprintPlan $f.Root $current.ContextPath } 'Data de referencia nao pode retroceder.'
$data.Constraints.ReferenceDate='2026-10-12'; Save-SprintData $current $data
Reject { New-HarnessSprintContext $f.Context -ContextPath $current.ContextPath -Sources @($f.Projects[0].Source) } 'Mudanca de participantes exige motivo.'
$scope=New-HarnessSprintContext $f.Context -ContextPath $current.ContextPath -Sources @($f.Projects[0].Source) -Reason 'Retirar b do escopo'
Reject { Complete-HarnessSprintPlan $f.Root $current.ContextPath } 'Retirar projeto exige exclusao explicita de suas issues.'
$data=Read-SprintData $scope
$data.Changes.Excluded=@($data.Baseline.Issues | Where-Object Project -CEQ b)
$data.EvidenceReview=[pscustomobject]@{Reviewed=$true;Reason='Retirada explicita de b preserva denominador e inclusoes.'}
Save-SprintData $scope $data
$scoped=Complete-HarnessSprintPlan $f.Root $scope.ContextPath
Assert ($scoped.NewIssues.Count -eq 1 -and $scoped.Baseline.Issues.Count -eq 4) 'Mudanca de escopo deve preservar base e inclusoes.'
Assert ([IO.File]::ReadAllText($f.Projects[0].IndexPath).Contains('sprints/migracao/plano.md') -and -not [IO.File]::ReadAllText($f.Projects[1].IndexPath).Contains('sprints/migracao/plano.md')) 'Indices devem refletir participantes atuais.'
# Reassociacao explicita na fixture preserva identidade funcional e B0.
$newSource=Join-Path $f.Root 'novo-clone-a'
$null=[IO.Directory]::CreateDirectory($newSource)
Copy-Item -LiteralPath $f.Projects[0].Pom -Destination (Join-Path $newSource 'pom.xml')
$config=Get-Content -LiteralPath $f.Projects[0].ConfigPath -Raw | ConvertFrom-Json
$config.pom=Join-Path $newSource 'pom.xml'
Publish-HarnessProjectFiles $f.Projects[0] @{'projeto.json'=($config | ConvertTo-Json)}
$f.Context.Projects[0].path=$newSource
$relocated=New-HarnessSprintContext $f.Context -ContextPath $scope.ContextPath -Reason 'Source reassociado explicitamente'
$data=Read-SprintData $relocated
Assert (@($data.Baseline.Issues | Where-Object { $_.Project -ceq 'a' -and $_.Source -ieq $newSource }).Count -eq 2) 'Relocalizacao deve remapear Source sem novas issues.'
$data.EvidenceReview=[pscustomobject]@{Reviewed=$true;Reason='Clone local conferido.'}
Save-SprintData $relocated $data
$moved=Complete-HarnessSprintPlan $f.Root $relocated.ContextPath
Assert ($moved.Baseline.Issues.Count -eq 4 -and $moved.NewIssues.Count -eq 1) 'Relocalizacao alterou cobertura funcional.'
# Falha real de substituicao preserva conjunto calculado; nova tentativa recupera.
$beforeResult=[IO.File]::ReadAllText($current.ValidationPath)
$beforePlan=[IO.File]::ReadAllText($current.SprintPlanPath)
$data.Constraints.ProductionDeadline='2026-11-07'; Save-SprintData $current $data
$blocked=[IO.File]::Open($current.ValidationPath,'Open','Read','Read')
try {
    Reject { Complete-HarnessSprintPlan $f.Root $current.ContextPath } 'Arquivo bloqueado deve impedir publicacao.'
} finally { $blocked.Dispose() }
$null=Read-HarnessSprintContext $f.Root $current.ContextPath
Assert ([IO.File]::ReadAllText($current.ValidationPath) -ceq $beforeResult -and [IO.File]::ReadAllText($current.SprintPlanPath) -ceq $beforePlan) 'Falha deve restaurar plano/resultado juntos.'
$null=Complete-HarnessSprintPlan $f.Root $current.ContextPath
[IO.File]::Delete($f.Projects[0].IndexPath)
Update-HarnessSprintIndex $f.Root
Assert ([IO.File]::ReadAllText($f.Projects[0].IndexPath).Contains('sprints/migracao/plano.md')) 'Indice deve reconstruir link do mestre sem revisoes.'
Assert (@(Get-HarnessSprintScenarios $f.Root).Count -eq 1 -and -not (Test-Path (Join-Path $f.Root '.harness/sprints'))) 'Retomada deve independer de historico legado.'
Write-Host 'PASS: baseline, mestre unico, escopo, relocalizacao, falha recuperavel e indices de sprints.'
