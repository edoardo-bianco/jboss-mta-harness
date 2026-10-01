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
    $harnessRoot = Split-Path -Parent $PSScriptRoot
    if (-not $ConfigPath) { $ConfigPath = Join-Path $harnessRoot 'config/harness.local.json' }
    $context = Read-HarnessConfig $ConfigPath $harnessRoot -WorkspacePath $WorkspacePath -Target $Target -SelectTarget:$SelectTarget
    if (-not $context.Active) { throw 'Escolha um projeto com -SelectTarget ou -Target.' }
    $register = Initialize-HarnessMigration $harnessRoot $context.Active
    $index = $register.EvidenceIndexPath
    Write-Host "Registro de migracao: $($register.MigrationPath)"
    Write-Host "Indice de evidencias: $index"
    Write-Host 'Liste arquivos e sua relacao com a correcao no indice. Use-os para manter o registro ou planejar, inclusive desde o primeiro lote.'
    Write-Host 'Registro e evidencias existentes foram preservados. Nenhum agente foi executado.'
    if (-not $NoOpen) {
        if (-not $EditorPath) { Write-Host 'Abra o indice acima no VS Code ou informe -EditorPath.' }
        else {
            try {
                Open-HarnessEditor -EditorPath $EditorPath -FilePaths $index -Root $harnessRoot
            } catch { Write-Warning ('Pasta criada; abra o indice pelo caminho acima. ' + $_.Exception.Message) }
        }
    }
    exit 0
} catch {
    Write-Host ('ERRO ao criar pasta de evidencias: ' + $_.Exception.Message) -ForegroundColor Red
    exit 1
}
