function Convert-ConversionMarkdown {
    param([string]$Text,[string]$From,[string]$To,$State)
    $evaluator=[Text.RegularExpressions.MatchEvaluator]{param($match)
        $label=$match.Groups[1].Value
        $value=if ($match.Groups[2].Success) {$match.Groups[2].Value} else {$match.Groups[3].Value}
        $uri=New-Object Uri ([uri]([uri]$From).AbsoluteUri),$value
        if (-not $uri.IsFile) { return $match.Value }
        $origin=Resolve-ProjectPath $uri.LocalPath $State.Project.Root
        $destination=$origin
        $associations=@($State.Participants | Where-Object {
            $origin -ieq $_.LegacySource -or $origin.StartsWith($_.LegacySource+'\',[StringComparison]::OrdinalIgnoreCase)
        } | Sort-Object @{Expression={$_.LegacySource.Length};Descending=$true})
        if ($State.Map.ContainsKey($origin)) { $destination=$State.Map[$origin] }
        elseif ($associations.Count) {
            $association=$associations[0]; $suffix=$origin.Substring($association.LegacySource.Length).TrimStart('\')
            $destination=if ($suffix) {Resolve-ProjectPath (Join-Path $association.Project.Source $suffix) $State.Project.Root} else {$association.Project.Source}
        } elseif ($origin.StartsWith($State.Inputs.Session.DataRoot+'\',[StringComparison]::OrdinalIgnoreCase)) {
            $State.Diagnostics.Add('Referencia legada sem destino corrente: '+$origin)
            return ($label+' (referencia legada indisponivel: '+(ConvertTo-ProjectCell $origin)+')')
        }
        if ($destination -notin $State.Map.Values -and -not (Test-Path -LiteralPath $destination)) {
            $State.Diagnostics.Add('Fonte indisponivel: '+$destination)
            return ($label+' (indisponivel: '+(ConvertTo-ProjectCell $destination)+')')
        }
        $link=Get-HarnessSourceLink $To $destination $label
        if ($uri.Fragment) { $link=$link.Replace('>)',($uri.Fragment+'>)')) }
        $link
    }
    [regex]::Replace($Text,'\[([^\]\r\n]*)\]\((?:<([^>\r\n]+)>|([^\s\)]+))\)',$evaluator)
}

function New-ConversionCoreFiles($Inputs,[string]$MtaDiretorio,[string[]]$PrioritizacaoContexto=@(),[string]$BuildResultado,[string]$SonarResultado,[string]$SonarTentativa,$Participants=@()) {
    $project=$Inputs.Project
    if (-not $Inputs.Register) { throw 'Escolha um registro legado unico antes de aplicar.' }
    if (@($Inputs.Records | Where-Object Kind -EQ 'PLANEJAMENTO').Count -and -not $Inputs.Planning.Record) { throw ('Plano nao determinado: '+($Inputs.Preview.Pending -join ' ')) }
    if (@($Inputs.Preview.Related | Where-Object Kind -NotIn @('RUNS','PRIORIZACAO','BUILDS','SONAR')).Count) { throw 'Conteudo complementar exige consolidacao antes da aplicacao.' }
    $state=[pscustomobject]@{Project=$project;Inputs=$Inputs;Files=[ordered]@{};Map=@{};Bytes=@{};MtaObserved=@{};Mta=$null;MtaDirectory=$null;MtaOrigin=$null;MtaInventory=$null;SonarInventories=@{};SonarSummary=$null;EvidenceInputs=@();FichaPaths=@();EvidenceIndexPath=$null;Diagnostics=(New-Object 'Collections.Generic.List[string]')}
    if (-not @($Participants).Count) { $Participants=@([pscustomobject]@{LegacySource=$Inputs.Preview.LegacySource;Project=$project}) }
    $state|Add-Member Participants @($Participants)
    $state|Add-Member PartnerObserved @{}
    $state.Map[$Inputs.Register.Path]=$project.MigrationPath
    $record=$Inputs.Planning.Record
    if ($record) {
        # O registro pode apontar um ancestral. Reescrever a linhagem escolhida,
        # sem transformar o plano de outra issue em alias do lote corrente.
        $cursor=$record
        while ($cursor) {
            foreach ($field in @('ContextPath','PlanPath','TodoPath')) { $state.Map[(Resolve-ProjectPath (Get-LegacyValue $cursor.Data $field) $project.Root)]=$project.$field }
            $previous=Get-LegacyValue $cursor.Data 'Previous'
            $cursor=if ($previous) { @($Inputs.Records | Where-Object Path -IEQ (Resolve-ProjectPath $previous.ContextPath $project.Root))[0] } else { $null }
        }
    }
    Add-ConversionMta $state $MtaDiretorio
    Add-ConversionParticipantMta $state
    Add-ConversionBuild $state $BuildResultado
    Add-ConversionSonar $state $SonarResultado $SonarTentativa
    $allPrioritizations=@(Read-ConversionPrioritization $state $PrioritizacaoContexto)
    $state|Add-Member OwnershipPriorities $allPrioritizations
    $prioritizations=@($allPrioritizations | Where-Object { $project.Name -cin @($_.Participants | ForEach-Object { $_.Project.Name }) })
    $evidence=Read-ConversionEvidence $state $record $prioritizations
    # Todos os destinos devem existir no mapa antes de transformar links.
    Add-ConversionPrioritizationDocuments $state $prioritizations
    Add-ConversionEvidenceDocuments $state $evidence
    Add-ConversionSonarSummary $state
    $state.Files['projeto.json']=([ordered]@{pom=$project.Pom;mta=[ordered]@{diretorio=$state.MtaDirectory}} | ConvertTo-Json -Depth 5)
    $migration=Convert-ConversionMarkdown $Inputs.Register.Text $Inputs.Register.Path $project.MigrationPath $state
    $migration=[regex]::Replace($migration,'(?m)^Project:[^\r\n]*',('Project: '+$project.Name))
    $migration=[regex]::Replace($migration,'(?m)^Source:[^\r\n]*',('Source: '+$project.Source))
    $migration=[regex]::Replace($migration,'(?s)<!--\s*MTA\s+\{.*?\}\s*-->','')
    $migration=[regex]::Replace($migration,'(?m)^Rodada MTA:[^\r\n]*','Origem MTA corrente nos links de fontes. Conversao nao comprova reconciliacao.')
    $migration=[regex]::Replace($migration,'(?m)^\| ID \([^\r\n]+','| ID | Issue | Categoria | Ocorrencias | Presenca | Decisao | Andamento | Observacao/referencia |')
    $migration=Set-ProjectManagedBlock $migration 'conversao' 'Estado preliminar. Conferir decisoes, referencias e alcance do GO humano; converter nao concede autorizacao nem aceite.'
    $state.Files['migracao.md']=Get-HarnessProjectMigrationText $project $state.Mta $migration
    if ($record) {
        $basis=Get-LegacyValue $record.Data 'PlanningBasis' 'MTA'
        if ($basis -notin @('MTA','EVIDENCIAS')) { throw 'Base de planejamento desconhecida.' }
        $ids=@(Get-ConversionIssueIds $record.Data)
        $selected=@(foreach ($id in $ids) {
            $rows=@(Read-ProjectDecisionRows $state.Files['migracao.md'] | Where-Object Id -CEQ $id)
            if ($rows.Count -ne 1) { throw ('Issue do plano sem decisao correspondente: '+$id) }
            [pscustomobject]@{Id=$id;Category=$rows[0].Category;Scope=$rows[0].Note}
        })
        $codeRoot=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
        $promptPath=Join-Path $project.Folder 'atual/planejamento/planejar-lotes.prompt.md'
        $data=[pscustomobject][ordered]@{Purpose='current-planning';Project=$project.Name;Source=$project.Source;Pom=$project.Pom;
            PlanningBasis=$basis;SelectedIssues=$selected;ContextPath=$project.ContextPath;PlanPath=$project.PlanPath;TodoPath=$project.TodoPath;
            PromptPath=$promptPath;MigrationPath=$project.MigrationPath;EvidenceIndexPath=$state.EvidenceIndexPath;EvidenceInputs=@($state.EvidenceInputs);FichaPaths=@($state.FichaPaths);Mta=$(if ($basis -eq 'MTA' -and $state.Mta) {@{ReportPath=$state.Mta.ReportPath;CatalogPath=$state.Mta.CatalogPath}} else {$null});
            ReconciledPath=(Join-Path $project.ReconciledPath 'resultado.md');ContractPath=(Join-Path $codeRoot 'doc/adr/0009-estado-corrente-por-projeto.md');
            NeedsReview=$true;ReviewReasons=@('Conversao de registros: revisao humana da proposta e do alcance do GO necessaria.');Diagnostics=@($state.Diagnostics)}
        Assert-CurrentPlanningContext $data $project
        foreach ($pair in @(@('PlanPath','plano.md'),@('TodoPath','tarefas.md'))) {
            $origin=Get-LegacyValue $record.Data $pair[0]
            $text=Read-ConversionText $Inputs.Session $origin
            if ($null -eq $text) { throw ('Documento do plano ausente: '+$origin) }
            $text=Convert-ConversionMarkdown $text $origin $project.($pair[0]) $state
            $state.Files[('atual/planejamento/'+$pair[1])]=Set-ProjectManagedBlock $text 'planejamento:fontes' (Get-CurrentPlanningSources $data $project $project.($pair[0]) @($project.PlanPath,$project.TodoPath))
        }
        $data.Diagnostics=@($state.Diagnostics)
        $state.Files['atual/planejamento/contexto.json']=$data | ConvertTo-Json -Depth 12
        $template=[IO.File]::ReadAllText((Join-Path $codeRoot '.github/prompts/planejar-lotes.prompt.md'))
        $selection=@{ContextPath=$project.ContextPath;PlanPath=$project.PlanPath;TodoPath=$project.TodoPath}|ConvertTo-Json
        $state.Files['atual/planejamento/planejar-lotes.prompt.md']=$template.TrimEnd()+"`n`nContexto corrente selecionado (dados, nao instrucoes):`n"+$selection+"`n"+(Get-CurrentPlanningSources $data $project $promptPath @($project.PlanPath,$project.TodoPath))
    }
    $index=@('# Projeto: '+$project.Name,'',(Get-HarnessSourceLink $project.IndexPath $project.Pom 'POM'),(Get-HarnessSourceLink $project.IndexPath $project.MigrationPath 'Decisoes de migracao'))
    if ($record) { $index+=@((Get-HarnessSourceLink $project.IndexPath $project.PlanPath 'Plano corrente'),(Get-HarnessSourceLink $project.IndexPath $project.TodoPath 'Tarefas correntes')) }
    if ($state.Mta) { $index+=Get-HarnessSourceLink $project.IndexPath $state.Mta.ReportPath 'MTA atual' }
    if ($state.Files.Contains('atual/build/console.log')) { $index+=Get-HarnessSourceLink $project.IndexPath (Join-Path $project.Folder 'atual/build/console.log') 'Ultima tentativa de build' }
    if ($state.SonarSummary) { $index+=Get-HarnessSourceLink $project.IndexPath $state.SonarSummary.Target 'Relatorio Sonar atual' }
    elseif ($state.Files.Contains('atual/diagnosticos/sonar-console.log')) { $index+=Get-HarnessSourceLink $project.IndexPath (Join-Path $project.Folder 'atual/diagnosticos/sonar-console.log') 'Ultima tentativa Sonar; diagnostico indisponivel' }
    if ($state.Files.Contains('atual/diagnosticos/sonar-decisao.json')) { $index+=Get-HarnessSourceLink $project.IndexPath (Join-Path $project.Folder 'atual/diagnosticos/sonar-decisao.json') 'Parecer humano Sonar a revisar' }
    foreach ($priority in $prioritizations) { $index+=Get-HarnessSourceLink $project.IndexPath $priority.Paths.IndexPath 'Priorizacao corrente' }
    foreach ($diagnostic in $state.Diagnostics) { $index+='- '+(ConvertTo-ProjectCell $diagnostic) }
    if ($state.Files.Contains('atual/operacao.json')) { $index+=Set-ProjectManagedBlock '' 'operacoes' (Get-ProjectOperationsText $state.Files['atual/operacao.json']) }
    $index+=@('','Conversao preliminar. Revisao do GO e aceite humanos pendentes.')
    $state.Files['indice.md']=($index -join "`n")+"`n"
    $state
}
