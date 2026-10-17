# Proprietario derivado apenas das referencias selecionadas, nunca da ordem de
# publicacao ou da existencia do destino. Este mapa existe somente em memoria.
function Set-ConversionPlanReferenceMaps($State,$Inputs) {
    foreach ($inputSet in $Inputs) {
        $record=$inputSet.Planning.Record
        if (-not $record) { continue }
        $project=$inputSet.Project
        $references=@{}; $references[$inputSet.Register.Path]=$project.MigrationPath
        $cursor=$record
        while ($cursor) {
            foreach ($field in @('ContextPath','PlanPath','TodoPath')) { $references[(Resolve-ProjectPath $cursor.Data.$field $project.Root)]=$project.$field }
            $previous=Get-LegacyValue $cursor.Data 'Previous'
            $cursor=if ($previous) {@($inputSet.Records | Where-Object Path -IEQ (Resolve-ProjectPath $previous.ContextPath $project.Root))[0]} else {$null}
        }
        $fichas=@(Get-LegacyValue $record.Data 'IssueInputs' @())
        $single=Get-LegacyValue $record.Data 'FichaPath'
        if ($single) {
            $ids=@(Get-ConversionIssueIds $record.Data)
            if ($ids.Count -ne 1) { throw 'FichaPath sem issue unica no plano participante.' }
            $fichas+=@([pscustomobject]@{FichaPath=$single;Id=$ids[0]})
        }
        foreach ($ficha in $fichas) {
            $path=Get-LegacyValue $ficha 'FichaPath'
            if (-not $path) { continue }
            $rows=@(Read-ConversionDecisions $inputSet.Register.Text | Where-Object Id -CEQ $ficha.Id)
            if ($rows.Count -ne 1) { throw 'Ficha do plano participante sem categoria unica.' }
            $references[(Resolve-ProjectPath $path $project.Root)]=Join-Path $project.Folder (Get-PrioritizationFichaRelativePath $rows[0].Category $ficha.Id)
        }
        foreach ($path in $references.Keys) {
            if ($State.Map.ContainsKey($path) -and $State.Map[$path] -ine $references[$path]) { throw 'Documento funcional com destinos conflitantes.' }
            $State.Map[$path]=$references[$path]
        }
    }
}

