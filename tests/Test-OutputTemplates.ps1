#requires -Version 5.1
$ErrorActionPreference='Stop'; Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'PlanningCurrentFixture.ps1')
$names=@('indice-projetos','indice-projeto','migracao','indice-priorizacoes','indice-priorizacao','priorizacao','orientacao-priorizacao','ficha-issue','plano-lote','tarefas-lote','evidencias','reconciliacao')
foreach ($name in $names) {
    Assert (Test-Path -LiteralPath (Join-Path $root ('doc/modelos/'+$name+'.template.md'))) ('Template corrente ausente: '+$name)
}
Import-Module (Join-Path $root 'scripts/HarnessDocumentTemplates.psm1') -DisableNameChecking
$f=New-PlanningFixture 2
$project=$f.Projects[0]
$register=[IO.File]::ReadAllText($project.MigrationPath)
$prior=New-HarnessPrioritizationContext $f.Context -Percentage 50 -Category mandatory
$null=Complete-Slice $f $prior
$null=Update-HarnessPrioritizationIndex $f.Root
foreach ($path in @($prior.RankingPath,$prior.IndexPath,$prior.PrioritizationIndexPath)) {
    $text=[IO.File]::ReadAllText($path)
    Assert ($text.Contains('Decisao=ANALISAR AGORA') -and $text.Contains('Observacao/referencia') -and $text.Contains('Planejamento: planejar')) 'Toda saida de priorizacao deve orientar a escolha no registro.'
}
Assert ([IO.File]::ReadAllText($project.MigrationPath) -ceq $register) 'Orientacao nao pode escolher a issue pelo humano.'
$planning=New-HarnessCurrentPlanning $f.Context
$reconciliation=New-HarnessReconciliationContext $f.Context -LocalOnly
foreach ($pair in @(@($prior.PromptPath,@('priorizacao','indice-priorizacao','indice-priorizacoes','orientacao-priorizacao','ficha-issue')),@($planning.PromptPath,@('plano-lote','tarefas-lote','ficha-issue')),@($reconciliation.PromptPath,@('migracao','plano-lote','tarefas-lote','ficha-issue','evidencias','reconciliacao')))) {
    $prompt=[IO.File]::ReadAllText($pair[0])
    foreach ($name in $pair[1]) {
        Assert ($prompt.Contains($name+'.template.md')) ('Prompt deve vincular template: '+$name)
    }
    Assert ($prompt.Contains('Modelos de saida obrigatorios')) 'Prompt preparado deve exigir leitura dos modelos.'
}
Assert (-not (Test-Path -LiteralPath $project.PlanPath) -and -not (Test-Path -LiteralPath $project.TodoPath)) 'Vincular templates nao fabrica proposta.'
# Alterar o modelo na copia de teste comprova consumo real pelo produtor.
foreach ($name in @('migracao','indice-projeto','priorizacao','indice-priorizacao','indice-priorizacoes','orientacao-priorizacao')) {
    $path=Get-HarnessDocumentTemplatePath $name
    $before=[IO.File]::ReadAllBytes($path)
    try {
        $text=[IO.File]::ReadAllText($path)
        $text=$text -replace '(?m)^# ',('# TEMPLATE-CONSUMIDO-'+$name+' ')
        if ($name -eq 'orientacao-priorizacao') { $text=$text.Replace('## Proximo passo','## TEMPLATE-CONSUMIDO-orientacao-priorizacao') }
        [IO.File]::WriteAllText($path,$text)
        $fresh=New-Fixture 1
        $prepared=New-HarnessPrioritizationContext $fresh.Context -Percentage 100 -Category mandatory
        $target=switch ($name) {
            'migracao' {$fresh.Projects[0].MigrationPath}
            'indice-projeto' {$fresh.Projects[0].IndexPath}
            'priorizacao' {$prepared.RankingPath}
            'indice-priorizacao' {$prepared.IndexPath}
            'indice-priorizacoes' {$prepared.PrioritizationIndexPath}
            'orientacao-priorizacao' {$prepared.RankingPath}
        }
        Assert ([IO.File]::ReadAllText($target).Contains('TEMPLATE-CONSUMIDO-'+$name)) ('Gerador deve consumir '+$name)
    } finally { [IO.File]::WriteAllBytes($path,$before) }
}
'PASS: templates correntes usados pelos geradores e vinculados aos prompts, com escolha humana padronizada.'

# Modelo de reconciliacao usado pela publicacao protegida, sem agente.
$model=Get-HarnessDocumentTemplatePath 'reconciliacao'
$bytes=[IO.File]::ReadAllBytes($model)
try {
    [IO.File]::AppendAllText($model,[Environment]::NewLine+'TEMPLATE-RECONCILIACAO-CONSUMIDO')
    $fresh=New-PlanningFixture 1
    $null=Start-HarnessReconciliationReview $fresh.Projects[0]
    $published=Complete-HarnessReconciliation $fresh.Projects[0] -Conclusion 'Conferencia sintetica de fontes e documentos.'
    Assert ([IO.File]::ReadAllText($published.ReconciledPath).Contains('TEMPLATE-RECONCILIACAO-CONSUMIDO')) 'Publicador deve consumir o template de reconciliacao.'
} finally { [IO.File]::WriteAllBytes($model,$bytes) }
