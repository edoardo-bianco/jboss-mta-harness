function Add-TransferFile {
    param($Manifest,[string]$Path,[string]$Role,[switch]$Optional)
    $path=Resolve-HarnessPath $Path $Manifest.OriginRoot
    if ([IO.Path]::GetFileName($path) -match '^(?i:settings\.xml|credentials|\.env(?:\..*)?|id_rsa|id_ed25519)$|\.(?i:pem|pfx|p12|key)$') { throw "Credenciais/settings pessoais nao entram no pacote: $path" }
    if ($Manifest._FileIndex.ContainsKey($path)) { return $Manifest._FileIndex[$path] }
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        if (-not $Optional) { throw "Arquivo necessario ao pacote ausente: $path" }
        $Manifest.Missing += $path; return $null
    }
    Assert-TransferRegularPath $path
    $entry='files/'+$Manifest.Files.Count.ToString('00000')+'/'+[IO.Path]::GetFileName($path)
    Assert-TransferRelativePath $entry
    $Manifest.Files.Add([pscustomobject]@{Entry=$entry;OriginPath=$path;Role=$Role;Length=(Get-Item -LiteralPath $path).Length;Sha256=(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash})
    $Manifest._FileIndex[$path]=$entry
    $entry
}
function Add-TransferProject {
    param($Manifest,$Context,[string]$Source)
    if (@($Manifest.Projects | Where-Object { (Resolve-HarnessPath $_.Source $Context.Root) -ieq (Resolve-HarnessPath $Source $Context.Root) }).Count) { return }
    $projects=@($Context.Projects | Where-Object { (Resolve-HarnessPath $_.path $Context.Root) -ieq (Resolve-HarnessPath $Source $Context.Root) })
    if ($projects.Count -ne 1) { throw 'Projeto do contexto nao pertence unicamente ao workspace escolhido.' }
    $project=$projects[0]
    $paths=Get-HarnessMigrationPaths $Context.Root $project
    $issuePaths=Get-HarnessIssueProjectPaths $Context.Root $project
    $register=Read-HarnessMigrationInput $Context.Root $project $paths.MigrationPath
    $entry=Add-TransferFile $Manifest $register.MigrationPath 'REGISTER'
    $Manifest.Projects += [pscustomobject]@{Source=$Source;Project=$project.name;Label=$project.label;ArtifactId=$issuePaths.ArtifactId;RegisterEntry=$entry;EvidenceEntries=@();EvidenceIndexOrigin=$paths.EvidenceIndexPath}
}
function Export-HarnessContextPackage {
    [CmdletBinding()]
    param($Context,[Parameter(Mandatory=$true)][string]$ContextPath,[Parameter(Mandatory=$true)][string]$PackagePath)
    $path=Resolve-HarnessPath $ContextPath $Context.Root
    $record=Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
    $manifest=[ordered]@{SchemaVersion=1;PackageId=[guid]::NewGuid().ToString('N');CreatedAtUtc=[DateTime]::UtcNow.ToString('o');Kind='PLANEJAMENTO';Stage='PLANO_E_TODO_PRESENTES';Decision='CONSULTAR_DOCUMENTOS';OriginRoot=$Context.Root;ContextEntry=$null;Projects=@();Receipts=@();Files=(New-Object 'Collections.Generic.List[object]');Missing=@();MtaRuns=@();_FileIndex=@{}}
    if ($record.Purpose -eq 'issue-prioritization') {
        Add-TransferAnalysis $manifest $Context $path
        return Write-TransferArchive $manifest $PackagePath
    }
    if ($record.Purpose -ne 'application-remediation' -or $record.LayoutVersion -ne 2 -or $record.EvidenceMode -ne 'CONSOLIDATED') { throw 'Exportacao de plano exige contexto por issue consolidado.' }
    Add-TransferProject $manifest $Context $record.Source
    $project=@($Context.Projects | Where-Object { (Resolve-HarnessPath $_.path $Context.Root) -ieq (Resolve-HarnessPath $record.Source $Context.Root) })[0]
    $history=@(Get-MtaPlanningHistory ([pscustomobject]@{Root=$Context.Root;Active=$project}) -IncludePrepared)
    $selected=@($history | Where-Object { (Resolve-HarnessPath $_.ContextPath $Context.Root) -ieq $path })
    if ($selected.Count -ne 1) { throw 'Contexto nao reconhecido no historico local.' }
    foreach ($file in @($record.PlanPath,$record.TodoPath)) { if (-not (Test-Path -LiteralPath $file -PathType Leaf)) { throw 'Plano/to-do ainda ausentes; execute o planejamento antes de exportar.' } }
    $seen=@{}; $cursor=$selected[0]
    while ($cursor) {
        if ($seen.ContainsKey($cursor.RequestId)) { throw 'Ciclo na cadeia de planejamento.' }; $seen[$cursor.RequestId]=$true
        if ($cursor.LayoutVersion -ne 2 -or $cursor.EvidenceMode -ne 'CONSOLIDATED') { throw 'Cadeia inclui recibo legado: recrie um contexto consolidado independente antes de exportar.' }
        Assert-HarnessPlanningEvidence $cursor $Context.Root -Historical:($cursor.RequestId -ne $record.RequestId)
        $entry=Add-TransferFile $manifest $cursor.ContextPath 'CONTEXT'
        if ($cursor.RequestId -eq $record.RequestId) { $manifest.ContextEntry=$entry }
        $manifest.Receipts += [pscustomobject]@{Entry=$entry;RequestId=$cursor.RequestId;Source=$cursor.Source;IssueId=$cursor.IssueId}
        foreach ($file in @($cursor.PlanPath,$cursor.TodoPath)) { $null=Add-TransferFile $manifest $file 'DOCUMENT' -Optional }
        $null=Add-TransferFile $manifest (Join-Path (Split-Path $cursor.ContextPath -Parent) 'planejar-lotes.prompt.md') 'PROMPT'
        foreach ($file in $cursor.Consolidated.Files) { $null=Add-TransferFile $manifest (Join-Path (Split-Path $cursor.ContextPath -Parent) $file.RelativePath) 'EVIDENCE' }
        foreach ($input in $cursor.SourceEvidenceInputs) { if ($input.Status -ne 'DISPONIVEL') { $manifest.Missing += $input.Reference } }
        if (-not $cursor.Previous) { break }
        $parents=@($history | Where-Object RequestId -CEQ $cursor.Previous.RequestId)
        if ($parents.Count -ne 1) { throw 'Previous ausente ou ambiguo; nao exportar historico truncado.' }
        if ($parents[0].IssueId -cne $record.IssueId) { throw 'Previous de outra issue; nao misturar recortes no pacote.' }
        foreach ($field in @('Context','Plan','Todo')) {
            $expected=$cursor.Previous.($field+'Sha256')
            if ($expected -and (Get-FileHash -LiteralPath $parents[0].($field+'Path')).Hash -cne $expected) { throw 'Documento Previous alterado; confira a revisao antes de exportar.' }
        }
        $cursor=$parents[0]
    }
    $null=Add-TransferFile $manifest (Join-Path $Context.Root '.harness/projetos/indice-projetos.md') 'INDEX' -Optional
    Write-TransferArchive $manifest $PackagePath
}
