# Anexos humanos internos ganham destinos funcionais; fontes externas sao referencias.
function Read-ConversionBytes($State,[string]$Path) {
    $path=Resolve-ProjectPath $Path $State.Project.Root
    if (-not $path.StartsWith($State.Inputs.Session.DataRoot+'\',[StringComparison]::OrdinalIgnoreCase)) { throw 'Copiar exige anexo interno ao harness.' }
    if (-not $State.Bytes.ContainsKey($path)) { $State.Bytes[$path]=[IO.File]::ReadAllBytes($path) }
    return ,$State.Bytes[$path]
}

function Read-ConversionEvidence($State,$Record) {
    if (-not $Record) { return }
    $entries=@($State.Inputs.Preview.Attachments | Where-Object ContextPath -IEQ $Record.Path)
    if (@($entries | Where-Object { -not $_.Valid }).Count) { throw 'Anexo estruturado invalido; corrija a origem antes de aplicar.' }
    $aliases=@{}; $relations=@{}; $diagnostics=@{}; $bases=@{}; $duplicates=@{}
    $functional=@(Get-LegacyValue $Record.Data 'FichaPath')+@(Get-LegacyValue $Record.Data 'IssueInputs' @() | ForEach-Object { Get-LegacyValue $_ 'FichaPath' })
    $functional=@($functional | Where-Object { $_ } | ForEach-Object { Resolve-ProjectPath $_ $State.Project.Root })
    foreach ($entry in $entries) {
        if ($entry.Kind -in @('COPIA_DIAGNOSTICO_LEGADO','EXTRATO_MTA')) { $diagnostics[$entry.Path]=$true }
        if ($entry.OriginPath -and $entry.Available) {
            $origin=Resolve-ProjectPath $entry.OriginPath $State.Project.Root
            $bases[$entry.Path]=$origin
            if ($aliases.ContainsKey($origin) -and $aliases[$origin] -ine $entry.Path) {
                $previous=$aliases[$origin]
                if ([Convert]::ToBase64String((Read-ConversionBytes $State $previous)) -cne [Convert]::ToBase64String((Read-ConversionBytes $State $entry.Path))) { throw 'Copias divergentes da mesma evidencia original; confira antes de aplicar.' }
                $chosen=if ($entry.Path -iin $functional) {$entry.Path} else {$previous}
                $other=if ($chosen -ieq $entry.Path) {$previous} else {$entry.Path}
                $duplicates[$other]=$chosen
                $aliases[$origin]=$chosen
            } else { $aliases[$origin]=$entry.Path }
        }
    }
    foreach ($path in $duplicates.Keys) { $aliases[$path]=$duplicates[$path] }
    foreach ($item in @(Get-LegacyValue $Record.Data 'IssueInputs' @())) {
        foreach ($pair in @(@('FichaOrigin',(Get-LegacyValue $item 'FichaPath')),@('EvidenceIndexOrigin',(Get-LegacyValue $Record.Data 'EvidenceIndexPath')))) {
            $origin=Get-LegacyValue $item $pair[0]
            if ($origin -and $pair[1] -and (Test-Path -LiteralPath $pair[1] -PathType Leaf)) { $aliases[(Resolve-ProjectPath $origin $State.Project.Root)]=Resolve-ProjectPath $pair[1] $State.Project.Root }
        }
    }
    foreach ($origin in @($aliases.Keys)) {
        $target=$aliases[$origin]; $visited=@{}
        while ($aliases.ContainsKey($target) -and $aliases[$target] -ine $target) {
            if ($visited.ContainsKey($target)) { throw 'Ciclo na proveniencia das evidencias.' }
            $visited[$target]=$true; $target=$aliases[$target]
        }
        $aliases[$origin]=$target
    }
    foreach ($entry in $entries) {
        if (-not $entry.Relation) { continue }
        $path=$entry.Path
        if ($aliases.ContainsKey($path)) { $path=$aliases[$path] }
        $relations[$path]=@($relations[$path])+@($entry.Relation)
    }
    $fichas=@{}
    $ids=@(Get-ConversionIssueIds $Record.Data)
    $single=Get-LegacyValue $Record.Data 'FichaPath'
    if ($single) {
        if ($ids.Count -ne 1) { throw 'FichaPath sem issue unica; confira IssueInputs antes de converter.' }
        $fichas[(Resolve-ProjectPath $single $State.Project.Root)]=$ids[0]
    }
    foreach ($item in @(Get-LegacyValue $Record.Data 'IssueInputs' @())) {
        $path=Get-LegacyValue $item 'FichaPath'
        if ($path) { $fichas[(Resolve-ProjectPath $path $State.Project.Root)]=[string]$item.Id }
    }
    $pending=New-Object 'Collections.Generic.Queue[object]'
    foreach ($entry in $entries) {
        if ($aliases.ContainsKey($entry.Path) -and $aliases[$entry.Path] -ine $entry.Path) { continue }
        $pending.Enqueue($entry)
    }
    $seen=@{}; $documents=@(); $destinations=@{}; $evidence=@(); $fichaPaths=@()
    $index=Get-LegacyValue $Record.Data 'EvidenceIndexPath'
    if ($index) { $index=Resolve-ProjectPath $index $State.Project.Root }
    while ($pending.Count) {
        if ($seen.Count -gt 1000) { throw 'Anexos excedem 1000 referencias; delimite as evidencias necessarias.' }
        $entry=$pending.Dequeue(); $path=[string]$entry.Path
        if (-not $path -or $seen.ContainsKey($path)) { continue }; $seen[$path]=$true
        if ($entry.Kind -eq 'ORIGEM_MTA') { continue }
        if ($diagnostics.ContainsKey($path)) { $State.Diagnostics.Add('Diagnostico legado requer fonte direta: '+$path); continue }
        $relation=if ($relations.ContainsKey($path)) { @($relations[$path] | Where-Object { $_ } | Sort-Object -Unique) -join '; ' } else { 'Evidencia: '+[IO.Path]::GetFileName($path) }
        if ($path -match '^https?://') {
            $evidence+=@([pscustomobject]@{Path=$path;Relation=$relation;Status='REFERENCIA EXTERNA'}); continue
        }
        $path=Resolve-ProjectPath $path $State.Project.Root
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            $State.Diagnostics.Add('Anexo indisponivel: '+$path)
            $missing=if ($path.StartsWith($State.Inputs.Session.DataRoot+'\',[StringComparison]::OrdinalIgnoreCase)) { Join-Path $State.Project.EvidencePath ([IO.Path]::GetFileName($path)) } else { $path }
            $evidence+=@([pscustomobject]@{Path=$missing;Relation=$relation;Status='AUSENTE'}); continue
        }
        if (-not $path.StartsWith($State.Inputs.Session.DataRoot+'\',[StringComparison]::OrdinalIgnoreCase)) {
            $evidence+=@([pscustomobject]@{Path=$path;Relation=$relation;Status='DISPONIVEL'}); continue
        }
        $leaf=[IO.Path]::GetFileName($(if ($bases.ContainsKey($path)) {$bases[$path]} else {$path}))
        if ($leaf -match '^(context(?:o)?(?:-.*)?|manifest|result|apontamentos-mta)\.json$|^output\.js$|^dependencies\.(yaml|csv)$' -and -not $relations.ContainsKey($path)) {
            throw ('Anexo de papel ambiguo; declare a relacao humana ou a origem diagnostica antes de converter: '+$path)
        }
        $id=$null; $category=$null
        if ($fichas.ContainsKey($path)) {
            if ([IO.Path]::GetExtension($path) -ine '.md') { throw 'Ficha deve ser Markdown para preservar texto e identidade funcional.' }
            $id=$fichas[$path]
            $rows=@(Read-ConversionDecisions $State.Inputs.Register.Text | Where-Object Id -CEQ $id)
            if ($rows.Count -ne 1) { throw ('Ficha sem categoria/decisao unica: '+$id) }
            $category=$rows[0].Category
            $relative=Get-PrioritizationFichaRelativePath $category $id
        } else { $relative='evidencias/'+$(if ($path -ieq $index) {'LEIA-ME.md'} else {$leaf}) }
        if ($destinations.ContainsKey($relative) -and $destinations[$relative] -ine $path) { throw ('Anexos distintos disputam destino: '+$relative+'. Resolva os nomes antes de converter.') }
        $destinations[$relative]=$path
        $target=Join-Path $State.Project.Folder $relative
        $State.Map[$path]=$target
        if ($id) { $fichaPaths+=@([pscustomobject]@{Id=$id;Category=$category;Path=$target;Status='DISPONIVEL'}) }
        else { $evidence+=@([pscustomobject]@{Path=$target;Relation=$relation;Status='DISPONIVEL'}) }
        if ([IO.Path]::GetExtension($path) -ieq '.md') {
            $text=Read-ConversionText $State.Inputs.Session $path
            $base=if ($bases.ContainsKey($path)) {$bases[$path]} else {$path}
            $documents+=@([pscustomobject]@{Path=$path;Base=$base;Relative=$relative;Text=$text;Id=$id;Category=$category})
            foreach ($link in @(Get-ConversionLinks $text $base $State.Inputs.Session)) {
                # Links operacionais nao viram anexos. Somente arquivos vizinhos
                # aos anexos declarados podem ser descobertos pelo Markdown.
                if ($State.Map.ContainsKey($link) -or $aliases.ContainsKey($link) -or $link -in @($Record.Path,$Record.Data.PlanPath,$Record.Data.TodoPath)) { continue }
                $directory=Split-Path $base -Parent
                if ($link.StartsWith($directory+'\',[StringComparison]::OrdinalIgnoreCase)) {
                    $pending.Enqueue([pscustomobject]@{Path=$link;Kind='EVIDENCIA'})
                }
            }
        } else { $State.Files[$relative]=Read-ConversionBytes $State $path }
    }
    $State.EvidenceInputs=$evidence
    $State.FichaPaths=$fichaPaths
    foreach ($origin in $aliases.Keys) {
        if ($State.Map.ContainsKey($aliases[$origin])) { $State.Map[$origin]=$State.Map[$aliases[$origin]] }
    }
    if ($index -and $State.Map.ContainsKey($index)) { $State.EvidenceIndexPath=$State.Map[$index] }
    [pscustomobject]@{Documents=$documents;Relations=$relations;Record=$Record}
}

function Add-ConversionEvidenceDocuments($State,$Evidence) {
    if (-not $Evidence) { return }
    $relations=$Evidence.Relations; $Record=$Evidence.Record
    foreach ($document in $Evidence.Documents) {
        $target=Join-Path $State.Project.Folder $document.Relative
        if ($document.Id) {
            $legacy=[regex]::Matches($document.Text,'(?s)<!-- issue:\s*(\{.*?\})\s*-->')
            if ($legacy.Count -gt 1) { throw 'Identidade ambigua na ficha do planejamento.' }
            if ($legacy.Count) {
                $identity=ConvertFrom-Json $legacy[0].Groups[1].Value
                if ($identity.Id -cne $document.Id -or (Resolve-ProjectPath $identity.Source $State.Project.Root) -ine $State.Inputs.Preview.LegacySource) { throw 'Ficha do planejamento pertence a outro Source/ID.' }
                $document.Text=$document.Text.Remove($legacy[0].Index,$legacy[0].Length)
            }
        }
        $text=Convert-ConversionMarkdown $document.Text $document.Base $target $State
        if ($document.Id) {
            if ($relations.ContainsKey($document.Path)) { $text=Set-ProjectManagedBlock $text 'conversao:relacoes' (@($relations[$document.Path] | Where-Object { $_ } | Sort-Object -Unique) -join "`n`n") }
            $local=@(); $human=@()
            foreach ($link in @(Get-ConversionLinks $text $target $State.Inputs.Session)) {
                if ($link.StartsWith($State.Project.Source+'\',[StringComparison]::OrdinalIgnoreCase)) { $local+=$link.Substring($State.Project.Source.Length+1) }
                if ($link.StartsWith($State.Project.EvidencePath+'\',[StringComparison]::OrdinalIgnoreCase)) { $human+=$link.Substring($State.Project.EvidencePath.Length+1) }
            }
            $identity=[ordered]@{Project=$State.Project.Name;Category=$document.Category;Id=$document.Id;LocalPaths=@($local|Sort-Object -Unique);EvidencePaths=@($human|Sort-Object -Unique)}
            $text=Set-ProjectManagedBlock $text 'ficha:identidade' ($identity|ConvertTo-Json -Depth 6)
            $evidenceOnly=(Get-LegacyValue $Record.Data 'PlanningBasis' 'MTA') -eq 'EVIDENCIAS'
            $mta=if ($evidenceOnly) {$null} else {$State.Mta}
            $text=Get-IssueSourcesText $State.Project $mta $document.Id $document.Category $text $target -EvidenceOnly:$evidenceOnly -AvailablePaths @($State.Map.Values)
            if ($State.Files.Contains($document.Relative)) {
                $old=[string]$State.Files[$document.Relative]
                $null=Read-PrioritizationFicha $old $State.Project.Name $document.Category $document.Id
                # A ficha do lote pode acrescentar observacoes, mas nao apagar a
                # analise humana incorporada da priorizacao. Blocos derivados
                # podem refletir a base escolhida no planejamento corrente.
                $bodies=@($old,$text)
                for ($i=0;$i -lt 2;$i++) {
                    foreach ($name in @('ficha:identidade','ficha:fontes','conversao:relacoes')) {
                        $block=Find-ProjectManagedBlock $bodies[$i] $name
                        if ($block) { $bodies[$i]=$bodies[$i].Remove($block.Index,$block.Length) }
                    }
                    $bodies[$i]=$bodies[$i].Replace("`r`n","`n").Trim()
                }
                if (-not $bodies[1].Contains($bodies[0])) { throw 'Ficha do planejamento perderia texto humano da priorizacao; resolva o conflito antes de aplicar.' }
                $relationBlock=Find-ProjectManagedBlock $old 'conversao:relacoes'
                if ($relationBlock) {
                    $content=$relationBlock.Value -replace '^<!-- conversao:relacoes:inicio -->\s*','' -replace '\s*<!-- conversao:relacoes:fim -->$',''
                    $next=Find-ProjectManagedBlock $text 'conversao:relacoes'
                    if ($next) {
                        $newContent=$next.Value -replace '^<!-- conversao:relacoes:inicio -->\s*','' -replace '\s*<!-- conversao:relacoes:fim -->$',''
                        if ($newContent -cne $content) { $content+="`n`n"+$newContent }
                    }
                    $text=Set-ProjectManagedBlock $text 'conversao:relacoes' $content
                }
            }
        }
        $State.Files[$document.Relative]=$text
    }
}
