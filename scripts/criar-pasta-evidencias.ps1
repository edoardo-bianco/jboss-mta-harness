#requires -Version 5.1
[CmdletBinding()]
param(
    [string]$ConfigPath,[string]$WorkspacePath,[string]$Target,[switch]$SelectTarget,
    [string]$EditorPath,[switch]$NoOpen,[string]$IssueId
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
try {
    Import-Module (Join-Path $PSScriptRoot 'Harness.psm1') -Force -DisableNameChecking
    Import-Module (Join-Path $PSScriptRoot 'HarnessProject.psm1') -Force -DisableNameChecking
    $root=Split-Path -Parent $PSScriptRoot
    if (-not $ConfigPath) { $ConfigPath=Join-Path $root 'config/harness.local.json' }
    $context=Read-HarnessConfig $ConfigPath $root -WorkspacePath $WorkspacePath -Target $Target -SelectTarget:$SelectTarget -SkipMigrationInitialization
    if (-not $context.Active) { throw 'Escolha um projeto com -SelectTarget ou -Target.' }
    $project=Get-HarnessProjectStorage $root (Join-Path $context.Active.path 'pom.xml')
    if (-not (Test-Path -LiteralPath $project.MigrationPath -PathType Leaf)) { throw 'Registro ausente; execute Workspace: atualizar indice dos projetos.' }
    if ($IssueId -and -not @(Get-HarnessProjectDecisions $project | Where-Object Id -CEQ $IssueId).Count) { throw 'IssueId nao pertence ao registro selecionado.' }
    $relative='evidencias/LEIA-ME.md'
    $index=Join-Path $project.Folder $relative
    $old=Read-HarnessProjectFiles $project @($relative)
    if ($null -eq $old[$relative]) {
        $body="# Evidencias: $($project.Name)`n`nListe links Markdown para os anexos, a issue e a relacao com a corretiva. Use * na coluna Issue para evidencia geral do projeto. Os arquivos permanecem na origem indicada; o planejamento le estas referencias diretamente.`n`n"
        if ($IssueId) { $body+="Issue de interesse: $(ConvertTo-ProjectCell $IssueId).`n`n" }
        $body+="| Issue | Arquivo (link relativo a este indice) | Relacao com a corretiva |`n| --- | --- | --- |`n`nUse o formato Markdown de link: rotulo entre colchetes, seguido do caminho entre parenteses.`n"
        Publish-HarnessProjectFiles $project @{$relative=$body} $old
    }
    Write-Host "Registro de migracao: $($project.MigrationPath)"
    Write-Host "Indice de evidencias: $index"
    Write-Host 'Relacione os anexos as issues no indice. Evidencias existentes foram preservadas; nenhum exame, GO ou aceite foi registrado.'
    if (-not $NoOpen -and $EditorPath) {
        try { Open-HarnessEditor -EditorPath $EditorPath -FilePaths $index -Root $root }
        catch { Write-Warning ('Indice disponivel; abra o caminho acima. '+$_.Exception.Message) }
    }
    exit 0
} catch {
    Write-Host ('ERRO ao criar pasta de evidencias: '+$_.Exception.Message) -ForegroundColor Red
    exit 1
}
