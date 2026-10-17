#requires -Version 5.1
$ErrorActionPreference='Stop'; Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'ConversionFixture.ps1')
Import-Module (Join-Path $root 'scripts/HarnessProject.psm1') -DisableNameChecking
Import-Module (Join-Path $root 'tools/transicao/ConversaoPublicacao.psm1') -DisableNameChecking
Import-Module (Join-Path $root 'tools/transicao/ConversaoValidacao.psm1') -DisableNameChecking
Import-Module (Join-Path $root 'tools/transicao/ConversaoLimpeza.psm1') -DisableNameChecking
function New-ConvertedCleanupFixture {
    $fixture=New-ConversionFixture
    $plan=Add-ConversionPlan $fixture ('a'*32)
    $evidence=Join-Path (Split-Path $plan.ContextPath -Parent) 'estimativa.md'
    $binary=Join-Path (Split-Path $plan.ContextPath -Parent) 'amostra.bin'
    Write-ConversionFile $evidence '# Estimativa humana com [amostra](<amostra.bin>)'
    [IO.File]::WriteAllBytes($binary,[byte[]]@(0,128,255,17))
    [IO.File]::AppendAllText($plan.PlanPath,("`n[Estimativa](<"+$evidence+">)`n"))
    [IO.File]::AppendAllText($fixture.Register,("`n[Plano](<"+$plan.PlanPath+">)`n"))
    $arguments=@{Workspace=$fixture.Workspace;Pom=$fixture.Pom;Registro=$fixture.Register;Contexto=$plan.ContextPath}
    $null=Invoke-ConversionApply @arguments
    $project=Get-HarnessProjectReference $fixture.Workspace $fixture.Pom
    $valid=Test-ConversionCurrent -Workspace $fixture.Workspace -Pom $fixture.Pom
    Assert $valid.Valid ('Fixture convertida deve ser operacional antes do descarte: '+($valid.Diagnostics -join '; '))
    $fixture|Add-Member NoteProperty Plan $plan
    $fixture|Add-Member NoteProperty Evidence $evidence
    $fixture|Add-Member NoteProperty Binary $binary
    $fixture|Add-Member NoteProperty Project $project
    $fixture|Add-Member NoteProperty Arguments $arguments
    $fixture
}
function Reject-ConversionCleanup($Fixture,[scriptblock]$Action,[string]$Pattern,[string]$Message) {
    $before=Get-ConversionState $Fixture; $failed=$false
    try { $null=& $Action } catch { Assert ($_.Exception.Message -match $Pattern) ($Message+' Erro inesperado: '+$_.Exception.Message); $failed=$true }
    Assert $failed $Message
    Assert ((Get-ConversionState $Fixture) -ceq $before) 'Recusa deve preservar origens, documentos correntes e temporarios, sem recibos ou mapas gravados.'
}
function Invoke-ConversionCleanupPromptMutation($Fixture,[string]$Mode) {
    $target=switch ($Mode) {
        'legacy' {$Fixture.Plan.PlanPath}
        'current' {$Fixture.Project.PlanPath}
        'new' {Join-Path (Split-Path $Fixture.Plan.PlanPath -Parent) 'nova-evidencia.md'}
        'new-other' {Join-Path $Fixture.Workspace '.harness/planning/outro/nota-durante-confirmacao.md'}
    }
    $null=[IO.Directory]::CreateDirectory((Split-Path $target -Parent))
    $module=Get-Module ConversaoLimpeza
    & $module {
        param($Fixture,$Target,$Snapshot)
        $script:cleanupFixture=$Fixture; $script:cleanupTarget=$Target; $script:cleanupSnapshot=$Snapshot; $script:cleanupAfterPrompt=$null
        function script:Read-Host {
            param([string]$Prompt)
            [IO.File]::AppendAllText($script:cleanupTarget,[Environment]::NewLine+'Nota humana durante confirmacao. [Origem](<'+$script:cleanupFixture.Evidence+'>)')
            $script:cleanupAfterPrompt=& $script:cleanupSnapshot $script:cleanupFixture
            'LIMPAR'
        }
    } $Fixture $target ${function:Get-ConversionState}
    $failed=$false; $arguments=$Fixture.Arguments
    try { $null=Invoke-ConversionCleanup @arguments -Descartar @($Fixture.Plan.PlanPath) 6>$null }
    catch { Assert ($_.Exception.Message -match 'alter|mud|equival|diverg|difer|conjunto|origem|corrente|nov|confirm') $_.Exception.Message; $failed=$true }
    finally { & $module { Remove-Item Function:\Read-Host } }
    Assert $failed ('Mudanca durante confirmacao deve impedir descarte: '+$Mode)
    $postPrompt=& $module { $script:cleanupAfterPrompt }
    Assert ($null -ne $postPrompt -and (Get-ConversionState $Fixture) -ceq $postPrompt) 'Descarte recusado deve preservar inclusive a contribuicao humana feita durante a confirmacao.'
}
$f=New-ConvertedCleanupFixture
$before=Get-ConversionState $f
$arguments=$f.Arguments
$preview=Get-ConversionCleanupPreview @arguments
Assert ($preview.Status -ceq 'PREVIA' -and -not $preview.DeletionAuthorized) 'Previa informa candidatos e nao autoriza descarte.'
$candidate=@($preview.Candidates|Where-Object Path -IEQ $f.Plan.PlanPath)
Assert ($candidate.Count -eq 1 -and $candidate[0].Eligible -and $candidate[0].Destination -ieq $f.Project.PlanPath) 'Plano legado convertido deve ter candidato elegivel e destino corrente explicito.'
Assert ((Get-ConversionState $f) -ceq $before) 'Previa de descarte nao grava mapa, recibo nem altera origens ou destinos.'
$selected=@($f.Register,$f.Plan.ContextPath,$f.Plan.PlanPath,$f.Plan.TodoPath,$f.Evidence,$f.Binary)
foreach ($path in $selected) {
    $candidate=@($preview.Candidates|Where-Object Path -IEQ $path)
    Assert ($candidate.Count -eq 1 -and $candidate[0].Eligible -and (Test-Path -LiteralPath $candidate[0].Destination -PathType Leaf)) ('Cada origem convertida precisa de destino corrente antes do descarte: '+$path)
}
$cancelled=Invoke-ConversionCleanup @arguments -Descartar $selected -ConfirmText cancelar 6>$null
Assert ($cancelled.Status -ceq 'CANCELADO') 'Confirmacao diferente de LIMPAR cancela explicitamente.'
Assert ((Get-ConversionState $f) -ceq $before) 'Cancelamento do descarte deve preservar bytes e datas, sem gravar temporarios.'
Reject-ConversionCleanup $f { Invoke-ConversionCleanup @arguments -ConfirmText LIMPAR 6>$null } 'sele|Descartar|arquivo|explic|vazi' 'Invocar descarte exige selecao explicita nao vazia.'

