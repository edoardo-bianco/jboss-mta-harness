# Criar ou revisar issues com evidencias

Use uma unica entrada para investigar um problema novo ou revisar uma issue
MTA/manual. A issue MTA conserva ID e categoria; um achado novo de deploy,
execucao, teste ou analise fora do catalogo entra como manual. Ambas tem ficha,
evidencias e continuidade para planejamento. O registro evita duplicatas.

## 1. Abrir a tarefa e executar o prompt

1. Execute **Tasks: Run Task -> Planejamento: criar ou revisar issue**.
2. Informe o workspace se solicitado e selecione o projeto no menu.
3. A tarefa abre **atual/planejamento/criar-revisar-issue.prompt.md** daquele
   projeto. Ela prepara o pedido; ainda nao investiga nem cadastra uma issue.
4. No Copilot, use **Executar Prompt** em uma sessao **Local**. Para aproveitar
   o diagnostico que ja esta no chat, escolha a conversa atual, nao um chat novo.
   O cabecalho seleciona **devsquad** quando instalado. Sem esse perfil, selecione
   **Agent** e envie: "Execute o prompt deste arquivo usando as evidencias desta
   conversa: [caminho do arquivo aberto]".
5. Informe o problema ou ID somente se ainda nao estiver claro. O agente recupera
   o contexto atual e pergunta apenas o essencial ausente. Evidencias podem ser
   trechos da conversa, saidas de ferramentas, arquivo/log ou relato humano.

A tarefa nao le o historico do Copilot nem transfere conversas para outro chat.
O executor aproveita o que esta acessivel na sessao em que voce roda o prompt.
Se a evidencia estiver em outra sessao, forneca trecho ou arquivo acessivel.
Notas escritas no prompt preparado sao preservadas ao preparar novamente;
conclusoes duraveis devem ficar na ficha/evidencias.

Tambem pode usar diretamente
[/criar-revisar-issue](../../../.github/prompts/criar-revisar-issue.prompt.md)
no Copilot Local, indicando o projeto se nao estiver definido.
Se o comando nao aparecer, abra o arquivo do prompt no harness e use Executar Prompt.
O helper migracao_helper orienta a passagem; a execucao pertence a devsquad/Agent.

Exemplo para aproveitar o que o Copilot acabou de encontrar:

~~~text
/criar-revisar-issue
Use o projeto e o problema que acabamos de analisar nesta conversa.
Aproveite os trechos de codigo, saidas de comandos e evidencias ja disponiveis.
Confira o registro e a documentacao oficial aplicavel; crie a issue se for nova
ou revise a existente. Preserve a evidencia necessaria para retomar a analise,
separando fato, hipotese e pesquisa pendente. A corretiva sera planejada depois.
~~~

Exemplo para um log de servidor:

~~~text
/criar-revisar-issue
Projeto: artifactId do projeto adicionado ao harness.
O deploy falhou. Use o server.log em [caminho local] ou o trecho anexado ao chat.
Servidor/ambiente: [se conhecido]. Tentativa/horario: [se conhecido].
Investigue o erro e as causas encadeadas, o Source e a documentacao oficial.
Crie ou revise a issue correspondente e preserve o recorte relevante na evidencia.
Nao repita o deploy para cadastrar o problema.
~~~

Nao e necessario preencher todos os campos quando ja estao na sessao. Sem anexo,
o relato pode sustentar cadastro, identificado como relato e sem afirmar
reproducao. Sem internet, pesquisa oficial fica pendente explicita; isso nao
autoriza inventar causa ou citar uma pagina como lida.

### Usar no Copilot, Codex ou Claude Code

O contrato e o mesmo nos tres clientes. A tarefa Run Task prepara/abre um arquivo
no VS Code; depois, execute esse arquivo na conversa do cliente escolhido.

| Cliente | Para pedir orientacao | Para executar o prompt preparado |
| --- | --- | --- |
| GitHub Copilot | Selecione migracao_helper no Chat e envie um dos exemplos abaixo. | Executar Prompt no chat Local; devsquad quando instalado, ou Agent conforme acima. |
| Codex | Use $orientar-migracao e envie um dos exemplos abaixo. | Na conversa principal com acesso ao workspace, envie o pedido de execucao abaixo com o caminho do arquivo. |
| Claude Code | Use /orientar-migracao, peca o subagente migracao_helper ou inicie claude --agent migracao_helper para orientacao. | Na conversa principal, sem --agent migracao_helper, envie o mesmo pedido de execucao com o caminho do arquivo. |

