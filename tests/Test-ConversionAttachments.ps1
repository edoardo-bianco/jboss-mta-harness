#requires -Version 5.1
$ErrorActionPreference='Stop'; Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'ConversionFixture.ps1')
Import-Module (Join-Path $root 'tools/transicao/ConversaoPrevia.psm1') -Force -DisableNameChecking
$f=New-ConversionFixture
# Um apelido livre 'source' nao pode desaparecer por filtro de nomes genericos.
$plan=Add-ConversionPlan $f ('a'*32) -ProjectFolder 'source'
$folder=Split-Path $plan.ContextPath -Parent
$attachment=Join-Path $folder 'evidencias/anexo.txt'
$original=Join-Path $f.Area 'recebido/anexo.txt'
$ficha=Join-Path $folder 'ficha-regra.md'
$index=Join-Path $folder 'evidencias/LEIA-ME.md'
$extract=Join-Path $folder 'evidencias/apontamentos-mta.json'
foreach ($path in @($attachment,$original,$ficha,$index,$extract)) { Write-ConversionFile $path 'Conteudo humano ou diagnostico a classificar.' }
$mta=Join-Path $f.Area 'mta externo'
Write-ConversionFile (Join-Path $mta 'index.html') '<html>MTA original</html>'
$plan|Add-Member -NotePropertyName FichaPath -NotePropertyValue $ficha
$plan|Add-Member -NotePropertyName EvidenceIndexPath -NotePropertyValue $index
$plan|Add-Member -NotePropertyName Run -NotePropertyValue $mta
$plan|Add-Member -NotePropertyName EvidenceInputs -NotePropertyValue @(@{Path=$attachment;OriginPath=$original;Relation='Anexo';Status='DISPONIVEL'})
$plan|Add-Member -NotePropertyName SourceEvidenceInputs -NotePropertyValue @(@{Path=$original;Reference=$original;Relation='Anexo';Status='DISPONIVEL'},@{Path=$null;Reference='https://example.invalid/evidencia';Status='REFERENCIA EXTERNA'})
$plan|Add-Member -NotePropertyName IssueInputs -NotePropertyValue @(@{Id='java::regra';Source=$f.Source;FichaPath=$ficha;FichaOrigin=$ficha;EvidenceIndexOrigin=$index})
$plan|Add-Member -NotePropertyName Consolidated -NotePropertyValue @{Files=@(@{RelativePath='evidencias/anexo.txt';OriginPath=$original},@{RelativePath='evidencias/apontamentos-mta.json';OriginPath=$null});MtaIssuePath=$extract}
Write-ConversionFile $plan.ContextPath ($plan|ConvertTo-Json -Depth 15)
[IO.File]::AppendAllText($f.Register,("`n[Plano](<"+$plan.PlanPath+">)`n"))
$oldFile=Join-Path $f.Source 'Classe.java'; Write-ConversionFile $oldFile 'class Classe {}'
Write-ConversionFile $plan.PlanPath ("# Plano`n[Fonte](<"+$oldFile+">)`n")
$newPom=Join-Path $f.Area 'checkout-novo/pom.xml'; Write-ConversionFile $newPom '<project><artifactId>api</artifactId></project>'
$before=Get-ConversionState $f
$preview=Get-ConversionPreview $f.Workspace $newPom -SourceLegado $f.Source
Assert ($preview.Planning.ContextPath -eq $plan.ContextPath) 'Apelido source deve ser inventariado.'
Assert (@($preview.Attachments|Where-Object Field -EQ 'Consolidated.Files').Count -eq 2) 'Anexos devem vir dos campos estruturados, sem depender de links Markdown.'
Assert (@($preview.Attachments|Where-Object Kind -EQ 'COPIA_DIAGNOSTICO_LEGADO').Count -ge 1) 'Copias diagnosticas nao devem ser confundidas com evidencia humana.'
Assert (@($preview.Attachments|Where-Object Kind -EQ 'ORIGEM_MTA').Count -eq 1 -and $mta -notin $preview.DiscardCandidates) 'Origem MTA externa deve permanecer referencia, fora do descarte.'
$sourceLink=@($preview.References|Where-Object Origin -EQ $oldFile)[0]
Assert ($sourceLink.Available -and -not $sourceLink.DestinationAvailable -and ($preview.Pending -join ' ') -match 'Fonte local remapeado indisponivel') 'Arquivo antigo existente nao comprova disponibilidade no checkout novo.'
Assert ((Get-ConversionState $f) -ceq $before) 'Anexos, fontes e MTA externo devem permanecer intactos.'
# RelativePath consolidado nao pode escapar da solicitacao.
$plan.Consolidated.Files+=@{RelativePath='../../fora.txt';OriginPath=$null}
Write-ConversionFile $plan.ContextPath ($plan|ConvertTo-Json -Depth 15)
$preview=Get-ConversionPreview $f.Workspace $f.Pom
Assert (($preview.Pending -join ' ') -match 'Copia consolidada fora da solicitacao') 'Escape de anexo deve ficar explicito.'
Write-Host 'PASS: anexos estruturados, extratos, Source relocalizado, origem MTA e limites.'