# Uma folha inelegivel impede retirar tambem as folhas elegiveis do mesmo pedido.
$unknown=Join-Path (Split-Path $f.Plan.PlanPath -Parent) 'desconhecido.txt'; Write-ConversionFile $unknown 'nao foi transformado'
$external=Join-Path $f.Area 'mta-externo/index.html'; Write-ConversionFile $external 'origem externa preservada'
$received=Join-Path $f.Project.Folder 'recebido/original.md'; Write-ConversionFile $received 'original recebido preservado'
$package=Join-Path $f.Workspace '.harness/importados/pacote-original.zip'; Write-ConversionFile $package 'pacote recebido preservado'
foreach ($path in @($unknown,$external,$received,$package,$f.Pom,$f.Project.PlanPath,(Split-Path $f.Plan.PlanPath -Parent),$f.Workspace)) {
    Reject-ConversionCleanup $f { Invoke-ConversionCleanup @arguments -Descartar @($f.Plan.PlanPath,$path) -ConfirmText LIMPAR 6>$null } 'eleg|convert|destin|origem|Source|fonte|extern|desconhec|arquivo|diretor|corrente|receb|pacote|autoriz|sele|legad|famil' ('Selecao deve recusar origem protegida, desconhecida ou diretorio: '+$path)
}

