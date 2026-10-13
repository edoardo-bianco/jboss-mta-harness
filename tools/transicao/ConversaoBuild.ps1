function Add-ConversionBuild($State,[string]$SelectedResult) {
    $records=@($State.Inputs.Records | Where-Object Kind -EQ 'BUILDS')
    if ($SelectedResult) {
        $selected=Resolve-ProjectPath $SelectedResult $State.Project.Root
        $records=@($records | Where-Object Path -IEQ $selected)
        if ($records.Count -ne 1) { throw 'BuildResultado nao pertence ao Source selecionado.' }
    }
    if (-not $records.Count) { return }
    $candidates=@(foreach ($record in $records) {
        $data=$record.Data
        if ($record.Sources.Count -ne 1 -or (Split-Path $record.Path -Leaf) -ine 'result.json' -or
            (Resolve-ProjectPath (Get-LegacyValue $data 'ResultPath') $State.Project.Root) -ine $record.Path -or
            (Get-LegacyValue $data 'Status') -cnotin @('SUCCEEDED','FAILED')) { throw 'Resultado de build legado desconhecido ou inconsistente.' }
        $dates=Get-ConversionExecutionDates $data 'Build'
        $exit=Get-LegacyValue $data 'ExitCode'
        if (($null -ne $exit -and $exit -isnot [int]) -or ($data.Status -ceq 'SUCCEEDED' -and ($null -eq $exit -or $exit -ne 0)) -or ($data.Status -ceq 'FAILED' -and $null -ne $exit -and $exit -eq 0)) { throw 'Status e codigo de saida do build divergentes.' }
        [pscustomobject]@{Record=$record;Finished=$dates.Finished}
    })
    $record=(Select-ConversionNewest $candidates 'BuildResultado').Record; $data=$record.Data; $folder=Split-Path $record.Path -Parent
    $log=Resolve-ProjectPath (Get-LegacyValue $data 'LogPath') $State.Project.Root
    if ((Split-Path $log -Parent) -ine $folder -or (Split-Path $log -Leaf) -ine 'console.log') { throw 'Log do build deve ser console.log da tentativa selecionada.' }
    $targetLog=Join-Path $State.Project.Folder 'atual/build/console.log'
    $targetResult=Join-Path $State.Project.Folder 'atual/build/resultado.json'
    if (Test-Path -LiteralPath $log -PathType Leaf) { $State.Files['atual/build/console.log']=Read-ConversionBytes $State $log }
    elseif ($data.Status -ceq 'FAILED' -and $null -eq (Get-LegacyValue $data 'ExitCode') -and (Get-LegacyValue $data 'Error')) {
        $null=Read-ConversionText $State.Inputs.Session $log
        $State.Files['atual/build/console.log']="Log original indisponivel. Erro registrado no resultado legado:`n"+$data.Error
        $State.Diagnostics.Add('Log original do build indisponivel; erro declarado preservado, sem inferir quando ocorreu a falha.')
    } else { throw 'Log declarado do build indisponivel; confira a tentativa antes de converter.' }
    $current=[ordered]@{Project=$State.Project.Name;Source=$State.Project.Source;ResultPath=$targetResult;LogPath=$targetLog}
    foreach ($field in @('Status','ExitCode','Goals','JavaHome','MavenHome','SettingsPath','JavaVersion','MavenVersion','StartedAtUtc','FinishedAtUtc','Error','Git')) {
        $current[$field]=Get-LegacyValue $data $field
    }
    if ($data.Source -ine $State.Project.Source) { $current['SourceAtBuild']=$data.Source }
    $State.Files['atual/build/resultado.json']=$current|ConvertTo-Json -Depth 8
    $State.Files['atual/operacao.json']=Get-HarnessProjectOperationText '' 'build' $current.Status $current.Error $targetLog $current.FinishedAtUtc
    $State.Map[$record.Path]=$targetResult; $State.Map[$log]=$targetLog
    $State.Diagnostics.Add('Tentativa de build preservada nos documentos correntes. Conversao nao executa build; conferir codigo local antes de reutilizar a verificacao.')
}
