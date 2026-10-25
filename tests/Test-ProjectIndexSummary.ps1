#requires -Version 5.1
$ErrorActionPreference='Stop'; Set-StrictMode -Version Latest
$root=Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $root 'scripts/HarnessProjectIndex.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $root 'scripts/HarnessProject.psm1') -DisableNameChecking
function Assert($value,[string]$message) { if (-not $value) { throw $message } }
function Write-File($path,$text) {
    $null=[IO.Directory]::CreateDirectory((Split-Path $path -Parent))
    [IO.File]::WriteAllText($path,$text,(New-Object Text.UTF8Encoding($false)))
}
$area=Join-Path $root ('.harness/tests/resumo-'+[guid]::NewGuid().ToString('N').Substring(0,8))
$workspace=Join-Path $area 'workspace'
$external=Join-Path $area 'relatorios externos'
$context=[pscustomobject]@{Root=$workspace;Config=[pscustomobject]@{mta=[pscustomobject]@{runsPath=$external}};Projects=@()}
foreach ($name in @('com-mta','sem-mta','vazio','outro-mta')) {
    $source=Join-Path $area ('fontes/'+$name)
    Write-File (Join-Path $source 'pom.xml') ('<project><artifactId>'+$name+'</artifactId></project>')
    $context.Projects+=@([pscustomobject]@{name=$name;path=$source})
}
foreach ($name in @('com-mta','vazio','outro-mta')) {
    $violations=@{}
    if ($name -eq 'com-mta') {
        $violations=@{
            obrigatoria=@{description='Uma regra';category='mandatory';incidents=@(@{},@{})}
            opcional=@{description='Outra regra';category='optional';incidents=@(@{})}
            especial=@{description='Categoria livre';category='custom|[x]<tag>';incidents=@()}
        }
    } elseif ($name -eq 'outro-mta') {
        $violations=@{
            obrigatoria=@{description='Mesma regra em outro projeto';category='mandatory';incidents=@(@{},@{},@{})}
            potencial=@{description='Regra potencial';category='potential';incidents=@(@{})}
            aviso=@{description='Informacao';category='information';incidents=@()}
        }
    }
    $report=Join-Path $external ($name+'/rodada/index.html')
    Write-File $report '<html>Relatorio sintetico</html>'
    $apps=@(@{artifactId=$name;generatedAt='2026-10-20T08:00:00-03:00';rulesets=@(@{name='java';violations=$violations})})
    Write-File (Join-Path (Split-Path $report) 'output.js') ('window["apps"] = '+(ConvertTo-Json -InputObject $apps -Depth 10 -Compress)+';')
}
$initial=New-HarnessProjectIndex $context -UpdateMigration
$p=$initial.Projects[0]
$registry=[IO.File]::ReadAllText($p.MigrationPath).Replace('| A DEFINIR | NAO ANALISADA |','| ANALISAR AGORA | EM ANDAMENTO |')
Publish-HarnessProjectFiles $p @{
    'migracao.md'=$registry
    'atual/build/console.log'='Falha sintetica'
    'atual/diagnosticos/sonar/RESUMO.md'='# Diagnostico anterior'
    'atual/planejamento/planejar-lotes.prompt.md'='# Preparo sem proposta'
    'atual/operacao.json'=(@{
        build=@{Status='FAILED';DateUtc='2026-10-21T11:00:00Z';Error='Falha';LogPath=(Join-Path $p.Folder 'atual/build/console.log')}
        mta=@{Status='FAILED';DateUtc='2026-10-21T12:00:00Z';Error='Falha posterior';LogPath=$null}
    } | ConvertTo-Json)
}
$externalBefore=@(Get-ChildItem -LiteralPath $external -File -Recurse | Get-FileHash | ForEach-Object Hash) -join ','
$result=New-HarnessProjectIndex $context
$text=[IO.File]::ReadAllText($result.IndexPath)
Assert ($text.Contains('| Projeto | MTA utilizavel (UTC) | Issues / ocorrencias | Categorias (issues / ocorrencias) | Ultimas tentativas (UTC) | Documentos |')) 'Indice deve apresentar tabela resumida com links.'
$line=($text -split '\r?\n' | Where-Object { $_ -match '^\| \[com-mta\]' })
Assert ($line.Contains('| MTA: 3 / 3<br>Manuais: 0 / - |') -and $line.Contains('mandatory: 1 / 2') -and $line.Contains('optional: 1 / 1')) 'Contagens devem vir do MTA por categoria.'
Assert ($line.Contains('custom&#124;&#91;x&#93;&lt;tag&gt;: 1 / 0')) 'Categoria externa deve ser texto seguro na tabela.'
Assert ($line.Contains('2026-10-20 11:00:00') -and $line.Contains('mta: FAILED') -and $line.Contains('2026-10-21T12:00:00Z')) 'Diagnostico anterior e ultima tentativa falha devem aparecer separados.'
Assert ($line.Contains('[build: FAILED]') -and $line.Contains('console.log')) 'Tentativa deve abrir seu log existente.'
Assert ($line.Contains('[Registro]') -and $line.Contains('[Sonar]') -and $line.Contains('[Preparo]') -and $line.Contains('Proposta ausente')) 'Preparo e diagnostico devem ter links sem aparentar plano existente.'
$missing=($text -split '\r?\n' | Where-Object { $_ -match '^\| \[sem-mta\]' })
$empty=($text -split '\r?\n' | Where-Object { $_ -match '^\| \[vazio\]' })
Assert ($missing.Contains('| Indisponivel | MTA: -<br>Manuais: 0 / - |') -and $empty.Contains('| MTA: 0 / 0<br>Manuais: 0 / - |')) 'Ausencia de MTA nao equivale a diagnostico vazio.'
Assert ($text.Contains('3 de 4 projetos') -and $text.Contains('6 issues / 7 ocorrencias')) 'Totais devem explicitar cobertura parcial e excluir ausencia.'
Assert ($text.Contains('## Totais conhecidos') -and $text.Contains('| Categoria | Issues | Ocorrencias |')) 'Totais devem ter tabela por categoria no indice geral.'
Assert ($text.Contains('| mandatory | 2 | 5 |')) 'Mesma regra em dois projetos conta duas issues; ocorrencias devem ser somadas.'
Assert ($text.Contains('| optional | 1 | 1 |') -and $text.Contains('| potential | 1 | 1 |') -and $text.Contains('| information | 1 | 0 |')) 'Categorias distintas devem manter seus totais de issues e ocorrencias.'
Assert ($text.Contains('| custom&#124;&#91;x&#93;&lt;tag&gt; | 1 | 0 |')) 'Totais devem preservar e escapar categorias livres.'
Assert ($text.Contains('Sem tentativa registrada')) 'Nao inferir execucao local a partir de MTA externo.'
Assert ([IO.File]::ReadAllText($p.MigrationPath) -ceq $registry) 'Resumo nao muda decisoes humanas.'
Assert ((@(Get-ChildItem -LiteralPath $external -File -Recurse | Get-FileHash | ForEach-Object Hash) -join ',') -ceq $externalBefore) 'Resumo nao escreve no MTA externo.'
Assert ($text -notmatch '\{\{[A-Za-z]+\}\}' -and $text.Contains('## Como interpretar')) 'Template deve ser preenchido e manter legenda.'
foreach ($match in [regex]::Matches($text,'\]\(<([^>]+)>\)')) {
    $target=New-Object Uri (([uri](New-Object Uri $result.IndexPath).AbsoluteUri),$match.Groups[1].Value)
    Assert (Test-Path -LiteralPath $target.LocalPath) ('Link deve existir: '+$target.LocalPath)
}
Publish-HarnessProjectFiles $p @{'atual/planejamento/plano.md'='# Plano';'atual/planejamento/tarefas.md'='# Tarefas'}
$again=New-HarnessProjectIndex $context
$againText=[IO.File]::ReadAllText($again.IndexPath)
$line=($againText -split '\r?\n' | Where-Object { $_ -match '^\| \[com-mta\]' })
Assert ($line.Contains('[Plano]') -and $line.Contains('[Tarefas]') -and -not $line.Contains('Proposta ausente')) 'Nova atualizacao deve apontar documentos produzidos.'
Assert ($againText.Contains('| mandatory | 2 | 5 |') -and $againText.Contains('6 issues / 7 ocorrencias')) 'Repetir a atualizacao nao acumula contagens de leituras anteriores.'
$onlyEmpty=[pscustomobject]@{Root=(Join-Path $area 'somente-vazio');Config=$context.Config;Projects=@($context.Projects | Where-Object name -EQ 'vazio')}
$zeroIndex=New-HarnessProjectIndex $onlyEmpty
$zeroText=[IO.File]::ReadAllText($zeroIndex.IndexPath)
Assert ($zeroText.Contains('1 de 1 projetos') -and $zeroText.Contains('0 issues / 0 ocorrencias') -and $zeroText.Contains('| Sem issues no MTA utilizavel | 0 | 0 |')) 'MTA valido vazio permite zero conhecido sem inventar categorias.'
$onlyMissing=[pscustomobject]@{Root=(Join-Path $area 'somente-indisponivel');Config=$context.Config;Projects=@($context.Projects | Where-Object name -EQ 'sem-mta')}
$unknownIndex=New-HarnessProjectIndex $onlyMissing
$unknownText=[IO.File]::ReadAllText($unknownIndex.IndexPath)
Assert ($unknownText.Contains('0 de 1 projetos') -and $unknownText.Contains('Totais conhecidos: indisponiveis.') -and $unknownText.Contains('| Indisponivel: nenhum MTA utilizavel | - | - |')) 'Ausencia de MTA nao pode publicar zero como total conhecido.'
$none=[pscustomobject]@{Root=(Join-Path $area 'sem-projetos');Projects=@()}
$emptyIndex=New-HarnessProjectIndex $none
$emptyText=[IO.File]::ReadAllText($emptyIndex.IndexPath)
Assert ($emptyText.Contains('Nenhum projeto Maven no escopo.') -and $emptyText.Contains('| Indisponivel: nenhum MTA utilizavel | - | - |')) 'Escopo vazio deve ficar explicito e sem categorias inventadas.'
'PASS: resumo com links, totais por categoria, cobertura, falhas, preparo e preservacao.'
