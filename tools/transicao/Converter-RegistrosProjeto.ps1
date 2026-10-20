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
    [string[]]$Descartar=@(),
    [string]$Confirmacao,
    [ValidateSet('Texto','Json')][string]$Formato='Texto'
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
if ($Modo -ne 'Limpar' -and ($PSBoundParameters.ContainsKey('Descartar') -or $PSBoundParameters.ContainsKey('Confirmacao'))) {
    throw 'Descartar e Confirmacao sao exclusivos do modo Limpar.'
}
$choices=@{Workspace=$Workspace;Pom=$Pom;SourceLegado=$SourceLegado;Registro=$Registro;Contexto=$Contexto;MtaDiretorio=$MtaDiretorio;PrioritizacaoContexto=$PrioritizacaoContexto;BuildResultado=$BuildResultado;SonarResultado=$SonarResultado;SonarTentativa=$SonarTentativa;Participantes=$Participantes;Sprints=$Sprints}
if ($Modo -eq 'Limpar') {
    Import-Module (Join-Path $PSScriptRoot 'ConversaoLimpeza.psm1') -Force -DisableNameChecking
    $execute=$Descartar.Count -gt 0 -or $PSBoundParameters.ContainsKey('Confirmacao')
    if ($execute) {
        if ($Formato -eq 'Json' -and -not $PSBoundParameters.ContainsKey('Confirmacao')) { throw 'Limpar em Json exige Confirmacao explicita; use a previa antes de selecionar arquivos.' }
        $cleanup=@{Descartar=$Descartar}
        if ($PSBoundParameters.ContainsKey('Confirmacao')) { $cleanup.ConfirmText=$Confirmacao }
        if ($Formato -eq 'Json') { $result=Invoke-ConversionCleanup @choices @cleanup 6>$null }
        else { $result=Invoke-ConversionCleanup @choices @cleanup }
    } else { $result=Get-ConversionCleanupPreview @choices }
    if ($Formato -eq 'Json') { $result|ConvertTo-Json -Depth 40; return }
    "Descarte legado: $($result.Status)"
    if ($execute) { foreach ($path in $result.RemovedFiles) { "Removido: $path" } }
    else {
        foreach ($item in $result.Candidates) { "Elegivel: $($item.Eligible) | $($item.Path) -> $($item.Destination) | $($item.Reason)" }
        if ($result.RecoveryPath) { "Recuperacao pendente: $($result.RecoveryPath). Use os arquivos exibidos em Descartar e Confirmacao RECUPERAR; sem arquivos exibidos, omita Descartar." }
        'Previa somente leitura. Selecione arquivos em Descartar e confirme LIMPAR para remover; outro texto cancela.'
    }
    'Integridade operacional nao concede revisao humana, GO ou aceite.'
    return
}
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
if ($preview.Planning.DocumentsState) { "Documentos do plano: $($preview.Planning.DocumentsState) (disponibilidade de plano/tarefas; nao comprova proposta concluida ou GO)" }
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
