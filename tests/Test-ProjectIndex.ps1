#requires -Version 5.1
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$root=Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $root 'scripts/HarnessProjectIndex.psm1') -Force -DisableNameChecking
function Assert($value,[string]$message) { if (-not $value) { throw $message } }
$area=Join-Path $root ('.harness/tests/indice-corrente-'+[guid]::NewGuid().ToString('N').Substring(0,8))
$context=[pscustomobject]@{Root=$area;Projects=@()}
foreach ($name in @('servico','modulo')) {
    $app=Join-Path $area $name; $null=[IO.Directory]::CreateDirectory($app)
    [IO.File]::WriteAllText((Join-Path $app 'pom.xml'),('<project><artifactId>'+$name+'</artifactId></project>'))
    $context.Projects+=@([pscustomobject]@{name=('alias-'+$name);path=$app})
}
$first=New-HarnessProjectIndex $context -UpdateMigration
Assert ($first.IndexPath -eq (Join-Path $area '.harness/indices/projetos.md')) 'Indice geral em destino estavel.'
Assert ($first.Warnings.Count -eq 2) 'Sem MTA, indice deve informar ausencia por projeto.'
$registry=Join-Path $area '.harness/projetos/servico/migracao.md'
$human=[IO.File]::ReadAllText($registry)+"`nDecisao humana preservada.`n"
[IO.File]::WriteAllText($registry,$human)
[IO.File]::Delete($first.IndexPath)
$second=New-HarnessProjectIndex $context -UpdateMigration
Assert ([IO.File]::ReadAllText($registry) -ceq $human) 'Reconstruir indice sem MTA nao altera registro humano.'
Assert (@(Get-ChildItem -LiteralPath (Split-Path $second.IndexPath) -File).Count -eq 1) 'Indice sem copias datadas.'
Assert ([IO.File]::ReadAllText($second.IndexPath).Contains('../projetos/servico/indice.md')) 'Link navega diretamente ao projeto.'
Assert (-not (Test-Path (Join-Path $area '.harness/planning'))) 'Nao procurar nem criar planejamento legado.'
[IO.File]::WriteAllText((Join-Path $area 'modulo/pom.xml'),'<project><artifactId>servico</artifactId></project>')
$failed=$false; try { New-HarnessProjectIndex $context | Out-Null } catch { $failed=$true }
Assert $failed 'Colisao de artifactId deve interromper, sem mesclar projetos.'
'PASS: indice geral corrente, POM literal, ausencia de MTA, preservacao e colisao.'
