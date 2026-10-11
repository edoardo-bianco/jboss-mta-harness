# Reassociacao explicita do POM permite regenerar referencias derivadas copiadas.
# Nao usa caminhos estrangeiros como destinos e nao muda escopo/decisoes.
function Get-ReconciliationContextFolder {
    param($Data,$Project,[string]$Name)
    $path=[IO.Path]::GetFullPath($Data.ContextPath).Replace('\','/')
    $suffix='/.harness/projetos/'+$Project.Name+'/atual/planejamento/'+$Name
    if (-not $path.EndsWith($suffix,[StringComparison]::OrdinalIgnoreCase)) { throw 'Contexto fora do layout corrente; preserve e confira.' }
    $path.Substring(0,$path.Length-('/atual/planejamento/'+$Name).Length).Replace('/','\')
}
function Get-ReconciliationPlanningContext {
    param($Project,[byte[]]$Bytes,$Mta)
    if ($null -eq $Bytes) { return $null }
    $data=ConvertFrom-Json (ConvertFrom-ReconciliationBytes $Bytes)
    $origin=Get-ReconciliationContextFolder $data $Project 'contexto.json'
    $destinations=@{ContextPath='atual/planejamento/contexto.json';PlanPath='atual/planejamento/plano.md';TodoPath='atual/planejamento/tarefas.md';MigrationPath='migracao.md'}
    foreach ($field in $destinations.Keys) {
        if ([IO.Path]::GetFullPath($data.$field) -ine (Join-Path $origin $destinations[$field])) { throw "Destino divergente no contexto copiado: $field" }
    }
    $relocated=$origin -ine $Project.Folder -or $data.Pom -ine $Project.Pom -or $data.Source -ine $Project.Source
    foreach ($field in $destinations.Keys) { $data.$field=$Project.$field }
    Assert-CurrentPlanningContext $data $Project
    if ($relocated) {
        $data.Source=$Project.Source; $data.Pom=$Project.Pom
        $data.PromptPath=Join-Path $Project.Folder 'atual/planejamento/planejar-lotes.prompt.md'
        $data.ReconciledPath=Join-Path $Project.ReconciledPath 'resultado.md'
        $data.ContractPath=Join-Path $Project.Root 'doc/adr/0009-estado-corrente-por-projeto.md'
        $index=$data.EvidenceIndexPath
        if ($index -and [IO.Path]::GetFullPath($index).StartsWith($origin+'\',[StringComparison]::OrdinalIgnoreCase)) {
            $index=Join-Path $Project.Folder ([IO.Path]::GetFullPath($index).Substring($origin.Length+1))
        }
        $rows=@($data.SelectedIssues | ForEach-Object {[pscustomobject]@{Id=$_.Id;Category=$_.Category;Note=$_.Scope}})
        $evidence=Get-CurrentPlanningEvidence $Project $rows $index
        $data.EvidenceIndexPath=$evidence.IndexPath; $data.EvidenceInputs=@($evidence.Inputs); $data.FichaPaths=@($evidence.Fichas)
        $data.Mta=if ($data.PlanningBasis -eq 'MTA' -and $Mta) {@{ReportPath=$Mta.ReportPath;CatalogPath=$Mta.CatalogPath}} else {$null}
        $data.Diagnostics=@($evidence.Warnings)
        $data.NeedsReview=$true
        $data.ReviewReasons=@(@($data.ReviewReasons)+@('Projeto copiado/realocado: conferir origens e proposta no Source local; GO recebido nao autoriza implementacao.') | Select-Object -Unique)
    }
    [pscustomobject]@{Data=$data;Relocated=$relocated}
}
