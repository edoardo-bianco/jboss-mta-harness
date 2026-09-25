#requires -Version 5.1
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$area = Join-Path $root ('.harness/tests/log-' + [guid]::NewGuid().ToString('N'))
$fixture = Join-Path $area 'harness'
$app = Join-Path $area 'aplicacao com espaco'
$null = New-Item -ItemType Directory -Path "$fixture/scripts", "$fixture/config", $app -Force
foreach ($file in @('Harness.psm1','acompanhar-log-mta.ps1')) { Copy-Item -LiteralPath (Join-Path $root "scripts/$file") -Destination "$fixture/scripts/$file" }
$script = Join-Path $fixture 'scripts/acompanhar-log-mta.ps1'
$config = Get-Content -LiteralPath (Join-Path $root 'config/harness.example.json') -Raw | ConvertFrom-Json
$config.activeProject = 'api'
$config.repositories = @(@{name='api'; path=$app})
$config | ConvertTo-Json -Depth 8 | Set-Content "$fixture/config/harness.local.json" -Encoding UTF8
function Assert($condition, $message) { if (-not $condition) { throw $message } }
$output = & powershell.exe -NoProfile -File $script -Once 2>&1 | Out-String
Assert ($LASTEXITCODE -eq 1 -and $output.Contains('Nenhuma rodada')) 'Sem rodada deve informar erro.'
$oldId = '11111111111111111111111111111111'
$newId = '22222222222222222222222222222222'
foreach ($id in @($oldId,$newId)) {
    $run = Join-Path $fixture ".harness/runs/api/$id"
    $null = New-Item -ItemType Directory -Path $run -Force
    @{RunId=$id; Project='api'} | ConvertTo-Json | Set-Content "$run/manifest.json" -Encoding UTF8
}
$old = Join-Path $fixture ".harness/runs/api/$oldId"
$current = Join-Path $fixture ".harness/runs/api/$newId"
(Get-Item "$old/manifest.json").CreationTimeUtc = [DateTime]::UtcNow.AddHours(-1)
Set-Content "$old/console.log" 'LOG-ANTIGO' -Encoding Unicode
@{Status='SUCCEEDED'; ExitCode=0} | ConvertTo-Json | Set-Content "$old/result.json"
@{RunId=$oldId} | ConvertTo-Json | Set-Content "$fixture/.harness/last-api.json"
$output = & powershell.exe -NoProfile -File $script -Once 2>&1 | Out-String
Assert ($LASTEXITCODE -eq 1 -and $output.Contains($newId) -and $output.Contains('console.log ainda nao existe') -and -not $output.Contains('LOG-ANTIGO')) 'Rodada nova sem log nao pode cair no ultimo sucesso.'
Set-Content "$current/console.log" @('LINHA-1','LINHA-2') -Encoding Unicode
$output = & powershell.exe -NoProfile -File $script -Once -Tail 1 2>&1 | Out-String
Assert ($LASTEXITCODE -eq 0 -and $output.Contains('LINHA-2') -and -not $output.Contains('LINHA-1')) 'Snapshot deve limitar linhas e escolher a nova rodada.'
$job = Start-Job -ArgumentList $script -ScriptBlock { param($entry) & $entry }
try {
    $captured = ''
    $deadline = [DateTime]::UtcNow.AddSeconds(15)
    do {
        Start-Sleep -Milliseconds 200
        $captured += (Receive-Job $job 6>&1 | Out-String)
    } until ($captured.Contains('LINHA-2') -or [DateTime]::UtcNow -ge $deadline)
    Assert ($captured.Contains('LINHA-2')) 'Leitor nao iniciou.'
    Add-Content "$current/console.log" 'NOVA-MENSAGEM' -Encoding Unicode
    $deadline = [DateTime]::UtcNow.AddSeconds(10)
    do {
        Start-Sleep -Milliseconds 200
        $captured += (Receive-Job $job 6>&1 | Out-String)
    } until ($captured.Contains('NOVA-MENSAGEM') -or [DateTime]::UtcNow -ge $deadline)
    Assert ($captured.Contains('NOVA-MENSAGEM')) 'Leitor nao acompanhou append concorrente.'
} finally { Stop-Job $job; Remove-Job $job }
$output = & powershell.exe -NoProfile -File $script -Detalhado -Once 2>&1 | Out-String
Assert ($LASTEXITCODE -eq 0 -and $output.Contains('Log interno ainda nao disponivel')) 'Log interno ausente deve ser informado sem falhar.'
$null = New-Item -ItemType Directory -Path "$current/.metadata" -Force
$internal = Join-Path $current '.metadata/.log'
$content = "!MESSAGE MENSAGEM-ANTIGA`n" + ('x' * 1000000) + "`n!MESSAGE ATIVIDADE-ATUAL`n  element=ClasseFixture`n"
[IO.File]::WriteAllText($internal, $content, (New-Object Text.UTF8Encoding($false)))
$internalHash = (Get-FileHash $internal).Hash
$output = & powershell.exe -NoProfile -File $script -Detalhado -Once 2>&1 | Out-String
Assert ($LASTEXITCODE -eq 0 -and $output.Contains('ATIVIDADE-ATUAL') -and $output.Contains('ClasseFixture') -and -not $output.Contains('MENSAGEM-ANTIGA') -and $output.Length -lt 6000) 'Amostra interna deve ser limitada e incluir atividade recente.'
Assert ((Get-FileHash $internal).Hash -eq $internalHash) 'Leitor alterou log interno.'
# Forcar a janela exata observada: Test-Path encontra o arquivo, mas Get-Item ja nao.
$raceScript = Join-Path $area 'simular-rotacao.ps1'
@'
param([string]$Entry, [string]$InternalLog)
function Get-Item {
    [CmdletBinding()]
    param([string]$LiteralPath, [switch]$Force)
    if ($LiteralPath -eq $InternalLog -and (Split-Path $MyInvocation.ScriptName -Leaf) -eq 'acompanhar-log-mta.ps1') {
        Rename-Item -LiteralPath $InternalLog -NewName '.race.log'
    }
    Microsoft.PowerShell.Management\Get-Item -LiteralPath $LiteralPath -Force:$Force
}
& $Entry -Detalhado -Once
exit $LASTEXITCODE
'@ | Set-Content -LiteralPath $raceScript -Encoding UTF8
$output = & powershell.exe -NoProfile -File $raceScript -Entry $script -InternalLog $internal 2>&1 | Out-String
Assert ($LASTEXITCODE -eq 0 -and $output.Contains('temporariamente indisponivel')) 'Rotacao entre Test-Path e Get-Item nao deve derrubar o leitor.'
Rename-Item -LiteralPath (Join-Path $current '.metadata/.race.log') -NewName '.log'
$job = Start-Job -ArgumentList $script -ScriptBlock { param($entry) & $entry -Detalhado }
try {
    $captured = ''
    $deadline = [DateTime]::UtcNow.AddSeconds(15)
    do {
        Start-Sleep -Milliseconds 200
        $captured += (Receive-Job $job 6>&1 | Out-String)
    } until ($captured.Contains('ATIVIDADE-ATUAL') -or [DateTime]::UtcNow -ge $deadline)
    Assert ($captured.Contains('ATIVIDADE-ATUAL')) 'Monitor interno nao iniciou.'
    Rename-Item -LiteralPath $internal -NewName '.bak-test.log'
    Set-Content -LiteralPath $internal -Value '!MESSAGE DEPOIS-DA-ROTACAO' -Encoding UTF8
    $deadline = [DateTime]::UtcNow.AddSeconds(15)
    do {
        Start-Sleep -Milliseconds 200
        $captured += (Receive-Job $job 6>&1 | Out-String)
    } until ($captured.Contains('DEPOIS-DA-ROTACAO') -or [DateTime]::UtcNow -ge $deadline)
    Assert ($captured.Contains('DEPOIS-DA-ROTACAO')) 'Monitor nao reabriu o log apos rotacao.'
    @{Status='FAILED'; ExitCode=7} | ConvertTo-Json | Set-Content "$current/result.json"
    $null = Wait-Job $job -Timeout 15
    $captured += (Receive-Job $job 6>&1 | Out-String)
    Assert ($job.State -eq 'Completed' -and $captured.Contains('Resultado registrado: FAILED')) 'Monitor deve encerrar com o resultado real.'
} finally { Stop-Job $job; Remove-Job $job }
@{Status='FAILED'; ExitCode=7} | ConvertTo-Json | Set-Content "$current/result.json"
$hash = (Get-FileHash "$current/console.log").Hash
$output = & powershell.exe -NoProfile -File $script 2>&1 | Out-String
Assert ($LASTEXITCODE -eq 0 -and $output.Contains('FAILED') -and $output.Contains('ExitCode: 7')) 'Rodada finalizada deve mostrar a falha e encerrar.'
Assert ((Get-FileHash "$current/console.log").Hash -eq $hash) 'Leitor alterou o log.'
$output = & powershell.exe -NoProfile -File $script -RunId $oldId -Once 2>&1 | Out-String
Assert ($LASTEXITCODE -eq 0 -and $output.Contains('LOG-ANTIGO') -and -not $output.Contains('NOVA-MENSAGEM')) 'Selecao explicita deve respeitar RunId.'
Write-Output 'PASS: selecao, tail/append, amostra interna limitada, log ausente, rotacao, encerramento pelo resultado e leitura sem alteracao.'
