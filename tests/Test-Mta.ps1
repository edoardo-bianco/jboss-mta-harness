#requires -Version 5.1
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $root 'scripts/Harness.psm1') -Force
$area = Join-Path $root ('.harness/tests/' + [guid]::NewGuid().ToString('N'))
$fixture = Join-Path $area 'harness'
$app = Join-Path $area 'reactor com espaco'
$toolsRoot = Join-Path $area 'ferramentas'
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
# Simula somente a fronteira nativa em memoria; nenhum executavel de fixture e criado.
& (Get-Module Harness) {
    function script:Invoke-HarnessMtaTool {
        param([string]$Executable, [string[]]$Arguments, [string]$LogPath)
        if ($Arguments[0] -eq 'version') { return [pscustomobject]@{ExitCode=0; Output='fixture-mta'} }
        $inputRoot = $Arguments[[Array]::IndexOf($Arguments, '--input') + 1]
        $outputRoot = $Arguments[[Array]::IndexOf($Arguments, '--output') + 1]
        if (-not (Test-Path (Join-Path $inputRoot 'modulo/pom.xml'))) { return [pscustomobject]@{ExitCode=8; Output=''} }
        $null = New-Item -ItemType Directory -Path (Join-Path $outputRoot 'static-report') -Force
        [IO.File]::WriteAllText((Join-Path $outputRoot 'environment.txt'), $env:JAVA_HOME)
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
$config.tools.mtaExecutable = Join-Path $env:SystemRoot 'System32/where.exe'
$config.tools.mtaJdkHome = "$toolsRoot/jdk"
$config.tools.mavenHome = "$toolsRoot/maven"
$config.mta.rulesPath = "$toolsRoot/rulesets/java"
$configPath = Join-Path $fixture 'config.json'
$config | ConvertTo-Json -Depth 8 | Set-Content $configPath -Encoding UTF8
$context = Read-HarnessConfig $configPath $fixture
$snapshot = New-MtaSnapshot $context
Assert (Test-Path (Join-Path $snapshot.Input 'modulo/pom.xml')) 'Reactor nao preservado.'
Assert (Test-Path (Join-Path $snapshot.Input '.mvn/maven.config')) 'Arquivos auxiliares nao preservados.'
Assert (-not (Test-Path (Join-Path $snapshot.Input '.git'))) 'Git nao deve ser copiado.'
Assert (-not (Test-Path (Join-Path $snapshot.Input 'target'))) 'Saida antiga nao deve ser copiada.'
Assert ($snapshot.Manifest.RuleFiles.Count -eq 1) 'Fixtures das regras nao devem ser analisadas.'
$arguments = $snapshot.Manifest.Arguments
Assert ($arguments[[Array]::IndexOf($arguments, '--target') + 1] -eq 'eap7') 'Target do ensaio anterior deve ser preservado.'
Assert ($arguments[[Array]::IndexOf($arguments, '--mode') + 1] -eq 'full') 'Modo full deve ser preservado.'
Assert ($arguments -contains '--enable-default-rulesets=false' -and $arguments -contains '--rules') 'Usar somente as regras explicitas.'
Assert ($arguments -notcontains '--source' -and $arguments -notcontains '--json-output') 'Nao reintroduzir filtros ou formato descartados no ensaio.'
$javaBefore = $env:JAVA_HOME
$pathBefore = $env:PATH
$original = (Get-FileHash "$app/pom.xml").Hash
$result = Invoke-MtaAnalysis $context
Assert ($result.Status -eq 'SUCCEEDED') 'Analise valida nao concluiu.'
Assert ($result.Project -eq 'api') 'Projeto incorreto.'
Assert ((Get-Content (Join-Path (Split-Path $result.ReportPath -Parent) '../environment.txt') -Raw) -eq $context.Config.tools.mtaJdkHome) 'JDK nao foi isolado.'
Assert ($env:JAVA_HOME -ceq $javaBefore -and $env:PATH -ceq $pathBefore) 'Ambiente do pai alterado.'
$lastBefore = Get-Content (Join-Path $fixture '.harness/last-api.json') -Raw
Set-Content "$app/fail.flag" '1'
$failed = Invoke-MtaAnalysis $context
Assert ($failed.Status -eq 'FAILED' -and $failed.ExitCode -eq 7) 'Falha MTA foi ocultada.'
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
Write-Output 'PASS: reactor, regras, ambiente, erros, integridade e concorrencia (processo simulado).'
