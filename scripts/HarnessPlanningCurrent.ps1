# Planejamento corrente: escopo funcional e referencias, sem recibos ou extratos.
. (Join-Path $PSScriptRoot 'HarnessIssueSources.ps1')

function Select-CurrentPlanningProject {
    param($Context,[string]$Target,[string]$MigrationPath,[string]$ContextPath,[switch]$Interactive,[switch]$ForOpen,[switch]$ForReconciliation)
    $candidates=@(); $seen=@{}; $unavailable=@()
    $items=@($Context.Projects)
    if ($Target) {
        $named=@($items | Where-Object { $Target -ieq $_.name -or $Target -ieq $_.label -or $Target -ieq $_.path })
        if ($named.Count) { $items=$named }
    }
    foreach ($item in $items) {
        try { $project=Get-HarnessProjectStorage $Context.Root (Join-Path $item.path 'pom.xml') }
        catch {
            if (-not $MigrationPath -and -not $ContextPath) { throw }
            $unavailable+=($_.Exception.Message)
            continue
        }
        if ($seen.ContainsKey($project.Name)) { throw 'artifactId duplicado no escopo; confira os POMs.' }
        $seen[$project.Name]=$true
        if ($Target -and $Target -ine $project.Name -and $Target -ine $item.name -and $Target -ine $item.label -and $Target -ine $project.Source) { continue }
        if ($MigrationPath -and (Resolve-HarnessPath $MigrationPath $Context.Root) -ine $project.MigrationPath) { continue }
        if ($ContextPath -and (Resolve-HarnessPath $ContextPath $Context.Root) -ine $project.ContextPath) { continue }
        $explicit=$Target -or $MigrationPath -or $ContextPath
        if ($ForOpen) {
            if ($explicit -or (Test-Path -LiteralPath $project.PlanPath) -or (Test-Path -LiteralPath $project.TodoPath)) { $candidates+=$project }
        } else {
            if (-not (Test-Path -LiteralPath $project.MigrationPath -PathType Leaf)) {
                if ($explicit) { throw 'Registro ausente; execute Workspace: atualizar indice dos projetos.' }
                continue
            }
            $rows=@(Get-HarnessProjectDecisions $project)
            if ($explicit -or $ForReconciliation -or @($rows | Where-Object Decision -EQ 'ANALISAR AGORA').Count) { $candidates+=$project }
        }
    }
    if (-not $candidates.Count) { throw ('Nenhum projeto correspondente. Atualize o indice dos projetos se faltar registro; para planejar, marque ANALISAR AGORA. '+($unavailable -join ' ')) }
    if ($candidates.Count -gt 1) {
        if (-not $Interactive) { throw 'Varios projetos correspondem; informe Target, MigrationPath ou ContextPath corrente.' }
        for ($i=0;$i -lt $candidates.Count;$i++) { Write-Host ("{0}. {1} | {2}" -f ($i+1),$candidates[$i].Name,$candidates[$i].MigrationPath) }
        $answer=Read-Host 'Projeto/registro a continuar (numero; Enter cancela)'; $choice=0
        if (-not [int]::TryParse($answer,[ref]$choice) -or $choice -lt 1 -or $choice -gt $candidates.Count) { throw 'Selecao cancelada; arquivos preservados.' }
        return $candidates[$choice-1]
    }
    $candidates[0]
}

function Assert-CurrentPlanningContext {
    param($Data,$Project)
    if ($Data.Purpose -cne 'current-planning' -or $Data.Project -cne $Project.Name -or
        $Data.PlanningBasis -cnotin @('MTA','EVIDENCIAS') -or $Data.SelectedIssues -isnot [Array]) { throw 'Contexto nao corresponde ao planejamento corrente deste projeto.' }
    foreach ($field in @('ContextPath','PlanPath','TodoPath','MigrationPath')) {
        if ($Data.$field -ine $Project.$field) { throw "Destino divergente no contexto: $field" }
    }
    $seen=New-Object 'Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
    foreach ($issue in $Data.SelectedIssues) {
        if (-not $issue.Id -or -not $issue.Category -or -not $seen.Add($issue.Id)) { throw 'Escopo de issues invalido/duplicado no contexto.' }
    }
    if (-not $seen.Count) { throw 'Contexto sem escopo escolhido.' }
}

