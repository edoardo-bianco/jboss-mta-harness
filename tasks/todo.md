# To-do do agente: evolucao do harness

## Estado JBoss corrente - 17/10/2026

[Escopo e decisoes](plan.md#estado-jboss-corrente---17102026).

- [x] Servidor em `.harness/servidores/<eap>/` com somente a ultima operacao e o ultimo start.
- [x] Deploy substitui o WAR (gerenciado, externo ou nao gerenciado) e guarda somente `atual/jboss/<eap>/ultimo-deploy.json`.
- [x] Retirar rollback: Run Task, acao, `-ReleaseId`, funcoes e testes.
- [x] Indice do projeto e `operacao.json` mostram o ultimo deploy.
- [x] Guias, cheat sheet, AGENTS.md e documentos do Engineering Harness atualizados.
- [x] Suites JBoss, Run Tasks, navegacao, armazenamento e build: PASS (runner isolado; ensaio real opt-in nao executado).
- [ ] Ensaio real na maquina de trabalho: start, deploy v1/v2/v1 com HTTP e stop (`Test-JbossReal.ps1 -RunReal`).
- [x] Pasta legada `.harness/jboss/` removida nesta maquina a pedido do desenvolvedor (recibos, logs e 4 copias de WAR; 298 KB).
- [ ] Revisao humana e aceite.

## Consolidacao documental do Engineering Harness - 17/10/2026

[Escopo e decisoes](plan.md#consolidacao-documental-do-engineering-harness---17102026).

- [x] Criar `doc/contratos/` (fluxo-migracao, planejamento-sprints com regras de cronograma, consultas-issues).
- [x] Criar `doc/engineering-harness/` com os tres documentos e imagens (imagem com nome em hash renomeada).
- [x] Corrigir a situacao real da `main` (`5c8d582`) e incorporar decisoes de 17/10/2026.
- [x] Incorporar o material reaproveitado (fundamentos, horizontes, catalogo no anexo A, estudo Java).
- [x] Mover cheat sheet para `doc/guias/` e conversor para `tools/transicao/README.md`.
- [x] Remover `doc/arquitetura/`, `doc/especificacoes/`, `doc/features/` e `doc/estrategia/`.
- [x] Reapontar consumidores: AGENTS.md, instrucoes, skill, prompts, scripts, testes, guias, ADRs e README.
- [x] Verificar links: 60 arquivos, somente os dois links-modelo do template de sprints (destino gerado).
- [x] Suites afetadas pelo runner isolado: 11 PASS; `Test-IssueQueries.ps1` FAIL, falha preexistente na `main` `5c8d582` (conferida em worktree separado).
- [ ] Revisao humana e aceite da consolidacao.
- [ ] Corretiva separada: `Test-IssueQueries.ps1` falha em "Truncamento silencioso ou ausente." (mensagem de incidente esperada com 128 caracteres e um campo truncado).
- [x] Incremento seguinte: armazenamento JBoss por projeto/servidor (ver secao "Estado JBoss corrente").
