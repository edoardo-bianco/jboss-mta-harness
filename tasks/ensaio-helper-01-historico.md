# Historico do ensaio 01: helpers de migracao

Rodada de 2026-10-04 encerrada pelo desenvolvedor. Este arquivo conserva a coleta
e as discussoes daquela rodada; instrucoes de proximo trabalho no relato sao
historicas, nao pendencias atuais. Base ensaiada: e328df2.

Os 17 achados motivaram a simplificacao implementada em 2c6b6e6 e as corretivas
da auditoria em 4ff6c68. O encerramento da coleta nao equivale a aprovar todos os
cenarios de validacao nativa ou a aceitar uma corretiva da aplicacao.
Estado atual e novo ensaio: [to-do](todo.md). Direcao de trabalho: [plano](plan.md).

Em 2026-10-05, o desenvolvedor autorizou reiniciar o playground do zero e descartar
suas analises locais, inclusive o arquivo em .harness/ensaios/ensaio-01-2026-10-04.
Os caminhos/recibos mencionados neste relato sao referencias historicas, sem garantia
de disponibilidade atual. Este texto documenta achados da evolucao do harness.

### Ensaio acompanhado do helper no Codex - 2026-10-04

Orientacao inicial do desenvolvedor: acumular observacoes durante o ensaio e
consolidar ajustes ao final. Coleta desta rodada encerrada por pedido posterior de
interromper o ensaio e simplificar antes de prosseguir; achados incorporados em
SIM-01 a SIM-14 acima. Nenhuma corretiva funcional foi aplicada nesta coleta.
Base testada: e328df2, workspace jboss-mta-harness.local.code-workspace.
Entradas: respostas do outro chat coladas pelo desenvolvedor; nao sao logs de
ferramentas nem comprovacao de execucao das tarefas indicadas.

Resposta 1 (pedido curto: priorizar mandatory, por onde comecar): identificou
corretamente o indice existente, duas issues mandatory A DEFINIR/NAO ANALISADA
no antes, reconciliacao PENDENTE e depois AGUARDANDO MTA. Fontes foram conferidas
na avaliacao. Preservou escolha humana, distinguiu preparo de ranking e nao
interpretou ausencia de MTA como zero. Declarou uso direto dos guias, sem delegar.

