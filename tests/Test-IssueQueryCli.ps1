#requires -Version 5.1
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Test-IssueQueries.ps1')
$cli=Join-Path $root 'scripts/consultar-issues.ps1'
Assert (Test-Path -LiteralPath $cli) 'CLI consultar-issues.ps1 ausente.'
function Invoke-QueryCli($arguments) {
    $output=@(& powershell.exe -NoProfile -File $cli @arguments)
    $code=$LASTEXITCODE
    $json=$output -join "`n"
    try { $value=$json | ConvertFrom-Json } catch { throw "CLI nao retornou somente JSON: $json" }
    Assert ($value.SchemaVersion -eq 1 -and $value.ReadOnly) 'Envelope CLI divergente.'
    [pscustomobject]@{Value=$value;ExitCode=$code;Bytes=[Text.Encoding]::UTF8.GetByteCount($json)}
}
$before=Inventory $area
$common=@('-Root',$fixture,'-ContextPath',$prepared.ContextPath)
$listing=Invoke-QueryCli (@('-Action','listar_issues','-PageSize','2')+$common)
Assert ($listing.ExitCode -eq 0 -and $listing.Value.Paging.Returned -eq 2) 'Lista CLI divergente.'
$detail=Invoke-QueryCli (@('-Action','obter_issue','-Id',$issueId,'-Incident','138')+$common)
Assert ($detail.ExitCode -eq 0 -and $detail.Value.Data.Incidents[0].Ordinal -eq 138) 'Ordinal CLI divergente.'
foreach ($arguments in @(@('-Page','abc'),@('-PageSize','51'),@('-Desconhecido','x'),@('-Page'),@('-Page','1','-Page','2'))) {
    $invalid=Invoke-QueryCli (@('-Action','listar_issues')+$common+$arguments)
    Assert ($invalid.ExitCode -eq 1 -and $invalid.Value.Error.Code -eq 'INVALID_INPUT') 'Parametro invalido fora do contrato JSON.'
}
$missing=Invoke-QueryCli @('-Action','listar_issues')
Assert ($missing.ExitCode -eq 1 -and $missing.Value.Error.Code -eq 'INVALID_INPUT') 'Contexto ausente fora do contrato JSON.'
$largeError=Invoke-QueryCli @('-Action',('x'*4096),('-'+('x'*4096)),'x')
Assert ($largeError.ExitCode -eq 1 -and $largeError.Bytes -lt 4096 -and $largeError.Value.Error.MessageTruncated -and $null -eq $largeError.Value.Action) 'Erro de argumentos sem limite declarado.'
$empty=Invoke-QueryCli (@('-Action','listar_issues','-Text','nao existe')+$common)
Assert ($empty.ExitCode -eq 0 -and $empty.Value.Paging.Total -eq 0) 'Consulta vazia confundida com falha.'
Assert ((Inventory $area) -ceq $before) 'CLI alterou evidencias.'
$rawBytes=(Get-Item -LiteralPath $catalog).Length
Write-Host "PASS: CLI JSON/exit codes/parametros/leitura. Fixture: catalogo=$rawBytes bytes; lista de 2=$($listing.Bytes); detalhe de 1 incidente=$($detail.Bytes). Nao mede tokens/acerto."

