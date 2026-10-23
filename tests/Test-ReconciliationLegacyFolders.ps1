#requires -Version 5.1
$ErrorActionPreference='Stop'; Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'PlanningCurrentFixture.ps1')
$source=New-PlanningFixture 1
$target=New-PlanningFixture 1
$prepared=New-HarnessPrioritizationContext $source.Context -Category mandatory -Percentage 100 -Scope p
Complete-Slice $source $prepared | Out-Null
$data=Read-Prepared $prepared
$sp=$source.Projects[0]; $tp=$target.Projects[0]
$entry=$data.FichaPaths[0]
$oldRelative='atual/priorizacao/mandatory/issues/'+(ConvertTo-HarnessFunctionalPath $entry.Id)+'/ficha.md'
$oldPath=Join-Path $sp.Folder $oldRelative
$null=[IO.Directory]::CreateDirectory((Split-Path $oldPath -Parent))
Assert ($oldPath.StartsWith($sp.Folder+'\') -and $entry.Path.StartsWith($sp.Folder+'\')) 'Fixture restrita ao projeto.'
[IO.File]::Move($entry.Path,$oldPath)
$entry.Path=$oldPath
[IO.File]::WriteAllText($prepared.ContextPath,($data|ConvertTo-Json -Depth 15))
Update-HarnessPrioritizationIndex $source.Root | Out-Null
$ctx=$prepared.ContextPath.Substring($sp.Folder.Length+1).Replace('\','/')
$rank=$prepared.RankingPath.Substring($sp.Folder.Length+1).Replace('\','/')
$origin=Join-Path $target.Root 'colega'
$resolutions=@{}
foreach ($relative in @($ctx,$rank,$oldRelative,'evidencias/observacao.md')) {
    $path=Join-Path $origin $relative
    $null=[IO.Directory]::CreateDirectory((Split-Path $path -Parent))
    [IO.File]::WriteAllBytes($path,[IO.File]::ReadAllBytes((Join-Path $sp.Folder $relative)))
    $resolutions[$relative]='RECEBIDO'
}
Start-HarnessReconciliationReview $tp $origin | Out-Null
Complete-HarnessReconciliation $tp -Conclusion 'Adocao de ficha antiga conferida' -Resolutions $resolutions | Out-Null
$received=Get-Content -LiteralPath (Join-Path $tp.Folder $ctx) -Raw | ConvertFrom-Json
Assert ($received.InitialTotal -eq 1) 'Cobertura preservada.'
Assert ($received.FichaPaths[0].Path -ceq (Join-Path $tp.Folder $oldRelative)) 'Contexto aponta para ficha antiga adotada, sem apontar para pasta legivel inexistente.'
Assert (Test-Path -LiteralPath $received.FichaPaths[0].Path) 'Ficha recebida publicada.'
$refreshed=Update-HarnessPrioritizationIndex $target.Root -RefreshSources
Assert ([IO.File]::ReadAllText($received.FichaPaths[0].Path).Contains('Relatorio MTA atual')) 'Indice reencontra e atualiza fontes da ficha antiga recebida.'
'PASS: recebimento de ficha antiga, contexto/ranking/cobertura e atualizacao do indice.'