| ID de observacao | Evidencia / ponto a avaliar ao final |
| --- | --- |
| ENS-01 | Conducao gradual: abertura indicou priorizar, mas primeiro item mandou reconciliar; entregou o percurso inteiro. Orientacao inicial deve tornar inequivoca a proxima acao, seu motivo, resultado esperado e retorno humano. |
| ENS-02 | Recomendacao versus impedimento: PENDENTE comprova reconciliacao nao concluida, sem demonstrar por si so conflito que bloqueie priorizacao. Explicar a consequencia concreta no recorte e evitar transformar sugestoes em pre-requisitos genericos. |
| ENS-03 | Adequacao ao cliente/experiencia: "execute o prompt" e alternativa Copilot/Codex deixaram passos implicitos para iniciante. Orientar no cliente informado, com arquivo real, forma de uso, escopo da escrita e evidencia a trazer quando pertinente. |
| ENS-04 | Completude proporcional: indices de evidencias complementares existem, mas estao vazios; esse limite nao foi citado. Avaliar como comunicar lacunas relevantes sem impor anexos desnecessarios ou bloqueios. |
| ENS-05 | Passagem da orientacao para execucao: apos preparar, desenvolvedor ficou em duvida sobre novo chat, janela do helper, colar prompt completo e preencher preferencias. Explicitar onde entregar o artefato, diferenca entre pedir orientacao e autorizar sua execucao, mensagem pronta com caminho real, campos opcionais e retorno do resultado ao helper. Avaliar essa comunicacao no helper, guia e saida da tarefa em conjunto. |
| ENS-06 | Clareza dos avisos: terminal identifica projeto pelo ID tecnico e agrupa "origem ausente ou ambigua" na mesma mensagem. Neste caso, o contexto atribui a ausencia ao depois. Avaliar uso de rotulo legivel junto do ID, projeto no aviso e diagnosticos distintos para ausencia/ambiguidade, preservando rastreabilidade. |
| ENS-07 | Orquestracao por cliente: desenvolvedor quer apoio SDLC via using-agent-skills e subagentes reais no Codex; via DevSquad e seus especialistas pertinentes no Copilot. Separar metodo/skills, agente condutor, capacidades reais e papel helper/executor; conferir coerencia entre prompt preparado, perfil, guia e comando de entrada. |
| ENS-08 | Registro da escolha: priorizacao tem link geral ao migracao.md, mas faltam por candidata link direto ao registro/linha ou secao, ID completo e instrucoes por campo. Entregar Decisao atual -> ANALISAR AGORA, explicar Andamento separado e oferecer texto de Observacao/referencia com recorte e link de volta a lista. Desenvolvedor escolhe; ranking/helper nao alteram prioridades automaticamente. Sobreposicoes entre IDs exigem escolha explicita, sem marcar resolucao/falso positivo por inferencia. |
| ENS-09 | Relacoes entre issues: explicitar issue principal, achados sobrepostos, possivel efeito da mesma corretiva e como conferir cada ID depois. Recomendar observacoes reciprocas com referencia a mesma candidata; distinguir incluir formalmente uma issue no escopo de apenas acompanhar impacto sobre ela. Nao contar uma chamada duas vezes nem prometer resolucao/classificacao automatica. |
| ENS-10 | Retomada por intencao: pedidos curtos como "Conclui a priorizacao e ja registrei a issue escolhida no migracao.md. Me conduza ao proximo passo" devem bastar quando o contexto identifica a solicitacao. Helper recupera projeto/artefatos, confere estado salvo e orienta uma acao com motivo e resultado esperado. Nao exigir repeticao de IDs, caminhos, status, tarefas ou instrucoes tecnicas ja recuperaveis. Se houver ambiguidade real, perguntar somente o dado minimo necessario, sem escolher outra solicitacao por recencia. Validar esse comportamento com desenvolvedor iniciante nas transicoes entre etapas. |
| ENS-11 | Continuidade entre clientes: permitir retomar no Copilot um trabalho iniciado no Codex, e vice-versa, pelos mesmos arquivos salvos e identidade da solicitacao, sem refazer etapas so pela troca. Entrada atual: selecionar migracao_helper no Copilot; orientar-migracao no Codex. Nao presumir transferencia do historico dos chats nem selecao automatica de agente. Pedido curto com projeto e etapa deve levar a leitura das escolhas/referencias existentes; pedir artefato adicional somente se houver ambiguidade. Validar retomada entre clientes, ausencia de escrita concorrente pelos executores e manutencao dos limites helper/execucao. Desenvolvedor relatou aparente recuperacao do Copilot ao desativar o MCP do Azure; hooks historicos nao comprovam a causa nem impedem esse reteste. |
| ENS-12 | Regra unica de transicao para planejamento: selecao humana em estado compativel e registro consistente permitem preparar proposta; Reconciliacao PENDENTE isolada nao comprova conflito impeditivo. Para exigir reconciliacao antes, helper deve apontar divergencia concreta, evidencia e efeito no recorte. Harmonizar contrato, skill/papeis, guias, templates e texto gerado no registro; diferenciar concluir uma manutencao pendente de poder planejar. Considerar registros ja gerados, preservando escolhas, recibos/snapshots e historico; nao marcar CONCLUIDA automaticamente. Validar nos dois clientes os casos sem conflito, com conflito relevante, conflito alheio ao recorte e ausencia/selecao incompativel; resposta deve indicar somente a proxima acao executavel. |
| ENS-13 | Preparo a partir do registro escolhido: reutilizar Project/Source, issues/recorte, origem MTA, lista de priorizacao e referencias de evidencias do migracao.md, com indice somente como localizador. Entrada deve transmitir um registro concreto a tarefa (por exemplo arquivo aberto validado ou referencia explicita); terminal nao herda o contexto do chat. Se a selecao for inequivoca, nao perguntar novamente projeto/rodada; se houver varios candidatos, perguntar apenas o registro/frente, sem juntar projetos ou escolher pela recencia. Reutilizar a tarefa/menu existente com nome neutro ao cliente; mostrar resumo informativo do contexto resolvido e orientar execucao no cliente certo. |
| ENS-14 | Separar preparar proposta de atualizar base MTA: planejamento usual deve usar a rodada vinculada ao registro, revalidar identidade/integridade e produzir recibo/snapshots sem recarregar catalogo de outra rodada implicitamente. Trocar/importar MTA pertence a escolha explicita de manutencao/reconciliacao; ausencia/conflito nao autoriza fallback para ultima elegivel. Preservar recibos e destinos, decisoes e vinculos; reaproveitar solicitacao selecionada na retomada, sem gerar outra por rotina. Evidencias/codigo continuam externos ao registro e precisam ser conferidos; simplificar a entrada nao elimina context.json ou verificacoes. |
| ENS-15 | Governanca assistida com entrada simples: desenvolvedor concentra escolha, observacoes, recorte, issues adicionais e referencias no migracao.md; helper confere estado, explica impacto e conduz uma etapa por vez, preservando decisao humana/GO/aceite. Checagem de consistencia e continua nas retomadas; reconciliacao separada so se houver necessidade concreta, sem transformar qualquer edicao em conflito. Priorizar e opcional; replanejar revisa proposta existente. Preparadores/executores autorizados persistem artefatos, sem ampliar o helper leitor. Harmonizar todo o percurso, inclusive sincronizacao do indice e registros ja existentes; evitar duplicar tarefas de preparo ou pedir os mesmos dados no prompt. |
| ENS-16 | Planejamento por evidencias e esclarecimento dirigido: pacote MTA completo nao e obrigatorio quando ha registro, escolha e referencias pertinentes. Preparar prompt/recibo com a base real; durante a analise, perguntar somente decisoes ou dados essenciais ainda ausentes antes de concluir proposta/to-do. Nao fabricar RunId, categoria, recomendacao ou par de documentos para cumprir formato. Preservar compatibilidade dos consumidores, limites das evidencias e mesma solicitacao na retomada. |
| ENS-17 | Entrada cotidiana unica: Planejamento: planejar sem menu de operacoes, selecao repetida de projeto ou submenu MTA. Resolver registro/base existentes; se faltar migracao.md, orientar Workspace: atualizar indice dos projetos para cria-lo. Reconciliar so quando identificada necessidade concreta, com caminho/chamada prontos. Varios registros elegiveis exigem apenas a escolha minima de contexto; nao presumir o ultimo nem planejar todos. |

