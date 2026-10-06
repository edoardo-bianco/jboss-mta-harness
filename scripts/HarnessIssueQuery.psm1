#requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$script:QueryAllowedRoots=$null
Import-Module (Join-Path $PSScriptRoot 'Harness.psm1') -DisableNameChecking
Import-Module (Join-Path $PSScriptRoot 'HarnessPlanning.psm1') -DisableNameChecking
. (Join-Path $PSScriptRoot 'HarnessPrioritizationEvidence.ps1')
. (Join-Path $PSScriptRoot 'HarnessIssueQueryInput.ps1')
. (Join-Path $PSScriptRoot 'HarnessIssueQueryPlanning.ps1')
. (Join-Path $PSScriptRoot 'HarnessIssueQueryView.ps1')

function Invoke-HarnessIssueQuery {
    [CmdletBinding()]
    param([string]$Action, [string]$ContextPath, [string]$Source,
        $Page=1,$PageSize=10,$MaxTextChars=1024,
        [string]$Category,[string]$Decision,[string]$Progress,[string]$Text,[string]$Label,
        [string]$Id,$Incident=$null,[string]$ExpectedBasisSha256,
        [string]$Root=(Split-Path -Parent $PSScriptRoot),[string[]]$AllowedRoots)
    $response=[ordered]@{SchemaVersion=1;Action=$Action;Status='ERROR';ReadOnly=$true;Provenance=$null;Data=$null;Paging=$null;Diagnostics=@();Error=$null}
    try {
        $script:QueryAllowedRoots=$null
        if ($PSBoundParameters.ContainsKey('AllowedRoots')) {
            if (-not $AllowedRoots.Count) { Stop-QueryError INVALID_INPUT 'AllowedRoots exige ao menos uma raiz local.' }
            $script:QueryAllowedRoots=@(foreach ($allowed in $AllowedRoots) {
                if ($allowed -notmatch '^[A-Za-z]:[\\/]') { Stop-QueryError INVALID_INPUT 'AllowedRoots exige caminhos locais absolutos.' }
                Resolve-HarnessPath $allowed $allowed
            })
        }
        $Root=Resolve-QueryPath $Root $Root
        if ($Action -notin @('auditar_base','listar_issues','obter_issue')) { Stop-QueryError INVALID_INPUT 'Operacao desconhecida.' }
        foreach ($filter in @('Category','Decision','Progress','Text','Label')) {
            if ($Action -ne 'listar_issues' -and $PSBoundParameters.ContainsKey($filter)) { Stop-QueryError INVALID_INPUT ("$filter exige listar_issues.") }
        }
        if ($Action -ne 'obter_issue' -and $PSBoundParameters.ContainsKey('Id')) { Stop-QueryError INVALID_INPUT 'Id exige obter_issue.' }
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
            $audit=Get-QueryAudit $base $Page $PageSize
            $response.Data=$audit.Data; $response.Paging=$audit.Paging
        }
        Assert-QueryFiles $base.Files
        $response.Status='OK'
    } catch { $response.Error=Get-QueryError $_; $response.Data=$null; $response.Paging=$null }
    finally { $script:QueryAllowedRoots=$null }
    # Identificadores/caminhos nao podem ser cortados silenciosamente. O teto
    # cobre tambem diagnosticos, mensagens de erro e extensoes livres do recibo.
    if ([Text.Encoding]::UTF8.GetByteCount((ConvertTo-Json -InputObject $response -Depth 50 -Compress)) -gt 256KB) {
        $response=[ordered]@{SchemaVersion=1;Action=if ($Action -in @('auditar_base','listar_issues','obter_issue')) {$Action} else {$null};Status='ERROR';ReadOnly=$true;Provenance=$null;Data=$null;Paging=$null;Diagnostics=@();Error=[ordered]@{Code='LIMIT_EXCEEDED';Message='Resposta excede 256 KiB; reduza PageSize/MaxTextChars ou confira campos extensos no contexto.'}}
    }
    [pscustomobject]$response
}
Export-ModuleMember -Function Invoke-HarnessIssueQuery
