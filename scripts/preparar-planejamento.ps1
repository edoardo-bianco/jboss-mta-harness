#requires -Version 5.1
[CmdletBinding()]
param(
    [string]$ConfigPath,[string]$WorkspacePath,[string]$Target,[switch]$SelectTarget,
    [string]$MigrationPath,[string]$ContextPath,[string]$EvidenceIndexPath,
    [ValidateSet('MTA','EVIDENCIAS')][string]$PlanningBasis,
    [ValidateSet('planejar-lotes','revisar-lote','manter-migracao')][string]$Operation='planejar-lotes',
    [switch]$SelectMigrationInput,[string]$EditorPath,[switch]$NoOpen,[switch]$NonInteractive,
    [ValidateSet('Text','Json')][string]$OutputFormat='Text'
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
try {
    if ($OutputFormat -eq 'Json' -and (-not $NonInteractive -or -not $NoOpen)) { throw 'Json exige NonInteractive e NoOpen.' }
    if ($NonInteractive -and ($SelectTarget -or $EditorPath)) { throw 'Preparo nao interativo exige escolhas explicitas, sem seletor/editor.' }
    if ($Operation -eq 'manter-migracao' -or $SelectMigrationInput) { throw 'A reconciliacao esta em adaptacao ao estado corrente (S13). Esta entrada prepara propostas; nao adota rodada nem registra reconciliacao.' }
    Import-Module (Join-Path $PSScriptRoot 'HarnessPlanning.psm1') -Force -DisableNameChecking
    Import-Module (Join-Path $PSScriptRoot 'Harness.psm1') -DisableNameChecking
    $root=Split-Path -Parent $PSScriptRoot
    if (-not $ConfigPath) { $ConfigPath=Join-Path $root 'config/harness.local.json' }
    $context=Read-HarnessConfig $ConfigPath $root -WorkspacePath $WorkspacePath -SkipMigrationInitialization
    $options=@{Context=$context;Target=$Target;MigrationPath=$MigrationPath;ContextPath=$ContextPath;EvidenceIndexPath=$EvidenceIndexPath;Interactive=(-not $NonInteractive)}
    if ($PlanningBasis) { $options.PlanningBasis=$PlanningBasis }
    $prepared=New-HarnessCurrentPlanning @options
    if ($OutputFormat -eq 'Json') {
        [pscustomobject]@{Status='PREPARED';Operation='planejar-lotes';Artifacts=$prepared;Diagnostics=$prepared.Diagnostics;ExitCode=0} | ConvertTo-Json -Depth 10
    } else {
        Write-Host "Projeto: $($prepared.Project) | Base: $($prepared.PlanningBasis)"
        if ($prepared.Reused) { Write-Host 'Contexto corrente retomado; documentos preservados.' }
        foreach ($diagnostic in $prepared.Diagnostics) { Write-Warning $diagnostic }
        Write-Host "Contexto: $($prepared.ContextPath)"
        Write-Host "Plano: $($prepared.PlanPath)"
        Write-Host "Tarefas: $($prepared.TodoPath)"
        Write-Host ('Codex: Execute o prompt deste arquivo: '+$prepared.PromptPath)
        Write-Host 'Copilot: abra o prompt e use Executar Prompt. Preparar nao executa o agente nem concede GO.'
        if (-not $NoOpen -and $EditorPath) {
            try { Open-HarnessEditor -EditorPath $EditorPath -FilePaths $prepared.PromptPath -Root $root }
            catch { Write-Warning ('Preparo salvo; abra o caminho acima. '+$_.Exception.Message) }
        }
    }
    exit 0
} catch {
    if ($OutputFormat -eq 'Json') { [pscustomobject]@{Status='FAILED';ExitCode=1;Error=$_.Exception.Message} | ConvertTo-Json }
    else { Write-Host ('ERRO ao preparar planejamento: '+$_.Exception.Message) -ForegroundColor Red }
    exit 1
}
