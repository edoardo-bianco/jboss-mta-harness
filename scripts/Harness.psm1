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

function Read-HarnessWorkspaceProjects {
    param([string]$WorkspacePath, [string]$Root)
    $WorkspacePath = Resolve-HarnessPath $WorkspacePath $Root
    $json = Get-Content -LiteralPath $WorkspacePath -Raw -Encoding UTF8
    # JSONC: preservar strings (inclusive URLs), remover comentarios e virgulas finais.
    $json = [regex]::Replace($json, '"(?:\\.|[^"\\])*"|//[^\r\n]*|/\*[\s\S]*?\*/', {
        param($match)
        if ($match.Value.StartsWith('"')) { $match.Value } else { ' ' }
    })
    $json = [regex]::Replace($json, '"(?:\\.|[^"\\])*"|,\s*(?=[}\]])', {
        param($match)
        if ($match.Value.StartsWith('"')) { $match.Value } else { '' }
    })
    $workspace = $json | ConvertFrom-Json
    $seen = @{}
    foreach ($folder in $workspace.folders) {
        if (-not $folder.PSObject.Properties['path']) { continue }
        $projectPath = Resolve-HarnessPath $folder.path (Split-Path -Parent $WorkspacePath)
        if (-not $projectPath -or $projectPath -ieq $Root -or $seen.ContainsKey($projectPath)) { continue }
        if (-not (Test-Path -LiteralPath (Join-Path $projectPath 'pom.xml') -PathType Leaf)) { continue }
        $seen[$projectPath] = $true
        $label = Split-Path $projectPath -Leaf
        if ($folder.PSObject.Properties['name'] -and $folder.name) { $label = $folder.name }
        # Identidade pelo caminho: renomear no Explorer nao perde o historico.
        $sha = [Security.Cryptography.SHA256]::Create()
        try { $hash = [BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($projectPath.ToLowerInvariant()))).Replace('-', '').ToLowerInvariant() }
        finally { $sha.Dispose() }
        [pscustomobject]@{name=('_workspace-' + $hash.Substring(0,24)); label=$label; path=$projectPath}
    }
}

function Select-HarnessProject {
    param([object[]]$Projects, [string]$Default, [string]$Target, [switch]$Interactive)
    $defaultProjects = @($Projects | Where-Object { $_.label -ieq $Default -or $_.name -ieq $Default -or $_.path -ieq $Default })
    if ($Interactive -and -not $Target) {
        if (-not $Projects.Count) { throw 'Nenhum projeto com pom.xml no workspace. Use File > Add Folder to Workspace e salve o workspace.' }
        Write-Host 'Escolha o projeto Maven desta execucao (inclui agregadores e packaging pom):'
        for ($index = 0; $index -lt $Projects.Count; $index++) {
            $mark = ''
            if ($defaultProjects.Count -eq 1 -and $Projects[$index].name -eq $defaultProjects[0].name) { $mark = ' [padrao: Enter]' }
            Write-Host ("{0}. {1} | {2}{3}" -f ($index + 1), $Projects[$index].label, $Projects[$index].path, $mark)
        }
        $answer = Read-Host 'Numero do projeto (q cancela)'
        if ([string]::IsNullOrWhiteSpace($answer) -and $defaultProjects.Count -eq 1) { return $defaultProjects[0] }
        $choice = 0
        if (-not [int]::TryParse($answer, [ref]$choice) -or $choice -lt 1 -or $choice -gt $Projects.Count) { throw 'Selecao cancelada ou invalida; nenhuma operacao iniciada.' }
        return $Projects[$choice - 1]
    }
    if ($Target) {
        $selected = @($Projects | Where-Object { $_.label -ieq $Target -or $_.name -ieq $Target -or $_.path -ieq $Target })
        if ($selected.Count -ne 1) { throw 'Target ausente ou ambiguo. Escolha um projeto da lista ou informe seu caminho completo.' }
        return $selected[0]
    }
    if ($defaultProjects.Count -eq 1) { return $defaultProjects[0] }
    return $null
}

