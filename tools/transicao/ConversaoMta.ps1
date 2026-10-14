function Get-ConversionMtaInventory([string]$Origin,[string]$Root) {
    $origin=Resolve-ProjectPath $Origin $Root
    if (-not (Test-Path -LiteralPath $origin -PathType Container)) { return 'AUSENTE' }
    $files=@(); $pending=New-Object 'Collections.Generic.Stack[string]'; $pending.Push($origin)
    while ($pending.Count) {
        foreach ($entry in Get-ChildItem -LiteralPath $pending.Pop() -Force) {
            $path=Resolve-ProjectPath $entry.FullName $Root
            if ($entry.PSIsContainer) { $pending.Push($path) }
            elseif ($entry.Name -in @('index.html','output.js')) { $files+=($path+'|'+$entry.Length+'|'+$entry.LastWriteTimeUtc.Ticks) }
        }
    }
    @($files | Sort-Object) -join "`n"
}

function Add-ConversionMta($State,[string]$MtaDiretorio) {
    $record=$State.Inputs.Planning.Record
    $basis=if ($record) {Get-LegacyValue $record.Data 'PlanningBasis' 'MTA'} else { 'EVIDENCIAS' }
    $origins=@()
    if ($record -and (Get-LegacyValue $record.Data 'Run')) { $origins+=Resolve-ProjectPath $record.Data.Run $State.Project.Root }
    $markers=[regex]::Matches($State.Inputs.Register.Text,'(?s)<!--\s*MTA\s+(\{.*?\})\s*-->')
    foreach ($marker in $markers) {
        $data=ConvertFrom-Json $marker.Groups[1].Value
        $run=Get-LegacyValue $data 'Run'
        if ($run) { $origins+=Resolve-ProjectPath $run $State.Project.Root }
    }
    $origins=@($origins|Sort-Object -Unique)
    if ($MtaDiretorio) { $origin=Resolve-ProjectPath $MtaDiretorio $State.Project.Root }
    elseif ($origins.Count -eq 1) { $origin=$origins[0] }
    elseif ($origins.Count -gt 1) { throw 'Origens MTA distintas no plano/registro; escolha MtaDiretorio explicitamente.' }
    elseif ($basis -eq 'MTA' -or $markers.Count -or $State.Inputs.Register.Text -match 'Rodada MTA:') { throw 'Origem MTA nao resolvida; informe MtaDiretorio sem mudar a base da proposta.' }
    else { return }
    $internal=$origin.StartsWith($State.Inputs.Session.DataRoot+'\',[StringComparison]::OrdinalIgnoreCase)
    if ($internal -and -not $origin.StartsWith($State.Inputs.Session.DataRoot+'\runs\',[StringComparison]::OrdinalIgnoreCase)) { throw 'Origem MTA interna fora da area legada de runs; delimite o relatorio antes de converter.' }
    if (-not $internal) { $State.MtaDirectory=$origin }
    $State.MtaOrigin=$origin
    $State.MtaInventory=Get-ConversionMtaInventory $origin $State.Project.Root
    $reader={param($Path)
        $text=[IO.File]::ReadAllText($Path)
        if ($State.MtaObserved.ContainsKey($Path) -and $State.MtaObserved[$Path] -cne $text) { throw (New-Object IO.IOException 'Origem MTA mudou durante a conversao.') }
        $State.MtaObserved[$Path]=$text
        $text
    }.GetNewClosure()
    try { $mta=Read-HarnessMtaDirectory $State.Project $origin -FileReader $reader }
    catch {
        $failure=$_.Exception
        while ($failure) {
            if ($failure -is [IO.IOException] -or $failure -is [UnauthorizedAccessException] -or $failure.Data.Contains('MtaChanged')) { throw }
            $failure=$failure.InnerException
        }
        if ($internal) { throw }
        $State.Diagnostics.Add('Origem MTA configurada, mas indisponivel: '+$_.Exception.Message)
        return
    }
    foreach ($diagnostic in $mta.Diagnostics) { $State.Diagnostics.Add($diagnostic) }
    if ($internal) {
        $base=Split-Path $mta.ReportPath -Parent
        $pending=New-Object 'Collections.Generic.Stack[string]'; $pending.Push($base)
        while ($pending.Count) {
            $directory=$pending.Pop()
            if ($directory -ine $base -and (Test-Path -LiteralPath (Join-Path $directory 'index.html') -PathType Leaf) -and (Test-Path -LiteralPath (Join-Path $directory 'output.js') -PathType Leaf)) {
                $raw=& $reader (Join-Path $directory 'output.js')
                # Outro conjunto reconhecivel aninhado nao pertence aos assets
                # do selecionado. Nao publica historia nem depende de mtimes copiados.
                if ($raw -match '^\s*window\["apps"\]\s*=') { continue }
            }
            foreach ($entry in Get-ChildItem -LiteralPath $directory -Force) {
                $path=Resolve-ProjectPath $entry.FullName $State.Project.Root
                if ($entry.PSIsContainer) { $pending.Push($path); continue }
                $relative='atual/diagnosticos/mta/'+$path.Substring($base.Length+1).Replace('\','/')
                $State.Files[$relative]=Read-ConversionBytes $State $path
                $State.Map[$path]=Join-Path $State.Project.Folder $relative
            }
        }
        $mta.ReportPath=$State.Map[$mta.ReportPath]
        $mta.CatalogPath=$State.Map[$mta.CatalogPath]
    }
    foreach ($attachment in $State.Inputs.Preview.Attachments | Where-Object Kind -In @('COPIA_DIAGNOSTICO_LEGADO','EXTRATO_MTA')) {
        if ((Get-LegacyValue $attachment 'OwnerSource') -ieq $State.Inputs.Preview.LegacySource) { $State.Map[$attachment.Path]=$mta.ReportPath }
    }
    $State.Mta=$mta
}
