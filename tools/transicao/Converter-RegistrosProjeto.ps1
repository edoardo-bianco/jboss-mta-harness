#requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$Workspace,
    [Parameter(Mandatory=$true)][string]$Pom,
    [ValidateSet('Previa','Aplicar','Validar','Limpar')][string]$Modo='Previa',
    [string]$SourceLegado,
    [string]$Registro,
    [string]$Contexto,
    [string]$MtaDiretorio,
    [string[]]$PrioritizacaoContexto=@(),
    [string]$BuildResultado,
    [string]$SonarResultado,
    [string]$SonarTentativa,
    [Collections.IDictionary]$Participantes=@{},
    [object[]]$Sprints=@(),
    [ValidateSet('Texto','Json')][string]$Formato='Texto'
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
if ($Modo -eq 'Limpar') { throw 'Limpar permanece em S23. Aplicar/Validar preservam todos os originais.' }
if ($Modo -eq 'Validar') {
    Import-Module (Join-Path $PSScriptRoot 'ConversaoValidacao.psm1') -Force -DisableNameChecking
    $result=Test-ConversionCurrent -Workspace $Workspace -Pom $Pom
    if ($Formato -eq 'Json') { $result|ConvertTo-Json -Depth 40; return }
    "Integridade operacional: $($result.Status) - $($result.Project)"
    "Destino: $($result.Destination)"
    foreach ($item in $result.Diagnostics) { "PENDENTE: $item" }
    $result.Scope
    return
}
if ($Modo -eq 'Aplicar') {
    Import-Module (Join-Path $PSScriptRoot 'ConversaoPublicacao.psm1') -Force -DisableNameChecking
    $choices=@{Workspace=$Workspace;Pom=$Pom;SourceLegado=$SourceLegado;Registro=$Registro;Contexto=$Contexto;MtaDiretorio=$MtaDiretorio;PrioritizacaoContexto=$PrioritizacaoContexto;BuildResultado=$BuildResultado;SonarResultado=$SonarResultado;SonarTentativa=$SonarTentativa;Participantes=$Participantes;Sprints=$Sprints}
    $result=Invoke-ConversionApply @choices
    if ($Formato -eq 'Json') { $result|ConvertTo-Json -Depth 40; return }
    "Conversao: $($result.Status) - $($result.Project)"
    "Destino: $($result.Destination)"
    foreach ($path in $result.ChangedFiles) { "Publicado: $path" }
    foreach ($item in $result.Diagnostics) { "CONFERIR: $item" }
    'Originais preservados. Conferir os documentos correntes com Validar; revisao humana, GO e aceite permanecem separados.'
    return
}
Import-Module (Join-Path $PSScriptRoot 'ConversaoPrevia.psm1') -Force -DisableNameChecking
$preview=Get-ConversionPreview -Workspace $Workspace -Pom $Pom -SourceLegado $SourceLegado -Registro $Registro -Contexto $Contexto
if ($Formato -eq 'Json') { $preview | ConvertTo-Json -Depth 40; return }
"Previa sem escrita: $($preview.Project)"
"POM: $($preview.Pom)"
"Source local: $($preview.Source)"
"Source legado: $($preview.LegacySource)"
"Destino: $($preview.Destination)"
"Registro escolhido: $($preview.Register.Path)"
foreach ($path in $preview.Register.Candidates) { "  Registro candidato: $path" }
foreach ($row in $preview.Register.Decisions) { "  Decisao preservada: $($row.Id) | $($row.Decision) | $($row.Progress) | $($row.Note)" }
"Plano: $($preview.Planning.Selection) $($preview.Planning.ContextPath)"
foreach ($path in $preview.Planning.Candidates) { "  Contexto candidato: $path" }
"Reconciliacao: $($preview.Reconciliation.State). $($preview.Reconciliation.Reason)"
foreach ($item in $preview.Reconciliation.Declarations) { "  Declaracao $($item.State): $($item.Path) [$($item.Field)] ($($item.Evidence))" }
foreach ($item in $preview.ProposedFiles) { "Proposta $($item.Action): $($item.Origin) -> $($item.Destination) (destino existe: $($item.Exists))" }
foreach ($item in $preview.Related) { "Candidato $($item.Kind): $($item.Path) -> $($item.ProposedDirectory) ($($item.Selection))" }
foreach ($item in $preview.References) { "Referencia em $($item.Document): $($item.Origin) -> $($item.Destination) ($($item.Action); origem disponivel: $($item.Available); destino disponivel: $($item.DestinationAvailable))" }
foreach ($item in $preview.Attachments) { "Anexo/origem $($item.Kind) [$($item.Field)]: $($item.Path) (disponivel: $($item.Available); $($item.Selection))" }
foreach ($item in $preview.Pending) { "PENDENTE: $item" }
'Descarte apenas informativo, sem autorizacao:'
foreach ($path in $preview.DiscardCandidates) { "  $path" }
$preview.DiscardCondition
'Nenhum GO ou aceite herdado. Nenhum arquivo gravado, recuperado ou removido.'
