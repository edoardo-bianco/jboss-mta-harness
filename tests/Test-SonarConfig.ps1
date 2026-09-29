#requires -Version 5.1
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
function Assert($condition, $message) { if (-not $condition) { throw $message } }
$area=Join-Path $root ('.harness/tests/sonar-config-' + [guid]::NewGuid().ToString('N'))
$null=New-Item -ItemType Directory -Path $area
$path=Join-Path $area 'config.json'
$original=[pscustomobject]@{tools=@{applicationMavenSettingsPath='C:/corporativo/settings.xml'}; custom='preservar'}
$original | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $path
& powershell.exe -NoProfile -File (Join-Path $root 'scripts/configurar-caminhos.ps1') -ConfigPath $path
Assert ($LASTEXITCODE -eq 0) 'Configuracao falhou.'
$config=Get-Content -Raw -LiteralPath $path | ConvertFrom-Json
Assert ($config.sonar.scannerVersion -eq '5.8.0.7211' -and $config.sonar.ceTimeoutSeconds -eq 300) 'JSON antigo nao recebeu defaults Sonar.'
Assert ($config.custom -eq 'preservar' -and $config.tools.applicationMavenSettingsPath -eq $original.tools.applicationMavenSettingsPath) 'Configuracao existente alterada.'
$config.sonar.serverUrl='https://sonar.empresa'; $config.sonar.scannerVersion='5.7.0.7130'
$config.sonar.PSObject.Properties.Remove('profiles')
$config | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $path
& powershell.exe -NoProfile -File (Join-Path $root 'scripts/configurar-caminhos.ps1') -ConfigPath $path
$config=Get-Content -Raw -LiteralPath $path | ConvertFrom-Json
Assert ($config.sonar.serverUrl -eq 'https://sonar.empresa' -and $config.sonar.scannerVersion -eq '5.7.0.7130' -and $config.sonar.profiles.Count -eq 0) 'Override existente perdido ou campo ausente nao preenchido.'
$hash=(Get-FileHash $path).Hash
& powershell.exe -NoProfile -File (Join-Path $root 'scripts/configurar-caminhos.ps1') -ConfigPath $path
Assert ((Get-FileHash $path).Hash -eq $hash) 'Configuracao completa nao deve ser reescrita.'
Write-Output 'PASS: defaults Sonar, preservacao de overrides e idempotencia.'
