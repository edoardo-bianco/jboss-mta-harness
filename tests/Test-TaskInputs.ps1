#requires -Version 5.1
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
function Assert($condition, $message) { if (-not $condition) { throw $message } }
$tasks = Get-Content -LiteralPath (Join-Path $root '.vscode/tasks.json') -Raw | ConvertFrom-Json
$labels = @($tasks.tasks | ForEach-Object { $_.label })
Assert ($labels.Count -eq 24 -and @($labels | Sort-Object -Unique).Count -eq 24) 'Manter 24 tarefas distintas, incluindo priorizacao multi-projeto.'
$serverLabels=@('Servidor: iniciar JBoss','Servidor: parar JBoss','Servidor: consultar estado JBoss','Servidor: criar usuario JBoss')
foreach ($label in $serverLabels) {
    $task=@($tasks.tasks | Where-Object label -eq $label)
    Assert ($task.Count -eq 1 -and $task[0].args -contains '${workspaceFolder}/scripts/gerenciar-jboss.ps1') 'Falta tarefa de servidor JBoss.'
    Assert ($task[0].args -notcontains '-SelectTarget' -and $task[0].args -notcontains '-WorkspacePath' -and -not ($task[0].args | Where-Object { $_ -like '${input:*}' })) 'Servidor nao deve solicitar workspace/projeto.'
}
foreach ($action in @('Deploy','Rollback')) {
    $task=@($tasks.tasks | Where-Object { $_.label -eq ('Aplicacao: ' + $action.ToLowerInvariant() + ' no JBoss') })
    Assert ($task.Count -eq 1 -and $task[0].args -contains $action) 'Release deve ter tarefa com acao explicita.'
}
$indexTask = @($tasks.tasks | Where-Object label -eq 'Workspace: atualizar indice dos projetos')
Assert ($indexTask.Count -eq 1 -and $indexTask[0].args -contains '${workspaceFolder}/scripts/atualizar-indice-projetos.ps1' -and $indexTask[0].args -contains '${input:harnessWorkspacePath}' -and $indexTask[0].args -notcontains '-SelectTarget') 'Indice deve abranger workspace sem selecao de alvo.'
$implementationTask = @($tasks.tasks | Where-Object label -eq 'Aplicacao: preparar implementacao do lote')
Assert ($implementationTask.Count -eq 1 -and $implementationTask[0].args -contains '${workspaceFolder}/scripts/preparar-implementacao.ps1' -and $implementationTask[0].args -contains '${execPath}') 'Implementacao deve ter tarefa unica que abre prompt no editor.'
$sonarTask = @($tasks.tasks | Where-Object label -eq 'Aplicacao: analisar SonarQube')
Assert ($sonarTask.Count -eq 1 -and $sonarTask[0].args -contains '${workspaceFolder}/scripts/analisar-sonar.ps1' -and -not (($sonarTask[0].args -join ' ') -match '(?i)token')) 'Sonar deve ter tarefa unica, sem token nos argumentos.'
Assert ($labels -contains 'Workspace: limpar execucoes' -and $labels -notcontains 'Planejamento: conferir Git do lote') 'Limpeza deve permanecer; controle Git deve sair do catalogo.'
Assert (@($labels | Where-Object { $_ -cnotmatch '^(Workspace|Aplicacao|Servidor|MTA|Planejamento): ' }).Count -eq 0) 'Run Tasks devem ser classificadas pelo prefixo da etapa.'
$prioritization = @($tasks.tasks | Where-Object label -eq 'Planejamento: priorizar issues')
Assert ($prioritization.Count -eq 1 -and $prioritization[0].args -contains '${workspaceFolder}/scripts/preparar-priorizacao.ps1' -and $prioritization[0].args -contains '${input:harnessWorkspacePath}' -and $prioritization[0].args -contains '${execPath}' -and $prioritization[0].args -notcontains '-SelectTarget') 'Priorizacao deve usar o workspace inteiro e abrir prompt.'
Assert ($prioritization[0].args -contains '-Interactive' -and $prioritization[0].args -notcontains '-SelectTop') 'Priorizacao deve oferecer percentual e recriar/progredir na mesma tarefa.'
$projectTasks = @($tasks.tasks | Where-Object { ($_.label -like 'MTA:*' -or $_.label -like 'Aplicacao:*' -or $_.label -like 'Planejamento:*') -and $_.label -notlike 'MTA: acompanhar*' -and $_.label -notin $serverLabels -and $_.label -notin @('Planejamento: priorizar issues','Planejamento: planejar') })
foreach ($monitor in @($tasks.tasks | Where-Object label -like 'MTA: acompanhar*')) {
    Assert ($monitor.args -contains '-Active' -and $monitor.args -notcontains '-SelectTarget' -and -not ($monitor.args | Where-Object { $_ -like '${input:*}' })) 'Observabilidade nao deve solicitar workspace/projeto.'
}
foreach ($task in $tasks.tasks) {
    Assert ($task.args -notcontains '${workspaceFile}') 'Regressao: workspaceFile nao e uma variavel suportada em tasks.json.'
}
$workspaceInput = @($tasks.inputs | Where-Object id -eq 'harnessWorkspacePath')
Assert ($workspaceInput.Count -eq 1 -and $workspaceInput[0].type -eq 'promptString') 'Falta entrada nativa para o arquivo de workspace.'
foreach ($task in $projectTasks) {
    Assert ($task.args -contains '${input:harnessWorkspacePath}' -and $task.args -contains '-SelectTarget') 'Tarefa de projeto sem workspace/selecao.'
}
$automatic = @($tasks.tasks | Where-Object label -eq 'Workspace: conferir configuracao ao abrir')[0]
$planning = @($tasks.tasks | Where-Object label -eq 'Planejamento: planejar')
Assert ($planning.Count -eq 1 -and $planning[0].args -contains '-EditorPath' -and $planning[0].args -contains '${execPath}') 'Planejamento deve abrir o prompt no editor da tarefa.'
Assert ($planning[0].args -contains '${workspaceFolder}/scripts/preparar-planejamento.ps1' -and $planning[0].args -contains '-WorkspacePath' -and $planning[0].args -contains '${input:harnessWorkspacePath}') 'Planejar deve receber o workspace para localizar o registro.'
Assert ($planning[0].args -notcontains '-SelectOperation' -and $planning[0].args -notcontains '-SelectTarget' -and $planning[0].args -notcontains '-RunId' -and $planning[0].args -notcontains '-RunPath') 'Planejar nao deve repetir menus de operacao/projeto/rodada ou fixar MTA.'
Assert ($labels -notcontains 'Planejamento: preparar contexto para Copilot' -and @($labels | Where-Object { $_ -match '(?i)replanejar|reconciliar' }).Count -eq 0) 'Entrada habitual unica nao deve deixar menus redundantes no catalogo.'
$openPlanning = @($tasks.tasks | Where-Object label -eq 'Planejamento: abrir plano e to-do')
$evidenceTask = @($tasks.tasks | Where-Object label -eq 'Planejamento: criar pasta de evidencias')
Assert ($evidenceTask.Count -eq 1 -and $evidenceTask[0].args -contains '${workspaceFolder}/scripts/criar-pasta-evidencias.ps1' -and $evidenceTask[0].args -contains '${execPath}') 'Falta tarefa para criar evidencias e abrir indice.'
Assert ($openPlanning.Count -eq 1 -and $openPlanning[0].args -contains '${workspaceFolder}/scripts/abrir-planejamento.ps1' -and $openPlanning[0].args -contains '${execPath}') 'Falta tarefa para abrir plano e to-do no editor.'
Assert (-not ($automatic.args | Where-Object { $_ -like '${input:*}' })) 'Tarefa automatica nao deve abrir prompts de entrada.'

