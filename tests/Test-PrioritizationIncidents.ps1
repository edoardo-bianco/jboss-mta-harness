#requires -Version 5.1
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $root 'scripts/Harness.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $root 'scripts/HarnessPrioritization.psm1') -Force -DisableNameChecking
function Assert($condition, $message) { if (-not $condition) { throw $message } }
function Reject($action, $message) {
    $failed = $false
    try { & $action | Out-Null } catch { $failed = $true }
    Assert $failed $message
}
function Read-Receipt($prepared) { Get-Content -LiteralPath $prepared.ContextPath -Raw -Encoding UTF8 | ConvertFrom-Json }
function Normalize-PathText([string]$text) { $text.Replace('\\','\').Replace('\','/').Replace('%20',' ') }
function Assert-Preserved($files) {
    foreach ($file in $files) {
        Assert ((Get-FileHash -LiteralPath $file.Path -Algorithm SHA256).Hash -eq $file.Hash) ('Entrada/historico alterado: ' + $file.Path)
    }
}

# Area curta para tambem executar no Windows PowerShell 5.1 com MAX_PATH.
$area = Join-Path $root ('.harness/tests/inc-' + [guid]::NewGuid().ToString('N').Substring(0,8))
$fixture = Join-Path $area 'h'
$source = Join-Path $area 'source atual'
$run = Join-Path $area 'mta recebido'
$analysisSource = Join-Path $run 'input'
$runId = 'b' * 32
$ruleId = 'eap7/weblogic/tests/data::hibernate4-00039'
$relativeSource = 'src/ApensoAdministrativoServico.java'
$oldInput = 'file:///C:/origem/.harness/runs/app/mta_2026-09-30_07-57-02-0300__' + $runId.Substring(0,12) + '/input/'
$uri = $oldInput + $relativeSource
foreach ($folder in @($source,$analysisSource,(Join-Path $run 'rules'),(Join-Path $run 'output/static-report'))) {
    $null = [IO.Directory]::CreateDirectory($folder)
}
foreach ($base in @($source,$analysisSource)) {
    foreach ($relative in @($relativeSource,'src/Ultimo.java','src/SemDetalhe.java')) {
        $path = Join-Path $base $relative
        $null = [IO.Directory]::CreateDirectory((Split-Path $path -Parent))
        [IO.File]::WriteAllText($path, '// Fonte sintetica: confrontar conteudo; linha MTA nao prova linha atual.')
    }
    Set-Content -LiteralPath (Join-Path $base 'pom.xml') '<project/>'
}
Write-HarnessJson (Join-Path $run 'manifest.json') @{RunId=$runId;Project='origem';Source='C:/origem/app';CreatedAtUtc='2026-10-05T10:00:00Z'}
Write-HarnessJson (Join-Path $run 'result.json') @{RunId=$runId;Project='origem';Status='SUCCEEDED';ExitCode=0;SourceUnchanged=$true;SnapshotOriginalFilesUnchanged=$true;RulesUnchanged=$true;UnexpectedAddedFiles=@()}
foreach ($relative in @('output/output.yaml','output/dependencies.yaml','output/static-report/index.html')) {
    Set-Content -LiteralPath (Join-Path $run $relative) 'Fixture sintetica: os incidentes estruturados estao no output.js.'
}
$incidents = @(foreach ($number in 1..138) {
    $line = if ($number -eq 1) { 54 } elseif ($number -eq 2) { 61 } else { 100 + $number }
    [ordered]@{
        uri=$uri
        message=('EVIDENCIA-{0:000}: conferir byte[]/Byte[] no Oracle12cDialect; a ocorrencia nao prova persistencia.' -f $number)
        codeSnip=("$line public byte[] criaRelatorioPAE() {`n" + ($line + 1) + ' return new byte[0];' + "`n}")
        lineNumber=$line
    }
})
$incidents[131].uri = 'file:///C:/origem/.harness/runs/app/mta_2026-09-30_07-57-02-0300__aaaaaaaaaaaa/input/src/OutraRodada.java'
$incidents[132].uri = 'file:///C:/m2/dependencia/input/src/ExternalInput.java'
$incidents[133].uri = 'file:///C:/m2/dependencia/External.java'
$incidents[134].uri = $oldInput + '../escape.java'
$incidents[135].uri = $oldInput + '%2e%2e/escape-codificado.java'
$incidents[136] = [ordered]@{uri=($oldInput + 'src/SemDetalhe.java')}
$incidents[137].uri = $oldInput + 'src/Ultimo.java'
$violations = [ordered]@{
    'hibernate4-00039'=[ordered]@{
        description='Hibernate Oracle12cDialect e bytes'
        category='mandatory'
        incidents=$incidents
    }
}
$apps = @([ordered]@{name='app';rulesets=@([ordered]@{name='eap7/weblogic/tests/data';violations=$violations})})
$catalog = Join-Path $run 'output/static-report/output.js'
[IO.File]::WriteAllText($catalog, ('window["apps"] = ' + (ConvertTo-Json -InputObject $apps -Depth 20 -Compress) + ';'))

$project = [pscustomobject]@{name='app';label='app';path=$source}
$context = [pscustomobject]@{Root=$fixture;Projects=@($project);ConfigPath=$null;WorkspacePath=$null}
$paths = Initialize-HarnessMigration $fixture $project
$index = Join-Path $fixture '.harness/projetos/indice-projetos.md'
Set-Content -LiteralPath $index '# Indice sintetico: mandatory 1 / 138'
foreach ($relative in @('doc/especificacoes/planejamento-copilot.md','.github/prompts/priorizar-issues.prompt.md')) {
    $destination = Join-Path $fixture $relative
    $null = [IO.Directory]::CreateDirectory((Split-Path $destination -Parent))
    Copy-Item -LiteralPath (Join-Path $root $relative) -Destination $destination
}
$origin = @{RunId=$runId;Project='origem';Source='C:/origem/app';Run=$run} | ConvertTo-Json -Compress
$record = [IO.File]::ReadAllText($paths.MigrationPath).Replace('AGUARDANDO MTA', '')
$record = $record.Replace('<!-- mta:fim -->', ((@("<!-- MTA $origin -->", "Rodada MTA: $runId.", "| $ruleId | Hibernate Oracle12cDialect e bytes | mandatory | 138 | PRESENTE | A DEFINIR | NAO ANALISADA | |") -join "`n") + "`n<!-- mta:fim -->"))
[IO.File]::WriteAllText($paths.MigrationPath, $record)
$inputs = @(Get-ChildItem -LiteralPath $area -Recurse -File | Get-FileHash -Algorithm SHA256)

$prepared = New-HarnessPrioritizationContext $context -Mode Recreate -Percentage 100
$receipt = Read-Receipt $prepared
$mta = $receipt.Projects[0].Mta
Assert ($null -ne $mta -and $null -ne $mta.PSObject.Properties['IncidentEvidence']) 'REGRESSAO: contexto tem contagem/catalogo, mas nao entrega IncidentEvidence para o agente localizar os 138 incidentes.'
$evidence = $mta.IncidentEvidence
Assert ($evidence.Status -eq 'AVAILABLE') ('Catalogo utilizavel nao exportado: ' + $evidence.Diagnostic)
Assert ($receipt.InitialTotal -eq 1 -and $receipt.SliceSize -eq 1) 'Ocorrencias alteraram a unidade de quota Source/ID.'
Assert ($evidence.IndexPath -and (Test-Path -LiteralPath $evidence.IndexPath -PathType Leaf)) 'Indice dos incidentes ausente.'
$indexText = [IO.File]::ReadAllText($evidence.IndexPath)
Assert ($indexText.Contains($ruleId) -and $indexText.Contains('138')) 'Indice nao identifica regra e contagem original.'
Assert (@($evidence.Files | Where-Object Path -EQ $evidence.IndexPath).Count -eq 1) 'Indice deve integrar a lista de arquivos com hash.'
$pages = @($evidence.Files | Where-Object Path -NE $evidence.IndexPath)
Assert ($pages.Count -eq 14) '138 incidentes devem gerar 14 paginas com no maximo 10 incidentes cada.'
$allPages = @()
foreach ($file in $evidence.Files) {
    $fullPath = [IO.Path]::GetFullPath($file.Path)
    $requestFolder = [IO.Path]::GetFullPath((Split-Path $prepared.ContextPath -Parent)).TrimEnd('\','/') + [IO.Path]::DirectorySeparatorChar
    Assert ($fullPath.StartsWith($requestFolder,[StringComparison]::OrdinalIgnoreCase)) 'Exportacao fora da pasta da solicitacao.'
    Assert ((Get-FileHash -LiteralPath $file.Path -Algorithm SHA256).Hash -eq $file.Sha256) 'Hash da evidencia derivada nao corresponde ao arquivo.'
}
foreach ($page in $pages) {
    $pageText = [IO.File]::ReadAllText($page.Path)
    $allPages += $pageText
    $markers = @([regex]::Matches($pageText, 'EVIDENCIA-\d{3}') | ForEach-Object Value | Select-Object -Unique)
    Assert ($markers.Count -le 10) 'Pagina exige ler mais de dez incidentes.'
}
$detail = $allPages -join "`n"
foreach ($number in @(1..136) + @(138)) {
    $marker = 'EVIDENCIA-{0:000}' -f $number
    Assert (([regex]::Matches($detail,[regex]::Escape($marker))).Count -eq 1) ('Incidente perdido ou duplicado: ' + $marker)
}
Assert ($detail.Contains($uri) -and $detail.Contains('54 public byte[]') -and $detail.Contains('61 public byte[]')) 'URI historico/linhas 54 e 61 nao preservados.'
Assert ($detail.Contains("55 return new byte[0];`n}") -and $detail.Contains("62 return new byte[0];`n}")) 'Trechos multiline foram achatados ou truncados.'
$normalized = Normalize-PathText $detail
foreach ($base in @($source,$analysisSource)) {
    Assert ($normalized.Contains((Normalize-PathText (Join-Path $base $relativeSource)))) 'URI sob input nao oferece caminho candidato na raiz atual.'
    Assert ($normalized.Contains((Normalize-PathText (Join-Path $base 'src/Ultimo.java')))) 'Ultimo incidente da ultima pagina nao foi remapeado.'
    foreach ($unsafe in @('src/OutraRodada.java','src/ExternalInput.java','External.java','../escape.java','escape.java','../escape-codificado.java','escape-codificado.java','C:/m2/dependencia/External.java')) {
        Assert (-not $normalized.Contains((Normalize-PathText ($base.TrimEnd('\','/') + '/' + $unsafe)))) 'Dependencia externa ou travessia produziu candidato local indevido.'
    }
}
Assert ($detail.Contains('file:///C:/m2/dependencia/External.java') -and $detail.Contains($incidents[134].uri) -and $detail.Contains($incidents[135].uri)) 'URI externa/travessia deve continuar visivel como evidencia original.'
Assert ($detail.Contains($incidents[131].uri) -and $detail.Contains($incidents[132].uri)) 'URI de outra rodada/dependencia com input deve permanecer visivel, sem candidato inventado.'
Assert ($detail.Contains('SemDetalhe.java')) 'Incidente so com URI foi descartado.'
Assert ($detail -match '(?i)ausente|indisponivel|nao informado|nao fornecid') 'Campos ausentes nao foram declarados como lacuna.'
Assert ($detail -match '(?i)candidat' -and $detail -match '(?i)aplicabilidade|conferir|comparar') 'Exportacao apresenta caminho candidato como conclusao sobre codigo/aplicabilidade.'

# Os links do indice devem resolver as paginas da propria solicitacao, sem caminho absoluto.
$linked = @([regex]::Matches($indexText,'\]\((?:<)?([^)>]+\.md)(?:>)?\)') | ForEach-Object { $_.Groups[1].Value })
foreach ($page in $pages) {
    $resolved = @($linked | Where-Object { -not [IO.Path]::IsPathRooted($_) } | ForEach-Object {
        [IO.Path]::GetFullPath((Join-Path (Split-Path $evidence.IndexPath -Parent) ([Uri]::UnescapeDataString($_))))
    })
    Assert ($page.Path -in $resolved) 'Indice nao oferece link relativo para uma pagina exportada.'
}
Assert (-not (Test-Path -LiteralPath $prepared.RankingPath)) 'Preparo inventou ranking.'
Assert-Preserved $inputs

# Retomada nao reexporta evidencias nem ignora alteracao de uma pagina vinculada.
$historical = @(@($prepared.ContextPath,$prepared.PromptPath) + @($evidence.Files.Path) | ForEach-Object { Get-FileHash -LiteralPath $_ -Algorithm SHA256 })
$resumed = New-HarnessPrioritizationContext $context -Mode Continue
Assert ($resumed.RequestId -eq $prepared.RequestId -and $resumed.Reused) 'Preparo pendente nao foi retomado.'
Assert-Preserved $historical
$pagePath = $pages[0].Path
$originalPage = [IO.File]::ReadAllText($pagePath)
[IO.File]::WriteAllText($pagePath, ($originalPage + "`nALTERACAO EXTERNA"))
try {
    Reject { New-HarnessPrioritizationContext $context -Mode Continue } 'Retomada ignorou hash alterado da evidencia derivada.'
} finally { [IO.File]::WriteAllText($pagePath, $originalPage, (New-Object Text.UTF8Encoding($false))) }
$recreated = New-HarnessPrioritizationContext $context -Mode Recreate -Percentage 100
$nextReceipt = Read-Receipt $recreated
Assert ($recreated.RequestId -ne $prepared.RequestId -and $nextReceipt.Previous.RequestId -eq $prepared.RequestId) 'Recriacao nao preservou a cadeia.'
Assert ($nextReceipt.Projects[0].Mta.IncidentEvidence.IndexPath -ne $evidence.IndexPath) 'Recriacao reutilizou arquivos mutaveis de outra solicitacao.'
Assert-Preserved $historical
Assert-Preserved $inputs

# Catalogo indisponivel nao autoriza reutilizar detalhes de outro preparo nem inventar incidentes.
Move-Item -LiteralPath $catalog -Destination ($catalog + '.saved')
try {
    $missing = Read-Receipt (New-HarnessPrioritizationContext $context -Mode Recreate -Percentage 100)
    $unavailable = $missing.Projects[0].Mta.IncidentEvidence
    Assert ($unavailable.Status -eq 'UNAVAILABLE' -and -not $unavailable.IndexPath -and @($unavailable.Files).Count -eq 0) 'Catalogo ausente virou exportacao disponivel ou reaproveitou detalhes antigos.'
    Assert (-not [string]::IsNullOrWhiteSpace($unavailable.Diagnostic)) 'Catalogo ausente nao tem diagnostico concreto.'
} finally { Move-Item -LiteralPath ($catalog + '.saved') -Destination $catalog }
Assert-Preserved $inputs
Write-Output 'PASS: 138 incidentes completos/paginados, URI historica, caminhos candidatos, lacunas, hashes e preservacao.'
