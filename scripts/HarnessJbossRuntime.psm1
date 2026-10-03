#requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'Harness.psm1') -DisableNameChecking
Import-Module (Join-Path $PSScriptRoot 'HarnessJbossConfig.psm1') -DisableNameChecking

function Read-HarnessJbossContext {
    param([string]$Path, [string]$Root = (Split-Path -Parent $PSScriptRoot))
    $Root=Resolve-HarnessPath $Root $Root
    $Path=Resolve-HarnessPath $Path $Root
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw 'Configure primeiro: Terminal > Run Task > Workspace: configurar caminhos.' }
    $config=Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($config.schemaVersion -ne 1) { throw 'schemaVersion deve ser 1.' }
    # Operacoes do servidor nao dependem de projetos, workspace ou perfil MTA.
    [pscustomobject]@{Root=$Root;ConfigPath=$Path;Config=$config;Active=$null}
}

function Get-HarnessJbossServer {
    param($Context, [ValidateSet('eap71','eap74')][string]$Eap)
    $settings=Get-HarnessJbossSettings $Context.Config $Eap
    $homePath=Resolve-HarnessPath $Context.Config.tools.($Eap+'Home') $Context.Root
    $jdk=Resolve-HarnessPath $Context.Config.tools.applicationJdk8Home $Context.Root
    if (-not $homePath -or -not $jdk) { throw "Configure tools.${Eap}Home e applicationJdk8Home." }
    $base=Join-Path $homePath 'standalone'
    $java=Join-Path $jdk 'bin/java.exe'
    $cli=Join-Path $homePath 'bin/client/jboss-cli-client.jar'
    foreach ($file in @($java,$cli,(Join-Path $homePath 'bin/standalone.bat'),(Join-Path $homePath 'version.txt'),(Join-Path $base ('configuration/'+$settings.standaloneConfig)))) {
        $null=Resolve-HarnessPath $file $Context.Root
        if (-not (Test-Path -LiteralPath $file -PathType Leaf)) { throw "Arquivo ausente: $file" }
        if ($file -match '["%!^&|<>\r\n]') { throw 'Caminho nao suportado pelo launcher JBoss Windows.' }
    }
    $version=if ($Eap -eq 'eap71') {'7.1'} else {'7.4'}
    if ((Get-Content -LiteralPath (Join-Path $homePath 'version.txt') -Raw) -notmatch ('Version '+[regex]::Escape($version)+'\.')) { throw 'Instalacao JBoss nao corresponde ao EAP selecionado.' }
    $key=Get-HarnessProjectKey $homePath
    $state=Resolve-HarnessPath (Join-Path $Context.Root ('.harness/jboss/'+$Eap+'__'+$key.Substring(0,12))) $Context.Root
    [pscustomobject]@{Eap=$Eap; Home=$homePath; Base=$base; Jdk=$jdk; Java=$java; Cli=$cli; Version=$version; Settings=$settings; ManagementPort=(9990+$settings.portOffset); HttpPort=(8080+$settings.portOffset); State=$state}
}

function ConvertTo-JbossNativeArgument {
    param([string]$Value)
    # Windows CommandLineToArgvW quoting; no shell is involved in the Java CLI.
    '"' + [regex]::Replace([regex]::Replace($Value, '(\\*)"', '$1$1\"'), '(\\+)$', '$1$1') + '"'
}

function Invoke-JbossJava {
    param($Server, [string[]]$Arguments, [int]$TimeoutSeconds=15)
    $info=New-Object Diagnostics.ProcessStartInfo
    $info.FileName=$Server.Java
    $info.Arguments=(@($Arguments | ForEach-Object { ConvertTo-JbossNativeArgument $_ }) -join ' ')
    $info.WorkingDirectory=$Server.Home
    $info.UseShellExecute=$false; $info.CreateNoWindow=$true
    $info.RedirectStandardOutput=$true; $info.RedirectStandardError=$true
    foreach ($name in @('JAVA_TOOL_OPTIONS','_JAVA_OPTIONS','JDK_JAVA_OPTIONS')) { $info.EnvironmentVariables.Remove($name) }
    $process=New-Object Diagnostics.Process
    $process.StartInfo=$info
    try {
        $null=$process.Start()
        $stdout=$process.StandardOutput.ReadToEndAsync(); $stderr=$process.StandardError.ReadToEndAsync()
        if (-not $process.WaitForExit($TimeoutSeconds*1000)) { $process.Kill(); $process.WaitForExit(); throw 'Timeout da CLI Java; resultado da operacao deve ser conferido no servidor.' }
        [pscustomobject]@{ExitCode=$process.ExitCode; Output=($stdout.Result+"`n"+$stderr.Result).Trim()}
    } finally { $process.Dispose() }
}

