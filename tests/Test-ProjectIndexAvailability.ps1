#requires -Version 5.1
$ErrorActionPreference='Stop'; Set-StrictMode -Version Latest
$root=Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $root 'scripts/HarnessProjectIndex.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $root 'scripts/HarnessProject.psm1') -DisableNameChecking
function Assert($value,[string]$message) { if (-not $value) { throw $message } }
function Write-File($path,$text) {
    $null=[IO.Directory]::CreateDirectory((Split-Path $path -Parent))
    [IO.File]::WriteAllText($path,$text,(New-Object Text.UTF8Encoding($false)))
}

$area=Join-Path $root ('.harness/tests/disponibilidade-'+[guid]::NewGuid().ToString('N').Substring(0,8))
$indexModule=Get-Module HarnessProjectIndex
$projectModule=Get-Module HarnessProject
function New-AvailabilityFixture([string]$Name) {
    $folder=Join-Path $area $Name
    $workspace=Join-Path $folder 'workspace'
    $external=Join-Path $folder 'mta-externo'
    $context=[pscustomobject]@{Root=$workspace;Config=[pscustomobject]@{mta=[pscustomobject]@{runsPath=$external}};Projects=@()}
    foreach ($id in @('siric-api','sem-mta')) {
        $source=Join-Path $folder ('fontes/'+$id)
        Write-File (Join-Path $source 'pom.xml') ('<project><artifactId>'+$id+'</artifactId></project>')
        $context.Projects+=@([pscustomobject]@{name=$id;path=$source})
    }
    $violations=@{
        mandatory1=@{description='Obrigatoria um';category='mandatory';incidents=@(@{},@{})}
        mandatory2=@{description='Obrigatoria dois';category='mandatory';incidents=@(@{},@{})}
        optional1=@{description='Opcional um';category='optional';incidents=@(1..176 | ForEach-Object { @{} })}
        optional2=@{description='Opcional dois';category='optional';incidents=@(1..176 | ForEach-Object { @{} })}
        optional3=@{description='Opcional tres';category='optional';incidents=@(1..176 | ForEach-Object { @{} })}
    }
    $report=Join-Path $external 'siric-api/rodada/index.html'
    $catalog=Join-Path (Split-Path $report -Parent) 'output.js'
    Write-File $report '<html>MTA sintetico siric</html>'
    $apps=@(@{artifactId='siric-api';generatedAt='2026-10-21T13:00:00Z';rulesets=@(@{name='java';violations=$violations})})
    Write-File $catalog ('window["apps"] = '+(ConvertTo-Json -InputObject $apps -Depth 10 -Compress)+';')
    $initial=New-HarnessProjectIndex $context -UpdateMigration
    $project=@($initial.Projects | Where-Object Name -EQ 'siric-api')[0]
    $migration=[IO.File]::ReadAllText($project.MigrationPath).Replace('| A DEFINIR | NAO ANALISADA |','| ANALISAR AGORA | EM ANDAMENTO |')
    $migration+=[Environment]::NewLine+'Nota humana: conferir integracao antes da corretiva.'+[Environment]::NewLine
    Publish-HarnessProjectFiles $project @{'migracao.md'=$migration}
    [pscustomobject]@{Context=$context;Project=$project;Report=$report;Catalog=$catalog;CatalogText=[IO.File]::ReadAllText($catalog);Migration=$migration}
}

