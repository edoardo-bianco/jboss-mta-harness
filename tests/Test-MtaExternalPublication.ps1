#requires -Version 5.1
$ErrorActionPreference='Stop'; Set-StrictMode -Version Latest
$root=Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $root 'scripts/HarnessProject.psm1') -DisableNameChecking
Import-Module (Join-Path $root 'scripts/HarnessMtaLocation.psm1') -DisableNameChecking
. (Join-Path $root 'scripts/HarnessMtaExternalPublication.ps1')
function Assert($value,[string]$message) { if (-not $value) { throw $message } }
function Write-Report($folder,[string]$date) {
    $null=[IO.Directory]::CreateDirectory($folder)
    [IO.File]::WriteAllText((Join-Path $folder 'index.html'),'MTA sintetico '+$date)
    [IO.File]::WriteAllText((Join-Path $folder 'output.js'),('window["apps"] = [{"artifactId":"api","generatedAt":"'+$date+'","rulesets":[]}];'))
    Join-Path $folder 'index.html'
}
$area=Join-Path $root ('.harness/tests/mta-publicacao-'+[guid]::NewGuid().ToString('N').Substring(0,8))
$script:failureMode=''
$script:boundaryReached=$false
$script:concurrentText=$null
$script:obstructPath=$null
# Injetar somente a falha do armazenamento local; movimento e leitura MTA sao reais.
function Publish-HarnessProjectFiles {
    param($Project,$Files,$Expected)
    if ($script:failureMode) {
        $script:boundaryReached=$true
        if ($script:failureMode -eq 'concorrente') {
            $changed=ConvertFrom-Json ([IO.File]::ReadAllText($Project.ConfigPath))
            $changed.mta.diretorio=Join-Path $area 'escolha-humana'
            $script:concurrentText=$changed | ConvertTo-Json
            [IO.File]::WriteAllText($Project.ConfigPath,$script:concurrentText)
            # O publicador real deve detectar a edicao; nao simular sua protecao.
            HarnessProject\Publish-HarnessProjectFiles $Project $Files $Expected
            throw 'Publicador aceitou indevidamente a edicao concorrente.'
        }
        if ($script:failureMode -eq 'retirada-obstruida') {
            $null=[IO.Directory]::CreateDirectory($script:obstructPath)
            [IO.File]::WriteAllText((Join-Path $script:obstructPath 'sentinela.txt'),'contribuicao concorrente')
        }
        throw 'Falha de armazenamento local injetada.'
    }
    HarnessProject\Publish-HarnessProjectFiles $Project $Files $Expected
}
foreach ($mode in @('armazenamento','concorrente','retirada-obstruida','sucesso')) {
    $case=Join-Path $area $mode
    $source=Join-Path $case 'source'
    $null=[IO.Directory]::CreateDirectory($source)
    $pom=Join-Path $source 'pom.xml'
    [IO.File]::WriteAllText($pom,'<project><artifactId>api</artifactId></project>')
    $project=Initialize-HarnessProjectStorage (Join-Path $case 'workspace') $pom
    $external=Join-Path $case 'externo'
    $location=[pscustomobject]@{Root=$external;Directory=(Join-Path $external 'source')}
    $oldReport=Write-Report (Join-Path $location.Directory 'anterior/static-report') '2026-01-01T00:00:00Z'
    $oldBytes=[IO.File]::ReadAllText($oldReport)
    $previous=[IO.File]::ReadAllText($project.ConfigPath)
    $association=Get-HarnessMtaExternalAssociationText $project $location $previous
    $stage=New-MtaExternalStage $location
    $null=Write-Report (Join-Path $stage.Output 'static-report') '2026-10-21T00:00:00Z'
    $mta=Read-HarnessMtaDirectory $project $stage.Output
    $script:failureMode=if ($mode -eq 'sucesso') { '' } else { $mode }
    $script:obstructPath=$stage.Output
    $script:boundaryReached=$false; $failure=$null; $published=$null
    try { $published=Publish-MtaExternalReport $project $location $stage $mta $previous $association }
    catch { $failure=$_.Exception.Message }
    if ($mode -eq 'sucesso') {
        Assert (-not $failure -and (Test-Path -LiteralPath $published -PathType Leaf)) 'Sucesso deve publicar o relatorio completo.'
        Assert ([IO.File]::ReadAllText($project.ConfigPath) -ceq $association) 'Sucesso deve associar a origem externa.'
        Assert ((Read-HarnessProjectMta $project).ReportPath -eq $published) 'Leitor deve selecionar o sucesso publicado.'
        # Associacao ja estabelecida tambem aceita uma nova rodada.
        Remove-MtaExternalStage $stage
        $stage=New-MtaExternalStage $location
        $null=Write-Report (Join-Path $stage.Output 'static-report') '2026-10-22T00:00:00Z'
        $mta=Read-HarnessMtaDirectory $project $stage.Output
        $next=Publish-MtaExternalReport $project $location $stage $mta $association $association
        Assert ((Read-HarnessProjectMta $project).ReportPath -eq $next -and (Test-Path -LiteralPath $published)) 'Nova rodada na mesma associacao deve preservar a anterior.'
    } elseif ($mode -eq 'retirada-obstruida') {
        # Dupla falha de filesystem exige intervencao manual; nao promete atomicidade.
        Assert ($script:boundaryReached -and $failure -match 'Falha ao associar MTA:.*armazenamento local injetada.*Falha ao retirar rodada externa') 'Relatar separadamente a falha de associacao e a falha de retirada.'
        $stranded=@(Get-ChildItem -LiteralPath $location.Directory -Directory | Where-Object Name -NE 'anterior')
        Assert ($stranded.Count -eq 1 -and $failure.Contains($stranded[0].FullName)) 'Erro deve identificar a rodada que requer intervencao manual.'
        Assert ($failure.Contains('Preserve os arquivos') -and $failure.Contains('antes de atualizar o indice')) 'Orientar preservacao e conferencia antes de reutilizar a origem externa.'
        Assert ([IO.File]::ReadAllText($project.ConfigPath) -ceq $previous) 'Dupla falha nao pode regravar a associacao anterior.'
        Assert ([IO.File]::ReadAllText((Join-Path $stage.Output 'sentinela.txt')) -ceq 'contribuicao concorrente') 'Retirada impossivel nao pode apagar a obstrucao concorrente.'
        $strandedReport=Join-Path $stranded[0].FullName 'static-report/index.html'
        Assert ([IO.File]::ReadAllText($strandedReport) -ceq 'MTA sintetico 2026-10-21T00:00:00Z') 'Retirada impossivel deve preservar a rodada para conferencia manual.'
    } else {
        Assert ($script:boundaryReached -and $failure) 'Falha deve ocorrer na publicacao da associacao, apos preparar a rodada.'
        if ($mode -eq 'armazenamento') {
            Assert ($failure -match 'armazenamento local injetada') 'Preservar o diagnostico da falha local.'
            Assert ([IO.File]::ReadAllText($project.ConfigPath) -ceq $previous) 'Falha deve preservar a associacao anterior.'
        } else {
            Assert ($failure -match 'Documento alterado desde a leitura') 'Publicador real deve detectar a edicao concorrente.'
            Assert ([IO.File]::ReadAllText($project.ConfigPath) -ceq $script:concurrentText) 'Falha nao pode desfazer a escolha humana concorrente.'
        }
        Assert ((Read-HarnessMtaDirectory $project $location.Directory).ReportPath -eq $oldReport) 'Rodada cuja associacao falhou nao pode permanecer elegivel no MTA externo.'
        Assert (@(Get-ChildItem -LiteralPath $location.Directory -Directory).Count -eq 1) 'Falha nao deve deixar rodada datada publicada.'
    }
    Assert ([IO.File]::ReadAllText($oldReport) -ceq $oldBytes) 'Publicacao ou rollback nao altera o diagnostico anterior.'
    Remove-MtaExternalStage $stage
    if ($mode -eq 'retirada-obstruida') {
        Assert (Test-Path -LiteralPath (Join-Path $stage.Output 'sentinela.txt') -PathType Leaf) 'Limpeza do chamador deve preservar stage quando a retirada falhou.'
        Assert ([IO.File]::ReadAllText((Join-Path $stage.Output 'sentinela.txt')) -ceq 'contribuicao concorrente') 'Limpeza nao pode alterar a sentinela preservada para intervencao manual.'
        Assert (Test-Path -LiteralPath $strandedReport -PathType Leaf) 'Limpeza do chamador nao pode apagar a rodada cuja retirada falhou.'
    } else {
        Assert (-not (Test-Path -LiteralPath $stage.Path)) 'Limpeza normal deve remover o stage apos sucesso ou retirada concluida.'
    }
}
'PASS: publicacao MTA externa desfaz rodada quando associacao falha, preserva concorrencia, explicita retirada impossivel e publica sucessos.'
