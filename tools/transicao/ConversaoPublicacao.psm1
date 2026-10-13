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
. (Join-Path $PSScriptRoot 'ConversaoEvidencias.ps1')
. (Join-Path $PSScriptRoot 'ConversaoMta.ps1')
. (Join-Path $PSScriptRoot 'ConversaoDiagnosticos.ps1')
. (Join-Path $PSScriptRoot 'ConversaoBuild.ps1')
. (Join-Path $PSScriptRoot 'ConversaoSonarDecisoes.ps1')
. (Join-Path $PSScriptRoot 'ConversaoSonar.ps1')
. (Join-Path $PSScriptRoot '../../scripts/HarnessPrioritizationState.ps1')
. (Join-Path $PSScriptRoot '../../scripts/HarnessPrioritizationIndex.ps1')
. (Join-Path $PSScriptRoot 'ConversaoPriorizacao.ps1')
. (Join-Path $PSScriptRoot 'ConversaoDocumentos.ps1')

function Invoke-ConversionApply {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][string]$Workspace,[Parameter(Mandatory=$true)][string]$Pom,[string]$SourceLegado,[string]$Registro,[string]$Contexto,[string]$MtaDiretorio,[string[]]$PrioritizacaoContexto=@(),[string]$BuildResultado,[string]$SonarResultado,[string]$SonarTentativa)
    $pomPath=Resolve-ProjectPath $Pom ([IO.Path]::GetFullPath($Workspace))
    # O nome da pasta e os documentos devem observar o mesmo POM. Manter apenas
    # compartilhamento de leitura impede troca/renomeacao durante a publicacao.
    $pomGuard=[IO.File]::Open($pomPath,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read)
    $lease=$null
    try {
        $project=Get-HarnessProjectReference $Workspace $pomPath
        $lease=Enter-HarnessProjectAccess $project -ForOperation
        $inputs=Read-ConversionInputs -Workspace $Workspace -Pom $Pom -SourceLegado $SourceLegado -Registro $Registro -Contexto $Contexto
        $state=New-ConversionCoreFiles $inputs $MtaDiretorio $PrioritizacaoContexto $BuildResultado $SonarResultado $SonarTentativa
        $expected=Read-HarnessProjectFiles $project @($state.Files.Keys) -AsBytes
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
        if ($writes.Count) { Publish-HarnessProjectFiles $project $writes $expected }
        [pscustomobject]@{Status=$(if ($writes.Count) {'CONVERTIDO'} else {'EQUIVALENTE'});Project=$project.Name;Destination=$project.Folder;ChangedFiles=@($writes.Keys);Diagnostics=@($state.Diagnostics);AuthorizationInherited=$false}
    } finally { if ($lease) { $lease.ReleaseMutex(); $lease.Dispose() }; $pomGuard.Dispose() }
}
Export-ModuleMember -Function Invoke-ConversionApply
