#requires -Version 5.1
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $root 'scripts/HarnessSonar.psm1') -Force -DisableNameChecking
$module = Get-Module HarnessSonar
function Assert($condition, $message) { if (-not $condition) { throw $message } }
$area = Join-Path $root ('.harness/tests/sonar-launcher-' + [guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $area
# Somente credencial sintetica. O filho confere o ambiente real e simula saida hostil.
$secret = 'synthetic-scanner-123456789'
$child = Join-Path $area 'scanner.ps1'
$launcher = Join-Path $area 'maven simulado.cmd'
$childCode = @'
$ErrorActionPreference = 'Stop'
$mode = $args[0]
$secret = 'synthetic-scanner-123456789'
if ($env:SONARQUBE_SCANNER_PARAMS) { throw 'Configuracao legada vazou ao scanner.' }
if ($mode -eq 'Basic') {
    if ($env:SONAR_TOKEN) { throw 'Basic recebeu token Bearer concorrente.' }
    $config = $env:SONAR_SCANNER_JSON_PARAMS | ConvertFrom-Json
    if ($config.'sonar.login' -cne $secret -or $config.'sonar.password' -cne '' -or $config.PSObject.Properties['sonar.token']) {
        throw 'Basic nao recebeu login e senha vazia.'
    }
} else {
    if ($env:SONAR_TOKEN -cne $secret -or $env:SONAR_SCANNER_JSON_PARAMS) { throw 'Bearer foi alterado.' }
}
Write-Output ('raw=' + $secret)
Write-Output ('base64=' + [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($secret + ':')))
Write-Output ('json=' + $env:SONAR_SCANNER_JSON_PARAMS)
Write-Output ('AUTH_OK=' + $mode)
exit 7
'@
[IO.File]::WriteAllText($child, $childCode)
[IO.File]::WriteAllText($launcher, "@echo off`r`npowershell.exe -NoProfile -File `"$child`" %*`r`nexit /b %ERRORLEVEL%`r`n")
$saved = @{}
foreach ($name in @('SONAR_TOKEN','SONAR_SCANNER_JSON_PARAMS','SONARQUBE_SCANNER_PARAMS')) {
    $saved[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
}
try {
    $env:SONAR_TOKEN = $secret
    $env:SONAR_SCANNER_JSON_PARAMS = '{"sonar.token":"previous-json-token"}'
    $env:SONARQUBE_SCANNER_PARAMS = '{"sonar.login":"previous-legacy-login"}'
    foreach ($scheme in @('Basic','Bearer')) {
        $captured = @(& $module { param($file,$auth) Invoke-SonarTool $file @($auth) -ScannerAuthScheme $auth } $launcher $scheme 6>&1)
        $output = $captured | Out-String
        Assert ($captured[-1].ExitCode -eq 7 -and $output.Contains('AUTH_OK=' + $scheme)) "Ambiente incorreto no processo $scheme."
        Assert (-not $output.Contains($secret)) 'Token exposto na saida do processo.'
        Assert (-not $output.Contains([Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($secret + ':')))) 'Basic exposto na saida.'
        Assert ($output.Contains('[REDACTED]')) 'Saida nao mascarada.'
        Assert ($env:SONAR_TOKEN -ceq $secret -and $env:SONAR_SCANNER_JSON_PARAMS -ceq '{"sonar.token":"previous-json-token"}' -and $env:SONARQUBE_SCANNER_PARAMS -ceq '{"sonar.login":"previous-legacy-login"}') 'Ambiente nao restaurado apos exit code de erro.'
    }
    try { & $module { param($file) Invoke-SonarTool $file @() -ScannerAuthScheme Basic } (Join-Path $area 'inexistente.exe') *>&1 | Out-Null }
    catch { } # O launcher pode devolver erro nativo ou excecao; ambos restauram o ambiente.
    Assert ($env:SONAR_TOKEN -ceq $secret -and $env:SONAR_SCANNER_JSON_PARAMS -ceq '{"sonar.token":"previous-json-token"}' -and $env:SONARQUBE_SCANNER_PARAMS -ceq '{"sonar.login":"previous-legacy-login"}') 'Falha de inicializacao nao restaurou ambiente.'
    $escapedSecret = 'synthetic-"-slash\-amp&-123456789'
    $json = ConvertTo-Json -InputObject @{ 'sonar.login'=$escapedSecret } -Compress
    $redacted = & $module { param($value,$credential) Protect-SonarText $value -Token $credential } $json $escapedSecret
    Assert ($redacted.Contains('[REDACTED]') -and -not $redacted.Contains('synthetic-')) 'Token JSON escapado nao mascarado.'
} finally {
    foreach ($name in $saved.Keys) { [Environment]::SetEnvironmentVariable($name, $saved[$name], 'Process') }
}
Write-Output 'PASS: launcher scanner Basic/Bearer, processo real, falhas, redacao e restauracao.'
