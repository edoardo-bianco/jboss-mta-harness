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
apoio do GitHub Copilot/DevSquad e controle do desenvolvedor.

O harness conecta ferramentas de analise e execucao — MTA, Maven, SonarQube e
JBoss — a contexto, prompts e evidencias. A proposta e transformar achados em
lotes de corretivas que possam ser revisados, implementados e verificados,
mantendo prioridades, cobertura e pendencias visiveis. O desenvolvedor define
o escopo, autoriza a implementacao e aceita o resultado.

A base atual atende a migracao de **JBoss EAP 7.1 para EAP 7.4, preservando
Java 8 e `javax.*`**. O repositorio inclui scripts, tarefas, configuracao,
prompts e dois projetos de demonstracao para ensaiar o processo. O mesmo
ambiente pode trabalhar com repositorios corporativos mantidos separadamente.

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
A [estrategia do harness](doc/estrategia/estrategia-harness_.md) distingue
as capacidades existentes das propostas e seus criterios de avanco.

## Como usar

**Siga o [guia do desenvolvedor](doc/guias/harness-migracao-desenvolvedor.md).**
Ele explica a primeira configuracao e conduz o fluxo completo, da analise ao
planejamento, implementacao, verificacao, aceite e reconciliacao. Em cada etapa,
indica o guia de ferramenta adequado para os comandos, opcoes e caminhos de
retomada.

Para contribuir com a evolucao do harness, consulte [AGENTS.md](AGENTS.md) e as
[decisoes arquiteturais](doc/adr/). O [contrato de planejamento](doc/especificacoes/planejamento-copilot.md)
define os limites do trabalho assistido e os registros de cada etapa.
