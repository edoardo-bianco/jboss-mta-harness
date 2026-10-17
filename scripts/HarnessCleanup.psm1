#requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'HarnessProject.psm1') -DisableNameChecking
. (Join-Path $PSScriptRoot 'HarnessCleanupFiles.ps1')

function Open-CleanupSelection {
    param([string]$Root,[string]$Source,[switch]$All,[switch]$TemporaryBackups)
    if (([int][bool]$Source+[int][bool]$All+[int][bool]$TemporaryBackups) -ne 1) { throw 'Escolha somente Source, All ou TemporaryBackups para limpar.' }
    $Root=Resolve-ProjectPath $Root $Root
    $associations=Get-CleanupAssociations $Root
    $projects=@(); $leases=@(); $guards=@(); $trees=@()
    try {
        if ($TemporaryBackups) {
            $path=Resolve-ProjectPath '.harness/backups-temporarios' $Root
            Assert-CleanupProtectedPath $path $Root $associations
            $trees+=Get-CleanupFileTree $path
        } else {
            $selected=@($associations.Items)
            if ($Source) {
                $localSource=Resolve-ProjectPath $Source $Root
                $selected=@($selected | Where-Object Source -IEQ $localSource)
            }
            $names=[string[]]@($selected | ForEach-Object Name); [Array]::Sort($names,[StringComparer]::Ordinal)
            foreach ($name in $names) {
                $entry=@($selected | Where-Object Name -CEQ $name)[0]
                $guards+=[IO.File]::Open($entry.Pom,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read)
                $project=Get-HarnessProjectReference $Root $entry.Pom
                if ($project.Name -cne $name -or $project.Folder -ine $entry.Folder) { throw 'Identidade Maven diverge da pasta associada; confira antes de limpar.' }
                $projects+=$project
            }
            foreach ($project in $projects) {
                # Recusar recuperacao pendente antes de qualquer acesso que a execute.
                $leases+=Enter-HarnessProjectAccess $project -ReadOnly
                $leases+=Enter-HarnessProjectAccess $project -ForOperation
            }
            foreach ($project in $projects) {
                foreach ($family in @('build','mta','sonar')) {
                    $path=Resolve-ProjectPath (Join-Path $project.TemporaryPath $family) $Root
                    Assert-CleanupProtectedPath $path $Root $associations
                    $trees+=Get-CleanupFileTree $path
                }
            }
        }
        Assert-CleanupAssociationsUnchanged $Root $associations
        [pscustomobject]@{Root=$Root;Projects=$projects;Trees=$trees;Associations=$associations;Leases=$leases;Guards=$guards}
    } catch {
        for ($i=$leases.Count-1;$i -ge 0;$i--) { $leases[$i].ReleaseMutex(); $leases[$i].Dispose() }
        foreach ($guard in $guards) { $guard.Dispose() }
        throw
    }
}
function Close-CleanupSelection {
    param($Selection)
    for ($i=$Selection.Leases.Count-1;$i -ge 0;$i--) { $Selection.Leases[$i].ReleaseMutex(); $Selection.Leases[$i].Dispose() }
    foreach ($guard in $Selection.Guards) { $guard.Dispose() }
}
function Get-HarnessCleanupPaths {
    param([string]$Root,[string]$Source,[switch]$All,[switch]$TemporaryBackups)
    $selection=Open-CleanupSelection @PSBoundParameters
    try { @($selection.Trees | ForEach-Object {$_.Files.Keys}) | Sort-Object -Unique }
    finally { Close-CleanupSelection $selection }
}
function Invoke-HarnessCleanup {
    param([string]$Root,[string]$Source,[switch]$All,[switch]$TemporaryBackups,[string]$ConfirmText)
    $selection=Open-CleanupSelection $Root -Source $Source -All:$All -TemporaryBackups:$TemporaryBackups
    try {
        $paths=@($selection.Trees | ForEach-Object {$_.Files.Keys} | Sort-Object -Unique)
        if (-not $paths.Count) { Write-Host 'Nenhum residuo encontrado neste escopo.'; return }
        if ($TemporaryBackups) { Write-Host 'Backups temporarios selecionados:' }
        else { Write-Host 'Residuos temporarios de build, MTA e Sonar selecionados:' }
        foreach ($path in $paths) { Write-Host $path }
        Write-Host 'Dados correntes, evidencias, fontes, MTA externo, recebidos e conciliacoes pendentes sao preservados.'
        if (-not $PSBoundParameters.ContainsKey('ConfirmText')) { $ConfirmText=Read-Host 'Digite LIMPAR para confirmar; Enter ou outro texto cancela' }
        if ($ConfirmText -cne 'LIMPAR') { Write-Host 'Limpeza cancelada; arquivos preservados.'; return }
        Assert-CleanupAssociationsUnchanged $selection.Root $selection.Associations
        foreach ($tree in $selection.Trees) { Assert-CleanupFileTreeUnchanged $tree }
        if ($TemporaryBackups) { foreach ($tree in $selection.Trees) { Remove-CleanupBackupFiles $tree } }
        else {
            foreach ($project in $selection.Projects) {
                $files=@{}; $expected=@{}; $directories=@()
                foreach ($tree in $selection.Trees) {
                    if (-not $tree.Path.StartsWith($project.TemporaryPath+'\',[StringComparison]::OrdinalIgnoreCase)) { continue }
                    $directories+=$tree.Directories
                    foreach ($path in $tree.Files.Keys) {
                        $relative=$path.Substring($project.Folder.Length+1).Replace('\','/')
                        $files[$relative]=$null; $expected[$relative]=$tree.Files[$path].Bytes
                    }
                }
                if ($files.Count) { Publish-HarnessProjectFiles $project $files $expected -RemoveTemporaryFiles }
                Remove-CleanupEmptyDirectories $directories
            }
        }
        Write-Host "Limpeza concluida: $($paths.Count) arquivos removidos."
    } finally { Close-CleanupSelection $selection }
}
Export-ModuleMember -Function Get-HarnessCleanupPaths,Invoke-HarnessCleanup
