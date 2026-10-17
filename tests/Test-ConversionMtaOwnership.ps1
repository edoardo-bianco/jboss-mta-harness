#requires -Version 5.1
$ErrorActionPreference='Stop'; Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'ConversionFixture.ps1')
Import-Module (Join-Path $root 'tools/transicao/ConversaoPublicacao.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $root 'tools/transicao/ConversaoPrevia.psm1') -DisableNameChecking
Import-Module (Join-Path $root 'scripts/HarnessProject.psm1') -DisableNameChecking
$failures=New-Object 'Collections.Generic.List[string]'
function Check-Ownership($Value,[string]$Message) { if (-not $Value) { $failures.Add($Message) } }
function New-OwnershipState($Project,$Session,$Attachments,[string]$RegisterText) {
    [pscustomobject]@{
        Project=$Project
        Inputs=[pscustomobject]@{Session=$Session;Planning=[pscustomobject]@{Record=$null};Register=[pscustomobject]@{Text=$RegisterText};Preview=[pscustomobject]@{Attachments=$Attachments;LegacySource=$Project.Source}}
        Files=[ordered]@{};Map=@{};Bytes=@{};MtaObserved=@{};Mta=$null;MtaDirectory=$null;MtaOrigin=$null;MtaInventory=$null
        Diagnostics=(New-Object 'Collections.Generic.List[string]');EvidenceInputs=@();FichaPaths=@();EvidenceIndexPath=$null
    }
}
$f=New-ConversionFixture
$sourceB=Join-Path $f.Area 'aplicacao-b'
Write-ConversionFile (Join-Path $sourceB 'pom.xml') '<project><artifactId>api-b</artifactId></project>'
$folder=Join-Path $f.Workspace '.harness/priorizacao/multiprojeto'
$context=Join-Path $folder 'context.json'
$indexA=Join-Path $folder 'incidentes-a/indice.md'; $pageA=Join-Path $folder 'incidentes-a/pagina.md'
$indexB=Join-Path $folder 'incidentes-b/indice.md'; $pageB=Join-Path $folder 'incidentes-b/pagina.md'
$copyB=Join-Path $folder 'anexos/copia-renomeada.md'
Write-ConversionFile $indexA '# Indice MTA A'
Write-ConversionFile $pageA 'Extrato MTA exclusivo do projeto A'
Write-ConversionFile $indexB '# Indice MTA B'
Write-ConversionFile $pageB 'Extrato MTA exclusivo do projeto B'
Write-ConversionFile $copyB ([IO.File]::ReadAllText($pageB))
$data=@{
    Purpose='issue-prioritization'
    Projects=@(
        @{Source=$f.Source;Mta=@{IncidentEvidence=@{IndexPath=$indexA;Files=@(@{Path=$pageA})}}},
        @{Source=$sourceB;Mta=@{IncidentEvidence=@{IndexPath=$indexB;Files=@(@{Path=$pageB})}}}
    )
    Consolidated=@{Files=@(@{RelativePath='anexos/copia-renomeada.md';OriginPath=$pageB})}
}
Write-ConversionFile $context ($data|ConvertTo-Json -Depth 12)
$record=[pscustomobject]@{Path=$context;Data=(Get-Content -LiteralPath $context -Raw|ConvertFrom-Json)}
$origin=Join-Path $f.Area 'mta externo a'
Write-ConversionFile (Join-Path $origin 'index.html') '<html>Relatorio MTA A</html>'
$apps=@(@{artifactId='api';rulesets=@(@{name='java';violations=@{regra=@{description='Problema A';category='mandatory';incidents=@()}}})})
Write-ConversionFile (Join-Path $origin 'output.js') ('window["apps"] = '+(ConvertTo-Json -InputObject $apps -Depth 12 -Compress)+';')
$session=[pscustomobject]@{Workspace=$f.Workspace;DataRoot=(Join-Path $f.Workspace '.harness');Observed=@{};Pending=(New-Object 'Collections.Generic.List[string]')}
$before=Get-ConversionState $f
$previewModule=Get-Module ConversaoPrevia
$attachments=@(& $previewModule { param($Session,$Record) Get-ConversionAttachments $Session $Record } $session $record)
foreach ($pair in @(@($indexA,$f.Source),@($pageA,$f.Source),@($indexB,$sourceB),@($pageB,$sourceB),@($copyB,$sourceB))) {
    $entries=@($attachments | Where-Object Path -IEQ $pair[0])
    Check-Ownership ($entries.Count -eq 1) ('Inventario deve conter uma referencia a '+$pair[0])
    if ($entries.Count -eq 1) {
        $entry=$entries[0]
        Check-Ownership ($entry.PSObject.Properties['OwnerSource'] -and $entry.OwnerSource -ieq $pair[1]) ('OwnerSource deve preservar o dono de '+$pair[0])
        Check-Ownership ($entry.Kind -in @('EXTRATO_MTA','COPIA_DIAGNOSTICO_LEGADO')) ('Extrato/copia deve conservar o papel diagnostico: '+$pair[0])
    }
}
$project=Get-HarnessProjectReference $f.Workspace $f.Pom
$registerText=[IO.File]::ReadAllText($f.Register)
$state=New-OwnershipState $project $session $attachments $registerText
$publicationModule=Get-Module ConversaoPublicacao
& $publicationModule { param($State,$Origin) Add-ConversionMta $State $Origin } $state $origin
Assert ($null -ne $state.Mta) 'Fixture deve disponibilizar o MTA de A pelo parser real.'
foreach ($path in @($indexA,$pageA)) {
    Check-Ownership ($state.Map.ContainsKey($path) -and $state.Map[$path] -ieq $state.Mta.ReportPath) ('Extrato de A deve abrir MTA de A: '+$path)
}
foreach ($path in @($indexB,$pageB,$copyB)) {
    Check-Ownership (-not $state.Map.ContainsKey($path)) ('Add-ConversionMta nao pode atribuir extrato de B ao MTA de A: '+$path)
}
# Estado independente para testar o remapeamento dos aliases em Read-ConversionEvidence.
foreach ($withExamined in @($true,$false)) {
$evidenceState=New-OwnershipState $project $session $attachments $registerText
$evidenceState.Mta=$state.Mta
$priority=[pscustomobject]@{Records=@($record);Rankings=@();Fichas=@{}}
# Priorizacao pendente pode ter dicionario vazio; origens antigas podem omitir o campo.
if ($withExamined) { $priority | Add-Member -NotePropertyName Examined -NotePropertyValue ([ordered]@{}) }
$null=& $publicationModule { param($State,$Priority) Read-ConversionEvidence $State $null @($Priority) } $evidenceState $priority
foreach ($path in @($indexA,$pageA)) {
    Check-Ownership ($evidenceState.Map.ContainsKey($path) -and $evidenceState.Map[$path] -ieq $state.Mta.ReportPath) ('Leitura de evidencias deve resolver apenas o extrato de A: '+$path)
}
foreach ($path in @($indexB,$pageB,$copyB)) {
    Check-Ownership (-not $evidenceState.Map.ContainsKey($path)) ('Read-ConversionEvidence nao pode reatribuir extrato/alias de B: '+$path)
}
Check-Ownership ($evidenceState.EvidenceInputs.Count -eq 0 -and $evidenceState.Files.Count -eq 0) 'Extrato ou copia renomeada de B nao pode virar evidencia humana.'
}
Check-Ownership ((Get-ConversionState $f) -ceq $before) 'Leitura/conversao em memoria deve preservar todas as fontes e nao publicar arquivos.'
if ($failures.Count) { throw ($failures -join "`n") }
'PASS: propriedade dos extratos MTA por Source, copia renomeada e isolamento do MTA entre projetos.'
