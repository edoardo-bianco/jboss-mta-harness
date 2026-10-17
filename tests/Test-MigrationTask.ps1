#requires -Version 5.1
$ErrorActionPreference='Stop'; Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'PlanningCurrentFixture.ps1')
$f=New-PlanningFixture 1 @('a','b')
$cli=Install-PlanningCli $f
$project=$f.Projects[0]
$tasks=Get-Content (Join-Path $root '.vscode/tasks.json') -Raw | ConvertFrom-Json
$task=@($tasks.tasks | Where-Object label -eq 'Planejamento: atualizar registro de migracao')
Assert ($task.Count -eq 1 -and $task[0].args -contains 'manter-migracao' -and $task[0].args -contains '-SelectMigrationInput') 'Reutilizar a Run Task de atualizacao do registro.'
$options=@{Operation='manter-migracao';NonInteractive=$true;NoOpen=$true;OutputFormat='Json'}
function Invoke-ReconciliationCli($Options) {
    $response=Invoke-PlanningCli $cli 'preparar-planejamento.ps1' $Options
    try { $data=$response.Output | ConvertFrom-Json } catch { throw $response.Output }
    Assert ($response.Code -eq $data.ExitCode) 'JSON deve corresponder ao codigo do processo.'
    $data
}
$before=Get-PlanningFixtureState $f
$result=Invoke-ReconciliationCli $options
Assert ($result.Status -eq 'FAILED' -and (Get-PlanningFixtureState $f) -ceq $before) 'Multiplos projetos exigem escolha sem gravar.'
# Reconciliar nao exige escolha ANALISAR AGORA.
[IO.File]::WriteAllText($project.MigrationPath,[IO.File]::ReadAllText($project.MigrationPath).Replace('ANALISAR AGORA','ADIAR'))
$register=[IO.File]::ReadAllBytes($project.MigrationPath)
$options.Target='a'
$result=Invoke-ReconciliationCli $options
Assert ($result.Status -eq 'PREPARED' -and $result.Operation -eq 'manter-migracao') ('Preparo falhou: '+($result|ConvertTo-Json -Depth 10))
$prepared=$result.Artifacts
$data=Read-Prepared $prepared
Assert ($data.Purpose -eq 'current-reconciliation' -and $data.Source -eq $project.Source) 'Contexto deve apontar o Source local.'
Assert (-not $data.PSObject.Properties['RunId'] -and -not $data.PSObject.Properties['Previous'] -and -not $data.PSObject.Properties['MtaStamp']) 'Contexto nao deve guardar recibo/historico/hashes.'
Assert (-not (Test-Path -LiteralPath $prepared.ReconciledPath) -and -not (Test-Path -LiteralPath $prepared.PlanPath)) 'Preparar nao cria conclusao ou plano.'
Assert ([Convert]::ToBase64String($register) -ceq [Convert]::ToBase64String([IO.File]::ReadAllBytes($project.MigrationPath))) 'Preparo alterou decisao humana.'
$again=Invoke-ReconciliationCli $options
Assert ($again.Artifacts.Reused) 'Mesmo preparo deve ser idempotente.'
$prompt=[IO.File]::ReadAllText($prepared.PromptPath)
Assert ($prompt.Contains('Complete-HarnessReconciliation') -and $prompt.Contains('current-reconciliation')) 'Prompt deve usar publicacao protegida corrente.'
$origin=Join-Path $f.Root 'pasta do colega'
$null=[IO.Directory]::CreateDirectory((Join-Path $origin 'atual/planejamento'))
[IO.File]::WriteAllText((Join-Path $origin 'atual/planejamento/plano.md'),'Proposta recebida')
$options.ReceivedPath=$origin
$result=Invoke-ReconciliationCli $options
Assert ($result.Status -eq 'PREPARED' -and (Read-Prepared $result.Artifacts).ReceivedPath -eq $origin) 'Pasta recebida explicita deve ser preparada.'
$options.Remove('ReceivedPath')
$result=Invoke-ReconciliationCli $options
Assert ((Read-Prepared $result.Artifacts).ReceivedPath -eq $origin) 'Retomada deve conservar a origem explicitamente associada.'
$options.LocalOnly=$true
$result=Invoke-ReconciliationCli $options
Assert ($result.Status -eq 'PREPARED' -and -not (Read-Prepared $result.Artifacts).ReceivedPath) 'Escolha somente local deve retirar associacao recebida.'
foreach ($override in @(@{ReceivedPath=$origin},@{SelectMigrationInput=$true},@{ContextPath=$prepared.ContextPath},@{PlanningBasis='MTA';Target='desconhecido'})) {
    $invalid=$options.Clone()
    foreach ($key in $override.Keys) { $invalid[$key]=$override[$key] }
    $before=Get-PlanningFixtureState $f
    $result=Invoke-ReconciliationCli $invalid
    Assert ($result.Status -eq 'FAILED' -and (Get-PlanningFixtureState $f) -ceq $before) 'Entrada incoerente deve falhar antes da escrita.'
}
$module=Get-Module HarnessPlanning
$before=Get-PlanningFixtureState $f
& $module { function script:Read-Host { return '' } }
try { Reject { New-HarnessReconciliationContext $f.Context -Interactive } 'Cancelamento deve interromper escolha.' }
finally { & $module { Remove-Item Function:Read-Host } }
Assert ((Get-PlanningFixtureState $f) -ceq $before) 'Cancelamento nao pode escrever.'
# EVIDENCIAS permanece utilizavel sem MTA e sem fallback silencioso.
Set-ManualPlanningChoice $project
Publish-HarnessProjectFiles $project @{'projeto.json'=(@{pom=$project.Pom;mta=@{diretorio='ausente'}}|ConvertTo-Json)}
$options.PlanningBasis='EVIDENCIAS'
$result=Invoke-ReconciliationCli $options
Assert ($result.Status -eq 'PREPARED' -and -not (Read-Prepared $result.Artifacts).Mta) 'EVIDENCIAS nao exige MTA.'
$review=Start-HarnessReconciliationReview $project -PlanningBasis EVIDENCIAS
$done=Complete-HarnessReconciliation $project -Conclusion 'Evidencia sintetica conferida; aplicabilidade humana permanece a revisar.'
Assert ($done.State -eq 'CONCLUIDA') 'Conclusao por evidencias deve funcionar sem MTA.'
$last=[IO.File]::ReadAllText($done.ReconciledPath)
$result=Invoke-ReconciliationCli $options
Assert ([IO.File]::ReadAllText($done.ReconciledPath) -ceq $last) 'Novo preparo nao apaga ultima conclusao.'
'PASS: Run Task/CLI corrente, escolhas, cancelamento, retomada, origem opcional e EVIDENCIAS sem MTA.'
