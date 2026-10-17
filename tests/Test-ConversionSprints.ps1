#requires -Version 5.1
$ErrorActionPreference='Stop'; Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'ConversionFixture.ps1')
Import-Module (Join-Path $root 'tools/transicao/ConversaoPublicacao.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $root 'scripts/HarnessProject.psm1') -DisableNameChecking
Import-Module (Join-Path $root 'scripts/HarnessSprintPlanning.psm1') -DisableNameChecking
Import-Module (Join-Path $root 'tools/transicao/ConversaoValidacao.psm1') -DisableNameChecking
function Copy-SprintValue($Value) { $Value|ConvertTo-Json -Depth 60|ConvertFrom-Json }
function Save-SprintValue([string]$Path,$Value) { Write-ConversionFile $Path ($Value|ConvertTo-Json -Depth 60) }
function Get-TestSprintHash($Value) {
    $sha=[Security.Cryptography.SHA256]::Create()
    try { [BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes(($Value|ConvertTo-Json -Depth 60 -Compress)))).Replace('-','') } finally { $sha.Dispose() }
}
function Reject-SprintConversion([scriptblock]$Action,[string]$Pattern,[string]$Message) {
    try { $null=& $Action } catch { Assert ($_.Exception.Message -match $Pattern) ($Message+' Erro inesperado: '+$_.Exception.Message); return }
    throw $Message
}
function New-TestSprintWork([string]$Id,[string]$Phase,$Dependencies,$Issues,[int]$Dev,[int]$Architect,[int]$DevOps,[string]$Reference) {
    @{Id=$Id;Title=('Entrega '+$Id);Phase=$Phase;Priority=1;DependsOn=$Dependencies;Issues=$Issues;Effort=@{Dev=@{Min=$Dev;Reference=$Dev;Max=$Dev};Architect=@{Min=$Architect;Reference=$Architect;Max=$Architect};DevOps=@{Min=$DevOps;Reference=$DevOps;Max=$DevOps}};EstimateSource='Estimativa humana legada';Confidence='alta';Assumptions=@('Pessoas distintas');NotBefore=$null;Deadline=$null;Acceptance='Contrato funcional conferido';References=@($Reference);Remaining=$true;AllocationMode='ASAP';AiAssisted=$false}
}
# Formato de 7134833. A fixture escreve o historico; nao usa New-HarnessSprintContext.
function Add-LegacySprintRevision($Fixture,$Projects,$Data,[string]$RevisionId,$Previous=$null,[switch]$Validated) {
    $planningId='d'*32
    $directory=Join-Path $Fixture.Workspace ('.harness/sprints/'+$planningId+'/revisoes/'+$RevisionId)
    $data=Copy-SprintValue $Data; $data.PlanningId=$planningId; $data.RevisionId=$RevisionId
    $receipt=[ordered]@{SchemaVersion=1;Purpose='sprint-planning';PlanningId=$planningId;RevisionId=$RevisionId;PreparedAtUtc='2026-10-05T09:00:00Z';SelectionMode='SUBSET';Projects=$Projects;References=@();InputFingerprint='fixture';Previous=$null;Reason='Preservar premissas humanas';ContextPath=(Join-Path $directory 'contexto.json');PromptPath=(Join-Path $directory 'planejar-sprints.prompt.md');ReviewPromptPath=(Join-Path $directory 'revisar-sprints.prompt.md');SprintDataPath=(Join-Path $directory 'planejamento-sprints.json');SprintPlanPath=(Join-Path $directory 'planejamento-sprints.md');ValidationPath=(Join-Path $directory 'validacao.json');WorkTemplate=$data.Work[0];StaffingTemplate=$data.Team.Staffing[0];HistoricalIssues=@($data.Changes.New);InputChanges=@();Reused=$false}
    if ($Previous) {
        $parent=$Previous.Receipt
        $receipt.Previous=@{PlanningId=$parent.PlanningId;RevisionId=$parent.RevisionId;ContextPath=$parent.ContextPath;SprintPlanPath=$parent.SprintPlanPath;SprintDataPath=$parent.SprintDataPath;DataSha256=(Get-FileHash -LiteralPath $parent.SprintDataPath).Hash;PlanSha256=(Get-FileHash -LiteralPath $parent.SprintPlanPath).Hash}
    }
    $block="<!-- sprints:inicio -->`nCalculo legado preservado.`n<!-- sprints:fim -->"
    $links=@($Projects | ForEach-Object { '[Registro '+$_.Project+'](<'+$_.MigrationPath+'>)' }) -join "`n"
    Write-ConversionFile $receipt.SprintPlanPath ("# Plano legado`nNarrativa humana: manter janela e dependencias.`n$links`n$block`nGO e aceite humano locais pendentes.")
    Write-ConversionFile $receipt.PromptPath '# Orientacao capturada de planejamento'
    Write-ConversionFile $receipt.ReviewPromptPath '# Orientacao capturada de revisao'
    Save-SprintValue $receipt.SprintDataPath $data
    Save-SprintValue $receipt.ContextPath $receipt
    Save-SprintValue (Join-Path $directory 'preparo.json') @{ContextSha256=(Get-FileHash -LiteralPath $receipt.ContextPath).Hash;CalculatedBlockSha256=(Get-TestSprintHash $block);ReviewPromptSha256=(Get-FileHash -LiteralPath $receipt.ReviewPromptPath).Hash}
    $validation=$null
    if ($Validated) {
        # O produtor sela o rascunho e depois substitui o bloco ao validar.
        # PlanSha256 comprova este novo texto; o hash de preparo fica historico.
        $validatedBlock=$block.Replace('Calculo legado preservado.',('Calculo validado da revisao '+$RevisionId+'.'))
        Write-ConversionFile $receipt.SprintPlanPath ([IO.File]::ReadAllText($receipt.SprintPlanPath).Replace($block,$validatedBlock))
        $validation=@{SchemaVersion=1;Purpose='sprint-planning-validation';PlanningId=$planningId;RevisionId=$RevisionId;Status='VALIDATED';Feasibility=$data.Simulation.Feasibility;CheckedAtUtc='2026-10-05T10:00:00Z';DataSha256=(Get-FileHash -LiteralPath $receipt.SprintDataPath).Hash;PlanSha256=(Get-FileHash -LiteralPath $receipt.SprintPlanPath).Hash;ContextSha256=(Get-FileHash -LiteralPath $receipt.ContextPath).Hash;Diagnostics=@($data.Simulation.Diagnostics);DataSnapshot=$data;SprintPlanPath=$receipt.SprintPlanPath;ContextPath=$receipt.ContextPath;BaselineFrozen=$true;ReviewPromptPath=$receipt.ReviewPromptPath}
        Save-SprintValue $receipt.ValidationPath $validation
    }
    [pscustomobject]@{Receipt=[pscustomobject]$receipt;Data=$data;Validation=$validation}
}
$f=New-ConversionFixture
# O consumidor corrente referencia os contratos instalados no workspace ao recalcular.
foreach ($relative in @('.github/prompts/planejar-sprints.prompt.md','.github/prompts/revisar-sprints.prompt.md','doc/modelos/planejamento-sprints.template.md','doc/contratos/planejamento-sprints.md','doc/adr/0009-estado-corrente-por-projeto.md','doc/guias/tools/planejamento-sprints.md')) {
    Write-ConversionFile (Join-Path $f.Workspace $relative) ([IO.File]::ReadAllText((Join-Path $root $relative)))
}
Write-ConversionFile (Join-Path $f.Workspace '.harness/indices/projetos.md') '# Projetos da fixture'
$sourceB=Join-Path $f.Area 'backend'; $pomB=Join-Path $sourceB 'pom.xml'
Write-ConversionFile $pomB '<project><artifactId>backend</artifactId></project>'
$registerB=Join-Path $f.Workspace '.harness/projetos/backend__123456789abc/migracao.md'
Write-ConversionFile $registerB ([IO.File]::ReadAllText($f.Register).Replace($f.Source,$sourceB))
$newRow='| java::atual | Issue posterior a B0 | mandatory | 1 | PRESENTE | ADIAR | NAO ANALISADA | Inclusao posterior |'
Write-ConversionFile $f.Register ([IO.File]::ReadAllText($f.Register).Replace('<!-- mta:fim -->',($newRow+"`n<!-- mta:fim -->")))
$estimate=Join-Path $f.Area 'estimativa.md'; Write-ConversionFile $estimate '# Premissas de capacidade e calendario da fixture'
$base=@(@{Source=$f.Source;Id='java::regra'},@{Source=$sourceB;Id='java::regra'})
$new=@(@{Source=$f.Source;Id='java::historica';Reason='Inclusao historica';Evidence='Decisao anterior preservada'},@{Source=$f.Source;Id='java::atual';Reason='Achado posterior';Evidence='Registro atualizado'})
$data=[ordered]@{SchemaVersion=1;Purpose='sprint-planning';PlanningId=('d'*32);RevisionId=('a'*32);State='REVISADO';ScopeCategories=@('mandatory');ScopeDecision='Recorte confirmado no legado';Constraints=@{SprintStartDate='2026-10-05';ProductionDeadline='2026-11-27';ReferenceDate='2026-10-05';MaxPreparationSprints=2;MaxImplementationSprints=3;MaxTestSprints=2;MaxTotalSprints=4;MaxDevelopers=2;UnboundedPhases=@()};Team=@{RolesAreDistinct=$true;WorkWeek=@(1,2,3,4,5);Holidays=@('2026-10-12');Staffing=@(foreach ($n in 1..4) {@{Sprint=$n;Developers=2;DeveloperAvailability=0.75;ArchitectAvailability=1;DevOpsAvailability=1;ReservePercent=10;AbsenceDays=@{Dev=1;Architect=0;DevOps=0}}})};Baseline=@{Id='B0';Known=$true;Issues=$base;Accepted=@(@{Source=$f.Source;Id='java::regra';Evidence='Aceite historico';AcceptedBy='Revisor legado'})};Changes=@{New=$new;Reopened=@(@{Source=$f.Source;Id='java::regra';Reason='Reabertura humana';Evidence='Regressao registrada'});Excluded=@(@{Source=$f.Source;Id='java::historica';Reason='Saiu do escopo';Evidence='Decisao explicita'})};Work=@();Assumptions=@('Ambiente compartilhado disponivel');Decisions=@('Preservar janela de producao');EstimateEvidence=@(@{Path=$estimate;Kind='Estimativa';Status='DISPONIVEL';Sha256=(Get-FileHash -LiteralPath $estimate).Hash});EvidenceReview=@{Reviewed=$true;Reason='Premissas examinadas no legado'};Estimation=@{AiDeveloperReductionPercent=15};Simulation=$null}
$data.Work=@((New-TestSprintWork 'preparar' 'PREPARATION' @() @() 0 1 1 $estimate),(New-TestSprintWork 'migrar' 'IMPLEMENTATION' @('preparar') @($base+$new[1]) 4 0 0 $estimate),(New-TestSprintWork 'testar' 'TEST' @('migrar') $base 2 0 0 $estimate),(New-TestSprintWork 'implantar' 'DEPLOYMENT' @('testar') @() 0 0 1 $estimate))
$data.Constraints.SprintStartDate='2026-09-21'
$projects=@(foreach ($pair in @(@($f.Source,$f.Register,'apelido'),@($sourceB,$registerB,'legado-backend'))) { @{Project=$pair[2];Label=$pair[2];Source=$pair[0];MigrationPath=$pair[1];PlanningBasis='EVIDENCIAS';MtaOrigin=$null;MigrationSnapshot=[IO.File]::ReadAllText($pair[1]);Issues=@(@{Source=$pair[0];Id='java::regra';Category='mandatory'});Diagnostics=@();References=@();PlanningCandidates=@();PrioritizationCandidates=@();RegisterValid=$true} })
$initialProjects=Copy-SprintValue $projects
$initialProjects[0].MigrationSnapshot=$initialProjects[0].MigrationSnapshot.Replace($newRow+"`n",'')
$initialData=Copy-SprintValue $data; $initialData.Constraints.ReferenceDate='2026-09-21'
$initialData.Changes.New=@(); $initialData.Changes.Excluded=@(); $initialData.Work[1].Issues=Copy-SprintValue $base
$initialData.Simulation=Get-HarnessSprintSimulation $initialData
$initial=Add-LegacySprintRevision $f $initialProjects $initialData ('0'*32) -Validated
# Primeira inclusao validada: a issue historica ainda fazia parte do contexto.
$historyProjects=Copy-SprintValue $initialProjects
$historyProjects[0].Issues+=@([pscustomobject]@{Source=$f.Source;Id='java::historica';Category='mandatory'})
$historicalRow=$newRow.Replace('java::atual','java::historica').Replace('Issue posterior a B0','Inclusao historica')
$historyProjects[0].MigrationSnapshot=$historyProjects[0].MigrationSnapshot.Replace('<!-- mta:fim -->',($historicalRow+"`n<!-- mta:fim -->"))
$historyData=Copy-SprintValue $data; $historyData.Constraints.ReferenceDate='2026-09-28'
$historyData.Changes.New=@((Copy-SprintValue $new[0])); $historyData.Changes.Excluded=@(); $historyData.Work[1].Issues=Copy-SprintValue @($base+$new[0])
$historyData.Simulation=Get-HarnessSprintSimulation $historyData -PreviousSimulation $initial.Data.Simulation
$historical=Add-LegacySprintRevision $f $historyProjects $historyData ('1'*32) $initial -Validated
# A inclusao antiga sai do registro, permanece em Changes.New e recebe exclusao.
$projects[0].Issues+=@(@{Source=$f.Source;Id='java::atual';Category='mandatory'})
$data.Simulation=Get-HarnessSprintSimulation $data -PreviousSimulation $historical.Data.Simulation
Assert (@($data.Simulation.ConsumedPhaseSprints.IMPLEMENTATION).Count -gt 0) 'Fixture deve conter consumo de fase realmente calculado.'
$published=Add-LegacySprintRevision $f $projects $data ('a'*32) $historical -Validated
$draftData=Copy-SprintValue $data; $draftData.State='RASCUNHO'; $draftData.Simulation=$null
$draftData.Constraints.ReferenceDate='2026-10-19'; $draftData.Work[1].Effort.Dev.Reference=6; $draftData.Work[1].Effort.Dev.Max=6
$draft=Add-LegacySprintRevision $f $projects $draftData ('b'*32) $published
$orphanData=Copy-SprintValue $data; $orphanData.Constraints.ReferenceDate='2026-10-26'
$orphanData.Simulation=Get-HarnessSprintSimulation $orphanData -PreviousSimulation $historical.Data.Simulation
$orphan=Add-LegacySprintRevision $f $projects $orphanData ('c'*32) $historical -Validated
[IO.File]::SetLastWriteTimeUtc($orphan.Receipt.ValidationPath,[datetime]'2035-01-01T00:00:00Z')
$pointer=Join-Path $f.Workspace ('.harness/sprints/'+('d'*32)+'/atual.json')
Save-SprintValue $pointer @{PlanningId=$published.Receipt.PlanningId;RevisionId=$published.Receipt.RevisionId;ContextPath=$published.Receipt.ContextPath;ValidationPath=$published.Receipt.ValidationPath;ValidationSha256=(Get-FileHash -LiteralPath $published.Receipt.ValidationPath).Hash}
$participants=@{}; $participants[$f.Source]=$f.Pom; $participants[$sourceB]=$pomB
$choice=@{Contexto=$draft.Receipt.ContextPath;Cenario='macro';MestrePom=$pomB}
$before=Get-ConversionState $f
Reject-SprintConversion {Invoke-ConversionApply $f.Workspace $pomB -Participantes $participants -Sprints @(@{Contexto=$choice.Contexto;MestrePom=$pomB})} 'Cenario|nome' 'Cenario exige nome funcional explicito.'
Reject-SprintConversion {Invoke-ConversionApply $f.Workspace $pomB -Participantes $participants -Sprints @(@{Contexto=$choice.Contexto;Cenario='macro'})} 'Mestre|mestre' 'Cenario exige mestre explicito.'
Assert ((Get-ConversionState $f) -ceq $before) 'Escolhas incompletas nao publicam dados.'
$null=Invoke-ConversionApply $f.Workspace $f.Pom -Participantes $participants -Sprints @($choice)
$member=Get-HarnessProjectReference $f.Workspace $f.Pom; $master=Get-HarnessProjectReference $f.Workspace $pomB
Assert (-not (Test-Path -LiteralPath (Join-Path $member.Folder 'atual/sprints'))) 'Participante nao duplica o cenario mestre.'
$memberBefore=@(Get-ChildItem -LiteralPath $member.Folder -Recurse -File|ForEach-Object {$_.FullName+' '+(Get-FileHash -LiteralPath $_.FullName).Hash})-join "`n"
$result=Invoke-ConversionApply $f.Workspace $pomB -Participantes $participants -Sprints @($choice)
Assert (-not $result.AuthorizationInherited) 'Converter cronograma nao concede GO ou aceite.'
$memberAfter=@(Get-ChildItem -LiteralPath $member.Folder -Recurse -File|ForEach-Object {$_.FullName+' '+(Get-FileHash -LiteralPath $_.FullName).Hash})-join "`n"
Assert ($memberAfter -ceq $memberBefore) 'Mestre nao regrava arquivos do participante.'
$scenarioPath=Join-Path $master.Folder 'atual/sprints/macro/contexto.json'
$current=Read-HarnessSprintContext $f.Workspace $scenarioPath
$converted=Get-Content -LiteralPath $current.SprintDataPath -Raw|ConvertFrom-Json
$calculated=Get-Content -LiteralPath $current.ValidationPath -Raw|ConvertFrom-Json
Assert ($current.MasterProject -ceq 'backend' -and (@($current.Projects.Project|Sort-Object) -join '|') -ceq 'api|backend') 'Mestre e participantes usam identidades funcionais do POM.'
foreach ($project in $current.Projects) {
    $expected=if ($project.Project -ceq 'api') {$member} else {$master}
    Assert ($project.Pom -ieq $expected.Pom -and $project.Source -ieq $expected.Source -and $project.MigrationPath -ieq $expected.MigrationPath) 'Participantes apontam fontes funcionais atuais.'
}
Assert ($converted.Baseline.Issues.Count -eq 2 -and @($converted.Baseline.Issues|Where-Object Id -EQ 'java::atual').Count -eq 0) 'B0 historica nao pode ser reconstruida do registro atual.'
Assert ((@($converted.Changes.New.Id|Sort-Object) -join '|') -ceq 'java::atual|java::historica') 'Inclusoes historicas permanecem em Changes.New.'
Assert ($converted.Changes.Excluded[0].Reason -ceq 'Saiu do escopo' -and $converted.Changes.Reopened[0].Evidence -ceq 'Regressao registrada' -and $converted.Baseline.Accepted[0].AcceptedBy -ceq 'Revisor legado') 'Decisoes historicas permanecem como evidencias, sem novo aceite local.'
foreach ($field in @('Constraints','Team','Assumptions','Decisions','Estimation')) { Assert (($converted.$field|ConvertTo-Json -Depth 30 -Compress) -ceq ($draft.Data.$field|ConvertTo-Json -Depth 30 -Compress)) ('Premissa alterada: '+$field) }
for ($i=0;$i -lt $converted.Work.Count;$i++) {
    foreach ($field in @('Id','Title','Phase','Priority','DependsOn','Effort','EstimateSource','Confidence','Assumptions','NotBefore','Deadline','Acceptance','References','Remaining','AllocationMode','AiAssisted')) {
        Assert (($converted.Work[$i].$field|ConvertTo-Json -Depth 30 -Compress) -ceq ($draft.Data.Work[$i].$field|ConvertTo-Json -Depth 30 -Compress)) ('Atividade alterada: '+$field)
    }
}
Assert (-not $converted.PSObject.Properties['Simulation'] -and $converted.State -ceq 'RASCUNHO' -and -not $converted.EvidenceReview.Reviewed) 'Conversao separa resultado historico das premissas e exige revisao local.'
Assert ($calculated.Purpose -ceq 'current-sprint-result' -and $calculated.Status -ceq 'CONVERTED' -and $calculated.NeedsReview -eq $true -and $calculated.ReferenceDate -ceq '2026-10-05') 'Ultimo calculo deve vir do ponteiro comprovado, nao da revisao orfa mais recente, e exigir revisao local.'
Assert (($calculated.Simulation|ConvertTo-Json -Depth 60 -Compress) -ceq ($published.Data.Simulation|ConvertTo-Json -Depth 60 -Compress)) 'Simulation, sprints encerradas e ConsumedPhaseSprints devem permanecer integrais.'
Assert ($calculated.NewIssues.Count -eq 2 -and $calculated.Baseline.Issues.Count -eq 2) 'Resultado deve sustentar B0 e inclusoes historicas nas proximas revisoes.'
Assert ([IO.File]::ReadAllText($current.SprintPlanPath) -match 'Narrativa humana: manter janela e dependencias') 'Narrativa editorial preservada.'
Assert ([IO.File]::ReadAllText($current.SprintPlanPath) -notmatch 'apelido__123456789abc|backend__123456789abc') 'Links da narrativa deixam de depender dos registros legados.'
foreach ($path in @($current.ContextPath,$current.SprintDataPath,$current.ValidationPath)) { Assert ([IO.File]::ReadAllText($path) -notmatch '"PlanningId"|"RevisionId"|"ValidationSha256"|"DataSnapshot"') 'Consumidor corrente nao deve depender de recibos legados.' }
Assert (@(Get-HarnessSprintScenarios $f.Workspace).Count -eq 1) 'Apenas um mestre publica o cenario.'
$before=Get-ConversionState $f
Assert ((Invoke-ConversionApply $f.Workspace $pomB -Participantes $participants -Sprints @($choice)).Status -ceq 'EQUIVALENTE') 'Cenario reaplica sem recalcular nem regravar.'
Assert ((Get-ConversionState $f) -ceq $before) 'Reaplicacao conserva bytes e datas.'
Reject-SprintConversion {Invoke-ConversionApply $f.Workspace $pomB -Participantes $participants -Sprints @(@{Contexto=$orphan.Receipt.ContextPath;Cenario='macro';MestrePom=$pomB})} 'cadeia|ancestr|validacao|vincul|ponteiro' 'Contexto selecionado sem vinculo com o resultado corrente deve ser recusado.'
Assert ((Get-ConversionState $f) -ceq $before) 'Recusa de revisao orfa nao publica arquivos.'
foreach ($target in @($pointer,$published.Receipt.ValidationPath,$published.Receipt.SprintDataPath,$published.Receipt.ContextPath,$draft.Receipt.ContextPath,$draft.Receipt.SprintPlanPath)) {
    $original=[IO.File]::ReadAllText($target)
    [IO.File]::AppendAllText($target,' ')
    if ($target -ieq $pointer) { $changed=ConvertFrom-Json $original; $changed.ValidationSha256='0'*64; Save-SprintValue $target $changed }
    if ($target -ieq $draft.Receipt.SprintPlanPath) { Write-ConversionFile $target ($original.Replace('Calculo legado preservado.','Calculo adulterado.')) }
    try {
        $before=Get-ConversionState $f
        Reject-SprintConversion {Invoke-ConversionApply $f.Workspace $pomB -Participantes $participants -Sprints @($choice)} 'hash|ponteiro|validacao|diverg|alterad|preparo|calculado' 'Vinculo historico alterado nao pode escolher fallback por data.'
        Assert ((Get-ConversionState $f) -ceq $before) 'Recusa por proveniencia nao altera arquivos.'
    } finally { Write-ConversionFile $target $original }
}
$originalData=[IO.File]::ReadAllText($draft.Receipt.SprintDataPath)
$originalPlan=[IO.File]::ReadAllText($draft.Receipt.SprintPlanPath)
try {
    $artificial=Copy-SprintValue $draft.Data; $artificial.Simulation=Copy-SprintValue $published.Data.Simulation
    Save-SprintValue $draft.Receipt.SprintDataPath $artificial
    Write-ConversionFile $draft.Receipt.SprintPlanPath ($originalPlan.Replace('Calculo legado preservado.','Calculo adulterado com Simulation artificial.'))
    $before=Get-ConversionState $f
    Reject-SprintConversion {Invoke-ConversionApply $f.Workspace $pomB -Participantes $participants -Sprints @($choice)} 'Simulation|simula|selo|calculado|validacao|comprovad' 'Simulation artificial no rascunho nao dispensa o selo do bloco calculado.'
    Assert ((Get-ConversionState $f) -ceq $before) 'Resultado artificial nao altera os documentos correntes.'
} finally {
    Write-ConversionFile $draft.Receipt.SprintDataPath $originalData
    Write-ConversionFile $draft.Receipt.SprintPlanPath $originalPlan
}
# Consumidor corrente usa o resultado convertido para conservar B0 e inclusoes.
$before=Get-ConversionState $f
$integrity=Test-ConversionCurrent $f.Workspace $pomB
Assert $integrity.Valid ('Cenario convertido deve validar antes da retomada: '+($integrity.Diagnostics|ConvertTo-Json -Compress))
Assert ((Get-ConversionState $f) -ceq $before) 'Validacao do cenario convertido conserva bytes e datas.'
$completed=Complete-HarnessSprintPlan $f.Workspace $current.ContextPath
Assert ($completed.Status -ceq 'VALIDATED' -and $completed.Baseline.Issues.Count -eq 2 -and $completed.NewIssues.Count -eq 2) 'Planejamento convertido deve continuar calculavel sem reconstruir o historico.'
Assert ($completed.ReferenceDate -ceq '2026-10-19' -and @($completed.Simulation.ConsumedPhaseSprints.IMPLEMENTATION).Count -gt 0) 'Novo calculo usa as premissas escolhidas e preserva consumo de fases.'
Assert ($completed.Feasibility -ceq 'NAO_AVALIAVEL' -and ($completed.Diagnostics -join ' ') -match 'EvidenceReview') 'Conversao nao dispensa revisao local das fontes ao recalcular.'
$before=Get-ConversionState $f
$integrity=Test-ConversionCurrent $f.Workspace $pomB
Assert (-not $integrity.Valid -and ($integrity.Diagnostics|ConvertTo-Json -Compress) -match 'atual.+planejamento.+plano.md') 'Retomada deve manter pendente a referencia ao plano de aplicacao ainda ausente.'
Assert ((Get-ConversionState $f) -ceq $before) 'Validar ausencia nao cria plano/contexto ficticio.'

