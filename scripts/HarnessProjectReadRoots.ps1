# Raizes externas declaradas nas associacoes correntes, sem inicializar registros.
function Get-HarnessProjectReadRoots {
    param([string]$Root,[string[]]$Poms)
    $projects=@($Poms | Select-Object -Unique | ForEach-Object { Get-HarnessProjectReference $Root $_ })
    $names=@{}; $roots=New-Object 'Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    foreach ($project in $projects) {
        if ($names.ContainsKey($project.Name)) { throw ('artifactId em colisao: '+$project.Name) }
        $names[$project.Name]=$true
        $lease=Enter-HarnessProjectAccess $project -ReadOnly
        try {
            if (-not (Test-Path -LiteralPath $project.ConfigPath -PathType Leaf)) { continue }
            $configuration=Get-Content -LiteralPath (Resolve-ProjectPath $project.ConfigPath $Root) -Raw -Encoding UTF8 | ConvertFrom-Json
            if ((Resolve-ProjectPath $configuration.pom $Root) -ine $project.Pom) { throw ('POM diverge da associacao corrente: '+$project.Name) }
            $external=$configuration.mta.diretorio
            if ($null -eq $external) { continue }
            if ($external -isnot [string] -or [string]::IsNullOrWhiteSpace($external)) { throw 'mta.diretorio exige caminho local dedicado ou null.' }
            $external=Resolve-ProjectPath $external $Root
            if ($external.Length -le 3 -or $external.Substring(2).Contains(':') -or $external.Contains('${')) { throw 'Origem MTA externa deve ser pasta local dedicada.' }
            $protectedRoots=@($project.Root)+@($projects | ForEach-Object Source)
            $covered=@($protectedRoots | Where-Object { $external -ieq $_ -or $external.StartsWith($_+'\',[StringComparison]::OrdinalIgnoreCase) }).Count -gt 0
            if ($covered) { continue } # Origem ja acessivel, inclusive Source/target/mta.
            foreach ($protected in $protectedRoots) {
                if ($protected.StartsWith($external+'\',[StringComparison]::OrdinalIgnoreCase)) {
                    throw 'Origem MTA nao pode ampliar leitura para uma pasta ancestral do harness ou dos projetos.'
                }
            }
            $null=$roots.Add($external)
        } finally { $lease.ReleaseMutex(); $lease.Dispose() }
    }
    @($roots)
}
