#requires -Version 5.1
param([switch]$MtaDisponivel)
$ErrorActionPreference='Stop'; Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'ConversionFixture.ps1')
Import-Module (Join-Path $root 'tools/transicao/ConversaoPublicacao.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $root 'tools/transicao/ConversaoPrevia.psm1') -DisableNameChecking
Import-Module (Join-Path $root 'scripts/HarnessProject.psm1') -DisableNameChecking
$f=New-ConversionFixture
if ($MtaDisponivel) {
    $origin=Join-Path $f.Area 'mta externo'
    Write-ConversionFile (Join-Path $origin 'index.html') '<html>Relatorio sintetico</html>'
    $apps=@(@{artifactId='api';rulesets=@(@{name='java';violations=@{regra=@{description='Problema';category='mandatory';incidents=@()}}})})
    Write-ConversionFile (Join-Path $origin 'output.js') ('window["apps"] = '+(ConvertTo-Json -InputObject $apps -Depth 12 -Compress)+';')
    $marker=@{Run=$origin;RunId=('d'*32);Source=$f.Source}|ConvertTo-Json -Compress
    [IO.File]::AppendAllText($f.Register,("`n<!-- MTA "+$marker+" -->`n"))
}
$id='a'*32; $folder=Join-Path $f.Workspace ('.harness/priorizacao/'+$id)
$context=Join-Path $folder 'context.json'; $ranking=Join-Path $folder 'priorizacao.md'; $ficha=Join-Path $folder 'ficha.md'
$index=Join-Path $folder 'anexos/LEIA-ME.md'; $binary=Join-Path $folder 'anexos/ensaio.bin'
$note=Join-Path $folder 'observacao.md'; $external=Join-Path $f.Area 'externo.txt'
$prompt=Join-Path $folder 'priorizar-issues.prompt.md'; $incidentIndex=Join-Path $folder 'incidentes/indice.md'; $incidentPage=Join-Path $folder 'incidentes/issue-0001-p-0000.md'
Write-ConversionFile $prompt 'Prompt legado com RequestId, hashes e comandos antigos'
Write-ConversionFile $incidentIndex '# Incidentes: [Pagina](issue-0001-p-0000.md)'
Write-ConversionFile $incidentPage 'Extrato MTA gerado'
Write-ConversionFile $external 'Evidencia externa'
Write-ConversionFile $index '# Evidencias: [Ensaio](ensaio.bin)'
[IO.File]::WriteAllBytes($binary,[byte[]](255,0,127))
Write-ConversionFile $note '# Observacao exclusiva da ficha'
$identity=@{Source=$f.Source;Id='java::regra'}|ConvertTo-Json -Compress
Write-ConversionFile $ficha ("# Analise humana`n[Observacao](observacao.md)`n[Indice](anexos/LEIA-ME.md)`n<!-- issue: $identity -->")
$issue=@{Source=$f.Source;Id='java::regra'}
$record=@{Purpose='issue-prioritization';SchemaVersion=4;Category='mandatory';RequestId=$id;SequenceId=$id;Mode='Start';Previous=$null;Projects=@(@{Source=$f.Source});ContextPath=$context;RankingPath=$ranking;Percentage='100';InitialTotal=1;SliceSize=1;BaselineIssues=@($issue);ExcludedIssues=@();AvailableIssues=@($issue);FichaPaths=@(@{Source=$f.Source;Id=$issue.Id;Path=$ficha});EvidenceIndexPath=$index;EvidenceInputs=@(@{Path=$binary;Relation='Ensaio revisado'},@{Path=$external;Relation='Contrato externo'},@{Path=(Join-Path $folder 'ausente.txt');Relation='Confirmacao pendente'})}
$result=@{RequestId=$id;Status='COMPLETED';AnalyzedIssues=@($issue);ProposedIssues=@($issue)}|ConvertTo-Json -Depth 8
Write-ConversionFile $ranking ("# Ranking humano`n[Indice](anexos/LEIA-ME.md)`n| Prioridade | Projeto | Issue | Avaliacao | Motivo |`n| --- | --- | --- | --- | --- |`n| 1 | api | [Issue](ficha.md) | Conferida | Corrigir SPI |`n<!-- priorizacao:resultado -->`n"+'```json'+"`n"+$result+"`n"+'```'+"`n<!-- /priorizacao:resultado -->")
Write-ConversionFile $context ($record|ConvertTo-Json -Depth 12)
$record.PromptPath=$prompt
$record.Projects[0].Mta=@{IncidentEvidence=@{IndexPath=$incidentIndex;Files=@(@{Path=$incidentIndex},@{Path=$incidentPage})}}
$incidentCopy=Join-Path $folder 'copia-renomeada.md'
Write-ConversionFile $incidentCopy ([IO.File]::ReadAllText($incidentPage))
$record.EvidenceInputs+=@{Path=$incidentCopy;OriginPath=$incidentPage;Relation='Copia recebida do diagnostico'}
$record.EvidenceInputs+=@{Path='https://example.test/contrato';Relation='Contrato HTTP'}
Write-ConversionFile $context ($record|ConvertTo-Json -Depth 12)
Write-ConversionFile $ranking ([IO.File]::ReadAllText($ranking)+"`n[Orientacao](priorizar-issues.prompt.md)`n[Incidentes](incidentes/indice.md)`n[Copia do diagnostico](copia-renomeada.md)")
$original=[IO.File]::ReadAllText($ficha)
$preview=Get-ConversionPreview $f.Workspace $f.Pom
Assert (@($preview.Attachments | Where-Object ContextPath -EQ $context).Count -ge 4) 'Previa deve mostrar anexos declarados da priorizacao sem plano.'
$null=Invoke-ConversionApply $f.Workspace $f.Pom
$p=Get-HarnessProjectReference $f.Workspace $f.Pom
Assert (-not (Test-Path -LiteralPath $p.ContextPath)) 'Converter priorizacao nao fabrica plano.'
Assert (-not (Test-Path -LiteralPath (Join-Path $p.EvidencePath 'priorizar-issues.prompt.md'))) 'Prompt legado nao pode virar evidencia humana.'
Assert (-not (Test-Path -LiteralPath (Join-Path $p.EvidencePath 'indice.md')) -and -not (Test-Path -LiteralPath (Join-Path $p.EvidencePath 'issue-0001-p-0000.md'))) 'Extratos estruturados nao podem virar evidencia humana.'
Assert (-not (Test-Path -LiteralPath (Join-Path $p.EvidencePath 'copia-renomeada.md'))) 'Proveniencia de copia renomeada deve manter papel diagnostico.'
Assert ([Convert]::ToBase64String([IO.File]::ReadAllBytes((Join-Path $p.EvidencePath 'ensaio.bin'))) -ceq '/wB/') 'Anexo exclusivo deve preservar bytes.'
Assert ([IO.File]::ReadAllText((Join-Path $p.EvidencePath 'LEIA-ME.md')) -match '\[Ensaio\]\(<ensaio.bin>\)') 'Indice humano deve abrir anexo corrente.'
Assert ([IO.File]::ReadAllText((Join-Path $p.EvidencePath 'observacao.md')) -match 'Observacao exclusiva') 'Vizinho humano da ficha deve ser preservado.'
$data=Get-Content -LiteralPath (Join-Path $p.Folder 'atual/priorizacao/mandatory/escopos/api/contexto.json') -Raw|ConvertFrom-Json
$human=[IO.File]::ReadAllText($data.FichaPaths[0].Path)
Assert ($human -notmatch 'referencia legada indisponivel' -and $human -match '\[Observacao\]\(<[^>]+observacao.md>\)') 'Ficha deve abrir anexos correntes sem dependencia do contexto legado.'
$text=[IO.File]::ReadAllText($data.RankingPath)
Assert ($text -match 'Ensaio revisado' -and $text -match 'Contrato externo' -and $text -match 'Confirmacao pendente' -and $text -match 'AUSENTE') 'Relacoes, referencia externa e lacuna devem permanecer visiveis sem plano.'
Assert ($text -match '\[Contrato HTTP\]\(<https://example.test/contrato>\)') 'URL externa deve permanecer como link HTTP.'
Assert ($text -match '\[Orientacao\]\(<priorizar-issues.prompt.md>\)') 'Orientacao deve apontar ao prompt corrente.'
if ($MtaDisponivel) {
    Assert ($text -match '\[Incidentes\]\(<[^>]+index.html>\)' -and $text -match '\[Copia do diagnostico\]\(<[^>]+index.html>\)') 'Indice e copia de extrato devem abrir o relatorio na origem atual.'
} else { Assert ($text -match 'Incidentes \(referencia legada indisponivel') 'Origem diagnostica ausente deve ficar visivel, sem copiar o extrato.' }
Assert (-not (Test-Path -LiteralPath (Join-Path $p.EvidencePath 'externo.txt'))) 'Evidencia externa nao deve ser copiada.'
Assert ([IO.File]::ReadAllText($ficha) -ceq $original) 'Original deve permanecer intacto.'
$before=Get-ConversionState $f
$again=Invoke-ConversionApply $f.Workspace $f.Pom
Assert ($again.Status -eq 'EQUIVALENTE' -and (Get-ConversionState $f) -ceq $before) 'Reaplicacao nao modifica arquivos equivalentes.'
$other=($record|ConvertTo-Json -Depth 12)|ConvertFrom-Json
$other.RequestId='b'*32; $other.SequenceId=$other.RequestId
$other.ContextPath=Join-Path $f.Workspace ('.harness/priorizacao/'+$other.RequestId+'/context.json')
$other|Add-Member Consolidated @{Files=@(@{RelativePath='../../fora.txt'})}
Write-ConversionFile $other.ContextPath ($other|ConvertTo-Json -Depth 12)
$before=Get-ConversionState $f
$again=Invoke-ConversionApply $f.Workspace $f.Pom -PrioritizacaoContexto $context
Assert ($again.Status -eq 'EQUIVALENTE' -and (Get-ConversionState $f) -ceq $before) 'Anexo invalido de outra sequencia nao deve ser adotado nem bloquear a cadeia escolhida.'
'PASS: anexos exclusivos, vizinhos Markdown, lacunas e relacoes da priorizacao sem plano.'
