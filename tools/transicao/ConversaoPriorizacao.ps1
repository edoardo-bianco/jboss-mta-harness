function Convert-ConversionIssues($State,$Issues) {
    $seen=New-Object 'Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
    foreach ($issue in @($Issues)) {
        if ((Resolve-ProjectPath $issue.Source $State.Project.Root) -ine $State.Inputs.Preview.LegacySource -or -not $issue.Id -or -not $seen.Add($issue.Id)) { throw 'Issue de outro Source ou duplicada na cobertura legada.' }
        [pscustomobject]@{Project=$State.Project.Name;Id=[string]$issue.Id}
    }
}

function Read-ConversionRanking($State,$Record) {
    $path=Resolve-ProjectPath $Record.Data.RankingPath $State.Project.Root
    if ((Split-Path $path -Parent) -ine (Split-Path $Record.Path -Parent)) { throw 'Ranking fora da solicitacao selecionada.' }
    $text=Read-ConversionText $State.Inputs.Session $path
    $blocks=[regex]::Matches($text,'(?s)<!-- priorizacao:resultado -->\s*```json\s*(.*?)\s*```\s*<!-- /priorizacao:resultado -->')
    if ($blocks.Count -ne 1) { throw ('Resultado de priorizacao ausente/ambiguo: '+$path) }
    $result=ConvertFrom-Json $blocks[0].Groups[1].Value
    if ($result.RequestId -cne $Record.Data.RequestId -or $result.Status -notin @('COMPLETED','IN_PROGRESS') -or $result.AnalyzedIssues -isnot [Array] -or $result.ProposedIssues -isnot [Array]) { throw 'Resultado divergente da priorizacao selecionada.' }
    $examined=@(Convert-ConversionIssues $State $result.AnalyzedIssues)
    $proposed=@(Convert-ConversionIssues $State $result.ProposedIssues)
    $available=@(Convert-ConversionIssues $State $Record.Data.AvailableIssues)
    $baseline=@(Convert-ConversionIssues $State $Record.Data.BaselineIssues)
    $excluded=@(Convert-ConversionIssues $State $Record.Data.ExcludedIssues)
    $percent=ConvertTo-PrioritizationPercentage ([string]$Record.Data.Percentage)
    if ($baseline.Count -ne $Record.Data.InitialTotal -or $Record.Data.SliceSize -ne [Math]::Min($available.Count,[Math]::Ceiling($baseline.Count*$percent/100)) -or
        @($available+$excluded | Where-Object Id -CNotIn @($baseline | ForEach-Object Id)).Count -or @($available | Where-Object Id -CIn @($excluded | ForEach-Object Id)).Count) { throw 'Quota, disponibilidade ou exclusoes inconsistentes na cadeia legada.' }
    if (@($examined | Where-Object Id -CNotIn @($available | ForEach-Object Id)).Count -or @($proposed | Where-Object Id -CNotIn @($examined | ForEach-Object Id)).Count -or
        $examined.Count -gt $Record.Data.SliceSize -or ($result.Status -eq 'COMPLETED' -and $Record.Data.SchemaVersion -ge 3 -and $examined.Count -ne $Record.Data.SliceSize)) { throw 'Exame/proposta fora da fatia ou quota inconsistente.' }
    [pscustomobject]@{Path=$path;Text=($text.Remove($blocks[0].Index,$blocks[0].Length));Result=$result;Examined=$examined;Proposed=$proposed;Excluded=$excluded;Available=$available;Version=$Record.Data.SchemaVersion}
}

