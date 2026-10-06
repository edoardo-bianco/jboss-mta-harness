#requires -Version 5.1
$ErrorActionPreference='Stop'
# A fixture e criada pelos preparadores existentes; so as chamadas Query sao read-only.
. (Join-Path $PSScriptRoot 'Test-IssueQueries.ps1')
Import-Module (Join-Path $root 'scripts/HarnessPlanning.psm1') -Force -DisableNameChecking
[IO.File]::WriteAllText($paths.MigrationPath,$registerText.Replace("| $issueId | Hibernate bytes | mandatory | 138 | PRESENTE | A DEFINIR |","| $issueId | Hibernate bytes | mandatory | 138 | PRESENTE | ANALISAR AGORA |"))
$plan=Invoke-HarnessRegisteredPlanning $context -MigrationPath $paths.MigrationPath
$planning=Get-Content -LiteralPath $plan.ContextPath -Raw | ConvertFrom-Json
$planningJson=[IO.File]::ReadAllText($plan.ContextPath)
function PlanningQuery([string]$action,[hashtable]$extra=@{}) {
    Invoke-HarnessIssueQuery -Root $fixture -Action $action -ContextPath $plan.ContextPath @extra
}
$before=Inventory $area
$detail=PlanningQuery obter_issue @{Id=$issueId;Incident=138}
Assert ($detail.Status -eq 'OK') ('Consulta consolidada falhou: '+($detail | ConvertTo-Json -Depth 8))
Assert ($detail.Provenance.EvidenceMode -eq 'CONSOLIDATED' -and $detail.Paging.Total -eq 138) 'Recorte MTA consolidado nao lido.'
Assert ((PlanningQuery listar_issues).Paging.Total -eq 1) 'Planejamento ampliou recorte para outras issues do registro.'
Assert ((PlanningQuery obter_issue @{Id='hibernate::opcional'}).Error.Code -eq 'ISSUE_NOT_FOUND') 'Planejamento permitiu issue fora da selecao.'
Assert ((Inventory $area) -ceq $before) 'Consulta de planejamento gravou entradas.'

