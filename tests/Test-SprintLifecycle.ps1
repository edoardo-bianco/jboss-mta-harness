#requires -Version 5.1
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $root 'scripts/HarnessSprintPlanning.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $root 'scripts/Harness.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $root 'scripts/HarnessCleanup.psm1') -Force -DisableNameChecking

function Assert($condition, [string]$message) {
    if (-not $condition) { throw $message }
}

function Reject([scriptblock]$action, [string]$expected, [string]$message) {
    $failure = $null
    try { $null = & $action } catch { $failure = $_.Exception.Message }
    Assert ($null -ne $failure) $message
    if ($expected) { Assert ($failure -like ('*' + $expected + '*')) ($message + ' Erro recebido: ' + $failure) }
}

function Read-Data($receipt) {
    Get-Content -LiteralPath $receipt.SprintDataPath -Raw -Encoding UTF8 | ConvertFrom-Json
}

function Save-Data($receipt, $data) {
    [IO.File]::WriteAllText($receipt.SprintDataPath, ($data | ConvertTo-Json -Depth 60), (New-Object Text.UTF8Encoding($false)))
}

function Add-Issue($project, [string]$id, [string]$observation = 'Evidencia pendente') {
    $path = (Get-HarnessMigrationPaths $fixture $project).MigrationPath
    $row = '| {0} | Migrar {0} | mandatory | 1 | PRESENTE | ADIAR | NAO ANALISADA | {1} |' -f $id, $observation
    $markdown = [IO.File]::ReadAllText($path).Replace('<!-- mta:fim -->', ($row + "`r`n<!-- mta:fim -->"))
    [IO.File]::WriteAllText($path, $markdown)
}

function Get-PointerPath($receipt) {
    Join-Path $fixture ('.harness/sprints/' + $receipt.PlanningId + '/atual.json')
}

function Read-Pointer($receipt) {
    Get-Content -LiteralPath (Get-PointerPath $receipt) -Raw -Encoding UTF8 | ConvertFrom-Json
}

$fixture = Join-Path $root ('.harness/tests/sprints-lifecycle-' + [guid]::NewGuid().ToString('N'))
$null = [IO.Directory]::CreateDirectory($fixture)
foreach ($relative in @('.github/prompts/planejar-sprints.prompt.md', '.github/prompts/revisar-sprints.prompt.md', 'doc/modelos/planejamento-sprints.template.md', 'doc/features/planejamento-macro-sprints.md', 'doc/especificacoes/planejamento-sprints.md')) {
    $target = Join-Path $fixture $relative
    $null = [IO.Directory]::CreateDirectory((Split-Path $target -Parent))
    Copy-Item -LiteralPath (Join-Path $root $relative) -Destination $target
}
$projects = @(foreach ($name in @('api principal', 'api adicional')) {
    $source = Join-Path $fixture $name
    $null = [IO.Directory]::CreateDirectory($source)
    [IO.File]::WriteAllText((Join-Path $source 'pom.xml'), '<project><modelVersion>4.0.0</modelVersion><groupId>test</groupId><artifactId>lifecycle</artifactId><version>1</version><packaging>pom</packaging></project>')
    [pscustomobject]@{name=$name.Replace(' ', '-');label=$name;path=$source}
})
$context = [pscustomobject]@{Root=$fixture;Projects=$projects;Active=$projects[0];WorkspacePath=(Join-Path $fixture 'fixture.code-workspace')}
$null = Initialize-HarnessMigration $fixture $projects[0]
Add-Issue $projects[0] 'I1'

# A structural validation of an incomplete draft must not freeze an unknown B0.
$unknown = New-HarnessSprintContext -Context $context -All
$unknownValidation = Complete-HarnessSprintPlan -Root $fixture -ContextPath $unknown.ContextPath
Assert (-not $unknownValidation.BaselineFrozen -and -not $unknownValidation.DataSnapshot.Baseline.Known) 'Rascunho sem registro congelou uma baseline desconhecida.'
Assert ($unknownValidation.Feasibility -eq 'NAO_AVALIAVEL') 'Registro ausente nao pode produzir cenario avaliavel.'
$unknownHash = (Get-FileHash -LiteralPath $unknown.SprintDataPath).Hash
$null = Initialize-HarnessMigration $fixture $projects[1]
Add-Issue $projects[1] 'I-extra'
$formed = New-HarnessSprintContext -Context $context -PreviousContextPath $unknown.ContextPath -Reason 'Registro adicional informado'
$formedData = Read-Data $formed
Assert ($formedData.Baseline.Known -and @($formedData.Baseline.Issues).Count -eq 2) 'Revisao deve formar B0 depois de resolver os registros ausentes.'
$formedValidation = Complete-HarnessSprintPlan -Root $fixture -ContextPath $formed.ContextPath
Assert $formedValidation.BaselineFrozen 'Baseline conhecida nao foi preservada para as proximas revisoes.'
Assert ((Get-FileHash -LiteralPath $unknown.SprintDataPath).Hash -ceq $unknownHash) 'Formacao de B0 alterou o rascunho historico.'

