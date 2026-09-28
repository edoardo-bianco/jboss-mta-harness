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
    $template = Join-Path $harnessRoot 'doc/guias/modelo-evidencias-complementares.md'
    $content = Get-Content -LiteralPath $template -Raw -Encoding UTF8
    $createdAt = [DateTimeOffset]::Now.ToString('o')
    $content = $content.Replace('- Project: PREENCHER', '- Project: ' + $context.Active.name)
    $content = $content.Replace('- Nome do projeto (Label): PREENCHER', '- Nome do projeto (Label): ' + $context.Active.label)
    $content = $content.Replace('- Source (raiz da aplicacao): PREENCHER', '- Source (raiz da aplicacao): ' + $context.Active.path)
    $content = $content.Replace('- Data de organizacao desta pasta, com fuso: PREENCHER', '- Data de organizacao desta pasta, com fuso: ' + $createdAt)
    $projectFolder = Get-HarnessProjectFolder $context.Active
    # Sufixo aleatorio evita colisoes entre preparacoes no mesmo segundo; nao e hash.
    $name = 'evidencias_' + (Format-HarnessDate $createdAt -ForPath) + '__' + [guid]::NewGuid().ToString('N').Substring(0,12)
    $folder = Resolve-HarnessPath (Join-Path $harnessRoot ('.harness/evidencias/' + $projectFolder + '/' + $name)) $harnessRoot
    $index = Join-Path $folder 'LEIA-ME.md'
    $null = New-Item -ItemType Directory -Path $folder -ErrorAction Stop
    $bytes = (New-Object Text.UTF8Encoding($false)).GetBytes($content)
    $stream = [IO.File]::Open($index, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try { $stream.Write($bytes, 0, $bytes.Length) } finally { $stream.Dispose() }
    Write-Host "Projeto: $($context.Active.label)"
    Write-Host "Pasta de evidencias: $folder"
    Write-Host "Indice e instrucoes: $index"
    Write-Host 'Coloque os arquivos manualmente nesta pasta e liste-os no LEIA-ME.md. Preencha o lote e o objetivo da revisao.'
    Write-Host 'Depois prepare contexto selecionando o planejamento anterior (Previous) e use /revisar-lote com o prompt preparado e este indice.'
    Write-Host 'Nenhum MTA, plano ou agente foi executado. Sem hashes adicionais; pastas anteriores preservadas.'
    if (-not $NoOpen) {
        if (-not $EditorPath) { Write-Host 'Abra o indice acima no VS Code ou informe -EditorPath.' }
        else {
            try {
                $editor = Resolve-HarnessPath $EditorPath $harnessRoot
                if (-not (Test-Path -LiteralPath $editor -PathType Leaf)) { throw 'Executavel do editor nao encontrado.' }
                $global:LASTEXITCODE = 0
                & $editor --reuse-window $index
                if ($LASTEXITCODE -ne 0) { throw "Editor retornou codigo $LASTEXITCODE." }
            } catch { Write-Warning ('Pasta criada; abra o indice pelo caminho acima. ' + $_.Exception.Message) }
        }
    }
    exit 0
} catch {
    Write-Host ('ERRO ao criar pasta de evidencias: ' + $_.Exception.Message) -ForegroundColor Red
    exit 1
}
