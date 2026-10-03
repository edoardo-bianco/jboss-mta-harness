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
    if (-not $config.PSObject.Properties['eap']) {
        $config | Add-Member NoteProperty eap $defaults.eap
        $changed=$true
    } elseif ($config.eap -is [pscustomobject]) {
        foreach ($id in @('eap71','eap74')) {
            if (-not $config.eap.PSObject.Properties[$id]) { $config.eap | Add-Member NoteProperty $id $defaults.eap.$id; $changed=$true }
            else {
                foreach ($field in $defaults.eap.$id.PSObject.Properties) {
                    if (-not $config.eap.$id.PSObject.Properties[$field.Name]) { $config.eap.$id | Add-Member NoteProperty $field.Name $field.Value; $changed=$true }
                }
            }
        }
    }
    if (-not $config.PSObject.Properties['mta']) {
        $config | Add-Member NoteProperty mta $defaults.mta
        $changed=$true
    } elseif ($config.mta -is [pscustomobject] -and -not $config.mta.PSObject.Properties['runsPath']) {
        $config.mta | Add-Member NoteProperty runsPath $null
        $changed=$true
    }
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
        Write-Host 'Campos de configuracao ausentes incluidos com os padroes do modelo; valores existentes preservados.'
    }
    Write-Host "Configuracao: $ConfigPath"
    Write-Host 'Para rodadas MTA em pasta curta externa, configure mta.runsPath = C:/mta-runs. Null preserva .harness/runs. Historico existente nao e movido.'
    Write-Host 'Preencha os caminhos em tools e salve. Os projetos das tarefas vem do workspace aberto; activeProject e um padrao opcional.'
    Write-Host 'Confira sonar: serverUrl (local/corporativo), scannerJdkHome, scannerVersion (padrao 5.8.0.7211; validar compatibilidade), ceTimeoutSeconds e profiles. Token nunca vai no JSON; a tarefa solicita entrada oculta.'
    Write-Host 'Confira eap.eap71/eap74: standaloneConfig, portOffset, debugPort e timeoutSeconds. Use Servidor: iniciar/parar/consultar estado/criar usuario JBoss e Aplicacao: deploy/rollback no JBoss; gere o workspace para atualizar os attaches Java.'
    Write-Host 'Para criar um workspace pelo JSON, preencha repositories e execute Workspace: gerar workspace. Para adicionar projetos no workspace existente, use Add Folder to Workspace.'
    if ($EditorPath) {
        Import-Module (Join-Path $PSScriptRoot 'Harness.psm1') -Force -DisableNameChecking
        Open-HarnessEditor -EditorPath $EditorPath -FilePaths $ConfigPath -Root (Split-Path -Parent $PSScriptRoot)
    }
    exit 0
} catch {
    Write-Host ("ERRO ao abrir configuracao: " + $_.Exception.Message) -ForegroundColor Red
    exit 1
}
