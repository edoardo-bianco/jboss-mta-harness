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

function Get-HarnessGitState {
    param($Context)
    $state = [ordered]@{Status='UNAVAILABLE';CheckedAtUtc=[DateTime]::UtcNow.ToString('o');Source=$Context.Active.path;RepositoryRoot=$null;Module=$null;Branch=$null;Head=$null;Detached=$null;HasChanges=$null;HasConflicts=$null;Changes=@();Problem=$null}
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
        $state.Status = 'VERIFIED'
    } catch { $state.Problem = $_.Exception.Message }
    [pscustomobject]$state
}

# gitPolicies legadas sao ignoradas; esta coleta nao cadastra nem bloqueia branches.
Export-ModuleMember -Function Get-HarnessGitState
