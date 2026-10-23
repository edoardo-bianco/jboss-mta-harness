---
html:
  embed_local_images: true
  embed_svg: true
  offline: true
---

# JBoss MTA Harness

Migrar uma aplicacao exige relacionar diagnosticos com o codigo, escolher o que
corrigir, verificar o resultado e preservar as decisoes entre uma rodada e outra.
O **JBoss MTA Harness** organiza esse trabalho em um ambiente no VS Code, com
apoio do Claude Code, Codex ou GitHub Copilot/DevSquad e controle do desenvolvedor.

O harness conecta ferramentas de analise e execucao — MTA, Maven, SonarQube e
JBoss — a contexto, prompts e evidencias. A proposta e transformar achados em
lotes de corretivas que possam ser revisados, implementados e verificados,
mantendo prioridades, cobertura e pendencias visiveis. O desenvolvedor define
o escopo, autoriza a implementacao e aceita o resultado.

A base atual atende a migracao de **JBoss EAP 7.0 ou 7.1 para EAP 7.4, preservando
Java 8 e `javax.*`**. O repositorio inclui scripts, tarefas, configuracao,
prompts e guias. Aplicacoes, incluindo playgrounds de ensaio, ficam em pastas
externas ao harness. O workspace inicial contem somente o harness; adicione os
projetos desejados com **File > Add Folder to Workspace...** e salve o workspace local.

## Direcao estrategica

A estrategia combina contexto preparado antes da atuacao da IA (**feedforward**)
com resultados de verificacoes que orientam a proxima decisao (**feedback**).
O conhecimento fica nos artefatos do projeto: diagnosticos, planos, decisoes,
testes e evidencias. O objetivo e reduzir perda de contexto e retrabalho,
preservando os fundamentos da engenharia e a responsabilidade humana.

A evolucao proposta e aproveitar essa base em outras tecnologias e etapas do
ciclo de desenvolvimento, incluindo modernizacao. Um nucleo comum, plugins
tecnologicos e adaptadores de IA e IDE sao o caminho estudado; Quarkus, IntelliJ
e engines alternativos dependem de implementacao e pilotos.
A [estrategia do harness](doc/engineering-harness/01-estrategia-e-arquitetura.md) distingue
as capacidades existentes das propostas e seus criterios de avanco.

