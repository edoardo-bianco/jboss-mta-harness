function Enter-SprintAccess {
    param([string]$Root)
    # Shared infrastructure mutex only; no directory, lock file or receipt is created.
    $folder=Resolve-ProjectPath '.harness/indices/sprints' $Root
    Enter-HarnessProjectAccess ([pscustomobject]@{Folder=$folder;TemporaryPath=(Join-Path $folder 'temporarios')}) -ReadOnly
}

function Get-SprintPaths {
    param($Master,[string]$Scenario)
    $relative='atual/sprints/'+(ConvertTo-HarnessFunctionalPath $Scenario)
    $directory=Resolve-ProjectPath $relative $Master.Folder
    if ((Join-Path $Master.TemporaryPath ('publicacao/depois/'+$relative+'/planejamento-sprints.json')).Length -ge 248) { throw 'Caminho do cenario longo; use nome funcional curto ou raiz de dados curta.' }
    [pscustomobject]@{Relative=$relative;ContextPath=(Join-Path $directory 'contexto.json');PromptPath=(Join-Path $directory 'planejar-sprints.prompt.md');ReviewPromptPath=(Join-Path $directory 'revisar-sprints.prompt.md');SprintDataPath=(Join-Path $directory 'planejamento-sprints.json');SprintPlanPath=(Join-Path $directory 'plano.md');ValidationPath=(Join-Path $directory 'resultado.json')}
}

