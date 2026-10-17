#requires -Version 5.1
$ErrorActionPreference='Stop'; Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'PlanningCurrentFixture.ps1')
$f=New-PlanningFixture 1
$p=$f.Projects[0]
$initial=Read-HarnessProjectMta $p
$oldHash=(Get-FileHash -LiteralPath $initial.CatalogPath).Hash
$register=[IO.File]::ReadAllText($p.MigrationPath)
Set-FixtureMta $p 2 @('mandatory') 'posterior'
$catalog=Join-Path $p.Root ('mta-'+$p.Name+'/posterior/output.js')
$report=Join-Path $p.Root ('mta-'+$p.Name+'/posterior/index.html')
# Datas distintas controladas: selecao de diagnostico completo, nao de plano/decisao.
[IO.File]::SetLastWriteTimeUtc($initial.ReportPath,[datetime]'2026-10-01T10:00:00Z')
[IO.File]::SetLastWriteTimeUtc($initial.CatalogPath,[datetime]'2026-10-01T10:00:00Z')
[IO.File]::SetLastWriteTimeUtc($catalog,[datetime]'2026-10-02T10:00:00Z')
[IO.File]::SetLastWriteTimeUtc($report,[datetime]'2026-10-02T10:00:00Z')
$current=Read-HarnessProjectMta $p
Assert ($current.CatalogPath -eq $catalog) 'Origem configurada deve selecionar ultimo diagnostico completo.'
$prepared=New-HarnessReconciliationContext $f.Context
$data=Read-Prepared $prepared
Assert ($data.Mta.CatalogPath -eq $catalog -and [IO.File]::ReadAllText($p.MigrationPath) -ceq $register) 'Preparo aponta MTA externo sem alterar registro.'
$before=(Get-FileHash -LiteralPath $catalog).Hash
$review=Start-HarnessReconciliationReview $p
$done=Complete-HarnessReconciliation $p -Conclusion 'Nova issue do diagnostico reconhecida sem mudar escolhas anteriores.'
Assert ([IO.File]::ReadAllText($p.MigrationPath).Contains('java::mandatory-2') -and [IO.File]::ReadAllText($p.MigrationPath).Contains('| ANALISAR AGORA |')) 'Reconciliacao deve atualizar fatos preservando escolha.'
Assert ((Get-FileHash -LiteralPath $catalog).Hash -eq $before -and (Get-FileHash -LiteralPath $initial.CatalogPath).Hash -eq $oldHash) 'MTA externo deve permanecer intacto.'
Assert (-not (Test-Path -LiteralPath (Join-Path $p.Folder 'atual/diagnosticos/mta'))) 'Leitura nao copia origem externa.'
Publish-HarnessProjectFiles $p @{'projeto.json'=(@{pom=$p.Pom;mta=@{diretorio='origem-ausente'}}|ConvertTo-Json)}
$state=Get-PlanningFixtureState $f
Reject { New-HarnessReconciliationContext $f.Context } 'Origem externa indisponivel nao pode trocar silenciosamente de base.'
Assert ((Get-PlanningFixtureState $f) -ceq $state) 'Falha de origem alterou documentos.'
'PASS: diagnostico externo corrente, preparo sem adocao, reconciliacao e origem preservada sem fallback.'
