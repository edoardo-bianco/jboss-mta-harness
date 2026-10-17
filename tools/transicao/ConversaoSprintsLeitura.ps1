# Leitura da cadeia legada, sem eleger revisoes por data nem executar simulacao.
function Read-ConversionSprintJson($State,[string]$Path) {
    $text=Read-ConversionText $State.Inputs.Session $Path
    if (-not $text) { throw ('Documento de sprints ausente: '+$Path) }
    ConvertFrom-Json $text
}

function Assert-ConversionSprintHash($State,[string]$Path,[string]$Hash) {
    if (-not $Hash -or (Get-ConversionHash (Read-ConversionBytes $State $Path)) -cne $Hash) { throw ('Hash de sprints divergente: '+$Path) }
}

function Assert-ConversionSprintValidation($State,$Context,$Data) {
    $validation=Read-ConversionSprintJson $State $Context.ValidationPath
    if ($validation.SchemaVersion -ne 1 -or $validation.Purpose -cne 'sprint-planning-validation' -or $validation.Status -cne 'VALIDATED' -or
        $validation.PlanningId -cne $Context.PlanningId -or $validation.RevisionId -cne $Context.RevisionId -or
        $validation.ContextPath -ine $Context.ContextPath -or $validation.SprintPlanPath -ine $Context.SprintPlanPath) { throw 'Identidade da validacao de sprints divergente.' }
    foreach ($pair in @(@('ContextPath','ContextSha256'),@('SprintDataPath','DataSha256'),@('SprintPlanPath','PlanSha256'))) {
        Assert-ConversionSprintHash $State $Context.($pair[0]) $validation.($pair[1])
    }
    if (($validation.DataSnapshot|ConvertTo-Json -Depth 60 -Compress) -cne ($Data|ConvertTo-Json -Depth 60 -Compress) -or -not $Data.Simulation) { throw 'Snapshot da validacao de sprints diverge das premissas comprovadas.' }
}

function Read-ConversionSprintRevision($State,[string]$Path) {
    $path=Resolve-ProjectPath $Path $State.Project.Root
    $context=Read-ConversionSprintJson $State $path
    if ($context.SchemaVersion -ne 1 -or $context.Purpose -cne 'sprint-planning' -or
        $context.PlanningId -cnotmatch '^[a-f0-9]{32}$' -or $context.RevisionId -cnotmatch '^[a-f0-9]{32}$') { throw 'Identidade da revisao de sprints invalida.' }
    $directory=Join-Path $State.Inputs.Session.DataRoot ('sprints/'+$context.PlanningId+'/revisoes/'+$context.RevisionId)
    $names=@{ContextPath='contexto.json';PromptPath='planejar-sprints.prompt.md';ReviewPromptPath='revisar-sprints.prompt.md';SprintDataPath='planejamento-sprints.json';SprintPlanPath='planejamento-sprints.md';ValidationPath='validacao.json'}
    foreach ($field in $names.Keys) {
        $value=Get-LegacyValue $context $field
        if ($field -eq 'ReviewPromptPath' -and -not $value) { continue }
        if (-not $value -or (Resolve-ProjectPath $value $State.Project.Root) -ine (Join-Path $directory $names[$field])) { throw ('Destino divergente na revisao de sprints: '+$field) }
    }
    if ($path -ine $context.ContextPath) { throw 'Contexto de sprints diverge do caminho selecionado.' }
    $seal=Read-ConversionSprintJson $State (Join-Path $directory 'preparo.json')
    Assert-ConversionSprintHash $State $path $seal.ContextSha256
    $review=Get-LegacyValue $context 'ReviewPromptPath'
    if ($review) { Assert-ConversionSprintHash $State $review (Get-LegacyValue $seal 'ReviewPromptSha256') }
    $data=Read-ConversionSprintJson $State $context.SprintDataPath
    if ($data.SchemaVersion -ne 1 -or $data.Purpose -cne 'sprint-planning' -or $data.PlanningId -cne $context.PlanningId -or $data.RevisionId -cne $context.RevisionId) { throw 'Premissas de outra revisao de sprints.' }
    $markdown=Read-ConversionText $State.Inputs.Session $context.SprintPlanPath
    $block=Get-SprintCalculatedBlock $markdown
    if (Get-LegacyValue $data 'Simulation') {
        Assert-ConversionSprintValidation $State $context $data
    } else {
        $bytes=[Text.Encoding]::UTF8.GetBytes(($block|ConvertTo-Json -Depth 60 -Compress))
        if ((Get-ConversionHash $bytes) -cne $seal.CalculatedBlockSha256) { throw 'Bloco calculado de sprints alterado desde o preparo.' }
    }
    [pscustomobject]@{Context=$context;Data=$data;Markdown=$markdown}
}

