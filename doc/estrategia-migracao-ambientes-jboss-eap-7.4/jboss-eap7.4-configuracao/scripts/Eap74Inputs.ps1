#requires -Version 5.1
function Resolve-EapPath {
    param([string]$Path,[string]$Base)
    if ([string]::IsNullOrWhiteSpace($Path)) { throw 'Caminho de preparo ausente.' }
    if (-not [IO.Path]::IsPathRooted($Path)) { $Path=Join-Path $Base $Path }
    [IO.Path]::GetFullPath($Path).TrimEnd('\','/')
}
function Test-EapWithin {
    param([string]$Path,[string]$Parent)
    $Path -ieq $Parent -or $Path.StartsWith($Parent+'\',[StringComparison]::OrdinalIgnoreCase)
}
function Read-EapJson {
    param([string]$Path)
    try { Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json -ErrorAction Stop }
    catch { throw "JSON ausente ou invalido: $Path" }
}
function Read-EapPreparationConfig {
    param([string]$Path)
    $Path=Resolve-EapPath $Path (Get-Location).Path
    $config=Read-EapJson $Path
    foreach ($key in @('schemaVersion','eapHome','jdkHome','expectedVersion','standaloneConfig','template','values','modules','jvmOptions','output','portOffset','logSql')) {
        if (-not $config.PSObject.Properties[$key]) { throw "Campo obrigatorio ausente: $key" }
    }
    if ($config.schemaVersion -ne 1) { throw 'schemaVersion deve ser 1.' }
    if ($config.expectedVersion -cnotmatch '^7\.4\.\d+\.GA$') { throw 'expectedVersion deve identificar um patch EAP 7.4, por exemplo 7.4.11.GA.' }
    if ($config.standaloneConfig -cnotmatch '^[A-Za-z0-9][A-Za-z0-9_.-]*\.xml$') { throw 'standaloneConfig deve ser um nome XML simples.' }
    if (($config.portOffset -isnot [int] -and $config.portOffset -isnot [long]) -or $config.portOffset -lt 0 -or $config.portOffset -gt 55000) { throw 'portOffset deve ser inteiro entre 0 e 55000.' }
    if ($config.logSql -isnot [bool]) { throw 'logSql deve ser booleano.' }
    $base=Split-Path -Parent $Path
    foreach ($key in @('eapHome','jdkHome','template','values','modules','jvmOptions','output')) { $config.$key=Resolve-EapPath $config.$key $base }
    foreach ($pathValue in @($config.eapHome,$config.jdkHome,$config.output)) {
        if ($pathValue -match '["%!^&|<>\r\n]') { throw 'Caminho contem caracteres nao suportados pelo launcher Windows.' }
    }
    foreach ($inputPath in @($Path,$config.template,$config.values,$config.modules,$config.jvmOptions)) {
        if (Test-EapWithin $inputPath $config.output) { throw 'O consolidado nao pode conter as entradas do preparo.' }
    }
    foreach ($homePath in @($config.eapHome,$config.jdkHome)) {
        if ((Test-EapWithin $config.output $homePath) -or (Test-EapWithin $homePath $config.output)) { throw 'Consolidado deve ficar separado do EAP e do JDK.' }
    }
    foreach ($relative in @('version.txt','bin/standalone.bat','bin/standalone.conf.bat')) {
        if (-not (Test-Path -LiteralPath (Join-Path $config.eapHome $relative) -PathType Leaf)) { throw "Arquivo EAP ausente: $relative" }
    }
    $version=[regex]::Match([IO.File]::ReadAllText((Join-Path $config.eapHome 'version.txt')),'\bVersion\s+(\S+)').Groups[1].Value
    if ($version -cne $config.expectedVersion) { throw 'Versao instalada difere de expectedVersion. Confira o patch antes do preparo.' }
    if (-not (Test-Path -LiteralPath (Join-Path $config.jdkHome 'bin/java.exe') -PathType Leaf) -or
        [IO.File]::ReadAllText((Join-Path $config.jdkHome 'release')) -notmatch '(?m)^JAVA_VERSION="1\.8\.') { throw 'Preparo exige JDK 8 identificado pelo arquivo release.' }
    $config
}
function ConvertTo-EapXmlDocument {
    param([string]$Text)
    $reader=$null
    try {
        $settings=New-Object Xml.XmlReaderSettings
        $settings.DtdProcessing=[Xml.DtdProcessing]::Prohibit; $settings.XmlResolver=$null
        $reader=[Xml.XmlReader]::Create((New-Object IO.StringReader $Text),$settings)
        $document=New-Object Xml.XmlDocument; $document.XmlResolver=$null; $document.PreserveWhitespace=$true
        $document.Load($reader)
        return ,$document
    } catch { throw 'XML invalido ou com DTD. Conteudo omitido para preservar valores locais.' }
    finally { if ($reader) { $reader.Dispose() } }
}
function New-EapXml {
    param($Config,[bool]$LogSql)
    $values=New-Object 'Collections.Generic.Dictionary[string,string]' ([StringComparer]::Ordinal)
    $lineNumber=0
    foreach ($line in [IO.File]::ReadAllLines($Config.values)) {
        $lineNumber++
        if ($line -match '^\s*(#|$)') { continue }
        $pair=$line -split '=',2; $key=$pair[0].Trim()
        if ($pair.Count -ne 2 -or $key -cnotmatch '^__[A-Za-z0-9_.]+__$') { throw "Linha de valores invalida: $lineNumber (conteudo omitido)." }
        if ($values.ContainsKey($key)) { throw "Chave duplicada: $key" }
        $values.Add($key,$pair[1])
    }
    $template=[IO.File]::ReadAllText($Config.template)
    $tokens=@([regex]::Matches($template,'__[A-Za-z0-9_.]+__') | ForEach-Object Value | Sort-Object -Unique)
    foreach ($key in $values.Keys) { if ($key -cnotin $tokens) { throw "Chave sem token no template: $key" } }
    foreach ($token in $tokens) { if (-not $values.ContainsKey($token)) { throw "Token sem valor: $token" } }
    # Substituicao unica: valores nao sao reinterpretados como novos tokens.
    $rendered=[regex]::Replace($template,'__[A-Za-z0-9_.]+__',[Text.RegularExpressions.MatchEvaluator]{param($match) [Security.SecurityElement]::Escape($values[$match.Value])})
    $document=ConvertTo-EapXmlDocument $rendered
    if (-not $LogSql) { return $rendered }
    $logging=@($document.SelectNodes('//*[local-name()="subsystem" and starts-with(namespace-uri(),"urn:jboss:domain:logging:")]'))
    if ($logging.Count -ne 1) { throw 'LogSql exige um unico subsistema logging no template.' }
    foreach ($entry in @(@('org.hibernate.SQL','DEBUG'),@('org.hibernate.type.descriptor.sql','TRACE'))) {
        $logger=$logging[0].SelectSingleNode('*[local-name()="logger" and @category="'+$entry[0]+'"]')
        if (-not $logger) {
            $logger=$document.CreateElement('logger',$logging[0].NamespaceURI); $logger.SetAttribute('category',$entry[0])
            $rootLogger=$logging[0].SelectSingleNode('*[local-name()="root-logger"]')
            if ($rootLogger) { $null=$logging[0].InsertBefore($logger,$rootLogger) } else { $null=$logging[0].AppendChild($logger) }
        }
        $level=$logger.SelectSingleNode('*[local-name()="level"]')
        if (-not $level) { $level=$document.CreateElement('level',$logger.NamespaceURI); $null=$logger.PrependChild($level) }
        $level.SetAttribute('name',$entry[1])
    }
    $document.OuterXml
}
function New-EapJvmConfig {
    param($Config)
    $options=@()
    foreach ($line in [IO.File]::ReadAllLines($Config.jvmOptions)) {
        $option=$line.Trim()
        if (-not $option -or $option.StartsWith('#')) { continue }
        if ($option -notmatch '^-' -or $option -match '["%!^&|<>\r\n]' -or $option -match '__[A-Za-z0-9_.]+__') { throw 'Opcao JVM invalida, token pendente ou caractere nao suportado no BAT (valor omitido).' }
        $options+='"'+$option+'"'
    }
    if (-not $options.Count) { throw 'Arquivo JVM sem opcoes.' }
    $original=[IO.File]::ReadAllText((Join-Path $Config.eapHome 'bin/standalone.conf.bat'))
    $original=[regex]::Replace($original,'(?ms)^rem BEGIN EAP74 PREPARO (?:ENV|JVM)\r?\n.*?^rem END EAP74 PREPARO\r?\n?','')
    # Limpar heranca antes do arquivo do produto; aplicar escolhas ao final.
    $prefix=@('rem BEGIN EAP74 PREPARO ENV','@echo off','set "JAVA_OPTS="','set "JAVA_TOOL_OPTIONS="','set "_JAVA_OPTIONS="','set "JDK_JAVA_OPTIONS="','rem END EAP74 PREPARO') -join "`r`n"
    $suffix=@('rem BEGIN EAP74 PREPARO JVM',('set "JAVA_HOME='+$Config.jdkHome+'"'),('set "JAVA='+$Config.jdkHome+'\bin\java.exe"'),('set JAVA_OPTS='+($options -join ' ')),'rem END EAP74 PREPARO') -join "`r`n"
    $prefix+"`r`n"+$original.TrimEnd()+"`r`n"+$suffix+"`r`n"
}
