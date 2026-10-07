#requires -Version 5.1
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $root 'scripts/HarnessMcpSettings.psm1') -Force -DisableNameChecking
function Assert($condition,$message) { if (-not $condition) { throw $message } }
function Rejected([scriptblock]$action) {
    try { & $action | Out-Null; return $false } catch { return $true }
}
$area=Join-Path $root ('.harness/tests/mcp-roots-'+[guid]::NewGuid().ToString('N'))
$fixture=Join-Path $area 'harness'
$source=Join-Path $area 'codigo com espacos'
$second=Join-Path $area 'outro projeto'
$runs=Join-Path $area 'rodadas MTA'
$newRuns=Join-Path $area 'novas rodadas'
foreach ($dir in @($fixture,$source,$second,$runs,$newRuns)) { $null=[IO.Directory]::CreateDirectory($dir) }
foreach ($dir in @($source,$second)) { [IO.File]::WriteAllText((Join-Path $dir 'pom.xml'),'<project/>') }
$workspace=Join-Path $fixture 'ensaio.code-workspace'
$config=Join-Path $fixture 'harness.json'
$utf8=[Text.UTF8Encoding]::new($false)
$workspaceJson='{"folders":[{"path":"."},{"path":"../codigo com espacos"},{"path":"../codigo com espacos"},],"settings":{"url":"https://example.invalid/"},/*comentario*/}'
[IO.File]::WriteAllText($workspace,$workspaceJson,$utf8)
function Set-MtaRoot($path) {
    [IO.File]::WriteAllText($config,(@{schemaVersion=1;mta=@{runsPath=$path}} | ConvertTo-Json -Depth 5),$utf8)
}
Set-MtaRoot '../rodadas MTA'
$argsRoots=@{Root=$fixture;AllowedRoots=@($fixture);WorkspacePath=$workspace;HarnessConfigPath=$config}
$workspaceBefore=[IO.File]::ReadAllText($workspace)
$configBefore=[IO.File]::ReadAllText($config)
$actual=@(Get-HarnessMcpAllowedRoots @argsRoots)
Assert ($actual.Count -eq 3 -and $actual -contains $fixture -and $actual -contains $source -and $actual -contains $runs) 'Raizes devem vir do workspace/JSONC e mta.runsPath relativo ao harness, sem duplicatas.'
$null=[IO.Directory]::CreateDirectory((Join-Path $runs 'projeto/rodada-nova'))
Assert ((@(Get-HarnessMcpAllowedRoots @argsRoots) -join '|') -eq ($actual -join '|')) 'Nova rodada nao deve exigir nova permissao.'
Assert ([IO.File]::ReadAllText($workspace) -ceq $workspaceBefore) 'Consulta alterou workspace.'
Assert ([IO.File]::ReadAllText($config) -ceq $configBefore) 'Consulta alterou configuracao.'
$otherRecords=Join-Path $fixture 'registros'
$null=[IO.Directory]::CreateDirectory($otherRecords)
$otherRoots=@(Get-HarnessMcpAllowedRoots -Root $otherRecords -AllowedRoots @($fixture) -WorkspacePath $workspace -HarnessConfigPath $config -PathBase $fixture)
Assert ($otherRoots -contains $runs) 'Raiz alternativa de registros nao deve mudar a base de mta.runsPath relativo.'
[IO.File]::WriteAllText($workspace,'{"folders":[{"path":"../codigo com espacos"},{"path":"../rodadas MTA"}]}',$utf8)
Assert (@(Get-HarnessMcpAllowedRoots @argsRoots).Count -eq 3) 'Raiz MTA tambem aberta no workspace deve ser aceita sem duplicacao.'

[IO.File]::WriteAllText($workspace,'{"folders":[{"path":"../outro projeto"}]}',$utf8)
$actual=@(Get-HarnessMcpAllowedRoots @argsRoots)
Assert ($actual -contains $second -and $actual -notcontains $source) 'Adicionar/remover folder deve valer na proxima consulta.'
Set-MtaRoot $newRuns
$actual=@(Get-HarnessMcpAllowedRoots @argsRoots)
Assert ($actual -contains $newRuns -and $actual -notcontains $runs) 'Mudanca de raiz MTA nao deve manter permissao antiga.'
Set-MtaRoot $null
Assert (@(Get-HarnessMcpAllowedRoots @argsRoots).Count -eq 2) 'runsPath null usa .harness/runs, ja coberto pela raiz do harness.'
$legacy=@(Get-HarnessMcpAllowedRoots -Root $fixture -AllowedRoots @($source))
Assert ($legacy.Count -eq 2 -and $legacy -contains $fixture -and $legacy -contains $source) 'Configuracao fixa legada foi alterada.'

foreach ($bad in @('C:/','\\servidor\pasta','C:/pasta:ads','${env:USERPROFILE}', '../outro projeto', $fixture)) {
    Set-MtaRoot $bad
    Assert (Rejected { Get-HarnessMcpAllowedRoots @argsRoots }) ('Raiz MTA invalida aceita: '+$bad)
}
Set-MtaRoot $runs
[IO.File]::WriteAllText($config,'{"schemaVersion":1,"mta":{"runsPath":[]}}',$utf8)
Assert (Rejected { Get-HarnessMcpAllowedRoots @argsRoots }) 'runsPath com tipo invalido nao pode ser ignorado.'
[IO.File]::WriteAllText($config,'{invalido',$utf8)
Assert (Rejected { Get-HarnessMcpAllowedRoots @argsRoots }) 'Configuracao corrompida nao pode usar permissao antiga.'
Set-MtaRoot $runs
[IO.File]::WriteAllText($workspace,'{invalido',$utf8)
Assert (Rejected { Get-HarnessMcpAllowedRoots @argsRoots }) 'Workspace corrompido nao pode usar permissao antiga.'
[IO.File]::WriteAllText($workspace,'{"folders":[{"path":"C:/"}]}',$utf8)
Assert (Rejected { Get-HarnessMcpAllowedRoots @argsRoots }) 'Folder na raiz de disco nao deve liberar o disco.'
[IO.File]::WriteAllText($workspace,'{"folders":[{"path":"../ausente"}]}',$utf8)
Assert (Rejected { Get-HarnessMcpAllowedRoots @argsRoots }) 'Folder ausente precisa de erro explicito.'
$argsRoots.WorkspacePath=Join-Path $fixture 'ausente.code-workspace'
Assert (Rejected { Get-HarnessMcpAllowedRoots @argsRoots }) 'Workspace indicado ausente nao pode ser ignorado.'
$link=Join-Path $fixture 'pasta-vinculada'
$null=New-Item -ItemType Junction -Path $link -Target $second
try {
    $argsRoots.WorkspacePath=$workspace
    [IO.File]::WriteAllText($workspace,'{"folders":[{"path":"pasta-vinculada"}]}',$utf8)
    Assert (Rejected { Get-HarnessMcpAllowedRoots @argsRoots }) 'Junction no workspace nao pode conceder acesso.'
} finally { [IO.Directory]::Delete($link) }
Write-Host 'PASS: raizes do workspace/MTA, atualizacao, JSONC, legado, limites e leitura sem escrita.'
