#requires -Version 5.1
# Executar pelo Invoke-HarnessTests.ps1 com HARNESS_TEST_EAP74_HOME e
# HARNESS_TEST_JDK8_HOME explicitos. Somente le as ferramentas dessas instalacoes;
# compila um JAR sintetico e carrega os modulos na copia temporaria do runner.
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$eap=$env:HARNESS_TEST_EAP74_HOME
$jdk=$env:HARNESS_TEST_JDK8_HOME
if (-not $eap -or -not $jdk) { throw 'Informe HARNESS_TEST_EAP74_HOME e HARNESS_TEST_JDK8_HOME para este ensaio explicito.' }
$java=Join-Path $jdk 'bin/java.exe'
$javac=Join-Path $jdk 'bin/javac.exe'
$jar=Join-Path $jdk 'bin/jar.exe'
$loader=Join-Path $eap 'jboss-modules.jar'
foreach ($path in @($java,$javac,$jar,$loader)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Ferramenta ausente: $path" }
}
$area=Join-Path $root ('.harness/tests/module-loading-'+[guid]::NewGuid().ToString('N'))
$classes=Join-Path $area 'classes'
$null=[IO.Directory]::CreateDirectory($classes)
$source=Join-Path $area 'ModuleProbe.java'
[IO.File]::WriteAllText($source,'public class ModuleProbe { public static void main(String[] args) { System.out.println("HARNESS_MODULE_LOADED"); } }')
& $javac -encoding UTF-8 -d $classes $source
if ($LASTEXITCODE -ne 0) { throw 'Compilacao do probe falhou.' }
$artifact=Join-Path $area 'probe.jar'
& $jar cf $artifact -C $classes .
if ($LASTEXITCODE -ne 0) { throw 'Criacao do JAR sintetico falhou.' }
# Usar LocalModuleLoader diretamente: a opcao -dep/-class trata ':' como
# caminho Windows antes da busca modular nesta versao do launcher.
$driver=Join-Path $area 'LoaderProbe.java'
[IO.File]::WriteAllText($driver,'public class LoaderProbe { public static void main(String[] args) throws Exception { org.jboss.modules.LocalModuleLoader loader = new org.jboss.modules.LocalModuleLoader(new java.io.File[]{new java.io.File(args[0])}); loader.loadModule(args[1]).getClassLoader().loadClass("ModuleProbe").getMethod("main", String[].class).invoke(null, (Object)new String[0]); } }')
& $javac -encoding UTF-8 -cp $loader -d $classes $driver
if ($LASTEXITCODE -ne 0) { throw 'Compilacao do carregador de teste falhou.' }
$modulesPath=Join-Path $area 'modulos.json'
$manifest=@{modules=@(
    @{name='org.example.probe';slot='main';dependencies=@();artifacts=@(@{source='file';path=$artifact;sha256=(Get-FileHash $artifact -Algorithm SHA256).Hash})},
    @{name='org.example.probe';slot='legado';dependencies=@();artifacts=@(@{source='file';path=$artifact;sha256=(Get-FileHash $artifact -Algorithm SHA256).Hash})}
)}
[IO.File]::WriteAllText($modulesPath,($manifest | ConvertTo-Json -Depth 8))
$stage=Join-Path $area 'stage'
$config=[pscustomobject]@{modules=$modulesPath;output=(Join-Path $area 'output')}
Import-Module (Join-Path $root 'doc/estrategia-migracao-ambientes-jboss-eap-7.4/jboss-eap7.4-configuracao/scripts/Eap74Preparation.psm1') -Force -DisableNameChecking
$preparation=Get-Module Eap74Preparation
$null=& $preparation { param($c,$s) New-EapModules $c $s } $config $stage
foreach ($identity in @('org.example.probe','org.example.probe:legado')) {
    $oldPreference=$ErrorActionPreference
    try {
        $ErrorActionPreference='Continue'
        $output=@(& $java -cp ($loader+';'+$classes) LoaderProbe (Join-Path $stage 'modules') $identity 2>&1)
        $exitCode=$LASTEXITCODE
    } finally { $ErrorActionPreference=$oldPreference }
    if ($exitCode -ne 0 -or 'HARNESS_MODULE_LOADED' -notin $output) { throw "Carregamento real falhou para ${identity}: $($output -join ' ')" }
}
Write-Output 'PASS: descritores main e slot personalizado gerados carregam classe real no JBoss Modules; nenhum servidor iniciado.'
