# Participantes sao associados exclusivamente pelos projetos locais. Caminhos recebidos
# nunca escolhem um POM nem um destino de escrita.
function Get-ReconciliationScopeParticipants {
    param($Project,[string]$ReceivedPath)
    $names=New-Object 'Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
    $null=$names.Add($Project.Name); $observed=@{}
    $folders=@($Project.Folder)
    if ($ReceivedPath) { $folders+=Resolve-ProjectPath $ReceivedPath $Project.Root }
    foreach ($folder in $folders) {
        foreach ($relative in @(Get-ReconciliationFiles $folder)) {
            if ($relative -cnotmatch '^atual/priorizacao/[^/]+/escopos/[^/]+/contexto\.json$') { continue }
            $path=Join-Path $folder $relative
            $text=[IO.File]::ReadAllText($path); $observed[$path]=$text
            $data=ConvertFrom-Json $text
            if ($data.Purpose -cne 'current-prioritization' -or $data.Projects -isnot [Array]) { throw 'Contexto de priorizacao recebido/local invalido.' }
            foreach ($entry in $data.Projects) {
                # Validar nome por sua pasta literal antes de abrir a associacao.
                if (-not $entry.Project -or $entry.Project -match '[<>:"/\\|?*\x00-\x1f]' -or $entry.Project -match '[. ]$') { throw 'Participante de priorizacao invalido.' }
                $null=$names.Add([string]$entry.Project)
            }
        }
    }
    $ordered=[string[]]@($names); [Array]::Sort($ordered,[StringComparer]::Ordinal)
    $projects=@(foreach ($name in $ordered) {
        if ($name -ceq $Project.Name) { $Project; continue }
        $configPath=Resolve-ProjectPath (Join-Path $Project.Root ('.harness/projetos/'+$name+'/projeto.json')) $Project.Root
        if (-not (Test-Path -LiteralPath $configPath -PathType Leaf)) { throw "Associe primeiro o participante local: $name" }
        $text=[IO.File]::ReadAllText($configPath); $observed[$configPath]=$text
        $peer=Get-HarnessProjectReference $Project.Root (ConvertFrom-Json $text).pom
        if ($peer.Name -cne $name -or $peer.ConfigPath -ine $configPath) { throw "Associacao divergente do participante: $name" }
        $peer
    })
    [pscustomobject]@{Projects=$projects;Observed=$observed}
}
function Enter-ReconciliationAccess {
    param($Project,[string]$ReceivedPath)
    $scope=Get-ReconciliationScopeParticipants $Project $ReceivedPath
    $leases=@(); $guards=@()
    try {
        foreach ($peer in $scope.Projects) {
            $guards+=[IO.File]::Open($peer.Pom,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read)
            if ((Get-HarnessProjectReference $Project.Root $peer.Pom).Name -cne $peer.Name) { throw 'POM alterado durante a associacao.' }
        }
        foreach ($peer in $scope.Projects) {
            if ($peer.Name -ceq $Project.Name) { $leases+=Enter-HarnessProjectAccess $peer -ForOperation }
            # Leitura mantida ate a publicacao: parceiros nao sao recuperados/escritos.
            $leases+=Enter-HarnessProjectAccess $peer -ReadOnly
        }
        foreach ($path in $scope.Observed.Keys) {
            if (-not (Test-Path -LiteralPath $path -PathType Leaf) -or [IO.File]::ReadAllText($path) -cne $scope.Observed[$path]) { throw 'Participantes mudaram durante a leitura; repita a comparacao.' }
        }
        foreach ($peer in $scope.Projects) {
            $config=Read-HarnessProjectFiles $peer @('projeto.json')
            if (-not $config['projeto.json'] -or (Resolve-ProjectPath (ConvertFrom-Json $config['projeto.json']).pom $Project.Root) -ine $peer.Pom) { throw "Associacao local divergente: $($peer.Name)" }
        }
        [pscustomobject]@{Projects=$scope.Projects;Leases=$leases;Guards=$guards}
    } catch {
        for ($i=$leases.Count-1;$i -ge 0;$i--) { $leases[$i].ReleaseMutex(); $leases[$i].Dispose() }
        foreach ($guard in $guards) { $guard.Dispose() }
        throw
    }
}
function Exit-ReconciliationAccess {
    param($Access)
    for ($i=$Access.Leases.Count-1;$i -ge 0;$i--) { $Access.Leases[$i].ReleaseMutex(); $Access.Leases[$i].Dispose() }
    foreach ($guard in $Access.Guards) { $guard.Dispose() }
}
function Get-ReconciliationPartnerFiles {
    param($Project,$Projects,$Local,$Received)
    $files=@{}; $requests=@{}; $narrative=@()
    foreach ($documents in @($Local,$Received)) {
        foreach ($relative in @($documents.Keys | Where-Object {$_ -cmatch '^atual/priorizacao/[^/]+/escopos/[^/]+/contexto\.json$'})) {
            if (-not $documents[$relative]) { continue }
            $data=ConvertFrom-Json (ConvertFrom-ReconciliationBytes $documents[$relative])
            $rank=$relative.Replace('/contexto.json','/priorizacao.md')
            if ($documents.Contains($rank) -and $documents[$rank]) {
                $current=Get-ReconciliationPriorityData $Project $relative $documents[$relative] $Projects
                $text=Convert-ReconciliationPriorityLinks (ConvertFrom-ReconciliationBytes $documents[$rank]) $data $current.Data $current.Projects
                $narrative+=@(Get-ReconciliationMarkdownReferences $text $current.Paths.RankingPath)
            }
            foreach ($issue in $data.BaselineIssues) {
                if ($issue.Project -ceq $Project.Name) { continue }
                $store=@($Projects | Where-Object Name -CEQ $issue.Project)
                if ($store.Count -ne 1) { throw 'Participante nao associado.' }
                $ficha=Get-PrioritizationFichaRelativePath $data.Category $issue.Id -Project $store[0]
                $requests[$issue.Project+'|'+$ficha]=[pscustomobject]@{Project=$issue.Project;Relative=$ficha;Category=$data.Category;Id=$issue.Id}
            }
        }
    }
    foreach ($peer in $Projects) {
        if ($peer.Name -ceq $Project.Name) { continue }
        $files[$peer.ConfigPath]=[IO.File]::ReadAllBytes($peer.ConfigPath)
        $queue=New-Object 'Collections.Generic.Queue[string]'
        foreach ($path in $narrative) {
            if ($path.StartsWith($peer.Source+'\',[StringComparison]::OrdinalIgnoreCase) -or $path.StartsWith($peer.EvidencePath+'\',[StringComparison]::OrdinalIgnoreCase)) { $queue.Enqueue($path) }
        }
        foreach ($request in @($requests.Values | Where-Object Project -CEQ $peer.Name)) {
            $path=Join-Path $peer.Folder $request.Relative
            $files[$path]=if (Test-Path -LiteralPath $path -PathType Leaf) {[IO.File]::ReadAllBytes($path)} else {$null}
            if (-not $files[$path]) { continue }
            $text=ConvertFrom-ReconciliationBytes $files[$path]
            # Ficha incompleta pode ser diagnosticada/descartada na revisao; sua
            # presenca nao obriga a adotar cobertura. Bytes seguem protegidos.
            try { $identity=Read-PrioritizationFicha $text $peer.Name $request.Category $request.Id } catch { continue }
            foreach ($pair in @(@($peer.Source,$identity.LocalPaths),@($peer.EvidencePath,$identity.EvidencePaths))) {
                foreach ($ref in $pair[1]) {
                    $null=Get-IssueLocalReference $pair[0] $ref $path
                    $queue.Enqueue((Resolve-ProjectPath (Join-Path $pair[0] $ref) $peer.Root))
                }
            }
            foreach ($reference in @(Get-ReconciliationMarkdownReferences $text $path)) { $queue.Enqueue($reference) }
        }
        while ($queue.Count) {
                $reference=Resolve-ProjectPath $queue.Dequeue() $peer.Root
                if ($files.ContainsKey($reference)) { continue }
                # Links operacionais nao incorporam planos/categorias alheios
                # ao escopo; fichas e seus anexos/fontes bastam para a cobertura.
                if (($reference.StartsWith((Join-Path $peer.Root '.harness')+'\',[StringComparison]::OrdinalIgnoreCase) -and $reference -notmatch '\\\.harness\\projetos\\[^\\]+\\evidencias\\') -or
                    (-not $reference.StartsWith($peer.Source+'\',[StringComparison]::OrdinalIgnoreCase) -and $reference -notmatch '\\\.harness\\projetos\\[^\\]+\\evidencias\\')) { continue }
                $files[$reference]=if (Test-Path -LiteralPath $reference -PathType Leaf) {[IO.File]::ReadAllBytes($reference)} else {$null}
                if ($files[$reference] -and (Test-ReconciliationReferenceDocument $peer $reference)) {
                    foreach ($next in @(Get-ReconciliationMarkdownReferences (ConvertFrom-ReconciliationBytes $files[$reference]) $reference)) { $queue.Enqueue($next) }
                }
        }
        $files[$peer.Pom]=[IO.File]::ReadAllBytes($peer.Pom)
    }
    $files
}