# Equivalencia e integridade sao verificadas novamente, sem substituir edicoes humanas.
foreach ($mode in @('legacy','current','invalid')) {
    $changed=New-ConvertedCleanupFixture; $arguments=$changed.Arguments
    if ($mode -eq 'legacy') { [IO.File]::AppendAllText($changed.Plan.PlanPath,"`nNota humana nova na origem.") }
    elseif ($mode -eq 'current') { [IO.File]::AppendAllText($changed.Project.PlanPath,"`nNota humana posterior no corrente.") }
    else { [IO.File]::AppendAllText($changed.Project.PlanPath,"`n[Referencia pendente](<ausente.md>)") }
    Reject-ConversionCleanup $changed { Invoke-ConversionCleanup @arguments -Descartar @($changed.Plan.PlanPath) -ConfirmText LIMPAR 6>$null } 'equival|alter|diverg|corrente|valid|penden|refer|origem|convers' ('Descarte nao pode aceitar origem ou destino alterado: '+$mode)
}
foreach ($mode in @('legacy','current','new','new-other')) { $changed=New-ConvertedCleanupFixture; Invoke-ConversionCleanupPromptMutation $changed $mode }

# Uma nota recebida durante a segunda verificacao tambem antecede a barreira final.
$late=New-ConvertedCleanupFixture; $arguments=$late.Arguments; $module=Get-Module ConversaoLimpeza
& $module {
    param($Fixture,$Snapshot)
    $script:cleanupVerifyOriginal=(Get-Command Invoke-ConversionApply).ScriptBlock
    $script:cleanupVerifyCalls=0; $script:cleanupLateFixture=$Fixture; $script:cleanupLateSnapshot=$Snapshot; $script:cleanupLateState=$null
    function script:Invoke-ConversionApply {
        param([string]$Workspace,[string]$Pom,[string]$Registro,[string]$Contexto,[switch]$VerifyOnly)
        $result=ConversaoPublicacao\Invoke-ConversionApply @PSBoundParameters
        $script:cleanupVerifyCalls++
        if ($script:cleanupVerifyCalls -eq 2) {
            $path=Join-Path $script:cleanupLateFixture.Project.Folder 'recebido/nota.md'
            $null=[IO.Directory]::CreateDirectory((Split-Path $path -Parent))
            [IO.File]::WriteAllText($path,('[Evidencia legada](<'+$script:cleanupLateFixture.Evidence+'>)'))
            $script:cleanupLateState=& $script:cleanupLateSnapshot $script:cleanupLateFixture
        }
        $result
    }
} $late ${function:Get-ConversionState}
$failed=$false
try { $null=Invoke-ConversionCleanup @arguments -Descartar @($late.Plan.PlanPath,$late.Evidence) -ConfirmText LIMPAR 6>$null }
catch { Assert ($_.Exception.Message -match 'mud|alter|receb|corrente|confirm|invent|selec') $_.Exception.Message; $failed=$true }
finally { & $module { ${function:Invoke-ConversionApply}=$script:cleanupVerifyOriginal } }
Assert ($failed -and (& $module { $script:cleanupVerifyCalls }) -eq 2) 'Nova nota recebida na segunda VerifyOnly deve impedir qualquer retirada.'
$lateState=& $module { $script:cleanupLateState }
Assert ($null -ne $lateState -and (Get-ConversionState $late) -ceq $lateState) 'Barreira final preserva origens e nota recebida adicionada durante a verificacao.'

