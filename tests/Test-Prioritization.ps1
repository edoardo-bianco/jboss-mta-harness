#requires -Version 5.1
$ErrorActionPreference='Stop'; Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'PrioritizationFixture.ps1')
$f=New-Fixture 6
$project=$f.Projects[0]
$original=[IO.File]::ReadAllText($project.MigrationPath)
$text=$original.Replace('| java::mandatory-1 | Problema 1 | mandatory | 1 | PRESENTE | A DEFINIR | NAO ANALISADA |',
    '| java::mandatory-1 | Problema 1 | mandatory | 1 | PRESENTE | ADIAR | NAO ANALISADA |')
[IO.File]::WriteAllText($project.MigrationPath,$text)
$p=New-HarnessPrioritizationContext $f.Context -Percentage 50 -Category mandatory
Assert ($p.InitialTotal -eq 5 -and $p.SliceSize -eq 3) 'Decisao humana exclui issue da base inicial.'
Assert ([IO.File]::ReadAllText($project.MigrationPath) -ceq $text) 'Preparo nao altera decisoes.'
$null=Complete-Slice $f $p
$text=$text.Replace('| A DEFINIR | NAO ANALISADA |','| ADIAR | NAO ANALISADA |')
[IO.File]::WriteAllText($project.MigrationPath,$text)
$next=New-HarnessPrioritizationContext $f.Context -Percentage 50 -Category mandatory -Mode Continue
Assert ($next.InitialTotal -eq 5 -and $next.Status -eq 'EXHAUSTED' -and (Read-Result $next).AnalyzedIssues.Count -eq 3) 'Retirada humana nao muda denominador nem inventa cobertura.'
$serialized=[IO.File]::ReadAllText($next.ContextPath)
foreach ($forbidden in @('RequestId','SequenceId','Previous','Sha256','Snapshot','IncidentEvidence','Consolidated')) {
    Assert (-not $serialized.Contains($forbidden)) ('Estado nao deve conter '+$forbidden)
}
$prompt=[IO.File]::ReadAllText($p.PromptPath)
Assert ($prompt -match '(?m)^agent: devsquad' -and $prompt.Contains('35 fichas') -and $prompt.Contains($p.ContextPath.Replace('\','\\'))) 'Prompt deve encaminhar contexto corrente e consolidacao completa.'
Assert (-not (Test-Path -LiteralPath (Join-Path $f.Root '.harness/priorizacao'))) 'Nao criar raiz legada.'
$g=New-Fixture 2 @('b')
Publish-HarnessProjectFiles $g.Projects[0] @{'projeto.json'=(@{pom=$g.Projects[0].Pom;mta=@{diretorio='inexistente'}}|ConvertTo-Json)}
$missing=New-HarnessPrioritizationContext $g.Context -Percentage 10 -Category mandatory
Assert ($missing.InitialTotal -eq 0 -and $missing.Projects[0].Diagnostics.Count -gt 0) 'Origem ausente explicita lacuna sem inventar catalogo.'
$before=[IO.File]::ReadAllText($p.ContextPath)
Reject { New-HarnessPrioritizationContext $f.Context -Percentage 50 -Category mandatory -Scope ('a'*200) } 'Caminho longo deve falhar antes da escrita.'
Assert ([IO.File]::ReadAllText($p.ContextPath) -ceq $before) 'Preflight nao altera contexto existente.'
$module=Get-Module HarnessPrioritization
& $module {
    $script:originalPublisher=(Get-Command Publish-HarnessProjectFiles).ScriptBlock
    function script:Publish-HarnessProjectFiles {
        param($Project,$Files,$Expected)
        foreach ($key in $Files.Keys) {
            if ($key -like '*/contexto.json') { [IO.File]::AppendAllText((Join-Path $Project.Folder $key),' EDICAO CONCORRENTE'); break }
        }
        & $script:originalPublisher $Project $Files $Expected
    }
}
try {
    Reject { New-HarnessPrioritizationContext $f.Context -Percentage 50 -Category mandatory -Mode Recreate } 'Escrita concorrente deve impedir sobrescrita.'
    Assert ([IO.File]::ReadAllText($p.ContextPath).EndsWith('EDICAO CONCORRENTE')) 'Contribuicao externa preservada.'
} finally {
    & $module { Remove-Item function:script:Publish-HarnessProjectFiles }
    [IO.File]::WriteAllText($p.ContextPath,$before)
}
'PASS: registro humano, limites, ausencia MTA, sem recibos, prompt e conflito de publicacao.'
