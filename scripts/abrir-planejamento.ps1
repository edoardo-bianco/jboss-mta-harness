#requires -Version 5.1
[CmdletBinding()]
param(
    [string]$ConfigPath, [string]$WorkspacePath, [string]$Target, [switch]$SelectTarget,
    [string]$RequestId, [string]$EditorPath, [switch]$NoOpen
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
try {
    Import-Module (Join-Path $PSScriptRoot 'Harness.psm1') -Force -DisableNameChecking
    Import-Module (Join-Path $PSScriptRoot 'HarnessPlanning.psm1') -Force -DisableNameChecking
    $harnessRoot = Split-Path -Parent $PSScriptRoot
    if (-not $ConfigPath) { $ConfigPath = Join-Path $harnessRoot 'config/harness.local.json' }
    $context = Read-HarnessConfig $ConfigPath $harnessRoot -WorkspacePath $WorkspacePath -Target $Target -SelectTarget:$SelectTarget
    $selected = Select-MtaPreviousPlanning $context -ForOpen -RequestId $RequestId
    Write-Host 'Abrir documentos permite revisao; executar corretivas continua dependendo de GO humano. A gestao de branches e do desenvolvedor.'
    Write-Host "Projeto: $($context.Active.label) | Solicitacao: $($selected.RequestId)"
    Write-Host "Plano: $($selected.PlanPath)"
    Write-Host "To-do: $($selected.TodoPath)"
    if (-not $NoOpen) {
        if (-not $EditorPath) { Write-Host 'Abra os dois arquivos acima no VS Code ou informe -EditorPath.' }
        else {
            Open-HarnessEditor -EditorPath $EditorPath -FilePaths @($selected.PlanPath, $selected.TodoPath) -Root $harnessRoot
        }
    }
    exit 0
} catch {
    Write-Host ('ERRO ao abrir planejamento: ' + $_.Exception.Message) -ForegroundColor Red
    exit 1
}
