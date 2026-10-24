---
html:
  embed_local_images: true
  embed_svg: true
  offline: true
---

# Orientacao da migracao com Claude Code, Codex ou GitHub Copilot

[Voltar ao fluxo do desenvolvedor](harness-migracao-desenvolvedor.md#roteiro-onde-estou-e-o-que-escolho).

Use este guia para iniciar ou retomar a migracao com apoio do agente, identificar
a etapa atual e receber uma proxima acao. A skill
[orientar-migracao](../../.agents/skills/orientar-migracao/SKILL.md) e o conjunto de
instrucoes compartilhadas pelos clientes. `migracao_helper` e o papel de orientador
que aplica essas instrucoes e consulta os helpers especializados quando pertinente.

O helper le indice, registro, contexto corrente, planos, prompts e evidencias.
Ele responde com **uma proxima acao**, motivo, caminho/mensagem prontos e resultado
a conferir. Voce executa as tarefas, escolhe prioridades, concede GO e aceita o
resultado. Nao precisa conhecer os nomes dos campos internos para pedir ajuda.

Para recuperar uma issue ou conferir a base pelas ferramentas opcionais, configure as
[consultas MCP](tools/consultas-issues.md#configurar-mcp-no-codex-e-no-copilot).
O helper pode chamar as tres ferramentas de leitura diretamente, sem terminal
geral. Sem MCP, continua pela leitura direta dos arquivos e pelo fluxo habitual
de priorizacao/planejamento; a CLI e uma alternativa opcional para consulta pontual.
Os perfis continuam sem executar tarefas/corretivas. Confira origem, paginas e
truncamentos antes de usar a resposta como evidencia.

Para arquivos recebidos de colega, siga o [roteiro de copia entre projetos](tools/compartilhamento-contextos.md):
associe o POM local, preserve as contribuicoes e reconcilie os documentos pela
tarefa **Planejamento: atualizar registro de migracao**. ZIP pode transportar os
arquivos, mas nao ha importacao/exportacao de pacote pelo harness.
Analise recebida segue para escolha/planejamento; proposta recebida exige
conferencia de escopo/GO e codigo local antes da execucao.

Para compartilhar somente os documentos no `simtr-doc` ou outro repositorio da
equipe, o helper consulta o
[passo a passo com prompts e verificacoes](tools/compartilhamento-documental-passo-a-passo.md).
Ele identifica a etapa atual e preserva o escopo escolhido, inclusive todos os
projetos Java locais. O inventario pode ser conferido em leitura; copia,
publicacao Git e reconciliacao sao encaminhadas ao executor do cliente atual.
Exemplo de pedido:

```text
Quero compartilhar somente os documentos da .harness de todos os projetos
Java locais adicionados ao harness no simtr-doc. Oriente a proxima etapa
usando o passo a passo documental, com o prompt e as verificacoes pertinentes.
```

Navegacao: [configuracao](#configuracao) · [iniciar](#iniciar-no-codex-ou-no-copilot) ·
[retomar](#retomar-em-outro-chat-ou-cliente) · [pedidos por etapa](#pedidos-por-etapa) ·
[resultado e proximo passo](#resultado-e-proximo-passo).

## Configuracao

Abra o workspace que inclui a pasta do harness e os projetos desejados. A
[configuracao da maquina e do workspace](tools/workspace.md#configuracao) fica no
guia proprio. No Claude Code e no Codex, inicie a conversa com a raiz do harness
como pasta de trabalho: uma aplicacao em repositorio irmao nao herda
automaticamente suas skills e helpers.

As instrucoes ficam em `.agents/skills` no repositorio, local reconhecido por
[Codex](https://learn.chatgpt.com/docs/build-skills) e
[Copilot no VS Code](https://code.visualstudio.com/docs/agent-customization/agent-skills).
No [Claude Code](https://code.claude.com/docs/en/skills), a descoberta usa
`.claude/skills/orientar-migracao/SKILL.md`, um ponteiro para a mesma skill comum,
sem regras proprias. A descoberta depende do cliente e da pasta aberta. Nao e
necessario regenerar o workspace para acrescentar a skill.

O helper tambem orienta a [instalacao do Node em pasta fixa e configuracao MCP](tools/consultas-issues.md#instalar-node-em-pasta-fixa).
Informe a versao atual, pasta escolhida e etapa ja realizada; veja a
[mensagem de exemplo](tools/consultas-issues.md#orientacao-com-o-helper).
Essa orientacao de ambiente nao exige selecionar projeto, MTA ou criar registro.
O desenvolvedor executa os comandos e retorna com o resultado para o proximo passo.

Para preparar sua maquina ou as dos colegas, use o [roteiro por maquina](tools/workspace.md#preparar-as-maquinas-dos-colegas).
O helper consulta os mesmos guias vinculados pelo README e pelo guia do desenvolvedor,
inclusive o [preparo do certificado Sonar](tools/sonar.md#certificado-publico-do-sonar-corporativo).
Ele informa a fonte e a proxima acao, sem instalar certificados ou ferramentas.

Para comecar com MTA ja existente, informe a raiz externa configurada, como
`C:/mta-runs`, e os projetos do workspace. O helper orienta a
[associacao pelo indice](tools/mta.md#origem-mta-e-caminhos), sem exigir nova analise
ou copia dos relatorios. Novas analises tambem usam obrigatoriamente essa raiz
externa; documentos, fichas e indices permanecem na `.harness` por projeto.
O conversor legado foi retirado. No inicio novo, o helper nao pede conversao
nem trata o MTA como recuperacao de decisoes ou fichas humanas anteriores.

### Se a skill ou o agente nao aparecer

Confira os arquivos no clone e se as customizacoes estao habilitadas no cliente.
No Copilot, consulte **/skills** e a lista de agentes; no Codex, reinicie o cliente
se a descoberta nao refletir os novos arquivos. No Claude Code, **/agents** lista os
helpers e a skill aparece entre as disponiveis; inicie nova sessao depois de
atualizar os arquivos. Sem descoberta automatica, pode
referenciar o SKILL.md pelo caminho e pedir que o cliente leia e aplique suas
instrucoes; isso nao comprova a integracao nativa.

O apoio de skills/subagentes no Codex e DevSquad no Copilot depende das capacidades
instaladas e permitidas. Se faltar apoio compativel com leitura e orientacao,
o helper informa a limitacao e continua pelos guias/helpers locais.

## Uso

### Se a chamada de subagente falhar

Registre cliente/sessao, condutor, nome exato solicitado, ferramenta e mensagem
de erro. Na priorizacao pelo Copilot, o prompt usa `devsquad` com apoio de `devsquad.plan`;
na orientacao, `migracao_helper` coordena os helpers leitores do repositorio.
O ranking deve informar qual apoio foi realmente usado e eventuais falhas.

Em sessao Local do Copilot, confira **Run Subagent** em **Configure Tools**,
o nome (inclusive maiusculas/minusculas), a lista `agents` do condutor e
`disable-model-invocation` do destinatario. Aparecer no seletor nao comprova
permissao de chamada; ocultacao por `user-invocable` e uma propriedade diferente.
Veja [diagnostico de subagentes no VS Code](https://code.visualstudio.com/docs/agents/run/subagents#troubleshooting).

Se preciso, use **Developer: Open Agent Debug Logs** e localize a chamada/erro;
compartilhe somente o trecho pertinente sem credenciais ou dados sensiveis.
Veja [depuracao do chat](https://code.visualstudio.com/docs/agents/agent-troubleshooting/chat-debug-view).

Perfis de plugins podem permitir somente seus proprios subagentes. Confira o
perfil efetivamente instalado na maquina afetada; a configuracao de outro
computador nao prova a causa. Nao amplie permissoes nem edite o plugin como
primeiro recurso. Sem apoio compativel, o condutor pode continuar diretamente
conforme o prompt e suas ferramentas; informe a limitacao. Helpers permanecem
leitores. Falta de ferramenta essencial deve ser resolvida explicitamente.

<a id="iniciar-no-codex-ou-no-copilot"></a>

### Iniciar no Claude Code, Codex ou Copilot

| Cliente | Como entrar na orientacao |
| --- | --- |
| Codex | Selecione **$orientar-migracao** no chat. Ela assume o papel de orquestrador helper. |
| GitHub Copilot | Abra a lista de agentes do Chat e selecione **migracao_helper**. A skill tambem pode ser usada por **/orientar-migracao**. |
| Claude Code | No terminal da raiz do harness, inicie `claude --agent migracao_helper`: a conversa inteira assume o helper. Numa conversa normal, peca "Use o subagente migracao_helper para me orientar" ou use **/orientar-migracao**. |

Depois envie o objetivo. Os exemplos dos guias usam `projeto X`: substitua pelo
seu projeto. A mesma mensagem serve nos tres clientes, apos selecionar a entrada
acima; ela e um pedido no chat, nao um comando de terminal.

```text
Quero iniciar a migracao do projeto X, que ja esta no workspace.
Confira o contexto existente e me oriente no proximo passo.
```

O helper parte de `.harness/indices/projetos.md` e do `indice.md` do projeto.
O registro `migracao.md` concentra escolhas; o trabalho corrente fica em
`.harness/projetos/<artifactId>/atual/`. Pede projeto ou caminho somente quando
os arquivos nao resolvem a ambiguidade. Se faltar registro, orienta
**Workspace: atualizar indice dos projetos**. Nao exige IDs de solicitacao.

Execute a acao indicada e retorne com o resultado. O helper confere a saida e
orienta a seguinte. Para comparar candidatas antes de escolher, use o exemplo
de [pre-planejamento](tools/priorizacao-issues.md#orientacao-com-o-helper).

### Passar da orientacao para a execucao

O helper entrega a mensagem pronta para o cliente atual, com os caminhos reais.
Quando a tarefa preparar um prompt:

- **Codex:** abra uma nova conversa no mesmo workspace, com o agente principal,
  sem selecionar `migracao_helper` nem invocar `$orientar-migracao`. Nessa conversa
  de execucao, envie `Execute o prompt deste arquivo:` seguido do caminho fornecido
  e `Use $using-agent-skills se disponivel; senao, prossiga no agente principal`.
  O prompt e seu contexto recuperam a etapa, as escolhas e os limites; nao e preciso
  copia-los novamente. A conversa com o helper permanece para orientacao e pode
  ser retomada depois com o resultado.
- **Copilot:** abra o arquivo `.prompt.md` preparado e use o botao **Executar
  Prompt** em sessao **Local**. O cabecalho `agent: devsquad` solicita a selecao
  automatica do perfil `devsquad` instalado nesse cliente. Ele atua como
  orquestrador: delega analises pertinentes, confere os retornos e consolida as
  saidas autorizadas. Colar/anexar o arquivo em uma mensagem nao e a execucao
  nativa do prompt e nao garante a troca do seletor.
- **Claude Code:** abra uma conversa normal (`claude`, sem `--agent migracao_helper`)
  na raiz do harness e envie `Leia e execute o prompt deste arquivo:` seguido do
  caminho fornecido e `Use using-agent-skills se disponivel; senao, prossiga no
  agente principal`. O campo `agent:` do prompt pertence ao Copilot e nao seleciona
  perfil no Claude Code; as permissoes sao as da sessao. A mesma regra de skill
  opcional e agente principal vale para os demais clientes.

`using-agent-skills` descobre skills de apoio; nao e nome de agente nem requisito
de instalacao. Sua ausencia nao impede executar o prompt. Os helpers consultados
continuam leitores; esse limite nao se transfere ao orquestrador. A skill
`orientar-migracao` nao deve assumir o controle de um pedido de execucao feito ao
agente principal, mesmo quando carregada automaticamente.

**Fallback no Copilot:** se `devsquad` nao estiver instalado/reconhecido, selecione
**Agent** e envie `Execute o prompt deste arquivo:` com o mesmo caminho. Agent
assume a execucao e usa apoio disponivel; nao e preciso instalar outro perfil.
O formato nativo documenta um unico `agent`, sem lista condicional de fallback.
Por isso, o harness nao promete trocar o seletor por uma instrucao no corpo do
prompt nem substitui o perfil externo do usuario.

**Se o perfil nao mudar ou a resposta pedir o mesmo prompt novamente:** confira
se o arquivo foi executado pelo botao do editor, se a sessao e Local e se o
perfil `devsquad` aparece entre os agentes disponiveis. Na interface atual do
VS Code, a sessao chamada Copilot e distinta da Local; o modo Agent, sozinho,
nao identifica o tipo de sessao. Com `devsquad` ja selecionado, a resposta deve
seguir o contrato de execucao e indicar impedimento concreto, caso exista.
Nao recrie contexto/base/fatia apenas por esse problema. Veja o comportamento
suportado em [prompt files do VS Code](https://code.visualstudio.com/docs/agent-customization/prompt-files#use-a-prompt-file-in-chat)
e o [campo agent](https://code.visualstudio.com/docs/agent-customization/prompt-files#prompt-file-format).

A execucao desse prompt e uma etapa distinta da orientacao; helpers continuam
leitores. Preparar o contexto nao executa o agente. Para o agente salvar o ranking
ou plano, execute o prompt correspondente; aplicar corretivas exige GO para o escopo.
Verificacoes tecnicas e aceite do resultado continuam separados.
Veja o [procedimento de planejamento e execucao](tools/planejamento-migracao.md#preparar-e-executar-o-prompt).

### Continuar manualmente a partir de uma ficha

Pode ser outro colega quem implementa. O orientador recupera a ficha e os anexos
do projeto/issue, confere se existe plano/tarefas correntes e indica a etapa que falta.
Os documentos seguem [estrutura padronizada e dossie por issue](tools/planejamento-migracao.md#dossie-por-issue-e-passagem-entre-colegas).
Com somente analise, orienta elaborar o plano; com proposta, revisar GO; com GO,
seguir execucao manual ou por agente de codificacao conforme a escolha humana.
O orientador continua leitor. Documentos e evidencias suficientes permitem
implementar sem acesso ao MTA original, conferindo o codigo local e as lacunas.
Para usar os documentos em outra raiz, siga a [associacao ao POM e reconciliacao](tools/compartilhamento-contextos.md).
O contexto tecnico precisa apontar para os destinos locais correntes.

O helper e opcional e tambem orienta trabalho manual. Diga, por exemplo:

```text
Quero investigar manualmente a issue de email do projeto X, que ficou SEM POSICAO.
Use a ficha do relatorio para indicar a primeira verificacao, os arquivos a ler
e a evidencia que devo guardar.
```

Ele deve recuperar a ficha, explicar o achado e encaminhar uma acao concreta, com
links e resultado esperado. SEM POSICAO nao impede sua escolha nem exige outro
ranking. A mesma orientacao vale para uma issue recomendada com lacunas.
Para planejar manualmente, o helper indica os destinos do contexto e os criterios
do guia; se ja houver proposta, parte dela. Se voce pedir trabalho assistido,
encaminha o prompt preparado. Nao deve exigir execucao pela IA para seguir manualmente.
Veja [a ficha e o roteiro manual](tools/priorizacao-issues.md#planejar-e-implementar-manualmente-a-partir-da-priorizacao).

### Retomar em outro chat ou cliente

Pode trocar de chat ou de cliente. O novo helper rele o registro e os documentos
correntes, reconhecendo escolhas e o alcance do GO sem reconstruir todo o
historico da conversa. Informe o projeto e a situacao real:

```text
Quero retomar a migracao do projeto X. Confira o registro, o plano corrente
e as evidencias; identifique a etapa atual e me oriente em uma proxima acao.
```

Se houver mais de um projeto ou escopo, indique qual deseja continuar.
`ContextPath` aponta para o `contexto.json` corrente; o helper deve localiza-lo,
sem exigir que voce invente nomes ou hashes. GO vigente do mesmo escopo e
preservado; mudanca de escopo/solucao exige revisao da autorizacao.

### Referencias que o desenvolvedor pode escrever

Voce pode montar a parte dinamica do pedido com projeto, objetivo, caminhos e
evidencias atuais. Por exemplo:

```text
No projeto X, confira o registro, o plano corrente, o ultimo build e o diagnostico
Sonar atual. Use tambem evidencias/LEIA-ME.md e o guia de configuracao JBoss EAP 7.4.
Indique as fontes consultadas e as lacunas antes de propor o proximo passo.
```

Use os [indices navegaveis](tools/workspace.md#navegar-pelas-evidencias-do-projeto)
para copiar links. O agente confere data, estado e finalidade: log da ultima
tentativa pode corresponder a uma falha, enquanto o relatorio conserva o ultimo
diagnostico utilizavel. Recencia nao escolhe escopo nem concede GO/aceite.

Mantenha instrucoes humanas duraveis no registro, no indice de evidencias ou em
arquivo proprio. O prompt de planejamento gerado pode ser substituido no preparo;
nao use esse arquivo como unico lugar de suas anotacoes. Um pedido manual no chat
nao substitui o contexto tecnico exigido pelas tarefas automaticas.

Os guias e contratos de `doc/` formam a base de conhecimento local: o agente busca
e le os trechos pertinentes e cita seus caminhos, sem carregar toda a documentacao
em cada prompt. Busca semantica/RAG com indexador vetorial nao esta implementada.

### Helpers especializados e delegacao

Uma duvida simples pode ser respondida diretamente pelo guia. O orquestrador
consulta somente o helper pertinente; voce tambem pode pedir apoio especializado.

| Nome do agente | Quando usar |
| --- | --- |
| migracao_helper | Entender a situacao atual e indicar o proximo passo. |
| migracao_preparo_helper | Orientar preparo do ambiente, localizacao/criacao do registro e base MTA ou evidencias. |
| migracao_reconciliacao_helper | Entender divergencias entre registro, decisoes e evidencias; orientar a [adocao explicita de novo MTA por Run Task](tools/planejamento-migracao.md#reconstruir-a-pasta-usando-um-mta-existente) quando solicitada. |
| migracao_planejamento_helper | Comparar candidatas e revisar cobertura, proposta e GO. |
| migracao_impacto_helper | Conferir amostras, codigo, dependencias, configuracoes e testes das issues. |
| migracao_implementacao_helper | Orientar pendencias autorizadas, build, debug, testes e aceite. |

No Copilot, os perfis ficam em `.github/agents`; escolha o helper na lista de
agentes. No Codex, `.codex/agents` fornece perfis para subagentes. No Claude Code,
`.claude/agents` fornece os mesmos seis helpers. Para solicitar
delegacao, diga "Use o subagente migracao_helper para me orientar", quando o perfil
estiver disponivel. `$` seleciona uma skill, nao comprova chamada de subagente.
Mencionar/anexar `.agent.md` ou `.toml` fornece um arquivo, sem selecionar o agente.
O cliente deve mostrar a delegacao real quando ocorrer.

As tres entradas usam a mesma skill e sua referencia de papeis. Formatos:
[agentes VS Code](https://code.visualstudio.com/docs/agent-customization/custom-agents),
[subagentes Codex](https://learn.chatgpt.com/docs/agent-configuration/subagents) e
[subagentes Claude Code](https://code.claude.com/docs/en/sub-agents).
Os perfis Copilot oferecem leitura/busca, com delegacao somente no orquestrador.
Os perfis Codex pedem sandbox read-only e desabilitam subdelegacao dos especialistas;
permissoes efetivas dependem da sessao. Os perfis Claude Code liberam somente
Read, Grep, Glob e as tres consultas MCP; o condutor delega pela ferramenta Agent.
A lista de helpers permitidos e imposta pelo cliente quando iniciado com
`claude --agent migracao_helper`; como subagente, vale pela instrucao do papel.
A skill isolada nao configura sandbox.
Confira as ferramentas/acoes exibidas pelo cliente.

O apoio opcional `devsquad.plan` so e compativel com o helper quando seu perfil
real permite leitura sem terminal, escrita ou subdelegacao. Se oferecer essas
capacidades adicionais, use os helpers locais. Instalar o plugin nao comprova
essa compatibilidade; nao e necessario altera-lo para receber orientacao.

## Pedidos por etapa

Cada guia abaixo tem uma secao **Orientacao com o helper**, com mensagem de exemplo
e resultado esperado. A configuracao, os comandos e as verificacoes ficam no guia
da etapa. Voce pode entrar diretamente onde parou.

| Etapa do processo | Guia com pedido de exemplo |
| --- | --- |
| 1. Preparar o ambiente | [Workspace](tools/workspace.md#orientacao-com-o-helper). |
| Criar ou atualizar o fork do harness na conta da empresa | [GitHub na empresa](tools/github-empresa.md#orientacao-com-o-helper); nao exige projeto/MTA/registro. |
| 2. Escolher projeto e fazer o build | [Maven](tools/maven.md#orientacao-com-o-helper); [Sonar](tools/sonar.md#orientacao-com-o-helper) e [JBoss](tools/jboss.md#orientacao-com-o-helper) para a referencia ANTES. |
| 3. Obter ou reutilizar diagnostico | [MTA](tools/mta.md#orientacao-com-o-helper). |
| 4. Conferir registro e escolher prioridades | [Registro](tools/planejamento-migracao.md#orientar-registro-e-escolha); [priorizacao opcional](tools/priorizacao-issues.md#orientacao-com-o-helper). |
| 5. Planejar e revisar o lote | [Planejamento e GO](tools/planejamento-migracao.md#orientar-planejamento-e-go). |
| 6. Implementar o lote autorizado | [Preparo da implementacao](tools/planejamento-migracao.md#orientar-implementacao). |
| 7. Verificar e aceitar o resultado | [Verificacoes e aceite](tools/planejamento-migracao.md#orientar-verificacoes-e-aceite), com [Maven](tools/maven.md#orientacao-com-o-helper), [Sonar](tools/sonar.md#orientacao-com-o-helper) e [JBoss](tools/jboss.md#orientacao-com-o-helper). |
| 8. Reconciliar e decidir continuidade | [Reconciliacao](tools/planejamento-migracao.md#orientar-reconciliacao-e-continuidade). |
| Compartilhar ou receber analise/plano | [Copia e reconciliacao](tools/compartilhamento-contextos.md#orientacao-com-o-helper). |

## Resultado e proximo passo

A resposta deve identificar a etapa, a fonte consultada, uma acao executavel pelo
desenvolvedor e o resultado a conferir. Se faltar informacao essencial, explicita
a lacuna. Retorne com o resultado real, falha ou decisao para receber a proxima
orientacao. Nao envie credenciais ou logs brutos com segredos ao chat.

**Ensaio nas extensoes:** confira descoberta/delegacao e orientacao em cada cliente,
usando o mesmo projeto e escolha. A resposta deve reconhecer a decisao atual,
oferecer uma acao pronta para aquele cliente e relatar somente o apoio utilizado.
Revisao de arquivos nao comprova obediencia do agente nem validacao nativa.

Para executar a etapa, siga o guia indicado em [pedidos por etapa](#pedidos-por-etapa).
Para acompanhar o ciclo completo, volte ao [guia do desenvolvedor](harness-migracao-desenvolvedor.md).