function Read-ConversionSprintHistory($State,[string]$Path) {
    $chain=@(); $visited=@{}; $current=Read-ConversionSprintRevision $State $Path
    $planningId=$current.Context.PlanningId
    while ($current) {
        if ($visited.ContainsKey($current.Context.ContextPath)) { throw 'Ciclo na cadeia de sprints.' }
        $visited[$current.Context.ContextPath]=$true; $chain+=@($current)
        $previous=Get-LegacyValue $current.Context 'Previous'
        if (-not $previous) { break }
        $parent=Read-ConversionSprintRevision $State $previous.ContextPath
        if ($previous.PlanningId -cne $planningId -or $parent.Context.PlanningId -cne $planningId -or $parent.Context.RevisionId -cne $previous.RevisionId) { throw 'Ancestral de sprints divergente.' }
        foreach ($field in @('SprintDataPath','SprintPlanPath')) {
            if ((Resolve-ProjectPath $previous.$field $State.Project.Root) -ine $parent.Context.$field) { throw 'Caminho ancestral de sprints divergente.' }
        }
        Assert-ConversionSprintHash $State $previous.SprintDataPath $previous.DataSha256
        Assert-ConversionSprintHash $State $previous.SprintPlanPath $previous.PlanSha256
        $current=$parent
    }
    $pointerPath=Join-Path $State.Inputs.Session.DataRoot ('sprints/'+$planningId+'/atual.json')
    $pointerText=Read-ConversionText $State.Inputs.Session $pointerPath
    $published=$null
    if ($pointerText) {
        $pointer=ConvertFrom-Json $pointerText
        $matches=@($chain | Where-Object { $_.Context.ContextPath -ieq $pointer.ContextPath -and $_.Context.RevisionId -ceq $pointer.RevisionId })
        if ($pointer.PlanningId -cne $planningId -or $matches.Count -ne 1) { throw 'Ponteiro publicado de sprints fora da cadeia ancestral escolhida.' }
        $proven=$matches[0]
        if ($pointer.ValidationPath -ine $proven.Context.ValidationPath) { throw 'Ponteiro de validacao de sprints divergente.' }
        Assert-ConversionSprintHash $State $pointer.ValidationPath $pointer.ValidationSha256
        Assert-ConversionSprintValidation $State $proven.Context $proven.Data
        $published=$proven
    } elseif (@($chain | Where-Object { Get-LegacyValue $_.Data 'Simulation' }).Count) { throw 'Historico calculado de sprints sem ponteiro de validacao comprovado; concilie a cadeia antes de converter.' }
    [pscustomobject]@{Selected=$chain[0];Chain=$chain;Published=$published}
}

function Read-ConversionSprints($State,$Choices) {
    $chosen=@{}; $names=@{}; $scenarios=@{}
    foreach ($choiceValue in $Choices) {
        $choice=[pscustomobject]$choiceValue
        $scenario=[string](Get-LegacyValue $choice 'Cenario')
        $masterPom=[string](Get-LegacyValue $choice 'MestrePom')
        if ([string]::IsNullOrWhiteSpace($scenario)) { throw 'Cenario de sprints exige nome funcional explicito.' }
        if (-not $masterPom) { throw 'Cenario de sprints exige MestrePom explicito.' }
        $contextPath=[string](Get-LegacyValue $choice 'Contexto')
        if (-not $contextPath) { throw 'Cenario de sprints exige Contexto explicito.' }
        $history=Read-ConversionSprintHistory $State $contextPath
        $context=$history.Selected.Context
        if ($chosen.ContainsKey($context.PlanningId)) { throw 'Cadeia de sprints selecionada mais de uma vez.' }
        $chosen[$context.PlanningId]=$true
        $participants=@(foreach ($legacy in $context.Projects) {
            $source=Resolve-ProjectPath $legacy.Source $State.Project.Root
            $matches=@($State.Participants | Where-Object LegacySource -IEQ $source)
            if ($matches.Count -ne 1) { throw ('Associe explicitamente o participante de sprints ao POM local: '+$source) }
            $matches[0]
        })
        if (-not $participants.Count -or @($participants | Group-Object LegacySource | Where-Object Count -GT 1).Count) { throw 'Participantes de sprints vazios ou duplicados.' }
        $pom=Resolve-ProjectPath $masterPom $State.Project.Root
        $masters=@($participants | Where-Object { $_.Project.Pom -ieq $pom })
        if ($masters.Count -ne 1) { throw 'Mestre de sprints deve participar do cenario.' }
        $master=$masters[0].Project; $paths=Get-SprintPaths $master $scenario
        $functional=Split-Path (Split-Path $paths.ContextPath -Parent) -Leaf
        if ($names.ContainsKey($functional)) { throw 'Nome funcional de cenario duplicado.' }
        $names[$functional]=$true
        foreach ($existing in @(Get-HarnessSprintScenarios $State.Project.Root | Where-Object Scenario -CEQ $scenario)) {
            if ($existing.ContextPath -ine $paths.ContextPath) { throw 'Cenario ja possui outro mestre; concilie antes da conversao.' }
        }
        foreach ($revision in $history.Chain) {
            foreach ($field in @('ContextPath','SprintDataPath','SprintPlanPath','ValidationPath','PromptPath','ReviewPromptPath')) {
                $origin=Get-LegacyValue $revision.Context $field
                if ($origin) { $State.Map[(Resolve-ProjectPath $origin $State.Project.Root)]=$paths.$field }
            }
        }
        $scenarios[$functional]=[pscustomobject]@{Scenario=$scenario;Master=$master;Participants=$participants;Paths=$paths;History=$history}
    }
    foreach ($record in @($State.Inputs.Records | Where-Object Kind -EQ 'SPRINT')) {
        if (-not $chosen.ContainsKey($record.Data.PlanningId)) { throw 'Selecione nome, mestre e Contexto para cada cadeia de sprints antes de aplicar.' }
    }
    # A ordem das escolhas humanas nao muda proprietarios de anexos ou indices.
    $ordered=[string[]]@($scenarios.Keys); [Array]::Sort($ordered,[StringComparer]::Ordinal)
    foreach ($name in $ordered) { $scenarios[$name] }
}