# A copia continua consultavel mesmo sem diagnostico original e com origem humana alterada.
$historical=Join-Path $area 'anexo historico.txt'; Set-Content -LiteralPath $historical 'versao atual diferente'
$planning.SourceEvidenceInputs=@([pscustomobject]@{Path=$historical;Status='DISPONIVEL';Sha256=('0'*64)})
Write-HarnessJson $plan.ContextPath $planning
$fixtureRoot=[IO.Path]::GetFullPath($area).TrimEnd('\')+'\'
$hiddenRun=Join-Path $area 'mta temporariamente indisponivel'
foreach ($target in @($run,$hiddenRun)) { Assert ([IO.Path]::GetFullPath($target).StartsWith($fixtureRoot,[StringComparison]::OrdinalIgnoreCase)) 'Movimento fora da fixture.' }
Rename-Item -LiteralPath $run -NewName 'mta temporariamente indisponivel'
try {
    $before=Inventory $area
    $offline=PlanningQuery obter_issue @{Id=$issueId}
    Assert ($offline.Status -eq 'OK' -and $offline.Data.Incidents.Count -eq 10) 'Consolidado reabriu origem historica.'
    Assert ((Inventory $area) -ceq $before) 'Consulta offline gravou entradas.'
} finally { Rename-Item -LiteralPath $hiddenRun -NewName (Split-Path $run -Leaf) }
[IO.File]::WriteAllText($plan.ContextPath,$planningJson)

# O recibo original legado nao tem SchemaVersion/LayoutVersion/PlanningBasis.
$legacy=$planningJson | ConvertFrom-Json
foreach ($field in @('LayoutVersion','PlanningBasis','EvidenceMode','Consolidated','IssueId','FichaPath','IssueInputs')) { $legacy.PSObject.Properties.Remove($field) }
$legacy.EvidenceInputs=@()
Write-HarnessJson $plan.ContextPath $legacy
$original=PlanningQuery obter_issue @{Id=$issueId;Incident=138}
Assert ($original.Status -eq 'OK' -and $original.Provenance.PlanningBasis -eq 'MTA' -and $original.Provenance.EvidenceMode -eq 'ORIGINAL') 'Compatibilidade com planejamento original perdida.'
[IO.File]::WriteAllText($plan.ContextPath,$planningJson)

$cutPath=$planning.Consolidated.MtaIssuePath
$cutJson=[IO.File]::ReadAllText($cutPath)
$cut=$cutJson | ConvertFrom-Json; $cut.Issue.Id='hibernate::outra'
Write-HarnessJson $cutPath $cut
Assert ((PlanningQuery obter_issue @{Id=$issueId}).Error.Code -eq 'HASH_MISMATCH') 'Recorte adulterado foi servido.'
$changed=$planningJson | ConvertFrom-Json
($changed.Consolidated.Files | Where-Object RelativePath -eq 'evidencias/apontamentos-mta.json').Sha256=(Get-FileHash $cutPath).Hash
Write-HarnessJson $plan.ContextPath $changed
Assert ((PlanningQuery obter_issue @{Id=$issueId}).Error.Code -eq 'IDENTITY_CONFLICT') 'ID interno conflitante aceito mesmo com hash valido.'
[IO.File]::WriteAllText($cutPath,$cutJson); [IO.File]::WriteAllText($plan.ContextPath,$planningJson)

# Pacote real exportado/importado para outra raiz e outro Source.
Set-Content -LiteralPath $planning.PlanPath '# Plano de teste sem GO'
Set-Content -LiteralPath $planning.TodoPath '- [ ] Corretiva pendente'
Import-Module (Join-Path $root 'scripts/HarnessTransfer.psm1') -Force -DisableNameChecking
$package=Join-Path $area 'contexto.zip'
$null=Export-HarnessContextPackage $context $plan.ContextPath $package
$destination=Join-Path $area 'destino'; $localSource=Join-Path $area 'colega codigo'
$null=[IO.Directory]::CreateDirectory($localSource)
Set-Content (Join-Path $localSource 'pom.xml') '<project><artifactId>servico-local</artifactId></project>'
$localProject=[pscustomobject]@{name='colega';label='Colega';path=$localSource}
$localContext=[pscustomobject]@{Root=$destination;Active=$localProject;Projects=@($localProject);Config=$null;ConfigPath=$null;WorkspacePath=$null}
$map=@{}; $map[$planning.Source]=$localSource
$received=Import-HarnessContextPackage $localContext $package $map
$before=Inventory $area
$imported=Invoke-HarnessIssueQuery -Root $destination -ContextPath $received.ContextPath -Action obter_issue -Id $issueId
Assert ($imported.Status -eq 'OK') ('Consulta importada falhou: '+($imported | ConvertTo-Json -Depth 5))
Assert ($imported.Provenance.Source -eq $localSource -and $imported.Provenance.MtaOrigin.Source -eq 'C:/origem/app') 'Importacao confundiu Source local com origem MTA.'
Assert ($imported.Data.Incidents[0].Location.SourceCandidate -eq (Join-Path $localSource 'src/Servico.java')) 'Candidato importado apontou fonte do colega errado.'
Assert ((Inventory $area) -ceq $before) 'Consulta importada modificou dados.'

# Planejamento humano sem MTA: nenhum incidente ou RunId sintetizado.
$manualRoot=Join-Path $area 'manual'
$manualContext=[pscustomobject]@{Root=$manualRoot;Active=$project;Projects=@($project);Config=$null;ConfigPath=$null;WorkspacePath=$null}
foreach ($file in @('doc/especificacoes/planejamento-copilot.md','.github/prompts/planejar-lotes.prompt.md')) {
    $dest=Join-Path $manualRoot $file; $null=[IO.Directory]::CreateDirectory((Split-Path $dest -Parent)); Copy-Item (Join-Path $root $file) $dest
}
$manualRegister=Initialize-HarnessMigration $manualRoot $project
$log=Join-Path $manualRoot 'erro.txt'; Set-Content $log 'Falha relatada pelo desenvolvedor.'
$manualText=[IO.File]::ReadAllText($manualRegister.MigrationPath)
$row="| DEV-LOG | Corrigir log | manual | - | MANUAL | ANALISAR AGORA | NAO ANALISADA | [Evidencia](<$log>) |"
[IO.File]::WriteAllText($manualRegister.MigrationPath,$manualText.Replace('<!-- mta:fim -->',$row+"`n<!-- mta:fim -->"))
$manualPlan=Invoke-HarnessRegisteredPlanning $manualContext -MigrationPath $manualRegister.MigrationPath
$human=Invoke-HarnessIssueQuery -Root $manualRoot -ContextPath $manualPlan.ContextPath -Action obter_issue -Id DEV-LOG
Assert ($human.Status -eq 'OK' -and $human.Provenance.PlanningBasis -eq 'EVIDENCIAS' -and $null -eq $human.Provenance.RunId) 'Base humana ganhou origem MTA ficticia.'
Assert ($human.Paging.Total -eq 0 -and -not $human.Data.Issue.CatalogAvailable -and $human.Data.EvidenceReferencesJson.Contains('erro.txt')) 'Issue manual sem referencia ou com incidentes inventados.'
$humanAudit=Invoke-HarnessIssueQuery -Root $manualRoot -ContextPath $manualPlan.ContextPath -Action auditar_base
Assert ($humanAudit.Status -eq 'OK' -and $humanAudit.Data.CatalogIssues -eq 0 -and $humanAudit.Data.DifferencesCount -eq 0) 'Auditoria manual exigiu catalogo MTA.'
Write-Host 'PASS: planejamento original/consolidado/importado, evidencia humana, identidade e escopo.'
