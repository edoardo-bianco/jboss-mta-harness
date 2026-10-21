. (Join-Path $PSScriptRoot 'PrioritizationFixture.ps1')
Import-Module (Join-Path $root 'scripts/Harness.psm1') -DisableNameChecking
Import-Module (Join-Path $root 'scripts/HarnessPlanning.psm1') -Force -DisableNameChecking
function New-PlanningFixture([int]$Count=2,[string[]]$Names=@('a')) {
    $fixture=New-Fixture $Count $Names
    Copy-Item -LiteralPath (Join-Path $root '.github/prompts/planejar-lotes.prompt.md') -Destination (Join-Path $fixture.Root '.github/prompts/planejar-lotes.prompt.md')
    Copy-Item -LiteralPath (Join-Path $root '.github/prompts/manter-migracao.prompt.md') -Destination (Join-Path $fixture.Root '.github/prompts/manter-migracao.prompt.md')
    foreach ($project in $fixture.Projects) {
        $text=[IO.File]::ReadAllText($project.MigrationPath).Replace('| A DEFINIR | NAO ANALISADA |','| ANALISAR AGORA | NAO ANALISADA |')
        [IO.File]::WriteAllText($project.MigrationPath,$text)
    }
    $fixture
}
function Set-ManualPlanningChoice($Project) {
    $text=[IO.File]::ReadAllText($Project.MigrationPath)
    $table=@('| ID | Issue | Categoria | Ocorrencias | Presenca | Decisao | Andamento | Observacao/referencia |','| --- | --- | --- | --- | --- | --- | --- | --- |',
        '| DEV-1 | Erro relatado | manual | - | MANUAL | ANALISAR AGORA | NAO ANALISADA | [Evidencia](<evidencias/observacao.md>) |') -join "`n"
    [IO.File]::WriteAllText($Project.MigrationPath,(Set-ProjectManagedBlock $text 'mta' $table))
}

function Install-PlanningCli($Fixture) {
    # A entrada publica exige aplicacoes fora da raiz do harness.
    for ($i=0;$i -lt $Fixture.Projects.Count;$i++) {
        $project=$Fixture.Projects[$i]
        $source=Join-Path ($Fixture.Root+'-applications') $project.Name
        $null=[IO.Directory]::CreateDirectory((Join-Path $source 'src'))
        Copy-Item -LiteralPath $project.Pom -Destination (Join-Path $source 'pom.xml')
        Copy-Item -LiteralPath (Join-Path $project.Source 'src/Exemplo.java') -Destination (Join-Path $source 'src/Exemplo.java')
        Publish-HarnessProjectFiles $project @{'projeto.json'=(@{pom=(Join-Path $source 'pom.xml');mta=@{diretorio=('mta-'+$project.Name)}}|ConvertTo-Json)}
        $Fixture.Projects[$i]=Get-HarnessProjectStorage $Fixture.Root (Join-Path $source 'pom.xml')
        $Fixture.Context.Projects[$i].path=$source
    }
    $models=Join-Path $Fixture.Root 'doc/modelos'
    $null=[IO.Directory]::CreateDirectory($models)
    Get-ChildItem -LiteralPath (Join-Path $root 'doc/modelos') -File | Copy-Item -Destination $models
    $scripts=Join-Path $Fixture.Root 'scripts'
    $null=[IO.Directory]::CreateDirectory($scripts)
    foreach ($file in Get-ChildItem -LiteralPath (Join-Path $root 'scripts') -File) {
        if ($file.Extension -in @('.ps1','.psm1')) { Copy-Item -LiteralPath $file.FullName -Destination $scripts }
    }
    $config=Get-Content -LiteralPath (Join-Path $root 'config/harness.example.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    $config.repositories=@(); $config.activeProject=$null
    $configPath=Join-Path $Fixture.Root 'config.json'; Write-HarnessJson $configPath $config
    $workspacePath=Join-Path $Fixture.Root 'projetos.code-workspace'
    Write-HarnessJson $workspacePath @{folders=@($Fixture.Projects | ForEach-Object {@{name=$_.Name;path=$_.Source}})}
    [pscustomobject]@{Scripts=$scripts;Config=$configPath;Workspace=$workspacePath}
}
function Invoke-PlanningCli($Cli,[string]$Entry,[hashtable]$Options) {
    $arguments=@('-NoProfile','-NonInteractive','-File',(Join-Path $Cli.Scripts $Entry),'-ConfigPath',$Cli.Config,'-WorkspacePath',$Cli.Workspace)
    foreach ($key in $Options.Keys) {
        if ($Options[$key] -is [bool]) { if ($Options[$key]) { $arguments+='-'+$key } }
        else { $arguments+=@(('-'+$key),[string]$Options[$key]) }
    }
    $output=& powershell.exe @arguments 2>&1 | Out-String
    [pscustomobject]@{Code=$LASTEXITCODE;Output=$output}
}
function Get-PlanningFixtureState($Fixture) {
    @(Get-ChildItem -LiteralPath $Fixture.Root -Recurse -File | Sort-Object FullName | ForEach-Object {
        $_.FullName+':'+(Get-FileHash -LiteralPath $_.FullName).Hash
    }) -join "`n"
}
