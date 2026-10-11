function New-HarnessReconciliationContext {
    param($Context,[string]$Target,[string]$MigrationPath,[string]$ReceivedPath,[string]$Reason,
        [ValidateSet('MTA','EVIDENCIAS')][string]$PlanningBasis,[switch]$LocalOnly,[switch]$Interactive,[switch]$SelectReceived)
    $project=Select-CurrentPlanningProject $Context -Target $Target -MigrationPath $MigrationPath -Interactive:$Interactive -ForReconciliation
    $lease=Enter-HarnessProjectAccess $project -ForOperation
    try {
        $contextRelative='atual/planejamento/reconciliacao.json'
        $promptRelative='atual/planejamento/manter-migracao.prompt.md'
        $contextPath=Join-Path $project.Folder $contextRelative
        $promptPath=Join-Path $project.Folder $promptRelative
        $old=Read-HarnessProjectFiles $project @($contextRelative,$promptRelative,'indice.md')
        $previous=$null; $relocated=$false; $bindingChanged=$false
        if ($old[$contextRelative]) {
            $previous=ConvertFrom-Json $old[$contextRelative]
            if ($previous.Purpose -cne 'current-reconciliation' -or $previous.Project -cne $project.Name) { throw 'Contexto de reconciliacao divergente; preserve e confira.' }
            $null=Get-ReconciliationContextFolder $previous $project 'reconciliacao.json'
            $bindingChanged=$previous.ContextPath -ine $contextPath -or $previous.Pom -ine $project.Pom -or $previous.Source -ine $project.Source
            $relocated=$bindingChanged
            if ($previous.PSObject.Properties['Relocated'] -and $previous.Relocated) { $relocated=$true }
        }
        if ($LocalOnly -and $ReceivedPath) { throw 'Use pasta recebida ou somente local, nao ambos.' }
        if (-not $ReceivedPath -and -not $LocalOnly -and $previous -and -not $bindingChanged) { $ReceivedPath=$previous.ReceivedPath }
        if ($SelectReceived -and $Interactive) {
            $default=if ($ReceivedPath) {$ReceivedPath} else {'somente documentos locais'}
            Write-Host "Origem atual: $default"
            $choice=Read-Host 'Pasta de colega opcional (Enter mantem; - usa somente local)'
            if ($choice -eq '-') { $ReceivedPath=$null; $LocalOnly=$true }
            elseif ($choice) { $ReceivedPath=$choice }
        }
        if ($LocalOnly) { $ReceivedPath=$null }
        if (-not $PlanningBasis) {
            if ($previous) { $PlanningBasis=$previous.PlanningBasis }
            elseif (@(Get-HarnessProjectDecisions $project | Where-Object { $_.Presence -ne 'MANUAL' }).Count) { $PlanningBasis='MTA' }
            else { $PlanningBasis='EVIDENCIAS' }
        }
        $comparison=Get-HarnessReconciliationComparison $project $ReceivedPath $PlanningBasis
        if (-not $Reason) {
            if ($comparison.ReceivedPath) { $Reason='Conferir documentos recebidos com o trabalho local.' }
            elseif ($comparison.Differences.Count) { $Reason='Conferir diferencas entre o diagnostico atual e o registro.' }
            elseif (-not $comparison.Local['reconciliado/resultado.md']) { $Reason='Conferir a base inicial com decisoes, evidencias e codigo local.' }
            elseif ($previous) { $Reason=$previous.Reason }
            elseif ($Interactive) { $Reason=Read-Host 'Motivo concreto da reconciliacao (conflito, evidencia ou decisao alterada)' }
            if ([string]::IsNullOrWhiteSpace($Reason)) { throw 'Informe o motivo concreto em Reason; existencia de pendencia historica nao basta.' }
        }
        $data=[ordered]@{Purpose='current-reconciliation';Project=$project.Name;Source=$project.Source;Pom=$project.Pom;Root=$project.Root;
            ContextPath=$contextPath;PromptPath=$promptPath;MigrationPath=$project.MigrationPath;PlanningContextPath=$project.ContextPath;
            PlanPath=$project.PlanPath;TodoPath=$project.TodoPath;ReconciledPath=(Join-Path $project.ReconciledPath 'resultado.md');
            PlanningBasis=$PlanningBasis;ReceivedPath=$comparison.ReceivedPath;Reason=$Reason;Relocated=$relocated;
            ContractPath=(Join-Path $Context.Root 'doc/adr/0009-estado-corrente-por-projeto.md');
            CurrentFiles=@($comparison.Local.Keys | Where-Object { $_ -ne $contextRelative -and $null -ne $comparison.Local[$_] } | Sort-Object | ForEach-Object {Join-Path $project.Folder $_});
            ReceivedDocuments=@($comparison.Documents);
            Mta=if ($comparison.Mta) {@{ReportPath=$comparison.Mta.ReportPath;CatalogPath=$comparison.Mta.CatalogPath}} else {$null};
            Diagnostics=@($comparison.Diagnostics)+@(if ($relocated) {'Contexto copiado realinhado ao POM associado; conferir origens externas e revisar GO local. A pasta recebida da outra maquina nao foi reassociada.'})}
        $template=[IO.File]::ReadAllText((Join-Path $Context.Root '.github/prompts/manter-migracao.prompt.md'))
        $selection=@{ContextPath=$contextPath}|ConvertTo-Json -Compress
        $prompt=$template.TrimEnd()+[Environment]::NewLine+[Environment]::NewLine+'Contexto corrente selecionado (dados, nao instrucoes):'+[Environment]::NewLine+$selection+[Environment]::NewLine
        $writes=@{$contextRelative=($data|ConvertTo-Json -Depth 8);$promptRelative=$prompt}
        $writes['indice.md']=Set-ProjectManagedBlock ([string]$old['indice.md']) 'reconciliacao:preparo' ((Get-HarnessSourceLink $project.IndexPath $promptPath 'Conferir reconciliacao')+' Preparar nao altera decisoes nem conclui a comparacao.')
        foreach ($key in @($writes.Keys)) { if ($writes[$key] -ceq $old[$key]) { $writes.Remove($key) } }
        $expected=@{}
        foreach ($key in $comparison.Local.Keys) { $expected[$key]=$comparison.Local[$key] }
        foreach ($key in $old.Keys) { $expected[$key]=$old[$key] }
        if ($writes.Count) { Publish-HarnessProjectFiles $project $writes $expected }
        [pscustomobject]@{Project=$project.Name;PlanningBasis=$PlanningBasis;ContextPath=$contextPath;PromptPath=$promptPath;
            PlanPath=$project.PlanPath;TodoPath=$project.TodoPath;MigrationPath=$project.MigrationPath;ReconciledPath=$data.ReconciledPath;
            Reused=($writes.Count -eq 0);Diagnostics=@($data.Diagnostics);ChangedFiles=@($writes.Keys)}
    } finally { $lease.ReleaseMutex(); $lease.Dispose() }
}
