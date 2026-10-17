#requires -Version 5.1
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
function Assert($condition, $message) { if (-not $condition) { throw $message } }
$tasks = Get-Content -LiteralPath (Join-Path $root '.vscode/tasks.json') -Raw | ConvertFrom-Json
$labels = @($tasks.tasks | ForEach-Object { $_.label })
Assert ($labels.Count -eq 24 -and @($labels | Sort-Object -Unique).Count -eq 24) 'Manter 24 tarefas distintas (rollback retirado), incluindo planejamento macro de sprints e conciliacao pela entrada habitual.'
$serverLabels=@('Servidor: iniciar JBoss','Servidor: parar JBoss','Servidor: consultar estado JBoss','Servidor: criar usuario JBoss')
foreach ($label in $serverLabels) {
    $task=@($tasks.tasks | Where-Object label -eq $label)
    Assert ($task.Count -eq 1 -and $task[0].args -contains '${workspaceFolder}/scripts/gerenciar-jboss.ps1') 'Falta tarefa de servidor JBoss.'
    Assert ($task[0].args -notcontains '-SelectTarget' -and $task[0].args -notcontains '-WorkspacePath' -and -not ($task[0].args | Where-Object { $_ -like '${input:*}' })) 'Servidor nao deve solicitar workspace/projeto.'
}
$deployTask=@($tasks.tasks | Where-Object label -eq 'Aplicacao: deploy no JBoss')
Assert ($deployTask.Count -eq 1 -and $deployTask[0].args -contains 'Deploy') 'Deploy deve ter tarefa com acao explicita.'
Assert (@($tasks.tasks | Where-Object label -eq 'Aplicacao: rollback no JBoss').Count -eq 0) 'Rollback gerenciado foi retirado; reverter e fazer deploy de outro WAR.'
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
$sharing=@($tasks.tasks | Where-Object label -eq 'Planejamento: compartilhar contexto')
Assert ($sharing.Count -eq 0) 'Copia/conciliacao corrente substitui a tarefa de pacotes.'
$sprints=@($tasks.tasks | Where-Object label -eq 'Planejamento: planejar sprints')
Assert ($sprints.Count -eq 1 -and $sprints[0].args -contains '${workspaceFolder}/scripts/preparar-sprints.ps1' -and $sprints[0].args -contains '-Interactive' -and $sprints[0].args -contains '${execPath}' -and $sprints[0].args -notcontains '-SelectTarget') 'Sprints deve ter tarefa unica com escolha de escopo antes do prompt.'
$projectTasks = @($tasks.tasks | Where-Object { ($_.label -like 'MTA:*' -or $_.label -like 'Aplicacao:*' -or $_.label -like 'Planejamento:*') -and $_.label -notlike 'MTA: acompanhar*' -and $_.label -notin $serverLabels -and $_.label -notin @('Planejamento: priorizar issues','Planejamento: planejar','Planejamento: planejar sprints') })
foreach ($monitor in @($tasks.tasks | Where-Object label -like 'MTA: acompanhar*')) {
    Assert ($monitor.args -notcontains '-Active' -and $monitor.args -contains '-SelectTarget' -and $monitor.args -contains '${input:harnessWorkspacePath}') 'Log corrente deve selecionar o projeto do workspace, sem ponteiro global.'
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
Set-Content (Join-Path $project 'pom.xml') '<project><artifactId>app</artifactId></project>'
Copy-Item -LiteralPath (Join-Path $root 'scripts') -Destination $fixture -Recurse
@{folders=@(@{name='Projeto do workspace'; path=$project})} | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $workspacePath -Encoding UTF8
$config = Get-Content -LiteralPath (Join-Path $root 'config/harness.example.json') -Raw | ConvertFrom-Json
$config.repositories = @()
$config.activeProject = $null
$config.sonar.serverUrl = 'http://localhost:9000'
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
$output=@('3','1','q') | & powershell.exe @sonarArguments 2>&1 | Out-String
Assert ($LASTEXITCODE -eq 1 -and $output.Contains('Nenhum scanner sera executado') -and $output.Contains('Selecao cancelada') -and -not $output.Contains('Token Sonar')) ('Menu de download deve chegar a chave sem toolchain ou rede: '+$output)
$output=@('1','q') | & powershell.exe @sonarArguments -Action Download 2>&1 | Out-String
Assert ($LASTEXITCODE -eq 1 -and $output.Contains('Nenhum scanner sera executado') -and $output.Contains('Selecao cancelada')) ('Action Download deve chegar a chave sem toolchain: '+$output)
$implementationArguments = @($implementationTask[0].args | ForEach-Object {
    $_.Replace('${workspaceFolder}', $fixture).Replace('${input:harnessWorkspacePath}', $workspacePath).Replace('${execPath}', (Join-Path $fixture 'editor-ausente.exe'))
})
$implementationArguments += @('-ConfigPath', $configPath)
$output = 'q' | & powershell.exe @implementationArguments 2>&1 | Out-String
Assert ($LASTEXITCODE -eq 1 -and $output.Contains('Nenhum projeto correspondente') -and -not (Test-Path (Join-Path $fixture '.harness/projetos'))) 'Ausencia de plano deve impedir preparo sem criar registro ou proposta.'
# Dois planos existentes exigem escolha; cancelar preserva ambos.
$secondProject=Join-Path $area 'outra aplicacao'
$null=[IO.Directory]::CreateDirectory($secondProject)
Set-Content (Join-Path $secondProject 'pom.xml') '<project><artifactId>outro</artifactId></project>'
@{folders=@(@{name='Projeto do workspace';path=$project},@{name='Outro';path=$secondProject})} | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $workspacePath -Encoding UTF8
foreach ($name in @('app','outro')) {
    $folder=Join-Path $fixture ('.harness/projetos/'+$name+'/atual/planejamento')
    $null=[IO.Directory]::CreateDirectory($folder)
    Set-Content (Join-Path $folder 'plano.md') ('Proposta humana de '+$name)
}
$output = 'q' | & powershell.exe @implementationArguments 2>&1 | Out-String
Assert ($LASTEXITCODE -eq 1 -and $output.Contains('Selecao cancelada') -and -not $output.Contains('Prompt preparado:')) 'Cancelamento da task de implementacao deve preceder preparo/editor.'
Assert (@(Get-ChildItem -LiteralPath (Join-Path $fixture '.harness') -Filter '*.prompt.md' -Recurse -File).Count -eq 0) 'Cancelar implementacao nao pode publicar prompts.'
Write-Output 'PASS: variaveis de tarefa suportadas, workspace com espacos, entrada real do build e cancelamento sem execucao.'
$sprintArguments=@($sprints[0].args | ForEach-Object { $_.Replace('${workspaceFolder}',$fixture).Replace('${input:harnessWorkspacePath}',$workspacePath).Replace('${execPath}',(Join-Path $fixture 'editor-ausente.exe')) })
$output='q' | & powershell.exe @sprintArguments 2>&1 | Out-String
Assert ($LASTEXITCODE -eq 1 -and $output.Contains('Selecao cancelada') -and @(Get-ChildItem -LiteralPath (Join-Path $fixture '.harness') -Filter 'contexto.json' -Recurse -File).Count -eq 0) 'Cancelamento da tarefa de sprints criou contexto ou nao chegou ao menu.'
Write-Output 'PASS: entrada real da tarefa de sprints cancela antes de criar contexto.'
