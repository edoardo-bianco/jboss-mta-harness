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

function Read-QueryFile {
    param([string]$Path,$Files,[string]$ExpectedHash)
    if ($Path -notmatch '^[A-Za-z]:[\\/]') { Stop-QueryError INVALID_CONTEXT 'Arquivo exige caminho local absoluto; UNC/rede nao sao aceitos.' }
    $Path=[IO.Path]::GetFullPath($Path)
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
    $json=ConvertTo-Json -InputObject $entries -Compress
    $sha=[Security.Cryptography.SHA256]::Create()
    try { ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($json)))).Replace('-','') }
    finally { $sha.Dispose() }
}

function Assert-QueryOrigin {
    param($Observed,$Expected)
    foreach ($field in @('RunId','Project','Source')) {
        $left=[string](Get-QueryProperty $Observed $field); $right=[string](Get-QueryProperty $Expected $field)
        if (-not $left -or -not $right) { Stop-QueryError IDENTITY_CONFLICT 'Identidade MTA incompleta.' }
        $equal=if ($field -eq 'Source') {$left.Replace('\','/').TrimEnd('/') -ieq $right.Replace('\','/').TrimEnd('/')} else {$left -ceq $right}
        if (-not $equal) { Stop-QueryError IDENTITY_CONFLICT ("Origem MTA divergente: $field.") }
    }
}

function Read-QueryBase {
    param([string]$Root,[string]$ContextPath,[string]$Source)
    if (-not $ContextPath) { Stop-QueryError INVALID_INPUT 'Informe ContextPath.' }
    $files=@{}; $diagnostics=@()
    $path=Resolve-HarnessPath $ContextPath $Root
    $receipt=Read-QueryFile $path $files | ConvertFrom-Json
    if ($receipt.RequestId -cnotmatch '^[a-f0-9]{32}$' -or (Resolve-HarnessPath $receipt.ContextPath $Root) -ine $path) { Stop-QueryError IDENTITY_CONFLICT 'ContextPath/RequestId divergente.' }
    $planning=$receipt.Purpose -eq 'application-remediation'
    if (-not $planning -and ($receipt.Purpose -ne 'issue-prioritization' -or $receipt.SchemaVersion -notin @(2,3,4))) { Stop-QueryError UNSUPPORTED_CONTEXT 'Tipo/versao de contexto nao suportado.' }
    $basis=if ($planning) {Get-QueryProperty $receipt 'PlanningBasis' 'MTA'} else {'MTA'}
    $mode=if ($planning) {Get-QueryProperty $receipt 'EvidenceMode' 'ORIGINAL'} else {'ORIGINAL'}
    if ($basis -notin @('MTA','EVIDENCIAS') -or $mode -notin @('ORIGINAL','CONSOLIDATED')) { Stop-QueryError INVALID_CONTEXT 'Base/modo de evidencia invalido.' }
    $projects=@(if ($planning) {$receipt} else {$receipt.Projects})
    if (-not $Source -and $projects.Count -ne 1) { Stop-QueryError INPUT_REQUIRED 'Informe Source de um projeto do contexto.' }
    $projects=@($projects | Where-Object { -not $Source -or (Resolve-HarnessPath $_.Source $Root) -ieq (Resolve-HarnessPath $Source $Root) })
    if ($projects.Count -ne 1) { Stop-QueryError IDENTITY_CONFLICT 'Source ausente/duplicado no contexto.' }
    $selected=$projects[0]
    $mta=if ($basis -ne 'MTA') {$null} elseif ($planning) {$receipt} else {$selected.Mta}
    $project=[pscustomobject]@{Project=$selected.Project;Source=(Resolve-HarnessPath $selected.Source $Root);MigrationPath=$selected.MigrationPath;MigrationSha256=$selected.MigrationSha256;Mta=$mta}
    $null=Read-QueryFile $project.MigrationPath $files
    $register=Read-HarnessMigrationInput $Root ([pscustomobject]@{name=$project.Project;path=$project.Source}) $project.MigrationPath
    if ($basis -eq 'MTA') {
        if (-not $mta -or -not $register.Origin -or $register.Origin.RunId -cne $mta.RunId) { Stop-QueryError IDENTITY_CONFLICT 'Origem MTA do registro diverge do contexto.' }
        Assert-QueryOrigin $register.Origin $mta.MtaOrigin
        $originHash=Get-QueryProperty $register.Origin 'CatalogSha256'
        if ($originHash -and $originHash -ine $mta.CatalogSha256) { Stop-QueryError IDENTITY_CONFLICT 'Catalogo do registro diverge da origem declarada.' }
    } elseif ($register.Origin -or (Get-QueryProperty $receipt 'RunId') -or (Get-QueryProperty $receipt 'MtaOrigin')) { Stop-QueryError IDENTITY_CONFLICT 'Base EVIDENCIAS conflita com origem MTA.' }
    if ($files[(Resolve-HarnessPath $project.MigrationPath $Root)] -cne $project.MigrationSha256) { $diagnostics+='REGISTER_CHANGED: escolhas atuais foram lidas; snapshot permanece historico.' }
    $items=@(if ($mode -eq 'CONSOLIDATED') { Read-QueryConsolidated $receipt $Root $files $basis }
        elseif ($basis -eq 'MTA') { Read-QueryOriginalMta $mta $Root $files })
    if ($planning -and $mode -eq 'ORIGINAL') {
        foreach ($input in @(Get-QueryProperty $receipt 'EvidenceInputs' @())) {
            if ($input.Status -eq 'DISPONIVEL') {
                if ($input.Sha256 -notmatch '^[A-Fa-f0-9]{64}$') { Stop-QueryError INVALID_CONTEXT 'Hash obrigatorio da evidencia humana ausente/invalido.' }
                $null=Read-QueryFile $input.Path $files $input.Sha256
            }
            else { $diagnostics+=('EVIDENCE_UNAVAILABLE: '+$input.Path) }
        }
    }
    $selectedIds=$null
    if ($planning) {
        $selectedIds=@($receipt.SelectedIssues | ForEach-Object Id)
        if (-not $selectedIds.Count -or @($selectedIds | Select-Object -Unique).Count -ne $selectedIds.Count) { Stop-QueryError INVALID_CONTEXT 'Selecao de issues vazia/duplicada.' }
        $items=@($items | Where-Object { $_.Id -cin $selectedIds })
    }
    if (Get-QueryProperty $receipt 'ProjectIndexPath') {
        try {
            $null=Read-QueryFile $receipt.ProjectIndexPath $files
            $indexHash=Get-QueryProperty $receipt 'ProjectIndexSha256'
            if ($indexHash -and $files[(Resolve-HarnessPath $receipt.ProjectIndexPath $Root)] -ine $indexHash) { $diagnostics+='INDEX_CHANGED: indice nao substitui escolhas atuais.' }
        } catch { $diagnostics+=('INDEX_UNAVAILABLE: '+(Get-QueryError $_).Code) }
    }
    $provenance=[ordered]@{ContextPath=$path;ContextSha256=$files[$path];RequestId=$receipt.RequestId;Source=$project.Source;Project=$project.Project;PlanningBasis=$basis;EvidenceMode=$mode;RunId=(Get-QueryProperty $mta 'RunId');MtaOrigin=(Get-QueryProperty $mta 'MtaOrigin');CatalogPath=(Get-QueryProperty $mta 'CatalogPath');CatalogSha256=(Get-QueryProperty $mta 'CatalogSha256');ConsolidatedPath=if ($mode -eq 'CONSOLIDATED') {$receipt.Consolidated.MtaIssuePath} else {$null};RegisterPath=$project.MigrationPath;RegisterSha256=$files[(Resolve-HarnessPath $project.MigrationPath $Root)]}
    $itemsById=[Collections.Generic.Dictionary[string,object]]::new([StringComparer]::Ordinal)
    foreach ($item in $items) { $itemsById.Add($item.Id,$item) }
    $rowsById=[Collections.Generic.Dictionary[string,object]]::new([StringComparer]::Ordinal)
    foreach ($row in $register.Rows) { $rowsById.Add($row.Id,$row) }
    $availability=[Collections.Generic.Dictionary[string,string]]::new([StringComparer]::Ordinal)
    if (-not $planning) {
        foreach ($entry in $receipt.AvailableIssues) { if ($entry.Source -ieq $project.Source) { $availability[$entry.Id]='AVAILABLE' } }
        foreach ($entry in $receipt.ExcludedIssues) { if ($entry.Source -ieq $project.Source) { $availability[$entry.Id]='EXCLUDED_PREVIOUS' } }
    }
    [pscustomobject]@{Receipt=$receipt;Project=$project;Mta=$mta;Items=$items;ItemsById=$itemsById;RowsById=$rowsById;AvailabilityById=$availability;Register=$register;Provenance=$provenance;Files=$files;Diagnostics=$diagnostics;IsPlanning=$planning;SelectedIds=$selectedIds}
}
