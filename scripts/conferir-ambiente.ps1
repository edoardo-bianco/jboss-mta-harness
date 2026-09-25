#requires -Version 5.1
[CmdletBinding()]
param([string]$ConfigPath, [switch]$AoAbrir, [string]$EditorPath)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
try {
    Import-Module (Join-Path $PSScriptRoot 'Harness.psm1') -Force -DisableNameChecking
    $harnessRoot = Split-Path -Parent $PSScriptRoot
    if (-not $ConfigPath) { $ConfigPath = Join-Path $harnessRoot 'config/harness.local.json' }
    $context = Read-HarnessConfig $ConfigPath $harnessRoot
    $rules = Get-MtaRequirements $context
    Write-Host "OK: caminhos e arquivos obrigatorios encontrados. Projeto: $($context.Active.name)"
    Write-Host "Fonte: $($context.Active.path)"
    Write-Host "MTA: $($context.Config.tools.mtaExecutable)"
    Write-Host "JDK do MTA: $($context.Config.tools.mtaJdkHome)"
    Write-Host "Maven: $($context.Config.tools.mavenHome)"
    Write-Host "Regras: $rules"
    Write-Host "Targets: $($context.Config.mta.targets -join ', ') | Modo: $($context.Config.mta.mode) | Regras padrao: desativadas | Filtro source: nenhum"
    Write-Host 'Esta conferencia valida os caminhos; a execucao MTA confirma o funcionamento.'
    Write-Host 'Para executar: Terminal > Run Task > MTA: executar analise.'
    exit 0
} catch {
    Write-Host ("Configuracao incompleta: " + $_.Exception.Message)
    if ($AoAbrir) {
        & (Join-Path $PSScriptRoot 'configurar-caminhos.ps1') -ConfigPath $ConfigPath -EditorPath $EditorPath
        exit $LASTEXITCODE
    }
    Write-Host 'Para revisar os caminhos: Terminal > Run Task > Workspace: configurar caminhos.'
    exit 1
}
