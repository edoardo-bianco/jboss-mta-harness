#requires -Version 5.1
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $root 'scripts/HarnessJbossRuntime.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $root 'scripts/HarnessJboss.psm1') -Force -DisableNameChecking
function Assert($condition,$message) { if (-not $condition) { throw $message } }
$area=Join-Path $root ('.harness/tests/jboss-server-'+[guid]::NewGuid().ToString('N'))
$null=[IO.Directory]::CreateDirectory($area)
$configPath=Join-Path $area 'config.json'
# Projetos antigos/indisponiveis e MTA invalido nao pertencem ao controle do servidor.
@{schemaVersion=1;tools=@{applicationJdk8Home='jdk';eap71Home='eap71';eap74Home='eap74'};
    activeProject='ausente';repositories=@(@{name='ausente';path='nao-existe'});mta=@{profile='invalido'}} |
    ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $configPath -Encoding UTF8
$before=(Get-FileHash $configPath).Hash
$context=Read-HarnessJbossContext $configPath $area
Assert ($null -eq $context.Active) 'Contexto de servidor nao deve selecionar aplicacao.'
Assert (-not (Test-Path (Join-Path $area '.harness/projetos'))) 'Controle de servidor criou registros de aplicacao.'
Assert ((Get-FileHash $configPath).Hash -eq $before) 'Leitura alterou configuracao.'
$module=Get-Module HarnessJboss
& $module {
    function script:Get-HarnessJbossStatus { param($Server) [pscustomobject]@{State='RUNNING';Identity='MATCHED';Debug=$false} }
    function script:Start-HarnessJboss { param($Server,$Run,[switch]$DebugMode) [pscustomobject]@{State='RUNNING';Identity='MATCHED';Debug=[bool]$DebugMode} }
    function script:Stop-HarnessJboss { param($Server) [pscustomobject]@{State='STOPPED'} }
}
foreach ($eap in @('eap71','eap74')) {
    $server=[pscustomobject]@{Eap=$eap;Home=(Join-Path $area $eap);Base=(Join-Path $area "$eap/standalone");
        State=(Join-Path $area "operations-$eap");Settings=[pscustomobject]@{standaloneConfig='standalone.xml'}}
    foreach ($action in @('Status','Start','StartDebug','Stop')) {
        $result=Invoke-HarnessJbossOperation $context $server $action
        Assert ($result.Status -eq 'SUCCEEDED' -and $result.Eap -eq $eap) "Operacao sem app falhou: $eap/$action"
        $receipt=Get-Content -LiteralPath $result.ResultPath -Raw | ConvertFrom-Json
        Assert ($receipt.Scope -eq 'Server' -and $null -eq $receipt.Project -and $null -eq $receipt.Source) 'Recibo atribuiu servidor a aplicacao.'
        if ($action -eq 'StartDebug') { Assert $receipt.Observed.Debug 'Modo debug perdido.' }
    }
}
foreach ($arguments in @(@('-Action','Start'),@('-SelectStartMode'))) {
    $output='q' | & powershell.exe -NoProfile -File (Join-Path $root 'scripts/gerenciar-jboss.ps1') -ConfigPath $configPath @arguments 2>&1 | Out-String
    Assert ($LASTEXITCODE -eq 1 -and $output.Contains('Selecao cancelada')) 'Cancelamento deve encerrar antes de executar operacoes.'
    Assert (-not $output.Contains('Escolha o projeto Maven') -and -not $output.Contains('Pasta ausente')) 'Operacao de servidor pediu aplicacao.'
}
Assert (-not (Test-Path (Join-Path $area '.harness/projetos'))) 'Entrada real criou registro de migracao.'
foreach ($action in @('Status','Start','StartDebug','Stop')) {
    # Instalacoes ficticias: a entrada deve chegar a validacao do servidor, sem
    # consultar projeto/workspace antigos nem executar Java.
    $output=& powershell.exe -NoProfile -File (Join-Path $root 'scripts/gerenciar-jboss.ps1') -ConfigPath $configPath -Eap eap71 -Action $action -WorkspacePath 'workspace-ausente' -SelectTarget 2>&1 | Out-String
    Assert ($LASTEXITCODE -eq 1 -and $output.Contains('Arquivo ausente:')) "Entrada nao validou o servidor sem aplicacao: $action"
    Assert (-not $output.Contains('Escolha o projeto Maven') -and -not $output.Contains('Pasta ausente')) 'Entrada consultou aplicacao ou workspace.'
}
Write-Output 'PASS: operacoes JBoss sem aplicacao, recibos por servidor, debug e cancelamento sem mutacao.'
