#requires -Version 5.1
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $root 'scripts/Harness.psm1') -Force -DisableNameChecking
function Assert($value, $message) { if (-not $value) { throw $message } }
function Reject($action, $message) { $failed = $false; try { & $action } catch { $failed = $true }; Assert $failed $message }
$area = Join-Path $root ('.harness/tests/registro-' + [guid]::NewGuid().ToString('N'))
$contractDestination = Join-Path $area 'doc/especificacoes/planejamento-copilot.md'
$null = [IO.Directory]::CreateDirectory((Split-Path $contractDestination -Parent))
Copy-Item (Join-Path $root 'doc/especificacoes/planejamento-copilot.md') $contractDestination
$project = [pscustomobject]@{name='app';label='Aplicacao';path=(Join-Path $area 'source')}
$context = [pscustomobject]@{Root=$area;Active=$project}
$register = Initialize-HarnessMigration $area $project
Assert ((Split-Path $register.MigrationPath -Leaf) -eq 'migracao-Aplicacao.md') 'Novo registro deve identificar o projeto no nome.'
Assert (Test-Path $register.MigrationPath) 'Projeto sem MTA deve ter registro.'
Assert ((Get-Content $register.MigrationPath -Raw).Contains('AGUARDANDO MTA')) 'Nao inventar catalogo inicial.'
$before = (Get-FileHash $register.MigrationPath).Hash
$project.label = 'Renomeado'
$again = Initialize-HarnessMigration $area $project
Assert ($again.MigrationPath -eq $register.MigrationPath) 'Renomear label nao pode duplicar registro.'
Assert ((Get-FileHash $register.MigrationPath).Hash -eq $before) 'Reimportacao deve preservar edicoes.'
$workspaceProject = [pscustomobject]@{name='_workspace-outra-identidade';label='Renomeado';path=$project.path}
Assert ((Initialize-HarnessMigration $area $workspaceProject).MigrationPath -eq $register.MigrationPath) 'JSON local e workspace devem compartilhar registro da mesma raiz.'
$other = Initialize-HarnessMigration $area ([pscustomobject]@{name='outro';label='Renomeado';path='C:/outro'})
Assert ($other.MigrationPath -ne $register.MigrationPath) 'Homonimos nao podem compartilhar registro.'
$run = Join-Path $area 'recebido'
$null = New-Item -ItemType Directory -Path (Join-Path $run 'output/static-report') -Force
$dataPath = Join-Path $run 'output/static-report/output.js'
function Write-Catalog($violations) {
    $apps = @(@{id='0000';name='input';rulesets=@(@{name='hibernate';violations=$violations})})
    [IO.File]::WriteAllText($dataPath, ('window["apps"] = ' + (ConvertTo-Json -InputObject $apps -Depth 10)), (New-Object Text.UTF8Encoding($false)))
}
Write-Catalog @{ 'rule-1'=@{description='Titulo | especial';category='mandatory';incidents=@(1..138 | ForEach-Object { @{uri="file-$_"} })}; 'rule-2'=@{description='Outra';category='future-category';incidents=@(@{uri='a'},@{uri='b'})} }
$selected = [pscustomobject]@{Run=$run;RunId=('a'*32)}
Write-HarnessJson (Join-Path $run 'manifest.json') @{Project='colega';Source='C:/maquina-do-colega';RunId=$selected.RunId}
$updated = Update-HarnessMigration $context $selected
$text = Get-Content $updated.MigrationPath -Raw -Encoding UTF8
Assert ($text.Contains('| mandatory | 138 | PRESENTE | A DEFINIR | NAO ANALISADA |')) 'Contar incidentes reais por regra.'
Assert ($text.Contains('future-category')) 'Preservar categoria desconhecida.'
Assert ($text.Contains('Total MTA: 2 issues (regras) / 140 ocorrencias.')) 'Falta total de regras e ocorrencias do catalogo.'
$text = $text.Replace('| A DEFINIR | NAO ANALISADA |', '| ADIAR | ANALISADA |')
$text = $text.Replace('<!-- mta:fim -->', "| DEV-001 | Adicional | manual | - | MANUAL | ANALISAR AGORA | NAO ANALISADA | Evidencia local |`n<!-- mta:fim -->")
$text += "`nDecisao humana fora da tabela: preservar javax.`n"
[IO.File]::WriteAllText($updated.MigrationPath, $text, (New-Object Text.UTF8Encoding($false)))
Write-Catalog @{ 'rule-1'=@{description='Titulo atualizado';category='mandatory';incidents=@(@{uri='a'})} }
$null = Update-HarnessMigration $context $selected
$text = Get-Content $updated.MigrationPath -Raw -Encoding UTF8
Assert ($text.Contains('| mandatory | 1 | PRESENTE | ADIAR | ANALISADA |')) 'Novo MTA nao pode redefinir decisoes/andamento.'
Assert ($text.Contains('| future-category | 2 | NAO REENCONTRADA | ADIAR | ANALISADA |')) 'Ausencia nao e correcao nem contagem zero.'
Assert ($text.Contains('DEV-001') -and $text.Contains('Decisao humana fora da tabela')) 'Preservar issues manuais e texto livre.'
Assert ($text.Contains('Total MTA: 1 issues (regras) / 1 ocorrencias.')) 'Total deve excluir nao reencontradas e manuais.'
$before = (Get-FileHash $updated.MigrationPath).Hash
$null = Update-HarnessMigration $context $selected
Assert ((Get-FileHash $updated.MigrationPath).Hash -eq $before) 'Reconciliacao deve ser idempotente.'
[IO.File]::WriteAllText($dataPath, 'window["apps"] = []; malicious();')
Reject { Update-HarnessMigration $context $selected } 'JavaScript arbitrario nao pode ser aceito.'
Assert ((Get-FileHash $updated.MigrationPath).Hash -eq $before) 'Erro de leitura nao pode apagar registro.'
[IO.File]::WriteAllText($dataPath, 'window["apps"] = [{"rulesets":null}];')
Reject { Update-HarnessMigration $context $selected } 'Rulesets ausentes nao podem simular zero issues.'
Assert ((Get-FileHash $updated.MigrationPath).Hash -eq $before) 'Catalogo incompleto alterou registro.'
Write-Catalog @{}
[IO.File]::WriteAllText($updated.MigrationPath, $text.Replace('<!-- mta:fim -->', "| linha invalida |`n<!-- mta:fim -->"))
$invalidHash = (Get-FileHash $updated.MigrationPath).Hash
Reject { Update-HarnessMigration $context $selected } 'Tabela invalida deve ser preservada para conciliacao.'
Assert ((Get-FileHash $updated.MigrationPath).Hash -eq $invalidHash) 'Erro na tabela apagou escolhas.'
[IO.File]::WriteAllText($updated.MigrationPath, $text)
Import-Module (Join-Path $root 'scripts/HarnessPlanning.psm1') -Force -DisableNameChecking
$templatePath = Join-Path $area '.github/prompts'
$null = New-Item -ItemType Directory -Path $templatePath -Force
Copy-Item (Join-Path $root '.github/prompts/manter-migracao.prompt.md') $templatePath
$existing = Join-Path $area 'registro-colega.md'
Set-Content -LiteralPath $existing 'Decisao conflitante trazida de colega; nao sobrescrever.'
$before = (Get-FileHash $updated.MigrationPath).Hash
$sourceHash = (Get-FileHash $existing).Hash
$beforeMaintenance = [IO.File]::ReadAllText($updated.MigrationPath)
$maintenance = New-MtaMigrationPrompt $context -MigrationSourcePath $existing
$receipt = Get-Content $maintenance.ContextPath -Raw | ConvertFrom-Json
Assert ($receipt.Run -eq $null -and $receipt.RunId -eq $null) 'Evidencias nao podem escolher scan implicitamente.'
Assert ($receipt.MigrationSourcePath -eq $existing -and $receipt.MigrationPath -eq $updated.MigrationPath) 'Documento recebido foi confundido com destino.'
$afterMaintenance = [IO.File]::ReadAllText($updated.MigrationPath)
$withoutState = [regex]::Replace($afterMaintenance, '(?s)<!-- reconciliacao:inicio -->.*?<!-- reconciliacao:fim -->\r?\n\r?\n', '')
Assert ($withoutState -ceq $beforeMaintenance -and (Get-FileHash $existing).Hash -eq $sourceHash) 'Preparo alterou conteudo alem da secao de reconciliacao ou documento recebido.'
Assert ($afterMaintenance.Contains('Estado: PENDENTE')) 'Preparo deve deixar execucao do prompt pendente.'
Assert (Test-Path $maintenance.PromptPath) 'Manutencao sem MTA deve gerar prompt.'
Import-Module (Join-Path $root 'scripts/HarnessCleanup.psm1') -Force -DisableNameChecking
$cleanup = @(Get-HarnessCleanupPaths $area -Source $project.path)
Assert ((Split-Path $maintenance.ContextPath -Parent) -in $cleanup) 'Limpeza por projeto deve reconhecer preparo do registro.'
Assert ($updated.MigrationPath -notin $cleanup -and (Split-Path $updated.MigrationPath -Parent) -notin $cleanup) 'Limpeza nao pode incluir registro permanente.'
$legacyPath = Join-Path (Split-Path $other.MigrationPath -Parent) 'migracao.md'
Move-Item -LiteralPath $other.MigrationPath -Destination $legacyPath
$legacy = Initialize-HarnessMigration $area ([pscustomobject]@{name='outro';label='Novo rotulo';path='C:/outro'})
Assert ($legacy.MigrationPath -eq $legacyPath) 'Registro legado deve manter caminho referenciado por prompts antigos.'
$null = Update-HarnessMigration $context $selected
Assert ([IO.File]::ReadAllText($updated.MigrationPath).Contains('Total MTA: 0 issues (regras) / 0 ocorrencias.')) 'Rodada sem achados deve apresentar totais zero sem apagar historico.'
Write-Output 'PASS: registro, identidade, catalogo real, contagens, conciliacao e preservacao humana.'
