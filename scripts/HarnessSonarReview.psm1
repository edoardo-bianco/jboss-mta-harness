#requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'Harness.psm1') -DisableNameChecking
Import-Module (Join-Path $PSScriptRoot 'HarnessProject.psm1') -DisableNameChecking
Import-Module (Join-Path $PSScriptRoot 'HarnessSonarCriteria.psm1') -DisableNameChecking

function Get-HarnessSonarReview {
    param([string]$Root, [string]$ResultPath)
    if ([string]::IsNullOrWhiteSpace($ResultPath)) { throw 'Informe o resultado.json Sonar corrente do projeto.' }
    $path=Resolve-HarnessPath $ResultPath $Root
    $base=Resolve-HarnessPath (Join-Path $Root '.harness/projetos') $Root
    if (-not $path.StartsWith($base+'\',[StringComparison]::OrdinalIgnoreCase) -or
        $path.Substring($base.Length+1) -notmatch '^[^\\]+\\atual\\diagnosticos\\sonar\\resultado\.json$') { throw 'Escolha o resultado Sonar corrente em .harness/projetos/<artifactId>/atual/diagnosticos/sonar/resultado.json.' }
    $name=$path.Substring($base.Length+1).Split('\')[0]
    $association=Get-Content -LiteralPath (Join-Path $base ($name+'/projeto.json')) -Raw -Encoding UTF8 | ConvertFrom-Json
    $project=Get-HarnessProjectStorage $Root $association.pom
    if ($project.Folder -ine (Join-Path $base $name)) { throw 'Associacao do POM diverge da pasta Sonar.' }
    $prefix='atual/diagnosticos/sonar/'
    $decisionPath='atual/diagnosticos/sonar-decisao.json'
    $documents=Read-HarnessProjectFiles $project @($prefix+'resultado.json'; $prefix+'quality-gate.json'; $prefix+'measures.json'; $prefix+'issues.json'; $prefix+'criteria.json'; $prefix+'RESUMO.md'; $decisionPath; 'atual/operacao.json')
    $data=@{}
    foreach ($file in @('resultado.json','quality-gate.json','measures.json','issues.json','criteria.json')) {
        if (-not $documents[$prefix+$file]) { throw "Diagnostico Sonar corrente incompleto: $file ausente. Confira a ultima tentativa; nenhum legado sera procurado." }
        $data[$file]=ConvertFrom-Json $documents[$prefix+$file]
    }
    $result=$data['resultado.json']; $gate=$data['quality-gate.json']; $measures=$data['measures.json']; $issues=$data['issues.json']; $criteria=$data['criteria.json']
    foreach ($field in @('Source','ProjectKey','ServerUrl','AnalysisId','Status','QualityGateStatus','CriteriaStatus')) {
        if (-not $result.PSObject.Properties[$field] -or [string]::IsNullOrWhiteSpace([string]$result.$field)) { throw 'Resultado Sonar incompleto.' }
    }
    foreach ($entry in @($gate,$measures,$issues,$criteria)) {
        if ($entry.AnalysisId -cne $result.AnalysisId -or $entry.ProjectKey -cne $result.ProjectKey) { throw 'Dados Sonar de outra analise/projeto; preserve os arquivos e refaca a coleta.' }
    }
    if ($issues.ServerUrl -cne $result.ServerUrl -or [string]$issues.BranchName -cne [string]$result.BranchName -or
        [string]$measures.BranchName -cne [string]$result.BranchName -or [string]$criteria.BranchName -cne [string]$result.BranchName -or
        $issues.Snapshot.Status -cne 'COMPLETE' -or $issues.Snapshot.Filter -cne 'resolved=false' -or $issues.Snapshot.Issues -isnot [Array] -or $issues.Snapshot.Count -ne $issues.Snapshot.Issues.Count -or
        $gate.Result.status -cnotin @('OK','ERROR','WARN','NONE') -or $gate.Result.conditions -isnot [Array]) { throw 'Dados Sonar incompletos ou de outra origem.' }
    $keys=New-Object 'Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
    foreach ($issue in $issues.Snapshot.Issues) {
        if ($issue.key -isnot [string] -or -not $issue.key -or $issue.project -cne $result.ProjectKey -or -not $keys.Add($issue.key)) { throw 'Identidade das issues Sonar invalida.' }
    }
    # Recalcular criterios locais. ANTES/DEPOIS continua sendo a comparacao
    # declarada na coleta, sem eleger outra referencia por recencia.
    $evaluation=Get-HarnessSonarCriteria -Measures $measures.Measures -IssueSnapshot $issues.Snapshot
    $assessment=[ordered]@{
        Source=$result.Source;ProjectKey=$result.ProjectKey;ServerUrl=$result.ServerUrl;BranchName=$result.BranchName;AnalysisId=$result.AnalysisId
        Phase=$result.Phase;DeclaredStatus=$result.Status;DeclaredCriteriaStatus=$result.CriteriaStatus;CollectedCriteriaStatus=$criteria.Evaluation.Status
        QualityGate=$gate.Result;Policy=$evaluation.Policy;LocalCriteriaStatus=$evaluation.Status
        Coverage=$evaluation.Coverage;DuplicatedLinesDensity=$evaluation.DuplicatedLinesDensity;TotalIssues=$evaluation.TotalIssues
        BlockerIssues=$evaluation.BlockerIssues;CriticalIssues=$evaluation.CriticalIssues;HighIssues=$evaluation.HighIssues
        SevereIssueKeys=$evaluation.SevereIssueKeys;BaselineComparison=$criteria.Evaluation.BaselineComparison
        BaselineAnalysisId=$criteria.Evaluation.BaselineAnalysisId;NewIssueKeys=$criteria.Evaluation.NewIssueKeys
        OpenIssueKeys=@($issues.Snapshot.Issues | ForEach-Object { $_.key } | Sort-Object -CaseSensitive)
    }
    $current=$null; $needsReview=$false
    if ($documents[$decisionPath]) {
        $current=ConvertFrom-Json $documents[$decisionPath]
        if ($current.Decision -cnotin @('CorrigirAgora','RegistrarParaDepois','Interromper') -or
            ($current.Decision -ceq 'RegistrarParaDepois' -and ([string]::IsNullOrWhiteSpace($current.Note) -or [string]::IsNullOrWhiteSpace($current.ReviewWhen)))) { throw 'Decisao Sonar invalida; preserve o texto e corrija motivo/gatilho.' }
        $needsReview=(ConvertTo-Json -InputObject $current.Assessment -Depth 20 -Compress) -cne (ConvertTo-Json -InputObject $assessment -Depth 20 -Compress)
    }
    if ($result.Source -ine $project.Source -or $result.QualityGateStatus -cne $gate.Result.status) { $needsReview=$true }
    $operation=$null
    if ($documents['atual/operacao.json']) {
        $operations=ConvertFrom-Json $documents['atual/operacao.json']
        if ($operations.PSObject.Properties['sonar']) { $operation=$operations.sonar }
    }
    [pscustomobject]@{Project=$project;ResultPath=$path;Result=$result;Documents=$documents;Assessment=$assessment;Evaluation=$evaluation
        DecisionPath=(Join-Path $project.Folder $decisionPath);Current=$current;NeedsReview=$needsReview;Operation=$operation
        Summary=$documents[$prefix+'RESUMO.md'];Decision=$(if ($current -and -not $needsReview) { $current.Decision } else { 'PENDING' })}
}

function Save-HarnessSonarDecision {
    param([string]$Root, [string]$ResultPath,
        [Parameter(Mandatory=$true)][ValidateSet('CorrigirAgora','RegistrarParaDepois','Interromper')][string]$Decision,
        [ValidateLength(0,4000)][string]$Note, [ValidateLength(0,1000)][string]$ReviewWhen,
        [Collections.IDictionary]$ExpectedDocuments)
    if ($Decision -ceq 'RegistrarParaDepois' -and ([string]::IsNullOrWhiteSpace($Note) -or [string]::IsNullOrWhiteSpace($ReviewWhen))) { throw 'Informe motivo e momento/gatilho de revisao do adiamento.' }
    $state=Get-HarnessSonarReview $Root $ResultPath
    $lock=Enter-HarnessProjectAccess $state.Project -ForOperation
    try {
        $state=Get-HarnessSonarReview $Root $ResultPath
        if ($null -eq $ExpectedDocuments) { $ExpectedDocuments=$state.Documents }
        $entry=[ordered]@{
            RecordedAtUtc=[DateTime]::UtcNow.ToString('o');Decision=$Decision;Note=$Note;ReviewWhen=$ReviewWhen
            Assessment=$state.Assessment
            Scope='Decisao de continuidade local para estes criterios; nao altera Quality Gate, nao concede GO, aceite ou dispensa corporativa.'
        }
        Publish-HarnessProjectFiles $state.Project @{'atual/diagnosticos/sonar-decisao.json'=($entry | ConvertTo-Json -Depth 20)} $ExpectedDocuments
    } finally { $lock.ReleaseMutex(); $lock.Dispose() }
    Get-HarnessSonarReview $Root $ResultPath
}

function Show-HarnessSonarReview {
    param([string]$Root, [string]$ResultPath)
    $state=Get-HarnessSonarReview $Root $ResultPath
    Write-Host "Projeto: $($state.Result.ProjectKey) | Source: $($state.Result.Source)"
    Write-Host "Diagnostico: $($state.Result.Status) | Gate corporativo: $($state.Result.QualityGateStatus) | Criterios na coleta: $($state.Result.CriteriaStatus)"
    if ($state.Operation -and $state.Operation.Status -ne 'SUCCEEDED') { Write-Warning "Ultima operacao Sonar: $($state.Operation.Status). $($state.Operation.Error). Exibindo o ultimo diagnostico utilizavel." }
    if ($state.Summary) { Write-Host $state.Summary }
    Write-Host "Criterios locais recalculados: $($state.Evaluation.Status); comparacao ANTES/DEPOIS permanece a declarada na coleta."
    Write-Host "Decisao vigente: $($state.Decision)"
    if ($state.Current) { Write-Host "Escolha registrada: $($state.Current.Decision) | Motivo: $($state.Current.Note) | Rever: $($state.Current.ReviewWhen)" }
    if ($state.NeedsReview) { Write-Warning 'Dados relevantes mudaram. Justificativa preservada; reavalie a decisao.' }
    Write-Host 'A escolha registra continuidade local; nao muda o gate nem autoriza executar corretivas.'
    $choice=Read-Host '1 Corrigir agora; 2 Registrar para depois e continuar outras atividades; 3 Interromper; Enter conserva o registro'
    $decision=switch ($choice) { '1' { 'CorrigirAgora' } '2' { 'RegistrarParaDepois' } '3' { 'Interromper' } '' { return $state } default { throw 'Opcao invalida; nenhuma decisao registrada.' } }
    $note=Read-Host 'Motivo/observacao (obrigatorio para adiar; sem credenciais)'
    $when=''
    if ($decision -ceq 'RegistrarParaDepois') { $when=Read-Host 'Quando rever: data, lote ou gatilho (obrigatorio)' }
    $state=Save-HarnessSonarDecision $Root $ResultPath $decision -Note $note -ReviewWhen $when -ExpectedDocuments $state.Documents
    Write-Host "Decisao salva em: $($state.DecisionPath)"
    if ($decision -ceq 'CorrigirAgora') { Write-Host 'Proximo passo: vincular estas evidencias a issue/registro e usar Planejamento: planejar; revisao/GO e implementacao sao etapas separadas.' }
    if ($decision -ceq 'RegistrarParaDepois') { Write-Host "Lembrete local para a retomada: $when. Vincule este diagnostico ao registro/plano. Nao ha agendamento automatico." }
    $state
}

Export-ModuleMember -Function Get-HarnessSonarReview, Save-HarnessSonarDecision, Show-HarnessSonarReview
