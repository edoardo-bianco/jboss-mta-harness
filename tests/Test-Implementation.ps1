#requires -Version 5.1
$ErrorActionPreference='Stop'; Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'PlanningCurrentFixture.ps1')
function Prepare-Fixture($Fixture) {
    foreach ($name in @('implementar-lote','revisar-resultado')) {
        Copy-Item -LiteralPath (Join-Path $root ('.github/prompts/'+$name+'.prompt.md')) -Destination (Join-Path $Fixture.Root '.github/prompts')
    }
    foreach ($project in $Fixture.Projects) {
        $null=New-HarnessCurrentPlanning $Fixture.Context -Target $project.Name
        Publish-HarnessProjectFiles $project @{'atual/planejamento/plano.md'="Lote ativo: LOCAL-1`nPROPOSTA - GO PENDENTE";'atual/planejamento/tarefas.md'='Lote ativo: LOCAL-1'}
    }
}
$f=New-PlanningFixture 1
Prepare-Fixture $f
$p=$f.Projects[0]
$before=Read-HarnessProjectFiles $p @('atual/planejamento/contexto.json','atual/planejamento/plano.md','atual/planejamento/tarefas.md','migracao.md')
$prepared=New-HarnessImplementationPrompt $f.Context
Assert ($prepared.PromptPath -eq (Join-Path $p.Folder 'atual/planejamento/implementar-lote.prompt.md')) 'Preparo deve usar destino fixo.'
foreach ($path in @($prepared.PromptPath,$prepared.ResultReviewPromptPath)) {
    $text=[IO.File]::ReadAllText($path)
    Assert ($text -notmatch 'PlanSnapshot|TodoSnapshot|ContractSnapshot|RequestId|RunId|ContextSha256|Previous|Consolidated') 'Prompt corrente exige historico retirado.'
    Assert ($text.Contains('GO') -and $text.Contains('conteudo') -and $text.Contains('NeedsReview')) 'Preparo deve exigir conferencia humana da autorizacao e conteudo.'
    Assert ($text.Contains('plano.md') -and $text.Contains('tarefas.md')) 'Prompt deve oferecer documentos legiveis.'
    [IO.File]::AppendAllText($path,"`nObservacao humana a preservar.")
}
$again=New-HarnessImplementationPrompt $f.Context
Assert ($again.Reused -and $again.PromptPath -eq $prepared.PromptPath) 'Repeticao deve preservar observacoes nos mesmos destinos.'
foreach ($path in @($again.PromptPath,$again.ResultReviewPromptPath)) { Assert ([IO.File]::ReadAllText($path).Contains('Observacao humana a preservar.')) 'Nota perdida.' }
foreach ($key in $before.Keys) { Assert ([IO.File]::ReadAllText((Join-Path $p.Folder $key)) -ceq $before[$key]) 'Preparo alterou proposta/decisao/contexto.' }
# MTA indisponivel e alteracao posterior do plano nao impedem preparar a leitura corrente.
$mta=(Read-Prepared $prepared).Mta.ReportPath
Move-Item -LiteralPath $mta -Destination ($mta+'.indisponivel')
[IO.File]::AppendAllText($p.PlanPath,"`nEscopo humano alterado; conferir novo alcance.")
$again=New-HarnessImplementationPrompt $f.Context
Assert ($again.PromptPath -eq $prepared.PromptPath -and $again.DocumentContents.Plan.Contains('Escopo humano alterado')) 'Deve ler plano atual sem depender de MTA ou copia anterior.'
$migration=[IO.File]::ReadAllText($p.MigrationPath).Replace('ANALISAR AGORA','ADIAR')
[IO.File]::WriteAllText($p.MigrationPath,$migration)
$again=New-HarnessImplementationPrompt $f.Context
Assert ($again.NeedsReview -and [IO.File]::ReadAllText($again.PromptPath).Contains('Escolhas do registro mudaram')) 'Mudanca de escolhas precisa explicitar revisao do GO.'
Move-Item -LiteralPath $p.TodoPath -Destination ($p.TodoPath+'.ausente')
$state=Get-PlanningFixtureState $f
Reject { New-HarnessImplementationPrompt $f.Context } 'Par incompleto nao pode preparar implementacao.'
Assert ((Get-PlanningFixtureState $f) -ceq $state) 'Falha alterou documentos.'
'PASS: preparo corrente, links, notas humanas, lacunas, escopo e ausencia de GO inferido.'

$f=New-PlanningFixture 1 @('a','b')
$cli=Install-PlanningCli $f
Prepare-Fixture $f
$state=Get-PlanningFixtureState $f
Reject { New-HarnessImplementationPrompt $f.Context } 'Multiplos projetos exigem escolha.'
Assert ((Get-PlanningFixtureState $f) -ceq $state) 'Escolha ambigua alterou arquivos.'
$entry=Join-Path $cli.Scripts 'preparar-implementacao.ps1'
$output='2' | & powershell.exe -NoProfile -File $entry -ConfigPath $cli.Config -WorkspacePath $cli.Workspace -Target b -NoOpen 2>&1 | Out-String
Assert ($LASTEXITCODE -eq 0) ('CLI corrente falhou: '+$output)
Assert ($output.Contains('Fonte da aplicacao: '+$f.Projects[1].Source) -and -not $output.Contains('Fonte da aplicacao: '+$f.Projects[0].Source)) 'Menu Git deve operar somente no projeto escolhido.'
Assert (Test-Path -LiteralPath (Join-Path $f.Projects[1].Folder 'atual/planejamento/implementar-lote.prompt.md')) 'CLI nao publicou prompt corrente.'
$output='' | & powershell.exe -NoProfile -File $entry -ConfigPath $cli.Config -WorkspacePath $cli.Workspace -Target b -NoOpen 2>&1 | Out-String
Assert ($LASTEXITCODE -eq 1 -and $output.Contains('Escolha de branch cancelada')) 'Enter nao autoriza operacao Git.'
'PASS: CLI por projeto, escolha multiprojeto explicita e cancelamento Git.'
