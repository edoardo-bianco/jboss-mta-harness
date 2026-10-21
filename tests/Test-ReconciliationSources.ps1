#requires -Version 5.1
$ErrorActionPreference='Stop'; Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'PlanningCurrentFixture.ps1')
$f=New-PlanningFixture 1
$p=$f.Projects[0]
$diagnostics=@('atual/operacao.json','atual/diagnosticos/sonar-decisao.json')+
    @('resultado.json','quality-gate.json','measures.json','issues.json','criteria.json','RESUMO.md' | ForEach-Object {'atual/diagnosticos/sonar/'+$_})
$writes=@{}
foreach ($relative in $diagnostics) { $writes[$relative]='Diagnostico sintetico inicial' }
Publish-HarnessProjectFiles $p $writes
$prepared=New-HarnessReconciliationContext $f.Context
$data=Read-Prepared $prepared
foreach ($relative in $diagnostics) {
    $path=Join-Path $p.Folder $relative
    Assert ($data.CurrentFiles -contains $path) ('Diagnostico deve estar no contexto: '+$relative)
    $review=Start-HarnessReconciliationReview $p -Restart
    [IO.File]::AppendAllText($path,' alterado durante a revisao')
    $before=Get-PlanningFixtureState $f
    Reject { Complete-HarnessReconciliation $p -Conclusion 'Diagnostico alterado exige nova conferencia.' } ('Proteger concorrencia de '+$relative)
    Assert ((Get-PlanningFixtureState $f) -ceq $before) 'Recusa deve preservar todo o trabalho.'
}
'PASS: diagnosticos completos e operacao corrente acessiveis e protegidos durante reconciliacao.'

$f=New-PlanningFixture 1
$p=$f.Projects[0]
$prior=New-HarnessPrioritizationContext $f.Context -Percentage 100 -Category mandatory
$null=Complete-Slice $f $prior
[IO.File]::WriteAllText((Join-Path $p.EvidencePath 'LEIA-ME.md'),'[Observacao](<observacao.md>)')
$prepared=New-HarnessCurrentPlanning $f.Context -PlanningBasis EVIDENCIAS
Publish-HarnessProjectFiles $p @{'atual/planejamento/plano.md'='Plano humano';'atual/planejamento/tarefas.md'='Tarefas humanas'}
$prepared=New-HarnessCurrentPlanning $f.Context
$before=[IO.File]::ReadAllText($p.PlanPath)
$links=@([regex]::Matches($before,'\]\(<([^>]+)>\)') | ForEach-Object {$_.Groups[1].Value})
$review=Start-HarnessReconciliationReview $p -PlanningBasis EVIDENCIAS
$done=Complete-HarnessReconciliation $p -Conclusion 'Evidencias e referencias conferidas no Source local.'
$after=[IO.File]::ReadAllText($p.PlanPath)
foreach ($link in $links) { Assert ($after.Contains($link)) ('Reconciliacao deve preservar fonte navegavel: '+$link) }
Assert ($after.Contains('Ficha: java::mandatory-1') -and $after.Contains('observacao.md')) 'Ficha e anexo devem permanecer acessiveis no plano.'
'PASS: reconciliacao preserva navegacao de ficha, anexo e documentos correntes.'

$f=New-PlanningFixture 1
$p=$f.Projects[0]
$prepared=New-HarnessCurrentPlanning $f.Context
Publish-HarnessProjectFiles $p @{'atual/planejamento/plano.md'='Plano humano';'atual/planejamento/tarefas.md'='Tarefas humanas'}
$historical='Nota humana: '+(Get-HarnessSourceLink $p.IndexPath (Read-Prepared $prepared).Mta.ReportPath 'MTA anterior')
[IO.File]::AppendAllText($p.IndexPath,([Environment]::NewLine+$historical))
Set-FixtureMta $p 1 @('mandatory') novo
$report=Join-Path $f.Root 'mta-a/novo/index.html'
[IO.File]::SetLastWriteTimeUtc($report,[DateTime]::UtcNow.AddMinutes(1))
Assert ((Get-HarnessReconciliationComparison $p).Differences.Count -eq 0) 'Fixture deve mudar origem mantendo contagens e issues.'
$review=Start-HarnessReconciliationReview $p
$done=Complete-HarnessReconciliation $p -Conclusion 'Nova origem conferida; mesmos IDs nao comprovam equivalencia.'
$data=Read-Prepared $prepared
Assert ($done.NeedsReview -and $data.NeedsReview -and $data.Mta.ReportPath -eq $report) 'Mudanca de origem deve atualizar contexto e pedir revisao mesmo sem diferenca de contagem.'
Assert ([IO.File]::ReadAllText($p.PlanPath).Contains('novo/index.html')) 'Plano deve abrir o MTA corrente apos reconciliacao.'
$indexText=[IO.File]::ReadAllText($p.IndexPath)
foreach ($match in [regex]::Matches($indexText,'\[MTA atual\]\(<([^>]+)>\)')) { Assert ($match.Groups[1].Value.Contains('novo/index.html')) 'Indice tambem deve abrir a origem MTA corrente.' }
Assert ($indexText.Contains($historical)) 'Link historico humano deve permanecer intacto.'
'PASS: troca de MTA atualiza contexto e links sem inferir equivalencia pelos totais.'

