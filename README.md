# JBoss MTA Harness

Harness para executar build Maven Java 8 e analise MTA pelo VS Code, consultar
relatorios e preparar propostas de corretivas com GitHub Copilot e DevSquad.
O perfil atual e EAP 7.1 → EAP 7.4, preservando Java 8 e `javax.*`.

## Comecar

1. Abra `iniciar-harness.code-workspace` no VS Code.
2. Execute **Workspace: configurar caminhos**, preencha o JSON local e salve.
3. Execute **Workspace: gerar workspace** e abra `jboss-mta-harness.local.code-workspace`.
4. Siga o roteiro abaixo; consulte o **[guia do desenvolvedor](doc/guias/harness-migracao-desenvolvedor.md)** para requisitos e detalhes operacionais.

O guia explica os requisitos, a escolha de projeto e branches, cada menu das
Run Tasks, a consulta de resultados e a limpeza para repetir o ensaio.
Se o workspace local ja existe, abra-o diretamente.

## Passo a passo pelo VS Code

Use **Terminal > Run Task**, com as tarefas da pasta `harness`, e selecione o
mesmo projeto no build, no MTA e no planejamento. Para o primeiro ensaio, use
`migracao-cache-antes`. A branch de trabalho e escolha do desenvolvedor;
nao ha cadastro ou bloqueio Git no harness.

1. **Limpeza opcional, para recomecar:** execute **Workspace: limpar execucoes**,
   escolha um projeto ou todos, confira os caminhos e confirme com `LIMPAR`.
   Isso apaga resultados, prompts, planos e to-dos anteriores; preserva fontes,
   configuracoes e Git. [Escopo e opcoes da limpeza](doc/guias/harness-migracao-desenvolvedor.md#limpar-execucoes-para-repetir-o-ensaio).
2. **Build:** execute **Aplicacao: build Maven (Java 8)**, escolha `clean install`
   e aguarde sucesso antes de seguir. [Build e escolha do modulo](doc/guias/harness-migracao-desenvolvedor.md#build-maven-da-aplicacao-com-java-8).
3. **MTA:** execute **MTA: executar analise**. Aguarde `Status: SUCCEEDED`,
   `ExitCode: 0` e integridade confirmada; consulte **MTA: abrir ultimo relatorio**.
   [Analise e resultados](doc/guias/harness-migracao-desenvolvedor.md#analise-e-resultados).
4. **Preparar contexto:** execute **Planejamento: preparar contexto para Copilot**
   e selecione a rodada desejada. Para recomecar do zero, nao vincule planejamento
   anterior; para continuar, selecione a proposta existente.
   [Menus e continuidade](doc/guias/harness-migracao-desenvolvedor.md#planejar-lotes-de-correcao-com-copilot).
5. **Executar o prompt:** confira o contexto no fim de `planejar-lotes.prompt.md`
   e use **Executar Prompt** em uma nova conversa **Copilot Local**, com `devsquad`.
   Preparar o arquivo nao aciona o agente. [Ferramentas e delegacao](doc/guias/harness-migracao-desenvolvedor.md#planejar-lotes-de-correcao-com-copilot).
6. **Revisar:** aguarde a gravacao e releitura de `plan.md` e `todo.md`; use
   **Planejamento: abrir plano e to-do**. Confira o unico lote proposto e suas
   pendencias. A proposta nao autoriza aplicar corretivas: essa etapa exige seu GO.
   [Revisao e documentos](doc/guias/harness-migracao-desenvolvedor.md#planejar-lotes-de-correcao-com-copilot).

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
