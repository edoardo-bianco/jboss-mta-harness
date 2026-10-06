#requires -Version 5.1
[CmdletBinding()]
param(
    [string]$ConfigPath, [string]$WorkspacePath, [string]$Target, [switch]$SelectTarget,
    [string]$EditorPath, [switch]$NoOpen, [string]$IssueId
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
try {
    Import-Module (Join-Path $PSScriptRoot 'Harness.psm1') -Force -DisableNameChecking
    . (Join-Path $PSScriptRoot 'HarnessPlanningInput.ps1')
    $harnessRoot = Split-Path -Parent $PSScriptRoot
    if (-not $ConfigPath) { $ConfigPath = Join-Path $harnessRoot 'config/harness.local.json' }
    $context = Read-HarnessConfig $ConfigPath $harnessRoot -WorkspacePath $WorkspacePath -Target $Target -SelectTarget:$SelectTarget
    if (-not $context.Active) { throw 'Escolha um projeto com -SelectTarget ou -Target.' }
    $register = Initialize-HarnessMigration $harnessRoot $context.Active
    $index = $register.EvidenceIndexPath
    $migrationInput=Read-HarnessMigrationInput $harnessRoot $context.Active $register.MigrationPath
    $chosen=@($migrationInput.Rows | Where-Object Decision -eq 'ANALISAR AGORA')
    if (-not $IssueId -and $chosen.Count -gt 1) { throw 'Mais de uma issue escolhida. Informe -IssueId para anexar evidencias a uma delas.' }
    if (-not $IssueId -and $chosen.Count -eq 1) { $IssueId=$chosen[0].Id }
    if ($IssueId) {
        if (@($migrationInput.Rows | Where-Object Id -CEQ $IssueId).Count -ne 1) { throw 'IssueId nao pertence ao registro selecionado.' }
        $paths=Get-HarnessIssuePaths $harnessRoot $context.Active $IssueId
        Initialize-HarnessIssueProject $paths $context.Active
        $index=$paths.EvidenceIndexPath
        if (Test-Path -LiteralPath $index) { Assert-HarnessIssueFicha $index $context.Active.path $IssueId }
        else {
            $null=[IO.Directory]::CreateDirectory((Split-Path $index -Parent))
            $identity=@{Source=$context.Active.path;Id=$IssueId}|ConvertTo-Json -Compress
            $body="# Evidencias: $($context.Active.label) / $IssueId`n`n<!-- issue: $identity -->`n`nListe a ficha-base e os anexos desta issue. Inclua a relacao de cada anexo com a correcao; referencie arquivos compartilhados sem os atribuir a outra issue.`n`n| Arquivo relativo | Relacao com a correcao |`n| --- | --- |`n"
            [IO.File]::WriteAllText($index,$body,(New-Object Text.UTF8Encoding($false)))
        }
    }
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
