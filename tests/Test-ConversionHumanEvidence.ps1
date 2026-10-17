#requires -Version 5.1
$ErrorActionPreference='Stop'; Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'ConversionFixture.ps1')
Import-Module (Join-Path $root 'tools/transicao/ConversaoPublicacao.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $root 'scripts/HarnessProject.psm1') -DisableNameChecking
$f=New-ConversionFixture
$plan=Add-ConversionPlan $f ('a'*32)
$folder=Split-Path $plan.ContextPath -Parent
$ficha=Join-Path $folder 'ficha.md'; $index=Join-Path $folder 'anexos/LEIA-ME.md'
$binary=Join-Path $folder 'anexos/evidencia.bin'; $external=Join-Path $f.Area 'externo.txt'
$sourceFile=Join-Path $f.Source 'Classe.java'
Write-ConversionFile $sourceFile 'class Classe {}'
Write-ConversionFile $external 'Evidencia fora do harness'
Write-ConversionFile $index "# Evidencias humanas`n[Anexo](<evidencia.bin>)"
[IO.File]::WriteAllBytes($binary,[byte[]](0,255,13,10,222))
Write-ConversionFile $ficha ("# Ficha humana`nRisco observado: manter transacao.`n[Fonte](<"+$sourceFile+">)`n[Anexo](<anexos/evidencia.bin>)")
$plan|Add-Member FichaPath $ficha
$plan|Add-Member EvidenceIndexPath $index
$plan|Add-Member EvidenceInputs @(@{Path=$binary;Relation='Teste humano';Status='DISPONIVEL'},@{Path=$external;Relation='Externo';Status='DISPONIVEL'})
Write-ConversionFile $plan.ContextPath ($plan|ConvertTo-Json -Depth 15)
Write-ConversionFile $plan.PlanPath '# Plano humano - GO PENDENTE'
$originalFicha=[IO.File]::ReadAllText($ficha)
$null=Invoke-ConversionApply $f.Workspace $f.Pom -Contexto $plan.ContextPath
$p=Get-HarnessProjectReference $f.Workspace $f.Pom
$data=Get-Content -LiteralPath $p.ContextPath -Raw|ConvertFrom-Json
Assert ($data.FichaPaths.Count -eq 1) 'Ficha deve estar vinculada ao contexto corrente.'
$currentFicha=[IO.File]::ReadAllText($data.FichaPaths[0].Path)
Assert ($currentFicha -match 'Risco observado' -and $currentFicha -match 'ficha:identidade' -and $currentFicha -notmatch 'plano_[a-f0-9]') 'Preservar texto e eliminar dependencia da solicitacao.'
Assert ($data.EvidenceIndexPath -eq (Join-Path $p.EvidencePath 'LEIA-ME.md')) 'Indice de evidencias corrente.'
Assert (@($data.EvidenceInputs | Where-Object Relation -EQ 'Teste humano').Count -eq 1) 'Relacao humana deve ser preservada.'
Assert ([Convert]::ToBase64String([IO.File]::ReadAllBytes((Join-Path $p.EvidencePath 'evidencia.bin'))) -eq 'AP8NCt4=') 'Binario copiado sem transformar.'
Assert ($external -in @($data.EvidenceInputs.Path) -and -not (Test-Path (Join-Path $p.EvidencePath 'externo.txt'))) 'Anexo externo permanece referencia.'
Assert ([IO.File]::ReadAllText($ficha) -ceq $originalFicha) 'Ficha original preservada.'
$before=Get-ConversionState $f
$again=Invoke-ConversionApply $f.Workspace $f.Pom -Contexto $plan.ContextPath
Assert ($again.Status -eq 'EQUIVALENTE' -and (Get-ConversionState $f) -ceq $before) 'Reaplicacao dos anexos idempotente.'
$other=Join-Path (Split-Path (Split-Path $folder -Parent) -Parent) 'outro/segredo.bin'
Write-ConversionFile $other 'Nao pertence ao contexto'
$plan|Add-Member Consolidated @{Files=@(@{RelativePath='../../outro/segredo.bin'})}
Write-ConversionFile $plan.ContextPath ($plan|ConvertTo-Json -Depth 15)
$before=Get-ConversionState $f
Reject { Invoke-ConversionApply $f.Workspace $f.Pom -Contexto $plan.ContextPath } 'RelativePath fora do contexto deve impedir toda publicacao.'
Assert ((Get-ConversionState $f) -ceq $before) 'Recusa preserva destino, origens e outro projeto.'

$f=New-ConversionFixture; $plan=Add-ConversionPlan $f ('b'*32); $folder=Split-Path $plan.ContextPath -Parent
$copy=Join-Path $folder 'evidencias/anexo.txt'; $original=Join-Path $f.Area 'outra-maquina/anexo.txt'
$index=Join-Path $folder 'evidencias/LEIA-ME.md'; $oldIndex=Join-Path $f.Area 'outra-maquina/LEIA-ME.md'
$humanResult=Join-Path $folder 'evidencias/result.json'; $renamedMta=Join-Path $folder 'evidencias/12345678-dependencies.yaml'
$mtaOrigin=Join-Path $f.Area 'mta-antigo'
Write-ConversionFile $copy 'Anexo consolidado'
Write-ConversionFile $humanResult '{"expectativaHumana":"preservar"}'
Write-ConversionFile $renamedMta 'Diagnostico MTA nao humano'
Write-ConversionFile $index ("# Evidencias`n[Original](<"+$original+">)")
$plan|Add-Member EvidenceIndexPath $index
$plan|Add-Member Run $mtaOrigin
$plan|Add-Member EvidenceInputs @(@{Path=$copy;OriginPath=$original;Relation='Contrato revisado';Status='DISPONIVEL'},@{Path=$humanResult;Relation='Expectativa registrada';Status='DISPONIVEL'})
$plan|Add-Member SourceEvidenceInputs @(@{Path=$original;Relation='Contrato revisado';Status='DISPONIVEL'})
$plan|Add-Member IssueInputs @(@{Id='java::regra';EvidenceIndexOrigin=$oldIndex})
$plan|Add-Member Consolidated @{Files=@(@{RelativePath='evidencias/anexo.txt';OriginPath=$original},@{RelativePath='evidencias/12345678-dependencies.yaml';OriginPath=(Join-Path $mtaOrigin 'output/dependencies.yaml')})}
Write-ConversionFile $plan.ContextPath ($plan|ConvertTo-Json -Depth 15)
$result=Invoke-ConversionApply $f.Workspace $f.Pom -Contexto $plan.ContextPath
$p=Get-HarnessProjectReference $f.Workspace $f.Pom
$data=Get-Content -LiteralPath $p.ContextPath -Raw|ConvertFrom-Json
Assert (@($data.EvidenceInputs | Where-Object Status -EQ 'AUSENTE').Count -eq 0) 'Proveniencia indisponivel nao vira dependencia quando a copia esta disponivel.'
Assert ($original -notin @($data.EvidenceInputs.Path) -and $oldIndex -notin @($data.EvidenceInputs.Path)) 'Proveniencia resolvida somente em memoria.'
Assert ([IO.File]::ReadAllText((Join-Path $p.EvidencePath 'result.json')) -match 'expectativaHumana') 'Nome de diagnostico nao descarta anexo humano declarado.'
Assert (-not (Test-Path (Join-Path $p.EvidencePath '12345678-dependencies.yaml'))) 'Diagnostico renomeado nao vira anexo humano.'
Assert (($result.Diagnostics -join ' ') -match 'Diagnostico legado requer fonte direta') 'Exclusao diagnostica deve ficar explicita.'
Assert ([IO.File]::ReadAllText($data.EvidenceIndexPath) -match '\[Original\]\(<anexo.txt>\)') 'Link ao original deve abrir a copia corrente.'

$ambiguous=Join-Path $folder 'evidencias/manifest.json'; Write-ConversionFile $ambiguous '{"origem":"indefinida"}'
$plan.Consolidated.Files+=@{RelativePath='evidencias/manifest.json'}
Write-ConversionFile $plan.ContextPath ($plan|ConvertTo-Json -Depth 15)
$before=Get-ConversionState $f
Reject { Invoke-ConversionApply $f.Workspace $f.Pom -Contexto $plan.ContextPath } 'Papel ambiguo exige esclarecimento, sem descarte silencioso.'
Assert ((Get-ConversionState $f) -ceq $before) 'Ambiguidade nao altera trabalho publicado.'

$f=New-ConversionFixture; $plan=Add-ConversionPlan $f ('c'*32); $folder=Split-Path $plan.ContextPath -Parent
$old=Join-Path $f.Workspace '.harness/priorizacao/origem-ausente'
$primary=Join-Path $folder 'ficha-regra.md'; $duplicate=Join-Path $folder 'evidencias/abcd-ficha.md'
$design=Join-Path $folder 'evidencias/abcd-design.md'; $sample=Join-Path $folder 'evidencias/efgh-sample.txt'
foreach ($path in @($primary,$duplicate)) { Write-ConversionFile $path '# Ficha humana equivalente' }
Write-ConversionFile $design '# Desenho humano: [Exemplo](sample.txt)'
Write-ConversionFile $sample 'Exemplo humano'
$plan|Add-Member FichaPath $primary
$plan|Add-Member EvidenceInputs @(@{Path=$duplicate;OriginPath=(Join-Path $old 'ficha.md');Relation='Ficha original'},@{Path=$design;OriginPath=(Join-Path $old 'design.md');Relation='Desenho'},@{Path=$sample;OriginPath=(Join-Path $old 'sample.txt');Relation='Exemplo'})
$plan|Add-Member Consolidated @{Files=@(@{RelativePath='ficha-regra.md';OriginPath=(Join-Path $old 'ficha.md')})}
Write-ConversionFile $plan.ContextPath ($plan|ConvertTo-Json -Depth 15)
$null=Invoke-ConversionApply $f.Workspace $f.Pom -Contexto $plan.ContextPath
$p=Get-HarnessProjectReference $f.Workspace $f.Pom
$data=Get-Content -LiteralPath $p.ContextPath -Raw|ConvertFrom-Json
Assert ($data.FichaPaths.Count -eq 1 -and -not (Test-Path (Join-Path $p.EvidencePath 'ficha.md'))) 'Copias equivalentes convergem para a ficha funcional.'
Assert ([IO.File]::ReadAllText($data.FichaPaths[0].Path) -match 'Ficha original') 'Relacao humana da copia consolidada permanece legivel na ficha.'
Assert ([IO.File]::ReadAllText((Join-Path $p.EvidencePath 'design.md')) -match '\[Exemplo\]\(<sample.txt>\)') 'Markdown consolidado resolve relativos pela origem declarada e abre a copia corrente.'
Write-ConversionFile $duplicate '# Conteudo divergente'
$before=Get-ConversionState $f
Reject { Invoke-ConversionApply $f.Workspace $f.Pom -Contexto $plan.ContextPath } 'Copias divergentes da mesma origem nao podem ser escolhidas por papel ou recencia.'
Assert ((Get-ConversionState $f) -ceq $before) 'Conflito entre copias preserva arquivos.'
'PASS: fichas, indice, binario, links locais e anexo externo preservados.'
