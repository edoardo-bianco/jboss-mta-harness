#requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'Harness.psm1') -DisableNameChecking

function Invoke-ApplicationTool {
    param([string]$Executable, [string[]]$Arguments, [string]$LogPath)
    # PS5.1 transforma stderr nativo em ErrorRecord, inclusive java -version.
    $savedPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $output = $null
        if ($LogPath) {
            & $Executable @Arguments 2>&1 | ForEach-Object { $_.ToString() } | Tee-Object -FilePath $LogPath | ForEach-Object { Write-Host $_ }
        } else { $output = (& $Executable @Arguments 2>&1 | ForEach-Object { $_.ToString() } | Out-String).Trim() }
        [pscustomobject]@{ExitCode=$LASTEXITCODE; Output=$output}
    } finally { $ErrorActionPreference = $savedPreference }
}

function Invoke-ApplicationBuild {
    param($Context, [ValidatePattern('^(clean|(?:clean )?(?:validate|compile|test|package|verify|install))$')][string]$Goals = 'clean verify')
    Import-Module (Join-Path $PSScriptRoot 'HarnessGit.psm1') -DisableNameChecking
    if ([string]::IsNullOrWhiteSpace($Goals)) { throw 'Informe as fases Maven.' }
    if (-not $Context.Active) { throw 'Escolha um projeto com -SelectTarget ou -Target; activeProject e o padrao opcional.' }
    $tool = $Context.Config.tools
    foreach ($name in @('applicationJdk8Home','applicationMavenHome')) {
        if (-not $tool.$name) { throw "Preencha tools.$name no JSON local." }
    }
    $java = Join-Path $tool.applicationJdk8Home 'bin/java.exe'
    $maven = Join-Path $tool.applicationMavenHome 'bin/mvn.cmd'
    $pom = Join-Path $Context.Active.path 'pom.xml'
    $files = @($java, (Join-Path $tool.applicationJdk8Home 'bin/javac.exe'), $maven, $pom)
    if ($tool.applicationMavenSettingsPath) { $files += $tool.applicationMavenSettingsPath }
    foreach ($file in $files) {
        if ($file -match '["%!^&|<>\r\n]') { throw 'Caminho contem caracteres nao suportados pelo launcher Maven Windows.' }
        if (-not (Test-Path -LiteralPath $file -PathType Leaf)) { throw "Arquivo ausente: $file" }
    }
    $state = Resolve-HarnessPath (Join-Path $Context.Root '.harness') $Context.Root
    $null = [IO.Directory]::CreateDirectory($state)
    # Mesmo lock do MTA: nao capturar fontes enquanto o build gera arquivos.
    try { $lock = [IO.File]::Open((Join-Path $state 'mta.lock'), 'OpenOrCreate', 'ReadWrite', 'None') }
    catch { throw 'Ja existe build ou analise MTA em execucao neste harness.' }
    $previous = @{}
    $pushed = $false
    $result = [ordered]@{Status='FAILED'; ExitCode=$null; Project=$Context.Active.name; Source=$Context.Active.path; Goals=$Goals; RunId=[guid]::NewGuid().ToString('N'); JavaHome=$tool.applicationJdk8Home; MavenHome=$tool.applicationMavenHome; SettingsPath=$tool.applicationMavenSettingsPath; JavaVersion=$null; MavenVersion=$null; StartedAtUtc=[DateTime]::UtcNow.ToString('o'); FinishedAtUtc=$null; LogPath=$null; ResultPath=$null; Error=$null}
    try {
        $result['Git'] = Get-HarnessGitState $Context
        $projectFolder = Get-HarnessProjectFolder $Context.Active
        do {
            $result.RunId = [guid]::NewGuid().ToString('N')
            $runFolder = 'build_' + (Format-HarnessDate $result.StartedAtUtc -ForPath) + '__' + $result.RunId.Substring(0,12)
            $run = Resolve-HarnessPath (Join-Path $state ('builds/' + $projectFolder + '/' + $runFolder)) $Context.Root
        } while (Test-Path -LiteralPath $run)
        $null = [IO.Directory]::CreateDirectory($run)
        $result.LogPath = Join-Path $run 'console.log'
        $result.ResultPath = Join-Path $run 'result.json'
        foreach ($name in @('JAVA_HOME','PATH','MAVEN_HOME','M2_HOME','MAVEN_ARGS','MAVEN_OPTS','JAVA_OPTS','JDK_JAVA_OPTIONS','JAVA_TOOL_OPTIONS','_JAVA_OPTIONS','MAVEN_SKIP_RC','MAVEN_BASEDIR','MAVEN_PROJECTBASEDIR','MAVEN_BATCH_PAUSE','MAVEN_BATCH_ECHO','SONAR_TOKEN')) {
            $previous[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
            [Environment]::SetEnvironmentVariable($name, $null, 'Process')
        }
        $env:JAVA_HOME = $tool.applicationJdk8Home
        $env:MAVEN_HOME = $tool.applicationMavenHome
        $env:M2_HOME = $tool.applicationMavenHome
        $env:MAVEN_SKIP_RC = 'true'
        $env:PATH = (Join-Path $tool.applicationJdk8Home 'bin') + ';' + (Join-Path $tool.applicationMavenHome 'bin') + ';' + $previous.PATH
        Push-Location -LiteralPath $Context.Active.path
        $pushed = $true
        Write-Host "Projeto: $($Context.Active.label) | Fonte: $($Context.Active.path)"
        Write-Host "Java: $env:JAVA_HOME | Maven: $env:MAVEN_HOME"
        Write-Host "Comando: mvn -Djacoco.haltOnFailure=false $Goals | Log: $($result.LogPath)"
        Write-Host 'Cobertura JaCoCo abaixo da meta gera aviso; falhas de compilacao e testes continuam reprovando.'
        $version = Invoke-ApplicationTool $java @('-version')
        $result.JavaVersion = $version.Output
        if ($version.ExitCode -ne 0 -or $version.Output -notmatch 'version "1\.8\.') { throw 'O build exige Java 8 efetivo.' }
        $version = Invoke-ApplicationTool $maven @('--version')
        $result.MavenVersion = $version.Output
        if ($version.ExitCode -ne 0 -or $version.Output -notmatch 'Apache Maven 3\.' -or $version.Output -notmatch 'Java version: 1\.8\.') { throw 'Maven deve executar com Java 8; confira sua versao e configuracao .mvn.' }
        Write-Host $version.Output
        $arguments = @('-B', '-f', $pom, '-Djacoco.haltOnFailure=false')
        if ($tool.applicationMavenSettingsPath) { $arguments += @('-s', $tool.applicationMavenSettingsPath) }
        $arguments += $Goals.Split(' ')
        $execution = Invoke-ApplicationTool $maven $arguments $result.LogPath
        $result.ExitCode = $execution.ExitCode
        if ($execution.ExitCode -eq 0) { $result.Status = 'SUCCEEDED' }
    } catch { $result.Error = $_.Exception.Message }
    finally {
        if ($pushed) { Pop-Location }
        foreach ($name in $previous.Keys) { [Environment]::SetEnvironmentVariable($name, $previous[$name], 'Process') }
        $result.FinishedAtUtc = [DateTime]::UtcNow.ToString('o')
        try { if ($result.ResultPath) { Write-HarnessJson $result.ResultPath $result } } finally { $lock.Dispose() }
    }
    return [pscustomobject]$result
}

Export-ModuleMember -Function Invoke-ApplicationBuild
