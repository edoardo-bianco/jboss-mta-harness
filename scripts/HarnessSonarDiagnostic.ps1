# Coleta e publicacao do diagnostico compartilhadas pelos produtores Sonar.
function Read-HarnessSonarDiagnostic {
    param($Settings, [Collections.IDictionary]$Result, [string]$Run)
    $ProjectKey=$Result.ProjectKey; $BranchName=$Result.BranchName
    $result.Stage='QUALITY_GATE'
    $gateReply=Invoke-SonarApiGet $settings.ServerUrl 'api/qualitygates/project_status' @{analysisId=$result.AnalysisId} -AuthScheme $settings.AuthScheme
    if ($gateReply.projectStatus.status -cnotin @('OK','ERROR','WARN','NONE')) { throw 'Quality Gate desconhecido.' }
    $result.QualityGateStatus=$gateReply.projectStatus.status
    Write-SonarJson (Join-Path $run 'quality-gate.json') @{AnalysisId=$result.AnalysisId; ProjectKey=$ProjectKey; Result=$gateReply.projectStatus}
    if ((Get-SonarApiField $gateReply.projectStatus 'conditions') -isnot [Array]) { throw 'Quality Gate incompleto.' }
    foreach ($condition in $gateReply.projectStatus.conditions) {
        foreach ($field in @('metricKey','comparator','status')) {
            if ([string]::IsNullOrWhiteSpace([string](Get-SonarApiField $condition $field))) { throw 'Condicao do Quality Gate incompleta.' }
        }
    }
    $gate=$gateReply
    $result.Stage='METRICS'
    Assert-SonarCurrentAnalysis $settings.ServerUrl $ProjectKey $BranchName $result.AnalysisId -AuthScheme $settings.AuthScheme
    $metrics=@('ncloc','coverage','duplicated_lines_density','violations','blocker_violations','critical_violations','bugs','vulnerabilities','code_smells','new_violations','new_coverage','new_duplicated_lines_density')
    $query=@{component=$ProjectKey; metricKeys=($metrics -join ',')}
    if ($BranchName) { $query.branch=$BranchName }
    $measures=Invoke-SonarApiGet $settings.ServerUrl 'api/measures/component' $query -AuthScheme $settings.AuthScheme
    if ($measures.component.key -cne $ProjectKey) { throw 'Metricas de outro projeto.' }
    # Consulta separada: servidores antigos podem recusar metricas MQR.
    # Critical no modo Standard nao e substituto automatico para High.
    $allMeasures=@($measures.component.measures)
    $severityMetrics=@('software_quality_blocker_issues','software_quality_high_issues')
    $query.metricKeys=$severityMetrics -join ','
    $severity=$null
    try { $severity=Invoke-SonarApiGet $settings.ServerUrl 'api/measures/component' $query -AuthScheme $settings.AuthScheme } catch { $severity=$null }
    if ($severity) {
        if ($severity.component.key -cne $ProjectKey) { throw 'Severidades de outro projeto.' }
        $allMeasures+=@($severity.component.measures)
    }
    $metrics+=$severityMetrics
    $result.Stage='ISSUES'
    $issueSnapshot=$null
    try { $issueSnapshot=Get-HarnessSonarIssues $settings.ServerUrl $ProjectKey $BranchName -AuthScheme $settings.AuthScheme }
    catch { Write-Host 'Issues nao verificadas: resposta incompleta, indisponivel ou limite de coleta excedido. Consulte a API corporativa.' }
    Assert-SonarCurrentAnalysis $settings.ServerUrl $ProjectKey $BranchName $result.AnalysisId -AuthScheme $settings.AuthScheme
    if ($issueSnapshot) {
        $issuePath=Join-Path $run 'issues.json'
        Write-SonarJson $issuePath @{AnalysisId=$result.AnalysisId; ServerUrl=$settings.ServerUrl; ProjectKey=$ProjectKey; BranchName=$BranchName; CollectedAtUtc=[DateTime]::UtcNow.ToString('o'); Snapshot=$issueSnapshot}
        $result.IssuesStatus='COMPLETE'
    }
    $result.MissingMetrics=@($metrics | Where-Object { $_ -cnotin @($allMeasures | ForEach-Object { $_.metric }) })
    Write-SonarJson (Join-Path $run 'measures.json') @{AnalysisId=$result.AnalysisId; ProjectKey=$ProjectKey; BranchName=$BranchName; CollectedAtUtc=[DateTime]::UtcNow.ToString('o'); Measures=$allMeasures; MissingMetrics=$result.MissingMetrics}
    $result.MetricsStatus='MATCHED'
    [pscustomobject]@{Gate=$gate;Measures=$allMeasures;Issues=$issueSnapshot}
}

