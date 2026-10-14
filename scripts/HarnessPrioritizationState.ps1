# Estado corrente por categoria/escopo; somente identidades funcionais persistidas.
function ConvertTo-PrioritizationPercentage {
    param([string]$Value)
    $text=([string]$Value).Trim()
    if ($text -notmatch '^\d{1,3}([.,]\d{1,2})?\s*%?$') { throw 'Informe percentual de 0,01 a 100,00, com ate duas casas decimais.' }
    $number=[decimal]::Parse(($text -replace '\s|%','').Replace(',','.'),[Globalization.CultureInfo]::InvariantCulture)
    if ($number -lt 0.01 -or $number -gt 100) { throw 'Percentual deve estar entre 0,01 e 100,00.' }
    $number
}

function Get-PrioritizationIssueKey {
    param($Issue)
    [string]$Issue.Project + "\n" + [string]$Issue.Id
}

function Get-PrioritizationPaths {
    param($Master,[string]$Category,[string]$Scope)
    $relative='atual/priorizacao/'+(ConvertTo-HarnessFunctionalPath $Category)+'/escopos/'+(ConvertTo-HarnessFunctionalPath $Scope)
    $folder=Join-Path $Master.Folder $relative
    # Publicacao PS5.1 usa nomes mais longos em temporarios/depois.
    if ((Join-Path $Master.TemporaryPath ('publicacao/depois/'+$relative+'/priorizar-issues.prompt.md')).Length -ge 248) {
        throw 'Caminho de priorizacao longo. Use raiz de dados curta e Scope funcional curto; nao truncar nem gerar hash.'
    }
    [pscustomobject]@{Relative=$relative;ContextPath=(Join-Path $folder 'contexto.json');
        RankingPath=(Join-Path $folder 'priorizacao.md');PromptPath=(Join-Path $folder 'priorizar-issues.prompt.md');
        IndexPath=(Join-Path $folder 'indice.md')}
}

function Get-PrioritizationSet {
    param($Issues,$Projects)
    $set=New-Object 'Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
    foreach ($issue in $Issues) {
        if ([string]::IsNullOrWhiteSpace($issue.Id) -or $issue.Project -cnotin @($Projects.Name) -or
            -not $set.Add((Get-PrioritizationIssueKey $issue))) { throw 'Identidade de issue ausente, duplicada ou fora do escopo.' }
    }
    return ,$set
}

function Assert-PrioritizationContext {
    param($Data,$Paths,$Projects,[string]$Category,[string]$Scope)
    if (-not @($Projects).Count -or $Data.Projects -isnot [Array] -or @($Projects | Group-Object Name | Where-Object Count -GT 1).Count) { throw 'Participantes ausentes ou duplicados.' }
    if ($Data.Purpose -cne 'current-prioritization' -or $Data.Category -cne $Category -or $Data.Scope -cne $Scope -or
        $Data.ContextPath -ine $Paths.ContextPath -or $Data.RankingPath -ine $Paths.RankingPath -or
        $Data.PromptPath -ine $Paths.PromptPath -or $Data.IndexPath -ine $Paths.IndexPath -or
        (@($Data.Projects.Project) -join '|') -cne (@($Projects.Name) -join '|')) { throw 'Contexto divergente do escopo/categoria/destinos correntes.' }
    foreach ($field in @('BaselineIssues','ExcludedIssues','AvailableIssues')) {
        if ($Data.$field -isnot [Array]) { throw "Contexto exige array $field." }
    }
    $baseline=Get-PrioritizationSet $Data.BaselineIssues $Projects
    $excluded=Get-PrioritizationSet $Data.ExcludedIssues $Projects
    $available=Get-PrioritizationSet $Data.AvailableIssues $Projects
    if (-not $excluded.IsSubsetOf($baseline) -or -not $available.IsSubsetOf($baseline) -or $excluded.Overlaps($available) -or
        $Data.InitialTotal -ne $baseline.Count -or $Data.SliceSize -lt 0 -or $Data.SliceSize -gt $available.Count) { throw 'Cobertura/base inicial inconsistente.' }
    $percent=ConvertTo-PrioritizationPercentage ([string]$Data.Percentage)
    if ($Data.SliceSize -ne [Math]::Min($available.Count,[Math]::Ceiling($baseline.Count*$percent/100))) { throw 'Quota divergente do percentual/base inicial.' }
}

