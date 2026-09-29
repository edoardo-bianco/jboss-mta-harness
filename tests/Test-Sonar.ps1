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
$module = Get-Module HarnessSonar
# Executar o wrapper nativo com credencial sintetica e saida hostil, antes dos mocks.
$native = Join-Path $area 'scanner simulado.cmd'
[IO.File]::WriteAllText($native, "@echo off`r`necho token=%SONAR_TOKEN%`r`nexit /b 9`r`n")
$savedNativeToken = $env:SONAR_TOKEN
try {
    $env:SONAR_TOKEN='synthetic-native-token-123456789'
    $captured = @(& $module { param($file) Invoke-SonarTool $file @() } $native 6>&1)
    Assert ($captured[-1].ExitCode -eq 9) 'Wrapper perdeu exit code nativo.'
    Assert (-not (($captured | Out-String).Contains($env:SONAR_TOKEN))) 'Wrapper exibiu token no terminal.'
    Assert (($captured | Out-String).Contains('[REDACTED]')) 'Wrapper nao mascarou saida.'
} finally { $env:SONAR_TOKEN=$savedNativeToken }
& $module {
    $script:Mode = 'OK'; $script:Calls = @(); $script:MetricReads=0
    function script:Invoke-SonarTool {
        param($Executable, $Arguments)
        $script:Calls += [pscustomobject]@{Args=$Arguments; Java=$env:JAVA_HOME; Token=$env:SONAR_TOKEN; Cwd=(Get-Location).Path; MavenArgs=$env:MAVEN_ARGS}
        if ($Arguments -contains '-version') { return [pscustomobject]@{ExitCode=0; Output='java version "21.0.1"'} }
        if ($Arguments -contains '--version') { return [pscustomobject]@{ExitCode=0; Output="Apache Maven 3.9.16`nJava version: 21.0.1"} }
        if ($script:Mode -eq 'MAVEN_FAIL') { return [pscustomobject]@{ExitCode=7; Output=$null} }
        $path = ($Arguments | Where-Object { $_ -like '-Dsonar.scanner.metadataFilePath=*' }).Substring(33)
        $server = 'http://localhost:9000'
        if ($script:Mode -eq 'WRONG_SERVER') { $server = 'https://wrong.example' }
        [IO.File]::WriteAllText($path, "projectKey=team:app`nserverUrl=$server`nceTaskId=task-1`nceTaskUrl=$server/api/ce/task?id=task-1")
        [pscustomobject]@{ExitCode=0; Output=$null}
    }
    function script:Invoke-SonarApiGet {
        param($ServerUrl, $Endpoint, $Query)
        if ($script:Mode -eq 'AUTH_FAIL') { throw 'SONAR_API_UNVERIFIED' }
        switch ($Endpoint) {
            'api/system/status' { [pscustomobject]@{status='UP'; version='2026.1'} }
            'api/components/show' { [pscustomobject]@{component=[pscustomobject]@{key='team:app'; qualifier='TRK'}} }
            'api/qualitygates/project_status' {
                if ($Query.analysisId -ne 'analysis-1') { throw 'Gate sem analysisId.' }
                $gate = if ($script:Mode -eq 'GATE_FAIL') { 'ERROR' } else { 'OK' }
                [pscustomobject]@{projectStatus=[pscustomobject]@{status=$gate; conditions=@()}}
            }
            'api/project_analyses/search' {
                $id = if ($script:Mode -eq 'RACE' -or ($script:Mode -eq 'RACE_AFTER' -and $script:MetricReads -gt 0)) { 'other-analysis' } else { 'analysis-1' }
                [pscustomobject]@{analyses=@([pscustomobject]@{key=$id})}
            }
            'api/ce/component' { [pscustomobject]@{queue=@()} }
            'api/measures/component' { $script:MetricReads++; [pscustomobject]@{component=[pscustomobject]@{key='team:app'; measures=@([pscustomobject]@{metric='coverage'; value='86.0'})}} }
            default { throw "API inesperada: $Endpoint" }
        }
    }
    function script:Wait-SonarComputeEngine {
        param($ServerUrl, $TaskId, $ProjectKey, $BranchName, $TimeoutSeconds)
        if ($script:Mode -eq 'CE_FAIL') { throw 'SONAR_CE_UNVERIFIED' }
        [pscustomobject]@{TaskId=$TaskId; AnalysisId='analysis-1'}
    }
}
$oldToken = $env:SONAR_TOKEN; $oldJava = $env:JAVA_HOME; $oldArgs = $env:MAVEN_ARGS
$secret = 'squ_TEST_ONLY_do_not_persist_987654321'
$secure = ConvertTo-SecureString $secret -AsPlainText -Force
try {
    $env:SONAR_TOKEN = 'previous-token'; $env:MAVEN_ARGS = 'deploy'
    $result = Invoke-HarnessSonar $context 'team:app' -Phase ANTES -Token $secure
    Assert ($result.Status -eq 'SUCCEEDED' -and $result.QualityGateStatus -eq 'OK' -and $result.MetricsStatus -eq 'MATCHED') 'Analise simulada deveria concluir.'
    Assert ($result.Project -eq 'app' -and $result.AnalysisId -eq 'analysis-1' -and $result.Phase -eq 'ANTES') 'Identidade perdida.'
    Assert ($result.MissingMetrics -contains 'duplicated_lines_density') 'Metrica ausente deve ficar explicita.'
    $run = Split-Path -Parent $result.ResultPath
    Assert ((Split-Path -Leaf $run) -match '^sonar_.*__[a-f0-9]{12}$') 'Convencao de pastas perdida.'
    $calls = @(& $module { $script:Calls }); $scan = $calls[-1]
    Assert (($scan.Args -join ' ') -notmatch 'sonar.token|sonar.login|squ_TEST') 'Token enviado por argumento.'
    Assert ($scan.Token -eq $secret -and -not $scan.MavenArgs -and $scan.Java -eq (Resolve-HarnessPath "$area/jdk21" $root)) 'Ambiente do scanner incorreto.'
    Assert ($scan.Args -contains ('-Dsonar.java.jdkHome=' + $context.Config.tools.applicationJdk8Home)) 'Java da aplicacao nao foi informado.'
    Assert ($env:SONAR_TOKEN -eq 'previous-token' -and $env:JAVA_HOME -eq $oldJava -and $env:MAVEN_ARGS -eq 'deploy') 'Ambiente nao restaurado.'
    $hash = (Get-FileHash $result.ResultPath).Hash
    foreach ($mode in @('GATE_FAIL','MAVEN_FAIL','AUTH_FAIL','CE_FAIL','WRONG_SERVER','RACE','RACE_AFTER')) {
        & $module { param($m) $script:Mode=$m; $script:MetricReads=0 } $mode
        $next = Invoke-HarnessSonar $context 'team:app' -Phase DEPOIS -Token $secure
        Assert ($next.Status -ne 'SUCCEEDED') "$mode virou sucesso."
        Assert ($next.ResultPath -ne $result.ResultPath) 'Historico sobrescrito.'
        if ($mode -eq 'GATE_FAIL') { Assert ($next.AnalysisStatus -eq 'SUCCESS' -and $next.QualityGateStatus -eq 'ERROR') 'Gate confundido com falha do scanner.' }
        if ($mode -like 'RACE*') { Assert ($next.MetricsStatus -eq 'UNVERIFIED' -and -not (Test-Path (Join-Path (Split-Path $next.ResultPath) 'measures.json'))) 'Metricas de outra analise exportadas.' }
    }
    Assert ((Get-FileHash $result.ResultPath).Hash -eq $hash) 'Recibo anterior alterado.'
    foreach ($file in Get-ChildItem -LiteralPath "$fixture/.harness/sonar" -Recurse -File) {
        Assert (-not ([IO.File]::ReadAllText($file.FullName).Contains($secret))) 'Token persistido.'
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
    $secure.Dispose(); $env:SONAR_TOKEN=$oldToken; $env:JAVA_HOME=$oldJava; $env:MAVEN_ARGS=$oldArgs
}
Write-Output 'PASS: Sonar simulado, identidade, gate, falhas, concorrencia, historico e token.'
