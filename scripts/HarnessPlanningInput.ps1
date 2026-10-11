# Leitores ainda usados por reconciliacao/consultas/sprints legados (S13-S16).
# A preparacao corrente usa HarnessPlanningCurrent e HarnessIssuePlanning.
function Read-HarnessMigrationInput {
    param([string]$Root, $Project, [string]$MigrationPath,
        [scriptblock]$PathResolver={param($p,$r) Resolve-HarnessPath $p $r})
    $paths = Get-HarnessMigrationPaths $Root $Project -PathResolver $PathResolver
    if ($MigrationPath -and (& $PathResolver $MigrationPath $Root) -ine $paths.MigrationPath) {
        throw 'MigrationPath nao corresponde ao registro deste projeto no indice local.'
    }
    if (-not (Test-Path -LiteralPath $paths.MigrationPath -PathType Leaf)) {
        throw 'Registro ausente. Execute Workspace: atualizar indice dos projetos; escolha as issues no registro e volte a Planejamento: planejar.'
    }
    $text = [IO.File]::ReadAllText($paths.MigrationPath)
    $source = [regex]::Matches($text, '(?m)^Source:\s*([^\r\n]+)')
    $identity = [regex]::Matches($text, '(?m)^Project:\s*([^\r\n]+)')
    if ($source.Count -ne 1 -or $identity.Count -ne 1 -or
        (& $PathResolver $source[0].Groups[1].Value.Trim() $Root) -ine $Project.path) {
        throw 'Identidade/Source do registro ambiguo ou divergente; confira o registro antes de planejar.'
    }
    $blocks = [regex]::Matches($text, '(?s)<!-- mta:inicio -->.*?<!-- mta:fim -->')
    if ($blocks.Count -ne 1) { throw 'Registro sem bloco de issues unico; reconciliar este formato antes de planejar.' }
    $seen = @{}
    $rows = @(foreach ($line in ($blocks[0].Value -split '\r?\n')) {
        if ($line -notmatch '^\|' -or $line -match '^\| (ID \(|---)') { continue }
        $cells = @($line.Trim().Trim('|').Split('|') | ForEach-Object { $_.Trim() })
        if ($cells.Count -ne 8 -or -not $cells[0] -or $seen.ContainsKey($cells[0])) { throw 'Tabela de issues invalida ou ID duplicado; preserve as escolhas e corrija o registro.' }
        if ($cells[5] -notin @('A DEFINIR','ANALISAR AGORA','ADIAR','FORA DO ESCOPO') -or
            $cells[6] -notin @('NAO ANALISADA','ANALISADA','PLANEJADA','IMPLEMENTADA','VERIFICADA')) {
            throw "Campos invalidos em $($cells[0]): ANALISAR AGORA pertence a Decisao, nao a Andamento."
        }
        if ($cells[4] -notin @('PRESENTE','NAO REENCONTRADA','MANUAL')) { throw "Presenca invalida em $($cells[0])." }
        $seen[$cells[0]] = $true
        [pscustomobject]@{Id=$cells[0];Title=$cells[1];Category=$cells[2];Count=$cells[3];Presence=$cells[4];Decision=$cells[5];Progress=$cells[6];Observation=$cells[7]}
    })
    $origins = [regex]::Matches($blocks[0].Value, '(?m)^<!-- MTA (\{[^\r\n]+\}) -->\s*$')
    if ($origins.Count -gt 1) { throw 'Origem MTA ambigua no registro; reconciliar a origem antes de planejar.' }
    $markerCount=[regex]::Matches($blocks[0].Value,'(?i)<!--\s*MTA(?=\s|\{)').Count
    if ($markerCount -ne $origins.Count -or (-not $origins.Count -and $blocks[0].Value -match 'Rodada MTA:')) { throw 'Origem MTA incompleta ou malformada no registro; nao converter silenciosamente para evidencias.' }
    $origin = if ($origins.Count) { $origins[0].Groups[1].Value | ConvertFrom-Json } else { $null }
    $warnings = @()
    if ($identity[0].Groups[1].Value.Trim() -cne $Project.name) { $warnings += 'Project textual difere do identificador atual; Source confere. Confira o nome ao revisar o registro.' }
    [pscustomobject]@{MigrationPath=$paths.MigrationPath;EvidenceIndexPath=$paths.EvidenceIndexPath;Text=$text;Rows=$rows;Origin=$origin;Warnings=$warnings}
}

function Get-HarnessPlanningEvidenceInputs {
    param([string]$Root, $Register, [string]$EvidenceIndexPath)
    $references = @()
    if ($EvidenceIndexPath -and (Test-Path -LiteralPath $EvidenceIndexPath -PathType Leaf)) {
        $references += [pscustomobject]@{Value=$EvidenceIndexPath;Base=$Root;Relation='Indice de evidencias'}
        foreach ($line in ([IO.File]::ReadAllLines($EvidenceIndexPath))) {
            if ($line -notmatch '^\|' -or $line -match '^\|\s*(Arquivo|---)') { continue }
            $cells = @($line.Trim().Trim('|').Split('|') | ForEach-Object { $_.Trim() })
            if ($cells.Count -lt 2 -or -not $cells[0]) { continue }
            $link = [regex]::Match($cells[0], '\[[^\]]*\]\(<?([^>\)]+)>?\)')
            $value = if ($link.Success) { $link.Groups[1].Value } else { $cells[0].Trim('`') }
            $references += [pscustomobject]@{Value=$value;Base=(Split-Path $EvidenceIndexPath -Parent);Relation=$cells[1]}
        }
    }
    # Observacoes podem apontar evidencias sem obrigar o humano a duplicar a lista.
    foreach ($row in @($Register.Rows | Where-Object Decision -eq 'ANALISAR AGORA')) {
        foreach ($link in [regex]::Matches($row.Observation, '\[[^\]]*\]\(<?([^>\)]+)>?\)')) {
            $references += [pscustomobject]@{Value=$link.Groups[1].Value;Base=(Split-Path $Register.MigrationPath -Parent);Relation=$row.Id}
        }
    }
    $seen = @{}
    foreach ($reference in $references) {
        $value = ($reference.Value -split '#',2)[0]
        # Planos sao entradas mutaveis proprias, nao anexos que congelam o GO.
        if (-not $value -or $value -match '(?:^|[\\/])(plan|todo|contexto?)(?:-[^\\/]*)?\.(md|json)$') { continue }
        $path = $value
        $status = 'REFERENCIA EXTERNA'; $hash = $null
        if ($value -notmatch '^https?://') {
            $path = Resolve-HarnessPath ([Uri]::UnescapeDataString($value)) $reference.Base
            $status = 'AUSENTE'
            if (Test-Path -LiteralPath $path -PathType Leaf) { $hash=(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash; $status='DISPONIVEL' }
        }
        if ($seen.ContainsKey($path)) { continue }; $seen[$path]=$true
        [pscustomobject]@{Path=$path;Reference=$reference.Value;Relation=$reference.Relation;Status=$status;Sha256=$hash}
    }
}
