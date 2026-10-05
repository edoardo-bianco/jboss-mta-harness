#requires -Version 5.1
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $root 'scripts/Harness.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $root 'scripts/HarnessPrioritization.psm1') -Force -DisableNameChecking
function Assert($condition, $message) { if (-not $condition) { throw $message } }
function Reject($action, $message) {
    $failed = $false
    try { & $action | Out-Null } catch { $failed = $true }
    Assert $failed $message
}
$area = Join-Path $root ('.harness/tests/percentual-' + [guid]::NewGuid().ToString('N'))
$fixture = Join-Path $area 'harness'
$source = Join-Path $area 'app'
$null = [IO.Directory]::CreateDirectory($source)
Set-Content (Join-Path $source 'pom.xml') '<project/>'
$project = [pscustomobject]@{name='app';label='app';path=$source}
$context = [pscustomobject]@{Root=$fixture;Projects=@($project);ConfigPath=$null;WorkspacePath=$null}
$paths = Initialize-HarnessMigration $fixture $project
Set-Content (Join-Path $fixture '.harness/projetos/indice-projetos.md') '# Indice'
foreach ($relative in @('doc/especificacoes/planejamento-copilot.md','.github/prompts/priorizar-issues.prompt.md')) {
    $destination = Join-Path $fixture $relative
    $null = [IO.Directory]::CreateDirectory((Split-Path $destination -Parent))
    Copy-Item (Join-Path $root $relative) $destination
}
$run = Join-Path $area 'mta'
$runId = 'a' * 32
foreach ($folder in @('input','rules','output/static-report')) { $null = [IO.Directory]::CreateDirectory((Join-Path $run $folder)) }
Write-HarnessJson (Join-Path $run 'manifest.json') @{RunId=$runId;Project='origem';Source='Z:/origem';CreatedAtUtc='2026-10-01T10:00:00Z'}
Write-HarnessJson (Join-Path $run 'result.json') @{RunId=$runId;Project='origem';Status='SUCCEEDED';ExitCode=0;SourceUnchanged=$true;SnapshotOriginalFilesUnchanged=$true;RulesUnchanged=$true;UnexpectedAddedFiles=@()}
foreach ($file in @('output/output.yaml','output/dependencies.yaml','output/static-report/index.html','output/static-report/output.js')) { Set-Content (Join-Path $run $file) 'fixture' }
$origin = @{RunId=$runId;Project='origem';Source='Z:/origem';Run=$run} | ConvertTo-Json -Compress
$text = [IO.File]::ReadAllText($paths.MigrationPath).Replace('AGUARDANDO MTA', '')
$rows = @(1..200 | ForEach-Object { "| r::$_ | Regra $_ | mandatory | 500 | PRESENTE | A DEFINIR | NAO ANALISADA | |" })
$text = $text.Replace('<!-- mta:fim -->', ((@("<!-- MTA $origin -->", "Rodada MTA: $runId.") + $rows) -join "`n") + "`n<!-- mta:fim -->")
[IO.File]::WriteAllText($paths.MigrationPath, $text)
function Read-Receipt($prepared) { Get-Content $prepared.ContextPath -Raw | ConvertFrom-Json }
function Save-Ranking($prepared, $examined, $proposed) {
    $result = @{RequestId=$prepared.RequestId;Status='COMPLETED';AnalyzedIssues=@($examined);ProposedIssues=@($proposed)} | ConvertTo-Json -Depth 6
    $body = '# Ranking de teste' + "`n<!-- priorizacao:resultado -->`n" + '```json' + "`n$result`n" + '```' + "`n<!-- /priorizacao:resultado -->`n"
    [IO.File]::WriteAllText($prepared.RankingPath, $body)
}
$first = New-HarnessPrioritizationContext $context -Percentage '10,00'
$initial = Read-Receipt $first
Assert ($initial.InitialTotal -eq 200 -and $initial.SliceSize -eq 20) '200 issues a 10% devem produzir quota 20, sem contar ocorrencias.'
$pending = New-HarnessPrioritizationContext $context -Mode Continue
Assert ($pending.RequestId -eq $first.RequestId -and $pending.Reused) 'Preparo sem resultado deve ser retomado sem nova fatia.'
Reject { New-HarnessPrioritizationContext $context -Percentage 10 } 'Solicitacao existente exige escolher recriar/progredir.'
Save-Ranking $first $initial.AvailableIssues[0..19] $initial.AvailableIssues[0..19]
$second = New-HarnessPrioritizationContext $context -Mode Continue -Percentage 10
$next = Read-Receipt $second
Assert ($next.InitialTotal -eq 200 -and $next.SliceSize -eq 20 -and $next.AvailableIssues.Count -eq 180) 'Avanco deve manter denominador 200 e excluir 20 propostas.'
Assert ($next.Previous.RequestId -eq $first.RequestId -and $next.SequenceId -eq $initial.SequenceId) 'Sequencia nao vinculada.'
$seen = @($initial.AvailableIssues[0..19].Id)
Assert (@($next.AvailableIssues | Where-Object { $_.Id -in $seen }).Count -eq 0) 'Propostas repetidas na nova fatia.'
Save-Ranking $second $next.AvailableIssues[0..19] $next.AvailableIssues[0..9]
$third = New-HarnessPrioritizationContext $context -Mode Continue -Percentage '100%'
$last = Read-Receipt $third
Assert ($last.InitialTotal -eq 200 -and $last.SliceSize -eq 170 -and $last.ExcludedIssues.Count -eq 30) 'Somente propostas devem ser excluidas cumulativamente.'
Assert (@($last.AvailableIssues | Where-Object Id -eq $next.AvailableIssues[10].Id).Count -eq 1) 'Examinada sem proposta deve continuar disponivel.'
Save-Ranking $third $last.AvailableIssues $last.AvailableIssues
$count = @(Get-ChildItem (Join-Path $fixture '.harness/priorizacao') -Directory).Count
$done = New-HarnessPrioritizationContext $context -Mode Continue -Percentage 10
Assert ($done.Status -eq 'EXHAUSTED' -and @(Get-ChildItem (Join-Path $fixture '.harness/priorizacao') -Directory).Count -eq $count) 'Esgotamento nao deve criar solicitacao vazia.'
Assert ($done.SliceSize -eq 0 -and (New-HarnessPrioritizationContext $context -Mode Continue).Status -eq 'EXHAUSTED') 'Esgotamento nao deve pedir percentual nem exibir quota antiga.'
$fresh = New-HarnessPrioritizationContext $context -Mode Recreate -Percentage '0,01'
$restart = Read-Receipt $fresh
Assert ($restart.SliceSize -eq 1 -and $restart.InitialTotal -eq 200 -and $restart.ExcludedIssues.Count -eq 0 -and $restart.SequenceId -ne $initial.SequenceId) 'Recriacao deve recomecar universo e arredondar para cima.'
Assert (Test-Path $first.RankingPath) 'Recriacao apagou historico.'
Set-Content $fresh.RankingPath '# Saida incompleta'
Reject { New-HarnessPrioritizationContext $context -Mode Continue -Percentage 10 } 'Arquivo incompleto foi tratado como analise concluida.'
Save-Ranking $fresh $restart.AvailableIssues[0..1] $restart.AvailableIssues[0..1]
Reject { New-HarnessPrioritizationContext $context -Mode Continue -Percentage 10 } 'Analise acima da quota aceita.'
Save-Ranking $fresh @($restart.AvailableIssues[0]) @([pscustomobject]@{Source=$source;Id='r::inexistente'})
Reject { New-HarnessPrioritizationContext $context -Mode Continue -Percentage 10 } 'Proposta fora da fatia aceita.'
Save-Ranking $fresh @($restart.AvailableIssues[0]) @($restart.AvailableIssues[0])
# Decisao humana muda disponibilidade, nao a base fixa.
[IO.File]::WriteAllText($paths.MigrationPath, $text.Replace('r::200 | Regra 200 | mandatory | 500 | PRESENTE | A DEFINIR','r::200 | Regra 200 | mandatory | 500 | PRESENTE | ADIAR'))
$filtered = New-HarnessPrioritizationContext $context -Mode Continue -Percentage 10
$filteredReceipt = Read-Receipt $filtered
Assert ($filteredReceipt.InitialTotal -eq 200 -and $filteredReceipt.AvailableIssues.Count -eq 198 -and $filteredReceipt.SliceSize -eq 20) 'Decisao atual alterou denominador ou foi ignorada.'
$fromOld = New-HarnessPrioritizationContext $context -Mode Continue -PreviousRequestId $first.RequestId
Assert ($fromOld.RequestId -eq $filtered.RequestId -and $fromOld.Reused) 'Referencia antiga deve seguir sucessor unico.'
$savedRanking = [IO.File]::ReadAllText($fresh.RankingPath)
Add-Content $fresh.RankingPath 'Edicao posterior'
Reject { New-HarnessPrioritizationContext $context -Mode Continue } 'Ranking ancestral alterado foi ignorado na retomada pendente.'
[IO.File]::WriteAllText($fresh.RankingPath, $savedRanking)
Set-Content (Join-Path $run 'output/output.yaml') 'origem alterada'
Reject { New-HarnessPrioritizationContext $context -Mode Continue -Percentage 10 } 'Evidencia alterada foi retomada silenciosamente.'
Set-Content (Join-Path $run 'output/output.yaml') 'fixture'
$validation = New-HarnessPrioritizationContext $context -Mode Recreate -Percentage 10
$validationReceipt = Read-Receipt $validation
Save-Ranking $validation @($validationReceipt.AvailableIssues[0],$validationReceipt.AvailableIssues[0]) @()
Reject { New-HarnessPrioritizationContext $context -Mode Continue -Percentage 10 } 'Examinadas duplicadas aceitas.'
Save-Ranking $validation @($validationReceipt.AvailableIssues[0]) @($validationReceipt.AvailableIssues[1])
Reject { New-HarnessPrioritizationContext $context -Mode Continue -Percentage 10 } 'Proposta disponivel fora das examinadas aceita.'
Save-Ranking $validation @($validationReceipt.AvailableIssues[0]) @($validationReceipt.AvailableIssues[0],$validationReceipt.AvailableIssues[0])
Reject { New-HarnessPrioritizationContext $context -Mode Continue -Percentage 10 } 'Propostas duplicadas aceitas.'
Save-Ranking $validation @($validationReceipt.AvailableIssues[0]) @($validationReceipt.AvailableIssues[0])
# Simular segunda ponta para comprovar ausencia de eleicao por data.
$fork = Read-Receipt $validation
$fork.RequestId = [guid]::NewGuid().ToString('N'); $fork.SequenceId = $fork.RequestId
$forkFolder = Join-Path $fixture ('.harness/priorizacao/' + $fork.RequestId)
$fork.ContextPath = Join-Path $forkFolder 'context.json'
$fork.PromptPath = Join-Path $forkFolder 'priorizar-issues.prompt.md'
$fork.RankingPath = Join-Path $forkFolder 'priorizacao.md'
Write-HarnessJson $fork.ContextPath $fork
Copy-Item $validation.PromptPath $fork.PromptPath
Reject { New-HarnessPrioritizationContext $context -Mode Continue -Percentage 10 } 'Varias pontas foram escolhidas por recencia.'
Reject { New-HarnessPrioritizationContext $context -Mode Continue -PreviousRequestId $filtered.RequestId } 'Bifurcacao foi seguida sem escolha.'
$chosen = New-HarnessPrioritizationContext $context -Mode Continue -PreviousRequestId $fork.RequestId
Assert ($chosen.RequestId -eq $fork.RequestId) 'PreviousRequestId explicito nao resolveu frente.'
# Mesma regra em dois projetos deve contar/excluir separadamente.
$otherSource = Join-Path $area 'outro projeto'
$null = [IO.Directory]::CreateDirectory($otherSource)
Set-Content (Join-Path $otherSource 'pom.xml') '<project/>'
$otherProject = [pscustomobject]@{name='outro';label='outro';path=$otherSource}
$otherPaths = Initialize-HarnessMigration $fixture $otherProject
$otherText = $text.Replace('Project: app','Project: outro').Replace(('Source: ' + $source),('Source: ' + $otherSource))
[IO.File]::WriteAllText($otherPaths.MigrationPath, $otherText)
$context.Projects = @($project,$otherProject)
$multi = New-HarnessPrioritizationContext $context -Percentage 1
$multiReceipt = Read-Receipt $multi
Assert ($multiReceipt.InitialTotal -eq 399 -and $multiReceipt.SliceSize -eq 4) 'Mesmo ID em Sources diferentes deve contar separadamente.'
$one = @($multiReceipt.AvailableIssues | Where-Object { $_.Source -eq $source -and $_.Id -eq 'r::1' })
Save-Ranking $multi $one $one
$multiNext = Read-Receipt (New-HarnessPrioritizationContext $context -Mode Continue -Percentage 1)
Assert (@($multiNext.AvailableIssues | Where-Object { $_.Id -eq 'r::1' -and $_.Source -eq $otherSource }).Count -eq 1) 'Proposta vazou para outro projeto.'
# Arredondamento com universo pequeno.
$context.Projects = @($otherProject)
$smallText = [regex]::Replace($otherText, '(?m)^\| r::(?:[3-9]|[1-9]\d|[12]\d\d) \|.*\r?\n', '')
[IO.File]::WriteAllText($otherPaths.MigrationPath, $smallText)
foreach ($case in @(@('0,01',1),@('50',1),@('50,01',2),@('100,00',2))) {
    $small = Read-Receipt (New-HarnessPrioritizationContext $context -Mode Recreate -Percentage $case[0])
    Assert ($small.InitialTotal -eq 2 -and $small.SliceSize -eq $case[1]) ('Arredondamento incorreto para duas issues: ' + $case[0])
}
Write-Output 'PASS: percentual, base fixa, continuidade, propostas acumuladas, recriacao, retomada e integridade.'
