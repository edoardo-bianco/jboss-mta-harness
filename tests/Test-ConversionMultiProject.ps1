#requires -Version 5.1
$ErrorActionPreference='Stop'; Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'ConversionFixture.ps1')
Import-Module (Join-Path $root 'tools/transicao/ConversaoPublicacao.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $root 'scripts/HarnessProject.psm1') -DisableNameChecking
Import-Module (Join-Path $root 'scripts/HarnessPrioritization.psm1') -DisableNameChecking
$f=New-ConversionFixture
$conversion=Get-Module ConversaoPublicacao
Reject {
    & $conversion {
        param($Fixture)
        $state=[pscustomobject]@{Inputs=[pscustomobject]@{Session=[pscustomobject]@{Workspace=$Fixture.Workspace}}}
        $ranking=[pscustomobject]@{Path=(Join-Path $Fixture.Workspace 'ranking.md');Text='| 1 | api | java::regra | Conferida | Somente API foi analisada |';Version=4;MultiProject=$true;Proposed=@([pscustomobject]@{Project='api';Id='java::regra'},[pscustomobject]@{Project='outro';Id='java::regra'})}
        Get-ConversionRankingAssessment $state $ranking $ranking.Proposed[1] (Join-Path $Fixture.Workspace 'ficha-outro.md')
    } $f
} 'Linha textual de outra aplicacao nao comprova motivo da mesma regra em outro projeto.'
$otherSource=Join-Path $f.Area 'outra aplicacao'; $otherPom=Join-Path $otherSource 'pom.xml'
Write-ConversionFile $otherPom '<project><artifactId>outro</artifactId></project>'
$otherRegister=Join-Path $f.Workspace '.harness/projetos/outro__123456789abc/migracao.md'
Write-ConversionFile $otherRegister ([IO.File]::ReadAllText($f.Register).Replace($f.Source,$otherSource))
$participants=@{}; $participants[$f.Source]=$f.Pom; $participants[$otherSource]=$otherPom
$baseline=@(@{Source=$f.Source;Id='java::regra'},@{Source=$otherSource;Id='java::regra'})
$previous=$null
for ($i=0;$i -lt 2;$i++) {
    $id=([string][char](97+$i))*32
    $directory=Join-Path $f.Workspace ('.harness/priorizacao/'+$id)
    $context=Join-Path $directory 'context.json'; $ranking=Join-Path $directory 'priorizacao.md'; $ficha=Join-Path $directory 'ficha.md'
    $issue=$baseline[$i]; $identity=$issue|ConvertTo-Json -Compress
    Write-ConversionFile $ficha ("# Ficha $i`nRoteiro humano do projeto $i.`n<!-- issue: $identity -->")
    $data=@{Purpose='issue-prioritization';SchemaVersion=4;Category='mandatory';RequestId=$id;SequenceId=('a'*32);Mode=$(if ($i) {'Continue'} else {'Start'});Previous=$(if ($previous) {@{RequestId=$previous}} else {$null});Projects=@(@{Source=$f.Source},@{Source=$otherSource});ContextPath=$context;RankingPath=$ranking;Percentage='50';InitialTotal=2;SliceSize=1;BaselineIssues=$baseline;ExcludedIssues=@($baseline|Select-Object -First $i);AvailableIssues=@($baseline|Select-Object -Skip $i);FichaPaths=@(@{Source=$issue.Source;Id=$issue.Id;Path=$ficha})}
    $result=@{RequestId=$id;Status='COMPLETED';AnalyzedIssues=@($issue);ProposedIssues=@($issue)}|ConvertTo-Json -Depth 8
    Write-ConversionFile $context ($data|ConvertTo-Json -Depth 12)
    Write-ConversionFile $ranking ("# Ranking humano $i`n| Prioridade | Projeto | Issue | Avaliacao | Motivo |`n| --- | --- | --- | --- | --- |`n| 1 | projeto $i | [Issue](<$ficha>) | Conferida | Motivo humano $i |`n<!-- priorizacao:resultado -->`n"+'```json'+"`n"+$result+"`n"+'```'+"`n<!-- /priorizacao:resultado -->")
    $previous=$id
}
foreach ($category in @('mandatory','optional')) {
    $singleId=if ($category -eq 'mandatory') {'c'*32} else {'d'*32}
    $singleDirectory=Join-Path $f.Workspace ('.harness/priorizacao/'+$singleId)
    $singleContext=Join-Path $singleDirectory 'context.json'; $singleRanking=Join-Path $singleDirectory 'priorizacao.md'; $singleFicha=Join-Path $singleDirectory 'ficha.md'
    $identity=$baseline[0]|ConvertTo-Json -Compress
    Write-ConversionFile $singleFicha ("# Ficha 0`nRoteiro humano do projeto 0.`n<!-- issue: $identity -->")
    $single=@{Purpose='issue-prioritization';SchemaVersion=4;Category=$category;RequestId=$singleId;SequenceId=$singleId;Mode='Start';Previous=$null;Projects=@(@{Source=$f.Source});ContextPath=$singleContext;RankingPath=$singleRanking;Percentage='100';InitialTotal=1;SliceSize=1;BaselineIssues=@($baseline[0]);ExcludedIssues=@();AvailableIssues=@($baseline[0]);FichaPaths=@(@{Source=$f.Source;Id='java::regra';Path=$singleFicha})}
    $singleResult=@{RequestId=$singleId;Status='COMPLETED';AnalyzedIssues=@($baseline[0]);ProposedIssues=@($baseline[0])}|ConvertTo-Json -Depth 8
    Write-ConversionFile $singleContext ($single|ConvertTo-Json -Depth 12)
    Write-ConversionFile $singleRanking ("# Outro escopo $category`n| 1 | api | [Issue](<$singleFicha>) | Conferida | Motivo proprio do escopo |`n<!-- priorizacao:resultado -->`n"+'```json'+"`n"+$singleResult+"`n"+'```'+"`n<!-- /priorizacao:resultado -->")
}
$completeRanking=[IO.File]::ReadAllText($ranking)
$partial=@{RequestId=$id;Status='IN_PROGRESS';AnalyzedIssues=@();ProposedIssues=@()}|ConvertTo-Json -Depth 8
Write-ConversionFile $ranking ("# Fatia pendente`n<!-- priorizacao:resultado -->`n"+'```json'+"`n"+$partial+"`n"+'```'+"`n<!-- /priorizacao:resultado -->")
$before=Get-ConversionState $f
Reject {Invoke-ConversionApply $f.Workspace $f.Pom -Participantes $participants} 'Mestre deve conferir associacao de participante ainda sem issue examinada.'
Assert ((Get-ConversionState $f) -ceq $before) 'Falta de associacao participante nao publica cobertura parcial.'
Write-ConversionFile $ranking $completeRanking
$before=Get-ConversionState $f
Reject {Invoke-ConversionApply $f.Workspace $f.Pom} 'Participante sem associacao explicita nao pode ser adivinhado.'
Reject {Invoke-ConversionApply $f.Workspace $f.Pom -Participantes $participants} 'Mestre nao publica cobertura antes das fichas dos participantes.'
Assert ((Get-ConversionState $f) -ceq $before) 'Recusas devem preservar todas as origens e destinos.'
$null=Invoke-ConversionApply $f.Workspace $otherPom -Participantes $participants
$master=Get-HarnessProjectReference $f.Workspace $f.Pom; $other=Get-HarnessProjectReference $f.Workspace $otherPom
Assert (-not (Test-Path -LiteralPath $master.Folder)) 'Conversao do participante nao escreve no mestre.'
$fichaRelative='atual/priorizacao/mandatory/issues/'+(ConvertTo-HarnessFunctionalPath 'java::regra')+'/ficha.md'
$otherFicha=Join-Path $other.Folder $fichaRelative
Assert ([IO.File]::ReadAllText($otherFicha) -match 'Roteiro humano do projeto 1') 'Participante preserva sua ficha, mesmo com ID igual no mestre.'
Assert (-not @(Get-ChildItem -LiteralPath $other.Folder -Filter contexto.json -Recurse).Count) 'Participante nao publica cobertura global duplicada.'
$otherBefore=@(Get-ChildItem -LiteralPath $other.Folder -File -Recurse | ForEach-Object { $_.FullName+' '+(Get-FileHash -LiteralPath $_.FullName).Hash }) -join "`n"
$null=Invoke-ConversionApply $f.Workspace $f.Pom -Participantes $participants
$otherAfter=@(Get-ChildItem -LiteralPath $other.Folder -File -Recurse | ForEach-Object { $_.FullName+' '+(Get-FileHash -LiteralPath $_.FullName).Hash }) -join "`n"
Assert ($otherAfter -ceq $otherBefore) 'Mestre nao regrava dados dos participantes.'
$path=Join-Path $master.Folder ('atual/priorizacao/mandatory/escopos/'+(ConvertTo-HarnessFunctionalPath 'api|outro')+'/contexto.json')
$data=Get-Content -LiteralPath $path -Raw|ConvertFrom-Json
$text=[IO.File]::ReadAllText($data.RankingPath)
$module=Get-Module HarnessPrioritization
$result=& $module {param($Data,$Text,$Projects) Read-PrioritizationResult $Data $Text $Projects} $data $text @($master,$other)
Assert ($data.InitialTotal -eq 2 -and $data.SliceSize -eq 1 -and $data.ExcludedIssues.Count -eq 1 -and $data.Projects.Count -eq 2) 'Denominador, quota e exclusoes continuam globais.'
Assert ($result.AnalyzedIssues.Count -eq 2 -and @($result.AnalyzedIssues.Project | Sort-Object -Unique).Count -eq 2) 'Mesmo ID em projetos distintos conserva dois exames.'
Assert (@(Get-ChildItem -LiteralPath (Join-Path $master.Folder 'atual/priorizacao') -Filter contexto.json -Recurse).Count -eq 3) 'Categorias e conjuntos de participantes mantem contextos separados.'
Assert ([IO.File]::ReadAllText((Join-Path $master.Folder $fichaRelative)) -match 'Roteiro humano do projeto 0') 'Mestre preserva sua propria ficha.'
$before=Get-ConversionState $f
Assert ((Invoke-ConversionApply $f.Workspace $otherPom -Participantes $participants).Status -eq 'EQUIVALENTE') 'Participante continua equivalente depois da publicacao do mestre.'
Assert ((Invoke-ConversionApply $f.Workspace $f.Pom -Participantes $participants).Status -eq 'EQUIVALENTE') 'Mestre reaplicado continua equivalente.'
Assert ((Get-ConversionState $f) -ceq $before) 'Reaplicacao dos dois projetos nao regrava dados.'
$human=[IO.File]::ReadAllText($otherFicha)+"`nAcrescimo humano posterior: conferir integracao."
Write-ConversionFile $otherFicha $human
$before=Get-ConversionState $f
Assert ((Invoke-ConversionApply $f.Workspace $f.Pom -Participantes $participants).Status -eq 'EQUIVALENTE') 'Mestre aceita acrescimo humano que preserva a analise legada.'
Reject {Invoke-ConversionApply $f.Workspace $otherPom -Participantes $participants} 'Reaplicar participante nao sobrescreve trabalho humano posterior.'
Assert ((Get-ConversionState $f) -ceq $before) 'A conferencia nao modifica acrescimos humanos.'
Write-ConversionFile $otherFicha ($human.Replace('Roteiro humano do projeto 1.','Conteudo substituido sem conciliacao.'))
$before=Get-ConversionState $f
Reject {Invoke-ConversionApply $f.Workspace $f.Pom -Participantes $participants} 'Mestre recusa ficha que perdeu a analise legada.'
Assert ((Get-ConversionState $f) -ceq $before) 'Divergencia de ficha nao modifica dados.'
Write-ConversionFile $otherFicha $human
$conversion=Get-Module ConversaoPublicacao
& $conversion {
    param($Path)
    $script:originalMultiBuilder=${function:New-ConversionCoreFiles}; $script:changedPartnerFicha=$Path
    Set-Item function:script:New-ConversionCoreFiles {
        param($Inputs,$Mta,$Priority,$Build,$Sonar,$Attempt,$Participants)
        $state=& $script:originalMultiBuilder $Inputs $Mta $Priority $Build $Sonar $Attempt $Participants
        [IO.File]::AppendAllText($script:changedPartnerFicha,"`nEdicao externa durante publicacao.")
        $state
    }
} $otherFicha
try { Reject {Invoke-ConversionApply $f.Workspace $f.Pom -Participantes $participants} 'Edicao concorrente de ficha participante deve impedir publicacao.' }
finally { & $conversion { Set-Item function:script:New-ConversionCoreFiles $script:originalMultiBuilder } }
Assert ([IO.File]::ReadAllText($otherFicha) -match 'Edicao externa durante publicacao') 'Edicao externa deve permanecer intacta.'
'PASS: associacao explicita, identidade Project/ID, cobertura global e publicacao local.'
