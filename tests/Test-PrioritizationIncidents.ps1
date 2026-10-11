#requires -Version 5.1
$ErrorActionPreference='Stop'; Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'PrioritizationFixture.ps1')
$f=New-Fixture 3
$p=New-HarnessPrioritizationContext $f.Context -Percentage 34 -Category mandatory
$null=Complete-Slice $f $p
$next=New-HarnessPrioritizationContext $f.Context -Percentage 34 -Category mandatory -Mode Continue
$d=Read-Prepared $next
$ficha=$d.FichaPaths[0].Path
$text=[IO.File]::ReadAllText($ficha)
foreach ($label in @('Relatorio MTA atual','Catalogo MTA original','src/Exemplo.java','pom.xml','observacao.md','Analise manual preservada')) {
    Assert ($text.Contains($label)) ('Ficha deve incluir fonte/texto: '+$label)
}
foreach ($match in [regex]::Matches($text,'\]\(<([^>]+)>\)')) {
    $baseUri=New-Object Uri $ficha
    $target=New-Object Uri (([uri]$baseUri.AbsoluteUri),$match.Groups[1].Value)
    Assert (Test-Path -LiteralPath $target.LocalPath) ('Link deve abrir: '+$target.LocalPath)
}
Set-FixtureMta $f.Projects[0] 4 @('mandatory') novo @('mandatory-1')
Update-HarnessProjectDocuments $f.Projects[0] (Read-HarnessProjectMta $f.Projects[0]) -UpdateIssues
$again=New-HarnessPrioritizationContext $f.Context -Percentage 34 -Category mandatory -Mode Continue
Assert ((Read-Prepared $again).InitialTotal -eq 3 -and (Read-Prepared $again).OutsideBaseline -eq 1) 'Novo MTA nao troca base inicial nem inclui novas silenciosamente.'
$text=[IO.File]::ReadAllText($ficha)
Assert ($text.Contains('nao reencontrada') -and $text.Contains('novo/index.html') -and $text.Contains('Analise manual preservada')) 'MTA novo atualiza links e assinala ausencia sem apagar analise.'
$all=@(Get-ChildItem -LiteralPath $f.Projects[0].Folder -Recurse -File)
Assert (-not @($all | Where-Object Name -Match 'apontamentos-mta|issue-\d|manifest|snapshot').Count) 'Nao gerar extratos nem recibos.'
foreach ($file in $all) {
    Assert (-not [IO.File]::ReadAllText($file.FullName).Contains('NAO_COPIAR_INCIDENTE')) 'Incidentes ficam somente na origem.'
}
# Realocacao explicitamente associada ao mesmo projeto, sem mover/apagar arquivos.
$newSource=Join-Path $f.Root 'relocado'; $null=[IO.Directory]::CreateDirectory((Join-Path $newSource 'src'))
Copy-Item -LiteralPath $f.Projects[0].Pom -Destination (Join-Path $newSource 'pom.xml')
Copy-Item -LiteralPath (Join-Path $f.Projects[0].Source 'src/Exemplo.java') -Destination (Join-Path $newSource 'src/Exemplo.java')
$project=$f.Projects[0]
Publish-HarnessProjectFiles $project @{'projeto.json'=(@{pom=(Join-Path $newSource 'pom.xml');mta=@{diretorio='mta-a'}}|ConvertTo-Json)}
$f.Context.Projects[0].path=$newSource
$again=New-HarnessPrioritizationContext $f.Context -Percentage 34 -Category mandatory -Mode Continue
Assert ([IO.File]::ReadAllText($ficha).Contains('relocado/src/Exemplo.java')) 'Associacao atual muda link local sem duplicar cobertura.'
$text=[IO.File]::ReadAllText($ficha)
[IO.File]::WriteAllText($ficha,$text.Replace('src/Exemplo.java','../fora.txt'))
Reject { New-HarnessPrioritizationContext $f.Context -Percentage 34 -Category mandatory -Mode Continue } 'Travessia em referencia local nao pode gerar link.'
[IO.File]::WriteAllText($ficha,$text)
$g=New-Fixture 10
$p=New-HarnessPrioritizationContext $g.Context -Percentage 50 -Category mandatory
$null=Complete-Slice $g $p
Set-FixtureMta $g.Projects[0] 10 @('mandatory') corrente @('mandatory-8','mandatory-9')
$p=New-HarnessPrioritizationContext $g.Context -Percentage 50 -Category mandatory -Mode Continue
Assert ($p.SliceSize -eq 3) 'Ausencias limitam quota da segunda fatia.'
Set-FixtureMta $g.Projects[0] 10
$again=New-HarnessPrioritizationContext $g.Context -Percentage 50 -Category mandatory -Mode Continue
Assert ($again.Reused -and $again.SliceSize -eq 3 -and (Read-Prepared $again).AvailableIssues.Count -eq 3) 'Reaparecimento nao aumenta universo/quota da fatia pendente.'
$null=Complete-Slice $g $again
$p=New-HarnessPrioritizationContext $g.Context -Percentage 50 -Category mandatory -Mode Continue
Assert ($p.SliceSize -eq 2) 'Reaparecidas ficam para a proxima fatia.'
$null=Complete-Slice $g $p
Set-FixtureMta $g.Projects[0] 0
$empty=New-HarnessPrioritizationContext $g.Context -Percentage 50 -Category mandatory -Mode Continue
Assert ($empty.InitialTotal -eq 10 -and $empty.Status -eq 'EXHAUSTED' -and (Read-Result $empty).AnalyzedIssues.Count -eq 10) 'MTA sem issues conserva base e examinadas.'
$d=Read-Prepared $empty
Assert ([IO.File]::ReadAllText($d.FichaPaths[0].Path).Contains('nao reencontrada')) 'MTA vazio informa ausencia nas fichas.'
Set-FixtureMta $g.Projects[0] 1 @('mandatory') posterior
$refreshed=Update-HarnessPrioritizationIndex $g.Root -RefreshSources
Assert ($refreshed.Warnings.Count -eq 0 -and [IO.File]::ReadAllText($d.FichaPaths[0].Path).Contains('posterior/index.html')) 'Reconstruir indices tambem atualiza fontes das fichas.'
'PASS: fontes diretas, anexo, ausencias, MTA novo/vazio, reaparecimento, realocacao e nenhuma copia.'
