#requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'Harness.psm1') -DisableNameChecking
Import-Module (Join-Path $PSScriptRoot 'HarnessJbossRuntime.psm1') -DisableNameChecking
Import-Module (Join-Path $PSScriptRoot 'HarnessGit.psm1') -DisableNameChecking

function Get-JbossDeployment {
    param($Server, [string]$Name)
    $list=Invoke-JbossCli $Server ':read-children-names(child-type=deployment)'
    if ($list -notmatch '"outcome"\s*=>\s*"success"') { throw 'Nao foi possivel listar deployments.' }
    if ($list -notmatch ('"'+[regex]::Escape($Name)+'"')) { return $null }
    $content=Invoke-JbossCli $Server ("/deployment=$Name`:read-attribute(name=content)")
    $bytes=[regex]::Matches($content,'0x([a-fA-F0-9]{2})')
    if ($bytes.Count -ne 20 -or $content -notmatch '"hash"\s*=>\s*bytes') { throw 'Deployment existente nao e um unico arquivo gerenciado; preservar e conferir manualmente.' }
    [pscustomobject]@{Hash=(($bytes | ForEach-Object {$_.Groups[1].Value}) -join '').ToUpperInvariant();
        RuntimeName=(Read-JbossValue $Server ("/deployment=$Name`:read-attribute(name=runtime-name)"));
        Status=(Read-JbossValue $Server ("/deployment=$Name`:read-attribute(name=status)"))}
}

function Get-HarnessJbossReleases {
    param($Context,$Server,[string]$DeploymentName)
    $runs=Join-Path $Server.State 'releases'
    if (-not (Test-Path -LiteralPath $runs)) { return }
    foreach ($folder in Get-ChildItem -LiteralPath $runs -Directory) {
        if ($folder.Name -cnotmatch '^[a-f0-9]{32}$') { continue }
        $path=Resolve-HarnessPath (Join-Path $folder.FullName 'result.json') $Context.Root
        if (-not (Test-Path -LiteralPath $path)) { continue }
        $result=Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($result.Status -eq 'SUCCEEDED' -and $result.RunId -ceq $folder.Name -and $result.Source -ieq $Context.Active.path -and
            $result.Eap -eq $Server.Eap -and $result.Home -ieq $Server.Home -and $result.Base -ieq $Server.Base -and
            $result.StandaloneConfig -ceq $Server.Settings.standaloneConfig -and $result.DeploymentName -ceq $DeploymentName) { $result }
    }
}

function Copy-JbossReleaseArtifact {
    param([string]$Source,[string]$Destination)
    $null=Resolve-HarnessPath $Source (Split-Path -Parent $Destination)
    if (-not (Test-Path -LiteralPath $Source -PathType Leaf) -or [IO.Path]::GetExtension($Source) -notin @('.war','.ear')) { throw 'Selecione um arquivo WAR ou EAR existente.' }
    # FileShare.Read impede substituicao durante a captura. A copia e a release.
    $input=[IO.File]::Open($Source,'Open','Read','Read')
    try {
        $output=[IO.File]::Open($Destination,'CreateNew','Write','None')
        try { $input.CopyTo($output) } finally { $output.Dispose() }
    } finally { $input.Dispose() }
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip=[IO.Compression.ZipFile]::OpenRead($Destination)
    try { if (-not $zip.Entries.Count) { throw 'WAR/EAR vazio.' } } finally { $zip.Dispose() }
}

