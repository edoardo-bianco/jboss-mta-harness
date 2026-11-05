#requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'Harness.psm1') -DisableNameChecking
Import-Module (Join-Path $PSScriptRoot 'HarnessProject.psm1') -DisableNameChecking
Import-Module (Join-Path $PSScriptRoot 'HarnessJbossRuntime.psm1') -DisableNameChecking
Import-Module (Join-Path $PSScriptRoot 'HarnessGit.psm1') -DisableNameChecking

function Get-JbossDeployment {
    param($Server, [string]$Name)
    $list=Invoke-JbossCli $Server ':read-children-names(child-type=deployment)'
    if ($list -notmatch '"outcome"\s*=>\s*"success"') { throw 'Nao foi possivel listar deployments.' }
    if ($list -notmatch ('"'+[regex]::Escape($Name)+'"')) { return $null }
    $content=Invoke-JbossCli $Server ("/deployment=$Name`:read-attribute(name=content)")
    $bytes=[regex]::Matches($content,'0x([a-fA-F0-9]{2})')
    if ($bytes.Count -ne 20 -or $content -notmatch '"hash"\s*=>\s*bytes') { throw 'Deployment existente nao e um unico arquivo gerenciado.' }
    [pscustomobject]@{Hash=(($bytes | ForEach-Object {$_.Groups[1].Value}) -join '').ToUpperInvariant();
        RuntimeName=(Read-JbossValue $Server ("/deployment=$Name`:read-attribute(name=runtime-name)"));
        Status=(Read-JbossValue $Server ("/deployment=$Name`:read-attribute(name=status)"))}
}

function Open-JbossArtifact {
    param([string]$Path)
    if ($Path -match '["\r\n]') { throw 'Caminho do artefato nao suportado pela CLI JBoss.' }
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf) -or [IO.Path]::GetExtension($Path) -notin @('.war','.ear')) { throw 'Selecione um arquivo WAR ou EAR existente.' }
    # FileShare.Read: leitores (hash, zip, CLI) continuam possiveis; nenhuma
    # escrita altera o artefato entre a conferencia e o envio ao servidor.
    $held=[IO.File]::Open($Path,'Open','Read','Read')
    try {
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $zip=[IO.Compression.ZipFile]::OpenRead($Path)
        try { if (-not $zip.Entries.Count) { throw 'WAR/EAR vazio.' } } finally { $zip.Dispose() }
    } catch { $held.Dispose(); throw }
    $held
}

