#requires -Version 5.1
$ErrorActionPreference='Stop'; Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'ConversionFixture.ps1')
Import-Module (Join-Path $root 'tools/transicao/ConversaoPublicacao.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $root 'scripts/HarnessProject.psm1') -DisableNameChecking
function Add-LegacyBuild($Fixture,[string]$Name,[string]$Finished,[string]$Status='FAILED',[switch]$NoLog) {
    $folder=Join-Path $Fixture.Workspace ('.harness/builds/apelido/'+$Name)
    $path=Join-Path $folder 'result.json'; $log=Join-Path $folder 'console.log'
    $data=@{RunId=[guid]::NewGuid().ToString('N');Project='apelido';Source=$Fixture.Source;StartedAtUtc='2026-10-01T09:00:00Z';FinishedAtUtc=$Finished;Status=$Status;ExitCode=$(if ($Status -eq 'SUCCEEDED') {0} else {1});Goals='clean verify';JavaHome='C:\jdk8';MavenHome='C:\maven';SettingsPath=$null;JavaVersion='1.8.0';MavenVersion='3.9';LogPath=$log;ResultPath=$path;Error=$(if ($Status -eq 'FAILED') {'Falha no teste'} else {$null});Git=@{Branch='trabalho';Head='abc'}}
    Write-ConversionFile $path ($data|ConvertTo-Json -Depth 8)
    if (-not $NoLog) { Write-ConversionFile $log ('Log da tentativa '+$Name) }
    [pscustomobject]@{Path=$path;Log=$log;Data=$data}
}
$f=New-ConversionFixture
$older=Add-LegacyBuild $f 'antigo' '2026-10-01T10:00:00Z' 'SUCCEEDED'
$latest=Add-LegacyBuild $f 'ultimo' '2026-10-02T10:00:00Z'
[IO.File]::WriteAllText($latest.Log,'Falha na ultima tentativa',[Text.Encoding]::Unicode)
[IO.File]::SetLastWriteTimeUtc($older.Path,[datetime]'2030-01-01T00:00:00Z')
Write-ConversionFile $f.Register ([IO.File]::ReadAllText($f.Register)+"`n[Build](<$($latest.Path)>) e [Log](<$($latest.Log)>)")
$original=[IO.File]::ReadAllText($latest.Path)
$null=Invoke-ConversionApply $f.Workspace $f.Pom
$p=Get-HarnessProjectReference $f.Workspace $f.Pom
$path=Join-Path $p.Folder 'atual/build/resultado.json'
$data=Get-Content -LiteralPath $path -Raw|ConvertFrom-Json
Assert ($data.Status -eq 'FAILED' -and $data.ExitCode -eq 1 -and $data.FinishedAtUtc -eq $latest.Data.FinishedAtUtc) 'Ultima tentativa inclui falha; mtime e sucesso antigo nao elegem outra.'
Assert ($data.Project -ceq 'api' -and $data.Source -ieq $p.Source -and $data.ResultPath -ieq $path -and -not $data.PSObject.Properties['RunId']) 'Identidade/caminhos correntes sem recibo.'
Assert ($data.Git.Branch -ceq 'trabalho' -and $data.Goals -ceq 'clean verify') 'Informacoes de execucao e Git devem ser preservadas.'
Assert ([Convert]::ToBase64String([IO.File]::ReadAllBytes($data.LogPath)) -ceq [Convert]::ToBase64String([IO.File]::ReadAllBytes($latest.Log))) 'Bytes/encoding do log da tentativa selecionada preservados.'
$operation=Get-Content -LiteralPath (Join-Path $p.Folder 'atual/operacao.json') -Raw|ConvertFrom-Json
Assert ($operation.build.Status -eq 'FAILED' -and $operation.build.DateUtc -eq $latest.Data.FinishedAtUtc) 'Operacao conserva resultado/data observados; conversao nao executa build.'
Assert ([IO.File]::ReadAllText($p.IndexPath) -match 'console.log' -and [IO.File]::ReadAllText($p.IndexPath) -match 'FAILED') 'Indice deve abrir o log e mostrar a falha.'
Assert ([IO.File]::ReadAllText($latest.Path) -ceq $original) 'Resultado original preservado.'
$before=Get-ConversionState $f; $again=Invoke-ConversionApply $f.Workspace $f.Pom
Assert ($again.Status -eq 'EQUIVALENTE' -and (Get-ConversionState $f) -ceq $before) 'Reaplicacao nao regrava build.'
$tie=Add-LegacyBuild $f 'empate' $latest.Data.FinishedAtUtc 'SUCCEEDED'
$before=Get-ConversionState $f
Reject {Invoke-ConversionApply $f.Workspace $f.Pom} 'Empate exige escolha explicita.'
Assert ((Get-ConversionState $f) -ceq $before) 'Empate preserva estado.'
$again=Invoke-ConversionApply $f.Workspace $f.Pom -BuildResultado $latest.Path
Assert ($again.Status -eq 'EQUIVALENTE') 'Escolha explicita resolve empate sem modificar o destino.'
Reject {Invoke-ConversionApply $f.Workspace $f.Pom -BuildResultado (Join-Path $f.Area 'outro.json')} 'Escolha invalida nao pode eleger outro build.'
Set-HarnessProjectOperation $p build SUCCEEDED -LogPath $data.LogPath
$index=[IO.File]::ReadAllText($p.IndexPath)
Assert ($index -match 'SUCCEEDED' -and $index -notmatch 'FAILED') 'Runtime corrente atualiza situacao convertida sem deixar falha antiga no indice.'
$before=Get-ConversionState $f
Reject {Invoke-ConversionApply $f.Workspace $f.Pom -BuildResultado $latest.Path} 'Trabalho posterior nao pode ser sobrescrito pela conversao.'
Assert ((Get-ConversionState $f) -ceq $before) 'Conflito preserva trabalho posterior.'

$f=New-ConversionFixture; $latest=Add-LegacyBuild $f 'incompleto' '2026-10-02T10:00:00Z' -NoLog
$before=Get-ConversionState $f
Reject {Invoke-ConversionApply $f.Workspace $f.Pom} 'Log declarado indisponivel nao comprova conjunto utilizavel.'
Assert ((Get-ConversionState $f) -ceq $before) 'Conjunto incompleto nao publica dados parciais.'
$latest.Data.ExitCode=$null; $latest.Data.Error='Java incorreto antes do Maven'
Write-ConversionFile $latest.Path ($latest.Data|ConvertTo-Json -Depth 8)
$localPom=Join-Path $f.Area 'checkout atual/pom.xml'
Write-ConversionFile $localPom ([IO.File]::ReadAllText($f.Pom))
$null=Invoke-ConversionApply $f.Workspace $localPom -SourceLegado $f.Source
$p=Get-HarnessProjectReference $f.Workspace $localPom
$data=Get-Content -LiteralPath (Join-Path $p.Folder 'atual/build/resultado.json') -Raw|ConvertFrom-Json
Assert ($data.Source -ieq $p.Source -and $data.SourceAtBuild -ieq $f.Source) 'Relocalizacao conserva o Source observado no build, sem declarar verificacao do novo checkout.'
Assert ([IO.File]::ReadAllText($data.LogPath) -match 'Log original indisponivel' -and [IO.File]::ReadAllText($data.LogPath) -match 'Java incorreto') 'Erro declarado permanece visivel sem inferir por que o log esta ausente.'
$f=New-ConversionFixture; $latest=Add-LegacyBuild $f 'log-invalido' '2026-10-02T10:00:00Z'
$latest.Data.LogPath=$latest.Path
Write-ConversionFile $latest.Path ($latest.Data|ConvertTo-Json -Depth 8)
$before=Get-ConversionState $f
Reject {Invoke-ConversionApply $f.Workspace $f.Pom} 'Resultado JSON nao pode ser aceito como log, nem copiar o recibo para console.log.'
Assert ((Get-ConversionState $f) -ceq $before) 'Papel de log invalido nao publica nem modifica arquivos.'
'PASS: ultima tentativa build, falha preservada, links, empate/selecoes e reaplicacao.'
