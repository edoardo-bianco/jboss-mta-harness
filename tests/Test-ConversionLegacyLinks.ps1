#requires -Version 5.1
$ErrorActionPreference='Stop'; Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'ConversionFixture.ps1')
Import-Module (Join-Path $root 'tools/transicao/ConversaoPrevia.psm1') -Force -DisableNameChecking
$f=New-ConversionFixture
$folder=Join-Path $f.Workspace '.harness/planning/apelido/issues/regra__123456789abc/p_123456789abc'
$plan=[ordered]@{Purpose='application-remediation';RequestId=('a'*32);LayoutVersion=2;IssueId='java::regra';SelectedIssues=@(@{Id='java::regra';Category='mandatory'});Source=$f.Source.Replace('\','/');ContextPath=(Join-Path $folder 'contexto-regra.json').Replace('\','/');PlanPath=(Join-Path $folder 'plan-regra.md').Replace('\','/');TodoPath=(Join-Path $folder 'todo-regra.md').Replace('\','/');MigrationPath=$f.Register.Replace('\','/')}
Write-ConversionFile $plan.ContextPath ($plan|ConvertTo-Json -Depth 12)
Write-ConversionFile $plan.PlanPath '# Plano'
Write-ConversionFile $plan.TodoPath '- [ ] Verificar'
$uri=New-Object Uri ([IO.Path]::GetFullPath($plan.PlanPath))
$relative=(New-Object Uri $f.Register).MakeRelativeUri($uri).ToString()
$text=[IO.File]::ReadAllText($f.Register).Replace('Conferir contrato',('[Plano](<'+$relative+'>)'))
Write-ConversionFile $f.Register $text
$before=Get-ConversionState $f
$preview=Get-ConversionPreview $f.Workspace $f.Pom
Assert ($preview.Planning.ContextPath -eq [IO.Path]::GetFullPath($plan.ContextPath)) 'Layout 2 com barras normais e link URL relativo deve selecionar plano.'
Assert ((Get-ConversionState $f) -ceq $before) 'Leitura de layout 2 nao deve escrever.'
# O plano historico fora da tabela nao substitui um vinculo atual quebrado.
$broken=$text.Replace($relative,'../../../planning/ausente/plan.md')+"`n[Historico](<"+$uri.AbsoluteUri+">)`n"
Write-ConversionFile $f.Register $broken
$preview=Get-ConversionPreview $f.Workspace $f.Pom
Assert ($null -eq $preview.Planning.ContextPath -and ($preview.Pending -join ' ') -match 'Vinculo.*nao resolvido') 'Link quebrado atual nao permite fallback historico.'
Write-ConversionFile $f.Register $text
$foreign=Join-Path $f.Workspace '.harness/planning/outro-projeto/plan.md'
Write-ConversionFile $foreign '# Outro projeto'
$plan.PlanPath=$foreign
Write-ConversionFile $plan.ContextPath ($plan|ConvertTo-Json -Depth 12)
$preview=Get-ConversionPreview $f.Workspace $f.Pom -Contexto $plan.ContextPath
Assert ($null -eq $preview.Planning.ContextPath -and @($preview.ProposedFiles|Where-Object Origin -EQ $foreign).Count -eq 0) 'Mesmo Source no recibo nao autoriza capturar documento de outra solicitacao.'
$plan.PlanPath=(Join-Path $folder 'plan-regra.md'); $plan.MigrationPath=(Join-Path $f.Workspace '.harness/projetos/outro/migracao.md')
Write-ConversionFile $plan.ContextPath ($plan|ConvertTo-Json -Depth 12)
$preview=Get-ConversionPreview $f.Workspace $f.Pom -Contexto $plan.ContextPath
Assert ($null -eq $preview.Planning.ContextPath -and ($preview.Pending -join ' ') -match 'MigrationPath divergente') 'Plano vinculado a outro registro deve ficar pendente.'
$plan.MigrationPath=$f.Register; $plan.IssueId='java::outra'
Write-ConversionFile $plan.ContextPath ($plan|ConvertTo-Json -Depth 12)
$preview=Get-ConversionPreview $f.Workspace $f.Pom -Contexto $plan.ContextPath
Assert ($null -eq $preview.Planning.ContextPath -and ($preview.Pending -join ' ') -match 'IssueId diverge') 'IssueId deve concordar com unica SelectedIssue.'
$plan.IssueId='java::regra'
Write-ConversionFile $plan.ContextPath ($plan|ConvertTo-Json -Depth 12)
$child=Add-ConversionPlan $f ('b'*32)
$child.SelectedIssues=@(@{Id='java::outra'}); $child.Previous=@{RequestId=$plan.RequestId;ContextPath=$plan.ContextPath}
$child|Add-Member -NotePropertyName LayoutVersion -NotePropertyValue 2
$child|Add-Member -NotePropertyName IssueId -NotePropertyValue 'java::outra'
Write-ConversionFile $child.ContextPath ($child|ConvertTo-Json -Depth 12)
$before=Get-ConversionState $f
$preview=Get-ConversionPreview $f.Workspace $f.Pom
Assert ($null -eq $preview.Planning.ContextPath -and ($preview.Pending -join ' ') -match 'Previous muda o escopo') 'Filho de outra issue nao pode virar ponta da primeira.'
Assert ((Get-ConversionState $f) -ceq $before) 'Conflitos nao alteram legado.'
# Recibos anteriores a SelectedIssues guardavam a escolha no snapshot do registro.
$f=New-ConversionFixture
$old=Add-ConversionPlan $f ('a'*32)
$old.PSObject.Properties.Remove('SelectedIssues')
$old|Add-Member -NotePropertyName MigrationSnapshot -NotePropertyValue ([IO.File]::ReadAllText($f.Register))
Write-ConversionFile $old.ContextPath ($old|ConvertTo-Json -Depth 12)
$new=Add-ConversionPlan $f ('b'*32) $old.RequestId
[IO.File]::AppendAllText($f.Register,("`n[Plano](<"+$old.PlanPath+">)`n"))
$preview=Get-ConversionPreview $f.Workspace $f.Pom
Assert ($preview.Planning.ContextPath -eq $new.ContextPath) 'MigrationSnapshot deve recuperar escolha dos recibos sem SelectedIssues.'
$old.MigrationSnapshot='Sem tabela de escolhas'
Write-ConversionFile $old.ContextPath ($old|ConvertTo-Json -Depth 12)
$preview=Get-ConversionPreview $f.Workspace $f.Pom
Assert ($null -eq $preview.Planning.ContextPath -and ($preview.Pending -join ' ') -match 'Escopo inconclusivo') 'Ausencia de prova do escopo nao equivale a mudanca comprovada.'
Write-Host 'PASS: layout legado 2, links relativos, barras, vinculo quebrado e pertencimento.'
