function Convert-ConversionSonarResult($State,$Record,[string]$Relative,[bool]$Published,[string]$LogPath) {
    $data=$Record.Data; $current=[ordered]@{}
    foreach ($property in $data.PSObject.Properties) {
        if ($property.Name -notin @('RunId','IssuesSha256','BaselineRunId')) { $current[$property.Name]=$property.Value }
    }
    $current.Project=$State.Project.Name; $current.ProjectLabel=$State.Project.Name
    $current.Source=$State.Project.Source
    if ($data.Source -ine $State.Project.Source) { $current['SourceAtScan']=$data.Source }
    $current.ResultPath=Join-Path $State.Project.Folder $Relative; $current.LogPath=$LogPath
    $current['DiagnosticPublished']=$Published; $current.HumanDecision='PENDING'
    $current.CriteriaPath=if ($Published) {Join-Path $State.Project.Folder 'atual/diagnosticos/sonar/criteria.json'} else {$null}
    $current.BaselineResultPath=$null; $current['BaselineAnalysisId']=$null
    $baselinePath=Get-LegacyValue $data 'BaselineResultPath'
    if ($baselinePath) {
        $path=Resolve-ProjectPath $baselinePath $State.Project.Root
        $baseline=@($State.Inputs.Records | Where-Object { $_.Kind -eq 'SONAR' -and $_.Path -ieq $path })
        if ($baseline.Count -eq 1) {
            $before=$baseline[0].Data
            foreach ($field in @('Source','ProjectKey','ServerUrl','BranchName')) { if ([string]$before.$field -cne [string]$data.$field) { throw 'Baseline Sonar de outra origem.' } }
            if ($before.Phase -cne 'ANTES' -or (Get-LegacyValue $data 'BaselineRunId') -cne $before.RunId -or
                (Get-ConversionExecutionDates $before 'Baseline Sonar').Finished -ge (Get-ConversionExecutionDates $data 'Sonar').Started) { throw 'Baseline Sonar divergente da referencia declarada.' }
            $current.BaselineAnalysisId=$before.AnalysisId
        } elseif (Test-Path -LiteralPath $path) { throw 'Baseline Sonar nao associado ao Source selecionado.' }
        $State.Diagnostics.Add('Comparacao Sonar declarada preservada; detalhes do baseline anterior nao sao copiados ao diagnostico corrente.')
    }
    [pscustomobject]$current
}

