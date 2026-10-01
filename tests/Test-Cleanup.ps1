#requires -Version 5.1
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $root 'scripts/Harness.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $root 'scripts/HarnessCleanup.psm1') -Force -DisableNameChecking
function Assert($condition, $message) { if (-not $condition) { throw $message } }
$fixture = Join-Path $root ('.harness/tests/c' + [guid]::NewGuid().ToString('N').Substring(0,8))
$source = Join-Path $fixture 'app'
$other = Join-Path $fixture 'other'
$run = Join-Path $fixture '.harness/runs/old/11111111111111111111111111111111'
$build = Join-Path $fixture '.harness/builds/readable/build_2026-09-27_10-00-00-0300__222222222222'
$planning = Join-Path $fixture '.harness/planning/readable/mta_date/plano_date'
Write-HarnessJson "$run/manifest.json" @{Project='old';Source=$source;RunId='11111111111111111111111111111111'}
Write-HarnessJson "$run/result.json" @{Status='SUCCEEDED'}
Write-HarnessJson "$build/result.json" @{Project='new';Source=$source;RunId='22222222222222222222222222222222'}
Write-HarnessJson "$planning/context.json" @{Project='new';Source=$source;RunId='11111111111111111111111111111111';RequestId='33333333333333333333333333333333'}
Set-Content "$planning/plan.md" 'proposta'
Set-Content "$planning/todo.md" 'pendente'
$sonarBaseline = "$fixture/.harness/sonar/app/sonar-baseline/result.json"
Write-HarnessJson $sonarBaseline @{Phase='ANTES'; AnalysisId='preservar'}
$sonarHash = (Get-FileHash $sonarBaseline).Hash
$preservedData = @('.harness/projetos/app/migracao.md', '.harness/projetos/app/evidencias/LEIA-ME.md', '.harness/evidencias/print.txt')
foreach ($file in $preservedData) {
    $path = Join-Path $fixture $file
    $null = [IO.Directory]::CreateDirectory((Split-Path -Parent $path))
    Set-Content -LiteralPath $path 'decisoes e evidencias a preservar'
}
Write-HarnessJson "$fixture/.harness/runs/other/44444444444444444444444444444444/manifest.json" @{Project='other';Source=$other;RunId='44444444444444444444444444444444'}
foreach ($file in @('config/harness.local.json','app/pom.xml','.harness/maven/settings.xml','.harness/workspace-backups/backup.json','.github/prompts/planejar-lotes.prompt.md')) { Write-HarnessJson (Join-Path $fixture $file) @{preserve=$true} }
Write-HarnessJson "$fixture/.harness/last-old.json" @{RunId='11111111111111111111111111111111'}
Write-HarnessJson "$fixture/.harness/last-other.json" @{RunId='44444444444444444444444444444444'}
Write-HarnessJson "$fixture/.harness/active-mta.json" @{Project='old';RunId='11111111111111111111111111111111'}
$before = @(Get-ChildItem -LiteralPath $fixture -Recurse -File | Get-FileHash)
$selection = @(Get-HarnessCleanupPaths $fixture -Source $source)
Assert ($selection.Count -eq 5) 'Selecao deve incluir MTA/build/planning e ponteiros do mesmo Source nos dois formatos.'
foreach ($file in $before) { Assert ((Get-FileHash -LiteralPath $file.Path).Hash -eq $file.Hash) 'Preview alterou arquivo.' }
Invoke-HarnessCleanup $fixture -Source $source -ConfirmText 'cancelar' | Out-Null
Assert (Test-Path -LiteralPath $run) 'Cancelamento removeu historico.'
Write-HarnessJson "$fixture/.harness/runs/old/55555555555555555555555555555555/manifest.json" @{Project='old';Source=$other;RunId='55555555555555555555555555555555'}
Write-HarnessJson "$fixture/.harness/last-old.json" @{RunId='55555555555555555555555555555555'}
Write-HarnessJson "$fixture/.harness/active-mta.json" @{Project='old';RunId='55555555555555555555555555555555'}
Assert (@(Get-HarnessCleanupPaths $fixture -Source $source).Count -eq 3) 'Ponteiros de outro Source com mesmo Project nao podem ser removidos.'
Write-HarnessJson "$fixture/.harness/last-old.json" @{RunId='11111111111111111111111111111111'}
Write-HarnessJson "$fixture/.harness/active-mta.json" @{Project='old';RunId='11111111111111111111111111111111'}
foreach ($lock in @('mta.lock','planning.lock')) {
$lease = [IO.File]::Open("$fixture/.harness/$lock", 'OpenOrCreate','ReadWrite','None')
try {
    $rejected=$false
    try { Invoke-HarnessCleanup $fixture -All -ConfirmText 'LIMPAR' | Out-Null } catch { $rejected=$true }
    Assert $rejected 'Limpeza durante MTA/build aceita.'
} finally { $lease.Dispose() }
}
$link = Join-Path $run 'junction'
$null = New-Item -ItemType Junction -Path $link -Target $source
try {
    $rejected=$false
    try { Invoke-HarnessCleanup $fixture -All -ConfirmText 'LIMPAR' | Out-Null } catch { $rejected=$true }
    Assert $rejected 'Junction dentro do historico deveria bloquear toda a limpeza.'
    Assert (Test-Path "$source/pom.xml") 'Limpeza seguiu junction.'
} finally {
    # Remover somente o link de teste, nunca seu destino ou uma arvore calculada.
    [IO.Directory]::Delete($link)
}
Invoke-HarnessCleanup $fixture -Source $source -ConfirmText 'LIMPAR' | Out-Null
Assert (-not (Test-Path -LiteralPath $run) -and -not (Test-Path -LiteralPath $build) -and -not (Test-Path -LiteralPath $planning)) 'Limpeza de projeto incompleta.'
Assert (Test-Path "$fixture/.harness/runs/other/44444444444444444444444444444444/manifest.json") 'Limpeza atingiu outro projeto.'
Assert (Test-Path "$fixture/.harness/runs/old/55555555555555555555555555555555/manifest.json") 'Limpeza atingiu outro Source com mesmo Project.'
foreach ($file in $preservedData) {
    $path = Join-Path $fixture $file
    Assert ((Get-FileHash -LiteralPath $path).Hash -eq ($before | Where-Object Path -EQ $path).Hash) 'Limpeza por projeto alterou registro/evidencias.'
}
Invoke-HarnessCleanup $fixture -All -ConfirmText 'LIMPAR' | Out-Null
Assert ((Get-FileHash $sonarBaseline).Hash -eq $sonarHash) 'Limpeza apagou ou alterou baseline Sonar.'
foreach ($file in $preservedData) {
    $path = Join-Path $fixture $file
    Assert ((Get-FileHash -LiteralPath $path).Hash -eq ($before | Where-Object Path -EQ $path).Hash) 'Limpeza geral alterou registro/evidencias.'
}
foreach ($area in @('runs','builds','planning')) { Assert (-not (Test-Path "$fixture/.harness/$area")) 'Limpeza total incompleta.' }
foreach ($file in @('config/harness.local.json','app/pom.xml','.harness/maven/settings.xml','.harness/workspace-backups/backup.json','.github/prompts/planejar-lotes.prompt.md')) {
    $path = Join-Path $fixture $file
    Assert ((Get-FileHash -LiteralPath $path).Hash -eq ($before | Where-Object Path -EQ $path).Hash) 'Limpeza alterou arquivo protegido.'
}
Assert (@(Get-HarnessCleanupPaths $fixture -All).Count -eq 0) 'Repeticao da limpeza deve ficar vazia.'
Write-Output 'PASS: preview, cancelamento, projeto, todos, bloqueio e preservacao de fontes/config/cache/templates/backups.'

