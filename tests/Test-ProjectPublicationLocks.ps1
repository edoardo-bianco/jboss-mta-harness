#requires -Version 5.1
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$root=Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $root 'scripts/HarnessProject.psm1') -Force -DisableNameChecking
function Assert($value,[string]$message) { if (-not $value) { throw $message } }

# Um handle real sem FILE_SHARE_DELETE reproduz o bloqueio de diretorio do
# Windows. A liberacao transitoria ocorre na primeira IOException real, antes
# de o runtime trata-la: sem corrida com timer, sleeps ou Delete simulado.
Add-Type -TypeDefinition @'
using System;
using System.ComponentModel;
using System.IO;
using System.Runtime.ExceptionServices;
using System.Runtime.InteropServices;
using Microsoft.Win32.SafeHandles;
public sealed class PublicationDirectoryBlocker : IDisposable {
    [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)]
    private static extern SafeFileHandle CreateFile(string path, uint access,
        uint share, IntPtr security, uint creation, uint flags, IntPtr template);
    private readonly string path;
    private readonly bool releaseAfterFailure;
    private readonly SafeFileHandle handle;
    public int SharingViolations { get; private set; }
    public PublicationDirectoryBlocker(string directory, bool release) {
        path=Path.GetFullPath(directory);
        releaseAfterFailure=release;
        handle=CreateFile(path,1,3,IntPtr.Zero,3,0x02000000,IntPtr.Zero);
        if (handle.IsInvalid) throw new Win32Exception(Marshal.GetLastWin32Error());
        AppDomain.CurrentDomain.FirstChanceException += Observe;
    }
    private void Observe(object sender, FirstChanceExceptionEventArgs args) {
        Exception error=args.Exception;
        if (!(error is IOException) || (error.HResult & 0xffff)!=32 ||
            error.Message.IndexOf(path,StringComparison.OrdinalIgnoreCase)<0) return;
        SharingViolations++;
        if (releaseAfterFailure) handle.Dispose();
    }
    public void Dispose() {
        AppDomain.CurrentDomain.FirstChanceException -= Observe;
        handle.Dispose();
    }
}
'@

$area=Join-Path $root ('.harness/tests/publicacao-bloqueio-'+[guid]::NewGuid().ToString('N').Substring(0,8))
$app=Join-Path $area 'app'; $null=[IO.Directory]::CreateDirectory($app)
$pom=Join-Path $app 'pom.xml'
[IO.File]::WriteAllText($pom,'<project><artifactId>servico</artifactId></project>')
$project=Initialize-HarnessProjectStorage $area $pom
$module=Get-Module HarnessProject
$before=@{'atual/planejamento/plano.md'='plano anterior';'atual/planejamento/tarefas.md'='tarefas anteriores'}
$after=@{'atual/planejamento/plano.md'='plano publicado';'atual/planejamento/tarefas.md'='tarefas publicadas'}

function Invoke-PublicationWithDirectoryBlock {
    param([string]$Relative,[bool]$Transient)
    $state=@{Blocker=$null;Relative=$Relative;Transient=$Transient}
    & $module {
        param($State)
        $script:directoryBlockState=$State
        $script:originalDirectoryCleaner=${function:Clear-ProjectPublicationFiles}
        function script:Clear-ProjectPublicationFiles {
            param($Project)
            if (-not $script:directoryBlockState.Blocker -and (Test-Path -LiteralPath (Join-Path $Project.TemporaryPath 'publicacao'))) {
                $target=if ($script:directoryBlockState.Relative) { Join-Path $Project.TemporaryPath $script:directoryBlockState.Relative } else { $Project.TemporaryPath }
                $script:directoryBlockState.Blocker=New-Object PublicationDirectoryBlocker($target,$script:directoryBlockState.Transient)
            }
            & $script:originalDirectoryCleaner $Project
        }
    } $state
    $failure=$null
    $elapsed=[Diagnostics.Stopwatch]::StartNew()
    try { Publish-HarnessProjectFiles $project $after } catch { $failure=$_ }
    finally {
        $elapsed.Stop()
        & $module { ${function:Clear-ProjectPublicationFiles}=$script:originalDirectoryCleaner }
        if ($state.Blocker) { $state.Blocker.Dispose() }
    }
    [pscustomobject]@{Error=$failure;Blocker=$state.Blocker;Seconds=$elapsed.Elapsed.TotalSeconds}
}

