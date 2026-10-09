# Indice derivado: nunca usado para escolher uma sequencia ou conceder aceite.
function ConvertTo-PrioritizationIndexCell {
    param($Value)
    ([string]$Value).Replace('&','&amp;').Replace('<','&lt;').Replace('>','&gt;').Replace('|','&#124;').Replace('`','&#96;').Replace('{','&#123;').Replace('}','&#125;') -replace '[\r\n]+',' '
}

function Expand-PrioritizationIndexTemplate {
    param([string]$Template, [hashtable]$Values)
    [regex]::Replace($Template, '\{\{(\w+)\}\}', [Text.RegularExpressions.MatchEvaluator]{
        param($match)
        $key=$match.Groups[1].Value
        if (-not $Values.ContainsKey($key)) { throw "Campo desconhecido no template do indice: $key" }
        [string]$Values[$key]
    })
}

function Get-PrioritizationIndexContent {
    param($History, [string]$Template)
    $sectionMatch=[regex]::Match($Template,'(?s)<!-- modelo:sequencia:inicio -->(.*?)<!-- modelo:sequencia:fim -->')
    if (-not $sectionMatch.Success) { throw 'Template do indice sem bloco de sequencia.' }
    $sectionTemplate=$sectionMatch.Groups[1].Value.Trim()
    $mainTemplate=$Template.Remove($sectionMatch.Index,$sectionMatch.Length).Trim()
    $sections=[Collections.Generic.List[string]]::new()
    $superseded=[Collections.Generic.List[string]]::new()
    $groups=@($History | Group-Object { if ($_.PSObject.Properties['SequenceId']) { $_.SequenceId } else { $_.RequestId } } | Sort-Object Name)
    foreach ($group in $groups) {
        $members=@($group.Group)
        $ordered=[Collections.Generic.List[object]]::new()
        $diagnostics=[Collections.Generic.List[string]]::new()
        $completed=[Collections.Generic.List[string]]::new()
        $keys=[Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
        $category=Get-PrioritizationCategory $members[0]
        $scope=Get-PrioritizationScope $members[0].Projects
        $front=@($History | Where-Object {
            (Get-PrioritizationCategory $_) -ieq $category -and (Get-PrioritizationScope $_.Projects) -ceq $scope
        })
        $state='ativa'; $chainValid=$true; $initial='N/A'; $percentage='N/A'
        $replacements=@($front | Where-Object { $_.PSObject.Properties['Previous'] -and $_.Previous -and $_.Mode -eq 'Recreate' -and $_.Previous.RequestId -cin @($members.RequestId) })
        try {
            $roots=@($members | Where-Object { $_.RequestId -ceq $group.Name -and $_.Mode -ne 'Continue' })
            if ($roots.Count -ne 1 -or -not $roots[0].PSObject.Properties['BaselineIssues']) { throw 'Raiz/base da sequencia ausente ou legado sem percentual; confira os recibos.' }
            $cursor=$roots[0]; $initial=$cursor.InitialTotal
            $baseline=@($cursor.BaselineIssues | ForEach-Object { Get-PrioritizationIssueKey $_ } | Sort-Object -Unique -CaseSensitive)
            if ($initial -ne $baseline.Count) { throw 'Denominador inicial diverge das identidades da base.' }
            $scope=Get-PrioritizationScope $cursor.Projects
            $seen=@{}
            while ($cursor) {
                if ($seen.ContainsKey($cursor.RequestId)) { throw 'Ciclo na sequencia.' }
                $seen[$cursor.RequestId]=$true; $ordered.Add($cursor)
                if ((Get-PrioritizationCategory $cursor) -ine $category -or (Get-PrioritizationScope $cursor.Projects) -cne $scope -or $cursor.InitialTotal -ne $initial -or
                    (@($cursor.BaselineIssues | ForEach-Object { Get-PrioritizationIssueKey $_ } | Sort-Object -Unique -CaseSensitive) -join "`n") -cne ($baseline -join "`n")) { throw 'Categoria, escopo ou base divergente na sequencia.' }
                $children=@($front | Where-Object { $_.PSObject.Properties['Previous'] -and $_.Previous -and $_.Previous.RequestId -ceq $cursor.RequestId })
                if ($children.Count -gt 1) { throw 'AMBIGUA: varios sucessores; nenhuma ponta escolhida por recencia.' }
                $next=@($members | Where-Object { $_.Mode -eq 'Continue' -and $_.Previous -and $_.Previous.RequestId -ceq $cursor.RequestId })
                if ($next.Count) {
                    $null=Get-PrioritizationParent $next[0] $History
                    $cursor=$next[0]
                } else { $cursor=$null }
            }
            if ($ordered.Count -ne $members.Count) { throw 'Sequencia desconectada; confira Previous/SequenceId.' }
            $percentage=([decimal]$ordered[$ordered.Count-1].Percentage).ToString('0.##',[Globalization.CultureInfo]::InvariantCulture)
        } catch {
            $chainValid=$false; $state='a conferir'
            $diagnostics.Add((ConvertTo-PrioritizationIndexCell $_.Exception.Message))
            # IDs apenas para exibir candidatos; nao representam a ordem da sequencia.
            $ordered.Clear(); foreach ($member in ($members | Sort-Object RequestId)) { $ordered.Add($member) }
        }
        if ($replacements.Count -and $chainValid) { $state='substituida' }
        if ($state -eq 'ativa') {
            $tips=@($front | Where-Object {
                $candidate=$_.RequestId
                -not @($front | Where-Object { $_.PSObject.Properties['Previous'] -and $_.Previous -and $_.Previous.RequestId -ceq $candidate }).Count
            })
            if ($tips.Count -gt 1) {
                $state='candidata (AMBIGUA)'
                $diagnostics.Add('Mais de uma ponta para este escopo/categoria; escolha explicita necessaria. Coberturas nao sao somadas entre frentes.')
            }
        }
        $ordinal=0
        foreach ($receipt in $ordered) {
            $ordinal++
            $id=$receipt.RequestId; $contextLink="[context.json]($id/context.json)"
            $rankingLink=if (Test-Path -LiteralPath $receipt.RankingPath -PathType Leaf) { "[priorizacao.md]($id/priorizacao.md)" } else { 'N/A (a produzir)' }
            $status='PENDENTE'; $reason='Execute o prompt preparado; o preparo nao comprova exame.'
            if (Test-Path -LiteralPath $receipt.RankingPath -PathType Leaf) {
                try {
                    $result=Read-PrioritizationResult $receipt
                    if (-not $chainValid) { throw 'Resultado individual presente; cadeia nao conferida.' }
                    foreach ($issue in $result.AnalyzedIssues) {
                        $key=Get-PrioritizationIssueKey $issue
                        if ($key -cnotin $baseline) { throw 'Examinada fora da base inicial.' }
                    }
                    foreach ($issue in $result.AnalyzedIssues) { $null=$keys.Add((Get-PrioritizationIssueKey $issue)) }
                    $labels=@(foreach ($project in $receipt.Projects) {
                        if (@($result.AnalyzedIssues | Where-Object Source -IEQ $project.Source).Count) { ConvertTo-PrioritizationIndexCell $project.Label }
                    }) -join ', '
                    if (-not $labels) { $labels='N/A' }
                    $order=if ($ordinal -eq $ordered.Count) { "$ordinal (atual)" } else { [string]$ordinal }
                    $date=ConvertTo-PrioritizationIndexCell $receipt.PreparedAtUtc
                    $completed.Add("| $order | ``$id`` | $(ConvertTo-PrioritizationIndexCell $receipt.Mode) | $date | $(@($result.AnalyzedIssues).Count) | $labels | $(@($result.ProposedIssues).Count) | $rankingLink | $contextLink |")
                    $status='COMPLETED conferido'; $reason=''
                } catch { $status='NAO_VALIDADA'; $reason=$_.Exception.Message }
            }
            if ($status -ne 'COMPLETED conferido') {
                $diagnostics.Add("``$id`` | $status | $(ConvertTo-PrioritizationIndexCell $reason) | $contextLink | $rankingLink")
            }
            if ($state -eq 'substituida') {
                $replacing=(@($replacements.RequestId) -join ', ')
                $superseded.Add("| ``$id`` | $(ConvertTo-PrioritizationIndexCell $receipt.Mode) | $(ConvertTo-PrioritizationIndexCell $receipt.PreparedAtUtc) | Substituida pelo Recreate ``$replacing``; $status | $rankingLink |")
            }
        }
        $count=if ($chainValid) { [string]$keys.Count } else { 'N/A' }
        $coverage=if ($chainValid -and $initial -gt 0) { ([decimal]($keys.Count*100)/[decimal]$initial).ToString('0.##',[Globalization.CultureInfo]::InvariantCulture) } else { 'N/A' }
        $scopes=@($members[0].Projects | ForEach-Object { ConvertTo-PrioritizationIndexCell ($_.Label+' ('+$_.Source+')') }) -join '; '
        $pending=if ($diagnostics.Count) { '- '+($diagnostics -join "`n- ") } else { 'Nenhuma pendencia de preenchimento identificada nesta conferencia.' }
        $sections.Add((Expand-PrioritizationIndexTemplate $sectionTemplate @{
            SequenceState=$state;Category=(ConvertTo-PrioritizationIndexCell $category);SequenceId=(ConvertTo-PrioritizationIndexCell $group.Name)
            InitialIssueCount=$initial;SlicePercent=$percentage;ScopeLabels=$scopes
            CompletedRows=($completed -join "`n");UniqueAnalyzedIssueCount=$count;CoveragePercent=$coverage;PendingRows=$pending
        }))
    }
    $latest=@($History | ForEach-Object PreparedAtUtc | Sort-Object | Select-Object -Last 1)
    Expand-PrioritizationIndexTemplate $mainTemplate @{
        PreparedThroughUtc=if ($latest.Count) { ConvertTo-PrioritizationIndexCell $latest[0] } else { 'N/A' }
        Verification='deterministica pelo preparador; COMPLETED exige bloco, quota, fichas e cadeia consistentes'
        Sequences=($sections -join "`n`n");SupersededRows=($superseded -join "`n")
        SupersededNote=if ($superseded.Count) { '' } else { 'Nenhuma sequencia substituida comprovada.' }
    }
}

function Merge-PrioritizationIndexContent {
    param([string]$Existing, [string]$Content)
    $start='<!-- priorizacao:indice:inicio -->'; $end='<!-- priorizacao:indice:fim -->'
    $starts=[regex]::Matches($Existing,[regex]::Escape($start)); $ends=[regex]::Matches($Existing,[regex]::Escape($end))
    $block=$start+"`n"+$Content.Trim()+"`n"+$end
    if (-not $starts.Count -and -not $ends.Count) {
        if (-not $Existing) { return $block+"`n" }
        return $Existing+"`n`n"+$block+"`n"
    }
    if ($starts.Count -ne 1 -or $ends.Count -ne 1 -or $starts[0].Index -ge $ends[0].Index) { throw 'Marcadores do indice invalidos/duplicados; arquivo preservado. Confira o bloco gerenciado.' }
    $last=$ends[0].Index+$end.Length
    $Existing.Substring(0,$starts[0].Index)+$block+$Existing.Substring($last)
}

function Write-PrioritizationIndexContent {
    param([string]$Path, [string]$Content, [string]$Original, [bool]$Existed)
    # Mesmo padrao do registro: preparar no mesmo volume e substituir sem truncar
    # o unico arquivo que pode conter notas humanas nao reconstruiveis.
    $temporary=$Path+'.'+[guid]::NewGuid().ToString('N')+'.tmp'
    try {
        [IO.File]::WriteAllText($temporary,$Content,(New-Object Text.UTF8Encoding($false)))
        if ($Existed) {
            for ($attempt=0; $attempt -lt 8; $attempt++) {
                if (-not (Test-Path -LiteralPath $Path -PathType Leaf) -or [IO.File]::ReadAllText($Path) -cne $Original) {
                    throw 'Indice mudou durante a atualizacao; arquivo preservado. Releia antes de publicar.'
                }
                try { [IO.File]::Replace($temporary,$Path,[System.Management.Automation.Language.NullString]::Value); break }
                catch {
                    $code=$_.Exception.GetBaseException().HResult -band 0xffff
                    if ($code -notin @(32,1175) -or $attempt -eq 7) { throw }
                    # Assim como na publicacao de sprints, handles de indexadores
                    # podem impedir temporariamente a substituicao no Windows.
                    Start-Sleep -Milliseconds 200
                }
            }
        } else {
            # Move falha se alguem criou o destino depois da leitura; nao sobrescreve.
            [IO.File]::Move($temporary,$Path)
        }
    } finally { if (Test-Path -LiteralPath $temporary -PathType Leaf) { Remove-Item -LiteralPath $temporary } }
}

function Update-PrioritizationIndex {
    param([string]$Root)
    $path=Join-Path $Root '.harness/priorizacao/indice-priorizacao.md'
    $template=[IO.File]::ReadAllText((Join-Path $Root 'doc/modelos/indice-priorizacao.template.md'))
    $history=@(Read-PrioritizationHistory $Root)
    $content=Get-PrioritizationIndexContent $history $template
    $existed=Test-Path -LiteralPath $path -PathType Leaf
    $existing=if ($existed) { [IO.File]::ReadAllText($path) } else { '' }
    $updated=Merge-PrioritizationIndexContent $existing $content
    if ($updated -cne $existing) {
        $null=[IO.Directory]::CreateDirectory((Split-Path $path -Parent))
        Write-PrioritizationIndexContent $path $updated $existing $existed
    }
    $path
}