function Assert-Available($Fixture,$Result,[bool]$Pending) {
    $text=[IO.File]::ReadAllText($Result.IndexPath)
    $row=@($text -split '\r?\n' | Where-Object { $_ -match '^\| \[siric-api\]' })
    Assert ($row.Count -eq 1) 'Projeto com MTA legivel deve continuar no resumo.'
    Assert ($row[0].Contains('| MTA: 5 / 532<br>Manuais: 0 / - |') -and $row[0].Contains('mandatory: 2 / 4') -and $row[0].Contains('optional: 3 / 528')) 'Falha local nao pode suprimir issues ou ocorrencias do MTA lido.'
    Assert ($row[0].Contains('siric-api/rodada/index.html') -and -not $row[0].Contains('Indisponivel')) 'Resumo deve manter o link ao relatorio original utilizavel.'
    Assert ($text.Contains('1 de 2 projetos') -and $text.Contains('5 issues / 532 ocorrencias')) 'Totais devem incluir o MTA valido e excluir somente o realmente ausente.'
    Assert ($text.Contains('| mandatory | 2 | 4 |') -and $text.Contains('| optional | 3 | 528 |')) 'Totais por categoria devem preservar o projeto com pendencia local.'
    $warnings=$Result.Warnings -join [Environment]::NewLine
    Assert ($warnings -notmatch 'siric-api: MTA indisponivel') 'Erro de publicacao nao deve ser rotulado como MTA indisponivel.'
    if ($Pending) {
        Assert ($warnings -match 'siric-api: Atualizacao local pendente' -and $row[0].Contains('Atualizacao local pendente')) 'Pendencia local deve aparecer separadamente na resposta e na linha do projeto.'
    } else {
        Assert ($warnings -notmatch 'Atualizacao local pendente' -and -not $row[0].Contains('Atualizacao local pendente')) 'Nova atualizacao concluida deve retirar o alerta local antigo da linha do projeto.'
    }
    Assert ([IO.File]::ReadAllText($Fixture.Project.MigrationPath).Contains('Nota humana: conferir integracao antes da corretiva.')) 'Nota humana deve ser preservada.'
    Assert ([IO.File]::ReadAllText($Fixture.Project.MigrationPath).Contains('| ANALISAR AGORA | EM ANDAMENTO |')) 'Escolhas e andamento humanos devem ser preservados.'
    Assert ([IO.File]::ReadAllText($Fixture.Catalog) -ceq $Fixture.CatalogText) 'Atualizar indice nao pode modificar o MTA externo.'
}

# A descoberta ja leu um MTA valido. Falhar ao salvar sua associacao nao pode
# transformar a disponibilidade do diagnostico em falha de leitura.
$fixture=New-AvailabilityFixture 'associacao'
$config=ConvertFrom-Json ([IO.File]::ReadAllText($fixture.Project.ConfigPath))
$config.mta.diretorio=$null
Publish-HarnessProjectFiles $fixture.Project @{'projeto.json'=($config | ConvertTo-Json)}
$associationBefore=[IO.File]::ReadAllText($fixture.Project.ConfigPath)
$fault=@{Count=0}
& $indexModule {
    param($Fault)
    $script:indexAvailabilityFault=$Fault
    $script:indexAvailabilityPublisher=${function:Publish-HarnessProjectFiles}
    function script:Publish-HarnessProjectFiles {
        param($Project,[Collections.IDictionary]$Files,[Collections.IDictionary]$Expected=@{},[switch]$RemoveTemporaryFiles)
        if ($Files.Contains('projeto.json')) { $script:indexAvailabilityFault.Count++; throw 'bloqueio sintetico ao publicar associacao local' }
        & $script:indexAvailabilityPublisher $Project $Files $Expected -RemoveTemporaryFiles:$RemoveTemporaryFiles
    }
} $fault
try { $result=New-HarnessProjectIndex $fixture.Context -UpdateMigration }
finally { & $indexModule { ${function:Publish-HarnessProjectFiles}=$script:indexAvailabilityPublisher } }
Assert ($fault.Count -gt 0) 'Fixture deve atingir a publicacao da associacao.'
Assert ([IO.File]::ReadAllText($fixture.Project.ConfigPath) -ceq $associationBefore) 'Associacao recusada nao pode parecer persistida.'
Assert-Available $fixture $result $true
$result=New-HarnessProjectIndex $fixture.Context -UpdateMigration
Assert-Available $fixture $result $false
Assert ((ConvertFrom-Json ([IO.File]::ReadAllText($fixture.Project.ConfigPath))).mta.diretorio) 'Retomar sem bloqueio deve publicar a associacao real.'

