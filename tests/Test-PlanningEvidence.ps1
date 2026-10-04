#requires -Version 5.1
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $root 'scripts/Harness.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $root 'scripts/HarnessPlanning.psm1') -Force -DisableNameChecking
function Assert($condition, $message) { if (-not $condition) { throw $message } }
function Reject($action, $message) { $failed=$false; try { & $action } catch { $failed=$true }; Assert $failed $message }
$area = Join-Path $root ('.harness/tests/pe-' + [guid]::NewGuid().ToString('N').Substring(0,8))
$fixture = Join-Path $area 'harness'
$app = Join-Path $area 'app'
$null = New-Item -ItemType Directory -Path $fixture,$app -Force
Set-Content (Join-Path $app 'pom.xml') '<project />'
$project = [pscustomobject]@{name='app';label='Aplicacao';path=$app}
$context = [pscustomobject]@{Root=$fixture;Active=$project;Projects=@($project);Config=$null;ConfigPath=$null;WorkspacePath=$null}
foreach ($file in @('doc/especificacoes/planejamento-copilot.md','.github/prompts/planejar-lotes.prompt.md','.github/prompts/implementar-lote.prompt.md','.github/prompts/revisar-resultado.prompt.md')) {
    $dest = Join-Path $fixture $file
    $null = New-Item -ItemType Directory -Path (Split-Path $dest -Parent) -Force
    Copy-Item (Join-Path $root $file) $dest
}
$register = Initialize-HarnessMigration $fixture $project
$text = [IO.File]::ReadAllText($register.MigrationPath)
$row = '| DEV-CACHE | Preservar comportamento do cache | manual | - | MANUAL | ANALISAR AGORA | NAO ANALISADA | Evidencia no LEIA-ME. |'
$text = $text.Replace('Total MTA:', "$row`n`nTotal MTA:")
[IO.File]::WriteAllText($register.MigrationPath,$text)
$before = (Get-FileHash $register.MigrationPath).Hash
$prepared = New-MtaPlanningContext $context -MigrationPath $register.MigrationPath
$receipt = Get-Content -Raw -Encoding UTF8 $prepared.ContextPath | ConvertFrom-Json
Assert ($receipt.PlanningBasis -eq 'EVIDENCIAS' -and $null -eq $receipt.RunId -and $null -eq $receipt.MtaOrigin) 'Evidencias nao podem inventar rodada MTA.'
Assert ($receipt.SelectedIssues[0].Id -eq 'DEV-CACHE') 'Escolha humana ausente no contexto.'
Assert ((Get-FileHash $register.MigrationPath).Hash -eq $before) 'Planejar alterou o registro.'
Assert (-not (Test-Path $prepared.PlanPath)) 'Preparo simulou plano do agente.'
Set-Content $prepared.PlanPath '# Proposta existente'
Set-Content $prepared.TodoPath '- [x] Evidencia conferida'
$history = @(Get-MtaPlanningHistory $context)
Assert ($history.Count -eq 1 -and $history[0].RequestId -eq $prepared.RequestId) 'Historico nao reconhece evidencias.'
$impl = New-MtaImplementationPrompt $context -RequestId $prepared.RequestId
Assert (Test-Path $impl.ResultReviewPromptPath) 'Fases posteriores exigiram MTA ficticio.'
$same=Invoke-HarnessRegisteredPlanning $context -MigrationPath $register.MigrationPath
Assert ($same.RequestId -eq $prepared.RequestId -and $same.Reused) 'Planejar duplicou uma solicitacao sem mudanca de base.'
$context.Active=$null
$same=Invoke-HarnessRegisteredPlanning $context
Assert ($same.RequestId -eq $prepared.RequestId) 'Registro inequivoco exigiu nova escolha de projeto.'
$same=Invoke-HarnessRegisteredPlanning $context -ContextPath $prepared.ContextPath
Assert ($same.RequestId -eq $prepared.RequestId) 'Retomada explicita nao preservou identidade.'
$savedReceipt=(Get-FileHash $prepared.ContextPath).Hash
Add-Content $register.EvidenceIndexPath '| falha.txt | Cenario relatado pelo desenvolvedor |'
Set-Content (Join-Path (Split-Path $register.EvidenceIndexPath -Parent) 'falha.txt') 'Erro reproduzido no cache desativado.'
Reject { New-MtaImplementationPrompt $context -RequestId $prepared.RequestId } 'Implementacao aceitou evidencia alterada sem reavaliacao.'
$updated=Invoke-HarnessRegisteredPlanning $context -ContextPath $prepared.ContextPath
$newReceipt=Get-Content -Raw -Encoding UTF8 $updated.ContextPath | ConvertFrom-Json
Assert ($newReceipt.Previous.RequestId -eq $prepared.RequestId -and $updated.RequestId -ne $prepared.RequestId) 'Mudanca de base nao vinculou Previous.'
Assert ((Get-FileHash $prepared.ContextPath).Hash -eq $savedReceipt) 'Retomada reescreveu recibo antigo.'
Assert (@($newReceipt.EvidenceInputs | Where-Object { $_.Path -like '*falha.txt' -and $_.Sha256 }).Count -eq 1) 'Anexo presente sem hash real.'
foreach ($selector in @(@{ContextPath=$prepared.ContextPath},@{RequestId=$prepared.RequestId})) {
    $repeat=Invoke-HarnessRegisteredPlanning $context @selector
    Assert ($repeat.RequestId -eq $updated.RequestId -and $repeat.Reused) 'Repetir referencia explicita antiga criou uma bifurcacao artificial.'
}
$successor=Invoke-HarnessRegisteredPlanning $context -MigrationPath $register.MigrationPath
Assert ($successor.RequestId -eq $updated.RequestId) 'Sucessao explicita Previous deveria retomar a revisao ja preparada.'
$linkedText=[IO.File]::ReadAllText($register.MigrationPath).Replace('Evidencia no LEIA-ME.', ('Evidencia no LEIA-ME. [Plano](<' + $prepared.PlanPath + '>).'))
[IO.File]::WriteAllText($register.MigrationPath,$linkedText)
$linkedSuccessor=Invoke-HarnessRegisteredPlanning $context -MigrationPath $register.MigrationPath
Assert ($linkedSuccessor.RequestId -eq $updated.RequestId) 'Referencia a base antiga criou outra revisao em vez de seguir Previous.'
$unselected='| DEV-DEPOIS | Outra frente | manual | - | MANUAL | ADIAR | NAO ANALISADA | [Plano](plano-inexistente/plan.md) |'
$withOther=[IO.File]::ReadAllText($register.MigrationPath).Replace((' [Plano](<' + $prepared.PlanPath + '>).'),'').Replace('<!-- mta:fim -->', "$unselected`n<!-- mta:fim -->")
[IO.File]::WriteAllText($register.MigrationPath,$withOther)
$same=Invoke-HarnessRegisteredPlanning $context -MigrationPath $register.MigrationPath
Assert ($same.RequestId -eq $updated.RequestId) 'Referencia de issue adiada interferiu na retomada da issue escolhida.'
[IO.File]::WriteAllText($register.MigrationPath,$linkedText)

