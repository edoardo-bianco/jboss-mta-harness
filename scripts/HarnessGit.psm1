#requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Invoke-HarnessGitRead {
    param([string]$Source, [string[]]$Arguments, [switch]$AllowFailure)
    $saved = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $output = @(& git --no-optional-locks -c core.quotepath=false -C $Source @Arguments 2>&1)
        $code = $LASTEXITCODE
    } finally { $ErrorActionPreference = $saved }
    if ($code -ne 0 -and -not $AllowFailure) { throw "Consulta Git falhou: $($Arguments[0]) (exit $code)." }
    [pscustomobject]@{Code=$code; Text=($output -join "`n").TrimEnd("`r","`n")}
}

function Get-HarnessGitPolicy {
    param($Context)
    if (-not $Context.Config.PSObject.Properties['gitPolicies']) { return }
    $matches = @($Context.Config.gitPolicies | Where-Object {
        [IO.Path]::GetFullPath($_.source).TrimEnd('\','/') -ieq [IO.Path]::GetFullPath($Context.Active.path).TrimEnd('\','/')
    })
    if ($matches.Count -gt 1) { throw 'Mais de uma politica Git para Source; ajuste gitPolicies no JSON local.' }
    if ($matches.Count) { $matches[0] }
}

function Get-HarnessGitState {
    param($Context)
    $state = [ordered]@{Status='UNAVAILABLE';CheckedAtUtc=[DateTime]::UtcNow.ToString('o');Source=$Context.Active.path;RepositoryRoot=$null;Module=$null;Branch=$null;Head=$null;Detached=$null;HasChanges=$null;HasConflicts=$null;OperationInProgress=$null;Changes=@();StateSha256=$null;Policy=$null;MainHead=$null;MigrationHead=$null;MainInMigration=$null;MigrationInWork=$null;Problem=$null}
    try {
        $source = $Context.Active.path
        $state.RepositoryRoot = [IO.Path]::GetFullPath((Invoke-HarnessGitRead $source @('rev-parse','--show-toplevel')).Text).TrimEnd('\','/')
        $state.Module = (Invoke-HarnessGitRead $source @('rev-parse','--show-prefix')).Text.TrimEnd('/')
        $state.Head = (Invoke-HarnessGitRead $source @('rev-parse','--verify','HEAD')).Text
        $branch = Invoke-HarnessGitRead $source @('symbolic-ref','--quiet','--short','HEAD') -AllowFailure
        $state.Detached = $branch.Code -ne 0
        if (-not $state.Detached) { $state.Branch = $branch.Text }
        $changes = (Invoke-HarnessGitRead $state.RepositoryRoot @('status','--porcelain=v1','--untracked-files=all')).Text
        $state.Changes = @($changes -split "`n" | Where-Object { $_ })
        $state.HasChanges = $state.Changes.Count -gt 0
        $state.HasConflicts = [bool]($state.Changes | Where-Object { $_ -match '^(DD|AU|UD|UA|DU|AA|UU) ' })
        $state.OperationInProgress = $false
        foreach ($marker in @('MERGE_HEAD','CHERRY_PICK_HEAD','REVERT_HEAD','rebase-merge','rebase-apply','BISECT_START')) {
            $markerPath = (Invoke-HarnessGitRead $state.RepositoryRoot @('rev-parse','--git-path',$marker)).Text
            if (-not [IO.Path]::IsPathRooted($markerPath)) { $markerPath = Join-Path $state.RepositoryRoot $markerPath }
            if (Test-Path -LiteralPath $markerPath) { $state.OperationInProgress = $true }
        }
        # Nao persistir diffs/conteudos: registrar somente um digest do estado local.
        $fingerprint = $changes + (Invoke-HarnessGitRead $state.RepositoryRoot @('diff','--no-ext-diff','--no-textconv','--binary','HEAD','--')).Text
        $untracked = (Invoke-HarnessGitRead $state.RepositoryRoot @('ls-files','--others','--exclude-standard','-z')).Text
        foreach ($relative in ($untracked -split "`0" | Where-Object { $_ })) {
            $path = [IO.Path]::GetFullPath((Join-Path $state.RepositoryRoot $relative))
            if (-not $path.StartsWith($state.RepositoryRoot + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Arquivo Git fora da raiz.' }
            $item = Get-Item -LiteralPath $path -Force
            if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint -or $item.PSIsContainer) { throw 'Arquivo Git nao regular; estado local nao verificavel.' }
            $fingerprint += $relative + (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
        }
        $sha = [Security.Cryptography.SHA256]::Create()
        try { $state.StateSha256 = ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($fingerprint)))).Replace('-','') }
        finally { $sha.Dispose() }
        $state.Policy = Get-HarnessGitPolicy $Context
        if ($state.Policy) {
            foreach ($pair in @(@('mainBranch','MainHead'),@('migrationBranch','MigrationHead'))) {
                $ref = 'refs/heads/' + $state.Policy.($pair[0])
                $resolved = Invoke-HarnessGitRead $state.RepositoryRoot @('rev-parse','--verify',($ref + '^{commit}')) -AllowFailure
                if ($resolved.Code -eq 0) { $state.($pair[1]) = $resolved.Text }
            }
            if ($state.MainHead -and $state.MigrationHead) { $state.MainInMigration = (Invoke-HarnessGitRead $state.RepositoryRoot @('merge-base','--is-ancestor',$state.MainHead,$state.MigrationHead) -AllowFailure).Code -eq 0 }
            if ($state.MigrationHead) { $state.MigrationInWork = (Invoke-HarnessGitRead $state.RepositoryRoot @('merge-base','--is-ancestor',$state.MigrationHead,$state.Head) -AllowFailure).Code -eq 0 }
        }
        $state.Status = 'VERIFIED'
    } catch { $state.Problem = $_.Exception.Message }
    [pscustomobject]$state
}

function Test-HarnessGitState {
    param($Context, $Baseline)
    $current = Get-HarnessGitState $Context
    $reasons = New-Object 'Collections.Generic.List[string]'
    if ($current.Status -ne 'VERIFIED') { $reasons.Add('Git atual indisponivel: ' + $current.Problem) }
    if (-not $Baseline -or $Baseline.Status -ne 'VERIFIED') { $reasons.Add('Contexto sem evidencia Git valida; prepare novo contexto.') }
    elseif ($current.Status -eq 'VERIFIED') {
        foreach ($field in @('Source','RepositoryRoot','Branch','Head','StateSha256')) {
            if ($current.$field -cne $Baseline.$field) { $reasons.Add("$field mudou desde o planejamento; reconciliar o lote.") }
        }
        if (($current.Policy | ConvertTo-Json -Depth 6 -Compress) -cne ($Baseline.Policy | ConvertTo-Json -Depth 6 -Compress)) { $reasons.Add('Politica de branches mudou; prepare contexto com as escolhas atuais.') }
    }
    $policy = $current.Policy
    if (-not $policy) { $reasons.Add('Defina as branches principal, migracao e trabalho autorizado em gitPolicies.') }
    else {
        foreach ($field in @('repositoryRoot','mainBranch','migrationBranch','workBranch','owner','coordination')) {
            if (-not $policy.PSObject.Properties[$field] -or -not $policy.$field) { $reasons.Add("Politica Git sem $field.") }
        }
        if ($reasons.Count -eq 0) {
            if ([IO.Path]::GetFullPath($policy.repositoryRoot).TrimEnd('\','/') -ine $current.RepositoryRoot) { $reasons.Add('Repositorio diferente do autorizado.') }
            if ($policy.mainBranch -eq $policy.migrationBranch -or $policy.mainBranch -eq $policy.workBranch) { $reasons.Add('Corretivas exigem branch separada da principal.') }
            if ($current.Branch -cne $policy.workBranch) { $reasons.Add('Branch atual diferente da branch de trabalho autorizada.') }
            if ($current.MainInMigration -ne $true -or $current.MigrationInWork -ne $true) { $reasons.Add('Referencias locais ausentes ou principal/migracao/trabalho sem alinhamento comprovado.') }
        }
    }
    if ($current.Detached) { $reasons.Add('HEAD destacado.') }
    if ($current.HasConflicts -or $current.OperationInProgress) { $reasons.Add('Conflito ou operacao Git em andamento.') }
    if ($current.HasChanges) { $reasons.Add('Alteracoes locais exigem revisao de autoria/escopo antes de executar; nao limpar automaticamente.') }
    [pscustomobject]@{Ready=($reasons.Count -eq 0);Scope='Git somente; nao concede GO humano nem valida runtime/testes';Current=$current;Reasons=@($reasons)}
}

function Set-HarnessGitPolicyInteractive {
    param($Context)
    $state = Get-HarnessGitState $Context
    if ($state.Status -ne 'VERIFIED') { throw ('Nao foi possivel identificar o repositorio: ' + $state.Problem) }
    Write-Host "Repositorio: $($state.RepositoryRoot) | Modulo: $($state.Module) | Branch atual: $($state.Branch)"
    if ($state.RepositoryRoot -ieq $Context.Root) { Write-Host 'Este exemplo compartilha o repositorio do harness. Cadastrar nomes nao isola a aplicacao nem troca a branch.' }
    Write-Host 'Principal: evolutivas normais (ex.: main/develop). Migracao: integra corretivas (ex.: main_jboss_eap74).'
    Write-Host 'Trabalho autorizado: branch do lote ou a propria migracao no trabalho individual. Nunca a principal.'
    Write-Host 'Estas escolhas apenas registram a politica; nao criam/trocam branches, nao fazem merge e nao concedem GO.'
    $branches = @((Invoke-HarnessGitRead $state.RepositoryRoot @('for-each-ref','--format=%(refname:short)','refs/heads/')).Text -split "`n" | Where-Object { $_ })
    for ($i=0; $i -lt $branches.Count; $i++) { Write-Host ("{0}. {1}" -f ($i+1),$branches[$i]) }
    $policy = [ordered]@{source=$Context.Active.path;repositoryRoot=$state.RepositoryRoot}
    foreach ($pair in @(@('mainBranch','principal'),@('migrationBranch','de migracao'),@('workBranch','de trabalho autorizada'))) {
        $answer = Read-Host "Branch $($pair[1]): numero da lista ou nome planejado (q cancela)"
        if (-not $answer -or $answer -eq 'q') { throw 'Cadastro de branches cancelado; configuracao preservada.' }
        $number=0
        if ([int]::TryParse($answer,[ref]$number)) {
            if ($number -lt 1 -or $number -gt $branches.Count) { throw 'Numero de branch invalido.' }
            $answer=$branches[$number-1]
        }
        if ($answer.StartsWith('-') -or $answer.Contains('@{') -or (Invoke-HarnessGitRead $state.RepositoryRoot @('check-ref-format','--branch',$answer) -AllowFailure).Code -ne 0) { throw 'Nome de branch invalido.' }
        $policy[$pair[0]]=$answer
    }
    if ($policy.mainBranch -eq $policy.migrationBranch -or $policy.mainBranch -eq $policy.workBranch) { throw 'Migracao e trabalho devem ser separados da principal.' }
    $policy.owner = Read-Host 'Responsavel pela frente/lote'
    $policy.coordination = Read-Host 'Referencia de coordenacao (issue, ticket ou identificador do ensaio individual)'
    if (-not $policy.owner -or -not $policy.coordination) { throw 'Informe responsavel e coordenacao; configuracao preservada.' }
    Write-Host "Principal: $($policy.mainBranch) | Migracao: $($policy.migrationBranch) | Trabalho: $($policy.workBranch)"
    if ((Read-Host 'Enter salva essas escolhas; q cancela') -ne '') { throw 'Cadastro cancelado.' }
    $config = Get-Content -LiteralPath $Context.ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $existing=@()
    if ($config.PSObject.Properties['gitPolicies']) { $existing=@($config.gitPolicies | Where-Object { [IO.Path]::GetFullPath($_.source).TrimEnd('\','/') -ine [IO.Path]::GetFullPath($Context.Active.path).TrimEnd('\','/') }) }
    $config | Add-Member NoteProperty gitPolicies @($existing + [pscustomobject]$policy) -Force
    [IO.File]::WriteAllText($Context.ConfigPath, ($config | ConvertTo-Json -Depth 12), (New-Object Text.UTF8Encoding($false)))
    $Context.Config | Add-Member NoteProperty gitPolicies $config.gitPolicies -Force
    Write-Host 'Escolhas salvas em gitPolicies no JSON local. Referencias locais nao comprovam alinhamento remoto.'
}

Export-ModuleMember -Function Get-HarnessGitState, Get-HarnessGitPolicy, Test-HarnessGitState, Set-HarnessGitPolicyInteractive