function Invoke-HarnessJbossDeploy {
    param($Context,$Server,[string]$ArtifactPath,[string]$DeploymentName)
    # Somente o ultimo deploy e guardado; o WAR implantado e sempre substituido.
    $result=[ordered]@{Action='Deploy';Status='FAILED';Project=$Context.Active.name;Source=$Context.Active.path;
        Eap=$Server.Eap;Home=$Server.Home;Base=$Server.Base;StandaloneConfig=$Server.Settings.standaloneConfig;DeploymentName=$DeploymentName;
        ArtifactSource=$null;Sha256=$null;Sha1=$null;Replaced=$false;ReplacedSha1=$null;Git=$null;
        StartedAtUtc=[DateTime]::UtcNow.ToString('o');FinishedAtUtc=$null;ResultPath=$null;Error=$null}
    $lock=$null; $project=$null; $access=$null; $held=$null
    $operation='jboss-'+$Server.Eap
    $relative='atual/jboss/'+$Server.Eap+'/ultimo-deploy.json'
    try {
        if ($DeploymentName -cnotmatch '^[A-Za-z0-9][A-Za-z0-9_.-]{0,119}\.(war|ear)$') { throw 'Nome do deployment deve ser simples e terminar em .war ou .ear.' }
        $state=Resolve-HarnessPath $Server.State $Context.Root
        $null=[IO.Directory]::CreateDirectory($state)
        try { $lock=[IO.File]::Open((Join-Path $state 'operation.lock'),'OpenOrCreate','ReadWrite','None') } catch { throw 'Outra operacao JBoss esta em andamento.' }
        $project=Initialize-HarnessProjectStorage $Context.Root (Join-Path $Context.Active.path 'pom.xml')
        $access=Enter-HarnessProjectAccess $project -ForOperation
        $result.Project=$project.Name
        $result.ResultPath=Join-Path $project.Folder $relative
        Set-HarnessProjectOperation $project $operation 'RUNNING'
        $current=Get-HarnessJbossStatus $Server
        if ($current.State -ne 'RUNNING' -or $current.Identity -ne 'MATCHED' -or $current.RunningMode -ne 'NORMAL') { throw 'Deploy exige servidor running em modo NORMAL com identidade confirmada. Use start/restart explicitamente.' }
        $ArtifactPath=Resolve-HarnessPath $ArtifactPath $Context.Root
        $result.ArtifactSource=$ArtifactPath
        $result.Git=Get-HarnessGitState $Context
        $held=Open-JbossArtifact $ArtifactPath
        $result.Sha256=(Get-FileHash -LiteralPath $ArtifactPath -Algorithm SHA256).Hash
        $result.Sha1=(Get-FileHash -LiteralPath $ArtifactPath -Algorithm SHA1).Hash
        try {
            $before=Get-JbossDeployment $Server $DeploymentName
            if ($before) { $result.Replaced=$true; $result.ReplacedSha1=$before.Hash }
        } catch {
            # Deployment com o mesmo nome, mas nao gerenciado como arquivo unico:
            # a decisao vigente e substitui-lo do mesmo modo.
            if ($_.Exception.Message -notmatch 'unico arquivo gerenciado') { throw }
            $result.Replaced=$true
        }
        $current=Get-HarnessJbossStatus $Server
        if ($current.State -ne 'RUNNING' -or $current.Identity -ne 'MATCHED' -or $current.RunningMode -ne 'NORMAL') { throw 'Servidor mudou antes do deploy.' }
        # A CLI Windows antiga reconhece C:\ como raiz, mas trata C:/ como relativo.
        $command='deploy "'+$ArtifactPath+'" --name='+$DeploymentName+' --runtime-name='+$DeploymentName
        if ($result.Replaced) { $command+=' --force' }
        $null=Invoke-JbossCli $Server $command
        $observed=Get-JbossDeployment $Server $DeploymentName
        if (-not $observed -or $observed.Status -ne 'OK' -or $observed.Hash -ine $result.Sha1 -or $observed.RuntimeName -cne $DeploymentName) { throw 'Deploy enviado, mas status/conteudo nao confirmados. Conferir o servidor.' }
        $result.Status='SUCCEEDED'
    } catch { $result.Status='FAILED'; $result.Error=$_.Exception.Message }
    finally {
        if ($held) { $held.Dispose() }
        $result.FinishedAtUtc=[DateTime]::UtcNow.ToString('o')
        try {
            if ($project) { Set-HarnessProjectOperation $project $operation $result.Status -ErrorMessage $result.Error -Files @{$relative=($result | ConvertTo-Json -Depth 6)} }
        } finally {
            if ($access) { $access.ReleaseMutex(); $access.Dispose() }
            if ($lock) { $lock.Dispose() }
        }
    }
    return [pscustomobject]$result
}

function Get-JbossDeploymentNames {
    param($Server)
    $reply=Invoke-JbossCli $Server ':read-children-names(child-type=deployment)'
    $match=[regex]::Match($reply,'"result"\s*=>\s*(\[(?:\s|"(?:\\.|[^"\\])*"|,)*\])')
    if ($reply -notmatch '"outcome"\s*=>\s*"success"' -or -not $match.Success) { throw 'Resposta CLI invalida ao listar deployments.' }
    # Apenas o array DMR de strings e JSON compativel; nao interpretar a tabela.
    $parsed=$match.Groups[1].Value | ConvertFrom-Json
    $names=@()
    if ($null -ne $parsed) { $names=@($parsed) }
    foreach ($name in $names) { if ($name -isnot [string] -or -not $name) { throw 'Nome de deployment invalido na resposta CLI.' } }
    $names
}

