<#
.SYNOPSIS
    Confere o manifesto do ambiente local do JBoss EAP 7.4 contra a instalacao real.

.DESCRIPTION
    Somente leitura: nao inicia o servidor e nao altera arquivos.
    Confere versao e patches do EAP (.installation), perfil, JDK (arquivo release),
    hashes dos pacotes, backup pre-patch, driver Oracle (quando preenchido)
    e lista os campos PREENCHER.

    Status: OK, FALHA, AVISO (pendencia aceitavel localmente) e PULADO (ainda nao preenchido).
    Codigo de saida: 0 sem FALHA; 1 com FALHA.

    Requer o modulo powershell-yaml.

.PARAMETER Manifesto
    Caminho do manifesto YAML. Padrao: manifesto-ambiente-local-jboss-eap-7.4.yaml na pasta do script.

.PARAMETER Promocao
    Gate de promocao: campos PREENCHER e pacotes nao conferidos com o portal passam a ser FALHA.

.EXAMPLE
    .\verificar-manifesto-eap74.ps1

.EXAMPLE
    .\verificar-manifesto-eap74.ps1 -Promocao
#>
[CmdletBinding()]
param(
    [string]$Manifesto = (Join-Path $PSScriptRoot 'manifesto-ambiente-local-jboss-eap-7.4.yaml'),
    [switch]$Promocao
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not (Get-Module -ListAvailable -Name powershell-yaml)) {
    throw ('Modulo powershell-yaml nao encontrado nesta versao do PowerShell. ' +
           'Instale com: Install-Module powershell-yaml -Scope CurrentUser -Repository PSGallery')
}
Import-Module powershell-yaml

if (-not (Test-Path -LiteralPath $Manifesto)) {
    throw "Manifesto nao encontrado: $Manifesto"
}

$Resultados = New-Object System.Collections.Generic.List[object]
$StatusPendente = if ($Promocao) { 'FALHA' } else { 'AVISO' }

function Add-Resultado {
    param([string]$Status, [string]$Item, $Esperado, $Encontrado)
    $exibir = {
        param($v)
        if ([string]::IsNullOrEmpty("$v")) { '(vazio)' } else { "$v" }
    }
    $Resultados.Add([pscustomobject]@{
        Status     = $Status
        Item       = $Item
        Esperado   = & $exibir $Esperado
        Encontrado = & $exibir $Encontrado
    })
}

function Compare-Valor {
    param([string]$Item, $Esperado, $Encontrado)
    if (Test-Pendente $Esperado) {
        Add-Resultado 'PULADO' $Item $Esperado $Encontrado
    } elseif ("$Esperado" -eq "$Encontrado") {
        Add-Resultado 'OK' $Item $Esperado $Encontrado
    } else {
        Add-Resultado 'FALHA' $Item $Esperado $Encontrado
    }
}

function Test-Pendente {
    param($Valor)
    ($Valor -is [string]) -and ($Valor -match 'PREENCHER')
}

# Le arquivos chave=valor (.installation\*.conf e release do JDK).
function Read-Propriedades {
    param([string]$Caminho)
    $props = @{}
    foreach ($linha in Get-Content -LiteralPath $Caminho) {
        if ($linha -match '^\s*#' -or $linha -notmatch '=') { continue }
        $chave, $valor = $linha -split '=', 2
        $props[$chave.Trim()] = $valor.Trim().Trim('"')
    }
    $props
}

function Find-Pendentes {
    param($No, [string]$Caminho)
    if ($No -is [System.Collections.IDictionary]) {
        foreach ($chave in $No.Keys) {
            $filho = if ($Caminho) { "$Caminho.$chave" } else { "$chave" }
            Find-Pendentes $No[$chave] $filho
        }
    } elseif ($No -is [System.Collections.IList]) {
        for ($i = 0; $i -lt $No.Count; $i++) {
            Find-Pendentes $No[$i] "$Caminho[$i]"
        }
    } elseif (Test-Pendente $No) {
        $Caminho
    }
}

function Format-Hash {
    param($Valor)
    if ("$Valor" -match '^[A-Fa-f0-9]{64}$') { "$Valor".Substring(0, 16).ToLower() + '...' } else { $Valor }
}

$m = Get-Content -LiteralPath $Manifesto -Raw -Encoding UTF8 | ConvertFrom-Yaml -Ordered
$b = $m.baseline
$EapHome = $m.ambiente_local.jboss_home
$JavaHome = $m.ambiente_local.java_home

# EAP: versao, cumulativo e correcoes individuais (mesma fonte do "patch info").
$ConfInstalacao = Join-Path $EapHome '.installation\JBoss EAP.conf'
if (-not (Test-Path -LiteralPath $ConfInstalacao)) {
    Add-Resultado 'FALHA' 'eap: metadados de patch' $ConfInstalacao 'arquivo ausente'
} else {
    $inst = Read-Propriedades $ConfInstalacao
    Compare-Valor 'eap_versao_resultante' $b.eap_versao_resultante $inst['current-version']
    Compare-Valor 'cumulativo_id' $b.cumulativo_id $inst['cumulative-patch-id']
    $esperadas = (@($b.correcoes_individuais) | Where-Object { $_ } | Sort-Object) -join ','
    $instaladas = (@("$($inst['patches'])" -split ',') | Where-Object { $_ } | Sort-Object) -join ','
    Compare-Valor 'correcoes_individuais' $esperadas $instaladas
}

