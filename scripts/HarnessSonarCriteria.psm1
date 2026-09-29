#requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'

function Get-SonarMetricNumber {
    param([object[]]$Measures, [string]$Name, [switch]$Coverage)
    $items=@($Measures | Where-Object { $_ -and $_.PSObject.Properties['metric'] -and $_.metric -ceq $Name })
    if ($items.Count -ne 1 -or -not $items[0].PSObject.Properties['value']) { return $null }
    $raw=[string]$items[0].value
    $pattern=if ($Coverage) { '^\d+(\.\d+)?$' } else { '^\d+$' }
    $number=[decimal]0
    if ($raw -cnotmatch $pattern -or -not [decimal]::TryParse($raw, [Globalization.NumberStyles]::AllowDecimalPoint, [Globalization.CultureInfo]::InvariantCulture, [ref]$number)) { return $null }
    if ($Coverage -and $number -gt 100) { return $null }
    $number
}

function Get-HarnessSonarCriteria {
    param([object[]]$Measures, $Baseline=$null)
    $coverage=Get-SonarMetricNumber $Measures 'coverage' -Coverage
    $blocker=Get-SonarMetricNumber $Measures 'software_quality_blocker_issues'
    $high=Get-SonarMetricNumber $Measures 'software_quality_high_issues'
    $issues=Get-SonarMetricNumber $Measures 'violations'
    $warnings=@(); $failures=@(); $pending=@(); $delta=$null
    if ($null -eq $coverage) { $pending+='Cobertura ausente ou invalida.' }
    elseif ($coverage -lt 85) { $warnings+='Cobertura abaixo de 85%.' }
    if ($null -eq $blocker) { $pending+='Contagem Blocker MQR ausente ou invalida.' }
    elseif ($blocker -gt 0) { $failures+='Ha issues Blocker.' }
    if ($null -eq $high) { $pending+='Contagem High MQR ausente ou invalida.' }
    elseif ($high -gt 0) { $failures+='Ha issues High.' }
    if ($null -eq $issues) { $pending+='Total de issues ausente ou invalido.' }
    $comparison='PENDING'
    if ($Baseline -and $null -ne $issues) {
        $delta=$issues - $Baseline.TotalIssues; $comparison='COMPARED'
        if ($delta -gt 0) { $warnings+='Total de issues aumentou em relacao ao ANTES selecionado.' }
    }
    $status=if ($failures.Count) { 'FAIL' } elseif ($pending.Count) { 'UNVERIFIED' } elseif ($warnings.Count) { 'WARN' } else { 'PASS' }
    [pscustomobject]@{
        Policy='blocker-high-zero_coverage85-warning_issues-increase-warning-v1'
        Status=$status; Coverage=$coverage; CoverageWarningBelow=85; BlockerIssues=$blocker; HighIssues=$high; TotalIssues=$issues
        Warnings=@($warnings); Failures=@($failures); Pending=@($pending)
        BaselineComparison=$comparison; IssuesDelta=$delta
        BaselineRunId=$(if ($Baseline) { $Baseline.RunId } else { $null })
        BaselineResultPath=$(if ($Baseline) { $Baseline.ResultPath } else { $null })
        ComparisonLimit='Comparacao numerica de violations; nao verifica equivalencia dos perfis, regras ou exclusoes. Sem baseline, comparacao PENDING nao reprova os criterios disponiveis.'
    }
}

function Read-HarnessSonarBaseline {
    param([string]$Path, $Context, $Current)
    if (-not $Path) { return $null }
    # Caminho selecionado explicitamente; nunca descobrir a ultima coleta.
    $path=Resolve-HarnessPath $Path $Context.Root
    $base=Resolve-HarnessPath (Join-Path $Context.Root '.harness/sonar') $Context.Root
    if (-not $path.StartsWith($base + '\', [StringComparison]::OrdinalIgnoreCase) -or (Split-Path -Leaf $path) -cne 'result.json') { throw 'Escolha um result.json de .harness/sonar deste harness.' }
    $record=Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
    foreach ($field in @('Project','Source','ServerUrl','ProjectKey','BranchName','ScannerVersion','SettingsPath','ApplicationJavaHome')) {
        if (-not $record.PSObject.Properties[$field] -or [string]$record.$field -cne [string]$Current[$field]) { throw "Baseline incompativel no campo $field." }
    }
    if (($record.Profiles | ConvertTo-Json -Compress) -cne ($Current.Profiles | ConvertTo-Json -Compress)) { throw 'Baseline com perfis Maven diferentes.' }
    if ($record.Phase -cne 'ANTES' -or $record.AnalysisStatus -cne 'SUCCESS' -or $record.MetricsStatus -cne 'MATCHED' -or $record.InputsStatus -cne 'STABLE' -or $record.ScannerExitCode -ne 0) { throw 'Baseline deve ser uma coleta ANTES concluida e estavel.' }
    if (-not $record.AnalysisId -or -not $record.RunId -or [DateTimeOffset]::Parse($record.FinishedAtUtc) -ge [DateTimeOffset]::Parse($Current.StartedAtUtc)) { throw 'Baseline deve identificar uma analise anterior.' }
    $measurePath=Resolve-HarnessPath (Join-Path (Split-Path -Parent $path) 'measures.json') $Context.Root
    $measures=Get-Content -LiteralPath $measurePath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($measures.AnalysisId -cne $record.AnalysisId -or $measures.ProjectKey -cne $record.ProjectKey -or [string]$measures.BranchName -cne [string]$record.BranchName) { throw 'Metricas do baseline nao correspondem ao recibo.' }
    $total=Get-SonarMetricNumber $measures.Measures 'violations'
    if ($null -eq $total) { throw 'Baseline sem total de issues valido.' }
    [pscustomobject]@{RunId=$record.RunId; ResultPath=$path; TotalIssues=$total; ServerVersion=$record.ServerVersion}
}

Export-ModuleMember -Function Get-HarnessSonarCriteria, Read-HarnessSonarBaseline
