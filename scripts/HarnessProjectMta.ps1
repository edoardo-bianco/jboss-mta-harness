function Get-ProjectMtaStamp {
    param([string]$Entry,[string]$Catalog)
    $entryInfo=Get-Item -LiteralPath $Entry -ErrorAction Stop
    $catalogInfo=Get-Item -LiteralPath $Catalog -ErrorAction Stop
    @($entryInfo.Length,$entryInfo.LastWriteTimeUtc.Ticks,$catalogInfo.Length,$catalogInfo.LastWriteTimeUtc.Ticks) -join ':'
}

function Read-ProjectMtaCandidate {
    param($Project,[string]$Entry,[scriptblock]$FileReader)
    $catalog=Join-Path (Split-Path $Entry -Parent) 'output.js'
    $null=Resolve-ProjectPath $catalog $Project.Root
    if (-not (Test-Path -LiteralPath $catalog -PathType Leaf)) { throw 'Conjunto incompleto: output.js ausente.' }
    $stamp=Get-ProjectMtaStamp $Entry $catalog
    # Share read only while reading: a writer cannot replace/truncate this file
    # unnoticed during this read. Never evaluate JavaScript from the report.
    if ($FileReader) {
        $null=& $FileReader $Entry
        $raw=[string](& $FileReader $catalog)
    } else {
        $reader=$null
        $stream=[IO.File]::Open($catalog,'Open','Read','Read')
        try { $reader=New-Object IO.StreamReader($stream,[Text.Encoding]::UTF8,$true); $raw=$reader.ReadToEnd() }
        finally { if ($reader) { $reader.Dispose() } else { $stream.Dispose() } }
    }
    if ($stamp -cne (Get-ProjectMtaStamp $Entry $catalog)) {
        $failure=New-Object IO.IOException 'Relatorio mudou durante a leitura; repetir a operacao.'
        $failure.Data['MtaChanged']=$true
        throw $failure
    }
    $match=[regex]::Match($raw,'(?s)^\s*window\["apps"\]\s*=\s*(\[.*\])\s*;?\s*$')
    if (-not $match.Success) { throw 'Formato de catalogo MTA nao suportado ou incompleto.' }
    $apps=ConvertFrom-Json $match.Groups[1].Value
    if (@($apps).Count -ne 1 -or -not $apps[0].PSObject.Properties['rulesets'] -or $apps[0].rulesets -isnot [Array]) { throw 'Relatorio deve conter uma aplicacao com rulesets.' }
    $app=$apps[0]
    if ($app.PSObject.Properties['artifactId'] -and $app.artifactId -and $app.artifactId -cne $Project.Name) { throw ('Relatorio identifica outra aplicacao: '+$app.artifactId) }
    $issues=@(); $seen=New-Object 'Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
    foreach ($ruleset in $app.rulesets) {
        if (-not $ruleset.PSObject.Properties['name'] -or -not $ruleset.name) { throw 'Ruleset sem nome funcional.' }
        if (-not $ruleset.PSObject.Properties['violations'] -or $null -eq $ruleset.violations) { continue }
        foreach ($rule in $ruleset.violations.PSObject.Properties) {
            $value=$rule.Value; $id=$ruleset.name+'::'+$rule.Name
            if (-not $seen.Add($id)) { throw "Issue duplicada: $id" }
            if (-not $value.PSObject.Properties['description'] -or -not $value.PSObject.Properties['category'] -or -not $value.PSObject.Properties['incidents'] -or $value.incidents -isnot [Array]) { throw "Issue incompleta: $id" }
            $issues+=[pscustomobject]@{Id=$id;Title=[string]$value.description;Category=[string]$value.category;Count=$value.incidents.Count;Details=$value}
        }
    }
    $after=Get-ProjectMtaStamp $Entry $catalog
    if ($stamp -cne $after) {
        $failure=New-Object IO.IOException 'Relatorio mudou durante a leitura; repetir a operacao.'
        $failure.Data['MtaChanged']=$true
        throw $failure
    }
    # Current static-report sets do not require a generation timestamp. When
    # explicitly present, accept only an ISO value with timezone; else use the
    # recognized entry file's modification time, never an old harness manifest.
    $date=(Get-Item -LiteralPath $Entry -ErrorAction Stop).LastWriteTimeUtc
    $dateSource='modificacao do arquivo de entrada'
    if ($app.PSObject.Properties['generatedAt'] -and ([string]$app.generatedAt) -match '(Z|[+-]\d{2}:\d{2})$') {
        $parsed=[DateTimeOffset]::MinValue
        if ([DateTimeOffset]::TryParse([string]$app.generatedAt,[Globalization.CultureInfo]::InvariantCulture,[Globalization.DateTimeStyles]::None,[ref]$parsed)) { $date=$parsed.UtcDateTime; $dateSource='generatedAt do relatorio' }
    }
    [pscustomobject]@{ReportPath=$Entry;CatalogPath=$catalog;DateUtc=$date;DateSource=$dateSource;Issues=@($issues);Diagnostics=@()}
}