# Com origem explicita valida, uma falha somente nos documentos locais conserva
# os bytes anteriores, mas o indice geral ainda pode mostrar o diagnostico lido.
$fixture=New-AvailabilityFixture 'documentos'
$associationBefore=[IO.File]::ReadAllText($fixture.Project.ConfigPath)
$indexBefore=[IO.File]::ReadAllText($fixture.Project.IndexPath)
$migrationBefore=[IO.File]::ReadAllText($fixture.Project.MigrationPath)
$fault=@{Count=0}
& $projectModule {
    param($Fault)
    $script:documentAvailabilityFault=$Fault
    $script:documentAvailabilityPublisher=${function:Publish-HarnessProjectFiles}
    function script:Publish-HarnessProjectFiles {
        param($Project,[Collections.IDictionary]$Files,[Collections.IDictionary]$Expected=@{},[switch]$RemoveTemporaryFiles)
        if ($Files.Contains('indice.md') -or $Files.Contains('migracao.md')) { $script:documentAvailabilityFault.Count++; throw 'bloqueio sintetico ao publicar documentos locais' }
        & $script:documentAvailabilityPublisher $Project $Files $Expected -RemoveTemporaryFiles:$RemoveTemporaryFiles
    }
} $fault
try { $result=New-HarnessProjectIndex $fixture.Context -UpdateMigration }
finally { & $projectModule { ${function:Publish-HarnessProjectFiles}=$script:documentAvailabilityPublisher } }
Assert ($fault.Count -gt 0) 'Fixture deve atingir a publicacao dos documentos.'
Assert ([IO.File]::ReadAllText($fixture.Project.ConfigPath) -ceq $associationBefore) 'Falha documental preserva associacao explicita.'
Assert ([IO.File]::ReadAllText($fixture.Project.IndexPath) -ceq $indexBefore -and [IO.File]::ReadAllText($fixture.Project.MigrationPath) -ceq $migrationBefore) 'Publicacao recusada deve preservar documentos anteriores.'
Assert-Available $fixture $result $true
$result=New-HarnessProjectIndex $fixture.Context -UpdateMigration
Assert-Available $fixture $result $false

# Resquicio de limpeza SEM journal: os documentos foram publicados por inteiro.
# Um handle real do Windows impede remover depois, sem impedir ler o MTA externo.
Add-Type -TypeDefinition @'
using System;
using System.ComponentModel;
using System.Runtime.InteropServices;
using Microsoft.Win32.SafeHandles;
public sealed class IndexAvailabilityDirectoryBlocker : IDisposable {
    [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)]
    private static extern SafeFileHandle CreateFile(string path, uint access,
        uint share, IntPtr security, uint creation, uint flags, IntPtr template);
    private readonly SafeFileHandle handle;
    public IndexAvailabilityDirectoryBlocker(string path) {
        handle=CreateFile(path,1,3,IntPtr.Zero,3,0x02000000,IntPtr.Zero);
        if (handle.IsInvalid) throw new Win32Exception(Marshal.GetLastWin32Error());
    }
    public void Dispose() { handle.Dispose(); }
}
'@
$fixture=New-AvailabilityFixture 'limpeza'
$associationBefore=[IO.File]::ReadAllText($fixture.Project.ConfigPath)
$migrationBefore=[IO.File]::ReadAllText($fixture.Project.MigrationPath)
$residue=Join-Path $fixture.Project.TemporaryPath 'publicacao/depois'
Write-File (Join-Path $residue 'resto.txt') 'residuo apos publicacao concluida'
$blocker=New-Object IndexAvailabilityDirectoryBlocker($residue)
try {
    $result=New-HarnessProjectIndex $fixture.Context -UpdateMigration
    Assert-Available $fixture $result $true
    Assert (Test-Path -LiteralPath $residue) 'Bloqueio persistente deve preservar o diretorio em uso.'
    Assert (-not (Test-Path -LiteralPath (Join-Path $fixture.Project.TemporaryPath 'publicacao/recuperacao.json'))) 'Residuo de limpeza nao deve inventar journal de rollback.'
    Assert ([IO.File]::ReadAllText($fixture.Project.ConfigPath) -ceq $associationBefore -and [IO.File]::ReadAllText($fixture.Project.MigrationPath) -ceq $migrationBefore) 'Leitura durante limpeza bloqueada preserva associacao e registro.'
} finally { $blocker.Dispose() }
$result=New-HarnessProjectIndex $fixture.Context -UpdateMigration
Assert-Available $fixture $result $false
Assert (-not (Test-Path -LiteralPath $fixture.Project.TemporaryPath)) 'Atualizacao posterior deve completar a limpeza liberada.'

