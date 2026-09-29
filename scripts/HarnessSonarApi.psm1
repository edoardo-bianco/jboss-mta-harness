#requires -Version 5.1
# Adaptado de jboss-eap-copilot-harness-template/scripts/SonarApi.psm1.
# Origem, limites e APIs: doc/guias/sonar.md.
Set-StrictMode -Version Latest
Add-Type -AssemblyName System.Net.Http

function Get-SonarServerBase {
    param([string]$ServerUrl)
    $uri = $null
    if (-not [Uri]::TryCreate($ServerUrl, [UriKind]::Absolute, [ref]$uri) -or $uri.UserInfo -or $uri.Query -or $uri.Fragment -or
        ($uri.Scheme -ne 'https' -and -not ($uri.Scheme -eq 'http' -and $uri.IsLoopback)) -or
        $uri.AbsolutePath -notmatch '^/[A-Za-z0-9._~/-]*$') { throw 'SONAR_API_UNVERIFIED: request failed; details suppressed.' }
    return $uri.AbsoluteUri.TrimEnd('/')
}

function Invoke-SonarApiGet {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$ServerUrl,
        [Parameter(Mandatory = $true)][ValidateSet('api/system/status', 'api/components/show', 'api/project_analyses/search', 'api/ce/component', 'api/ce/task', 'api/issues/search', 'api/measures/component', 'api/qualitygates/project_status')][string]$Endpoint,
        [hashtable]$Query = @{},
        [ValidateRange(1, 120)][int]$TimeoutSeconds = 15,
        [Threading.CancellationToken]$CancellationToken = [Threading.CancellationToken]::None
    )
    $client = $null
    $handler = $null
    $response = $null
    $token = $null
    try {
        $base = Get-SonarServerBase $ServerUrl
        $token = [Environment]::GetEnvironmentVariable('SONAR_TOKEN', 'Process')
        if ([string]::IsNullOrWhiteSpace($token) -or $token -match '[\s\x00-\x1f\x7f]') { throw 'Missing or invalid token.' }
        $CancellationToken.ThrowIfCancellationRequested()
        $allowed = switch ($Endpoint) {
            'api/system/status' { @() }
            'api/components/show' { @('component', 'branch') }
            'api/project_analyses/search' { @('project', 'branch', 'p', 'ps') }
            'api/ce/component' { @('component', 'branch') }
            'api/ce/task' { @('id') }
            'api/issues/search' { @('componentKeys', 'resolved', 'p', 'ps', 'branch') }
            'api/measures/component' { @('component', 'metricKeys', 'branch') }
            'api/qualitygates/project_status' { @('analysisId') }
        }
        $pairs = @()
        foreach ($key in @($Query.Keys | Sort-Object)) {
            $value = $Query[$key]
            if ($key -cnotin @($allowed) -or $value -isnot [string] -or
                [string]::IsNullOrWhiteSpace($value) -or $value.Length -gt 400 -or $value -match '[\x00-\x1f\x7f]' -or $value.Contains($token)) { throw 'Invalid query.' }
            $pairs += [Uri]::EscapeDataString($key) + '=' + [Uri]::EscapeDataString($value)
        }
        $address = $base + '/' + $Endpoint
        if ($pairs.Count -gt 0) { $address += '?' + ($pairs -join '&') }
        if ($address.Contains($token)) { throw 'Credential in URL.' }
        # Disable redirects; preserve default TLS certificate validation.
        # https://learn.microsoft.com/en-us/dotnet/api/system.net.http.httpclienthandler.allowautoredirect
        $handler = New-Object Net.Http.HttpClientHandler
        $handler.AllowAutoRedirect = $false
        $handler.UseCookies = $false
        if (([Uri]$base).IsLoopback) { $handler.UseProxy = $false }
        $client = New-Object Net.Http.HttpClient($handler)
        $client.Timeout = [TimeSpan]::FromSeconds($TimeoutSeconds)
        $client.MaxResponseContentBufferSize = 1MB
        $client.DefaultRequestHeaders.Authorization = New-Object Net.Http.Headers.AuthenticationHeaderValue('Bearer', $token)
        $response = $client.GetAsync($address, $CancellationToken).GetAwaiter().GetResult()
        if ([int]$response.StatusCode -ne 200) { throw 'HTTP failure.' }
        $bytes = $response.Content.ReadAsByteArrayAsync().GetAwaiter().GetResult()
        if ($bytes.Length -gt 1MB) { throw 'Response too large.' }
        $utf8 = New-Object Text.UTF8Encoding($false, $true)
        $json = $utf8.GetString($bytes).TrimStart([char]0xfeff)
        if (-not $json.TrimStart().StartsWith('{')) { throw 'JSON object required.' }
        $result = ConvertFrom-Json -InputObject $json -ErrorAction Stop
        if ($result -isnot [pscustomobject]) { throw 'JSON object required.' }
        return $result
    } catch {
        throw 'SONAR_API_UNVERIFIED: request failed; details suppressed.'
    } finally {
        $token = $null
        if ($null -ne $response) { $response.Dispose() }
        if ($null -ne $client) { $client.DefaultRequestHeaders.Clear(); $client.Dispose() }
        elseif ($null -ne $handler) { $handler.Dispose() }
    }
}

