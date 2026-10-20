#requires -Version 5.1
$ErrorActionPreference='Stop'; Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'ConversionFixture.ps1')
Import-Module (Join-Path $root 'scripts/HarnessProject.psm1') -DisableNameChecking
Import-Module (Join-Path $root 'tools/transicao/ConversaoPrevia.psm1') -DisableNameChecking
Import-Module (Join-Path $root 'tools/transicao/ConversaoPublicacao.psm1') -DisableNameChecking
Import-Module (Join-Path $root 'tools/transicao/ConversaoValidacao.psm1') -DisableNameChecking
Import-Module (Join-Path $root 'tools/transicao/ConversaoLimpeza.psm1') -DisableNameChecking

function New-PreparedConversionFixture([string]$Basis='EVIDENCIAS') {
    $fixture=New-ConversionFixture
    $folder=Join-Path $fixture.Workspace ('.harness/planning/apelido/rodada/plano_'+('a'*32))
    $context=Join-Path $folder 'context.json'
    $ficha=Join-Path $folder 'ficha.md'; $index=Join-Path $folder 'anexos/LEIA-ME.md'
    $binary=Join-Path $folder 'anexos/evidencia.bin'; $prompt=Join-Path $folder 'planejar-lotes.prompt.md'
    Write-ConversionFile $index "# Evidencias humanas`n[Anexo conferido](<evidencia.bin>)"
    [IO.File]::WriteAllBytes($binary,[byte[]](0,255,13,10,222))
    Write-ConversionFile $ficha "# Ficha humana`nRisco: preservar transacao.`n[Anexo](<anexos/evidencia.bin>)"
    Write-ConversionFile $prompt '# Preparo de planejamento; proposta ainda nao escrita.'
    $data=[pscustomobject][ordered]@{
        Purpose='application-remediation';RequestId=('a'*32);Project='apelido';Source=$fixture.Source
        PlanningBasis=$Basis;MigrationPath=$fixture.Register;SelectedIssues=@('java::regra')
        ContextPath=$context;PromptPath=$prompt;PlanPath=(Join-Path $folder 'plan.md');TodoPath=(Join-Path $folder 'todo.md')
        Previous=$null;FichaPath=$ficha;EvidenceIndexPath=$index
        EvidenceInputs=@(@{Path=$binary;Relation='Contrato humano';Status='DISPONIVEL'})
    }
    if ($Basis -eq 'MTA') {
        $origin=Join-Path $fixture.Area 'mta externo'
        Write-ConversionFile (Join-Path $origin 'index.html') '<html>Relatorio sintetico</html>'
        $apps=@(@{artifactId='api';rulesets=@(@{name='java';violations=@{regra=@{description='Problema';category='mandatory';incidents=@()}}})})
        Write-ConversionFile (Join-Path $origin 'output.js') ('window["apps"] = '+(ConvertTo-Json -InputObject $apps -Depth 12 -Compress)+';')
        $data|Add-Member Run $origin
    }
    Write-ConversionFile $context ($data|ConvertTo-Json -Depth 15)
    $fixture|Add-Member Plan $data
    $fixture|Add-Member Arguments @{Workspace=$fixture.Workspace;Pom=$fixture.Pom;Contexto=$context}
    $fixture
}
function Get-PreparedOriginalState([string[]]$Paths) {
    @($Paths | Sort-Object | ForEach-Object { $_+' '+[IO.File]::GetLastWriteTimeUtc($_).Ticks+' '+(Get-FileHash -LiteralPath $_).Hash }) -join "`n"
}
function Assert-PreparedValidation($Fixture,[bool]$Expected,[string]$Message) {
    $before=Get-ConversionState $Fixture
    $result=Test-ConversionCurrent -Workspace $Fixture.Workspace -Pom $Fixture.Pom
    Assert ($result.Valid -eq $Expected) ($Message+' '+($result.Diagnostics -join '; '))
    Assert (-not $result.AuthorizationInherited) 'Validacao operacional nao concede GO ou aceite.'
    Assert ((Get-ConversionState $Fixture) -ceq $before) 'Validar deve preservar bytes, datas e ausencias.'
}

