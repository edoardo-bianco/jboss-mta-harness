#requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'HarnessProject.psm1') -DisableNameChecking

function Get-HarnessMtaExternalLocation {
    param($Context,$Project)
    if (-not $Context.PSObject.Properties['Config'] -or -not $Context.Config -or
        -not $Context.Config.PSObject.Properties['mta'] -or -not $Context.Config.mta -or
        -not $Context.Config.mta.PSObject.Properties['runsPath'] -or
        [string]::IsNullOrWhiteSpace([string]$Context.Config.mta.runsPath)) {
        throw 'Configure mta.runsPath com uma pasta externa em Workspace: configurar caminhos. Nenhum relatorio MTA sera gerado na .harness.'
    }
    if ($Context.Config.mta.runsPath -isnot [string]) { throw 'mta.runsPath deve ser um caminho de pasta externa.' }
    $base=Resolve-ProjectPath $Context.Config.mta.runsPath $Context.Root
    $sourceName=Split-Path $Project.Source -Leaf
    if (-not $sourceName) { throw 'Source precisa ter nome de pasta para organizar o MTA externo.' }
    if ($sourceName -ieq '.harness-mta-em-preparo') { throw 'Nome de pasta Source reservado para a area de preparo do MTA externo.' }
    $directory=Resolve-ProjectPath (Join-Path $base $sourceName) $Context.Root
    $sources=@($Project.Source)
    if ($Context.PSObject.Properties['Projects']) {
        $sources+=@($Context.Projects | ForEach-Object { Resolve-ProjectPath $_.path $Context.Root })
    }
    $sources=@($sources | Sort-Object -Unique)
    if (@($sources | Where-Object { (Split-Path $_ -Leaf) -ieq $sourceName }).Count -ne 1) {
        throw "Nome de pasta Source ambiguo no escopo: $sourceName. Use raizes MTA distintas para esses projetos."
    }
    foreach ($protected in @($Context.Root)+$sources) {
        $protected=Resolve-ProjectPath $protected $Context.Root
        if ($base -ieq $protected -or $base.StartsWith($protected+'\',[StringComparison]::OrdinalIgnoreCase) -or
            $protected -ieq $directory -or $protected.StartsWith($directory+'\',[StringComparison]::OrdinalIgnoreCase)) {
            throw 'mta.runsPath deve manter os relatorios fora do harness e das fontes das aplicacoes.'
        }
    }
    [pscustomobject]@{Root=$base;Directory=$directory}
}

function Get-HarnessMtaExternalAssociationText {
    param($Project,$Location,[string]$Previous)
    $config=ConvertFrom-Json $Previous
    if ((Resolve-ProjectPath $config.pom $Project.Root) -ine $Project.Pom) { throw 'Associacao ao POM mudou; atualize o indice antes de executar MTA.' }
    if ($config.mta.diretorio) {
        $current=Resolve-ProjectPath $config.mta.diretorio $Project.Root
        if ($current -ieq $Location.Directory) { return $Previous }
        throw ('Origem MTA explicita diverge de mta.runsPath/Source. Confira projeto.json: '+$Project.ConfigPath)
    }
    $config.mta.diretorio=$Location.Directory
    $config | ConvertTo-Json -Depth 20
}

Export-ModuleMember -Function Get-HarnessMtaExternalLocation,Get-HarnessMtaExternalAssociationText
