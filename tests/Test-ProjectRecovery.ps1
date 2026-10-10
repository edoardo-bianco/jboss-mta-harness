#requires -Version 5.1
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$root=Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $root 'scripts/HarnessProject.psm1') -Force -DisableNameChecking
function Assert($value,[string]$message) { if (-not $value) { throw $message } }
$area=Join-Path $root ('.harness/tests/recovery-'+[guid]::NewGuid().ToString('N').Substring(0,8))
$app=Join-Path $area 'app'; $null=[IO.Directory]::CreateDirectory($app)
$pom=Join-Path $app 'pom.xml'
[IO.File]::WriteAllText($pom,'<project><artifactId>servico</artifactId></project>')
$project=Initialize-HarnessProjectStorage $area $pom
$old=@{'atual/planejamento/plano.md'='plano anterior';'atual/planejamento/tarefas.md'='tarefas anteriores'}
$child=Join-Path $area 'interromper.ps1'
[IO.File]::WriteAllText($child,@'
param($ModulePath,$Workspace,$Pom,$Mode)
$ErrorActionPreference='Stop'
Import-Module $ModulePath -Force -DisableNameChecking
$project=Get-HarnessProjectStorage $Workspace $Pom
& (Get-Module HarnessProject) {
    param($Mode)
    $script:mode=$Mode; $script:original=${function:Write-ProjectPublishedFile}; $script:count=0
    if ($Mode -eq 'preparing') {
        function script:Write-ProjectRecoveryInstruction {
            param($Temporary,$Entries)
            [IO.File]::WriteAllText((Join-Path $Temporary 'recuperacao.tmp'),'[{')
            [Environment]::Exit(73)
        }
    }
    function script:Write-ProjectPublishedFile {
        param($Source,$Destination)
        & $script:original $Source $Destination
        $script:count++
        if ($script:mode -eq 'forward' -and $script:count -eq 1) { [Environment]::Exit(71) }
        if ($script:mode -eq 'rollback' -and $script:count -eq 1) { throw 'iniciar rollback' }
        if ($script:mode -eq 'rollback' -and $script:count -eq 2) { [Environment]::Exit(72) }
    }
} $Mode
Publish-HarnessProjectFiles $project @{'atual/planejamento/plano.md'='plano novo';'atual/planejamento/tarefas.md'='tarefas novas'}
'@,(New-Object Text.UTF8Encoding($false)))
foreach ($mode in @('preparing','forward','rollback')) {
    Publish-HarnessProjectFiles $project $old
    & powershell.exe -NoProfile -File $child (Join-Path $root 'scripts/HarnessProject.psm1') $area $pom $mode
    Assert ($LASTEXITCODE -in @(71,72,73)) ('Processo deve terminar abruptamente em '+$mode)
    $content=Read-HarnessProjectFiles $project @('atual/planejamento/plano.md','atual/planejamento/tarefas.md')
    Assert ($content['atual/planejamento/plano.md'] -ceq 'plano anterior' -and $content['atual/planejamento/tarefas.md'] -ceq 'tarefas anteriores') ('Retomada deve recuperar conjunto depois de '+$mode)
    Assert (-not (Test-Path -LiteralPath $project.TemporaryPath)) 'Recuperacao concluida deve retirar temporarios.'
}
# Interromper a limpeza depois de remover parte do material. O journal precisa
# deixar de existir antes da limpeza recursiva; reabrir nao deve tentar rollback.
Publish-HarnessProjectFiles $project $old
$module=Get-Module HarnessProject
& $module {
    $script:cleaner=${function:Clear-ProjectPublicationFiles}
    function script:Clear-ProjectPublicationFiles {
        param($Project)
        $journal=Join-Path $Project.TemporaryPath 'publicacao/recuperacao.json'
        if (Test-Path -LiteralPath $journal) { throw 'Journal ainda existe durante limpeza.' }
        $before=Join-Path $Project.TemporaryPath 'publicacao/antes/atual/planejamento/plano.md'
        if (Test-Path -LiteralPath $before) { [IO.File]::Delete($before) }
        throw 'limpeza interrompida'
    }
}
try { Publish-HarnessProjectFiles $project @{'atual/planejamento/plano.md'='plano publicado';'atual/planejamento/tarefas.md'='tarefas publicadas'} } catch { }
& $module { ${function:Clear-ProjectPublicationFiles}=$script:cleaner }
$content=Read-HarnessProjectFiles $project @('atual/planejamento/plano.md','atual/planejamento/tarefas.md')
Assert ($content['atual/planejamento/plano.md'] -ceq 'plano publicado' -and $content['atual/planejamento/tarefas.md'] -ceq 'tarefas publicadas') 'Limpeza interrompida nao pode desfazer publicacao completa.'
Assert (-not (Test-Path -LiteralPath $project.TemporaryPath)) 'Reabertura deve terminar limpeza.'
'PASS: morte do processo no preparo, na escrita, na recuperacao e limpeza interrompida.'