function Publish-HarnessSonarDiagnostic {
    param($Project, [Collections.IDictionary]$Result, [string]$Run,
        [string]$ScannerLog, $Gate, $Criteria)
    $result.FinishedAtUtc=[DateTime]::UtcNow.ToString('o')
    $result.TechnicalStatus=if ($result.QualityGateStatus -ceq 'ERROR' -or $result.CriteriaStatus -ceq 'FAIL') { 'NON_COMPLIANT' }
        elseif ($result.Status -ceq 'SUCCEEDED') { 'COMPLIANT' } else { 'UNVERIFIED' }
    if ($result.ResultPath) {
        $result.DiagnosticPublished=$result.Stage -ceq 'COMPLETE' -and $result.IssuesStatus -ceq 'COMPLETE' -and $result.InputsStatus -ceq 'STABLE'
        Write-SonarJson (Join-Path $run 'resultado.json') $result
        $lines=@('# Coleta SonarQube', '', "Projeto: $($result.ProjectLabel)", "Estado declarado pelo operador: $($result.Phase)", "Inicio: $(Format-HarnessDate $result.StartedAtUtc)", "Servidor: $($result.ServerUrl)", "Chave: $($result.ProjectKey)", "AnalysisId: $($result.AnalysisId)", "Resultado da operacao: $($result.Status)", "Processamento: $($result.AnalysisStatus)", "Quality Gate do servidor: $($result.QualityGateStatus)", "Criterios do harness: $($result.CriteriaStatus)", "Metricas: $($result.MetricsStatus)", "[Dashboard]($($result.DashboardUrl))", '')
        $lines += @("Autenticacao da API: $($result.ApiAuthScheme)", "Autenticacao do scanner: $($result.ScannerAuthScheme)", '')
        $lines+=@("Resultado tecnico: $($result.TechnicalStatus)", "Issues: $($result.IssuesStatus)", "Log: $($result.LogLevel)", 'Decisao humana corrente: [parecer](../sonar-decisao.json), quando registrado. Gate e aceite sao independentes.', '')
        if ($gate) {
            $lines+=@('## Condicoes do Quality Gate corporativo', '', '| Metrica | Comparador | Limite | Valor | Estado |', '| --- | --- | --- | --- | --- |')
            foreach ($condition in $gate.projectStatus.conditions) {
                $cells=@(foreach ($field in @('metricKey','comparator','errorThreshold','actualValue','status')) {
                    [string]$value=Get-SonarApiField $condition $field
                    $value.Replace('|','&#124;').Replace('<','&lt;').Replace('>','&gt;') -replace '[\r\n]',' '
                })
                $lines+='| ' + ($cells -join ' | ') + ' |'
            }
            $lines+=@('', 'Condicoes e periodos em [Quality Gate](quality-gate.json); metricas new_* se referem ao New Code do servidor. Decisao local nao altera esse gate.', '')
        }
        if ($criteria) {
            $lines+=@('| Criterio | Valor | Regra |', '| --- | --- | --- |', "| Blocker | $($criteria.BlockerIssues) | Reprova acima de zero |", "| Critical | $($criteria.CriticalIssues) | Reprova acima de zero |", "| High | $($criteria.HighIssues) | Reprova acima de zero |", "| Cobertura global (%) | $($criteria.Coverage) | Minimo 80%; meta 85% |", "| Duplicidade global (%) | $($criteria.DuplicatedLinesDensity) | Maximo 5% |", "| Total de issues | $($criteria.TotalIssues) | Diferenca apenas informativa |", "| Issues abertas | $($criteria.OpenIssues) | Severidades e novas chaves em [issues](issues.json)/[criterios](criteria.json) |", '', "Comparacao por chave: $($criteria.BaselineComparison); diferenca de totais: $($criteria.IssuesDelta)", '')
            if ($criteria.BaselineResultPath -ieq $result.ResultPath) {
                $lines+='ANTES consumido antes da substituicao: analise '+$criteria.BaselineAnalysisId+'. Detalhes anteriores nao preservados; [resultado corrente](resultado.json) contem esta coleta.'
            } elseif ($criteria.BaselineResultPath) {
                $lines+=Get-HarnessSourceLink (Join-Path (Split-Path $result.ResultPath) 'RESUMO.md') $criteria.BaselineResultPath 'Evidencia ANTES selecionada'
            } else { $lines+='Referencia ANTES nao selecionada; comparacao pendente.' }
            foreach ($message in $criteria.Failures) { $lines+='REPROVADO: ' + $message }
            foreach ($message in $criteria.Warnings) { $lines+='AVISO: ' + $message }
            foreach ($message in $criteria.Pending) { $lines+='PENDENTE: ' + $message }
            $lines+=@('', $criteria.ComparisonLimit)
        }
        $summaryPath=Join-Path (Split-Path $result.ResultPath) 'RESUMO.md'
        $lines+=@('', (Get-HarnessSourceLink $summaryPath $project.Pom 'POM local'), (Get-HarnessSourceLink $summaryPath $project.Source 'Source local'), '[Resultado](resultado.json) | [Metricas](measures.json) | [Issues](issues.json) | [Criterios](criteria.json)', 'Campos ausentes nao equivalem a zero. ANTES/DEPOIS e declaracao do operador.', 'O scanner nao gera cobertura: importe o XML JaCoCo produzido pelos testes. Esta coleta nao comprova WAR/runtime, GO ou aceite humano.', "Erro: $($result.Error)")
        $summary=$lines -join "`r`n"
        [IO.File]::WriteAllText((Join-Path $run 'RESUMO.md'), (Protect-SonarText $summary), (New-Object Text.UTF8Encoding($false)))
        $writes=@{}
        if ($result.DiagnosticPublished) {
            foreach ($name in @('resultado.json','quality-gate.json','measures.json','issues.json','criteria.json','RESUMO.md')) {
                $writes['atual/diagnosticos/sonar/'+$name]=[IO.File]::ReadAllText((Join-Path $run $name))
            }
        }
        $writes['atual/diagnosticos/sonar-tentativa.json']=[IO.File]::ReadAllText((Join-Path $run 'resultado.json'))
        $writes['atual/diagnosticos/sonar-console.log']=if (Test-Path -LiteralPath $scannerLog -PathType Leaf) { Protect-SonarText ([IO.File]::ReadAllText($scannerLog)) } else { [string]$result.Error }
        $operationStatus=if ($result.DiagnosticPublished) { 'SUCCEEDED' } else { 'FAILED' }
        $operationError=if ($result.DiagnosticPublished) { $null } else { 'Coleta incompleta; ultimo diagnostico utilizavel preservado. '+$result.Error }
        Set-HarnessProjectOperation $project 'sonar' $operationStatus -ErrorMessage $operationError -LogPath $result.LogPath -Files $writes
        Remove-HarnessProjectTemporary $project 'sonar'
    }
}
