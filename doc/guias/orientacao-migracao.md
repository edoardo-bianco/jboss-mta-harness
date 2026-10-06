---
html:
  embed_local_images: true
  embed_svg: true
  offline: true
---

# Orientacao da migracao com Codex ou GitHub Copilot

[Voltar ao fluxo do desenvolvedor](harness-migracao-desenvolvedor.md#roteiro-onde-estou-e-o-que-escolho).

Use este guia para iniciar ou retomar a migracao com apoio do agente, identificar
a etapa atual e receber uma proxima acao. A skill
[orientar-migracao](../../.agents/skills/orientar-migracao/SKILL.md) e o conjunto de
instrucoes compartilhadas pelos clientes. `migracao_helper` e o papel de orientador
que aplica essas instrucoes e consulta os helpers especializados quando pertinente.

O helper le indice, registro, recibos, planos, prompts preparados e evidencias.
Ele responde com **uma proxima acao**, motivo, caminho/mensagem prontos e resultado
a conferir. Voce executa as tarefas, escolhe prioridades, concede GO e aceita o
resultado. Nao precisa conhecer os nomes dos campos internos para pedir ajuda.

Para recuperar uma issue ou conferir a base, configure as
[consultas MCP](tools/consultas-issues.md#configurar-mcp-no-codex-e-no-copilot).
O helper pode chamar as tres ferramentas de leitura diretamente, sem terminal
geral. Sem MCP, continua pela leitura direta dos arquivos e pelo fluxo habitual
de priorizacao/planejamento; a CLI e uma alternativa opcional para consulta pontual.
Os perfis continuam sem executar tarefas/corretivas. Confira origem, paginas e
truncamentos antes de usar a resposta como evidencia.

Para um ZIP recebido, indique **Planejamento: compartilhar contexto** e associe
os projetos locais. Depois informe ao orientador o ContextPath devolvido pela
tarefa. Analise recebida segue para escolha/planejamento; proposta recebida segue
para revisao de escopo/GO e execucao manual ou assistida. Veja o
[roteiro entre colegas](tools/compartilhamento-contextos.md).

Navegacao: [configuracao](#configuracao) · [iniciar](#iniciar-no-codex-ou-no-copilot) ·
[retomar](#retomar-em-outro-chat-ou-cliente) · [pedidos por etapa](#pedidos-por-etapa) ·
[resultado e proximo passo](#resultado-e-proximo-passo).

## Configuracao

Abra o workspace que inclui a pasta do harness e os projetos desejados. A
[configuracao da maquina e do workspace](tools/workspace.md#configuracao) fica no
guia proprio. No Codex, inicie a conversa com a raiz do harness como pasta de
trabalho: uma aplicacao em repositorio irmao nao herda automaticamente suas skills.

As instrucoes ficam em `.agents/skills` no repositorio, local reconhecido por
[Codex](https://learn.chatgpt.com/docs/build-skills) e
[Copilot no VS Code](https://code.visualstudio.com/docs/agent-customization/agent-skills).
A descoberta depende do cliente e da pasta aberta. Nao e necessario regenerar
o workspace para acrescentar a skill.

### Se a skill ou o agente nao aparecer

Confira os arquivos no clone e se as customizacoes estao habilitadas no cliente.
No Copilot, consulte **/skills** e a lista de agentes; no Codex, reinicie o cliente
se a descoberta nao refletir os novos arquivos. Sem descoberta automatica, pode
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

### Iniciar no Codex ou no Copilot

| Cliente | Como entrar na orientacao |
| --- | --- |
| Codex | Selecione **$orientar-migracao** no chat. Ela assume o papel de orquestrador helper. |
| GitHub Copilot | Abra a lista de agentes do Chat e selecione **migracao_helper**. A skill tambem pode ser usada por **/orientar-migracao**. |

Depois envie o objetivo. Os exemplos dos guias usam `projeto X`: substitua pelo
seu projeto. A mesma mensagem serve nos dois clientes, apos selecionar a entrada
acima; ela e um pedido no chat, nao um comando de terminal.

```text
Quero iniciar a migracao do projeto X, que ja esta no workspace.
Confira o contexto existente e me oriente no proximo passo.
```

O helper localiza indice/registro e a solicitacao vinculada. Pede caminho, projeto
ou ID somente quando os arquivos nao resolvem a ambiguidade. Se faltar registro,
orienta **Workspace: atualizar indice dos projetos**. Nao escolhe rodada ou
solicitacao apenas por ser a mais recente.

Execute a acao indicada e retorne com o resultado. O helper confere a saida e
orienta a seguinte. Para comparar candidatas antes de escolher, use o exemplo
de [pre-planejamento](tools/priorizacao-issues.md#orientacao-com-o-helper).

### Passar da orientacao para a execucao

O helper entrega a mensagem pronta para o cliente atual, com os caminhos reais.
Quando a tarefa preparar um prompt:

- **Codex:** envie `Execute o prompt deste arquivo:` seguido do caminho fornecido.
- **Copilot:** abra o prompt preparado e use **Executar Prompt**, com o agente
  indicado e DevSquad nas fases pertinentes, em conversa Local.

A execucao desse prompt e uma etapa distinta da orientacao; helpers continuam
leitores. Preparar o contexto nao executa o agente. Para o agente salvar o ranking
ou plano, execute o prompt correspondente; aplicar corretivas exige GO para o escopo.
Verificacoes tecnicas e aceite do resultado continuam separados.
Veja o [procedimento de planejamento e execucao](tools/planejamento-migracao.md#preparar-e-executar-o-prompt).

### Continuar manualmente a partir de uma ficha

Pode ser outro colega quem implementa. O orientador recupera a ficha e os anexos
do projeto/issue, confere se existe plano/to-do e indica a etapa que falta.
Os documentos seguem [estrutura padronizada e dossie por issue](tools/planejamento-migracao.md#dossie-por-issue-e-passagem-entre-colegas).
Com somente analise, orienta elaborar o plano; com proposta, revisar GO; com GO,
seguir execucao manual ou por agente de codificacao conforme a escolha humana.
O orientador continua leitor. Contexto consolidado dispensa MTA original para
implementar, mas exige conferir o codigo local. Para tornar o contexto operacional
em outra raiz, use a [importacao com associacao aos projetos locais](tools/compartilhamento-contextos.md).

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

Pode trocar de chat ou de cliente. O novo helper rele os mesmos registros e a
solicitacao vinculada, reconhecendo escolhas e GO vigentes sem reconstruir todo
o historico da conversa. Informe o projeto e a situacao real:

```text
Quero retomar a migracao do projeto X. Confira o registro, a solicitacao vinculada
e as evidencias; identifique a etapa atual e me oriente em uma proxima acao.
```

Se houver mais de uma frente, indique a que deseja continuar quando solicitado.
`ContextPath` e o caminho do recibo (`contexto-<projeto>-<issue>.json` nos novos
planos ou `context.json` na priorizacao e em layouts legados); o helper deve localiza-lo e
apresenta-lo, nao exigir que voce invente o caminho. GO vigente do mesmo escopo
e preservado; mudanca de escopo exige revisao da autorizacao.

### Helpers especializados e delegacao

Uma duvida simples pode ser respondida diretamente pelo guia. O orquestrador
consulta somente o helper pertinente; voce tambem pode pedir apoio especializado.

| Nome do agente | Quando usar |
| --- | --- |
| migracao_helper | Entender a situacao atual e indicar o proximo passo. |
| migracao_preparo_helper | Orientar preparo do ambiente, localizacao/criacao do registro e base MTA ou evidencias. |
| migracao_reconciliacao_helper | Entender divergencias entre registro, decisoes e evidencias. |
| migracao_planejamento_helper | Comparar candidatas e revisar cobertura, proposta e GO. |
| migracao_impacto_helper | Conferir amostras, codigo, dependencias, configuracoes e testes das issues. |
| migracao_implementacao_helper | Orientar pendencias autorizadas, build, debug, testes e aceite. |

No Copilot, os perfis ficam em `.github/agents`; escolha o helper na lista de
agentes. No Codex, `.codex/agents` fornece perfis para subagentes. Para solicitar
delegacao, diga "Use o subagente migracao_helper para me orientar", quando o perfil
estiver disponivel. `$` seleciona uma skill, nao comprova chamada de subagente.
Mencionar/anexar `.agent.md` ou `.toml` fornece um arquivo, sem selecionar o agente.
O cliente deve mostrar a delegacao real quando ocorrer.

As duas entradas usam a mesma skill e sua referencia de papeis. Formatos:
[agentes VS Code](https://code.visualstudio.com/docs/agent-customization/custom-agents)
e [subagentes Codex](https://learn.chatgpt.com/docs/agent-configuration/subagents).
Os perfis Copilot oferecem leitura/busca, com delegacao somente no orquestrador.
Os perfis Codex pedem sandbox read-only e desabilitam subdelegacao dos especialistas;
permissoes efetivas dependem da sessao. A skill isolada nao configura sandbox.
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
| 2. Escolher projeto e fazer o build | [Maven](tools/maven.md#orientacao-com-o-helper); [Sonar](tools/sonar.md#orientacao-com-o-helper) e [JBoss](tools/jboss.md#orientacao-com-o-helper) para a referencia ANTES. |
| 3. Obter ou reutilizar diagnostico | [MTA](tools/mta.md#orientacao-com-o-helper). |
| 4. Conferir registro e escolher prioridades | [Registro](tools/planejamento-migracao.md#orientar-registro-e-escolha); [priorizacao opcional](tools/priorizacao-issues.md#orientacao-com-o-helper). |
| 5. Planejar e revisar o lote | [Planejamento e GO](tools/planejamento-migracao.md#orientar-planejamento-e-go). |
| 6. Implementar o lote autorizado | [Preparo da implementacao](tools/planejamento-migracao.md#orientar-implementacao). |
| 7. Verificar e aceitar o resultado | [Verificacoes e aceite](tools/planejamento-migracao.md#orientar-verificacoes-e-aceite), com [Maven](tools/maven.md#orientacao-com-o-helper), [Sonar](tools/sonar.md#orientacao-com-o-helper) e [JBoss](tools/jboss.md#orientacao-com-o-helper). |
| 8. Reconciliar e decidir continuidade | [Reconciliacao](tools/planejamento-migracao.md#orientar-reconciliacao-e-continuidade). |
| Compartilhar ou receber analise/plano | [Exportacao/importacao](tools/compartilhamento-contextos.md#orientacao-com-o-helper). |

## Resultado e proximo passo

A resposta deve identificar a etapa, a fonte consultada, uma acao executavel pelo
desenvolvedor e o resultado a conferir. Se faltar informacao essencial, explicita
a lacuna. Retorne com o resultado real, falha ou decisao para receber a proxima
orientacao. Nao envie credenciais ou logs brutos com segredos ao chat.

**Ensaio nas extensoes:** confira descoberta/delegacao e orientacao em cada cliente,
usando a mesma escolha/solicitacao. A resposta deve reconhecer a decisao atual,
oferecer uma acao pronta para aquele cliente e relatar somente o apoio utilizado.
Revisao de arquivos nao comprova obediencia do agente nem validacao nativa.

Para executar a etapa, siga o guia indicado em [pedidos por etapa](#pedidos-por-etapa).
Para acompanhar o ciclo completo, volte ao [guia do desenvolvedor](harness-migracao-desenvolvedor.md).
