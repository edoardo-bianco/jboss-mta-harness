#requires -Version 5.1
$ErrorActionPreference='Stop'; Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'ConversionFixture.ps1')
$f=New-ConversionFixture
$plan=Add-ConversionPlan $f ('a'*32)
[IO.File]::AppendAllText($f.Register,("`n[Plano](<"+$plan.PlanPath+">)`n"))
$cli=Join-Path $root 'tools/transicao/Converter-RegistrosProjeto.ps1'
$parameters=(Get-Command $cli).Parameters
foreach ($name in @('Descartar','Confirmacao')) { Assert ($parameters.ContainsKey($name)) ('CLI deve expor a selecao explicita do descarte: '+$name) }
function Reject-ConversionCli([scriptblock]$Action,[string]$Pattern,[string]$Message) {
    $failed=$false
    try { $null=& $Action } catch { Assert ($_.Exception.Message -match $Pattern) $_.Exception.Message; $failed=$true }
    Assert $failed $Message
}
$before=Get-ConversionState $f
$json=& powershell.exe -NoProfile -File $cli -Workspace $f.Workspace -Pom $f.Pom -Formato Json
Assert ($LASTEXITCODE -eq 0) 'CLI JSON deve funcionar no PS5.1.'
$preview=($json -join "`n")|ConvertFrom-Json
Assert ($preview.Mode -eq 'Previa' -and $preview.Project -eq 'api') 'Modo padrao deve ser previa derivada do POM.'
$text=& $cli -Workspace $f.Workspace -Pom $f.Pom
Assert (($text -join "`n") -match 'Previa sem escrita' -and ($text -join "`n") -match 'PRELIMINAR') 'CLI deve mostrar limites e destino para revisao.'
Reject-ConversionCli { & $cli -Workspace $f.Workspace -Pom $f.Pom -Modo Limpar } 'config|corrente|convert|destino|projeto' 'Limpar exige destino corrente convertido.'
foreach ($mode in @('Previa','Aplicar','Validar')) {
    Reject-ConversionCli { & $cli -Workspace $f.Workspace -Pom $f.Pom -Modo $mode -Confirmacao LIMPAR } 'Limpar|Confirmacao' ('Confirmacao nao pertence ao modo '+$mode)
    Reject-ConversionCli { & $cli -Workspace $f.Workspace -Pom $f.Pom -Modo $mode -Descartar @($plan.PlanPath) } 'Limpar|Descartar' ('Descartar nao pertence ao modo '+$mode)
}
Assert ((Get-ConversionState $f) -ceq $before) 'Previa e recusas nao podem alterar arquivos.'
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
# Integridade operacional permite notas humanas posteriores; descarte exige equivalencia.
$before=Get-ConversionState $f
Reject-ConversionCli { & $cli -Workspace $f.Workspace -Pom $f.Pom -Modo Limpar -Registro $f.Register -Contexto $plan.ContextPath -Descartar @($plan.PlanPath) -Confirmacao LIMPAR -Formato Json } 'equival|alter|difer|convers|destino' 'CLI recusa descarte apos contribuicao humana no destino.'
Assert ((Get-ConversionState $f) -ceq $before) 'Recusa por divergencia preserva origem e contribuicao humana.'

# A limpeza valida usa outra conversao, sem a nota humana que tornou a primeira divergente.
$clean=New-ConversionFixture; $cleanPlan=Add-ConversionPlan $clean ('c'*32)
[IO.File]::AppendAllText($clean.Register,("`n[Plano](<"+$cleanPlan.PlanPath+">)`n"))
$choices=@{Workspace=$clean.Workspace;Pom=$clean.Pom;Registro=$clean.Register;Contexto=$cleanPlan.ContextPath}
$json=& $cli @choices -Modo Aplicar -Formato Json
$null=($json -join "`n")|ConvertFrom-Json
$current=Get-HarnessProjectReference $clean.Workspace $clean.Pom
$selected=@($clean.Register,$cleanPlan.ContextPath,$cleanPlan.PlanPath,$cleanPlan.TodoPath)
$before=Get-ConversionState $clean
$json=& $cli @choices -Modo Limpar -Formato Json 6>&1
$cleanupPreview=($json -join "`n")|ConvertFrom-Json
Assert ($cleanupPreview.Status -ceq 'PREVIA' -and -not $cleanupPreview.DeletionAuthorized) 'Limpar sem selecao nem confirmacao mostra somente a previa.'
foreach ($path in $selected) {
    $candidate=@($cleanupPreview.Candidates|Where-Object Path -IEQ $path)
    Assert ($candidate.Count -eq 1 -and $candidate[0].Eligible -and $candidate[0].Destination) ('Previa do CLI identifica destino comprovado: '+$path)
}
Reject-ConversionCli { & $cli @choices -Modo Limpar -Descartar $selected -Formato Json } 'Confirmacao|confirm' 'Execucao JSON exige confirmacao explicita antes de perguntar ou remover.'
$json=& $cli @choices -Modo Limpar -Descartar $selected -Confirmacao CANCELAR -Formato Json 6>&1
$cancelled=($json -join "`n")|ConvertFrom-Json
Assert ($cancelled.Status -ceq 'CANCELADO' -and @($cancelled.RemovedFiles).Count -eq 0) 'JSON cancelado e puro e nao autoriza retirada.'
Reject-ConversionCli { & $cli @choices -Modo Limpar -Descartar @((Split-Path $cleanPlan.PlanPath -Parent)) -Confirmacao LIMPAR -Formato Json } 'arquivo|diretor|folha|legad' 'Diretorio nao equivale a selecao explicita de arquivos.'
Assert ((Get-ConversionState $clean) -ceq $before) 'Previa, confirmacao ausente, cancelamento e recusa preservam bytes e datas.'