function Get-ConversionRankingAssessment($State,$Ranking,$Issue,[string]$Ficha) {
    $rows=@()
    $recommended=$Issue.Id -cin @($Ranking.Proposed | ForEach-Object Id)
    foreach ($line in $Ranking.Text -split '\r?\n') {
        if ($line -notmatch '^\s*\|') { continue }
        $cells=@($line.Trim().Trim('|').Split('|') | ForEach-Object { $_.Trim() })
        if ($cells.Count -lt 5 -or $cells[0] -match '^:?-+:?$') { continue }
        $links=@(Get-ConversionLinks $cells[2] $Ranking.Path $State.Inputs.Session)
        if (($Ficha -and $Ficha -iin $links) -or $cells[2] -ceq $Issue.Id) { $rows+=,@($cells) }
    }
    if (-not $rows.Count -and $Ranking.Version -lt 4) {
        return $(if ($recommended) {'Exame e recomendacao declarados no resultado legado; posicao e motivo nao estruturados. Conferir texto humano preservado e codigo antes de escolher.'} else {'Exame declarado no resultado legado, sem proposta. Motivo nao estruturado; conferir texto humano preservado e codigo antes de escolher.'})
    }
    if ($rows.Count -ne 1 -or -not $rows[0][4]) { throw ('Falta linha unica com motivo humano para '+$Issue.Id+' em '+$Ranking.Path) }
    $row=$rows[0]; $position=0
    if ($recommended -and (-not [int]::TryParse($row[0],[ref]$position) -or $position -lt 1)) { throw 'Recomendacao legada sem posicao numerica correspondente.' }
    if (-not $recommended -and [int]::TryParse($row[0],[ref]$position)) { throw 'Posicao legada sem proposta correspondente no resultado.' }
    $prefix=if ($recommended) {'Recomendacao preservada (prioridade '+$position+' na fatia original); comparacao acumulada exige revisao humana. '} else {'Sem recomendacao na fatia original. '}
    $prefix+$row[3]+'. '+$row[4]
}

