#requires -Version 5.1
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$area=Join-Path $root ('.harness/tests/isolamento-'+[guid]::NewGuid().ToString('N').Substring(0,8))
$fixture=Join-Path $area 'harness'
$null=[IO.Directory]::CreateDirectory((Join-Path $fixture 'tests'))
$null=[IO.Directory]::CreateDirectory((Join-Path $fixture 'config'))
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'Invoke-HarnessTests.ps1') -Destination (Join-Path $fixture 'tests')
[IO.File]::WriteAllText((Join-Path $fixture '.gitignore'),"config/harness.local.json`n.harness/`n")
[IO.File]::WriteAllText((Join-Path $fixture 'config/harness.local.json'),'NAO COPIAR CONFIGURACAO PESSOAL')
[IO.File]::WriteAllText((Join-Path $fixture 'entrada.txt'),'antes')
$pass=@'
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
if (Test-Path (Join-Path $root 'config/harness.local.json')) { throw 'Configuracao pessoal copiada.' }
if ((Get-Content (Join-Path $root 'entrada.txt') -Raw) -cne 'edicao corrente') { throw 'Edicao local nao copiada.' }
$null=[IO.Directory]::CreateDirectory((Join-Path $root '.harness/tests/app'))
[IO.File]::WriteAllText((Join-Path $root '.harness/tests/app/pom.xml'),'<project/>')
New-Item -ItemType Junction -Path (Join-Path $root '.harness/tests/link') -Target $env:HARNESS_TEST_LINK_TARGET | Out-Null
'PASS: fixture somente na copia isolada.'
'@
[IO.File]::WriteAllText((Join-Path $fixture 'tests/Test-Pass.ps1'),$pass)
[IO.File]::WriteAllText((Join-Path $fixture 'tests/Test-Fail.ps1'),($pass+"`nthrow 'Falha proposital para conferir limpeza.'"))
& git -C $fixture init -q
& git -C $fixture add .
if ($LASTEXITCODE -ne 0) { throw 'Falha ao preparar fixture Git.' }
[IO.File]::WriteAllText((Join-Path $fixture 'entrada.txt'),'edicao corrente')
$runner=Join-Path $fixture 'tests/Invoke-HarnessTests.ps1'
$linkTarget=Join-Path $area 'destino protegido'
$null=[IO.Directory]::CreateDirectory($linkTarget)
$sentinel=Join-Path $linkTarget 'preservar.txt'
[IO.File]::WriteAllText($sentinel,'conteudo externo preservado')
$oldTarget=$env:HARNESS_TEST_LINK_TARGET
try {
$env:HARNESS_TEST_LINK_TARGET=$linkTarget
foreach ($test in @('Test-Pass.ps1','Test-Fail.ps1')) {
    $results=Join-Path $area $test
    $previous=$ErrorActionPreference
    try { $ErrorActionPreference='Continue'; & powershell.exe -NoProfile -NonInteractive -File $runner -Test $test -ResultsPath $results *> (Join-Path $area ($test+'.out')); $code=$LASTEXITCODE }
    finally { $ErrorActionPreference=$previous }
    $expected=if ($test -eq 'Test-Pass.ps1') { 0 } else { 1 }
    if ($code -ne $expected) { Get-Content (Join-Path $area ($test+'.out')); throw 'Codigo de saida incorreto.' }
    $report=Get-Content (Join-Path $results 'resultado.json') -Raw | ConvertFrom-Json
    if (-not $report.TemporaryRemoved -or (Test-Path -LiteralPath $report.TemporaryRoot)) { throw 'Diretorio temporario nao removido.' }
    if ($report.Tests[0].ExitCode -ne $expected) { throw 'Relatorio nao preservou resultado.' }
    if ([IO.File]::ReadAllText($sentinel) -cne 'conteudo externo preservado') { throw 'Limpeza seguiu junction.' }
}
} finally { $env:HARNESS_TEST_LINK_TARGET=$oldTarget }
if (Test-Path (Join-Path $fixture '.harness/tests/app/pom.xml')) { throw 'Fixture criada na origem.' }
if ((Get-Content (Join-Path $fixture 'config/harness.local.json') -Raw) -cne 'NAO COPIAR CONFIGURACAO PESSOAL') { throw 'Origem alterada.' }
'PASS: isolamento, edicao corrente, configuracao privada, logs opcionais, junction e limpeza apos sucesso/falha.'
