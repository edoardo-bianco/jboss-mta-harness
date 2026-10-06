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
    param($Base,[int]$MaxTextChars)
    $entries=[Collections.Generic.Dictionary[string,object]]::new([StringComparer]::Ordinal)
    foreach ($item in $Base.Items) { $entries.Add($item.Id,$item) }
    foreach ($row in $Base.Register.Rows) {
        if (-not $entries.ContainsKey($row.Id)) {
            $entries.Add($row.Id,[pscustomobject]@{Id=$row.Id;Title=$row.Title;Category=$row.Category;Count=$null;Details=$null})
        }
    }
    [string[]]$ids=@($entries.Keys); [Array]::Sort($ids,[StringComparer]::Ordinal)
    foreach ($id in $ids) {
        $item=$entries[$id]; $row=@($Base.Register.Rows | Where-Object Id -CEQ $id)
        $truncated=[Collections.Generic.List[object]]::new()
        $availability='NOT_AVAILABLE_IN_REQUEST'
        $category=if ($Base.Receipt.SchemaVersion -ge 4) { $Base.Receipt.Category } else {'mandatory'}
        if ($item.Category -ine $category) { $availability='OUTSIDE_CATEGORY' }
        elseif (@($Base.Receipt.ExcludedIssues | Where-Object { $_.Source -ieq $Base.Project.Source -and $_.Id -ceq $id }).Count) { $availability='EXCLUDED_PREVIOUS' }
        elseif (@($Base.Receipt.AvailableIssues | Where-Object { $_.Source -ieq $Base.Project.Source -and $_.Id -ceq $id }).Count) { $availability='AVAILABLE' }
        [pscustomobject][ordered]@{
            Source=$Base.Project.Source;Id=$id;Title=(Limit-QueryText $item.Title $MaxTextChars 'Title' $truncated)
            Category=$item.Category;Count=$item.Count;CatalogAvailable=($null -ne $item.Details)
            Presence=if ($row.Count) {$row[0].Presence} else {$null}
            Decision=if ($row.Count) {$row[0].Decision} else {$null}
            Progress=if ($row.Count) {$row[0].Progress} else {$null}
            Observation=if ($row.Count) {Limit-QueryText $row[0].Observation $MaxTextChars 'Observation' $truncated} else {$null}
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
        $original=@($Base.Items | Where-Object Id -CEQ $item.Id)
        $title=if ($original.Count) {$original[0].Title} else {$item.Title}
        if ($Text -and $item.Id.IndexOf($Text,[StringComparison]::OrdinalIgnoreCase) -lt 0 -and $title.IndexOf($Text,[StringComparison]::OrdinalIgnoreCase) -lt 0) { return $false }
        if ($Label -and (-not $original.Count -or $Label -notin @(Get-QueryProperty $original[0].Details 'labels'))) { return $false }
        $true
    })
    Get-QueryPage $items $Page $PageSize
}

function Get-QueryDetail {
    param($Base,[string]$Id,[int]$Page,[int]$PageSize,$Incident,[int]$MaxTextChars)
    $summary=@(Get-QueryItems $Base $MaxTextChars | Where-Object Id -CEQ $Id)
    if ($summary.Count -ne 1) { Stop-QueryError ISSUE_NOT_FOUND 'Issue nao encontrada no escopo deste contexto.' }
    $items=@($Base.Items | Where-Object Id -CEQ $Id)
    $incidents=@(); $metadata=$null; $truncated=[Collections.Generic.List[object]]::new()
    if ($items.Count -and $items[0].Details) {
        $incidents=@($items[0].Details.incidents)
        $metadata=Limit-QueryText (($items[0].Details | Select-Object * -ExcludeProperty incidents | ConvertTo-Json -Depth 40 -Compress)) $MaxTextChars 'RuleMetadataJson' $truncated
    }
    if ($null -ne $Incident -and $Incident -gt $incidents.Count) { Stop-QueryError INCIDENT_NOT_FOUND 'Ordinal nao existe nesta issue.' }
    $pageResult=Get-QueryPage $incidents $Page $PageSize
    $offset=([long]$Page-1)*$PageSize
    if ($null -ne $Incident) {
        $offset=$Incident-1
        $pageResult.Items=@($incidents[$offset])
        $pageResult.Paging=[ordered]@{Total=$incidents.Count;Returned=1;Incident=$Incident;Page=$null;PageSize=$null;HasMore=$false}
    }
    $selected=@(foreach ($item in $pageResult.Items) {
        $offset++; $cuts=[Collections.Generic.List[object]]::new()
        $uri=[string](Get-IncidentValue $item 'uri')
        [pscustomobject]@{
            Ordinal=$offset;Uri=(Limit-QueryText $uri $MaxTextChars 'Uri' $cuts)
            LineNumber=(Get-IncidentValue $item 'lineNumber')
            Message=(Limit-QueryText (Get-IncidentValue $item 'message') $MaxTextChars 'Message' $cuts)
            CodeSnippet=(Limit-QueryText (Get-IncidentValue $item 'codeSnip') $MaxTextChars 'CodeSnippet' $cuts)
            Location=(Get-IncidentLocation $uri $Base.Project);TruncatedFields=@($cuts.ToArray())
        }
    })
    [pscustomobject]@{Data=[ordered]@{Issue=$summary[0];RuleMetadataJson=$metadata;TruncatedFields=@($truncated.ToArray());Incidents=$selected;CodeApplicability='NOT_CHECKED'};Paging=$pageResult.Paging}
}
