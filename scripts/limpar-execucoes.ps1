#requires -Version 5.1
[CmdletBinding()]
param([string]$ConfigPath, [string]$WorkspacePath, [string]$Target, [switch]$All, [switch]$TemporaryBackups, [switch]$Preview)
$ErrorActionPreference = 'Stop'
try {
    Import-Module (Join-Path $PSScriptRoot 'HarnessCleanup.psm1') -Force -DisableNameChecking
    Import-Module (Join-Path $PSScriptRoot 'Harness.psm1') -DisableNameChecking
    $root = Split-Path -Parent $PSScriptRoot
    if (([int][bool]$All + [int][bool]$Target + [int][bool]$TemporaryBackups) -gt 1) { throw 'Escolha somente All, Target ou TemporaryBackups.' }
    if (-not $All -and -not $Target -and -not $TemporaryBackups) {
        Write-Host '1. Limpar execucoes de um projeto'
        Write-Host '2. Limpar execucoes de todos os projetos'
        Write-Host '3. Limpar somente backups temporarios de exercicios/ajustes'
        $choice = Read-Host 'Numero da opcao (q cancela)'
        if ($choice -eq '2') { $All = $true }
        elseif ($choice -eq '3') { $TemporaryBackups = $true }
        elseif ($choice -ne '1') { Write-Host 'Limpeza cancelada.'; exit 0 }
    }
    $source = $null
    if (-not $All -and -not $TemporaryBackups) {
        if (-not $ConfigPath) { $ConfigPath = Join-Path $root 'config/harness.local.json' }
        $context = Read-HarnessConfig $ConfigPath $root -WorkspacePath $WorkspacePath -Target $Target -SelectTarget:(-not $Target)
        $source = $context.Active.path
        Write-Host "Projeto: $($context.Active.label) | Fonte: $source"
    }
    if ($Preview) { Get-HarnessCleanupPaths $root -Source $source -All:$All -TemporaryBackups:$TemporaryBackups }
    else { Invoke-HarnessCleanup $root -Source $source -All:$All -TemporaryBackups:$TemporaryBackups }
    exit 0
} catch { Write-Host ('ERRO na limpeza: ' + $_.Exception.Message) -ForegroundColor Red; exit 1 }
