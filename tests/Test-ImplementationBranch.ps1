#requires -Version 5.1
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $root 'scripts/HarnessImplementation.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $root 'scripts/HarnessGit.psm1') -Force -DisableNameChecking
function Assert($condition, $message) { if (-not $condition) { throw $message } }
function Reject($action, $message) {
    $rejected = $false
    try { & $action | Out-Null } catch { $rejected = $true }
    Assert $rejected $message
}
function Answer([string[]]$Answers) {
    & (Get-Module HarnessImplementation) {
        param($Values)
        $script:answers = New-Object 'Collections.Generic.Queue[string]'
        foreach ($value in $Values) { $script:answers.Enqueue($value) }
        function script:Read-Host { param($Prompt) $script:answers.Dequeue() }
    } $Answers
}
$area = Join-Path $root ('.harness/tests/ib' + [guid]::NewGuid().ToString('N').Substring(0,8))
$app = Join-Path $area 'app com espacos'
$module = Join-Path $app 'modulo'
$null = [IO.Directory]::CreateDirectory($module)
& git init -q -b main $app
Set-Content -LiteralPath (Join-Path $module 'pom.xml') '<project/>'
& git -C $app add .
& git -C $app -c user.name=HarnessFixture -c user.email=fixture@example.invalid commit -qm fixture
if ($LASTEXITCODE) { throw 'Falha ao criar commit da fixture.' }
$context = [pscustomobject]@{Root=$root;Active=[pscustomobject]@{path=$module}}
$prepared = [pscustomobject]@{ContextPath=(Join-Path $area 'context.json');PlanPath=(Join-Path $area 'plan.md');TodoPath=(Join-Path $area 'todo.md');ContextSha256=$null;PlanSha256=$null;TodoSha256=$null}
Set-Content -LiteralPath $prepared.ContextPath '{}'
function Documents($plan, $todo) {
    Set-Content -LiteralPath $prepared.PlanPath $plan
    Set-Content -LiteralPath $prepared.TodoPath $todo
    foreach ($name in @('Context','Plan','Todo')) { $prepared.($name + 'Sha256') = (Get-FileHash -LiteralPath $prepared.($name + 'Path')).Hash }
}
Documents '**Lote ativo:** HIB-CACHE-001' 'ID do lote: `HIB-CACHE-001`'
Assert ((Get-ImplementationBatchId $prepared.PlanPath $prepared.TodoPath) -ceq 'HIB-CACHE-001') 'ID explicito igual nao detectado.'
$before = Get-HarnessGitState $context
foreach ($answer in @('','q','9')) {
    Answer @($answer)
    Reject { Select-ImplementationBranch $context $prepared } 'Escolha vazia/invalida nao pode escolher branch.'
}
Answer @('2')
$result = Select-ImplementationBranch $context $prepared
Assert ($result.Branch -eq 'main' -and $result.Head -eq $before.Head) 'Usar atual alterou branch/HEAD.'
# Preservar alteracoes no indice, fora do indice e arquivo nao rastreado.
$pom = Join-Path $module 'pom.xml'
Set-Content -LiteralPath $pom '<project>staged</project>'
& git -C $app add .
Add-Content -LiteralPath $pom '<!-- unstaged -->'
Set-Content -LiteralPath (Join-Path $app 'local.txt') 'nao rastreado'
$dirty = Get-HarnessGitState $context
$indexBefore = (& git -C $app diff --cached --binary) -join "`n"
$filesBefore = @(Get-ChildItem $module -File | Get-FileHash)
Answer @('1')
$created = Select-ImplementationBranch $context $prepared
Assert ($created.Branch -ceq 'lote/HIB-CACHE-001' -and $created.Head -eq $before.Head) 'Criacao automatica nao usou ID/HEAD da aplicacao.'
Assert (($created.Changes -join "`n") -ceq ($dirty.Changes -join "`n")) 'Criacao alterou estado local.'
Assert (((& git -C $app diff --cached --binary) -join "`n") -ceq $indexBefore) 'Indice alterado.'
foreach ($file in $filesBefore) { Assert ((Get-FileHash $file.Path).Hash -eq $file.Hash) 'Conteudo local alterado.' }
Answer @('1','2')
Assert ((Select-ImplementationBranch $context $prepared).Branch -ceq 'lote/HIB-CACHE-001') 'Falha automatica nao ofereceu continuar na atual.'
Documents 'Lote ativo: invalido..001' 'Lote ativo: invalido..001'
Answer @('1','3','lote/recuperado')
Assert ((Select-ImplementationBranch $context $prepared).Branch -ceq 'lote/recuperado') 'Falha de nome automatico nao permitiu nome manual na mesma execucao.'
Documents '**Lote ativo:** HIB-CACHE-001' 'ID do lote: `HIB-CACHE-001`'
Answer @('3','minha-corretiva')
$manual = Select-ImplementationBranch $context $prepared
Assert ($manual.Branch -ceq 'minha-corretiva' -and $manual.Head -eq $before.Head) 'Nome manual nao foi usado literalmente.'
foreach ($name in @('','q','nome invalido','../fora','--force','@{-1}','lote/HIB-CACHE-001')) {
    if ($name -in @('','q')) {
        Answer @('3',$name)
        Reject { Select-ImplementationBranch $context $prepared } 'Nome manual vazio nao cancelou.'
    } else {
        Answer @('3',$name,'2')
        Assert ((Select-ImplementationBranch $context $prepared).Branch -eq 'minha-corretiva') 'Falha de nome manual nao permitiu continuar na atual.'
    }
    Assert ((Get-HarnessGitState $context).Branch -eq 'minha-corretiva') 'Falha trocou branch.'
}
foreach ($pair in @(@('Sem metadado','Sem metadado'),@('Lote ativo: A-001','Lote ativo: B-001'),@("Lote ativo: A-001`nLote ativo: B-001",'Lote ativo: A-001'),@("``````text`nLote ativo: EXEMPLO-001`n``````",'Lote ativo: EXEMPLO-001'))) {
    Documents $pair[0] $pair[1]
    Assert (-not (Get-ImplementationBatchId $prepared.PlanPath $prepared.TodoPath)) 'ID ausente/ambiguo/exemplo aceito.'
    Answer @('2')
    $messages = Select-ImplementationBranch $context $prepared 6>&1
    $text = $messages | Out-String
    Assert ($text.Contains('2. Usar') -and $text.Contains('3. Criar') -and -not $text.Contains('1. Criar')) 'Fallback nao ofereceu apenas atual/manual.'
}
Answer @('3','lote/manual-sem-id')
Assert ((Select-ImplementationBranch $context $prepared).Branch -eq 'lote/manual-sem-id') 'Fallback manual sem ID falhou.'
Documents 'Lote ativo: A-001' 'Lote ativo: A-001'
Add-Content -LiteralPath $prepared.PlanPath 'alterado depois do preparo'
Answer @('1')
Reject { Select-ImplementationBranch $context $prepared } 'Criou branch com documentos alterados apos preparo.'
Assert ((Get-HarnessGitState $context).Branch -eq 'lote/manual-sem-id') 'Documento alterado provocou mutacao Git.'
Documents 'Lote ativo: A-001' 'Lote ativo: A-001'
$unavailable = [pscustomobject]@{Active=[pscustomobject]@{path=(Join-Path $area 'ausente')}}
Answer @('2')
Assert ((Select-ImplementationBranch $unavailable $prepared).Status -eq 'UNAVAILABLE') 'Git indisponivel virou gate para continuar.'
Answer @('1')
Reject { Select-ImplementationBranch $unavailable $prepared } 'Criacao alegada com Git indisponivel.'
& git -C $app switch -q --detach $before.Head
Answer @('2')
Assert ((Select-ImplementationBranch $context $prepared).Detached) 'Escolha atual bloqueou/mudou HEAD destacado.'
Answer @('3','lote/partindo-de-head')
Assert ((Select-ImplementationBranch $context $prepared).Branch -eq 'lote/partindo-de-head') 'Nao criou branch a partir de HEAD destacado.'
Write-Output 'PASS: tres escolhas explicitas, ID automatico, fallback, nomes invalidos/existentes e preservacao local.'
