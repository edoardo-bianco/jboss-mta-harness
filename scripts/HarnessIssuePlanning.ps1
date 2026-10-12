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

# Entradas correntes sao referencias diretas; nao copiar anexos nem diagnostico.
function Get-CurrentPlanningEvidence {
    param($Project,$Rows,[string]$EvidenceIndexPath)
    if ($EvidenceIndexPath) { $index=Resolve-HarnessPath $EvidenceIndexPath $Project.Root }
    else { $index=Join-Path $Project.EvidencePath 'LEIA-ME.md' }
    $references=@(); $warnings=@(); $fichas=@()
    if (Test-Path -LiteralPath $index -PathType Leaf) {
        $references+=@([pscustomobject]@{Value=$index;Base=$Project.Root;Relation='Indice de evidencias'})
        $sources=@()
        $issueTable=$false
        foreach ($line in ([IO.File]::ReadAllText($index) -split '\r?\n')) {
            if ($line -match '^\s*\|\s*Issue\s*\|') { $issueTable=$true; continue }
            if ($issueTable -and $line -notmatch '^\s*\|') { $issueTable=$false }
            $relation='Anexo geral do indice'
            if ($issueTable) {
                $cells=$line.Trim().Trim('|').Split('|')
                if ($cells.Count -lt 3) { throw 'Tabela de evidencias por Issue exige arquivo e relacao.' }
                $id=$cells[0].Trim()
                if ($id -match '^:?-+:?$') { continue }
                if ($id -ne '*' -and $id -cnotin @($Rows | ForEach-Object Id)) { continue }
                $relation=$id+': '+$cells[2].Trim()
            }
            $sources+=@([pscustomobject]@{Text=$line;From=$index;Relation=$relation})
        }
    } else {
        if ($EvidenceIndexPath) { $references+=@([pscustomobject]@{Value=$index;Base=$Project.Root;Relation='Indice de evidencias'}) }
        $sources=@()
    }
    foreach ($row in $Rows) {
        $sources+=@([pscustomobject]@{Text=$row.Note;From=$Project.MigrationPath;Relation=$row.Id})
        $relative=Get-PrioritizationFichaRelativePath $row.Category $row.Id
        $path=Join-Path $Project.Folder $relative
        $read=Read-HarnessProjectFiles $Project @($relative)
        if ($read[$relative]) {
            $null=Read-PrioritizationFicha $read[$relative] $Project.Name $row.Category $row.Id
            $fichas+=@([pscustomobject]@{Id=$row.Id;Category=$row.Category;Path=$path;Status='DISPONIVEL'})
        } else { $fichas+=@([pscustomobject]@{Id=$row.Id;Category=$row.Category;Path=$path;Status='A ELABORAR'}) }
    }
    foreach ($source in $sources) {
        foreach ($match in [regex]::Matches($source.Text,'\[[^\]]*\]\((?:<([^>\r\n]+)>|([^\s\)]+))\)')) {
            $value=if ($match.Groups[1].Success) {$match.Groups[1].Value} else {$match.Groups[2].Value}
            $baseUri=New-Object Uri $source.From
            $uri=New-Object Uri (([uri]$baseUri.AbsoluteUri),$value)
            if ($uri.IsUnc -or $uri.Scheme -notin @('file','http','https')) { throw 'Referencia de evidencia com esquema/localizacao nao suportado.' }
            $references+=@([pscustomobject]@{Value=if ($uri.IsFile) {$uri.LocalPath} else {$uri.AbsoluteUri};Base=$Project.Root;Relation=$source.Relation})
        }
    }
    $inputs=@(); $seen=@{}
    foreach ($reference in $references) {
        $path=$reference.Value
        $status='REFERENCIA EXTERNA'
        if ($path -notmatch '^https?://') {
            $path=Resolve-HarnessPath $path $reference.Base
            # Documentos correntes se referenciam, mas nao viram anexos de si mesmos.
            if ($path -iin @($Project.PlanPath,$Project.TodoPath,$Project.ContextPath,$Project.MigrationPath,$Project.IndexPath)) { continue }
            $status=if (Test-Path -LiteralPath $path -PathType Leaf) {'DISPONIVEL'} else {'AUSENTE'}
        }
        if ($seen.ContainsKey($path)) { continue }; $seen[$path]=$true
        if ($status -eq 'AUSENTE') { $warnings+="Evidencia indisponivel: $path" }
        $inputs+=@([pscustomobject][ordered]@{Path=$path;Relation=$reference.Relation;Status=$status})
    }
    [pscustomobject]@{IndexPath=if ($EvidenceIndexPath -or (Test-Path -LiteralPath $index -PathType Leaf)) {$index} else {$null};Inputs=$inputs;Fichas=$fichas;Warnings=$warnings}
}

