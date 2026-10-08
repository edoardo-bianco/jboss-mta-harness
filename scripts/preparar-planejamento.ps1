#requires -Version 5.1
[CmdletBinding()]
param(
    [string]$ConfigPath, [string]$WorkspacePath, [string]$Target, [switch]$SelectTarget,
    [string]$RunId, [string]$RunPath, [string]$EditorPath, [switch]$NoOpen,
    [string]$PreviousRequestId, [switch]$NewPlan,
    [string]$MigrationPath, [string]$ContextPath, [string]$RequestId,
    [ValidateSet('planejar-lotes','revisar-lote','manter-migracao')][string]$Operation = 'planejar-lotes',
    [switch]$SelectOperation, [switch]$SelectMigrationInput, [string]$EvidenceIndexPath, [string]$MigrationSourcePath, [switch]$WithoutMta,
    [switch]$NonInteractive, [ValidateSet('Text','Json')][string]$OutputFormat = 'Text'
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if ($NonInteractive -or $OutputFormat -eq 'Json') {
    Import-Module (Join-Path $PSScriptRoot 'HarnessPlanning.psm1') -Force -DisableNameChecking
    $response = Invoke-MtaPlanningPreparation -Root (Split-Path -Parent $PSScriptRoot) -Choices $PSBoundParameters
    if ($OutputFormat -eq 'Json') { $response | ConvertTo-Json -Depth 8 }
    else {
        Write-Host ("{0}: {1}" -f $response.Status, $response.Operation)
        foreach ($diagnostic in $response.Diagnostics) { Write-Warning $diagnostic }
        if ($response.Error) { Write-Host $response.Error.Message }
        if ($response.Artifacts.ContextPath) { Write-Host "Recibo: $($response.Artifacts.ContextPath)" }
        foreach ($file in $response.ChangedFiles) { Write-Host ("{0}: {1}" -f $file.Change, $file.Path) }
    }
    exit $response.ExitCode
}
try {
    if ($PreviousRequestId -and $NewPlan) { throw 'Use PreviousRequestId ou NewPlan, nao ambos.' }
    if ($RunId -and $RunPath) { throw 'Use RunId do historico ou RunPath da pasta recebida, nao ambos.' }
    if ($SelectOperation -and $PSBoundParameters.ContainsKey('Operation')) { throw 'Use Operation ou SelectOperation, nao ambos.' }
    if ($SelectMigrationInput -and ($Operation -ne 'manter-migracao' -or $SelectOperation -or $RunId -or $RunPath -or $WithoutMta -or $MigrationSourcePath -or $MigrationPath -or $ContextPath -or $RequestId -or $PreviousRequestId -or $NewPlan)) {
        throw 'SelectMigrationInput pertence a manter-migracao e seleciona a nova rodada; nao combine com outras entradas/operacoes.'
    }
    Import-Module (Join-Path $PSScriptRoot 'Harness.psm1') -Force -DisableNameChecking
    Import-Module (Join-Path $PSScriptRoot 'HarnessPlanning.psm1') -Force -DisableNameChecking
    $harnessRoot = Split-Path -Parent $PSScriptRoot
    if (-not $ConfigPath) { $ConfigPath = Join-Path $harnessRoot 'config/harness.local.json' }
    $registered = $Operation -eq 'planejar-lotes' -and ($MigrationPath -or $ContextPath -or $RequestId -or (-not $RunId -and -not $RunPath -and -not $SelectTarget -and -not $SelectOperation))
    $context = Read-HarnessConfig $ConfigPath $harnessRoot -WorkspacePath $WorkspacePath -Target $Target -SelectTarget:$SelectTarget -SkipMigrationInitialization:($registered -or $SelectMigrationInput)
    if ($SelectMigrationInput) {
        $currentRegister = Read-HarnessMigrationInput $harnessRoot $context.Active
        $registerHash = (Get-FileHash -LiteralPath $currentRegister.MigrationPath -Algorithm SHA256).Hash
        Write-Host 'Escolha o novo MTA para adotar no registro. A selecao so sera gravada depois da confirmacao.'
        $selected = Select-MtaPlanningRun $context -Interactive
        $RunPath = $selected.Run
        if (-not (Test-Path -LiteralPath (Join-Path $RunPath 'input') -PathType Container)) { throw 'Snapshot input ausente; informe a pasta completa da rodada MTA.' }
        New-MtaMigrationPrompt $context -RunPath $RunPath -EvidenceIndexPath $EvidenceIndexPath -ValidateOnly
        $manifestPath = Join-Path $RunPath 'manifest.json'
        $resultPath = Join-Path $RunPath 'result.json'
        $manifestHash = (Get-FileHash -LiteralPath $manifestPath -Algorithm SHA256).Hash
        $resultHash = (Get-FileHash -LiteralPath $resultPath -Algorithm SHA256).Hash
        $manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
        $catalogPath = Join-Path $RunPath 'output/static-report/output.js'
        $catalogHash = (Get-FileHash -LiteralPath $catalogPath -Algorithm SHA256).Hash
        Write-Host "Registro a atualizar: $($currentRegister.MigrationPath)"
        Write-Host "Projeto local: $($context.Active.label) | Source: $($context.Active.path)"
        if ($currentRegister.Origin) {
            Write-Host "Origem atual: $($currentRegister.Origin.RunId) | $($currentRegister.Origin.Run)"
            Write-Host "Projeto/origem atual: $($currentRegister.Origin.Project) | $($currentRegister.Origin.Source)"
        } else { Write-Host 'Origem atual: registro sem rodada MTA vinculada.' }
        Write-Host "Nova origem: $($manifest.RunId) | $RunPath"
        Write-Host "Projeto/origem da analise: $($manifest.Project) | $($manifest.Source)"
        Write-Host 'A origem pode ser de outra maquina. Confirme a associacao ao Source local e confira seu codigo ao comparar.'
        Write-Host 'Decisoes, andamento e referencias serao preservados; ausencias nao comprovam resolucao. O prompt fara a comparacao das evidencias.'
        if ((Read-Host 'Digite ADOTAR para atualizar este registro; Enter ou q cancela') -cne 'ADOTAR') { throw 'Selecao cancelada; registro e contextos preservados.' }
        if ((Get-FileHash -LiteralPath $currentRegister.MigrationPath -Algorithm SHA256).Hash -cne $registerHash -or
            (Get-FileHash -LiteralPath $catalogPath -Algorithm SHA256).Hash -cne $catalogHash -or
            (Get-FileHash -LiteralPath $manifestPath -Algorithm SHA256).Hash -cne $manifestHash -or
            (Get-FileHash -LiteralPath $resultPath -Algorithm SHA256).Hash -cne $resultHash) {
            throw 'Registro ou entrada MTA mudou durante a confirmacao; confira novamente pela tarefa.'
        }
    }
    if ($registered) {
        if ($WithoutMta -or $MigrationSourcePath -or $RunId -or $RunPath) { throw 'Planejar pelo registro usa sua base atual. Para trocar MTA, use manter-migracao explicitamente.' }
        $prepared = Invoke-HarnessRegisteredPlanning $context -MigrationPath $MigrationPath -ContextPath $ContextPath -RequestId $RequestId -Target $Target -EvidenceIndexPath $EvidenceIndexPath -PreviousRequestId $PreviousRequestId -NewPlan:$NewPlan -Interactive
        $promptToOpen=$prepared.PromptPath
        Write-Host "Projeto: $($context.Active.label) | Fonte: $($context.Active.path)"
        Write-Host "Registro: $((Get-HarnessMigrationPaths $harnessRoot $context.Active).MigrationPath)"
        Write-Host "Prompt preparado: $promptToOpen"
        Write-Host "Plano: $($prepared.PlanPath)"
        Write-Host "To-do: $($prepared.TodoPath)"
        Write-Host "Contexto: $($prepared.ContextPath)"
        Write-Host 'O prompt cria ou atualiza a proposta; se faltar decisao essencial, o agente pergunta antes de concluir. Preparar nao executa o agente.'
        Write-Host ('Codex: Execute o prompt deste arquivo: ' + $promptToOpen)
        Write-Host 'Copilot: abra o arquivo acima e use Executar Prompt (nova conversa no Chat/Copilot).'
        if (-not $NoOpen -and $EditorPath) {
            try { Open-HarnessEditor -EditorPath $EditorPath -FilePaths $promptToOpen -Root $harnessRoot }
            catch { Write-Warning ('Contexto salvo; abra pelo caminho acima. ' + $_.Exception.Message) }
        }
        exit 0
    }
    if ($SelectOperation) {
        Write-Host '1. Planejar ou atualizar lote (/planejar-lotes): fluxo usual; atualiza o registro e prepara o planejamento.'
        Write-Host '2. Atualizar somente migracao.md (/manter-migracao): sem planejar lote; ajuda do Copilot opcional.'
        switch (Read-Host 'Numero da operacao; q cancela') {
            '1' { $Operation = 'planejar-lotes' }
            '2' { $Operation = 'manter-migracao' }
            default { throw 'Selecao de operacao cancelada ou invalida; nenhum contexto preparado.' }
        }
    }
    $review = $Operation -eq 'revisar-lote'
    if ($review -and $NewPlan) { throw 'Revisar lote exige planejamento anterior; nao use NewPlan.' }
    if ($Operation -ne 'manter-migracao' -and ($WithoutMta -or $MigrationSourcePath)) { throw 'WithoutMta e MigrationSourcePath pertencem a manter-migracao.' }
    if ($Operation -eq 'manter-migracao') {
        if ($PreviousRequestId -or $NewPlan) { throw 'Manter registro nao seleciona planejamento anterior.' }
        if ($WithoutMta -and ($RunId -or $RunPath)) { throw 'WithoutMta nao aceita rodada nova.' }
        if (-not $WithoutMta -and -not $RunId -and -not $RunPath) {
            switch (Read-Host '1: selecionar MTA; 2: somente registro/evidencias existentes; q cancela') {
                '1' { }
                '2' { $WithoutMta = $true }
                default { throw 'Selecao cancelada; nenhum prompt preparado.' }
            }
        }
        if (-not $WithoutMta -and -not $RunPath) {
            $selected = Select-MtaPlanningRun $context -RunId $RunId -Interactive:(-not $RunId)
            $RunPath = $selected.Run
            $RunId = $null
        }
        $prepared = New-MtaMigrationPrompt $context -RunId $RunId -RunPath $RunPath -EvidenceIndexPath $EvidenceIndexPath -MigrationSourcePath $MigrationSourcePath
        $promptToOpen = $prepared.PromptPath
        Write-Host "Registro de migracao: $($prepared.MigrationPath)"
        Write-Host "Prompt preparado: $promptToOpen"
        Write-Host "Recibo de contexto: $($prepared.ContextPath)"
        Write-Host 'Se selecionou MTA, o catalogo ja foi atualizado no migracao.md; sem rodada nova, a referencia existente foi preservada.'
        Write-Host 'Manutencao solicitada: execute o prompt para conferir decisoes/evidencias. A carga MTA nao conclui reconciliacao; ele nao gera plan.md/todo.md.'
        Write-Host ('Codex: em nova conversa com o agente principal (fora do helper), envie: Execute o prompt deste arquivo: ' + $promptToOpen)
        Write-Host 'Copilot: abra o arquivo e use Executar Prompt. Depois da conferencia, volte a Planejamento: planejar para produzir ou atualizar a proposta.'
    } else {
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
        Write-Host "Registro de migracao: $((Initialize-HarnessMigration $harnessRoot $context.Active).MigrationPath)"
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
        }
    if (-not $NoOpen) {
        if (-not $EditorPath) { Write-Host 'Abra o arquivo acima no VS Code ou informe -EditorPath. O contexto ja esta salvo.' }
        else {
            try {
                Open-HarnessEditor -EditorPath $EditorPath -FilePaths $promptToOpen -Root $harnessRoot
            } catch { Write-Warning ('Contexto salvo; nao foi possivel abrir o editor: ' + $_.Exception.Message) }
        }
    }
    exit 0
} catch {
    Write-Host ('ERRO ao preparar planejamento: ' + $_.Exception.Message) -ForegroundColor Red
    exit 1
}
