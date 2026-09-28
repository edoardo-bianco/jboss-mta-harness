#requires -Version 5.1
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
function Assert($condition, $message) { if (-not $condition) { throw $message } }
$entrySource = Join-Path $root 'scripts/criar-pasta-evidencias.ps1'
Assert (Test-Path -LiteralPath $entrySource) 'Falta entrada para criar pasta de evidencias.'
$area = Join-Path $root ('.harness/tests/evidencias-' + [guid]::NewGuid().ToString('N').Substring(0,8))
$fixture = Join-Path $area 'harness com espacos'
$scripts = Join-Path $fixture 'scripts'
$docs = Join-Path $fixture 'doc/guias'
$app = Join-Path $area 'app um'
$other = Join-Path $area 'app dois'
foreach ($path in @($scripts,$docs,$app,$other)) { $null = New-Item -ItemType Directory -Path $path -Force }
foreach ($path in @($app,$other)) { Set-Content -LiteralPath (Join-Path $path 'pom.xml') '<project />' }
Copy-Item -LiteralPath $entrySource -Destination $scripts
Copy-Item -LiteralPath (Join-Path $root 'scripts/Harness.psm1') -Destination $scripts
Copy-Item -LiteralPath (Join-Path $root 'doc/guias/modelo-evidencias-complementares.md') -Destination $docs
$config = Get-Content -LiteralPath (Join-Path $root 'config/harness.example.json') -Raw | ConvertFrom-Json
$config.repositories = @()
$config.activeProject = $null
$configPath = Join-Path $fixture 'config.json'
$workspacePath = Join-Path $area 'workspace com espacos.code-workspace'
$config | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $configPath -Encoding UTF8
@{folders=@(@{name='Mesmo nome';path=$app},@{name='Mesmo nome';path=$other})} | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $workspacePath -Encoding UTF8
$configBefore = Get-Content -Raw $configPath
$workspaceBefore = Get-Content -Raw $workspacePath
$entry = Join-Path $scripts 'criar-pasta-evidencias.ps1'
$entryArgs = @('-NoProfile','-File',$entry,'-ConfigPath',$configPath,'-WorkspacePath',$workspacePath,'-SelectTarget','-NoOpen')
$output = 'q' | & powershell.exe @entryArgs 2>&1 | Out-String
Assert ($LASTEXITCODE -eq 1 -and $output.Contains('Selecao cancelada')) 'Cancelamento nao respeitado.'
Assert (-not (Test-Path -LiteralPath (Join-Path $fixture '.harness'))) 'Cancelar criou estrutura.'
$output = '2' | & powershell.exe @entryArgs 2>&1 | Out-String
Assert ($LASTEXITCODE -eq 0) ('Criacao falhou: ' + $output)
$base = Join-Path $fixture '.harness/evidencias'
$first = @(Get-ChildItem -LiteralPath $base -Recurse -File)
Assert ($first.Count -eq 1 -and $first[0].Name -eq 'LEIA-ME.md') 'Criou arquivos alem do indice.'
$index = Get-Content -Raw -Encoding UTF8 $first[0].FullName
Assert ($index.Contains($other) -and -not $index.Contains($app)) 'Identidade de outro projeto.'
Assert ($index.Contains('/revisar-lote') -and $index.Contains('Previous') -and $index.Contains('ID do lote existente: PREENCHER')) 'Faltam instrucoes ou inferiu lote.'
Assert ($output.Contains($first[0].FullName)) 'Terminal nao informou caminho do indice.'
Add-Content -LiteralPath $first[0].FullName 'EVIDENCIA MANUAL PRESERVAR'
$preserved = Get-Content -Raw $first[0].FullName
$output = '2' | & powershell.exe @entryArgs 2>&1 | Out-String
Assert ($LASTEXITCODE -eq 0) 'Repeticao falhou.'
Assert ((Get-Content -Raw $first[0].FullName) -ceq $preserved) 'Repeticao sobrescreveu indice anterior.'
Assert (@(Get-ChildItem -LiteralPath $base -Directory).Count -eq 1 -and @(Get-ChildItem -LiteralPath $base -Recurse -File).Count -eq 2) 'Repeticao nao criou nova pasta no mesmo projeto.'
$editor = Join-Path $scripts 'editor.ps1'
Set-Content -LiteralPath $editor -Encoding UTF8 -Value '$args | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $PSScriptRoot "editor-args.json")'
$output = & powershell.exe -NoProfile -File $entry -ConfigPath $configPath -WorkspacePath $workspacePath -Target $app -EditorPath $editor 2>&1 | Out-String
Assert ($LASTEXITCODE -eq 0) ('Criacao com editor falhou: ' + $output)
Assert (@(Get-ChildItem -LiteralPath $base -Directory).Count -eq 2) 'Projetos homonimos misturados.'
$editorArgs = Get-Content -Raw (Join-Path $scripts 'editor-args.json') | ConvertFrom-Json
Assert ($editorArgs.Count -eq 2 -and $editorArgs[0] -eq '--reuse-window' -and (Test-Path -LiteralPath $editorArgs[1])) 'Editor nao recebeu indice criado.'
Assert ((Get-Content -Raw -Encoding UTF8 $editorArgs[1]).Contains($app)) 'Editor abriu indice do outro projeto.'
Assert ((Get-Content -Raw $configPath) -ceq $configBefore -and (Get-Content -Raw $workspacePath) -ceq $workspaceBefore) 'Alterou configuracao/workspace.'
Assert (@(Get-ChildItem -LiteralPath (Join-Path $fixture '.harness') -Directory).Count -eq 1) 'Criou area de MTA/planejamento indevida.'
Write-Output "PASS: selecao/cancelamento reais, homonimos isolados, repeticao preservada, indice com instrucoes e editor. Fixture: $area"
