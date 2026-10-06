# Contextos de planejamento: copias consolidadas sao suficientes para a consulta.
function Read-QueryConsolidated {
    param($Receipt,[string]$Root,$Files,[string]$Basis)
    if ($Receipt.LayoutVersion -ne 2 -or @($Receipt.SelectedIssues).Count -ne 1 -or $Receipt.SelectedIssues[0].Id -cne $Receipt.IssueId) {
        Stop-QueryError IDENTITY_CONFLICT 'Selecao/layout da issue consolidada divergente.'
    }
    $folder=Resolve-HarnessPath (Split-Path $Receipt.ContextPath -Parent) $Root
    foreach ($file in $Receipt.Consolidated.Files) {
        if ([IO.Path]::IsPathRooted($file.RelativePath) -or $file.RelativePath -match '(^|[\\/])\.\.([\\/]|$)') { Stop-QueryError INVALID_CONTEXT 'Caminho consolidado invalido.' }
        $path=Resolve-HarnessPath (Join-Path $folder $file.RelativePath) $Root
        if (-not $path.StartsWith($folder+'\',[StringComparison]::OrdinalIgnoreCase) -or $file.Sha256 -notmatch '^[A-Fa-f0-9]{64}$') { Stop-QueryError INVALID_CONTEXT 'Arquivo/hash consolidado invalido.' }
        $null=Read-QueryFile $path $Files $file.Sha256
    }
    # O validador de planejamento tambem confere origens humanas mutaveis.
    # Na consulta, validar somente copias: nao abrir SourceEvidenceInputs historicos.
    $local=$Receipt.PSObject.Copy()
    $local | Add-Member NoteProperty SourceEvidenceInputs @() -Force
    $local | Add-Member NoteProperty PlanningBasis $Basis -Force
    Assert-HarnessPlanningEvidence $local $Root
    if ($Basis -ne 'MTA') { return }
    $mta=Read-QueryFile $Receipt.Consolidated.MtaIssuePath $Files | ConvertFrom-Json
    Assert-QueryOrigin $mta.MtaOrigin $Receipt.MtaOrigin
    if ($mta.CatalogSha256 -ine $Receipt.CatalogSha256 -or $mta.CatalogSha256 -notmatch '^[a-fA-F0-9]{64}$') { Stop-QueryError IDENTITY_CONFLICT 'Hash de origem do recorte MTA divergente.' }
    if ($null -eq $mta.Issue) {
        if ($Receipt.IssueId -notlike 'DEV-*') { Stop-QueryError INVALID_CONTEXT 'Recorte MTA sem issue.' }
        return
    }
    $issue=$mta.Issue
    if ($issue.Id -cne $Receipt.IssueId -or $issue.Details.incidents -isnot [Array] -or $issue.Count -ne $issue.Details.incidents.Count -or
        $issue.Category -cne $issue.Details.category -or $issue.Title -cne $issue.Details.description) { Stop-QueryError IDENTITY_CONFLICT 'Conteudo interno da issue MTA divergente.' }
    $issue
}

function Read-QueryOriginalMta {
    param($Mta,[string]$Root,$Files)
    foreach ($pair in @(@('Manifest','manifest.json'),@('Result','result.json'),@('Findings','output/output.yaml'),@('Dependencies','output/dependencies.yaml'))) {
        if ($Mta.EvidenceHashes.($pair[0]) -notmatch '^[A-Fa-f0-9]{64}$') { Stop-QueryError INVALID_CONTEXT 'Hash obrigatorio de evidencia MTA ausente/invalido.' }
        $null=Read-QueryFile (Join-Path $Mta.Run $pair[1]) $Files $Mta.EvidenceHashes.($pair[0])
    }
    $run=Get-MtaPlanningRunFromPath $Mta.Run $Root
    Assert-QueryOrigin $run.Manifest $Mta.MtaOrigin
    if ($run.RunId -cne $Mta.RunId) { Stop-QueryError IDENTITY_CONFLICT 'RunId difere dos artefatos.' }
    $catalog=Resolve-HarnessPath (Join-Path $Mta.Run 'output/static-report/output.js') $Root
    if ((Resolve-HarnessPath $Mta.CatalogPath $Root) -ine $catalog -or $Mta.CatalogSha256 -notmatch '^[A-Fa-f0-9]{64}$') { Stop-QueryError INVALID_CONTEXT 'Caminho/hash do catalogo invalido.' }
    $null=Read-QueryFile $catalog $Files $Mta.CatalogSha256
    try { Get-HarnessMtaCatalog $Mta.Run $Root -IncludeIncidents }
    catch { Stop-QueryError UNSUPPORTED_FORMAT $_.Exception.Message }
}
