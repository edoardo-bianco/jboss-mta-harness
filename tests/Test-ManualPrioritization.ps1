#requires -Version 5.1
$ErrorActionPreference='Stop'; Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'PrioritizationFixture.ps1')
Import-Module (Join-Path $root 'scripts/HarnessIssues.psm1') -Force -DisableNameChecking
$f=New-Fixture 2
$p=$f.Projects[0]
$first=Register-HarnessManualIssue $p DEV-A 'Achado A'
Assert ($first.Counts.Registered -eq 3 -and $first.Counts.Manual -eq 1) 'Total deve incluir 2 MTA e 1 manual.'
Assert ([IO.File]::ReadAllText($p.IndexPath).Contains('Manuais: 1')) 'Indice mostra total manual atualizado pelo cadastro.'
$prepared=New-HarnessPrioritizationContext $f.Context -Category manual -Percentage 100
Assert ($prepared.InitialTotal -eq 1 -and $prepared.SliceSize -eq 1) 'Manual deve entrar na sua categoria.'
$data=Read-Prepared $prepared
Assert ($data.BaselineIssues[0].Id -ceq 'DEV-A' -and $null -eq $data.Projects[0].Mta) 'Priorizar manual nao inventa resultado MTA.'
$second=Register-HarnessManualIssue $p DEV-B 'Achado B'
$continued=New-HarnessPrioritizationContext $f.Context -Category manual -Mode Continue
Assert ($continued.InitialTotal -eq 1 -and $continued.SliceSize -eq 1) 'Nova issue nao muda base/quota em andamento.'
$again=New-HarnessPrioritizationContext $f.Context -Category manual -Mode Recreate -Percentage 100
Assert ($again.InitialTotal -eq 2) 'Recriar inclui a nova manual na base.'
$mt=New-HarnessPrioritizationContext $f.Context -Category mandatory -Percentage 100
Assert ($mt.InitialTotal -eq 2) 'Manuais nao entram como mandatory do MTA.'

Complete-Slice $f $again | Out-Null
Complete-Slice $f $mt | Out-Null
$manualPath=(Read-Prepared $again).FichaPaths[0].Path
$mtaPath=(Read-Prepared $mt).FichaPaths[0].Path
foreach ($reverse in @($false,$true)) {
    $mod=Get-Module HarnessPrioritization
    try {
        if ($reverse) {
            & $mod {
                function script:Get-ChildItem {
                    param([string]$LiteralPath,[string]$Filter,[switch]$File,[switch]$Directory,[switch]$Recurse)
                    $items=@(Microsoft.PowerShell.Management\Get-ChildItem @PSBoundParameters)
                    if ($Filter -eq 'contexto.json') { [Array]::Reverse($items) }
                    $items
                }
            }
        }
        Update-HarnessPrioritizationIndex $f.Root -RefreshSources | Out-Null
        Assert ([IO.File]::ReadAllText($manualPath).Contains('MTA nao consultado')) 'Refresh manual nao pode receber cache MTA.'
        Assert ([IO.File]::ReadAllText($mtaPath).Contains('Relatorio MTA atual')) 'Refresh MTA nao pode receber null do cache manual.'
    } finally { if ($reverse) { & $mod { Remove-Item Function:Get-ChildItem } } }
}

# Uma base mista nao transforma manual em issue MTA nao reencontrada.
$manualText=& (Get-Module HarnessPrioritization) {
    param($project,$path,$mta)
    Get-IssueSourcesText $project $mta 'DEV-A' manual ([IO.File]::ReadAllText($path)) $path
} $p $manualPath (Read-HarnessProjectMta $p)
Assert ($manualText.Contains('Issue manual:') -and -not $manualText.Contains('nao reencontrada') -and -not $manualText.Contains('Relatorio MTA atual')) 'Manual nao recebe status ou fonte MTA em uma base mista.'
# Mesmo sem relatorio MTA configurado, a base manual e explicita.
Publish-HarnessProjectFiles $p @{'projeto.json'=(@{pom=$p.Pom;mta=@{diretorio=$null}}|ConvertTo-Json)}
$without=New-HarnessPrioritizationContext $f.Context -Category manual -Mode Recreate -Percentage 100
Assert ($without.InitialTotal -eq 2) 'Manual pode ser priorizada sem MTA.'
'PASS: totais, categoria manual, base fixa, recriacao explicita e independencia do MTA.'
