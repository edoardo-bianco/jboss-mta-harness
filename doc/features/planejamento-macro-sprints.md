# Proposta: planejamento macro por sprints

**Origem:** pedido do desenvolvedor em 2026-10-08: distribuir a resolucao das
issues existentes num periodo informado, por prioridade e categoria, considerando
por exemplo sprints de duas semanas e dois desenvolvedores.
**Decisao:** registrar a proposta para evolucao futura e concluir a entrega
corporativa atual. **Nao implementada; sem data de implementacao aprovada.**
O estado fica no [backlog vigente](../../tasks/todo.md#backlog-vigente).

## Resultado pretendido

Uma operacao distinta de planejamento macro, com nome proposto
**Planejamento: planejar sprints**, produz uma distribuicao revisavel entre
projetos, capacidade ocupada/disponivel, dependencias, riscos e trabalho que nao
coube. O periodo pode ser informado por datas ou por numero/duracao de sprints.
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
| Equipe/capacidade | Numero de desenvolvedores, dedicacao, ausencias/feriados e capacidade real disponivel por sprint; nao presumir produtividade linear pela contagem de pessoas. |
| Esforco restante | Estimativa por issue/recorte, unidade, origem, faixa de incerteza e validacao. Reaproveitar estimativas existentes quando comparaveis. Issues sem estimativa ficam identificadas para refinamento. |

Nao converter automaticamente story points/effort do MTA em horas. Uma contagem
de incidentes tambem nao equivale a esforco. Escolher uma unidade consistente com
o historico da equipe; na ausencia de historico, usar estimativas humanas com
incerteza explicita. Reservar capacidade para testes, integracao, revisao,
retrabalho e atividades de servidor quando fizerem parte do escopo.

## Distribuicao e revisao

1. Fixar escopo e fotografar referencias das entradas. Resolver conflitos de
   identidade/decisao antes de usar dados divergentes; nao escolher pela recencia.
2. Calcular capacidade por sprint na unidade escolhida, considerando calendario
   e dedicacao. Mostrar as premissas e os dados ainda ausentes.
3. Ordenar conforme prioridade e politica de categorias confirmadas. Respeitar
   dependencias, continuidade do trabalho iniciado e competencias necessarias.
4. Alocar somente esforco estimado na capacidade disponivel. Issue maior que
   uma sprint pede recorte ou previsao de continuidade, sem declarar resolucao
   parcial como conclusao. Nao compactar todas as issues artificialmente no prazo.
5. Exibir cronograma proposto e listas de excedentes, bloqueadas e sem estimativa,
   cada uma com motivo e fonte. Permitir revisao das premissas pelo desenvolvedor.
6. Salvar revisao com vinculo a anterior e entradas utilizadas. Atualizar o
   planejamento macro a partir de novas evidencias, preservando o anterior.

As saidas propostas incluem Markdown legivel e dados estruturados para
comparacao/exportacao, em area local propria sob `.harness/`. Destino e contrato
serao definidos na implementacao, aproveitando compartilhamento existente quando
compativel. Nao escrever nos registros ou PlanPath/TodoPath de corretiva somente
por ter alocado uma issue numa sprint.

## Criterios para a futura implementacao

- Entradas/perguntas unicas, reutilizadas do contexto; nenhuma nova tarefa por
  projeto, sprint, formato ou arquivo.
- Capacidade/estimativas e prioridade rastreaveis, sem duplicar issues por nome
  parecido ou misturar a mesma regra de projetos distintos.
- Dependencias, sobrecarga, escopo fora do prazo e incerteza visiveis.
- Mesmas entradas/premissas produzem proposta explicavel; alteracoes humanas
  geram nova revisao, sem apagar historico ou simular aceite.
- Helper aponta para este procedimento quando implementado e continua orientador.
  Enquanto proposta, informa a indisponibilidade da Run Task e pode apoiar
  planejamento macro manual com os arquivos fornecidos.

Antes de implementar, confirmar formato das estimativas, politica entre categorias,
calendario/capacidade e criterios de replanejamento com um conjunto real de projetos.
Essa definicao nao impede a coleta atual de indice, priorizacao, plano e exportacao.
