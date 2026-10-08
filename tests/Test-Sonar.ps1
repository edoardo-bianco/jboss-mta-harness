#requires -Version 5.1
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $root 'scripts/Harness.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $root 'scripts/HarnessSonar.psm1') -Force -DisableNameChecking
function Assert($condition, $message) { if (-not $condition) { throw $message } }
$area = Join-Path $root ('.harness/tests/sonar-' + [guid]::NewGuid().ToString('N'))
$fixture = Join-Path $area 'harness'
$app = Join-Path $area 'app com espaco'
foreach ($dir in @($app, "$area/jdk8/bin", "$area/jdk21/bin", "$area/maven/bin")) { $null = New-Item -ItemType Directory -Path $dir -Force }
foreach ($file in @("$app/pom.xml", "$area/jdk8/bin/java.exe", "$area/jdk21/bin/java.exe", "$area/maven/bin/mvn.cmd")) { Set-Content -LiteralPath $file -Value '' }
$config = Get-Content (Join-Path $root 'config/harness.example.json') -Raw | ConvertFrom-Json
$config.repositories = @(@{name='app'; path=$app}); $config.activeProject = 'app'
$config.tools.applicationJdk8Home = "$area/jdk8"
$config.tools.applicationMavenHome = "$area/maven"
$config.sonar.serverUrl = 'http://localhost:9000'
$config.sonar.scannerJdkHome = "$area/jdk21"
Write-HarnessJson "$fixture/config.json" $config
$context = Read-HarnessConfig "$fixture/config.json" $fixture
$context.Config.sonar.PSObject.Properties.Remove('apiAuthScheme')
$module = Get-Module HarnessSonar
# Executar o wrapper nativo com credencial sintetica e saida hostil, antes dos mocks.
$native = Join-Path $area 'scanner simulado.cmd'
$nativeBasic = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes('synthetic-native-token-123456789:'))
[IO.File]::WriteAllText($native, "@echo off`r`necho token=%SONAR_TOKEN%`r`necho Authorization: Basic $nativeBasic`r`nexit /b 9`r`n")
$savedNativeToken = $env:SONAR_TOKEN
try {
    $env:SONAR_TOKEN='synthetic-native-token-123456789'
    $nativeLog=Join-Path $area 'scanner-debug.log'
    $captured = @(& $module { param($file,$log) Invoke-SonarTool $file @() -LogPath $log } $native $nativeLog 6>&1)
    Assert ($captured[-1].ExitCode -eq 9) 'Wrapper perdeu exit code nativo.'
    Assert (-not (($captured | Out-String).Contains($env:SONAR_TOKEN))) 'Wrapper exibiu token no terminal.'
    Assert (-not (($captured | Out-String).Contains($nativeBasic))) 'Wrapper exibiu credencial Basic no terminal.'
    Assert (($captured | Out-String).Contains('[REDACTED]')) 'Wrapper nao mascarou saida.'
    $savedLog=Get-Content -Raw $nativeLog
    Assert ($savedLog.Contains('[REDACTED]') -and -not $savedLog.Contains($env:SONAR_TOKEN) -and -not $savedLog.Contains($nativeBasic)) 'Token persistido no log.'
} finally { $env:SONAR_TOKEN=$savedNativeToken }
& $module {
    $script:Mode = 'OK'; $script:Calls = @(); $script:MetricReads=0; $script:ApiCalls=@(); $script:JavaVersion='21.0.1'
    function script:Invoke-SonarTool {
        param($Executable, $Arguments, $ScannerAuthScheme, $LogPath)
        $script:Calls += [pscustomobject]@{Args=$Arguments; Java=$env:JAVA_HOME; Token=$env:SONAR_TOKEN; Cwd=(Get-Location).Path; MavenArgs=$env:MAVEN_ARGS; AuthScheme=$ScannerAuthScheme; Legacy=$env:SONARQUBE_SCANNER_PARAMS}
        if ($Arguments -contains '-version') { return [pscustomobject]@{ExitCode=0; Output=('java version "' + $script:JavaVersion + '"')} }
        if ($Arguments -contains '--version') { return [pscustomobject]@{ExitCode=0; Output="Apache Maven 3.9.16`nJava version: $script:JavaVersion"} }
        if ($script:Mode -eq 'MAVEN_FAIL') { return [pscustomobject]@{ExitCode=7; Output=$null} }
        $path = ($Arguments | Where-Object { $_ -like '-Dsonar.scanner.metadataFilePath=*' }).Substring(33)
        $server = 'http://localhost:9000'
        if ($script:Mode -eq 'WRONG_SERVER') { $server = 'https://wrong.example' }
        $branchArgument = @($Arguments | Where-Object { $_ -like '-Dsonar.branch.name=*' })
        $branchMetadata = if ($branchArgument.Count) { "`nbranch=" + $branchArgument[0].Substring('-Dsonar.branch.name='.Length) } else { '' }
        if ($script:Mode -eq 'WRONG_BRANCH') { $branchMetadata = "`nbranch=other" }
        [IO.File]::WriteAllText($path, "projectKey=team:app`nserverUrl=$server`nceTaskId=task-1`nceTaskUrl=$server/api/ce/task?id=task-1$branchMetadata")
        [pscustomobject]@{ExitCode=0; Output=$null}
    }
    function script:Invoke-SonarApiGet {
        param($ServerUrl, $Endpoint, $Query, $AuthScheme)
        $script:ApiCalls += [pscustomobject]@{Endpoint=$Endpoint; AuthScheme=$AuthScheme}
        if ($script:Mode -eq 'AUTH_FAIL') { throw 'SONAR_API_UNVERIFIED' }
        switch ($Endpoint) {
            'api/system/status' { [pscustomobject]@{status='UP'; version='2026.1'} }
            'api/components/show' { [pscustomobject]@{component=[pscustomobject]@{key='team:app'; qualifier='TRK'}} }
            'api/qualitygates/project_status' {
                if ($Query.analysisId -ne 'analysis-1') { throw 'Gate sem analysisId.' }
                $gate = if ($script:Mode -eq 'GATE_FAIL') { 'ERROR' } else { 'OK' }
                if ($script:Mode -eq 'BAD_GATE') { return [pscustomobject]@{projectStatus=[pscustomobject]@{status='ERROR'}} }
                [pscustomobject]@{projectStatus=[pscustomobject]@{status=$gate; conditions=@([pscustomobject]@{metricKey='new_coverage';comparator='LT';errorThreshold='90';actualValue='81';status=$gate})}}
            }
            'api/project_analyses/search' {
                $id = if ($script:Mode -eq 'RACE' -or ($script:Mode -eq 'RACE_AFTER' -and $script:MetricReads -gt 0)) { 'other-analysis' } else { 'analysis-1' }
                [pscustomobject]@{analyses=@([pscustomobject]@{key=$id})}
            }
            'api/ce/component' { [pscustomobject]@{queue=@()} }
            'api/measures/component' {
                $script:MetricReads++
                if ($script:Mode -eq 'NO_MQR' -and $Query.metricKeys -match 'software_quality') { throw 'Metricas indisponiveis.' }
                $values=@{coverage='86.0'; duplicated_lines_density='5'; violations='2'; software_quality_blocker_issues='0'; software_quality_high_issues='0'}
                if ($script:Mode -eq 'LOW_COVERAGE') { $values.coverage='84.9' }
                if ($script:Mode -eq 'HIGH') { $values.software_quality_high_issues='1' }
                if ($script:Mode -eq 'INCREASE') { $values.violations='3' }
                $data=@($Query.metricKeys.Split(',') | Where-Object { $values.ContainsKey($_) } | ForEach-Object { [pscustomobject]@{metric=$_; value=$values[$_]} })
                [pscustomobject]@{component=[pscustomobject]@{key='team:app'; measures=$data}}
            }
            'api/issues/search' {
                if ($script:Mode -eq 'ISSUES_FAIL') { throw 'Indisponivel' }
                $keys=@('old-1','old-2')
                if ($script:Mode -eq 'EMPTY') { $keys=@() }
                if ($script:Mode -eq 'INCREASE') { $keys+= 'new-3' }
                if ($script:Mode -eq 'SWAP') { $keys=@('old-1','new-3') }
                $items=@($keys | ForEach-Object {
                    $impacts=@(); $severity='MAJOR'
                    if ($script:Mode -eq 'HIGH') { $impacts=@([pscustomobject]@{severity='HIGH';softwareQuality='SECURITY'}) }
                    if ($script:Mode -eq 'CRITICAL') { $severity='CRITICAL' }
                    [pscustomobject]@{key=$_;project='team:app';component='team:app:A.java';rule='java:S1';severity=$severity;impacts=$impacts;message='Corrigir';line=12}
                })
                [pscustomobject]@{paging=[pscustomobject]@{pageIndex=1;pageSize=100;total=$items.Count};issues=$items;components=@([pscustomobject]@{key='team:app:A.java';path='src/A.java'})}
            }
            default { throw "API inesperada: $Endpoint" }
        }
    }
    function script:Wait-SonarComputeEngine {
        param($ServerUrl, $TaskId, $ProjectKey, $BranchName, $TimeoutSeconds, $AuthScheme)
        $script:ApiCalls += [pscustomobject]@{Endpoint='api/ce/task'; AuthScheme=$AuthScheme}
        if ($script:Mode -eq 'CE_FAIL') { throw 'SONAR_CE_UNVERIFIED' }
        [pscustomobject]@{TaskId=$TaskId; AnalysisId='analysis-1'}
    }
}
$oldToken = $env:SONAR_TOKEN; $oldJava = $env:JAVA_HOME; $oldArgs = $env:MAVEN_ARGS; $oldLegacy = $env:SONARQUBE_SCANNER_PARAMS
$secret = 'squ_TEST_ONLY_do_not_persist_987654321'
$secure = ConvertTo-SecureString $secret -AsPlainText -Force
try {
    $env:SONAR_TOKEN = 'previous-token'; $env:MAVEN_ARGS = 'deploy'
    $env:SONARQUBE_SCANNER_PARAMS = '{"sonar.token":"previous-legacy-token"}'
    $result = Invoke-HarnessSonar $context 'team:app' -Phase ANTES -Token $secure
    Assert ($result.Status -eq 'SUCCEEDED' -and $result.QualityGateStatus -eq 'OK' -and $result.MetricsStatus -eq 'MATCHED') 'Analise simulada deveria concluir.'
    Assert ($result.CriteriaStatus -eq 'PASS' -and $result.BaselineComparison -eq 'PENDING') 'Criterios devem ser avaliados separadamente.'
    Assert ($result.Project -eq 'app' -and $result.AnalysisId -eq 'analysis-1' -and $result.Phase -eq 'ANTES') 'Identidade perdida.'
    Assert ($result.MissingMetrics -contains 'ncloc') 'Metrica ausente deve ficar explicita.'
    $apiCalls=@(& $module { $script:ApiCalls })
    Assert ($result.ApiAuthScheme -ceq 'Bearer' -and $apiCalls.Count -eq 11 -and @($apiCalls | Where-Object AuthScheme -cne 'Bearer').Count -eq 0) 'Configuracao antiga deve manter Bearer em todas as consultas.'
    $run = Split-Path -Parent $result.ResultPath
    Assert ((Split-Path -Leaf $run) -match '^sonar_.*__[a-f0-9]{12}$') 'Convencao de pastas perdida.'
    $calls = @(& $module { $script:Calls }); $scan = $calls[-1]
    Assert ($scan.Args -notcontains '-X' -and $scan.Args -contains '-Dsonar.verbose=false' -and $scan.Args -contains '-Dsonar.log.level=INFO') 'Padrao deve ser INFO.'
    Assert ($result.LogLevel -ceq 'INFO' -and $result.LogPath.EndsWith('scanner-info.log') -and $result.IssuesStatus -ceq 'COMPLETE') 'Nivel/log/issues ausentes no recibo.'
    Assert (($scan.Args -join ' ') -notmatch 'sonar.token|sonar.login|squ_TEST') 'Token enviado por argumento.'
    Assert ($scan.Token -eq $secret -and -not $scan.MavenArgs -and $scan.Java -eq (Resolve-HarnessPath "$area/jdk21" $root)) 'Ambiente do scanner incorreto.'
    Assert ($scan.AuthScheme -ceq 'Bearer' -and -not $scan.Legacy -and $result.ScannerAuthScheme -ceq 'Bearer') 'Scanner legado deve manter Bearer sem herdar JSON externo.'
    Assert ($scan.Args -contains ('-Dsonar.java.jdkHome=' + $context.Config.tools.applicationJdk8Home)) 'Java da aplicacao nao foi informado.'
    Assert ($env:SONAR_TOKEN -eq 'previous-token' -and $env:JAVA_HOME -eq $oldJava -and $env:MAVEN_ARGS -eq 'deploy') 'Ambiente nao restaurado.'
    $hash = (Get-FileHash $result.ResultPath).Hash
    foreach ($authScheme in @('Basic','Bearer')) {
        $context.Config.sonar | Add-Member -NotePropertyName apiAuthScheme -NotePropertyValue $authScheme -Force
        & $module { $script:ApiCalls=@(); $script:MetricReads=0 }
        $authenticated=Invoke-HarnessSonar $context 'team:app' -BranchName develop -Phase ANTES -Token $secure
        $apiCalls=@(& $module { $script:ApiCalls })
        Assert ($authenticated.Status -eq 'SUCCEEDED' -and $authenticated.ApiAuthScheme -ceq $authScheme) 'Modo explicito nao concluiu coleta.'
        Assert ($apiCalls.Count -eq 11 -and @($apiCalls | Where-Object AuthScheme -cne $authScheme).Count -eq 0) 'Esquema nao propagado a todas as consultas (CE, gate, metricas e correlacao).'
        $record=Get-Content -Raw $authenticated.ResultPath | ConvertFrom-Json
        Assert ($record.ApiAuthScheme -ceq $authScheme) 'Esquema nao registrado no recibo.'
        Assert ($record.ScannerAuthScheme -ceq $authScheme) 'Esquema do scanner nao registrado no recibo.'
        Assert ($record.TaskId -ceq 'task-1' -and $record.AnalysisId -ceq 'analysis-1') 'Metadados com branch nao chegaram ao CE.'
        Assert ($record.DashboardUrl -ceq 'http://localhost:9000/dashboard?id=team%3Aapp&branch=develop') 'Dashboard/branch nao sobreviveu ao JSON.'
        $summary=Get-Content -Raw (Join-Path (Split-Path $authenticated.ResultPath) 'RESUMO.md')
        Assert ($summary.Contains('Autenticacao da API: ' + $authScheme)) 'Esquema nao registrado no resumo.'
        Assert ($summary.Contains('Autenticacao do scanner: ' + $authScheme)) 'Esquema do scanner nao registrado no resumo.'
        $scan=@(& $module { $script:Calls })[-1]
        Assert ($scan.AuthScheme -ceq $authScheme) 'Escolha de autenticacao nao chegou ao launcher Maven.'
        Assert ($scan.Args -contains '-Dsonar.branch.name=develop' -and ($scan.Args -join ' ') -notmatch 'sonar.token|sonar.login|squ_TEST') 'Branch/token incorretos no scanner.'
    }
    & $module { $script:Mode='WRONG_BRANCH'; $script:ApiCalls=@() }
    $wrongBranch=Invoke-HarnessSonar $context 'team:app' -BranchName develop -Phase ANTES -Token $secure
    Assert ($wrongBranch.Status -eq 'FAILED' -and $wrongBranch.Stage -eq 'COMPUTE_ENGINE' -and $null -eq $wrongBranch.TaskId) 'Metadados de outra branch foram aceitos.'
    Assert (@(& $module { $script:ApiCalls | Where-Object Endpoint -eq 'api/ce/task' }).Count -eq 0) 'Metadados divergentes chegaram ao CE.'
    & $module { $script:Mode='OK' }
    foreach ($invalidScheme in @($null, '', 'Digest', @('Basic'), 1)) {
        $context.Config.sonar.apiAuthScheme=$invalidScheme
        $callsBefore=@(& $module { $script:Calls }).Count
        $apiBefore=@(& $module { $script:ApiCalls }).Count
        $invalidRejected=$false
        try { $null=Invoke-HarnessSonar $context 'team:app' -Token $secure }
        catch { $invalidRejected=$_.Exception.Message -ceq 'sonar.apiAuthScheme deve ser Bearer ou Basic.' }
        Assert ($invalidRejected -and @(& $module { $script:Calls }).Count -eq $callsBefore -and @(& $module { $script:ApiCalls }).Count -eq $apiBefore) 'Esquema invalido nao recusado antes de processos/rede.'
    }
    $context.Config.sonar.apiAuthScheme='Bearer'
    $context.Config.sonar.debug=$true
    $debugResult=Invoke-HarnessSonar $context 'team:app' -Token $secure
    $debugScan=@(& $module { $script:Calls })[-1]
    Assert ($debugScan.Args -contains '-X' -and $debugScan.Args -contains '-Dsonar.verbose=true' -and $debugScan.Args -contains '-Dsonar.log.level=DEBUG' -and $debugResult.LogPath.EndsWith('scanner-debug.log')) 'DEBUG explicito nao aplicado.'
    foreach ($invalidDebug in @('false',1,$null)) {
        $context.Config.sonar.debug=$invalidDebug; $rejected=$false
        try { $null=Get-HarnessSonarSettings $context } catch { $rejected=$true }
        Assert $rejected 'Debug nao booleano aceito.'
    }
    $context.Config.sonar.PSObject.Properties.Remove('debug')
    Assert (-not (Get-HarnessSonarSettings $context).Debug) 'Config antiga deve usar INFO.'
    foreach ($javaVersion in @('17.0.16','25.0.3','1.8.0_112')) {
        & $module { param($v) $script:JavaVersion=$v } $javaVersion
        $javaResult=Invoke-HarnessSonar $context 'team:app' -Token $secure
        if ($javaVersion -like '1.8*') { Assert ($javaResult.Stage -eq 'TOOLS' -and $javaResult.Status -eq 'FAILED' -and $null -eq $javaResult.ScannerExitCode) 'Java 8 deve parar antes do scanner.' }
        else { Assert ($javaResult.Status -eq 'SUCCEEDED') "Validacao do harness recusou Java $javaVersion." }
    }
    & $module { $script:JavaVersion='21.0.1' }
    foreach ($mode in @('HIGH','CRITICAL','LOW_COVERAGE','INCREASE','SWAP','NO_MQR','ISSUES_FAIL')) {
        & $module { param($m) $script:Mode=$m; $script:MetricReads=0 } $mode
        $next=Invoke-HarnessSonar $context 'team:app' -Phase DEPOIS -Token $secure -BaselineResultPath $result.ResultPath
        if ($mode -in @('HIGH','CRITICAL','INCREASE','SWAP')) { Assert ($next.Status -eq 'CRITERIA_FAILED' -and $next.CriteriaStatus -eq 'FAIL' -and $next.QualityGateStatus -eq 'OK') 'Severidade ou nova chave nao reprovou com gate OK.' }
        elseif ($mode -eq 'NO_MQR') { Assert ($next.Status -eq 'SUCCEEDED' -and $next.CriteriaStatus -eq 'PASS') 'Sonar Standard nao deve exigir metricas MQR.' }
        elseif ($mode -eq 'ISSUES_FAIL') { Assert ($next.Status -eq 'UNVERIFIED' -and $next.IssuesStatus -eq 'UNVERIFIED') 'Falha de issues virou zero.' }
        else { Assert ($next.Status -eq 'SUCCEEDED' -and $next.CriteriaStatus -eq 'WARN') 'Avisos nao devem reprovar.' }
        if ($mode -eq 'INCREASE') {
            $criteria=Get-Content -Raw (Join-Path (Split-Path $next.ResultPath) 'criteria.json') | ConvertFrom-Json
            Assert ($criteria.Evaluation.IssuesDelta -eq 1 -and $criteria.Evaluation.BaselineRunId -eq $result.RunId) 'Comparacao nao vinculou baseline.'
        }
    }
    foreach ($mode in @('GATE_FAIL','BAD_GATE','MAVEN_FAIL','AUTH_FAIL','CE_FAIL','WRONG_SERVER','RACE','RACE_AFTER')) {
        & $module { param($m) $script:Mode=$m; $script:MetricReads=0 } $mode
        $next = Invoke-HarnessSonar $context 'team:app' -Phase DEPOIS -Token $secure
        Assert ($next.Status -ne 'SUCCEEDED') "$mode virou sucesso."
        Assert ($next.ResultPath -ne $result.ResultPath) 'Historico sobrescrito.'
        if ($mode -eq 'GATE_FAIL') { Assert ($next.AnalysisStatus -eq 'SUCCESS' -and $next.QualityGateStatus -eq 'ERROR') 'Gate confundido com falha do scanner.' }
        if ($mode -eq 'BAD_GATE') { Assert ($next.Status -eq 'UNVERIFIED' -and $next.TechnicalStatus -eq 'NON_COMPLIANT' -and $next.QualityGateStatus -eq 'ERROR') 'Resposta incompleta apagou reprovacao corporativa comprovada.' }
        if ($mode -eq 'GATE_FAIL') {
            $summary=Get-Content -Raw (Join-Path (Split-Path $next.ResultPath) 'RESUMO.md')
            Assert ($summary.Contains('| new_coverage | LT | 90 | 81 | ERROR |')) 'Condicao corporativa nao foi preservada no resumo.'
        }
        if ($mode -like 'RACE*') { Assert ($next.MetricsStatus -eq 'UNVERIFIED' -and -not (Test-Path (Join-Path (Split-Path $next.ResultPath) 'measures.json'))) 'Metricas de outra analise exportadas.' }
    }
    Assert ((Get-FileHash $result.ResultPath).Hash -eq $hash) 'Recibo anterior alterado.'
    Assert ($env:SONARQUBE_SCANNER_PARAMS -ceq '{"sonar.token":"previous-legacy-token"}') 'Ambiente legado nao restaurado pelo fluxo.'
    & $module { $script:Mode='EMPTY'; $script:MetricReads=0 }
    $emptyBaseline=Invoke-HarnessSonar $context 'team:app' -Phase ANTES -Token $secure
    $emptyAfter=Invoke-HarnessSonar $context 'team:app' -Phase DEPOIS -Token $secure -BaselineResultPath $emptyBaseline.ResultPath
    Assert ($emptyAfter.Status -eq 'SUCCEEDED' -and $emptyAfter.BaselineComparison -eq 'COMPARED') 'Baseline com zero issues nao foi comparavel.'
    & $module { $script:Mode='OK'; $script:MetricReads=0 }
    # Baselines incompatíveis ou adulterados devem ser recusados antes do scanner.
    $badDir=Join-Path (Split-Path $run) 'baseline-invalido'
    $null=New-Item -ItemType Directory -Path $badDir
    foreach ($field in @('Source','ProjectKey','BranchName','ServerUrl','ScannerVersion','Phase','MetricsStatus','InputsStatus','FinishedAtUtc','MeasuresAnalysisId','TotalIssues','IssuesHash','IssuesIdentity')) {
        $record=Get-Content -Raw $result.ResultPath | ConvertFrom-Json
        $savedMeasures=Get-Content -Raw (Join-Path $run 'measures.json') | ConvertFrom-Json
        $savedIssues=Get-Content -Raw (Join-Path $run 'issues.json') | ConvertFrom-Json
        if ($field -eq 'MeasuresAnalysisId') { $savedMeasures.AnalysisId='other' }
        elseif ($field -eq 'TotalIssues') { ($savedMeasures.Measures | Where-Object metric -eq 'violations').value='invalid' }
        elseif ($field -eq 'FinishedAtUtc') { $record.FinishedAtUtc=[DateTime]::UtcNow.AddDays(1).ToString('o') }
        elseif ($field -in @('IssuesHash','IssuesIdentity')) { $savedIssues.AnalysisId='other' }
        else { $record.$field='other' }
        Write-HarnessJson (Join-Path $badDir 'issues.json') $savedIssues
        if ($field -eq 'IssuesIdentity') { $record.IssuesSha256=(Get-FileHash (Join-Path $badDir 'issues.json')).Hash }
        Write-HarnessJson (Join-Path $badDir 'result.json') $record
        Write-HarnessJson (Join-Path $badDir 'measures.json') $savedMeasures
        $callsBefore=@(& $module { $script:Calls }).Count
        $rejected=Invoke-HarnessSonar $context 'team:app' -Phase DEPOIS -Token $secure -BaselineResultPath (Join-Path $badDir 'result.json')
        Assert ($rejected.Status -eq 'FAILED' -and $rejected.Stage -eq 'BASELINE' -and @(& $module { $script:Calls }).Count -eq $callsBefore) "Baseline invalido aceito: $field"
    }
    $legacyRecord=Get-Content -Raw $result.ResultPath | ConvertFrom-Json
    $legacyRecord.PSObject.Properties.Remove('IssuesStatus'); $legacyRecord.PSObject.Properties.Remove('IssuesSha256')
    Write-HarnessJson (Join-Path $badDir 'result.json') $legacyRecord
    Copy-Item -LiteralPath (Join-Path $run 'measures.json') -Destination (Join-Path $badDir 'measures.json') -Force
    $legacyAfter=Invoke-HarnessSonar $context 'team:app' -Phase DEPOIS -Token $secure -BaselineResultPath (Join-Path $badDir 'result.json')
    Assert ($legacyAfter.CriteriaStatus -eq 'UNVERIFIED' -and $legacyAfter.BaselineComparison -eq 'PENDING') 'Recibo legado inferiu lista pela presenca de outro arquivo.'
    foreach ($file in Get-ChildItem -LiteralPath "$fixture/.harness/sonar" -Recurse -File) {
        Assert (-not ([IO.File]::ReadAllText($file.FullName).Contains($secret))) 'Token persistido.'
        $basicSecret=[Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($secret + ':'))
        Assert (-not ([IO.File]::ReadAllText($file.FullName).Contains($basicSecret))) 'Credencial Basic persistida.'
    }
    $lock = [IO.File]::Open("$fixture/.harness/mta.lock", 'OpenOrCreate', 'ReadWrite', 'None')
    try {
        $rejected=$false
        try { Invoke-HarnessSonar $context 'team:app' -Token $secure | Out-Null } catch { $rejected=$true }
        Assert $rejected 'Concorrencia local aceita.'
    } finally { $lock.Dispose() }
    $legacy = $config | ConvertTo-Json -Depth 10 | ConvertFrom-Json
    $legacy.PSObject.Properties.Remove('sonar'); Write-HarnessJson "$fixture/legacy.json" $legacy
    $null = Read-HarnessConfig "$fixture/legacy.json" $fixture
} finally {
    $secure.Dispose(); $env:SONAR_TOKEN=$oldToken; $env:JAVA_HOME=$oldJava; $env:MAVEN_ARGS=$oldArgs; $env:SONARQUBE_SCANNER_PARAMS=$oldLegacy
}
Write-Output 'PASS: Sonar simulado, identidade, gate, falhas, concorrencia, historico e token.'
