#requires -Version 5.1
$ErrorActionPreference='Stop'; Set-StrictMode -Version Latest
$root=Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $root 'scripts/HarnessProjectIndex.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $root 'scripts/HarnessProject.psm1') -DisableNameChecking
function Assert($value,[string]$message) { if (-not $value) { throw $message } }
function Write-File($path,$text) {
    $null=[IO.Directory]::CreateDirectory((Split-Path $path -Parent))
    [IO.File]::WriteAllText($path,$text,(New-Object Text.UTF8Encoding($false)))
}
function Add-Report($base,$folder,$artifact,$date) {
    $entry=Join-Path $base ($folder+'/index.html')
    Write-File $entry '<html>MTA sintetico</html>'
    $apps=@(@{artifactId=$artifact;generatedAt=$date;rulesets=@(@{name='java';violations=@{regra=@{description='Conferir';category='mandatory';incidents=@()}}})})
    Write-File (Join-Path (Split-Path $entry) 'output.js') ('window["apps"] = '+(ConvertTo-Json -InputObject $apps -Depth 10 -Compress)+';')
    return $entry
}
$area=Join-Path $root ('.harness/tests/indice-mta-'+[guid]::NewGuid().ToString('N').Substring(0,8))
$workspace=Join-Path $area 'workspace'
$external=Join-Path $area 'relatorios externos'
$context=[pscustomobject]@{Root=$workspace;Config=[pscustomobject]@{mta=[pscustomobject]@{runsPath='../relatorios externos'}};Projects=@()}
foreach ($pair in @(@('SIMTR-api','simtr-parent'),@('Outro-servico','outro-artifact'))) {
    $source=Join-Path $area ('fontes/'+$pair[0])
    Write-File (Join-Path $source 'pom.xml') ('<project><artifactId>'+$pair[1]+'</artifactId></project>')
    $context.Projects+=@([pscustomobject]@{name=('alias-'+$pair[1]);path=$source})
    $null=Add-Report $external ($pair[0]+'/nome-maior') $pair[1] '2026-09-30T07:57:02-03:00'
    $null=Add-Report $external ($pair[0]+'/nome-menor') $pair[1] '2026-10-01T07:57:02-03:00'
}
# Reproduz indices ja criados com null; tambem cobre associacao ainda inexistente.
$api=Initialize-HarnessProjectStorage $workspace (Join-Path $context.Projects[0].path 'pom.xml')
$result=New-HarnessProjectIndex $context -UpdateMigration
Assert ($result.Warnings.Count -eq 0) 'Indice deve usar a raiz externa configurada para todos os projetos.'
foreach ($project in $result.Projects) {
    $sourceName=Split-Path $project.Source -Leaf
    $config=Get-Content -LiteralPath $project.ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
    Assert ($config.mta.diretorio -eq (Join-Path $external $sourceName)) 'Associar pasta da aplicacao, nao artifactId nem rodada datada.'
    $mta=Read-HarnessProjectMta $project
    Assert ($mta.ReportPath -eq (Join-Path $external ($sourceName+'/nome-menor/index.html'))) 'Selecionar ultimo relatorio pela data, nao pelo nome da pasta.'
    Assert ((Get-Content -LiteralPath $project.MigrationPath -Raw) -match 'java::regra') 'Indice deve inicializar registro usando MTA externo.'
}
$association=[IO.File]::ReadAllText($api.ConfigPath)
$next=Add-Report $external 'SIMTR-api/nova-rodada' 'simtr-parent' '2026-10-02T07:57:02-03:00'
$null=New-HarnessProjectIndex $context -UpdateMigration
Assert ((Read-HarnessProjectMta $api).ReportPath -eq $next) 'Nova rodada deve ser descoberta sem editar associacao.'
Assert ([IO.File]::ReadAllText($api.ConfigPath) -ceq $association) 'Atualizar indice preserva associacao existente.'
Assert (-not (Test-Path -LiteralPath (Join-Path $api.Folder 'atual/diagnosticos/mta'))) 'MTA externo nao pode ser copiado.'

