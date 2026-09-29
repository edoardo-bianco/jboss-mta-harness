#requires -Version 5.1
[CmdletBinding()]
param([string]$ConfigPath, [string]$WorkspacePath, [string]$Target, [switch]$SelectTarget,
    [string]$ProjectKey, [string]$BranchName, [ValidateSet('ANTES','DEPOIS')][string]$Phase)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$token=$null
try {
    Import-Module (Join-Path $PSScriptRoot 'Harness.psm1') -Force -DisableNameChecking
    Import-Module (Join-Path $PSScriptRoot 'HarnessSonar.psm1') -Force -DisableNameChecking
    $root=Split-Path -Parent $PSScriptRoot
    if (-not $ConfigPath) { $ConfigPath=Join-Path $root 'config/harness.local.json' }
    $context=Read-HarnessConfig $ConfigPath $root -WorkspacePath $WorkspacePath -Target $Target -SelectTarget:$SelectTarget
    $settings=Get-HarnessSonarSettings $context
    Write-Host "Projeto: $($context.Active.label) | Fonte: $($context.Active.path)"
    Write-Host "SonarQube: $($settings.ServerUrl)"
    Write-Host 'Execute antes o build/testes Java 8 do mesmo estado e gere o XML de cobertura. Esta tarefa envia as fontes ao servidor informado.'
    if (-not $ProjectKey) { $ProjectKey=Read-Host 'Chave do projeto existente no SonarQube (q cancela)' }
    if (-not $ProjectKey -or $ProjectKey -eq 'q') { throw 'Selecao cancelada.' }
    if (-not $PSBoundParameters.ContainsKey('BranchName')) { $BranchName=Read-Host 'Branch Sonar (Enter usa principal do servidor; requer edicao com suporte)' }
    if (-not $Phase) {
        $choice=Read-Host 'Estado da coleta: 1 ANTES da corretiva; 2 DEPOIS; q cancela'
        $Phase=switch ($choice) { '1' { 'ANTES' } '2' { 'DEPOIS' } default { throw 'Selecao cancelada.' } }
    }
    $token=Read-Host 'Token Sonar do usuario (entrada oculta, nao sera salvo)' -AsSecureString
    $result=Invoke-HarnessSonar $context -ProjectKey $ProjectKey -BranchName $BranchName -Phase $Phase -Token $token
    $result | ConvertTo-Json -Depth 6 | Write-Host
    Write-Host "Resumo: $(Join-Path (Split-Path $result.ResultPath) 'RESUMO.md')"
    if ($result.Status -eq 'SUCCEEDED') { exit 0 }
    if ($result.Status -eq 'QUALITY_GATE_FAILED') { exit 2 }
    exit 1
} catch {
    Write-Host ('ERRO ao analisar Sonar: ' + $_.Exception.Message) -ForegroundColor Red
    exit 1
} finally { if ($null -ne $token) { $token.Dispose() } }
