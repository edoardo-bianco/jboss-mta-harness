#requires -Version 5.1
$ErrorActionPreference='Stop'; Set-StrictMode -Version Latest
$root=Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $root 'scripts/HarnessProjectIndex.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $root 'scripts/HarnessIssues.psm1') -DisableNameChecking
Import-Module (Join-Path $root 'scripts/HarnessProject.psm1') -DisableNameChecking
function Assert($value,[string]$message) { if (-not $value) { throw $message } }
function Write-File($path,$text) {
    $null=[IO.Directory]::CreateDirectory((Split-Path $path -Parent))
    [IO.File]::WriteAllText($path,$text,(New-Object Text.UTF8Encoding($false)))
}
$area=Join-Path $root ('.harness/tests/indice-manual-'+[guid]::NewGuid().ToString('N').Substring(0,8))
$external=Join-Path $area 'mta-externo'
$context=[pscustomobject]@{Root=(Join-Path $area 'workspace');Config=[pscustomobject]@{mta=[pscustomobject]@{runsPath=$external}};Projects=@()}
foreach ($name in @('com-mta','sem-mta')) {
    $source=Join-Path $area ('fontes/'+$name)
    Write-File (Join-Path $source 'pom.xml') ('<project><artifactId>'+$name+'</artifactId></project>')
    $context.Projects+=@([pscustomobject]@{name=$name;path=$source})
}
$report=Join-Path $external 'com-mta/rodada/index.html'
Write-File $report '<html>MTA sintetico</html>'
$catalog=Join-Path (Split-Path $report) 'output.js'
$apps=@(@{artifactId='com-mta';rulesets=@(@{name='java';violations=@{
    regra=@{description='Regra MTA';category='mandatory';incidents=@(@{},@{})}
}})})
Write-File $catalog ('window["apps"] = '+(ConvertTo-Json -InputObject $apps -Depth 10 -Compress)+';')
$catalogBefore=[IO.File]::ReadAllText($catalog)
$first=New-HarnessProjectIndex $context -UpdateMigration
$p=@($first.Projects | Where-Object Name -EQ 'com-mta')[0]
$q=@($first.Projects | Where-Object Name -EQ 'sem-mta')[0]
$a=Register-HarnessManualIssue $p DEV-DEPLOY 'Falha de deploy'
$null=Register-HarnessManualIssue $p DEV-RUNTIME 'Falha em execucao'
$b=Register-HarnessManualIssue $q DEV-DEPLOY 'Falha sem MTA'
$ficha=[IO.File]::ReadAllText($a.FichaPath)+"`nNota humana da investigacao.`n"
Write-File $a.FichaPath $ficha
$registry=[IO.File]::ReadAllText($p.MigrationPath)
foreach ($update in @($false,$true)) {
    $index=New-HarnessProjectIndex $context -UpdateMigration:$update
    $text=[IO.File]::ReadAllText($index.IndexPath)
    $row=@($text -split '\r?\n' | Where-Object { $_ -match '^\| \[com-mta\]' })[0]
    $missing=@($text -split '\r?\n' | Where-Object { $_ -match '^\| \[sem-mta\]' })[0]
    Assert ($row.Contains('MTA: 1 / 2<br>Manuais: 2 / -') -and $row.Contains('manual: 2 / -')) 'Projeto misto deve separar MTA e manual na celula e categorias.'
    Assert ($missing.Contains('MTA: -<br>Manuais: 1 / -') -and $missing.Contains('manual: 1 / -')) 'Manual deve aparecer mesmo sem MTA.'
    Assert ($text.Contains('| manual | 3 | - |') -and $text.Contains('Issues manuais registradas: 3, fora dos totais MTA.')) 'Somar manuais por projeto, sem ocorrencias inventadas.'
    Assert ($text.Contains('1 issues / 2 ocorrencias') -and $text.Contains('| mandatory | 1 | 2 |')) 'Totais MTA devem permanecer independentes.'
    Assert ($text.Contains('Registros legiveis: 2 de 2 projetos.')) 'Cobertura manual deve ser explicita.'
    Assert ([IO.File]::ReadAllText($p.IndexPath).Contains('Manuais: 2') -and [IO.File]::ReadAllText($q.IndexPath).Contains('Manuais: 1')) 'Indices individuais devem manter as contagens.'
    Assert ([IO.File]::ReadAllText($p.MigrationPath).Replace("`r`n","`n") -ceq $registry.Replace("`r`n","`n") -and [IO.File]::ReadAllText($a.FichaPath) -ceq $ficha) 'Regenerar nao altera ficha, vinculo nem registro humano.'
    Assert ($missing.Contains('[Registro]') -and [IO.File]::ReadAllText($q.MigrationPath).Contains('[Ficha]')) 'Navegacao do indice ao registro e ficha deve existir sem MTA.'
    Assert ([IO.File]::ReadAllText($catalog) -ceq $catalogBefore) 'Contagem manual nao modifica origem MTA.'
}
# Uma categoria livre do MTA chamada manual nao deve se confundir com cadastro humano.
Write-File $catalog $catalogBefore.Replace('"mandatory"','"manual"')
$sameName=New-HarnessProjectIndex $context
$text=[IO.File]::ReadAllText($sameName.IndexPath)
Assert ($text.Contains('| manual (MTA) | 1 | 2 |') -and $text.Contains('manual (MTA): 1 / 2') -and $text.Contains('| manual | 3 | - |')) 'Origem MTA e manual devem permanecer distintas mesmo com categoria homonima.'
Write-File $catalog $catalogBefore
# Um registro danificado nao autoriza informar zero nem perder o MTA legivel.
Write-File $p.MigrationPath 'Registro sem bloco valido'
$partial=New-HarnessProjectIndex $context
$text=[IO.File]::ReadAllText($partial.IndexPath)
$row=@($text -split '\r?\n' | Where-Object { $_ -match '^\| \[com-mta\]' })[0]
Assert ($row.Contains('MTA: 1 / 2<br>Manuais: - / -')) 'Registro ilegivel deve indicar lacuna manual e preservar MTA.'
Assert ($text.Contains('| manual | 1 | - |') -and $text.Contains('Registros legiveis: 1 de 2 projetos.') -and $text.Contains('Total manual parcial.')) 'Somente manuais conhecidas entram no total parcial.'
Assert (($partial.Warnings -join ' ').Contains('Contagem manual indisponivel')) 'Falha do registro deve ter diagnostico explicito.'
'PASS: indice manual com/sem MTA, totais separados, regeneracao, navegacao, preservacao e lacuna.'
