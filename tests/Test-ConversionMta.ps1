#requires -Version 5.1
$ErrorActionPreference='Stop'; Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'ConversionFixture.ps1')
Import-Module (Join-Path $root 'tools/transicao/ConversaoPublicacao.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $root 'scripts/HarnessProject.psm1') -DisableNameChecking
function Add-ConversionMta([string]$Path,[string]$Id='regra') {
    Write-ConversionFile (Join-Path $Path 'index.html') '<html>Relatorio sintetico</html>'
    $apps=@(@{artifactId='api';rulesets=@(@{name='java';violations=@{$Id=@{description='Problema';category='mandatory';incidents=@()}}})})
    Write-ConversionFile (Join-Path $Path 'output.js') ('window["apps"] = '+(ConvertTo-Json -InputObject $apps -Depth 12 -Compress)+';')
}
foreach ($internal in @($false,$true)) {
    $f=New-ConversionFixture; $plan=Add-ConversionPlan $f ('a'*32)
    $origin=if ($internal) {Join-Path $f.Workspace '.harness/runs/apelido/rodada/execucao'} else {Join-Path $f.Area 'mta externo'}
    $report=Join-Path $origin 'output/static-report'; Add-ConversionMta $report
    if ($internal) {
        $nested=Join-Path $report 'historico'; Add-ConversionMta $nested 'regra-antiga'
        [IO.File]::SetLastWriteTimeUtc((Join-Path $nested 'index.html'),[datetime]'2020-01-01T00:00:00Z')
    }
    $plan.PlanningBasis='MTA'; $plan|Add-Member Run $origin
    $ficha=Join-Path (Split-Path $plan.ContextPath -Parent) 'ficha.md'
    Write-ConversionFile $ficha '# Risco humano preservado'
    $plan|Add-Member FichaPath $ficha
    Write-ConversionFile $plan.ContextPath ($plan|ConvertTo-Json -Depth 15)
    $marker=@{Run=$origin;RunId=('d'*32);Source=$f.Source}|ConvertTo-Json -Compress
    [IO.File]::AppendAllText($f.Register,("`n<!-- MTA "+$marker+" -->`nRodada MTA: "+('d'*32)+".`n"))
    $original=[IO.File]::ReadAllText((Join-Path $report 'output.js'))
    $null=Invoke-ConversionApply $f.Workspace $f.Pom -Contexto $plan.ContextPath
    $p=Get-HarnessProjectReference $f.Workspace $f.Pom
    $data=Get-Content -LiteralPath $p.ContextPath -Raw|ConvertFrom-Json
    $config=Get-Content -LiteralPath $p.ConfigPath -Raw|ConvertFrom-Json
    $mta=Read-HarnessProjectMta $p
    Assert ($data.PlanningBasis -eq 'MTA' -and $data.Mta.ReportPath -eq $mta.ReportPath) 'Base e fonte MTA correntes preservadas.'
    Assert ([IO.File]::ReadAllText($data.FichaPaths[0].Path) -match 'Relatorio MTA atual' -and [IO.File]::ReadAllText($data.FichaPaths[0].Path) -notmatch 'MTA indisponivel') 'Ficha aponta ao MTA disponivel sem extrato.'
    Assert ([IO.File]::ReadAllText((Join-Path $report 'output.js')) -ceq $original) 'Origem MTA intacta.'
    if ($internal) {
        Assert (-not $config.mta.diretorio -and $mta.ReportPath.StartsWith($p.Folder+'\atual\diagnosticos\mta\')) 'MTA interno vai ao destino corrente.'
        Assert ($mta.Issues[0].Id -eq 'java::regra' -and -not (Test-Path (Join-Path $p.Folder 'atual/diagnosticos/mta/historico'))) 'Conjunto aninhado antigo nao e publicado nem muda a selecao por mtime.'
    } else {
        Assert ($config.mta.diretorio -eq $origin -and -not (Test-Path (Join-Path $p.Folder 'atual/diagnosticos/mta'))) 'MTA externo apenas configurado, sem copia.'
    }
    $before=Get-ConversionState $f
    $again=Invoke-ConversionApply $f.Workspace $f.Pom -Contexto $plan.ContextPath
    Assert ($again.Status -eq 'EQUIVALENTE' -and (Get-ConversionState $f) -ceq $before) 'Reaplicacao MTA idempotente.'
    if (-not $internal) {
        $next=Join-Path $origin 'nova'; Add-ConversionMta $next 'nova-regra'
        [IO.File]::SetLastWriteTimeUtc((Join-Path $next 'index.html'),[datetime]'2030-01-01T00:00:00Z')
        $new=Read-HarnessProjectMta $p
        Assert ($new.Issues[0].Id -eq 'java::nova-regra') 'Novo MTA na origem dispensa conversao.'
    }
}
$f=New-ConversionFixture; $plan=Add-ConversionPlan $f ('b'*32)
$origin=Join-Path $f.Area 'origem externa ausente'
$plan.PlanningBasis='MTA'; $plan|Add-Member Run $origin
Write-ConversionFile $plan.ContextPath ($plan|ConvertTo-Json -Depth 15)
$null=Invoke-ConversionApply $f.Workspace $f.Pom -Contexto $plan.ContextPath
$p=Get-HarnessProjectReference $f.Workspace $f.Pom
$data=Get-Content -LiteralPath $p.ContextPath -Raw|ConvertFrom-Json
Assert ($data.PlanningBasis -eq 'MTA' -and -not $data.Mta -and $data.NeedsReview) 'Origem ausente mantem base MTA e revisao, sem mudar para EVIDENCIAS.'
Assert ([IO.File]::ReadAllText($p.PlanPath) -match 'origem atualmente indisponivel' -and [IO.File]::ReadAllText($p.PlanPath) -notmatch 'Base EVIDENCIAS:') 'Limite deve estar visivel no plano.'
Reject { Read-HarnessProjectMta $p } 'Origem ausente nao usa fallback interno.'
# Alteracao de selecao durante o preparo deve impedir qualquer publicacao.
$module=Get-Module ConversaoPublicacao
foreach ($mutation in @('date','new')) {
    $f=New-ConversionFixture; $plan=Add-ConversionPlan $f ('c'*32)
    $origin=Join-Path $f.Area 'mta externo'; Add-ConversionMta $origin
    $plan.PlanningBasis='MTA'; $plan|Add-Member Run $origin
    Write-ConversionFile $plan.ContextPath ($plan|ConvertTo-Json -Depth 15)
    & $module {
        param($Origin,$Mutation)
        $script:originalBuilder=${function:New-ConversionCoreFiles}
        $script:mutationOrigin=$Origin; $script:mutationKind=$Mutation
        Set-Item function:script:New-ConversionCoreFiles {
            param($Inputs,$MtaDiretorio)
            $state=& $script:originalBuilder $Inputs $MtaDiretorio
            if ($script:mutationKind -eq 'date') { [IO.File]::SetLastWriteTimeUtc((Join-Path $script:mutationOrigin 'index.html'),[datetime]'2030-01-01T00:00:00Z') }
            else {
                $next=Join-Path $script:mutationOrigin 'novo'; $null=[IO.Directory]::CreateDirectory($next)
                foreach ($name in @('index.html','output.js')) { [IO.File]::Copy((Join-Path $script:mutationOrigin $name),(Join-Path $next $name)) }
            }
            $state
        }
    } $origin $mutation
    try { Reject { Invoke-ConversionApply $f.Workspace $f.Pom -Contexto $plan.ContextPath } 'Mudanca de data ou conjunto novo deve abortar.' }
    finally { & $module { Set-Item function:script:New-ConversionCoreFiles $script:originalBuilder } }
    $p=Get-HarnessProjectReference $f.Workspace $f.Pom
    Assert (-not (Test-Path $p.Folder)) 'Selecao alterada nao publica dados parciais.'
}
'PASS: MTA externo direto, interno corrente, origem intacta e novo diagnostico independente.'