function Read-ConversionPrioritization($State,[string[]]$SelectedContexts=@()) {
    $records=@($State.Inputs.Records | Where-Object Kind -EQ 'PRIORIZACAO'); $groups=@{}
    $SelectedContexts=@($SelectedContexts | ForEach-Object { Resolve-ProjectPath $_ $State.Project.Root })
    foreach ($path in $SelectedContexts) { if (@($records | Where-Object Path -IEQ $path).Count -ne 1) { throw 'PrioritizacaoContexto nao pertence ao Source selecionado.' } }
    foreach ($record in $records) {
        if ($record.Sources.Count -ne 1) { throw 'Priorizacao multiprojeto exige associacao explicita dos participantes antes da consolidacao.' }
        if ($record.Data.SchemaVersion -notin @(2,3,4)) { throw 'Versao de priorizacao desconhecida.' }
        if ($record.Data.Mode -notin @('Start','Recreate','Continue') -or $record.Data.SequenceId -cnotmatch '^[a-f0-9]{32}$') { throw 'Modo/sequencia de priorizacao desconhecidos.' }
        $category=if ($record.Data.SchemaVersion -ge 4) { [string](Get-LegacyValue $record.Data 'Category') } else {'mandatory'}
        if (-not $category) { throw 'Categoria da priorizacao ausente.' }
        if (@($groups.Keys | Where-Object { $_ -ieq $category -and $_ -cne $category }).Count) { throw 'Categorias diferentes colidem no Windows; nao mesclar silenciosamente.' }
        if (-not $groups.ContainsKey($category)) { $groups[$category]=@() }; $groups[$category]+=$record
    }
    foreach ($category in @($groups.Keys | Sort-Object)) {
        $history=$groups[$category]; $byId=@{}
        foreach ($record in $history) {
            $id=Get-LegacyValue $record.Data 'RequestId'
            if ($id -cnotmatch '^[a-f0-9]{32}$' -or $byId.ContainsKey($id)) { throw 'Identidade de priorizacao ausente/duplicada.' }; $byId[$id]=$record
            if ((Resolve-ProjectPath $record.Data.ContextPath $State.Project.Root) -ine $record.Path) { throw 'ContextPath diverge do registro de priorizacao.' }
        }
        $parents=@(foreach ($record in $history) { $previous=Get-LegacyValue $record.Data 'Previous'; if ($previous) { $previous.RequestId } })
        $tips=@($history | Where-Object { $_.Data.RequestId -cnotin $parents })
        $chosen=@($history | Where-Object Path -IIn $SelectedContexts)
        if (-not $chosen.Count) { $chosen=$tips }
        if ($chosen.Count -ne 1) { throw ('Priorizacao ambigua da categoria '+$category+'; escolha PrioritizacaoContexto explicitamente.') }
        $current=$chosen[0]; $forward=@{}
        while ($true) {
            if ($forward.ContainsKey($current.Data.RequestId)) { throw 'Ciclo na priorizacao legada.' }; $forward[$current.Data.RequestId]=$true
            $children=@($history | Where-Object { $parent=Get-LegacyValue $_.Data 'Previous'; $parent -and $parent.RequestId -ceq $current.Data.RequestId })
            if (-not $children.Count) { break }
            if ($children.Count -ne 1) { throw 'Priorizacao com varios sucessores; escolha a frente explicitamente.' }
            $current=$children[0]
        }
        $cursor=$current; $chain=@(); $visited=@{}
        while ($cursor) {
            $id=$cursor.Data.RequestId
            if ($visited.ContainsKey($id)) { throw 'Ciclo na priorizacao legada.' }; $visited[$id]=$true
            if ($cursor.Data.SequenceId -cne $current.Data.SequenceId) { throw 'Cadeia cruza sequencias de priorizacao.' }
            $chain=@($cursor)+$chain; $previous=Get-LegacyValue $cursor.Data 'Previous'
            if ($cursor.Data.Mode -ne 'Continue') { break }
            if (-not $previous -or -not $byId.ContainsKey($previous.RequestId)) { throw 'Anterior da priorizacao ausente ou de outra categoria.' }
            $cursor=$byId[$previous.RequestId]
        }
        $scope=$State.Project.Name; $paths=Get-PrioritizationPaths $State.Project $category $scope
        $baseline=@(Convert-ConversionIssues $State $current.Data.BaselineIssues)
        if ($baseline.Count -ne $current.Data.InitialTotal) { throw 'Denominador diverge da base inicial.' }
        $baselineIds=@($baseline | ForEach-Object Id | Sort-Object -CaseSensitive)
        $rankings=@(); $examined=[Collections.Specialized.OrderedDictionary]::new([StringComparer]::Ordinal)
        $beforeLast=@()
        $fichas=New-Object 'Collections.Generic.Dictionary[string,object]' ([StringComparer]::Ordinal)
        $assessments=New-Object 'Collections.Generic.Dictionary[string,object]' ([StringComparer]::Ordinal)
        foreach ($record in $chain) {
            $other=@(Convert-ConversionIssues $State $record.Data.BaselineIssues | ForEach-Object Id | Sort-Object -CaseSensitive)
            if (($other -join "`n") -cne ($baselineIds -join "`n") -or $record.Data.InitialTotal -ne $current.Data.InitialTotal) { throw 'Base inicial mudou dentro da sequencia.' }
            $ranking=Read-ConversionRanking $State $record
            if ($record.Path -ine $current.Path -and $ranking.Result.Status -ne 'COMPLETED') { throw 'Fatia anterior incompleta nao comprova cobertura excluida.' }
            $earlier=@($examined.Values | ForEach-Object Id | Sort-Object -CaseSensitive)
            $declared=@($ranking.Excluded | ForEach-Object Id | Sort-Object -CaseSensitive)
            if (($record.Data.SchemaVersion -ge 3 -and ($earlier -join "`n") -cne ($declared -join "`n")) -or @($declared | Where-Object { $_ -cnotin $earlier }).Count) { throw 'Exclusoes legadas nao correspondem as examinadas anteriores.' }
            if ($record.Path -ieq $current.Path) { $beforeLast=@($examined.Values | Select-Object Project,Id) }
            $rankings+=$ranking; $State.Map[$record.Path]=$paths.ContextPath; $State.Map[$ranking.Path]=$paths.RankingPath
            foreach ($issue in $ranking.Examined) {
                if ($issue.Id -cnotin $baselineIds) { throw 'Examinada fora da base inicial.' }
                $entries=@(Get-LegacyValue $record.Data 'FichaPaths' @() | Where-Object { $_.Id -ceq $issue.Id -and (Resolve-ProjectPath $_.Source $State.Project.Root) -ieq $State.Inputs.Preview.LegacySource })
                if ($entries.Count -gt 1 -or ($record.Data.SchemaVersion -ge 4 -and $entries.Count -ne 1)) { throw 'Ficha da examinada ausente/ambigua.' }
                $path=if ($entries.Count) {Resolve-ProjectPath $entries[0].Path $State.Project.Root} else {$null}
                if ($path -and $record.Data.SchemaVersion -lt 4 -and $null -eq (Read-ConversionText $State.Inputs.Session $path)) { $path=$null }
                $reason=Get-ConversionRankingAssessment $State $ranking $issue $path
                $assessments[$issue.Id]=@($assessments[$issue.Id])+@([pscustomobject]@{Text=$reason;Path=$ranking.Path})
                $examined[$issue.Id]=[pscustomobject]@{Project=$State.Project.Name;Id=$issue.Id;Position=$null;Reason=''}
                if ($path) {
                    $text=Read-ConversionText $State.Inputs.Session $path
                    if ($null -eq $text) { throw ('Ficha examinada indisponivel: '+$path) }
                    $markers=[regex]::Matches($text,'(?s)<!-- issue:\s*(\{.*?\})\s*-->')
                    if ($markers.Count -ne 1) { throw 'Ficha legada sem identidade unica.' }
                    $identity=ConvertFrom-Json $markers[0].Groups[1].Value
                    if ($identity.Id -cne $issue.Id -or (Resolve-ProjectPath $identity.Source $State.Project.Root) -ine $State.Inputs.Preview.LegacySource) { throw 'Identidade divergente na ficha legada.' }
                    $human=$text.Remove($markers[0].Index,$markers[0].Length)
                    if ($fichas.ContainsKey($issue.Id) -and $fichas[$issue.Id].HasContent -and $fichas[$issue.Id].Text -cne $human) { throw 'Fichas divergentes da mesma issue examinada; escolha o conteudo corrente explicitamente.' }
                    $fichas[$issue.Id]=[pscustomobject]@{Path=$path;Text=$human;HasContent=$true}
                    $State.Map[$path]=Join-Path $State.Project.Folder (Get-PrioritizationFichaRelativePath $category $issue.Id)
                } elseif (-not $fichas.ContainsKey($issue.Id)) {
                    $fichas[$issue.Id]=[pscustomobject]@{Path=$ranking.Path;Text=('# '+$issue.Id+"`n`n"+$reason+"`n`nDetalhamento adicional nao fornecido no legado. Conferir codigo, evidencias e roteiro antes da corretiva.");HasContent=$false}
                }
            }
        }
        $excluded=$beforeLast
        $available=@($rankings[-1].Available | Where-Object Id -CNotIn @($excluded | ForEach-Object Id))
        $percent=ConvertTo-PrioritizationPercentage ([string]$current.Data.Percentage)
        $slice=[int][Math]::Min($available.Count,[Math]::Ceiling($baseline.Count*$percent/100))
        $status=$rankings[-1].Result.Status
        if ($examined.Count-$excluded.Count -ne $slice) { $status='IN_PROGRESS' }
        $eligibleKnown=@($current.Data.Projects | Where-Object { $_.PSObject.Properties['EligibleIssues'] }).Count -eq @($current.Data.Projects).Count
        $outside=$null
        if ($eligibleKnown) {
            $eligible=@(foreach ($participant in $current.Data.Projects) {
                if ($participant.EligibleIssues -isnot [Array]) { throw 'EligibleIssues legado exige array.' }
                foreach ($issue in $participant.EligibleIssues) {
                if ($issue.PSObject.Properties['Category'] -and $issue.Category -cne $category) { throw 'Elegibilidade legada contem outra categoria.' }
                if ($issue.PSObject.Properties['Source'] -and (Resolve-ProjectPath $issue.Source $State.Project.Root) -ine (Resolve-ProjectPath $participant.Source $State.Project.Root)) { throw 'Elegibilidade legada contem outro Source.' }
                [pscustomobject]@{Source=$participant.Source;Id=$issue.Id}
            } })
            $outside=@(Convert-ConversionIssues $State $eligible | Where-Object Id -CNotIn $baselineIds).Count
        } else { $State.Diagnostics.Add('Elegiveis fora da base inicial nao informadas no contexto legado; conferir origem atual.') }
        $codeRoot=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
        $data=[pscustomobject][ordered]@{Purpose='current-prioritization';Scope=$scope;Category=$category;ContextPath=$paths.ContextPath;RankingPath=$paths.RankingPath;PromptPath=$paths.PromptPath;IndexPath=$paths.IndexPath;PrioritizationIndexPath=(Join-Path $State.Project.Root '.harness/indices/priorizacao.md');
            Projects=@([pscustomobject]@{Project=$State.Project.Name;Label=$State.Project.Name;Source=$State.Project.Source;Pom=$State.Project.Pom;MigrationPath=$State.Project.MigrationPath;EvidencePath=$State.Project.EvidencePath;Mta=$(if ($State.Mta) {@{ReportPath=$State.Mta.ReportPath;CatalogPath=$State.Mta.CatalogPath}} else {$null});Diagnostics=@($State.Diagnostics)});
            Percentage=$percent;InitialTotal=$baseline.Count;SliceSize=$slice;BaselineIssues=$baseline;ExcludedIssues=$excluded;AvailableIssues=$available;
            FichaPaths=@(foreach ($issue in $baseline) {[pscustomobject]@{Project=$State.Project.Name;Id=$issue.Id;Path=(Join-Path $State.Project.Folder (Get-PrioritizationFichaRelativePath $category $issue.Id))}});OutsideBaseline=$outside;ContractPath=(Join-Path $codeRoot 'doc/adr/0009-estado-corrente-por-projeto.md')}
        Assert-PrioritizationContext $data $paths @($State.Project) $category $scope
        [pscustomobject]@{Data=$data;Paths=$paths;Fichas=$fichas;Rankings=$rankings;Examined=$examined;Assessments=$assessments;Status=$status}
    }
}

