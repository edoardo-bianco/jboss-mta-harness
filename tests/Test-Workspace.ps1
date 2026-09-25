#requires -Version 5.1
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $root 'scripts/Harness.psm1') -Force
$area = Join-Path $root ('.harness/tests/' + [guid]::NewGuid().ToString('N'))
$fixture = Join-Path $area 'harness'
$app = Join-Path $area 'app com espaco'
$other = Join-Path $area 'biblioteca'
foreach ($dir in @($fixture, $app, $other)) { $null = New-Item -ItemType Directory -Path $dir -Force }
function Assert($condition, $message) { if (-not $condition) { throw $message } }
$config = Get-Content (Join-Path $root 'config/harness.example.json') -Raw | ConvertFrom-Json
$config.repositories = @(@{name='api'; path=$app}, @{name='biblioteca'; path=$other})
$config.activeProject = 'api'
$configPath = Join-Path $fixture 'config.json'
$config | ConvertTo-Json -Depth 8 | Set-Content $configPath -Encoding UTF8
$context = Read-HarnessConfig $configPath $fixture
Assert ($context.Active.path -eq $app) 'Alvo inicial incorreto.'
$path = New-HarnessWorkspace $context
$workspace = Get-Content $path -Raw | ConvertFrom-Json
Assert ($workspace.folders.Count -eq 3) 'Workspace deve conter harness e dois repos.'
Assert ($workspace.folders[0].name -eq 'harness') 'Raiz de tarefas ausente.'
Assert ($workspace.folders[1].path -eq $app) 'Path com espacos alterado.'
$workspace.settings | Add-Member NoteProperty 'editor.fontSize' 17
$workspace | ConvertTo-Json -Depth 8 | Set-Content $path -Encoding UTF8
$config.activeProject = 'biblioteca'
$config | ConvertTo-Json -Depth 8 | Set-Content $configPath -Encoding UTF8
$context = Read-HarnessConfig $configPath $fixture
Assert ($context.Active.path -eq $other) 'Troca de projeto nao foi lida da configuracao.'
$null = New-HarnessWorkspace $context
Assert (@(Get-ChildItem (Join-Path $fixture '.harness/workspace-backups') -File).Count -eq 1) 'Workspace anterior nao preservado.'
$config.activeProject = 'inexistente'
$config | ConvertTo-Json -Depth 8 | Set-Content $configPath -Encoding UTF8
$rejected = $false
try { Read-HarnessConfig $configPath $fixture | Out-Null } catch { $rejected = $true }
Assert $rejected 'Projeto desconhecido deve falhar, sem escolher outro.'
$config.activeProject = 'api'
$config.repositories[0].path = $fixture
$config | ConvertTo-Json -Depth 8 | Set-Content $configPath -Encoding UTF8
$rejected = $false
try { Read-HarnessConfig $configPath $fixture | Out-Null } catch { $rejected = $true }
Assert $rejected 'Analisar a propria raiz do harness deve ser recusado.'
# Um clone novo ja inclui os exemplos e resolve seus caminhos a partir do harness.
$null = New-Item -ItemType Directory -Path (Join-Path $fixture 'exemplos') -Force
foreach ($name in @('migracao-cache-antes','migracao-cache-depois')) {
    Copy-Item -LiteralPath (Join-Path $root "exemplos/$name") -Destination (Join-Path $fixture 'exemplos') -Recurse
}
$config = Get-Content (Join-Path $root 'config/harness.example.json') -Raw | ConvertFrom-Json
$config | ConvertTo-Json -Depth 8 | Set-Content $configPath -Encoding UTF8
$context = Read-HarnessConfig $configPath $fixture
Assert ($context.Active.path -eq (Join-Path $fixture 'exemplos/migracao-cache-antes').Replace('/','\')) 'Exemplo ANTES deve resolver dentro do clone.'
Assert ($context.Config.tools.mtaExecutable -eq $null) 'Clone nao deve carregar ferramentas pessoais.'
$path = New-HarnessWorkspace $context
$workspace = Get-Content $path -Raw | ConvertFrom-Json
Assert ($workspace.folders.Count -eq 3) 'Clone deve abrir harness e dois exemplos.'
$config.activeProject = 'migracao-cache-depois'
$config | ConvertTo-Json -Depth 8 | Set-Content $configPath -Encoding UTF8
$context = Read-HarnessConfig $configPath $fixture
Assert ($context.Active.path.EndsWith('exemplos\migracao-cache-depois')) 'Troca para exemplo DEPOIS falhou.'
$config.repositories += @(@{name='corporativo'; path=$app})
$config.activeProject = 'corporativo'
$config | ConvertTo-Json -Depth 8 | Set-Content $configPath -Encoding UTF8
$context = Read-HarnessConfig $configPath $fixture
Assert ($context.Active.path -eq $app) 'Repositorio real externo deve continuar suportado.'
$config.repositories[2].path = Join-Path $fixture 'exemplos'
$config | ConvertTo-Json -Depth 8 | Set-Content $configPath -Encoding UTF8
$rejected = $false
try { Read-HarnessConfig $configPath $fixture | Out-Null } catch { $rejected = $true }
Assert $rejected 'Excecao dos exemplos nao deve permitir analisar sua pasta pai.'
$withoutExamples = Join-Path $area 'harness-sem-exemplos'
$config.repositories = @(@{name='corporativo'; path=$app})
$config.activeProject = 'corporativo'
$configPath = Join-Path $withoutExamples 'config.json'
Write-HarnessJson $configPath $config
$context = Read-HarnessConfig $configPath $withoutExamples
$path = New-HarnessWorkspace $context
$workspace = Get-Content $path -Raw | ConvertFrom-Json
Assert ($workspace.folders.Count -eq 2 -and $workspace.folders[1].name -eq 'corporativo') 'Workspace corporativo deve funcionar sem exemplos presentes.'
Write-Output 'PASS: configuracao, troca de alvo, caminhos, workspace, backup e exemplos portaveis.'
