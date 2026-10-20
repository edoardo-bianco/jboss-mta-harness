# Replicar na máquina de trabalho: EAP 7.4 + Update 11 + verificação do manifesto

**Origem:** procedimento executado na máquina de casa em 20/10/2026 (guia operacional, seções 5 a 7).
**Resultado esperado:** EAP `7.4.11.GA`, cumulativo `jboss-eap-7.4.11.CP` e `verificar-manifesto-eap74.ps1` com `FALHA=0`.

Execute os blocos na ordem, no PowerShell (de preferência `pwsh` 7). Se a máquina usar outros caminhos, altere **somente o bloco 1**.

## 0. Arquivos a levar

| Arquivo | Origem (máquina de casa) | SHA-256 |
|---|---|---|
| JDK 8 (se não houver lá) | `C:\desenvolvimento\java\OpenJDK8U-jdk_x64_windows_hotspot_8u504b01.zip` | `ea43d46ede95b51e44a12c66711706cddc762e0a766c54bccea18954e902b2aa` |
| EAP 7.4.0 (se ainda não instalado) | `C:\desenvolvimento\instaladores\eap\jboss-eap-7.4.0.zip` | `5f1f0b7a389dedcd6f91ea3c8c6c9b723e9e8609bdf5720d4088e5469d46ad3a` |
| Update 11 | `C:\desenvolvimento\instaladores\eap\jboss-eap-7.4.11-patch.zip` | `ad7f67de6b2fbaee357ad50a9832e9f62029a3cae4d1688e214f3cb46143cbe5` |
| Manifesto + script | esta pasta: `manifesto-ambiente-local-jboss-eap-7.4.yaml` e `verificar-manifesto-eap74.ps1` | — |

Os ZIPs também podem ser baixados de novo no portal Red Hat (Downloads → JBoss EAP → 7.4 → Patches → Update 11). O bloco 2 confirma que são idênticos.

## 1. Sessão (Terminal A e Terminal B)

```powershell
$ErrorActionPreference = 'Stop'
# ---- Ajuste somente aqui, se os caminhos forem outros ----
$Base         = 'C:\desenvolvimento'
$Eap74        = "$Base\servidores\jboss-eap-7.4"
$Jdk8         = "$Base\java\jdk8u504-b01"
$Instaladores = "$Base\instaladores\eap"
$Backups      = "$Base\backups"
$Verificacao  = "$Base\ferramentas\manifesto-eap74"
# ----------------------------------------------------------
$Patch        = "$Instaladores\jboss-eap-7.4.11-patch.zip"
$Cli74        = "$Eap74\bin\jboss-cli.bat"
$Controller74 = '127.0.0.1:10090'

$env:JAVA_HOME  = $Jdk8
$env:JAVA       = "$Jdk8\bin\java.exe"
$env:JBOSS_HOME = $Eap74
$env:NOPAUSE    = 'true'
$env:PATH       = "$Jdk8\bin;$env:PATH"
```

## 2. Conferir os pacotes (Terminal B)

```powershell
$Esperados = [ordered]@{
    "$Base\java\OpenJDK8U-jdk_x64_windows_hotspot_8u504b01.zip" = 'ea43d46ede95b51e44a12c66711706cddc762e0a766c54bccea18954e902b2aa'
    "$Instaladores\jboss-eap-7.4.0.zip"                         = '5f1f0b7a389dedcd6f91ea3c8c6c9b723e9e8609bdf5720d4088e5469d46ad3a'
    "$Instaladores\jboss-eap-7.4.11-patch.zip"                  = 'ad7f67de6b2fbaee357ad50a9832e9f62029a3cae4d1688e214f3cb46143cbe5'
}
foreach ($arq in $Esperados.Keys) {
    if (-not (Test-Path -LiteralPath $arq)) { Write-Host "AUSENTE  $arq"; continue }
    $hash = (Get-FileHash -LiteralPath $arq -Algorithm SHA256).Hash
    if ($hash -eq $Esperados[$arq]) { Write-Host "OK       $arq" } else { Write-Host "DIVERGE  $arq" }
}
```

Prossiga só com **OK** nos arquivos que você vai usar. AUSENTE é aceitável para o JDK ou o EAP 7.4.0 se eles já estiverem instalados.

## 3. JDK 8 e EAP 7.4.0, se ainda não existirem (Terminal B)

```powershell
if (-not (Test-Path -LiteralPath "$Jdk8\bin\java.exe")) {
    Expand-Archive -LiteralPath "$Base\java\OpenJDK8U-jdk_x64_windows_hotspot_8u504b01.zip" -DestinationPath (Split-Path $Jdk8 -Parent)
}
if (-not (Test-Path -LiteralPath $Eap74)) {
    Expand-Archive -LiteralPath "$Instaladores\jboss-eap-7.4.0.zip" -DestinationPath (Split-Path $Eap74 -Parent)
}
& $env:JAVA -version
Get-Content "$Eap74\version.txt"
```

