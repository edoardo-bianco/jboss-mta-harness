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
    Import-Module (Join-Path $PSScriptRoot 'HarnessImplementation.psm1') -Force -DisableNameChecking
    $harnessRoot = Split-Path -Parent $PSScriptRoot
    if (-not $ConfigPath) { $ConfigPath = Join-Path $harnessRoot 'config/harness.local.json' }
    $context = Read-HarnessConfig $ConfigPath $harnessRoot -WorkspacePath $WorkspacePath -Target $Target -SelectTarget:$SelectTarget
    $selected = Select-MtaPreviousPlanning $context -ForImplementation -RequestId $RequestId
    $prepared = New-MtaImplementationPrompt $context -RequestId $selected.RequestId
    Write-Host "Projeto: $($context.Active.label) | Solicitacao: $($prepared.RequestId)"
    Write-Host "Plano: $($prepared.PlanPath)"
    Write-Host "To-do: $($prepared.TodoPath)"
    Write-Host "Prompt preparado: $($prepared.PromptPath)"
    $null = Select-ImplementationBranch $context $prepared
    Write-Host 'Confira o GO humano registrado no plano/to-do e use Executar Prompt em nova conversa Copilot Local com devsquad.'
    Write-Host 'Preparar/abrir nao aciona o agente, nao concede GO e nao aplica corretivas. O agente confere o GO antes de editar.'
    Write-Host 'A escolha da branch e do desenvolvedor; preserve trabalho local. Aceite do resultado continua separado.'
    Write-Host 'Se alterar plano/to-do antes de executar, prepare novamente. O prompt anterior fica preservado.'
    Write-Host ('Alternativa no chat: /implementar-lote Leia o prompt preparado "' + $prepared.PromptPath + '" e implemente somente o lote com GO humano registrado, conforme seu contrato.')
    if (-not $NoOpen) {
        if (-not $EditorPath) { Write-Host 'Abra o prompt acima no VS Code ou informe -EditorPath. O arquivo ja esta salvo.' }
        else {
            try {
                Open-HarnessEditor -EditorPath $EditorPath -FilePaths $prepared.PromptPath -Root $harnessRoot
            } catch { Write-Warning ('Prompt salvo; nao foi possivel abrir o editor: ' + $_.Exception.Message) }
        }
    }
    exit 0
} catch {
    Write-Host ('ERRO ao preparar implementacao: ' + $_.Exception.Message) -ForegroundColor Red
    exit 1
}
