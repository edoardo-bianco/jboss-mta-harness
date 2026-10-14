# Resolucao em memoria: a origem de cada participante usa as mesmas escolhas
# da conversao individual. Nenhum asset ou controle de outro projeto e publicado.
function Add-ConversionParticipantMta($State) {
    $sources=@{}; $sources[$State.Inputs.Preview.LegacySource]=$State.Mta
    $peers=@()
    foreach ($participant in @($State.Participants | Where-Object { $_.Project.Name -cne $State.Project.Name })) {
        $project=$participant.Project
        $options=$participant.Options
        $inputs=Read-ConversionInputs $project.Root $project.Pom -SourceLegado $participant.LegacySource -Registro $options.Registro -Contexto $options.Contexto
        if (-not $inputs.Register) { throw ('Escolha um registro unico para o participante '+$project.Name+'.') }
        if (@($inputs.Records | Where-Object Kind -EQ 'PLANEJAMENTO').Count -and -not $inputs.Planning.Record) { throw ('Plano do participante ambiguo; informe Contexto: '+$project.Name) }
        $peer=[pscustomobject]@{Project=$project;Inputs=$inputs;Files=[ordered]@{};Map=@{};Bytes=@{};MtaObserved=@{};Mta=$null;MtaDirectory=$null;MtaOrigin=$null;MtaInventory=$null;Diagnostics=(New-Object 'Collections.Generic.List[string]')}
        Add-ConversionMta $peer $options.MtaDiretorio -ReferencesOnly
        $sources[$participant.LegacySource]=$peer.Mta
        foreach ($path in $peer.Map.Keys) {
            if ($State.Map.ContainsKey($path) -and $State.Map[$path] -ine $peer.Map[$path]) { throw ('Origem compartilhada com destinos MTA conflitantes: '+$path) }
            $State.Map[$path]=$peer.Map[$path]
        }
        foreach ($diagnostic in $peer.Diagnostics) { $State.Diagnostics.Add($project.Name+': '+$diagnostic) }
        $peers+=@($peer)
    }
    $State|Add-Member ParticipantMta $sources
    $State|Add-Member ParticipantMtaStates $peers
    $State|Add-Member OwnershipInputs @(@($State.Inputs)+@($peers | ForEach-Object Inputs) | Sort-Object { $_.Project.Name })
}

function Assert-ConversionParticipantMtaUnchanged($State) {
    foreach ($peer in $State.ParticipantMtaStates) {
        Assert-ConversionUnchanged $peer.Inputs.Session $peer.Inputs.Inventory
        foreach ($path in $peer.MtaObserved.Keys) {
            if (-not (Test-Path -LiteralPath $path -PathType Leaf) -or [IO.File]::ReadAllText($path) -cne $peer.MtaObserved[$path]) { throw 'Origem MTA participante mudou durante a conversao.' }
        }
        if ($peer.MtaOrigin -and (Get-ConversionMtaInventory $peer.MtaOrigin $State.Project.Root) -cne $peer.MtaInventory) { throw 'Conjunto MTA participante mudou durante a conversao.' }
        # A existencia do destino nao elege a origem. Se ja publicado, precisa
        # concordar com a escolha calculada, inclusive quando nao ha MTA.
        $files=Read-HarnessProjectFiles $peer.Project @('projeto.json')
        if ($files['projeto.json']) {
            $config=ConvertFrom-Json $files['projeto.json']
            if ($config.mta.diretorio -ine $peer.MtaDirectory) { throw ('Origem MTA do participante diverge da escolha: '+$peer.Project.Name) }
            if (-not $peer.MtaDirectory) {
                # Configuracao null identifica armazenamento interno, nao qual
                # conjunto foi publicado. Conferir o conteudo selecionado.
                $names=@('atual/diagnosticos/mta/index.html','atual/diagnosticos/mta/output.js')
                $published=Read-HarnessProjectFiles $peer.Project $names
                foreach ($relative in $names) {
                    $target=Join-Path $peer.Project.Folder $relative
                    $origin=if ($peer.Mta) {if ($relative.EndsWith('index.html')) {$peer.MtaReportOrigin} else {$peer.MtaCatalogOrigin}} else {$null}
                    $expected=if ($origin) {$peer.MtaObserved[$origin]} else {$null}
                    if ($published[$relative] -cne $expected) { throw ('Conjunto MTA interno do participante diverge da escolha: '+$peer.Project.Name) }
                    if ($null -ne $published[$relative]) { $State.PartnerObserved[$target]=$published[$relative] }
                }
            }
        }
    }
}