# Material recebido pendente e notas sem contexto nunca herdam o Source do alvo.
foreach ($kind in @('received','orphan')) {
    $unknownConsumer=New-ConvertedCleanupFixture; $arguments=$unknownConsumer.Arguments
    $note=if ($kind -eq 'received') { Join-Path $unknownConsumer.Project.Folder 'recebido/nota.md' } else { Join-Path $unknownConsumer.Workspace '.harness/planning/outro/nota.md' }
    Write-ConversionFile $note ('# Nota humana com [evidencia legada](<'+$unknownConsumer.Evidence+'>)')
    $before=Get-ConversionState $unknownConsumer
    $preview=Get-ConversionCleanupPreview @arguments
    $candidate=@($preview.Candidates|Where-Object Path -IEQ $unknownConsumer.Evidence)
    Assert ($candidate.Count -eq 1 -and -not $candidate[0].Eligible) ('Consumidor pendente ou desconhecido impede descartar a evidencia: '+$kind)
    Assert ((Get-ConversionState $unknownConsumer) -ceq $before) 'Preview preserva material recebido e notas orfas.'
    Reject-ConversionCleanup $unknownConsumer { Invoke-ConversionCleanup @arguments -Descartar @($unknownConsumer.Evidence) -ConfirmText LIMPAR 6>$null } 'consum|compart|desconhec|exclus|comprov|receb|penden' ('Evidencia de consumidor sem adocao nao pode ser retirada: '+$kind)
}

# Outro Source depende transitivamente do anexo, embora nao participe desta conversao.
$shared=New-ConvertedCleanupFixture; $arguments=$shared.Arguments
$otherSource=Join-Path $shared.Area 'outro-source'; Write-ConversionFile (Join-Path $otherSource 'pom.xml') '<project><artifactId>outro</artifactId></project>'
$otherRegister=Join-Path $shared.Workspace '.harness/projetos/outro__123456789abc/migracao.md'
$registerText=[IO.File]::ReadAllText($shared.Register).Replace($shared.Source,$otherSource).Replace('Project: apelido','Project: outro')
Write-ConversionFile $otherRegister $registerText
$other=[pscustomobject]@{Workspace=$shared.Workspace;Source=$otherSource;Register=$otherRegister}
$otherPlan=Add-ConversionPlan $other ('b'*32) -ProjectFolder outro
Write-ConversionFile $otherRegister ($registerText.Replace($shared.Plan.PlanPath,$otherPlan.PlanPath))
$bridge=Join-Path (Split-Path $otherPlan.PlanPath -Parent) 'ponte.md'
Write-ConversionFile $bridge ('# Nota de B com [anexo compartilhado](<'+$shared.Evidence+'>)')
[IO.File]::AppendAllText($otherPlan.PlanPath,("`n[Nota do outro Source](<"+$bridge+">)`n"))
$before=Get-ConversionState $shared
$preview=Get-ConversionCleanupPreview @arguments
$candidate=@($preview.Candidates|Where-Object Path -IEQ $shared.Evidence)
Assert ($candidate.Count -eq 1 -and -not $candidate[0].Eligible -and $candidate[0].Reason -match 'Source|compart|refer|consum|outro') 'Referencia transitiva de outro Source deve impedir descarte do anexo compartilhado.'
Assert ((Get-ConversionState $shared) -ceq $before) 'Deteccao de dependencias compartilhadas e somente leitura.'
Reject-ConversionCleanup $shared { Invoke-ConversionCleanup @arguments -Descartar @($shared.Plan.PlanPath,$shared.Evidence) -ConfirmText LIMPAR 6>$null } 'Source|compart|refer|consum|outro|eleg|exclus|comprov' 'Nenhuma parte da selecao deve ser removida quando um anexo sustenta outro Source.'

