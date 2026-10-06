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
Ele conduz da configuracao ao aceite. Os guias de etapa concentram comandos,
opcoes e caminhos de retomada; voce pode entrar na etapa em que esta.

| Sua situacao | Primeiro passo |
| --- | --- |
| Primeiro uso | Abra `iniciar-harness.code-workspace` e siga a [configuracao do workspace](doc/guias/tools/workspace.md#configuracao). Gere/salve o workspace local e adicione os projetos externos. |
| Quero escolher o que corrigir | Confira o registro e use a [priorizacao opcional por categoria](doc/guias/tools/priorizacao-issues.md). |
| Ja escolhi uma issue | Use **Planejamento: planejar**, a partir da escolha e das evidencias no registro. |
| Quero conferir uma base ou consultar uma issue preparada | Use a [CLI de consultas de issues](doc/guias/tools/consultas-issues.md), com ContextPath explicito e JSON paginado. |
| Recebi analise ou plano de um colega | Use **Planejamento: compartilhar contexto** e siga o [guia de importacao](doc/guias/tools/compartilhamento-contextos.md). |
| Quero ajuda para retomar | Use `$orientar-migracao` no Codex ou `migracao_helper` no Copilot, conforme o [guia de orientacao](doc/guias/orientacao-migracao.md). |

**O agente de orientacao e opcional e permanece leitor.** Ele confere os arquivos
e indica uma proxima acao. As tarefas de priorizacao e planejamento preparam
contexto; elaborar ranking/fichas ou plano/to-do e outra etapa, manual ou pela
execucao do prompt no Codex/Copilot.
Com plano revisado e GO, outro colega pode implementar manualmente ou com agente.
Testes e revisao humana do resultado continuam necessarios nas duas formas.

O [pre-planejamento opcional](doc/guias/tools/priorizacao-issues.md) separa as
categorias `mandatory`, `optional`, `potential` e outras recebidas. Examina uma
fatia de **0,01% a 100,00%** das issues elegiveis sobre o total inicial fixo.
Com uma priorizacao existente, escolha recriar ou progredir; o avanco exclui as
issues ja examinadas naquela categoria/escopo, com ou sem recomendacao. Cada uma
recebe ficha de evidencias, referencias e roteiro; o ranking resume a comparacao.
Depois voce escolhe a issue e seu recorte para planejar.

No planejamento, a entrada e **Planejamento: planejar**: usa a escolha e as
evidencias do registro para criar ou atualizar a proposta. Sem pacote a importar,
se faltar registro, **Workspace: atualizar indice dos projetos** o prepara. Nao e
necessario repetir projeto, rodada e escolhas em menus sucessivos. Evidencias suficientes permitem
planejar sem pacote MTA completo; duvidas essenciais sao esclarecidas antes de
concluir o plano, sem trocar silenciosamente uma base MTA ja declarada.
Plano e to-do usam modelos padronizados e nomes que identificam projeto/issue,
na pasta do `artifactId` Maven. O [dossie por issue](doc/guias/tools/planejamento-migracao.md#dossie-por-issue-e-passagem-entre-colegas)
reune ficha e evidencias usadas. O plano consolidado recebido permite preparar
implementacao sem o MTA original; revisar suas entradas exige reavaliacao explicita.

Para contribuir com a evolucao do harness, consulte [AGENTS.md](AGENTS.md) e as
[decisoes arquiteturais](doc/adr/). O [contrato de planejamento](doc/especificacoes/planejamento-copilot.md)
define os limites do trabalho assistido e os registros de cada etapa.

## Licenca

Distribuido sob a [licenca MIT](LICENSE). Copyright (c) 2026 Edoardo Bianco.
