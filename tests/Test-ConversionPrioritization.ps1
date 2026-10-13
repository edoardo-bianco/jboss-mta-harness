#requires -Version 5.1
$ErrorActionPreference='Stop'; Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'ConversionFixture.ps1')
Import-Module (Join-Path $root 'tools/transicao/ConversaoPublicacao.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $root 'scripts/HarnessProject.psm1') -DisableNameChecking
Import-Module (Join-Path $root 'scripts/HarnessPrioritization.psm1') -DisableNameChecking
$f=New-ConversionFixture
$plan=Add-ConversionPlan $f ('d'*32)
$annex=Join-Path (Split-Path $plan.ContextPath -Parent) 'explicacao.md'
Write-ConversionFile $annex '# Evidencia humana compartilhada'
$plan.SelectedIssues=@('java::regra','java::segunda')
$plan|Add-Member IssueInputs @()
$plan|Add-Member EvidenceInputs @(@{Path=$annex;Relation='Justificativa do ajuste';Status='DISPONIVEL'})
Write-ConversionFile $f.Register ([IO.File]::ReadAllText($f.Register).Replace('<!-- mta:fim -->',"| java::segunda | Outra API | mandatory | 1 | PRESENTE | ANALISAR AGORA | PLANEJADA | Conferir contrato |`n<!-- mta:fim -->"))
$baseline=@('java::regra','java::segunda','java::terceira' | ForEach-Object {@{Source=$f.Source;Id=$_}})
$previous=$null
for ($i=0;$i -lt 2;$i++) {
    $id=([string][char](97+$i))*32
    $folder=Join-Path $f.Workspace ('.harness/priorizacao/'+$id)
    $ranking=Join-Path $folder 'priorizacao.md'; $context=Join-Path $folder 'context.json'
    $issue=$baseline[$i]
    $ficha=Join-Path $folder ('ficha-'+$i+'.md')
    $identity=@{Source=$f.Source;Id=$issue.Id}|ConvertTo-Json -Compress
    Write-ConversionFile $ficha ("# Ficha examinada`nRoteiro humano $i`n[Anexo](<$annex>)`n<!-- issue: $identity -->")
    $plan.IssueInputs+=@(@{Id=$issue.Id;FichaPath=$ficha})
    Write-ConversionFile $plan.ContextPath ($plan|ConvertTo-Json -Depth 15)
    if ($i -eq 0) {
        Write-ConversionFile $f.Register ([IO.File]::ReadAllText($f.Register).Replace('Conferir contrato',('[Plano](<'+$plan.PlanPath+'>) e [Ficha](<'+$ficha+'>)')))
    }
    $record=@{Purpose='issue-prioritization';SchemaVersion=4;Category='mandatory';RequestId=$id;SequenceId=('a'*32);Mode=$(if ($i) {'Continue'} else {'Start'});Previous=$(if ($previous) {@{RequestId=$previous}} else {$null});Projects=@(@{Source=$f.Source});ContextPath=$context;RankingPath=$ranking;Percentage='33.33';InitialTotal=3;SliceSize=1;BaselineIssues=$baseline;ExcludedIssues=@($baseline|Select-Object -First $i);AvailableIssues=@($baseline|Select-Object -Skip $i);FichaPaths=@(@{Source=$f.Source;Id=$issue.Id;Path=$ficha})}
    $result=@{RequestId=$id;Status='COMPLETED';AnalyzedIssues=@($issue);ProposedIssues=@($issue)}|ConvertTo-Json -Depth 8
    $markdown="# Ranking humano`nNota humana $i`n[Anexo](<$annex>)`n| Prioridade | Projeto | Issue | Avaliacao | Motivo / proxima acao |`n| --- | --- | --- | --- | --- |`n| 1 | apelido | [Problema](<$ficha>) | Conferida | Motivo concreto $i |`n<!-- priorizacao:resultado -->`n"+'```json'+"`n"+$result+"`n"+'```'+"`n<!-- /priorizacao:resultado -->"
    Write-ConversionFile $context ($record|ConvertTo-Json -Depth 12)
    Write-ConversionFile $ranking $markdown
    $previous=$id
}
$null=Invoke-ConversionApply $f.Workspace $f.Pom
$p=Get-HarnessProjectReference $f.Workspace $f.Pom
$path=Join-Path $p.Folder 'atual/priorizacao/mandatory/escopos/api/contexto.json'
$data=Get-Content -LiteralPath $path -Raw|ConvertFrom-Json
Assert ($data.Purpose -eq 'current-prioritization' -and $data.InitialTotal -eq 3 -and $data.ExcludedIssues.Count -eq 1) 'Base e exclusoes da fatia corrente preservadas.'
$text=[IO.File]::ReadAllText($data.RankingPath)
Assert ([IO.File]::ReadAllText($p.MigrationPath) -notmatch 'referencia legada indisponivel') 'Registro deve resolver fichas/ranking antes de transformar links.'
$planning=Get-Content -LiteralPath $p.ContextPath -Raw|ConvertFrom-Json
Assert ([IO.File]::ReadAllText($planning.FichaPaths[0].Path) -notmatch '<!-- issue:') 'Ficha corrente nao deve conservar identidade operacional legada.'
Assert ($planning.FichaPaths.Count -eq 2) 'Todas as fichas do lote devem ser combinadas com a priorizacao.'
foreach ($ficha in $planning.FichaPaths) {
    $human=[IO.File]::ReadAllText($ficha.Path)
    Assert ($human -notmatch 'referencia legada indisponivel' -and $human -match '\[Anexo\]\(<[^>]+explicacao.md>\)') 'Ficha deve manter link do anexo publicado na mesma conversao.'
}
Assert ($text -notmatch 'referencia legada indisponivel' -and $text -match '\[Anexo\]\(<[^>]+explicacao.md>\)') 'Ranking deve manter link do anexo publicado pelo planejamento.'
$block=Find-ProjectManagedBlock $text 'priorizacao:resultado'
$result=($block.Value -replace '^<!-- priorizacao:resultado:inicio -->\s*','' -replace '\s*<!-- priorizacao:resultado:fim -->$','')|ConvertFrom-Json
Assert ($result.Status -eq 'COMPLETED' -and $result.AnalyzedIssues.Count -eq 2) 'Cobertura acumulada deve incluir examinadas com ou sem nova proposta.'
Assert ($text -match 'Nota humana 0' -and $text -match 'Nota humana 1' -and $text -notmatch '\.harness[/\\]priorizacao') 'Texto humano consolidado e links correntes.'
Assert ($result.AnalyzedIssues[0].Reason -match 'Motivo concreto' -and $result.AnalyzedIssues[1].Reason -match 'Motivo concreto') 'Motivos humanos preservados.'
$before=Get-ConversionState $f
$again=Invoke-ConversionApply $f.Workspace $f.Pom
Assert ($again.Status -eq 'EQUIVALENTE' -and (Get-ConversionState $f) -ceq $before) 'Cobertura reaplicada sem regravar.'
$priorityModule=Get-Module HarnessPrioritization
& $priorityModule {param($Data,$Text,$Project) $null=Read-PrioritizationResult $Data $Text @($Project)} $data $text $p
'PASS: categoria, denominador, cobertura acumulada, motivos/fichas e consumidor corrente.'