function Read-HarnessConfig {
    param([string]$Path, [string]$Root = (Split-Path -Parent $PSScriptRoot), [string]$WorkspacePath, [string]$Target, [switch]$SelectTarget)
    $Root = Resolve-HarnessPath $Root $Root
    $Path = Resolve-HarnessPath $Path $Root
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw 'Configure primeiro: Terminal > Run Task > Workspace: configurar caminhos.' }
    $config = Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($config.schemaVersion -ne 1) { throw 'schemaVersion deve ser 1.' }
    if (-not $config.PSObject.Properties['repositories']) { $config | Add-Member NoteProperty repositories @() }
    if (-not $config.PSObject.Properties['activeProject']) { $config | Add-Member NoteProperty activeProject $null }
    $projects = @($config.repositories)
    if ($WorkspacePath) { $projects = @(Read-HarnessWorkspaceProjects $WorkspacePath $Root) }
    $names = @{}
    foreach ($repo in $projects) {
        if ((-not $WorkspacePath -and ($repo.name -notmatch '^[A-Za-z0-9][A-Za-z0-9_.-]{0,63}$' -or $repo.name -ieq 'harness')) -or $names.ContainsKey($repo.name)) { throw 'Nome de repositorio invalido ou duplicado.' }
        if (-not $repo.PSObject.Properties['label']) { $repo | Add-Member NoteProperty label $repo.name }
        $names[$repo.name] = $true
        $repo.path = Resolve-HarnessPath $repo.path $Root
        if (-not $repo.path -or -not (Test-Path -LiteralPath $repo.path -PathType Container)) { throw "Pasta ausente para o repositorio $($repo.name). Ajuste config/harness.local.json." }
        $bundledExamples = @((Join-Path $Root 'exemplos/migracao-cache-antes'), (Join-Path $Root 'exemplos/migracao-cache-depois')) | ForEach-Object { [IO.Path]::GetFullPath($_) }
        if ($repo.path -ieq $Root -or $Root.StartsWith($repo.path + '\', [StringComparison]::OrdinalIgnoreCase) -or ($repo.path.StartsWith($Root + '\', [StringComparison]::OrdinalIgnoreCase) -and $repo.path -notin $bundledExamples)) { throw 'Use os dois exemplos incluidos ou mantenha os repositorios de aplicacao fora da pasta do harness.' }
    }
    $active = Select-HarnessProject $projects $config.activeProject $Target -Interactive:$SelectTarget
    if (-not $WorkspacePath -and -not $Target -and -not $SelectTarget -and $config.activeProject -and -not $active) { throw 'activeProject deve corresponder ao name de um repositorio.' }
    foreach ($field in @('applicationMavenHome','applicationMavenSettingsPath')) {
        if (-not $config.tools.PSObject.Properties[$field]) { $config.tools | Add-Member NoteProperty $field $null }
    }
    foreach ($field in @('mtaExecutable','mtaJdkHome','mavenHome','mavenSettingsPath','applicationMavenHome','applicationMavenSettingsPath','applicationJdk8Home','eap71Home','eap74Home')) {
        $config.tools.$field = Resolve-HarnessPath $config.tools.$field $Root
    }
    $config.mta.rulesPath = Resolve-HarnessPath $config.mta.rulesPath $Root
    # Compatibilidade com o JSON local anterior, sem reescrever o arquivo.
    if (-not $config.mta.PSObject.Properties['profile']) { $config.mta | Add-Member NoteProperty profile 'eap71-to-eap74-java8' }
    if (-not $config.mta.PSObject.Properties['sources']) { $config.mta | Add-Member NoteProperty sources @() }
    if ($config.mta.profile -cne 'eap71-to-eap74-java8') { throw 'Perfil suportado: mta.profile = eap71-to-eap74-java8.' }
    if ($config.mta.sources -isnot [Array] -or $config.mta.sources.Count -ne 0) { throw 'Use mta.sources = []. Filtrar source=eap7.1 exclui regras Hibernate do perfil ensaiado.' }
    if ($config.mta.targets -isnot [Array] -or $config.mta.targets.Count -ne 1 -or $config.mta.targets[0] -cne 'eap7') { throw 'Use mta.targets = ["eap7"]. EAP 7.4 e o destino de runtime; nao um target desta CLI ensaiada. Nao usar eap8.' }
    if ($config.mta.mode -cne 'full') { throw 'Use mta.mode = full para preservar a analise de fontes e dependencias do perfil ensaiado.' }
    [pscustomobject]@{ Root=$Root; ConfigPath=$Path; Config=$config; Active=$active; Projects=$projects; WorkspacePath=$WorkspacePath }
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
        $settings['maven.terminal.useJavaHome'] = $false
        $settings['maven.terminal.customEnv'] = @(@{environmentVariable='JAVA_HOME'; value=$Context.Config.tools.applicationJdk8Home})
    }
    if ($Context.Config.tools.mtaJdkHome) { $settings['java.jdt.ls.java.home'] = $Context.Config.tools.mtaJdkHome }
    if ($Context.Config.tools.applicationMavenHome) { $settings['maven.executable.path'] = Join-Path $Context.Config.tools.applicationMavenHome 'bin/mvn.cmd' }
    if ($Context.Config.tools.applicationMavenSettingsPath) {
        $settings['java.configuration.maven.userSettings'] = $Context.Config.tools.applicationMavenSettingsPath
        $settings['maven.settingsFile'] = $Context.Config.tools.applicationMavenSettingsPath
    }
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
    if (-not $Context.Active) { throw 'Escolha um projeto com -SelectTarget ou -Target; activeProject e o padrao opcional.' }
    foreach ($name in @('mtaExecutable','mtaJdkHome','mavenHome')) {
        if (-not $tool.$name) { throw "Preencha tools.$name no JSON local." }
    }
    if ([IO.Path]::GetExtension($tool.mtaExecutable) -ine '.exe') { throw 'mtaExecutable deve apontar para a CLI .exe do ZIP Windows.' }
    $mtaHome = Split-Path -Parent $tool.mtaExecutable
    foreach ($file in @($tool.mtaExecutable, (Join-Path $tool.mtaJdkHome 'bin/java.exe'), (Join-Path $tool.mtaJdkHome 'bin/javac.exe'), (Join-Path $tool.mavenHome 'bin/mvn.cmd'), (Join-Path $Context.Active.path 'pom.xml'), (Join-Path $mtaHome 'java-external-provider.exe'), (Join-Path $mtaHome 'fernflower.jar'), (Join-Path $mtaHome 'static-report/index.html'))) {
        if (-not (Test-Path -LiteralPath $file -PathType Leaf)) { throw "Arquivo ausente: $file" }
    }
    foreach ($directory in @('jdtls/config_win','jdtls/plugins')) {
        if (-not (Test-Path -LiteralPath (Join-Path $mtaHome $directory) -PathType Container)) { throw "Instalacao MTA incompleta: $directory ausente em $mtaHome. Extraia a distribuicao completa nessa pasta." }
    }
    if ($tool.mavenSettingsPath -and -not (Test-Path -LiteralPath $tool.mavenSettingsPath -PathType Leaf)) { throw 'mavenSettingsPath nao existe.' }
    $rules = $Context.Config.mta.rulesPath
    if (-not $rules) { $rules = Join-Path $mtaHome 'rulesets/java' }
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

function Format-HarnessDate {
    param([string]$Value, [switch]$ForPath)
    $date = ([DateTimeOffset]::Parse($Value)).ToLocalTime()
    if ($ForPath) { return $date.ToString('yyyy-MM-dd_HH-mm-sszzz', [Globalization.CultureInfo]::InvariantCulture).Replace(':','') }
    $date.ToString('yyyy-MM-dd HH:mm:ss zzz', [Globalization.CultureInfo]::InvariantCulture)
}

function Test-HarnessRunFolder {
    param([string]$Name, [string]$Id, [string]$Prefix)
    if ($Id -cnotmatch '^[a-f0-9]{32}$') { return $false }
    if ($Name -ceq $Id) { return $true }
    $Name -cmatch ('^' + [regex]::Escape($Prefix) + '_\d{4}-\d{2}-\d{2}_\d{2}-\d{2}-\d{2}[+-]\d{4}__' + $Id.Substring(0,12) + '$')
}

function Get-HarnessProjectKey {
    param([string]$Project)
    $sha = [Security.Cryptography.SHA256]::Create()
    try { ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($Project)))).Replace('-','').Substring(0,12).ToLowerInvariant() }
    finally { $sha.Dispose() }
}