function Invoke-HarnessJbossRelease {
    param($Context,$Server,[ValidateSet('Deploy','Rollback')][string]$Action,[string]$ArtifactPath,[string]$DeploymentName,[string]$ReleaseId)
    $result=[ordered]@{RunId=[guid]::NewGuid().ToString('N');Action=$Action;Status='FAILED';Project=$Context.Active.name;Source=$Context.Active.path;
        Eap=$Server.Eap;Home=$Server.Home;Base=$Server.Base;StandaloneConfig=$Server.Settings.standaloneConfig;DeploymentName=$DeploymentName;
        ArtifactSource=$null;Git=$null;Sha256=$null;Sha1=$null;PreviousRelease=$null;RestoredRelease=$null;
        StartedAtUtc=[DateTime]::UtcNow.ToString('o');FinishedAtUtc=$null;ResultPath=$null;Error=$null}
    $lock=$null; $run=$null
    try {
        if ($DeploymentName -cnotmatch '^[A-Za-z0-9][A-Za-z0-9_.-]{0,119}\.(war|ear)$') { throw 'Nome do deployment deve ser simples e terminar em .war ou .ear.' }
        $state=Resolve-HarnessPath $Server.State $Context.Root
        $null=[IO.Directory]::CreateDirectory($state)
        try { $lock=[IO.File]::Open((Join-Path $state 'operation.lock'),'OpenOrCreate','ReadWrite','None') } catch { throw 'Outra operacao JBoss esta em andamento.' }
        $run=Resolve-HarnessPath (Join-Path $state ('releases/'+$result.RunId)) $Context.Root
        $null=[IO.Directory]::CreateDirectory($run)
        $result.ResultPath=Join-Path $run 'result.json'
        Write-HarnessJson $result.ResultPath $result
        $current=Get-HarnessJbossStatus $Server
        if ($current.State -ne 'RUNNING' -or $current.Identity -ne 'MATCHED') { throw 'Deploy/rollback exige servidor running com identidade confirmada. Use start explicitamente.' }
        $pointer=Resolve-HarnessPath (Join-Path $state ('deployments/'+$DeploymentName+'.json')) $Context.Root
        $existing=Get-JbossDeployment $Server $DeploymentName
        if ($existing) {
            if (-not (Test-Path -LiteralPath $pointer)) { throw 'Deployment existente sem release gerenciada. Preserve o artefato anterior ou use outro nome; substituicao recusada.' }
            $last=Get-Content -LiteralPath $pointer -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($last.Source -ine $Context.Active.path -or $last.Home -ine $Server.Home -or $last.Base -ine $Server.Base -or
                $last.StandaloneConfig -cne $Server.Settings.standaloneConfig -or $last.Eap -ne $Server.Eap -or
                $last.DeploymentName -cne $DeploymentName -or $last.Sha1 -ine $existing.Hash -or $existing.RuntimeName -cne $DeploymentName -or $existing.Status -ne 'OK') { throw 'Deployment divergente da ultima release gerenciada; conferir alteracoes externas antes de substituir.' }
            $result.PreviousRelease=$last.RunId
        } elseif ($Action -eq 'Rollback') { throw 'Rollback exige deployment atual gerenciado; nenhum deployment encontrado.' }
        $snapshot=Join-Path $run $DeploymentName
        if ($Action -eq 'Rollback') {
            if ($ReleaseId -cnotmatch '^[a-f0-9]{32}$') { throw 'Escolha uma release anterior explicita.' }
            $selected=@(Get-HarnessJbossReleases $Context $Server $DeploymentName | Where-Object RunId -ceq $ReleaseId)
            if ($selected.Count -ne 1 -or $ReleaseId -eq $result.PreviousRelease) { throw 'Release anterior nao encontrada para este projeto/EAP/deployment.' }
            $ArtifactPath=Resolve-HarnessPath (Join-Path $state ('releases/'+$ReleaseId+'/'+$DeploymentName)) $Context.Root
            if ((Get-FileHash -LiteralPath $ArtifactPath -Algorithm SHA256).Hash -ine $selected[0].Sha256) { throw 'Artefato de rollback adulterado ou divergente.' }
            $result.RestoredRelease=$ReleaseId
        }
        $ArtifactPath=Resolve-HarnessPath $ArtifactPath $Context.Root
        $result.ArtifactSource=$ArtifactPath
        $result.Git=Get-HarnessGitState $Context
        Copy-JbossReleaseArtifact $ArtifactPath $snapshot
        $result.Sha256=(Get-FileHash -LiteralPath $snapshot -Algorithm SHA256).Hash
        $result.Sha1=(Get-FileHash -LiteralPath $snapshot -Algorithm SHA1).Hash
        if ($Action -eq 'Rollback' -and $result.Sha256 -ine $selected[0].Sha256) { throw 'Artefato mudou durante a captura de rollback.' }
        $result.Status='EXECUTING'; Write-HarnessJson $result.ResultPath $result
        # Revalidar imediatamente antes da escrita remota. Nao substituir mudanca externa.
        $current=Get-HarnessJbossStatus $Server
        if ($current.State -ne 'RUNNING' -or $current.Identity -ne 'MATCHED') { throw 'Servidor mudou antes do deploy.' }
        $before=Get-JbossDeployment $Server $DeploymentName
        if (($null -eq $existing) -ne ($null -eq $before) -or ($existing -and $before.Hash -ine $existing.Hash)) { throw 'Deployment mudou antes do deploy.' }
        $command='deploy "'+$snapshot.Replace('\','/')+'" --name='+$DeploymentName+' --runtime-name='+$DeploymentName
        if ($existing) { $command+=' --force' }
        # Nao permitir escrita no snapshot enquanto a CLI o le.
        $held=[IO.File]::Open($snapshot,'Open','Read','Read')
        try { $null=Invoke-JbossCli $Server $command } finally { $held.Dispose() }
        $observed=Get-JbossDeployment $Server $DeploymentName
        if (-not $observed -or $observed.Status -ne 'OK' -or $observed.Hash -ine $result.Sha1 -or $observed.RuntimeName -cne $DeploymentName) { throw 'Deploy enviado, mas status/conteudo nao confirmados. Conferir servidor; rollback nao executado automaticamente.' }
        $result.Status='SUCCEEDED'
        $result.FinishedAtUtc=[DateTime]::UtcNow.ToString('o')
        Write-HarnessJson $result.ResultPath $result
        Write-HarnessJson $pointer $result
    } catch { $result.Status='FAILED'; $result.Error=$_.Exception.Message }
    finally {
        $result.FinishedAtUtc=[DateTime]::UtcNow.ToString('o')
        try { if ($result.ResultPath) { Write-HarnessJson $result.ResultPath $result } } finally { if ($lock) {$lock.Dispose()} }
    }
    return [pscustomobject]$result
}

function Invoke-HarnessJbossOperation {
    param($Context,$Server,[ValidateSet('Status','Start','StartDebug','Stop')][string]$Action)
    $null=[IO.Directory]::CreateDirectory($Server.State)
    try { $lock=[IO.File]::Open((Join-Path $Server.State 'operation.lock'),'OpenOrCreate','ReadWrite','None') } catch { throw 'Outra operacao JBoss esta em andamento.' }
    $id=[guid]::NewGuid().ToString('N')
    $run=Resolve-HarnessPath (Join-Path $Server.State ('operations/'+$id)) $Context.Root
    $result=[ordered]@{RunId=$id;Action=$Action;Eap=$Server.Eap;Home=$Server.Home;Base=$Server.Base;StandaloneConfig=$Server.Settings.standaloneConfig;Source=$Context.Active.path;Project=$Context.Active.name;Status='FAILED';Observed=$null;Error=$null;StartedAtUtc=[DateTime]::UtcNow.ToString('o');FinishedAtUtc=$null;ResultPath=(Join-Path $run 'result.json')}
    try {
        $null=[IO.Directory]::CreateDirectory($run)
        Write-HarnessJson $result.ResultPath $result
        $result.Observed=switch ($Action) {
            Status { Get-HarnessJbossStatus $Server }
            Start { Start-HarnessJboss $Server $run }
            StartDebug { Start-HarnessJboss $Server $run -DebugMode }
            Stop { Stop-HarnessJboss $Server }
        }
        $result.Status='SUCCEEDED'
    } catch { $result.Error=$_.Exception.Message }
    finally {
        $result.FinishedAtUtc=[DateTime]::UtcNow.ToString('o')
        try { Write-HarnessJson $result.ResultPath $result } finally { $lock.Dispose() }
    }
    [pscustomobject]$result
}
Export-ModuleMember -Function Get-HarnessJbossReleases, Invoke-HarnessJbossRelease, Invoke-HarnessJbossOperation
