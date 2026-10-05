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
$config.mta.runsPath = Join-Path $area 'mta externo'
$configPath = Join-Path $fixture 'config.json'
$config | ConvertTo-Json -Depth 8 | Set-Content $configPath -Encoding UTF8
$context = Read-HarnessConfig $configPath $fixture
Assert ($context.Active.path -eq $app) 'Alvo inicial incorreto.'
$path = New-HarnessWorkspace $context
Assert (Test-Path (Initialize-HarnessMigration $fixture $context.Active).MigrationPath) 'Workspace deve preparar registro por projeto.'
$registers = @(Get-ChildItem (Join-Path $fixture '.harness/projetos') -Filter migracao-*.md -Recurse)
Assert ($registers.Count -eq 2) 'Workspace deve preparar todos os projetos importados.'
$workspace = Get-Content $path -Raw | ConvertFrom-Json
Assert ($workspace.folders.Count -eq 3) 'Workspace deve conter harness e dois repos.'
Assert ($workspace.folders[0].name -eq 'harness') 'Raiz de tarefas ausente.'
Assert ($workspace.folders[1].path -eq $app) 'Path com espacos alterado.'
$readAccessKey = 'github.copilot.chat.additionalReadAccessPaths'
Assert ($workspace.settings.PSObject.Properties[$readAccessKey] -and @($workspace.settings.$readAccessKey).Count -eq 1 -and $workspace.settings.$readAccessKey[0] -eq $context.Config.mta.runsPath.Replace('\','/')) 'Workspace deve autorizar leitura da raiz MTA configurada.'
$workspace.settings.$readAccessKey = @('D:/evidencias escolhidas')
$workspace.settings | Add-Member NoteProperty 'editor.fontSize' 17
$workspace | ConvertTo-Json -Depth 8 | Set-Content $path -Encoding UTF8
$config.activeProject = 'biblioteca'
$config | ConvertTo-Json -Depth 8 | Set-Content $configPath -Encoding UTF8
$context = Read-HarnessConfig $configPath $fixture
Assert ($context.Active.path -eq $other) 'Troca de projeto nao foi lida da configuracao.'
$null = New-HarnessWorkspace $context
Assert (@(Get-ChildItem (Join-Path $fixture '.harness/workspace-backups') -File).Count -eq 1) 'Workspace anterior nao preservado.'
$workspace = Get-Content $path -Raw | ConvertFrom-Json
Assert (@($workspace.settings.$readAccessKey).Count -eq 1 -and $workspace.settings.$readAccessKey[0] -eq 'D:/evidencias escolhidas') 'Gerador alterou permissao escolhida no workspace.'
Assert ($workspace.settings.'editor.fontSize' -eq 17) 'Gerador alterou outra configuracao do usuario.'
$workspace.settings.$readAccessKey = @()
Write-HarnessJson $path $workspace
$null = New-HarnessWorkspace $context
$workspace = Get-Content $path -Raw | ConvertFrom-Json
Assert ($workspace.settings.PSObject.Properties[$readAccessKey] -and @($workspace.settings.$readAccessKey).Count -eq 0) 'Gerador deve respeitar revogacao por lista vazia.'
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
# Clone novo sem aplicacoes; importar projetos externos continua funcionando.
$emptyRoot = Join-Path $area 'harness-vazio'
$config = Get-Content (Join-Path $root 'config/harness.example.json') -Raw | ConvertFrom-Json
Assert (@($config.repositories).Count -eq 0 -and $null -eq $config.activeProject) 'Clone deve iniciar sem exemplos cadastrados.'
$configPath = Join-Path $emptyRoot 'config.json'
Write-HarnessJson $configPath $config
$context = Read-HarnessConfig $configPath $emptyRoot
Assert ($context.Projects.Count -eq 0 -and $null -eq $context.Active) 'Configuracao vazia deve ser valida.'
Assert ($context.Config.tools.mtaExecutable -eq $null) 'Clone nao deve carregar ferramentas pessoais.'
$path = New-HarnessWorkspace $context
$workspace = Get-Content $path -Raw | ConvertFrom-Json
Assert ($workspace.folders.Count -eq 1 -and $workspace.folders[0].name -eq 'harness') 'Workspace inicial deve conter somente o harness.'
Assert (-not $workspace.settings.PSObject.Properties[$readAccessKey]) 'RunsPath null nao deve conceder acesso externo por padrao.'
$starter = Get-Content (Join-Path $root 'iniciar-harness.code-workspace') -Raw | ConvertFrom-Json
Assert ($starter.folders.Count -eq 1 -and $starter.folders[0].path -eq '.') 'Workspace versionado deve conter somente o harness.'
Set-Content (Join-Path $app 'pom.xml') '<project/>'
$workspace.folders += [pscustomobject]@{name='Aplicacao importada';path=$app}
Write-HarnessJson $path $workspace
$context = Read-HarnessConfig $configPath $emptyRoot -WorkspacePath $path
Assert ($context.Projects.Count -eq 1 -and $context.Projects[0].path -eq $app) 'Importacao manual nao foi descoberta.'
$null = New-HarnessWorkspace $context
$workspace = Get-Content $path -Raw | ConvertFrom-Json
Assert ($workspace.folders.Count -eq 2) 'Regeneracao deve preservar importacao manual.'
$nested = Join-Path $emptyRoot 'exemplos/migracao-cache-antes'
$null = [IO.Directory]::CreateDirectory($nested)
$config.repositories = @(@{name='interno';path=$nested}); $config.activeProject = 'interno'
Write-HarnessJson $configPath $config
$rejected = $false
try { Read-HarnessConfig $configPath $emptyRoot | Out-Null } catch { $rejected = $true }
Assert $rejected 'Aplicacao dentro do harness nao deve ter excecao por nome.'
Write-Output 'PASS: configuracao, troca de alvo, caminhos, workspace vazio, importacao externa e backup.'
