---
html:
  embed_local_images: true
  embed_svg: true
  offline: true
---

# Conciliação das evoluções do harness

Registro de 05/10/2026, comparando o [catálogo de 23 capacidades](../features/evolucao-harness-dominios-capacidades-priorizacao.md), baseado em `de5975096d`, com o harness integrado em `d48cf6a`. A análise usa código e documentação locais; não revalida ferramentas externas nem executa pilotos.

**Situação:** proposta incorporada para avaliação futura. Data, prioridade escolhida e piloto continuam **a definir**. As sugestões P1/P2/P3 e a preferência pelo piloto A no catálogo não foram aprovadas como sequência de trabalho.

## Fontes e responsabilidades

- A [estratégia](estrategia-harness_.md) mantém a direção: JBoss, núcleo comum, tecnologias, engines, IDEs, SDLC e modernização.
- O catálogo detalha capacidades, alternativas e possíveis pilotos. Sua baseline e suas fontes históricas permanecem identificadas.
- Esta conciliação relaciona os escopos e corrige a leitura da baseline antiga; não substitui os contratos nem é outro plano de implementação.
- O [backlog vigente](../../tasks/todo.md#backlog-vigente) concentra o estado das entregas e verificações. A matriz de prioridade do catálogo concentra a futura escolha das capacidades. Ao escolher um incremento, atualizar essas referências na mesma entrega, sem manter dois checklists da mesma implementação.
- [AGENTS.md](../../AGENTS.md), as ADRs [0002](../adr/0002-separacao-harness-e-migracao-progressiva.md), [0004](../adr/0004-git-informativo-sem-controle-de-branches.md), [0005](../adr/0005-planejamento-orientado-pelo-registro.md) e o [contrato vigente](../especificacoes/planejamento-copilot.md) continuam normativos. A proposta não transforma helpers em executores.

## Correspondência com todas as frentes do backlog

Os IDs anteriores são preservados para rastreabilidade. Sua correspondência com o catálogo não cria uma segunda entrega nem amplia automaticamente o escopo solicitado.

| Frente existente | Relação com o catálogo | Tratamento para o planejamento futuro |
| --- | --- | --- |
| SIM-01 a SIM-14 | Base de HAR-03/04, OBJ-02 e SRC-06 | Reutilizar SIM-01..13; o ensaio SIM-14 continua em VAL-01. |
| SDLC-01/02 | CLI e orientação já entregues; base de HAR-01/02 e OBJ-02 | Estender apenas lacunas comprovadas; não recriar entrada CLI ou skill. |
| SDLC-03 | Helpers implementados; interface humana para várias capacidades | Preservar leitura/orientação e concluir a validação nativa em VAL-01. |
| SDLC-04/05 | Executores futuros; poderão consumir HAR, OBJ, SRC, DEP, JBS e CHG | Continuam entregas próprias. Um adaptador disponível não comprova orquestração/delegação autorizada. VAL-01 precede os executores. |
| SDLC-06 | Adequação de ações existentes, relacionada a HAR-02, JBS e CHG-03 | Vincular cada ajuste ao incremento que o exigir, evitando duas tarefas para a mesma mudança. |
| COMP-01 | Detalhado principalmente por DEP-01/02 | Uma demanda de inventário e matriz de compatibilidade, decomposta em capacidades. DEP-03 acrescenta verificações e exige escolha de escopo própria. |
| CORE-01 | Detalhado por SRC-01/03/06; SRC-02/04/05 ampliam as opções de análise | Manter piloto opcional, independente de MTA e de COMP-01. Dependência de classpath Maven é condicional. JDT/CLI e JavaParser continuam alternativas a avaliar; a proposta não escolheu uma implementação. |
| SERV-01 | Detalhado por JBS-01..05 | Uma frente de configuração e recursos do servidor. Separar inventário, rota, assistência, transformação e validação. Não duplicar start/deploy/rollback existentes. |
| VAL-01 | Ensaio nativo dos helpers nos dois clientes | Pendente, com observações parciais já registradas. Catálogo, links válidos e testes simulados não comprovam delegação nas extensões. |
| VAL-02 | Ensaio operacional de prompts, persistência, GO e continuidade | Pendente; continua distinto da validação de um futuro adaptador ou piloto. |
| VAL-03 | Sonar real, critérios e comparação com baseline | Pendente; CHG-03 aproveita essa frente sem declarar o ensaio concluído. |
| DEC-01 | Decisão sobre preparo de deploy com servidor parado | Mantida separadamente. Não foi respondida por JBS-03, que trata transformação de configuração. |
| EVO-01 | Estratégia mais ampla e novas capacidades sem demanda anterior específica | Mantém Node.js/TypeScript, IntelliJ, Quarkus, outros engines e entrega/operação. HAR-04 é relacionado, mas não substitui esses pilotos. |

## Correspondência das 23 capacidades

“Base existente” significa reaproveitamento identificado, não aceite integral da capacidade proposta. As lacunas abaixo ainda precisam de recorte, escolha humana e validação antes de serem implementadas.

| Capacidade | Base ou sobreposição identificada | Incremento ainda a avaliar |
| --- | --- | --- |
| HAR-01 | SDLC-02/03, instruções, helpers e Run Tasks | Descrição estruturada e seleção de capacidades realmente disponíveis; MCP apenas se necessário. |
| HAR-02 | Scripts, configuração, runtimes, build/MTA/JBoss; SDLC-01/06 | Contrato de execução dos novos adaptadores e lacunas de timeout/cancelamento por operação; não criar outro runner por padrão. |
| HAR-03 | Recibos, ContractSnapshot, Previous, origem MTA e evidências | Proveniência/cobertura dos novos coletores; validade e eventual cache conforme o conteúdo pertinente. |
| HAR-04 | ADR-0005 e PlanningBasis=MTA ou EVIDENCIAS; EVO-01 | Separação por objetivo, perfil, engine e IDE. A entrada de planejamento EAP sem pacote MTA já existe; perfis DDD/Quarkus não estão entregues por isso. |
| SRC-01 | Busca disponível nos clientes; recorte de CORE-01 | Adaptador de busca textual com escopo, exclusões e truncamento no contrato do harness. Ter ripgrep no ambiente não comprova essa integração. |
| SRC-02 | Ampliação de CORE-01 | Busca estrutural, regras e evidências; ferramenta candidata ainda sem piloto aprovado. |
| SRC-03 | Núcleo da navegação Java solicitada em CORE-01 | Resolução semântica e referências no recorte, com classpath e limites explícitos; escolher adaptador no piloto. |
| SRC-04 | Ampliação de CORE-01 e da estratégia de modernização | Relações/regras arquiteturais; grafo técnico não comprova limites de negócio. |
| SRC-05 | Novo detalhamento para investigação de comportamento/segurança | Fluxo de dados com cobertura e limitações; não é pré-requisito universal de CORE-01. |
| SRC-06 | Preparação atual de contexto; CORE-01 e HAR-03 | Seleção por objetivo/símbolo e orçamento de contexto, reaproveitando os caminhos e recibos existentes. |
| OBJ-01 | Importação MTA e API Sonar existentes | Normalização compartilhada e Fortify com amostra/interface real. Não reconstruir importadores existentes. |
| OBJ-02 | Planejamento pelo registro, escolha humana, lote e bases MTA/EVIDENCIAS | Seleção de capacidades e procedimentos para novos objetivos. A entrada sem MTA não depende mais de criar HAR-04. |
| DEP-01 | COMP-01; comparação estática do POM e evidências MTA | Inventário Maven efetivamente resolvido: POM efetivo, perfis, árvore, transitivas e escopos. |
| DEP-02 | Parecer solicitado em COMP-01 | Matriz por alvo com fontes, incertezas e ação recomendada; inventário não é parecer de suporte. |
| DEP-03 | Extensão da frente Maven | Convergência e vulnerabilidades, conforme necessidade do piloto; não implícitas no escopo inicial de COMP-01. |
| JBS-01 | SERV-01; configuração/controle standalone existentes | Inventário dos recursos, drivers, módulos e subsistemas pertinentes. |
| JBS-02 | Exigência de rota suportada já registrada em SERV-01 | Comprovar procedimento para versões/distribuições exatas antes de transformar. A rota direta 7.1 → 7.4 não foi confirmada nesta conciliação. |
| JBS-03 | SERV-01; deploy/rollback de artefatos existentes | Transformar configuração com diff, autorização e reversão próprios; rollback de WAR/EAR não restaura XML, módulos ou dados. |
| JBS-04 | Assistência de SERV-01 e helpers existentes | Orientação específica de configuração/recursos com evidências. Disponibilizar uma instrução não executa a migração. |
| JBS-05 | SERV-01; operações JBoss e verificações existentes | Validar a configuração candidata e os recursos usados no destino isolado, com critérios do piloto. |
| CHG-01 | OpenRewrite previsto no contrato | Adaptador de receitas, aplicabilidade, dryRun, diff e execução autorizada; menção contratual não é integração pronta. |
| CHG-02 | Preparo de implementação, prompts, GO e destinos atuais; SDLC-04/05 | Consumir novo contexto/capacidades e avaliar executores futuros. Preservar a execução autorizada atual e os helpers leitores. |
| CHG-03 | Build/testes/JaCoCo, critérios Sonar, verificações e aceite; VAL-02/03 | Ampliar evidências por objetivo e comparação de achados quando pertinente, sem refazer verificações existentes. |

## O que foi detalhado, superado ou acrescentado

**Descrições futuras detalhadas pelo catálogo:** COMP-01 ganha DEP-01/02; CORE-01 ganha um conjunto de opções SRC; SERV-01 ganha cinco capacidades JBS. Usar essas decomposições ao recortar a demanda. Os IDs agregadores, critérios anteriores e decisões humanas permanecem; não tratar as duas descrições como duas implementações. O catálogo não supera a estratégia nem aprova suas alternativas técnicas.

**Lacunas da baseline antiga já atendidas por entregas posteriores:**

- HAR-04/OBJ-02 ainda descrevem uma entrada sem MTA como trabalho futuro. A ADR-0005 e a implementação atual já permitem planejamento EAP com `PlanningBasis=EVIDENCIAS`, sem fabricar RunId ou snapshot. A ampliação para outros objetivos/perfis continua proposta.
- A priorização de issues da aplicação já usa 0,01% a 100,00% do total inicial fixo, com recriação ou progresso que exclui IDs já propostos. Ela é distinta da prioridade das capacidades do harness nesta proposta; não usar P1/P2/P3 para alterar esse fluxo.
- O workspace inicial agora contém apenas o harness; playgrounds/aplicações são externos. Referências históricas a exemplos internos e à branch encerrada do ensaio não são instruções para nova execução.
- A afirmação de “validação manual completa com aplicação ainda pendente” na base estratégica de 02/10 deve ser lida com o aceite geral de 03/10 registrado em tasks/todo.md. Esse aceite não comprova cenários individuais não registrados e não encerra VAL-01/02/03 nem a futura migração de configuração JBS.

**Novos recortes explícitos a avaliar:** ingestão Fortify, objetivo DDD separado da migração mínima, buscas estrutural/arquitetural/de fluxo, verificações Maven adicionais e adaptador OpenRewrite. Parte deles já cabia na estratégia ampla; agora há fichas, dependências e candidatos. Não há aprovação de instalação, versão, licença, runtime ou suporte por sua inclusão no catálogo.

## Dependências para uma evolução coerente

1. Escolher futuramente um problema real e um recorte; manter as demais capacidades a definir. Não transformar toda sugestão P1 em requisito do primeiro piloto.
2. Reutilizar a base que já satisfaz o contrato. Estender HAR somente nas lacunas exigidas pelo recorte; não exigir extração completa do núcleo, MCP, grafo ou Node.js antes de um piloto Java/JBoss.
3. DEP-02 consome o inventário DEP-01. CORE-01 continua opcional; SRC-03 usa DEP-01 quando precisar do classpath. COMP-01 não aguarda um explorador Java completo.
4. Para JBS, confirmar a rota antes da transformação; assistência pode preparar uma configuração candidata antes de automatizar JBS-03. Verificar o destino com critérios próprios.
5. VAL-01 continua antes de SDLC-04/05. Isso é uma dependência do fluxo de executores, não uma escolha de prioridade global entre Maven, JBoss, análise de código e portabilidade.
6. DDD, Quarkus, outros engines e IDEs exigem objetivo e critérios próprios. Não ampliar implicitamente o lote Java 8/javax/EAP 7.4 nem converter helper em executor.
7. Quando houver escolha, abrir um incremento em tasks/plan.md e tasks/todo.md com capacidade, lacuna, evidência atual, artefatos afetados e aceite. Implementação e integração seguem o fluxo de branch e PR do harness.

## Evidências consultadas e limites

| Constatação | Referências locais |
| --- | --- |
| Estado e ensaios ainda pendentes | [Backlog vigente](../../tasks/todo.md#backlog-vigente), [sequência e verificação](../../tasks/plan.md#sequencia-e-verificacao) e [aceite geral de 03/10](../../tasks/todo.md#aceite-manual-e-integracao-nas-principais---2026-10-03). |
| Planejamento pelo registro e base EVIDENCIAS | [HarnessPlanningInput.ps1](../../scripts/HarnessPlanningInput.ps1), [HarnessPlanning.psm1](../../scripts/HarnessPlanning.psm1), [Test-PlanningEvidence.ps1](../../tests/Test-PlanningEvidence.ps1) e ADR-0005. |
| Priorização percentual e continuidade | [Estado de priorização](../../scripts/HarnessPrioritizationState.ps1), [guia](../guias/tools/priorizacao-issues.md), [Test-PrioritizationProgress.ps1](../../tests/Test-PrioritizationProgress.ps1). |
| Importação e consultas existentes | [HarnessProjectIndex.psm1](../../scripts/HarnessProjectIndex.psm1) e [HarnessSonarApi.psm1](../../scripts/HarnessSonarApi.psm1). |
| Operações e validações existentes | [HarnessBuild.psm1](../../scripts/HarnessBuild.psm1), [HarnessSonarCriteria.psm1](../../scripts/HarnessSonarCriteria.psm1), [HarnessJboss.psm1](../../scripts/HarnessJboss.psm1) e [HarnessJbossArtifacts.psm1](../../scripts/HarnessJbossArtifacts.psm1). |
| Papéis e contratos | [Skill de orientação](../../.agents/skills/orientar-migracao/SKILL.md), [contrato de planejamento](../especificacoes/planejamento-copilot.md), ADRs e AGENTS.md. |

Os testes citados são evidência de cobertura existente, não de uma nova execução nesta conciliação. Versões, licenças, suporte das ferramentas candidatas, custo e ganho de cada piloto precisam ser verificados no seu planejamento. Nenhum ensaio de aplicação ou capacidade futura recebe aceite por esta revisão documental.
