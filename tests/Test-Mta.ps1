#requires -Version 5.1
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $root 'scripts/Harness.psm1') -Force
$area = Join-Path $root ('.harness/tests/' + [guid]::NewGuid().ToString('N'))
$fixture = Join-Path $area 'harness'
$app = Join-Path $area 'reactor com espaco'
$toolsRoot = Join-Path $area 'ferramentas'
$mtaHome = Join-Path $toolsRoot 'MTA em pasta permitida'
foreach ($dir in @($fixture, $app, "$app/modulo/src/main/java", "$app/.mvn", "$app/.git", "$app/target", "$toolsRoot/jdk/bin", "$toolsRoot/maven/bin", "$toolsRoot/rulesets/java/test")) { $null = New-Item -ItemType Directory -Path $dir -Force }
function Assert($condition, $message) { if (-not $condition) { throw $message } }
Set-Content "$app/pom.xml" '<project><modules><module>modulo</module></modules></project>'
Set-Content "$app/modulo/pom.xml" '<project/>'
Set-Content "$app/modulo/src/main/java/Exemplo.java" 'class Exemplo {}'
Set-Content "$app/.mvn/maven.config" '-Pteste'
Set-Content "$app/.git/config" 'git fixture'
Set-Content "$app/target/antigo.txt" 'nao copiar'
Set-Content "$toolsRoot/rulesets/java/regra.yaml" '- ruleID: fixture'
Set-Content "$toolsRoot/rulesets/java/test/sonda.yaml" 'nao copiar'
Set-Content "$toolsRoot/jdk/bin/java.exe" ''
Set-Content "$toolsRoot/jdk/bin/javac.exe" ''
Set-Content "$toolsRoot/maven/bin/mvn.cmd" ''
foreach ($directory in @('jdtls/config_win','jdtls/plugins','static-report','rulesets/java')) { $null = New-Item -ItemType Directory -Path (Join-Path $mtaHome $directory) -Force }
foreach ($file in @('windows-mta-cli.exe','java-external-provider.exe','fernflower.jar','static-report/index.html')) { Set-Content -LiteralPath (Join-Path $mtaHome $file) 'fixture, nao executar' }
Set-Content -LiteralPath (Join-Path $mtaHome 'rulesets/java/default.yaml') '- ruleID: default-fixture'
# Arquivos .exe sao marcadores; a fronteira nativa e simulada em memoria.
& (Get-Module Harness) {
    function script:Invoke-HarnessMtaTool {
        param([string]$Executable, [string[]]$Arguments, [string]$LogPath)
        if ($Arguments[0] -eq 'version') { return [pscustomobject]@{ExitCode=0; Output='fixture-mta'} }
        $inputRoot = $Arguments[[Array]::IndexOf($Arguments, '--input') + 1]
        $outputRoot = $Arguments[[Array]::IndexOf($Arguments, '--output') + 1]
        if (-not (Test-Path (Join-Path $inputRoot 'modulo/pom.xml'))) { return [pscustomobject]@{ExitCode=8; Output=''} }
        $null = New-Item -ItemType Directory -Path (Join-Path $outputRoot 'static-report') -Force
        [IO.File]::WriteAllText((Join-Path $outputRoot 'environment.txt'), $env:JAVA_HOME)
        [IO.File]::WriteAllText((Join-Path $outputRoot 'kantra-dir.txt'), [string]$env:KANTRA_DIR)
        Set-Content (Join-Path $outputRoot 'static-report/index.html') '<html>fixture only</html>'
        Set-Content (Join-Path $outputRoot 'output.yaml') '[]'
        if (Test-Path (Join-Path $inputRoot 'mutate.flag')) { Add-Content (Join-Path $inputRoot 'pom.xml') 'changed' }
        $exitCode = 0
        if (Test-Path (Join-Path $inputRoot 'fail.flag')) { $exitCode = 7 }
        [pscustomobject]@{ExitCode=$exitCode; Output=''}
    }
}
$config = Get-Content (Join-Path $root 'config/harness.example.json') -Raw | ConvertFrom-Json
$config.activeProject = 'api'
$config.repositories = @(@{name='api'; path=$app})
$config.tools.mtaExecutable = Join-Path $mtaHome 'windows-mta-cli.exe'
$config.tools.mtaJdkHome = "$toolsRoot/jdk"
$config.tools.mavenHome = "$toolsRoot/maven"
$config.mta.rulesPath = "$toolsRoot/rulesets/java"
$configPath = Join-Path $fixture 'config.json'
$config | ConvertTo-Json -Depth 8 | Set-Content $configPath -Encoding UTF8
$context = Read-HarnessConfig $configPath $fixture
Assert ($context.Config.mta.profile -ceq 'eap71-to-eap74-java8') 'Perfil de migracao ausente.'
# Um filtro aparentemente mais preciso pode excluir as regras Hibernate do baseline.
foreach ($case in @(
    @{field='sources'; value=@('eap7.1')},
    @{field='targets'; value=@('eap7.4')},
    @{field='targets'; value=@('eap8')},
    @{field='targets'; value=@('eap7','eap8')},
    @{field='mode'; value='source-only'},
    @{field='profile'; value='outro-perfil'}
)) {
    $candidate = $config | ConvertTo-Json -Depth 8 | ConvertFrom-Json
    $candidate.mta.($case.field) = $case.value
    Write-HarnessJson $configPath $candidate
    $rejected = $false
    try { Read-HarnessConfig $configPath $fixture | Out-Null } catch { $rejected = $true }
    Assert $rejected "Desvio do perfil deve ser recusado: $($case.field)."
}
# JSONs locais anteriores continuam no mesmo perfil, sem alterar o arquivo do usuario.
$legacy = $config | ConvertTo-Json -Depth 8 | ConvertFrom-Json
$legacy.mta.PSObject.Properties.Remove('profile')
$legacy.mta.PSObject.Properties.Remove('sources')
Write-HarnessJson $configPath $legacy
$legacyContext = Read-HarnessConfig $configPath $fixture
Assert ($legacyContext.Config.mta.profile -ceq 'eap71-to-eap74-java8' -and @($legacyContext.Config.mta.sources).Count -eq 0) 'Defaults legados devem preservar o perfil ensaiado.'
Write-HarnessJson $configPath $config
$context.Config.mta.rulesPath = $null
Assert ((Get-MtaRequirements $context) -eq (Join-Path $mtaHome 'rulesets/java')) 'Regras devem vir da pasta configurada, nao do perfil do usuario.'
$context.Config.mta.rulesPath = "$toolsRoot/rulesets/java"
$snapshot = New-MtaSnapshot $context
Assert (Test-Path (Join-Path $snapshot.Input 'modulo/pom.xml')) 'Reactor nao preservado.'
Assert (Test-Path (Join-Path $snapshot.Input '.mvn/maven.config')) 'Arquivos auxiliares nao preservados.'
Assert (-not (Test-Path (Join-Path $snapshot.Input '.git'))) 'Git nao deve ser copiado.'
Assert (-not (Test-Path (Join-Path $snapshot.Input 'target'))) 'Saida antiga nao deve ser copiada.'
Assert ($snapshot.Manifest.RuleFiles.Count -eq 1) 'Fixtures das regras nao devem ser analisadas.'
$arguments = $snapshot.Manifest.Arguments
Assert ($snapshot.Manifest.Migration.Source -ceq 'EAP 7.1' -and $snapshot.Manifest.Migration.Target -ceq 'EAP 7.4' -and $snapshot.Manifest.Migration.Java -eq 8 -and $snapshot.Manifest.Migration.Namespace -ceq 'javax') 'Intencao de migracao deve acompanhar a evidencia.'
Assert ($snapshot.Manifest.MtaProfile -ceq 'eap71-to-eap74-java8' -and @($snapshot.Manifest.MtaSources).Count -eq 0) 'Perfil e ausencia de filtro source devem ser registrados.'
Assert ($arguments[[Array]::IndexOf($arguments, '--target') + 1] -eq 'eap7') 'Target do ensaio anterior deve ser preservado.'
Assert ($arguments[[Array]::IndexOf($arguments, '--mode') + 1] -eq 'full') 'Modo full deve ser preservado.'
Assert ($arguments -contains '--enable-default-rulesets=false' -and $arguments -contains '--rules') 'Usar somente as regras explicitas.'
Assert ($arguments -notcontains '--source' -and $arguments -notcontains '--json-output') 'Nao reintroduzir filtros ou formato descartados no ensaio.'
$javaBefore = $env:JAVA_HOME
$pathBefore = $env:PATH
$kantraBefore = $env:KANTRA_DIR
$env:KANTRA_DIR = 'C:\caminho-herdado-que-nao-deve-ser-usado'
try {
$original = (Get-FileHash "$app/pom.xml").Hash
$result = Invoke-MtaAnalysis $context
Assert ($result.Status -eq 'SUCCEEDED') 'Analise valida nao concluiu.'
Assert ($result.Project -eq 'api') 'Projeto incorreto.'
Assert ((Get-Content -LiteralPath (Join-Path (Split-Path $result.ReportPath -Parent) '../kantra-dir.txt') -Raw) -eq $mtaHome) 'KANTRA_DIR deve apontar para a instalacao configurada.'
Assert ($env:KANTRA_DIR -eq 'C:\caminho-herdado-que-nao-deve-ser-usado') 'KANTRA_DIR herdado nao foi restaurado apos sucesso.'
Assert ((Get-Content (Join-Path (Split-Path $result.ReportPath -Parent) '../environment.txt') -Raw) -eq $context.Config.tools.mtaJdkHome) 'JDK nao foi isolado.'
Assert ($env:JAVA_HOME -ceq $javaBefore -and $env:PATH -ceq $pathBefore) 'Ambiente do pai alterado.'
$lastBefore = Get-Content (Join-Path $fixture '.harness/last-api.json') -Raw
Set-Content "$app/fail.flag" '1'
$failed = Invoke-MtaAnalysis $context
Assert ($failed.Status -eq 'FAILED' -and $failed.ExitCode -eq 7) 'Falha MTA foi ocultada.'
Assert ($env:KANTRA_DIR -eq 'C:\caminho-herdado-que-nao-deve-ser-usado') 'KANTRA_DIR herdado nao foi restaurado apos falha.'
Assert ((Get-Content (Join-Path $fixture '.harness/last-api.json') -Raw) -ceq $lastBefore) 'Falha nao pode substituir ultimo sucesso.'
Remove-Item -LiteralPath "$app/fail.flag"
Set-Content "$app/mutate.flag" '1'
$changed = Invoke-MtaAnalysis $context
Assert ($changed.Status -eq 'INPUT_CHANGED') 'Modificacao pelo analisador deve ser detectada.'
Assert ((Get-FileHash "$app/pom.xml").Hash -eq $original) 'Fonte real foi alterado.'
$lock = [IO.File]::Open((Join-Path $fixture '.harness/mta.lock'), 'OpenOrCreate', 'ReadWrite', 'None')
try {
    $rejected = $false
    try { Invoke-MtaAnalysis $context | Out-Null } catch { $rejected = $true }
    Assert $rejected 'Execucao concorrente nao foi recusada.'
} finally { $lock.Dispose() }
Remove-Item -LiteralPath (Join-Path $mtaHome 'java-external-provider.exe')
$rejected = $false
try { Get-MtaRequirements $context | Out-Null } catch { $rejected = $true }
Assert $rejected 'Instalacao incompleta deve ser recusada antes da analise.'
} finally { $env:KANTRA_DIR = $kantraBefore }
Write-Output 'PASS: instalacao portavel, ambiente, reactor, regras, erros, integridade e concorrencia (processo simulado).'
