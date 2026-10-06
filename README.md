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
apoio do Codex ou GitHub Copilot/DevSquad e controle do desenvolvedor.

O harness conecta ferramentas de analise e execucao — MTA, Maven, SonarQube e
JBoss — a contexto, prompts e evidencias. A proposta e transformar achados em
lotes de corretivas que possam ser revisados, implementados e verificados,
mantendo prioridades, cobertura e pendencias visiveis. O desenvolvedor define
o escopo, autoriza a implementacao e aceita o resultado.

A base atual atende a migracao de **JBoss EAP 7.1 para EAP 7.4, preservando
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
A [estrategia do harness](doc/estrategia/estrategia-harness_.md) distingue
as capacidades existentes das propostas e seus criterios de avanco.

O [catalogo de dominios e capacidades](doc/features/evolucao-harness-dominios-capacidades-priorizacao.md)
detalha propostas futuras. A [conciliacao com o backlog](doc/estrategia/conciliacao-evolucao-harness.md)
identifica sobreposicoes, entregas ja atendidas e pendencias preservadas;
prazo, prioridade e piloto permanecem a definir.

## Como usar

**Siga o [guia do desenvolvedor](doc/guias/harness-migracao-desenvolvedor.md).**
Ele explica a primeira configuracao e conduz o fluxo completo, da analise ao
planejamento, implementacao, verificacao, aceite e reconciliacao. Em cada etapa,
indica o guia de ferramenta adequado para os comandos, opcoes e caminhos de
retomada.

**O agente de orientacao e opcional.** Para trabalhar sem helper, use as Run Tasks
e a secao **Uso** do guia de cada etapa. Na priorizacao, a tarefa prepara o prompt;
voce pode executa-lo diretamente no Codex/Copilot para produzir o relatorio.
Escolha a categoria na priorizacao: mandatory, optional, potential ou outra recebida,
com continuidade independente. Depois, siga as [fichas e o caminho manual](doc/guias/tools/priorizacao-issues.md#planejar-e-implementar-manualmente-a-partir-da-priorizacao)
para investigar, planejar e implementar, com as mesmas revisoes e verificacoes.
Quem ja sabe o que corrigir pode escolher a issue no registro e ir direto a Planejar.

Para comecar com orientacao, siga o [guia de orientacao da migracao com Codex ou GitHub Copilot](doc/guias/orientacao-migracao.md)
e diga apenas o objetivo, por exemplo: "Quero priorizar as issues mandatory dos
projetos deste workspace". O guia explica `orientar-migracao`, `migracao_helper`,
retomada e passagem a execucao; cada guia de etapa oferece pedidos de exemplo e
o resultado esperado. O helper confere a situacao e conduz uma etapa por vez.

O [pre-planejamento opcional](doc/guias/tools/priorizacao-issues.md) examina uma
fatia de **0,01% a 100,00%** das issues elegiveis sobre o total inicial fixo.
Com uma priorizacao existente, escolha recriar ou progredir; o avanco exclui as
issues ja examinadas na sequencia, com ou sem recomendacao. Cada issue examinada
recebe evidencias, referencias e roteiro para continuidade manual. Depois voce
escolhe o recorte para planejar.

No planejamento, a entrada e **Planejamento: planejar**: usa a escolha e as
evidencias do registro para criar ou atualizar a proposta. Se faltar registro,
**Workspace: atualizar indice dos projetos** o prepara. Nao e necessario repetir
projeto, rodada e escolhas em menus sucessivos. Evidencias suficientes permitem
planejar sem pacote MTA completo; duvidas essenciais sao esclarecidas antes de
concluir o plano. Veja [entradas e resultados](doc/guias/tools/planejamento-migracao.md#preparar-e-executar-o-prompt).

Para contribuir com a evolucao do harness, consulte [AGENTS.md](AGENTS.md) e as
[decisoes arquiteturais](doc/adr/). O [contrato de planejamento](doc/especificacoes/planejamento-copilot.md)
define os limites do trabalho assistido e os registros de cada etapa.

## Licenca

Distribuido sob a [licenca MIT](LICENSE). Copyright (c) 2026 Edoardo Bianco.
