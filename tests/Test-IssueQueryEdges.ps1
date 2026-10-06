#requires -Version 5.1
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Test-IssueQueries.ps1')
$receiptJson=[IO.File]::ReadAllText($prepared.ContextPath)
foreach ($version in @(2,3)) {
    $receipt=$receiptJson | ConvertFrom-Json; $receipt.SchemaVersion=$version; $receipt.PSObject.Properties.Remove('Category')
    Write-HarnessJson $prepared.ContextPath $receipt
    $result=Query listar_issues @{Category='optional'}
    Assert ($result.Status -eq 'OK' -and $result.Data.Items[0].Availability -eq 'OUTSIDE_CATEGORY') 'Recibo legado perdeu categoria mandatory.'
}
$receipt=$receiptJson | ConvertFrom-Json; $receipt.SchemaVersion=99
Write-HarnessJson $prepared.ContextPath $receipt
Assert ((Query auditar_base).Error.Code -eq 'UNSUPPORTED_CONTEXT') 'Versao desconhecida aceita.'
[IO.File]::WriteAllText($prepared.ContextPath,$receiptJson)
Assert ((Query auditar_base @{Category='mandatory'}).Error.Code -eq 'INVALID_INPUT') 'Filtro ignorado silenciosamente na auditoria.'
Assert ((Query obter_issue @{Id=$issueId;Incident=139}).Error.Code -eq 'INCIDENT_NOT_FOUND') 'Ordinal fora do fim aceito.'
$beyond=Query obter_issue @{Id=$issueId;Page=15}
Assert ($beyond.Status -eq 'OK' -and $beyond.Paging.Returned -eq 0 -and -not $beyond.Paging.HasMore) 'Pagina vazia confundida com erro.'

$secondSource=Join-Path $area 'segundo projeto'; $null=[IO.Directory]::CreateDirectory($secondSource)
Set-Content (Join-Path $secondSource 'pom.xml') '<project><artifactId>segundo-servico</artifactId></project>'
$secondProject=[pscustomobject]@{name='segundo';label='Segundo';path=$secondSource}
$secondPaths=Initialize-HarnessMigration $fixture $secondProject
$secondText=[IO.File]::ReadAllText($secondPaths.MigrationPath)
[IO.File]::WriteAllText($secondPaths.MigrationPath,$secondText.Replace('<!-- mta:fim -->',$rows+"`n<!-- mta:fim -->"))
$multiContext=[pscustomobject]@{Root=$fixture;Active=$project;Projects=@($project,$secondProject);ConfigPath=$null;WorkspacePath=$null}
$multi=New-HarnessPrioritizationContext $multiContext -Mode Recreate -Percentage 100 -Category mandatory
$ambiguous=Invoke-HarnessIssueQuery -Root $fixture -ContextPath $multi.ContextPath -Action listar_issues
Assert ($ambiguous.Error.Code -eq 'INPUT_REQUIRED') 'Multi-projeto elegeu Source automaticamente.'
$second=Invoke-HarnessIssueQuery -Root $fixture -ContextPath $multi.ContextPath -Source $secondSource -Action obter_issue -Id $issueId
Assert ($second.Status -eq 'OK' -and $second.Data.Issue.Source -eq $secondSource -and $second.Data.Incidents[0].Location.SourceCandidate.StartsWith($secondSource)) 'ID compartilhado misturou projetos.'

# Formato nao suportado, mesmo com hash do arquivo atualizado no recibo.
$receipt=$receiptJson | ConvertFrom-Json
[IO.File]::WriteAllText($catalog,'window["apps"] = executarCodigo();')
$receipt.Projects[0].Mta.CatalogSha256=(Get-FileHash $catalog).Hash
Write-HarnessJson $prepared.ContextPath $receipt
Assert ((Query auditar_base).Error.Code -eq 'UNSUPPORTED_FORMAT') 'Catalogo nao JSON aceito/executado.'
[IO.File]::WriteAllText($catalog,$catalogText); [IO.File]::WriteAllText($prepared.ContextPath,$receiptJson)

$module=Get-Module HarnessIssueQuery
$denied=& $module { Get-QueryError ([Management.Automation.ErrorRecord]::new([UnauthorizedAccessException]::new('Negado'),'Denied','PermissionDenied',$null)) }
Assert ($denied.Code -eq 'ACCESS_DENIED') 'Acesso negado perdeu classificacao.'
$changed=& $module { param($path)
    try { Assert-QueryFiles @{$path=('0'*64)} } catch { Get-QueryError $_ }
} $catalog
Assert ($changed.Code -eq 'BASE_CHANGED') 'Verificacao final de hashes nao detectou mudanca.'
Write-Host 'PASS: versoes legadas, limites, multi-projeto, formato e erros de leitura.'
