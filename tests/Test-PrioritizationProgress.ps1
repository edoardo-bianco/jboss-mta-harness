#requires -Version 5.1
$ErrorActionPreference='Stop'; Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'PrioritizationFixture.ps1')
$f=New-Fixture 200
$p=New-HarnessPrioritizationContext $f.Context -Percentage 10 -Category mandatory
$d=Read-Prepared $p
Assert ($d.InitialTotal -eq 200 -and $d.SliceSize -eq 20) 'Primeira fatia deve usar total inicial.'
Reject { New-HarnessPrioritizationContext $f.Context -Percentage 10 -Category mandatory } 'Escolha Continue/Recreate deve ser explicita.'
$r=New-HarnessPrioritizationContext $f.Context -Percentage 5 -Category mandatory -Mode Continue
Assert ($r.Reused -and $r.SliceSize -eq 20 -and $r.ContextPath -ceq $p.ContextPath) 'Pendente deve retomar no mesmo caminho e quota.'
$null=Complete-Slice $f $p 10 IN_PROGRESS
$r=New-HarnessPrioritizationContext $f.Context -Percentage 5 -Category mandatory -Mode Continue
Assert ((Read-Result $r).AnalyzedIssues.Count -eq 10 -and $r.Reused) 'Parcial conserva examinadas sem completar quota.'
$null=Complete-Slice $f $p 10
$next=New-HarnessPrioritizationContext $f.Context -Percentage '7,5' -Category mandatory -Mode Continue
$n=Read-Prepared $next
Assert ($n.InitialTotal -eq 200 -and $n.SliceSize -eq 15 -and $n.ExcludedIssues.Count -eq 20 -and $n.AvailableIssues.Count -eq 180) 'Segunda fatia exclui todas examinadas, inclusive sem proposta.'
$null=Complete-Slice $f $next
$index=Update-HarnessPrioritizationIndex $f.Root
Assert ($index.Warnings.Count -eq 0) ($index.Warnings -join '; ')
Assert ((Read-Result $next).AnalyzedIssues.Count -eq 35) '20 + 15 deve consolidar 35 examinadas.'
$indexText=[IO.File]::ReadAllText($next.IndexPath)
Assert ($indexText -match '35 / 200' -and ([regex]::Matches($indexText,'ficha\.md')).Count -eq 35) 'Indice deve apontar todas as 35 fichas.'
$third=New-HarnessPrioritizationContext $f.Context -Percentage 10 -Category mandatory -Mode Continue
Assert ((Read-Prepared $third).ExcludedIssues.Count -eq 35 -and $third.ContextPath -ceq $p.ContextPath) 'Proxima fatia exclui conjunto acumulado sem nova execucao.'
Assert (@(Get-ChildItem -LiteralPath $f.Projects[0].Folder -Recurse -Filter contexto.json).Count -eq 1) 'Sem cadeia de contextos.'
$reset=New-HarnessPrioritizationContext $f.Context -Percentage '0,01' -Category mandatory -Mode Recreate
Assert ($reset.SliceSize -eq 1 -and (Read-Prepared $reset).ExcludedIssues.Count -eq 0) 'Recreate deve zerar cobertura e arredondar para cima.'
Assert (@(Get-ChildItem -LiteralPath $f.Projects[0].Folder -Recurse -Filter ficha.md).Count -eq 35) 'Recriar preserva fichas sem contar como exame.'
Reject { New-HarnessPrioritizationContext $f.Context -Percentage 0 -Category mandatory -Mode Recreate } 'Zero nao e percentual valido.'
Reject { New-HarnessPrioritizationContext $f.Context -Percentage '1,234' -Category mandatory -Mode Recreate } 'Mais de duas casas invalido.'
$g=New-Fixture 44
$expected=@(9,9,9,9,8); $prior=$null
foreach ($quota in $expected) {
    $options=@{Percentage=20;Category='mandatory'}; if ($prior) {$options.Mode='Continue'}
    $prior=New-HarnessPrioritizationContext $g.Context @options
    Assert ($prior.SliceSize -eq $quota) 'Quota deve manter denominador 44 e limitar ultima fatia.'
    $null=Complete-Slice $g $prior
}
$done=New-HarnessPrioritizationContext $g.Context -Percentage 20 -Category mandatory -Mode Continue
Assert ($done.Status -eq 'EXHAUSTED' -and (Read-Result $done).AnalyzedIssues.Count -eq 44) 'Esgotamento conserva conjunto completo.'
'PASS: fatias 20+15=35, retomada parcial, recriacao, quota fixa e esgotamento.'
