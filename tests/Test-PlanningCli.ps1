#requires -Version 5.1
$ErrorActionPreference='Stop'; Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'PlanningCurrentFixture.ps1')
$f=New-PlanningFixture 1 @('a','b')
$cli=Install-PlanningCli $f
$base=@{NonInteractive=$true;NoOpen=$true;OutputFormat='Json'}
function Invoke-Json($Options) {
    $result=Invoke-PlanningCli $cli 'preparar-planejamento.ps1' $Options
    try { $json=$result.Output | ConvertFrom-Json } catch { throw ('CLI nao retornou JSON unico: '+$result.Output) }
    Assert ($json.ExitCode -eq $result.Code) 'Codigo do JSON diverge do processo.'
    $json
}
function Reject-Json($Options,[string]$Message) {
    $before=Get-PlanningFixtureState $f
    $result=Invoke-Json $Options
    Assert ($result.Status -eq 'FAILED' -and $result.ExitCode -eq 1) $Message
    Assert ((Get-PlanningFixtureState $f) -ceq $before) 'Falha de validacao alterou arquivos.'
}
Reject-Json $base 'Ambiguidade exige escolha explicita.'
foreach ($override in @(@{Target='desconhecido'},@{Target='a';SelectTarget=$true},@{Target='a';Operation='manter-migracao'},@{Target='a';SelectMigrationInput=$true},@{Target='a';NonInteractive=$false},@{Target='a';NoOpen=$false})) {
    $options=$base.Clone()
    foreach ($key in $override.Keys) { $options[$key]=$override[$key] }
    Reject-Json $options 'Entrada incoerente deve ser recusada.'
}
$options=$base.Clone(); $options.Target='a'
$p=Invoke-Json $options
Assert ($p.Status -eq 'PREPARED' -and $p.Artifacts.Project -ceq 'a') ('Preparo falhou: '+($p|ConvertTo-Json -Depth 8))
Assert (-not (Test-Path -LiteralPath $f.Projects[1].ContextPath)) 'Escolha afetou outro projeto.'
Assert (-not (Test-Path -LiteralPath $p.Artifacts.PlanPath)) 'Preparo criou plano ficticio.'
$again=Invoke-Json $options
Assert ($again.Artifacts.Reused -and $again.Artifacts.ContextPath -eq $p.Artifacts.ContextPath) 'CLI deve retomar o destino corrente.'
$before=Get-PlanningFixtureState $f
$missing=Invoke-PlanningCli $cli 'abrir-planejamento.ps1' @{Target='a';NoOpen=$true}
Assert ($missing.Code -eq 1 -and $missing.Output.Contains('ausente') -and (Get-PlanningFixtureState $f) -ceq $before) 'Ausencia de plano deve diagnosticar sem procurar historico.'
[IO.File]::WriteAllText($p.Artifacts.PlanPath,'PROPOSTA HUMANA')
[IO.File]::WriteAllText($p.Artifacts.TodoPath,'TAREFAS HUMANAS')
$options.Operation='revisar-lote'
$review=Invoke-Json $options
Assert ($review.Artifacts.ContextPath -eq $p.Artifacts.ContextPath -and [IO.File]::ReadAllText($p.Artifacts.PlanPath).Contains('PROPOSTA HUMANA')) 'Alias de revisao deve preservar a mesma proposta.'
Publish-HarnessProjectFiles $f.Projects[0] @{'projeto.json'=(@{pom=$f.Projects[0].Pom;mta=@{diretorio='ausente'}}|ConvertTo-Json)}
$before=Get-PlanningFixtureState $f
$opened=Invoke-PlanningCli $cli 'abrir-planejamento.ps1' @{Target='a';NoOpen=$true}
Assert ($opened.Code -eq 0 -and $opened.Output.Contains($p.Artifacts.PlanPath) -and $opened.Output.Contains($p.Artifacts.TodoPath)) 'Abertura deve usar ambos os documentos correntes sem MTA.'
Assert ((Get-PlanningFixtureState $f) -ceq $before) 'Abertura alterou arquivos.'
# Cancelamento do seletor interativo, sem abrir editor nem gravar.
Publish-HarnessProjectFiles $f.Projects[1] @{'atual/planejamento/plano.md'='PLANO B';'atual/planejamento/tarefas.md'='TAREFAS B'}
$module=Get-Module HarnessPlanning
$before=Get-PlanningFixtureState $f
& $module { function script:Read-Host { return '' } }
try { Reject { Get-HarnessCurrentPlanning $f.Context -Interactive } 'Cancelamento deve abortar a selecao.' }
finally { & $module { Remove-Item Function:Read-Host } }
Assert ((Get-PlanningFixtureState $f) -ceq $before) 'Cancelamento alterou arquivos.'
'PASS: CLI sem recibos, JSON, validacao antes de escrever, revisao, abertura e cancelamento.'
