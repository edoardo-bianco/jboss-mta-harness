#requires -Version 5.1
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $root 'scripts/HarnessSonarCriteria.psm1') -Force
function Assert($condition, $message) { if (-not $condition) { throw $message } }
function Issue($key='old', $severity='MAJOR', $impact='') {
    $impacts=@(); if ($impact) { $impacts+= [pscustomobject]@{severity=$impact;softwareQuality='SECURITY'} }
    [pscustomobject]@{key=$key;severity=$severity;impacts=$impacts}
}
function Evaluate($coverage='85', $duplication='5', $items=@((Issue)), $baseline=$null, $phase='ANTES') {
    $measures=@([pscustomobject]@{metric='coverage';value=$coverage},
        [pscustomobject]@{metric='duplicated_lines_density';value=$duplication},
        [pscustomobject]@{metric='violations';value='2'})
    $snapshot=$null
    if ($null -ne $items) { $snapshot=[pscustomobject]@{Status='COMPLETE';Issues=@($items)} }
    Get-HarnessSonarCriteria -Measures $measures -IssueSnapshot $snapshot -Baseline $baseline -Phase $phase
}
Assert ((Evaluate).Status -eq 'PASS') '85% e duplicidade 5% devem atender.'
Assert ((Evaluate '80').Status -eq 'WARN') '80% atende minimo, mas avisa meta 85.'
Assert ((Evaluate '84.99').Status -eq 'WARN') 'Abaixo de 85 deve avisar.'
Assert ((Evaluate '79.99').Status -eq 'FAIL') 'Abaixo de 80 deve ser nao conforme.'
Assert ((Evaluate '85' '5.01').Status -eq 'FAIL') 'Acima de 5% deve ser nao conforme.'
Assert ((Evaluate '0' '0').Status -eq 'FAIL') 'Zero nao pode ser tratado como ausente.'
foreach ($severity in @('CRITICAL','BLOCKER')) {
    $r=Evaluate '85' '0' @((Issue 'legacy' $severity))
    Assert ($r.Status -eq 'FAIL' -and $r.SevereIssueKeys -contains 'legacy') 'Severidade Standard nao avaliada.'
}
foreach ($impact in @('HIGH','BLOCKER')) {
    $r=Evaluate '85' '0' @((Issue 'modern' 'MAJOR' $impact))
    Assert ($r.Status -eq 'FAIL' -and $r.SevereIssueKeys -contains 'modern') 'Impacto MQR nao avaliado.'
}
$both=Evaluate '85' '0' @((Issue 'same' 'CRITICAL' 'HIGH'))
Assert ($both.SevereIssues -eq 1) 'Uma issue foi contada duas vezes como severa.'
Assert ((Evaluate '85' '0' @()).Status -eq 'PASS') 'Lista completa vazia deve permitir zero.'
Assert ((Evaluate '85' '0' $null).Status -eq 'UNVERIFIED') 'Lista ausente nao pode virar zero.'
foreach ($bad in @($null,'101','-1','NaN','1,5')) {
    Assert ((Evaluate $bad).Status -eq 'UNVERIFIED') 'Cobertura invalida aceita.'
    Assert ((Evaluate '85' $bad).Status -eq 'UNVERIFIED') 'Duplicidade invalida aceita.'
}
Assert ((Evaluate $null '0' @((Issue 'critical' 'CRITICAL'))).Status -eq 'FAIL') 'Severa comprovada deve prevalecer sobre metrica ausente.'
$baseline=[pscustomobject]@{RunId='before';ResultPath='selected/result.json';TotalIssues=2;Issues=@((Issue 'old'))}
$new=Evaluate '85' '0' @((Issue 'replacement')) $baseline 'DEPOIS'
Assert ($new.Status -eq 'FAIL' -and $new.NewIssueKeys -contains 'replacement' -and $new.IssuesDelta -eq 0) 'Troca de issue com total igual deve ser detectada.'
Assert ($new.BaselineComparison -eq 'COMPARED' -and $new.BaselineRunId -eq 'before') 'Comparacao perdeu origem.'
Assert ((Evaluate '85' '0' @((Issue)) $baseline 'DEPOIS').Status -eq 'PASS') 'Issue persistente nao e nova.'
Assert ((Evaluate '85' '0' @() $baseline 'DEPOIS').Status -eq 'PASS') 'Reducao sem novas nao deve reprovar.'
$legacy=[pscustomobject]@{RunId='legacy';ResultPath='legacy/result.json';TotalIssues=2;Issues=$null}
Assert ((Evaluate '85' '0' @((Issue)) $legacy 'DEPOIS').Status -eq 'UNVERIFIED') 'Baseline sem lista nao prova ausencia de novas.'
Assert ((Evaluate '85' '0' @((Issue)) $null 'DEPOIS').Status -eq 'UNVERIFIED') 'DEPOIS sem baseline nao prova ausencia de novas.'
$missing=Evaluate
Assert ($missing.BaselineComparison -eq 'PENDING' -and $null -eq $missing.NewIssueKeys) 'ANTES nao pode inventar comparacao.'
Write-Output 'PASS: cobertura 80/85, duplicidade 5, severidades Standard/MQR e novas issues por chave.'
