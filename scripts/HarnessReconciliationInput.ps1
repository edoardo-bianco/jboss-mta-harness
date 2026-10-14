# Comparacao corrente; somente a revisao transitoria guarda a base lida.
function Get-ReconciliationFileKind {
    param([string]$Relative)
    if ($Relative -ceq 'migracao.md') { return 'REGISTRO' }
    if ($Relative -cin @('atual/planejamento/plano.md','atual/planejamento/tarefas.md')) { return 'DOCUMENTO' }
    if ($Relative -cmatch '^atual/priorizacao/[^/]+/issues/[^/]+/ficha\.md$') { return 'FICHA' }
    if ($Relative -cmatch '^atual/priorizacao/[^/]+/escopos/[^/]+/(contexto\.json|priorizacao\.md)$') { return 'PRIORIZACAO' }
    if ($Relative -cmatch '^evidencias/.+') { return 'ANEXO' }
    'REFERENCIA'
}
function Get-ReconciliationFiles {
    param([string]$Folder,[switch]$AllFiles)
    $found=@()
    if (-not (Test-Path -LiteralPath $Folder -PathType Container)) { return $found }
    $pending=New-Object 'Collections.Generic.Stack[string]'; $pending.Push($Folder)
    while ($pending.Count) {
        foreach ($item in Get-ChildItem -LiteralPath $pending.Pop() -Force) {
            $relative=$item.FullName.Substring($Folder.Length+1).Replace('\','/')
            if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "Link/junction na reconciliacao: $relative" }
            if ($item.PSIsContainer) {
                if ($AllFiles -or $relative -notmatch '^(temporarios|recebido)(/|$)|^atual/(diagnosticos|build|sprints)(/|$)') { $pending.Push($item.FullName) }
            } elseif ($AllFiles -or (Get-ReconciliationFileKind $relative) -ne 'REFERENCIA' -or
                $relative -cmatch '^atual/priorizacao/[^/]+/escopos/[^/]+/(indice\.md|priorizar-issues\.prompt\.md)$' -or
                $relative -cin @('projeto.json','indice.md','atual/planejamento/contexto.json','reconciliado/resultado.md')) { $found+=$relative }
        }
    }
    @($found | Sort-Object)
}
function ConvertFrom-ReconciliationBytes {
    param([byte[]]$Bytes)
    if ($null -eq $Bytes) { return '' }
    (New-Object Text.UTF8Encoding($false,$true)).GetString($Bytes).TrimStart([char]0xfeff)
}
function Get-ReconciliationComparable {
    param([byte[]]$Bytes,[string]$Relative)
    if ($null -eq $Bytes) { return $null }
    if ($Relative -notmatch '\.md$' -or (Get-ReconciliationFileKind $Relative) -eq 'ANEXO') { return [Convert]::ToBase64String($Bytes) }
    $text=ConvertFrom-ReconciliationBytes $Bytes
    foreach ($name in @('fontes','planejamento:fontes','ficha:fontes','reconciliacao','reconciliacao:fontes','reconciliacao:autorizacao')) {
        $block=Find-ProjectManagedBlock $text $name
        if ($block) { $text=$text.Remove($block.Index,$block.Length) }
    }
    ($text -replace '\r\n',"`n").Trim()
}
function Get-ReconciliationMtaStamp {
    param($Mta)
    if ($null -eq $Mta) { return $null }
    # Protecao somente na area transitoria de revisao; nunca identifica um ciclo.
    [ordered]@{ReportPath=$Mta.ReportPath;CatalogPath=$Mta.CatalogPath;
        Report=(Get-FileHash -LiteralPath $Mta.ReportPath -Algorithm SHA256).Hash;
        Catalog=(Get-FileHash -LiteralPath $Mta.CatalogPath -Algorithm SHA256).Hash}
}
function Get-HarnessReconciliationComparison {
    param($Project,[string]$ReceivedPath,[ValidateSet('MTA','EVIDENCIAS')][string]$PlanningBasis='MTA',$Access)
    $ownsAccess=$null -eq $Access
    if ($ownsAccess) { $Access=Enter-ReconciliationAccess $Project $ReceivedPath }
    try {
        $received=@{}; $origin=$null
        if ($ReceivedPath) {
            $origin=Resolve-ProjectPath $ReceivedPath $Project.Root
            $internal=Join-Path $Project.Folder 'recebido'
            if ($origin -ieq $Project.Folder -or $Project.Folder.StartsWith($origin+'\',[StringComparison]::OrdinalIgnoreCase) -or
                ($origin.StartsWith($Project.Folder+'\',[StringComparison]::OrdinalIgnoreCase) -and
                $origin -ine $internal -and -not $origin.StartsWith($internal+'\',[StringComparison]::OrdinalIgnoreCase))) { throw 'Origem deve ser recebido/ ou pasta externa ao projeto, sem sobrepor o trabalho local.' }
            if (-not (Test-Path -LiteralPath $origin -PathType Container)) { throw 'Pasta recebida indisponivel.' }
            foreach ($relative in @(Get-ReconciliationFiles $origin)) { $received[$relative]=[IO.File]::ReadAllBytes((Join-Path $origin $relative)) }
            if (-not $received.Count) { throw 'Pasta sem documentos correntes reconhecidos; preserve sua organizacao relativa ao projeto.' }
            if ($received.ContainsKey('atual/planejamento/contexto.json')) {
                $data=ConvertFrom-Json (ConvertFrom-ReconciliationBytes $received['atual/planejamento/contexto.json'])
                if ($data.Purpose -cne 'current-planning' -or $data.Project -cne $Project.Name) { throw 'Contexto recebido de outro projeto/layout; associe a pasta correta.' }
            }
        }
        $paths=@(@(Get-ReconciliationFiles $Project.Folder)+@($received.Keys)+@('projeto.json','migracao.md','indice.md',
            'atual/planejamento/contexto.json','atual/planejamento/plano.md','atual/planejamento/tarefas.md',
            'atual/planejamento/reconciliacao.json','atual/planejamento/planejar-lotes.prompt.md','reconciliado/resultado.md','atual/build/resultado.json','atual/diagnosticos/sonar/resultado.json',
            'atual/diagnosticos/sonar-decisao.json','atual/operacao.json')+
            @('quality-gate.json','measures.json','issues.json','criteria.json','RESUMO.md' | ForEach-Object {'atual/diagnosticos/sonar/'+$_}) | Select-Object -Unique)
        $local=Read-HarnessProjectFiles $Project $paths -AsBytes
        if ($null -eq $local['migracao.md']) { throw 'Registro ausente; execute Workspace: atualizar indice dos projetos.' }
        $rows=@(Read-ProjectDecisionRows (ConvertFrom-ReconciliationBytes $local['migracao.md']))
        $mta=$null; $differences=@(); $diagnostics=@()
        if ($PlanningBasis -eq 'MTA') {
            $mta=Read-HarnessProjectMta $Project; $diagnostics+=@($mta.Diagnostics)
            $byId=New-Object 'Collections.Generic.Dictionary[string,object]' ([StringComparer]::Ordinal)
            foreach ($row in $rows) { $byId.Add($row.Id,$row) }
            $present=New-Object 'Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
            foreach ($issue in $mta.Issues) {
                $null=$present.Add($issue.Id)
                if (-not $byId.ContainsKey($issue.Id)) { $differences+=($issue.Id+': nova no catalogo atual') }
                elseif ($byId[$issue.Id].Count -cne [string]$issue.Count -or $byId[$issue.Id].Category -cne $issue.Category -or $byId[$issue.Id].Presence -cne 'PRESENTE') { $differences+=($issue.Id+': diagnostico alterado; conferir aplicabilidade') }
            }
            foreach ($row in $rows) {
                if ($row.Presence -ne 'MANUAL' -and -not $present.Contains($row.Id)) { $differences+=($row.Id+': nao reencontrada; ausencia nao comprova resolucao') }
            }
        }
        $documents=@(foreach ($relative in @($received.Keys | Sort-Object)) {
            $kind=Get-ReconciliationFileKind $relative
            if ($kind -eq 'FICHA') {
                $parts=$relative.Split('/')
                if ((Get-PrioritizationFichaRelativePath ([Uri]::UnescapeDataString($parts[2])) ([Uri]::UnescapeDataString($parts[4]))) -cne $relative) { throw 'Caminho da ficha nao corresponde a chave funcional canonica.' }
                $null=Read-PrioritizationFicha (ConvertFrom-ReconciliationBytes $received[$relative]) $Project.Name ([Uri]::UnescapeDataString($parts[2])) ([Uri]::UnescapeDataString($parts[4]))
            }
            if ($kind -eq 'REGISTRO') { $null=@(Read-ProjectDecisionRows (ConvertFrom-ReconciliationBytes $received[$relative])) }
            $status=if ($kind -eq 'REFERENCIA') {'REFERENCIA'} elseif ($null -eq $local[$relative]) {'NOVO'}
                elseif ((Get-ReconciliationComparable $local[$relative] $relative) -ceq (Get-ReconciliationComparable $received[$relative] $relative)) {'EQUIVALENTE'} else {'DIVERGENTE'}
            [pscustomobject]@{Path=$relative;Kind=$kind;Status=$status;LocalPath=(Join-Path $Project.Folder $relative);ReceivedPath=(Join-Path $origin $relative)}
        })
        [pscustomobject]@{Project=$Project;PlanningBasis=$PlanningBasis;ReceivedPath=$origin;Local=$local;Received=$received;
            Documents=$documents;Mta=$mta;MtaStamp=(Get-ReconciliationMtaStamp $mta);Differences=$differences;Diagnostics=$diagnostics;
            PartnerFiles=(Get-ReconciliationPartnerFiles $Project $Access.Projects $local $received)}
    } finally { if ($ownsAccess) { Exit-ReconciliationAccess $Access } }
}
