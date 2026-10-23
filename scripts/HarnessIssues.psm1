#requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'HarnessProject.psm1') -DisableNameChecking
Import-Module (Join-Path $PSScriptRoot 'HarnessDocumentTemplates.psm1') -DisableNameChecking
. (Join-Path $PSScriptRoot 'HarnessIssueSources.ps1')

function Get-HarnessIssuePath {
    param($Project,[string]$Category,[string]$Id)
    Join-Path $Project.Folder (Get-PrioritizationFichaRelativePath $Category $Id -Project $Project)
}

function Register-HarnessManualIssue {
    [CmdletBinding()]
    param($Project,[Parameter(Mandatory=$true)][string]$Id,[Parameter(Mandatory=$true)][string]$Title,
        [string[]]$LocalPaths=@(),[string[]]$EvidencePaths=@())
    if ($Id -cnotmatch '^DEV-[A-Za-z0-9][A-Za-z0-9._-]*$' -or $Id.EndsWith('.')) { throw 'Issue manual exige ID DEV-... legivel, sem separadores de pasta.' }
    if ([string]::IsNullOrWhiteSpace($Title)) { throw 'Informe o titulo do achado.' }
    $lease=Enter-HarnessProjectAccess $Project -ForOperation
    try {
        $relative=Get-PrioritizationFichaRelativePath manual $Id -Project $Project
        if ($relative -cne (Get-PrioritizationFichaRelativePath manual $Id)) { throw 'Ficha antiga codificada: converta as pastas antes de cadastrar novamente; nao sera criada outra ficha.' }
        $old=Read-HarnessProjectFiles $Project @('migracao.md','indice.md',$relative)
        if (-not $old['migracao.md']) { throw 'Atualize o indice dos projetos para criar o registro antes de cadastrar a issue.' }
        $rows=@(Read-ProjectDecisionRows $old['migracao.md'])
        Assert-HarnessIssueFolderSet @(@($rows | ForEach-Object { [pscustomobject]@{Project=$Project.Name;Category=$_.Category;Id=$_.Id} })+[pscustomobject]@{Project=$Project.Name;Category='manual';Id=$Id})
        $row=@($rows | Where-Object Id -CEQ $Id)
        if ($row.Count -and ($row[0].Category -cne 'manual' -or $row[0].Presence -cne 'MANUAL')) { throw 'ID existente nao e uma issue manual; preserve a identidade.' }
        $path=Join-Path $Project.Folder $relative
        $link=Get-HarnessSourceLink $Project.MigrationPath $path 'Ficha'
        $writes=@{}
        if (-not $old[$relative]) {
            $identity=[ordered]@{Project=$Project.Name;Category='manual';Id=$Id;LocalPaths=@($LocalPaths);EvidencePaths=@($EvidencePaths)}
            $text=Expand-HarnessDocumentTemplate 'ficha-issue' @{
                Project=$Project.Name;Id=$Id;IdentityJson=($identity|ConvertTo-Json -Compress);
                Finding='PENDENTE: examinar o achado e separar fatos, hipoteses e lacunas.';
                Assessment='PENDENTE: avaliar aplicabilidade, risco e alcance.';
                Steps='PENDENTE: definir roteiro e verificacoes com base nas evidencias.';
                ReferencesAndLimits='Cadastro inicial; nao comprova analise, corretiva, GO ou aceite.';Sources=''
            }
            $writes[$relative]=Get-IssueSourcesText $Project $null $Id manual $text $path -EvidenceOnly
        }
        if (-not $row.Count) {
            $line='| '+((@($Id,$Title,'manual','-','MANUAL','A DEFINIR','NAO ANALISADA') | ForEach-Object {ConvertTo-ProjectCell $_}) -join ' | ')+' | '+$link+' |'
            $writes['migracao.md']=$old['migracao.md'].Replace('<!-- mta:fim -->',$line+[Environment]::NewLine+'<!-- mta:fim -->')
        } elseif (-not $row[0].Note.Contains($link)) {
            # Repara somente o vinculo da ficha; texto/decisao/andamento ficam intactos.
            $block=Find-ProjectManagedBlock $old['migracao.md'] 'mta'
            $lines=$block.Value -split '(?<=\n)'
            for ($i=0;$i -lt $lines.Count;$i++) {
                if ($lines[$i] -match '^\|\s*([^|]+)\|') {
                    if ([Net.WebUtility]::HtmlDecode($Matches[1].Trim()) -ceq $Id) {
                        $lines[$i]=[regex]::Replace($lines[$i],'\[Ficha\]\((?:<[^>]+>|[^)]+)\)',[Text.RegularExpressions.MatchEvaluator]{param($m) $link})
                        if (-not $lines[$i].Contains($link)) { $lines[$i]=[regex]::Replace($lines[$i],'\|\s*(\r?\n)?$',(' / '+$link+' |'+'$1')) }
                    }
                }
            }
            $writes['migracao.md']=$old['migracao.md'].Substring(0,$block.Index)+($lines -join '')+$old['migracao.md'].Substring($block.Index+$block.Length)
        }
        $migration=if ($writes.ContainsKey('migracao.md')) {$writes['migracao.md']} else {$old['migracao.md']}
        if ($old['indice.md']) {
            $index=Set-ProjectManagedBlock $old['indice.md'] 'issues:totais' (Get-HarnessMigrationCountText $migration)
            if ($index -cne $old['indice.md']) { $writes['indice.md']=$index }
        }
        if ($writes.Count) { Publish-HarnessProjectFiles $Project $writes $old }
        [pscustomobject]@{Counts=(Get-HarnessMigrationCounts $migration);Id=$Id;FichaPath=$path;MigrationPath=$Project.MigrationPath;Reused=($writes.Count -eq 0);ChangedFiles=@($writes.Keys)}
    } finally { $lease.ReleaseMutex(); $lease.Dispose() }
}

