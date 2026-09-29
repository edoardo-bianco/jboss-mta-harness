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
    $defaults=Get-Content -LiteralPath (Join-Path $harnessRoot 'config/harness.example.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    $config=Get-Content -LiteralPath $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $changed=$false
    if (-not $config.PSObject.Properties['sonar']) {
        $config | Add-Member -NotePropertyName sonar -NotePropertyValue $defaults.sonar
        $changed=$true
    } elseif ($config.sonar -is [pscustomobject]) {
        foreach ($field in $defaults.sonar.PSObject.Properties) {
            if (-not $config.sonar.PSObject.Properties[$field.Name]) {
                $config.sonar | Add-Member -NotePropertyName $field.Name -NotePropertyValue $field.Value
                $changed=$true
            }
        }
    }
    if ($changed) {
        [IO.File]::WriteAllText($ConfigPath, ($config | ConvertTo-Json -Depth 100), (New-Object Text.UTF8Encoding($false)))
        Write-Host 'Campos Sonar ausentes incluidos com os padroes do modelo; valores existentes preservados.'
    }
    Write-Host "Configuracao: $ConfigPath"
    Write-Host 'Preencha os caminhos em tools e salve. Os projetos das tarefas vem do workspace aberto; activeProject e um padrao opcional.'
    Write-Host 'Confira sonar: serverUrl (local/corporativo), scannerJdkHome, scannerVersion (padrao 5.8.0.7211; validar compatibilidade), ceTimeoutSeconds e profiles. Token nunca vai no JSON; a tarefa solicita entrada oculta.'
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