function Read-PrioritizationResult {
    param($Data,[string]$Text,$Projects,[scriptblock]$FichaReader)
    $block=Find-ProjectManagedBlock $Text 'priorizacao:resultado'
    if (-not $block) { throw 'Ranking exige bloco unico priorizacao:resultado:inicio/fim.' }
    $json=$block.Value -replace '^<!-- priorizacao:resultado:inicio -->\s*','' -replace '\s*<!-- priorizacao:resultado:fim -->$',''
    $result=ConvertFrom-Json $json
    if ($result.Category -cne $Data.Category -or $result.Scope -cne $Data.Scope -or
        $result.Status -cnotin @('IN_PROGRESS','COMPLETED') -or $result.AnalyzedIssues -isnot [Array]) { throw 'Resultado invalido ou de outro escopo/categoria.' }
    $examined=Get-PrioritizationSet $result.AnalyzedIssues $Projects
    $excluded=Get-PrioritizationSet $Data.ExcludedIssues $Projects
    $allowed=Get-PrioritizationSet @($Data.ExcludedIssues+$Data.AvailableIssues) $Projects
    if (-not $excluded.IsSubsetOf($examined) -or -not $examined.IsSubsetOf($allowed)) { throw 'Resultado perdeu examinadas anteriores ou incluiu issue indisponivel.' }
    $delta=$examined.Count-$excluded.Count
    if ($delta -gt $Data.SliceSize -or ($result.Status -ceq 'COMPLETED' -and $delta -ne $Data.SliceSize)) { throw 'COMPLETED exige exatamente a quota de novas examinadas; parcial deve ficar IN_PROGRESS.' }
    $positions=New-Object 'Collections.Generic.HashSet[int]'
    foreach ($issue in $result.AnalyzedIssues) {
        if ([string]::IsNullOrWhiteSpace($issue.Reason)) { throw 'Cada examinada exige motivo, inclusive sem recomendacao.' }
        if ($null -ne $issue.Position -and ($issue.Position -isnot [int] -or $issue.Position -lt 1 -or -not $positions.Add($issue.Position))) { throw 'Posicao deve ser inteiro positivo unico ou null para sem proposta.' }
        $project=@($Projects | Where-Object Name -CEQ $issue.Project)[0]
        $relative=Get-PrioritizationFichaRelativePath $Data.Category $issue.Id
        $ficha=if ($FichaReader) { & $FichaReader $project $relative } else { Read-HarnessProjectFiles $project @($relative) }
        if (-not $ficha[$relative]) { throw "Falta ficha da issue examinada: $($issue.Project) / $($issue.Id)" }
        $null=Read-PrioritizationFicha $ficha[$relative] $project.Name $Data.Category $issue.Id
    }
    $result
}

function Set-PrioritizationResult {
    param([string]$Text,$Result)
    Set-ProjectManagedBlock $Text 'priorizacao:resultado' ($Result | ConvertTo-Json -Depth 12)
}

function Get-PrioritizationPreparedResult {
    param($Data,[bool]$Reused=$false,[string]$Status='PREPARED')
    [pscustomobject]@{Status=$Status;Scope=$Data.Scope;Category=$Data.Category;ContextPath=$Data.ContextPath;
        PromptPath=$Data.PromptPath;RankingPath=$Data.RankingPath;Projects=$Data.Projects;IndexPath=$Data.IndexPath;
        PrioritizationIndexPath=$Data.PrioritizationIndexPath;Percentage=$Data.Percentage;InitialTotal=$Data.InitialTotal;
        SliceSize=$Data.SliceSize;Reused=$Reused}
}
