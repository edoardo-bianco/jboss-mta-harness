#requires -Version 5.1
$ErrorActionPreference='Stop'; Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'PlanningCurrentFixture.ps1')
$f=New-PlanningFixture 1
$p=$f.Projects[0]
$received=Join-Path $p.Folder 'recebido'
Publish-HarnessProjectFiles $p @{'recebido/evidencias/nota.txt'='Evidencia recebida';'atual/planejamento/plano.md'='Plano local'}
$review=Start-HarnessReconciliationReview $p $received
Set-FixtureMta $p 2
$before=Get-PlanningFixtureState $f
Reject { Complete-HarnessReconciliation $p -Conclusion 'Base antiga nao pode ser publicada.' } 'Mudanca MTA deve impedir publicacao.'
Assert ((Get-PlanningFixtureState $f) -ceq $before) 'Rejeicao MTA alterou dados.'
$review=Start-HarnessReconciliationReview $p $received -Restart
[IO.File]::WriteAllText((Join-Path $received 'evidencias/nota.txt'),'Edicao do colega')
$before=Get-PlanningFixtureState $f
Reject { Complete-HarnessReconciliation $p -Conclusion 'Origem antiga nao pode ser publicada.' } 'Mudanca recebida deve impedir publicacao.'
Assert ((Get-PlanningFixtureState $f) -ceq $before) 'Rejeicao de origem alterou dados.'
$review=Start-HarnessReconciliationReview $p $received -Restart
# Mesmo conjunto inclui destinos oficiais, ultima conclusao e retirada do recebido.
$module=Get-Module HarnessProject
& $module {
    $script:reconciliationWriter=${function:Write-ProjectPublishedFile}; $script:reconciliationWrites=0
    function script:Write-ProjectPublishedFile { param($Source,$Destination)
        $script:reconciliationWrites++
        if ($script:reconciliationWrites -eq 3) { throw 'Falha sintetica na publicacao da reconciliacao' }
        & $script:reconciliationWriter $Source $Destination
    }
}
$before=Get-PlanningFixtureState $f
try { Reject { Complete-HarnessReconciliation $p -Conclusion 'Exame sintetico' -Resolutions @{'evidencias/nota.txt'='RECEBIDO'} } 'Interrupcao deve ser reportada.' }
finally { & $module { ${function:Write-ProjectPublishedFile}=$script:reconciliationWriter } }
Assert ((Get-PlanningFixtureState $f) -ceq $before) 'Rollback deve restaurar todo conjunto e preservar proposta/recebido.'
# Proposta editada por fora durante a publicacao: resultado e salvo, rascunho fica.
& $module { param($ProposalPath)
    $script:reconciliationProposal=Join-Path $ProposalPath 'migracao.md'
    $script:reconciliationMutated=$false
    function script:Write-ProjectPublishedFile { param($Source,$Destination)
        if (-not $script:reconciliationMutated) {
            $script:reconciliationMutated=$true
            [IO.File]::WriteAllText($script:reconciliationProposal,'Rascunho humano novo durante a publicacao')
        }
        & $script:reconciliationWriter $Source $Destination
    }
} $review.ProposalPath
try { $done=Complete-HarnessReconciliation $p -Conclusion 'Exame publicado; edicao paralela deve permanecer.' -Resolutions @{'evidencias/nota.txt'='RECEBIDO'} }
finally { & $module { ${function:Write-ProjectPublishedFile}=$script:reconciliationWriter } }
Assert ($done.Diagnostics.Count -eq 1 -and $done.Diagnostics[0].Contains('Resultado publicado')) 'Retorno deve distinguir publicacao concluida de rascunho concorrente.'
Assert ([IO.File]::ReadAllText((Join-Path $review.ProposalPath 'migracao.md')).Contains('Rascunho humano novo')) 'Edicao concorrente nao pode ser apagada ao limpar revisao.'
Assert ((Test-Path -LiteralPath $done.ReconciledPath) -and -not (Test-Path -LiteralPath (Join-Path $received 'evidencias/nota.txt'))) 'Publicacao bem-sucedida deve manter conclusao e consumo apenas do examinado.'
# Retomada nao reutiliza automaticamente base desatualizada apos publicacao.
Reject { Complete-HarnessReconciliation $p -Conclusion 'Nao reutilizar rascunho antigo sem comparar.' } 'Base antiga preservada nao pode sobrescrever conclusao nova.'
'PASS: edicao de MTA/origem, rollback integral e rascunho editado durante publicacao.'
