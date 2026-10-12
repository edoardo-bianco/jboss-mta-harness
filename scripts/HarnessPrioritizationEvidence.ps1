# Localizacao lexical do diagnostico; nunca acessar o checkout de outra maquina.
function Get-IncidentValue {
    param($Incident,[string]$Name)
    if ($null -ne $Incident -and $Incident.PSObject.Properties[$Name]) { $Incident.$Name }
}
function Get-IncidentLocation {
    param([string]$OriginalUri,$Project,[switch]$LexicalPaths)
    $location=[ordered]@{RelativePath=$null;SourceCandidate=$null;PathStatus='URI fora do Source local ou nao reconhecida; conferir origem/dependencia.'}
    try {
        $decoded=[Uri]::UnescapeDataString($OriginalUri).Replace('\','/')
        if ($decoded -match '(^|/)\.\.(/|$)' -or $decoded -match '[\x00-\x1f]') { throw 'URI com travessia ou controle; nenhum candidato gerado.' }
        $uri=$null; $relative=$null
        $source=[IO.Path]::GetFullPath($Project.Source).TrimEnd('\','/')
        if ([Uri]::TryCreate($OriginalUri,[UriKind]::Absolute,[ref]$uri)) {
            if (-not $uri.IsFile -or $uri.IsUnc -or $uri.Query -or $uri.Fragment) { return [pscustomobject]$location }
            $path=$uri.LocalPath.Replace('\','/')
            $prefix=$source.Replace('\','/')+'/'
            if ($path.StartsWith($prefix,[StringComparison]::OrdinalIgnoreCase)) { $relative=$path.Substring($prefix.Length) }
        } elseif ($decoded -and -not [IO.Path]::IsPathRooted($decoded) -and -not $decoded.Contains(':')) { $relative=$decoded }
        if (-not $relative) { return [pscustomobject]$location }
        $candidate=[IO.Path]::GetFullPath([IO.Path]::Combine($source,$relative))
        if (-not $candidate.StartsWith($source+'\',[StringComparison]::OrdinalIgnoreCase)) { throw 'Caminho fora do Source.' }
        $location.RelativePath=$relative; $location.SourceCandidate=$candidate
        $location.PathStatus='CANDIDATO lexical; conferir existencia, conteudo e metodo. Nao comprova aplicabilidade.'
    } catch { $location.PathStatus=$_.Exception.Message }
    [pscustomobject]$location
}
