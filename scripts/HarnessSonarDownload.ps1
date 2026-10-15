# Download somente leitura do servidor; nao depende de toolchain local.
function Get-HarnessSonarConnection {
    param($Context)
    if (-not $Context.Active) { throw 'Escolha o projeto Maven.' }
    if (-not $Context.Config.PSObject.Properties['sonar'] -or -not $Context.Config.sonar) { throw 'Adicione o bloco sonar ao JSON local.' }
    $settings=$Context.Config.sonar
    if (@($settings.PSObject.Properties.Name | Where-Object { $_ -match '(token|password|login|credential)' }).Count) { throw 'Remova credenciais do JSON. O token sera solicitado com entrada oculta.' }
    $url=Get-SonarServerBase (Get-SonarApiField $settings 'serverUrl')
    $auth='Bearer'
    if ($settings.PSObject.Properties['apiAuthScheme']) {
        if ($settings.apiAuthScheme -isnot [string] -or $settings.apiAuthScheme -cnotin @('Bearer','Basic')) { throw 'sonar.apiAuthScheme deve ser Bearer ou Basic.' }
        $auth=$settings.apiAuthScheme
    }
    [pscustomobject]@{ServerUrl=$url;AuthScheme=$auth}
}

function ConvertFrom-SonarAnalysis {
    param($Analysis)
    $id=Get-SonarApiField $Analysis 'key'
    $date=Get-SonarApiField $Analysis 'date'
    $parsed=[DateTimeOffset]::MinValue
    if ($id -isnot [string] -or $id -cnotmatch '^[A-Za-z0-9_-]{1,200}$' -or
        $date -isnot [string] -or $date -notmatch '(Z|[+-]\d{2}:?\d{2})$' -or
        -not [DateTimeOffset]::TryParse(($date -replace '([+-]\d{2})(\d{2})$','$1:$2'),[Globalization.CultureInfo]::InvariantCulture,[Globalization.DateTimeStyles]::None,[ref]$parsed)) {
        throw 'Analise sem identidade ou data com fuso valida.'
    }
    $revision=Get-SonarApiField $Analysis 'revision'
    if ($null -ne $revision -and ($revision -isnot [string] -or $revision.Length -gt 256 -or $revision -match '[\r\n]')) { throw 'Revisao SCM invalida.' }
    [pscustomobject]@{Id=$id;DateUtc=$parsed.UtcDateTime.ToString('o');Revision=$revision}
}