function Get-SonarApiField {
    param($Object, [string]$Name)
    if ($Object -isnot [pscustomobject]) { throw 'Invalid API object.' }
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) { return $null }
    return ,$property.Value
}

function Read-SonarTaskReport {
    [CmdletBinding()]
    param([string]$Path, [string]$ServerUrl, [string]$ProjectKey)
    try {
        $base = Get-SonarServerBase $ServerUrl
        $file = Get-Item -LiteralPath $Path -ErrorAction Stop
        if ($file.PSIsContainer -or $file.Length -gt 64KB -or ($file.Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw 'Invalid metadata file.' }
        $utf8 = New-Object Text.UTF8Encoding($false, $true)
        $text = $utf8.GetString([IO.File]::ReadAllBytes($file.FullName)).TrimStart([char]0xfeff)
        $values = @{}
        foreach ($line in ($text -split '\r?\n')) {
            if ([string]::IsNullOrWhiteSpace($line) -or $line.StartsWith('#')) { continue }
            $parts = $line -split '=', 2
            if ($parts.Count -ne 2 -or $parts[0] -cnotin @('projectKey', 'serverUrl', 'serverVersion', 'dashboardUrl', 'ceTaskId', 'ceTaskUrl') -or $values.ContainsKey($parts[0])) { throw 'Invalid metadata fields.' }
            $values[$parts[0]] = $parts[1]
        }
        foreach ($name in @('projectKey', 'serverUrl', 'ceTaskId', 'ceTaskUrl')) {
            if (-not $values.ContainsKey($name) -or [string]::IsNullOrWhiteSpace($values[$name])) { throw 'Missing metadata.' }
        }
        if ($values.projectKey -cne $ProjectKey -or (Get-SonarServerBase $values.serverUrl) -cne $base -or $values.ceTaskId -cnotmatch '^[A-Za-z0-9_-]{1,200}$' -or
            $values.ceTaskUrl -cne ($base + '/api/ce/task?id=' + [Uri]::EscapeDataString($values.ceTaskId))) { throw 'Unbound metadata.' }
        return [pscustomobject]@{ TaskId = $values.ceTaskId }
    } catch { throw 'SONAR_METADATA_UNVERIFIED: invalid or unbound report; details suppressed.' }
}

function Wait-SonarComputeEngine {
    [CmdletBinding()]
    param(
        [string]$ServerUrl, [string]$TaskId, [string]$ProjectKey,
        [AllowNull()][string]$BranchName,
        [ValidateRange(1, 3600)][int]$TimeoutSeconds = 300,
        [ValidateRange(1, 5000)][int]$PollMilliseconds = 1000,
        [Threading.CancellationToken]$CancellationToken = [Threading.CancellationToken]::None
    )
    $deadline = $null
    try {
        if ($TaskId -cnotmatch '^[A-Za-z0-9_-]{1,200}$') { throw 'Invalid task id.' }
        $deadline = [Threading.CancellationTokenSource]::CreateLinkedTokenSource($CancellationToken, [Threading.CancellationToken]::None)
        $deadline.CancelAfter($TimeoutSeconds * 1000)
        while ($true) {
            $deadline.Token.ThrowIfCancellationRequested()
            $reply = Invoke-SonarApiGet -ServerUrl $ServerUrl -Endpoint 'api/ce/task' -Query @{ id = $TaskId } -CancellationToken $deadline.Token
            $task = Get-SonarApiField $reply 'task'
            foreach ($field in @('id', 'type', 'componentKey', 'status')) {
                if ((Get-SonarApiField $task $field) -isnot [string]) { throw 'Missing CE field.' }
            }
            if ($task.id -cne $TaskId -or $task.type -cne 'REPORT' -or $task.componentKey -cne $ProjectKey) { throw 'Different CE identity.' }
            if ($BranchName -and ((Get-SonarApiField $task 'branch') -isnot [string] -or $task.branch -cne $BranchName)) { throw 'Different CE branch.' }
            if ($task.status -ceq 'SUCCESS') {
                $analysisId = Get-SonarApiField $task 'analysisId'
                if ($analysisId -isnot [string] -or $analysisId -cnotmatch '^[A-Za-z0-9_-]{1,200}$') { throw 'Missing analysis id.' }
                return [pscustomobject]@{ TaskId = $TaskId; AnalysisId = $analysisId }
            }
            if ($task.status -cnotin @('PENDING', 'IN_PROGRESS')) { throw 'CE failed or status unknown.' }
            $null = $deadline.Token.WaitHandle.WaitOne($PollMilliseconds)
        }
    } catch { throw 'SONAR_CE_UNVERIFIED: task failed, timed out, cancelled or unbound; details suppressed.' }
    finally { if ($null -ne $deadline) { $deadline.Dispose() } }
}

Export-ModuleMember -Function Get-SonarServerBase, Invoke-SonarApiGet, Read-SonarTaskReport, Wait-SonarComputeEngine
