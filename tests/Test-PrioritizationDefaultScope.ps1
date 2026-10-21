#requires -Version 5.1
$ErrorActionPreference='Stop'; Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'PrioritizationFixture.ps1')

function Get-ScopeFixtureBytes([string]$Path) {
    (@(Get-ChildItem -LiteralPath $Path -Recurse -File | Sort-Object FullName | ForEach-Object {
        $_.FullName.Substring($Path.Length)+':'+[Convert]::ToBase64String([IO.File]::ReadAllBytes($_.FullName))
    }) -join [Environment]::NewLine)
}

# Os nomes reproduzem o tamanho do escopo informado, mas fontes e MTA sao todos
# sinteticos. O caminho curto nao pode reduzir os participantes nem a cobertura.
$names=@('simtr-parent','simtr-outsourcing-parent','arquitetura-common','arquiteturajee7',
    'arquitetura-util','caixa-permissao','caixa-verificapdf','caixa-keycloak',
    'parent-all-jee7','sicli-api','simtr-siecm-api','siiso-api','sipes-api','siric-api')
$f=New-Fixture 2 $names
$p=New-HarnessPrioritizationContext $f.Context -Percentage 25 -Category mandatory
$d=Read-Prepared $p
Assert ($p.Scope -ceq 'priorizacao' -and $d.Scope -ceq 'priorizacao') 'Sem Scope, usar o nome curto fixo priorizacao.'
Assert ($p.ContextPath -match '\\mandatory\\escopos\\priorizacao\\contexto\.json$') 'Caminho padrao nao deve concatenar artifactIds.'
$ordered=[string[]]$names; [Array]::Sort($ordered,[StringComparer]::Ordinal)
Assert ($d.Projects.Count -eq 14 -and (@($d.Projects.Project) -join '|') -ceq ($ordered -join '|')) 'Contexto deve preservar todos os participantes em ordem canonica.'
Assert ($d.InitialTotal -eq 28 -and $d.SliceSize -eq 7 -and $d.BaselineIssues.Count -eq 28 -and $d.FichaPaths.Count -eq 28) 'Nome curto preserva base, quota e destinos de ficha das 28 issues.'
Assert (@($d.BaselineIssues.Project | Select-Object -Unique).Count -eq 14) 'Nenhum projeto pode desaparecer para encurtar o caminho.'

# Retomar a fatia parcial conserva sua quota; progredir depois da conclusao
# exclui todas as examinadas, mesmo sem recomendacao, no mesmo contexto.
$null=Complete-Slice $f $p 3 IN_PROGRESS
$partial=New-HarnessPrioritizationContext $f.Context -Percentage 10 -Category mandatory -Mode Continue
Assert ($partial.Reused -and $partial.ContextPath -ceq $p.ContextPath -and $partial.SliceSize -eq 7) 'Retomada parcial conserva caminho e quota original.'
Assert ((Read-Result $partial).AnalyzedIssues.Count -eq 3) 'Retomada parcial preserva as tres examinadas.'
$null=Complete-Slice $f $partial 4
$examined=@((Read-Result $partial).AnalyzedIssues | ForEach-Object { $_.Project+'|'+$_.Id })
$next=New-HarnessPrioritizationContext $f.Context -Percentage 25 -Category mandatory -Mode Continue
$n=Read-Prepared $next
Assert ($next.ContextPath -ceq $p.ContextPath -and $n.Scope -ceq 'priorizacao') 'Proxima fatia continua no mesmo escopo curto.'
Assert ($n.InitialTotal -eq 28 -and $n.SliceSize -eq 7 -and $n.ExcludedIssues.Count -eq 7 -and $n.AvailableIssues.Count -eq 21) 'Continuar mantem denominador fixo e exclui sete examinadas.'
Assert ((Read-Result $next).AnalyzedIssues.Count -eq 7) 'Resultado acumulado conserva todas as examinadas sem proposta.'
Assert (@($n.AvailableIssues | Where-Object { ($_.Project+'|'+$_.Id) -cin $examined }).Count -eq 0) 'Issue ja examinada nao volta a ser candidata.'

