#requires -Version 5.1
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'SprintCurrentFixture.ps1')

function Get-PromptTargets([string]$Path) {
    $text=[IO.File]::ReadAllText($Path)
    foreach ($link in [regex]::Matches($text,'\[[^\]\r\n]+\]\(<([^>\r\n]+)>\)')) {
        # File URI explicita decodifica uma vez os percentuais do href, como o editor.
        $uri=New-Object Uri ([uri]([uri]$Path).AbsoluteUri),$link.Groups[1].Value
        Assert ($uri.IsFile -and (Test-Path -LiteralPath $uri.LocalPath)) ('Link local deve existir: '+$link.Value)
        $uri.LocalPath
    }
}

$f=New-SprintFixture @('a','b')
$globalIndex=Join-Path $f.Root '.harness/indices/projetos.md'
$null=[IO.Directory]::CreateDirectory((Split-Path $globalIndex -Parent))
[IO.File]::WriteAllText($globalIndex,'# Projetos da fixture')
$prior=New-HarnessPrioritizationContext $f.Context -Percentage 50 -Category mandatory
$null=Complete-Slice $f $prior
$current=New-HarnessSprintContext $f.Context -All -MasterProject b
$sources=Get-HarnessSprintSources $f.Context $f.Context.Projects
$expected=@($current.SprintPlanPath,$current.SprintDataPath,$globalIndex)
$expected+=@('doc/adr/0009-estado-corrente-por-projeto.md','doc/especificacoes/planejamento-sprints.md','doc/guias/tools/planejamento-sprints.md' | ForEach-Object { Join-Path $f.Root $_ })
foreach ($project in $f.Projects) { $expected+=@($project.Pom,$project.Source,$project.MigrationPath,$project.IndexPath) }
$expected+=@($sources.References | Where-Object { $_.Status -eq 'DISPONIVEL' -and $_.Kind -in @('Ficha','Evidencia') } | ForEach-Object Path)
foreach ($prompt in @($current.PromptPath,$current.ReviewPromptPath)) {
    $targets=@(Get-PromptTargets $prompt)
    foreach ($path in $expected) { Assert ($path -in $targets) ('Fonte direta ausente no prompt: '+$path) }
    Assert (@($targets | Where-Object { $_ -like '*index.html' }).Count -eq 2) 'Ambos os relatorios MTA devem estar acessiveis.'
    Assert (@($targets | Where-Object { $_ -like '*output.js' -or $_ -like '*projeto.json' }).Count -eq 0) 'Navegacao deve preferir relatorio/registro aos dados tecnicos.'
    [IO.File]::AppendAllText($prompt,([Environment]::NewLine+'Nota humana: preservar escolha do prazo.'))
}
# Templates atuais substituem orientacoes gerenciadas, sem recapturar contrato nem perder notas.
$templatePath=Join-Path $f.Root '.github/prompts/revisar-sprints.prompt.md'
[IO.File]::WriteAllText($templatePath,[IO.File]::ReadAllText($templatePath).Replace('agent: devsquad','agent: fixture-review'))
$register=[IO.File]::ReadAllText($f.Projects[0].MigrationPath)
[IO.File]::Delete($f.Projects[0].MigrationPath)
[IO.File]::Delete($f.Projects[0].IndexPath)
$revised=New-HarnessSprintContext $f.Context -ContextPath $current.ContextPath -Reason 'Registro temporariamente ausente'
foreach ($prompt in @($revised.PromptPath,$revised.ReviewPromptPath)) {
    $targets=@(Get-PromptTargets $prompt)
    Assert ($f.Projects[0].MigrationPath -notin $targets) 'Registro ausente nao deve gerar link quebrado.'
    Assert ($f.Projects[0].Source -in $targets) 'Codigo existente deve ter link mesmo com indice/registro ausentes.'
    $text=[IO.File]::ReadAllText($prompt)
    Assert ($text.Contains('Fonte indisponivel') -and $text.Contains('Nota humana: preservar escolha do prazo.')) 'Revisao deve mostrar lacuna e preservar nota humana.'
}
Assert ([IO.File]::ReadAllText($revised.ReviewPromptPath).Contains('agent: fixture-review')) 'Cabecalho de revisao deve acompanhar template atual.'
[IO.File]::WriteAllText($f.Projects[0].MigrationPath,$register)
$null=New-HarnessSprintContext $f.Context -ContextPath $current.ContextPath -Reason 'Registro recuperado'
$before=Get-PlanningFixtureState $f
$null=New-HarnessSprintContext $f.Context -ContextPath $current.ContextPath -Reason 'Registro recuperado'
Assert ((Get-PlanningFixtureState $f) -ceq $before) 'Preparo repetido deve preservar bytes e destinos.'
Assert (@(Get-ChildItem -LiteralPath (Split-Path $current.ContextPath -Parent) -File).Count -eq 5) 'Preparo nao deve criar copias operacionais de contratos ou revisoes.'
Write-Host 'PASS: fontes diretas de sprints, lacunas, cabecalhos, notas e preparo idempotente sem snapshots.'
