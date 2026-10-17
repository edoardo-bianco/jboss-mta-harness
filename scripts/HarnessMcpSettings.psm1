#requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'Harness.psm1') -DisableNameChecking
Import-Module (Join-Path $PSScriptRoot 'HarnessProject.psm1') -DisableNameChecking

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
        if (-not $WorkspacePath -and $config.PSObject.Properties['repositories']) {
            foreach ($repo in $config.repositories) {
                $source=Resolve-McpPath $repo.path $PathBase -Directory
                $projectRoots+=$source
                $null=$roots.Add($source)
            }
        }
    }
    foreach ($external in @(Get-HarnessProjectReadRoots $Root @($projectRoots | ForEach-Object { Join-Path $_ 'pom.xml' }))) { $null=$roots.Add($external) }
    if ($roots.Count -gt 100) { throw 'MCP permite no maximo 100 raizes de leitura.' }
    return @($roots)
}
Export-ModuleMember -Function Get-HarnessMcpAllowedRoots
