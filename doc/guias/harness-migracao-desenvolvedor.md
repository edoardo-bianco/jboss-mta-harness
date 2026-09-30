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
| 4. Preparar planejamento | Rodada MTA e proposta anterior ou independente | Prompt e recibo com destinos exclusivos; Git informativo |
| 5. Acionar Copilot | Objetivo do lote; continuidade explicita quando houver historico | Um `plan.md` e um `todo.md`, ainda sem GO |
| 6. Revisar | Pendencias tecnicas, rota, escopo e criterios de aceite | GO humano separado; branch escolhida pelo desenvolvedor |
| 7. Aplicar e validar | Aplicacao: preparar implementacao do lote; selecionar plano/to-do com GO e executar o prompt | Diff, build/testes, qualidade e validacao funcional; aceite humano |
| 8. Continuar | Novo MTA e proposta anterior vinculada | Reconciliar o lote; proximo lote somente apos aceite e pedido |

Para consultar sem gerar outra solicitacao, use **Planejamento: abrir plano e to-do**.
A coleta Sonar tem a tarefa **Aplicacao: analisar SonarQube**; veja o
[roteiro Sonar local/corporativo](sonar.md). Deploy e controle do servidor
ainda nao sao automatizados aqui.

Navegacao: [configuracao](#comecar-na-maquina-de-trabalho) ·
[projetos](#escolher-o-projeto-em-cada-tarefa) ·
[branches](#branches-e-conferencia-git) ·
[build](#build-maven-da-aplicacao-com-java-8) ·
[MTA](#analise-e-resultados) ·
[Copilot e documentos](#planejar-lotes-de-correcao-com-copilot) ·
[exemplo de revisao](exemplo-revisao-lote.md) ·
[depois da revisao: GO, execucao e aceite](#da-proposta-revisada-a-execucao-e-ao-aceite) ·
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
2. Execute **Terminal > Run Task > Workspace: configurar caminhos**. A tarefa cria e abre `config/harness.local.json`. Em configuracoes existentes, acrescenta somente campos Sonar ausentes, preservando os valores ja informados; confira os [padroes e requisitos Sonar](sonar.md#configurar-uma-vez-por-maquina).
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
| Aplicacao: analisar SonarQube | `analisar-sonar.ps1` |
| Aplicacao: preparar implementacao do lote | `preparar-implementacao.ps1` |
| **MTA: executar analise** | **`executar-mta.ps1`** |
| **MTA: acompanhar log da analise** | **`acompanhar-log-mta.ps1 -Active`** |
| **MTA: acompanhar atividade interna** | **`acompanhar-log-mta.ps1 -Active -Detalhado`** |
| MTA: consultar log de execucao anterior | `acompanhar-log-mta.ps1 -SelectTarget -SelectRun -Once` (com workspace informado) |
| MTA: abrir ultimo relatorio | `abrir-relatorio-mta.ps1` |
| Workspace: conferir configuracao ao abrir | `conferir-ambiente.ps1 -AoAbrir` |
| Planejamento: preparar contexto para Copilot | `preparar-planejamento.ps1` |
| Planejamento: criar pasta de evidencias | `criar-pasta-evidencias.ps1` |
| Planejamento: abrir plano e to-do | `abrir-planejamento.ps1` |

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
  "sonar": {
    "serverUrl": null,
    "scannerJdkHome": null,
    "scannerVersion": "5.8.0.7211",
    "ceTimeoutSeconds": 300,
    "profiles": []
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
| `sonar` | Opcional no ciclo build/MTA; necessario para a task Sonar. URL, JDK do scanner, versao fixa e perfis conforme [guia Sonar](sonar.md). Nunca gravar token. |
| `mta.rulesPath` | `null` usa `rulesets/java` ao lado da CLI; preencha se as regras Java estiverem em outra pasta. |
| `mta.runsPath` | Pasta dedicada externa para novas rodadas, por exemplo `"C:/mta-runs"`. `null`/ausente mantem `.harness/runs`. |
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
O harness passa `-Djacoco.haltOnFailure=false`: cobertura abaixo da meta de 85%
gera aviso, sem quebrar o build. Testes, instrumentacao e relatorios continuam
ativos; erros de compilacao e testes reprovados continuam retornando falha.
Em Maven direto, use `mvn -Djacoco.haltOnFailure=false clean install`.
Se o POM fixar `haltOnFailure=true` ou outro plugin impuser um gate, ajuste essa
configuracao no escopo aprovado do projeto; a task nao edita o POM nem mascara erros.
Ao configurar JaCoCo no POM, preserve os limites e use `haltOnFailure=false`,
conforme a [documentacao do JaCoCo check](https://www.jacoco.org/jacoco/trunk/doc/check-mojo.html).
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

**Pasta curta externa para projetos com caminhos longos:** em **Workspace:
configurar caminhos**, acrescente/ajuste somente `runsPath` no bloco `mta` de
`config/harness.local.json`, preservando os outros campos:

```json
"runsPath": "C:/mta-runs"
```

Salve e execute novamente **MTA: executar analise**. Nao precisa mover o harness
nem alterar o workspace. A pasta precisa permitir escrita ao seu usuario e ficar
fora do harness e dos projetos. Novas rodadas usam
`C:/mta-runs/<nome-projeto>/yyMMdd-HHmmss/`, por exemplo
`C:/mta-runs/SIMTR-Outsourcing-api/260930-151210/`, com `input`, `rules`, `output`,
logs e recibos. A data/hora usa o horario local; o instante UTC e o RunId completo
continuam no manifesto. Horarios repetidos recebem `-2`, `-3` etc., sem sobrescrever.
O nome do projeto usa o rotulo do workspace/configuracao, com caracteres seguros
e limite de 64 caracteres. Nomes iguais de projetos/fontes diferentes recebem
sufixos numericos. `project.json` na pasta do projeto identifica `Label`, `Project`
e `Source`; `manifest.json` em cada rodada registra tambem o Git observado.
Nomes dos fontes e estrutura dos modulos sao preservados. A pasta local da rodada
guarda `location.json`, incluindo o caminho relativo do destino externo.
Logs, relatorio e planejamento resolvem essa referencia, inclusive apos trocar
`runsPath` ou voltar a null. Historico existente nao e movido nem reescrito.
Rodadas externas anteriores em `p__<chave12>/<RunId>/` continuam acessiveis.
Na limpeza, a pasta do projeto e seu `project.json` permanecem; somente as rodadas
registradas e selecionadas sao removidas, preservando a identificacao para reuso.
Preserve as referencias locais junto com a pasta externa; nao mova rodadas a mao.

O snapshot usa caminhos estendidos internamente para enumerar/copiar/calcular
SHA-256 acima de 260 caracteres no PowerShell 5.1; manifestos e comandos MTA
mantem caminhos normais. A pasta externa curta tambem reduz o caminho recebido
pelo MTA/Java. Isso nao certifica todos os limites das ferramentas externas:
confira `Status`, exit code e integridade na nova rodada real do projeto.

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

A partir da [ADR-0004](../adr/0004-git-informativo-sem-controle-de-branches.md),
**o desenvolvedor escolhe a branch em que quer trabalhar**. O harness registra
branch/commit automaticamente quando disponiveis, apenas como referencia.
Nao ha cadastro de principal/migracao/trabalho, responsavel ou coordenacao.
A tarefa `Planejamento: conferir Git do lote` foi removida; nao e uma etapa pendente.

### Fluxo direto para a aplicacao

1. Crie/selecione sua branch usando Git, VS Code ou TortoiseGit, conforme seu fluxo.
2. Execute build/MTA quando necessario para obter evidencias do codigo analisado.
3. Prepare contexto escolhendo projeto, rodada e proposta anterior, se for continuidade.
4. Execute o prompt e informe a branch desejada ao agente, se pertinente.
5. Revise a proposta, resolva pendencias tecnicas e de GO separado para corretivas.

Troca de branch/HEAD nao exige novo cadastro, novo contexto ou MTA por si so.
O mesmo MTA pode continuar pertinente se fontes, POMs e configuracoes relevantes
permanecerem iguais. Quando o codigo mudar, avalie a aplicabilidade dos achados
antes de reaplicar uma proposta. Depois de corretivas aceitas e integradas,
novo MTA e reconciliacao dos resultados orientam o proximo lote solicitado.

Git atual e MtaGit historico permanecem separados nos recibos. `VERIFIED` indica
coleta realizada; `UNAVAILABLE` indica ausencia de observacao, sem bloquear o
planejamento. O harness nao compara politica de branches nem concede prontidao
para execucao. Conflitos, integracao e coordenacao pertencem ao desenvolvedor.
Preserve alteracoes locais e obtenha GO antes de aplicar corretivas.

### Branch exclusiva para alterar o harness

A simplificacao da migracao nao muda o fluxo de desenvolvimento deste repositorio:
crie/retome `harness/<objetivo>` a partir da main, revise/teste e integre a entrega.
Com migracao em andamento, use checkout/worktree separado e preserve a branch
usada pelo desenvolvedor. No ensaio em repositorio unico, alinhe explicitamente
main -> main_jboss_eap74 e a branch de trabalho pertinente apos validar a entrega.
Nao desenvolva o harness diretamente nas branches de corretivas.

Os exemplos compartilham o repositorio do harness: a branch vale para o checkout
inteiro. Em outros projetos do workspace, a coleta parte da raiz real da aplicacao.
Nunca use a branch do harness para identificar outro repositorio.

### Historico e transicao

Configuracoes antigas com `gitPolicies` continuam legiveis, mas o campo e ignorado.
Nao e necessario editar o JSON local. Recibos/planos/prompts antigos permanecem
intactos. Para adotar o contrato novo, prepare uma solicitacao vinculada ao plano
anterior e execute o prompt atualizado uma vez. Depois, mudar branch nao exige
repetir esse processo. Pendencias do cadastro/gate antigo ficam SUPERADAS no plano
novo; pendencias tecnicas e o ID do lote sao preservados. Isso nao concede GO.

Para consultar Git por iniciativa propria, veja o
[guia Git/TortoiseGit](diagnostico-branches-git-tortoisegit.md). Ele oferece
procedimentos de diagnostico e integracao da equipe, sem controle pelo harness.

## Planejar lotes de correcao com Copilot

O [prompt planejar-lotes](../../.github/prompts/planejar-lotes.prompt.md) ja acompanha o clone. **Voce o aciona; ele nao executa automaticamente depois do MTA.** Seleciona o condutor **devsquad** com delegacao (`agent`), leitura/busca (`read/readFile`, `search/listDirectory`, `search/fileSearch`, `search/textSearch`) e gravacao (`edit/createFile`, `edit/editFiles`). O condutor delega a elaboracao a **devsquad.plan**, que usa as skills e devolve os textos; o condutor confere, grava e rele somente `plan.md` e `todo.md` da solicitacao. [Ferramentas do VS Code](https://code.visualstudio.com/docs/agents/reference/tools-reference).

O contrato do prompt adapta o fluxo generico do plugin ao lote MTA: nao gera
specs, ADRs, diagramas ou board. O planejador trabalha por leitura/busca e nao
grava nem subdelega; nao e necessario habilitar subdelegacoes no VS Code.
Fontes, POMs, evidencias e documentos do harness ficam fora do escopo de escrita.
Terminal, tarefas, web, Git e implementacao permanecem proibidos para ambos.
Agentes personalizados podem expor ferramentas proprias; esses limites sao
instrucoes, nao uma sandbox tecnica herdada: confira chamadas e destinos das edicoes.
Veja o [contrato de subagentes Local](https://code.visualstudio.com/docs/agents/run/subagents).

O plugin DevSquad deve disponibilizar `devsquad`, `devsquad.plan` e as skills
pertinentes ao planejamento. O prompt pede a leitura dessas skills e o relato das
que foram usadas, sem executar automaticamente implementacao, testes ou commits.
Confira agente e skills em **Chat: Open Customizations**; se nao estiverem disponiveis,
resolva a configuracao do plugin antes do ensaio. O harness nao instala o plugin.
O nome do agente no cabecalho e a prioridade das ferramentas do prompt seguem o
[contrato de prompt files](https://code.visualstudio.com/docs/agent-customization/prompt-files).

**Fluxo pratico:**

1. No workspace local salvo, execute **Terminal > Run Task > Planejamento: preparar contexto para Copilot**, da pasta `harness`, escolha o projeto e **1. Planejar lote (/planejar-lotes)**. Para revisar uma proposta com evidencias, escolha **2. Revisar lote (/revisar-lote)** e siga [revisao com evidencias](#revisar-um-lote-com-evidencias-complementares).
2. Confira projeto, fonte, horario local com fuso e RunId no terminal. O menu usa o fuso do Windows (por exemplo, `17:05:53 -03:00`); os recibos preservam UTC (`20:05:53Z` representa o mesmo instante). **Enter** usa a ultima rodada bem-sucedida com evidencias e integridade registradas; **h** lista o historico por data/resultado para escolher outra; **q** cancela. Uma tentativa mais recente indisponivel aparece como aviso. Sem rodada valida, conclua build e MTA antes de planejar.
3. Nao ha pergunta de politica Git. Branch/commit sao registrados como referencia; o desenvolvedor escolhe onde trabalhar. Veja [branches e conferencia Git](#branches-e-conferencia-git).
4. Se houver propostas salvas desse projeto, escolha o planejamento anterior para continuar/comparar ou pressione **Enter** para iniciar um independente. A lista mostra o projeto, a data local de preparacao e a data do MTA, ambas com fuso, alem dos IDs; ter arquivos nao significa que a proposta foi aprovada.
5. A tarefa abre `planejar-lotes.prompt.md`. Confira o **Contexto selecionado pelo desenvolvedor**, ao final. Cada solicitacao fica sob `.harness/planning/`, organizada pelo nome do projeto e pelas datas do MTA e da preparacao, conforme abaixo. O `context.json` registra identidades completas, hashes das quatro evidencias principais e o vinculo anterior escolhido. Preparar contexto nao envia mensagens nem executa MTA.
6. Use o botao de executar o prompt no editor e escolha uma **nova conversa Copilot Local**, com modelo que ofereca ferramentas. Confira **devsquad**, **Run Subagent (`agent/runSubagent`)**, leitura/busca e `edit/createFile` / `edit/editFiles` em **Configure Tools**. Pode informar o objetivo: "Planeje somente o lote para corrigir a limpeza do cache de consultas".
7. Confira no chat a chamada a **devsquad.plan** e o relato das skills utilizadas. O especialista deve elaborar **um lote ativo por objetivo**, conferir POMs/dependencias e devolver os dois textos. O condutor grava e rele **plan.md** e **todo.md** nos caminhos do contexto e apresenta os links. Revise a proposta e as pendencias; grava-la nao autoriza implementar corretivas.

**Se o DevSquad disser que nao pode gravar por ser condutor:** confira se o prompt
preparado tem a secao **Delegacao delimitada ao planejador DevSquad** e `agent`
na lista de ferramentas. Prompts antigos sao copias historicas e nao se atualizam
com o template. Prepare uma nova solicitacao para testar uma versao nova; preserve
a anterior e vincule-a se ja contiver proposta. Nao repetir build/MTA somente para
trocar o prompt: confira a integridade e a diferenca de codigo/HEAD antes de reutilizar
a rodada como evidencia historica. Nunca atribua ao MTA antigo o novo HEAD.
Se a ferramenta ou especialista faltar, ajuste a sessao/plugin antes da triagem.
Uma resposta so no chat nao conclui a persistencia; use **abrir plano e to-do**
para conferir os dois documentos depois. Relate qualquer acao fora do contrato.

Se o botao de executar nao aparecer, abra uma nova conversa Local e use a linha `/planejar-lotes ...` exibida no terminal. Ela referencia o arquivo preparado, sem preencher varios caminhos manualmente. Contextos antigos sem destinos de escrita devem ser preparados novamente. Nunca use `input` como checkout de trabalho.

**Enter ou numero do planejamento anterior?** No modo Planejar lote, ambos criam uma nova solicitacao. Enter inicia independente; o numero vincula o historico para comparar/continuar, sem sobrescreve-lo. No modo Revisar lote, a escolha do anterior e obrigatoria; Enter cancela sem preparar contexto. Para continuar exatamente a mesma solicitacao, reabra seu prompt ja preparado. Se o lote anterior ainda nao foi aplicado ou aceito, peca reconciliar e manter o mesmo ID, sem criar outro lote.

**Planejamento progressivo e continuidade:** com milhares de ocorrencias, o agente registra apenas a cobertura realmente analisada e candidatas ainda nao detalhadas. O `plan.md` contem o objetivo e o escopo do lote ativo, dependencias, riscos, criterios e historico resumido. O `todo.md` contem as tarefas desse lote; nao e um checklist de todo o relatorio.

**Revisar sem deixar instrucoes contraditorias:** o planejador deve substituir as
orientacoes antigas incompativeis nos documentos atuais e o condutor deve conferir
o plano e o to-do completos, incluindo resumo, riscos e tarefas. Precondicoes e GO
antecedem a implementacao; verificacoes do artefato corrigido antecedem o aceite.
Adicionar uma secao nova nao encerra a revisao se outra ainda exigir o contrario.
Para adotar essa instrucao em uma proposta existente, prepare novo contexto com a
mesma rodada e selecione o planejamento anterior. Preserve o ID do lote e os
documentos anteriores; nao e necessario repetir MTA apenas por atualizar o prompt.

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

**Compartilhar o MTA para gerar um plano novo:** envie a pasta completa da rodada
(por exemplo `260930-154744`, com `manifest.json`, `result.json`, `input`, `rules`
e `output`). O destinatario extrai em uma pasta local e usa **Planejamento:
preparar contexto para Copilot**, seleciona o projeto local e a operacao planejar.
Na selecao da rodada, digita **p** e informa a pasta extraida. Funciona mesmo sem
historico MTA local. Para proposta independente, Enter no planejamento anterior.
Nao e necessario copiar `.harness`, registrar/importar a rodada ou executar outro
MTA somente por mudar de maquina. A pasta recebida nao e modificada nem incluida
na limpeza de rodadas locais; mantenha-a no caminho informado enquanto for usada.

O contexto novo referencia o RunId original e separa `MtaOrigin` (identidade e
raiz historicas), `AnalysisSource` (input recebido) e `Source` (projeto local).
Nao exige igualdade de caminhos, IDs derivados de caminho ou branches entre
origem e destino. Compare o projeto escolhido pelo nome e pelo POM: o harness
le `groupId:artifactId` do POM raiz, incluindo groupId herdado do parent, e mostra
`version` separadamente. Diferencas ou propriedades nao resolvidas geram apenas
ALERTA, sem impedir a proposta; essa leitura nao executa Maven/effective-pom.
Novos recibos de planejamento nao coletam Git/branch/checkout para validacao.

O agente parte dos fontes da rodada e verifica os pontos correspondentes nos
fontes/POMs/testes locais. Se o trecho mudou, registra alerta no plano e no to-do,
explica o que ainda se aplica e recomenda novo MTA para atualizar o diagnostico,
continuando a proposta dos pontos verificaveis. O harness nao faz sozinho essa
comparacao semantica. GO e aceite continuam separados. Rodada incompleta ou
manifesto/resultado de IDs diferentes continuam sendo erros de entrada.

Pela linha de comando, use `preparar-planejamento.ps1 -RunPath <pasta-extraida>`
com o workspace/projeto local, `-NewPlan` e `-NoOpen` se desejar apenas preparar.
Use RunPath ou RunId do historico, nunca ambos. Planos anteriores permanecem intactos.

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

**POM e Hibernate do destino:** para lote que migra Hibernate para EAP 7.4, o
plano deve incluir os POMs afetados e o to-do deve conter a tarefa de alinhar
compilacao e testes ao Hibernate ORM 5.3 fornecido por esse servidor. A versao
exata depende do modulo/patch de destino; nao basta escolher qualquer 5.3 nem
copiar a versao de outro exemplo. Conferir propriedade/parent/BOM, hibernate-core
e integracoes usadas nos testes, preservando provided/test e evitando duplicatas
no WAR. Sem evidencia, a versao exata fica pendente, mas a tarefa continua no lote.
Build que ainda resolve 5.1 nao comprova a migracao para 5.3. Para concluir, registrar
a versao resolvida e os resultados de clean install Java 8, testes/cobertura e WAR.
Dispensar a confirmacao previa do ambiente nao elimina essa entrega de implementacao.

**Checklist do desenvolvedor (nao bloqueante):** Sonar ANTES/DEPOIS e nova rodada
MTA ficam como tarefas [ ] pendentes ate a execucao. Sua ausencia nao impede GO,
implementacao, entrega da corretiva ou submissao ao aceite e nao exige dispensa.
Nao marcar como feitas nem alegar comparacao sem baseline; o desenvolvedor decide
o aceite com as pendencias visiveis. Cobertura <85% e aviso, nao bloqueio.
Resultados Sonar coletados mantem Blocker/High reprovados na avaliacao, avisos de
cobertura/aumento de issues e Quality Gate do servidor registrado separadamente.

Repita ate concluir todas as corretivas do escopo. A conclusao exige reconciliar a
cobertura acumulada com a rodada final comparavel, resolver pendencias e obter
aceite humano final; terminar um lote ou nao reencontrar um achado nao basta.

**Projeto e branch do ciclo:** preserve Project/Source e os destinos do contexto.
O desenvolvedor escolhe a branch; branch/HEAD observados sao referencias. Nao
cadastrar papeis ou gerar bloqueios por diferenca Git. Conferir conteudo relevante
da aplicacao para avaliar se os achados ainda se aplicam. A coordenacao de frentes
fica com a equipe; revalide tecnicamente o codigo integrado antes de aceita-lo.
Veja a [ADR-0004](../adr/0004-git-informativo-sem-controle-de-branches.md).

### Revisao manual do plano e do to-do

**Qual opcao usar?** Ambas ficam na task **Planejamento: preparar contexto para
Copilot**. A opcao 1 tambem permite revisar documentos anteriores; a diferenca
da opcao 2 e receber explicitamente o indice das evidencias complementares.

| Necessidade | Opcao | Previous | Prompt a executar |
| --- | --- | --- | --- |
| Criar uma proposta independente | 1. Planejar lote | Sem anterior; Enter inicia independente | planejar-lotes.prompt.md |
| Revisar/continuar com MTA e observacoes salvas no plano/to-do | 1. Planejar lote | Selecionar a proposta com o feedback salvo | planejar-lotes.prompt.md |
| Revisar o lote com plano/to-do e arquivos listados no LEIA-ME | 2. Revisar lote | Obrigatorio, junto com o caminho do indice | revisar-lote.prompt.md |

No modo 1, o indice complementar nao e solicitado. No modo 2, a proposta anterior
e obrigatoria mesmo que o indice contenha somente observacoes. Em ambos, uma nova
preparacao cria outra solicitacao e preserva os documentos anteriores. Nenhuma
opcao concede GO nem executa corretivas. Se mudou somente o feedback, reutilize
a rodada MTA pertinente. Para retomar um contexto ja preparado, reabra o prompt.

Para apresentar o fluxo, siga o [exemplo limpo de revisao de lote](exemplo-revisao-lote.md),
com feedback para os dois documentos, tabela preenchida do LEIA-ME e pontos de conferencia.

O desenvolvedor revisa a proposta antes de autorizar corretivas. Para registrar
suas observacoes e receber uma nova versao com historico preservado:

1. Execute **Planejamento: abrir plano e to-do** e escolha a solicitacao a revisar
   pela data e pelo RequestId. Confira objetivo, escopo, dependencias, riscos,
   criterios de aceite e ordem das tarefas nos dois arquivos.
2. Edite manualmente o `plan.md` e/ou `todo.md` dessa solicitacao, em uma secao
   **Observacoes do desenvolvedor - revisao pendente**. Registre data, trecho a
   corrigir e resultado esperado. Use o plano para decisoes/escopo e o to-do para
   tarefas/ordem; nao e necessario duplicar a mesma observacao nos dois arquivos.
   Preserve identidade, ID do lote e evidencias. Uma observacao nao significa GO
   nem tarefa executada: mantenha a proposta nao aprovada e nao marque `[x]` sem evidencia.
3. Salve os arquivos **antes** de executar **Planejamento: preparar contexto para
   Copilot**. Escolha o mesmo projeto, **1. Planejar lote** para este percurso de
   feedback documental sem indice e, para uma revisao apenas documental, a mesma
   rodada MTA. Nao e necessario repetir build/MTA so para revisar o plano.
4. Na pergunta do planejamento anterior, digite o numero da solicitacao que acabou
   de editar. **Enter inicia independente** e nao vincula suas observacoes.
   No novo prompt, confira se `Previous.RequestId` aponta para a solicitacao correta.
5. Execute o novo prompt em uma **nova conversa Copilot Local**, com `devsquad`,
   informando que suas observacoes sao o pedido de revisao. Pode usar o texto abaixo.
6. O agente le os documentos selecionados como `Previous`, mantem o mesmo lote e
   grava a versao revisada nos novos `PlanPath`/`TodoPath`. Reabra esses documentos,
   confira se cada observacao foi atendida ou justificada e se plano e to-do estao
   consistentes. Os anteriores permanecem preservados. Se precisar de outra revisao,
   repita o ciclo sobre a versao mais recente que deseja continuar.
7. Quando estiver satisfeito e as precondicoes tecnicas estiverem resolvidas,
   registre GO explicito para o lote e escopo. Aplicar corretivas e uma etapa
   separada; o agente de planejamento continua limitado aos dois documentos.

Texto para acompanhar a execucao do novo prompt:

```text
Revise o mesmo lote considerando minhas observacoes de revisao pendente nos
documentos selecionados em Previous. Trate essas observacoes como meu pedido de
revisao dentro do escopo do prompt. Atualize plano e to-do de forma consistente,
preserve o historico e mantenha PROPOSTA - NAO APROVADA. Informe o atendimento ou
a justificativa para cada observacao. Nao aplique corretivas.
```

O prompt referencia os arquivos anteriores; nao incorpora automaticamente suas
observacoes como texto. Na preparacao, o recibo registra os hashes dos documentos
salvos naquele momento. Depois de vincula-los, preserve essa versao anterior;
novas observacoes entram na proxima revisao. Nao edite `context.json`, hashes ou
evidencias MTA para registrar comentarios. Nao use `tasks/` do harness para isso.

**Como identificar Previous depois de uma pausa:** use **Planejamento: abrir plano
e to-do**, escolha o projeto e confira lote, observacoes e pendencias nos documentos.
Leia o `RequestId` no cabecalho do plano que deseja revisar. Ao preparar o novo
contexto, encontre esse valor no campo **Solicitacao** do menu e digite o numero
da opcao correspondente. O horario **Planejado** identifica a preparacao do contexto,
nao a ultima edicao do plano. Nao selecione automaticamente o mais recente.

| Onde aparece | O que identifica |
| --- | --- |
| RequestId do plano / Solicitacao no menu | A proposta a revisar |
| Previous.RequestId no novo contexto | A proposta escolhida no menu |
| RunId | A rodada MTA |
| ID do lote, por exemplo HIB-CACHE-001 | O lote, preservado entre revisoes |

Exemplo: se o plano tem `RequestId: 581722d0364f467b828edb2bdc429946` e esse
valor aparece na opcao **1**, digite **1**. A task preenche `Previous.RequestId`
com esse identificador completo. `581722d0364f` e apenas sua abreviacao na pasta.
Use o RequestId do plano, mesmo que o Previous dele seja null. Nao edite
`context.json` manualmente para preencher Previous.

**Conferir e corrigir o resultado da revisao:** releia ambos os documentos,
incluindo resumo, pendencias e criterios de aceite. Confirme que cada observacao
foi atendida ou justificada. Sonar/baseline e reexecucao MTA ficam no checklist
nao bloqueante: a ausencia nao impede implementar/entregar nem exige dispensa.
O exemplo historico do cache exigia baseline previo e aprovacao do Quality Gate;
essa exigencia nao deve ser reproduzida como bloqueio automatico nos novos planos.
Resultados coletados e pendencias continuam visiveis para o aceite humano.

Para corrigir omissao/contradicao na entrega recem-gerada, ainda nao vinculada
como Previous de outra solicitacao, peca na mesma conversa uma correcao documental
somente nos PlanPath/TodoPath atuais e nova releitura integral. Nao e necessario
repetir a task, o build ou o MTA por esse ajuste. Para uma nova rodada de revisao
com historico separado, salve o feedback na proposta escolhida e prepare outro
contexto com ela em Previous. Preserve sempre as versoes ja vinculadas.

O relato do agente nao substitui a conferencia dos arquivos. Se uma chamada
exibida no chat nao puder ser inspecionada, registre o que nao foi verificado,
sem presumir conformidade ou falha. Isso nao comprova testes nem concede GO.

### Revisar um lote com evidencias complementares

Use o prompt [revisar-lote](../../.github/prompts/revisar-lote.prompt.md) quando
ja existir plano/to-do e voce quiser considerar, junto ao MTA, outras evidencias:
arvore Maven, resultados de testes, exportacao Sonar, informacoes do EAP ou
observacoes tecnicas. O planejamento inicial continua com `planejar-lotes`.
A revisao mantem o mesmo lote; nao aplica corretivas nem concede GO.

Use a mesma task **Planejamento: preparar contexto para Copilot**, escolhendo
**2. Revisar lote (/revisar-lote)**. Nesse modo, selecione obrigatoriamente uma
proposta com plan.md/to-do salvos e informe o caminho do **LEIA-ME.md preenchido**.
A task verifica a existencia do indice; o agente confere identidade, arquivos
listados e pertinencia das evidencias. Nenhuma evidencia complementar recebe hash.

O editor abre **revisar-lote.prompt.md**, ja com os caminhos do contexto-base e
do indice. Use **Executar Prompt** em nova conversa Copilot Local com `devsquad`
ou copie a chamada **/revisar-lote** exibida no terminal. O arquivo
`planejar-lotes.prompt.md` da mesma pasta e o contexto-base; execute somente
o prompt de revisao. A task prepara os arquivos, mas nao aciona o agente.

Se a revisao ja foi preparada, reabra esse prompt; outra preparacao cria outra
solicitacao. Contextos antigos com Previous continuam utilizaveis com a chamada
manual de /revisar-lote e os dois caminhos explicitos, como no exemplo abaixo.
Nao e necessario repetir build/MTA ou substituir um contexto valido por essa melhoria.

Execute **Terminal > Run Task > Planejamento: criar pasta de evidencias**.
Informe o workspace em uso e escolha o projeto. A tarefa cria uma pasta nova,
abre o `LEIA-ME.md` no VS Code e informa os caminhos no terminal. Project, nome,
Source e data sao preenchidos; voce completa o ID do lote e o objetivo. A tarefa
nao exige MTA previo e nao escolhe o planejamento nem coleta arquivos.

**Coloque as evidencias manualmente** na pasta criada, pelo Explorer do Windows
ou do VS Code. Estrutura ilustrativa:

```text
.harness/evidencias/
  migracao-cache-antes__97a5fc995901/
    evidencias_2026-09-28_16-10-00-0300__<id12>/
      LEIA-ME.md
      runtime.md
      arvore-maven.txt
      testes.xml
      sonar.json
```

Os nomes de arquivos acima sao exemplos, nao resultados fornecidos pelo harness.
O nome do projeto segue o mesmo padrao de `.harness/planning/` e `runs/`;
sua chave identifica o projeto, nao os arquivos adicionais. A pasta usa data/hora
com fuso e um ID aleatorio para evitar sobrescrita em execucoes no mesmo segundo.
Cada execucao cria outra pasta; para continuar preenchendo uma existente, reabra
seu LEIA-ME pelo caminho completo (Ctrl+P), sem repetir a tarefa. `.harness` pode
estar oculta no Explorer do VS Code. O [modelo de indice](modelo-evidencias-complementares.md)
tambem permite criar a estrutura manualmente, mantendo pastas antigas sem o ID final.

#### Percurso de feedback com nova rodada MTA

1. Abra o plano/to-do existentes com **Planejamento: abrir plano e to-do**.
   Registre seu feedback em **Observacoes do desenvolvedor - revisao pendente**
   e salve. Preserve identidade, ID do lote, historico e decisoes anteriores.
2. Execute **Aplicacao: build Maven (Java 8)** para o projeto, com `clean install`.
   Apos sucesso, execute **MTA: executar analise** para o mesmo projeto e aguarde
   `SUCCEEDED`. Esta sera a nova rodada a selecionar na revisao.
3. Execute **Planejamento: criar pasta de evidencias** e preencha o LEIA-ME.
   Coloque ali somente os arquivos pertinentes. Liste cada caminho relativo no
   indice, origem, data real de coleta, ambiente, artefato/versao e o que pretende
   verificar. Use PENDENTE para dados desconhecidos. Forneca exportacoes e trechos
   sem segredos, nao logs brutos ou settings privados. Salve tudo antes de iniciar.
   Nao copie o relatorio MTA para essa pasta: o contexto ja referencia a rodada.
4. Execute **Planejamento: preparar contexto para Copilot**, escolha o mesmo
   projeto, **2. Revisar lote**, a **nova rodada MTA** e **selecione o planejamento
   anterior** que contem seu feedback. Informe o caminho do LEIA-ME preenchido.
   Confira `Previous.RequestId` no contexto-base preparado. A selecao anterior
   e obrigatoria nesse modo: `Previous` deve apontar para o
   plano/to-do que quer revisar. O RunId atual identifica o novo MTA; Previous
   preserva o plano, o to-do e a rodada historica escolhidos, sem substitui-los.
5. Em nova conversa Copilot Local com `devsquad`, execute o `revisar-lote.prompt.md`
   aberto pela task ou copie a chamada `/revisar-lote` apresentada no terminal.
   Os caminhos do contexto-base e do indice ja estao preenchidos. Para contextos
   antigos, use a chamada manual abaixo. Nao execute tambem `planejar-lotes`.
   A tarefa de evidencias so cria a estrutura;
   a revisao e acionada por voce no chat, nao pela Run Task.
6. O condutor delega a `devsquad.plan`, que le o MTA, o plano/to-do anteriores e os
   arquivos listados. O condutor grava somente os novos PlanPath/TodoPath e rele
   ambos. Confira o que mudou, evidencias consideradas, lacunas, criterios e ordem
   das tarefas. Exija que cada observacao seja atendida ou justificada e que
   contradicoes sejam corrigidas em ambos. A revisao continua **PROPOSTA - NAO
   APROVADA**. Voce decide o GO para executar; depois das corretivas e verificacoes,
   o aceite do resultado tambem e seu. Revisar nao inicia outro lote automaticamente.

Se mudou somente o feedback documental, pode pular o passo 2 e selecionar o MTA
existente no passo 4. Novas evidencias por si so nao exigem nova rodada; mudancas
tecnicas relevantes na aplicacao podem exigir reanalise. Nao limpe as execucoes
durante essa continuidade: o fluxo usa os documentos e evidencias anteriores.

Substitua os dois caminhos do exemplo pelos arquivos reais; nao envie placeholders:

```text
/revisar-lote Use o contexto do arquivo "CAMINHO_ABSOLUTO/planejar-lotes.prompt.md"
e as evidencias listadas em "CAMINHO_ABSOLUTO/LEIA-ME.md".
Reavalie o mesmo lote considerando o MTA selecionado, o plano/to-do de Previous,
minhas observacoes nesses documentos e o feedback/evidencias do indice.
Preserve o ID e o historico. Explique as mudancas, o atendimento das observacoes
e as pendencias. Atualize os dois documentos de forma consistente.
Nao aplique corretivas nem conceda GO.
```

Se o comando nao aparecer, abra `.github/prompts/revisar-lote.prompt.md` pelo
**Ctrl+P** e use **Executar Prompt**, informando esses mesmos caminhos no chat.

**Nao ha hashes dos arquivos adicionais**, cadastro em JSON nem alteracao de
`EvidenceHashes`. O agente registra origem e limites, sem afirmar integridade
automatica. Os hashes MTA e dos documentos anteriores continuam no fluxo existente.
Preserve a pasta depois de usada; para novos resultados, crie outra pasta datada.
Se precisar comparar arquivos antigos e novos, copie os pertinentes para a nova
pasta e identifique suas origens no indice; o agente nao varre outras pastas.

`.harness/evidencias/` e local, ignorada pelo Git e preservada pelas tres opcoes
de **Workspace: limpar execucoes**. Ela nao acompanha o clone: execute a tarefa
na outra maquina e forneca os arquivos pertinentes. Essa preservacao nao protege os planos/MTA
referenciados: as opcoes 1/2 continuam apagando as respectivas areas de execucao.

### Da proposta revisada a execucao e ao aceite

Uma revisao documental consistente ainda pode ter precondicoes tecnicas abertas.
No exemplo HIB-CACHE-001, a implementacao depende das evidencias abaixo e do GO
humano. A conclusao da revisao nao autoriza editar codigo, POM ou testes.

**1. Reunir as precondicoes sem aplicar a corretiva.** Use o plano/to-do vigente
como lista do que falta; registre resultados reais, origem e limites.

| Evidencia anterior a implementacao | O que registrar | Como entra na revisao |
| --- | --- | --- |
| Hibernate do EAP 7.4 de destino | Ambiente/instalacao e atualizacao do EAP, existencia do modulo org.hibernate, versao exata e evidencia da API disponivel. A linha 5.3 do perfil nao confirma esses detalhes. | Exportacao ou trecho pertinente dos metadados do ambiente; nao inferir runtime a partir do POM. |
| Dependencias e classpath Maven | Effective POM/arvore pertinentes, perfil e JDK usados, versoes/escopos de Hibernate Core e Hibernate Ehcache e suas dependencias relevantes. | Saidas identificadas do Maven; nao tratar dependencies.yaml do MTA como resolucao atual completa. |
| Baseline Sonar ANTES | Projeto analisado, data/fuso, identificacao da analise, estado dos fontes, configuracao/perfil e metricas necessarias a comparacao posterior. | Exportacao do resultado obtido antes de alterar codigo, POM ou testes; resultado ausente permanece pendente. |
| Decisao de API e criterio de teste | Comparacao das candidatas com as versoes confirmadas e como os testes demonstrarao limpeza padrao, preservacao da regiao nomeada, cache desativado e HTTP. | Evidencias tecnicas e justificativa no plano; comportamento da corretiva sera comprovado depois da implementacao. |

Essas coletas sao uma atividade tecnica separada dos prompts de planejamento.
`planejar-lotes` e `revisar-lote` leem os resultados fornecidos; nao executam Maven,
Sonar ou EAP para produzi-los. O harness oferece build/MTA e a coleta Sonar pela
task **Aplicacao: analisar SonarQube**, fora desses prompts; consulte o
[roteiro Sonar](sonar.md). Deploy, inspecao e controle do EAP usam as rotinas
autorizadas da equipe. Para a execucao da corretiva, use o fluxo
[implementar-lote](#preparar-implementacao-do-lote) depois do GO humano.
Nao gravar credenciais, settings privados ou logs brutos na pasta de evidencias.

**2. Incorporar as novas evidencias ao mesmo lote.** Crie outra pasta datada pela
task de evidencias para resultados novos, preservando a ja usada. Liste no LEIA-ME
os arquivos pertinentes, incluindo copias de evidencias anteriores que ainda sejam
necessarias, com suas origens. Salve observacoes no plano/to-do vigente e prepare
**2. Revisar lote**, selecionando essa proposta como Previous e o novo indice.
Reutilize o MTA se o conteudo pertinente da aplicacao continuar aplicavel; nova
evidencia de ambiente ou mudanca documental, isoladamente, nao exige reanalise.
Mudanca tecnica relevante exige avaliar nova rodada. Confira se a revisao fecha
as precondicoes com evidencia, sem marcar o artefato corrigido como validado.

**3. Registrar o GO humano no proprio plano/to-do.** Novos planejamentos e revisoes
ja trazem este bloco nos dois documentos. Ele comeca sem aprovacao:

```text
## Decisao humana
Responsavel:
GO humano: PENDENTE
Pendencias dispensadas como precondicao: nenhuma.
Aceite do resultado: PENDENTE.
```

Preencha seu nome e troque o GO por `autorizo implementar este plano e seu to-do`.
Nao precisa repetir RequestId, lote, escopo ou criterios ja identificados nesses
documentos. Data e opcional. Mantenha a mesma decisao nos dois arquivos.

| Sua decisao | Campo Pendencias dispensadas como precondicao |
| --- | --- |
| Implementar cumprindo as precondicoes do plano | `nenhuma` |
| Prosseguir apesar de todas as pendencias previas listadas | `todas as precondicoes listadas neste plano e to-do` |
| Prosseguir apesar de algumas precondicoes tecnicas | Liste apenas os IDs ou descricoes precisas das condicoes a dispensar |

A dispensa expressa substitui exigencias anteriores somente nesse alcance; na
opcao seletiva, as demais precondicoes tecnicas continuam exigidas. Sonar e nova
rodada MTA sao checklist nao bloqueante e nao precisam de dispensa. Registros em texto livre que expressem a mesma decisao
tambem sao aceitos, inclusive os existentes; nao e obrigatorio reescreve-los no modelo.

O agente reconhece a decisao vigente antes de avaliar o estado antigo PROPOSTA -
NAO APROVADA. Apos conferir contexto/hashes e alcance, encaminha a decisao ao
especialista; ao registrar resultados, concilia estado e textos superados no
plano/to-do, preservando historico. Nao pede o mesmo GO outra vez.
Exemplo nao preenchido, aprovacao revogada ou decisoes humanas conflitantes nao
autorizam execucao. Se a dispensa for ambigua, pede apenas o esclarecimento necessario.

Verificacoes nao realizadas permanecem pendentes; falta do baseline Sonar nao
bloqueia implementar, mas impede comprovar comparacao ANTES/DEPOIS. Aceite
do resultado continua separado. Mudar escopo/API/criterios exige decisao explicita;
a dispensa nao autoriza operacoes externas nem altera a integridade das evidencias.

Se editar os documentos depois de preparar implementacao, execute novamente
**Aplicacao: preparar implementacao do lote** para fixar os hashes novos. Se a
branch ja foi criada, escolha **2 - usar a branch atual**. Prompts antigos preservam
o contrato anterior: use o novo arquivo gerado apos atualizar o harness.

**4. Solicitar a execucao separadamente.** Depois de registrar GO, o desenvolvedor
escolhe a branch/checkout e usa **Aplicacao: preparar implementacao do lote**.
Selecione a solicitacao aprovada e execute o prompt aberto no Copilot Local,
conforme o [roteiro de implementacao](#preparar-implementacao-do-lote).
Nao use `/planejar-lotes` ou `/revisar-lote` para executar corretivas. O executor
preserva trabalho local e evidencias, aplica somente o lote e registra resultados
verificaveis; o aceite continua sendo uma decisao humana posterior.

**5. Verificar o artefato corrigido.** Siga os criterios do plano aprovado:

1. Execute **Aplicacao: build Maven (Java 8)** e os testes previstos, registrando
   o JDK efetivo e os resultados. Confira dependencias e identifique/inspecione o WAR.
2. Execute **MTA: executar analise** com perfil/regras/versao comparaveis. Reconcile
   os achados do lote; SUCCEEDED indica sucesso da ferramenta, nao ausencia de achados.
3. Execute **Aplicacao: analisar SonarQube** no servidor autorizado e compare com o baseline
   ANTES. Registre os criterios quantitativos e a aprovacao do Quality Gate
   separadamente. Sem comparacao valida, mantenha a verificacao pendente.
4. Valide o WAR identificado no EAP 7.4, pela rotina autorizada da equipe,
   registrando versao carregada e comportamento funcional. POM/build/MTA nao
   substituem evidencia de runtime. Deploy/servidor ainda nao possuem task no harness.

Falha ou resultado inconclusivo exige registrar retrabalho; nao marque tarefa
como concluida nem promova o artefato por ausencia de evidencia. Se necessario,
use a reversao delimitada no plano, preservando evidencias e trabalho alheio.

**6. Revisar e aceitar o resultado.** O desenvolvedor confere diff, build/testes,
WAR, comparacoes MTA/Sonar e validacao EAP contra o plano aprovado. Registra aceite
somente quando os criterios forem cumpridos e as pendencias impeditivas resolvidas.
GO de implementacao e aceite do resultado sao duas decisoes distintas.

Somente apos verificacoes e aceite, mediante pedido de continuidade, prepare
contexto com a nova rodada MTA e o planejamento vigente em Previous. Reconcilie
achados persistentes, novos, nao reencontrados e inconclusivos antes de planejar
outro lote. Se o atual falhar, continue nele; nao trate a pendencia como sucesso.
O ensaio documental de 29/09/2026 nao executou essas etapas de implementacao e aceite.

### Preparar implementacao do lote

Use esta etapa depois de revisar o plano/to-do, resolver ou dispensar expressamente
as precondicoes previas e registrar
o GO humano para a solicitacao e escopo concretos. Preparar o prompt e executar a
corretiva sao acoes diferentes; os scripts nao interpretam texto Markdown como GO.

1. Salve o registro de GO no plano/to-do, conforme o modelo acima. Preserve o lote,
   RequestId, escopo/API, criterios, evidencias e a autoria da decisao humana.
2. Execute **Terminal > Run Task > Aplicacao: preparar implementacao do lote**.
   Informe o workspace, escolha o projeto e selecione explicitamente a solicitacao
   com os dois documentos. O menu mostra datas/IDs; a presenca nao indica aprovacao.
   `q`, Enter vazio ou selecao invalida cancelam sem gerar prompt.
3. Decida explicitamente a branch no terminal: **1** cria e seleciona
   `lote/<ID-do-lote>`; **2** continua na atual; **3** pede o nome completo e cria
   uma branch local com esse nome. Sem ID confiavel, aparecem somente **2/3**.
   Enter/q cancela essa etapa, preservando o prompt ja salvo e sem abrir o editor.
4. Confira o arquivo `implementar-lote_<id12>.prompt.md` aberto na pasta da solicitacao.
   O bloco final fixa Project/Source, RunId/RequestId, os caminhos literais e hashes
   SHA-256 do recibo/plano/to-do. A tarefa revalida identidade, destinos e hashes MTA;
   nao cria outro planejamento, nao altera documentos e nao aciona o agente.
5. Use **Executar Prompt** em nova conversa **Copilot Local**, com `devsquad`.
   A chamada `/implementar-lote` com o caminho do arquivo preparado tambem aparece
   no terminal. Exige plugin DevSquad com `devsquad.implement` e ferramentas de
   subagente, leitura, edicao e terminal; a task nao instala/verifica o plugin.
6. O condutor le os dois documentos e confere versao, identidade, aplicabilidade,
   GO vigente e precondicoes nao dispensadas. Reconhece exigencias antigas
   expressamente superadas e delega ao `devsquad.implement` somente o escopo
   aprovado, com as dispensas. Ausencia de GO ou conflito real exige esclarecimento.
7. Confira diff, comandos/resultados e as atualizacoes de PlanPath/TodoPath.
   Implementacao, testes/build, MTA, Sonar e runtime mantem estados separados;
   verificacao nao realizada fica pendente. Revise e registre o aceite humano depois.

Para o nome automatico, mantenha `Lote ativo: HIB-CACHE-001` (exemplo) no inicio
do plano e do to-do, com o mesmo ID. Tambem e aceito `ID do lote: HIB-CACHE-001`,
inclusive com negrito/backticks. Sem metadado, com varios IDs ou com divergencia,
a tarefa nao adivinha: oferece continuar na atual ou informar um nome manual.
Na opcao 3, informe o nome completo, por exemplo `lote/ajuste-cache`; nao e
adicionado prefixo automaticamente. Se o Git recusar a criacao (por exemplo, nome
invalido ou branch existente), a tarefa informa o erro e oferece novamente 2/3
na mesma execucao, sem sobrescrever ou selecionar a branch existente.

A criacao parte do HEAD exibido do repositorio da aplicacao e seleciona a nova
branch local. Se Source for um modulo, a escolha afeta todo o checkout: confira
que outro agente nao o esta usando. Alteracoes locais e indice sao preservados;
nao ha force/reset/stash, commit, push ou mudanca de remoto/upstream. A opcao 2
nao exige uma branch padrao e funciona mesmo com HEAD destacado ou Git indisponivel.
Criar branch nao concede GO nem altera recibos/evidencias. Se documentos ou o
estado Git exibido mudarem durante a escolha, a criacao e interrompida para nova
decisao. O agente Copilot continua sem permissao para gerir branches.

Se editar o plano/to-do depois do preparo, execute a tarefa novamente para fixar
a nova versao. Cada preparo grava outro prompt e preserva os anteriores. Na retomada
apos execucao parcial, use os documentos atualizados da mesma solicitacao; o agente
confere o trabalho existente e continua somente as tarefas tecnicas pendentes,
sem exigir novo GO quando escopo e decisao anteriores continuam validos.

O contrato adapta o plugin: PlanPath/TodoPath substituem tasks.md e descoberta de
spec; nao exige board/work item nem altera branches. Workers de validacao, execucao,
verificacao e revisao recebem os mesmos limites; nao ha commit/push/PR automaticos,
escrita em memoria ou abertura de outro lote. As ferramentas dos subagentes nao
sao sandbox; conferir obediencia exige ensaio no cliente.
MTA/Sonar, rede, EAP/deploy e operacoes externas dependem de autorizacao explicita
para destino/finalidade; constar como criterio futuro nao autoriza a execucao.

Alternativa pelo terminal, na raiz do harness (selecao interativa de projeto/plano):

```powershell
powershell.exe -NoProfile -File .\scripts\preparar-implementacao.ps1 -WorkspacePath .\jboss-mta-harness.local.code-workspace -SelectTarget
```

`-RequestId <id-completo>` seleciona uma solicitacao explicita; `-EditorPath <editor>`
abre o prompt, e `-NoOpen` suprime apenas a abertura (a decisao de branch continua
explicita). Sem editor ou com falha de
abertura, o arquivo salvo continua disponivel. Limpeza do planejamento remove
tambem esses prompts; preserve evidencias necessarias antes de limpar.

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
prompt, cache Maven, backups e `.harness/evidencias/`. Nao apaga `target/` da aplicacao nem copias externas
de relatorios. No menu de projeto, o escopo vem do `Source` dos recibos, incluindo
pastas antigas e novas. Recibos invalidos bloqueiam a limpeza seletiva; pastas sem
recibo identificavel permanecem. A opcao todos remove as tres areas por inteiro.
Rodadas externas registradas tambem aparecem no preview e sao removidas nas
opcoes 1/2, antes das referencias locais. A limpeza nunca remove a raiz
`C:/mta-runs` inteira nem pastas/arquivos externos sem referencia registrada.
Referencia externa inconsistente cancela a limpeza; mantenha as evidencias para
conferir o problema. A opcao 3 continua restrita aos backups temporarios locais.

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
| `.harness/evidencias/` | A tarefa Planejamento: criar pasta de evidencias cria pasta por projeto/data/ID e LEIA-ME.md orientativo. O desenvolvedor adiciona/lista os arquivos manualmente. Sem hashes adicionais; usados por revisar-lote. Preservados pela limpeza, locais e ausentes no clone. |
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

Para testar o preparo de implementacao, execute `powershell.exe -NoProfile -File .\tests\Test-Implementation.ps1`.
Verifica identidade/destinos/hashes, preservacao do historico, menus, cancelamento
e abertura simulada do editor. Nao executa corretivas nem comprova o GO ou a
delegacao no Copilot; esse ensaio permanece separado dos testes de scripts.

`powershell.exe -NoProfile -File .\tests\Test-ImplementationBranch.ps1` verifica
as tres escolhas e o fallback, com criacao de branches somente em repositorios
ficticios: nomes invalidos/existentes, cancelamento, HEAD destacado e preservacao
de arquivos/indice. Nao altera branches da aplicacao real.

Para testar configuracao e analise: execute `powershell.exe -NoProfile -File .\tests\Test-Workspace.ps1` e `powershell.exe -NoProfile -File .\tests\Test-Mta.ps1`. Criam fixtures em `.harness/tests/`; o segundo simula a chamada ao processo MTA.

Para testar o build e sua configuracao: execute `powershell.exe -NoProfile -File .\tests\Test-Build.ps1` e `powershell.exe -NoProfile -File .\tests\Test-BuildConfig.ps1`. Verificam ferramentas separadas, Java 8, falhas, restauracao do ambiente e geracao do workspace, com chamadas de build simuladas.

Para ensaiar cobertura com Maven real, execute `powershell.exe -NoProfile -File
.\tests\Test-BuildCoverage.ps1 -Jdk8Home <caminho-do-jdk8> -MavenHome <caminho-do-maven>`
em uma linha. O ensaio usa fixture isolada em `.harness/tests/`, dependencias e
settings padrao da maquina: cobertura baixa gera aviso/exit 0, enquanto teste
reprovado e erro de compilacao continuam falhando. Nao executa Sonar nem MTA.

Para testar o acompanhamento e o historico, execute `powershell.exe -NoProfile -File .\tests\Test-MtaLog.ps1`. Usa logs ficticios e verifica novas linhas durante a leitura e selecao de rodadas anteriores, sem executar MTA. `powershell.exe -NoProfile -File .\tests\Test-MtaActive.ps1` verifica a deteccao da analise ativa sem selecao de projeto e recusa registros antigos e builds como fonte de observabilidade MTA.

Para testar a selecao dos projetos do workspace, execute `powershell.exe -NoProfile -File .\tests\Test-Target.ps1`. Verifica o menu, packaging pom, padrao opcional, projetos homonimos, adicao/renomeacao e preservacao do JSON/workspace.

Para testar os argumentos das tarefas, execute `powershell.exe -NoProfile -File .\tests\Test-TaskInputs.ps1`. Verifica as entradas suportadas e executa o script real de build ate o menu, com caminho de workspace contendo espacos; cancela antes de iniciar Maven.

Para testar a pasta de evidencias, execute `powershell.exe -NoProfile -File .\tests\Test-EvidenceFolder.ps1`.
Verifica selecao/cancelamento pela entrada real, isolamento de projetos homonimos,
repeticao sem sobrescrita e abertura do LEIA-ME em editor simulado, sem MTA/Copilot.
