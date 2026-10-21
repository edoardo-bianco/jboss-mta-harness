# Internal publication protocol. Recovery files exist only while publishing or
# recovering; no operation ID or persistent receipt is used to read the project.
function Resolve-ProjectDocument {
    param($Project,[string]$RelativePath,[switch]$TemporaryRemoval)
    if ([IO.Path]::IsPathRooted($RelativePath) -or $RelativePath -match '(^|[\\/])\.\.([\\/]|$)') { throw 'Documento fora dos destinos correntes.' }
    if ($TemporaryRemoval) {
        if ($RelativePath.Replace('\','/') -cnotmatch '^temporarios/(build|mta|sonar)/[^/](?:.*[^/])?$') { throw 'Remocao temporaria limitada a folhas de build, mta e sonar.' }
    } elseif ($RelativePath -match '(^|[\\/])temporarios([\\/]|$)') { throw 'Documento fora dos destinos correntes.' }
    $path=Resolve-ProjectPath $RelativePath $Project.Folder
    if (-not $path.StartsWith($Project.Folder+'\',[StringComparison]::OrdinalIgnoreCase)) { throw 'Documento fora do projeto.' }
    $path
}
function Get-ProjectRecoveryDestination {
    param($Project,$Entry)
    $temporaryRemoval=$false
    if ($Entry.PSObject.Properties['TemporaryRemoval']) {
        if ($Entry.TemporaryRemoval -isnot [bool]) { throw 'Marcador de remocao temporaria invalido.' }
        $temporaryRemoval=$Entry.TemporaryRemoval
        if ($temporaryRemoval -and ($Entry.Remove -isnot [bool] -or -not $Entry.Remove)) { throw 'Recuperacao temporaria exige remocao explicita.' }
    }
    Resolve-ProjectDocument $Project $Entry.Path -TemporaryRemoval:$temporaryRemoval
}

function Clear-ProjectPublicationFiles {
    param($Project)
    # Windows scanners/editors may briefly hold a directory without delete
    # sharing. Retry cleanup only; never replay the completed publication.
    for ($attempt=0;$attempt -lt 8;$attempt++) {
        try {
            $temporary=Resolve-ProjectPath (Join-Path $Project.TemporaryPath 'publicacao') $Project.Folder
            if (-not $temporary.StartsWith($Project.Folder+'\temporarios\',[StringComparison]::OrdinalIgnoreCase)) { throw 'Area de recuperacao invalida.' }
            if (Test-Path -LiteralPath $temporary) {
                $pending=New-Object 'Collections.Generic.Stack[IO.DirectoryInfo]'
                $pending.Push((Get-Item -LiteralPath $temporary))
                while ($pending.Count) {
                    foreach ($child in $pending.Pop().EnumerateFileSystemInfos()) {
                        if ($child.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Link/junction na area de recuperacao.' }
                        if ($child -is [IO.DirectoryInfo]) { $pending.Push($child) }
                    }
                }
                [IO.Directory]::Delete($temporary,$true)
            }
            if ((Test-Path -LiteralPath $Project.TemporaryPath) -and -not @(Get-ChildItem -LiteralPath $Project.TemporaryPath -Force).Count) { [IO.Directory]::Delete($Project.TemporaryPath) }
            return
        } catch {
            $failure=$_.Exception.GetBaseException()
            $code=$failure.HResult -band 0xffff
            if ($failure -isnot [IO.IOException] -or $code -ne 32 -or $attempt -eq 7) { throw }
            Start-Sleep -Milliseconds 200
        }
    }
}

function Remove-ProjectPublication {
    param($Project)
    # Commit/rollback is complete. Remove the recovery instruction first, so a
    # crash halfway through cleanup never interprets remaining files as a write.
    $journal=Resolve-ProjectPath (Join-Path $Project.TemporaryPath 'publicacao/recuperacao.json') $Project.Folder
    if (Test-Path -LiteralPath $journal -PathType Leaf) { [IO.File]::Delete($journal) }
    Clear-ProjectPublicationFiles $Project
}

function Test-ProjectFileBytes {
    param([string]$Left,[string]$Right)
    if (-not (Test-Path -LiteralPath $Left -PathType Leaf) -or -not (Test-Path -LiteralPath $Right -PathType Leaf)) { return $false }
    [Convert]::ToBase64String([IO.File]::ReadAllBytes($Left)) -ceq [Convert]::ToBase64String([IO.File]::ReadAllBytes($Right))
}

function Restore-ProjectPublication {
    param($Project)
    $temporary=Join-Path $Project.TemporaryPath 'publicacao'
    if (-not (Test-Path -LiteralPath $temporary)) { return }
    $null=Resolve-ProjectPath $temporary $Project.Folder
    $journal=Join-Path $temporary 'recuperacao.json'
    if (Test-Path -LiteralPath $journal) {
        $entries=Get-Content -LiteralPath $journal -Raw -Encoding UTF8 | ConvertFrom-Json
        # Validate the complete recovery set before changing any document. An
        # editor that changed a file outside our lock must not lose its changes.
        foreach ($entry in $entries) {
            $destination=Get-ProjectRecoveryDestination $Project $entry
            $before=Resolve-ProjectPath (Join-Path $temporary ('antes/'+$entry.Path)) $Project.Folder
            $after=Resolve-ProjectPath (Join-Path $temporary ('depois/'+$entry.Path)) $Project.Folder
            $removed=$entry.PSObject.Properties['Remove'] -and $entry.Remove
            if ((-not $removed -and -not (Test-Path -LiteralPath $after -PathType Leaf)) -or ($entry.Existed -and -not (Test-Path -LiteralPath $before -PathType Leaf))) { throw 'Conjunto de recuperacao incompleto; preserve temporarios.' }
            if ((Test-Path -LiteralPath $destination) -and -not (-not $removed -and (Test-ProjectFileBytes $destination $after)) -and -not ($entry.Existed -and (Test-ProjectFileBytes $destination $before))) { throw "Edicao concorrente durante recuperacao: $destination. Preserve e concilie os arquivos em temporarios/publicacao." }
        }
        foreach ($entry in $entries) {
            $destination=Get-ProjectRecoveryDestination $Project $entry
            if ($entry.Existed -and -not (Test-ProjectFileBytes $destination (Join-Path $temporary ('antes/'+$entry.Path)))) {
                $working=Join-Path $temporary 'restaurar.tmp'
                [IO.File]::Copy((Join-Path $temporary ('antes/'+$entry.Path)),$working,$true)
                Write-ProjectPublishedFile $working $destination
            }
            elseif (-not $entry.Existed -and (Test-Path -LiteralPath $destination -PathType Leaf)) { [IO.File]::Delete($destination) }
        }
    }
    Remove-ProjectPublication $Project
}

function Enter-HarnessProjectAccess {
    param($Project,[switch]$ForOperation,[switch]$ReadOnly,[switch]$ReadCommitted)
    if ($ForOperation -and $ReadOnly) { throw 'Operacao e leitura pura sao acessos distintos.' }
    if ($ReadCommitted -and ($ForOperation -or $ReadOnly)) { throw 'Leitura confirmada exige acesso proprio.' }
    # Only an OS mutex name: this digest is never saved in project data or used
    # for identity, navigation, history or authorization.
    $sha=[Security.Cryptography.SHA256]::Create()
    try { $name=[BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($Project.Folder.ToLowerInvariant()))).Replace('-','') }
    finally { $sha.Dispose() }
    if ($ForOperation) { $name+='_operation' }
    $mutex=New-Object Threading.Mutex($false,('Local\HarnessProject_'+$name))
    $acquired=$false
    try {
        try { $acquired=$mutex.WaitOne(0) } catch [Threading.AbandonedMutexException] { $acquired=$true }
        if (-not $acquired) { throw 'Projeto em uso por outra operacao; aguarde terminar.' }
        if ($ForOperation) {
            # Long-running tools serialize with each other. Readers may still
            # inspect the complete current state while the next one is prepared.
            $publication=Enter-HarnessProjectAccess $Project
            try { } finally { $publication.ReleaseMutex(); $publication.Dispose() }
        } elseif ($ReadCommitted) {
            # No journal means either preparation never reached publication or
            # the whole write/rollback finished. Leftover cleanup cannot change
            # current documents. Keep the mutex and reject an actual journal.
            $temporary=Resolve-ProjectPath (Join-Path $Project.TemporaryPath 'publicacao') $Project.Folder
            if (Test-Path -LiteralPath (Join-Path $temporary 'recuperacao.json')) { throw 'Recuperacao de publicacao pendente; leitura confirmada exige recuperar os documentos primeiro.' }
        } elseif ($ReadOnly) {
            if (Test-Path -LiteralPath (Join-Path $Project.TemporaryPath 'publicacao')) { throw 'Recuperacao de publicacao pendente; consulta somente leitura nao altera o projeto. Atualize o indice antes de consultar.' }
        } else { Restore-ProjectPublication $Project }
        return $mutex
    } catch { if ($acquired) { $mutex.ReleaseMutex() }; $mutex.Dispose(); throw }
}

function Invoke-WithProjectAccess {
    param($Project,[scriptblock]$Action)
    $mutex=Enter-HarnessProjectAccess $Project
    try { & $Action } finally { $mutex.ReleaseMutex(); $mutex.Dispose() }
}

function Write-ProjectPublishedFile {
    param([string]$Source,[string]$Destination)
    $null=[IO.Directory]::CreateDirectory((Split-Path $Destination -Parent))
    if (Test-Path -LiteralPath $Destination -PathType Leaf) {
        $original=[Convert]::ToBase64String([IO.File]::ReadAllBytes($Destination))
        for ($attempt=0;$attempt -lt 8;$attempt++) {
            if (-not (Test-Path -LiteralPath $Destination -PathType Leaf) -or [Convert]::ToBase64String([IO.File]::ReadAllBytes($Destination)) -cne $original) { throw 'Documento editado durante a substituicao; preserve a contribuicao externa.' }
            try { [IO.File]::Replace($Source,$Destination,[System.Management.Automation.Language.NullString]::Value); break }
            catch {
                $code=$_.Exception.GetBaseException().HResult -band 0xffff
                if ($code -notin @(32,1175) -or $attempt -eq 7) { throw }
                Start-Sleep -Milliseconds 200
            }
        }
    } else { [IO.File]::Move($Source,$Destination) }
}

function Write-ProjectRecoveryInstruction {
    param([string]$Temporary,$Entries)
    $preparing=Join-Path $Temporary 'recuperacao.tmp'
    [IO.File]::WriteAllText($preparing,(ConvertTo-Json -InputObject @($Entries)),(New-Object Text.UTF8Encoding($false)))
    [IO.File]::Move($preparing,(Join-Path $Temporary 'recuperacao.json'))
}

function Publish-HarnessProjectFiles {
    param($Project,[Collections.IDictionary]$Files,[Collections.IDictionary]$Expected=@{},[switch]$RemoveTemporaryFiles)
    if (-not $Files -or -not $Files.Count) { throw 'Nenhum documento para publicar.' }
    if ($RemoveTemporaryFiles) {
        foreach ($relative in $Files.Keys) {
            $null=Resolve-ProjectDocument $Project $relative -TemporaryRemoval
            if ($null -ne $Files[$relative] -or -not $Expected.Contains($relative) -or $Expected[$relative] -isnot [byte[]]) { throw 'Remocao temporaria exige valor null e Expected byte[] para cada folha.' }
        }
    }
    Invoke-WithProjectAccess $Project {
        $paths=@{}
        foreach ($relative in $Files.Keys) {
            $path=Resolve-ProjectDocument $Project $relative -TemporaryRemoval:$RemoveTemporaryFiles
            if ($paths.ContainsKey($path)) { throw 'Destinos duplicados na publicacao.' }
            $paths[$path]=$true
        }
        foreach ($relative in $Expected.Keys) {
            $path=Resolve-ProjectDocument $Project $relative -TemporaryRemoval:$RemoveTemporaryFiles
            $equal=$false
            if ($Expected[$relative] -is [byte[]]) {
                $equal=(Test-Path -LiteralPath $path -PathType Leaf) -and
                    [Convert]::ToBase64String([IO.File]::ReadAllBytes($path)) -ceq [Convert]::ToBase64String($Expected[$relative])
            } else {
                $current=if (Test-Path -LiteralPath $path -PathType Leaf) { [IO.File]::ReadAllText($path) } else { $null }
                $equal=$current -ceq $Expected[$relative]
            }
            if (-not $equal) { throw "Documento alterado desde a leitura: $path" }
        }
        $temporary=Join-Path $Project.TemporaryPath 'publicacao'
        $entries=@()
        try {
            foreach ($relative in $Files.Keys) {
                $path=Resolve-ProjectDocument $Project $relative -TemporaryRemoval:$RemoveTemporaryFiles
                $after=Join-Path $temporary ('depois/'+$relative)
                $null=[IO.Directory]::CreateDirectory((Split-Path $after -Parent))
                if ($null -ne $Files[$relative]) {
                    if ($Files[$relative] -is [byte[]]) { [IO.File]::WriteAllBytes($after,$Files[$relative]) }
                    else { [IO.File]::WriteAllBytes($after,(New-Object Text.UTF8Encoding($false)).GetBytes([string]$Files[$relative])) }
                }
                $existed=Test-Path -LiteralPath $path -PathType Leaf
                if ($existed) {
                    $before=Join-Path $temporary ('antes/'+$relative)
                    $null=[IO.Directory]::CreateDirectory((Split-Path $before -Parent))
                    [IO.File]::Copy($path,$before)
                }
                $entry=@{Path=$relative;Existed=$existed;Remove=($null -eq $Files[$relative])}
                if ($RemoveTemporaryFiles) { $entry.TemporaryRemoval=$true }
                $entries+=$entry
            }
            Write-ProjectRecoveryInstruction $temporary $entries
            foreach ($entry in $entries) {
                $path=Resolve-ProjectDocument $Project $entry.Path -TemporaryRemoval:$RemoveTemporaryFiles
                if ($entry.Existed) {
                    if (-not (Test-ProjectFileBytes $path (Join-Path $temporary ('antes/'+$entry.Path)))) { throw "Documento alterado durante publicacao: $path" }
                } elseif (Test-Path -LiteralPath $path) { throw "Documento criado durante publicacao: $path" }
                # Keep the prepared file for crash recovery; Replace consumes
                # its source, so use a single transient working file.
                if ($entry.Remove) { [IO.File]::Delete($path) }
                else {
                    $working=Join-Path $temporary 'escrita.tmp'
                    [IO.File]::Copy((Join-Path $temporary ('depois/'+$entry.Path)),$working,$true)
                    Write-ProjectPublishedFile $working $path
                }
            }
            Remove-ProjectPublication $Project
        } catch {
            $failure=$_
            try { Restore-ProjectPublication $Project }
            catch { throw ("Publicacao falhou: {0}. Recuperacao pendente: {1}" -f $failure.Exception.Message,$_.Exception.Message) }
            throw $failure
        }
    }
}

function Read-HarnessProjectFiles {
    param($Project,[string[]]$Paths,[switch]$AsBytes,[switch]$ReadCommitted)
    $access=Enter-HarnessProjectAccess $Project -ReadCommitted:$ReadCommitted
    try {
        $result=[ordered]@{}
        foreach ($relative in $Paths) {
            $path=Resolve-ProjectDocument $Project $relative
            $result[$relative]=$null
            if (Test-Path -LiteralPath $path -PathType Leaf) {
                if ($AsBytes) { $result[$relative]=[IO.File]::ReadAllBytes($path) }
                else { $result[$relative]=[IO.File]::ReadAllText($path) }
            }
        }
        $result
    } finally { $access.ReleaseMutex(); $access.Dispose() }
}
