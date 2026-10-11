#requires -Version 5.1
$ErrorActionPreference='Stop'; Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'PrioritizationFixture.ps1')
$f=New-Fixture 4
$p=New-HarnessPrioritizationContext $f.Context -Percentage 50 -Category mandatory
$null=Complete-Slice $f $p
[IO.File]::AppendAllText($p.IndexPath,"\nANOTACAO INDICE")
[IO.File]::AppendAllText($p.PrioritizationIndexPath,"\nANOTACAO GLOBAL")
[IO.File]::AppendAllText($p.RankingPath,"\nANOTACAO RANKING")
$r=Update-HarnessPrioritizationIndex $f.Root
Assert ($r.Warnings.Count -eq 0) ($r.Warnings -join '; ')
foreach ($path in @($p.IndexPath,$p.PrioritizationIndexPath,$p.RankingPath)) {
    Assert ([IO.File]::ReadAllText($path).Contains('ANOTACAO')) 'Regenerar deve preservar texto manual.'
    foreach ($match in [regex]::Matches([IO.File]::ReadAllText($path),'\]\(<([^>]+)>\)')) {
        $baseUri=New-Object Uri $path
        $target=New-Object Uri (([uri]$baseUri.AbsoluteUri),$match.Groups[1].Value)
        Assert (Test-Path -LiteralPath $target.LocalPath) ('Indice/ranking deve abrir a parte real: '+$target.LocalPath)
    }
}
Assert ([IO.File]::ReadAllText($p.IndexPath) -match '(?m)^\| Posicao') 'Tabela acumulada deve comecar em linha propria no Markdown.'
$d=Read-Prepared $p
$ficha=$d.FichaPaths[0].Path
$original=[IO.File]::ReadAllText($ficha)
[IO.File]::WriteAllText($ficha,'Ficha incompleta')
$r=Update-HarnessPrioritizationIndex $f.Root
Assert ($r.Warnings.Count -eq 1 -and [IO.File]::ReadAllText($p.IndexPath).Contains('Cobertura nao validada')) 'Ficha invalida invalida indice derivado, sem cobertura antiga.'
Reject { New-HarnessPrioritizationContext $f.Context -Percentage 50 -Category mandatory -Mode Continue } 'Nao progredir com ficha ausente/invalida.'
[IO.File]::WriteAllText($ficha,$original)
$r=Update-HarnessPrioritizationIndex $f.Root
Assert ($r.Warnings.Count -eq 0) 'Reparar ficha permite reconstruir indice.'
$saved=[IO.File]::ReadAllText($p.RankingPath)
$result=Read-Result $p
$result.AnalyzedIssues+=@($result.AnalyzedIssues[0])
[IO.File]::WriteAllText($p.RankingPath,(Set-ProjectManagedBlock $saved 'priorizacao:resultado' ($result|ConvertTo-Json -Depth 10)))
Reject { New-HarnessPrioritizationContext $f.Context -Percentage 50 -Category mandatory -Mode Continue } 'Duplicata nao pode inflar cobertura.'
[IO.File]::WriteAllText($p.RankingPath,$saved)
$result=Read-Result $p; $result.AnalyzedIssues[0].Reason=''
[IO.File]::WriteAllText($p.RankingPath,(Set-ProjectManagedBlock $saved 'priorizacao:resultado' ($result|ConvertTo-Json -Depth 10)))
Reject { New-HarnessPrioritizationContext $f.Context -Percentage 50 -Category mandatory -Mode Continue } 'Sem proposta exige motivo.'
[IO.File]::WriteAllText($p.RankingPath,$saved)
$result=Read-Result $p; $result.AnalyzedIssues[0].Position=1; $result.AnalyzedIssues[1].Position=1
[IO.File]::WriteAllText($p.RankingPath,(Set-ProjectManagedBlock $saved 'priorizacao:resultado' ($result|ConvertTo-Json -Depth 10)))
Reject { New-HarnessPrioritizationContext $f.Context -Percentage 50 -Category mandatory -Mode Continue } 'Posicoes de recomendacao devem ser unicas.'
$result.AnalyzedIssues[1].Position=$null
[IO.File]::WriteAllText($p.RankingPath,(Set-ProjectManagedBlock $saved 'priorizacao:resultado' ($result|ConvertTo-Json -Depth 10)))
$valid=Update-HarnessPrioritizationIndex $f.Root
Assert ($valid.Warnings.Count -eq 0) 'Ranking aceita recomendada e examinada sem proposta no mesmo conjunto.'
[IO.File]::WriteAllText($p.RankingPath,$saved)
$result=Read-Result $p; $result.AnalyzedIssues=@($result.AnalyzedIssues[0])
[IO.File]::WriteAllText($p.RankingPath,(Set-ProjectManagedBlock $saved 'priorizacao:resultado' ($result|ConvertTo-Json -Depth 10)))
Reject { New-HarnessPrioritizationContext $f.Context -Percentage 50 -Category mandatory -Mode Continue } 'COMPLETED parcial deve ser recusado.'
[IO.File]::WriteAllText($p.RankingPath,$saved)
$next=New-HarnessPrioritizationContext $f.Context -Percentage 50 -Category mandatory -Mode Continue
$result=Read-Result $next; $result.AnalyzedIssues=@()
[IO.File]::WriteAllText($next.RankingPath,(Set-ProjectManagedBlock ([IO.File]::ReadAllText($next.RankingPath)) 'priorizacao:resultado' ($result|ConvertTo-Json -Depth 10)))
Reject { New-HarnessPrioritizationContext $f.Context -Percentage 50 -Category mandatory -Mode Continue } 'Nao perder examinadas anteriores em resultado parcial.'
$other=New-Fixture 1 @('a','b')
$b=$other.Projects[1]
Publish-HarnessProjectFiles $b @{'projeto.json'=(@{pom=(Join-Path $other.Root 'ausente/pom.xml');mta=@{diretorio=$null}}|ConvertTo-Json)}
$single=[pscustomobject]@{Root=$other.Root;Projects=@($other.Context.Projects[0])}
$p=New-HarnessPrioritizationContext $single -Percentage 100 -Category mandatory
$null=Complete-Slice $other $p
$again=New-HarnessPrioritizationContext $single -Percentage 100 -Category mandatory -Mode Continue
Assert ($again.Status -eq 'EXHAUSTED') 'Associacao alheia indisponivel nao bloqueia escopo valido.'
Assert ([IO.File]::ReadAllText($p.PrioritizationIndexPath).Contains('Associacao indisponivel')) 'Indice deve informar associacao alheia indisponivel.'
'PASS: indice derivado, texto humano, ficha/quota/motivo/unicidade, acumulacao e isolamento.'