function Invoke-JbossCli {
    param($Server, [string]$Command)
    $arguments=@(('-Djboss.cli.config='+ (Join-Path $Server.Home 'bin/jboss-cli.xml')), '-jar', $Server.Cli,
        '--connect', ('--controller=remote+http://127.0.0.1:'+$Server.ManagementPort), '--error-on-interact', '--timeout=3000',
        ('--command-timeout='+$Server.Settings.timeoutSeconds), ('--command='+$Command))
    $reply=Invoke-JbossJava $Server $arguments ($Server.Settings.timeoutSeconds+5)
    if ($reply.ExitCode -ne 0 -or $reply.Output -match '"outcome"\s*=>\s*"failed"') { throw "CLI JBoss falhou: $($reply.Output)" }
    return $reply.Output
}

function Read-JbossValue {
    param($Server, [string]$Command)
    $output=Invoke-JbossCli $Server $Command
    if ($output -notmatch '"outcome"\s*=>\s*"success"') { throw 'Resposta CLI sem outcome success.' }
    $match=[regex]::Match($output,'"result"\s*=>\s*("(?:\\.|[^"\\])*"|true|false|undefined)')
    if (-not $match.Success) { throw 'Resposta CLI nao contem valor escalar esperado.' }
    $value=$match.Groups[1].Value
    if ($value.StartsWith('"')) { return ($value | ConvertFrom-Json) }
    return $value
}

function Get-JbossListener {
    param([int]$Port)
    @(Get-NetTCPConnection -State Listen -ErrorAction Stop | Where-Object LocalPort -eq $Port)
}

function Get-JbossLocalProcesses {
    param($Server)
    @(Get-CimInstance Win32_Process -Filter "Name = 'java.exe'" -ErrorAction Stop | Where-Object {
        $_.CommandLine -and $_.CommandLine.IndexOf($Server.Home,[StringComparison]::OrdinalIgnoreCase) -ge 0 -and $_.CommandLine -match 'org\.jboss\.as\.standalone'
    })
}

