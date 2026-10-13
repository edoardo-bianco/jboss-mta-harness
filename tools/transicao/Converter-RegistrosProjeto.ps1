#requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$Workspace,
    [Parameter(Mandatory=$true)][string]$Pom,
    [ValidateSet('Previa','Aplicar','Validar','Limpar')][string]$Modo='Previa',
    [string]$SourceLegado,
    [string]$Registro,
    [string]$Contexto,
    [ValidateSet('Texto','Json')][string]$Formato='Texto'
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
if ($Modo -ne 'Previa') { throw 'S20 entrega somente Previa. Aplicar/Validar permanecem em S21; Limpar em S23.' }
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
