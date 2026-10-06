#requires -Version 5.1
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$root=Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $root 'scripts/Harness.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $root 'scripts/HarnessPlanning.psm1') -Force -DisableNameChecking
function Assert($value,$message) { if (-not $value) { throw $message } }
function Reject($action,$message) { $failed=$false; try { & $action | Out-Null } catch { $failed=$true }; Assert $failed $message }
$area=Join-Path $root ('.harness/tests/ip-'+[guid]::NewGuid().ToString('N').Substring(0,8))
$fixture=Join-Path $area 'h'
$app=Join-Path $area 'app'; $null=[IO.Directory]::CreateDirectory($app)
Set-Content (Join-Path $app 'pom.xml') '<project><artifactId>meu-servico</artifactId><name>Nome descritivo</name></project>'
$project=[pscustomobject]@{name='app';label='App';path=$app}
$context=[pscustomobject]@{Root=$fixture;Active=$project;Projects=@($project);Config=$null;ConfigPath=$null;WorkspacePath=$null}
foreach ($relative in @('doc/especificacoes/planejamento-copilot.md','.github/prompts/planejar-lotes.prompt.md','.github/prompts/implementar-lote.prompt.md','.github/prompts/revisar-resultado.prompt.md')) {
    $dest=Join-Path $fixture $relative; $null=[IO.Directory]::CreateDirectory((Split-Path $dest -Parent)); Copy-Item (Join-Path $root $relative) $dest
}
$register=Initialize-HarnessMigration $fixture $project
$id='DEV-CACHE'
$issue=Get-HarnessIssuePaths $fixture $project $id
Assert ($issue.Folder.Contains('\planning\meu-servico\issues\') -and $issue.Stem.StartsWith('meu-servico-')) 'Pasta/arquivo nao usam artifactId Maven.'
$other=Get-HarnessIssuePaths $fixture ([pscustomobject]@{name='other';label='App';path=(Join-Path $area 'other')}) $id
Assert ($issue.Folder -ne $other.Folder -and $issue.Stem -ne $other.Stem) 'Projetos com mesmo titulo/issue colidiram.'
$collision=Get-HarnessIssuePaths $fixture $project 'DEV:CACHE'
Assert ($issue.Folder -ne $collision.Folder) 'Caracteres normalizados causaram colisao.'
$null=[IO.Directory]::CreateDirectory((Split-Path $issue.EvidenceIndexPath -Parent))
Set-Content $issue.EvidenceIndexPath "# Evidencias`nProject: app`nSource: $app`nIssue: $id`n`n| Arquivo relativo | Relacao com a correcao |`n| --- | --- |`n| falha.txt | Erro desta issue |"
Set-Content (Join-Path (Split-Path $issue.EvidenceIndexPath -Parent) 'falha.txt') 'Erro antes da corretiva'
$text=[IO.File]::ReadAllText($register.MigrationPath)
$row="| $id | Cache | manual | - | MANUAL | ANALISAR AGORA | NAO ANALISADA | |"
[IO.File]::WriteAllText($register.MigrationPath,$text.Replace('Total MTA:',"$row`nTotal MTA:"))
$prepared=Invoke-HarnessRegisteredPlanning $context -MigrationPath $register.MigrationPath
$r=Get-Content $prepared.ContextPath -Raw -Encoding UTF8 | ConvertFrom-Json
$project.label='Outro rotulo'
Assert ((Get-HarnessIssuePaths $fixture $project $id).Folder -eq $issue.Folder) 'Alterar rotulo mudou a pasta da issue.'
$duplicate=Join-Path $area 'duplicado'; $null=[IO.Directory]::CreateDirectory($duplicate)
Set-Content (Join-Path $duplicate 'pom.xml') '<project><artifactId>meu-servico</artifactId></project>'
Reject { Get-HarnessIssuePaths $fixture ([pscustomobject]@{name='outro';label='Outro';path=$duplicate}) $id } 'artifactId duplicado misturou Sources.'
Assert ($r.LayoutVersion -eq 2 -and $r.IssueId -eq $id -and $r.EvidenceMode -eq 'CONSOLIDATED') 'Contexto por issue nao consolidado.'
Assert ((Split-Path $r.PlanPath -Leaf) -eq ('plan-'+$issue.Stem+'.md') -and (Split-Path $r.TodoPath -Leaf) -eq ('todo-'+$issue.Stem+'.md')) 'Nomes nao distinguem projeto/issue.'
Assert ($r.PlanPath.Replace('\','/').Contains('/issues/')) 'Pasta da issue ausente.'
Assert (@($r.EvidenceInputs | Where-Object { $_.Path -like '*falha.txt' }).Count -eq 1) 'Anexo da issue nao carregado.'
Assert (-not (Test-Path $r.PlanPath)) 'Preparo inventou plano.'
$same=Invoke-HarnessRegisteredPlanning $context -ContextPath $r.ContextPath
Assert ($same.RequestId -eq $r.RequestId) 'Retomada duplicou contexto.'
Set-Content $r.PlanPath '# Plano desta issue'
Set-Content $r.TodoPath '- [ ] Corrigir'
$impl=New-MtaImplementationPrompt $context -RequestId $r.RequestId
Assert (Test-Path $impl.PromptPath) 'Implementacao nao reconhece nomes por issue.'
Set-Content (Join-Path $app 'pom.xml') '<project><artifactId>meu-servico-renomeado</artifactId></project>'
Assert (@(Get-MtaPlanningHistory $context).Count -eq 1) 'Mudanca no artifactId invalidou historico.'
Set-Content (Join-Path $app 'pom.xml') '<project><artifactId>meu-servico</artifactId></project>'
$indexBefore=[IO.File]::ReadAllText($issue.EvidenceIndexPath)
Add-Content $issue.EvidenceIndexPath ('<!-- issue: '+(@{Source=$app;Id='DEV-OUTRA'}|ConvertTo-Json -Compress)+' -->')
Reject { Invoke-HarnessRegisteredPlanning $context -ContextPath $r.ContextPath } 'Indice de outra issue foi aceito.'
[IO.File]::WriteAllText($issue.EvidenceIndexPath,$indexBefore)
$registerBefore=[IO.File]::ReadAllText($register.MigrationPath)
[IO.File]::WriteAllText($register.MigrationPath,$registerBefore.Replace('Total MTA:',"| DEV-OUTRA | Outra | manual | - | MANUAL | ANALISAR AGORA | NAO ANALISADA | |`nTotal MTA:"))
Reject { New-MtaPlanningContext $context -MigrationPath $register.MigrationPath -PreviousRequestId $r.RequestId } 'Revisao por issue virou lote legado multi-issue.'
Reject { Invoke-HarnessRegisteredPlanning $context -ContextPath $r.ContextPath } 'Retomada ignorou segunda issue escolhida.'
[IO.File]::WriteAllText($register.MigrationPath,$registerBefore)
Import-Module (Join-Path $root 'scripts/HarnessCleanup.psm1') -Force -DisableNameChecking
foreach ($selection in @(@{All=$true},@{Source=$app})) {
    $removals=@(Get-HarnessCleanupPaths $fixture @selection)
    Assert (@($removals | Where-Object { $issue.Folder.StartsWith($_,[StringComparison]::OrdinalIgnoreCase) }).Count -eq 0) 'Limpeza selecionou dossie/evidencias oficiais.'
}
$originalHash=(Get-FileHash $r.ContextPath).Hash
Add-Content (Join-Path (Split-Path $issue.EvidenceIndexPath -Parent) 'falha.txt') 'Complemento'
$revision=Invoke-HarnessRegisteredPlanning $context -ContextPath $r.ContextPath
$next=Get-Content $revision.ContextPath -Raw -Encoding UTF8 | ConvertFrom-Json
Assert ($next.Previous.RequestId -eq $r.RequestId -and (Get-FileHash $r.ContextPath).Hash -eq $originalHash) 'Nova evidencia perdeu historico.'
Write-Output 'PASS: pastas/nomes por projeto e issue, anexos, historico e preparo da implementacao.'

# A mesma proposta deve continuar utilizavel com a origem MTA inacessivel.
$mtaApp=Join-Path $area 'mta-app'; $null=[IO.Directory]::CreateDirectory($mtaApp)
Set-Content (Join-Path $mtaApp 'pom.xml') '<project/>'
$mp=[pscustomobject]@{name='mta-app';label='MtaApp';path=$mtaApp}
$mc=[pscustomobject]@{Root=$fixture;Active=$mp;Projects=@($mp);Config=$null;ConfigPath=$null;WorkspacePath=$null}
$mr=Initialize-HarnessMigration $fixture $mp
$run=Join-Path $area 'mta'; $runId='b'*32
foreach ($dir in @('input','rules','output/static-report')) { $null=[IO.Directory]::CreateDirectory((Join-Path $run $dir)) }
Write-HarnessJson (Join-Path $run 'manifest.json') @{RunId=$runId;Project='origem';Source='Z:/origem';CreatedAtUtc='2026-10-01T10:00:00Z'}
Write-HarnessJson (Join-Path $run 'result.json') @{RunId=$runId;Project='origem';Status='SUCCEEDED';ExitCode=0;SourceUnchanged=$true;SnapshotOriginalFilesUnchanged=$true;RulesUnchanged=$true;UnexpectedAddedFiles=@()}
foreach ($file in @('output/output.yaml','output/dependencies.yaml','output/static-report/index.html')) { Set-Content (Join-Path $run $file) 'fixture' }
$uri=([Uri](Join-Path $run 'input/src/A.java')).AbsoluteUri
$catalog=@(@{rulesets=@(@{name='r';violations=@{rule=@{description='Regra';category='optional';links=@(@{url='https://example.invalid/rule'});incidents=@(@{uri=$uri;lineNumber=3;message='API';codeSnip='oldCall();'})}}})})|ConvertTo-Json -Depth 15 -Compress
Set-Content (Join-Path $run 'output/static-report/output.js') ('window["apps"] = ['+$catalog+'];')
$origin=@{RunId=$runId;Project='origem';Source='Z:/origem';Run=$run}|ConvertTo-Json -Compress
$text=[IO.File]::ReadAllText($mr.MigrationPath).Replace('AGUARDANDO MTA','')
$text=$text.Replace('<!-- mta:fim -->',"<!-- MTA $origin -->`nRodada MTA: $runId.`n| r::rule | Regra | optional | 1 | PRESENTE | ANALISAR AGORA | NAO ANALISADA | |`n<!-- mta:fim -->")
[IO.File]::WriteAllText($mr.MigrationPath,$text)
$issuePaths=Get-HarnessIssuePaths $fixture $mp 'r::rule'
$null=[IO.Directory]::CreateDirectory((Split-Path $issuePaths.EvidenceIndexPath -Parent))
$baseFicha=Join-Path (Split-Path $issuePaths.EvidenceIndexPath -Parent) 'ficha-base.md'
$identity=@{Source=$mtaApp;Id='r::rule'}|ConvertTo-Json -Compress
Set-Content $baseFicha "# Ficha optional recebida`n<!-- issue: $identity -->`nVerificar oldCall e seu consumidor; nao examinado fora deste recorte."
Set-Content $issuePaths.EvidenceIndexPath '| ficha-base.md#achado | Ficha escolhida |'
$prepared=Invoke-HarnessRegisteredPlanning $mc -MigrationPath $mr.MigrationPath
$m=Get-Content $prepared.ContextPath -Raw -Encoding UTF8 | ConvertFrom-Json
Assert ($m.IssueInputs[0].FichaOrigin -eq $baseFicha -and [IO.File]::ReadAllText($m.FichaPath).Contains('Ficha optional recebida')) 'Planejamento nao recebeu a ficha escolhida.'
Assert ($m.SourceEvidenceInputs[1].Reference -eq 'ficha-base.md#achado') 'Ancora da referencia perdida.'
$validFicha=[IO.File]::ReadAllText($baseFicha)
Set-Content $baseFicha ('<!-- issue: '+(@{Source=$app;Id='r::rule'}|ConvertTo-Json -Compress)+' -->')
Reject { Invoke-HarnessRegisteredPlanning $mc -ContextPath $m.ContextPath } 'Ficha de outro projeto aceita.'
[IO.File]::WriteAllText($baseFicha,$validFicha)
$extracted=Get-Content $m.Consolidated.MtaIssuePath -Raw -Encoding UTF8 | ConvertFrom-Json
Assert ($extracted.Id -eq 'r::rule' -and $extracted.Issue.Details.incidents[0].codeSnip -eq 'oldCall();' -and $extracted.Locations[0].RelativePath -eq 'src/A.java') 'Extracao perdeu incidente ou caminho relativo.'
Set-Content $m.PlanPath '# Plano'
Set-Content $m.TodoPath '- [ ] Corrigir'
$offline=Join-Path $area 'mta-offline'
Assert ((Resolve-HarnessPath $run $root).StartsWith((Resolve-HarnessPath $area $root)+'\') -and (Resolve-HarnessPath $offline $root).StartsWith((Resolve-HarnessPath $area $root)+'\')) 'Fixture fora da area de teste.'
[IO.Directory]::Move($run,$offline)
$implementation=New-MtaImplementationPrompt $mc -RequestId $m.RequestId
Assert (Test-Path $implementation.PromptPath) 'Implementacao continua dependendo do MTA original.'
Add-Content $m.Consolidated.MtaIssuePath 'Alterado'
Reject { New-MtaImplementationPrompt $mc -RequestId $m.RequestId } 'Consolidado alterado foi aceito.'
Write-Output 'PASS: MTA consolidado preserva detalhes e caminhos, funciona sem origem e rejeita adulteracao.'

# Nomes Maven usuais e regras longas precisam ser gravaveis no PowerShell 5.1.
$longApp=Join-Path $area 'long'; $null=[IO.Directory]::CreateDirectory($longApp)
Set-Content (Join-Path $longApp 'pom.xml') '<project><artifactId>corporativo-integracao-servico-legado</artifactId></project>'
$longProject=[pscustomobject]@{name='long';label='Long';path=$longApp}
$longContext=[pscustomobject]@{Root=$fixture;Active=$longProject;Projects=@($longProject)}
$longRegister=Initialize-HarnessMigration $fixture $longProject
$longId='DEV-hibernate-persistence-migracao-00039'
$longText=[IO.File]::ReadAllText($longRegister.MigrationPath).Replace('Total MTA:',"| $longId | Regra longa | manual | - | MANUAL | ANALISAR AGORA | NAO ANALISADA | |`nTotal MTA:")
[IO.File]::WriteAllText($longRegister.MigrationPath,$longText)
$longPlan=New-MtaPlanningContext $longContext -MigrationPath $longRegister.MigrationPath
Set-Content -LiteralPath $longPlan.PlanPath '# Plano gravavel'
Set-Content -LiteralPath $longPlan.TodoPath '- [ ] Passo'
Assert ((Test-Path -LiteralPath $longPlan.ContextPath) -and $longPlan.ContextPath.Length -lt 260 -and @(Get-MtaPlanningHistory $longContext).Count -eq 1) 'Nomes longos nao persistem/retomam.'
Write-Output 'PASS: artifactId historico, indice por issue, revisao isolada e nomes longos reais.'
