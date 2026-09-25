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
Write-Output 'PASS: configuracao, troca de alvo, caminhos, workspace e backup.'
