#requires -Version 5.1
[CmdletBinding()]
param(
    [string]$ConfigPath,[string]$WorkspacePath,
    [ValidateSet('Export','Import')][string]$Action,
    [string]$ContextPath,[string]$PackagePath,[string]$SourceMapPath,
    [switch]$Interactive,[switch]$Preview,
    [ValidateSet('Text','Json')][string]$OutputFormat='Text'
)
$ErrorActionPreference='Stop'
try {
    if ($Interactive -and $OutputFormat -eq 'Json') { throw 'Json exige escolhas explicitas, sem Interactive.' }
    Import-Module (Join-Path $PSScriptRoot 'HarnessTransfer.psm1') -Force -DisableNameChecking
    Import-Module (Join-Path $PSScriptRoot 'Harness.psm1') -DisableNameChecking
    $root=Split-Path -Parent $PSScriptRoot
    if (-not $ConfigPath) { $ConfigPath=Join-Path $root 'config/harness.local.json' }
    $context=Read-HarnessConfig $ConfigPath $root -WorkspacePath $WorkspacePath -SkipMigrationInitialization
    if (-not $Action -and $Interactive) {
        Write-Host '1. Exportar analise concluida ou planejamento por issue'
        Write-Host '2. Importar pacote e associar projetos locais'
        $answer=Read-Host 'Numero (q/Enter cancela)'
        if ($answer -notin @('1','2')) { Write-Host 'Compartilhamento cancelado.'; exit 0 }
        $Action=if ($answer -eq '1') { 'Export' } else { 'Import' }
    }
    if (-not $Action) { throw 'Informe Action Export ou Import.' }
    if ($Action -eq 'Export' -and -not $ContextPath -and $Interactive) {
        $items=@(Get-HarnessTransferContexts $context)
        if (-not $items.Count) { throw 'Nenhuma analise concluida ou proposta por issue encontrada.' }
        for ($i=0;$i -lt $items.Count;$i++) { Write-Host ("{0}. {1} | {2} | {3}" -f ($i+1),$items[$i].Kind,$items[$i].Label,$items[$i].RequestId) }
        $answer=Read-Host 'Contexto a exportar (q/Enter cancela)'; $choice=0
        if (-not [int]::TryParse($answer,[ref]$choice) -or $choice -lt 1 -or $choice -gt $items.Count) { Write-Host 'Compartilhamento cancelado.'; exit 0 }
        $ContextPath=$items[$choice-1].ContextPath
        Write-Host 'Analise inclui diagnostico MTA/snapshot/regras; planejamento inclui somente o recorte consolidado e sua cadeia.'
    }
    if (-not $PackagePath -and $Interactive) {
        $PackagePath=Read-Host 'Caminho completo do ZIP (destino novo para exportar; arquivo recebido para importar; q cancela)'
        if (-not $PackagePath -or $PackagePath -eq 'q') { Write-Host 'Compartilhamento cancelado.'; exit 0 }
    }
    if (-not $PackagePath) { throw 'Informe PackagePath.' }
    if ($Action -eq 'Export') {
        if (-not $ContextPath) { throw 'Informe ContextPath ou use Interactive.' }
        if ($Preview) { throw 'Preview esta disponivel para importacao. Exportar cria um ZIP novo sem alterar as origens.' }
        $result=Export-HarnessContextPackage $context $ContextPath $PackagePath -WarningVariable diagnostics -WarningAction SilentlyContinue
    } else {
        $mapping=@{}
        if ($SourceMapPath) {
            $data=Get-Content -LiteralPath $SourceMapPath -Raw -Encoding UTF8 | ConvertFrom-Json
            foreach ($property in $data.PSObject.Properties) { $mapping[$property.Name]=[string]$property.Value }
        } elseif ($Interactive) {
            $manifest=Read-HarnessContextPackage $PackagePath
            Write-Host ("Pacote: {0} | Etapa: {1} | Arquivos: {2}" -f $manifest.Kind,$manifest.Stage,$manifest.Files.Count)
            foreach ($source in $manifest.Projects) {
                Write-Host ("Origem: {0} | {1}" -f $source.Project,$source.Source)
                for ($i=0;$i -lt $context.Projects.Count;$i++) { Write-Host ("{0}. {1} | {2}" -f ($i+1),$context.Projects[$i].label,$context.Projects[$i].path) }
                $answer=Read-Host 'Projeto local correspondente (q/Enter cancela)'; $choice=0
                if (-not [int]::TryParse($answer,[ref]$choice) -or $choice -lt 1 -or $choice -gt $context.Projects.Count) { Write-Host 'Compartilhamento cancelado.'; exit 0 }
                $mapping[$source.Source]=$context.Projects[$choice-1].path
            }
        } else { throw 'Importacao exige SourceMapPath ou escolha Interactive.' }
        $result=Import-HarnessContextPackage $context $PackagePath $mapping -Preview:$Preview -WarningVariable diagnostics -WarningAction SilentlyContinue
    }
    $result | Add-Member NoteProperty Diagnostics @($diagnostics | ForEach-Object { [string]$_ }) -Force
    if ($OutputFormat -eq 'Json') { $result | ConvertTo-Json -Depth 12 }
    else {
        $result | Format-List | Out-Host
        if ($Action -eq 'Import' -and -not $Preview) { Write-Host 'Originais preservados. Use o orientador com ContextPath; confira indice, codigo e alcance do GO antes de executar.' }
    }
    exit 0
} catch {
    if ($OutputFormat -eq 'Json') { @{Status='FAILED';Error=$_.Exception.Message} | ConvertTo-Json }
    else { Write-Host ('ERRO no compartilhamento: '+$_.Exception.Message) -ForegroundColor Red }
    exit 1
}
