#requires -Version 5.1
$ErrorActionPreference='Stop'
[Console]::OutputEncoding=[Text.UTF8Encoding]::new($false)
. (Join-Path $PSScriptRoot '../../../tests/Test-IssueQueryPlanning.ps1') 6>$null 3>$null
$outside=$planningJson | ConvertFrom-Json
$outside.FichaPath=$area+'-externo/ficha.md'
try {
    Write-HarnessJson $plan.ContextPath $outside
    $blocked=Invoke-HarnessIssueQuery -Root $fixture -ContextPath $plan.ContextPath -Action auditar_base -AllowedRoots @($area)
    Assert ($blocked.Error.Code -eq 'ACCESS_DENIED') 'Ponteiro consolidado externo nao recusado.'
} finally { [IO.File]::WriteAllText($plan.ContextPath,$planningJson) }
# Caminho Unicode real passa pelo JSON stdin; script ASCII tambem funciona no PS5.1.
$unicode=$planningJson | ConvertFrom-Json
$unicode.ContextPath=Join-Path (Split-Path $plan.ContextPath -Parent) ('consulta '+[char]0x00e7+[char]0x00e3+'o.json')
Write-HarnessJson $unicode.ContextPath $unicode
$plan.ContextPath=$unicode.ContextPath
$unicodeTitle='A'+[char]0x00e7+[char]0x00e3+'o corporativa'
$updatedRegister=[IO.File]::ReadAllText($paths.MigrationPath).Replace('| DEV-LOG | Log manual |',('| DEV-LOG | '+$unicodeTitle+' |'))
[IO.File]::WriteAllText($paths.MigrationPath,$updatedRegister)
$settings=Join-Path $area 'mcp-config.json'
Write-HarnessJson $settings @{root=$fixture;allowedRoots=@($area);timeoutMs=60000}
$baseline=Invoke-HarnessIssueQuery -Root $fixture -ContextPath $plan.ContextPath -Action obter_issue -Id $issueId -Incident 138
[Console]::Out.WriteLine((@{area=$area;root=$fixture;source=$source;context=$prepared.ContextPath;plan=$plan.ContextPath;id=$issueId;unicodeTitle=$unicodeTitle;settings=$settings;manualRoot=$manualRoot;manualPlan=$manualPlan.ContextPath;importRoot=$destination;importPlan=$received.ContextPath;baseline=$baseline} | ConvertTo-Json -Depth 50 -Compress))
