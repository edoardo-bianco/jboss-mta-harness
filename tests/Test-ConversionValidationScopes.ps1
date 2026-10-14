#requires -Version 5.1
$ErrorActionPreference='Stop'; Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'ConversionFixture.ps1')
Import-Module (Join-Path $root 'tools/transicao/ConversaoPublicacao.psm1') -DisableNameChecking
Import-Module (Join-Path $root 'tools/transicao/ConversaoValidacao.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $root 'scripts/HarnessProject.psm1') -DisableNameChecking
$f=New-ConversionFixture
$sourceB=Join-Path $f.Area 'backend'; $pomB=Join-Path $sourceB 'pom.xml'
Write-ConversionFile $pomB '<project><artifactId>backend</artifactId></project>'
$registerB=Join-Path $f.Workspace '.harness/projetos/backend__123456789abc/migracao.md'
Write-ConversionFile $registerB ([IO.File]::ReadAllText($f.Register).Replace($f.Source,$sourceB))
$null=Invoke-ConversionApply $f.Workspace $f.Pom
$null=Invoke-ConversionApply $f.Workspace $pomB
$a=Get-HarnessProjectReference $f.Workspace $f.Pom
$b=Get-HarnessProjectReference $f.Workspace $pomB
$validation=Get-Module ConversaoValidacao

# Um ContextPath adulterado deve falhar antes de entrar no leitor de terceiro.
$before=Get-ConversionState $f
$guard=& $validation {
    param($Project,$Other)
    $paths=Get-SprintPaths $Project 'macro'; $otherPaths=Get-SprintPaths $Other 'macro'
    $context=[pscustomobject]@{SchemaVersion=1;Purpose='current-sprint-planning';Scenario='macro';MasterProject=$Project.Name;Projects=@([pscustomobject]@{Project=$Project.Name;Source=$Project.Source;Pom=$Project.Pom;MigrationPath=$Project.MigrationPath});ContextPath=$otherPaths.ContextPath;SprintDataPath=$paths.SprintDataPath;SprintPlanPath=$paths.SprintPlanPath;ValidationPath=$paths.ValidationPath;PromptPath=$paths.PromptPath;ReviewPromptPath=$paths.ReviewPromptPath}
    $original=${function:Read-HarnessSprintContext}; $script:validationForeignRead=$false; $message=$null
    Set-Item function:script:Read-HarnessSprintContext { $script:validationForeignRead=$true; throw 'LEITURA_DE_TERCEIRO_PROIBIDA' }
    try { Assert-CurrentValidationSprint $Project $context @{} @{} }
    catch { $message=$_.Exception.Message }
    finally { Set-Item function:script:Read-HarnessSprintContext $original }
    [pscustomobject]@{ReadCalled=$script:validationForeignRead;Message=$message}
} $a $b
Assert (-not $guard.ReadCalled -and $guard.Message -match 'destino|ContextPath|identidade') 'Contexto de sprints fora do mestre deve ser recusado antes de qualquer leitura/recuperacao de terceiro.'
Assert ((Get-ConversionState $f) -ceq $before) 'Conferencia focal nao pode recuperar nem publicar arquivos.'

# Um escopo corrente parcial e legitimo ja associa explicitamente A e B.
$paths=& $validation { param($Project) Get-PrioritizationPaths $Project 'mandatory' 'par' } $a
$issues=@(@{Project=$a.Name;Id='java::regra'},@{Project=$b.Name;Id='java::regra'})
$data=[ordered]@{Purpose='current-prioritization';Scope='par';Category='mandatory';ContextPath=$paths.ContextPath;RankingPath=$paths.RankingPath;PromptPath=$paths.PromptPath;IndexPath=$paths.IndexPath;PrioritizationIndexPath=(Join-Path $f.Workspace '.harness/indices/priorizacao.md');Projects=@(foreach ($project in @($a,$b)) { @{Project=$project.Name;Label=$project.Name;Source=$project.Source;Pom=$project.Pom;MigrationPath=$project.MigrationPath;EvidencePath=$project.EvidencePath;Mta=$null;Diagnostics=@()} });Percentage='50';InitialTotal=2;SliceSize=1;BaselineIssues=$issues;ExcludedIssues=@();AvailableIssues=$issues;FichaPaths=@();OutsideBaseline=0;ContractPath=(Join-Path $root 'doc/adr/0009-estado-corrente-por-projeto.md')}
Write-ConversionFile $paths.ContextPath ($data|ConvertTo-Json -Depth 20)
$result=@{Category='mandatory';Scope='par';Status='IN_PROGRESS';AnalyzedIssues=@()}|ConvertTo-Json -Depth 10
Write-ConversionFile $paths.RankingPath ("# Priorizacao corrente`n<!-- priorizacao:resultado:inicio -->`n"+$result+"`n<!-- priorizacao:resultado:fim -->")
Write-ConversionFile $paths.PromptPath '# Orientacao corrente'
Write-ConversionFile $paths.IndexPath '# Indice do escopo'
$before=Get-ConversionState $f
$checked=Test-ConversionCurrent $f.Workspace $f.Pom
Assert $checked.Valid ('Fixture corrente integra deve validar: '+($checked.Diagnostics|ConvertTo-Json -Compress))
Assert ((Get-ConversionState $f) -ceq $before) 'Validar escopo corrente nao altera participantes.'

$alternatePom=Join-Path $f.Area 'outro-backend/pom.xml'
Write-ConversionFile $alternatePom '<project><artifactId>backend</artifactId></project>'
$original=[IO.File]::ReadAllText($b.ConfigPath)
try {
    $changed=ConvertFrom-Json $original; $changed.pom=$alternatePom
    Write-ConversionFile $b.ConfigPath ($changed|ConvertTo-Json -Depth 10)
    $before=Get-ConversionState $f
    $checked=Test-ConversionCurrent $f.Workspace $f.Pom
    Assert (-not $checked.Valid -and $checked.Status -ceq 'PENDENTE') 'Validar A deve detectar config de B apontando outro POM, mesmo artifactId.'
    Assert (($checked.Diagnostics|ConvertTo-Json -Depth 10) -match 'POM|associacao|participante|identidade') 'Pendencia deve indicar a associacao divergente do participante.'
    Assert ((Get-ConversionState $f) -ceq $before) 'Associacao divergente nao autoriza recuperar ou regravar participantes.'
} finally { Write-ConversionFile $b.ConfigPath $original }

$fichaRelative=& $validation { Get-PrioritizationFichaRelativePath 'mandatory' 'java::regra' }
$fichaB=Join-Path $b.Folder $fichaRelative
$annex=Join-Path $b.EvidencePath 'decisao.md'; Write-ConversionFile $annex '# Evidencia exclusiva da ficha B'
$identity=@{Project=$b.Name;Category='mandatory';Id='java::regra';LocalPaths=@();EvidencePaths=@('decisao.md')}|ConvertTo-Json -Depth 10
Write-ConversionFile $fichaB ("# Ficha examinada de B`n<!-- ficha:identidade:inicio -->`n"+$identity+"`n<!-- ficha:identidade:fim -->`n"+'[Evidencia](<'+$annex+'>)')
$result=@{Category='mandatory';Scope='par';Status='COMPLETED';AnalyzedIssues=@(@{Project=$b.Name;Id='java::regra';Position=1;Reason='Conferido com evidencia exclusiva'})}|ConvertTo-Json -Depth 10
Write-ConversionFile $paths.RankingPath ("# Priorizacao corrente`n<!-- priorizacao:resultado:inicio -->`n"+$result+"`n<!-- priorizacao:resultado:fim -->")
$checked=Test-ConversionCurrent $f.Workspace $f.Pom
Assert $checked.Valid ('Cobertura integra da ficha B deve validar: '+($checked.Diagnostics|ConvertTo-Json -Compress))
$annexOffline=Join-Path $f.Area 'decisao-fora.md'
Move-Item -LiteralPath $annex -Destination $annexOffline
try {
    $before=Get-ConversionState $f
    $checked=Test-ConversionCurrent $f.Workspace $f.Pom
    Assert (-not $checked.Valid -and ($checked.Diagnostics|ConvertTo-Json -Depth 10) -match 'ausente|decisao.md') 'Mestre deve detectar anexo exclusivo ausente na ficha examinada de B.'
    Assert ((Get-ConversionState $f) -ceq $before) 'Validar cobertura nao recria nem recupera o anexo do parceiro.'
} finally { Move-Item -LiteralPath $annexOffline -Destination $annex }

$contextOffline=Join-Path $f.Area 'priorizacao-contexto-fora.json'
Move-Item -LiteralPath $paths.ContextPath -Destination $contextOffline
try {
    $before=Get-ConversionState $f
    $checked=Test-ConversionCurrent $f.Workspace $f.Pom
    Assert (-not $checked.Valid -and ($checked.Diagnostics|ConvertTo-Json -Depth 10) -match 'contexto') 'Ranking orfao de contexto deve ficar pendente.'
    Assert ((Get-ConversionState $f) -ceq $before) 'Validar nao reconstrui contexto ausente.'
} finally { Move-Item -LiteralPath $contextOffline -Destination $paths.ContextPath }
Write-ConversionFile $a.PlanPath '# Plano humano sem contexto'
$before=Get-ConversionState $f
$checked=Test-ConversionCurrent $f.Workspace $f.Pom
Assert (-not $checked.Valid -and ($checked.Diagnostics|ConvertTo-Json -Depth 10) -match 'contexto') 'Plano orfao de contexto deve ficar pendente.'
Assert ((Get-ConversionState $f) -ceq $before) 'Plano humano orfao e preservado pela validacao.'
'PASS: destinos de sprints, associacao participante, anexo de ficha parceira e documentos orfaos.'
