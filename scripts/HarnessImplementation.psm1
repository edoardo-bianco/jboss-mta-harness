#requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'HarnessGit.psm1') -DisableNameChecking

function Get-ImplementationBatchId {
    param([string]$PlanPath, [string]$TodoPath)
    $ids = foreach ($path in @($PlanPath,$TodoPath)) {
        $found = @()
        $fence = $null
        foreach ($line in Get-Content -LiteralPath $path -Encoding UTF8) {
            if ($line -match '^\s*(`{3,}|~{3,})') {
                $marker = $Matches[1].Substring(0,1)
                if (-not $fence) { $fence = $marker } elseif ($fence -eq $marker) { $fence = $null }
                continue
            }
            if ($fence) { continue }
            $plain = $line.Trim().Replace('*','').Replace('`','') -replace '^[-+]\s+', ''
            if ($plain -match '^(?:Lote ativo|ID do lote)\s*:\s*(.+)$') { $found += $Matches[1].Trim() }
        }
        $unique = @($found | Sort-Object -Unique -CaseSensitive)
        if ($unique.Count -ne 1 -or $unique[0] -cnotmatch '^[A-Za-z0-9][A-Za-z0-9._-]{0,99}$') { return $null }
        $unique[0]
    }
    if ($ids.Count -eq 2 -and $ids[0] -ceq $ids[1]) { return $ids[0] }
    return $null
}

function Select-ImplementationBranch {
    param($Context, $Prepared)
    $observed = Get-HarnessGitState $Context
    $batchId = Get-ImplementationBatchId $Prepared.PlanPath $Prepared.TodoPath
    while ($true) {
        Write-Host "Fonte da aplicacao: $($Context.Active.path)"
        Write-Host "Repositorio Git: $($observed.RepositoryRoot) | Branch atual: $($observed.Branch) | HEAD: $($observed.Head)"
        if ($observed.Status -ne 'VERIFIED') { Write-Host 'Git indisponivel; continuar no estado atual nao altera Git.' }
        elseif ($observed.Detached) { Write-Host 'HEAD destacado: nao ha branch selecionada.' }
        Write-Host 'Decida onde trabalhar. Criar uma branch nao concede GO para a corretiva.'
        Write-Host 'A escolha vale para todo o checkout da aplicacao; nao troque um checkout usado por outro agente.'
        if ($batchId) { Write-Host "1. Criar e usar lote/$batchId, localmente, a partir do HEAD exibido" }
        else { Write-Host 'Nome automatico indisponivel; escolha branch atual ou nome manual.' }
        Write-Host '2. Usar a branch atual (continuar sem alterar Git)'
        Write-Host '3. Criar e usar uma branch local com nome informado'
        $choice = Read-Host 'Escolha explicitamente uma opcao; Enter/q cancela'
        if ($choice -eq '2') { return $observed }
        if ($choice -eq '1' -and $batchId) { $name = 'lote/' + $batchId }
        elseif ($choice -eq '3') {
            $name = (Read-Host 'Nome completo da nova branch (ex.: lote/minha-corretiva); Enter/q cancela').Trim()
            if (-not $name -or $name -eq 'q') { throw 'Escolha de branch cancelada.' }
        } else { throw 'Escolha de branch cancelada ou invalida; Git nao alterado.' }
        if ($observed.Status -ne 'VERIFIED') { throw 'Nao foi possivel criar branch: Git/HEAD indisponivel. Use a opcao 2 para continuar sem alterar Git.' }
        foreach ($key in @('Context','Plan','Todo')) {
            $hash = (Get-FileHash -LiteralPath $Prepared.($key + 'Path') -Algorithm SHA256).Hash
            if ($hash -cne $Prepared.($key + 'Sha256')) { throw 'Documentos alterados depois do preparo; prepare novamente antes de criar a branch.' }
        }
        $current = Get-HarnessGitState $Context
        if ($current.Status -ne 'VERIFIED' -or $current.RepositoryRoot -ine $observed.RepositoryRoot -or
            $current.Head -cne $observed.Head -or $current.Branch -cne $observed.Branch) {
            throw 'Repositorio/HEAD/branch mudou durante a escolha; repita para confirmar o estado atual.'
        }
        $saved = $ErrorActionPreference
        $creationError = $null
        try {
            $ErrorActionPreference = 'Continue'
            $validation = @(& git -C $Context.Active.path check-ref-format --branch $name 2>&1)
            if ($LASTEXITCODE -ne 0 -or $validation.Count -ne 1 -or [string]$validation[0] -cne $name -or
                $name.StartsWith('-') -or $name -match '[\x00-\x1f\x7f]') { throw 'Nome de branch invalido; Git nao alterado.' }
            # -c e transacional: nao sobrescreve branch existente. Nunca usar -C/-f/reset/stash.
            # --no-track impede herdar upstream; a base e o HEAD que o operador viu.
            $output = @(& git -C $Context.Active.path switch --no-track -c $name $observed.Head 2>&1)
            if ($LASTEXITCODE -ne 0) { throw ('Git recusou criar/selecionar a branch: ' + ($output -join ' ')) }
        } catch { $creationError = $_.Exception.Message }
        finally { $ErrorActionPreference = $saved }
        if ($creationError) {
            Write-Host $creationError
            Write-Host 'Escolha 2 para continuar na branch atual ou 3 para informar outro nome; Enter/q cancela.'
            $batchId = $null
            $observed = Get-HarnessGitState $Context
            continue
        }
        $after = Get-HarnessGitState $Context
        if ($after.Status -ne 'VERIFIED' -or $after.Branch -cne $name -or $after.Head -cne $observed.Head) {
            throw 'Nao foi possivel confirmar o estado apos criar a branch. Confira Git antes de prosseguir; nao houve reversao automatica.'
        }
        Write-Host "Branch local criada e selecionada: $name. Sem commit/push; confira as alteracoes locais preservadas."
        return $after
    }
}

Export-ModuleMember -Function Get-ImplementationBatchId, Select-ImplementationBranch