function Get-HarnessProjectFolder {
    param($Project)
    $label = ([regex]::Replace($Project.label, '[^A-Za-z0-9_-]', '-')).Trim('-','_')
    if (-not $label) { $label = 'projeto' }
    if ($label.Length -gt 24) { $label = $label.Substring(0,24) }
    $label + '__' + (Get-HarnessProjectKey $Project.name)
}

function Get-HarnessMtaRuns {
    param([string]$Root, [string]$Project, [string]$Source)
    if ($Project -cnotmatch '^(?:[A-Za-z0-9][A-Za-z0-9_.-]{0,63}|_workspace-[a-f0-9]{24})$') { throw 'Identidade de projeto invalida.' }
    $base = Resolve-HarnessPath (Join-Path $Root '.harness/runs') $Root
    if (-not (Test-Path -LiteralPath $base -PathType Container)) { return }
    $key = Get-HarnessProjectKey $Project
    $projects = @(Get-ChildItem -LiteralPath $base -Directory | Where-Object {
        $_.Name -ceq $Project -or $_.Name.EndsWith(('__' + $key), [StringComparison]::Ordinal)
    })
    $records = @(foreach ($directory in $projects) {
        $projectPath = Resolve-HarnessPath $directory.FullName $Root
        foreach ($folder in Get-ChildItem -LiteralPath $projectPath -Directory) {
            if ($folder.Name -cnotmatch '^(?:[a-f0-9]{32}|mta_\d{4}-\d{2}-\d{2}_\d{2}-\d{2}-\d{2}[+-]\d{4}__[a-f0-9]{12})$') { continue }
            $record = [pscustomobject]@{Run=$folder.FullName; RunId=$null; CreatedAtUtc=$folder.CreationTimeUtc; Manifest=$null; Problem=$null}
            try {
                $record.Run = Resolve-HarnessPath $folder.FullName $Root
                $path = Resolve-HarnessPath (Join-Path $record.Run 'manifest.json') $Root
                $manifest = Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
                $record.RunId = $manifest.RunId
                $record.CreatedAtUtc = ([DateTimeOffset]::Parse($manifest.CreatedAtUtc)).UtcDateTime
                if ($manifest.Project -cne $Project -or -not (Test-HarnessRunFolder $folder.Name $manifest.RunId 'mta')) { throw 'Manifesto nao corresponde ao projeto/rodada.' }
                $manifestSource = Resolve-HarnessPath $manifest.Source $Root
                if (-not $manifestSource -or ($Source -and $manifestSource -ine (Resolve-HarnessPath $Source $Root))) { throw 'Fonte do manifesto diverge do projeto selecionado.' }
                $record.Manifest = $manifest
            } catch { $record.Problem = $_.Exception.Message }
            $record
        }
    })
    $duplicates = @($records | Where-Object { $_.RunId } | Group-Object RunId | Where-Object Count -gt 1)
    if ($duplicates.Count) { throw 'RunId ambiguo: mais de uma pasta encontrada para a mesma rodada/projeto.' }
    $records | Sort-Object -Property @{Expression='CreatedAtUtc';Descending=$true}, RunId
}

