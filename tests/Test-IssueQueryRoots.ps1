#requires -Version 5.1
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Test-IssueQueries.ps1')
$parameters=@{Root=$fixture;ContextPath=$prepared.ContextPath;Action='obter_issue';Id=$issueId}
$before=Inventory $area
Assert ((Invoke-HarnessIssueQuery @parameters -AllowedRoots @($area)).Status -eq 'OK') 'Consulta permitida recusada.'
foreach ($roots in @(@($source),@($fixture,$source),@($fixture,$run),@($area+'-vizinho'))) {
    $blocked=Invoke-HarnessIssueQuery @parameters -AllowedRoots $roots
    Assert ($blocked.Error.Code -eq 'ACCESS_DENIED') ('Raizes insuficientes permitiram leitura: '+($roots -join ','))
}
Assert ((Invoke-HarnessIssueQuery @parameters -AllowedRoots @()).Error.Code -eq 'INVALID_INPUT') 'Lista vazia desativou restricao.'
Assert ((Inventory $area) -ceq $before) 'Restricao escreveu arquivos.'
$configJson=[IO.File]::ReadAllText($paths.ConfigPath)
try {
    $config=$configJson | ConvertFrom-Json; $config.mta.diretorio=$area+'-externo'
    Write-HarnessJson $paths.ConfigPath $config
    Assert ((Invoke-HarnessIssueQuery @parameters -AllowedRoots @($area)).Error.Code -eq 'ACCESS_DENIED') 'Origem local configurada escapou da restricao.'
} finally { [IO.File]::WriteAllText($paths.ConfigPath,$configJson) }
$receiptJson=[IO.File]::ReadAllText($prepared.ContextPath)
try {
    $data=$receiptJson | ConvertFrom-Json
    $other=$data.Projects[0] | ConvertTo-Json -Depth 30 | ConvertFrom-Json
    $other.Source=$area+'-outro-projeto'; $other.Project='outro'
    $data.Projects+=@($other); Write-HarnessJson $prepared.ContextPath $data
    Assert ((Invoke-HarnessIssueQuery @parameters -Source $source -AllowedRoots @($area)).Status -eq 'OK') 'Projeto nao selecionado bloqueou leitura permitida.'
    Assert ((Invoke-HarnessIssueQuery @parameters -Source $other.Source -AllowedRoots @($area)).Error.Code -eq 'ACCESS_DENIED') 'Projeto externo selecionado foi lido.'
} finally { [IO.File]::WriteAllText($prepared.ContextPath,$receiptJson) }
Assert ((Invoke-HarnessIssueQuery @parameters).Status -eq 'OK') 'Raizes vazaram para proxima chamada.'
Write-Host 'PASS: limites de contexto, Source/POM, MTA e isolamento entre chamadas.'
