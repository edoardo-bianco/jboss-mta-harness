#requires -Version 5.1
$ErrorActionPreference='Stop'; Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'ConversionFixture.ps1')
$f=New-ConversionFixture
$plan=Add-ConversionPlan $f ('a'*32)
[IO.File]::AppendAllText($f.Register,("`n[Plano](<"+$plan.PlanPath+">)`n"))
$cli=Join-Path $root 'tools/transicao/Converter-RegistrosProjeto.ps1'
$before=Get-ConversionState $f
$json=& powershell.exe -NoProfile -File $cli -Workspace $f.Workspace -Pom $f.Pom -Formato Json
Assert ($LASTEXITCODE -eq 0) 'CLI JSON deve funcionar no PS5.1.'
$preview=($json -join "`n")|ConvertFrom-Json
Assert ($preview.Mode -eq 'Previa' -and $preview.Project -eq 'api') 'Modo padrao deve ser previa derivada do POM.'
$text=& $cli -Workspace $f.Workspace -Pom $f.Pom
Assert (($text -join "`n") -match 'Previa sem escrita' -and ($text -join "`n") -match 'PRELIMINAR') 'CLI deve mostrar limites e destino para revisao.'
Reject { & $cli -Workspace $f.Workspace -Pom $f.Pom -Modo Limpar } 'Limpar permanece recusado ate S23.'
Assert ((Get-ConversionState $f) -ceq $before) 'Previa e Limpar bloqueado nao podem alterar arquivos.'
# A interface publica aceita as mesmas escolhas explicitas da API de aplicacao.
$parameters=(Get-Command $cli).Parameters
foreach ($name in @('SourceLegado','Registro','Contexto','MtaDiretorio','PrioritizacaoContexto','BuildResultado','SonarResultado','SonarTentativa','Participantes','Sprints')) {
    Assert ($parameters.ContainsKey($name)) ('CLI deve expor a escolha de conversao: '+$name)
}
$other=Add-ConversionPlan $f ('b'*32)
Write-ConversionFile $other.PlanPath '# Outro plano que nao foi escolhido'
$participants=@{}; $participants[$f.Source]=$f.Pom
$json=& $cli -Workspace $f.Workspace -Pom $f.Pom -Modo Aplicar -Formato Json -SourceLegado $f.Source -Registro $f.Register -Contexto $plan.ContextPath -Participantes $participants
$applied=($json -join "`n")|ConvertFrom-Json
Assert ($applied.Status -ceq 'CONVERTIDO' -and $applied.AuthorizationInherited -eq $false) 'CLI Aplicar publica somente a escolha explicita, sem herdar autorizacao.'
Import-Module (Join-Path $root 'scripts/HarnessProject.psm1') -DisableNameChecking
$project=Get-HarnessProjectReference $f.Workspace $f.Pom
Assert ([IO.File]::ReadAllText($project.PlanPath) -match 'Plano humano' -and [IO.File]::ReadAllText($project.PlanPath) -notmatch 'Outro plano') 'CLI deve encaminhar Contexto, sem eleger o plano mais recente.'
[IO.File]::AppendAllText($project.PlanPath,"`nNota humana posterior a aplicacao pelo CLI.`n")
$before=Get-ConversionState $f
$json=& powershell.exe -NoProfile -File $cli -Workspace $f.Workspace -Pom $f.Pom -Modo Validar -Formato Json
Assert ($LASTEXITCODE -eq 0) 'CLI Validar JSON deve funcionar em processo PS5.1 limpo.'
$validated=($json -join "`n")|ConvertFrom-Json
Assert ($validated.Status -ceq 'VALIDO' -and $validated.Valid -eq $true -and $validated.AuthorizationInherited -eq $false) 'Validar examina a integridade corrente, inclusive apos contribuicao humana.'
$text=& $cli -Workspace $f.Workspace -Pom $f.Pom -Modo Validar
Assert (($text -join "`n") -match 'integridade|operacional' -and ($text -join "`n") -match 'GO|aceite') 'CLI deve explicar o alcance operacional e os limites da validacao.'
Assert ((Get-ConversionState $f) -ceq $before) 'Validar texto/JSON preserva bytes e datas, sem reaplicar conversao.'
$original=[IO.File]::ReadAllText($project.PlanPath)
try {
    [IO.File]::AppendAllText($project.PlanPath,("`n[Legado](<"+$plan.PlanPath+">)`n"))
    $before=Get-ConversionState $f
    $json=& powershell.exe -NoProfile -File $cli -Workspace $f.Workspace -Pom $f.Pom -Modo Validar -Formato Json
    Assert ($LASTEXITCODE -eq 0) 'Pendencia deve ser resultado legivel, sem interromper a saida JSON.'
    $pending=($json -join "`n")|ConvertFrom-Json
    Assert ($pending.Status -ceq 'PENDENTE' -and $pending.Valid -eq $false -and @($pending.Diagnostics).Count -gt 0) 'CLI informa vinculo legado pendente.'
    Assert ((Get-ConversionState $f) -ceq $before) 'CLI nao repara nem regrava uma pendencia.'
} finally { Write-ConversionFile $project.PlanPath $original }
# O runtime permanente nao importa o utilitario descartavel.
$callers=@(Get-ChildItem (Join-Path $root 'scripts') -File | Select-String -Pattern 'ConversaoPrevia|Converter-RegistrosProjeto|tools[/\\]transicao')
Assert ($callers.Count -eq 0) 'Nucleo nao pode depender do conversor.'
Write-Host 'PASS: CLI PS5.1, previa padrao, selecao explicita, aplicar/validar, Limpar bloqueado e independencia.'
