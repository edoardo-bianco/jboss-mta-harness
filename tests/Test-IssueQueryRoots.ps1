#requires -Version 5.1
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Test-IssueQueries.ps1')
$parameters=@{Root=$fixture;ContextPath=$prepared.ContextPath;Action='obter_issue';Id=$issueId}
$before=Inventory $area
$allowed=Invoke-HarnessIssueQuery @parameters -AllowedRoots @($area)
Assert ($allowed.Status -eq 'OK') 'Consulta permitida foi recusada.'
$blocked=Invoke-HarnessIssueQuery @parameters -AllowedRoots @($source)
Assert ($blocked.Error.Code -eq 'ACCESS_DENIED') 'Contexto fora das raizes foi lido.'
$blocked=Invoke-HarnessIssueQuery @parameters -AllowedRoots @($fixture,$source)
Assert ($blocked.Error.Code -eq 'ACCESS_DENIED') 'MTA externo do recibo escapou da restricao.'
$blocked=Invoke-HarnessIssueQuery @parameters -AllowedRoots @($fixture,$run)
Assert ($blocked.Error.Code -eq 'ACCESS_DENIED') 'Source/POM externo foi inspecionado.'
$empty=Invoke-HarnessIssueQuery @parameters -AllowedRoots @()
Assert ($empty.Error.Code -eq 'INVALID_INPUT') 'Lista vazia desativou restricao.'
Assert ((Inventory $area) -ceq $before) 'Restricao de leitura escreveu arquivos.'
$prefix=Invoke-HarnessIssueQuery @parameters -AllowedRoots @($area+'-vizinho')
Assert ($prefix.Error.Code -eq 'ACCESS_DENIED') 'Prefixo semelhante foi aceito como raiz.'
$originalRegister=[IO.File]::ReadAllText($paths.MigrationPath)
try {
    [IO.File]::WriteAllText($paths.MigrationPath,$originalRegister.Replace('Source: '+$source,'Source: '+$area+'-externo'))
    $internalSource=Invoke-HarnessIssueQuery @parameters -AllowedRoots @($area)
    Assert ($internalSource.Error.Code -eq 'ACCESS_DENIED') 'Source interno do registro escapou da restricao.'
} finally { [IO.File]::WriteAllText($paths.MigrationPath,$originalRegister) }
$unrestricted=Invoke-HarnessIssueQuery @parameters
Assert ($unrestricted.Status -eq 'OK') 'Estado de raizes vazou para chamada CLI seguinte.'
$receiptJson=[IO.File]::ReadAllText($prepared.ContextPath)
try {
    $receipt=$receiptJson | ConvertFrom-Json
    $other=$receipt.Projects[0] | ConvertTo-Json -Depth 30 | ConvertFrom-Json
    $other.Source=$area+'-outro-projeto'
    $receipt.Projects+=@($other)
    Write-HarnessJson $prepared.ContextPath $receipt
    $selected=Invoke-HarnessIssueQuery @parameters -Source $source -AllowedRoots @($area)
    Assert ($selected.Status -eq 'OK') 'Projeto fora do escopo bloqueou selecao permitida.'
    $selected=Invoke-HarnessIssueQuery @parameters -Source $other.Source -AllowedRoots @($area)
    Assert ($selected.Error.Code -eq 'ACCESS_DENIED') 'Projeto externo selecionado nao foi recusado.'
} finally { [IO.File]::WriteAllText($prepared.ContextPath,$receiptJson) }
Write-Host 'PASS: raizes explicitas, contexto, Source, origem interna, lista vazia e isolamento entre chamadas.'
