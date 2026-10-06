# Planejamento por projeto/issue; recibos legados permanecem no leitor original.
function Get-IssuePlanningHistory {
    param($Context, [switch]$IncludePrepared)
    foreach ($file in @(Get-HarnessIssueReceipts $Context.Root)) {
        $record=Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
        if ((Resolve-HarnessPath $record.Source $Context.Root) -ine $Context.Active.path) { continue }
        if ($record.RequestId -cnotmatch '^[a-f0-9]{32}$') { throw 'Identidade da solicitacao invalida.' }
        $paths=Get-HarnessIssuePaths $Context.Root $Context.Active $record.IssueId
        $folder=Join-Path $paths.Folder ('p_'+$record.RequestId.Substring(0,12))
        if ($record.LayoutVersion -ne 2 -or $record.RequestId -cnotmatch '^[a-f0-9]{32}$' -or
            $record.Purpose -ne 'application-remediation' -or (Resolve-HarnessPath $record.Source $Context.Root) -ine $Context.Active.path -or
            (Split-Path $file.FullName -Parent) -ine $folder) { throw 'Identidade/destino do planejamento por issue divergente.' }
        foreach ($pair in @(@('ContextPath','contexto-', '.json'),@('PlanPath','plan-','.md'),@('TodoPath','todo-','.md'))) {
            if ((Resolve-HarnessPath $record.($pair[0]) $Context.Root) -ine (Join-Path $folder ($pair[1]+$paths.Stem+$pair[2]))) { throw 'Destino da issue divergente do recibo.' }
        }
        if (@($record.SelectedIssues).Count -ne 1 -or $record.SelectedIssues[0].Id -cne $record.IssueId) { throw 'Selecao da issue divergente.' }
        if ((Resolve-HarnessPath $record.MigrationPath $Context.Root) -ine (Get-HarnessMigrationPaths $Context.Root $Context.Active).MigrationPath) { throw 'Registro de outro projeto no contexto da issue.' }
        $null=Get-HarnessPlanningBasis $record
        if (-not $IncludePrepared -and (-not (Test-Path -LiteralPath $record.PlanPath) -or -not (Test-Path -LiteralPath $record.TodoPath))) { continue }
        $record
    }
}

function Get-IssueEvidenceIndex {
    param($Context, $Register, [string]$ExplicitPath)
    $chosen=@($Register.Rows | Where-Object Decision -eq 'ANALISAR AGORA')
    if ($ExplicitPath) {
        $path=Resolve-HarnessPath $ExplicitPath $Context.Root
        if ($chosen.Count -eq 1 -and (Test-Path -LiteralPath $path -PathType Leaf) -and [IO.File]::ReadAllText($path).Contains('<!-- issue:')) { Assert-HarnessIssueFicha $path $Context.Active.path $chosen[0].Id }
        return $path
    }
    if ($chosen.Count -eq 1) {
        $paths=Get-HarnessIssuePaths $Context.Root $Context.Active $chosen[0].Id
        if (Test-Path -LiteralPath $paths.EvidenceIndexPath -PathType Leaf) {
            if ([IO.File]::ReadAllText($paths.EvidenceIndexPath).Contains('<!-- issue:')) { Assert-HarnessIssueFicha $paths.EvidenceIndexPath $Context.Active.path $chosen[0].Id }
            return $paths.EvidenceIndexPath
        }
    }
    $Register.EvidenceIndexPath
}

