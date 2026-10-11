#requires -Version 5.1
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $root 'scripts/Harness.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $root 'scripts/HarnessProject.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $root 'scripts/HarnessSonarCriteria.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $root 'scripts/HarnessSonarReview.psm1') -Force -DisableNameChecking
function Assert($condition,$message) { if (-not $condition) { throw $message } }
$area=Join-Path $root ('.harness/tests/sonar-review-' + [guid]::NewGuid().ToString('N'))
$fixture=Join-Path $area 'harness'
$app=Join-Path $area 'app com espaco'
$null=[IO.Directory]::CreateDirectory($app)
Set-Content (Join-Path $app 'pom.xml') '<project><artifactId>app</artifactId></project>'
$project=Initialize-HarnessProjectStorage $fixture (Join-Path $app 'pom.xml')
$run=Join-Path $project.Folder 'atual/diagnosticos/sonar'
$path=Join-Path $run 'resultado.json'
$record=[ordered]@{AnalysisId='analysis-1';Source=$project.Source;ProjectKey='app';BranchName='develop';ServerUrl='https://sonar.example';Phase='ANTES';Status='QUALITY_GATE_FAILED';QualityGateStatus='ERROR';CriteriaStatus='PASS'}
$measures=@(@{metric='coverage';value='85'},@{metric='duplicated_lines_density';value='0'},@{metric='violations';value='0'})
$snapshot=[pscustomobject]@{Status='COMPLETE';Count=0;Filter='resolved=false';Issues=@()}
$evaluation=Get-HarnessSonarCriteria -Measures ($measures | ConvertTo-Json | ConvertFrom-Json) -IssueSnapshot $snapshot
Write-HarnessJson $path $record
Write-HarnessJson (Join-Path $run 'quality-gate.json') @{AnalysisId='analysis-1';ProjectKey='app';Result=@{status='ERROR';conditions=@()}}
Write-HarnessJson (Join-Path $run 'measures.json') @{AnalysisId='analysis-1';ProjectKey='app';BranchName='develop';Measures=$measures}
Write-HarnessJson (Join-Path $run 'issues.json') @{AnalysisId='analysis-1';ProjectKey='app';BranchName='develop';ServerUrl='https://sonar.example';Snapshot=$snapshot}
Write-HarnessJson (Join-Path $run 'criteria.json') @{AnalysisId='analysis-1';ProjectKey='app';BranchName='develop';Evaluation=$evaluation}
'Resumo da coleta simulada' | Set-Content (Join-Path $run 'RESUMO.md')
$hash=(Get-FileHash $path).Hash
$state=Get-HarnessSonarReview $fixture $path
Assert ($state.Decision -eq 'PENDING' -and $null -eq $state.Current) 'Diagnostico sem decisao deve ficar pendente.'
# Entrada real Review sem JDK/token; Enter conserva PENDING.
Copy-Item -LiteralPath (Join-Path $root 'scripts') -Destination $fixture -Recurse
$output='' | & powershell.exe -NoProfile -File (Join-Path $fixture 'scripts/analisar-sonar.ps1') -Action Review -ResultPath $path 2>&1 | Out-String
Assert ($LASTEXITCODE -eq 0 -and $output.Contains('PENDING') -and -not $output.Contains('Token Sonar')) 'Review depende de ambiente do scanner ou registrou decisao implicita.'
Assert (-not (Test-Path $state.DecisionPath)) 'Enter registrou decisao.'
$config=Get-Content -Raw (Join-Path $root 'config/harness.example.json') | ConvertFrom-Json
$config.repositories=@(@{name='app';path=$app});$config.activeProject='app'
Write-HarnessJson (Join-Path $fixture 'config.json') $config
$output='' | & powershell.exe -NoProfile -File (Join-Path $fixture 'scripts/analisar-sonar.ps1') -Action Review -ConfigPath (Join-Path $fixture 'config.json') 2>&1 | Out-String
Assert ($LASTEXITCODE -eq 0 -and $output.Contains('PENDING') -and -not $output.Contains('Caminho do')) ("Review nao resolveu projeto/caminho corrente: "+$output)
$rejected=$false
try { Save-HarnessSonarDecision $fixture $path RegistrarParaDepois -Note 'Aguardar ambiente' | Out-Null } catch { $rejected=$true }
Assert $rejected 'Adiamento sem gatilho aceito.'
$saved=Save-HarnessSonarDecision $fixture $path RegistrarParaDepois -Note 'Aguardar ambiente' -ReviewWhen 'Antes da revisao do lote L1'
Assert ($saved.Decision -eq 'RegistrarParaDepois' -and $saved.Current.ReviewWhen -like '*L1') 'Adiamento nao registrado.'
$saved=Save-HarnessSonarDecision $fixture $path CorrigirAgora -Note 'Ambiente disponivel'
Assert ($saved.Decision -eq 'CorrigirAgora' -and -not (Test-Path (Join-Path $run 'decisions'))) 'Retomada criou cadeia ou perdeu decisao.'
Assert ((Get-FileHash $path).Hash -eq $hash -and $saved.Result.QualityGateStatus -eq 'ERROR') 'Decisao alterou evidencia/gate.'
$decisionText=Get-Content -Raw $saved.DecisionPath
Assert ($decisionText -notmatch 'Previous|Sha256|RunId|Sequence') 'Parecer restaurou recibos.'
foreach ($field in @('Phase','CriteriaStatus')) {
    $altered=Get-Content -Raw $path | ConvertFrom-Json
    $altered.$field=if ($field -eq 'Phase') { 'DEPOIS' } else { 'FAIL' }
    Write-HarnessJson $path $altered
    Assert ((Get-HarnessSonarReview $fixture $path).NeedsReview) "Mudanca em $field manteve decisao vigente."
    Write-HarnessJson $path $record
}
$issuePath=Join-Path $run 'issues.json'
$originalIssues=Get-Content -Raw $issuePath
foreach ($mode in @('FILTER','PROJECT','DUPLICATE')) {
    $invalid=ConvertFrom-Json $originalIssues
    if ($mode -eq 'FILTER') { $invalid.Snapshot.Filter='resolved=true' }
    else {
        $issue=[pscustomobject]@{key='issue-1';project='other';severity='MAJOR';impacts=@()}
        $invalid.Snapshot.Issues=@($issue)
        if ($mode -eq 'DUPLICATE') { $issue.project='app';$invalid.Snapshot.Issues=@($issue,$issue) }
        $invalid.Snapshot.Count=$invalid.Snapshot.Issues.Count
    }
    Write-HarnessJson $issuePath $invalid
    $rejected=$false
    try { $null=Get-HarnessSonarReview $fixture $path } catch { $rejected=$true }
    Assert $rejected "Escopo de issues invalido aceito: $mode"
}
[IO.File]::WriteAllText($issuePath,$originalIssues)
# Mudanca relevante recalcula criterios, preserva justificativa e pede revisao.
$changed=Get-Content -Raw (Join-Path $run 'measures.json') | ConvertFrom-Json
$changed.Measures[0].value='79'
Write-HarnessJson (Join-Path $run 'measures.json') $changed
$state=Get-HarnessSonarReview $fixture $path
Assert ($state.NeedsReview -and $state.Decision -eq 'PENDING' -and $state.Evaluation.Status -eq 'FAIL' -and $state.Current.Note -eq 'Ambiente disponivel') 'Dados alterados nao reavaliados ou justificativa perdida.'
Assert ((Get-Content -Raw $state.DecisionPath) -ceq $decisionText) 'Consulta alterou texto humano.'
$saved=Save-HarnessSonarDecision $fixture $path Interromper -Note 'Rever cobertura'
Assert ($saved.Decision -eq 'Interromper' -and -not $saved.NeedsReview) 'Reavaliacao nao substituiu parecer corrente.'
# Mesmo dialogo nao pode confirmar dados diferentes dos apresentados.
$displayed=$saved.Documents
$changed.Measures[0].value='78'
Write-HarnessJson (Join-Path $run 'measures.json') $changed
$rejected=$false
try { Save-HarnessSonarDecision $fixture $path CorrigirAgora -ExpectedDocuments $displayed | Out-Null } catch { $rejected=$true }
Assert $rejected 'Decisao confirmou evidencia alterada durante dialogo.'
Assert ((Get-HarnessSonarReview $fixture $path).Current.Note -eq 'Rever cobertura') 'Conflito apagou justificativa.'
# Outra analise pode substituir os dados sem perder o parecer humano anterior.
foreach ($file in @('resultado.json','quality-gate.json','measures.json','issues.json','criteria.json')) {
    $item=Get-Content -Raw (Join-Path $run $file) | ConvertFrom-Json
    $item.AnalysisId='analysis-2'
    Write-HarnessJson (Join-Path $run $file) $item
}
$state=Get-HarnessSonarReview $fixture $path
Assert ($state.NeedsReview -and $state.Decision -eq 'PENDING' -and $state.Current.Decision -eq 'Interromper') 'Nova analise transferiu decisao automaticamente.'
Set-HarnessProjectOperation $project sonar FAILED -ErrorMessage 'Falha de coleta simulada'
Assert ((Get-HarnessSonarReview $fixture $path).Operation.Status -eq 'FAILED') 'Falha mais recente nao ficou visivel junto ao diagnostico.'
$outside=Join-Path $fixture 'resultado.json'; Copy-Item -LiteralPath $path -Destination $outside
$rejected=$false
try { Get-HarnessSonarReview $fixture $outside | Out-Null } catch { $rejected=$true }
Assert $rejected 'Revisao aceitou destino fora do projeto.'
# Mutex real em outro processo, incluindo liberacao apos falha de publicacao.
$worker=Join-Path $fixture 'tentar-decisao.ps1'
@'
param($Module,$Root,$Result)
Import-Module $Module -DisableNameChecking
try { $null=Save-HarnessSonarDecision $Root $Result CorrigirAgora; exit 0 }
catch { exit 7 }
'@ | Set-Content $worker
$lock=Enter-HarnessProjectAccess $project -ForOperation
try {
    & powershell.exe -NoProfile -File $worker -Module (Join-Path $root 'scripts/HarnessSonarReview.psm1') -Root $fixture -Result $path
    Assert ($LASTEXITCODE -eq 7) 'Escrita concorrente aceita.'
} finally { $lock.ReleaseMutex();$lock.Dispose() }
& powershell.exe -NoProfile -File $worker -Module (Join-Path $root 'scripts/HarnessSonarReview.psm1') -Root $fixture -Result $path
Assert ($LASTEXITCODE -eq 0) 'Mutex nao liberado apos falha/conflito.'
Assert (-not (Test-Path $project.TemporaryPath)) 'Revisao deixou temporarios permanentes.'
Write-Output 'PASS: parecer corrente, criterios recalculados, justificativa preservada, dialogo e concorrencia; sem JDK/rede/token.'