# Varios registros elegiveis exigem uma escolha, sem planejar todos.
$secondApp=Join-Path $area 'app2'
$null=New-Item -ItemType Directory -Path $secondApp -Force
Set-Content (Join-Path $secondApp 'pom.xml') '<project />'
$secondProject=[pscustomobject]@{name='app2';label='Outra aplicacao';path=$secondApp}
$secondRegister=Initialize-HarnessMigration $fixture $secondProject
[IO.File]::WriteAllText($secondRegister.MigrationPath,([IO.File]::ReadAllText($secondRegister.MigrationPath).Replace('Total MTA:',"$row`n`nTotal MTA:")))
$context.Projects=@($project,$secondProject)
Reject { Invoke-HarnessRegisteredPlanning $context } 'Dois registros elegiveis foram escolhidos sem direcionamento humano.'
$same=Invoke-HarnessRegisteredPlanning $context -Target app
Assert ($same.RequestId -eq $updated.RequestId) 'Escolha minima por projeto nao resolveu ambiguidade real.'
$context.Projects=@($project)

# Entrada real sem menus, com registro e retomada por recibo.
$scripts=Join-Path $fixture 'scripts'
$null=New-Item -ItemType Directory -Path $scripts -Force
foreach ($name in @('Harness.psm1','HarnessPlanning.psm1','HarnessPlanningInput.ps1','preparar-planejamento.ps1')) { Copy-Item (Join-Path $root ('scripts/'+$name)) $scripts }
$config=Get-Content (Join-Path $root 'config/harness.example.json') -Raw | ConvertFrom-Json
$config.repositories=@(@{name='app';path=$app}); $config.activeProject=$null
$configPath=Join-Path $fixture 'config.json'
Write-HarnessJson $configPath $config
$entry=Join-Path $scripts 'preparar-planejamento.ps1'
$output=& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $entry -ConfigPath $configPath -ContextPath $updated.ContextPath -NoOpen 2>&1 | Out-String
Assert ($LASTEXITCODE -eq 0 -and $output.Contains('Codex: Execute o prompt deste arquivo:') -and $output.Contains('Copilot:')) ('Retomada real falhou: '+$output)
$output=& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $entry -ConfigPath $configPath -RequestId $updated.RequestId -NoOpen -NonInteractive -OutputFormat Json 2>&1 | Out-String
$json=$output | ConvertFrom-Json
Assert ($LASTEXITCODE -eq 0 -and $json.RequestId -eq $updated.RequestId -and @($json.ChangedFiles).Count -eq 0) ('Retomada JSON nao foi idempotente: '+$output)
$output=& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $entry -ConfigPath $configPath -MigrationPath $register.MigrationPath -PreviousRequestId $updated.RequestId -NewPlan -NoOpen -NonInteractive -OutputFormat Json 2>&1 | Out-String
$json=$output | ConvertFrom-Json
Assert ($LASTEXITCODE -eq 1 -and $json.Status -eq 'FAILED' -and -not $json.WritesStarted -and @($json.ChangedFiles).Count -eq 0) 'Seletores contraditorios foram aceitos na entrada JSON.'

