#requires -Version 5.1
[CmdletBinding()]
param(
    [string]$ConfigPath,[string]$WorkspacePath,
    [ValidateSet('New','Resume','Revise','Validate')][string]$Action,
    [switch]$All,[string[]]$Sources,[string]$ContextPath,[string]$Reason,
    [switch]$Interactive,[string]$EditorPath,[switch]$NoOpen,
    [ValidateSet('Text','Json')][string]$OutputFormat='Text'
)
$ErrorActionPreference='Stop'
try {
    if ($OutputFormat -eq 'Json' -and ($Interactive -or -not $NoOpen -or $EditorPath)) { throw 'Json exige NoOpen e escolhas explicitas, sem Interactive/EditorPath.' }
    Import-Module (Join-Path $PSScriptRoot 'HarnessSprintPlanning.psm1') -Force -DisableNameChecking
    Import-Module (Join-Path $PSScriptRoot 'Harness.psm1') -DisableNameChecking
    $root=Split-Path -Parent $PSScriptRoot
    if ($Interactive -and -not $Action) {
        Write-Host 'Planejamento macro de sprints'
        Write-Host '1. Novo cenario'
        Write-Host '2. Retomar contexto/proposta'
        Write-Host '3. Revisar com novas evidencias ou premissas'
        Write-Host '4. Validar e gerar cronograma'
        $choice=Read-Host 'Acao (numero; q cancela)'
        $Action=switch ($choice) { '1' {'New'} '2' {'Resume'} '3' {'Revise'} '4' {'Validate'} default { throw 'Selecao cancelada ou invalida; nenhuma operacao iniciada.' } }
    }
    if (-not $Action) { throw 'Informe a acao ou use a Run Task interativa.' }
    if ($Action -ne 'New' -and -not $ContextPath) {
        if (-not $Interactive) { throw 'Informe ContextPath para a acao escolhida.' }
        $history=@(Get-HarnessSprintHistory $root)
        if (-not $history.Count) { throw 'Nao ha cenarios de sprint. Use Novo cenario na mesma tarefa.' }
        for ($i=0;$i -lt $history.Count;$i++) {
            $item=$history[$i]
            Write-Host ("{0}. {1} | Revisao {2} | {3} | {4}" -f ($i+1),$item.PlanningId,$item.RevisionId,(($item.Projects | ForEach-Object Label) -join ', '),$item.Reason)
        }
        $number=0; $answer=Read-Host 'Contexto/revisao (numero; q cancela)'
        if (-not [int]::TryParse($answer,[ref]$number) -or $number -lt 1 -or $number -gt $history.Count) { throw 'Selecao cancelada ou invalida.' }
        $ContextPath=$history[$number-1].ContextPath
    }
    if ($Action -eq 'Validate') {
        $result=Complete-HarnessSprintPlan -Root $root -ContextPath $ContextPath
        $files=@($result.SprintPlanPath)
    } else {
        if (-not $ConfigPath) { $ConfigPath=Join-Path $root 'config/harness.local.json' }
        $context=Read-HarnessConfig $ConfigPath $root -WorkspacePath $WorkspacePath -SkipMigrationInitialization
        $selectScope=($Action -eq 'New')
        if ($Action -eq 'Revise' -and $Interactive -and -not $All -and -not $Sources) {
            Write-Host '1. Manter lista concreta de projetos da revisao escolhida'
            Write-Host '2. Atualizar selecao de projetos explicitamente'
            $scopeChoice=Read-Host 'Escopo da revisao (numero; q cancela)'
            if ($scopeChoice -eq '2') { $selectScope=$true }
            elseif ($scopeChoice -ne '1') { throw 'Selecao cancelada ou invalida.' }
        }
        if ($selectScope -and $Interactive -and -not $All -and -not $Sources) {
            Write-Host '1. Todos os projetos do workspace'
            Write-Host '2. Escolher projetos'
            $mode=Read-Host 'Escopo (numero; q cancela)'
            if ($mode -eq '1') { $All=$true }
            elseif ($mode -eq '2') {
                for ($i=0;$i -lt $context.Projects.Count;$i++) { Write-Host ("{0}. {1} | {2}" -f ($i+1),$context.Projects[$i].label,$context.Projects[$i].path) }
                $answer=Read-Host 'Numeros separados por virgula; q cancela'
                $Sources=@(foreach ($part in $answer.Split(',')) {
                    $number=0
                    if (-not [int]::TryParse($part.Trim(),[ref]$number) -or $number -lt 1 -or $number -gt $context.Projects.Count) { throw 'Selecao cancelada ou invalida.' }
                    $context.Projects[$number-1].path
                })
            } else { throw 'Selecao cancelada ou invalida.' }
        }
        if ($selectScope -and $Interactive) {
            $selected=if ($All) { @($context.Projects) } else { @($context.Projects | Where-Object path -In $Sources) }
            $preview=Get-HarnessSprintSources $context $selected
            Write-Host ("Escopo concreto: {0} projetos. Recorte inicial mandatory; o prompt perguntara sobre opcionais." -f $preview.Projects.Count)
            foreach ($project in $preview.Projects) {
                Write-Host ("{0} | {1} | issues mandatory conhecidas: {2}" -f $project.Label,$project.Source,@($project.Issues | Where-Object Category -EQ 'mandatory').Count)
                foreach ($diagnostic in $project.Diagnostics) { Write-Warning $diagnostic }
            }
            Write-Host 'Datas, prazo, equipe e estimativas serao perguntados pelo agente ao executar o prompt.'
            if ((Read-Host 'Digite PREPARAR para manter este escopo com suas lacunas; outro texto cancela') -cne 'PREPARAR') { throw 'Preparo cancelado; nenhum cenario criado.' }
        }
        if ($Action -eq 'Revise' -and -not $Reason -and $Interactive) { $Reason=Read-Host 'Motivo concreto da revisao (evidencias, estimativas ou premissas que mudaram)' }
        if ($Action -eq 'Revise' -and [string]::IsNullOrWhiteSpace($Reason)) { throw 'Revisao exige motivo; para entradas iguais use Retomar.' }
        if ($Action -eq 'New') { $result=New-HarnessSprintContext $context -All:$All -Sources $Sources }
        else { $result=New-HarnessSprintContext $context -PreviousContextPath $ContextPath -Reason $Reason -All:$All -Sources $Sources }
        $files=@($result.PromptPath,$result.SprintDataPath,$result.SprintPlanPath)
    }
    if ($OutputFormat -eq 'Json') { $result | ConvertTo-Json -Depth 60 }
    else {
        if ($Action -eq 'Validate') {
            Write-Host ("Validacao: {0} | Viabilidade: {1}" -f $result.Status,$result.Feasibility)
            foreach ($diagnostic in $result.Diagnostics) { Write-Warning $diagnostic }
            if ($result.PSObject.Properties['ReviewPromptPath']) {
                $files+= $result.ReviewPromptPath
                Write-Host ('Analise do resultado: '+$result.ReviewPromptPath)
                Write-Host ('Codex: no agente principal, envie: Execute o prompt deste arquivo: '+$result.ReviewPromptPath)
                Write-Host 'Copilot: abra esse prompt e use Executar Prompt. A analise e somente leitura; a revalidacao numerica continua nesta tarefa.'
            } else { Write-Host 'Revisao legada sem prompt de analise capturado. Use Revisar para adotar o fluxo atualizado.' }
        } else {
            Write-Host ("Cenario: {0} | Revisao: {1} | Retomado: {2}" -f $result.PlanningId,$result.RevisionId,$result.Reused)
            Write-Host ('Contexto: '+$result.ContextPath)
            Write-Host ('Codex: em nova conversa com o agente principal, fora do helper, envie: Execute o prompt deste arquivo: '+$result.PromptPath)
            Write-Host 'Copilot: abra o prompt e use Executar Prompt com o executor indicado. Preparo nao executa o agente.'
            Write-Host 'Depois use esta mesma tarefa: Validar e gerar cronograma. Para editar uma revisao ja validada, use Revisar.'
        }
        Write-Host ('Plano: '+$result.SprintPlanPath)
        if (-not $NoOpen -and $EditorPath) {
            try { Open-HarnessEditor $EditorPath $files $root }
            catch { Write-Warning ('Arquivos salvos; abra os caminhos informados. '+$_.Exception.Message) }
        }
    }
    exit 0
} catch {
    if ($OutputFormat -eq 'Json') { [pscustomobject]@{Status='FAILED';Error=$_.Exception.Message} | ConvertTo-Json }
    else { Write-Host ('ERRO no planejamento de sprints: '+$_.Exception.Message) -ForegroundColor Red }
    exit 1
}
