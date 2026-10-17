# Anexos humanos internos ganham destinos funcionais; fontes externas sao referencias.
function Read-ConversionBytes($State,[string]$Path) {
    $path=Resolve-ProjectPath $Path $State.Project.Root
    if (-not $path.StartsWith($State.Inputs.Session.DataRoot+'\',[StringComparison]::OrdinalIgnoreCase)) { throw 'Copiar exige anexo interno ao harness.' }
    if (-not $State.Bytes.ContainsKey($path)) { $State.Bytes[$path]=[IO.File]::ReadAllBytes($path) }
    return ,$State.Bytes[$path]
}

function Read-ConversionEvidence($State,$Record,$Prioritizations=@()) {
    $contexts=@(if ($Record) {$Record.Path})+@($Prioritizations | ForEach-Object { $_.Records | ForEach-Object Path })
    if (-not $contexts.Count) { return }
    $planData=Get-LegacyValue $Record 'Data'
    $inputs=@(Get-LegacyValue $State 'OwnershipInputs' @($State.Inputs))
    $allPriorities=@(Get-LegacyValue $State 'OwnershipPriorities' $Prioritizations)
    $plans=@($inputs | ForEach-Object { $_.Planning.Record } | Where-Object { $_ })
    $allContexts=@($plans | ForEach-Object Path)+@($allPriorities | ForEach-Object { $_.Records | ForEach-Object Path })
    $entries=@($inputs | ForEach-Object { $_.Preview.Attachments } | Where-Object ContextPath -IIn $allContexts | Sort-Object ContextPath,Field,Path,OriginPath -Unique)
    if (@($entries | Where-Object { -not $_.Valid }).Count) { throw 'Anexo estruturado invalido; corrija a origem antes de aplicar.' }
    $aliases=@{}; $relations=@{}; $diagnostics=@{}; $bases=@{}; $duplicates=@{}
    $functional=@(foreach ($plan in $plans) { Get-LegacyValue $plan.Data 'FichaPath'; @(Get-LegacyValue $plan.Data 'IssueInputs' @() | ForEach-Object { Get-LegacyValue $_ 'FichaPath' }) })
    $functional=@($functional | Where-Object { $_ } | ForEach-Object { Resolve-ProjectPath $_ $State.Project.Root })
    foreach ($entry in $entries) {
        if ($entry.Kind -in @('COPIA_DIAGNOSTICO_LEGADO','EXTRATO_MTA')) {
            $owner=Get-LegacyValue $entry 'OwnerSource'
            if ($diagnostics.ContainsKey($entry.Path) -and $diagnostics[$entry.Path] -ine $owner) { throw 'Extrato MTA declarado para Sources diferentes.' }
            $diagnostics[$entry.Path]=$owner
        }
        if ($entry.OriginPath -and $entry.Available) {
            $origin=Resolve-ProjectPath $entry.OriginPath $State.Project.Root
            $bases[$entry.Path]=$origin
            if ($aliases.ContainsKey($origin) -and $aliases[$origin] -ine $entry.Path) {
                $previous=$aliases[$origin]
                if ([Convert]::ToBase64String((Read-ConversionBytes $State $previous)) -cne [Convert]::ToBase64String((Read-ConversionBytes $State $entry.Path))) { throw 'Copias divergentes da mesma evidencia original; confira antes de aplicar.' }
                $chosen=if ($entry.Path -iin $functional -and $previous -inotIn $functional) {$entry.Path} else {$previous}
                $other=if ($chosen -ieq $entry.Path) {$previous} else {$entry.Path}
                $duplicates[$other]=$chosen
                $aliases[$origin]=$chosen
            } else { $aliases[$origin]=$entry.Path }
        }
    }
    foreach ($path in $duplicates.Keys) { $aliases[$path]=$duplicates[$path] }
    foreach ($plan in $plans) { foreach ($item in @(Get-LegacyValue $plan.Data 'IssueInputs' @())) {
        foreach ($pair in @(@('FichaOrigin',(Get-LegacyValue $item 'FichaPath')),@('EvidenceIndexOrigin',(Get-LegacyValue $plan.Data 'EvidenceIndexPath')))) {
            $origin=Get-LegacyValue $item $pair[0]
            if ($origin -and $pair[1] -and (Test-Path -LiteralPath $pair[1] -PathType Leaf)) { $aliases[(Resolve-ProjectPath $origin $State.Project.Root)]=Resolve-ProjectPath $pair[1] $State.Project.Root }
        }
    } }
    foreach ($origin in @($aliases.Keys)) {
        $target=$aliases[$origin]; $visited=@{}
        while ($aliases.ContainsKey($target) -and $aliases[$target] -ine $target) {
            if ($visited.ContainsKey($target)) { throw 'Ciclo na proveniencia das evidencias.' }
            $visited[$target]=$true; $target=$aliases[$target]
        }
        $aliases[$origin]=$target
    }
    # Copias renomeadas mantem o papel da origem, inclusive atraves de aliases.
    foreach ($path in @($diagnostics.Keys)) {
        if ($aliases.ContainsKey($path)) {
            $target=$aliases[$path]
            if ($diagnostics.ContainsKey($target) -and $diagnostics[$target] -ine $diagnostics[$path]) { throw 'Proveniencia diagnostica com Sources conflitantes.' }
            $diagnostics[$target]=$diagnostics[$path]
        }
    }
    foreach ($origin in $aliases.Keys) {
        if ($diagnostics.ContainsKey($aliases[$origin])) { $diagnostics[$origin]=$diagnostics[$aliases[$origin]] }
    }
    Set-ConversionPlanReferenceMaps $State $inputs
    if ($State.Mta) {
        foreach ($path in $diagnostics.Keys) {
            if ($diagnostics[$path] -ieq $State.Inputs.Preview.LegacySource) { $State.Map[$path]=$State.Mta.ReportPath }
        }
    }
    foreach ($entry in $entries) {
        if (-not $entry.Relation) { continue }
        $path=$entry.Path
        if ($aliases.ContainsKey($path)) { $path=$aliases[$path] }
        $relations[$path]=@($relations[$path])+@($entry.Relation)
    }
    $fichas=@{}
    $ids=@(if ($Record) {Get-ConversionIssueIds $planData})
    $single=Get-LegacyValue $planData 'FichaPath'
    if ($single) {
        if ($ids.Count -ne 1) { throw 'FichaPath sem issue unica; confira IssueInputs antes de converter.' }
        $fichas[(Resolve-ProjectPath $single $State.Project.Root)]=$ids[0]
    }
    foreach ($item in @(Get-LegacyValue $planData 'IssueInputs' @())) {
        $path=Get-LegacyValue $item 'FichaPath'
        if ($path) { $fichas[(Resolve-ProjectPath $path $State.Project.Root)]=[string]$item.Id }
    }
    $ownership=Get-ConversionEvidenceOwners $State $Record $allPriorities $entries $aliases $diagnostics $bases
    $owners=$ownership.Owners; $requiredTargets=@{}
    $requiredConsumers=@{}; $requiredConsumers[$State.Project.Name]=$true
    foreach ($priority in $Prioritizations) {
        if ((Get-LegacyValue $priority 'Master' $State.Project).Name -ceq $State.Project.Name) {
            $examined=Get-LegacyValue $priority 'Examined' @{}
            foreach ($issue in $examined.Values) { $requiredConsumers[$issue.Project]=$true }
        }
    }
    $pending=New-Object 'Collections.Generic.Queue[object]'
    foreach ($entry in @($entries | Where-Object ContextPath -IIn $contexts)) {
        $pending.Enqueue($entry)
    }
    # Fichas/rankings ja tem destino proprio. Descobrir somente os anexos
    # vizinhos dos documentos realmente selecionados, sem copiar os controles.
    $roots=@(foreach ($priority in $Prioritizations) { @($priority.Rankings)+@($priority.Fichas.Values | Where-Object HasContent) })
    if ($Record) {
        foreach ($field in @('PlanPath','TodoPath')) {
            $path=Get-LegacyValue $Record.Data $field
            if ($path) { $roots+=@([pscustomobject]@{Path=$path;Text=(Read-ConversionText $State.Inputs.Session $path)}) }
        }
    }
    foreach ($document in $roots) {
            $directory=Split-Path $document.Path -Parent
            foreach ($link in @(Get-ConversionLinks $document.Text $document.Path $State.Inputs.Session)) {
                if ($State.Map.ContainsKey($link)) { continue }
                if ($aliases.ContainsKey($link)) { $pending.Enqueue([pscustomobject]@{Path=$aliases[$link];Kind='EVIDENCIA'}); continue }
                if ($link.StartsWith($directory+'\',[StringComparison]::OrdinalIgnoreCase)) { $pending.Enqueue([pscustomobject]@{Path=$link;Kind='EVIDENCIA'}) }
            }
    }
    $seen=@{}; $documents=@(); $foreignFiles=@(); $destinations=@{}; $evidence=@(); $fichaPaths=@()
    $index=Get-LegacyValue $planData 'EvidenceIndexPath'
    if ($index) { $index=Resolve-ProjectPath $index $State.Project.Root }
    $indices=@(foreach ($plan in $plans) { $path=Get-LegacyValue $plan.Data 'EvidenceIndexPath'; if ($path) { Resolve-ProjectPath $path $State.Project.Root } })
    while ($pending.Count) {
        if ($seen.Count -gt 1000) { throw 'Anexos excedem 1000 referencias; delimite as evidencias necessarias.' }
        $entry=$pending.Dequeue(); $path=[string]$entry.Path
        if ($path -and $aliases.ContainsKey($path)) { $path=$aliases[$path] }
        if (-not $path -or $seen.ContainsKey($path)) { continue }; $seen[$path]=$true
        if ($entry.Kind -eq 'ORIGEM_MTA') { continue }
        if ($diagnostics.ContainsKey($path)) { $State.Diagnostics.Add('Diagnostico legado requer fonte direta: '+$path); continue }
        $relation=if ($relations.ContainsKey($path)) { @($relations[$path] | Where-Object { $_ } | Sort-Object -Unique) -join '; ' } else { 'Evidencia: '+[IO.Path]::GetFileName($path) }
        if ($State.Map.ContainsKey($path) -and -not $fichas.ContainsKey($path)) {
            if ($relations.ContainsKey($path)) { $evidence+=@([pscustomobject]@{Path=$State.Map[$path];Relation=$relation;Status='DISPONIVEL'}) }
            continue
        }
        if ($path -match '^https?://') {
            $evidence+=@([pscustomobject]@{Path=$path;Relation=$relation;Status='REFERENCIA EXTERNA'}); continue
        }
        $path=Resolve-ProjectPath $path $State.Project.Root
        $owner=if ($owners.ContainsKey($path)) {$owners[$path]} else {$State.Project}
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            $State.Diagnostics.Add('Anexo indisponivel: '+$path)
            $missing=if ($path.StartsWith($State.Inputs.Session.DataRoot+'\',[StringComparison]::OrdinalIgnoreCase)) { Join-Path $owner.EvidencePath ([IO.Path]::GetFileName($path)) } else { $path }
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
            $owner=$State.Project
        } else { $relative='evidencias/'+$(if ($path -iin $indices) {'LEIA-ME.md'} else {$leaf}) }
        $target=Join-Path $owner.Folder $relative
        if ($ownership.Consumers.ContainsKey($path) -and @($ownership.Consumers[$path].Keys | Where-Object { $requiredConsumers.ContainsKey($_) }).Count) { $requiredTargets[$target]=$true }
        if ($destinations.ContainsKey($target) -and $destinations[$target] -ine $path) { throw ('Anexos distintos disputam destino: '+$target+'. Resolva os nomes antes de converter.') }
        $destinations[$target]=$path
        $State.Map[$path]=$target
        if ($id) { $fichaPaths+=@([pscustomobject]@{Id=$id;Category=$category;Path=$target;Status='DISPONIVEL'}) }
        else { $evidence+=@([pscustomobject]@{Path=$target;Relation=$relation;Status='DISPONIVEL'}) }
        if ([IO.Path]::GetExtension($path) -ieq '.md') {
            $text=Read-ConversionText $State.Inputs.Session $path
            $base=if ($bases.ContainsKey($path)) {$bases[$path]} else {$path}
            $documents+=@([pscustomobject]@{Path=$path;Base=$base;Owner=$owner;Relative=$relative;Text=$text;Id=$id;Category=$category})
            foreach ($link in @(Get-ConversionLinks $text $base $State.Inputs.Session)) {
                # Links operacionais nao viram anexos. Somente arquivos vizinhos
                # aos anexos declarados podem ser descobertos pelo Markdown.
                if ($State.Map.ContainsKey($link)) { continue }
                if ($aliases.ContainsKey($link)) { $pending.Enqueue([pscustomobject]@{Path=$aliases[$link];Kind='EVIDENCIA'}); continue }
                $directory=Split-Path $base -Parent
                if ($link.StartsWith($directory+'\',[StringComparison]::OrdinalIgnoreCase)) {
                    $pending.Enqueue([pscustomobject]@{Path=$link;Kind='EVIDENCIA'})
                }
            }
        } else {
            $bytes=Read-ConversionBytes $State $path
            if ($owner.Name -ceq $State.Project.Name) { $State.Files[$relative]=$bytes }
            else { $foreignFiles+=@([pscustomobject]@{Owner=$owner;Relative=$relative;Content=$bytes}) }
        }
    }
    $State.EvidenceInputs=$evidence
    $State.FichaPaths=$fichaPaths
    foreach ($origin in $aliases.Keys) {
        if ($State.Map.ContainsKey($aliases[$origin])) { $State.Map[$origin]=$State.Map[$aliases[$origin]] }
    }
    if ($index -and $State.Map.ContainsKey($index)) { $State.EvidenceIndexPath=$State.Map[$index] }
    [pscustomobject]@{Documents=$documents;Relations=$relations;Record=$Record;ForeignFiles=$foreignFiles;RequiredTargets=$requiredTargets}
}

function Add-ConversionEvidenceDocuments($State,$Evidence) {
    if (-not $Evidence) { return }
    $relations=$Evidence.Relations; $Record=$Evidence.Record
    foreach ($file in $Evidence.ForeignFiles) { Assert-ConversionPartnerEvidence $State $file.Owner $file.Relative $file.Content $Evidence.RequiredTargets }
    foreach ($document in $Evidence.Documents) {
        $target=Join-Path $document.Owner.Folder $document.Relative
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
        if ($document.Owner.Name -cne $State.Project.Name) {
            Assert-ConversionPartnerEvidence $State $document.Owner $document.Relative $text $Evidence.RequiredTargets
            continue
        }
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
