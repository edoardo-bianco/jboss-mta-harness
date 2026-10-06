# Funcoes privadas de priorizacao; carregadas pelo modulo em PowerShell 5.1.
function ConvertTo-PrioritizationPercentage {
    param([string]$Value)
    $text = $Value.Trim()
    if ($text -notmatch '^\d{1,3}([.,]\d{1,2})?\s*%?$') { throw 'Informe percentual de 0,01 a 100,00, com ate duas casas decimais.' }
    $number = [decimal]::Parse(($text -replace '\s|%','').Replace(',','.'), [Globalization.CultureInfo]::InvariantCulture)
    if ($number -lt 0.01 -or $number -gt 100) { throw 'Percentual deve estar entre 0,01 e 100,00.' }
    $number
}

function Get-PrioritizationIssueKey {
    param($Issue)
    ([string]$Issue.Source).ToLowerInvariant() + "`n" + [string]$Issue.Id
}

function Get-PrioritizationScope {
    param($Projects)
    (@($Projects | ForEach-Object { ([string]$_.Source).ToLowerInvariant() } | Sort-Object -Unique) -join "`n")
}

function Get-PrioritizationCategory {
    param($Receipt)
    if ($Receipt.PSObject.Properties['Category'] -and $Receipt.Category) { return [string]$Receipt.Category }
    if ($Receipt.PSObject.Properties['SchemaVersion'] -and $Receipt.SchemaVersion -ge 4) { throw 'Categoria ausente no recibo de priorizacao.' }
    'mandatory'
}

function Read-PrioritizationHistory {
    param([string]$Root)
    $projectPaths=@{}
    $base = Join-Path $Root '.harness/priorizacao'
    if (-not (Test-Path -LiteralPath $base)) { return }
    foreach ($folder in Get-ChildItem -LiteralPath $base -Directory) {
        if ($folder.Name -cnotmatch '^[a-f0-9]{32}$') { continue }
        $path = Resolve-HarnessPath (Join-Path $folder.FullName 'context.json') $Root
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Solicitacao incompleta: $path. Confira antes de preparar outra." }
        $receipt = Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($receipt.Purpose -ne 'issue-prioritization' -or $receipt.RequestId -cne $folder.Name -or
            $receipt.ContextPath -ine $path -or $receipt.RankingPath -ine (Join-Path $folder.FullName 'priorizacao.md') -or
            $receipt.PromptPath -ine (Join-Path $folder.FullName 'priorizar-issues.prompt.md')) { throw "Identidade/destinos invalidos: $path" }
        $null = Resolve-HarnessPath $receipt.RankingPath $Root
        $null = Resolve-HarnessPath $receipt.PromptPath $Root
        if ($receipt.PSObject.Properties['SchemaVersion'] -and $receipt.SchemaVersion -ge 4) {
            if ($receipt.SchemaVersion -ne 4) { throw 'Versao de priorizacao desconhecida.' }
            if (@($receipt.FichaPaths).Count -ne @($receipt.AvailableIssues).Count) { throw 'Destinos das fichas divergem das issues disponiveis.' }
            $fichas=@{}; $projects=@{}
            foreach ($entry in $receipt.FichaPaths) {
                $key=Get-PrioritizationIssueKey $entry
                if ($fichas.ContainsKey($key)) { throw 'Destino de ficha duplicado.' }
                $fichas[$key]=$entry
            }
            foreach ($project in $receipt.Projects) { $projects[$project.Source]=$project }
            foreach ($issue in $receipt.AvailableIssues) {
                $entry=$fichas[(Get-PrioritizationIssueKey $issue)]
                $project=$projects[$issue.Source]
                if (-not $entry -or -not $project) { throw 'Destino/identidade de ficha ambiguo.' }
                if (-not $projectPaths.ContainsKey($project.Source)) {
                    $projectPaths[$project.Source]=Get-HarnessIssueProjectPaths $Root ([pscustomobject]@{name=$project.Project;label=$project.Label;path=$project.Source})
                }
                $paths=Get-HarnessIssuePaths $Root $null $issue.Id -ProjectPaths $projectPaths[$project.Source]
                $expected=Join-Path $paths.Folder ('fichas/p_'+$receipt.RequestId.Substring(0,12)+'/ficha-'+$paths.Stem+'.md')
                if ([IO.Path]::GetFullPath($entry.Path) -ine $expected) { throw 'Destino de ficha fora da issue/projeto.' }
            }
        }
        $receipt
    }
}

