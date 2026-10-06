#requires -Version 5.1
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Test-IssueQueries.ps1')
$module=Get-Module HarnessIssueQuery
# Interceptar o acesso em vez de tentar acessar uma rede real.
$unc=& $module {
    function Get-Item { throw 'IO_NAO_DEVERIA_SER_CHAMADO' }
    try { $null=Read-QueryFile '\\host\share\arquivo.json' @{} } catch { Get-QueryError $_ }
}
Assert ($unc.Code -eq 'INVALID_CONTEXT' -and $unc.Message -notmatch 'IO_NAO') 'UNC chegou ao filesystem.'
$lexical=& $module {
    function Resolve-HarnessPath { throw 'CAMINHO_HISTORICO_ACESSADO' }
    $project=[pscustomobject]@{Source='C:/colega/projeto';Mta=[pscustomobject]@{AnalysisSource='C:/historico/input';RunId=('b'*32);MtaOrigin=[pscustomobject]@{Run='C:/historico'}}}
    Get-IncidentLocation 'file:///C:/historico/input/src/Classe.java' $project -LexicalPaths
}
Assert ($lexical.SourceCandidate -eq 'C:\colega\projeto\src\Classe.java') 'Localizacao depende de acesso a origem historica.'
$receiptJson=[IO.File]::ReadAllText($prepared.ContextPath)
$receipt=$receiptJson | ConvertFrom-Json
$receipt.Projects[0].Mta.MtaOrigin | Add-Member NoteProperty Extra ('x'*300000)
Write-HarnessJson $prepared.ContextPath $receipt
$oversized=Query auditar_base
Assert ($oversized.Status -eq 'ERROR' -and $oversized.Error.Code -eq 'LIMIT_EXCEEDED' -and $null -eq $oversized.Provenance) ('Envelope sem teto de tamanho: '+$oversized.Status+' '+($oversized.Error | ConvertTo-Json -Compress))
[IO.File]::WriteAllText($prepared.ContextPath,$receiptJson)
$document=($catalogText -replace '^window\["apps"\]\s*=\s*','' -replace ';\s*$','') | ConvertFrom-Json
$incident=$document[0].rulesets[0].violations.'hibernate4-00039'.incidents[0]
$incident.uri='file:///C:/origem/.harness/runs/app/mta_2026-09-30_07-57-02-0300__bbbbbbbbbbbb/input/'+('classe'*23)+'.java'
function Save-QueryCatalog {
    [IO.File]::WriteAllText($catalog,('window["apps"] = '+(ConvertTo-Json -InputObject @($document) -Depth 30 -Compress)+';'))
    $receipt=$receiptJson | ConvertFrom-Json; $receipt.Projects[0].Mta.CatalogSha256=(Get-FileHash $catalog).Hash
    Write-HarnessJson $prepared.ContextPath $receipt
}
Save-QueryCatalog
$long=Query obter_issue @{Id=$issueId;Incident=1;MaxTextChars=128}
Assert ($long.Status -eq 'OK' -and $long.Data.Incidents[0].Location.RelativePath.Length -eq 128) ('Localizacao nao limitada: '+($long | ConvertTo-Json -Depth 8 -Compress))
Assert (@($long.Data.Incidents[0].TruncatedFields | Where-Object Field -eq 'Location.RelativePath').Count -eq 1) 'Corte de localizacao nao declarado.'
$incident.lineNumber=[pscustomobject]@{unexpected=('x'*3000)}; Save-QueryCatalog
Assert ((Query obter_issue @{Id=$issueId;Incident=1}).Error.Code -eq 'UNSUPPORTED_FORMAT') 'Linha nao numerica aceita.'
[IO.File]::WriteAllText($catalog,$catalogText); [IO.File]::WriteAllText($prepared.ContextPath,$receiptJson)
Write-Host 'PASS: localizacao lexical, UNC sem I/O, teto JSON, limites de texto e linha numerica.'
