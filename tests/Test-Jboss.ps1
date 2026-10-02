#requires -Version 5.1
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $root 'scripts/HarnessJboss.psm1') -Force -DisableNameChecking
function Assert($condition,$message) { if (-not $condition) { throw $message } }
$area=Join-Path $root ('.harness/tests/jboss-'+[guid]::NewGuid().ToString('N'))
$null=[IO.Directory]::CreateDirectory($area)
$server=[pscustomobject]@{Eap='eap74'; Home='C:\fixture-eap74'; Base='C:\fixture-eap74\standalone'; State=$area; Settings=[pscustomobject]@{timeoutSeconds=10;standaloneConfig='standalone.xml'}}
$context=[pscustomobject]@{Root=$root; Active=[pscustomobject]@{name='app';label='app';path='C:\fixture-app'}}
$module=Get-Module HarnessJboss
& $module {
    $script:deployed=@{}; $script:failDeploy=$false
    function script:Get-HarnessJbossStatus { param($Server) [pscustomobject]@{State='RUNNING';Identity='MATCHED'} }
    function script:Get-JbossDeployment { param($Server,$Name)
        if ($script:deployed.ContainsKey($Name)) { return $script:deployed[$Name] }
        return $null
    }
    function script:Invoke-JbossCli { param($Server,$Command)
        if ($script:failDeploy) { throw 'Falha simulada de deploy' }
        if ($Command -match '^deploy "([^"]+)" --name=([^ ]+) --runtime-name=([^ ]+)') {
            $script:deployed[$Matches[2]]=[pscustomobject]@{Status='OK';Hash=(Get-FileHash -LiteralPath $Matches[1] -Algorithm SHA1).Hash;RuntimeName=$Matches[3]}
        } else { throw "Comando inesperado: $Command" }
    }
}
Add-Type -AssemblyName System.IO.Compression.FileSystem
function New-War([string]$Name,[string]$Content) {
    $folder=Join-Path $area $Name; $null=[IO.Directory]::CreateDirectory($folder)
    [IO.File]::WriteAllText((Join-Path $folder 'index.html'),$Content)
    $path=Join-Path $area ($Name+'.war'); [IO.Compression.ZipFile]::CreateFromDirectory($folder,$path)
    return $path
}
$v1=New-War 'v1' 'release 1'; $v2=New-War 'v2' 'release 2'
$first=Invoke-HarnessJbossRelease $context $server Deploy $v1 'app.war'
Assert ($first.Status -eq 'SUCCEEDED') 'Primeiro deploy falhou.'
$second=Invoke-HarnessJbossRelease $context $server Deploy $v2 'app.war'
Assert ($second.Status -eq 'SUCCEEDED' -and $second.PreviousRelease -eq $first.RunId) 'Substituicao perdeu versao anterior.'
$rollback=Invoke-HarnessJbossRelease $context $server Rollback -DeploymentName 'app.war' -ReleaseId $first.RunId
Assert ($rollback.Status -eq 'SUCCEEDED' -and $rollback.Sha256 -eq $first.Sha256) 'Rollback nao restaurou release selecionada.'
Assert ((Get-FileHash $v1).Hash -eq $first.Sha256) 'Artefato original alterado.'
& $module { $script:failDeploy=$true }
$failed=Invoke-HarnessJbossRelease $context $server Deploy $v2 'app.war'
Assert ($failed.Status -eq 'FAILED') 'Falha foi declarada sucesso.'
& $module { $script:failDeploy=$false }
$history=@(Get-HarnessJbossReleases $context $server 'app.war')
Assert ($history.Count -eq 3) 'Historico deve incluir somente sucessos.'
$pointer=Get-Content (Join-Path $area 'deployments/app.war.json') -Raw | ConvertFrom-Json
Assert ($pointer.RunId -eq $rollback.RunId) 'Falha alterou ponteiro do ultimo sucesso.'
[IO.File]::WriteAllText((Join-Path $area ('releases/'+$first.RunId+'/app.war')),'adulterado')
$tampered=Invoke-HarnessJbossRelease $context $server Rollback -DeploymentName 'app.war' -ReleaseId $first.RunId
Assert ($tampered.Status -eq 'FAILED' -and $tampered.Error -match 'adulterado') 'Rollback aceitou snapshot adulterado.'
$lease=[IO.File]::Open((Join-Path $area 'operation.lock'),'OpenOrCreate','ReadWrite','None')
try {
    $concurrent=Invoke-HarnessJbossRelease $context $server Deploy $v2 'app.war'
    Assert ($concurrent.Status -eq 'FAILED' -and $concurrent.Error -match 'andamento') 'Operacoes simultaneas nao foram impedidas.'
} finally {$lease.Dispose()}
& $module { $script:deployed['app.war'].Hash='externo' }
$diverged=Invoke-HarnessJbossRelease $context $server Deploy $v2 'app.war'
Assert ($diverged.Status -eq 'FAILED' -and $diverged.Error -match 'diverg') 'Deploy externo divergente nao foi protegido.'
$foreignContext=[pscustomobject]@{Root=$root;Active=[pscustomobject]@{name='outro';label='outro';path='C:\outro'}}
$rejected=Invoke-HarnessJbossRelease $foreignContext $server Rollback -DeploymentName 'app.war' -ReleaseId $first.RunId
Assert ($rejected.Status -eq 'FAILED') 'Rollback de outro projeto aceito.'
$invalid=Invoke-HarnessJbossRelease $context $server Deploy $v1 '../app.war'
Assert ($invalid.Status -eq 'FAILED') 'Nome inseguro aceito.'
& $module { $script:deployed['externo.war']=[pscustomobject]@{Status='OK';RuntimeName='externo.war';Hash='nao-gerenciado'} }
$unmanaged=Invoke-HarnessJbossRelease $context $server Deploy $v1 'externo.war'
Assert ($unmanaged.Status -eq 'FAILED' -and $unmanaged.Error -match 'sem release gerenciada') 'Deployment nao gerenciado sobrescrito.'
Write-Output 'PASS: deploy, rollback, falha, historico e isolamento por projeto/servidor/conteudo.'
