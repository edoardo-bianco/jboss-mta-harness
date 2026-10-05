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

function Read-PrioritizationHistory {
    param([string]$Root)
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
        $receipt
    }
}

function Select-PrioritizationPrevious {
    param($History, $Projects, [string]$RequestId, [switch]$Interactive)
    if ($RequestId) {
        $selected = @($History | Where-Object RequestId -CEQ $RequestId)
        if ($selected.Count -ne 1) { throw 'PreviousRequestId ausente ou ambiguo.' }
        $visited = @{}
        while ($true) {
            $current = $selected[0]
            if ($visited.ContainsKey($current.RequestId)) { throw 'Ciclo no historico de priorizacao.' }
            $visited[$current.RequestId] = $true
            $successors = @($History | Where-Object { $_.PSObject.Properties['Previous'] -and $_.Previous -and $_.Previous.RequestId -ceq $current.RequestId })
            if (-not $successors.Count) { return $current }
            if ($successors.Count -gt 1) { throw 'Referencia com varios sucessores. Informe PreviousRequestId da frente desejada.' }
            $selected = $successors
        }
    }
    $scope = Get-PrioritizationScope $Projects
    $matching = @($History | Where-Object { (Get-PrioritizationScope $_.Projects) -ceq $scope })
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
    [pscustomobject]@{Status=$Status;RequestId=$Receipt.RequestId;ContextPath=$Receipt.ContextPath;
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
    $result
}

function Get-PrioritizationExcludedIssues {
    param($Previous, $History)
    $cursor = $Previous
    $requests = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    $issues = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    while ($cursor) {
        if (-not $requests.Add($cursor.RequestId) -or $cursor.SequenceId -cne $Previous.SequenceId) { throw 'Ciclo ou sequencia divergente no historico.' }
        $result = Read-PrioritizationResult $cursor
        foreach ($issue in $result.ProposedIssues) {
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
    $parent[0]
}
