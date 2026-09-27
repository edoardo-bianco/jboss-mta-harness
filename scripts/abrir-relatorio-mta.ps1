#requires -Version 5.1
[CmdletBinding()]
param([string]$ConfigPath, [string]$WorkspacePath, [string]$Target, [switch]$SelectTarget)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
try {
    Import-Module (Join-Path $PSScriptRoot 'Harness.psm1') -Force -DisableNameChecking
    $harnessRoot = Split-Path -Parent $PSScriptRoot
    if (-not $ConfigPath) { $ConfigPath = Join-Path $harnessRoot 'config/harness.local.json' }
    $context = Read-HarnessConfig $ConfigPath $harnessRoot -WorkspacePath $WorkspacePath -Target $Target -SelectTarget:$SelectTarget
    $report = Get-LastMtaReport $context
    Write-Host "Relatorio do projeto $($context.Active.label): $report"
    Invoke-Item -LiteralPath $report
    exit 0
} catch {
    Write-Host ("ERRO ao abrir relatorio MTA: " + $_.Exception.Message) -ForegroundColor Red
    exit 1
}
