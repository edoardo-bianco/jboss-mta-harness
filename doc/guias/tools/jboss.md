---
html:
  embed_local_images: true
  embed_svg: true
  offline: true
---

# JBoss: configuracao e uso

[Voltar ao fluxo principal do desenvolvedor](../harness-migracao-desenvolvedor.md#roteiro-onde-estou-e-o-que-escolho).

Controle local de JBoss EAP 7.1/7.4, usuarios de gerenciamento, deploy, rollback
e debug Java. Os comandos partem da raiz do harness, em Windows PowerShell 5.1.
Para preparar a IDE, consulte as [extensoes Java](workspace.md#extensoes-java-no-vs-code).

**No fluxo principal:** use este guia para observar o comportamento ANTES na
[etapa 2](../harness-migracao-desenvolvedor.md#2-escolher-o-projeto-e-fazer-o-build)
ou executar, depurar e validar a corretiva na
[etapa 7](../harness-migracao-desenvolvedor.md#7-verificar-e-aceitar-o-resultado).
Depois do ensaio, volte a etapa correspondente e registre o resultado como
evidencia. Start, stop, console e debug tambem podem ser usados separadamente.

Navegacao: [configuracao](#configuracao) · [console e usuarios](#console-administrativa-e-usuario-de-gerenciamento) ·
[uso](#uso) · [deploy e rollback](#deploy-e-rollback) · [debug](#debug-java-no-vs-code).

## Configuracao

### Instalacoes, portas e XML standalone

Configure `tools.eap71Home`, `tools.eap74Home` e `tools.applicationJdk8Home`.
**Workspace: configurar caminhos** acrescenta campos `eap` ausentes sem substituir
valores existentes. Padroes (offset aplicado aos sockets do standalone):

| Servidor | Configuracao | Offset | HTTP | Gerenciamento | Debug |
| --- | --- | --- | --- | --- | --- |
| eap71 | standalone.xml | 0 | 8080 | 9990 | 8787 |
| eap74 | standalone.xml | 100 | 8180 | 10090 | 8788 |

Cada `eap.<servidor>` aceita `standaloneConfig` (nome em standalone/configuration),
`portOffset`, `debugPort` e `timeoutSeconds` (10 a 600; padrao 120 por operacao CLI/espera).

Para usar um XML com nome diferente de `standalone.xml`, edite
`eap.eap71.standaloneConfig` ou `eap.eap74.standaloneConfig` em
`config/harness.local.json`. Exemplo de trecho para as duas instalacoes:

```json
"eap": {
  "eap71": {
    "standaloneConfig": "standalone-full.xml"
  },
  "eap74": {
    "standaloneConfig": "standalone-meu-projeto.xml"
  }
}
```

Altere somente o campo do EAP desejado, preservando os demais valores existentes.
Informe apenas o nome do arquivo, sem caminho; ele deve existir em
`<EAP_HOME>/standalone/configuration/` da instalacao selecionada. Se o campo
estiver ausente, o harness usa `standalone.xml`.
Se o servidor estiver ativo, execute **Servidor: parar JBoss** antes de alterar
o campo: a tarefa compara o XML em uso com o nome configurado. Depois salve o
JSON e execute **Servidor: iniciar JBoss**, que passa o nome ao launcher com
`-c`. Essa troca de XML nao exige regenerar o workspace.

O perfil espera os sockets padrao HTTP 8080 e gerenciamento 9990 mais offset.
Preserva e executa o `standalone.conf.bat` instalado. Datasources, drivers e demais
requisitos da aplicacao continuam sendo configurados pelo desenvolvedor no JBoss.
Overrides locais do launcher que mudem Java, portas ou debug devem corresponder
ao perfil; falha de identidade nao sera tratada como sucesso.

O gerenciamento usa CLI local com autenticacao local do JBoss; nao grava senha.
Confere home, base, XML, versao e Java 8 antes das mutacoes. Porta ocupada nao
equivale a servidor correto. Processo existente sem gerenciamento fica
`UNREACHABLE`; nao iniciar outra instancia. Start aguarda `RUNNING`. Stop usa
shutdown e aguarda a saida do processo identificado, sem encerrar outros Java.
Em timeout, consulte o recibo e os logs; o processo e preservado para diagnostico.

### Console administrativa e usuario de gerenciamento

Para usar a console administrativa do JBoss, prepare o usuario de gerenciamento
e verifique o acesso conforme os passos abaixo.
**MTA: conferir ambiente** e a conferencia ao abrir validam requisitos do MTA;
nao criam usuarios nem testam login na console. Essa verificacao e manual, com
o EAP iniciado, e nao e requisito para a CLI local na configuracao padrao.

No VS Code, execute **Terminal > Run Task > Servidor: criar usuario JBoss** e
escolha o EAP. A tarefa usa `applicationJdk8Home` e abre o assistente oficial no
terminal. Selecione **a - Management User** para acesso ao gerenciamento/console
ou **b - Application User** para usuario de aplicacao. O proprio assistente pede
nome, senha e confirmacao. Management User nao concede por si so um papel
administrativo especifico em instalacoes que usam RBAC.

Essa tarefa funciona com o servidor parado. Usa os arquivos padrao de usuarios
da instalacao selecionada (standalone e domain, conforme o utilitario oficial).
Nao inicia o JBoss, nao passa senha como argumento e nao grava recibos ou logs
do assistente. Ao terminar, restaura o ambiente do processo. Encerrar o assistente
sem erro nao comprova criacao: confirme a operacao nele e depois teste o login.

Com o EAP iniciado, abra a console correspondente aos offsets padrao do harness:

| Servidor | Console |
| --- | --- |
| EAP 7.1 | http://localhost:9990/console |
| EAP 7.4 | http://localhost:10090/console |

Se alterou `portOffset`, use a porta de gerenciamento exibida pela tarefa.
Na configuracao padrao, a console exige usuario de gerenciamento, mesmo em
localhost; a CLI local pode autenticar sem esse usuario.

**Caso eventual: habilitar um usuario `admin` existente.** Se a instalacao ja
tiver esse usuario desabilitado, use o mesmo assistente para habilita-lo:

1. Execute **Servidor: criar usuario JBoss** e escolha a instalacao desejada.
2. Selecione **a - Management User**, mantenha `ManagementRealm` quando solicitado
   e informe `admin` como nome do usuario.
3. Se o assistente informar que o usuario existe e esta desabilitado, escolha
   **Enable the existing user** e conclua conforme as mensagens. Confira o texto:
   para um usuario ja habilitado, o menu oferece desabilitar, e essa opcao nao
   deve ser selecionada para este procedimento.
4. Habilitar preserva a senha anterior; o harness nao define uma senha padrao.
   Se nao souber a senha, execute novamente a tarefa, selecione o mesmo EAP,
   **Management User** e `admin`, e escolha
   **a - Update the existing user password and roles**. Informe e confirme a nova senha.
5. Na atualizacao, grupos podem ficar vazios para acesso administrativo com
   `provider="simple"`. Com RBAC, siga o mapeamento de grupos/papeis da instalacao.
   Confirme a atualizacao e, se houver pergunta sobre conexao entre servidores,
   responda **no** para um usuario humano da console.
6. Com o EAP ativo, teste o login na console correspondente usando a senha conhecida.

Esse procedimento so e necessario se o usuario escolhido estiver desabilitado.
O nome `admin` nao e obrigatorio; se ele nao existir, siga o fluxo de criacao
de um usuario de gerenciamento. Veja a [orientacao da Red Hat para atualizar
usuarios](https://docs.redhat.com/en/documentation/red_hat_jboss_enterprise_application_platform/7.4/html/configuration_guide/jboss_eap_management#updating_a_management_user).

Se aparecer a mensagem de que nenhum usuario foi adicionado, use a tarefa acima.
Como alternativa manual, execute o assistente do EAP escolhido com o JDK 8.
No PowerShell, a partir da raiz do harness:

```powershell
$jbossConfig = Get-Content .\config\harness.local.json -Raw | ConvertFrom-Json
$eapHome = $jbossConfig.tools.eap71Home # Troque por eap74Home para EAP 7.4.
$javaHomeAnterior = $env:JAVA_HOME
try {
    $env:JAVA_HOME = $jbossConfig.tools.applicationJdk8Home
    & (Join-Path $eapHome 'bin\add-user.bat')
} finally {
    $env:JAVA_HOME = $javaHomeAnterior
}
```

Escolha **a - Management User**, mantenha **ManagementRealm**, informe usuario e
senha no assistente, deixe grupos vazios para o uso basico e confirme com **yes**.
Na pergunta sobre conexao entre servidores/processos, responda **no** para um
usuario humano da console. Volte ao navegador, clique **Try Again** e confirme
que consegue entrar. Repita na outra instalacao se precisar acessa-la.

O script usa `JAVA_HOME` do terminal: se apontar para um Java recente, como JDK 25,
pode falhar com `Setting a system-wide Policy object is not supported`. O bloco
acima seleciona o JDK 8 apenas durante o assistente e restaura o valor anterior.
As Run Tasks JBoss ja usam o JDK 8 configurado. A tarefa de usuario delega a
criacao ao assistente oficial; o harness nao armazena suas senhas. Ambientes com
autenticacao corporativa seguem sua configuracao.

Referencia: [Red Hat: usuarios de gerenciamento e add-user](https://docs.redhat.com/en/documentation/red_hat_jboss_enterprise_application_platform/7.4/html/configuration_guide/jboss_eap_management).

## Uso

Em **Terminal > Run Task**, use as tarefas da pasta **harness**.
Elas substituem a antiga tarefa **Aplicacao: gerenciar JBoss**:

| Tarefa | Selecao |
| --- | --- |
| Servidor: iniciar JBoss | Modo normal ou debug, depois EAP 7.1, EAP 7.4 ou Todos. |
| Servidor: parar JBoss | EAP 7.1, EAP 7.4 ou Todos. |
| Servidor: consultar estado JBoss | EAP 7.1, EAP 7.4 ou Todos. |
| Servidor: criar usuario JBoss | EAP 7.1/7.4; assistente oficial solicita tipo, nome e senha. Nao exige servidor ativo. |
| Aplicacao: deploy no JBoss | Workspace, EAP 7.1/7.4, aplicacao e WAR/EAR descoberto ou caminho manual. |
| Aplicacao: rollback no JBoss | Workspace, EAP 7.1/7.4, aplicacao, deployment e release anterior. |

Iniciar, parar e consultar estado nao pedem aplicacao nem workspace: atuam sobre
o servidor escolhido, inclusive sem projeto Maven disponivel. Nao criam registros
de migracao. Cada execucao realiza somente a acao escolhida; deploy exige servidor
ativo e nao o inicia. Desconectar debug nao para o JBoss. Stop encerra o servidor
inteiro, incluindo todas as aplicacoes nele. Enter/q cancela os menus de modo/EAP sem executar.
As tarefas ficam no repositorio; nao precisa regenerar workspace para receber
o novo menu. Se necessario, recarregue a janela do VS Code.
Escopo atual: Windows, PowerShell 5.1, Java 8 e servidor local standalone.

**3. Todos (EAP 7.1 e 7.4)** executa a acao primeiro no 7.1 e depois no 7.4,
com as configuracoes, verificacoes de identidade, locks e recibos de cada um.
No start, o modo normal/debug escolhido vale para ambos. O terminal mostra cada
resultado e um resumo final; falha de configuracao ou operacao de um servidor
nao impede tentar o outro. Se qualquer um falhar, a tarefa termina com codigo 1,
sem desfazer os sucessos. EAP nao configurado aparece como falha, sem ser omitido.
Enter/q continua cancelando a selecao; Todos exige escolher a opcao 3.
Criar usuario, deploy e rollback continuam exigindo um EAP individual.

### Testar o controle do servidor sem deploy

1. Execute **Servidor: consultar estado JBoss** e escolha EAP 7.1 ou 7.4.
2. Se estiver STOPPED, execute **Servidor: iniciar JBoss**, escolha **1. Start normal**
   e o mesmo EAP. Confira `Status: SUCCEEDED` e `Observed.State: RUNNING`.
3. Consulte o estado novamente; confira `Identity: MATCHED` e `Debug: false`.
4. Execute **Servidor: parar JBoss** para o mesmo EAP; confira `SUCCEEDED` e `STOPPED`.
5. Para testar o modo debug, inicie com **2. Start com debug**; confira `Debug: true`.
   O attach e o breakpoint na aplicacao seguem o roteiro de debug abaixo.
   Ao terminar, pare o servidor pela tarefa correspondente.

Para ensaiar **Todos**, repita estado/start/stop escolhendo **3** no menu de EAP.
Confira as duas entradas no resumo e os recibos individuais, inclusive no modo debug.

Esse roteiro nao exige selecionar aplicacao nem construir um WAR. Start pode carregar
aplicacoes ja implantadas no servidor; stop encerra todas elas. Repita no outro EAP
quando quiser validar as duas instalacoes. Falha ou timeout exige conferir os logs
e o recibo antes de continuar; nao equivale a sucesso parcial confirmado.

### Deploy e rollback

1. Construa a aplicacao pela tarefa Maven e confira seu resultado.
2. Execute **Servidor: iniciar JBoss** (normal ou debug) e **Servidor: consultar estado JBoss**; espere RUNNING.
3. Execute **Aplicacao: deploy no JBoss**, escolha EAP e aplicacao, confirme/selecione o WAR/EAR encontrado (ou informe caminho manual) e um **nome estavel**, por exemplo
   `minha-api.war`, mesmo que o arquivo contenha a versao no nome.
4. Confira o recibo, o status do deployment e valide a aplicacao funcionalmente.
5. Para reverter, execute **Aplicacao: rollback no JBoss**, escolha o mesmo EAP/aplicacao/nome e a release anterior mostrada no
   menu. O harness reimplanta a copia preservada e verifica hash/status no servidor.

A tarefa procura arquivos `.war` e `.ear` diretamente na pasta `target` do projeto
selecionado e dos modulos declarados em `<modules>` nos POMs. Exibe os caminhos:
com um unico candidato, **Enter** confirma; com varios, escolha um numero, sem
padrao nem preferencia pelo arquivo mais recente. **m** permite informar outro
caminho; **q** cancela. Com varios candidatos, Enter tambem cancela.
Nao procura dentro de WARs expandidos nem escolhe JARs ou arquivos `.war.original`.

Sem candidatos, orienta executar **Aplicacao: build Maven (Java 8)** com
`package`, `verify` ou `install` e permite informar um caminho manual.
O deploy nao executa build. A descoberta nao avalia POM efetivo, perfis ativos,
heranca ou propriedades Maven: para diretorios de saida personalizados e modulos
dependentes dessas configuracoes, informe o caminho manualmente ou selecione o
modulo diretamente como projeto. `-ArtifactPath` explicito na CLI evita a descoberta.
Confira se o artefato foi reconstruido com os fontes desejados; encontrar o arquivo
nao comprova sua atualidade. O harness exibe caminho, destino e hash e registra a
associacao ao projeto selecionado, sem inferir sua origem Maven.

Substituicao exige que o deployment atual corresponda ao ultimo recibo do mesmo
projeto/EAP/nome. Deploy existente sem historico, conteudo alterado externamente,
estado diferente de OK ou arquivo de rollback adulterado sao recusados. Use outro
nome para iniciar um historico ou trate a implantacao anterior manualmente.
O primeiro deploy nao tem release anterior para rollback. Rollback restaura WAR/EAR;
nao reverte banco, configuracao do servidor nem efeitos externos da aplicacao.
Nao ha rollback automatico em erro. Falha depois do envio exige conferir o servidor:
o ultimo sucesso permanece preservado, e uma divergencia impede sobrescrita silenciosa.

Recibos, hashes SHA256 (arquivo), SHA1 (conteudo gerenciado JBoss), logs e copias
de releases ficam em `.harness/jboss/<eap>__<chave>/`. Essa area e permanente e
fica fora de **Workspace: limpar execucoes**. Nao e backup temporario. Recibos
de operacao sao por execucao, com `Scope: Server` e `Project`/`Source` nulos nos
novos recibos de estado/start/stop. Recibos antigos permanecem historicos.
Releases continuam vinculadas a aplicacao, sao por ID e guardam referencia a anterior.
Registram tambem caminho do artefato, base/XML do servidor e observacao Git
informativa. Troca de branch ou ausencia de Git nao bloqueia deploy/rollback.
Uma release SUCCEEDED confirma conteudo/status do deployment, sem conceder aceite
funcional ou GO de migracao. O indice dos projetos continua mostrando build/MTA/
planejamento/Sonar; os recibos JBoss sao consultados pelo caminho exibido na tarefa.

Exemplos CLI: projeto e necessario apenas para deploy/rollback. Sem `-Action`,
o script oferece o menu geral de compatibilidade; selecione a acao antes do EAP.
Parametros antigos de projeto/workspace nao sao utilizados nas operacoes do servidor.

```powershell
powershell.exe -NoProfile -File .\scripts\gerenciar-jboss.ps1 -Eap eap74 -Action StartDebug
powershell.exe -NoProfile -File .\scripts\gerenciar-jboss.ps1 -Target minha-api -Eap eap74 -Action Deploy -ArtifactPath C:\apps\minha-api\target\api-1.0.war -DeploymentName minha-api.war
powershell.exe -NoProfile -File .\scripts\gerenciar-jboss.ps1 -Eap eap74 -Action Status
powershell.exe -NoProfile -File .\scripts\gerenciar-jboss.ps1 -Eap eap74 -Action Stop
powershell.exe -NoProfile -File .\scripts\gerenciar-jboss.ps1 -Eap all -Action Status
```

### Debug Java no VS Code

Se os attaches JBoss ainda nao aparecem, execute **Workspace: gerar workspace**
e abra o workspace local. Se ja aparecem e as portas nao mudaram, nao precisa
regenerar. O workspace recomenda
Language Support for Java (`redhat.java`) e Debugger for Java
(`vscjava.vscode-java-debug`); instale essas extensoes se ainda nao estiverem disponiveis.
O Java do language server continua separado do Java 8 da aplicacao.

Os attaches conectam em `127.0.0.1`, nas portas configuradas (8787 para EAP 7.1,
8788 para EAP 7.4 nos padroes). JDWP inicia com `suspend=n`, sem aguardar o
debugger para subir o servidor. Alterar a porta no JSON exige regenerar o
workspace e reiniciar o servidor. Os nomes desses attaches sao gerenciados pelo
harness; use outro nome para uma configuracao personalizada. F5 conecta ao
servidor preparado; nao habilita JDWP, recompila nem faz deploy pelo harness.

#### Conectar, parar no breakpoint e desconectar

1. Abra `jboss-mta-harness.local.code-workspace` e aguarde a importacao Java.
   Use os fontes do projeto que gerou o WAR implantado.
2. Se o JBoss iniciou com `Debug: false`, execute **Servidor: parar JBoss** para
   esse EAP. Depois use **Servidor: iniciar JBoss > 2. Start com debug** e escolha
   o mesmo EAP. Espere `Observed.State: RUNNING` e `Observed.Debug: true`.
   O estado continua RUNNING; debug habilita a conexao JDWP.
3. Implante o artefato construido com os fontes abertos. Se ele ja esta implantado
   na mesma base/XML e os fontes nao mudaram, nao precisa repetir o deploy apenas
   para conectar o debugger.
4. Abra **Exibir > Executar**, ou **Ctrl+Shift+D**, para mostrar **Executar e
   Depurar / Run and Debug**. No seletor ao lado do triangulo verde, escolha
   **JBoss eap71 - attach Java** ou **JBoss eap74 - attach Java**. Clique no
   triangulo ou pressione **F5**. A conexao usa a porta configurada, sem escolher
   o PID manualmente.
5. Abra o fonte, clique na margem esquerda de uma linha executavel ou pressione
   **F9** nela, e invoque o endpoint. A linha destacada indica a pausa.
6. Inspecione as variaveis e avance pelos controles abaixo. Pressione **F5**
   para concluir a chamada. Depois use **Executar > Parar Depuracao**,
   **Shift+F5** ou **Desconectar** na barra de debug. Nesse attach, desconectar
   mantem o JBoss ativo; **Servidor: parar JBoss** encerra o servidor.

**Ensaio no exemplo ANTES:** no EAP 7.1 com `migracao-cache.war` implantado,
abra `src/main/java/lab/migracao/CacheServlet.java` no playground externo importado
e coloque o breakpoint na chamada `new LimpezaCache().limpar(...)` de `doPost`.
Este roteiro pressupoe o playground `migracao-cache-antes`, mantido fora do harness.
No terminal PowerShell, execute:

```powershell
Invoke-WebRequest -UseBasicParsing -Method Post `
  http://localhost:8080/migracao-cache/cache/limpar |
  Select-Object StatusCode, Content
```

O terminal espera enquanto a requisicao esta pausada. Apos continuar, a resposta
normal e HTTP 200 com `CACHE_CONSULTAS_LIMPO`. O endpoint aceita POST; abrir a
URL diretamente no navegador envia GET. Ajuste a porta/contexto se mudou o
servidor ou o nome do deployment.

#### Controles, variaveis e Watch

Os controles ficam no menu **Executar** e na barra de debug, normalmente flutuante
no topo do editor durante a sessao. Se estiver oculta, confira a configuracao
`debug.toolBarLocation`: `floating` ou `docked` a tornam visivel.

| Acao | Atalho no Windows | Efeito quando pausado |
| --- | --- | --- |
| Breakpoint | F9 | Adiciona/remove o ponto na linha atual. |
| Continuar / Resume | F5 | Executa ate outro breakpoint ou o fim da chamada. |
| Step Over | F10 | Executa a linha sem entrar nas chamadas. |
| Step Into | F11 | Entra na chamada; pode abrir codigo de biblioteca. |
| Step Out | Shift+F11 | Termina o metodo atual e volta ao chamador. |
| Parar/desconectar | Shift+F5 | Encerra a sessao de attach, mantendo o JBoss ativo. |

Em **Variaveis / Variables**, expanda os objetos ou passe o mouse no fonte.
Em **Pilha de Chamadas / Call Stack**, selecione `CacheServlet.doPost` para
inspecionar o contexto dessa chamada. Em **Watch / Inspecao**, clique em **+**
e adicione uma expressao de leitura por vez:

```java
request.getMethod()
request.getRequestURI()
this.entityManagerFactory.isOpen()
```

O Watch reavalia quando o debugger pausa, no contexto selecionado; uma variavel
fora do escopo pode aparecer indisponivel. O **Console de Depuracao**
(`Ctrl+Shift+Y`) tambem avalia expressoes, por exemplo `request.getMethod()`.
No `src/main/java/lab/migracao/LimpezaCache.java` do playground externo,
um breakpoint em `if (cache != null)` permite inspecionar `cache` depois
da atribuicao. Veja os [controles e a inspecao no VS Code](https://code.visualstudio.com/docs/debugtest/debugging).

**Alterar um valor somente nessa chamada:** para ensaiar uma variavel local,
substitua temporariamente a escrita final de `doPost` por:

```java
String mensagem = "CACHE_CONSULTAS_LIMPO";
response.getWriter().write(mensagem);
```

Carregue esse trecho pelo [Hot Code Replace](#hot-code-replace-alterar-o-metodo-em-execucao)
ou por build/deploy. Coloque o breakpoint na linha `write(mensagem)`, depois
da atribuicao, e faca outro POST. Adicione `mensagem` e `mensagem.length()`
ao Watch. Em **Variaveis**, clique com o botao direito em `mensagem`,
escolha **Set Value / Definir Valor** e informe `"DEBUG_TESTADO"`.
Continue com F5: essa resposta deve ser `DEBUG_TESTADO`. Na proxima chamada,
a atribuicao inicial volta a produzir `CACHE_CONSULTAS_LIMPO`. Ao terminar,
restaure o trecho original e atualize a JVM pelo mesmo mecanismo usado no teste.

#### Hot Code Replace: alterar o metodo em execucao

O debugger Java pode substituir bytecode na JVM conectada, sem reiniciar o JBoss
nem enviar outro WAR. No Java 8 usual, restrinja o ensaio ao corpo de um metodo;
adicionar/remover campos ou metodos e mudar assinaturas exige build/deploy.
XML, dependencias e configuracao JBoss tambem nao sao atualizados por esse recurso.
Confira os [limites da JVM e do debugger](https://github.com/microsoft/vscode-java-debug/wiki/Hot-Code-Replace).

O workspace inicial `iniciar-harness.code-workspace` e os novos workspaces gerados
ja habilitam compilacao automatica e Hot Code Replace automatico. As propriedades
abaixo ficam em `settings` do workspace; nao sao opcoes de `config/harness.local.json`.

```json
{
  "java.autobuild.enabled": true,
  "java.debug.settings.hotCodeReplace": "auto"
}
```

Em workspaces antigos, confira essas duas propriedades e ajuste-as diretamente
se quiser habilitar o recurso. O gerador inclui valores ausentes, mas preserva
escolhas explicitas existentes, inclusive `java.autobuild.enabled: false` e
Hot Code Replace em `manual` ou `never`. Preserve os demais ajustes da IDE.
Para desativar a substituicao de codigo, use `java.debug.settings.hotCodeReplace`
com valor `never`; nao e necessario desabilitar o attach ou parar o JBoss.

Com `auto`, o debugger tenta aplicar a classe apos a compilacao Java da IDE.
Salvar o fonte sem compilar nao atualiza o servidor. Essa compilacao nao substitui
o build/testes Maven do fluxo de validacao.
[Opcoes oficiais do debugger Java](https://github.com/microsoft/vscode-java-debug#user-settings).

1. Aguarde a importacao/compilacao Java terminar sem erros. Desconecte e reconecte
   o attach do EAP que esta em debug, mantendo o servidor ativo.
2. Se uma chamada estiver pausada, conclua-a com F5. Desative temporariamente o
   breakpoint para fazer a troca fora do metodo em execucao.
3. No exemplo ANTES, troque somente a escrita final de `doPost`:

   ```java
   response.getWriter().write("CACHE_CONSULTAS_LIMPO_DEBUG");
   ```

4. Salve, aguarde a compilacao e confira as mensagens de Hot Code Replace no
   debugger. Se houver falha, nao assuma que a classe mudou.
5. Repita o POST: a resposta esperada e `CACHE_CONSULTAS_LIMPO_DEBUG`, sem novo
   deploy. Restaure a linha original, salve, aguarde a substituicao e repita
   a chamada para confirmar `CACHE_CONSULTAS_LIMPO`.
6. Ao terminar o ensaio, restaure os fontes temporarios e confirme a resposta
   original; as configuracoes de Hot Code Replace podem permanecer habilitadas.
   Para uma alteracao definitiva, execute build/testes e deploy pelo fluxo normal,
   gerando outra release rastreavel.

A substituicao afeta a JVM e permanece ate outra substituicao ou recarga da
aplicacao; desconectar o debugger nao a desfaz. O WAR e os hashes/recibos de deploy
continuam representando o artefato implantado, sem registrar essas mudancas em
memoria. A resposta de uma nova chamada e a verificacao funcional do ensaio.

#### Se o attach, o Watch ou o breakpoint nao funcionar

Confira `Debug: true`, porta do EAP, extensoes habilitadas, importacao Java e
correspondencia entre os fontes e o WAR. Um breakpoint vazio/cinza pode estar
desabilitado ou nao vinculado a uma linha executavel carregada.
Quando houver varios projetos Java ou classes homonimas, copie o attach para
uma configuracao com outro nome e informe `projectName` com o nome exato exibido
em **Java Projects**, nao presumindo que seja o rotulo da pasta no Explorer.
A extensao usa esse campo para resolver classes e expressoes.
[Configuracao de attach Java](https://github.com/microsoft/vscode-java-debug#attach).

Os exemplos ANTES/DEPOIS sao projetos distintos com classes homonimas: confirme
que o fonte, a configuracao escolhida e a aplicacao implantada correspondem.
Hot Code Replace rejeitado exige conferir o motivo; build/deploy permite
recarregar a aplicacao quando a mudanca nao pode ser aplicada na JVM existente.
O roteiro descreve o teste; nao comprova que breakpoint, Watch ou substituicao
foram validados na instalacao do desenvolvedor.

Referencias: [Red Hat EAP: comandos CLI](https://docs.redhat.com/en/documentation/red_hat_jboss_enterprise_application_platform/7.4/html/management_cli_guide/how_to_cli)
e [VS Code: debug Java e attach](https://code.visualstudio.com/docs/java/java-debugging).
A compatibilidade 7.1 tambem e verificada contra a CLI instalada, que usa saida DMR.
