#requires -Version 5.1
$ErrorActionPreference='Stop'; Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'PlanningCurrentFixture.ps1')
$f=New-PlanningFixture 1
$p=$f.Projects[0]
$origin=Join-Path $f.Root 'colega'
$null=[IO.Directory]::CreateDirectory((Join-Path $origin 'atual/planejamento'))
[IO.File]::WriteAllText((Join-Path $origin 'projeto.json'),'{ "pom": "Z:/colega/pom.xml", "mta": { "diretorio": "Z:/mta" } }')
[IO.File]::WriteAllText((Join-Path $origin 'atual/planejamento/contexto.json'),(@{Purpose='current-planning';Project=$p.Name;Source='Z:/colega';Pom='Z:/colega/pom.xml'}|ConvertTo-Json))
$plan="Escopo humano\r\n\r\nGO relatado pelo colega."
$plan=$plan.Replace('\r',"`r").Replace('\n',"`n")
[IO.File]::WriteAllText((Join-Path $origin 'atual/planejamento/plano.md'),$plan)
Publish-HarnessProjectFiles $p @{'atual/planejamento/plano.md'=$plan.Replace("`r`n","`n")}
$comparison=Get-HarnessReconciliationComparison $p $origin
Assert (@($comparison.Documents | Where-Object { $_.Path -eq 'atual/planejamento/plano.md' -and $_.Status -eq 'EQUIVALENTE' }).Count -eq 1) 'LF/CRLF nao devem transformar mesmo escopo em conflito.'
$config=[IO.File]::ReadAllText($p.ConfigPath)
$review=Start-HarnessReconciliationReview $p $origin
$done=Complete-HarnessReconciliation $p -Conclusion 'Conferido conteudo equivalente no Source local, sem transferir aceite.'
Assert ([IO.File]::ReadAllText($p.ConfigPath) -ceq $config -and (Test-Path -LiteralPath (Join-Path $origin 'projeto.json'))) 'Configuracao local e pasta externa devem permanecer.'
Assert ([IO.File]::ReadAllText($p.PlanPath).Contains('POM local')) 'Referencias gerenciadas devem usar fonte local.'
# Material de outro projeto exige associacao correta, nunca por recencia.
[IO.File]::WriteAllText((Join-Path $origin 'atual/planejamento/contexto.json'),'{"Purpose":"current-planning","Project":"outro"}')
Reject { Get-HarnessReconciliationComparison $p $origin } 'Nao aceitar contexto de outro projeto.'
# Markdown anexado e evidencia: comparacao deve preservar todos os bytes.
$received=Join-Path $p.Folder 'recebido'
$old="Evidencia`n<!-- fontes:inicio -->origem antiga<!-- fontes:fim -->"
$new="Evidencia`n<!-- fontes:inicio -->origem nova<!-- fontes:fim -->"
Publish-HarnessProjectFiles $p @{'evidencias/anexo.md'=$old;'recebido/evidencias/anexo.md'=$new;'recebido/evidencias/pendente.txt'='Examinar depois';'recebido/arquivo-desconhecido.txt'='Preservar'}
$comparison=Get-HarnessReconciliationComparison $p $received
Assert (@($comparison.Documents | Where-Object { $_.Path -eq 'evidencias/anexo.md' -and $_.Status -eq 'DIVERGENTE' }).Count -eq 1) 'Bloco dentro de anexo faz parte da evidencia e nao pode ser ignorado.'
$review=Start-HarnessReconciliationReview $p $received
$done=Complete-HarnessReconciliation $p -Conclusion 'Anexo examinado; outro material permanece pendente.' -Resolutions @{'evidencias/anexo.md'='RECEBIDO'}
Assert ([IO.File]::ReadAllText((Join-Path $p.EvidencePath 'anexo.md')) -ceq $new -and -not (Test-Path -LiteralPath (Join-Path $received 'evidencias/anexo.md'))) 'Adocao deve publicar bytes do anexo antes de retirar recebido.'
Assert ($done.State -eq 'PENDENTE' -and (Test-Path -LiteralPath (Join-Path $received 'evidencias/pendente.txt')) -and (Test-Path -LiteralPath (Join-Path $received 'arquivo-desconhecido.txt'))) 'Material pendente/nao examinado deve permanecer.'
# Registro divergente exige proposta mesclada, preservando IDs/observacoes locais.
$incoming=[IO.File]::ReadAllText($p.MigrationPath).Replace('ANALISAR AGORA','ADIAR')
Publish-HarnessProjectFiles $p @{'recebido/migracao.md'=$incoming}
$review=Start-HarnessReconciliationReview $p $received
Reject { Complete-HarnessReconciliation $p -Conclusion 'Rejeitar substituicao cega' -Resolutions @{'migracao.md'='RECEBIDO'} } 'Registro exige mesclagem explicita.'
$merged=$incoming+"`nNota humana mesclada."
[IO.File]::WriteAllText((Join-Path $review.ProposalPath 'migracao.md'),$merged)
$done=Complete-HarnessReconciliation $p -Conclusion 'Decisao humana explicita de adiar, mantendo observacao e IDs.' -Resolutions @{'migracao.md'='MESCLADO'}
Assert ([IO.File]::ReadAllText($p.MigrationPath).Contains('Nota humana mesclada.') -and [IO.File]::ReadAllText($p.MigrationPath).Contains('| ADIAR |')) 'Mesclagem deve preservar decisao examinada.'
# Copia direta para projeto ainda sem trabalho: configuracao ja reassociada localmente.
$peer=New-PlanningFixture 1
$peerPlan=New-HarnessCurrentPlanning $peer.Context
$peerReconciliation=New-HarnessReconciliationContext $peer.Context
Publish-HarnessProjectFiles $peer.Projects[0] @{'atual/planejamento/plano.md'='Plano do colega. GO concedido na origem.';'atual/planejamento/tarefas.md'='[x] Concluido pelo colega'}
$local=New-PlanningFixture 1
$lp=$local.Projects[0]
$files=(Get-HarnessReconciliationComparison $peer.Projects[0]).Local
$copy=@{}
foreach ($key in $files.Keys) { if ($key -ne 'projeto.json' -and $null -ne $files[$key]) { $copy[$key]=$files[$key] } }
Publish-HarnessProjectFiles $lp $copy
$prepared=New-HarnessReconciliationContext $local.Context -ReceivedPath $peer.Projects[0].Folder
Assert ((Read-Prepared $prepared).Relocated) 'Contexto de reconciliacao copiado deve ser realinhado ao POM local.'
$again=New-HarnessReconciliationContext $local.Context
Assert ((Read-Prepared $again).ReceivedPath -eq $peer.Projects[0].Folder) 'Retomada deve preservar origem ja reassociada nesta maquina, mesmo com GO pendente.'
$prepared=New-HarnessReconciliationContext $local.Context -LocalOnly
$review=Start-HarnessReconciliationReview $lp
[IO.File]::AppendAllText((Join-Path $lp.Folder 'atual/planejamento/planejar-lotes.prompt.md'),' Edicao humana posterior ao inicio.')
$before=Get-PlanningFixtureState $local
Reject { Complete-HarnessReconciliation $lp -Conclusion 'Nao sobrescrever prompt editado.' } 'Prompt derivado deve ter a mesma protecao de concorrencia.'
Assert ((Get-PlanningFixtureState $local) -ceq $before) 'Conflito no prompt deve preservar todos os arquivos.'
$review=Start-HarnessReconciliationReview $lp -Restart
$done=Complete-HarnessReconciliation $lp -Conclusion 'Copia direta conferida; GO da origem exige revisao local.'
$context=Get-Content -LiteralPath $lp.ContextPath -Raw | ConvertFrom-Json
Assert ($context.ContextPath -eq $lp.ContextPath -and $context.Source -eq $lp.Source -and $context.Pom -eq $lp.Pom -and $context.NeedsReview -and $done.NeedsReview) 'Todos os destinos derivados devem ser locais com revisao do GO.'
Assert ([IO.File]::ReadAllText($lp.PlanPath).Contains('Plano do colega.') -and [IO.File]::ReadAllText($lp.PlanPath).Contains('REVISAO HUMANA DO GO NECESSARIA')) 'Texto copiado permanece, com aviso de revisao local.'
Assert ([IO.File]::ReadAllText($context.PromptPath).Contains($lp.ContextPath.Replace('\','\\'))) 'Prompt copiado deve apontar o contexto local.'
$continued=New-HarnessCurrentPlanning $local.Context
Assert ($continued.ContextPath -eq $lp.ContextPath -and $continued.NeedsReview) 'Planejar depois da copia deve retomar sem caminho estrangeiro nem GO automatico.'
'PASS: pasta recebida/externa/copia direta, contextos realinhados, GO local, anexos exatos e mesclagem por decisao.'

# Copia com base humana deve regenerar fontes do registro sem consultar MTA.
$peer=New-PlanningFixture 1
$pp=$peer.Projects[0]
Set-ManualPlanningChoice $pp
$null=New-HarnessCurrentPlanning $peer.Context
Publish-HarnessProjectFiles $pp @{'atual/planejamento/plano.md'='Plano por evidencias';'atual/planejamento/tarefas.md'='Roteiro manual'}
$local=New-PlanningFixture 1
$lp=$local.Projects[0]
$source=Join-Path $local.Root 'checkout-local-diferente'
$null=[IO.Directory]::CreateDirectory($source)
Copy-Item -LiteralPath $lp.Pom -Destination (Join-Path $source 'pom.xml')
Publish-HarnessProjectFiles $lp @{'projeto.json'=(@{pom=(Join-Path $source 'pom.xml')} | ConvertTo-Json)}
$lp=Get-HarnessProjectStorage $local.Root (Join-Path $source 'pom.xml')
$copy=@{}
$files=(Get-HarnessReconciliationComparison $pp -PlanningBasis EVIDENCIAS).Local
foreach ($key in $files.Keys) { if ($key -ne 'projeto.json' -and $null -ne $files[$key]) { $copy[$key]=$files[$key] } }
Publish-HarnessProjectFiles $lp $copy
$review=Start-HarnessReconciliationReview $lp -PlanningBasis EVIDENCIAS
$done=Complete-HarnessReconciliation $lp -Conclusion 'Copia por evidencias conferida no Source local.'
$text=[IO.File]::ReadAllText($lp.MigrationPath)
Assert ($text.Contains((Get-HarnessSourceLink $lp.MigrationPath $lp.Pom 'POM')) -and $text.Contains((Get-HarnessSourceLink $lp.MigrationPath $lp.Source 'Codigo local'))) 'Registro por evidencias deve apontar ao POM e Source locais depois da copia.'
'PASS: copia por EVIDENCIAS realinha fontes do registro sem MTA.'
