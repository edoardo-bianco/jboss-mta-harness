# jboss-eap-7.4.11-patch.zip Instruções

> Registro da obtencao/aplicacao do CP11. Para outro cumulativo 7.4.XX, consulte
> [o procedimento atual e os requisitos ELS/JDK](jboss-eap7.4-configuracao/patches.md).
> Filtros e escolhas deste registro historico nao sao recomendacao do patch atual.

## baixar o patch

Pelo navegador, logado com a sua conta Red Hat:

1. Abra o link abaixo. Se pedir login, use a mesma conta Developer.
   https://access.redhat.com/jbossnetwork/restricted/listSoftware.html?downloadType=patches&product=appplatform&version=7.4
2. Confira os filtros no topo da página:
   - Product: Red Hat JBoss Enterprise Application Platform. Não escolha "XP" nem "Expansion Pack".
   - Version: 7.4. Não escolha 7.4 ELS nem 8.0.
   - Aba Patches. A aba "Releases" tem só a distribuição completa.
3. Role a lista até "Red Hat JBoss Enterprise Application Platform 7.4 Update 11", com data de maio de 2023. Os updates aparecem do mais recente para o mais antigo, então o 11 fica bem abaixo dos updates 12 a 23.
4. Clique no nome do item. A página de detalhe mostra o arquivo jboss-eap-7.4.11-patch.zip e o SHA-256. Copie o SHA-256 para usar no passo 2 das instruções anteriores.

