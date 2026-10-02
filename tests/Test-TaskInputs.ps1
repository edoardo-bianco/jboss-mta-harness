#requires -Version 5.1
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
function Assert($condition, $message) { if (-not $condition) { throw $message } }
$tasks = Get-Content -LiteralPath (Join-Path $root '.vscode/tasks.json') -Raw | ConvertFrom-Json
$labels = @($tasks.tasks | ForEach-Object { $_.label })
Assert ($labels.Count -eq 17 -and @($labels | Sort-Object -Unique).Count -eq 17) 'Manter 17 tarefas distintas, incluindo indice dos projetos.'
$indexTask = @($tasks.tasks | Where-Object label -eq 'Workspace: atualizar indice dos projetos')
Assert ($indexTask.Count -eq 1 -and $indexTask[0].args -contains '${workspaceFolder}/scripts/atualizar-indice-projetos.ps1' -and $indexTask[0].args -contains '${input:harnessWorkspacePath}' -and $indexTask[0].args -notcontains '-SelectTarget') 'Indice deve abranger workspace sem selecao de alvo.'
$implementationTask = @($tasks.tasks | Where-Object label -eq 'Aplicacao: preparar implementacao do lote')
Assert ($implementationTask.Count -eq 1 -and $implementationTask[0].args -contains '${workspaceFolder}/scripts/preparar-implementacao.ps1' -and $implementationTask[0].args -contains '${execPath}') 'Implementacao deve ter tarefa unica que abre prompt no editor.'
$sonarTask = @($tasks.tasks | Where-Object label -eq 'Aplicacao: analisar SonarQube')
Assert ($sonarTask.Count -eq 1 -and $sonarTask[0].args -contains '${workspaceFolder}/scripts/analisar-sonar.ps1' -and -not (($sonarTask[0].args -join ' ') -match '(?i)token')) 'Sonar deve ter tarefa unica, sem token nos argumentos.'
Assert ($labels -contains 'Workspace: limpar execucoes' -and $labels -notcontains 'Planejamento: conferir Git do lote') 'Limpeza deve permanecer; controle Git deve sair do catalogo.'
Assert (@($labels | Where-Object { $_ -cnotmatch '^(Workspace|Aplicacao|MTA|Planejamento): ' }).Count -eq 0) 'Run Tasks devem ser classificadas pelo prefixo da etapa.'
$projectTasks = @($tasks.tasks | Where-Object { ($_.label -like 'MTA:*' -or $_.label -like 'Aplicacao:*' -or $_.label -like 'Planejamento:*') -and $_.label -notlike 'MTA: acompanhar*' })
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
$planning = @($tasks.tasks | Where-Object label -eq 'Planejamento: preparar contexto para Copilot')
Assert ($planning.Count -eq 1 -and $planning[0].args -contains '-EditorPath' -and $planning[0].args -contains '${execPath}') 'Planejamento deve abrir o prompt no editor da tarefa.'
Assert ($planning[0].args -contains '-SelectOperation') 'Task deve oferecer planejamento ou revisao explicitamente.'
$openPlanning = @($tasks.tasks | Where-Object label -eq 'Planejamento: abrir plano e to-do')
$evidenceTask = @($tasks.tasks | Where-Object label -eq 'Planejamento: criar pasta de evidencias')
Assert ($evidenceTask.Count -eq 1 -and $evidenceTask[0].args -contains '${workspaceFolder}/scripts/criar-pasta-evidencias.ps1' -and $evidenceTask[0].args -contains '${execPath}') 'Falta tarefa para criar evidencias e abrir indice.'
Assert ($openPlanning.Count -eq 1 -and $openPlanning[0].args -contains '${workspaceFolder}/scripts/abrir-planejamento.ps1' -and $openPlanning[0].args -contains '${execPath}') 'Falta tarefa para abrir plano e to-do no editor.'
Assert (-not ($automatic.args | Where-Object { $_ -like '${input:*}' })) 'Tarefa automatica nao deve abrir prompts de entrada.'

# Executar a entrada real do build com argumentos da tarefa e caminhos com espacos.
# Cancelar no menu: nenhum Maven ou MTA deve ser iniciado neste teste.
$area = Join-Path $root ('.harness/tests/task inputs ' + [guid]::NewGuid().ToString('N'))
$fixture = Join-Path $area 'fixture'
$project = Join-Path $root 'exemplos/migracao-cache-antes'
$workspacePath = Join-Path $area 'workspace com espacos.code-workspace'
$null = New-Item -ItemType Directory -Path $fixture -Force
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
    $_.Replace('${workspaceFolder}', $root).Replace('${input:harnessWorkspacePath}', $workspacePath).Replace('${input:applicationBuildGoals}', 'clean install')
})
Assert (-not ($arguments | Where-Object { $_.Contains('${') })) 'Variavel nao resolvida enviada ao PowerShell.'
$arguments += @('-ConfigPath', $configPath)
$output = 'q' | & powershell.exe @arguments 2>&1 | Out-String
Assert ($LASTEXITCODE -eq 1 -and $output.Contains('Projeto do workspace') -and $output.Contains('Selecao cancelada')) 'A tarefa nao chegou ao menu do workspace informado.'
Assert (-not $output.Contains('Caminho invalido') -and -not $output.Contains('Comando: mvn')) 'Workspace invalido ou build iniciado apos cancelamento.'
Assert ((Get-FileHash $configPath).Hash -eq $originalConfig -and (Get-FileHash $workspacePath).Hash -eq $originalWorkspace) 'Tarefa alterou configuracao/workspace.'
$sonarArguments = @($sonarTask[0].args | ForEach-Object {
    $_.Replace('${workspaceFolder}', $root).Replace('${input:harnessWorkspacePath}', $workspacePath)
})
$sonarArguments += @('-ConfigPath', $configPath)
$output = 'q' | & powershell.exe @sonarArguments 2>&1 | Out-String
Assert ($LASTEXITCODE -eq 1 -and $output.Contains('Selecao cancelada') -and -not $output.Contains('Token Sonar')) 'Cancelamento Sonar deve preceder pedido de token e envio.'
$implementationArguments = @($implementationTask[0].args | ForEach-Object {
    $_.Replace('${workspaceFolder}', $root).Replace('${input:harnessWorkspacePath}', $workspacePath).Replace('${execPath}', (Join-Path $fixture 'editor-ausente.exe'))
})
$implementationArguments += @('-ConfigPath', $configPath)
$output = 'q' | & powershell.exe @implementationArguments 2>&1 | Out-String
Assert ($LASTEXITCODE -eq 1 -and $output.Contains('Selecao cancelada') -and -not $output.Contains('Prompt preparado:')) 'Cancelamento da task de implementacao deve preceder preparo/editor.'
Write-Output 'PASS: variaveis de tarefa suportadas, workspace com espacos, entrada real do build e cancelamento sem execucao.'