foreach ($converted in @($false,$true)) {
    foreach ($documents in @(@('PlanPath'),@('TodoPath'),@('PlanPath','TodoPath'))) {
        $f=New-PreparedConversionFixture; $arguments=$f.Arguments
        if ($converted) { $null=Invoke-ConversionApply @arguments }
        $p=Get-HarnessProjectReference $f.Workspace $f.Pom
        foreach ($document in $documents) { Write-ConversionFile $p.$document '# Proposta humana local; manter escopo e decisao.' }
        $before=Get-ConversionState $f
        Reject { Invoke-ConversionApply @arguments } 'Preparo sem documentos na origem nao pode incorporar proposta humana presente no destino.'
        Assert ((Get-ConversionState $f) -ceq $before) 'Recusa deve preservar bytes e datas dos documentos humanos, contexto e originais.'
    }
}

foreach ($basis in @('EVIDENCIAS','MTA')) {
    $f=New-PreparedConversionFixture $basis; $plan=$f.Plan; $arguments=$f.Arguments
    $originals=@(Get-ChildItem -LiteralPath $f.Area -File -Recurse | ForEach-Object FullName)
    $originalState=Get-PreparedOriginalState $originals
    $before=Get-ConversionState $f
    $preview=Get-ConversionPreview @arguments
    Assert ((Get-ConversionState $f) -ceq $before) 'Previa do preparo deve ser somente leitura.'
    # Reproducao: o legado aponta destinos que nunca foram escritos pelo planejamento.
    $applied=Invoke-ConversionApply @arguments
    Assert ($applied.Status -ceq 'CONVERTIDO') 'Contexto preparado deve converter mesmo sem proposta escrita.'
    $p=Get-HarnessProjectReference $f.Workspace $f.Pom
    $data=Get-Content -LiteralPath $p.ContextPath -Raw|ConvertFrom-Json
    Assert ($preview.Planning.DocumentsState -ceq 'AUSENTES' -and $preview.Planning.Selection -ceq 'EXPLICITA') 'Previa distingue destinos ausentes da escolha explicita do contexto.'
    Assert (@($preview.ProposedFiles|Where-Object { $_.Destination -in @($p.PlanPath,$p.TodoPath) }).Count -eq 0) 'Previa nao deve propor copiar plano ou tarefas inexistentes.'
    Assert (-not (Test-Path -LiteralPath $p.PlanPath) -and -not (Test-Path -LiteralPath $p.TodoPath)) 'Conversao de preparo nao fabrica proposta ou tarefas.'
    Assert ((Test-Path -LiteralPath $data.PromptPath -PathType Leaf) -and $data.Purpose -ceq 'current-planning') 'Preparo convertido publica contexto e orientacao correntes.'
    Assert ($data.PlanningBasis -ceq $basis -and $data.SelectedIssues[0].Id -ceq 'java::regra') 'Base e escolhas funcionais devem permanecer.'
    Assert ($data.NeedsReview -and @($data.ReviewReasons).Count -gt 0 -and -not $preview.AuthorizationInherited) 'Conversao conserva revisao pendente, sem conceder GO.'
    Assert ([IO.File]::ReadAllText($p.MigrationPath) -match 'ANALISAR AGORA' -and [IO.File]::ReadAllText($p.MigrationPath) -match 'Nota humana: manter decisao') 'Decisao e nota humana do registro devem permanecer.'
    Assert ($data.FichaPaths.Count -eq 1 -and [IO.File]::ReadAllText($data.FichaPaths[0].Path) -match 'Risco: preservar transacao') 'Ficha preparada deve preservar o texto humano.'
    Assert ([IO.File]::ReadAllText($data.EvidenceIndexPath) -match 'Anexo conferido' -and $data.EvidenceIndexPath -eq (Join-Path $p.EvidencePath 'LEIA-ME.md')) 'Indice preparado deve conservar texto e destino corrente.'
    Assert ([Convert]::ToBase64String([IO.File]::ReadAllBytes((Join-Path $p.EvidencePath 'evidencia.bin'))) -ceq 'AP8NCt4=') 'Anexo humano deve conservar seus bytes.'
    Assert (@($data.EvidenceInputs|Where-Object Relation -EQ 'Contrato humano').Count -eq 1) 'Relacao humana do anexo deve permanecer.'
    Assert ((Get-PreparedOriginalState $originals) -ceq $originalState) 'Conversao preserva bytes e datas de todos os originais, inclusive prompt e MTA externo.'
    if ($basis -eq 'MTA') {
        $config=Get-Content -LiteralPath $p.ConfigPath -Raw|ConvertFrom-Json
        Assert ($config.mta.diretorio -eq $plan.Run -and $data.Mta.ReportPath -eq (Join-Path $plan.Run 'index.html')) 'MTA externo permanece associado na origem.'
    }
    Assert-PreparedValidation $f $true 'Contexto e prompt integros com ambos os documentos ausentes devem validar.'
    $before=Get-ConversionState $f
    $again=Invoke-ConversionApply @arguments
    Assert ($again.Status -ceq 'EQUIVALENTE' -and (Get-ConversionState $f) -ceq $before) 'Repetir preparo equivalente nao regrava nem cria documentos.'
    $cleanup=Get-ConversionCleanupPreview @arguments
    Assert (@($cleanup.Candidates|Where-Object { $_.Path -in @($plan.PlanPath,$plan.TodoPath) }).Count -eq 0) 'Documentos ausentes nunca sao candidatos de descarte.'
    Assert ((Get-ConversionState $f) -ceq $before) 'Previa de limpeza nao altera originais nem destino.'
    foreach ($path in @($p.PlanPath,$p.TodoPath)) {
        Write-ConversionFile $path '# Documento humano isolado'
        Assert-PreparedValidation $f $false 'Um unico documento corrente nao forma par valido.'
        [IO.File]::Delete($path)
        $null=[IO.Directory]::CreateDirectory($path)
        Assert-PreparedValidation $f $false 'Diretorio no caminho de plano ou tarefas correntes impede validar o preparo.'
        [IO.Directory]::Delete($path)
    }
    $register=[IO.File]::ReadAllText($p.MigrationPath)
    [IO.File]::AppendAllText($p.MigrationPath,("`n[Proposta citada](<"+$p.PlanPath+">)`n"))
    Assert-PreparedValidation $f $false 'Referencia Markdown explicita a proposta ausente continua pendente.'
    Write-ConversionFile $p.MigrationPath $register
    Assert-PreparedValidation $f $true 'Remover a referencia inexistente restaura o preparo valido.'
}