function Select-PrioritizationPrevious {
    param($History, $Projects, [string]$RequestId, [switch]$Interactive, [string]$Category='mandatory')
    if ($RequestId) {
        $selected = @($History | Where-Object RequestId -CEQ $RequestId)
        if ($selected.Count -ne 1) { throw 'PreviousRequestId ausente ou ambiguo.' }
        $visited = @{}
        while ($true) {
            $current = $selected[0]
            if ((Get-PrioritizationCategory $current) -ine $Category) { throw 'A solicitacao pertence a outra categoria; inicie ou retome a sequencia dessa categoria.' }
            if ($visited.ContainsKey($current.RequestId)) { throw 'Ciclo no historico de priorizacao.' }
            $visited[$current.RequestId] = $true
            $successors = @($History | Where-Object { $_.PSObject.Properties['Previous'] -and $_.Previous -and $_.Previous.RequestId -ceq $current.RequestId })
            if (-not $successors.Count) { return $current }
            if ($successors.Count -gt 1) { throw 'Referencia com varios sucessores. Informe PreviousRequestId da frente desejada.' }
            $selected = $successors
        }
    }
    $scope = Get-PrioritizationScope $Projects
    $matching = @($History | Where-Object { (Get-PrioritizationScope $_.Projects) -ceq $scope -and (Get-PrioritizationCategory $_) -ieq $Category })
    $parents = @($matching | Where-Object { $_.PSObject.Properties['Previous'] -and $_.Previous } | ForEach-Object { $_.Previous.RequestId })
    $tips = @($matching | Where-Object { $_.RequestId -cnotin $parents } | Sort-Object RequestId)
    if ($matching.Count -and -not $tips.Count) { throw 'Historico de priorizacao sem ponta unica; confira os vinculos.' }
    if ($tips.Count -eq 1) { return $tips[0] }
    if ($tips.Count -gt 1) {
        if (-not $Interactive) { throw 'Varias priorizacoes deste escopo. Informe PreviousRequestId; nao escolher por recencia.' }
        for ($i=0; $i -lt $tips.Count; $i++) { Write-Host ("{0}. {1} | {2}" -f ($i+1), $tips[$i].RequestId, $tips[$i].RankingPath) }
        $answer = Read-Host 'Escolha a priorizacao anterior (q/Enter cancela)'
        $choice = 0
        if (-not [int]::TryParse($answer,[ref]$choice) -or $choice -lt 1 -or $choice -gt $tips.Count) { throw 'Priorizacao cancelada.' }
        return $tips[$choice-1]
    }
}

function Get-PrioritizationPreparedResult {
    param($Receipt, [bool]$Reused=$false, [string]$Status='PREPARED')
    [pscustomobject]@{Status=$Status;RequestId=$Receipt.RequestId;Category=(Get-PrioritizationCategory $Receipt);ContextPath=$Receipt.ContextPath;
        PromptPath=$Receipt.PromptPath;RankingPath=$Receipt.RankingPath;Projects=$Receipt.Projects;
        Percentage=$Receipt.Percentage;InitialTotal=$Receipt.InitialTotal;SliceSize=$Receipt.SliceSize;Reused=$Reused}
}

function Get-PrioritizationBasis {
    param($Projects)
    $basis = @(foreach ($project in ($Projects | Sort-Object Source)) {
        $mta = $project.Mta
        [ordered]@{Source=$project.Source.ToLowerInvariant();Mta=if ($mta) {
            [ordered]@{RunId=$mta.RunId;Project=$mta.MtaOrigin.Project;Source=$mta.MtaOrigin.Source;Run=$mta.MtaOrigin.Run;
                Manifest=$mta.EvidenceHashes.Manifest;Result=$mta.EvidenceHashes.Result;Findings=$mta.EvidenceHashes.Findings;
                Dependencies=$mta.EvidenceHashes.Dependencies;CatalogSha256=$mta.CatalogSha256}
        } else { $null }}
    })
    ConvertTo-Json -InputObject $basis -Depth 10 -Compress
}