# Origem explicita continua prevalecendo, mesmo se indisponivel.
$manual=Join-Path $area 'origem manual'
$manualReport=Add-Report $manual 'rodada' 'simtr-parent' '2020-10-01T00:00:00Z'
$manualConfig=ConvertFrom-Json $association
$manualConfig.mta.diretorio=$manual
Publish-HarnessProjectFiles $api @{'projeto.json'=($manualConfig | ConvertTo-Json)}
$manualBytes=[IO.File]::ReadAllText($api.ConfigPath)
$null=New-HarnessProjectIndex $context -UpdateMigration
Assert ((Read-HarnessProjectMta $api).ReportPath -eq $manualReport -and [IO.File]::ReadAllText($api.ConfigPath) -ceq $manualBytes) 'Escolha externa explicita nao pode ser trocada por recencia.'
$manualConfig.mta.diretorio=Join-Path $area 'inexistente'
Publish-HarnessProjectFiles $api @{'projeto.json'=($manualConfig | ConvertTo-Json)}
$missingResult=New-HarnessProjectIndex $context
Assert (($missingResult.Warnings -join ' ') -match 'inexistente') 'Origem explicita ausente nao usa fallback global.'

foreach ($case in @('ausente','invalido','outra-aplicacao')) {
    $source=Join-Path $area ('fontes/'+$case)
    Write-File (Join-Path $source 'pom.xml') ('<project><artifactId>'+$case+'</artifactId></project>')
    if ($case -eq 'invalido') { Write-File (Join-Path $external ($case+'/rodada/index.html')) '<html>incompleto</html>' }
    if ($case -eq 'outra-aplicacao') { $null=Add-Report $external ($case+'/rodada') 'nao-corresponde' '2026-10-10T00:00:00Z' }
    $negative=[pscustomobject]@{Root=$workspace;Config=$context.Config;Projects=@([pscustomobject]@{name=$case;path=$source})}
    $result=New-HarnessProjectIndex $negative
    $config=Get-Content -LiteralPath $result.Projects[0].ConfigPath -Raw | ConvertFrom-Json
    Assert ($result.Warnings.Count -gt 0 -and $null -eq $config.mta.diretorio) ('Origem '+$case+' deve ser informada sem associacao ficticia.')
}
$ambiguous=[pscustomobject]@{Root=$workspace;Config=$context.Config;Projects=@()}
foreach ($id in @('um','dois')) {
    $source=Join-Path $area ($id+'/mesmo-nome')
    Write-File (Join-Path $source 'pom.xml') ('<project><artifactId>'+$id+'</artifactId></project>')
    $ambiguous.Projects+=@([pscustomobject]@{name=$id;path=$source})
}
$null=Add-Report $external 'mesmo-nome/rodada' 'um' '2026-10-10T00:00:00Z'
$result=New-HarnessProjectIndex $ambiguous
Assert ($result.Warnings.Count -eq 2 -and ($result.Warnings -join ' ') -match 'ambiguo') 'Duas fontes com mesmo nome nao podem compartilhar relatorios automaticamente.'
$reservedSource=Join-Path $area 'fontes/.harness-mta-em-preparo'
Write-File (Join-Path $reservedSource 'pom.xml') '<project><artifactId>reservado</artifactId></project>'
$null=Add-Report $external '.harness-mta-em-preparo/rodada' 'reservado' '2026-10-10T00:00:00Z'
$reserved=[pscustomobject]@{Root=$workspace;Config=$context.Config;Projects=@([pscustomobject]@{name='reservado';path=$reservedSource})}
$result=New-HarnessProjectIndex $reserved
$config=Get-Content -LiteralPath $result.Projects[0].ConfigPath -Raw | ConvertFrom-Json
Assert (($result.Warnings -join ' ') -match 'reservado' -and $null -eq $config.mta.diretorio) 'Nome Source reservado nao pode expor relatorios em preparo.'
'PASS: associacao externa geral por pasta Source, null existente, ultima rodada e repeticao.'