# Publicacao concluida nao deve falhar por um bloqueio transitorio no material
# preparado ou no pai vazio. O caso vazio cobre Directory.Delete com um argumento.
foreach ($relative in @('publicacao/depois','')) {
    Publish-HarnessProjectFiles $project $before
    $result=Invoke-PublicationWithDirectoryBlock $relative $true
    Assert ($result.Blocker -and $result.Blocker.SharingViolations -gt 0) ('Fixture deve produzir sharing violation real em '+$relative+'; erro observado: '+$result.Error)
    Assert ($null -eq $result.Error) ('Bloqueio transitorio nao deve falhar a publicacao em '+$relative+': '+$result.Error)
    $content=Read-HarnessProjectFiles $project @('atual/planejamento/plano.md','atual/planejamento/tarefas.md')
    Assert ($content['atual/planejamento/plano.md'] -ceq 'plano publicado' -and $content['atual/planejamento/tarefas.md'] -ceq 'tarefas publicadas') 'Limpeza nao pode desfazer o conjunto publicado.'
    Assert (-not (Test-Path -LiteralPath $project.TemporaryPath)) 'Bloqueio transitorio resolvido deve terminar a limpeza.'
}

# Retomar um resquicio de limpeza (sem journal) tambem deve tolerar o bloqueio.
foreach ($relative in @('publicacao/depois','')) {
    $residue=Join-Path $project.TemporaryPath 'publicacao/depois'
    $null=[IO.Directory]::CreateDirectory($residue)
    [IO.File]::WriteAllText((Join-Path $residue 'residuo.txt'),'material da publicacao concluida')
    $target=if ($relative) { Join-Path $project.TemporaryPath $relative } else { $project.TemporaryPath }
    $blocker=New-Object PublicationDirectoryBlocker($target,$true)
    try { $content=Read-HarnessProjectFiles $project @('atual/planejamento/plano.md','atual/planejamento/tarefas.md') }
    finally { $blocker.Dispose() }
    Assert ($blocker.SharingViolations -gt 0) 'Recuperacao deve encontrar o bloqueio real.'
    Assert ($content['atual/planejamento/plano.md'] -ceq 'plano publicado' -and $content['atual/planejamento/tarefas.md'] -ceq 'tarefas publicadas') 'Retomada de limpeza deve preservar o conjunto completo.'
    Assert (-not (Test-Path -LiteralPath $project.TemporaryPath)) 'Retomada deve retirar o residuo e o pai vazio.'
}

# Bloqueio persistente continua visivel e limitado; liberar o handle permite
# retomar, sem simular sucesso nem reconstruir o journal da publicacao completa.
foreach ($relative in @('publicacao/depois','')) {
    Publish-HarnessProjectFiles $project $before
    $result=Invoke-PublicationWithDirectoryBlock $relative $false
    Assert ($result.Blocker -and $result.Blocker.SharingViolations -gt 1) 'Bloqueio persistente deve ser reencontrado nas tentativas limitadas.'
    Assert ($null -ne $result.Error -and $result.Error.Exception.Message -match 'temporarios') 'Bloqueio persistente deve informar erro e caminho.'
    Assert ($result.Seconds -lt 15) 'Bloqueio persistente nao pode esperar indefinidamente.'
    if ($relative) {
        Assert ($result.Error.Exception.Message -match 'Recuperacao pendente') 'Residuo de publicacao bloqueado deve informar recuperacao pendente.'
        Assert (Test-Path -LiteralPath (Join-Path $project.TemporaryPath $relative)) 'Falha deve preservar o residuo bloqueado.'
    }
    Assert (-not (Test-Path -LiteralPath (Join-Path $project.TemporaryPath 'publicacao/recuperacao.json'))) 'Publicacao completa nao pode voltar a ter journal de rollback.'
    Assert ([IO.File]::ReadAllText($project.PlanPath) -ceq 'plano publicado' -and [IO.File]::ReadAllText($project.TodoPath) -ceq 'tarefas publicadas') 'Bloqueio na limpeza nao deve desfazer documentos ja publicados.'
    $content=Read-HarnessProjectFiles $project @('atual/planejamento/plano.md','atual/planejamento/tarefas.md')
    Assert ($content['atual/planejamento/plano.md'] -ceq 'plano publicado' -and $content['atual/planejamento/tarefas.md'] -ceq 'tarefas publicadas') 'Liberar bloqueio deve permitir leitura do conjunto completo.'
    if (-not $relative) {
        # So o pai vazio sobreviveu; nao existe publicacao pendente para restaurar.
        # A proxima escrita deve seguir normalmente e completar sua propria limpeza.
        Publish-HarnessProjectFiles $project $after
    }
    Assert (-not (Test-Path -LiteralPath $project.TemporaryPath)) 'Retomada apos bloqueio persistente deve terminar a limpeza.'
}
'PASS: bloqueios reais transitorios e persistentes na publicacao e retomada, com documentos preservados.'
