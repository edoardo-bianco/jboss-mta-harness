function Get-ConversionAttachments($Session,$Record) {
    if (-not $Record) { return }
    $directory=Split-Path $Record.Path -Parent
    $entries=@()
    foreach ($field in @('FichaPath','EvidenceIndexPath','Run')) {
        $value=Get-LegacyValue $Record.Data $field
        if ($value) { $entries+=@([pscustomobject]@{Field=$field;Value=$value;Origin=$null;Relative=$false;Kind=$(if ($field -eq 'Run') {'ORIGEM_MTA'} else {'FICHA_OU_EVIDENCIA'})}) }
    }
    foreach ($field in @('EvidenceInputs','SourceEvidenceInputs')) {
        foreach ($item in @(Get-LegacyValue $Record.Data $field @())) {
            $value=Get-LegacyValue $item 'Path'
            if (-not $value) { $value=Get-LegacyValue $item 'Reference' }
            if ($value) { $entries+=@([pscustomobject]@{Field=$field;Value=$value;Origin=(Get-LegacyValue $item 'OriginPath');Relative=$false;Kind='EVIDENCIA';Relation=(Get-LegacyValue $item 'Relation' '')}) }
        }
    }
    foreach ($item in @(Get-LegacyValue $Record.Data 'IssueInputs' @())) {
        foreach ($field in @('FichaPath','FichaOrigin','EvidenceIndexOrigin')) {
            $value=Get-LegacyValue $item $field
            if ($value) { $entries+=@([pscustomobject]@{Field=('IssueInputs.'+$field);Value=$value;Origin=$null;Relative=$false;Kind='FICHA_OU_EVIDENCIA'}) }
        }
    }
    $consolidated=Get-LegacyValue $Record.Data 'Consolidated'
    foreach ($item in @(Get-LegacyValue $consolidated 'Files' @())) {
        $entries+=@([pscustomobject]@{Field='Consolidated.Files';Value=(Get-LegacyValue $item 'RelativePath');Origin=(Get-LegacyValue $item 'OriginPath');Relative=$true;Kind='COPIA_LEGADA_A_CLASSIFICAR'})
    }
    $mtaIssue=Get-LegacyValue $consolidated 'MtaIssuePath'
    if ($mtaIssue) { $entries+=@([pscustomobject]@{Field='Consolidated.MtaIssuePath';Value=$mtaIssue;Origin=$null;Relative=$false;Kind='EXTRATO_MTA'}) }
    foreach ($project in @(Get-LegacyValue $Record.Data 'Projects' @())) {
        $mta=Get-LegacyValue $project 'Mta'
        $incidents=Get-LegacyValue $mta 'IncidentEvidence'
        $paths=@(Get-LegacyValue $incidents 'IndexPath')+@(Get-LegacyValue $incidents 'Files' @() | ForEach-Object { Get-LegacyValue $_ 'Path' })
        foreach ($path in @($paths | Where-Object { $_ } | Sort-Object -Unique)) {
            $entries+=@([pscustomobject]@{Field='Projects.Mta.IncidentEvidence';Value=$path;Origin=$null;Relative=$false;Kind='EXTRATO_MTA'})
        }
    }
    foreach ($entry in $entries) {
        $path=$entry.Value; $available=$null; $kind=$entry.Kind; $valid=$true
        try {
            if ($path -match '^https?://') { $kind='REFERENCIA_EXTERNA' }
            else {
                if ($entry.Relative -and [IO.Path]::IsPathRooted($path)) { throw 'RelativePath deve ser relativo ao contexto.' }
                $path=Resolve-ProjectPath $path $(if ($entry.Relative) {$directory} else {$Session.Workspace})
                if ($entry.Relative -and -not $path.StartsWith($directory+'\',[StringComparison]::OrdinalIgnoreCase)) { throw 'Copia consolidada fora da solicitacao.' }
                $available=Test-Path -LiteralPath $path -PathType $(if ($kind -eq 'ORIGEM_MTA') {'Container'} else {'Leaf'})
                if (-not $available) { $Session.Pending.Add('Anexo/origem indisponivel: '+$path+' em '+$Record.Path) }
                # Papel/proveniencia prevalece sobre o nome: result.json pode
                # ser evidencia humana, e uma copia MTA pode ter sido renomeada.
                $run=Get-LegacyValue $Record.Data 'Run'
                $extract=Get-LegacyValue $consolidated 'MtaIssuePath'
                $origins=@($path)
                if ($entry.Origin) { $origins+=Resolve-ProjectPath $entry.Origin $Session.Workspace }
                if ($kind -ne 'ORIGEM_MTA') {
                    foreach ($origin in $origins) {
                        if (($extract -and $origin -ieq (Resolve-ProjectPath $extract $Session.Workspace)) -or
                            ($run -and $origin.StartsWith((Resolve-ProjectPath $run $Session.Workspace)+'\',[StringComparison]::OrdinalIgnoreCase))) { $kind='COPIA_DIAGNOSTICO_LEGADO' }
                    }
                }
            }
        } catch { $Session.Pending.Add('Referencia estruturada invalida em '+$Record.Path+' ['+$entry.Field+']: '+$_.Exception.Message); $available=$false; $valid=$false }
        [pscustomobject]@{ContextPath=$Record.Path;Field=$entry.Field;Path=$path;OriginPath=$entry.Origin;Kind=$kind;Available=$available;Valid=$valid;Relation=(Get-LegacyValue $entry 'Relation' '');Selection='PENDENTE'}
    }
    if ($entries.Count) { $Session.Pending.Add('Consolidar fichas/anexos e substituir dependencias de copias diagnosticas por fontes diretas antes de aplicar: '+$Record.Path) }
}
