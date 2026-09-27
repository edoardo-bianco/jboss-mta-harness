# JBoss MTA Harness

Harness para executar build Maven Java 8 e analise MTA pelo VS Code, consultar
relatorios e preparar propostas de corretivas com GitHub Copilot e DevSquad.
O perfil atual e EAP 7.1 → EAP 7.4, preservando Java 8 e `javax.*`.

## Comecar

1. Abra `iniciar-harness.code-workspace` no VS Code.
2. Execute **Workspace: configurar caminhos**, preencha o JSON local e salve.
3. Execute **Workspace: gerar workspace** e abra `jboss-mta-harness.local.code-workspace`.
4. Siga o **[guia do desenvolvedor](doc/guias/harness-migracao-desenvolvedor.md)**.

O guia explica os requisitos, a escolha de projeto e branches, cada menu das
Run Tasks, a consulta de resultados e a limpeza para repetir o ensaio.
Se o workspace local ja existe, abra-o diretamente.

## Fluxo

Build → MTA → proposta de um lote → revisao/GO humano → correcao autorizada →
verificacoes → revisao/aceite humano → novo MTA e reconciliacao → proximo lote.

O agente de planejamento grava somente `plan.md` e `todo.md` do lote.
Sonar, deploy e controle do servidor sao evolucoes futuras do harness.

## Referencias

- [Guia: passo a passo e escolhas](doc/guias/harness-migracao-desenvolvedor.md)
- [Decisoes arquiteturais](doc/adr/) e [contratos do harness](doc/especificacoes/)
- [Evolucoes](doc/features/) e [tarefas do harness](tasks/todo.md)
- [Instrucoes para agentes](AGENTS.md)
- [Como testar os scripts](doc/guias/harness-migracao-desenvolvedor.md#testar-os-scripts-do-harness)

Configuracao local, workspace gerado e artefatos de execucao em `.harness/`
nao sao versionados. Os dois projetos de demonstracao acompanham o clone.
