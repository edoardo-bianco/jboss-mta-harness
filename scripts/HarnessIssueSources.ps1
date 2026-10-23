# Referencias funcionais: nenhum incidente ou trecho MTA e copiado para a ficha.
function ConvertTo-HarnessIssueFolderName {
    param([string]$Id)
    if ([string]::IsNullOrWhiteSpace($Id) -or $Id -match '[\x00-\x1f]') { throw 'ID da issue ausente/invalido.' }
    # Nome de navegacao; a identidade continua sendo o ID literal dentro da ficha.
    $name=$Id.Replace('::','--') -replace '[/\\<>:"|?*%\s]+','-'
    $name=$name.Trim('.',' ')
    if (-not $name -or $name -match '^(?i:CON|PRN|AUX|NUL|COM[0-9]|LPT[0-9])(?:\.|$)') { throw 'ID nao produz pasta legivel valida no Windows.' }
    if ($name.Length -gt 160) { throw 'Nome da ficha excede 160 caracteres; nao sera truncado. Revise a nomenclatura explicitamente.' }
    $name
}

function Get-PrioritizationFichaRelativePath {
    param([string]$Category,[string]$Id,$Project,[switch]$Legacy)
    $prefix='atual/priorizacao/'+(ConvertTo-HarnessFunctionalPath $Category)+'/issues/'
    $relative=$prefix+(ConvertTo-HarnessIssueFolderName $Id)+'/ficha.md'
    try { $old=$prefix+(ConvertTo-HarnessFunctionalPath $Id)+'/ficha.md' }
    catch { $old=$relative } # Chave que nunca cabia no layout antigo.
    if ($Legacy) { return $old }
    if ($Project) {
        $path=Join-Path $Project.Folder $relative
        $legacyPath=Join-Path $Project.Folder $old
        $current=Test-Path -LiteralPath $path -PathType Leaf
        $legacyExists=$old -cne $relative -and (Test-Path -LiteralPath $legacyPath -PathType Leaf)
        if ($current -and $legacyExists) { throw "Duas fichas para $Id. Confira o conteudo e execute a conversao de pastas; nao escolher por tamanho/data." }
        if ($legacyExists) { $relative=$old; $path=$legacyPath }
        if ($current -or $legacyExists) {
            $null=Read-PrioritizationFicha ([IO.File]::ReadAllText((Resolve-ProjectPath $path $Project.Folder))) $Project.Name $Category $Id
        } else {
            $staging=Join-Path $Project.TemporaryPath ('publicacao/depois/'+$relative)
            if ($path.Length -gt 240 -or $staging.Length -ge 248) { throw "Caminho da ficha longo ($($path.Length); publicacao $($staging.Length)): $path. Use uma raiz mais curta; nenhum nome sera truncado." }
        }
    }
    $relative
}

function Read-HarnessFichaAtPath {
    param([string]$Text,[string]$Project,[string]$Relative)
    $block=Find-ProjectManagedBlock $Text 'ficha:identidade'
    if (-not $block) { throw "Ficha sem identidade: $Relative. Preserve o arquivo e confira antes de continuar." }
    $identity=ConvertFrom-Json ($block.Value -replace '^<!-- ficha:identidade:inicio -->\s*','' -replace '\s*<!-- ficha:identidade:fim -->$','')
    $identity=Read-PrioritizationFicha $Text $Project $identity.Category $identity.Id
    $new=Get-PrioritizationFichaRelativePath $identity.Category $identity.Id
    $old=Get-PrioritizationFichaRelativePath $identity.Category $identity.Id -Legacy
    if ($Relative -cne $new -and $Relative -cne $old) { throw "Pasta divergente da identidade da ficha: $Relative" }
    $identity
}

function Assert-HarnessIssueFolderSet {
    param($Issues)
    $seen=New-Object 'Collections.Generic.Dictionary[string,string]' ([StringComparer]::OrdinalIgnoreCase)
    foreach ($issue in $Issues) {
        $key=$issue.Project+'/'+$issue.Category+'/'+(ConvertTo-HarnessIssueFolderName $issue.Id)
        if ($seen.ContainsKey($key) -and $seen[$key] -cne $issue.Id) { throw "Colisao de pastas legiveis: $($seen[$key]) / $($issue.Id). Preserve ambos os IDs; nenhuma ficha sera sobrescrita." }
        $seen[$key]=$issue.Id
    }
}
function Read-PrioritizationFicha {
    param([string]$Text,[string]$Project,[string]$Category,[string]$Id)
    $block=Find-ProjectManagedBlock $Text 'ficha:identidade'
    if (-not $block) { throw "Ficha sem identidade: $Project / $Id" }
    $json=$block.Value -replace '^<!-- ficha:identidade:inicio -->\s*','' -replace '\s*<!-- ficha:identidade:fim -->$',''
    $identity=ConvertFrom-Json $json
    if ($identity.Project -cne $Project -or $identity.Category -cne $Category -or $identity.Id -cne $Id -or
        $identity.LocalPaths -isnot [Array] -or $identity.EvidencePaths -isnot [Array]) { throw "Identidade/referencias da ficha divergentes: $Project / $Id" }
    $identity
}

