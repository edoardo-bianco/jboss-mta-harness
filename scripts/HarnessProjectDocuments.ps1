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
    $guide=Join-Path (Split-Path -Parent $PSScriptRoot) 'doc/guias/tools/priorizacao-issues.md'
    $guideLinks=(Get-HarnessSourceLink $Project.MigrationPath $guide 'Como preencher e usar a ficha')+' | '+
        (Get-HarnessSourceLink $Project.MigrationPath (Get-HarnessDocumentTemplatePath 'ficha-issue') 'Modelo da ficha')
    $orientation=(Expand-HarnessDocumentTemplate 'orientacao-registro' @{GuideLinks=$guideLinks}).TrimEnd()
    $migration=$Text
    if (-not $migration) {
        $migration=Expand-HarnessDocumentTemplate 'migracao' @{Project=(ConvertTo-ProjectCell $Project.Name);Orientation=$orientation}
    }
    $migration=Set-ProjectManagedBlock $migration 'registro:orientacao' $orientation
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
    $refs=@((Get-HarnessSourceLink $Project.MigrationPath $Project.Pom 'POM'),(Get-HarnessSourceLink $Project.MigrationPath $Project.Source 'Codigo local'))
    if ($Mta) { $refs+=Get-HarnessSourceLink $Project.MigrationPath $Mta.ReportPath 'MTA atual' }
    $migration=Set-ProjectManagedBlock $migration 'fontes' ($refs -join ' | ')
    $migration
}

function Get-ProjectOperationsText {
    param([string]$Json)
    $operations=ConvertFrom-Json $Json
    $lines=@('## Situacao das operacoes','')
    foreach ($entry in $operations.PSObject.Properties) {
        $state=$entry.Value
        $lines+='- '+(ConvertTo-ProjectCell $entry.Name)+': '+(ConvertTo-ProjectCell $state.Status)+' ('+(ConvertTo-ProjectCell $state.DateUtc)+'). '+(ConvertTo-ProjectCell $state.Error)
    }
    $lines -join [Environment]::NewLine
}

function Update-HarnessProjectDocuments {
    param($Project,$Mta,[switch]$UpdateIssues,[string[]]$Warnings=@(),[Collections.IDictionary]$Expected=@{})
    $old=Read-HarnessProjectFiles $Project @('migracao.md','indice.md','atual/operacao.json','projeto.json')
    foreach ($key in $Expected.Keys) {
        if (-not $old.Contains($key) -or $old[$key] -cne $Expected[$key]) { throw 'Associacao editada desde a leitura do MTA; preserve os documentos e atualize novamente o indice.' }
    }
    $migration=Get-HarnessProjectMigrationText $Project $Mta $old['migracao.md'] -UpdateIssues:$UpdateIssues
    $lines=@()
    foreach ($entry in @(
        @('atual/planejamento/plano.md','Plano corrente'),
        @('atual/planejamento/tarefas.md','Tarefas correntes'),
        @('atual/planejamento/planejar-lotes.prompt.md','Orientacao do planejamento'),
        @('evidencias/LEIA-ME.md','Evidencias e anexos do projeto'),
        @('atual/build/console.log','Log da ultima tentativa de build'),
        @('atual/jboss/eap71/ultimo-deploy.json','Ultimo deploy JBoss EAP 7.0/7.1'),
        @('atual/jboss/eap74/ultimo-deploy.json','Ultimo deploy JBoss EAP 7.4'),
        @('atual/diagnosticos/mta-console.log','Log da ultima tentativa MTA'),
        @('atual/diagnosticos/mta-interno.log','Log interno da ultima tentativa MTA'),
        @('atual/diagnosticos/sonar/RESUMO.md','Relatorio Sonar atual'),
        @('atual/diagnosticos/sonar-console.log','Log da ultima tentativa Sonar'),
        @('reconciliado/resultado.md','Ultima reconciliacao'))) {
        $path=Join-Path $Project.Folder $entry[0]
        if (Test-Path -LiteralPath $path -PathType Leaf) { $lines+='- '+(Get-HarnessSourceLink $Project.IndexPath $path $entry[1]) }
    }
    $mtaText=''
    if ($Mta) {
        $mtaText=(Get-HarnessSourceLink $Project.IndexPath $Mta.ReportPath 'MTA atual')+[Environment]::NewLine+'Consultar diagnostico nao reconcilia decisoes nem concede GO.'
        $Warnings+=@($Mta.Diagnostics)
    }
    $values=@{
        Project=(ConvertTo-ProjectCell $Project.Name)
        Pom=(Get-HarnessSourceLink $Project.IndexPath $Project.Pom 'POM')
        Source=(Get-HarnessSourceLink $Project.IndexPath $Project.Source 'Codigo local')
        Migration=(Get-HarnessSourceLink $Project.IndexPath $Project.MigrationPath 'Decisoes de migracao')
        Documents=($lines -join [Environment]::NewLine)
        Mta=$mtaText
        Operations=if ($old['atual/operacao.json']) { Set-ProjectManagedBlock '' 'operacoes' (Get-ProjectOperationsText $old['atual/operacao.json']) } else { '' }
        Warnings=if ($Warnings.Count) { 'Limites da leitura:'+[Environment]::NewLine+(@($Warnings | ForEach-Object { '- '+(ConvertTo-ProjectCell $_) }) -join [Environment]::NewLine) } else { '' }
    }
    $writes=@{'indice.md'=(Expand-HarnessDocumentTemplate 'indice-projeto' $values)}
    if ($migration -cne $old['migracao.md']) { $writes['migracao.md']=$migration }
    Publish-HarnessProjectFiles $Project $writes $old
}

function Get-HarnessTemplateLinks {
    param([string]$From,[string[]]$Names)
    if ('migracao' -in $Names -and 'orientacao-registro' -notin $Names) { $Names+='orientacao-registro' }
    $lines=@('## Modelos de saida obrigatorios','','Leia os modelos vinculados antes de escrever. Use suas secoes e blocos; preencha com evidencias reais, sem placeholders restantes. Preserve texto humano existente. Template ausente e lacuna a resolver; nao improvise outro formato.','')
    foreach ($name in $Names) { $lines+='- '+(Get-HarnessSourceLink $From (Get-HarnessDocumentTemplatePath $name) ($name+'.template.md')) }
    $lines -join [Environment]::NewLine
}
