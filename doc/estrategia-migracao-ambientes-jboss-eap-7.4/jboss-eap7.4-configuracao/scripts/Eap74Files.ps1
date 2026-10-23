function New-EapFiles {
    param($Config,[string]$Stage)
    $entries=@()
    if ($Config.PSObject.Properties['files']) { $entries=$Config.files }
    if ($null -eq $entries -or $entries -isnot [array]) { throw 'files deve ser uma lista, inclusive quando vazia.' }
    $destinations=New-Object 'Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    foreach ($entry in $entries) {
        $target=[string](Get-EapField $entry 'target' '')
        $parts=@($target.Replace('\','/').Split('/'))
        foreach ($part in $parts) {
            if ($part -notmatch '^[A-Za-z0-9_-][A-Za-z0-9_. -]*$' -or $part -match '[ .]$' -or
                $part -match '^(?i:CON|PRN|AUX|NUL|COM[0-9]|LPT[0-9])(?:\.|$)') { throw 'Destino de arquivo externo invalido: use caminho relativo simples, sem .., raiz ou nomes reservados.' }
        }
        if ($parts[0] -match '^(?i:standalone.*\.xml|standalone_xml_history|logging\.properties)$' -or
            $target -ieq $Config.standaloneConfig) { throw 'Destino de arquivo externo reservado ao servidor ou ao gerador.' }
        $relative='standalone\configuration\'+($parts -join '\')
        if (-not $destinations.Add($relative)) { throw 'Destino de arquivo externo duplicado.' }
        $source=Resolve-EapPath ([string](Get-EapField $entry 'source' '')) $Config.PreparationBase
        if ((Test-EapWithin $source $Config.output) -or (Test-EapWithin $source $Config.eapHome)) { throw 'Arquivo externo de entrada deve ficar fora do consolidado e do servidor.' }
        Assert-EapPlainPath $source
        if (-not [IO.File]::Exists($source)) { throw "Arquivo externo ausente: $source" }
        $destination=Join-Path $Stage $relative
        $null=[IO.Directory]::CreateDirectory((Split-Path -Parent $destination))
        [IO.File]::Copy($source,$destination,$false)
        $relative
    }
}

function Assert-EapFilesCompatible {
    param($Config,[string]$Stage,[string[]]$Files)
    foreach ($relative in $Files) {
        $target=Join-Path $Config.eapHome $relative
        Assert-EapPlainPath $target
        if (-not (Test-Path -LiteralPath $target)) { continue }
        if (-not [IO.File]::Exists($target) -or
            (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash -cne (Get-FileHash -LiteralPath (Join-Path $Stage $relative) -Algorithm SHA256).Hash) {
            throw "Arquivo externo existente divergente: $relative. Arquivos preservados; concilie as copias antes de repetir."
        }
    }
}
