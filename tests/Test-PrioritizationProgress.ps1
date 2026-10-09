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
foreach ($relative in @('doc/especificacoes/planejamento-copilot.md','.github/prompts/priorizar-issues.prompt.md','doc/modelos/indice-priorizacao.template.md')) {
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
function Read-Receipt($prepared) { Get-Content $prepared.ContextPath -Raw -Encoding UTF8 | ConvertFrom-Json }
function Save-Ranking($prepared, $examined, $proposed) {
    $result = @{RequestId=$prepared.RequestId;Status='COMPLETED';AnalyzedIssues=@($examined);ProposedIssues=@($proposed)} | ConvertTo-Json -Depth 6
    $body = '# Ranking de teste' + "`n<!-- priorizacao:resultado -->`n" + '```json' + "`n$result`n" + '```' + "`n<!-- /priorizacao:resultado -->`n"
    [IO.File]::WriteAllText($prepared.RankingPath, $body)
    $receipt=Read-Receipt $prepared
    if ($receipt.PSObject.Properties['FichaPaths']) {
        foreach ($issue in $examined) {
            $fichas=@($receipt.FichaPaths | Where-Object { $_.Source -eq $issue.Source -and $_.Id -ceq $issue.Id })
            if ($fichas.Count -eq 1) {
                $identity=@{Source=$issue.Source;Id=$issue.Id}|ConvertTo-Json -Compress
                $null=[IO.Directory]::CreateDirectory((Split-Path $fichas[0].Path -Parent))
                [IO.File]::WriteAllText($fichas[0].Path,"# Ficha de teste`n<!-- issue: $identity -->`nEvidencia da fixture.")
            }
        }
    }
}
$first = New-HarnessPrioritizationContext $context -Percentage '10,00'
$initial = Read-Receipt $first
Assert ((Test-Path $first.PrioritizationIndexPath) -and $initial.PrioritizationIndexTemplateSnapshot -eq [IO.File]::ReadAllText((Join-Path $fixture 'doc/modelos/indice-priorizacao.template.md'))) 'Preparo nao publicou indice/template no contexto.'
Assert ([IO.File]::ReadAllText($first.PrioritizationIndexPath) -match 'PENDENTE') 'Preparo nao pode contar como exame.'
Assert ($initial.InitialTotal -eq 200 -and $initial.SliceSize -eq 20) '200 issues a 10% devem produzir quota 20, sem contar ocorrencias.'
$pending = New-HarnessPrioritizationContext $context -Mode Continue
Assert ($pending.RequestId -eq $first.RequestId -and $pending.Reused) 'Preparo sem resultado deve ser retomado sem nova fatia.'
Reject { New-HarnessPrioritizationContext $context -Percentage 10 } 'Solicitacao existente exige escolher recriar/progredir.'
Save-Ranking $first $initial.AvailableIssues[0..19] $initial.AvailableIssues[0..19]
$priorModule=Get-Module HarnessPrioritization
& $priorModule { param($r) Update-PrioritizationIndex $r } $fixture | Out-Null
Assert ([IO.File]::ReadAllText($first.PrioritizationIndexPath) -match '20 de 200') 'Fixture precisa comecar com fatia indexada.'
$completeText=[IO.File]::ReadAllText($first.RankingPath)
[IO.File]::WriteAllText($first.RankingPath,$completeText.Replace('COMPLETED','IN_PROGRESS'))
$requestCount=@(Get-ChildItem (Join-Path $fixture '.harness/priorizacao') -Directory).Count
Reject { New-HarnessPrioritizationContext $context -Mode Continue -Percentage 10 } 'Parcial permitiu progresso.'
$indexText=[IO.File]::ReadAllText($first.PrioritizationIndexPath)
Assert ($indexText -match 'NAO_VALIDADA' -and $indexText -notmatch '20 de 200') 'Continue recusado deixou cobertura antiga no indice.'
Assert (@(Get-ChildItem (Join-Path $fixture '.harness/priorizacao') -Directory).Count -eq $requestCount) 'Continue recusado criou fatia.'
[IO.File]::WriteAllText($first.RankingPath,$completeText)
# V4: um bloco completo sem a ficha individual nao pode manter cobertura conferida.
& $priorModule { param($r) Update-PrioritizationIndex $r } $fixture | Out-Null
$fichaPath=@($initial.FichaPaths | Where-Object { $_.Id -ceq $initial.AvailableIssues[0].Id })[0].Path
[IO.File]::Move($fichaPath,($fichaPath+'.missing'))
try {
    Reject { New-HarnessPrioritizationContext $context -Mode Continue -Percentage 10 } 'Ficha ausente permitiu progresso.'
    $indexText=[IO.File]::ReadAllText($first.PrioritizationIndexPath)
    Assert ($indexText -match 'Falta ficha' -and $indexText -notmatch '20 de 200') 'Ficha ausente conservou cobertura no indice.'
} finally { [IO.File]::Move(($fichaPath+'.missing'),$fichaPath) }
$second = New-HarnessPrioritizationContext $context -Mode Continue -Percentage 10
$next = Read-Receipt $second
Assert ([IO.File]::ReadAllText($second.PrioritizationIndexPath) -match '20 de 200') 'Continue nao reconciliou exame anterior no indice.'
Assert ($next.InitialTotal -eq 200 -and $next.SliceSize -eq 20 -and $next.AvailableIssues.Count -eq 180) 'Avanco deve manter denominador 200 e excluir 20 propostas.'
Assert ($next.Previous.RequestId -eq $first.RequestId -and $next.SequenceId -eq $initial.SequenceId) 'Sequencia nao vinculada.'
$seen = @($initial.AvailableIssues[0..19].Id)
Assert (@($next.AvailableIssues | Where-Object { $_.Id -in $seen }).Count -eq 0) 'Propostas repetidas na nova fatia.'
Save-Ranking $second $next.AvailableIssues[0..19] $next.AvailableIssues[0..9]
$third = New-HarnessPrioritizationContext $context -Mode Continue -Percentage '100%'
$last = Read-Receipt $third
Assert ($last.InitialTotal -eq 200 -and $last.SliceSize -eq 160 -and $last.ExcludedIssues.Count -eq 40) 'Todas as examinadas devem ser excluidas cumulativamente, mesmo sem proposta.'
Assert (@($last.AvailableIssues | Where-Object Id -eq $next.AvailableIssues[10].Id).Count -eq 0) 'Examinada sem proposta voltou para a fila.'
Save-Ranking $third $last.AvailableIssues $last.AvailableIssues
$count = @(Get-ChildItem (Join-Path $fixture '.harness/priorizacao') -Directory).Count
$done = New-HarnessPrioritizationContext $context -Mode Continue -Percentage 10
Assert ([IO.File]::ReadAllText($done.PrioritizationIndexPath) -match '200 de 200.*100') 'Esgotamento nao atualizou cobertura final.'
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
Save-Ranking $validation @() @()
Reject { New-HarnessPrioritizationContext $context -Mode Continue -Percentage 10 } 'Resultado vazio concluiu fatia nao vazia.'
Save-Ranking $validation @($validationReceipt.AvailableIssues[0]) @()
Reject { New-HarnessPrioritizationContext $context -Mode Continue -Percentage 10 } 'COMPLETED com cobertura parcial aceito.'
Save-Ranking $validation $validationReceipt.AvailableIssues[0..19] @()
[IO.File]::WriteAllText($validation.RankingPath, ([IO.File]::ReadAllText($validation.RankingPath).Replace('COMPLETED','IN_PROGRESS')))
Reject { New-HarnessPrioritizationContext $context -Mode Continue -Percentage 10 } 'IN_PROGRESS consumiu fatia.'
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
foreach ($entry in $fork.FichaPaths) { $entry.Path=$entry.Path.Replace($validation.RequestId.Substring(0,12),$fork.RequestId.Substring(0,12)) }
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
Save-Ranking $multi $multiReceipt.AvailableIssues[0..3] $one
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
# Regressao do ensaio: 44 issues, 20%, poucas ou nenhuma proposta; 5 rodadas sem repeticao.
$fortyFour = [regex]::Replace($otherText, '(?m)^\| r::(?:4[5-9]|[5-9]\d|[12]\d\d) \|.*\r?\n', '')
[IO.File]::WriteAllText($otherPaths.MigrationPath, $fortyFour)
$recordHash = (Get-FileHash $otherPaths.MigrationPath).Hash
$covered = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
$sizes = @()
foreach ($round in 1..5) {
    $mode = if ($round -eq 1) { 'Recreate' } else { 'Continue' }
    $batch = New-HarnessPrioritizationContext $context -Mode $mode -Percentage '20%'
    $batchReceipt = Read-Receipt $batch
    Assert ($batchReceipt.InitialTotal -eq 44 -and $batchReceipt.AvailableIssues.Count -eq (44 - $covered.Count)) 'Base/cobertura incorreta no caso 44/20%.'
    $examined = @($batchReceipt.AvailableIssues | Select-Object -First $batchReceipt.SliceSize)
    foreach ($issue in $examined) { Assert ($covered.Add(($issue.Source + '::' + $issue.Id))) 'Issue reexaminada entre rodadas.' }
    $sizes += $examined.Count
    $proposed = @(if ($round -ne 2) { $examined[0] })
    Save-Ranking $batch $examined $proposed
}
Assert (($sizes -join ',') -eq '9,9,9,9,8' -and $covered.Count -eq 44) 'Cinco rodadas de 20% nao cobriram as 44 issues.'
$folderCount = @(Get-ChildItem (Join-Path $fixture '.harness/priorizacao') -Directory).Count
Assert ((New-HarnessPrioritizationContext $context -Mode Continue).Status -eq 'EXHAUSTED') '44 issues examinadas nao esgotaram a base.'
Assert (@(Get-ChildItem (Join-Path $fixture '.harness/priorizacao') -Directory).Count -eq $folderCount) 'Esgotamento criou pasta adicional.'
Assert ((Get-FileHash $otherPaths.MigrationPath).Hash -eq $recordHash) 'Priorizacao alterou o registro da aplicacao.'

# Historico v2 pode repetir examinadas: consumir uniao distinta sem editar recibos/resultados.
$legacy = New-HarnessPrioritizationContext $context -Mode Recreate -Percentage 20
$legacyReceipt = Read-Receipt $legacy
$legacyReceipt.SchemaVersion = 2
Write-HarnessJson $legacy.ContextPath $legacyReceipt
Save-Ranking $legacy $legacyReceipt.AvailableIssues[0..8] @($legacyReceipt.AvailableIssues[0])
$legacyNext = New-HarnessPrioritizationContext $context -Mode Continue -Percentage 20
$legacyNextReceipt = Read-Receipt $legacyNext
Assert ($legacyNextReceipt.SchemaVersion -eq 4 -and $legacyNextReceipt.ExcludedIssues.Count -eq 9 -and $legacyNextReceipt.AvailableIssues.Count -eq 35) 'Continue nao aproveitou examinadas v2.'
# Emular a segunda rodada antiga, que retirava apenas a primeira proposta.
$legacyNextReceipt.SchemaVersion = 2
$legacyNextReceipt.ExcludedIssues = @($legacyReceipt.AvailableIssues[0])
$legacyNextReceipt.AvailableIssues = @($legacyReceipt.AvailableIssues[1..43])
Write-HarnessJson $legacyNext.ContextPath $legacyNextReceipt
Save-Ranking $legacyNext $legacyNextReceipt.AvailableIssues[0..8] @($legacyNextReceipt.AvailableIssues[8])
$historicalFiles = @($legacy.ContextPath,$legacy.RankingPath,$legacyNext.ContextPath,$legacyNext.RankingPath)
$historicalHashes = @($historicalFiles | ForEach-Object { Get-FileHash -LiteralPath $_ })
$upgraded = Read-Receipt (New-HarnessPrioritizationContext $context -Mode Continue -Percentage 20)
Assert ($upgraded.SequenceId -eq $legacyReceipt.SequenceId -and $upgraded.InitialTotal -eq 44 -and $upgraded.ExcludedIssues.Count -eq 10 -and $upgraded.AvailableIssues.Count -eq 34) 'Uniao das examinadas v2 sobrepostas incorreta.'
foreach ($file in $historicalHashes) { Assert ((Get-FileHash $file.Path).Hash -eq $file.Hash) 'Upgrade alterou evidencia historica.' }

# COMPLETED parcial v2 continua historico valido; nao inventar cobertura para completar quota antiga.
$partialLegacy = New-HarnessPrioritizationContext $context -Mode Recreate -Percentage 20
$partialReceipt = Read-Receipt $partialLegacy
$partialReceipt.SchemaVersion = 2
Write-HarnessJson $partialLegacy.ContextPath $partialReceipt
Save-Ranking $partialLegacy @($partialReceipt.AvailableIssues[0]) @()
$afterPartial = Read-Receipt (New-HarnessPrioritizationContext $context -Mode Continue -Percentage 20)
Assert ($afterPartial.ExcludedIssues.Count -eq 1 -and $afterPartial.AvailableIssues.Count -eq 43) 'Historico parcial v2 rejeitado ou cobertura inventada.'
# Retirada humana depois do preparo nao pode completar artificialmente a quota.
[IO.File]::WriteAllText($otherPaths.MigrationPath, $smallText)
$withdrawal = New-HarnessPrioritizationContext $context -Mode Recreate -Percentage 100
$withdrawalReceipt = Read-Receipt $withdrawal
Assert ($withdrawalReceipt.SliceSize -eq 2) 'Cenario de retirada deve iniciar com quota dois.'
[IO.File]::WriteAllText($otherPaths.MigrationPath, $smallText.Replace('r::2 | Regra 2 | mandatory | 500 | PRESENTE | A DEFINIR','r::2 | Regra 2 | mandatory | 500 | PRESENTE | ADIAR'))
Save-Ranking $withdrawal @($withdrawalReceipt.AvailableIssues[0]) @()
Reject { New-HarnessPrioritizationContext $context -Mode Continue -Percentage 100 } 'Retirada humana preencheu quota sem exame.'
[IO.File]::WriteAllText($withdrawal.RankingPath, ([IO.File]::ReadAllText($withdrawal.RankingPath).Replace('COMPLETED','IN_PROGRESS')))
$partialHash = (Get-FileHash $withdrawal.RankingPath).Hash
$afterWithdrawal = Read-Receipt (New-HarnessPrioritizationContext $context -Mode Recreate -Percentage 100)
Assert ($afterWithdrawal.InitialTotal -eq 1 -and $afterWithdrawal.SliceSize -eq 1 -and $afterWithdrawal.AvailableIssues[0].Id -eq 'r::1') 'Recriacao nao refletiu a nova selecao humana.'
Assert ((Get-FileHash $withdrawal.RankingPath).Hash -eq $partialHash) 'Recriacao apagou parcial da selecao anterior.'
Write-Output 'PASS: cobertura 44/20% em 9+9+9+9+8, zero propostas, historico v2, quota, continuidade e integridade.'