Resposta 2 (apos pedir uma acao e esclarecer reconciliacao): adequada para
prosseguir. Corrigiu explicitamente a ambiguidade, distinguiu recomendacao de
pre-requisito, indicou apenas Planejamento: priorizar issues, workspace e Top 5,
explicou que prepara arquivos sem produzir ranking, e pediu prompt preparado ou
caminho completo com avisos do terminal. O prompt referencia o context.json.
A melhora ocorreu apos intervencao humana; ENS-01/02/03 continuam candidatos
a ajuste para obter esse comportamento desde o pedido curto.

Evento 3: desenvolvedor executou Planejamento: priorizar issues com Top 5 e
trouxe log e prompt completo. Recibo e prompt conferidos por leitura em
.harness/priorizacao/2ff39907a87d4101a7a7c21f7d2397d2/: Purpose correto, dois
projetos, antes vinculado ao RunId 161c1bd4ce7a4da78641091c58557e44 sem Diagnostics,
depois com Mta=null e aviso de origem ausente/ambigua. Prompt aponta ao mesmo
RequestId/ContextPath/RankingPath/Top; priorizacao.md ainda ausente. Log registra
abertura via code.cmd. Preparo produziu contexto; nenhuma analise de candidatas
ou ranking foi comprovada. Ausencia do MTA do depois e lacuna parcial esperada.

Orientacao neste ensaio: executar o prompt preparado em novo chat Codex dedicado
a essa operacao, usando o caminho real; preferencias sao opcionais. A conversa
do helper recebe o resultado para interpretacao/proximo passo. Receber um prompt
no helper nao autoriza automaticamente sua execucao. Novo chat e procedimento
recomendado para este ensaio, nao requisito tecnico do preparador.

Evento 4 / complemento ENS-05: desenvolvedor questionou a necessidade da mensagem
longa de execucao sugerida pelo avaliador. As instrucoes de leitura do contexto,
tratamento de lacunas, destino de escrita e limites ja estao no prompt preparado;
nao exigir que o desenvolvedor as redija ou repita. Para o ensaio, basta pedir
"Execute o prompt deste arquivo" com seu caminho real no novo chat Codex.
Preferencias continuam opcionais. Abrir o arquivo no editor nao executa o agente.
Criterio de usabilidade a considerar na consolidacao: helper/tarefa fornecerem
acionamento curto e pronto com o artefato correto, deixando contexto e regras
no prompt, sem transferir ao iniciante o conhecimento de ContextPath/RankingPath
ou a interpretacao tecnica dos avisos. Correcao da orientacao do avaliador;
nenhuma mudanca funcional aplicada durante esta coleta.

Complemento ENS-05: desenvolvedor perguntou a qual cliente pertence "Run Prompt
in New Chat" no editor do .prompt.md. Esse acionamento usa o Chat integrado do
VS Code/Copilot, nao a extensao Codex. Distinguir explicitamente os pontos de
entrada por cliente: no ensaio Codex, abrir conversa no painel Codex e pedir
execucao do arquivo pelo caminho. Fonte do comportamento do editor:
https://code.visualstudio.com/docs/agent-customization/prompt-files .