# Coluna errada, ausencia de escolha e origem ambigua nunca viram plano global.
$valid=[IO.File]::ReadAllText($register.MigrationPath)
[IO.File]::WriteAllText($register.MigrationPath,$valid.Replace('ANALISAR AGORA | NAO ANALISADA','A DEFINIR | ANALISAR AGORA'))
Reject { New-MtaPlanningContext $context -MigrationPath $register.MigrationPath } 'Estado em coluna errada aceito.'
[IO.File]::WriteAllText($register.MigrationPath,$valid.Replace('ANALISAR AGORA','A DEFINIR'))
Reject { New-MtaPlanningContext $context -MigrationPath $register.MigrationPath } 'Sem escolha iniciou planejamento global.'
[IO.File]::WriteAllText($register.MigrationPath,$valid)
$badOrigin=$valid.Replace('<!-- mta:inicio -->', "<!-- mta:inicio -->`n<!-- MTA { quebrado -->")
[IO.File]::WriteAllText($register.MigrationPath,$badOrigin)
Reject { New-MtaPlanningContext $context -MigrationPath $register.MigrationPath } 'Origem MTA malformada virou modo evidencias.'
[IO.File]::WriteAllText($register.MigrationPath,$valid)

# Preparo nao exige falsificar andamento para uma reabertura humana explicita.
foreach ($progress in @('IMPLEMENTADA','VERIFICADA')) {
    $reopened=$valid.Replace('ANALISAR AGORA | NAO ANALISADA',('ANALISAR AGORA | '+$progress)).Replace('Evidencia no LEIA-ME.','Reabrir DEV-CACHE para avaliar regressao no cache desativado; preservar aceite anterior no historico.')
    [IO.File]::WriteAllText($register.MigrationPath,$reopened)
    $reopenOutput=@(Invoke-HarnessRegisteredPlanning $context -MigrationPath $register.MigrationPath 3>&1)
    $reopenWarnings=@($reopenOutput | Where-Object { $_ -is [System.Management.Automation.WarningRecord] })
    $reopen=$reopenOutput | Where-Object { $_ -isnot [System.Management.Automation.WarningRecord] }
    Assert ($reopen.RequestId -eq $updated.RequestId -and $reopenWarnings.Count -gt 0) 'Reabertura bloqueada ou sem orientacao sobre direcionamento humano.'
    Assert ([IO.File]::ReadAllText($register.MigrationPath) -ceq $reopened) 'Preparo regrediu andamento para permitir reabertura.'
}
[IO.File]::WriteAllText($register.MigrationPath,$valid)

# Links percentencoded recebem hash real; Target resolve sem menu.
$evidence=Join-Path (Split-Path $register.EvidenceIndexPath -Parent) 'cenario com espaco.txt'
Set-Content $evidence 'cenario confirmado'
Add-Content $register.EvidenceIndexPath '| [Cenario](cenario%20com%20espaco.txt) | Cache |'
$incomplete=Invoke-HarnessRegisteredPlanning $context -ContextPath $updated.ContextPath -Target app
$incompleteReceipt=Get-Content -Raw -Encoding UTF8 $incomplete.ContextPath | ConvertFrom-Json
Assert ($incompleteReceipt.Previous.RequestId -eq $updated.RequestId -and $null -eq $incompleteReceipt.Previous.PlanSha256) 'Resposta com evidencia exigiu concluir proposta antiga ou inventou hash.'
Assert (@($incompleteReceipt.EvidenceInputs | Where-Object { $_.Path -eq $evidence -and $_.Sha256 }).Count -eq 1) 'Link com %20 nao recebeu hash.'