$index=Join-Path $p.EvidencePath 'LEIA-ME.md'
[IO.File]::WriteAllText($index,'[Anexo a receber](<novo.md>)')
$prepared=New-HarnessCurrentPlanning $f.Context -EvidenceIndexPath $index
$data=Read-Prepared $prepared
Assert ($data.FichaPaths[0].Status -eq 'A ELABORAR' -and @($data.EvidenceInputs | Where-Object Status -eq 'AUSENTE').Count -eq 1) 'Fixture deve partir de ficha/anexo ausentes.'
$relative=$data.FichaPaths[0].Path.Substring($p.Folder.Length+1).Replace('\','/')
$identity=@{Project=$p.Name;Id='java::mandatory-1';Category='mandatory';LocalPaths=@();EvidencePaths=@('novo.md')} | ConvertTo-Json -Compress
$ficha="# Exame humano recebido`n<!-- ficha:identidade:inicio -->`n$identity`n<!-- ficha:identidade:fim -->"
Publish-HarnessProjectFiles $p @{('recebido/'+$relative)=$ficha;'recebido/evidencias/novo.md'='Evidencia recebida'}
$review=Start-HarnessReconciliationReview $p (Join-Path $p.Folder 'recebido')
$done=Complete-HarnessReconciliation $p -Conclusion 'Ficha e anexo recebidos conferidos; revisar proposta local.' -Resolutions @{$relative='RECEBIDO';'evidencias/novo.md'='RECEBIDO'}
$data=Read-Prepared $prepared
Assert ($data.FichaPaths[0].Status -eq 'DISPONIVEL' -and @($data.EvidenceInputs | Where-Object Status -eq 'AUSENTE').Count -eq 0) 'Contexto deve reconhecer ficha/anexo aceitos na mesma publicacao.'
$text=[IO.File]::ReadAllText($p.PlanPath)
Assert ($text.Contains('Ficha: java::mandatory-1') -and $text.Contains('novo.md') -and -not $text.Contains('Evidencia indisponivel:')) 'Plano deve oferecer links aos novos documentos aceitos.'
'PASS: ficha e anexo aceitos ficam navegaveis na mesma publicacao.'

$review=Start-HarnessReconciliationReview $p -PlanningBasis EVIDENCIAS
$null=Complete-HarnessReconciliation $p -Conclusion 'Conferencia somente das evidencias humanas.'
$review=Start-HarnessReconciliationReview $p -PlanningBasis MTA
$null=Complete-HarnessReconciliation $p -Conclusion 'Diagnostico MTA corrente conferido novamente.'
$text=[IO.File]::ReadAllText($p.IndexPath)
Assert (-not $text.Contains('MTA nao consultado nesta reconciliacao')) 'Trocar base e voltar ao MTA nao pode deixar aviso antigo no indice.'
Assert ($text.Contains((Get-HarnessSourceLink $p.IndexPath $report 'MTA atual')) -and $text.Contains($historical)) 'Retorno ao MTA deve manter link corrente e nota historica.'
'PASS: transicoes MTA/EVIDENCIAS/MTA mantem fontes atuais sem aviso obsoleto.'

# Orientacao gerada pode mudar de versao/maquina sem virar conflito humano.
$f=New-PlanningFixture 1
$p=$f.Projects[0]
$register=[IO.File]::ReadAllText($p.MigrationPath)
$received=Set-ProjectManagedBlock $register 'registro:orientacao' 'Orientacao de outra versao; links locais de outra maquina.'
Publish-HarnessProjectFiles $p @{'recebido/migracao.md'=$received}
$comparison=Get-HarnessReconciliationComparison $p (Join-Path $p.Folder 'recebido')
$document=@($comparison.Documents | Where-Object Path -EQ 'migracao.md')[0]
Assert ($document.Status -eq 'EQUIVALENTE') 'Legenda gerada nao altera equivalencia das decisoes humanas.'
Publish-HarnessProjectFiles $p @{'recebido/migracao.md'=($received+"`nNova decisao humana a conciliar.")}
$comparison=Get-HarnessReconciliationComparison $p (Join-Path $p.Folder 'recebido')
$document=@($comparison.Documents | Where-Object Path -EQ 'migracao.md')[0]
Assert ($document.Status -eq 'DIVERGENTE') 'Notas fora da orientacao continuam sendo contribuicao humana.'
'PASS: orientacao gerada difere sem conflito ficticio, preservando divergencia humana.'
