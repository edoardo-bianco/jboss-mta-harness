#requires -Version 5.1
[CmdletBinding()]
param([string]$ConfigPath,[ValidateSet('eap71','eap74','all')][string]$Eap,
    [ValidateRange(0,10000)][int]$Tail=100)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
try {
    Import-Module (Join-Path $PSScriptRoot 'Harness.psm1') -DisableNameChecking
    Import-Module (Join-Path $PSScriptRoot 'HarnessJbossRuntime.psm1') -DisableNameChecking
    Import-Module (Join-Path $PSScriptRoot 'HarnessJbossLogs.psm1') -DisableNameChecking
    $root=Split-Path -Parent $PSScriptRoot
    if (-not $ConfigPath) { $ConfigPath=Join-Path $root 'config/harness.local.json' }
    $context=Read-HarnessJbossContext $ConfigPath $root
    if (-not $Eap) {
        Write-Host 'Servidor: 1. EAP 7.0/7.1 (eap71) | 2. EAP 7.4 | 3. Todos | Enter/q cancela'
        $Eap=switch (Read-Host 'EAP') {'1' {'eap71'} '2' {'eap74'} '3' {'all'} default {throw 'Selecao cancelada.'}}
    }
    $selected=if ($Eap -eq 'all') {@('eap71','eap74')} else {@($Eap)}
    $cursors=@()
    foreach ($id in $selected) {
        # Leitura de logs nao depende de JDK/CLI, projeto ou servidor ativo.
        $property=$context.Config.tools.PSObject.Properties[$id+'Home']
        if (-not $property -or [string]::IsNullOrWhiteSpace([string]$property.Value)) { throw "Configure tools.${id}Home para acompanhar este log." }
        $serverHome=Resolve-HarnessPath $property.Value $root
        if (-not [IO.Directory]::Exists($serverHome)) { throw "Instalacao configurada ausente: $serverHome" }
        $path=Join-Path $serverHome 'standalone/log/server.log'
        Write-Host "[$id] $path"
        if (-not [IO.File]::Exists($path)) { Write-Host "[$id] Aguardando a criacao do log." }
        $cursors+=New-HarnessJbossLogCursor $id $path $Tail
    }
    Write-Host 'Ctrl+C encerra somente o acompanhamento. O servidor continua em execucao.'
    while ($true) {
        foreach ($cursor in $cursors) {
            Read-HarnessJbossLog $cursor | ForEach-Object { Write-Host ('['+$cursor.Eap+'] '+$_) }
        }
        Start-Sleep -Milliseconds 500
    }
} catch { Write-Host ('ERRO logs JBoss: '+$_.Exception.Message) -ForegroundColor Red; exit 1 }
