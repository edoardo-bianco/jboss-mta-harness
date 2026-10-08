# Proposta: planejamento macro por sprints

**Origem:** pedido do desenvolvedor em 2026-10-08: distribuir a resolucao das
issues existentes num periodo informado, por prioridade e categoria, considerando
por exemplo sprints de duas semanas e dois desenvolvedores.
**Decisao:** registrar a proposta para evolucao futura e concluir a entrega
corporativa atual. **Nao implementada; sem data de implementacao aprovada.**
O estado fica no [backlog vigente](../../tasks/todo.md#backlog-vigente).

**Refinamento do mesmo pedido:** a tarefa deve preparar contexto e prompt para
um agente de planejamento no cliente escolhido, aproveitando tudo que ja foi
coletado e pedindo apenas prazo/capacidade ainda ausentes. Incluir reservas para
testes e implantacao, agrupamentos, percentuais previstos e diagrama temporal,
respeitando o numero maximo de sprints. Continua sendo proposta futura.

## Resultado pretendido

Uma operacao distinta de planejamento macro, com nome proposto
**Planejamento: planejar sprints**, produz uma distribuicao revisavel entre
projetos, capacidade ocupada/disponivel, dependencias, riscos e trabalho que nao
coube. A Run Task prepara o contexto/prompt; o agente estima e elabora a proposta
em etapa separada, apos receber as informacoes essenciais. O periodo pode ser
informado por datas ou por numero/duracao de sprints.
Se ainda nao houver data inicial, identifica Sprint 1, Sprint 2 etc., sem inventar
datas de calendario. A quantidade de desenvolvedores pode variar por sprint.

O cronograma e uma proposta de capacidade e prioridade, sem prometer conclusao,
marcar issues resolvidas, alterar decisoes ou conceder GO. O planejamento
detalhado continua pela entrada habitual por issue, mantendo um lote consistente
por frente; nao gerar automaticamente planos de corretiva para todas as issues.

## Entradas a reaproveitar e a perguntar

| Entrada | Fonte e tratamento propostos |
| --- | --- |
| Projetos, issues e situacao atual | Indice localiza os registros de migracao; registro atual concentra decisoes e andamento. Preservar Source/ID e distinguir concluida, em andamento, pendente, bloqueada e nao avaliada. |
| Prioridade e categoria | Escolhas humanas vigentes e priorizacoes vinculadas com origem/cobertura identificadas. Categoria nao equivale automaticamente a prioridade. Ordem entre categorias e desempates devem ser explicitos. |
| Evidencias e dependencias | Fichas, planos e anexos existentes; citar fonte e marcar dependencia desconhecida. Sem MCP, ler arquivos normalmente. |
| Horizonte | Perguntar datas ou numero de sprints; duas semanas e uma opcao, nao um limite fixo. Confirmar calendario util quando houver datas. |
| Testes e implantacao | Perguntar quantas sprints ou qual capacidade reservar para teste integrado/homologacao e implantacao, com janelas/dependencias. Essas reservas integram o limite total, sem se somar silenciosamente a ele. |
| Equipe/capacidade | Numero de desenvolvedores, dedicacao, ausencias/feriados e capacidade real disponivel por sprint; nao presumir produtividade linear pela contagem de pessoas. |
| Esforco restante | Estimativa por issue/recorte, unidade, origem, faixa de incerteza e validacao. Reaproveitar estimativas existentes quando comparaveis. Issues sem estimativa ficam identificadas para refinamento. |

Nao converter automaticamente story points/effort do MTA em horas. Uma contagem
de incidentes tambem nao equivale a esforco. Escolher uma unidade consistente com
o historico da equipe; na ausencia de historico, o agente propoe faixas a partir
das evidencias, com premissas explicitas e validacao humana. Reservar capacidade
para testes, integracao, revisao,
retrabalho e atividades de servidor quando fizerem parte do escopo.

## Contexto preparado e prompt por cliente

A tarefa deve reunir referencias e evidencias pertinentes de todos os projetos
do escopo: indice, registros de migracao, categorias/priorizacoes com cobertura,
fichas, planos de implementacao existentes, andamento, dependencias e resultados
de verificacoes, incluindo build/testes e Sonar quando disponiveis. Usar o indice
como localizador, sem substituir a decisao atual
do registro por um ranking antigo. Plano existente e dado para estimar esforco
restante; a presenca do arquivo nao prova execucao, GO ou aceite.

O pacote deve identificar Source/ID, origem/recibo/rodada quando presentes,
caminhos locais ou copias consolidadas, data de coleta e hashes das entradas
usadas. Preservar lacunas, conflito de fontes e base parcial. Evidencias recebidas
seguem suas referencias de origem; nao exigir MTA original quando o contexto
consolidado ja permite a leitura. Sem MCP, preparar a partir dos arquivos.
Incluir somente material necessario, sem credenciais ou extracao indiscriminada.

Gerar mensagem pronta e destinos para a proposta macro, distintos de PlanPath/
TodoPath de corretiva. A tarefa informa qual agente/perfil abrir e quais arquivos
ele deve ler, sem executar automaticamente o prompt. O agente deve perguntar
apenas dados essenciais ainda ausentes, como numero maximo de sprints, duracao,
desenvolvedores/dedicacao e reservas de testes/implantacao. Respostas e estimativas
retornam a proposta revisavel, sem registrar resolucao nos projetos.

| Cliente escolhido | Adaptacao proposta |
| --- | --- |
| GitHub Copilot/DevSquad | Encaminhar ao perfil de planejamento disponivel, como `devsquad.plan` quando suas capacidades forem confirmadas. Definir papel de planejamento macro e limites de escrita dos seus entregaveis; nao tratar disponibilidade de DevSquad como comprovada nem transformar helpers leitores em executores. |
| Codex | Preparar prompt para o papel de planejamento macro usando `using-agent-skills`, quando disponivel, para descobrir/aplicar skills de planejamento e estimativa pertinentes. Skill nao e nome de agente; identificar o executor real na implementacao e nao presumir delegacao automatica. |

O contrato de entrada/saida e os criterios de capacidade sao os mesmos nos dois
clientes. Cliente, agente ou skill ausentes devem ser informados; permitir usar
o mesmo contexto para proposta manual ou com agente disponivel, sem alterar
permissoes ou fabricar execucao/delegacao. A escolha concreta do perfil e a
conferencia de suas capacidades fazem parte do recorte de implementacao futuro.

## Distribuicao e revisao

1. Fixar escopo e fotografar referencias das entradas. Resolver conflitos de
   identidade/decisao antes de usar dados divergentes; nao escolher pela recencia.
2. Calcular capacidade por sprint na unidade escolhida, considerando calendario,
   dedicacao e reservas. Mostrar as premissas e os dados ainda ausentes. Por
   exemplo, em seis sprints totais, uma exclusiva de teste e uma de implantacao
   deixam quatro para as demais atividades; o exemplo nao estima entregas reais.
3. Ordenar conforme prioridade e politica de categorias confirmadas. Respeitar
   dependencias, continuidade do trabalho iniciado e competencias necessarias.
4. Alocar somente esforco estimado na capacidade disponivel. Issue maior que
   uma sprint pede recorte ou previsao de continuidade, sem declarar resolucao
   parcial como conclusao. Nao compactar todas as issues artificialmente no prazo.
   Agrupar por objetivo tecnico coerente, dependencias e possibilidade de entrega;
   compartilhar categoria, por si so, nao obriga colocar issues no mesmo lote.
5. Exibir cronograma proposto e listas de excedentes, bloqueadas e sem estimativa,
   cada uma com motivo e fonte. Permitir revisao das premissas pelo desenvolvedor.
6. Salvar revisao com vinculo a anterior e entradas utilizadas. Atualizar o
   planejamento macro a partir de novas evidencias, preservando o anterior.

As saidas propostas incluem Markdown legivel e dados estruturados para
comparacao/exportacao, em area local propria sob `.harness/`. Destino e contrato
serao definidos na implementacao, aproveitando compartilhamento existente quando
compativel. Incluir um diagrama temporal de atividades macro, duracoes e
dependencias: Gantt/Mermaid quando houver datas confirmadas, ou eixo Sprint 1..N
quando o calendario ainda nao estiver definido. Mostrar desenvolvimento,
testes/homologacao e implantacao, carga e eventuais paralelismos.

Por agrupamento/sprint, apresentar projetos e Source/IDs cobertos, quantidade de
issues com conclusao prevista, percentual da base fixa e acumulado, esforco/faixa,
capacidade, criterio de conclusao e fonte da estimativa. O denominador deve ser
o total de issues unicas do escopo inicial declarado; exibir tambem os recortes
por categoria. Uma issue que atravessa sprints conta uma vez, apenas na conclusao
prevista, sem confundir incidentes, issues examinadas e issues resolvidas.

Percentual **previsto** nao e percentual **comprovado**: o segundo depende das
evidencias e do aceite. A proposta pode levar os agrupamentos ate o fim do escopo
ou ate a ultima sprint permitida. Se nao couber, mostrar trabalho restante,
confianca da estimativa e alternativas de escopo/capacidade/prazo para decisao
humana. Testes de cada corretiva permanecem no seu esforco; uma sprint de teste
integrado nao transfere todos os testes para o final.

Nao escrever nos registros ou PlanPath/TodoPath de corretiva somente por ter
alocado uma issue numa sprint.

## Criterios para a futura implementacao

- Entradas/perguntas unicas, reutilizadas do contexto; nenhuma nova tarefa por
  projeto, sprint, formato ou arquivo.
- Capacidade/estimativas e prioridade rastreaveis, sem duplicar issues por nome
  parecido ou misturar a mesma regra de projetos distintos.
- Dependencias, sobrecarga, escopo fora do prazo e incerteza visiveis.
- Contexto e prompt rastreaveis, com adaptacao por cliente e papel disponivel;
  preparo separado da execucao do agente e da revisao humana da estimativa.
- Testes/implantacao dentro do limite total; diagrama temporal e percentuais com
  base fixa, sem inventar datas, produtividade ou concluir todas as issues a forca.
- Mesmas entradas/premissas produzem proposta explicavel; alteracoes humanas
  geram nova revisao, sem apagar historico ou simular aceite.
- Helper aponta para este procedimento quando implementado e continua orientador.
  Enquanto proposta, informa a indisponibilidade da Run Task e pode apoiar
  planejamento macro manual com os arquivos fornecidos.

Antes de implementar, confirmar formato das estimativas, politica entre categorias,
calendario/capacidade e criterios de replanejamento com um conjunto real de projetos.
Essa definicao nao impede a coleta atual de indice, priorizacao, plano e exportacao.
