# Leitores privados. Nao usar configuracao/preparadores: podem inicializar registros.
function Stop-QueryError {
    param([string]$Code,[string]$Message)
    $error=[InvalidOperationException]::new($Message)
    $error.Data['QueryCode']=$Code
    throw $error
}

function Get-QueryError {
    param($Record)
    $code='INVALID_CONTEXT'; $exception=$Record.Exception
    while ($exception) {
        if ($exception.Data.Contains('QueryCode')) { $code=$exception.Data['QueryCode']; break }
        if ($exception -is [UnauthorizedAccessException] -or $exception -is [Security.SecurityException]) { $code='ACCESS_DENIED'; break }
        if ($exception -is [IO.FileNotFoundException] -or $exception -is [IO.DirectoryNotFoundException] -or $exception -is [Management.Automation.ItemNotFoundException]) { $code='NOT_FOUND'; break }
        if ($exception -is [IO.IOException]) { $code='READ_ERROR' }
        $exception=$exception.InnerException
    }
    [pscustomobject]@{Code=$code;Message=$Record.Exception.Message}
}

function Get-QueryProperty {
    param($Value,[string]$Name,$Default=$null)
    if ($null -ne $Value -and $Value.PSObject.Properties[$Name]) { return $Value.$Name }
    $Default
}

