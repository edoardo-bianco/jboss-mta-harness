#requires -Version 5.1
$ErrorActionPreference='Stop'; Set-StrictMode -Version Latest
$root=Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $root 'scripts/HarnessIssues.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $root 'scripts/HarnessPlanning.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $root 'scripts/HarnessProject.psm1') -DisableNameChecking
function Assert($ok,[string]$message) { if (-not $ok) { throw $message } }
function Reject([scriptblock]$Action) { $failed=$false; try { & $Action | Out-Null } catch { $failed=$true }; Assert $failed 'Esperava recusa sem sobrescrita.' }
$area=Join-Path $root '.harness/t'
$app=Join-Path $area 'source'
$null=[IO.Directory]::CreateDirectory($app)
[IO.File]::WriteAllText((Join-Path $app 'pom.xml'),'<project><artifactId>simtr-parent</artifactId></project>')
$p=Initialize-HarnessProjectStorage $area (Join-Path $app 'pom.xml')
Update-HarnessProjectDocuments $p
$id='DEV-SWAGGER-JACKSON-01'
$r=Register-HarnessManualIssue -Project $p -Id $id -Title 'Swagger | Jackson'
Assert ($r.FichaPath.EndsWith('\manual\issues\DEV-SWAGGER-JACKSON-01\ficha.md')) 'Manual precisa de pasta literal legivel.'
Assert (Test-Path -LiteralPath $r.FichaPath) 'Cadastro deve publicar ficha.'
$rows=@(Get-HarnessProjectDecisions $p)
Assert ($rows.Count -eq 1 -and $rows[0].Decision -ceq 'A DEFINIR' -and $rows[0].Progress -ceq 'NAO ANALISADA') 'Cadastro nao concede analise ou escolha.'
Assert ($rows[0].Title -ceq 'Swagger | Jackson' -and $rows[0].Note.Contains('/DEV-SWAGGER-JACKSON-01/ficha.md')) 'Registro escapado e link legivel.'
$before=[IO.File]::ReadAllText($p.MigrationPath)
$human=$before.Replace('A DEFINIR | NAO ANALISADA','ADIAR | ANALISADA').Replace('<!-- mta:fim -->',"<!-- mta:fim -->`nNota humana.")
[IO.File]::WriteAllText($p.MigrationPath,$human)
$again=Register-HarnessManualIssue -Project $p -Id $id -Title 'Nao substituir titulo existente'
Assert ([IO.File]::ReadAllText($p.MigrationPath) -ceq $human) 'Repetir cadastro preserva escolhas e notas.'
Assert ($again.Reused) 'Repetir nao cria outra ficha.'
$mta='eap7/weblogic/tests/data::hibernate4-00039'
$path=Get-HarnessIssuePath -Project $p -Category mandatory -Id $mta
Assert ($path.EndsWith('\mandatory\issues\eap7-weblogic-tests-data--hibernate4-00039\ficha.md')) 'MTA deve usar pasta legivel.'
Reject { Register-HarnessManualIssue -Project $p -Id '../DEV-01' -Title 'Invalido' }
Reject { Register-HarnessManualIssue -Project $p -Id 'dev-swagger-jackson-01' -Title 'Colisao' }
# Estado antigo, com link, contexto e evidencia. Nao tocar no log.
$legacy='atual/priorizacao/manual/issues/'+(ConvertTo-HarnessFunctionalPath $id)+'/ficha.md'
$legacyPath=Join-Path $p.Folder $legacy
$null=[IO.Directory]::CreateDirectory((Split-Path $legacyPath -Parent))
[IO.File]::Move($r.FichaPath,$legacyPath)
$oldLink=Get-HarnessSourceLink $p.MigrationPath $legacyPath 'Ficha'
[IO.File]::WriteAllText($p.MigrationPath,$human.Replace((Get-HarnessSourceLink $p.MigrationPath $r.FichaPath 'Ficha'),$oldLink))
$log=Join-Path $p.EvidencePath 'antes.log'
$null=[IO.Directory]::CreateDirectory($p.EvidencePath)
[IO.File]::WriteAllBytes($log,[byte[]]@(239,187,191,65,13,10))
$originalLog=[Convert]::ToBase64String([IO.File]::ReadAllBytes($log))
$contextRelative='atual/planejamento/contexto.json'
Publish-HarnessProjectFiles $p @{$contextRelative=(@{FichaPaths=@(@{Id=$id;Category='manual';Path=$legacyPath});NeedsReview=$true;ReviewReasons=@('Manter')}|ConvertTo-Json -Depth 8)}
$preview=Repair-HarnessManualIssue -Project $p -Id $id
Assert (Test-Path -LiteralPath $legacyPath) 'Conferencia nao move arquivos.'
Assert (-not (Test-Path -LiteralPath $r.FichaPath)) 'Conferencia nao publica.'
# Um arquivo vazio no destino nao autoriza sobrescrever; o operador o preserva primeiro.
[IO.File]::WriteAllText($r.FichaPath,'# ficha')
Reject { Repair-HarnessManualIssue -Project $p -Id $id -Apply }
Assert (Test-Path -LiteralPath $legacyPath) 'Recusa preserva a ficha completa.'
[IO.File]::Delete($r.FichaPath) # Somente o stub sintetico criado acima.
$conversion=Repair-HarnessManualIssue -Project $p -Id $id -Apply
Assert (Test-Path -LiteralPath $r.FichaPath) 'Conversao publicou destino legivel.'
Assert (-not (Test-Path -LiteralPath $legacyPath)) 'Nao manter duas fichas correntes.'
Assert ([Convert]::ToBase64String([IO.File]::ReadAllBytes($log)) -ceq $originalLog) 'Log original intacto.'
Assert ([IO.File]::ReadAllText($p.MigrationPath) -ceq $human) 'Conversao muda apenas destino do link.'
$data=Get-Content -LiteralPath $p.ContextPath -Raw | ConvertFrom-Json
Assert ($data.FichaPaths[0].Path -ceq $r.FichaPath -and $data.NeedsReview -and $data.ReviewReasons[0] -ceq 'Manter') 'Contexto realinhado sem limpar pendencias.'
$twice=Repair-HarnessManualIssue -Project $p -Id $id -Apply
Assert ($twice.ChangedFiles.Count -eq 0) 'Conversao deve ser idempotente.'
Update-HarnessProjectDocuments $p
$e=Get-CurrentPlanningEvidence $p @(Get-HarnessProjectDecisions $p)
Assert ($e.Fichas.Count -eq 1 -and $e.Fichas[0].Status -ceq 'DISPONIVEL') 'Planejamento encontra ficha legivel.'


