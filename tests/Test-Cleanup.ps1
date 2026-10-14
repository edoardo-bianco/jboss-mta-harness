#requires -Version 5.1
$ErrorActionPreference='Stop'; Set-StrictMode -Version Latest
$root=Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $root 'scripts/HarnessProject.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $root 'scripts/HarnessCleanup.psm1') -Force -DisableNameChecking
function Assert($Value,[string]$Message) { if (-not $Value) { throw $Message } }
function Write-CleanupFixture([string]$Path,[string]$Text='preservar') {
    $null=[IO.Directory]::CreateDirectory((Split-Path $Path -Parent))
    [IO.File]::WriteAllText($Path,$Text,(New-Object Text.UTF8Encoding($false)))
}
function New-CleanupFixture([switch]$RootSource) {
    $area=Join-Path $root ('.harness/tests/cleanup-'+[guid]::NewGuid().ToString('N').Substring(0,8))
    $projects=@(foreach ($name in @('a','b')) {
        $source=if ($RootSource -and $name -ceq 'a') {$area} else {Join-Path $area ('app-'+$name)}
        $pom=Join-Path $source 'pom.xml'; Write-CleanupFixture $pom ('<project><artifactId>'+$name+'</artifactId></project>')
        Initialize-HarnessProjectStorage $area $pom
    })
    foreach ($project in $projects) {
        foreach ($family in @('build','mta','sonar')) { Write-CleanupFixture (Join-Path $project.TemporaryPath ($family+'/tentativa/log.bin')) ('scratch '+$project.Name+' '+$family) }
        foreach ($relative in @('migracao.md','indice.md','atual/planejamento/plano.md','atual/build/resultado.json','atual/mta/index.html','atual/sonar/resultado.json','atual/priorizacao/mandatory/escopos/p/priorizacao.md','atual/sprints/macro/contexto.json','evidencias/anexo.bin','reconciliado/notas.md','recebido/contexto.json','temporarios/reconciliacao/base.clixml')) { Write-CleanupFixture (Join-Path $project.Folder $relative) ('oficial '+$relative) }
    }
    foreach ($relative in @('.harness/runs/antigo/run/manifest.json','.harness/builds/antigo/run/result.json','.harness/planning/antigo/run/plano/context.json','.harness/sonar/baseline/result.json','.harness/last-antigo.json','.harness/active-mta.json','.harness/workspace-backups/oficial.json','externo/mta/index.html','externo/mta/output.js','config/harness.local.json','.harness/maven/settings.xml')) { Write-CleanupFixture (Join-Path $area $relative) ('legado e externo preservados '+$relative) }
    $receipt=@{Project='antigo';Source=$projects[0].Source;RunId='11111111111111111111111111111111'}|ConvertTo-Json -Compress
    foreach ($relative in @('.harness/runs/antigo/run/manifest.json','.harness/builds/antigo/run/result.json','.harness/planning/antigo/run/plano/context.json','.harness/last-antigo.json','.harness/active-mta.json')) { Write-CleanupFixture (Join-Path $area $relative) $receipt }
    [pscustomobject]@{Root=$area;Projects=$projects}
}
function Get-CleanupState([string]$Folder) {
    $pending=New-Object 'Collections.Generic.Stack[IO.DirectoryInfo]'; $pending.Push((New-Object IO.DirectoryInfo $Folder)); $states=@()
    while ($pending.Count) {
        foreach ($item in $pending.Pop().EnumerateFileSystemInfos()) {
            if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { $states+=($item.FullName+' JUNCTION'); continue }
            if ($item -is [IO.DirectoryInfo]) { $pending.Push($item); continue }
            $sha=[Security.Cryptography.SHA256]::Create()
            try { $hash=[BitConverter]::ToString($sha.ComputeHash([IO.File]::ReadAllBytes(('\\?\'+$item.FullName)))) } finally { $sha.Dispose() }
            $states+=($item.FullName+' '+$item.LastWriteTimeUtc.Ticks+' '+$hash)
        }
    }
    ($states|Sort-Object) -join [Environment]::NewLine
}
function Reject-Cleanup($Fixture,[scriptblock]$Action,[string]$Pattern,[string]$Message) {
    $before=Get-CleanupState $Fixture.Root; $failed=$false
    try { $null=& $Action } catch { Assert ($_.Exception.Message -match $Pattern) ($Message+' Erro inesperado: '+$_.Exception.Message); $failed=$true }
    Assert $failed $Message
    Assert ((Get-CleanupState $Fixture.Root) -ceq $before) 'Recusa de limpeza preserva bytes e datas de todos os arquivos.'
}
function Assert-CleanupSelectionRemoved($Fixture,[string]$Before,[string[]]$Paths) {
    $remaining=@($Before -split '\r?\n'|Where-Object { $line=$_; -not @($Paths|Where-Object {$line.StartsWith($_+' ',[StringComparison]::OrdinalIgnoreCase)}).Count }) -join [Environment]::NewLine
    Assert ((Get-CleanupState $Fixture.Root) -ceq $remaining) 'Limpeza deve retirar somente as folhas selecionadas, preservando bytes e datas do restante.'
}
function Invoke-CleanupPromptMutation($Fixture,[string]$Mode,[switch]$TemporaryBackups) {
    $target=Join-Path $Fixture.Projects[0].TemporaryPath 'build/tentativa/log.bin'
    if ($Mode -eq 'new') { $target=Join-Path $Fixture.Projects[0].TemporaryPath 'build/tentativa/novo.bin' }
    if ($TemporaryBackups) {
        $name=if ($Mode -eq 'new') {'novo.bin'} else {'log.bin'}
        $target=Join-Path $Fixture.Root ('.harness/backups-temporarios/ensaio/'+$name)
    }
    $module=Get-Module HarnessCleanup
    & $module {
        param($Root,$Target,$Mode,$Snapshot)
        $script:cleanupRoot=$Root; $script:cleanupTarget=$Target; $script:cleanupMode=$Mode; $script:cleanupSnapshot=$Snapshot
        $script:cleanupAfterPrompt=$null
        function script:Read-Host {
            param([string]$Prompt)
            if ($script:cleanupMode -eq 'time') { [IO.File]::SetLastWriteTimeUtc($script:cleanupTarget,([IO.File]::GetLastWriteTimeUtc($script:cleanupTarget).AddSeconds(2))) }
            else { [IO.File]::WriteAllText($script:cleanupTarget,'contribuicao durante a confirmacao') }
            $script:cleanupAfterPrompt=& $script:cleanupSnapshot $script:cleanupRoot
            'LIMPAR'
        }
    } $Fixture.Root $target $Mode ${function:Get-CleanupState}
    $failed=$false
    try { Invoke-HarnessCleanup $Fixture.Root -All:(-not $TemporaryBackups) -TemporaryBackups:$TemporaryBackups 6>$null|Out-Null }
    catch { Assert ($_.Exception.Message -match 'mud|alter|nov|selec|conjunto|leitura|confirm') $_.Exception.Message; $failed=$true }
    finally { & $module { Remove-Item Function:\Read-Host } }
    Assert $failed ('Mudanca durante confirmacao deve recusar todo o conjunto: '+$Mode)
    $postPrompt=& $module { $script:cleanupAfterPrompt }
    Assert ($null -ne $postPrompt -and (Get-CleanupState $Fixture.Root) -ceq $postPrompt) 'Nenhum arquivo pode ser removido apos edicao, nova folha ou mudanca de data durante a confirmacao.'
}

$f=New-CleanupFixture; $a=$f.Projects[0]; $b=$f.Projects[1]
$before=Get-CleanupState $f.Root
$selection=@(Get-HarnessCleanupPaths $f.Root -Source $a.Source)
$expected=@('build','mta','sonar'|ForEach-Object { Join-Path $a.TemporaryPath ($_+'/tentativa/log.bin') })
Assert ($selection.Count -eq 3 -and @($expected|Where-Object {$_ -notin $selection}).Count -eq 0) 'Preview deve selecionar somente folhas de build/MTA/Sonar correntes do Source associado.'
Assert ((Get-CleanupState $f.Root) -ceq $before) 'Preview deve ser somente leitura, sem recibos nem recuperacao.'
Invoke-HarnessCleanup $f.Root -Source $a.Source -ConfirmText cancelar 6>$null|Out-Null
Assert ((Get-CleanupState $f.Root) -ceq $before) 'Cancelamento deve ser somente leitura.'
Reject-Cleanup $f { Get-HarnessCleanupPaths $f.Root -All -TemporaryBackups } 'somente|escolha|escopo' 'Escopos de limpeza nao podem ser misturados.'
Invoke-HarnessCleanup $f.Root -Source $a.Source -ConfirmText LIMPAR 6>$null|Out-Null
Assert-CleanupSelectionRemoved $f $before $expected
$before=Get-CleanupState $f.Root; $all=@(Get-HarnessCleanupPaths $f.Root -All)
Assert ($all.Count -eq 3 -and @($all|Where-Object {-not $_.StartsWith($b.TemporaryPath+'\',[StringComparison]::OrdinalIgnoreCase)}).Count -eq 0) 'Limpeza geral seleciona somente o restante do outro projeto corrente.'
Invoke-HarnessCleanup $f.Root -All -ConfirmText LIMPAR 6>$null|Out-Null
Assert-CleanupSelectionRemoved $f $before $all
Assert (@(Get-HarnessCleanupPaths $f.Root -All).Count -eq 0) 'Limpeza corrente repetida fica vazia sem consultar recibos legados.'

# Journal pendente bloqueia ate a previa; nenhuma recuperacao e executada pela limpeza.
$pending=New-CleanupFixture; $project=$pending.Projects[0]; $current='atual/planejamento/plano.md'
Write-CleanupFixture (Join-Path $project.Folder $current) 'conteudo novo interrompido'
Write-CleanupFixture (Join-Path $project.TemporaryPath ('publicacao/antes/'+$current)) 'conteudo anterior'
Write-CleanupFixture (Join-Path $project.TemporaryPath ('publicacao/depois/'+$current)) 'conteudo novo interrompido'
$journal=ConvertTo-Json -InputObject @(@{Path=$current;Existed=$true;Remove=$false})
Write-CleanupFixture (Join-Path $project.TemporaryPath 'publicacao/recuperacao.json') $journal
Reject-Cleanup $pending { Get-HarnessCleanupPaths $pending.Root -Source $project.Source } 'recupera|publicac|pendente' 'Preview deve recusar journal pendente sem recuperar documentos.'
Reject-Cleanup $pending { Invoke-HarnessCleanup $pending.Root -All -ConfirmText LIMPAR 6>$null } 'recupera|publicac|pendente' 'Limpeza nao deve recuperar publicacao pendente.'

foreach ($mode in @('edit','new','time')) { $changed=New-CleanupFixture; Invoke-CleanupPromptMutation $changed $mode }

# Um produtor em outro processo detem o mutex de operacao, mesmo com preview preparado.
$locked=New-CleanupFixture; $peer=$locked.Projects[1]
$child=Join-Path $locked.Root 'segurar-operacao.ps1'; $ready=Join-Path $locked.Root 'pronto'; $release=Join-Path $locked.Root 'liberar'
[IO.File]::WriteAllText($child,@'
param($ModulePath,$Workspace,$Pom,$Ready,$Release)
$ErrorActionPreference='Stop'
Import-Module $ModulePath -Force -DisableNameChecking
$project=Get-HarnessProjectStorage $Workspace $Pom
$lease=Enter-HarnessProjectAccess $project -ForOperation
try {
    [IO.File]::WriteAllText($Ready,'operacao ativa')
    $deadline=[DateTime]::UtcNow.AddSeconds(30)
    while (-not [IO.File]::Exists($Release) -and [DateTime]::UtcNow -lt $deadline) { Start-Sleep -Milliseconds 25 }
} finally { $lease.ReleaseMutex(); $lease.Dispose() }
'@,(New-Object Text.UTF8Encoding($false)))
$arguments=@('-NoProfile','-ExecutionPolicy','Bypass','-File',('"'+$child+'"'),('"'+(Join-Path $root 'scripts/HarnessProject.psm1')+'"'),('"'+$locked.Root+'"'),('"'+$peer.Pom+'"'),('"'+$ready+'"'),('"'+$release+'"'))
$process=Start-Process powershell.exe -ArgumentList $arguments -WindowStyle Hidden -PassThru
try {
    $deadline=[DateTime]::UtcNow.AddSeconds(10)
    while (-not [IO.File]::Exists($ready) -and -not $process.HasExited -and [DateTime]::UtcNow -lt $deadline) { Start-Sleep -Milliseconds 25 }
    Assert ([IO.File]::Exists($ready)) 'Filho deve deter o mutex antes de testar limpeza.'
    Reject-Cleanup $locked { Invoke-HarnessCleanup $locked.Root -All -ConfirmText LIMPAR 6>$null } 'operac|uso|aguarde|andamento' 'Limpeza geral deve recusar produtor ativo antes de remover o primeiro projeto.'
} finally { [IO.File]::WriteAllText($release,'liberar'); Assert ($process.WaitForExit(10000)) 'Filho deve liberar o mutex e terminar.'; $process.Dispose() }

# Junction em scratch nunca autoriza seguir ou apagar a fonte apontada.
$linked=New-CleanupFixture; $project=$linked.Projects[0]; $link=Join-Path $project.TemporaryPath 'build/junction'
$null=New-Item -ItemType Junction -Path $link -Target $project.Source
try { Reject-Cleanup $linked { Invoke-HarnessCleanup $linked.Root -All -ConfirmText LIMPAR 6>$null } 'junction|link' 'Junction dentro de temporarios bloqueia a limpeza.' }
finally { [IO.Directory]::Delete($link) }

# Source igual ao workspace e permitido; Source/MTA dentro de um candidato nao.
$workspace=New-CleanupFixture -RootSource; $before=Get-CleanupState $workspace.Root
$paths=@(Get-HarnessCleanupPaths $workspace.Root -Source $workspace.Root)
Assert ($paths.Count -eq 3) 'Source no workspace pode limpar somente sua area .harness dedicada.'
Invoke-HarnessCleanup $workspace.Root -Source $workspace.Root -ConfirmText LIMPAR 6>$null|Out-Null
Assert-CleanupSelectionRemoved $workspace $before $paths
foreach ($kind in @('Source','Mta')) {
    $protected=New-CleanupFixture; $project=$protected.Projects[0]
    $inside=Join-Path $project.TemporaryPath ('build/origem-'+$kind)
    $config=Get-Content -LiteralPath $project.ConfigPath -Raw|ConvertFrom-Json
    if ($kind -eq 'Source') { $config.pom=Join-Path $inside 'pom.xml'; Write-CleanupFixture $config.pom '<project><artifactId>a</artifactId></project>' }
    else { $config.mta.diretorio=$inside; Write-CleanupFixture (Join-Path $inside 'index.html') 'MTA configurado'; Write-CleanupFixture (Join-Path $inside 'output.js') 'catalogo configurado' }
    Write-CleanupFixture $project.ConfigPath ($config|ConvertTo-Json -Depth 10)
    Reject-Cleanup $protected { Invoke-HarnessCleanup $protected.Root -All -ConfirmText LIMPAR 6>$null } 'source|fonte|origem|MTA|config|proteg|sobrep' ('Origem configurada dentro do candidato impede apagar: '+$kind)
}
'PASS: limpeza corrente por Source/todos, previa, cancelamento, preservacao, concorrencia e bloqueios.'

# Backups de exercicio sao uma selecao separada de folhas, sem nomes reservados internos.
$backups=New-CleanupFixture; $temporary=Join-Path $backups.Root '.harness/backups-temporarios'
$backupPaths=@(
    (Join-Path $temporary 'ensaio/log.bin'),
    (Join-Path $temporary 'ensaio/temporarios/publicacao/recuperacao.json'),
    (Join-Path $temporary 'ensaio/recebido/nota.md')
)
foreach ($path in $backupPaths) { Write-CleanupFixture $path 'copia humana, nao protocolo ativo' }
$longFile=Join-Path $temporary ('ensaio/'+('x'*200)+'.class')
[IO.File]::WriteAllText(('\\?\'+$longFile),'fixture de backup com caminho longo')
$backupPaths+=@($longFile)
Assert ($longFile.Length -gt 260) 'Fixture de backup realmente cobre caminho longo no Windows.'
$before=Get-CleanupState $backups.Root
$preview=@(Get-HarnessCleanupPaths $backups.Root -TemporaryBackups)
Assert ($preview.Count -eq 4 -and @($backupPaths|Where-Object {$_ -notin $preview}).Count -eq 0) 'Preview de backups retorna somente as quatro folhas exatas, incluindo nomes humanos e caminho longo.'
Assert ((Get-CleanupState $backups.Root) -ceq $before) 'Preview dos backups nao cria nem altera arquivos.'
Assert (@(Get-HarnessCleanupPaths $backups.Root -All|Where-Object {$_.StartsWith($temporary+'\',[StringComparison]::OrdinalIgnoreCase)}).Count -eq 0) 'Limpeza de produtores nao inclui backups temporarios.'
Invoke-HarnessCleanup $backups.Root -TemporaryBackups -ConfirmText cancelar 6>$null|Out-Null
Assert ((Get-CleanupState $backups.Root) -ceq $before) 'Cancelar backups preserva todas as folhas e datas.'
$link=Join-Path $temporary 'junction'; $null=New-Item -ItemType Junction -Path $link -Target $backups.Projects[0].Source
try {
    Reject-Cleanup $backups { Get-HarnessCleanupPaths $backups.Root -TemporaryBackups } 'junction|link' 'Preview de backup recusa junction sem percorrer a fonte.'
    Reject-Cleanup $backups { Invoke-HarnessCleanup $backups.Root -TemporaryBackups -ConfirmText LIMPAR 6>$null } 'junction|link' 'Limpeza de backup recusa junction.'
} finally { [IO.Directory]::Delete($link) }
$before=Get-CleanupState $backups.Root
Invoke-HarnessCleanup $backups.Root -TemporaryBackups -ConfirmText LIMPAR 6>$null|Out-Null
Assert-CleanupSelectionRemoved $backups $before $backupPaths
Assert (-not [IO.Directory]::Exists($temporary)) 'Depois das folhas, somente diretorios vazios devem ser retirados.'
Assert (@(Get-HarnessCleanupPaths $backups.Root -TemporaryBackups).Count -eq 0) 'Repetir preview de backups removidos retorna vazio.'
foreach ($mode in @('edit','new','time')) {
    $changed=New-CleanupFixture
    Write-CleanupFixture (Join-Path $changed.Root '.harness/backups-temporarios/ensaio/log.bin') 'backup observado'
    Invoke-CleanupPromptMutation $changed $mode -TemporaryBackups
}
$protectedBackup=New-CleanupFixture; $project=$protectedBackup.Projects[0]
$configured=Join-Path $protectedBackup.Root '.harness/backups-temporarios/ensaio/mta-configurado'
Write-CleanupFixture (Join-Path $configured 'index.html') 'origem ativa nao e copia descartavel'
$config=Get-Content -LiteralPath $project.ConfigPath -Raw|ConvertFrom-Json
$config.mta.diretorio=$configured; Write-CleanupFixture $project.ConfigPath ($config|ConvertTo-Json -Depth 10)
Reject-Cleanup $protectedBackup { Invoke-HarnessCleanup $protectedBackup.Root -TemporaryBackups -ConfirmText LIMPAR 6>$null } 'origem|MTA|config|proteg|sobrep' 'MTA configurado dentro de backups tambem impede apagar a origem.'
'PASS: backups temporarios isolados, nomes humanos, caminho longo, junction e concorrencia.'

# Troca tardia por junction depois da primeira retirada nao pode atingir original externo.
$late=New-CleanupFixture; $backupRoot=Join-Path $late.Root '.harness/backups-temporarios'
$first=Join-Path $backupRoot 'a/primeiro.bin'; $second=Join-Path $backupRoot 'b/segundo.bin'
$swapped=Join-Path $backupRoot 'c'; $last=Join-Path $swapped 'original.bin'
$outside=Join-Path $late.Root 'originais-externos'; $externalFile=Join-Path $outside 'original.bin'; $moved=Join-Path $late.Root 'pasta-deslocada'
foreach ($path in @($first,$second,$last,$externalFile)) { Write-CleanupFixture $path 'mesmos bytes para provar que hash nao identifica junction' }
[IO.File]::SetLastWriteTimeUtc($externalFile,[IO.File]::GetLastWriteTimeUtc($last))
$externalBefore=Get-CleanupState $outside; $lastBytes=[IO.File]::ReadAllBytes($last)
$module=Get-Module HarnessCleanup
& $module {
    param($Root,$First,$Second,$Swapped,$Moved,$Outside)
    $script:cleanupNativeOriginal=${function:Get-CleanupNativePath}
    $script:lateRoot=$Root; $script:lateFirst=$First; $script:lateSecond=$Second; $script:lateSwapped=$Swapped; $script:lateMoved=$Moved; $script:lateOutside=$Outside; $script:lateInjected=$false
    function script:Get-CleanupNativePath {
        param([string]$Path)
        if (-not $script:lateInjected -and $Path -ieq $script:lateSecond -and -not [IO.File]::Exists($script:lateFirst)) {
            foreach ($item in @($script:lateSwapped,$script:lateMoved,$script:lateOutside)) { if (-not [IO.Path]::GetFullPath($item).StartsWith($script:lateRoot+'\',[StringComparison]::OrdinalIgnoreCase)) { throw 'Destino da fixture fora da area isolada.' } }
            [IO.Directory]::Move($script:lateSwapped,$script:lateMoved)
            $null=New-Item -ItemType Junction -Path $script:lateSwapped -Target $script:lateOutside
            $script:lateInjected=$true
        }
        & $script:cleanupNativeOriginal $Path
    }
} $late.Root $first $second $swapped $moved $outside
$failed=$false
try { Invoke-HarnessCleanup $late.Root -TemporaryBackups -ConfirmText LIMPAR 6>$null|Out-Null }
catch { Assert ($_.Exception.Message -match 'junction|link') $_.Exception.Message; $failed=$true }
finally {
    & $module { ${function:Get-CleanupNativePath}=$script:cleanupNativeOriginal }
    if (Test-Path -LiteralPath $swapped) { if ((Get-Item -LiteralPath $swapped).Attributes -band [IO.FileAttributes]::ReparsePoint) { [IO.Directory]::Delete($swapped) } }
    if ([IO.Directory]::Exists($moved)) { [IO.Directory]::Move($moved,$swapped) }
}
Assert (& $module { $script:lateInjected }) 'Fixture deve trocar a terceira subpasta somente depois da primeira retirada.'
Assert $failed 'Junction inserida durante o loop deve interromper a limpeza restante.'
Assert ((Get-CleanupState $outside) -ceq $externalBefore) 'Original externo com mesmos bytes e data jamais pode ser apagado pela junction tardia.'
Assert ([Convert]::ToBase64String([IO.File]::ReadAllBytes($last)) -ceq [Convert]::ToBase64String($lastBytes)) 'Copia original deslocada pela fixture permanece intacta.'
'PASS: junction inserida apos primeira retirada preserva original externo.'

# O menu real conserva as tres operacoes e preview nao escreve na fixture.
$menu=New-CleanupFixture; $scripts=Join-Path $menu.Root 'scripts'; $null=[IO.Directory]::CreateDirectory($scripts)
foreach ($file in Get-ChildItem -LiteralPath (Join-Path $root 'scripts') -File|Where-Object Name -Match '^Harness.*\.(ps1|psm1)$') { Copy-Item -LiteralPath $file.FullName -Destination (Join-Path $scripts $file.Name) }
Copy-Item -LiteralPath (Join-Path $root 'scripts/limpar-execucoes.ps1') -Destination (Join-Path $scripts 'limpar-execucoes.ps1')
$menuBackup=Join-Path $menu.Root '.harness/backups-temporarios/ensaio/log.bin'; Write-CleanupFixture $menuBackup 'backup de menu'
$before=Get-CleanupState $menu.Root
$menuOutput=@('2')|& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $scripts 'limpar-execucoes.ps1') -Preview 2>&1
$menuText=$menuOutput -join [Environment]::NewLine
Assert ($LASTEXITCODE -eq 0) ('Menu deve executar somente a previa: '+$menuText)
Assert ($menuText -match '1\.[^\r\n]*tempor' -and $menuText -match '2\.[^\r\n]*tempor' -and $menuText -match '3\.[^\r\n]*backups') ('Menu deve conservar 1/2/3 com texto de temporarios correntes e backups: '+$menuText)
Assert ($menuText.Contains((Join-Path $menu.Projects[0].TemporaryPath 'build/tentativa/log.bin'))) 'Opcao 2 em preview deve selecionar folha corrente.'
$menuOutput=@('3')|& powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $scripts 'limpar-execucoes.ps1') -Preview 2>&1
Assert ($LASTEXITCODE -eq 0 -and ($menuOutput -join [Environment]::NewLine).Contains($menuBackup)) 'Opcao 3 em preview seleciona somente backup temporario.'
Assert ((Get-CleanupState $menu.Root) -ceq $before) 'Menus em preview preservam bytes e datas de todos os arquivos.'
'PASS: menus correntes 1/2/3 e preview sem escrita.'