function Get-ConversionEvidenceOwners($State,$Record,$Prioritizations,$Entries,$Aliases,$Diagnostics,$Bases) {
    $contexts=@{}; $projects=@{}
    $participants=@(Get-LegacyValue $State 'Participants' @([pscustomobject]@{LegacySource=$State.Inputs.Preview.LegacySource;Project=$State.Project}))
    foreach ($participant in $participants) { $projects[$participant.Project.Name]=$participant.Project }
    $inputs=@(Get-LegacyValue $State 'OwnershipInputs' @($State.Inputs))
    foreach ($inputSet in $inputs) { if ($inputSet.Planning.Record) { $contexts[$inputSet.Planning.Record.Path]=$inputSet.Project } }
    if ($Record) { $contexts[$Record.Path]=$State.Project }
    foreach ($priority in $Prioritizations) { foreach ($item in $priority.Records) { $contexts[$item.Path]=Get-LegacyValue $priority 'Master' $State.Project } }
    $queue=New-Object 'Collections.Generic.Queue[object]'
    foreach ($entry in $Entries) {
        if ($entry.Kind -eq 'ORIGEM_MTA' -or $Diagnostics.ContainsKey($entry.Path)) { continue }
        $source=Get-LegacyValue $entry 'OwnerSource'
        $owner=$null
        if ($source) {
            $matches=@($participants | Where-Object LegacySource -IEQ $source)
            if ($matches.Count -ne 1) { throw 'Anexo de Source sem associacao explicita.' }
            $owner=$matches[0].Project
        } else { $owner=$contexts[$entry.ContextPath] }
        if (-not $owner) { throw 'Proprietario do anexo nao determinado pelo contexto.' }
        $fixed=$entry.Field -in @('FichaPath','IssueInputs.FichaPath')
        $queue.Enqueue([pscustomobject]@{Path=$entry.Path;Project=$owner.Name;Strong=[bool]$source;Root=$fixed;Text=$(if ($fixed) {Read-ConversionText $State.Inputs.Session $entry.Path} else {$null})})
    }
    foreach ($priority in $Prioritizations) {
        foreach ($ranking in $priority.Rankings) { $queue.Enqueue([pscustomobject]@{Path=$ranking.Path;Project=$priority.Master.Name;Strong=$false;Root=$true;Text=$ranking.Text}) }
        foreach ($ficha in @($priority.Fichas.Values | Where-Object HasContent)) { $queue.Enqueue([pscustomobject]@{Path=$ficha.Path;Project=$ficha.Issue.Project;Strong=$true;Root=$true;Text=$ficha.Text}) }
    }
    foreach ($inputSet in $inputs) {
        if (-not $inputSet.Planning.Record) { continue }
        foreach ($field in @('PlanPath','TodoPath')) {
            $path=Get-LegacyValue $inputSet.Planning.Record.Data $field
            if ($path) { $queue.Enqueue([pscustomobject]@{Path=$path;Project=$inputSet.Project.Name;Strong=$true;Root=$true;Text=(Read-ConversionText $State.Inputs.Session $path)}) }
        }
    }
    $seen=@{}; $choices=@{}
    while ($queue.Count) {
        $item=$queue.Dequeue(); $path=[string]$item.Path
        if (-not $path -or $path -match '^https?://') { continue }
        if ($Aliases.ContainsKey($path)) { $path=$Aliases[$path] }
        $path=Resolve-ProjectPath $path $State.Project.Root
        if ($Diagnostics.ContainsKey($path) -or -not $path.StartsWith($State.Inputs.Session.DataRoot+'\',[StringComparison]::OrdinalIgnoreCase)) { continue }
        if (-not $item.Root -and $State.Map.ContainsKey($path)) { continue }
        # Visitar por consumidor e forca: um segundo projeto tambem deve
        # propagar sua referencia ate os anexos transitivos e os ciclos validos.
        $key=@($path,$item.Project,$item.Strong,$item.Root)|ConvertTo-Json -Compress
        if ($seen.ContainsKey($key)) { continue }; $seen[$key]=$true
        if ($seen.Count -gt 10000) { throw 'Grafo de anexos excede 10000 referencias por consumidor.' }
        if (-not $item.Root) {
            if (-not $choices.ContainsKey($path)) { $choices[$path]=@{} }
            $choices[$path][$item.Project]=$true
        }
        if ([IO.Path]::GetExtension($path) -ine '.md' -or -not (Test-Path -LiteralPath $path -PathType Leaf)) { continue }
        $text=if ($item.Root) {$item.Text} else {Read-ConversionText $State.Inputs.Session $path}
        $base=if ($Bases.ContainsKey($path)) {$Bases[$path]} else {$path}
        $directory=Split-Path $base -Parent
        foreach ($link in @(Get-ConversionLinks $text $base $State.Inputs.Session)) {
            if ($link.StartsWith($directory+'\',[StringComparison]::OrdinalIgnoreCase)) {
                $queue.Enqueue([pscustomobject]@{Path=$link;Project=$item.Project;Strong=$item.Strong;Root=$false;Text=$null})
            }
        }
    }
    $owners=@{}
    foreach ($path in $choices.Keys) {
        $names=[string[]]@($choices[$path].Keys); [Array]::Sort($names,[StringComparer]::Ordinal)
        # Maior consumidor primeiro: publicar em ordem decrescente evita que
        # dois mestres sobrepostos esperem anexos um do outro.
        $owners[$path]=$projects[$names[-1]]
    }
    [pscustomobject]@{Owners=$owners;Consumers=$choices}
}

function Assert-ConversionPartnerEvidence($State,$Owner,[string]$Relative,$Expected,$RequiredTargets) {
    if (-not $RequiredTargets.ContainsKey((Join-Path $Owner.Folder $Relative))) { return }
    $binary=$Expected -is [byte[]]
    $files=Read-HarnessProjectFiles $Owner @($Relative) -AsBytes:$binary
    $actual=$files[$Relative]
    if ($null -eq $actual) { throw ('Converta primeiro os anexos do participante '+$Owner.Name+'.') }
    $matches=if ($binary) { [Convert]::ToBase64String($actual) -ceq [Convert]::ToBase64String($Expected) }
        else { $actual.Replace("`r`n","`n").Contains($Expected.Replace("`r`n","`n").Trim()) }
    if (-not $matches) { throw ('Anexo participante diverge da evidencia legada: '+(Join-Path $Owner.Folder $Relative)) }
    $State.PartnerObserved[(Join-Path $Owner.Folder $Relative)]=$actual
}
