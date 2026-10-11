# Referencias funcionais: nenhum incidente ou trecho MTA e copiado para a ficha.
function Get-PrioritizationFichaRelativePath {
    param([string]$Category,[string]$Id)
    'atual/priorizacao/'+(ConvertTo-HarnessFunctionalPath $Category)+'/issues/'+(ConvertTo-HarnessFunctionalPath $Id)+'/ficha.md'
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
    param([string]$Base,[string]$Relative,[string]$From)
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
    if (Test-Path -LiteralPath $path -PathType Leaf) { Get-HarnessSourceLink $From $path $Relative }
    else { 'Indisponivel: '+(ConvertTo-ProjectCell $Relative) }
}

function Get-IssueSourcesText {
    param($Project,$Mta,[string]$Id,[string]$Category,[string]$Text,[string]$Path,[switch]$EvidenceOnly)
    $identity=Read-PrioritizationFicha $Text $Project.Name $Category $Id
    $lines=@((Get-HarnessSourceLink $Path $Project.Pom 'POM'),(Get-HarnessSourceLink $Path $Project.MigrationPath 'Decisoes atuais'))
    if ($Mta) {
        $lines+=@((Get-HarnessSourceLink $Path $Mta.ReportPath 'Relatorio MTA atual'),(Get-HarnessSourceLink $Path $Mta.CatalogPath 'Catalogo MTA original'))
        $issue=@($Mta.Issues | Where-Object Id -CEQ $Id)
        if ($issue.Count) { $lines+='Issue presente no MTA atual. Categoria: '+(ConvertTo-ProjectCell $issue[0].Category)+'. Conferir aplicabilidade no codigo local.' }
        else { $lines+='Issue nao reencontrada no MTA atual; ausencia nao comprova resolucao. Avaliacao humana preservada.' }
    } elseif ($EvidenceOnly) { $lines+='Base EVIDENCIAS: MTA nao consultado neste planejamento. Avaliacao humana preservada.' }
    else { $lines+='MTA indisponivel: detalhes nao consultaveis. Avaliacao humana preservada; nao inferir resolucao.' }
    foreach ($relative in $identity.LocalPaths) { $lines+=Get-IssueLocalReference $Project.Source $relative $Path }
    foreach ($relative in $identity.EvidencePaths) { $lines+=Get-IssueLocalReference $Project.EvidencePath $relative $Path }
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
        $id=[Uri]::UnescapeDataString($folder.Name)
        $relative=Get-PrioritizationFichaRelativePath $Category $id
        if ((Split-Path (Split-Path $relative -Parent) -Leaf) -cne $folder.Name) { throw 'Pasta da ficha nao corresponde a chave funcional.' }
        $old=Read-HarnessProjectFiles $Project @($relative)
        if (-not $old[$relative]) { continue }
        $text=Get-IssueSourcesText $Project $Mta $id $Category $old[$relative] (Join-Path $Project.Folder $relative)
        if ($text -cne $old[$relative]) { $writes[$relative]=$text; $expected[$relative]=$old[$relative] }
    }
    if ($writes.Count) { Publish-HarnessProjectFiles $Project $writes $expected }
}
