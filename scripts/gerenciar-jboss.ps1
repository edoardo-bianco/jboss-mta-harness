#requires -Version 5.1
[CmdletBinding()]
param([string]$ConfigPath,[string]$WorkspacePath,[string]$Target,[switch]$SelectTarget,
    [ValidateSet('eap71','eap74')][string]$Eap,
    [ValidateSet('Status','Start','StartDebug','Deploy','Rollback','Stop')][string]$Action,
    [string]$ArtifactPath,[string]$DeploymentName,[string]$ReleaseId)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
try {
    Import-Module (Join-Path $PSScriptRoot 'Harness.psm1') -DisableNameChecking
    Import-Module (Join-Path $PSScriptRoot 'HarnessJbossRuntime.psm1') -DisableNameChecking
    Import-Module (Join-Path $PSScriptRoot 'HarnessJboss.psm1') -DisableNameChecking
    $root=Split-Path -Parent $PSScriptRoot
    if (-not $ConfigPath) { $ConfigPath=Join-Path $root 'config/harness.local.json' }
    $context=Read-HarnessConfig $ConfigPath $root -WorkspacePath $WorkspacePath -Target $Target -SelectTarget:$SelectTarget
    if (-not $context.Active) { throw 'Escolha o projeto com -SelectTarget ou -Target.' }
    if (-not $Eap) {
        Write-Host 'Servidor: 1. EAP 7.1 | 2. EAP 7.4 | Enter/q cancela'
        $choice=Read-Host 'EAP'
        $Eap=switch ($choice) {'1' {'eap71'} '2' {'eap74'} default {throw 'Selecao cancelada.'}}
    }
    $server=Get-HarnessJbossServer $context $Eap
    Write-Host "Projeto: $($context.Active.label) | Source: $($context.Active.path)"
    Write-Host "Servidor: $Eap | Home: $($server.Home) | Config: $($server.Settings.standaloneConfig)"
    Write-Host "HTTP: $($server.HttpPort) | Gerenciamento: $($server.ManagementPort) | Debug: 127.0.0.1:$($server.Settings.debugPort)"
    if (-not $Action) {
        Write-Host '1. Estado | 2. Start | 3. Start com debug | 4. Deploy | 5. Rollback | 6. Stop'
        $choice=Read-Host 'Acao (Enter/q cancela)'
        $Action=switch ($choice) {'1' {'Status'} '2' {'Start'} '3' {'StartDebug'} '4' {'Deploy'} '5' {'Rollback'} '6' {'Stop'} default {throw 'Selecao cancelada.'}}
    }
    if ($Action -in @('Deploy','Rollback')) {
        if ($Action -eq 'Deploy') {
            if (-not $ArtifactPath) { $ArtifactPath=Read-Host 'Caminho do WAR/EAR ja construido (Enter cancela)' }
            if (-not $ArtifactPath) { throw 'Selecao cancelada.' }
            $ArtifactPath=Resolve-HarnessPath $ArtifactPath $root
            if (-not $DeploymentName) {
                $suggested=[IO.Path]::GetFileName($ArtifactPath)
                $DeploymentName=Read-Host "Nome estavel do deployment (Enter usa $suggested)"
                if (-not $DeploymentName) { $DeploymentName=$suggested }
            }
            Write-Host "Deploy: $ArtifactPath -> $DeploymentName | SHA256: $((Get-FileHash -LiteralPath $ArtifactPath -Algorithm SHA256).Hash)"
        } else {
            if (-not $DeploymentName) { $DeploymentName=Read-Host 'Nome do deployment, incluindo .war/.ear (Enter cancela)' }
            if (-not $DeploymentName) { throw 'Selecao cancelada.' }
            if (-not $ReleaseId) {
                $releases=@(Get-HarnessJbossReleases $context $server $DeploymentName | Sort-Object StartedAtUtc -Descending)
                if (-not $releases.Count) { throw 'Nenhuma release gerenciada disponivel para este projeto/EAP/nome.' }
                for ($i=0;$i -lt $releases.Count;$i++) { Write-Host ("{0}. {1} | {2} | SHA256 {3}" -f ($i+1),$releases[$i].RunId,$releases[$i].StartedAtUtc,$releases[$i].Sha256) }
                $choice=Read-Host 'Release a restaurar (Enter/q cancela)'
                $number=0
                if (-not [int]::TryParse($choice,[ref]$number) -or $number -lt 1 -or $number -gt $releases.Count) { throw 'Selecao cancelada.' }
                $ReleaseId=$releases[$number-1].RunId
            }
        }
        $result=Invoke-HarnessJbossRelease $context $server $Action -ArtifactPath $ArtifactPath -DeploymentName $DeploymentName -ReleaseId $ReleaseId
    } else {
        if ($ArtifactPath -or $DeploymentName -or $ReleaseId) { throw 'Argumentos de release so se aplicam a deploy/rollback.' }
        if ($Action -eq 'Stop') { Write-Host 'Stop encerra este servidor e todas as aplicacoes nele implantadas.' }
        $result=Invoke-HarnessJbossOperation $context $server $Action
    }
    $result | ConvertTo-Json -Depth 8 | Write-Host
    if ($result.Status -ne 'SUCCEEDED') { exit 1 }
    if ($Action -eq 'StartDebug') { Write-Host "No VS Code: Run and Debug > JBoss $Eap - attach Java > F5. Desconectar nao para o servidor." }
    exit 0
} catch { Write-Host ('ERRO JBoss: '+$_.Exception.Message) -ForegroundColor Red; exit 1 }
