function Get-HarnessIssueProgressStates {
    # A mesma tabela fornece a ordem ao calculo e as definicoes aos documentos.
    $legend=Expand-HarnessDocumentTemplate 'legenda-andamento'
    foreach ($match in [regex]::Matches($legend,'(?m)^\| ([A-Z ]+) \| ([^\r\n]+) \|\r?$')) {
        [pscustomobject]@{Name=$match.Groups[1].Value;Definition=$match.Groups[2].Value}
    }
}

function Format-HarnessIssuePercent {
    param($Percent)
    if ($null -eq $Percent) { return '-' }
    $Percent.ToString('F2',[Globalization.CultureInfo]::GetCultureInfo('pt-BR'))+'%'
}

function Get-HarnessIssueProgressText {
    param($Progress,[string]$From,[string]$MigrationPath)
    $lines=@('## Andamento registrado','','| Origem / categoria | Andamento | Quantidade | Percentual | Total da categoria | Issues no registro |',
        '| --- | --- | --- | --- | --- | --- |')
    foreach ($group in $Progress.Groups) {
        $category=ConvertTo-ProjectCell ($group.Origin+' / '+$group.Category)
        foreach ($entry in $group.States) {
            $state=if ($entry.Known) { $entry.State } elseif ($entry.State) { 'Lacuna: '+(ConvertTo-ProjectCell $entry.State) } else { 'Lacuna: estado vazio' }
            $members=@(foreach ($row in $entry.Rows) {
                $label=ConvertTo-ProjectCell $row.Id
                $path=$MigrationPath
                if ($row.PSObject.Properties['Project']) { $label=(ConvertTo-ProjectCell $row.Project)+' / '+$label; $path=$row.MigrationPath }
                Get-HarnessSourceLink $From $path $label
            })
            $links=if ($members.Count) { $members -join ', ' } else { '-' }
            $lines+='| '+$category+' | '+$state+' | '+$entry.Count+' | '+(Format-HarnessIssuePercent $entry.Percent)+' | '+$group.Total+' | '+$links+' |'
        }
    }
    if (-not $Progress.Groups.Count) { $lines+='| Sem issues registradas | - | 0 | - | 0 | - |' }
    $lines+=@('',('Indicadores separados, com sobreposicao: ADIAR: '+$Progress.Deferred+'; FORA DO ESCOPO: '+$Progress.OutOfScope+'; NAO REENCONTRADA: '+$Progress.NotFound+'.'),'',(Expand-HarnessDocumentTemplate 'legenda-andamento').TrimEnd())
    $lines -join "`n"
}

function Set-HarnessIssueProgressBlock {
    param([string]$Text,[string]$Content)
    $old=Find-ProjectManagedBlock $Text 'issues:andamento'
    # Repeticao equivalente nao muda a data nem regrava documentos humanos.
    if ($old) {
        $previous=$old.Value -replace '(?m)^Calculado em [^\r\n]+\r?\n',''
        $candidate=(Set-ProjectManagedBlock '' 'issues:andamento' $Content).Trim()
        if ($previous.Replace("`r`n","`n").Trim() -ceq $candidate.Replace("`r`n","`n")) { return $Text }
    }
    Set-ProjectManagedBlock $Text 'issues:andamento' ('Calculado em '+[DateTime]::UtcNow.ToString('yyyy-MM-dd HH:mm:ss')+" UTC; retrata o registro lido.`n"+$Content)
}

function Get-HarnessIssueProgressCompact {
    param($Progress,[string]$From,[string]$MigrationPath)
    if ($null -eq $Progress) { return 'Indisponivel: registro nao lido' }
    if (-not $Progress.Groups.Count) { return 'Sem issues registradas: 0 / -' }
    $lines=@(foreach ($group in $Progress.Groups) {
        $values=@(foreach ($entry in $group.States) {
            if (-not $entry.Count) { continue }
            $state=if ($entry.Known) { $entry.State } elseif ($entry.State) { 'Lacuna: '+$entry.State } else { 'Lacuna: estado vazio' }
            (ConvertTo-ProjectCell $state)+': '+$entry.Count+' ('+(Format-HarnessIssuePercent $entry.Percent)+')'
        })
        (ConvertTo-ProjectCell ($group.Origin+' / '+$group.Category))+': total '+$group.Total+'; '+($values -join '; ')
    })
    ($lines -join '<br>')+'<br>'+(Get-HarnessSourceLink $From $MigrationPath 'Detalhar issues')
}

