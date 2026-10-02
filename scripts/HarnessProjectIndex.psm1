#requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'Harness.psm1') -DisableNameChecking

function ConvertTo-IndexText {
    param([string]$Text)
    $Text.Replace('&','&amp;').Replace('<','&lt;').Replace('>','&gt;').Replace('|','&#124;').Replace('[','&#91;').Replace(']','&#93;') -replace '[\r\n]+',' '
}

function New-IndexLink {
    param([string]$Text, [string]$Path, [string]$Directory)
    $baseUri = [Uri]($Directory.TrimEnd([char[]]'\/') + '\')
    $relative = $baseUri.MakeRelativeUri([Uri]$Path).ToString()
    '[' + (ConvertTo-IndexText $Text) + '](<' + $relative + '>)'
}

function Read-IndexRecords {
    param([string]$Root, [string]$Area, [Collections.Generic.List[string]]$Warnings, [string[]]$AdditionalRuns = @())
    $base = Join-Path $Root ('.harness/' + $Area)
    $folders = @(if (Test-Path -LiteralPath $base) { $base })
    $depth = if ($Area -eq 'planning') { 3 } else { 2 }
    for ($level = 0; $level -lt $depth; $level++) {
        $folders = @(foreach ($folder in $folders) {
            if ((Get-Item -LiteralPath $folder -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) {
                $Warnings.Add("Link ignorado: $folder"); continue
            }
            Get-ChildItem -LiteralPath $folder -Directory -Force | Select-Object -ExpandProperty FullName
        })
    }
    $folders = @($folders) + @($AdditionalRuns)
    foreach ($folder in ($folders | Select-Object -Unique)) {
        $receipt = Join-Path $folder $(if ($Area -eq 'planning') { 'context.json' } elseif ($Area -eq 'runs') { 'manifest.json' } else { 'result.json' })
        $bucket = Split-Path -Parent $folder
        $action = $Area
        if ($Area -eq 'planning') {
            $action = if ((Split-Path -Leaf $bucket) -eq 'registro') { 'migration-register' } else { 'application-remediation' }
            $bucket = Split-Path -Parent $bucket
        }
        $source = $null; $data = $null; $date = [DateTimeOffset]::MinValue; $id = ''; $status = 'NAO VERIFICADO'; $problem = $null
        # A data do nome permite ordenar uma rodada recente mesmo com recibo ausente.
        $stamp = [regex]::Match((Split-Path -Leaf $folder), '^(?:mta|build|plano|sonar)_(\d{4}-\d{2}-\d{2})_(\d{2}-\d{2}-\d{2})([+-]\d{4})__')
        if ($stamp.Success) {
            try { $date = [DateTimeOffset]::Parse($stamp.Groups[1].Value + 'T' + $stamp.Groups[2].Value.Replace('-',':') + $stamp.Groups[3].Value.Insert(3,':')) } catch { }
        }
        try {
            if ((Get-Item -LiteralPath $folder -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Link ignorado.' }
            if ($Area -eq 'runs') {
                $location = Join-Path $folder 'location.json'
                if (Test-Path -LiteralPath $location -PathType Leaf) {
                    $receipt = $location
                    $reference = Get-Content -LiteralPath $location -Raw -Encoding UTF8 | ConvertFrom-Json
                    $source = Resolve-HarnessPath $reference.Source $Root
                    $id = [string]$reference.RunId
                }
                $run = Resolve-HarnessMtaRunDirectory $folder $Root
                $receipt = Join-Path $run 'manifest.json'
            }
            $data = Get-Content -LiteralPath $receipt -Raw -Encoding UTF8 | ConvertFrom-Json
            $source = Resolve-HarnessPath $data.Source $Root
            if (-not $source) { throw 'Source ausente.' }
            if ($Area -eq 'planning') {
                if ($data.Purpose -notin @('application-remediation','migration-register')) { throw 'Tipo de contexto desconhecido.' }
                $action = $data.Purpose
                $id = [string]$data.RequestId
                $date = [DateTimeOffset]::Parse($data.PreparedAtUtc)
                $hasPlan = Test-Path -LiteralPath (Join-Path $folder 'plan.md') -PathType Leaf
                $hasTodo = Test-Path -LiteralPath (Join-Path $folder 'todo.md') -PathType Leaf
                $status = if ($hasPlan -and $hasTodo) { 'PLANO E TO-DO PRESENTES' } elseif ($hasPlan -or $hasTodo) { 'DOCUMENTOS INCOMPLETOS' } else { 'CONTEXTO PREPARADO' }
            } else {
                $id = [string]$data.RunId
                $date = [DateTimeOffset]::Parse($(if ($Area -eq 'runs') { $data.CreatedAtUtc } else { $data.StartedAtUtc }))
                if ($Area -eq 'runs') {
                    $receipt = Join-Path (Split-Path $receipt -Parent) 'result.json'
                    $result = Get-Content -LiteralPath $receipt -Raw -Encoding UTF8 | ConvertFrom-Json
                    if ($result.RunId -cne $data.RunId -or $result.Project -cne $data.Project) { throw 'Resultado MTA divergente do manifesto.' }
                    $status = [string]$result.Status
                } else { $status = [string]$data.Status }
                if (-not $status) { throw 'Status ausente.' }
                if ($Area -eq 'sonar') { $status += ' / ' + $data.Phase }
            }
            if (-not $id) { throw 'ID ausente.' }
        } catch {
            $status = 'NAO VERIFICADO'
            $problem = "${Area}: $receipt - $($_.Exception.Message)"
        }
        [pscustomobject]@{Area=$Area;Action=$action;Bucket=$bucket;Source=$source;Id=$id;Date=$date;Status=$status;Path=$receipt;Problem=$problem}
    }
}

function Select-IndexLatest {
    param([object[]]$Records, $Context, [Collections.Generic.List[string]]$Warnings)
    foreach ($record in $Records) {
        if ($record.Source) { continue }
        $folderName = Split-Path -Leaf $record.Bucket
        $matches = @($Context.Projects | Where-Object {
            $folderName -ieq $_.name -or $folderName.EndsWith(('__' + (Get-HarnessProjectKey $_.name)), [StringComparison]::OrdinalIgnoreCase)
        })
        if ($matches.Count -eq 1) { $record.Source = $matches[0].path; continue }
        $siblings = @($Records | Where-Object { $_.Bucket -eq $record.Bucket -and $_.Source } | Select-Object -ExpandProperty Source -Unique)
        if ($siblings.Count -eq 1) { $record.Source = $siblings[0] }
    }
    $sources = @($Context.Projects | ForEach-Object { $_.path })
    foreach ($group in ($Records | Where-Object { $_.Source -in $sources } | Group-Object Source,Area,Action)) {
        # Sem data confiavel, nao fingir que um sucesso anterior representa a ultima acao.
        $latest = @($group.Group | Sort-Object @{Expression={ $_.Date -eq [DateTimeOffset]::MinValue };Descending=$true}, @{Expression='Date';Descending=$true}, @{Expression='Id';Descending=$true})[0]
        if ($latest.Problem) { $Warnings.Add($latest.Problem) }
        $latest
    }
    foreach ($record in ($Records | Where-Object { -not $_.Source -and $_.Problem })) {
        $Warnings.Add('Nao foi possivel identificar projeto/data para selecionar a ultima acao: ' + $record.Problem)
    }
}

function Read-IndexMigration {
    param([string]$Root, $Project, [Collections.Generic.List[string]]$Warnings)
    $base = Join-Path $Root '.harness/projetos'
    $key = Get-HarnessProjectKey ((Resolve-HarnessPath $Project.path $Root).ToLowerInvariant())
    $matches = @(if (Test-Path -LiteralPath $base) { Get-ChildItem -LiteralPath $base -Directory | Where-Object Name -Like "*__$key" })
    $summary = [pscustomobject]@{Path=$null;Status='NAO GERADO';Counts='';Decisions='';Progress='';RunId='';Issues=0;Occurrences=0;ActiveRows=@();Reconciliation='NAO PREPARADA';ReconciliationId=''}
    if (-not $matches.Count) { return $summary }
    try {
        if ($matches.Count -ne 1) { throw 'Registro ambiguo.' }
        if ($matches[0].Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Link de registro ignorado.' }
        $summary.Path = Resolve-HarnessPath (Resolve-HarnessMigrationPath $matches[0].FullName) $Root
        if (-not (Test-Path -LiteralPath $summary.Path -PathType Leaf)) { $summary.Path = $null; return $summary }
        $text = [IO.File]::ReadAllText($summary.Path)
        $reconciliation = [regex]::Matches($text, '(?s)<!-- reconciliacao:inicio -->.*?<!-- reconciliacao:fim -->')
        if ($reconciliation.Count) {
            $state = [regex]::Match($reconciliation[0].Value, '(?m)^Estado: (PENDENTE|CONCLUIDA)\s*$')
            $request = [regex]::Match($reconciliation[0].Value, '(?m)^Solicitacao: ([a-f0-9]{32})\s*$')
            if ($reconciliation.Count -ne 1 -or -not $state.Success -or -not $request.Success) { throw 'Secao de reconciliacao invalida ou ambigua.' }
            $summary.Reconciliation = $state.Groups[1].Value
            $summary.ReconciliationId = $request.Groups[1].Value
        }
        $blocks = [regex]::Matches($text, '(?s)<!-- mta:inicio -->.*?<!-- mta:fim -->')
        if ($blocks.Count -ne 1) { throw 'Bloco de issues ausente ou ambiguo.' }
        $rows = @(); $ids = @{}
        foreach ($line in ($blocks[0].Value -split '\r?\n')) {
            if ($line -match '^\| ID \(' -or $line -match '^\| ---' -or $line -match '^(<!--|AGUARDANDO MTA|Rodada MTA:|Total MTA:|\s*$)') { continue }
            $cells = @($line.Trim().Trim('|').Split('|') | ForEach-Object { $_.Trim() })
            if (-not $line.StartsWith('|') -or $cells.Count -ne 8 -or -not $cells[0] -or $ids.ContainsKey($cells[0])) { throw 'Tabela invalida ou ID duplicado.' }
            if ($cells[4] -notin @('PRESENTE','NAO REENCONTRADA','MANUAL')) { throw 'Presenca desconhecida.' }
            $ids[$cells[0]] = $true
            $rows += [pscustomobject]@{Presence=$cells[4];Count=$cells[3];Decision=$cells[5];Progress=$cells[6]}
        }
        $runMatch = [regex]::Match($blocks[0].Value, 'Rodada MTA: ([a-f0-9]{32})')
        $summary.RunId = $runMatch.Groups[1].Value
        $summary.Status = if ($runMatch.Success) { 'CATALOGO CARREGADO' } else { 'AGUARDANDO MTA' }
        $present = @($rows | Where-Object Presence -eq 'PRESENTE')
        [long]$occurrences = 0
        foreach ($row in $present) {
            [long]$count = 0
            if (-not [long]::TryParse($row.Count, [ref]$count) -or $count -lt 0) { throw 'Contagem invalida.' }
            $occurrences += $count
        }
        $summary.Counts = "$($present.Count) issues presentes / $occurrences ocorrencias; NAO REENCONTRADA: $(@($rows | Where-Object Presence -eq 'NAO REENCONTRADA').Count); MANUAL: $(@($rows | Where-Object Presence -eq 'MANUAL').Count)"
        $summary.Decisions = (@($rows | Group-Object Decision | Sort-Object Name | ForEach-Object { "$($_.Name): $($_.Count)" }) -join '; ')
        $summary.Progress = (@($rows | Group-Object Progress | Sort-Object Name | ForEach-Object { "$($_.Name): $($_.Count)" }) -join '; ')
        $summary.Issues = $present.Count
        $summary.Occurrences = $occurrences
        $summary.ActiveRows = @($rows | Where-Object Presence -ne 'NAO REENCONTRADA')
    } catch { $summary.Status = 'REVISAR REGISTRO'; $Warnings.Add("Registro $($Project.path): $($_.Exception.Message)") }
    $summary
}

function Read-IndexMtaCatalog {
    param([object[]]$Records, [string]$Root, [Collections.Generic.List[string]]$Warnings)
    $summary = [pscustomobject]@{Available=$false;Issues=0;Occurrences=0;Categories='';CategoryCounts=@();Problem=$null}
    if (-not $Records.Count -or $Records[0].Problem -or $Records[0].Status -ne 'SUCCEEDED') { return $summary }
    try {
        $run = Split-Path -Parent $Records[0].Path
        $catalog = @(Get-HarnessMtaCatalog $run $Root)
        [long]$total = 0
        foreach ($issue in $catalog) { $total += $issue.Count }
        $summary.Issues = $catalog.Count
        $summary.Occurrences = $total
        $summary.Categories = (@($catalog | Group-Object Category | Sort-Object Name | ForEach-Object {
            [long]$occurrences = 0
            foreach ($issue in $_.Group) { $occurrences += $issue.Count }
            $summary.CategoryCounts += [pscustomobject]@{Category=$_.Name;Issues=$_.Count;Occurrences=$occurrences}
            "$($_.Name): $($_.Count) issues / $occurrences ocorrencias"
        }) -join '; ')
        $summary.Available = $true
    } catch {
        $summary.Problem = "Catalogo do ultimo MTA ($($Records[0].Id)): $($_.Exception.Message)"
        $Warnings.Add($summary.Problem)
    }
    $summary
}

function Format-IndexCategories {
    param([object[]]$Counts)
    if (-not $Counts.Count) { return 'nenhuma (0 issues)' }
    (@($Counts | Group-Object Category | Sort-Object Name | ForEach-Object {
        [long]$issues = 0; [long]$occurrences = 0
        foreach ($item in $_.Group) { $issues += $item.Issues; $occurrences += $item.Occurrences }
        (ConvertTo-IndexText $_.Name) + ": $issues / $occurrences"
    }) -join '; ')
}

function Format-IndexRecords {
    param([object[]]$Records, [string]$Directory, [switch]$Compact)
    if (-not $Records.Count) { return 'SEM REGISTRO' }
    $latest = @($Records | Sort-Object Date,Id -Descending)[0]
    $date = if ($latest.Date -eq [DateTimeOffset]::MinValue) { 'data indisponivel' } else { $latest.Date.ToString('yyyy-MM-dd HH:mm zzz') }
    if ($Compact) { return (New-IndexLink $latest.Status $latest.Path $Directory) }
    (New-IndexLink ($latest.Status + ' - ' + $date) $latest.Path $Directory) + ' / ID: ' + (ConvertTo-IndexText $latest.Id)
}

function Format-IndexIssueGroups {
    param([object[]]$Rows, [string]$Field)
    if (-not $Rows.Count) { return 'Sem issues registradas' }
    (@($Rows | Group-Object -Property $Field | Sort-Object Name | ForEach-Object {
        $name = if ($_.Name) { $_.Name } else { 'NAO INFORMADO' }
        (ConvertTo-IndexText $name) + ': ' + $_.Count
    }) -join '; ')
}

function Get-IndexNextSteps {
    param($Project)
    $migration = $Project.Migration
    $steps = @()
    $latest = @($Project.Builds) + @($Project.Mta) + @($Project.Plans) + @($Project.Sonar) + @($Project.Maintenance)
    if (@($latest | Where-Object Problem).Count -or $Project.MtaCatalog.Problem -or $migration.Status -eq 'REVISAR REGISTRO') {
        return 'Revisar limites da leitura e registros incompletos'
    }
    if ($Project.Builds.Count -and $Project.Builds[0].Status -ne 'SUCCEEDED') { $steps += 'Conferir ultimo build' }
    if ($Project.Mta.Count -and $Project.Mta[0].Status -ne 'SUCCEEDED') { $steps += 'Conferir ultima execucao MTA' }
    if ($Project.Sonar.Count -and $Project.Sonar[0].Status -notlike 'SUCCEEDED*') { $steps += 'Conferir ultimo Sonar' }
    if ($migration.Reconciliation -eq 'PENDENTE') { return (($steps + 'RECONCILIACAO PENDENTE: executar o prompt indicado antes de considerar decisoes reconciliadas') -join '; ') }
    if ($migration.Status -in @('NAO GERADO','AGUARDANDO MTA')) {
        $steps += 'Preparar planejamento > 2 Manter registro > selecionar MTA concluido; catalogo atualizado sem executar prompt'
    } elseif ($Project.Mta.Count -and $migration.RunId -cne $Project.Mta[0].Id) {
        $steps += 'Conferir rodada MTA do registro; para trocar, Preparar planejamento > 2 Manter registro > selecionar MTA concluido (sem executar prompt)'
    } else {
        $rows = @($migration.ActiveRows)
        $chosen = @($rows | Where-Object Decision -eq 'ANALISAR AGORA')
        if (@($chosen | Where-Object Progress -in @('NAO ANALISADA','ANALISADA')).Count) {
            $steps += 'Planejar issues ANALISAR AGORA; conferir plano existente'
        }
        if (@($chosen | Where-Object Progress -eq 'PLANEJADA').Count) { $steps += 'Revisar plano e confirmar GO humano antes de implementar' }
        if (@($chosen | Where-Object Progress -eq 'IMPLEMENTADA').Count) { $steps += 'Verificar implementacao e registrar evidencias' }
        if (@($rows | Where-Object Decision -eq 'A DEFINIR').Count) { $steps += 'Definir prioridades no registro' }
        if (-not $steps.Count) { $steps += 'Revisar decisoes e evidencias para definir continuidade; aceite humano pendente de conferencia' }
    }
    $steps -join '; '
}

function Get-IndexMigrationComparison {
    param($Project)
    if ($Project.Migration.Status -eq 'REVISAR REGISTRO') { return 'COMPARACAO INDISPONIVEL: revisar registro' }
    if (-not $Project.Mta.Count) {
        if (-not $Project.Migration.RunId) { return 'CATALOGO NAO CARREGADO; SEM MTA LOCALIZADO' }
        return 'SEM MTA LOCALIZADO PARA COMPARAR'
    }
    $latest = $Project.Mta[0]
    if ($latest.Problem) { return 'COMPARACAO INDISPONIVEL: revisar MTA' }
    $comparison = if (-not $Project.Migration.RunId) { 'CATALOGO NAO CARREGADO' }
        elseif ($Project.Migration.RunId -ceq $latest.Id) { 'MESMA RODADA' }
        else { 'RODADA DIFERENTE: conferir selecao' }
    if ($latest.Status -ne 'SUCCEEDED') { return "ULTIMA TENTATIVA $($latest.Status); $comparison" }
    $comparison
}

function Get-IndexReconciliationPrompt {
    param($Project)
    if ($Project.Sync -and $Project.Sync.PromptPath) { return $Project.Sync.PromptPath }
    $maintenance = @($Project.Maintenance | Where-Object Id -eq $Project.Migration.ReconciliationId)
    if ($maintenance.Count) {
        $path = Join-Path (Split-Path -Parent $maintenance[0].Path) 'manter-migracao.prompt.md'
        if (Test-Path -LiteralPath $path -PathType Leaf) { return $path }
    }
}

function Sync-IndexMigration {
    param($Context, $Project, [object[]]$Mta, $Catalog, [Collections.Generic.List[string]]$Warnings)
    $result = [pscustomobject]@{Message='NAO ATUALIZADO: sem MTA reconhecido';PromptPath=$null;ContextPath=$null}
    if (-not $Mta.Count) { return $result }
    if (-not $Catalog.Available) { $result.Message = 'NAO ATUALIZADO: ultimo MTA falhou, e ambiguo ou tem catalogo indisponivel'; return $result }
    try {
        $projectContext = [pscustomobject]@{Root=$Context.Root;Config=$Context.Config;ConfigPath=$Context.ConfigPath;WorkspacePath=$Context.WorkspacePath;Projects=$Context.Projects;Active=$Project}
        $prepared = New-MtaMigrationPrompt $projectContext -RunPath (Split-Path -Parent $Mta[0].Path) -ReuseUnchanged
        $result.PromptPath = $prepared.PromptPath
        $result.ContextPath = $prepared.ContextPath
        $result.Message = if ($prepared.Reused) { 'CATALOGO ATUALIZADO; prompt existente reutilizado' } else { 'CATALOGO ATUALIZADO; novo prompt de reconciliacao preparado' }
    } catch {
        $result.Message = 'ATUALIZACAO INCOMPLETA: ' + $_.Exception.Message
        $Warnings.Add("Registro $($Project.path): $($result.Message)")
    }
    $result
}

function New-HarnessProjectIndex {
    param($Context, [switch]$UpdateMigration)
    if ($UpdateMigration) { Import-Module (Join-Path $PSScriptRoot 'HarnessPlanning.psm1') -DisableNameChecking }
    $warnings = New-Object 'Collections.Generic.List[string]'
    $external = @(Get-HarnessExternalMtaRuns $Context.Root $Context.Config.mta.runsPath -WarningVariable discoveryWarnings -WarningAction SilentlyContinue)
    foreach ($warning in $discoveryWarnings) { $warnings.Add([string]$warning) }
    $sources = @($Context.Projects | ForEach-Object { $_.path })
    $externalPaths = @(foreach ($run in $external) {
        if ($run.Source -in $sources) { $run.Run }
        elseif ($run.Problem) { $warnings.Add($run.Problem) }
    })
    $candidates = @(foreach ($area in @('builds','runs','planning','sonar')) {
        $additional = if ($area -eq 'runs') { $externalPaths } else { @() }
        Read-IndexRecords $Context.Root $area $warnings -AdditionalRuns $additional
    })
    foreach ($invalid in ($external | Where-Object Problem)) {
        foreach ($record in ($candidates | Where-Object { $_.Area -eq 'runs' -and (Split-Path $_.Path -Parent) -ieq $invalid.Run })) {
            $record.Status = 'NAO VERIFICADO'; $record.Problem = $invalid.Problem
        }
    }
    # Referencia local e pasta externa podem apontar ao mesmo resultado.
    $candidates = @($candidates | Group-Object Path | ForEach-Object { $_.Group[0] })
    foreach ($duplicate in ($candidates | Where-Object { $_.Area -eq 'runs' -and $_.Id } | Group-Object Source,Id | Where-Object Count -gt 1)) {
        foreach ($record in $duplicate.Group) { $record.Status = 'NAO VERIFICADO'; $record.Problem = 'RunId ambiguo em pastas MTA diferentes: ' + $record.Id }
    }
    $records = @(Select-IndexLatest $candidates $Context $warnings)
    $projects = @(foreach ($project in $Context.Projects) {
        $source = Resolve-HarnessPath $project.path $Context.Root
        $own = @($records | Where-Object Source -IEQ $source)
        $mta = @($own | Where-Object Area -eq 'runs')
        $catalog = Read-IndexMtaCatalog $mta $Context.Root $warnings
        $sync = if ($UpdateMigration) { Sync-IndexMigration $Context $project $mta $catalog $warnings } else { $null }
        $maintenance = @($own | Where-Object Action -eq 'migration-register')
        if ($sync -and $sync.ContextPath) {
            $receipt = Get-Content -LiteralPath $sync.ContextPath -Raw -Encoding UTF8 | ConvertFrom-Json
            $maintenance = @([pscustomobject]@{Area='planning';Action='migration-register';Date=[DateTimeOffset]::Parse($receipt.PreparedAtUtc);Id=$receipt.RequestId;Status='PROMPT DE RECONCILIACAO PREPARADO';Path=$sync.ContextPath;Problem=$null})
        }
        [pscustomobject]@{
            Label=$project.label;Source=$source;Migration=(Read-IndexMigration $Context.Root $project $warnings)
            Builds=@($own | Where-Object Area -eq 'builds');Mta=$mta
            MtaCatalog=$catalog;Sync=$sync
            Sonar=@($own | Where-Object Area -eq 'sonar')
            Plans=@($own | Where-Object Action -eq 'application-remediation')
            Maintenance=$maintenance
        }
    })
    $catalogs = @($projects | Where-Object { $_.MtaCatalog.Available })
    $readable = @($projects | Where-Object { $_.Migration.Status -in @('CATALOGO CARREGADO','AGUARDANDO MTA') })
    [long]$totalIssues = 0; [long]$totalOccurrences = 0
    foreach ($project in $catalogs) { $totalIssues += $project.MtaCatalog.Issues; $totalOccurrences += $project.MtaCatalog.Occurrences }
    $categoryTotals = if ($catalogs.Count) {
        Format-IndexCategories @(foreach ($project in $catalogs) { $project.MtaCatalog.CategoryCounts })
    } else { 'indisponivel' }
    $activeRows = @(foreach ($project in $readable) { $project.Migration.ActiveRows })
    $base = Resolve-HarnessPath (Join-Path $Context.Root '.harness/projetos') $Context.Root
    $history = Resolve-HarnessPath (Join-Path $base 'indices') $Context.Root
    $null = [IO.Directory]::CreateDirectory($history)
    $now = [DateTimeOffset]::Now
    $snapshot = Join-Path $history ('indice_' + $now.ToString('yyyyMMdd-HHmmss') + '__' + [guid]::NewGuid().ToString('N') + '.md')
    $index = Resolve-HarnessPath (Join-Path $base 'indice-projetos.md') $Context.Root
    foreach ($destination in @($snapshot, $index)) {
        $directory = Split-Path -Parent $destination
        $lines = @('# Situacao dos projetos', '', ('Gerado em: ' + $now.ToString('yyyy-MM-dd HH:mm:ss zzz')), '')
        if ($warnings.Count) { $lines += @('**LEITURA PARCIAL: consulte Limites da leitura antes de interpretar os status.**', '') }
        $lines += 'Escopo: ' + (ConvertTo-IndexText $(if ($Context.WorkspacePath) { $Context.WorkspacePath } else { $Context.ConfigPath }))
        $mode = if ($UpdateMigration) { 'Registros sincronizados quando possivel; prompts preparados/reutilizados. Execute as reconciliacoes PENDENTES no Copilot.' } else { 'Consulta tecnica somente leitura; registros nao sincronizados nesta chamada.' }
        $lines += @('', $mode, 'Execute Workspace: atualizar indice dos projetos apos novas execucoes ou edicoes do registro.',
            'Somente a ultima rodada de cada acao por projeto, inclusive falha/incompleta; sem somar historico. SEM REGISTRO significa ausencia de evidencia local disponivel.',
            'O indice nao valida o codigo atual, nao concede GO/aceite e nao comprova conclusao da migracao. Contagens de andamento podem ter cobertura parcial.',
            'Leitura sequencial: mudancas simultaneas podem nao aparecer. A copia datada preserva este resumo, nao os arquivos apontados pelos links.', '',
            ('Projetos: ' + $projects.Count + '; sem migracao.md: ' + @($projects | Where-Object { $_.Migration.Status -eq 'NAO GERADO' }).Count + '; registros aguardando carga MTA: ' + @($projects | Where-Object { $_.Migration.Status -eq 'AGUARDANDO MTA' }).Count + '; registros com catalogo carregado: ' + @($projects | Where-Object { $_.Migration.Status -eq 'CATALOGO CARREGADO' }).Count), '',
            (New-IndexLink 'Copia desta consulta' $snapshot $directory), (New-IndexLink 'Historico de indices' ($history + '\') $directory), '',
            '| Projeto / Source | Ultimo build | Ultimo MTA | Ultimo planejamento | Ultimo Sonar | Registro atual | MTA x registro | Reconciliacao | Issues / ocorrencias (ultimo MTA) | Categorias MTA (issues / ocorrencias) | Decisoes (registro) | Andamento (registro) | Proximos passos sugeridos |', '| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |')
        foreach ($project in $projects) {
            $migration = $project.Migration
            $register = if ($migration.Path) { New-IndexLink $migration.Status $migration.Path $directory } else { $migration.Status }
            $reconciliationLabel = if ($migration.Reconciliation -eq 'PENDENTE') { 'PENDENTE - executar prompt' } elseif ($migration.Reconciliation -eq 'CONCLUIDA') { 'CONCLUIDA (declarada no registro)' } else { $migration.Reconciliation }
            $reconciliation = $reconciliationLabel
            $reconciliationPrompt = Get-IndexReconciliationPrompt $project
            if ($reconciliationPrompt) { $reconciliation = New-IndexLink $reconciliationLabel $reconciliationPrompt $directory }
            $counts = if ($project.MtaCatalog.Available) { "$($project.MtaCatalog.Issues) / $($project.MtaCatalog.Occurrences)" } else { 'indisponivel' }
            $categories = if ($project.MtaCatalog.Available) { Format-IndexCategories $project.MtaCatalog.CategoryCounts } else { 'indisponivel' }
            $decisions = 'indisponivel'; $progress = 'indisponivel'
            if ($migration.Status -eq 'CATALOGO CARREGADO' -or ($migration.Status -eq 'AGUARDANDO MTA' -and $migration.ActiveRows.Count)) {
                $decisions = Format-IndexIssueGroups $migration.ActiveRows 'Decision'
                $progress = Format-IndexIssueGroups $migration.ActiveRows 'Progress'
            }
            $lines += '| ' + (ConvertTo-IndexText ($project.Label + ' / ' + $project.Source)) + ' | ' + (Format-IndexRecords $project.Builds $directory -Compact) + ' | ' + (Format-IndexRecords $project.Mta $directory -Compact) + ' | ' + (Format-IndexRecords $project.Plans $directory -Compact) + ' | ' + (Format-IndexRecords $project.Sonar $directory -Compact) + ' | ' + $register + ' | ' + (ConvertTo-IndexText (Get-IndexMigrationComparison $project)) + ' | ' + $reconciliation + ' | ' + $counts + ' | ' + $categories + ' | ' + $decisions + ' | ' + $progress + ' | ' + (ConvertTo-IndexText (Get-IndexNextSteps $project)) + ' |'
        }
        $totalText = if ($catalogs.Count) { "$totalIssues issues / $totalOccurrences ocorrencias" } else { 'indisponivel' }
        $lines += @('', ('**Total MTA contabilizado: ' + $totalText + '**'),
            ('Totais por categoria (issues / ocorrencias): ' + $categoryTotals),
            ('Catalogos contabilizados: ' + $catalogs.Count + '/' + $projects.Count + '. Leitura direta do ultimo MTA de cada projeto, independentemente do registro. Falha, ambiguidade ou catalogo ilegivel ficam fora do total; nao usar rodadas antigas como substitutas.'),
            'Issues sao regras por projeto; a mesma regra em dois projetos conta duas vezes. Ocorrencias sao os pontos apontados pelo MTA.',
            ('Decisoes consolidadas: ' + (Format-IndexIssueGroups $activeRows 'Decision')),
            ('Andamento consolidado: ' + (Format-IndexIssueGroups $activeRows 'Progress')),
            ('Registros legiveis: ' + $readable.Count + '/' + $projects.Count + '. Decisoes/andamento contam issues PRESENTE e MANUAL do registro; excluem NAO REENCONTRADA. Podem se referir a outra rodada: confira MTA x registro. Manuais nao entram nos totais MTA.'),
            'Decisao e andamento sao dimensoes da mesma issue: nao somar suas contagens. IMPLEMENTADA/VERIFICADA nao comprovam todas as ocorrencias resolvidas.',
            'Proximos passos sao sugestoes baseadas nos registros; nao executam acoes nem substituem GO/aceite humano.',
            '', '## Como interpretar o indice', '',
            'A tarefa carrega o ultimo MTA reconhecido nos registros possiveis e prepara/reutiliza prompts, preservando decisoes e anotacoes. Nao executa agente nem planeja lote.',
            'Issues, ocorrencias e categorias vem diretamente do ultimo MTA. Decisoes e andamento vem do migracao.md; carga automatica nao comprova que essas escolhas foram reconciliadas.',
            'Categorias MTA: cada par indica issues / ocorrencias (ex.: mandatory: 2 / 138). A classificacao do MTA nao e a prioridade escolhida pelo desenvolvedor; categorias ausentes nao sao listadas.',
            'A coluna MTA x registro compara a ultima tentativa encontrada com o RunId carregado no registro. Ela nao valida o conteudo do catalogo nem o codigo atual.', '',
            '| Indicacao | Significado | O que fazer |', '| --- | --- | --- |',
            '| CATALOGO NAO CARREGADO | Nao foi possivel carregar o MTA no registro; seus numeros podem estar disponiveis no indice. | Conferir Atualizacao do registro e Limites da leitura; para outra origem, informar p no preparo. |',
            '| MESMA RODADA | O registro e a ultima tentativa encontrada referenciam o mesmo RunId. | Conferir prioridades e seguir os proximos passos sugeridos; nao significa migracao concluida. |',
            '| RODADA DIFERENTE | O registro ainda usa outra rodada. | Conferir os RunIds e o motivo da carga nao concluida nos detalhes. |',
            '| ULTIMA TENTATIVA FAILED (ou outro estado sem sucesso) | A tentativa mais recente nao terminou com sucesso. | Conferir a tentativa; preservar o catalogo ou selecionar outra rodada concluida. |',
            '| SEM MTA LOCALIZADO | Nenhuma rodada associavel foi encontrada para comparar com o registro. | Conferir mta.runsPath; para origem de outra maquina/caminho, informar a pasta com p no preparo. |',
            '| COMPARACAO INDISPONIVEL | MTA ou registro invalido, incompleto ou ambiguo. | Conferir Limites da leitura e corrigir os dados antes de interpretar a comparacao. |', '',
            '**RECONCILIACAO PENDENTE: execute o prompt vinculado no Copilot.** MESMA RODADA e catalogo atualizado nao significam reconciliacao concluida.',
            'O campo Estado na secao Reconciliacao do registro e explicito: PENDENTE ate executar o prompt e tratar os conflitos; CONCLUIDA somente depois disso. A tarefa nunca conclui essa etapa nem concede GO/aceite.',
            'Copiar o MTA e executar esta tarefa basta para carregar o catalogo reconhecido e preparar o prompt. Para escolher outra rodada, origem ou evidencias, use Preparar planejamento > 2 Manter registro.',
            'SEM REGISTRO nas colunas de acoes significa ausencia de evidencia local disponivel, nao que a acao nunca foi executada. Indisponivel nas contagens nao equivale a zero.')
        foreach ($project in $projects) {
            if ($project.Migration.Status -eq 'NAO GERADO' -and ($project.Builds.Count + $project.Mta.Count + $project.Plans.Count + $project.Sonar.Count + $project.Maintenance.Count) -eq 0) { continue }
            $lines += @('', ('## ' + (ConvertTo-IndexText $project.Label)), '', ('- Source: ' + (ConvertTo-IndexText $project.Source)),
                ('- Build: ' + (Format-IndexRecords $project.Builds $directory)), ('- MTA: ' + (Format-IndexRecords $project.Mta $directory)),
                ('- Planejamento: ' + (Format-IndexRecords $project.Plans $directory)), ('- Sonar: ' + (Format-IndexRecords $project.Sonar $directory)),
                ('- Manutencao do registro: ' + (Format-IndexRecords $project.Maintenance $directory)), ('- Catalogo: ' + (ConvertTo-IndexText $project.Migration.Status)))
            if ($project.Sync) { $lines += '- Atualizacao do registro: ' + (ConvertTo-IndexText $project.Sync.Message) }
            $lines += '- Reconciliacao: ' + $project.Migration.Reconciliation
            $reconciliationPrompt = Get-IndexReconciliationPrompt $project
            if ($reconciliationPrompt) { $lines += '- ' + (New-IndexLink 'Prompt de reconciliacao (executar se PENDENTE)' $reconciliationPrompt $directory) }
            if ($project.MtaCatalog.Available) {
                $lines += '- Ultimo MTA: ' + $project.MtaCatalog.Issues + ' issues / ' + $project.MtaCatalog.Occurrences + ' ocorrencias'
                if ($project.MtaCatalog.Categories) { $lines += '- Categorias do ultimo MTA: ' + (ConvertTo-IndexText $project.MtaCatalog.Categories) }
            }
            if ($project.Migration.RunId) { $lines += '- RunId carregado no registro: ' + $project.Migration.RunId }
            if ($project.Migration.RunId -and $project.Mta.Count -and $project.Mta[0].Id -and $project.Migration.RunId -cne $project.Mta[0].Id) {
                $lines += '- ATENCAO: o catalogo do registro usa outra rodada MTA. Confira Atualizacao do registro e Limites da leitura; a carga da ultima rodada nao foi confirmada nesta geracao.'
            }
            if ($project.Migration.Counts -and ($project.Migration.RunId -or $project.Migration.ActiveRows.Count)) { $lines += '- Contagens do registro: ' + (ConvertTo-IndexText $project.Migration.Counts) }
            if ($project.Migration.Decisions) { $lines += '- Decisoes: ' + (ConvertTo-IndexText $project.Migration.Decisions) }
            if ($project.Migration.Progress) { $lines += '- Andamento: ' + (ConvertTo-IndexText $project.Migration.Progress) }
        }
        if ($warnings.Count) { $lines += @('', '## Limites da leitura', '', '**LEITURA PARCIAL / NAO VERIFICADO: registros abaixo nao confirmam status atual.**', '') + @($warnings | ForEach-Object { '- ' + (ConvertTo-IndexText $_) }) }
        $temp = $destination + '.' + [guid]::NewGuid().ToString('N') + '.tmp'
        try {
            [IO.File]::WriteAllText($temp, ($lines -join "`n"), (New-Object Text.UTF8Encoding($false)))
            Move-Item -LiteralPath $temp -Destination $destination -Force
        } finally { if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp } }
    }
    [pscustomobject]@{IndexPath=$index;SnapshotPath=$snapshot;Warnings=@($warnings.ToArray())}
}

Export-ModuleMember -Function New-HarnessProjectIndex
