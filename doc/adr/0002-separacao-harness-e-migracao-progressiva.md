# ADR-0002: separar evolucao do harness e migracao progressiva das aplicacoes

Status: aceita pelo desenvolvedor em 2026-09-27.

Atualizacao em 2026-09-28: para identidade e Git, a
[ADR-0004](0004-git-informativo-sem-controle-de-branches.md) substitui os controles
de branches da ADR-0003. Mantidos os escopos, integridade MTA e GO/aceite separados.
Leitura historica: as exigencias abaixo de reconciliar por mudanca de HEAD e de
controle Git pela ADR-0003 foram substituidas. Confira conteudo relevante, sem
exigir novo contexto apenas por branch/commit. No contrato atual, Sonar e nova
rodada MTA sao checklist nao bloqueante; pendencias ficam visiveis para o aceite.

## Contexto

O mesmo workspace pode ser usado por agentes, incluindo o Copilot, para evoluir
o ambiente de migracao ou para usa-lo na correcao de uma aplicacao. Ambos precisam
de planejamento e to-do, mas possuem escopos, evidencias e autorizacoes diferentes.
Um relatorio MTA pode conter milhares de ocorrencias. Detalhar todas antes de
executar a primeira corretiva gera planos extensos sobre uma base que mudara.

## Decisao

Manter dois trabalhos separados, mesmo quando realizados pelo mesmo agente:

| Trabalho | Escopo | Plano e to-do |
| --- | --- | --- |
| Evoluir o harness | Scripts, preparacao de prompts/contextos, Run Tasks, configuracao, testes e documentacao do ambiente | `tasks/plan.md` e `tasks/todo.md` na raiz do harness |
| Migrar uma aplicacao usando o harness | Classificar achados, planejar e executar um lote de corretivas autorizado e verificar seu resultado | `PlanPath` e `TodoPath` do contexto, na solicitacao sob `.harness/planning/` |

O agente deve identificar o trabalho solicitado antes de editar. Nomes iguais
como plan.md e todo.md nao tornam os arquivos intercambiaveis. Uma melhoria do
harness descoberta durante a migracao deve ser relatada como demanda separada;
nao entra no lote da aplicacao nem autoriza editar prompts ou tarefas do harness.

### Separacao das branches de desenvolvimento do harness

Complemento confirmado pelo desenvolvedor em 2026-09-27: toda alteracao do
harness, incluindo documentacao, prompts e tasks, deve comecar em branch propria
`harness/<objetivo>`, derivada da principal do seu repositorio. Integrar na principal
somente apos revisao e validacao. Branches de integracao EAP 7.4 e de lote pertencem
ao fluxo da aplicacao e nao recebem desenvolvimento direto do harness.

Nos exemplos deste repositorio, harness e aplicacao compartilham a raiz Git.
Depois de integrar a evolucao do harness na principal, alinhar explicitamente
a branch EAP 7.4; qualquer mudanca de HEAD exige reconciliar contextos/evidencias.
Com frentes simultaneas, usar checkouts isolados. Em aplicacoes com repositorio
proprio, a entrega do harness nao autoriza alterar as branches da aplicacao.

### Ciclo progressivo da migracao

O ciclo pertence ao projeto/repositorio e a frente de trabalho identificados.
A [ADR-0003](0003-projeto-branch-e-concorrencia-da-migracao.md) define a identidade
Git, verificacao de branch e HEAD, alinhamento com a principal e corretivas paralelas.
Um lote ativo e por frente, nao um bloqueio global a outros desenvolvedores.

1. Partir da rodada MTA selecionada e de evidencia identificada da aplicacao.
   Fazer triagem delimitada para identificar um lote consistente, com objetivo,
   transformacao, dependencias, criterios de aceite e reversao comuns. Mesma regra
   MTA, por si so, nao basta para agrupar ocorrencias.
2. Classificar e planejar apenas esse lote ativo. Persistir proposta e tarefas nos
   destinos do contexto; registrar cobertura analisada e NAO ANALISADO. Outras
   familias podem ser citadas como candidatas, sem identifica-las exaustivamente
   nem antecipar seus planos e checklists.
3. Submeter o plano, a rota, as pendencias e o escopo a revisao humana. Registrar
   a decisao e a autorizacao explicita do lote. Gravar documentos ou ter acesso
   a ferramentas nao constitui autorizacao para aplicar corretivas.
4. Em etapa de execucao autorizada, o agente de migracao aplica somente a corretiva
   do lote no checkout da aplicacao, atualiza suas tarefas com evidencias e executa
   as verificacoes previstas. Para OpenRewrite, preservar testes da receita,
   dryRun, revisao do patch e GO antes do run. Mudanca de escopo volta a revisao.
5. Conferir build Java 8, testes, dependencias/artefato, MTA comparavel, Sonar e
   validacao funcional no EAP 7.4 conforme os criterios do lote. Registrar resultados,
   falhas e verificacoes pendentes; ausencia de evidencia nao equivale a aprovacao.
   Submeter o resultado e as pendencias a nova revisao humana para aceite ou retrabalho.
6. Apos as verificacoes e o aceite humano, mediante pedido de continuidade, usar
   o novo MTA e o planejamento anterior selecionados pelo desenvolvedor. Reconciliar
   ocorrencias persistentes, novas, nao reencontradas e inconclusivas antes de
   identificar e planejar o proximo lote. Preservar identidade e historico; nao
   sobrescrever a rodada anterior. Pendencia impeditiva mantem o lote em retrabalho.

Repetir esse ciclo ate concluir todas as corretivas do escopo de migracao. A
conclusao exige reconciliacao da cobertura acumulada com a rodada final comparavel,
sem ocorrencias ou verificacoes pendentes no escopo, e aceite humano final. Nao
declarar conclusao global por amostragem, por terminar um lote ou pelo desaparecimento
de achados. Falsos positivos e itens nao aplicaveis exigem justificativa rastreavel
e revisao humana; nao devem ser contabilizados como corretivas aplicadas.

### Limites e guardrails

O prompt `planejar-lotes` implementa a etapa de proposta e persistencia, com escrita
somente em PlanPath/TodoPath. A execucao autorizada e outra etapa, com ferramentas
e escopo proprios; este ADR nao habilita terminal ou alteracao da aplicacao dentro
do prompt de planejamento. GO de um lote nao aprova seu resultado nem o proximo lote.

As verificacoes automaticas produzem evidencias; as revisoes humanas aprovam escopo
e resultado. Uma nao substitui a outra. O harness atual prepara contexto e valida
identidades/integridade; nao implementa nem comprova sozinho todo esse ciclo.
Limites de escrita do prompt sao instrucoes, nao uma sandbox tecnica por pasta.

## Alternativas e consequencias

Um plano/to-do compartilhado misturaria manutencao do ambiente e corretivas,
dificultando rastrear autorizacoes. Planejar todo o MTA antecipadamente aumentaria
o custo de revisao e retrabalho a cada rodada. Ambos foram rejeitados.

O planejamento progressivo reduz esse custo, mas exige registrar cobertura parcial,
resultados e vinculos entre rodadas para nao perder pendencias. Os dois pontos de
revisao humana por lote impedem tratar sucesso tecnico como aceite automatico.

Esta decisao complementa a [ADR-0001](0001-contexto-copilot.md). O contrato de
preparacao esta na [especificacao](../especificacoes/planejamento-copilot.md), e
as instrucoes operacionais estao no [prompt](../../.github/prompts/planejar-lotes.prompt.md).
