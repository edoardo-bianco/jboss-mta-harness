#requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if ($PSVersionTable.PSVersion.Major -ne 5 -or $PSVersionTable.PSVersion.Minor -ne 1) { throw 'Use Windows PowerShell 5.1 (powershell.exe).' }

Import-Module (Join-Path $PSScriptRoot 'HarnessProject.psm1') -DisableNameChecking

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

function Open-HarnessEditor {
    param(
        [Parameter(Mandatory=$true)][string]$EditorPath,
        [Parameter(Mandatory=$true)][string[]]$FilePaths,
        [Parameter(Mandatory=$true)][string]$Root
    )
    $editor = Resolve-HarnessPath $EditorPath $Root
    if (-not $editor -or -not (Test-Path -LiteralPath $editor -PathType Leaf)) { throw 'Executavel do editor nao encontrado.' }
    # ${execPath} aponta ao aplicativo Electron. A CLI encaminha a abertura para
    # a instancia existente, usando a mesma instalacao (inclusive portable).
    $cliName = switch ([IO.Path]::GetFileName($editor)) {
        'Code.exe' { 'code.cmd' }
        'Code - Insiders.exe' { 'code-insiders.cmd' }
    }
    if ($cliName) {
        $editor = Resolve-HarnessPath (Join-Path (Split-Path -Parent $editor) ('bin/' + $cliName)) $Root
        if (-not (Test-Path -LiteralPath $editor -PathType Leaf)) {
            throw "CLI do VS Code nao encontrada: $editor. Confira a instalacao ou informe -EditorPath com o caminho da CLI."
        }
    }
    if (-not $FilePaths.Count) { throw 'Informe ao menos um arquivo para abrir.' }
    $files = @(foreach ($file in $FilePaths) {
        $path = Resolve-HarnessPath $file $Root
        if (-not $path -or -not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Arquivo para abrir nao encontrado: $file" }
        if ([IO.Path]::IsPathRooted($file)) { $file } else { $path }
    })
    Write-Host "Abrindo arquivos via: $editor"
    $global:LASTEXITCODE = 0
    & $editor --reuse-window @files
    if ($LASTEXITCODE -ne 0) { throw "Editor retornou codigo $LASTEXITCODE. Os arquivos continuam salvos nos caminhos informados." }
}

function Write-HarnessJson {
    param([string]$Path, $Value)
    $null = [IO.Directory]::CreateDirectory((Split-Path -Parent $Path))
    [IO.File]::WriteAllText($Path, ($Value | ConvertTo-Json -Depth 12), (New-Object Text.UTF8Encoding($false)))
}

function Read-HarnessWorkspaceFile {
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
    if (-not $workspace.PSObject.Properties['folders'] -or $workspace.folders -isnot [Array]) { throw 'Workspace deve conter folders como lista.' }
    return $workspace
}

function Read-HarnessWorkspaceProjects {
    param([string]$WorkspacePath, [string]$Root)
    $WorkspacePath = Resolve-HarnessPath $WorkspacePath $Root
    $workspace = Read-HarnessWorkspaceFile $WorkspacePath $Root
    $seen = @{}
    foreach ($folder in $workspace.folders) {
        if (-not $folder.PSObject.Properties['path']) { continue }
        $projectPath = Resolve-HarnessPath $folder.path (Split-Path -Parent $WorkspacePath)
        if (-not $projectPath -or $projectPath -ieq $Root -or $seen.ContainsKey($projectPath)) { continue }
        if (-not (Test-Path -LiteralPath (Join-Path $projectPath 'pom.xml') -PathType Leaf)) { continue }
        $seen[$projectPath] = $true
        $label = Split-Path $projectPath -Leaf
        if ($folder.PSObject.Properties['name'] -and $folder.name) { $label = $folder.name }
        $project=Get-HarnessProjectReference $Root (Join-Path $projectPath 'pom.xml')
        [pscustomobject]@{name=$project.Name; label=$label; path=$projectPath}
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
    param([string]$Path, [string]$Root = (Split-Path -Parent $PSScriptRoot), [string]$WorkspacePath, [string]$Target, [switch]$SelectTarget, [switch]$SkipMigrationInitialization)
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
        if (-not $WorkspacePath -and ([string]::IsNullOrWhiteSpace($repo.name) -or $repo.name -ieq 'harness')) { throw 'Alias de repositorio vazio ou reservado: harness identifica a raiz das Run Tasks.' }
        if ($names.ContainsKey($repo.name)) { throw 'Projeto duplicado ou artifactId em colisao no escopo. Confira os POMs e use outra raiz para projetos distintos.' }
        if (-not $repo.PSObject.Properties['label']) { $repo | Add-Member NoteProperty label $repo.name }
        $names[$repo.name] = $true
        $repo.path = Resolve-HarnessPath $repo.path $Root
        if (-not $repo.path -or -not (Test-Path -LiteralPath $repo.path -PathType Container)) { throw "Pasta ausente para o repositorio $($repo.name). Ajuste config/harness.local.json." }
        if ($repo.path -ieq $Root -or $Root.StartsWith($repo.path + '\', [StringComparison]::OrdinalIgnoreCase) -or $repo.path.StartsWith($Root + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Mantenha os repositorios de aplicacao fora da pasta do harness.' }
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
    # Ler configuracao nao publica registros. A tarefa de indice inicializa os
    # destinos correntes; o switch antigo permanece sem efeito ate retirar chamadores.
    [pscustomobject]@{ Root=$Root; ConfigPath=$Path; Config=$config; Active=$active; Projects=$projects; WorkspacePath=$WorkspacePath }
}

function New-HarnessWorkspace {
    param($Context)
    Import-Module (Join-Path $PSScriptRoot 'HarnessJbossConfig.psm1') -DisableNameChecking
    $debugConfigurations = @(Get-HarnessJbossDebugConfigurations $Context.Config)
    $folders = @([ordered]@{name='harness'; path='.'})
    foreach ($repo in $Context.Config.repositories) { $folders += [ordered]@{name=$repo.name; path=$repo.path} }
    $settings = [ordered]@{
        'java.autobuild.enabled'=$true
        'java.debug.settings.hotCodeReplace'='auto'
        'java.configuration.updateBuildConfiguration'='disabled'
        'java.import.generatesMetadataFilesAtProjectRoot'=$false
        'files.exclude'=@{ '**/.harness'=$false }
    }
    $externalRoots=@(Get-HarnessProjectReadRoots $Context.Root @($Context.Projects | ForEach-Object { Join-Path $_.path 'pom.xml' }))
    if ($externalRoots.Count) { $settings['github.copilot.chat.additionalReadAccessPaths'] = @($externalRoots | ForEach-Object { $_.Replace('\','/') }) }
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
    $document = [pscustomobject]@{folders=$folders; settings=[pscustomobject]$settings}
    if (Test-Path -LiteralPath $path) {
        $document = Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
        foreach ($folder in $folders) {
            $existing=@($document.folders | Where-Object { $_.PSObject.Properties['name'] -and $_.name -eq $folder.name })
            if ($existing.Count) { $existing[0].path=$folder.path; continue }
            # O VS Code pode importar somente path; aliases humanos tambem sao opcionais.
            $folderPath = Resolve-HarnessPath $folder.path $Context.Root
            $existing=@($document.folders | Where-Object {
                if (-not $_.PSObject.Properties['path']) { return $false }
                try { (Resolve-HarnessPath $_.path $Context.Root) -ieq $folderPath }
                catch { $false } # Pasta extra nao gerenciada: preservar sem validar seu destino.
            })
            if (-not $existing.Count) { $document.folders += [pscustomobject]$folder }
            elseif ($folder.name -eq 'harness') {
                # As Run Tasks referenciam workspaceFolder:harness.
                $existing[0] | Add-Member NoteProperty name 'harness' -Force
            }
        }
        if (-not $document.PSObject.Properties['settings']) { $document | Add-Member NoteProperty settings ([pscustomobject]@{}) }
        foreach ($name in @('java.configuration.runtimes','maven.terminal.useJavaHome','maven.terminal.customEnv','java.jdt.ls.java.home','maven.executable.path','java.configuration.maven.userSettings','maven.settingsFile')) {
            $document.settings.PSObject.Properties.Remove($name)
        }
        foreach ($name in $settings.Keys) {
            if (-not $document.settings.PSObject.Properties[$name]) { $document.settings | Add-Member NoteProperty $name $settings[$name] }
        }
        $backup = Join-Path $Context.Root ('.harness/workspace-backups/' + [guid]::NewGuid().ToString('N') + '.code-workspace')
        $null = [IO.Directory]::CreateDirectory((Split-Path -Parent $backup))
        Copy-Item -LiteralPath $path -Destination $backup
    }
    # O padrao antigo escondia inclusive os indices e as evidencias oficiais.
    # Corrigir somente esse filtro, preservando as demais escolhas do Explorer.
    $document.settings.'files.exclude' | Add-Member NoteProperty '**/.harness' $false -Force
    if (-not $document.PSObject.Properties['launch']) { $document | Add-Member NoteProperty launch ([pscustomobject]@{version='0.2.0'; configurations=@()}) }
    if (-not $document.launch.PSObject.Properties['configurations']) { $document.launch | Add-Member NoteProperty configurations @() }
    $names=@($debugConfigurations | ForEach-Object name)
    $document.launch.configurations = @($document.launch.configurations | Where-Object { $_.name -notin $names }) + $debugConfigurations
    if (-not $document.PSObject.Properties['extensions']) { $document | Add-Member NoteProperty extensions ([pscustomobject]@{}) }
    if (-not $document.extensions.PSObject.Properties['recommendations']) { $document.extensions | Add-Member NoteProperty recommendations @() }
    $document.extensions.recommendations = @(@($document.extensions.recommendations) + @('redhat.java','vscjava.vscode-java-debug') | Select-Object -Unique)
    Write-HarnessJson $path $document
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
        $info = New-Object IO.DirectoryInfo ('\\?\' + $directory)
        foreach ($item in $info.EnumerateFileSystemInfos()) {
            $isDirectory = $item -is [IO.DirectoryInfo]
            if ($isDirectory -and $item.Name -in @('.git','.harness','.scannerwork','node_modules')) { continue }
            if ($isDirectory -and $Rules -and $item.Name -in @('test','tests')) { continue }
            if ($isDirectory -and -not $Rules -and $item.Name -eq 'target' -and [IO.File]::Exists(('\\?\' + $directory + '\pom.xml'))) { continue }
            if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "Link/junction na entrada: $($item.FullName)" }
            $normalPath = $item.FullName.Substring(4)
            if ($isDirectory) { $pending.Push($normalPath); continue }
            if ($Rules -and $item.Extension -notin @('.yaml','.yml')) { continue }
            $files.Add([pscustomobject]@{path=$normalPath.Substring($Root.Length + 1).Replace('\','/'); sha256=(Get-HarnessFileHash $normalPath)})
        }
    }
    return @($files | Sort-Object path)
}

function Get-HarnessFileHash {
    param([string]$Path)
    $stream = [IO.File]::OpenRead(('\\?\' + $Path))
    $sha = [Security.Cryptography.SHA256]::Create()
    try { ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-','') }
    finally { $sha.Dispose(); $stream.Dispose() }
}

function Copy-HarnessFiles {
    param([string]$Source, [string]$Destination, [object[]]$Files)
    foreach ($file in $Files) {
        $target = Join-Path $Destination $file.path
        $extended = '\\?\' + $target
        $null = [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($extended))
        [IO.File]::Copy(('\\?\' + (Join-Path $Source $file.path)), $extended, $false)
        if ((Get-HarnessFileHash $target) -ine $file.sha256) { throw 'Entrada mudou durante a copia; repita com fontes estaveis.' }
    }
}

function Format-HarnessDate {
    param([string]$Value, [switch]$ForPath)
    $date = ([DateTimeOffset]::Parse($Value)).ToLocalTime()
    if ($ForPath) { return $date.ToString('yyyy-MM-dd_HH-mm-sszzz', [Globalization.CultureInfo]::InvariantCulture).Replace(':','') }
    $date.ToString('yyyy-MM-dd HH:mm:ss zzz', [Globalization.CultureInfo]::InvariantCulture)
}

function Get-HarnessProjectKey {
    param([string]$Project)
    $sha = [Security.Cryptography.SHA256]::Create()
    try { ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($Project)))).Replace('-','').Substring(0,12).ToLowerInvariant() }
    finally { $sha.Dispose() }
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

. (Join-Path $PSScriptRoot 'HarnessMtaExecution.ps1')

Export-ModuleMember -Function Read-HarnessConfig, New-HarnessWorkspace, Write-HarnessJson, Resolve-HarnessPath, Get-MtaRequirements, Invoke-MtaAnalysis, Get-LastMtaReport, Format-HarnessDate, Get-HarnessProjectKey, Get-HarnessFiles
Export-ModuleMember -Function Open-HarnessEditor
Export-ModuleMember -Function Read-HarnessWorkspaceFile