# Descarte confirmado retira apenas folhas transformadas; o corrente permanece autonomo.
$done=New-ConvertedCleanupFixture; $arguments=$done.Arguments
$selected=@($done.Register,$done.Plan.ContextPath,$done.Plan.PlanPath,$done.Plan.TodoPath,$done.Evidence,$done.Binary)
$currentBefore=@(Get-ChildItem -LiteralPath $done.Project.Folder -File -Recurse|Sort-Object FullName|ForEach-Object { $_.FullName+' '+$_.LastWriteTimeUtc.Ticks+' '+(Get-FileHash -LiteralPath $_.FullName).Hash }) -join [Environment]::NewLine
$cleaned=Invoke-ConversionCleanup @arguments -Descartar $selected -ConfirmText LIMPAR 6>$null
Assert ($cleaned.Status -ceq 'LIMPO' -and @($cleaned.RemovedFiles).Count -eq $selected.Count) 'Resultado confirmado informa exatamente as folhas retiradas.'
foreach ($path in $selected) { Assert (-not (Test-Path -LiteralPath $path)) ('Somente a folha explicitamente selecionada deve sair: '+$path) }
$currentAfter=@(Get-ChildItem -LiteralPath $done.Project.Folder -File -Recurse|Sort-Object FullName|ForEach-Object { $_.FullName+' '+$_.LastWriteTimeUtc.Ticks+' '+(Get-FileHash -LiteralPath $_.FullName).Hash }) -join [Environment]::NewLine
Assert ($currentAfter -ceq $currentBefore) 'Descarte de origens nao reescreve os documentos, anexos ou configuracao correntes.'
$valid=Test-ConversionCurrent -Workspace $done.Workspace -Pom $done.Pom
Assert $valid.Valid ('Corrente deve continuar operacional depois de retirar todas as origens selecionadas: '+($valid.Diagnostics -join '; '))
$newSibling=Join-Path (Split-Path $done.Plan.PlanPath -Parent) 'novo-arquivo-humano.md'; Write-ConversionFile $newSibling 'arquivo criado depois do descarte'
$before=Get-ConversionState $done
$repeat=Invoke-ConversionCleanup @arguments -Descartar $selected -ConfirmText LIMPAR 6>$null
Assert ($repeat.Status -ceq 'SEM_RESIDUOS') 'Repetir a mesma selecao ausente retorna SEM_RESIDUOS apos validar o corrente.'
Assert ((Get-ConversionState $done) -ceq $before) 'Repeticao nao apaga arquivos novos nem grava recibo de descarte.'
[IO.File]::AppendAllText($done.Project.PlanPath,"`n[Pendencia corrente](<ausente.md>)")
Reject-ConversionCleanup $done { Invoke-ConversionCleanup @arguments -Descartar $selected -ConfirmText LIMPAR 6>$null } 'corrente|penden|valid|refer' 'Mesmo a selecao inteiramente ausente exige destino corrente valido.'

