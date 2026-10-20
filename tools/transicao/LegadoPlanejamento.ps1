function Get-ConversionPlanDocuments($Session,$Record) {
    if (-not $Record) { return [pscustomobject]@{State=$null;Items=@()} }
    $items=@(foreach ($field in @('PlanPath','TodoPath')) {
        $origin=Resolve-ProjectPath (Get-LegacyValue $Record.Data $field) $Session.Workspace
        if (Test-Path -LiteralPath $origin -PathType Container) { throw ('Diretorio no lugar de documento do plano: '+$origin) }
        [pscustomobject]@{Field=$field;Origin=$origin;Text=(Read-ConversionText $Session $origin)}
    })
    $count=@($items | Where-Object { $null -ne $_.Text }).Count
    $state=if ($count -eq 2) {'PRESENTES'} elseif ($count -eq 0) {'AUSENTES'} else {'INCOMPLETOS'}
    if ($state -eq 'INCOMPLETOS') { $Session.Pending.Add('Par plano/tarefas incompleto: '+$Record.Path) }
    # Disponibilidade informa somente existencia, sem atestar proposta ou GO.
    [pscustomobject]@{State=$state;Items=$items}
}

function Get-ConversionIssueIds($Data) {
    $selected=@(Get-LegacyValue $Data 'SelectedIssues' @())
    if (-not $selected.Count) {
        # Recibos antigos preservam a escolha no texto capturado do registro.
        try { $selected=@(Read-ConversionDecisions (Get-LegacyValue $Data 'MigrationSnapshot' '') | Where-Object Decision -EQ 'ANALISAR AGORA') }
        catch { $selected=@() } # O chamador distingue escopo inconclusivo de divergente.
    }
    @($selected | ForEach-Object {
        if ($_ -is [string]) { $_ } else { Get-LegacyValue $_ 'Id' }
    } | Where-Object { $_ } | Sort-Object -Unique)
}
function Select-ConversionPlan($Session,$Plans,$Register,[string]$Contexto) {
    # Uma origem ilegivel nao permite concluir seu Source nem ausencia de plano.
    $byPath=@{}; $byId=@{}; $children=@{}; $parents=@{}; $targets=@{}; $invalid=@($Session.ReadErrors | Where-Object Family -EQ 'planning').Count -gt 0
    foreach ($plan in $Plans) {
        $id=[string](Get-LegacyValue $plan.Data 'RequestId')
        if ($id -cnotmatch '^[a-f0-9]{32}$' -or $byId.ContainsKey($id)) { $Session.Pending.Add('Identidade de planejamento ausente/duplicada: '+$plan.Path); $invalid=$true; continue }
        $declared=Get-LegacyValue $plan.Data 'ContextPath'
        if (-not $declared -or (Resolve-ProjectPath $declared $Session.Workspace) -ine $plan.Path) { $Session.Pending.Add('ContextPath divergente: '+$plan.Path); $invalid=$true; continue }
        $issues=@(Get-LegacyValue $plan.Data 'SelectedIssues' @())
        $ids=@(Get-ConversionIssueIds $plan.Data)
        if ((Get-LegacyValue $plan.Data 'LayoutVersion') -eq 2 -and ($issues.Count -ne 1 -or $ids.Count -ne 1 -or $ids[0] -cne (Get-LegacyValue $plan.Data 'IssueId'))) {
            $Session.Pending.Add('IssueId diverge do escopo LayoutVersion=2: '+$plan.Path); $invalid=$true
        }
        $paths=@($plan.Path)
        foreach ($name in @('PlanPath','TodoPath')) {
            $path=Resolve-ProjectPath (Get-LegacyValue $plan.Data $name) $Session.Workspace
            if ((Split-Path $path -Parent) -ine (Split-Path $plan.Path -Parent) -or $path -in $paths) {
                $Session.Pending.Add($name+' fora da solicitacao ou sobreposto: '+$plan.Path); $invalid=$true
            }
            $paths+=@($path)
        }
        $byPath[$plan.Path]=$plan; $byId[$id]=$plan; $targets[$plan.Path]=$paths
    }
    foreach ($plan in $Plans) {
        $previous=Get-LegacyValue $plan.Data 'Previous'
        if (-not $previous) { continue }
        $path=Get-LegacyValue $previous 'ContextPath'
        if (-not $path) { $Session.Pending.Add('Previous sem ContextPath: '+$plan.Path); $invalid=$true; continue }
        $path=Resolve-ProjectPath $path $Session.Workspace
        if (-not $byPath.ContainsKey($path) -or (Get-LegacyValue $previous 'RequestId') -cne (Get-LegacyValue $byPath[$path].Data 'RequestId')) {
            $Session.Pending.Add('Ancestral ausente ou de outra identidade: '+$plan.Path); $invalid=$true; continue
        }
        $childIssues=@(Get-ConversionIssueIds $plan.Data); $parentIssues=@(Get-ConversionIssueIds $byPath[$path].Data)
        if (-not $childIssues.Count -or -not $parentIssues.Count) {
            $Session.Pending.Add('Escopo inconclusivo em Previous; conferir escolhas e snapshot: '+$plan.Path); $invalid=$true
        } elseif (($childIssues -join "`n") -cne ($parentIssues -join "`n")) {
            $Session.Pending.Add('Previous muda o escopo de issues: '+$plan.Path); $invalid=$true
        }
        $parents[$plan.Path]=$path
        $children[$path]=@($children[$path])+@($plan.Path)
    }
    foreach ($start in $byPath.Keys) {
        $visited=@{}; $path=$start
        while ($path) {
            if ($visited.ContainsKey($path)) { $Session.Pending.Add('Ciclo em Previous: '+$path); $invalid=$true; break }
            $visited[$path]=$true; $path=$parents[$path]
        }
    }
    $selection='VINCULO_UNICO'; $seeds=@()
    if ($Contexto) {
        $path=Resolve-ProjectPath $Contexto $Session.Workspace
        if (-not $byPath.ContainsKey($path)) { throw 'Contexto escolhido nao pertence ao Source legado selecionado.' }
        $seeds=@($path); $selection='EXPLICITA'
    } elseif ($Register) {
        $notes=@($Register.Decisions | Where-Object Decision -EQ 'ANALISAR AGORA' | ForEach-Object Note) -join "`n"
        $outside=[regex]::Replace($Register.Text,'(?s)<!-- mta:inicio -->.*?<!-- mta:fim -->','')
        foreach ($text in @($notes,$outside)) {
            $links=@(Get-ConversionLinks $text $Register.Path $Session)
            $seeds=@(foreach ($path in $byPath.Keys) { if (@($targets[$path] | Where-Object { $_ -in $links }).Count) { $path } })
            $known=@(foreach ($paths in $targets.Values) { $paths })
            $broken=@($links | Where-Object { $_ -notin $known -and ($_ -match '[\\/]planning[\\/]' -or [IO.Path]::GetFileName($_) -match '^(plan|todo|context)(?:o)?(?:[-.]|$)') })
            if ($broken.Count) { $Session.Pending.Add('Vinculo de planejamento nao resolvido: '+($broken -join ', ')); $invalid=$true }
            if ($seeds.Count -or $broken.Count) { break }
        }
        if (-not $seeds.Count -and $Plans.Count) { $Session.Pending.Add('Sem vinculo explicito do registro ao plano; escolha Contexto antes de aplicar.') }
    }
    $tips=New-Object 'Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    foreach ($seed in $seeds) {
        $stack=New-Object 'Collections.Generic.Stack[string]'; $stack.Push($seed)
        $visited=@{}
        while ($stack.Count) {
            $path=$stack.Pop()
            if ($visited.ContainsKey($path)) { $Session.Pending.Add('Ciclo em Previous: '+$path); $invalid=$true; break }
            $visited[$path]=$true
            $next=@($children[$path] | Where-Object { $_ })
            if ($selection -eq 'EXPLICITA' -or -not $next.Count) { $null=$tips.Add($path) }
            else { foreach ($child in $next) { $stack.Push($child) } }
        }
    }
    # Sem vinculo, expor candidatos; nem um candidato unico comprova uso humano.
    $candidates=if ($seeds.Count) { @($tips | Sort-Object) } else { @($Plans | ForEach-Object Path | Sort-Object) }
    $chosen=if (-not $invalid -and $seeds.Count -and $tips.Count -eq 1) { $byPath[@($tips)[0]] } else { $null }
    if ($tips.Count -gt 1) { $Session.Pending.Add('Mais de uma ponta de planejamento vinculada; escolha Contexto explicitamente.') }
    if ($chosen) {
        $migration=Get-LegacyValue $chosen.Data 'MigrationPath'
        if (-not $Register -or ($migration -and (Resolve-ProjectPath $migration $Session.Workspace) -ine $Register.Path)) {
            $Session.Pending.Add('Plano sem registro selecionado ou MigrationPath divergente; confira associacao.'); $chosen=$null
        }
    }
    [pscustomobject]@{ContextPath=$(if ($chosen) {$chosen.Path} else {$null});Selection=$(if ($chosen) {$selection} elseif (-not $Plans.Count -and -not $invalid) {'SEM_PLANO'} else {'PENDENTE'});Candidates=$candidates;Record=$chosen}
}