Direcao solicitada apos evento 4 (ENS-05/07): o helper deve fornecer o acionamento
ja preenchido, como "Execute o prompt deste arquivo" seguido do caminho real,
adaptado ao cliente da sessao. Nao exigir que o desenvolvedor componha esse texto
nem confundir estar no VS Code com estar no Copilot. Cliente incerto pede somente
a identificacao necessaria. Contexto/objetivo/limites permanecem comuns.

No Codex, o agente principal coordena o fluxo, usa using-agent-skills para escolher
apoio SDLC pertinente e delega aos subagentes disponiveis quando fizer sentido.
using-agent-skills e uma skill de metodo/descoberta, nao um agente nem proprietaria
de subagentes. No Copilot, a direcao pedida para orquestracao SDLC e DevSquad com
os especialistas pertinentes. Em modo helper, apoio continua somente de leitura
e orientacao; execucao e escrita pertencem a etapa autorizada correspondente.
Disponibilidade, ferramentas e limites precisam ser conferidos; nao simular
delegacao nem ampliar escopo por rotina padrao de skill/plugin.

Lacuna atual conferida: priorizar-issues usa agent: agent e sua lista de tools
nao inclui agent; portanto, a execucao Copilot desse prompt ainda nao representa
a orquestracao DevSquad solicitada. migracao_helper e hoje o orquestrador helper
local nos dois clientes, com apoio DevSquad restrito conforme papeis/contrato.
Registrar essa diferenca para a consolidacao; nao declarar a direcao ja entregue
nem alterar o plugin instalado durante o ensaio.

Refinamento confirmado pelo desenvolvedor (ENS-07): priorizar-issues deve assumir
o encaminhamento ao apoio SDLC correspondente ao agente de codificacao em uso:
Codex aplica using-agent-skills e subagentes reais pertinentes; Copilot usa
DevSquad e seus especialistas pertinentes. Isso deve fazer parte do fluxo/prompt,
sem pedir ao desenvolvedor que acrescente invocacoes ou altere agent/tools.
Conferir homogeneidade com as demais fases: planejar-lotes e implementar-lote
ja declaram agent: devsquad no adaptador Copilot; essa declaracao nao comprova
roteamento equivalente no Codex. A entrada curta deve bastar em cada cliente.
Cliente vem da sessao/entrada identificada, nao da extensao .prompt.md nem de
EditorPath (a tarefa atual recebe VS Code, sem parametro de cliente IA).
Se indispensavel, esclarecer o cliente uma vez. Preservar contrato comum de
priorizacao, evidencias, escolha humana e unica escrita em RankingPath, mesmo
quando o workflow SDLC normalmente gera outros artefatos. Validacao futura deve
comprovar apoio realmente utilizado nos dois clientes e informar indisponibilidade.

Retomada orientada: depois da execucao, o desenvolvedor pode invocar
orientar-migracao na mesma conversa Codex para interpretar a saida. Recuperar a
conversa anterior e opcional; a solicitacao/artefatos explicitos identificam o
trabalho. A separacao helper/execucao e de papel e autorizacao, nao de janelas.

Evento 5: desenvolvedor trouxe priorizacao.md da solicitacao
2ff39907a87d4101a7a7c21f7d2397d2, ainda sem pedir interpretacao ao helper.
Resultado: uma oportunidade, risco medio; 00400 direta e 00401 sobreposta no
mesmo ponto; depois como lacuna; escolha humana PENDENTE. Avaliacao por leitura
confirmou arquivo, links locais existentes, hashes do indice/dois registros e
dos quatro artefatos MTA iguais ao recibo; Findings/regras apontam a mesma
chamada getQueryCache() sem argumentos em LimpezaCache.java:10. POM/testes lidos
sustentam a natureza preliminar: Hibernate declarado 5.1.10.Final e tres testes,
sem comprovacao de execucao em 5.3/EAP 7.4. Documentacao 5.3 consultada confirma
a distincao entre getDefaultQueryResultsCache() e getQueryResultsCache(String).
Principais conclusoes coerentes neste caso; nao comprova todos os casos de uso,
corretiva aplicada, runtime, apoio SDLC ou delegacao nativa. Declaracao de unica
escrita vem da resposta do executor; hashes conferidos cobrem as entradas acima,
sem auditoria completa de todas as operacoes daquela sessao.

