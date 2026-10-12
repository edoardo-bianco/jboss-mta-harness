#requires -Version 5.1
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Test-IssueQueries.ps1')
$receiptJson=[IO.File]::ReadAllText($prepared.ContextPath)
foreach ($purpose in @('issue-prioritization','application-remediation','desconhecido')) {
    $data=$receiptJson | ConvertFrom-Json; $data.Purpose=$purpose
    Write-HarnessJson $prepared.ContextPath $data
    Assert ((Query auditar_base).Error.Code -eq 'UNSUPPORTED_CONTEXT') 'Contexto legado/desconhecido aceito.'
}
[IO.File]::WriteAllText($prepared.ContextPath,$receiptJson)
Assert ((Query auditar_base @{Category='mandatory'}).Error.Code -eq 'INVALID_INPUT') 'Filtro ignorado na auditoria.'
Assert ((Query obter_issue @{Id=$issueId;Incident=139}).Error.Code -eq 'INCIDENT_NOT_FOUND') 'Ordinal fora do fim aceito.'
$beyond=Query obter_issue @{Id=$issueId;Page=15}
Assert ($beyond.Status -eq 'OK' -and $beyond.Paging.Returned -eq 0 -and -not $beyond.Paging.HasMore) 'Pagina vazia virou erro.'
$secondSource=Join-Path $area 'segundo projeto'; $null=[IO.Directory]::CreateDirectory($secondSource)
Set-Content (Join-Path $secondSource 'pom.xml') '<project><artifactId>segundo-servico</artifactId></project>'
$secondProject=[pscustomobject]@{name='segundo';label='Segundo';path=$secondSource}
$secondPaths=Initialize-HarnessProjectStorage $fixture (Join-Path $secondSource 'pom.xml')
Publish-HarnessProjectFiles $secondPaths @{'projeto.json'=(@{pom=$secondPaths.Pom;mta=@{diretorio=$run}} | ConvertTo-Json)}
$null=Update-HarnessProjectDocuments $secondPaths (Read-HarnessProjectMta $secondPaths)
$multiContext=[pscustomobject]@{Root=$fixture;Active=$project;Projects=@($project,$secondProject)}
$multi=New-HarnessPrioritizationContext $multiContext -Mode Recreate -Percentage 100 -Category mandatory
Assert ((Invoke-HarnessIssueQuery -Root $fixture -ContextPath $multi.ContextPath -Action listar_issues).Error.Code -eq 'INPUT_REQUIRED') 'Multiprojeto escolheu Source automaticamente.'
$second=Invoke-HarnessIssueQuery -Root $fixture -ContextPath $multi.ContextPath -Source $secondSource -Action obter_issue -Id $issueId
Assert ($second.Status -eq 'OK' -and $second.Data.Issue.Source -eq $secondSource -and -not $second.Data.Incidents[0].Location.SourceCandidate) 'ID compartilhado ou URI de outro Source misturou projetos.'
[IO.File]::WriteAllText($catalog,'window["apps"] = executarCodigo();')
Assert ((Query auditar_base).Error.Code -eq 'UNSUPPORTED_FORMAT') 'Catalogo nao JSON aceito/executado.'
[IO.File]::WriteAllText($catalog,$catalogText)
# A data pode trocar o candidato sem alterar os bytes de nenhum arquivo.
$alternate=Join-Path $run 'outro-relatorio'
$null=[IO.Directory]::CreateDirectory($alternate)
$firstReport=Join-Path $run 'output/static-report/index.html'
$secondReport=Join-Path $alternate 'index.html'
[IO.File]::WriteAllText($secondReport,'Outro HTML')
[IO.File]::WriteAllText((Join-Path $alternate 'output.js'),$catalogText.Replace('Ocorrencia','Outra origem'))
[IO.File]::SetLastWriteTimeUtc($firstReport,[datetime]'2026-01-02T00:00:00Z')
[IO.File]::SetLastWriteTimeUtc($secondReport,[datetime]'2026-01-01T00:00:00Z')
$first=Query obter_issue @{Id=$issueId;Page=1}
Assert ($first.Status -eq 'OK' -and $first.Provenance.ReportPath -eq $firstReport) 'Fixture deve selecionar primeiro relatorio.'
[IO.File]::SetLastWriteTimeUtc($secondReport,[datetime]'2026-01-03T00:00:00Z')
Assert ((Query obter_issue @{Id=$issueId;Page=2;ExpectedBasisSha256=$first.Provenance.BasisSha256}).Error.Code -eq 'BASE_CHANGED') 'Troca somente de data misturou paginas de origens diferentes.'
Assert ((Query obter_issue @{Id=$issueId;Page=2}).Provenance.ReportPath -eq $secondReport) 'Nova consulta deve adotar a selecao corrente.'
$denied=& (Get-Module HarnessIssueQuery) {
    param($rootPath,$contextPath,$deniedPath)
    function Get-FileHash {
        param($LiteralPath,$Algorithm)
        if ($LiteralPath -eq $deniedPath) { throw (New-Object UnauthorizedAccessException 'Acesso negado sintetico.') }
        Microsoft.PowerShell.Utility\Get-FileHash -LiteralPath $LiteralPath -Algorithm $Algorithm
    }
    Invoke-HarnessIssueQuery -Root $rootPath -ContextPath $contextPath -Action auditar_base
} $fixture $prepared.ContextPath (Join-Path $alternate 'output.js')
Assert ($denied.Error.Code -eq 'ACCESS_DENIED') 'Falha de leitura nao pode selecionar silenciosamente outro candidato.'
$projectModule=Get-Module HarnessProject
$originalStamp=& $projectModule { ${function:Get-ProjectMtaStamp} }
try {
    & $projectModule {
        param($deniedPath)
        $script:deniedReport=$deniedPath
        function script:Get-ProjectMtaStamp {
            param($Entry,$Catalog)
            if ($Entry -eq $script:deniedReport) { throw (New-Object UnauthorizedAccessException 'Metadados indisponiveis.') }
            $entryInfo=Get-Item -LiteralPath $Entry; $catalogInfo=Get-Item -LiteralPath $Catalog
            @($entryInfo.Length,$entryInfo.LastWriteTimeUtc.Ticks,$catalogInfo.Length,$catalogInfo.LastWriteTimeUtc.Ticks) -join ':'
        }
    } $secondReport
    Assert ((Query auditar_base).Error.Code -eq 'ACCESS_DENIED') 'Falha de metadados fora do leitor nao pode selecionar outro candidato.'
} finally {
    & $projectModule { param($original) Set-Item Function:script:Get-ProjectMtaStamp $original; Remove-Variable deniedReport -Scope Script } $originalStamp
}
$configJson=[IO.File]::ReadAllText($paths.ConfigPath)
try {
    $configuration=$configJson | ConvertFrom-Json; $configuration.mta.diretorio=Join-Path $area 'origem-ausente'
    Write-HarnessJson $paths.ConfigPath $configuration
    Assert ((Query auditar_base).Error.Code -eq 'NOT_FOUND') 'Origem ausente deve informar indisponibilidade, nao formato invalido.'
} finally { [IO.File]::WriteAllText($paths.ConfigPath,$configJson) }
$temporary=Join-Path $paths.TemporaryPath 'publicacao'
$null=[IO.Directory]::CreateDirectory($temporary)
[IO.File]::WriteAllText((Join-Path $temporary 'recuperacao.json'),'[]')
$before=Inventory $area
Assert ((Query auditar_base).Error.Code -eq 'BASE_BUSY') 'Consulta recuperou publicacao interrompida.'
Assert ((Inventory $area) -ceq $before) 'Consulta alterou temporarios.'
Write-Host 'PASS: recusa legado, limites, multiprojeto, formato e publicacao pendente sem escrita.'
