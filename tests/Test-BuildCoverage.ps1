#requires -Version 5.1
param(
    [Parameter(Mandatory=$true)][string]$Jdk8Home,
    [Parameter(Mandatory=$true)][string]$MavenHome
)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $root 'scripts/Harness.psm1') -Force
Import-Module (Join-Path $root 'scripts/HarnessBuild.psm1') -Force
function Assert($condition, $message) { if (-not $condition) { throw $message } }
$area = Join-Path $root ('.harness/tests/coverage-' + [guid]::NewGuid().ToString('N'))
$app = Join-Path $area 'app'
$main = Join-Path $app 'src/main/java/fixture'
$test = Join-Path $app 'src/test/java/fixture'
foreach ($dir in @($main, $test)) { $null = New-Item -ItemType Directory -Path $dir -Force }
$pom = @'
<project xmlns="http://maven.apache.org/POM/4.0.0">
  <modelVersion>4.0.0</modelVersion>
  <groupId>local.harness.test</groupId><artifactId>coverage-warning</artifactId><version>1</version>
  <properties><maven.compiler.source>1.8</maven.compiler.source><maven.compiler.target>1.8</maven.compiler.target></properties>
  <dependencies><dependency><groupId>junit</groupId><artifactId>junit</artifactId><version>4.13.2</version><scope>test</scope></dependency></dependencies>
  <build><plugins>
    <plugin><groupId>org.apache.maven.plugins</groupId><artifactId>maven-resources-plugin</artifactId><version>3.3.1</version></plugin>
    <plugin><groupId>org.apache.maven.plugins</groupId><artifactId>maven-compiler-plugin</artifactId><version>3.14.1</version></plugin>
    <plugin><groupId>org.apache.maven.plugins</groupId><artifactId>maven-surefire-plugin</artifactId><version>3.5.4</version></plugin>
    <plugin><groupId>org.apache.maven.plugins</groupId><artifactId>maven-jar-plugin</artifactId><version>3.4.2</version></plugin>
    <plugin><groupId>org.jacoco</groupId><artifactId>jacoco-maven-plugin</artifactId><version>0.8.12</version>
      <executions>
        <execution><goals><goal>prepare-agent</goal></goals></execution>
        <execution><id>coverage</id><phase>verify</phase><goals><goal>report</goal><goal>check</goal></goals>
          <configuration><rules><rule><element>BUNDLE</element><limits>
            <limit><counter>LINE</counter><value>COVEREDRATIO</value><minimum>0.85</minimum></limit>
          </limits></rule></rules></configuration>
        </execution>
      </executions>
    </plugin>
  </plugins></build>
</project>
'@
Set-Content -LiteralPath (Join-Path $app 'pom.xml') -Value $pom -Encoding UTF8
$source = @'
package fixture;
public class Example {
    public static int used() { return 1; }
    public static int notCoveredA() { return 2; }
    public static int notCoveredB() { return 3; }
    public static int notCoveredC() { return 4; }
}
'@
$testSource = 'package fixture; public class ExampleTest { @org.junit.Test public void verifies() { org.junit.Assert.assertEquals(1, Example.used()); } }'
Set-Content -LiteralPath (Join-Path $main 'Example.java') -Value $source -Encoding ASCII
Set-Content -LiteralPath (Join-Path $test 'ExampleTest.java') -Value $testSource -Encoding ASCII
$config = Get-Content (Join-Path $root 'config/harness.example.json') -Raw | ConvertFrom-Json
$config.repositories = @(@{name='coverage'; path=$app})
$config.activeProject = 'coverage'
$config.tools.applicationJdk8Home = $Jdk8Home
$config.tools.applicationMavenHome = $MavenHome
$fixtureHarness = Join-Path $area 'harness'
$configPath = Join-Path $fixtureHarness 'config.json'
Write-HarnessJson $configPath $config
$context = Read-HarnessConfig $configPath $fixtureHarness
$warning = Invoke-ApplicationBuild $context 'clean verify'
Assert ($warning.Status -eq 'SUCCEEDED' -and $warning.ExitCode -eq 0) "Cobertura baixa reprovou: $($warning.LogPath)"
$log = Get-Content -LiteralPath $warning.LogPath -Raw
Assert ($log -match '\[WARNING\].*Rule violated') 'JaCoCo nao exibiu aviso de cobertura.'
[xml]$report = Get-Content -LiteralPath (Join-Path $app 'target/site/jacoco/jacoco.xml') -Raw
$lines = $report.report.counter | Where-Object { $_.type -eq 'LINE' }
$ratio = [double]$lines.covered / ([double]$lines.covered + [double]$lines.missed)
Assert ($ratio -lt 0.85) 'Fixture nao reproduziu cobertura abaixo da meta.'
Set-Content -LiteralPath (Join-Path $test 'ExampleTest.java') -Value ($testSource.Replace('assertEquals(1,', 'assertEquals(9,')) -Encoding ASCII
$failedTest = Invoke-ApplicationBuild $context 'clean verify'
Assert ($failedTest.Status -eq 'FAILED' -and $failedTest.ExitCode -ne 0) 'Teste reprovado virou sucesso.'
Set-Content -LiteralPath (Join-Path $main 'Example.java') -Value 'package fixture; public class Example { syntax error }' -Encoding ASCII
$failedCompile = Invoke-ApplicationBuild $context 'clean verify'
Assert ($failedCompile.Status -eq 'FAILED' -and $failedCompile.ExitCode -ne 0) 'Erro de compilacao virou sucesso.'
Write-Output "PASS: JaCoCo real com cobertura $($ratio * 100)% gera aviso/exit 0; falhas de teste e compilacao preservadas. Evidencias: $area"
