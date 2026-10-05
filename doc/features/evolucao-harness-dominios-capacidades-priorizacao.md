# Proposta de evolução do harness de engenharia: domínios, capacidades e priorização

**Versão:** 1.0  
**Data:** 04/10/2026  
**Finalidade:** selecionar, planejar e implementar com o Codex incrementos no harness existente, para migração, SDLC e modernização.  
**Enquadramento:** backlog de evolução integrado à estratégia e ao fluxo existentes.  
**Projeto-base:** [edoardo-bianco/jboss-mta-harness](https://github.com/edoardo-bianco/jboss-mta-harness).  
**Baseline examinada:** branch `main`, commit [`de5975096d`](https://github.com/edoardo-bianco/jboss-mta-harness/commit/de5975096d0848b91b0d45aad00d291787a89bb3), de 03/10/2026.  
**Situação:** proposta com 23 capacidades; implementação atual identificada por leitura de código e documentação. Não foram executados testes ou validações de runtime nesta revisão.

> **Incorporação em 05/10/2026:** proposta registrada sem prazo, prioridade ou piloto escolhido. Consulte a [conciliação com o backlog e a base atual](../estrategia/conciliacao-evolucao-harness.md) para sobreposições e lacunas já atendidas após a baseline examinada. O texto original abaixo e suas sugestões permanecem como proposta.

## 1. Objetivo

Evoluir o `jboss-mta-harness` em direção ao **harness de engenharia extensível** já previsto na estratégia do próprio repositório. Ampliar sua capacidade de preparar contexto, orientar o agente e validar resultados em migrações, correções do cotidiano e modernização. As novas capacidades devem aproveitar os scripts, tarefas, contratos, evidências, lotes e pontos de revisão existentes.

O resultado esperado é permitir que o agente escolha e execute ferramentas locais conforme um objetivo técnico, recupere o contexto necessário, fundamente decisões em evidências e conduza a mudança até sua validação. O documento especifica os incrementos a incorporar ao harness atual; não propõe sua substituição nem a construção de um segundo framework.

O trabalho começa por um módulo, apontamento, símbolo, caso de uso ou configuração de servidor. A análise amplia o escopo quando uma dependência relevante exigir. A construção de um índice completo do repositório não é pré-requisito.

O catálogo cobre quatro objetivos de uso:

- Investigar e corrigir apontamentos do Sonar, Fortify, MTA e outras fontes que venham a receber adaptadores.
- Apoiar refatorações em direção a DDD, partindo de casos de uso e regras de negócio.
- Avaliar dependências Maven em relação a uma plataforma-alvo, com justificativas e links oficiais.
- Migrar a configuração do JBoss EAP, combinando transformação automatizada e orientação ao desenvolvedor.

Este documento organiza o backlog e complementa a estratégia em andamento. Não aprova automaticamente todas as capacidades nem redefine o cronograma da migração. Capacidades já atendidas pelo harness devem ser marcadas como reutilizadas; o planejamento deve estimar somente o incremento que falta.

**Nome e posicionamento:** `jboss-mta-harness` identifica o repositório atual e sua origem. O nome conceitual usado nesta proposta é “harness de engenharia extensível”. Uma eventual renomeação deve ser decidida separadamente, após avaliar links, scripts, workspaces e documentação; não é requisito para implementar estas capacidades.

## 2. Índice

- [3. Diretrizes da expansão](#3-diretrizes-da-expansão)
- [4. Modelo de organização](#4-modelo-de-organização)
- [5. Domínio: execução e evidências do harness](#5-domínio-execução-e-evidências-do-harness)
- [6. Domínio: análise de código sob demanda](#6-domínio-análise-de-código-sob-demanda)
- [7. Domínio: apontamentos e objetivos de análise](#7-domínio-apontamentos-e-objetivos-de-análise)
- [8. Domínio: dependências Maven e plataforma-alvo](#8-domínio-dependências-maven-e-plataforma-alvo)
- [9. Domínio: migração da configuração JBoss EAP](#9-domínio-migração-da-configuração-jboss-eap)
- [10. Domínio: transformação e validação](#10-domínio-transformação-e-validação)
- [11. Contrato comum das capacidades](#11-contrato-comum-das-capacidades)
- [12. Matriz de priorização](#12-matriz-de-priorização)
- [13. Planejamento e implementação com o Codex](#13-planejamento-e-implementação-com-o-codex)
- [14. Fontes oficiais e limites de aplicação](#14-fontes-oficiais-e-limites-de-aplicação)

## 3. Diretrizes da expansão

1. **Análise orientada ao objetivo.** O agente escolhe uma capacidade pela pergunta que precisa responder: localizar, resolver uma referência, investigar um fluxo, verificar uma dependência ou migrar uma configuração.
2. **Escopo progressivo.** Começar pelo recorte informado; ampliar com justificativa e registrar os limites. Carregar o classpath de um módulo não implica enviar todo o módulo ao LLM.
3. **Ferramentas determinísticas para extrair e transformar.** Usar parsers, plugins, regras e receitas para operações reproduzíveis. O agente interpreta resultados, conduz a investigação e propõe decisões.
4. **Evidência vinculada à conclusão.** Registrar arquivos, localizações, versões, comandos, resultados e documentação aplicável. Diferenciar fato extraído, orientação documentada, inferência e informação não confirmada.
5. **Alvo explícito por perfil.** Migrações exigem produto, versão, atualização/patch, JDK e restrições. O perfil atual preserva Java 8, `javax` e EAP 7.4 como destino de validação. Essas regras pertencem ao perfil EAP, não ao núcleo comum nem a futuros perfis Quarkus.
6. **Execução local integrada ao fluxo existente.** Reutilizar os scripts e tarefas do VS Code, preservando a execução manual assistida e a possibilidade de operar ferramentas sem LLM. Considerar Windows corporativo, PowerShell 5.1, caminhos explícitos e softwares aprovados. Verificar os requisitos de cada ferramenta antes de selecioná-la.
7. **JDK da ferramenta separado do JDK da aplicação.** Quando tecnicamente permitido, configurar runtimes distintos sem alterar o alvo de compilação/deploy da aplicação.
8. **Mudanças rastreáveis.** Preservar a origem, produzir diferenças revisáveis e manter um mecanismo de recuperação adequado ao recurso alterado. Alterações em código, POM e servidor têm efeitos diferentes.
9. **Validação proporcional à mudança.** Definir antes da execução quais evidências encerram o trabalho. Uma instrução emitida ou um comando com saída zero não comprovam, isoladamente, a migração funcional.
10. **Adoção incremental.** Implementar uma capacidade utilizável por vez. MCP e bancos de grafos podem ser introduzidos quando trouxerem benefício concreto; não são pré-requisitos universais.

### 3.1. Encaixe na estratégia e no harness atual

A referência principal é a [estratégia do repositório](https://github.com/edoardo-bianco/jboss-mta-harness/blob/de5975096d0848b91b0d45aad00d291787a89bb3/doc/estrategia/estrategia-harness_.md). Ela prevê núcleo comum, plugins tecnológicos, adaptadores de engine e de IDE, com JBoss como base e Quarkus como evolução. O catálogo abaixo detalha capacidades que materializam essa direção.

A evolução mantém o ciclo: **preparar contexto → analisar e propor um lote → revisão e GO → execução autorizada → verificações → aceite humano**. A geração de contexto ou de prompt não executa o agente e não concede GO. O próximo lote depende do aceite do atual e do pedido de continuidade.

As novas ferramentas aumentam a qualidade das entradas fornecidas ao agente e das evidências devolvidas após a execução. Os pontos de revisão humana e as autorizações já estabelecidos permanecem no fluxo, sem criar uma trilha paralela de aprovação.

| Base constatada no repositório | Evolução proposta | Ponto de integração |
| --- | --- | --- |
| Windows PowerShell 5.1, configuração compartilhada e tarefas VS Code | Integrar adaptadores locais e selecionar ferramentas por capacidade. | `scripts/Harness.psm1`, `config/harness.example.json`, `.vscode/tasks.json`. |
| Preparação de contexto/prompt, recibos e contrato preservado em `ContractSnapshot` | Enriquecer contexto, cobertura e roteamento por objetivo. | `scripts/HarnessPlanning.psm1`, `doc/especificacoes/planejamento-copilot.md`. |
| Índice de projetos, histórico MTA e registros de migração | Relacionar apontamentos a consultas de código feitas sob demanda. | `scripts/HarnessProjectIndex.psm1`. O índice atual não é um índice semântico Java. |
| Ingestão de violações MTA e consultas à API Sonar | Normalizar localizações e evidências; integrar Fortify por adaptador novo. | `HarnessProjectIndex.psm1`, `HarnessSonarApi.psm1` e `HarnessSonarCriteria.psm1`. |
| Comparação estática de identidade do POM e evidências de dependências MTA | Acrescentar POM efetivo, árvore Maven atual e parecer por alvo. | `Compare-MtaPlanningPom` em `HarnessPlanning.psm1`; guia Maven e configuração atuais. |
| Build Maven Java 8 com recibos; avaliação Sonar e política de validação | Reutilizar verificações e acrescentar comparação de achados quando necessária. | `scripts/HarnessBuild.psm1`, módulos Sonar e contrato de planejamento. |
| JBoss standalone: estado, start normal/debug, deploy, histórico de releases, rollback, stop e attach Java implementados | Acrescentar inventário detalhado e migração da configuração. | `HarnessJboss*.psm1` e tarefas existentes. A estratégia registra validação manual completa com aplicação ainda pendente. |
| Referências a OpenRewrite no contrato | Integrar execução de receitas com diferenças revisáveis e evidência. | Mesmo plano, autorização e validação da correção contextual; referências não equivalem a um adaptador pronto. |

**Limite atual relevante:** `Harness.psm1` valida o perfil `eap71-to-eap74-java8`; a execução compartilhada ainda depende de Windows PowerShell 5.1. A arquitetura com múltiplos plugins, engines e IDEs está proposta, não implementada como plataforma genérica. A ampliação deve acontecer por contratos e pilotos incrementais.

O contrato vigente e as ADRs do repositório prevalecem sobre materiais anteriores. Preservar `RequestId`, `Project`, `Source`, `RunId`, `ContextPath`, `PlanPath`, `TodoPath`, `ContractPath` e `ContractSnapshot` onde forem aplicáveis. `MigrationPath` e os caminhos recebidos são autoritativos; não reconstruí-los por conveniência.

**Separação de objetivos:** apoiar DDD é uma capacidade reutilizável, acionada por objetivo próprio, com regras e validação de negócio. Não amplia implicitamente um lote de migração mínima EAP. Nesse perfil permanecem Java 8, `javax`, contratos, comportamento e restrições de arquitetura/SSO já estabelecidas. O código corrigido é validado no **EAP 7.4**; EAP 7.1 é origem histórica, sem obrigação de executar o mesmo WAR corrigido nos dois servidores.

### 3.2. Regra de evolução para cada capacidade

Antes de abrir uma implementação, registrar: **evidência do que existe → lacuna observada → incremento proposto → artefatos afetados → compatibilidade a preservar → aceite**.

Classificar o trabalho como **reutilizar**, **estender**, **integrar ferramenta** ou **criar componente ausente**. Os IDs deste documento organizam o backlog; não obrigam novos diretórios, novos processos ou a troca dos nomes já adotados no harness.

### 3.3. Contratos que as extensões devem preservar

- **Planejamento separado:** evolução do harness usa `tasks/plan.md` e `tasks/todo.md`; trabalho na aplicação usa os `PlanPath`/`TodoPath` recebidos em `.harness/planning/<solicitacao>/`. Manutenção do registro de migração não cria plano nem executa correção.
- **Git informativo no fluxo da aplicação:** não criar gates por branch, HEAD, árvore suja ou caminho histórico. Planejamento não coleta Git. Verificar relevância das evidências pelo conteúdo pertinente; troca de máquina/branch não invalida automaticamente o contexto. A evolução do próprio harness segue a convenção de branch descrita na seção 13.
- **Origem distinta do fonte local:** preservar `MtaOrigin`/`AnalysisSource` e analisar em `Source`. Resolver referências por caminho relativo, classe, método ou assinatura; não editar snapshots históricos.
- **Decisão humana preservada:** extração automática pode reconciliar fatos, sem sobrescrever decisões, confundir andamento com aceite ou declarar migração completa por contagem reduzida.
- **Validação vigente:** build/testes e resultado funcional no destino continuam exigidos pelo perfil. Novo MTA e Sonar antes/depois permanecem checklist não bloqueante; sua ausência fica visível e não implica conformidade. A conclusão global exige evidência final comparável, cobertura do escopo e aceite humano.
- **Configuração corporativa:** utilizar Maven/settings/repositórios aprovados e padrões da máquina; não criar mirrors, settings ou caches alternativos por conveniência. Segredos não integram o contexto do agente.
- **Interface existente:** reaproveitar menus e os prefixos de tarefas `Workspace:`, `Aplicacao:`, `Servidor:`, `MTA:` e `Planejamento:`; evitar uma nova tarefa por ferramenta, arquivo ou formato.

## 4. Modelo de organização

“Domínio” e “subdomínio” são usados aqui para organizar as responsabilidades do harness. Essa classificação não determina os bounded contexts da aplicação nem exige serviços separados.

| Domínio | Subdomínios | Capacidades |
| --- | --- | --- |
| Execução e evidências | Catálogo; execução local; rastreabilidade; perfis e contratos | HAR-01 a HAR-04 |
| Análise de código | Localização; semântica Java; arquitetura e fluxos; contexto | SRC-01 a SRC-06 |
| Apontamentos e objetivos | Ingestão; investigação e planejamento por objetivo | OBJ-01 a OBJ-02 |
| Dependências Maven | Inventário efetivo; compatibilidade e suporte; verificações técnicas | DEP-01 a DEP-03 |
| Configuração JBoss EAP | Descoberta; estratégia; transformação; assistência; validação | JBS-01 a JBS-05 |
| Transformação e validação | Receitas; correção pelo agente; comprovação do resultado | CHG-01 a CHG-03 |

Para as extensões selecionadas, aplicar **portas e adaptadores** nos pontos existentes de integração: a capacidade oferece um contrato estável; o adaptador encapsula a ferramenta e seu formato; o procedimento por objetivo decide a sequência. Essa separação permite trocar ferramentas e versões sem reescrever os procedimentos e não exige reestruturar globalmente o harness.

| Elemento | Responsabilidade |
| --- | --- |
| Capacidade | Define qual problema pode resolver, entradas, saídas e limites. |
| Adaptador de ferramenta | Executa a CLI/biblioteca, interpreta a saída e registra efeitos e falhas. |
| Procedimento ou skill do agente | Explica quando usar capacidades, como interpretar evidências e qual próximo passo tomar. |
| Executor local | Controla diretório, runtime, parâmetros, timeout e artefatos da execução. |
| Registro de evidências | Relaciona o resultado ao código/configuração analisados e às fontes utilizadas. |

Descrever uma ferramenta ao agente não a torna executável: é necessário disponibilizar o binário, a biblioteca ou o adaptador correspondente.

### 4.1. Distribuição na arquitetura prevista pela estratégia

| Parte da arquitetura-alvo | Responsabilidade nesta proposta | Capacidades principais |
| --- | --- | --- |
| Núcleo comum | Objetivo, escopo, catálogo, execução, evidências, continuidade e contratos. | HAR; partes comuns de OBJ, SRC-06 e CHG-03. |
| Ferramentas Java/Maven compartilhadas | Busca, resolução de símbolos, inventário de dependências e receitas reutilizáveis. | SRC; DEP-01/03; CHG-01. |
| Perfil/plugin tecnológico | Alvo, regras, fontes oficiais e verificações específicas. | DEP-02 por alvo; JBS para EAP; regras tecnológicas de OBJ/CHG. |
| Adaptador de engine | Apresentar capacidades/contexto e receber resultados no contrato do harness. | HAR-01/04 e integração de CHG-02. Codex pode implementar o harness sem se tornar seu único engine. |
| Adaptador de IDE | Acionar comandos e apresentar contexto, evidências e debug. | Tarefas VS Code atuais; IntelliJ como piloto posterior da estratégia. |

Essa distribuição é uma direção para a evolução, não a descrição de módulos já extraídos. Ferramentas de análise local podem funcionar sem engine de IA. Execução local também não significa operação totalmente offline: Maven, bases de vulnerabilidades, documentação e engines podem exigir conectividade, explicitada no adaptador.

### 4.2. Classificação das ferramentas para o agente

| Categoria | Ferramenta candidata | Pergunta atendida | Limite essencial |
| --- | --- | --- | --- |
| Localização textual | ripgrep | Onde este texto/API/configuração aparece? | Ocorrência textual não é referência Java resolvida. |
| Estrutura sintática | ast-grep | Onde ocorre esta construção de código? | AST não fornece, por si, análise de tipos ou fluxo. |
| Semântica Java | JavaParser + Symbol Solver | Qual declaração/tipo esta referência representa? | Exige adaptador, classpath e cobertura explícita. |
| Arquitetura | jQAssistant | Como estes elementos dependem entre si? | Grafo técnico não identifica sozinho limites de negócio. |
| Fluxo de dados | Joern | Como um dado pode chegar a determinado ponto? | Resultado estático depende do frontend, modelos e escopo. |
| Contexto | Montador do harness + Repomix opcional | Quais trechos/evidências o agente deve receber? | Empacotamento não substitui seleção nem análise. |
| Dependências | Maven Help/Dependency, Versions, Enforcer, Dependency-Check | O que é resolvido e quais problemas/candidatos existem? | Versão recente ou alerta isolado não determina suporte ao alvo. |
| Transformação | OpenRewrite | Há uma receita adequada para este conjunto de mudanças? | Verificar licença, versão, aplicabilidade e efeitos da receita. |
| Configuração EAP | Management CLI + Server Migration Tool da distribuição | Como inventariar e migrar esta configuração? | Confirmar procedimento Red Hat para o par exato de versões. |

Os projetos de análise e automação listados são candidatos open-source; fixar versão, licença e requisitos de cada componente no piloto. Sonar, Fortify e MTA são também **origens de apontamentos**: não se exige substituir as instalações existentes nem classificar todas as suas edições/distribuições como open-source. O uso de documentação Red Hat e de sua distribuição EAP preserva as condições de acesso e suporte aplicáveis.

## 5. Domínio: execução e evidências do harness

### 5.1. Subdomínio: catálogo de capacidades

#### HAR-01 — Catalogar e expor capacidades ao agente

- **Objetivo:** permitir seleção pelo propósito, com descrição verificável de cada capacidade.
- **Entradas:** objetivo, escopo e capacidades disponíveis no ambiente.
- **Saídas:** capacidade selecionada, parâmetros necessários, pré-requisitos e justificativa de escolha.
- **Incremento no harness:** estruturar descrições de capacidades a partir das instruções e comandos existentes, com metadados para seleção pelo agente. Acrescentar um catálogo próprio somente quando necessário à integração; exposição por MCP é evolução opcional.
- **Aceite:** cada entrada possui nome, descrição, quando usar, entradas, saídas, limites e efeitos; capacidades indisponíveis são identificadas sem simular execução.
- **Dependências:** nenhuma; compatibilizar com o mecanismo já existente no harness.

### 5.2. Subdomínio: execução local

#### HAR-02 — Executar ferramentas no ambiente correto

- **Objetivo:** executar a mesma operação pelo agente ou por Run Task do VS Code, com parâmetros reproduzíveis.
- **Entradas:** comando/adaptador, diretório, versão da ferramenta, runtime, parâmetros e modo de execução.
- **Saídas:** resultado estruturado, código de saída, logs relevantes, duração e arquivos produzidos.
- **Incremento no harness:** estender o executor e os scripts existentes; centralizar parâmetros e versões na configuração já adotada, evitando duplicar runners.
- **Aceite:** distinguir JDK da aplicação e da ferramenta; informar instalação/runtime ausente; tratar falha, timeout e cancelamento; não pressupor Docker ou privilégio administrativo.
- **Dependências:** HAR-01.

### 5.3. Subdomínio: rastreabilidade e contexto reutilizável

#### HAR-03 — Registrar evidências, cobertura e validade dos resultados

- **Objetivo:** permitir retomada e impedir uso silencioso de resultados desatualizados ou incompletos.
- **Entradas:** execução, arquivos analisados, perfis, alvo e fontes consultadas; metadados Git já disponíveis apenas como informação.
- **Saídas:** extensão do registro de análise com escopo, exclusões, lacunas, configuração e data. Identificadores de conteúdo podem apoiar caches locais de análise, sem criar exigência de hashes para evidências complementares.
- **Incremento no harness:** ampliar recibos e registros de evidências atuais, preservando `ContractSnapshot`. Acrescentar cache com invalidação por conteúdo pertinente apenas quando existir resultado reutilizável.
- **Aceite:** verificar validade conforme alterações relevantes de fonte, configuração, classpath, perfis, alvo, ferramenta ou regras; identificar truncamento e símbolos não resolvidos. Não coletar Git na preparação do planejamento nem usar diferenças de Git/caminho como bloqueio. Preservar a política de evidências complementares listadas, sem varrer logs, credenciais ou caches. Não registrar segredos.
- **Dependências:** HAR-02.

### 5.4. Subdomínio: perfis tecnológicos e contratos comuns

#### HAR-04 — Separar objetivo, perfil tecnológico, engine e IDE

- **Objetivo:** permitir reutilização das capacidades além de JBoss/MTA, conforme a estratégia existente.
- **Entradas:** objetivo, perfil com versões/regras, engine e IDE escolhidos, contratos e comandos atuais.
- **Saídas:** declaração explícita da combinação suportada e dos adaptadores necessários; extensão compatível dos contratos de contexto e resultado.
- **Incremento no harness:** separar gradualmente regras `eap71-to-eap74-java8` das responsabilidades comuns de `Harness.psm1`/`HarnessPlanning.psm1`. Definir entrada para objetivos sem MTA, preservando o fluxo atual `Purpose=application-remediation`; não inventar `RunId` MTA para um defeito, análise DDD ou parecer Maven independente.
- **Aceite:** o fluxo EAP atual continua utilizável; objetivo, tecnologia, engine e IDE não são acoplados artificialmente; combinações não validadas aparecem como tal. Uma primeira fatia pode apenas explicitar os contratos, sem extrair todo o núcleo.
- **Dependências:** contratos de HAR-01/03; validação de regressão do fluxo atual. Portabilidade Node.js/TypeScript, IntelliJ, plugin Quarkus e engines alternativos permanecem pilotos próprios da estratégia.

## 6. Domínio: análise de código sob demanda

### 6.1. Subdomínio: localização de código

#### SRC-01 — Localizar arquivos e ocorrências textuais

- **Objetivo:** encontrar rapidamente candidatos relacionados a uma issue, API, classe, mensagem ou configuração.
- **Ferramenta:** ripgrep. [R01]
- **Entradas:** módulo/diretório, texto ou expressão, filtros de arquivo e limite de resultados.
- **Saídas:** caminhos, linhas e trechos, incluindo informação de truncamento.
- **Aceite:** respeitar o escopo e tornar exclusões visíveis; classificar ocorrências como textuais, sem tratá-las como referências Java resolvidas.
- **Dependências:** HAR-02 e HAR-03.

#### SRC-02 — Encontrar padrões estruturais

- **Objetivo:** localizar construções Java equivalentes, como chamadas, declarações e expressões, para agrupar ocorrências semelhantes.
- **Ferramenta:** ast-grep, com regras compatíveis com Java. [R02]
- **Entradas:** regra/padrão e arquivos ou pacotes selecionados.
- **Saídas:** ocorrências estruturais e suas localizações.
- **Aceite:** conservar o vínculo com a regra; diferenciar correspondência sintática de resolução de tipos. A identificação de um padrão não autoriza automaticamente sua substituição.
- **Dependências:** HAR-02 e HAR-03.

### 6.2. Subdomínio: semântica Java

#### SRC-03 — Consultar símbolos, referências e dependências Java

- **Objetivo:** investigar declarações e relações necessárias ao impacto de uma alteração.
- **Ferramenta:** adaptador próprio sobre JavaParser e Symbol Solver. São bibliotecas, não uma ferramenta pronta com o contrato do harness. [R03]
- **Entradas:** símbolo/assinatura ou localização, raízes de fonte, linguagem Java, classpath e escopo.
- **Saídas:** declaração, referências encontradas, tipos e relações extraídas, trechos e símbolos não resolvidos.
- **Aceite:** permitir consultas no recorte e índices/cache sob demanda; informar limites em reflexão, resolução dinâmica e injeção; construir a busca de referências sobre os arquivos efetivamente percorridos. Ausência de resultado fora da cobertura não significa ausência de uso.
- **Dependências:** HAR-02 e HAR-03; DEP-01 quando necessário para obter o classpath/configuração Maven.

### 6.3. Subdomínio: arquitetura e fluxo de dados

#### SRC-04 — Investigar relações arquiteturais

- **Objetivo:** consultar dependências entre classes, pacotes e módulos para identificar acoplamento e verificar restrições arquiteturais explícitas.
- **Ferramenta:** jQAssistant. O scanner Java padrão usa bytecode; localizações dependem das informações presentes na compilação. [R04]
- **Entradas:** artefatos do recorte, relações a investigar e regras arquiteturais.
- **Saídas:** consultas e subgrafos relevantes, violações e cobertura.
- **Aceite:** relacionar artefatos ao código analisado; informar recursos não escaneados; não converter agrupamentos técnicos automaticamente em bounded contexts.
- **Dependências:** HAR-02 e HAR-03; artefatos compilados compatíveis com a análise.

#### SRC-05 — Investigar fluxo de dados

- **Objetivo:** examinar origem, propagação e destino de dados em uma investigação de segurança ou comportamento.
- **Ferramenta:** Joern, frontend Java e mecanismos de slicing, conforme a versão selecionada. [R05]
- **Entradas:** localizações, métodos e caminho reportado pelo analisador, quando disponível; dependências necessárias.
- **Saídas:** caminhos/recortes de fluxo, métodos envolvidos e evidências; `joern-slice` oferece saída JSON.
- **Aceite:** explicitar limites de profundidade, escopo e resolução; preservar o caminho original do Fortify e registrar divergências. A ausência de caminho no Joern não encerra uma issue de outro analisador.
- **Dependências:** HAR-02 e HAR-03.

### 6.4. Subdomínio: preparação de contexto

#### SRC-06 — Preparar contexto por objetivo

- **Objetivo:** entregar ao LLM os trechos, relações e evidências selecionados para a tarefa.
- **Ferramenta:** montador do harness; Repomix pode empacotar os arquivos selecionados. Recorte por símbolo e junção de evidências pertencem ao adaptador. [R06]
- **Entradas:** objetivo, arquivos/trechos selecionados, apontamento, evidências e orçamento de contexto.
- **Saídas:** pacote em Markdown/XML/JSON ou leitura sob demanda, com proveniência e lacunas.
- **Aceite:** preservar os corpos de métodos relevantes à investigação; informar o que foi omitido. A compressão do Repomix remove detalhes de implementação e exige escolha consciente.
- **Dependências:** HAR-03 e ao menos uma fonte de seleção de contexto, como SRC-01.

## 7. Domínio: apontamentos e objetivos de análise

### 7.1. Subdomínio: ingestão de apontamentos

#### OBJ-01 — Normalizar apontamentos de analisadores

- **Objetivo:** dar ao agente uma entrada estável para Sonar, Fortify, MTA e futuros analisadores.
- **Incremento no harness:** estender os importadores MTA/Sonar existentes quando atendam ao contrato; integrar Fortify por adaptador específico. Separar origem, versão e formato de relatório/API comprovadamente disponível, sem presumir exportação comum.
- **Entradas:** relatório ou dados autorizados do analisador, versão, configuração e identificação do código analisado.
- **Saídas:** ID original, ferramenta, regra, severidade original, descrição, localizações principais/secundárias, caminhos e recomendações existentes.
- **Aceite:** preservar o relatório original e dados específicos; marcar campos ausentes; relacionar localizações ao estado do código. Semânticas de severidade distintas devem manter sua origem.
- **Dependências:** HAR-03. A implementação pode começar apenas pelo adaptador MTA.

**Base concreta:** o harness já extrai violações do `output/static-report/output.js` do MTA por leitura dos dados atribuídos a `window["apps"]`, sem executar JavaScript. Preservar o fallback documentado para execuções antigas sem esse arquivo. O adaptador Sonar já consulta a API de issues e critérios; o incremento é relacionar os achados ao contrato comum e ao código, não reconstruir a integração. Fortify requer amostra real e interface/exportação da versão utilizada.

### 7.2. Subdomínio: investigação e planejamento por objetivo

#### OBJ-02 — Selecionar capacidades e formar unidades de trabalho

- **Objetivo:** transformar um objetivo ou apontamento em uma investigação delimitada e em um plano executável.
- **Entradas:** objetivo, apontamento opcional, alvo, restrições e evidências disponíveis.
- **Saídas:** hipótese, capacidades selecionadas, recorte, plano de mudança e critérios de encerramento.
- **Unidade de trabalho:** preservar a convenção de lote de correção do harness, também discutida como fatia. O lote pode reunir ocorrências equivalentes ou conter um único problema complexo. Mesmo rule ID não comprova mesma causa/correção; justificar o agrupamento e registrar ocorrências incluídas, excluídas e dependências.
- **Aceite:** ampliar o escopo apenas com motivo; distinguir diagnóstico de proposta; definir validação antes da alteração; manter hipóteses de DDD separadas das evidências técnicas.
- **Dependências:** HAR-01 a HAR-03; OBJ-01 quando a origem for um analisador. Demais capacidades são escolhidas por objetivo.

Trabalhar um lote consistente por frente. Registrar cobertura parcial e ocorrências restantes no registro atual. Para uma demanda sem MTA, usar a entrada independente definida por HAR-04; o contexto MTA não deve se tornar um pré-requisito artificial para DDD ou correções do SDLC.

| Objetivo | Encaminhamento proposto |
| --- | --- |
| Sonar | Ler regra e localizações; inspecionar código; investigar relações se necessário; corrigir e reanalisar. |
| Fortify | Preservar o caminho reportado; investigar origem, propagação e destino; complementar com SRC-05 quando útil; revalidar no analisador original. |
| MTA | Confirmar alvo e regras; localizar ocorrências equivalentes; avaliar dependências/configuração relacionadas; escolher receita ou correção contextual. A cobertura depende da versão e das regras do MTA. [R07] |
| DDD | Partir do caso de uso, invariantes e linguagem do negócio; investigar regras, persistência e acoplamento; propor responsabilidades e validar a hipótese com conhecimento do domínio. |

No objetivo DDD, a saída esperada inclui vocabulário e invariantes informados, responsabilidades atuais, dependências relevantes, hipótese de subdomínio/bounded context e uma refatoração delimitada. Cada hipótese deve indicar o que veio do código, de documentação/ADR ou de confirmação humana. O grafo não determina automaticamente agregados, subdomínios centrais/de suporte/genéricos ou eventos de domínio.

## 8. Domínio: dependências Maven e plataforma-alvo

### 8.1. Subdomínio: inventário efetivo

#### DEP-01 — Extrair configuração e dependências resolvidas

- **Objetivo:** complementar o diagnóstico Maven/dependências existente com o que o módulo declara, herda e efetivamente resolve.
- **Ferramentas:** Maven Help Plugin, `help:effective-pom` com `verbose`; Maven Dependency Plugin, `dependency:tree`. [R08][R09]
- **Entradas:** POM do módulo, parents/BOMs acessíveis, perfis, propriedades e ambiente Maven relevante.
- **Saídas:** POM efetivo, árvore resolvida, escopos, caminhos transitivos e origem do gerenciamento de versões; classpath quando necessário.
- **Incremento no harness:** complementar `Compare-MtaPlanningPom`, que hoje faz comparação estática de identidade; `dependencies.yaml` da execução MTA não representa a resolução Maven atual. Reutilizar JDK/Maven/settings da aplicação. Criar uma operação específica com goals/argumentos controlados para coleta, preservando a restrição da tarefa de build a fases Maven autorizadas.
- **Aceite:** usar configuração equivalente à do build analisado; registrar perfis/propriedades relevantes; separar dependências utilizadas de entradas apenas gerenciadas; distinguir dependências da aplicação e plugins de build. Falhas de resolução/parent/perfil são lacunas explícitas. O POM efetivo não substitui a árvore resolvida. [R10]
- **Dependências:** HAR-02 e HAR-03.

### 8.2. Subdomínio: compatibilidade, suporte e evidências

#### DEP-02 — Avaliar dependências em relação ao alvo

- **Objetivo:** decidir se uma dependência pode permanecer, precisa mudar ou exige investigação, apontando evidência oficial.
- **Ferramentas:** Versions Maven Plugin para candidatos e comparação com POM/BOM de referência; pesquisa documental e regras do harness para o parecer. `compare-dependencies` pode operar em modo de relatório. [R11]
- **Entradas:** DEP-01, produto/framework de destino, versão/patch, JDK, BOM quando aplicável e restrições.
- **Saídas:** parecer por dependência, versão/BOM recomendado quando sustentado, ponto de alteração e validações pendentes.
- **Aceite:** separar compatibilidade técnica, suporte, segurança e alinhamento ao BOM. Uma versão mais nova não comprova adequação ao alvo; ausência de vulnerabilidade reportada não comprova segurança. Conclusões sem evidência suficiente devem ser não confirmadas.
- **Dependências:** DEP-01 e HAR-03; articulação com JBS-01 para bibliotecas fornecidas pelo servidor.

Cada parecer deve registrar:

| Campo | Conteúdo obrigatório |
| --- | --- |
| Dependência | Coordenadas, versão declarada, resolvida e escopo. |
| Origem | Direta/transitiva; parent, propriedade, BOM e caminho que introduz a dependência. |
| Alvo | Produto, versão/patch, JDK e restrições consideradas. |
| Situação por dimensão | Compatibilidade com API/JDK, alinhamento ao BOM, suporte/ciclo de vida e segurança, cada um com evidência ou “não confirmado”. |
| Decisão | Manter, atualizar, substituir, ajustar escopo ou investigar. |
| Alteração proposta | Versão/BOM e local que controla a configuração; avaliar impacto em módulos irmãos quando houver parent compartilhado. |
| Evidência | URL oficial, título, seção, versões às quais se aplica e data de consulta. |
| Fundamentação | Relação concreta entre a evidência e a recomendação; documentada, inferida ou não confirmada. |
| Validação | Compilação, testes, deploy e/ou análise necessários antes de encerrar. |

Para JBoss, o parecer sobre compatibilidade e configuração da plataforma deve usar documentação oficial Red Hat. Complementos sobre a biblioteca podem usar documentação oficial do respectivo fornecedor, sem substituir o posicionamento Red Hat sobre a plataforma.

O escopo `provided` expressa que se espera uma dependência do JDK/contêiner em execução. Para identificar a implementação efetivamente carregada, cruzar Maven com inventário e configuração do servidor. [R10]

**Aplicação ao perfil existente:** Hibernate ORM 5.3 é a premissa do destino EAP 7.4 no contrato atual; o patch exato precisa vir das evidências da instalação/BOM aplicável. Relacionar separadamente declaração no POM, resolução Maven, API/testes, conteúdo do WAR e runtime, usando os estados já previstos no contrato: `CONFERIDO NAS EVIDENCIAS`, `PENDENTE` ou `CONFLITO`. Preservar `provided` para bibliotecas do servidor e `test` quando aplicável; não empacotar Hibernate no WAR como atalho para resolver uma divergência.

**Pesquisa documental da capacidade:** selecionar primeiro produto/versão/patch e a fonte oficial correspondente; localizar a seção que sustenta a decisão; registrar link, aplicabilidade e justificativa. Quando uma página não comprovar a versão necessária, devolver a lacuna e a coleta seguinte. Não recomendar automaticamente a última versão pública nem inventar uma versão de correção. Verificações de ciclo de vida, erratas e avisos de segurança devem registrar a data, pois podem mudar.

### 8.3. Subdomínio: verificações técnicas das dependências

#### DEP-03 — Verificar convergência e vulnerabilidades

- **Objetivo:** agregar evidências técnicas sobre divergências de versões e vulnerabilidades conhecidas.
- **Ferramentas:** Maven Enforcer, regra `dependencyConvergence`; OWASP Dependency-Check. [R12][R13]
- **Entradas:** dependências resolvidas, configuração das verificações e bases de vulnerabilidade disponíveis.
- **Saídas:** conflitos, caminhos envolvidos, achados de segurança e data/estado das bases consultadas.
- **Aceite:** tratar verificações de convergência e segurança separadamente; diferenciar falha de consulta de ausência de achados; confrontar alertas com avisos oficiais aplicáveis, inclusive versões de fornecedor.
- **Dependências:** DEP-01. DEP-02 é necessário quando os achados originarem recomendações de atualização para um alvo.

## 9. Domínio: migração da configuração JBoss EAP

### 9.1. Subdomínio: descoberta da instalação

#### JBS-01 — Inventariar a configuração de origem e o destino

- **Objetivo:** identificar a configuração efetiva e os recursos externos que participam da execução.
- **Entradas:** versões/patches, JDK, método de instalação, modo detectado e arquivos/consultas locais disponíveis. O primeiro recorte é standalone, já suportado pelo harness; domain mode fica identificado como expansão própria.
- **Saídas:** inventário de origem e destino, incluindo configuração ativa, extensões, subsistemas, módulos adicionais, drivers, datasources, segurança/SSO, mensageria, portas, caminhos e parâmetros de inicialização.
- **Assistência:** solicitar apenas informações ausentes; fornecer instruções de coleta por arquivos e Management CLI aplicáveis à versão. [R14]
- **Incremento no harness:** aproveitar identidade de instalação, home/base, XML ativo e CLI de `HarnessJbossRuntime.psm1`; ampliar a coleta de recursos. A seleção de `standaloneConfig` e os controles de identidade já existem.
- **Aceite:** identificar o XML realmente usado, inclusive configuração personalizada; registrar ajustes em `standalone.conf`/`standalone.conf.bat`, propriedades e recursos externos. Receber somente o XML não comprova inventário completo.
- **Dependências:** HAR-02 e HAR-03; modo assistido mínimo pode usar coleta de arquivos, sem acesso remoto ao servidor.

### 9.2. Subdomínio: estratégia de migração do servidor

#### JBS-02 — Verificar o caminho e planejar a configuração de destino

- **Objetivo:** determinar o procedimento aplicável ao par origem/destino e ao conjunto de componentes instalado.
- **Fontes e ferramentas:** documentação Red Hat e versão do JBoss Server Migration Tool distribuída com o produto selecionado. [R15][R16]
- **Entradas:** JBS-01, alvo exato, restrições e documentação aplicável.
- **Saídas:** caminho documentado, componentes preservados/transformados/substituídos, recursos pendentes e sequência automática/manual.
- **Aceite:** registrar versão da ferramenta e evidências; não pressupor que qualquer salto entre versões seja coberto; separar recurso tecnicamente migrável de recurso suportado no destino.
- **Dependências:** JBS-01 e HAR-03.

O plano deve produzir uma matriz por componente: **origem → equivalente no destino → ação → dependências externas → referência Red Hat → evidência de conclusão**. Ações possíveis: manter, transformar, substituir, remover com justificativa ou solicitar informação. Diferenciar extensão instalada, subsistema configurado e recurso efetivamente necessário à aplicação.

**Ponto documental a resolver para EAP 7.0/7.1 → 7.4:** o Migration Guide 7.4 menciona migração a partir de 6.4 e de todas as versões 7.x anteriores; a introdução do guia específico da ferramenta lista 6.4 e 7.3. O planejamento deve registrar essa divergência e esclarecer a aplicabilidade à distribuição/versão usada, recorrendo à documentação específica e, se necessário, ao suporte Red Hat. Este catálogo não declara o salto automaticamente suportado. [R15][R16]

### 9.3. Subdomínio: transformação da configuração

#### JBS-03 — Migrar e comparar a configuração do servidor

- **Objetivo:** produzir uma configuração candidata do destino, preservando a instalação de origem e documentando as diferenças.
- **Ferramentas:** JBoss Server Migration Tool e ajustes específicos via Management CLI quando documentados. [R14][R17]
- **Entradas:** plano JBS-02, instalação de destino preparada, origem preservada e parâmetros de migração.
- **Saídas:** configuração candidata, relatórios HTML/XML, logs, diferenças e tratamento de cada componente.
- **Aceite:** respeitar pré-requisitos oficiais, inclusive origem/destino parados durante o Server Migration Tool; preparar destino limpo; comparar inventário anterior e posterior; distinguir migração de configuração, cópia de deployments e migração de dados persistidos. [R17][R18]
- **Dependências:** JBS-02 e HAR-02/HAR-03.

**Integração e recuperação:** reutilizar os controles de identidade/estado antes de qualquer operação; apresentar diferenças da configuração candidata. O rollback hoje implementado pelo harness é de artefatos/releases de deploy e não restaura automaticamente XML, módulos, drivers ou dados. A fatia JBS-03 deve definir recuperação própria desses recursos, usando as convenções de backup existentes em `AGENTS.md`, antes de aplicar alterações.

O guia de migração 7.3→7.4 informa que a ferramenta pode remover subsistemas/extensões não suportados e migrar módulos referenciados. A conferência deve tornar toda remoção visível e registrar o tratamento de extensões adicionais. Não assumir que copiar um módulo comprova sua compatibilidade. [R19]

### 9.4. Subdomínio: assistência ao desenvolvedor

#### JBS-04 — Conduzir ajustes manuais e coleta de evidências

- **Objetivo:** permitir que o agente avance quando uma ação exige execução local pelo desenvolvedor ou informação indisponível.
- **Entradas:** lacuna identificada, componente, etapa atual e procedimento oficial.
- **Saídas:** tarefa objetiva, comando/procedimento, local de execução, resultado esperado e retorno solicitado.
- **Aceite:** não pedir novamente dados já disponíveis; adaptar instruções ao ambiente; receber e interpretar a evidência; atualizar a situação e emitir o próximo passo. Uma instrução entregue permanece pendente até comprovação.
- **Dependências:** HAR-03 e JBS-01; usar JBS-02 para instruções de alteração/migração.

Toda tarefa assistida deve informar:

1. Recurso e problema identificado.
2. Ação, pré-requisitos e instalação/configuração onde executar.
3. Comando ou procedimento aplicável, distinguindo parâmetros conhecidos dos que o desenvolvedor precisa preencher.
4. Resultado esperado e evidência a devolver, com segredos ocultados.
5. URL e seção oficial Red Hat.
6. Situação da execução, pendência e responsável, quando definido.

### 9.5. Subdomínio: validação do destino

#### JBS-05 — Validar servidor, recursos e integração com a aplicação

- **Objetivo:** comprovar que a configuração candidata atende ao recorte migrado.
- **Entradas:** configuração do destino, relatórios, aplicação de referência e critérios do plano.
- **Saídas:** verificações de inicialização, recursos e fluxos relevantes, com evidências e pendências.
- **Aceite:** integrar-se às tarefas JBoss já implementadas e aos controles de identidade/isolamento; analisar erros de boot e recursos faltantes; verificar conexões, autenticação/SSO, mensageria e demais componentes usados no recorte; executar o fluxo selecionado no destino. No perfil atual, validar o artefato corrigido no EAP 7.4, sem exigir o mesmo WAR no EAP 7.1. Separar “configuração gerada”, “servidor iniciado” e “fluxo validado”.
- **Dependências:** JBS-02 e configuração candidata produzida por JBS-03 ou pelo procedimento manual de JBS-04.

A Red Hat esclarece que o Server Migration Tool não determina a compatibilidade dos recursos implantados. A validação da aplicação permanece necessária. [R19]

## 10. Domínio: transformação e validação

### 10.1. Subdomínio: transformação por receitas

#### CHG-01 — Aplicar receitas OpenRewrite

- **Objetivo:** executar mudanças repetíveis quando houver receita aplicável e escopo confirmado.
- **Ferramenta:** OpenRewrite, núcleo e receitas com licenciamento adequado ao uso definido. O ecossistema contém componentes com licenças diferentes. [R20]
- **Entradas:** unidade de trabalho, receita/versão, projeto e configuração necessários à análise de tipos.
- **Saídas:** proposta de diferenças, ocorrências tratadas e relatório de execução.
- **Aceite:** comparar escopo esperado e alterações reais; verificar idempotência quando pertinente; avaliar efeitos em outros arquivos; manter o vínculo entre receita, apontamentos e validação. Receita não substitui testes e reanálise.
- **Dependências:** HAR-02/HAR-03 e plano de OBJ-02; DEP-01 conforme a integração Maven.

### 10.2. Subdomínio: correção contextual pelo agente

#### CHG-02 — Implementar alterações orientadas por evidências

- **Objetivo:** tratar problemas que exigem julgamento contextual ou não são cobertos por receita adequada.
- **Entradas:** plano, código selecionado, restrições, documentação e critérios de aceite.
- **Saídas:** diferenças revisáveis, justificativa por mudança e validações a executar.
- **Aceite:** resolver a unidade de trabalho delimitada; explicitar decisões e efeitos; preservar comportamento fora do escopo acordado; registrar hipóteses não comprovadas e ampliar investigação quando necessário.
- **Dependências:** OBJ-02 e HAR-03; SRC-06 quando houver necessidade de montar um pacote de contexto.

### 10.3. Subdomínio: comprovação e encerramento

#### CHG-03 — Validar a mudança e encerrar a unidade de trabalho

- **Objetivo:** comparar o estado anterior e posterior segundo critérios definidos no plano.
- **Entradas:** baseline, diferenças, testes e analisadores pertinentes ao objetivo.
- **Saídas:** compilação/testes, reanálises, comparação dos apontamentos e conclusão fundamentada.
- **Aceite:** reutilizar build/testes, Sonar, MTA e checkpoints existentes; reexecutar verificações relevantes na configuração correta; distinguir corrigido, persistente, não reproduzido e não verificado; registrar desvios de configuração entre análises. Preservar a política vigente do harness e apresentar o Quality Gate corporativo separadamente. Para migração de servidor, incorporar JBS-05.
- **Dependências:** HAR-02/HAR-03, critérios de OBJ-02 ou JBS-02 e a mudança a validar. OBJ-01 quando houver comparação de relatórios.

**Política vigente do perfil EAP:** cobertura de 85% é meta com aviso, não gate de entrega; compilação/testes com falha continuam falhos, sem mascarar códigos de saída ou pular testes. Blocker/High reprovam a avaliação Sonar; cobertura e aumento da contagem de issues geram avisos, com Quality Gate do servidor separado. Novo MTA e Sonar antes/depois são checklist não bloqueante e ficam pendentes quando ausentes. Comparar contagens não comprova que um achado específico foi corrigido; essa conclusão exige correspondência e evidência adequadas. Não fabricar baseline anterior após a mudança.

Separar três resultados: **mudança implementada**, **validações técnicas realizadas** e **aceite humano**. Sem reanálise comparável, não afirmar desaparecimento de achados ou conclusão global; registrar cobertura limitada, conforme o contrato atual.

## 11. Contrato comum das capacidades

Os nomes técnicos e estruturas desta seção são requisitos de informação para as extensões. Mapear primeiro esses campos nos contratos existentes; adicionar apenas as lacunas com compatibilidade. Não representam APIs nativas das ferramentas nem determinam a substituição dos schemas atuais.

| Grupo | Campos mínimos |
| --- | --- |
| Identidade | ID estável, nome, versão do contrato, descrição e quando usar. |
| Entradas | Objetivo, escopo, parâmetros tipados, perfil/alvo quando necessário e pré-requisitos; adaptar a origem sem exigir MTA em todo trabalho. |
| Executor | Adaptador, versão da ferramenta, runtime, modo local e timeout. |
| Efeitos | Leitura, geração de artefatos, alteração de fonte/POM, alteração de servidor ou operação de runtime; indicar necessidade de conectividade e possíveis downloads. |
| Resultados | Dados estruturados, artefatos, código de saída e proveniência. |
| Cobertura | Escopo efetivo, itens omitidos, referências não resolvidas e truncamento. |
| Evidências | Arquivos/localizações, configuração de análise, fontes oficiais e data; identificadores de conteúdo apenas quando úteis ao artefato/cache, sem novo gate Git/hash. |
| Continuidade | Pendências, entradas ainda necessárias e próximos passos possíveis. |

**Situação da capacidade no backlog:** a priorizar, planejada, em implementação, implementada, validada ou adiada.

**Situação de uma execução:** concluída, parcial, falhou ou requer entrada.

**Pendência:** informação, ação ou evidência que falta; deve ter descrição própria e não substituir a situação.

**Grau de confirmação de um parecer:** documentado, inferido ou não confirmado. Registrar validação prática separadamente.

Essas situações descrevem capacidades e execuções novas. Elas não substituem os campos de decisão/andamento dos registros de migração, nem equivalem a GO ou aceite.

As descrições para o agente devem explicar limites concretos: busca textual não resolve símbolos; AST não comprova fluxo de execução; grafo de código não define domínio de negócio; comparação de versões não comprova suporte; geração de XML não comprova migração funcional.

### 11.1. Exemplo de descrição entregue ao agente

```yaml
id: DEP-02
nome: avaliar-dependencia-para-alvo
descricao: Avalia uma dependência resolvida contra um alvo explícito e justifica a recomendação com fontes oficiais.
usar_quando:
  - Uma issue aponta incompatibilidade de biblioteca.
  - É necessário confirmar versão, BOM ou escopo para o destino.
entradas:
  - módulo e coordenadas da dependência
  - inventário DEP-01 ou lacunas conhecidas
  - produto, versão, patch e JDK de destino
saida:
  - decisão por dimensão, evidências oficiais e validações pendentes
efeitos: consulta e geração de parecer; não altera POM
conectividade: documentação oficial e repositórios conforme configuração autorizada
limites:
  - Versão mais recente não comprova compatibilidade nem suporte.
  - Evidência insuficiente produz parecer não confirmado.
proximo_passo: incorporar proposta ao lote; executar mudança conforme autorização vigente
```

Esse exemplo descreve conteúdo do catálogo; não fixa um novo formato de configuração. O adaptador de engine traduz esse conteúdo para as ferramentas/instruções que o engine consegue utilizar.

## 12. Matriz de priorização

Os **incrementos** abaixo estão a priorizar. Isso não significa que as capacidades estejam ausentes: várias ampliam mecanismos já existentes ou em implementação. A coluna “Prioridade escolhida” é a decisão do responsável; nenhuma sugestão representa compromisso de execução.

Use **P1 — próximo ciclo**, **P2 — ciclo posterior**, **P3 — evolução** ou **Adiar**. A sugestão considera primeiro um piloto de migração EAP com análise de apontamentos e dependências. A coluna “Pré-requisitos principais” resume as fichas; relações condicionais permanecem descritas nelas.

| ID | Capacidade | Sugestão | Prioridade escolhida | Pré-requisitos principais |
| --- | --- | --- | --- | --- |
| HAR-01 | Ampliar catálogo/instruções existentes | P1, apenas lacunas | A definir | Revisar mecanismos existentes |
| HAR-02 | Estender executor e runtimes existentes | P1, apenas lacunas | A definir | HAR-01 |
| HAR-03 | Enriquecer evidências e validade | P1, apenas lacunas | A definir | HAR-02 |
| HAR-04 | Explicitar contratos e separar perfis | P1, contrato mínimo; extração posterior | A definir | HAR-01/03; preservar fluxo EAP |
| SRC-01 | Busca textual | P1 | A definir | HAR-02/03 |
| SRC-02 | Busca estrutural | P2 | A definir | HAR-02/03 |
| SRC-03 | Símbolos e referências Java | P2 | A definir | HAR-02/03; DEP-01 conforme projeto |
| SRC-04 | Relações arquiteturais | P3 | A definir | HAR-02/03; bytecode |
| SRC-05 | Fluxo de dados | P3 | A definir | HAR-02/03 |
| SRC-06 | Contexto por objetivo | P1, versão mínima | A definir | HAR-03; seleção de contexto |
| OBJ-01 | Ampliar ingestão de apontamentos | P1, aproveitar MTA existente | A definir | HAR-03; relatório real |
| OBJ-02 | Enriquecer investigação e lote existente | P1 | A definir | HAR-01/02/03; HAR-04 para entrada sem MTA |
| DEP-01 | Completar inventário Maven efetivo | P1 | A definir | HAR-02/03 |
| DEP-02 | Parecer de compatibilidade com alvo | P1, recorte piloto | A definir | DEP-01; documentação aplicável |
| DEP-03 | Convergência e vulnerabilidades | P2 | A definir | DEP-01 |
| JBS-01 | Inventário JBoss | P1 | A definir | HAR-02/03 |
| JBS-02 | Caminho e plano de migração | P1 | A definir | JBS-01; documentação aplicável |
| JBS-03 | Transformação de configuração | P2 | A definir | JBS-02 |
| JBS-04 | Assistência ao desenvolvedor | P1, versão mínima | A definir | JBS-01; JBS-02 para alterações |
| JBS-05 | Validação do destino | P1, fluxo piloto | A definir | JBS-02; configuração candidata |
| CHG-01 | Receitas OpenRewrite | P2 | A definir | OBJ-02; HAR-02/03 |
| CHG-02 | Correção contextual pelo agente | P1, reutilizar existente | A definir | OBJ-02; HAR-03 |
| CHG-03 | Ampliar validação e encerramento existentes | P1, apenas lacunas | A definir | Plano, mudança e HAR-02/03 |

### 12.1. Como escolher o próximo incremento

Para cada capacidade, avaliar: cobertura atual, lacuna, problema concreto que resolve agora, frequência de uso, risco que reduz, esforço incremental, pré-requisitos e facilidade de comprovar valor. Estimar esforço apenas depois de verificar o repositório e experimentar a ferramenta na amostra. Uma dependência já atendida pelo harness é reutilizada e não vira automaticamente outra implementação.

Não é necessário concluir todas as sugestões P1 para iniciar. Selecionar um fluxo vertical pequeno e implementar somente as capacidades necessárias a ele.

### 12.2. Pilotos que podem ser escolhidos separadamente

| Piloto | Recorte | Capacidades incrementais | Evidência de valor |
| --- | --- | --- | --- |
| A — Dependência para o destino | Um módulo e uma dependência relevante para EAP 7.4. | DEP-01/02 e lacunas HAR; usar planejamento/validação atuais. | POM efetivo e árvore rastreáveis; recomendação ou lacuna explícita, com link oficial e local da alteração. |
| B — Configuração JBoss assistida | Um standalone e os recursos usados pelo módulo, começando por driver/datasource ou outro componente prioritário. | JBS-01/02/04/05; automação JBS-03 depois. | Inventário, matriz origem/destino, instruções Red Hat e recurso validado no destino. |
| C — Contexto para uma issue | Um apontamento MTA ou Sonar já disponível. | SRC-01/06, OBJ-01/02 e lacunas HAR; adicionar SRC-03 apenas se necessário. | Recorte suficiente para investigar/corrigir; cobertura e validações registradas. |
| D — Refatoração DDD delimitada | Um caso de uso com regras confirmadas, fora do lote de migração mínima. | HAR-04, OBJ-02, SRC-01/03/06 e CHG-02/03. | Hipótese de responsabilidades confirmada e refatoração com comportamento verificado. |
| E — Investigação de segurança | Um achado Fortify real, com caminho e contexto disponíveis. | Adaptador OBJ-01; SRC-01/03 e SRC-05 quando trouxer valor. | Caminho investigado, correção justificada e situação da revalidação no analisador original. |

**Sugestão de primeira escolha:** piloto A, por ampliar diretamente a comparação estática de POM já existente e produzir uma decisão verificável sem exigir grafo de código. Se configuração de servidor for o bloqueio imediato, escolher B. As prioridades escolhidas continuam abertas; não é necessário combinar A, B e C em um único lote.

No piloto B, a configuração candidata pode ser preparada por instruções assistidas antes da automação JBS-03. No piloto C, uma correção pode usar o agente atual antes da integração OpenRewrite. Encerrar cada piloto exige o aceite definido para seu próprio objetivo; um parecer de análise não deve ser declarado como migração funcional concluída.

**Critério para expandir:** o piloto demonstrou que as evidências permitem retomar o trabalho, identificar lacunas e verificar a correção; então automatizar a próxima etapa com maior custo ou recorrência.

### 12.3. Relação com as frentes mais amplas da estratégia

Este catálogo complementa as frentes já propostas: consolidar a base JBoss, explicitar/extrair contratos comuns, pilotar Node.js/TypeScript e IntelliJ, ampliar a orquestração, introduzir Quarkus, avaliar engines alternativos e aplicar o núcleo ao SDLC e à modernização.

HAR-04 estabelece os pontos de separação; não condiciona o catálogo a uma reescrita. Uma rotina de preparação pode ser o piloto Node.js/TypeScript, preservando o ponto de entrada PowerShell e demonstrando equivalência de conteúdo/evidência. IntelliJ pode iniciar com comandos externos sobre os scripts atuais. Portabilidade de IDE, tecnologia e engine são avaliações distintas; a migração JBoss não deve aguardar a conclusão delas.

Medir os pilotos com escopos comparáveis: tempo de preparação/investigação, retrabalho, falhas detectadas, esforço humano, consumo de contexto/custo do engine e capacidade de retomar a partir das evidências. Esses resultados orientam a próxima prioridade, sem antecipar uma estimativa de ganho ainda não observada.

## 13. Planejamento e implementação com o Codex

### 13.1. Inspecionar o harness antes de alterar

1. Reler `AGENTS.md`, o contrato vigente e as ADRs ao iniciar a implementação; conferir diferenças em relação ao commit examinado por esta proposta.
2. Relacionar a capacidade selecionada com componentes existentes: reutilizar, estender, integrar ferramenta ou criar componente ausente. Documentar a lacuna e evitar duplicação de execução, configuração e registros.
3. Confirmar ferramenta, licença, versão, runtime e formato de saída na máquina-alvo.
4. Identificar uma amostra real e o critério de sucesso; não começar pela execução sobre todo o repositório.

Como **evolução do harness**, a implementação segue a branch `harness/<objetivo>` criada a partir da principal e atualiza `tasks/plan.md`/`tasks/todo.md`, conforme `AGENTS.md`. Isso é distinto do trabalho na aplicação, cujo Git é informativo e cujo planejamento usa os caminhos do recibo. Este documento é uma proposta; sua criação não alterou o repositório remoto.

### 13.2. Pontos de integração para o Codex

| Capacidades | Reutilizar/estender | Lacuna a implementar |
| --- | --- | --- |
| HAR-01/02/04 | `Harness.psm1`, configuração e `.vscode/tasks.json`; contrato em `doc/especificacoes/planejamento-copilot.md`. | Catálogo descritivo e adaptadores; separar seleção de perfil/objetivo sem romper entradas atuais. |
| HAR-03, SRC-06 | `HarnessPlanning.psm1`, recibos/contextos e evidências referenciadas. | Cobertura do recorte, seleção de trechos e validade do resultado; preservar `ContractSnapshot`. |
| SRC-01 a SRC-05 | Executor/configuração atuais e contexto Maven quando necessário. | Adaptadores de análise de código; não confundir com o índice de projetos existente. |
| OBJ-01/02 | `HarnessProjectIndex.psm1`, `HarnessPlanning.psm1`, `HarnessSonarApi.psm1`, registros `MigrationPath`. | Normalização, vínculo de achados ao código e entrada sem MTA; novo adaptador Fortify. |
| DEP-01/02/03 | `Compare-MtaPlanningPom`, `HarnessBuild.psm1`, `doc/guias/tools/maven.md`. | Coleta Maven controlada, parecer documental e verificações opcionais. |
| JBS-01 a JBS-05 | `HarnessJboss.psm1`, `HarnessJbossConfig.psm1`, `HarnessJbossRuntime.psm1`, artefatos/releases e guia JBoss. | Inventário profundo, caminho documentado, transformação/assistência e recuperação da configuração. |
| CHG-01/02 | Preparação de implementação, plano/to-do e prompts do fluxo atual. | Adaptador OpenRewrite e incorporação das evidências adicionais na correção contextual. |
| CHG-03 | Módulos de build/Sonar/JBoss e critérios vigentes. | Validações específicas da nova capacidade e comparação por achado quando necessária. |

Os nomes acima são pontos de partida observados, não autorização para ampliar indiscriminadamente os módulos. Uma nova responsabilidade coesa pode exigir módulo próprio, mantendo as interfaces externas.

### 13.3. Planejar uma capacidade por unidade de implementação

Preencher a ficha abaixo ao selecionar um item. Ela pode se tornar uma issue ou um documento de plano no próprio repositório.

```markdown
# [ID] Nome da capacidade

## Objetivo e recorte
- Problema a resolver:
- Objetivo de uso: MTA / Sonar / Fortify / DDD / Maven / JBoss
- Módulo, arquivos ou configuração da amostra:
- Alvo e restrições:
- Perfil tecnológico, engine e IDE da fatia:

## Integração com o harness
- Evidência da capacidade já existente e sua cobertura:
- Commit-base e diferença relevante desde esta proposta:
- Lacuna concreta a tratar:
- Tipo de evolução: reutilizar / estender / integrar ferramenta / criar ausente
- Componentes existentes a reutilizar:
- Contratos, prompts, comandos e consumidores a preservar:
- Adaptador/ferramenta e versão:
- Entradas e saídas:
- Comando local e tarefa VS Code:
- Caminhos de plano/to-do e contrato vigente:
- Efeitos e artefatos gerados:
- Dependências entre capacidades:

## Implementação e aceite
- Incremento mínimo utilizável:
- Evidências e limites que devem ser registrados:
- Casos relevantes de sucesso, falha e resultado parcial:
- Critérios objetivos de aceite:
- Verificação de que o fluxo existente continua funcionando:
- Recuperação da mudança quando aplicável:
- Fontes oficiais e dúvidas pendentes:
```

### 13.4. Concluir com integração e evidência

- Disponibilizar um comando utilizável e a descrição da capacidade para o agente.
- Validar com a amostra escolhida, incluindo uma falha relevante ou lacuna real do adaptador quando aplicável.
- Registrar resultado, cobertura e limitações; evitar testes que apenas repitam detalhes internos sem verificar o contrato.
- Demonstrar a chamada pelo harness e pela tarefa local correspondente, quando prevista.
- Atualizar catálogo e situação da capacidade, distinguindo implementada de validada no ambiente-alvo.

**Orientação de escopo ao Codex:** tratar este documento como evolução do harness presente no repositório. Primeiro mapear o existente e apresentar o incremento; depois planejar e implementar apenas os IDs selecionados. Preservar fluxo, artefatos, tarefas e revisões vigentes. Outras capacidades permanecem backlog; refatorações adicionais precisam de relação concreta com o incremento.

## 14. Fontes oficiais e limites de aplicação

### 14.1. Evidências do projeto-base

As referências abaixo estão fixadas no commit examinado. Elas fundamentam o estado atual, as restrições e a direção da evolução; não comprovam execução de testes nesta revisão.

| Documento/código | O que fundamenta |
| --- | --- |
| [README](https://github.com/edoardo-bianco/jboss-mta-harness/blob/de5975096d0848b91b0d45aad00d291787a89bb3/README.md) e [AGENTS.md](https://github.com/edoardo-bianco/jboss-mta-harness/blob/de5975096d0848b91b0d45aad00d291787a89bb3/AGENTS.md) | Escopo, operação e convenções para trabalhar no harness. |
| [Estratégia do harness](https://github.com/edoardo-bianco/jboss-mta-harness/blob/de5975096d0848b91b0d45aad00d291787a89bb3/doc/estrategia/estrategia-harness_.md) | SDLC/modernização, núcleo, plugins, engines, IDEs e sequência de pilotos. |
| [Contrato de planejamento](https://github.com/edoardo-bianco/jboss-mta-harness/blob/de5975096d0848b91b0d45aad00d291787a89bb3/doc/especificacoes/planejamento-copilot.md) | Recibos, origem, um lote por frente, perfil EAP, GO, validações e aceite. |
| [ADR-0002](https://github.com/edoardo-bianco/jboss-mta-harness/blob/de5975096d0848b91b0d45aad00d291787a89bb3/doc/adr/0002-separacao-harness-e-migracao-progressiva.md) e [ADR-0004](https://github.com/edoardo-bianco/jboss-mta-harness/blob/de5975096d0848b91b0d45aad00d291787a89bb3/doc/adr/0004-git-informativo-sem-controle-de-branches.md) | Separação harness/aplicação e Git informativo. |
| [HarnessPlanning.psm1](https://github.com/edoardo-bianco/jboss-mta-harness/blob/de5975096d0848b91b0d45aad00d291787a89bb3/scripts/HarnessPlanning.psm1) e [HarnessProjectIndex.psm1](https://github.com/edoardo-bianco/jboss-mta-harness/blob/de5975096d0848b91b0d45aad00d291787a89bb3/scripts/HarnessProjectIndex.psm1) | Preparação de contexto, comparação estática do POM e índice atual de projetos/MTA. |
| [Harness.psm1](https://github.com/edoardo-bianco/jboss-mta-harness/blob/de5975096d0848b91b0d45aad00d291787a89bb3/scripts/Harness.psm1) e [tarefas VS Code](https://github.com/edoardo-bianco/jboss-mta-harness/blob/de5975096d0848b91b0d45aad00d291787a89bb3/.vscode/tasks.json) | Runtime PowerShell, perfil atual e entradas operacionais. |
| [Guia Maven](https://github.com/edoardo-bianco/jboss-mta-harness/blob/de5975096d0848b91b0d45aad00d291787a89bb3/doc/guias/tools/maven.md) e [HarnessSonarApi.psm1](https://github.com/edoardo-bianco/jboss-mta-harness/blob/de5975096d0848b91b0d45aad00d291787a89bb3/scripts/HarnessSonarApi.psm1) | Configuração Maven existente e integração Sonar já disponível. |
| [Guia JBoss](https://github.com/edoardo-bianco/jboss-mta-harness/blob/de5975096d0848b91b0d45aad00d291787a89bb3/doc/guias/tools/jboss.md), [HarnessJbossRuntime.psm1](https://github.com/edoardo-bianco/jboss-mta-harness/blob/de5975096d0848b91b0d45aad00d291787a89bb3/scripts/HarnessJbossRuntime.psm1) e [HarnessJboss.psm1](https://github.com/edoardo-bianco/jboss-mta-harness/blob/de5975096d0848b91b0d45aad00d291787a89bb3/scripts/HarnessJboss.psm1) | Identidade do servidor, XML ativo, CLI, ciclo local e rollback de releases. |

### 14.2. Fontes primárias das ferramentas

As capacidades, prioridades, IDs e contratos deste documento são propostas de arquitetura do harness. As fontes abaixo sustentam funcionalidades e limites das ferramentas; não constituem endosso dos projetos ao desenho completo proposto. Referências consultadas em 04/10/2026; verificar novamente a documentação da versão fixada na implementação.

| Ref. | Fonte primária | Aplicação no catálogo |
| --- | --- | --- |
| R01 | [ripgrep — repositório oficial](https://github.com/BurntSushi/ripgrep) | Busca textual, filtros e execução local. |
| R02 | [ast-grep — introdução](https://ast-grep.github.io/guide/introduction.html) e [linguagens suportadas](https://ast-grep.github.io/reference/languages.html) | Correspondência estrutural e suporte a Java. |
| R03 | [JavaParser e Symbol Solver](https://github.com/javaparser/javaparser) | AST, resolução de símbolos e integração como biblioteca. |
| R04 | [jQAssistant — manual](https://jqassistant.github.io/jqassistant/current/) | Modelo de grafo, scanner Java e relações consultáveis. |
| R05 | [Joern — frontend Java](https://docs.joern.io/frontends/java/) e [CPG Slicing](https://docs.joern.io/cpg-slicing/) | Análise Java, recortes de fluxo e saída JSON. |
| R06 | [Repomix — guia](https://repomix.com/guide/) e [compressão de código](https://repomix.com/guide/code-compress) | Empacotamento e limites da compressão. |
| R07 | [Red Hat — MTA, uso da CLI](https://docs.redhat.com/en/documentation/migration_toolkit_for_applications/8.1/html-single/using_the_migration_toolkit_for_applications_command-line_interface/index) | Alvos e execução do analisador; usar a documentação da versão efetivamente instalada. |
| R08 | [Maven Help Plugin — effective-pom](https://maven.apache.org/plugins/maven-help-plugin/effective-pom-mojo.html) | POM efetivo, perfis e origem dos elementos. |
| R09 | [Maven Dependency Plugin — dependency:tree](https://maven.apache.org/plugins/maven-dependency-plugin/tree-mojo.html) | Árvore resolvida, formatos e nós omitidos. |
| R10 | [Maven — mecanismo de dependências](https://maven.apache.org/guides/introduction/introduction-to-dependency-mechanism.html) | Mediação, gerenciamento, BOMs, escopos e distinção de plugins. |
| R11 | [Versions — compare-dependencies](https://www.mojohaus.org/versions/versions-maven-plugin/compare-dependencies-mojo.html) e [display-dependency-updates](https://www.mojohaus.org/versions/versions-maven-plugin/display-dependency-updates-mojo.html) | Comparação com referência e descoberta de candidatos. |
| R12 | [Maven Enforcer — Dependency Convergence](https://maven.apache.org/enforcer/enforcer-rules/dependencyConvergence.html) | Divergências de versões entre caminhos. |
| R13 | [OWASP Dependency-Check](https://owasp.org/projects/dependency-check) | Identificação de vulnerabilidades conhecidas. |
| R14 | [Red Hat EAP 7.4 — Management CLI Guide](https://docs.redhat.com/en/documentation/red_hat_jboss_enterprise_application_platform/7.4/html-single/management_cli_guide/index) | Consulta e administração por CLI. |
| R15 | [Red Hat EAP 7.4 — Migration Guide](https://docs.redhat.com/en/documentation/red_hat_jboss_enterprise_application_platform/7.4/html-single/migration_guide/index) | Mudanças de configuração, preparação e seção 3.2 sobre a ferramenta. |
| R16 | [Red Hat EAP 7.4 — Server Migration Tool, introdução](https://docs.redhat.com/en/documentation/red_hat_jboss_enterprise_application_platform/7.4/html/using_the_jboss_server_migration_tool/migration_introduction) | Distribuição da ferramenta e caminhos declarados. |
| R17 | [Red Hat EAP 7.4 — execução do Server Migration Tool](https://docs.redhat.com/en/documentation/red_hat_jboss_enterprise_application_platform/7.4/html/using_the_jboss_server_migration_tool/running_the_server_migration_tool) | Modos de execução e servidores parados. |
| R18 | [Red Hat EAP 7.4 — guia completo do Server Migration Tool](https://docs.redhat.com/en/documentation/red_hat_jboss_enterprise_application_platform/7.4/html-single/using_the_jboss_server_migration_tool/index) | Destino limpo, configuração da ferramenta e relatórios HTML/XML. |
| R19 | [Red Hat — configurações EAP 7.3 para 7.4](https://docs.redhat.com/en/documentation/red_hat_jboss_enterprise_application_platform/7.4/html/using_the_jboss_server_migration_tool/migrating_jboss_eap_7_3_configurations_to_jboss_eap_7_4) | Remoção de subsistemas, módulos e limites relativos a deployments; não generalizar a outros saltos. |
| R20 | [OpenRewrite — repositório oficial](https://github.com/openrewrite/rewrite) e [árvores semânticas](https://docs.openrewrite.org/concepts-and-explanations/lossless-semantic-trees) | Transformação por receitas, atribuição de tipos e licenciamento do ecossistema. |

Para estender o adaptador Sonar e implementar o adaptador Fortify, acrescentar as referências oficiais das versões e interfaces efetivamente utilizadas. A presença da API Sonar no harness foi verificada; equivalência de campos entre versões/produtos e uma integração Fortify pronta não são presumidas.
