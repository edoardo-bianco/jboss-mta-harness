# Funcoes privadas do modulo HarnessPlanning; entradas sao dados, nunca comandos.
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

function Select-HarnessPlanningRegister {
    param($Context, [string]$MigrationPath, [string]$Target, [switch]$Interactive)
    $projects = @($Context.Projects)
    if ($Target) {
        $projects=@($projects | Where-Object { $_.label -ieq $Target -or $_.name -ieq $Target -or $_.path -ieq $Target })
        if ($projects.Count -ne 1) { throw 'Target ausente ou ambiguo no workspace/config selecionado.' }
    }
    $candidates = @(foreach ($project in $projects) {
        $paths = Get-HarnessMigrationPaths $Context.Root $project
        if ($MigrationPath -and (Resolve-HarnessPath $MigrationPath $Context.Root) -ine $paths.MigrationPath) { continue }
        if (-not (Test-Path -LiteralPath $paths.MigrationPath -PathType Leaf)) { continue }
        try {
            $register = Read-HarnessMigrationInput $Context.Root $project $paths.MigrationPath
            $chosen = @($register.Rows | Where-Object Decision -eq 'ANALISAR AGORA')
            if ($MigrationPath -or $Target -or $chosen.Count) { [pscustomobject]@{Project=$project;Register=$register} }
        } catch {
            if ($MigrationPath -or $Target) { throw }
            Write-Warning ("$($project.label): " + $_.Exception.Message)
        }
    })
    if (-not $candidates.Count) { throw 'Nenhum registro escolhido encontrado. Execute Workspace: atualizar indice dos projetos se faltar migracao.md; marque Decisao=ANALISAR AGORA na issue desejada.' }
    if ($candidates.Count -gt 1) {
        if (-not $Interactive) { throw 'Mais de um registro escolhido: informe MigrationPath ou Target. Nenhum projeto foi selecionado automaticamente.' }
        for ($i=0; $i -lt $candidates.Count; $i++) { Write-Host ("{0}. {1} | {2}" -f ($i+1),$candidates[$i].Project.label,$candidates[$i].Register.MigrationPath) }
        $answer = Read-Host 'Qual registro deseja planejar? Numero; q cancela'
        $choice = 0
        if (-not [int]::TryParse($answer,[ref]$choice) -or $choice -lt 1 -or $choice -gt $candidates.Count) { throw 'Selecao cancelada; nenhum contexto preparado.' }
        $selected = $candidates[$choice-1]
    } else { $selected = $candidates[0] }
    $Context.Active = $selected.Project
    $selected.Register
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

function Get-HarnessPlanningRequestResult {
    param($Receipt, [switch]$Reused)
    $prompt = Join-Path (Split-Path $Receipt.ContextPath -Parent) 'planejar-lotes.prompt.md'
    if (-not (Test-Path -LiteralPath $prompt -PathType Leaf)) { throw 'Prompt da solicitacao ausente; preserve o recibo e confira esta solicitacao.' }
    [pscustomobject]@{RequestId=$Receipt.RequestId;Project=$Receipt.Project;RunId=$Receipt.RunId;PlanningBasis=(Get-HarnessPlanningBasis $Receipt);MigrationPath=$Receipt.MigrationPath;ContextPath=$Receipt.ContextPath;PromptPath=$prompt;PlanPath=$Receipt.PlanPath;TodoPath=$Receipt.TodoPath;EvidenceIndexPath=$Receipt.EvidenceIndexPath;Reused=[bool]$Reused}
}

function Invoke-HarnessRegisteredPlanningCore {
    param($Context, [string]$MigrationPath, [string]$ContextPath, [string]$RequestId,
        [string]$Target, [string]$EvidenceIndexPath, [string]$PreviousRequestId,
        [switch]$NewPlan, [switch]$Interactive, [switch]$ValidateOnly)
    if ($ContextPath -and $RequestId) { throw 'Use ContextPath ou RequestId, nao ambos.' }
    if ($PreviousRequestId -and $NewPlan) { throw 'Use PreviousRequestId ou NewPlan, nao ambos.' }
    if (($ContextPath -or $RequestId) -and ($NewPlan -or $PreviousRequestId)) { throw 'Retomar contexto nao pode selecionar nova solicitacao ao mesmo tempo.' }
    $receipt=$null
    if ($ContextPath -or $RequestId) {
        $matches = @(foreach ($project in $Context.Projects) {
            $lookup = [pscustomobject]@{Root=$Context.Root;Active=$project}
            foreach ($item in @(Get-MtaPlanningHistory $lookup -IncludePrepared)) {
                if (($RequestId -and $item.RequestId -ceq $RequestId) -or ($ContextPath -and (Resolve-HarnessPath $ContextPath $Context.Root) -ieq (Resolve-HarnessPath $item.ContextPath $Context.Root))) { $item }
            }
        })
        if ($matches.Count -ne 1) { throw 'Solicitacao ausente ou ambigua no workspace. Informe o recibo correto; nenhuma solicitacao foi escolhida pela recencia.' }
        $receipt=$matches[0]
        if ($MigrationPath -and (Resolve-HarnessPath $MigrationPath $Context.Root) -ine (Resolve-HarnessPath $receipt.MigrationPath $Context.Root)) { throw 'MigrationPath diverge do contexto selecionado.' }
        $MigrationPath=$receipt.MigrationPath
    }
    $register = Select-HarnessPlanningRegister $Context -MigrationPath $MigrationPath -Target $Target -Interactive:$Interactive
    $chosen=@($register.Rows | Where-Object Decision -eq 'ANALISAR AGORA')
    if (-not $chosen.Count) { throw 'Marque Decisao=ANALISAR AGORA nas issues desejadas no registro antes de planejar.' }
    if (@($chosen | Where-Object Progress -in @('IMPLEMENTADA','VERIFICADA')).Count) {
        Write-Warning 'Escolha inclui trabalho implementado/verificado. O agente deve conferir o direcionamento humano por ID antes de reabrir a proposta; o preparo preserva o andamento.'
    }
    $history=@(Get-MtaPlanningHistory $Context -IncludePrepared)
    if (-not $NewPlan -and -not $PreviousRequestId) {
        if ($receipt) {
            $linked=@($receipt)
            $options=@($receipt)
        } else {
        $linkText=($chosen | ForEach-Object Observation) -join "`n"
        if ($linkText -notmatch '(plan|todo|contexto?)(?:-[^\\/\)]*)?\.(md|json)') { $linkText=[regex]::Replace($register.Text,'(?s)<!-- mta:inicio -->.*?<!-- mta:fim -->','') }
        $links=@(foreach ($match in [regex]::Matches($linkText,'\[[^\]]*\]\(<?([^>\)]+)>?\)')) {
            $value=($match.Groups[1].Value -split '#',2)[0]
            if ($value -match '(?:^|[\\/])(plan|todo|contexto?)(?:-[^\\/]*)?\.(md|json)$') { Resolve-HarnessPath ([Uri]::UnescapeDataString($value)) (Split-Path $register.MigrationPath -Parent) }
        })
        $linked=@($history | Where-Object { (Resolve-HarnessPath $_.ContextPath $Context.Root) -in $links -or (Resolve-HarnessPath $_.PlanPath $Context.Root) -in $links -or (Resolve-HarnessPath $_.TodoPath $Context.Root) -in $links })
        if ($links.Count -and -not $linked.Count) { throw 'Referencia de plano no registro nao localiza uma solicitacao valida. Confira o caminho indicado; nao sera criado outro lote silenciosamente.' }
        $options=if ($linked.Count) { @($linked) } else { @($history | Where-Object {
            $item=$_
            $ids=if ($item.PSObject.Properties['SelectedIssues'] -and @($item.SelectedIssues).Count) { @($item.SelectedIssues | ForEach-Object Id) }
                else { @([regex]::Matches($item.MigrationSnapshot,'(?m)^\|\s*([^|]+)\|[^\r\n]*\|\s*ANALISAR AGORA\s*\|') | ForEach-Object { $_.Groups[1].Value.Trim() }) }
            $item.MigrationPath -and (Resolve-HarnessPath $item.MigrationPath $Context.Root) -ieq $register.MigrationPath -and @($chosen | Where-Object { $_.Id -in $ids }).Count
        }) }
        }
        $options=@($options)
        # O registro pode continuar apontando a base ate o agente escrever o plano.
        # Siga somente a linhagem Previous desse lote, nunca a data de criacao.
        if ($linked.Count) {
            do {
                $known=@($options | ForEach-Object RequestId)
                $children=@($history | Where-Object { $_.Previous -and $_.Previous.RequestId -in $known -and $_.RequestId -notin $known })
                $options+= $children
            } while ($children.Count)
        }
        # Sucessao explicita, nao recencia: uma revisao referencia a base anterior.
        $superseded=@($options | Where-Object { $_.Previous } | ForEach-Object { $_.Previous.RequestId })
        $options=@($options | Where-Object { $_.RequestId -notin $superseded })
        if (-not $options.Count -and $history.Count) { throw 'A escolha atual nao identifica um plano anterior. Informe ContextPath para revisar o lote escolhido ou NewPlan para iniciar outro apos o aceite; nao sera retomado um lote alheio.' }
        if ($options.Count -gt 1) {
            if (-not $Interactive) { throw 'Ha varias solicitacoes para o registro; informe ContextPath ou RequestId para retomar.' }
            for ($i=0; $i -lt $options.Count; $i++) { Write-Host ("{0}. {1} | {2}" -f ($i+1),$options[$i].RequestId,$options[$i].PlanPath) }
            $answer=Read-Host 'Qual proposta deseja continuar? Numero; q cancela'
            $choice=0
            if (-not [int]::TryParse($answer,[ref]$choice) -or $choice -lt 1 -or $choice -gt $options.Count) { throw 'Selecao cancelada; nenhum contexto preparado.' }
            $receipt=$options[$choice-1]
        } elseif ($options.Count -eq 1) { $receipt=$options[0] }
    }
    if ($receipt) {
        if ($receipt.Project -cne $Context.Active.name -or (Resolve-HarnessPath $receipt.Source $Context.Root) -ine $Context.Active.path) { throw 'Registro e solicitacao pertencem a projetos diferentes.' }
        if ($receipt.PSObject.Properties['LayoutVersion'] -and ($chosen.Count -ne 1 -or $chosen[0].Id -cne $receipt.IssueId)) {
            throw 'A solicitacao pertence a uma issue. Preserve essa escolha para revisar ou use NewPlan para a outra issue; nao misturar dossies.'
        }
        if ($receipt.PSObject.Properties['ImportedFrom'] -and $receipt.EvidenceMode -eq 'CONSOLIDATED') {
            $markers=[regex]::Matches($receipt.MigrationSnapshot,'(?m)^<!-- MTA (\{[^\r\n]+\}) -->\s*$')
            $frozenOrigin=if ($markers.Count -eq 1) { $markers[0].Groups[1].Value | ConvertFrom-Json } else { $null }
            $currentBasis=if ($register.Origin) { 'MTA' } else { 'EVIDENCIAS' }
            if ($currentBasis -ne (Get-HarnessPlanningBasis $receipt) -or
                ($register.Origin | ConvertTo-Json -Depth 30 -Compress) -cne ($frozenOrigin | ConvertTo-Json -Depth 30 -Compress)) {
                throw 'Origem da proposta importada mudou no registro. Reavalie a base antes de retomar; nao reutilizar silenciosamente.'
            }
            $index=Get-IssueEvidenceIndex $Context $register $EvidenceIndexPath
            $inputs=@(Get-HarnessPlanningEvidenceInputs $Context.Root $register $index)
            if (($inputs | ConvertTo-Json -Depth 5 -Compress) -cne ($receipt.SourceEvidenceInputs | ConvertTo-Json -Depth 5 -Compress)) {
                throw 'Entradas locais da proposta importada mudaram. Reavalie com a origem MTA quando aplicavel; nao reutilizar a proposta nem trocar sua base silenciosamente.'
            }
            if ($receipt.ContractSnapshot -cne [IO.File]::ReadAllText((Join-Path $Context.Root 'doc/especificacoes/planejamento-copilot.md')) -or
                $receipt.PromptSha256 -cne (Get-FileHash -LiteralPath (Join-Path $Context.Root '.github/prompts/planejar-lotes.prompt.md')).Hash) {
                throw 'Contrato/template da proposta importada difere do atual. Reavalie a proposta antes de preparar outro planejamento.'
            }
            Assert-HarnessPlanningEvidence $receipt $Context.Root
            if ($ValidateOnly) { return }
            return Get-HarnessPlanningRequestResult $receipt -Reused
        }
        $run=Get-HarnessRegisteredMtaRun $register $Context.Root
        $basis=if ($run) { 'MTA' } else { 'EVIDENCIAS' }
        $sameBase=(Get-HarnessPlanningBasis $receipt) -eq $basis -and
            (($basis -eq 'EVIDENCIAS') -or ($run.RunId -ceq $receipt.RunId -and (Resolve-HarnessPath $receipt.Run $Context.Root) -ieq $run.Run))
        $index=Get-IssueEvidenceIndex $Context $register $EvidenceIndexPath
        $inputs=@(Get-HarnessPlanningEvidenceInputs $Context.Root $register $index)
        if ($receipt.PSObject.Properties['EvidenceInputs']) {
            $originalInputs=if ($receipt.PSObject.Properties['SourceEvidenceInputs']) { @($receipt.SourceEvidenceInputs) } else { @($receipt.EvidenceInputs) }
            $sameBase=$sameBase -and (($inputs | ConvertTo-Json -Depth 5 -Compress) -ceq ($originalInputs | ConvertTo-Json -Depth 5 -Compress))
        }
        $sameBase=$sameBase -and $receipt.PSObject.Properties['PlanningBasis'] -and
            $receipt.ContractSnapshot -ceq [IO.File]::ReadAllText((Join-Path $Context.Root 'doc/especificacoes/planejamento-copilot.md')) -and
            $receipt.PromptSha256 -ceq (Get-FileHash -LiteralPath (Join-Path $Context.Root '.github/prompts/planejar-lotes.prompt.md') -Algorithm SHA256).Hash
        if ($sameBase) {
            Assert-HarnessPlanningEvidence $receipt $Context.Root
            if ($ValidateOnly) { return }
            return Get-HarnessPlanningRequestResult $receipt -Reused
        }
        $PreviousRequestId=$receipt.RequestId
    }
    New-MtaPlanningContextCore $Context -MigrationPath $register.MigrationPath -EvidenceIndexPath $EvidenceIndexPath -PreviousRequestId $PreviousRequestId -Operation 'planejar-lotes' -ValidateOnly:$ValidateOnly
}

function Invoke-HarnessRegisteredPlanning {
    param($Context, [string]$MigrationPath, [string]$ContextPath, [string]$RequestId,
        [string]$Target, [string]$EvidenceIndexPath, [string]$PreviousRequestId,
        [switch]$NewPlan, [switch]$Interactive, [switch]$ValidateOnly)
    if ($ValidateOnly) { Invoke-HarnessRegisteredPlanningCore @PSBoundParameters; return }
    $state=Resolve-HarnessPath (Join-Path $Context.Root '.harness') $Context.Root
    $null=[IO.Directory]::CreateDirectory($state)
    try { $lease=[IO.File]::Open((Join-Path $state 'planning.lock'),'OpenOrCreate','ReadWrite','None') }
    catch { throw 'Existe preparacao de contexto ou limpeza em andamento.' }
    try { Invoke-HarnessRegisteredPlanningCore @PSBoundParameters }
    finally { $lease.Dispose() }
}

function Invoke-HarnessRegisteredPreparation {
    param([string]$Root, [System.Collections.IDictionary]$Choices)
    $response=[ordered]@{SchemaVersion=1;Operation='planejar-lotes';Status='FAILED';ExitCode=1;Project=$null;Source=$null;RunId=$null;RequestId=$null;
        Artifacts=[ordered]@{PromptPath=$null;ContextPath=$null;PlanPath=$null;TodoPath=$null;MigrationPath=$null;EvidenceIndexPath=$null};
        WritesStarted=$false;ChangedFiles=@();ChangesVerified=$true;Diagnostics=@();Error=$null}
    try {
        if (-not $Choices['NonInteractive'] -or -not $Choices['NoOpen']) { throw 'Use NonInteractive e NoOpen para preparo estruturado.' }
        if ($Choices['SelectTarget'] -or $Choices['SelectOperation'] -or $Choices['SelectMigrationInput'] -or $Choices['EditorPath'] -or $Choices['RunId'] -or $Choices['RunPath'] -or $Choices['WithoutMta'] -or $Choices['MigrationSourcePath'] -or ($Choices['Operation'] -and $Choices['Operation'] -ne 'planejar-lotes')) {
            throw 'Preparo pelo registro nao aceita seletores ou troca de MTA/operacao. Use manter-migracao explicitamente para trocar a base.'
        }
        & {
            $configPath=if ($Choices['ConfigPath']) { $Choices['ConfigPath'] } else { Join-Path $Root 'config/harness.local.json' }
            $context=Read-HarnessConfig $configPath $Root -WorkspacePath $Choices['WorkspacePath'] -Target $Choices['Target'] -SkipMigrationInitialization
            $parameters=@{Context=$context}
            foreach ($key in @('MigrationPath','ContextPath','RequestId','Target','EvidenceIndexPath','PreviousRequestId','NewPlan')) {
                if ($key -in @($Choices.Keys)) { $parameters[$key]=$Choices[$key] }
            }
            $null=Invoke-HarnessRegisteredPlanning @parameters -ValidateOnly
            $response.Project=$context.Active.name; $response.Source=$context.Active.path
            $state=Resolve-HarnessPath (Join-Path $Root '.harness') $Root
            $null=[IO.Directory]::CreateDirectory($state)
            try { $lease=[IO.File]::Open((Join-Path $state 'planning.lock'),'OpenOrCreate','ReadWrite','None') }
            catch { throw 'Existe preparacao de contexto ou limpeza em andamento.' }
            try {
              $before=Get-MtaPreparationFileState $context
              try {
                $response.WritesStarted=$true
                $prepared=Invoke-HarnessRegisteredPlanningCore @parameters
                $receipt=Get-Content -LiteralPath $prepared.ContextPath -Raw -Encoding UTF8 | ConvertFrom-Json
                foreach ($key in @($response.Artifacts.Keys)) { if ($receipt.PSObject.Properties[$key]) { $response.Artifacts[$key]=$receipt.$key } }
                $response.Artifacts.PromptPath=$prepared.PromptPath
                $response.RunId=$receipt.RunId; $response.RequestId=$receipt.RequestId
                $response.Status='PREPARED'; $response.ExitCode=0
              } finally {
                $after=Get-MtaPreparationFileState $context
                $response.ChangedFiles=@(foreach ($path in @($after.Keys | Sort-Object)) {
                    if (-not $before.ContainsKey($path)) { [pscustomobject]@{Path=$path;Change='Created'} }
                    elseif ($before[$path] -cne $after[$path]) { [pscustomobject]@{Path=$path;Change='Modified'} }
                })
                if (-not $response.ChangedFiles.Count) { $response.WritesStarted=$false }
              }
            } finally { $lease.Dispose() }
        } 3>&1 6>&1 | ForEach-Object { $response.Diagnostics += [string]$_ }
    } catch {
        $response.Status='FAILED'; $response.ExitCode=1
        if ($response.WritesStarted) { $response.ChangesVerified=$false }
        $response.Error=[ordered]@{Code='PREPARATION_FAILED';Message=$_.Exception.Message;MissingInputs=@()}
    }
    [pscustomobject]$response
}