function Receive-HarnessSonar {
    param($Context,[string]$ProjectKey,[string]$BranchName,
        [ValidateSet('ANTES','DEPOIS')][string]$Phase='DEPOIS',
        [Parameter(Mandatory=$true)][Security.SecureString]$Token,[string]$BaselineResultPath)
    $settings=Get-HarnessSonarConnection $Context
    if ($ProjectKey -cnotmatch '^(?=.{1,400}$)(?![0-9]+$)[A-Za-z0-9_.:-]+$') { throw 'Informe a chave exata do projeto existente no SonarQube.' }
    if ($BranchName -and $BranchName -cnotmatch '^[A-Za-z0-9_][A-Za-z0-9_./-]{0,199}$') { throw 'Nome de branch Sonar invalido.' }
    if ($Token.Length -eq 0) { throw 'Token vazio; nenhum download iniciado.' }
    $project=Initialize-HarnessProjectStorage $Context.Root (Join-Path $Context.Active.path 'pom.xml')
    $lock=Enter-HarnessProjectAccess $project -ForOperation
    try {
        $previousToken=[Environment]::GetEnvironmentVariable('SONAR_TOKEN','Process')
        $run=$null; $scannerLog=$null; $gate=$null; $criteria=$null; $plain=$null
        $result=[ordered]@{
            Origin='SERVER';AnalysisDateUtc=$null;AnalysisRevision=$null;LocalSourceStatus='NOT_CHECKED'
            Status='FAILED';ScannerExitCode=$null;AnalysisStatus='UNVERIFIED';QualityGateStatus='UNVERIFIED';MetricsStatus='UNVERIFIED'
            TechnicalStatus='UNVERIFIED';IssuesStatus='UNVERIFIED';DiagnosticPublished=$false;InputsStatus='UNVERIFIED';BuildFreshness='NOT_VERIFIED'
            LogLevel='INFO';LogPath=$null;Project=$project.Name;Source=$project.Source;ProjectLabel=$Context.Active.label
            Phase=$Phase;PhaseOrigin='OPERATOR';ServerUrl=$settings.ServerUrl;ServerVersion=$null;ProjectKey=$ProjectKey;BranchName=$BranchName
            ApiAuthScheme=$settings.AuthScheme;ScannerAuthScheme=$null;ScannerVersion=$null;ScannerJavaHome=$null;ScannerJavaVersion=$null;MavenVersion=$null
            ApplicationJavaHome=$null;MavenHome=$null;SettingsPath=$null;Profiles=$null
            StartedAtUtc=[DateTime]::UtcNow.ToString('o');FinishedAtUtc=$null;TaskId=$null;AnalysisId=$null
            MissingMetrics=@();Stage='PREPARE';Error=$null;ResultPath=$null;CriteriaPath=$null
            DashboardUrl=($settings.ServerUrl+'/dashboard?id='+[Uri]::EscapeDataString($ProjectKey))
            HumanDecision='PENDING';BaselineComparison='PENDING';CriteriaStatus='NOT_EVALUATED'
            BaselineResultPath=$BaselineResultPath;BaselineAnalysisId=$null
            AttemptPath=(Join-Path $project.Folder 'atual/diagnosticos/sonar-tentativa.json')
        }
        if ($BranchName) { $result.DashboardUrl+='&branch='+[Uri]::EscapeDataString($BranchName) }
        try {
            Remove-HarnessProjectTemporary $project 'sonar'
            $run=Get-HarnessProjectTemporary $project 'sonar'
            $null=[IO.Directory]::CreateDirectory($run)
            $scannerLog=Join-Path $run 'download.log'
            $result.ResultPath=Join-Path $project.Folder 'atual/diagnosticos/sonar/resultado.json'
            $result.LogPath=Join-Path $project.Folder 'atual/diagnosticos/sonar-console.log'
            Set-HarnessProjectOperation $project 'sonar' 'RUNNING' -LogPath $scannerLog
            [IO.File]::WriteAllText($scannerLog,('Download do diagnostico existente. Nenhum scanner executado.'+[Environment]::NewLine))
            $ptr=[Runtime.InteropServices.Marshal]::SecureStringToBSTR($Token)
            try { $plain=[Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr) } finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr) }
            if ($plain -match '[\s\x00-\x1f\x7f]') { throw 'Token invalido.' }
            $env:SONAR_TOKEN=$plain; $plain=$null
            $result.Stage='SERVER'
            $server=Invoke-SonarApiGet $settings.ServerUrl 'api/system/status' -AuthScheme $settings.AuthScheme
            if ($server.status -cne 'UP' -or -not (Get-SonarApiField $server 'version')) { throw 'Servidor nao confirmado.' }
            $result.ServerVersion=Protect-SonarText ([string]$server.version)
            $remote=Invoke-SonarApiGet $settings.ServerUrl 'api/components/show' @{component=$ProjectKey} -AuthScheme $settings.AuthScheme
            if ($remote.component.key -cne $ProjectKey -or $remote.component.qualifier -cne 'TRK') { throw 'Projeto existente nao confirmado.' }
            $result.Stage='LATEST_ANALYSIS'
            $query=@{project=$ProjectKey;p='1';ps='1'}
            if ($BranchName) { $query.branch=$BranchName }
            $reply=Invoke-SonarApiGet $settings.ServerUrl 'api/project_analyses/search' $query -AuthScheme $settings.AuthScheme
            if (@($reply.analyses).Count -ne 1) { throw 'Nenhuma analise concluida disponivel.' }
            $analysis=ConvertFrom-SonarAnalysis $reply.analyses[0]
            $result.AnalysisId=$analysis.Id; $result.AnalysisDateUtc=$analysis.DateUtc; $result.AnalysisRevision=$analysis.Revision
            $result.AnalysisStatus='SUCCESS'
            $result.Stage='BASELINE'
            $baseline=Read-HarnessSonarBaseline $BaselineResultPath $Context $result
            if ($baseline) {
                if ($baseline.ServerVersion -cne $result.ServerVersion) { throw 'Versao do servidor diferente do baseline.' }
                $result.BaselineResultPath=$baseline.ResultPath; $result.BaselineAnalysisId=$baseline.AnalysisId
            }
            Assert-HarnessSonarBaselineChronology $baseline $result
            $diagnostic=Read-HarnessSonarDiagnostic $settings $result $run
            $gate=$diagnostic.Gate
            $result.Stage='CRITERIA'
            $criteria=Get-HarnessSonarCriteria -Measures $diagnostic.Measures -Baseline $baseline -IssueSnapshot $diagnostic.Issues -Phase $Phase
            $result.CriteriaStatus=$criteria.Status; $result.BaselineComparison=$criteria.BaselineComparison
            $result.CriteriaPath=Join-Path (Split-Path $result.ResultPath) 'criteria.json'
            Write-SonarJson (Join-Path $run 'criteria.json') @{AnalysisId=$result.AnalysisId;ProjectKey=$ProjectKey;BranchName=$BranchName;Evaluation=$criteria}
            $result.Stage='COMPLETE'
            $result.Status=if ($result.QualityGateStatus -ceq 'ERROR') {'QUALITY_GATE_FAILED'}
                elseif ($criteria.Status -ceq 'FAIL') {'CRITERIA_FAILED'}
                elseif ($result.QualityGateStatus -ceq 'OK' -and $criteria.Status -cin @('PASS','WARN')) {'SUCCEEDED'}
                else {'UNVERIFIED'}
            [IO.File]::AppendAllText($scannerLog,('Analise: '+$result.AnalysisId+' | Data: '+$result.AnalysisDateUtc+' | Resultado: '+$result.Status))
        } catch {
            $result.Error='Falha no download, etapa '+$result.Stage+'. Confira projeto/branch, permissoes, processamento e APIs do servidor.'
            if ($result.AnalysisStatus -eq 'SUCCESS') { $result.Status='UNVERIFIED' }
            if ($scannerLog -and (Test-Path -LiteralPath $scannerLog -PathType Leaf)) { [IO.File]::AppendAllText($scannerLog,$result.Error) }
        } finally {
            try { Publish-HarnessSonarDiagnostic $project $result $run $scannerLog $gate $criteria }
            finally { [Environment]::SetEnvironmentVariable('SONAR_TOKEN',$previousToken,'Process'); $plain=$null }
        }
        [pscustomobject]$result
    } finally { $lock.ReleaseMutex(); $lock.Dispose() }
}
