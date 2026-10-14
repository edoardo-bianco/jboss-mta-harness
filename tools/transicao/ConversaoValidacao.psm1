#requires -Version 5.1
# Conferencia independente: importa somente consumidores do contrato corrente.
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot '../../scripts/HarnessProject.psm1') -DisableNameChecking
Import-Module (Join-Path $PSScriptRoot '../../scripts/HarnessPlanning.psm1') -DisableNameChecking
. (Join-Path $PSScriptRoot '../../scripts/HarnessIssueSources.ps1')
. (Join-Path $PSScriptRoot '../../scripts/HarnessPrioritizationState.ps1')
. (Join-Path $PSScriptRoot '../../scripts/HarnessSprintState.ps1')
. (Join-Path $PSScriptRoot '../../scripts/HarnessSprintPresentation.ps1')
. (Join-Path $PSScriptRoot '../../scripts/HarnessSprintSimulation.ps1')
. (Join-Path $PSScriptRoot '../../scripts/HarnessSprintSources.ps1')
. (Join-Path $PSScriptRoot '../../scripts/HarnessSprintValidation.ps1')

function Get-CurrentValidationValue($Object,[string]$Name,$Default=$null) {
    if ($null -ne $Object -and $Object.PSObject.Properties[$Name]) { return $Object.$Name }
    $Default
}

