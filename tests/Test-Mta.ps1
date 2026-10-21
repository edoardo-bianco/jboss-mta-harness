#requires -Version 5.1
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$root=Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $root 'scripts/Harness.psm1') -Force -DisableNameChecking
function Assert($condition,[string]$message) { if (-not $condition) { throw $message } }
$area=Join-Path $root ('.harness/tests/mta-corrente-'+[guid]::NewGuid().ToString('N').Substring(0,8))
$app=Join-Path $area 'app com espaco'; $fixture=Join-Path $area 'harness'; $installation=Join-Path $area 'mta'
foreach ($dir in @($app,$fixture,"$app/modulo","$app/.git","$app/target","$installation/bin","$installation/jdtls/config_win","$installation/jdtls/plugins","$installation/static-report","$installation/rulesets/java")) { $null=[IO.Directory]::CreateDirectory($dir) }
[IO.File]::WriteAllText((Join-Path $app 'pom.xml'),'<project><artifactId>api</artifactId><modules><module>modulo</module></modules></project>')
[IO.File]::WriteAllText((Join-Path $app 'modulo/pom.xml'),'<project><artifactId>modulo</artifactId></project>')
[IO.File]::WriteAllText((Join-Path $app '.git/config'),'fixture')
[IO.File]::WriteAllText((Join-Path $app 'target/velho'),'fixture')
foreach ($file in @('mta.exe','java-external-provider.exe','fernflower.jar','static-report/index.html','bin/java.exe','bin/javac.exe','bin/mvn.cmd','rulesets/java/regra.yaml')) { [IO.File]::WriteAllText((Join-Path $installation $file),'fixture') }
$config=Get-Content (Join-Path $root 'config/harness.example.json') -Raw | ConvertFrom-Json
$config.tools.mtaExecutable=Join-Path $installation 'mta.exe'; $config.tools.mtaJdkHome=$installation; $config.tools.mavenHome=$installation; $config.mta.rulesPath=Join-Path $installation 'rulesets/java'
$context=[pscustomobject]@{Root=$fixture;Active=[pscustomobject]@{name='apelido';label='Aplicacao';path=$app};Config=$config}
$module=Get-Module Harness
& $module {
    $script:attempt=0; $script:fail=$false; $script:mutate=$false; $script:editAssociation=$null
    function script:Invoke-HarnessMtaTool {
        param($Executable,$Arguments,$LogPath)
        if ($Arguments[0] -eq 'version') { return [pscustomobject]@{ExitCode=0;Output='fixture-mta'} }
        $script:attempt++
        $inputRoot=$Arguments[[Array]::IndexOf($Arguments,'--input')+1]
        $outputRoot=$Arguments[[Array]::IndexOf($Arguments,'--output')+1]
        if ($outputRoot -notmatch 'relatorios externos\\\.harness-mta-em-preparo\\[a-f0-9]{32}\\saida$') { throw 'Saida do analisador deve ficar inteiramente na raiz externa.' }
        if (-not (Test-Path (Join-Path $inputRoot 'modulo/pom.xml')) -or (Test-Path (Join-Path $inputRoot '.git')) -or (Test-Path (Join-Path $inputRoot 'target'))) { throw 'Entrada temporaria do agregador incorreta.' }
        if ($Arguments -contains '--source' -or $Arguments -notcontains '--enable-default-rulesets=false' -or $Arguments[[Array]::IndexOf($Arguments,'--target')+1] -cne 'eap7') { throw 'Perfil funcional MTA alterado.' }
        $report=Join-Path $outputRoot 'static-report'; $null=[IO.Directory]::CreateDirectory($report)
        [IO.File]::WriteAllText((Join-Path $report 'index.html'),('tentativa '+$script:attempt))
        [IO.File]::WriteAllText((Join-Path $report 'output.js'),'window["apps"] = [{"artifactId":"api","rulesets":[]}];')
        [IO.File]::WriteAllText((Join-Path $outputRoot 'output.yaml'),'[]')
        if ($script:attempt -eq 1) { [IO.File]::WriteAllText((Join-Path $report 'obsoleto.js'),'asset anterior') }
        [IO.File]::WriteAllText($LogPath,('console '+$script:attempt))
        if ($script:mutate) { [IO.File]::AppendAllText((Join-Path $inputRoot 'pom.xml'),'modificado') }
        if ($script:editAssociation) { [IO.File]::AppendAllText($script:editAssociation,"`n") }
        [pscustomobject]@{ExitCode=$(if ($script:fail) { 7 } else { 0 });Output=''}
    }
}
$beforeJava=$env:JAVA_HOME; $beforePath=$env:PATH; $beforeKantra=$env:KANTRA_DIR
$original=[IO.File]::ReadAllText((Join-Path $app 'pom.xml'))
$missing=$false
try { Invoke-MtaAnalysis $context | Out-Null } catch { $missing=$_.Exception.Message -match 'mta.runsPath' }
Assert $missing 'Sem raiz externa, orientar configurar mta.runsPath antes de executar.'
Assert ((& $module { $script:attempt }) -eq 0) 'Ausencia de configuracao nao pode iniciar MTA.'
$external=Join-Path $area 'relatorios externos'
$config.mta | Add-Member NoteProperty runsPath $external -Force
$first=Invoke-MtaAnalysis $context
Assert ($first.Status -eq 'SUCCEEDED') ('MTA simulado falhou: '+$first.Error)
Assert ($first.ReportPath.StartsWith((Join-Path $external 'app com espaco')+'\') -and $first.ReportPath -match '\\[0-9]{6}-[0-9]{6}-[0-9]{3}\\static-report\\index.html$') 'MTA deve usar raiz externa, pasta Source e data.'
Assert (-not (Test-Path (Join-Path $fixture '.harness/projetos/api/atual/diagnosticos/mta'))) 'Nao gerar relatorio na .harness.'
$association=Get-Content (Join-Path $fixture '.harness/projetos/api/projeto.json') -Raw | ConvertFrom-Json
Assert ($association.mta.diretorio -eq (Join-Path $external 'app com espaco')) 'Execucao deve associar origem externa sem fixar rodada.'
Assert (-not $first.PSObject.Properties['RunId']) 'Resultado nao exige RunId.'
$complete=[IO.File]::ReadAllText($first.ReportPath)
& $module { $script:fail=$true }
$failed=Invoke-MtaAnalysis $context
Assert ($failed.Status -eq 'FAILED' -and $failed.ExitCode -eq 7) 'Falha do MTA deve permanecer falha.'
Assert ([IO.File]::ReadAllText($first.ReportPath) -ceq $complete) 'Falha nao substitui ultimo diagnostico completo.'
Assert ((Get-LastMtaReport $context) -eq $first.ReportPath) 'Abertura usa ultimo completo mesmo apos falha.'
& $module { $script:fail=$false }
$next=Invoke-MtaAnalysis $context
Assert ($next.Status -eq 'SUCCEEDED' -and $next.ReportPath -ne $first.ReportPath) 'Novo sucesso cria outra pasta datada externa.'
Assert ((Get-LastMtaReport $context) -eq $next.ReportPath) 'Leitor deve encontrar novo sucesso automaticamente.'
Assert ([IO.File]::ReadAllText($first.ReportPath) -ceq $complete) 'Nova analise preserva relatorio externo anterior.'
Assert (-not (Test-Path (Join-Path (Split-Path $next.ReportPath) 'obsoleto.js'))) 'Assets antigos ausentes no novo conjunto devem sair.'
& $module { $script:mutate=$true }
$changed=Invoke-MtaAnalysis $context
Assert ($changed.Status -eq 'FAILED') 'Mudanca da entrada analisada impede publicacao.'
Assert ([IO.File]::ReadAllText((Join-Path $app 'pom.xml')) -ceq $original) 'Fonte original deve permanecer intacta.'
Assert ($env:JAVA_HOME -ceq $beforeJava -and $env:PATH -ceq $beforePath -and $env:KANTRA_DIR -ceq $beforeKantra) 'Ambiente deve ser restaurado.'
Assert (-not (Test-Path (Join-Path $fixture '.harness/projetos/api/temporarios'))) 'Entrada e recuperacao sao descartaveis.'
Assert (-not (Test-Path (Join-Path $fixture '.harness/runs'))) 'Nao criar historico/manifest/ponteiros.'
Assert (@(Get-ChildItem -LiteralPath (Join-Path $external '.harness-mta-em-preparo') -Directory).Count -eq 0) 'Saida parcial externa deve ser removida apos sucesso ou falha.'
$temporary=Join-Path $fixture '.harness/projetos/api/temporarios'
$null=[IO.Directory]::CreateDirectory($temporary)
$outside=Join-Path $area 'fora'; $null=[IO.Directory]::CreateDirectory($outside)
$junction=Join-Path $temporary 'mta'
$null=New-Item -ItemType Junction -Path $junction -Target $outside
try {
    $rejected=$false; try { Invoke-MtaAnalysis $context | Out-Null } catch { $rejected=$true }
    Assert $rejected 'Junction temporaria deve impedir analise.'
    $probe=Join-Path $area 'conferir-lock.ps1'
    $body=@'
param($Module,$Root,$Pom)
$ErrorActionPreference='Stop'
Import-Module $Module -DisableNameChecking
$project=Get-HarnessProjectStorage $Root $Pom
$lease=Enter-HarnessProjectAccess $project -ForOperation
try { 'LOCK-LIBERADO' } finally { $lease.ReleaseMutex(); $lease.Dispose() }
'@
    [IO.File]::WriteAllText($probe,$body)
    $output=& powershell.exe -NoProfile -File $probe -Module (Join-Path $root 'scripts/HarnessProject.psm1') -Root $fixture -Pom (Join-Path $app 'pom.xml') 2>&1 | Out-String
    Assert ($LASTEXITCODE -eq 0 -and $output.Contains('LOCK-LIBERADO')) 'Falha antes do preparo deve liberar mutex para outro processo.'
} finally { [IO.Directory]::Delete($junction) }

$attempts=& $module { $script:attempt }
foreach ($invalid in @((Join-Path $fixture 'relatorios'),(Join-Path $app 'relatorios'))) {
    $config.mta.runsPath=$invalid
    $rejected=$false; try { Invoke-MtaAnalysis $context | Out-Null } catch { $rejected=$true }
    Assert $rejected 'Raiz de relatorios interna ao harness ou Source deve ser recusada.'
}
Assert ((& $module { $script:attempt }) -eq $attempts) 'Destino invalido deve ser recusado antes da ferramenta.'
$config.mta.runsPath=$external
$associationPath=Join-Path $fixture '.harness/projetos/api/projeto.json'
& $module { param($path); $script:mutate=$false; $script:editAssociation=$path } $associationPath
$beforeAssociation=[IO.File]::ReadAllText($associationPath)
$count=@(Get-ChildItem -LiteralPath (Join-Path $external 'app com espaco') -Directory).Count
$conflict=Invoke-MtaAnalysis $context
Assert ($conflict.Status -eq 'FAILED' -and $conflict.Error -match 'editada durante') 'Edicao concorrente da associacao deve impedir publicacao.'
Assert ([IO.File]::ReadAllText($associationPath) -ceq ($beforeAssociation+"`n")) 'Edicao externa deve ser preservada.'
Assert (@(Get-ChildItem -LiteralPath (Join-Path $external 'app com espaco') -Directory).Count -eq $count) 'Conflito nao publica outra rodada externa.'

# Diagnostico interno historico nao pode ficar inacessivel na primeira falha externa.
Import-Module (Join-Path $root 'scripts/HarnessProject.psm1') -DisableNameChecking
$legacyRoot=Join-Path $area 'harness-antigo'
$legacy=Initialize-HarnessProjectStorage $legacyRoot (Join-Path $app 'pom.xml')
$oldReport=Join-Path $legacy.Folder 'atual/diagnosticos/mta/static-report/index.html'
$null=[IO.Directory]::CreateDirectory((Split-Path $oldReport))
[IO.File]::WriteAllText($oldReport,'diagnostico interno historico')
[IO.File]::WriteAllText((Join-Path (Split-Path $oldReport) 'output.js'),'window["apps"] = [{"artifactId":"api","rulesets":[]}];')
$legacyConfig=$config | ConvertTo-Json -Depth 10 | ConvertFrom-Json
$legacyConfig.mta.runsPath=Join-Path $area 'legado/relatorios externos'
$legacyContext=[pscustomobject]@{Root=$legacyRoot;Active=$context.Active;Config=$legacyConfig}
$legacyAssociation=[IO.File]::ReadAllText($legacy.ConfigPath)
& $module { $script:fail=$true; $script:editAssociation=$null }
$legacyFailure=Invoke-MtaAnalysis $legacyContext
Assert ($legacyFailure.Status -eq 'FAILED' -and [IO.File]::ReadAllText($legacy.ConfigPath) -ceq $legacyAssociation) 'Primeira falha externa deve preservar associacao anterior.'
Assert ((Get-LastMtaReport $legacyContext) -eq $oldReport) 'Diagnostico interno historico deve continuar acessivel apos falha externa.'
'PASS: MTA sempre externo, configuracao obrigatoria, ultima analise, falha preserva diagnostico, perfil e fontes.'