function Get-SprintMaster {
    param([string]$Root,[string]$ContextPath)
    $path=Resolve-ProjectPath $ContextPath $Root
    $base=Resolve-ProjectPath '.harness/projetos' $Root
    if (-not $path.StartsWith($base+'\',[StringComparison]::OrdinalIgnoreCase)) { throw 'Contexto fora dos projetos correntes.' }
    $parts=$path.Substring($base.Length+1).Split('\')
    if ($parts.Count -ne 5 -or $parts[1] -cne 'atual' -or $parts[2] -cne 'sprints' -or $parts[4] -cne 'contexto.json') { throw 'Contexto fora do destino corrente de sprints.' }
    $folder=Join-Path $base $parts[0]
    $access=[pscustomobject]@{Folder=$folder;TemporaryPath=(Join-Path $folder 'temporarios')}
    $files=Read-HarnessProjectFiles $access @('projeto.json')
    if (-not $files['projeto.json']) { throw 'Associacao do projeto mestre ausente.' }
    $config=ConvertFrom-Json $files['projeto.json']
    $master=Get-HarnessProjectStorage $Root $config.pom
    if ($master.Folder -ine $folder) { throw 'POM diverge da pasta mestre de sprints.' }
    $master
}

function Read-HarnessSprintContext {
    param([string]$Root,[string]$ContextPath)
    $master=Get-SprintMaster $Root $ContextPath
    $path=Resolve-ProjectPath $ContextPath $Root
    $relative=$path.Substring($master.Folder.Length+1)
    $files=Read-HarnessProjectFiles $master @($relative)
    if (-not $files[$relative]) { throw 'Contexto corrente de sprints ausente.' }
    $current=ConvertFrom-Json $files[$relative]
    if ($current.SchemaVersion -ne 1 -or $current.Purpose -cne 'current-sprint-planning' -or $current.MasterProject -cne $master.Name) { throw 'Identidade do cenario corrente invalida.' }
    $expected=Get-SprintPaths $master $current.Scenario
    foreach ($field in @('ContextPath','PromptPath','ReviewPromptPath','SprintDataPath','SprintPlanPath','ValidationPath')) {
        if ((Resolve-ProjectPath $current.$field $Root) -ine $expected.$field) { throw 'Destino divergente no contexto corrente de sprints.' }
    }
    if ($current.ContextPath -ine $path -or $current.Projects -isnot [Array] -or -not $current.Projects.Count -or
        @($current.Projects | Group-Object Project | Where-Object Count -GT 1).Count -or
        @($current.Projects | Where-Object Project -CEQ $master.Name).Count -ne 1) { throw 'Participantes invalidos ou mestre fora do escopo.' }
    $current
}

function Get-HarnessSprintScenarios {
    param([string]$Root)
    $base=Resolve-ProjectPath '.harness/projetos' $Root
    if (-not (Test-Path -LiteralPath $base)) { return }
    foreach ($project in Get-ChildItem -LiteralPath $base -Directory | Sort-Object Name) {
        $directory=Resolve-ProjectPath (Join-Path $project.FullName 'atual/sprints') $Root
        if (-not (Test-Path -LiteralPath $directory)) { continue }
        foreach ($scenario in Get-ChildItem -LiteralPath $directory -Directory | Sort-Object Name) {
            $path=Join-Path $scenario.FullName 'contexto.json'
            if (Test-Path -LiteralPath $path) { Read-HarnessSprintContext $Root $path }
        }
    }
}

function Update-HarnessSprintIndex {
    param([string]$Root)
    $lease=Enter-SprintAccess $Root
    try {
    $scenarios=@(Get-HarnessSprintScenarios $Root)
    $base=Join-Path $Root '.harness/projetos'
    if (-not (Test-Path -LiteralPath $base)) { return }
    foreach ($folder in Get-ChildItem -LiteralPath $base -Directory | Sort-Object Name) {
        $association=Join-Path $folder.FullName 'projeto.json'
        if (-not (Test-Path -LiteralPath $association)) { continue }
        $config=Get-Content -LiteralPath $association -Raw -Encoding UTF8 | ConvertFrom-Json
        $project=Get-HarnessProjectStorage $Root $config.pom
        $old=Read-HarnessProjectFiles $project @('indice.md')
        $links=@(foreach ($scenario in $scenarios) {
            if ($project.Name -cin @($scenario.Projects.Project)) { '- '+(Get-HarnessSourceLink $project.IndexPath $scenario.SprintPlanPath ('Sprints: '+$scenario.Scenario+' (mestre '+$scenario.MasterProject+')')) }
        })
        if (-not $links.Count -and -not (Find-ProjectManagedBlock ([string]$old['indice.md']) 'sprints')) { continue }
        $text=if ($old['indice.md']) {$old['indice.md']} else {'# '+$project.Name}
        $text=Set-ProjectManagedBlock $text 'sprints' ($links -join [Environment]::NewLine)
        Publish-HarnessProjectFiles $project @{'indice.md'=$text} $old
    }
    } finally { $lease.ReleaseMutex(); $lease.Dispose() }
}

function New-SprintWorkTemplate {
    [pscustomobject][ordered]@{Id='atividade-1';Title='Descrever entrega';Phase='IMPLEMENTATION';Priority=$null;DependsOn=@();Issues=@();Effort=[ordered]@{Dev=@{Min=$null;Reference=$null;Max=$null};Architect=@{Min=$null;Reference=$null;Max=$null};DevOps=@{Min=$null;Reference=$null;Max=$null}};EstimateSource=$null;Confidence=$null;Assumptions=@();NotBefore=$null;Deadline=$null;Acceptance=$null;References=@();Remaining=$true;AllocationMode='ASAP';AiAssisted=$false}
}

function Get-SprintPrompt {
    param([string]$Template,[string]$Existing,[string]$Path,$Current,$Inputs)
    $header=[regex]::Match($Template,'(?s)^---\r?\n.*?\r?\n---\r?\n')
    $body=if ($header.Success) {$Template.Substring($header.Length)} else {$Template}
    $text=[regex]::Replace($Existing,'(?s)^---\r?\n.*?\r?\n---\r?\n','')
    $text=Set-ProjectManagedBlock $text 'sprints:orientacao' $body.Trim()
    $links=@('Cenario: '+$Current.Scenario,'Mestre: '+$Current.MasterProject,'ContextPath: '+$Current.ContextPath,
        (Get-HarnessSourceLink $Path $Current.SprintPlanPath 'Plano corrente'),
        (Get-HarnessSourceLink $Path $Current.SprintDataPath 'Premissas e estimativas editaveis'))
    $groups=[ordered]@{'Contrato e orientacoes correntes'=@($Inputs.References | Where-Object Kind -In @('Contrato','Indice geral'))}
    foreach ($participant in $Inputs.Projects) {
        $links+=Get-HarnessSourceLink $Path $participant.Source ('Codigo local - '+$participant.Project)
        $groups['Projeto: '+$participant.Project]=$participant.References
    }
    foreach ($label in $groups.Keys) {
        $links+='### '+$label
        foreach ($reference in $groups[$label]) {
            if ($reference.Kind -eq 'Associacao') { continue }
            if ($reference.Status -eq 'REFERENCIA EXTERNA') { $links+='- ['+$reference.Kind+'](<'+$reference.Path+'>)' }
            elseif ($reference.Status -eq 'DISPONIVEL' -or ($reference.Status -eq 'AUSENTE' -and (Test-Path -LiteralPath $reference.Path -PathType Container))) {
                $description=$reference.Kind+' - '+[IO.Path]::GetFileName($reference.Path)
                $links+='- '+(Get-HarnessSourceLink $Path $reference.Path $description)
            } else { $links+='- Fonte indisponivel ('+$reference.Kind+'): '+$reference.Path }
        }
    }
    $text=Set-ProjectManagedBlock $text 'sprints:fontes' ($links -join "`r`n`r`n")
    $header.Value+$text
}
