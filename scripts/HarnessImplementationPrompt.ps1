# Preparo corrente: documentos vivos e autorizacao humana, sem copiar o plano.
function New-HarnessImplementationPrompt {
    param($Context,[string]$Target,[switch]$Interactive)
    $project=Select-CurrentPlanningProject $Context -Target $Target -Interactive:$Interactive -ForOpen
    $lease=Enter-HarnessProjectAccess $project -ForOperation
    try {
        $prefix='atual/planejamento/'
        $old=Read-HarnessProjectFiles $project @(($prefix+'contexto.json'),($prefix+'plano.md'),($prefix+'tarefas.md'),
            ($prefix+'implementar-lote.prompt.md'),($prefix+'revisar-resultado.prompt.md'),'migracao.md','indice.md')
        foreach ($name in @('contexto.json','plano.md','tarefas.md')) {
            if ([string]::IsNullOrWhiteSpace($old[$prefix+$name])) { throw "Documento corrente ausente ou vazio: $name. Prepare/conclua a proposta antes da implementacao." }
        }
        $data=ConvertFrom-Json $old[$prefix+'contexto.json']
        Assert-CurrentPlanningContext $data $project
        if ($data.Source -ine $project.Source -or $data.Pom -ine $project.Pom) { throw 'Projeto reassociado: prepare o planejamento ou reconcilie as fontes locais antes da implementacao.' }
        $rows=@(Read-ProjectDecisionRows $old['migracao.md'] | Where-Object Decision -EQ 'ANALISAR AGORA' | Sort-Object Id)
        $selected=@($rows | ForEach-Object {[pscustomobject][ordered]@{Id=$_.Id;Category=$_.Category;Scope=$_.Note}})
        $reasons=@($data.ReviewReasons)
        if ((ConvertTo-Json -InputObject $selected -Depth 6 -Compress) -cne (ConvertTo-Json -InputObject $data.SelectedIssues -Depth 6 -Compress)) {
            $reasons+='Escolhas do registro mudaram: reavaliar escopo da proposta e alcance do GO humano.'
        }
        $paths=@{}
        $writes=@{}
        foreach ($operation in @('implementar-lote','revisar-resultado')) {
            $relative=$prefix+$operation+'.prompt.md'
            $path=Join-Path $project.Folder $relative
            $paths[$operation]=$path
            $template=[IO.File]::ReadAllText((Join-Path $Context.Root ('.github/prompts/'+$operation+'.prompt.md')))
            $body=@('','## Projeto e documentos correntes','',('Projeto: '+(ConvertTo-ProjectCell $project.Name)),
                ('ContextPath (dado tecnico): `'+$project.ContextPath+'`'),'',
                (Get-CurrentPlanningSources $data $project $path),
                (Get-HarnessSourceLink $path $project.Source 'Codigo local'),
                (Get-HarnessSourceLink $path (Join-Path $Context.Root 'doc/guias/tools/planejamento-migracao.md') 'Guia de planejamento e verificacoes'),
                'Preparar ou abrir nao concede GO/aceite. Antes de editar, conferir a autorizacao humana contra o conteudo e escopo atuais; caminhos iguais nao atestam equivalencia.')
            foreach ($reason in $reasons) { $body+=('REVISAO NECESSARIA: '+(ConvertTo-ProjectCell $reason)) }
            $header=[regex]::Match($template,'(?s)\A---\r?\n.*?\r?\n---')
            if (-not $header.Success) { throw "Template sem cabecalho: $operation" }
            $text=if ($old[$relative]) { $old[$relative] } else { $header.Value+"`n`n## Observacoes do desenvolvedor`n`nRegistre observacoes aqui, fora dos blocos gerenciados. Decisoes de escopo/GO pertencem ao plano corrente.`n" }
            $text=Set-ProjectManagedBlock $text 'implementacao:orientacao' $template.Substring($header.Length).Trim()
            $writes[$relative]=Set-ProjectManagedBlock $text 'implementacao:fontes' ($body -join ([Environment]::NewLine+[Environment]::NewLine))
        }
        $indexLinks=@()
        foreach ($operation in @('implementar-lote','revisar-resultado')) { $indexLinks+=Get-HarnessSourceLink $project.IndexPath $paths[$operation] $operation }
        $writes['indice.md']=Set-ProjectManagedBlock ([string]$old['indice.md']) 'implementacao' ($indexLinks -join ([Environment]::NewLine+[Environment]::NewLine))
        foreach ($key in @($writes.Keys)) { if ($writes[$key] -ceq $old[$key]) { $writes.Remove($key) } }
        if ($writes.Count) { Publish-HarnessProjectFiles $project $writes $old }
        # Somente memoria do dialogo Git: nao persistir copias ou selos de autorizacao.
        $documents=@{Context=$old[$prefix+'contexto.json'];Plan=$old[$prefix+'plano.md'];Todo=$old[$prefix+'tarefas.md']}
        [pscustomobject]@{Project=$project.Name;Source=$project.Source;ContextPath=$project.ContextPath;PlanPath=$project.PlanPath;TodoPath=$project.TodoPath;
            PromptPath=$paths['implementar-lote'];ResultReviewPromptPath=$paths['revisar-resultado'];DocumentContents=$documents;
            NeedsReview=($data.NeedsReview -or $reasons.Count -gt 0);ReviewReasons=$reasons;Reused=($writes.Count -eq 0)}
    } finally { $lease.ReleaseMutex(); $lease.Dispose() }
}
