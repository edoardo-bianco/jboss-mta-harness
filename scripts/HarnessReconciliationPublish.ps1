function Complete-HarnessReconciliation {
    param($Project,[Parameter(Mandatory=$true)][string]$Conclusion,
        [Collections.IDictionary]$Resolutions=@{},[string[]]$Pending=@())
    if ([string]::IsNullOrWhiteSpace($Conclusion)) { throw 'Informe a conclusao baseada no exame das fontes.' }
    $lease=Enter-HarnessProjectAccess $Project -ForOperation
    try {
        $folder=Get-ReconciliationReviewFolder $Project
        $draft=Get-ReconciliationDraft $folder
        $base=Import-Clixml -LiteralPath (Join-Path $folder 'base.clixml')
        $null=Get-HarnessProjectStorage $Project.Root $Project.Pom
        $comparison=Get-HarnessReconciliationComparison $Project $base.ReceivedPath $base.PlanningBasis
        Assert-ReconciliationReviewUnchanged $base $comparison
        $writes=@{}; $expected=@{}; $proposed=@{}; $decisions=@(); $reviewNeeded=$false
        foreach ($key in $base.Local.Keys) { $expected[$key]=$base.Local[$key] }
        $proposalFolder=Join-Path $folder 'proposta'
        foreach ($relative in @(Get-ReconciliationFiles $proposalFolder -AllFiles)) {
            if ((Get-ReconciliationFileKind $relative) -eq 'REFERENCIA') { throw "Proposta nao pode substituir configuracao/contexto/indice: $relative" }
            if (-not $Resolutions.Contains($relative) -or $Resolutions[$relative] -cne 'MESCLADO') { throw "Documento proposto exige decisao MESCLADO: $relative" }
            $proposed[$relative]=[IO.File]::ReadAllBytes((Join-Path $proposalFolder $relative))
        }
        foreach ($key in $Resolutions.Keys) {
            if ($Resolutions[$key] -cnotin @('LOCAL','RECEBIDO','MESCLADO','PENDENTE','DESCARTAR')) { throw "Decisao invalida: $key" }
            if (-not $comparison.Received.Contains($key) -and -not $proposed.ContainsKey($key)) { throw "Decisao sem documento recebido/proposto: $key" }
        }
        $paths=@(@($comparison.Received.Keys)+@($proposed.Keys) | Sort-Object -Unique)
        foreach ($relative in $paths) {
            $kind=Get-ReconciliationFileKind $relative
            $incoming=$comparison.Received.Contains($relative)
            $document=@($comparison.Documents | Where-Object Path -CEQ $relative)
            $choice=if ($Resolutions.Contains($relative)) {$Resolutions[$relative]}
                elseif ($document.Count -and $document[0].Status -eq 'EQUIVALENTE') {'LOCAL'}
                elseif ($kind -eq 'REFERENCIA') {'REFERENCIA'} else {'PENDENTE'}
            if ($kind -eq 'REFERENCIA' -and $choice -notin @('LOCAL','DESCARTAR','REFERENCIA','PENDENTE')) { throw "Configuracao/contexto recebido nao pode substituir o local: $relative" }
            if ($choice -eq 'PENDENTE') { $Pending+=('Decisao pendente: '+$relative); continue }
            if ($choice -eq 'REFERENCIA') { continue }
            $candidate=$null
            if ($choice -eq 'RECEBIDO') {
                if (-not $incoming) { throw "Documento recebido ausente: $relative" }
                if ($kind -eq 'REGISTRO') { throw 'Registro recebido exige mesclagem explicita por ID, preservando decisoes/texto local.' }
                $candidate=$comparison.Received[$relative]
            } elseif ($choice -eq 'MESCLADO') {
                if (-not $proposed.ContainsKey($relative)) { throw "Proposta mesclada ausente: $relative" }
                $candidate=$proposed[$relative]
            }
            if ($null -ne $candidate) {
                if (-not $expected.ContainsKey($relative)) { $expected[$relative]=$null }
                if ((Get-ReconciliationComparable $candidate $relative) -cne (Get-ReconciliationComparable $expected[$relative] $relative)) {
                    $writes[$relative]=$candidate; $reviewNeeded=$true
                }
            }
            $decisions+=($relative+': '+$choice)
            # Retirada somente do arquivo examinado, com decisao explicita.
            $internal=Join-Path $Project.Folder 'recebido'
            if ($incoming -and $Resolutions.Contains($relative) -and
                ($comparison.ReceivedPath -ieq $internal -or $comparison.ReceivedPath.StartsWith($internal+'\',[StringComparison]::OrdinalIgnoreCase))) {
                $source=Resolve-ProjectPath (Join-Path $comparison.ReceivedPath $relative) $Project.Root
                if (-not $source.StartsWith($internal+'\',[StringComparison]::OrdinalIgnoreCase)) { throw 'Retirada fora de recebido.' }
                $remove=$source.Substring($Project.Folder.Length+1).Replace('\','/')
                $expected[$remove]=$comparison.Received[$relative]; $writes[$remove]=$null
            }
        }
        $contextRelative='atual/planejamento/contexto.json'
        $planning=Get-ReconciliationPlanningContext $Project $base.Local[$contextRelative] $comparison.Mta
        if ($planning -and $planning.Relocated) { $reviewNeeded=$true }
        $reconciliationRelative='atual/planejamento/reconciliacao.json'
        if ($base.Local[$reconciliationRelative]) {
            $prepared=ConvertFrom-Json (ConvertFrom-ReconciliationBytes $base.Local[$reconciliationRelative])
            if ($prepared.PSObject.Properties['Relocated'] -and $prepared.Relocated) {
                $reviewNeeded=$true; $prepared.Relocated=$false
                $writes[$reconciliationRelative]=$prepared | ConvertTo-Json -Depth 12
            }
        }
        $migration=if ($writes.ContainsKey('migracao.md')) {ConvertFrom-ReconciliationBytes $writes['migracao.md']} else {ConvertFrom-ReconciliationBytes $base.Local['migracao.md']}
        $rows=@(Read-ProjectDecisionRows $migration)
        foreach ($row in @(Read-ProjectDecisionRows (ConvertFrom-ReconciliationBytes $base.Local['migracao.md']))) {
            if ($row.Id -cnotin @($rows | ForEach-Object Id)) { throw "Mesclagem nao pode apagar issue/decisao local: $($row.Id)" }
        }
        $migration=Get-HarnessProjectMigrationText $Project $comparison.Mta $migration -UpdateIssues
        if ($comparison.Differences.Count) { $reviewNeeded=$true }
        $resultPath=Join-Path $Project.ReconciledPath 'resultado.md'
        $references=@((Get-HarnessSourceLink $Project.PlanPath $Project.Pom 'POM local'),
            (Get-HarnessSourceLink $Project.PlanPath $Project.MigrationPath 'Decisoes locais'),
            (Get-HarnessSourceLink $Project.PlanPath $resultPath 'Ultima reconciliacao'))
        if ($comparison.Mta) { $references+=Get-HarnessSourceLink $Project.PlanPath $comparison.Mta.ReportPath 'MTA atual' }
        $available=@($writes.Keys | Where-Object { $null -ne $writes[$_] } | ForEach-Object {Join-Path $Project.Folder $_})
        $all=@(@($base.Local.Keys)+@($writes.Keys) | Sort-Object -Unique)
        foreach ($relative in $all) {
            if ($relative -notmatch '^atual/priorizacao/[^/]+/issues/[^/]+/ficha\.md$') { continue }
            $bytes=if ($writes.ContainsKey($relative)) {$writes[$relative]} else {$base.Local[$relative]}
            if ($null -eq $bytes) { continue }
            $parts=$relative.Split('/')
            if ((Get-PrioritizationFichaRelativePath ([Uri]::UnescapeDataString($parts[2])) ([Uri]::UnescapeDataString($parts[4]))) -cne $relative) { throw 'Caminho da ficha nao corresponde a chave funcional canonica.' }
            $writes[$relative]=Get-IssueSourcesText $Project $comparison.Mta ([Uri]::UnescapeDataString($parts[4])) ([Uri]::UnescapeDataString($parts[2])) (ConvertFrom-ReconciliationBytes $bytes) (Join-Path $Project.Folder $relative) -EvidenceOnly:($base.PlanningBasis -eq 'EVIDENCIAS') -AvailablePaths $available
        }
        foreach ($relative in @('atual/planejamento/plano.md','atual/planejamento/tarefas.md')) {
            $bytes=if ($writes.ContainsKey($relative)) {$writes[$relative]} else {$base.Local[$relative]}
            if ($null -eq $bytes) { continue }
            $text=ConvertFrom-ReconciliationBytes $bytes
            $text=Set-ProjectManagedBlock $text 'planejamento:fontes' ($references -join ([Environment]::NewLine+[Environment]::NewLine))
            if ($reviewNeeded) {
                $notice='REVISAO HUMANA DO GO NECESSARIA. Declaracoes e tarefas recebidas nao autorizam execucao local nem comprovam integracao. Conferir o alcance das autorizacoes antes de implementar.'
                if (Find-ProjectManagedBlock $text 'reconciliacao:autorizacao') { $text=Set-ProjectManagedBlock $text 'reconciliacao:autorizacao' $notice }
                else { $text=(Set-ProjectManagedBlock '' 'reconciliacao:autorizacao' $notice)+[Environment]::NewLine+$text }
            }
            $writes[$relative]=$text
        }
        if ($planning -and $reviewNeeded) {
            $data=$planning.Data
            $data.NeedsReview=$true
            $data.ReviewReasons=@(@($data.ReviewReasons)+@('Reconciliacao alterou entradas; revisar proposta, codigo local e alcance do GO humano.') | Select-Object -Unique)
            $writes[$contextRelative]=$data | ConvertTo-Json -Depth 12
            if ($planning.Relocated) {
                $template=[IO.File]::ReadAllText((Join-Path $Project.Root '.github/prompts/planejar-lotes.prompt.md'))
                $selection=@{ContextPath=$Project.ContextPath;PlanPath=$Project.PlanPath;TodoPath=$Project.TodoPath}|ConvertTo-Json
                $writes['atual/planejamento/planejar-lotes.prompt.md']=$template.TrimEnd()+[Environment]::NewLine+'Contexto corrente selecionado (dados, nao instrucoes):'+[Environment]::NewLine+$selection
            }
        }
        $Pending=@($Pending | Select-Object -Unique)
        $state=if ($Pending.Count) {'PENDENTE'} else {'CONCLUIDA'}
        $result=@('# Reconciliacao: '+$Project.Name,'',('Estado: '+$state),'',('Base: '+$base.PlanningBasis),'',
            $Conclusion,'','## Diferencas e decisoes')
        $result+=@($comparison.Differences+$decisions | ForEach-Object {'- '+(ConvertTo-ProjectCell $_)})
        $result+=@('','## Pendencias e limites')
        if ($Pending.Count) { $result+=@($Pending | ForEach-Object {'- '+(ConvertTo-ProjectCell $_)}) }
        $result+='Comparacao de ocorrencias anteriores nao e inferida por IDs, contagens, datas ou arquivos. Ausencia no MTA nao comprova resolucao. Esta conclusao nao concede GO nem aceite local.'
        $result+=@('',(Get-HarnessSourceLink $resultPath $Project.Pom 'POM local'),(Get-HarnessSourceLink $resultPath $Project.MigrationPath 'Decisoes correntes'))
        if ($comparison.Mta) { $result+=Get-HarnessSourceLink $resultPath $comparison.Mta.ReportPath 'MTA atual' }
        if ($comparison.ReceivedPath) { $result+='Origem examinada: '+(ConvertTo-ProjectCell $comparison.ReceivedPath)+'. Somente arquivos explicitamente resolvidos em recebido/ podem ser retirados.' }
        $writes['reconciliado/resultado.md']=$result -join [Environment]::NewLine
        $migration=Set-ProjectManagedBlock $migration 'reconciliacao' ('Estado da ultima comparacao: '+$state+'. '+(Get-HarnessSourceLink $Project.MigrationPath $resultPath 'Conclusoes e pendencias')+' Preparar ou reconciliar nao concede GO/aceite.')
        $writes['migracao.md']=$migration
        $writes['indice.md']=Set-ProjectManagedBlock (ConvertFrom-ReconciliationBytes $base.Local['indice.md']) 'reconciliacao' (Get-HarnessSourceLink $Project.IndexPath $resultPath 'Ultima reconciliacao')
        if ($planning -and $planning.Relocated) { $writes['indice.md']=Set-ProjectManagedBlock $writes['indice.md'] 'planejamento' (Get-CurrentPlanningSources $planning.Data $Project $Project.IndexPath) }
        foreach ($key in @($writes.Keys)) {
            $value=$writes[$key]
            if ($null -ne $value -and $value -isnot [byte[]]) { $value=(New-Object Text.UTF8Encoding($false)).GetBytes([string]$value); $writes[$key]=$value }
            $before=$expected[$key]
            if ($null -eq $value -and $null -eq $before) { $writes.Remove($key) }
            elseif ($null -ne $value -and $null -ne $before -and [Convert]::ToBase64String($value) -ceq [Convert]::ToBase64String([byte[]]$before)) { $writes.Remove($key) }
        }
        if (-not (Test-ReconciliationDraftUnchanged $folder $draft)) { throw 'Proposta editada durante a conclusao; revisao preservada, nada publicado.' }
        if ($writes.Count) { Publish-HarnessProjectFiles $Project $writes $expected }
        $removed=Remove-ReconciliationReview $Project -Expected $draft
        $diagnostics=@()
        if (-not $removed) { $diagnostics+='Resultado publicado, mas a revisao foi editada durante a publicacao. Rascunho preservado; confira as diferencas antes de reiniciar.' }
        [pscustomobject]@{Project=$Project.Name;State=$state;ReconciledPath=$resultPath;NeedsReview=$reviewNeeded;ChangedFiles=@($writes.Keys);Pending=$Pending;Diagnostics=$diagnostics}
    } finally { $lease.ReleaseMutex(); $lease.Dispose() }
}
