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
    param([object[]]$Measures, $Baseline=$null, $IssueSnapshot=$null,
        [ValidateSet('ANTES','DEPOIS')][string]$Phase='ANTES')
    $coverage=Get-SonarMetricNumber $Measures 'coverage' -Coverage
    $duplication=Get-SonarMetricNumber $Measures 'duplicated_lines_density' -Coverage
    $issues=Get-SonarMetricNumber $Measures 'violations'
    $warnings=@(); $failures=@(); $pending=@(); $delta=$null
    if ($null -eq $coverage) { $pending+='Cobertura ausente ou invalida.' }
    elseif ($coverage -lt 80) { $failures+='Cobertura abaixo do minimo de 80%.' }
    elseif ($coverage -lt 85) { $warnings+='Cobertura atende 80%, mas esta abaixo da meta de 85%.' }
    if ($null -eq $duplication) { $pending+='Duplicidade ausente ou invalida.' }
    elseif ($duplication -gt 5) { $failures+='Duplicidade acima do maximo de 5%.' }
    $blocker=$null; $critical=$null; $high=$null; $openCount=$null; $severeKeys=$null; $newKeys=$null
    $complete=$IssueSnapshot -and $IssueSnapshot.Status -ceq 'COMPLETE'
    if ($complete) {
        $blocker=0; $critical=0; $high=0; $severeKeys=@(); $openCount=@($IssueSnapshot.Issues).Count
        foreach ($issue in $IssueSnapshot.Issues) {
            $severity=[string]$issue.severity
            $impacts=@($issue.impacts | ForEach-Object { $_.severity })
            if ($severity -ceq 'BLOCKER' -or $impacts -ccontains 'BLOCKER') { $blocker++ }
            if ($severity -ceq 'CRITICAL') { $critical++ }
            if ($impacts -ccontains 'HIGH') { $high++ }
            if ($severity -cin @('BLOCKER','CRITICAL') -or $impacts -ccontains 'HIGH' -or $impacts -ccontains 'BLOCKER') { $severeKeys+=$issue.key }
            if ($severity -cnotin @('BLOCKER','CRITICAL','MAJOR','MINOR','INFO') -and $impacts.Count -eq 0) { $pending+='Issue sem severidade reconhecida.' }
        }
        # O coletor ja valida chaves unicas, preservando maiusculas/minusculas.
        if ($severeKeys.Count) { $failures+='Ha issues abertas BLOCKER, CRITICAL ou HIGH.' }
    } else { $pending+='Lista completa de issues abertas indisponivel; severidades e novas issues nao verificadas.' }
    $comparison='PENDING'
    if ($Baseline -and $null -ne $issues) {
        $delta=$issues - $Baseline.TotalIssues
    }
    if ($Baseline -and $complete -and $null -ne $Baseline.Issues) {
        $keys=New-Object 'Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
        foreach ($old in $Baseline.Issues) { $null=$keys.Add([string]$old.key) }
        $newKeys=@($IssueSnapshot.Issues | Where-Object { -not $keys.Contains([string]$_.key) } | ForEach-Object { $_.key })
        $comparison='COMPARED'
        if ($newKeys.Count) { $failures+='Ha issues novas no conjunto aberto em relacao ao ANTES selecionado.' }
    } elseif ($Baseline -or $Phase -ceq 'DEPOIS') {
        $pending+='Comparacao por chave pendente: informe um ANTES com lista completa de issues.'
    }
    $status=if ($failures.Count) { 'FAIL' } elseif ($pending.Count) { 'UNVERIFIED' } elseif ($warnings.Count) { 'WARN' } else { 'PASS' }
    [pscustomobject]@{
        Policy='open-severe-new-zero_coverage80-goal85_duplication5-v2'
        Status=$status; Coverage=$coverage; MinimumCoverage=80; CoverageWarningBelow=85
        DuplicatedLinesDensity=$duplication; MaximumDuplication=5
        BlockerIssues=$blocker; CriticalIssues=$critical; HighIssues=$high; TotalIssues=$issues; OpenIssues=$openCount
        SevereIssueKeys=$severeKeys; SevereIssues=$(if ($null -ne $severeKeys) { $severeKeys.Count } else { $null }); NewIssueKeys=$newKeys
        Warnings=@($warnings); Failures=@($failures); Pending=@($pending)
        BaselineComparison=$comparison; IssuesDelta=$delta
        BaselineRunId=$(if ($Baseline) { $Baseline.RunId } else { $null })
        BaselineResultPath=$(if ($Baseline) { $Baseline.ResultPath } else { $null })
        ComparisonLimit='Novas no conjunto aberto por chave podem incluir reaberturas ou mudancas de regras; nao comprovam causa no codigo. New Code do servidor e separado. Perfis, exclusoes e conteudo precisam de conferencia. ANTES sem baseline inicia a referencia; DEPOIS sem lista comparavel fica pendente.'
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
    $issues=$null
    if ($record.PSObject.Properties['IssuesStatus'] -and $record.IssuesStatus -ceq 'COMPLETE') {
        $issuePath=Resolve-HarnessPath (Join-Path (Split-Path -Parent $path) 'issues.json') $Context.Root
        if (-not $record.PSObject.Properties['IssuesSha256'] -or (Get-FileHash -LiteralPath $issuePath -Algorithm SHA256).Hash -cne $record.IssuesSha256) { throw 'Hash das issues do baseline divergente.' }
        $saved=Get-Content -LiteralPath $issuePath -Raw -Encoding UTF8 | ConvertFrom-Json
        foreach ($field in @('RunId','AnalysisId','ServerUrl','ProjectKey','BranchName')) {
            if ([string]$saved.$field -cne [string]$record.$field) { throw 'Issues do baseline nao correspondem ao recibo.' }
        }
        if ($saved.Snapshot.Status -cne 'COMPLETE' -or $saved.Snapshot.Filter -cne 'resolved=false' -or $saved.Snapshot.Issues -isnot [Array] -or $saved.Snapshot.Count -ne $saved.Snapshot.Issues.Count) { throw 'Lista de issues do baseline incompleta.' }
        $keys=New-Object 'Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
        foreach ($issue in $saved.Snapshot.Issues) {
            if ($issue.key -isnot [string] -or -not $issue.key -or $issue.project -cne $record.ProjectKey -or -not $keys.Add($issue.key)) { throw 'Identidade das issues do baseline invalida.' }
        }
        $issues=$saved.Snapshot.Issues
    }
    [pscustomobject]@{RunId=$record.RunId; ResultPath=$path; TotalIssues=$total; ServerVersion=$record.ServerVersion; Issues=$issues}
}

Export-ModuleMember -Function Get-HarnessSonarCriteria, Read-HarnessSonarBaseline
