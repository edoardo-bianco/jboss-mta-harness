# Read-only collection. A category, decision or progress label is not proof of resolution.
function Get-SprintInputValue {
    param($Object,[string]$Name,$Default=$null)
    if ($null -ne $Object -and $Object.PSObject.Properties[$Name]) { return $Object.$Name }
    return $Default
}

function Get-SprintJsonHash {
    param($Value)
    $sha=[Security.Cryptography.SHA256]::Create()
    try { [BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes(($Value | ConvertTo-Json -Depth 60 -Compress)))).Replace('-','') }
    finally { $sha.Dispose() }
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
        if (-not $value) { continue }
        Get-SprintReference ([Uri]::UnescapeDataString($value)) $Base $Kind
    }
}

function Get-HarnessSprintSources {
    param($Context,[object[]]$Projects)
    $root=$Context.Root
    $references=@(Get-SprintReference (Join-Path $root '.harness/projetos/indice-projetos.md') $root 'Indice')
    foreach ($relative in @('doc/features/planejamento-macro-sprints.md','doc/especificacoes/planejamento-sprints.md','doc/modelos/planejamento-sprints.template.md','.github/prompts/planejar-sprints.prompt.md','.github/prompts/revisar-sprints.prompt.md')) {
        $references+=Get-SprintReference (Join-Path $root $relative) $root 'Contrato'
    }
    $entries=@(foreach ($project in $Projects) {
        $entry=[pscustomobject][ordered]@{Project=$project.name;Label=$project.label;Source=$project.path;MigrationPath=$null;PlanningBasis=$null;MtaOrigin=$null;MigrationSnapshot=$null;Issues=@();Diagnostics=@();References=@();PlanningCandidates=@();PrioritizationCandidates=@();RegisterValid=$false}
        try {
            $paths=Get-HarnessMigrationPaths $root $project
            $entry.MigrationPath=$paths.MigrationPath
            $entry.References+=Get-SprintReference $paths.MigrationPath $root 'Registro'
            $register=Read-HarnessMigrationInput $root $project $paths.MigrationPath
            $entry.RegisterValid=$true
            # Keep the issue inventory even if a legacy annex/link cannot be read.
            $entry.Issues=@(foreach ($row in $register.Rows) { [pscustomobject]@{Source=$project.path;Id=$row.Id;Title=$row.Title;Category=$row.Category;Count=$row.Count;Presence=$row.Presence;Decision=$row.Decision;Progress=$row.Progress;Observation=$row.Observation;FichaPaths=@();Diagnostics=@('Fichas ainda nao conferidas.')} })
            $entry.MigrationSnapshot=$register.Text
            $entry.PlanningBasis=if ($register.Origin) {'MTA'} else {'EVIDENCIAS'}
            $entry.MtaOrigin=$register.Origin
            $entry.Diagnostics+=@($register.Warnings)
            $entry.References+=@(Get-SprintMarkdownReferences $register.Text (Split-Path $register.MigrationPath -Parent) 'Vinculo do registro')
            # Reuse annex reader for every row, without changing the actual register.
            $allRows=@($register.Rows | ForEach-Object { [pscustomobject]@{Id=$_.Id;Observation=$_.Observation;Decision='ANALISAR AGORA'} })
            $reading=[pscustomobject]@{Rows=$allRows;MigrationPath=$register.MigrationPath}
            try { $entry.References+=@(Get-HarnessPlanningEvidenceInputs $root $reading $paths.EvidenceIndexPath | ForEach-Object { Get-SprintReference $_.Path $root 'Evidencia' }) }
            catch { $entry.Diagnostics+=('Referencia incompleta: '+$_.Exception.Message) }
            $entry.Issues=@(foreach ($row in $register.Rows) {
                $fichas=@(); $issueReferences=@(); $diagnostics=@()
                try {
                    $issuePaths=Get-HarnessIssuePaths $root $project $row.Id
                    if (Test-Path -LiteralPath $issuePaths.Folder -PathType Container) {
                        foreach ($file in Get-ChildItem -LiteralPath $issuePaths.Folder -Recurse -File -Filter 'ficha-*.md') {
                            $null=Resolve-HarnessPath $file.FullName $root
                            Assert-HarnessIssueFicha $file.FullName $project.path $row.Id
                            $fichas+=$file.FullName
                            $issueReferences+=Get-SprintReference $file.FullName $root 'Ficha'
                            $issueReferences+=@(Get-SprintMarkdownReferences ([IO.File]::ReadAllText($file.FullName)) $file.DirectoryName 'Anexo da ficha')
                        }
                    }
                    $issueReading=[pscustomobject]@{Rows=@();MigrationPath=$register.MigrationPath}
                    $issueReferences+=@(Get-HarnessPlanningEvidenceInputs $root $issueReading $issuePaths.EvidenceIndexPath | ForEach-Object { Get-SprintReference $_.Path $root 'Evidencia da issue' })
                } catch { $diagnostics+=$_.Exception.Message }
                if (-not $fichas.Count) { $diagnostics+='Ficha ausente; estimativa e solucao precisam de exame.' }
                $entry.References+=$issueReferences
                [pscustomobject]@{Source=$project.path;Id=$row.Id;Title=$row.Title;Category=$row.Category;Count=$row.Count;Presence=$row.Presence;Decision=$row.Decision;Progress=$row.Progress;Observation=$row.Observation;FichaPaths=$fichas;Diagnostics=$diagnostics}
            })
        } catch { $entry.Diagnostics+=('Registro indisponivel/invalido: '+$_.Exception.Message) }
        # This is an inventory, never a selection by newest date. Explicit links are retained.
        try {
            $history=@(Get-MtaPlanningHistory ([pscustomobject]@{Root=$root;Active=$project}) -IncludePrepared)
            foreach ($item in ($history | Sort-Object RequestId)) {
                $entry.PlanningCandidates+=[pscustomobject]@{RequestId=$item.RequestId;ContextPath=$item.ContextPath;PlanPath=$item.PlanPath;TodoPath=$item.TodoPath;Previous=(Get-SprintInputValue $item 'Previous');PlanningBasis=(Get-HarnessPlanningBasis $item);MtaOrigin=(Get-SprintInputValue $item 'MtaOrigin');RunId=(Get-SprintInputValue $item 'RunId');EvidenceMode=(Get-SprintInputValue $item 'EvidenceMode');SelectedIssues=(Get-SprintInputValue $item 'SelectedIssues' @())}
                foreach ($path in @($item.ContextPath,$item.PlanPath,$item.TodoPath)) { if ($path) { $entry.References+=Get-SprintReference $path $root 'Plano candidato' } }
                # Consolidated imported evidence remains usable without the original MTA.
                $consolidated=Get-SprintInputValue $item 'Consolidated'
                foreach ($file in @(Get-SprintInputValue $consolidated 'Files' @())) {
                    $relative=Get-SprintInputValue $file 'RelativePath'
                    if ($relative) {
                        $folder=Split-Path $item.ContextPath -Parent
                        $path=Resolve-HarnessPath $relative $folder
                        if (-not $path.StartsWith($folder+'\',[StringComparison]::OrdinalIgnoreCase)) { throw 'Evidencia consolidada fora da pasta da solicitacao.' }
                        $reference=Get-SprintReference $path $root 'Evidencia consolidada'
                        $entry.References+=$reference
                        if ($reference.Sha256 -cne $file.Sha256) { $entry.Diagnostics+='Evidencia consolidada alterada/ausente: '+$path }
                    }
                }
            }
        } catch { $entry.Diagnostics+=('Inventario de planos incompleto: '+$_.Exception.Message) }
        $entry
    })
    $priorityBase=Join-Path $root '.harness/priorizacao'
    if (Test-Path -LiteralPath $priorityBase -PathType Container) {
        foreach ($directory in Get-ChildItem -LiteralPath $priorityBase -Directory | Sort-Object Name) {
            $path=Join-Path $directory.FullName 'context.json'
            if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { continue }
            try {
                $receipt=Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
                if ($receipt.Purpose -ne 'issue-prioritization' -or $receipt.ContextPath -ine $path -or $receipt.RequestId -cne $directory.Name) { throw 'Identidade de priorizacao divergente.' }
                foreach ($entry in $entries) {
                    if (@($receipt.Projects | Where-Object Source -IEQ $entry.Source).Count -ne 1) { continue }
                    $entry.PrioritizationCandidates+=[pscustomobject]@{RequestId=$receipt.RequestId;ContextPath=$path;RankingPath=$receipt.RankingPath;Category=(Get-SprintInputValue $receipt 'Category' 'mandatory');PreviousRequestId=(Get-SprintInputValue $receipt 'PreviousRequestId')}
                    $entry.References+=Get-SprintReference $path $root 'Recibo de priorizacao'
                    $entry.References+=Get-SprintReference $receipt.RankingPath $root 'Ranking candidato'
                    foreach ($ficha in @(Get-SprintInputValue $receipt 'FichaPaths' @()) | Where-Object Source -IEQ $entry.Source) {
                        $entry.References+=Get-SprintReference $ficha.Path $root 'Ficha referenciada'
                    }
                }
            } catch { foreach ($entry in $entries) { $entry.Diagnostics+=('Priorizacao nao validada: '+$path+'; '+$_.Exception.Message) } }
        }
    }
    foreach ($entry in $entries) {
        $entry.References=@($entry.References | Sort-Object Path -Unique)
        $references+=$entry.References
    }
    $references=@($references | Sort-Object Path -Unique)
    [pscustomobject]@{Projects=$entries;References=$references;Fingerprint=(Get-SprintJsonHash ([ordered]@{Projects=$entries;References=$references}))}
}

function Get-SprintReferenceChanges {
    param($Previous,$Current)
    $before=@{}; $after=@{}
    foreach ($item in $Previous) { $before[$item.Path]=$item }
    foreach ($item in $Current) { $after[$item.Path]=$item }
    foreach ($path in @(@($before.Keys)+@($after.Keys) | Sort-Object -Unique)) {
        $left=$before[$path]; $right=$after[$path]
        if (-not $left -or -not $right -or $left.Status -ne $right.Status -or $left.Sha256 -cne $right.Sha256) {
            [pscustomobject]@{Path=$path;Before=$left;After=$right}
        }
    }
}

function Assert-SprintReferences {
    param($Receipt,[string]$Root)
    foreach ($reference in $Receipt.References) {
        $current=Get-SprintReference $reference.Path $Root $reference.Kind
        if ($reference.Status -ne $current.Status -or $reference.Sha256 -cne $current.Sha256) { throw "Entrada mudou: $($reference.Path). Use Revisar com motivo; preserve a revisao anterior." }
    }
}
