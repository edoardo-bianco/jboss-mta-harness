#requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'Harness.psm1') -DisableNameChecking
Import-Module (Join-Path $PSScriptRoot 'HarnessPlanning.psm1') -DisableNameChecking
. (Join-Path $PSScriptRoot 'HarnessPrioritizationEvidence.ps1')
. (Join-Path $PSScriptRoot 'HarnessIssueQueryInput.ps1')
. (Join-Path $PSScriptRoot 'HarnessIssueQueryView.ps1')

function Invoke-HarnessIssueQuery {
    [CmdletBinding()]
    param([string]$Action, [string]$ContextPath, [string]$Source,
        $Page=1,$PageSize=10,$MaxTextChars=1024,
        [string]$Category,[string]$Decision,[string]$Progress,[string]$Text,[string]$Label,
        [string]$Id,$Incident=$null,[string]$ExpectedBasisSha256,
        [string]$Root=(Split-Path -Parent $PSScriptRoot))
    $response=[ordered]@{SchemaVersion=1;Action=$Action;Status='ERROR';ReadOnly=$true;Provenance=$null;Data=$null;Paging=$null;Diagnostics=@();Error=$null}
    try {
        if ($Action -notin @('auditar_base','listar_issues','obter_issue')) { Stop-QueryError INVALID_INPUT 'Operacao desconhecida.' }
        $Page=ConvertTo-QueryNumber $Page 'Page' 1 ([int]::MaxValue)
        $maximum=if ($Action -eq 'obter_issue') {10} else {50}
        $PageSize=ConvertTo-QueryNumber $PageSize 'PageSize' 1 $maximum
        $MaxTextChars=ConvertTo-QueryNumber $MaxTextChars 'MaxTextChars' 128 8192
        if ($Action -eq 'obter_issue' -and -not $Id) { Stop-QueryError INVALID_INPUT 'Informe Id exato da issue.' }
        if ($null -ne $Incident) {
            if ($Action -ne 'obter_issue' -or $PSBoundParameters.ContainsKey('Page') -or $PSBoundParameters.ContainsKey('PageSize')) { Stop-QueryError INVALID_INPUT 'Incident exige obter_issue, sem Page/PageSize.' }
            $Incident=ConvertTo-QueryNumber $Incident 'Incident' 1 ([int]::MaxValue)
        }
        if ($ExpectedBasisSha256 -and $ExpectedBasisSha256 -notmatch '^[A-Fa-f0-9]{64}$') { Stop-QueryError INVALID_INPUT 'ExpectedBasisSha256 invalido.' }
        $base=Read-QueryBase $Root $ContextPath $Source
        $base.Provenance.BasisSha256=Get-QueryBasisHash $base
        if ($ExpectedBasisSha256 -and $ExpectedBasisSha256 -ine $base.Provenance.BasisSha256) { Stop-QueryError BASE_CHANGED 'Base diferente da pagina anterior; consulte novamente desde o inicio.' }
        $response.Provenance=$base.Provenance
        $response.Diagnostics=$base.Diagnostics
        if ($Action -eq 'listar_issues') {
            $list=Get-QueryList $base $Page $PageSize $MaxTextChars $Category $Decision $Progress $Text $Label
            $response.Data=[ordered]@{Items=$list.Items}
            $response.Paging=$list.Paging
        } elseif ($Action -eq 'obter_issue') {
            $detail=Get-QueryDetail $base $Id $Page $PageSize $Incident $MaxTextChars
            $response.Data=$detail.Data; $response.Paging=$detail.Paging
        } else {
        $differences=@(foreach ($issue in $base.Items) {
            $row=@($base.Register.Rows | Where-Object Id -CEQ $issue.Id)
            if ($row.Count -ne 1) { [pscustomobject]@{Id=$issue.Id;Reason='ISSUE_NOT_IN_REGISTER'}; continue }
            if ($row[0].Category -cne $issue.Category -or [string]$row[0].Count -cne [string]$issue.Count -or $row[0].Presence -ne 'PRESENTE') {
                [pscustomobject]@{Id=$issue.Id;Reason='CATALOG_REGISTER_DIFFERENCE'}
            }
        })
        $response.Data=[ordered]@{CatalogIssues=$base.Items.Count;CatalogIncidents=($base.Items | Measure-Object Count -Sum).Sum;RegisterIssues=@($base.Register.Rows).Count;Differences=$differences;CodeApplicability='NOT_CHECKED';IndexComparison='HASH_ONLY'}
        }
        Assert-QueryFiles $base.Files
        $response.Status='OK'
    } catch { $response.Error=Get-QueryError $_; $response.Data=$null; $response.Paging=$null }
    [pscustomobject]$response
}
Export-ModuleMember -Function Invoke-HarnessIssueQuery
