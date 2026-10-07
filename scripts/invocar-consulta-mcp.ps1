#requires -Version 5.1
# Bridge interno: parametros sao dados JSON, nunca texto de comando.
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
[Console]::InputEncoding=[Text.UTF8Encoding]::new($false)
[Console]::OutputEncoding=[Text.UTF8Encoding]::new($false)
$failureCode='RUNTIME_ERROR'
try {
    $json=[Console]::In.ReadToEnd()
    if ($json.Length -gt 128KB) { throw 'Entrada MCP excede 128 KiB.' }
    $request=$json | ConvertFrom-Json
    $parameters=@{}
    foreach ($property in $request.Arguments.PSObject.Properties) { $parameters[$property.Name]=$property.Value }
    $failureCode='CONFIG_ERROR'
    Import-Module (Join-Path $PSScriptRoot 'HarnessMcpSettings.psm1') -DisableNameChecking
    $rootParameters=@{Root=$request.Root;AllowedRoots=$request.AllowedRoots;PathBase=(Split-Path -Parent $PSScriptRoot)}
    foreach ($name in @('WorkspacePath','HarnessConfigPath')) {
        if ($request.PSObject.Properties[$name]) { $rootParameters[$name]=$request.$name }
    }
    $allowedRoots=@(Get-HarnessMcpAllowedRoots @rootParameters)
    $failureCode='RUNTIME_ERROR'
    Import-Module (Join-Path $PSScriptRoot 'HarnessIssueQuery.psm1') -DisableNameChecking
    $result=Invoke-HarnessIssueQuery -Action $request.Action -Root $request.Root -AllowedRoots $allowedRoots @parameters
} catch {
    $result=[ordered]@{SchemaVersion=1;Action=$null;Status='ERROR';ReadOnly=$true;Provenance=$null;Data=$null;Paging=$null;Diagnostics=@();Error=@{Code=$failureCode;Message=$_.Exception.Message.Substring(0,[Math]::Min(1024,$_.Exception.Message.Length))}}
}
[Console]::Out.WriteLine((ConvertTo-Json -InputObject $result -Depth 50 -Compress))
if ($result.Status -ne 'OK') { exit 1 }