function Get-IssueLocalReference {
    param([string]$Base,[string]$Relative,[string]$From,[string[]]$AvailablePaths=@())
    # Referencias relativas escolhidas ao examinar codigo/anexos. Nao inferir
    # equivalencia entre caminhos de outra maquina e arquivos locais.
    $decoded=[Uri]::UnescapeDataString($Relative).Replace('\','/')
    if (-not $Relative -or [IO.Path]::IsPathRooted($decoded) -or $decoded -match '(^|/)\.\.(/|$)|[:?*#\x00-\x1f]') { throw 'Referencia da ficha deve ser relativa a Source/evidencias, sem travessia.' }
    $path=[IO.Path]::GetFullPath((Join-Path $Base $Relative))
    if (-not $path.StartsWith($Base.TrimEnd('\','/')+'\',[StringComparison]::OrdinalIgnoreCase)) { throw 'Referencia fora da origem.' }
    $cursor=$path
    while ($cursor -and $cursor.Length -ge $Base.Length) {
        if ((Test-Path -LiteralPath $cursor) -and ((Get-Item -LiteralPath $cursor -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw 'Referencia por link/junction exige conferencia explicita.' }
        $cursor=Split-Path $cursor -Parent
    }
    if ((Test-Path -LiteralPath $path -PathType Leaf) -or $path -iin $AvailablePaths) { Get-HarnessSourceLink $From $path $Relative }
    else { 'Indisponivel: '+(ConvertTo-ProjectCell $Relative) }
}

function Get-IssueSourcesText {
    param($Project,$Mta,[string]$Id,[string]$Category,[string]$Text,[string]$Path,[switch]$EvidenceOnly,[string[]]$AvailablePaths=@())
    $identity=Read-PrioritizationFicha $Text $Project.Name $Category $Id
    $lines=@((Get-HarnessSourceLink $Path $Project.Pom 'POM'),(Get-HarnessSourceLink $Path $Project.MigrationPath 'Decisoes atuais'))
    if ($Category -ceq 'manual') {
        $lines+='Issue manual: fontes humanas e codigo local; sem regra MTA associada.'
        if ($EvidenceOnly) { $lines+='Base EVIDENCIAS: MTA nao consultado nesta base.' }
    } elseif ($Mta) {
        $lines+=Get-HarnessSourceLink $Path $Mta.ReportPath 'Relatorio MTA atual'
        $issue=@($Mta.Issues | Where-Object Id -CEQ $Id)
        if ($issue.Count) { $lines+='Issue presente no MTA atual. Categoria: '+(ConvertTo-ProjectCell $issue[0].Category)+'. Conferir aplicabilidade no codigo local.' }
        else { $lines+='Issue nao reencontrada no MTA atual; ausencia nao comprova resolucao. Avaliacao humana preservada.' }
    } elseif ($EvidenceOnly) { $lines+='Base EVIDENCIAS: MTA nao consultado neste planejamento. Avaliacao humana preservada.' }
    else { $lines+='MTA indisponivel: detalhes nao consultaveis. Avaliacao humana preservada; nao inferir resolucao.' }
    foreach ($relative in $identity.LocalPaths) { $lines+=Get-IssueLocalReference $Project.Source $relative $Path }
    foreach ($relative in $identity.EvidencePaths) { $lines+=Get-IssueLocalReference $Project.EvidencePath $relative $Path $AvailablePaths }
    if (-not $identity.LocalPaths.Count) { $lines+='Sem arquivo local vinculado: registrar a lacuna ou os caminhos relativos efetivamente conferidos em LocalPaths.' }
    Set-ProjectManagedBlock $Text 'ficha:fontes' ($lines -join "`n`n")
}

function Update-PrioritizationFichaSources {
    param($Project,$Mta,[string]$Category)
    $base='atual/priorizacao/'+(ConvertTo-HarnessFunctionalPath $Category)+'/issues'
    $directory=Join-Path $Project.Folder $base
    if (-not (Test-Path -LiteralPath $directory -PathType Container)) { return }
    $writes=@{}; $expected=@{}
    foreach ($folder in Get-ChildItem -LiteralPath $directory -Directory) {
        $relative=$base+'/'+$folder.Name+'/ficha.md'
        $old=Read-HarnessProjectFiles $Project @($relative)
        if (-not $old[$relative]) { continue }
        $identity=Read-HarnessFichaAtPath $old[$relative] $Project.Name $relative
        $id=$identity.Id
        $null=Get-PrioritizationFichaRelativePath $Category $id -Project $Project
        $text=Get-IssueSourcesText $Project $Mta $id $Category $old[$relative] (Join-Path $Project.Folder $relative) -EvidenceOnly:($Category -ceq 'manual')
        if ($text -cne $old[$relative]) { $writes[$relative]=$text; $expected[$relative]=$old[$relative] }
    }
    if ($writes.Count) { Publish-HarnessProjectFiles $Project $writes $expected }
}
