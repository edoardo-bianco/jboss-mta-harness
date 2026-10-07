#requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'Harness.psm1') -DisableNameChecking

function Resolve-McpPath {
    param([string]$Value,[string]$Root,[switch]$Directory)
    $resolved=Resolve-HarnessPath $Value $Root
    if (-not $resolved -or $resolved.Length -le 3 -or $resolved.Substring(2).Contains(':')) {
        throw 'Raizes MCP exigem pasta local dedicada; raiz de disco e ADS nao sao permitidos.'
    }
    if ($Directory -and -not (Test-Path -LiteralPath $resolved -PathType Container)) { throw "Pasta do workspace ausente: $resolved" }
    return $resolved
}

function Get-HarnessMcpAllowedRoots {
    param([string]$Root,[string[]]$AllowedRoots,[string]$WorkspacePath,[string]$HarnessConfigPath,[string]$PathBase=$Root)
    $Root=Resolve-McpPath $Root $Root
    $roots=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $null=$roots.Add($Root)
    foreach ($allowed in $AllowedRoots) { $null=$roots.Add((Resolve-McpPath $allowed $Root)) }
    $projectRoots=@()
    if ($WorkspacePath) {
        $WorkspacePath=Resolve-McpPath $WorkspacePath $Root
        $workspace=Read-HarnessWorkspaceFile $WorkspacePath $Root
        foreach ($folder in $workspace.folders) {
            if (-not $folder.PSObject.Properties['path']) { throw 'MCP exige folders com path local no workspace.' }
            if ($folder.path -isnot [string] -or [string]::IsNullOrWhiteSpace($folder.path)) { throw 'Folder do workspace exige path nao vazio.' }
            $folderRoot=Resolve-McpPath $folder.path (Split-Path -Parent $WorkspacePath) -Directory
            if (Test-Path -LiteralPath (Join-Path $folderRoot 'pom.xml') -PathType Leaf) { $projectRoots+=@($folderRoot) }
            $null=$roots.Add($folderRoot)
        }
    }
    if ($HarnessConfigPath) {
        $HarnessConfigPath=Resolve-McpPath $HarnessConfigPath $Root
        $config=Get-Content -LiteralPath $HarnessConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
        if (-not $config.PSObject.Properties['schemaVersion'] -or $config.schemaVersion -ne 1 -or
            -not $config.PSObject.Properties['mta'] -or $config.mta -isnot [pscustomobject]) {
            throw 'Configuracao do harness exige schemaVersion 1 e objeto mta.'
        }
        $runs=$null
        if ($config.mta.PSObject.Properties['runsPath']) { $runs=$config.mta.runsPath }
        if ($null -ne $runs) {
            if ($runs -isnot [string] -or [string]::IsNullOrWhiteSpace($runs)) { throw 'mta.runsPath exige caminho local ou null.' }
            $runs=Resolve-McpPath $runs $PathBase
            foreach ($protected in (@($Root)+$projectRoots)) {
                if ($runs -ieq $protected -or $runs.StartsWith($protected+'\',[StringComparison]::OrdinalIgnoreCase) -or
                    $protected.StartsWith($runs+'\',[StringComparison]::OrdinalIgnoreCase)) {
                    throw 'mta.runsPath deve ficar fora do harness e dos projetos Maven, sem conte-los.'
                }
            }
            $null=$roots.Add($runs)
        }
    }
    if ($roots.Count -gt 100) { throw 'MCP permite no maximo 100 raizes de leitura.' }
    return @($roots)
}
Export-ModuleMember -Function Get-HarnessMcpAllowedRoots
