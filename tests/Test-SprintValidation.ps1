#requires -Version 5.1
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $root 'scripts/HarnessSprintPlanning.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $root 'scripts/Harness.psm1') -Force -DisableNameChecking

function Assert($condition, [string]$message) {
    if (-not $condition) { throw $message }
}

function Reject([scriptblock]$action, [string]$message) {
    $rejected = $false
    try { $null = & $action } catch { $rejected = $true }
    Assert $rejected $message
}

function Copy-Data($value) {
    $value | ConvertTo-Json -Depth 60 | ConvertFrom-Json
}

function Save-Data($receipt, $data) {
    [IO.File]::WriteAllText($receipt.SprintDataPath, ($data | ConvertTo-Json -Depth 60), (New-Object Text.UTF8Encoding($false)))
}

function Check-Scope($data, $receipt = $baseReceipt) {
    & (Get-Module HarnessSprintPlanning) {
        param($inputData, $inputReceipt, $inputRoot)
        Assert-SprintDataScope $inputData $inputReceipt $inputRoot
    } $data $receipt $fixture
}

$failures = New-Object 'Collections.Generic.List[string]'
$passed = 0
function Test-Case([string]$name, [scriptblock]$action) {
    try {
        $null = & $action
        $script:passed++
        Write-Output ('PASS: ' + $name)
    } catch {
        $script:failures.Add($name + ': ' + $_.Exception.Message)
        Write-Output ('FAIL: ' + $name + ': ' + $_.Exception.Message)
    }
}

$fixture = Join-Path $root ('.harness/tests/sprints-validation-' + [guid]::NewGuid().ToString('N'))
$null = [IO.Directory]::CreateDirectory($fixture)
foreach ($relative in @('.github/prompts/planejar-sprints.prompt.md', '.github/prompts/revisar-sprints.prompt.md', 'doc/modelos/planejamento-sprints.template.md', 'doc/features/planejamento-macro-sprints.md', 'doc/especificacoes/planejamento-sprints.md')) {
    $target = Join-Path $fixture $relative
    $null = [IO.Directory]::CreateDirectory((Split-Path $target -Parent))
    Copy-Item -LiteralPath (Join-Path $root $relative) -Destination $target
}
$source = Join-Path $fixture 'api'
$null = [IO.Directory]::CreateDirectory($source)
[IO.File]::WriteAllText((Join-Path $source 'pom.xml'), '<project><modelVersion>4.0.0</modelVersion><groupId>test</groupId><artifactId>validation</artifactId><version>1</version><packaging>pom</packaging></project>')
$project = [pscustomobject]@{name='api';label='api';path=$source}
$context = [pscustomobject]@{Root=$fixture;Projects=@($project);Active=$project;WorkspacePath=(Join-Path $fixture 'fixture.code-workspace')}
$null = Initialize-HarnessMigration $fixture $project
$register = (Get-HarnessMigrationPaths $fixture $project).MigrationPath
$rows = "| I1 | Migrar I1 | mandatory | 1 | PRESENTE | ADIAR | NAO ANALISADA | Evidencia pendente |`r`n| OPT1 | Opcional OPT1 | optional | 1 | PRESENTE | ADIAR | NAO ANALISADA | Evidencia pendente |`r`n"
[IO.File]::WriteAllText($register, ([IO.File]::ReadAllText($register).Replace('<!-- mta:fim -->', ($rows + '<!-- mta:fim -->'))))
$baseReceipt = New-HarnessSprintContext -Context $context -All
$baseData = Get-Content -LiteralPath $baseReceipt.SprintDataPath -Raw -Encoding UTF8 | ConvertFrom-Json
$issue = [pscustomobject]@{Source=$source;Id='I1'}
$outside = [pscustomobject]@{Source=$source;Id='FORA-DO-RECORTE'}
$optional = [pscustomobject]@{Source=$source;Id='OPT1'}
$accepted = [pscustomobject]@{Source=$source;Id='I1';Evidence='Aceite humano registrado na fixture';AcceptedBy='Revisor da fixture'}

Test-Case 'Recorte original e lacunas booleanas sao estruturalmente validos' {
    foreach ($value in @($null, $false, $true)) {
        $data = Copy-Data $baseData
        $data.Team.RolesAreDistinct = $value
        $data.EvidenceReview.Reviewed = $value
        Check-Scope $data
    }
}

Test-Case 'Referencias validas de B0 permanecem aceitas' {
    $data = Copy-Data $baseData
    $data.Work = @([pscustomobject]@{Id='W1';Issues=@($issue)})
    $data.Changes.Reopened = @($issue)
    $data.Baseline.Accepted = @($accepted)
    Check-Scope $data
}

foreach ($field in @('Work.Issues', 'Changes.Reopened', 'Changes.Excluded', 'Baseline.Accepted')) {
    Test-Case ($field + ' rejeita issue fora de B0 e New') {
        $data = Copy-Data $baseData
        switch ($field) {
            'Work.Issues' { $data.Work = @([pscustomobject]@{Id='W1';Issues=@($outside)}) }
            'Changes.Reopened' { $data.Changes.Reopened = @($outside) }
            'Changes.Excluded' { $data.Changes.Excluded = @($outside) }
            'Baseline.Accepted' { $data.Baseline.Accepted = @([pscustomobject]@{Source=$source;Id=$outside.Id;Evidence='Aceite da fixture';AcceptedBy='Revisor'}) }
        }
        Reject { Check-Scope $data } 'Identidade desconhecida foi aceita.'
    }
}