function Add-ConversionSonar($State,[string]$SelectedResult,[string]$SelectedAttempt) {
    $records=@($State.Inputs.Records | Where-Object Kind -EQ 'SONAR')
    $selection=$null; $attemptSelection=$null
    if ($SelectedResult) {
        $path=Resolve-ProjectPath $SelectedResult $State.Project.Root
        $selected=@($records | Where-Object Path -IEQ $path)
        if ($selected.Count -ne 1) { throw 'SonarResultado nao pertence ao Source selecionado.' }
        $selection=$selected[0]
    }
    if ($SelectedAttempt) {
        $path=Resolve-ProjectPath $SelectedAttempt $State.Project.Root
        $selected=@($records | Where-Object Path -IEQ $path)
        if ($selected.Count -ne 1) { throw 'SonarTentativa nao pertence ao Source selecionado.' }
        $attemptSelection=$selected[0]
    }
    if (-not $records.Count) { return }
    $candidates=@(foreach ($record in $records) {
        $data=$record.Data
        if ($record.Sources.Count -ne 1 -or (Split-Path $record.Path -Leaf) -ine 'result.json' -or
            (Resolve-ProjectPath (Get-LegacyValue $data 'ResultPath') $State.Project.Root) -ine $record.Path -or
            $data.Status -cnotin @('FAILED','UNVERIFIED','SUCCEEDED','QUALITY_GATE_FAILED','CRITERIA_FAILED')) { throw 'Resultado Sonar legado desconhecido ou inconsistente.' }
        foreach ($field in @('ServerUrl','ProjectKey','Phase')) { if (-not (Get-LegacyValue $data $field)) { throw 'Origem/fase Sonar incompleta.' } }
        $dates=Get-ConversionExecutionDates $data 'Sonar'
        $scope=ConvertTo-Json -InputObject @($data.ServerUrl,$data.ProjectKey,[string]$data.BranchName) -Compress
        $usable=$data.Stage -ceq 'COMPLETE' -and $data.IssuesStatus -ceq 'COMPLETE' -and $data.InputsStatus -ceq 'STABLE'
        if ($usable -and ($data.AnalysisStatus -cne 'SUCCESS' -or $data.MetricsStatus -cne 'MATCHED' -or $data.ScannerExitCode -ne 0)) { throw 'Coleta Sonar declara conjunto completo com processamento inconsistente.' }
        [pscustomobject]@{Record=$record;Finished=$dates.Finished;Scope=$scope;Usable=$usable}
    })
    $scopeRecord=if ($selection) {$selection} else {$attemptSelection}
    if ($scopeRecord) {
        $scope=@($candidates | Where-Object { $_.Record.Path -ieq $scopeRecord.Path })[0].Scope
        $candidates=@($candidates | Where-Object Scope -CEQ $scope)
    } else {
        if (@($candidates | ForEach-Object Scope | Sort-Object -Unique -CaseSensitive).Count -ne 1) { throw 'Varias origens/chaves/branches Sonar; escolha SonarResultado explicitamente.' }
    }
    if ($attemptSelection) {
        $matches=@($candidates | Where-Object { $_.Record.Path -ieq $attemptSelection.Path })
        if ($matches.Count -ne 1) { throw 'SonarTentativa e SonarResultado pertencem a origens distintas.' }
        $attempt=$matches[0]
        if (@($candidates | Where-Object Finished -GT $attempt.Finished).Count) { throw 'SonarTentativa nao e a tentativa mais recente da origem escolhida.' }
    } else { $attempt=Select-ConversionNewest $candidates 'SonarTentativa' }
    $usable=@($candidates | Where-Object Usable)
    if ($selection) {
        $chosen=@($candidates | Where-Object { $_.Record.Path -ieq $selection.Path })[0]
        if (-not $chosen.Usable -or @($usable | Where-Object Finished -GT $chosen.Finished).Count) { throw 'SonarResultado deve escolher o diagnostico completo mais recente da origem.' }
    } else { $chosen=Select-ConversionNewest $usable 'SonarResultado' }
    if ($attempt.Usable -and $chosen.Record.Path -ine $attempt.Record.Path) { throw 'Tentativa completa e diagnostico escolhido devem pertencer a mesma coleta.' }
    $latest=$attempt.Record; $folder=Split-Path $latest.Path -Parent
    $log=Resolve-ProjectPath $latest.Data.LogPath $State.Project.Root
    if ((Split-Path $log -Parent) -ine $folder -or (Split-Path $log -Leaf) -cnotin @('scanner-info.log','scanner-debug.log')) { throw 'Log Sonar fora do papel/tentativa selecionados.' }
    $targetLog=Join-Path $State.Project.Folder 'atual/diagnosticos/sonar-console.log'
    if (Test-Path -LiteralPath $log -PathType Leaf) { $State.Files['atual/diagnosticos/sonar-console.log']=Read-ConversionBytes $State $log }
    else {
        $null=Read-ConversionText $State.Inputs.Session $log
        $State.Files['atual/diagnosticos/sonar-console.log']="Log original Sonar indisponivel. Erro declarado:`n"+[string]$latest.Data.Error
        $State.Diagnostics.Add('Log da ultima tentativa Sonar indisponivel na origem.')
    }
    $State.Map[$log]=$targetLog
    $published=$chosen -and $chosen.Record.Path -ieq $latest.Path
    $attemptData=Convert-ConversionSonarResult $State $latest 'atual/diagnosticos/sonar-tentativa.json' $published $targetLog
    $State.Files['atual/diagnosticos/sonar-tentativa.json']=$attemptData|ConvertTo-Json -Depth 20
    $State.Map[$latest.Path]=$attemptData.ResultPath
    $operationStatus=if ($published) {'SUCCEEDED'} else {'FAILED'}
    $previous=if ($State.Files.Contains('atual/operacao.json')) {[string]$State.Files['atual/operacao.json']} else {''}
    $State.Files['atual/operacao.json']=Get-HarnessProjectOperationText $previous 'sonar' $operationStatus $latest.Data.Error $targetLog $latest.Data.FinishedAtUtc
    $decisions=@(foreach ($candidate in $candidates) { Read-ConversionSonarDecision $State $candidate.Record })
    if ($decisions.Count) {
        $decision=Select-ConversionNewest $decisions 'a decisao Sonar a preservar'
        $entry=$decision.Entry
        $State.Files['atual/diagnosticos/sonar-decisao.json']=@{RecordedAtUtc=$entry.RecordedAtUtc;Decision=$entry.Decision;Note=$entry.Note;ReviewWhen=$entry.ReviewWhen;Assessment=$null;Scope='Decisao declarada no legado, preservada para revisao local; nao concede GO ou aceite.'}|ConvertTo-Json -Depth 10
        $State.Diagnostics.Add('Decisao humana Sonar preservada; revisar o parecer no conjunto corrente.')
    }
    if (-not $chosen) { $State.Diagnostics.Add('Nenhuma coleta Sonar completa; ultima tentativa preservada, diagnostico indisponivel.'); return }
    $record=$chosen.Record; $folder=Split-Path $record.Path -Parent
    $prefix='atual/diagnosticos/sonar/'
    $current=Convert-ConversionSonarResult $State $record ($prefix+'resultado.json') $true $(if ($published) {$targetLog} else {$null})
    $documents=@{'resultado.json'=($current|ConvertTo-Json -Depth 20)}
    $State.Map[$record.Path]=$current.ResultPath
    foreach ($name in @('quality-gate.json','measures.json','issues.json','criteria.json')) {
        $path=Join-Path $folder $name
        $text=Read-ConversionText $State.Inputs.Session $path
        if (-not $text) { throw ('Coleta Sonar declarada completa sem '+$name) }
        $data=ConvertFrom-Json $text
        if ($name -eq 'issues.json') {
            if ($data.RunId -cne $record.Data.RunId -or (Get-ConversionHash (Read-ConversionBytes $State $path)) -cne $record.Data.IssuesSha256) { throw 'Issues Sonar divergem da coleta legada.' }
            $data.PSObject.Properties.Remove('RunId')
        }
        if ($name -eq 'criteria.json') {
            if ((Get-LegacyValue $data.Evaluation 'BaselineRunId') -cne (Get-LegacyValue $record.Data 'BaselineRunId') -or
                (Get-LegacyValue $data.Evaluation 'BaselineResultPath') -ine (Get-LegacyValue $record.Data 'BaselineResultPath')) { throw 'Criterios Sonar declaram outro baseline.' }
            $data.Evaluation.PSObject.Properties.Remove('BaselineRunId')
            $data.Evaluation|Add-Member BaselineAnalysisId $current.BaselineAnalysisId -Force
            $data.Evaluation|Add-Member BaselineResultPath $null -Force
        }
        $documents[$name]=$data|ConvertTo-Json -Depth 30
        $State.Map[$path]=Join-Path $State.Project.Folder ($prefix+$name)
    }
    $null=Get-HarnessSonarAssessment $documents
    foreach ($name in $documents.Keys) { $State.Files[$prefix+$name]=$documents[$name] }
    $summary=Join-Path $folder 'RESUMO.md'
    $text=Read-ConversionText $State.Inputs.Session $summary
    if (-not $text) { $text='# Sonar convertido'; $State.Diagnostics.Add('Resumo Sonar original indisponivel; consultar dados correntes e origem.') }
    $State.Map[$summary]=Join-Path $State.Project.Folder ($prefix+'RESUMO.md')
    $State.SonarSummary=[pscustomobject]@{Path=$summary;Text=$text;Relative=($prefix+'RESUMO.md');Target=$State.Map[$summary];Result=$current}
}