$VersionTxt = Join-Path $EapHome 'version.txt'
if (Test-Path -LiteralPath $VersionTxt) {
    $versao = ((Get-Content -LiteralPath $VersionTxt -Raw) -replace '(?s).*Version\s+', '').Trim()
    Compare-Valor 'version.txt' $b.eap_versao_resultante $versao
} else {
    Add-Resultado 'FALHA' 'version.txt' $b.eap_versao_resultante 'arquivo ausente'
}

$ArquivoPerfil = Join-Path $EapHome "standalone\configuration\$($b.perfil)"
if (Test-Path -LiteralPath $ArquivoPerfil) {
    Add-Resultado 'OK' 'perfil' $b.perfil 'presente'
} else {
    Add-Resultado 'FALHA' 'perfil' $b.perfil 'ausente'
}

# JDK: arquivo release na raiz do JDK.
$ReleaseJdk = Join-Path $JavaHome 'release'
if (-not (Test-Path -LiteralPath $ReleaseJdk)) {
    Add-Resultado 'FALHA' 'jdk: arquivo release' $ReleaseJdk 'ausente'
} else {
    $rel = Read-Propriedades $ReleaseJdk
    Compare-Valor 'jdk.fornecedor' $b.jdk.fornecedor $rel['IMPLEMENTOR']
    Compare-Valor 'jdk.versao' $b.jdk.versao $rel['FULL_VERSION']
    Compare-Valor 'jdk.arquitetura' $b.jdk.arquitetura $rel['OS_ARCH']
    Compare-Valor 'jdk.tipo' $b.jdk.tipo $rel['IMAGE_TYPE']
}

# Pacotes: tamanho e SHA-256 registrados.
foreach ($p in @($m.pacotes)) {
    $item = 'pacote ' + ("$($p.arquivo)" -replace '^jboss-eap-', '' -replace '\.zip$', '')
    if (-not (Test-Path -LiteralPath $p.local)) {
        Add-Resultado 'FALHA' $item $p.local 'arquivo ausente'
        continue
    }
    Compare-Valor "${item}: tamanho" $p.tamanho_bytes (Get-Item -LiteralPath $p.local).Length
    $hash = (Get-FileHash -LiteralPath $p.local -Algorithm SHA256).Hash
    if ("$($p.sha256)" -eq $hash) {
        Add-Resultado 'OK' "${item}: sha256" (Format-Hash $p.sha256) (Format-Hash $hash)
    } else {
        Add-Resultado 'FALHA' "${item}: sha256" $p.sha256 $hash.ToLower()
    }
    if ($p.conferido_com_portal -ne 'sim') {
        Add-Resultado $StatusPendente "${item}: portal" 'sim' $p.conferido_com_portal
    }
}

# Backup pre-patch: necessario enquanto a reversao puder ser usada.
$Backup = $m.evidencias_patch.backup_pre_patch
if ($Backup) {
    $NomeBackup = Split-Path -Leaf $Backup
    if (Test-Path -LiteralPath $Backup) {
        Add-Resultado 'OK' 'backup_pre_patch' $NomeBackup 'presente'
    } else {
        Add-Resultado 'AVISO' 'backup_pre_patch' $NomeBackup 'ausente'
    }
}

# Driver Oracle: conferido quando modulo, arquivo e hash estiverem preenchidos.
$ora = $b.oracle_driver
if ((Test-Pendente $ora.modulo) -or (Test-Pendente $ora.arquivo) -or (Test-Pendente $ora.sha256)) {
    Add-Resultado 'PULADO' 'oracle_driver' 'preencher na secao 9' '-'
} else {
    $slot = if ($ora.slot) { $ora.slot } else { 'main' }
    $DirModulo = Join-Path $EapHome ('modules\' + ($ora.modulo -replace '\.', '\') + "\$slot")
    $JarDriver = Join-Path $DirModulo $ora.arquivo
    if (-not (Test-Path -LiteralPath (Join-Path $DirModulo 'module.xml'))) {
        Add-Resultado 'FALHA' 'oracle_driver: module.xml' $DirModulo 'ausente'
    }
    if (Test-Path -LiteralPath $JarDriver) {
        $hash = (Get-FileHash -LiteralPath $JarDriver -Algorithm SHA256).Hash
        Compare-Valor 'oracle_driver: sha256' $ora.sha256 $hash
    } else {
        Add-Resultado 'FALHA' 'oracle_driver: arquivo' $JarDriver 'ausente'
    }
}

# Campos ainda nao preenchidos.
$Pendentes = @(Find-Pendentes $m '')
if ($Pendentes.Count -gt 0) {
    Add-Resultado $StatusPendente 'campos PREENCHER' 0 $Pendentes.Count
} else {
    Add-Resultado 'OK' 'campos PREENCHER' 0 0
}

Write-Host "Manifesto: $Manifesto"
Write-Host ("Modo: " + $(if ($Promocao) { 'promocao (PREENCHER = FALHA)' } else { 'local' }))
$Resultados | Format-Table -AutoSize -Wrap Status, Item, Esperado, Encontrado | Out-Host

if ($Pendentes.Count -gt 0) {
    Write-Host "Campos PREENCHER ($($Pendentes.Count)):"
    $Pendentes | ForEach-Object { Write-Host "  - $_" }
    Write-Host ''
}

$Contagem = foreach ($s in 'OK', 'FALHA', 'AVISO', 'PULADO') {
    "$s=" + @($Resultados | Where-Object { $_.Status -eq $s }).Count
}
Write-Host ("Resumo: " + ($Contagem -join '  '))

if (@($Resultados | Where-Object { $_.Status -eq 'FALHA' }).Count -gt 0) { exit 1 }
exit 0