function Get-HarnessJbossDeployments {
    param($Server)
    $current=Get-HarnessJbossStatus $Server
    if ($current.State -ne 'RUNNING' -or $current.Identity -ne 'MATCHED') { throw 'Consulta exige gerenciamento ativo com identidade confirmada.' }
    $info=Invoke-JbossCli $Server 'deployment-info'
    [pscustomobject]@{Info=$info;Names=@(Get-JbossDeploymentNames $Server)}
}

function Invoke-HarnessJbossUndeploy {
    param($Server,[string[]]$Names)
    $result=[ordered]@{Action='Undeploy';Scope='Server';Eap=$Server.Eap;Home=$Server.Home;Base=$Server.Base;
        StandaloneConfig=$Server.Settings.standaloneConfig;Status='FAILED';Requested=@($Names);Removed=@();Error=$null;
        StartedAtUtc=[DateTime]::UtcNow.ToString('o');FinishedAtUtc=$null;ResultPath=(Join-Path $Server.State 'ultima-operacao.json')}
    $lock=$null
    try {
        if (-not $Names.Count) { throw 'Escolha ao menos um deployment listado.' }
        foreach ($name in $Names) {
            # Nome literal: impedir opcoes, expressoes CLI, caminhos e wildcard.
            if ($name -cnotmatch '^[A-Za-z0-9][A-Za-z0-9_. -]*$' -or $name.Contains(' --')) { throw "Nome de deployment nao suportado para undeploy: $name" }
        }
        $null=[IO.Directory]::CreateDirectory($Server.State)
        try { $lock=[IO.File]::Open((Join-Path $Server.State 'operation.lock'),'OpenOrCreate','ReadWrite','None') } catch { throw 'Outra operacao JBoss esta em andamento.' }
        $view=Get-HarnessJbossDeployments $Server
        foreach ($name in $Names) { if ($view.Names -cnotcontains $name) { throw 'A lista de deployments mudou. Consulte novamente antes de remover.' } }
        foreach ($name in $Names) {
            $current=Get-HarnessJbossStatus $Server
            if ($current.State -ne 'RUNNING' -or $current.Identity -ne 'MATCHED') { throw 'Servidor mudou antes do undeploy.' }
            $null=Invoke-JbossCli $Server ('undeploy "'+$name+'"')
            if (@(Get-JbossDeploymentNames $Server) -ccontains $name) { throw "Undeploy enviado, mas remocao nao confirmada: $name" }
            $result.Removed+=@($name)
        }
        $result.Status='SUCCEEDED'
    } catch { $result.Error=$_.Exception.Message }
    finally {
        $result.FinishedAtUtc=[DateTime]::UtcNow.ToString('o')
        if ($lock) { try { Write-HarnessJson $result.ResultPath $result } finally { $lock.Dispose() } }
    }
    [pscustomobject]$result
}

