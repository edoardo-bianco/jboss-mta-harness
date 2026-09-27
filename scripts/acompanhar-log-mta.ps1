#requires -Version 5.1
[CmdletBinding()]
param(
    [string]$ConfigPath,
    [ValidatePattern('^[a-f0-9]{32}$')][string]$RunId,
    [ValidateRange(1,1000)][int]$Tail = 40,
    [switch]$Once,
    [switch]$Detalhado,
    [string]$WorkspacePath,
    [string]$Target,
    [switch]$SelectTarget,
    [switch]$Active,
    [switch]$SelectRun
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
try {
    Import-Module (Join-Path $PSScriptRoot 'Harness.psm1') -Force -DisableNameChecking
    $harnessRoot = Split-Path -Parent $PSScriptRoot
    if ($Active) {
        if ($ConfigPath -or $WorkspacePath -or $Target -or $SelectTarget -or $RunId -or $SelectRun) { throw 'Use -Active sozinho para selecionar a analise em execucao; nao combine com selecao de projeto/rodada.' }
        $activeRun = Get-ActiveMtaRun $harnessRoot
        $run = $activeRun.Run
        $manifest = $activeRun.Manifest
        $RunId = $manifest.RunId
        $projectLabel = $activeRun.Label
        $source = $manifest.Source
    } else {
        if ($SelectRun -and $RunId) { throw 'Escolha -SelectRun ou -RunId, sem combinar os dois.' }
        if (-not $ConfigPath) { $ConfigPath = Join-Path $harnessRoot 'config/harness.local.json' }
        $context = Read-HarnessConfig $ConfigPath $harnessRoot -WorkspacePath $WorkspacePath -Target $Target -SelectTarget:$SelectTarget
        if (-not $context.Active) { throw 'Escolha um projeto com -SelectTarget ou -Target; activeProject e o padrao opcional.' }
        $runs = @(Get-HarnessMtaRuns $harnessRoot $context.Active.name $context.Active.path)
        if (-not $RunId) {
            if (-not $runs.Count) { throw 'Nenhuma rodada encontrada. Execute MTA: executar analise primeiro.' }
            # O manifesto nasce depois do snapshot. Nao usar last-*.json: aponta apenas ao ultimo sucesso.
            $selected = $runs[0]
            if ($SelectRun) {
                Write-Host "Rodadas MTA de $($context.Active.label), da mais recente para a mais antiga:"
                for ($index = 0; $index -lt $runs.Count; $index++) {
                    $item = $runs[$index]
                    $status = 'SEM RESULTADO'
                    $savedResult = Join-Path $item.Run 'result.json'
                    if (Test-Path -LiteralPath $savedResult -PathType Leaf) {
                        try { $status = (Get-Content -LiteralPath $savedResult -Raw -Encoding UTF8 | ConvertFrom-Json).Status }
                        catch { $status = 'RESULTADO INDISPONIVEL' }
                    }
                    if ($item.Problem) { $status = 'INDISPONIVEL: ' + $item.Problem }
                    Write-Host ("{0}. {1} | {2} | RunId: {3}" -f ($index + 1), (Format-HarnessDate $item.CreatedAtUtc.ToString('o')), $status, $item.RunId)
                }
                $answer = Read-Host 'Numero da rodada (q cancela)'
                $choice = 0
                if (-not [int]::TryParse($answer, [ref]$choice) -or $choice -lt 1 -or $choice -gt $runs.Count) { throw 'Selecao de rodada cancelada ou invalida; nenhum log aberto.' }
                $selected = $runs[$choice - 1]
            }
        } else {
            $matches = @($runs | Where-Object RunId -CEQ $RunId)
            if ($matches.Count -ne 1) { throw 'Rodada ausente ou ambigua para o projeto selecionado.' }
            $selected = $matches[0]
        }
        if ($selected.Problem) { throw $selected.Problem }
        $RunId = $selected.RunId
        $run = $selected.Run
        $manifest = $selected.Manifest
        $projectLabel = $context.Active.label
        $source = $context.Active.path
    }
    $log = Join-Path $run 'console.log'
    $resultPath = Join-Path $run 'result.json'
    Write-Host "Projeto: $projectLabel | Fonte: $source | Rodada: $RunId"
    if ($Detalhado) {
        $internalLog = Resolve-HarnessPath (Join-Path $run '.metadata/.log') $harnessRoot
        Write-Host "Log interno: $internalLog"
        Write-Host 'Amostra a cada 5s; ate 16 KiB por leitura, sem seguir a rotacao. Ctrl+C encerra somente este leitor.'
        Write-Host 'Atividade de log nao comprova progresso, porcentagem ou sucesso. O resultado final vem de result.json.'
        $previousStamp = ''
        do {
            Write-Host ("--- Consulta: " + (Get-Date -Format 'HH:mm:ss'))
            if (Test-Path -LiteralPath $internalLog -PathType Leaf) {
                $stream = $null
                try {
                    $info = Get-Item -LiteralPath $internalLog
                    $age = [Math]::Max(0, [int]([DateTime]::UtcNow - $info.LastWriteTimeUtc).TotalSeconds)
                    Write-Host "Ultima gravacao interna: $($info.LastWriteTime.ToString('HH:mm:ss')) | ha ${age}s | $($info.Length) bytes"
                    $stamp = "$($info.LastWriteTimeUtc.Ticks):$($info.Length)"
                    if ($stamp -ne $previousStamp) {
                        # Capturar somente um trecho finito: Get-Content -Wait nao e adequado a este log volumoso/rotativo.
                        $stream = [IO.File]::Open($internalLog, [IO.FileMode]::Open, [IO.FileAccess]::Read, ([IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete))
                        $length = [int][Math]::Min(16384, $stream.Length)
                        $null = $stream.Seek(-$length, [IO.SeekOrigin]::End)
                        $buffer = New-Object byte[] $length
                        $read = $stream.Read($buffer, 0, $length)
                        $sample = [Text.Encoding]::UTF8.GetString($buffer, 0, $read)
                        $lines = @($sample -split '\r?\n' | Where-Object { $_ -match '^(\uFEFF)?!MESSAGE|^\s*element=|^with provider:' } | Select-Object -Last 4)
                        foreach ($line in $lines) { Write-Host ($line.Substring(0, [Math]::Min(500, $line.Length))) }
                        if (-not $lines.Count) { Write-Host 'Trecho atualizado, sem mensagem resumivel nesta amostra.' }
                        $previousStamp = $stamp
                    } else { Write-Host 'Sem nova gravacao interna desde a consulta anterior; isso sozinho nao indica travamento.' }
                } catch [IO.IOException], [System.Management.Automation.ItemNotFoundException] {
                    Write-Host 'Log interno temporariamente indisponivel (pode estar em rotacao); nova tentativa na proxima consulta.'
                } finally { if ($stream) { $stream.Dispose() } }
            } else { Write-Host 'Log interno ainda nao disponivel. Confira tambem o terminal da analise.' }
            if (Test-Path -LiteralPath $resultPath -PathType Leaf) {
                # O produtor pode estar entre criar e concluir a gravacao do JSON.
                $result = $null
                try { $result = Get-Content -LiteralPath $resultPath -Raw -Encoding UTF8 | ConvertFrom-Json } catch { Write-Host 'Resultado ainda nao legivel; aguardando a proxima consulta.' }
                if ($result -and $result.PSObject.Properties['Status']) {
                    Write-Host "Resultado registrado: $($result.Status) | ExitCode: $($result.ExitCode)"
                    break
                }
            } else { Write-Host 'Resultado final ainda nao registrado.' }
            if ($Once) { break }
            Start-Sleep -Seconds 5
        } while ($true)
        exit 0
    }
    Write-Host "Log: $log"
    $finished = Test-Path -LiteralPath $resultPath -PathType Leaf
    if ($finished) {
        $result = Get-Content -LiteralPath $resultPath -Raw -Encoding UTF8 | ConvertFrom-Json
        Write-Host "Resultado registrado: $($result.Status) | ExitCode: $($result.ExitCode)"
    }
    if (-not (Test-Path -LiteralPath $log -PathType Leaf)) {
        throw 'console.log ainda nao existe (ou a rodada terminou antes da analise). Confira o terminal original/result.json e tente novamente quando o log existir.'
    }
    if ($Once -or $finished) { Get-Content -LiteralPath $log -Tail $Tail }
    else {
        Write-Host 'Acompanhando novas linhas. Ctrl+C encerra somente este leitor. Ao terminar a analise, encerre o leitor e confira o JSON no terminal original.'
        Get-Content -LiteralPath $log -Tail $Tail -Wait
    }
    exit 0
} catch {
    Write-Host ("ERRO ao acompanhar log MTA: " + $_.Exception.Message) -ForegroundColor Red
    exit 1
}
