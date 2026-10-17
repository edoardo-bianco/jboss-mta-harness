#requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot '../../scripts/HarnessProject.psm1') -DisableNameChecking
Import-Module (Join-Path $PSScriptRoot 'ConversaoPublicacao.psm1') -DisableNameChecking
Import-Module (Join-Path $PSScriptRoot 'ConversaoValidacao.psm1') -DisableNameChecking
. (Join-Path $PSScriptRoot 'LegadoLeitura.ps1')
. (Join-Path $PSScriptRoot '../../scripts/HarnessCleanupFiles.ps1')
. (Join-Path $PSScriptRoot '../../scripts/HarnessSprintState.ps1')
. (Join-Path $PSScriptRoot 'ConversaoLimpezaAcesso.ps1')
. (Join-Path $PSScriptRoot 'ConversaoLimpezaCandidatos.ps1')

function Get-ConversionCleanupPreview {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][string]$Workspace,[Parameter(Mandatory=$true)][string]$Pom,[string]$SourceLegado,[string]$Registro,[string]$Contexto,[string]$MtaDiretorio,[string[]]$PrioritizacaoContexto=@(),[string]$BuildResultado,[string]$SonarResultado,[string]$SonarTentativa,[Collections.IDictionary]$Participantes=@{},[object[]]$Sprints=@())
    $access=Open-ConversionCleanupAccess $Workspace $Pom
    try {
        $recovery=Get-ConversionDiscardRecovery $access
        if ($recovery) {
            return [pscustomobject]@{Status='RECUPERACAO_PENDENTE';Project=$access.Project.Name;Candidates=@($recovery.Paths | ForEach-Object {[pscustomobject]@{Path=$_;Destination=$null;Eligible=$false;Reason='Recuperar explicitamente antes de reconstruir a selecao.'}});RecoveryPath=$recovery.Path;DeletionAuthorized=$false}
        }
        $selection=New-ConversionCleanupSelection $access $PSBoundParameters
        [pscustomobject]@{Status='PREVIA';Project=$access.Project.Name;Candidates=$selection.Candidates;RecoveryPath=$null;DeletionAuthorized=$false}
    } finally { Close-ConversionCleanupAccess $access }
}
function Invoke-ConversionCleanup {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][string]$Workspace,[Parameter(Mandatory=$true)][string]$Pom,[string]$SourceLegado,[string]$Registro,[string]$Contexto,[string]$MtaDiretorio,[string[]]$PrioritizacaoContexto=@(),[string]$BuildResultado,[string]$SonarResultado,[string]$SonarTentativa,[Collections.IDictionary]$Participantes=@{},[object[]]$Sprints=@(),[string[]]$Descartar=@(),[string]$ConfirmText)
    $options=@{}; foreach ($key in $PSBoundParameters.Keys) { if ($key -notin @('Descartar','ConfirmText')) { $options[$key]=$PSBoundParameters[$key] } }
    $access=Open-ConversionCleanupAccess $Workspace $Pom
    try {
        $paths=@($Descartar | ForEach-Object {Assert-ConversionDiscardPath $_ $access} | Sort-Object -Unique)
        $recovery=Get-ConversionDiscardRecovery $access
        if ($recovery) {
            if ((@($recovery.Paths | Sort-Object -Unique) -join "`n") -ine ($paths -join "`n")) { throw 'Recuperacao exige exatamente os arquivos do journal; sem journal, omita Descartar.' }
            foreach ($path in $paths) { Write-Host ('Restaurar original: '+$path) }
            if (-not $paths.Count) { Write-Host 'Remover somente o estagio tecnico sem journal; arquivos legados permanecem como estao.' }
            if (-not $PSBoundParameters.ContainsKey('ConfirmText')) { $ConfirmText=Read-Host 'Digite RECUPERAR para restaurar os originais; nenhum descarte sera iniciado' }
            if ($ConfirmText -cne 'RECUPERAR') { return [pscustomobject]@{Status='CANCELADO';RemovedFiles=@()} }
            Assert-CleanupAssociationsUnchanged $access.Project.Root $access.Associations
            Assert-CleanupFileTreeUnchanged $recovery.Tree
            $null=Get-ConversionDiscardRecovery $access
            $lease=Enter-HarnessProjectAccess $access.Discard
            try { } finally { $lease.ReleaseMutex(); $lease.Dispose() }
            return [pscustomobject]@{Status='RECUPERADO';RemovedFiles=@()}
        }
        if (-not $paths.Count) { throw 'Selecione explicitamente os arquivos em Descartar antes de limpar.' }
        $existing=@($paths | Where-Object {Test-Path -LiteralPath $_ -PathType Leaf})
        if (-not $existing.Count) {
            $valid=Test-ConversionCurrent $access.Project.Root $access.Project.Pom
            if (-not $valid.Valid) { throw ('Destino corrente pendente: '+($valid.Diagnostics -join ' ')) }
            return [pscustomobject]@{Status='SEM_RESIDUOS';RemovedFiles=@()}
        }
        if ($existing.Count -ne $paths.Count) { throw 'Selecao parcialmente ausente sem journal: confira os originais antes de descartar.' }
        $selection=New-ConversionCleanupSelection $access $options
        foreach ($path in $paths) {
            $candidate=@($selection.Candidates | Where-Object Path -IEQ $path)
            if ($candidate.Count -ne 1 -or -not $candidate[0].Eligible) { throw ('Arquivo sem comprovacao de descarte exclusivo: '+$path) }
            Write-Host ($path+' -> '+$candidate[0].Destination)
        }
        if (-not $PSBoundParameters.ContainsKey('ConfirmText')) { $ConfirmText=Read-Host 'Digite LIMPAR para descartar somente esses arquivos; outro texto cancela' }
        if ($ConfirmText -cne 'LIMPAR') { return [pscustomobject]@{Status='CANCELADO';RemovedFiles=@()} }
        # Recomputar as fontes selecionadas tambem confere MTA e anexos binarios
        # que nao participam da leitura textual do grafo de consumidores.
        $null=Invoke-ConversionApply @options -VerifyOnly
        $valid=Test-ConversionCurrent $access.Project.Root $access.Project.Pom
        if (-not $valid.Valid) { throw ('Destino corrente pendente: '+($valid.Diagnostics -join ' ')) }
        # Conferir o conjunto depois das validacoes demoradas: uma contribuicao
        # recebida nesse intervalo tambem invalida a selecao mostrada ao humano.
        Assert-CleanupAssociationsUnchanged $access.Project.Root $access.Associations
        Assert-ConversionUnchanged $selection.State.Inputs.Session $selection.State.Inputs.Inventory
        if ((@(Get-ConversionDiscardTextInventory $access) -join "`n") -cne ($selection.Graph.TextInventory -join "`n")) { throw 'Inventario textual legado mudou durante a confirmacao; descarte recusado.' }
        foreach ($entry in $selection.CurrentTrees) { Assert-CleanupFileTreeUnchanged $entry.Tree }
        foreach ($tree in $selection.OriginTrees) { Assert-CleanupFileTreeUnchanged $tree }
        foreach ($tree in $selection.Graph.Folders) { Assert-CleanupFileTreeUnchanged $tree }
        if (Get-ConversionDiscardRecovery $access) { throw 'Area de recuperacao surgiu durante a confirmacao; nenhum descarte iniciado.' }
        $files=@{}; $expected=@{}
        foreach ($path in $paths) {
            $null=Assert-ConversionDiscardPath $path $access
            if ([IO.File]::GetLastWriteTimeUtc($path).Ticks -ne $selection.Files[$path].Ticks -or
                [Convert]::ToBase64String([IO.File]::ReadAllBytes($path)) -cne [Convert]::ToBase64String($selection.Files[$path].Bytes)) { throw 'Origem alterada durante a confirmacao; descarte recusado.' }
            $relative=$path.Substring($access.Discard.Folder.Length+1).Replace('\','/')
            $files[$relative]=$null; $expected[$relative]=$selection.Files[$path].Bytes
        }
        Publish-HarnessProjectFiles $access.Discard $files $expected
        [pscustomobject]@{Status='LIMPO';Project=$access.Project.Name;RemovedFiles=$paths}
    } finally { Close-ConversionCleanupAccess $access }
}
Export-ModuleMember -Function Get-ConversionCleanupPreview,Invoke-ConversionCleanup