function Find-HarnessMtaRun {
    param([string]$Root, [string]$Project, [string]$RunId, [string]$Source)
    if ($RunId -cnotmatch '^[a-f0-9]{32}$') { throw 'RunId invalido.' }
    $matches = @(Get-HarnessMtaRuns $Root $Project $Source | Where-Object RunId -CEQ $RunId)
    if ($matches.Count -ne 1) { throw 'Rodada ausente ou ambigua para o projeto selecionado.' }
    if ($matches[0].Problem) { throw $matches[0].Problem }
    $matches[0]
}

function New-MtaSnapshot {
    param($Context)
    $rules = Get-MtaRequirements $Context
    Import-Module (Join-Path $PSScriptRoot 'HarnessGit.psm1') -DisableNameChecking
    $createdAt = [DateTime]::UtcNow.ToString('o')
    $projectFolder = Get-HarnessProjectFolder $Context.Active
    do {
        $id = [guid]::NewGuid().ToString('N')
        $runFolder = 'mta_' + (Format-HarnessDate $createdAt -ForPath) + '__' + $id.Substring(0,12)
        $run = Resolve-HarnessPath (Join-Path $Context.Root ('.harness/runs/' + $projectFolder + '/' + $runFolder)) $Context.Root
    } while (Test-Path -LiteralPath $run)
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
        RunId=$id; Project=$Context.Active.name; Source=$Context.Active.path; CreatedAtUtc=$createdAt
        Git=(Get-HarnessGitState $Context)
        Executable=$Context.Config.tools.mtaExecutable; ExecutableSha256=(Get-FileHash -LiteralPath $Context.Config.tools.mtaExecutable).Hash
        MtaHome=(Split-Path -Parent $Context.Config.tools.mtaExecutable)
        MtaProfile=$Context.Config.mta.profile; MtaSources=@($Context.Config.mta.sources)
        Migration=[ordered]@{Source='EAP 7.1'; Target='EAP 7.4'; Java=8; Namespace='javax'; CorrectedArtifactRuntime='EAP 7.4'}
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
    if (-not $Context.Active) { throw 'Escolha um projeto com -SelectTarget ou -Target; activeProject e o padrao opcional.' }
    $stateRoot = Resolve-HarnessPath (Join-Path $Context.Root '.harness') $Context.Root
    $null = [IO.Directory]::CreateDirectory($stateRoot)
    try { $lock = [IO.File]::Open((Join-Path $stateRoot 'mta.lock'), 'OpenOrCreate', 'ReadWrite', 'None') }
    catch { throw 'Ja existe uma analise MTA em execucao neste harness.' }
    $snapshot = $null
    $activeLease = $null
    $previous = @{}
    foreach ($name in @('JAVA_HOME','PATH','JVM_MAX_MEM','SONAR_TOKEN','MAVEN_HOME','M2_HOME','JAVA_OPTS','MAVEN_OPTS','JDK_JAVA_OPTIONS','JAVA_TOOL_OPTIONS','_JAVA_OPTIONS','KANTRA_DIR')) { $previous[$name] = [Environment]::GetEnvironmentVariable($name, 'Process') }
    $result = [ordered]@{Status='FAILED'; ExitCode=$null; Project=$Context.Active.name; RunId=$null; ReportPath=$null; ResultPath=$null; SourceUnchanged=$null; SnapshotOriginalFilesUnchanged=$null; UnexpectedAddedFiles=@(); RulesUnchanged=$null; Version=$null; Error=$null}
    $pushed = $false
    try {
        $snapshot = New-MtaSnapshot $Context
        $result.RunId = $snapshot.Manifest.RunId
        $result.ReportPath = Join-Path $snapshot.Output 'static-report/index.html'
        $result.ResultPath = Join-Path $snapshot.Run 'result.json'
        # O arquivo permanece, mas o handle so fica aberto durante esta analise.
        # Um registro antigo apos encerramento abrupto nao deve apontar para um build.
        $activeLease = [IO.File]::Open((Join-Path $snapshot.Run 'active.lock'), 'OpenOrCreate', 'ReadWrite', 'Read')
        Write-HarnessJson (Join-Path $stateRoot 'active-mta.json') @{RunId=$result.RunId; Project=$Context.Active.name; Label=$Context.Active.label}
        $tool = $Context.Config.tools
        $env:KANTRA_DIR = Split-Path -Parent $tool.mtaExecutable
        $env:JAVA_HOME = $tool.mtaJdkHome
        $env:MAVEN_HOME = $tool.mavenHome
        $env:M2_HOME = $tool.mavenHome
        foreach ($name in @('JAVA_OPTS','MAVEN_OPTS','JDK_JAVA_OPTIONS','JAVA_TOOL_OPTIONS','_JAVA_OPTIONS')) { [Environment]::SetEnvironmentVariable($name,$null,'Process') }
        $env:PATH = (Join-Path $tool.mtaJdkHome 'bin') + ';' + (Join-Path $tool.mavenHome 'bin') + ';' + (Split-Path -Parent $tool.mtaExecutable) + ';' + $previous.PATH
        $env:JVM_MAX_MEM = '2g'
        $env:SONAR_TOKEN = $null
        Push-Location -LiteralPath $snapshot.Run
        $pushed = $true
        Write-Host "Projeto: $($Context.Active.label) | Fonte: $($Context.Active.path)"
        Write-Host "Instalacao MTA (KANTRA_DIR): $env:KANTRA_DIR"
        Write-Host "Perfil: $($snapshot.Manifest.MtaProfile) | EAP 7.1 -> EAP 7.4 | Java 8 / javax"
        Write-Host 'Filtros MTA: target=eap7; source=nenhum (preserva regras Hibernate).'
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
        try { if ($result.ResultPath) { Write-HarnessJson $result.ResultPath $result } }
        finally {
            if ($activeLease) { $activeLease.Dispose() }
            $lock.Dispose()
        }
    }
    [pscustomobject]$result
}

