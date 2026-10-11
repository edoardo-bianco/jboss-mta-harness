#requires -Version 5.1
$ErrorActionPreference='Stop'; Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'PlanningCurrentFixture.ps1')
$f=New-PlanningFixture 2
$project=$f.Projects[0]
Publish-HarnessProjectFiles $project @{'atual/planejamento/plano.md'='Plano local';'atual/planejamento/tarefas.md'='Tarefas locais'}
$origin=Join-Path $f.Root 'colega'
$null=[IO.Directory]::CreateDirectory((Join-Path $origin 'atual/planejamento'))
[IO.File]::WriteAllText((Join-Path $origin 'atual/planejamento/plano.md'),'Plano local')
[IO.File]::WriteAllText((Join-Path $origin 'atual/planejamento/tarefas.md'),'Outro escopo')
[IO.File]::WriteAllText((Join-Path $origin 'projeto.json'),'{"pom":"Z:/maquina-colega/pom.xml","mta":{"diretorio":"Z:/mta"}}')
$before=Get-PlanningFixtureState $f
$comparison=Get-HarnessReconciliationComparison $project $origin
Assert ($comparison.Documents.Count -eq 3) 'Reconhecer documentos funcionais e configuracao apenas como referencia.'
Assert (@($comparison.Documents | Where-Object Status -EQ 'EQUIVALENTE').Count -eq 1) 'Conteudo igual nao exige duplicacao.'
Assert (@($comparison.Documents | Where-Object Status -EQ 'DIVERGENTE').Count -eq 1) 'Divergencia nao pode ser escolhida por data.'
Assert ((Get-PlanningFixtureState $f) -ceq $before) 'Comparacao deve ser somente leitura.'
$review=Start-HarnessReconciliationReview $project $origin
Assert ($review.Reused -eq $false -and (Test-Path -LiteralPath (Join-Path $review.Folder 'base.clixml'))) 'Revisao deve proteger base apenas na area transitoria.'
Assert ((Start-HarnessReconciliationReview $project $origin).Reused) 'Revisao pendente retoma sem apagar proposta.'
Assert (-not (Test-Path -LiteralPath (Join-Path $project.ReconciledPath 'resultado.md'))) 'Preparo nao conclui reconciliacao.'
$module=Get-Module HarnessPlanning
& $module { param($p,$o) $base=Import-Clixml (Join-Path (Get-ReconciliationReviewFolder $p) 'base.clixml'); Assert-ReconciliationReviewUnchanged $base (Get-HarnessReconciliationComparison $p $o) } $project $origin
[IO.File]::AppendAllText($project.PlanPath,' edicao humana')
Reject { & $module { param($p,$o) $base=Import-Clixml (Join-Path (Get-ReconciliationReviewFolder $p) 'base.clixml'); Assert-ReconciliationReviewUnchanged $base (Get-HarnessReconciliationComparison $p $o) } $project $origin } 'Edicao concorrente deve impedir conclusao.'
'PASS: comparacao corrente, equivalencia, divergencia, revisao transitoria e conflito de edicao.'
Reject { Complete-HarnessReconciliation $project -Conclusion 'Ainda nao conferir nova edicao' } 'Conclusao deve rejeitar edicao externa desde inicio da revisao.'
$review=Start-HarnessReconciliationReview $project $origin -Restart
$localPlan=[IO.File]::ReadAllText($project.PlanPath)
$config=[IO.File]::ReadAllText($project.ConfigPath)
$partial=Complete-HarnessReconciliation $project -Conclusion 'Conferidos os documentos; divergencias de escopo aguardam escolha humana.'
Assert ($partial.State -eq 'PENDENTE' -and [IO.File]::ReadAllText($project.PlanPath).Contains($localPlan)) 'Conflito deve preservar trabalho local e ficar pendente.'
Assert (Test-Path -LiteralPath (Join-Path $origin 'atual/planejamento/tarefas.md')) 'Origem externa deve permanecer.'
Assert (-not (Test-Path -LiteralPath $review.Folder)) 'Revisao terminada nao deixa copia persistente da base.'
$review=Start-HarnessReconciliationReview $project $origin
$resolved=Complete-HarnessReconciliation $project -Conclusion 'Humano escolheu conservar plano local e incorporar o roteiro recebido; GO sera revisto no Source local.' -Resolutions @{'atual/planejamento/plano.md'='LOCAL';'atual/planejamento/tarefas.md'='RECEBIDO';'projeto.json'='DESCARTAR'}
Assert ($resolved.State -eq 'CONCLUIDA' -and $resolved.NeedsReview) 'Resolucao explicita deve concluir comparacao e exigir revisao de autorizacao.'
Assert ([IO.File]::ReadAllText($project.TodoPath).Contains('Outro escopo') -and [IO.File]::ReadAllText($project.TodoPath).Contains('REVISAO HUMANA DO GO NECESSARIA')) 'Conteudo recebido nao transfere GO.'
Assert ([IO.File]::ReadAllText($project.ConfigPath) -ceq $config) 'Configuracao da outra maquina nao substitui associacoes locais.'
Assert (Test-Path -LiteralPath (Join-Path $origin 'projeto.json')) 'DESCARTAR nunca apaga arquivo externo.'
$review=Start-HarnessReconciliationReview $project $origin
$same=Complete-HarnessReconciliation $project -Conclusion 'Mesmas fontes conferidas, plano local mantido.' -Resolutions @{'atual/planejamento/plano.md'='LOCAL';'atual/planejamento/tarefas.md'='LOCAL'}
Assert (-not $same.NeedsReview) 'Mesmo material nao duplica ou renova aviso sem mudanca funcional.'
Assert (@(Get-ChildItem -LiteralPath $project.ReconciledPath -File).Count -eq 1) 'Somente a ultima conclusao deve permanecer.'
# Material interno: anexo binario e ficha sao publicados junto da retirada da origem.
$internal=Join-Path $project.Folder 'recebido'
$id='java::mandatory-1'; $relative='atual/priorizacao/mandatory/issues/java%3A%3Amandatory-1/ficha.md'
$identity=@{Project=$project.Name;Id=$id;Category='mandatory';LocalPaths=@('src/Exemplo.java');EvidencePaths=@('recebido.bin')}|ConvertTo-Json -Compress
$ficha="# Ficha recebida`n`nTexto humano preservado.`n<!-- ficha:identidade:inicio -->`n$identity`n<!-- ficha:identidade:fim -->"
Publish-HarnessProjectFiles $project @{('recebido/'+$relative)=$ficha;'recebido/evidencias/recebido.bin'=[byte[]]@(0,128,255)}
$review=Start-HarnessReconciliationReview $project $internal
$result=Complete-HarnessReconciliation $project -Conclusion 'Ficha e anexo conferidos no codigo local; nenhuma execucao autorizada.' -Resolutions @{$relative='RECEBIDO';'evidencias/recebido.bin'='RECEBIDO'}
Assert (-not (Test-Path -LiteralPath (Join-Path $internal $relative)) -and -not (Test-Path -LiteralPath (Join-Path $internal 'evidencias/recebido.bin'))) 'Somente recebidos resolvidos devem sair da area temporaria.'
Assert ([Convert]::ToBase64String([IO.File]::ReadAllBytes((Join-Path $project.EvidencePath 'recebido.bin'))) -ceq 'AID/') 'Bytes do anexo devem permanecer no destino oficial.'
$text=[IO.File]::ReadAllText((Join-Path $project.Folder $relative))
Assert ($text.Contains('Texto humano preservado') -and $text.Contains('[recebido.bin]') -and -not $text.Contains('Indisponivel: recebido.bin')) 'Ficha deve ligar ao anexo publicado junto, preservando texto.'
'PASS: conflitos, equivalencia repetida, GO local, associacoes, ultima base e consumo protegido de recebido.'
