#requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot '../../scripts/HarnessProject.psm1') -DisableNameChecking
Import-Module (Join-Path $PSScriptRoot '../../scripts/HarnessPlanning.psm1') -DisableNameChecking
Import-Module (Join-Path $PSScriptRoot '../../scripts/HarnessSonarReview.psm1') -DisableNameChecking
Import-Module (Join-Path $PSScriptRoot 'ConversaoPrevia.psm1') -DisableNameChecking
. (Join-Path $PSScriptRoot 'LegadoLeitura.ps1')
. (Join-Path $PSScriptRoot 'LegadoPlanejamento.ps1')
. (Join-Path $PSScriptRoot '../../scripts/HarnessIssueSources.ps1')
. (Join-Path $PSScriptRoot 'ConversaoPropriedade.ps1')
. (Join-Path $PSScriptRoot 'ConversaoEvidencias.ps1')
. (Join-Path $PSScriptRoot 'ConversaoMta.ps1')
. (Join-Path $PSScriptRoot 'ConversaoParticipantes.ps1')
. (Join-Path $PSScriptRoot 'ConversaoDiagnosticos.ps1')
. (Join-Path $PSScriptRoot 'ConversaoBuild.ps1')
. (Join-Path $PSScriptRoot 'ConversaoSonarDecisoes.ps1')
. (Join-Path $PSScriptRoot 'ConversaoSonar.ps1')
. (Join-Path $PSScriptRoot '../../scripts/HarnessPrioritizationState.ps1')
. (Join-Path $PSScriptRoot '../../scripts/HarnessPrioritizationIndex.ps1')
. (Join-Path $PSScriptRoot 'ConversaoPriorizacao.ps1')
. (Join-Path $PSScriptRoot 'ConversaoDocumentos.ps1')
. (Join-Path $PSScriptRoot '../../scripts/HarnessSprintPresentation.ps1')
. (Join-Path $PSScriptRoot '../../scripts/HarnessSprintState.ps1')
. (Join-Path $PSScriptRoot '../../scripts/HarnessSprintSimulation.ps1')
. (Join-Path $PSScriptRoot 'ConversaoSprintsLeitura.ps1')
. (Join-Path $PSScriptRoot 'ConversaoSprints.ps1')

function Get-ConversionParticipants([string]$Workspace,[string]$Pom,[string]$SourceLegado,[Collections.IDictionary]$Participantes) {
    $current=Get-HarnessProjectReference $Workspace $Pom
    $source=if ($SourceLegado) {Resolve-ProjectPath $SourceLegado $current.Root} else {$current.Source}
    $mapping=@{}; $mapping[$source]=[pscustomobject]@{Pom=$current.Pom;Registro=$null;Contexto=$null;MtaDiretorio=$null}
    foreach ($key in $Participantes.Keys) {
        $legacy=Resolve-ProjectPath $key $current.Root
        $value=$Participantes[$key]
        if ($value -is [string]) { $value=[pscustomobject]@{Pom=$value} }
        elseif ($value -is [Collections.IDictionary]) { $value=[pscustomobject]$value }
        $pomPath=Resolve-ProjectPath (Get-LegacyValue $value 'Pom') $current.Root
        if ($mapping.ContainsKey($legacy) -and $mapping[$legacy].Pom -ine $pomPath) { throw 'Source legado associado a POMs diferentes.' }
        $next=[pscustomobject]@{Pom=$pomPath;Registro=(Get-LegacyValue $value 'Registro');Contexto=(Get-LegacyValue $value 'Contexto');MtaDiretorio=(Get-LegacyValue $value 'MtaDiretorio')}
        if ($mapping.ContainsKey($legacy)) {
            foreach ($name in @('Registro','Contexto','MtaDiretorio')) {
                $previous=$mapping[$legacy].$name
                if ($previous -and $next.$name -and (Resolve-ProjectPath $previous $current.Root) -ine (Resolve-ProjectPath $next.$name $current.Root)) { throw ('Source participante com escolhas conflitantes: '+$name) }
                if ($previous -and -not $next.$name) { $next.$name=$previous }
            }
        }
        $mapping[$legacy]=$next
    }
    $names=@{}; $poms=@{}
    foreach ($legacy in $mapping.Keys) {
        $project=Get-HarnessProjectReference $current.Root $mapping[$legacy].Pom
        if ($names.ContainsKey($project.Name) -or $poms.ContainsKey($project.Pom)) { throw 'Participantes com artifactId/POM duplicado; nao consolidar Sources distintos.' }
        $names[$project.Name]=[pscustomobject]@{LegacySource=$legacy;Project=$project;Options=$mapping[$legacy]}
        $poms[$project.Pom]=$true
    }
    $ordered=[string[]]@($names.Keys); [Array]::Sort($ordered,[StringComparer]::Ordinal)
    foreach ($name in $ordered) { $names[$name] }
}