# Sem Formato Json, a ausencia de Confirmacao deve chegar ao prompt humano.
$global:conversionCliPrompt=$null
function global:Read-Host { param([string]$Prompt) $global:conversionCliPrompt=$Prompt; 'CANCELAR' }
try { $text=& $cli @choices -Modo Limpar -Descartar $selected 6>$null }
finally { Remove-Item Function:\Read-Host }
Assert ($global:conversionCliPrompt -match 'LIMPAR' -and ($text -join "`n") -match 'CANCELADO') 'CLI textual encaminha selecao ao prompt e respeita cancelamento.'
Remove-Variable conversionCliPrompt -Scope Global
Assert ((Get-ConversionState $clean) -ceq $before) 'Cancelamento pelo prompt preserva a conversao.'

# Uma interrupcao antes do journal pode ser recuperada sem selecao de arquivos.
$stage=Join-Path $clean.Workspace '.harness/temporarios/conversao-descarte/publicacao'
Write-ConversionFile (Join-Path $stage 'recuperacao.tmp') '[journal ainda nao publicado'
$before=Get-ConversionState $clean
$json=& $cli @choices -Modo Limpar -Formato Json 6>&1
$pendingRecovery=($json -join "`n")|ConvertFrom-Json
Assert ($pendingRecovery.Status -ceq 'RECUPERACAO_PENDENTE') 'CLI informa estagio pendente sem recuperar na previa.'
Assert ((Get-ConversionState $clean) -ceq $before) 'Previa da recuperacao nao escreve.'
$json=& $cli @choices -Modo Limpar -Confirmacao RECUPERAR -Formato Json 6>&1
$recovered=($json -join "`n")|ConvertFrom-Json
Assert ($recovered.Status -ceq 'RECUPERADO' -and @($recovered.RemovedFiles).Count -eq 0 -and -not (Test-Path -LiteralPath $stage)) 'Confirmacao RECUPERAR admite selecao vazia somente para o estagio tecnico.'
foreach ($path in $selected) { Assert (Test-Path -LiteralPath $path -PathType Leaf) 'Recuperar nao inicia descarte dos originais.' }

$currentBefore=Get-ConversionState ([pscustomobject]@{Area=$current.Folder})
$json=& $cli @choices -Modo Limpar -Descartar $selected -Confirmacao LIMPAR -Formato Json 6>&1
$removed=($json -join "`n")|ConvertFrom-Json
Assert ($removed.Status -ceq 'LIMPO' -and @($removed.RemovedFiles).Count -eq $selected.Count) 'CLI remove somente a selecao comprovada e confirmada.'
foreach ($path in $selected) { Assert (-not (Test-Path -LiteralPath $path)) 'Somente os originais selecionados foram retirados.' }
Assert ((Get-ConversionState ([pscustomobject]@{Area=$current.Folder})) -ceq $currentBefore) 'Descarte preserva bytes e datas dos documentos correntes.'
$newFile=Join-Path (Split-Path $cleanPlan.PlanPath -Parent) 'nota-posterior.md'
Write-ConversionFile $newFile '# Nova nota posterior ao descarte'
$before=Get-ConversionState $clean
$json=& $cli @choices -Modo Limpar -Descartar $selected -Confirmacao LIMPAR -Formato Json 6>&1
$repeated=($json -join "`n")|ConvertFrom-Json
Assert ($repeated.Status -ceq 'SEM_RESIDUOS' -and @($repeated.RemovedFiles).Count -eq 0) 'Repeticao nao amplia a selecao para novos arquivos.'
$json=& powershell.exe -NoProfile -NonInteractive -File $cli -Workspace $clean.Workspace -Pom $clean.Pom -Modo Validar -Formato Json
Assert ($LASTEXITCODE -eq 0) 'Validar apos descarte funciona em processo PS5.1 limpo.'
$validAfter=($json -join "`n")|ConvertFrom-Json
Assert ($validAfter.Valid -and $validAfter.Status -ceq 'VALIDO') 'Destino permanece autonomo depois da retirada dos originais.'
Assert ((Get-ConversionState $clean) -ceq $before) 'Repeticao e validacao preservam a nova nota e o destino corrente.'
# O runtime permanente nao importa o utilitario descartavel.
$callers=@(Get-ChildItem (Join-Path $root 'scripts') -File | Select-String -Pattern 'ConversaoPrevia|Converter-RegistrosProjeto|tools[/\\]transicao')
Assert ($callers.Count -eq 0) 'Nucleo nao pode depender do conversor.'
Write-Host 'PASS: CLI PS5.1, previa, aplicar/validar, descarte explicito, JSON puro, cancelamento, recuperacao e independencia.'
