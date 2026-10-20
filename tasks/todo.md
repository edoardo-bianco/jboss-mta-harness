# To-do do agente: evolucao do harness

## Conversao de associacao legada sem plano - 20/10/2026

[Escopo](plan.md#conversao-de-associacao-legada-sem-plano---20102026).

- [x] Reproduzir o caso informado em fixture isolada antes da corretiva.
- [x] Validar associacao legada e distinguir ausencia de plano de vinculo quebrado.
- [x] Conferir preservacao, repeticao e descarte explicito, incluindo outro projeto com plano.
- [x] Reproduzir e corrigir classificacao duplicada das copias MTA declaradas nos anexos.
- [x] Bloquear publicacao com origem corrompida; nao declarar ausencia de plano por falha de leitura.
- [x] Executar suites de conversao, revisar diff e documentar o resultado.
- [ ] Revisao humana e integracao na principal.

**Verificacao em 20/10/2026:** 29 suites `Test-Conversion*.ps1` aprovadas em
Windows PowerShell 5.1 pelo runner isolado. Na rodada final, 26 passaram e tres
atingiram o limite de caminho na raiz temporaria padrao; essas tres
(`EvidenceScopes`, `MultiProject`, `SharedEvidence`) passaram ao repetir com
TMP e TEMP apontando para `C:\Temp` apenas no processo. Uma primeira rodada
tambem detectou a mudanca da mensagem de ambiguidade; a mensagem compativel
foi preservada e `ParticipantMta` passou na rodada final.

As novas fixtures falharam antes das respectivas correcoes. Mutacao que
desabilitou a validacao de Source foi detectada pelo teste e revertida.
Revisao independente da associacao, falhas de leitura, publicacao/descarte
e copias MTA terminou sem achados pendentes; `git diff --check` passou.
Nenhum dado real de aplicacao foi convertido ou removido. Na maquina de
trabalho, a origem declarada no contexto SIMTR-api e as escolhas de
planejamento/diagnosticos/priorizacao/sprints ainda precisam ser conferidas.

## Consistencia documental e agentes principais - 19/10/2026

[Escopo e decisao](plan.md#consistencia-documental-e-agentes-principais---19102026).

- [x] Corrigir os seis achados e os ajustes editoriais nos tres documentos.
- [x] Alinhar Codex e GitHub Copilot como principais; Claude Code secundario.
- [x] Conferir links/ancoras, sintaxe/preservacao dos exemplos JSON, diagrama e diff.
- [ ] Revisao humana e integracao na principal.

**Verificacao em 19/10/2026:** 106 referencias locais nos tres documentos e 27
referencias recebidas de outros Markdown versionados, sem arquivos/ancoras
ausentes. Links dos dois arquivos tasks tambem conferidos. Cinco blocos JSON
validos e identicos a baseline `6566bb8`; cercas balanceadas e fluxo Mermaid
revisado por leitura. Catalogo: 47 URLs externas distintas, sendo sete do
repositorio e 40 fontes oficiais/primarias. `git diff --check`: PASS.

**Limites:** testes de runtime nao executados nesta alteracao documental.
Validacao JSON Schema original mantida como historica; nao repetida porque
`jsonschema` nao esta instalado. Ajuda local `codex exec --help` bloqueada pela
politica de scripts; interface conferida na fonte oficial O13, sem alterar a
politica da maquina ou declarar o piloto homologado.

## Adaptador Claude Code - 17/10/2026

[Escopo](plan.md#adaptador-claude-code---17102026).

- [x] Seis helpers em `.claude/agents/` com perfil leitor e delegacao restrita ao condutor.
- [x] Ponteiro `.claude/skills/orientar-migracao/SKILL.md` (descoberta confirmada nesta sessao do Claude Code).
- [x] Skill comum e papeis com encaminhamento Claude Code.
- [x] Configurador MCP grava `.mcp.json`; `.gitignore` e copias de teste atualizados.
- [x] Guias, README e documento 1 atualizados.
- [x] `Test-ClaudeAdapter`, `Test-CurrentPromptLinks`, `Test-Implementation`, `Test-TestIsolation`: PASS. Node: 10/10 em checkout separado.
- [ ] `integration.test.mjs` nao executado: caminho do checkout temporario excedeu o limite do harness; repetir em raiz curta.
- [ ] Ensaio nativo: `claude --agent migracao_helper`, delegacao a um helper, `/orientar-migracao` e consultas MCP aprovadas em `/mcp`.
- [ ] Revisao humana e aceite.

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
