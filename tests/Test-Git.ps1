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
Assert (-not $observed.PSObject.Properties['Policy']) 'Coleta informativa nao deve carregar politica de branches.'
# Politicas antigas incompletas/duplicadas nao participam da coleta.
$legacy = [pscustomobject]@{source=$null;mainBranch='inexistente';workBranch='outra'}
$context.Config | Add-Member NoteProperty gitPolicies @($legacy,$legacy)
$configPath = Join-Path $fixture 'config.json'
$context.Config | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $configPath
$configHash = (Get-FileHash $configPath).Hash
Assert ((Get-HarnessGitState $context).Status -eq 'VERIFIED') 'Politica antiga interferiu na coleta.'
Assert ((Get-FileHash $configPath).Hash -eq $configHash) 'Coleta alterou configuracao legada.'
Set-Content "$app/modulo/pom.xml" '<project>changed</project>'
$dirty = Get-HarnessGitState $context
Assert ($dirty.Status -eq 'VERIFIED' -and $dirty.HasChanges -and $dirty.Changes.Count -gt 0) 'Alteracoes locais devem ser informativas.'
Assert ($dirty.Head -eq $observed.Head -and $dirty.Branch -eq $observed.Branch) 'Coleta modificou HEAD/branch.'
Assert ((Get-Content "$app/modulo/pom.xml" -Raw).Contains('changed')) 'Coleta descartou alteracao local.'
& git -C $app checkout -q main
Assert ((Get-HarnessGitState $context).Branch -eq 'main') 'Qualquer branch escolhida pelo desenvolvedor deve ser observada.'
& git -C $app checkout -q --detach $observed.Head
$detached = Get-HarnessGitState $context
Assert ($detached.Status -eq 'VERIFIED' -and $detached.Detached -and -not $detached.Branch) 'HEAD destacado deve ser observado sem gate.'
& git -C $app checkout -q lote_cache
& git -C $app add .
& git -C $app -c user.name=HarnessFixture -c user.email=fixture@example.invalid commit -qm segundo
$advanced = Get-HarnessGitState $context
Assert ($advanced.Status -eq 'VERIFIED' -and $advanced.Head -ne $observed.Head) 'Novo commit deve ser observado sem politica.'
$context.Active.path = "$fixture/ausente"
Assert ((Get-HarnessGitState $context).Status -eq 'UNAVAILABLE') 'Fonte ausente deve deixar somente a observacao Git indisponivel.'
Write-Output 'PASS: coleta informativa por modulo, politicas antigas ignoradas, branch/HEAD/estado local sem gate e sem mutacao.'