function Read-HarnessProjectMta {
    param($Project)
    Invoke-WithProjectAccess $Project {
    $documents=Read-HarnessProjectFiles $Project @('projeto.json')
    if (-not $documents['projeto.json']) { throw 'Associacao projeto.json ausente; inicialize o projeto pelo POM.' }
    $configuration=ConvertFrom-Json $documents['projeto.json']
    $external=$configuration.mta.diretorio
    $origin=if ($external) { Resolve-ProjectPath $external $Project.Root } else { Join-Path $Project.Folder 'atual/diagnosticos/mta' }
    Read-HarnessMtaDirectory $Project $origin
    }
}

function Read-HarnessMtaDirectory {
    param($Project,[string]$Origin,[scriptblock]$FileReader)
    $origin=Resolve-ProjectPath $Origin $Project.Root
    if (-not (Test-Path -LiteralPath $origin -PathType Container)) { throw "Origem MTA indisponivel: $origin. Nenhum fallback para outra origem." }
    $pending=New-Object 'Collections.Generic.Stack[IO.DirectoryInfo]'
    $pending.Push((Get-Item -LiteralPath $origin))
    $candidates=@(); $problems=@()
    while ($pending.Count) {
        $directory=$pending.Pop()
        foreach ($child in $directory.EnumerateFileSystemInfos()) {
            if ($child.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "Link/junction na origem MTA: $($child.FullName)" }
            if ($child -is [IO.DirectoryInfo]) { $pending.Push($child); continue }
            if ($child.Name -ine 'index.html') { continue }
            try { $candidates+=Read-ProjectMtaCandidate $Project $child.FullName -FileReader $FileReader }
            catch {
                $failure=$_.Exception
                while ($failure) {
                    if ($failure.Data.Contains('MtaChanged') -or $failure.Data.Contains('QueryCode') -or
                        $failure -is [IO.IOException] -or $failure -is [UnauthorizedAccessException] -or
                        $failure -is [Security.SecurityException]) { throw }
                    $failure=$failure.InnerException
                }
                $problems+=($child.FullName+': '+$_.Exception.Message)
            }
        }
    }
    if (-not $candidates.Count) { throw ('Nenhum conjunto MTA utilizavel na origem '+$origin+'. '+($problems -join ' ')) }
    $latest=($candidates | Sort-Object DateUtc -Descending | Select-Object -First 1).DateUtc
    $ties=@($candidates | Where-Object DateUtc -EQ $latest)
    $paths=[string[]]@($ties | ForEach-Object ReportPath)
    [Array]::Sort($paths,[StringComparer]::Ordinal)
    $selected=$ties | Where-Object ReportPath -CEQ $paths[0] | Select-Object -First 1
    if ($ties.Count -gt 1) { $problems+=('Empate de data: selecionado por caminho ordinal '+$selected.ReportPath) }
    $selected.Diagnostics=@($problems)
    $selected
}
