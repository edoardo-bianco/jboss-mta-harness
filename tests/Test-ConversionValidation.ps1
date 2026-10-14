#requires -Version 5.1
$ErrorActionPreference='Stop'; Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'ConversionFixture.ps1')
Import-Module (Join-Path $root 'scripts/HarnessProject.psm1') -DisableNameChecking
Import-Module (Join-Path $root 'tools/transicao/ConversaoPublicacao.psm1') -DisableNameChecking
$f=New-ConversionFixture
$plan=Add-ConversionPlan $f ('a'*32)
[IO.File]::AppendAllText($f.Register,("`n[Plano](<"+$plan.PlanPath+">)`n"))
$null=Invoke-ConversionApply -Workspace $f.Workspace -Pom $f.Pom -Contexto $plan.ContextPath
$project=Get-HarnessProjectReference $f.Workspace $f.Pom
# Cada validacao usa processo limpo; nenhum modulo leitor/conversor legado pode entrar.
$reader=Join-Path $f.Area 'validar-corrente.ps1'
Write-ConversionFile $reader @'
param($HarnessRoot,$Workspace,$Pom)
$ErrorActionPreference='Stop'; Set-StrictMode -Version Latest
Import-Module (Join-Path $HarnessRoot 'tools/transicao/ConversaoValidacao.psm1') -DisableNameChecking
$result=Test-ConversionCurrent -Workspace $Workspace -Pom $Pom
if (@(Get-Module | Where-Object Name -Match '^(ConversaoPublicacao|ConversaoPrevia|Legado)').Count) { throw 'Validar corrente importou leitor legado ou publicacao.' }
$result|ConvertTo-Json -Depth 30
'@
function Read-TestValidation([bool]$ExpectedValid,[string]$Message) {
    $before=Get-ConversionState $f
    $json=& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $reader -HarnessRoot $root -Workspace $f.Workspace -Pom $f.Pom
    Assert ($LASTEXITCODE -eq 0) ('Validacao em processo limpo falhou: '+$Message)
    $result=($json -join "`n")|ConvertFrom-Json
    Assert ((Get-ConversionState $f) -ceq $before) ('Validar deve preservar bytes/datas e nao gravar relatorio ou mapa: '+$Message)
    Assert ($result.Valid -is [bool] -and $result.Valid -eq $ExpectedValid) ($Message+' Diagnosticos: '+($result.Diagnostics|ConvertTo-Json -Depth 10 -Compress))
    Assert ($result.Status -ceq $(if ($ExpectedValid) {'VALIDO'} else {'PENDENTE'})) 'Status deve refletir somente integridade operacional.'
    Assert ($result.AuthorizationInherited -eq $false) 'Validar nao concede revisao, GO ou aceite humano.'
    if (-not $ExpectedValid) { Assert (@($result.Diagnostics).Count -gt 0) 'Pendencia deve indicar o problema encontrado.' }
    $result
}
$current=Get-Content -LiteralPath $project.ContextPath -Raw|ConvertFrom-Json
Assert ($current.NeedsReview -and $current.PlanningBasis -ceq 'EVIDENCIAS') 'Fixture deve conter plano EVIDENCIAS ainda sujeito a revisao humana.'
$null=Read-TestValidation $true 'Registro e plano EVIDENCIAS integros devem validar mesmo com revisao humana pendente.'

# Remove o legado do workspace somente dentro da fixture, sem apagar as fontes.
$offline=Join-Path $f.Area 'legado-fora-do-workspace'
$fixtureRoot=[IO.Path]::GetFullPath((Join-Path $root '.harness/tests'))+'\'
foreach ($pair in @(@((Join-Path $f.Workspace '.harness/planning'),(Join-Path $offline 'planning')),@((Split-Path $f.Register -Parent),(Join-Path $offline 'projeto')))) {
    foreach ($path in $pair) { Assert ([IO.Path]::GetFullPath($path).StartsWith($fixtureRoot,[StringComparison]::OrdinalIgnoreCase)) 'Movimento de diretorio deve permanecer sob .harness/tests.' }
    $null=[IO.Directory]::CreateDirectory((Split-Path $pair[1] -Parent))
    Move-Item -LiteralPath $pair[0] -Destination $pair[1]
}
foreach ($path in @($project.MigrationPath,$project.PlanPath,$project.TodoPath)) { [IO.File]::AppendAllText($path,"`nNota humana posterior: conferir janela com a equipe.`n") }
$null=Read-TestValidation $true 'Estado corrente deve validar sem controles legados e preservar as notas humanas posteriores.'

$original=[IO.File]::ReadAllText($project.PlanPath)
try {
    [IO.File]::AppendAllText($project.PlanPath,("`n[Plano legado](<"+$plan.PlanPath+">)`n"))
    $result=Read-TestValidation $false 'Link operacional para o planejamento legado deve ficar pendente.'
    Assert (($result.Diagnostics|ConvertTo-Json -Depth 10) -match 'legad|planning|referencia|vinculo|link') 'Diagnostico deve localizar a dependencia legada.'
} finally { Write-ConversionFile $project.PlanPath $original }

$original=[IO.File]::ReadAllText($project.ContextPath)
try {
    $changed=ConvertFrom-Json $original; $changed.Source=Join-Path $f.Area 'outro-source'
    Write-ConversionFile $project.ContextPath ($changed|ConvertTo-Json -Depth 20)
    $result=Read-TestValidation $false 'Contexto Source incoerente deve ficar pendente.'
    Assert (($result.Diagnostics|ConvertTo-Json -Depth 10) -match 'Source|identidade|contexto') 'Diagnostico deve explicar a identidade incoerente.'
    $changed=ConvertFrom-Json $original
    $changed.EvidenceInputs+=@([pscustomobject]@{Path=(Join-Path $project.EvidencePath 'confirmacao-pendente.md');Relation='Confirmacao humana ainda ausente';Status='AUSENTE'})
    Write-ConversionFile $project.ContextPath ($changed|ConvertTo-Json -Depth 20)
    $result=Read-TestValidation $false 'Ausencia explicitamente declarada permanece pendente, sem gerar evidencia ou aceite.'
    Assert (($result.Diagnostics|ConvertTo-Json -Depth 10) -match 'ausen|pendente|evidencia') 'Ausencia deve permanecer visivel no diagnostico.'
} finally { Write-ConversionFile $project.ContextPath $original }

$original=[IO.File]::ReadAllText($project.ConfigPath)
try {
    $changed=ConvertFrom-Json $original; $changed.pom=Join-Path $f.Source 'modulo/pom.xml'
    Write-ConversionFile $project.ConfigPath ($changed|ConvertTo-Json -Depth 10)
    $null=Read-TestValidation $false 'Associacao de projeto para outro POM deve ficar pendente.'
} finally { Write-ConversionFile $project.ConfigPath $original }
$null=Read-TestValidation $true 'Restaurar somente as inconsistencias recupera a integridade, sem reexecutar conversao.'
'PASS: validacao corrente independente do legado, sem escrita, com identidade e referencias verificadas.'
