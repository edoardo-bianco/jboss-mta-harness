#requires -Version 5.1
$ErrorActionPreference='Stop'; Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'ConversionFixture.ps1')
Import-Module (Join-Path $root 'tools/transicao/ConversaoPublicacao.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $root 'scripts/HarnessProject.psm1') -DisableNameChecking
Import-Module (Join-Path $root 'scripts/HarnessPrioritization.psm1') -DisableNameChecking
function Reject-Reason([scriptblock]$Action,[string]$Pattern) {
    $message=''; try { $null=& $Action } catch { $message=$_.Exception.Message }
    Assert ($message -match $Pattern) ('Recusa esperada: '+$Pattern+'. Recebido: '+$message)
}
$f=New-ConversionFixture
$baseline=@('java::regra','java::segunda','java::terceira' | ForEach-Object {@{Source=$f.Source;Id=$_}})
$records=@()
for ($i=0;$i -lt 2;$i++) {
    $id=([string][char](97+$i))*32
    $folder=Join-Path $f.Workspace ('.harness/priorizacao/'+$id)
    $context=Join-Path $folder 'context.json'; $ranking=Join-Path $folder 'priorizacao.md'
    $eligible=@($baseline | ForEach-Object {@{Source=$f.Source;Id=$_.Id;Category='mandatory'}})+@(@{Source=$f.Source;Id='java::nova';Category='mandatory'})
    $record=[pscustomobject]@{Purpose='issue-prioritization';SchemaVersion=2;RequestId=$id;SequenceId=('a'*32);Mode=$(if ($i) {'Continue'} else {'Start'});Previous=$(if ($i) {@{RequestId=('a'*32)}} else {$null});Projects=@(@{Source=$f.Source;EligibleIssues=$eligible});ContextPath=$context;RankingPath=$ranking;Percentage='100';InitialTotal=3;SliceSize=3;BaselineIssues=$baseline;ExcludedIssues=@();AvailableIssues=$baseline}
    $analyzed=@($baseline|Select-Object -First ($i+1))
    if ($i) {
        $ficha=Join-Path $folder 'ficha-real.md'
        $identity=@{Source=$f.Source;Id=$baseline[0].Id}|ConvertTo-Json -Compress
        Write-ConversionFile $ficha ("# Ficha posteriormente examinada`nRoteiro humano real`n<!-- issue: $identity -->")
        $record|Add-Member FichaPaths @(@{Source=$f.Source;Id=$baseline[0].Id;Path=$ficha})
    }
    $result=@{RequestId=$id;Status='COMPLETED';AnalyzedIssues=$analyzed;ProposedIssues=@()}|ConvertTo-Json -Depth 8
    Write-ConversionFile $context ($record|ConvertTo-Json -Depth 12)
    Write-ConversionFile $ranking ("# Ranking humano v2 $i`n<!-- priorizacao:resultado -->`n"+'```json'+"`n"+$result+"`n"+'```'+"`n<!-- /priorizacao:resultado -->")
    $records+=$record
}
$plan=Add-ConversionPlan $f ('d'*32)
$plan.SelectedIssues=@('java::segunda')
$planFicha=Join-Path (Split-Path $plan.ContextPath -Parent) 'ficha-planejada.md'
Write-ConversionFile $planFicha '# Conteudo humano disponivel somente no plano'
$plan|Add-Member FichaPath $planFicha
Write-ConversionFile $plan.ContextPath ($plan|ConvertTo-Json -Depth 15)
Write-ConversionFile $f.Register ([IO.File]::ReadAllText($f.Register).Replace('<!-- mta:fim -->',("| java::segunda | Outra API | mandatory | 1 | PRESENTE | ANALISAR AGORA | PLANEJADA | [Plano](<"+$plan.PlanPath+">) |`n<!-- mta:fim -->")))
$null=Invoke-ConversionApply $f.Workspace $f.Pom
$p=Get-HarnessProjectReference $f.Workspace $f.Pom
$data=Get-Content -LiteralPath (Join-Path $p.Folder 'atual/priorizacao/mandatory/escopos/api/contexto.json') -Raw|ConvertFrom-Json
$text=[IO.File]::ReadAllText($data.RankingPath)
$block=Find-ProjectManagedBlock $text 'priorizacao:resultado'
$result=($block.Value -replace '^<!-- priorizacao:resultado:inicio -->\s*','' -replace '\s*<!-- priorizacao:resultado:fim -->$','')|ConvertFrom-Json
Assert ($result.AnalyzedIssues.Count -eq 2 -and $result.Status -eq 'IN_PROGRESS') 'Uniao v2 sem duplicar exame ou preencher quota nao examinada.'
Assert ($data.ExcludedIssues.Count -eq 1 -and $data.AvailableIssues.Count -eq 2 -and $data.SliceSize -eq 2) 'Cobertura anterior excluida integralmente na fatia corrente.'
Assert ($data.OutsideBaseline -eq 1) 'Nova elegivel nao pode desaparecer da informacao de cobertura.'
Assert ($result.AnalyzedIssues[0].Reason -match 'Motivo nao estruturado') 'Lacuna v2 explicita, sem inventar motivo tecnico.'
Assert ([IO.File]::ReadAllText($data.FichaPaths[0].Path) -match 'Roteiro humano real') 'Ficha real posterior substitui ausencia anterior sem perder a cobertura declarada.'
Assert ([IO.File]::ReadAllText($data.FichaPaths[1].Path) -match 'Conteudo humano disponivel somente no plano') 'Ficha do plano substitui lacuna da priorizacao sem exigir texto sintetico.'
$priorityModule=Get-Module HarnessPrioritization
& $priorityModule {param($Data,$Text,$Project) $null=Read-PrioritizationResult $Data $Text @($Project)} $data $text $p
$before=Get-ConversionState $f
Reject-Reason { Invoke-ConversionApply $f.Workspace $f.Pom -PrioritizacaoContexto 'inexistente.json' } 'nao pertence ao Source'
Assert ((Get-ConversionState $f) -ceq $before) 'Escolha invalida nao pode cair na ponta automatica.'
$records[0].SliceSize=2
Write-ConversionFile $records[0].ContextPath ($records[0]|ConvertTo-Json -Depth 12)
$before=Get-ConversionState $f
Reject-Reason { Invoke-ConversionApply $f.Workspace $f.Pom } 'Quota, disponibilidade ou exclusoes inconsistentes'
Assert ((Get-ConversionState $f) -ceq $before) 'Quota ancestral invalida nao publica cobertura.'
'PASS: v2 parcial/sobreposto, lacunas, novas elegiveis, quota ancestral e escolha invalida.'
