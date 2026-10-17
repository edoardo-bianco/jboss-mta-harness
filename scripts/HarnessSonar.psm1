#requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'Harness.psm1') -DisableNameChecking
Import-Module (Join-Path $PSScriptRoot 'HarnessProject.psm1') -DisableNameChecking
Import-Module (Join-Path $PSScriptRoot 'HarnessSonarApi.psm1') -DisableNameChecking
Import-Module (Join-Path $PSScriptRoot 'HarnessSonarCriteria.psm1') -DisableNameChecking

function Protect-SonarText {
    param([string]$Text, [string]$Token = [Environment]::GetEnvironmentVariable('SONAR_TOKEN', 'Process'))
    if ($token) {
        $jsonToken = ConvertTo-Json -InputObject $token -Compress
        foreach ($secret in @($token, $jsonToken.Substring(1, $jsonToken.Length - 2), [Uri]::EscapeDataString($token), [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($token + ':')))) {
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
    param([string]$Executable, [string[]]$Arguments, [ValidateSet('Bearer','Basic')][string]$ScannerAuthScheme, [string]$LogPath)
    foreach ($value in @($Executable) + $Arguments) {
        if ($value -match '["%!^&|<>\r\n]') { throw 'Argumento nao suportado pelo launcher Maven Windows.' }
    }
    $saved = $ErrorActionPreference
    $token = [Environment]::GetEnvironmentVariable('SONAR_TOKEN', 'Process')
    $previousAuth = @{}; $writer=$null
    try {
        if ($LogPath) {
            $stream=[IO.File]::Open($LogPath, 'CreateNew', 'Write', 'Read')
            $writer=New-Object IO.StreamWriter($stream, (New-Object Text.UTF8Encoding($false)))
            $writer.AutoFlush=$true
        }
        if ($ScannerAuthScheme) {
            foreach ($name in @('SONAR_TOKEN','SONAR_SCANNER_JSON_PARAMS','SONARQUBE_SCANNER_PARAMS')) {
                $previousAuth[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
                [Environment]::SetEnvironmentVariable($name, $null, 'Process')
            }
            if ($ScannerAuthScheme -ceq 'Basic') {
                # SONAR_TOKEN tem precedencia e produziria Bearer mesmo com sonar.login.
                # JSON somente no ambiente do processo: nenhum segredo na linha de comando.
                $env:SONAR_SCANNER_JSON_PARAMS = @{ 'sonar.login'=$token; 'sonar.password'='' } | ConvertTo-Json -Compress
            } else { $env:SONAR_TOKEN = $token }
        }
        $ErrorActionPreference = 'Continue'
        $version = $Arguments -contains '-version' -or $Arguments -contains '--version'
        $lines = New-Object 'Collections.Generic.List[string]'
        & $Executable @Arguments 2>&1 | ForEach-Object {
            $line = Protect-SonarText $_.ToString() -Token $token
            if ($writer) { $writer.WriteLine($line) }
            if ($version) { $lines.Add($line) } else { Write-Host $line }
        }
        [pscustomobject]@{ExitCode=$LASTEXITCODE; Output=($lines -join "`n")}
    } finally {
        try { if ($writer) { $writer.Dispose() } }
        finally {
            foreach ($name in $previousAuth.Keys) { [Environment]::SetEnvironmentVariable($name, $previousAuth[$name], 'Process') }
            $token = $null
            $ErrorActionPreference = $saved
        }
    }
}

function Get-HarnessSonarSettings {
    param($Context)
    $connection=Get-HarnessSonarConnection $Context
    $settings = $Context.Config.sonar
    $debug=$false
    if ($settings -and $settings.PSObject.Properties['debug']) {
        if ($settings.debug -isnot [bool]) { throw 'sonar.debug deve ser true ou false (booleano JSON).' }
        $debug=$settings.debug
    }
    foreach ($field in @('serverUrl','scannerJdkHome','scannerVersion','ceTimeoutSeconds','profiles')) {
        if (-not $settings -or -not $settings.PSObject.Properties[$field]) { throw "Preencha sonar.$field conforme harness.example.json." }
    }
    $url=$connection.ServerUrl; $authScheme=$connection.AuthScheme
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
    [pscustomobject]@{ServerUrl=$url; AuthScheme=$authScheme; Debug=$debug; Jdk=$jdk; Java=$files[0]; Maven=$files[2]; Pom=$files[3]; Version=$settings.scannerVersion; Timeout=$settings.ceTimeoutSeconds; Profiles=@($settings.profiles)}
}

function Assert-SonarCurrentAnalysis {
    param([string]$ServerUrl, [string]$ProjectKey, [string]$BranchName, [string]$AnalysisId,
        [ValidateSet('Bearer','Basic')][string]$AuthScheme = 'Bearer', [switch]$PassThru)
    $query = @{project=$ProjectKey; p='1'; ps='1'}
    $queueQuery = @{component=$ProjectKey}
    if ($BranchName) { $query.branch=$BranchName; $queueQuery.branch=$BranchName }
    $reply = Invoke-SonarApiGet $ServerUrl 'api/project_analyses/search' $query -AuthScheme $AuthScheme
    if (@($reply.analyses).Count -ne 1 -or $reply.analyses[0].key -cne $AnalysisId) { throw 'Analise atual diferente; metricas nao vinculadas.' }
    $queue = Invoke-SonarApiGet $ServerUrl 'api/ce/component' $queueQuery -AuthScheme $AuthScheme
    if (@($queue.queue).Count -gt 0 -or ($queue.PSObject.Properties['current'] -and $queue.current -and $queue.current.status -in @('PENDING','IN_PROGRESS'))) { throw 'Outra analise em processamento; metricas nao vinculadas.' }
    if ($PassThru) { $reply.analyses[0] }
}

function Get-HarnessSonarIssues {
    param([string]$ServerUrl, [string]$ProjectKey, [string]$BranchName,
        [ValidateSet('Bearer','Basic')][string]$AuthScheme='Bearer', [ValidateRange(1,100)][int]$PageSize=100)
    $items=New-Object 'Collections.Generic.List[object]'
    $keys=New-Object 'Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
    $total=$null; $page=1
    do {
        $query=@{componentKeys=$ProjectKey;resolved='false';p=[string]$page;ps=[string]$PageSize}
        if ($BranchName) { $query.branch=$BranchName }
        $reply=Invoke-SonarApiGet $ServerUrl 'api/issues/search' $query -AuthScheme $AuthScheme
        $paging=Get-SonarApiField $reply 'paging'
        $received=Get-SonarApiField $reply 'issues'
        if ($received -isnot [Array] -or (Get-SonarApiField $paging 'total') -isnot [int] -or
            $paging.total -lt 0 -or $paging.total -gt 10000 -or $paging.pageIndex -ne $page -or $paging.pageSize -ne $PageSize) {
            throw 'SONAR_ISSUES_UNVERIFIED: pagina invalida ou limite de 10000 issues excedido.'
        }
        if ($null -eq $total) { $total=$paging.total }
        if ($paging.total -ne $total -or $received.Count -ne [Math]::Min($PageSize, $total-$items.Count)) { throw 'SONAR_ISSUES_UNVERIFIED: contagem mudou ou pagina incompleta.' }
        $components=Get-SonarApiField $reply 'components'
        foreach ($issue in $received) {
            foreach ($field in @('key','project','component','rule','message')) {
                $value=Get-SonarApiField $issue $field
                if ($value -isnot [string] -or [string]::IsNullOrWhiteSpace($value)) { throw 'SONAR_ISSUES_UNVERIFIED: identidade ou detalhe ausente.' }
            }
            if ($issue.project -cne $ProjectKey -or -not $keys.Add($issue.key)) { throw 'SONAR_ISSUES_UNVERIFIED: outro projeto ou chave duplicada.' }
            $impacts=@(); $rawImpacts=Get-SonarApiField $issue 'impacts'
            if ($null -ne $rawImpacts -and $rawImpacts -isnot [Array]) { throw 'SONAR_ISSUES_UNVERIFIED: impactos invalidos.' }
            foreach ($impact in $rawImpacts) {
                $severity=Get-SonarApiField $impact 'severity'
                if ($severity -cnotin @('BLOCKER','HIGH','MEDIUM','LOW','INFO')) { throw 'SONAR_ISSUES_UNVERIFIED: severidade desconhecida.' }
                $impacts+= [pscustomobject]@{severity=$severity;softwareQuality=(Get-SonarApiField $impact 'softwareQuality')}
            }
            $component=@($components | Where-Object { $_ -and (Get-SonarApiField $_ 'key') -ceq $issue.component })
            $path=$null; if ($component.Count -eq 1) { $path=Get-SonarApiField $component[0] 'path' }
            $items.Add([pscustomobject]@{
                key=$issue.key;project=$issue.project;component=$issue.component;path=$path;rule=$issue.rule
                severity=[string](Get-SonarApiField $issue 'severity');impacts=$impacts
                status=(Get-SonarApiField $issue 'status');issueStatus=(Get-SonarApiField $issue 'issueStatus')
                message=$issue.message;line=(Get-SonarApiField $issue 'line');textRange=(Get-SonarApiField $issue 'textRange')
                creationDate=(Get-SonarApiField $issue 'creationDate');updateDate=(Get-SonarApiField $issue 'updateDate')
            })
        }
        $page++
    } while ($items.Count -lt $total)
    [pscustomobject]@{Status='COMPLETE';Filter='resolved=false';Count=$items.Count;Issues=@($items.ToArray())}
}

. (Join-Path $PSScriptRoot 'HarnessSonarDiagnostic.ps1')
. (Join-Path $PSScriptRoot 'HarnessSonarDownload.ps1')

function Invoke-HarnessSonar {
    param($Context, [string]$ProjectKey, [string]$BranchName,
        [ValidateSet('ANTES','DEPOIS')][string]$Phase = 'ANTES',
        [Parameter(Mandatory=$true)][Security.SecureString]$Token, [string]$BaselineResultPath)
    $settings = Get-HarnessSonarSettings $Context
    if ($ProjectKey -cnotmatch '^(?=.{1,400}$)(?![0-9]+$)[A-Za-z0-9_.:-]+$') { throw 'Informe a chave exata do projeto existente no SonarQube.' }
    if ($BranchName -and $BranchName -cnotmatch '^[A-Za-z0-9_][A-Za-z0-9_./-]{0,199}$') { throw 'Nome de branch Sonar invalido.' }
    if ($Token.Length -eq 0) { throw 'Token vazio; nenhuma analise iniciada.' }
    $project=Initialize-HarnessProjectStorage $Context.Root $settings.Pom
    $lock=Enter-HarnessProjectAccess $project -ForOperation
    try {
    $previous=@{}; $pushed=$false; $run=$null; $scannerLog=$null; $plain=$null; $criteria=$null; $gate=$null
    $result = [ordered]@{
        Origin='SCAN'; AnalysisDateUtc=$null; AnalysisRevision=$null; LocalSourceStatus='NOT_CHECKED'
        Status='FAILED'; ScannerExitCode=$null; AnalysisStatus='UNVERIFIED'; QualityGateStatus='UNVERIFIED'; MetricsStatus='UNVERIFIED'
        TechnicalStatus='UNVERIFIED'; IssuesStatus='UNVERIFIED'; DiagnosticPublished=$false
        LogLevel=$(if ($settings.Debug) { 'DEBUG' } else { 'INFO' }); LogPath=$null
        Project=$project.Name; Source=$Context.Active.path; ProjectLabel=$Context.Active.label
        Phase=$Phase; PhaseOrigin='OPERATOR'
        ServerUrl=$settings.ServerUrl; ServerVersion=$null; ProjectKey=$ProjectKey; BranchName=$BranchName
        ApiAuthScheme=$settings.AuthScheme; ScannerAuthScheme=$settings.AuthScheme
        ScannerVersion=$settings.Version; ScannerJavaHome=$settings.Jdk; ScannerJavaVersion=$null; MavenVersion=$null
        ApplicationJavaHome=$Context.Config.tools.applicationJdk8Home; MavenHome=$Context.Config.tools.applicationMavenHome
        SettingsPath=$Context.Config.tools.applicationMavenSettingsPath; Profiles=$settings.Profiles
        StartedAtUtc=[DateTime]::UtcNow.ToString('o'); FinishedAtUtc=$null; TaskId=$null; AnalysisId=$null
        MissingMetrics=@(); Stage='PREPARE'; Error=$null; ResultPath=$null
        DashboardUrl=($settings.ServerUrl + '/dashboard?id=' + [Uri]::EscapeDataString($ProjectKey))
        HumanDecision='PENDING'; BaselineComparison='PENDING'; CriteriaStatus='NOT_EVALUATED'; InputsStatus='UNVERIFIED'; BuildFreshness='NOT_VERIFIED'
        BaselineResultPath=$BaselineResultPath; BaselineAnalysisId=$null; CriteriaPath=$null
        AttemptPath=(Join-Path $project.Folder 'atual/diagnosticos/sonar-tentativa.json')
    }
    if ($BranchName) { $result.DashboardUrl += '&branch=' + [Uri]::EscapeDataString($BranchName) }
    try {
        Remove-HarnessProjectTemporary $project 'sonar'
        $run=Get-HarnessProjectTemporary $project 'sonar'
        $null = [IO.Directory]::CreateDirectory($run)
        $result.ResultPath = Join-Path $project.Folder 'atual/diagnosticos/sonar/resultado.json'
        $result.LogPath=Join-Path $project.Folder 'atual/diagnosticos/sonar-console.log'
        $scannerLog=Join-Path $run 'scanner.log'
        Set-HarnessProjectOperation $project 'sonar' 'RUNNING' -LogPath $scannerLog
        $result.Stage='BASELINE'
        $baseline=Read-HarnessSonarBaseline -Path $BaselineResultPath -Context $Context -Current $result
        if ($baseline) { $result.BaselineResultPath=$baseline.ResultPath; $result.BaselineAnalysisId=$baseline.AnalysisId }
        $result.Stage='PREPARE'
        Import-Module (Join-Path $PSScriptRoot 'HarnessGit.psm1') -DisableNameChecking
        $result['Git'] = Get-HarnessGitState $Context
        $sourceFiles = @(Get-HarnessFiles $Context.Active.path)
        foreach ($name in @('JAVA_HOME','PATH','MAVEN_HOME','M2_HOME','MAVEN_ARGS','MAVEN_OPTS','JAVA_OPTS','JDK_JAVA_OPTIONS','JAVA_TOOL_OPTIONS','_JAVA_OPTIONS','MAVEN_SKIP_RC','MAVEN_BASEDIR','MAVEN_PROJECTBASEDIR','MAVEN_BATCH_PAUSE','MAVEN_BATCH_ECHO','SONAR_TOKEN','SONAR_HOST_URL','SONAR_SCANNER_JSON_PARAMS','SONARQUBE_SCANNER_PARAMS','SONAR_SCANNER_OPTS','SONAR_SCANNER_JAVA_OPTS')) {
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
        $sonarProject=Invoke-SonarApiGet $settings.ServerUrl 'api/components/show' @{component=$ProjectKey} -AuthScheme $settings.AuthScheme
        if ($sonarProject.component.key -cne $ProjectKey -or $sonarProject.component.qualifier -cne 'TRK') { throw 'Projeto existente nao confirmado.' }
        $result.Stage='SCAN'
        $report=Join-Path $run 'report-task.txt'
        $arguments=@('-B','-f',$settings.Pom)
        if ($settings.Debug) { $arguments+=@('-e','-X') }
        if ($result.SettingsPath) { $arguments+=@('-s',$result.SettingsPath) }
        if ($settings.Profiles.Count) { $arguments+=('-P' + ($settings.Profiles -join ',')) }
        $arguments+=@(('org.sonarsource.scanner.maven:sonar-maven-plugin:' + $settings.Version + ':sonar'),
            ('-Dsonar.host.url=' + $settings.ServerUrl), ('-Dsonar.projectKey=' + $ProjectKey),
            ('-Dsonar.java.jdkHome=' + $result.ApplicationJavaHome), ('-Dsonar.scanner.javaExePath=' + $settings.Java),
            '-Dsonar.scanner.skipJreProvisioning=true', ('-Dsonar.verbose=' + $settings.Debug.ToString().ToLowerInvariant()), ('-Dsonar.log.level=' + $result.LogLevel), '-Dsonar.qualitygate.wait=false',
            ('-Dsonar.scanner.metadataFilePath=' + $report), ('-Dsonar.working.directory=' + (Join-Path $run 'scanner-work')))
        if ($BranchName) { $arguments+=('-Dsonar.branch.name=' + $BranchName) }
        Write-Host "Enviando $($result.ProjectLabel) ao Sonar $($settings.ServerUrl) | Chave: $ProjectKey | Estado declarado: $Phase"
        $scan=Invoke-SonarTool $settings.Maven $arguments -ScannerAuthScheme $settings.AuthScheme -LogPath $scannerLog; $result.ScannerExitCode=$scan.ExitCode
        if ($scan.ExitCode -ne 0) { throw 'Scanner Maven falhou; consulte a saida do terminal.' }
        $result.Stage='COMPUTE_ENGINE'
        $metadata=Read-SonarTaskReport $report $settings.ServerUrl $ProjectKey -BranchName $BranchName
        $result.TaskId=$metadata.TaskId
        Write-Host 'Relatorio enviado. Aguardando processamento no SonarQube...'
        $task=Wait-SonarComputeEngine -ServerUrl $settings.ServerUrl -TaskId $metadata.TaskId -ProjectKey $ProjectKey -BranchName $BranchName -TimeoutSeconds $settings.Timeout -AuthScheme $settings.AuthScheme
        $result.AnalysisId=$task.AnalysisId; $result.AnalysisStatus='SUCCESS'
        $diagnostic=Read-HarnessSonarDiagnostic $settings $result $run
        $gate=$diagnostic.Gate; $allMeasures=$diagnostic.Measures; $issueSnapshot=$diagnostic.Issues
        $after=@(Get-HarnessFiles $Context.Active.path)
        if (($sourceFiles | ConvertTo-Json -Depth 4 -Compress) -cne ($after | ConvertTo-Json -Depth 4 -Compress)) { throw 'Entradas mudaram durante o scan; coleta nao e baseline estavel.' }
        $result.InputsStatus='STABLE'
        $result.LocalSourceStatus='STABLE_DURING_SCAN'
        Assert-HarnessSonarBaselineChronology $baseline $result
        $result.Stage='CRITERIA'
        $criteria=Get-HarnessSonarCriteria -Measures $allMeasures -Baseline $baseline -IssueSnapshot $issueSnapshot -Phase $Phase
        $result.CriteriaStatus=$criteria.Status; $result.BaselineComparison=$criteria.BaselineComparison
        $result.CriteriaPath=Join-Path (Split-Path $result.ResultPath) 'criteria.json'
        Write-SonarJson (Join-Path $run 'criteria.json') @{AnalysisId=$task.AnalysisId; ProjectKey=$ProjectKey; BranchName=$BranchName; Evaluation=$criteria}
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
            Publish-HarnessSonarDiagnostic $project $result $run $scannerLog $gate $criteria
        } finally {
            if ($pushed) { Pop-Location }
            foreach ($name in $previous.Keys) { [Environment]::SetEnvironmentVariable($name,$previous[$name],'Process') }
            $plain=$null
        }
    }
    [pscustomobject]$result
    } finally { $lock.ReleaseMutex(); $lock.Dispose() }
}

Export-ModuleMember -Function Get-HarnessSonarSettings, Get-HarnessSonarConnection, Invoke-HarnessSonar, Receive-HarnessSonar
