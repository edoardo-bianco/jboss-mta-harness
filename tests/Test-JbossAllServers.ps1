#requires -Version 5.1
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
function Assert($condition,$message) { if (-not $condition) { throw $message } }
$area=Join-Path $root ('.harness/tests/jboss all '+[guid]::NewGuid().ToString('N'))
$scripts=Join-Path $area 'scripts'
$null=[IO.Directory]::CreateDirectory($scripts)
# Copias sao fixtures: a entrada e os recibos reais ficam isolados do ambiente local.
Copy-Item -Path (Join-Path $root 'scripts/*.psm1') -Destination $scripts
Copy-Item -LiteralPath (Join-Path $root 'scripts/gerenciar-jboss.ps1') -Destination $scripts
$configPath=Join-Path $area 'config.json'
$jdk=Join-Path $area 'jdk8'
$null=[IO.Directory]::CreateDirectory((Join-Path $jdk 'bin'))
[IO.File]::WriteAllText((Join-Path $jdk 'bin/java.exe'),'fixture; nao executar')
$config=@{schemaVersion=1;tools=@{applicationJdk8Home=$jdk};repositories=@();activeProject='ausente'}
foreach ($eap in @('eap71','eap74')) {
    $eapHome=Join-Path $area $eap
    foreach ($folder in @('bin/client','standalone/configuration')) { $null=[IO.Directory]::CreateDirectory((Join-Path $eapHome $folder)) }
    foreach ($file in @('bin/client/jboss-cli-client.jar','bin/standalone.bat','standalone/configuration/standalone.xml')) {
        [IO.File]::WriteAllText((Join-Path $eapHome $file),'fixture; nao executar')
    }
    $version=if ($eap -eq 'eap71') {'7.0'} else {'7.4'}
    [IO.File]::WriteAllText((Join-Path $eapHome 'version.txt'),"Version $version.0.GA")
    $config.tools[$eap+'Home']=$eapHome
}
$config | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $configPath -Encoding UTF8
$runner=Join-Path $area 'runner.ps1'
@'
param([string]$Eap,[string]$Action,[switch]$SelectStartMode,[string]$FailEap)
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'scripts/HarnessJboss.psm1') -DisableNameChecking
$module=Get-Module HarnessJboss
& $module {
    param($FailEap)
    $script:failEap=$FailEap
    function script:Get-HarnessJbossStatus {
        param($Server)
        if ($Server.Eap -eq $script:failEap) { throw "Falha simulada em $($Server.Eap)" }
        [pscustomobject]@{State='RUNNING';Identity='MATCHED';Debug=$false}
    }
    function script:Start-HarnessJboss {
        param($Server,$Run,[switch]$DebugMode)
        $state=Get-HarnessJbossStatus $Server
        $state.Debug=[bool]$DebugMode
        $state
    }
    function script:Stop-HarnessJboss {
        param($Server)
        $state=Get-HarnessJbossStatus $Server
        $state.State='STOPPED'
        $state
    }
} $FailEap
$arguments=@{ConfigPath=(Join-Path $PSScriptRoot 'config.json')}
if ($Eap) { $arguments.Eap=$Eap }
if ($Action) { $arguments.Action=$Action }
if ($SelectStartMode) { $arguments.SelectStartMode=$true }
try { & (Join-Path $PSScriptRoot 'scripts/gerenciar-jboss.ps1') @arguments }
catch { Write-Output $_.Exception.Message; exit 1 }
exit $LASTEXITCODE
'@ | Set-Content -LiteralPath $runner -Encoding UTF8
function Get-Receipts {
    @(Get-ChildItem -LiteralPath (Join-Path $area '.harness/jboss') -Filter result.json -Recurse -ErrorAction SilentlyContinue |
        ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw | ConvertFrom-Json })
}
function Invoke-Entry {
    param([string[]]$Arguments,[string[]]$Answers=@('q'))
    $previous=@(Get-Receipts | ForEach-Object RunId)
    $output=$Answers | & powershell.exe -NoProfile -File $runner @Arguments 2>&1 | Out-String
    $exitCode=$LASTEXITCODE
    [pscustomobject]@{ExitCode=$exitCode;Output=$output;Receipts=@(Get-Receipts | Where-Object RunId -notin $previous)}
}
foreach ($action in @('Status','Start','StartDebug','Stop')) {
    $result=Invoke-Entry -Arguments @('-Eap','all','-Action',$action)
    Assert ($result.ExitCode -eq 0 -and $result.Receipts.Count -eq 2) "Todos deve executar ambos: $action. $($result.Output)"
    Assert (($result.Receipts.Eap | Sort-Object) -join ',' -eq 'eap71,eap74') 'Recibos devem identificar cada EAP.'
    foreach ($receipt in $result.Receipts) {
        Assert ($receipt.Status -eq 'SUCCEEDED' -and $receipt.Action -eq $action -and $receipt.Scope -eq 'Server' -and $null -eq $receipt.Source) 'Resultado/escopo incorreto.'
        if ($action -eq 'StartDebug') { Assert $receipt.Observed.Debug 'Todos perdeu modo debug.' }
        if ($action -eq 'Stop') { Assert ($receipt.Observed.State -eq 'STOPPED') 'Todos nao parou o servidor.' }
    }
    Assert ($result.Output.Contains('Resumo por servidor') -and $result.Output.Contains('eap71') -and $result.Output.Contains('eap74')) 'Falta resumo dos resultados.'
    Assert ($result.Output.Contains('EAP detectado: 7.0') -and $result.Output.Contains('EAP detectado: 7.4')) 'Saida deve distinguir chave legada da versao instalada.'
}
foreach ($action in @('Status','Stop')) {
    $result=Invoke-Entry -Arguments @('-Action',$action) -Answers @('3')
    Assert ($result.ExitCode -eq 0 -and $result.Receipts.Count -eq 2 -and $result.Output.Contains('3. Todos')) 'Menu nao oferece/executa Todos.'
}
foreach ($mode in @('1','2')) {
    $result=Invoke-Entry -Arguments @('-SelectStartMode') -Answers @($mode,'3')
    $expected=if ($mode -eq '1') {'Start'} else {'StartDebug'}
    Assert ($result.ExitCode -eq 0 -and $result.Receipts.Count -eq 2 -and @($result.Receipts | Where-Object Action -ne $expected).Count -eq 0) 'Menu de start perdeu modo ou selecao Todos.'
}
foreach ($failedEap in @('eap71','eap74')) {
    $result=Invoke-Entry -Arguments @('-Eap','all','-Action','Stop','-FailEap',$failedEap)
    Assert ($result.ExitCode -eq 1 -and $result.Receipts.Count -eq 2) 'Falha parcial deve tentar ambos e retornar erro.'
    Assert (@($result.Receipts | Where-Object Status -eq 'SUCCEEDED').Count -eq 1 -and @($result.Receipts | Where-Object Status -eq 'FAILED').Count -eq 1) 'Falha parcial ocultada ou sucesso desfeito.'
}
[IO.File]::WriteAllText((Join-Path $area 'eap71/version.txt'),'Version invalida')
$result=Invoke-Entry -Arguments @('-Eap','all','-Action','Status')
Assert ($result.ExitCode -eq 1 -and $result.Receipts.Count -eq 1 -and $result.Receipts[0].Eap -eq 'eap74') 'Configuracao invalida de um EAP impediu processar o outro.'
Assert ($result.Output.Contains('eap71') -and $result.Output.Contains('FAILED')) 'Falha anterior ao recibo deve aparecer no resultado.'
[IO.File]::WriteAllText((Join-Path $area 'eap71/version.txt'),'Version 7.0.0.GA')
foreach ($eap in @('eap71','eap74')) {
    $result=Invoke-Entry -Arguments @('-Eap',$eap,'-Action','Status')
    Assert ($result.ExitCode -eq 0 -and $result.Receipts.Count -eq 1 -and $result.Receipts[0].Eap -eq $eap) 'Selecao individual regrediu.'
}
foreach ($action in @('Status','Start','StartDebug','Stop')) {
    $result=Invoke-Entry -Arguments @('-Action',$action) -Answers @('q')
    Assert ($result.ExitCode -eq 1 -and $result.Receipts.Count -eq 0 -and $result.Output.Contains('Selecao cancelada')) 'Cancelar deve encerrar sem operacao.'
}
foreach ($action in @('AddUser','Deploy','Rollback')) {
    $result=Invoke-Entry -Arguments @('-Eap','all','-Action',$action)
    Assert ($result.ExitCode -eq 1 -and $result.Receipts.Count -eq 0 -and $result.Output.Contains('Todos so se aplica')) 'Todos deve recusar usuario/deploy/rollback antes de qualquer interacao.'
    $result=Invoke-Entry -Arguments @('-Action',$action) -Answers @('3')
    Assert ($result.ExitCode -eq 1 -and -not $result.Output.Contains('3. Todos')) 'Menu nao deve oferecer Todos para usuario/deploy/rollback.'
}
Assert (-not (Test-Path (Join-Path $area '.harness/projetos'))) 'Operacoes de servidor criaram registro de aplicacao.'
Write-Output 'PASS: Todos via CLI/menu, modos, recibos individuais, falha parcial, configuracao invalida, cancelamento e selecao individual; runtime simulado.'
