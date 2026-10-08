#requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'Harness.psm1') -DisableNameChecking

function Get-HarnessSonarReview {
    param([string]$Root, [string]$ResultPath)
    if ([string]::IsNullOrWhiteSpace($ResultPath)) { throw 'Informe o result.json da coleta selecionada.' }
    $path=Resolve-HarnessPath $ResultPath $Root
    $base=Resolve-HarnessPath (Join-Path $Root '.harness/sonar') $Root
    if (-not $path.StartsWith($base + '\', [StringComparison]::OrdinalIgnoreCase) -or (Split-Path -Leaf $path) -cne 'result.json') { throw 'Escolha um result.json de .harness/sonar deste harness.' }
    $result=Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
    foreach ($field in @('RunId','Source','ProjectKey','ServerUrl','Status','QualityGateStatus','CriteriaStatus')) {
        if (-not $result.PSObject.Properties[$field] -or [string]::IsNullOrWhiteSpace([string]$result.$field)) { throw 'Recibo Sonar incompleto.' }
    }
    $run=Split-Path -Parent $path
    $evidence=@(foreach ($name in @('result.json','inputs.json','quality-gate.json','measures.json','issues.json','criteria.json')) {
        $file=Resolve-HarnessPath (Join-Path $run $name) $Root
        if (Test-Path -LiteralPath $file -PathType Leaf) { [pscustomobject]@{Name=$name;Sha256=(Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash} }
    })
    $dir=Resolve-HarnessPath (Join-Path $run 'decisions') $Root
    $history=@(); $previous=$null; $current=$null
    if (Test-Path -LiteralPath $dir) {
        $files=@(Get-ChildItem -LiteralPath $dir -File -Filter '*.json' | Sort-Object Name)
        if ($files.Count -gt 1000) { throw 'Historico de decisoes excedeu 1000 entradas.' }
        foreach ($file in $files) {
            $filePath=Resolve-HarnessPath $file.FullName $Root
            $entry=Get-Content -LiteralPath $filePath -Raw -Encoding UTF8 | ConvertFrom-Json
            foreach ($field in @('Source','ProjectKey','ServerUrl')) {
                if ($entry.$field -cne $result.$field) { throw 'Identidade da decisao diverge da coleta.' }
            }
            $sequence=$history.Count + 1
            if ($file.Name -cne ('decision_{0:D6}.json' -f $sequence) -or $entry.Sequence -ne $sequence -or
                $entry.SchemaVersion -ne 1 -or $entry.RunId -cne $result.RunId -or $entry.PreviousSha256 -cne $previous -or
                $entry.Decision -cnotin @('CorrigirAgora','RegistrarParaDepois','Interromper') -or
                (ConvertTo-Json -InputObject @($entry.Evidence) -Compress) -cne (ConvertTo-Json -InputObject $evidence -Compress)) { throw 'Historico Sonar divergente: confira origem, sequencia e hashes das evidencias.' }
            if ($entry.Decision -ceq 'RegistrarParaDepois' -and ([string]::IsNullOrWhiteSpace($entry.Note) -or [string]::IsNullOrWhiteSpace($entry.ReviewWhen))) { throw 'Adiamento sem motivo/gatilho.' }
            $history+= $entry; $current=$entry
            $previous=(Get-FileHash -LiteralPath $filePath -Algorithm SHA256).Hash
        }
    }
    [pscustomobject]@{ResultPath=$path;Result=$result;Evidence=$evidence;Directory=$dir;History=$history;Current=$current;LastSha256=$previous;Decision=$(if ($current) { $current.Decision } else { 'PENDING' })}
}

function Save-HarnessSonarDecision {
    param([string]$Root, [string]$ResultPath,
        [Parameter(Mandatory=$true)][ValidateSet('CorrigirAgora','RegistrarParaDepois','Interromper')][string]$Decision,
        [ValidateLength(0,4000)][string]$Note, [ValidateLength(0,1000)][string]$ReviewWhen)
    if ($Decision -ceq 'RegistrarParaDepois' -and ([string]::IsNullOrWhiteSpace($Note) -or [string]::IsNullOrWhiteSpace($ReviewWhen))) { throw 'Informe motivo e momento/gatilho de revisao do adiamento.' }
    $state=Get-HarnessSonarReview $Root $ResultPath
    $lockPath=Resolve-HarnessPath (Join-Path (Split-Path $state.ResultPath) 'decision.lock') $Root
    try { $lock=[IO.File]::Open($lockPath,'OpenOrCreate','ReadWrite','None') }
    catch { throw 'Outra decisao esta sendo registrada nesta coleta.' }
    try {
        $state=Get-HarnessSonarReview $Root $ResultPath
        if ($state.History.Count -ge 1000) { throw 'Historico de decisoes excedeu 1000 entradas.' }
        $null=[IO.Directory]::CreateDirectory($state.Directory)
        $sequence=$state.History.Count + 1
        $entry=[ordered]@{
            SchemaVersion=1;Sequence=$sequence;RunId=$state.Result.RunId;Source=$state.Result.Source
            ProjectKey=$state.Result.ProjectKey;ServerUrl=$state.Result.ServerUrl
            RecordedAtUtc=[DateTime]::UtcNow.ToString('o');Decision=$Decision;Note=$Note;ReviewWhen=$ReviewWhen
            Evidence=$state.Evidence;PreviousSha256=$state.LastSha256
            Scope='Decisao de continuidade local; nao altera Quality Gate, nao concede GO, aceite ou dispensa corporativa.'
        }
        $destination=Join-Path $state.Directory ('decision_{0:D6}.json' -f $sequence)
        $temporary=Join-Path $state.Directory ([guid]::NewGuid().ToString('N') + '.tmp')
        [IO.File]::WriteAllText($temporary, ($entry | ConvertTo-Json -Depth 10), (New-Object Text.UTF8Encoding($false)))
        [IO.File]::Move($temporary,$destination)
    } finally { $lock.Dispose() }
    Get-HarnessSonarReview $Root $ResultPath
}

function Show-HarnessSonarReview {
    param([string]$Root, [string]$ResultPath)
    $state=Get-HarnessSonarReview $Root $ResultPath
    Write-Host "Coleta: $($state.Result.RunId) | Projeto: $($state.Result.ProjectKey) | Source: $($state.Result.Source)"
    Write-Host "Operacao: $($state.Result.Status) | Gate corporativo: $($state.Result.QualityGateStatus) | Criterios: $($state.Result.CriteriaStatus)"
    $summaryPath=Resolve-HarnessPath (Join-Path (Split-Path $state.ResultPath) 'RESUMO.md') $Root
    if (Test-Path -LiteralPath $summaryPath -PathType Leaf) { Write-Host (Get-Content -LiteralPath $summaryPath -Raw -Encoding UTF8) }
    else { Write-Host 'RESUMO.md ausente; confira os JSONs de evidencia antes de decidir.' }
    Write-Host "Decisao registrada: $($state.Decision)"
    if ($state.Current) { Write-Host "Motivo: $($state.Current.Note) | Rever: $($state.Current.ReviewWhen)" }
    Write-Host 'A escolha registra continuidade local; nao muda o gate nem autoriza executar corretivas.'
    $choice=Read-Host '1 Corrigir agora; 2 Registrar para depois e continuar outras atividades; 3 Interromper; Enter conserva a decisao atual (PENDING se ausente)'
    $decision=switch ($choice) { '1' { 'CorrigirAgora' } '2' { 'RegistrarParaDepois' } '3' { 'Interromper' } '' { return $state } default { throw 'Opcao invalida; nenhuma decisao registrada.' } }
    $note=Read-Host 'Motivo/observacao (obrigatorio para adiar; sem credenciais)'
    $when=''
    if ($decision -ceq 'RegistrarParaDepois') { $when=Read-Host 'Quando rever: data, lote ou gatilho (obrigatorio)' }
    $state=Save-HarnessSonarDecision $Root $ResultPath $decision -Note $note -ReviewWhen $when
    Write-Host "Decisao salva em: $($state.Directory)"
    if ($decision -ceq 'CorrigirAgora') { Write-Host 'Proximo passo: vincular estas evidencias a issue/registro e usar Planejamento: planejar; revisao/GO e implementacao sao etapas separadas.' }
    if ($decision -ceq 'RegistrarParaDepois') { Write-Host "Lembrete local para a retomada: $when. Vincule esta coleta ao registro/plano para o helper recupera-la. Nao ha agendamento automatico." }
    $state
}

Export-ModuleMember -Function Get-HarnessSonarReview, Save-HarnessSonarDecision, Show-HarnessSonarReview
