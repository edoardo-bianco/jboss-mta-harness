$root=Split-Path -Parent $PSScriptRoot
function Assert($value,[string]$message) { if (-not $value) { throw $message } }
function Reject([scriptblock]$action,[string]$message) {
    $failed=$false
    try { $null=& $action } catch { $failed=$true }
    Assert $failed $message
}
function Write-ConversionFile([string]$Path,[string]$Text) {
    $null=[IO.Directory]::CreateDirectory((Split-Path $Path -Parent))
    [IO.File]::WriteAllText($Path,$Text,(New-Object Text.UTF8Encoding($false)))
}
function New-ConversionFixture {
    $area=Join-Path $root ('.harness/tests/conversao-'+[guid]::NewGuid().ToString('N').Substring(0,8))
    $workspace=Join-Path $area 'workspace com espacos'
    $source=Join-Path $area 'aplicacao'
    $pom=Join-Path $source 'pom.xml'
    Write-ConversionFile $pom '<project xmlns="http://maven.apache.org/POM/4.0.0"><parent><artifactId>pai</artifactId></parent><artifactId>api</artifactId><modules><module>modulo</module></modules></project>'
    Write-ConversionFile (Join-Path $source 'modulo/pom.xml') '<project><artifactId>modulo</artifactId></project>'
    $register=Join-Path $workspace '.harness/projetos/apelido__123456789abc/migracao.md'
    $text="Project: apelido`nSource: $source`n`nNota humana: manter decisao.`n<!-- mta:inicio -->`n| ID | Issue | Categoria | Ocorrencias | Presenca | Decisao | Andamento | Observacao/referencia |`n| --- | --- | --- | --- | --- | --- | --- | --- |`n| java::regra | Migrar API | mandatory | 2 | PRESENTE | ANALISAR AGORA | PLANEJADA | Conferir contrato |`n<!-- mta:fim -->`n"
    Write-ConversionFile $register $text
    [pscustomobject]@{Area=$area;Workspace=$workspace;Source=$source;Pom=$pom;Register=$register}
}
function Add-ConversionPlan($Fixture,[string]$Id,[string]$Previous=$null,[string]$ProjectFolder='apelido') {
    $directory=Join-Path $Fixture.Workspace ('.harness/planning/'+$ProjectFolder+'/rodada/plano_'+$Id)
    $context=Join-Path $directory 'context.json'
    $data=[ordered]@{Purpose='application-remediation';RequestId=$Id;Project='apelido';Source=$Fixture.Source;PlanningBasis='EVIDENCIAS';MigrationPath=$Fixture.Register;SelectedIssues=@('java::regra');ContextPath=$context;PlanPath=(Join-Path $directory 'plan.md');TodoPath=(Join-Path $directory 'todo.md');Previous=$null}
    if ($Previous) { $data.Previous=@{RequestId=$Previous;ContextPath=(Join-Path $Fixture.Workspace ('.harness/planning/'+$ProjectFolder+'/rodada/plano_'+$Previous+'/context.json'))} }
    Write-ConversionFile $context ($data|ConvertTo-Json -Depth 15)
    Write-ConversionFile $data.PlanPath '# Plano humano - GO PENDENTE'
    Write-ConversionFile $data.TodoPath '- [ ] Testar'
    [pscustomobject]$data
}
function Get-ConversionState($Fixture) {
    @(Get-ChildItem -LiteralPath $Fixture.Area -Recurse -Force | Sort-Object FullName | ForEach-Object {
        if ($_.PSIsContainer) { 'D '+$_.FullName }
        else { 'F '+$_.FullName+' '+$_.LastWriteTimeUtc.Ticks+' '+(Get-FileHash -LiteralPath $_.FullName).Hash }
    }) -join "`n"
}
