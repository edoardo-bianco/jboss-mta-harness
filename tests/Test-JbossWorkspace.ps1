#requires -Version 5.1
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $root 'scripts/Harness.psm1') -Force -DisableNameChecking
function Assert($condition, $message) { if (-not $condition) { throw $message } }
$area = Join-Path $root ('.harness/tests/jboss-workspace-' + [guid]::NewGuid().ToString('N'))
$null = [IO.Directory]::CreateDirectory($area)
$config = Get-Content (Join-Path $root 'config/harness.example.json') -Raw | ConvertFrom-Json
$context = [pscustomobject]@{ Root=$area; Config=$config }
$path = New-HarnessWorkspace $context
$workspace = Get-Content $path -Raw | ConvertFrom-Json
Assert ($workspace.launch.configurations.Count -eq 2) 'Faltam attaches Java dos dois EAPs.'
Assert ($workspace.launch.configurations[0].port -ne $workspace.launch.configurations[1].port) 'Debug dos EAPs deve usar portas diferentes.'
Assert ($workspace.launch.configurations[0].request -eq 'attach' -and $workspace.launch.configurations[0].hostName -eq '127.0.0.1') 'Debug deve conectar localmente.'
$workspace.settings | Add-Member NoteProperty 'editor.fontSize' 17
$workspace.folders += [pscustomobject]@{name='manual'; path='C:/manual'}
$workspace.launch.configurations += [pscustomobject]@{name='Meu debug'; type='java'; request='attach'; port=5005}
$workspace | Add-Member NoteProperty extensions ([pscustomobject]@{recommendations=@('redhat.java','minha.extensao')}) -Force
Write-HarnessJson $path $workspace
$config.eap.eap74.debugPort = 9009
$null = New-HarnessWorkspace $context
$updated = Get-Content $path -Raw | ConvertFrom-Json
Assert ($updated.settings.'editor.fontSize' -eq 17 -and @($updated.folders | Where-Object name -eq 'manual').Count -eq 1) 'Regeneracao perdeu ajustes/pastas.'
Assert (@($updated.launch.configurations | Where-Object name -eq 'Meu debug').Count -eq 1) 'Regeneracao perdeu launch manual.'
Assert (@($updated.launch.configurations | Where-Object port -eq 9009).Count -eq 1) 'Porta configurada nao propagou.'
Assert ($updated.extensions.recommendations -contains 'vscjava.vscode-java-debug' -and $updated.extensions.recommendations -contains 'minha.extensao') 'Extensoes nao preservadas.'
$config.eap.eap74.debugPort = $config.eap.eap71.debugPort
$rejected=$false
try { New-HarnessWorkspace $context | Out-Null } catch { $rejected=$true }
Assert $rejected 'Colisao debug deve ser recusada.'
Write-Output 'PASS: attach Java, portas e preservacao do workspace.'
