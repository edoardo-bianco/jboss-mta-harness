# To-do do agente: evolucao do harness

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
- [ ] Incremento seguinte (branch propria): armazenamento JBoss por projeto/servidor, sem GUID/hash; somente o ultimo; deploy sempre substitui o WAR; retirar rollback.
