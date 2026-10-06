# Projecoes paginadas. Nunca retornam o catalogo/recibo inteiro nem marcam exame.
function ConvertTo-QueryNumber {
    param($Value,[string]$Name,[int]$Minimum,[int]$Maximum)
    $number=0
    if (-not [int]::TryParse([string]$Value,[ref]$number) -or $number -lt $Minimum -or $number -gt $Maximum) {
        Stop-QueryError INVALID_INPUT ("$Name deve estar entre $Minimum e $Maximum.")
    }
    $number
}

function Limit-QueryText {
    param($Value,[int]$Limit,[string]$Field,$Truncated)
    if ($null -eq $Value) { return $null }
    $text=[string]$Value
    if ($text.Length -gt $Limit) {
        $null=$Truncated.Add([pscustomobject]@{Field=$Field;OriginalLength=$text.Length;ReturnedLength=$Limit})
        return $text.Substring(0,$Limit)
    }
    $text
}

function Get-QueryItems {
    param($Base,[int]$MaxTextChars,[string]$Id)
    $entries=[Collections.Generic.Dictionary[string,object]]::new([StringComparer]::Ordinal)
    foreach ($item in $Base.Items) { $entries.Add($item.Id,$item) }
    foreach ($row in $Base.Register.Rows) {
        if ($Base.IsPlanning -and $row.Id -cnotin $Base.SelectedIds) { continue }
        if (-not $entries.ContainsKey($row.Id)) {
            $entries.Add($row.Id,[pscustomobject]@{Id=$row.Id;Title=$row.Title;Category=$row.Category;Count=$null;Details=$null})
        }
    }
    [string[]]$ids=@($entries.Keys); [Array]::Sort($ids,[StringComparer]::Ordinal)
    if ($Id) { $ids=@($ids | Where-Object { $_ -ceq $Id }) }
    foreach ($key in $ids) {
        $item=$entries[$key]; $row=$Base.RowsById[$key]
        $truncated=[Collections.Generic.List[object]]::new()
        $availability='NOT_AVAILABLE_IN_REQUEST'
        $category=if ($Base.IsPlanning) {$null} elseif ($Base.Receipt.SchemaVersion -ge 4) { $Base.Receipt.Category } else {'mandatory'}
        if ($Base.IsPlanning) { $availability='SELECTED_FOR_PLANNING' }
        elseif ($item.Category -ine $category) { $availability='OUTSIDE_CATEGORY' }
        elseif ($Base.AvailabilityById.ContainsKey($key)) { $availability=$Base.AvailabilityById[$key] }
        [pscustomobject][ordered]@{
            Source=$Base.Project.Source;Id=$key;Title=(Limit-QueryText $item.Title $MaxTextChars 'Title' $truncated)
            Category=$item.Category;Count=$item.Count;CatalogAvailable=($null -ne $item.Details)
            Presence=if ($row) {$row.Presence} else {$null}
            Decision=if ($row) {$row.Decision} else {$null}
            Progress=if ($row) {$row.Progress} else {$null}
            Observation=if ($row) {Limit-QueryText $row.Observation $MaxTextChars 'Observation' $truncated} else {$null}
            Availability=$availability;TruncatedFields=@($truncated.ToArray())
        }
    }
}

function Get-QueryPage {
    param([object[]]$Items,[int]$Page,[int]$PageSize)
    $offset=([long]$Page-1)*$PageSize
    $selected=@($Items | Select-Object -Skip ([Math]::Min($offset,[int]::MaxValue)) -First $PageSize)
    [pscustomobject]@{Items=$selected;Paging=[ordered]@{Total=$Items.Count;Returned=$selected.Count;Page=$Page;PageSize=$PageSize;HasMore=($offset+$selected.Count -lt $Items.Count)}}
}

function Get-QueryList {
    param($Base,[int]$Page,[int]$PageSize,[int]$MaxTextChars,[string]$Category,[string]$Decision,[string]$Progress,[string]$Text,[string]$Label)
    $items=@(Get-QueryItems $Base $MaxTextChars | Where-Object {
        $item=$_
        if ($Category -and $item.Category -ine $Category) { return $false }
        if ($Decision -and $item.Decision -ine $Decision) { return $false }
        if ($Progress -and $item.Progress -ine $Progress) { return $false }
        $original=$Base.ItemsById[$item.Id]
        $title=if ($original) {$original.Title} else {$Base.RowsById[$item.Id].Title}
        if ($Text -and $item.Id.IndexOf($Text,[StringComparison]::OrdinalIgnoreCase) -lt 0 -and $title.IndexOf($Text,[StringComparison]::OrdinalIgnoreCase) -lt 0) { return $false }
        if ($Label -and (-not $original -or $Label -notin @(Get-QueryProperty $original.Details 'labels'))) { return $false }
        $true
    })
    Get-QueryPage $items $Page $PageSize
}

