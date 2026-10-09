#requires -Version 5.1
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $root 'scripts/HarnessPrioritization.psm1') -Force -DisableNameChecking
$module = Get-Module HarnessPrioritization
function Assert($condition, $message) { if (-not $condition) { throw $message } }
function Reject($action, $message) { $failed=$false; try { & $action | Out-Null } catch { $failed=$true }; Assert $failed $message }
$fixture = Join-Path $root ('.harness/tests/prior-index-' + [guid]::NewGuid().ToString('N'))
$templatePath = Join-Path $fixture 'doc/modelos/indice-priorizacao.template.md'
$null = [IO.Directory]::CreateDirectory((Split-Path $templatePath -Parent))
Copy-Item (Join-Path $root 'doc/modelos/indice-priorizacao.template.md') $templatePath
$indexPath = Join-Path $fixture '.harness/priorizacao/indice-priorizacao.md'
$history = [Collections.Generic.List[object]]::new()
function Receipt($category='mandatory', $source='C:\app', $previous=$null, $mode='Start') {
    $id=[guid]::NewGuid().ToString('N'); $folder=Join-Path $fixture ('.harness/priorizacao/'+$id)
    $null=[IO.Directory]::CreateDirectory($folder)
    $issues=@(1..4 | ForEach-Object { [pscustomobject]@{Source=$source;Id="r::$_"} })
    $r=[pscustomobject]@{
        Purpose='issue-prioritization';SchemaVersion=2;RequestId=$id;Category=$category
        SequenceId=$(if ($mode -eq 'Continue') { $previous.SequenceId } else { $id })
        Mode=$mode;PreparedAtUtc='2026-10-09T12:00:00Z';Percentage=50;InitialTotal=4;SliceSize=2
        BaselineIssues=$issues;AvailableIssues=$issues;ExcludedIssues=@()
        Projects=@([pscustomobject]@{Source=$source;Project='app';Label='App | teste';Mta=$null})
        Previous=$(if ($previous) { [pscustomobject]@{RequestId=$previous.RequestId;RankingSha256=$(if (Test-Path $previous.RankingPath) { (Get-FileHash $previous.RankingPath).Hash } else { $null })} } else { $null })
        ContextPath=(Join-Path $folder 'context.json');RankingPath=(Join-Path $folder 'priorizacao.md');PromptPath=(Join-Path $folder 'priorizar-issues.prompt.md')
    }
    [IO.File]::WriteAllText($r.ContextPath, ($r | ConvertTo-Json -Depth 10))
    $history.Add($r)
    $r
}
function Complete($r, $issues, $proposals=@()) {
    $result=@{RequestId=$r.RequestId;Status='COMPLETED';AnalyzedIssues=@($issues);ProposedIssues=@($proposals)} | ConvertTo-Json -Depth 8
    [IO.File]::WriteAllText($r.RankingPath, ('<!-- priorizacao:resultado -->'+"`n"+'```json'+"`n$result`n"+'```'+"`n<!-- /priorizacao:resultado -->"))
}
function Refresh {
    & $module { param($r) Update-PrioritizationIndex $r } $fixture | Out-Null
    [IO.File]::ReadAllText($indexPath)
}
$first=Receipt
$manual="# Indice manual original`r`nMinha observacao e links devem ficar intactos.`r`n"
[IO.File]::WriteAllText($indexPath,$manual)
$text=Refresh
Assert ($text.StartsWith($manual)) 'Indice manual foi alterado.'
Assert ($text -match 'PENDENTE' -and $text -match '0 de 4') 'Preparo foi contado como exame.'
Assert ($text -notmatch '\[priorizacao.md\]') 'Criou link para ranking inexistente.'
Complete $first $first.AvailableIssues[0..1] @($first.AvailableIssues[0])
$second=Receipt -previous $first -mode Continue
$text=Refresh
Assert ($text -match '2 de 4.*50' -and $text.Contains($first.RequestId+'/priorizacao.md')) 'Resultado completo nao entrou no indice com link relativo.'
Assert ($text -match 'App &#124; teste') 'Rotulo quebrou tabela Markdown.'
# Legado v2 podia reexaminar uma issue: cobertura deve usar uniao Source/Id.
Complete $second $second.AvailableIssues[1..2]
$text=Refresh
Assert ($text -match '3 de 4.*75') 'Cobertura somou examinadas repetidas.'
Assert ($text -ceq (Refresh)) 'Atualizacao sem mudancas nao e idempotente.'
$optional=Receipt -category optional
$otherScope=Receipt -source 'C:\outro'
$text=Refresh
Assert ($text.Contains($optional.RequestId) -and $text.Contains($otherScope.RequestId) -and $text.Contains($first.RequestId)) 'Categoria/escopo independente desapareceu.'
$crossScope=Receipt -source 'C:\outro-escopo' -previous $otherScope -mode Recreate
$text=Refresh
Assert (-not $text.Contains(('Substituida pelo Recreate `'+$crossScope.RequestId+'`'))) 'Recreate de outro escopo substituiu a sequencia anterior.'
# Mesmo escopo pode continuar mesmo que outra frente tenha referencia historica a ele.
Complete $otherScope $otherScope.AvailableIssues[0..1]
$otherNext=Receipt -source 'C:\outro' -previous $otherScope -mode Continue
$text=Refresh
Assert ($text -notmatch 'AMBIGUA' -and $text.Contains($otherNext.RequestId)) 'Referencia de outro escopo virou bifurcacao da sequencia.'
$selected=& $module {
    param($r,$previous)
    Select-PrioritizationPrevious @(Read-PrioritizationHistory $r) $previous.Projects -RequestId $previous.RequestId
} $fixture $otherScope
Assert ($selected.RequestId -eq $otherNext.RequestId) 'Retomada explicita seguiu referencia de outro escopo.'
$recreated=Receipt -previous $second -mode Recreate
$text=Refresh
Assert ($text -match 'Substitu.da' -and $text.Contains($recreated.RequestId)) 'Recreate nao preservou sequencia substituida.'
Assert ($text -match '0 de 4') 'Recreate pendente herdou cobertura anterior.'
$hash=(Get-FileHash $indexPath).Hash
$fileHashes=@($history | ForEach-Object { Get-FileHash $_.ContextPath })
# Resultado parcial nao consome cobertura.
Complete $recreated @($recreated.AvailableIssues[0])
[IO.File]::WriteAllText($recreated.RankingPath,([IO.File]::ReadAllText($recreated.RankingPath).Replace('COMPLETED','IN_PROGRESS')))
$text=Refresh
Assert ($text -match 'NAO_VALIDADA' -and $text -match 'nao concluido') 'Parcial virou fatia concluida.'
Complete $recreated $recreated.AvailableIssues[0..1]
$child=Receipt -previous $recreated -mode Continue
Add-Content $recreated.RankingPath 'mudanca posterior'
$text=Refresh
Assert ($text -match 'anterior ausente/alterado' -and $text -match 'N/A') 'Ancestral adulterado conservou cobertura confiavel.'
# Bifurcacao nao escolhe por recencia, mesmo com timestamps iguais.
$fork=Receipt -previous $recreated -mode Continue
$text=Refresh
Assert ($text -match 'AMBIGUA' -and $text.Contains($child.RequestId) -and $text.Contains($fork.RequestId)) 'Bifurcacao ocultada.'
foreach ($entry in $fileHashes) { Assert ((Get-FileHash $entry.Path).Hash -eq $entry.Hash) 'Indice reescreveu recibo legado.' }
# Um marcador ausente/duplicado e conflito, nao autorizacao de sobrescrita.
$original=[IO.File]::ReadAllText($indexPath)
[IO.File]::WriteAllText($indexPath,$original+"`n<!-- priorizacao:indice:inicio -->")
$broken=(Get-FileHash $indexPath).Hash
Reject { Refresh } 'Marcadores duplicados aceitos.'
Assert ((Get-FileHash $indexPath).Hash -eq $broken) 'Conflito de marcador sobrescreveu indice.'
[IO.File]::WriteAllText($indexPath,$original)
# Publicacao atomica: conflito apos a leitura e falha no replace preservam o original.
$concurrent=$original+"`nNota humana nova.`n"
[IO.File]::WriteAllText($indexPath,$concurrent)
Reject { & $module { param($p,$old) Write-PrioritizationIndexContent $p 'novo indice' $old $true } $indexPath $original } 'Edicao concorrente foi sobrescrita.'
Assert ([IO.File]::ReadAllText($indexPath) -ceq $concurrent) 'Perdeu a nota concorrente.'
$lock=[IO.File]::Open($indexPath,'Open','Read','Read')
try {
    Reject { & $module { param($p,$old) Write-PrioritizationIndexContent $p 'novo indice' $old $true } $indexPath $concurrent } 'Replace de arquivo bloqueado deveria falhar.'
} finally { $lock.Dispose() }
Assert ([IO.File]::ReadAllText($indexPath) -ceq $concurrent) 'Falha de publicacao truncou conteudo humano.'
Assert (@(Get-ChildItem (Split-Path $indexPath -Parent) -File -Filter '*.tmp').Count -eq 0) 'Publicacao deixou temporario.'
& $module { param($p,$old) Write-PrioritizationIndexContent $p ($old+'Atualizacao completa') $old $true } $indexPath $concurrent
Assert ([IO.File]::ReadAllText($indexPath) -ceq ($concurrent+'Atualizacao completa')) 'Publicacao atomica nao concluiu.'
# Legado Top sem campos de percentual permanece localizavel, sem cobertura inventada.
$legacy=Receipt -source 'C:\legado'
foreach ($field in @('SchemaVersion','Category','Mode','SequenceId','Previous','Percentage','InitialTotal','SliceSize','BaselineIssues','AvailableIssues','ExcludedIssues')) { $legacy.PSObject.Properties.Remove($field) }
$legacy | Add-Member NoteProperty Top 5
[IO.File]::WriteAllText($legacy.ContextPath,($legacy | ConvertTo-Json -Depth 10))
$text=Refresh
Assert ($text.Contains($legacy.RequestId) -and $text -match 'N/A de N/A') 'Legado Top perdeu identidade ou ganhou cobertura ficticia.'
Write-Output 'PASS: indice automatico, legado, cobertura distinta, escopos/categorias, pendencias, historico e preservacao.'
