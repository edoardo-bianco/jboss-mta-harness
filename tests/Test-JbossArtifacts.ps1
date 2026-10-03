#requires -Version 5.1
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $root 'scripts/HarnessJbossArtifacts.psm1') -Force -DisableNameChecking
function Assert($condition,$message) { if (-not $condition) { throw $message } }
$area=Join-Path $root ('.harness/tests/jboss artifacts '+[guid]::NewGuid().ToString('N'))
function Write-Fixture {
    param([string]$Path,[string]$Content='fixture')
    $null=[IO.Directory]::CreateDirectory((Split-Path -Parent $Path))
    [IO.File]::WriteAllText($Path,$Content)
}
$project=Join-Path $area 'project with spaces'
Write-Fixture (Join-Path $project 'pom.xml') '<project><modules><module>web</module><module>enterprise</module></modules></project>'
Write-Fixture (Join-Path $project 'web/pom.xml') '<project xmlns="http://maven.apache.org/POM/4.0.0"><modules><module>..</module></modules></project>'
Write-Fixture (Join-Path $project 'enterprise/pom.xml') '<project/>'
Assert (@(Get-HarnessJbossArtifacts $project).Count -eq 0) 'Projeto sem build inventou artefato.'
$war=Join-Path $project 'web/target/app-custom-name.war'
$ear=Join-Path $project 'enterprise/target/application.ear'
Write-Fixture $war
Write-Fixture (Join-Path $project 'web/target/app.jar')
Write-Fixture (Join-Path $project 'web/target/app.war.original')
Write-Fixture (Join-Path $project 'web/target/exploded/nested.war')
Write-Fixture (Join-Path $project 'unrelated/target/other.war')
$candidates=@(Get-HarnessJbossArtifacts $project)
Assert ($candidates.Count -eq 1 -and $candidates[0].ArtifactPath -eq $war -and $candidates[0].ModulePath -eq (Join-Path $project 'web')) 'Descoberta deve respeitar modulos, extensao e target direto.'
$module=Get-Module HarnessJbossArtifacts
function Select-Fixture {
    param([string[]]$Answers)
    & $module {
        param($Project,$Answers)
        $script:answers=New-Object Collections.Queue
        foreach ($answer in $Answers) { $script:answers.Enqueue($answer) }
        function script:Read-Host { param($Prompt) if (-not $script:answers.Count) { throw "Pergunta inesperada: $Prompt" }; $script:answers.Dequeue() }
        Select-HarnessJbossArtifact $Project
    } $project $Answers
}
Assert ((Select-Fixture -Answers @('')) -eq $war) 'Candidato unico deve ser sugerido por Enter.'
Write-Fixture $ear
$candidates=@(Get-HarnessJbossArtifacts $project)
Assert ($candidates.Count -eq 2) 'Agregador deve listar WAR e EAR, sem escolher automaticamente.'
$selected=Select-Fixture -Answers @('2')
Assert ($selected -eq $candidates[1].ArtifactPath) 'Selecao nao respeitou o numero informado.'
foreach ($answer in @('','q','9','invalido')) {
    $cancelled=$false
    try { Select-Fixture -Answers @($answer) | Out-Null } catch { $cancelled=$_.Exception.Message -match 'Selecao cancelada' }
    Assert $cancelled 'Multiplos candidatos exigem escolha valida, sem padrao.'
}
$manual=Join-Path $area 'custom output/manual.ear'
Write-Fixture $manual
Assert ((Select-Fixture -Answers @('m',$manual)) -eq $manual) 'Entrada manual deixou de estar disponivel.'
$empty=Join-Path $area 'empty'
Write-Fixture (Join-Path $empty 'pom.xml') '<project/>'
$project=$empty
Assert ((Select-Fixture -Answers @($manual)) -eq $manual) 'Ausencia de build deve permitir informar caminho manual.'
$cancelled=$false
try { Select-Fixture -Answers @('') | Out-Null } catch { $cancelled=$_.Exception.Message -match 'Selecao cancelada' }
Assert $cancelled 'Ausencia de build nao deve selecionar artefato inexistente.'
# Propriedades Maven nao resolvidas nao devem impedir o uso do artefato da raiz.
Write-Fixture (Join-Path $project 'pom.xml') '<project><modules><module>${optional.module}</module></modules></project>'
$rootWar=Join-Path $project 'target/root.war'
Write-Fixture $rootWar
Assert ((Select-Fixture -Answers @('')) -eq $rootWar) 'Modulo dinamico impediu descoberta local.'
# Entrada real, com adaptadores de servidor ficticios: nenhum Java pode ser iniciado.
$fixture=Join-Path $area 'harness'
$scripts=Join-Path $fixture 'scripts'
$null=[IO.Directory]::CreateDirectory($scripts)
Copy-Item -Path (Join-Path $root 'scripts/*.psm1') -Destination $scripts
Copy-Item -LiteralPath (Join-Path $root 'scripts/gerenciar-jboss.ps1') -Destination $scripts
@'
function Get-HarnessJbossServer {
    param($Context,$Eap)
    [pscustomobject]@{Home='fixture';Settings=[pscustomobject]@{standaloneConfig='standalone.xml';debugPort=8787};HttpPort=8080;ManagementPort=9990}
}
Export-ModuleMember -Function Get-HarnessJbossServer
'@ | Set-Content -LiteralPath (Join-Path $scripts 'HarnessJbossRuntime.psm1') -Encoding UTF8
@'
function Invoke-HarnessJbossRelease {
    param($Context,$Server,$Action,$ArtifactPath,$DeploymentName,$ReleaseId)
    $result=[pscustomobject]@{Status='SUCCEEDED';ArtifactSource=$ArtifactPath;DeploymentName=$DeploymentName;Source=$Context.Active.path}
    $result | ConvertTo-Json -Compress | Add-Content -LiteralPath (Join-Path $Context.Root 'selected.jsonl')
    $result
}
Export-ModuleMember -Function Invoke-HarnessJbossRelease
'@ | Set-Content -LiteralPath (Join-Path $scripts 'HarnessJboss.psm1') -Encoding UTF8
$config=Get-Content (Join-Path $root 'config/harness.example.json') -Raw | ConvertFrom-Json
$config.activeProject='fixture'
$config.repositories=@([pscustomobject]@{name='fixture';path=$project})
$configPath=Join-Path $fixture 'config.json'
$config | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $configPath -Encoding UTF8
$entry=Join-Path $scripts 'gerenciar-jboss.ps1'
$arguments=@('-NoProfile','-File',$entry,'-ConfigPath',$configPath,'-Eap','eap71','-Action','Deploy','-Target','fixture','-DeploymentName','stable.war')
$output='' | & powershell.exe @arguments 2>&1 | Out-String
Assert ($LASTEXITCODE -eq 0 -and $output.Contains('WAR/EAR encontrados')) "Deploy nao ofereceu descoberta: $output"
$selected=Get-Content (Join-Path $fixture 'selected.jsonl') | Select-Object -Last 1 | ConvertFrom-Json
Assert ($selected.ArtifactSource -eq $rootWar -and $selected.DeploymentName -eq 'stable.war' -and $selected.Source -eq $project) 'Deploy perdeu artefato/projeto/nome estavel.'
$output=& powershell.exe @arguments -ArtifactPath $manual 2>&1 | Out-String
Assert ($LASTEXITCODE -eq 0 -and -not $output.Contains('WAR/EAR encontrados')) 'ArtifactPath explicito deve evitar descoberta e perguntas.'
$selected=Get-Content (Join-Path $fixture 'selected.jsonl') | Select-Object -Last 1 | ConvertFrom-Json
Assert ($selected.ArtifactSource -eq $manual) 'Deploy ignorou ArtifactPath explicito.'
$output='q' | & powershell.exe @arguments 2>&1 | Out-String
Assert ($LASTEXITCODE -eq 1 -and @(Get-Content (Join-Path $fixture 'selected.jsonl')).Count -eq 2) 'Cancelamento enviou deploy.'
Write-Output 'PASS: descoberta WAR/EAR, modulos/ciclos, ambiguidade, build ausente, caminho manual e entrada real do deploy com adaptadores ficticios.'