~~~text
Execute o prompt do arquivo [caminho do criar-revisar-issue.prompt.md preparado].
Use o projeto selecionado e aproveite as evidencias acessiveis nesta conversa.
Siga o contrato referenciado, investigue e publique a ficha; pergunte so o que faltar.
~~~

O cabecalho agent/tools configura a execucao nativa no Copilot Local. Ele nao
configura Codex/Claude Code, onde o agente principal usa suas ferramentas e
permissoes reais; using-agent-skills e usada quando disponivel. Nao e necessario
instalar devsquad nesses clientes. O corpo do prompt e suas referencias continuam
sendo o procedimento comum. Helpers explicitamente ativos seguem orientadores.

Sem Run Task, prepare pelo terminal Windows do harness (nao inicia o agente):

```powershell
powershell.exe -NoProfile -File .\scripts\preparar-issue.ps1 -WorkspacePath 'C:\caminho\projetos.code-workspace' -SelectTarget -NoOpen
```

Use o caminho mostrado no pedido ao agente. Tambem e possivel executar o contrato
original .github/prompts/criar-revisar-issue.prompt.md diretamente, informando
projeto/POM se ainda nao conhecidos. Nao presuma que o slash command do Copilot
foi instalado nos demais clientes. Se mudar de cliente ou sessao, forneca as
evidencias persistidas ou os trechos necessarios; o historico nao e transferido
pela tarefa. Rede e acesso a arquivos continuam sujeitos as permissoes do cliente.

### Pedir ajuda ao orientador: exemplos por situacao

Os pedidos abaixo servem nos tres clientes, depois de entrar na orientacao pela
tabela acima. Substitua os campos entre colchetes somente quando ainda nao forem
conhecidos na conversa. Indique o projeto se houver ambiguidade. Os exemplos sao
mensagens no chat; o helper orienta e encaminha a execucao, sem gravar a ficha.

**Problema novo no deploy ou na execucao, com log do servidor:**

~~~text
Encontrei um problema no deploy do projeto [artifactId].
Oriente-me a criar ou revisar a issue, aproveitando o diagnostico desta conversa
e o log do servidor em [caminho local ou trecho anexado].
A tentativa ocorreu em [horario/ambiente, se conhecidos].
Confira se ja existe uma issue relacionada e indique a tarefa e a mensagem
para executar a investigacao no cliente que estou usando.
~~~

**Problema que o agente acabou de encontrar na conversa:**

~~~text
Quero registrar o problema que acabamos de identificar neste projeto.
Use o relato, os trechos de codigo e as saidas de comandos disponiveis nesta
conversa, sem me pedir novamente essas informacoes.
Oriente o cadastro ou a revisao da issue existente e a preservacao das evidencias.
Se algo citado no diagnostico nao estiver acessivel, indique exatamente o que falta.
~~~

**Revisao de uma issue manual com nova evidencia:**

~~~text
A issue manual [ID DEV-... completo] do projeto [artifactId] recebeu uma nova evidencia:
[caminho do arquivo ou trecho desta conversa].
Oriente-me a revisar a mesma ficha, preservando ID, notas, decisoes e evidencia
anterior. Indique como encaminhar ao executor a conferencia do Source e da
documentacao oficial e o registro das conclusoes que mudaram.
~~~

**Revisao de uma issue MTA com erro observado na aplicacao:**

~~~text
Quero revisar a issue MTA [ID completo] do projeto [artifactId].
O erro observado na execucao esta em [log/arquivo ou trecho desta conversa].
Confira a ficha e o registro e oriente como investigar a relacao com esse erro,
preservando o ID e a categoria MTA e evitando uma manual duplicada.
Entregue a tarefa e a mensagem para executar a revisao no meu cliente.
~~~

Se nao houver arquivo/log, diga: "Tenho apenas este relato: [o que ocorreu]".
Se a pesquisa web estiver bloqueada, informe o bloqueio: o executor registra
pesquisa oficial pendente e limita as conclusoes ao material realmente lido.

