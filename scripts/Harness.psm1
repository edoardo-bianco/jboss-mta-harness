#requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if ($PSVersionTable.PSVersion.Major -ne 5 -or $PSVersionTable.PSVersion.Minor -ne 1) { throw 'Use Windows PowerShell 5.1 (powershell.exe).' }

function Resolve-HarnessPath {
    param([AllowNull()][string]$Value, [string]$Root)
    if ([string]::IsNullOrWhiteSpace($Value)) { return $null }
    if ($Value -match '[*?\x00-\x1f]' -or $Value.Contains('${')) { throw "Caminho invalido: $Value" }
    if (-not [IO.Path]::IsPathRooted($Value)) { $Value = Join-Path $Root $Value }
    if ($Value -notmatch '^[A-Za-z]:[\\/]') { throw 'Use caminhos locais absolutos ou relativos a pasta do harness.' }
    $full = [IO.Path]::GetFullPath($Value).TrimEnd('\', '/')
    $check = $full
    while ($check) {
        if (Test-Path -LiteralPath $check) {
            if ((Get-Item -LiteralPath $check -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "Link/junction nao suportado: $check" }
        }
        $parent = Split-Path -Parent $check
        if ($parent -eq $check) { break }
        $check = $parent
    }
    return $full
}

function Write-HarnessJson {
    param([string]$Path, $Value)
    $null = [IO.Directory]::CreateDirectory((Split-Path -Parent $Path))
    [IO.File]::WriteAllText($Path, ($Value | ConvertTo-Json -Depth 12), (New-Object Text.UTF8Encoding($false)))
}

function Read-HarnessConfig {
    param([string]$Path, [string]$Root = (Split-Path -Parent $PSScriptRoot))
    $Root = Resolve-HarnessPath $Root $Root
    $Path = Resolve-HarnessPath $Path $Root
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw 'Configure primeiro: Terminal > Run Task > Workspace: configurar caminhos.' }
    $config = Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($config.schemaVersion -ne 1) { throw 'schemaVersion deve ser 1.' }
    $names = @{}
    foreach ($repo in $config.repositories) {
        if ($repo.name -notmatch '^[A-Za-z0-9][A-Za-z0-9_.-]{0,63}$' -or $repo.name -ieq 'harness' -or $names.ContainsKey($repo.name)) { throw 'Nome de repositorio invalido ou duplicado.' }
        $names[$repo.name] = $true
        $repo.path = Resolve-HarnessPath $repo.path $Root
        if (-not $repo.path -or -not (Test-Path -LiteralPath $repo.path -PathType Container)) { throw "Pasta ausente para o repositorio $($repo.name). Ajuste config/harness.local.json." }
        if ($repo.path -ieq $Root -or $Root.StartsWith($repo.path + '\', [StringComparison]::OrdinalIgnoreCase) -or $repo.path.StartsWith($Root + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Mantenha os repositorios de aplicacao fora da pasta do harness.' }
    }
    $active = $null
    if ($config.activeProject) {
        $selected = @($config.repositories | Where-Object name -eq $config.activeProject)
        if ($selected.Count -ne 1) { throw 'activeProject deve corresponder ao name de um repositorio.' }
        $active = $selected[0]
    }
    foreach ($field in @('mtaExecutable','mtaJdkHome','mavenHome','mavenSettingsPath','applicationJdk8Home','eap71Home','eap74Home')) {
        $config.tools.$field = Resolve-HarnessPath $config.tools.$field $Root
    }
    $config.mta.rulesPath = Resolve-HarnessPath $config.mta.rulesPath $Root
    if ($config.mta.mode -cnotin @('full','source-only')) { throw 'mta.mode deve ser full ou source-only.' }
    if (@($config.mta.targets).Count -eq 0) { throw 'Informe pelo menos um target MTA.' }
    foreach ($target in $config.mta.targets) { if ($target -notmatch '^[A-Za-z0-9_.-]+$') { throw 'Target MTA invalido.' } }
    [pscustomobject]@{ Root=$Root; ConfigPath=$Path; Config=$config; Active=$active }
}

function New-HarnessWorkspace {
    param($Context)
    $folders = @([ordered]@{name='harness'; path='.'})
    foreach ($repo in $Context.Config.repositories) { $folders += [ordered]@{name=$repo.name; path=$repo.path} }
    $settings = [ordered]@{
        'java.autobuild.enabled'=$false
        'java.configuration.updateBuildConfiguration'='disabled'
        'java.import.generatesMetadataFilesAtProjectRoot'=$false
        'files.exclude'=@{ '**/.harness'=$true }
    }
    if ($Context.Config.tools.applicationJdk8Home) {
        $settings['java.configuration.runtimes'] = @(@{name='JavaSE-1.8'; path=$Context.Config.tools.applicationJdk8Home; default=$true})
    }
    if ($Context.Config.tools.mtaJdkHome) { $settings['java.jdt.ls.java.home'] = $Context.Config.tools.mtaJdkHome }
    if ($Context.Config.tools.mavenHome) { $settings['maven.executable.path'] = Join-Path $Context.Config.tools.mavenHome 'bin/mvn.cmd' }
    if ($Context.Config.tools.mavenSettingsPath) { $settings['java.configuration.maven.userSettings'] = $Context.Config.tools.mavenSettingsPath }
    $path = Join-Path $Context.Root 'jboss-mta-harness.local.code-workspace'
    if (Test-Path -LiteralPath $path) {
        $backup = Join-Path $Context.Root ('.harness/workspace-backups/' + [guid]::NewGuid().ToString('N') + '.code-workspace')
        $null = [IO.Directory]::CreateDirectory((Split-Path -Parent $backup))
        Copy-Item -LiteralPath $path -Destination $backup
    }
    Write-HarnessJson $path ([ordered]@{folders=$folders; settings=$settings})
    return $path
}

function Get-MtaRequirements {
    param($Context)
    $tool = $Context.Config.tools
    if (-not $Context.Active) { throw 'Preencha repositories e activeProject no JSON local.' }
    foreach ($name in @('mtaExecutable','mtaJdkHome','mavenHome')) {
        if (-not $tool.$name) { throw "Preencha tools.$name no JSON local." }
    }
    if ([IO.Path]::GetExtension($tool.mtaExecutable) -ine '.exe') { throw 'mtaExecutable deve apontar para a CLI .exe do ZIP Windows.' }
    foreach ($file in @($tool.mtaExecutable, (Join-Path $tool.mtaJdkHome 'bin/java.exe'), (Join-Path $tool.mtaJdkHome 'bin/javac.exe'), (Join-Path $tool.mavenHome 'bin/mvn.cmd'), (Join-Path $Context.Active.path 'pom.xml'))) {
        if (-not (Test-Path -LiteralPath $file -PathType Leaf)) { throw "Arquivo ausente: $file" }
    }
    if ($tool.mavenSettingsPath -and -not (Test-Path -LiteralPath $tool.mavenSettingsPath -PathType Leaf)) { throw 'mavenSettingsPath nao existe.' }
    $rules = $Context.Config.mta.rulesPath
    if (-not $rules) { $rules = Join-Path (Split-Path -Parent $tool.mtaExecutable) 'rulesets/java' }
    $rules = Resolve-HarnessPath $rules $Context.Root
    if (-not (Test-Path -LiteralPath $rules -PathType Container)) { throw 'Regras Java nao encontradas. Preencha mta.rulesPath com a pasta Java da distribuicao MTA.' }
    return $rules
}

function Get-HarnessFiles {
    param([string]$Root, [switch]$Rules)
    $files = New-Object 'Collections.Generic.List[object]'
    $pending = New-Object 'Collections.Generic.Stack[string]'
    $pending.Push($Root)
    while ($pending.Count) {
        $directory = $pending.Pop()
        foreach ($item in Get-ChildItem -LiteralPath $directory -Force) {
            if ($item.PSIsContainer -and $item.Name -in @('.git','.harness','.scannerwork','node_modules')) { continue }
            if ($item.PSIsContainer -and $Rules -and $item.Name -in @('test','tests')) { continue }
            if ($item.PSIsContainer -and -not $Rules -and $item.Name -eq 'target' -and (Test-Path -LiteralPath (Join-Path $directory 'pom.xml'))) { continue }
            if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "Link/junction na entrada: $($item.FullName)" }
            if ($item.PSIsContainer) { $pending.Push($item.FullName); continue }
            if ($Rules -and $item.Extension -notin @('.yaml','.yml')) { continue }
            $files.Add([pscustomobject]@{path=$item.FullName.Substring($Root.Length + 1).Replace('\','/'); sha256=(Get-FileHash -LiteralPath $item.FullName -Algorithm SHA256).Hash})
        }
    }
    return @($files | Sort-Object path)
}

function Copy-HarnessFiles {
    param([string]$Source, [string]$Destination, [object[]]$Files)
    foreach ($file in $Files) {
        $target = Join-Path $Destination $file.path
        $null = [IO.Directory]::CreateDirectory((Split-Path -Parent $target))
        Copy-Item -LiteralPath (Join-Path $Source $file.path) -Destination $target
        if ((Get-FileHash -LiteralPath $target).Hash -ine $file.sha256) { throw 'Entrada mudou durante a copia; repita com fontes estaveis.' }
    }
}

function New-MtaSnapshot {
    param($Context)
    $rules = Get-MtaRequirements $Context
    $id = [guid]::NewGuid().ToString('N')
    $run = Resolve-HarnessPath (Join-Path $Context.Root ('.harness/runs/' + $Context.Active.name + '/' + $id)) $Context.Root
    $inputPath = Join-Path $run 'input'
    $outputPath = Join-Path $run 'output'
    $sourceFiles = @(Get-HarnessFiles $Context.Active.path)
    $ruleFiles = @(Get-HarnessFiles $rules -Rules)
    if ($ruleFiles.Count -eq 0) { throw 'Nenhuma regra YAML encontrada.' }
    Copy-HarnessFiles $Context.Active.path $inputPath $sourceFiles
    Copy-HarnessFiles $rules (Join-Path $run 'rules') $ruleFiles
    $arguments = @('analyze','--input',$inputPath,'--output',$outputPath,'--run-local','--mode',$Context.Config.mta.mode,'--enable-default-rulesets=false','--rules',(Join-Path $run 'rules'))
    foreach ($target in $Context.Config.mta.targets) { $arguments += @('--target',$target) }
    if ($Context.Config.tools.mavenSettingsPath) { $arguments += @('--maven-settings',$Context.Config.tools.mavenSettingsPath) }
    $manifest = [ordered]@{
        RunId=$id; Project=$Context.Active.name; Source=$Context.Active.path; CreatedAtUtc=[DateTime]::UtcNow.ToString('o')
        Executable=$Context.Config.tools.mtaExecutable; ExecutableSha256=(Get-FileHash -LiteralPath $Context.Config.tools.mtaExecutable).Hash
        MtaJdkHome=$Context.Config.tools.mtaJdkHome; MavenHome=$Context.Config.tools.mavenHome
        Arguments=$arguments; SourceFiles=$sourceFiles; RuleFiles=$ruleFiles
    }
    Write-HarnessJson (Join-Path $run 'manifest.json') $manifest
    [pscustomobject]@{Run=$run; Input=$inputPath; Output=$outputPath; Manifest=$manifest}
}

function Invoke-HarnessMtaTool {
    param([string]$Executable, [string[]]$Arguments, [string]$LogPath)
    $savedPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $output = $null
        if ($LogPath) {
            & $Executable @Arguments 2>&1 | Tee-Object -FilePath $LogPath | ForEach-Object { Write-Host $_ }
        } else { $output = (& $Executable @Arguments 2>&1 | Out-String).Trim() }
        [pscustomobject]@{ExitCode=$LASTEXITCODE; Output=$output}
    } finally { $ErrorActionPreference = $savedPreference }
}

function Invoke-MtaAnalysis {
    param($Context)
    $stateRoot = Resolve-HarnessPath (Join-Path $Context.Root '.harness') $Context.Root
    $null = [IO.Directory]::CreateDirectory($stateRoot)
    try { $lock = [IO.File]::Open((Join-Path $stateRoot 'mta.lock'), 'OpenOrCreate', 'ReadWrite', 'None') }
    catch { throw 'Ja existe uma analise MTA em execucao neste harness.' }
    $snapshot = $null
    $previous = @{}
    foreach ($name in @('JAVA_HOME','PATH','JVM_MAX_MEM','SONAR_TOKEN','MAVEN_HOME','M2_HOME','JAVA_OPTS','MAVEN_OPTS','JDK_JAVA_OPTIONS','JAVA_TOOL_OPTIONS','_JAVA_OPTIONS')) { $previous[$name] = [Environment]::GetEnvironmentVariable($name, 'Process') }
    $result = [ordered]@{Status='FAILED'; ExitCode=$null; Project=$Context.Config.activeProject; RunId=$null; ReportPath=$null; ResultPath=$null; SourceUnchanged=$null; SnapshotOriginalFilesUnchanged=$null; UnexpectedAddedFiles=@(); RulesUnchanged=$null; Version=$null; Error=$null}
    $pushed = $false
    try {
        $snapshot = New-MtaSnapshot $Context
        $result.RunId = $snapshot.Manifest.RunId
        $result.ReportPath = Join-Path $snapshot.Output 'static-report/index.html'
        $result.ResultPath = Join-Path $snapshot.Run 'result.json'
        $tool = $Context.Config.tools
        $env:JAVA_HOME = $tool.mtaJdkHome
        $env:MAVEN_HOME = $tool.mavenHome
        $env:M2_HOME = $tool.mavenHome
        foreach ($name in @('JAVA_OPTS','MAVEN_OPTS','JDK_JAVA_OPTIONS','JAVA_TOOL_OPTIONS','_JAVA_OPTIONS')) { [Environment]::SetEnvironmentVariable($name,$null,'Process') }
        $env:PATH = (Join-Path $tool.mtaJdkHome 'bin') + ';' + (Join-Path $tool.mavenHome 'bin') + ';' + (Split-Path -Parent $tool.mtaExecutable) + ';' + $previous.PATH
        $env:JVM_MAX_MEM = '2g'
        $env:SONAR_TOKEN = $null
        Push-Location -LiteralPath $snapshot.Run
        $pushed = $true
        Write-Host "Projeto: $($Context.Active.name) | Fonte: $($Context.Active.path)"
        Write-Host "Rodada: $($snapshot.Run) | Modo: $($Context.Config.mta.mode)"
        $version = Invoke-HarnessMtaTool $tool.mtaExecutable @('version')
        $result.Version = $version.Output
        if ($version.ExitCode -eq 0) {
            $execution = Invoke-HarnessMtaTool $tool.mtaExecutable $snapshot.Manifest.Arguments (Join-Path $snapshot.Run 'console.log')
            $result.ExitCode = $execution.ExitCode
        } else { $result.ExitCode = $version.ExitCode; $result.Error = 'Falha ao consultar a versao MTA.' }
        $sourceAfter = @(Get-HarnessFiles $Context.Active.path)
        $inputAfter = @(Get-HarnessFiles $snapshot.Input)
        $rulesAfter = @(Get-HarnessFiles (Join-Path $snapshot.Run 'rules') -Rules)
        $beforeMap = @{}; $afterMap = @{}
        foreach ($file in $snapshot.Manifest.SourceFiles) { $beforeMap[$file.path]=$file.sha256 }
        foreach ($file in $inputAfter) { $afterMap[$file.path]=$file.sha256 }
        $changed = @($snapshot.Manifest.SourceFiles | Where-Object { $afterMap[$_.path] -cne $_.sha256 })
        $known = @('.classpath','.project','.settings/org.eclipse.core.resources.prefs','.settings/org.eclipse.jdt.apt.core.prefs','.settings/org.eclipse.jdt.core.prefs','.settings/org.eclipse.m2e.core.prefs')
        $result.UnexpectedAddedFiles = @($inputAfter | Where-Object { -not $beforeMap.ContainsKey($_.path) -and $_.path -notin $known } | Select-Object -ExpandProperty path)
        $result.SnapshotOriginalFilesUnchanged = ($changed.Count -eq 0)
        $result.SourceUnchanged = (($sourceAfter | ConvertTo-Json -Depth 4 -Compress) -ceq ($snapshot.Manifest.SourceFiles | ConvertTo-Json -Depth 4 -Compress))
        $result.RulesUnchanged = (($rulesAfter | ConvertTo-Json -Depth 4 -Compress) -ceq ($snapshot.Manifest.RuleFiles | ConvertTo-Json -Depth 4 -Compress))
        if (-not $result.SourceUnchanged -or -not $result.SnapshotOriginalFilesUnchanged -or -not $result.RulesUnchanged -or $result.UnexpectedAddedFiles.Count) { $result.Status='INPUT_CHANGED' }
        elseif ($result.ExitCode -eq 0 -and (Test-Path -LiteralPath $result.ReportPath -PathType Leaf) -and (Test-Path -LiteralPath (Join-Path $snapshot.Output 'output.yaml'))) {
            $result.Status='SUCCEEDED'
            Write-HarnessJson (Join-Path $stateRoot ('last-' + $result.Project + '.json')) @{RunId=$result.RunId}
        }
    } catch { $result.Error = $_.Exception.Message }
    finally {
        if ($pushed) { Pop-Location }
        foreach ($name in $previous.Keys) { [Environment]::SetEnvironmentVariable($name,$previous[$name],'Process') }
        try { if ($result.ResultPath) { Write-HarnessJson $result.ResultPath $result } } finally { $lock.Dispose() }
    }
    [pscustomobject]$result
}

function Get-LastMtaReport {
    param($Context)
    if (-not $Context.Active) { throw 'Selecione activeProject no JSON.' }
    $state = Join-Path $Context.Root ('.harness/last-' + $Context.Active.name + '.json')
    if (-not (Test-Path -LiteralPath $state)) { throw 'Nao ha analise concluida para o projeto ativo.' }
    $last = Get-Content -LiteralPath $state -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($last.RunId -cnotmatch '^[a-f0-9]{32}$') { throw 'Referencia de relatorio invalida.' }
    $run = Resolve-HarnessPath (Join-Path $Context.Root ('.harness/runs/' + $Context.Active.name + '/' + $last.RunId)) $Context.Root
    $result = Get-Content -LiteralPath (Join-Path $run 'result.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    $path = Join-Path $run 'output/static-report/index.html'
    if ($result.Status -cne 'SUCCEEDED' -or -not (Test-Path -LiteralPath $path -PathType Leaf)) { throw 'Relatorio ausente ou rodada nao concluida.' }
    return $path
}

Export-ModuleMember -Function Read-HarnessConfig, New-HarnessWorkspace, Write-HarnessJson, Resolve-HarnessPath, Get-MtaRequirements, New-MtaSnapshot, Invoke-MtaAnalysis, Get-LastMtaReport
