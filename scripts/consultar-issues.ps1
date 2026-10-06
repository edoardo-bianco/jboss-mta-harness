#requires -Version 5.1
# Entrada sem binder: erros de argumentos tambem devem produzir o envelope JSON.
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$parameters=@{}
$failureCode='INVALID_INPUT'
try {
    $names=@('Action','ContextPath','Source','Root','Page','PageSize','MaxTextChars',
        'Category','Decision','Progress','Text','Label','Id','Incident','ExpectedBasisSha256')
    for ($position=0; $position -lt $args.Count; $position+=2) {
        $token=[string]$args[$position]
        if ($token -notmatch '^-[A-Za-z]+$' -or $token.Substring(1) -notin $names) { throw "Parametro desconhecido: $token" }
        $name=$token.Substring(1)
        if ($parameters.ContainsKey($name)) { throw "Parametro repetido: $name" }
        if ($position+1 -ge $args.Count) { throw "Informe valor para $name." }
        $parameters[$name]=$args[$position+1]
    }
    $failureCode='RUNTIME_ERROR'
    Import-Module (Join-Path $PSScriptRoot 'HarnessIssueQuery.psm1') -DisableNameChecking
    $result=Invoke-HarnessIssueQuery @parameters
} catch {
    $message=$_.Exception.Message; $originalLength=$message.Length
    if ($originalLength -gt 1024) { $message=$message.Substring(0,1024) }
    $action=if ($parameters['Action'] -in @('auditar_base','listar_issues','obter_issue')) {$parameters['Action']} else {$null}
    $result=[pscustomobject][ordered]@{SchemaVersion=1;Action=$action;Status='ERROR';ReadOnly=$true;
        Provenance=$null;Data=$null;Paging=$null;Diagnostics=@();Error=[ordered]@{Code=$failureCode;Message=$message;MessageTruncated=($originalLength -gt 1024);MessageOriginalLength=$originalLength}}
}
$result | ConvertTo-Json -Depth 50 -Compress
if ($result.Status -eq 'OK') { exit 0 }
exit 1
