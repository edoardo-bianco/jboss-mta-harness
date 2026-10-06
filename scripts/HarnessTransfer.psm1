#requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'Harness.psm1') -DisableNameChecking
Import-Module (Join-Path $PSScriptRoot 'HarnessPlanning.psm1') -DisableNameChecking
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
. (Join-Path $PSScriptRoot 'HarnessTransferArchive.ps1')
. (Join-Path $PSScriptRoot 'HarnessTransferExport.ps1')
. (Join-Path $PSScriptRoot 'HarnessPrioritizationState.ps1')
. (Join-Path $PSScriptRoot 'HarnessPrioritizationEvidence.ps1')
. (Join-Path $PSScriptRoot 'HarnessTransferAnalysis.ps1')
. (Join-Path $PSScriptRoot 'HarnessTransferMapping.ps1')
. (Join-Path $PSScriptRoot 'HarnessTransferValidation.ps1')
. (Join-Path $PSScriptRoot 'HarnessTransferPlanning.ps1')
. (Join-Path $PSScriptRoot 'HarnessTransferImport.ps1')
function Get-HarnessTransferContexts {
    param($Context)
    foreach ($project in $Context.Projects) {
        foreach ($record in @(Get-MtaPlanningHistory ([pscustomobject]@{Root=$Context.Root;Active=$project}))) {
            if ($record.PSObject.Properties['LayoutVersion'] -and $record.LayoutVersion -eq 2) {
                [pscustomobject]@{Kind='PLANEJAMENTO';Label=($project.label+' / '+$record.IssueId);RequestId=$record.RequestId;ContextPath=$record.ContextPath}
            }
        }
    }
    foreach ($record in @(Read-PrioritizationHistory $Context.Root)) {
        if ($record.SchemaVersion -ne 4) { continue }
        if (-not (Test-Path -LiteralPath $record.RankingPath)) { continue }
        try { $null=Read-PrioritizationResult $record }
        catch { Write-Warning ("$($record.RequestId): " + $_.Exception.Message); continue }
        [pscustomobject]@{Kind='ANALISE';Label=($record.Category+' / '+$record.Percentage+'% / '+$record.PreparedAtUtc);RequestId=$record.RequestId;ContextPath=$record.ContextPath}
    }
}
Export-ModuleMember -Function Read-HarnessContextPackage, Export-HarnessContextPackage, Import-HarnessContextPackage, Get-HarnessTransferContexts
