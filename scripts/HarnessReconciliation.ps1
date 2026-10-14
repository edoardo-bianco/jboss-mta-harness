# Area de revisao e descartavel. Contexto corrente nunca guarda copias de entradas.
function Get-ReconciliationReviewFolder {
    param($Project)
    Resolve-ProjectPath (Join-Path $Project.TemporaryPath 'reconciliacao') $Project.Root
}
function Remove-ReconciliationReview {
    param($Project,[Collections.IDictionary]$Expected)
    $folder=Get-ReconciliationReviewFolder $Project
    if (-not $folder.StartsWith($Project.Folder+'\temporarios\',[StringComparison]::OrdinalIgnoreCase)) { throw 'Area transitoria fora do projeto.' }
    if (-not (Test-Path -LiteralPath $folder)) { return }
    if ($Expected -and -not (Test-ReconciliationDraftUnchanged $folder $Expected)) { return $false }
    $pending=New-Object 'Collections.Generic.Stack[string]'; $pending.Push($folder)
    while ($pending.Count) {
        foreach ($item in Get-ChildItem -LiteralPath $pending.Pop() -Force) {
            if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Link/junction na revisao; preserve e confira.' }
            if ($item.PSIsContainer) { $pending.Push($item.FullName) }
        }
    }
    [IO.Directory]::Delete($folder,$true)
    $true
}
function Get-ReconciliationDraft {
    param([string]$Folder)
    $draft=@{}
    foreach ($relative in @(Get-ReconciliationFiles $Folder -AllFiles)) { $draft[$relative]=[IO.File]::ReadAllBytes((Join-Path $Folder $relative)) }
    $draft
}
function Test-ReconciliationDraftUnchanged {
    param([string]$Folder,[Collections.IDictionary]$Expected)
    $actual=Get-ReconciliationDraft $Folder
    if ($actual.Count -ne $Expected.Count) { return $false }
    foreach ($key in $Expected.Keys) {
        if (-not $actual.ContainsKey($key) -or [Convert]::ToBase64String($actual[$key]) -cne [Convert]::ToBase64String($Expected[$key])) { return $false }
    }
    $true
}
function Start-HarnessReconciliationReview {
    param($Project,[string]$ReceivedPath,[ValidateSet('MTA','EVIDENCIAS')][string]$PlanningBasis='MTA',[switch]$Restart)
    $access=Enter-ReconciliationAccess $Project $ReceivedPath
    try {
        $folder=Get-ReconciliationReviewFolder $Project
        if ($Restart) { $null=Remove-ReconciliationReview $Project }
        $basePath=Join-Path $folder 'base.clixml'
        if (Test-Path -LiteralPath $basePath) {
            $base=Import-Clixml -LiteralPath $basePath
            $origin=if ($ReceivedPath) { Resolve-ProjectPath $ReceivedPath $Project.Root } else { $null }
            if ($base.Project -cne $Project.Name -or $base.Pom -ine $Project.Pom -or $base.ReceivedPath -ine $origin -or $base.PlanningBasis -cne $PlanningBasis) { throw 'Ha revisao temporaria de outro recorte. Preserve a proposta e reinicie explicitamente se necessario.' }
            return [pscustomobject]@{Folder=$folder;ProposalPath=(Join-Path $folder 'proposta');Reused=$true;Documents=@($base.Documents)}
        }
        if (Test-Path -LiteralPath $folder) { throw 'Revisao temporaria incompleta; preserve e reinicie explicitamente.' }
        $comparison=Get-HarnessReconciliationComparison $Project $ReceivedPath $PlanningBasis -Access $access
        $null=[IO.Directory]::CreateDirectory((Join-Path $folder 'proposta'))
        $base=[pscustomobject]@{Project=$Project.Name;Pom=$Project.Pom;ReceivedPath=$comparison.ReceivedPath;PlanningBasis=$PlanningBasis;
            Local=$comparison.Local;Received=$comparison.Received;Documents=$comparison.Documents;MtaStamp=$comparison.MtaStamp;PartnerFiles=$comparison.PartnerFiles}
        $base | Export-Clixml -LiteralPath $basePath -Depth 20 -Encoding UTF8
        [pscustomobject]@{Folder=$folder;ProposalPath=(Join-Path $folder 'proposta');Reused=$false;Documents=$comparison.Documents}
    } finally { Exit-ReconciliationAccess $access }
}
function Assert-ReconciliationReviewUnchanged {
    param($Base,$Comparison)
    if ($Base.Project -cne $Comparison.Project.Name -or $Base.Pom -ine $Comparison.Project.Pom) { throw 'Revisao nao corresponde ao POM local.' }
    foreach ($field in @('Local','Received','PartnerFiles')) {
        $expected=if ($Base.PSObject.Properties[$field]) {$Base.$field} else {@{}}
        $current=$Comparison.$field
        if (@($expected.Keys).Count -ne @($current.Keys).Count) { throw "Conjunto $field alterado durante a revisao; confira e reinicie explicitamente." }
        foreach ($path in $expected.Keys) {
            if (-not $current.Contains($path)) { throw "Documento alterado durante a revisao: $path" }
            $left=if ($null -eq $expected[$path]) {$null} else {[Convert]::ToBase64String([byte[]]$expected[$path])}
            $right=if ($null -eq $current[$path]) {$null} else {[Convert]::ToBase64String([byte[]]$current[$path])}
            if ($left -cne $right) { throw "Documento alterado durante a revisao: $path. Confira e reinicie explicitamente." }
        }
    }
    if (($null -eq $Base.MtaStamp) -ne ($null -eq $Comparison.MtaStamp)) { throw 'Base MTA mudou durante a revisao.' }
    if ($Base.MtaStamp) {
        foreach ($field in @('ReportPath','CatalogPath','Report','Catalog')) {
            if ($Base.MtaStamp[$field] -cne $Comparison.MtaStamp[$field]) { throw 'MTA mudou durante a revisao; confira e reinicie explicitamente.' }
        }
    }
}
