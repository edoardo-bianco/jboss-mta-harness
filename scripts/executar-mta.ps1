#requires -Version 5.1
[CmdletBinding()]
param([string]$ConfigPath)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
try {
    Import-Module (Join-Path $PSScriptRoot 'Harness.psm1') -Force -DisableNameChecking
    $harnessRoot = Split-Path -Parent $PSScriptRoot
    if (-not $ConfigPath) { $ConfigPath = Join-Path $harnessRoot 'config/harness.local.json' }
    $context = Read-HarnessConfig $ConfigPath $harnessRoot
    $result = Invoke-MtaAnalysis $context
    $result | ConvertTo-Json -Depth 5 | Write-Host
    if ($result.Status -ne 'SUCCEEDED') { exit 2 }
    exit 0
} catch {
    Write-Host ("ERRO ao executar MTA: " + $_.Exception.Message) -ForegroundColor Red
    Write-Host 'Para revisar os caminhos: Terminal > Run Task > Workspace: configurar caminhos.'
    exit 1
}
