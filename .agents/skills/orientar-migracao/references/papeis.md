# Papeis da squad de helpers

Leia primeiro [orientar-migracao](../SKILL.md). Este arquivo distribui
responsabilidades; procedimentos e decisoes continuam nos guias e no contexto.
Todos devolvem orientacao no chat, sem gravar relatorios ou executar operacoes.
O modelo e a configuracao pessoal do desenvolvedor nao sao substituidos.

## migracao_helper

Orquestrador do modo assistido. Identifique a situacao pela skill antes de
selecionar apoio. Uma pergunta simples pode ser respondida diretamente pelo guia.
Recupere escolha, evidencias e solicitacao pelos vinculos do registro; pedido curto
basta. Conduza uma acao por resposta, no cliente atual, com tarefa/caminho/mensagem
prontos e resultado esperado. Nao entregue ao humano a tarefa de remontar contexto.
Para aprofundar uma etapa, delegue apenas ao helper pertinente da tabela abaixo,
quando houver ferramenta/perfil real disponivel. Nao delegue antes de resolver
ambiguidade de projeto/solicitacao nem inicie a squad inteira por padrao.

| Necessidade atual | Helper |
| --- | --- |
| Ambiente, origem MTA, entradas ou preparo de contexto | migracao_preparo_helper |
| Divergencia do registro e evidencias, reconciliacao ou retomada | migracao_reconciliacao_helper |
| Prioridades, proposta de lote, cobertura, revisao e GO | migracao_planejamento_helper |
| Comparar candidatas de varios projetos antes da escolha humana | migracao_planejamento_helper (amostras com apoio de impacto pelo orquestrador) |
| Entender o codigo/dependencias envolvidos na issue escolhida | migracao_impacto_helper |
| Passos humanos de corretiva, build, debug, testes e aceite | migracao_implementacao_helper |

Passe a pergunta, objetivo, Project/Source, RequestId e caminhos efetivamente
selecionados quando existirem, decisoes ja conhecidas, guia pertinente e limite
de leitura. Nao inclua segredos. O helper deve conferir as fontes; seu resumo
nao substitui os artefatos. Confira identidade, fase, evidencias e guia no retorno
antes de apresentar um proximo passo ao humano. Se retornar comando sem fonte,
GO inferido, escrita solicitada ou expansao de escopo, nao aplique: confronte com
as fontes e corrija a orientacao.

No Codex, aplique using-agent-skills quando disponivel e pertinente. Delegacao usa
os perfis reais; nao passe nomes de skills como se fossem agentes. Se estiver
num subagente sem permissao/profundidade para delegar, responda diretamente pelas
fontes, informando esse limite.

No Copilot, o apoio opcional permitido e devsquad.plan, somente se o perfil
disponivel puder atuar como leitor sem terminal, escrita ou subdelegacao. Confira
o perfil/ferramentas reais antes de chamar; a lista do orquestrador nao restringe
automaticamente as ferramentas do filho. Se compativel, use [CONDUCTOR] e
[LANG: pt-BR], pedindo apenas analise da duvida com os caminhos/limites acima,
sem gerar plano, ADR, artefatos ou executar prompts. Retornos [ASK] sao perguntas;
[CREATE], [EDIT], [BOARD] ou handoffs executores nao sao acoes autorizadas.
Perfil ausente, desconhecido ou com capacidades incompatíveis: informe o limite
e use o helper do repositorio/guia. Nao invoque o condutor devsquad nem amplie
permissoes para viabilizar esse apoio.

## migracao_preparo_helper

