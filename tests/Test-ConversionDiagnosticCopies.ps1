#requires -Version 5.1
$ErrorActionPreference='Stop'; Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'ConversionFixture.ps1')
Import-Module (Join-Path $root 'tools/transicao/ConversaoPublicacao.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $root 'tools/transicao/ConversaoPrevia.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $root 'tools/transicao/ConversaoValidacao.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $root 'scripts/HarnessProject.psm1') -DisableNameChecking

$f=New-ConversionFixture
$plan=Add-ConversionPlan $f ('a'*32) -ProjectFolder api
$folder=Split-Path $plan.ContextPath -Parent
$origin=Join-Path $f.Area 'mta externo'
Write-ConversionFile (Join-Path $origin 'index.html') '<html>Relatorio MTA original</html>'
$apps=@(@{artifactId='api';rulesets=@(@{name='java';violations=@{regra=@{description='Migrar API';category='mandatory';incidents=@()}}})})
Write-ConversionFile (Join-Path $origin 'output.js') ('window["apps"] = '+(ConvertTo-Json -InputObject $apps -Depth 12 -Compress)+';')
$manifest=Join-Path $folder 'evidencias/manifest.json'
$result=Join-Path $folder 'evidencias/result.json'
$data=@{RunId=('b'*32);Project='apelido';Source=$f.Source;SourceFiles=@(@{path='Classe.java';sha256=('A'*64)})}
Write-ConversionFile $manifest ($data|ConvertTo-Json -Depth 5)
Write-ConversionFile $result (@{Source=$f.Source;RunId=('b'*32);Status='SUCCEEDED'}|ConvertTo-Json)
$plan.PlanningBasis='MTA'
$plan|Add-Member Run $origin
$plan|Add-Member Consolidated @{Files=@(
    @{RelativePath='evidencias/manifest.json';OriginPath=(Join-Path $origin 'manifest.json')},
    @{RelativePath='evidencias/result.json';OriginPath=(Join-Path $origin 'result.json')}
)}
Write-ConversionFile $plan.ContextPath ($plan|ConvertTo-Json -Depth 12)
Write-ConversionFile $plan.PlanPath '# Plano humano - [Manifesto antigo](evidencias/manifest.json)'
$before=Get-ConversionState $f
$preview=Get-ConversionPreview $f.Workspace $f.Pom -Contexto $plan.ContextPath
Assert (@($preview.Attachments|Where-Object Kind -EQ 'COPIA_DIAGNOSTICO_LEGADO').Count -eq 2) 'Origem declarada deve identificar as duas copias MTA.'
Assert (@($preview.Related|Where-Object Kind -EQ 'PLANNING').Count -eq 0) 'Copias MTA reconhecidas nao podem voltar como conteudo PLANNING desconhecido.'
Assert ((Get-ConversionState $f) -ceq $before) 'Previa de copias MTA deve preservar entradas.'
$originals=@($manifest,$result) | ForEach-Object { [pscustomobject]@{Path=$_;Text=[IO.File]::ReadAllText($_);Ticks=[IO.File]::GetLastWriteTimeUtc($_).Ticks} }
$applied=Invoke-ConversionApply $f.Workspace $f.Pom -Contexto $plan.ContextPath
$project=Get-HarnessProjectReference $f.Workspace $f.Pom
Assert ($applied.Status -ceq 'CONVERTIDO' -and (Test-ConversionCurrent $f.Workspace $f.Pom).Valid) 'Plano com copias diagnosticas e MTA direto deve converter e validar.'
Assert ([IO.File]::ReadAllText($project.PlanPath) -match 'mta%20externo/index.html|mta externo/index.html') 'Referencia diagnostica deve abrir o relatorio original.'
foreach ($item in $originals) {
    Assert ([IO.File]::ReadAllText($item.Path) -ceq $item.Text -and [IO.File]::GetLastWriteTimeUtc($item.Path).Ticks -eq $item.Ticks) 'Originais diagnosticos devem permanecer intactos.'
    Assert (-not (Test-Path -LiteralPath (Join-Path $project.EvidencePath ([IO.Path]::GetFileName($item.Path))))) 'Metadados MTA nao devem virar anexos humanos.'
}
Assert (-not (Test-Path -LiteralPath (Join-Path $project.Folder 'atual/diagnosticos/mta'))) 'MTA externo nao deve ser copiado.'

# Mesmo nome e Source nao bastam: sem proveniencia, o complemento segue pendente.
$plan.Consolidated.Files=@()
Write-ConversionFile $plan.ContextPath ($plan|ConvertTo-Json -Depth 12)
$before=Get-ConversionState $f
$preview=Get-ConversionPreview $f.Workspace $f.Pom -Contexto $plan.ContextPath
Assert (@($preview.Related|Where-Object Kind -EQ 'PLANNING').Count -eq 2) 'Manifesto e resultado sem proveniencia nao podem ser ignorados pelo nome.'
Reject { Invoke-ConversionApply $f.Workspace $f.Pom -Contexto $plan.ContextPath } 'Origem nao comprovada deve impedir nova publicacao.'
Assert ((Get-ConversionState $f) -ceq $before) 'Recusa deve preservar publicacao anterior e legados.'

# Anexo com Sources conflitantes nao recebe a identidade do plano por conveniencia.
$plan.Consolidated.Files=@(@{RelativePath='evidencias/manifest.json';OriginPath=(Join-Path $origin 'manifest.json')},@{RelativePath='evidencias/result.json';OriginPath=(Join-Path $origin 'result.json')})
$data.Projects=@(@{Source=(Join-Path $f.Area 'outro-projeto')})
Write-ConversionFile $manifest ($data|ConvertTo-Json -Depth 5)
Write-ConversionFile $plan.ContextPath ($plan|ConvertTo-Json -Depth 12)
$before=Get-ConversionState $f
Reject { Invoke-ConversionApply $f.Workspace $f.Pom -Contexto $plan.ContextPath } 'Metadados multiprojeto nao podem virar copia diagnostica de um projeto.'
Assert ((Get-ConversionState $f) -ceq $before) 'Conflito de Sources preserva todos os arquivos.'
Write-Host 'PASS: copias MTA reconhecidas pela proveniencia, fontes diretas e recusa de identidade ambigua.'