Nova dificuldade relatada: como registrar a propria decisao no migracao.md.
Aplicar ENS-08 na consolidacao: a saida deve ajudar o iniciante a localizar a
issue e efetuar a escolha sem reconstruir caminhos, colunas ou vinculos. Exemplo
condicional apresentado para 00400; nenhum ID foi escolhido nem registro alterado
por esta avaliacao. A lista permanece evidencia, e selecionar ANALISAR AGORA
nao concede GO nem altera Andamento automaticamente.

Evento 6: desenvolvedor editou o registro e trouxe duvida sobre a cobertura da
00401 sobreposta. Conferencia do arquivo salvo: 00400 ficou Decisao=A DEFINIR e
Andamento=ANALISAR AGORA, com observacao que expressa intencao de planejar a
corretiva e link valido para a lista. ANALISAR AGORA pertence a Decisao; o valor
em Andamento e invalido e a selecao nao aparece na coluna consumida pelo fluxo.
00401 permanece A DEFINIR/NAO ANALISADA, sem observacao. Nao corrigido pelo
avaliador: orientacao para o humano trocar os dois campos da 00400, preservando
seu texto, e sugestao de vinculo reciproco na observacao da 00401.

Reforco ENS-08: fornecer exemplos das linhas completas com os oito campos e
conferir a edicao humana antes de orientar o planejamento; somente explicar os
nomes das colunas nao evitou o erro neste ensaio. Reforco ENS-09: priorizacao deve
explicar a relacao e sugerir como registra-la; helper deve interpretar e conferir
o registro. Uma alteracao pode afetar os dois achados, mas classificacao e cobertura
permanecem rastreaveis por ID. Sem nova evidencia, nao declarar resolucao ou falso
positivo. Referenciar 00401 na observacao da principal nao seleciona automaticamente
a secundaria para planejamento; inclusao formal exige decisao humana explicita.

Evento 7: leitura posterior confirmou a correcao humana da 00400 para
Decisao=ANALISAR AGORA e Andamento=NAO ANALISADA, preservando observacao e link.
00401 ainda estava A DEFINIR/NAO ANALISADA, com observacao vazia nessa leitura;
depois o desenvolvedor informou ter acrescentado o vinculo. Reforcou que sua
tarefa deve ser simples e que o helper deve absorver a complexidade do contexto.
Mensagem detalhada de retomada sugerida pelo avaliador foi reduzida a informar
conclusao da priorizacao, escolha registrada e pedido do proximo passo. Registrar
ENS-10 como criterio de aceite futuro, sem declarar que o helper ja o satisfaz.

Evento 8: ao orientar troca para Copilot, o avaliador repetiu a pendencia antiga
de isolamento dos hooks DevSquad. Desenvolvedor informou que aparentemente resolveu
a falta de resposta ao desativar o MCP do Azure. Atualizar o estado de retomada
por esse relato, preservando os logs historicos sem causalidade presumida. Nao
foi identificado o servidor MCP exato nem recebido novo log; confirmacao operacional
sera o proximo teste do helper. Nao exigir nova alteracao no plugin para prosseguir.

Evento 9: desenvolvedor trouxe resposta e chamadas Read do Copilot ao pedido
curto de continuidade. Skill orientar-migracao lida; encontrou indice, registro
correto, lista/recibo da priorizacao, evidencias e solicitacao de reconciliacao.
Reconheceu 00400 ANALISAR AGORA, 00401 A DEFINIR com vinculo, e distinguiu escolha
atual do PENDENTE historico na lista. Conferencia local confirmou essas linhas,
incluindo agora a observacao reciproca da 00401. Ha resposta do Copilot nessa
sessao apos o relato de desativacao do MCP Azure; causa tecnica permanece aberta.
O trecho apresentado mostra leituras e declaracao de ausencia de escrita; nao
mostra delegacao nem identifica por si so qual perfil foi selecionado na interface.

Achado: resposta exigiu reconciliacao antes do lote sem apontar conflito concreto,
depois descreveu preparo, execucao e revisao da proposta na mesma orientacao.
Reforca ENS-01/02/10/11. Origem documental da ambiguidade confirmada:
scripts/HarnessPlanning.psm1:415 gera "Se Estado for PENDENTE, execute o prompt";
registro salvo repete esse imperativo, e guia planejamento-migracao.md:98 manda
executar os pendentes. O mesmo guia, linhas 309-314, permite opcao 1 diretamente
com registro consistente e separa planejamento de conclusao da reconciliacao.
Contrato exige selecao/estado compativel e conferencia de consistencia, sem
estabelecer PENDENTE isolado como impedimento a toda proposta. Registrar ENS-12
para alinhamento futuro; nao atribuir a falha somente ao modelo ou pedir que o
desenvolvedor conheca a excecao e escreva um prompt defensivo. Leitura do prompt
de reconciliacao e pertinente para conferir a pendencia; nao implica executa-lo.

