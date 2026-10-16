#requires -Version 5.1
$ErrorActionPreference='Stop'; Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'ConversionFixture.ps1')
Import-Module (Join-Path $root 'scripts/HarnessProject.psm1') -DisableNameChecking
Import-Module (Join-Path $root 'scripts/HarnessPlanning.psm1') -DisableNameChecking
$f=New-ConversionFixture
# Este ensaio usa POM completo; nenhuma ferramenta Java precisa ser executada.
Write-ConversionFile $f.Pom '<project xmlns="http://maven.apache.org/POM/4.0.0"><modelVersion>4.0.0</modelVersion><groupId>ensaio</groupId><artifactId>api</artifactId><version>1.0</version></project>'
$sourceBefore=Get-ConversionState ([pscustomobject]@{Area=$f.Source})
$plan=Add-ConversionPlan $f ('a'*32)
$evidence=Join-Path (Split-Path $plan.PlanPath -Parent) 'observacao.md'
Write-ConversionFile $evidence '# Evidencia humana preservada na conversao'
Write-ConversionFile $plan.PlanPath ("# Plano humano - GO PENDENTE`n`n[Observacao](<observacao.md>)`n[Tarefas](<todo.md>)`n")
[IO.File]::AppendAllText($f.Register,("`n[Plano](<"+$plan.PlanPath+">)`n"))
$unrelated=Join-Path $f.Workspace '.harness/planning/nota-nao-selecionada.txt'
Write-ConversionFile $unrelated 'Material fora da selecao de descarte.'
$cli=Join-Path $root 'tools/transicao/Converter-RegistrosProjeto.ps1'
$choices=@{Workspace=$f.Workspace;Pom=$f.Pom;Registro=$f.Register;Contexto=$plan.ContextPath;Formato='Json'}
$before=Get-ConversionState $f
$preview=(& $cli @choices -Modo Previa | Out-String) | ConvertFrom-Json
Assert ($preview.Project -eq 'api' -and (Get-ConversionState $f) -ceq $before) 'Previa identifica o POM sem alterar o acervo.'
$legacy=@($f.Register,$plan.ContextPath,$plan.PlanPath,$plan.TodoPath,$evidence)
$originals=@{}
foreach ($path in $legacy) { $originals[$path]=(Get-FileHash -LiteralPath $path).Hash }
$applied=(& $cli @choices -Modo Aplicar | Out-String) | ConvertFrom-Json
Assert ($applied.Status -eq 'CONVERTIDO' -and -not $applied.AuthorizationInherited) 'Aplicar deve converter sem transferir autorizacao.'
foreach ($path in $legacy) { Assert ((Get-FileHash -LiteralPath $path).Hash -ceq $originals[$path]) 'Aplicar deve preservar os originais.' }
$project=Get-HarnessProjectStorage $f.Workspace $f.Pom
$valid=(& $cli -Workspace $f.Workspace -Pom $f.Pom -Modo Validar -Formato Json | Out-String) | ConvertFrom-Json
Assert $valid.Valid ('Conversao deve validar: '+($valid.Diagnostics -join '; '))
$cleanup=(& $cli @choices -Modo Limpar 6>&1 | Out-String) | ConvertFrom-Json
foreach ($path in $legacy) {
    $candidate=@($cleanup.Candidates | Where-Object Path -IEQ $path)
    Assert ($candidate.Count -eq 1 -and $candidate[0].Eligible) ('Descarte precisa de destino comprovado: '+$path)
}
$removed=(& $cli @choices -Modo Limpar -Descartar $legacy -Confirmacao LIMPAR 6>&1 | Out-String) | ConvertFrom-Json
Assert ($removed.Status -eq 'LIMPO' -and $removed.RemovedFiles.Count -eq $legacy.Count) 'Descarte deve retirar somente as folhas selecionadas.'
foreach ($path in $legacy) { Assert (-not (Test-Path -LiteralPath $path)) 'Legado selecionado deve ficar inacessivel.' }
Assert ([IO.File]::ReadAllText($unrelated) -ceq 'Material fora da selecao de descarte.') 'Material nao selecionado deve permanecer.'

# O consumidor corrente abre o resultado em outro processo, sem importar conversor.
$reader=Join-Path $f.Area 'ler-corrente.ps1'
Write-ConversionFile $reader @'
param($HarnessRoot,$Workspace,$Source)
$ErrorActionPreference='Stop'
Import-Module (Join-Path $HarnessRoot 'scripts/HarnessPlanning.psm1') -DisableNameChecking
$context=[pscustomobject]@{Root=$Workspace;Projects=@([pscustomobject]@{path=$Source;name='api';label='api'})}
$current=Get-HarnessCurrentPlanning $context -Target api
if (-not (Test-Path -LiteralPath $current.PlanPath)) { throw 'Plano convertido indisponivel.' }
if (@(Get-Module | Where-Object Name -Match '^(Conversao|Legado)').Count) { throw 'Consumidor depende do conversor.' }
'PASS: leitura corrente independente do conversor e dos originais.'
'@
& powershell.exe -NoProfile -NonInteractive -File $reader -HarnessRoot $root -Workspace $f.Workspace -Source $f.Source
Assert ($LASTEXITCODE -eq 0) 'Consumidor deve funcionar sem os documentos legados.'

