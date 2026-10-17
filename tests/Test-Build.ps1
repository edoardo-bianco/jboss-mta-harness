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
[IO.File]::WriteAllText((Join-Path $app 'pom.xml'),'<project><artifactId>app</artifactId></project>')
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
$context = Read-HarnessConfig $configPath $fixture -WorkspacePath $workspacePath -Target 'app' -SkipMigrationInitialization
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
    Assert ($result.Project -eq 'app' -and $result.Source -eq $app) 'Resultado nao pertence ao artifactId do projeto escolhido.'
    $run = Split-Path -Parent $result.ResultPath
    Assert ($run -eq (Join-Path $fixture '.harness/projetos/app/atual/build')) 'Build deve usar destino fixo por artifactId.'
    Assert (-not $result.PSObject.Properties['RunId']) 'Resultado nao deve exigir recibo/RunId.'
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
    Assert (Test-Path $result.ResultPath) 'Resultado corrente ausente.'
    & $module { $script:Failure = 7 }
    $failed = Invoke-ApplicationBuild $context 'test'
    Assert ($failed.Status -eq 'FAILED' -and $failed.ExitCode -eq 7) 'Falha Maven virou sucesso.'
    Assert ($failed.ResultPath -eq $result.ResultPath) 'Falha deve ocupar o mesmo destino corrente.'
    $current=Get-Content -LiteralPath $failed.ResultPath -Raw | ConvertFrom-Json
    Assert ($current.Status -eq 'FAILED' -and $current.ExitCode -eq 7) 'Ultima tentativa deve mostrar a falha.'
    Assert ($env:JAVA_HOME -ceq $beforeJava -and $env:PATH -ceq $beforePath) 'Falha nao restaurou ambiente.'
    & $module { $script:Calls = @(); $script:JavaVersion = '25.0.3' }
    $wrong = Invoke-ApplicationBuild $context 'verify'
    Assert ($wrong.Status -eq 'FAILED') 'Java nao 8 aceito.'
    Assert (@(& $module { $script:Calls }).Count -eq 1) 'Maven rodou apos rejeitar Java.'
    Assert (-not (Test-Path (Join-Path $fixture '.harness/mta.lock'))) 'Build nao deixa lock/ponteiro legado em disco.'
    Assert (-not (Test-Path (Join-Path $fixture '.harness/projetos/app/temporarios'))) 'Temporarios devem ser retirados ao terminar.'
    $operation=Get-Content (Join-Path $fixture '.harness/projetos/app/atual/operacao.json') -Raw | ConvertFrom-Json
    Assert ($operation.build.Status -eq 'FAILED' -and $operation.build.Error -match 'Java 8') 'Situacao corrente explica a ultima falha.'
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
Write-Output 'PASS: build corrente, ferramentas separadas, settings, ambiente, falha, Java 8 e ausencia de recibos.'
