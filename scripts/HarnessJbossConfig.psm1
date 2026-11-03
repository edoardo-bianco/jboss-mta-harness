#requires -Version 5.1
Set-StrictMode -Version Latest

function Get-HarnessJbossSettings {
    param($Config, [ValidateSet('eap71','eap74')][string]$Eap)
    $values = [ordered]@{standaloneConfig='standalone.xml'; portOffset=0; debugPort=8787; timeoutSeconds=120}
    if ($Eap -eq 'eap74') { $values.portOffset=100; $values.debugPort=8788 }
    if ($Config.PSObject.Properties['eap'] -and $Config.eap.PSObject.Properties[$Eap]) {
        $custom = $Config.eap.$Eap
        foreach ($name in @($values.Keys)) {
            if ($custom.PSObject.Properties[$name]) { $values[$name]=$custom.$name }
        }
    }
    if ($values.standaloneConfig -cnotmatch '^[A-Za-z0-9][A-Za-z0-9_.-]*\.xml$') { throw 'standaloneConfig deve ser nome XML dentro de standalone/configuration.' }
    foreach ($entry in @(@('portOffset',0,55000),@('debugPort',1024,65535),@('timeoutSeconds',10,600))) {
        $value=$values[$entry[0]]
        if ($value -isnot [int] -and $value -isnot [long]) { throw "eap.$Eap.$($entry[0]) deve ser inteiro." }
        if ($value -lt $entry[1] -or $value -gt $entry[2]) { throw "eap.$Eap.$($entry[0]) fora do intervalo." }
    }
    return [pscustomobject]$values
}

function Get-HarnessJbossDebugConfigurations {
    param($Config)
    $ports=@{}
    foreach ($id in @('eap71','eap74')) {
        $settings=Get-HarnessJbossSettings $Config $id
        if ($ports.ContainsKey($settings.debugPort)) { throw 'Portas de debug dos EAPs devem ser distintas.' }
        $ports[$settings.debugPort]=$true
        [pscustomobject][ordered]@{name="JBoss $id - attach Java"; type='java'; request='attach'; hostName='127.0.0.1'; port=$settings.debugPort}
    }
}
function Get-HarnessJbossJvmFileName {
    param([string]$StandaloneConfig)
    if ($StandaloneConfig -cnotmatch '^[A-Za-z0-9][A-Za-z0-9_.-]*\.xml$') { throw 'Nome XML invalido para associacao JVM.' }
    'eap74-preparo-'+[IO.Path]::GetFileNameWithoutExtension($StandaloneConfig)+'.conf.bat'
}

function Resolve-HarnessJbossJvmConfig {
    param([string]$EapHome,[string]$StandaloneConfig,[string]$ExpectedJdk)
    $profilePath=Join-Path $EapHome ('bin/'+(Get-HarnessJbossJvmFileName $StandaloneConfig))
    if (Test-Path -LiteralPath $profilePath) {
        if (-not [IO.File]::Exists($profilePath)) { throw 'Arquivo JVM do XML indisponivel.' }
        $content=[IO.File]::ReadAllText($profilePath)
        $markers=[regex]::Matches($content,'(?m)^rem EAP74 PREPARO CONFIG=([^\r\n]+)\r?$')
        if ($markers.Count -ne 1 -or $markers[0].Groups[1].Value -ine $StandaloneConfig) { throw 'Associacao JVM/XML invalida. Confira o preparo instalado.' }
        if ($ExpectedJdk) {
            $blocks=[regex]::Matches($content,'(?ms)^rem BEGIN EAP74 PREPARO JVM\r?\n.*?^rem END EAP74 PREPARO')
            if ($blocks.Count -ne 1) { throw 'Bloco JVM associado ao XML ausente ou repetido.' }
            $jdk=[regex]::Matches($blocks[0].Value,'(?m)^set "JAVA_HOME=([^"\r\n]+)"\r?$')
            if ($jdk.Count -ne 1 -or [IO.Path]::GetFullPath($jdk[0].Groups[1].Value) -ine [IO.Path]::GetFullPath($ExpectedJdk)) { throw 'JDK da JVM por XML difere da configuracao do servidor.' }
        }
        return $profilePath
    }
    Join-Path $EapHome 'bin/standalone.conf.bat'
}
Export-ModuleMember -Function Get-HarnessJbossSettings, Get-HarnessJbossDebugConfigurations, Get-HarnessJbossJvmFileName, Resolve-HarnessJbossJvmConfig