function Get-CurrentValidationFiles($Project) {
    if (-not (Test-Path -LiteralPath $Project.Folder -PathType Container)) { throw 'Projeto corrente ausente.' }
    $queue=New-Object 'Collections.Generic.Queue[string]'; $queue.Enqueue($Project.Folder)
    while ($queue.Count) {
        foreach ($item in Get-ChildItem -LiteralPath $queue.Dequeue() -Force) {
            $path=Resolve-ProjectPath $item.FullName $Project.Root
            if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Link/junction no projeto corrente.' }
            if ($item.PSIsContainer) {
                if ($item.Parent.FullName -ieq $Project.Folder -and $item.Name -in @('recebido','temporarios')) { continue }
                $queue.Enqueue($path)
            } else { $path.Substring($Project.Folder.Length+1).Replace('\','/') }
        }
    }
}

function Assert-CurrentValidationReference($Project,[string]$Path,[switch]$AllowMissing) {
    if (-not $Path -or $Path -match '^https?://|^#') { return }
    $resolved=Resolve-ProjectPath $Path $Project.Root
    $dataRoot=Join-Path $Project.Root '.harness'
    if ($resolved.StartsWith($dataRoot+'\',[StringComparison]::OrdinalIgnoreCase)) {
        $relative=$resolved.Substring($dataRoot.Length+1)
        if ($relative -match '^(planning|priorizacao|sprints|runs|builds|sonar|importacoes)(\\|$)|^(active-mta|last-[^\\]+)\.json$') { throw ('Dependencia legada: '+$resolved) }
        if ($relative -match '^projetos\\([^\\]+)(?:\\|$)') {
            $association=Join-Path $dataRoot ('projetos/'+$matches[1]+'/projeto.json')
            if (-not (Test-Path -LiteralPath $association -PathType Leaf)) { throw ('Referencia a projeto legado ou nao associado: '+$resolved) }
        }
    }
    if (-not $AllowMissing -and -not (Test-Path -LiteralPath $resolved)) { throw ('Referencia ausente: '+$resolved) }
}

function Assert-CurrentValidationPaths($Project,$Object,[string]$Field='') {
    if ($null -eq $Object) { return }
    if ($Object -is [string]) {
        if ($Field -match '(?:Path|Paths|Pom|Source|References)$|^diretorio$') { Assert-CurrentValidationReference $Project $Object -AllowMissing }
        return
    }
    if ($Object -is [Array]) { foreach ($item in $Object) { Assert-CurrentValidationPaths $Project $item $Field }; return }
    if ($Object -is [pscustomobject]) {
        foreach ($property in $Object.PSObject.Properties) { Assert-CurrentValidationPaths $Project $property.Value $property.Name }
    }
}

function Assert-CurrentValidationPlanning($Project,$Data,$Files) {
    Assert-CurrentPlanningContext $Data $Project
    if ($Data.Source -ine $Project.Source -or $Data.Pom -ine $Project.Pom) { throw 'Source/POM do contexto diverge da identidade corrente.' }
    foreach ($relative in @('atual/planejamento/plano.md','atual/planejamento/tarefas.md','atual/planejamento/planejar-lotes.prompt.md')) { if (-not $Files.ContainsKey($relative)) { throw ('Documento corrente ausente: '+$relative) } }
    foreach ($reference in @($Data.EvidenceInputs)+@($Data.FichaPaths)) {
        if ((Get-CurrentValidationValue $reference 'Status') -in @('AUSENTE','INVALIDA')) { throw ('Evidencia ausente/invalida: '+$reference.Path) }
        Assert-CurrentValidationReference $Project $reference.Path
    }
    if ($Data.EvidenceIndexPath) { Assert-CurrentValidationReference $Project $Data.EvidenceIndexPath }
    $rows=@(Read-ProjectDecisionRows $Files['migracao.md'])
    foreach ($issue in $Data.SelectedIssues) {
        if (@($rows | Where-Object { $_.Id -ceq $issue.Id -and $_.Category -ceq $issue.Category }).Count -ne 1) { throw ('Issue do plano sem decisao/categoria correspondente: '+$issue.Id) }
    }
}

function Get-CurrentValidationLinks([string]$Text,[string]$Document) {
    foreach ($match in [regex]::Matches($Text,'\[[^\]\r\n]*\]\((?:<([^>\r\n]*)>|([^\s\)]+))\)')) {
        $value=if ($match.Groups[1].Success) {$match.Groups[1].Value} else {$match.Groups[2].Value}
        if ($value -match '^https?://|^#') { continue }
        $uri=New-Object Uri ([uri]([uri]$Document).AbsoluteUri),$value
        if ($uri.IsFile) { $uri.LocalPath }
    }
}

function Assert-CurrentValidationReferenceTree($Project,[string]$Path,$Observed) {
    $queue=New-Object 'Collections.Generic.Queue[string]'; $queue.Enqueue($Path); $visited=@{}
    $projectsRoot=(Join-Path $Project.Root '.harness/projetos')+'\'
    while ($queue.Count) {
        $path=$queue.Dequeue()
        Assert-CurrentValidationReference $Project $path
        if ($path -match '^https?://') { continue }
        $path=Resolve-ProjectPath $path $Project.Root
        if ($visited.ContainsKey($path)) { continue }
        $visited[$path]=$true
        # Fontes externas sao referencias; documentos correntes participantes
        # sao percorridos para conferir os anexos que sustentam a cobertura.
        if ($path.StartsWith($projectsRoot,[StringComparison]::OrdinalIgnoreCase) -and [IO.Path]::GetExtension($path) -ieq '.md') {
            if (-not $Observed.ContainsKey($path)) { $Observed[$path]=[IO.File]::ReadAllText($path) }
            foreach ($link in @(Get-CurrentValidationLinks $Observed[$path] $path)) { $queue.Enqueue($link) }
        }
    }
}

function Assert-CurrentValidationPrioritization($Project,$Data,$Files,$Observed) {
    $projects=@(foreach ($entry in $Data.Projects) {
        $participant=Get-HarnessProjectReference $Project.Root $entry.Pom
        if ($entry.Project -cne $participant.Name -or $entry.Source -ine $participant.Source) { throw 'Identidade participante de priorizacao divergente.' }
        $participant
    })
    $paths=Get-PrioritizationPaths $Project $Data.Category $Data.Scope
    Assert-PrioritizationContext $Data $paths $projects $Data.Category $Data.Scope
    foreach ($path in @($paths.PromptPath,$paths.IndexPath)) { Assert-CurrentValidationReference $Project $path }
    $relative=$paths.RankingPath.Substring($Project.Folder.Length+1).Replace('\','/')
    if (-not $Files.ContainsKey($relative)) { throw 'Ranking corrente ausente.' }
    $result=Read-PrioritizationResult $Data $Files[$relative] $projects
    foreach ($issue in $result.AnalyzedIssues) {
        $peer=@($projects | Where-Object Name -CEQ $issue.Project)[0]
        $relative=Get-PrioritizationFichaRelativePath $Data.Category $issue.Id
        $ficha=Read-HarnessProjectFiles $peer @($relative)
        $path=Join-Path $peer.Folder $relative
        $Observed[$path]=$ficha[$relative]
        $identity=Read-PrioritizationFicha $ficha[$relative] $peer.Name $Data.Category $issue.Id
        foreach ($pair in @(@($peer.Source,$identity.LocalPaths),@($peer.EvidencePath,$identity.EvidencePaths))) {
            foreach ($reference in $pair[1]) {
                $null=Get-IssueLocalReference $pair[0] $reference $path
                Assert-CurrentValidationReferenceTree $Project (Join-Path $pair[0] $reference) $Observed
            }
        }
        Assert-CurrentValidationReferenceTree $Project $path $Observed
    }
}

function Assert-CurrentValidationSprint($Project,$Data,$Files,$Observed) {
    $paths=Get-SprintPaths $Project $Data.Scenario
    if ($Data.SchemaVersion -ne 1 -or $Data.Purpose -cne 'current-sprint-planning' -or $Data.MasterProject -cne $Project.Name) { throw 'Identidade do contexto de sprints divergente.' }
    foreach ($field in @('ContextPath','SprintDataPath','SprintPlanPath','ValidationPath','PromptPath','ReviewPromptPath')) {
        if ($Data.$field -ine $paths.$field) { throw ('Destino do contexto de sprints divergente: '+$field) }
    }
    foreach ($folder in Get-ChildItem -LiteralPath (Join-Path $Project.Root '.harness/projetos') -Directory) {
        if ($folder.FullName -ieq $Project.Folder -or -not (Test-Path -LiteralPath (Join-Path $folder.FullName 'projeto.json'))) { continue }
        $other=Resolve-ProjectPath (Join-Path $folder.FullName ($paths.Relative+'/contexto.json')) $Project.Root
        if (Test-Path -LiteralPath $other -PathType Leaf) { throw 'Cenario com mais de um mestre corrente.' }
    }
    $null=Read-HarnessSprintContext $Project.Root $Data.ContextPath
    $projects=@(foreach ($participant in $Data.Projects) {
        $actual=Get-HarnessProjectReference $Project.Root $participant.Pom
        if ($participant.Project -cne $actual.Name -or $participant.Source -ine $actual.Source -or $participant.MigrationPath -ine $actual.MigrationPath) { throw 'Identidade participante de sprints divergente.' }
        Assert-CurrentValidationReference $Project $actual.MigrationPath
        $register=Read-HarnessProjectFiles $actual @('migracao.md')
        $Observed[$actual.MigrationPath]=$register['migracao.md']
        [pscustomobject]@{Project=$actual.Name;Source=$actual.Source;RegisterValid=$true;Issues=@(Read-ProjectDecisionRows $register['migracao.md'])}
    })
    $prefix=$paths.Relative+'/'
    foreach ($relative in @('planejamento-sprints.json','plano.md','planejar-sprints.prompt.md','revisar-sprints.prompt.md')) { if (-not $Files.ContainsKey($prefix+$relative)) { throw ('Documento de sprints ausente: '+$relative) } }
    $premises=ConvertFrom-Json $Files[$prefix+'planejamento-sprints.json']
    if ($premises.Purpose -cne 'current-sprint-planning' -or $premises.Scenario -cne $Data.Scenario -or $premises.PSObject.Properties['Simulation']) { throw 'Premissas de sprints fora do contrato corrente.' }
    $null=Get-SprintCalculatedBlock $Files[$prefix+'plano.md']
    foreach ($work in $premises.Work) { foreach ($reference in $work.References) { Assert-CurrentValidationReferenceTree $Project $reference $Observed } }
    $result=$null
    if ($Files.ContainsKey($prefix+'resultado.json')) {
        $result=ConvertFrom-Json $Files[$prefix+'resultado.json']
        if ($result.Purpose -cne 'current-sprint-result' -or $result.Scenario -cne $Data.Scenario -or -not $result.Simulation) { throw 'Resultado de sprints divergente.' }
        foreach ($issue in @($result.Baseline.Issues)+@($result.NewIssues)) { if (-not (Get-CurrentValidationValue $issue 'Project')) { throw 'Issue historica sem identidade funcional de projeto.' } }
        if ($result.SprintStartDate -and $premises.Constraints.SprintStartDate -ne $result.SprintStartDate) { throw 'Inicio de sprints publicadas diverge do resultado anterior.' }
        if ($result.ReferenceDate -and $premises.Constraints.ReferenceDate -lt $result.ReferenceDate) { throw 'Referencia temporal retrocede em relacao ao resultado anterior.' }
    }
    Assert-SprintDataScope $premises ([pscustomobject]@{Scenario=$Data.Scenario;Projects=$projects}) $result
}

function Test-ConversionCurrent {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][string]$Workspace,[Parameter(Mandatory=$true)][string]$Pom)
    $project=Get-HarnessProjectReference $Workspace $Pom
    $leases=@(); $guards=@()
    $diagnostics=New-Object 'Collections.Generic.List[string]'
    $observed=@{}; $files=@{}
    try {
        try {
            # Mesma ordem dos produtores: mutex de cenarios, depois projetos em
            # ordem ordinal. Leitores de fichas de parceiros nao podem recuperar
            # publicacoes pendentes como efeito colateral de Validar.
            $leases+=Enter-SprintAccess $project.Root
            $participants=@{}; $participants[$project.Name]=$project; $preflight=@{}
            foreach ($relative in @(Get-CurrentValidationFiles $project | Where-Object { $_ -match '^atual/(priorizacao/.*/escopos/.*|sprints/[^/]+)/contexto\.json$' })) {
                $path=Join-Path $project.Folder $relative
                $preflight[$path]=[IO.File]::ReadAllText($path)
                $context=ConvertFrom-Json $preflight[$path]
                foreach ($entry in $context.Projects) {
                    $peer=Get-HarnessProjectReference $project.Root $entry.Pom
                    if ($participants.ContainsKey($peer.Name) -and $participants[$peer.Name].Pom -ine $peer.Pom) { throw 'Colisao de identidade entre participantes.' }
                    $participants[$peer.Name]=$peer
                }
            }
            $ordered=[string[]]@($participants.Keys); [Array]::Sort($ordered,[StringComparer]::Ordinal)
            foreach ($name in $ordered) {
                $peer=$participants[$name]
                $guards+=[IO.File]::Open($peer.Pom,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read)
                $checked=Get-HarnessProjectReference $project.Root $peer.Pom
                if ($checked.Name -cne $peer.Name -or $checked.Source -ine $peer.Source) { throw 'POM participante mudou durante a validacao; repita a leitura.' }
            }
            foreach ($name in $ordered) { $leases+=Enter-HarnessProjectAccess $participants[$name] -ReadOnly }
            foreach ($name in $ordered) {
                $peer=$participants[$name]
                $association=Read-HarnessProjectFiles $peer @('projeto.json')
                if (-not $association['projeto.json'] -or (Resolve-ProjectPath (ConvertFrom-Json $association['projeto.json']).pom $project.Root) -ine $peer.Pom) { throw ('Associacao do participante aponta outro POM: '+$name) }
                $observed[$peer.ConfigPath]=$association['projeto.json']
            }
            $paths=@(Get-CurrentValidationFiles $project | Sort-Object)
            foreach ($relative in $paths | Where-Object { $_ -match '\.(md|json)$' -and $_ -notmatch '^evidencias/.*\.json$|^atual/diagnosticos/mta/' }) {
                $path=Join-Path $project.Folder $relative
                $observed[$path]=[IO.File]::ReadAllText($path); $files[$relative]=$observed[$path]
            }
            foreach ($path in $preflight.Keys) { if (-not $observed.ContainsKey($path) -or $observed[$path] -cne $preflight[$path]) { throw 'Participantes/contexto mudaram durante a validacao; repita a leitura.' } }
            if (-not $files.ContainsKey('projeto.json') -or -not $files.ContainsKey('migracao.md')) { throw 'Associacao ou registro corrente ausente.' }
            $config=ConvertFrom-Json $files['projeto.json']
            if ((Resolve-ProjectPath $config.pom $project.Root) -ine $project.Pom) { throw 'Associacao de projeto aponta outro POM.' }
            $null=Read-ProjectDecisionRows $files['migracao.md']
            foreach ($relative in $files.Keys) {
                $contextPath=$null
                if ($relative -match '^(atual/(?:planejamento|priorizacao/[^/]+/escopos/[^/]+|sprints/[^/]+))/') { $contextPath=$matches[1]+'/contexto.json' }
                if ($contextPath -and -not $files.ContainsKey($contextPath)) { throw ('Documentos correntes sem contexto: '+$contextPath) }
            }
            foreach ($relative in $files.Keys) {
                try {
                    if ($relative.EndsWith('.json')) {
                        $data=ConvertFrom-Json $files[$relative]
                        Assert-CurrentValidationPaths $project $data
                        if ($relative -eq 'atual/planejamento/contexto.json') { Assert-CurrentValidationPlanning $project $data $files }
                        elseif ($relative -match '^atual/priorizacao/.*/escopos/.*/contexto\.json$') { Assert-CurrentValidationPrioritization $project $data $files $observed }
                        elseif ($relative -match '^atual/sprints/[^/]+/contexto\.json$') { Assert-CurrentValidationSprint $project $data $files $observed }
                    } else {
                        foreach ($path in @(Get-CurrentValidationLinks $files[$relative] (Join-Path $project.Folder $relative))) { Assert-CurrentValidationReference $project $path }
                    }
                } catch { $diagnostics.Add($relative+': '+$_.Exception.Message) }
            }
            $needsMta=$config.mta.diretorio -or (Test-Path -LiteralPath (Join-Path $project.Folder 'atual/diagnosticos/mta'))
            if ($files.ContainsKey('atual/planejamento/contexto.json')) { $needsMta=$needsMta -or ((ConvertFrom-Json $files['atual/planejamento/contexto.json']).PlanningBasis -eq 'MTA') }
            if ($needsMta) { $null=Read-HarnessProjectMta $project }
            foreach ($path in $observed.Keys) { if (-not (Test-Path -LiteralPath $path -PathType Leaf) -or [IO.File]::ReadAllText($path) -cne $observed[$path]) { throw 'Documento mudou durante a validacao; repita a leitura.' } }
            if ((@(Get-CurrentValidationFiles $project | Sort-Object) -join "`n") -cne ($paths -join "`n")) { throw 'Inventario corrente mudou durante a validacao.' }
        } catch { $diagnostics.Add($_.Exception.Message) }
        [pscustomobject]@{Status=$(if ($diagnostics.Count) {'PENDENTE'} else {'VALIDO'});Valid=($diagnostics.Count -eq 0);Project=$project.Name;Destination=$project.Folder;
            CheckedFiles=$files.Count;Diagnostics=@($diagnostics);AuthorizationInherited=$false;Scope='Integridade operacional e referencias correntes; revisao humana, GO e aceite separados.'}
    } finally {
        for ($i=$leases.Count-1;$i -ge 0;$i--) { $leases[$i].ReleaseMutex(); $leases[$i].Dispose() }
        foreach ($guard in $guards) { $guard.Dispose() }
    }
}
Export-ModuleMember -Function Test-ConversionCurrent
