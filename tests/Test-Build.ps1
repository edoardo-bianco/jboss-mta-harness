#requires -Version 5.1
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $root 'scripts/Harness.psm1') -Force
Import-Module (Join-Path $root 'scripts/HarnessBuild.psm1') -Force
function Assert($condition, $message) { if (-not $condition) { throw $message } }
$area = Join-Path $root ('.harness/tests/' + [guid]::NewGuid().ToString('N'))
$fixture = Join-Path $area 'harness'
$app = Join-Path $area 'app com espaco'
$jdk = Join-Path $area 'jdk app'
$maven = Join-Path $area 'maven app'
foreach ($dir in @($app, "$jdk/bin", "$maven/bin")) { $null = New-Item -ItemType Directory -Path $dir -Force }
foreach ($file in @("$app/pom.xml", "$jdk/bin/java.exe", "$jdk/bin/javac.exe", "$maven/bin/mvn.cmd", "$area/settings app.xml")) { Set-Content $file '' }
$config = Get-Content (Join-Path $root 'config/harness.example.json') -Raw | ConvertFrom-Json
$config.repositories = @(@{name='app'; path=$app})
$config.activeProject = 'app'
$config.tools.applicationJdk8Home = $jdk
$config.tools.applicationMavenHome = $maven
$config.tools.applicationMavenSettingsPath = "$area/settings app.xml"
$config.tools.mavenHome = "$area/maven mta ausente"
$config.tools.mtaJdkHome = "$area/jdk mta ausente"
$configPath = Join-Path $fixture 'config.json'
Write-HarnessJson $configPath $config
$workspacePath = Join-Path $fixture 'build.code-workspace'
Write-HarnessJson $workspacePath @{folders=@(@{name='app'; path=$app})}
$context = Read-HarnessConfig $configPath $fixture -WorkspacePath $workspacePath -Target 'app'
$module = Get-Module HarnessBuild
& $module {
    $script:Calls = @(); $script:Failure = 0; $script:JavaVersion = '1.8.0_504'
    function script:Invoke-ApplicationTool {
        param($Executable, $Arguments, $LogPath)
        $script:Calls += [pscustomobject]@{Executable=$Executable; Arguments=$Arguments; Java=$env:JAVA_HOME; Maven=$env:MAVEN_HOME; Path=$env:PATH; Cwd=(Get-Location).Path; Injected=$env:MAVEN_ARGS}
        if ($Arguments -contains '-version') { return [pscustomobject]@{ExitCode=0; Output=('java version "' + $script:JavaVersion + '"')} }
        if ($Arguments -contains '--version') { return [pscustomobject]@{ExitCode=0; Output="Apache Maven 3.9.16`nJava version: $script:JavaVersion, vendor: test`nJava home: $env:JAVA_HOME\jre"} }
        Set-Content $LogPath 'simulated build'
        return [pscustomobject]@{ExitCode=$script:Failure; Output=$null}
    }
}
$beforeJava = $env:JAVA_HOME; $beforePath = $env:PATH; $beforeArgs = $env:MAVEN_ARGS
try {
    $env:MAVEN_ARGS = 'deploy'
    $result = Invoke-ApplicationBuild $context 'clean install'
    Assert ($result.Status -eq 'SUCCEEDED' -and $result.ExitCode -eq 0) 'clean install falhou.'
    Assert ($result.Project -eq $context.Active.name -and $result.Source -eq $app) 'Recibo nao pertence ao projeto escolhido no workspace.'
    $run = Split-Path -Parent $result.ResultPath
    Assert ((Split-Path -Leaf (Split-Path -Parent $run)) -match '^app__[a-f0-9]{12}$') 'Build deve usar nome e chave do projeto.'
    $runName = 'build_' + ([DateTimeOffset]::Parse($result.StartedAtUtc)).ToLocalTime().ToString('yyyy-MM-dd_HH-mm-sszzz').Replace(':','') + '__' + $result.RunId.Substring(0,12)
    Assert ((Split-Path -Leaf $run) -ceq $runName -and $result.RunId.Length -eq 32) 'Build deve compartilhar data com recibo e preservar RunId completo.'
    $resultHash = (Get-FileHash -LiteralPath $result.ResultPath).Hash
    $calls = @(& $module { $script:Calls })
    $build = $calls[-1]
    Assert (($build.Arguments[-2..-1] -join ' ') -eq 'clean install') 'Ordem clean install perdida.'
    Assert ($build.Arguments -contains '-Djacoco.haltOnFailure=false') 'Cobertura deve gerar aviso sem reprovar o build.'
    Assert (-not ($build.Arguments -match 'skipTests|maven.test.failure.ignore|jacoco.skip')) 'Politica de cobertura nao pode ignorar testes ou relatorios.'
    Assert ($build.Java -eq $jdk -and $build.Maven -eq $maven) 'Build usou ferramentas do MTA.'
    Assert ($build.Cwd -eq $app -and $build.Executable -eq (Join-Path $maven 'bin/mvn.cmd')) 'Alvo/executavel errado.'
    Assert ($build.Arguments -contains $context.Config.tools.applicationMavenSettingsPath) 'Settings com espaco perdido.'
    Assert (-not $build.Injected) 'MAVEN_ARGS herdado alterou os comandos.'
    Assert ($env:JAVA_HOME -ceq $beforeJava -and $env:PATH -ceq $beforePath -and $env:MAVEN_ARGS -eq 'deploy') 'Ambiente nao restaurado.'
    Assert (Test-Path $result.ResultPath) 'Recibo ausente.'
    & $module { $script:Failure = 7 }
    $failed = Invoke-ApplicationBuild $context 'test'
    Assert ($failed.Status -eq 'FAILED' -and $failed.ExitCode -eq 7) 'Falha Maven virou sucesso.'
    Assert ($failed.ResultPath -ne $result.ResultPath -and (Split-Path -Leaf (Split-Path -Parent $failed.ResultPath)) -like 'build_*') 'Falha deve manter recibo em nova pasta legivel.'
    Assert ((Get-FileHash -LiteralPath $result.ResultPath).Hash -ceq $resultHash) 'Nova execucao alterou recibo anterior.'
    Assert ($env:JAVA_HOME -ceq $beforeJava -and $env:PATH -ceq $beforePath) 'Falha nao restaurou ambiente.'
    & $module { $script:Calls = @(); $script:JavaVersion = '25.0.3' }
    $wrong = Invoke-ApplicationBuild $context 'verify'
    Assert ($wrong.Status -eq 'FAILED') 'Java nao 8 aceito.'
    Assert (@(& $module { $script:Calls }).Count -eq 1) 'Maven rodou apos rejeitar Java.'
    $lock = [IO.File]::Open((Join-Path $fixture '.harness/mta.lock'), 'OpenOrCreate', 'ReadWrite', 'None')
    try {
        $rejected = $false
        try { Invoke-ApplicationBuild $context 'verify' | Out-Null } catch { $rejected = $true }
        Assert $rejected 'Build concorrente com MTA aceito.'
    } finally { $lock.Dispose() }
    foreach ($goals in @('clean install & whoami', 'deploy', '')) {
        $rejected = $false
        try { Invoke-ApplicationBuild $context $goals | Out-Null } catch { $rejected = $true }
        Assert $rejected 'Comando invalido aceito.'
    }
    $context.Config.tools.applicationMavenHome = $null
    $rejected = $false
    try { Invoke-ApplicationBuild $context 'verify' | Out-Null } catch { $rejected = $true }
    Assert $rejected 'Build sem Maven proprio aceito.'
} finally { $env:MAVEN_ARGS = $beforeArgs }
Write-Output 'PASS: clean install, ferramentas separadas, alvo, settings, ambiente, falha, Java 8 e lock.'