# Nomes diferentes que colidem nao podem compartilhar a ficha.
$before=[IO.File]::ReadAllText($p.MigrationPath)
Reject { Register-HarnessManualIssue -Project $p -Id 'DEV-swagger-jackson-01' -Title 'Outra identidade' }
Assert ([IO.File]::ReadAllText($p.MigrationPath) -ceq $before) 'Colisao nao pode alterar registro.'
$rows=@([pscustomobject]@{Id='x/y';Category='mandatory';Note=''},[pscustomobject]@{Id='x-y';Category='mandatory';Note=''})
Reject { Get-CurrentPlanningEvidence $p $rows }
Reject { Get-HarnessIssuePath $p manual ('DEV-'+('A'*170)) }
$long=[pscustomobject]@{Name=$p.Name;Folder=($p.Folder+'\'+('x'*150));TemporaryPath=($p.Folder+'\'+('x'*150)+'\temporarios')}
Reject { Get-HarnessIssuePath $long manual DEV-LONG }
# Reparar DEV-A nao deve aceitar ficha cuja identidade e DEV-A-.
$wrong=Join-Path $p.Folder 'atual/priorizacao/manual/issues/DEV-A/ficha.md'
$null=[IO.Directory]::CreateDirectory((Split-Path $wrong -Parent))
[IO.File]::WriteAllText($wrong,("# Ficha`n<!-- ficha:identidade:inicio -->`n"+(@{Project=$p.Name;Category='manual';Id='DEV-A-';LocalPaths=@();EvidencePaths=@()}|ConvertTo-Json -Compress)+"`n<!-- ficha:identidade:fim -->"))
Reject { Repair-HarnessManualIssue $p DEV-A -Apply }
Assert ((Get-Content -LiteralPath $wrong -Raw).Contains('DEV-A-')) 'Reparo preserva outra identidade.'

'PASS: nomes legiveis, cadastro, reparo, limites, colisoes, conflitos e preservacao.'
