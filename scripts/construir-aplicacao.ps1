#requires -Version 5.1
[CmdletBinding()]
param([string]$ConfigPath, [string]$Goals = 'clean verify', [string]$WorkspacePath, [string]$Target, [switch]$SelectTarget)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
try {
    Import-Module (Join-Path $PSScriptRoot 'Harness.psm1') -Force -DisableNameChecking
    Import-Module (Join-Path $PSScriptRoot 'HarnessBuild.psm1') -Force -DisableNameChecking
    $harnessRoot = Split-Path -Parent $PSScriptRoot
    if (-not $ConfigPath) { $ConfigPath = Join-Path $harnessRoot 'config/harness.local.json' }
    $context = Read-HarnessConfig $ConfigPath $harnessRoot -WorkspacePath $WorkspacePath -Target $Target -SelectTarget:$SelectTarget
    $result = Invoke-ApplicationBuild $context $Goals
    $result | ConvertTo-Json -Depth 5 | Write-Host
    if ($result.Status -ne 'SUCCEEDED') {
        if ($null -ne $result.ExitCode -and $result.ExitCode -ne 0) { exit $result.ExitCode }
        exit 1
    }
    exit 0
} catch {
    Write-Host ("ERRO ao construir aplicacao: " + $_.Exception.Message) -ForegroundColor Red
    exit 1
}
