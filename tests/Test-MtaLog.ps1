#requires -Version 5.1
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$root=Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $root 'scripts/HarnessProject.psm1') -Force -DisableNameChecking
function Assert($condition,[string]$message) { if (-not $condition) { throw $message } }
$area=Join-Path $root ('.harness/tests/log-corrente-'+[guid]::NewGuid().ToString('N').Substring(0,8))
$fixture=Join-Path $area 'harness'; $null=[IO.Directory]::CreateDirectory((Join-Path $fixture 'scripts'))
foreach ($file in Get-ChildItem (Join-Path $root 'scripts') -File -Filter 'Harness*.ps*') { Copy-Item -LiteralPath $file.FullName -Destination (Join-Path $fixture 'scripts') }
foreach ($name in @('acompanhar-log-mta.ps1','abrir-relatorio-mta.ps1')) { Copy-Item -LiteralPath (Join-Path $root ('scripts/'+$name)) -Destination (Join-Path $fixture 'scripts') }
$config=Get-Content (Join-Path $root 'config/harness.example.json') -Raw | ConvertFrom-Json
$config.repositories=@(); $config.activeProject='api'; $projects=@{}
foreach ($name in @('api','outro')) {
    $app=Join-Path $area $name; $null=[IO.Directory]::CreateDirectory($app)
    [IO.File]::WriteAllText((Join-Path $app 'pom.xml'),('<project><artifactId>'+$name+'</artifactId></project>'))
    $config.repositories+=@([pscustomobject]@{name=$name;path=$app})
    $projects[$name]=Initialize-HarnessProjectStorage $fixture (Join-Path $app 'pom.xml')
}
$configPath=Join-Path $fixture 'config.json'; [IO.File]::WriteAllText($configPath,($config | ConvertTo-Json -Depth 8))
$entry=Join-Path $fixture 'scripts/acompanhar-log-mta.ps1'
$output=& powershell.exe -NoProfile -File $entry -ConfigPath $configPath -Target api -Once 2>&1 | Out-String
Assert ($LASTEXITCODE -eq 1 -and $output.Contains('Nenhuma operacao MTA')) 'Ausencia de operacao deve ser informada.'
foreach ($name in $projects.Keys) {
    $project=$projects[$name]
    $log=Join-Path $project.Folder 'atual/diagnosticos/mta-console.log'
    $internal=('x'*50000)+"`n!MESSAGE ATIVIDADE-"+$name+"`n"
    Set-HarnessProjectOperation $project 'mta' 'SUCCEEDED' -LogPath $log -Files @{'atual/diagnosticos/mta-console.log'=('CONSOLE-'+$name);'atual/diagnosticos/mta-interno.log'=$internal}
}
$output=& powershell.exe -NoProfile -File $entry -ConfigPath $configPath -Target api -Once 2>&1 | Out-String
Assert ($LASTEXITCODE -eq 0 -and $output.Contains('CONSOLE-api') -and -not $output.Contains('CONSOLE-outro')) 'Log deve pertencer ao projeto escolhido.'
$output=& powershell.exe -NoProfile -File $entry -ConfigPath $configPath -Target outro -Detalhado -Once 2>&1 | Out-String
Assert ($LASTEXITCODE -eq 0 -and $output.Contains('ATIVIDADE-outro') -and $output.Length -lt 3000) 'Amostra interna deve ser limitada e do projeto certo.'
$project=$projects['api']; $temporary=Get-HarnessProjectTemporary $project 'mta'
$null=[IO.Directory]::CreateDirectory($temporary)
[IO.File]::WriteAllText((Join-Path $temporary 'console.log'),'LOG-INTERROMPIDO')
Set-HarnessProjectOperation $project 'mta' 'RUNNING' -LogPath (Join-Path $temporary 'console.log')
$output=& powershell.exe -NoProfile -File $entry -ConfigPath $configPath -Target api -Once 2>&1 | Out-String
Assert ($LASTEXITCODE -eq 0 -and $output.Contains('INTERRUPTED') -and $output.Contains('LOG-INTERROMPIDO')) 'Processo encerrado nao pode parecer ainda ativo; ultimo log deve permanecer consultavel.'
Set-HarnessProjectOperation $project 'build' 'RUNNING'
$output=& powershell.exe -NoProfile -File $entry -ConfigPath $configPath -Target api -Once 2>&1 | Out-String
Assert ($LASTEXITCODE -eq 0 -and $output.Contains('FAILED') -and $output.Contains('LOG-INTERROMPIDO')) 'Build seguinte nao pode ser confundido com MTA ativo.'
$external=Join-Path $area 'relatorio externo'; $null=[IO.Directory]::CreateDirectory($external)
[IO.File]::WriteAllText((Join-Path $external 'index.html'),'relatorio')
[IO.File]::WriteAllText((Join-Path $external 'output.js'),'window["apps"] = [{"artifactId":"api","rulesets":[]}];')
Publish-HarnessProjectFiles $project @{'projeto.json'=(@{pom=$project.Pom;mta=@{diretorio=$external}} | ConvertTo-Json)}
$output=& powershell.exe -NoProfile -File (Join-Path $fixture 'scripts/abrir-relatorio-mta.ps1') -ConfigPath $configPath -Target api -NoOpen 2>&1 | Out-String
Assert ($LASTEXITCODE -eq 0 -and $output.Contains((Join-Path $external 'index.html'))) 'Abertura deve ler origem externa sem recibos.'
'PASS: log por projeto, amostra limitada, interrupcao, outra operacao e abertura direta.'
