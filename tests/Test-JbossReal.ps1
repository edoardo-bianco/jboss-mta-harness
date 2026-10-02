#requires -Version 5.1
[CmdletBinding()]
param([switch]$RunReal,[ValidateSet('eap71','eap74')][string]$Eap='eap74')
$ErrorActionPreference='Stop'
if (-not $RunReal) { Write-Output 'SKIP: use -RunReal para ensaio local com JBoss/JDK configurados e base isolada.'; exit 0 }
$root=Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $root 'scripts/Harness.psm1') -DisableNameChecking
Import-Module (Join-Path $root 'scripts/HarnessJbossRuntime.psm1') -DisableNameChecking
Import-Module (Join-Path $root 'scripts/HarnessJboss.psm1') -DisableNameChecking
function Assert($condition,$message) { if (-not $condition) { throw $message } }
$context=Read-HarnessConfig (Join-Path $root 'config/harness.local.json') $root -SkipMigrationInitialization
$server=Get-HarnessJbossServer $context $Eap
$area=Join-Path $root ('.harness/tests/jboss-real-'+[guid]::NewGuid().ToString('N'))
$configuration=Join-Path $area 'base/configuration'
$null=[IO.Directory]::CreateDirectory($configuration)
foreach ($file in Get-ChildItem -LiteralPath (Join-Path $server.Base 'configuration') -File) {
    if ($file.Extension -in @('.xml','.properties')) { Copy-Item -LiteralPath $file.FullName -Destination $configuration }
}
$server.Base=Join-Path $area 'base'; $server.State=Join-Path $area 'history'
$server.Settings.portOffset=200; $server.ManagementPort=10190; $server.HttpPort=8280; $server.Settings.debugPort=8790
$context.Active=[pscustomobject]@{name='jboss-smoke';label='JBoss smoke';path=$area}
$configHash=(Get-FileHash (Join-Path $server.Home 'standalone/configuration/standalone.xml')).Hash
Add-Type -AssemblyName System.IO.Compression.FileSystem
$started=$false
try {
    $before=Get-HarnessJbossStatus $server
    Assert ($before.State -eq 'STOPPED') 'Ensaio exige portas livres e servidor selecionado parado.'
    $started=$true
    $start=Invoke-HarnessJbossOperation $context $server StartDebug
    $start | ConvertTo-Json -Depth 8 | Write-Host
    Assert ($start.Status -eq 'SUCCEEDED' -and $start.Observed.Debug) "Start debug falhou: $($start.Error)"
    # Confirmar protocolo JDWP sem depender da extensao VS Code.
    $client=New-Object Net.Sockets.TcpClient
    try {
        $client.Connect('127.0.0.1',$server.Settings.debugPort)
        $stream=$client.GetStream();$stream.ReadTimeout=5000
        $handshake=[Text.Encoding]::ASCII.GetBytes('JDWP-Handshake')
        $stream.Write($handshake,0,$handshake.Length)
        $reply=New-Object byte[] $handshake.Length; $offset=0
        while ($offset -lt $reply.Length) { $count=$stream.Read($reply,$offset,$reply.Length-$offset); if (-not $count) {throw 'JDWP encerrou conexao.'};$offset+=$count }
        Assert ([Text.Encoding]::ASCII.GetString($reply) -eq 'JDWP-Handshake') 'Handshake debug invalido.'
    } finally { $client.Dispose() }
    $releases=@()
    foreach ($version in @('v1','v2')) {
        $content=Join-Path $area $version;$null=[IO.Directory]::CreateDirectory($content)
        [IO.File]::WriteAllText((Join-Path $content 'index.html'),$version)
        $war=Join-Path $area ($version+'.war');[IO.Compression.ZipFile]::CreateFromDirectory($content,$war)
        $release=Invoke-HarnessJbossRelease $context $server Deploy $war 'harness-smoke.war'
        $release | ConvertTo-Json -Depth 5 | Write-Host
        Assert ($release.Status -eq 'SUCCEEDED') "Deploy falhou: $($release.Error)"
        $releases+=$release
        $http=Invoke-WebRequest "http://127.0.0.1:$($server.HttpPort)/harness-smoke/index.html" -UseBasicParsing
        Assert ($http.Content.Trim() -eq $version) 'HTTP nao corresponde ao artefato implantado.'
    }
    $rollback=Invoke-HarnessJbossRelease $context $server Rollback -DeploymentName 'harness-smoke.war' -ReleaseId $releases[0].RunId
    Assert ($rollback.Status -eq 'SUCCEEDED') "Rollback falhou: $($rollback.Error)"
    $http=Invoke-WebRequest "http://127.0.0.1:$($server.HttpPort)/harness-smoke/index.html" -UseBasicParsing
    Assert ($http.Content.Trim() -eq 'v1') 'Rollback nao restaurou resposta HTTP v1.'
} finally {
    if ($started) {
        $stop=Invoke-HarnessJbossOperation $context $server Stop
        $stop | ConvertTo-Json -Depth 8 | Write-Host
        Assert ($stop.Status -eq 'SUCCEEDED' -and $stop.Observed.State -eq 'STOPPED') "Stop nao confirmado: $($stop.Error)"
    }
    Assert ((Get-FileHash (Join-Path $server.Home 'standalone/configuration/standalone.xml')).Hash -eq $configHash) 'XML original alterado.'
}
Write-Output "PASS: $Eap start/debug JDWP, deploy v1/v2 HTTP, rollback HTTP v1, stop e XML original preservado. Evidencias: $area"
