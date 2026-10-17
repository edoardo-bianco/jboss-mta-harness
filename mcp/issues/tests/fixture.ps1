#requires -Version 5.1
$ErrorActionPreference='Stop'
[Console]::OutputEncoding=[Text.UTF8Encoding]::new($false)
. (Join-Path $PSScriptRoot '../../../tests/Test-IssueQueryPlanning.ps1') 6>$null 3>$null
# Entrada Unicode e dados literais passam por JSON stdin sem interpretar comandos.
$unicodeTitle='A'+[char]0x00e7+[char]0x00e3+'o corporativa'
$updatedRegister=[IO.File]::ReadAllText($paths.MigrationPath).Replace('| DEV-LOG | Log manual |',('| DEV-LOG | '+$unicodeTitle+' |'))
[IO.File]::WriteAllText($paths.MigrationPath,$updatedRegister)
$settings=Join-Path $area 'mcp-config.json'
Write-HarnessJson $settings @{root=$fixture;allowedRoots=@($area);timeoutMs=60000}
$baseline=Invoke-HarnessIssueQuery -Root $fixture -ContextPath $plan.ContextPath -Action obter_issue -Id $issueId -Incident 138
[Console]::Out.WriteLine((@{area=$area;root=$fixture;source=$source;run=$run;projectConfig=$paths.ConfigPath;context=$prepared.ContextPath;plan=$plan.ContextPath;id=$issueId;unicodeTitle=$unicodeTitle;settings=$settings;manualRoot=$manualRoot;manualPlan=$manualPlan.ContextPath;baseline=$baseline} | ConvertTo-Json -Depth 50 -Compress))
