#requires -Version 5.1
$ErrorActionPreference='Stop'; Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'PlanningCurrentFixture.ps1')
$f=New-PlanningFixture 1
$p=$f.Projects[0]
$log=Join-Path $p.Folder 'atual/build/console.log'
Publish-HarnessProjectFiles $p @{
    'atual/planejamento/contexto.json'='{}';'atual/planejamento/planejar-lotes.prompt.md'='# Orientacao'
    'atual/build/resultado.json'='{}';'atual/build/console.log'='BUILD FAILURE'
    'atual/diagnosticos/sonar/resultado.json'='{}';'atual/diagnosticos/sonar/RESUMO.md'='# Coleta Sonar'
    'atual/operacao.json'=(@{build=@{Status='FAILED';DateUtc='2026-10-12T12:00:00Z';Error='Falha sintetica';LogPath=$log}} | ConvertTo-Json)
}
$mta=Read-HarnessProjectMta $p
Update-HarnessProjectDocuments $p $mta
$index=[IO.File]::ReadAllText($p.IndexPath)
foreach ($path in @($mta.ReportPath,(Join-Path $p.Folder 'atual/diagnosticos/sonar/RESUMO.md'),$log)) {
    $uri=New-Object Uri $p.IndexPath
    $target=$uri.MakeRelativeUri((New-Object Uri $path)).ToString()
    Assert ($index.Contains($target)) ('Navegacao deve abrir documento legivel: '+$target)
}
Assert ($index.Contains('FAILED') -and $index.Contains('Falha sintetica')) 'Situacao corrente deve ser legivel no indice.'
Assert ($index -notmatch '\]\(<?[^)\r\n]*\.json[>)]') 'Indice nao deve mandar o leitor para JSON quando ha documento legivel.'
[IO.File]::AppendAllText($p.IndexPath,"`nNota humana no indice.")
Set-HarnessProjectOperation $p build SUCCEEDED -LogPath $log
$current=[IO.File]::ReadAllText($p.IndexPath)
Assert ($current.Contains('SUCCEEDED') -and -not $current.Contains('Falha sintetica') -and $current.Contains('Nota humana no indice.')) 'Publicar nova tentativa deve atualizar estado legivel e preservar notas, sem exigir regeneracao do indice.'
$json=[IO.File]::ReadAllBytes((Join-Path $p.Folder 'atual/diagnosticos/sonar/resultado.json'))
Update-HarnessProjectDocuments $p $mta
Assert ([Convert]::ToBase64String($json) -ceq [Convert]::ToBase64String([IO.File]::ReadAllBytes((Join-Path $p.Folder 'atual/diagnosticos/sonar/resultado.json')))) 'Navegacao nao modifica os dados tecnicos.'
'PASS: indice abre relatorio HTML, resumo Sonar e log; situacao legivel e JSON preservado.'

$f=New-PlanningFixture 1
$p=$f.Projects[0]
$prior=New-HarnessPrioritizationContext $f.Context -Percentage 100 -Category mandatory
$null=Complete-Slice $f $prior
$null=Update-HarnessPrioritizationIndex $f.Root
$prepared=New-HarnessCurrentPlanning $f.Context
Publish-HarnessProjectFiles $p @{'atual/planejamento/plano.md'='Plano humano';'atual/planejamento/tarefas.md'='Tarefas humanas'}
$prepared=New-HarnessCurrentPlanning $f.Context
$ficha=(Read-Prepared $prepared).FichaPaths[0].Path
foreach ($path in @($p.IndexPath,$p.PlanPath,$p.TodoPath,$ficha,$prior.IndexPath)) {
    $text=[IO.File]::ReadAllText($path)
    Assert ($text -notmatch '\]\(<?[^)\r\n]*\.(json|js)[>)]') ('Navegacao deve abrir documentos em '+$path)
    foreach ($match in [regex]::Matches($text,'\]\(<([^>]+)>\)')) {
        $baseUri=New-Object Uri $path
        $target=New-Object Uri (([uri]$baseUri.AbsoluteUri),$match.Groups[1].Value)
        Assert (Test-Path -LiteralPath $target.LocalPath) ('Destino navegavel deve existir: '+$target.LocalPath)
    }
}
'PASS: plano, tarefas, fichas e priorizacao abrem documentos correntes existentes.'