- [Red Hat JBoss Enterprise Application Platform 7.4 Update 11](https://access.redhat.com/downloads/content/application-services/appplatform/7.4/JBEAP-7.4.11/jboss-eap-7.4.11-patch.zip)
- SHA-256 Checksum: ad7f67de6b2fbaee357ad50a9832e9f62029a3cae4d1688e214f3cb46143cbe5

To apply this update using the CLI on Windows-based systems, run the following command from JBOSS_HOME:

bin\jboss-cli.bat "patch apply path\to\jboss-eap-7.4.11-patch.zip"
These commands will apply the update to the installation that contains the CLI script. Other scenarios and use of the management console are covered in the JBoss EAP 7.4 Patching And Upgrading Guide.

[Patching and Upgrading Guide 7.4](https://docs.redhat.com/en/documentation/red_hat_jboss_enterprise_application_platform/7.4/html/patching_and_upgrading_guide/index)

5. Clique em Download now. Não baixe o "Maven Repository" nem o "Source Code" do mesmo update.

Se não conseguir seguir esse caminho, use o menu: https://access.redhat.com/downloads → Red Hat JBoss Enterprise Application Platform → Version 7.4 → aba Patches.

Depois do download, mova o arquivo para a pasta que as instruções usam:
Move-Item -LiteralPath "$HOME\Downloads\jboss-eap-7.4.11-patch.zip" -Destination 'C:\desenvolvimento\instaladores\eap\'

Se der problema:
- Acesso negado ou mensagem sobre assinatura: entre uma vez em https://developers.redhat.com e aceite os termos. Depois confira em https://access.redhat.com/management/subscriptions se aparece a Red Hat Developer Subscription for Individuals. Ela pode levar alguns minutos para aparecer.
- Update 11 não aparece: quase sempre o filtro de produto ou de versão está errado. Confira o passo 2.
- Página "We'll be back soon": é uma instabilidade do portal. Tente mais tarde.

Não consigo ver o portal pela sua sessão logada, então esse caminho segue a estrutura que o portal costuma ter, e os nomes dos botões podem estar um pouco diferentes. Se quiser, posso abrir o Chrome com você logado e procurar o arquivo junto.

## aplicar o patch

Adaptei o passo a passo das seções 5 e 7 do guia aos caminhos que encontrei na sua máquina:

- EAP 7.4: C:\desenvolvimento\servidores\jboss-eap-7.4 (versão 7.4.0.GA, parado)
- JDK 8: C:\desenvolvimento\java\jdk8u504-b01
- Pacotes: C:\desenvolvimento\instaladores\eap\ (o jboss-eap-7.4.0.zip já está lá)

Atenção: o JAVA_HOME do Windows aponta para o JDK 25, e o EAP 7.4 não roda nele. Por isso o bloco do passo 1 tem que ser executado em todo terminal que você usar.

0. Baixar

Salve jboss-eap-7.4.11-patch.zip em C:\desenvolvimento\instaladores\eap\. Copie também o SHA-256 que o portal mostra ao lado do arquivo.

1. Variáveis (Terminal A e Terminal B)

$ErrorActionPreference = 'Stop'
$Eap74        = 'C:\desenvolvimento\servidores\jboss-eap-7.4'
$Cli74        = Join-Path $Eap74 'bin\jboss-cli.bat'
$Controller74 = '127.0.0.1:10090'
$Jdk8         = 'C:\desenvolvimento\java\jdk8u504-b01'
$Patch        = 'C:\desenvolvimento\instaladores\eap\jboss-eap-7.4.11-patch.zip'
$Backups      = 'C:\desenvolvimento\backups'

$env:JAVA_HOME  = $Jdk8
$env:JAVA       = Join-Path $Jdk8 'bin\java.exe'
$env:JBOSS_HOME = $Eap74
$env:NOPAUSE    = 'true'
$env:PATH       = "$Jdk8\bin;$env:PATH"

& $env:JAVA -version
A saída tem que mostrar 1.8.0_504.

2. Conferir o pacote (Terminal B)

$ShaEsperado = 'ad7f67de6b2fbaee357ad50a9832e9f62029a3cae4d1688e214f3cb46143cbe5'
$ShaObtido = (Get-FileHash -LiteralPath $Patch -Algorithm SHA256).Hash
if ($ShaObtido -ne $ShaEsperado) { throw 'Checksum divergente. Nao aplicar o patch.' }
$ShaObtido

3. Backup com o servidor parado (Terminal B)

if (Get-NetTCPConnection -LocalPort 10090,8180 -State Listen -ErrorAction SilentlyContinue) {
    throw 'Ha um servidor escutando em 10090/8180. Desligue-o antes do backup.'
}
New-Item -ItemType Directory -Path $Backups -Force | Out-Null
$Backup = Join-Path $Backups ('eap74-pre-patch-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
Copy-Item -LiteralPath $Eap74 -Destination $Backup -Recurse
$Backup

4. Terminal A: subir só a administração

& "$Eap74\bin\standalone.bat" `
    '--server-config=standalone-full.xml' `
    '--admin-only' `
    '-b=127.0.0.1' `
    '-bmanagement=127.0.0.1' `
    '-Djboss.socket.binding.port-offset=100' `
    '-Djboss.node.name=eap74-local' `
    '-Djboss.tx.node.id=eap74-local'
Espere a mensagem WFLYSRV0025 (servidor iniciado) e deixe esse terminal aberto.

5. Terminal B: aplicar o Update 11

& $Cli74 --connect "--controller=$Controller74"
Dentro do CLI, confira primeiro:
:read-attribute(name=product-version)
/core-service=server-environment:read-attribute(name=home-dir)
patch info
patch history
O resultado esperado é 7.4.0.GA, com home-dir C:\desenvolvimento\servidores\jboss-eap-7.4 e nenhum cumulativo aplicado. Estando tudo certo:
patch apply "C:/desenvolvimento/instaladores/eap/jboss-eap-7.4.11-patch.zip"
Se der "outcome" => "success", desligue:
shutdown
Se o comando acusar conflito, pare nesse ponto e não use --override-all. Me mande a mensagem para diagnosticarmos juntos.

5.1 se o servidor reiniciar sozinho

O patch foi aplicado com sucesso. Confirmei nos arquivos da instalação:

- version.txt → 7.4.11.GA
- .installation\JBoss EAP.conf → cumulative-patch-id=jboss-eap-7.4.11.CP
- server.log → WFLYSRV0049: Inicializando JBoss EAP 7.4.11.GA (WildFly Core 15.0.26...)

O servidor já está rodando de novo. Depois do shutdown, o standalone.bat reiniciou o servidor sozinho em menos de 1 segundo, com os mesmos parâmetros: standalone-full.xml, --admin-only e offset 100. Ele já está no 7.4.11 e escutando em 127.0.0.1:10090. Então você não precisa rodar de novo o comando do Terminal A.

Agora, no Terminal B

O CLI está em [disconnected /]. Reconecte nele mesmo:

connect 127.0.0.1:10090

Depois rode:

:read-attribute(name=product-version)
patch info
patch history

O resultado esperado é:
- product-version → 7.4.11.GA
- patch info → cumulative-patch-id: jboss-eap-7.4.11.CP
- patch history → uma entrada do tipo cumulative com o ID jboss-eap-7.4.11.CP e a data de hoje

Copie essas saídas para o manifesto, junto com o SHA-256 do ZIP e o caminho do backup (passo 7). Depois desligue:

shutdown

Desta vez o servidor deve parar de verdade. Se ele subir sozinho de novo no Terminal A, pressione Ctrl+C nesse terminal e responda S à pergunta de encerrar o lote.

Com isso a seção 7 está concluída. A seção 7.4 (correção individual) não se aplica ao 7.4.11, como o próprio guia diz. O próximo passo é continuar o guia na configuração dos módulos e integrações.

 

6. Reiniciar e conferir

No Terminal A, rode de novo o comando do passo 4. No Terminal B, reconecte (& $Cli74 --connect "--controller=$Controller74") e rode:
:read-attribute(name=product-version)
patch info
patch history
O esperado é 7.4.11.GA e um ID de cumulativo do tipo jboss-eap-7.4.11.CP. Depois disso, shutdown.

7. Registrar no manifesto

Anote:
- o nome do arquivo e o SHA-256;
- a saída de patch info, patch history e product-version;
- o caminho do backup ($Backup).

Se algo der errado, a forma mais simples de voltar é restaurar a cópia do passo 3, com o servidor parado.

Sobre o JDK: o que está na sua máquina é o Temurin 8u504, não o Red Hat build of OpenJDK que a seção 4.4 recomenda. Isso não impede aplicar o patch. Mas vale registrar e comparar com o JDK da imagem de destino quando a esteira responder o item ESTEIRA-04.

8. Registrar no manifesto
