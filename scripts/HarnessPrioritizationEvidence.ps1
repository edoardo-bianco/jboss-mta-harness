# Utilitarios de localizacao ainda consumidos pelo planejamento/consultas legados.
# O fluxo corrente usa HarnessIssueSources.ps1 e nao gera extratos de incidentes.
function Get-IncidentValue {
    param($Incident, [string]$Name)
    if ($null -ne $Incident -and $Incident.PSObject.Properties[$Name]) { $Incident.$Name }
}

function Get-IncidentLocation {
    param([string]$OriginalUri, $Project, [switch]$LexicalPaths)
    $location = [ordered]@{RelativePath=$null;SnapshotCandidate=$null;SourceCandidate=$null;PathStatus='URI fora do input ou nao reconhecida; conferir origem/dependencia.'}
    try {
        # Conferir antes de Uri/GetFullPath, que normalizam e ocultam segmentos .. .
        $decoded = [Uri]::UnescapeDataString($OriginalUri).Replace('\','/')
        if ($decoded -match '(^|/)\.\.(/|$)' -or $decoded -match '[\x00-\x1f]') { throw 'URI com travessia ou caracteres de controle; nenhum candidato gerado.' }
        $uri = $null
        if (-not [Uri]::TryCreate($OriginalUri, [UriKind]::Absolute, [ref]$uri) -or
            -not $uri.IsFile -or $uri.IsUnc -or $uri.Query -or $uri.Fragment) { return [pscustomobject]$location }
        $path = $uri.LocalPath.Replace('\','/')
        $relative = $null
        foreach ($prefix in @($Project.Mta.AnalysisSource, ($Project.Mta.MtaOrigin.Run.TrimEnd('\','/') + '/input'))) {
            $prefix = $prefix.Replace('\','/').TrimEnd('/') + '/'
            if ($path.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) { $relative = $path.Substring($prefix.Length); break }
        }
        if (-not $relative) {
            # Rodadas recebidas podem conservar a raiz antiga do harness. A pasta
            # input isolada tambem existe em dependencias: exigir formato conhecido
            # e identidade da rodada antes de associar o sufixo ao projeto atual.
            $runId = [string]$Project.Mta.RunId
            if ($runId -notmatch '^[a-fA-F0-9]{32}$') { return [pscustomobject]$location }
            $legacyRun = '(?:' + $runId + '|mta_\d{4}-\d{2}-\d{2}_\d{2}-\d{2}-\d{2}[+-]\d{4}__' + $runId.Substring(0,12) + ')'
            $markers = [regex]::Matches($path, ('(?i)/\.harness/runs/[^/]+/' + $legacyRun + '/input/'))
            if ($markers.Count -ne 1) { return [pscustomobject]$location }
            $relative = $path.Substring($markers[0].Index + $markers[0].Length)
        }
        if (-not $relative -or [IO.Path]::IsPathRooted($relative) -or $relative.Contains(':')) { return [pscustomobject]$location }
        $candidates = @(foreach ($base in @($Project.Mta.AnalysisSource, $Project.Source)) {
            if ($LexicalPaths) {
                # Consultas nao acessam a maquina/origem historica nem provam existencia.
                if ($base -notmatch '^[A-Za-z]:[\\/]') { throw 'Candidato exige raiz local absoluta.' }
                $rootPath = [IO.Path]::GetFullPath($base).TrimEnd('\','/')
                $candidate = [IO.Path]::GetFullPath([IO.Path]::Combine($rootPath,$relative))
            } else {
                $rootPath = Resolve-HarnessPath $base $base
                $candidate = Resolve-HarnessPath (Join-Path $rootPath $relative) $rootPath
            }
            if (-not $candidate.StartsWith(($rootPath + '\'), [StringComparison]::OrdinalIgnoreCase)) { throw 'Caminho fora da raiz permitida.' }
            $candidate
        })
        $location.RelativePath = $relative
        $location.SnapshotCandidate = $candidates[0]
        $location.SourceCandidate = $candidates[1]
        $location.PathStatus = 'CANDIDATOS por caminho relativo; conferir existencia, conteudo e metodo. Nao comprovam aplicabilidade.'
    } catch { $location.PathStatus = $_.Exception.Message }
    [pscustomobject]$location
}
