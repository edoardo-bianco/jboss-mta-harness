#requires -Version 5.1
[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$script:checks = 0
$script:lastCheck = 'setup'
$exitCode = 0
$listener = $null
$testRoot = $null
$worker = $null
$previousToken = [Environment]::GetEnvironmentVariable('SONAR_TOKEN', 'Process')
function Assert-Test([bool]$Condition, [string]$Message) {
    $script:lastCheck = $Message
    if (-not $Condition) { throw 'Assertion failed.' }; $script:checks++
}
function Queue-Response([string]$Body, [int]$Status = 200, [string]$Extra = '') {
    $state.Responses.Enqueue([pscustomobject]@{ Body = $Body; Status = $Status; Extra = $Extra })
}
try {
    Assert-Test ($PSVersionTable.PSVersion.Major -eq 5 -and $PSVersionTable.PSVersion.Minor -eq 1) 'PS5.1 required'
    $repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
    Import-Module (Join-Path $repo 'scripts/HarnessSonarApi.psm1') -Force
    $synthetic = 'synthetic-' + [Guid]::NewGuid().ToString('N')
    [Environment]::SetEnvironmentVariable('SONAR_TOKEN', $synthetic, 'Process')
    $state = [hashtable]::Synchronized(@{
        Stop = $false
        AuthValid = $true
        Requests = (New-Object 'Collections.Concurrent.ConcurrentQueue[string]')
        Responses = (New-Object 'Collections.Concurrent.ConcurrentQueue[object]')
        Token = $synthetic
        ExpectedAuthorization = 'Bearer ' + $synthetic
    })
    $listener = New-Object Net.Sockets.TcpListener([Net.IPAddress]::Loopback, 0)
    $listener.Start()
    $url = 'http://127.0.0.1:' + $listener.LocalEndpoint.Port + '/sonar'
    $worker = [PowerShell]::Create()
    $null = $worker.AddScript(@'
param($listener, $state)
while (-not $state.Stop) {
    if (-not $listener.Pending()) { Start-Sleep -Milliseconds 10; continue }
    $connection = $listener.AcceptTcpClient()
    try {
        $connection.ReceiveTimeout = 2000
        $stream = $connection.GetStream()
        $reader = New-Object IO.StreamReader($stream, [Text.Encoding]::ASCII)
        $firstLine = $reader.ReadLine()
        $state.Requests.Enqueue($firstLine)
        $authorization = $null
        while ($true) {
            $line = $reader.ReadLine()
            if ([string]::IsNullOrEmpty($line)) { break }
            if ($line.StartsWith('Authorization:')) { $authorization = $line.Substring(14).Trim() }
        }
        $authorized = $authorization -ceq $state.ExpectedAuthorization
        if (-not $authorized) { $state.AuthValid = $false }
        $reply = $null
        if (-not $state.Responses.TryDequeue([ref]$reply)) { $reply = [pscustomobject]@{ Body = '{}'; Status = 500; Extra = '' } }
        if (-not $authorized) { $reply = [pscustomobject]@{ Body = '{}'; Status = 401; Extra = '' } }
        if ($reply.Extra -eq 'delay') { Start-Sleep -Milliseconds 1500 }
        $body = [Text.Encoding]::UTF8.GetBytes($reply.Body)
        $crlf = [string][char]13 + [char]10
        $extra = $reply.Extra
        if ($extra -eq 'delay') { $extra = '' }
        $head = 'HTTP/1.1 ' + $reply.Status + ' Fixture' + $crlf + 'Content-Type: application/json' + $crlf + 'Connection: close' + $crlf + 'Content-Length: ' + $body.Length + $crlf
        if ($extra) { $head += $extra + $crlf }
        $head += $crlf
        $headerBytes = [Text.Encoding]::ASCII.GetBytes($head)
        $stream.Write($headerBytes, 0, $headerBytes.Length)
        $stream.Write($body, 0, $body.Length)
        $stream.Flush()
    } catch { } finally { $connection.Dispose() }
}
'@).AddArgument($listener).AddArgument($state)
    $pending = $worker.BeginInvoke()
    Queue-Response '{"status":"UP","version":"fixture"}'
    $response = Invoke-SonarApiGet -ServerUrl $url -Endpoint 'api/system/status'
    Assert-Test ($response.status -ceq 'UP') 'real HTTP JSON transport'
    Assert-Test $state.AuthValid 'Bearer header only'
    Queue-Response '{"component":{"key":"fixture:key"}}'
    $response = Invoke-SonarApiGet -ServerUrl $url -Endpoint 'api/components/show' -Query @{ component = 'fixture:key'; branch = 'feature/a b' }
    $requests = $state.Requests.ToArray()
    Assert-Test ($requests[1].Contains('branch=feature%2Fa%20b') -and $requests[1].Contains('component=fixture%3Akey')) 'query escaping'
    Assert-Test (-not ($requests -join ' ').Contains($synthetic)) 'no token in URL'
    $basic = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($synthetic + ':'))
    $state.ExpectedAuthorization = 'Basic ' + $basic
    Queue-Response '{"status":"UP","version":"9.9.5"}'
    $response = Invoke-SonarApiGet -ServerUrl $url -Endpoint 'api/system/status' -AuthScheme Basic
    Assert-Test ($response.version -ceq '9.9.5' -and $state.AuthValid) 'Basic token username with empty password'
    foreach ($ceStatus in @('PENDING', 'IN_PROGRESS', 'SUCCESS')) {
        Queue-Response ('{"task":{"id":"CE1","type":"REPORT","componentKey":"fixture:key","status":"' + $ceStatus + '","analysisId":"A1","branch":"develop"}}')
    }
    $task = Wait-SonarComputeEngine -ServerUrl $url -TaskId 'CE1' -ProjectKey 'fixture:key' -BranchName develop -PollMilliseconds 1 -TimeoutSeconds 2 -AuthScheme Basic
    Assert-Test ($task.AnalysisId -ceq 'A1' -and $state.AuthValid) 'Basic used in every CE poll'
    foreach ($status in @(302, 401)) {
        Queue-Response ('{"message":"' + $basic + '"}') $status ('Location: ' + $url + '/stolen')
        $before = $state.Requests.Count
        $rejected = $false
        try { $null = Invoke-SonarApiGet -ServerUrl $url -Endpoint 'api/system/status' -AuthScheme Basic }
        catch { $rejected = $_.Exception.Message -ceq 'SONAR_API_UNVERIFIED: request failed; details suppressed.' }
        Assert-Test ($rejected -and $state.Requests.Count -eq $before + 1) 'Basic failure sanitized without redirect or auth fallback'
    }
    Assert-Test (-not ($state.Requests.ToArray() -join ' ').Contains($basic)) 'no Basic credential in URL'
    $state.ExpectedAuthorization = 'Bearer ' + $synthetic
    Queue-Response '{"status":"UP"}'
    $response = Invoke-SonarApiGet -ServerUrl $url -Endpoint 'api/system/status' -AuthScheme Bearer
    Assert-Test ($response.status -ceq 'UP' -and $state.AuthValid) 'explicit Bearer remains supported after Basic'
    $before = $state.Requests.Count
    $rejected = $false
    try { $null = Invoke-SonarApiGet -ServerUrl $url -Endpoint 'api/system/status' -AuthScheme Digest }
    catch { $rejected = $true }
    Assert-Test ($rejected -and $state.Requests.Count -eq $before) 'invalid auth scheme sends nothing'
    $before = $state.Requests.Count
    $rejected = $false
    try { $null = Invoke-SonarApiGet -ServerUrl $url -Endpoint 'api/system/status' -Query @{ component = 'fixture' } }
    catch { $rejected = $true }
    Assert-Test ($rejected -and $state.Requests.Count -eq $before) 'cross-endpoint query rejected before network'
    foreach ($entry in @(
        @{ Endpoint = 'api/issues/search'; Query = @{ componentKeys = 'fixture'; resolved = 'false'; p = '1'; ps = '100' } },
        @{ Endpoint = 'api/measures/component'; Query = @{ component = 'fixture'; metricKeys = 'coverage,duplicated_lines_density' } },
        @{ Endpoint = 'api/qualitygates/project_status'; Query = @{ analysisId = 'A1' } }
    )) {
        Queue-Response '{}'
        $null = Invoke-SonarApiGet -ServerUrl $url @entry
        Assert-Test $state.AuthValid 'quality endpoints authenticated'
    }
    foreach ($status in @(301, 302, 307, 401, 403, 404, 500)) {
        Queue-Response ('{"message":"' + $synthetic + '"}') $status ('Location: ' + $url + '/stolen')
        $before = $state.Requests.Count
        $rejected = $false
        try { $null = Invoke-SonarApiGet -ServerUrl $url -Endpoint 'api/system/status' }
        catch { $rejected = $_.Exception.Message -ceq 'SONAR_API_UNVERIFIED: request failed; details suppressed.' }
        Assert-Test $rejected 'HTTP failure sanitized'
        Assert-Test ($state.Requests.Count -eq $before + 1) 'no redirect followed'
    }
    foreach ($invalidBody in @('<html>login</html>', '[]', '{broken', ('{"padding":"' + ('x' * 1100000) + '"}'))) {
        Queue-Response $invalidBody
        $rejected = $false
        try { $null = Invoke-SonarApiGet -ServerUrl $url -Endpoint 'api/system/status' }
        catch { $rejected = $_.Exception.Message.StartsWith('SONAR_API_UNVERIFIED:') }
        Assert-Test $rejected 'malformed/oversized response rejected'
    }
    foreach ($unsafeUrl in @('http://remote.invalid', 'https://user:pass@remote.invalid', ($url + '?q=1'), ($url + '#fragment'))) {
        $rejected = $false
        try { $null = Invoke-SonarApiGet -ServerUrl $unsafeUrl -Endpoint 'api/system/status' }
        catch { $rejected = $_.Exception.Message.StartsWith('SONAR_API_UNVERIFIED:') }
        Assert-Test $rejected 'unsafe URL rejected before network'
    }
    $before = $state.Requests.Count
    [Environment]::SetEnvironmentVariable('SONAR_TOKEN', $null, 'Process')
    $rejected = $false
    try { $null = Invoke-SonarApiGet -ServerUrl $url -Endpoint 'api/system/status' }
    catch { $rejected = $_.Exception.Message.StartsWith('SONAR_API_UNVERIFIED:') }
    Assert-Test ($rejected -and $state.Requests.Count -eq $before) 'missing token fails before network'
    [Environment]::SetEnvironmentVariable('SONAR_TOKEN', $synthetic, 'Process')
    $cancellation = New-Object Threading.CancellationTokenSource
    try {
        $cancellation.Cancel()
        $rejected = $false
        try { $null = Invoke-SonarApiGet -ServerUrl $url -Endpoint 'api/system/status' -CancellationToken $cancellation.Token }
        catch { $rejected = $true }
        Assert-Test ($rejected -and $state.Requests.Count -eq $before) 'pre-cancelled request sends nothing'
    } finally { $cancellation.Dispose() }
    $tempParent = Join-Path $repo '.harness/tests'
    $null = [IO.Directory]::CreateDirectory($tempParent)
    $testName = 'sonar-api-' + [Guid]::NewGuid().ToString('N')
    $testRoot = Join-Path $tempParent $testName
    $null = New-Item -ItemType Directory -Path $testRoot
    $reportPath = Join-Path $testRoot 'report-task.txt'
    $report = 'projectKey=fixture:key' + [char]10 + 'serverUrl=' + $url + [char]10 + 'ceTaskId=CE1' + [char]10 + 'ceTaskUrl=' + $url + '/api/ce/task?id=CE1'
    [IO.File]::WriteAllText($reportPath, $report)
    $task = Read-SonarTaskReport -Path $reportPath -ServerUrl $url -ProjectKey 'fixture:key'
    Assert-Test ($task.TaskId -ceq 'CE1' -and @($task.PSObject.Properties).Count -eq 1) 'metadata returns only trusted task identifier'
    foreach ($badReport in @(
        $report.Replace('id=CE1', 'id=CE1&extra=1'),
        $report.Replace('ceTaskUrl=' + $url, 'ceTaskUrl=https://other.invalid'),
        $report.Replace('serverUrl=' + $url, 'serverUrl=https://other.invalid'),
        $report.Replace('projectKey=fixture:key', 'projectKey=other:key'),
        ($report + [char]10 + 'ceTaskId=OTHER'),
        $report.Replace('ceTaskId=CE1', 'ceTaskId='),
        ('ceTaskId=STALE')
    )) {
        [IO.File]::WriteAllText($reportPath, $badReport)
        $rejected = $false
        try { $null = Read-SonarTaskReport -Path $reportPath -ServerUrl $url -ProjectKey 'fixture:key' }
        catch { $rejected = $_.Exception.Message.StartsWith('SONAR_METADATA_UNVERIFIED:') }
        Assert-Test $rejected 'unbound/duplicate/unsafe metadata rejected'
    }
    foreach ($status in @('PENDING', 'IN_PROGRESS', 'SUCCESS')) {
        Queue-Response ('{"task":{"id":"CE1","type":"REPORT","componentKey":"fixture:key","status":"' + $status + '","analysisId":"A1","branch":"feature/a"}}')
    }
    $completed = Wait-SonarComputeEngine -ServerUrl $url -TaskId 'CE1' -ProjectKey 'fixture:key' -BranchName 'feature/a' -TimeoutSeconds 2 -PollMilliseconds 1
    Assert-Test ($completed.AnalysisId -ceq 'A1' -and $completed.TaskId -ceq 'CE1') 'CE pending/running/success correlation'
    foreach ($taskJson in @(
        '{"id":"CE1","type":"REPORT","componentKey":"fixture:key","status":"FAILED"}',
        '{"id":"CE1","type":"REPORT","componentKey":"fixture:key","status":"CANCELED"}',
        '{"id":"CE1","type":"REPORT","componentKey":"fixture:key","status":"FUTURE"}',
        '{"id":"CE1","type":"REPORT","componentKey":"fixture:key","status":["SUCCESS"],"analysisId":"A1"}',
        '{"id":"OTHER","type":"REPORT","componentKey":"fixture:key","status":"SUCCESS","analysisId":"A1"}',
        '{"id":"CE1","type":"OTHER","componentKey":"fixture:key","status":"SUCCESS","analysisId":"A1"}',
        '{"id":"CE1","type":"REPORT","componentKey":"other:key","status":"SUCCESS","analysisId":"A1"}',
        '{"id":"CE1","type":"REPORT","componentKey":"fixture:key","status":"SUCCESS"}',
        '{"id":"CE1","type":"REPORT","componentKey":"fixture:key","status":"SUCCESS","analysisId":"A1","branch":"other"}'
    )) {
        Queue-Response ('{"task":' + $taskJson + '}')
        $rejected = $false
        try { $null = Wait-SonarComputeEngine -ServerUrl $url -TaskId 'CE1' -ProjectKey 'fixture:key' -BranchName 'feature/a' -TimeoutSeconds 2 -PollMilliseconds 1 }
        catch { $rejected = $_.Exception.Message.StartsWith('SONAR_CE_UNVERIFIED:') }
        Assert-Test $rejected 'invalid CE identity/status/analysis/branch rejected'
    }
    Queue-Response '{}' 200 'delay'
    $rejected = $false
    $timer = [Diagnostics.Stopwatch]::StartNew()
    try { $null = Invoke-SonarApiGet -ServerUrl $url -Endpoint 'api/system/status' -TimeoutSeconds 1 }
    catch { $rejected = $_.Exception.Message.StartsWith('SONAR_API_UNVERIFIED:') }
    Assert-Test ($rejected -and $timer.Elapsed.TotalSeconds -lt 4) 'bounded request timeout'
    Write-Output ('PASS sonar-api: ' + $script:checks + ' verificacoes; PS ' + $PSVersionTable.PSVersion)
} catch {
    Write-Output ('FAIL sonar-api: line=' + $_.InvocationInfo.ScriptLineNumber + '; checks=' + $script:checks + '; last=' + $script:lastCheck + '; type=' + $_.Exception.GetType().Name)
    $exitCode = 1
} finally {
    if ($null -ne $worker) {
        $state.Stop = $true
        $null = $pending.AsyncWaitHandle.WaitOne(3000)
        $worker.Stop()
        $worker.Dispose()
    }
    if ($null -ne $testRoot -and (Test-Path -LiteralPath $testRoot)) {
        $target = Get-Item -LiteralPath $testRoot
        if ($target.Parent.FullName -ne $tempParent -or $target.Name -ne $testName -or ($target.Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw 'Cleanup refused.' }
        Remove-Item -LiteralPath $target.FullName -Recurse -Force
    }
    if ($null -ne $listener) { $listener.Stop() }
    [Environment]::SetEnvironmentVariable('SONAR_TOKEN', $previousToken, 'Process')
}
exit $exitCode
