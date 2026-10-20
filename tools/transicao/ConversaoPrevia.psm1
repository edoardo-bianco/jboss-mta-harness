#requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot '../../scripts/HarnessProject.psm1') -DisableNameChecking
. (Join-Path $PSScriptRoot 'LegadoLeitura.ps1')
. (Join-Path $PSScriptRoot 'LegadoPlanejamento.ps1')
. (Join-Path $PSScriptRoot 'LegadoInventario.ps1')
. (Join-Path $PSScriptRoot 'LegadoAnexos.ps1')

function Read-ConversionInputs {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][string]$Workspace,[Parameter(Mandatory=$true)][string]$Pom,[string]$SourceLegado,[string]$Registro,[string]$Contexto)
    $project=Get-HarnessProjectReference $Workspace $Pom
    $source=if ($SourceLegado) {Resolve-ProjectPath $SourceLegado $project.Root} else {$project.Source}
    $session=[pscustomobject]@{Workspace=$project.Root;DataRoot=(Join-Path $project.Root '.harness');Observed=@{};Pending=(New-Object 'Collections.Generic.List[string]');ReadErrors=(New-Object 'Collections.Generic.List[object]')}
    $lease=Enter-HarnessProjectAccess $project -ReadOnly
    try {
        $configuration=Read-ConversionText $session $project.ConfigPath
        if ($configuration -and (Resolve-ProjectPath (ConvertFrom-Json $configuration).pom $project.Root) -ine $project.Pom) { throw 'Colisao de artifactId: destino associado a outro POM.' }
        $projectsRoot=Join-Path $project.Root '.harness/projetos'
        if (Test-Path -LiteralPath $projectsRoot -PathType Container) {
            foreach ($folder in Get-ChildItem -LiteralPath $projectsRoot -Directory | Sort-Object Name) {
                if ($folder.FullName -ieq $project.Folder) { continue }
                $association=Read-ConversionText $session (Join-Path $folder.FullName 'projeto.json')
                if ($association -and (Resolve-ProjectPath (ConvertFrom-Json $association).pom $project.Root) -ieq $project.Pom) { throw ('artifactId alterado: realinhe a associacao existente em '+$folder.FullName) }
            }
        }
        $inventory=@(Get-ConversionInventory $session | Sort-Object Path)
        $records=@(Read-ConversionRecords $session $inventory $source)
        $association=Get-ConversionPlanningAssociation $session $inventory $project $source
        foreach ($record in $records | Where-Object Path -IEQ $association) { $record.Kind='ASSOCIACAO' }
        $registers=@($records | Where-Object Kind -EQ 'REGISTRO')
        if ($Registro) {
            $path=Resolve-ProjectPath $Registro $project.Root
            $registers=@($registers | Where-Object Path -IEQ $path)
            if ($registers.Count -ne 1) { throw 'Registro escolhido nao pertence ao Source legado selecionado.' }
        }
        $register=$null
        if ($registers.Count -eq 1) {
            $record=$registers[0]
            $register=[pscustomobject]@{Path=$record.Path;Text=$record.Text;Decisions=@(Read-ConversionDecisions $record.Text)}
        } elseif ($registers.Count -gt 1) { $session.Pending.Add('Mais de um registro para o Source legado; escolha Registro explicitamente.') }
        else { $session.Pending.Add('Registro legado nao associado ao POM; informe SourceLegado se o checkout foi relocalizado.') }
        $planning=Select-ConversionPlan $session @($records | Where-Object Kind -EQ 'PLANEJAMENTO') $register $Contexto
        $planning|Add-Member Documents (Get-ConversionPlanDocuments $session $planning.Record)
        $proposed=@([pscustomobject]@{Origin=$project.Pom;Destination=$project.ConfigPath;Action='ASSOCIAR_POM';Exists=(Test-Path -LiteralPath $project.ConfigPath)})
        if ($association) { $proposed+=[pscustomobject]@{Origin=$association;Destination=$project.ConfigPath;Action='CONVERTER_ASSOCIACAO';Exists=(Test-Path -LiteralPath $project.ConfigPath)} }
        if ($register) { $proposed+=[pscustomobject]@{Origin=$register.Path;Destination=$project.MigrationPath;Action='PRESERVAR_DECISOES_E_REESCREVER_LINKS';Exists=(Test-Path -LiteralPath $project.MigrationPath)} }
        if ($planning.Record) {
            foreach ($document in $planning.Documents.Items) {
                if ($null -eq $document.Text) { continue }
                $destination=$project.($document.Field)
                $proposed+=[pscustomobject]@{Origin=$document.Origin;Destination=$destination;Action='PRESERVAR_TEXTO_REVISAR_GO';Exists=(Test-Path -LiteralPath $destination)}
            }
            $proposed+=[pscustomobject]@{Origin=$planning.ContextPath;Destination=$project.ContextPath;Action='TRANSFORMAR_CONTEXTO_SEM_RECIBO';Exists=(Test-Path -LiteralPath $project.ContextPath)}
        }
        if (@($proposed | Where-Object Exists).Count) { $session.Pending.Add('Destino possui dados; Aplicar devera conferir equivalencia ou conflito, sem sobrescrever trabalho novo.') }
        $reconciliation=Get-ConversionReconciliation $session $records $register
        $references=@(Get-ConversionReferences $session $proposed $project $source)
        $attachments=@(Get-ConversionAttachments $session $planning.Record)
        foreach ($priority in @($records | Where-Object Kind -EQ 'PRIORIZACAO')) { $attachments+=@(Get-ConversionAttachments $session $priority) }
        $related=@(Get-ConversionRelated $session $records $project $attachments)
        Assert-ConversionUnchanged $session $inventory
        $preview=[pscustomobject][ordered]@{Mode='Previa';Project=$project.Name;Pom=$project.Pom;Source=$project.Source;LegacySource=$source;Destination=$project.Folder;
            Register=[pscustomobject]@{Path=$(if ($register) {$register.Path} else {$null});Candidates=@($registers | ForEach-Object Path);Decisions=@(if ($register) {$register.Decisions})};
            Planning=[pscustomobject]@{ContextPath=$planning.ContextPath;Selection=$planning.Selection;Candidates=@($planning.Candidates);DocumentsState=$planning.Documents.State};
            Reconciliation=$reconciliation;Related=$related;References=$references;Attachments=$attachments;
            ProposedFiles=@($proposed);Pending=@($session.Pending | Sort-Object -Unique);AuthorizationInherited=$false;DeletionAuthorized=$false;
            DiscardCandidates=@($records | Where-Object { $_.Sources.Count -eq 1 -and -not $_.Path.StartsWith($project.Folder+'\',[StringComparison]::OrdinalIgnoreCase) } | ForEach-Object Path | Sort-Object -Unique);
            DiscardCondition='Use Modo Limpar sem Descartar para conferir elegibilidade apos a conversao; descarte exige arquivos selecionados e confirmacao. Diretorios, Source e MTA externo sao preservados.'}
        [pscustomobject]@{Preview=$preview;Project=$project;Session=$session;Records=$records;Register=$register;Planning=$planning;Inventory=$inventory}
    } finally { $lease.ReleaseMutex(); $lease.Dispose() }
}
function Get-ConversionPreview {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][string]$Workspace,[Parameter(Mandatory=$true)][string]$Pom,[string]$SourceLegado,[string]$Registro,[string]$Contexto)
    (Read-ConversionInputs @PSBoundParameters).Preview
}
Export-ModuleMember -Function Get-ConversionPreview,Read-ConversionInputs
