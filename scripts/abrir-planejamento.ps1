#requires -Version 5.1
[CmdletBinding()]
param([string]$ConfigPath,[string]$WorkspacePath,[string]$Target,[switch]$SelectTarget,[string]$EditorPath,[switch]$NoOpen)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
try {
    Import-Module (Join-Path $PSScriptRoot 'Harness.psm1') -DisableNameChecking
    Import-Module (Join-Path $PSScriptRoot 'HarnessPlanning.psm1') -Force -DisableNameChecking
    $root=Split-Path -Parent $PSScriptRoot
    if (-not $ConfigPath) { $ConfigPath=Join-Path $root 'config/harness.local.json' }
    $context=Read-HarnessConfig $ConfigPath $root -WorkspacePath $WorkspacePath -SkipMigrationInitialization
    $selected=Get-HarnessCurrentPlanning $context -Target $Target -Interactive:$SelectTarget
    Write-Host "Projeto: $($selected.Project)"
    Write-Host "Plano: $($selected.PlanPath)"
    Write-Host "Tarefas: $($selected.TodoPath)"
    Write-Host 'Abrir documentos nao concede GO nem aceite.'
    if (-not $NoOpen -and $EditorPath) { Open-HarnessEditor -EditorPath $EditorPath -FilePaths @($selected.PlanPath,$selected.TodoPath) -Root $root }
    exit 0
} catch { Write-Host ('ERRO ao abrir planejamento: '+$_.Exception.Message) -ForegroundColor Red; exit 1 }
