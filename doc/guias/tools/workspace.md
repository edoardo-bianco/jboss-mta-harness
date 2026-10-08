---
html:
  embed_local_images: true
  embed_svg: true
  offline: true
---

# Workspace: configuracao e uso

[Voltar ao fluxo principal](../harness-migracao-desenvolvedor.md#roteiro-onde-estou-e-o-que-escolho).

Este guia cuida do ambiente comum: primeira configuracao, IDE, selecao de projetos,
exemplos, dados locais e limpeza. Os comandos das tarefas partem da raiz do harness.
Use-o na [etapa 1](../harness-migracao-desenvolvedor.md#1-preparar-o-ambiente)
e quando precisar ajustar o ambiente durante o trabalho.

| Necessidade | Secao |
| --- | --- |
| Comecar em uma maquina | [Primeira configuracao](#comecar-na-maquina-de-trabalho) |
| Preparar tambem as maquinas dos colegas | [Roteiro por maquina e usuario](#preparar-as-maquinas-dos-colegas) |
| Alterar caminhos ou escolhas da IDE | [JSON local](#configuracao-da-maquina) e [workspace gerado/manual](#duas-opcoes-para-configurar-o-workspace) |
| Permitir leitura dos relatorios MTA pelo Copilot | [Acesso a pasta MTA](#acesso-do-copilot-a-pasta-mta) |
| Selecionar ou adicionar aplicacoes | [Projetos](#escolher-o-projeto-em-cada-tarefa) e [exemplos/corporativos](#ensaiar-e-depois-usar-os-projetos-corporativos) |
| Localizar ou limpar saidas | [Pastas locais](#pastas-locais-e-backups-temporarios) e [limpeza](#limpar-execucoes-locais) |
| Identificar o script de uma Run Task | [Catalogo de tarefas](#tarefa-e-script-correspondente) |

Navegacao: [orientacao com o helper](#orientacao-com-o-helper) ·
[configuracao](#configuracao) · [uso](#uso) · [resultado e proximo passo](#resultado-e-proximo-passo).

## Orientacao com o helper

No Codex, ative `$orientar-migracao`; no Copilot, selecione `migracao_helper`.
Veja [como iniciar e retomar a orientacao](../orientacao-migracao.md#iniciar-no-codex-ou-no-copilot).

```text
Quero preparar o ambiente para migrar o projeto X nesta maquina.
Confira o workspace salvo, a configuracao e os registros existentes.
Me oriente na proxima acao necessaria.
```

**Resultado esperado:** indicacao da configuracao, selecao de projeto ou atualizacao
inicial do indice que falta, com o caminho e a tarefa corretos. Voce executa a acao
e retorna com o resultado; o helper preserva configuracao e evidencias existentes.

## Configuracao

### Comecar na maquina de trabalho

Esta secao detalha a etapa 1 do roteiro. A configuracao e feita por maquina;
no uso diario, abra seu workspace local e retome a [etapa em que parou](../harness-migracao-desenvolvedor.md#como-usar-este-guia).

**Qual workspace abrir?**

| Arquivo | Quando usar |
| --- | --- |
| `iniciar-harness.code-workspace` | Somente na primeira configuracao, apos clonar. Modelo portavel somente com o harness; adicione aplicacoes externas. |
| `jboss-mta-harness.local.code-workspace` | No dia a dia, apos configurar. Contem seus caminhos e os projetos adicionados ao workspace; nao e versionado. |

**Se voce ja tem o workspace local configurado, continue abrindo `jboss-mta-harness.local.code-workspace`.** Nao precisa repetir a configuracao inicial nem gerar novamente para adicionar projetos. O arquivo inicial foi renomeado de `jboss-mta-harness.code-workspace` para `iniciar-harness.code-workspace`; seu workspace local permanece o mesmo.

Use uma pasta local permitida pela empresa, com Git, VS Code e Windows PowerShell
5.1 disponiveis. Para build, tenha Maven e JDK 8; para executar MTA, tenha a
distribuicao Windows completa e seu JDK (JDK 25 no ensaio), conforme a
[configuracao MTA](mta.md#configuracao). Use as instalacoes existentes.
Para o planejamento assistido, consulte [Codex ou GitHub Copilot](../orientacao-migracao.md#configuracao)
em sessao Local. Quem vai somente planejar com uma rodada recebida segue o caminho
de reutilizacao da etapa 3, sem repetir a analise apenas para preparar a proposta.
Tambem pode planejar com issues e evidencias fornecidas, sem pacote MTA completo;
nesse caso siga a etapa 4 do guia principal.

Para ativar as consultas MCP opcionais, siga a [instalacao do Node em pasta fixa](consultas-issues.md#instalar-node-em-pasta-fixa)
e depois a configuracao dos clientes no mesmo guia. Node 18 pode permanecer no
PATH para outros projetos. O [helper acompanha esse preparo](consultas-issues.md#orientacao-com-o-helper)
uma etapa por vez; priorizacao e planejamento continuam sem MCP quando indisponivel.

Aplicacoes e playgrounds ficam fora do repositorio do harness e sao adicionados
ao workspace pelo desenvolvedor. JBoss 7.1/7.4 podem permanecer
nas pastas onde foram extraidos; seus caminhos sao opcionais nesta primeira etapa.
Build e analise sao tarefas separadas, executadas nas etapas 2 e 3 do roteiro.
Prepare JBoss e Sonar quando for usar essas ferramentas.

Em uma pasta de repositorios permitida, execute:

```powershell
git clone https://github.com/edoardo-bianco/jboss-mta-harness.git
```

Os passos abaixo usam a **opcao A: configuracao pelo harness**. Para configurar a IDE diretamente, veja a [opcao B: configuracao manual do workspace](#opcao-b-configurar-o-workspace-manualmente).

1. Na primeira configuracao, use **File > Open Workspace from File** e abra `iniciar-harness.code-workspace`, na raiz do clone. Ele mostra somente `harness`. Use-o para configurar os caminhos e gerar seu workspace local nos passos seguintes.
2. Execute **Terminal > Run Task > Workspace: configurar caminhos**. A tarefa cria e abre `config/harness.local.json`. Em configuracoes existentes, acrescenta campos Sonar e EAP ausentes, preservando os valores ja informados; confira os [padroes Sonar](sonar.md#configurar-uma-vez-por-maquina) e [JBoss](jboss.md).
3. Preencha em `tools` os caminhos **desta maquina** para as ferramentas que vai usar e salve; o build precisa de `applicationJdk8Home` e `applicationMavenHome`. A configuracao inicial usa `repositories: []` e `activeProject: null`; importe as aplicacoes externas no workspace local. Use a [configuracao comum](#configuracao-da-maquina) e os [guias de ferramentas](../harness-migracao-desenvolvedor.md#guias-de-ferramentas). Para repositorios Maven privados/proxy, informe o `settings.xml` aprovado em `tools.mavenSettingsPath` (MTA) e `tools.applicationMavenSettingsPath` (build); podem apontar para o mesmo arquivo. Nao copie o settings da demo pessoal.
4. Execute **Terminal > Run Task > Workspace: gerar workspace**. Abra o arquivo gerado `jboss-mta-harness.local.code-workspace`, na raiz do clone, em **File > Open Workspace from File**. O Explorer deve mostrar `harness` e os projetos cadastrados. Adicione suas aplicacoes externas com **File > Add Folder to Workspace...** e salve. A partir daqui, use esse arquivo local para as tarefas; quando Run Task pedir o arquivo de workspace, confirme esse nome.
5. Se vai executar MTA nesta maquina, execute **MTA: conferir ambiente**, da pasta `harness`. Deve mostrar `OK`, o projeto certo, os caminhos locais, perfil `eap71-to-eap74-java8`, `Targets: eap7 | Modo: full` e filtro source nenhum. Se falhar, use **Workspace: configurar caminhos**, corrija o JSON e repita a conferencia.

**Configuracao concluida:** volte a [etapa 2 para selecionar e construir a aplicacao](../harness-migracao-desenvolvedor.md#2-escolher-o-projeto-e-fazer-o-build),
ou a [etapa 3 para usar MTA existente/recebido](../harness-migracao-desenvolvedor.md#3-obter-ou-reutilizar-o-diagnostico-mta).
Se ja tem uma issue e evidencias, siga diretamente a
[etapa 4 para registrar a escolha](../harness-migracao-desenvolvedor.md#4-conferir-o-registro-e-escolher-prioridades).
A sequencia de analise, planejamento, implementacao e aceite esta no roteiro principal.

Ao abrir o workspace, a conferencia automatica usa a configuracao legada `repositories`/`activeProject` do JSON, quando disponivel, sem perguntar qual arquivo de workspace usar. Sem padrao, orienta executar a conferencia manual; esta permite informar o workspace e escolher um projeto. Se a configuracao necessaria estiver incompleta, abre o JSON. O VS Code pode pedir para permitir tarefas automaticas; a tarefa manual de configuracao funciona independentemente dessa permissao. Nenhuma analise comeca automaticamente.

Nos proximos dias, abra diretamente `jboss-mta-harness.local.code-workspace`. `iniciar-harness.code-workspace` fica como modelo para novos clones; nao precisa reabri-lo depois da configuracao. Relatorios, configuracao pessoal e workspace local nao acompanham o clone. Se uma politica impedir scripts, siga o procedimento de liberacao da empresa; este guia nao usa bypass nem altera ExecutionPolicy.

Apos atualizar o harness com Git, continue usando seu workspace local. Se precisar
recarregar a interface/extensoes, use **Ctrl+Shift+P > Developer: Reload Window**;
isso nao gera workspace nem atualiza prompts salvos. Para usar instrucoes novas,
prepare outro prompt na operacao desejada, reutilizando o MTA existente quando
aplicavel. Na manutencao do registro, pode escolher somente registro/evidencias.
Prompts e copias do contrato de solicitacoes anteriores permanecem historicos.

#### Preparar as maquinas dos colegas

Cada colega comeca pelo [README](../../../README.md#como-usar) e pelo
[guia do desenvolvedor](../harness-migracao-desenvolvedor.md#1-preparar-o-ambiente).
Esta tabela encaminha aos procedimentos; comandos e versoes ficam no guia de cada
ferramenta, tambem consultado pelo helper. Confira os caminhos desta maquina e
o usuario que executara as tarefas; arquivos locais nao acompanham o clone.

| Preparo necessario | Procedimento e evidencia a conferir |
| --- | --- |
| Workspace e ferramentas | [Primeira configuracao](#comecar-na-maquina-de-trabalho): workspace salvo, projetos externos e JSON com caminhos locais. Maven usa settings normais da maquina ou override corporativo explicito. |
| Build/testes | [Maven Java 8](maven.md#build-maven-da-aplicacao-com-java-8): versao Java, resultado dos testes e cobertura da aplicacao. |
| Sonar corporativo | [Configuracao Sonar](sonar.md#exemplo-corporativo-no-sonarqube-99) e [certificado publico](sonar.md#certificado-publico-do-sonar-corporativo): JDK do scanner, endpoint, impressao confirmada e truststore do usuario. A propria tarefa oferece o preparo. |
| Consultas MCP opcionais | [Node em pasta fixa](consultas-issues.md#instalar-node-em-pasta-fixa), seguido de [dependencias e clientes](consultas-issues.md#instalar-dependencias-e-configurar-os-clientes): node/npm pelo caminho escolhido, configurador e descoberta/consulta real no cliente. |

Instale apenas o necessario para a etapa do colega. Para Node/MCP e certificado,
a orientacao inicial dispensa MTA e registro de migracao. Compartilhe os links dos
guias e a referencia corporativa do certificado; cada usuario informa seu proprio
token no terminal e confere seus caminhos, sem copiar credenciais/configuracao
pessoal de outra maquina.

No Codex, ative `$orientar-migracao`; no Copilot, escolha `migracao_helper` e envie:

```text
Estou preparando esta maquina para usar o harness, incluindo Sonar corporativo
e consultas MCP. Leia o roteiro por maquina no guia de workspace e me oriente
uma etapa por vez pelos guias oficiais do repositorio. Informe a fonte, a tarefa
ou comando e o resultado esperado. Ja concluimos: [etapas e caminhos locais].
```

O helper preserva o que ja foi conferido e indica a proxima acao. Para retomar,
informe a etapa e o resultado obtido, sem token; nao precisa repetir todo o roteiro.

#### Extensoes Java no VS Code

No painel **Extensions** (`Ctrl+Shift+X`), procure pelo identificador e instale/habilite:

| Extensao | Identificador | Uso |
| --- | --- | --- |
| Language Support for Java(TM) by Red Hat | `redhat.java` | Importacao dos projetos Java, navegacao e suporte aos fontes usados no debug. |
| Debugger for Java | `vscjava.vscode-java-debug` | Breakpoints e attach remoto a JVM do JBoss. |
| Maven for Java (opcional) | `vscjava.vscode-maven` | Painel Maven da IDE; as Run Tasks Maven do harness funcionam sem esta extensao. |

O workspace gerado recomenda as duas primeiras; recomendacao nao instala extensoes.
Confira que estao habilitadas no workspace. Copilot/DevSquad atendem ao fluxo
assistido e nao sao necessarios para start, deploy, stop ou attach Java.

O JDK do servidor de linguagem deve atender aos requisitos da extensao instalada;
ele e separado do JDK 8 da aplicacao/JBoss e do JDK do MTA. Configure os caminhos
locais e aguarde a importacao Java terminar antes de testar breakpoints.
Depois de atualizar um workspace antigo, execute **Workspace: gerar workspace**
uma vez para receber as recomendacoes e os attaches JBoss, e reabra o arquivo local.
Se os attaches ja aparecem e as portas nao mudaram, nao precisa regenerar.

### Configuracao da maquina

O exemplo versionado e `config/harness.example.json`; a tarefa cria dele o seu `config/harness.local.json`. Use caminhos reais com `/` ou `\\`, sem variaveis como `%JAVA_HOME%`. Caminhos relativos partem da pasta deste repo.

**Respeitar os padroes das ferramentas:** mantenha `mavenSettingsPath` e
`applicationMavenSettingsPath` como `null` no uso normal. Maven usa os settings
globais/usuario da maquina e seu repositorio local padrao, normalmente
`%USERPROFILE%\.m2\repository`. O harness nao cria settings, mirrors ou cache
Maven proprios. Informe um settings alternativo somente quando necessario,
por exemplo um arquivo corporativo aprovado. A geracao do workspace tambem
omite os overrides de settings quando esses campos estao null.

Trecho comum para preencher no passo 3 de [Comecar na maquina de trabalho](#comecar-na-maquina-de-trabalho). **Os caminhos de ferramentas abaixo sao ficticios:** substitua pelos existentes na maquina. Preserve os demais campos criados pela tarefa e complemente `tools`, `mta`, `eap` e `sonar` pelos [guias de ferramentas](../harness-migracao-desenvolvedor.md#guias-de-ferramentas). O trecho abaixo nao substitui o JSON inteiro; JBoss e Sonar sao opcionais no ciclo build/MTA.

```json
{
  "schemaVersion": 1,
  "activeProject": null,
  "repositories": [],
  "tools": {
    "applicationMavenHome": "D:/ferramentas/apache-maven",
    "applicationMavenSettingsPath": null,
    "applicationJdk8Home": "D:/ferramentas/jdk8"
  }
}
```

| Campo | Preencher com |
| --- | --- |
| `repositories` | Opcional para tarefas com workspace: usado pelo gerador e pela CLI legada sem `-WorkspacePath`. As tarefas do VS Code descobrem os projetos no workspace aberto. |
| `activeProject` | Padrao opcional: nome do projeto no workspace ou caminho completo. Pode ficar `null` ou ser omitido; escolha o alvo no menu de cada tarefa. Na CLI legada, corresponde ao `name` em `repositories`. |
| `tools.applicationMavenHome` | Maven do build da aplicacao, com `bin/mvn.cmd`. Pode apontar para a mesma instalacao do MTA; depois pode ser trocado independentemente. |
| `tools.applicationMavenSettingsPath` | Opcional: `settings.xml` do build/importacao Java. Pode ter o mesmo caminho do MTA. Se null, Maven usa seus settings padrao; nao herda o campo do MTA. |
| `tools.applicationJdk8Home` | Obrigatorio para o build: pasta do JDK 8, tambem configurada no workspace para a aplicacao. |
| `tools.eap71Home`, `tools.eap74Home`, `eap` | Opcionais para build/MTA; veja a [configuracao JBoss](jboss.md#configuracao) para operar o servidor. |
| `sonar` | Opcional no ciclo build/MTA; veja a [configuracao Sonar](sonar.md#configuracao). Nunca gravar token. |
| `tools.mta*`, `tools.mavenHome`, `tools.mavenSettingsPath`, `mta` | Veja a [configuracao MTA](mta.md#configuracao), incluindo perfil, regras e destino das rodadas. |

**Trocar projeto:** escolha outro alvo no menu, execute seu build e, apos sucesso, selecione-o no MTA. **Adicionar projetos:** use Add Folder to Workspace e salve. **Mudar ferramentas:** ajuste `tools` no JSON e sincronize as configuracoes da IDE pela opcao A ou B. O gerador sincroniza os projetos de `repositories` e preserva pastas extras, com backup em `.harness/workspace-backups/`; nao e necessario executa-lo para adicionar projetos ao workspace. Uma biblioteca visivel nao e compilada nem analisada automaticamente junto com outro repo.

### Acesso do Copilot a pasta MTA

O gerador preenche `github.copilot.chat.additionalReadAccessPaths` em `settings`
do workspace local com `mta.runsPath`, quando este caminho esta configurado e a
permissao ainda nao existe no workspace. A lista autoriza leitura da pasta e suas
subpastas pelas ferramentas do Copilot; com `C:/mta-runs`, abrange as rodadas dos
projetos nessa raiz. A configuracao pertence ao workspace, sem editar User Settings.

Para aplicar em outra maquina, confira `mta.runsPath` em
`config/harness.local.json`, execute **Workspace: gerar workspace** e abra
`jboss-mta-harness.local.code-workspace`. Esse arquivo e local e nao acompanha
o clone/atualizacao por Git. O gerador preserva projetos e ajustes existentes.

Para alterar manualmente, use **Ctrl+Shift+P > Preferences: Open Workspace
Settings (JSON)** e edite a lista dentro de `settings`, preservando os demais campos:

```json
"github.copilot.chat.additionalReadAccessPaths": [
  "C:/mta-runs"
]
```

Substitua pelo caminho desta maquina ou informe varias pastas. Para limitar a
uma rodada, use sua pasta completa. Para revogar o acesso configurado aqui,
deixe `[]`: o gerador preserva listas existentes, inclusive vazias. Remover a
chave permite que a proxima geracao volte a inicializa-la com `mta.runsPath`.
Se mudar a pasta de saida MTA, confira tambem esta lista; uma permissao existente
nao e trocada automaticamente. Com `mta.runsPath=null`, nenhuma nova permissao
externa e acrescentada. Listas ja definidas permanecem sob controle do usuario.

O [manifesto oficial do Copilot](https://github.com/microsoft/vscode-copilot-chat/blob/main/package.json)
registra `additionalReadAccessPaths` com escopo `window`, compativel com workspace.
A referencia de settings do VS Code consultada citava `additionalReadAccessFolders`;
use a chave reconhecida pela extensao instalada. Se `Paths` aparecer como
desconhecida, confira a versao e a configuracao exposta pelo Copilot antes de
afirmar que o acesso foi concedido. A leitura real continua sendo conferida pelo
agente; veja [permissao e retomada](priorizacao-issues.md#acesso-a-rodada-externa).

### Duas opcoes para configurar o workspace

As duas opcoes configuram a IDE. Para executar as tarefas do harness, mantenha tambem `config/harness.local.json` preenchido, inclusive quando escolher a opcao manual.

| Opcao | Onde editar | Como aplicar |
| --- | --- | --- |
| **A — Pelo harness** | `config/harness.local.json` | Gerar novamente e abrir `jboss-mta-harness.local.code-workspace`. |
| **B — Manualmente no VS Code** | `settings` e, se necessario, `folders` do `.local.code-workspace` | Salvar o arquivo e criar um novo terminal Maven. Nao precisa executar Run Task nem gerar novamente. |

#### Opcao A: editar o JSON local e gerar novamente

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
quando e gerado ou editado. O gerador atualiza caminhos dos projetos cadastrados,
Java/Maven e os dois attaches JBoss; preserva pastas extras, demais settings e
launches manuais. Guarda o arquivo anterior em `.harness/workspace-backups/`.
Settings Maven null removem os overrides gerados, mantendo os padroes da maquina.
Pastas adicionadas pelo VS Code podem conter somente `path`; `name` e opcional
no [formato de workspace](https://code.visualstudio.com/docs/editing/workspaces/multi-root-workspaces#workspace-file-schema).
O gerador reconhece caminhos equivalentes sem duplicar pastas, preserva aliases
das aplicacoes e garante o nome `harness` na raiz usada pelas tarefas.

#### Opcao B: configurar o workspace manualmente

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

## Uso

### Orientacao com Codex ou GitHub Copilot

O passo a passo foi reunido no [guia de orientacao da migracao](../orientacao-migracao.md).
Para preparar o ambiente, use o [pedido ao helper deste guia](#orientacao-com-o-helper).

### Escolher o projeto em cada tarefa

Use **File > Add Folder to Workspace...** para adicionar os projetos Java/Maven e salve o workspace. **Nao e preciso cadastra-los em `repositories` no JSON do harness.** Cada pasta do workspace que contenha `pom.xml` aparece na selecao, incluindo agregadores e projetos com packaging `pom`, `jar` ou `war`. Para escolher um modulo separadamente, adicione tambem a pasta dele ao workspace. Pastas sem POM e a pasta do harness ficam fora da lista.

Em **Terminal > Run Task**, escolha a tarefa da pasta `harness`. Na entrada **Arquivo .code-workspace em uso**, confirme `jboss-mta-harness.local.code-workspace` se esse for o arquivo aberto. Se usar outro, informe seu caminho completo ou relativo a raiz do harness, sem aspas. No build, escolha tambem as fases na lista do VS Code. Para conferir ambiente, build, executar MTA, consultar historico e abrir relatorio, o terminal oferece uma lista numerada de projetos: digite o numero e pressione Enter; `q` cancela. As duas tarefas **MTA: acompanhar...** localizam a analise em execucao automaticamente. **Planejamento: planejar** recupera o registro existente e so pergunta qual usar quando houver varios candidatos; nao repete menus de operacao ou rodada.

Por exemplo, se `simtr-api` e `simtr-outsourcing-api` estiverem no workspace, ambos aparecem. Escolher um agregador executa o Maven no POM dele e inclui os modulos declarados; escolher um modulo usa o POM desse modulo. O nome da pasta nao determina seu papel.

`activeProject` e apenas um **padrao opcional**, pelo nome exibido no workspace ou caminho completo; Enter aceita esse padrao quando ele identifica exatamente um projeto. Sem padrao, escolha um numero. A escolha vale somente para a tarefa atual e nao altera o JSON nem o workspace. Se houver nomes repetidos, confira os caminhos na lista.

As tarefas **Workspace: configurar caminhos** e **Workspace: gerar workspace** cuidam da configuracao, sem alvo de build. A conferencia automatica ao abrir tambem nao solicita selecao. Adicionar/remover projetos no workspace nao exige gerar novamente; o gerador continua sendo uma opcao de criacao/sincronizacao a partir do JSON e pode substituir edicoes manuais.

As tarefas recebem o arquivo informado por `${input:harnessWorkspacePath}`, uma entrada `promptString` suportada pelo VS Code. `${workspaceFile}` nao e uma variavel nativa de tarefas; por isso o caminho e solicitado explicitamente, sem presumir qual workspace esta aberto. Veja a [referencia de variaveis do VS Code](https://code.visualstudio.com/docs/reference/variables-reference). Pelo terminal, passe `-WorkspacePath` e `-SelectTarget` para abrir o mesmo menu, ou `-Target "simtr-outsourcing-api"` para selecionar diretamente. Sem `-WorkspacePath`, os scripts mantem a compatibilidade com `repositories`/`activeProject` do JSON.

Historicos de projetos selecionados pelo workspace sao identificados pelo caminho, evitando misturar projetos homonimos e preservando a identidade quando o nome no Explorer muda. Rodadas antigas criadas pelo cadastro JSON continuam acessiveis pela execucao CLI sem `-WorkspacePath`; os arquivos existentes sao preservados.

### Ensaiar e depois usar os projetos corporativos

O harness nao inclui aplicacoes de exemplo. Use um playground ou repositorio real
em pasta externa ao harness e adicione-o com **File > Add Folder to Workspace...**.
Salve o workspace local; as tarefas descobrem suas pastas Maven, incluindo agregadores.
Para CLI sem WorkspacePath, cadastre os caminhos externos em `repositories`.

No ensaio local reiniciado em 2026-10-05, `migracao-cache-antes` foi separado para
`C:/desenvolvimento/repositorio/migracao-cache-antes`. Esse caminho e particular da
maquina do ensaio, nao um requisito de instalacao. O projeto DEPOIS foi removido.
O desenvolvedor importa ANTES e inicia novos build/MTA e registros, sem reutilizar
as analises anteriores do playground. Codigo movido nao foi corrigido nesta etapa.

Depois de importar o projeto, selecione-o nas tarefas de build/MTA, confira o
relatorio e execute **Workspace: atualizar indice dos projetos**. Pode priorizar
uma fatia percentual ou escolher uma issue diretamente no registro e usar
**Planejamento: planejar**. A aplicacao tem versionamento separado do harness.

Para usar projetos corporativos, importe-os da mesma forma e remova do workspace
as pastas que nao deseja considerar. Remover uma entrada do workspace nao apaga
codigo nem evidencias; o gerador preserva entradas existentes. Se usa o gerador ou
CLI sem WorkspacePath, mantenha `repositories` coerente com os projetos desejados.

### Limpar execucoes locais

1. Termine build/MTA e preparacao de contexto. Encerre a conversa Codex/Copilot que usa
   os documentos a apagar; o harness nao controla o agente externo.
2. Execute **Workspace: limpar execucoes**. Escolha **1** para um projeto ou **2**
   para todos os projetos; **3** limpa somente backups temporarios de exercicios/ajustes.
   **q** cancela. Na opcao 1, selecione o projeto do workspace.
3. Confira os caminhos listados. Nas opcoes **1/2**, a limpeza inclui somente
   execucoes em `.harness/runs`, `.harness/builds` e `.harness/planning`, com
   relatorios/snapshots locais, indices de MTA externo, prompts, `plan.md`, `todo.md`
   e recibos legados. Os dossies em `planning/<artifactId>/issues/` sao preservados,
   incluindo fichas, anexos e novas propostas. Os ponteiros locais relacionados
   tambem sao removidos. Na opcao **3**,
   apenas a pasta central de backups temporarios sera removida.
4. Digite **LIMPAR** para excluir. Enter ou outro texto cancela. Os scripts recusam
   links/junctions e caminhos fora das areas autorizadas, e bloqueiam limpeza
   concorrente com build/MTA/preparacao pelo harness.
5. O registro e a origem MTA externa permanecem. Confira suas referencias antes de
   usar **Planejamento: planejar**: planos/recibos apagados nao podem ser retomados.
   Para reconstruir o preparo preservando as escolhas, peca ao helper o
   [encaminhamento apropriado](planejamento-migracao.md#recuperar-um-preparo-apos-limpeza).
   Para adotar outra rodada, use manutencao explicita; Planejar nao oferece menu de MTA.

A limpeza preserva configuracao, workspace, fontes, Git, `.harness/sonar/`, templates
versionados dos prompts, cache Maven, backups, `.harness/evidencias/`, `.harness/projetos/`
e `.harness/priorizacao/`, alem de `.harness/importacoes/` e dos dossies por issue
em `.harness/planning/`.
Nao apaga `target/` da aplicacao nem qualquer conteudo MTA externo, registrado ou recebido.
No menu de projeto, o escopo vem do `Source` dos recibos, incluindo
pastas antigas e novas. Recibos invalidos bloqueiam a limpeza seletiva; pastas sem
recibo identificavel permanecem. A opcao todos remove runs/builds e o planejamento
fora dos dossies por issue.
Para MTA externo, somente o indice local `location.json` e seus ponteiros entram
na limpeza. O destino externo nao e consultado e pode estar indisponivel.
Depois, o historico/ultimo relatorio perde a referencia local; informe a pasta quando
**MTA: abrir ultimo relatorio** solicitar. Para adotar outra origem no registro,
peca ao helper o [encaminhamento de manutencao](planejamento-migracao.md#reconstruir-a-pasta-usando-um-mta-existente)
com o caminho pronto; Planejar usa a origem vinculada sem menu de rodadas.
O `migracao.md` mantem decisoes e referencias anteriores; limpa-se o historico de
execucoes, sem zerar o registro. A opcao 3 continua restrita aos backups temporarios locais.

Para somente listar, sem excluir, execute na raiz:

```powershell
powershell.exe -NoProfile -File .\scripts\limpar-execucoes.ps1 -All -Preview
```

Alteracoes permanentes dos prompts devem estar no template correspondente em
`.github/prompts/`. Uma edicao feita apenas no prompt
preparado pertence aquela solicitacao e sera apagada com ela. Para conservar um
plano ou resultado, guarde antes uma copia fora das areas que serao removidas.

#### Reiniciar um ensaio do zero

Use este caminho quando decidir descartar todo o estado local do ensaio. A exclusao
integral de `.harness/` tambem remove registros e decisoes humanas, fichas, planos,
anexos, evidencias, backups e rodadas MTA que estejam dentro dela. A tarefa
**Workspace: limpar execucoes** preserva parte desse material e nao faz esse reinicio.

1. Atualize o harness para a entrega que sera ensaiada. Alteracoes ainda sem
   commit/push em outra maquina nao chegam por `git pull`.
2. Encerre build/MTA, testes, preparacao e agentes que usem o estado local; pare
   tambem o servidor iniciado pelo harness antes de descartar seus controles.
3. Confira o caminho absoluto e o conteudo da `.harness` deste checkout. Com todo
   esse material de ensaio descartavel, remova somente essa pasta. Se houver
   worktrees ou links/junctions, resolva-os separadamente antes da exclusao.
4. Preserve `config/harness.local.json`, o workspace e os fontes das aplicacoes,
   que ficam fora dela. Um MTA externo completo pode ser reutilizado; confirme
   sua aplicabilidade ao codigo atual. MTA que estava dentro da pasta sera perdido.
5. Execute **Workspace: atualizar indice dos projetos** para reconstruir registros
   e indice. Confira a origem MTA reconhecida; resolva origem ausente ou ambigua
   pelo fluxo de MTA existente antes de priorizar.
6. Execute **Planejamento: priorizar issues**, escolha uma categoria e informe
   **10%**. Execute o novo prompt e confira ranking e fichas por projeto/issue.
7. Escolha uma issue no registro, vincule sua ficha e acrescente anexos pertinentes.
   Execute **Planejamento: planejar** e confira os modelos comuns de plano/to-do
   nos destinos por artifactId e issue. Depois ensaie outra categoria e a retomada
   da primeira. Revisao/GO precedem a implementacao; aceite vem apos verificacoes.

Esse ensaio usa registros, contextos e prompts novos; nao recupera automaticamente
escolhas ou aprovacoes apagadas. Registre seus resultados e, para ensaiar a passagem
entre colegas, siga o [roteiro de compartilhamento](compartilhamento-contextos.md#ensaio-em-pequena-escala).

#### Pastas locais e backups temporarios

`.harness/` guarda dados locais do harness e e ignorada pelo Git. As pastas sao
criadas conforme o uso; nao precisam existir todas depois de uma limpeza.
Build usa projeto/data/ID; novos planos usam artifactId/issue/solicitacao e os
legados conservam seus destinos. MTA externo usa projeto/data compacta.
Os IDs completos permanecem nos recibos. `.harness/i` e outros worktrees de agentes
podem existir nesta maquina, mas nao sao resultados nem requisitos do harness.

| Pasta | Finalidade |
| --- | --- |
| `.harness/builds/` | Registro de cada build Maven: `console.log` e `result.json`, com projeto, comando/fases, ferramentas, estado Git coletado, datas, status e exit code. O WAR/JAR e os relatorios de testes continuam no `target/` da aplicacao. |
| `.harness/runs/` | Rodadas MTA locais ou indices `location.json` das rodadas externas: `manifest.json` identifica entrada, argumentos, hashes e estado Git; `result.json` registra resultado/integridade; `console.log` guarda a saida. Cada rodada possui `input/` (copia dos fontes analisados), `rules/` (regras usadas) e `output/` (achados, dependencias e relatorio HTML com seus arquivos). A copia `input/` e evidencia, nao checkout para corretivas. |
| `.harness/sonar/` | Resultados Sonar por projeto/data, com RESUMO.md, metricas, criterios e Gate; preservados pela limpeza de execucoes. |
| `.harness/planning/` | Contextos e prompts com base MTA ou EVIDENCIAS. Novos dossies em `<artifactId>/issues/<issue>/` reunem fichas, anexos e solicitacoes com plano/to-do de nomes identificaveis; sao preservados pela limpeza de execucoes. Legados conservam nomes e destinos. Manutencao usa `registro/solicitacao_<id>` e so reconcilia o registro. Preparar contexto sozinho nao cria plano/to-do nem aprova lote. |
| `.harness/priorizacao/` | Contexto e prompt por solicitacao para comparar issues entre projetos; `priorizacao.md` e produzido ao executar o prompt. Preservada pela limpeza de execucoes. A lista nao e plano nem escolha humana. |
| `.harness/importacoes/` | Originais e manifesto recebidos, recibo de importacao e diagnosticos/anexos transportados. Preservada pela limpeza; as copias operacionais dos planos e priorizacoes ficam em seus destinos habituais. |
| `.harness/backups-temporarios/` | Unico local para copias temporarias de exercicios/ajustes, agrupadas por atividade. Opcao **3** da tarefa lista os caminhos e exige **LIMPAR**. |
| `.harness/projetos/` | Registro por raiz local e evidencias/LEIA-ME.md; criacao idempotente, sem duplicar por rodada. Preservados pela limpeza, locais e ausentes no clone. |
| `.harness/projetos/indice-projetos.md` e `indices/` | Ultima acao por projeto e copias datadas dessas consultas, geradas pela tarefa de indice e preservadas pela limpeza. |
| `.harness/evidencias/` | Evidencias historicas, preservadas e ainda utilizaveis por EvidenceIndexPath. |
| `.harness/workspace-backups/` | Copia automatica do workspace anterior quando o gerador o substitui; permite recuperar pastas e ajustes manuais. Preservada pela tarefa de limpeza. |
| `.harness/tests/` | Fixtures e resultados dos testes dos scripts; descartaveis quando nenhum teste estiver rodando. Recriada nos proximos testes. |
| `%USERPROFILE%\.m2\repository` | Repositorio local padrao do Maven, fora do harness; compartilhado com os demais projetos da maquina, salvo configuracao propria do Maven. |

Na raiz tambem podem aparecer **arquivos de controle**, que nao sao pastas:
`mta.lock` coordena build/MTA/limpeza; `planning.lock` coordena preparacao/importacao/limpeza.
Eles podem permanecer vazios depois da execucao; sua existencia nao comprova
atividade. `active-mta.json` identifica a rodada para acompanhamento, e
`last-<Project>.json` aponta para a ultima rodada MTA bem-sucedida do projeto.
Esses ponteiros nao substituem os manifestos nem os resultados salvos.

Os fontes continuam no repositorio da aplicacao; o JSON local em `config/`, o
workspace ativo na raiz do harness e o template em `.github/prompts/`. Os planos
de evolucao do harness permanecem em `tasks/`, separados dos planos de corretivas.

As opcoes **1/2** limpam execucoes e preservam backups; a opcao **3** limpa somente
`backups-temporarios`, sem apagar execucoes ou backups do workspace. Nao criar
pastas de backup avulsas para cada ajuste na raiz de `.harness/`. Criar a pasta
central apenas quando houver algo a preservar. Agentes seguem essa regra em AGENTS.md.

Preview pelo terminal: `powershell.exe -NoProfile -File .\scripts\limpar-execucoes.ps1 -TemporaryBackups -Preview`.

### Tarefa e script correspondente

Referencia de consulta; para escolher a operacao e a ordem, use o
[roteiro principal](../harness-migracao-desenvolvedor.md#roteiro-onde-estou-e-o-que-escolho).

| Run Task | Arquivo em `scripts/` |
| --- | --- |
| [Workspace: configurar caminhos](#configuracao-da-maquina) | `configurar-caminhos.ps1` |
| [Workspace: gerar workspace](#opcao-a-editar-o-json-local-e-gerar-novamente) | `gerar-workspace.ps1` |
| [Workspace: limpar execucoes](#limpar-execucoes-locais) | `limpar-execucoes.ps1` |
| [Workspace: atualizar indice dos projetos](planejamento-migracao.md#indice-da-situacao-dos-projetos) | `atualizar-indice-projetos.ps1` |
| [MTA: conferir ambiente](mta.md#uso) | `conferir-ambiente.ps1` |
| [**Aplicacao: build Maven (Java 8)**](maven.md#uso) | **`construir-aplicacao.ps1 -Goals <fases escolhidas>`** |
| [Aplicacao: analisar SonarQube](sonar.md#uso) | `analisar-sonar.ps1` |
| [Servidor: iniciar JBoss](jboss.md#uso) | `gerenciar-jboss.ps1` (sem selecao de aplicacao) |
| [Servidor: parar JBoss](jboss.md#uso) | `gerenciar-jboss.ps1` (sem selecao de aplicacao) |
| [Servidor: consultar estado JBoss](jboss.md#uso) | `gerenciar-jboss.ps1` (sem selecao de aplicacao) |
| [Servidor: criar usuario JBoss](jboss.md#console-administrativa-e-usuario-de-gerenciamento) | `gerenciar-jboss.ps1 -Action AddUser` (assistente oficial com JDK 8, sem selecao de aplicacao) |
| [Aplicacao: deploy no JBoss](jboss.md#uso) | `gerenciar-jboss.ps1` (com selecao de aplicacao) |
| [Aplicacao: rollback no JBoss](jboss.md#uso) | `gerenciar-jboss.ps1` (com selecao de aplicacao) |
| [Aplicacao: preparar implementacao do lote](planejamento-migracao.md#preparar-implementacao-do-lote) | `preparar-implementacao.ps1` |
| [**MTA: executar analise**](mta.md#uso) | **`executar-mta.ps1`** |
| [**MTA: acompanhar log da analise**](mta.md#acompanhar-a-analise-mta) | **`acompanhar-log-mta.ps1 -Active`** |
| [**MTA: acompanhar atividade interna**](mta.md#acompanhar-a-analise-mta) | **`acompanhar-log-mta.ps1 -Active -Detalhado`** |
| [MTA: consultar log de execucao anterior](mta.md#acompanhar-a-analise-mta) | `acompanhar-log-mta.ps1 -SelectTarget -SelectRun -Once` (com workspace informado) |
| [MTA: abrir ultimo relatorio](mta.md#uso) | `abrir-relatorio-mta.ps1` |
| [Workspace: conferir configuracao ao abrir](#comecar-na-maquina-de-trabalho) | `conferir-ambiente.ps1 -AoAbrir` |
| [Planejamento: planejar](planejamento-migracao.md#preparar-e-executar-o-prompt) | `preparar-planejamento.ps1` |
| [Planejamento: priorizar issues](priorizacao-issues.md#uso-manual-pela-run-task) | `preparar-priorizacao.ps1` |
| [Planejamento: compartilhar contexto](compartilhamento-contextos.md) | `compartilhar-contexto.ps1` |
| [Planejamento: criar pasta de evidencias](planejamento-migracao.md#revisar-um-lote-com-evidencias-complementares) | `criar-pasta-evidencias.ps1` |
| [Planejamento: abrir plano e to-do](planejamento-migracao.md#localizar-documentos-e-identificar-o-historico) | `abrir-planejamento.ps1` |

Os comandos completos ficam no guia de cada ferramenta, junto das condicoes de
uso e dos resultados esperados. Para o ciclo build/MTA, siga o
[guia Maven](maven.md#uso) e o [guia MTA](mta.md#uso).

## Resultado e proximo passo

Com o workspace pronto, siga para [build e diagnostico](../harness-migracao-desenvolvedor.md#2-escolher-o-projeto-e-fazer-o-build)
ou [reutilize um MTA existente](../harness-migracao-desenvolvedor.md#3-obter-ou-reutilizar-o-diagnostico-mta).
Com issue/evidencias ja fornecidas, pode seguir diretamente ao
[registro e escolha](../harness-migracao-desenvolvedor.md#4-conferir-o-registro-e-escolher-prioridades)
e usar **Planejamento: planejar**, sem executar MTA apenas para preencher contexto.
Depois de ajustar configuracao ou limpar execucoes, confira o que permanece
disponivel e retome a [etapa do seu trabalho](../harness-migracao-desenvolvedor.md#como-usar-este-guia).
Configurar o ambiente nao executa a migracao.
