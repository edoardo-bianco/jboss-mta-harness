#requires -Version 5.1
$ErrorActionPreference='Stop'; Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'PlanningCurrentFixture.ps1')
function Assert-PromptLinks([string]$Path,[switch]$Mta) {
    $text=[IO.File]::ReadAllText($Path)
    $links=[regex]::Matches($text,'\[[^\]\r\n]+\]\(<([^>\r\n]+)>\)')
    Assert ($links.Count -ge 2) ('Prompt deve oferecer navegacao legivel: '+$Path)
    $html=$false
    foreach ($link in $links) {
        $uri=New-Object Uri ([uri]$Path),$link.Groups[1].Value
        Assert ($uri.IsFile -and (Test-Path -LiteralPath $uri.LocalPath)) ('Link deve abrir documento existente: '+$link.Value)
        Assert ($uri.LocalPath -notmatch '(?i)\.(json|js)$') ('Navegacao deve preferir o documento legivel: '+$link.Value)
        if ($uri.LocalPath.EndsWith('index.html')) { $html=$true }
    }
    Assert ($html -eq [bool]$Mta) 'Relatorio HTML so deve aparecer quando a base MTA estiver disponivel.'
}
$prior=New-Fixture 2 @('prior','sem-registro')
[IO.File]::Delete($prior.Projects[1].MigrationPath)
$prepared=New-HarnessPrioritizationContext $prior.Context -Percentage 50 -Category mandatory
Assert-PromptLinks $prepared.PromptPath -Mta
Assert ([IO.File]::ReadAllText($prepared.PromptPath).Contains('Registro indisponivel: sem-registro')) 'Origem ausente exige lacuna explicita, sem link quebrado.'
foreach ($basis in @('MTA','EVIDENCIAS')) {
    $f=New-PlanningFixture 1
    $p=$f.Projects[0]
    if ($basis -eq 'EVIDENCIAS') { Set-ManualPlanningChoice $p }
    $register=[IO.File]::ReadAllText($p.MigrationPath)
    $planning=New-HarnessCurrentPlanning $f.Context -PlanningBasis $basis
    Assert-PromptLinks $planning.PromptPath -Mta:($basis -eq 'MTA')
    Assert (-not (Test-Path $p.PlanPath) -and -not (Test-Path $p.TodoPath)) 'Links nao devem criar proposta ficticia.'
    $reconciliation=New-HarnessReconciliationContext $f.Context -PlanningBasis $basis -LocalOnly
    Assert-PromptLinks $reconciliation.PromptPath -Mta:($basis -eq 'MTA')
    foreach ($operation in @('implementar-lote','revisar-resultado')) {
        Copy-Item -LiteralPath (Join-Path $root ('.github/prompts/'+$operation+'.prompt.md')) -Destination (Join-Path $f.Root '.github/prompts')
    }
    Publish-HarnessProjectFiles $p @{'atual/planejamento/plano.md'='PROPOSTA - GO PENDENTE';'atual/planejamento/tarefas.md'='Verificacoes pendentes'}
    $guide=Join-Path $f.Root 'doc/guias/tools/planejamento-migracao.md'
    $null=[IO.Directory]::CreateDirectory((Split-Path $guide -Parent))
    [IO.File]::WriteAllText($guide,'Guia da fixture')
    $implementation=New-HarnessImplementationPrompt $f.Context
    Assert-PromptLinks $implementation.PromptPath -Mta:($basis -eq 'MTA')
    Assert-PromptLinks $implementation.ResultReviewPromptPath -Mta:($basis -eq 'MTA')
    Assert ([IO.File]::ReadAllText($p.MigrationPath) -ceq $register) 'Preparo de prompts nao pode alterar decisoes humanas.'
    Assert ([IO.File]::ReadAllText($p.PlanPath) -ceq 'PROPOSTA - GO PENDENTE') 'Preparo nao concede GO ou aceite.'
}
Write-Host 'PASS: prompts correntes MTA/EVIDENCIAS com links existentes e legiveis, sem proposta ficticia ou GO inferido.'
