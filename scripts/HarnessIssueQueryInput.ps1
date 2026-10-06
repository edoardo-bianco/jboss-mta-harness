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
    if (-not $Path -or -not [IO.Path]::IsPathRooted($Path)) { Stop-QueryError INVALID_CONTEXT 'Arquivo exige caminho absoluto no contexto.' }
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
    if ($receipt.Purpose -ne 'issue-prioritization' -or $receipt.SchemaVersion -notin @(2,3,4)) { Stop-QueryError UNSUPPORTED_CONTEXT 'Tipo/versao de contexto nao suportado.' }
    $projects=@($receipt.Projects)
    if (-not $Source -and $projects.Count -ne 1) { Stop-QueryError INPUT_REQUIRED 'Informe Source de um projeto do contexto.' }
    $projects=@($projects | Where-Object { -not $Source -or (Resolve-HarnessPath $_.Source $Root) -ieq (Resolve-HarnessPath $Source $Root) })
    if ($projects.Count -ne 1) { Stop-QueryError IDENTITY_CONFLICT 'Source ausente/duplicado no contexto.' }
    $project=$projects[0]; $mta=$project.Mta
    $null=Read-QueryFile $project.MigrationPath $files
    $register=Read-HarnessMigrationInput $Root ([pscustomobject]@{name=$project.Project;path=$project.Source}) $project.MigrationPath
    if (-not $mta -or -not $register.Origin -or $register.Origin.RunId -cne $mta.RunId) { Stop-QueryError IDENTITY_CONFLICT 'Origem MTA do registro diverge do contexto.' }
    Assert-QueryOrigin $register.Origin $mta.MtaOrigin
    $originHash=Get-QueryProperty $register.Origin 'CatalogSha256'
    if ($originHash -and $originHash -ine $mta.CatalogSha256) { Stop-QueryError IDENTITY_CONFLICT 'Catalogo do registro diverge da origem declarada.' }
    if ($files[(Resolve-HarnessPath $project.MigrationPath $Root)] -cne $project.MigrationSha256) { $diagnostics+='REGISTER_CHANGED: escolhas atuais foram lidas; snapshot permanece historico.' }
    foreach ($pair in @(@('Manifest','manifest.json'),@('Result','result.json'),@('Findings','output/output.yaml'),@('Dependencies','output/dependencies.yaml'))) {
        $artifact=Join-Path $mta.Run $pair[1]
        if ($mta.EvidenceHashes.($pair[0]) -notmatch '^[A-Fa-f0-9]{64}$') { Stop-QueryError INVALID_CONTEXT 'Hash obrigatorio de evidencia MTA ausente/invalido.' }
        $null=Read-QueryFile $artifact $files $mta.EvidenceHashes.($pair[0])
    }
    $run=Get-MtaPlanningRunFromPath $mta.Run $Root
    if ($run.RunId -cne $mta.RunId -or $run.Manifest.Project -cne $mta.MtaOrigin.Project -or $run.Manifest.Source.Replace('\','/') -ine $mta.MtaOrigin.Source.Replace('\','/')) { Stop-QueryError IDENTITY_CONFLICT 'Artefatos nao correspondem a origem do contexto.' }
    $expectedCatalog=Resolve-HarnessPath (Join-Path $mta.Run 'output/static-report/output.js') $Root
    if ((Resolve-HarnessPath $mta.CatalogPath $Root) -ine $expectedCatalog -or $mta.CatalogSha256 -cnotmatch '^[A-Fa-f0-9]{64}$') { Stop-QueryError INVALID_CONTEXT 'Caminho/hash do catalogo invalido.' }
    $null=Read-QueryFile $expectedCatalog $files $mta.CatalogSha256
    try { $items=@(Get-HarnessMtaCatalog $mta.Run $Root -IncludeIncidents) }
    catch { Stop-QueryError UNSUPPORTED_FORMAT $_.Exception.Message }
    if ($receipt.ProjectIndexPath) {
        try {
            $null=Read-QueryFile $receipt.ProjectIndexPath $files
            if ($files[(Resolve-HarnessPath $receipt.ProjectIndexPath $Root)] -cne $receipt.ProjectIndexSha256) { $diagnostics+='INDEX_CHANGED: indice nao substitui escolhas atuais.' }
        } catch { $diagnostics+=('INDEX_UNAVAILABLE: '+(Get-QueryError $_).Code) }
    }
    $provenance=[ordered]@{ContextPath=$path;ContextSha256=$files[$path];RequestId=$receipt.RequestId;Source=$project.Source;Project=$project.Project;PlanningBasis='MTA';EvidenceMode='ORIGINAL';RunId=$mta.RunId;MtaOrigin=$mta.MtaOrigin;CatalogPath=$expectedCatalog;CatalogSha256=$mta.CatalogSha256;RegisterPath=$project.MigrationPath;RegisterSha256=$files[(Resolve-HarnessPath $project.MigrationPath $Root)]}
    [pscustomobject]@{Receipt=$receipt;Project=$project;Mta=$mta;Items=$items;Register=$register;Provenance=$provenance;Files=$files;Diagnostics=$diagnostics}
}
