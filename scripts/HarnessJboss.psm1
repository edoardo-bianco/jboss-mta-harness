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
        if ($current.State -ne 'RUNNING' -or $current.Identity -ne 'MATCHED') { throw 'Deploy exige servidor running com identidade confirmada. Use start explicitamente.' }
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
        if ($current.State -ne 'RUNNING' -or $current.Identity -ne 'MATCHED') { throw 'Servidor mudou antes do deploy.' }
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

function Invoke-HarnessJbossOperation {
    param($Context,$Server,[ValidateSet('Status','Start','StartDebug','Stop','Restart','RestartDebug')][string]$Action)
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
Export-ModuleMember -Function Invoke-HarnessJbossDeploy, Invoke-HarnessJbossOperation
