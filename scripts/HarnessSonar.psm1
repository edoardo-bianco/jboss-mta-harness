#requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'Harness.psm1') -DisableNameChecking
Import-Module (Join-Path $PSScriptRoot 'HarnessSonarApi.psm1') -DisableNameChecking
Import-Module (Join-Path $PSScriptRoot 'HarnessSonarCriteria.psm1') -DisableNameChecking

function Protect-SonarText {
    param([string]$Text)
    $token = [Environment]::GetEnvironmentVariable('SONAR_TOKEN', 'Process')
    if ($token) {
        foreach ($secret in @($token, [Uri]::EscapeDataString($token), [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($token + ':')))) {
            $Text = $Text.Replace($secret, '[REDACTED]')
        }
    }
    $Text
}

function Write-SonarJson {
    param([string]$Path, $Value)
    $json = Protect-SonarText ($Value | ConvertTo-Json -Depth 20)
    [IO.File]::WriteAllText($Path, $json, (New-Object Text.UTF8Encoding($false)))
}

function Invoke-SonarTool {
    param([string]$Executable, [string[]]$Arguments)
    foreach ($value in @($Executable) + $Arguments) {
        if ($value -match '["%!^&|<>\r\n]') { throw 'Argumento nao suportado pelo launcher Maven Windows.' }
    }
    $saved = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $version = $Arguments -contains '-version' -or $Arguments -contains '--version'
        $lines = New-Object 'Collections.Generic.List[string]'
        & $Executable @Arguments 2>&1 | ForEach-Object {
            $line = Protect-SonarText $_.ToString()
            if ($version) { $lines.Add($line) } else { Write-Host $line }
        }
        [pscustomobject]@{ExitCode=$LASTEXITCODE; Output=($lines -join "`n")}
    } finally { $ErrorActionPreference = $saved }
}

function Get-HarnessSonarSettings {
    param($Context)
    if (-not $Context.Active) { throw 'Escolha o projeto Maven.' }
    if (-not $Context.Config.PSObject.Properties['sonar']) { throw 'Adicione o bloco sonar do harness.example.json ao JSON local.' }
    $settings = $Context.Config.sonar
    foreach ($field in @('serverUrl','scannerJdkHome','scannerVersion','ceTimeoutSeconds','profiles')) {
        if (-not $settings -or -not $settings.PSObject.Properties[$field]) { throw "Preencha sonar.$field conforme harness.example.json." }
    }
    if (@($settings.PSObject.Properties.Name | Where-Object { $_ -match '(token|password|login|credential)' }).Count) { throw 'Remova credenciais do JSON. O token sera solicitado com entrada oculta.' }
    $url = Get-SonarServerBase $settings.serverUrl
    $authScheme = 'Bearer'
    if ($settings.PSObject.Properties['apiAuthScheme']) {
        if ($settings.apiAuthScheme -isnot [string] -or $settings.apiAuthScheme -cnotin @('Bearer','Basic')) { throw 'sonar.apiAuthScheme deve ser Bearer ou Basic.' }
        $authScheme = $settings.apiAuthScheme
    }
    if ($settings.scannerVersion -cnotmatch '^5\.\d+\.\d+\.\d+$') { throw 'Use uma versao fixa 5.x do sonar-maven-plugin, compativel com seu servidor.' }
    if ($settings.ceTimeoutSeconds -isnot [int] -or $settings.ceTimeoutSeconds -lt 1 -or $settings.ceTimeoutSeconds -gt 3600) { throw 'ceTimeoutSeconds deve ser inteiro entre 1 e 3600.' }
    if ($settings.profiles -isnot [Array]) { throw 'sonar.profiles deve ser uma lista de perfis Maven.' }
    foreach ($profile in $settings.profiles) { if ($profile -isnot [string] -or $profile -cnotmatch '^[A-Za-z0-9_][A-Za-z0-9_.-]*$') { throw 'Perfil Maven invalido.' } }
    $jdk = Resolve-HarnessPath $settings.scannerJdkHome $Context.Root
    $tools = $Context.Config.tools
    foreach ($path in @($jdk, $tools.applicationJdk8Home, $tools.applicationMavenHome)) {
        if (-not $path) { throw 'Configure sonar.scannerJdkHome, tools.applicationJdk8Home e tools.applicationMavenHome.' }
    }
    $files = @((Join-Path $jdk 'bin/java.exe'), (Join-Path $tools.applicationJdk8Home 'bin/java.exe'), (Join-Path $tools.applicationMavenHome 'bin/mvn.cmd'), (Join-Path $Context.Active.path 'pom.xml'))
    if ($tools.applicationMavenSettingsPath) { $files += $tools.applicationMavenSettingsPath }
    foreach ($file in $files) {
        if ($file -match '["%!^&|<>\r\n]') { throw 'Caminho nao suportado pelo launcher Maven Windows.' }
        if (-not (Test-Path -LiteralPath $file -PathType Leaf)) { throw "Arquivo ausente: $file" }
    }
    [pscustomobject]@{ServerUrl=$url; AuthScheme=$authScheme; Jdk=$jdk; Java=$files[0]; Maven=$files[2]; Pom=$files[3]; Version=$settings.scannerVersion; Timeout=$settings.ceTimeoutSeconds; Profiles=@($settings.profiles)}
}

