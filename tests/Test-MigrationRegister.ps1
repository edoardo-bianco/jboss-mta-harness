#requires -Version 5.1
$ErrorActionPreference='Stop'; Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'PlanningCurrentFixture.ps1')
$f=New-PlanningFixture 2
$p=$f.Projects[0]
$text=[IO.File]::ReadAllText($p.MigrationPath).Replace('| ANALISAR AGORA | NAO ANALISADA |','| ADIAR | ANALISADA |')
$text=$text.Replace('<!-- mta:fim -->',"| DEV-001 | Adicional | manual | - | MANUAL | ANALISAR AGORA | NAO ANALISADA | Evidencia local |`n<!-- mta:fim -->")
$text+="`nDecisao humana fora da tabela: preservar javax."
[IO.File]::WriteAllText($p.MigrationPath,$text)
Set-FixtureMta $p 1
$before=[IO.File]::ReadAllText($p.MigrationPath)
$prepared=New-HarnessReconciliationContext $f.Context
Assert ([IO.File]::ReadAllText($p.MigrationPath) -ceq $before -and -not (Test-Path -LiteralPath $prepared.ReconciledPath)) 'Preparar nao carrega catalogo nem conclui reconciliacao.'
$review=Start-HarnessReconciliationReview $p
$done=Complete-HarnessReconciliation $p -Conclusion 'Diagnostico corrente conferido; ausencia nao prova correcao.'
$text=[IO.File]::ReadAllText($p.MigrationPath)
Assert ($text.Contains('| NAO REENCONTRADA | ADIAR | ANALISADA |') -and $text.Contains('DEV-001') -and $text.Contains('Decisao humana fora da tabela')) 'Atualizar fatos deve preservar decisoes, andamento, manuais e texto.'
$present=@(Get-HarnessProjectDecisions $p | Where-Object Presence -EQ 'PRESENTE')
Assert ($present.Count -eq 1 -and $present[0].Count -eq '1') 'Registro deve refletir apenas o catalogo atual como presente.'
$catalog=(Read-HarnessProjectMta $p).CatalogPath
$original=[IO.File]::ReadAllBytes($catalog)
foreach ($invalid in @('window["apps"] = []; malicious();','window["apps"] = [{"rulesets":null}];')) {
    [IO.File]::WriteAllText($catalog,$invalid)
    $before=Get-PlanningFixtureState $f
    Reject { New-HarnessReconciliationContext $f.Context } 'MTA arbitrario/incompleto nao pode simular catalogo vazio.'
    Assert ((Get-PlanningFixtureState $f) -ceq $before) 'Falha de MTA alterou documentos.'
}
[IO.File]::WriteAllBytes($catalog,$original)
[IO.File]::WriteAllText($p.MigrationPath,$text.Replace('<!-- mta:fim -->',"| linha invalida |`n<!-- mta:fim -->"))
$before=Get-PlanningFixtureState $f
Reject { New-HarnessReconciliationContext $f.Context } 'Tabela invalida exige conciliacao.'
Assert ((Get-PlanningFixtureState $f) -ceq $before) 'Tabela invalida perdeu escolhas.'
[IO.File]::WriteAllText($p.MigrationPath,$text)
Set-FixtureMta $p 0
$review=Start-HarnessReconciliationReview $p
$done=Complete-HarnessReconciliation $p -Conclusion 'Catalogo vazio reconhecido sem inferir resolucao.'
Assert (@(Get-HarnessProjectDecisions $p | Where-Object Presence -EQ 'PRESENTE').Count -eq 0) 'MTA vazio deve manter escolhas sem issues presentes.'
# Bloqueio real no Windows: publicacao recuperavel limita tentativas e preserva base.
$review=Start-HarnessReconciliationReview $p
$handle=[IO.File]::Open($p.MigrationPath,'Open','Read','ReadWrite')
$before=Get-PlanningFixtureState $f
try { Reject { Complete-HarnessReconciliation $p -Conclusion 'Novo texto com arquivo bloqueado.' -Pending @('Conferir runtime') } 'Bloqueio persistente deve falhar.' }
finally { $handle.Dispose() }
Assert ((Get-PlanningFixtureState $f) -ceq $before) 'Bloqueio nao pode deixar atualizacao parcial.'
$done=Complete-HarnessReconciliation $p -Conclusion 'Repeticao apos liberar arquivo.' -Pending @('Conferir runtime')
Assert ($done.State -eq 'PENDENTE') 'Mesma revisao deve funcionar apos liberar arquivo.'
'PASS: registro corrente preserva decisoes, rejeita fontes/tabela invalidas e recupera bloqueio de publicacao.'
