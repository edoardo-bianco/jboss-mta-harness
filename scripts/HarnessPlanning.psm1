Import-Module (Join-Path $PSScriptRoot 'HarnessDocumentTemplates.psm1') -DisableNameChecking
#requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'Harness.psm1') -DisableNameChecking
Import-Module (Join-Path $PSScriptRoot 'HarnessProject.psm1') -DisableNameChecking
. (Join-Path $PSScriptRoot 'HarnessIssuePlanning.ps1')
. (Join-Path $PSScriptRoot 'HarnessPlanningCurrent.ps1')
. (Join-Path $PSScriptRoot 'HarnessPrioritizationState.ps1')
. (Join-Path $PSScriptRoot 'HarnessPrioritizationIndex.ps1')
. (Join-Path $PSScriptRoot 'HarnessImplementationPrompt.ps1')
. (Join-Path $PSScriptRoot 'HarnessReconciliationInput.ps1')
. (Join-Path $PSScriptRoot 'HarnessReconciliationAccess.ps1')
. (Join-Path $PSScriptRoot 'HarnessReconciliationPrioritization.ps1')
. (Join-Path $PSScriptRoot 'HarnessReconciliationReferences.ps1')
. (Join-Path $PSScriptRoot 'HarnessReconciliation.ps1')
. (Join-Path $PSScriptRoot 'HarnessReconciliationPublish.ps1')
. (Join-Path $PSScriptRoot 'HarnessReconciliationContext.ps1')
Export-ModuleMember -Function Get-HarnessReconciliationComparison
Export-ModuleMember -Function Start-HarnessReconciliationReview
Export-ModuleMember -Function Complete-HarnessReconciliation
Export-ModuleMember -Function New-HarnessReconciliationContext
Export-ModuleMember -Function New-HarnessCurrentPlanning,Get-HarnessCurrentPlanning
Export-ModuleMember -Function New-HarnessImplementationPrompt
Export-ModuleMember -Function Get-CurrentPlanningEvidence
Export-ModuleMember -Function Assert-CurrentPlanningContext,Get-CurrentPlanningSources

function Assert-HarnessPlanningEvidence {
    param($Data,[string]$Root)
    if (-not $Data.PSObject.Properties['Purpose'] -or $Data.Purpose -cne 'current-planning') { throw 'Use contexto corrente; dados legados exigem conversao explicita.' }
    Assert-IssuePlanningEvidence $Data $Root
}
Export-ModuleMember -Function Assert-HarnessPlanningEvidence
