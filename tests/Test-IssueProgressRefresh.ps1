#requires -Version 5.1
$ErrorActionPreference='Stop'; Set-StrictMode -Version Latest
$root=Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $root 'scripts/HarnessProjectIndex.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $root 'scripts/HarnessProject.psm1') -DisableNameChecking
Import-Module (Join-Path $root 'scripts/HarnessIssues.psm1') -DisableNameChecking
function Assert($value,[string]$message) { if (-not $value) { throw $message } }
$area=Join-Path $root ('.harness/tests/andamento-'+[guid]::NewGuid().ToString('N').Substring(0,8))
$source=Join-Path $area 'app'; $null=[IO.Directory]::CreateDirectory($source)
[IO.File]::WriteAllText((Join-Path $source 'pom.xml'),'<project><artifactId>app</artifactId></project>')
$context=[pscustomobject]@{Root=(Join-Path $area 'workspace');Projects=@([pscustomobject]@{path=$source})}
$initial=New-HarnessProjectIndex $context
$p=$initial.Projects[0]
$created=Register-HarnessManualIssue $p DEV-A 'Achado' -Context $context
Assert (-not $created.DashboardPending) 'Escopo explicito permite atualizar dashboard apos cadastro.'
Assert ([IO.File]::ReadAllText($p.MigrationPath).Contains('| manual / manual | NAO ANALISADA | 1 | 100,00% | 1 |')) 'Cadastro deve publicar resumo junto do registro.'
$text=[IO.File]::ReadAllText($p.MigrationPath).Replace('| A DEFINIR | NAO ANALISADA |','| ADIAR | IMPLEMENTADA |')+"`nNota humana depois do resumo.`n"
[IO.File]::WriteAllText($p.MigrationPath,$text)
$association=[IO.File]::ReadAllText((Join-Path $p.Folder 'projeto.json'))
$result=Update-HarnessIssueProgress -Context $context
Assert $result.Synchronized 'Recalculo deve confirmar tres destinos quando todos publicados.'
foreach ($path in @($p.IndexPath,$p.MigrationPath,$initial.IndexPath)) {
    Assert ([IO.File]::ReadAllText($path).Contains('| manual / manual | IMPLEMENTADA | 1 | 100,00% | 1 |')) 'Tres resumos devem concordar apos edicao documental.'
}
$dashboard=[IO.File]::ReadAllText($initial.IndexPath)
Assert ($dashboard.Contains('MTA: -<br>Manuais: 1 / -') -and $dashboard.Contains('IMPLEMENTADA: 1 (100,00%)')) 'Coluna compacta e cadastro manual devem acompanhar o recalcúlo.'
Assert ([IO.File]::ReadAllText((Join-Path $p.Folder 'projeto.json')) -ceq $association) 'Recalculo nao troca associacao MTA.'
$before=[IO.File]::ReadAllText($p.MigrationPath)
$again=Register-HarnessManualIssue $p DEV-A 'Achado'
Assert ($again.Reused -and [IO.File]::ReadAllText($p.MigrationPath) -ceq $before) 'Cadastro repetido nao reabre nem altera estado/nota.'
$null=Update-HarnessIssueProgress -Context $context
Assert ([IO.File]::ReadAllText($initial.IndexPath) -ceq $dashboard) 'Repeticao deve ser idempotente tambem no dashboard.'
$wrong=[pscustomobject]@{Root=$context.Root;Projects=@()}
$scope=Update-HarnessIssueProgress -Context $wrong
Assert (-not $scope.Synchronized -and [IO.File]::ReadAllText($initial.IndexPath) -ceq $dashboard) 'Escopo reduzido nao pode substituir o consolidado existente.'
[IO.File]::WriteAllText($p.MigrationPath,'Registro invalido')
$unavailable=Update-HarnessIssueProgress -Context $context
$unknown=[IO.File]::ReadAllText($initial.IndexPath)
Assert (-not $unavailable.Synchronized -and $unknown.Contains('Andamento indisponivel; nenhum registro lido.') -and $unknown.Contains('Indisponivel: registro nao lido')) 'Indisponibilidade nao pode produzir zero ou deixar sucesso anterior no dashboard.'
[IO.File]::WriteAllText($p.MigrationPath,$before)
$null=Update-HarnessIssueProgress -Context $context
# Nenhum catalogo pode ser selecionado como efeito do recalculo.
$external=Join-Path $area 'mta'; $null=[IO.Directory]::CreateDirectory($external)
[IO.File]::WriteAllText((Join-Path $external 'output.js'),'INVALIDO')
$config=ConvertFrom-Json $association; $config.mta.diretorio=$external
[IO.File]::WriteAllText((Join-Path $p.Folder 'projeto.json'),($config|ConvertTo-Json))
$null=Update-HarnessIssueProgress -Context $context
Assert ([IO.File]::ReadAllText((Join-Path $external 'output.js')) -ceq 'INVALIDO') 'Nao ler/executar/regravar MTA no recalculo documental.'
[IO.File]::Delete($initial.IndexPath)
$partial=Update-HarnessIssueProgress -Context $context
Assert (-not $partial.Synchronized -and ($partial.Warnings -join ' ').Contains('Dashboard pendente')) 'Falha global nao pode aparentar sincronizacao completa.'
Assert ([IO.File]::ReadAllText($p.MigrationPath).Contains('Nota humana depois do resumo.')) 'Falha global preserva publicacao e texto humano.'
# Simular editor externo entre leitura e publicacao: Expected deve recusar.
$module=Get-Module HarnessProject
& $module {
    $script:originalProgressFiles=${function:Get-HarnessIssueProgressFiles}
    function script:Get-HarnessIssueProgressFiles {
        param($Project,$Migration,$Index)
        $files=& $script:originalProgressFiles $Project $Migration $Index
        [IO.File]::AppendAllText($Project.MigrationPath,"`nEdicao concorrente preservada.`n")
        $files['migracao.md']+="`n"
        $files
    }
}
try {
    $conflict=Update-HarnessIssueProgress -Context $context
    Assert (-not $conflict.Synchronized -and ($conflict.Warnings -join ' ').Contains('alterado desde a leitura')) 'Concorrencia nao pode publicar resumo sobre registro alterado.'
    Assert ([IO.File]::ReadAllText($p.MigrationPath).Contains('Edicao concorrente preservada.')) 'Recusa preserva contribuicao do editor externo.'
} finally { & $module { ${function:Get-HarnessIssueProgressFiles}=$script:originalProgressFiles; Remove-Variable originalProgressFiles -Scope Script } }
'PASS: cadastro, tres resumos, repeticao, origem preservada e falha parcial explicita.'
