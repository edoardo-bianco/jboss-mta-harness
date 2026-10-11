# Fixtures sinteticas do contrato corrente; nenhuma origem real e modificada.
$root=Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $root 'scripts/HarnessProject.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $root 'scripts/HarnessPrioritization.psm1') -Force -DisableNameChecking
function Assert($Value,[string]$Message) { if (-not $Value) { throw $Message } }
function Reject([scriptblock]$Action,[string]$Message) {
    $failed=$false
    try { & $Action | Out-Null } catch { $failed=$true }
    Assert $failed $Message
}
function New-Fixture {
    param([int]$Count=10,[string[]]$Names=@('a'),[string[]]$Categories=@('mandatory'))
    $area=Join-Path $root ('.harness/tests/p'+[guid]::NewGuid().ToString('N').Substring(0,6))
    $null=[IO.Directory]::CreateDirectory((Join-Path $area '.github/prompts'))
    Copy-Item -LiteralPath (Join-Path $root '.github/prompts/priorizar-issues.prompt.md') -Destination (Join-Path $area '.github/prompts/priorizar-issues.prompt.md')
    $null=[IO.Directory]::CreateDirectory((Join-Path $area 'doc/adr'))
    Copy-Item -LiteralPath (Join-Path $root 'doc/adr/0009-estado-corrente-por-projeto.md') -Destination (Join-Path $area 'doc/adr/0009-estado-corrente-por-projeto.md')
    $projects=@()
    foreach ($name in $Names) {
        $app=Join-Path $area ('app-'+$name); $null=[IO.Directory]::CreateDirectory($app)
        [IO.File]::WriteAllText((Join-Path $app 'pom.xml'),('<project><artifactId>'+$name+'</artifactId></project>'))
        $project=Initialize-HarnessProjectStorage $area (Join-Path $app 'pom.xml')
        Publish-HarnessProjectFiles $project @{'projeto.json'=(@{pom=$project.Pom;mta=@{diretorio=('mta-'+$name)}} | ConvertTo-Json)}
        $null=[IO.Directory]::CreateDirectory((Join-Path $app 'src'))
        [IO.File]::WriteAllText((Join-Path $app 'src/Exemplo.java'),'// fonte sintetica')
        $null=[IO.Directory]::CreateDirectory($project.EvidencePath)
        [IO.File]::WriteAllText((Join-Path $project.EvidencePath 'observacao.md'),'Anexo humano sintetico.')
        Set-FixtureMta $project $Count $Categories
        Update-HarnessProjectDocuments $project (Read-HarnessProjectMta $project) -UpdateIssues
        $projects+=$project
    }
    [pscustomobject]@{Root=$area;Projects=$projects;Context=[pscustomobject]@{Root=$area;Projects=@($projects | ForEach-Object {[pscustomobject]@{name=$_.Name;label=$_.Name;path=$_.Source}})}}
}
function Set-FixtureMta {
    param($Project,[int]$Count,[string[]]$Categories=@('mandatory'),[string]$Name='corrente',[string[]]$Omit=@())
    $folder=Join-Path $Project.Root ('mta-'+$Project.Name+'/'+$Name)
    $null=[IO.Directory]::CreateDirectory($folder)
    $violations=[ordered]@{}
    foreach ($category in $Categories) { for ($i=1;$i -le $Count;$i++) {
        $key=$category+'-'+$i
        if ($key -in $Omit) { continue }
        $violations[$key]=@{description=('Problema '+$i);category=$category;incidents=@(@{uri='src/Exemplo.java';lineNumber=1;codeSnip='NAO_COPIAR_INCIDENTE'})}
    } }
    $apps=@(@{artifactId=$Project.Name;rulesets=@(@{name='java';violations=$violations})})
    [IO.File]::WriteAllText((Join-Path $folder 'output.js'),('window["apps"] = '+(ConvertTo-Json -InputObject $apps -Depth 15 -Compress)+';'))
    [IO.File]::WriteAllText((Join-Path $folder 'index.html'),'<html>MTA sintetico</html>')
}
function Read-Prepared($Prepared) { Get-Content -LiteralPath $Prepared.ContextPath -Raw -Encoding UTF8 | ConvertFrom-Json }
function Read-Result($Prepared) {
    $text=[IO.File]::ReadAllText($Prepared.RankingPath)
    $match=[regex]::Match($text,'(?s)<!-- priorizacao:resultado:inicio -->\s*(.*?)\s*<!-- priorizacao:resultado:fim -->')
    ConvertFrom-Json $match.Groups[1].Value
}
function Write-Ficha($Fixture,$Data,$Issue) {
    $entry=@($Data.FichaPaths | Where-Object { $_.Project -ceq $Issue.Project -and $_.Id -ceq $Issue.Id })[0]
    $project=@($Fixture.Projects | Where-Object Name -CEQ $Issue.Project)[0]
    $identity=@{Project=$Issue.Project;Id=$Issue.Id;Category=$Data.Category;LocalPaths=@('src/Exemplo.java','pom.xml');EvidencePaths=@('observacao.md')} | ConvertTo-Json -Compress
    $text="# Ficha examinada`n`nAnalise manual preservada: aplicabilidade conferida na fonte sintetica.`n`n## Roteiro`nConferir chamada e executar teste focal.`n`n<!-- ficha:identidade:inicio -->`n$identity`n<!-- ficha:identidade:fim -->`n"
    $relative=$entry.Path.Substring($project.Folder.Length+1)
    Publish-HarnessProjectFiles $project @{$relative=$text}
}
function Complete-Slice($Fixture,$Prepared,[int]$Count=-1,[string]$Status='COMPLETED') {
    $data=Read-Prepared $Prepared; $result=Read-Result $Prepared
    if ($Count -lt 0) { $Count=$data.SliceSize }
    $current=@($result.AnalyzedIssues | ForEach-Object {$_.Project+'|'+$_.Id})
    foreach ($issue in @($data.AvailableIssues | Where-Object { ($_.Project+'|'+$_.Id) -cnotin $current } | Select-Object -First $Count)) {
        Write-Ficha $Fixture $data $issue
        $result.AnalyzedIssues+=@([pscustomobject]@{Project=$issue.Project;Id=$issue.Id;Position=$null;Reason='Examinada sem proposta: teste focal insuficiente.'})
    }
    $result.Status=$Status
    $text=[IO.File]::ReadAllText($Prepared.RankingPath)
    $text=Set-ProjectManagedBlock $text 'priorizacao:resultado' ($result | ConvertTo-Json -Depth 10)
    [IO.File]::WriteAllText($Prepared.RankingPath,$text)
    $result
}
