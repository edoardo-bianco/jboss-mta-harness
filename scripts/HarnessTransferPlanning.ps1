function New-TransferPlanningWrites {
    param($Context,$Manifest,$Archive,[string]$Base,$Records,$Selected,$Mapping,$Writes,$Projects)
    foreach ($item in $Records) {
        $old=$item.Record; $local=Convert-TransferValue $old $Mapping
        $project=$Projects[$old.Source]; $local.Project=$project.name; $local.Label=$project.label
        $local | Add-Member NoteProperty ImportedFrom ([pscustomobject]@{PackageId=$Manifest.PackageId;OriginalSource=$old.Source;OriginalContextPath=(Join-Path $Base ('original/'+$item.Entry));OriginalContextSha256=(@($Manifest.Files | Where-Object Entry -CEQ $item.Entry)[0]).Sha256}) -Force
        foreach ($field in @('PlanPath','TodoPath')) {
            $file=@($Manifest.Files | Where-Object { $_.OriginPath.Replace('\','/') -ieq $old.$field.Replace('\','/') })
            if ($file.Count) { Add-TransferWrite $Writes $local.$field (Get-TransferBytes (Convert-TransferDocument (Read-TransferText $Archive $file[0].Entry) $file[0].OriginPath $Mapping)) $null }
        }
        foreach ($file in $old.Consolidated.Files) {
            Assert-TransferRelativePath $file.RelativePath
            $origin=Join-Path (Split-Path $old.ContextPath -Parent) $file.RelativePath
            $source=@($Manifest.Files | Where-Object { $_.OriginPath.Replace('\','/') -ieq $origin.Replace('\','/') })
            if ($source.Count -ne 1 -or $source[0].Sha256 -ine $file.Sha256) { throw 'Evidencia consolidada diverge do inventario do pacote.' }
            $dest=Convert-TransferText $origin $Mapping
            $bytes=$null
            if ($origin -like '*.md') { $bytes=Get-TransferBytes (Convert-TransferDocument (Read-TransferText $Archive $source[0].Entry) $origin $Mapping) }
            elseif ($old.Consolidated.MtaIssuePath -and $origin.Replace('\','/') -ieq $old.Consolidated.MtaIssuePath.Replace('\','/')) {
                $mta=Read-TransferText $Archive $source[0].Entry | ConvertFrom-Json
                $mta.Source=$local.Source
                foreach ($location in $mta.Locations) { if ($location.SourceCandidate) { $location.SourceCandidate=Convert-TransferText $location.SourceCandidate $Mapping } }
                $bytes=Get-TransferBytes ($mta | ConvertTo-Json -Depth 60)
            }
            Add-TransferWrite $Writes $dest $bytes $source[0].Entry
        }
        foreach ($file in $local.Consolidated.Files) {
            $origin=Join-Path (Split-Path $old.ContextPath -Parent) $file.RelativePath
            $dest=Convert-TransferText $origin $Mapping
            $file.RelativePath=$dest.Substring($item.Folder.Length+1).Replace('\','/')
            $file.Sha256=Get-TransferWriteHash $Writes $dest $Manifest
        }
        foreach ($input in $local.EvidenceInputs) { if ($input.Status -eq 'DISPONIVEL') { $input.Sha256=Get-TransferWriteHash $Writes $input.Path $Manifest } }
        $item | Add-Member NoteProperty Local $local
    }
    $root=$Selected.Local; $issue=$Selected.IssuePaths
    $editable=Split-Path $issue.EvidenceIndexPath -Parent
    $entries=@([pscustomobject]@{Path=$root.FichaPath;Relation='Ficha-base recebida'})+@($root.EvidenceInputs | Where-Object { $_.Status -eq 'DISPONIVEL' -and $_.Relation -ne 'Indice de evidencias' -and $_.Path -ine $root.FichaPath })
    $index=@('# Evidencias da issue recebida','',('<!-- issue: '+(@{Source=$root.Source;Id=$root.IssueId} | ConvertTo-Json -Compress)+' -->'),'', '| Arquivo relativo | Relacao com a correcao |','| --- | --- |')
    $inputs=@(); $seen=@{}
    foreach ($entry in $entries) {
        $name=[IO.Path]::GetFileName($entry.Path); $dest=Join-Path $editable $name
        if ($seen.ContainsKey($dest)) { continue }; $seen[$dest]=$true
        if (-not $Writes.ContainsKey($entry.Path)) { throw 'Anexo ativo ausente das copias consolidadas.' }
        $write=$Writes[$entry.Path]; Add-TransferWrite $Writes $dest $write.Bytes $write.Entry
        $relation=([string]$entry.Relation).Replace('|','&#124;').Replace("`n",' ').Replace("`r",' ')
        $index += '| ['+$name+'](<'+$name+'>) | '+$relation+' |'
        $inputs += [pscustomobject]@{Path=$dest;Reference=$name;Relation=$relation;Status='DISPONIVEL';Sha256=(Get-TransferWriteHash $Writes $dest $Manifest)}
    }
    Add-TransferWrite $Writes $issue.EvidenceIndexPath (Get-TransferBytes ($index -join "`n")) $null
    $inputs=@([pscustomobject]@{Path=$issue.EvidenceIndexPath;Reference=$issue.EvidenceIndexPath;Relation='Indice de evidencias';Status='DISPONIVEL';Sha256=(Get-TransferWriteHash $Writes $issue.EvidenceIndexPath $Manifest)})+$inputs
    $originProject=@($Manifest.Projects | Where-Object Source -IEQ $Selected.Record.Source)[0]
    $registerFile=@($Manifest.Files | Where-Object Entry -CEQ $originProject.RegisterEntry)[0]
    $registerText=Convert-TransferDocument (Read-TransferText $Archive $originProject.RegisterEntry) $registerFile.OriginPath $Mapping -Register
    $registerText=[regex]::Replace($registerText,'(?m)^Project:[^\r\n]*',('Project: '+$root.Project))
    $block=[regex]::Match($registerText,'(?s)<!-- mta:inicio -->.*?<!-- mta:fim -->')
    if (-not $block.Success) { throw 'Registro recebido sem tabela de issues.' }
    $lines=@(); $id=$root.IssueId
    foreach ($line in ($block.Value -split '\r?\n')) {
        if ($line.StartsWith('|') -and $line -notmatch '^\| (ID \(|---)') {
            $cells=@($line.Trim().Trim('|').Split('|') | ForEach-Object { $_.Trim() })
            if ($cells.Count -ne 8) { throw 'Linha de registro recebido invalida.' }
            if ($cells[0] -cne $id) { continue }
            $cells[5]='ANALISAR AGORA'; $cells[6]='PLANEJADA'
            $cells[7]='Proposta recebida; conferir escopo/GO e codigo local. [Plano](<'+$root.PlanPath+'>) [Contexto](<'+$root.ContextPath+'>)'
            $lines += '| '+($cells -join ' | ')+' |'
        } else { $lines += $line }
    }
    $registerText=$registerText.Replace($block.Value,($lines -join "`n"))
    $registerText += "`n`nRecorte recebido: $id. Decisoes e verificacoes da origem nao comprovam execucao neste checkout.`n"
    Add-TransferWrite $Writes $root.MigrationPath (Get-TransferBytes $registerText) $null
    $identity=@{Project=$root.Project;Source=$Projects[$Selected.Record.Source].path;ArtifactId=$issue.ArtifactId}
    if (-not (Test-Path -LiteralPath $issue.ProjectIdentityPath)) { Add-TransferWrite $Writes $issue.ProjectIdentityPath (Get-TransferBytes ($identity | ConvertTo-Json)) $null }
    $orderedRecords=@(); $pending=@($Records); $done=@{}
    while ($pending.Count) {
        $ready=@($pending | Where-Object { -not $_.Local.Previous -or $done.ContainsKey($_.Local.Previous.RequestId) })
        if (-not $ready.Count) { throw 'Previous ausente ou ciclico no pacote de planejamento.' }
        foreach ($entry in $ready) { $orderedRecords += $entry; $done[$entry.Local.RequestId]=$true }
        $pending=@($pending | Where-Object { -not $done.ContainsKey($_.Local.RequestId) })
    }
    foreach ($item in $orderedRecords) {
        $local=$item.Local
        if ($local.RequestId -ceq $root.RequestId) {
            $local.SourceEvidenceInputs=$inputs
            $local | Add-Member NoteProperty ImportedInputIndexPath $issue.EvidenceIndexPath -Force
            $local.MigrationSnapshot=$registerText
        } else {
            # As entradas historicas apontam as copias da propria revisao, nunca as da ponta.
            $local.SourceEvidenceInputs=@($local.EvidenceInputs)
            $local.MigrationSnapshot=Convert-TransferRegisterText $item.Record.MigrationSnapshot $Mapping
        }
        $local.MigrationSha256=Get-TransferBytesHash (Get-TransferBytes $local.MigrationSnapshot)
        if ($local.Previous) {
            $local.Previous.ContextSha256=Get-TransferWriteHash $Writes $local.Previous.ContextPath $Manifest
            $local.Previous.PlanSha256=Get-TransferWriteHash $Writes $local.Previous.PlanPath $Manifest
            $local.Previous.TodoSha256=Get-TransferWriteHash $Writes $local.Previous.TodoPath $Manifest
        }
        Add-TransferWrite $Writes $local.ContextPath (Get-TransferBytes ($local | ConvertTo-Json -Depth 60)) $null
        $promptFile=@($Manifest.Files | Where-Object { $_.Role -eq 'PROMPT' -and (Split-Path $_.OriginPath -Parent) -ieq (Split-Path $item.Record.ContextPath -Parent) })
        if ($promptFile.Count -ne 1) { throw 'Prompt de planejamento ausente/ambiguo no pacote.' }
        Add-TransferWrite $Writes (Join-Path $item.Folder 'planejar-lotes.prompt.md') (Get-TransferBytes (Convert-TransferText (Read-TransferText $Archive $promptFile[0].Entry) $Mapping)) $null
    }
}
function Write-TransferImport {
    param($Context,$Manifest,$Archive,[string]$Base,$Writes,$Directories,[string]$Marker,[scriptblock]$Validate)
    $state=Join-Path $Context.Root '.harness'; $null=[IO.Directory]::CreateDirectory($state)
    try { $lease=[IO.File]::Open((Join-Path $state 'planning.lock'),'OpenOrCreate','ReadWrite','None') }
    catch { throw 'Existe preparacao ou limpeza em andamento.' }
    $created=New-Object 'Collections.Generic.List[string]'
    $createdDirs=New-Object 'Collections.Generic.List[string]'
    $ensureDirectory={ param([string]$Path)
        Assert-TransferChild $Path $state
        $missing=New-Object 'Collections.Generic.Stack[string]'; $cursor=$Path
        while (-not (Test-Path -LiteralPath $cursor)) { $missing.Push($cursor); $cursor=Split-Path $cursor -Parent }
        Assert-TransferRegularPath $cursor
        while ($missing.Count) { $next=$missing.Pop(); $null=[IO.Directory]::CreateDirectory($next); $createdDirs.Add($next) }
    }
    try {
        foreach ($write in $Writes.Values) { if (Test-Path -LiteralPath $write.Path) { throw "Conflito local: $($write.Path)" } }
        foreach ($dir in $Directories) { & $ensureDirectory $dir }
        foreach ($write in @($Writes.Values | Where-Object Path -INE $Marker)+@($Writes[$Marker])) {
            if ($write.Path -ieq $Marker) { & $Validate }
            & $ensureDirectory (Split-Path $write.Path -Parent)
            Assert-TransferRegularPath (Split-Path $write.Path -Parent)
            $dest=[IO.File]::Open($write.Path,'CreateNew','Write','None'); $created.Add($write.Path)
            try {
                if ($null -ne $write.Bytes) { $dest.Write($write.Bytes,0,$write.Bytes.Length) }
                else { $source=$Archive.GetEntry($write.Entry).Open(); try { $source.CopyTo($dest) } finally { $source.Dispose() } }
            } finally { $dest.Dispose() }
        }
    } catch {
        # Somente arquivos criados por esta chamada, com destinos previamente validados.
        foreach ($path in $created) { [IO.File]::Delete($path) }
        for ($i=$createdDirs.Count-1; $i -ge 0; $i--) {
            $path=$createdDirs[$i]; Assert-TransferChild $path $state
            if ([IO.Directory]::Exists($path) -and -not [IO.Directory]::EnumerateFileSystemEntries($path).GetEnumerator().MoveNext()) { [IO.Directory]::Delete($path,$false) }
        }
        throw
    } finally { $lease.Dispose() }
}
