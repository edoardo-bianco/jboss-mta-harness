function ConvertTo-ProjectCell {
    param([string]$Text)
    $Text.Replace('&','&amp;').Replace('|','&#124;').Replace('<','&lt;').Replace('>','&gt;').Replace('[','&#91;').Replace(']','&#93;') -replace '[\r\n]+',' '
}

function Find-ProjectManagedBlock {
    param([string]$Text,[string]$Name)
    $start='<!-- '+$Name+':inicio -->'; $end='<!-- '+$Name+':fim -->'
    $starts=[regex]::Matches($Text,[regex]::Escape($start)).Count
    $ends=[regex]::Matches($Text,[regex]::Escape($end)).Count
    $matches=[regex]::Matches($Text,('(?s)'+[regex]::Escape($start)+'.*?'+[regex]::Escape($end)))
    if ($starts -eq 0 -and $ends -eq 0) { return $null }
    if ($starts -ne 1 -or $ends -ne 1 -or $matches.Count -ne 1) { throw "Bloco $Name ambiguo ou incompleto; preserve e confira o documento." }
    $matches[0]
}

function Set-ProjectManagedBlock {
    param([string]$Text,[string]$Name,[string]$Content)
    $start='<!-- '+$Name+':inicio -->'; $end='<!-- '+$Name+':fim -->'
    $found=Find-ProjectManagedBlock $Text $Name
    $block=$start+"`n"+$Content+"`n"+$end
    if (-not $found) { return $Text.TrimEnd()+"`n`n"+$block+"`n" }
    $Text.Substring(0,$found.Index)+$block+$Text.Substring($found.Index+$found.Length)
}

function Read-ProjectDecisionRows {
    param([string]$Text)
    $block=Find-ProjectManagedBlock $Text 'mta'
    if (-not $block) { throw 'Registro exige um bloco de issues unico; confira os marcadores mta:inicio/fim.' }
    $seen=New-Object 'Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
    foreach ($line in ($block.Value -split '\r?\n')) {
        if (-not $line.StartsWith('|') -or $line -match '^\|\s*ID\s*\|\s*Issue\s*\|' -or $line -match '^\|(?:\s*:?-+:?\s*\|)+\s*$') { continue }
        $raw=@($line.Trim().Trim('|').Split('|') | ForEach-Object { $_.Trim() })
        $cells=@($raw | ForEach-Object { [Net.WebUtility]::HtmlDecode($_) })
        if ($cells.Count -ne 8 -or -not $cells[0] -or -not $seen.Add($cells[0])) { throw 'Tabela de decisoes invalida/duplicada; preserve o registro e corrija a linha.' }
        [pscustomobject]@{Id=$cells[0];Title=$cells[1];Category=$cells[2];Count=$cells[3];Presence=$cells[4];Decision=$cells[5];Progress=$cells[6];Note=$raw[7]}
    }
}

function Get-HarnessProjectDecisions {
    param($Project)
    $documents=Read-HarnessProjectFiles $Project @('migracao.md')
    if (-not $documents['migracao.md']) { throw 'Registro migracao.md ausente; atualize o indice dos projetos.' }
    Read-ProjectDecisionRows $documents['migracao.md']
}

