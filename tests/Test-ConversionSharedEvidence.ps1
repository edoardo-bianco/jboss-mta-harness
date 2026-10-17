#requires -Version 5.1
$ErrorActionPreference='Stop'; Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'ConversionFixture.ps1')
Import-Module (Join-Path $root 'tools/transicao/ConversaoPublicacao.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $root 'scripts/HarnessProject.psm1') -DisableNameChecking
$f=New-ConversionFixture
$sourceB=Join-Path $f.Area 'outra aplicacao'; $pomB=Join-Path $sourceB 'pom.xml'
Write-ConversionFile $pomB '<project><artifactId>outro</artifactId></project>'
$registerB=Join-Path $f.Workspace '.harness/projetos/outro__123456789abc/migracao.md'
Write-ConversionFile $registerB ([IO.File]::ReadAllText($f.Register).Replace($f.Source,$sourceB))
$participants=@{}; $participants[$f.Source]=$f.Pom; $participants[$sourceB]=$pomB
$folder=Join-Path $f.Workspace ('.harness/priorizacao/'+('a'*32))
$context=Join-Path $folder 'context.json'; $ranking=Join-Path $folder 'priorizacao.md'
$issues=@(@{Source=$f.Source;Id='java::regra'},@{Source=$sourceB;Id='java::regra'})
$fichas=@(); $projects=@()
for ($i=0;$i -lt 2;$i++) {
    $source=$issues[$i].Source; $name=if ($i) {'outro'} else {'api'}
    $origin=Join-Path $f.Area ('mta-'+$name)
    Write-ConversionFile (Join-Path $origin 'index.html') ('<html>MTA '+$name+'</html>')
    $apps=@(@{artifactId=$name;rulesets=@(@{name='java';violations=@{regra=@{description=$name;category='mandatory';incidents=@()}}})})
    Write-ConversionFile (Join-Path $origin 'output.js') ('window["apps"] = '+(ConvertTo-Json -InputObject $apps -Depth 12 -Compress)+';')
    $marker=@{Run=$origin;Source=$source}|ConvertTo-Json -Compress
    $register=if ($i) {$registerB} else {$f.Register}
    [IO.File]::AppendAllText($register,("`n<!-- MTA "+$marker+" -->`n"))
    $extract=Join-Path $folder ('incidentes-'+$i+'.md')
    Write-ConversionFile $extract ('Extrato gerado '+$i)
    $projects+=@{Source=$source;Mta=@{Run=$origin;IncidentEvidence=@{IndexPath=$extract;Files=@()}}}
    $path=Join-Path $folder ('ficha-'+$i+'.md'); $identity=$issues[$i]|ConvertTo-Json -Compress
    Write-ConversionFile $path ("# Ficha $i`nAnalise humana $i.`n[Proprio](projeto-$i/detalhe.md)`n[Compartilhado](anexos/compartilhado.md)`n[Diagnostico](incidentes-$i.md)`n<!-- issue: $identity -->")
    Write-ConversionFile (Join-Path $folder "projeto-$i/detalhe.md") ("# Anexo exclusivo $i")
    $fichas+=@{Source=$source;Id='java::regra';Path=$path}
}
Write-ConversionFile (Join-Path $folder 'anexos/compartilhado.md') '# Evidencia comum: [Bytes](ensaio.bin) [Ciclo](ciclo.md)'
Write-ConversionFile (Join-Path $folder 'anexos/ciclo.md') '# Referencia circular valida: [Comum](compartilhado.md)'
[IO.File]::WriteAllBytes((Join-Path $folder 'anexos/ensaio.bin'),[byte[]](10,0,255))
Write-ConversionFile (Join-Path $folder 'ranking/anexo.md') '# Anexo exclusivo do ranking'
$data=@{Purpose='issue-prioritization';SchemaVersion=4;Category='mandatory';RequestId=('a'*32);SequenceId=('a'*32);Mode='Start';Previous=$null;Projects=$projects;ContextPath=$context;RankingPath=$ranking;Percentage='100';InitialTotal=2;SliceSize=2;BaselineIssues=$issues;ExcludedIssues=@();AvailableIssues=$issues;FichaPaths=$fichas}
Write-ConversionFile $context ($data|ConvertTo-Json -Depth 15)
$result=@{RequestId=('a'*32);Status='COMPLETED';AnalyzedIssues=$issues;ProposedIssues=$issues}|ConvertTo-Json -Depth 8
Write-ConversionFile $ranking ("# Ranking humano`n[Anexo ranking](ranking/anexo.md)`n| 1 | api | [A](ficha-0.md) | Conferida | Motivo A |`n| 2 | outro | [B](ficha-1.md) | Conferida | Motivo B |`n<!-- priorizacao:resultado -->`n"+'```json'+"`n"+$result+"`n"+'```'+"`n<!-- /priorizacao:resultado -->")
$master=Get-HarnessProjectReference $f.Workspace $f.Pom; $other=Get-HarnessProjectReference $f.Workspace $pomB
$null=Invoke-ConversionApply $f.Workspace $pomB -Participantes $participants
Assert (-not (Test-Path -LiteralPath $master.Folder)) 'Participante nao escreve no mestre.'
Assert ([IO.File]::ReadAllText((Join-Path $other.EvidencePath 'detalhe.md')) -match 'exclusivo 1') 'Anexo exclusivo pertence ao projeto de sua ficha.'
Assert (Test-Path -LiteralPath (Join-Path $other.EvidencePath 'compartilhado.md')) 'Maior consumidor ordinal publica o anexo compartilhado primeiro.'
$relative='atual/priorizacao/mandatory/issues/'+(ConvertTo-HarnessFunctionalPath 'java::regra')+'/ficha.md'
$otherFicha=Join-Path $other.Folder $relative
$text=[IO.File]::ReadAllText($otherFicha)
Assert ($text -match 'evidencias/compartilhado.md' -and $text -notmatch 'referencia legada indisponivel') 'Ficha do parceiro aponta ao destino comum, mesmo antes da publicacao do mestre.'
Assert ($text -match 'mta-outro/index.html' -and $text -notmatch 'mta-api/index.html') 'Diagnostico da ficha usa somente o MTA de seu Source.'
$before=@(Get-ChildItem -LiteralPath $other.Folder -File -Recurse|ForEach-Object {$_.FullName+' '+(Get-FileHash -LiteralPath $_.FullName).Hash})-join "`n"
$required=Join-Path $other.EvidencePath 'detalhe.md'; $saved=[IO.File]::ReadAllText($required)
Assert ($required.StartsWith($f.Area+'\',[StringComparison]::OrdinalIgnoreCase)) 'Remocao restrita a fixture.'
[IO.File]::Delete($required)
Reject {Invoke-ConversionApply $f.Workspace $f.Pom -Participantes $participants} 'Mestre nao pode atestar ficha cujo anexo exclusivo do parceiro desapareceu.'
Write-ConversionFile $required $saved
$null=Invoke-ConversionApply $f.Workspace $f.Pom -Participantes $participants
$current=Get-Content -LiteralPath (Join-Path $master.Folder ('atual/priorizacao/mandatory/escopos/'+(ConvertTo-HarnessFunctionalPath 'api|outro')+'/contexto.json')) -Raw|ConvertFrom-Json
Assert (@($current.Projects|Where-Object {$_.Mta -and $_.Mta.ReportPath -match ('mta-'+$_.Project+'\\index.html$')}).Count -eq 2) 'Contexto global oferece a fonte MTA correta de cada participante.'
$after=@(Get-ChildItem -LiteralPath $other.Folder -File -Recurse|ForEach-Object {$_.FullName+' '+(Get-FileHash -LiteralPath $_.FullName).Hash})-join "`n"
Assert ($after -ceq $before) 'Mestre preserva integralmente os arquivos do parceiro.'
Assert ([IO.File]::ReadAllText((Join-Path $master.EvidencePath 'detalhe.md')) -match 'exclusivo 0') 'Mesmo nome em donos diferentes nao conflita.'
Assert ([IO.File]::ReadAllText((Join-Path $master.EvidencePath 'anexo.md')) -match 'exclusivo do ranking') 'Anexo exclusivo do ranking pertence ao mestre.'
Assert (-not (Test-Path -LiteralPath (Join-Path $master.EvidencePath 'compartilhado.md'))) 'Mestre nao duplica anexo compartilhado.'
Assert ([Convert]::ToBase64String([IO.File]::ReadAllBytes((Join-Path $other.EvidencePath 'ensaio.bin'))) -ceq 'CgD/') 'Dependencia transitiva compartilha o mesmo dono e conserva bytes.'
Assert ([IO.File]::ReadAllText((Join-Path $other.EvidencePath 'ciclo.md')) -match '\[Comum\]\(<compartilhado.md>\)') 'Ciclo Markdown nao perde links nem duplica arquivos.'
$snapshot=Get-ConversionState $f
Assert ((Invoke-ConversionApply $f.Workspace $pomB -Participantes $participants).Status -eq 'EQUIVALENTE') 'Parceiro reaplica de forma equivalente com mestre publicado.'
Assert ((Invoke-ConversionApply $f.Workspace $f.Pom -Participantes $participants).Status -eq 'EQUIVALENTE') 'Mestre reaplica sem duplicacao.'
Assert ((Get-ConversionState $f) -ceq $snapshot) 'Reaplicacao preserva bytes e datas.'
'PASS: anexos por proprietario, compartilhamento transitivo, ciclos, fontes MTA distintas e reaplicacao.'
