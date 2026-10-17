#requires -Version 5.1
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$root=Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $root 'scripts/HarnessProject.psm1') -Force -DisableNameChecking
function Assert($Value,[string]$Message) { if (-not $Value) { throw $Message } }
function Write-Scratch([string]$Path,[byte[]]$Bytes) {
    $null=[IO.Directory]::CreateDirectory((Split-Path $Path -Parent))
    [IO.File]::WriteAllBytes($Path,$Bytes)
}
function Get-ScratchState([string]$Folder) {
    @(Get-ChildItem -LiteralPath $Folder -File -Recurse -Force|Sort-Object FullName|ForEach-Object { $_.FullName+' '+$_.LastWriteTimeUtc.Ticks+' '+(Get-FileHash -LiteralPath $_.FullName).Hash }) -join "`n"
}
function Reject-Scratch([scriptblock]$Action,[string]$Pattern,[string]$Message) {
    $before=Get-ScratchState $project.Folder; $failed=$false
    try { $null=& $Action } catch { Assert ($_.Exception.Message -match $Pattern) ($Message+' Erro inesperado: '+$_.Exception.Message); $failed=$true }
    Assert $failed $Message
    Assert ((Get-ScratchState $project.Folder) -ceq $before) 'Recusa deve preservar todos os bytes e datas, inclusive os temporarios.'
}
$area=Join-Path $root ('.harness/tests/temporary-removal-'+[guid]::NewGuid().ToString('N').Substring(0,8))
$app=Join-Path $area 'app'; $null=[IO.Directory]::CreateDirectory($app)
$pom=Join-Path $app 'pom.xml'
[IO.File]::WriteAllText($pom,'<project><artifactId>servico</artifactId></project>')
$project=Initialize-HarnessProjectStorage $area $pom
$relative='temporarios/build/tentativa/log.bin'; $path=Join-Path $project.Folder $relative
$bytes=[byte[]]@(0,128,255,10)
Write-Scratch $path $bytes
Publish-HarnessProjectFiles $project @{$relative=$null} -Expected @{$relative=$bytes} -RemoveTemporaryFiles
Assert (-not (Test-Path -LiteralPath $path)) 'Remocao temporaria explicita deve retirar o arquivo observado.'
Assert (-not (Test-Path -LiteralPath (Join-Path $project.TemporaryPath 'publicacao'))) 'Sucesso nao deixa journal de publicacao.'

# O switch so retira folhas de produtores; leitura e escrita genericas permanecem fechadas.
$current='atual/planejamento/plano.md'
Publish-HarnessProjectFiles $project @{$current='Plano corrente preservado';'recebido/nota.md'='Recebido preservado'}
Write-Scratch $path $bytes
Reject-Scratch { Read-HarnessProjectFiles $project @($relative) } 'destin|temporari|documento' 'Leitura generica nao deve abrir temporarios.'
Reject-Scratch { Publish-HarnessProjectFiles $project @{$relative=$null} -Expected @{$relative=$bytes} } 'destin|temporari|documento' 'Remocao generica nao deve abrir temporarios.'
foreach ($value in @('escrita proibida',([byte[]]@(1,2)))) {
    Reject-Scratch { Publish-HarnessProjectFiles $project @{$relative=$value} -Expected @{$relative=$bytes} -RemoveTemporaryFiles } 'temporari|remoc|nulo|null|escrit' 'O switch nao autoriza escrita textual nem binaria em temporarios.'
}
foreach ($denied in @('atual/planejamento/plano.md','recebido/nota.md','reconciliado/nota.md','temporarios/publicacao/injetado.bin','temporarios/reconciliacao/base.bin','temporarios/outro/log.bin','temporarios/build/../sonar/log.bin')) {
    Reject-Scratch { Publish-HarnessProjectFiles $project @{$denied=$null} -Expected @{$denied=$bytes} -RemoveTemporaryFiles } 'temporari|destin|documento|remoc|permit|folha' ('Destino fora da allowlist deve ser recusado: '+$denied)
}
Reject-Scratch { Publish-HarnessProjectFiles $project ([ordered]@{$relative=$null;$current=$null}) -Expected @{$relative=$bytes;$current='Plano corrente preservado'} -RemoveTemporaryFiles } 'temporari|destin|documento|remoc|permit' 'Remocao temporaria nao deve misturar documento atual.'
Reject-Scratch { Publish-HarnessProjectFiles $project @{$relative=$null} -RemoveTemporaryFiles } 'Expected|esperad|observ|byte|leitura|temporari' 'Cada folha exige os bytes observados explicitamente.'
Reject-Scratch { Publish-HarnessProjectFiles $project @{$relative=$null} -Expected @{$relative=[Text.Encoding]::UTF8.GetString($bytes)} -RemoveTemporaryFiles } 'Expected|esperad|observ|byte|leitura|temporari' 'Comparacao textual nao substitui igualdade binaria.'

