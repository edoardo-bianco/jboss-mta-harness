#requires -Version 5.1
[CmdletBinding()]
param(
    [string]$ConfigPath, [string]$WorkspacePath, [string]$Target, [switch]$SelectTarget,
    [string]$EditorPath, [switch]$NoOpen
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
try {
    Import-Module (Join-Path $PSScriptRoot 'Harness.psm1') -Force -DisableNameChecking
    Import-Module (Join-Path $PSScriptRoot 'HarnessPlanning.psm1') -Force -DisableNameChecking
    Import-Module (Join-Path $PSScriptRoot 'HarnessImplementation.psm1') -Force -DisableNameChecking
    $harnessRoot = Split-Path -Parent $PSScriptRoot
    if (-not $ConfigPath) { $ConfigPath = Join-Path $harnessRoot 'config/harness.local.json' }
    $context = Read-HarnessConfig $ConfigPath $harnessRoot -WorkspacePath $WorkspacePath -SkipMigrationInitialization
    $prepared = New-HarnessImplementationPrompt $context -Target $Target -Interactive:$SelectTarget
    $gitContext = [pscustomobject]@{Root=$context.Root;Active=[pscustomobject]@{name=$prepared.Project;label=$prepared.Project;path=$prepared.Source}}
    Write-Host "Projeto: $($prepared.Project)"
    Write-Host "Plano: $($prepared.PlanPath)"
    Write-Host "To-do: $($prepared.TodoPath)"
    Write-Host "Prompt preparado: $($prepared.PromptPath)"
    Write-Host "Revisao do resultado (apos corretiva): $($prepared.ResultReviewPromptPath)"
    foreach ($reason in $prepared.ReviewReasons) { Write-Host ('Revisao necessaria: '+$reason) }
    $null = Select-ImplementationBranch $gitContext $prepared
    Write-Host 'Confira o GO humano registrado no plano/to-do antes de executar o prompt no cliente escolhido.'
    Write-Host ('Codex: Execute o prompt deste arquivo: ' + $prepared.PromptPath)
    Write-Host 'Copilot: abra o arquivo e use Executar Prompt em nova conversa Local com devsquad.'
    Write-Host 'Preparar/abrir nao aciona o agente, nao concede GO e nao aplica corretivas. O agente confere o GO antes de editar.'
    Write-Host 'A escolha da branch e do desenvolvedor; preserve trabalho local. Aceite do resultado continua separado.'
    Write-Host 'O prompt referencia documentos correntes. Releia conteudo, escopo e alcance do GO antes de executar.'
    Write-Host ('Alternativa no chat do Copilot: /implementar-lote Leia o prompt preparado "' + $prepared.PromptPath + '" e implemente somente o lote com GO humano registrado, conforme seu contrato.')
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