Test-Case 'New rejeita optional sem categoria selecionada' {
    $data = Copy-Data $baseData
    $data.Changes.New = @($optional)
    Reject { Check-Scope $data } 'New incluiu optional fora das categorias escolhidas.'
}

Test-Case 'Optional exige ScopeDecision humana' {
    $data = Copy-Data $baseData
    $data.ScopeCategories = @('mandatory', 'optional')
    $data.Baseline.Issues += $optional
    Reject { Check-Scope $data } 'Optional sem decisao humana foi aceito.'
}

Test-Case 'Optional selecionada com decisao humana e permitida' {
    $data = Copy-Data $baseData
    $data.ScopeCategories = @('mandatory', 'optional')
    $data.ScopeDecision = 'Humano incluiu OPT1 no escopo desta fixture.'
    $data.Baseline.Issues += $optional
    Check-Scope $data
}

foreach ($field in @('Work.Issues', 'Changes.Reopened', 'Changes.Excluded', 'Baseline.Accepted')) {
    Test-Case ($field + ' rejeita Source/ID duplicado') {
        $data = Copy-Data $baseData
        switch ($field) {
            'Work.Issues' { $data.Work = @([pscustomobject]@{Id='W1';Issues=@($issue, $issue)}) }
            'Changes.Reopened' { $data.Changes.Reopened = @($issue, $issue) }
            'Changes.Excluded' { $data.Changes.Excluded = @($issue, $issue) }
            'Baseline.Accepted' { $data.Baseline.Accepted = @($accepted, $accepted) }
        }
        Reject { Check-Scope $data } 'A mesma identidade foi contada duas vezes.'
    }
}

Test-Case 'New rejeita repeticao de issue da B0' {
    $data = Copy-Data $baseData
    $data.Changes.New = @($issue)
    Reject { Check-Scope $data } 'New repetiu identidade da B0.'
}

Test-Case 'Work rejeita associacao com issue excluida' {
    $data = Copy-Data $baseData
    $data.Changes.Excluded = @($issue)
    $data.Work = @([pscustomobject]@{Id='W1';Issues=@($issue)})
    Reject { Check-Scope $data } 'Issue excluida recebeu trabalho no cronograma.'
}

foreach ($field in @('RolesAreDistinct', 'Reviewed')) {
    foreach ($value in @('false', 'true', 0, 1)) {
        Test-Case ($field + ' rejeita ' + $value.GetType().Name + ' ' + [string]$value) {
            $data = Copy-Data $baseData
            if ($field -eq 'RolesAreDistinct') { $data.Team.RolesAreDistinct = $value }
            else { $data.EvidenceReview.Reviewed = $value }
            Reject { Check-Scope $data } 'Valor nao booleano foi convertido implicitamente.'
        }
    }
}

Test-Case 'Simulation manual e rejeitada sem alterar arquivos ou ponteiro publicado' {
    $null = Complete-HarnessSprintPlan -Root $fixture -ContextPath $baseReceipt.ContextPath
    $pointer = Join-Path $fixture ('.harness/sprints/' + $baseReceipt.PlanningId + '/atual.json')
    $revision = New-HarnessSprintContext -Context $context -PreviousContextPath $baseReceipt.ContextPath -Reason 'Conferir protecao de campos calculados'
    $data = Get-Content -LiteralPath $revision.SprintDataPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $data.Simulation = [pscustomobject]@{Feasibility='CABE_NAS_PREMISSAS';Sprints=@()}
    Save-Data $revision $data
    $paths = @($baseReceipt.SprintDataPath, $baseReceipt.SprintPlanPath, $baseReceipt.ValidationPath, $revision.ContextPath, $revision.SprintDataPath, $revision.SprintPlanPath, $pointer)
    $hashes = @{}
    foreach ($path in $paths) { $hashes[$path] = (Get-FileHash -LiteralPath $path).Hash }
    $failure = $null
    try { $null = Complete-HarnessSprintPlan -Root $fixture -ContextPath $revision.ContextPath } catch { $failure = $_.Exception.Message }
    Assert ($failure -like '*Simulation*') ('Simulation manual nao foi rejeitada pelo motivo esperado: ' + $failure)
    foreach ($path in $paths) { Assert ((Get-FileHash -LiteralPath $path).Hash -ceq $hashes[$path]) ('Rejeicao alterou arquivo: ' + $path) }
    Assert (-not (Test-Path -LiteralPath $revision.ValidationPath)) 'Revisao com Simulation manual ganhou validacao.'
    Assert ((Get-Content -LiteralPath $pointer -Raw | ConvertFrom-Json).RevisionId -ceq $baseReceipt.RevisionId) 'Rejeicao publicou ponteiro para a revisao invalida.'
}

