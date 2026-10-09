#requires -Version 5.1
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $root 'scripts/Harness.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $root 'scripts/HarnessPlanning.psm1') -Force -DisableNameChecking
function Assert($condition,$message) { if (-not $condition) { throw $message } }
function Reject($action,$message) { $failed=$false; try { & $action | Out-Null } catch { $failed=$true }; Assert $failed $message }
$area=Join-Path $root ('.harness/tests/pkg'+[guid]::NewGuid().ToString('N').Substring(0,8))
$a=Join-Path $area 'origem'; $b=Join-Path $area 'colega novo'
function Fixture($directory) {
    $app=$directory+'-codigo'
    $null=[IO.Directory]::CreateDirectory($app)
    Set-Content (Join-Path $app 'pom.xml') '<project><artifactId>servico</artifactId></project>'
    foreach ($file in @('doc/especificacoes/planejamento-copilot.md','.github/prompts/planejar-lotes.prompt.md','.github/prompts/implementar-lote.prompt.md','.github/prompts/revisar-resultado.prompt.md','doc/modelos/indice-priorizacao.template.md')) {
        $dest=Join-Path $directory $file; $null=[IO.Directory]::CreateDirectory((Split-Path $dest -Parent)); Copy-Item (Join-Path $root $file) $dest
    }
    $project=[pscustomobject]@{name='servico';label='Servico';path=$app}
    [pscustomobject]@{Root=$directory;Active=$project;Projects=@($project);Config=$null;ConfigPath=$null;WorkspacePath=$null}
}
$ca=Fixture $a; $cb=Fixture $b
Set-Content (Join-Path $cb.Active.path 'pom.xml') '<project><artifactId>servico-local</artifactId></project>'
$reg=Initialize-HarnessMigration $a $ca.Active
$text=[IO.File]::ReadAllText($reg.MigrationPath)
$row='| DEV-LOG | Corrigir log | manual | - | MANUAL | ANALISAR AGORA | NAO ANALISADA | |'
[IO.File]::WriteAllText($reg.MigrationPath,$text.Replace('Total MTA:',"$row`nTotal MTA:"))
$prepared=Invoke-HarnessRegisteredPlanning $ca -MigrationPath $reg.MigrationPath
$receipt=Get-Content $prepared.ContextPath -Raw | ConvertFrom-Json
Set-Content $receipt.PlanPath "# Plano`nLote: LOG-1`nGO humano: PENDENTE`n[Contexto](<$($receipt.ContextPath)>)"
Set-Content $receipt.TodoPath '# To-do: LOG-1'
$before=(Get-FileHash $receipt.ContextPath).Hash
Import-Module (Join-Path $root 'scripts/HarnessTransfer.psm1') -Force -DisableNameChecking
$zip=Join-Path $area 'plano.zip'
$exported=Export-HarnessContextPackage -Context $ca -ContextPath $receipt.ContextPath -PackagePath $zip
$manifest=Read-HarnessContextPackage $zip
Assert ($manifest.SchemaVersion -eq 1 -and $manifest.Kind -eq 'PLANEJAMENTO') 'Tipo/versao do pacote incorretos.'
Assert ($manifest.Files.Count -ge 5 -and (Test-Path $zip)) 'Pacote nao fecha os documentos/evidencias.'
Assert ((Get-FileHash $receipt.ContextPath).Hash -eq $before) 'Exportacao alterou origem.'
Reject { Export-HarnessContextPackage -Context $ca -ContextPath $receipt.ContextPath -PackagePath $zip } 'Exportacao sobrescreveu pacote existente.'
Write-Host 'PASS: exportacao de plano consolidado, manifesto e preservacao da origem.'
$map=@{}; $map[$receipt.Source]=$cb.Active.path
function RewritePackage($source,$target,$change) {
    Copy-Item $source $target
    $zipFile=[IO.Compression.ZipFile]::Open($target,[IO.Compression.ZipArchiveMode]::Update)
    try {
        $reader=[IO.StreamReader]::new($zipFile.GetEntry('manifest.json').Open())
        try { $metadata=$reader.ReadToEnd() | ConvertFrom-Json } finally { $reader.Dispose() }
        & $change $metadata $zipFile
        $zipFile.GetEntry('manifest.json').Delete()
        $writer=[IO.StreamWriter]::new($zipFile.CreateEntry('manifest.json').Open())
        try { $writer.Write(($metadata | ConvertTo-Json -Depth 60)) } finally { $writer.Dispose() }
    } finally { $zipFile.Dispose() }
}
function ChangePackageJson($metadata,$zipFile,$entry,$change) {
    $reader=[IO.StreamReader]::new($zipFile.GetEntry($entry).Open())
    try { $value=$reader.ReadToEnd() | ConvertFrom-Json } finally { $reader.Dispose() }
    & $change $value
    $bytes=[Text.Encoding]::UTF8.GetBytes(($value | ConvertTo-Json -Depth 60))
    $zipFile.GetEntry($entry).Delete(); $stream=$zipFile.CreateEntry($entry).Open()
    try { $stream.Write($bytes,0,$bytes.Length) } finally { $stream.Dispose() }
    $file=@($metadata.Files | Where-Object Entry -CEQ $entry)[0]
    $sha=[Security.Cryptography.SHA256]::Create()
    try { $file.Sha256=([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-','') } finally { $sha.Dispose() }
    $file.Length=$bytes.Length
}
$badRelative=Join-Path $area 'relative-path.zip'
RewritePackage $zip $badRelative { param($metadata,$zipFile)
    ChangePackageJson $metadata $zipFile $metadata.ContextEntry { param($value)
        $old=Join-Path (Split-Path $value.ContextPath -Parent) $value.Consolidated.Files[0].RelativePath
        $file=@($metadata.Files | Where-Object OriginPath -IEQ $old)[0]
        $file.OriginPath=Join-Path (Split-Path $value.ContextPath -Parent) '../fora.txt'
        $value.Consolidated.Files[0].RelativePath='../fora.txt'
    }
}
Reject { Import-HarnessContextPackage $cb $badRelative $map -Preview } 'RelativePath escapou da solicitacao.'
Reject { Import-HarnessContextPackage -Context $cb -PackagePath $zip -SourceMap @{} } 'Importacao adivinhou Source local.'
$preview=Import-HarnessContextPackage -Context $cb -PackagePath $zip -SourceMap $map -Preview
Assert ($preview.Status -eq 'READY' -and -not (Test-Path (Join-Path $b '.harness'))) 'Preview alterou estado local.'
$received=Import-HarnessContextPackage -Context $cb -PackagePath $zip -SourceMap $map
$local=Get-Content $received.ContextPath -Raw | ConvertFrom-Json
Assert ($local.Source.Replace('/','\') -eq $cb.Active.path -and $local.ImportedFrom.PackageId -eq $manifest.PackageId) 'Associacao/proveniencia local ausente.'
Assert ($local.RequestId -eq $receipt.RequestId -and (Test-Path $local.PlanPath)) 'Importacao perdeu identidade ou plano.'
$indexBody=[IO.File]::ReadAllText($local.EvidenceIndexPath)
foreach ($link in [regex]::Matches($indexBody,'\]\(<([^>]+)>\)')) {
    Assert (Test-Path (Resolve-HarnessPath $link.Groups[1].Value (Split-Path $local.EvidenceIndexPath -Parent))) 'Link consolidado quebrou com outro artifactId.'
}
Assert ((Get-FileHash $received.OriginalContextPath).Hash -eq $before) 'Original importado foi reescrito.'
$resume=Invoke-HarnessRegisteredPlanning $cb -ContextPath $local.ContextPath
Assert ($resume.Reused -and $resume.RequestId -eq $receipt.RequestId) 'Entrada habitual nao retomou plano recebido.'
$prompt=New-MtaImplementationPrompt $cb -RequestId $local.RequestId
Assert (Test-Path $prompt.PromptPath) 'Plano recebido nao prepara implementacao.'
Add-Content $local.PlanPath 'Nota local preservada na reimportacao.'
$changed=(Get-FileHash $local.PlanPath).Hash
$again=Import-HarnessContextPackage -Context $cb -PackagePath $zip -SourceMap $map
Assert ($again.Reused -and (Get-FileHash $local.PlanPath).Hash -eq $changed) 'Reimportacao sobrescreveu trabalho local.'
$localRegisterBefore=[IO.File]::ReadAllText($local.MigrationPath)
$otherOrigin=@{RunId=('f'*32);Run='Z:/outra-rodada';Source='Z:/outro';Project='outro'} | ConvertTo-Json -Compress
[IO.File]::WriteAllText($local.MigrationPath,$localRegisterBefore.Replace('<!-- mta:inicio -->',"<!-- mta:inicio -->`n<!-- MTA $otherOrigin -->"))
Reject { Invoke-HarnessRegisteredPlanning $cb -ContextPath $local.ContextPath } 'Mudanca de origem reutilizou proposta importada.'
[IO.File]::WriteAllText($local.MigrationPath,$localRegisterBefore)
$cc=Fixture (Join-Path $area 'conflito')
$null=Initialize-HarnessMigration $cc.Root $cc.Active
$conflictMap=@{}; $conflictMap[$receipt.Source]=$cc.Active.path
Reject { Import-HarnessContextPackage -Context $cc -PackagePath $zip -SourceMap $conflictMap } 'Registro local sobrescrito silenciosamente.'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$bad=Join-Path $area 'adulterado.zip'; Copy-Item $zip $bad
$archive=[IO.Compression.ZipFile]::Open($bad,[IO.Compression.ZipArchiveMode]::Update)
$entry=$archive.GetEntry($manifest.ContextEntry); $entry.Delete()
$writer=New-Object IO.StreamWriter($archive.CreateEntry($manifest.ContextEntry).Open()); $writer.Write('{}'); $writer.Dispose(); $archive.Dispose()
Reject { Read-HarnessContextPackage $bad } 'ZIP adulterado aceito.'
$traversal=Join-Path $area 'traversal.zip'; Copy-Item $zip $traversal
$archive=[IO.Compression.ZipFile]::Open($traversal,[IO.Compression.ZipArchiveMode]::Update)
$null=$archive.CreateEntry('../fora.txt'); $archive.Dispose()
Reject { Import-HarnessContextPackage -Context $cb -PackagePath $traversal -SourceMap $map } 'ZIP com traversal aceito.'
$future=Join-Path $area 'versao-futura.zip'
RewritePackage $zip $future { param($metadata,$zipFile) $metadata.SchemaVersion=999 }
Reject { Read-HarnessContextPackage $future } 'Versao desconhecida aceita.'
foreach ($case in @('absolute','duplicate','symlink')) {
    $unsafe=Join-Path $area ($case+'.zip'); Copy-Item $zip $unsafe
    $archive=[IO.Compression.ZipFile]::Open($unsafe,[IO.Compression.ZipArchiveMode]::Update)
    if ($case -eq 'absolute') { $null=$archive.CreateEntry('C:/fora.txt') }
    elseif ($case -eq 'duplicate') { $null=$archive.CreateEntry($manifest.ContextEntry.ToUpperInvariant()) }
    else { $archive.GetEntry($manifest.ContextEntry).ExternalAttributes=-1610612736 }
    $archive.Dispose()
    Reject { Read-HarnessContextPackage $unsafe } ('ZIP inseguro aceito: '+$case)
}
Write-Host 'PASS: importacao, retomada, idempotencia, conflitos e integridade.'
Import-Module (Join-Path $root 'scripts/HarnessPrioritization.psm1') -Force -DisableNameChecking
$cd=Fixture (Join-Path $area 'analise origem'); $ce=Fixture (Join-Path $area 'analise destino')
$secondA=Fixture (Join-Path $area 'segundo origem'); $secondB=Fixture (Join-Path $area 'segundo destino')
foreach ($ctx in @($secondA,$secondB)) { $ctx.Active.name='segundo'; $ctx.Active.label='Segundo'; Set-Content (Join-Path $ctx.Active.path 'pom.xml') '<project><artifactId>segundo-servico</artifactId></project>' }
$cd.Projects += $secondA.Active; $ce.Projects += $secondB.Active
foreach ($ctx in @($cd,$ce)) {
    $dest=Join-Path $ctx.Root '.github/prompts/priorizar-issues.prompt.md'
    Copy-Item (Join-Path $root '.github/prompts/priorizar-issues.prompt.md') $dest
}
$run=Join-Path $cd.Root 'diagnostico'; $runId=[guid]::NewGuid().ToString('N')
foreach ($dir in @('input','rules','output/static-report')) { $null=[IO.Directory]::CreateDirectory((Join-Path $run $dir)) }
Copy-Item (Join-Path $cd.Active.path 'pom.xml') (Join-Path $run 'input/pom.xml')
Set-Content (Join-Path $run 'output/output.yaml') '[]'; Set-Content (Join-Path $run 'output/dependencies.yaml') '[]'
Set-Content (Join-Path $run 'output/static-report/index.html') '<html></html>'
$violations=[ordered]@{}
foreach ($n in 1..4) { $violations['regra'+$n]=@{description='Issue optional';category='optional';incidents=@(@{uri='file:///src/App.java';lineNumber=1;message='Conferir'})} }
$catalog=ConvertTo-Json -InputObject @(@{id='app';rulesets=@(@{name='teste';violations=$violations})}) -Depth 20 -Compress
Set-Content (Join-Path $run 'output/static-report/output.js') ('window["apps"] = '+$catalog+';')
Write-HarnessJson (Join-Path $run 'manifest.json') @{RunId=$runId;Project='origem-mta';Source='Z:/origem-mta';CreatedAtUtc='2026-10-06T10:00:00Z'}
Write-HarnessJson (Join-Path $run 'result.json') @{RunId=$runId;Project='origem-mta';Status='SUCCEEDED';ExitCode=0;SourceUnchanged=$true;SnapshotOriginalFilesUnchanged=$true;RulesUnchanged=$true;UnexpectedAddedFiles=@()}
$selected=Get-MtaPlanningRunFromPath $run $cd.Root
$register=Update-HarnessMigration $cd $selected
$general=Get-HarnessMigrationPaths $cd.Root $cd.Active
Set-Content (Join-Path (Split-Path $general.EvidenceIndexPath -Parent) 'falha.log') 'Evidencia humana compartilhada'
Add-Content $general.EvidenceIndexPath '| falha.log | Log do projeto |'
$secondContext=[pscustomobject]@{Root=$cd.Root;Active=$secondA.Active}
$null=Update-HarnessMigration $secondContext $selected
Set-Content (Join-Path $cd.Root '.harness/projetos/indice-projetos.md') '# Indice local'
function CompletePackageSlice($prepared) {
    $record=Get-Content $prepared.ContextPath -Raw | ConvertFrom-Json
    $examined=@($record.AvailableIssues | Group-Object Source | ForEach-Object { $_.Group | Select-Object -First 1 } | Select-Object -First $record.SliceSize)
    $result=@{RequestId=$record.RequestId;Status='COMPLETED';AnalyzedIssues=$examined;ProposedIssues=@()} | ConvertTo-Json -Depth 8
    Set-Content $record.RankingPath ('<!-- priorizacao:resultado -->'+"`n"+'```json'+"`n$result`n"+'```'+"`n<!-- /priorizacao:resultado -->")
    foreach ($issue in $examined) {
        $ficha=@($record.FichaPaths | Where-Object { $_.Source -eq $issue.Source -and $_.Id -eq $issue.Id })[0]
        $null=[IO.Directory]::CreateDirectory((Split-Path $ficha.Path -Parent))
        Set-Content $ficha.Path ('# Ficha'+"`n<!-- issue: "+(@{Source=$issue.Source;Id=$issue.Id}|ConvertTo-Json -Compress)+' -->')
    }
}
$slice=New-HarnessPrioritizationContext $cd -Category optional -Percentage 25; CompletePackageSlice $slice
$slice2=New-HarnessPrioritizationContext $cd -Category optional -Percentage 25 -Mode Continue -PreviousRequestId $slice.RequestId; CompletePackageSlice $slice2
$analysisZip=Join-Path $area 'analise.zip'
$null=Export-HarnessContextPackage -Context $cd -ContextPath $slice2.ContextPath -PackagePath $analysisZip
$analysisManifest=Read-HarnessContextPackage $analysisZip
$sourceIndexHash=(Get-FileHash $slice2.PrioritizationIndexPath).Hash
Assert (-not @($analysisManifest.Files | Where-Object OriginPath -EQ $slice2.PrioritizationIndexPath).Count) 'Indice agregado da origem foi incluido no pacote da fatia.'
Assert ($analysisManifest.Kind -eq 'ANALISE' -and $analysisManifest.Receipts.Count -eq 2) 'Cadeia da analise truncada.'
$analysisMap=@{}; $analysisMap[$cd.Active.path]=$ce.Active.path
$analysisMap[$secondA.Active.path]=$secondB.Active.path
$unknownRole=Join-Path $area 'papel-invalido.zip'
RewritePackage $analysisZip $unknownRole { param($metadata,$zipFile) $metadata.Files[0].Role='OUTRO' }
Reject { Import-HarnessContextPackage $ce $unknownRole $analysisMap -Preview } 'Papel desconhecido aceito.'
$unowned=Join-Path $area 'arquivo-sem-vinculo.zip'
RewritePackage $analysisZip $unowned { param($metadata,$zipFile)
    $entry=@($metadata.Files | Where-Object Role -eq 'RANKING')[0]
    $entry.OriginPath=Join-Path $ce.Root '.harness/arquivo-sem-vinculo.md'
}
Reject { Import-HarnessContextPackage $ce $unowned $analysisMap -Preview } 'Arquivo sem vinculo poderia gravar fora do recibo.'
$badPrevious=Join-Path $area 'previous-ficha-alterada.zip'
RewritePackage $analysisZip $badPrevious { param($metadata,$zipFile)
    ChangePackageJson $metadata $zipFile $metadata.ContextEntry { param($value) $value.Previous.FichaHashes[0].Sha256='f'*64 }
}
Reject { Import-HarnessContextPackage $ce $badPrevious $analysisMap -Preview } 'Ficha Previous divergente foi reparada silenciosamente.'
$analysisImport=Import-HarnessContextPackage -Context $ce -PackagePath $analysisZip -SourceMap $analysisMap
$importedIndexContext=Get-Content $analysisImport.ContextPath -Raw -Encoding UTF8 | ConvertFrom-Json
Assert ($importedIndexContext.PrioritizationIndexPath -eq (Join-Path $ce.Root '.harness/priorizacao/indice-priorizacao.md')) 'Indice recebido nao aponta a raiz local.'
Assert ($importedIndexContext.PrioritizationIndexTemplatePath -eq (Join-Path $ce.Root 'doc/modelos/indice-priorizacao.template.md')) 'Template recebido nao aponta a raiz local.'
$next=New-HarnessPrioritizationContext $ce -Category optional -Percentage 25 -Mode Continue -PreviousRequestId $slice2.RequestId
Assert ((Get-FileHash $slice2.PrioritizationIndexPath).Hash -eq $sourceIndexHash) 'Continuidade recebida alterou o indice da origem.'
Assert ([IO.File]::ReadAllText($next.PrioritizationIndexPath) -match '4 de 8') 'Indice receptor nao incorporou a cobertura importada.'
$nextRecord=Get-Content $next.ContextPath -Raw | ConvertFrom-Json
Assert ($nextRecord.InitialTotal -eq 8 -and $nextRecord.ExcludedIssues.Count -eq 4 -and $nextRecord.AvailableIssues.Count -eq 4) 'Continuidade importada perdeu cobertura.'
Assert ($nextRecord.Projects[0].Mta.MtaOrigin.Source -eq 'Z:/origem-mta') 'Origem MTA foi atribuida ao receptor.'
Assert (Test-Path (Join-Path $nextRecord.Projects[0].Mta.Run 'rules')) 'Diretorio MTA vazio nao foi preservado.'
$localGeneral=Get-HarnessMigrationPaths $ce.Root $ce.Active
$evidenceIndexText=[IO.File]::ReadAllText($localGeneral.EvidenceIndexPath)
Assert ($evidenceIndexText.Contains('falha.log')) 'Anexo da analise nao chegou ao indice local.'
Write-Host 'PASS: pacote de analise optional e continuidade com cadeia Previous.'
$importedAnalysis=Get-Content $analysisImport.ContextPath -Raw | ConvertFrom-Json
$ficha=@($importedAnalysis.FichaPaths | Where-Object { $_.Source -eq $ce.Active.path -and (Test-Path $_.Path) })[0]
$localRegister=Get-HarnessMigrationPaths $ce.Root $ce.Active
$text=[IO.File]::ReadAllText($localRegister.MigrationPath)
$lines=@(foreach ($line in ($text -split '\r?\n')) {
    if ($line.StartsWith('| '+$ficha.Id+' |')) {
        $cells=@($line.Trim().Trim('|').Split('|') | ForEach-Object { $_.Trim() })
        $cells[5]='ANALISAR AGORA'; $cells[7]='[Ficha](<'+$ficha.Path+'>)'; '| '+($cells -join ' | ')+' |'
    } else { $line }
})
[IO.File]::WriteAllText($localRegister.MigrationPath,($lines -join "`n"))
$planned=Invoke-HarnessRegisteredPlanning $ce -MigrationPath $localRegister.MigrationPath
$mtaPlan=Get-Content $planned.ContextPath -Raw | ConvertFrom-Json
Assert ($mtaPlan.PlanningBasis -eq 'MTA' -and $mtaPlan.IssueId -eq $ficha.Id) 'Ficha recebida nao gera plano com origem preservada.'
Set-Content $mtaPlan.PlanPath '# Plano MTA'; Set-Content $mtaPlan.TodoPath '# To-do MTA'
$mtaZip=Join-Path $area 'plano-mta.zip'
$null=Export-HarnessContextPackage -Context $ce -ContextPath $mtaPlan.ContextPath -PackagePath $mtaZip
$cf=Fixture (Join-Path $area 'implementador')
$mtaMap=@{}; $mtaMap[$mtaPlan.Source]=$cf.Active.path
$mtaImport=Import-HarnessContextPackage -Context $cf -PackagePath $mtaZip -SourceMap $mtaMap
$mtaLocal=Get-Content $mtaImport.ContextPath -Raw | ConvertFrom-Json
$originalRun=[IO.Path]::GetFullPath($mtaPlan.Run); $away=[IO.Path]::GetFullPath((Join-Path $area 'diagnostico indisponivel'))
foreach ($candidate in @($originalRun,$away)) { Assert ($candidate.StartsWith(([IO.Path]::GetFullPath($area)+'\'),[StringComparison]::OrdinalIgnoreCase)) 'Movimento fora da fixture.' }
Move-Item -LiteralPath $originalRun -Destination $away
$resumed=Invoke-HarnessRegisteredPlanning $cf -ContextPath $mtaLocal.ContextPath
Assert $resumed.Reused 'Plano MTA importado exigiu origem indisponivel.'
$implemented=New-MtaImplementationPrompt $cf -RequestId $mtaLocal.RequestId
Assert (Test-Path $implemented.PromptPath) 'Implementacao importada exigiu MTA original.'
Add-Content $mtaLocal.ImportedInputIndexPath '| novo.txt | Nova evidencia |'
Set-Content (Join-Path (Split-Path $mtaLocal.ImportedInputIndexPath -Parent) 'novo.txt') 'Nova base'
Reject { Invoke-HarnessRegisteredPlanning $cf -ContextPath $mtaLocal.ContextPath } 'Plano importado com anexo novo reutilizado silenciosamente.'
Write-Host 'PASS: dois projetos, ficha recebida vira plano, implementacao sem MTA e nova evidencia detectada.'
$cliScripts=Join-Path $a 'scripts'; $null=[IO.Directory]::CreateDirectory($cliScripts)
Get-ChildItem (Join-Path $root 'scripts') -File | Copy-Item -Destination $cliScripts
$config=Get-Content (Join-Path $root 'config/harness.example.json') -Raw | ConvertFrom-Json
$config.repositories=@($ca.Active); $config.activeProject=$ca.Active.name; $config.mta.runsPath=$null
$configFile=Join-Path $a 'cli.json'; Write-HarnessJson $configFile $config
$cliZip=Join-Path $area 'cli.zip'
$out=& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $cliScripts 'compartilhar-contexto.ps1') -Action Export -ConfigPath $configFile -ContextPath $receipt.ContextPath -PackagePath $cliZip -OutputFormat Json 2>&1 | Out-String
Assert ($LASTEXITCODE -eq 0) ('CLI falhou: '+$out)
$response=$out | ConvertFrom-Json
Assert ($response.Kind -eq 'PLANEJAMENTO' -and (Test-Path $response.PackagePath)) 'CLI nao produziu resposta JSON/pacote.'
Write-Host 'PASS: CLI com escolhas explicitas e saida JSON.'
$cliReceiver=Fixture (Join-Path $area 'cli receptor')
$receiverScripts=Join-Path $cliReceiver.Root 'scripts'; $null=[IO.Directory]::CreateDirectory($receiverScripts)
Get-ChildItem (Join-Path $root 'scripts') -File | Copy-Item -Destination $receiverScripts
$config.repositories=@($cliReceiver.Active); $config.activeProject=$cliReceiver.Active.name
$receiverConfig=Join-Path $cliReceiver.Root 'cli.json'; Write-HarnessJson $receiverConfig $config
$sourceMapFile=Join-Path $area 'sources.json'; $cliMapping=@{}; $cliMapping[$receipt.Source]=$cliReceiver.Active.path
Write-HarnessJson $sourceMapFile $cliMapping
foreach ($previewFlag in @($true,$false)) {
    $args=@('-NoProfile','-ExecutionPolicy','Bypass','-File',(Join-Path $receiverScripts 'compartilhar-contexto.ps1'),'-Action','Import','-ConfigPath',$receiverConfig,'-PackagePath',$cliZip,'-SourceMapPath',$sourceMapFile,'-OutputFormat','Json')
    if ($previewFlag) { $args += '-Preview' }
    $out=& powershell.exe @args 2>&1 | Out-String
    Assert ($LASTEXITCODE -eq 0) ('CLI de importacao falhou: '+$out)
    $response=$out | ConvertFrom-Json
    Assert ($response.Status -eq $(if ($previewFlag) { 'READY' } else { 'IMPORTED' })) 'Resposta JSON de importacao incorreta.'
    if ($previewFlag) { Assert (-not (Test-Path (Join-Path $cliReceiver.Root '.harness'))) 'CLI preview inicializou registros.' }
}
Write-Host 'PASS: CLI de importacao, preview sem inicializacao e SourceMap explicito.'

# Nova revisao conserva a base anterior e reconstroi hashes Previous locais.
$cg=Fixture (Join-Path $area 'revisoes destino')
$issue=Get-HarnessIssuePaths $ca.Root $ca.Active 'DEV-LOG'
$null=[IO.Directory]::CreateDirectory((Split-Path $issue.EvidenceIndexPath -Parent))
Set-Content $issue.EvidenceIndexPath '| novo.log | Evidencia da revisao |'
Set-Content (Join-Path (Split-Path $issue.EvidenceIndexPath -Parent) 'novo.log') 'Novo erro'
$revision=Invoke-HarnessRegisteredPlanning $ca -ContextPath $receipt.ContextPath
$revised=Get-Content $revision.ContextPath -Raw | ConvertFrom-Json
Assert ($revised.Previous.RequestId -eq $receipt.RequestId) 'Fixture nao criou revisao.'
Set-Content $revised.PlanPath '# Plano revisado'; Set-Content $revised.TodoPath '# To-do revisado'
$revisionZip=Join-Path $area 'revisao.zip'
$null=Export-HarnessContextPackage $ca $revised.ContextPath $revisionZip
$revisionMap=@{}; $revisionMap[$receipt.Source]=$cg.Active.path
$revisionImport=Import-HarnessContextPackage $cg $revisionZip $revisionMap
$tip=Get-Content $revisionImport.ContextPath -Raw | ConvertFrom-Json
$ancestor=Get-Content $tip.Previous.ContextPath -Raw | ConvertFrom-Json
Assert (-not $ancestor.MigrationSnapshot.Contains('Proposta recebida;')) 'Historico recebeu registro atual.'
Assert (-not @($ancestor.SourceEvidenceInputs | Where-Object Path -like '*novo.log').Count) 'Historico recebeu evidencias da revisao.'
Assert (@($tip.SourceEvidenceInputs | Where-Object Path -like '*novo.log').Count -eq 1) 'Ponta perdeu evidencia editavel.'
Assert ($tip.Previous.ContextSha256 -eq (Get-FileHash $ancestor.ContextPath).Hash) 'Previous nao protege contexto local.'
Assert ((Invoke-HarnessRegisteredPlanning $cg -ContextPath $tip.ContextPath).Reused) 'Revisao recebida nao retoma.'

# Falha depois das copias deve remover somente o que a chamada criou e permitir repeticao.
$rollback=Fixture (Join-Path $area 'rollback')
$transfer=Get-Module HarnessTransfer
Reject { & $transfer { param($ctx)
    $base=Join-Path $ctx.Root '.harness/importacoes/teste'; $writes=@{}; $marker=Join-Path $base 'import.json'
    Add-TransferWrite $writes (Join-Path $base 'original/teste.txt') (Get-TransferBytes 'teste') $null
    Add-TransferWrite $writes $marker (Get-TransferBytes '{}') $null
    Write-TransferImport $ctx $null $null $base $writes @() $marker { throw 'Falha injetada antes da publicacao.' }
} $rollback } 'Falha injetada nao ocorreu.'
Assert (-not (Test-Path (Join-Path $rollback.Root '.harness/importacoes/teste'))) 'Rollback deixou base incompleta.'
$rollbackMap=@{}; $rollbackMap[$receipt.Source]=$rollback.Active.path
Assert ((Import-HarnessContextPackage $rollback $zip $rollbackMap).Status -eq 'IMPORTED') 'Importacao valida apos rollback falhou.'
Write-Host 'PASS: origem, caminhos/roles, revisoes independentes e rollback sem bloqueio de repeticao.'