$temporary = Join-Path $fixture '.harness/backups-temporarios'
Write-HarnessJson "$temporary/ensaio/proveniencia.json" @{test=$true}
$longFile = Join-Path $temporary ('ensaio/' + ('x' * 200) + '.class')
[IO.File]::WriteAllText(('\\?\' + $longFile.Replace('/','\')), 'fixture de caminho longo')
$remaining = "$fixture/.harness/runs/other/77777777777777777777777777777777/manifest.json"
Write-HarnessJson $remaining @{Project='other';Source=$other;RunId='77777777777777777777777777777777'}
Assert (@(Get-HarnessCleanupPaths $fixture -All) -notcontains $temporary) 'Limpeza de execucoes passou a incluir backups.'
$preview = @(Get-HarnessCleanupPaths $fixture -TemporaryBackups)
Assert ($preview.Count -eq 1 -and $preview[0] -eq $temporary) 'Preview de temporarios deve conter somente a pasta central.'
$rejected=$false
try { Get-HarnessCleanupPaths $fixture -All -TemporaryBackups | Out-Null } catch { $rejected=$true }
Assert $rejected 'Escopos misturados aceitos.'
Invoke-HarnessCleanup $fixture -TemporaryBackups -ConfirmText 'cancelar' | Out-Null
Assert (Test-Path $temporary) 'Cancelamento apagou backup.'
$link = Join-Path $temporary 'junction'
$null = New-Item -ItemType Junction -Path $link -Target $source
try {
    $rejected=$false
    try { Invoke-HarnessCleanup $fixture -TemporaryBackups -ConfirmText 'LIMPAR' | Out-Null } catch { $rejected=$true }
    Assert $rejected 'Junction em temporarios aceita.'
} finally { [IO.Directory]::Delete($link) }
# Executar o menu real, apontado somente para a fixture; preview nao exclui.
$null = New-Item -ItemType Directory -Path "$fixture/scripts" -Force
foreach ($name in @('Harness.psm1','HarnessCleanup.psm1','limpar-execucoes.ps1')) { Copy-Item -LiteralPath (Join-Path $root "scripts/$name") -Destination "$fixture/scripts/$name" }
$menuOutput = @('3') | & powershell.exe -NoProfile -File "$fixture/scripts/limpar-execucoes.ps1" -Preview 2>&1
Assert ($LASTEXITCODE -eq 0 -and ($menuOutput -join "`n").Contains($temporary)) 'Menu 3 nao selecionou backups temporarios.'
Invoke-HarnessCleanup $fixture -TemporaryBackups -ConfirmText 'LIMPAR' | Out-Null
Assert (-not (Test-Path $temporary)) 'Backup temporario nao removido.'
Assert (Test-Path $remaining) 'Limpeza de backups atingiu execucoes.'
foreach ($file in @('config/harness.local.json','app/pom.xml','.harness/maven/settings.xml','.harness/workspace-backups/backup.json','.github/prompts/planejar-lotes.prompt.md')) {
    $path = Join-Path $fixture $file
    Assert ((Get-FileHash -LiteralPath $path).Hash -eq ($before | Where-Object Path -EQ $path).Hash) 'Limpeza de temporarios alterou arquivo protegido.'
}
Assert (@(Get-HarnessCleanupPaths $fixture -TemporaryBackups).Count -eq 0) 'Preview de temporarios removidos deveria ficar vazio.'
Write-Output 'PASS: backups centralizados, menu 3, cancelamento, junction, isolamento e preservacao de configuracao/cache/workspace.'

# Rodadas externas sao permanentes; somente indices e ponteiros locais sao limpos.
$external = $fixture + '-external'
$null = [IO.Directory]::CreateDirectory($external)
$sentinel = Join-Path $external 'arquivo-do-desenvolvedor.txt'
Set-Content -LiteralPath $sentinel 'preservar'
foreach ($id in @('aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa','bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb')) {
    $index = Join-Path $fixture ('.harness/runs/external/' + $id)
    $externalRun = Join-Path $external ('p__' + (Get-HarnessProjectKey 'external') + '/' + $id)
    $location = @{Project='external'; Source=$source; RunId=$id; RunsPath=$external}
    if ($id.StartsWith('b')) {
        $location.RunRelativePath = 'external/260930-151210'
        $externalRun = Join-Path $external $location.RunRelativePath
        Write-HarnessJson (Join-Path $external 'external/project.json') @{Project='external'; Source=$source}
    }
    Write-HarnessJson (Join-Path $externalRun 'manifest.json') @{Project='external'; Source=$source; RunId=$id; IndexPath=$index}
    Write-HarnessJson (Join-Path $externalRun 'output/resultado.json') @{preservar='MTA'}
    Write-HarnessJson (Join-Path $index 'location.json') $location
    Write-HarnessJson "$fixture/.harness/last-external.json" @{RunId=$id}
    $externalBefore = @(Get-ChildItem -LiteralPath $external -Recurse -File | Get-FileHash)
    $preview = @(Get-HarnessCleanupPaths $fixture -Source $source)
    Assert ($preview -notcontains $externalRun -and $preview -contains $index -and $preview -notcontains $external) 'Preview deve incluir somente indice local, nunca rodada externa.'
    Assert (@($preview | Where-Object { -not $_.StartsWith((Join-Path $fixture '.harness') + '\') }).Count -eq 0) 'Preview saiu de .harness.'
    Invoke-HarnessCleanup $fixture -Source $source -ConfirmText 'cancelar' | Out-Null
    Assert (Test-Path $externalRun) 'Cancelamento removeu rodada externa.'
    $locationPath = Join-Path $index 'location.json'
    $location.Source = $other
    Write-HarnessJson $locationPath $location
    Assert (@(Get-HarnessCleanupPaths $fixture -Source $source) -notcontains $index) 'Indice local de outro Source foi selecionado.'
    $location.Source = $source
    Write-HarnessJson $locationPath $location
    if ($location.ContainsKey('RunRelativePath')) {
        $location.RunRelativePath = '../external/260930-151210'
        Write-HarnessJson $locationPath $location
        Assert (@(Get-HarnessCleanupPaths $fixture -Source $source) -contains $index) 'Limpeza local tentou resolver RunRelativePath externo.'
    }
    $link = Join-Path $externalRun 'junction'
    $null = New-Item -ItemType Junction -Path $link -Target $source
    try {
        if ($id.StartsWith('a')) { Invoke-HarnessCleanup $fixture -Source $source -ConfirmText 'LIMPAR' | Out-Null }
        else { Invoke-HarnessCleanup $fixture -All -ConfirmText 'LIMPAR' | Out-Null }
        Assert (Test-Path -LiteralPath $link) 'Limpeza alterou link dentro da rodada externa.'
    } finally { [IO.Directory]::Delete($link) }
    Assert ((Test-Path $externalRun) -and -not (Test-Path $index)) 'Limpeza deve remover indice e preservar rodada externa.'
    Assert (-not (Test-Path "$fixture/.harness/last-external.json")) 'Ponteiro local externo nao removido.'
    $externalAfter = @(Get-ChildItem -LiteralPath $external -Recurse -File | Get-FileHash)
    Assert ($externalAfter.Count -eq $externalBefore.Count) 'Limpeza alterou quantidade de arquivos externos.'
    foreach ($file in $externalBefore) { Assert ((Get-FileHash -LiteralPath $file.Path).Hash -eq $file.Hash) 'Limpeza alterou conteudo MTA externo.' }
    Assert (Test-Path $sentinel) 'Limpeza atingiu arquivo externo nao registrado.'
    if ($id.StartsWith('b')) { Assert (Test-Path (Join-Path $external 'external/project.json')) 'Limpeza removeu identidade do projeto.' }
}
$missingIndex = Join-Path $fixture '.harness/runs/missing/cccccccccccccccccccccccccccccccc'
Write-HarnessJson "$missingIndex/location.json" @{Project='missing'; Source=$source; RunId='cccccccccccccccccccccccccccccccc'; RunsPath='Z:/mta-indisponivel'}
Invoke-HarnessCleanup $fixture -Source $source -ConfirmText 'LIMPAR' | Out-Null
Assert (-not (Test-Path $missingIndex)) 'Limpeza local exigiu armazenamento externo disponivel.'
Write-Output 'PASS: indices locais por projeto/todos; MTA externo intacto e independente da limpeza.'