function Get-HarnessJbossStatus {
    param($Server)
    $listeners=@(Get-JbossListener $Server.ManagementPort)
    if (-not $listeners.Count) {
        $processes=@(Get-JbossLocalProcesses $Server)
        $state=if ($processes.Count) {'UNREACHABLE'} else {'STOPPED'}
        return [pscustomobject]@{State=$state; ProcessId=$null; ProcessStartUtc=$null; Identity='UNVERIFIED'; Debug=$false}
    }
    $ids=@($listeners.OwningProcess | Select-Object -Unique)
    if ($ids.Count -ne 1) { throw 'Porta de gerenciamento tem identidade ambigua.' }
    $process=Get-Process -Id $ids[0] -ErrorAction Stop
    $processStart=$process.StartTime.ToUniversalTime().ToString('o')
    $homeObserved=Read-JbossValue $Server '/core-service=server-environment:read-attribute(name=home-dir)'
    $baseObserved=Read-JbossValue $Server '/core-service=server-environment:read-attribute(name=base-dir)'
    $configObserved=Read-JbossValue $Server '/core-service=server-environment:read-attribute(name=config-file)'
    $version=Read-JbossValue $Server ':read-attribute(name=product-version)'
    if ([IO.Path]::GetFullPath($homeObserved).TrimEnd('\') -ine $Server.Home -or [IO.Path]::GetFullPath($baseObserved).TrimEnd('\') -ine $Server.Base -or
        [IO.Path]::GetFileName($configObserved) -ine $Server.Settings.standaloneConfig -or $version -notmatch ('^'+[regex]::Escape($Server.Version)+'\.')) { throw 'Identidade do servidor difere do home/base/config/versao selecionados.' }
    $javaVersion=Read-JbossValue $Server ':resolve-expression(expression="${java.version}")'
    if ($javaVersion -notmatch '^1\.8\.') { throw 'O servidor selecionado nao esta executando Java 8.' }
    $state=Read-JbossValue $Server ':read-attribute(name=server-state)'
    $debug=@(Get-JbossListener $Server.Settings.debugPort | Where-Object { $_.OwningProcess -eq $ids[0] -and $_.LocalAddress -eq '127.0.0.1' }).Count -gt 0
    [pscustomobject]@{State=$state.ToUpperInvariant(); ProcessId=[int]$ids[0]; ProcessStartUtc=$processStart; Identity='MATCHED'; Debug=$debug}
}

function Start-JbossProcess {
    param($Server, [string]$Run, [switch]$DebugMode)
    $previous=@{}
    try {
        foreach ($name in @('JAVA_HOME','JBOSS_HOME','JBOSS_BASE_DIR','JBOSS_CONFIG_DIR','JBOSS_LOG_DIR','STANDALONE_CONF','DEBUG','DEBUG_PORT','NOPAUSE')) {
            $previous[$name]=[Environment]::GetEnvironmentVariable($name,'Process')
            [Environment]::SetEnvironmentVariable($name,$null,'Process')
        }
        $env:JAVA_HOME=$Server.Jdk; $env:JBOSS_HOME=$Server.Home; $env:JBOSS_BASE_DIR=$Server.Base; $env:NOPAUSE='true'
        $arguments='""'+(Join-Path $Server.Home 'bin/standalone.bat')+'" "-Djboss.server.base.dir='+$Server.Base+'" -c '+$Server.Settings.standaloneConfig+' -b 127.0.0.1 -bmanagement 127.0.0.1 -Djboss.socket.binding.port-offset='+$Server.Settings.portOffset
        if ($DebugMode) {
            # O parser Java aceita somente a porta numerica apos --debug.
            # O launcher usa DEBUG_PORT como endereco JDWP, sem repassa-lo ao parser.
            $env:DEBUG_PORT='127.0.0.1:'+$Server.Settings.debugPort
            $arguments+=' --debug '+$Server.Settings.debugPort
        }
        $arguments+='"'
        Start-Process -FilePath $env:ComSpec -ArgumentList @('/d','/s','/c',$arguments) -WorkingDirectory $Server.Home -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $Run 'stdout.log') -RedirectStandardError (Join-Path $Run 'stderr.log')
    } finally { foreach ($name in $previous.Keys) { [Environment]::SetEnvironmentVariable($name,$previous[$name],'Process') } }
}

function Start-HarnessJboss {
    param($Server, [string]$Run, [switch]$DebugMode)
    $current=Get-HarnessJbossStatus $Server
    if ($current.State -eq 'RUNNING') {
        if ($DebugMode -and -not $current.Debug) { throw 'Servidor ja esta iniciado sem debug na porta configurada. Use stop e start debug explicitamente.' }
        return $current
    }
    if ($current.State -ne 'STOPPED') { throw 'Servidor existente ainda nao esta pronto; confira o log antes de novo start.' }
    $ports=@($Server.ManagementPort,$Server.HttpPort)
    if ($DebugMode) { $ports+=$Server.Settings.debugPort }
    foreach ($port in $ports) { if (@(Get-JbossListener $port).Count) { throw "Porta $port ocupada; nenhum processo iniciado." } }
    $java=Invoke-JbossJava $Server @('-version')
    if ($java.ExitCode -ne 0 -or $java.Output -notmatch 'version "1\.8\.') { throw 'Start exige JDK 8 efetivo.' }
    $launcher=Start-JbossProcess $Server $Run -DebugMode:$DebugMode
    Write-HarnessJson (Join-Path $Run 'process.json') @{ProcessId=$launcher.Id; StartedAtUtc=$launcher.StartTime.ToUniversalTime().ToString('o')}
    $timer=[Diagnostics.Stopwatch]::StartNew(); $lastError=''
    do {
        if ($launcher.HasExited) { throw "Launcher encerrou; confira $Run/stdout.log e stderr.log." }
        try {
            $current=Get-HarnessJbossStatus $Server
            if ($current.State -eq 'RUNNING') {
                if ($DebugMode -and -not $current.Debug) { throw 'Servidor iniciou mas debug local nao foi confirmado.' }
                return $current
            }
        } catch { $lastError=$_.Exception.Message }
        Start-Sleep -Milliseconds 500
    } while ($timer.Elapsed.TotalSeconds -lt $Server.Settings.timeoutSeconds)
    throw "Start nao confirmado no prazo; servidor preservado para diagnostico/stop. $lastError"
}

