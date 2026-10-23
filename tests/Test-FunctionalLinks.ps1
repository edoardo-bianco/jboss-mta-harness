#requires -Version 5.1
[CmdletBinding()]
param([switch]$ChildRuntime)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$temporaryRoot=Split-Path -Parent $root
$marker=Join-Path $temporaryRoot 'owner.txt'
if ((Split-Path $root -Leaf) -cne 'checkout' -or (Split-Path $temporaryRoot -Leaf) -notmatch '^harness-test-[0-9a-f]{12}$' -or -not (Test-Path -LiteralPath $marker -PathType Leaf)) {
    throw 'Execute somente por tests/Invoke-HarnessTests.ps1 -Test Test-FunctionalLinks.ps1, na copia temporaria isolada.'
}
Import-Module (Join-Path $root 'scripts/HarnessProject.psm1') -Force -DisableNameChecking
$runtime=$PSVersionTable.PSVersion.Major
if ($runtime -eq 5) {
    # HarnessPlanning/Harness exigem Windows PowerShell 5.1. O filho PS7 cobre
    # somente o modulo de caminhos, sem contornar a restricao dos consumidores.
    Import-Module (Join-Path $root 'scripts/HarnessPlanning.psm1') -Force -DisableNameChecking
    $planningModule=Get-Module HarnessPlanning
}
function Assert($condition,[string]$message) { if (-not $condition) { throw $message } }
function Write-Fixture([string]$Path,[string]$Text) {
    $null=[IO.Directory]::CreateDirectory((Split-Path -Parent $Path))
    [IO.File]::WriteAllText($Path,$Text)
}
function Get-ExplicitFileUri([string]$Path) {
    # Oracle independente: URI file:/// explicita; nunca interpretar um caminho DOS
    # como URI. Cada segmento representa o nome LITERAL existente no filesystem.
    $full=[IO.Path]::GetFullPath($Path).Replace('\','/')
    $segments=@($full.Substring(3).Split('/') | ForEach-Object { [Uri]::EscapeDataString($_) })
    [Uri]('file:///'+$full.Substring(0,3)+($segments -join '/'))
}
function Resolve-MarkdownLink([string]$From,[string]$Link,[bool]$ExpectedAbsolute=$false,[string]$ExpectedFragment='') {
    $match=[regex]::Match($Link,'^\[[^\]\r\n]*\]\(<(?<destination>[^>\r\n]*)>\)$')
    Assert $match.Success ('Link Markdown invalido: '+$Link)
    $destination=[Uri]::new($match.Groups['destination'].Value,[UriKind]::RelativeOrAbsolute)
    Assert ($destination.IsAbsoluteUri -eq $ExpectedAbsolute) ('Tipo de URI inesperado: '+$Link)
    $resolved=[Uri]::new((Get-ExplicitFileUri $From),$destination)
    Assert ($resolved.IsFile -and $resolved.Fragment -ceq $ExpectedFragment -and -not $resolved.Query) ('Caminho/fragmento/query inesperado: '+$Link)
    $resolved.LocalPath
}
function Assert-FileLink([string]$From,[string]$Path,[string]$ExpectedText) {
    $link=Get-HarnessSourceLink -From $From -Path $Path -Label 'Ficha ou evidencia'
    $resolved=Resolve-MarkdownLink $From $link
    Assert ($resolved -ceq [IO.Path]::GetFullPath($Path)) ('Link mudou o caminho literal: '+$link+' -> '+$resolved)
    Assert (Test-Path -LiteralPath $resolved -PathType Leaf) ('Link nao abre arquivo real: '+$link)
    Assert ([IO.File]::ReadAllText($resolved) -ceq $ExpectedText) ('Link abriu outro arquivo: '+$link)
}
$area=Join-Path $root ('.harness/tests/links-'+$runtime)
$from=Join-Path $area 'migracao.md'
Write-Fixture $from 'Registro com links para fichas e evidencias.'
$script:casePassed=0
$script:caseFailures=New-Object 'Collections.Generic.List[string]'
function Test-Case([string]$Name,[scriptblock]$Action) {
    try { & $Action; $script:casePassed++ }
    catch { $script:caseFailures.Add(('PS'+$runtime+' / '+$Name+': '+$_.Exception.Message)) }
}

Test-Case 'Ficha manual com ID maiusculo e identidade preservada' {
    $id='DEV-SWAGGER-JACKSON-01'
    $folder=ConvertTo-HarnessFunctionalPath $id
    $path=Join-Path $area ('manual/issues/'+$folder+'/ficha.md')
    $text='{"Project":"simtr-parent","Category":"manual","Id":"'+$id+'"}'
    Write-Fixture $path $text
    Assert-FileLink $from $path $text
    Assert (([IO.File]::ReadAllText($path) | ConvertFrom-Json).Id -ceq $id) 'Navegacao alterou a identidade manual.'
    Assert ([Uri]::UnescapeDataString((Split-Path (Split-Path $path -Parent) -Leaf)) -ceq $id) 'Pasta deixou de representar o ID manual.'
}
Test-Case 'Ficha MTA com delimitadores de ruleset e caminho' {
    $id='eap7/weblogic/tests/data::hibernate4-00039'
    $path=Join-Path $area ('mandatory/issues/'+(ConvertTo-HarnessFunctionalPath $id)+'/ficha.md')
    Write-Fixture $path $id
    Assert-FileLink $from $path $id
}
Test-Case 'Percentuais literais distintos de caracteres decodificados' {
    foreach ($pair in @(@('%20',' '),@('%44','D'),@('%2520','%20'),@('100%','100'))) {
        $literal=Join-Path $area ('evidencias/log-'+$pair[0]+'.log')
        $decoy=Join-Path $area ('evidencias/log-'+$pair[1]+'.log')
        Write-Fixture $literal ('literal: '+$pair[0])
        Write-Fixture $decoy 'Arquivo diferente; nao deve ser aberto.'
        Assert-FileLink $from $literal ('literal: '+$pair[0])
    }
}
Test-Case 'Espacos, cerquilha, acentos e parenteses em arquivo real' {
    $accent='a'+[char]0xE7+[char]0xE3+'o'
    $path=Join-Path $area ('evidencias/ensaio '+$accent+' #1 (local)/falha #2 (antes).log')
    Write-Fixture $path 'Falha antes da corretiva.'
    Assert-FileLink $from $path 'Falha antes da corretiva.'
}
Test-Case 'Origem codificada para evidencia e retorno para ficha' {
    $issueFolder=ConvertTo-HarnessFunctionalPath 'DEV-LINK-01'
    $issue=Join-Path $area ('manual/issues/'+$issueFolder+'/ficha.md')
    $evidence=Join-Path $area 'evidencias/ensaio %20 #1/falha.log'
    Write-Fixture $issue 'Ficha de origem e destino.'
    Write-Fixture $evidence 'Log com caminho literal.'
    Assert-FileLink $issue $evidence 'Log com caminho literal.'
    Assert-FileLink $evidence $issue 'Ficha de origem e destino.'
    Assert-FileLink $issue $issue 'Ficha de origem e destino.'
}
Test-Case 'Pastas codificadas distintas na origem e destino' {
    $a=Join-Path $area ((ConvertTo-HarnessFunctionalPath 'DEV-A')+'/registro.md')
    $b=Join-Path $area ((ConvertTo-HarnessFunctionalPath 'DEV-B')+'/ficha.md')
    Write-Fixture $a 'Origem codificada.'
    Write-Fixture $b 'Destino codificado.'
    Assert-FileLink $a $b 'Destino codificado.'
}
Test-Case 'Outra unidade usa URI absoluta sem exigir unidade montada' {
    $accent='a'+[char]0xE7+[char]0xE3+'o'
    $origin='C:\harness\%44%45%56\registro #1.md'
    $target='Z:\evidencias\log %20 #1 ('+$accent+').log'
    $link=Get-HarnessSourceLink -From $origin -Path $target -Label 'Log externo'
    $resolved=Resolve-MarkdownLink $origin $link $true
    Assert ($resolved -ceq $target) ('URI entre unidades alterou o caminho: '+$link+' -> '+$resolved)
}

if ($runtime -eq 5) {
Test-Case 'Leitor do planejamento resolve indice e registro sob percentual literal' {
    $workspace=Join-Path $area 'workspace %20'
    $pom=Join-Path $workspace 'source/pom.xml'
    Write-Fixture $pom '<project><artifactId>aplicacao</artifactId></project>'
    $project=Get-HarnessProjectReference $workspace $pom
    $index=Join-Path $project.EvidencePath 'LEIA-ME.md'
    $attachment=Join-Path $project.EvidencePath 'anexo%20.log'
    $registerAttachment=Join-Path $project.EvidencePath 'registro%20.log'
    Write-Fixture $attachment 'Evidencia indicada pelo indice.'
    Write-Fixture $registerAttachment 'Evidencia indicada pelo registro.'
    # Entradas corretas independentes do gerador: %25 representa o percentual
    # LITERAL do nome. A base do indice/registro tambem contem um %20 literal.
    Write-Fixture $index "| Issue | Arquivo | Relacao |`n| --- | --- | --- |`n| DEV-LINK-02 | [Anexo](<anexo%2520.log>) | Antes da corretiva |"
    $note='[Evidencia](<evidencias/registro%2520.log>)'
    Write-Fixture $project.MigrationPath $note
    $rows=@([pscustomobject]@{Id='DEV-LINK-02';Category='manual';Note=$note})
    $result=Get-CurrentPlanningEvidence $project $rows
    foreach ($expected in @($index,$attachment,$registerAttachment)) {
        $matchingInput=@($result.Inputs | Where-Object { $_.Path -ceq $expected -and $_.Status -ceq 'DISPONIVEL' })
        Assert ($matchingInput.Count -eq 1) ('Leitor nao encontrou o arquivo literal disponivel: '+$expected)
        Assert (Test-Path -LiteralPath $matchingInput[0].Path -PathType Leaf) 'Referencia disponivel deve abrir arquivo real.'
        Assert ([IO.File]::ReadAllText($matchingInput[0].Path) -ceq [IO.File]::ReadAllText($expected)) 'Leitor abriu outra evidencia.'
    }
    Assert ($result.Warnings.Count -eq 0) 'Escapes corretos nao podem gerar lacunas ficticias.'
}

function New-ReconciliationLinkFixture {
    $oldFolder=Join-Path $area 'origem %20/projeto'
    $newFolder=Join-Path $area 'destino %20/projeto'
    $contexts=@(foreach ($folder in @($oldFolder,$newFolder)) {
        [pscustomobject]@{
            ContextPath=$null;RankingPath=(Join-Path $folder 'priorizacao.md');PromptPath=$null
            IndexPath=$null;ContractPath=$null;PrioritizationIndexPath=$null
            Projects=@([pscustomobject]@{Project='aplicacao';Source=(Join-Path $folder 'source');MigrationPath=(Join-Path $folder 'migracao.md')})
        }
    })
    $fromRelative='atual/priorizacao/manual/issues/%44%45%56-A/ficha.md'
    $targetRelative='atual/priorizacao/manual/issues/%44%45%56-B/ficha.md'
    $oldFrom=Join-Path $oldFolder $fromRelative
    $newFrom=Join-Path $newFolder $fromRelative
    $oldTarget=Join-Path $oldFolder $targetRelative
    $newTarget=Join-Path $newFolder $targetRelative
    Write-Fixture $oldFrom 'Ficha de origem.'
    Write-Fixture $newFrom 'Ficha recebida.'
    Write-Fixture $oldTarget "# Achado`nEvidencia na origem."
    Write-Fixture $newTarget "# Achado`nEvidencia local."
    [pscustomobject]@{Original=$contexts[0];Current=$contexts[1];OldFrom=$oldFrom;NewFrom=$newFrom;OldTarget=$oldTarget;NewTarget=$newTarget
        Peer=[pscustomobject]@{Name='aplicacao';Source=(Join-Path $newFolder 'source');Folder=$newFolder}}
}
Test-Case 'Leitor da reconciliacao preserva percentual na base e na ficha referenciada' {
    $fixture=New-ReconciliationLinkFixture
    $text='[Ficha relacionada](<../%2544%2545%2556-B/ficha.md#achado>)'
    $references=@(& $planningModule { param($content,$fromPath) Get-ReconciliationMarkdownReferences $content $fromPath } $text $fixture.OldFrom)
    Assert ($references.Count -eq 1 -and $references[0] -ceq $fixture.OldTarget) 'Leitor da reconciliacao decodificou a pasta literal ou confundiu o fragmento com o arquivo.'
    Assert (Test-Path -LiteralPath $references[0] -PathType Leaf) 'Referencia da reconciliacao nao abre a ficha real.'
    Assert ([IO.File]::ReadAllText($references[0]).Contains('Evidencia na origem.')) 'Referencia abriu uma ficha diferente.'
}
Test-Case 'Relocalizacao de ficha preserva pasta literal e fragmento' {
    $fixture=New-ReconciliationLinkFixture
    # O link absoluto correto exige a troca de origem; mante-lo inalterado
    # apontaria para o arquivo estrangeiro, mesmo havendo ficha local equivalente.
    $text='[Ficha relacionada](<'+(Get-ExplicitFileUri $fixture.OldTarget).AbsoluteUri+'#achado>)'
    $rewritten=& $planningModule {
        param($content,$original,$current,$peer,$oldFrom,$newFrom)
        Convert-ReconciliationPriorityLinks $content $original $current @($peer) $oldFrom $newFrom
    } $text $fixture.Original $fixture.Current $fixture.Peer $fixture.OldFrom $fixture.NewFrom
    $resolved=Resolve-MarkdownLink $fixture.NewFrom $rewritten $false '#achado'
    Assert ($resolved -ceq $fixture.NewTarget) 'Relocalizacao alterou o nome literal ou manteve a origem estrangeira.'
    Assert (Test-Path -LiteralPath $resolved -PathType Leaf) 'Link relocalizado nao abre a ficha local.'
    Assert ([IO.File]::ReadAllText($resolved).Contains('Evidencia local.')) 'Relocalizacao abriu outra ficha.'
}
}

# O wrapper executa PS5.1. Repetir dentro da MESMA copia isolada cobre as
# diferencas de System.Uri do PS7 sem executar suite no checkout operacional.
if (-not $ChildRuntime -and $runtime -eq 5) {
    $pwsh=Get-Command pwsh.exe -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($pwsh) {
        & $pwsh.Source -NoProfile -NonInteractive -File $PSCommandPath -ChildRuntime
        if ($LASTEXITCODE -ne 0) { $script:caseFailures.Add('A rodada PS7 falhou; veja os casos acima.') }
    } else { Write-Output 'SKIP PS7: pwsh.exe nao disponivel; rodada PS5.1 executada.' }
}
foreach ($failure in $script:caseFailures) { Write-Output ('FAIL: '+$failure) }
if ($script:caseFailures.Count) { throw ('Links funcionais: '+$script:caseFailures.Count+' falha(s) em PS'+$runtime+'.') }
$coverage=if ($runtime -eq 5) {'7 casos URI e 3 casos de consumidores (planejamento/reconciliacao)'} else {'7 casos URI; consumidores exclusivos do Windows PowerShell 5.1'}
Write-Output ('PASS PS'+$runtime+': '+$script:casePassed+' casos ('+$coverage+'); fixtures reais e outra unidade em memoria.')
