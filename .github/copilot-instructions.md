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
Depois, com pedido de continuidade, reconcilie o novo MTA com o historico antes de
identificar o proximo lote. Mantenha cobertura pendente ate a conclusao verificada
de todo o escopo. O prompt de planejamento nao autoriza executar corretivas.

Siga a [ADR-0003](../doc/adr/0003-projeto-branch-e-concorrencia-da-migracao.md):
o ciclo pertence ao projeto/repositorio selecionado e a branch de trabalho
autorizada para sua migracao. Confira branch, HEAD e alteracoes locais antes de
executar/retomar; mudancas exigem reconciliacao. Um lote ativo por frente permite
outras frentes coordenadas, com integracao na branch de migracao e alinhamento
com a principal. Revalide o resultado integrado. O prompt sem terminal registra
dados Git fornecidos ou PENDENTE; nao pode afirmar uma verificacao nao realizada.
