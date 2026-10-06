# Validacao sem consultar caminhos da maquina de origem e antes de qualquer escrita.
function Get-TransferCanonicalPath {
    param([string]$Path)
    if (-not $Path -or -not [IO.Path]::IsPathRooted($Path)) { throw 'Artefato recebido exige caminho absoluto de origem.' }
    $normal=$Path.Replace('/','\').TrimEnd('\')
    if ([IO.Path]::GetFullPath($normal) -ine $normal -or $normal -match '[\x00-\x1f]' -or $normal.Substring(2).Contains(':')) { throw 'Caminho de origem nao canonico.' }
    $normal
}
function Assert-TransferChild {
    param([string]$Path,[string]$Folder)
    $path=Get-TransferCanonicalPath $Path; $folder=Get-TransferCanonicalPath $Folder
    if (-not $path.StartsWith($folder+'\',[StringComparison]::OrdinalIgnoreCase)) { throw 'Artefato fora da pasta declarada pelo recibo.' }
}
function Add-TransferOwner {
    param($Owners,[string]$Path,[string]$Role)
    $path=Get-TransferCanonicalPath $Path
    if ($Owners.ContainsKey($path) -and $Owners[$path] -ne $Role) { throw 'Artefato com papeis conflitantes.' }
    $Owners[$path]=$Role
}
function Assert-TransferPackageSemantics {
    param($Manifest,$Archive,$Records)
    $owners=@{}; $files=@{}; $projectMap=@{}
    foreach ($file in $Manifest.Files) { $files[(Get-TransferCanonicalPath $file.OriginPath)]=$file }
    foreach ($project in $Manifest.Projects) {
        $source=Get-TransferCanonicalPath $project.Source
        if ($projectMap.ContainsKey($source)) { throw 'Source duplicado no manifesto.' }
        $projectMap[$source]=$project
        $register=@($Manifest.Files | Where-Object Entry -CEQ $project.RegisterEntry)
        if ($register.Count -ne 1) { throw 'Registro ausente/ambiguo.' }
        Add-TransferOwner $owners $register[0].OriginPath 'REGISTER'
        Add-TransferOwner $owners $project.EvidenceIndexOrigin 'INPUT_INDEX'
        foreach ($reference in $project.EvidenceEntries) {
            $annex=@($Manifest.Files | Where-Object Entry -CEQ $reference.Entry)
            if ($annex.Count -ne 1) { throw 'Anexo referenciado ausente.' }
            # Uma ficha ja inventariada pode tambem ser um anexo explicito.
            if ($annex[0].Role -eq 'ANNEX') { Add-TransferOwner $owners $annex[0].OriginPath 'ANNEX' }
        }
    }
    Add-TransferOwner $owners (Join-Path $Manifest.OriginRoot '.harness/projetos/indice-projetos.md') 'INDEX'
    foreach ($item in $Records) {
        $r=$item.Record; $folder=Split-Path $r.ContextPath -Parent
        if ($files[(Get-TransferCanonicalPath $r.ContextPath)].Entry -cne $item.Entry) { throw 'ContextPath diverge da entrada do recibo.' }
        Add-TransferOwner $owners $r.ContextPath 'CONTEXT'
        if ($Manifest.Kind -eq 'PLANEJAMENTO') {
            $project=$projectMap[(Get-TransferCanonicalPath $r.Source)]
            $register=@($Manifest.Files | Where-Object Entry -CEQ $project.RegisterEntry)[0]
            if ((Get-TransferCanonicalPath $r.MigrationPath) -ine (Get-TransferCanonicalPath $register.OriginPath)) { throw 'Registro do plano difere do projeto.' }
            foreach ($field in @('PlanPath','TodoPath')) {
                Assert-TransferChild $r.$field $folder
                Add-TransferOwner $owners $r.$field 'DOCUMENT'
            }
            Add-TransferOwner $owners (Join-Path $folder 'planejar-lotes.prompt.md') 'PROMPT'
            $evidence=@{}
            foreach ($file in $r.Consolidated.Files) {
                Assert-TransferRelativePath $file.RelativePath
                $path=Get-TransferCanonicalPath (Join-Path $folder $file.RelativePath)
                Assert-TransferChild $path $folder
                if ($evidence.ContainsKey($path) -or -not $files.ContainsKey($path) -or $files[$path].Sha256 -ine $file.Sha256) { throw 'Evidencia duplicada, ausente ou divergente do inventario.' }
                $evidence[$path]=$true; Add-TransferOwner $owners $path 'EVIDENCE'
            }
            foreach ($path in @($r.FichaPath,$r.EvidenceIndexPath)+@($r.EvidenceInputs | Where-Object Status -eq 'DISPONIVEL' | ForEach-Object Path)) {
                if (-not $evidence.ContainsKey((Get-TransferCanonicalPath $path))) { throw 'Referencia fora das evidencias consolidadas.' }
            }
            if ($r.PlanningBasis -eq 'MTA' -and -not $evidence.ContainsKey((Get-TransferCanonicalPath $r.Consolidated.MtaIssuePath))) { throw 'Recorte MTA ausente.' }
        } else {
            foreach ($pair in @(@('ContextPath','context.json','CONTEXT'),@('RankingPath','priorizacao.md','RANKING'),@('PromptPath','priorizar-issues.prompt.md','PROMPT'))) {
                if ((Get-TransferCanonicalPath $r.($pair[0])) -ine (Join-Path $folder $pair[1])) { throw 'Destino nao canonico da analise.' }
                Add-TransferOwner $owners $r.($pair[0]) $pair[2]
            }
            foreach ($project in $r.Projects) {
                if (-not $projectMap.ContainsKey((Get-TransferCanonicalPath $project.Source))) { throw 'Projeto da analise fora do pacote.' }
                foreach ($file in $project.Mta.IncidentEvidence.Files) {
                    Assert-TransferChild $file.Path $folder
                    if ($files[(Get-TransferCanonicalPath $file.Path)].Sha256 -ine $file.Sha256) { throw 'Incidente divergente do recibo.' }
                    Add-TransferOwner $owners $file.Path 'INCIDENT'
                }
            }
            $ranking=$files[(Get-TransferCanonicalPath $r.RankingPath)]
            $matches=[regex]::Matches((Read-TransferText $Archive $ranking.Entry),'(?s)<!-- priorizacao:resultado -->\s*```json\s*(.*?)\s*```\s*<!-- /priorizacao:resultado -->')
            if ($matches.Count -ne 1) { throw 'Ranking recebido sem resultado unico.' }
            $result=$matches[0].Groups[1].Value | ConvertFrom-Json
            if ($result.RequestId -cne $r.RequestId -or $result.Status -cne 'COMPLETED' -or @($result.AnalyzedIssues).Count -ne $r.SliceSize) { throw 'Ranking recebido incompleto/divergente.' }
            $examined=@{}
            foreach ($issue in $result.AnalyzedIssues) {
                $key=Get-PrioritizationIssueKey $issue
                if ($examined.ContainsKey($key) -or -not @($r.AvailableIssues | Where-Object { (Get-PrioritizationIssueKey $_) -ceq $key }).Count) { throw 'Exame duplicado/fora do recorte.' }
                $examined[$key]=$true
                $ficha=@($r.FichaPaths | Where-Object { (Get-PrioritizationIssueKey $_) -ceq $key })
                if ($ficha.Count -ne 1) { throw 'Ficha examinada ausente/ambigua.' }
                Add-TransferOwner $owners $ficha[0].Path 'FICHA'
                $file=$files[(Get-TransferCanonicalPath $ficha[0].Path)]
                $identity=[regex]::Matches((Read-TransferText $Archive $file.Entry),'<!-- issue: (\{[^\r\n]+\}) -->')
                if ($identity.Count -ne 1 -or (Get-PrioritizationIssueKey ($identity[0].Groups[1].Value | ConvertFrom-Json)) -cne $key) { throw 'Identidade da ficha diverge do exame.' }
            }
            foreach ($issue in $result.ProposedIssues) { if (-not $examined.ContainsKey((Get-PrioritizationIssueKey $issue))) { throw 'Proposta sem exame.' } }
        }
        if ($r.Previous -and ($Manifest.Kind -eq 'PLANEJAMENTO' -or $r.Mode -eq 'Continue')) {
            $parent=@($Records | Where-Object { $_.Record.RequestId -ceq $r.Previous.RequestId })
            if ($parent.Count -ne 1) { throw 'Previous ausente/ambiguo.' }
            $fields=if ($Manifest.Kind -eq 'PLANEJAMENTO') { @('Context','Plan','Todo') } else { @('Ranking') }
            foreach ($field in $fields) {
                $path=Get-TransferCanonicalPath $parent[0].Record.($field+'Path')
                if (($Manifest.Kind -eq 'PLANEJAMENTO' -and (Get-TransferCanonicalPath $r.Previous.($field+'Path')) -ine $path) -or ($r.Previous.($field+'Sha256') -and $r.Previous.($field+'Sha256') -ine $files[$path].Sha256)) { throw 'Previous alterado ou com destino divergente.' }
            }
            if ($Manifest.Kind -eq 'ANALISE') {
                $p=$parent[0].Record
                if ($p.SequenceId -cne $r.SequenceId -or $p.Category -cne $r.Category -or (Get-PrioritizationScope $p.Projects) -cne (Get-PrioritizationScope $r.Projects)) { throw 'Cadeia recebida mistura sequencia/categoria/escopo.' }
                $text=Read-TransferText $Archive $files[(Get-TransferCanonicalPath $p.RankingPath)].Entry
                $result=[regex]::Match($text,'(?s)<!-- priorizacao:resultado -->\s*```json\s*(.*?)\s*```\s*<!-- /priorizacao:resultado -->').Groups[1].Value | ConvertFrom-Json
                $expected=@(foreach ($issue in $result.AnalyzedIssues) {
                    $ficha=@($p.FichaPaths | Where-Object { $_.Source -ieq $issue.Source -and $_.Id -ceq $issue.Id })[0]
                    [pscustomobject]@{Source=$issue.Source;Id=$issue.Id;Path=$ficha.Path;Sha256=$files[(Get-TransferCanonicalPath $ficha.Path)].Sha256}
                })
                if ((ConvertTo-Json -InputObject $expected -Compress) -cne (ConvertTo-Json -InputObject @($r.Previous.FichaHashes) -Compress)) { throw 'Fichas Previous alteradas no pacote recebido.' }
            }
        }
    }
    foreach ($run in $Manifest.MtaRuns) {
        if ($Manifest.Kind -ne 'ANALISE' -or -not @($Records | Where-Object { @($_.Record.Projects | Where-Object { $_.Mta.Run -ieq $run.OriginPath -and $_.Mta.RunId -ceq $run.RunId }).Count }).Count) { throw 'Rodada sem vinculo com a analise.' }
        $runRoot=(Get-TransferCanonicalPath $run.OriginPath)+'\'
        foreach ($file in $Manifest.Files) {
            $path=Get-TransferCanonicalPath $file.OriginPath
            if ($file.Role -ne 'MTA' -or -not $path.StartsWith($runRoot,[StringComparison]::OrdinalIgnoreCase)) { continue }
            $relative=$path.Substring($runRoot.Length).Replace('\','/')
            Assert-TransferRelativePath $relative
            if ($relative -notmatch '^(manifest\.json|result\.json|(?:input|rules|output)/.+)$') { throw 'Arquivo fora do diagnostico compartilhavel.' }
            Add-TransferOwner $owners $path 'MTA'
        }
    }
    foreach ($file in $Manifest.Files) {
        $path=Get-TransferCanonicalPath $file.OriginPath
        if (-not $owners.ContainsKey($path) -or $owners[$path] -cne $file.Role) { throw 'Arquivo sem vinculo/papel valido no contexto recebido.' }
    }
}
