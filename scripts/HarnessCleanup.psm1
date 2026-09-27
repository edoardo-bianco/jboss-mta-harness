#requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'Harness.psm1') -DisableNameChecking

function Assert-CleanupTree {
    param([string]$Path, [string]$State)
    $resolved = Resolve-HarnessPath $Path $State
    if (-not $resolved.StartsWith($State + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Limpeza fora da area .harness recusada.' }
    $relative = $resolved.Substring($State.Length + 1)
    if ($relative -notmatch '^(runs|builds|planning|backups-temporarios)(\\|$)|^(active-mta|last-[A-Za-z0-9_.-]+)\.json$') { throw "Area nao autorizada para limpeza: $resolved" }
    # Usar objetos evita a normalizacao de caminhos longos pelo provider PS 5.1.
    $pending = New-Object 'Collections.Generic.Stack[System.IO.FileSystemInfo]'
    $pending.Push((Get-Item -LiteralPath $resolved -Force))
    while ($pending.Count) {
        $item = $pending.Pop()
        if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "Link/junction na limpeza: $($item.FullName)" }
        if ($item -is [IO.DirectoryInfo]) { foreach ($child in $item.EnumerateFileSystemInfos()) { $pending.Push($child) } }
    }
}

function Get-HarnessCleanupPaths {
    param([string]$Root, [string]$Source, [switch]$All, [switch]$TemporaryBackups)
    if (([int][bool]$Source + [int][bool]$All + [int][bool]$TemporaryBackups) -ne 1) { throw 'Escolha somente Source, All ou TemporaryBackups para limpar.' }
    $state = Resolve-HarnessPath (Join-Path $Root '.harness') $Root
    if (-not (Test-Path -LiteralPath $state)) { return }
    if ($TemporaryBackups) {
        $temporary = Join-Path $state 'backups-temporarios'
        if (Test-Path -LiteralPath $temporary) { Assert-CleanupTree $temporary $state; $temporary }
        return
    }
    $paths = New-Object 'Collections.Generic.List[string]'
    $mtaRuns = @{}
    foreach ($area in @('runs','builds','planning')) {
        $base = Join-Path $state $area
        if (-not (Test-Path -LiteralPath $base)) { continue }
        # Validar antes de enumerar recursivamente: nunca seguir junctions.
        Assert-CleanupTree $base $state
        if ($All) { $paths.Add($base); continue }
        $receiptName = switch ($area) { 'runs' {'manifest.json'} 'builds' {'result.json'} 'planning' {'context.json'} }
        $depth = if ($area -eq 'planning') { 3 } else { 2 }
        $folders = @($base)
        for ($i=0; $i -lt $depth; $i++) { $folders = @($folders | ForEach-Object { Get-ChildItem -LiteralPath $_ -Directory -Force | Select-Object -ExpandProperty FullName }) }
        foreach ($folder in $folders) {
            $receipt = Join-Path $folder $receiptName
            if (-not (Test-Path -LiteralPath $receipt -PathType Leaf)) { continue }
            try {
                $data = Get-Content -LiteralPath $receipt -Raw -Encoding UTF8 | ConvertFrom-Json
                if ((Resolve-HarnessPath $data.Source $Root) -ine (Resolve-HarnessPath $Source $Root)) { continue }
                if ($data.Project -cnotmatch '^(?:[A-Za-z0-9][A-Za-z0-9_.-]{0,63}|_workspace-[a-f0-9]{24})$') { throw 'Identidade de projeto invalida.' }
                $paths.Add($folder)
                if ($area -eq 'runs') {
                    if ($data.RunId -cnotmatch '^[a-f0-9]{32}$') { throw 'RunId invalido.' }
                    $mtaRuns[$data.Project + '/' + $data.RunId] = $true
                }
            } catch { throw "Recibo invalido; limpeza cancelada antes de remover arquivos: $receipt. $($_.Exception.Message)" }
        }
    }
    foreach ($pointer in Get-ChildItem -LiteralPath $state -File -Force | Where-Object { $_.Name -match '^(active-mta|last-[A-Za-z0-9_.-]+)\.json$' }) {
        if ($All) { $paths.Add($pointer.FullName); continue }
        $data = Get-Content -LiteralPath $pointer.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
        $project = if ($pointer.Name -eq 'active-mta.json') { [string]$data.Project } else { $pointer.Name.Substring(5, $pointer.Name.Length - 10) }
        # Um nome legado pode ter sido reutilizado com outro Source. Conferir a rodada.
        if ($mtaRuns.ContainsKey($project + '/' + $data.RunId)) { $paths.Add($pointer.FullName) }
    }
    foreach ($path in $paths) { Assert-CleanupTree $path $state }
    $paths | Sort-Object -Unique
}

function Invoke-HarnessCleanup {
    param([string]$Root, [string]$Source, [switch]$All, [switch]$TemporaryBackups, [string]$ConfirmText)
    $state = Resolve-HarnessPath (Join-Path $Root '.harness') $Root
    if (-not (Test-Path -LiteralPath $state)) { Write-Host 'Nenhuma execucao gravada.'; return }
    $leases = New-Object 'Collections.Generic.List[IDisposable]'
    try {
        foreach ($name in @('mta.lock','planning.lock')) {
            try { $leases.Add([IO.File]::Open((Join-Path $state $name), 'OpenOrCreate','ReadWrite','None')) }
            catch { throw 'Existe build, MTA, planejamento ou limpeza em andamento. Aguarde terminar.' }
        }
        $paths = @(Get-HarnessCleanupPaths $Root -Source $Source -All:$All -TemporaryBackups:$TemporaryBackups)
        if (-not $paths.Count) { Write-Host 'Nenhum artefato encontrado neste escopo.'; return }
        if ($TemporaryBackups) { Write-Host 'Serao removidos somente os backups temporarios de exercicios/ajustes:' }
        else { Write-Host 'Serao removidos os seguintes caminhos (incluindo relatorios, prompts, planos e to-dos):' }
        foreach ($path in $paths) { Write-Host $path }
        Write-Host 'Encerre agentes que estejam usando estes arquivos. Configuracao ativa, fontes, templates e backups do workspace serao preservados.'
        if (-not $PSBoundParameters.ContainsKey('ConfirmText')) { $ConfirmText = Read-Host 'Digite LIMPAR para confirmar a exclusao; Enter ou outro texto cancela' }
        if ($ConfirmText -cne 'LIMPAR') { Write-Host 'Limpeza cancelada; historico preservado.'; return }
        # Revalidar todos os destinos antes da primeira remocao, ainda sob os locks.
        foreach ($path in $paths) { Assert-CleanupTree $path $state }
        foreach ($path in $paths) {
            # O caminho absoluto ja foi validado acima. Prefixo estendido permite
            # excluir tambem arquivos >260 caracteres no Windows PowerShell 5.1.
            $extended = if ($path.StartsWith('\\')) { '\\?\UNC\' + $path.Substring(2) } else { '\\?\' + $path }
            Remove-Item -LiteralPath $extended -Recurse -Force -ErrorAction Stop
        }
        Write-Host "Limpeza concluida: $($paths.Count) caminhos removidos."
    } finally { foreach ($lease in $leases) { $lease.Dispose() } }
}

Export-ModuleMember -Function Get-HarnessCleanupPaths, Invoke-HarnessCleanup