function Get-QueryAbsolutePath {
    param([string]$Path,[string]$Root)
    if (-not $Path) { Stop-QueryError INVALID_CONTEXT 'Caminho vazio.' }
    if (-not [IO.Path]::IsPathRooted($Path)) { $Path=[IO.Path]::Combine($Root,$Path) }
    if ($Path -notmatch '^[A-Za-z]:[\\/]' -or $Path.Substring(2).Contains(':')) { Stop-QueryError INVALID_CONTEXT 'Caminho local absoluto esperado; UNC/dispositivo/ADS nao aceitos.' }
    [IO.Path]::GetFullPath($Path).TrimEnd('\','/')
}

function Resolve-QueryPath {
    param([string]$Path,[string]$Root)
    $absolute=Get-QueryAbsolutePath $Path $Root
    if ($null -ne $script:QueryAllowedRoots) {
        $permitted=$false
        foreach ($allowed in $script:QueryAllowedRoots) {
            $prefix=$allowed.TrimEnd('\','/')
            if ($absolute -ieq $prefix -or $absolute.StartsWith($prefix+'\',[StringComparison]::OrdinalIgnoreCase)) { $permitted=$true; break }
        }
        if (-not $permitted) { Stop-QueryError ACCESS_DENIED 'Caminho fora das raizes de leitura configuradas para esta consulta.' }
    }
    Resolve-HarnessPath $absolute $Root
}

function Read-QueryFile {
    param([string]$Path,$Files,[string]$ExpectedHash)
    try {
    if ($Path -notmatch '^[A-Za-z]:[\\/]') { Stop-QueryError INVALID_CONTEXT 'Arquivo exige caminho local absoluto; UNC/rede nao sao aceitos.' }
    $Path=Resolve-QueryPath $Path ([IO.Path]::GetDirectoryName($Path))
    $item=Get-Item -LiteralPath $Path -Force -ErrorAction Stop
    if ($item.PSIsContainer) { Stop-QueryError INVALID_CONTEXT 'Esperado arquivo, recebido diretorio.' }
    for ($parent=$item; $null -ne $parent; $parent=$parent.Parent) {
        if ($parent.Attributes -band [IO.FileAttributes]::ReparsePoint) { Stop-QueryError INVALID_CONTEXT 'Consulta nao segue links/junctions.' }
        if ($parent -is [IO.FileInfo]) { $parent=$parent.Directory; if ($null -eq $parent) { break } }
        if ($parent.Attributes -band [IO.FileAttributes]::ReparsePoint) { Stop-QueryError INVALID_CONTEXT 'Consulta nao segue links/junctions.' }
    }
    if ($item.Length -gt 64MB) { Stop-QueryError LIMIT_EXCEEDED 'Arquivo excede o limite de leitura de 64 MiB.' }
    $hash=(Get-FileHash -LiteralPath $item.FullName -Algorithm SHA256).Hash
    if ($ExpectedHash -and $hash -ine $ExpectedHash) { Stop-QueryError HASH_MISMATCH ("Hash diverge do contexto: $Path") }
    if ($Files.ContainsKey($item.FullName) -and $Files[$item.FullName] -cne $hash) { Stop-QueryError BASE_CHANGED 'Arquivo mudou durante a consulta.' }
    $Files[$item.FullName]=$hash
    [IO.File]::ReadAllText($item.FullName)
    } catch {
        $failure=Get-QueryError $_
        Stop-QueryError $failure.Code $failure.Message
    }
}

function Assert-QueryFiles {
    param($Files)
    foreach ($path in $Files.Keys) {
        if ((Get-FileHash -LiteralPath $path -Algorithm SHA256 -ErrorAction Stop).Hash -cne $Files[$path]) { Stop-QueryError BASE_CHANGED ("Arquivo mudou durante a consulta: $path") }
    }
}

function Get-QueryBasisHash {
    param($Base)
    [string[]]$paths=@($Base.Files.Keys); [Array]::Sort($paths,[StringComparer]::Ordinal)
    $entries=@(foreach ($path in $paths) { [ordered]@{Path=$path;Sha256=$Base.Files[$path]} })
    $selection=if ($Base.Mta) { [ordered]@{ReportPath=$Base.Mta.ReportPath;CatalogPath=$Base.Mta.CatalogPath;DateUtc=$Base.Mta.DateUtc;DateSource=$Base.Mta.DateSource} } else { $null }
    $json=ConvertTo-Json -InputObject ([ordered]@{Files=$entries;Mta=$selection}) -Depth 6 -Compress
    $sha=[Security.Cryptography.SHA256]::Create()
    try { ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($json)))).Replace('-','') }
    finally { $sha.Dispose() }
}

function Read-QueryBase {
    param([string]$Root,[string]$ContextPath,[string]$Source)
    if (-not $ContextPath) { Stop-QueryError INVALID_INPUT 'Informe ContextPath corrente.' }
    $files=@{}; $diagnostics=@()
    $path=Resolve-QueryPath $ContextPath $Root
    $baseFolder=Join-Path $Root '.harness/projetos'
    if (-not $path.StartsWith($baseFolder+'\',[StringComparison]::OrdinalIgnoreCase)) { Stop-QueryError UNSUPPORTED_CONTEXT 'Consulta exige contexto corrente por projeto; converta/reconcilie o legado explicitamente.' }
    $owner=$path.Substring($baseFolder.Length+1).Split('\')[0]
    Enter-QueryProject (Join-Path $baseFolder $owner)
    $receipt=Read-QueryFile $path $files | ConvertFrom-Json
    if ($receipt.Purpose -cnotin @('current-planning','current-prioritization')) { Stop-QueryError UNSUPPORTED_CONTEXT 'Contexto legado ou desconhecido; use documentos correntes.' }
    if ((Resolve-QueryPath $receipt.ContextPath $Root) -ine $path) { Stop-QueryError IDENTITY_CONFLICT 'ContextPath divergente.' }
    $planning=$receipt.Purpose -ceq 'current-planning'
    $projects=@(if ($planning) {$receipt} else {$receipt.Projects})
    if (-not $Source -and $projects.Count -ne 1) { Stop-QueryError INPUT_REQUIRED 'Informe Source de um projeto do contexto.' }
    $projects=@($projects | Where-Object { -not $Source -or (Get-QueryAbsolutePath $_.Source $Root) -ieq (Get-QueryAbsolutePath $Source $Root) })
    if ($projects.Count -ne 1) { Stop-QueryError IDENTITY_CONFLICT 'Source ausente/duplicado no contexto.' }
    $selected=$projects[0]
    $resolved=Read-QueryProject $selected $Root $files
    $reference=$resolved.Project
    if ($planning) {
        $basis=$receipt.PlanningBasis
        if ($basis -cnotin @('MTA','EVIDENCIAS')) { Stop-QueryError INVALID_CONTEXT 'Base de planejamento invalida.' }
        foreach ($field in @('ContextPath','PlanPath','TodoPath','MigrationPath')) {
            if ((Resolve-QueryPath $receipt.$field $Root) -ine $reference.$field) { Stop-QueryError IDENTITY_CONFLICT ("Destino corrente divergente: "+$field) }
        }
    } else {
        $basis='MTA'
        $relative='atual/priorizacao/'+(ConvertTo-HarnessFunctionalPath $receipt.Category)+'/escopos/'+(ConvertTo-HarnessFunctionalPath $receipt.Scope)+'/contexto.json'
        if ($owner -cne $receipt.Projects[0].Project -or $path -ine (Join-Path (Join-Path $baseFolder $owner) $relative)) { Stop-QueryError IDENTITY_CONFLICT 'Escopo/categoria/destino de priorizacao divergente.' }
    }
    $rows=@(Read-ProjectDecisionRows (Read-QueryFile $reference.MigrationPath $files))
    $mta=$null; $items=@()
    if ($basis -eq 'MTA') {
        $mta=Read-QueryCurrentMta $reference $resolved.Configuration $Root $files
        $items=@($mta.Issues); $diagnostics+=@($mta.Diagnostics)
        if (-not $selected.Mta -or $selected.Mta.ReportPath -ine $mta.ReportPath -or $selected.Mta.CatalogPath -ine $mta.CatalogPath) { $diagnostics+='MTA_SOURCE_CHANGED: consulta usa origem atual; reavaliar proposta/cobertura.' }
    }
    $selectedIds=$null
    if ($planning) {
        $selectedIds=@($receipt.SelectedIssues | ForEach-Object Id)
        if (-not $selectedIds.Count -or @($selectedIds | Sort-Object -Unique -CaseSensitive).Count -ne $selectedIds.Count) { Stop-QueryError INVALID_CONTEXT 'Selecao de issues vazia/duplicada.' }
        $items=@($items | Where-Object { $_.Id -cin $selectedIds })
        foreach ($input in @($receipt.EvidenceInputs)+@($receipt.FichaPaths)) {
            if ($input.Status -eq 'REFERENCIA EXTERNA') { continue }
            $inputPath=Resolve-QueryPath $input.Path $Root
            if (Test-Path -LiteralPath $inputPath -PathType Leaf) { $null=Read-QueryFile $inputPath $files }
            else { $diagnostics+=('EVIDENCE_UNAVAILABLE: '+$inputPath) }
        }
        if ($receipt.NeedsReview) { $diagnostics+=@($receipt.ReviewReasons) }
    }
    $project=[pscustomobject]@{Project=$reference.Name;Source=$reference.Source;MigrationPath=$reference.MigrationPath}
    $provenance=[ordered]@{ContextPath=$path;ContextSha256=$files[$path];Source=$project.Source;Project=$project.Project;PlanningBasis=$basis;
        ReportPath=(Get-QueryProperty $mta 'ReportPath');CatalogPath=(Get-QueryProperty $mta 'CatalogPath');
        RegisterPath=$reference.MigrationPath;RegisterSha256=$files[$reference.MigrationPath]}
    $itemsById=[Collections.Generic.Dictionary[string,object]]::new([StringComparer]::Ordinal)
    foreach ($item in $items) { $itemsById.Add($item.Id,$item) }
    $rowsById=[Collections.Generic.Dictionary[string,object]]::new([StringComparer]::Ordinal)
    foreach ($row in $rows) { $rowsById.Add($row.Id,$row) }
    $availability=[Collections.Generic.Dictionary[string,string]]::new([StringComparer]::Ordinal)
    if (-not $planning) {
        foreach ($entry in $receipt.AvailableIssues) { if ($entry.Project -ceq $project.Project) { $availability[$entry.Id]='AVAILABLE' } }
        foreach ($entry in $receipt.ExcludedIssues) { if ($entry.Project -ceq $project.Project) { $availability[$entry.Id]='EXCLUDED_PREVIOUS' } }
    }
    [pscustomobject]@{Receipt=$receipt;Project=$project;Mta=$mta;Items=$items;ItemsById=$itemsById;RowsById=$rowsById;AvailabilityById=$availability;
        Register=[pscustomobject]@{Rows=$rows};Provenance=$provenance;Files=$files;Diagnostics=$diagnostics;IsPlanning=$planning;SelectedIds=$selectedIds}
}
