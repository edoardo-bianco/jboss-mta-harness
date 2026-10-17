#requires -Version 5.1
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'SprintCurrentFixture.ps1')
$f=New-SprintFixture @('a','b')
$current=New-HarnessSprintContext $f.Context -All -MasterProject a
$module=Get-Module HarnessSprintPlanning
$register=$f.Projects[0].MigrationPath
$original=[IO.File]::ReadAllText($register)
$contextBefore=[IO.File]::ReadAllText($current.ContextPath)
try {
    & $module {
        param($registerPath)
        $script:mutationPath=$registerPath
        function script:Read-HarnessProjectFiles {
            param($Project,$Paths)
            $result=HarnessProject\Read-HarnessProjectFiles $Project $Paths
            if ($script:mutationPath -and 'migracao.md' -in $Paths -and $script:mutationPath -eq $Project.MigrationPath) {
                [IO.File]::AppendAllText($script:mutationPath,([Environment]::NewLine+'Edicao concorrente depois da leitura.'))
                $script:mutationPath=$null
            }
            $result
        }
    } $register
    $failure=$null
    try { $null=Complete-HarnessSprintPlan $f.Root $current.ContextPath } catch { $failure=$_.Exception.Message }
    Assert ($failure -like '*Entrada mudou durante a leitura*') ('Texto A protegido pelo hash B deveria ser recusado: '+$failure)
    Assert (-not (Test-Path $current.ValidationPath) -and [IO.File]::ReadAllText($current.ContextPath) -ceq $contextBefore) 'Leitura inconsistente publicou resultado/contexto.'
} finally {
    # The imported command may retain its function binding; disable the one-shot
    # mutation for the rest of this isolated PowerShell test process.
    & $module { $script:mutationPath=$null }
    [IO.File]::WriteAllText($register,$original)
}
# Outro processo segura a exclusividade comum depois de descobrir os cenarios.
$ready=Join-Path $f.Root 'barreira-pronta'; $release=Join-Path $f.Root 'barreira-liberar'
$job=Start-Job -ArgumentList $root,$f.Root,$ready,$release -ScriptBlock {
    param($repository,$fixture,$readyPath,$releasePath)
    $ErrorActionPreference='Stop'
    Import-Module (Join-Path $repository 'scripts/HarnessSprintPlanning.psm1') -DisableNameChecking
    & (Get-Module HarnessSprintPlanning) {
        param($fixture,$readyPath,$releasePath)
        $lease=Enter-SprintAccess $fixture
        try {
            $null=Get-HarnessSprintScenarios $fixture
            [IO.File]::WriteAllText($readyPath,'Pronto')
            $deadline=[datetime]::UtcNow.AddSeconds(40)
            while (-not (Test-Path $releasePath) -and [datetime]::UtcNow -lt $deadline) { Start-Sleep -Milliseconds 100 }
        } finally { $lease.ReleaseMutex(); $lease.Dispose() }
    } $fixture $readyPath $releasePath
}
try {
    $deadline=[datetime]::UtcNow.AddSeconds(25)
    while (-not (Test-Path $ready) -and [datetime]::UtcNow -lt $deadline) { Start-Sleep -Milliseconds 100 }
    Assert (Test-Path $ready) 'Processo concorrente nao alcançou barreira.'
    $before=Get-PlanningFixtureState $f
    Reject { New-HarnessSprintContext $f.Context -All -MasterProject b -Scenario outro } 'Outro mestre nao pode publicar durante descoberta.'
    Reject { Complete-HarnessSprintPlan $f.Root $current.ContextPath } 'Validacao deve compartilhar exclusividade de sprints.'
    Reject { Update-HarnessSprintIndex $f.Root } 'Indice nao pode publicar lista obsoleta durante outra operacao.'
    Assert ((Get-PlanningFixtureState $f) -ceq $before) 'Operacao concorrente alterou os documentos.'
} finally {
    [IO.File]::WriteAllText($release,'Liberar')
    $null=Wait-Job $job -Timeout 45
    Receive-Job $job -ErrorAction Stop
    Remove-Job $job -Force
}
$null=Complete-HarnessSprintPlan $f.Root $current.ContextPath
Assert (@(Get-HarnessSprintScenarios $f.Root).Count -eq 1) 'Barreira deixou mestre duplicado.'
Write-Host 'PASS: edicao externa detectada e exclusividade comum de cenarios/indices em processos distintos.'
