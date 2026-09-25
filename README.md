# JBoss MTA Harness

Repo independente para executar MTA pelo VS Code. Scripts, tarefas, prompt, configuracao e dois projetos de demonstracao estao aqui. **Este README e o unico guia.** Um clone permite ensaiar; depois, os exemplos podem ser removidos e substituidos pelos repositorios corporativos. JDKs, Maven, MTA e JBoss ficam nas pastas indicadas no JSON local.

## Comecar na maquina de trabalho

Use uma pasta local permitida pela empresa. Tenha Git, VS Code e Windows PowerShell 5.1 disponiveis; para o planejamento assistido, use Copilot autenticado em sessao Local com modo Agent e ferramentas de leitura disponiveis. Extraia a distribuicao Windows completa do MTA em uma pasta permitida, por exemplo `D:/ferramentas/mta` — **nao precisa ser `.kantra`**. Tenha tambem Maven, JDK do analisador (JDK 25 no ensaio) e JDK 8 da aplicacao. Se ja estiverem instalados, use essas instalacoes. O harness nao instala ferramentas nem exige variaveis globais.

Para o ensaio, nao precisa clonar outro repo: `exemplos/migracao-cache-antes` e `exemplos/migracao-cache-depois` ja acompanham este. JBoss 7.1/7.4 podem permanecer nas pastas onde foram extraidos; seus caminhos sao opcionais nesta primeira etapa. **Sonar, build e deploy nao fazem parte deste primeiro fluxo MTA + planejamento.**

Em uma pasta de repositorios permitida, execute:

```powershell
git clone https://github.com/edoardo-bianco/jboss-mta-harness.git
```

