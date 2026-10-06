#requires -Version 5.1
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $root 'scripts/Harness.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $root 'scripts/HarnessPrioritization.psm1') -Force -DisableNameChecking
function Assert($condition,$message) { if (-not $condition) { throw $message } }
function Inventory($path) {
    (@(Get-ChildItem -LiteralPath $path -File -Recurse -Force | Sort-Object FullName | ForEach-Object {
        $_.FullName+'|'+(Get-FileHash -LiteralPath $_.FullName).Hash
    }) -join "`n")
}
$area=Join-Path $root ('.harness/tests/q'+[guid]::NewGuid().ToString('N').Substring(0,8))
$fixture=Join-Path $area 'h'
$source=Join-Path $area 'codigo local'
$run=Join-Path $area 'mta recebido'
$runId='b'*32
$issueId='hibernate::hibernate4-00039'
foreach ($folder in @($source,(Join-Path $run 'input/src'),(Join-Path $run 'rules'),(Join-Path $run 'output/static-report'))) {
    $null=[IO.Directory]::CreateDirectory($folder)
}
Set-Content -LiteralPath (Join-Path $source 'pom.xml') '<project><artifactId>servico</artifactId></project>'
$uri='file:///C:/origem/.harness/runs/app/mta_2026-09-30_07-57-02-0300__bbbbbbbbbbbb/input/src/Servico.java'
$incidents=@(foreach ($i in 1..138) { [ordered]@{uri=$uri;lineNumber=50+$i;message="Ocorrencia $i";codeSnip="public byte[] metodo$i() { return new byte[0]; }"} })
$incidents[0].message+=' '+('x'*300)
$violations=[ordered]@{
    'hibernate4-00039'=[ordered]@{description='Hibernate bytes';category='mandatory';labels=@('hibernate');links=@(@{url='https://example.invalid/regra';title='Referencia'});effort=3;incidents=$incidents}
    'regra2'=[ordered]@{description='Outra obrigatoria';category='mandatory';incidents=@(@{uri=$uri;lineNumber=9;message='Outra';codeSnip='return null;'})}
    'opcional'=[ordered]@{description='Melhoria';category='optional';labels=@('hibernate');incidents=@(@{uri=$uri;lineNumber=12;message='Melhoria';codeSnip='return 1;'})}
}
$catalog=Join-Path $run 'output/static-report/output.js'
function Save-Catalog {
    $apps=@([ordered]@{name='origem';rulesets=@([ordered]@{name='hibernate';violations=$violations})})
    [IO.File]::WriteAllText($catalog,('window["apps"] = '+(ConvertTo-Json -InputObject $apps -Depth 20 -Compress)+';'))
}
Save-Catalog
Write-HarnessJson (Join-Path $run 'manifest.json') @{RunId=$runId;Project='origem';Source='C:/origem/app';CreatedAtUtc='2026-10-05T10:00:00Z'}
Write-HarnessJson (Join-Path $run 'result.json') @{RunId=$runId;Project='origem';Status='SUCCEEDED';ExitCode=0;SourceUnchanged=$true;SnapshotOriginalFilesUnchanged=$true;RulesUnchanged=$true;UnexpectedAddedFiles=@()}
foreach ($file in @('output/output.yaml','output/dependencies.yaml','output/static-report/index.html')) { Set-Content -LiteralPath (Join-Path $run $file) 'Fixture' }
$project=[pscustomobject]@{name='servico';label='Servico';path=$source}
$context=[pscustomobject]@{Root=$fixture;Active=$project;Projects=@($project);ConfigPath=$null;WorkspacePath=$null}
$paths=Initialize-HarnessMigration $fixture $project
$index=Join-Path $fixture '.harness/projetos/indice-projetos.md'
Set-Content -LiteralPath $index '# Indice sintetico'
foreach ($file in @('doc/especificacoes/planejamento-copilot.md','.github/prompts/priorizar-issues.prompt.md','.github/prompts/planejar-lotes.prompt.md')) {
    $dest=Join-Path $fixture $file; $null=[IO.Directory]::CreateDirectory((Split-Path $dest -Parent)); Copy-Item -LiteralPath (Join-Path $root $file) -Destination $dest
}
$origin=@{RunId=$runId;Project='origem';Source='C:/origem/app';Run=$run} | ConvertTo-Json -Compress
$text=[IO.File]::ReadAllText($paths.MigrationPath).Replace('AGUARDANDO MTA','')
$rows=@("<!-- MTA $origin -->","Rodada MTA: $runId.",
    "| $issueId | Hibernate bytes | mandatory | 138 | PRESENTE | A DEFINIR | NAO ANALISADA | |",
    '| hibernate::regra2 | Outra obrigatoria | mandatory | 1 | PRESENTE | ADIAR | NAO ANALISADA | |',
    '| hibernate::opcional | Melhoria | optional | 1 | PRESENTE | A DEFINIR | NAO ANALISADA | |',
    '| DEV-LOG | Log manual | manual | - | MANUAL | A DEFINIR | NAO ANALISADA | |') -join "`n"