# Scope informado continua sendo uma escolha funcional independente.
$defaultBefore=[IO.File]::ReadAllText($next.ContextPath)
$explicit=New-HarnessPrioritizationContext $f.Context -Percentage 25 -Category mandatory -Scope frente-manual
Assert ($explicit.Scope -ceq 'frente-manual' -and (Read-Prepared $explicit).Scope -ceq 'frente-manual') 'Scope explicito nao pode ser substituido pelo padrao.'
Assert ($explicit.ContextPath -cne $next.ContextPath -and $explicit.InitialTotal -eq 28) 'Escopo explicito tem caminho proprio com os mesmos participantes.'
Assert ([IO.File]::ReadAllText($next.ContextPath) -ceq $defaultBefore) 'Criar escopo explicito preserva o contexto padrao existente.'

# Compatibilidade: quando so existe o antigo padrao concatenado, omitir Scope
# deve reencontra-lo; nao renomear arquivos nem apagar notas e cobertura.
$legacyFixture=New-Fixture 4 @('a','b')
$legacy=New-HarnessPrioritizationContext $legacyFixture.Context -Percentage 25 -Category mandatory -Scope 'a|b'
$null=Complete-Slice $legacyFixture $legacy
[IO.File]::AppendAllText($legacy.RankingPath,"`nNota humana do ranking legado: manter decisao pendente.`n")
[IO.File]::AppendAllText($legacy.IndexPath,"`nNota humana do indice legado: revisar dependencias.`n")
$legacyNext=New-HarnessPrioritizationContext $legacyFixture.Context -Percentage 25 -Category mandatory -Mode Continue
$legacyData=Read-Prepared $legacyNext
Assert ($legacyNext.Scope -ceq 'a|b' -and $legacyNext.ContextPath -ceq $legacy.ContextPath -and $legacyNext.RankingPath -ceq $legacy.RankingPath) 'Retomada automatica deve reutilizar os caminhos do escopo anterior.'
Assert ($legacyData.InitialTotal -eq 8 -and $legacyData.ExcludedIssues.Count -eq 2 -and $legacyData.SliceSize -eq 2 -and (Read-Result $legacyNext).AnalyzedIssues.Count -eq 2) 'Compatibilidade preserva base inicial e cobertura acumulada.'
Assert ([IO.File]::ReadAllText($legacyNext.RankingPath).Contains('Nota humana do ranking legado') -and [IO.File]::ReadAllText($legacyNext.IndexPath).Contains('Nota humana do indice legado')) 'Retomada preserva notas humanas dos documentos anteriores.'
Assert (@(Get-ChildItem -LiteralPath $legacyFixture.Projects[0].Folder -Recurse -Filter contexto.json).Count -eq 1) 'Retomada do legado nao cria contexto padrao paralelo.'

# Se os dois nomes ja existem para os mesmos participantes, somente uma escolha
# explicita resolve a ambiguidade. Nem Continue nem Recreate pode adivinhar.
$ambiguousFixture=New-Fixture 4 @('a','b')
$old=New-HarnessPrioritizationContext $ambiguousFixture.Context -Percentage 25 -Category mandatory -Scope 'a|b'
$null=Complete-Slice $ambiguousFixture $old
[IO.File]::AppendAllText($old.RankingPath,"`nNota exclusiva do escopo a|b.`n")
$current=New-HarnessPrioritizationContext $ambiguousFixture.Context -Percentage 25 -Category mandatory -Scope priorizacao
$null=Complete-Slice $ambiguousFixture $current
[IO.File]::AppendAllText($current.RankingPath,"`nNota exclusiva do escopo priorizacao.`n")
$statePath=Join-Path $ambiguousFixture.Root '.harness'
$ambiguousBefore=Get-ScopeFixtureBytes $statePath
foreach ($mode in @('Continue','Recreate')) {
    $failure=$null
    try { $null=New-HarnessPrioritizationContext $ambiguousFixture.Context -Percentage 25 -Category mandatory -Mode $mode } catch { $failure=$_ }
    Assert ($failure -and $failure.Exception.Message -match 'Scope|escopo') 'Dois contextos candidatos exigem erro indicando escolha explicita de Scope.'
    Assert ((Get-ScopeFixtureBytes $statePath) -ceq $ambiguousBefore) 'Ambiguidade deve preservar todos os contextos, notas, fichas e cobertura.'
}
$chosenOld=New-HarnessPrioritizationContext $ambiguousFixture.Context -Percentage 25 -Category mandatory -Scope 'a|b' -Mode Continue
$chosenCurrent=New-HarnessPrioritizationContext $ambiguousFixture.Context -Percentage 25 -Category mandatory -Scope priorizacao -Mode Continue
Assert ($chosenOld.ContextPath -ceq $old.ContextPath -and $chosenCurrent.ContextPath -ceq $current.ContextPath) 'Selecao explicita deve permitir retomar qualquer um dos contextos existentes.'
Assert ((Read-Prepared $chosenOld).ExcludedIssues.Count -eq 2 -and (Read-Prepared $chosenCurrent).ExcludedIssues.Count -eq 2) 'Escolha explicita nao mistura as coberturas existentes.'
Assert ([IO.File]::ReadAllText($chosenOld.RankingPath).Contains('Nota exclusiva do escopo a|b') -and [IO.File]::ReadAllText($chosenCurrent.RankingPath).Contains('Nota exclusiva do escopo priorizacao')) 'Cada escolha preserva suas notas.'