# Ausencia parcial sem journal nao autoriza inferir um descarte anterior.
$partial=New-ConvertedCleanupFixture; $arguments=$partial.Arguments
$moved=Join-Path $partial.Area 'plano-retirado-por-fora.md'
foreach ($path in @($partial.Plan.PlanPath,$moved)) { Assert ([IO.Path]::GetFullPath($path).StartsWith([IO.Path]::GetFullPath($partial.Area)+'\',[StringComparison]::OrdinalIgnoreCase)) 'Movimento da fixture deve permanecer na area isolada.' }
Move-Item -LiteralPath $partial.Plan.PlanPath -Destination $moved
Reject-ConversionCleanup $partial { Invoke-ConversionCleanup @arguments -Descartar @($partial.Plan.PlanPath,$partial.Plan.TodoPath) -ConfirmText LIMPAR 6>$null } 'parcial|ausen|journal|origina' 'Selecao parcialmente ausente sem journal deve ser recusada.'

# Morte real do processo deixa somente journal transitorio; recuperar e uma escolha separada.
$recovery=New-ConvertedCleanupFixture; $arguments=$recovery.Arguments
$selected=@($recovery.Register,$recovery.Plan.ContextPath,$recovery.Plan.PlanPath,$recovery.Plan.TodoPath,$recovery.Evidence,$recovery.Binary)
$originals=@{}
foreach ($path in $selected) { $originals[$path]=[pscustomobject]@{Bytes=[IO.File]::ReadAllBytes($path);Ticks=[IO.File]::GetLastWriteTimeUtc($path).Ticks} }
$payload=Join-Path $recovery.Area 'selecao-filho.json'
Write-ConversionFile $payload (@{Arguments=$arguments;Descartar=$selected}|ConvertTo-Json -Depth 10)
$child=Join-Path $recovery.Area 'interromper-descarte.ps1'
Write-ConversionFile $child @'
param($ModulePath,$Payload,$Mode='published')
$ErrorActionPreference='Stop'
Import-Module (Join-Path (Split-Path $ModulePath -Parent) '../../scripts/HarnessProject.psm1') -DisableNameChecking
Import-Module $ModulePath -DisableNameChecking
$data=Get-Content -LiteralPath $Payload -Raw|ConvertFrom-Json
$arguments=@{}; foreach ($property in $data.Arguments.PSObject.Properties) { $arguments[$property.Name]=$property.Value }
& (Get-Module HarnessProject) {
    param($Mode)
    if ($Mode -eq 'preparing') {
        function script:Write-ProjectRecoveryInstruction { param($Temporary,$Entries) [IO.File]::WriteAllText((Join-Path $Temporary 'recuperacao.tmp'),'[{'); [Environment]::Exit(73) }
    } elseif ($Mode -eq 'committed') {
        function script:Clear-ProjectPublicationFiles { param($Project) [Environment]::Exit(74) }
    } else { function script:Remove-ProjectPublication { param($Project) [Environment]::Exit(71) } }
} $Mode
$null=Invoke-ConversionCleanup @arguments -Descartar @($data.Descartar) -ConfirmText LIMPAR
'@
$childOutput=@(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $child (Join-Path $root 'tools/transicao/ConversaoLimpeza.psm1') $payload 2>&1)
Assert ($LASTEXITCODE -eq 71) ('Filho deve morrer depois da retirada e antes do commit do descarte: '+($childOutput -join ' '))
foreach ($path in $selected) { Assert (-not (Test-Path -LiteralPath $path)) 'Filho deve ter retirado realmente cada origem selecionada.' }
$journal=Join-Path $recovery.Workspace '.harness/temporarios/conversao-descarte/publicacao/recuperacao.json'
Assert (Test-Path -LiteralPath $journal) 'Interrupcao deixa instrucao transitoria para restaurar os originais.'
$before=Get-ConversionState $recovery
$preview=Get-ConversionCleanupPreview @arguments
Assert ($preview.Status -ceq 'RECUPERACAO_PENDENTE') 'Preview deve sinalizar journal sem recompor a conversao com origens retiradas.'
Assert ((Get-ConversionState $recovery) -ceq $before) 'Preview com recuperacao pendente permanece somente leitura.'
$cancelled=Invoke-ConversionCleanup @arguments -Descartar $selected -ConfirmText LIMPAR 6>$null
Assert ($cancelled.Status -ceq 'CANCELADO' -and (Get-ConversionState $recovery) -ceq $before) 'LIMPAR nao autoriza implicitamente recuperar originais nem repetir descarte.'
Reject-ConversionCleanup $recovery { Invoke-ConversionCleanup @arguments -Descartar @($selected[0]) -ConfirmText RECUPERAR 6>$null } 'exatamente|journal|recuper' 'Recuperacao exige exatamente a selecao registrada no journal transitorio.'
$restored=Invoke-ConversionCleanup @arguments -Descartar $selected -ConfirmText RECUPERAR 6>$null
Assert ($restored.Status -ceq 'RECUPERADO' -and @($restored.RemovedFiles).Count -eq 0) 'RECUPERAR restaura os originais sem iniciar novo descarte.'
foreach ($path in $selected) {
    Assert ([Convert]::ToBase64String([IO.File]::ReadAllBytes($path)) -ceq [Convert]::ToBase64String($originals[$path].Bytes)) 'Recuperacao deve restaurar os bytes de todas as origens.'
    Assert ([IO.File]::GetLastWriteTimeUtc($path).Ticks -eq $originals[$path].Ticks) 'Recuperacao deve preservar a data das origens restauradas.'
}
Assert (-not (Test-Path -LiteralPath $journal)) 'Recuperacao completa retira o journal transitorio.'
Assert ((Test-ConversionCurrent -Workspace $recovery.Workspace -Pom $recovery.Pom).Valid) 'Recuperar origens nao altera a autonomia do destino corrente.'

# Sem journal, recuperar apenas limpa o estagio tecnico, antes ou depois do commit.
foreach ($mode in @('preparing','committed')) {
    $stageFixture=New-ConvertedCleanupFixture; $arguments=$stageFixture.Arguments
    $selected=@($stageFixture.Plan.PlanPath,$stageFixture.Plan.TodoPath)
    $originals=@{}; foreach ($path in $selected) { $originals[$path]=[IO.File]::ReadAllBytes($path) }
    $payload=Join-Path $stageFixture.Area 'selecao-filho.json'; Write-ConversionFile $payload (@{Arguments=$arguments;Descartar=$selected}|ConvertTo-Json -Depth 10)
    $childOutput=@(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $child (Join-Path $root 'tools/transicao/ConversaoLimpeza.psm1') $payload $mode 2>&1)
    $expectedExit=if ($mode -eq 'preparing') {73} else {74}
    Assert ($LASTEXITCODE -eq $expectedExit) ('Filho deve interromper no estagio '+$mode+': '+($childOutput -join ' '))
    $stage=Join-Path $stageFixture.Workspace '.harness/temporarios/conversao-descarte/publicacao'
    Assert ((Test-Path -LiteralPath $stage) -and -not (Test-Path -LiteralPath (Join-Path $stage 'recuperacao.json'))) 'Fixture deve deixar estagio real sem journal.'
    $before=Get-ConversionState $stageFixture
    $preview=Get-ConversionCleanupPreview @arguments
    Assert ($preview.Status -ceq 'RECUPERACAO_PENDENTE' -and (Get-ConversionState $stageFixture) -ceq $before) 'Preview de estagio sem journal e pendencia somente leitura.'
    $cancelled=Invoke-ConversionCleanup @arguments -Descartar @() -ConfirmText cancelar 6>$null
    Assert ($cancelled.Status -ceq 'CANCELADO' -and (Get-ConversionState $stageFixture) -ceq $before) 'Cancelamento nao limpa o estagio tecnico.'
    $restored=Invoke-ConversionCleanup @arguments -Descartar @() -ConfirmText RECUPERAR 6>$null
    Assert ($restored.Status -ceq 'RECUPERADO' -and @($restored.RemovedFiles).Count -eq 0 -and -not (Test-Path -LiteralPath $stage)) 'Confirmacao vazia de arquivos so limpa estagio tecnico sem journal.'
    foreach ($path in $selected) {
        if ($mode -eq 'preparing') { Assert ([Convert]::ToBase64String([IO.File]::ReadAllBytes($path)) -ceq [Convert]::ToBase64String($originals[$path])) 'Limpar preparo interrompido nao altera origens ainda presentes.' }
        else { Assert (-not (Test-Path -LiteralPath $path)) 'Limpar estagio apos commit nao restaura origens ja retiradas.' }
    }
}
'PASS: descarte explicito do legado convertido, autonomia corrente, cancelamento, concorrencia, compartilhamento e repeticao segura.'