Evento 10: desenvolvedor repetiu o pedido curto no Codex com orientar-migracao e
trouxe a resposta. Reconheceu corretamente a escolha/recorte da 00400, vinculo com
00401 ainda A DEFINIR e precedencia do registro atual sobre indice/ranking antigos.
Preservou proposta unica e GO posterior; declarou orientacao por leitura. Nao ha
evidencia de chamada a subagente nesse material, o que nao e falha para esta consulta.

Comparacao: Copilot exigiu reconciliacao primeiro; Codex a recomendou como primeiro
passo do percurso. Nenhum apresentou conflito concreto no recorte que justificasse
essa ordem, reforcando ENS-02/12 nos dois clientes. Ambos entregaram varias etapas
em vez de uma proxima acao com retorno humano (ENS-01/10). Codex ainda mandou
executar reconciliacao no Copilot Local/devsquad e usar Executar Prompt para planejar,
sem adaptar a entrada ao cliente da conversa (ENS-03/05/07). Distinguir o nome real
da Run Task, que hoje inclui Copilot, do destino de execucao do prompt; esse nome
nao exige trocar de cliente. A opcao p com a pasta MTA explicita e valida e preserva
a rodada escolhida; nao registrar essa alternativa como defeito.

Na consolidacao, alinhar regras comuns e acionamentos por cliente em conjunto;
nao pedir ao desenvolvedor mensagens maiores para compensar as ambiguidades.
Manter exemplos de resposta de um passo para os dois clientes e testar que o mesmo
estado leve a mesma decisao, com instrucoes de execucao apropriadas ao cliente.

Evento 11: desenvolvedor executou a Run Task de planejamento, escolheu projeto 1,
operacao 1 e Enter na rodada elegivel. Log mostrou tentativa indisponivel por
manifest.json ausente no historico local, mas preparou a solicitacao
86e35d8af7d54f9d8fecb500121be590, vinculada ao RunId
161c1bd4ce7a4da78641091c58557e44. Pasta:
.harness/planning/migracao-cache-antes__97a5fc995901/mta_2026-09-30_15-47-44-0300__161c1bd4ce7a/plano_2026-10-04_15-36-23-0300__86e35d8af7d5/.
Leitura confirmou context.json e prompt; PlanPath/TodoPath ainda ausentes.
Purpose=application-remediation, Source/AnalysisSource separados, MigrationPath e
EvidenceIndexPath corretos, Previous=null e CatalogStatus=ATUALIZADO. Registro atual
coincide com MigrationSnapshot e MigrationSha256 do recibo; 00400 continua
ANALISAR AGORA/NAO ANALISADA, 00401 A DEFINIR/NAO ANALISADA com observacoes reciprocas.
Rodada e origem coincidem com o registro e a priorizacao; nenhuma divergencia desse
vinculo foi identificada neste preparo. Isso nao e auditoria integral dos artefatos
MTA nem comprovacao de planejamento executado. Aviso do historico nao impediu o preparo.

Nova dificuldade: repetir projeto, operacao e MTA depois de registrar a escolha
gera trabalho e risco de alterar a base. Confirmado no codigo: .vscode/tasks.json
passa SelectTarget/SelectOperation; preparar-planejamento.ps1 seleciona projeto e
rodada antes de New-MtaPlanningContext. Select-MtaPlanningRun usa ultima elegivel
por padrao, sem resolver a origem do registro; New-MtaPlanningContextCore chama
Update-HarnessMigration para carregar o catalogo selecionado antes do snapshot.
Assim, outra rodada elegivel pode mudar a base do registro nesse fluxo, embora
neste ensaio a rodada tenha coincidido. Priorizar ja resolve e valida a origem do
registro em Read-PrioritizationProject, base para reaproveitamento futuro.

