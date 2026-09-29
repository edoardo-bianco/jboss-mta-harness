#requires -Version 5.1
[CmdletBinding()]
param([string]$ConfigPath, [string]$EditorPath)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
try {
    $harnessRoot = Split-Path -Parent $PSScriptRoot
    if (-not $ConfigPath) { $ConfigPath = Join-Path $harnessRoot 'config/harness.local.json' }
    if (-not (Test-Path -LiteralPath $ConfigPath)) {
        $null = [IO.Directory]::CreateDirectory((Split-Path -Parent $ConfigPath))
        Copy-Item -LiteralPath (Join-Path $harnessRoot 'config/harness.example.json') -Destination $ConfigPath
    }
    Write-Host "Configuracao: $ConfigPath"
    Write-Host 'Preencha os caminhos em tools e salve. Os projetos das tarefas vem do workspace aberto; activeProject e um padrao opcional.'
    Write-Host 'Para Sonar, adicione/preencha o bloco sonar de config/harness.example.json: serverUrl e scannerJdkHome. Token nunca vai no JSON; a tarefa solicita entrada oculta.'
    Write-Host 'Para criar um workspace pelo JSON, preencha repositories e execute Workspace: gerar workspace. Para adicionar projetos no workspace existente, use Add Folder to Workspace.'
    if ($EditorPath) {
        if (-not (Test-Path -LiteralPath $EditorPath -PathType Leaf)) { throw 'Executavel do editor nao encontrado.' }
        & $EditorPath --reuse-window $ConfigPath
    }
    exit 0
} catch {
    Write-Host ("ERRO ao abrir configuracao: " + $_.Exception.Message) -ForegroundColor Red
    exit 1
}
