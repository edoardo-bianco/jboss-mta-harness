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
            $editor = Resolve-HarnessPath $EditorPath $harnessRoot
            if (-not (Test-Path -LiteralPath $editor -PathType Leaf)) { throw 'Executavel do editor nao encontrado.' }
            $global:LASTEXITCODE = 0
            & $editor --reuse-window $selected.PlanPath $selected.TodoPath
            if ($LASTEXITCODE -ne 0) { throw "Editor retornou codigo $LASTEXITCODE. Os caminhos estao acima." }
        }
    }
    exit 0
} catch {
    Write-Host ('ERRO ao abrir planejamento: ' + $_.Exception.Message) -ForegroundColor Red
    exit 1
}