Direcao de simplificacao solicitada (ENS-13/14): registro como entrada humana,
indice como localizador, recibo como identidade/snapshot da solicitacao. Ler e
validar o registro antes de resolver preparacao; reutilizar sua rodada e referencias,
apresentar resumo e perguntar somente por ausencia/ambiguidade relevante. A tarefa
precisa receber o registro, pois nao conhece a conversa do helper. Usar arquivo
ativo exige validar que e registro da aplicacao, nunca aceitar qualquer .md por
nome. Havendo varias frentes/projetos, manter escolha humana unica; nao planejar
tudo que estiver ANALISAR AGORA nem presumir Previous pelo mais recente. Manutencao
usual reaproveita evidencias/origem atuais; troca/importacao de MTA e explicita.
Reaproveitar preparadores/verificacoes existentes, sem criar uma Run Task por
projeto ou arquivo. Nao remover recibos, integridade ou historico.

Reforcos ENS-03/05/06/10: terminal continua dizendo "a ser escrito pelo Copilot" e
"Executar Prompt" no Copilot Local; adaptar ao cliente. Aviso de historico deve
identificar a entrada ausente e seu efeito, sem parecer falha da origem selecionada.
Prompt gerado pede repetir lista/projeto/IDs/recorte no direcionamento, embora seu
corpo ja mande ler essa referencia no registro. Tornar complemento opcional quando
o registro ja fornece a escolha; nao exigir redigitacao nem duplicar autoridades.
Avaliar na consolidacao casos de rodada mais nova diferente da vinculada, varios
registros elegiveis, indice atrasado, origem ausente/conflitante, arquivo ativo
invalido, manutencao sem novo MTA e retomada de solicitacao explicita.

Evento 12: desenvolvedor apresentou o prompt de planejamento, ainda sem resultado
da execucao, e explicitou a direcao de simplificar sua governanca: preparar entradas,
acrescentar evidencias/observacoes/issues, priorizar se desejar, registrar escolha e
executar planejamento. Interpretar o pre-planejamento como priorizacao opcional;
replanejamento fica para proposta ja existente. Helper deve conduzir o processo e
explicar apenas as decisoes que cabem ao humano. Consolidacao conceitual registrada
em tasks/plan.md, secao Direcao de simplificacao registrada no ensaio, sem aplicar
mudancas funcionais nem substituir recibos/prompts atuais.

Complemento ENS-14/15: contrato ja descreve criacao/carga de registros pela tarefa
de indice; nao exigir outra criacao manual. Codigo conferido em
scripts/HarnessProjectIndex.psm1:276 mostra Sync-IndexMigration preparando manutencao
com a rodada mais recente reconhecida quando UpdateMigration esta ativo. Revisao
da simplicidade deve abranger esse caminho para nao permitir que o indice altere
implicitamente a base de um trabalho selecionado. Edicao de observacao/escolha ou
nova evidencia nao e automaticamente inconsistencia; avaliar efeito sobre recorte,
origem, plano e andamento, preservando evidencias historicas e limites por fase.
Humano pode incluir issues do catalogo ou DEV-... com origem/objetivo/evidencia,
sem atribuir categoria/regra MTA ficticia e sem inclusao automatica fora do lote.

Refinamento ENS-10/12/15: desenvolvedor rejeita acumular estados PENDENTE que
impliquem validar manualmente uma escolha ja feita. ANALISAR AGORA no registro
atual resolve a pendencia de selecao; ranking/indice/snapshot anteriores preservam
historico sem exigir repeticao da decisao. Consumidores devem mostrar escolha
registrada e proxima acao, sem chamar o documento inteiro de pendente ou classificar
a edicao humana esperada como conflito. Nao exigir atualizar manualmente cada
artefato dependente. Antes de solicitar validacao humana, agente da fase confere
o que pode nas fontes e isola a lacuna que realmente depende do desenvolvedor.
GO/aceite e evidencias de execucao sao dimensoes separadas; nao concluidas pela
escolha. Nao reescrever snapshots nem marcar reconciliacao CONCLUIDA por inferencia.

Evento 13 / fechamento da coleta: desenvolvedor decidiu interromper o ensaio para
simplificar o percurso antes de seguir. Pediu planejamento com evidencias sem pacote
MTA completo, perguntas essenciais antes da proposta/to-do, menos PENDENTE generico
e entrada unica Planejar. Registro ausente deve levar a tarefa de indice que o cria;
reconciliacao so por necessidade concreta. Requisitos registrados em ENS-16/17 e
plano SIM-01 a SIM-14, abrangendo contrato, scripts, consumidores, prompts, helpers,
README, guias e verificacoes. Isso nao declara validacao manual concluida.

Proximo trabalho: implementar o plano consolidado apos sua revisao, depois retestar
o fluxo simplificado nos dois clientes. A solicitacao 86e35d8af7d54f9d8fecb500121be590
permanece evidencia historica do preparo anterior; nao executar automaticamente nem
reescrever seu prompt/recibo. Reteste usa preparo do contrato corrigido. Delegacao
nativa e demais cenarios ainda precisam de validacao; consulta simples sem delegacao
nao constitui falha.

