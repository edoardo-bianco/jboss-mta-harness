#requires -Version 5.1
$ErrorActionPreference='Stop'; Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'PlanningCurrentFixture.ps1')
$f=New-PlanningFixture 1; $p=$f.Projects[0]
$register=[IO.File]::ReadAllText($p.MigrationPath).Replace('| NAO ANALISADA |','| VERIFICADA |')
[IO.File]::WriteAllText($p.MigrationPath,$register)
$review=Start-HarnessReconciliationReview $p
$done=Complete-HarnessReconciliation $p -Conclusion 'Criterios conferidos; aceite humano pendente.'
foreach ($path in @($p.MigrationPath,$p.IndexPath)) {
    Assert ([IO.File]::ReadAllText($path).Contains('| MTA / mandatory | VERIFICADA | 1 | 100,00% | 1 |')) 'Reconciliacao deve publicar dois resumos do registro efetivo.'
    Assert ([IO.File]::ReadAllText($path).Contains('| MTA / mandatory | CONCLUIDA | 0 | 0,00% | 1 |')) 'Reconciliacao concluida nao conclui issue.'
}
$received=Set-ProjectManagedBlock ([IO.File]::ReadAllText($p.MigrationPath)) 'issues:andamento' 'Resumo antigo da outra maquina.'
Publish-HarnessProjectFiles $p @{'recebido/migracao.md'=$received}
$comparison=Get-HarnessReconciliationComparison $p (Join-Path $p.Folder 'recebido')
Assert (@($comparison.Documents | Where-Object Path -EQ 'migracao.md')[0].Status -eq 'EQUIVALENTE') 'Resumo derivado nao deve produzir conflito humano.'
$g=New-Fixture 5; $q=$g.Projects[0]
$register=[IO.File]::ReadAllText($q.MigrationPath)
$states=@('EM ANALISE','EM IMPLEMENTACAO','IMPLEMENTADA','VERIFICADA','CONCLUIDA')
for ($i=1;$i -le 5;$i++) {
    $pattern='(?m)^(\| java::mandatory-'+$i+' \|[^\r\n]*\| )NAO ANALISADA( \|[^\r\n]*$)'
    $register=[regex]::Replace($register,$pattern,('$1'+$states[$i-1]+'$2'))
}
[IO.File]::WriteAllText($q.MigrationPath,$register)
$prior=New-HarnessPrioritizationContext $g.Context -Percentage 100 -Category mandatory
$data=Read-Prepared $prior
Assert ($data.InitialTotal -eq 1 -and $data.AvailableIssues[0].Id -ceq 'java::mandatory-1') 'EM ANALISE retoma; implementacao e resultado nao reabrem por filtro.'
'PASS: publicacao reconciliada, derivado sem conflito e retomada dos estados novos.'
