#requires -Version 5.1
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $root 'scripts/HarnessJbossRuntime.psm1') -Force -DisableNameChecking
function Assert($condition,$message) { if (-not $condition) { throw $message } }
$area=Join-Path $root ('.harness/tests/jboss user '+[guid]::NewGuid().ToString('N'))
$bin=Join-Path $area 'bin'
$null=[IO.Directory]::CreateDirectory($bin)
$launcher=Join-Path $bin 'add-user.bat'
# O assistente ficticio apenas exibe o ambiente; nao recebe nem cria credenciais.
@'
@echo off
echo JDK=%JAVA_HOME%
echo EAP=%JBOSS_HOME%
echo MODULES=%JBOSS_MODULEPATH%
echo OPTIONS=%JAVA_OPTS%
echo TOOL=%JAVA_TOOL_OPTIONS%
echo EXTRA=%*
exit /b 0
'@ | Set-Content -LiteralPath $launcher -Encoding ASCII
$server=[pscustomobject]@{Home=$area;Jdk=(Join-Path $area 'jdk8');Java=(Join-Path $area 'jdk8/bin/java.exe')}
$module=Get-Module HarnessJbossRuntime
& $module {
    $script:version='version "1.8.0_504"'
    function script:Invoke-JbossJava { param($Server,$Arguments) [pscustomobject]@{ExitCode=0;Output=$script:version} }
}
$names=@('JAVA_HOME','JBOSS_HOME','JBOSS_MODULEPATH','JAVA_OPTS','JAVA_TOOL_OPTIONS','_JAVA_OPTIONS','JDK_JAVA_OPTIONS','COMMON_CONF','NOPAUSE')
$previous=@{}
try {
    foreach ($name in $names) {
        $previous[$name]=[Environment]::GetEnvironmentVariable($name,'Process')
        [Environment]::SetEnvironmentVariable($name,('valor-anterior-'+$name),'Process')
    }
    $output=Invoke-HarnessJbossAddUser $server | Out-String
    Assert ($output.Contains('JDK='+$server.Jdk) -and $output.Contains('EAP='+$server.Home)) 'Assistente usou Java ou EAP herdado.'
    Assert ($output.Contains('MODULES='+(Join-Path $server.Home 'modules'))) 'Assistente pode atingir modulos de outro EAP.'
    Assert (-not $output.Contains('valor-anterior-') -and $output -match '(?m)^EXTRA=\s*$') 'Opcoes herdadas ou credenciais repassadas como argumentos.'
    foreach ($name in $names) { Assert ([Environment]::GetEnvironmentVariable($name,'Process') -eq ('valor-anterior-'+$name)) "Ambiente nao restaurado: $name" }
    [IO.File]::WriteAllText($launcher,"@echo off`r`nexit /b 9`r`n")
    $failed=$false
    try { Invoke-HarnessJbossAddUser $server } catch { $failed=$_.Exception.Message -match '9' }
    Assert $failed 'Falha do script foi declarada sucesso.'
    foreach ($name in $names) { Assert ([Environment]::GetEnvironmentVariable($name,'Process') -eq ('valor-anterior-'+$name)) "Falha nao restaurou ambiente: $name" }
    & $module { $script:version='version "25.0.3"' }
    $rejected=$false
    try { Invoke-HarnessJbossAddUser $server } catch { $rejected=$_.Exception.Message -match 'JDK 8' }
    Assert $rejected 'Assistente aceitou Java recente.'
    Assert (-not (Test-Path (Join-Path $area '.harness'))) 'Assistente criou recibo ou log com dados de usuario.'
} finally {
    foreach ($name in $previous.Keys) { [Environment]::SetEnvironmentVariable($name,$previous[$name],'Process') }
}
Write-Output 'PASS: assistente interativo, JDK 8, isolamento EAP, ambiente restaurado e falhas propagadas; nenhum usuario criado.'
