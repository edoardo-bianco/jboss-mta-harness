#requires -Version 5.1
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$root=Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $root 'scripts/HarnessProject.psm1') -Force -DisableNameChecking
function Assert($condition,[string]$message) { if (-not $condition) { throw $message } }
function Reject([scriptblock]$action,[string]$message) { $failed=$false; try { & $action | Out-Null } catch { $failed=$true }; Assert $failed $message }
$area=Join-Path $root ('.harness/tests/publicacao-'+[guid]::NewGuid().ToString('N').Substring(0,8))
$app=Join-Path $area 'app'; $null=[IO.Directory]::CreateDirectory($app)
[IO.File]::WriteAllText((Join-Path $app 'pom.xml'),'<project><artifactId>servico</artifactId></project>')
$project=Initialize-HarnessProjectStorage -Root $area -Pom (Join-Path $app 'pom.xml')
$files=[ordered]@{'atual/planejamento/plano.md'='plano um';'atual/planejamento/tarefas.md'='tarefas um'}
Publish-HarnessProjectFiles -Project $project -Files $files
Assert ([IO.File]::ReadAllText($project.PlanPath) -ceq 'plano um') 'Publicacao inicial deve disponibilizar plano.'
Assert ([IO.File]::ReadAllText($project.TodoPath) -ceq 'tarefas um') 'Publicacao inicial deve disponibilizar tarefas.'
Assert (-not (Test-Path -LiteralPath $project.TemporaryPath)) 'Sucesso nao pode deixar material de recuperacao.'
Reject { Publish-HarnessProjectFiles $project @{'../fora.txt'='nao'} } 'Escrita fora do projeto deve ser recusada.'
Reject { Publish-HarnessProjectFiles $project @{'temporarios/injetado.json'='nao'} } 'Publicacao nao pode escrever no proprio protocolo de recuperacao.'
$files['atual/planejamento/plano.md']='plano dois'; $files['atual/planejamento/tarefas.md']='tarefas dois'
Reject { Publish-HarnessProjectFiles $project $files -Expected @{'atual/planejamento/plano.md'='plano desatualizado'} } 'Edicao humana divergente deve impedir sobrescrita.'
Assert ([IO.File]::ReadAllText($project.PlanPath) -ceq 'plano um') 'Conflito deve preservar documentos.'
# Falhar depois da primeira escrita real. O contrato observado e a recuperacao
# dos dois documentos, nao a implementacao usada para trocar cada arquivo.
$module=Get-Module HarnessProject
& $module { $script:originalWriter=${function:Write-ProjectPublishedFile}; $script:writes=0
    function script:Write-ProjectPublishedFile { param($Source,$Destination)
        & $script:originalWriter $Source $Destination
        $script:writes++
        if ($script:writes -eq 1) { throw 'falha injetada depois da escrita' }
    }
}
Reject { Publish-HarnessProjectFiles $project $files } 'Falha injetada deve ser reportada.'
& $module { ${function:Write-ProjectPublishedFile}=$script:originalWriter }
Assert ([IO.File]::ReadAllText($project.PlanPath) -ceq 'plano um') 'Falha deve recuperar plano anterior.'
Assert ([IO.File]::ReadAllText($project.TodoPath) -ceq 'tarefas um') 'Falha deve recuperar tarefas anteriores.'
Publish-HarnessProjectFiles $project $files
$values=Read-HarnessProjectFiles $project @('atual/planejamento/plano.md','atual/planejamento/tarefas.md')
Assert ($values['atual/planejamento/plano.md'] -ceq 'plano dois' -and $values['atual/planejamento/tarefas.md'] -ceq 'tarefas dois') 'Leitor deve observar um conjunto completo.'
Assert (-not (Test-Path -LiteralPath $project.TemporaryPath)) 'Segunda publicacao nao cria revisoes.'
'PASS: publicacao, conflito, recuperacao e leitura consistente sem recibos permanentes.'
