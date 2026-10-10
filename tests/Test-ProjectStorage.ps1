#requires -Version 5.1
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$root=Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $root 'scripts/HarnessProject.psm1') -Force -DisableNameChecking
function Assert($condition,[string]$message) { if (-not $condition) { throw $message } }
function Reject([scriptblock]$action,[string]$message) {
    $failed=$false
    try { & $action | Out-Null } catch { $failed=$true }
    Assert $failed $message
}
$area=Join-Path $root ('.harness/tests/projeto-'+[guid]::NewGuid().ToString('N'))
$workspace=Join-Path $area 'harness com espacos'
$app=Join-Path $area 'aplicacao'
$null=[IO.Directory]::CreateDirectory($app)
$pom=Join-Path $app 'pom.xml'
[IO.File]::WriteAllText($pom,'<project xmlns="http://maven.apache.org/POM/4.0.0"><parent><artifactId>pai</artifactId></parent><artifactId>meu-servico</artifactId><dependencies><dependency><artifactId>outra</artifactId></dependency></dependencies></project>')
$project=Get-HarnessProjectStorage -Root $workspace -Pom $pom
Assert ($project.Name -ceq 'meu-servico') 'Nome deve vir do filho direto do POM.'
Assert ($project.Folder -ceq (Join-Path $workspace '.harness/projetos/meu-servico')) 'Pasta deve ser exatamente artifactId.'
Assert (-not (Test-Path -LiteralPath $workspace)) 'Resolver nao deve criar arquivos.'
$project=Initialize-HarnessProjectStorage -Root $workspace -Pom $pom
$association=Get-Content -LiteralPath $project.ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
Assert (@($association.PSObject.Properties.Name).Count -eq 2) 'Associacao deve conter somente pom e mta.'
Assert ($association.pom -ceq $pom) 'Associacao deve preservar POM selecionado.'
Assert ($project.PlanPath -ceq (Join-Path $project.Folder 'atual/planejamento/plano.md')) 'Plano deve ter caminho fixo.'
$again=Initialize-HarnessProjectStorage -Root $workspace -Pom $pom
Assert ($again.Folder -ceq $project.Folder) 'Repetir nao pode criar outro projeto.'
$other=Join-Path $area 'outro'
$null=[IO.Directory]::CreateDirectory($other)
Copy-Item -LiteralPath $pom -Destination (Join-Path $other 'pom.xml')
Reject { Initialize-HarnessProjectStorage -Root $workspace -Pom (Join-Path $other 'pom.xml') } 'Mesmo artifactId em outro Source deve exigir associacao explicita.'
foreach ($invalid in @('CON','../outro','a/b','nome.','${nome}','a:b','')) {
    [IO.File]::WriteAllText((Join-Path $other 'pom.xml'),('<project><artifactId>'+[Security.SecurityElement]::Escape($invalid)+'</artifactId></project>'))
    Reject { Get-HarnessProjectStorage -Root $workspace -Pom (Join-Path $other 'pom.xml') } ('Nome invalido aceito: '+$invalid)
}
[IO.File]::WriteAllText((Join-Path $other 'pom.xml'),'<project><parent><artifactId>pai</artifactId></parent></project>')
Reject { Get-HarnessProjectStorage -Root $workspace -Pom (Join-Path $other 'pom.xml') } 'Nao deve usar artifactId do parent.'
[IO.File]::WriteAllText((Join-Path $other 'pom.xml'),'<project><artifactId>modulo</artifactId></project>')
$module=Get-HarnessProjectStorage -Root $workspace -Pom (Join-Path $other 'pom.xml')
Assert ($module.Name -ceq 'modulo') 'POM do modulo deve definir seu proprio escopo.'
$relative=Get-HarnessProjectStorage -Root $area -Pom 'aplicacao/pom.xml'
Assert ($relative.Source -ceq $app) 'POM relativo deve usar Root, nunca o diretorio do terminal.'
$key=ConvertTo-HarnessFunctionalPath 'ruleset::regra/a%'
Assert ($key -ceq 'ruleset%3A%3Aregra%2Fa%25') 'Chave funcional deve ser reversivel e legivel, sem hash.'
Assert ([Uri]::UnescapeDataString($key) -ceq 'ruleset::regra/a%') 'Chave funcional deve preservar identidade.'
Assert ((ConvertTo-HarnessFunctionalPath 'A') -ine (ConvertTo-HarnessFunctionalPath 'a')) 'Chaves sensiveis a caixa devem permanecer distintas no Windows.'
foreach ($id in @('.','..','con','con.txt','termina.','regra::A','regra::a')) {
    $safe=ConvertTo-HarnessFunctionalPath $id
    Assert ([Uri]::UnescapeDataString($safe) -ceq $id) ('Nome reversivel: '+$id)
    Assert ($safe -notmatch '[. ]$|^(?i:CON)(?:\.|$)') ('Nome seguro no Windows: '+$safe)
}
$link=Get-HarnessSourceLink -From $project.PlanPath -Path $pom -Label 'POM'
Assert ($link -match '^\[POM\]\(<.+>\)$') 'Link deve ser Markdown direto e suportar espacos.'
Assert ($link -notmatch 'vscode:|snapshot|recibo') 'Link nao deve depender de IDE ou recibo.'
'PASS: identidade Maven, caminhos fixos, colisao, associacao, chave funcional e link direto.'
