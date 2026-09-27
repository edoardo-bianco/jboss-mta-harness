#requires -Version 5.1
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $root 'scripts/Harness.psm1') -Force
function Assert($condition, $message) { if (-not $condition) { throw $message } }
$area = Join-Path $root ('.harness/tests/' + [guid]::NewGuid().ToString('N'))
$fixture = Join-Path $area 'harness'
$app = Join-Path $area 'app com espaco'
$null = New-Item -ItemType Directory -Path $app -Force
$config = Get-Content (Join-Path $root 'config/harness.example.json') -Raw | ConvertFrom-Json
Assert ($null -ne $config.tools.PSObject.Properties['applicationMavenHome']) 'Falta Maven independente da aplicacao.'
$config.repositories = @(@{name='app'; path=$app})
$config.activeProject = 'app'
$config.tools.mavenHome = Join-Path $area 'maven mta'
$config.tools.applicationMavenHome = Join-Path $area 'maven app'
$config.tools.mavenSettingsPath = Join-Path $area 'mta-settings.xml'
$config.tools.applicationMavenSettingsPath = Join-Path $area 'app-settings.xml'
$config.tools.applicationJdk8Home = Join-Path $area 'jdk app'
$config.tools.mtaJdkHome = Join-Path $area 'jdk mta'
$configPath = Join-Path $fixture 'config.json'
Write-HarnessJson $configPath $config
$context = Read-HarnessConfig $configPath $fixture
$workspace = Get-Content (New-HarnessWorkspace $context) -Raw | ConvertFrom-Json
Assert ($workspace.settings.'maven.executable.path' -eq (Join-Path $config.tools.applicationMavenHome 'bin/mvn.cmd')) 'IDE usou Maven do MTA.'
Assert ($workspace.settings.'java.configuration.maven.userSettings' -eq $config.tools.applicationMavenSettingsPath) 'IDE usou settings do MTA.'
Assert ($context.Config.tools.mavenHome -eq $config.tools.mavenHome) 'Maven do MTA foi alterado.'
Assert ($workspace.settings.'maven.terminal.useJavaHome' -eq $false) 'Terminal Maven nao deve herdar java.home da IDE.'
Assert ($workspace.settings.'maven.terminal.customEnv'[0].environmentVariable -eq 'JAVA_HOME' -and $workspace.settings.'maven.terminal.customEnv'[0].value -eq $config.tools.applicationJdk8Home) 'Terminal Maven nao recebeu Java da aplicacao.'
Assert ($workspace.settings.'maven.settingsFile' -eq $config.tools.applicationMavenSettingsPath) 'Extensao Maven nao recebeu settings da aplicacao.'
Assert ($workspace.settings.'java.jdt.ls.java.home' -eq $config.tools.mtaJdkHome) 'Runtime do servico Java foi alterado.'
# Regenerar deve acompanhar os novos caminhos da aplicacao, sem reutilizar os antigos.
$config.tools.applicationJdk8Home = Join-Path $area 'outro jdk app'
$config.tools.applicationMavenSettingsPath = Join-Path $area 'outro-settings.xml'
Write-HarnessJson $configPath $config
$context = Read-HarnessConfig $configPath $fixture
$workspace = Get-Content (New-HarnessWorkspace $context) -Raw | ConvertFrom-Json
Assert ($workspace.settings.'maven.terminal.customEnv'[0].value -eq $config.tools.applicationJdk8Home -and $workspace.settings.'maven.settingsFile' -eq $config.tools.applicationMavenSettingsPath) 'Regeneracao conservou caminhos antigos.'
# Sem override, delegar settings/repositorio aos padroes Maven da maquina.
$config.tools.applicationMavenSettingsPath = $null
$config.tools.mavenSettingsPath = $null
Write-HarnessJson $configPath $config
$context = Read-HarnessConfig $configPath $fixture
$workspace = Get-Content (New-HarnessWorkspace $context) -Raw | ConvertFrom-Json
Assert (-not $workspace.settings.PSObject.Properties['maven.settingsFile'] -and -not $workspace.settings.PSObject.Properties['java.configuration.maven.userSettings']) 'Settings null deve respeitar os padroes da maquina, sem overrides na IDE.'
Assert (-not (Test-Path (Join-Path $fixture '.harness/maven'))) 'Gerador nao deve criar settings/cache Maven proprio.'
# JSON antigo continua apto para MTA, sem habilitar build por fallback silencioso.
$config.tools.PSObject.Properties.Remove('applicationMavenHome')
$config.tools.PSObject.Properties.Remove('applicationMavenSettingsPath')
Write-HarnessJson $configPath $config
$context = Read-HarnessConfig $configPath $fixture
Assert ($null -eq $context.Config.tools.applicationMavenHome) 'JSON antigo nao deve herdar Maven MTA no build.'
Write-Output 'PASS: Maven/settings separados, workspace e JSON antigo.'
