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
foreach ($name in @('com-mta','sem-mta','vazio')) {
    $source=Join-Path $area ('fontes/'+$name)
    Write-File (Join-Path $source 'pom.xml') ('<project><artifactId>'+$name+'</artifactId></project>')
    $context.Projects+=@([pscustomobject]@{name=$name;path=$source})
}
foreach ($name in @('com-mta','vazio')) {
    $violations=@{}
    if ($name -eq 'com-mta') {
        $violations=@{
            obrigatoria=@{description='Uma regra';category='mandatory';incidents=@(@{},@{})}
            opcional=@{description='Outra regra';category='optional';incidents=@(@{})}
            especial=@{description='Categoria livre';category='custom|[x]<tag>';incidents=@()}
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
Assert ($line.Contains('| 3 / 3 |') -and $line.Contains('mandatory: 1 / 2') -and $line.Contains('optional: 1 / 1')) 'Contagens devem vir do MTA por categoria.'
Assert ($line.Contains('custom&#124;&#91;x&#93;&lt;tag&gt;: 1 / 0')) 'Categoria externa deve ser texto seguro na tabela.'
Assert ($line.Contains('2026-10-20 11:00:00') -and $line.Contains('mta: FAILED') -and $line.Contains('2026-10-21T12:00:00Z')) 'Diagnostico anterior e ultima tentativa falha devem aparecer separados.'
Assert ($line.Contains('[build: FAILED]') -and $line.Contains('console.log')) 'Tentativa deve abrir seu log existente.'
Assert ($line.Contains('[Registro]') -and $line.Contains('[Sonar]') -and $line.Contains('[Preparo]') -and $line.Contains('Proposta ausente')) 'Preparo e diagnostico devem ter links sem aparentar plano existente.'
$missing=($text -split '\r?\n' | Where-Object { $_ -match '^\| \[sem-mta\]' })
$empty=($text -split '\r?\n' | Where-Object { $_ -match '^\| \[vazio\]' })
Assert ($missing.Contains('| Indisponivel | - |') -and $empty.Contains('| 0 / 0 |')) 'Ausencia de MTA nao equivale a diagnostico vazio.'
Assert ($text.Contains('2 de 3 projetos') -and $text.Contains('3 issues / 3 ocorrencias')) 'Totais devem explicitar cobertura parcial e excluir ausencia.'
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
$line=([IO.File]::ReadAllText($again.IndexPath) -split '\r?\n' | Where-Object { $_ -match '^\| \[com-mta\]' })
Assert ($line.Contains('[Plano]') -and $line.Contains('[Tarefas]') -and -not $line.Contains('Proposta ausente')) 'Nova atualizacao deve apontar documentos produzidos.'
$none=[pscustomobject]@{Root=(Join-Path $area 'sem-projetos');Projects=@()}
$emptyIndex=New-HarnessProjectIndex $none
Assert ([IO.File]::ReadAllText($emptyIndex.IndexPath).Contains('Nenhum projeto Maven no escopo.')) 'Escopo vazio deve ficar explicito.'
'PASS: resumo com links, contagens MTA, cobertura, falhas, preparo e preservacao.'