function Add-ConversionSonarSummary($State) {
    $summary=$State.SonarSummary
    if (-not $summary) { return }
    $text=[regex]::Replace($summary.Text,'(?m)^(?:RunId:|Arquivos:|Decisao na coleta:|Baseline selecionado:|Log:)[^\r\n]*(?:\r?\n)?','')
    $text=[regex]::Replace($text,'(?m)^Source:[^\r\n]*',('Source: '+$State.Project.Source))
    $text=Convert-ConversionMarkdown $text $summary.Path $summary.Target $State
    $lines=@('Conversao preserva o diagnostico declarado; nao executa scanner nem comprova o codigo atual.',
        '[Resultado](resultado.json) | [Quality Gate](quality-gate.json) | [Metricas](measures.json) | [Issues](issues.json) | [Criterios](criteria.json)',
        (Get-HarnessSourceLink $summary.Target $State.Project.Pom 'POM local'),
        (Get-HarnessSourceLink $summary.Target (Join-Path $State.Project.Folder 'atual/diagnosticos/sonar-console.log') 'Log da ultima tentativa de coleta'))
    if ($State.Files.Contains('atual/diagnosticos/sonar-decisao.json')) { $lines+='Parecer humano preservado, pendente de revisao local: [decisao](../sonar-decisao.json).' }
    $State.Files[$summary.Relative]=Set-ProjectManagedBlock $text 'sonar:fontes' ($lines -join "`n`n")
}