function Get-CurrentPlanningSources {
    param($Data,$Project,[string]$From,[string[]]$AvailablePaths=@())
    $lines=@((Get-HarnessSourceLink $From $Project.Pom 'POM'),(Get-HarnessSourceLink $From $Project.MigrationPath 'Decisoes e recorte atuais'),
        (Get-HarnessSourceLink $From $Data.PromptPath 'Orientacao do planejamento'),(Get-HarnessSourceLink $From $Data.ContractPath 'Contrato corrente'))
    foreach ($pair in @(@($Project.PlanPath,'Plano corrente'),@($Project.TodoPath,'Tarefas correntes'),@($Data.ReconciledPath,'Ultima reconciliacao'))) {
        if ((Test-Path -LiteralPath $pair[0] -PathType Leaf) -or $pair[0] -iin $AvailablePaths) { $lines+=Get-HarnessSourceLink $From $pair[0] $pair[1] }
    }
    if ($Data.PlanningBasis -eq 'MTA' -and $Data.Mta) {
        $lines+=Get-HarnessSourceLink $From $Data.Mta.ReportPath 'MTA atual'
    } else { $lines+='Base EVIDENCIAS: nenhum resultado MTA atribuido a esta proposta.' }
    foreach ($ficha in $Data.FichaPaths) {
        if ($ficha.Status -eq 'DISPONIVEL') { $lines+=Get-HarnessSourceLink $From $ficha.Path ('Ficha: '+$ficha.Id) }
        else { $lines+='Ficha ainda a elaborar: '+(ConvertTo-ProjectCell $ficha.Id) }
    }
    foreach ($input in $Data.EvidenceInputs) {
        if ($input.Status -eq 'DISPONIVEL') { $lines+=Get-HarnessSourceLink $From $input.Path $input.Relation }
        elseif ($input.Status -eq 'REFERENCIA EXTERNA') { $lines+='['+(ConvertTo-ProjectCell $input.Relation)+'](<'+$input.Path+'>)' }
        else { $lines+='Evidencia indisponivel: '+(ConvertTo-ProjectCell $input.Path) }
    }
    if (-not (Test-Path -LiteralPath $Data.ReconciledPath -PathType Leaf) -and -not ($AvailablePaths -icontains $Data.ReconciledPath)) { $lines+='Sem reconciliacao anterior disponivel: proposta preliminar.' }
    if ($Data.NeedsReview) { $lines+=@($Data.ReviewReasons | ForEach-Object { ConvertTo-ProjectCell $_ }) }
    $lines+='Preparar/retomar nao concede GO ou aceite. Releia as fontes: mesmo caminho nao comprova conteudo inalterado.'
    $lines -join ([Environment]::NewLine+[Environment]::NewLine)
}

function Assert-IssuePlanningEvidence {
    param($Data,[string]$Root)
    $project=Get-HarnessProjectStorage $Root $Data.Pom
    Assert-CurrentPlanningContext $Data $project
    foreach ($input in $Data.EvidenceInputs) {
        if ($input.Status -eq 'REFERENCIA EXTERNA') { continue }
        $path=Resolve-HarnessPath $input.Path $Root
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Evidencia indisponivel: $path. Reavalie a proposta corrente." }
    }
    # Disponibilidade nao atesta equivalencia do conteudo, GO ou aceite.
}
