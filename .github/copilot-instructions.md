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

Siga a [ADR-0004](../doc/adr/0004-git-informativo-sem-controle-de-branches.md):
o desenvolvedor escolhe a branch. Git e informativo, sem cadastro de politica,
responsavel ou coordenacao e sem bloqueio automatico por branch/HEAD/estado local.
Nao exigir novo contexto apenas por essas diferencas. Preserve identidade do
projeto, hashes MTA e destinos; avalie conteudo relevante para aplicar os achados.
Os controles Git antigos da ADR-0003 foram substituidos. Nao renovar suas
pendencias em propostas novas. Gestao de branches fica com o desenvolvedor;
GO de corretivas, verificacoes tecnicas e aceite humano permanecem separados.
