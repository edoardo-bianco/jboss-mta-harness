#requires -Version 5.1
$ErrorActionPreference='Stop'; Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'ConversionFixture.ps1')
Import-Module (Join-Path $root 'tools/transicao/ConversaoPublicacao.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $root 'scripts/HarnessProject.psm1') -DisableNameChecking
$conversion=Get-Module ConversaoPublicacao
function Reject-Participant([scriptblock]$Action,[string]$Pattern,[string]$Message) {
    try { $null=& $Action } catch { Assert ($_.Exception.Message -match $Pattern) ($Message+' Erro inesperado: '+$_.Exception.Message); return }
    throw $Message
}
function Add-ParticipantMta([string]$Path,[string]$Artifact,[string]$Label) {
    Write-ConversionFile (Join-Path $Path 'index.html') ('<html>MTA '+$Label+'</html>')
    $apps=@(@{artifactId=$Artifact;rulesets=@(@{name='java';violations=@{$Label=@{description=$Label;category='mandatory';incidents=@()}}})})
    Write-ConversionFile (Join-Path $Path 'output.js') ('window["apps"] = '+(ConvertTo-Json -InputObject $apps -Depth 12 -Compress)+';')
    Write-ConversionFile (Join-Path $Path 'asset.txt') ('Asset exclusivo '+$Label)
}
function New-ParticipantMtaFixture([bool]$Internal=$false) {
    $f=New-ConversionFixture
    $sourceB=Join-Path $f.Area 'aplicacao b'; $pomB=Join-Path $sourceB 'pom.xml'
    Write-ConversionFile $pomB '<project><artifactId>outro</artifactId></project>'
    $registerB=Join-Path $f.Workspace '.harness/projetos/outro__123456789abc/migracao.md'
    Write-ConversionFile $registerB ([IO.File]::ReadAllText($f.Register).Replace($f.Source,$sourceB))
    $base=if ($Internal) {Join-Path $f.Workspace '.harness/runs'} else {Join-Path $f.Area 'origens externas'}
    $originA=Join-Path $base 'a-declarado'; $originB=Join-Path $base 'b-declarado'
    $selectedA=Join-Path $base 'a-escolhido'; $selectedB=Join-Path $base 'b-escolhido'
    Add-ParticipantMta $originA 'api' 'a-declarado'; Add-ParticipantMta $originB 'outro' 'b-declarado'
    Add-ParticipantMta $selectedA 'api' 'a-escolhido'; Add-ParticipantMta $selectedB 'outro' 'b-escolhido'
    foreach ($pair in @(@($f.Register,$originA,$f.Source),@($registerB,$originB,$sourceB))) {
        $marker=@{Run=$pair[1];RunId=('d'*32);Source=$pair[2]}|ConvertTo-Json -Compress
        [IO.File]::AppendAllText($pair[0],("`n<!-- MTA "+$marker+" -->`n"))
    }
    $f|Add-Member SourceB $sourceB; $f|Add-Member PomB $pomB; $f|Add-Member RegisterB $registerB
    $f|Add-Member OriginA $originA; $f|Add-Member OriginB $originB; $f|Add-Member SelectedA $selectedA; $f|Add-Member SelectedB $selectedB
    $f
}
function Get-ParticipantPreparedState($Fixture,[string]$Pom,$Participants) {
    & $conversion {
        param($Fixture,$Pom,$Participants)
        $entries=@(Get-ConversionParticipants $Fixture.Workspace $Pom $null $Participants)
        $options=@($entries | Where-Object { $_.Project.Pom -ieq $Pom })[0].Options
        $inputs=Read-ConversionInputs $Fixture.Workspace $Pom -Registro $options.Registro -Contexto $options.Contexto
        New-ConversionCoreFiles $inputs $options.MtaDiretorio @() $null $null $null $entries
    } $Fixture $Pom $Participants
}
$f=New-ParticipantMtaFixture $true
$shared=$f.SelectedA
$apps=@(@{rulesets=@(@{name='java';violations=@{compartilhada=@{description='Mesmo relatorio sem artifactId';category='mandatory';incidents=@()}}})})
Write-ConversionFile (Join-Path $shared 'output.js') ('window["apps"] = '+(ConvertTo-Json -InputObject $apps -Depth 12 -Compress)+';')
$participants=@{}
$participants[$f.Source]=@{Pom=$f.Pom;MtaDiretorio=$shared}
$participants[$f.SourceB]=@{Pom=$f.PomB;MtaDiretorio=$shared}
$before=Get-ConversionState $f
Reject-Participant {Invoke-ConversionApply $f.Workspace $f.Pom -Participantes $participants} 'destin|conflit' 'Mesma origem MTA interna nao pode ganhar destinos de dois participantes por sobrescrita do mapa.'
Assert ((Get-ConversionState $f) -ceq $before) 'Conflito de destinos para a mesma origem preserva fontes e impede publicacao.'

$f=New-ParticipantMtaFixture
foreach ($name in @('Registro','Contexto','MtaDiretorio')) {
    $first=@{Pom=$f.PomB}; $first[$name]=Join-Path $f.Area 'escolha-a'
    $second=@{Pom=$f.PomB}; $second[$name]=Join-Path $f.Area 'escolha-b'
    $aliases=@{}; $aliases[$f.SourceB]=$first; $aliases[$f.SourceB+'\.']=$second
    Reject-Participant {
        & $conversion { param($Fixture,$Aliases) Get-ConversionParticipants $Fixture.Workspace $Fixture.Pom $null $Aliases } $f $aliases
    } 'conflit' ('Aliases do mesmo Source com '+$name+' divergente nao podem depender da ordem do dicionario.')
}
$aliases=@{}; $aliases[$f.SourceB]=@{Pom=$f.PomB;Registro=$f.RegisterB}
$selectedContext=Join-Path $f.Area 'contexto-escolhido.json'
$aliases[$f.SourceB+'\.']=@{Pom=$f.PomB;Contexto=$selectedContext;Registro=(Join-Path (Split-Path $f.RegisterB -Parent) './migracao.md')}
$entries=@(& $conversion { param($Fixture,$Aliases) Get-ConversionParticipants $Fixture.Workspace $Fixture.Pom $null $Aliases } $f $aliases)
$options=@($entries | Where-Object LegacySource -IEQ $f.SourceB)[0].Options
Assert ($entries.Count -eq 2 -and [IO.Path]::GetFullPath($options.Registro) -ieq $f.RegisterB -and [IO.Path]::GetFullPath($options.Contexto) -ieq $selectedContext) 'Aliases equivalentes mesclam apenas opcoes ausentes, preservando escolhas normalizadas.'
foreach ($internal in @($false,$true)) {
    $f=New-ParticipantMtaFixture $internal
    $participants=@{}; $participants[$f.Source]=$f.Pom; $participants[$f.SourceB]=$f.PomB
    $before=Get-ConversionState $f
    $state=Get-ParticipantPreparedState $f $f.Pom $participants
    Assert ($state.ParticipantMta[$f.Source].Issues[0].Id -ceq 'java::a-declarado' -and $state.ParticipantMta[$f.SourceB].Issues[0].Id -ceq 'java::b-declarado') 'Participantes em formato string usam cada origem declarada, sem misturar projetos.'
    $projectB=Get-HarnessProjectReference $f.Workspace $f.PomB
    $peer=$state.ParticipantMtaStates[0]
    Assert ($peer.Files.Count -eq 0 -and $peer.Bytes.Count -eq 0 -and -not (Test-Path -LiteralPath $projectB.Folder)) 'Calcular fonte do parceiro nao publica nem copia seus assets.'
    $expectedReport=if ($internal) {Join-Path $projectB.Folder 'atual/diagnosticos/mta/index.html'} else {Join-Path $f.OriginB 'index.html'}
    Assert ($peer.Mta.ReportPath -ieq $expectedReport) 'Referencia do parceiro interno antecipa o destino funcional; externo conserva origem direta.'
    Assert ((Get-ConversionState $f) -ceq $before) 'Preparo em memoria preserva todas as fontes e destinos.'
    $participants[$f.Source]=@{Pom=$f.Pom;Registro=$f.Register;MtaDiretorio=$f.SelectedA}
    $participants[$f.SourceB]=@{Pom=$f.PomB;Registro=$f.RegisterB;MtaDiretorio=$f.SelectedB}
    $state=Get-ParticipantPreparedState $f $f.Pom $participants
    Assert ($state.Mta.Issues[0].Id -ceq 'java::a-escolhido' -and $state.ParticipantMta[$f.SourceB].Issues[0].Id -ceq 'java::b-escolhido') 'Overrides explicitos devem prevalecer separadamente para alvo e parceiro.'
    Reject-Participant {Invoke-ConversionApply $f.Workspace $f.Pom -Participantes $participants -MtaDiretorio $f.OriginA} 'Escolhas conflitantes.*MtaDiretorio' 'Override do alvo conflitante nao pode ser ignorado.'
    Assert ((Get-ConversionState $f) -ceq $before) 'Conflito de escolhas nao publica arquivos.'
    $null=Invoke-ConversionApply $f.Workspace $f.Pom -Participantes $participants
    Assert (-not (Test-Path -LiteralPath $projectB.Folder)) 'Aplicar alvo nao publica o parceiro.'
    $null=Invoke-ConversionApply $f.Workspace $f.PomB -Participantes $participants
    $projectA=Get-HarnessProjectReference $f.Workspace $f.Pom
    Assert ((Read-HarnessProjectMta $projectA).Issues[0].Id -ceq 'java::a-escolhido' -and (Read-HarnessProjectMta $projectB).Issues[0].Id -ceq 'java::b-escolhido') 'Publicacao individual dos dois projetos conserva os overrides.'
    if ($internal) {
        Assert ([IO.File]::ReadAllText((Join-Path $projectA.Folder 'atual/diagnosticos/mta/asset.txt')) -ceq 'Asset exclusivo a-escolhido') 'Alvo interno copia somente seu asset.'
        Assert ([IO.File]::ReadAllText((Join-Path $projectB.Folder 'atual/diagnosticos/mta/asset.txt')) -ceq 'Asset exclusivo b-escolhido') 'Parceiro copia seu asset apenas na propria publicacao.'
    } else {
        Assert (-not (Test-Path -LiteralPath (Join-Path $projectA.Folder 'atual/diagnosticos/mta')) -and -not (Test-Path -LiteralPath (Join-Path $projectB.Folder 'atual/diagnosticos/mta'))) 'MTA externo nao deve ser duplicado nos participantes.'
    }
    $before=Get-ConversionState $f
    Assert ((Invoke-ConversionApply $f.Workspace $f.Pom -Participantes $participants).Status -ceq 'EQUIVALENTE') 'Reaplicacao respeita a fonte previamente calculada do parceiro.'
    Assert ((Get-ConversionState $f) -ceq $before) 'Reaplicacao equivalente nao regrava nenhum projeto.'
    if ($internal) {
        $participants[$f.SourceB].MtaDiretorio=$f.OriginB
        try { Reject-Participant {Invoke-ConversionApply $f.Workspace $f.Pom -Participantes $participants} 'participante' 'Parceiro publicado com outro conjunto interno nao pode passar apenas porque ambos configuram diretorio null.' }
        finally { $participants[$f.SourceB].MtaDiretorio=$f.SelectedB }
        Assert ((Get-ConversionState $f) -ceq $before) 'Conjunto interno divergente preserva o diagnostico publicado do parceiro.'
    }
    $config=Get-Content -LiteralPath $projectB.ConfigPath -Raw|ConvertFrom-Json
    $config.mta.diretorio=$f.OriginB
    Write-ConversionFile $projectB.ConfigPath ($config|ConvertTo-Json -Depth 6)
    $before=Get-ConversionState $f
    Reject-Participant {Invoke-ConversionApply $f.Workspace $f.Pom -Participantes $participants} 'Origem MTA do participante diverge' 'Origem configurada divergente nao pode substituir a escolha calculada.'
    Assert ((Get-ConversionState $f) -ceq $before) 'Divergencia de configuracao preserva ambos os projetos.'
}

$f=New-ParticipantMtaFixture
$participants=@{}; $participants[$f.SourceB]=$f.PomB
$otherRegister=Join-Path $f.Workspace '.harness/projetos/outro-registro/migracao.md'
Write-ConversionFile $otherRegister ([IO.File]::ReadAllText($f.RegisterB))
[IO.File]::SetLastWriteTimeUtc($otherRegister,[datetime]'2035-01-01T00:00:00Z')
$before=Get-ConversionState $f
Reject-Participant {Invoke-ConversionApply $f.Workspace $f.Pom -Participantes $participants} 'registro unico para o participante' 'Registro mais recente nao resolve ambiguidade do parceiro.'
Assert ((Get-ConversionState $f) -ceq $before) 'Ambiguidade de registro nao publica.'
$participants[$f.SourceB]=@{Pom=$f.PomB;Registro=$f.RegisterB}
$state=Get-ParticipantPreparedState $f $f.Pom $participants
Assert ($state.ParticipantMtaStates[0].Inputs.Register.Path -ieq $f.RegisterB) 'Escolha explicita de registro resolve a ambiguidade sem usar mtime.'

$f=New-ParticipantMtaFixture
$partnerFixture=[pscustomobject]@{Workspace=$f.Workspace;Source=$f.SourceB;Register=$f.RegisterB}
$planA=Add-ConversionPlan $partnerFixture ('a'*32) -ProjectFolder 'outro'
$planB=Add-ConversionPlan $partnerFixture ('b'*32) -ProjectFolder 'outro'
[IO.File]::SetLastWriteTimeUtc($planB.ContextPath,[datetime]'2035-01-01T00:00:00Z')
$participants=@{}; $participants[$f.SourceB]=$f.PomB
$before=Get-ConversionState $f
Reject-Participant {Invoke-ConversionApply $f.Workspace $f.Pom -Participantes $participants} 'Plano do participante ambiguo' 'Plano mais recente nao resolve ambiguidade do parceiro.'
Assert ((Get-ConversionState $f) -ceq $before) 'Ambiguidade de plano nao publica.'
$participants[$f.SourceB]=@{Pom=$f.PomB;Registro=$f.RegisterB;Contexto=$planA.ContextPath}
$state=Get-ParticipantPreparedState $f $f.Pom $participants
Assert ($state.ParticipantMtaStates[0].Inputs.Planning.ContextPath -ieq $planA.ContextPath) 'Contexto explicito preserva a proposta escolhida mesmo com outro plano mais recente.'
Reject-Participant {Invoke-ConversionApply $f.Workspace $f.PomB -Participantes $participants -Contexto $planB.ContextPath} 'Escolhas conflitantes.*Contexto' 'Contextos conflitantes do alvo exigem escolha consistente.'

$f=New-ParticipantMtaFixture
$participants=@{}; $participants[$f.SourceB]=$f.PomB
& $conversion {
    param($Origin)
    $script:originalParticipantBuilder=${function:New-ConversionCoreFiles}; $script:participantMutationOrigin=$Origin
    Set-Item function:script:New-ConversionCoreFiles {
        param($Inputs,$Mta,$Priority,$Build,$Sonar,$Attempt,$Participants)
        $state=& $script:originalParticipantBuilder $Inputs $Mta $Priority $Build $Sonar $Attempt $Participants
        $next=Join-Path $script:participantMutationOrigin 'nova-coleta'
        $null=[IO.Directory]::CreateDirectory($next)
        foreach ($name in @('index.html','output.js')) {
            [IO.File]::WriteAllText((Join-Path $next $name),[IO.File]::ReadAllText((Join-Path $script:participantMutationOrigin $name)))
        }
        $state
    }
} $f.OriginB
try { Reject-Participant {Invoke-ConversionApply $f.Workspace $f.Pom -Participantes $participants} 'Conjunto MTA participante mudou' 'Nova coleta do parceiro durante o preparo deve impedir publicacao.' }
finally { & $conversion { Set-Item function:script:New-ConversionCoreFiles $script:originalParticipantBuilder } }
$projectA=Get-HarnessProjectReference $f.Workspace $f.Pom; $projectB=Get-HarnessProjectReference $f.Workspace $f.PomB
Assert (-not (Test-Path -LiteralPath $projectA.Folder) -and -not (Test-Path -LiteralPath $projectB.Folder)) 'Concorrencia no MTA do parceiro nao publica nenhum dos projetos.'
Assert (Test-Path -LiteralPath (Join-Path $f.OriginB 'nova-coleta/index.html')) 'Nova coleta concorrente deve permanecer intacta.'
'PASS: fontes MTA por participante, overrides, referencias sem assets, ambiguidades e concorrencia.'
