#requires -Version 5.1
[CmdletBinding()]
param([string]$ConfigPath, [string]$WorkspacePath, [string]$EditorPath, [switch]$NoOpen)
$ErrorActionPreference = 'Stop'
try {
    Import-Module (Join-Path $PSScriptRoot 'Harness.psm1') -Force -DisableNameChecking
    Import-Module (Join-Path $PSScriptRoot 'HarnessProjectIndex.psm1') -Force -DisableNameChecking
    $root = Split-Path -Parent $PSScriptRoot
    if (-not $ConfigPath) { $ConfigPath = Join-Path $root 'config/harness.local.json' }
    $context = Read-HarnessConfig $ConfigPath $root -WorkspacePath $WorkspacePath -SkipMigrationInitialization
    $result = New-HarnessProjectIndex $context -UpdateMigration
    Write-Host "Indice dos projetos: $($result.IndexPath)"
    if ($result.Warnings.Count) { Write-Warning 'Leitura parcial. Confira Limites da leitura no indice.' }
    Write-Host 'Indice corrente reconstruido por artifactId; escolhas humanas preservadas. Confira os avisos e links por projeto.'
    Write-Host 'Escolha Decisao=ANALISAR AGORA no registro e use Planejamento: planejar. Reconciliacao separada somente se houver conflito concreto ou troca de base desejada; o helper fornece o encaminhamento.'
    if (-not $NoOpen -and $EditorPath) {
        try { Open-HarnessEditor -EditorPath $EditorPath -FilePaths $result.IndexPath -Root $root }
        catch { Write-Warning ('Indice salvo; abra pelo caminho acima. ' + $_.Exception.Message) }
    }
    exit 0
} catch { Write-Host ('ERRO ao atualizar indice: ' + $_.Exception.Message) -ForegroundColor Red; exit 1 }
