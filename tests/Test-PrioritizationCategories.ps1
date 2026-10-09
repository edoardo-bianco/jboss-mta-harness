#requires -Version 5.1
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $root 'scripts/Harness.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $root 'scripts/HarnessPrioritization.psm1') -Force -DisableNameChecking
function Assert($value, $message) { if (-not $value) { throw $message } }
function Reject($action, $message) { $failed=$false; try { & $action | Out-Null } catch { $failed=$true }; Assert $failed $message }
$area = Join-Path $root ('.harness/tests/categories-' + [guid]::NewGuid().ToString('N'))
$fixture = Join-Path $area 'harness'
$project = [pscustomobject]@{name='app';label='App';path=(Join-Path $area 'app')}
$null = [IO.Directory]::CreateDirectory($project.path)
Set-Content (Join-Path $project.path 'pom.xml') '<project/>'
$paths = Initialize-HarnessMigration $fixture $project
$context = [pscustomobject]@{Root=$fixture;Projects=@($project);WorkspacePath=$null;ConfigPath=$null}
foreach ($relative in @('doc/especificacoes/planejamento-copilot.md','.github/prompts/priorizar-issues.prompt.md','doc/modelos/indice-priorizacao.template.md')) {
    $dest=Join-Path $fixture $relative
    $null=[IO.Directory]::CreateDirectory((Split-Path $dest -Parent))
    Copy-Item (Join-Path $root $relative) $dest
}
Set-Content (Join-Path $fixture '.harness/projetos/indice-projetos.md') '# Indice'
$run=Join-Path $area 'mta'; $runId='a'*32
foreach ($dir in @('input','rules','output/static-report')) { $null=[IO.Directory]::CreateDirectory((Join-Path $run $dir)) }
Write-HarnessJson (Join-Path $run 'manifest.json') @{RunId=$runId;Project='origem';Source='Z:/app';CreatedAtUtc='2026-10-01T10:00:00Z'}
Write-HarnessJson (Join-Path $run 'result.json') @{RunId=$runId;Project='origem';Status='SUCCEEDED';ExitCode=0;SourceUnchanged=$true;SnapshotOriginalFilesUnchanged=$true;RulesUnchanged=$true;UnexpectedAddedFiles=@()}
foreach ($file in @('output/output.yaml','output/dependencies.yaml','output/static-report/index.html')) { Set-Content (Join-Path $run $file) 'fixture' }
$origin=@{RunId=$runId;Project='origem';Source='Z:/app';Run=$run}|ConvertTo-Json -Compress
$rows=@(); $violations=[ordered]@{}
foreach ($category in @('mandatory','optional','potential','custom')) {
    foreach ($n in 1..2) {
        $id="$category-$n"
        $rows+="| r::$id | Regra $id | $category | 0 | PRESENTE | A DEFINIR | NAO ANALISADA | |"
        $violations[$id]=@{description=$id;category=$category;incidents=@()}
    }
}
$catalog=@(@{rulesets=@(@{name='r';violations=$violations})})|ConvertTo-Json -Depth 12 -Compress
Set-Content (Join-Path $run 'output/static-report/output.js') ('window["apps"] = ['+$catalog+'];')
$text=[IO.File]::ReadAllText($paths.MigrationPath).Replace('AGUARDANDO MTA','')
$text=$text.Replace('<!-- mta:fim -->', ((@("<!-- MTA $origin -->","Rodada MTA: $runId.")+$rows)-join "`n")+"`n<!-- mta:fim -->")
[IO.File]::WriteAllText($paths.MigrationPath,$text)
$registerHash=(Get-FileHash $paths.MigrationPath).Hash
function Receipt($prepared) { Get-Content $prepared.ContextPath -Raw -Encoding UTF8 | ConvertFrom-Json }
function Complete($prepared) {
    $r=Receipt $prepared; $examined=@($r.AvailableIssues | Select-Object -First $r.SliceSize)
    $result=@{RequestId=$r.RequestId;Status='COMPLETED';AnalyzedIssues=$examined;ProposedIssues=@()}|ConvertTo-Json -Depth 8
    [IO.File]::WriteAllText($r.RankingPath, ('<!-- priorizacao:resultado -->'+"`n"+'```json'+"`n$result`n"+'```'+"`n<!-- /priorizacao:resultado -->"))
    foreach ($issue in $examined) {
        $ficha=@($r.FichaPaths | Where-Object { $_.Source -eq $issue.Source -and $_.Id -ceq $issue.Id })[0]
        $identity=@{Source=$issue.Source;Id=$issue.Id}|ConvertTo-Json -Compress
        $null=[IO.Directory]::CreateDirectory((Split-Path $ficha.Path -Parent))
        [IO.File]::WriteAllText($ficha.Path,"# Ficha de teste`n<!-- issue: $identity -->`nEvidencia examinada na fixture.")
    }
}
$mandatory=New-HarnessPrioritizationContext $context -Category mandatory -Percentage 50
$m=Receipt $mandatory
Assert ($m.Category -eq 'mandatory' -and $m.InitialTotal -eq 2 -and $m.SliceSize -eq 1) 'Base mandatory incorreta.'
Complete $mandatory
$optional=New-HarnessPrioritizationContext $context -Category optional -Percentage 50
$o=Receipt $optional
Assert ($o.Category -eq 'optional' -and $o.InitialTotal -eq 2 -and $o.SequenceId -ne $m.SequenceId -and -not $o.Previous) 'optional misturou a sequencia mandatory.'
Complete $optional
$next=New-HarnessPrioritizationContext $context -Category mandatory -Mode Continue -Percentage 50
$n=Receipt $next
Assert ($n.SequenceId -eq $m.SequenceId -and $n.ExcludedIssues.Count -eq 1 -and $n.AvailableIssues[0].Id -eq 'r::mandatory-2') 'Retorno mandatory perdeu cobertura.'
$resume=New-HarnessPrioritizationContext $context -PreviousRequestId $optional.RequestId -Mode Continue -Percentage 50
Assert ((Receipt $resume).Category -eq 'optional') 'Continue explicito nao herdou categoria.'
Reject { New-HarnessPrioritizationContext $context -PreviousRequestId $optional.RequestId -Category mandatory -Mode Continue } 'Continue cruzou categorias.'
foreach ($cat in @('potential','custom')) {
    $p=New-HarnessPrioritizationContext $context -Category $cat -Percentage 100
    Assert ((Receipt $p).InitialTotal -eq 2) 'Categoria recebida nao preservada.'
}
Reject { New-HarnessPrioritizationContext $context -Category typo -Percentage 100 } 'Categoria desconhecida aceita.'
Assert ((Get-FileHash $paths.MigrationPath).Hash -eq $registerHash) 'Registro modificado.'
$ficha=@($m.FichaPaths | Where-Object Id -EQ $m.AvailableIssues[0].Id)[0].Path
$originalFicha=[IO.File]::ReadAllText($ficha)
Add-Content $ficha 'Mudanca posterior ao avanco'
Reject { New-HarnessPrioritizationContext $context -Category mandatory -Mode Continue } 'Alteracao da ficha ancestral aceita.'
[IO.File]::WriteAllText($ficha,$originalFicha)
$second=[pscustomobject]@{name='app2';label='App dois';path=(Join-Path $area 'app2')}
$null=[IO.Directory]::CreateDirectory($second.path)
Set-Content (Join-Path $second.path 'pom.xml') '<project><artifactId>app-dois</artifactId></project>'
$secondPaths=Initialize-HarnessMigration $fixture $second
$secondText=[IO.File]::ReadAllText($secondPaths.MigrationPath).Replace('AGUARDANDO MTA','')
$secondText=$secondText.Replace('<!-- mta:fim -->', ((@("<!-- MTA $origin -->","Rodada MTA: $runId.")+$rows)-join "`n")+"`n<!-- mta:fim -->")
[IO.File]::WriteAllText($secondPaths.MigrationPath,$secondText)
$context.Projects=@($project,$second)
$both=New-HarnessPrioritizationContext $context -Category potential -Percentage 100
$bothReceipt=Receipt $both
$shared=@($bothReceipt.FichaPaths | Where-Object Id -EQ 'r::potential-1')
Assert ($shared.Count -eq 2 -and $shared[0].Path -ne $shared[1].Path -and $shared[0].Source -ne $shared[1].Source) 'Mesma regra misturou fichas de projetos distintos.'
Complete $both
foreach ($entry in $shared) { Assert-HarnessIssueFicha $entry.Path $entry.Source $entry.Id }
# Entrada publica preserva a categoria tambem em JSON, sem menus.
$scripts=Join-Path $fixture 'scripts'; $null=[IO.Directory]::CreateDirectory($scripts)
foreach ($name in @('Harness.psm1','HarnessPlanning.psm1','HarnessPlanningInput.ps1','HarnessIssuePlanning.ps1','HarnessPrioritization.psm1','HarnessPrioritizationState.ps1','HarnessPrioritizationEvidence.ps1','HarnessPrioritizationIndex.ps1','preparar-priorizacao.ps1')) { Copy-Item (Join-Path $root ('scripts/'+$name)) $scripts }
$config=Get-Content (Join-Path $root 'config/harness.example.json') -Raw | ConvertFrom-Json
$config.repositories=@(@{name='app';path=$project.path},@{name='app2';path=$second.path}); $config.activeProject=$null
$configPath=Join-Path $fixture 'config.json'; Write-HarnessJson $configPath $config
$output=& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $scripts 'preparar-priorizacao.ps1') -ConfigPath $configPath -Category optional -Percentage 50 -Mode Recreate -NoOpen -OutputFormat Json 2>&1 | Out-String
Assert ($LASTEXITCODE -eq 0 -and ($output | ConvertFrom-Json).Category -eq 'optional') ('CLI perdeu categoria: '+$output)
Write-Output 'PASS: categorias independentes, cobertura, retomada, categoria recebida e conflitos.'