function Stop-HarnessJboss {
    param($Server)
    $current=Get-HarnessJbossStatus $Server
    if ($current.State -eq 'STOPPED') { return $current }
    if ($current.Identity -ne 'MATCHED') { throw 'Stop exige identidade confirmada pelo gerenciamento.' }
    $process=Get-Process -Id $current.ProcessId -ErrorAction Stop
    if ($process.StartTime.ToUniversalTime().ToString('o') -ne $current.ProcessStartUtc) { throw 'Processo mudou antes do shutdown.' }
    $command=if ($Server.Version -eq '7.1') {'shutdown --timeout=10'} else {'shutdown --suspend-timeout=10'}
    $null=Invoke-JbossCli $Server $command
    if (-not $process.WaitForExit($Server.Settings.timeoutSeconds*1000)) { throw 'Shutdown enviado, mas saida nao confirmada; nenhum processo foi forcado.' }
    $after=Get-HarnessJbossStatus $Server
    if ($after.State -ne 'STOPPED') { throw 'Processo encerrou, mas servidor/launcher ainda ativo. Confira o estado.' }
    return $after
}
function Invoke-HarnessJbossAddUser {
    param($Server)
    $launcher=Join-Path $Server.Home 'bin/add-user.bat'
    if (-not (Test-Path -LiteralPath $launcher -PathType Leaf)) { throw "Arquivo ausente: $launcher" }
    $previous=@{}
    try {
        foreach ($name in @('JAVA_HOME','JBOSS_HOME','JBOSS_MODULEPATH','JAVA_OPTS','JAVA_TOOL_OPTIONS','_JAVA_OPTIONS','JDK_JAVA_OPTIONS','COMMON_CONF','NOPAUSE')) {
            $previous[$name]=[Environment]::GetEnvironmentVariable($name,'Process')
            [Environment]::SetEnvironmentVariable($name,$null,'Process')
        }
        $env:JAVA_HOME=$Server.Jdk
        $env:JBOSS_HOME=$Server.Home
        $env:JBOSS_MODULEPATH=Join-Path $Server.Home 'modules'
        $env:NOPAUSE='true'
        $java=Invoke-JbossJava $Server @('-version')
        if ($java.ExitCode -ne 0 -or $java.Output -notmatch 'version "1\.8\.') { throw 'Criar usuario exige JDK 8 efetivo.' }
        # Assistente nativo conectado ao terminal: sem credenciais nos argumentos,
        # sem redirecionar sua saida e sem recibo contendo dados do usuario.
        & $launcher
        if ($LASTEXITCODE -ne 0) { throw "Assistente add-user encerrou com codigo $LASTEXITCODE." }
    } finally {
        foreach ($name in $previous.Keys) { [Environment]::SetEnvironmentVariable($name,$previous[$name],'Process') }
    }
}

Export-ModuleMember -Function Read-HarnessJbossContext, Get-HarnessJbossServer, Get-HarnessJbossStatus, Start-HarnessJboss, Stop-HarnessJboss, Invoke-HarnessJbossAddUser, Invoke-JbossCli, Read-JbossValue
