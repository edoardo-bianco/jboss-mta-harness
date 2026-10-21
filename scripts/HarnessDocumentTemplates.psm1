#requires -Version 5.1
Set-StrictMode -Version Latest
function Get-HarnessDocumentTemplatePath {
    param([ValidatePattern('^[a-z][a-z-]*$')][string]$Name)
    $path=Join-Path (Split-Path $PSScriptRoot -Parent) ('doc/modelos/'+$Name+'.template.md')
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Template ausente: $path" }
    $path
}
function Expand-HarnessDocumentTemplate {
    param([string]$Name,[Collections.IDictionary]$Values=@{})
    $text=[IO.File]::ReadAllText((Get-HarnessDocumentTemplatePath $Name))
    [regex]::Replace($text,'\{\{([A-Za-z]+)\}\}',[Text.RegularExpressions.MatchEvaluator]{
        param($match)
        $key=$match.Groups[1].Value
        if (-not $Values.Contains($key)) { throw "Campo $key ausente para o template $Name." }
        [string]$Values[$key]
    })
}
Export-ModuleMember -Function Get-HarnessDocumentTemplatePath,Expand-HarnessDocumentTemplate
