#requires -Version 5.1
$ErrorActionPreference='Stop'; Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'PlanningCurrentFixture.ps1')
$f=New-PlanningFixture 2
$project=$f.Projects[0]
$prior=New-HarnessPrioritizationContext $f.Context -Percentage 50 -Category mandatory
$null=Complete-Slice $f $prior
$p=New-HarnessCurrentPlanning $f.Context
$data=Read-Prepared $p
$ficha=@($data.FichaPaths | Where-Object Status -eq 'DISPONIVEL')[0].Path
Assert (@($data.FichaPaths | Where-Object Status -eq 'A ELABORAR').Count -eq 1) 'Ausencia de ficha deve permanecer lacuna, sem inventar exame.'
$text=[IO.File]::ReadAllText($ficha)
foreach ($label in @('Relatorio MTA atual','src/Exemplo.java','observacao.md','Analise manual preservada')) { Assert ($text.Contains($label)) ('Fonte/texto ausente: '+$label) }
foreach ($match in [regex]::Matches($text,'\]\(<([^>]+)>\)')) {
    $baseUri=New-Object Uri $ficha
    $target=New-Object Uri (([uri]$baseUri.AbsoluteUri),$match.Groups[1].Value)
    Assert (Test-Path -LiteralPath $target.LocalPath) ('Link deve abrir: '+$target.LocalPath)
}
Set-FixtureMta $project 2 @('mandatory') novo @('mandatory-1')
[IO.File]::SetLastWriteTimeUtc((Join-Path $f.Root 'mta-a/novo/index.html'),[DateTime]::UtcNow.AddMinutes(1))
$changed=New-HarnessCurrentPlanning $f.Context
Assert ($changed.NeedsReview -and $changed.Diagnostics.Count -gt 0) 'Nova origem deve pedir revisao e informar issue ausente.'
$text=[IO.File]::ReadAllText($ficha)
Assert ($text.Contains('novo/index.html') -and $text.Contains('nao reencontrada') -and $text.Contains('Analise manual preservada')) 'MTA novo atualiza apenas fontes; ausencia nao e resolucao.'
$newSource=Join-Path $f.Root 'relocado'
$null=[IO.Directory]::CreateDirectory((Join-Path $newSource 'src'))
Copy-Item -LiteralPath $project.Pom -Destination (Join-Path $newSource 'pom.xml')
Copy-Item -LiteralPath (Join-Path $project.Source 'src/Exemplo.java') -Destination (Join-Path $newSource 'src/Exemplo.java')
Publish-HarnessProjectFiles $project @{'projeto.json'=(@{pom=(Join-Path $newSource 'pom.xml');mta=@{diretorio='mta-a'}}|ConvertTo-Json)}
$f.Context.Projects[0].path=$newSource
$again=New-HarnessCurrentPlanning $f.Context
Assert ([IO.File]::ReadAllText($ficha).Contains('relocado/src/Exemplo.java')) 'Associacao explicita atualiza links locais sem copiar ficha.'
$again=New-HarnessCurrentPlanning $f.Context -PlanningBasis EVIDENCIAS
Assert ([IO.File]::ReadAllText($ficha).Contains('MTA nao consultado')) 'Base humana nao deve afirmar falha de uma consulta que nao ocorreu.'
$text=[IO.File]::ReadAllText($ficha)
[IO.File]::WriteAllText($ficha,$text.Replace('src/Exemplo.java','../fora.txt'))
$before=[IO.File]::ReadAllText($p.ContextPath)
Reject { New-HarnessCurrentPlanning $f.Context } 'Referencia insegura deve ser recusada.'
Assert ([IO.File]::ReadAllText($p.ContextPath) -ceq $before) 'Falha na ficha nao pode publicar contexto parcial.'
[IO.File]::WriteAllText($ficha,$text.Replace('"Project":"a"','"Project":"outro"'))
Reject { New-HarnessCurrentPlanning $f.Context } 'Ficha de outro projeto deve ser recusada.'
foreach ($file in Get-ChildItem -LiteralPath $project.Folder -Recurse -File) {
    Assert ($file.Name -notmatch 'apontamentos-mta|snapshot|manifest') 'Planejamento nao deve gerar extrato/recibo.'
    Assert (-not [IO.File]::ReadAllText($file.FullName).Contains('NAO_COPIAR_INCIDENTE')) 'Detalhes MTA permanecem na origem.'
}
'PASS: ficha essencial, links navegaveis, novo MTA/Source, lacunas, identidade e preservacao atomica.'
