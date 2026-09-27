#requires -Version 5.1
[CmdletBinding()]
param([string]$ConfigPath, [string]$WorkspacePath, [string]$Target, [switch]$SelectTarget, [string]$RequestId)
$ErrorActionPreference = 'Stop'
try {
    Import-Module (Join-Path $PSScriptRoot 'Harness.psm1') -Force -DisableNameChecking
    Import-Module (Join-Path $PSScriptRoot 'HarnessPlanning.psm1') -Force -DisableNameChecking
    Import-Module (Join-Path $PSScriptRoot 'HarnessGit.psm1') -Force -DisableNameChecking
    $root = Split-Path -Parent $PSScriptRoot
    if (-not $ConfigPath) { $ConfigPath = Join-Path $root 'config/harness.local.json' }
    $context = Read-HarnessConfig $ConfigPath $root -WorkspacePath $WorkspacePath -Target $Target -SelectTarget:$SelectTarget
    if ($SelectTarget) {
        $choice = Read-Host 'Enter confere Git de um planejamento; c configura/revisa escolhas de branches; q cancela'
        if ($choice -eq 'c') {
            Set-HarnessGitPolicyInteractive $context
            Write-Host 'Prepare novo contexto para registrar essas escolhas; nenhum planejamento anterior foi alterado.'
            exit 0
        }
        if ($choice -ne '') { throw 'Conferencia cancelada.' }
    }
    $selected = Select-MtaPreviousPlanning $context -ForOpen -RequestId $RequestId
    $baseline = $null
    if ($selected.PSObject.Properties['Git']) { $baseline = $selected.Git }
    $result = Test-HarnessGitState $context $baseline
    Write-Host "Repositorio: $($result.Current.RepositoryRoot) | Branch atual: $($result.Current.Branch) | HEAD: $($result.Current.Head)"
    Write-Host $result.Scope
    if (-not $result.Ready) {
        foreach ($reason in $result.Reasons) { Write-Host ('PENDENTE/BLOQUEADO: ' + $reason) }
        exit 1
    }
    Write-Host 'OK: identidade, branch, HEAD, estado local e referencias locais conferidos. Alinhamento remoto e GO humano continuam separados.'
    exit 0
} catch { Write-Host ('ERRO na conferencia Git: ' + $_.Exception.Message) -ForegroundColor Red; exit 1 }
