#requires -Version 5.1
$ErrorActionPreference='Stop'; Set-StrictMode -Version Latest
$root=Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $root 'scripts/HarnessProject.psm1') -Force -DisableNameChecking
function Assert($value,[string]$message) { if (-not $value) { throw $message } }
$states=@('NAO ANALISADA','EM ANALISE','ANALISADA','PLANEJADA','EM IMPLEMENTACAO','IMPLEMENTADA','VERIFICADA','CONCLUIDA')
$rows=@(for ($i=0;$i -lt $states.Count;$i++) {
    [pscustomobject]@{Id=('regra-'+$i);Category='mandatory';Presence='PRESENTE';Decision='A DEFINIR';Progress=$states[$i]}
})
$rows+=@(
    [pscustomobject]@{Id='adiada';Category='mandatory';Presence='NAO REENCONTRADA';Decision='ADIAR';Progress='LEGADO'},
    [pscustomobject]@{Id='fora';Category='mandatory';Presence='PRESENTE';Decision='FORA DO ESCOPO';Progress=''},
    [pscustomobject]@{Id='DEV-1';Category='manual';Presence='MANUAL';Decision='A DEFINIR';Progress='IMPLEMENTADA'},
    [pscustomobject]@{Id='manual-mta';Category='manual';Presence='PRESENTE';Decision='A DEFINIR';Progress='CONCLUIDA'}
)
$progress=Get-HarnessIssueProgress -Rows $rows
Assert ($progress.Total -eq 12 -and $progress.Groups.Count -eq 3) 'Origem manual deve permanecer distinta da categoria MTA homonima.'
$group=@($progress.Groups | Where-Object Category -CEQ mandatory)[0]
Assert ($group.Total -eq 10 -and $group.States.Count -eq 10) 'Denominador inclui adiadas, fora do escopo, nao reencontradas e estados livres.'
foreach ($state in $states) {
    $entry=@($group.States | Where-Object State -CEQ $state)[0]
    Assert ($entry.Count -eq 1 -and $entry.Percent -eq 10 -and $entry.Ids.Count -eq 1) 'Cada estado deve informar quantidade, percentual e membros.'
}
Assert ($progress.Deferred -eq 1 -and $progress.OutOfScope -eq 1 -and $progress.NotFound -eq 1) 'Decisao e presenca sao indicadores separados.'
Assert (@($group.States | Where-Object { -not $_.Known }).Count -eq 2) 'Vazio/desconhecido permanecem lacunas distintas.'
$three=Get-HarnessIssueProgress -Rows $rows[0..2]
Assert ($three.Groups[0].States[0].Percent -eq 33.33) 'Percentual arredondado com duas casas.'
$zero=Get-HarnessIssueProgress -Rows @() -Categories @([pscustomobject]@{Origin='MTA';Category='optional'})
Assert ($zero.Total -eq 0 -and $null -eq $zero.Groups[0].States[0].Percent) 'Categoria vazia tem zero issues e percentual sem base.'
$failed=$false; try { Get-HarnessIssueProgress -Rows @($rows[0],$rows[0]) | Out-Null } catch { $failed=$true }
Assert $failed 'Identidade duplicada nao pode produzir contagem.'
$failed=$false; try { Get-HarnessIssueProgress -Rows @([pscustomobject]@{Id='';Category='x';Presence='MANUAL';Decision='';Progress=''}) | Out-Null } catch { $failed=$true }
Assert $failed 'Identidade vazia nao pode produzir contagem.'
'PASS: estados, denominadores, origem, lacunas, arredondamento e identidades.'