function Invoke-ConversionApply {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][string]$Workspace,[Parameter(Mandatory=$true)][string]$Pom,[string]$SourceLegado,[string]$Registro,[string]$Contexto,[string]$MtaDiretorio,[string[]]$PrioritizacaoContexto=@(),[string]$BuildResultado,[string]$SonarResultado,[string]$SonarTentativa,[Collections.IDictionary]$Participantes=@{},[object[]]$Sprints=@(),[switch]$VerifyOnly)
    $pomPath=Resolve-ProjectPath $Pom ([IO.Path]::GetFullPath($Workspace))
    # O nome da pasta e os documentos devem observar o mesmo POM. Manter apenas
    # compartilhamento de leitura impede troca/renomeacao durante a publicacao.
    $participants=@(Get-ConversionParticipants $Workspace $pomPath $SourceLegado $Participantes)
    $guards=@(); $leases=@()
    try {
        if ($Sprints.Count) { $leases+=Enter-SprintAccess ([IO.Path]::GetFullPath($Workspace)) }
        foreach ($entry in $participants) {
            $guards+=[IO.File]::Open($entry.Project.Pom,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read)
            $checked=Get-HarnessProjectReference $Workspace $entry.Project.Pom
            if ($checked.Name -cne $entry.Project.Name -or $checked.Source -ine $entry.Project.Source) { throw 'POM participante mudou durante a associacao; repita a leitura.' }
        }
        $project=Get-HarnessProjectReference $Workspace $pomPath
        foreach ($entry in $participants) {
            if ($entry.Project.Pom -ieq $pomPath -and -not $VerifyOnly) { $leases+=Enter-HarnessProjectAccess $entry.Project -ForOperation }
            else { $leases+=Enter-HarnessProjectAccess $entry.Project -ReadOnly }
        }
        $options=@($participants | Where-Object { $_.Project.Pom -ieq $pomPath })[0].Options
        foreach ($name in @('Registro','Contexto','MtaDiretorio')) {
            $explicit=Get-Variable -Name $name -ValueOnly
            if ($explicit -and $options.$name -and (Resolve-ProjectPath $explicit $project.Root) -ine (Resolve-ProjectPath $options.$name $project.Root)) { throw ('Escolhas conflitantes do participante: '+$name) }
            if (-not $explicit -and $options.$name) { Set-Variable -Name $name -Value $options.$name }
        }
        $inputs=Read-ConversionInputs -Workspace $Workspace -Pom $Pom -SourceLegado $SourceLegado -Registro $Registro -Contexto $Contexto
        $state=New-ConversionCoreFiles $inputs $MtaDiretorio $PrioritizacaoContexto $BuildResultado $SonarResultado $SonarTentativa $participants $Sprints
        $expected=Read-HarnessProjectFiles $project @($state.Files.Keys) -AsBytes
        if ($inputs.Planning.Documents.State -eq 'AUSENTES') {
            # Uma proposta criada depois da leitura tambem invalida o preparo.
            $expected['atual/planejamento/plano.md']=$null
            $expected['atual/planejamento/tarefas.md']=$null
        }
        $writes=[ordered]@{}
        foreach ($relative in $state.Files.Keys) {
            [byte[]]$bytes=if ($state.Files[$relative] -is [byte[]]) {$state.Files[$relative]} else {(New-Object Text.UTF8Encoding($false)).GetBytes([string]$state.Files[$relative])}
            if ($null -eq $expected[$relative]) { $writes[$relative]=$bytes }
            elseif ([Convert]::ToBase64String($expected[$relative]) -cne [Convert]::ToBase64String($bytes)) { throw ('Destino diferente da conversao; preservar trabalho local: '+(Join-Path $project.Folder $relative)) }
        }
        Assert-ConversionUnchanged $inputs.Session $inputs.Inventory
        foreach ($path in $state.Bytes.Keys) {
            if (-not (Test-Path -LiteralPath $path -PathType Leaf) -or [Convert]::ToBase64String([IO.File]::ReadAllBytes($path)) -cne [Convert]::ToBase64String($state.Bytes[$path])) { throw ('Anexo mudou durante a conversao: '+$path) }
        }
        foreach ($path in $state.MtaObserved.Keys) {
            if (-not (Test-Path -LiteralPath $path -PathType Leaf) -or [IO.File]::ReadAllText($path) -cne $state.MtaObserved[$path]) { throw ('Origem MTA mudou durante a conversao: '+$path) }
        }
        if ($state.MtaOrigin -and (Get-ConversionMtaInventory $state.MtaOrigin $project.Root) -cne $state.MtaInventory) { throw 'Conjunto/selecao MTA mudou durante a conversao; repita a leitura.' }
        Assert-ConversionSonarUnchanged $state
        Assert-ConversionParticipantMtaUnchanged $state
        foreach ($path in $state.PartnerObserved.Keys) {
            if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw 'Arquivo participante removido durante a conversao.' }
            $expectedPartner=$state.PartnerObserved[$path]
            $changed=if ($expectedPartner -is [byte[]]) { [Convert]::ToBase64String([IO.File]::ReadAllBytes($path)) -cne [Convert]::ToBase64String($expectedPartner) } else { [IO.File]::ReadAllText($path) -cne $expectedPartner }
            if ($changed) { throw 'Arquivo participante mudou durante a conversao; repita a leitura.' }
        }
        if ($VerifyOnly) {
            if ($writes.Count) { throw 'Conversao ainda incompleta: destino ausente; descarte recusado.' }
            return $state
        }
        if ($writes.Count) { Publish-HarnessProjectFiles $project $writes $expected }
        [pscustomobject]@{Status=$(if ($writes.Count) {'CONVERTIDO'} else {'EQUIVALENTE'});Project=$project.Name;Destination=$project.Folder;ChangedFiles=@($writes.Keys);Diagnostics=@($state.Diagnostics);AuthorizationInherited=$false}
    } finally {
        for ($i=$leases.Count-1;$i -ge 0;$i--) { $leases[$i].ReleaseMutex(); $leases[$i].Dispose() }
        foreach ($guard in $guards) { $guard.Dispose() }
    }
}
Export-ModuleMember -Function Invoke-ConversionApply
