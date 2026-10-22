function Get-EapField {
    param($Object,[string]$Name,$Default=$null)
    if ($Object -and $Object.PSObject.Properties[$Name]) { return $Object.$Name }
    $Default
}
function Invoke-EapMavenCopy {
    param($Maven,[string]$Coordinates,[string]$Destination)
    $executable=Get-EapField $Maven 'executable' 'mvn.cmd'
    $settings=Get-EapField $Maven 'settings'
    $arguments=@('-B','-q','org.apache.maven.plugins:maven-dependency-plugin:3.8.1:copy',('-Dartifact='+$Coordinates),('-DoutputDirectory='+(Split-Path -Parent $Destination)))
    if ($settings) { $arguments=@('--settings',$settings)+$arguments }
    $log=$Destination+'.maven.log'
    Push-Location (Split-Path -Parent $Destination)
    try {
        # Usar settings e cache da maquina; nao criar POM, mirror ou repositorio proprio.
        & $executable @arguments *> $log
        if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $Destination -PathType Leaf)) { throw 'Maven nao entregou o JAR solicitado.' }
    } catch { throw "Falha Maven para $Coordinates. Confira acesso, settings e disponibilidade do artefato; nenhum modulo parcial sera publicado." }
    finally { Pop-Location; if ([IO.File]::Exists($log)) { [IO.File]::Delete($log) } }
}
function New-EapModules {
    param($Config,[string]$Stage)
    $manifest=Read-EapJson $Config.modules
    if (-not $manifest.PSObject.Properties['modules']) { throw 'Manifesto sem lista modules.' }
    $base=Split-Path -Parent $Config.modules
    $maven=Get-EapField $manifest 'maven'
    if ($maven -and (Get-EapField $maven 'settings')) { $maven.settings=Resolve-EapPath $maven.settings $base }
    $names=New-Object 'Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    $paths=New-Object 'Collections.Generic.List[string]'
    foreach ($module in @($manifest.modules)) {
        $name=[string]$module.name; $slot=[string](Get-EapField $module 'slot' 'main')
        if ($name -cnotmatch '^[A-Za-z0-9_-]+(\.[A-Za-z0-9_-]+)*$' -or $name -match '^system($|\.)' -or $slot -cnotmatch '^[A-Za-z0-9_-]+$') { throw 'Nome/slot de modulo invalido ou reservado.' }
        $relative='modules\'+$name.Replace('.','\')+'\'+$slot
        if (-not $names.Add($relative)) { throw "Modulo/slot duplicado: $name/$slot" }
        $destination=Join-Path $Stage $relative
        $null=[IO.Directory]::CreateDirectory($destination)
        $lines=@('<?xml version="1.0" encoding="UTF-8"?>',('<module xmlns="urn:jboss:module:1.9" name="'+$name+'" slot="'+$slot+'">'),'  <resources>')
        $jars=New-Object 'Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
        if (-not @($module.artifacts).Count) { throw "Modulo sem artefatos: $name" }
        foreach ($artifact in @($module.artifacts)) {
            $source=$artifact.source
            if ($source -eq 'file') {
                $file=Resolve-EapPath $artifact.path $base
                if (Test-EapWithin $file $Config.output) { throw 'JAR de entrada nao pode vir do consolidado.' }
                $leaf=Split-Path -Leaf $file
            } elseif ($source -eq 'maven') {
                $coordinate=[string]$artifact.coordinates
                if ($coordinate -cnotmatch '^([A-Za-z0-9_.-]+):([A-Za-z0-9_.-]+):([A-Za-z0-9_.+-]+)(:jar(:[A-Za-z0-9_.-]+)?)?$') { throw 'Coordenadas Maven invalidas; use groupId:artifactId:version[:jar[:classifier]].' }
                $parts=$coordinate.Split(':'); $leaf=$parts[1]+'-'+$parts[2]
                if ($parts.Count -eq 5) { $leaf+='-'+$parts[4] }
                $leaf+='.jar'
            } else { throw 'Origem de artefato deve ser file ou maven.' }
            if ($leaf -cnotmatch '^[A-Za-z0-9][A-Za-z0-9._+-]*\.jar$' -or -not $jars.Add($leaf)) { throw "Nome de JAR invalido ou repetido no modulo $name." }
            $sha256=Get-EapField $artifact 'sha256'; $sha1=Get-EapField $artifact 'sha1'
            if ($sha256 -and -not $sha1 -and $sha256 -match '^[0-9a-fA-F]{64}$') { $algorithm='SHA256'; $expected=$sha256 }
            elseif ($sha1 -and -not $sha256 -and $sha1 -match '^[0-9a-fA-F]{40}$') { $algorithm='SHA1'; $expected=$sha1 }
            else { throw "Informe exatamente um hash valido (sha256 ou sha1) para o JAR de $name." }
            $target=Join-Path $destination $leaf
            if ($source -eq 'file') { [IO.File]::Copy($file,$target,$false) }
            else { Invoke-EapMavenCopy $maven $coordinate $target }
            if ((Get-FileHash -LiteralPath $target -Algorithm $algorithm).Hash -ine $expected) { throw "Checksum divergente no modulo $name; nada sera instalado." }
            $lines+='    <resource-root path="'+$leaf+'"/>'
        }
        $lines+='  </resources>'
        $dependencies=@(Get-EapField $module 'dependencies' @())
        if ($dependencies.Count) {
            $lines+='  <dependencies>'
            foreach ($dependency in $dependencies) {
                if ($dependency -isnot [string] -or $dependency -cnotmatch '^[A-Za-z0-9_-]+(\.[A-Za-z0-9_-]+)*$') { throw "Dependencia de modulo invalida: $name" }
                $lines+='    <module name="'+$dependency+'"/>'
            }
            $lines+='  </dependencies>'
        }
        $lines+='</module>'
        [IO.File]::WriteAllText((Join-Path $destination 'module.xml'),($lines -join "`r`n")+"`r`n",(New-Object Text.UTF8Encoding $false))
        $paths.Add($relative)
    }
    $paths.ToArray()
}
function Get-EapTreeFiles {
    param([string]$Directory)
    Assert-EapPlainPath $Directory
    $files=@{}
    if (-not (Test-Path -LiteralPath $Directory -PathType Container)) { return $files }
    $pending=New-Object 'Collections.Generic.Stack[string]'
    $pending.Push($Directory)
    while ($pending.Count) {
        foreach ($item in @(Get-ChildItem -LiteralPath $pending.Pop() -Force)) {
            if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Link encontrado na arvore de publicacao.' }
            if ($item.PSIsContainer) { $pending.Push($item.FullName) }
            else { $files[$item.FullName.Substring($Directory.Length+1)]=(Get-FileHash -LiteralPath $item.FullName -Algorithm SHA256).Hash }
        }
    }
    $files
}
function Assert-EapModulesCompatible {
    param($Config,[string]$Stage,[string[]]$Modules)
    foreach ($relative in $Modules) {
        $destination=Join-Path $Config.eapHome $relative
        Assert-EapPlainPath $destination
        if (-not (Test-Path -LiteralPath $destination)) { continue }
        $expected=Get-EapTreeFiles (Join-Path $Stage $relative); $actual=Get-EapTreeFiles $destination
        if ($expected.Count -ne $actual.Count) { throw "Modulo existente diferente ou incompleto: $relative. Arquivos preservados." }
        foreach ($key in $expected.Keys) {
            if (-not $actual.ContainsKey($key) -or $actual[$key] -cne $expected[$key]) { throw "Modulo existente divergente: $relative. Arquivos preservados." }
        }
    }
}
