#requires -Version 5.1
[CmdletBinding()]
param(
    [string]$ConfigPath, [string]$WorkspacePath,
    [ValidateRange(5,10)][int]$Top = 5, [switch]$SelectTop,
    [string]$EditorPath, [switch]$NoOpen,
    [ValidateSet('Text','Json')][string]$OutputFormat = 'Text'
)
$ErrorActionPreference = 'Stop'
try {
    if ($SelectTop -and $PSBoundParameters.ContainsKey('Top')) { throw 'Use Top ou SelectTop, nao ambos.' }
    if ($OutputFormat -eq 'Json' -and ($SelectTop -or -not $NoOpen -or $EditorPath)) { throw 'Json exige NoOpen e escolhas explicitas, sem SelectTop/EditorPath.' }
    if ($SelectTop) {
        switch (Read-Host 'Quantidade de candidatas: 5 ou 10; Enter usa 5; q cancela') {
            '' { $Top = 5 }
            '5' { $Top = 5 }
            '10' { $Top = 10 }
            default { throw 'Priorizacao cancelada; nenhum contexto preparado.' }
        }
    }
    Import-Module (Join-Path $PSScriptRoot 'HarnessPrioritization.psm1') -Force -DisableNameChecking
    Import-Module (Join-Path $PSScriptRoot 'Harness.psm1') -Force -DisableNameChecking
    $root = Split-Path -Parent $PSScriptRoot
    if (-not $ConfigPath) { $ConfigPath = Join-Path $root 'config/harness.local.json' }
    $context = Read-HarnessConfig $ConfigPath $root -WorkspacePath $WorkspacePath -SkipMigrationInitialization
    $prepared = New-HarnessPrioritizationContext $context -Top $Top
    if ($OutputFormat -eq 'Json') {
        [pscustomobject]@{Status='PREPARED';RequestId=$prepared.RequestId;ContextPath=$prepared.ContextPath;PromptPath=$prepared.PromptPath;RankingPath=$prepared.RankingPath;Projects=$prepared.Projects} | ConvertTo-Json -Depth 12
    } else {
        Write-Host "Projetos: $($prepared.Projects.Count) | Top: $Top"
        foreach ($project in $prepared.Projects) {
            Write-Host "Projeto: $($project.Project) | Source: $($project.Source)"
            foreach ($diagnostic in $project.Diagnostics) { Write-Warning $diagnostic }
        }
        Write-Host "Prompt preparado: $($prepared.PromptPath)"
        Write-Host "Contexto: $($prepared.ContextPath)"
        Write-Host "Ranking a ser escrito pelo agente: $($prepared.RankingPath)"
        Write-Host 'Execute o prompt no chat do Copilot ou peca ao Codex para ler o arquivo preparado. Preparo nao executa o agente.'
        Write-Host 'Depois escolha projeto/IDs/recorte, registre ANALISAR AGORA e indique a lista no planejamento usual. Ranking nao concede GO.'
        if (-not $NoOpen -and $EditorPath) {
            try { Open-HarnessEditor -EditorPath $EditorPath -FilePaths $prepared.PromptPath -Root $root }
            catch { Write-Warning ('Contexto salvo; abra o prompt pelo caminho acima. ' + $_.Exception.Message) }
        }
    }
    exit 0
} catch {
    if ($OutputFormat -eq 'Json') { [pscustomobject]@{Status='FAILED';Error=$_.Exception.Message} | ConvertTo-Json }
    else { Write-Host ('ERRO ao preparar priorizacao: ' + $_.Exception.Message) -ForegroundColor Red }
    exit 1
}