function Get-ActiveMtaRun {
    param([string]$Root)
    $pointer = Resolve-HarnessPath (Join-Path $Root '.harness/active-mta.json') $Root
    $notRunning = 'Nenhuma analise MTA em execucao. Inicie MTA: executar analise e aguarde a mensagem Rodada.'
    if (-not (Test-Path -LiteralPath $pointer -PathType Leaf)) { throw $notRunning }
    try { $active = Get-Content -LiteralPath $pointer -Raw -Encoding UTF8 | ConvertFrom-Json }
    catch { throw 'Registro da analise ainda indisponivel. Aguarde a mensagem Rodada e tente novamente.' }
    if ($active.RunId -cnotmatch '^[a-f0-9]{32}$' -or $active.Project -cnotmatch '^(?:[A-Za-z0-9][A-Za-z0-9_.-]{0,63}|_workspace-[a-f0-9]{24})$') { throw 'Registro da analise ativa invalido.' }
    $selected = Find-HarnessMtaRun $Root $active.Project $active.RunId
    $run = $selected.Run
    $leasePath = Join-Path $run 'active.lock'
    if (-not (Test-Path -LiteralPath $leasePath -PathType Leaf)) { throw $notRunning }
    $running = $false
    try {
        $probe = [IO.File]::Open($leasePath, 'Open', 'ReadWrite', 'None')
        $probe.Dispose()
    } catch [IO.IOException] { $running = $true }
    if (-not $running) { throw $notRunning }
    $manifest = $selected.Manifest
    [pscustomobject]@{Run=$run; Manifest=$manifest; Label=$active.Label}
}

