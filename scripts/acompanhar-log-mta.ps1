#requires -Version 5.1
[CmdletBinding()]
param([string]$ConfigPath,[string]$WorkspacePath,[string]$Target,[switch]$SelectTarget,
    [ValidateRange(1,1000)][int]$Tail=40,[switch]$Once,[switch]$Detalhado)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
try {
    Import-Module (Join-Path $PSScriptRoot 'Harness.psm1') -Force -DisableNameChecking
    Import-Module (Join-Path $PSScriptRoot 'HarnessProject.psm1') -DisableNameChecking
    $root=Split-Path -Parent $PSScriptRoot
    if (-not $ConfigPath) { $ConfigPath=Join-Path $root 'config/harness.local.json' }
    $context=Read-HarnessConfig $ConfigPath $root -WorkspacePath $WorkspacePath -Target $Target -SelectTarget:$SelectTarget -SkipMigrationInitialization
    if (-not $context.Active) { throw 'Escolha o projeto Maven.' }
    $project=Get-HarnessProjectStorage $root (Join-Path $context.Active.path 'pom.xml')
    Write-Host "Projeto: $($project.Name). Ctrl+C encerra somente o leitor. Atividade de log nao comprova progresso ou sucesso."
    $stamp=''
    do {
        $log=Get-HarnessProjectMtaLog $project -Detailed:$Detalhado
        Write-Host "Situacao: $($log.Status) | Log: $($log.Path)"
        if ($log.Error) { Write-Host $log.Error }
        if (Test-Path -LiteralPath $log.Path -PathType Leaf) {
            $stream=$null
            try {
                $info=Get-Item -LiteralPath $log.Path
                $current="$($info.LastWriteTimeUtc.Ticks):$($info.Length)"
                if ($current -cne $stamp) {
                    if ($Detalhado) {
                        $stream=[IO.File]::Open($log.Path,'Open','Read',([IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete))
                        $length=[int][Math]::Min(16384,$stream.Length)
                        $null=$stream.Seek(-$length,[IO.SeekOrigin]::End)
                        $buffer=New-Object byte[] $length; $read=$stream.Read($buffer,0,$length)
                        $sample=[Text.Encoding]::UTF8.GetString($buffer,0,$read)
                        foreach ($line in @($sample -split '\r?\n' | Where-Object { $_ -match '^(\uFEFF)?!MESSAGE|^\s*element=|^with provider:' } | Select-Object -Last 4)) {
                            Write-Host ($line.Substring(0,[Math]::Min(500,$line.Length)))
                        }
                    } else { Get-Content -LiteralPath $log.Path -Tail $Tail }
                    $stamp=$current
                }
            } catch [IO.IOException], [Management.Automation.ItemNotFoundException] { Write-Host 'Log em rotacao; tente novamente.' }
            finally { if ($stream) { $stream.Dispose() } }
        } else { Write-Host 'Log ainda indisponivel; confira a situacao e o terminal da ferramenta.' }
        if ($Once -or -not $log.Running) { break }
        Start-Sleep -Seconds 5
    } while ($true)
    exit 0
} catch { Write-Host ('ERRO ao acompanhar MTA: '+$_.Exception.Message) -ForegroundColor Red; exit 1 }
