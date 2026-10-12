#requires -Version 5.1
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Test-IssueQueries.ps1')
Import-Module (Join-Path $root 'scripts/HarnessPlanning.psm1') -Force -DisableNameChecking
[IO.File]::WriteAllText($paths.MigrationPath,$registerText.Replace("| $issueId | Hibernate bytes | mandatory | 138 | PRESENTE | A DEFINIR |","| $issueId | Hibernate bytes | mandatory | 138 | PRESENTE | ANALISAR AGORA |"))
$plan=New-HarnessCurrentPlanning $context
$planningJson=[IO.File]::ReadAllText($plan.ContextPath)
function PlanningQuery([string]$action,[hashtable]$extra=@{}) { Invoke-HarnessIssueQuery -Root $fixture -Action $action -ContextPath $plan.ContextPath @extra }
$before=Inventory $area
$detail=PlanningQuery obter_issue @{Id=$issueId;Incident=138}
Assert ($detail.Status -eq 'OK' -and $detail.Paging.Total -eq 138) ('Consulta corrente falhou: '+($detail | ConvertTo-Json -Depth 8))
Assert ((PlanningQuery listar_issues).Paging.Total -eq 1) 'Planejamento ampliou recorte.'
Assert ((PlanningQuery obter_issue @{Id='hibernate::opcional'}).Error.Code -eq 'ISSUE_NOT_FOUND') 'Issue fora da selecao foi servida.'
Assert ((Inventory $area) -ceq $before) 'Consulta de planejamento gravou entradas.'
# Origem ausente nao faz fallback para copias antigas.
$report=Join-Path $run 'output/static-report/index.html'
Move-Item -LiteralPath $report -Destination ($report+'.indisponivel')
try { Assert ((PlanningQuery obter_issue @{Id=$issueId}).Status -eq 'ERROR') 'Origem indisponivel virou evidencia inventada.' }
finally { Move-Item -LiteralPath ($report+'.indisponivel') -Destination $report }
# Uma troca da associacao local e detectada antes de servir dados.
$configText=[IO.File]::ReadAllText($paths.ConfigPath)
try {
    $config=$configText | ConvertFrom-Json; $config.pom=Join-Path $area 'outro/pom.xml'
    Write-HarnessJson $paths.ConfigPath $config
    Assert ((PlanningQuery auditar_base).Error.Code -eq 'IDENTITY_CONFLICT') 'Outra associacao ao POM foi aceita.'
} finally { [IO.File]::WriteAllText($paths.ConfigPath,$configText) }
# Sem MTA, o planejamento humano segue os arquivos correntes.
$manualRoot=Join-Path $area 'manual'
$manualContext=[pscustomobject]@{Root=$manualRoot;Active=$project;Projects=@($project)}
foreach ($file in @('.github/prompts/planejar-lotes.prompt.md')) {
    $dest=Join-Path $manualRoot $file; $null=[IO.Directory]::CreateDirectory((Split-Path $dest -Parent)); Copy-Item (Join-Path $root $file) $dest
}
$manualRegister=Initialize-HarnessProjectStorage $manualRoot (Join-Path $source 'pom.xml')
$null=Update-HarnessProjectDocuments $manualRegister
$log=Join-Path $manualRoot 'erro.txt'; Set-Content $log 'Falha relatada pelo desenvolvedor.'
$manualText=[IO.File]::ReadAllText($manualRegister.MigrationPath)
$row="| DEV-LOG | Corrigir log | manual | - | MANUAL | ANALISAR AGORA | NAO ANALISADA | [Evidencia](<$log>) |"
[IO.File]::WriteAllText($manualRegister.MigrationPath,$manualText.Replace('<!-- mta:fim -->',$row+"`n<!-- mta:fim -->"))
$manualPlan=New-HarnessCurrentPlanning $manualContext -PlanningBasis EVIDENCIAS
$before=Inventory $area
$human=Invoke-HarnessIssueQuery -Root $manualRoot -ContextPath $manualPlan.ContextPath -Action obter_issue -Id DEV-LOG
Assert ($human.Status -eq 'OK' -and $human.Provenance.PlanningBasis -eq 'EVIDENCIAS' -and -not $human.Provenance.Contains('RunId')) 'Base humana ganhou origem ficticia.'
Assert ($human.Paging.Total -eq 0 -and -not $human.Data.Issue.CatalogAvailable -and $human.Data.EvidenceReferencesJson.Contains('erro.txt')) 'Issue manual ganhou incidentes ou perdeu referencia.'
$humanAudit=Invoke-HarnessIssueQuery -Root $manualRoot -ContextPath $manualPlan.ContextPath -Action auditar_base
Assert ($humanAudit.Status -eq 'OK' -and $humanAudit.Data.CatalogIssues -eq 0 -and $humanAudit.Data.DifferencesCount -eq 0) 'Auditoria humana exigiu MTA.'
Assert ((Inventory $area) -ceq $before) 'Consulta humana gravou arquivos.'
Write-Host 'PASS: planejamento corrente MTA/EVIDENCIAS, escopo, identidade, lacunas e nenhuma copia.'