# Executar a entrada real do build com argumentos da tarefa e caminhos com espacos.
# Cancelar no menu: nenhum Maven ou MTA deve ser iniciado neste teste.
$area = Join-Path $root ('.harness/tests/task inputs ' + [guid]::NewGuid().ToString('N'))
$fixture = Join-Path $area 'fixture'
$project = Join-Path $area 'aplicacao externa'
$workspacePath = Join-Path $area 'workspace com espacos.code-workspace'
$null = New-Item -ItemType Directory -Path $fixture -Force
$null = New-Item -ItemType Directory -Path $project -Force
Set-Content (Join-Path $project 'pom.xml') '<project/>'
Copy-Item -LiteralPath (Join-Path $root 'scripts') -Destination $fixture -Recurse
@{folders=@(@{name='Projeto do workspace'; path=$project})} | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $workspacePath -Encoding UTF8
$config = Get-Content -LiteralPath (Join-Path $root 'config/harness.example.json') -Raw | ConvertFrom-Json
$config.repositories = @()
$config.activeProject = $null
$configPath = Join-Path $fixture 'config.json'
$config | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $configPath -Encoding UTF8
$originalConfig = (Get-FileHash $configPath).Hash
$originalWorkspace = (Get-FileHash $workspacePath).Hash
$buildTask = @($projectTasks | Where-Object label -eq 'Aplicacao: build Maven (Java 8)')[0]
$arguments = @($buildTask.args | ForEach-Object {
    $_.Replace('${workspaceFolder}', $fixture).Replace('${input:harnessWorkspacePath}', $workspacePath).Replace('${input:applicationBuildGoals}', 'clean install')
})
Assert (-not ($arguments | Where-Object { $_.Contains('${') })) 'Variavel nao resolvida enviada ao PowerShell.'
$arguments += @('-ConfigPath', $configPath)
$output = 'q' | & powershell.exe @arguments 2>&1 | Out-String
Assert ($LASTEXITCODE -eq 1 -and $output.Contains('Projeto do workspace') -and $output.Contains('Selecao cancelada')) 'A tarefa nao chegou ao menu do workspace informado.'
Assert (-not $output.Contains('Caminho invalido') -and -not $output.Contains('Comando: mvn')) 'Workspace invalido ou build iniciado apos cancelamento.'
Assert ((Get-FileHash $configPath).Hash -eq $originalConfig -and (Get-FileHash $workspacePath).Hash -eq $originalWorkspace) 'Tarefa alterou configuracao/workspace.'
$sonarArguments = @($sonarTask[0].args | ForEach-Object {
    $_.Replace('${workspaceFolder}', $fixture).Replace('${input:harnessWorkspacePath}', $workspacePath)
})
$sonarArguments += @('-ConfigPath', $configPath)
$output = 'q' | & powershell.exe @sonarArguments 2>&1 | Out-String
Assert ($LASTEXITCODE -eq 1 -and $output.Contains('Selecao cancelada') -and -not $output.Contains('Token Sonar')) 'Cancelamento Sonar deve preceder pedido de token e envio.'
$implementationArguments = @($implementationTask[0].args | ForEach-Object {
    $_.Replace('${workspaceFolder}', $fixture).Replace('${input:harnessWorkspacePath}', $workspacePath).Replace('${execPath}', (Join-Path $fixture 'editor-ausente.exe'))
})
$implementationArguments += @('-ConfigPath', $configPath)
$output = 'q' | & powershell.exe @implementationArguments 2>&1 | Out-String
Assert ($LASTEXITCODE -eq 1 -and $output.Contains('Selecao cancelada') -and -not $output.Contains('Prompt preparado:')) 'Cancelamento da task de implementacao deve preceder preparo/editor.'
Write-Output 'PASS: variaveis de tarefa suportadas, workspace com espacos, entrada real do build e cancelamento sem execucao.'
