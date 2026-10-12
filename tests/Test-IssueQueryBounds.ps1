#requires -Version 5.1
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Test-IssueQueries.ps1')
$module=Get-Module HarnessIssueQuery
$unc=& $module {
    function Get-Item { throw 'IO_NAO_DEVERIA_SER_CHAMADO' }
    try { $null=Read-QueryFile '\\host\share\arquivo.json' @{} } catch { Get-QueryError $_ }
}
Assert ($unc.Code -eq 'INVALID_CONTEXT' -and $unc.Message -notmatch 'IO_NAO') 'UNC chegou ao filesystem.'
$lexical=& $module {
    function Resolve-HarnessPath { throw 'ORIGEM_NAO_DEVERIA_SER_ACESSADA' }
    Get-IncidentLocation 'src/Classe.java' ([pscustomobject]@{Source='C:/colega/projeto'}) -LexicalPaths
}
Assert ($lexical.SourceCandidate -eq 'C:\colega\projeto\src\Classe.java') 'Localizacao depende de acesso ao arquivo.'
$document=($catalogText -replace '^window\["apps"\]\s*=\s*','' -replace ';\s*$','') | ConvertFrom-Json
function Save-QueryCatalog { [IO.File]::WriteAllText($catalog,('window["apps"] = '+(ConvertTo-Json -InputObject @($document) -Depth 30 -Compress)+';')) }
$huge='x'*300000
$document[0].rulesets[0].violations | Add-Member NoteProperty $huge ([pscustomobject]@{description='Grande';category='mandatory';incidents=@()})
Save-QueryCatalog
$oversized=Query listar_issues
Assert ($oversized.Status -eq 'ERROR' -and $oversized.Error.Code -eq 'LIMIT_EXCEEDED' -and $null -eq $oversized.Provenance) 'Envelope sem teto de tamanho.'
$document[0].rulesets[0].violations.PSObject.Properties.Remove($huge)
$incident=$document[0].rulesets[0].violations.'hibernate4-00039'.incidents[0]
$incident.uri='file:///C:/origem-alheia/src/Classe.java'; Save-QueryCatalog
$foreign=Query obter_issue @{Id=$issueId;Incident=1}
Assert ($foreign.Status -eq 'OK' -and -not $foreign.Data.Incidents[0].Location.SourceCandidate) 'URI alheia nao pode inventar mapeamento local.'
$incident.uri='src/'+('classe'*23)+'.java'; Save-QueryCatalog
$long=Query obter_issue @{Id=$issueId;Incident=1;MaxTextChars=128}
Assert ($long.Status -eq 'OK' -and $long.Data.Incidents[0].Location.RelativePath.Length -eq 128) 'Localizacao nao limitada.'
Assert (@($long.Data.Incidents[0].TruncatedFields | Where-Object Field -eq 'Location.RelativePath').Count -eq 1) 'Corte nao declarado.'
$incident.uri='src/%2e%2e/segredo.java'; Save-QueryCatalog
Assert (-not (Query obter_issue @{Id=$issueId;Incident=1}).Data.Incidents[0].Location.SourceCandidate) 'Travessia gerou caminho local.'
$incident.lineNumber=[pscustomobject]@{unexpected=('x'*3000)}; Save-QueryCatalog
Assert ((Query obter_issue @{Id=$issueId;Incident=1}).Error.Code -eq 'UNSUPPORTED_FORMAT') 'Linha nao numerica aceita.'
[IO.File]::WriteAllText($catalog,$catalogText)
Write-Host 'PASS: localizacao lexical, URI alheia/travessia, UNC sem IO, teto JSON e limites de texto.'