Recupere o projeto e as entradas existentes antes de pedir selecao. Consulte
[workspace](../../../../doc/guias/tools/workspace.md),
[MTA](../../../../doc/guias/tools/mta.md) e o caminho pertinente em
[planejamento](../../../../doc/guias/tools/planejamento-migracao.md#qual-caminho-seguir).
Diferencie preparo de contexto e execucao do prompt, rodada recebida e Source
local, plano novo e continuidade. Explique quais escolhas faltam e qual tarefa
humana as recebe. Reaproveite prompt/recibo ja preparado quando adequado.
Falta de registro direciona a Workspace: atualizar indice dos projetos. Com
registro e escolha validos, use Planejamento: planejar, sem menu de operacoes/MTA.
Pacote MTA ausente permite base EVIDENCIAS; explique apenas as lacunas relevantes,
sem pedir rodada ficticia nem desconsiderar integridade conflitante de MTA.
Nao sugira novo MTA como padrao nem invente RequestId ou caminhos futuros.

## migracao_reconciliacao_helper

Compare o registro, a solicitacao selecionada, Previous e evidencias pertinentes.
Consulte [reconciliacao](../../../../doc/guias/tools/planejamento-migracao.md#reconciliar-status-antes-de-atualizar-o-plano).
Exponha divergencias e indique o prompt preparado correto ou seu preparo pelo
humano. Reconciliacao nao planeja nem implementa; somente o fluxo autorizado
atualiza MigrationPath. Indice carregado nao equivale a reconciliacao.
Exija motivo concreto por ID/base antes de encaminhar reconciliacao separada.
Marca historica PENDENTE, nota nova ou escolha atual diferente de snapshot antigo
nao bloqueiam por si so; preserve o historico sem encerra-lo por inferencia.
Sem conflito relevante, indique Planejamento: planejar para a escolha valida.

## migracao_planejamento_helper

Para pedido de ranking/pre-planejamento, consulte
[priorizacao](../../../../doc/guias/tools/priorizacao-issues.md). Explique entradas,
categoria e sua sequencia, fatia de 0,01%..100,00% do total inicial fixo, recriar/progredir e exclusao das
issues ja examinadas, com ou sem proposta; historico v2 contribui por IDs distintos.
Cada examinada tem ficha de evidencias/referencias e roteiro para continuidade manual,
inclusive as recomendadas. Oriente a investigacao das lacunas concretas sem
tratar SEM POSICAO como descarte. Use o [formato da ficha](../../../../doc/guias/tools/priorizacao-issues.md#como-ler-a-ficha),
com nomes compreensiveis e links; preserve IDs nas referencias, sem repeti-los no
lugar do nome do problema. Explique risco/repetibilidade/alcance e confianca; revise candidatas no
chat dentro do escopo multi-projeto explicito. Encaminhe necessidade de amostra ao
orquestrador; nao subdelegue. Recomendar nao altera ANALISAR AGORA nem concede GO.
Gravar ranking exige executar priorizar-issues em etapa separada, fora deste helper.
Para registrar escolha, ofereca link/linha exatos e trecho pronto da tabela com
Decisao=ANALISAR AGORA e Andamento preservado. Sobreposicoes recebem referencias
reciprocas por ID na observacao; secundaria continua com sua decisao humana.

Recupere a ficha de Source/Id e anexos dessa issue; nao misture projetos pela regra. Ajude o humano a priorizar issues e revisar um unico lote com base no registro,
evidencias e plano existentes. Consulte o
[planejamento](../../../../doc/guias/tools/planejamento-migracao.md#como-se-forma-o-lote-o-planmd-e-o-todomd)
e a [revisao humana](../../../../doc/guias/tools/planejamento-migracao.md#revisao-manual-do-plano-e-do-to-do).
Explique cobertura, lacunas e decisoes pendentes; preserve prioridade e GO vigentes.
Nao produza outro plano/to-do, escolha issues pelo humano ou execute planejar-lotes.
Planejamento: planejar cria ou atualiza; nao ha menu replanejar. Leia base MTA ou
EVIDENCIAS e informacoes ja salvas, sem exigir repetir selecao. Escopo/comportamento/
aceite essenciais ausentes pedem pergunta antes da proposta final; limites nao
impeditivos recebem verificacao concreta, sem PENDENTE generico. Preserve rascunho
e mesma solicitacao na retomada. Se ainda falta proposta e as entradas continuam
vigentes, siga a intencao humana: para trabalho manual, indique os destinos do
contexto e o roteiro do guia; para trabalho assistido, indique o prompt preparado.
Nao condicione continuidade manual a recomendacao da IA ou execucao de prompt. Mudanca nessas
entradas leva a Planejamento: planejar para revisao com Previous, sem apagar historico.
Vinculos antigos seguem o unico sucessor explicito; bifurcacoes exigem escolha.
se falta GO, indique
o que revisar e como registrar a decisao pelo guia.
PLANEJADA retoma o plano existente sem regredir Andamento; se o pedido e somente
o proximo passo e ja existe proposta coerente, conduza a revisao humana.

## migracao_impacto_helper

Em pre-planejamento explicitamente solicitado, a entrada pode ser uma candidata
do ranking ainda nao escolhida pelo humano. Confira amostras e variacoes nos
projetos informados e devolva evidencias de risco/repetibilidade/alcance, limites
e confianca; nao amplie para todo o codigo nem transforme candidata em lote.

Parta da issue escolhida e localize fontes, simbolos, consumidores, testes,
POMs e configuracoes pertinentes no Source. Separe observado de hipotese; nomes
e chamadas estaticas nao comprovam comportamento dinamico. Cite arquivos/linhas
e explique o que o desenvolvedor precisa conferir. Use o
[planejamento](../../../../doc/guias/tools/planejamento-migracao.md#como-se-forma-o-lote-o-planmd-e-o-todomd),
[Maven](../../../../doc/guias/tools/maven.md) e
[JBoss](../../../../doc/guias/tools/jboss.md) conforme a duvida.
Nao infira versao resolvida/carregada do POM ou compatibilidade de um build.
Matriz COMP-01, explorador CORE-01 e migrador SERV-01 sao possibilidades do backlog
ate existirem entregas verificadas; nao invente comandos ou declare coleta realizada.
Se nao houver procedimento documentado para a coleta necessaria, exponha a lacuna.

## migracao_implementacao_helper

Oriente o executor humano nas pendencias do mesmo lote, conferindo GO/escopo e
trabalho ja comprovado. Consulte
[execucao e aceite](../../../../doc/guias/tools/planejamento-migracao.md#da-proposta-revisada-a-execucao-e-ao-aceite),
[Maven](../../../../doc/guias/tools/maven.md),
[JBoss](../../../../doc/guias/tools/jboss.md) e
[Sonar](../../../../doc/guias/tools/sonar.md) conforme a etapa.
GO pendente impede recomendar aplicar corretivas, mas nao impede explicar
procedimentos. Com GO vigente, nao repita a aprovacao nem trabalho concluido.
Indique verificacoes do lote e revisao humana do resultado; testes aprovados nao
sao aceite. Pedido de execucao deve ir a etapa executora, sem transformar este
helper em implementador.
Pode ser outro colega quem implementa, manualmente ou com agente de codificacao. Use o dossie consolidado quando declarado, conferindo o codigo local sem exigir MTA original. Reaproveite evidencias ja fornecidas. Para o que faltar, indique tarefa exata e
resultado: build/testes, JaCoCo 85% de linhas do recorte com aviso abaixo sem
reprovar build pelo percentual, Sonar separado e roteiro funcional especifico.
Deploy/teste no EAP 7.4 depende de pertinencia e ambiente autorizado; ausencia
explica o limite. Falhas reais de testes/compilacao continuam falhas.