# The nearest validated ancestor remains authoritative through intermediate drafts.
$a = New-HarnessSprintContext -Context $context -Sources @($projects[0].path)
$data = Read-Data $a
$data.Constraints.SprintStartDate = '2026-10-05'
$data.Constraints.ProductionDeadline = '2026-11-01'
$data.Constraints.ReferenceDate = '2026-10-05'
$data.Constraints.MaxPreparationSprints = 2
$data.Constraints.MaxImplementationSprints = 2
$data.Constraints.MaxTestSprints = 2
$data.Constraints.MaxDevelopers = 1
Save-Data $a $data
$commentA = 'Comentario humano A: conservar a janela e o aceite registrado.'
[IO.File]::AppendAllText($a.SprintPlanPath, ("`r`n" + $commentA + "`r`n"))
$null = Complete-HarnessSprintPlan -Root $fixture -ContextPath $a.ContextPath
$aDataHash = (Get-FileHash -LiteralPath $a.SprintDataPath).Hash
$aPlanHash = (Get-FileHash -LiteralPath $a.SprintPlanPath).Hash
$b = New-HarnessSprintContext -Context $context -PreviousContextPath $a.ContextPath -Reason 'Refinar a narrativa'
$commentB = 'Comentario humano B: dependencia externa ainda em refinamento.'
[IO.File]::AppendAllText($b.SprintPlanPath, ("`r`n" + $commentB + "`r`n"))
$bDataHash = (Get-FileHash -LiteralPath $b.SprintDataPath).Hash
$bPlanHash = (Get-FileHash -LiteralPath $b.SprintPlanPath).Hash
$c = New-HarnessSprintContext -Context $context -PreviousContextPath $b.ContextPath -Reason 'Consolidar o rascunho intermediario'
$data = Read-Data $c
$baselineId = $data.Baseline.Id
$data.Baseline.Id = 'B0-alterada-no-rascunho'
Save-Data $c $data
Reject { Complete-HarnessSprintPlan -Root $fixture -ContextPath $c.ContextPath } 'B0 validada e fixa' 'Rascunho intermediario permitiu trocar a baseline ancestral.'
$data.Baseline.Id = $baselineId
Save-Data $c $data
$null = Complete-HarnessSprintPlan -Root $fixture -ContextPath $c.ContextPath
Assert ((Read-Pointer $c).RevisionId -ceq $c.RevisionId) 'Revisao descendente de rascunho nao substituiu o ancestral publicado.'
Assert (-not (Test-Path -LiteralPath $b.ValidationPath)) 'Validar descendente publicou indevidamente o rascunho intermediario.'
Assert ((Get-FileHash -LiteralPath $a.SprintDataPath).Hash -ceq $aDataHash -and (Get-FileHash -LiteralPath $a.SprintPlanPath).Hash -ceq $aPlanHash) 'Validacao alterou os dados/plano do ancestral validado.'
Assert ((Get-FileHash -LiteralPath $b.SprintDataPath).Hash -ceq $bDataHash -and (Get-FileHash -LiteralPath $b.SprintPlanPath).Hash -ceq $bPlanHash) 'Validacao alterou os dados/plano do rascunho anterior.'
$cMarkdown = [IO.File]::ReadAllText($c.SprintPlanPath)
Assert ($cMarkdown.Contains($commentA) -and $cMarkdown.Contains($commentB)) 'Narrativa humana fora do bloco calculado foi perdida na revisao.'
Assert ((Read-Data $c).Constraints.SprintStartDate -eq '2026-10-05') 'Revisao perdeu a data inicial informada.'