O [catalogo de dominios e capacidades](doc/engineering-harness/03-plano-tatico-e-implementacao.md#anexo-a)
detalha propostas futuras. A [conciliacao com o backlog](doc/engineering-harness/03-plano-tatico-e-implementacao.md)
identifica sobreposicoes, entregas ja atendidas e pendencias preservadas;
as prioridades relativas e pilotos posteriores permanecem a definir.

**Prioridade definida em 10/10/2026:** concluir a
[simplificacao por projeto](doc/engineering-harness/02-system-design.md#estado-local)
antes da modernizacao e de novas funcionalidades. O objetivo e retirar recibos e
rastreamentos por execucao, usar caminhos fixos e oferecer links diretos das fichas
para suas fontes. A entrega inclui limpeza e alinhamento dos guias e do orientador.
O [plano de viabilidade](tasks/historico/plan-ate-2026-10-17.md#simplificacao-prioritaria-por-projeto---2026-10-10)
registra a implementacao tecnica por etapas. O fluxo corrente ja usa esses caminhos;
regressao integrada e aceite humano sao acompanhados separadamente no
[checklist](tasks/historico/todo-ate-2026-10-17.md#simplificacao-prioritaria-por-projeto---2026-10-10).
Em 20/10/2026, por escolha do desenvolvedor, o conversor legado foi retirado.
Para iniciar com relatorios MTA existentes, configure a raiz externa e execute
**Workspace: atualizar indice dos projetos**, conforme o
[guia MTA](doc/guias/tools/mta.md#origem-mta-e-caminhos).
Nenhum dado real foi convertido ou limpo nesta entrega.

A [arquitetura do Engineering Harness](doc/engineering-harness/01-estrategia-e-arquitetura.md)
consolida a base implementada e propoe a evolucao por nucleo, perfis e capacidades,
com matriz das Run Tasks, escolha de plataforma e indexacao Java independente de IDE.
As novas decisoes estao em revisao na [ADR-0008](doc/adr/0008-nucleo-perfis-e-plataforma-do-harness.md).

## Como usar

**Siga o [guia do desenvolvedor](doc/guias/harness-migracao-desenvolvedor.md).**
Ele conduz da configuracao ao aceite. Os guias de etapa concentram comandos,
opcoes e caminhos de retomada; voce pode entrar na etapa em que esta.

| Sua situacao | Primeiro passo |
| --- | --- |
| Primeiro uso | Abra `iniciar-harness.code-workspace` e siga a [configuracao do workspace](doc/guias/tools/workspace.md#configuracao). Gere/salve o workspace local e adicione os projetos externos. |
| Quero o harness na minha conta GitHub da empresa | Siga o [guia de fork e atualizacao](doc/guias/tools/github-empresa.md): terminal com gh/Git ou navegador e Git, preservando as aplicacoes no Azure Repos. |
| Preparar minha maquina ou as dos colegas | Siga o [roteiro por maquina](doc/guias/tools/workspace.md#preparar-as-maquinas-dos-colegas), que encaminha ao certificado Sonar e ao Node/MCP opcional; o helper usa essas mesmas fontes. |
| Quero escolher o que corrigir | Confira o registro e use a [priorizacao opcional por categoria](doc/guias/tools/priorizacao-issues.md). |
| Ja escolhi uma issue | Use **Planejamento: planejar**, a partir da escolha e das evidencias no registro. |
| Quero prever a migracao por sprints, equipe e prazo | Use **Planejamento: planejar sprints**, conforme o [guia de planejamento macro](doc/guias/tools/planejamento-sprints.md); inclui todos os projetos ou um subconjunto. |
| Quero conferir uma base ou consultar uma issue preparada | Peca ao helper a [consulta da base ou da issue](doc/guias/tools/consultas-issues.md#consultar-pelo-helper), indicando o contexto se ainda nao estiver identificado. |
| Quero adotar um novo MTA, local ou recebido | Use **Planejamento: atualizar registro de migracao**, conforme o [guia de adocao e comparacao](doc/guias/tools/planejamento-migracao.md#reconstruir-a-pasta-usando-um-mta-existente). |
| Recebi arquivos de analise ou plano de um colega | Siga o [guia de copia](doc/guias/tools/compartilhamento-contextos.md): associar o POM local, preservar contribuicoes e reconciliar. |
| Quero navegar nas evidencias | Abra `.harness/indices/projetos.md` e o indice do projeto; [roteiro de navegacao](doc/guias/tools/workspace.md#navegar-pelas-evidencias-do-projeto). |
| Quero baixar o Sonar da pipeline | Use **Aplicacao: analisar SonarQube > 3 Baixar ultima analise concluida**; [origem e limites](doc/guias/tools/sonar.md#baixar-a-ultima-analise-concluida). |
| Quero migrar/configurar o JBoss EAP 7.4 | Consulte o [guia de migracao da configuracao](doc/guias/tools/migracao-configuracao-jboss.md) e o [guia de operacao](doc/guias/tools/jboss.md). |
| Quero ajuda para retomar | Use `$orientar-migracao` no Codex ou `migracao_helper` no Copilot, conforme o [guia de orientacao](doc/guias/orientacao-migracao.md). |

**O agente de orientacao e opcional e permanece leitor.** Ele confere os arquivos
e indica uma proxima acao. As tarefas de priorizacao e planejamento preparam
contexto; elaborar ranking/fichas ou plano/to-do e outra etapa, manual ou pela
execucao do prompt no Claude Code, Codex ou Copilot.
Com plano revisado e GO, outro colega pode implementar manualmente ou com agente.
Testes e revisao humana do resultado continuam necessarios nas duas formas.

As consultas MCP sao opcionais: quando configuradas e disponiveis, os agentes as
usam para recuperar a base e os incidentes. Sem MCP, priorizacao e planejamento
continuam pela leitura dos arquivos, sem exigir consulta manual ou JSON copiado.
Node >=20 e npm sao necessarios somente para ativar MCP; veja o [guia de consultas](doc/guias/tools/consultas-issues.md).

O [pre-planejamento opcional](doc/guias/tools/priorizacao-issues.md) separa as
categorias `mandatory`, `optional`, `potential` e outras recebidas. Examina uma
fatia de **0,01% a 100,00%** das issues elegiveis sobre o total inicial fixo.
Com uma priorizacao existente, escolha recriar ou progredir; o avanco exclui as
issues ja examinadas naquela categoria/escopo, com ou sem recomendacao. Cada uma
recebe ficha de evidencias, referencias e roteiro; o ranking resume a comparacao.
Depois voce escolhe a issue e seu recorte para planejar.

No planejamento, a entrada e **Planejamento: planejar**: usa a escolha e as
evidencias do registro para criar ou atualizar a proposta. Sem trabalho recebido,
se faltar registro, **Workspace: atualizar indice dos projetos** o prepara. Nao e
necessario repetir projeto, rodada e escolhas em menus sucessivos. Evidencias suficientes permitem
planejar sem pacote MTA completo; duvidas essenciais sao esclarecidas antes de
concluir o plano, sem trocar silenciosamente uma base MTA ja declarada.
Plano e tarefas ficam em `atual/planejamento/` na pasta do `artifactId` Maven.
Cada issue tem [ficha e referencias](doc/guias/tools/planejamento-migracao.md#dossie-por-issue-e-passagem-entre-colegas).
Plano recebido exige associacao/reconciliacao, conferencia local e revisao do GO;
copia nao autoriza execucao. Origem ausente fica explicita, sem afirmar equivalencia.
Voce pode escrever referencias em Markdown/chat indicando projeto, objetivo e
resultados correntes, sem IDs de execucao ou hashes. Os guias em `doc/` servem
como base local para busca/leitura do agente; RAG semantico nao esta implementado.

Para contribuir com a evolucao do harness, consulte [AGENTS.md](AGENTS.md) e as
[decisoes arquiteturais](doc/adr/). O [contrato de planejamento](doc/contratos/fluxo-migracao.md)
define os limites do trabalho assistido e os registros de cada etapa.

## Licenca

Distribuido sob a [licenca MIT](LICENSE). Copyright (c) 2026 Edoardo Bianco.