# Alteracao desde a previa e arquivo novo nao listado devem sobreviver.
$newRelative='temporarios/mta/nova-tentativa/novo.bin'; $newPath=Join-Path $project.Folder $newRelative
$newBytes=[byte[]]@(129,7,0); Write-Scratch $newPath $newBytes
$changedBytes=[byte[]]@(0,129,255,10); Write-Scratch $path $changedBytes
Reject-Scratch { Publish-HarnessProjectFiles $project @{$relative=$null} -Expected @{$relative=$bytes} -RemoveTemporaryFiles } 'alter|leitura|observ|diverg' 'Bytes alterados depois da previa impedem a retirada.'
$newBefore=Get-ScratchState (Split-Path $newPath -Parent)
Publish-HarnessProjectFiles $project @{$relative=$null} -Expected @{$relative=$changedBytes} -RemoveTemporaryFiles
Assert ((Get-ScratchState (Split-Path $newPath -Parent)) -ceq $newBefore) 'Arquivo novo nao listado permanece byte a byte e com a mesma data.'

# As tres familias sao elegiveis, incluindo arquivo vazio observado como byte[].
$removals=[ordered]@{'temporarios/build/tentativa/log.bin'=$null;'temporarios/mta/tentativa/catalogo.bin'=$null;'temporarios/sonar/tentativa/vazio.bin'=$null}
$observed=@{'temporarios/build/tentativa/log.bin'=[byte[]]@(0,128,255);'temporarios/mta/tentativa/catalogo.bin'=[byte[]]@(32,0,129);'temporarios/sonar/tentativa/vazio.bin'=[byte[]]@()}
foreach ($key in $removals.Keys) { Write-Scratch (Join-Path $project.Folder $key) $observed[$key] }
Publish-HarnessProjectFiles $project $removals -Expected $observed -RemoveTemporaryFiles
foreach ($key in $removals.Keys) { Assert (-not (Test-Path -LiteralPath (Join-Path $project.Folder $key))) ('Retirada confirmada: '+$key) }

# Falha depois de todas as retiradas deve restaurar o conjunto de scratch.
foreach ($key in $removals.Keys) { Write-Scratch (Join-Path $project.Folder $key) $observed[$key] }
$module=Get-Module HarnessProject
& $module {
    $script:temporaryOriginalRemove=${function:Remove-ProjectPublication}; $script:temporaryFailure=$false
    function script:Remove-ProjectPublication {
        param($Project)
        if (-not $script:temporaryFailure) { $script:temporaryFailure=$true; throw 'falha injetada depois das retiradas temporarias' }
        & $script:temporaryOriginalRemove $Project
    }
}
$failed=$false
try { Publish-HarnessProjectFiles $project $removals -Expected $observed -RemoveTemporaryFiles }
catch { Assert ($_.Exception.Message -match 'falha injetada') $_.Exception.Message; $failed=$true }
finally { & $module { ${function:Remove-ProjectPublication}=$script:temporaryOriginalRemove } }
Assert $failed 'Falha apos retirada deve chegar ao chamador.'
foreach ($key in $removals.Keys) { Assert ([Convert]::ToBase64String([IO.File]::ReadAllBytes((Join-Path $project.Folder $key))) -ceq [Convert]::ToBase64String($observed[$key])) 'Rollback deve restaurar cada arquivo temporario observado.' }
Assert (-not (Test-Path -LiteralPath (Join-Path $project.TemporaryPath 'publicacao'))) 'Rollback concluido limpa somente o protocolo de publicacao.'

