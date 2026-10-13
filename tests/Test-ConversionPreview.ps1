#requires -Version 5.1
$ErrorActionPreference='Stop'; Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'ConversionFixture.ps1')
Import-Module (Join-Path $root 'tools/transicao/ConversaoPrevia.psm1') -Force -DisableNameChecking
$f=New-ConversionFixture
$first=Add-ConversionPlan $f ('a'*32)
$second=Add-ConversionPlan $f ('b'*32) $first.RequestId
# O registro aponta o ancestral, que tem data mais nova: somente o vinculo define a ponta.
[IO.File]::AppendAllText($f.Register,("`n[Plano em uso](<"+$first.PlanPath+">)`n"))
[IO.File]::SetLastWriteTimeUtc($first.ContextPath,[DateTime]::UtcNow.AddDays(1))
$before=Get-ConversionState $f
$preview=Get-ConversionPreview -Workspace $f.Workspace -Pom $f.Pom
Assert ($preview.Project -ceq 'api' -and $preview.Destination -eq (Join-Path $f.Workspace '.harness/projetos/api')) 'Destino deve vir do artifactId direto do POM.'
Assert ($preview.Planning.ContextPath -eq $second.ContextPath -and $preview.Planning.Selection -eq 'VINCULO_UNICO') 'Selecao deve seguir Previous, nunca data.'
Assert ($preview.Register.Path -eq $f.Register -and $preview.Register.Decisions.Count -eq 1) 'Previa deve preservar registro e decisoes por issue.'
Assert ($preview.Reconciliation.State -eq 'PRELIMINAR' -and -not $preview.AuthorizationInherited) 'Preparo nao comprova reconciliacao nem GO.'
Assert (@($preview.ProposedFiles | Where-Object Destination -EQ (Join-Path $preview.Destination 'atual/planejamento/plano.md')).Count -eq 1) 'Previa deve mostrar destino concreto do plano.'
Assert (-not (Test-Path $preview.Destination) -and (Get-ConversionState $f) -ceq $before) 'Previa nao pode criar destino, lock, mapa ou alterar origem.'
$again=Get-ConversionPreview -Workspace $f.Workspace -Pom $f.Pom
Assert (($again|ConvertTo-Json -Depth 40) -ceq ($preview|ConvertTo-Json -Depth 40)) 'Mesmas entradas devem gerar mesma previa.'
$module=Get-ConversionPreview -Workspace $f.Workspace -Pom (Join-Path $f.Source 'modulo/pom.xml')
Assert ($module.Project -ceq 'modulo' -and $null -eq $module.Register.Path) 'Selecionar modulo nao herda registro do agregador.'
$relocated=Join-Path $f.Area 'clone-local/pom.xml'; Write-ConversionFile $relocated '<project><artifactId>api</artifactId></project>'
$without=Get-ConversionPreview -Workspace $f.Workspace -Pom $relocated
Assert ($null -eq $without.Register.Path) 'Mesmo artifactId nao associa Source antigo implicitamente.'
$explicit=Get-ConversionPreview -Workspace $f.Workspace -Pom $relocated -SourceLegado $f.Source
Assert ($explicit.Register.Path -eq $f.Register -and $explicit.Source -eq (Split-Path $relocated -Parent)) 'Relocalizacao exige associacao explicita ao Source legado.'
$fork=Add-ConversionPlan $f ('c'*32) $first.RequestId
$ambiguous=Get-ConversionPreview -Workspace $f.Workspace -Pom $f.Pom
Assert ($null -eq $ambiguous.Planning.ContextPath -and $ambiguous.Planning.Candidates.Count -eq 2 -and $ambiguous.Pending.Count -gt 0) 'Duas pontas nao podem ser escolhidas por recencia.'
$chosen=Get-ConversionPreview -Workspace $f.Workspace -Pom $f.Pom -Contexto $fork.ContextPath
Assert ($chosen.Planning.ContextPath -eq $fork.ContextPath -and $chosen.Planning.Selection -eq 'EXPLICITA') 'Escolha explicita deve resolver a proposta a converter.'
Write-Host 'PASS: previa sem escrita, POM, associacao explicita, vinculos, pontas e preliminaridade.'
