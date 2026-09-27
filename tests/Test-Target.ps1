#requires -Version 5.1
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $root 'scripts/Harness.psm1') -Force
function Assert($condition, $message) { if (-not $condition) { throw $message } }
$area = Join-Path $root ('.harness/tests/' + [guid]::NewGuid().ToString('N'))
$fixture = Join-Path $area 'harness'
$parent = Join-Path $area 'simtr-api'
$app = Join-Path $parent 'simtr-outsourcing-api'
$other = Join-Path $area 'outro repo/simtr-outsourcing-api'
$docs = Join-Path $area 'documentacao'
foreach ($dir in @($fixture, $parent, $app, $other, $docs)) { $null = New-Item -ItemType Directory -Path $dir -Force }
foreach ($dir in @($parent, $app, $other)) { Set-Content -LiteralPath (Join-Path $dir 'pom.xml') '<project><packaging>pom</packaging></project>' }
$config = Get-Content (Join-Path $root 'config/harness.example.json') -Raw | ConvertFrom-Json
$config.PSObject.Properties.Remove('repositories')
$config.PSObject.Properties.Remove('activeProject')
$configPath = Join-Path $fixture 'config.json'
Write-HarnessJson $configPath $config
$workspacePath = Join-Path $area 'projetos.code-workspace'
$workspaceJson = '{
  // Sem cadastro de projetos no JSON do harness.
  "folders": [
    {"name": "harness", "path": "harness"},
    {"path": "simtr-api"},
    {"path": "simtr-api/simtr-outsourcing-api"},
    {"path": "documentacao"},
  ],
  "settings": {"fixture.url": "https://example.invalid/a/*b*/,}"},
}'
Set-Content -LiteralPath $workspacePath -Value $workspaceJson -Encoding UTF8
$originalConfig = (Get-FileHash $configPath).Hash
$originalWorkspace = (Get-FileHash $workspacePath).Hash
$selected = Read-HarnessConfig $configPath $fixture -WorkspacePath $workspacePath -Target 'simtr-outsourcing-api'
Assert ($selected.Active.path -eq $app) 'Projeto do workspace nao foi selecionado.'
Assert ($selected.Projects.Count -eq 2) 'Lista deve incluir somente projetos Maven, inclusive packaging pom.'
Assert ($null -eq $selected.Config.activeProject -and $selected.Config.repositories.Count -eq 0) 'Selecao cadastrou projetos no JSON.'
$byPath = Read-HarnessConfig $configPath $fixture -WorkspacePath $workspacePath -Target $app
Assert ($byPath.Active.name -eq $selected.Active.name) 'Nome e caminho devem usar o mesmo historico.'
& (Get-Module Harness) { function script:Read-Host { param($Prompt) '2' } }
$interactive = Read-HarnessConfig $configPath $fixture -WorkspacePath $workspacePath -SelectTarget
Assert ($interactive.Active.path -eq $app) 'Menu nao respeitou a escolha do projeto.'
Assert ((Get-FileHash $configPath).Hash -eq $originalConfig -and (Get-FileHash $workspacePath).Hash -eq $originalWorkspace) 'Selecao alterou configuracao ou workspace.'
$config | Add-Member NoteProperty activeProject 'simtr-api'
Write-HarnessJson $configPath $config
& (Get-Module Harness) { function script:Read-Host { param($Prompt) '' } }
$default = Read-HarnessConfig $configPath $fixture -WorkspacePath $workspacePath -SelectTarget
Assert ($default.Active.path -eq $parent) 'Enter nao usou o padrao opcional.'
$override = Read-HarnessConfig $configPath $fixture -WorkspacePath $workspacePath -Target 'simtr-outsourcing-api'
Assert ($override.Active.path -eq $app -and $override.Config.activeProject -eq 'simtr-api') 'Override alterou o padrao.'
$workspace = @{folders=@(@{path='harness'}, @{path='simtr-api'}, @{name='API renomeada'; path='simtr-api/simtr-outsourcing-api'}, @{name='API renomeada'; path='outro repo/simtr-outsourcing-api'})}
Write-HarnessJson $workspacePath $workspace
$renamed = Read-HarnessConfig $configPath $fixture -WorkspacePath $workspacePath -Target $app
$added = Read-HarnessConfig $configPath $fixture -WorkspacePath $workspacePath -Target $other
Assert ($renamed.Active.name -eq $selected.Active.name) 'Renomear no Explorer perdeu o historico.'
Assert ($added.Active.path -eq $other -and $added.Active.name -ne $renamed.Active.name) 'Projetos homonimos misturaram historicos.'
foreach ($target in @('inexistente', 'API renomeada', $docs, $fixture)) {
    $rejected = $false
    try { Read-HarnessConfig $configPath $fixture -WorkspacePath $workspacePath -Target $target | Out-Null } catch { $rejected = $true }
    Assert $rejected "Alvo ausente/ambiguo aceito: $target"
}
& (Get-Module Harness) { function script:Read-Host { param($Prompt) 'q' } }
$rejected = $false
try { Read-HarnessConfig $configPath $fixture -WorkspacePath $workspacePath -SelectTarget | Out-Null } catch { $rejected = $true }
Assert $rejected 'Cancelar nao interrompeu a selecao.'
Write-Output 'PASS: projetos do workspace, menu, padrao opcional, adicao/renomeacao, isolamento e configuracoes preservadas.'
