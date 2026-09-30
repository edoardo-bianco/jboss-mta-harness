#requires -Version 5.1
[CmdletBinding()]
param(
    [string]$ConfigPath, [string]$WorkspacePath, [string]$Target, [switch]$SelectTarget,
    [string]$RunId, [string]$RunPath, [string]$EditorPath, [switch]$NoOpen,
    [string]$PreviousRequestId, [switch]$NewPlan,
    [ValidateSet('planejar-lotes','revisar-lote')][string]$Operation = 'planejar-lotes',
    [switch]$SelectOperation, [string]$EvidenceIndexPath
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
try {
    if ($PreviousRequestId -and $NewPlan) { throw 'Use PreviousRequestId ou NewPlan, nao ambos.' }
    if ($RunId -and $RunPath) { throw 'Use RunId do historico ou RunPath da pasta recebida, nao ambos.' }
    if ($SelectOperation -and $PSBoundParameters.ContainsKey('Operation')) { throw 'Use Operation ou SelectOperation, nao ambos.' }
    Import-Module (Join-Path $PSScriptRoot 'Harness.psm1') -Force -DisableNameChecking
    Import-Module (Join-Path $PSScriptRoot 'HarnessPlanning.psm1') -Force -DisableNameChecking
    $harnessRoot = Split-Path -Parent $PSScriptRoot
    if (-not $ConfigPath) { $ConfigPath = Join-Path $harnessRoot 'config/harness.local.json' }
    $context = Read-HarnessConfig $ConfigPath $harnessRoot -WorkspacePath $WorkspacePath -Target $Target -SelectTarget:$SelectTarget
    if ($SelectOperation) {
        Write-Host '1. Planejar lote (/planejar-lotes): proposta inicial ou continuidade do planejamento.'
        Write-Host '2. Revisar lote (/revisar-lote): exige plano/to-do anteriores e LEIA-ME das evidencias.'
        switch (Read-Host 'Numero da operacao; q cancela') {
            '1' { $Operation = 'planejar-lotes' }
            '2' { $Operation = 'revisar-lote' }
            default { throw 'Selecao de operacao cancelada ou invalida; nenhum contexto preparado.' }
        }
    }
    $review = $Operation -eq 'revisar-lote'
    if ($review -and $NewPlan) { throw 'Revisar lote exige planejamento anterior; nao use NewPlan.' }
    if (-not $review -and $EvidenceIndexPath) { throw 'EvidenceIndexPath exige a operacao revisar-lote.' }
    if ($RunPath) { $selected = Get-MtaPlanningRunFromPath -RunPath $RunPath -Root $harnessRoot }
    else { $selected = Select-MtaPlanningRun $context -RunId $RunId -Interactive:(-not $RunId) }
    if ($selected.PSObject.Properties['ExternalInput'] -and $selected.ExternalInput) { $RunPath = $selected.Run }
    if (-not $PreviousRequestId -and -not $NewPlan) {
        $previous = Select-MtaPreviousPlanning $context -Required:$review
        if ($previous) { $PreviousRequestId = $previous.RequestId }
    }
    if ($review -and -not $EvidenceIndexPath) {
        $EvidenceIndexPath = Read-Host 'Caminho do LEIA-ME.md preenchido das evidencias; q cancela'
        if ([string]::IsNullOrWhiteSpace($EvidenceIndexPath) -or $EvidenceIndexPath -eq 'q') { throw 'Selecao de evidencias cancelada; nenhum contexto preparado.' }
        $EvidenceIndexPath = $EvidenceIndexPath.Trim().Trim('"')
    }
    $prepared = New-MtaPlanningContext $context -RunId $selected.RunId -RunPath $RunPath -PreviousRequestId $PreviousRequestId -Operation $Operation -EvidenceIndexPath $EvidenceIndexPath
    $promptToOpen = if ($review) { $prepared.ReviewPromptPath } else { $prepared.PromptPath }
    Write-Host "Projeto: $($context.Active.label) | RunId: $($prepared.RunId)"
    Write-Host "Operacao: $Operation"
    Write-Host "Prompt preparado: $promptToOpen"
    Write-Host "Plano de corretivas (a ser escrito pelo Copilot): $($prepared.PlanPath)"
    Write-Host "To-do de corretivas (a ser escrito pelo Copilot): $($prepared.TodoPath)"
    Write-Host "Recibo de contexto e hashes: $($prepared.ContextPath)"
    Write-Host "Base MTA: $($selected.Run) | Fontes locais para conferir: $($context.Active.path)"
    Write-Host 'Planejamento parte do snapshot MTA e confere pontos do codigo local; diferencas de POM/codigo geram alertas, nao bloqueiam a proposta.'
    if ($PreviousRequestId) { Write-Host "Planejamento anterior vinculado: $PreviousRequestId" }
    Write-Host 'Para continuar o mesmo planejamento, reabra este prompt; uma nova preparacao cria outra solicitacao.'
    Write-Host 'Confira o contexto e use Executar Prompt em uma nova conversa Copilot Local. Preparar o arquivo nao aciona o agente.'
    if ($review) {
        Write-Host "Contexto-base da revisao: $($prepared.PromptPath)"
        Write-Host "Indice de evidencias: $($prepared.EvidenceIndexPath)"
        Write-Host 'Execute somente revisar-lote. Preserve os documentos anteriores vinculados; revisao nao concede GO.'
        Write-Host ('Alternativa no chat: /revisar-lote Use o contexto do arquivo "' + $prepared.PromptPath + '" e as evidencias listadas em "' + $prepared.EvidenceIndexPath + '". Revise o mesmo lote considerando as observacoes de Previous e do indice. Nao aplique corretivas nem conceda GO.')
    } else {
        Write-Host ('Alternativa no chat: /planejar-lotes Leia o contexto selecionado ao final do arquivo "' + $prepared.PromptPath + '".')
    }
    if (-not $NoOpen) {
        if (-not $EditorPath) { Write-Host 'Abra o arquivo acima no VS Code ou informe -EditorPath. O contexto ja esta salvo.' }
        else {
            try {
                $editor = Resolve-HarnessPath $EditorPath $harnessRoot
                if (-not (Test-Path -LiteralPath $editor -PathType Leaf)) { throw 'Executavel do editor nao encontrado.' }
                & $editor --reuse-window $promptToOpen
            } catch { Write-Warning ('Contexto salvo; nao foi possivel abrir o editor: ' + $_.Exception.Message) }
        }
    }
    exit 0
} catch {
    Write-Host ('ERRO ao preparar planejamento: ' + $_.Exception.Message) -ForegroundColor Red
    exit 1
}
