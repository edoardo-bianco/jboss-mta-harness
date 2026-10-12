#requires -Version 5.1
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'SprintCurrentFixture.ps1')
function Copy-Data($value) { $value | ConvertTo-Json -Depth 60 | ConvertFrom-Json }
function Check-Scope($data) {
    $input=Get-HarnessSprintSources $f.Context $f.Context.Projects
    $view=[pscustomobject]@{Scenario=$baseReceipt.Scenario;Projects=$input.Projects}
    $previous=if (Test-Path $baseReceipt.ValidationPath) { Get-Content $baseReceipt.ValidationPath -Raw | ConvertFrom-Json } else {$null}
    & (Get-Module HarnessSprintPlanning) { param($data,$view,$previous) Assert-SprintDataScope $data $view $previous } $data $view $previous
}
$failures=New-Object 'Collections.Generic.List[string]'; $passed=0
function Test-Case([string]$name,[scriptblock]$action) {
    try { $null=& $action; $script:passed++; Write-Host ('PASS: '+$name) }
    catch { $script:failures.Add($name+': '+$_.Exception.Message); Write-Host ('FAIL: '+$name+': '+$_.Exception.Message) }
}
$f=New-SprintFixture
$source=$f.Projects[0].Source; $register=$f.Projects[0].MigrationPath
$table=@('| ID | Issue | Categoria | Ocorrencias | Presenca | Decisao | Andamento | Observacao/referencia |',
    '| --- | --- | --- | --- | --- | --- | --- | --- |',
    '| I1 | Migrar I1 | mandatory | 1 | PRESENTE | ADIAR | NAO ANALISADA | Conferir |',
    '| OPT1 | Opcional | optional | 1 | PRESENTE | ADIAR | NAO ANALISADA | Conferir |') -join [Environment]::NewLine
[IO.File]::WriteAllText($register,(Set-ProjectManagedBlock ([IO.File]::ReadAllText($register)) 'mta' $table))
$baseReceipt=New-HarnessSprintContext $f.Context -All
$baseData=Read-SprintData $baseReceipt
$issue=[pscustomobject]@{Project='a';Source=$source;Id='I1'}
$outside=[pscustomobject]@{Project='a';Source=$source;Id='FORA-DO-RECORTE'}
$optional=[pscustomobject]@{Project='a';Source=$source;Id='OPT1'}
$accepted=[pscustomobject]@{Project='a';Source=$source;Id='I1';Evidence='Aceite humano da fixture';AcceptedBy='Revisor'}
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

Test-Case 'Simulation manual recusada preserva ultimo resultado' {
    $null=Complete-HarnessSprintPlan $f.Root $baseReceipt.ContextPath
    $before=[IO.File]::ReadAllText($baseReceipt.ValidationPath)
    $data=Read-SprintData $baseReceipt
    $data | Add-Member -NotePropertyName Simulation -NotePropertyValue @{Feasibility='CABE_NAS_PREMISSAS'}
    Save-SprintData $baseReceipt $data
    Reject { Complete-HarnessSprintPlan $f.Root $baseReceipt.ContextPath } 'Simulation editavel nao pode entrar no calculo.'
    Assert ([IO.File]::ReadAllText($baseReceipt.ValidationPath) -ceq $before) 'Falha apagou ultimo resultado.'
    $data.PSObject.Properties.Remove('Simulation'); Save-SprintData $baseReceipt $data
}
Test-Case 'Inclusao acumulada preservada quando issue sai do registro' {
    $row='| I2 | Migrar I2 | mandatory | 1 | PRESENTE | ADIAR | NAO ANALISADA | Nova |'
    [IO.File]::WriteAllText($register,[IO.File]::ReadAllText($register).Replace('<!-- mta:fim -->',($row+[Environment]::NewLine+'<!-- mta:fim -->')))
    $null=New-HarnessSprintContext $f.Context -ContextPath $baseReceipt.ContextPath -Reason 'Nova issue'
    $data=Read-SprintData $baseReceipt
    $new=[pscustomobject]@{Project='a';Source=$source;Id='I2'}
    $data.Changes.New=@($new); Check-Scope $data
    $data.Changes.New=@($new,$new); Reject { Check-Scope $data } 'Inclusao duplicada deveria falhar.'
    $data.Changes.New=@($new); Save-SprintData $baseReceipt $data
    $null=Complete-HarnessSprintPlan $f.Root $baseReceipt.ContextPath
    [IO.File]::WriteAllText($register,[IO.File]::ReadAllText($register).Replace($row,''))
    $null=New-HarnessSprintContext $f.Context -ContextPath $baseReceipt.ContextPath -Reason 'I2 ausente no MTA'
    $data=Read-SprintData $baseReceipt
    Assert ($data.Changes.New.Count -eq 1) 'Preparo perdeu inclusao acumulada.'
    $data.Changes.Excluded=@([pscustomobject]@{Project='a';Source=$source;Id='I2';Reason='Decisao humana';Evidence='Fixture'})
    Check-Scope $data
    $data.Changes.New=@(); $data.Changes.Excluded=@()
    Reject { Check-Scope $data } 'Inclusao calculada nao pode desaparecer.'
}
if ($failures.Count) { throw ($failures -join [Environment]::NewLine) }
Write-Host ('PASS: SprintValidation '+$passed+' casos de escopo, tipos e preservacao.')
