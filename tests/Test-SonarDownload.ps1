#requires -Version 5.1
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $root 'scripts/Harness.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $root 'scripts/HarnessSonar.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $root 'scripts/HarnessSonarCriteria.psm1') -DisableNameChecking
Import-Module (Join-Path $root 'scripts/HarnessSonarReview.psm1') -Force -DisableNameChecking
function Assert($condition,$message) { if (-not $condition) { throw $message } }
$area=Join-Path $root ('.harness/tests/sonar-download-'+[guid]::NewGuid().ToString('N'))
$app=Join-Path $area 'app'
$null=[IO.Directory]::CreateDirectory($app)
[IO.File]::WriteAllText((Join-Path $app 'pom.xml'),'<project><artifactId>app</artifactId></project>')
$config=Get-Content -Raw (Join-Path $root 'config/harness.example.json') | ConvertFrom-Json
$config.repositories=@(@{name='app';path=$app}); $config.activeProject='app'
$config.sonar.serverUrl='http://localhost:9000'; $config.sonar.apiAuthScheme='Basic'
# Nenhuma instalacao de Java/Maven/scanner existe nesta fixture.
foreach ($field in @('applicationJdk8Home','applicationMavenHome')) { $config.tools.$field=$null }
$config.sonar.scannerJdkHome=$null
$fixture=Join-Path $area 'harness'
Write-HarnessJson (Join-Path $fixture 'config.json') $config
$context=Read-HarnessConfig (Join-Path $fixture 'config.json') $fixture
$module=Get-Module HarnessSonar
& $module {
    $script:Mode='OK'; $script:Id='analysis-1'; $script:AnalysisDate='2026-10-01T10:00:00+00:00'
    $script:ApiCalls=@(); $script:MetricReads=0; $script:ToolCalls=0
    function script:Invoke-SonarTool { $script:ToolCalls++; throw 'Download nao pode executar toolchain.' }
    function script:Get-HarnessFiles { throw 'Download nao pode declarar captura dos fontes locais.' }
    function script:Invoke-SonarApiGet {
        param($ServerUrl,$Endpoint,$Query,$AuthScheme)
        $script:ApiCalls+=@([pscustomobject]@{Endpoint=$Endpoint;Query=$Query;Auth=$AuthScheme})
        if ($AuthScheme -cne 'Basic') { throw 'Autenticacao configurada nao utilizada.' }
        if ($script:Mode -eq 'DENIED') { throw ('Resposta sensivel: '+$env:SONAR_TOKEN) }
        switch ($Endpoint) {
            'api/system/status' { [pscustomobject]@{status='UP';version='9.9'} }
            'api/components/show' {
                $key=if ($script:Mode -eq 'WRONG_PROJECT') {'other'} else {'team:app'}
                [pscustomobject]@{component=[pscustomobject]@{key=$key;qualifier='TRK'}}
            }
            'api/project_analyses/search' {
                if ($Query.project -cne 'team:app' -or $Query.branch -cne 'develop' -or $Query.ps -ne 1) { throw 'Busca sem projeto/branch/ultima analise.' }
                if ($script:Mode -eq 'NONE') { return [pscustomobject]@{analyses=@()} }
                $id=if ($script:Mode -eq 'RACE' -and $script:MetricReads -gt 0) {'analysis-other'} else {$script:Id}
                $date=if ($script:Mode -eq 'BAD_DATE') {'sem-data'} else {$script:AnalysisDate}
                [pscustomobject]@{analyses=@([pscustomobject]@{key=$id;date=$date;revision='scm-da-pipeline'})}
            }
            'api/ce/component' {
                $queue=if ($script:Mode -eq 'BUSY') {@([pscustomobject]@{status='IN_PROGRESS'})} else {@()}
                [pscustomobject]@{queue=$queue}
            }
            'api/qualitygates/project_status' {
                if ($Query.analysisId -cne $script:Id) { throw 'Gate nao vinculado a analise.' }
                $state=if ($script:Mode -eq 'GATE_FAIL') {'ERROR'} else {'OK'}
                [pscustomobject]@{projectStatus=[pscustomobject]@{status=$state;conditions=@()}}
            }
            'api/measures/component' {
                $script:MetricReads++
                $values=@{coverage='88';duplicated_lines_density='2';violations='0'}
                $measures=@($Query.metricKeys.Split(',') | Where-Object {$values.ContainsKey($_)} | ForEach-Object {[pscustomobject]@{metric=$_;value=$values[$_]}})
                [pscustomobject]@{component=[pscustomobject]@{key='team:app';measures=$measures}}
            }
            'api/issues/search' {
                $total=if ($script:Mode -eq 'INCOMPLETE') {1} else {0}
                [pscustomobject]@{paging=[pscustomobject]@{pageIndex=1;pageSize=100;total=$total};issues=@();components=@()}
            }
            default { throw ('Endpoint inesperado: '+$Endpoint) }
        }
    }
}
$secret='synthetic-download-token-987654'
$token=ConvertTo-SecureString $secret -AsPlainText -Force
$previousToken=$env:SONAR_TOKEN
$env:SONAR_TOKEN='previous-environment-value'
try {
    $before=Receive-HarnessSonar $context -ProjectKey 'team:app' -BranchName develop -Phase ANTES -Token $token
    Assert ($before.DiagnosticPublished -and $before.Status -eq 'SUCCEEDED') 'Download completo deve publicar sem Java/Maven.'
    Assert ($before.Origin -ceq 'SERVER' -and $before.AnalysisId -ceq 'analysis-1') 'Origem remota/analise perdidas.'
    Assert ($before.AnalysisDateUtc -ceq '2026-10-01T10:00:00.0000000Z' -and $before.AnalysisRevision -ceq 'scm-da-pipeline') 'Data da analise deve ser distinta da data do download.'
    Assert ($before.InputsStatus -ceq 'UNVERIFIED' -and $before.LocalSourceStatus -ceq 'NOT_CHECKED') 'Download nao verifica fontes locais.'
    foreach ($field in @('ScannerExitCode','ScannerVersion','ScannerJavaHome','MavenHome','ApplicationJavaHome','SettingsPath','Profiles')) {
        Assert ($null -eq $before.$field) ('Download inventou dados locais: '+$field)
    }
    Assert ($env:SONAR_TOKEN -ceq 'previous-environment-value') 'Token anterior nao restaurado.'
    $folder=Split-Path $before.ResultPath
    $summary=Get-Content -Raw (Join-Path $folder 'RESUMO.md')
    Assert ($summary.Contains('SERVER') -and $summary.Contains('codigo local nao conferido')) 'Resumo deve explicar limite da origem.'
    $baselineFolder=Join-Path $area 'evidencias-antes'
    $null=[IO.Directory]::CreateDirectory($baselineFolder)
    foreach ($name in @('resultado.json','measures.json','issues.json')) { Copy-Item -LiteralPath (Join-Path $folder $name) -Destination (Join-Path $baselineFolder $name) }
    $baseline=Join-Path $baselineFolder 'resultado.json'
    $same=Receive-HarnessSonar $context -ProjectKey 'team:app' -BranchName develop -Phase DEPOIS -Token $token -BaselineResultPath $baseline
    Assert (-not $same.DiagnosticPublished) 'Mesma analise nao comprova comparacao ANTES/DEPOIS.'
    & $module { $script:Id='analysis-2'; $script:AnalysisDate='2026-10-02T10:00:00+00:00' }
    $after=Receive-HarnessSonar $context -ProjectKey 'team:app' -BranchName develop -Phase DEPOIS -Token $token -BaselineResultPath $baseline
    Assert ($after.DiagnosticPublished -and $after.BaselineComparison -eq 'COMPARED') 'Analise posterior comparavel nao publicada.'
    $criteria=Get-Content -Raw $after.CriteriaPath | ConvertFrom-Json
    Assert ($criteria.Evaluation.Status -eq 'WARN' -and ($criteria.Evaluation.Warnings -join '').Contains('codigo local')) 'Comparacao remota deve declarar configuracao/codigo nao conferidos.'
    $clockSkew=Get-Content -Raw $baseline | ConvertFrom-Json
    $clockSkew.FinishedAtUtc=[DateTime]::UtcNow.AddDays(1).ToString('o')
    [IO.File]::WriteAllText($baseline,($clockSkew | ConvertTo-Json -Depth 20))
    $clockResult=Receive-HarnessSonar $context -ProjectKey 'team:app' -BranchName develop -Phase DEPOIS -Token $token -BaselineResultPath $baseline
    Assert ($clockResult.DiagnosticPublished) 'Comparacao remota deve usar data da analise, sem bloquear pelo relogio do colega.'
    # SERVER -> SCAN aceita identidade remota, mas exige cronologia da analise.
    $currentScan=@{Origin='SCAN';Project='app';Source=$app;ServerUrl='http://localhost:9000';ProjectKey='team:app';BranchName='develop'
        StartedAtUtc=[DateTime]::UtcNow.AddMinutes(1).ToString('o');AnalysisId='analysis-scan';AnalysisDateUtc='2026-10-03T10:00:00Z'}
    $remoteBaseline=Read-HarnessSonarBaseline $baseline $context $currentScan
    Assert ($remoteBaseline.RemoteComparison) 'Baseline SERVER deve declarar limite da comparacao com scan.'
    Assert-HarnessSonarBaselineChronology $remoteBaseline $currentScan
    $currentScan.AnalysisDateUtc=$null
    $rejected=$false
    try { Assert-HarnessSonarBaselineChronology $remoteBaseline $currentScan } catch { $rejected=$true }
    Assert $rejected 'Data remota ausente nao pode ser substituida pela data do download.'
    # SCAN -> SERVER nao inventa correspondencia de settings/scanner da pipeline.
    $localBaseline=Get-Content -Raw $baseline | ConvertFrom-Json
    $localBaseline.Origin='SCAN'; $localBaseline.InputsStatus='STABLE'; $localBaseline.ScannerExitCode=0
    $localBaseline.ScannerVersion='5.8.0.7211'; $localBaseline.Profiles=@('perfil-local')
    [IO.File]::WriteAllText($baseline,($localBaseline | ConvertTo-Json -Depth 20))
    $mixed=Receive-HarnessSonar $context -ProjectKey 'team:app' -BranchName develop -Phase DEPOIS -Token $token -BaselineResultPath $baseline
    Assert ($mixed.DiagnosticPublished -and $mixed.BaselineComparison -eq 'COMPARED' -and $null -eq $mixed.Profiles) 'Comparacao com scan nao deve atribuir configuracao local ao servidor.'
    $saved=Get-Content -Raw $after.ResultPath
    foreach ($mode in @('DENIED','NONE','BAD_DATE','WRONG_PROJECT','BUSY','RACE','INCOMPLETE')) {
        & $module {param($mode) $script:Mode=$mode; $script:MetricReads=0} $mode
        $failed=Receive-HarnessSonar $context -ProjectKey 'team:app' -BranchName develop -Phase DEPOIS -Token $token
        Assert (-not $failed.DiagnosticPublished -and $failed.Status -ne 'SUCCEEDED') ('Falha publicada: '+$mode)
        Assert ((Get-Content -Raw $after.ResultPath) -ceq $saved) ('Diagnostico anterior perdido: '+$mode)
        Assert ($env:SONAR_TOKEN -ceq 'previous-environment-value') ('Token nao restaurado: '+$mode)
    }
    & $module { $script:Mode='GATE_FAIL'; $script:MetricReads=0 }
    $gate=Receive-HarnessSonar $context -ProjectKey 'team:app' -BranchName develop -Phase ANTES -Token $token
    Assert ($gate.DiagnosticPublished -and $gate.Status -eq 'QUALITY_GATE_FAILED') 'Gate reprovado deve permanecer evidencia completa.'
    $review=Get-HarnessSonarReview $fixture $gate.ResultPath
    Assert ($review.Assessment.Origin -ceq 'SERVER') 'Parecer deve considerar origem remota.'
    $null=Save-HarnessSonarDecision $fixture $gate.ResultPath RegistrarParaDepois -Note 'Dependencia externa' -ReviewWhen 'Proxima revisao'
    $record=Get-Content -Raw $gate.ResultPath | ConvertFrom-Json
    $record.AnalysisRevision='outro-scm'
    [IO.File]::WriteAllText($gate.ResultPath,($record | ConvertTo-Json -Depth 20))
    Assert ((Get-HarnessSonarReview $fixture $gate.ResultPath).NeedsReview) 'Proveniencia alterada deve invalidar parecer vigente.'
    $all=Get-ChildItem -LiteralPath (Join-Path $fixture '.harness/projetos/app') -Recurse -File | ForEach-Object { [IO.File]::ReadAllText($_.FullName) }
    Assert (-not (($all -join '').Contains($secret))) 'Token persistido.'
    Assert ((& $module { $script:ToolCalls }) -eq 0) 'Download executou toolchain.'
    Assert (@(Get-ChildItem -LiteralPath $folder -File).Count -eq 6) 'Diagnostico deve conservar os seis documentos correntes.'
    & $module { function script:Publish-HarnessSonarDiagnostic { throw 'Falha simulada de publicacao.' } }
    $publicationFailed=$false
    try { $null=Receive-HarnessSonar $context -ProjectKey 'team:app' -BranchName develop -Phase ANTES -Token $token } catch { $publicationFailed=$true }
    Assert ($publicationFailed -and $env:SONAR_TOKEN -ceq 'previous-environment-value') 'Falha do publicador deve restaurar token.'
} finally { $token.Dispose(); $env:SONAR_TOKEN=$previousToken }
Write-Host 'PASS: download Sonar sem toolchain, origem, baseline, concorrencia, falhas, gate, parecer e token.'
