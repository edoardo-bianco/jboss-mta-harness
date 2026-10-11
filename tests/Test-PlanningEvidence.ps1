#requires -Version 5.1
$ErrorActionPreference='Stop'; Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'PlanningCurrentFixture.ps1')
$f=New-PlanningFixture 1
$project=$f.Projects[0]
$evidence=Join-Path $project.EvidencePath 'LEIA-ME.md'
$attachment=Join-Path $project.EvidencePath 'anexo 50% cafe (1).txt'
[IO.File]::WriteAllText($attachment,'Observacao original')
$link=Get-HarnessSourceLink $evidence $attachment 'Falha local'
[IO.File]::WriteAllText($evidence,"# Evidencias`n$link`n[Ausente](<ausente.txt>)`n[Referencia](<https://example.invalid/explicacao>)")
$p=New-HarnessCurrentPlanning $f.Context
$data=Read-Prepared $p
Assert (@($data.EvidenceInputs | Where-Object { $_.Path -eq $attachment -and $_.Status -eq 'DISPONIVEL' }).Count -eq 1) 'Referencia com espaco e percentual deve apontar ao arquivo original.'
Assert (@($data.EvidenceInputs | Where-Object Status -eq 'AUSENTE').Count -eq 1 -and $p.Diagnostics.Count -gt 0) 'Anexo ausente deve ficar explicito.'
Assert (@($data.EvidenceInputs | Where-Object Status -eq 'REFERENCIA EXTERNA').Count -eq 1) 'Link externo nao deve exigir download.'
Reject { Assert-HarnessPlanningEvidence $data $f.Root } 'Validador deve relatar ausencia de anexo.'
[IO.File]::WriteAllText((Join-Path $project.EvidencePath 'ausente.txt'),'Complemento')
$p=New-HarnessCurrentPlanning $f.Context
$data=Read-Prepared $p
Assert ($p.NeedsReview) 'Mudanca na disponibilidade de evidencia exige revisar proposta.'
Assert-HarnessPlanningEvidence $data $f.Root
[IO.File]::WriteAllText($p.PlanPath,'PLANO HUMANO / GO existente sujeito a revisao')
[IO.File]::WriteAllText($p.TodoPath,'TAREFAS HUMANAS')
$switched=New-HarnessCurrentPlanning $f.Context -PlanningBasis EVIDENCIAS
Assert ($switched.NeedsReview -and $null -eq (Read-Prepared $switched).Mta) 'Troca explicita de base deve sinalizar revisao sem guardar MTA.'
Assert ([IO.File]::ReadAllText($p.PlanPath).Contains('PLANO HUMANO')) 'Troca de base perdeu texto humano.'
[IO.File]::WriteAllText($attachment,'Evidencia atualizada no mesmo caminho')
$again=New-HarnessCurrentPlanning $f.Context
Assert ($again.ContextPath -eq $p.ContextPath -and [IO.File]::ReadAllText($p.PlanPath).Contains('mesmo caminho nao comprova conteudo inalterado')) 'Conteudo mutavel exige releitura, sem sucessor ou equivalencia implicita.'
$data=Read-Prepared $again
$data.PlanPath=Join-Path $project.Folder 'fora.md'
Write-HarnessJson $p.ContextPath $data
$before=[IO.File]::ReadAllText($p.ContextPath)
Reject { New-HarnessCurrentPlanning $f.Context } 'Contexto de destino divergente deve ser recusado.'
Assert ([IO.File]::ReadAllText($p.ContextPath) -ceq $before) 'Recusa alterou contexto.'
$multi=New-PlanningFixture 1 @('a','b')
Reject { New-HarnessCurrentPlanning $multi.Context } 'Escopo multiprojeto ambiguo exige escolha.'
foreach ($prj in $multi.Projects) { Assert (-not (Test-Path -LiteralPath $prj.ContextPath)) 'Ambiguidade produziu contexto.' }
$multi.Context.Projects[1].path=Join-Path $multi.Root 'indisponivel'
$selected=New-HarnessCurrentPlanning $multi.Context -Target 'a'
Assert ($selected.Project -ceq 'a') 'Projeto explicitamente escolhido nao depende de POM alheio indisponivel.'
Assert ((New-HarnessCurrentPlanning $multi.Context -ContextPath $selected.ContextPath).Project -ceq 'a') 'Retomada por contexto deve isolar POM alheio.'
Assert ((New-HarnessCurrentPlanning $multi.Context -MigrationPath $selected.MigrationPath).Project -ceq 'a') 'Retomada por registro deve isolar POM alheio.'
$explicit=Join-Path $multi.Root 'indice-escolhido-indisponivel.md'
$selected=New-HarnessCurrentPlanning $multi.Context -Target a -EvidenceIndexPath $explicit
Assert ((Read-Prepared $selected).EvidenceIndexPath -eq $explicit) 'Ausencia deve preservar o caminho explicitamente escolhido.'
[IO.File]::WriteAllText((Join-Path $multi.Projects[0].EvidencePath 'LEIA-ME.md'),'Outro indice, nao escolhido')
$selected=New-HarnessCurrentPlanning $multi.Context -Target a
Assert ((Read-Prepared $selected).EvidenceIndexPath -eq $explicit -and $selected.Diagnostics.Count -gt 0) 'Retomada nao pode adotar indice padrao nem apagar lacuna.'
$scoped=New-PlanningFixture 2
$prj=$scoped.Projects[0]
$register=[IO.File]::ReadAllText($prj.MigrationPath)
[IO.File]::WriteAllText($prj.MigrationPath,$register.Replace('| java::mandatory-2 | Problema 2 | mandatory | 1 | PRESENTE | ANALISAR AGORA |','| java::mandatory-2 | Problema 2 | mandatory | 1 | PRESENTE | ADIAR |'))
$index=Join-Path $prj.EvidencePath 'LEIA-ME.md'
$table="| Issue | Arquivo | Relacao |`n| --- | --- | --- |`n| java::mandatory-1 | [Anexo](<observacao.md>) | Erro selecionado |`n| java::mandatory-2 | [Ausente](<outra.txt>) | Fora do lote |"
[IO.File]::WriteAllText($index,$table)
$prepared=New-HarnessCurrentPlanning $scoped.Context
$inputs=(Read-Prepared $prepared).EvidenceInputs
Assert ($inputs.Count -eq 2 -and $inputs[1].Relation -eq 'java::mandatory-1: Erro selecionado') 'Evidencias devem preservar relacao e filtrar issues fora do lote.'
Assert-HarnessPlanningEvidence (Read-Prepared $prepared) $scoped.Root
[IO.File]::WriteAllText($index,($table+"`n| java::mandatory-2 | [Outro](<tambem-ausente.txt>) | Outra issue |"))
Assert (-not (New-HarnessCurrentPlanning $scoped.Context).NeedsReview) 'Evidencia de outra issue nao muda escopo nem entradas do lote.'
'PASS: evidencias diretas, lacunas, troca de base, destinos, escopo e isolamento.'
