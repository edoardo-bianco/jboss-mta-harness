# Guia do desenvolvedor: harness de migracao

Repo independente para executar MTA pelo VS Code e preparar o planejamento de corretivas com GitHub Copilot, sob controle do desenvolvedor. Scripts, tarefas, prompt, configuracao e dois projetos de demonstracao estao aqui. **Siga este guia para configurar, executar e revisar cada etapa.** Todos os comandos partem da raiz do repositorio. Um clone permite ensaiar; depois, os exemplos podem ser substituidos pelos repositorios corporativos. JDKs, Maven, MTA e JBoss ficam nas pastas indicadas no JSON local.

## Roteiro: onde estou e o que escolho

Use **Terminal > Run Task**, com as tarefas da pasta `harness`. Confirme sempre
o projeto e o caminho dos fontes exibidos. Um workspace pode conter varios projetos;
a tarefa atua somente no alvo escolhido. Ter uma pasta aberta nao a torna o alvo.

| Etapa | Escolha do desenvolvedor | Resultado para conferir |
| --- | --- | --- |
| 1. Configurar | Caminhos desta maquina e workspace local | Ambiente encontrado; conferir caminhos nao executa build/MTA |
| 2. Build | Projeto/modulo e `clean install` no primeiro ensaio | `SUCCEEDED`, exit 0 e caminhos de `console.log`/`result.json` |
| 3. MTA | Mesmo projeto e fontes do build | Rodada bem-sucedida, integridade e relatorio HTML |
| 4. Preparar planejamento | Rodada MTA, papeis das branches e proposta anterior ou independente | Prompt e recibo com destinos exclusivos |
| 5. Acionar Copilot | Objetivo do lote; continuidade explicita quando houver historico | Um `plan.md` e um `todo.md`, ainda sem GO |
| 6. Revisar | Pendencias, rota, escopo e criterios de aceite | Conferencia Git e GO humano separado |
| 7. Aplicar e validar | Execucao autorizada do lote em etapa separada | Diff, build/testes, qualidade e validacao funcional; aceite humano |
| 8. Continuar | Novo MTA e proposta anterior vinculada | Reconciliar o lote; proximo lote somente apos aceite e pedido |

Para consultar sem gerar outra solicitacao, use **Planejamento: abrir plano e to-do**.
As etapas de Sonar, deploy e controle do servidor ainda nao sao automatizadas aqui.