function Get-IssueRepairFiles {
    param([string]$Folder)
    $pending=New-Object 'Collections.Generic.Stack[string]'; $pending.Push($Folder)
    while ($pending.Count) {
        foreach ($item in Get-ChildItem -LiteralPath $pending.Pop() -Force) {
            $relative=$item.FullName.Substring($Folder.Length+1).Replace('\','/')
            if ($relative -match '^(temporarios|recebido)(/|$)|^atual/(build|diagnosticos|sprints|jboss)(/|$)') { continue }
            if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "Link/junction na conversao: $relative" }
            if ($item.PSIsContainer) { $pending.Push($item.FullName) }
            else { $relative }
        }
    }
}

function Convert-IssueDocumentLinks {
    param([string]$Text,[string]$From,[string]$NewFrom,$Maps)
    [regex]::Replace($Text,'(?<label>\[[^\]\r\n]*\])\((?:<(?<angle>[^>\r\n]+)>|(?<plain>[^\s)]+))\)',[Text.RegularExpressions.MatchEvaluator]{
        param($match)
        $value=if ($match.Groups['angle'].Success) {$match.Groups['angle'].Value} else {$match.Groups['plain'].Value}
        try { $uri=[Uri]::new((ConvertTo-HarnessFileUri $From),$value) } catch { return $match.Value }
        if (-not $uri.IsFile) { return $match.Value }
        $target=$uri.LocalPath; $changed=$false
        foreach ($map in $Maps) {
            if ($target.StartsWith($map.OldDirectory+'\',[StringComparison]::OrdinalIgnoreCase)) {
                $target=$map.NewDirectory+$target.Substring($map.OldDirectory.Length); $changed=$true; break
            }
            if ($target.StartsWith($map.NewDirectory+'\',[StringComparison]::OrdinalIgnoreCase)) { $changed=$true; break }
        }
        if (-not $changed) { return $match.Value }
        $link=Get-HarnessSourceLink $NewFrom $target 'destino'
        $address=$link.Substring(11,$link.Length-13)
        $match.Groups['label'].Value+'(<'+$address+$uri.Query+$uri.Fragment+'>)'
    })
}

function Convert-IssueContextPaths {
    param($Value,$Maps,[string]$Field='')
    if ($null -eq $Value) { return $null }
    if ($Value -is [string]) {
        if ($Field -notmatch '(?i)paths?$') { return $Value }
        $normalized=$Value.Replace('\','/')
        foreach ($map in $Maps) {
            $old='/projetos/'+$map.Project+'/'+$map.OldRelativeDirectory+'/'
            $new='/projetos/'+$map.Project+'/'+$map.NewRelativeDirectory+'/'
            $normalized=$normalized.Replace($old,$new)
        }
        if ($normalized -ceq $Value.Replace('\','/')) { return $Value }
        if ($Value.Contains('\')) { return $normalized.Replace('/','\') }
        return $normalized
    }
    if ($Value -is [Array]) { return ,@($Value | ForEach-Object { Convert-IssueContextPaths $_ $Maps $Field }) }
    if ($Value -is [pscustomobject]) {
        foreach ($property in @($Value.PSObject.Properties)) { $property.Value=Convert-IssueContextPaths $property.Value $Maps $property.Name }
    }
    $Value
}

function Repair-HarnessManualIssue {
    [CmdletBinding()]
    param($Project,[Parameter(Mandatory=$true)][string]$Id,[switch]$Apply)
    if ($Id -cnotmatch '^DEV-[A-Za-z0-9][A-Za-z0-9._-]*$' -or $Id.EndsWith('.')) { throw 'Informe o ID manual original DEV-...; nao alterar sua identidade.' }
    $lease=Enter-HarnessProjectAccess $Project -ForOperation
    $access=$null
    try {
        $access=Enter-HarnessProjectAccess $Project
        $relative=Get-PrioritizationFichaRelativePath manual $Id
        $legacy=Get-PrioritizationFichaRelativePath manual $Id -Legacy
        $files=@(Get-IssueRepairFiles $Project.Folder)
        $old=Read-HarnessProjectFiles $Project $files -AsBytes
        $source=if ($old.Contains($legacy)) {$legacy} elseif ($old.Contains($relative)) {$relative} else { throw 'Ficha existente nao encontrada; nao criar outra analise.' }
        $text=[Text.Encoding]::UTF8.GetString($old[$source]).TrimStart([char]0xfeff)
        $null=Read-HarnessFichaAtPath $text $Project.Name $source
        $null=Read-PrioritizationFicha $text $Project.Name manual $Id
        if ($old.Contains('migracao.md')) {
            $rows=@(Read-ProjectDecisionRows ([Text.Encoding]::UTF8.GetString($old['migracao.md']).TrimStart([char]0xfeff)))
            Assert-HarnessIssueFolderSet @(@($rows | ForEach-Object { [pscustomobject]@{Project=$Project.Name;Category=$_.Category;Id=$_.Id} })+[pscustomobject]@{Project=$Project.Name;Category='manual';Id=$Id})
        }
        if ($source -cne $relative -and $old.Contains($relative) -and [Convert]::ToBase64String($old[$relative]) -cne [Convert]::ToBase64String($old[$source])) {
            throw 'Destino legivel ocupado por outro conteudo. Preserve/concilie a ficha vazia ou divergente antes do reparo; nada foi sobrescrito.'
        }
        $maps=@([pscustomobject]@{Project=$Project.Name;OldRelativeDirectory=(Split-Path $legacy -Parent).Replace('\','/');NewRelativeDirectory=(Split-Path $relative -Parent).Replace('\','/');
            OldDirectory=(Split-Path (Join-Path $Project.Folder $legacy) -Parent);NewDirectory=(Split-Path (Join-Path $Project.Folder $relative) -Parent)})
        $writes=@{}; $expected=@{}
        foreach ($file in $files) {
            $destination=$file
            if ($file.StartsWith($maps[0].OldRelativeDirectory+'/',[StringComparison]::Ordinal)) {
                $destination=$maps[0].NewRelativeDirectory+$file.Substring($maps[0].OldRelativeDirectory.Length)
            }
            $bytes=$old[$file]; $after=$bytes
            if ($destination -cne $file) {
                if ($old.Contains($destination) -and [Convert]::ToBase64String($old[$destination]) -cne [Convert]::ToBase64String($bytes)) { throw "Destino ocupado: $destination. Nenhum arquivo sobrescrito." }
                $expected[$destination]=if ($old.Contains($destination)) {$old[$destination]} else {$null}
                $writes[$file]=$null; $expected[$file]=$bytes
            }
            $text=[Text.Encoding]::UTF8.GetString($bytes).TrimStart([char]0xfeff)
            if ($file -match '\.md$' -and ($file -notmatch '^evidencias/' -or $file -ceq 'evidencias/LEIA-ME.md')) {
                $converted=Convert-IssueDocumentLinks $text (Join-Path $Project.Folder $file) (Join-Path $Project.Folder $destination) $maps
                if ($converted -cne $text) { $after=(New-Object Text.UTF8Encoding($false)).GetBytes($converted) }
            } elseif ($file -ceq 'atual/planejamento/contexto.json') {
                $data=ConvertFrom-Json $text
                $beforeJson=ConvertTo-Json $data -Depth 80 -Compress
                $data=Convert-IssueContextPaths $data $maps
                if ((ConvertTo-Json $data -Depth 80 -Compress) -cne $beforeJson) { $after=(New-Object Text.UTF8Encoding($false)).GetBytes((ConvertTo-Json $data -Depth 80)) }
            }
            if ($destination -cne $file -or [Convert]::ToBase64String($bytes) -cne [Convert]::ToBase64String($after)) {
                $writes[$destination]=$after
                if (-not $expected.ContainsKey($destination)) { $expected[$destination]=$bytes }
            }
        }
        foreach ($file in $writes.Keys) {
            $path=Join-Path $Project.Folder $file
            $staging=Join-Path $Project.TemporaryPath ('publicacao/depois/'+$file)
            if ($path.Length -gt 240 -or $staging.Length -ge 248) { throw "Caminho longo para reparo protegido: $path (publicacao: $($staging.Length)). Use raiz mais curta; nada foi movido." }
        }
        if ($Apply -and $writes.Count) {
            Publish-HarnessProjectFiles $Project $writes $expected
            $path=Resolve-ProjectPath $maps[0].OldDirectory $Project.Folder
            if (-not $path.StartsWith($Project.Folder+'\',[StringComparison]::OrdinalIgnoreCase)) { throw 'Pasta antiga fora do projeto.' }
            if ((Test-Path -LiteralPath $path -PathType Container) -and -not @(Get-ChildItem -LiteralPath $path -Force).Count) { [IO.Directory]::Delete($path) }
        }
        [pscustomobject]@{Applied=[bool]$Apply;FichaPath=(Join-Path $Project.Folder $relative);ChangedFiles=@($writes.Keys | ForEach-Object {Join-Path $Project.Folder $_})}
    } finally {
        if ($access) { $access.ReleaseMutex(); $access.Dispose() }
        $lease.ReleaseMutex(); $lease.Dispose()
    }
}
Export-ModuleMember -Function Get-HarnessIssuePath,Register-HarnessManualIssue,Repair-HarnessManualIssue