function Read-PrioritizationResult {
    param($Receipt)
    Assert-PrioritizationIncidentEvidence $Receipt
    $text = [IO.File]::ReadAllText($Receipt.RankingPath)
    $matches = [regex]::Matches($text, '(?s)<!-- priorizacao:resultado -->\s*```json\s*(.*?)\s*```\s*<!-- /priorizacao:resultado -->')
    if ($matches.Count -ne 1) { throw 'Ranking incompleto/antigo: falta bloco unico priorizacao:resultado. Complete a solicitacao ou recrie.' }
    $result = $matches[0].Groups[1].Value | ConvertFrom-Json
    if ($result.RequestId -cne $Receipt.RequestId -or $result.Status -cne 'COMPLETED') { throw 'Resultado de outra solicitacao ou ainda nao concluido.' }
    $available = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($issue in $Receipt.AvailableIssues) { $null = $available.Add((Get-PrioritizationIssueKey $issue)) }
    $examined = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($field in @('AnalyzedIssues','ProposedIssues')) {
        if (-not $result.PSObject.Properties[$field] -or $result.$field -isnot [Array]) { throw "Resultado exige array $field." }
        $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
        foreach ($issue in $result.$field) {
            if (-not $issue.PSObject.Properties['Source'] -or -not $issue.PSObject.Properties['Id']) { throw 'Issue do resultado exige Source e Id completos.' }
            $key = Get-PrioritizationIssueKey $issue
            if (-not $available.Contains($key) -or -not $seen.Add($key)) { throw 'Resultado contem issue indisponivel ou duplicada.' }
            if ($field -eq 'AnalyzedIssues') { $null = $examined.Add($key) }
            elseif (-not $examined.Contains($key)) { throw 'Issue proposta deve pertencer a AnalyzedIssues.' }
        }
    }
    if ($examined.Count -gt $Receipt.SliceSize) { throw 'Resultado examina mais issues que a quota da fatia.' }
    if ($Receipt.SchemaVersion -ge 3 -and $examined.Count -ne $Receipt.SliceSize) {
        throw 'Resultado COMPLETED exige todas as issues da fatia em AnalyzedIssues, inclusive sem recomendacao com motivo no relatorio. Complete a analise; parcial permanece IN_PROGRESS.'
    }
    if ($Receipt.SchemaVersion -ge 4) {
        foreach ($issue in $result.AnalyzedIssues) {
            $ficha=@($Receipt.FichaPaths | Where-Object { $_.Source -ieq $issue.Source -and $_.Id -ceq $issue.Id })
            if ($ficha.Count -ne 1 -or -not (Test-Path -LiteralPath $ficha[0].Path -PathType Leaf)) { throw 'Falta ficha individual de issue examinada.' }
            $null=Resolve-HarnessPath $ficha[0].Path (Split-Path $Receipt.ContextPath -Parent)
            Assert-HarnessIssueFicha $ficha[0].Path $issue.Source $issue.Id
        }
    }
    $result
}

function Get-PrioritizationExcludedIssues {
    param($Previous, $History)
    $cursor = $Previous
    $requests = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    $issues = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    while ($cursor) {
        if (-not $requests.Add($cursor.RequestId) -or $cursor.SequenceId -cne $Previous.SequenceId -or (Get-PrioritizationCategory $cursor) -ine (Get-PrioritizationCategory $Previous)) { throw 'Ciclo, categoria ou sequencia divergente no historico.' }
        $result = Read-PrioritizationResult $cursor
        # Cobertura independe de recomendacao. Resultados v2 podem se sobrepor;
        # consumir sua uniao sem reescrever recibos ou inventar analise ausente.
        foreach ($issue in $result.AnalyzedIssues) {
            if ($issues.Add((Get-PrioritizationIssueKey $issue))) { $issue }
        }
        if ($cursor.Mode -ne 'Continue') { break }
        $cursor = Get-PrioritizationParent $cursor $History
    }
}

function Get-PrioritizationParent {
    param($Receipt, $History)
    $parent = @($History | Where-Object RequestId -CEQ $Receipt.Previous.RequestId)
    if ($parent.Count -ne 1 -or -not (Test-Path -LiteralPath $parent[0].RankingPath -PathType Leaf) -or
        (Get-FileHash -LiteralPath $parent[0].RankingPath -Algorithm SHA256).Hash -cne $Receipt.Previous.RankingSha256) { throw 'Resultado anterior ausente/alterado; confira a sequencia ou recrie.' }
    if ($parent[0].SchemaVersion -ge 4) {
        $expected=@(Get-PrioritizationFichaHashes $parent[0])
        if (-not $Receipt.Previous.PSObject.Properties['FichaHashes'] -or
            (ConvertTo-Json -InputObject $expected -Compress) -cne (ConvertTo-Json -InputObject @($Receipt.Previous.FichaHashes) -Compress)) { throw 'Fichas anteriores ausentes/alteradas; confira a sequencia ou recrie.' }
    }
    $parent[0]
}

function Get-PrioritizationFichaHashes {
    param($Receipt)
    if ($Receipt.SchemaVersion -lt 4) { return }
    $result=Read-PrioritizationResult $Receipt
    foreach ($issue in $result.AnalyzedIssues) {
        $ficha=@($Receipt.FichaPaths | Where-Object { $_.Source -ieq $issue.Source -and $_.Id -ceq $issue.Id })[0]
        [pscustomobject]@{Source=$issue.Source;Id=$issue.Id;Path=$ficha.Path;Sha256=(Get-FileHash -LiteralPath $ficha.Path).Hash}
    }
}
