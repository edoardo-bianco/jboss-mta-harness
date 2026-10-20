# Leitores exclusivos da transicao. Nao inicializam nem recuperam dados.
function Get-LegacyValue($Object,[string]$Name,$Default=$null) {
    if ($null -ne $Object -and $Object.PSObject.Properties[$Name]) { return $Object.$Name }
    $Default
}
function Read-ConversionDecisions([string]$Text) {
    # O cabecalho antigo difere; somente a leitura em memoria e normalizada.
    $table=[regex]::Replace($Text,'(?m)^\| ID \([^\r\n]+','| ID | Issue | Categoria | Ocorrencias | Presenca | Decisao | Andamento | Observacao/referencia |')
    Read-ProjectDecisionRows $table
}
function Read-ConversionText($Session,[string]$Path) {
    $path=Resolve-ProjectPath $Path $Session.Workspace
    if (-not $path.StartsWith($Session.DataRoot+'\',[StringComparison]::OrdinalIgnoreCase)) { throw "Referencia fora dos dados legados: $path" }
    if ($Session.Observed.ContainsKey($path)) { return $Session.Observed[$path] }
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { $Session.Observed[$path]=$null; return $null }
    if ((Get-Item -LiteralPath $path).Length -gt 16MB) { throw "Arquivo excede limite de leitura da previa (16 MiB): $path" }
    $text=[IO.File]::ReadAllText($path)
    $Session.Observed[$path]=$text
    $text
}
function Get-ConversionInventory($Session) {
    foreach ($family in @('projetos','planning','priorizacao','sprints','builds','sonar','runs','importacoes')) {
        $base=Resolve-ProjectPath (Join-Path $Session.DataRoot $family) $Session.Workspace
        if (-not (Test-Path -LiteralPath $base -PathType Container)) { continue }
        $pending=New-Object 'Collections.Generic.Stack[string]'; $pending.Push($base)
        $count=0
        while ($pending.Count) {
            $directory=$pending.Pop()
            foreach ($entry in Get-ChildItem -LiteralPath $directory -Force | Sort-Object Name) {
                if (++$count -gt 50000) { throw "Inventario excede 50000 entradas em $base; delimite os dados antes da transicao." }
                $path=Resolve-ProjectPath $entry.FullName $Session.Workspace
                if ($entry.PSIsContainer) {
                    if ($family -eq 'projetos' -and $directory -eq $base -and (Test-Path -LiteralPath (Join-Path $path 'projeto.json'))) { continue }
                    if ($family -eq 'importacoes' -and $entry.Name -eq 'original' -and (Split-Path $directory -Parent) -ieq $base) { continue }
                    if ($family -eq 'runs' -and $entry.Name -in @('source','output','input') -and (Test-Path -LiteralPath (Join-Path $directory 'manifest.json'))) { continue }
                    $pending.Push($path)
                } elseif (($family -eq 'projetos' -and $entry.Name -match '^migracao(?:-.*)?\.md$') -or
                    ($entry.Name -match '^(context(?:o)?(?:-.*)?|result|manifest|import|atual|project)\.json$')) {
                    [pscustomobject]@{Path=$path;Family=$family}
                }
            }
        }
    }
}
function Read-ConversionRecords($Session,$Inventory,[string]$Source) {
    foreach ($file in $Inventory) {
        $text=Read-ConversionText $Session $file.Path
        try {
            if ($file.Path.EndsWith('.md',[StringComparison]::OrdinalIgnoreCase)) {
                $matches=[regex]::Matches($text,'(?m)^Source:\s*([^\r\n]+)\s*$')
                if ($matches.Count -ne 1) { throw 'Registro sem Source unico.' }
                $sources=@($matches[0].Groups[1].Value.Trim())
                $data=$null; $kind='REGISTRO'
            } else {
                $data=ConvertFrom-Json $text
                $sources=@(Get-LegacyValue $data 'Source')+@(Get-LegacyValue $data 'Projects' @() | ForEach-Object { Get-LegacyValue $_ 'Source' })
                $kind=switch ([string](Get-LegacyValue $data 'Purpose')) {
                    'application-remediation' { 'PLANEJAMENTO' }
                    'migration-register' { 'RECONCILIACAO' }
                    'issue-prioritization' { 'PRIORIZACAO' }
                    'sprint-planning' { if ($file.Path -match 'context(?:o)?\.json$') { 'SPRINT' } else { 'OUTRO' } }
                    default { $file.Family.ToUpperInvariant() }
                }
            }
            $normalized=@($sources | Where-Object { $_ } | ForEach-Object { Resolve-ProjectPath $_ $Session.Workspace } | Sort-Object -Unique)
            if ($Source -notin $normalized) { continue }
            [pscustomobject]@{Path=$file.Path;Kind=$kind;Sources=$normalized;Data=$data;Text=$text}
        } catch {
            $Session.ReadErrors.Add($file)
            $Session.Pending.Add(('Origem nao interpretada: '+$file.Path+' - '+$_.Exception.Message))
        }
    }
}
function Get-ConversionPlanningAssociation($Session,$Inventory,$Project,[string]$Source) {
    # Cadastro do layout por issue, nao um contexto de planejamento.
    $path=Resolve-ProjectPath (Join-Path $Session.DataRoot ('planning/'+$Project.Name+'/issues/project.json')) $Session.Workspace
    if ($path -notin @($Inventory | ForEach-Object Path)) { return }
    $data=ConvertFrom-Json (Read-ConversionText $Session $path)
    $fields=@('ArtifactId','Project','Source')
    if ($data -isnot [pscustomobject] -or @($data.PSObject.Properties | Where-Object Name -NotIn $fields).Count) {
        throw ('Formato de associacao legada desconhecido; preservar e conferir: '+$path)
    }
    foreach ($field in $fields) {
        $property=$data.PSObject.Properties[$field]
        if (-not $property -or $property.Value -isnot [string] -or [string]::IsNullOrWhiteSpace($property.Value)) {
            throw ('Campo '+$field+' invalido na associacao legada: '+$path)
        }
    }
    if ($data.ArtifactId -cne $Project.Name) { throw ('ArtifactId da associacao legada diverge do POM: '+$path) }
    if ((Resolve-ProjectPath $data.Source $Session.Workspace) -ine $Source) {
        throw ('Source da associacao legada diverge do selecionado; confira SourceLegado: '+$path)
    }
    $path
}
function Get-ConversionLinks([string]$Text,[string]$Document,$Session) {
    foreach ($match in [regex]::Matches($Text,'\[[^\]\r\n]*\]\((?:<([^>\r\n]*)>|([^\s\)]+))\)')) {
        $value=if ($match.Groups[1].Success) {$match.Groups[1].Value} else {$match.Groups[2].Value}
        if ($value -match '^https?://|^#') { continue }
        try {
            $base=[uri]([uri]$Document).AbsoluteUri
            $uri=New-Object Uri $base,$value
            if (-not $uri.IsFile) { continue }
            Resolve-ProjectPath $uri.LocalPath $Session.Workspace
        } catch { $Session.Pending.Add(('Link invalido em '+$Document+': '+$value)) }
    }
}
function Assert-ConversionUnchanged($Session,$Inventory) {
    foreach ($path in $Session.Observed.Keys) {
        $current=if (Test-Path -LiteralPath $path -PathType Leaf) { [IO.File]::ReadAllText($path) } else { $null }
        if ($current -cne $Session.Observed[$path]) { throw "Entrada mudou durante a previa: $path. Repita a leitura." }
    }
    $after=@(Get-ConversionInventory $Session | ForEach-Object Path | Sort-Object)
    if (($after -join "`n") -cne (@($Inventory | ForEach-Object Path | Sort-Object) -join "`n")) { throw 'Inventario mudou durante a previa; repita a leitura.' }
}