# Contribuicao externa sobre o mesmo projeto convertido, sem copiar por cima.
$origin=Join-Path $f.Area 'contribuicao do colega'
$relative='atual/planejamento/plano.md'
$incoming=Join-Path $origin $relative
Write-ConversionFile $incoming ([IO.File]::ReadAllText($project.PlanPath)+"`nContribuicao do colega: conferir contrato HTTP.`n")
Write-ConversionFile (Join-Path $origin 'projeto.json') '{"pom":"Z:/colega/pom.xml","mta":{"diretorio":"Z:/mta"}}'
[IO.File]::AppendAllText($project.PlanPath,"`nNota local: preservar janela de manutencao.`n")
$originBefore=Get-ConversionState ([pscustomobject]@{Area=$origin})
$configBefore=[IO.File]::ReadAllText($project.ConfigPath)
$comparison=Get-HarnessReconciliationComparison $project $origin -PlanningBasis EVIDENCIAS
Assert (@($comparison.Documents | Where-Object { $_.Path -eq $relative -and $_.Status -eq 'DIVERGENTE' }).Count -eq 1) 'Divergencia de escopo deve ficar visivel.'
$null=Start-HarnessReconciliationReview $project $origin -PlanningBasis EVIDENCIAS
$pending=Complete-HarnessReconciliation $project -Conclusion 'Ensaio sintetico: conflito identificado, sem escolha automatica.'
Assert ($pending.State -eq 'PENDENTE' -and [IO.File]::ReadAllText($project.PlanPath).Contains('Nota local: preservar janela')) 'Conflito pendente deve preservar o trabalho local.'
Assert ((Get-ConversionState ([pscustomobject]@{Area=$origin})) -ceq $originBefore) 'Contribuicao externa deve permanecer intacta.'
$review=Start-HarnessReconciliationReview $project $origin -PlanningBasis EVIDENCIAS
$merged=[IO.File]::ReadAllText($project.PlanPath)+"`nContribuicao do colega: conferir contrato HTTP.`n"
Write-ConversionFile (Join-Path $review.ProposalPath $relative) $merged
$done=Complete-HarnessReconciliation $project -Conclusion 'Ensaio sintetico: mesclagem explicita das duas notas; GO pendente.' -Resolutions @{$relative='MESCLADO';'projeto.json'='DESCARTAR'}
Assert ($done.State -eq 'CONCLUIDA' -and $done.NeedsReview) 'Mesclagem conclui a comparacao e exige revisao do GO.'
$text=[IO.File]::ReadAllText($project.PlanPath)
Assert ($text.Contains('Nota local: preservar janela') -and $text.Contains('Contribuicao do colega: conferir contrato HTTP') -and $text.Contains('GO PENDENTE')) 'As duas contribuicoes e o GO pendente devem permanecer.'
Assert ([IO.File]::ReadAllText($project.ConfigPath) -ceq $configBefore) 'Configuracao estrangeira nao deve substituir associacao local.'
Assert ((Get-ConversionState ([pscustomobject]@{Area=$origin})) -ceq $originBefore) 'Resolucao nao deve apagar ou editar a origem externa.'

# Percurso pelos arquivos correntes e links existentes, sem relatorio MTA nesta base.
foreach ($path in @($project.IndexPath,$project.MigrationPath,$project.PlanPath,$project.TodoPath,$done.ReconciledPath)) {
    Assert (Test-Path -LiteralPath $path -PathType Leaf) ('Documento corrente ausente: '+$path)
    $text=[IO.File]::ReadAllText($path)
    Assert ($text -notmatch '\.harness[/\\]planning') 'Documento corrente nao pode depender do layout legado.'
    foreach ($match in [regex]::Matches($text,'\]\(<([^>]+)>\)')) {
        $target=New-Object Uri ((New-Object Uri $path),$match.Groups[1].Value)
        if ($target.IsFile) { Assert (Test-Path -LiteralPath $target.LocalPath) ('Link indisponivel: '+$target.LocalPath) }
    }
}
$valid=(& $cli -Workspace $f.Workspace -Pom $f.Pom -Modo Validar -Formato Json | Out-String) | ConvertFrom-Json
Assert $valid.Valid ('Estado reconciliado deve continuar valido: '+($valid.Diagnostics -join '; '))
Assert ((Get-ConversionState ([pscustomobject]@{Area=$f.Source})) -ceq $sourceBefore) 'Fonte/POM da aplicacao sintetica nao devem ser alterados.'
'PASS: previa, conversao, descarte selecionado, leitura independente, conflito, mesclagem, GO pendente e navegacao do mesmo projeto.'