function Add-ConversionPrioritizationDocuments($State,$Prioritizations) {
    $codeRoot=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    foreach ($priority in $Prioritizations) {
        $data=$priority.Data; $paths=$priority.Paths; $fichas=$priority.Fichas
        $category=$data.Category; $scope=$data.Scope
        foreach ($issue in $priority.Examined.Values) {
            $issue.Reason=(@($priority.Assessments[$issue.Id] | Where-Object { $_ } | ForEach-Object { Convert-ConversionMarkdown $_.Text $_.Path $paths.RankingPath $State } | Select-Object -Unique) -join "`n")
        }
        foreach ($id in $fichas.Keys) {
            # Uma lacuna sintetica nao disputa o texto humano da ficha do lote.
            if (-not $fichas[$id].HasContent -and @($State.FichaPaths | Where-Object { $_.Id -ceq $id -and $_.Category -ceq $category -and $_.Status -eq 'DISPONIVEL' }).Count) { continue }
            $relative=Get-PrioritizationFichaRelativePath $category $id; $target=Join-Path $State.Project.Folder $relative
            $ficha=$fichas[$id]; $text=Convert-ConversionMarkdown $ficha.Text $ficha.Path $target $State
            $local=@(); $evidence=@()
            foreach ($link in @(Get-ConversionLinks $text $target $State.Inputs.Session)) {
                if ($link.StartsWith($State.Project.Source+'\',[StringComparison]::OrdinalIgnoreCase)) { $local+=$link.Substring($State.Project.Source.Length+1) }
                if ($link.StartsWith($State.Project.EvidencePath+'\',[StringComparison]::OrdinalIgnoreCase)) { $evidence+=$link.Substring($State.Project.EvidencePath.Length+1) }
            }
            $identity=[ordered]@{Project=$State.Project.Name;Category=$category;Id=$id;LocalPaths=@($local|Sort-Object -Unique);EvidencePaths=@($evidence|Sort-Object -Unique)}|ConvertTo-Json -Depth 6
            $text=Set-ProjectManagedBlock $text 'ficha:identidade' $identity
            $text=Get-IssueSourcesText $State.Project $State.Mta $id $category $text $target -AvailablePaths @($State.Map.Values)
            if ($State.Files.Contains($relative) -and $State.Files[$relative] -cne $text) { throw 'Ficha do planejamento diverge da priorizacao; conferir antes de consolidar.' }
            $State.Files[$relative]=$text
        }
        $result=[pscustomobject]@{Scope=$scope;Category=$category;Status=$priority.Status;AnalyzedIssues=@($priority.Examined.Values)}
        $text=(@($priority.Rankings | ForEach-Object { Convert-ConversionMarkdown $_.Text $_.Path $paths.RankingPath $State }) -join "`n`n")
        $text=Set-PrioritizationResult $text $result
        $text=Set-ProjectManagedBlock $text 'priorizacao:fichas' (Get-PrioritizationRows $data $result $paths.RankingPath)
        $State.Files[$paths.Relative+'/priorizacao.md']=$text; $State.Files[$paths.Relative+'/contexto.json']=$data|ConvertTo-Json -Depth 15
        $State.Files[$paths.Relative+'/indice.md']=Get-PrioritizationIndexContent $data $result ''
        $template=[IO.File]::ReadAllText((Join-Path $codeRoot '.github/prompts/priorizar-issues.prompt.md'))
        $State.Files[$paths.Relative+'/priorizar-issues.prompt.md']=$template+"`n`nContexto corrente selecionado: "+(Get-HarnessSourceLink $paths.PromptPath $paths.ContextPath 'Contexto')+"`n"+(Get-HarnessSourceLink $paths.PromptPath $paths.IndexPath 'Indice e fontes')
    }
}