Navegacao: [configuracao](#comecar-na-maquina-de-trabalho) ·
[projetos](#escolher-o-projeto-em-cada-tarefa) ·
[branches](#branches-e-conferencia-git) ·
[build](#build-maven-da-aplicacao-com-java-8) ·
[MTA](#analise-e-resultados) ·
[Copilot e documentos](#planejar-lotes-de-correcao-com-copilot) ·
[limpeza](#limpar-execucoes-para-repetir-o-ensaio).

## Comecar na maquina de trabalho

**Qual workspace abrir?**

| Arquivo | Quando usar |
| --- | --- |
| `iniciar-harness.code-workspace` | Somente na primeira configuracao, apos clonar. Modelo portavel com o harness e os exemplos. |
| `jboss-mta-harness.local.code-workspace` | No dia a dia, apos configurar. Contem seus caminhos e os projetos adicionados ao workspace; nao e versionado. |

**Se voce ja tem o workspace local configurado, continue abrindo `jboss-mta-harness.local.code-workspace`.** Nao precisa repetir a configuracao inicial nem gerar novamente para adicionar projetos. O arquivo inicial foi renomeado de `jboss-mta-harness.code-workspace` para `iniciar-harness.code-workspace`; seu workspace local permanece o mesmo.

Use uma pasta local permitida pela empresa. Tenha Git, VS Code e Windows PowerShell 5.1 disponiveis; para o planejamento assistido, use Copilot autenticado em sessao Local com o agente `devsquad` do plugin DevSquad disponivel e ferramentas de leitura/edicao habilitadas. Extraia a distribuicao Windows completa do MTA em uma pasta permitida, por exemplo `D:/ferramentas/mta` — **nao precisa ser `.kantra`**. Tenha tambem Maven, JDK do analisador (JDK 25 no ensaio) e JDK 8 da aplicacao. Se ja estiverem instalados, use essas instalacoes. O harness nao instala ferramentas nem exige variaveis globais.

Para o ensaio, nao precisa clonar outro repo: `exemplos/migracao-cache-antes` e `exemplos/migracao-cache-depois` ja acompanham este. JBoss 7.1/7.4 podem permanecer nas pastas onde foram extraidos; seus caminhos sao opcionais nesta primeira etapa. **Neste fluxo, o build Java 8 do projeto/modulo selecionado e obrigatorio antes da analise MTA. Build e analise sao tarefas separadas. Sonar e deploy ficam para etapas posteriores.**

Em uma pasta de repositorios permitida, execute:

```powershell
git clone https://github.com/edoardo-bianco/jboss-mta-harness.git
```

Os passos abaixo usam a **opcao A: configuracao pelo harness**. Para configurar a IDE diretamente, veja a [opcao B: configuracao manual do workspace](#opcao-b-configurar-o-workspace-manualmente).

1. Na primeira configuracao, use **File > Open Workspace from File** e abra `iniciar-harness.code-workspace`, na raiz do clone. Ele ja mostra `harness`, `migracao-cache-antes` e `migracao-cache-depois`, com caminhos relativos. Use-o para configurar os caminhos e gerar seu workspace local nos passos seguintes.
2. Execute **Terminal > Run Task > Workspace: configurar caminhos**. A tarefa cria e abre `config/harness.local.json`, sem sobrescrever uma configuracao existente.
3. Preencha em `tools` os caminhos **desta maquina**, incluindo `applicationJdk8Home` e `applicationMavenHome`, e salve. Os dois exemplos e `activeProject: migracao-cache-antes` ja estao configurados; mantenha-os para o primeiro ensaio. Use o [exemplo completo abaixo](#configuracao-da-maquina). Para repositorios Maven privados/proxy, informe o `settings.xml` aprovado em `tools.mavenSettingsPath` (MTA) e `tools.applicationMavenSettingsPath` (build); podem apontar para o mesmo arquivo. Nao copie o settings da demo pessoal.
4. Execute **Terminal > Run Task > Workspace: gerar workspace**. Abra o arquivo gerado `jboss-mta-harness.local.code-workspace`, na raiz do clone, em **File > Open Workspace from File**. O Explorer deve mostrar `harness` e os projetos cadastrados. A partir daqui, use esse arquivo local para as tarefas e para adicionar seus projetos; quando Run Task pedir o arquivo de workspace, confirme esse nome.
5. Execute **MTA: conferir ambiente**, da pasta `harness`. Deve mostrar `OK`, o projeto certo, os caminhos locais, perfil `eap71-to-eap74-java8`, `Targets: eap7 | Modo: full` e filtro source nenhum. Se falhar, use **Workspace: configurar caminhos**, corrija o JSON e repita a conferencia.
6. Execute **Terminal > Run Task > Aplicacao: build Maven (Java 8)**, da pasta `harness`, e escolha `clean install`. Confira o projeto e a pasta de fontes exibidos: devem ser os mesmos que serao analisados pelo MTA. Aguarde `Status: SUCCEEDED` e `ExitCode: 0`. Se o build falhar, corrija a falha e repita antes de seguir. Veja [como selecionar o projeto/modulo](#build-maven-da-aplicacao-com-java-8).
7. Apos o build bem-sucedido, execute **MTA: executar analise** uma unica vez, escolhendo o mesmo projeto no terminal e mantendo as mesmas fontes. Aguarde o JSON final com `Status: SUCCEEDED`, `ExitCode: 0` e verificacoes de integridade verdadeiras. Para acompanhar, aguarde a mensagem `Rodada` e use **MTA: acompanhar atividade interna** em outro terminal: ela identifica automaticamente a analise em execucao, sem pedir projeto ou workspace. `Ctrl+C` nesse leitor nao para a analise.
8. Execute **MTA: abrir ultimo relatorio** para consultar o HTML. Depois use **Planejamento: preparar contexto para Copilot** e siga o [fluxo de planejamento](#planejar-lotes-de-correcao-com-copilot). A tarefa oferece a ultima rodada valida do projeto e permite escolher outra; nao precisa copiar os caminhos das evidencias.

**No dia a dia:** abra o workspace local e siga **build com sucesso → analise MTA → relatorio → planejamento dos lotes**, selecionando o mesmo projeto nas tarefas. Ao trocar o projeto/modulo ou alterar fontes, POMs ou configuracao de build, repita o build antes da proxima analise. A conferencia de ambiente valida os caminhos do MTA; o sucesso do build e conferido na tarefa propria. A tarefa MTA nao inicia o build nem bloqueia automaticamente sua execucao por falta dele: execute as etapas nessa ordem.

Ao abrir o workspace, a conferencia automatica usa a configuracao legada `repositories`/`activeProject` do JSON, quando disponivel, sem perguntar qual arquivo de workspace usar. Sem padrao, orienta executar a conferencia manual; esta permite informar o workspace e escolher um projeto. Se a configuracao necessaria estiver incompleta, abre o JSON. O VS Code pode pedir para permitir tarefas automaticas; a tarefa manual de configuracao funciona independentemente dessa permissao. Nenhuma analise comeca automaticamente.

Nos proximos dias, abra diretamente `jboss-mta-harness.local.code-workspace`. `iniciar-harness.code-workspace` fica como modelo para novos clones; nao precisa reabri-lo depois da configuracao. Relatorios, configuracao pessoal e workspace local nao acompanham o clone. Se uma politica impedir scripts, siga o procedimento de liberacao da empresa; este guia nao usa bypass nem altera ExecutionPolicy.

## Escolher o projeto em cada tarefa

Use **File > Add Folder to Workspace...** para adicionar os projetos Java/Maven e salve o workspace. **Nao e preciso cadastra-los em `repositories` no JSON do harness.** Cada pasta do workspace que contenha `pom.xml` aparece na selecao, incluindo agregadores e projetos com packaging `pom`, `jar` ou `war`. Para escolher um modulo separadamente, adicione tambem a pasta dele ao workspace. Pastas sem POM e a pasta do harness ficam fora da lista.

Em **Terminal > Run Task**, escolha a tarefa da pasta `harness`. Na entrada **Arquivo .code-workspace em uso**, confirme `jboss-mta-harness.local.code-workspace` se esse for o arquivo aberto. Se usar outro, informe seu caminho completo ou relativo a raiz do harness, sem aspas. No build, escolha tambem as fases na lista do VS Code. Em seguida, o terminal mostra uma lista numerada com nome e caminho dos projetos: digite o numero e pressione Enter. Isso vale para conferir ambiente, build, executar MTA, consultar o historico, abrir relatorio e preparar planejamento. Digite `q` no menu do terminal para cancelar sem executar. As duas tarefas **MTA: acompanhar...** localizam a analise em execucao automaticamente, sem essas perguntas.

Por exemplo, se `simtr-api` e `simtr-outsourcing-api` estiverem no workspace, ambos aparecem. Escolher um agregador executa o Maven no POM dele e inclui os modulos declarados; escolher um modulo usa o POM desse modulo. O nome da pasta nao determina seu papel.

`activeProject` e apenas um **padrao opcional**, pelo nome exibido no workspace ou caminho completo; Enter aceita esse padrao quando ele identifica exatamente um projeto. Sem padrao, escolha um numero. A escolha vale somente para a tarefa atual e nao altera o JSON nem o workspace. Se houver nomes repetidos, confira os caminhos na lista.

As tarefas **Workspace: configurar caminhos** e **Workspace: gerar workspace** cuidam da configuracao, sem alvo de build. A conferencia automatica ao abrir tambem nao solicita selecao. Adicionar/remover projetos no workspace nao exige gerar novamente; o gerador continua sendo uma opcao de criacao/sincronizacao a partir do JSON e pode substituir edicoes manuais.

As tarefas recebem o arquivo informado por `${input:harnessWorkspacePath}`, uma entrada `promptString` suportada pelo VS Code. `${workspaceFile}` nao e uma variavel nativa de tarefas; por isso o caminho e solicitado explicitamente, sem presumir qual workspace esta aberto. Veja a [referencia de variaveis do VS Code](https://code.visualstudio.com/docs/reference/variables-reference). Pelo terminal, passe `-WorkspacePath` e `-SelectTarget` para abrir o mesmo menu, ou `-Target "simtr-outsourcing-api"` para selecionar diretamente. Sem `-WorkspacePath`, os scripts mantem a compatibilidade com `repositories`/`activeProject` do JSON.

Historicos de projetos selecionados pelo workspace sao identificados pelo caminho, evitando misturar projetos homonimos e preservando a identidade quando o nome no Explorer muda. Rodadas antigas criadas pelo cadastro JSON continuam acessiveis pela execucao CLI sem `-WorkspacePath`; os arquivos existentes sao preservados.

## Duas opcoes para configurar o workspace

As duas opcoes configuram a IDE. Para executar as tarefas do harness, mantenha tambem `config/harness.local.json` preenchido, inclusive quando escolher a opcao manual.

| Opcao | Onde editar | Como aplicar |
| --- | --- | --- |
| **A — Pelo harness** | `config/harness.local.json` | Gerar novamente e abrir `jboss-mta-harness.local.code-workspace`. |
| **B — Manualmente no VS Code** | `settings` e, se necessario, `folders` do `.local.code-workspace` | Salvar o arquivo e criar um novo terminal Maven. Nao precisa executar Run Task nem gerar novamente. |

### Opcao A: editar o JSON local e gerar novamente

1. Abra `config/harness.local.json` diretamente ou use **Workspace: configurar caminhos**.
2. Ajuste `repositories`/`activeProject` e os caminhos reais em `tools`. Para o build,
   use `applicationJdk8Home`, `applicationMavenHome` e `applicationMavenSettingsPath`.
   `mtaJdkHome`, `mavenHome` e `mavenSettingsPath` continuam destinados ao MTA.
3. Salve e execute **Terminal > Run Task > Workspace: gerar workspace**. Alternativa
   no terminal PowerShell, a partir da raiz do harness:

   ```powershell
   powershell.exe -NoProfile -File .\scripts\gerar-workspace.ps1
   ```

4. Abra `jboss-mta-harness.local.code-workspace` em **File > Open Workspace from File**.
   O resultado esperado e ver os projetos de `repositories`, Java 8 para a aplicacao
   e Maven/settings correspondentes aos campos `application*`.

Gerar novamente sincroniza a IDE com o JSON; nao precisa fazer isso antes de cada build.
As tarefas do harness leem o JSON a cada execucao, mas o arquivo de workspace so muda
quando e gerado ou editado. O gerador reescreve `folders` e `settings` e guarda o arquivo
anterior em `.harness/workspace-backups/`: ajustes manuais podem ser sobrescritos.

### Opcao B: configurar o workspace manualmente

1. Abra seu `jboss-mta-harness.local.code-workspace`. Se so tiver `iniciar-harness.code-workspace`,
   abra-o e use **File > Save Workspace As...** para salvar uma copia com o nome
   `jboss-mta-harness.local.code-workspace`, na raiz do harness. Continue usando essa copia local.
2. Pressione **Ctrl+Shift+P > Preferences: Open Workspace Settings (JSON)**.
3. Dentro de `settings`, adicione ou ajuste as propriedades abaixo, preservando as
   demais configuracoes e `folders`. **Os caminhos sao ficticios:** use os existentes
   na sua maquina; o JDK da aplicacao deve ser Java 8. Se nao usar settings explicito,
   omita as duas propriedades de settings do exemplo para usar os padroes das ferramentas.

   ```json
   {
     "java.configuration.runtimes": [
       {"name": "JavaSE-1.8", "path": "D:/ferramentas/jdk8", "default": true}
     ],
     "java.jdt.ls.java.home": "D:/ferramentas/jdk-25",
     "maven.executable.path": "D:/ferramentas/apache-maven/bin/mvn.cmd",
     "maven.terminal.useJavaHome": false,
     "maven.terminal.customEnv": [
       {"environmentVariable": "JAVA_HOME", "value": "D:/ferramentas/jdk8"}
     ],
     "maven.settingsFile": "D:/config/maven/settings.xml",
     "java.configuration.maven.userSettings": "D:/config/maven/settings.xml"
   }
   ```

4. Salve. Apos terminar qualquer execucao em andamento, feche os terminais Maven antigos.
   No painel **MAVEN**, selecione o projeto e use **Run Maven Command > Custom** ou
   **Execute Commands...**, conforme a interface, com `--version` (sem `mvn`). Confira
   Java 1.8 e o Maven escolhido. Depois execute `clean install` pela mesma opcao.

`java.configuration.runtimes` identifica o JDK do projeto; `maven.terminal.customEnv`
define o Java do processo Maven. `java.jdt.ls.java.home` executa o servico Java da IDE
e pode continuar no JDK25. O Java da IDE nao precisa ser o mesmo Java do build.

**Editar o workspace nao atualiza `config/harness.local.json`.** Se tambem usar tarefas
MTA/build do harness, mantenha esse JSON configurado para elas. A extensao Maven usa o
POM selecionado; as tarefas oferecem os projetos do workspace. Escolha o mesmo projeto nos dois fluxos.
Configuracoes de pasta podem sobrescrever as do workspace. Se optar pela edicao manual,
nao gere novamente sem antes considerar os ajustes que serao substituidos.

**Recarregar a janela nao e gerar novamente o workspace:** `Developer: Reload Window`
reinicia a interface/extensoes; o gerador reescreve o arquivo a partir do JSON do harness.
Para o Java de um novo comando Maven, salve as configuracoes e crie um terminal Maven novo.

## Ensaiar e depois usar os projetos corporativos

| Projeto incluido | Conteudo e resultado esperado com MTA 8.2.1/regras ensaiadas |
| --- | --- |
| `migracao-cache-antes` | Codigo original, proveniente do commit `1bfbae96ebd39a3e996d07682ad88cd7af603cbf` da demo local. Regras `hibernate51-53-00400` e `00401` apontam a mesma chamada `getQueryCache()` em `LimpezaCache.java`; triagem precisa distinguir o overload e evitar dupla contagem. |
| `migracao-cache-depois` | Mesma aplicacao com a correcao minima `factory.getCache().evictDefaultQueryRegion()` e POM alinhado ao Hibernate `5.3.20.Final-redhat-00001` do EAP 7.4 local. O resultado MTA anterior precede esse alinhamento do POM; a nova combinacao requer sua propria rodada. Nao e comprovacao de homologacao no EAP 7.4. |

As duas pastas incluem POM, fontes e testes Java 8. Sao projetos independentes para selecionar um por vez, nao modulos de um reactor comum. Foram preservados `javax.*`, WAR e contratos. No exemplo DEPOIS, `hibernate-core` permanece `provided` e `hibernate-ehcache` fica em `test`, ambos na versao do destino local; o POM declara o repositorio Red Hat GA. Na empresa, o repositorio Maven aprovado deve disponibilizar esses artefatos; confira a versao do EAP instalado. Ao corrigir ANTES numa branch, seu conteudo deixa de ser o baseline original: compare pelos snapshots das rodadas. A distribuicao MTA, caches Maven e resultados antigos nao sao publicados aqui.

Comece pelo `migracao-cache-antes`: selecione-o nas tarefas, execute o build, depois o MTA, abra o relatorio e use **Planejamento: preparar contexto para Copilot**. Para comparar com o exemplo ja corrigido, selecione `migracao-cache-depois`, conclua o build desse projeto e execute MTA novamente; cada projeto recebe suas proprias rodadas. Para um ensaio independente, o Copilot deve se limitar ao projeto selecionado, sem consultar a solucao do outro exemplo.

**Apos o ensaio, para manter apenas os projetos corporativos:**

1. Clone os repositorios reais em pastas externas ao harness, usando os meios aprovados pela empresa.
2. Use **File > Add Folder to Workspace...** para incluir os projetos corporativos. Remova as pastas dos exemplos do workspace pelo Explorer e salve o `.local.code-workspace`.
3. Execute as tarefas e selecione o projeto no terminal. Se desejar, ajuste `activeProject` para um padrao; o cadastro em `repositories` nao e necessario.
4. As pastas em `exemplos/` podem entao ser removidas, se desejado. Para continuar usando o gerador ou a CLI legada, atualize tambem `repositories`; as tarefas que recebem o workspace usam diretamente suas pastas, mesmo que esse cadastro esteja desatualizado.

Remover as entradas do workspace nao apaga codigo nem evidencias antigas. Nao ha exclusao automatica dos exemplos e nao e necessario mudar scripts para adicionar projetos corporativos.

## Tarefa e script correspondente

| Run Task | Arquivo em `scripts/` |
| --- | --- |
| Workspace: configurar caminhos | `configurar-caminhos.ps1` |
| Workspace: gerar workspace | `gerar-workspace.ps1` |
| Workspace: limpar execucoes | `limpar-execucoes.ps1` |
| MTA: conferir ambiente | `conferir-ambiente.ps1` |
| **Aplicacao: build Maven (Java 8)** | **`construir-aplicacao.ps1 -Goals <fases escolhidas>`** |
| **MTA: executar analise** | **`executar-mta.ps1`** |
| **MTA: acompanhar log da analise** | **`acompanhar-log-mta.ps1 -Active`** |
| **MTA: acompanhar atividade interna** | **`acompanhar-log-mta.ps1 -Active -Detalhado`** |
| MTA: consultar log de execucao anterior | `acompanhar-log-mta.ps1 -SelectTarget -SelectRun -Once` (com workspace informado) |
| MTA: abrir ultimo relatorio | `abrir-relatorio-mta.ps1` |
| Workspace: conferir configuracao ao abrir | `conferir-ambiente.ps1 -AoAbrir` |
| Planejamento: preparar contexto para Copilot | `preparar-planejamento.ps1` |
| Planejamento: abrir plano e to-do | `abrir-planejamento.ps1` |
| Planejamento: conferir Git do lote | `conferir-git-planejamento.ps1` |

Alternativa pelo terminal, na pasta deste repo: execute o build e confira seu sucesso antes de iniciar a analise. Se o build falhar, corrija-o antes de executar o segundo comando.

```powershell
powershell.exe -NoProfile -File .\scripts\construir-aplicacao.ps1 -WorkspacePath .\jboss-mta-harness.local.code-workspace -SelectTarget -Goals "clean install"
# Somente apos o build concluir com sucesso:
powershell.exe -NoProfile -File .\scripts\executar-mta.ps1 -WorkspacePath .\jboss-mta-harness.local.code-workspace -SelectTarget
```

## Configuracao da maquina

O exemplo versionado e `config/harness.example.json`; a tarefa cria dele o seu `config/harness.local.json`. Use caminhos reais com `/` ou `\\`, sem variaveis como `%JAVA_HOME%`. Caminhos relativos partem da pasta deste repo.

**Respeitar os padroes das ferramentas:** mantenha `mavenSettingsPath` e
`applicationMavenSettingsPath` como `null` no uso normal. Maven usa os settings
globais/usuario da maquina e seu repositorio local padrao, normalmente
`%USERPROFILE%\.m2\repository`. O harness nao cria settings, mirrors ou cache
Maven proprios. Informe um settings alternativo somente quando necessario,
por exemplo um arquivo corporativo aprovado. A geracao do workspace tambem
omite os overrides de settings quando esses campos estao null.

Exemplo completo para preencher na etapa 3. **Os caminhos de ferramentas abaixo sao ficticios:** substitua pelos existentes na maquina de trabalho. Os caminhos relativos dos dois exemplos ja sao validos no clone. Campos opcionais podem ficar `null`; JBoss e Sonar nao bloqueiam esta etapa.

```json
{
  "schemaVersion": 1,
  "activeProject": "migracao-cache-antes",
  "repositories": [
    {"name": "migracao-cache-antes", "path": "exemplos/migracao-cache-antes"},
    {"name": "migracao-cache-depois", "path": "exemplos/migracao-cache-depois"}
  ],
  "tools": {
    "mtaExecutable": "D:/ferramentas/mta/windows-mta-cli.exe",
    "mtaJdkHome": "D:/ferramentas/jdk-25",
    "mavenHome": "D:/ferramentas/apache-maven",
    "mavenSettingsPath": null,
    "applicationMavenHome": "D:/ferramentas/apache-maven",
    "applicationMavenSettingsPath": null,
    "applicationJdk8Home": "D:/ferramentas/jdk8",
    "eap71Home": null,
    "eap74Home": null
  },
  "mta": {
    "profile": "eap71-to-eap74-java8",
    "rulesPath": null,
    "sources": [],
    "targets": ["eap7"],
    "mode": "full"
  }
}
```

| Campo | Preencher com |
| --- | --- |
| `repositories` | Opcional para tarefas com workspace: usado pelo gerador e pela CLI legada sem `-WorkspacePath`. As tarefas do VS Code descobrem os projetos no workspace aberto. |
| `activeProject` | Padrao opcional: nome do projeto no workspace ou caminho completo. Pode ficar `null` ou ser omitido; escolha o alvo no menu de cada tarefa. Na CLI legada, corresponde ao `name` em `repositories`. |
| `tools.mtaExecutable` | Caminho completo do `windows-mta-cli.exe` dentro da distribuicao completa. Essa pasta tambem define onde o MTA busca seus componentes. |
| `tools.mtaJdkHome` | Pasta do JDK do analisador. O ensaio local utilizou JDK 25. |
| `tools.mavenHome` | Maven usado pelo MTA, com `bin/mvn.cmd`. |
| `tools.mavenSettingsPath` | Opcional: `settings.xml` aprovado para o MTA. Nunca coloque credenciais neste JSON. |
| `tools.applicationMavenHome` | Maven do build da aplicacao, com `bin/mvn.cmd`. Pode apontar para a mesma instalacao do MTA; depois pode ser trocado independentemente. |
| `tools.applicationMavenSettingsPath` | Opcional: `settings.xml` do build/importacao Java. Pode ter o mesmo caminho do MTA. Se null, Maven usa seus settings padrao; nao herda o campo do MTA. |
| `tools.applicationJdk8Home` | Obrigatorio para o build: pasta do JDK 8, tambem configurada no workspace para a aplicacao. |
| `tools.eap71Home`, `tools.eap74Home` | Opcionais: pastas dos JBoss ja extraidos, reservadas para a etapa de runtime. |
| `mta.rulesPath` | `null` usa `rulesets/java` ao lado da CLI; preencha se as regras Java estiverem em outra pasta. |
| `mta.profile` | `"eap71-to-eap74-java8"`: origem EAP 7.1, destino EAP 7.4, Java 8 e `javax.*`. |
| `mta.sources`, `mta.targets`, `mta.mode` | Mantenha `[]`, `["eap7"]` e `"full"`. O harness recusa desvios desse perfil. |

**Trocar projeto:** escolha outro alvo no menu, execute seu build e, apos sucesso, selecione-o no MTA. **Adicionar projetos:** use Add Folder to Workspace e salve. **Mudar ferramentas:** ajuste `tools` no JSON e sincronize as configuracoes da IDE pela opcao A ou B. O gerador substitui as pastas a partir de `repositories`, com backup em `.harness/workspace-backups/`; nao e necessario executa-lo para adicionar projetos ao workspace. Uma biblioteca visivel nao e compilada nem analisada automaticamente junto com outro repo.

## O que acompanha o clone

Scripts, tarefas, prompt, exemplo de configuracao, workspace inicial, dois projetos de demonstracao, testes e este README entram no Git. `config/harness.local.json`, o workspace gerado e `.harness/` sao locais e ignorados. O clone no trabalho pede os caminhos dessa maquina, sem carregar caminhos pessoais. **Este repo nao depende de outro harness nem dos checkouts locais usados para criar os exemplos.**

Os programas precisam estar instalados/extraidos nessa maquina. **O MTA pode ficar em qualquer pasta local permitida pela empresa; `.kantra` nao e obrigatorio.** Extraia a distribuicao Windows completa nessa pasta, preservando CLI, `java-external-provider.exe`, `jdtls/`, `rulesets/`, `static-report/` e os demais arquivos do ZIP. Nao basta mover so o executavel. Nao ha instalacao automatica nem alteracao de ExecutionPolicy.

Por exemplo, se a pasta permitida for `D:/ferramentas/mta`, informe `"D:/ferramentas/mta/windows-mta-cli.exe"` em `tools.mtaExecutable`. Com `mta.rulesPath: null`, as regras virao de `D:/ferramentas/mta/rulesets/java`. O harness define `KANTRA_DIR` com a pasta do executavel somente no processo da analise e restaura o valor anterior ao terminar, inclusive em caso de falha. Nao precisa configurar essa variavel globalmente. **MTA: conferir ambiente** mostra a pasta efetiva e confere a presenca dos componentes essenciais. [Resolucao da pasta pelo Kantra](https://github.com/konveyor/kantra/blob/main/pkg/util/util.go).

As tarefas usam Windows PowerShell 5.1. Java e Maven sao configurados somente no processo da analise, a partir do JSON: nao precisa ajustar `JAVA_HOME` ou PATH global. O JDK do MTA nao muda o Java 8/POM da aplicacao. Combinacao ensaiada: MTA 8.2.1, JDK 25 e Maven 3.9.16. A analise completa pode acessar os repositorios Maven definidos nos settings.

## Build Maven da aplicacao com Java 8

**Conclua o build do alvo antes de executar MTA.** Escolha o mesmo projeto do workspace nas duas tarefas. Se escolher um POM agregador, o build inclui seu reactor. Para analisar apenas um modulo, adicione a pasta desse modulo ao workspace e selecione-o; pais e dependencias de outros modulos devem estar disponiveis no repositorio Maven. Quando necessario, execute primeiro `clean install` no agregador para disponibiliza-los, depois construa e analise o modulo escolhido.

Preencha `tools.applicationJdk8Home`, `tools.applicationMavenHome` e, se necessario,
`tools.applicationMavenSettingsPath`. Os campos `mavenHome`/`mavenSettingsPath` continuam
exclusivos do MTA. Para usar a mesma versao por enquanto, informe o mesmo caminho nos
dois campos Maven; nao e preciso duplicar a instalacao. JSON antigo continua funcionando
na leitura da configuracao MTA; para seguir o fluxo completo, preencha tambem os campos do build.

Execute **Terminal > Run Task > Aplicacao: build Maven (Java 8)** e selecione o projeto no terminal.
Para preparar a analise, escolha `clean install` e aguarde o sucesso. A tarefa tambem
oferece `clean verify`, `clean package`, `test`, `package`, `verify`, `install` e `clean`
para outras operacoes; `clean` sozinho nao atende a etapa de build anterior ao MTA.
A tarefa mostra projeto, caminhos, versoes e log. Alternativa no
terminal PowerShell, a partir da raiz deste harness:

```powershell
powershell.exe -NoProfile -File .\scripts\construir-aplicacao.ps1 -WorkspacePath .\jboss-mta-harness.local.code-workspace -SelectTarget -Goals "clean install"
```

O padrao da tarefa e do script sem `-Goals` continua sendo `clean verify`; para seguir a preparacao descrita neste guia, selecione ou informe `clean install`. `clean` remove as saidas conforme o POM;
`install` percorre o ciclo ate instalar o artefato no repositorio Maven local.
Veja o [ciclo oficial do Maven](https://maven.apache.org/guides/introduction/introduction-to-the-lifecycle.html).
Esta entrada aceita as fases acima (tambem `validate`/`compile`, com `clean` opcional),
sem linha de shell, flags avulsas ou goals arbitrarios de plugins. Perfis, plugins,
toolchains e `.mvn` existentes continuam sendo configuracao da aplicacao e precisam
estar revisados. Um toolchain ou compilador externo declarado no projeto pode selecionar
outro JDK: a conferencia do launcher nao certifica todo o bytecode produzido.

O executor usa `applicationJdk8Home` e `applicationMavenHome` somente no processo,
confere Java 8 e Maven 3 antes das fases e restaura o ambiente ao terminar. Opcoes
Java/Maven herdadas do terminal e scripts pessoais mavenrc nao sao usados; configuracao
versionada `.mvn` e settings declarados permanecem aplicaveis. O build ocorre na raiz
do projeto ativo, incluindo seu reactor. Nao execute outra IDE/CLI escrevendo nesse
projeto; a tarefa compartilha o lock do MTA deste harness.

Log e recibo ficam em `.harness/builds/<nome>__<chave12>/build_<data-fuso>__<RunId12>/console.log` e `result.json`.
O nome usa a data/hora de inicio do recibo e o fuso local; o RunId completo permanece
no JSON. Builds anteriores continuam nos caminhos originais.
O codigo de falha do Maven e propagado. `SUCCEEDED` significa Maven exit 0 para as
fases escolhidas; `clean` sozinho, testes desabilitados no POM ou ausencia de testes
nao comprovam teste/cobertura. Esta tarefa nao produz manifesto Sonar nem homologa EAP.
Depois de trocar o Maven/settings da aplicacao no JSON do harness, siga a opcao A para
sincronizar a IDE; se preferir editar a IDE diretamente, siga a opcao B em
[Duas opcoes para configurar o workspace](#duas-opcoes-para-configurar-o-workspace).
A tarefa de build le o JSON novamente em cada execucao.

### Usar a extensao Maven padrao do VS Code

Abra `jboss-mta-harness.local.code-workspace`. O gerador configura o `JAVA_HOME` do
terminal Maven em `maven.terminal.customEnv`, a partir de `applicationJdk8Home`, e
`maven.terminal.useJavaHome: false`. Configura tambem `maven.settingsFile` com
`applicationMavenSettingsPath` e `maven.executable.path` com o Maven da aplicacao.
O Java do servico da IDE (`java.jdt.ls.java.home`) continua separado do Java do build.
Esses valores sao atualizados sempre que voce gera novamente o workspace.

Depois de alterar/gerar o workspace, feche os terminais Maven antigos ja encerrados
e abra um novo; nao interrompa uma execucao em andamento. No painel **MAVEN**, clique
com o botao direito no projeto desejado, escolha **Execute Commands...** e digite
`--version`, sem `mvn`. Confira Java 1.8 e o Maven configurado. Depois use a mesma
opcao com `clean install` e aguarde `BUILD SUCCESS` antes de executar MTA. Confira que o POM selecionado corresponde ao projeto que voce escolhera na tarefa MTA. A extensao usa o POM selecionado
e nao passa pelo lock/recibo da tarefa do harness: execute uma operacao por vez.
Configuracoes particulares de pasta podem sobrescrever as do workspace.
Referencia: [configuracao da extensao Maven](https://github.com/microsoft/vscode-maven#additional-configurations).

## Analise e resultados

Mantenha o bloco `mta` do exemplo completo acima para preservar o perfil ensaiado.

**Origem/destino da migracao e filtros do MTA sao coisas distintas.** A CLI 8.2.1 ensaiada nao oferece target `eap7.4`. Usamos `eap7`, incluindo as regras Hibernate 5.1 para 5.3: no arquivo instalado `eap7/116-hibernate51-53.windup.yaml`, elas tem source `hibernate`/`hibernate5.1-` e target `eap7`. Acrescentar `--source eap7.1` excluiria essas regras. `sources: []` e intencional: nao envia `--source`. A selecao por rotulos e descrita no [guia de regras do Kantra](https://github.com/konveyor/kantra/blob/main/docs/rules-quickstart.md).

Preservamos `full`, `--run-local`, todas as regras YAML da pasta Java (sem fixtures de teste), `--enable-default-rulesets=false` e ausencia de `--json-output`. O perfil identifica o objetivo; nao reescreve regras nem transforma o conjunto amplo `eap7` em cobertura exata do EAP 7.4. O Copilot/desenvolvedor deve triar a aplicabilidade por versao e dependencia; o corrigido sera validado no EAP 7.4. Nao converter `javax.*` para `jakarta.*` nem trocar o target para `eap8`.

JSONs locais anteriores, sem `profile` e `sources`, recebem esses valores em memoria; caminhos permanecem inalterados. As novas rodadas registram perfil, origem/destino e filtros no manifesto, alem dos argumentos e hashes das regras. Atualizar a distribuicao ou `rulesPath` exige conferir novamente a comparabilidade com o baseline: o nome do perfil sozinho nao garante regras identicas.

Cada nova rodada fica em `.harness/runs/<nome>__<chave12>/mta_<data-fuso>__<RunId12>/`, com copia do reactor e das regras, `manifest.json` (argumentos/hashes), `console.log`, `result.json` e `output/static-report/index.html`. A pasta usa o instante CreatedAtUtc do manifesto convertido para horario local com fuso; o ID completo permanece nos recibos. Excluimos `.git`, `.harness`, `.scannerwork`, `node_modules` e pastas Maven `target`; preservamos `.mvn` e os modulos. Modulos/pais externos precisam estar disponiveis no Maven ou incluidos na raiz escolhida. Links/junctions nao sao suportados. As fontes originais e as regras sao conferidas depois da execucao.

Rodadas antigas em `.harness/runs/<Project>/<RunId>/` continuam acessiveis nas
mesmas tarefas. O harness le ambos os formatos, inclusive ultimo relatorio,
analise ativa, logs e planejamento. Confere projeto/fonte e ID completo no
manifesto; mudar o rotulo do projeto nao perde o historico. Copias com o mesmo
RunId dentro da area de rodadas sao recusadas como ambiguas.

Uma falha nao substitui o ultimo relatorio concluido do projeto. `SUCCEEDED` confirma a execucao e as verificacoes locais, nao a homologacao no EAP 7.4. Sonar e deploy ficam para etapas posteriores.

### Acompanhar a analise MTA

**Acompanhar a execucao atual:** o terminal de **MTA: executar analise** ja mostra a saida. Para abrir um leitor separado, aguarde a mensagem `Rodada` e execute **MTA: acompanhar log da analise**. Ela se vincula automaticamente a analise MTA em execucao neste harness, sem pedir projeto ou workspace; mostra projeto, fontes, RunId e caminho do log. Exibe as ultimas 40 linhas e acompanha novas linhas dessa rodada. `Ctrl+C` encerra somente o leitor. Ele fica nessa rodada e nao muda para outra automaticamente; encerre-o ao concluir e confira o JSON final no terminal original. Se encontrar o resultado ao abrir, mostra-o e encerra. Sem MTA ativo, informa que nao ha analise em execucao; um build ou registro antigo nao conta como analise ativa. Se o log ainda nao existir, informa a situacao sem abrir um log antigo.

**Consultar uma execucao anterior:** execute **MTA: consultar log de execucao anterior**, confirme o workspace e escolha o projeto. Depois escolha a rodada na lista, que mostra data/hora local com fuso, resultado e RunId, da mais recente para a mais antiga. A ordem usa o instante do manifesto, nao a data de copia da pasta. A tarefa exibe o resultado salvo, o caminho do `console.log` e suas ultimas 40 linhas, sem executar MTA nem seguir novas linhas. `SEM RESULTADO` indica ausencia de recibo, nao comprova que a rodada esteja em execucao. Para ler tudo, abra o arquivo pelo caminho exibido. Builds Maven ficam em `.harness/builds/` e nao aparecem nesse historico MTA.

Para escolher uma rodada explicitamente, use `powershell.exe -NoProfile -File .\scripts\acompanhar-log-mta.ps1 -WorkspacePath .\jboss-mta-harness.local.code-workspace -SelectTarget -RunId <id>`. Adicione `-Once` para mostrar somente as ultimas linhas, sem esperar. O leitor nao inicia/cancela MTA nem altera arquivos; nao acompanha os logs internos do JDT.

**Console sem novas mensagens:** use **MTA: acompanhar atividade interna**. No mesmo script, `-Active -Detalhado` identifica a analise em execucao e consulta `.metadata/.log` da rodada a cada 5 segundos, mostrando horario/idade da ultima gravacao e ate quatro linhas resumidas de mensagens/classes/consultas. Le no maximo 16 KiB por consulta e reabre o arquivo para tolerar rotacao, sem despejar o log inteiro. Nao altera o nivel de log nem a analise. Encerra ao encontrar `result.json` legivel ou com `Ctrl+C`; acrescente `-Once` para fazer apenas uma consulta. Logs atualizados indicam atividade, nao porcentagem/progresso garantido; silencio sozinho tambem nao comprova travamento. Esta visao usa o formato JDT observado na CLI ensaiada e pode ficar indisponivel em outra versao.

## Branches e conferencia Git

O harness consulta Git automaticamente no repositorio que contem o projeto
selecionado. O desenvolvedor define o papel das branches e a frente de trabalho;
nao precisa repetir manualmente os quatro comandos Git a cada planejamento.

| Campo | Significado | Exemplo e escolha |
| --- | --- | --- |
| Principal | Linha que recebe as evolutivas normais da aplicacao | `develop` na equipe ou `main` no ensaio; escolha a referencia acordada |
| Migracao | Linha que integra a progressao das corretivas EAP 7.4 | `develop_jboss_eap74` ou `main_jboss_eap74`, separada da principal |
| Trabalho autorizada | Branch em que esta frente pode aplicar seu lote | `lote/cache-hib-001`; no trabalho individual pode ser a propria branch de migracao |
| Atual | Branch observada no checkout neste instante | Deve coincidir com a de trabalho autorizada antes de executar |
| HEAD | Commit atual, identificado pelo hash | Mudar o HEAD exige reconciliar o lote, mesmo mantendo a branch |
| Checkout e modulo | Pasta de trabalho e caminho do projeto dentro da raiz Git | Um modulo pode compartilhar o repositorio com outros modulos |

No exemplo `migracao-cache-antes`, a raiz Git e o proprio repositorio do harness.
As branches abrangem esse checkout inteiro, incluindo o harness e os exemplos.
Escolher nomes no menu nao isola o exemplo em outro repositorio. Em projetos
corporativos, selecione o checkout real da aplicacao; nao copie a branch observada
no harness.

### Branch exclusiva para alterar o harness

Antes de mudar scripts, prompts, Run Tasks, testes ou documentacao, crie uma
branch `harness/<objetivo>` a partir da `main` do harness. Exemplo:
`harness/ajustar-planejamento`. Retome uma branch existente somente se for a
mesma frente de trabalho e sua base estiver conferida.

| Trabalho | Branch | Destino da entrega revisada |
| --- | --- | --- |
| Evoluir o harness | `harness/<objetivo>` | `main` do harness |
| Analisar a base integrada EAP 7.4 | `main_jboss_eap74` | Novo build/MTA e proposta |
| Aplicar corretiva autorizada | `lote/<id>` | `main_jboss_eap74` |

Nao desenvolva o harness diretamente na principal ou nas branches da migracao.
Confira e preserve alteracoes locais antes de trocar de branch. Se uma migracao
estiver em andamento, use outro checkout/worktree para o harness, sem alterar a
branch da pasta usada pelo agente de migracao.

No ensaio, ambos compartilham o repositorio: revise/teste a mudanca do harness,
integre na `main` e depois alinhe `main_jboss_eap74` explicitamente. Retorne ao
checkout da migracao, confira o novo HEAD e atualize o contexto e as evidencias
afetadas antes de continuar. Em repositorios separados, essa integracao ocorre
somente no repositorio do harness. A branch do lote so e criada quando o
planejador solicitar apos definir a proposta.

### Em qual branch rodar o primeiro MTA, se o lote ainda nao existe?

Nao e preciso conhecer o lote nem criar sua branch antes do diagnostico. O fluxo
recomendado comeca com build e MTA sobre a branch de migracao, em um checkout
local proprio, limpo e alinhado com a referencia acordada pela equipe.
Estar localmente em `main_jboss_eap74` para analisar nao publica alteracoes nessa
branch. Checkout proprio e a pasta de trabalho de cada desenvolvedor; branch e
a linha de historico selecionada nessa pasta. Nao compartilhe a mesma pasta de
trabalho com outro desenvolvedor ou agente que possa alterar seu estado.

| Etapa | Branch do checkout | Acao e resultado esperado |
| --- | --- | --- |
| Preparar a base | `main` -> `main_jboss_eap74` | Consolidar a principal e criar a linha de migracao a partir dela, mantendo o alinhamento acordado pela equipe. |
| Diagnosticar | `main_jboss_eap74` | Executar build e MTA; registrar o commit e preservar essa rodada como baseline. |
| Propor um lote | `main_jboss_eap74` | Planejar um unico lote a partir do MTA; a branch de trabalho pode continuar pendente. |
| Isolar o trabalho | `lote/cache-hib-001` | Depois de identificar o lote, criar sua branch a partir da base analisada e cadastrar a frente. |
| Autorizar e corrigir | `lote/cache-hib-001` | Reconciliar o contexto, conferir Git, obter GO humano e executar somente o escopo aprovado. |
| Verificar e integrar | Lote -> `main_jboss_eap74` | Verificar a corretiva, obter revisao humana, integrar e repetir as verificacoes e o MTA no estado integrado. |
| Continuar | `main_jboss_eap74` -> nova branch de lote | Voltar a base integrada e atualizada, usar o MTA desse estado e, apos aceite e pedido de continuidade, identificar o proximo lote. |

**Ao terminar um lote, retorne a base de integracao EAP 7.4 antes de planejar o
seguinte.** O MTA executado na branch do lote serve para verificar aquela
corretiva. A referencia para escolher o proximo lote e o MTA da branch de migracao
integrada (`main_jboss_eap74` ou `develop_jboss_eap74`), incluindo as corretivas
aceitas dos colegas e as evolutivas incorporadas da principal.

**Relatorios de commits diferentes nao formam um diagnostico da integracao.**
Por exemplo, o MTA do commit do desenvolvedor A e o MTA do commit do desenvolvedor
B verificam suas respectivas bases. Depois de integrar ambos, execute uma nova
analise completa no commit resultante da branch EAP 7.4. Nao some os relatorios
nem escolha simplesmente o mais recente entre as branches dos desenvolvedores.
O proximo lote usa essa nova rodada integrada, com Project/Source, branch, HEAD
e RunId identificados e perfil/regras comparaveis.

Neste fluxo, "MTA limpo na base" significa checkout sem alteracoes locais,
build `clean install` e nova rodada MTA em sua propria pasta de saida. Preserve
as rodadas anteriores e os planejamentos como historico para reconciliacao;
nao e necessario apagar `.harness`, caches ou relatorios para reanalisar.
Se novos commits forem incorporados a base antes de iniciar o proximo lote,
atualize o checkout e repita build/MTA nessa base antes de fechar sua proposta.

1. Conclua as verificacoes da branch do lote e obtenha revisao/aceite humano para
   integrar, conforme o fluxo da equipe.
2. Integre o lote na branch de migracao. Resolva conflitos com revisao e preserve
   o trabalho existente; o harness nao executa essa integracao automaticamente.
3. No seu checkout, retorne a branch de migracao e atualize-a para a referencia
   compartilhada acordada. Nao troque de branch carregando alteracoes pendentes
   do lote; conclua sua preservacao pelo fluxo Git da equipe primeiro.
4. Execute build, testes e demais verificacoes do estado integrado, incluindo
   novo MTA. Registre o commit analisado e obtenha o aceite humano desse estado.
5. Prepare contexto selecionando esse MTA e vinculando o planejamento anterior.
   Peca reconciliar o lote concluido e identificar somente o proximo lote.
6. Crie a nova branch do lote a partir dessa base analisada e repita cadastro,
   conferencia Git, revisao e GO antes de aplicar a nova corretiva.

Esse retorno reduz retrabalho e evita usar como base apenas o resultado isolado
de uma branch de lote. Nao elimina conflitos: se a integracao avancar depois do
MTA, confira os commits novos e as sobreposicoes antes de iniciar/retomar.
Reconcile o plano e atualize as evidencias necessarias. Coordenar responsavel,
arquivos e dependencias continua obrigatorio para frentes paralelas.

**No menu, quando ainda nao sabe qual sera o lote:** em **Planejamento: preparar
contexto para Copilot**, pressione **Enter** na pergunta sobre branches ainda nao
declaradas. Isso permite uma proposta preliminar com a politica Git pendente.
Execute o prompt para identificar e planejar o lote; essa etapa nao aplica corretivas.

Ao entregar a proposta, o agente de planejamento deve solicitar a criacao da
branch do lote, sugerindo um nome associado ao ID e identificando a base analisada.
O desenvolvedor confirma o nome e cria a branch pelo fluxo Git da equipe. O agente
nao cria/troca branches nem concede GO. Uma branch ja comprovada para o mesmo lote
pode ser reutilizada; o cadastro do lote anterior nao autoriza o seguinte.

Depois de definir o lote e criar sua branch pelo fluxo Git da equipe, use
**Planejamento: conferir Git do lote**, escolha o projeto e **c** para cadastrar
principal, migracao, trabalho, responsavel e coordenacao. Prepare um **novo contexto**
e selecione o planejamento anterior para continuar o mesmo lote. Assim o novo
recibo registra a branch de trabalho e preserva a proposta anterior. Confira Git
novamente nesse contexto antes do GO e da execucao.

A rodada MTA continua vinculada ao commit e a branch em que foi produzida. Criar
a branch do lote no mesmo commit nao exige outro MTA apenas pela troca de nome,
mas exige conferir a equivalencia dos fontes e registrar o novo contexto. Se a
base avancou, inclusive com commits de colegas ou da principal, revise o diff e
reconcilie a proposta; gere novo MTA quando necessario para representar o codigo
que sera corrigido. Nunca atribua a branch/HEAD atual a uma rodada historica.

### Exemplo do ensaio: principal, migracao e lote

```text
main
  └─ main_jboss_eap74
       └─ lote/cache-hib-001
```

| Papel no cadastro | Nome neste ensaio | Uso |
| --- | --- | --- |
| Principal | `main` | Base consolidada e publicada; recebe as evolutivas normais. |
| Migracao | `main_jboss_eap74` | Integra os lotes de corretivas EAP 7.4 e acompanha a principal. |
| Trabalho autorizada | `lote/cache-hib-001` | Checkout do lote CACHE-HIB-001; alteracoes somente apos revisao e GO humano. |

Os nomes acima ilustram o cadastro depois que o lote estiver definido. Para
reiniciar o ensaio, mantenha somente `main` e `main_jboss_eap74`; a branch de lote
sera criada quando o planejador solicitar, apos a nova proposta. Siga a sequencia:
base limpa na `main`, branch de migracao, build/MTA, proposta e so entao branch do
lote a partir da base analisada. No cadastro, digite os
nomes acima ou escolha os numeros correspondentes na lista atual; os numeros
podem mudar. Informe tambem o responsavel e a referencia de coordenacao do lote.
O checkout deve estar na branch de trabalho autorizada antes de aplicar a corretiva.

Apos a corretiva, verificacoes e revisao humana, integre o lote na branch de
migracao e revalide o estado integrado. Novas evolutivas da principal precisam
ser conciliadas com a migracao. Somente depois do aceite e da reconciliacao com
novo MTA, mediante pedido, prepare outro lote em sua propria branch. A integracao
final na principal segue a politica de entrega da equipe; o harness nao faz merge.

As branches antigas `feat/application-maven-build` e
`fix/mta-hibernate-query-cache` foram removidas apos confirmar a integracao de seus
commits na `main`. Em qualquer limpeza futura, confira integracao local/remota e
ausencia de commits exclusivos ou checkout em uso antes de excluir uma branch.

### Comparar antes de alinhar ou integrar branches

Use o [guia de diagnostico com Git e TortoiseGit](diagnostico-branches-git-tortoisegit.md)
para conferir conteudo e historico nos tres sentidos do fluxo:

- **Principal -> EAP 7.4:** incorporar evolutivas e revalidar os lotes afetados.
- **Lote -> EAP 7.4:** revisar a corretiva aprovada e verificar o estado integrado.
- **EAP 7.4 -> principal:** entregar a migracao testada, com aceite final e
  validacao do commit resultante, antes da release e implantacao autorizadas em PRD.

O guia explica como escolher origem/destino, comparar pelo ancestral comum ou
pelos estados atuais e investigar no TortoiseGit. Diagnostico nao executa integracao;
merge nao publica a aplicacao em producao. Release/deploy seguem o processo da equipe.

### Cadastrar as escolhas

1. Em **Planejamento: preparar contexto para Copilot**, escolha projeto e rodada.
   Se ainda nao houver politica Git, digite **c**. Enter deixa a politica pendente
   e permite apenas proposta preliminar; q cancela.
2. Confira raiz, modulo e branch atual. Para principal, migracao e trabalho,
   informe o numero de uma branch local da lista ou digite o nome planejado.
   Principal deve ser diferente de migracao e trabalho.
3. Informe o responsavel e a referencia de coordenacao: issue, ticket ou
   identificador do ensaio individual. Confira o resumo e pressione Enter para salvar.
4. As escolhas ficam em `gitPolicies` no `config/harness.local.json`, vinculadas
   ao caminho absoluto `source`. Outros projetos e as ferramentas sao preservados.
   Para revisar escolhas existentes, use **Planejamento: conferir Git do lote**,
   selecione o projeto e digite **c**; depois prepare novo contexto.

O cadastro nao cria nem troca branches e nao realiza merge, commit, push ou fetch.
Se digitar uma branch ainda inexistente, ela permanecera pendente na conferencia.
A criacao e a integracao das branches pertencem ao fluxo Git acordado pela equipe.
Nao descarte alteracoes locais para liberar a conferencia.

### Conferir antes de executar ou retomar

1. Execute **Planejamento: conferir Git do lote** e escolha o projeto.
2. Pressione Enter para conferir; selecione o planejamento na lista.
3. Leia o resultado. **PENDENTE/BLOQUEADO** e exit code 1 exigem resolver a causa
   e reconciliar o planejamento. **OK** vale somente para Git; ainda sao necessarios
   o GO humano e as evidencias de dependencias, testes, qualidade e runtime do lote.

O recibo novo registra `Git`: raiz/modulo, branch, HEAD, estado local, instante e
politica declarada. `MtaGit`, quando disponivel, vem do manifesto da rodada MTA;
Git atual nao comprova a branch de uma rodada antiga. `VERIFIED` significa coleta
realizada, nao prontidao ou aprovacao. Contextos antigos sem Git continuam abrindo
para consulta, mas exigem novo contexto para essa conferencia.

A tarefa compara o estado atual com o registrado no planejamento e verifica a
branch autorizada, HEAD destacado, conflitos, operacoes Git e alinhamento das
referencias **locais** principal → migracao → trabalho. Alteracoes locais mantem
a conferencia pendente: esta versao nao registra aceite seletivo de um diff sujo.
O alinhamento com o remoto e a coordenacao de colegas continuam responsabilidade
da equipe. Abrir plano/to-do tambem mostra pendencias Git, sem impedir a consulta.

Essa verificacao ocorre quando a tarefa e executada, sem monitoramento continuo.
Build e MTA coletam o estado Git, mas nao exigem branch de corretiva para analisar
uma baseline. O harness ainda nao possui aplicador de corretivas: o executor deve
respeitar o resultado da conferencia antes de editar e antes de validar/integrar.

## Planejar lotes de correcao com Copilot

O [prompt planejar-lotes](../../.github/prompts/planejar-lotes.prompt.md) ja acompanha o clone. **Voce o aciona; ele nao executa automaticamente depois do MTA.** Seleciona o agente **devsquad** com leitura/busca (`read/readFile`, `search/listDirectory`, `search/fileSearch`, `search/textSearch`) e gravacao (`edit/createFile`, `edit/editFiles`). A escrita autorizada pelo prompt limita-se ao `plan.md` e `todo.md` de corretivas da solicitacao atual; fontes, POMs, evidencias e documentos do harness ficam fora desse escopo. Essa delimitacao vem das instrucoes, nao de uma restricao tecnica de pasta nas ferramentas: confira os destinos das edicoes. Nao ha ferramentas de terminal, tarefas, web ou delegacao. [Ferramentas do VS Code](https://code.visualstudio.com/docs/agents/reference/tools-reference).

O plugin DevSquad deve disponibilizar o agente `devsquad` no seletor e as skills
pertinentes ao planejamento. O prompt pede a leitura dessas skills e o relato das
que foram usadas, sem executar automaticamente implementacao, testes ou commits.
Confira agente e skills em **Chat: Open Customizations**; se nao estiverem disponiveis,
resolva a configuracao do plugin antes do ensaio. O harness nao instala o plugin.
O nome do agente no cabecalho e a prioridade das ferramentas do prompt seguem o
[contrato de prompt files](https://code.visualstudio.com/docs/agent-customization/prompt-files).

**Fluxo pratico:**

1. No workspace local salvo, execute **Terminal > Run Task > Planejamento: preparar contexto para Copilot**, da pasta `harness`, e escolha o projeto.
2. Confira projeto, fonte, data UTC e RunId no terminal. **Enter** usa a ultima rodada bem-sucedida com evidencias e integridade registradas; **h** lista o historico por data/resultado para escolher outra; **q** cancela. Uma tentativa mais recente indisponivel aparece como aviso. Sem rodada valida, conclua build e MTA antes de planejar.
3. Se ainda nao houver politica Git, escolha **c** para cadastrar as branches, **Enter** para deixa-las pendentes na proposta preliminar ou **q** para cancelar. Veja [branches e conferencia Git](#branches-e-conferencia-git).
4. Se houver propostas salvas desse projeto, escolha o planejamento anterior para continuar/comparar ou pressione **Enter** para iniciar um independente. A lista mostra o projeto, a data local de preparacao e a data do MTA, ambas com fuso, alem dos IDs; ter arquivos nao significa que a proposta foi aprovada.
5. A tarefa abre `planejar-lotes.prompt.md`. Confira o **Contexto selecionado pelo desenvolvedor**, ao final. Cada solicitacao fica sob `.harness/planning/`, organizada pelo nome do projeto e pelas datas do MTA e da preparacao, conforme abaixo. O `context.json` registra identidades completas, hashes das quatro evidencias principais e o vinculo anterior escolhido. Preparar contexto nao envia mensagens nem executa MTA.
6. Use o botao de executar o prompt no editor e escolha uma **nova conversa Copilot Local**, com modelo que ofereca ferramentas. Confira **devsquad**, as ferramentas de leitura/busca e `edit/createFile` / `edit/editFiles` em **Configure Tools**. Pode informar o objetivo na mensagem, por exemplo: "Planeje somente o lote para corrigir a limpeza do cache de consultas".
7. O Copilot deve planejar **um lote ativo por objetivo**, conferir seus POMs/dependencias e gravar **plan.md** e **todo.md** nos dois caminhos indicados pelo contexto. O chat apresenta os links e um resumo. Revise a proposta e as pendencias; grava-la nao autoriza implementar corretivas.

Se o botao de executar nao aparecer, abra uma nova conversa Local e use a linha `/planejar-lotes ...` exibida no terminal. Ela referencia o arquivo preparado, sem preencher varios caminhos manualmente. Contextos antigos sem destinos de escrita devem ser preparados novamente. Nunca use `input` como checkout de trabalho.

**Enter ou numero do planejamento anterior?** Ambos criam uma nova solicitacao. Enter inicia independente; o numero vincula o historico para comparar/continuar, sem sobrescreve-lo. Para continuar exatamente a mesma solicitacao, reabra seu prompt ja preparado. Se o lote anterior ainda nao foi aplicado ou aceito, peca reconciliar e manter o mesmo ID, sem criar outro lote.

**Planejamento progressivo e continuidade:** com milhares de ocorrencias, o agente registra apenas a cobertura realmente analisada e candidatas ainda nao detalhadas. O `plan.md` contem o objetivo e o escopo do lote ativo, dependencias, riscos, criterios e historico resumido. O `todo.md` contem as tarefas desse lote; nao e um checklist de todo o relatorio.

**Encontrar e abrir os documentos:** execute **Terminal > Run Task > Planejamento:
abrir plano e to-do**, confirme o workspace e escolha o projeto. Selecione o
planejamento pela data de preparacao e pela data MTA; os dois arquivos existentes
serao abertos no VS Code. `q` cancela. A tarefa nao prepara outro contexto nem
aciona o Copilot. Solicitações sem os dois documentos ainda nao aparecem na lista.

MTA, build e planejamento usam a mesma convencao (exemplo; sufixos abreviados):

```text
.harness/
  runs/migracao-cache-antes__<chave12>/
    mta_2026-09-26_09-55-07-0300__<RunId12>/
      manifest.json, result.json, console.log, input/, rules/, output/
  builds/migracao-cache-antes__<chave12>/
    build_2026-09-26_09-40-00-0300__<RunId12>/
      result.json, console.log
  planning/migracao-cache-antes__<chave12>/
    mta_2026-09-26_09-55-07-0300__<RunId12>/
      plano_2026-09-27_12-13-48-0300__<RequestId12>/
        plan.md, todo.md, context.json, planejar-lotes.prompt.md
```

O nome do projeto e sanitizado e limitado a 24 caracteres; a chave estavel distingue
projetos homonimos. As datas usam o fuso local da maquina, indicado no nome; a data
do plano e a de **preparacao**, nao a de conclusao pelo Copilot. IDs completos e
datas UTC permanecem no recibo. Os sufixos curtos reduzem o tamanho dos caminhos.
Pastas antigas com IDs continuam acessiveis pelo mesmo menu, sem renomeacao nem
alteracao de seus recibos ou vinculos. Sempre use os caminhos indicados no contexto.

**Compartilhar o relatorio:** copie a pasta `output/static-report` inteira para
fora de `.harness/runs`, usando um nome como
`migracao-cache-antes_2026-09-26_09-55-07-0300__b8913bad9ab84`. Preserve `assets/`,
`api/`, `output.js`, os demais scripts e arquivos ao lado de `index.html`.
Antes de compartilhar, abra o `index.html` da copia e confira o resumo, os achados
e a navegacao. Enviar somente o HTML perde dependencias; a copia serve para consulta
e nao substitui o snapshot, os recibos ou os caminhos de retomada do agente.
O harness nao publica nem envia arquivos automaticamente.

Verificacao em 2026-09-27: copia fora do repositorio com 23 arquivos e hashes
iguais aos originais. No ensaio guiado posterior, o desenvolvedor confirmou a
abertura e navegacao do relatorio da rodada das 15:15:54 e de sua copia externa.
Essa confirmacao vale para o ambiente ensaiado; confira a copia no destino ao
compartilhar. No Windows PowerShell 5.1, mantenha a raiz do
harness curta: nomes abreviados reduzem, mas nao eliminam limites de caminho em
snapshots com muitos niveis.

- Para revisar o mesmo lote na mesma rodada, reabra o mesmo prompt e peca a revisao. O agente le e atualiza os mesmos dois documentos, preservando identidade e historico.
- Apos implementar e validar um lote, execute novamente build/testes/MTA. Prepare contexto escolhendo **a nova rodada e o planejamento anterior**. Forneca explicitamente ao Copilot os caminhos dos resultados adicionais de build/testes/Sonar/EAP que deseja considerar.
- O novo plano usa o novo RunId e referencia o anterior, sem sobrescreve-lo. O agente reconcilia o lote anterior antes de propor outro: o que permanece, nao foi reencontrado, surgiu ou ficou inconclusivo. Ausencia de achado nao comprova aceite; mudancas de regras/perfil podem impedir comparacao.
- Peca explicitamente "reconcilie os resultados e planeje o proximo lote". GO para executar um lote nao autoriza os demais. O agente de planejamento continua sem executar comandos ou editar a aplicacao.

Os planos de corretivas sao arquivos locais ignorados pelo Git, distintos de `tasks/plan.md` e `tasks/todo.md`, usados para evoluir o harness. Uma nova preparacao cria nova solicitacao; nao muda o RunId de um plano existente. O harness confere os hashes das evidencias anteriores ao vincular uma proposta, mas o agente ainda precisa avaliar comparabilidade e resultados das validacoes.

A integridade registrada vale para o momento do MTA. O prompt informa que o checkout atual ainda nao foi verificado; o agente deve conferir os fontes pertinentes antes de usar achados antigos. O modelo continua sendo escolhido pelo desenvolvedor.

O contexto separa **premissas confirmadas**, **evidencias da rodada** e **verificacoes pendentes**. O perfil ja define EAP 7.4, Java 8/`javax.*` e Hibernate ORM 5.3 fornecido pelo servidor. O agente ainda deve conferir se a aplicacao usa essa dependencia, sua versao exata no ambiente e a API/comportamento da correcao candidata. Uma premissa nao equivale a uma verificacao executada. Ao atualizar o prompt do harness, execute novamente a tarefa de planejamento para gerar uma nova solicitacao; os arquivos preparados anteriormente permanecem intactos e nao e preciso repetir o MTA apenas por essa atualizacao.

**Cada lote exige conferencia dos POMs e dependencias afetadas:** versoes e sua origem, escopos, parent/BOMs/perfis pertinentes, transitivas, consumidores e impacto na compilacao, testes, WAR e runtime. O plano deve indicar ajustes de POM/propriedades ja demonstrados e estados separados para POM declarado, resolucao Maven, API/testes, empacotamento e runtime: **CONFERIDO NAS EVIDENCIAS**, **PENDENTE** ou **CONFLITO**. Sem evidencia da compatibilidade relevante, o lote permanece preliminar; conferir arquivos nao substitui build e testes na execucao autorizada.

A leitura pelos caminhos depende das ferramentas/permissoes do cliente; informar um caminho nao equivale a anexar seu conteudo. Confira a lista de arquivos efetivamente lidos na resposta. `.harness` e ignorada/oculta e pode nao aparecer no indice: o agente deve tentar a leitura direta do caminho informado, sem confundir ausencia na busca com arquivo inexistente.

**Se aparecer "nao ha ferramenta de leitura nesta conversa":** abra nova conversa Local, selecione um modelo com ferramentas e acione novamente `/planejar-lotes`; confira `read/readFile` em **Configure Tools**. Se o prompt continuar antigo, use **Developer: Reload Window** quando nao houver tarefas em andamento. Se as ferramentas nao existirem ou estiverem bloqueadas nessa instalacao, a configuracao/permissao do Copilot precisa ser resolvida com o suporte da empresa. Anexar uma pasta pode fornecer apenas referencias e nao resolve, por si so, a falta de ferramentas. Nao e necessario compactar ou reunir arquivos.

**Se `/planejar-lotes` nao aparecer:** confira se a pasta `harness` esta aberta no workspace e se `.github/prompts/planejar-lotes.prompt.md` existe no clone. Use **Chat: Open Customizations** para conferir descoberta/erros. Este fluxo usa sessao Local do VS Code; nao pressupoe compatibilidade com outros clientes. O desenvolvedor confirmou um ensaio de leitura e proposta pelo Copilot; os testes dos scripts verificam separadamente a preparacao do contexto e nao comprovam a interface em outras instalacoes. [Ferramentas do VS Code](https://code.visualstudio.com/docs/agents/reference/tools-reference).

Revise a triagem, a matriz de dependencias e o escopo do lote proposto antes de autorizar sua execucao. Arvore Maven, conteudo do WAR, modulos EAP e Sonar ANTES entram quando disponiveis e revisados; ausencia deve constar como pendencia, sem inventar evidencias. Nao misture rodadas nem exponha credenciais, settings privados ou logs brutos. A proposta tambem pode ser preparada por humano usando os mesmos criterios.

**Lote de correcao** e uma convencao deste projeto: ocorrencias correlacionadas com objetivo, solucao, aceite e reversao comuns. Mesma regra MTA nao basta para agrupar. Nao ha relacao obrigatoria de um apontamento = um lote = uma receita; preservar IDs e evidencias historicas chamados de "fatia".

O agente avalia receita OpenRewrite existente, composicao YAML/Refaster, receita Java propria ou ajuste especifico/combinado. Ausencia de receita pronta nao prova impossibilidade: considerar tipos/classpath, viabilidade, custo e reuso. Receita candidata precisa de testes, `dryRun`, revisao do patch e GO antes do `run`. Essa etapa prepara somente o plano; nao instala ou executa OpenRewrite. [Receitas](https://docs.openrewrite.org/concepts-and-explanations/recipes) e [dryRun/run](https://docs.openrewrite.org/reference/rewrite-maven-plugin).

Preservar Java 8, `javax.*`, arquitetura, contratos e baselines. **O corrigido sera testado somente no EAP 7.4; EAP 7.1 e referencia historica, sem exigir retrocompatibilidade.** Sonar e criterios de qualidade permanecem no plano de validacao; ausencia de Sonar nao bloqueia a proposta preliminar nem equivale a conformidade. Nao ha aceite, alteracao de codigo, commit/push ou proximo lote automaticos. Este prompt nao implementa Start/Stop/Deploy nem comprova o ciclo integrado.

**Ciclo de cada lote:** proposta -> revisao e GO humano -> agente aplica a corretiva
em etapa autorizada -> verificacoes automaticas -> revisao humana do resultado.
Falhas ou pendencias impeditivas mantem o lote em retrabalho. Apos o aceite, um
pedido de continuidade usa o novo MTA e o historico para identificar o proximo lote.
O prompt de planejamento continua limitado a proposta e reconciliacao.

Repita ate concluir todas as corretivas do escopo. A conclusao exige reconciliar a
cobertura acumulada com a rodada final comparavel, resolver pendencias e obter
aceite humano final; terminar um lote ou nao reencontrar um achado nao basta.

**Projeto e branch do ciclo:** registre o repositorio/modulo selecionado, principal
(por exemplo `develop` ou `main`), branch de migracao (`develop_jboss_eap74` ou
`main_jboss_eap74`), branch de trabalho autorizada, HEAD, estado local e responsavel.
Antes de aplicar ou retomar, confira a branch e o codigo atual da aplicacao;
a branch do harness nao identifica os demais projetos. Divergencia de branch
impede executar. Novos commits exigem reconciliar o lote, mesmo sem trocar de branch.

Outros desenvolvedores podem tratar lotes coordenados em branches de lote e
checkouts separados, integrando na branch de migracao. Mantenha essa branch
alinhada a principal e revalide o codigo integrado com novo MTA e demais criterios.
Um lote ativo e por frente de trabalho; os documentos locais nao coordenam a equipe
automaticamente. Veja a [ADR-0003](../../doc/adr/0003-projeto-branch-e-concorrencia-da-migracao.md).
A coleta e a conferencia Git estao descritas em [branches e conferencia Git](#branches-e-conferencia-git). A execucao continua dependendo de GO humano e das demais evidencias do lote.

## Limpar execucoes para repetir o ensaio

1. Termine build/MTA e preparacao de contexto. Encerre a conversa Copilot que usa
   os documentos a apagar; o harness nao controla o agente externo.
2. Execute **Workspace: limpar execucoes**. Escolha **1** para um projeto ou **2**
   para todos os projetos; **3** limpa somente backups temporarios de exercicios/ajustes.
   **q** cancela. Na opcao 1, selecione o projeto do workspace.
3. Confira os caminhos listados. Nas opcoes **1/2**, a limpeza inclui historicos MTA, relatorios,
   snapshots, builds e planejamentos, com prompts preparados, `plan.md`, `todo.md`
   e recibos. Os ponteiros relacionados tambem sao removidos. Na opcao **3**,
   apenas a pasta central de backups temporarios sera removida.
4. Digite **LIMPAR** para excluir. Enter ou outro texto cancela. Os scripts recusam
   links/junctions e caminhos fora das areas autorizadas, e bloqueiam limpeza
   concorrente com build/MTA/preparacao pelo harness.
5. Para recomecar, execute build → MTA → preparar contexto. Sem historico salvo,
   nao ha proposta anterior para selecionar.

A limpeza preserva configuracao, workspace, fontes, Git, template versionado do
prompt, cache Maven e backups. Nao apaga `target/` da aplicacao nem copias externas
de relatorios. No menu de projeto, o escopo vem do `Source` dos recibos, incluindo
pastas antigas e novas. Recibos invalidos bloqueiam a limpeza seletiva; pastas sem
recibo identificavel permanecem. A opcao todos remove as tres areas por inteiro.

Para somente listar, sem excluir, execute na raiz:

```powershell
powershell.exe -NoProfile -File .\scripts\limpar-execucoes.ps1 -All -Preview
```

Alteracoes permanentes do prompt devem estar em
`.github/prompts/planejar-lotes.prompt.md`. Uma edicao feita apenas no prompt
preparado pertence aquela solicitacao e sera apagada com ela. Para conservar um
resultado de ensaio, guarde antes uma copia fora das areas que serao removidas.

### Pastas locais e backups temporarios

`.harness/` guarda dados locais do harness e e ignorada pelo Git. As pastas sao
criadas conforme o uso; nao precisam existir todas depois de uma limpeza.
Build, MTA e planejamento organizam o historico por projeto, data/hora e ID,
conforme a arvore mostrada na secao de planejamento.

| Pasta | Finalidade |
| --- | --- |
| `.harness/builds/` | Registro de cada build Maven: `console.log` e `result.json`, com projeto, comando/fases, ferramentas, estado Git coletado, datas, status e exit code. O WAR/JAR e os relatorios de testes continuam no `target/` da aplicacao. |
| `.harness/runs/` | Rodadas MTA: `manifest.json` identifica entrada, argumentos, hashes e estado Git; `result.json` registra resultado/integridade; `console.log` guarda a saida. Cada rodada possui `input/` (copia dos fontes analisados), `rules/` (regras usadas) e `output/` (achados, dependencias e relatorio HTML com seus arquivos). A copia `input/` e evidencia, nao checkout para corretivas. |
| `.harness/planning/` | Solicitacoes de planejamento ligadas a uma rodada MTA: `context.json` com identidades, caminhos, hashes e vinculo anterior; `planejar-lotes.prompt.md` preparado; `plan.md` e `todo.md` gravados posteriormente pelo Copilot. Preparar contexto sozinho nao cria o plano/to-do nem aprova o lote. |
| `.harness/backups-temporarios/` | Unico local para copias temporarias de exercicios/ajustes, agrupadas por atividade. Opcao **3** da tarefa lista os caminhos e exige **LIMPAR**. |
| `.harness/workspace-backups/` | Copia automatica do workspace anterior quando o gerador o substitui; permite recuperar pastas e ajustes manuais. Preservada pela tarefa de limpeza. |
| `.harness/tests/` | Fixtures e resultados dos testes dos scripts; descartaveis quando nenhum teste estiver rodando. Recriada nos proximos testes. |
| `%USERPROFILE%\.m2\repository` | Repositorio local padrao do Maven, fora do harness; compartilhado com os demais projetos da maquina, salvo configuracao propria do Maven. |

Na raiz tambem podem aparecer **arquivos de controle**, que nao sao pastas:
`mta.lock` coordena build/MTA/limpeza; `planning.lock` coordena preparacao/limpeza.
Eles podem permanecer vazios depois da execucao; sua existencia nao comprova
atividade. `active-mta.json` identifica a rodada para acompanhamento, e
`last-<Project>.json` aponta para a ultima rodada MTA bem-sucedida do projeto.
Esses ponteiros nao substituem os manifestos nem os resultados salvos.

Os fontes continuam no repositorio da aplicacao; o JSON local em `config/`, o
workspace ativo na raiz do harness e o template em `.github/prompts/`. Os planos
de evolucao do harness permanecem em `tasks/`, separados dos planos de corretivas.

O ensaio anterior usou `.harness/maven/repository`; essa configuracao foi retirada
do ambiente local em 2026-09-27 para respeitar o padrao da maquina. O cache antigo
foi apenas movido para `backups-temporarios/maven-ensaio`, sem copiar/mesclar com
o repositorio padrao, e nao e mais usado pela configuracao do harness. A opcao 3
pode remove-lo junto aos demais temporarios; a pasta deixa de existir apos essa
limpeza. Artefatos instalados somente nesse
cache antigo precisam de novo build/install para aparecer no repositorio padrao.

As opcoes **1/2** limpam execucoes e preservam backups; a opcao **3** limpa somente
`backups-temporarios`, sem apagar execucoes ou backups do workspace. Nao criar
pastas de backup avulsas para cada ajuste na raiz de `.harness/`. Criar a pasta
central apenas quando houver algo a preservar. Agentes seguem essa regra em AGENTS.md.

Preview pelo terminal: `powershell.exe -NoProfile -File .\scripts\limpar-execucoes.ps1 -TemporaryBackups -Preview`.

## Documentacao e evolucao do harness

A [ADR-0002](../../doc/adr/0002-separacao-harness-e-migracao-progressiva.md) estabelece a
separacao entre **evoluir o harness** (scripts, prompts, Run Tasks e documentacao,
com plano/to-do em `tasks/`) e **migrar uma aplicacao** (lotes progressivos, com
plano/to-do nos destinos do contexto). [AGENTS.md](../../AGENTS.md) e as
[instrucoes do Copilot](../../.github/copilot-instructions.md) levam essa regra aos agentes.

O [README](../../README.md) e a entrada resumida. Este guia concentra o fluxo operacional. Os demais documentos possuem finalidades distintas:

| Local | Conteudo |
| --- | --- |
| `doc/guias/` | Apoio ao desenvolvedor, como a [apresentacao existente](../../doc/guias/Migracao_EAP_71_74_Plano_DevOps.pptx). O fluxo atual e o deste guia. |
| `doc/adr/` | Decisoes e justificativas, como [contexto local e acionamento do Copilot](../../doc/adr/0001-contexto-copilot.md). |
| `doc/especificacoes/` | Contratos duradouros do harness e criterios verificaveis, como [planejamento Copilot](../../doc/especificacoes/planejamento-copilot.md). |
| `doc/features/` | Problema, escopo e estado de cada evolucao, como [preparar planejamento](../../doc/features/planejamento-copilot.md). Referencia a especificacao, sem repeti-la. |
| `tasks/` | [Plano](../../tasks/plan.md) e [to-do](../../tasks/todo.md) do agente de codificacao para a evolucao atual do harness. |

Crie documentos apenas quando houver conteudo proprio: nao repetir o guia em uma feature nem o checklist de trabalho em uma especificacao. Os prompts em `.github/prompts/` sao instrucoes operacionais do agente; `.harness/` guarda artefatos locais de execucao. O plano do agente que evolui o harness e separado das propostas de corretivas das aplicacoes.

## Testar os scripts do harness

Estes testes verificam os scripts do harness; o build da aplicacao continua sendo uma etapa separada do fluxo.

Para Git e limpeza, execute `powershell.exe -NoProfile -File .\tests\Test-Git.ps1`
e `powershell.exe -NoProfile -File .\tests\Test-Cleanup.ps1`. Usam repositorios e
historicos de teste em `.harness/tests/`; nao trocam a branch nem apagam historicos
reais do desenvolvedor.

Para testar o planejamento, execute `powershell.exe -NoProfile -File .\tests\Test-Planning.ps1`. Verifica selecao de rodadas, isolamento por projeto, evidencia invalida, contexto fixo, pastas legiveis e compatibilidade com o historico antigo. Testa abertura de plano/to-do com editor simulado e cancelamento pela entrada real, sem iniciar Maven, MTA ou Copilot.

Para testar configuracao e analise: execute `powershell.exe -NoProfile -File .\tests\Test-Workspace.ps1` e `powershell.exe -NoProfile -File .\tests\Test-Mta.ps1`. Criam fixtures em `.harness/tests/`; o segundo simula a chamada ao processo MTA.

Para testar o build e sua configuracao: execute `powershell.exe -NoProfile -File .\tests\Test-Build.ps1` e `powershell.exe -NoProfile -File .\tests\Test-BuildConfig.ps1`. Verificam ferramentas separadas, Java 8, falhas, restauracao do ambiente e geracao do workspace, com chamadas de build simuladas.

Para testar o acompanhamento e o historico, execute `powershell.exe -NoProfile -File .\tests\Test-MtaLog.ps1`. Usa logs ficticios e verifica novas linhas durante a leitura e selecao de rodadas anteriores, sem executar MTA. `powershell.exe -NoProfile -File .\tests\Test-MtaActive.ps1` verifica a deteccao da analise ativa sem selecao de projeto e recusa registros antigos e builds como fonte de observabilidade MTA.

Para testar a selecao dos projetos do workspace, execute `powershell.exe -NoProfile -File .\tests\Test-Target.ps1`. Verifica o menu, packaging pom, padrao opcional, projetos homonimos, adicao/renomeacao e preservacao do JSON/workspace.

Para testar os argumentos das tarefas, execute `powershell.exe -NoProfile -File .\tests\Test-TaskInputs.ps1`. Verifica as entradas suportadas e executa o script real de build ate o menu, com caminho de workspace contendo espacos; cancela antes de iniciar Maven.
