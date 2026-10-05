# Escopo do Copilot

Siga [AGENTS.md](../AGENTS.md) e a
[ADR-0002](../doc/adr/0002-separacao-harness-e-migracao-progressiva.md).

Evolucao do harness (incluindo prompts e Run Tasks) usa `tasks/plan.md` e
`tasks/todo.md`. Migracao da aplicacao usa exclusivamente os destinos PlanPath e
TodoPath do contexto para seus planos/tarefas. Nao misture esses trabalhos.

Para alterar o harness, use branch propria `harness/<objetivo>` a partir da sua
principal. Nao escreva evolucoes do harness diretamente na principal, na branch
EAP 7.4 ou na branch do lote. Confira o checkout antes de editar; com migracao
em andamento, use checkout isolado. Integre mudancas revisadas/validadas na
principal e alinhe a migracao separadamente, conforme AGENTS.md.

Planeje somente um lote consistente por vez. O ciclo e proposta, revisao/GO humano,
execucao autorizada, verificacoes automaticas e revisao/aceite humano do resultado.
Depois, com aceite e pedido de continuidade, reconcilie as evidencias disponiveis;
comparacao com novo MTA fica pendente se nao houver rodada. Nao declarar conclusao
global sem evidencia. O prompt de planejamento nao autoriza executar corretivas.

Pre-planejamento opcional priorizar-issues compara os projetos explicitamente
incluidos no contexto e examina uma fatia de 0,01%..100,00% sobre o total inicial
fixo, recomendando por risco/repetibilidade/alcance. Com historico, perguntar
recriar/progredir; progresso exclui todos os IDs examinados na sequencia,
com ou sem proposta. Toda examinada tem linha com posicao ou motivo e ficha
de evidencias/referencias/roteiro para continuidade manual pelo desenvolvedor.
Escreve apenas RankingPath sob .harness/priorizacao; nao escolhe pelo humano,
nao altera registros nem planeja lotes. Escolha humana precede o planejamento usual.
Helpers explicam/revisam a lista no chat; executar o prompt e etapa separada.

Siga a [ADR-0005](../doc/adr/0005-planejamento-orientado-pelo-registro.md).
Planejamento: planejar cria, retoma ou atualiza a proposta pelo registro existente;
nao exigir menu de operacao ou selecao repetida de projeto/rodada. Sem registro,
orientar Workspace: atualizar indice dos projetos. Indice localiza, registro atual
concentra escolha/recorte/evidencias; ranking antigo nao revoga escolha atual.
PlanningBasis=MTA|EVIDENCIAS permite proposta por evidencias humanas sem fabricar
MTA. Conferir integridade da base real. Origem/evidencias/contrato/template iguais
retomam a solicitacao; mudancas nessas entradas geram recibo com Previous. Escolhas
e observacoes atuais sao lidas sem reescrever historico. Link antigo segue Previous
ate o unico sucessor; bifurcacao pede escolha. Nao escolher plano/rodada por recencia.
Reconciliar so por motivo concreto; PENDENTE historico nao e gate generico.
Perguntas essenciais antecedem a proposta completa, sem par ficticio plan/to-do.
Helpers continuam leitores e orientam uma etapa com caminho pronto no Copilot;
execucao usa DevSquad compativel. GO vigente no mesmo escopo nao e pedido novamente.

Siga o [contrato vigente](../doc/especificacoes/planejamento-copilot.md): decisoes
Java 8/javax/EAP 7.4 e Hibernate permanecem. planejar-lotes atende proposta e revisao.
MigrationPath explicito permite somente andamento/cobertura/referencias das issues
trabalhadas, preservando escolhas humanas e catalogo. manter-migracao grava apenas
esse registro; nao concede GO/aceite nem inicia planejamento automaticamente.

Siga a [ADR-0004](../doc/adr/0004-git-informativo-sem-controle-de-branches.md):
o desenvolvedor escolhe a branch. Git e informativo, sem cadastro de politica,
responsavel ou coordenacao e sem bloqueio automatico por branch/HEAD/estado local.
Nao exigir novo contexto apenas por essas diferencas. Preserve identidade do
projeto, hashes MTA e destinos; avalie conteudo relevante para aplicar os achados.
Os controles Git antigos da ADR-0003 foram substituidos. Nao renovar suas
pendencias em propostas novas. Gestao de branches fica com o desenvolvedor;
GO de corretivas, verificacoes tecnicas e aceite humano permanecem separados.

Para executar a corretiva, use implementar-lote com o prompt preparado pela tarefa
Aplicacao: preparar implementacao do lote. Confira o GO humano vigente e o par
PlanPath/TodoPath antes de delegar ao devsquad.implement. A preparacao nao concede
GO; a execucao autorizada limita-se ao lote e nao concede aceite nem autoriza
commit/push/PR, escrita no harness ou tarefas de outro lote.

<!-- mermaid-ai-skills:start -->
## Mermaid Diagrams

When the user asks to create, edit, or visualize a diagram, follow the
instructions in `.github/instructions/mermaid.instructions.md`.
<!-- mermaid-ai-skills:end -->
