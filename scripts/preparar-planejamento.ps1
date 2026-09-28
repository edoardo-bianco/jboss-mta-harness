#requires -Version 5.1
[CmdletBinding()]
param(
    [string]$ConfigPath, [string]$WorkspacePath, [string]$Target, [switch]$SelectTarget,
    [string]$RunId, [string]$EditorPath, [switch]$NoOpen,
    [string]$PreviousRequestId, [switch]$NewPlan
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
try {
    if ($PreviousRequestId -and $NewPlan) { throw 'Use PreviousRequestId ou NewPlan, nao ambos.' }
    Import-Module (Join-Path $PSScriptRoot 'Harness.psm1') -Force -DisableNameChecking
    Import-Module (Join-Path $PSScriptRoot 'HarnessPlanning.psm1') -Force -DisableNameChecking
    $harnessRoot = Split-Path -Parent $PSScriptRoot
    if (-not $ConfigPath) { $ConfigPath = Join-Path $harnessRoot 'config/harness.local.json' }
    $context = Read-HarnessConfig $ConfigPath $harnessRoot -WorkspacePath $WorkspacePath -Target $Target -SelectTarget:$SelectTarget
    $selected = Select-MtaPlanningRun $context -RunId $RunId -Interactive:(-not $RunId)
    if (-not $PreviousRequestId -and -not $NewPlan) {
        $previous = Select-MtaPreviousPlanning $context
        if ($previous) { $PreviousRequestId = $previous.RequestId }
    }
    $prepared = New-MtaPlanningContext $context -RunId $selected.RunId -PreviousRequestId $PreviousRequestId
    Write-Host "Projeto: $($context.Active.label) | RunId: $($prepared.RunId)"
    Write-Host "Prompt preparado: $($prepared.PromptPath)"
    Write-Host "Plano de corretivas (a ser escrito pelo Copilot): $($prepared.PlanPath)"
    Write-Host "To-do de corretivas (a ser escrito pelo Copilot): $($prepared.TodoPath)"
    Write-Host "Recibo de contexto e hashes: $($prepared.ContextPath)"
    Write-Host 'Branch e commit foram registrados como referencia quando disponiveis. A escolha da branch e do desenvolvedor; nao ha cadastro ou bloqueio Git no harness.'
    if ($PreviousRequestId) { Write-Host "Planejamento anterior vinculado: $PreviousRequestId" }
    Write-Host 'Para continuar o mesmo planejamento, reabra este prompt; uma nova preparacao cria outra solicitacao.'
    Write-Host 'Confira o contexto e use Executar Prompt em uma nova conversa Copilot Local. Preparar o arquivo nao aciona o agente.'
    Write-Host ('Alternativa no chat: /planejar-lotes Leia o contexto selecionado ao final do arquivo "' + $prepared.PromptPath + '".')
    if (-not $NoOpen) {
        if (-not $EditorPath) { Write-Host 'Abra o arquivo acima no VS Code ou informe -EditorPath. O contexto ja esta salvo.' }
        else {
            try {
                $editor = Resolve-HarnessPath $EditorPath $harnessRoot
                if (-not (Test-Path -LiteralPath $editor -PathType Leaf)) { throw 'Executavel do editor nao encontrado.' }
                & $editor --reuse-window $prepared.PromptPath
            } catch { Write-Warning ('Contexto salvo; nao foi possivel abrir o editor: ' + $_.Exception.Message) }
        }
    }
    exit 0
} catch {
    Write-Host ('ERRO ao preparar planejamento: ' + $_.Exception.Message) -ForegroundColor Red
    exit 1
}