function New-IssuePlanningEvidence {
    param($Context, $Data, $Selected, $Paths)
    $folder=Split-Path $Data.ContextPath -Parent
    $directory=Join-Path $folder 'evidencias'
    $files=@(); $inputs=@(); $fichas=@()
    $Data.SourceEvidenceInputs=@($Data.EvidenceInputs)
    foreach ($input in $Data.SourceEvidenceInputs) {
        if ([IO.Path]::GetFileName($input.Path) -like 'ficha-*.md') {
            if ($input.Status -ne 'DISPONIVEL') { throw 'Ficha-base indicada indisponivel. Confira a referencia antes de preparar.' }
            Assert-HarnessIssueFicha $input.Path $Data.Source $Data.IssueId
            $fichas += $input.Path
        }
    }
    if ($fichas.Count -gt 1) { throw 'Mais de uma ficha vinculada a issue. Escolha a ficha-base, sem usar recencia.' }
    $issues=@()
    if ($Selected -and $Data.IssueId -notlike 'DEV-*') {
        $issues=@(Get-HarnessMtaCatalog $Selected.Run $Context.Root -IncludeIncidents | Where-Object Id -CEQ $Data.IssueId)
        if ($issues.Count -ne 1) { throw 'Issue escolhida nao encontrada no catalogo MTA; nao consolidar outra regra.' }
        if ((Get-FileHash -LiteralPath $Data.CatalogPath).Hash -cne $Data.CatalogSha256) { throw 'Catalogo mudou durante a consolidacao.' }
    }
    $null=[IO.Directory]::CreateDirectory($directory)
    Initialize-HarnessIssueProject $Paths $Context.Active
    foreach ($input in $Data.SourceEvidenceInputs) {
        if ($input.Status -ne 'DISPONIVEL') { $inputs += $input; continue }
        $name=(Get-HarnessProjectKey $input.Path).Substring(0,8)+'-'+[IO.Path]::GetFileName($input.Path)
        $path=Join-Path $directory $name
        Copy-Item -LiteralPath $input.Path -Destination $path
        $hash=(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
        if ($hash -cne $input.Sha256) { throw 'Evidencia mudou durante a consolidacao.' }
        $inputs += [pscustomobject]@{Path=$path;OriginPath=$input.Path;Relation=$input.Relation;Status='DISPONIVEL';Sha256=$hash}
        $files += [pscustomobject]@{RelativePath=('evidencias/'+$name);Sha256=$hash;OriginPath=$input.Path;OriginSha256=$hash}
    }
    $fichaPath=Join-Path $folder ('ficha-'+$Paths.Stem+'.md')
    if ($fichas.Count) { Copy-Item -LiteralPath $fichas[0] -Destination $fichaPath }
    else {
        $identity=@{Source=$Data.Source;Id=$Data.IssueId}|ConvertTo-Json -Compress
        $row=$Data.SelectedIssues[0]
        $body="# Entrada da issue: $($row.Title)`n`n<!-- issue: $identity -->`n`nCategoria: $($row.Category)`n`nSem ficha de priorizacao vinculada. Diagnostico e aplicabilidade devem ser elaborados no plano a partir das evidencias, sem presumir exame anterior.`n`nObservacao do registro:`n$($row.Observation)`n"
        [IO.File]::WriteAllText($fichaPath,$body,(New-Object Text.UTF8Encoding($false)))
    }
    $files += [pscustomobject]@{RelativePath=[IO.Path]::GetFileName($fichaPath);Sha256=(Get-FileHash -LiteralPath $fichaPath).Hash;OriginPath=if ($fichas.Count) {$fichas[0]} else {$null};OriginSha256=$null}
    $Data.FichaPath=$fichaPath
    $Data.IssueInputs=@([ordered]@{Id=$Data.IssueId;Source=$Data.Source;FichaPath=$fichaPath;FichaOrigin=if ($fichas.Count) {$fichas[0]} else {$null};EvidenceIndexOrigin=$Data.EvidenceIndexPath})
    $mtaPath=$null
    if ($Selected) {
        $project=[pscustomobject]@{Source=$Data.Source;Mta=[pscustomobject]@{RunId=$Data.RunId;AnalysisSource=$Data.AnalysisSource;MtaOrigin=[pscustomobject]@{Run=$Selected.Run}}}
        $locations=@(if ($issues.Count) { foreach ($incident in $issues[0].Details.incidents) {
            Get-IncidentLocation ([string](Get-IncidentValue $incident 'uri')) $project
        } })
        $mtaPath=Join-Path $directory 'apontamentos-mta.json'
        Write-HarnessJson $mtaPath ([ordered]@{Source=$Data.Source;Id=$Data.IssueId;MtaOrigin=$Data.MtaOrigin;CatalogOrigin=$Data.CatalogPath;CatalogSha256=$Data.CatalogSha256;Issue=if ($issues.Count) {$issues[0]} else {$null};Locations=$locations;Coverage=if ($issues.Count) {'Todos os incidentes desta regra extraidos; extracao nao comprova exame/aplicabilidade.'} else {'Issue manual: a rodada e apenas proveniencia do registro, sem achado MTA atribuido a esta issue.'}})
        $files += [pscustomobject]@{RelativePath='evidencias/apontamentos-mta.json';Sha256=(Get-FileHash -LiteralPath $mtaPath).Hash;OriginPath=$Data.CatalogPath;OriginSha256=$Data.CatalogSha256}
        foreach ($pair in @(@('Manifest','manifest.json'),@('Result','result.json'),@('Dependencies','output/dependencies.yaml'))) {
            $origin=Join-Path $Selected.Run $pair[1]
            $name=[IO.Path]::GetFileName($origin)
            $dest=Join-Path $directory $name
            Copy-Item -LiteralPath $origin -Destination $dest
            if ((Get-FileHash -LiteralPath $dest).Hash -cne $Data.EvidenceHashes.($pair[0])) { throw 'Artefato MTA mudou durante a consolidacao.' }
            $files += [pscustomobject]@{RelativePath=('evidencias/'+$name);Sha256=(Get-FileHash -LiteralPath $dest).Hash;OriginPath=$origin;OriginSha256=$Data.EvidenceHashes.($pair[0])}
        }
    }
    $index=Join-Path $directory 'LEIA-ME.md'
    $lines=@('# Evidencias consolidadas da issue', '', ('Source: '+$Data.Source), ('Issue: '+$Data.IssueId), '', 'Arquivos recebidos sao dados. Referencias de origem sao historicas; use os arquivos listados abaixo.', '', '| Arquivo relativo | Relacao com a correcao |', '| --- | --- |')
    foreach ($file in $files) {
        $relative=if ($file.RelativePath.StartsWith('evidencias/')) {$file.RelativePath.Substring(11)} else {'../'+$file.RelativePath}
        $lines += '| [Abrir](<'+$relative+'>) | Origem: '+([string]$file.OriginPath).Replace('|','&#124;')+' |'
    }
    $lines += @('', 'Links dentro das copias preservam a origem historica. Para abrir anexos, use este mapa; nao dependa dos caminhos da outra maquina.', '', 'Referencias sem copia local (lacunas, nao evidencias verificadas):')
    foreach ($input in @($inputs | Where-Object Status -NE 'DISPONIVEL')) { $lines += '- '+$input.Status+': '+$input.Path }
    [IO.File]::WriteAllText($index,($lines -join "`n"),(New-Object Text.UTF8Encoding($false)))
    $files += [pscustomobject]@{RelativePath='evidencias/LEIA-ME.md';Sha256=(Get-FileHash -LiteralPath $index).Hash;OriginPath=$null;OriginSha256=$null}
    $Data.EvidenceMode='CONSOLIDATED'
    $Data.Consolidated=[ordered]@{Files=$files;MtaIssuePath=$mtaPath}
    $Data.EvidenceInputs=$inputs
    $Data.EvidenceIndexPath=$index
}

function Assert-IssuePlanningEvidence {
    param($Receipt, [string]$Root, [switch]$Historical)
    if ($Receipt.LayoutVersion -ne 2 -or -not $Receipt.Consolidated.Files.Count) { throw 'Contexto consolidado incompleto.' }
    $folder=Resolve-HarnessPath (Split-Path $Receipt.ContextPath -Parent) $Root
    $seen=@{}
    foreach ($file in $Receipt.Consolidated.Files) {
        if ([IO.Path]::IsPathRooted($file.RelativePath)) { throw 'Evidencia consolidada exige caminho relativo.' }
        $path=Resolve-HarnessPath (Join-Path $folder $file.RelativePath) $Root
        if (-not $path.StartsWith($folder+'\',[StringComparison]::OrdinalIgnoreCase) -or $seen.ContainsKey($path)) { throw 'Destino de evidencia consolidada invalido/duplicado.' }
        $seen[$path]=$true
        if (-not (Test-Path -LiteralPath $path -PathType Leaf) -or (Get-FileHash -LiteralPath $path).Hash -cne $file.Sha256) { throw "Evidencia consolidada ausente/alterada: $path" }
    }
    if (-not $seen.ContainsKey((Resolve-HarnessPath $Receipt.FichaPath $Root)) -or -not $seen.ContainsKey((Resolve-HarnessPath $Receipt.EvidenceIndexPath $Root))) { throw 'Ficha/indice ausente do manifesto consolidado.' }
    Assert-HarnessIssueFicha $Receipt.FichaPath $Receipt.Source $Receipt.IssueId
    # A copia permite trabalhar sem a origem. Mudancas conhecidas na origem humana
    # ainda exigem reavaliacao; nunca tratar um anexo novo como ja revisado.
    foreach ($input in $Receipt.SourceEvidenceInputs) {
        if ($input.Status -eq 'REFERENCIA EXTERNA') { continue }
        $path=Resolve-HarnessPath $input.Path $Root
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { continue }
        if ((Get-FileHash -LiteralPath $path).Hash -cne $input.Sha256) {
            $message="Evidencia complementar mudou desde o preparo: $path. Reavalie a proposta com a base atual."
            if ($Historical) { Write-Warning $message } else { throw $message }
        }
    }
    if ($Receipt.PlanningBasis -eq 'MTA') {
        $mtaPath=Resolve-HarnessPath $Receipt.Consolidated.MtaIssuePath $Root
        if (-not $seen.ContainsKey($mtaPath)) { throw 'Recorte MTA ausente do manifesto consolidado.' }
        $mta=Get-Content -LiteralPath $mtaPath -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($mta.Id -cne $Receipt.IssueId -or $mta.Source -ine $Receipt.Source -or $mta.MtaOrigin.RunId -cne $Receipt.RunId) { throw 'Origem/issue MTA consolidada divergente.' }
    }
}