function Assert-SonarCurrentAnalysis {
    param([string]$ServerUrl, [string]$ProjectKey, [string]$BranchName, [string]$AnalysisId,
        [ValidateSet('Bearer','Basic')][string]$AuthScheme = 'Bearer')
    $query = @{project=$ProjectKey; p='1'; ps='1'}
    $queueQuery = @{component=$ProjectKey}
    if ($BranchName) { $query.branch=$BranchName; $queueQuery.branch=$BranchName }
    $reply = Invoke-SonarApiGet $ServerUrl 'api/project_analyses/search' $query -AuthScheme $AuthScheme
    if (@($reply.analyses).Count -ne 1 -or $reply.analyses[0].key -cne $AnalysisId) { throw 'Analise atual diferente; metricas nao vinculadas.' }
    $queue = Invoke-SonarApiGet $ServerUrl 'api/ce/component' $queueQuery -AuthScheme $AuthScheme
    if (@($queue.queue).Count -gt 0 -or ($queue.PSObject.Properties['current'] -and $queue.current -and $queue.current.status -in @('PENDING','IN_PROGRESS'))) { throw 'Outra analise em processamento; metricas nao vinculadas.' }
}

function Invoke-HarnessSonar {
    param($Context, [string]$ProjectKey, [string]$BranchName,
        [ValidateSet('ANTES','DEPOIS')][string]$Phase = 'ANTES',
        [Parameter(Mandatory=$true)][Security.SecureString]$Token, [string]$BaselineResultPath)
    $settings = Get-HarnessSonarSettings $Context
    if ($ProjectKey -cnotmatch '^(?=.{1,400}$)(?![0-9]+$)[A-Za-z0-9_.:-]+$') { throw 'Informe a chave exata do projeto existente no SonarQube.' }
    if ($BranchName -and $BranchName -cnotmatch '^[A-Za-z0-9_][A-Za-z0-9_./-]{0,199}$') { throw 'Nome de branch Sonar invalido.' }
    if ($Token.Length -eq 0) { throw 'Token vazio; nenhuma analise iniciada.' }
    $state = Resolve-HarnessPath (Join-Path $Context.Root '.harness') $Context.Root
    $null = [IO.Directory]::CreateDirectory($state)
    try { $lock = [IO.File]::Open((Join-Path $state 'mta.lock'), 'OpenOrCreate', 'ReadWrite', 'None') }
    catch { throw 'Ja existe build, MTA, Sonar ou limpeza em execucao neste harness.' }
    $previous=@{}; $pushed=$false; $run=$null; $plain=$null; $criteria=$null
    $result = [ordered]@{
        Status='FAILED'; ScannerExitCode=$null; AnalysisStatus='UNVERIFIED'; QualityGateStatus='UNVERIFIED'; MetricsStatus='UNVERIFIED'
        Project=$Context.Active.name; Source=$Context.Active.path; ProjectLabel=$Context.Active.label
        RunId=[guid]::NewGuid().ToString('N'); Phase=$Phase; PhaseOrigin='OPERATOR'
        ServerUrl=$settings.ServerUrl; ServerVersion=$null; ProjectKey=$ProjectKey; BranchName=$BranchName
        ApiAuthScheme=$settings.AuthScheme
        ScannerVersion=$settings.Version; ScannerJavaHome=$settings.Jdk; ScannerJavaVersion=$null; MavenVersion=$null
        ApplicationJavaHome=$Context.Config.tools.applicationJdk8Home; MavenHome=$Context.Config.tools.applicationMavenHome
        SettingsPath=$Context.Config.tools.applicationMavenSettingsPath; Profiles=$settings.Profiles
        StartedAtUtc=[DateTime]::UtcNow.ToString('o'); FinishedAtUtc=$null; TaskId=$null; AnalysisId=$null
        MissingMetrics=@(); Stage='PREPARE'; Error=$null; ResultPath=$null
        DashboardUrl=($settings.ServerUrl + '/dashboard?id=' + [Uri]::EscapeDataString($ProjectKey))
        HumanDecision='PENDING'; BaselineComparison='PENDING'; CriteriaStatus='NOT_EVALUATED'; InputsStatus='UNVERIFIED'; BuildFreshness='NOT_VERIFIED'
        BaselineResultPath=$BaselineResultPath; BaselineRunId=$null; CriteriaPath=$null
    }
    if ($BranchName) { $result.DashboardUrl += '&branch=' + [Uri]::EscapeDataString($BranchName) }
    try {
        $folder = 'sonar_' + (Format-HarnessDate $result.StartedAtUtc -ForPath) + '__' + $result.RunId.Substring(0,12)
        $run = Resolve-HarnessPath (Join-Path $state ('sonar/' + (Get-HarnessProjectFolder $Context.Active) + '/' + $folder)) $Context.Root
        if (Test-Path -LiteralPath $run) { throw 'Pasta de coleta ja existe.' }
        $null = [IO.Directory]::CreateDirectory($run)
        $result.ResultPath = Join-Path $run 'result.json'
        $result.Stage='BASELINE'
        $baseline=Read-HarnessSonarBaseline -Path $BaselineResultPath -Context $Context -Current $result
        if ($baseline) { $result.BaselineResultPath=$baseline.ResultPath; $result.BaselineRunId=$baseline.RunId }
        $result.Stage='PREPARE'
        Import-Module (Join-Path $PSScriptRoot 'HarnessGit.psm1') -DisableNameChecking
        $result['Git'] = Get-HarnessGitState $Context
        $sourceFiles = @(Get-HarnessFiles $Context.Active.path)
        Write-SonarJson (Join-Path $run 'inputs.json') @{Project=$result.Project; Source=$result.Source; Files=$sourceFiles; Note='Hashes dos arquivos de entrada; nao comprovam atualidade dos binarios ou cobertura.'}
        foreach ($name in @('JAVA_HOME','PATH','MAVEN_HOME','M2_HOME','MAVEN_ARGS','MAVEN_OPTS','JAVA_OPTS','JDK_JAVA_OPTIONS','JAVA_TOOL_OPTIONS','_JAVA_OPTIONS','MAVEN_SKIP_RC','MAVEN_BASEDIR','MAVEN_PROJECTBASEDIR','MAVEN_BATCH_PAUSE','MAVEN_BATCH_ECHO','SONAR_TOKEN','SONAR_HOST_URL','SONAR_SCANNER_JSON_PARAMS','SONAR_SCANNER_OPTS','SONAR_SCANNER_JAVA_OPTS')) {
            $previous[$name]=[Environment]::GetEnvironmentVariable($name,'Process')
            [Environment]::SetEnvironmentVariable($name,$null,'Process')
        }
        $env:JAVA_HOME=$settings.Jdk; $env:MAVEN_HOME=$Context.Config.tools.applicationMavenHome; $env:M2_HOME=$env:MAVEN_HOME; $env:MAVEN_SKIP_RC='true'
        $env:PATH=(Join-Path $settings.Jdk 'bin') + ';' + (Join-Path $env:MAVEN_HOME 'bin') + ';' + $previous.PATH
        Push-Location -LiteralPath $Context.Active.path; $pushed=$true
        $result.Stage='TOOLS'
        $version=Invoke-SonarTool $settings.Java @('-version'); $result.ScannerJavaVersion=$version.Output
        if ($version.ExitCode -ne 0 -or $version.Output -notmatch 'version "(\d+)' -or [int]$Matches[1] -lt 17) { throw 'Scanner requer JDK moderno; configure JDK 21 ou superior para servidores atuais.' }
        $version=Invoke-SonarTool $settings.Maven @('--version'); $result.MavenVersion=$version.Output
        if ($version.ExitCode -ne 0 -or $version.Output -notmatch 'Java version: (\d+)' -or [int]$Matches[1] -lt 17) { throw 'Maven nao esta usando o JDK do scanner.' }
        $ptr=[Runtime.InteropServices.Marshal]::SecureStringToBSTR($Token)
        try { $plain=[Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr) } finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr) }
        if ($plain -match '[\s\x00-\x1f\x7f]') { throw 'Token invalido.' }
        $env:SONAR_TOKEN=$plain; $plain=$null
        $result.Stage='SERVER'
        $server=Invoke-SonarApiGet $settings.ServerUrl 'api/system/status' -AuthScheme $settings.AuthScheme
        if ($server.status -cne 'UP') { throw 'Servidor nao esta UP.' }
        $result.ServerVersion=Protect-SonarText ([string]$server.version)
        if ($baseline -and $baseline.ServerVersion -cne $result.ServerVersion) { throw 'Versao do servidor diferente do baseline.' }
        $project=Invoke-SonarApiGet $settings.ServerUrl 'api/components/show' @{component=$ProjectKey} -AuthScheme $settings.AuthScheme
        if ($project.component.key -cne $ProjectKey -or $project.component.qualifier -cne 'TRK') { throw 'Projeto existente nao confirmado.' }
        $result.Stage='SCAN'
        $report=Join-Path $run 'report-task.txt'
        $arguments=@('-B','-f',$settings.Pom)
        if ($result.SettingsPath) { $arguments+=@('-s',$result.SettingsPath) }
        if ($settings.Profiles.Count) { $arguments+=('-P' + ($settings.Profiles -join ',')) }
        $arguments+=@(('org.sonarsource.scanner.maven:sonar-maven-plugin:' + $settings.Version + ':sonar'),
            ('-Dsonar.host.url=' + $settings.ServerUrl), ('-Dsonar.projectKey=' + $ProjectKey),
            ('-Dsonar.java.jdkHome=' + $result.ApplicationJavaHome), ('-Dsonar.scanner.javaExePath=' + $settings.Java),
            '-Dsonar.scanner.skipJreProvisioning=true', '-Dsonar.verbose=false', '-Dsonar.log.level=INFO', '-Dsonar.qualitygate.wait=false',
            ('-Dsonar.scanner.metadataFilePath=' + $report), ('-Dsonar.working.directory=' + (Join-Path $run 'scanner-work')))
        if ($BranchName) { $arguments+=('-Dsonar.branch.name=' + $BranchName) }
        Write-Host "Enviando $($result.ProjectLabel) ao Sonar $($settings.ServerUrl) | Chave: $ProjectKey | Estado declarado: $Phase"
        $scan=Invoke-SonarTool $settings.Maven $arguments; $result.ScannerExitCode=$scan.ExitCode
        if ($scan.ExitCode -ne 0) { throw 'Scanner Maven falhou; consulte a saida do terminal.' }
        $result.Stage='COMPUTE_ENGINE'
        $metadata=Read-SonarTaskReport $report $settings.ServerUrl $ProjectKey
        $result.TaskId=$metadata.TaskId
        Write-Host 'Relatorio enviado. Aguardando processamento no SonarQube...'
        $task=Wait-SonarComputeEngine -ServerUrl $settings.ServerUrl -TaskId $metadata.TaskId -ProjectKey $ProjectKey -BranchName $BranchName -TimeoutSeconds $settings.Timeout -AuthScheme $settings.AuthScheme
        $result.AnalysisId=$task.AnalysisId; $result.AnalysisStatus='SUCCESS'
        $result.Stage='QUALITY_GATE'
        $gate=Invoke-SonarApiGet $settings.ServerUrl 'api/qualitygates/project_status' @{analysisId=$task.AnalysisId} -AuthScheme $settings.AuthScheme
        if ($gate.projectStatus.status -cnotin @('OK','ERROR','WARN','NONE')) { throw 'Quality Gate desconhecido.' }
        $result.QualityGateStatus=$gate.projectStatus.status
        Write-SonarJson (Join-Path $run 'quality-gate.json') @{AnalysisId=$task.AnalysisId; ProjectKey=$ProjectKey; Result=$gate.projectStatus}
        $result.Stage='METRICS'
        Assert-SonarCurrentAnalysis $settings.ServerUrl $ProjectKey $BranchName $task.AnalysisId -AuthScheme $settings.AuthScheme
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
        Assert-SonarCurrentAnalysis $settings.ServerUrl $ProjectKey $BranchName $task.AnalysisId -AuthScheme $settings.AuthScheme
        $result.MissingMetrics=@($metrics | Where-Object { $_ -cnotin @($allMeasures | ForEach-Object { $_.metric }) })
        Write-SonarJson (Join-Path $run 'measures.json') @{AnalysisId=$task.AnalysisId; ProjectKey=$ProjectKey; BranchName=$BranchName; CollectedAtUtc=[DateTime]::UtcNow.ToString('o'); Measures=$allMeasures; MissingMetrics=$result.MissingMetrics}
        $result.MetricsStatus='MATCHED'
        $after=@(Get-HarnessFiles $Context.Active.path)
        if (($sourceFiles | ConvertTo-Json -Depth 4 -Compress) -cne ($after | ConvertTo-Json -Depth 4 -Compress)) { throw 'Entradas mudaram durante o scan; coleta nao e baseline estavel.' }
        $result.InputsStatus='STABLE'
        $result.Stage='CRITERIA'
        $criteria=Get-HarnessSonarCriteria -Measures $allMeasures -Baseline $baseline
        $result.CriteriaStatus=$criteria.Status; $result.BaselineComparison=$criteria.BaselineComparison
        $result.CriteriaPath=Join-Path $run 'criteria.json'
        Write-SonarJson $result.CriteriaPath @{AnalysisId=$task.AnalysisId; ProjectKey=$ProjectKey; BranchName=$BranchName; Evaluation=$criteria}
        $result.Stage='COMPLETE'
        $result.Status=if ($result.QualityGateStatus -ceq 'ERROR') { 'QUALITY_GATE_FAILED' }
            elseif ($criteria.Status -ceq 'FAIL') { 'CRITERIA_FAILED' }
            elseif ($result.QualityGateStatus -ceq 'OK' -and $criteria.Status -cin @('PASS','WARN')) { 'SUCCEEDED' }
            else { 'UNVERIFIED' }
    } catch {
        # Nao persistir mensagens arbitrarias de processos, POMs ou respostas HTTP.
        $result.Error='Falha na etapa ' + $result.Stage + '. Confira configuracao, permissoes, saida do scanner e disponibilidade das APIs. Nao considerar esta coleta aprovada.'
        if ($result.AnalysisStatus -eq 'SUCCESS') { $result.Status='UNVERIFIED' }
    } finally {
        try {
            $result.FinishedAtUtc=[DateTime]::UtcNow.ToString('o')
            if ($result.ResultPath) {
                Write-SonarJson $result.ResultPath $result
                $lines=@('# Coleta SonarQube', '', "Projeto: $($result.ProjectLabel)", "Source: $($result.Source)", "RunId: $($result.RunId)", "Estado declarado pelo operador: $Phase", "Inicio: $(Format-HarnessDate $result.StartedAtUtc)", "Servidor: $($result.ServerUrl)", "Chave: $ProjectKey", "AnalysisId: $($result.AnalysisId)", "Resultado da operacao: $($result.Status)", "Processamento: $($result.AnalysisStatus)", "Quality Gate do servidor: $($result.QualityGateStatus)", "Criterios do harness: $($result.CriteriaStatus)", "Metricas: $($result.MetricsStatus)", "Dashboard: $($result.DashboardUrl)", '')
                $lines += @("Autenticacao da API: $($result.ApiAuthScheme)", '')
                if ($criteria) {
                    $lines+=@('| Criterio | Valor | Regra |', '| --- | --- | --- |', "| Blocker | $($criteria.BlockerIssues) | Reprova acima de zero |", "| High | $($criteria.HighIssues) | Reprova acima de zero |", "| Cobertura global (%) | $($criteria.Coverage) | Aviso abaixo de 85% |", "| Total de issues | $($criteria.TotalIssues) | Aviso se aumentar ante o baseline |", '', "Comparacao: $($criteria.BaselineComparison); diferenca de issues: $($criteria.IssuesDelta)", "Baseline selecionado: $($criteria.BaselineResultPath)", '')
                    foreach ($message in $criteria.Failures) { $lines+='REPROVADO: ' + $message }
                    foreach ($message in $criteria.Warnings) { $lines+='AVISO: ' + $message }
                    foreach ($message in $criteria.Pending) { $lines+='PENDENTE: ' + $message }
                    $lines+=@('', $criteria.ComparisonLimit)
                }
                $lines+=@('', 'Arquivos: result.json, inputs.json, report-task.txt e, quando coletados, quality-gate.json, measures.json e criteria.json.', 'Campos ausentes nao equivalem a zero. ANTES/DEPOIS e declaracao do operador.', 'O scanner nao gera cobertura: importe o XML JaCoCo produzido pelos testes. Esta coleta nao comprova WAR/runtime, GO ou aceite humano.', "Erro: $($result.Error)")
                $summary=$lines -join "`r`n"
                [IO.File]::WriteAllText((Join-Path $run 'RESUMO.md'), (Protect-SonarText $summary), (New-Object Text.UTF8Encoding($false)))
            }
        } finally {
            if ($pushed) { Pop-Location }
            foreach ($name in $previous.Keys) { [Environment]::SetEnvironmentVariable($name,$previous[$name],'Process') }
            $plain=$null; $lock.Dispose()
        }
    }
    [pscustomobject]$result
}

Export-ModuleMember -Function Get-HarnessSonarSettings, Invoke-HarnessSonar
