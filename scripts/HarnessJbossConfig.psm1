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
Export-ModuleMember -Function Get-HarnessJbossSettings, Get-HarnessJbossDebugConfigurations
