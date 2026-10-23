#requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$modulePath = Join-Path $root 'doc/estrategia-migracao-ambientes-jboss-eap-7.4/jboss-eap7.4-configuracao/scripts/Eap74Preparation.psm1'
Import-Module $modulePath -Force -DisableNameChecking
$module = Get-Module Eap74Preparation

function Assert($condition, $message) { if (-not $condition) { throw $message } }
function Write-TestFile([string]$Path, [string]$Content) {
    $null = [IO.Directory]::CreateDirectory((Split-Path -Parent $Path))
    [IO.File]::WriteAllText($Path, $Content, (New-Object Text.UTF8Encoding $false))
}
function Write-TestJson([string]$Path, $Value) {
    Write-TestFile $Path ($Value | ConvertTo-Json -Depth 12)
}
function Get-TreeState([string]$Path, [switch]$IncludeTimes) {
    if (-not (Test-Path -LiteralPath $Path)) { return '[ausente]' }
    $rows = @(Get-ChildItem -LiteralPath $Path -Force -Recurse | Sort-Object FullName | ForEach-Object {
        $relative = $_.FullName.Substring($Path.Length)
        if ($_.PSIsContainer) { 'D|' + $relative }
        else {
            $row = 'F|' + $relative + '|' + (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
            if ($IncludeTimes) { $row += '|' + $_.LastWriteTimeUtc.Ticks }
            $row
        }
    })
    return ($rows -join "`n")
}
function Assert-Rejected([scriptblock]$Action, [string]$Message, [string]$Reason) {
    $failure = $null
    try { $null = & $Action } catch { $failure = $_ }
    Assert ($null -ne $failure) $Message
    if ($Reason) { Assert ($failure.Exception.Message -match $Reason) ($Message + ' Motivo inesperado: ' + $failure.Exception.Message) }
}

# Todas as entradas sao sinteticas. O executor coloca esta suite e as fixtures
# numa copia temporaria fora do checkout operacional; nenhum EAP real e usado.
$area = Join-Path $root ('.harness/tests/eap74-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
$null = [IO.Directory]::CreateDirectory($area)
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
function New-PreparationFixture([string]$Name) {
    $base = Join-Path $area $Name
    $eap = Join-Path $base 'servidor destino'
    $jdk = Join-Path $base 'jdk 8'
    $inputs = Join-Path $base 'entradas'
    $output = Join-Path $base 'consolidado'
    Write-TestFile (Join-Path $eap 'version.txt') 'JBoss EAP - Version 7.4.11.GA'
    Write-TestFile (Join-Path $eap 'bin/standalone.bat') '@echo servidor sintetico: nao executar'
    Write-TestFile (Join-Path $eap 'bin/standalone.conf.bat') '@rem configuracao JVM anterior'
    Write-TestFile (Join-Path $eap 'standalone/configuration/standalone-local.xml') '<server id="anterior" />'
    $null = [IO.Directory]::CreateDirectory((Join-Path $eap 'modules'))
    Write-TestFile (Join-Path $jdk 'release') 'JAVA_VERSION="1.8.0_442"'
    Write-TestFile (Join-Path $jdk 'bin/java.exe') 'executavel sintetico: nao executar'
    $template = Join-Path $inputs 'templates/standalone.xml'
    Write-TestFile $template @'
<?xml version="1.0" encoding="UTF-8"?>
<server xmlns="urn:jboss:domain:16.0">
  <system-properties>
    <property name="example.endpoint" value="__ENDPOINT__" />
    <property name="example.message" value="__MESSAGE__" />
  </system-properties>
  <profile>
    <subsystem xmlns="urn:jboss:domain:logging:8.0">
      <console-handler name="CONSOLE"><level name="INFO" /></console-handler>
      <periodic-rotating-file-handler name="FILE"><formatter><named-formatter name="PATTERN" /></formatter><file relative-to="jboss.server.log.dir" path="server.log" /><suffix value=".yyyy-MM-dd" /></periodic-rotating-file-handler>
      <logger category="org.hibernate.SQL"><level name="INFO" /></logger>
      <root-logger><level name="INFO" /><handlers><handler name="CONSOLE" /><handler name="FILE" /></handlers></root-logger>
      <formatter name="PATTERN"><pattern-formatter pattern="%m%n" /></formatter>
    </subsystem>
  </profile>
  <socket-binding-group name="standard-sockets" default-interface="public" port-offset="${jboss.socket.binding.port-offset:0}" />
</server>
'@
    $values = Join-Path $inputs 'valores/ambiente.properties'
    Write-TestFile $values @'
# Dados ficticios; caracteres especiais precisam sobreviver ao XML.
__ENDPOINT__=https://example.invalid/path?x=1&y=2
__MESSAGE__=a & <b> "c" 'd' = C:\dados
'@
    $jar = Join-Path $inputs 'modulos/jars/driver.jar'
    $null = [IO.Directory]::CreateDirectory((Split-Path -Parent $jar))
    $archive = [IO.Compression.ZipFile]::Open($jar, [IO.Compression.ZipArchiveMode]::Create)
    try {
        $entry = $archive.CreateEntry('META-INF/MANIFEST.MF')
        $writer = New-Object IO.StreamWriter ($entry.Open())
        try { $writer.Write("Manifest-Version: 1.0`r`nImplementation-Title: fixture-eap74`r`n`r`n") } finally { $writer.Dispose() }
    } finally { $archive.Dispose() }
    $modulesPath = Join-Path $inputs 'modulos/modulos.json'
    $modules = [ordered]@{
        maven = [ordered]@{ executable = 'mvn.cmd'; settings = $null }
        modules = @([ordered]@{
            name = 'org.example.driver'; slot = 'main'; dependencies = @('javax.api')
            artifacts = @([ordered]@{ source = 'file'; path = 'jars/driver.jar'; sha256 = (Get-FileHash -LiteralPath $jar -Algorithm SHA256).Hash })
        })
    }
    Write-TestJson $modulesPath $modules
    Write-TestFile (Join-Path $inputs 'jvm/opcoes.txt') "# Uma opcao por linha`n-Xms128m`n-Xmx512m`n-Dfile.encoding=UTF-8`n"
    $configPath = Join-Path $base 'preparo.json'
    $config = [ordered]@{
        schemaVersion = 1; eapHome = 'servidor destino'; jdkHome = 'jdk 8'
        expectedVersion = '7.4.11.GA'; standaloneConfig = 'standalone-local.xml'
        template = 'entradas/templates/standalone.xml'; values = 'entradas/valores/ambiente.properties'
        modules = 'entradas/modulos/modulos.json'; jvmOptions = 'entradas/jvm/opcoes.txt'
        output = 'consolidado'; portOffset = 100; logSql = $false
    }
    Write-TestJson $configPath $config
    [pscustomobject]@{
        Base=$base; Eap=$eap; Jdk=$jdk; Inputs=$inputs; Output=$output
        ConfigPath=$configPath; Config=$config; ModulesPath=$modulesPath; Modules=$modules
        Template=$template; Values=$values; Jar=$jar
        GeneratedXml=(Join-Path $output 'standalone/configuration/standalone-local.xml')
        TargetModule=(Join-Path $eap 'modules/org/example/driver/main')
    }
}

# Somente fronteiras de processos/rede sao substituidas. Renderizacao, XML,
# checksum, consolidacao e publicacao exercitam arquivos e implementacao reais.
& $module {
    $script:testServerActive = $false
    $script:testMavenMode = 'forbidden'
    $script:testMavenJar = $null
    function script:Assert-EapStopped { param($Config)
        if ($script:testServerActive) { throw 'Servidor sintetico ativo: preparo recusado.' }
    }
    function script:Invoke-EapMavenCopy { param($Maven, $Coordinates, $Destination)
        if ($script:testMavenMode -eq 'forbidden') { throw 'A fixture de arquivo local nao pode consultar Maven.' }
        $null = [IO.Directory]::CreateDirectory((Split-Path -Parent $Destination))
        if ($script:testMavenMode -eq 'fail') {
            [IO.File]::WriteAllText($Destination, 'download parcial sintetico')
            throw 'Falha Maven sintetica apos download parcial.'
        }
        [IO.File]::Copy($script:testMavenJar, $Destination, $true)
    }
}

# A verificacao de servidor parado precede qualquer alteracao, inclusive gerar.
foreach ($apply in @($false, $true)) {
    $f = New-PreparationFixture ('servidor-ativo-' + $apply)
    Write-TestFile (Join-Path $f.Output 'preservar.txt') 'consolidado anterior'
    $beforeTarget = Get-TreeState $f.Eap -IncludeTimes
    $beforeOutput = Get-TreeState $f.Output -IncludeTimes
    & $module { $script:testServerActive = $true }
    try {
        Assert-Rejected { Invoke-EapPreparation -ConfigPath $f.ConfigPath -Apply:$apply } 'Preparo com servidor ativo foi permitido.' 'ativo'
    } finally { & $module { $script:testServerActive = $false } }
    Assert ((Get-TreeState $f.Eap -IncludeTimes) -ceq $beforeTarget) 'Servidor ativo teve arquivos alterados.'
    Assert ((Get-TreeState $f.Output -IncludeTimes) -ceq $beforeOutput) 'Servidor ativo teve o consolidado anterior substituido.'
}

$f = New-PreparationFixture 'gerar-xml-e-caminhos-relativos'
$beforeTarget = Get-TreeState $f.Eap -IncludeTimes
$beforeTemplate = [IO.File]::ReadAllText($f.Template)
$null = Invoke-EapPreparation -ConfigPath $f.ConfigPath
Assert (Test-Path -LiteralPath $f.GeneratedXml -PathType Leaf) 'Geracao nao publicou o XML no consolidado.'
[xml]$xml = [IO.File]::ReadAllText($f.GeneratedXml)
$endpoint = $xml.SelectSingleNode('//*[local-name()="property" and @name="example.endpoint"]')
$message = $xml.SelectSingleNode('//*[local-name()="property" and @name="example.message"]')
Assert ($endpoint.GetAttribute('value') -ceq 'https://example.invalid/path?x=1&y=2') 'Escape XML alterou endpoint com & e =.'
Assert ($message.GetAttribute('value') -ceq 'a & <b> "c" ''d'' = C:\dados') 'Escape XML alterou aspas, menor/maior ou caminho.'
Assert (([IO.File]::ReadAllText($f.Template)) -ceq $beforeTemplate) 'Geracao alterou o template de entrada.'
Assert ((Get-TreeState $f.Eap -IncludeTimes) -ceq $beforeTarget) 'Gerar sem Apply alterou o servidor destino.'
Assert ($xml.SelectSingleNode('//*[local-name()="logger" and @category="org.hibernate.SQL"]/*[local-name()="level"]').GetAttribute('name') -ceq 'INFO') 'Geracao comum ativou SQL sem escolha local.'
$jvm = [IO.File]::ReadAllText((Join-Path $f.Output 'bin/standalone.conf.bat'))
Assert ($jvm.Contains('-Xms128m') -and $jvm.Contains('-Xmx512m') -and $jvm.Contains('-Dfile.encoding=UTF-8')) 'Consolidado perdeu opcoes JVM configuradas.'

# A pasta de saida e gerenciada. Nao deve substituir material desconhecido nem
# remover ajustes humanos de um consolidado anteriormente gerado.
foreach ($problem in @('saida-desconhecida', 'saida-alterada', 'saida-com-extras')) {
    $f = New-PreparationFixture $problem
    if ($problem -eq 'saida-desconhecida') {
        Write-TestFile (Join-Path $f.Output 'anotacao-manual.txt') 'material humano preexistente'
    } else {
        $null = Invoke-EapPreparation -ConfigPath $f.ConfigPath
        Assert (Test-Path -LiteralPath (Join-Path $f.Output '.eap-preparo.json') -PathType Leaf) 'Consolidado gerado nao possui manifesto de propriedade.'
        if ($problem -eq 'saida-alterada') {
            [IO.File]::AppendAllText($f.GeneratedXml, "`n<!-- ajuste humano a preservar -->`n")
        } else { Write-TestFile (Join-Path $f.Output 'anotacao-manual.txt') 'material humano acrescentado' }
    }
    $beforeTarget = Get-TreeState $f.Eap -IncludeTimes
    $beforeOutput = Get-TreeState $f.Output -IncludeTimes
    Assert-Rejected { Invoke-EapPreparation -ConfigPath $f.ConfigPath -Apply } ('Consolidado humano foi aceito para substituicao: ' + $problem)
    Assert ((Get-TreeState $f.Eap -IncludeTimes) -ceq $beforeTarget) ('Recusa de consolidado alterou servidor: ' + $problem)
    Assert ((Get-TreeState $f.Output -IncludeTimes) -ceq $beforeOutput) ('Recusa de consolidado perdeu material humano: ' + $problem)
}

# Defeitos de entrada nao substituem resultado anterior nem arquivos ativos.
foreach ($problem in @('chave-duplicada', 'chave-ausente', 'xml-invalido')) {
    $f = New-PreparationFixture $problem
    Write-TestFile (Join-Path $f.Output 'preservar.txt') 'consolidado anterior'
    $beforeTarget = Get-TreeState $f.Eap -IncludeTimes
    $beforeOutput = Get-TreeState $f.Output -IncludeTimes
    switch ($problem) {
        'chave-duplicada' { [IO.File]::AppendAllText($f.Values, "`n__ENDPOINT__=outro`n") }
        'chave-ausente' { Write-TestFile $f.Values '__ENDPOINT__=https://example.invalid' }
        'xml-invalido' { Write-TestFile $f.Template '<server><property value="__ENDPOINT__"></server>' }
    }
    Assert-Rejected { Invoke-EapPreparation -ConfigPath $f.ConfigPath -Apply } ('Entrada invalida aceita: ' + $problem)
    Assert ((Get-TreeState $f.Eap -IncludeTimes) -ceq $beforeTarget) ('Entrada invalida alterou servidor: ' + $problem)
    Assert ((Get-TreeState $f.Output -IncludeTimes) -ceq $beforeOutput) ('Entrada invalida perdeu consolidado anterior: ' + $problem)
}

foreach ($selection in @('switch', 'config')) {
    $f = New-PreparationFixture ('sql-' + $selection)
    $beforeTemplate = [IO.File]::ReadAllText($f.Template)
    if ($selection -eq 'config') { $f.Config.logSql = $true; Write-TestJson $f.ConfigPath $f.Config }
    $null = Invoke-EapPreparation -ConfigPath $f.ConfigPath -LogSql:($selection -eq 'switch')
    [xml]$xml = [IO.File]::ReadAllText($f.GeneratedXml)
    foreach ($logger in @(@('org.hibernate.SQL','DEBUG'), @('org.hibernate.type.descriptor.sql','TRACE'))) {
        $nodes = $xml.SelectNodes('//*[local-name()="logger" and @category="' + $logger[0] + '"]')
        Assert ($nodes.Count -eq 1) ('LogSql duplicou ou omitiu logger ' + $logger[0])
        Assert ($nodes[0].NamespaceURI -ceq 'urn:jboss:domain:logging:8.0') 'LogSql criou logger fora do namespace logging.'
        Assert ($nodes[0].SelectSingleNode('*[local-name()="level"]').GetAttribute('name') -ceq $logger[1]) ('Nivel incorreto: ' + $logger[0])
    }
    Assert (([IO.File]::ReadAllText($f.Template)) -ceq $beforeTemplate) 'LogSql alterou o template de origem.'
}

$f = New-PreparationFixture 'modulo-local-e-retomada'
$null = Invoke-EapPreparation -ConfigPath $f.ConfigPath -Apply
$installedJar = Join-Path $f.TargetModule 'driver.jar'
$installedModule = Join-Path $f.TargetModule 'module.xml'
Assert (Test-Path -LiteralPath $installedJar -PathType Leaf) 'JAR local nao foi instalado.'
Assert ((Get-FileHash -LiteralPath $installedJar -Algorithm SHA256).Hash -ceq (Get-FileHash -LiteralPath $f.Jar -Algorithm SHA256).Hash) 'Instalacao alterou o JAR local.'
[xml]$moduleXml = [IO.File]::ReadAllText($installedModule)
Assert ($moduleXml.DocumentElement.GetAttribute('name') -ceq 'org.example.driver') 'module.xml perdeu o nome configurado.'
Assert (-not $moduleXml.DocumentElement.HasAttribute('slot')) 'Schema module:1.9 rejeita atributo slot; descritor gerado nao pode usa-lo.'
Assert ($null -ne $moduleXml.SelectSingleNode('//*[local-name()="resource-root" and @path="driver.jar"]')) 'module.xml nao referencia o JAR instalado.'
Assert ($null -ne $moduleXml.SelectSingleNode('//*[local-name()="dependencies"]/*[local-name()="module" and @name="javax.api"]')) 'module.xml perdeu dependencia configurada.'
[IO.File]::SetLastWriteTimeUtc($installedJar, [datetime]'2020-01-02T03:04:05Z')
[IO.File]::SetLastWriteTimeUtc($installedModule, [datetime]'2020-01-02T03:04:05Z')
$beforeModule = Get-TreeState $f.TargetModule -IncludeTimes
$null = Invoke-EapPreparation -ConfigPath $f.ConfigPath -Apply
Assert ((Get-TreeState $f.TargetModule -IncludeTimes) -ceq $beforeModule) 'Retomada reescreveu modulo ja instalado e identico.'

$f = New-PreparationFixture 'modulo-slot-personalizado'
$f.Modules.modules[0].slot = 'legado'
Write-TestJson $f.ModulesPath $f.Modules
$null = Invoke-EapPreparation -ConfigPath $f.ConfigPath -Apply
$customDescriptor = Join-Path $f.Eap 'modules/org/example/driver/legado/module.xml'
[xml]$customXml = [IO.File]::ReadAllText($customDescriptor)
Assert ($customXml.DocumentElement.GetAttribute('name') -ceq 'org.example.driver:legado') 'Slot personalizado deve integrar a identidade do modulo no schema 1.9.'
Assert (-not $customXml.DocumentElement.HasAttribute('slot')) 'Slot personalizado gerou atributo incompativel com schema 1.9.'

foreach ($problem in @('jar-diferente', 'xml-diferente', 'modulo-incompleto')) {
    $f = New-PreparationFixture $problem
    $null = Invoke-EapPreparation -ConfigPath $f.ConfigPath -Apply
    $installedJar = Join-Path $f.TargetModule 'driver.jar'
    $installedModule = Join-Path $f.TargetModule 'module.xml'
    switch ($problem) {
        'jar-diferente' { Write-TestFile $installedJar 'conteudo preexistente diferente' }
        'xml-diferente' { Write-TestFile $installedModule '<module name="outro" xmlns="urn:jboss:module:1.9" />' }
        'modulo-incompleto' { [IO.File]::Delete($installedModule) }
    }
    $beforeTarget = Get-TreeState $f.Eap -IncludeTimes
    Assert-Rejected { Invoke-EapPreparation -ConfigPath $f.ConfigPath -Apply } ('Modulo divergente/incompleto aceito: ' + $problem)
    Assert ((Get-TreeState $f.Eap -IncludeTimes) -ceq $beforeTarget) ('Modulo divergente/incompleto foi sobrescrito: ' + $problem)
}

foreach ($mode in @('success', 'fail')) {
    $f = New-PreparationFixture ('maven-' + $mode)
    if ($mode -eq 'fail') {
        # Primeiro consolidado valido: a falha seguinte precisa vir do Maven,
        # sem ser mascarada pela protecao de uma saida desconhecida.
        $null = Invoke-EapPreparation -ConfigPath $f.ConfigPath
    }
    $mavenArtifact = [ordered]@{ source='maven'; coordinates='org.example:driver:1.0'; sha256=(Get-FileHash -LiteralPath $f.Jar -Algorithm SHA256).Hash }
    if ($mode -eq 'fail') {
        # Reproduz a falha no segundo modulo: o primeiro ja pode ser preparado,
        # mas nada deve ser instalado quando o download seguinte falha.
        $f.Modules.modules += [ordered]@{ name='org.example.second'; slot='main'; dependencies=@('javax.api'); artifacts=@($mavenArtifact) }
    } else { $f.Modules.modules[0].artifacts = @($mavenArtifact) }
    Write-TestJson $f.ModulesPath $f.Modules
    $beforeTarget = Get-TreeState $f.Eap -IncludeTimes
    $beforeOutput = Get-TreeState $f.Output -IncludeTimes
    & $module { param($m,$jar) $script:testMavenMode=$m; $script:testMavenJar=$jar } $mode $f.Jar
    try {
        if ($mode -eq 'fail') {
            Assert-Rejected { Invoke-EapPreparation -ConfigPath $f.ConfigPath -Apply } 'Download parcial Maven foi publicado.' 'Falha Maven sintetica'
            Assert ((Get-TreeState $f.Eap -IncludeTimes) -ceq $beforeTarget) 'Falha Maven publicou modulo parcial ou mudou servidor.'
            Assert ((Get-TreeState $f.Output -IncludeTimes) -ceq $beforeOutput) 'Falha Maven apagou consolidado anterior.'
        } else {
            $null = Invoke-EapPreparation -ConfigPath $f.ConfigPath -Apply
            $mavenJar = Join-Path $f.TargetModule 'driver-1.0.jar'
            Assert (Test-Path -LiteralPath $mavenJar -PathType Leaf) 'Artefato Maven nao foi instalado com nome coordenado.'
            Assert ((Get-FileHash -LiteralPath $mavenJar -Algorithm SHA256).Hash -ceq (Get-FileHash -LiteralPath $f.Jar -Algorithm SHA256).Hash) 'Publicacao Maven perdeu o conteudo obtido.'
        }
    } finally { & $module { $script:testMavenMode='forbidden'; $script:testMavenJar=$null } }
}

$f = New-PreparationFixture 'checksum-divergente'
$f.Modules.modules[0].artifacts[0].sha256 = ('0' * 64)
Write-TestJson $f.ModulesPath $f.Modules
$beforeTarget = Get-TreeState $f.Eap -IncludeTimes
Assert-Rejected { Invoke-EapPreparation -ConfigPath $f.ConfigPath -Apply } 'JAR com checksum divergente foi aceito.'
Assert ((Get-TreeState $f.Eap -IncludeTimes) -ceq $beforeTarget) 'Checksum divergente alterou o servidor.'

$f = New-PreparationFixture 'versao-divergente'
Write-TestFile (Join-Path $f.Eap 'version.txt') 'JBoss EAP - Version 7.4.12.GA'
Write-TestFile (Join-Path $f.Output 'preservar.txt') 'consolidado anterior'
$beforeTarget = Get-TreeState $f.Eap -IncludeTimes
$beforeOutput = Get-TreeState $f.Output -IncludeTimes
Assert-Rejected { Invoke-EapPreparation -ConfigPath $f.ConfigPath -Apply } 'Versao diferente do patch configurado foi aceita.'
Assert ((Get-TreeState $f.Eap -IncludeTimes) -ceq $beforeTarget) 'Versao divergente alterou o servidor.'
Assert ((Get-TreeState $f.Output -IncludeTimes) -ceq $beforeOutput) 'Versao divergente alterou o consolidado anterior.'

# Arquivos externos sao opt-in, copiados sem transformar bytes e nunca
# substituem um arquivo existente diferente no servidor.
$f = New-PreparationFixture 'arquivos-externos'
$secretFile = Join-Path $f.Base 'arquivos/aplicacao.jceks'
Write-TestFile $secretFile 'chave sintetica; nao e um keystore real'
$f.Config.files = @(@{source='arquivos/aplicacao.jceks';target='seguranca/aplicacao.jceks'})
Write-TestJson $f.ConfigPath $f.Config
$beforeTarget = Get-TreeState $f.Eap -IncludeTimes
$null = Invoke-EapPreparation -ConfigPath $f.ConfigPath
$relativeFile = 'standalone/configuration/seguranca/aplicacao.jceks'
Assert ([IO.File]::Exists((Join-Path $f.Output $relativeFile))) 'Arquivo externo nao entrou no consolidado.'
Assert ((Get-TreeState $f.Eap -IncludeTimes) -ceq $beforeTarget) 'Gerar arquivos externos alterou servidor.'
$null = Invoke-EapPreparation -ConfigPath $f.ConfigPath -Apply
$installed = Join-Path $f.Eap $relativeFile
Assert ((Get-FileHash $installed).Hash -eq (Get-FileHash $secretFile).Hash) 'Arquivo externo perdeu bytes.'
$beforeTarget = Get-TreeState $f.Eap -IncludeTimes
$beforeOutput = Get-TreeState $f.Output -IncludeTimes
$null = Invoke-EapPreparation -ConfigPath $f.ConfigPath -Apply
Assert ((Get-TreeState $f.Eap -IncludeTimes) -ceq $beforeTarget) 'Arquivo identico foi regravado.'
$beforeOutput = Get-TreeState $f.Output -IncludeTimes
Write-TestFile $secretFile 'outra chave sintetica'
Assert-Rejected { Invoke-EapPreparation -ConfigPath $f.ConfigPath -Apply } 'Arquivo externo divergente foi sobrescrito.' 'externo.*divergente'
Assert ((Get-TreeState $f.Eap -IncludeTimes) -ceq $beforeTarget) 'Divergencia alterou servidor.'
Assert ((Get-TreeState $f.Output -IncludeTimes) -ceq $beforeOutput) 'Divergencia alterou consolidado.'
foreach ($destination in @('../fora.jceks','C:/fora.jceks','seguranca/../fora.jceks','arquivo:stream','CON','pasta./arquivo','standalone-local.xml')) {
    $f.Config.files[0].target=$destination
    Write-TestJson $f.ConfigPath $f.Config
    Assert-Rejected { Invoke-EapPreparation -ConfigPath $f.ConfigPath } ('Destino externo inseguro aceito: '+$destination) 'Destino.*externo'
}
$f.Config.files=@(@{source='arquivos/ausente.jceks';target='ausente.jceks'})
Write-TestJson $f.ConfigPath $f.Config
Assert-Rejected { Invoke-EapPreparation -ConfigPath $f.ConfigPath } 'Arquivo ausente aceito.' 'externo.*ausente'
$f.Config.files=@(@{source='arquivos/aplicacao.jceks';target='igual.jceks'},@{source='arquivos/aplicacao.jceks';target='IGUAL.jceks'})
Write-TestJson $f.ConfigPath $f.Config
Assert-Rejected { Invoke-EapPreparation -ConfigPath $f.ConfigPath } 'Destino externo duplicado aceito.' 'externo.*duplicado'

# Recarregar elimina o mock do guard. Daqui em diante o guard real decide a
# partir apenas das fronteiras Windows simuladas, sem consultar a maquina.
Import-Module $modulePath -Force -DisableNameChecking
$module = Get-Module Eap74Preparation
& $module {
    $script:testProcesses = @()
    $script:testListeners = @()
    $script:testProcessError = $false
    $script:testPortError = $false
    $script:testProcessReads = 0
    $script:testActiveAfter = 0
    function script:Get-CimInstance { param($ClassName, $ErrorAction)
        if ($script:testProcessError) { throw 'Leitura de processos sintetica recusada.' }
        $script:testProcessReads++
        if ($script:testActiveAfter -gt 0 -and $script:testProcessReads -lt $script:testActiveAfter) { return }
        $script:testProcesses
    }
    function script:Get-NetTCPConnection { param($ErrorAction)
        if ($script:testPortError) { throw 'Leitura de portas sintetica recusada.' }
        $script:testListeners
    }
}
foreach ($scenario in @('java-ativo', 'javaw-ativo', 'cmd-iniciando', 'java-inacessivel', 'porta-http', 'porta-management', 'erro-processos', 'erro-portas', 'outro-java')) {
    $f = New-PreparationFixture ('guard-' + $scenario)
    $processes = @()
    $listeners = @()
    switch ($scenario) {
        'java-ativo' { $processes = @([pscustomobject]@{ Name='java.exe'; CommandLine=('java -jar "' + (Join-Path $f.Eap 'jboss-modules.jar') + '"') }) }
        'javaw-ativo' { $processes = @([pscustomobject]@{ Name='javaw.exe'; CommandLine=('javaw -jar "' + (Join-Path $f.Eap 'jboss-modules.jar') + '"') }) }
        'cmd-iniciando' { $processes = @([pscustomobject]@{ Name='cmd.exe'; CommandLine=('cmd /c "' + (Join-Path $f.Eap 'bin/standalone.bat') + '"') }) }
        'java-inacessivel' { $processes = @([pscustomobject]@{ Name='java.exe'; CommandLine=$null }) }
        'porta-http' { $listeners = @([pscustomobject]@{ State='Listen'; LocalPort=8180 }) }
        'porta-management' { $listeners = @([pscustomobject]@{ State='Listen'; LocalPort=10090 }) }
        'outro-java' {
            $processes = @([pscustomobject]@{ Name='java.exe'; CommandLine='java -jar C:\fixture-distinta\worker.jar' })
            $listeners = @([pscustomobject]@{ State='Listen'; LocalPort=25001 }, [pscustomobject]@{ State='Established'; LocalPort=8180 })
        }
    }
    & $module {
        param($p,$l,$s)
        $script:testProcesses=$p; $script:testListeners=$l
        $script:testProcessError=($s -eq 'erro-processos'); $script:testPortError=($s -eq 'erro-portas')
        $script:testProcessReads=0; $script:testActiveAfter=0
    } $processes $listeners $scenario
    $beforeTarget = Get-TreeState $f.Eap -IncludeTimes
    if ($scenario -eq 'outro-java') {
        $null = Invoke-EapPreparation -ConfigPath $f.ConfigPath
        Assert (Test-Path -LiteralPath $f.GeneratedXml -PathType Leaf) 'Processo Java distinto ou conexao sem listener bloqueou preparo.'
    } else {
        Assert-Rejected { Invoke-EapPreparation -ConfigPath $f.ConfigPath -Apply } ('Guard real nao recusou: ' + $scenario)
        Assert (-not (Test-Path -LiteralPath $f.Output)) ('Guard real publicou consolidado apesar de: ' + $scenario)
    }
    Assert ((Get-TreeState $f.Eap -IncludeTimes) -ceq $beforeTarget) ('Guard real alterou servidor: ' + $scenario)
}

# O servidor pode iniciar enquanto downloads/renderizacao sao feitos. A
# verificacao final deve impedir publicacao e preservar o consolidado anterior.
$f = New-PreparationFixture 'guard-servidor-inicia-durante-preparo'
& $module {
    $script:testProcesses=@(); $script:testListeners=@()
    $script:testProcessError=$false; $script:testPortError=$false
    $script:testProcessReads=0; $script:testActiveAfter=0
}
$null = Invoke-EapPreparation -ConfigPath $f.ConfigPath
$beforeTarget = Get-TreeState $f.Eap -IncludeTimes
$beforeOutput = Get-TreeState $f.Output -IncludeTimes
& $module {
    param($eap)
    $script:testProcesses=@([pscustomobject]@{ Name='java.exe'; CommandLine=('java -jar "' + (Join-Path $eap 'jboss-modules.jar') + '"') })
    $script:testProcessReads=0; $script:testActiveAfter=2
} $f.Eap
Assert-Rejected { Invoke-EapPreparation -ConfigPath $f.ConfigPath -Apply } 'Servidor iniciado durante o preparo nao impediu publicacao.' 'ativo'
Assert ((Get-TreeState $f.Eap -IncludeTimes) -ceq $beforeTarget) 'Inicio concorrente do servidor permitiu alterar arquivos ativos.'
Assert ((Get-TreeState $f.Output -IncludeTimes) -ceq $beforeOutput) 'Inicio concorrente do servidor perdeu consolidado anterior.'

# Um batch real, sem Java, representa o contrato do standalone.bat: consumir a
# mesma conf instalada e receber os argumentos escolhidos pelo launcher.
$f = New-PreparationFixture 'iniciar-servidor-pronto com espacos'
& $module {
    $script:testProcesses=@(); $script:testListeners=@()
    $script:testProcessError=$false; $script:testPortError=$false
    $script:testProcessReads=0; $script:testActiveAfter=0
}
$null = Invoke-EapPreparation -ConfigPath $f.ConfigPath -Apply
$batch = @'
@echo off
setlocal
call "%~dp0standalone.conf.bat"
echo FIXTURE_CONF=%~dp0standalone.conf.bat
echo FIXTURE_JAVA_HOME=%JAVA_HOME%
echo FIXTURE_JAVA=%JAVA%
echo FIXTURE_JAVA_OPTS=%JAVA_OPTS%
echo FIXTURE_JAVA_TOOL_OPTIONS=%JAVA_TOOL_OPTIONS%
echo FIXTURE_UNDERSCORE_JAVA_OPTIONS=%_JAVA_OPTIONS%
echo FIXTURE_JDK_JAVA_OPTIONS=%JDK_JAVA_OPTIONS%
echo FIXTURE_STANDALONE_CONF=%STANDALONE_CONF%
echo FIXTURE_RAW_ARGS=%*
:arguments
if "%~1"=="" goto finished
echo FIXTURE_ARG=%~1
shift
goto arguments
:finished
exit /b %EAP74_TEST_EXIT_CODE%
'@
Write-TestFile (Join-Path $f.Eap 'bin/standalone.bat') ($batch.Replace("`r`n", "`n").Replace("`n", "`r`n"))
$beforeTarget = Get-TreeState $f.Eap -IncludeTimes
$beforeInputs = Get-TreeState $f.Inputs -IncludeTimes
$beforeOutput = Get-TreeState $f.Output -IncludeTimes
$variables = @('JAVA_HOME','JAVA','JAVA_OPTS','JAVA_TOOL_OPTIONS','_JAVA_OPTIONS','JDK_JAVA_OPTIONS','JBOSS_HOME','JBOSS_BASE_DIR','JBOSS_CONFIG_DIR','JBOSS_LOG_DIR','STANDALONE_CONF','DEBUG','DEBUG_PORT','NOPAUSE','EAP74_TEST_EXIT_CODE')
$originalEnvironment = @{}
$syntheticEnvironment = @{}
foreach ($name in $variables) {
    $originalEnvironment[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
    $syntheticEnvironment[$name] = 'ambiente-anterior-' + $name
}
try {
    foreach ($name in $variables) { [Environment]::SetEnvironmentVariable($name, $syntheticEnvironment[$name], 'Process') }
    foreach ($mode in @('normal', 'admin-only', 'falha')) {
        $exitCode = if ($mode -eq 'falha') { '7' } else { '0' }
        $syntheticEnvironment['EAP74_TEST_EXIT_CODE'] = $exitCode
        $env:EAP74_TEST_EXIT_CODE = $exitCode
        if ($mode -eq 'falha') {
            Assert-Rejected { Start-EapPrepared -ConfigPath $f.ConfigPath } 'Launcher ocultou erro do processo filho.' 'codigo 7'
        } else {
            $captured = @(Start-EapPrepared -ConfigPath $f.ConfigPath -AdminOnly:($mode -eq 'admin-only'))
            Assert ($captured -contains ('FIXTURE_CONF=' + (Join-Path $f.Eap 'bin/standalone.conf.bat'))) 'Launcher nao consumiu a configuracao JVM instalada.'
            Assert ($captured -contains ('FIXTURE_JAVA_HOME=' + $f.Jdk)) 'Batch recebeu JDK diferente do preparo.'
            Assert ($captured -contains ('FIXTURE_JAVA=' + (Join-Path $f.Jdk 'bin/java.exe'))) 'Conf compartilhada perdeu caminho Java com espacos.'
            $javaOptions = @($captured | Where-Object { $_ -like 'FIXTURE_JAVA_OPTS=*' })
            Assert ($javaOptions.Count -eq 1 -and $javaOptions[0].Contains('-Xms128m') -and $javaOptions[0].Contains('-Xmx512m') -and $javaOptions[0].Contains('-Dfile.encoding=UTF-8')) 'Inicio nao usou opcoes JVM preparadas.'
            Assert (-not $javaOptions[0].Contains('ambiente-anterior')) 'Inicio herdou JAVA_OPTS concorrente.'
            foreach ($line in @('FIXTURE_JAVA_TOOL_OPTIONS=','FIXTURE_UNDERSCORE_JAVA_OPTIONS=','FIXTURE_JDK_JAVA_OPTIONS=','FIXTURE_STANDALONE_CONF=')) {
                Assert ($captured -contains $line) ('Override herdado vazou ao processo: ' + $line)
            }
            Assert ($captured -contains 'FIXTURE_ARG=-c' -and $captured -contains 'FIXTURE_ARG=standalone-local.xml') 'Inicio nao selecionou o XML preparado.'
            Assert ($captured -contains ('FIXTURE_ARG=-Djboss.server.base.dir=' + (Join-Path $f.Eap 'standalone'))) 'Caminho da base com espacos nao chegou como um argumento.'
            # cmd.exe separa '=' ao consultar %%1; %%* preserva o argumento
            # que o standalone.bat encaminha ao Java.
            $rawArguments = @($captured | Where-Object { $_ -like 'FIXTURE_RAW_ARGS=*' })
            Assert ($rawArguments.Count -eq 1 -and $rawArguments[0].Contains('-Djboss.socket.binding.port-offset=100')) 'Inicio perdeu portOffset configurado.'
            Assert (($captured -contains 'FIXTURE_ARG=--admin-only') -eq ($mode -eq 'admin-only')) 'Modo admin-only divergiu da escolha do launcher.'
        }
        foreach ($name in $variables) {
            Assert ([Environment]::GetEnvironmentVariable($name, 'Process') -ceq $syntheticEnvironment[$name]) ('Launcher nao restaurou variavel ' + $name + ' apos ' + $mode)
        }
        Assert ((Get-TreeState $f.Eap -IncludeTimes) -ceq $beforeTarget) ('Inicio alterou XML/conf/modulos do servidor: ' + $mode)
        Assert ((Get-TreeState $f.Inputs -IncludeTimes) -ceq $beforeInputs) ('Inicio alterou entradas do preparo: ' + $mode)
        Assert ((Get-TreeState $f.Output -IncludeTimes) -ceq $beforeOutput) ('Inicio alterou consolidado: ' + $mode)
    }
} finally {
    foreach ($name in $variables) { [Environment]::SetEnvironmentVariable($name, $originalEnvironment[$name], 'Process') }
}

# A segunda escrita do destino falha depois de o XML ter sido publicado. O
# rollback deve restaurar bytes e datas do servidor e a saida anterior.
$f = New-PreparationFixture 'rollback-na-segunda-publicacao'
$null = Invoke-EapPreparation -ConfigPath $f.ConfigPath
[IO.File]::AppendAllText($f.Values, "`n# Nova tentativa de preparo`n")
$beforeTarget = Get-TreeState $f.Eap -IncludeTimes
$beforeOutput = Get-TreeState $f.Output -IncludeTimes
& $module {
    $script:testOriginalAtomicWrite = (Get-Item Function:Write-EapAtomicFile).ScriptBlock
    $script:testAtomicWrites = 0
    function script:Write-EapAtomicFile { param([string]$Path, [byte[]]$Bytes)
        $script:testAtomicWrites++
        if ($script:testAtomicWrites -eq 2) { throw 'Falha sintetica na segunda publicacao atomica.' }
        & $script:testOriginalAtomicWrite $Path $Bytes
    }
}
try {
    Assert-Rejected { Invoke-EapPreparation -ConfigPath $f.ConfigPath -Apply } 'Falha de publicacao foi ocultada.' 'segunda publicacao atomica'
    Assert ((Get-TreeState $f.Eap -IncludeTimes) -ceq $beforeTarget) 'Rollback nao restaurou os arquivos e datas do servidor.'
    Assert ((Get-TreeState $f.Output -IncludeTimes) -ceq $beforeOutput) 'Rollback nao restaurou o consolidado anterior.'
    Assert (@(Get-ChildItem -LiteralPath $f.Base -Directory -Force | Where-Object Name -Like '.eap-preparo-*').Count -eq 0) 'Rollback deixou staging transitorio abandonado.'
} finally {
    & $module { Set-Item -Path Function:script:Write-EapAtomicFile -Value $script:testOriginalAtomicWrite }
}

# Falha apos publicar um arquivo externo deve retirar apenas os bytes desta
# tentativa e restaurar XML/JVM e consolidado anteriores.
$f = New-PreparationFixture 'rollback-arquivos-externos'
Write-TestFile (Join-Path $f.Base 'arquivos/primeiro.jceks') 'segredo sintetico 1'
Write-TestFile (Join-Path $f.Base 'arquivos/segundo.jceks') 'segredo sintetico 2'
$f.Config.files=@(@{source='arquivos/primeiro.jceks';target='externos/primeiro.jceks'},@{source='arquivos/segundo.jceks';target='externos/segundo.jceks'})
Write-TestJson $f.ConfigPath $f.Config
$null=Invoke-EapPreparation -ConfigPath $f.ConfigPath
$beforeTarget=Get-TreeState $f.Eap -IncludeTimes
$beforeOutput=Get-TreeState $f.Output -IncludeTimes
& $module {
    $script:testOriginalAtomicWrite=(Get-Item Function:Write-EapAtomicFile).ScriptBlock
    function script:Write-EapAtomicFile { param([string]$Path,[byte[]]$Bytes,[switch]$CreateOnly)
        if ($Path.EndsWith('segundo.jceks')) { throw 'Falha sintetica no segundo arquivo externo.' }
        & $script:testOriginalAtomicWrite $Path $Bytes -CreateOnly:$CreateOnly
    }
}
try {
    Assert-Rejected { Invoke-EapPreparation -ConfigPath $f.ConfigPath -Apply } 'Falha de arquivo externo ocultada.' 'segundo arquivo externo'
    Assert ((Get-TreeState $f.Eap -IncludeTimes) -ceq $beforeTarget) 'Rollback externo alterou servidor.'
    Assert ((Get-TreeState $f.Output -IncludeTimes) -ceq $beforeOutput) 'Rollback externo alterou consolidado.'
} finally { & $module { Set-Item Function:script:Write-EapAtomicFile $script:testOriginalAtomicWrite } }

Write-Output ('PASS PS' + $PSVersionTable.PSVersion.Major + ': preparo EAP 7.4 isolado, guard/recheck, XML/LogSql/JVM, modulos locais/Maven, arquivos externos, retomada, preservacao/rollback, patch e launcher batch com restauracao de ambiente.')

# O executor principal usa PS5.1. Quando disponivel, executar a mesma suite em
# PS7 dentro desta copia temporaria detecta diferencas reais de JSON/runtime.
# O processo PS7 nao entra novamente neste bloco, evitando recursao.
if ($PSVersionTable.PSVersion.Major -eq 5) {
    $powershellSeven = Get-Command pwsh.exe -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($powershellSeven) {
        $ps7Output = @(& $powershellSeven.Source -NoProfile -NonInteractive -File $PSCommandPath 2>&1)
        $ps7ExitCode = $LASTEXITCODE
        $ps7Output | Write-Output
        Assert ($ps7ExitCode -eq 0) ('Suite em PowerShell 7 falhou com codigo ' + $ps7ExitCode + '.')
        Assert (@($ps7Output | Where-Object { [string]$_ -like 'PASS PS7:*' }).Count -eq 1) 'Processo pwsh nao confirmou PASS PS7.'
    }
}
