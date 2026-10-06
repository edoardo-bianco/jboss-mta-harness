#requires -Version 5.1
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $root 'scripts/HarnessJbossRuntime.psm1') -Force -DisableNameChecking
function Assert($condition,$message) { if (-not $condition) { throw $message } }
function Reject($action,$message) { $failed=$false; try { & $action | Out-Null } catch { $failed=$true }; Assert $failed $message }
$area=Join-Path $root ('.harness/tests/versions-'+[guid]::NewGuid().ToString('N').Substring(0,8))
$eapHome=Join-Path $area 'j-boss-eap-7.0'
$jdk=Join-Path $area 'jdk8'
foreach ($path in @('bin/client/jboss-cli-client.jar','bin/standalone.bat','standalone/configuration/standalone.xml')) {
    $dest=Join-Path $eapHome $path; $null=[IO.Directory]::CreateDirectory((Split-Path $dest -Parent)); Set-Content -LiteralPath $dest 'fixture; nao executar'
}
$null=[IO.Directory]::CreateDirectory((Join-Path $jdk 'bin'))
Set-Content -LiteralPath (Join-Path $jdk 'bin/java.exe') 'fixture; nao executar'
$context=[pscustomobject]@{Root=$area;Config=[pscustomobject]@{tools=[pscustomobject]@{applicationJdk8Home=$jdk;eap71Home=$eapHome;eap74Home=$eapHome}}}
$versionFile=Join-Path $eapHome 'version.txt'
foreach ($version in @('7.0','7.1')) {
    Set-Content -LiteralPath $versionFile "Red Hat JBoss Enterprise Application Platform - Version $version.0.GA"
    $server=Get-HarnessJbossServer $context eap71
    Assert ($server.Version -eq $version -and $server.Eap -eq 'eap71' -and $server.Home -eq $eapHome) 'eap71 deve preservar chave e detectar versao instalada.'
    Reject { Get-HarnessJbossServer $context eap74 } 'eap74 aceitou instalacao legada.'
}
Set-Content -LiteralPath $versionFile 'Red Hat JBoss Enterprise Application Platform - Version 7.4.23.GA'
Assert ((Get-HarnessJbossServer $context eap74).Version -eq '7.4') 'EAP 7.4 sofreu regressao.'
Reject { Get-HarnessJbossServer $context eap71 } 'eap71 aceitou EAP 7.4.'
foreach ($version in @('7.2.0.GA','7.3.0.GA','17.0.0.GA','7.10.0.GA','8.0.0.GA','invalida')) {
    Set-Content -LiteralPath $versionFile "Version $version"
    Reject { Get-HarnessJbossServer $context eap71 } "eap71 aceitou $version."
    Reject { Get-HarnessJbossServer $context eap74 } "eap74 aceitou $version."
}
Assert (-not (Test-Path (Join-Path $area '.harness'))) 'Leitura de versao criou estado.'
Write-Output 'PASS: eap71 aceita 7.0/7.1; eap74 exige 7.4; versao real e caminhos preservados.'
