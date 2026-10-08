#requires -Version 5.1
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $root 'scripts/HarnessSonar.psm1') -Force -DisableNameChecking
function Assert($condition,$message) { if (-not $condition) { throw $message } }
$module=Get-Module HarnessSonar
& $module {
    $script:IssueMode='OK'; $script:IssueCalls=@()
    function script:Invoke-SonarApiGet {
        param($ServerUrl,$Endpoint,$Query,$AuthScheme)
        $script:IssueCalls+= [pscustomobject]@{Query=$Query.Clone();Auth=$AuthScheme}
        $total=3; $page=[int]$Query.p; $items=@()
        if ($script:IssueMode -eq 'EMPTY') { $total=0 }
        if ($script:IssueMode -eq 'LIMIT') { $total=10001 }
        if ($script:IssueMode -eq 'CHANGED' -and $page -gt 1) { $total=4 }
        for ($i=($page-1)*2; $i -lt [Math]::Min($page*2,3); $i++) {
            $items+= [pscustomobject]@{key="issue-$i";project='team:app';component='team:app:src/A.java';rule='java:S1';
                severity='CRITICAL';status='OPEN';message='Confira este ponto';line=12;impacts=@()}
        }
        if ($script:IssueMode -eq 'EMPTY' -or ($script:IssueMode -eq 'SHORT' -and $page -gt 1)) { $items=@() }
        if ($script:IssueMode -eq 'OTHER') { $items[0].project='other' }
        if ($script:IssueMode -eq 'DUPLICATE' -and $page -gt 1) { $items[0].key='issue-0' }
        if ($script:IssueMode -eq 'BAD_KEY') { $items[0].key='' }
        $paging=[pscustomobject]@{pageIndex=$page;pageSize=2;total=$total}
        if ($script:IssueMode -eq 'BAD_PAGE') { $paging.pageIndex=9 }
        [pscustomobject]@{paging=$paging;issues=$items;components=@([pscustomobject]@{key='team:app:src/A.java';path='src/A.java'})}
    }
}
$r=& $module { Get-HarnessSonarIssues 'https://sonar.example' 'team:app' 'develop' -AuthScheme Basic -PageSize 2 }
Assert ($r.Status -eq 'COMPLETE' -and $r.Issues.Count -eq 3 -and $r.Issues[2].key -eq 'issue-2') 'Paginacao incompleta.'
Assert ($r.Issues[0].path -eq 'src/A.java' -and $r.Issues[0].line -eq 12 -and $r.Issues[0].severity -eq 'CRITICAL') 'Evidencia de corretiva perdida.'
$calls=@(& $module { $script:IssueCalls })
Assert ($calls.Count -eq 2 -and $calls[1].Query.branch -eq 'develop' -and $calls[1].Auth -eq 'Basic' -and $calls[0].Query.resolved -eq 'false') 'Escopo ou autenticacao nao propagado.'
foreach ($mode in @('LIMIT','CHANGED','SHORT','OTHER','DUPLICATE','BAD_KEY','BAD_PAGE')) {
    & $module { param($m) $script:IssueMode=$m } $mode
    $failed=$false
    try { $null=& $module { Get-HarnessSonarIssues 'https://sonar.example' 'team:app' 'develop' -PageSize 2 } }
    catch { $failed=$true }
    Assert $failed "Resposta incorreta aceita: $mode"
}
& $module { $script:IssueMode='EMPTY' }
$empty=& $module { Get-HarnessSonarIssues 'https://sonar.example' 'team:app' '' -PageSize 2 }
Assert ($empty.Status -eq 'COMPLETE' -and $empty.Issues.Count -eq 0) 'Zero issues nao reconhecido.'
Write-Output 'PASS: issues paginadas, origem, autenticacao, localizacao e respostas inconsistentes.'
