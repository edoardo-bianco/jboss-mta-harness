#requires -Version 5.1
$ErrorActionPreference='Stop'
# Prova de independencia: preparadores atuais funcionam sem Node/npm/npx no PATH.
$originalPath=$env:PATH
$originalConfig=$env:HARNESS_MCP_CONFIG
try {
    $env:PATH=(Join-Path $env:SystemRoot 'System32')+';'+$PSHOME
    $env:HARNESS_MCP_CONFIG=Join-Path $PSScriptRoot 'mcp-nao-instalado.json'
    if (Get-Command node,npm,npx -ErrorAction SilentlyContinue) { throw 'Fixture ainda encontra Node/npm/npx.' }
    foreach ($name in @('Test-PrioritizationCategories.ps1','Test-IssuePlanning.ps1')) {
        & (Join-Path $PSHOME 'powershell.exe') -NoProfile -File (Join-Path $PSScriptRoot $name)
        if ($LASTEXITCODE -ne 0) { throw ('Fluxo sem MCP falhou: '+$name) }
    }
    Write-Host 'PASS: priorizacao por categoria e planejamento por issue independentes de Node/MCP.'
} finally {
    $env:PATH=$originalPath
    $env:HARNESS_MCP_CONFIG=$originalConfig
}
