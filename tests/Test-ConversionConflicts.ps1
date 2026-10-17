#requires -Version 5.1
$ErrorActionPreference='Stop'; Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'ConversionFixture.ps1')
Import-Module (Join-Path $root 'tools/transicao/ConversaoPrevia.psm1') -Force -DisableNameChecking
$f=New-ConversionFixture
$a=Add-ConversionPlan $f ('a'*32)
$unlinked=Get-ConversionPreview $f.Workspace $f.Pom
Assert ($null -eq $unlinked.Planning.ContextPath -and $unlinked.Planning.Candidates.Count -eq 1) 'Plano unico sem vinculo nao comprova uso.'
[IO.File]::AppendAllText($f.Register,("`n[Plano](<"+$a.PlanPath+">)`n"))
$other=Join-Path $f.Workspace '.harness/projetos/outra-origem/migracao.md'
Write-ConversionFile $other ([IO.File]::ReadAllText($f.Register))
$before=Get-ConversionState $f
$ambiguous=Get-ConversionPreview $f.Workspace $f.Pom
Assert ($null -eq $ambiguous.Register.Path -and $null -eq $ambiguous.Planning.ContextPath -and $ambiguous.Register.Candidates.Count -eq 2) 'Dois registros exigem escolha, mesmo com conteudo igual.'
$chosen=Get-ConversionPreview $f.Workspace $f.Pom -Registro $f.Register
Assert ($chosen.Register.Path -eq $f.Register -and $chosen.Planning.ContextPath -eq $a.ContextPath) 'Registro explicito deve resolver associacao.'
Assert ((Get-ConversionState $f) -ceq $before) 'Escolha nao altera nenhum registro.'
# Uma escolha nao torna um ciclo valido.
$b=Add-ConversionPlan $f ('b'*32) $a.RequestId
$a.Previous=@{RequestId=$b.RequestId;ContextPath=$b.ContextPath}
Write-ConversionFile $a.ContextPath ($a|ConvertTo-Json -Depth 15)
$before=Get-ConversionState $f
$cycle=Get-ConversionPreview $f.Workspace $f.Pom -Registro $other -Contexto $b.ContextPath
Assert ($null -eq $cycle.Planning.ContextPath -and ($cycle.Pending -join ' ') -match 'Ciclo') 'Escolha explicita nao pode esconder ciclo em Previous.'
Assert ((Get-ConversionState $f) -ceq $before) 'Ciclo nao pode provocar reparo.'
$f=New-ConversionFixture
$target=Join-Path $f.Workspace '.harness/projetos/api/projeto.json'
Write-ConversionFile $target (@{pom=(Join-Path $f.Source 'modulo/pom.xml')}|ConvertTo-Json)
$before=Get-ConversionState $f
Reject { Get-ConversionPreview $f.Workspace $f.Pom } 'Colisao de artifactId deve recusar previa.'
Assert ((Get-ConversionState $f) -ceq $before) 'Colisao nao altera dados.'
$f=New-ConversionFixture
Write-ConversionFile (Join-Path $f.Workspace '.harness/projetos/nome-anterior/projeto.json') (@{pom=$f.Pom}|ConvertTo-Json)
$before=Get-ConversionState $f
Reject { Get-ConversionPreview $f.Workspace $f.Pom } 'POM ja associado a outra pasta exige realinhamento.'
Assert ((Get-ConversionState $f) -ceq $before) 'Renomeacao nao pode acontecer na previa.'
$f=New-ConversionFixture
Write-ConversionFile (Join-Path $f.Workspace '.harness/projetos/api/temporarios/publicacao/transacao.json') '{}'
$before=Get-ConversionState $f
Reject { Get-ConversionPreview $f.Workspace $f.Pom } 'Publicacao pendente deve recusar leitura sem recuperar.'
Assert ((Get-ConversionState $f) -ceq $before) 'Previa nao recupera publicacao.'
Write-Host 'PASS: ambiguidades, ciclo, colisao, realinhamento e recuperacao sem escrita.'
