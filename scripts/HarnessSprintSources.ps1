# Sources are read afresh. Hashes below protect one operation and are never saved.
function Get-SprintInputValue {
    param($Object,[string]$Name,$Default=$null)
    if ($null -ne $Object -and $Object.PSObject.Properties[$Name]) { return $Object.$Name }
    return $Default
}

function Get-SprintReference {
    param([string]$Path,[string]$Root,[string]$Kind)
    if ($Path -match '^https?://') { return [pscustomobject]@{Path=$Path;Kind=$Kind;Status='REFERENCIA EXTERNA';Sha256=$null} }
    try { $resolved=Resolve-HarnessPath $Path $Root }
    catch { return [pscustomobject]@{Path=$Path;Kind=$Kind;Status='INVALIDA';Sha256=$null;Error=$_.Exception.Message} }
    $exists=$resolved -and (Test-Path -LiteralPath $resolved -PathType Leaf)
    [pscustomobject]@{Path=$resolved;Kind=$Kind;Status=$(if ($exists) {'DISPONIVEL'} else {'AUSENTE'});Sha256=$(if ($exists) {(Get-FileHash -LiteralPath $resolved -Algorithm SHA256).Hash} else {$null})}
}

function Get-SprintMarkdownReferences {
    param([string]$Text,[string]$Base,[string]$Kind)
    foreach ($link in [regex]::Matches($Text,'\[[^\]]*\]\(<?([^>\)]+)>?\)')) {
        $value=($link.Groups[1].Value -split '#',2)[0]
        if ($value) { Get-SprintReference ([Uri]::UnescapeDataString($value)) $Base $Kind }
    }
}

function Get-HarnessSprintSources {
    param($Context,[object[]]$Projects)
    $root=$Context.Root
    $references=@(Get-SprintReference (Join-Path $root '.harness/indices/projetos.md') $root 'Indice')
    foreach ($relative in @('doc/features/planejamento-macro-sprints.md','doc/especificacoes/planejamento-sprints.md','doc/modelos/planejamento-sprints.template.md','.github/prompts/planejar-sprints.prompt.md','.github/prompts/revisar-sprints.prompt.md')) {
        $references+=Get-SprintReference (Join-Path $root $relative) $root 'Contrato'
    }
    $entries=@(foreach ($item in $Projects) {
        $project=Get-HarnessProjectStorage $root (Join-Path $item.path 'pom.xml')
        if (-not (Test-Path -LiteralPath $project.ConfigPath -PathType Leaf)) { throw 'Projeto sem associacao: use Workspace: atualizar indice dos projetos.' }
        $lease=Enter-HarnessProjectAccess $project
        try {
            $entry=[pscustomobject][ordered]@{Project=$project.Name;Label=$project.Name;Source=$project.Source;Pom=$project.Pom;MigrationPath=$project.MigrationPath;Issues=@();Diagnostics=@();References=@();RegisterValid=$false}
            $files=Read-HarnessProjectFiles $project @('migracao.md','indice.md','atual/planejamento/plano.md','atual/planejamento/tarefas.md')
            foreach ($pair in @(@($project.Pom,'POM'),@($project.ConfigPath,'Associacao'),@($project.MigrationPath,'Registro'))) {
                $entry.References+=Get-SprintReference $pair[0] $root $pair[1]
            }
            if ($files['migracao.md']) {
                try {
                    $rows=@(Read-ProjectDecisionRows $files['migracao.md'])
                    $entry.RegisterValid=$true
                    $entry.Issues=@(foreach ($row in $rows) {
                        [pscustomobject]@{Source=$project.Source;Id=$row.Id;Title=$row.Title;Category=$row.Category;Count=$row.Count;Presence=$row.Presence;Decision=$row.Decision;Progress=$row.Progress;Observation=$row.Note;FichaPaths=@()}
                    })
                    try {
                        $evidence=Get-CurrentPlanningEvidence $project $rows
                        foreach ($input in $evidence.Inputs) { $entry.References+=Get-SprintReference $input.Path $root 'Evidencia' }
                        foreach ($ficha in $evidence.Fichas | Where-Object Status -EQ 'DISPONIVEL') {
                            $entry.References+=Get-SprintReference $ficha.Path $root 'Ficha'
                            foreach ($issue in $entry.Issues | Where-Object Id -CEQ $ficha.Id) { $issue.FichaPaths+=@($ficha.Path) }
                            $entry.References+=@(Get-SprintMarkdownReferences ([IO.File]::ReadAllText($ficha.Path)) (Split-Path $ficha.Path -Parent) 'Anexo da ficha')
                        }
                        $entry.Diagnostics+=@($evidence.Warnings)
                    } catch { $entry.Diagnostics+=('Referencia incompleta: '+$_.Exception.Message) }
                    $entry.References+=@(Get-SprintMarkdownReferences $files['migracao.md'] $project.Folder 'Vinculo do registro')
                } catch { $entry.Diagnostics+=('Registro invalido: '+$_.Exception.Message) }
            } else { $entry.Diagnostics+='Registro ausente; total de trabalho desconhecido.' }
            foreach ($relative in @('atual/planejamento/plano.md','atual/planejamento/tarefas.md')) {
                if ($files[$relative]) { $entry.References+=Get-SprintReference (Join-Path $project.Folder $relative) $root 'Plano corrente' }
            }
            if ($files['indice.md']) {
                $entry.References+=Get-SprintReference $project.IndexPath $root 'Indice'
                $entry.References+=@(Get-SprintMarkdownReferences $files['indice.md'] $project.Folder 'Documento corrente' |
                    Where-Object { $_.Path -notmatch '(?i)[\\/]atual[\\/]sprints[\\/]' })
            }
            $entry.References=@($entry.References | Sort-Object Path -Unique)
            $references+=$entry.References
            $entry
        } finally { $lease.Dispose() }
    })
    if (@($entries | Group-Object Project | Where-Object Count -GT 1).Count) { throw 'Projetos duplicados ou colisao de artifactId no escopo.' }
    [pscustomobject]@{Projects=$entries;References=@($references | Sort-Object Path -Unique)}
}

function Assert-SprintReferences {
    param($Inputs,[string]$Root)
    foreach ($reference in $Inputs.References) {
        $current=Get-SprintReference $reference.Path $Root $reference.Kind
        if ($reference.Status -ne $current.Status -or $reference.Sha256 -cne $current.Sha256) { throw "Entrada mudou durante a operacao: $($reference.Path). Repita a leitura." }
    }
}
