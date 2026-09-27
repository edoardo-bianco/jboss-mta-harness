#requires -Version 5.1
[CmdletBinding()]
param([string]$ConfigPath, [switch]$AoAbrir, [string]$EditorPath, [string]$WorkspacePath, [string]$Target, [switch]$SelectTarget)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
try {
    Import-Module (Join-Path $PSScriptRoot 'Harness.psm1') -Force -DisableNameChecking
    $harnessRoot = Split-Path -Parent $PSScriptRoot
    if (-not $ConfigPath) { $ConfigPath = Join-Path $harnessRoot 'config/harness.local.json' }
    $context = Read-HarnessConfig $ConfigPath $harnessRoot -WorkspacePath $WorkspacePath -Target $Target -SelectTarget:$SelectTarget
    if ($AoAbrir -and -not $context.Active) {
        Write-Host 'Workspace sem alvo padrao disponivel. Execute MTA: conferir ambiente e escolha um projeto no terminal.'
        exit 0
    }
    $rules = Get-MtaRequirements $context
    Write-Host "OK: caminhos e arquivos obrigatorios encontrados. Projeto: $($context.Active.label)"
    Write-Host "Fonte: $($context.Active.path)"
    Write-Host "MTA: $($context.Config.tools.mtaExecutable)"
    Write-Host "Instalacao MTA (KANTRA_DIR): $(Split-Path -Parent $context.Config.tools.mtaExecutable)"
    Write-Host "JDK do MTA: $($context.Config.tools.mtaJdkHome)"
    Write-Host "Maven do MTA: $($context.Config.tools.mavenHome)"
    Write-Host "JDK da aplicacao: $($context.Config.tools.applicationJdk8Home)"
    Write-Host "Maven da aplicacao (build antes do MTA): $($context.Config.tools.applicationMavenHome)"
    Write-Host "Regras: $rules"
    Write-Host "Perfil: $($context.Config.mta.profile) | Origem: EAP 7.1 | Destino: EAP 7.4 | Java 8 / javax"
    Write-Host "Targets: $($context.Config.mta.targets -join ', ') | Modo: $($context.Config.mta.mode) | Regras padrao: desativadas | Filtro source: nenhum"
    Write-Host 'Esta conferencia valida os caminhos; a execucao MTA confirma o funcionamento.'
    Write-Host 'Proximo passo: Terminal > Run Task > Aplicacao: build Maven (Java 8); escolha clean install.'
    Write-Host 'Apos o build concluir com sucesso no mesmo projeto, execute MTA: executar analise.'
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
