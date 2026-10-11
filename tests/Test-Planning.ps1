#requires -Version 5.1
$ErrorActionPreference='Stop'; Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'PlanningCurrentFixture.ps1')
$f=New-PlanningFixture
$project=$f.Projects[0]; $register=[IO.File]::ReadAllText($project.MigrationPath)
$p=New-HarnessCurrentPlanning $f.Context
$data=Read-Prepared $p
Assert ($data.Project -ceq 'a' -and $data.PlanningBasis -eq 'MTA' -and $data.SelectedIssues.Count -eq 2) 'Planejamento deve partir das escolhas no registro e do POM.'
Assert ($p.PlanPath -eq $project.PlanPath -and $p.TodoPath -eq $project.TodoPath) 'Destinos devem ser correntes.'
Assert (-not (Test-Path -LiteralPath $p.PlanPath) -and -not (Test-Path -LiteralPath $p.TodoPath)) 'Preparo nao cria proposta ficticia.'
$stamp=[IO.File]::GetLastWriteTimeUtc($p.ContextPath)
$again=New-HarnessCurrentPlanning $f.Context
Assert ($again.Reused -and [IO.File]::GetLastWriteTimeUtc($p.ContextPath) -eq $stamp) 'Contexto sem plano deve retomar sem duplicar nem regravar.'
[IO.File]::WriteAllText($p.PlanPath,"# Proposta`n`nGO humano: conferir alcance na revisao.`n`nTEXTO MANUAL")
[IO.File]::WriteAllText($p.TodoPath,"# Tarefas`n`n- [ ] Teste focal")
$again=New-HarnessCurrentPlanning $f.Context
Assert ([IO.File]::ReadAllText($p.PlanPath).Contains('TEXTO MANUAL') -and [IO.File]::ReadAllText($p.PlanPath).Contains('MTA atual')) 'Atualizar fontes preserva proposta humana.'
$again=New-HarnessCurrentPlanning $f.Context
Assert ($again.Reused) 'Repeticao com plano/tarefas nao cria historico.'
[IO.File]::WriteAllText($project.MigrationPath,$register.Replace('| java::mandatory-1 | Problema 1 | mandatory | 1 | PRESENTE | ANALISAR AGORA |','| java::mandatory-1 | Problema 1 | mandatory | 1 | PRESENTE | ADIAR |'))
$changed=New-HarnessCurrentPlanning $f.Context
Assert ($changed.NeedsReview -and (Read-Prepared $changed).SelectedIssues.Count -eq 1) 'Mudanca de escopo deve sinalizar revisao.'
Assert ([IO.File]::ReadAllText($p.PlanPath).Contains('GO humano') -and [IO.File]::ReadAllText($p.PlanPath).Contains('Reavaliar proposta')) 'Nao apagar declaracao humana nem conservar GO por inferencia.'
$json=[IO.File]::ReadAllText($p.ContextPath)
foreach ($forbidden in @('RequestId','Previous','RunId','Sha256','Snapshot','Consolidated','MtaIssuePath')) { Assert (-not $json.Contains($forbidden)) ('Contexto corrente nao deve guardar '+$forbidden) }
Assert (@(Get-ChildItem -LiteralPath $project.Folder -Recurse -Filter contexto.json).Count -eq 1) 'Um contexto corrente, sem sucessor.'
Publish-HarnessProjectFiles $project @{'projeto.json'=(@{pom=$project.Pom;mta=@{diretorio='ausente'}}|ConvertTo-Json)}
$before=[IO.File]::ReadAllText($p.ContextPath)
Reject { New-HarnessCurrentPlanning $f.Context } 'MTA ausente nao pode trocar automaticamente a base.'
Assert ([IO.File]::ReadAllText($p.ContextPath) -ceq $before) 'Falha de origem preserva contexto.'
$opened=Get-HarnessCurrentPlanning $f.Context
Assert ($opened.PlanPath -eq $p.PlanPath) 'Abertura independe de MTA e de contexto aprovado.'
$manual=New-PlanningFixture 1 @('b')
Set-ManualPlanningChoice $manual.Projects[0]
Publish-HarnessProjectFiles $manual.Projects[0] @{'projeto.json'=(@{pom=$manual.Projects[0].Pom;mta=@{diretorio='ausente'}}|ConvertTo-Json)}
$p=New-HarnessCurrentPlanning $manual.Context
$data=Read-Prepared $p
Assert ($data.PlanningBasis -eq 'EVIDENCIAS' -and $null -eq $data.Mta -and $data.EvidenceInputs.Count -eq 1) 'Issue manual deve usar evidencia direta sem MTA inventado.'
Assert (-not @(Get-ChildItem -LiteralPath $manual.Projects[0].Folder -Recurse -File | Where-Object Name -eq 'apontamentos-mta.json').Count) 'Nao gerar extrato de MTA.'
'PASS: contexto corrente, retomada, escopo, fontes diretas, MTA/EVIDENCIAS e abertura sem origem.'
