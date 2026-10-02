#requires -Version 5.1
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $root 'scripts/Harness.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $root 'scripts/HarnessProjectIndex.psm1') -Force -DisableNameChecking
function Assert($condition, $message) { if (-not $condition) { throw $message } }
function Write-TestCatalog($run, [int[]]$counts) {
    $violations = @{}
    for ($i = 0; $i -lt $counts.Count; $i++) {
        $incidents = @(for ($j = 0; $j -lt $counts[$i]; $j++) { @{uri="arquivo-$j"} })
        $category = switch ($i) { 0 { 'mandatory' } 1 { 'optional' } default { 'future-category' } }
        $violations["rule-$i"] = @{description='Regra';category=$category;incidents=$incidents}
    }
    $apps = @(@{rulesets=@(@{name='java';violations=$violations})})
    $null = [IO.Directory]::CreateDirectory("$run/output/static-report")
    [IO.File]::WriteAllText("$run/output/static-report/output.js", ('window["apps"] = ' + (ConvertTo-Json -InputObject $apps -Depth 12)))
}
$area = Join-Path $root ('.harness/tests/indice-' + [guid]::NewGuid().ToString('N'))
$fixture = Join-Path $area 'harness'
$app = Join-Path $area 'app um'
$other = Join-Path $area 'app dois'
foreach ($path in @($fixture, $app, $other)) { $null = [IO.Directory]::CreateDirectory($path) }
foreach ($path in @($app, $other)) { Set-Content -LiteralPath (Join-Path $path 'pom.xml') '<project />' }
$config = Get-Content (Join-Path $root 'config/harness.example.json') -Raw | ConvertFrom-Json
$config.repositories = @(); $config.activeProject = $null
$configPath = Join-Path $fixture 'config.json'
Write-HarnessJson $configPath $config
$workspace = Join-Path $area 'workspace.code-workspace'
Write-HarnessJson $workspace @{folders=@(@{name='Mesmo nome';path=$app},@{name='Mesmo nome';path=$other})}
$context = Read-HarnessConfig $configPath $fixture -WorkspacePath $workspace -SkipMigrationInitialization
Assert (-not (Test-Path "$fixture/.harness/projetos")) 'Ler para indexar nao deve criar registros.'
$first = New-HarnessProjectIndex $context
Assert ((Split-Path $first.IndexPath -Leaf) -eq 'indice-projetos.md') 'Indice deve ter nome significativo.'
$text = [IO.File]::ReadAllText($first.IndexPath)
Assert ($text.Contains('NAO GERADO') -and $text.Contains('SEM REGISTRO')) 'Ausencias devem estar explicitas.'
Assert ($text.Contains('indisponivel') -and $text.Contains('Catalogos contabilizados: 0/2')) 'Ausencia nao pode parecer total zero confirmado.'
Assert ($text.Contains('## Como interpretar o indice') -and $text.Contains('| Indicacao | Significado | O que fazer |')) 'Indice deve conter instrucoes de interpretacao.'
foreach ($state in @('CATALOGO NAO CARREGADO','MESMA RODADA','RODADA DIFERENTE','ULTIMA TENTATIVA FAILED','SEM MTA LOCALIZADO','COMPARACAO INDISPONIVEL')) {
    Assert ($text.Contains('| ' + $state)) ('Legenda ausente: ' + $state)
}
Assert ($text.Contains($app) -and $text.Contains($other)) 'Homonimos devem ser distinguidos pelo Source.'
$firstHash = (Get-FileHash $first.SnapshotPath).Hash
$project = $context.Projects[0]
$register = Initialize-HarnessMigration $fixture $project
$md = [IO.File]::ReadAllText($register.MigrationPath).Replace('AGUARDANDO MTA', ('Rodada MTA: ' + ('a'*32)))
$md = $md.Replace('<!-- mta:fim -->', "| regra::1 | Uma | mandatory | 138 | PRESENTE | ANALISAR AGORA | ANALISADA | 20/138 |`n| regra::2 | Outra | optional | 18 | NAO REENCONTRADA | ADIAR | IMPLEMENTADA | parcial |`n<!-- mta:fim -->")
[IO.File]::WriteAllText($register.MigrationPath, $md)
Write-HarnessJson "$fixture/.harness/builds/renomeado/antigo/result.json" @{Source=$app;RunId='b1';Status='SUCCEEDED';StartedAtUtc='2026-09-01T10:00:00Z'}
Write-HarnessJson "$fixture/.harness/builds/renomeado/novo/result.json" @{Source=$app;RunId='b2';Status='FAILED';StartedAtUtc='2026-09-02T10:00:00Z'}
Write-HarnessJson "$fixture/.harness/builds/outro/novo/result.json" @{Source=$other;RunId='b3';Status='SUCCEEDED';StartedAtUtc='2026-09-03T10:00:00Z'}
Write-HarnessJson "$fixture/.harness/sonar/app/coleta/result.json" @{Source=$app;RunId='s1';Status='QUALITY_GATE_FAILED';Phase='DEPOIS';StartedAtUtc='2026-09-04T10:00:00Z'}
$planFolder = "$fixture/.harness/planning/app/rodada/solicitacao"
Write-HarnessJson "$planFolder/context.json" @{Source=$app;Purpose='application-remediation';RequestId='p1';PreparedAtUtc='2026-09-05T10:00:00Z'}
Write-HarnessJson "$fixture/.harness/planning/app/registro/solicitacao/context.json" @{Source=$app;Purpose='migration-register';RequestId='r1';PreparedAtUtc='2026-09-06T10:00:00Z'}
$external = Join-Path $area 'mta externo'
$id = 'c'*32
$indexFolder = "$fixture/.harness/runs/app/$id"
Write-HarnessJson "$indexFolder/location.json" @{Source=$app;Project='app';RunId=$id;RunsPath=$external;RunRelativePath='app/260901-100000'}
Write-HarnessJson "$external/app/260901-100000/manifest.json" @{Source=$app;Project='app';RunId=$id;IndexPath=$indexFolder;CreatedAtUtc='2026-09-01T10:00:00Z'}
Write-HarnessJson "$external/app/260901-100000/result.json" @{Source=$app;Project='app';RunId=$id;Status='SUCCEEDED'}
Write-TestCatalog "$external/app/260901-100000" @(6,4)
$before = @(Get-ChildItem $area -Recurse -File | Where-Object { $_.FullName -notlike '*\projetos\indices\*' -and $_.Name -ne 'indice-projetos.md' } | Get-FileHash)
$second = New-HarnessProjectIndex $context
$text = [IO.File]::ReadAllText($second.IndexPath)
Assert ($text.Contains('FAILED') -and $text.Contains('2026-09-02')) 'Ultima falha do build foi escondida.'
Assert ($text.Contains('QUALITY_GATE_FAILED') -and $text.Contains('DEPOIS')) 'Sonar perdeu status ou fase.'
Assert ($text.Contains('CONTEXTO PREPARADO') -and $text.Contains('Manutencao do registro:') -and $text.Contains('ID: r1')) 'Manutencao foi confundida com plano.'
Assert ($text.Contains('1 issues presentes / 138 ocorrencias') -and $text.Contains('NAO REENCONTRADA: 1')) 'Contagem misturou historico com MTA atual.'
Assert ($text.Contains('ANALISAR AGORA: 1') -and $text.Contains('ADIAR: 1')) 'Resumo perdeu escolhas humanas.'
Assert ($text.Contains('| Issues / ocorrencias (ultimo MTA) |') -and $text.Contains('Proximos passos sugeridos')) 'Faltou resumo consolidado por projeto.'
Assert ($text.Contains('**Total MTA contabilizado: 2 issues / 10 ocorrencias**') -and $text.Contains('Catalogos contabilizados: 1/2')) 'Totais devem vir do MTA, nao das 138 ocorrencias no registro antigo.'
Assert ($text.Contains('Categorias do ultimo MTA: mandatory: 1 issues / 6 ocorrencias; optional: 1 issues / 4 ocorrencias')) 'Categorias MTA ausentes.'
$summaryLine = @($text -split '\r?\n' | Where-Object { $_.StartsWith('| ') -and $_.Contains($app) })
Assert ($summaryLine.Count -eq 1 -and $summaryLine[0].Contains('| mandatory: 1 / 6; optional: 1 / 4 |')) 'Resumo deve separar issues e ocorrencias por categoria.'
Assert ($text.Contains('Conferir rodada MTA do registro')) 'Proxima acao deve mostrar divergencia do catalogo.'
Assert ($text.Contains('- MTA:') -and $text.Contains($id)) 'MTA externo nao foi indexado.'
Assert (-not $text.Contains('ID: b1') -and -not $text.Contains('registro(s)')) 'Resumo nao deve listar nem contar historico de execucoes.'
Assert ((Get-FileHash $first.SnapshotPath).Hash -eq $firstHash -and $first.SnapshotPath -ne $second.SnapshotPath) 'Snapshot anterior foi alterado.'
foreach ($file in $before) { Assert ((Get-FileHash $file.Path).Hash -eq $file.Hash) 'Indexacao alterou entrada.' }
foreach ($document in @($second.IndexPath, $second.SnapshotPath)) {
    $baseUri = [Uri](([Uri]$document).AbsoluteUri)
    foreach ($link in [regex]::Matches([IO.File]::ReadAllText($document), '\]\(<([^>]+)>\)')) {
        $targetUri = New-Object Uri($baseUri, $link.Groups[1].Value)
        Assert (Test-Path -LiteralPath $targetUri.LocalPath) ('Link quebrado no indice: ' + $targetUri.LocalPath)
    }
}
Set-Content "$planFolder/plan.md" 'GO humano: PENDENTE'
$third = New-HarnessProjectIndex $context
Assert ([IO.File]::ReadAllText($third.IndexPath).Contains('DOCUMENTOS INCOMPLETOS')) 'Plano sem todo nao pode parecer completo.'
Set-Content "$planFolder/todo.md" 'pendente'
$fourth = New-HarnessProjectIndex $context
Assert ([IO.File]::ReadAllText($fourth.IndexPath).Contains('PLANO E TO-DO PRESENTES')) 'Par gerado nao reconhecido.'
# Uma rodada mais nova substitui a anterior, inclusive se falhou. Erro antigo nao contamina o resumo.
$newId = 'd'*32
$newMta = "$fixture/.harness/runs/app/mta_2026-09-07_10-00-00+0000__dddddddddddd"
Write-HarnessJson "$newMta/manifest.json" @{Source=$app;Project='app';RunId=$newId;CreatedAtUtc='2026-09-07T10:00:00Z'}
Write-HarnessJson "$newMta/result.json" @{Project='app';RunId=$newId;Status='FAILED'}
$oldBroken = "$fixture/.harness/runs/app/mta_2026-09-01_10-00-00+0000__eeeeeeeeeeee"
$null = [IO.Directory]::CreateDirectory($oldBroken)
$newPlan = "$fixture/.harness/planning/app/rodada/nova"
Write-HarnessJson "$newPlan/context.json" @{Source=$app;Purpose='application-remediation';RequestId='p2';PreparedAtUtc='2026-09-07T10:00:00Z'}
Write-HarnessJson "$fixture/.harness/sonar/app/nova/result.json" @{Source=$app;RunId='s2';Status='SUCCEEDED';Phase='DEPOIS';StartedAtUtc='2026-09-07T10:00:00Z'}
Write-HarnessJson "$fixture/.harness/planning/app/registro/nova/context.json" @{Source=$app;Purpose='migration-register';RequestId='r2';PreparedAtUtc='2026-09-07T10:00:00Z'}
$latestOnly = New-HarnessProjectIndex $context
$text = [IO.File]::ReadAllText($latestOnly.IndexPath)
Assert ($text.Contains($newId) -and -not $text.Contains($id) -and -not $text.Contains($oldBroken)) 'MTA antigo contaminou resumo da ultima rodada.'
Assert ($latestOnly.Warnings.Count -eq 0) 'Aviso de historico anterior nao pertence ao resumo atual.'
Assert ($text.Contains('**Total MTA contabilizado: indisponivel**')) 'Falha recente nao deve usar numeros do MTA anterior nem do registro.'
Assert ($text.Contains('catalogo do registro usa outra rodada MTA')) 'Diferenca entre MTA carregado e ultima execucao ficou oculta.'
foreach ($oldId in @('b1','p1','r1','s1')) { Assert (-not $text.Contains('ID: ' + $oldId)) 'Acao antiga aparece no resumo.' }
foreach ($latestId in @('b2','p2','r2','s2')) { Assert ($text.Contains('ID: ' + $latestId)) 'Ultima acao nao aparece no resumo.' }
# Recibo corrompido e destino externo indisponivel devem aparecer como limites.
Set-Content "$fixture/.harness/builds/renomeado/novo/result.json" '{ quebrado'
$location = Get-Content "$indexFolder/location.json" -Raw | ConvertFrom-Json
$location.RunsPath = Join-Path $area 'ausente'
Write-HarnessJson "$indexFolder/location.json" $location
$newResult = Get-Content "$newMta/result.json" -Raw | ConvertFrom-Json
$newResult.RunId = 'errado'
Write-HarnessJson "$newMta/result.json" $newResult
$fifth = New-HarnessProjectIndex $context
$text = [IO.File]::ReadAllText($fifth.IndexPath)
Assert ($text.Contains('Limites da leitura') -and $text.Contains('NAO VERIFICADO')) 'Falhas de leitura ficaram invisiveis.'
Assert (@(Get-ChildItem "$fixture/.harness/projetos" -Recurse -File | Where-Object Name -like 'migracao*.md').Count -eq 1) 'Indice criou registro inesperado.'
# Entrada CLI: nenhuma selecao de projeto; abre somente indice, sem analisar.
$null = [IO.Directory]::CreateDirectory("$fixture/scripts")
foreach ($file in @('Harness.psm1','HarnessPlanning.psm1','HarnessProjectIndex.psm1','atualizar-indice-projetos.ps1')) {
    Copy-Item -LiteralPath (Join-Path $root "scripts/$file") -Destination "$fixture/scripts/$file"
}
$editor = "$fixture/scripts/editor.ps1"
Set-Content -LiteralPath $editor -Value '$args | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $PSScriptRoot "editor.json")'
$cli = & powershell.exe -NoProfile -File "$fixture/scripts/atualizar-indice-projetos.ps1" -ConfigPath $configPath -WorkspacePath $workspace -EditorPath $editor 2>&1 | Out-String
Assert ($LASTEXITCODE -eq 0 -and $cli.Contains('Copia datada:') -and $cli.Contains('Leitura parcial')) ('CLI falhou: ' + $cli)
$editorArgs = Get-Content "$fixture/scripts/editor.json" -Raw | ConvertFrom-Json
Assert ($editorArgs[0] -eq '--reuse-window' -and $editorArgs[1] -eq $fifth.IndexPath) 'Editor nao recebeu indice atual.'
Import-Module (Join-Path $root 'scripts/HarnessCleanup.psm1') -Force -DisableNameChecking
$cleanup = @(Get-HarnessCleanupPaths $fixture -All)
Assert (@($cleanup | Where-Object { $fifth.SnapshotPath.StartsWith($_ + '\') -or $fifth.IndexPath.StartsWith($_ + '\') }).Count -eq 0) 'Limpeza inclui indice/historico.'
# Totais entre projetos: manuais contam no acompanhamento, antigas nao; ausencias nao sao zero.
$secondProject = @($context.Projects | Where-Object path -eq $other)[0]
$secondRegister = Initialize-HarnessMigration $fixture $secondProject
$secondMd = [IO.File]::ReadAllText($secondRegister.MigrationPath).Replace('AGUARDANDO MTA', ('Rodada MTA: ' + ('f'*32)))
$secondMd = $secondMd.Replace('<!-- mta:fim -->', "| regra::1 | Mesma regra, outro projeto | mandatory | 18 | PRESENTE | ANALISAR AGORA | PLANEJADA | |`n| DEV-1 | Manual | manual | - | MANUAL | ADIAR | NAO ANALISADA | |`n<!-- mta:fim -->")
[IO.File]::WriteAllText($secondRegister.MigrationPath, $secondMd)
$location.RunsPath = $external
Write-HarnessJson "$indexFolder/location.json" $location
Write-HarnessJson "$newMta/result.json" @{Project='app';RunId=$newId;Status='SUCCEEDED'}
Write-TestCatalog $newMta @(6,4)
$otherMta = "$fixture/.harness/runs/outro/ffffffffffffffffffffffffffffffff"
Write-HarnessJson "$otherMta/manifest.json" @{Source=$other;Project='outro';RunId=('f'*32);CreatedAtUtc='2026-09-07T10:00:00Z'}
Write-HarnessJson "$otherMta/result.json" @{Project='outro';RunId=('f'*32);Status='SUCCEEDED'}
Write-TestCatalog $otherMta @(18)
$consolidated = New-HarnessProjectIndex $context
$text = [IO.File]::ReadAllText($consolidated.IndexPath)
Assert ($text.Contains('**Total MTA contabilizado: 3 issues / 28 ocorrencias**') -and $text.Contains('Catalogos contabilizados: 2/2')) 'Totais entre projetos devem somar somente os ultimos MTA.'
Assert ($text.Contains('Totais por categoria (issues / ocorrencias): mandatory: 2 / 24; optional: 1 / 4')) 'Consolidacao por categoria incorreta.'
Assert ($text.Contains('Decisoes consolidadas: ADIAR: 1; ANALISAR AGORA: 2')) 'Decisoes devem incluir manual e excluir nao reencontrada.'
Assert ($text.Contains('Andamento consolidado: ANALISADA: 1; NAO ANALISADA: 1; PLANEJADA: 1')) 'Andamento consolidado incorreto.'
Assert ($text.Contains('confirmar GO humano antes de implementar')) 'Issue planejada nao deve autorizar execucao.'
$secondLine = @($text -split '\r?\n' | Where-Object { $_.StartsWith('| ') -and $_.Contains($other) })
Assert ($secondLine.Count -eq 1 -and $secondLine[0].Contains('18') -and $secondLine[0].Contains('PLANEJADA: 1')) 'Faltou uma unica linha consolidada por projeto.'
foreach ($case in @(
    @{Status='ANALISADA';Expected='Planejar issues ANALISAR AGORA'},
    @{Status='IMPLEMENTADA';Expected='Verificar implementacao e registrar evidencias'},
    @{Status='VERIFICADA';Expected='Revisar decisoes e evidencias para definir continuidade'}
)) {
    [IO.File]::WriteAllText($secondRegister.MigrationPath, $secondMd.Replace('PLANEJADA', $case.Status))
    $check = New-HarnessProjectIndex $context
    Assert ([IO.File]::ReadAllText($check.IndexPath).Contains($case.Expected)) ('Sugestao incorreta para ' + $case.Status)
}
[IO.File]::WriteAllText($secondRegister.MigrationPath, '<!-- mta:inicio -->invalido<!-- mta:fim -->')
$invalid = New-HarnessProjectIndex $context
$text = [IO.File]::ReadAllText($invalid.IndexPath)
Assert ($text.Contains('Catalogos contabilizados: 2/2') -and $text.Contains('**Total MTA contabilizado: 3 issues / 28 ocorrencias**')) 'Registro invalido nao deve impedir contagens MTA.'
# Catalogo estruturado ausente/corrompido nunca usa o registro como substituto.
[IO.File]::WriteAllText("$otherMta/output/static-report/output.js", 'invalido')
$brokenCatalog = New-HarnessProjectIndex $context
$text = [IO.File]::ReadAllText($brokenCatalog.IndexPath)
Assert ($text.Contains('Catalogos contabilizados: 1/2') -and $text.Contains('**Total MTA contabilizado: 2 issues / 10 ocorrencias**') -and $text.Contains('Formato de catalogo MTA nao suportado')) 'Catalogo invalido nao ficou excluido e explicado.'
Write-TestCatalog $otherMta @()
$emptyCatalog = New-HarnessProjectIndex $context
$text = [IO.File]::ReadAllText($emptyCatalog.IndexPath)
Assert ($text.Contains('Catalogos contabilizados: 2/2') -and $text.Contains('| 0 / 0 |')) 'Catalogo vazio valido deve ter zero confirmado.'
$missingCatalog = "$fixture/.harness/runs/outro/abababababababababababababababab"
Write-HarnessJson "$missingCatalog/manifest.json" @{Source=$other;Project='outro';RunId=('ab'*16);CreatedAtUtc='2026-09-08T10:00:00Z'}
Write-HarnessJson "$missingCatalog/result.json" @{Project='outro';RunId=('ab'*16);Status='SUCCEEDED'}
$missing = New-HarnessProjectIndex $context
$text = [IO.File]::ReadAllText($missing.IndexPath)
Assert ($text.Contains('Catalogos contabilizados: 1/2') -and $text.Contains('Catalogo estruturado ausente')) 'MTA sem output.js deve explicitar contagem indisponivel.'
Write-TestCatalog $missingCatalog @(1,2,3)
$unknownCategory = New-HarnessProjectIndex $context
$text = [IO.File]::ReadAllText($unknownCategory.IndexPath)
Assert ($text.Contains('Totais por categoria (issues / ocorrencias): future-category: 1 / 3; mandatory: 2 / 7; optional: 2 / 6')) 'Categorias adicionais devem ser preservadas, sem reduzir a obrigatoria/opcional.'
Write-Output 'PASS: indice por Source, ausencias, tentativas, MTA externo, planos, registro e snapshots preservados.'