function Invoke-HarnessJbossDeploymentMenu {
    param($Context,$Server)
    $cancelled=[pscustomobject]@{Status='CANCELLED'}
    $current=Get-HarnessJbossStatus $Server
    if ($current.State -eq 'STOPPED') {
        Write-Host 'Servidor parado. 1. Iniciar somente administracao (sem aplicacoes) | 0. Sair'
        do {
            $choice=Read-Host 'Acao (Enter/q sai)'
            if ($choice -in @('','q','0')) { return $cancelled }
        } while ($choice -ne '1')
        $started=Invoke-HarnessJbossOperation $Context $Server 'StartAdminOnly'
        if ($started.Status -ne 'SUCCEEDED') { throw $started.Error }
        $current=$started.Observed
    }
    if ($current.State -ne 'RUNNING' -or $current.Identity -ne 'MATCHED') { throw 'Gerenciamento indisponivel; confira estado e identidade do servidor.' }
    Write-Host "Modo: $($current.RunningMode) | Console: http://127.0.0.1:$($Server.ManagementPort)/console"
    Write-Host 'Sair encerra somente a tarefa. O servidor permanece no modo atual.'
    $view=Get-HarnessJbossDeployments $Server
    Write-Host 'deployment-info:'
    Write-Host $view.Info
    if (-not $view.Names.Count) { Write-Host 'Nenhuma aplicacao registrada neste servidor.'; return $cancelled }
    Write-Host "1. Undeploy de todas as $($view.Names.Count) aplicacoes listadas | 2. Escolher uma aplicacao | 0. Sair"
    do {
        $choice=Read-Host 'Acao (Enter/q sai)'
        if ($choice -in @('','q','0')) { return $cancelled }
    } while ($choice -notin @('1','2'))
    $selected=@($view.Names)
    if ($choice -eq '2') {
        for ($i=0;$i -lt $view.Names.Count;$i++) { Write-Host ('{0}. {1}' -f ($i+1),$view.Names[$i]) }
        do {
            $choice=Read-Host 'Aplicacao (0/Enter/q sai)'
            if ($choice -in @('','q','0')) { return $cancelled }
            $number=0
            $valid=[int]::TryParse($choice,[ref]$number) -and $number -ge 1 -and $number -le $view.Names.Count
        } while (-not $valid)
        $selected=@($view.Names[$number-1])
    }
    Write-Host ('Undeploy: '+($selected -join ', '))
    $result=Invoke-HarnessJbossUndeploy $Server $selected
    $result | ConvertTo-Json -Depth 6 | Write-Host
    return $result
}

function Invoke-HarnessJbossOperation {
    param($Context,$Server,[ValidateSet('Status','Start','StartDebug','StartAdminOnly','Stop','Restart','RestartDebug')][string]$Action)
    $null=[IO.Directory]::CreateDirectory($Server.State)
    try { $lock=[IO.File]::Open((Join-Path $Server.State 'operation.lock'),'OpenOrCreate','ReadWrite','None') } catch { throw 'Outra operacao JBoss esta em andamento.' }
    # Somente a ultima operacao: cada execucao substitui o resultado anterior.
    # Logs do servidor ficam em ultimo-start/, renovados apenas por um novo start.
    $result=[ordered]@{Action=$Action;Scope='Server';Eap=$Server.Eap;Home=$Server.Home;Base=$Server.Base;StandaloneConfig=$Server.Settings.standaloneConfig;Source=$null;Project=$null;Status='FAILED';Observed=$null;Error=$null;StartedAtUtc=[DateTime]::UtcNow.ToString('o');FinishedAtUtc=$null;ResultPath=(Join-Path $Server.State 'ultima-operacao.json')}
    try {
        $result.Phase=$Action
        Write-HarnessJson $result.ResultPath $result
        $start=Join-Path $Server.State 'ultimo-start'
        $result.Observed=switch ($Action) {
            Status { Get-HarnessJbossStatus $Server }
            Start { Start-HarnessJboss $Server $start }
            StartDebug { Start-HarnessJboss $Server $start -DebugMode }
            StartAdminOnly { Start-HarnessJboss $Server $start -AdminOnly }
            Stop { Stop-HarnessJboss $Server }
            { $_ -in @('Restart','RestartDebug') } {
                $result.Phase='Stop'
                $stopped=Stop-HarnessJboss $Server
                if ($stopped.State -ne 'STOPPED') { throw 'Parada nao confirmada; restart interrompido antes do start.' }
                $result.Phase='Start'
                Start-HarnessJboss $Server $start -DebugMode:($Action -eq 'RestartDebug')
            }
        }
        $result.Status='SUCCEEDED'
        $result.Phase='Completed'
    } catch { $result.Error=$_.Exception.Message }
    finally {
        $result.FinishedAtUtc=[DateTime]::UtcNow.ToString('o')
        try { Write-HarnessJson $result.ResultPath $result } finally { $lock.Dispose() }
    }
    [pscustomobject]$result
}
Export-ModuleMember -Function Invoke-HarnessJbossDeploy, Invoke-HarnessJbossOperation, Get-HarnessJbossDeployments, Invoke-HarnessJbossUndeploy, Invoke-HarnessJbossDeploymentMenu