1. No VS Code, use **File > Open Workspace from File** e abra `jboss-mta-harness.code-workspace`, na raiz do clone. Ele ja mostra `harness`, `migracao-cache-antes` e `migracao-cache-depois`, com caminhos relativos. Abrir a pasta do repo tambem permite executar as tarefas.
2. Execute **Terminal > Run Task > Workspace: configurar caminhos**. A tarefa cria e abre `config/harness.local.json`, sem sobrescrever uma configuracao existente.
3. Preencha em `tools` os caminhos **desta maquina** e salve. Os dois exemplos e `activeProject: migracao-cache-antes` ja estao configurados; mantenha-os para o primeiro ensaio. Use o [exemplo completo abaixo](#configuracao-da-maquina). Para repositorios Maven privados/proxy, informe o caminho do `settings.xml` aprovado em `tools.mavenSettingsPath`; nao copie o settings da demo pessoal.
4. Execute **Terminal > Run Task > Workspace: gerar workspace**. Abra o arquivo gerado `jboss-mta-harness.local.code-workspace`, na raiz do clone, em **File > Open Workspace from File**. O Explorer deve mostrar `harness` e os projetos cadastrados.
5. Execute **MTA: conferir ambiente**, da pasta `harness`. Deve mostrar `OK`, o projeto certo, os caminhos locais, perfil `eap71-to-eap74-java8`, `Targets: eap7 | Modo: full` e filtro source nenhum. Se falhar, use **Workspace: configurar caminhos**, corrija o JSON e repita a conferencia.
6. Execute **MTA: executar analise** uma unica vez. Aguarde o JSON final com `Status: SUCCEEDED`, `ExitCode: 0` e verificacoes de integridade verdadeiras. Para acompanhar, use **MTA: acompanhar atividade interna** em outro terminal; `Ctrl+C` nesse leitor nao para a analise.
7. Execute **MTA: abrir ultimo relatorio** para abrir o HTML no navegador. A tarefa de analise apenas imprime o caminho. Guarde a pasta `Rodada`/o `RunId` para [planejar os lotes no Copilot](#planejar-lotes-de-correcao-com-copilot).

Ao abrir a pasta/workspace, a conferencia automatica abre o JSON se estiver incompleto. O VS Code pode pedir para permitir tarefas automaticas; a tarefa manual de configuracao funciona independentemente dessa permissao. Nenhuma analise comeca automaticamente.

Nos proximos dias, abra diretamente o `.local.code-workspace` gerado. O `.code-workspace` versionado e o ponto de partida portavel; o `.local.code-workspace` gerado reflete seus caminhos/projetos. Relatorios, configuracao pessoal e workspace local nao acompanham o clone. Se uma politica impedir scripts, siga o procedimento de liberacao da empresa; este guia nao usa bypass nem altera ExecutionPolicy.

## Ensaiar e depois usar os projetos corporativos

| Projeto incluido | Conteudo e resultado esperado com MTA 8.2.1/regras ensaiadas |
| --- | --- |
| `migracao-cache-antes` | Codigo original, proveniente do commit `1bfbae96ebd39a3e996d07682ad88cd7af603cbf` da demo local. Regras `hibernate51-53-00400` e `00401` apontam a mesma chamada `getQueryCache()` em `LimpezaCache.java`; triagem precisa distinguir o overload e evitar dupla contagem. |
| `migracao-cache-depois` | Mesma aplicacao com a correcao minima `factory.getCache().evictDefaultQueryRegion()` e POM alinhado ao Hibernate `5.3.20.Final-redhat-00001` do EAP 7.4 local. O resultado MTA anterior precede esse alinhamento do POM; a nova combinacao requer sua propria rodada. Nao e comprovacao de homologacao no EAP 7.4. |

As duas pastas incluem POM, fontes e testes Java 8. Sao projetos independentes para selecionar um por vez, nao modulos de um reactor comum. Foram preservados `javax.*`, WAR e contratos. No exemplo DEPOIS, `hibernate-core` permanece `provided` e `hibernate-ehcache` fica em `test`, ambos na versao do destino local; o POM declara o repositorio Red Hat GA. Na empresa, o repositorio Maven aprovado deve disponibilizar esses artefatos; confira a versao do EAP instalado. Ao corrigir ANTES numa branch, seu conteudo deixa de ser o baseline original: compare pelos snapshots das rodadas. A distribuicao MTA, caches Maven e resultados antigos nao sao publicados aqui.

Comece pelo `migracao-cache-antes`, abra o relatorio e use `/planejar-lotes`. Para comparar com o exemplo ja corrigido, mude `activeProject` para `migracao-cache-depois` e execute MTA novamente; cada projeto recebe suas proprias rodadas. Para um ensaio independente, peca ao Copilot que se limite ao projeto selecionado, sem consultar a solucao do outro exemplo.

**Apos o ensaio, para manter apenas os projetos corporativos:**

1. Clone os repositorios reais em pastas externas ao harness, usando os meios aprovados pela empresa.
2. Em **Workspace: configurar caminhos**, substitua as duas entradas de exemplo em `repositories` pelos repositorios reais e ajuste `activeProject` para um deles.
3. Execute **Workspace: gerar workspace** e abra o `.local.code-workspace` gerado. Ele mostrara apenas o harness e os projetos cadastrados.
4. As pastas em `exemplos/` podem entao ser removidas, se desejado. O harness nao depende delas quando nao estao no JSON. Use o workspace local gerado, pois o workspace inicial versionado continua sendo o modelo para o ensaio.

Remover as entradas do workspace nao apaga codigo nem evidencias antigas. Nao ha exclusao automatica dos exemplos e nao e necessario mudar scripts para adicionar projetos corporativos.

## Tarefa e script correspondente

| Run Task | Arquivo em `scripts/` |
| --- | --- |
| **MTA: executar analise** | **`executar-mta.ps1`** |
| **MTA: acompanhar log da analise** | **`acompanhar-log-mta.ps1`** |
| **MTA: acompanhar atividade interna** | **`acompanhar-log-mta.ps1 -Detalhado`** |
| MTA: abrir ultimo relatorio | `abrir-relatorio-mta.ps1` |
| MTA: conferir ambiente | `conferir-ambiente.ps1` |
| Workspace: configurar caminhos | `configurar-caminhos.ps1` |
| Workspace: gerar workspace | `gerar-workspace.ps1` |
| Workspace: conferir configuracao ao abrir | `conferir-ambiente.ps1 -AoAbrir` |

Execucao direta, na pasta deste repo:

```powershell
powershell.exe -NoProfile -File .\scripts\executar-mta.ps1
```

## Planejar lotes de correcao com Copilot

O [prompt planejar-lotes](.github/prompts/planejar-lotes.prompt.md) ja acompanha o clone. **Voce o aciona; ele nao executa automaticamente depois do MTA.** Ele seleciona modo **Agent** com apenas quatro ferramentas: `read/readFile`, `search/listDirectory`, `search/fileSearch` e `search/textSearch`. A proposta continua somente por leitura: sem ferramentas de edicao, terminal, tarefas, web ou delegacao. A configuracao pertence ao repo; nao exige configurar um agente global na maquina. [Formato e prioridade das ferramentas nos prompts do VS Code](https://code.visualstudio.com/docs/agent-customization/prompt-files).

**Fluxo pratico, sem anexar um arquivo por vez:**

1. Abra o `.local.code-workspace` gerado, contendo o harness e a aplicacao, e inicie uma **nova conversa Copilot Local** com um modelo que ofereca ferramentas.
2. Digite `/planejar-lotes` e selecione a sugestao. Confira que o prompt usa **Agent**, nao Ask. Na selecao **Configure Tools** do chat, confira as quatro ferramentas de leitura/busca acima. O prompt limita a lista ao ser executado; nao habilite ferramentas de escrita ou terminal para este planejamento.
3. Cole o texto abaixo preenchido e envie. O agente deve mostrar chamadas de leitura e confirmar o projeto/rodada a partir dos arquivos antes de propor lotes.

Substitua `<PROJETO>`, `<PASTA_DA_RODADA>` e `<PASTA_DA_APLICACAO>` por valores reais. A pasta da rodada e a mostrada no terminal em `Rodada`, terminando no RunId; a da aplicacao e `repositories[].path` para o projeto ativo. Nao use a pasta `input` da rodada como checkout de trabalho.

```text
Projeto: <PROJETO>
Pasta da rodada MTA: <PASTA_DA_RODADA>
Pasta da aplicacao: <PASTA_DA_APLICACAO>

Leia diretamente, usando as ferramentas de leitura disponiveis:
- manifest.json e result.json da rodada;
- output/output.yaml e output/dependencies.yaml;
- pom.xml, POMs dos modulos e fontes/testes pertinentes em src da aplicacao;
- arquivos YAML em rules da rodada que sustentam os achados.

Esses arquivos constituem o contexto autorizado desta analise.
Nao leia logs, credenciais ou configuracoes pessoais.
Nao execute terminal nem altere arquivos.

Primeiro confirme quais arquivos conseguiu ler. Se algum estiver
inacessivel, informe exatamente qual, sem presumir seu conteudo.
Depois faca a triagem e proponha os lotes conforme /planejar-lotes,
considerando tambem desenvolver uma receita OpenRewrite quando fizer sentido.
Entregue somente a proposta no chat, com as evidencias e lacunas.
```

A leitura pelos caminhos depende das ferramentas/permissoes do cliente; informar um caminho nao equivale a anexar seu conteudo. Confira a lista de arquivos efetivamente lidos na resposta. `.harness` e ignorada/oculta e pode nao aparecer no indice: o agente deve tentar a leitura direta do caminho informado, sem confundir ausencia na busca com arquivo inexistente.

**Se aparecer "nao ha ferramenta de leitura nesta conversa":** abra nova conversa Local, selecione um modelo com ferramentas e acione novamente `/planejar-lotes`; confira `read/readFile` em **Configure Tools**. Se o prompt continuar antigo, use **Developer: Reload Window** quando nao houver tarefas em andamento. Se as ferramentas nao existirem ou estiverem bloqueadas nessa instalacao, a configuracao/permissao do Copilot precisa ser resolvida com o suporte da empresa. Anexar uma pasta pode fornecer apenas referencias e nao resolve, por si so, a falta de ferramentas. Nao e necessario compactar ou reunir arquivos.

**Se `/planejar-lotes` nao aparecer:** confira se a pasta `harness` esta aberta no workspace e se `.github/prompts/planejar-lotes.prompt.md` existe no clone. Use **Chat: Open Customizations** para conferir descoberta/erros. Este fluxo usa Copilot Local; sessoes Agent Host nao carregam prompt files. A disponibilidade no DevSquad/outro cliente deve ser conferida, sem assumir que uma conversa sem ferramentas consegue ler os paths. A descoberta do comando foi confirmada no ensaio local; a leitura pelo modo Agent ainda precisa de ensaio no cliente. [Ferramentas do VS Code](https://code.visualstudio.com/docs/agents/reference/tools-reference).

Revise a triagem, a matriz de dependencias e a tabela de lotes antes de escolher um primeiro lote. Arvore Maven, conteudo do WAR, modulos EAP e Sonar ANTES entram quando disponiveis e revisados; ausencia deve constar como pendencia, sem inventar evidencias. Nao misture rodadas nem exponha credenciais, settings privados ou logs brutos. A proposta tambem pode ser preparada por humano usando os mesmos criterios.

**Lote de correcao** e uma convencao deste projeto: ocorrencias correlacionadas com objetivo, solucao, aceite e reversao comuns. Mesma regra MTA nao basta para agrupar. Nao ha relacao obrigatoria de um apontamento = um lote = uma receita; preservar IDs e evidencias historicas chamados de "fatia".

O agente avalia receita OpenRewrite existente, composicao YAML/Refaster, receita Java propria ou ajuste especifico/combinado. Ausencia de receita pronta nao prova impossibilidade: considerar tipos/classpath, viabilidade, custo e reuso. Receita candidata precisa de testes, `dryRun`, revisao do patch e GO antes do `run`. Essa etapa prepara somente o plano; nao instala ou executa OpenRewrite. [Receitas](https://docs.openrewrite.org/concepts-and-explanations/recipes) e [dryRun/run](https://docs.openrewrite.org/reference/rewrite-maven-plugin).

Preservar Java 8, `javax.*`, arquitetura, contratos e baselines. **O corrigido sera testado somente no EAP 7.4; EAP 7.1 e referencia historica, sem exigir retrocompatibilidade.** Sonar e criterios de qualidade permanecem no plano de validacao; ausencia de Sonar nao bloqueia a proposta preliminar nem equivale a conformidade. Nao ha aceite, alteracao de codigo, commit/push ou proximo lote automaticos. Este prompt nao implementa Start/Stop/Deploy nem comprova o ciclo integrado.

## Configuracao da maquina

O exemplo versionado e `config/harness.example.json`; a tarefa cria dele o seu `config/harness.local.json`. Use caminhos reais com `/` ou `\\`, sem variaveis como `%JAVA_HOME%`. Caminhos relativos partem da pasta deste repo.

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
| `repositories` | Os dois exemplos incluidos ou uma lista como `[{"name":"sistema-a","path":"D:/repos/sistema-a"}]`. Para projetos reais, use pastas externas ao harness; selecione a raiz Maven com `pom.xml` e seus modulos. |
| `activeProject` | O `name` do unico repositorio que sera analisado, por exemplo `"sistema-a"`. |
| `tools.mtaExecutable` | Caminho completo do `windows-mta-cli.exe` dentro da distribuicao completa. Essa pasta tambem define onde o MTA busca seus componentes. |
| `tools.mtaJdkHome` | Pasta do JDK do analisador. O ensaio local utilizou JDK 25. |
| `tools.mavenHome` | Pasta do Maven, que contem `bin/mvn.cmd`. |
| `tools.mavenSettingsPath` | Opcional: `settings.xml` aprovado para repositorios/proxy. Nunca coloque credenciais neste JSON. |
| `tools.applicationJdk8Home` | Opcional nesta etapa: pasta do JDK 8, configurada no workspace para a aplicacao. |
| `tools.eap71Home`, `tools.eap74Home` | Opcionais: pastas dos JBoss ja extraidos, reservadas para a etapa de runtime. |
| `mta.rulesPath` | `null` usa `rulesets/java` ao lado da CLI; preencha se as regras Java estiverem em outra pasta. |
| `mta.profile` | `"eap71-to-eap74-java8"`: origem EAP 7.1, destino EAP 7.4, Java 8 e `javax.*`. |
| `mta.sources`, `mta.targets`, `mta.mode` | Mantenha `[]`, `["eap7"]` e `"full"`. O harness recusa desvios desse perfil. |

**Trocar projeto:** altere `activeProject`, salve e execute MTA. **Adicionar repositorios ou mudar paths de ferramentas:** ajuste o JSON, gere e reabra o workspace. A lista de pastas vem do JSON; alteracoes feitas somente na interface sao substituidas na proxima geracao, com backup em `.harness/workspace-backups/`. Uma biblioteca visivel nao e compilada nem analisada automaticamente junto com outro repo.

## O que acompanha o clone

Scripts, tarefas, prompt, exemplo de configuracao, workspace inicial, dois projetos de demonstracao, testes e este README entram no Git. `config/harness.local.json`, o workspace gerado e `.harness/` sao locais e ignorados. O clone no trabalho pede os caminhos dessa maquina, sem carregar caminhos pessoais. **Este repo nao depende de outro harness nem dos checkouts locais usados para criar os exemplos.**

Os programas precisam estar instalados/extraidos nessa maquina. **O MTA pode ficar em qualquer pasta local permitida pela empresa; `.kantra` nao e obrigatorio.** Extraia a distribuicao Windows completa nessa pasta, preservando CLI, `java-external-provider.exe`, `jdtls/`, `rulesets/`, `static-report/` e os demais arquivos do ZIP. Nao basta mover so o executavel. Nao ha instalacao automatica nem alteracao de ExecutionPolicy.

Por exemplo, se a pasta permitida for `D:/ferramentas/mta`, informe `"D:/ferramentas/mta/windows-mta-cli.exe"` em `tools.mtaExecutable`. Com `mta.rulesPath: null`, as regras virao de `D:/ferramentas/mta/rulesets/java`. O harness define `KANTRA_DIR` com a pasta do executavel somente no processo da analise e restaura o valor anterior ao terminar, inclusive em caso de falha. Nao precisa configurar essa variavel globalmente. **MTA: conferir ambiente** mostra a pasta efetiva e confere a presenca dos componentes essenciais. [Resolucao da pasta pelo Kantra](https://github.com/konveyor/kantra/blob/main/pkg/util/util.go).

As tarefas usam Windows PowerShell 5.1. Java e Maven sao configurados somente no processo da analise, a partir do JSON: nao precisa ajustar `JAVA_HOME` ou PATH global. O JDK do MTA nao muda o Java 8/POM da aplicacao. Combinacao ensaiada: MTA 8.2.1, JDK 25 e Maven 3.9.16. A analise completa pode acessar os repositorios Maven definidos nos settings.

## Analise e resultados

Mantenha o bloco `mta` do exemplo completo acima para preservar o perfil ensaiado.

**Origem/destino da migracao e filtros do MTA sao coisas distintas.** A CLI 8.2.1 ensaiada nao oferece target `eap7.4`. Usamos `eap7`, incluindo as regras Hibernate 5.1 para 5.3: no arquivo instalado `eap7/116-hibernate51-53.windup.yaml`, elas tem source `hibernate`/`hibernate5.1-` e target `eap7`. Acrescentar `--source eap7.1` excluiria essas regras. `sources: []` e intencional: nao envia `--source`. A selecao por rotulos e descrita no [guia de regras do Kantra](https://github.com/konveyor/kantra/blob/main/docs/rules-quickstart.md).

Preservamos `full`, `--run-local`, todas as regras YAML da pasta Java (sem fixtures de teste), `--enable-default-rulesets=false` e ausencia de `--json-output`. O perfil identifica o objetivo; nao reescreve regras nem transforma o conjunto amplo `eap7` em cobertura exata do EAP 7.4. O Copilot/desenvolvedor deve triar a aplicabilidade por versao e dependencia; o corrigido sera validado no EAP 7.4. Nao converter `javax.*` para `jakarta.*` nem trocar o target para `eap8`.

JSONs locais anteriores, sem `profile` e `sources`, recebem esses valores em memoria; caminhos permanecem inalterados. As novas rodadas registram perfil, origem/destino e filtros no manifesto, alem dos argumentos e hashes das regras. Atualizar a distribuicao ou `rulesPath` exige conferir novamente a comparabilidade com o baseline: o nome do perfil sozinho nao garante regras identicas.

Cada rodada fica em `.harness/runs/<projeto>/<id>/`, com copia do reactor e das regras, `manifest.json` (argumentos/hashes), `console.log`, `result.json` e `output/static-report/index.html`. Excluimos `.git`, `.harness`, `.scannerwork`, `node_modules` e pastas Maven `target`; preservamos `.mvn` e os modulos. Modulos/pais externos precisam estar disponiveis no Maven ou incluidos na raiz escolhida. Links/junctions nao sao suportados. As fontes originais e as regras sao conferidas depois da execucao.

Uma falha nao substitui o ultimo relatorio concluido do projeto. `SUCCEEDED` confirma a execucao e as verificacoes locais, nao a homologacao no EAP 7.4. Sonar, build e deploy ficam para etapas posteriores.

**Acompanhar a execucao:** o terminal de **MTA: executar analise** ja mostra a saida. Para abrir um leitor separado, aguarde a mensagem `Rodada` e execute **MTA: acompanhar log da analise**. Mostra as ultimas 40 linhas do `console.log` da rodada mais recente com manifesto do `activeProject` (inclusive falhas) e acompanha novas linhas. O terminal identifica projeto, rodada e caminho; confira se e a rodada desejada. `Ctrl+C` nesse leitor encerra somente o acompanhamento. Ele fica nessa rodada e nao muda para outra automaticamente; encerre-o ao concluir e confira o JSON final no terminal original. Se a rodada ja tiver `result.json`, mostra o resultado e as ultimas linhas e encerra. Se o log ainda nao existir, informa a situacao sem abrir um log antigo.

Para escolher uma rodada explicitamente, use `powershell.exe -NoProfile -File .\scripts\acompanhar-log-mta.ps1 -RunId <id>`. Adicione `-Once` para mostrar somente as ultimas linhas, sem esperar. O leitor nao inicia/cancela MTA nem altera arquivos; nao acompanha os logs internos do JDT.

**Console sem novas mensagens:** use **MTA: acompanhar atividade interna**. No mesmo script, `-Detalhado` consulta `.metadata/.log` da rodada a cada 5 segundos e mostra horario/idade da ultima gravacao e ate quatro linhas resumidas de mensagens/classes/consultas. Le no maximo 16 KiB por consulta e reabre o arquivo para tolerar rotacao, sem despejar o log inteiro. Nao altera o nivel de log nem a analise. Encerra ao encontrar `result.json` legivel ou com `Ctrl+C`; `-Detalhado -Once` faz apenas uma consulta. Logs atualizados indicam atividade, nao porcentagem/progresso garantido; silencio sozinho tambem nao comprova travamento. Esta visao usa o formato JDT observado na CLI ensaiada e pode ficar indisponivel em outra versao.

Para testar somente o harness: execute `powershell.exe -NoProfile -File .\tests\Test-Workspace.ps1` e `powershell.exe -NoProfile -File .\tests\Test-Mta.ps1`. Criam fixtures em `.harness/tests/`; o segundo simula a chamada ao processo MTA.

Para testar o acompanhamento de log, execute `powershell.exe -NoProfile -File .\tests\Test-MtaLog.ps1`. Usa logs ficticios e verifica inclusive novas linhas durante a leitura, sem executar MTA.
