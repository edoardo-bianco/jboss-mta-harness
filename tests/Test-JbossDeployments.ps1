#requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $root 'scripts/HarnessJboss.psm1') -Force -DisableNameChecking
$module=Get-Module HarnessJboss
function Assert($condition,$message) { if (-not $condition) { throw $message } }
$area=Join-Path $root ('.harness/tests/deployments-'+[guid]::NewGuid().ToString('N'))
$server=[pscustomobject]@{Eap='eap74';Home=$area;Base=(Join-Path $area 'standalone');State=(Join-Path $area 'state');ManagementPort=10090;Settings=@{standaloneConfig='standalone.xml'}}
$context=[pscustomobject]@{Root=$area;Active=$null}
& $module {
    $script:names=@('simtr-api.war','outra app.ear'); $script:commands=@(); $script:answers=@()
    $script:state='RUNNING'; $script:mode='NORMAL'; $script:identity='MATCHED'
    $script:failName=''; $script:keepName=''; $script:badList=$false; $script:startCalls=0
    function script:Get-HarnessJbossStatus($Server) {
        [pscustomobject]@{State=$script:state;Identity=$script:identity;RunningMode=$script:mode}
    }
    function script:Invoke-JbossCli($Server,$Command) {
        $script:commands+=$Command
        if ($Command -eq 'deployment-info') { return 'NAME RUNTIME-NAME ENABLED STATUS' }
        if ($Command -eq ':read-children-names(child-type=deployment)') {
            if ($script:badList) { return '{"outcome" => "success", "result" => undefined}' }
            return ('{"outcome" => "success", "result" => '+(ConvertTo-Json -InputObject @($script:names) -Compress)+'}')
        }
        if ($Command -match '^undeploy "([^"]+)"$') {
            $name=$Matches[1]
            # O lock de servidor deve abranger cada remocao e sua verificacao.
            try { $other=[IO.File]::Open((Join-Path $Server.State 'operation.lock'),'OpenOrCreate','ReadWrite','None') }
            catch { $other=$null }
            if ($other) { $other.Dispose(); throw 'Undeploy sem lock.' }
            if ($name -ceq $script:failName) { throw 'Falha simulada de undeploy.' }
            if ($name -cne $script:keepName) { $script:names=@($script:names | Where-Object {$_ -cne $name}) }
            return ''
        }
        throw "Comando inesperado: $Command"
    }
    function script:Read-Host($Prompt) {
        if (-not $script:answers.Count) { throw 'Menu pediu resposta inesperada.' }
        $answer=$script:answers[0]; $script:answers=@($script:answers | Select-Object -Skip 1)
        return $answer
    }
    function script:Start-HarnessJboss($Server,$Run,[switch]$AdminOnly) {
        if (-not $AdminOnly) { throw 'Menu tentou iniciar aplicacoes.' }
        $script:startCalls++; $script:state='RUNNING'; $script:mode='ADMIN_ONLY'
        Get-HarnessJbossStatus $Server
    }
}
$view=Get-HarnessJbossDeployments $server
Assert ($view.Names.Count -eq 2 -and $view.Info.Contains('NAME')) 'Consulta deve mostrar deployment-info e nomes reais, inclusive com espaco.'
$single=Invoke-HarnessJbossUndeploy $server @('outra app.ear')
Assert ($single.Status -eq 'SUCCEEDED' -and $single.Removed.Count -eq 1) 'Undeploy individual falhou.'
Assert ((@(& $module {$script:names}) -join ',') -ceq 'simtr-api.war') 'Remocao individual atingiu outra aplicacao.'
$receipt=Get-Content (Join-Path $server.State 'ultima-operacao.json') -Raw | ConvertFrom-Json
Assert ($receipt.Action -eq 'Undeploy' -and $receipt.Status -eq 'SUCCEEDED') 'Resultado de servidor ausente.'
foreach ($answer in @('0','q','')) {
    & $module {param($a) $script:answers=@($a);$script:commands=@()} $answer
    $result=Invoke-HarnessJbossDeploymentMenu $context $server
    Assert ($result.Status -eq 'CANCELLED' -and -not (@(& $module {$script:commands}) -like 'undeploy *')) 'Sair removeu aplicacao.'
}
& $module {$script:names=@();$script:answers=@()}
$empty=Invoke-HarnessJbossDeploymentMenu $context $server
Assert ($empty.Status -eq 'CANCELLED') 'Lista vazia deve sair sem pedir remocao.'
& $module {$script:names=@('a.war','b.ear');$script:answers=@('2','99','2')}
$selected=Invoke-HarnessJbossDeploymentMenu $context $server
Assert ($selected.Status -eq 'SUCCEEDED' -and (@(& $module {$script:names}) -join ',') -ceq 'a.war') 'Selecao invalida nao deve remover; escolha numerica deve usar o nome listado.'
& $module {$script:names=@('a.war','b.ear');$script:answers=@('1')}
$all=Invoke-HarnessJbossDeploymentMenu $context $server
Assert ($all.Status -eq 'SUCCEEDED' -and @(& $module {$script:names}).Count -eq 0) 'Opcao todos nao removeu a lista.'
Assert (-not (@(& $module {$script:commands}) -contains 'undeploy *')) 'Nao remover deployments novos por wildcard.'
& $module {$script:names=@('a.war','b.ear');$script:failName='b.ear'}
$partial=Invoke-HarnessJbossUndeploy $server @('a.war','b.ear')
Assert ($partial.Status -eq 'FAILED' -and $partial.Removed.Count -eq 1 -and $partial.Removed[0] -ceq 'a.war') 'Falha parcial nao pode virar sucesso ou perder removidos.'
& $module {$script:failName='';$script:keepName='b.ear'}
$unconfirmed=Invoke-HarnessJbossUndeploy $server @('b.ear')
Assert ($unconfirmed.Status -eq 'FAILED') 'Exit code zero sem remocao foi declarado sucesso.'
& $module {$script:keepName='';$script:commands=@()}
$missing=Invoke-HarnessJbossUndeploy $server @('b.ear','ausente.war')
Assert ($missing.Status -eq 'FAILED' -and -not (@(& $module {$script:commands}) -like 'undeploy *')) 'Lista alterada deve interromper antes de remover.'
foreach ($name in @('*','b.ear --all-relevant-server-groups','x;shutdown','../x.war')) {
    & $module {param($n) $script:names=@($n);$script:commands=@()} $name
    $unsafe=Invoke-HarnessJbossUndeploy $server @($name)
    Assert ($unsafe.Status -eq 'FAILED' -and -not (@(& $module {$script:commands}) -like 'undeploy *')) 'Nome deve ser literal, sem injecao CLI.'
}
& $module {$script:names=@('a.war');$script:identity='UNVERIFIED';$script:commands=@()}
$wrong=Invoke-HarnessJbossUndeploy $server @('a.war')
Assert ($wrong.Status -eq 'FAILED' -and -not (@(& $module {$script:commands}) -like 'undeploy *')) 'Identidade divergente permitiu remocao.'
& $module {$script:identity='MATCHED';$script:badList=$true}
$rejected=$false; try {Get-HarnessJbossDeployments $server} catch {$rejected=$true}
Assert $rejected 'Resposta malformada nao pode virar lista vazia.'
& $module {$script:badList=$false}
$lease=[IO.File]::Open((Join-Path $server.State 'operation.lock'),'OpenOrCreate','ReadWrite','None')
try {
    $blocked=Invoke-HarnessJbossUndeploy $server @('a.war')
    Assert ($blocked.Status -eq 'FAILED' -and $blocked.Error -match 'andamento') 'Operacao concorrente nao foi bloqueada.'
} finally {$lease.Dispose()}
& $module {$script:state='STOPPED';$script:answers=@('0')}
$cancel=Invoke-HarnessJbossDeploymentMenu $context $server
Assert ($cancel.Status -eq 'CANCELLED' -and (& $module {$script:startCalls}) -eq 0) 'Cancelar com servidor parado iniciou processo.'
& $module {$script:answers=@('1','0')}
$admin=Invoke-HarnessJbossDeploymentMenu $context $server
Assert ($admin.Status -eq 'CANCELLED' -and (& $module {$script:mode}) -eq 'ADMIN_ONLY' -and (& $module {$script:startCalls}) -eq 1) 'Inicio deve ser somente administrativo e sair deve manter esse modo.'
Assert (-not (Test-Path (Join-Path $area '.harness/projetos'))) 'Administracao criou registro de aplicacao.'
Write-Output 'PASS: consulta, vazio/sair, individual/todos, falha parcial, verificacao, identidade, nomes, concorrencia e inicio admin-only; CLI simulada.'
