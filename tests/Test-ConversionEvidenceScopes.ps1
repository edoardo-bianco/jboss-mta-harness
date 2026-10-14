#requires -Version 5.1
$ErrorActionPreference='Stop'; Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'ConversionFixture.ps1')
Import-Module (Join-Path $root 'tools/transicao/ConversaoPublicacao.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $root 'scripts/HarnessProject.psm1') -DisableNameChecking
function Reject-Scope([scriptblock]$Action,[string]$Pattern,[string]$Message) {
    try { $null=& $Action } catch { Assert ($_.Exception.Message -match $Pattern) ($Message+' Erro inesperado: '+$_.Exception.Message); return }
    throw $Message
}
function Get-ScopeFolderState([string]$Folder) {
    if (-not (Test-Path -LiteralPath $Folder)) { return 'AUSENTE' }
    @(Get-ChildItem -LiteralPath $Folder -Recurse -File | Sort-Object FullName | ForEach-Object { $_.FullName+' '+$_.LastWriteTimeUtc.Ticks+' '+(Get-FileHash -LiteralPath $_.FullName).Hash }) -join "`n"
}
function Assert-ScopeLink([string]$Document,[string]$Label,[string]$Target) {
    $match=[regex]::Match([IO.File]::ReadAllText($Document),('\['+[regex]::Escape($Label)+'\]\(<([^>]+)>\)'))
    Assert $match.Success ('Link funcional ausente: '+$Label+' em '+$Document)
    $relative=[Uri]::UnescapeDataString($match.Groups[1].Value).Replace('/','\')
    $actual=[IO.Path]::GetFullPath((Join-Path (Split-Path $Document -Parent) $relative))
    Assert ($actual -ieq $Target -and (Test-Path -LiteralPath $Target -PathType Leaf)) ('Link '+$Label+' aponta ao dono incorreto ou indisponivel: '+$actual)
}
function Add-EvidenceScope($Fixture,$Members,[string]$Id,[string]$Label) {
    $folder=Join-Path $Fixture.Workspace ('.harness/priorizacao/'+$Id)
    $context=Join-Path $folder 'context.json'; $ranking=Join-Path $folder 'priorizacao.md'
    $issues=@($Members | ForEach-Object { @{Source=$_.Source;Id='java::regra'} })
    $fichas=@($Members | ForEach-Object { @{Source=$_.Source;Id='java::regra';Path=$_.Ficha} })
    $data=@{Purpose='issue-prioritization';SchemaVersion=4;Category='mandatory';RequestId=$Id;SequenceId=$Id;Mode='Start';Previous=$null;Projects=@($Members|ForEach-Object {@{Source=$_.Source}});ContextPath=$context;RankingPath=$ranking;Percentage='100';InitialTotal=2;SliceSize=2;BaselineIssues=$issues;ExcludedIssues=@();AvailableIssues=$issues;FichaPaths=$fichas}
    Write-ConversionFile $context ($data|ConvertTo-Json -Depth 12)
    $result=@{RequestId=$Id;Status='COMPLETED';AnalyzedIssues=$issues;ProposedIssues=$issues}|ConvertTo-Json -Depth 8
    $rows=@(for ($i=0;$i -lt $Members.Count;$i++) { '| '+($i+1)+' | '+$Members[$i].Name+' | [Issue](<'+$Members[$i].Ficha+'>) | Conferida | Motivo '+$Members[$i].Name+' |' })
    Write-ConversionFile (Join-Path $folder ('anexo-'+$Label+'.md')) ('# Exclusivo do ranking '+$Label)
    Write-ConversionFile $ranking ("# Ranking $Label`n[Exclusivo ranking](anexo-$Label.md)`n[Comum](<$($Fixture.Shared)>)`n"+($rows-join "`n")+"`n<!-- priorizacao:resultado -->`n"+'```json'+"`n"+$result+"`n"+'```'+"`n<!-- /priorizacao:resultado -->")
}
$f=New-ConversionFixture
$members=@([pscustomobject]@{Name='api';Source=$f.Source;Pom=$f.Pom;Register=$f.Register;Ficha=$null})
foreach ($name in @('backend','cliente')) {
    $source=Join-Path $f.Area $name; $pom=Join-Path $source 'pom.xml'
    Write-ConversionFile $pom ('<project><artifactId>'+$name+'</artifactId></project>')
    $register=Join-Path $f.Workspace ('.harness/projetos/'+$name+'__123456789abc/migracao.md')
    Write-ConversionFile $register ([IO.File]::ReadAllText($f.Register).Replace($f.Source,$source))
    $members+=[pscustomobject]@{Name=$name;Source=$source;Pom=$pom;Register=$register;Ficha=$null}
}
$common=Join-Path $f.Workspace '.harness/priorizacao/documentos'
$shared=Join-Path $common 'compartilhado.md'; $contract=Join-Path $common 'contrato-plano.md'
$f|Add-Member Shared $shared
Write-ConversionFile $shared '# Evidencia compartilhada: [Bytes](ensaio.bin) [Ciclo](ciclo.md)'
Write-ConversionFile (Join-Path $common 'ciclo.md') '# Referencia circular: [Comum](compartilhado.md)'
[IO.File]::WriteAllBytes((Join-Path $common 'ensaio.bin'),[byte[]](10,0,255))
Write-ConversionFile $contract '# Contrato consumido pela ficha A e pelo plano C: [Comum](compartilhado.md)'
foreach ($member in $members) {
    $member.Ficha=Join-Path $common ('ficha-'+$member.Name+'.md')
    $identity=@{Source=$member.Source;Id='java::regra'}|ConvertTo-Json -Compress
    $extra=if ($member.Name -ceq 'api') {"`n[Contrato plano](contrato-plano.md)"} else {''}
    Write-ConversionFile $member.Ficha ("# Ficha $($member.Name)`nAnalise humana $($member.Name).`n[Comum](compartilhado.md)`n[Exclusivo]($($member.Name)/detalhe.md)"+$extra+"`n<!-- issue: $identity -->")
    Write-ConversionFile (Join-Path $common ($member.Name+'/detalhe.md')) ('# Exclusivo da ficha '+$member.Name)
}
Add-EvidenceScope $f @($members[0],$members[1]) ('a'*32) 'ab'
Add-EvidenceScope $f @($members[1],$members[2]) ('b'*32) 'bc'
$planFixture=[pscustomobject]@{Workspace=$f.Workspace;Source=$members[2].Source;Register=$members[2].Register}
$plan=Add-ConversionPlan $planFixture ('c'*32) -ProjectFolder 'cliente'
$plan|Add-Member EvidenceInputs @(@{Path=$contract;Relation='Contrato usado no plano C'},@{Path=$shared;Relation='Ensaio comum usado no plano C'})
Write-ConversionFile $plan.ContextPath ($plan|ConvertTo-Json -Depth 12)
Write-ConversionFile $plan.PlanPath ("# Plano humano C - GO PENDENTE`n[Contrato plano](<$contract>)")
$participants=@{}; foreach ($member in $members) { $participants[$member.Source]=$member.Pom }
$participants[$members[2].Source]=@{Pom=$members[2].Pom;Contexto=$plan.ContextPath}
$projects=@($members|ForEach-Object {Get-HarnessProjectReference $f.Workspace $_.Pom})
$originals=@(Get-ChildItem -LiteralPath $f.Area -Recurse -File | ForEach-Object { [pscustomobject]@{Path=$_.FullName;Hash=(Get-FileHash -LiteralPath $_.FullName).Hash} })

$null=Invoke-ConversionApply $f.Workspace $members[2].Pom -Participantes $participants
Assert (-not (Test-Path -LiteralPath $projects[0].Folder) -and -not (Test-Path -LiteralPath $projects[1].Folder)) 'Converter C nao escreve em A ou B.'
foreach ($name in @('compartilhado.md','ciclo.md','ensaio.bin','contrato-plano.md')) {
    Assert (Test-Path -LiteralPath (Join-Path $projects[2].EvidencePath $name)) ('Maior consumidor ordinal C deve ser o unico dono de '+$name+', inclusive pelo plano parceiro.')
}
$bytesPath=Join-Path $projects[2].EvidencePath 'ensaio.bin'; $bytes=[IO.File]::ReadAllBytes($bytesPath)
[IO.File]::Delete($bytesPath)
try {
    $before=Get-ConversionState $f
    Reject-Scope {Invoke-ConversionApply $f.Workspace $members[1].Pom -Participantes $participants} 'anexos do participante|Anexo participante' 'Mestre B nao publica cobertura com dependencia transitiva de C ausente.'
    Assert ((Get-ConversionState $f) -ceq $before) 'Recusa por anexo ausente nao publica arquivos.'
} finally { [IO.File]::WriteAllBytes($bytesPath,$bytes) }
$cBefore=Get-ScopeFolderState $projects[2].Folder
$null=Invoke-ConversionApply $f.Workspace $members[1].Pom -Participantes $participants
Assert (-not (Test-Path -LiteralPath $projects[0].Folder) -and (Get-ScopeFolderState $projects[2].Folder) -ceq $cBefore) 'Converter B escreve somente em B e preserva C.'
[IO.File]::WriteAllBytes($bytesPath,[byte[]](99))
try {
    $before=Get-ConversionState $f
    Reject-Scope {Invoke-ConversionApply $f.Workspace $members[0].Pom -Participantes $participants} 'Anexo participante diverge' 'Mestre A deve conferir anexo de C requerido pelo escopo encadeado.'
    Assert ((Get-ConversionState $f) -ceq $before) 'Recusa por anexo divergente preserva trabalho dos participantes.'
} finally { [IO.File]::WriteAllBytes($bytesPath,$bytes) }
$bBefore=Get-ScopeFolderState $projects[1].Folder; $cBefore=Get-ScopeFolderState $projects[2].Folder
$null=Invoke-ConversionApply $f.Workspace $members[0].Pom -Participantes $participants
Assert ((Get-ScopeFolderState $projects[1].Folder) -ceq $bBefore -and (Get-ScopeFolderState $projects[2].Folder) -ceq $cBefore) 'Converter A preserva integralmente B e C.'
$fichaRelative='atual/priorizacao/mandatory/issues/'+(ConvertTo-HarnessFunctionalPath 'java::regra')+'/ficha.md'
for ($i=0;$i -lt 3;$i++) {
    $project=$projects[$i]; $ficha=Join-Path $project.Folder $fichaRelative
    Assert-ScopeLink $ficha 'Comum' (Join-Path $projects[2].EvidencePath 'compartilhado.md')
    Assert-ScopeLink $ficha 'Exclusivo' (Join-Path $project.EvidencePath 'detalhe.md')
    Assert ([IO.File]::ReadAllText((Join-Path $project.EvidencePath 'detalhe.md')) -match $members[$i].Name) 'Anexo exclusivo da ficha permanece em seu projeto.'
    if ($i -lt 2) {
        foreach ($name in @('compartilhado.md','ciclo.md','ensaio.bin','contrato-plano.md')) { Assert (-not (Test-Path -LiteralPath (Join-Path $project.EvidencePath $name))) 'Anexo comum nao pode ser duplicado por escopo.' }
    }
}
Assert-ScopeLink (Join-Path $projects[0].Folder $fichaRelative) 'Contrato plano' (Join-Path $projects[2].EvidencePath 'contrato-plano.md')
Assert-ScopeLink $projects[2].PlanPath 'Contrato plano' (Join-Path $projects[2].EvidencePath 'contrato-plano.md')
Assert-ScopeLink (Join-Path $projects[2].EvidencePath 'compartilhado.md') 'Bytes' $bytesPath
Assert-ScopeLink (Join-Path $projects[2].EvidencePath 'ciclo.md') 'Comum' (Join-Path $projects[2].EvidencePath 'compartilhado.md')
Assert ([Convert]::ToBase64String([IO.File]::ReadAllBytes($bytesPath)) -ceq 'CgD/') 'Dependencia transitiva conserva bytes.'
for ($i=0;$i -lt 2;$i++) {
    $scope=$members[$i].Name+'|'+$members[$i+1].Name
    $contextPath=Join-Path $projects[$i].Folder ('atual/priorizacao/mandatory/escopos/'+(ConvertTo-HarnessFunctionalPath $scope)+'/contexto.json')
    $current=Get-Content -LiteralPath $contextPath -Raw|ConvertFrom-Json
    $label=if ($i) {'bc'} else {'ab'}
    Assert-ScopeLink $current.RankingPath 'Exclusivo ranking' (Join-Path $projects[$i].EvidencePath ('anexo-'+$label+'.md'))
    Assert-ScopeLink $current.RankingPath 'Comum' (Join-Path $projects[2].EvidencePath 'compartilhado.md')
}
$incomplete=@{}; $incomplete[$members[0].Source]=$members[0].Pom; $incomplete[$members[1].Source]=$members[1].Pom
$before=Get-ConversionState $f
Reject-Scope {Invoke-ConversionApply $f.Workspace $members[0].Pom -Participantes $incomplete} 'associacao explicita|Source nao associado' 'A cadeia A|B e B|C exige associacao de C, mesmo ao converter A.'
Assert ((Get-ConversionState $f) -ceq $before) 'Associacao incompleta nao altera cobertura.'
foreach ($i in @(2,1,0)) { Assert ((Invoke-ConversionApply $f.Workspace $members[$i].Pom -Participantes $participants).Status -ceq 'EQUIVALENTE') ('Reaplicacao equivalente de '+$members[$i].Name) }
Assert ((Get-ConversionState $f) -ceq $before) 'Reaplicacao de todos os escopos conserva bytes e datas.'
foreach ($original in $originals) { Assert ((Get-FileHash -LiteralPath $original.Path).Hash -ceq $original.Hash) 'Origem legada preservada em toda a conversao.' }
'PASS: universo comum A|B/B|C, plano parceiro, dono unico decrescente, dependencias e reaplicacao.'
