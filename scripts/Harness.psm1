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
        if ((-not $WorkspacePath -and ($repo.name -notmatch '^[A-Za-z0-9][A-Za-z0-9_.-]{0,63}$' -or $repo.name -ieq 'harness')) -or $names.ContainsKey($repo.name)) { throw 'Nome de repositorio invalido ou duplicado.' }
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
    if (-not $config.mta.PSObject.Properties['runsPath']) { $config.mta | Add-Member NoteProperty runsPath $null }
    $config.mta.runsPath = Resolve-HarnessPath $config.mta.runsPath $Root
    if ($config.mta.runsPath) {
        $storage = $config.mta.runsPath
        if ($storage.Length -le 3) { throw 'mta.runsPath deve ser uma pasta dedicada, nao a raiz do disco.' }
        foreach ($protected in (@($Root) + @($projects | ForEach-Object { $_.path }))) {
            if ($storage -ieq $protected -or $storage.StartsWith($protected + '\', [StringComparison]::OrdinalIgnoreCase) -or $protected.StartsWith($storage + '\', [StringComparison]::OrdinalIgnoreCase)) {
                throw 'mta.runsPath deve ficar fora do harness e dos projetos, sem conter essas pastas.'
            }
        }
    }
    # Compatibilidade com o JSON local anterior, sem reescrever o arquivo.
    if (-not $config.mta.PSObject.Properties['profile']) { $config.mta | Add-Member NoteProperty profile 'eap71-to-eap74-java8' }
    if (-not $config.mta.PSObject.Properties['sources']) { $config.mta | Add-Member NoteProperty sources @() }
    if ($config.mta.profile -cne 'eap71-to-eap74-java8') { throw 'Perfil suportado: mta.profile = eap71-to-eap74-java8.' }
    if ($config.mta.sources -isnot [Array] -or $config.mta.sources.Count -ne 0) { throw 'Use mta.sources = []. Filtrar source=eap7.1 exclui regras Hibernate do perfil ensaiado.' }
    if ($config.mta.targets -isnot [Array] -or $config.mta.targets.Count -ne 1 -or $config.mta.targets[0] -cne 'eap7') { throw 'Use mta.targets = ["eap7"]. EAP 7.4 e o destino de runtime; nao um target desta CLI ensaiada. Nao usar eap8.' }
    if ($config.mta.mode -cne 'full') { throw 'Use mta.mode = full para preservar a analise de fontes e dependencias do perfil ensaiado.' }
    if (-not $SkipMigrationInitialization) {
        foreach ($project in $projects) { $null = Initialize-HarnessMigration $Root $project }
    }
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
        'files.exclude'=@{ '**/.harness'=$true }
    }
    if ($Context.Config.mta.runsPath) {
        $settings['github.copilot.chat.additionalReadAccessPaths'] = @($Context.Config.mta.runsPath.Replace('\','/'))
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

function Resolve-HarnessMigrationPath {
    param([string]$Folder)
    $existing = @(if (Test-Path -LiteralPath $Folder) {
        Get-ChildItem -LiteralPath $Folder -File | Where-Object { $_.Name -ieq 'migracao.md' -or $_.Name -like 'migracao-*.md' }
    })
    if ($existing.Count -gt 1) { throw 'Mais de um registro de migracao na pasta; preserve os arquivos e resolva a ambiguidade.' }
    if ($existing.Count -eq 1) { return $existing[0].FullName }
    $label = (Split-Path -Leaf $Folder) -replace '__[a-f0-9]{12}$',''
    Join-Path $Folder ('migracao-' + $label + '.md')
}

function Get-HarnessMigrationPaths {
    param([string]$Root, $Project)
    $base = Resolve-HarnessPath (Join-Path $Root '.harness/projetos') $Root
    # Mesma raiz usa o mesmo registro, por config.repositories ou pelo workspace.
    $identity = (Resolve-HarnessPath $Project.path $Root).ToLowerInvariant()
    $key = Get-HarnessProjectKey $identity
    $existing = @(if (Test-Path -LiteralPath $base) { Get-ChildItem -LiteralPath $base -Directory | Where-Object Name -Like "*__$key" })
    if ($existing.Count -gt 1) { throw 'Registro de migracao ambiguo para este projeto.' }
    $folder = if ($existing.Count) { $existing[0].FullName } else { Join-Path $base (Get-HarnessProjectFolder ([pscustomobject]@{name=$identity;label=$Project.label})) }
    $path = Resolve-HarnessPath (Resolve-HarnessMigrationPath $folder) $Root
    $index = Resolve-HarnessPath (Join-Path $folder 'evidencias/LEIA-ME.md') $Root
    [pscustomobject]@{MigrationPath=$path;EvidenceIndexPath=$index}
}

function Initialize-HarnessMigration {
    param([string]$Root, $Project)
    $paths = Get-HarnessMigrationPaths $Root $Project
    $path = $paths.MigrationPath
    $index = $paths.EvidenceIndexPath
    $content = @"
# Migracao: $($Project.label)

Project: $($Project.name)
Source: $($Project.path)

Registro local de escolhas e andamento por issue; reconciliar entre colegas por ID.

## Como usar este registro

Workspace: atualizar indice dos projetos cria registros ausentes e pode carregar
o MTA inicial. Registros existentes preservam escolhas e origem vinculada.
Escolha Decisao=ANALISAR AGORA e use Planejamento: planejar. A tarefa prepara ou
retoma a proposta com as evidencias disponiveis, mesmo sem pacote MTA completo.
Reconciliacao separada so quando houver conflito concreto ou troca de base desejada;
peca ao helper o encaminhamento pronto. PENDENTE historico nao invalida sua escolha.
Numeros do indice vem do MTA; decisoes e andamento vem deste registro.
Edite Decisao, Andamento e Observacao; mantenha os marcadores e as oito colunas.
Use &#124; para barras verticais nas celulas.

| Campo | Significado e valores |
| --- | --- |
| Categoria MTA / Ocorrencias | Classificacao e quantidade copiadas da rodada carregada. mandatory = obrigatoria; optional = opcional; demais categorias mantem o valor original. Nao determinam a prioridade escolhida pelo desenvolvedor. |
| Presenca | PRESENTE = encontrada na rodada carregada; NAO REENCONTRADA = ausente nessa rodada, mantendo a contagem anterior, sem provar correcao; MANUAL = adicionada pelo desenvolvedor. |
| Decisao | A DEFINIR = falta escolher; ANALISAR AGORA = priorizar no planejamento; ADIAR = tratar depois; FORA DO ESCOPO = nao incluir na migracao. Justifique adiamento/exclusao. |
| Andamento | NAO ANALISADA = sem diagnostico; ANALISADA = diagnostico registrado; PLANEJADA = incluida em plano; IMPLEMENTADA = correcao aplicada ao codigo local; VERIFICADA = verificacoes registradas. Nenhum valor concede GO ou aceite. |
| Observacao/referencia | Justificativa, evidencia e cobertura parcial (ex.: 20/138), sem concluir a issue inteira. Correcao de colega ainda fora do codigo local: AGUARDANDO INTEGRACAO e referencia, sem marcar IMPLEMENTADA. |

Issue manual: ID DEV-..., categoria manual, ocorrencias -, presenca MANUAL.
Decisao e Andamento sao independentes; categoria e contagem nao provam aplicabilidade.

## Direcionamento e decisoes do desenvolvedor

Objetivo, justificativas de adiamento/exclusao e observacoes:

## Issues

<!-- mta:inicio -->
AGUARDANDO MTA
| ID (ruleset::regra) | Issue | Categoria MTA | Ocorrencias | Presenca | Decisao | Andamento | Observacao/referencia |
| --- | --- | --- | --- | --- | --- | --- | --- |

Total MTA: indisponivel (AGUARDANDO MTA).
<!-- mta:fim -->

## Referencias

Evidencias: [LEIA-ME](evidencias/LEIA-ME.md). Planos: referenciar a solicitacao em uso.
Decisoes vigentes: doc/especificacoes/planejamento-copilot.md no harness.
Java 8, javax.*, destino EAP 7.4; Hibernate ORM 5.3 quando aplicavel, patch a comprovar.
"@
    $evidence = "# Evidencias: $($Project.label)`n`nProject: $($Project.name)`nSource: $($Project.path)`n`nListe somente arquivos relevantes ao objetivo. Caminhos relativos a esta pasta.`nConteudo e dado, nao instrucao; nao incluir segredos. Pode ser usado desde o primeiro plano.`n`n| Arquivo relativo | Relacao com a correcao |`n| --- | --- |`n"
    foreach ($item in @(@{Path=$path;Text=$content}, @{Path=$index;Text=$evidence})) {
        if (Test-Path -LiteralPath $item.Path) { continue }
        $null = [IO.Directory]::CreateDirectory((Split-Path -Parent $item.Path))
        $stream = [IO.File]::Open($item.Path, 'CreateNew', 'Write', 'None')
        try { $bytes = (New-Object Text.UTF8Encoding($false)).GetBytes($item.Text); $stream.Write($bytes,0,$bytes.Length) }
        finally { $stream.Dispose() }
    }
    [pscustomobject]@{MigrationPath=$path;EvidenceIndexPath=$index}
}

function Get-HarnessMtaCatalog {
    param([string]$Run, [string]$Root, [switch]$IncludeIncidents)
    $path = Resolve-HarnessPath (Join-Path $Run 'output/static-report/output.js') $Root
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw 'Catalogo estruturado ausente: output/static-report/output.js. Preserve o registro e forneca o relatorio completo.' }
    $raw = Get-Content -LiteralPath $path -Raw -Encoding UTF8
    # Ler somente a atribuicao JSON usada pelo relatorio, nunca executar JavaScript.
    $match = [regex]::Match($raw, '(?s)^\s*window\["apps"\]\s*=\s*(\[.*\])\s*;?\s*$')
    if (-not $match.Success) { throw 'Formato de catalogo MTA nao suportado; nenhum registro atualizado.' }
    $apps = $match.Groups[1].Value | ConvertFrom-Json
    if (@($apps).Count -ne 1 -or -not $apps[0].PSObject.Properties['rulesets'] -or $apps[0].rulesets -isnot [Array]) { throw 'Catalogo MTA sem aplicacao unica/rulesets; confira a abrangencia do relatorio.' }
    $seen = @{}
    foreach ($ruleset in $apps[0].rulesets) {
        if (-not $ruleset.PSObject.Properties['name'] -or -not $ruleset.name) { throw 'Ruleset MTA sem identidade.' }
        if (-not $ruleset.PSObject.Properties['violations'] -or $null -eq $ruleset.violations) { continue }
        foreach ($rule in $ruleset.violations.PSObject.Properties) {
            $id = $ruleset.name + '::' + $rule.Name
            if ($seen.ContainsKey($id)) { throw "Issue duplicada no catalogo: $id" }
            $seen[$id] = $true
            $value = $rule.Value
            if (-not $value.PSObject.Properties['description'] -or -not $value.PSObject.Properties['category'] -or -not $value.PSObject.Properties['incidents'] -or $value.incidents -isnot [Array]) { throw "Issue MTA incompleta: $id" }
            $entry = [ordered]@{Id=$id;Title=[string]$value.description;Category=[string]$value.category;Count=$value.incidents.Count}
            if ($IncludeIncidents) { $entry.Details = $value }
            [pscustomobject]$entry
        }
    }
}

function Update-HarnessMigration {
    param($Context, $Selected)
    $catalog = @(Get-HarnessMtaCatalog $Selected.Run $Context.Root | Sort-Object Category,Id)
    $register = Initialize-HarnessMigration $Context.Root $Context.Active
    $path = $register.MigrationPath
    $original = [IO.File]::ReadAllText($path)
    $blocks = [regex]::Matches($original, '(?s)<!-- mta:inicio -->.*?<!-- mta:fim -->')
    if ($blocks.Count -ne 1) { throw 'Registro sem bloco MTA unico. Preserve o arquivo e use manter-migracao para reconciliar.' }
    $rows = [ordered]@{}
    foreach ($line in ($blocks[0].Value -split '\r?\n')) {
        if ($line -match '^\| ID \(' -or $line -match '^\| ---' -or $line -match '^(<!--|AGUARDANDO MTA|Rodada MTA:|Total MTA:|\s*$)') { continue }
        $cells = @($line.Trim().Trim('|').Split('|') | ForEach-Object { $_.Trim() })
        if (-not $line.StartsWith('|') -or $cells.Count -ne 8 -or -not $cells[0] -or $rows.Contains($cells[0])) { throw 'Tabela de issues invalida ou duplicada; corrija sem perder as decisoes antes de atualizar.' }
        $rows[$cells[0]] = $cells
        if ($cells[0] -notlike 'DEV-*') { $cells[4] = 'NAO REENCONTRADA' }
    }
    foreach ($issue in $catalog) {
        $fields = @($issue.Id,$issue.Title,$issue.Category,[string]$issue.Count | ForEach-Object { ([string]$_).Replace('&','&amp;').Replace('|','&#124;').Replace('<','&lt;').Replace('>','&gt;') -replace '[\r\n]+',' ' })
        $id = $fields[0]
        $human = if ($rows.Contains($id)) { @($rows[$id][5..7]) } else { @('A DEFINIR','NAO ANALISADA','') }
        $rows[$id] = @($fields) + @('PRESENTE') + $human
    }
    $manifest = Get-Content -LiteralPath (Join-Path $Selected.Run 'manifest.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    $origin = [ordered]@{RunId=$Selected.RunId;Project=$manifest.Project;Source=$manifest.Source;Run=$Selected.Run;CatalogSha256=(Get-FileHash (Join-Path $Selected.Run 'output/static-report/output.js')).Hash} | ConvertTo-Json -Compress
    $lines = @('<!-- mta:inicio -->', ('<!-- MTA ' + $origin.Replace('--','\u002d\u002d') + ' -->'),
        ('Rodada MTA: ' + $Selected.RunId + '. Origem e caminho completos no comentario MTA deste bloco.'), '',
        '| ID (ruleset::regra) | Issue | Categoria MTA | Ocorrencias | Presenca | Decisao | Andamento | Observacao/referencia |',
        '| --- | --- | --- | --- | --- | --- | --- | --- |')
    foreach ($id in $rows.Keys) { $lines += '| ' + ($rows[$id] -join ' | ') + ' |' }
    [long]$totalOccurrences = 0
    foreach ($issue in $catalog) { $totalOccurrences += $issue.Count }
    $lines += @('', "Total MTA: $($catalog.Count) issues (regras) / $totalOccurrences ocorrencias. Somente a rodada carregada; exclui manuais e nao reencontradas.")
    $lines += '<!-- mta:fim -->'
    $updated = $original.Substring(0,$blocks[0].Index) + ($lines -join "`n") + $original.Substring($blocks[0].Index + $blocks[0].Length)
    if ($updated -cne $original) {
        $temp = $path + '.' + [guid]::NewGuid().ToString('N') + '.tmp'
        try {
            [IO.File]::WriteAllText($temp,$updated,(New-Object Text.UTF8Encoding($false)))
            for ($attempt = 0; $attempt -lt 3; $attempt++) {
                if ([IO.File]::ReadAllText($path) -cne $original) { throw 'Registro mudou durante a atualizacao; tente novamente preservando a edicao.' }
                try { [IO.File]::Replace($temp,$path,[NullString]::Value); break }
                catch [IO.IOException] {
                    if ($attempt -eq 2) { throw }
                    # Indexadores/antivirus podem manter handle temporario sem FileShare.Delete.
                    Start-Sleep -Milliseconds 100
                }
            }
        } finally { if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp } }
    }
    $register
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

function Get-HarnessIssueProjectPaths {
    param([string]$Root, $Project)
    $source=Resolve-HarnessPath $Project.path $Root
    $planning=Resolve-HarnessPath (Join-Path $Root '.harness/planning') $Root
    $matches=@(if (Test-Path -LiteralPath $planning) {
        foreach ($folder in Get-ChildItem -LiteralPath $planning -Directory) {
            $identityPath=Resolve-HarnessPath (Join-Path $folder.FullName 'issues/project.json') $Root
            if (-not (Test-Path -LiteralPath $identityPath -PathType Leaf)) { continue }
            $identity=Get-Content -LiteralPath $identityPath -Raw -Encoding UTF8 | ConvertFrom-Json
            if ((Resolve-HarnessPath $identity.Source $Root) -ieq $source) {
                [pscustomobject]@{Folder=(Split-Path $identityPath -Parent);Name=$folder.Name;ArtifactId=$identity.ArtifactId;IdentityPath=$identityPath}
            }
        }
    })
    if ($matches.Count -gt 1) { throw 'Mais de uma pasta de issues para o mesmo Source. Confira a identidade.' }
    if ($matches.Count -eq 1) { return $matches[0] } # Nome observado no primeiro preparo e historico.
    $artifactId=$null; $reader=$null
    $pom=Join-Path $Project.path 'pom.xml'
    if (Test-Path -LiteralPath $pom -PathType Leaf) {
        try {
            $settings=New-Object Xml.XmlReaderSettings
            $settings.DtdProcessing=[Xml.DtdProcessing]::Prohibit; $settings.XmlResolver=$null
            $reader=[Xml.XmlReader]::Create($pom,$settings)
            $xml=New-Object Xml.XmlDocument; $xml.XmlResolver=$null; $xml.Load($reader)
            $node=$xml.SelectSingleNode("/*[local-name()='project']/*[local-name()='artifactId']")
            if ($node) { $artifactId=$node.InnerText.Trim() }
        } finally { if ($reader) { $reader.Dispose() } }
    }
    # Compatibilidade com projetos ainda sem identidade Maven declarada.
    $projectFolder=if ($artifactId) {$artifactId} else {$Project.name}
    if ($projectFolder -cnotmatch '^[A-Za-z0-9_][A-Za-z0-9_.-]{0,63}$' -or $projectFolder -match '^(CON|PRN|AUX|NUL|COM[0-9]|LPT[0-9])(?:\.|$)' -or $projectFolder.EndsWith('.')) { throw 'artifactId/nome do projeto nao pode ser usado como pasta. Informe uma identidade Maven literal e segura.' }
    $projectPath=Resolve-HarnessPath (Join-Path $Root ('.harness/planning/'+$projectFolder+'/issues')) $Root
    $identityPath=Join-Path $projectPath 'project.json'
    if (Test-Path -LiteralPath $identityPath -PathType Leaf) {
        $identity=Get-Content -LiteralPath $identityPath -Raw -Encoding UTF8 | ConvertFrom-Json
        if ((Resolve-HarnessPath $identity.Source $Root) -ine (Resolve-HarnessPath $Project.path $Root)) { throw "artifactId duplicado em Sources diferentes: $projectFolder. Use uma raiz de trabalho separada; nao misturar dossies." }
    }
    [pscustomobject]@{Folder=$projectPath;Name=$projectFolder;ArtifactId=$artifactId;IdentityPath=$identityPath}
}

function Get-HarnessIssuePaths {
    param([string]$Root, $Project, [string]$Id, $ProjectPaths)
    if ([string]::IsNullOrWhiteSpace($Id) -or $Id -match '[\r\n\x00]') { throw 'ID da issue ausente/invalido.' }
    $cached=[bool]$ProjectPaths
    if (-not $ProjectPaths) { $ProjectPaths=Get-HarnessIssueProjectPaths $Root $Project }
    $label = ([regex]::Replace(($Id -split '::')[-1], '[^A-Za-z0-9_-]', '-')).Trim('-','_')
    if (-not $label) { $label='issue' }
    if ($label.Length -gt 16) { $label=$label.Substring(0,16) }
    $folderLabel=if ($label.Length -gt 8) {$label.Substring(0,8)} else {$label}
    $issueFolder = $folderLabel + '__' + (Get-HarnessProjectKey $Id)
    $projectLabel=$ProjectPaths.Name
    if ($projectLabel.Length -gt 20) { $projectLabel=$projectLabel.Substring(0,20)+'-'+(Get-HarnessProjectKey $projectLabel).Substring(0,6) }
    $stem=$projectLabel+'-'+$label+'-'+(Get-HarnessProjectKey $Id).Substring(0,6)
    $folder=Join-Path $ProjectPaths.Folder $issueFolder
    if (-not $cached) { $folder=Resolve-HarnessPath $folder $Root }
    [pscustomobject]@{Folder=$folder;Stem=$stem;ArtifactId=$ProjectPaths.ArtifactId;ProjectIdentityPath=$ProjectPaths.IdentityPath;EvidenceIndexPath=(Join-Path $folder 'evidencias/LEIA-ME.md')}
}

function Initialize-HarnessIssueProject {
    param($Paths, $Project)
    if (-not (Test-Path -LiteralPath $Paths.ProjectIdentityPath -PathType Leaf)) {
        Write-HarnessJson $Paths.ProjectIdentityPath @{Project=$Project.name;Source=$Project.path;ArtifactId=$Paths.ArtifactId}
    }
}

function Get-HarnessIssueReceipts {
    param([string]$Root)
    $base=Join-Path $Root '.harness/planning'
    if (-not (Test-Path -LiteralPath $base)) { return }
    foreach ($project in Get-ChildItem -LiteralPath $base -Directory) {
        $issues=Join-Path $project.FullName 'issues'
        if (-not (Test-Path -LiteralPath $issues)) { continue }
        $null=Resolve-HarnessPath $issues $Root
        foreach ($issue in Get-ChildItem -LiteralPath $issues -Directory) {
            $null=Resolve-HarnessPath $issue.FullName $Root
            foreach ($request in Get-ChildItem -LiteralPath $issue.FullName -Directory | Where-Object Name -Match '^p_[a-f0-9]{12}$') {
                $null=Resolve-HarnessPath $request.FullName $Root
                $receipts=@(Get-ChildItem -LiteralPath $request.FullName -File -Filter 'contexto-*.json')
                if (-not $receipts.Count) { continue } # Preparo interrompido nao constitui recibo.
                if ($receipts.Count -ne 1) { throw "Solicitacao de issue ambigua: $($request.FullName)" }
                $receipts[0]
            }
        }
    }
}

function Assert-HarnessIssueFicha {
    param([string]$Path, [string]$Source, [string]$Id)
    $text=[IO.File]::ReadAllText($Path)
    $markers=[regex]::Matches($text, '(?s)<!-- issue:\s*(\{.*?\})\s*-->')
    if ($markers.Count -ne 1) { throw "Ficha exige identificacao unica issue (Source/Id): $Path" }
    $identity=$markers[0].Groups[1].Value | ConvertFrom-Json
    if ($identity.Source.Replace('\','/') -ine $Source.Replace('\','/') -or $identity.Id -cne $Id) { throw 'Ficha pertence a outro projeto/issue.' }
}

function Resolve-HarnessMtaRunDirectory {
    param([string]$Index, [string]$Root)
    $indexPath = Resolve-HarnessPath $Index $Root
    $locationPath = Join-Path $indexPath 'location.json'
    if (-not (Test-Path -LiteralPath $locationPath -PathType Leaf)) { return $indexPath }
    $location = Get-Content -LiteralPath $locationPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($location.Project -cnotmatch '^(?:[A-Za-z0-9][A-Za-z0-9_.-]{0,63}|_workspace-[a-f0-9]{24})$' -or
        -not (Test-HarnessRunFolder (Split-Path -Leaf $indexPath) $location.RunId 'mta')) { throw 'Referencia externa MTA invalida.' }
    $base = Resolve-HarnessPath $location.RunsPath $Root
    if (-not $base -or $base.Length -le 3) { throw 'Raiz externa MTA invalida.' }
    $relative = 'p__' + (Get-HarnessProjectKey $location.Project) + '/' + $location.RunId
    if ($location.PSObject.Properties['RunRelativePath']) {
        $relative = [string]$location.RunRelativePath
        if ($relative -cnotmatch '^[A-Za-z0-9][A-Za-z0-9_-]*/\d{6}-\d{6}(?:-[1-9][0-9]*)?$') { throw 'Caminho relativo externo MTA invalido.' }
    }
    $run = Resolve-HarnessPath (Join-Path $base $relative) $Root
    $manifest = Get-Content -LiteralPath (Join-Path $run 'manifest.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    # A raiz do harness pode mudar. A identidade do indice abaixo de runs permanece.
    $indexSuffix = '\.harness\runs\' + (Split-Path -Leaf (Split-Path -Parent $indexPath)) + '\' + (Split-Path -Leaf $indexPath)
    $originIndex = Resolve-HarnessPath $manifest.IndexPath $Root
    if ($manifest.Project -cne $location.Project -or $manifest.RunId -cne $location.RunId -or
        (Resolve-HarnessPath $manifest.Source $Root) -ine (Resolve-HarnessPath $location.Source $Root) -or
        $indexPath -ine ((Resolve-HarnessPath $Root $Root) + $indexSuffix) -or
        -not $originIndex -or -not $originIndex.EndsWith($indexSuffix, [StringComparison]::OrdinalIgnoreCase)) { throw 'Manifesto externo nao corresponde a referencia local.' }
    return $run
}

function Get-HarnessExternalMtaRuns {
    [CmdletBinding()]
    param([string]$Root, [string]$RunsPath)
    if (-not $RunsPath) { return }
    $base = Resolve-HarnessPath $RunsPath $Root
    if (-not (Test-Path -LiteralPath $base -PathType Container)) {
        Write-Warning "Pasta MTA externa indisponivel: $base"
        return
    }
    # Apenas projeto/rodada; nao percorrer snapshots nem seguir links de diretorio.
    foreach ($projectFolder in Get-ChildItem -LiteralPath $base -Directory) {
        if ($projectFolder.Attributes -band [IO.FileAttributes]::ReparsePoint) { Write-Warning "Link MTA externo ignorado: $($projectFolder.FullName)"; continue }
        foreach ($folder in Get-ChildItem -LiteralPath $projectFolder.FullName -Directory) {
            $record = [pscustomobject]@{Run=$folder.FullName;RunId=$null;CreatedAtUtc=[DateTime]::MinValue;Manifest=$null;Source=$null;Problem=$null;ExternalInput=$true}
            try {
                if ($folder.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Link MTA externo ignorado.' }
                $manifest = Get-Content -LiteralPath (Join-Path $folder.FullName 'manifest.json') -Raw -Encoding UTF8 | ConvertFrom-Json
                $record.Source = Resolve-HarnessPath $manifest.Source $Root
                if (-not $record.Source) { throw 'Source ausente.' }
                if ($manifest.RunId -cnotmatch '^[a-f0-9]{32}$' -or $manifest.Project -cnotmatch '^(?:[A-Za-z0-9][A-Za-z0-9_.-]{0,63}|_workspace-[a-f0-9]{24})$') { throw 'Identidade MTA externa invalida.' }
                $record.RunId = $manifest.RunId
                $record.CreatedAtUtc = ([DateTimeOffset]::Parse($manifest.CreatedAtUtc)).UtcDateTime
                $record.Manifest = $manifest
            } catch { $record.Problem = "MTA externo $($folder.FullName): $($_.Exception.Message)" }
            $record
        }
    }
}

function Get-HarnessMtaRuns {
    param([string]$Root, [string]$Project, [string]$Source, [string]$RunsPath)
    if ($Project -cnotmatch '^(?:[A-Za-z0-9][A-Za-z0-9_.-]{0,63}|_workspace-[a-f0-9]{24})$') { throw 'Identidade de projeto invalida.' }
    $base = Resolve-HarnessPath (Join-Path $Root '.harness/runs') $Root
    $key = Get-HarnessProjectKey $Project
    $projects = @(if (Test-Path -LiteralPath $base -PathType Container) { Get-ChildItem -LiteralPath $base -Directory | Where-Object {
        $_.Name -ceq $Project -or $_.Name.EndsWith(('__' + $key), [StringComparison]::Ordinal)
    } })
    $records = @(foreach ($directory in $projects) {
        $projectPath = Resolve-HarnessPath $directory.FullName $Root
        foreach ($folder in Get-ChildItem -LiteralPath $projectPath -Directory) {
            if ($folder.Name -cnotmatch '^(?:[a-f0-9]{32}|mta_\d{4}-\d{2}-\d{2}_\d{2}-\d{2}-\d{2}[+-]\d{4}__[a-f0-9]{12})$') { continue }
            $record = [pscustomobject]@{Run=$folder.FullName; RunId=$null; CreatedAtUtc=$folder.CreationTimeUtc; Manifest=$null; Problem=$null; ExternalInput=$false}
            try {
                $locationPath = Join-Path $folder.FullName 'location.json'
                if (Test-Path -LiteralPath $locationPath -PathType Leaf) {
                    $location = Get-Content -LiteralPath $locationPath -Raw -Encoding UTF8 | ConvertFrom-Json
                    if ($location.Project -ceq $Project -and (Test-HarnessRunFolder $folder.Name $location.RunId 'mta')) { $record.RunId = $location.RunId }
                }
                $record.Run = Resolve-HarnessMtaRunDirectory $folder.FullName $Root
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
    foreach ($external in Get-HarnessExternalMtaRuns $Root $RunsPath) {
        # Caminho da origem e a unica associacao automatica; nomes de pastas nao bastam.
        if (-not $Source -or $external.Source -ine (Resolve-HarnessPath $Source $Root)) {
            if ($external.Problem) { Write-Warning $external.Problem }
            continue
        }
        if (@($records | Where-Object { $_.Run -ieq $external.Run }).Count) { continue }
        $records += $external
    }
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

function New-HarnessExternalRunDirectory {
    param($Context, [string]$CreatedAtUtc)
    $base = $Context.Config.mta.runsPath
    $label = ([regex]::Replace($Context.Active.label, '[^A-Za-z0-9_-]', '-')).Trim('-','_')
    if (-not $label) { $label = 'projeto' }
    if ($label.Length -gt 64) { $label = $label.Substring(0,64) }
    if ($label -match '^(CON|PRN|AUX|NUL|COM[0-9]|LPT[0-9])$') { $label = 'projeto-' + $label }
    for ($number = 1; ; $number++) {
        $name = if ($number -eq 1) { $label } else { $label + '-' + $number }
        $projectPath = Resolve-HarnessPath (Join-Path $base $name) $Context.Root
        $receipt = Join-Path $projectPath 'project.json'
        if (Test-Path -LiteralPath $projectPath) {
            # Nao adotar pastas desconhecidas nem misturar fontes homonimas.
            if (-not (Test-Path -LiteralPath $receipt -PathType Leaf)) { continue }
            $identity = Get-Content -LiteralPath $receipt -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($identity.Project -ceq $Context.Active.name -and
                (Resolve-HarnessPath $identity.Source $Context.Root) -ieq $Context.Active.path) { break }
            continue
        }
        try { $null = New-Item -ItemType Directory -Path $projectPath -ErrorAction Stop }
        catch {
            if (Test-Path -LiteralPath $projectPath) { continue }
            throw
        }
        Write-HarnessJson $receipt @{Project=$Context.Active.name; Label=$Context.Active.label; Source=$Context.Active.path}
        break
    }
    $stamp = ([DateTimeOffset]::Parse($CreatedAtUtc)).ToLocalTime().ToString('yyMMdd-HHmmss', [Globalization.CultureInfo]::InvariantCulture)
    for ($number = 1; ; $number++) {
        $name = if ($number -eq 1) { $stamp } else { $stamp + '-' + $number }
        $run = Resolve-HarnessPath (Join-Path $projectPath $name) $Context.Root
        if (Test-Path -LiteralPath $run) { continue }
        # Criacao sem Force reserva o destino, inclusive entre dois harnesses.
        try { $null = New-Item -ItemType Directory -Path $run -ErrorAction Stop; return $run }
        catch {
            if (Test-Path -LiteralPath $run) { continue }
            throw
        }
    }
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
        $indexPath = Resolve-HarnessPath (Join-Path $Context.Root ('.harness/runs/' + $projectFolder + '/' + $runFolder)) $Context.Root
    } while (Test-Path -LiteralPath $indexPath)
    $run = $indexPath
    if ($Context.Config.mta.runsPath) { $run = New-HarnessExternalRunDirectory $Context $createdAt }
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
    if ($run -ine $indexPath) { $manifest.IndexPath = $indexPath }
    Write-HarnessJson (Join-Path $run 'manifest.json') $manifest
    if ($run -ine $indexPath) {
        $relative = (Split-Path -Leaf (Split-Path -Parent $run)) + '/' + (Split-Path -Leaf $run)
        Write-HarnessJson (Join-Path $indexPath 'location.json') @{Project=$Context.Active.name; Source=$Context.Active.path; RunId=$id; RunsPath=$Context.Config.mta.runsPath; RunRelativePath=$relative}
    }
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

Export-ModuleMember -Function Read-HarnessConfig, New-HarnessWorkspace, Write-HarnessJson, Resolve-HarnessPath, Get-MtaRequirements, New-MtaSnapshot, Invoke-MtaAnalysis, Get-ActiveMtaRun, Get-LastMtaReport, Format-HarnessDate, Test-HarnessRunFolder, Get-HarnessProjectKey, Get-HarnessProjectFolder, Get-HarnessMtaRuns, Find-HarnessMtaRun, Get-HarnessFiles, Resolve-HarnessMtaRunDirectory
Export-ModuleMember -Function Initialize-HarnessMigration, Get-HarnessMtaCatalog, Update-HarnessMigration
Export-ModuleMember -Function Get-HarnessExternalMtaRuns
Export-ModuleMember -Function Resolve-HarnessMigrationPath
Export-ModuleMember -Function Get-HarnessMigrationPaths
Export-ModuleMember -Function Get-HarnessIssuePaths, Get-HarnessIssueProjectPaths, Get-HarnessIssueReceipts, Initialize-HarnessIssueProject
Export-ModuleMember -Function Assert-HarnessIssueFicha
Export-ModuleMember -Function Open-HarnessEditor
