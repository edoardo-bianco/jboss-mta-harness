#requires -Version 5.1
[CmdletBinding()]
param([string]$ConfigPath, [string]$WorkspacePath, [string]$Target, [switch]$SelectTarget,
    [string]$RunPath, [switch]$NoOpen)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
try {
    Import-Module (Join-Path $PSScriptRoot 'Harness.psm1') -Force -DisableNameChecking
    $harnessRoot = Split-Path -Parent $PSScriptRoot
    if (-not $RunPath) {
        if (-not $ConfigPath) { $ConfigPath = Join-Path $harnessRoot 'config/harness.local.json' }
        $context = Read-HarnessConfig $ConfigPath $harnessRoot -WorkspacePath $WorkspacePath -Target $Target -SelectTarget:$SelectTarget
        try { $report = Get-LastMtaReport $context }
        catch {
            if (-not $SelectTarget) { throw }
            Write-Host ('Ultimo relatorio indisponivel: ' + $_.Exception.Message)
            $RunPath = (Read-Host 'Pasta da rodada MTA existente ou recebida (contem manifest.json e result.json); q cancela').Trim().Trim('"')
            if (-not $RunPath -or $RunPath -eq 'q') { throw 'Abertura cancelada; historico preservado.' }
        }
    }
    if ($RunPath) {
        Import-Module (Join-Path $PSScriptRoot 'HarnessPlanning.psm1') -Force -DisableNameChecking
        $selected = Get-MtaPlanningRunFromPath -RunPath $RunPath -Root $harnessRoot
        $report = Join-Path $selected.Run 'output/static-report/index.html'
        Write-Host "Origem MTA: $($selected.Manifest.Project) | RunId: $($selected.RunId)"
    }
    Write-Host "Relatorio MTA: $report"
    if (-not $NoOpen) { Invoke-Item -LiteralPath $report }
    exit 0
} catch {
    Write-Host ("ERRO ao abrir relatorio MTA: " + $_.Exception.Message) -ForegroundColor Red
    exit 1
}
