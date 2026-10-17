# Leitura corrente usa a mesma identidade e descoberta MTA dos produtores.
function Enter-QueryProject {
    param([string]$Folder)
    $folder=Resolve-QueryPath $Folder $Folder
    if ($script:QueryLeases.ContainsKey($folder)) { return }
    $reference=[pscustomobject]@{Folder=$folder;TemporaryPath=(Join-Path $folder 'temporarios')}
    try { $script:QueryLeases[$folder]=Enter-HarnessProjectAccess $reference -ReadOnly }
    catch { Stop-QueryError BASE_BUSY $_.Exception.Message }
}

function Read-QueryProject {
    param($Selected,[string]$Root,$Files)
    $pom=Resolve-QueryPath $Selected.Pom $Root
    $source=Resolve-QueryPath $Selected.Source $Root
    $project=Get-HarnessProjectReference $Root $pom -FileReader {param($p) Read-QueryFile $p $Files}
    if ($project.Name -cne $Selected.Project -or $project.Source -ine $source -or
        (Resolve-QueryPath $Selected.MigrationPath $Root) -ine $project.MigrationPath) { Stop-QueryError IDENTITY_CONFLICT 'Projeto, POM, Source ou registro divergente.' }
    Enter-QueryProject $project.Folder
    $configuration=Read-QueryFile $project.ConfigPath $Files | ConvertFrom-Json
    if ((Resolve-QueryPath $configuration.pom $Root) -ine $pom) { Stop-QueryError IDENTITY_CONFLICT 'POM difere da associacao local do projeto.' }
    [pscustomobject]@{Project=$project;Configuration=$configuration}
}

function Read-QueryCurrentMta {
    param($Project,$Configuration,[string]$Root,$Files)
    $external=Get-QueryProperty (Get-QueryProperty $Configuration 'mta') 'diretorio'
    $origin=if ($external) {Resolve-QueryPath $external $Root} else {Resolve-QueryPath (Join-Path $Project.Folder 'atual/diagnosticos/mta') $Root}
    try {
        $directory=Get-Item -LiteralPath $origin -Force -ErrorAction Stop
        if (-not $directory.PSIsContainer) { Stop-QueryError INVALID_CONTEXT 'Origem MTA deve ser diretorio.' }
        Read-HarnessMtaDirectory $Project $origin -FileReader {param($p) Read-QueryFile $p $Files}
    }
    catch {
        if ($_.Exception.Data.Contains('QueryCode')) { throw }
        if ($_.Exception.Data.Contains('MtaChanged')) { Stop-QueryError BASE_CHANGED $_.Exception.Message }
        $failure=Get-QueryError $_
        if ($failure.Code -ne 'INVALID_CONTEXT') { Stop-QueryError $failure.Code $failure.Message }
        Stop-QueryError UNSUPPORTED_FORMAT $_.Exception.Message
    }
}
