#requires -Version 5.1
$ErrorActionPreference='Stop'; Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'ConversionFixture.ps1')
Import-Module (Join-Path $root 'tools/transicao/ConversaoPublicacao.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $root 'scripts/HarnessSprintPlanning.psm1') -DisableNameChecking
function New-SelectionSprint($Fixture,[string]$PlanningId,[string]$RevisionId,[string]$Reference,$Previous=$null,[switch]$Validated) {
    $directory=Join-Path $Fixture.Workspace ('.harness/sprints/'+$PlanningId+'/revisoes/'+$RevisionId)
    $issues=@(@{Source=$Fixture.Source;Id='java::regra'})
    $work=@{Id='migrar';Title='Migrar';Phase='IMPLEMENTATION';Priority=1;DependsOn=@();Issues=$issues;Effort=@{Dev=@{Min=1;Reference=1;Max=1};Architect=@{Min=0;Reference=0;Max=0};DevOps=@{Min=0;Reference=0;Max=0}};EstimateSource='Estimativa humana';Confidence='alta';Assumptions=@();NotBefore=$null;Deadline=$null;Acceptance='Conferir';References=@($Reference);Remaining=$true;AllocationMode='ASAP';AiAssisted=$false}
    $staff=@{Sprint=1;Developers=1;DeveloperAvailability=1;ArchitectAvailability=1;DevOpsAvailability=1;ReservePercent=0;AbsenceDays=@{Dev=0;Architect=0;DevOps=0}}
    $data=@{SchemaVersion=1;Purpose='sprint-planning';PlanningId=$PlanningId;RevisionId=$RevisionId;State='RASCUNHO';ScopeCategories=@('mandatory');ScopeDecision='Escopo escolhido';Constraints=@{SprintStartDate='2026-10-05';ReferenceDate='2026-10-05';ProductionDeadline='2026-10-16';MaxPreparationSprints=1;MaxImplementationSprints=1;MaxTestSprints=1;MaxTotalSprints=1;MaxDevelopers=1;UnboundedPhases=@()};Team=@{RolesAreDistinct=$true;WorkWeek=@(1,2,3,4,5);Holidays=@();Staffing=@($staff)};Baseline=@{Id='B0';Known=$true;Issues=$issues;Accepted=@()};Changes=@{New=@();Reopened=@();Excluded=@()};Work=@($work);Assumptions=@();Decisions=@();Estimation=@{AiDeveloperReductionPercent=0};EvidenceReview=@{Reviewed=$false;Reason=$null};EstimateEvidence=@();Simulation=$null}
    $context=@{SchemaVersion=1;Purpose='sprint-planning';PlanningId=$PlanningId;RevisionId=$RevisionId;SelectionMode='SUBSET';Projects=@(@{Project='apelido';Label='apelido';Source=$Fixture.Source;MigrationPath=$Fixture.Register;Issues=$issues;Diagnostics=@();RegisterValid=$true});References=@();Reason='Fixture';Previous=$null;ContextPath=(Join-Path $directory 'contexto.json');SprintDataPath=(Join-Path $directory 'planejamento-sprints.json');SprintPlanPath=(Join-Path $directory 'planejamento-sprints.md');ValidationPath=(Join-Path $directory 'validacao.json');PromptPath=(Join-Path $directory 'planejar-sprints.prompt.md');ReviewPromptPath=(Join-Path $directory 'revisar-sprints.prompt.md');WorkTemplate=$work;StaffingTemplate=$staff}
    if ($Previous) { $context.Previous=@{PlanningId=$Previous.PlanningId;RevisionId=$Previous.RevisionId;ContextPath=$Previous.ContextPath;SprintDataPath=$Previous.SprintDataPath;SprintPlanPath=$Previous.SprintPlanPath;DataSha256=(Get-FileHash -LiteralPath $Previous.SprintDataPath).Hash;PlanSha256=(Get-FileHash -LiteralPath $Previous.SprintPlanPath).Hash} }
    $block="<!-- sprints:inicio -->`nCalculo pendente.`n<!-- sprints:fim -->"
    Write-ConversionFile $context.SprintPlanPath $block
    Write-ConversionFile $context.PromptPath '# Planejar'; Write-ConversionFile $context.ReviewPromptPath '# Revisar'
    Write-ConversionFile $context.ContextPath ($context|ConvertTo-Json -Depth 40)
    $sha=[Security.Cryptography.SHA256]::Create()
    try { $blockHash=[BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes(($block|ConvertTo-Json -Compress)))).Replace('-','') } finally { $sha.Dispose() }
    Write-ConversionFile (Join-Path $directory 'preparo.json') (@{ContextSha256=(Get-FileHash -LiteralPath $context.ContextPath).Hash;CalculatedBlockSha256=$blockHash;ReviewPromptSha256=(Get-FileHash -LiteralPath $context.ReviewPromptPath).Hash}|ConvertTo-Json)
    if ($Validated) { $data.Simulation=Get-HarnessSprintSimulation $data; Write-ConversionFile $context.SprintPlanPath ($block.Replace('pendente','validado')) }
    Write-ConversionFile $context.SprintDataPath ($data|ConvertTo-Json -Depth 60)
    if ($Validated) {
        $validation=@{SchemaVersion=1;Purpose='sprint-planning-validation';PlanningId=$PlanningId;RevisionId=$RevisionId;Status='VALIDATED';ContextPath=$context.ContextPath;SprintPlanPath=$context.SprintPlanPath;ContextSha256=(Get-FileHash -LiteralPath $context.ContextPath).Hash;DataSha256=(Get-FileHash -LiteralPath $context.SprintDataPath).Hash;PlanSha256=(Get-FileHash -LiteralPath $context.SprintPlanPath).Hash;DataSnapshot=$data;BaselineFrozen=$true}
        Write-ConversionFile $context.ValidationPath ($validation|ConvertTo-Json -Depth 60)
    }
    [pscustomobject]$context
}
$failures=New-Object 'Collections.Generic.List[string]'
try {
    $f=New-ConversionFixture
    $reference=Join-Path $f.Workspace '.harness/sprints/evidencias/estimativa.md'
    Write-ConversionFile $reference '# Estimativa comum aos dois cenarios'
    $x=New-SelectionSprint $f ('a'*32) ('1'*32) $reference
    $y=New-SelectionSprint $f ('b'*32) ('1'*32) $reference
    $choiceX=@{Contexto=$x.ContextPath;Cenario='x';MestrePom=$f.Pom}; $choiceY=@{Contexto=$y.ContextPath;Cenario='y';MestrePom=$f.Pom}
    $null=Invoke-ConversionApply $f.Workspace $f.Pom -Sprints @($choiceY,$choiceX)
    $before=Get-ConversionState $f
    Assert ((Invoke-ConversionApply $f.Workspace $f.Pom -Sprints @($choiceX,$choiceY)).Status -ceq 'EQUIVALENTE') 'Inverter escolhas nao deve trocar o dono do anexo compartilhado.'
    Assert ((Get-ConversionState $f) -ceq $before) 'Ordem de escolhas nao regrava arquivos.'
} catch { $failures.Add('ORDEM: '+$_.Exception.Message) }
try {
    $g=New-ConversionFixture
    $reference=Join-Path $g.Area 'estimativa.md'; Write-ConversionFile $reference '# Estimativa'
    $ancestor=New-SelectionSprint $g ('c'*32) ('1'*32) $reference -Validated
    $draft=New-SelectionSprint $g ('c'*32) ('2'*32) $reference $ancestor
    $before=Get-ConversionState $g; $rejected=$false
    try { $null=Invoke-ConversionApply $g.Workspace $g.Pom -Sprints @(@{Contexto=$draft.ContextPath;Cenario='historico';MestrePom=$g.Pom}) }
    catch { Assert ($_.Exception.Message -match 'ponteiro|validacao|histor|ancestr') 'Recusa deve explicar a ausencia de publicacao comprovada.'; $rejected=$true }
    Assert $rejected 'Draft com ancestral validado e atual.json ausente deve recusar para preservar o consumo historico.'
    Assert ((Get-ConversionState $g) -ceq $before) 'Ponteiro ausente nao autoriza publicar um rascunho que perde historico.'
} catch { $failures.Add('PONTEIRO: '+$_.Exception.Message) }
if ($failures.Count) { throw ($failures -join "`n") }
'PASS: ordem das escolhas independente e historico validado exige ponteiro.'
