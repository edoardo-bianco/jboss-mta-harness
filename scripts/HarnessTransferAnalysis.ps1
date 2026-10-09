function Add-TransferAnalysis {
    param($Manifest,$Context,[string]$ContextPath)
    $Manifest.Kind='ANALISE'; $Manifest.Stage='PRIORIZACAO_CONCLUIDA'
    $history=@(Read-PrioritizationHistory $Context.Root)
    $matches=@($history | Where-Object { (Resolve-HarnessPath $_.ContextPath $Context.Root) -ieq $ContextPath })
    if ($matches.Count -ne 1) { throw 'Priorizacao ausente/ambigua no historico.' }
    $cursor=$matches[0]; $seen=@{}
    while ($cursor) {
        if ($seen.ContainsKey($cursor.RequestId)) { throw 'Ciclo no historico de priorizacao.' }; $seen[$cursor.RequestId]=$true
        if ($cursor.SchemaVersion -ne 4) { throw 'Pacote de analise exige sequencia v4; recrie a base para compartilhar os novos dossies.' }
        $result=Read-PrioritizationResult $cursor
        foreach ($project in $cursor.Projects) {
            Add-TransferProject $Manifest $Context $project.Source
            if (-not $project.Mta) { throw 'Projeto da analise sem diagnostico completo. Restrinja o escopo antes de exportar.' }
            $run=Get-HarnessRegisteredMtaRun (Read-HarnessMigrationInput $Context.Root (@($Context.Projects | Where-Object { $_.path.Replace('\','/') -ieq $project.Source.Replace('\','/') })[0])) $Context.Root
            if ($run.RunId -cne $project.Mta.RunId -or $run.Run -ine $project.Mta.Run) { throw 'Registro mudou de origem apos a priorizacao. Recrie o contexto antes de compartilhar.' }
            foreach ($name in @('Manifest','Result','Findings','Dependencies')) {
                if ((Get-FileHash -LiteralPath $project.Mta.Evidence.$name).Hash -cne $project.Mta.EvidenceHashes.$name) { throw 'Diagnostico alterado desde a priorizacao.' }
            }
            if ((Get-FileHash -LiteralPath $project.Mta.CatalogPath).Hash -cne $project.Mta.CatalogSha256) { throw 'Catalogo alterado desde a priorizacao.' }
            if (-not @($Manifest.MtaRuns | Where-Object OriginPath -IEQ $run.Run).Count) {
                $Manifest.MtaRuns += [pscustomobject]@{OriginPath=$run.Run;RunId=$run.RunId;Directories=@('input','rules','output');Source=$project.Source}
                foreach ($file in @('manifest.json','result.json')) { $null=Add-TransferFile $Manifest (Join-Path $run.Run $file) 'MTA' }
                foreach ($dir in @('input','rules','output')) {
                    $base=Join-Path $run.Run $dir; Assert-TransferRegularPath $base
                    # Enumerar por nivel: nunca atravessar junction antes de a recusar.
                    $pending=New-Object 'Collections.Generic.Stack[string]'; $pending.Push($base)
                    while ($pending.Count) {
                        foreach ($entry in Get-ChildItem -LiteralPath $pending.Pop() -Force) {
                            Assert-TransferRegularPath $entry.FullName
                            if ($entry.PSIsContainer) { $pending.Push($entry.FullName) }
                            else { $null=Add-TransferFile $Manifest $entry.FullName 'MTA' }
                        }
                    }
                }
            }
            if ($project.Mta.PSObject.Properties['IncidentEvidence']) {
                foreach ($file in $project.Mta.IncidentEvidence.Files) { $null=Add-TransferFile $Manifest $file.Path 'INCIDENT' }
            }
        }
        $entry=Add-TransferFile $Manifest $cursor.ContextPath 'CONTEXT'
        if (-not $Manifest.ContextEntry) { $Manifest.ContextEntry=$entry }
        $Manifest.Receipts += [pscustomobject]@{Entry=$entry;RequestId=$cursor.RequestId}
        $null=Add-TransferFile $Manifest $cursor.RankingPath 'RANKING'
        $null=Add-TransferFile $Manifest $cursor.PromptPath 'PROMPT'
        foreach ($issue in $result.AnalyzedIssues) {
            $ficha=@($cursor.FichaPaths | Where-Object { $_.Source -ieq $issue.Source -and $_.Id -ceq $issue.Id })[0]
            $null=Add-TransferFile $Manifest $ficha.Path 'FICHA'
        }
        if ($cursor.Mode -ne 'Continue') { break }
        $cursor=Get-PrioritizationParent $cursor $history
    }
    $null=Add-TransferFile $Manifest (Join-Path $Context.Root '.harness/projetos/indice-projetos.md') 'INDEX'
    foreach ($origin in $Manifest.Projects) {
        $project=@($Context.Projects | Where-Object { $_.path.Replace('\','/') -ieq $origin.Source.Replace('\','/') })[0]
        $register=Read-HarnessMigrationInput $Context.Root $project
        # Recolher somente referencias explicitamente fornecidas, inclusive de candidatas nao escolhidas.
        $rows=@($register.Rows | ForEach-Object { [pscustomobject]@{Id=$_.Id;Decision='ANALISAR AGORA';Observation=$_.Observation} })
        $references=@(Get-HarnessPlanningEvidenceInputs $Context.Root ([pscustomobject]@{Rows=$rows;MigrationPath=$register.MigrationPath}) $register.EvidenceIndexPath)
        foreach ($reference in $references) {
            if ($reference.Status -ne 'DISPONIVEL') { $Manifest.Missing += $reference.Reference; continue }
            if ($reference.Relation -eq 'Indice de evidencias') { $null=Add-TransferFile $Manifest $reference.Path 'INPUT_INDEX'; continue }
            $entry=Add-TransferFile $Manifest $reference.Path 'ANNEX'
            $origin.EvidenceEntries += [pscustomobject]@{Entry=$entry;Reference=$reference.Reference;Relation=$reference.Relation}
        }
    }
}
function New-TransferAnalysisMapping {
    param($Context,$Record,$Reference,$Projects,$Paths)
    if ($Record.Purpose -ne 'issue-prioritization' -or $Record.SchemaVersion -ne 4 -or $Record.RequestId -cnotmatch '^[a-f0-9]{32}$' -or $Record.RequestId -cne $Reference.RequestId) { throw 'Identidade/versao da analise recebida invalida.' }
    $folder=Join-Path $Context.Root ('.harness/priorizacao/'+$Record.RequestId)
    $Paths[(Split-Path $Record.ContextPath -Parent)]=$folder
    $Paths[$Record.ProjectIndexPath]=Join-Path $Context.Root '.harness/projetos/indice-projetos.md'
    # O indice agregado pertence ao receptor, nao e um artefato a importar da origem.
    $originPrioritization=Split-Path (Split-Path $Record.ContextPath -Parent) -Parent
    if ($Record.PSObject.Properties['PrioritizationIndexPath']) {
        if ($Record.PrioritizationIndexPath -ine (Join-Path $originPrioritization 'indice-priorizacao.md')) { throw 'Destino do indice recebido diverge da raiz da priorizacao.' }
        $Paths[$Record.PrioritizationIndexPath]=Join-Path $Context.Root '.harness/priorizacao/indice-priorizacao.md'
    }
    if ($Record.PSObject.Properties['PrioritizationIndexTemplatePath']) {
        $originRoot=Split-Path (Split-Path $originPrioritization -Parent) -Parent
        if ($Record.PrioritizationIndexTemplatePath -ine (Join-Path $originRoot 'doc/modelos/indice-priorizacao.template.md')) { throw 'Template do indice recebido fora da raiz do harness.' }
        $Paths[$Record.PrioritizationIndexTemplatePath]=Join-Path $Context.Root 'doc/modelos/indice-priorizacao.template.md'
    }
    foreach ($ficha in $Record.FichaPaths) {
        if (-not $Projects.ContainsKey($ficha.Source)) { throw 'Source da ficha ausente do mapeamento.' }
        $issue=Get-HarnessIssuePaths $Context.Root $Projects[$ficha.Source] $ficha.Id
        $Paths[$ficha.Path]=Join-Path $issue.Folder ('fichas/p_'+$Record.RequestId.Substring(0,12)+'/ficha-'+$issue.Stem+'.md')
    }
    [pscustomobject]@{Record=$Record;Entry=$Reference.Entry;Folder=$folder}
}
function New-TransferAnalysisWrites {
    param($Context,$Manifest,$Archive,[string]$Base,$Records,$Mapping,$Writes,$Projects)
    foreach ($file in $Manifest.Files) {
        if ($file.Role -in @('CONTEXT','INDEX','INPUT_INDEX')) { continue }
        $dest=Convert-TransferText $file.OriginPath $Mapping
        if ($file.Role -in @('MTA','ANNEX')) { Add-TransferWrite $Writes $dest $null $file.Entry; continue }
        $text=Read-TransferText $Archive $file.Entry
        $text=Convert-TransferDocument $text $file.OriginPath $Mapping -Register:($file.Role -eq 'REGISTER')
        if ($file.Role -eq 'REGISTER') {
            $origin=@($Manifest.Projects | Where-Object RegisterEntry -CEQ $file.Entry)[0]
            $project=$Projects[$origin.Source]
            $text=[regex]::Replace($text,'(?m)^Project:[^\r\n]*',('Project: '+$project.name))
            $text += "`nRegistro recebido; conferir escolhas, escopo e codigo local. Execucao/aceite na origem nao comprovam integracao local.`n"
        }
        Add-TransferWrite $Writes $dest (Get-TransferBytes $text) $null
    }
    foreach ($origin in $Manifest.Projects) {
        $project=$Projects[$origin.Source]
        $paths=Get-HarnessIssuePaths $Context.Root $project 'DEV-TRANSFER'
        if (-not (Test-Path -LiteralPath $paths.ProjectIdentityPath)) {
            Add-TransferWrite $Writes $paths.ProjectIdentityPath (Get-TransferBytes (@{Project=$project.name;Source=$project.path;ArtifactId=$paths.ArtifactId} | ConvertTo-Json)) $null
        }
        $general=Get-HarnessMigrationPaths $Context.Root $project
        $lines=@('# Evidencias recebidas do projeto','','| Arquivo relativo | Relacao com a correcao |','| --- | --- |')
        foreach ($evidence in $origin.EvidenceEntries) {
            $file=@($Manifest.Files | Where-Object Entry -CEQ $evidence.Entry)[0]
            $path=Convert-TransferText $file.OriginPath $Mapping
            $anchor=if ($evidence.Reference.Contains('#')) { '#'+($evidence.Reference -split '#',2)[1] } else { '' }
            $lines += '| [Abrir](<'+$path+$anchor+'>) | '+$evidence.Relation.Replace('|','&#124;')+' |'
        }
        Add-TransferWrite $Writes $general.EvidenceIndexPath (Get-TransferBytes ($lines -join "`n")) $null
    }
    foreach ($item in $Records) {
        $old=$item.Record; $local=Convert-TransferValue $old $Mapping
        $local | Add-Member NoteProperty ImportedFrom ([pscustomobject]@{PackageId=$Manifest.PackageId;OriginalContextPath=(Join-Path $Base ('original/'+$item.Entry));OriginalContextSha256=(@($Manifest.Files | Where-Object Entry -CEQ $item.Entry)[0]).Sha256;Previous=$old.Previous}) -Force
        foreach ($project in $local.Projects) {
            $origin=@($old.Projects | Where-Object { (Convert-TransferText $_.Source $Mapping) -ieq $project.Source })[0]
            $project.Project=$Projects[$origin.Source].name; $project.Label=$Projects[$origin.Source].label
            $project.MigrationSnapshot=Convert-TransferRegisterText $origin.MigrationSnapshot $Mapping
            $project.MigrationSha256=Get-TransferBytesHash (Get-TransferBytes $project.MigrationSnapshot)
            if ($project.Mta.PSObject.Properties['IncidentEvidence']) {
                foreach ($file in $project.Mta.IncidentEvidence.Files) { $file.Sha256=Get-TransferWriteHash $Writes $file.Path $Manifest }
            }
        }
        if ($local.Mode -eq 'Continue') {
            $parent=@($Records | Where-Object { $_.Record.RequestId -ceq $local.Previous.RequestId })
            if ($parent.Count -ne 1) { throw 'Cadeia Continue incompleta no pacote.' }
            $parentRecord=Convert-TransferValue $parent[0].Record $Mapping
            $local.Previous.RankingSha256=Get-TransferWriteHash $Writes $parentRecord.RankingPath $Manifest
            $ranking=[Text.Encoding]::UTF8.GetString($Writes[$parentRecord.RankingPath].Bytes)
            $match=[regex]::Match($ranking,'(?s)<!-- priorizacao:resultado -->\s*```json\s*(.*?)\s*```\s*<!-- /priorizacao:resultado -->')
            $result=$match.Groups[1].Value | ConvertFrom-Json
            $local.Previous.FichaHashes=@(foreach ($issue in $result.AnalyzedIssues) {
                $ficha=@($parentRecord.FichaPaths | Where-Object { $_.Source -ieq $issue.Source -and $_.Id -ceq $issue.Id })[0]
                [pscustomobject]@{Source=$issue.Source;Id=$issue.Id;Path=$ficha.Path;Sha256=(Get-TransferWriteHash $Writes $ficha.Path $Manifest)}
            })
        }
        Add-TransferWrite $Writes $local.ContextPath (Get-TransferBytes ($local | ConvertTo-Json -Depth 60)) $null
    }
    $index=Join-Path $Context.Root '.harness/projetos/indice-projetos.md'
    if (-not (Test-Path -LiteralPath $index)) {
        $lines=@('# Indice local dos projetos recebidos','','Atualize pela tarefa Workspace: atualizar indice dos projetos para reunir outras frentes.','')
        foreach ($project in $Projects.Values) {
            $paths=Get-HarnessMigrationPaths $Context.Root $project
            $lines += '- ['+$project.label+'](<'+$paths.MigrationPath+'>)'
        }
        Add-TransferWrite $Writes $index (Get-TransferBytes ($lines -join "`n")) $null
    }
}
