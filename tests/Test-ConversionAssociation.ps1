#requires -Version 5.1
$ErrorActionPreference='Stop'; Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'ConversionFixture.ps1')
Import-Module (Join-Path $root 'tools/transicao/ConversaoPublicacao.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $root 'tools/transicao/ConversaoPrevia.psm1') -DisableNameChecking
Import-Module (Join-Path $root 'tools/transicao/ConversaoValidacao.psm1') -DisableNameChecking
Import-Module (Join-Path $root 'tools/transicao/ConversaoLimpeza.psm1') -DisableNameChecking
Import-Module (Join-Path $root 'scripts/HarnessProject.psm1') -DisableNameChecking

function Write-Association($Fixture,[string]$ArtifactId='api') {
    $path=Join-Path $Fixture.Workspace ('.harness/planning/'+$ArtifactId+'/issues/project.json')
    Write-ConversionFile $path (@{ArtifactId=$ArtifactId;Project='_workspace-cbb23022b6210ef0d5e3a1f3';Source=$Fixture.Source}|ConvertTo-Json)
    $path
}

# Reproducao: somente cadastro antigo e registro sem escolhas, nenhum plano.
$f=New-ConversionFixture
Write-ConversionFile $f.Register ([IO.File]::ReadAllText($f.Register).Replace('ANALISAR AGORA | PLANEJADA','A DEFINIR | NAO ANALISADA'))
$association=Write-Association $f
$before=Get-ConversionState $f
$preview=Get-ConversionPreview $f.Workspace $f.Pom
Assert ($preview.Planning.Selection -ceq 'SEM_PLANO' -and $preview.Planning.Candidates.Count -eq 0) 'Associacao sem plano deve informar SEM_PLANO, sem exigir Contexto inexistente.'
Assert ($null -eq $preview.Planning.ContextPath -and ($preview.Pending -join ' ') -notmatch 'escolha Contexto|destino de PLANNING') 'Metadados de identidade nao sao plano nem conteudo desconhecido.'
Assert (@($preview.ProposedFiles | Where-Object Origin -EQ $association).Count -eq 1) 'Previa deve mostrar destino da associacao legada.'
Assert ((Get-ConversionState $f) -ceq $before) 'Previa deve preservar bytes e datas de todas as entradas.'
Reject { Get-ConversionPreview $f.Workspace $f.Pom -Contexto $association } 'Associacao nao pode ser selecionada como contexto.'
$originals=@($association,$f.Register) | ForEach-Object { [pscustomobject]@{Path=$_;Text=[IO.File]::ReadAllText($_);Ticks=[IO.File]::GetLastWriteTimeUtc($_).Ticks} }
$result=Invoke-ConversionApply $f.Workspace $f.Pom
$project=Get-HarnessProjectReference $f.Workspace $f.Pom
Assert ($result.Status -ceq 'CONVERTIDO') 'Associacao sem plano deve permitir conversao do registro.'
foreach ($path in @($project.ContextPath,$project.PlanPath,$project.TodoPath,(Join-Path $project.Folder 'atual/planejamento/planejar-lotes.prompt.md'))) {
    Assert (-not (Test-Path -LiteralPath $path)) 'Conversao nao deve fabricar planejamento.'
}
$config=Get-Content -LiteralPath $project.ConfigPath -Raw|ConvertFrom-Json
Assert ($config.pom -ceq $f.Pom -and -not $config.PSObject.Properties['Project']) 'Destino deve associar POM sem manter alias tecnico.'
Assert ([IO.File]::ReadAllText($project.MigrationPath) -match 'A DEFINIR \| NAO ANALISADA') 'Decisao e andamento humanos devem permanecer.'
foreach ($item in $originals) {
    Assert ([IO.File]::ReadAllText($item.Path) -ceq $item.Text -and [IO.File]::GetLastWriteTimeUtc($item.Path).Ticks -eq $item.Ticks) 'Aplicar preserva conteudo e datas dos originais.'
}
Assert ((Test-ConversionCurrent $f.Workspace $f.Pom).Valid) 'Projeto sem plano deve validar pelo contrato corrente.'
$before=Get-ConversionState $f
Assert ((Invoke-ConversionApply $f.Workspace $f.Pom).Status -ceq 'EQUIVALENTE') 'Reaplicacao deve ser equivalente.'
Assert ((Get-ConversionState $f) -ceq $before) 'Reaplicacao nao deve regravar entradas nem destinos.'
$cleanup=Get-ConversionCleanupPreview -Workspace $f.Workspace -Pom $f.Pom
$candidate=@($cleanup.Candidates | Where-Object Path -EQ $association)
Assert ($candidate.Count -eq 1 -and $candidate[0].Eligible -and $candidate[0].Destination -eq $project.ConfigPath) 'Associacao transformada so deve ser elegivel para descarte explicito apos equivalencia.'
Assert ((Get-ConversionState $f) -ceq $before) 'Previa de descarte nao deve remover a associacao.'
Write-Host 'PASS: associacao sem plano, preservacao, validacao, repeticao e previa de descarte.'

# Outra aplicacao, com plano real e a mesma especie de associacao.
$f=New-ConversionFixture
Write-ConversionFile $f.Pom '<project><artifactId>servico</artifactId></project>'
$association=Write-Association $f 'servico'
$plan=Add-ConversionPlan $f ('a'*32) -ProjectFolder servico
[IO.File]::AppendAllText($f.Register,("`n[Plano](<"+$plan.PlanPath+">)`n"))
$preview=Get-ConversionPreview $f.Workspace $f.Pom
Assert ($preview.Project -ceq 'servico' -and $preview.Planning.ContextPath -eq $plan.ContextPath) 'Outra aplicacao deve manter seu plano vinculado.'
$null=Invoke-ConversionApply $f.Workspace $f.Pom
$project=Get-HarnessProjectReference $f.Workspace $f.Pom
Assert ([IO.File]::ReadAllText($project.PlanPath) -match 'Plano humano' -and [IO.File]::ReadAllText($project.TodoPath) -match 'Testar') 'Plano e tarefas existentes devem ser preservados no destino.'
Assert ((Test-ConversionCurrent $f.Workspace $f.Pom).Valid) 'Outra aplicacao com plano deve validar.'
Assert (Test-Path -LiteralPath $association) 'Aplicacao com plano tambem preserva a associacao original.'
Write-Host 'PASS: segunda aplicacao sintetica com plano vinculado.'

# Relocalizacao continua exigindo SourceLegado explicito.
$f=New-ConversionFixture
$association=Write-Association $f
$relocated=Join-Path $f.Area 'clone-local/pom.xml'
Write-ConversionFile $relocated '<project><artifactId>api</artifactId></project>'
Reject { Invoke-ConversionApply $f.Workspace $relocated } 'Mesmo artifactId nao autoriza reassociar Source.'
$preview=Get-ConversionPreview $f.Workspace $relocated -SourceLegado $f.Source
Assert ($preview.Planning.Selection -ceq 'SEM_PLANO' -and $preview.Register.Path -eq $f.Register) 'SourceLegado explicito deve permitir associacao sem plano.'
$null=Invoke-ConversionApply $f.Workspace $relocated -SourceLegado $f.Source
Assert ((Test-ConversionCurrent $f.Workspace $relocated).Valid) 'Associacao relocalizada deve validar.'

# Formatos desconhecidos e identidades divergentes nunca sao ignorados.
foreach ($variant in @('artifactId','caixa','source','project','extra','ausente','array','local')) {
    $f=New-ConversionFixture
    $association=Write-Association $f
    $data=Get-Content -LiteralPath $association -Raw|ConvertFrom-Json
    switch ($variant) {
        'artifactId' { $data.ArtifactId='outro' }
        'caixa' { $data.ArtifactId='API' }
        'source' { $data.Source=Join-Path $f.Source 'modulo' }
        'project' { $data.Project='' }
        'extra' { $data|Add-Member NoteProperty NotaHumana 'Preservar este conteudo desconhecido.' }
        'ausente' { $data.PSObject.Properties.Remove('Source') }
        'array' { $data.Source=@($f.Source) }
        'local' { $association=Join-Path $f.Workspace '.harness/planning/api/outro/project.json' }
    }
    Write-ConversionFile $association ($data|ConvertTo-Json)
    $before=Get-ConversionState $f
    Reject { Invoke-ConversionApply $f.Workspace $f.Pom } ('Associacao invalida deve impedir publicacao: '+$variant)
    Assert ((Get-ConversionState $f) -ceq $before) ('Recusa deve preservar entradas e nao publicar: '+$variant)
}

# Ausencia real de plano e referencia quebrada sao casos distintos.
$f=New-ConversionFixture
$preview=Get-ConversionPreview $f.Workspace $f.Pom
Assert ($preview.Planning.Selection -ceq 'SEM_PLANO') 'Projeto sem cadastro legado nem plano tambem deve informar ausencia.'
$association=Write-Association $f
$missing=Join-Path $f.Workspace '.harness/planning/api/ausente/plan.md'
[IO.File]::AppendAllText($f.Register,("`n[Plano em uso](<"+$missing+">)`n"))
$before=Get-ConversionState $f
$preview=Get-ConversionPreview $f.Workspace $f.Pom
Assert ($preview.Planning.Selection -ceq 'PENDENTE' -and ($preview.Pending -join ' ') -match 'Vinculo de planejamento nao resolvido') 'Referencia quebrada nao pode virar ausencia de plano.'
Reject { Invoke-ConversionApply $f.Workspace $f.Pom } 'Plano referenciado ausente deve impedir publicacao.'
Assert ((Get-ConversionState $f) -ceq $before) 'Vinculo quebrado nao pode provocar reparo automatico.'
$f=New-ConversionFixture
$association=Write-Association $f
$plan=Add-ConversionPlan $f ('a'*32)
$before=Get-ConversionState $f
$preview=Get-ConversionPreview $f.Workspace $f.Pom
Assert ($preview.Planning.Selection -ceq 'PENDENTE' -and $preview.Planning.Candidates.Count -eq 1) 'Plano existente sem vinculo continua exigindo escolha.'
Reject { Invoke-ConversionApply $f.Workspace $f.Pom } 'Associacao nao autoriza escolher plano unico sem vinculo.'
Assert ((Get-ConversionState $f) -ceq $before) 'Plano sem escolha deve permanecer intacto.'
Write-Host 'PASS: identidade, formato desconhecido, relocalizacao e vinculos de planejamento protegidos.'

# Falha de leitura nao comprova ausencia de plano, mesmo sem link no registro.
foreach ($linked in @($false,$true)) {
    $f=New-ConversionFixture
    $association=Write-Association $f
    $broken=Add-ConversionPlan $f ('b'*32)
    Write-ConversionFile $broken.ContextPath '{"Purpose":'
    if ($linked) {
        $plan=Add-ConversionPlan $f ('a'*32) -ProjectFolder api
        [IO.File]::AppendAllText($f.Register,("`n[Plano](<"+$plan.PlanPath+">)`n"))
    }
    $before=Get-ConversionState $f
    $preview=Get-ConversionPreview $f.Workspace $f.Pom
    Assert ($preview.Planning.Selection -ceq 'PENDENTE' -and ($preview.Pending -join ' ') -match 'Origem nao interpretada') 'Contexto corrompido exige conferencia, com ou sem outro plano vinculado.'
    Reject { Invoke-ConversionApply $f.Workspace $f.Pom } 'Falha de leitura deve impedir publicacao parcial.'
    Assert ((Get-ConversionState $f) -ceq $before) 'Contexto corrompido nao pode provocar escrita ou recuperacao.'
}
Write-Host 'PASS: contexto corrompido nao vira ausencia de plano nem e ignorado por outro vinculo.'

$f=New-ConversionFixture
$association=Write-Association $f
Write-ConversionFile (Join-Path $f.Workspace '.harness/builds/antigo/result.json') '{"Source":'
$before=Get-ConversionState $f
Reject { Invoke-ConversionApply $f.Workspace $f.Pom } 'Origem complementar ilegivel tambem exige conferencia antes da publicacao.'
Assert ((Get-ConversionState $f) -ceq $before) 'Origem complementar corrompida deve permanecer intacta.'
