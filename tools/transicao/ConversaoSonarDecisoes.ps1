function Get-ConversionHash([byte[]]$Bytes) {
    $sha=[Security.Cryptography.SHA256]::Create()
    try { [BitConverter]::ToString($sha.ComputeHash($Bytes)).Replace('-','') } finally { $sha.Dispose() }
}

function Get-ConversionSonarDecisionFiles($State,[string]$Directory) {
    $directory=Resolve-ProjectPath $Directory $State.Project.Root
    if (Test-Path -LiteralPath $directory -PathType Container) {
        foreach ($file in @(Get-ChildItem -LiteralPath $directory -File -Filter '*.json' | Sort-Object Name)) { Resolve-ProjectPath $file.FullName $State.Project.Root }
    }
}

function Read-ConversionSonarDecision($State,$Record) {
    $folder=Split-Path $Record.Path -Parent
    $directory=Join-Path $folder 'decisions'
    $files=@(Get-ConversionSonarDecisionFiles $State $directory)
    $State.SonarInventories[$directory]=$files -join "`n"
    if ($files.Count -gt 1000) { throw 'Decisoes Sonar excedem 1000 entradas.' }
    if (-not $files.Count) { return }
    $evidence=@{}
    foreach ($name in @('result.json','inputs.json','quality-gate.json','measures.json','issues.json','criteria.json')) {
        $path=Join-Path $folder $name
        if (Test-Path -LiteralPath $path -PathType Leaf) { $evidence[$name]=Get-ConversionHash (Read-ConversionBytes $State $path) }
        else { $null=Read-ConversionText $State.Inputs.Session $path }
    }
    $previous=$null; $sequence=0; $current=$null
    foreach ($path in $files) {
        $entry=ConvertFrom-Json (Read-ConversionText $State.Inputs.Session $path)
        $sequence++
        if ((Split-Path $path -Leaf) -cne ('decision_{0:D6}.json' -f $sequence) -or $entry.Sequence -ne $sequence -or $entry.SchemaVersion -ne 1 -or
            $entry.RunId -cne $Record.Data.RunId -or $entry.PreviousSha256 -cne $previous -or $entry.Decision -cnotin @('CorrigirAgora','RegistrarParaDepois','Interromper')) { throw 'Cadeia de decisoes Sonar inconsistente.' }
        foreach ($field in @('Source','ProjectKey','ServerUrl')) { if ($entry.$field -cne $Record.Data.$field) { throw 'Decisao Sonar pertence a outra origem.' } }
        if ($entry.Decision -ceq 'RegistrarParaDepois' -and ([string]::IsNullOrWhiteSpace($entry.Note) -or [string]::IsNullOrWhiteSpace($entry.ReviewWhen))) { throw 'Adiamento Sonar sem motivo/gatilho.' }
        $names=@{}
        foreach ($item in $entry.Evidence) {
            if ($names.ContainsKey($item.Name) -or -not $evidence.ContainsKey($item.Name) -or $item.Sha256 -cne $evidence[$item.Name]) { throw 'Evidencias da decisao Sonar divergem do conjunto.' }
            $names[$item.Name]=$true
        }
        if ($names.Count -ne $evidence.Count) { throw 'Decisao Sonar omite evidencias do conjunto.' }
        $date=[DateTimeOffset]::MinValue
        if ([string]$entry.RecordedAtUtc -notmatch '(?:Z|[+-]\d{2}:\d{2})$' -or -not [DateTimeOffset]::TryParse($entry.RecordedAtUtc,[Globalization.CultureInfo]::InvariantCulture,[Globalization.DateTimeStyles]::None,[ref]$date)) { throw 'Decisao Sonar sem data com fuso.' }
        if ($current -and $date -lt $current.Finished) { throw 'Datas retrocedem na cadeia de decisoes Sonar.' }
        $current=[pscustomobject]@{Entry=$entry;Finished=$date;Record=$Record}
        $previous=Get-ConversionHash (Read-ConversionBytes $State $path)
    }
    $current
}

function Assert-ConversionSonarUnchanged($State) {
    foreach ($directory in $State.SonarInventories.Keys) {
        if ((@(Get-ConversionSonarDecisionFiles $State $directory) -join "`n") -cne $State.SonarInventories[$directory]) { throw 'Decisoes Sonar mudaram durante a conversao; repita a leitura.' }
    }
}