# Newly catalogued mandatory issues cannot vanish behind the frozen denominator.
Add-Issue $projects[0] 'I2'
$newIssue = New-HarnessSprintContext -Context $context -PreviousContextPath $c.ContextPath -Reason 'Nova issue mandatory no registro'
Reject { Complete-HarnessSprintPlan -Root $fixture -ContextPath $newIssue.ContextPath } 'B0/Changes.New' 'Nova mandatory omitida foi aceita pela validacao.'
Assert (-not (Test-Path -LiteralPath $newIssue.ValidationPath) -and (Read-Pointer $c).RevisionId -ceq $c.RevisionId) 'Rejeicao de cobertura publicou uma revisao inconsistente.'
$data = Read-Data $newIssue
$data.Changes.New = @([pscustomobject]@{Source=$projects[0].path;Id='I2'})
$data.EvidenceReview.Reviewed = $true
$data.EvidenceReview.Reason = 'Registro comparado: I2 permanece a estimar.'
Save-Data $newIssue $data
$null = Complete-HarnessSprintPlan -Root $fixture -ContextPath $newIssue.ContextPath
$data = Read-Data $newIssue
Assert (@($data.Baseline.Issues).Count -eq 1 -and $data.Baseline.Issues[0].Id -ceq 'I1') 'Revisao reescreveu B0 para incluir a nova issue.'
Assert (@($data.Changes.New).Count -eq 1 -and $data.Changes.New[0].Id -ceq 'I2') 'Nova issue nao permaneceu separada da baseline.'

$changedDate = New-HarnessSprintContext -Context $context -PreviousContextPath $newIssue.ContextPath -Reason 'Conferir preservacao do calendario'
$data = Read-Data $changedDate
$data.Constraints.SprintStartDate = '2026-10-06'
Save-Data $changedDate $data
Reject { Complete-HarnessSprintPlan -Root $fixture -ContextPath $changedDate.ContextPath } 'Inicio das sprints' 'Alteracao da cadencia publicada foi aceita numa revisao.'

# Scope changes require explicit intent and retain the same scenario/history.
Reject { New-HarnessSprintContext -Context $context -PreviousContextPath $newIssue.ContextPath -Sources @($projects[1].path) } 'motivo' 'Mudanca de Sources sem motivo foi aceita.'
$scope = New-HarnessSprintContext -Context $context -PreviousContextPath $newIssue.ContextPath -Sources @($projects[1].path) -Reason 'Revisar explicitamente o conjunto de projetos'
Assert ($scope.PlanningId -ceq $newIssue.PlanningId -and $scope.Previous.RevisionId -ceq $newIssue.RevisionId) 'Mudanca de escopo perdeu a cadeia do cenario.'
Assert ($scope.SelectionMode -ceq 'SUBSET' -and $scope.Projects.Count -eq 1 -and $scope.Projects[0].Source -ieq $projects[1].path) 'Revisao nao respeitou o subconjunto informado.'
Assert ((Read-Data $scope).Baseline.Issues[0].Id -ceq 'I1') 'Mudanca de projetos reescreveu B0 ja formada.'
$data = Read-Data $scope
$data.Changes.New += [pscustomobject]@{Source=$projects[1].path;Id='I-extra'}
$data.Changes.Excluded = @(
    [pscustomobject]@{Source=$projects[0].path;Id='I1'},
    [pscustomobject]@{Source=$projects[0].path;Id='I2'}
)
$data.Decisions = @('Fixture humana: retirar P1 do escopo, preservando I1 na B0 e I2 como inclusao historica, ambas excluidas.')
$data.EvidenceReview.Reviewed = $true
$data.EvidenceReview.Reason = 'Mudanca explicita para P2; inclusoes anteriores permanecem no historico.'
Save-Data $scope $data
$null = Complete-HarnessSprintPlan -Root $fixture -ContextPath $scope.ContextPath
Assert ((Read-Pointer $scope).RevisionId -ceq $scope.RevisionId) 'Revisao de subconjunto com exclusoes explicitas nao foi publicada.'
Assert (@((Read-Data $scope).Changes.New | Where-Object Id -CEQ 'I2').Count -eq 1) 'Revisao removeu a inclusao historica para validar o novo escopo.'

