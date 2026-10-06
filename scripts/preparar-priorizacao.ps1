#requires -Version 5.1
[CmdletBinding()]
param(
    [string]$ConfigPath, [string]$WorkspacePath,
    [string]$Percentage, [string]$Category, [switch]$Interactive,
    [ValidateSet('Recreate','Continue')][string]$Mode, [string]$PreviousRequestId,
    [string]$EditorPath, [switch]$NoOpen,
    [ValidateSet('Text','Json')][string]$OutputFormat = 'Text'
)
$ErrorActionPreference = 'Stop'
try {
    if ($OutputFormat -eq 'Json' -and ($Interactive -or -not $NoOpen -or $EditorPath)) { throw 'Json exige NoOpen e escolhas explicitas, sem Interactive/EditorPath.' }
    Import-Module (Join-Path $PSScriptRoot 'HarnessPrioritization.psm1') -Force -DisableNameChecking
    Import-Module (Join-Path $PSScriptRoot 'Harness.psm1') -Force -DisableNameChecking
    $root = Split-Path -Parent $PSScriptRoot
    if (-not $ConfigPath) { $ConfigPath = Join-Path $root 'config/harness.local.json' }
    $context = Read-HarnessConfig $ConfigPath $root -WorkspacePath $WorkspacePath -SkipMigrationInitialization
    $options = @{Percentage=$Percentage;PreviousRequestId=$PreviousRequestId;Interactive=$Interactive}
    if ($Mode) { $options.Mode = $Mode }
    if ($Category) { $options.Category = $Category }
    $prepared = New-HarnessPrioritizationContext $context @options
    if ($OutputFormat -eq 'Json') {
        $prepared | ConvertTo-Json -Depth 12
    } else {
        if ($prepared.Status -eq 'EXHAUSTED') { Write-Host 'Nao restam novas issues elegiveis nesta sequencia. Nenhuma solicitacao criada.'; exit 0 }
        if ($prepared.Reused) { Write-Host 'Retomando a fatia ainda sem resultado; percentual e quota originais preservados.' }
        Write-Host "Categoria: $($prepared.Category) | Projetos: $($prepared.Projects.Count) | Percentual: $($prepared.Percentage)% | Base inicial: $($prepared.InitialTotal) | Fatia: $($prepared.SliceSize)"
        foreach ($project in $prepared.Projects) {
            Write-Host "Projeto: $($project.Label) | ID: $($project.Project) | Source: $($project.Source)"
            foreach ($diagnostic in $project.Diagnostics) { Write-Warning ("$($project.Label): " + $diagnostic) }
        }
        Write-Host "Prompt preparado: $($prepared.PromptPath)"
        Write-Host "Contexto: $($prepared.ContextPath)"
        Write-Host "Ranking a ser escrito pelo agente: $($prepared.RankingPath)"
        Write-Host ('Codex: Execute o prompt deste arquivo: ' + $prepared.PromptPath)
        Write-Host 'Copilot: abra o arquivo e use Executar Prompt. Preparo nao executa o agente.'
        Write-Host 'Depois escolha projeto/IDs/recorte no registro e use Planejamento: planejar. Ranking nao concede GO.'
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
