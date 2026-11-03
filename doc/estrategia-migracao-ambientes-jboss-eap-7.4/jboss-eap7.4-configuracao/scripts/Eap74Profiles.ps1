function Resolve-EapProfile {
    param($Config,[string]$Path,[string]$Profile)
    if ($Config.schemaVersion -eq 1) {
        if ($Profile) { throw 'Perfil exige schemaVersion=2 com profiles.' }
        $Config | Add-Member -NotePropertyName Profile -NotePropertyValue $null -Force
        return $Config
    }
    if ($Config.schemaVersion -ne 2) { throw 'schemaVersion deve ser 1 ou 2.' }
    if (-not $Config.PSObject.Properties['profiles'] -or $Config.profiles -isnot [pscustomobject]) { throw 'profiles deve ser um objeto de perfis.' }
    $profiles=@($Config.profiles.PSObject.Properties)
    if (-not $profiles.Count) { throw 'profiles deve conter ao menos um perfil.' }
    if (-not $Profile -or $Profile -cnotin $profiles.Name) { throw ('Informe -Perfil com um dos nomes disponiveis: '+($profiles.Name -join ', ')) }
    $common=@('eapHome','jdkHome','expectedVersion','modules','portOffset','logSql')
    foreach ($key in $common) { if (-not $Config.PSObject.Properties[$key]) { throw "Campo comum obrigatorio ausente: $key" } }
    foreach ($property in $Config.PSObject.Properties) {
        if ($property.Name -cnotin ($common+@('schemaVersion','profiles','files'))) { throw "Campo fora do esquema de perfis: $($property.Name)" }
    }
    $base=Split-Path -Parent $Path
    $fields=@('standaloneConfig','template','values','jvmOptions','output')
    $xmlNames=New-Object 'Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    $outputs=@(); $inputs=@($Path,(Resolve-EapPath $Config.modules $base))
    foreach ($entry in $profiles) {
        if ($entry.Name -cnotmatch '^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$' -or $entry.Value -isnot [pscustomobject]) { throw 'Nome ou objeto de perfil invalido.' }
        foreach ($field in $fields) {
            if (-not $entry.Value.PSObject.Properties[$field] -or $entry.Value.$field -isnot [string] -or [string]::IsNullOrWhiteSpace($entry.Value.$field)) { throw "Campo de perfil ausente/invalido: $($entry.Name).$field" }
        }
        foreach ($field in $entry.Value.PSObject.Properties.Name) { if ($field -cnotin $fields) { throw "Campo nao permitido no perfil: $field" } }
        if ($entry.Value.standaloneConfig -cnotmatch '^[A-Za-z0-9][A-Za-z0-9_.-]*\.xml$' -or -not $xmlNames.Add($entry.Value.standaloneConfig)) { throw 'XML de perfil invalido ou repetido.' }
        $outputs+=Resolve-EapPath $entry.Value.output $base
        foreach ($field in @('template','values','jvmOptions')) { $inputs+=Resolve-EapPath $entry.Value.$field $base }
    }
    if ($Config.PSObject.Properties['files']) {
        foreach ($file in $Config.files) {
            if ($xmlNames.Contains([string](Get-EapField $file 'target' ''))) { throw 'Arquivo externo nao pode substituir XML de perfil.' }
            $inputs+=Resolve-EapPath ([string](Get-EapField $file 'source' '')) $base
        }
    }
    $manifestPath=Resolve-EapPath $Config.modules $base
    $manifest=Read-EapJson $manifestPath
    foreach ($module in @(Get-EapField $manifest 'modules' @())) {
        foreach ($artifact in @(Get-EapField $module 'artifacts' @())) {
            if ((Get-EapField $artifact 'source') -eq 'file') { $inputs+=Resolve-EapPath ([string](Get-EapField $artifact 'path' '')) (Split-Path -Parent $manifestPath) }
        }
    }
    $mavenSettings=Get-EapField (Get-EapField $manifest 'maven') 'settings'
    if ($mavenSettings) { $inputs+=Resolve-EapPath $mavenSettings (Split-Path -Parent $manifestPath) }
    for ($i=0; $i -lt $outputs.Count; $i++) {
        foreach ($inputPath in $inputs) { if (Test-EapWithin $inputPath $outputs[$i]) { throw 'output de perfil nao pode conter entradas de outro perfil ou entradas comuns.' } }
        foreach ($homePath in @($Config.eapHome,$Config.jdkHome)) {
            $resolved=Resolve-EapPath $homePath $base
            if ((Test-EapWithin $outputs[$i] $resolved) -or (Test-EapWithin $resolved $outputs[$i])) { throw 'output de perfil deve ficar separado do EAP e JDK.' }
        }
        for ($j=0; $j -lt $i; $j++) {
            if ((Test-EapWithin $outputs[$i] $outputs[$j]) -or (Test-EapWithin $outputs[$j] $outputs[$i])) { throw 'Saidas de perfis nao podem coincidir nem conter outra saida.' }
        }
    }
    $effective=[ordered]@{schemaVersion=2;Profile=$Profile}
    foreach ($key in $common) { $effective[$key]=$Config.$key }
    if ($Config.PSObject.Properties['files']) { $effective.files=$Config.files }
    foreach ($field in $fields) { $effective[$field]=$Config.profiles.$Profile.$field }
    [pscustomobject]$effective
}