# A readable pointer that cannot be replaced fails after validation, then recovers.
$published = New-HarnessSprintContext -Context $context -Sources @($projects[1].path)
$null = Complete-HarnessSprintPlan -Root $fixture -ContextPath $published.ContextPath
$retry = New-HarnessSprintContext -Context $context -PreviousContextPath $published.ContextPath -Reason 'Revisao para testar recuperacao de publicacao'
$pointer = Get-PointerPath $published
$pointerLease = [IO.File]::Open($pointer, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
try {
    Reject { Complete-HarnessSprintPlan -Root $fixture -ContextPath $retry.ContextPath } '' 'Publicacao deveria falhar enquanto o ponteiro esta bloqueado para substituicao.'
    Assert (Test-Path -LiteralPath $retry.ValidationPath) 'Fixture deve falhar depois de gravar validacao, nao antes.'
    Assert ((Read-Pointer $published).RevisionId -ceq $published.RevisionId) 'Falha de publicacao alterou o ponteiro anterior.'
} finally { $pointerLease.Dispose() }
$retryDataHash = (Get-FileHash -LiteralPath $retry.SprintDataPath).Hash
$retryPlanHash = (Get-FileHash -LiteralPath $retry.SprintPlanPath).Hash
$retryValidationHash = (Get-FileHash -LiteralPath $retry.ValidationPath).Hash
$null = Complete-HarnessSprintPlan -Root $fixture -ContextPath $retry.ContextPath
Assert ((Read-Pointer $retry).RevisionId -ceq $retry.RevisionId) 'Retry consistente nao recuperou a publicacao do ponteiro.'
Assert ((Get-FileHash -LiteralPath $retry.SprintDataPath).Hash -ceq $retryDataHash -and (Get-FileHash -LiteralPath $retry.SprintPlanPath).Hash -ceq $retryPlanHash -and (Get-FileHash -LiteralPath $retry.ValidationPath).Hash -ceq $retryValidationHash) 'Retry recalculou ou reescreveu uma revisao validada.'

# A malformed annex must remain a gap without losing the known issue inventory.
Add-Issue $projects[1] 'I-link' '[relatorio](relatorio.md "Titulo do anexo")'
$malformed = New-HarnessSprintContext -Context $context -Sources @($projects[1].path)
Assert (@($malformed.Projects[0].Issues).Count -eq 2 -and @($malformed.Projects[0].Issues | Where-Object Id -CEQ 'I-link').Count -eq 1) 'Referencia malformada removeu issues conhecidas.'
Assert (@($malformed.References | Where-Object Status -EQ 'INVALIDA').Count -gt 0) 'Referencia malformada nao ficou identificada como lacuna.'

$invalidEvidence = New-HarnessSprintContext -Context $context -Sources @($projects[0].path)
$data = Read-Data $invalidEvidence
$work = $invalidEvidence.WorkTemplate | ConvertTo-Json -Depth 30 | ConvertFrom-Json
$work.Id = 'estimativa-com-referencia-invalida'
$work.Priority = 1
$work.Issues = @([pscustomobject]@{Source=$projects[0].path;Id='I1'})
$work.EstimateSource = 'Fixture de validacao de caminho'
$work.Confidence = 'BAIXA'
$work.Assumptions = @('Estimativa provisoria; arquivo precisa de conferencia')
$work.Acceptance = 'Conferir anexo'
$work.References = @('anexo?.md')
$data.Work = @($work)
Save-Data $invalidEvidence $data
$invalidValidation = Complete-HarnessSprintPlan -Root $fixture -ContextPath $invalidEvidence.ContextPath
Assert ($invalidValidation.Feasibility -eq 'NAO_AVALIAVEL') 'Referencia invalida sustentou viabilidade.'
Assert (@($invalidValidation.DataSnapshot.EstimateEvidence | Where-Object Status -EQ 'INVALIDA').Count -eq 1) 'Hash/status de evidencia invalida nao foi registrado.'
Assert (@($invalidValidation.Diagnostics | Where-Object { $_ -like '*Arquivo usado para estimar*' }).Count -gt 0) 'Lacuna da referencia de estimativa ficou sem diagnostico.'

$manualBlock = New-HarnessSprintContext -Context $context -Sources @($projects[0].path)
$markdown = [IO.File]::ReadAllText($manualBlock.SprintPlanPath).Replace('Calculos pendentes.', 'Calculo manual indevido: 100%.')
[IO.File]::WriteAllText($manualBlock.SprintPlanPath, $markdown)
Reject { Complete-HarnessSprintPlan -Root $fixture -ContextPath $manualBlock.ContextPath } 'Bloco calculado' 'Edicao manual do bloco calculado foi sobrescrita silenciosamente.'
Assert (-not (Test-Path -LiteralPath $manualBlock.ValidationPath)) 'Bloco adulterado recebeu validacao.'

# Cleanup keeps official sprint scenarios even when transient runs are present.
$builds = Join-Path $fixture '.harness/builds'
$null = [IO.Directory]::CreateDirectory($builds)
[IO.File]::WriteAllText((Join-Path $builds 'descartavel.txt'), 'Fixture descartavel')
$cleanup = @(Get-HarnessCleanupPaths -Root $fixture -All)
Assert ($builds -in $cleanup) 'Fixture de limpeza nao incluiu seu controle descartavel.'
$sprintRoot = Join-Path $fixture '.harness/sprints'
foreach ($path in $cleanup) {
    Assert (-not ($sprintRoot -ieq $path -or $sprintRoot.StartsWith($path + '\', [StringComparison]::OrdinalIgnoreCase) -or $path.StartsWith($sprintRoot + '\', [StringComparison]::OrdinalIgnoreCase))) 'Limpeza atingiria planejamento oficial de sprints.'
}
Write-Output 'PASS: SprintLifecycle baseline, cadeia de rascunhos, cobertura, escopo, publicacao recuperavel, evidencias e preservacao.'
