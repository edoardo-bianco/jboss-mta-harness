#requires -Version 5.1
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $root 'scripts/HarnessGit.psm1') -Force -DisableNameChecking
function Assert($condition, $message) { if (-not $condition) { throw $message } }
$fixture = Join-Path $root ('.harness/tests/g' + [guid]::NewGuid().ToString('N').Substring(0,8))
$null = New-Item -ItemType Directory -Path "$fixture/app/modulo", "$fixture/h" -Force
$app = Join-Path $fixture 'app'
& git init -q -b main $app
Set-Content "$app/modulo/pom.xml" '<project/>'
& git -C $app add .
& git -C $app -c user.name=HarnessFixture -c user.email=fixture@example.invalid commit -qm fixture
if ($LASTEXITCODE) { throw 'Falha ao criar commit somente da fixture.' }
& git -C $app branch main_jboss_eap74
& git -C $app checkout -qb lote_cache main_jboss_eap74
$context = [pscustomobject]@{Root="$fixture/h"; Active=[pscustomobject]@{name='app';label='App';path="$app/modulo"};Config=[pscustomobject]@{}}
$observed = Get-HarnessGitState $context
Assert ($observed.Status -eq 'VERIFIED' -and $observed.RepositoryRoot -eq $app -and $observed.Branch -eq 'lote_cache' -and $observed.Module -eq 'modulo') 'Coleta deve partir do modulo, nao da raiz do harness.'
$guard = Test-HarnessGitState $context $observed
Assert (-not $guard.Ready) 'Branch observada nao pode ser autorizada implicitamente.'
$policy = [pscustomobject]@{source="$app/modulo";repositoryRoot=$app;mainBranch='main';migrationBranch='main_jboss_eap74';workBranch='lote_cache';owner='Fixture';coordination='lote_cache'}
$context.Config | Add-Member NoteProperty gitPolicies @($policy)
$configPath = Join-Path $fixture 'config.json'
$context | Add-Member NoteProperty ConfigPath $configPath
[IO.File]::WriteAllText($configPath, '{"tools":{"preserve":true},"gitPolicies":[{"source":"C:/other/app","owner":"Other"}]}')
$global:harnessGitTestAnswers = New-Object 'Collections.Generic.Queue[string]'
function global:Read-Host { param($Prompt) $global:harnessGitTestAnswers.Dequeue() }
try {
    foreach ($answer in @('main','main_jboss_eap74','lote_cache','Fixture','lote_cache','')) { $global:harnessGitTestAnswers.Enqueue($answer) }
    Set-HarnessGitPolicyInteractive $context
    $saved = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
    Assert ($saved.tools.preserve -and $saved.gitPolicies.Count -eq 2) 'Cadastro deve preservar ferramentas e politicas de outros projetos.'
    Assert ((Get-HarnessGitState $context).Branch -eq 'lote_cache') 'Cadastro trocou branch.'
    $configHash = (Get-FileHash $configPath).Hash
    $global:harnessGitTestAnswers.Enqueue('q')
    $cancelled=$false
    try { Set-HarnessGitPolicyInteractive $context } catch { $cancelled=$true }
    Assert ($cancelled -and (Get-FileHash $configPath).Hash -eq $configHash) 'Cancelamento alterou configuracao.'
} finally {
    Remove-Item Function:\Read-Host
    Remove-Variable harnessGitTestAnswers -Scope Global
}
$observed = Get-HarnessGitState $context
Assert ((Test-HarnessGitState $context $observed).Ready) 'Estado limpo e declarado deveria passar pela conferencia Git.'
Set-Content "$app/modulo/pom.xml" '<project>changed</project>'
Assert (-not (Test-HarnessGitState $context $observed).Ready) 'Alteracao local apos planejamento nao bloqueou.'
$dirty = Get-HarnessGitState $context
Assert ($dirty.HasChanges -and -not (Test-HarnessGitState $context $dirty).Ready) 'Arvore suja nao deve ser aprovada implicitamente.'
& git -C $app checkout -- modulo/pom.xml
& git -C $app checkout -q main
Assert (-not (Test-HarnessGitState $context $observed).Ready) 'Branch divergente nao bloqueou.'
& git -C $app checkout -q --detach $observed.Head
Assert ((Get-HarnessGitState $context).Detached) 'HEAD destacado nao detectado.'
Assert (-not (Test-HarnessGitState $context $observed).Ready) 'HEAD destacado aceito.'
& git -C $app checkout -q lote_cache
Set-Content "$app/modulo/untracked.txt" 'first'
$untracked = Get-HarnessGitState $context
Set-Content "$app/modulo/untracked.txt" 'second'
Assert ((Get-HarnessGitState $context).StateSha256 -ne $untracked.StateSha256) 'Edicao de arquivo nao rastreado deve alterar digest.'
& git -C $app add .
& git -C $app -c user.name=HarnessFixture -c user.email=fixture@example.invalid commit -qm segundo
Assert (-not (Test-HarnessGitState $context $observed).Ready) 'Novo HEAD na mesma branch nao bloqueou.'
$context.Active.path = "$fixture/ausente"
Assert ((Get-HarnessGitState $context).Status -eq 'UNAVAILABLE') 'Fonte ausente deveria deixar Git pendente.'
Write-Output 'PASS: raiz/modulo reais, politica explicita, branch divergente, alteracoes locais e HEAD destacado.'