- [x] Consolidar os achados e planejar ajustes homogeneos conforme o pedido de
  interromper o ensaio; preservar evidencias e comportamentos corretos.

## Direcao de simplificacao registrada no ensaio - 2026-10-04

Registro historico das discussoes durante o ensaio; o plano consolidado acima
passa a orientar a proxima implementacao. Evidencias e criterios iniciais em ENS-01 a
ENS-15 do [to-do](todo.md#ensaio-acompanhado-do-helper-no-codex---2026-10-04).
Este registro nao altera contratos, prompts, tarefas ou recibos ja emitidos.

Entrada humana central: migracao.md do projeto escolhido, com prioridades,
observacoes, recorte, issues adicionais e referencias das evidencias. Indice
localiza e resume; recibo preserva identidade/snapshots/destinos da solicitacao.
Relatorios MTA, codigo e anexos continuam fontes externas a conferir. Preparacao
inicial pelo indice ja pode criar/carregar registros; nao impor uma segunda
tarefa de criacao do migracao.md quando ele ja existe.

Percurso proposto: preparar entradas necessarias -> priorizar opcionalmente ->
registrar escolha -> preparar/executar proposta -> revisao/GO -> corretiva ->
verificacoes -> aceite. Escolha direta dispensa ranking; pre-planejamento e
priorizacao, enquanto replanejamento revisa uma proposta existente. Operacoes
tecnicas de preparo/execucao continuam distintas, apresentadas pelo helper apenas
quando chegarem a vez, com entrada curta pronta para o cliente em uso.

Helper acompanha situacao, confere escolhas/evidencias, identifica mudancas com
impacto e orienta uma proxima acao; usa especialistas quando pertinente. Mantem
limites atuais de leitura/orientacao. Preparadores e executores da etapa autorizada
persistem artefatos/andamento permitidos. Humano escolhe prioridades/recorte,
resolve conflitos de intencao e concede GO/aceite; helper nao assume essas decisoes.
Se futuramente for desejada escrita automatica pelo condutor, isso pertence ao
executor com escopo explicito, sem ampliar silenciosamente o perfil helper.

Conferencia de consistencia integra a retomada; reconciliacao separada e uma rota
por necessidade concreta, nao pedaggio de toda proposta. Nota explicativa, escolha
registrada apos um snapshot ou evidencia que apenas confirma estado nao sao
automaticamente conflitos. Novo MTA, mudanca de escopo, divergencia entre colegas
ou evidencia que contradiz andamento exigem avaliar impacto e conciliar o recorte;
revisar o mesmo lote quando aplicavel. Dependencia impeditiva deve ser demonstrada.
Preservar pendencias historicas e nao marcar CONCLUIDA sem executar a manutencao.

Rever juntos atualizacao do indice, preparo de planejamento/manutencao, templates,
guia e helpers: Sync-IndexMigration tambem carrega o ultimo MTA reconhecido quando
UpdateMigration esta ativo. Separar descoberta inicial de adocao de outra rodada
em um trabalho ja selecionado; impedir troca implicita da base por atualizar indice
ou preparar proposta. Nao criar registro duplicado, novo sistema de status ou novas
Run Tasks por arquivo/projeto. Observacoes no prompt sao complementos opcionais;
nao repetir selecao e links ja registrados. Lacunas e ambiguidade pedem somente o
dado indispensavel, sem planejar automaticamente todos os projetos/issues.

Refinamento humano: ANALISAR AGORA ja satisfaz a decisao de incluir a issue na
analise. Consumidores devem reconhecer essa escolha no registro atual e parar de
apresenta-la como PENDENTE porque ranking/indice/snapshot anterior assim dizia.
Nao exigir edicao manual coordenada de varios documentos para repetir a escolha.
Preservar snapshots historicos; no resumo atual, mostrar decisao registrada e
proxima acao. Evitar estado generico de "documento pendente": distinguir escolha,
execucao do planejamento, verificacoes especificas e futuras decisoes de GO/aceite.
Evidencia nao examinada pede verificacao pertinente pelo agente da fase antes de
virar pergunta ao humano; somente lacuna concreta que dependa dele pede retorno.
Esse reconhecimento nao marca reconciliacao historica CONCLUIDA nem presume
corretiva, verificacao ou GO. Revisar quando gerar avisos/pendencias para que o
simples preparo de arquivos nao produza uma nova obrigacao humana sem necessidade.
