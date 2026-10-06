function Import-HarnessContextPackage {
    [CmdletBinding()]
    param($Context,[Parameter(Mandatory=$true)][string]$PackagePath,[Parameter(Mandatory=$true)][Collections.IDictionary]$SourceMap,[switch]$Preview)
    $manifest=Read-HarnessContextPackage $PackagePath
    $packageHash=(Get-FileHash -LiteralPath $PackagePath -Algorithm SHA256).Hash
    $base=Join-Path $Context.Root ('.harness/importacoes/'+$manifest.PackageId)
    $marker=Join-Path $base 'import.json'
    $projects=@{}; $paths=@{}; $canonicalMap=[ordered]@{}
    foreach ($origin in $manifest.Projects) {
        $keys=@($SourceMap.Keys | Where-Object { ([string]$_).Replace('\','/').TrimEnd('/') -ieq $origin.Source.Replace('\','/').TrimEnd('/') })
        if ($keys.Count -ne 1) { throw "Informe Source local explicito para $($origin.Source)." }
        $target=Resolve-HarnessPath $SourceMap[$keys[0]] $Context.Root
        $matches=@($Context.Projects | Where-Object { (Resolve-HarnessPath $_.path $Context.Root) -ieq $target })
        if ($matches.Count -ne 1 -or $canonicalMap.Values -icontains $target) { throw 'Mapeamento exige projetos locais distintos e unicos no workspace.' }
        Assert-TransferRegularPath $target
        $projects[$origin.Source]=$matches[0]; $canonicalMap[$origin.Source]=$target; $paths[$origin.Source]=$target
        $local=Get-HarnessMigrationPaths $Context.Root $matches[0]
        $file=@($manifest.Files | Where-Object Entry -CEQ $origin.RegisterEntry)
        if ($file.Count -ne 1) { throw 'Registro do projeto ausente do inventario.' }
        $paths[$file[0].OriginPath]=$local.MigrationPath
    }
    if ($SourceMap.Count -ne $canonicalMap.Count) { throw 'Mapeamento contem Sources fora do pacote.' }
    $mapJson=ConvertTo-Json $canonicalMap -Compress
    if (Test-Path -LiteralPath $marker) {
        Assert-TransferRegularPath $marker
        $prior=Get-Content -LiteralPath $marker -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($prior.PackageSha256 -ine $packageHash -or $prior.SourceMapJson -cne $mapJson) { throw 'PackageId ja importado com outro conteudo ou mapeamento.' }
        foreach ($file in $manifest.Files) {
            $raw=Join-Path $base ('original/'+$file.Entry)
            Assert-TransferRegularPath $raw
            if ((Get-FileHash -LiteralPath $raw).Hash -ine $file.Sha256) { throw 'Original recebido ausente/alterado; nao reparar por sobrescrita.' }
        }
        if (-not (Test-Path -LiteralPath $prior.ContextPath)) { throw 'Importacao local incompleta; confira o recibo antes de repetir.' }
        return [pscustomobject]@{Status='IMPORTED';Reused=$true;ContextPath=$prior.ContextPath;OriginalContextPath=$prior.OriginalContextPath;PackageId=$manifest.PackageId}
    }
    if (Test-Path -LiteralPath $base) { throw 'Importacao anterior incompleta. Confira a pasta recebida antes de repetir.' }
    $archive=[IO.Compression.ZipFile]::OpenRead((Resolve-HarnessPath $PackagePath $Context.Root))
    try {
        $records=@(); $knownRequests=@{}
        foreach ($project in $Context.Projects) {
            foreach ($known in @(Get-MtaPlanningHistory ([pscustomobject]@{Root=$Context.Root;Active=$project}) -IncludePrepared)) { $knownRequests[$known.RequestId]=$true }
        }
        foreach ($known in @(Read-PrioritizationHistory $Context.Root)) { $knownRequests[$known.RequestId]=$true }
        foreach ($ref in $manifest.Receipts) {
            $record=Read-TransferText $archive $ref.Entry | ConvertFrom-Json
            if ($knownRequests.ContainsKey($record.RequestId)) { throw 'RequestId ja existe no workspace; concilie sem duplicar a solicitacao.' }
            $knownRequests[$record.RequestId]=$true
            if ($manifest.Kind -eq 'ANALISE') {
                $records += New-TransferAnalysisMapping $Context $record $ref $projects $paths
                continue
            }
            if ($record.RequestId -cnotmatch '^[a-f0-9]{32}$' -or $record.RequestId -cne $ref.RequestId -or -not $projects.ContainsKey($record.Source)) { throw 'Identidade do recibo recebido invalida.' }
            if ($record.Purpose -ne 'application-remediation' -or $record.LayoutVersion -ne 2 -or $record.EvidenceMode -ne 'CONSOLIDATED') { throw 'Recibo recebido nao e plano consolidado por issue.' }
            $issue=Get-HarnessIssuePaths $Context.Root $projects[$record.Source] $record.IssueId
            $folder=Join-Path $issue.Folder ('p_'+$record.RequestId.Substring(0,12))
            $paths[(Split-Path $record.ContextPath -Parent)]=$folder
            foreach ($pair in @(@('ContextPath','contexto-','.json'),@('PlanPath','plan-','.md'),@('TodoPath','todo-','.md'),@('FichaPath','ficha-','.md'))) { $paths[$record.($pair[0])]=Join-Path $folder ($pair[1]+$issue.Stem+$pair[2]) }
            $records += [pscustomobject]@{Record=$record;Entry=$ref.Entry;IssuePaths=$issue;Folder=$folder}
        }
        Assert-TransferPackageSemantics $manifest $archive $records
        if ($manifest.Kind -eq 'ANALISE') {
            foreach ($run in $manifest.MtaRuns) { $paths[$run.OriginPath]=Join-Path $base ('mta/'+(Get-HarnessProjectKey $run.OriginPath).Substring(0,12)) }
            foreach ($origin in $manifest.Projects) {
                $paths[$origin.EvidenceIndexOrigin]=(Get-HarnessMigrationPaths $Context.Root $projects[$origin.Source]).EvidenceIndexPath
            }
            foreach ($file in @($manifest.Files | Where-Object Role -eq 'ANNEX')) {
                $paths[$file.OriginPath]=Join-Path $base ('anexos/'+(Get-HarnessProjectKey $file.OriginPath)+'/'+[IO.Path]::GetFileName($file.OriginPath))
            }
        }
        $mapping=New-TransferMapping $paths
        $writes=@{}
        foreach ($file in $manifest.Files) { Add-TransferWrite $writes (Join-Path $base ('original/'+$file.Entry)) $null $file.Entry }
        $rootRecord=@($records | Where-Object Entry -CEQ $manifest.ContextEntry)
        if ($rootRecord.Count -ne 1) { throw 'Contexto principal ausente/ambiguo.' }
        if ($manifest.Kind -eq 'ANALISE') { New-TransferAnalysisWrites $Context $manifest $archive $base $records $mapping $writes $projects }
        else { New-TransferPlanningWrites $Context $manifest $archive $base $records $rootRecord[0] $mapping $writes $projects }
        $contextPath=Convert-TransferText $rootRecord[0].Record.ContextPath $mapping
        $result=[ordered]@{PackageId=$manifest.PackageId;PackageSha256=$packageHash;SourceMapJson=$mapJson;ContextPath=$contextPath;OriginalContextPath=(Join-Path $base ('original/'+$manifest.ContextEntry));ImportedAtUtc=[DateTime]::UtcNow.ToString('o')}
        Add-TransferWrite $writes $marker (Get-TransferBytes ($result | ConvertTo-Json -Depth 10)) $null
        Add-TransferWrite $writes (Join-Path $base 'original/manifest.json') $null 'manifest.json'
        $directories=@(if ($manifest.Kind -eq 'ANALISE') {
            foreach ($run in $manifest.MtaRuns) {
                $runPath=Convert-TransferText $run.OriginPath $mapping
                foreach ($dir in @('input','rules','output')) { Join-Path $runPath $dir }
            }
        })
        foreach ($write in $writes.Values) {
            if (Test-Path -LiteralPath $write.Path) { throw "Conflito local; nada sera sobrescrito: $($write.Path)" }
            $parent=Split-Path $write.Path -Parent
            while (-not (Test-Path -LiteralPath $parent)) { $parent=Split-Path $parent -Parent }
            Assert-TransferRegularPath $parent
            if (-not ([IO.Path]::GetFullPath($write.Path)).StartsWith(([IO.Path]::GetFullPath((Join-Path $Context.Root '.harness'))+'\'),[StringComparison]::OrdinalIgnoreCase)) { throw 'Destino fora da .harness.' }
        }
        if ($Preview) { return [pscustomobject]@{Status='READY';PackageId=$manifest.PackageId;Kind=$manifest.Kind;SourceMap=$canonicalMap;Files=$writes.Count;Missing=$manifest.Missing;ContextPath=$contextPath} }
        Write-TransferImport $Context $manifest $archive $base $writes $directories $marker {
            if ($manifest.Kind -eq 'ANALISE') {
                $history=@(Read-PrioritizationHistory $Context.Root)
                foreach ($item in $records) {
                    $receipt=@($history | Where-Object RequestId -CEQ $item.Record.RequestId)[0]
                    $null=Get-PrioritizationExcludedIssues $receipt $history
                }
            } else {
                foreach ($item in $records) { Assert-HarnessPlanningEvidence $item.Local $Context.Root -Historical }
            }
        }
        Import-Module (Join-Path $PSScriptRoot 'HarnessProjectIndex.psm1') -DisableNameChecking
        $indexContext=$Context
        if (-not $Context.Config) {
            $indexContext=[pscustomobject]@{Root=$Context.Root;Projects=$Context.Projects;Active=$Context.Active;Config=[pscustomobject]@{mta=[pscustomobject]@{runsPath=$null}};ConfigPath=$Context.ConfigPath;WorkspacePath=$Context.WorkspacePath}
        }
        $indexStatus='UPDATED'
        try { $null=New-HarnessProjectIndex $indexContext }
        catch { $indexStatus='PENDING'; Write-Warning ('Pacote importado; atualizar indice dos projetos ficou pendente: '+$_.Exception.Message) }
        [pscustomobject]@{Status='IMPORTED';Reused=$false;ContextPath=$result.ContextPath;OriginalContextPath=$result.OriginalContextPath;PackageId=$manifest.PackageId;IndexStatus=$indexStatus}
    } finally { $archive.Dispose() }
}