Esperado: `1.8.0_504` e `Version 7.4.0.GA`. Os ZIPs extraem para as pastas `jdk8u504-b01` e `jboss-eap-7.4`, por isso `$Jdk8` e `$Eap74` precisam terminar com esses nomes.

**Se aparecer `7.4.11.GA`, o patch já está aplicado:** pule para o passo 7.

## 4. Backup com o servidor parado (Terminal B)

```powershell
if (Get-NetTCPConnection -LocalPort 10090,8180 -State Listen -ErrorAction SilentlyContinue) {
    throw 'Ha um servidor escutando em 10090/8180. Desligue-o antes do backup.'
}
New-Item -ItemType Directory -Path $Backups -Force | Out-Null
$Backup = Join-Path $Backups ('eap74-pre-patch-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
Copy-Item -LiteralPath $Eap74 -Destination $Backup -Recurse
$Backup
```

Anote o caminho exibido: ele vai para o manifesto no passo 7.

## 5. Terminal A: subir em modo administrativo

```powershell
& "$Eap74\bin\standalone.bat" `
    '--server-config=standalone-full.xml' `
    '--admin-only' `
    '-b=127.0.0.1' `
    '-bmanagement=127.0.0.1' `
    '-Djboss.socket.binding.port-offset=100' `
    '-Djboss.node.name=eap74-local' `
    '-Djboss.tx.node.id=eap74-local'
```

Aguarde `WFLYSRV0025` e deixe o terminal aberto.

## 6. Terminal B: aplicar o Update 11

```powershell
& $Cli74 --connect "--controller=$Controller74"
```

No CLI (ajuste o caminho do `patch apply` se for outro):

```text
:read-attribute(name=product-version)
patch info
patch apply "C:/desenvolvimento/instaladores/eap/jboss-eap-7.4.11-patch.zip"
shutdown
```

Se o `patch apply` acusar **conflito**, pare e não use `--override-all`.

Após o `shutdown`, o servidor deve reiniciar sozinho no Terminal A (foi o que aconteceu em casa). Se não reiniciar, repita o passo 5. Depois, no CLI:

```text
connect 127.0.0.1:10090
:read-attribute(name=product-version)
patch info
patch history
shutdown
```

Esperado: `7.4.11.GA`, `Cumulative patch ID: jboss-eap-7.4.11.CP` e uma entrada `cumulative` no histórico. Se o servidor subir de novo após o último `shutdown`, use `Ctrl+C` no Terminal A e responda `S`.

## 7. Verificação automatizada (Terminal B)

Instalar o módulo (responda `S` à pergunta sobre o repositório) e criar a pasta:

```powershell
Install-Module powershell-yaml -RequiredVersion 0.4.12 -Scope CurrentUser -Repository PSGallery
New-Item -ItemType Directory -Path $Verificacao -Force | Out-Null
explorer $Verificacao
```

Copie o manifesto e o script para essa pasta. Colete os valores desta máquina:

```powershell
Get-Content "$Eap74\.installation\JBoss EAP.conf"
Get-Content "$Jdk8\release" | Select-String '^(IMPLEMENTOR|FULL_VERSION|OS_ARCH|IMAGE_TYPE)='
$Backup
```

No manifesto, atualize o que for diferente nesta máquina:

- `data_verificacao`
- `ambiente_local.jboss_home` e `ambiente_local.java_home`
- `local` de cada pacote
- `evidencias_patch.backup_pre_patch` e `patch_history.applied_at`
- `jdk.*`, se o JDK for outro

Os hashes não mudam se o bloco 2 deu OK. Executar:

```powershell
& "$Verificacao\verificar-manifesto-eap74.ps1"
```

Esperado: **FALHA=0**. Antes de promover o candidato: `& "$Verificacao\verificar-manifesto-eap74.ps1" -Promocao`.

## Observações para máquina corporativa

- Se o PSGallery ou o script forem bloqueados, siga a política da empresa: repositório interno ou liberação pelo suporte. `Unblock-File` só se a política permitir. **Não usar `-ExecutionPolicy Bypass`** (guia, seção 5).
- Se o JDK aprovado for outro (por exemplo, Red Hat build of OpenJDK 8), use-o: ajuste `$Jdk8` e os campos `jdk.*` do manifesto e registre na pendência JDK-01.
- O módulo `powershell-yaml` é instalado por edição do PowerShell: instalado no `pwsh` 7, não aparece no Windows PowerShell 5.1 (e vice-versa).
