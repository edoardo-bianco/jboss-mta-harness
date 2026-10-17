#requires -Version 5.1
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $root 'scripts/HarnessJboss.psm1') -Force -DisableNameChecking
function Assert($condition,$message) { if (-not $condition) { throw $message } }
$area=Join-Path $root ('.harness/tests/jboss com espacos-'+[guid]::NewGuid().ToString('N'))
$source=Join-Path $area 'fonte app'
$null=[IO.Directory]::CreateDirectory($source)
Set-Content -LiteralPath (Join-Path $source 'pom.xml') -Value '<project><artifactId>app</artifactId><packaging>war</packaging></project>' -Encoding UTF8
$state=Join-Path $area '.harness/servidores/eap74'
$server=[pscustomobject]@{Eap='eap74'; Home='C:\fixture-eap74'; Base='C:\fixture-eap74\standalone'; State=$state; Settings=[pscustomobject]@{timeoutSeconds=10;standaloneConfig='standalone.xml'}}
$context=[pscustomobject]@{Root=$area; Active=[pscustomobject]@{name='app';label='app';path=$source}}
$module=Get-Module HarnessJboss
& $module {
    $script:deployed=@{}; $script:unmanaged=@{}; $script:failDeploy=$false; $script:writeBlocked=$null; $script:commands=@()
    function script:Get-HarnessJbossStatus { param($Server) [pscustomobject]@{State='RUNNING';Identity='MATCHED'} }
    function script:Get-JbossDeployment { param($Server,$Name)
        if ($script:unmanaged.ContainsKey($Name)) { throw 'Deployment existente nao e um unico arquivo gerenciado.' }
        if ($script:deployed.ContainsKey($Name)) { return $script:deployed[$Name] }
        return $null
    }
    function script:Invoke-JbossCli { param($Server,$Command)
        $script:commands+=$Command
        if ($script:failDeploy) { throw 'Falha simulada de deploy' }
        if ($Command -match '^deploy "([^"]+)" --name=([^ ]+) --runtime-name=([^ ]+)') {
            $path=$Matches[1]; $name=$Matches[2]; $runtimeName=$Matches[3]
            # Mesmo criterio de raiz de WindowsFilenameTabCompleter da CLI antiga:
            # C:/... recebe Home como prefixo, embora o .NET aceite esse formato.
            if (-not $path.Contains(':\') -and -not $path.StartsWith('\\')) { $path=$Server.Home+'\'+$path }
            if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Path $path doesn't exist." }
            if ($script:deployed.ContainsKey($name) -or $script:unmanaged.ContainsKey($name)) {
                if ($Command -notmatch ' --force$') { throw 'Duplicate resource: deployment ja existe.' }
            }
            try { ([IO.File]::Open($path,'Open','ReadWrite','ReadWrite')).Dispose(); $script:writeBlocked=$false } catch { $script:writeBlocked=$true }
            $script:unmanaged.Remove($name)
            $script:deployed[$name]=[pscustomobject]@{Status='OK';Hash=(Get-FileHash -LiteralPath $path -Algorithm SHA1).Hash;RuntimeName=$runtimeName}
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
function Read-LastDeploy { Get-Content -LiteralPath (Join-Path $area '.harness/projetos/app/atual/jboss/eap74/ultimo-deploy.json') -Raw | ConvertFrom-Json }
function Read-Operations { Get-Content -LiteralPath (Join-Path $area '.harness/projetos/app/atual/operacao.json') -Raw | ConvertFrom-Json }
$v1=New-War 'v1' 'release 1'; $v2=New-War 'v2' 'release 2'
$v1Sha1=(Get-FileHash $v1 -Algorithm SHA1).Hash; $v2Sha1=(Get-FileHash $v2 -Algorithm SHA1).Hash

$first=Invoke-HarnessJbossDeploy $context $server $v1 'app.war'
Assert ($first.Status -eq 'SUCCEEDED' -and -not $first.Replaced) ('Primeiro deploy falhou: '+$first.Error)
Assert ((& $module { $script:writeBlocked }) -eq $true) 'Artefato deve ficar protegido contra escrita durante o envio.'
Assert ((Read-LastDeploy).Sha256 -eq (Get-FileHash $v1).Hash) 'Resultado corrente nao registrou o primeiro deploy.'

$second=Invoke-HarnessJbossDeploy $context $server $v2 'app.war'
Assert ($second.Status -eq 'SUCCEEDED' -and $second.Replaced -and $second.ReplacedSha1 -eq $v1Sha1) 'Segundo deploy deve substituir o WAR implantado.'
Assert ((& $module { $script:commands[-1] }) -match ' --force$') 'Substituicao deve usar --force.'
$deployFolder=Join-Path $area '.harness/projetos/app/atual/jboss/eap74'
Assert (@(Get-ChildItem -LiteralPath $deployFolder -Force).Name -join ',' -eq 'ultimo-deploy.json') 'Somente o ultimo deploy deve ser guardado, sem copias de WAR ou historico.'
Assert ((Read-LastDeploy).Sha1 -eq $v2Sha1 -and (Read-Operations).'jboss-eap74'.Status -eq 'SUCCEEDED') 'Resultado/operacao corrente nao foram substituidos.'

# Reverter e fazer deploy do WAR anterior escolhido pelo desenvolvedor.
$revert=Invoke-HarnessJbossDeploy $context $server $v1 'app.war'
Assert ($revert.Status -eq 'SUCCEEDED' -and (& $module { $script:deployed['app.war'].Hash }) -eq $v1Sha1) 'Deploy do WAR anterior deve reverter a aplicacao.'
Assert ((Get-FileHash $v1 -Algorithm SHA1).Hash -eq $v1Sha1) 'Artefato original alterado.'

& $module { $script:deployed['app.war'].Hash='externo' }
$external=Invoke-HarnessJbossDeploy $context $server $v2 'app.war'
Assert ($external.Status -eq 'SUCCEEDED' -and $external.Replaced -and $external.ReplacedSha1 -eq 'externo') 'Deployment alterado externamente deve ser substituido.'

& $module { $script:unmanaged['externo.war']=$true }
$unmanaged=Invoke-HarnessJbossDeploy $context $server $v1 'externo.war'
Assert ($unmanaged.Status -eq 'SUCCEEDED' -and $unmanaged.Replaced) ('Deployment nao gerenciado deve ser substituido: '+$unmanaged.Error)

& $module { $script:failDeploy=$true }
$failed=Invoke-HarnessJbossDeploy $context $server $v2 'app.war'
& $module { $script:failDeploy=$false }
Assert ($failed.Status -eq 'FAILED') 'Falha foi declarada sucesso.'
Assert ((Read-LastDeploy).Status -eq 'FAILED' -and (Read-Operations).'jboss-eap74'.Status -eq 'FAILED') 'Ultima tentativa deve registrar a falha.'

$null=[IO.Directory]::CreateDirectory($state)
$lease=[IO.File]::Open((Join-Path $state 'operation.lock'),'OpenOrCreate','ReadWrite','None')
try {
    $concurrent=Invoke-HarnessJbossDeploy $context $server $v2 'app.war'
    Assert ($concurrent.Status -eq 'FAILED' -and $concurrent.Error -match 'andamento') 'Operacoes simultaneas nao foram impedidas.'
} finally {$lease.Dispose()}
$invalid=Invoke-HarnessJbossDeploy $context $server $v1 '../app.war'
Assert ($invalid.Status -eq 'FAILED') 'Nome inseguro aceito.'

$identified=@(Get-ChildItem -LiteralPath (Join-Path $area '.harness') -Recurse -Force | Where-Object { $_.Name -match '[0-9a-f]{32}' -or $_.Name -in @('releases','deployments','operations') })
Assert ($identified.Count -eq 0) ('Pastas/arquivos nomeados por identificador ou historico: '+(($identified | ForEach-Object FullName) -join ', '))
Assert (-not (Test-Path -LiteralPath (Join-Path $area '.harness/jboss'))) 'Area legada nao deve ser criada.'
Write-Output 'PASS: deploy substitui WAR (gerenciado, externo e nao gerenciado), revert por novo deploy, somente o ultimo, falha, concorrencia e nomes legiveis.'