Test-Case 'New aceita inclusao na revisao e rejeita Source/ID duplicado' {
    $row = "| I2 | Migrar I2 | mandatory | 1 | PRESENTE | ADIAR | NAO ANALISADA | Nova issue da fixture |`r`n"
    [IO.File]::WriteAllText($register, ([IO.File]::ReadAllText($register).Replace('<!-- mta:fim -->', ($row + '<!-- mta:fim -->'))))
    $revision = New-HarnessSprintContext -Context $context -PreviousContextPath $baseReceipt.ContextPath -Reason 'Nova mandatory para conferir inclusao sem duplicata'
    $data = Get-Content -LiteralPath $revision.SprintDataPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $newIssue = [pscustomobject]@{Source=$source;Id='I2'}
    $data.Changes.New = @($newIssue)
    Check-Scope $data $revision
    $data.Changes.New = @($newIssue, $newIssue)
    Reject { Check-Scope $data $revision } 'New repetiu a mesma inclusao da revisao.'
}

Test-Case 'New historica validada nao desaparece quando a issue sai do registro' {
    $included = New-HarnessSprintContext -Context $context -PreviousContextPath $baseReceipt.ContextPath -Reason 'Validar inclusao historica de I2'
    $data = Get-Content -LiteralPath $included.SprintDataPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $newIssue = [pscustomobject]@{Source=$source;Id='I2'}
    $data.Changes.New = @($newIssue)
    $data.EvidenceReview.Reviewed = $true
    $data.EvidenceReview.Reason = 'Comparacao humana da fixture confirmou a nova mandatory I2.'
    Save-Data $included $data
    # Scope validation uses the durable validation even if pointer publication needs retry.
    try { $null = Complete-HarnessSprintPlan -Root $fixture -ContextPath $included.ContextPath }
    catch {
        $cause = $_.Exception.GetBaseException()
        $nativeCode = $cause.HResult -band 0xFFFF
        if ($cause -isnot [IO.IOException] -or $nativeCode -notin @(32, 1175) -or -not (Test-Path -LiteralPath $included.ValidationPath)) { throw }
        Write-Warning ('Fixture historica validada; teste de escopo segue sem publicacao apos IOException ' + $nativeCode + ': ' + $cause.Message)
    }
    $validation = Get-Content -LiteralPath $included.ValidationPath -Raw -Encoding UTF8 | ConvertFrom-Json
    Assert ($validation.Status -eq 'VALIDATED' -and $validation.BaselineFrozen) 'Fixture historica precisa de B0 e revisao efetivamente validadas.'
    Assert ($validation.DataSha256 -ceq (Get-FileHash -LiteralPath $included.SprintDataPath).Hash -and $validation.PlanSha256 -ceq (Get-FileHash -LiteralPath $included.SprintPlanPath).Hash) 'Validacao historica diverge dos arquivos persistidos.'
    Assert (@($validation.DataSnapshot.Changes.New).Count -eq 1 -and $validation.DataSnapshot.Changes.New[0].Id -ceq 'I2') 'Fixture nao validou a inclusao de I2.'
    $historicalDataHash = (Get-FileHash -LiteralPath $included.SprintDataPath).Hash
    $historicalValidationHash = (Get-FileHash -LiteralPath $included.ValidationPath).Hash
    $row = "| I2 | Migrar I2 | mandatory | 1 | PRESENTE | ADIAR | NAO ANALISADA | Nova issue da fixture |`r`n"
    Assert ([IO.File]::ReadAllText($register).Contains($row)) 'Fixture nao encontrou I2 para retira-la do registro.'
    [IO.File]::WriteAllText($register, ([IO.File]::ReadAllText($register).Replace($row, '')))
    $removed = New-HarnessSprintContext -Context $context -PreviousContextPath $included.ContextPath -Reason 'I2 saiu do registro; preservar decisao e historico'
    $data = Get-Content -LiteralPath $removed.SprintDataPath -Raw -Encoding UTF8 | ConvertFrom-Json
    Assert (@($data.Changes.New).Count -eq 1 -and $data.Changes.New[0].Id -ceq 'I2') 'Preparo apagou a inclusao historica.'
    $data.Changes.Excluded = @([pscustomobject]@{Source=$source;Id='I2';Reason='Exclusao de escopo decidida pelo humano';Evidence='Decisao humana registrada nesta fixture'})
    Check-Scope $data $removed
    $data.Changes.New = @()
    $data.Changes.Excluded = @()
    Reject { Check-Scope $data $removed } 'Revisao apagou New historica validada porque I2 deixou de constar no registro.'
    Assert ((Get-FileHash -LiteralPath $included.SprintDataPath).Hash -ceq $historicalDataHash -and (Get-FileHash -LiteralPath $included.ValidationPath).Hash -ceq $historicalValidationHash) 'Conferencia de escopo alterou a revisao historica.'
}

if ($failures.Count) { throw ('SprintValidation: ' + $failures.Count + ' falha(s), ' + $passed + ' caso(s) passaram.' + "`n" + ($failures -join "`n")) }
Write-Output ('PASS: SprintValidation ' + $passed + ' casos de escopo, tipos e preservacao de arquivos.')