foreach ($document in @('PlanPath','TodoPath')) {
    $f=New-PreparedConversionFixture; $arguments=$f.Arguments
    Write-ConversionFile $f.Plan.$document '# Documento humano ja escrito'
    $before=Get-ConversionState $f
    $preview=Get-ConversionPreview @arguments
    Assert ($preview.Planning.DocumentsState -ceq 'INCOMPLETOS') 'Previa deve identificar os dois sentidos do par incompleto.'
    Reject { Invoke-ConversionApply @arguments } 'Um documento presente e outro ausente deve impedir toda publicacao.'
    Assert ((Get-ConversionState $f) -ceq $before) 'Recusa de par incompleto deve preservar todos os arquivos.'
}

foreach ($document in @('PlanPath','TodoPath')) {
    $f=New-PreparedConversionFixture; $arguments=$f.Arguments
    $null=[IO.Directory]::CreateDirectory($f.Plan.$document)
    $before=Get-ConversionState $f
    Reject { Invoke-ConversionApply @arguments } 'Diretorio no lugar de documento nao equivale a destino nunca escrito.'
    Assert ((Get-ConversionState $f) -ceq $before) 'Recusa de diretorio deve ocorrer sem publicacao.'
}

$f=New-PreparedConversionFixture; $arguments=$f.Arguments
foreach ($path in @($f.Plan.PlanPath,$f.Plan.TodoPath)) { Write-ConversionFile $path 'Rascunho humano ainda incompleto.' }
$before=Get-ConversionState $f
$preview=Get-ConversionPreview @arguments
Assert ($preview.Planning.DocumentsState -ceq 'PRESENTES') 'Estado documental informa existencia, sem atestar qualidade ou completude da proposta.'
Assert ((Get-ConversionState $f) -ceq $before) 'Previa de documentos existentes permanece somente leitura.'
'PASS: preparo sem proposta, bases EVIDENCIAS/MTA, originais e escolhas preservados, pares incompletos recusados e limpeza somente previa.'