# Um rascunho sem atual.json nao inventa resultado; a associacao pode relocar Source.
$g=New-ConversionFixture
$relocatedSource=Join-Path $g.Area 'relocado'; $relocatedPom=Join-Path $relocatedSource 'pom.xml'
Write-ConversionFile $relocatedPom '<project><artifactId>api</artifactId></project>'
Write-ConversionFile (Join-Path $g.Source 'src/App.java') 'class App {}'
Write-ConversionFile (Join-Path $relocatedSource 'src/App.java') 'class App {}'
$draftDirectory=Join-Path $g.Workspace ('.harness/sprints/'+('d'*32)+'/revisoes/'+('e'*32))
$internalEstimate=Join-Path $draftDirectory 'estimativa.md'; $binary=Join-Path $draftDirectory 'capacidade.bin'
Write-ConversionFile $internalEstimate ('# Premissa de capacidade'+"`n"+'[Medicao](capacidade.bin)'+"`n"+'[Codigo](<'+(Join-Path $g.Source 'src/App.java')+'>)')
[IO.File]::WriteAllBytes($binary,[byte[]]@(0,1,127,128,255))
$onlyIssues=@(@{Source=$g.Source;Id='java::regra'})
$onlyData=Copy-SprintValue $initialData
$onlyData.State='RASCUNHO'; $onlyData.Simulation=$null; $onlyData.Baseline.Issues=$onlyIssues
$onlyData.Baseline.Accepted=@(); $onlyData.Changes.Reopened=@()
foreach ($work in $onlyData.Work) {
    if ($work.Issues.Count) { $work.Issues=Copy-SprintValue $onlyIssues }
    $work.References=@($internalEstimate)
}
$onlyData.EstimateEvidence=@(@{Path=$internalEstimate;Kind='Estimativa';Status='DISPONIVEL';Sha256=(Get-FileHash -LiteralPath $internalEstimate).Hash})
$onlyProjects=@(@{Project='apelido';Label='apelido';Source=$g.Source;MigrationPath=$g.Register;PlanningBasis='EVIDENCIAS';MtaOrigin=$null;MigrationSnapshot=[IO.File]::ReadAllText($g.Register);Issues=@(@{Source=$g.Source;Id='java::regra';Category='mandatory'});Diagnostics=@();References=@();PlanningCandidates=@();PrioritizationCandidates=@();RegisterValid=$true})
$only=Add-LegacySprintRevision $g $onlyProjects $onlyData ('e'*32)
Write-ConversionFile $only.Receipt.SprintPlanPath ([IO.File]::ReadAllText($only.Receipt.SprintPlanPath)+"`n"+'[Estimativa](<'+$internalEstimate+'>)')
$onlyParticipants=@{}; $onlyParticipants[$g.Source]=$relocatedPom
$onlyChoice=@{Contexto=$only.Receipt.ContextPath;Cenario='rascunho';MestrePom=$relocatedPom}
$null=Invoke-ConversionApply $g.Workspace $relocatedPom -SourceLegado $g.Source -Participantes $onlyParticipants -Sprints @($onlyChoice)
$onlyProject=Get-HarnessProjectReference $g.Workspace $relocatedPom
$onlyCurrent=Read-HarnessSprintContext $g.Workspace (Join-Path $onlyProject.Folder 'atual/sprints/rascunho/contexto.json')
$onlyConverted=Get-Content -LiteralPath $onlyCurrent.SprintDataPath -Raw|ConvertFrom-Json
Assert (-not (Test-Path -LiteralPath $onlyCurrent.ValidationPath)) 'Rascunho sem ponteiro comprovado nao produz resultado ficticio.'
Assert ($onlyCurrent.Projects[0].Source -ieq $relocatedSource -and $onlyConverted.Baseline.Issues[0].Source -ieq $relocatedSource -and $onlyConverted.Baseline.Issues[0].Project -ceq 'api') 'Source e identidade funcional sao associados ao codigo local.'
foreach ($work in $onlyConverted.Work) { foreach ($issue in $work.Issues) { Assert ($issue.Source -ieq $relocatedSource -and $issue.Project -ceq 'api') 'Work.Issues usa a associacao explicita de Source.' } }
$convertedEstimate=Join-Path $onlyProject.Folder 'evidencias/sprints/rascunho/estimativa.md'
$convertedBinary=Join-Path $onlyProject.Folder 'evidencias/sprints/rascunho/capacidade.bin'
Assert ($onlyConverted.Work[0].References[0] -ieq $convertedEstimate -and (Test-Path -LiteralPath $convertedEstimate)) 'Estimativa interna ganha destino funcional e Work.References aponta a copia.'
Assert ((Get-FileHash -LiteralPath $convertedBinary).Hash -ceq (Get-FileHash -LiteralPath $binary).Hash) 'Anexo binario transitivo conserva os bytes.'
Assert ([IO.File]::ReadAllText($convertedEstimate) -match 'relocado' -and [IO.File]::ReadAllText($convertedEstimate) -notmatch [regex]::Escape($g.Source)) 'Link de codigo na estimativa acompanha o Source local.'
$before=Get-ConversionState $g
Assert ((Invoke-ConversionApply $g.Workspace $relocatedPom -SourceLegado $g.Source -Participantes $onlyParticipants -Sprints @($onlyChoice)).Status -ceq 'EQUIVALENTE') 'Rascunho relocado e seus anexos reaplicam equivalentemente.'
Assert ((Get-ConversionState $g) -ceq $before) 'Reaplicacao de rascunho conserva arquivos e datas.'
'PASS: cenario mestre, historico comprovado, retomada corrente, rascunho relocado e anexos de estimativa.'