# Processo filho morre antes do commit; o journal deve permitir recuperar na reabertura.
$child=Join-Path $area 'interromper-remocao.ps1'
[IO.File]::WriteAllText($child,@'
param($ModulePath,$Workspace,$Pom)
$ErrorActionPreference='Stop'
Import-Module $ModulePath -Force -DisableNameChecking
$project=Get-HarnessProjectStorage $Workspace $Pom
$files=[ordered]@{'temporarios/build/tentativa/log.bin'=$null;'temporarios/mta/tentativa/catalogo.bin'=$null;'temporarios/sonar/tentativa/vazio.bin'=$null}
$expected=@{}
foreach ($key in $files.Keys) { $expected[$key]=[IO.File]::ReadAllBytes((Join-Path $project.Folder $key)) }
& (Get-Module HarnessProject) { function script:Remove-ProjectPublication { param($Project) [Environment]::Exit(71) } }
Publish-HarnessProjectFiles $project $files -Expected $expected -RemoveTemporaryFiles
'@,(New-Object Text.UTF8Encoding($false)))
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $child (Join-Path $root 'scripts/HarnessProject.psm1') $area $pom
Assert ($LASTEXITCODE -eq 71) 'Filho deve interromper depois das retiradas reais, antes do commit.'
foreach ($key in $removals.Keys) { Assert (-not (Test-Path -LiteralPath (Join-Path $project.Folder $key))) 'Interrupcao deve ocorrer depois da retirada dos temporarios.' }
$journal=Join-Path $project.TemporaryPath 'publicacao/recuperacao.json'
$journalBytes=[IO.File]::ReadAllBytes($journal)
$entries=Get-Content -LiteralPath $journal -Raw|ConvertFrom-Json
Assert (@($entries).Count -eq 3) 'Journal registra exatamente as tres folhas retiradas.'
foreach ($entry in $entries) { Assert ($entry.TemporaryRemoval -eq $true -and $entry.Remove -eq $true) 'Journal deve marcar retirada temporaria somente como remocao.' }

# Mesmo um journal com backups completos nao pode ampliar a autorizacao de retirada.
foreach ($variant in @('destination','write','marker')) {
    $tampered=[Text.Encoding]::UTF8.GetString($journalBytes)|ConvertFrom-Json
    if ($variant -eq 'destination') {
        $tampered[0].Path=$current
        Write-Scratch (Join-Path $project.TemporaryPath ('publicacao/antes/'+$current)) ([IO.File]::ReadAllBytes((Join-Path $project.Folder $current)))
    } elseif ($variant -eq 'write') {
        $tampered[0].Remove=$false
        Write-Scratch (Join-Path $project.TemporaryPath ('publicacao/depois/'+$tampered[0].Path)) $observed[$tampered[0].Path]
    } else { $tampered[0].PSObject.Properties.Remove('TemporaryRemoval') }
    [IO.File]::WriteAllText($journal,(ConvertTo-Json -InputObject @($tampered)),(New-Object Text.UTF8Encoding($false)))
    Reject-Scratch { Read-HarnessProjectFiles $project @($current) } 'temporari|destin|documento|remoc|recupera|permit' ('Recuperacao nao pode aceitar journal adulterado: '+$variant)
    [IO.File]::WriteAllBytes($journal,$journalBytes)
}
$content=Read-HarnessProjectFiles $project @($current)
Assert ($content[$current] -ceq 'Plano corrente preservado') 'Recuperacao preserva o documento atual fora da retirada temporaria.'
foreach ($key in $removals.Keys) { Assert ([Convert]::ToBase64String([IO.File]::ReadAllBytes((Join-Path $project.Folder $key))) -ceq [Convert]::ToBase64String($observed[$key])) 'Reabertura deve restaurar cada temporario depois da morte do processo.' }
Assert (-not (Test-Path -LiteralPath (Join-Path $project.TemporaryPath 'publicacao'))) 'Recuperacao validada retira journal e backups transitorios.'
Assert ((Get-ScratchState (Split-Path $newPath -Parent)) -ceq $newBefore) 'Arquivo nao listado permanece intacto apos falha e recuperacao.'
'PASS: retirada temporaria restrita, igualdade binaria, concorrencia, rollback e recuperacao apos morte do processo.'