# Origem explicita ausente/corrompida continua sendo falha de MTA. O relatorio
# valido sob runsPath nao autoriza trocar a escolha nem ocultar a lacuna.
foreach ($case in @('ausente','corrompido')) {
    $fixture=New-AvailabilityFixture $case
    $explicit=Join-Path (Split-Path $fixture.Context.Root -Parent) 'origem-escolhida'
    if ($case -eq 'corrompido') {
        Write-File (Join-Path $explicit 'index.html') '<html>Relatorio explicito corrompido</html>'
        Write-File (Join-Path $explicit 'output.js') 'window["apps"] = [{ invalido;'
    }
    $config=ConvertFrom-Json ([IO.File]::ReadAllText($fixture.Project.ConfigPath))
    $config.mta.diretorio=$explicit
    Publish-HarnessProjectFiles $fixture.Project @{'projeto.json'=($config | ConvertTo-Json)}
    $associationBefore=[IO.File]::ReadAllText($fixture.Project.ConfigPath)
    $result=New-HarnessProjectIndex $fixture.Context -UpdateMigration
    $text=[IO.File]::ReadAllText($result.IndexPath)
    $row=@($text -split '\r?\n' | Where-Object { $_ -match '^\| \[siric-api\]' })
    Assert ($row.Count -eq 1 -and $row[0].Contains('| Indisponivel | MTA: -<br>Manuais: 0 / - |')) 'MTA realmente ausente ou corrompido deve ficar indisponivel.'
    Assert ($text.Contains('0 de 2 projetos') -and $text.Contains('Totais conhecidos: indisponiveis.')) 'Nao contar MTA alternativo quando a origem escolhida falhou.'
    Assert (($result.Warnings -join ' ') -match 'siric-api: MTA indisponivel' -and ($result.Warnings -join ' ') -notmatch 'Atualizacao local pendente') 'Distinguir falha real da fonte de falha da atualizacao local.'
    Assert ([IO.File]::ReadAllText($fixture.Project.ConfigPath) -ceq $associationBefore) 'Indice nao pode substituir a origem explicita invalida.'
    Assert ([IO.File]::ReadAllText($fixture.Catalog) -ceq $fixture.CatalogText) 'Origem alternativa deve permanecer intacta.'
}

# Interromper uma publicacao real depois de trocar projeto.json: permanece um
# journal valido e o registro ainda e o anterior. O indice precisa recuperar o
# conjunto antes de usar a associacao parcialmente publicada.
function Start-InterruptedAssociationPublication($Fixture) {
    $child=Join-Path (Split-Path $Fixture.Context.Root -Parent) 'interromper-associacao.ps1'
    Write-File $child @'
param($ModulePath,$Workspace,$Pom,$UncommittedOrigin)
$ErrorActionPreference='Stop'
Import-Module $ModulePath -Force -DisableNameChecking
$project=Get-HarnessProjectStorage $Workspace $Pom
$config=ConvertFrom-Json ([IO.File]::ReadAllText($project.ConfigPath))
$config.mta.diretorio=$UncommittedOrigin
& (Get-Module HarnessProject) {
    $script:availabilityOriginalWriter=${function:Write-ProjectPublishedFile}
    function script:Write-ProjectPublishedFile {
        param($Source,$Destination)
        & $script:availabilityOriginalWriter $Source $Destination
        [Environment]::Exit(84)
    }
}
Publish-HarnessProjectFiles $project ([ordered]@{
    'projeto.json'=($config | ConvertTo-Json)
    'migracao.md'='# Registro da publicacao que nao terminou'
})
'@
    $uncommitted=Join-Path (Split-Path $Fixture.Context.Root -Parent) 'origem-nao-publicada'
    & powershell.exe -NoProfile -NonInteractive -File $child (Join-Path $root 'scripts/HarnessProject.psm1') $Fixture.Context.Root $Fixture.Project.Pom $uncommitted
    Assert ($LASTEXITCODE -eq 84) 'Subprocesso deve interromper a publicacao depois da primeira escrita real.'
    Assert (Test-Path -LiteralPath (Join-Path $Fixture.Project.TemporaryPath 'publicacao/recuperacao.json')) 'Interrupcao deve deixar journal real para recuperacao.'
    Assert ((ConvertFrom-Json ([IO.File]::ReadAllText($Fixture.Project.ConfigPath))).mta.diretorio -eq $uncommitted) 'Fixture deve expor associacao parcialmente publicada antes da recuperacao.'
}
function Get-AvailabilityTreeBytes([string]$Path) {
    (@(Get-ChildItem -LiteralPath $Path -Recurse -File | Sort-Object FullName | ForEach-Object {
        $_.FullName.Substring($Path.Length)+':'+[Convert]::ToBase64String([IO.File]::ReadAllBytes($_.FullName))
    }) -join [Environment]::NewLine)
}
$fixture=New-AvailabilityFixture 'journal-recuperavel'
$associationBefore=[IO.File]::ReadAllText($fixture.Project.ConfigPath)
Start-InterruptedAssociationPublication $fixture
$result=New-HarnessProjectIndex $fixture.Context -UpdateMigration
Assert-Available $fixture $result $false
Assert ([IO.File]::ReadAllText($fixture.Project.ConfigPath) -ceq $associationBefore) 'Indice deve recuperar associacao completa antes de consultar a origem MTA.'
Assert (-not (Test-Path -LiteralPath $fixture.Project.TemporaryPath)) 'Recuperacao concluida deve retirar journal e material transitorio.'
Assert (-not [IO.File]::ReadAllText($fixture.Project.MigrationPath).Contains('Registro da publicacao que nao terminou')) 'Registro incompleto nao pode substituir o anterior.'