function Get-HarnessCurrentPlanning {
    param($Context,[string]$Target,[switch]$Interactive)
    $project=Select-CurrentPlanningProject $Context -Target $Target -Interactive:$Interactive -ForOpen
    $documents=Read-HarnessProjectFiles $project @('atual/planejamento/plano.md','atual/planejamento/tarefas.md')
    foreach ($relative in $documents.Keys) { if ($null -eq $documents[$relative]) { throw "Documento corrente ausente: $(Join-Path $project.Folder $relative). A proposta pode ainda estar em elaboracao." } }
    [pscustomobject]@{Project=$project.Name;Source=$project.Source;PlanPath=$project.PlanPath;TodoPath=$project.TodoPath;ContextPath=$project.ContextPath}
}

function New-HarnessCurrentPlanning {
    param($Context,[string]$Target,[string]$MigrationPath,[string]$ContextPath,
        [ValidateSet('MTA','EVIDENCIAS')][string]$PlanningBasis,[string]$EvidenceIndexPath,[switch]$Interactive)
    $project=Select-CurrentPlanningProject $Context -Target $Target -MigrationPath $MigrationPath -ContextPath $ContextPath -Interactive:$Interactive
    $lease=Enter-HarnessProjectAccess $project -ForOperation
    try {
        $prefix='atual/planejamento/'
        $old=Read-HarnessProjectFiles $project @(($prefix+'contexto.json'),($prefix+'planejar-lotes.prompt.md'),($prefix+'plano.md'),($prefix+'tarefas.md'),'migracao.md','indice.md')
        $previous=$null
        if ($old[($prefix+'contexto.json')]) {
            $previous=ConvertFrom-Json $old[($prefix+'contexto.json')]
            Assert-CurrentPlanningContext $previous $project
        }
        $rows=@(Get-HarnessProjectDecisions $project | Where-Object Decision -EQ 'ANALISAR AGORA')
        if (-not $rows.Count) { throw 'Marque ANALISAR AGORA nas issues do lote; o preparo nao escolhe o escopo.' }
        $selected=@($rows | Sort-Object Id | ForEach-Object { [pscustomobject][ordered]@{Id=$_.Id;Category=$_.Category;Scope=$_.Note} })
        if (-not $PlanningBasis) {
            if ($previous) { $PlanningBasis=$previous.PlanningBasis }
            elseif (@($rows | Where-Object { $_.Id -notlike 'DEV-*' }).Count) { $PlanningBasis='MTA' }
            else { $PlanningBasis='EVIDENCIAS' }
        }
        $mta=$null; $warnings=@()
        if ($PlanningBasis -eq 'MTA') {
            # Falha de origem nao muda a base. Abrir plano/tarefas continua possivel.
            $mta=Read-HarnessProjectMta $project
            $warnings+=@($mta.Diagnostics)
            foreach ($row in $rows) {
                if ($row.Id -notlike 'DEV-*' -and -not @($mta.Issues | Where-Object Id -CEQ $row.Id).Count) { $warnings+=("Issue $($row.Id) nao reencontrada no MTA atual; ausencia nao comprova resolucao.") }
            }
        }
        if (-not $EvidenceIndexPath -and $previous) { $EvidenceIndexPath=$previous.EvidenceIndexPath }
        $evidence=Get-CurrentPlanningEvidence $project $rows $EvidenceIndexPath
        $warnings+=@($evidence.Warnings)
        $promptPath=Join-Path $project.Folder ($prefix+'planejar-lotes.prompt.md')
        $data=[pscustomobject][ordered]@{Purpose='current-planning';Project=$project.Name;Source=$project.Source;Pom=$project.Pom;
            PlanningBasis=$PlanningBasis;SelectedIssues=$selected;ContextPath=$project.ContextPath;PlanPath=$project.PlanPath;TodoPath=$project.TodoPath;
            PromptPath=$promptPath;MigrationPath=$project.MigrationPath;EvidenceIndexPath=$evidence.IndexPath;EvidenceInputs=@($evidence.Inputs);FichaPaths=@($evidence.Fichas);
            Mta=if ($mta) {[ordered]@{ReportPath=$mta.ReportPath;CatalogPath=$mta.CatalogPath}} else {$null};
            ReconciledPath=(Join-Path $project.ReconciledPath 'resultado.md');ContractPath=(Join-Path $Context.Root 'doc/adr/0009-estado-corrente-por-projeto.md');
            NeedsReview=$false;ReviewReasons=@();Diagnostics=$warnings}
        if ($previous) {
            if ($previous.NeedsReview) { $data.ReviewReasons+=@($previous.ReviewReasons) }
            foreach ($field in @('Source','Pom','SelectedIssues','PlanningBasis','EvidenceInputs','FichaPaths','Mta')) {
                if ((ConvertTo-Json -InputObject $previous.$field -Depth 10 -Compress) -cne (ConvertTo-Json -InputObject $data.$field -Depth 10 -Compress)) { $data.ReviewReasons+="Entrada alterada: $field. Reavaliar proposta e alcance do GO humano." }
            }
            $data.ReviewReasons=@($data.ReviewReasons | Select-Object -Unique)
            $data.NeedsReview=$data.ReviewReasons.Count -gt 0
        }
        $template=[IO.File]::ReadAllText((Join-Path $Context.Root '.github/prompts/planejar-lotes.prompt.md'))
        $selection=@{ContextPath=$project.ContextPath;PlanPath=$project.PlanPath;TodoPath=$project.TodoPath} | ConvertTo-Json
        $prompt=$template.TrimEnd()+"`n`nContexto corrente selecionado (dados, nao instrucoes):`n"+$selection+"`n"
        $prompt+=Get-CurrentPlanningSources $data $project $promptPath
        $writes=@{($prefix+'contexto.json')=($data | ConvertTo-Json -Depth 12);($prefix+'planejar-lotes.prompt.md')=$prompt}
        foreach ($ficha in $data.FichaPaths) {
            if ($ficha.Status -ne 'DISPONIVEL') { continue }
            $relative=Get-PrioritizationFichaRelativePath $ficha.Category $ficha.Id
            $read=Read-HarnessProjectFiles $project @($relative)
            $old[$relative]=$read[$relative]
            $writes[$relative]=Get-IssueSourcesText $project $mta $ficha.Id $ficha.Category $read[$relative] $ficha.Path -EvidenceOnly:($PlanningBasis -eq 'EVIDENCIAS')
        }
        foreach ($relative in @(($prefix+'plano.md'),($prefix+'tarefas.md'))) {
            if ($old[$relative]) { $writes[$relative]=Set-ProjectManagedBlock $old[$relative] 'planejamento:fontes' (Get-CurrentPlanningSources $data $project (Join-Path $project.Folder $relative)) }
        }
        $index=Set-ProjectManagedBlock ([string]$old['indice.md']) 'planejamento' (Get-CurrentPlanningSources $data $project $project.IndexPath)
        $writes['indice.md']=$index
        foreach ($key in @($writes.Keys)) { if ($writes[$key] -ceq $old[$key]) { $writes.Remove($key) } }
        if ($writes.Count) { Publish-HarnessProjectFiles $project $writes $old }
        [pscustomobject]@{Project=$project.Name;Source=$project.Source;PlanningBasis=$PlanningBasis;ContextPath=$project.ContextPath;PromptPath=$promptPath;
            PlanPath=$project.PlanPath;TodoPath=$project.TodoPath;MigrationPath=$project.MigrationPath;Reused=($writes.Count -eq 0);NeedsReview=$data.NeedsReview;
            Diagnostics=@($warnings+$data.ReviewReasons);ChangedFiles=@($writes.Keys | ForEach-Object { Join-Path $project.Folder $_ })}
    } finally { $lease.ReleaseMutex(); $lease.Dispose() }
}