[IO.File]::WriteAllText($paths.MigrationPath,$text.Replace('<!-- mta:fim -->',$rows+"`n<!-- mta:fim -->"))
$prepared=New-HarnessPrioritizationContext $context -Mode Recreate -Percentage 100 -Category mandatory
$before=Inventory $area
Import-Module (Join-Path $root 'scripts/HarnessIssueQuery.psm1') -Force -DisableNameChecking
function Query([string]$action,[hashtable]$extra=@{}) {
    Invoke-HarnessIssueQuery -Root $fixture -Action $action -ContextPath $prepared.ContextPath @extra
}
$audit=Query auditar_base
Assert ($audit.Status -eq 'OK') ('Auditoria falhou: '+($audit | ConvertTo-Json -Depth 10))
Assert ($audit.ReadOnly -and $audit.SchemaVersion -eq 1) 'Contrato de leitura ausente.'
Assert ($audit.Data.CatalogIssues -eq 3 -and $audit.Data.CatalogIncidents -eq 140) 'Contagens MTA incorretas.'
Assert ($audit.Data.RegisterIssues -eq 4 -and $audit.Data.DifferencesCount -eq 0) 'Registro divergiu sem motivo.'
Assert ($audit.Provenance.Source -eq $source -and $audit.Provenance.RunId -eq $runId) 'Origem ausente.'
$list=Query listar_issues @{PageSize=2}
Assert ($list.Status -eq 'OK' -and $list.Paging.Total -eq 4 -and $list.Paging.HasMore) 'Lista deve incluir catalogo e issue manual, paginada.'
Assert ($list.Data.Items[0].Id -ceq 'DEV-LOG' -and $list.Data.Items[1].Id -ceq $issueId) 'Ordenacao ordinal ou IDs incorretos.'
$mandatory=Query listar_issues @{Category='mandatory';Decision='ADIAR'}
Assert ($mandatory.Paging.Total -eq 1 -and $mandatory.Data.Items[0].Id -ceq 'hibernate::regra2') 'Filtro por categoria/decisao omitiu registro adiado.'
Assert ($mandatory.Data.Items[0].Availability -eq 'NOT_AVAILABLE_IN_REQUEST') 'Item adiado declarado disponivel.'
$optional=Query listar_issues @{Category='optional';Label='hibernate'}
Assert ($optional.Paging.Total -eq 1 -and $optional.Data.Items[0].Availability -eq 'OUTSIDE_CATEGORY') 'Outra categoria misturada com sequencia.'
$empty=Query listar_issues @{Text='*'}
Assert ($empty.Status -eq 'OK' -and $empty.Paging.Total -eq 0) 'Busca deve ser literal, nao wildcard.'
$detail=Query obter_issue @{Id=$issueId;MaxTextChars=128}
Assert ($detail.Status -eq 'OK' -and $detail.Paging.Total -eq 138 -and $detail.Paging.Returned -eq 10) 'Detalhe deve paginar todos os incidentes.'
Assert ($detail.Data.Incidents[0].Message.Length -eq 128 -and $detail.Data.Incidents[0].TruncatedFields.Count -eq 1) 'Truncamento silencioso ou ausente.'
Assert ($detail.Data.Incidents[0].Location.SourceCandidate -eq (Join-Path $source 'src/Servico.java')) 'Candidato local mapeado incorretamente.'
$basis=$detail.Provenance.BasisSha256
$ordinals=@(foreach ($page in 1..14) {
    $response=Query obter_issue @{Id=$issueId;Page=$page;ExpectedBasisSha256=$basis}
    Assert ($response.Status -eq 'OK') 'Paginacao da mesma base falhou.'
    $response.Data.Incidents.Ordinal
})
Assert (($ordinals -join ',') -ceq ((1..138) -join ',')) 'Incidentes foram omitidos ou duplicados entre paginas.'
$last=Query obter_issue @{Id=$issueId;Incident=138}
Assert ($last.Paging.Returned -eq 1 -and $last.Data.Incidents[0].LineNumber -eq 188) 'Ordinal final perdido.'
Assert ((Query obter_issue @{Id=$issueId;Incident=138;Page=2}).Error.Code -eq 'INVALID_INPUT') 'Ordinal e pagina aceitos juntos.'
Assert ((Query obter_issue @{Id='inexistente'}).Error.Code -eq 'ISSUE_NOT_FOUND') 'Issue ausente virou sucesso vazio.'
Assert ((Query obter_issue @{Id=$issueId;PageSize=11}).Error.Code -eq 'INVALID_INPUT') 'Pagina de incidentes acima do limite.'
Assert ((Query listar_issues @{Page='texto'}).Error.Code -eq 'INVALID_INPUT') 'Numero invalido sem erro estruturado.'
Assert ((Query listar_issues @{ExpectedBasisSha256=('0'*64)}).Error.Code -eq 'BASE_CHANGED') 'Base antiga misturada silenciosamente.'
Assert ((Inventory $area) -ceq $before) 'Consulta gravou ou alterou entradas.'
$registerText=[IO.File]::ReadAllText($paths.MigrationPath)
[IO.File]::WriteAllText($paths.MigrationPath,$registerText.Replace('| ADIAR |','| ANALISAR AGORA |'))
$changed=Query listar_issues @{Decision='ANALISAR AGORA'}
Assert ($changed.Status -eq 'OK' -and $changed.Paging.Total -eq 1 -and $changed.Diagnostics -like 'REGISTER_CHANGED*') 'Escolha atual nao foi respeitada.'
Assert ((Query listar_issues @{ExpectedBasisSha256=$basis}).Error.Code -eq 'BASE_CHANGED') 'Mudanca do registro nao invalidou pagina.'
[IO.File]::WriteAllText($paths.MigrationPath,$registerText.Replace('"Project":"origem"','"Project":"outra"'))
Assert ((Query auditar_base).Error.Code -eq 'IDENTITY_CONFLICT') 'Mesmo RunId aceitou origem de outro projeto.'
[IO.File]::WriteAllText($paths.MigrationPath,$registerText)
$catalogText=[IO.File]::ReadAllText($catalog)
[IO.File]::WriteAllText($catalog,$catalogText+' ')
Assert ((Query auditar_base).Error.Code -eq 'HASH_MISMATCH') 'Catalogo alterado sem deteccao.'
[IO.File]::WriteAllText($catalog,$catalogText)
$missingRoot=Join-Path $area 'nao existe'
$missing=Invoke-HarnessIssueQuery -Root $missingRoot -ContextPath (Join-Path $missingRoot 'context.json') -Action auditar_base
Assert ($missing.Error.Code -eq 'NOT_FOUND' -and -not (Test-Path $missingRoot)) 'Consulta ausente criou estado ou ocultou erro.'
Write-Host 'PASS: auditoria/lista/detalhe, filtros, 138 incidentes, identidade, hashes e ausencia de escrita.'
