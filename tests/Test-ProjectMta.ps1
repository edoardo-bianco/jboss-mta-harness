#requires -Version 5.1
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$root=Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $root 'scripts/HarnessProject.psm1') -Force -DisableNameChecking
function Assert($value,[string]$message) { if (-not $value) { throw $message } }
function Reject([scriptblock]$action,[string]$message) { $failed=$false; try { & $action | Out-Null } catch { $failed=$true }; Assert $failed $message }
$area=Join-Path $root ('.harness/tests/mta-direto-'+[guid]::NewGuid().ToString('N').Substring(0,8))
$app=Join-Path $area 'app'; $external=Join-Path $area 'relatorios externos'
$null=[IO.Directory]::CreateDirectory($app)
[IO.File]::WriteAllText((Join-Path $app 'pom.xml'),'<project><artifactId>servico</artifactId></project>')
$project=Initialize-HarnessProjectStorage $area (Join-Path $app 'pom.xml')
Publish-HarnessProjectFiles $project @{'projeto.json'=([ordered]@{pom=$project.Pom;mta=@{diretorio='relatorios externos'}} | ConvertTo-Json)}
function Add-Report([string]$Name,[datetime]$Date,[string]$Artifact='servico') {
    $folder=Join-Path $external $Name; $null=[IO.Directory]::CreateDirectory($folder)
    $catalog=Join-Path $folder 'output.js'; $entry=Join-Path $folder 'index.html'
    $apps=@(@{artifactId=$Artifact;rulesets=@(@{name='java';violations=@{'regra'= @{description='Problema';category='mandatory';incidents=@(@{uri='src/Exemplo.java';lineNumber=12})}}})})
    [IO.File]::WriteAllText($catalog,('window["apps"] = '+(ConvertTo-Json -InputObject $apps -Depth 12 -Compress)+';'))
    [IO.File]::WriteAllText($entry,'<html>Relatorio sintetico</html>')
    [IO.File]::SetLastWriteTimeUtc($entry,$Date); $folder
}
Reject { Read-HarnessProjectMta $project } 'Origem externa ausente nao deve usar destino interno.'
$older=Add-Report 'a' ([datetime]'2026-10-01T12:00:00Z')
$first=Read-HarnessProjectMta $project
Assert ($first.ReportPath -ceq (Join-Path $older 'index.html')) 'MTA sem manifest deve ser reconhecido diretamente.'
Assert ($first.Issues.Count -eq 1 -and $first.Issues[0].Id -ceq 'java::regra') 'Leitor deve preservar chave e categoria.'
Assert ($first.Issues[0].Count -eq 1) 'Incidentes devem estar disponiveis em memoria.'
$newer=Add-Report 'b' ([datetime]'2026-10-02T12:00:00Z')
$second=Read-HarnessProjectMta $project
Assert ($second.ReportPath -ceq (Join-Path $newer 'index.html')) 'Novo MTA deve ser reconhecido sem adotar/cadastrar.'
$tie=Add-Report 'c' ([datetime]'2026-10-02T12:00:00Z')
$tied=Read-HarnessProjectMta $project
Assert ($tied.ReportPath -ceq $second.ReportPath) 'Empate deve seguir caminho ordinal.'
Assert ($tied.Diagnostics.Count -gt 0) 'Empate deve ser informado.'
$incomplete=Add-Report 'd' ([datetime]'2026-10-03T12:00:00Z')
[IO.File]::WriteAllText((Join-Path $incomplete 'output.js'),'window["apps"] = [')
$fallback=Read-HarnessProjectMta $project
Assert ($fallback.ReportPath -ceq $second.ReportPath -and $fallback.Diagnostics.Count -gt 0) 'Candidato recente invalido deve ser explicitado ao mostrar utilizavel anterior.'
$wrong=Add-Report 'e' ([datetime]'2026-10-04T12:00:00Z') 'outra-aplicacao'
$selected=Read-HarnessProjectMta $project
Assert ($selected.ReportPath -cne (Join-Path $wrong 'index.html') -and ($selected.Diagnostics -join ' ') -match 'outra aplicacao') 'Origem inequivoca de outra aplicacao nao pode ser incorporada.'
Assert (-not (Test-Path -LiteralPath (Join-Path $project.Folder 'atual/diagnosticos'))) 'Ler MTA externo nao pode gerar copia interna.'
Assert (@(Get-ChildItem -LiteralPath $project.Folder -Recurse -File).Count -eq 1) 'Leitura nao pode criar extrato, recibo ou cache.'
$before=[IO.File]::ReadAllText((Join-Path $older 'output.js'))
$null=Read-HarnessProjectMta $project
Assert ([IO.File]::ReadAllText((Join-Path $older 'output.js')) -ceq $before) 'Relatorio externo deve permanecer intacto.'
$dated=Add-Report 'fuso' ([datetime]'2020-01-01T00:00:00Z')
$datedCatalog=Join-Path $dated 'output.js'
$raw=[IO.File]::ReadAllText($datedCatalog).Replace('"artifactId":','"generatedAt":"2026-10-09T23:00:00-03:00","artifactId":')
[IO.File]::WriteAllText($datedCatalog,$raw)
$withDate=Read-HarnessProjectMta $project
Assert ($withDate.ReportPath -ceq (Join-Path $dated 'index.html') -and $withDate.DateUtc -eq ([DateTimeOffset]'2026-10-10T02:00:00Z').UtcDateTime) 'Data de geracao deve ser comparada em UTC, antes do mtime.'
$module=Get-Module HarnessProject
& $module {
    $script:savedStamp=${function:Get-ProjectMtaStamp}
    $script:stampCalls=0
    Set-Item function:script:Get-ProjectMtaStamp { param($Entry,$Catalog); $script:stampCalls++; [string]$script:stampCalls }
}
try { Reject { Read-HarnessProjectMta $project } 'Regravacao durante a leitura deve interromper a operacao inteira, sem selecionar outro relatorio.' }
finally { & $module { Set-Item function:script:Get-ProjectMtaStamp $script:savedStamp } }
# Rodadas reais guardam fontes em input e o relatorio em output/static-report.
$round=Add-Report 'rodada/output/static-report' ([datetime]'2026-10-11T12:00:00Z')
$sourceReport=Add-Report 'rodada/input/assets' ([datetime]'2099-10-11T12:00:00Z')
$web=Join-Path $external 'rodada/input/src/main/webapp'
$null=[IO.Directory]::CreateDirectory($web)
[IO.File]::WriteAllText((Join-Path $web 'index.html'),'<html>Pagina da aplicacao, sem catalogo MTA</html>')
$readPaths=New-Object 'Collections.Generic.List[string]'
$actual=Read-HarnessMtaDirectory $project $external -FileReader {
    param($Path)
    $readPaths.Add($Path)
    [IO.File]::ReadAllText($Path)
}
Assert ($actual.ReportPath -ceq (Join-Path $round 'index.html')) 'Input da rodada nao pode disputar selecao com o relatorio em output.'
Assert (-not @($readPaths | Where-Object { $_.Contains('\input\') }).Count -and ($actual.Diagnostics -join ' ') -notmatch '\\input\\') 'HTML e dados da aplicacao em input nao devem ser lidos como relatorios ou gerar avisos MTA.'
$incompleteRound=Add-Report 'incompleta/output/static-report' ([datetime]'2026-10-12T12:00:00Z')
[IO.File]::Delete((Join-Path $incompleteRound 'output.js'))
$withIncomplete=Read-HarnessProjectMta $project
Assert ($withIncomplete.ReportPath -ceq (Join-Path $round 'index.html') -and ($withIncomplete.Diagnostics -join ' ').Contains($incompleteRound)) 'Relatorio incompleto em output continua sendo lacuna explicita.'
$explicitInput=Read-HarnessMtaDirectory $project $sourceReport
Assert ($explicitInput.ReportPath -ceq (Join-Path $sourceReport 'index.html')) 'Origem explicita nao pode ser recusada por conter input no caminho.'
'PASS: MTA direto, origem unica, recencia, empate, falhas e ausencia de copias.'
