#requires -Version 5.1
[CmdletBinding()]
param([string]$ConfigPath, [string]$WorkspacePath, [string]$Target, [switch]$SelectTarget,
    [string]$ProjectKey, [string]$BranchName, [ValidateSet('ANTES','DEPOIS')][string]$Phase, [string]$BaselineResultPath,
    [switch]$PrepareCertificate, [ValidateSet('Scan','Review')][string]$Action, [string]$ResultPath)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$token=$null
try {
    Import-Module (Join-Path $PSScriptRoot 'Harness.psm1') -Force -DisableNameChecking
    Import-Module (Join-Path $PSScriptRoot 'HarnessSonar.psm1') -Force -DisableNameChecking
    Import-Module (Join-Path $PSScriptRoot 'HarnessSonarCertificate.psm1') -Force -DisableNameChecking
    $root=Split-Path -Parent $PSScriptRoot
    Import-Module (Join-Path $PSScriptRoot 'HarnessSonarReview.psm1') -Force -DisableNameChecking
    if (-not $Action) {
        if ($ResultPath) { $Action='Review' }
        elseif ($ProjectKey -or $Phase -or $PrepareCertificate) { $Action='Scan' }
        else {
            $operation=Read-Host 'Sonar: 1 Nova coleta; 2 Rever evidencias/decisao de coleta existente; q cancela'
            $Action=switch ($operation) { '1' { 'Scan' } '2' { 'Review' } default { throw 'Selecao cancelada.' } }
        }
    }
    if ($Action -eq 'Review') {
        if (-not $ResultPath) { $ResultPath=Read-Host 'Caminho do result.json da coleta que deseja rever' }
        $null=Show-HarnessSonarReview $root $ResultPath
        exit 0 # Sucesso da revisao local; nao e aprovacao tecnica da analise.
    }
    if ($ResultPath) { throw 'ResultPath somente pode ser usado com Action Review.' }
    if (-not $ConfigPath) { $ConfigPath=Join-Path $root 'config/harness.local.json' }
    $context=Read-HarnessConfig $ConfigPath $root -WorkspacePath $WorkspacePath -Target $Target -SelectTarget:$SelectTarget
    $settings=Get-HarnessSonarSettings $context
    Write-Host "Projeto: $($context.Active.label) | Fonte: $($context.Active.path)"
    Write-Host "SonarQube: $($settings.ServerUrl)"
    Initialize-HarnessSonarCertificate -ServerUrl $settings.ServerUrl -ScannerJdkHome $settings.Jdk -PrepareCertificate:$PrepareCertificate
    Write-Host 'Execute antes o build/testes Java 8 do mesmo estado e gere o XML de cobertura. Esta tarefa envia as fontes ao servidor informado.'
    if (-not $ProjectKey) { $ProjectKey=Read-Host 'Chave do projeto existente no SonarQube (q cancela)' }
    if (-not $ProjectKey -or $ProjectKey -eq 'q') { throw 'Selecao cancelada.' }
    if (-not $PSBoundParameters.ContainsKey('BranchName')) { $BranchName=Read-Host 'Branch Sonar (Enter usa principal do servidor; requer edicao com suporte)' }
    if (-not $Phase) {
        $choice=Read-Host 'Estado da coleta: 1 ANTES da corretiva; 2 DEPOIS; q cancela'
        $Phase=switch ($choice) { '1' { 'ANTES' } '2' { 'DEPOIS' } default { throw 'Selecao cancelada.' } }
    }
    if (-not $PSBoundParameters.ContainsKey('BaselineResultPath')) {
        $BaselineResultPath=Read-Host 'Caminho do result.json ANTES para comparar issues (Enter deixa comparacao pendente; q cancela)'
        if ($BaselineResultPath -eq 'q') { throw 'Selecao cancelada.' }
    }
    Write-Host 'Criterios: issues abertas Blocker/Critical/High e novas chaves exigem corretiva; cobertura minima 80% (meta 85%); duplicidade maxima 5%. Gate corporativo permanece independente.'
    $token=Read-Host 'Token Sonar do usuario (entrada oculta, nao sera salvo)' -AsSecureString
    $result=Invoke-HarnessSonar $context -ProjectKey $ProjectKey -BranchName $BranchName -Phase $Phase -Token $token -BaselineResultPath $BaselineResultPath
    $token.Dispose(); $token=$null
    $result | ConvertTo-Json -Depth 6 | Write-Host
    Write-Host "Resumo: $(Join-Path (Split-Path $result.ResultPath) 'RESUMO.md')"
    $null=Show-HarnessSonarReview $root $result.ResultPath
    if ($result.Status -eq 'SUCCEEDED') { exit 0 }
    if ($result.Status -in @('QUALITY_GATE_FAILED','CRITERIA_FAILED')) { exit 2 }
    exit 1
} catch {
    Write-Host ('ERRO ao analisar Sonar: ' + $_.Exception.Message) -ForegroundColor Red
    exit 1
} finally { if ($null -ne $token) { $token.Dispose() } }
