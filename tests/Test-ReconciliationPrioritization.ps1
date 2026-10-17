#requires -Version 5.1
$ErrorActionPreference='Stop'; Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'PlanningCurrentFixture.ps1')
function Write-ReceptionFile([string]$Path,[string]$Text) {
    $null=[IO.Directory]::CreateDirectory((Split-Path $Path -Parent))
    [IO.File]::WriteAllText($Path,$Text,(New-Object Text.UTF8Encoding($false)))
}
function Get-ReceptionState($Fixture) {
    @(Get-ChildItem -LiteralPath $Fixture.Root -File -Recurse|Sort-Object FullName|ForEach-Object { $_.FullName+' '+$_.LastWriteTimeUtc.Ticks+' '+(Get-FileHash -LiteralPath $_.FullName).Hash }) -join "`n"
}
function New-PriorityReception([switch]$Internal,[switch]$Multi) {
    $names=if ($Multi) {@('a','b')} else {@('a')}; $count=if ($Multi) {1} else {4}; $percentage=if ($Multi) {'100'} else {'50'}
    $source=New-PlanningFixture $count $names; $target=New-PlanningFixture $count $names
    $prepared=New-HarnessPrioritizationContext $source.Context -Percentage $percentage -Category mandatory -Scope 'p'
    $completed=Complete-Slice $source $prepared; $data=Read-Prepared $prepared
    foreach ($issue in $completed.AnalyzedIssues) {
        $project=@($source.Projects|Where-Object Name -CEQ $issue.Project)[0]
        $ficha=@($data.FichaPaths|Where-Object { $_.Project -ceq $issue.Project -and $_.Id -ceq $issue.Id })[0].Path
        $annex=if ($Multi -and $project.Name -ceq 'b') {'recebida-b.md'} else {'recebida.md'}
        $identity=@{Project=$issue.Project;Id=$issue.Id;Category='mandatory';LocalPaths=@('src/Exemplo.java');EvidencePaths=@($annex)}|ConvertTo-Json -Compress
        Write-ReceptionFile $ficha ("# Ficha recebida`nAnalise humana recebida do projeto "+$project.Name+".`n<!-- ficha:identidade:inicio -->`n"+$identity+"`n<!-- ficha:identidade:fim -->")
        Write-ReceptionFile (Join-Path $project.EvidencePath $annex) ('# Evidencia examinada na origem '+$project.Name)
    }
    $master=$target.Projects[0]; $sourceMaster=$source.Projects[0]
    $origin=if ($Internal) {Join-Path $master.Folder 'recebido'} else {Join-Path $target.Root 'colega'}
    $contextRelative=$prepared.ContextPath.Substring($sourceMaster.Folder.Length+1).Replace('\','/')
    $rankingRelative=$prepared.RankingPath.Substring($sourceMaster.Folder.Length+1).Replace('\','/')
    $relatives=@($contextRelative,$rankingRelative,'evidencias/recebida.md')
    foreach ($entry in $data.FichaPaths|Where-Object { $_.Project -ceq $master.Name -and $_.Id -cin @($completed.AnalyzedIssues.Id) }) { $relatives+=$entry.Path.Substring($sourceMaster.Folder.Length+1).Replace('\','/') }
    $decisions=@{}
    foreach ($relative in $relatives) { Write-ReceptionFile (Join-Path $origin $relative) ([IO.File]::ReadAllText((Join-Path $sourceMaster.Folder $relative))); $decisions[$relative]='RECEBIDO' }
    [pscustomobject]@{Source=$source;Target=$target;Master=$master;Prepared=$prepared;Data=$data;Result=$completed;Origin=$origin;ContextRelative=$contextRelative;RankingRelative=$rankingRelative;Decisions=$decisions}
}
function Reject-PriorityReception($Reception,[scriptblock]$Action,[string]$Pattern,[string]$Message) {
    $before=Get-ReceptionState $Reception.Target; $sourceBefore=Get-ReceptionState $Reception.Source
    $rejected=$false
    try { $null=& $Action } catch { Assert ($_.Exception.Message -match $Pattern) ($Message+' Erro inesperado: '+$_.Exception.Message); $rejected=$true }
    Assert $rejected $Message
    Assert ((Get-ReceptionState $Reception.Target) -ceq $before -and (Get-ReceptionState $Reception.Source) -ceq $sourceBefore) 'Recusa preserva projeto, proposta transitoria e arquivos recebidos/originais.'
}
function Adopt-ReceptionPeer($Reception) {
    $source=$Reception.Source.Projects[1]; $target=$Reception.Target.Projects[1]
    foreach ($entry in $Reception.Data.FichaPaths|Where-Object Project -CEQ $target.Name) {
        $relative=$entry.Path.Substring($source.Folder.Length+1)
        Write-ReceptionFile (Join-Path $target.Folder $relative) ([IO.File]::ReadAllText($entry.Path))
    }
    Write-ReceptionFile (Join-Path $target.EvidencePath 'recebida-b.md') ([IO.File]::ReadAllText((Join-Path $source.EvidencePath 'recebida-b.md')))
}

# Links exclusivos da narrativa tambem sustentam a examinada, mesmo com arrays vazios.
$r=New-PriorityReception -Internal
$entry=@($r.Data.FichaPaths|Where-Object Id -CEQ $r.Result.AnalyzedIssues[0].Id)[0]
$relative=$entry.Path.Substring($r.Source.Projects[0].Folder.Length+1)
$identity=@{Project=$r.Master.Name;Id=$entry.Id;Category='mandatory';LocalPaths=@();EvidencePaths=@()}|ConvertTo-Json -Compress
$missing=Join-Path $r.Source.Projects[0].Source 'src/Ausente.java'
Write-ReceptionFile (Join-Path $r.Origin $relative) ("# Ficha recebida`n[Codigo analisado](<"+$missing+">)`n<!-- ficha:identidade:inicio -->`n"+$identity+"`n<!-- ficha:identidade:fim -->")
$review=Start-HarnessReconciliationReview $r.Master $r.Origin
Reject-PriorityReception $r { Complete-HarnessReconciliation $r.Master -Conclusion 'Referencia apenas na narrativa' -Resolutions $r.Decisions } 'indisponivel|ausente|referencia|fonte|anexo' 'Ficha examinada com link narrativo ausente deve impedir adocao da cobertura.'

# A narrativa do ranking tambem precisa de referencias operacionais resolvidas.
$r=New-PriorityReception -Internal
$ranking=Join-Path $r.Origin $r.RankingRelative
$missing=Join-Path $r.Source.Projects[0].EvidencePath 'ausente-ranking.md'
Write-ReceptionFile $ranking ([IO.File]::ReadAllText($ranking)+"`n[Anexo exclusivo do ranking](<"+$missing+">)")
$review=Start-HarnessReconciliationReview $r.Master $r.Origin
Reject-PriorityReception $r { Complete-HarnessReconciliation $r.Master -Conclusion 'Anexo do ranking ausente' -Resolutions $r.Decisions } 'indisponivel|ausente|referencia|fonte|anexo' 'Ranking com link narrativo ausente nao pode publicar cobertura recebida.'
Write-ReceptionFile (Join-Path $r.Origin 'evidencias/ausente-ranking.md') '# Anexo recebido ainda sem decisao de adocao'
$r.Decisions['evidencias/ausente-ranking.md']='PENDENTE'
$review=Start-HarnessReconciliationReview $r.Master $r.Origin -Restart
Reject-PriorityReception $r { Complete-HarnessReconciliation $r.Master -Conclusion 'Anexo do ranking pendente' -Resolutions $r.Decisions } 'indisponivel|ausente|referencia|fonte|anexo|pendente' 'Presenca em recebido nao torna operacional o anexo pendente do ranking.'

# Origem externa conserva caminhos estrangeiros ate a associacao aos projetos locais.
$r=New-PriorityReception
$sourceBefore=Get-ReceptionState $r.Source
$review=Start-HarnessReconciliationReview $r.Master $r.Origin
Assert (@($review.Documents|Where-Object { $_.Path -in @($r.ContextRelative,$r.RankingRelative) -and $_.Kind -ceq 'PRIORIZACAO' }).Count -eq 2) 'Reconhecer contexto/ranking correntes como par de priorizacao recebida.'
$accepted=Complete-HarnessReconciliation $r.Master -Conclusion 'Cobertura e fichas recebidas conferidas no codigo local; GO e aceite separados.' -Resolutions $r.Decisions
Assert ($accepted.State -ceq 'CONCLUIDA' -and $accepted.NeedsReview) 'Adocao explicita conclui comparacao e exige revisao humana local.'
$localContext=Join-Path $r.Master.Folder $r.ContextRelative
$localData=Get-Content -LiteralPath $localContext -Raw|ConvertFrom-Json
$localPrepared=[pscustomobject]@{ContextPath=$localContext;RankingPath=(Join-Path $r.Master.Folder $r.RankingRelative)}
Assert ($localData.InitialTotal -eq 4 -and $localData.Percentage -eq 50 -and $localData.BaselineIssues.Count -eq 4 -and $localData.ExcludedIssues.Count -eq 0) 'Adocao conserva B0, denominador, percentual e exclusoes recebidos.'
Assert ((Read-Result $localPrepared).AnalyzedIssues.Count -eq 2) 'Resultado recebido conserva as examinadas e seus motivos.'
Assert ($localData.Projects[0].Source -ieq $r.Master.Source -and $localData.Projects[0].Pom -ieq $r.Master.Pom -and $localData.ContextPath -ieq $localContext) 'Identidade e destinos estrangeiros sao associados ao Source/POM local.'
Assert ([IO.File]::ReadAllText($localContext) -notmatch [regex]::Escape($r.Source.Root.Replace('\','\\'))) 'Contexto adotado nao depende de caminhos da maquina de origem.'
foreach ($path in @($localData.PromptPath,$localData.IndexPath)) { Assert (Test-Path -LiteralPath $path) ('Prompt e indice do escopo devem ser regenerados: '+$path) }
Assert ([IO.File]::ReadAllText($r.Master.IndexPath).Contains('atual/priorizacao/mandatory/escopos/p/indice.md')) 'Indice local do mestre aponta para o escopo adotado.'
Assert ((Get-ReceptionState $r.Source) -ceq $sourceBefore) 'Origem externa permanece intacta.'
$next=New-HarnessPrioritizationContext $r.Target.Context -Percentage 50 -Category mandatory -Scope p -Mode Continue
$continued=Read-Prepared $next
Assert ($next.InitialTotal -eq 4 -and $continued.ExcludedIssues.Count -eq 2 -and $continued.AvailableIssues.Count -eq 2 -and (Read-Result $next).AnalyzedIssues.Count -eq 2) 'Continue preserva B0 e exclui examinadas recebidas da nova fatia.'
Assert (Test-Path -LiteralPath $continued.PrioritizationIndexPath) 'Continuacao atualiza indice global derivado.'

# Repor a ficha local com candidata examinada nao perde a cobertura existente.
$r=New-PriorityReception -Internal
$local=New-HarnessPrioritizationContext $r.Target.Context -Percentage 50 -Category mandatory -Scope p
$null=Complete-Slice $r.Target $local
$localData=Read-Prepared $local
$firstFicha=@($localData.FichaPaths|Where-Object Id -CEQ $r.Result.AnalyzedIssues[0].Id)[0].Path
Move-Item -LiteralPath $firstFicha -Destination (Join-Path $r.Target.Root 'ficha-local-ausente.md')
$review=Start-HarnessReconciliationReview $r.Master $r.Origin
$accepted=Complete-HarnessReconciliation $r.Master -Conclusion 'Reposicao conferida da ficha local examinada.' -Resolutions $r.Decisions
Assert ($accepted.State -ceq 'CONCLUIDA' -and [IO.File]::ReadAllText($firstFicha).Contains('Analise humana recebida do projeto a.')) 'Ficha candidata deve poder repor a local ausente preservando examinadas.'
Assert ((Read-Result $local).AnalyzedIssues.Count -eq 2) 'Reposicao de ficha conserva a cobertura local anterior.'

# Um par incompleto ou com decisoes diferentes nao publica nem retira recebido/.
$r=New-PriorityReception -Internal
$outside=Join-Path $r.Target.Root 'ranking-fora.md'
Move-Item -LiteralPath (Join-Path $r.Origin $r.RankingRelative) -Destination $outside
$null=$r.Decisions.Remove($r.RankingRelative)
$review=Start-HarnessReconciliationReview $r.Master $r.Origin
Reject-PriorityReception $r { Complete-HarnessReconciliation $r.Master -Conclusion 'Par incompleto' -Resolutions $r.Decisions } 'par|ranking|contexto|priorizacao' 'Contexto sem ranking correspondente deve ser recusado.'
Move-Item -LiteralPath $outside -Destination (Join-Path $r.Origin $r.RankingRelative)
$r.Decisions[$r.RankingRelative]='LOCAL'
$review=Start-HarnessReconciliationReview $r.Master $r.Origin -Restart
Reject-PriorityReception $r { Complete-HarnessReconciliation $r.Master -Conclusion 'Decisoes diferentes' -Resolutions $r.Decisions } 'par|mesma|decis|ranking|contexto' 'Contexto RECEBIDO com ranking LOCAL deve ser recusado.'

# A adocao nunca apaga exames locais; a mesclagem respeita a quota fixa.
$r=New-PriorityReception -Internal
$local=New-HarnessPrioritizationContext $r.Target.Context -Percentage 50 -Category mandatory -Scope p
$null=Complete-Slice $r.Target $local
$receivedContextPath=Join-Path $r.Origin $r.ContextRelative
$receivedContext=[IO.File]::ReadAllText($receivedContextPath)
$changedBaseline=ConvertFrom-Json $receivedContext
$changedBaseline.BaselineIssues=@($changedBaseline.BaselineIssues|Select-Object -First 3)
$changedBaseline.AvailableIssues=@($changedBaseline.AvailableIssues|Select-Object -First 3)
$changedBaseline.InitialTotal=3
Write-ReceptionFile $receivedContextPath ($changedBaseline|ConvertTo-Json -Depth 20)
$review=Start-HarnessReconciliationReview $r.Master $r.Origin
Reject-PriorityReception $r { Complete-HarnessReconciliation $r.Master -Conclusion 'B0 recebida divergente' -Resolutions $r.Decisions } 'B0|base|denominador|cobertura' 'Recepcao nao pode substituir B0 local por outra base inicial.'
Write-ReceptionFile $receivedContextPath $receivedContext
$foreignResult=$r.Result|ConvertTo-Json -Depth 15|ConvertFrom-Json
$foreignResult.AnalyzedIssues=@(foreach ($issue in $r.Data.AvailableIssues|Select-Object -Last 2) { [pscustomobject]@{Project=$issue.Project;Id=$issue.Id;Position=$null;Reason='Outro exame recebido'} })
foreach ($issue in $foreignResult.AnalyzedIssues) {
    Write-Ficha $r.Source $r.Data $issue
    $ficha=@($r.Data.FichaPaths|Where-Object Id -CEQ $issue.Id)[0].Path
    $relative=$ficha.Substring($r.Source.Projects[0].Folder.Length+1).Replace('\','/')
    Write-ReceptionFile (Join-Path $r.Origin $relative) ([IO.File]::ReadAllText($ficha))
    $r.Decisions[$relative]='RECEBIDO'
}
$rankingPath=Join-Path $r.Origin $r.RankingRelative
Write-ReceptionFile $rankingPath (Set-ProjectManagedBlock ([IO.File]::ReadAllText($rankingPath)) 'priorizacao:resultado' ($foreignResult|ConvertTo-Json -Depth 15))
$review=Start-HarnessReconciliationReview $r.Master $r.Origin -Restart
Reject-PriorityReception $r { Complete-HarnessReconciliation $r.Master -Conclusion 'Nao perder exames locais' -Resolutions $r.Decisions } 'examin|perd|cobertura|local' 'Resultado recebido nao pode perder examinadas locais.'
$union=$r.Result|ConvertTo-Json -Depth 15|ConvertFrom-Json; $union.AnalyzedIssues+=@($foreignResult.AnalyzedIssues)
Write-ReceptionFile (Join-Path $review.ProposalPath $r.ContextRelative) ([IO.File]::ReadAllText((Join-Path $r.Origin $r.ContextRelative)))
Write-ReceptionFile (Join-Path $review.ProposalPath $r.RankingRelative) (Set-ProjectManagedBlock ([IO.File]::ReadAllText($rankingPath)) 'priorizacao:resultado' ($union|ConvertTo-Json -Depth 15))
$r.Decisions[$r.ContextRelative]='MESCLADO'; $r.Decisions[$r.RankingRelative]='MESCLADO'
Reject-PriorityReception $r { Complete-HarnessReconciliation $r.Master -Conclusion 'Uniao acima da quota' -Resolutions $r.Decisions } 'quota|fatia|COMPLETED|cobertura' 'Uniao de examinadas nao pode ultrapassar a quota sem novo preparo.'

# Mestre multiprojeto depende de ficha e anexos do parceiro ja adotados.
$r=New-PriorityReception -Multi -Internal
$review=Start-HarnessReconciliationReview $r.Master $r.Origin
Reject-PriorityReception $r { Complete-HarnessReconciliation $r.Master -Conclusion 'Parceiro nao adotado' -Resolutions $r.Decisions } 'ficha|parceiro|participante' 'Ficha do parceiro ausente impede publicar cobertura do mestre.'
Adopt-ReceptionPeer $r
$peer=$r.Target.Projects[1]; $peerAnnex=Join-Path $peer.EvidencePath 'recebida-b.md'; $annexOutside=Join-Path $r.Target.Root 'anexo-parceiro-fora.md'
$rankingPath=Join-Path $r.Origin $r.RankingRelative
$originalRanking=[IO.File]::ReadAllText($rankingPath)
Write-ReceptionFile (Join-Path $peer.Source 'notas.md') '# Notas do parceiro: [Anexo examinado](<ausente.bin>)'
$foreignNotes=Join-Path $r.Source.Projects[1].Source 'notas.md'
Write-ReceptionFile $rankingPath ($originalRanking+"`n[Notas examinadas do parceiro](<"+$foreignNotes+">)")
$review=Start-HarnessReconciliationReview $r.Master $r.Origin -Restart
Reject-PriorityReception $r { Complete-HarnessReconciliation $r.Master -Conclusion 'Anexo transitivo do Source parceiro ausente' -Resolutions $r.Decisions } 'ausente\.bin' 'Ranking deve percorrer notas no Source de B e recusar o anexo transitivo ausente.'
Write-ReceptionFile $rankingPath $originalRanking
Move-Item -LiteralPath $peerAnnex -Destination $annexOutside
$review=Start-HarnessReconciliationReview $r.Master $r.Origin -Restart
Reject-PriorityReception $r { Complete-HarnessReconciliation $r.Master -Conclusion 'Anexo parceiro ausente' -Resolutions $r.Decisions } 'anexo|evidencia|ausente|referencia' 'Anexo exclusivo ausente do parceiro impede atestar cobertura.'
Move-Item -LiteralPath $annexOutside -Destination $peerAnnex
$review=Start-HarnessReconciliationReview $r.Master $r.Origin -Restart
[IO.File]::AppendAllText($peerAnnex,"`nEdicao humana apos inicio da revisao.")
Reject-PriorityReception $r { Complete-HarnessReconciliation $r.Master -Conclusion 'Parceiro mudou durante revisao' -Resolutions $r.Decisions } 'mud|alter|parceiro|participante' 'Edicao de parceiro durante revisao impede conclusao.'
$independentPlan=Join-Path $peer.Folder 'atual/planejamento/independente/plan.md'
Write-ReceptionFile $independentPlan '# Plano de outra solicitacao, fora da cobertura recebida'
$review=Start-HarnessReconciliationReview $r.Master $r.Origin -Restart
Write-ReceptionFile (Join-Path $peer.Folder 'atual/priorizacao/optional/issues/ignorada/ficha.md') '# Ficha sem metadados, fora da categoria recebida'
[IO.File]::AppendAllText($independentPlan,"`nObservacao humana feita durante a revisao independente.")
$independentText=[IO.File]::ReadAllText($independentPlan)
$accepted=Complete-HarnessReconciliation $r.Master -Conclusion 'Parceiros e anexos novamente conferidos.' -Resolutions $r.Decisions
Assert ($accepted.State -ceq 'CONCLUIDA') 'Novo exame explicito permite adotar cobertura multiprojeto.'
Assert ([IO.File]::ReadAllText($independentPlan) -ceq $independentText) 'Plano independente e categoria alheia do parceiro nao bloqueiam nem sao alterados pela recepcao.'
Assert ($r.Result.AnalyzedIssues.Count -eq 2 -and $r.Result.AnalyzedIssues[0].Id -ceq $r.Result.AnalyzedIssues[1].Id) 'Fixture cobre a mesma ID em dois participantes distintos.'
foreach ($project in $r.Target.Projects) {
    $sourceProject=@($r.Source.Projects|Where-Object Name -CEQ $project.Name)[0]
    $entry=@($r.Data.FichaPaths|Where-Object { $_.Project -ceq $project.Name -and $_.Id -ceq $r.Result.AnalyzedIssues[0].Id })[0]
    $ficha=Join-Path $project.Folder $entry.Path.Substring($sourceProject.Folder.Length+1)
    Assert ([IO.File]::ReadAllText($ficha).Contains('Analise humana recebida do projeto '+$project.Name+'.')) 'Cada participante conserva a propria ficha para a mesma ID.'
}
Assert (-not (Test-Path -LiteralPath (Join-Path $peer.Folder $r.ContextRelative))) 'Somente o mestre ordinal publica contexto/ranking do escopo.'
Assert (-not (Test-Path -LiteralPath (Join-Path $r.Origin $r.ContextRelative))) 'Par recebido resolvido sai da area temporaria apos publicacao completa.'
'PASS: recepcao de priorizacao, continuidade, pares atomicos, preservacao local, quota e parceiros.'
