#requires -Version 5.1
$ErrorActionPreference='Stop'; Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'PlanningCurrentFixture.ps1')
$f=New-PlanningFixture 1
$p=$f.Projects[0]
$seen=New-Object 'Collections.Generic.List[string]'
$reader={param($path) $seen.Add($path); [IO.File]::ReadAllText($path)}
$reference=Get-HarnessProjectReference $f.Root $p.Pom -FileReader $reader
Assert ($reference.Folder -eq $p.Folder -and $seen.Contains($p.Pom)) 'Identidade de leitura deve reutilizar parser/paths comuns.'
$mta=Read-HarnessMtaDirectory $reference (Join-Path $f.Root 'mta-a') -FileReader $reader
Assert ($seen.Contains($mta.ReportPath) -and $seen.Contains($mta.CatalogPath)) 'Leitura MTA deve passar todos os arquivos ao leitor restrito.'
$temporary=Join-Path $p.TemporaryPath 'publicacao'
$null=[IO.Directory]::CreateDirectory($temporary)
[IO.File]::WriteAllText((Join-Path $temporary 'recuperacao.json'),'[]')
$before=Get-PlanningFixtureState $f
Reject { Enter-HarnessProjectAccess $reference -ReadOnly } 'Consulta nao pode recuperar publicacao incompleta.'
Assert ((Get-PlanningFixtureState $f) -ceq $before) 'Leitura pura alterou temporarios ou documentos.'
$errorFound=$false
try {
    Read-HarnessMtaDirectory $reference (Join-Path $f.Root 'mta-a') -FileReader {
        param($path) $failure=New-Object InvalidOperationException 'Limite de leitura'; $failure.Data['QueryCode']='LIMIT_EXCEEDED'; throw $failure
    }
} catch { $errorFound=$_.Exception.Data['QueryCode'] -eq 'LIMIT_EXCEEDED' }
Assert $errorFound 'Limite do leitor nao pode virar candidato descartado silenciosamente.'
'PASS: identidade/MTA compartilhados, leitor restrito e recuperacao recusada sem escrita.'
