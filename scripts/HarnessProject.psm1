Import-Module (Join-Path $PSScriptRoot 'HarnessDocumentTemplates.psm1') -DisableNameChecking
#requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'

function Resolve-ProjectPath {
    param([string]$Path,[string]$Root)
    if ([string]::IsNullOrWhiteSpace($Path) -or $Path -match '[*?\x00-\x1f]') { throw 'Caminho ausente/invalido.' }
    if (-not [IO.Path]::IsPathRooted($Path)) { $Path=Join-Path $Root $Path }
    $full=[IO.Path]::GetFullPath($Path).TrimEnd('\','/')
    if ($full -notmatch '^[A-Za-z]:\\') { throw 'Use caminho local absoluto ou relativo ao workspace.' }
    $cursor=$full
    while ($cursor) {
        if ((Test-Path -LiteralPath $cursor) -and ((Get-Item -LiteralPath $cursor -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw "Link/junction nao suportado: $cursor" }
        $parent=Split-Path $cursor -Parent
        if ($parent -eq $cursor) { break }
        $cursor=$parent
    }
    $full
}

function Get-HarnessProjectReference {
    param([Parameter(Mandatory=$true)][string]$Root,[Parameter(Mandatory=$true)][string]$Pom,[scriptblock]$FileReader)
    $Root=Resolve-ProjectPath ([IO.Path]::GetFullPath($Root)) $Root
    $Pom=Resolve-ProjectPath $Pom $Root
    if (-not (Test-Path -LiteralPath $Pom -PathType Leaf)) { throw "POM ausente: $Pom" }
    $settings=New-Object Xml.XmlReaderSettings
    $settings.DtdProcessing=[Xml.DtdProcessing]::Prohibit; $settings.XmlResolver=$null
    $inputReader=if ($FileReader) { New-Object IO.StringReader ([string](& $FileReader $Pom)) } else { $null }
    $reader=if ($inputReader) { [Xml.XmlReader]::Create($inputReader,$settings) } else { [Xml.XmlReader]::Create($Pom,$settings) }
    try {
        $xml=New-Object Xml.XmlDocument; $xml.XmlResolver=$null; $xml.Load($reader)
        $nodes=$xml.SelectNodes("/*[local-name()='project']/*[local-name()='artifactId']")
        if ($nodes.Count -ne 1) { throw 'POM deve declarar um project.artifactId literal.' }
        $name=$nodes[0].InnerText.Trim()
    } finally { $reader.Dispose(); if ($inputReader) { $inputReader.Dispose() } }
    if (-not $name -or $name -match '[<>:"/\\|?*\x00-\x1f]' -or $name.Contains('${') -or $name -match '[. ]$' -or $name -match '^(?i:CON|PRN|AUX|NUL|COM[0-9]|LPT[0-9])(?:\.|$)' -or $name.Length -gt 255) { throw 'artifactId nao pode ser usado como pasta literal no Windows; confira o POM.' }
    $folder=Resolve-ProjectPath (Join-Path $Root ('.harness/projetos/'+$name)) $Root
    $configPath=Join-Path $folder 'projeto.json'
    $project=[pscustomobject]@{Root=$Root;Name=$name;Pom=$Pom;Source=(Split-Path $Pom -Parent);Folder=$folder;ConfigPath=$configPath;
        IndexPath=(Join-Path $folder 'indice.md');MigrationPath=(Join-Path $folder 'migracao.md');
        PlanPath=(Join-Path $folder 'atual/planejamento/plano.md');TodoPath=(Join-Path $folder 'atual/planejamento/tarefas.md');
        ContextPath=(Join-Path $folder 'atual/planejamento/contexto.json');EvidencePath=(Join-Path $folder 'evidencias');
        ReconciledPath=(Join-Path $folder 'reconciliado');TemporaryPath=(Join-Path $folder 'temporarios')}
    $project
}

function Get-HarnessProjectStorage {
    param([Parameter(Mandatory=$true)][string]$Root,[Parameter(Mandatory=$true)][string]$Pom,[switch]$ReadCommitted)
    $project=Get-HarnessProjectReference $Root $Pom
    $Root=$project.Root; $Pom=$project.Pom; $folder=$project.Folder; $name=$project.Name
    $documents=Read-HarnessProjectFiles $project @('projeto.json') -ReadCommitted:$ReadCommitted
    if ($documents['projeto.json']) {
        $config=ConvertFrom-Json $documents['projeto.json']
        if ((Resolve-ProjectPath $config.pom $Root) -ine $Pom) { throw "Colisao de artifactId: $name. Confira a associacao ao POM ou use outra raiz de dados." }
    }
    $base=Join-Path $Root '.harness/projetos'
    if (Test-Path -LiteralPath $base -PathType Container) {
        foreach ($other in Get-ChildItem -LiteralPath $base -Directory) {
            if ($other.FullName -ieq $folder) { continue }
            $association=Join-Path $other.FullName 'projeto.json'
            if (-not (Test-Path -LiteralPath $association -PathType Leaf)) { continue }
            $config=Get-Content -LiteralPath $association -Raw -Encoding UTF8 | ConvertFrom-Json
            if ((Resolve-ProjectPath $config.pom $Root) -ieq $Pom) { throw "artifactId alterado: realinhe explicitamente a pasta $($other.FullName) e seus links." }
        }
    }
    $project
}

function Initialize-HarnessProjectStorage {
    param([string]$Root,[string]$Pom)
    $project=Get-HarnessProjectStorage -Root $Root -Pom $Pom
    if (-not (Test-Path -LiteralPath $project.ConfigPath -PathType Leaf)) {
        $json=[ordered]@{pom=$project.Pom;mta=[ordered]@{diretorio=$null}} | ConvertTo-Json
        Publish-HarnessProjectFiles $project @{'projeto.json'=$json} @{'projeto.json'=$null}
    }
    $project
}

function ConvertTo-HarnessFunctionalPath {
    param([string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) { throw 'Chave funcional ausente.' }
    $encoded=-join @([Text.Encoding]::UTF8.GetBytes($Value) | ForEach-Object {
        if (($_ -ge 97 -and $_ -le 122) -or ($_ -ge 48 -and $_ -le 57) -or $_ -in @(45,46,95)) { [char]$_ } else { '%'+$_.ToString('X2') }
    })
    if ($encoded -match '^(con|prn|aux|nul|com[0-9]|lpt[0-9])(?:\.|$)') { $encoded='%'+([int][char]$encoded[0]).ToString('X2')+$encoded.Substring(1) }
    while ($encoded.EndsWith('.')) { $encoded=$encoded.Substring(0,$encoded.Length-1)+'%2E' }
    if ($encoded.Length -gt 160) { throw 'Chave funcional excede o limite de caminho; use raiz de dados curta e revise a chave, sem truncar ou gerar hash.' }
    $encoded
}

function ConvertTo-HarnessFileUri {
    param([Parameter(Mandatory=$true)][string]$Path)
    # O argumento e um caminho LITERAL, nao uma URL. O construtor Uri em modo
    # DOS interpreta percentuais diferentemente no .NET do PS5.1 e do PS7.
    # Construir file:// explicitamente preserva %44 como nome, nao como D.
    $full=[IO.Path]::GetFullPath($Path).Replace('\','/')
    $segments=@($full.Split('/') | ForEach-Object { [Uri]::EscapeDataString($_) })
    if ($full -match '^[A-Za-z]:/') {
        $segments[0]=$full.Substring(0,2)
        return [Uri]('file:///'+($segments -join '/'))
    }
    if ($full.StartsWith('//')) { return [Uri]('file:'+($segments -join '/')) }
    throw 'URI de arquivo exige caminho absoluto Windows.'
}

function Get-HarnessSourceLink {
    param([string]$From,[string]$Path,[string]$Label='Abrir')
    $fromUri=ConvertTo-HarnessFileUri $From
    $targetUri=ConvertTo-HarnessFileUri $Path
    $relative=$fromUri.MakeRelativeUri($targetUri).OriginalString
    if ([IO.Path]::GetPathRoot($fromUri.LocalPath) -ine [IO.Path]::GetPathRoot($targetUri.LocalPath)) { $relative=$targetUri.AbsoluteUri }
    '['+($Label -replace '[\[\]\r\n]',' ')+'](<'+$relative+'>)'
}

Export-ModuleMember -Function Get-HarnessProjectStorage,Initialize-HarnessProjectStorage,ConvertTo-HarnessFunctionalPath,ConvertTo-HarnessFileUri,Get-HarnessSourceLink
Export-ModuleMember -Function Get-HarnessProjectReference
. (Join-Path $PSScriptRoot 'HarnessProjectPublication.ps1')
Export-ModuleMember -Function Publish-HarnessProjectFiles,Read-HarnessProjectFiles,Enter-HarnessProjectAccess
. (Join-Path $PSScriptRoot 'HarnessProjectMta.ps1')
Export-ModuleMember -Function Read-HarnessProjectMta,Read-HarnessMtaDirectory
. (Join-Path $PSScriptRoot 'HarnessProjectDocuments.ps1')
Export-ModuleMember -Function Update-HarnessProjectDocuments,Get-HarnessProjectDecisions,Get-HarnessMigrationCounts,Get-HarnessMigrationCountText
Export-ModuleMember -Function Get-HarnessProjectMigrationText,Read-ProjectDecisionRows,Resolve-ProjectPath
Export-ModuleMember -Function Find-ProjectManagedBlock,Set-ProjectManagedBlock,ConvertTo-ProjectCell,Get-ProjectOperationsText

function Publish-HarnessWorkspaceIndex {
    param([string]$Root,[string]$Text)
    $folder=Resolve-ProjectPath '.harness/indices' $Root
    # Infrastructure destination; this does not create a Maven project.
    $destination=[pscustomobject]@{Folder=$folder;TemporaryPath=(Join-Path $folder 'temporarios')}
    Publish-HarnessProjectFiles $destination @{'projetos.md'=$Text}
    Join-Path $folder 'projetos.md'
}
Export-ModuleMember -Function Publish-HarnessWorkspaceIndex
. (Join-Path $PSScriptRoot 'HarnessProjectOperations.ps1')
Export-ModuleMember -Function Set-HarnessProjectOperation,Get-HarnessProjectOperationText,Get-HarnessProjectTemporary,Remove-HarnessProjectTemporary,Get-HarnessProjectTreePublication
Export-ModuleMember -Function Get-HarnessProjectMtaLog
. (Join-Path $PSScriptRoot 'HarnessProjectReadRoots.ps1')
Export-ModuleMember -Function Get-HarnessProjectReadRoots

Export-ModuleMember -Function Get-HarnessTemplateLinks
