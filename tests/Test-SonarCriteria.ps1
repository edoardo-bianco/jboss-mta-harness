#requires -Version 5.1
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $root 'scripts/HarnessSonarCriteria.psm1') -Force
function Assert($condition, $message) { if (-not $condition) { throw $message } }
function Evaluate($coverage='85', $blocker='0', $high='0', $issues='2', $baseline=$null) {
    $measures=@(
        [pscustomobject]@{metric='coverage'; value=$coverage},
        [pscustomobject]@{metric='software_quality_blocker_issues'; value=$blocker},
        [pscustomobject]@{metric='software_quality_high_issues'; value=$high},
        [pscustomobject]@{metric='violations'; value=$issues})
    Get-HarnessSonarCriteria -Measures $measures -Baseline $baseline
}
$pass=Evaluate
Assert ($pass.Status -eq 'PASS' -and $pass.BaselineComparison -eq 'PENDING') '85% e severidades zero devem passar, sem inventar comparacao.'
Assert ((Evaluate '84.9').Status -eq 'WARN') 'Cobertura baixa deve apenas avisar.'
Assert ((Evaluate '100' '1').Status -eq 'FAIL') 'Blocker deve reprovar.'
Assert ((Evaluate '100' '0' '1').Status -eq 'FAIL') 'High deve reprovar.'
Assert ((Evaluate '100' $null).Status -eq 'UNVERIFIED') 'Blocker ausente nao e zero.'
Assert ((Evaluate '100' $null '1').Status -eq 'FAIL') 'High comprovado deve reprovar mesmo com outra metrica ausente.'
foreach ($bad in @('-1','NaN','1.5','abc')) { Assert ((Evaluate '85' '0' $bad).Status -eq 'UNVERIFIED') 'Contagem invalida virou sucesso.' }
foreach ($bad in @($null,'101','-1','NaN')) { Assert ((Evaluate $bad).Status -eq 'UNVERIFIED') 'Cobertura desconhecida/invalida virou sucesso.' }
$baseline=[pscustomobject]@{RunId='before'; ResultPath='selected/result.json'; TotalIssues=2}
$increase=Evaluate '85' '0' '0' '3' $baseline
Assert ($increase.Status -eq 'WARN' -and $increase.IssuesDelta -eq 1 -and $increase.BaselineComparison -eq 'COMPARED') 'Aumento de issues deve avisar.'
Assert ((Evaluate '85' '0' '0' '2' $baseline).Status -eq 'PASS') 'Igualdade nao deve avisar.'
Assert ((Evaluate '85' '0' '0' '1' $baseline).IssuesDelta -eq -1) 'Reducao deve ser registrada.'
$legacy=@([pscustomobject]@{metric='critical_violations';value='0'},[pscustomobject]@{metric='blocker_violations';value='0'})
Assert ((Get-HarnessSonarCriteria $legacy).Status -eq 'UNVERIFIED') 'Critical nao pode substituir High.'
$duplicate=@([pscustomobject]@{metric='software_quality_high_issues';value='0'},[pscustomobject]@{metric='software_quality_high_issues';value='1'})
Assert ((Get-HarnessSonarCriteria $duplicate).Status -eq 'UNVERIFIED') 'Metricas duplicadas nao podem aprovar.'
Write-Output 'PASS: Blocker/High, limite 85%, diferenca de issues e metricas ausentes/invalidas.'
