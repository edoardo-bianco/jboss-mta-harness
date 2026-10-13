. (Join-Path $PSScriptRoot 'PlanningCurrentFixture.ps1')
Import-Module (Join-Path $root 'scripts/HarnessSprintPlanning.psm1') -Force -DisableNameChecking
function New-SprintFixture([string[]]$Names=@('a')) {
    $f=New-PlanningFixture 2 $Names
    foreach ($relative in @('.github/prompts/planejar-sprints.prompt.md','.github/prompts/revisar-sprints.prompt.md','doc/modelos/planejamento-sprints.template.md','doc/features/planejamento-macro-sprints.md','doc/especificacoes/planejamento-sprints.md','doc/guias/tools/planejamento-sprints.md')) {
        $destination=Join-Path $f.Root $relative
        $null=[IO.Directory]::CreateDirectory((Split-Path $destination -Parent))
        Copy-Item -LiteralPath (Join-Path $root $relative) -Destination $destination
    }
    $f
}
function Read-SprintData($Current) { Get-Content -LiteralPath $Current.SprintDataPath -Raw -Encoding UTF8 | ConvertFrom-Json }
function Save-SprintData($Current,$Data) { [IO.File]::WriteAllText($Current.SprintDataPath,($Data | ConvertTo-Json -Depth 60),(New-Object Text.UTF8Encoding($false))) }
function Set-SprintPremises($Data) {
    $Data.State='PROPOSTA'
    $Data.Constraints=[pscustomobject]@{SprintStartDate='2026-10-12';ReferenceDate='2026-10-12';ProductionDeadline='2026-11-08';MaxPreparationSprints=1;MaxImplementationSprints=2;MaxTestSprints=1;MaxTotalSprints=2;MaxDevelopers=2;UnboundedPhases=@()}
    $Data.Team.RolesAreDistinct=$true
    $Data.Team.Staffing=@(foreach ($n in 1..2) { [pscustomobject]@{Sprint=$n;Developers=2;DeveloperAvailability=1;ArchitectAvailability=1;DevOpsAvailability=1;ReservePercent=0;AbsenceDays=@{Dev=0;Architect=0;DevOps=0}} })
    $Data.EvidenceReview=[pscustomobject]@{Reviewed=$true;Reason='Fontes e premissas conferidas na fixture.'}
}
function New-SprintWork($Id,$Phase,$Priority,$Depends,$Dev,$Arq,$Ops,$Issues,$References=@()) {
    [pscustomobject]@{Id=$Id;Title=$Id;Phase=$Phase;Priority=$Priority;DependsOn=@($Depends);Issues=@($Issues);Effort=@{Dev=@{Min=$Dev;Reference=$Dev;Max=$Dev};Architect=@{Min=$Arq;Reference=$Arq;Max=$Arq};DevOps=@{Min=$Ops;Reference=$Ops;Max=$Ops}};EstimateSource='Fixture';Confidence='ALTA';Assumptions=@('Fixture');NotBefore=$null;Deadline=$null;Acceptance='Fixture verificavel';References=@($References);Remaining=$true;AllocationMode='ASAP';AiAssisted=$false}
}
