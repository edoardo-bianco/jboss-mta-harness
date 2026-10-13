function Get-ConversionReconciliation($Session,$Records,$Register) {
    $declarations=@()
    $inputs=@()
    if ($Register) {
        $inputs+=@([pscustomobject]@{Path=$Register.Path;Field=$null;Text=$Register.Text})
        foreach ($record in $Records | Where-Object { $_.Kind -in @('RECONCILIACAO','PLANEJAMENTO') }) {
            $migration=Get-LegacyValue $record.Data 'MigrationPath'
            if (-not $migration -or (Resolve-ProjectPath $migration $Session.Workspace) -ine $Register.Path) { continue }
            $inputs+=@([pscustomobject]@{Path=$record.Path;Field='MigrationSnapshot';Text=(Get-LegacyValue $record.Data 'MigrationSnapshot' '')})
            $inputs+=@([pscustomobject]@{Path=$record.Path;Field='PreviousMigration.Snapshot';Text=(Get-LegacyValue (Get-LegacyValue $record.Data 'PreviousMigration') 'Snapshot' '')})
        }
    }
    foreach ($input in $inputs) {
        $blocks=[regex]::Matches($input.Text,'(?s)<!-- reconciliacao:inicio -->.*?<!-- reconciliacao:fim -->')
        if ($blocks.Count -eq 0) { continue }
        if ($blocks.Count -ne 1) { $Session.Pending.Add('Reconciliacao ambigua em '+$input.Path+' '+$input.Field); continue }
        $states=[regex]::Matches($blocks[0].Value,'(?m)^Estado:\s*([^\r\n]+)')
        $requests=[regex]::Matches($blocks[0].Value,'(?m)^Solicitacao:\s*([^\r\n]+)')
        if ($states.Count -ne 1 -or $requests.Count -ne 1) { $Session.Pending.Add('Declaracao de reconciliacao incompleta em '+$input.Path+' '+$input.Field); continue }
        $declarations+=@([pscustomobject]@{Path=$input.Path;Field=$input.Field;State=$states[0].Groups[1].Value.Trim();RequestId=$requests[0].Groups[1].Value.Trim();Evidence='DECLARADA_A_CONFERIR'})
    }
    [pscustomobject]@{State='PRELIMINAR';Basis=$null;Declarations=$declarations;Reason='Recibo, snapshot e declaracao CONCLUIDA nao comprovam comparacao executada. Conferir conclusoes humanas antes de propor base reconciliada.'}
}

function Get-ConversionRelated($Session,$Records,$Project) {
    foreach ($record in $Records | Where-Object { $_.Kind -notin @('REGISTRO','PLANEJAMENTO','RECONCILIACAO') }) {
        $category=$null
        $destination=switch ($record.Kind) {
            'PRIORIZACAO' {
                $category=if ((Get-LegacyValue $record.Data 'SchemaVersion' 0) -ge 4) { [string](Get-LegacyValue $record.Data 'Category') } else { 'mandatory' }
                if ($category) { Join-Path $Project.Folder ('atual/priorizacao/'+(ConvertTo-HarnessFunctionalPath $category)) }
            }
            'BUILDS' { Join-Path $Project.Folder 'atual/build' }
            'SONAR' { Join-Path $Project.Folder 'atual/diagnosticos/sonar' }
            'SPRINT' { $null } # Mestre participante e nome funcional exigem escolha.
            default { $null }
        }
        $paths=@()
        foreach ($field in @('RankingPath','EvidenceIndexPath','SprintDataPath','SprintPlanPath','ValidationPath','LogPath','ResultPath')) {
            $value=Get-LegacyValue $record.Data $field
            if ($value) {
                $path=Resolve-ProjectPath $value $Session.Workspace
                $paths+=@([pscustomobject]@{Field=$field;Path=$path;Available=(Test-Path -LiteralPath $path -PathType Leaf)})
            }
        }
        $Session.Pending.Add('Conferir conjunto corrente, cobertura e destino de '+$record.Kind+': '+$record.Path)
        [pscustomobject]@{Kind=$record.Kind;Path=$record.Path;Sources=$record.Sources;Category=$category;ProposedDirectory=$destination;Selection='PENDENTE';References=$paths}
    }
}

function Get-ConversionReferences($Session,$Proposed,$Project,[string]$LegacySource) {
    $map=@{}
    foreach ($file in $Proposed) { if ($file.Origin) { $map[$file.Origin]=$file.Destination } }
    foreach ($file in $Proposed | Where-Object { $_.Origin -and $_.Origin.EndsWith('.md',[StringComparison]::OrdinalIgnoreCase) }) {
        $text=Read-ConversionText $Session $file.Origin
        foreach ($origin in @(Get-ConversionLinks $text $file.Origin $Session | Sort-Object -Unique)) {
            $destination=$null; $action='CONFERIR_DESTINO'
            if ($map.ContainsKey($origin)) { $destination=$map[$origin]; $action='REESCREVER_LINK' }
            elseif ($origin.StartsWith($LegacySource+'\',[StringComparison]::OrdinalIgnoreCase)) {
                $destination=Resolve-ProjectPath (Join-Path $Project.Source $origin.Substring($LegacySource.Length+1)) $Session.Workspace; $action='REFERENCIAR_SOURCE_LOCAL'
            } elseif (-not $origin.StartsWith($Session.DataRoot+'\',[StringComparison]::OrdinalIgnoreCase)) {
                $destination=$origin; $action='PRESERVAR_REFERENCIA_EXTERNA'
            }
            $available=Test-Path -LiteralPath $origin -PathType Leaf
            $destinationAvailable=if ($destination) { Test-Path -LiteralPath $destination -PathType Leaf } else { $null }
            if ($action -eq 'REFERENCIAR_SOURCE_LOCAL' -and -not $destinationAvailable) { $Session.Pending.Add('Fonte local remapeado indisponivel: '+$destination) }
            if (-not $available -or -not $destination) { $Session.Pending.Add('Referencia ausente ou sem destino corrente: '+$origin+' em '+$file.Origin) }
            [pscustomobject]@{Document=$file.Origin;Origin=$origin;Destination=$destination;Available=$available;DestinationAvailable=$destinationAvailable;Action=$action}
        }
    }
}
