#requires -Version 5.1
$ErrorActionPreference='Stop'; Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'ConversionFixture.ps1')
Import-Module (Join-Path $root 'tools/transicao/ConversaoPublicacao.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $root 'scripts/HarnessProject.psm1') -DisableNameChecking
Import-Module (Join-Path $root 'scripts/HarnessSonarReview.psm1') -DisableNameChecking
function Add-LegacySonar($Fixture,[string]$Name,[string]$Finished,[switch]$Incomplete) {
    $folder=Join-Path $Fixture.Workspace ('.harness/sonar/apelido/'+$Name)
    $path=Join-Path $folder 'result.json'; $log=Join-Path $folder 'scanner-info.log'
    $runId=[guid]::NewGuid().ToString('N')
    $data=@{RunId=$runId;Project='apelido';ProjectLabel='Apelido';Source=$Fixture.Source;StartedAtUtc='2026-10-01T09:00:00Z';FinishedAtUtc=$Finished;Status='QUALITY_GATE_FAILED';Stage='COMPLETE';ScannerExitCode=0;AnalysisStatus='SUCCESS';MetricsStatus='MATCHED';InputsStatus='STABLE';IssuesStatus='COMPLETE';QualityGateStatus='ERROR';CriteriaStatus='PASS';Phase='ANTES';ProjectKey='api-key';BranchName='develop';ServerUrl='https://sonar.example';AnalysisId=$Name;LogPath=$log;ResultPath=$path;Error=$null;HumanDecision='PENDING';BaselineComparison='PENDING';BaselineRunId=$null;BaselineResultPath=$null;CriteriaPath=(Join-Path $folder 'criteria.json')}
    if ($Incomplete) { $data.Status='UNVERIFIED';$data.Stage='ISSUES';$data.IssuesStatus='UNVERIFIED';$data.InputsStatus='UNVERIFIED';$data.Error='Coleta interrompida' }
    Write-ConversionFile $log ('Log '+$Name)
    Write-ConversionFile (Join-Path $folder 'inputs.json') '{"Files":[]}'
    $measures=@(@{metric='coverage';value='85'},@{metric='duplicated_lines_density';value='0'},@{metric='violations';value='0'})
    $snapshot=@{Status='COMPLETE';Count=0;Filter='resolved=false';Issues=@()}
    $criteria=@{Status='PASS';BaselineComparison='PENDING';BaselineRunId=$null;BaselineResultPath=$null;NewIssueKeys=@()}
    foreach ($entry in @(@('quality-gate.json',@{AnalysisId=$Name;ProjectKey='api-key';Result=@{status='ERROR';conditions=@()}}),@('measures.json',@{AnalysisId=$Name;ProjectKey='api-key';BranchName='develop';Measures=$measures}),@('issues.json',@{RunId=$runId;AnalysisId=$Name;ProjectKey='api-key';BranchName='develop';ServerUrl='https://sonar.example';Snapshot=$snapshot}),@('criteria.json',@{AnalysisId=$Name;ProjectKey='api-key';BranchName='develop';Evaluation=$criteria}))) {
        Write-ConversionFile (Join-Path $folder $entry[0]) ($entry[1]|ConvertTo-Json -Depth 15)
    }
    $data.IssuesSha256=(Get-FileHash -LiteralPath (Join-Path $folder 'issues.json')).Hash
    Write-ConversionFile $path ($data|ConvertTo-Json -Depth 12)
    Write-ConversionFile (Join-Path $folder 'RESUMO.md') ("# Resumo $Name`nNota humana: conferir regra corporativa.`nRunId: $runId`n[Resultado](result.json)`nDecisao na coleta: PENDING. Consulte decisions/ para o historico humano posterior.")
    [pscustomobject]@{Path=$path;Folder=$folder;Data=$data}
}
function Add-LegacySonarDecision($Record) {
    $evidence=@(foreach ($name in @('result.json','inputs.json','quality-gate.json','measures.json','issues.json','criteria.json')) { @{Name=$name;Sha256=(Get-FileHash -LiteralPath (Join-Path $Record.Folder $name)).Hash} })
    $choice=@{SchemaVersion=1;Sequence=1;RunId=$Record.Data.RunId;Source=$Record.Data.Source;ProjectKey=$Record.Data.ProjectKey;ServerUrl=$Record.Data.ServerUrl;RecordedAtUtc='2026-10-03T11:00:00Z';Decision='RegistrarParaDepois';Note='Aguardar correcoes do fornecedor';ReviewWhen='Antes do aceite';Evidence=$evidence;PreviousSha256=$null}
    Write-ConversionFile (Join-Path $Record.Folder 'decisions/decision_000001.json') ($choice|ConvertTo-Json -Depth 15)
}
$f=New-ConversionFixture
$usable=Add-LegacySonar $f 'analysis-1' '2026-10-02T10:00:00Z'
$latest=Add-LegacySonar $f 'analysis-2' '2026-10-03T10:00:00Z' -Incomplete
Add-LegacySonarDecision $usable
[IO.File]::SetLastWriteTimeUtc($usable.Path,[datetime]'2030-01-01T00:00:00Z')
Write-ConversionFile $f.Register ([IO.File]::ReadAllText($f.Register)+"`n[Sonar](<$($usable.Folder)/RESUMO.md>)")
$original=[IO.File]::ReadAllText($usable.Path)
$null=Invoke-ConversionApply $f.Workspace $f.Pom
$p=Get-HarnessProjectReference $f.Workspace $f.Pom
$path=Join-Path $p.Folder 'atual/diagnosticos/sonar/resultado.json'
$review=Get-HarnessSonarReview $f.Workspace $path
Assert ($review.Result.AnalysisId -ceq 'analysis-1' -and $review.Result.Status -eq 'QUALITY_GATE_FAILED') 'Gate reprovado continua sendo diagnostico completo; tentativa parcial nao o substitui.'
Assert ($review.Operation.Status -eq 'FAILED') 'Falha da ultima coleta deve ficar visivel.'
$attempt=Get-Content -LiteralPath (Join-Path $p.Folder 'atual/diagnosticos/sonar-tentativa.json') -Raw|ConvertFrom-Json
Assert ($attempt.AnalysisId -ceq 'analysis-2' -and -not $attempt.DiagnosticPublished) 'Ultima tentativa separada do conjunto utilizavel.'
Assert ($review.Current.Note -ceq 'Aguardar correcoes do fornecedor' -and $review.NeedsReview -and $review.Decision -eq 'PENDING') 'Decisao humana preservada para revisao, sem herdar aceite.'
Assert ($review.Summary -match 'Nota humana' -and $review.Summary -notmatch 'RunId:|decisions/' -and $review.Summary -match '\[Resultado\]\(<resultado.json>\)') 'Resumo humano e links funcionais preservados sem controles legados.'
Assert ([IO.File]::ReadAllText($p.IndexPath) -match 'RESUMO.md' -and [IO.File]::ReadAllText($p.IndexPath) -match 'FAILED') 'Indice deve mostrar resumo e ultima falha.'
Assert ([IO.File]::ReadAllText($usable.Path) -ceq $original) 'Origem Sonar preservada.'
foreach ($file in @('resultado.json','issues.json','criteria.json')) { Assert ([IO.File]::ReadAllText((Join-Path (Split-Path $path -Parent) $file)) -notmatch 'RunId|IssuesSha256|PreviousSha256') 'Diagnostico corrente nao pode depender de recibos.' }
$before=Get-ConversionState $f; $again=Invoke-ConversionApply $f.Workspace $f.Pom
Assert ($again.Status -eq 'EQUIVALENTE' -and (Get-ConversionState $f) -ceq $before) 'Reaplicacao Sonar idempotente.'
$issuePath=Join-Path $usable.Folder 'issues.json'
$invalid=Get-Content -LiteralPath $issuePath -Raw|ConvertFrom-Json
$invalid.AnalysisId='outra-analise'; Write-ConversionFile $issuePath ($invalid|ConvertTo-Json -Depth 15)
$before=Get-ConversionState $f
Reject {Invoke-ConversionApply $f.Workspace $f.Pom} 'Conjunto declarado completo com outra analise nao pode eleger fallback.'
Assert ((Get-ConversionState $f) -ceq $before) 'Recusa de diagnostico alterado preserva todos os arquivos.'

$f=New-ConversionFixture
$usable=Add-LegacySonar $f 'completa' '2026-10-02T10:00:00Z'
$failed=Add-LegacySonar $f 'baseline-rejeitado' '2026-10-03T10:00:00Z' -Incomplete
$rejectedBaseline=Join-Path $f.Workspace '.harness/sonar/outro/result.json'
Write-ConversionFile $rejectedBaseline (@{Source=(Join-Path $f.Area 'outro-projeto')}|ConvertTo-Json)
$failed.Data.Stage='BASELINE'; $failed.Data.Status='FAILED'; $failed.Data.AnalysisStatus='UNVERIFIED'; $failed.Data.ScannerExitCode=$null
$failed.Data.BaselineResultPath=$rejectedBaseline; $failed.Data.BaselineRunId=$null
Write-ConversionFile $failed.Path ($failed.Data|ConvertTo-Json -Depth 12)
$null=Invoke-ConversionApply $f.Workspace $f.Pom
$p=Get-HarnessProjectReference $f.Workspace $f.Pom
$attempt=Get-Content -LiteralPath (Join-Path $p.Folder 'atual/diagnosticos/sonar-tentativa.json') -Raw|ConvertFrom-Json
Assert ($attempt.Stage -eq 'BASELINE' -and $null -eq $attempt.BaselineAnalysisId -and -not $attempt.BaselineResultPath) 'Baseline rejeitado na coleta nao vira base adotada nem impede preservar a falha.'

$f=New-ConversionFixture
$baseline=Add-LegacySonar $f 'antes' '2026-10-02T10:00:00Z'
$after=Add-LegacySonar $f 'depois' '2026-10-04T10:00:00Z'
$after.Data.StartedAtUtc='2026-10-03T09:00:00Z'; $after.Data.Phase='DEPOIS'
$after.Data.BaselineResultPath=$baseline.Path; $after.Data.BaselineRunId=$baseline.Data.RunId; $after.Data.BaselineComparison='COMPARED'
Write-ConversionFile $after.Path ($after.Data|ConvertTo-Json -Depth 12)
$criteria=Get-Content -LiteralPath $after.Data.CriteriaPath -Raw|ConvertFrom-Json
$criteria.Evaluation.BaselineRunId=$baseline.Data.RunId; $criteria.Evaluation.BaselineResultPath=$baseline.Path; $criteria.Evaluation.BaselineComparison='COMPARED'
Write-ConversionFile $after.Data.CriteriaPath ($criteria|ConvertTo-Json -Depth 15)
$null=Invoke-ConversionApply $f.Workspace $f.Pom
$p=Get-HarnessProjectReference $f.Workspace $f.Pom
$review=Get-HarnessSonarReview $f.Workspace (Join-Path $p.Folder 'atual/diagnosticos/sonar/resultado.json')
Assert ($review.Assessment.BaselineAnalysisId -eq 'antes' -and $review.Assessment.BaselineComparison -eq 'COMPARED') 'Identidade e comparacao do baseline explicito preservadas sem selecionar outro ANTES.'
Assert (-not $review.Result.BaselineResultPath -and -not (Test-Path -LiteralPath (Join-Path $p.Folder 'atual/diagnosticos/sonar/antes'))) 'Conversao nao duplica baseline nem conserva dependencia de recibo.'

$f=New-ConversionFixture
$partial=Add-LegacySonar $f 'parcial' '2026-10-03T10:00:00Z' -Incomplete
$other=Add-LegacySonar $f 'outra-branch' '2026-10-04T10:00:00Z' -Incomplete
$other.Data.BranchName='outra'; Write-ConversionFile $other.Path ($other.Data|ConvertTo-Json -Depth 12)
$before=Get-ConversionState $f
Reject {Invoke-ConversionApply $f.Workspace $f.Pom} 'Origens Sonar distintas exigem escolha, sem usar a data para trocar branch.'
Assert ((Get-ConversionState $f) -ceq $before) 'Ambiguidade de origem nao publica.'
$null=Invoke-ConversionApply $f.Workspace $f.Pom -SonarTentativa $partial.Path
$p=Get-HarnessProjectReference $f.Workspace $f.Pom
Assert (-not (Test-Path -LiteralPath (Join-Path $p.Folder 'atual/diagnosticos/sonar/resultado.json'))) 'Somente coleta parcial nao fabrica diagnostico completo.'
Assert (Test-Path -LiteralPath (Join-Path $p.Folder 'atual/diagnosticos/sonar-tentativa.json')) 'Tentativa parcial escolhida permanece disponivel.'

$f=New-ConversionFixture
$usable=Add-LegacySonar $f 'concorrencia' '2026-10-02T10:00:00Z'
Add-LegacySonarDecision $usable
$module=Get-Module ConversaoPublicacao
& $module {
    param($Directory)
    $script:originalBuilder=${function:New-ConversionCoreFiles}; $script:decisionDirectory=$Directory
    Set-Item function:script:New-ConversionCoreFiles {
        param($Inputs,$Mta,$Priority,$Build,$Sonar,$Attempt)
        $state=& $script:originalBuilder $Inputs $Mta $Priority $Build $Sonar $Attempt
        [IO.File]::WriteAllText((Join-Path $script:decisionDirectory 'decision_000002.json'),'{}')
        $state
    }
} (Join-Path $usable.Folder 'decisions')
try { Reject {Invoke-ConversionApply $f.Workspace $f.Pom} 'Nova decisao concorrente deve impedir publicacao de parecer antigo.' }
finally { & $module { Set-Item function:script:New-ConversionCoreFiles $script:originalBuilder } }
$p=Get-HarnessProjectReference $f.Workspace $f.Pom
Assert (-not (Test-Path -LiteralPath $p.Folder)) 'Mudanca concorrente nao publica conjunto parcial.'
'PASS: Sonar utilizavel, tentativa parcial, revisao humana, links e independencia de recibos.'