function Get-HarnessProjectMigrationText {
    param($Project,$Mta,[string]$Text,[switch]$UpdateIssues)
    $migration=$Text
    if (-not $migration) {
        $migration="# Migracao: $($Project.Name)`n`nEdite Decisao, Andamento e Observacao. ANALISAR AGORA seleciona uma issue para planejamento; ADIAR e FORA DO ESCOPO exigem justificativa. Categoria e testes nao concedem GO ou aceite. Issues manuais usam ID DEV-... e categoria manual.`n`n## Direcionamento humano`n`nRegistre objetivo, escopo e decisoes aqui.`n`n<!-- mta:inicio -->`n| ID | Issue | Categoria | Ocorrencias | Presenca | Decisao | Andamento | Observacao/referencia |`n| --- | --- | --- | --- | --- | --- | --- | --- |`n<!-- mta:fim -->`n"
    }
    if ($UpdateIssues -and $Mta) {
        $rows=New-Object 'Collections.Generic.Dictionary[string,object]' ([StringComparer]::Ordinal)
        foreach ($row in @(Read-ProjectDecisionRows $migration)) {
            if ($row.Presence -ne 'MANUAL') { $row.Presence='NAO REENCONTRADA' }
            $rows.Add($row.Id,$row)
        }
        foreach ($issue in $Mta.Issues) {
            if ($rows.ContainsKey($issue.Id)) {
                $row=$rows[$issue.Id]; $row.Title=$issue.Title; $row.Category=$issue.Category; $row.Count=[string]$issue.Count; $row.Presence='PRESENTE'
            } else { $rows.Add($issue.Id,[pscustomobject]@{Id=$issue.Id;Title=$issue.Title;Category=$issue.Category;Count=[string]$issue.Count;Presence='PRESENTE';Decision='A DEFINIR';Progress='NAO ANALISADA';Note=''}) }
        }
        $lines=@('| ID | Issue | Categoria | Ocorrencias | Presenca | Decisao | Andamento | Observacao/referencia |','| --- | --- | --- | --- | --- | --- | --- | --- |')
        foreach ($row in $rows.Values) {
            $fields=@($row.Id,$row.Title,$row.Category,$row.Count,$row.Presence,$row.Decision,$row.Progress | ForEach-Object { ConvertTo-ProjectCell ([string]$_) })
            # Note may contain human Markdown links. Preserve them verbatim.
            $lines+='| '+(($fields+@($row.Note)) -join ' | ')+' |'
        }
        $migration=Set-ProjectManagedBlock $migration 'mta' ($lines -join "`n")
    }
    if ($Mta -or -not $Text) {
        $refs=@((Get-HarnessSourceLink $Project.MigrationPath $Project.Pom 'POM'),(Get-HarnessSourceLink $Project.MigrationPath $Project.Source 'Codigo local'))
        if ($Mta) { $refs+=Get-HarnessSourceLink $Project.MigrationPath $Mta.ReportPath 'MTA atual' }
        $migration=Set-ProjectManagedBlock $migration 'fontes' ($refs -join ' | ')
    }
    $migration
}

function Update-HarnessProjectDocuments {
    param($Project,$Mta,[switch]$UpdateIssues,[string[]]$Warnings=@())
    $old=Read-HarnessProjectFiles $Project @('migracao.md','indice.md','atual/operacao.json')
    $migration=Get-HarnessProjectMigrationText $Project $Mta $old['migracao.md'] -UpdateIssues:$UpdateIssues
    $lines=@('# Projeto: '+$Project.Name,'', (Get-HarnessSourceLink $Project.IndexPath $Project.Pom 'POM'),(Get-HarnessSourceLink $Project.IndexPath $Project.MigrationPath 'Decisoes de migracao'))
    foreach ($entry in @(@('atual/planejamento/plano.md','Plano corrente'),@('atual/planejamento/tarefas.md','Tarefas correntes'),@('atual/planejamento/contexto.json','Contexto corrente'),@('atual/build/resultado.json','Ultimo build'),@('atual/diagnosticos/sonar/resultado.json','Sonar atual'),@('reconciliado/resultado.md','Ultima reconciliacao'))) {
        $path=Join-Path $Project.Folder $entry[0]
        if (Test-Path -LiteralPath $path -PathType Leaf) { $lines+=Get-HarnessSourceLink $Project.IndexPath $path $entry[1] }
    }
    if ($Mta) { $lines+=@('',(Get-HarnessSourceLink $Project.IndexPath $Mta.ReportPath 'MTA atual'),'Consultar diagnostico nao reconcilia decisoes nem concede GO.'); $Warnings+=@($Mta.Diagnostics) }
    if ($old['atual/operacao.json']) { $lines+=@('',(Get-HarnessSourceLink $Project.IndexPath (Join-Path $Project.Folder 'atual/operacao.json') 'Situacao das operacoes')) }
    if ($Warnings.Count) { $lines+=@('','Limites da leitura:')+@($Warnings | ForEach-Object { '- '+(ConvertTo-ProjectCell $_) }) }
    $writes=@{'indice.md'=($lines -join "`n")+"`n"}
    if ($migration -cne $old['migracao.md']) { $writes['migracao.md']=$migration }
    Publish-HarnessProjectFiles $Project $writes @{'migracao.md'=$old['migracao.md'];'indice.md'=$old['indice.md']}
}