**Confira a resposta do orientador:** ela deve recuperar projeto/issue ja
conhecidos, apontar **Planejamento: criar ou revisar issue** (ou o prompt ja
preparado), entregar a mensagem para o executor do cliente atual e indicar o que
conferir na ficha/evidencias. Ambiguidade deve virar uma pergunta especifica.
O helper tambem explica a confirmacao de possiveis correspondencias e a escolha
sobre auditoria independente; nao a aciona como efeito de uma duvida.
A orientacao nao comprova cadastro, revisao tecnica, GO ou aceite.

### Levar a orientacao e as evidencias para o executor

Execute a tarefa indicada e use o caminho do prompt aberto na mensagem de
execucao da tabela. Se ja estiver no agente principal com as evidencias acessiveis,
execute nessa conversa. Se estiver num perfil helper dedicado, siga a
[passagem da orientacao para a execucao](../orientacao-migracao.md#passar-da-orientacao-para-a-execucao):
no Copilot, Executar Prompt solicita devsquad; no Codex, abra conversa principal;
no Claude Code iniciado com --agent migracao_helper, abra conversa normal.
O helper consultado como subagente devolve a orientacao ao agente principal.

Quando mudar de conversa/cliente, acrescente ao pedido de execucao:

~~~text
Projeto: [artifactId ja escolhido]. Issue: [ID, se existir].
Execute o prompt deste arquivo: [caminho real fornecido pela tarefa].
O diagnostico foi discutido em outra conversa. Aqui estao os trechos relevantes:
[colar relato/saida de comando/erro, sem segredos], ou leia [arquivo acessivel].
Use esse material como ponto de partida, confira o Source e as fontes oficiais
e crie ou revise a ficha, preservando origem e limites das evidencias.
~~~

O caminho do prompt recupera o projeto e o contrato; ele nao transfere o historico
do chat. O executor deve conferir o diagnostico anterior e preservar o recorte
necessario na ficha/evidencias. Depois, volte ao orientador com o ID, caminhos
publicados e lacunas, para decidir se quer priorizar ou planejar a corretiva.

## 2. Revisar uma issue e conferir as evidencias

~~~text
/criar-revisar-issue
Revise a issue [ID MTA ou DEV-...] do projeto ja escolhido.
Use o erro e a saida de execucao desta conversa, mais [arquivo opcional].
Releia a ficha e o Source, confira as fontes oficiais e explique o que mudou.
Preserve identidade, decisoes, notas humanas e evidencias anteriores.
~~~

A mesma ficha e reaproveitada. Se a issue MTA ainda nao tem ficha, o executor
usa seu ID/categoria do registro e o modelo existente, ligando registro -> ficha.
Nao se cria uma manual duplicada nem se transforma a origem de uma issue MTA.
Se o relato for outro problema, a identidade precisa ser distinguida por evidencia.

Para chat/saida de ferramenta, registre a fonte e o trecho ou resumo fiel usado,
sem inventar comando, horario ou linhas. Uma conclusao anterior do Copilot e uma
hipotese a conferir; a saida observada tem os limites do trecho disponivel.
Para server.log, confira instancia, aplicacao/deployment e intervalo conhecido;
log compartilhado pode conter erros de outras aplicacoes. Caminho igual nao
comprova que o conteudo lido anteriormente ainda existe.

O executor guarda o recorte relevante em **evidencias/** com nome ligado ao ID,
origem, intervalo e limites, sem sobrescrever o ANTES. Se o arquivo ja e uma
evidencia estavel, reutiliza-o. Para log mutavel/rotacionado, preserva o recorte
lido e a data da coleta; nao copia o log inteiro por padrao. Segredos/dados
sensiveis sao omitidos nos recortes, com a omissao indicada. A ficha e
**evidencias/LEIA-ME.md** apontam para o material preservado. Sem acesso a um
trecho, o agente informa a lacuna e nao inventa anexo.

**Confira:** projeto/ID/origem; fato e hipotese separados; evidencia realmente
lida, preservada e com link; Source aplicavel; documento oficial da versao certa;
conclusoes alteradas justificadas; notas e decisoes mantidas; verificacoes pendentes.
Cadastro inicial manual usa A DEFINIR / NAO ANALISADA. Revisar ficha nao muda
escolhas/andamento, nao reabre automaticamente issue aceita nem altera lote aprovado.
Se a nova evidencia muda a solucao ou contradiz uma decisao, revise planejamento
ou reconcilie o registro pela etapa correspondente.

Para cadastro/reparo manual, veja a
[API existente](planejamento-migracao.md#registrar-uma-issue-manual).
Register-HarnessManualIssue cadastra somente manuais; quem executa o prompt
investiga e publica a revisao da ficha/anexos com protecao contra edicao concorrente.

### Antes de criar: conferir correspondencias e confirmar

O executor SEMPRE busca issues iguais ou parecidas antes de criar ficha/linha
no registro. Confere migracao.md, fichas/evidencias e MTA disponivel do projeto,
inclusive categorias/estados fora da fatia atual. Compara erro, codigo, componente,
condicao e alcance; titulo parecido nao basta para decidir. Fonte ilegivel ou
busca incompleta fica como lacuna, nunca como prova de que a issue nao existe.

Havendo candidata, deve apresentar ID/link, semelhancas, diferencas e duvidas,
e perguntar, por exemplo:

~~~text
Encontrei estas issues possivelmente relacionadas: [IDs e links reais].
Coincidem em [fatos sustentados]; diferem em [diferencas ou lacunas].
Recomendo [revisar ID / esclarecer a diferenca], por [evidencia].
Confirma revisar uma dessas issues ou criar uma nova distinta? Qual delas?
~~~

Enquanto essa escolha estiver pendente, nao cria nem revisa a candidata. Se voce
confirmar nova, registra a distincao informada. Se o pedido ja era revisar um ID
inequivoco, reutiliza a ficha sem repetir a escolha. Sem candidata apos a busca,
segue o cadastro solicitado, declarando escopo/limites da conferencia. Uma issue
relacionada em outro projeto pode ser referenciada, sem misturar Project/Id.

### Modelos, fatos e pesquisa oficial

A proposta segue os modelos existentes de
[ficha](../../modelos/ficha-issue.template.md) e
[indice de evidencias](../../modelos/evidencias.template.md), com suas secoes,
identidade, blocos gerenciados e colunas. Revisar preserva o documento existente
e suas notas. Nomes/pastas e vinculos seguem as APIs do harness. O cadastro nao
inventa outro formato nem reescreve o registro inteiro.

Cada afirmacao relevante deve ter suporte: ocorrido/versao/impacto em evidencia
local ou relato identificado; regra tecnica em documentacao oficial da versao
aplicavel; causa apenas quando sustentada. Relato nao comprova reproducao, e
documentacao nao prova o que ocorreu na maquina. Resposta de IA ou fonte secundaria
e pista, nao fonte primaria. Contradicao ou fato essencial ausente gera pergunta;
sem resposta suficiente, a conclusao permanece hipotese/lacuna, nunca fato.

Sem internet, o agente confere copias oficiais locais quando disponiveis. Se nao
conseguir consultar, entrega um roteiro como este, preenchido para o problema:

~~~text
Pesquisa oficial pendente: [pergunta tecnica que precisamos responder].
Produto e versao: [confirmados no projeto; indicar o que ainda falta].
Fonte oficial: [portal/documento conhecido; nao inventar URL].
Termos publicos para buscar: [tecnologia, versao, erro tecnico sem dados internos].
Traga: URL e trecho/secao relevante, ou copia oficial local acessivel.
A conclusao que depende dessa consulta e: [hipotese ainda nao confirmada].
~~~

O fato sustentado pode ser cadastrado com essa pendencia, conforme o fluxo abaixo.
A resposta do desenvolvedor com uma fonte deve ser conferida e citada; URL nao
lida nao vira prova. A pesquisa nao exige enviar codigo ou logs internos a sites.

### Perguntar antes da auditoria independente

Depois de preparar a proposta, o executor pergunta:

~~~text
Deseja executar uma auditoria independente desta proposta antes de publica-la?
1. Sim: outro agente/revisor confere modelos, fatos/fontes e correspondencias.
2. Nao: seguir sem auditoria independente, registrando que ela nao foi realizada.
3. Adiar a publicacao.
~~~

A auditoria so comeca apos Sim. Sem resposta, aguarda. Uma escolha ja explicita
para essa proposta nao e perguntada novamente. Optar por nao auditar nao dispensa
a checagem previa de
correspondencias nem sua confirmacao humana quando pertinente.

O auditor deve ser outro agente em contexto separado, sem participacao na autoria
ou investigacao inicial; a revisao do proprio autor nao conta como independente.
No Copilot, devsquad/Agent delega se houver capacidade; Codex e Claude Code usam
suas ferramentas reais. O cabecalho do Copilot nao instala agentes nos demais.
O auditor le proposta/diff, modelos, registro/fichas candidatas, evidencias e
fontes oficiais pertinentes, sem escrever, cadastrar ou implementar corretivas.

Se o cliente nao permitir outro agente, o executor informa o limite e oferece
este pedido para outra sessao/revisor, com o material acessivel. Aguarda a escolha
de aguardar o parecer ou seguir sem auditoria; nao simula a segunda revisao.

~~~text
Audite de forma independente esta proposta de criacao/revisao de issue.
Voce nao participou da autoria. Atue somente como leitor; nao publique alteracoes.
Projeto/ID e proposta ou diff: [identidade e texto/caminhos acessiveis].
Registro e candidatas comparadas: [caminhos/IDs e escolha humana registrada].
Evidencias/fontes: [arquivos, trechos e URLs realmente consultados].
Leia os modelos de ficha/evidencias do harness e confira diretamente as fontes.
Aponte duplicidade possivel, afirmacoes sem suporte, versao incorreta, contradicoes,
desvios dos modelos e problemas de identidade/links. Nao atribua existencia a
arquivos apenas propostos nem acesso a outra conversa. Devolva escopo/fontes lidas,
achados com fundamento, ajustes necessarios e lacunas. Nao conceda GO ou aceite.
~~~

O autor trata os achados e submete mudancas materiais de identidade/fatos/conclusao
a nova conferencia independente dos pontos alterados. Duvida de identidade volta
a voce. A secao **4. Referencias e lacunas** da ficha registra a escolha sobre
auditoria e, quando feita, a origem real do parecer, resultado e limites.
Sem auditoria, registra que nao foi realizada por sua escolha. So entao publica
a ficha/registro/evidencias; cadastro e auditoria nao aprovam a corretiva.

## 3. Atualizar e navegar pelos indices

Execute **Workspace: atualizar indice dos projetos** no workspace habitual.
O indice geral .harness/indices/projetos.md mostra:

| Local | Leitura |
| --- | --- |
| Issues / ocorrencias | MTA: X / Y e Manuais: N / -, na mesma celula. |
| Categorias | Categorias MTA e manual: N / -. |
| Totais conhecidos | Totais MTA preservados; manual separado, com ocorrencias -. |
| Projeto sem MTA | MTA indisponivel e contagem manual obtida do registro. |
| Registro ilegivel | Contagem manual indisponivel e total parcial com cobertura de leitura. |

A contagem manual vem das linhas com presenca MANUAL em migracao.md.
Nao e calculada pelo numero de pastas/fichas: uma ficha orfa precisa ser conferida
e cadastrada/reparada, nao contada silenciosamente.
Zero exige registro legivel; ocorrencias "-" de uma manual significa que nao se
aplicam. Quantidade de cadastro nao significa quantidade pendente ou resolvida.

Abra **Projeto -> Decisoes de migracao -> Ficha**. O indice geral tambem oferece
**Registro -> Ficha**. Na ficha, confira codigo, evidencias e referencias oficiais.
O indice do projeto conserva o total de manuais e distingue MTA presentes e
nao reencontradas. Editar projetos.md a mao nao corrige o gerador: ele e refeito.

## 4. Priorizar ou escolher diretamente

| Situacao | Comportamento |
| --- | --- |
| Manual cadastrada antes de iniciar a base | Entra na categoria manual se estiver elegivel no registro. |
| Ficha existente selecionada na fatia | O executor rele ficha, codigo e evidencias; atualiza a mesma ficha e preserva notas humanas. |
| Apenas preparar/atualizar o indice | Regenera contexto/links; nao realiza exame tecnico nem comprova priorizacao. |
| Manual adicionada depois de iniciar a base | Fica fora da base fixa; Recriar inclui as novas elegiveis, por escolha explicita. |
| Progredir | Mantem InitialTotal e exclui todas as examinadas acumuladas, com ou sem posicao. |
| Nova evidencia para issue ja examinada | Revise a ficha pelo mesmo prompt; isso nao atualiza automaticamente ranking/cobertura. |
| Issue ja escolhida pelo desenvolvedor | Pode ir diretamente ao planejamento; ranking e opcional. |

Recriar preserva fichas/anotacoes, mas redefine base e cobertura do ranking.
Nao use essa opcao automaticamente para toda revisao de ficha. Se quiser
reavaliar o ranking com a base atual, escolha-a explicitamente.
Uma ficha existente nao prova exame na nova fatia: o executor precisa reler
as fontes e registrar o exame efetivamente realizado.

A elegibilidade usa Decisao A DEFINIR/ANALISAR AGORA e Andamento NAO ANALISADA/ANALISADA.
ADIAR, FORA DO ESCOPO e corretiva ja em andamento nao sao reabertos pelo cadastro.
Veja [priorizacao por fatias](priorizacao-issues.md).

## 5. Planejar, implementar e verificar

Escolha a issue no migracao.md, marque **ANALISAR AGORA** e descreva o recorte
na Observacao/referencia, preservando o andamento real. Use
**Planejamento: planejar**, com base EVIDENCIAS quando o recorte se apoia em
evidencias humanas. A tarefa recupera a ficha e suas referencias; o executor
confere novamente o Source para propor a corretiva.

Revise a proposta e conceda GO para o escopo definido. Depois, implemente,
execute as verificacoes pertinentes ao problema e registre evidencias do DEPOIS.
Compare com o ANTES preservado e faca a revisao/aceite. Cadastro, documentacao,
ranking e sucesso de um comando isolado nao concedem aceite.

Consulte [planejamento e continuidade](planejamento-migracao.md).
Este roteiro nao implementa automaticamente a corretiva ao registrar a issue.

## 6. Consultar a internet no Copilot da maquina de trabalho

A capacidade depende da versao do VS Code, do tipo de sessao, das ferramentas
habilitadas e da politica corporativa. O prompt nao concede acesso de rede.

1. Abra uma sessao Local com o executor devsquad ou Agent para executar o prompt nativo.
2. Em sessao Local, abra **Configure Tools**. Em sessao Copilot que ofereca o
   editor de customizacoes, use **Chat: Open Customizations -> Tools**.
3. Procure e habilite a ferramenta de leitura web disponivel, normalmente
   fetch/web/fetch. Digitar # no Chat mostra os nomes reconhecidos pela sessao.
4. Teste com uma pagina oficial publica e confira a chamada e seu resultado:

~~~text
Leia com a ferramenta web disponivel:
https://docs.redhat.com/en/documentation/red_hat_jboss_enterprise_application_platform/7.4/html-single/migration_guide/index
Informe o titulo e uma secao efetivamente lida. Se nao conseguir acessar,
informe o erro e nao substitua a leitura por conhecimento de memoria.
~~~

5. Autorize a URL quando o cliente solicitar e a politica da empresa permitir.
   Se houver bloqueio, registre o erro e solicite a liberacao pelos canais
   corporativos. Nao desabilite controles para fazer o prompt funcionar.

fetch le uma URL; pesquisar por assunto depende de ferramenta de busca habilitada
ou de navegar pelos indices da documentacao oficial. O novo prompt declara
web/fetch e vscode/askQuestions para a execucao Local. A lista do prompt tem
precedencia sobre a lista do agente, selecionando as ferramentas disponiveis.
Uma ferramenta declarada mas indisponivel nao
e instalada nem ganha permissao automaticamente. Outros tipos de sessao/clientes
podem usar nomes diferentes. MCP/extensao de busca e opcional e depende da
aprovacao/disponibilidade da empresa; nao e requisito para registrar a issue.

Os helpers migracao_* permanecem leitores/orientadores. Execute a investigacao
na conversa principal; a lista restrita de ferramentas do helper nao libera web.

As configuracoes chat.agent.networkFilter, chat.agent.allowedNetworkDomains e
chat.agent.deniedNetworkDomains podem controlar destinos quando presentes na
versao instalada. Politica da organizacao pode prevalecer. Nao e necessario
alterar settings do harness para documentar uma issue.

Fontes oficiais consultadas em 24/10/2026:
[prompts, agente e precedencia de ferramentas](https://code.visualstudio.com/docs/agent-customization/prompt-files),
[uso e selecao de ferramentas](https://code.visualstudio.com/docs/agents/run/tools),
[nomes e disponibilidade](https://code.visualstudio.com/docs/agents/reference/tools-reference)
e [configuracoes de IA/rede](https://code.visualstudio.com/docs/agents/reference/ai-settings).
Use termos tecnicos publicos nas buscas, sem enviar codigo, logs integrais,
segredos ou identificadores internos para servicos externos.