function Get-QueryDetail {
    param($Base,[string]$Id,[int]$Page,[int]$PageSize,$Incident,[int]$MaxTextChars)
    $summary=@(Get-QueryItems $Base $MaxTextChars $Id)
    if ($summary.Count -ne 1) { Stop-QueryError ISSUE_NOT_FOUND 'Issue nao encontrada no escopo deste contexto.' }
    $item=$Base.ItemsById[$Id]
    $incidents=@(); $metadata=$null; $truncated=[Collections.Generic.List[object]]::new()
    if ($item -and $item.Details) {
        $incidents=@($item.Details.incidents)
        $metadata=Limit-QueryText (($item.Details | Select-Object * -ExcludeProperty incidents | ConvertTo-Json -Depth 40 -Compress)) $MaxTextChars 'RuleMetadataJson' $truncated
    }
    if ($null -ne $Incident -and $Incident -gt $incidents.Count) { Stop-QueryError INCIDENT_NOT_FOUND 'Ordinal nao existe nesta issue.' }
    $pageResult=Get-QueryPage $incidents $Page $PageSize
    $offset=([long]$Page-1)*$PageSize
    if ($null -ne $Incident) {
        $offset=$Incident-1
        $pageResult.Items=@($incidents[$offset])
        $pageResult.Paging=[ordered]@{Total=$incidents.Count;Returned=1;Incident=$Incident;Page=$null;PageSize=$null;HasMore=$false}
    }
    $locationProject=if ($Base.Mta) {
        [pscustomobject]@{Source=$Base.Project.Source;Mta=[pscustomobject]@{RunId=$Base.Mta.RunId;AnalysisSource=$Base.Mta.AnalysisSource;MtaOrigin=[pscustomobject]@{Run=(Get-QueryProperty $Base.Mta.MtaOrigin 'Run' $Base.Mta.Run)}}}
    } else {$null}
    $selected=@(foreach ($item in $pageResult.Items) {
        $offset++; $cuts=[Collections.Generic.List[object]]::new()
        $uri=[string](Get-IncidentValue $item 'uri')
        $line=Get-IncidentValue $item 'lineNumber'
        $number=0
        if ($null -ne $line -and (-not [int]::TryParse([string]$line,[ref]$number) -or $number -lt 0)) { Stop-QueryError UNSUPPORTED_FORMAT 'lineNumber deve ser inteiro nao negativo ou nulo.' }
        $location=Get-IncidentLocation $uri $locationProject -LexicalPaths
        foreach ($property in @($location.PSObject.Properties)) { $property.Value=Limit-QueryText $property.Value $MaxTextChars ('Location.'+$property.Name) $cuts }
        [pscustomobject]@{
            Ordinal=$offset;Uri=(Limit-QueryText $uri $MaxTextChars 'Uri' $cuts)
            LineNumber=if ($null -eq $line) {$null} else {$number}
            Message=(Limit-QueryText (Get-IncidentValue $item 'message') $MaxTextChars 'Message' $cuts)
            CodeSnippet=(Limit-QueryText (Get-IncidentValue $item 'codeSnip') $MaxTextChars 'CodeSnippet' $cuts)
            Location=$location;TruncatedFields=@($cuts.ToArray())
        }
    })
    $references=@(Get-QueryProperty $Base.Receipt 'EvidenceInputs' @())
    $referencesJson=Limit-QueryText (ConvertTo-Json -InputObject $references -Depth 10 -Compress) $MaxTextChars 'EvidenceReferencesJson' $truncated
    [pscustomobject]@{Data=[ordered]@{Issue=$summary[0];RuleMetadataJson=$metadata;EvidenceReferencesJson=$referencesJson;TruncatedFields=@($truncated.ToArray());Incidents=$selected;CodeApplicability='NOT_CHECKED'};Paging=$pageResult.Paging}
}

function Get-QueryAudit {
    param($Base,[int]$Page,[int]$PageSize)
    $rows=@($Base.Register.Rows | Where-Object { -not $Base.IsPlanning -or $_.Id -cin $Base.SelectedIds })
    $differences=@(foreach ($issue in $Base.Items) {
        $row=$Base.RowsById[$issue.Id]
        if (-not $row) { [pscustomobject]@{Id=$issue.Id;Reason='ISSUE_NOT_IN_REGISTER'}; continue }
        if ($row.Category -cne $issue.Category -or [string]$row.Count -cne [string]$issue.Count -or $row.Presence -ne 'PRESENTE') {
            [pscustomobject]@{Id=$issue.Id;Reason='CATALOG_REGISTER_DIFFERENCE'}
        }
    }
    foreach ($row in $rows) {
        if ($Base.Provenance.PlanningBasis -eq 'MTA' -and $row.Presence -eq 'PRESENTE' -and -not $Base.ItemsById.ContainsKey($row.Id)) {
            [pscustomobject]@{Id=$row.Id;Reason='REGISTER_ISSUE_NOT_IN_CATALOG'}
        }
    }
    if ($Base.IsPlanning) {
        foreach ($id in $Base.SelectedIds) { if (-not $Base.RowsById.ContainsKey($id)) { [pscustomobject]@{Id=$id;Reason='SELECTED_ISSUE_NOT_IN_REGISTER'} } }
    })
    [string[]]$paths=@($Base.Files.Keys); [Array]::Sort($paths,[StringComparer]::Ordinal)
    $checks=@(foreach ($path in $paths) { [pscustomobject]@{Type='FILE_HASH';Path=$path;Sha256=$Base.Files[$path]} }
        foreach ($difference in $differences) { [pscustomobject]@{Type='DIFFERENCE';Path=$Base.Provenance.RegisterPath;Id=$difference.Id;Reason=$difference.Reason} })
    $pageResult=Get-QueryPage $checks $Page $PageSize
    [long]$incidents=0; foreach ($item in $Base.Items) { $incidents+=$item.Count }
    [pscustomobject]@{Data=[ordered]@{CatalogIssues=$Base.Items.Count;CatalogIncidents=$incidents;RegisterIssues=$rows.Count;RegisterTotalIssues=@($Base.Register.Rows).Count;DifferencesCount=$differences.Count;FilesCount=$paths.Count;Checks=$pageResult.Items;CodeApplicability='NOT_CHECKED';IndexComparison='HASH_ONLY'};Paging=$pageResult.Paging}
}
