#requires -Version 5.1
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$root=Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $root 'scripts/HarnessProject.psm1') -Force -DisableNameChecking
function Assert($value,[string]$message) { if (-not $value) { throw $message } }
$area=Join-Path $root ('.harness/tests/documentos-'+[guid]::NewGuid().ToString('N').Substring(0,8))
$app=Join-Path $area 'fonte com espacos'; $null=[IO.Directory]::CreateDirectory($app)
[IO.File]::WriteAllText((Join-Path $app 'pom.xml'),'<project><artifactId>servico</artifactId></project>')
$project=Initialize-HarnessProjectStorage $area (Join-Path $app 'pom.xml')
$report=Join-Path $area 'relatorio.html'; [IO.File]::WriteAllText($report,'MTA sintetico')
$mta=[pscustomobject]@{ReportPath=$report;Diagnostics=@();Issues=@([pscustomobject]@{Id='java::regra';Title='Problema';Category='mandatory';Count=4})}
Update-HarnessProjectDocuments $project -Mta $mta -UpdateIssues
$before=Read-HarnessProjectFiles $project @('migracao.md','indice.md')
Assert ($before['indice.md'] -match '\[POM\]\(' -and $before['indice.md'] -match '\[MTA atual\]\(') 'Indice deve ligar diretamente a POM e MTA.'
Assert ($before['migracao.md'] -match 'java::regra') 'Primeiro MTA deve oferecer issue para decisao.'
Assert ($before['indice.md'] -match '\[Codigo local\]\(') 'Indice do projeto deve localizar Source sem duplicar seu conteudo.'
Assert ($before['migracao.md'].Contains('## Como usar este registro') -and $before['migracao.md'].Contains('ficha-issue.template.md')) 'Registro deve orientar preenchimento e vincular o modelo comum da ficha.'
Assert ($before['migracao.md'].Contains('NAO REENCONTRADA') -and $before['migracao.md'].Contains('VERIFICADA')) 'Orientacao deve distinguir presenca, decisao e andamento.'
$human=$before['migracao.md'].Replace('| A DEFINIR | NAO ANALISADA |','| ANALISAR AGORA | PLANEJADA |').Replace('<!-- mta:fim -->',"| ID-manual | Humana | manual | - | MANUAL | ADIAR | NAO ANALISADA | [POM](../pom.xml) &#124; justificativa |`n<!-- mta:fim -->")+"`nTexto humano a preservar.`n"
Publish-HarnessProjectFiles $project @{'migracao.md'=$human}
[IO.File]::Delete($project.IndexPath)
Update-HarnessProjectDocuments $project -Mta $mta
$after=Read-HarnessProjectFiles $project @('migracao.md','indice.md')
Assert ($after['migracao.md'] -ceq $human) 'Reconstruir indice nao altera decisoes ou conteudo manual.'
Assert ($after['indice.md'] -match 'MTA atual') 'Indice removido deve ser reconstruido sem recibos.'
$mta.Issues=@()
Update-HarnessProjectDocuments $project -Mta $mta -UpdateIssues
$decisions=@(Get-HarnessProjectDecisions $project)
Assert ($decisions.Count -eq 2 -and $decisions[0].Decision -eq 'ANALISAR AGORA' -and $decisions[0].Progress -eq 'PLANEJADA') 'Nova leitura deve preservar decisoes por chave funcional, inclusive prefixo ID.'
Assert ($decisions[0].Presence -eq 'NAO REENCONTRADA') 'Ausencia no MTA nao significa resolucao.'
Assert ([IO.File]::ReadAllText($project.MigrationPath).Contains('Texto humano a preservar.')) 'Texto externo ao bloco deve permanecer.'
Assert (-not (Test-Path (Join-Path $project.Folder 'reconciliado'))) 'Consultar/atualizar indice nao reconcilia automaticamente.'
Assert (@(Get-ChildItem -LiteralPath $project.Folder -Recurse -File).Count -eq 3) 'Sem snapshots, extratos, indice datado ou recibo.'
Assert ($decisions[1].Note -ceq '[POM](../pom.xml) &#124; justificativa') 'Observacao humana conserva Markdown e entidades.'
$mta.ReportPath=Join-Path $area 'outro relatorio.html'; [IO.File]::WriteAllText($mta.ReportPath,'novo')
Update-HarnessProjectDocuments $project -Mta $mta
Assert ([IO.File]::ReadAllText($project.MigrationPath).Contains('outro%20relatorio.html')) 'Atualizar indice deve corrigir o link MTA atual no registro.'
$valid=[IO.File]::ReadAllText($project.MigrationPath)
# Registros anteriores ao modelo recebem so a orientacao gerada, uma unica vez.
$withoutOrientation=[regex]::Replace($valid,'(?s)<!-- registro:orientacao:inicio -->.*?<!-- registro:orientacao:fim -->','')
Publish-HarnessProjectFiles $project @{'migracao.md'=$withoutOrientation}
Update-HarnessProjectDocuments $project -Mta $mta
$upgraded=[IO.File]::ReadAllText($project.MigrationPath)
Update-HarnessProjectDocuments $project -Mta $mta
Assert ([IO.File]::ReadAllText($project.MigrationPath) -ceq $upgraded) 'Adicionar orientacao a registro existente deve ser idempotente.'
Assert ((Find-ProjectManagedBlock $upgraded 'mta').Value -ceq (Find-ProjectManagedBlock $valid 'mta').Value -and $upgraded.Contains('Texto humano a preservar.')) 'Acrescentar orientacao preserva tabela e notas existentes.'
foreach ($invalid in @($valid+"`n<!-- mta:inicio -->",$valid.Replace('<!-- mta:inicio -->',"<!-- mta:inicio -->`n<!-- mta:inicio -->"))) {
    Publish-HarnessProjectFiles $project @{'migracao.md'=$invalid}
    $failed=$false; try { Update-HarnessProjectDocuments $project -Mta $mta -UpdateIssues } catch { $failed=$true }
    Assert $failed 'Marcador orfao/aninhado deve impedir reescrita.'
    Assert ([IO.File]::ReadAllText($project.MigrationPath) -ceq $invalid) 'Texto ambiguo deve permanecer intacto.'
}
'PASS: indice reconstruivel, links diretos e decisoes preservadas sem rastreamento.'
