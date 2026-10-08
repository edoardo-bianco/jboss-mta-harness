#requires -Version 5.1
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $root 'scripts/Harness.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $root 'scripts/HarnessPlanning.psm1') -Force -DisableNameChecking
function Assert($condition, $message) { if (-not $condition) { throw $message } }
$tasks = Get-Content (Join-Path $root '.vscode/tasks.json') -Raw | ConvertFrom-Json
$task = @($tasks.tasks | Where-Object label -eq 'Planejamento: atualizar registro de migracao')
Assert ($task.Count -eq 1) 'Falta Run Task para adotar novo MTA no registro.'
Assert ($task[0].args -contains '-SelectMigrationInput' -and $task[0].args -contains 'manter-migracao') 'Tarefa deve reutilizar manter-migracao com selecao e confirmacao.'
$area = Join-Path $root ('.harness/tests/adocao ' + [guid]::NewGuid().ToString('N').Substring(0,8))
$fixture = Join-Path $area 'h'
$app = Join-Path $area 'fonte local'
$other = Join-Path $area 'outro projeto'
foreach ($path in @($app,$other,$fixture)) { $null = [IO.Directory]::CreateDirectory($path) }
foreach ($path in @($app,$other)) { Set-Content (Join-Path $path 'pom.xml') '<project />' }
Copy-Item -LiteralPath (Join-Path $root 'scripts') -Destination $fixture -Recurse
foreach ($file in @('doc/especificacoes/planejamento-copilot.md','.github/prompts/manter-migracao.prompt.md')) {
    $targetFile = Join-Path $fixture $file
    $null = [IO.Directory]::CreateDirectory((Split-Path $targetFile -Parent))
    Copy-Item -LiteralPath (Join-Path $root $file) -Destination $targetFile
}
$config = Get-Content (Join-Path $root 'config/harness.example.json') -Raw | ConvertFrom-Json
$config.repositories = @(); $config.activeProject = $null
$configPath = Join-Path $fixture 'config.json'
$workspacePath = Join-Path $area 'projetos.code-workspace'
Write-HarnessJson $configPath $config
Write-HarnessJson $workspacePath @{folders=@(@{name='Aplicacao';path=$app},@{name='Outra';path=$other})}
$context = Read-HarnessConfig $configPath $fixture -WorkspacePath $workspacePath -Target $app -SkipMigrationInitialization
function New-Run($path, $id, $project, $source, $ruleIds) {
    Write-HarnessJson (Join-Path $path 'manifest.json') @{Project=$project;Source=$source;RunId=$id;CreatedAtUtc='2026-10-08T10:00:00Z'}
    Write-HarnessJson (Join-Path $path 'result.json') @{Project=$project;RunId=$id;Status='SUCCEEDED';ExitCode=0;SourceUnchanged=$true;SnapshotOriginalFilesUnchanged=$true;RulesUnchanged=$true;UnexpectedAddedFiles=@()}
    foreach ($file in @('input/pom.xml','rules/regra.yaml','output/output.yaml','output/dependencies.yaml','output/static-report/index.html')) {
        $targetFile = Join-Path $path $file
        $null = [IO.Directory]::CreateDirectory((Split-Path $targetFile -Parent))
        Set-Content -LiteralPath $targetFile 'fixture'
    }
    $rules = [ordered]@{}
    foreach ($idRule in $ruleIds) { $rules[$idRule] = @{description=$idRule;category='mandatory';incidents=@(@{message='ocorrencia'})} }
    $json = ConvertTo-Json -InputObject @(@{rulesets=@(@{name='java';violations=$rules})}) -Depth 10 -Compress
    Set-Content (Join-Path $path 'output/static-report/output.js') ('window["apps"] = ' + $json)
}
$oldId = '11111111111111111111111111111111'
$localId = '22222222222222222222222222222222'
$receivedId = '33333333333333333333333333333333'
$oldRun = Join-Path $area 'mta anterior'
$localRun = Join-Path $fixture ('.harness/runs/' + $context.Active.name + '/' + $localId)
$receivedRun = Join-Path $area 'mta colega'
New-Run $oldRun $oldId $context.Active.name $app @('mantida','ausente')
New-Run $localRun $localId $context.Active.name $app @('mantida','nova')
New-Run $receivedRun $receivedId 'app-no-colega' 'Z:\equipe\app' @('mantida','colega')
$arguments = @($task[0].args | ForEach-Object {
    $_.Replace('${workspaceFolder}',$fixture).Replace('${input:harnessWorkspacePath}',$workspacePath).Replace('${execPath}',(Join-Path $fixture 'editor-ausente.exe'))
}) + @('-ConfigPath',$configPath,'-NoOpen')
function Invoke-Task([string[]]$answers) {
    $output = $answers | & powershell.exe @arguments 2>&1 | Out-String
    [pscustomobject]@{Code=$LASTEXITCODE;Text=$output}
}
function Get-State {
    @(Get-ChildItem -LiteralPath $area -Recurse -File | Sort-Object FullName | ForEach-Object {
        $_.FullName + ':' + (Get-FileHash -LiteralPath $_.FullName).Hash
    }) -join "`n"
}
$before = Get-State
$result = Invoke-Task @('1')
Assert ($result.Code -ne 0 -and $result.Text.Contains('Workspace: atualizar indice dos projetos')) 'Registro ausente deve orientar indice, sem inicializar implicitamente.'
Assert ((Get-State) -ceq $before) 'Registro ausente gravou arquivos.'
$selected = Get-MtaPlanningRunFromPath $oldRun $fixture
$register = Update-HarnessMigration $context $selected
$human = [IO.File]::ReadAllText($register.MigrationPath).Replace('| A DEFINIR | NAO ANALISADA |','| ADIAR | ANALISADA |')
$human = $human.Replace('<!-- mta:fim -->',"| DEV-001 | Manual | humana | 1 | MANUAL | ANALISAR AGORA | PLANEJADA | plano existente |`n<!-- mta:fim -->")
$human += "`nNota humana preservada.`n"
[IO.File]::WriteAllText($register.MigrationPath,$human)
$prior = New-MtaMigrationPrompt $context
$priorHash = (Get-FileHash $prior.ContextPath).Hash
foreach ($answers in @(@('q'),@('1','q'),@('1','h','1','q'),@('1','p',$receivedRun,''))) {
    $before = Get-State
    $result = Invoke-Task $answers
    Assert ($result.Code -ne 0 -and -not $result.Text.Contains('Prompt preparado:')) 'Cancelar deve parar antes de gravar/abrir prompt.'
    Assert ((Get-State) -ceq $before) 'Cancelamento alterou registro, evidencias ou contexto.'
}
# Simular uma edicao concorrente exatamente enquanto Read-Host aguarda ADOTAR.
# O restante da entrada e do preparo continua real; somente a resposta humana e controlada.
$driver = Join-Path $area 'mutar-origem.ps1'
$manifestPath = Join-Path $localRun 'manifest.json'
$manifestBefore = [IO.File]::ReadAllText($manifestPath)
$driverText = @'
$global:MigrationTestAnswers = New-Object 'Collections.Generic.Queue[string]'
@('1','h','1','ADOTAR') | ForEach-Object { $global:MigrationTestAnswers.Enqueue($_) }
function global:Read-Host {
    param($Prompt)
    if ($Prompt -like '*Digite ADOTAR*') {
        $path = '{MANIFEST}'
        $manifest = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
        $manifest.Source = 'Z:\origem-nao-confirmada'
        $manifest | ConvertTo-Json | Set-Content -LiteralPath $path -Encoding UTF8
    }
    $global:MigrationTestAnswers.Dequeue()
}
& '{ENTRY}' -ConfigPath '{CONFIG}' -WorkspacePath '{WORKSPACE}' -Operation manter-migracao -SelectMigrationInput -SelectTarget -NoOpen
exit $LASTEXITCODE
'@
$driverText = $driverText.Replace('{MANIFEST}',$manifestPath.Replace("'","''")).Replace('{ENTRY}',(Join-Path $fixture 'scripts/preparar-planejamento.ps1').Replace("'","''")).Replace('{CONFIG}',$configPath.Replace("'","''")).Replace('{WORKSPACE}',$workspacePath.Replace("'","''"))
[IO.File]::WriteAllText($driver,$driverText)
$before = Get-State
$raceOutput = & powershell.exe -NoProfile -File $driver 2>&1 | Out-String
$raceCode = $LASTEXITCODE
[IO.File]::WriteAllText($manifestPath,$manifestBefore,(New-Object Text.UTF8Encoding($false)))
Assert ($raceCode -ne 0 -and $raceOutput.Contains('mudou durante a confirmacao')) ('Adotou origem diferente da previa: ' + $raceOutput)
Assert ((Get-State) -ceq $before) 'Mudanca concorrente de origem gravou registro/contexto.'
$original = [IO.File]::ReadAllText($register.MigrationPath)
$result = Invoke-Task @('1','h','1','ADOTAR')
Assert ($result.Code -eq 0) ('Adocao local falhou: ' + $result.Text)
Assert ($result.Text.Contains($oldId) -and $result.Text.Contains($localId) -and $result.Text.Contains($app)) 'Previa deve mostrar as duas rodadas e o destino local.'
$current = Read-HarnessMigrationInput $fixture $context.Active
Assert ($current.Origin.RunId -eq $localId) 'Rodada local nao adotada.'
Assert ($current.Text.Contains('| NAO REENCONTRADA | ADIAR | ANALISADA |') -and $current.Text.Contains('| DEV-001 |') -and $current.Text.Contains('Nota humana preservada.')) 'Troca perdeu escolhas/linha manual ou inferiu resolucao.'
$receiptPath = [regex]::Match($result.Text,'Recibo de contexto: ([^\r\n]+)').Groups[1].Value.Trim()
$receipt = Get-Content -LiteralPath $receiptPath -Raw | ConvertFrom-Json
Assert ($receipt.PreviousMigration.Snapshot -ceq $original -and $receipt.PreviousMigration.Origin.RunId -eq $oldId -and $receipt.PreviousMigration.Sha256) 'Recibo nao preservou o registro e a origem antes da carga.'
Assert ((Get-FileHash $prior.ContextPath).Hash -eq $priorHash) 'Contexto anterior foi reescrito.'
$before = Get-State
$result = Invoke-Task @('1','p',(Join-Path $area 'ausente'),'ADOTAR')
Assert ($result.Code -ne 0 -and (Get-State) -ceq $before) 'Pasta invalida alterou estado.'
$catalogPath = Join-Path $receivedRun 'output/static-report/output.js'
$catalogBefore = [IO.File]::ReadAllText($catalogPath)
Set-Content -LiteralPath $catalogPath 'window["apps"] = [{"rulesets":null}];'
$before = Get-State
$result = Invoke-Task @('1','p',$receivedRun,'ADOTAR')
Assert ($result.Code -ne 0 -and (Get-State) -ceq $before) 'Catalogo invalido alterou estado.'
[IO.File]::WriteAllText($catalogPath,$catalogBefore)
$badRun = Join-Path $area 'mta incompleto'
New-Run $badRun ('4'*32) 'app-colega' 'Z:\app' @('nova')
Rename-Item -LiteralPath (Join-Path $badRun 'input') -NewName 'snapshot-ausente'
$before = Get-State
$result = Invoke-Task @('1','p',$badRun,'ADOTAR')
Assert ($result.Code -ne 0 -and (Get-State) -ceq $before) 'MTA sem input foi adotado.'
$original = [IO.File]::ReadAllText($register.MigrationPath)
$result = Invoke-Task @('1','p',('"' + $receivedRun + '"'),'ADOTAR')
Assert ($result.Code -eq 0) ('Adocao recebida falhou: ' + $result.Text)
$current = Read-HarnessMigrationInput $fixture $context.Active
Assert ($current.Origin.RunId -eq $receivedId -and $current.Origin.Source -eq 'Z:\equipe\app' -and $current.Origin.Project -eq 'app-no-colega') 'Origem recebida foi substituida pela identidade local.'
Assert ($result.Text.Contains('Z:\equipe\app') -and $result.Text.Contains($localId)) 'Previa recebida nao mostrou origem historica.'
$receiptPath = [regex]::Match($result.Text,'Recibo de contexto: ([^\r\n]+)').Groups[1].Value.Trim()
$receipt = Get-Content -LiteralPath $receiptPath -Raw | ConvertFrom-Json
Assert ($receipt.Source -eq $app -and $receipt.PreviousMigration.Snapshot -ceq $original) 'Associacao ao Source local ou historico incorretos.'
Assert (-not (Test-Path (Get-HarnessMigrationPaths $fixture $context.Projects[1]).MigrationPath)) 'Tarefa criou registro para outro projeto.'
Assert (@(Get-ChildItem -LiteralPath $fixture -Recurse -File | Where-Object Name -match '^(plan|todo)\.md$').Count -eq 0) 'Manutencao criou plano/to-do.'
Write-Output 'PASS: tarefa real PS5.1, previa, cancelamento, MTA local/recebido e preservacao de escolhas/origens.'