# Identidade do registro e contextos e sempre conferida, mesmo em modo EVIDENCIAS.
$receiptOriginal=[IO.File]::ReadAllText($incomplete.ContextPath)
$incompleteReceipt.MigrationPath=Join-Path $fixture 'registro-de-outro-projeto.md'
Write-HarnessJson $incomplete.ContextPath $incompleteReceipt
Reject { Invoke-HarnessRegisteredPlanning $context -ContextPath $incomplete.ContextPath } 'Recibo com registro divergente aceito.'
[IO.File]::WriteAllText($incomplete.ContextPath,$receiptOriginal)
$lease=[IO.File]::Open((Join-Path $fixture '.harness/planning.lock'),'OpenOrCreate','ReadWrite','None')
try { Reject { Invoke-HarnessRegisteredPlanning $context -ContextPath $incomplete.ContextPath } 'Retomada ignorou lock.' }
finally { $lease.Dispose() }

function Add-TestMta($id,$date) {
    $run=Join-Path $fixture ('.harness/runs/app/'+$id)
    Write-HarnessJson (Join-Path $run 'manifest.json') @{Project='app';RunId=$id;Source=$app;CreatedAtUtc=$date}
    Write-HarnessJson (Join-Path $run 'result.json') @{Project='app';RunId=$id;Status='SUCCEEDED';ExitCode=0;SourceUnchanged=$true;SnapshotOriginalFilesUnchanged=$true;RulesUnchanged=$true;UnexpectedAddedFiles=@()}
    foreach ($name in @('input/pom.xml','output/output.yaml','output/dependencies.yaml','output/static-report/index.html','rules/rule.yaml')) {
        $path=Join-Path $run $name
        $null=New-Item -ItemType Directory -Path (Split-Path $path -Parent) -Force
        Set-Content $path 'fixture'
    }
    Set-Content (Join-Path $run 'output/static-report/output.js') 'window["apps"] = [{"rulesets":[{"name":"java","violations":{"rule":{"description":"Regra","category":"mandatory","incidents":[]}}}]}]'
    $run
}
$oldRun=Add-TestMta ('a'*32) '2026-10-01T10:00:00Z'
$newRun=Add-TestMta ('b'*32) '2026-10-02T10:00:00Z'
$null=Update-HarnessMigration $context (Get-MtaPlanningRunFromPath $oldRun $fixture)
$registeredHash=(Get-FileHash $register.MigrationPath).Hash
$mtaPlan=New-MtaPlanningContext $context -MigrationPath $register.MigrationPath
$mtaReceipt=Get-Content -Raw -Encoding UTF8 $mtaPlan.ContextPath | ConvertFrom-Json
Assert ($mtaReceipt.RunId -eq ('a'*32) -and $mtaReceipt.PlanningBasis -eq 'MTA') 'Planejar elegeu a rodada mais nova em vez da origem registrada.'
Assert ((Get-FileHash $register.MigrationPath).Hash -eq $registeredHash) 'Preparo atualizou catalogo/registro.'
$withOrigin=[IO.File]::ReadAllText($register.MigrationPath)
[IO.File]::WriteAllText($register.MigrationPath,$withOrigin.Replace('<!-- mta:fim -->',"<!-- MTA { quebrado -->`n<!-- mta:fim -->"))
Reject { New-MtaPlanningContext $context -MigrationPath $register.MigrationPath } 'Origem valida junto de marcador malformado foi aceita.'
[IO.File]::WriteAllText($register.MigrationPath,$withOrigin)
# Atualizacao do contrato prepara novo recibo sem reescrever o prompt historico.
$oldPromptHash=(Get-FileHash $mtaPlan.PromptPath).Hash
Add-Content (Join-Path $fixture 'doc/especificacoes/planejamento-copilot.md') 'Nota de evolucao do contrato.'
$newContract=Invoke-HarnessRegisteredPlanning $context -ContextPath $mtaPlan.ContextPath
$newContractReceipt=Get-Content -Raw -Encoding UTF8 $newContract.ContextPath | ConvertFrom-Json
Assert ($newContractReceipt.Previous.RequestId -eq $mtaPlan.RequestId -and (Get-FileHash $mtaPlan.PromptPath).Hash -eq $oldPromptHash) 'Contrato novo reescreveu historico ou nao preparou contexto atualizado.'
Write-Output 'PASS: planejamento por evidencias, registro preservado, historico e fases posteriores.'
