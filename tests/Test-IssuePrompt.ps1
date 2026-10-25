#requires -Version 5.1
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'PlanningCurrentFixture.ps1')
$fixture=New-PlanningFixture 2 @('a','b')
$cli=Install-PlanningCli $fixture
$template=Join-Path $root '.github/prompts/criar-revisar-issue.prompt.md'
if (Test-Path -LiteralPath $template) { Copy-Item -LiteralPath $template -Destination (Join-Path $fixture.Root '.github/prompts/criar-revisar-issue.prompt.md') }
$a=$fixture.Projects[0]; $b=$fixture.Projects[1]
$beforeA=[IO.File]::ReadAllText($a.MigrationPath)
$beforeB=[IO.File]::ReadAllText($b.MigrationPath)
$beforeSource=(Get-FileHash -LiteralPath $b.Pom).Hash
$relative='atual/planejamento/criar-revisar-issue.prompt.md'
$path=Join-Path $b.Folder $relative
$result=Invoke-PlanningCli $cli 'preparar-issue.ps1' @{Target='b';NoOpen=$true;EditorPath='editor-inexistente.exe'}
Assert ($result.Code -eq 0) ('Preparo da issue falhou: '+$result.Output)
Assert ((Test-Path -LiteralPath $path) -and -not (Test-Path -LiteralPath (Join-Path $a.Folder $relative))) 'Preparador deve escrever somente no projeto escolhido.'
$text=[IO.File]::ReadAllText($path)
Assert ($text -match '(?m)^agent: devsquad$' -and $text.Contains('web/fetch') -and $text.Contains('vscode/askQuestions')) 'Prompt deve herdar executor e ferramentas do contrato.'
$contextMatch=[regex]::Match($text,'(?s)```json\s*(.*?)\s*```')
Assert $contextMatch.Success 'Prompt precisa do contexto real da selecao.'
$data=$contextMatch.Groups[1].Value | ConvertFrom-Json
Assert ($data.Project -ceq 'b' -and $data.Source -eq $b.Source -and $data.MigrationPath -eq $b.MigrationPath -and $data.ConfigPath -eq $cli.Config -and $data.WorkspacePath -eq $cli.Workspace) 'Contexto do projeto/config/workspace incorreto.'
$links=[regex]::Matches($text,'\]\(<([^>]+)>\)')
Assert ($links.Count -ge 3) 'Prompt precisa de contrato, registro e indice.'
foreach ($link in $links) {
    $uri=[Uri]::new((ConvertTo-HarnessFileUri $path),$link.Groups[1].Value)
    Assert ($uri.IsFile -and (Test-Path -LiteralPath $uri.LocalPath)) ('Link invalido: '+$link.Value)
}
Assert (-not $result.Output.Contains('WARNING')) 'NoOpen nao deve chamar editor inexistente.'
Assert ([IO.File]::ReadAllText($a.MigrationPath) -ceq $beforeA) 'Preparo alterou outro projeto.'
Assert ([IO.File]::ReadAllText($b.MigrationPath) -ceq $beforeB) 'Preparo nao deve cadastrar issue ou mudar decisoes.'
Assert ((Get-FileHash -LiteralPath $b.Pom).Hash -eq $beforeSource -and -not (Test-Path -LiteralPath $b.PlanPath)) 'Preparo alterou Source ou criou plano.'

# Notas persistem; cabecalho antigo e contexto gerenciado sao renovados.
[IO.File]::WriteAllText($path,$text.Replace('agent: devsquad','agent: antigo')+"`nNota humana: usar o erro do log da sessao, sem repetir deploy.`n")
$result=Invoke-PlanningCli $cli 'preparar-issue.ps1' @{Target='b';NoOpen=$true}
Assert ($result.Code -eq 0) $result.Output
$text=[IO.File]::ReadAllText($path)
Assert ($text.Contains('Nota humana: usar o erro do log da sessao') -and $text.Contains('agent: devsquad') -and -not $text.Contains('agent: antigo')) 'Repreparo perdeu nota ou manteve cabecalho obsoleto.'
$state=Get-PlanningFixtureState $fixture
$result=Invoke-PlanningCli $cli 'preparar-issue.ps1' @{Target='b';NoOpen=$true}
Assert ($result.Code -eq 0 -and (Get-PlanningFixtureState $fixture) -ceq $state) 'Repeticao identica deve preservar documentos.'

# Sem registro ou com registro corrompido, nenhuma preparacao ficticia.
[IO.File]::WriteAllText($a.MigrationPath,'registro invalido')
$state=Get-PlanningFixtureState $fixture
$result=Invoke-PlanningCli $cli 'preparar-issue.ps1' @{Target='a';NoOpen=$true}
Assert ($result.Code -ne 0 -and (Get-PlanningFixtureState $fixture) -ceq $state) 'Registro invalido nao deve permitir escrita.'
[IO.File]::Delete($a.MigrationPath)
$state=Get-PlanningFixtureState $fixture
$result=Invoke-PlanningCli $cli 'preparar-issue.ps1' @{Target='a';NoOpen=$true}
Assert ($result.Code -ne 0 -and $result.Output.Contains('atualizar indice') -and (Get-PlanningFixtureState $fixture) -ceq $state) 'Registro ausente deve orientar indice sem inventar cadastro.'
Write-Output 'PASS: preparo por projeto, fontes/contexto reais, ferramentas, preservacao, repeticao e falhas sem escrita.'