function Get-LastMtaReport {
    param($Context)
    if (-not $Context.Active) { throw 'Escolha um projeto com -SelectTarget ou -Target; activeProject e o padrao opcional.' }
    $state = Join-Path $Context.Root ('.harness/last-' + $Context.Active.name + '.json')
    if (-not (Test-Path -LiteralPath $state)) { throw 'Nao ha analise concluida para o projeto ativo.' }
    $last = Get-Content -LiteralPath $state -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($last.RunId -cnotmatch '^[a-f0-9]{32}$') { throw 'Referencia de relatorio invalida.' }
    $selected = Find-HarnessMtaRun $Context.Root $Context.Active.name $last.RunId $Context.Active.path
    $run = $selected.Run
    $result = Get-Content -LiteralPath (Join-Path $run 'result.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($result.Project -cne $Context.Active.name -or $result.RunId -cne $last.RunId) { throw 'Resultado nao corresponde ao projeto/rodada.' }
    $path = Join-Path $run 'output/static-report/index.html'
    if ($result.Status -cne 'SUCCEEDED' -or -not (Test-Path -LiteralPath $path -PathType Leaf)) { throw 'Relatorio ausente ou rodada nao concluida.' }
    return $path
}

Export-ModuleMember -Function Read-HarnessConfig, New-HarnessWorkspace, Write-HarnessJson, Resolve-HarnessPath, Get-MtaRequirements, New-MtaSnapshot, Invoke-MtaAnalysis, Get-ActiveMtaRun, Get-LastMtaReport, Format-HarnessDate, Test-HarnessRunFolder, Get-HarnessProjectKey, Get-HarnessProjectFolder, Get-HarnessMtaRuns, Find-HarnessMtaRun
