#requires -Version 5.1
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $root 'scripts/HarnessSonarReview.psm1') -Force -DisableNameChecking
function Assert($condition,$message) { if (-not $condition) { throw $message } }
$fixture=Join-Path $root ('.harness/tests/sonar-review-' + [guid]::NewGuid().ToString('N'))
$run=Join-Path $fixture '.harness/sonar/app/run'
$null=New-Item -ItemType Directory -Path $run -Force
$path=Join-Path $run 'result.json'
@{RunId='run-1';AnalysisId='analysis-1';Source='C:/app';ProjectKey='app';BranchName='develop';ServerUrl='https://sonar.example';Status='QUALITY_GATE_FAILED';TechnicalStatus='NON_COMPLIANT';QualityGateStatus='ERROR';CriteriaStatus='FAIL';HumanDecision='PENDING'} | ConvertTo-Json | Set-Content $path
'{"Result":{"status":"ERROR"}}' | Set-Content (Join-Path $run 'quality-gate.json')
$hash=(Get-FileHash $path).Hash
$state=Get-HarnessSonarReview $fixture $path
Assert ($state.Decision -eq 'PENDING' -and $state.History.Count -eq 0) 'Coleta sem decisao deve ficar pendente.'
# Entrada real Review sem configuracao/JDK/token; Enter conserva PENDING.
'Resumo da coleta simulada' | Set-Content (Join-Path $run 'RESUMO.md')
Copy-Item -LiteralPath (Join-Path $root 'scripts') -Destination $fixture -Recurse
$output='' | & powershell.exe -NoProfile -File (Join-Path $fixture 'scripts/analisar-sonar.ps1') -Action Review -ResultPath $path 2>&1 | Out-String
Assert ($LASTEXITCODE -eq 0 -and $output.Contains('PENDING') -and -not $output.Contains('Token Sonar')) 'Review depende de ambiente do scanner ou registrou decisao implicita.'
Assert (-not (Test-Path (Join-Path $run 'decisions'))) 'Enter registrou decisao.'
$rejected=$false
try { Save-HarnessSonarDecision $fixture $path RegistrarParaDepois -Note 'Aguardar ambiente' | Out-Null } catch { $rejected=$true }
Assert $rejected 'Adiamento sem gatilho aceito.'
$saved=Save-HarnessSonarDecision $fixture $path RegistrarParaDepois -Note 'Aguardar ambiente' -ReviewWhen 'Antes da revisao do lote L1'
Assert ($saved.Decision -eq 'RegistrarParaDepois' -and $saved.History.Count -eq 1 -and $saved.Current.ReviewWhen -like '*L1') 'Adiamento nao registrado.'
$firstHash=(Get-FileHash (Join-Path $run 'decisions/decision_000001.json')).Hash
$saved=Save-HarnessSonarDecision $fixture $path CorrigirAgora -Note 'Ambiente disponivel'
Assert ($saved.History.Count -eq 2 -and $saved.Decision -eq 'CorrigirAgora') 'Retomada perdeu historico.'
Assert ((Get-FileHash $path).Hash -eq $hash -and (Get-FileHash (Join-Path $run 'decisions/decision_000001.json')).Hash -eq $firstHash) 'Decisao alterou evidencia/historico.'
Assert ($saved.Result.QualityGateStatus -eq 'ERROR' -and $saved.Result.HumanDecision -eq 'PENDING') 'Gate/recibo foi reescrito.'
$saved=Save-HarnessSonarDecision $fixture $path Interromper -Note 'Rever escopo'
Assert ($saved.History.Count -eq 3 -and $saved.Decision -eq 'Interromper') 'Interrupcao perdida.'
$outside=Join-Path $fixture 'result.json'; Copy-Item -LiteralPath $path -Destination $outside
$rejected=$false
try { Get-HarnessSonarReview $fixture $outside | Out-Null } catch { $rejected=$true }
Assert $rejected 'Caminho fora da coleta aceito.'
$lock=[IO.File]::Open((Join-Path $run 'decision.lock'),'OpenOrCreate','ReadWrite','None')
try {
    $rejected=$false
    try { Save-HarnessSonarDecision $fixture $path CorrigirAgora | Out-Null } catch { $rejected=$true }
    Assert $rejected 'Escrita concorrente aceita.'
} finally { $lock.Dispose() }
'{"Result":{"status":"OK"}}' | Set-Content (Join-Path $run 'quality-gate.json')
$rejected=$false
try { Get-HarnessSonarReview $fixture $path | Out-Null } catch { $rejected=$true }
Assert $rejected 'Evidencia alterada aceita pelo historico.'
Write-Output 'PASS: decisao separada, motivo/gatilho, retomada, hashes e concorrencia; sem rede/configuracao/token.'
