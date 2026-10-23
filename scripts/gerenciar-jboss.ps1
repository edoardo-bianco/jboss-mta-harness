#requires -Version 5.1
[CmdletBinding()]
param([string]$ConfigPath,[string]$WorkspacePath,[string]$Target,[switch]$SelectTarget,
    [ValidateSet('eap71','eap74','all')][string]$Eap,
    [ValidateSet('Status','Start','StartDebug','Deploy','Stop','AddUser','Restart','RestartDebug')][string]$Action,
    [string]$ArtifactPath,[string]$DeploymentName,[switch]$SelectStartMode,[switch]$SelectRestartMode)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
try {
    Import-Module (Join-Path $PSScriptRoot 'Harness.psm1') -DisableNameChecking
    Import-Module (Join-Path $PSScriptRoot 'HarnessJbossRuntime.psm1') -DisableNameChecking
    Import-Module (Join-Path $PSScriptRoot 'HarnessJboss.psm1') -DisableNameChecking
    $root=Split-Path -Parent $PSScriptRoot
    if (-not $ConfigPath) { $ConfigPath=Join-Path $root 'config/harness.local.json' }
    if ($SelectStartMode -or $SelectRestartMode) {
        if ($Action -or ($SelectStartMode -and $SelectRestartMode)) { throw 'Use apenas Action, SelectStartMode ou SelectRestartMode.' }
        $operation=if ($SelectRestartMode) {'Restart'} else {'Start'}
        Write-Host "1. $operation normal | 2. $operation com debug"
        $choice=Read-Host 'Modo (Enter/q cancela)'
        $Action=switch ($choice) {'1' {$operation} '2' {$operation+'Debug'} default {throw 'Selecao cancelada.'}}
    }
    if (-not $Action) {
        Write-Host '1. Estado | 2. Start | 3. Start com debug | 4. Deploy | 5. Stop | 6. Criar usuario | 7. Restart | 8. Restart com debug'
        $choice=Read-Host 'Acao (Enter/q cancela)'
        $Action=switch ($choice) {'1' {'Status'} '2' {'Start'} '3' {'StartDebug'} '4' {'Deploy'} '5' {'Stop'} '6' {'AddUser'} '7' {'Restart'} '8' {'RestartDebug'} default {throw 'Selecao cancelada.'}}
    }
    $serverAction=$Action -in @('Status','Start','StartDebug','Stop','Restart','RestartDebug')
    if (-not $Eap) {
        $allOption=if ($serverAction) {' | 3. Todos (legado e EAP 7.4)'} else {''}
        Write-Host "Servidor: 1. EAP 7.0/7.1 (eap71) | 2. EAP 7.4$allOption | Enter/q cancela"
        $choice=Read-Host 'EAP'
        $Eap=switch ($choice) {'1' {'eap71'} '2' {'eap74'} '3' {if ($serverAction) {'all'} else {throw 'Selecao cancelada.'}} default {throw 'Selecao cancelada.'}}
    }
    if ($Eap -eq 'all' -and -not $serverAction) { throw 'Todos so se aplica a iniciar, reiniciar, parar e consultar estado do servidor.' }
    if ($Action -eq 'Deploy') {
        $context=Read-HarnessConfig $ConfigPath $root -WorkspacePath $WorkspacePath -Target $Target -SelectTarget:($SelectTarget -or -not $Target)
        if (-not $context.Active) { throw 'Escolha o projeto com -SelectTarget ou -Target.' }
        Write-Host "Projeto: $($context.Active.label) | Source: $($context.Active.path)"
    } else {
        if ($ArtifactPath -or $DeploymentName) { throw 'Artefato e nome do deployment so se aplicam a deploy.' }
        $context=Read-HarnessJbossContext $ConfigPath $root
    }
    if ($serverAction) {
        $selected=if ($Eap -eq 'all') {@('eap71','eap74')} else {@($Eap)}
        $summary=@()
        foreach ($serverId in $selected) {
            try {
                $server=Get-HarnessJbossServer $context $serverId
                Write-Host "Servidor: $serverId | EAP detectado: $($server.Version) | Home: $($server.Home) | Config: $($server.Settings.standaloneConfig)"
                Write-Host "HTTP: $($server.HttpPort) | Gerenciamento: $($server.ManagementPort) | Debug: 127.0.0.1:$($server.Settings.debugPort)"
                if ($Action -eq 'Stop') { Write-Host 'Stop encerra este servidor e todas as aplicacoes nele implantadas.' }
                if ($Action -in @('Restart','RestartDebug')) { Write-Host 'Restart para este servidor e suas aplicacoes; so inicia novamente depois da parada confirmada.' }
                $result=Invoke-HarnessJbossOperation $context $server $Action
            } catch {
                # Falhas anteriores ao recibo (configuracao/lock) tambem entram no resumo.
                $result=[pscustomobject]@{Eap=$serverId;Action=$Action;Status='FAILED';Observed=$null;Error=$_.Exception.Message;ResultPath=$null}
            }
            $result | ConvertTo-Json -Depth 8 | Write-Host
            $state=if ($result.Observed) {$result.Observed.State} else {'UNVERIFIED'}
            $summary+=[pscustomobject]@{Eap=$serverId;Status=$result.Status;State=$state}
            if ($Action -in @('StartDebug','RestartDebug') -and $result.Status -eq 'SUCCEEDED') {
                Write-Host "No VS Code: Run and Debug > JBoss $serverId - attach Java > F5. Desconectar nao para o servidor."
            }
        }
        if ($Eap -eq 'all') {
            Write-Host 'Resumo por servidor:'
            $summary | Format-Table -AutoSize | Out-String | Write-Host
        }
        if (@($summary | Where-Object Status -ne 'SUCCEEDED').Count) { exit 1 }
        exit 0
    }
    $server=Get-HarnessJbossServer $context $Eap
    Write-Host "Servidor: $Eap | EAP detectado: $($server.Version) | Home: $($server.Home) | Config: $($server.Settings.standaloneConfig)"
    Write-Host "HTTP: $($server.HttpPort) | Gerenciamento: $($server.ManagementPort) | Debug: 127.0.0.1:$($server.Settings.debugPort)"
    if ($Action -eq 'AddUser') {
        Write-Host 'Assistente oficial: a = Management User (gerenciamento/console); b = Application User.'
        Write-Host 'Informe nome e senha no assistente. O servidor pode estar parado.'
        Invoke-HarnessJbossAddUser $server
        Write-Host 'Assistente encerrado. Se confirmou a criacao de Management User, confira o login na console com o servidor ativo.'
        exit 0
    }
    if (-not $ArtifactPath) {
        Import-Module (Join-Path $PSScriptRoot 'HarnessJbossArtifacts.psm1') -DisableNameChecking
        $ArtifactPath=Select-HarnessJbossArtifact $context.Active.path
    }
    if (-not $ArtifactPath) { throw 'Selecao cancelada.' }
    $ArtifactPath=Resolve-HarnessPath $ArtifactPath $root
    if (-not $DeploymentName) {
        $suggested=[IO.Path]::GetFileName($ArtifactPath)
        $DeploymentName=Read-Host "Nome estavel do deployment (Enter usa $suggested)"
        if (-not $DeploymentName) { $DeploymentName=$suggested }
    }
    Write-Host "Deploy: $ArtifactPath -> $DeploymentName | SHA256: $((Get-FileHash -LiteralPath $ArtifactPath -Algorithm SHA256).Hash)"
    Write-Host 'O deploy substitui o WAR/EAR implantado com este nome, inclusive se implantado fora do harness. Guarda somente o ultimo deploy.'
    $result=Invoke-HarnessJbossDeploy $context $server -ArtifactPath $ArtifactPath -DeploymentName $DeploymentName
    $result | ConvertTo-Json -Depth 8 | Write-Host
    if ($result.Status -ne 'SUCCEEDED') { exit 1 }
    exit 0
} catch { Write-Host ('ERRO JBoss: '+$_.Exception.Message) -ForegroundColor Red; exit 1 }