# O mestre a ja possui priorizacao para a,b. Acrescentar c continua exigindo
# outro Scope, inclusive ao pedir recriacao; nao reassociar o nome silenciosamente.
$participantsFixture=New-Fixture 2 @('a','b','c')
$pair=[pscustomobject]@{Root=$participantsFixture.Root;Projects=@($participantsFixture.Context.Projects | Where-Object name -In @('a','b'))}
$pairPrepared=New-HarnessPrioritizationContext $pair -Percentage 50 -Category mandatory
$statePath=Join-Path $participantsFixture.Root '.harness'
$participantsBefore=Get-ScopeFixtureBytes $statePath
foreach ($mode in @('Continue','Recreate')) {
    Reject { New-HarnessPrioritizationContext $participantsFixture.Context -Percentage 50 -Category mandatory -Mode $mode } 'Mesmo mestre e Scope padrao nao podem trocar participantes.'
    Assert ((Get-ScopeFixtureBytes $statePath) -ceq $participantsBefore) 'Recusa de participantes divergentes preserva documentos e cobertura.'
}
Assert ((Read-Prepared $pairPrepared).Projects.Count -eq 2) 'Contexto original conserva somente os participantes escolhidos.'
$otherParticipants=New-HarnessPrioritizationContext $participantsFixture.Context -Percentage 50 -Category mandatory -Scope frente-abc
Assert ((Read-Prepared $otherParticipants).Projects.Count -eq 3 -and $otherParticipants.InitialTotal -eq 6) 'Outro Scope explicito permite preparar o conjunto ampliado.'

# Mesmo nome curto em categorias diferentes tem caminhos e cobertura separados.
$categoriesFixture=New-Fixture 2 @('a','b') @('mandatory','optional')
$mandatory=New-HarnessPrioritizationContext $categoriesFixture.Context -Percentage 25 -Category mandatory
$null=Complete-Slice $categoriesFixture $mandatory
$mandatory=New-HarnessPrioritizationContext $categoriesFixture.Context -Percentage 25 -Category mandatory -Mode Continue
$mandatoryContext=[IO.File]::ReadAllText($mandatory.ContextPath)
$mandatoryRanking=[IO.File]::ReadAllText($mandatory.RankingPath)
$optional=New-HarnessPrioritizationContext $categoriesFixture.Context -Percentage 25 -Category optional
Assert ($mandatory.Scope -ceq 'priorizacao' -and $optional.Scope -ceq 'priorizacao' -and $mandatory.ContextPath -cne $optional.ContextPath) 'Categorias usam o mesmo nome curto em destinos distintos.'
Assert ($optional.InitialTotal -eq 4 -and $optional.SliceSize -eq 1 -and (Read-Prepared $optional).ExcludedIssues.Count -eq 0) 'Categoria nova nao herda cobertura de mandatory.'
$null=Complete-Slice $categoriesFixture $optional
$optionalNext=New-HarnessPrioritizationContext $categoriesFixture.Context -Percentage 25 -Category optional -Mode Continue
Assert ((Read-Prepared $optionalNext).ExcludedIssues.Count -eq 1 -and (Read-Prepared $mandatory).ExcludedIssues.Count -eq 1) 'Cada categoria mantem suas examinadas sem acumular a outra.'
Assert ([IO.File]::ReadAllText($mandatory.ContextPath) -ceq $mandatoryContext -and [IO.File]::ReadAllText($mandatory.RankingPath) -ceq $mandatoryRanking) 'Progredir optional nao altera contexto nem ranking de mandatory.'
'PASS: escopo padrao curto, continuidade, escolhas explicitas, compatibilidade, ambiguidades, participantes e categorias.'
