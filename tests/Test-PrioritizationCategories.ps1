#requires -Version 5.1
$ErrorActionPreference='Stop'; Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'PrioritizationFixture.ps1')
$f=New-Fixture 2 @('a','b') @('mandatory','optional','potential','personalizada')
foreach ($category in @('mandatory','optional','potential','personalizada')) {
    $p=New-HarnessPrioritizationContext $f.Context -Percentage 25 -Category $category
    Assert ($p.InitialTotal -eq 4 -and $p.SliceSize -eq 1) 'Categoria deve ter base propria em dois projetos.'
    $null=Complete-Slice $f $p
    $next=New-HarnessPrioritizationContext $f.Context -Percentage 25 -Category $category -Mode Continue
    Assert ((Read-Prepared $next).ExcludedIssues.Count -eq 1) 'Cobertura nao mistura categorias.'
}
$single=[pscustomobject]@{Root=$f.Root;Projects=@($f.Context.Projects[0])}
Reject { New-HarnessPrioritizationContext $single -Percentage 100 -Category mandatory } 'Escopo padrao existente nao pode mudar participantes.'
$p=New-HarnessPrioritizationContext $single -Percentage 100 -Category mandatory -Scope individual
Assert ($p.InitialTotal -eq 2 -and (Read-Prepared $p).ExcludedIssues.Count -eq 0) 'Escopo individual nao herda exame do conjunto.'
$null=Complete-Slice $f $p
$all=New-HarnessPrioritizationContext $f.Context -Percentage 100 -Category mandatory -Mode Continue
Assert ($all.Reused -and (Read-Prepared $all).ExcludedIssues.Count -eq 1) 'Ficha em outro escopo nao implica exame.'
$reverse=[pscustomobject]@{Root=$f.Root;Projects=@($f.Context.Projects[1],$f.Context.Projects[0])}
$again=New-HarnessPrioritizationContext $reverse -Percentage 100 -Category mandatory -Mode Continue
Assert ($again.ContextPath -ceq $all.ContextPath) 'Ordem dos projetos nao muda escopo/mestre.'
$other=New-HarnessPrioritizationContext $f.Context -Percentage 100 -Category mandatory -Scope frente
Reject { New-HarnessPrioritizationContext $single -Percentage 100 -Category mandatory -Scope frente -Mode Recreate } 'Escopo nomeado nao pode trocar participantes silenciosamente.'
$null=Complete-Slice $f $other
Assert ((Read-Result $other).AnalyzedIssues.Count -eq 4) 'Mesmo ID em projetos diferentes sao issues distintas.'
'PASS: categorias, escopos, ordem canonica e IDs repetidos entre projetos.'