function Get-HarnessWorkspaceProgressText {
    param([object[]]$Rows,[string[]]$ReadProjects,[string[]]$MissingProjects,[string]$From)
    $coverage='Registros de andamento lidos: '+$ReadProjects.Count+' de '+($ReadProjects.Count+$MissingProjects.Count)+'.'
    if ($ReadProjects.Count) { $coverage+=' Projetos: '+(ConvertTo-ProjectCell ($ReadProjects -join ', '))+'.' }
    if ($MissingProjects.Count) { $coverage+=' Consolidacao parcial; indisponiveis: '+(ConvertTo-ProjectCell ($MissingProjects -join ', '))+'.' }
    if (-not $ReadProjects.Count) { return $coverage+"`n`nAndamento indisponivel; nenhum registro lido.`n`n"+(Expand-HarnessDocumentTemplate 'legenda-andamento') }
    $coverage+"`n`n"+(Get-HarnessIssueProgressText (Get-HarnessIssueProgress -Rows $Rows) $From '')
}

function Get-HarnessIssueProgress {
    param([object[]]$Rows=@(),[object[]]$Categories=@())
    $states=@(Get-HarnessIssueProgressStates | ForEach-Object Name)
    $groups=New-Object 'Collections.Generic.Dictionary[string,object]' ([StringComparer]::Ordinal)
    $seen=New-Object 'Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
    $deferred=0; $outside=0; $notFound=0
    foreach ($category in $Categories) {
        $key=$category.Origin+':'+$category.Category
        if (-not $groups.ContainsKey($key)) { $groups.Add($key,[pscustomobject]@{Origin=$category.Origin;Category=$category.Category;Rows=(New-Object 'Collections.Generic.List[object]')}) }
    }
    foreach ($row in $Rows) {
        $project=if ($row.PSObject.Properties['Project']) { [string]$row.Project } else { '' }
        if ([string]::IsNullOrWhiteSpace($row.Id) -or -not $seen.Add($project+[char]0+$row.Id)) { throw 'Identidade de issue vazia/duplicada; resumo indisponivel.' }
        $origin=if ($row.Presence -ceq 'MANUAL') { 'manual' } else { 'MTA' }
        $key=$origin+':'+$row.Category
        if (-not $groups.ContainsKey($key)) { $groups.Add($key,[pscustomobject]@{Origin=$origin;Category=$row.Category;Rows=(New-Object 'Collections.Generic.List[object]')}) }
        $groups[$key].Rows.Add($row)
        if ($row.Decision -ceq 'ADIAR') { $deferred++ }
        if ($row.Decision -ceq 'FORA DO ESCOPO') { $outside++ }
        if ($row.Presence -ceq 'NAO REENCONTRADA') { $notFound++ }
    }
    $result=@(foreach ($key in @($groups.Keys | Sort-Object -CaseSensitive)) {
        $group=$groups[$key]; $total=$group.Rows.Count
        $unknown=@($group.Rows | ForEach-Object { [string]$_.Progress } | Where-Object { $_ -cnotin $states } | Sort-Object -Unique -CaseSensitive)
        $entries=@(foreach ($state in @($states)+@($unknown)) {
            $members=@($group.Rows | Where-Object { [string]$_.Progress -ceq $state })
            [pscustomobject]@{State=$state;Known=($state -cin $states);Count=$members.Count;
                Percent=if ($total) { [math]::Round(100.0*$members.Count/$total,2) } else { $null };
                Ids=@($members | ForEach-Object Id);Rows=$members}
        })
        [pscustomobject]@{Origin=$group.Origin;Category=$group.Category;Total=$total;States=$entries}
    })
    [pscustomobject]@{Total=$Rows.Count;Groups=$result;Deferred=$deferred;OutOfScope=$outside;NotFound=$notFound}
}