# Conflito com edicao humana impede a recuperacao inteira. A falha nao pode ser
# rebaixada a alerta local enquanto o indice usa uma associacao intermediaria.
$fixture=New-AvailabilityFixture 'journal-conflitante'
Start-InterruptedAssociationPublication $fixture
Write-File $fixture.Project.MigrationPath ($fixture.Migration+[Environment]::NewLine+'Edicao humana concorrente: preservar este texto.')
$bytesBefore=Get-AvailabilityTreeBytes $fixture.Context.Root
$failure=$null
try { $null=New-HarnessProjectIndex $fixture.Context -UpdateMigration } catch { $failure=$_ }
Assert ($failure -and $failure.Exception.Message -match 'Edicao concorrente durante recuperacao') 'Journal conflitante deve interromper o indice com erro explicito de recuperacao.'
Assert ((Get-AvailabilityTreeBytes $fixture.Context.Root) -ceq $bytesBefore) 'Conflito deve preservar todos os documentos, arquivos de recuperacao e journal byte a byte.'
Assert ([IO.File]::ReadAllText($fixture.Catalog) -ceq $fixture.CatalogText) 'Recuperacao recusada nao altera o MTA externo.'

# A origem antiga ganha uma issue depois da baseline. Um humano muda a origem
# depois de ela ser lida, imediatamente antes de publicar os documentos locais.
# O registro deve permanecer identico, sem incorporar a issue da leitura antiga.
$fixture=New-AvailabilityFixture 'associacao-concorrente'
$migrationBefore=[IO.File]::ReadAllText($fixture.Project.MigrationPath)
$indexBefore=[IO.File]::ReadAllText($fixture.Project.IndexPath)
$changedCatalog=$fixture.CatalogText.Replace('"mandatory1":','"obsoleta":{"description":"Issue descoberta antes da troca","category":"mandatory","incidents":[{}]},"mandatory1":')
Assert ($changedCatalog -cne $fixture.CatalogText) 'Fixture deve acrescentar issue inedita somente a origem antiga.'
Write-File $fixture.Catalog $changedCatalog
$newOrigin=Join-Path (Split-Path $fixture.Context.Root -Parent) 'nova-origem-escolhida'
Write-File (Join-Path $newOrigin 'index.html') '<html>Nova escolha explicita</html>'
Write-File (Join-Path $newOrigin 'output.js') 'window["apps"] = [{"artifactId":"siric-api","generatedAt":"2026-10-22T13:00:00Z","rulesets":[{"name":"java","violations":{"nova":{"description":"Issue da nova origem","category":"optional","incidents":[{},{}]}}}]}];'
$config=ConvertFrom-Json ([IO.File]::ReadAllText($fixture.Project.ConfigPath))
$config.mta.diretorio=$newOrigin
$race=@{Count=0;Association=($config | ConvertTo-Json);SawOldIssue=$false}
& $indexModule {
    param($Race)
    $script:availabilityAssociationRace=$Race
    $script:availabilityOriginalDocumentUpdate=${function:Update-HarnessProjectDocuments}
    $script:availabilityRacePublisher=${function:Publish-HarnessProjectFiles}
    function script:Update-HarnessProjectDocuments {
        param($Project,$Mta,[switch]$UpdateIssues,[string[]]$Warnings=@(),[Collections.IDictionary]$Expected=@{})
        if ($Project.Name -eq 'siric-api' -and $script:availabilityAssociationRace.Count -eq 0) {
            $script:availabilityAssociationRace.Count++
            $script:availabilityAssociationRace.SawOldIssue=@($Mta.Issues | Where-Object Id -EQ 'java::obsoleta').Count -eq 1
            & $script:availabilityRacePublisher $Project @{'projeto.json'=$script:availabilityAssociationRace.Association}
        }
        & $script:availabilityOriginalDocumentUpdate @PSBoundParameters
    }
} $race
try { $result=New-HarnessProjectIndex $fixture.Context -UpdateMigration }
finally { & $indexModule { ${function:Update-HarnessProjectDocuments}=$script:availabilityOriginalDocumentUpdate } }
Assert ($race.Count -eq 1 -and $race.SawOldIssue) 'Troca de associacao deve ocorrer depois de ler a issue da origem antiga.'
Assert ([IO.File]::ReadAllText($fixture.Project.ConfigPath) -ceq $race.Association) 'Atualizacao nao pode desfazer a nova escolha humana de origem.'
Assert ([IO.File]::ReadAllText($fixture.Project.MigrationPath) -ceq $migrationBefore -and [IO.File]::ReadAllText($fixture.Project.IndexPath) -ceq $indexBefore) 'Mudanca concorrente da origem deve impedir publicacao de documentos derivados da leitura antiga.'
Assert (-not [IO.File]::ReadAllText($fixture.Project.MigrationPath).Contains('java::obsoleta')) 'Issue da origem superada nao pode ser inserida no registro.'
Assert (($result.Warnings -join ' ') -match 'siric-api: Atualizacao local pendente') 'Concorrencia da associacao deve ficar visivel como pendencia local.'
$summary=[IO.File]::ReadAllText($result.IndexPath)
$row=@($summary -split '\r?\n' | Where-Object { $_ -match '^\| \[siric-api\]' })
Assert ($row.Count -eq 1 -and $row[0].Contains('| MTA: 6 / 533<br>Manuais: 0 / - |') -and $row[0].Contains('siric-api/rodada/index.html') -and $row[0].Contains('Atualizacao local pendente')) 'Resumo deve identificar a leitura efetivamente realizada e sua pendencia de sincronizacao local.'
Assert (($result.Warnings -join ' ') -notmatch 'siric-api: MTA indisponivel') 'Troca concorrente nao torna invalido o diagnostico ja lido.'
Assert ([IO.File]::ReadAllText($fixture.Catalog) -ceq $changedCatalog) 'Protecao da associacao nao altera a origem externa antiga.'
$result=New-HarnessProjectIndex $fixture.Context -UpdateMigration
Assert (($result.Warnings -join ' ') -notmatch 'Atualizacao local pendente') 'Nova leitura com escolha atual deve permitir retomar documentos.'
Assert ([IO.File]::ReadAllText($fixture.Project.MigrationPath).Contains('java::nova') -and -not [IO.File]::ReadAllText($fixture.Project.MigrationPath).Contains('java::obsoleta')) 'Retomada deve usar somente a origem escolhida, sem inserir issue da leitura rejeitada.'
'PASS: MTA utilizavel contado apesar de falha local, retomada de journal e protecao contra conflitos e associacao concorrente.'
