#requires -Version 5.1
[CmdletBinding()]
param([string]$ConfigPath,[string]$WorkspacePath,[string]$Target,[switch]$SelectTarget,[switch]$NoOpen)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
try {
    Import-Module (Join-Path $PSScriptRoot 'Harness.psm1') -Force -DisableNameChecking
    $root=Split-Path -Parent $PSScriptRoot
    if (-not $ConfigPath) { $ConfigPath=Join-Path $root 'config/harness.local.json' }
    $context=Read-HarnessConfig $ConfigPath $root -WorkspacePath $WorkspacePath -Target $Target -SelectTarget:$SelectTarget -SkipMigrationInitialization
    $report=Get-LastMtaReport $context
    Write-Host "MTA atual: $report"
    if (-not $NoOpen) { Invoke-Item -LiteralPath $report }
    exit 0
} catch { Write-Host ('ERRO ao abrir MTA: '+$_.Exception.Message) -ForegroundColor Red; exit 1 }
