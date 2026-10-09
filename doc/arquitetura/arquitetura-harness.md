---
html:
  embed_local_images: true
  embed_svg: true
  offline: true
---

# Arquitetura do Engineering Harness

**Data:** 09/10/2026. **Estado:** arquitetura existente e evolução proposta.
**Baseline operacional:** `main` em `17f80c22084dd26437eda3bd106698dcacc8a33e`, após a integração de sprints pela [PR #26](https://github.com/edoardo-bianco/jboss-mta-harness/pull/26). Esta revisão incorpora a documentação de arquitetura produzida sobre `6390808` e atualiza sua leitura da base entregue. As decisões propostas estão registradas na [ADR-0008](../adr/0008-nucleo-perfis-e-plataforma-do-harness.md).

## 1. Objetivo

Evoluir o produto de migração JBoss para um harness de engenharia organizado por domínios, subdomínios e capacidades, preservando as decisões que sustentam sua operação. A separação entre núcleo, perfis, ferramentas, clientes de agentes e IDEs permite ampliar os cenários de uso com manutenção sustentável, operação humana direta e contexto verificável para trabalho assistido por IA.

## 2. Contexto

O harness atual organiza a migração EAP com PowerShell, Run Tasks do VS Code, configurações locais, documentos, evidências e agentes. A [estratégia](../estrategia/estrategia-harness_.md), o [catálogo de capacidades](../features/evolucao-harness-dominios-capacidades-priorizacao.md) e sua [conciliação](../estrategia/conciliacao-evolucao-harness.md) ampliam essa direção para desenvolvimento, qualidade e modernização, apoiados nos fundamentos de [harness engineering](#anexo-a--fundamentos-de-harness-engineering). Para atender novos cenários, a arquitetura proposta extrai um núcleo comum e introduz perfis e interfaces independentes de IDE. Essas estruturas, a extensão própria e a integração IntelliJ ainda não fazem parte da base operacional. O planejamento por sprints já integra a base entregue, com contexto, estimativas e validação determinística; seu primeiro ensaio corporativo permanece pendente.

## 3. Estratégia

Evoluir por capacidades verificáveis, preservando o ciclo objetivo → contexto → proposta → decisão humana → execução → evidências → aceite. Adotar DDD pragmático em um monólito modular local, com portas e adaptadores: TypeScript/Node.js no núcleo e nas interfaces; ferramentas especializadas podem usar Java ou outra linguagem justificada. Perfis compõem regras, ferramentas, documentação e papéis de agentes. CLI, menu, MCP e IDEs acessam os mesmos casos de uso. A transição reaproveita PowerShell e contratos históricos até comprovar equivalência de cada substituição.

## 4. Arquitetura existente

### 4.1. Estrutura e tecnologias comprovadas

| Elemento | Tecnologia e responsabilidade atual | Evidência |
| --- | --- | --- |
| Entrada operacional | VS Code, tarefas JSON e workspace multifolder; scripts também podem ser chamados pelo terminal. Menus e abertura de arquivos estão acoplados ao fluxo Windows/VS Code. | [Run Tasks](../../.vscode/tasks.json), [workspace](../guias/tools/workspace.md) |
| Automação | Windows PowerShell 5.1, `.ps1` como entradas e `.psm1` como módulos. Regras, I/O, menus e processos coexistem em parte desses módulos. | [Scripts](../../scripts), [Harness.psm1](../../scripts/Harness.psm1) |
| Configuração | JSON local reúne projetos, ferramentas, EAP, Sonar e MTA. O campo `mta.profile` seleciona o perfil de análise; o sistema geral de perfis pertence à arquitetura proposta. | [Configuração de exemplo](../../config/harness.example.json) |
| Estado e conhecimento | JSON, Markdown, snapshots, SHA-256, logs e ZIP sob `.harness/`; templates e contratos versionados. Sem banco de dados central. | [Planejamento](../especificacoes/planejamento-copilot.md), [compartilhamento](../guias/tools/compartilhamento-contextos.md) |
| MCP opcional | JavaScript ESM em Node.js; SDK `@modelcontextprotocol/server` 2.3.1, Zod 4.6.5 e `smol-toml` 1.9.0. Servidor `stdio` com três consultas de leitura; ponte chama PowerShell com entrada/saída JSON. O pacote declara Node `>=20`, não uma política atualizada de suporte LTS. | [Pacote](../../mcp/issues/package.json), [servidor](../../mcp/issues/server.mjs), [ponte](../../mcp/issues/bridge.mjs), [contrato](../../mcp/issues/contract.mjs) |
| Build e cobertura | Maven 3 e JDK 8 para a aplicação; fases delimitadas, logs e recibos. JaCoCo depende da instrumentação e dos relatórios do projeto; o harness não cria cobertura por conta própria. | [Build](../guias/tools/maven.md), [módulo](../../scripts/HarnessBuild.psm1) |
| Diagnóstico e qualidade | MTA CLI produz diagnóstico e snapshot; Sonar usa scanner Maven e API, com runtime próprio, coleta CE/Gate/métricas/issues e revisão local dos critérios. | [MTA](../guias/tools/mta.md), [Sonar](../guias/tools/sonar.md) |
| Runtime da aplicação | Instalações JBoss EAP 7.1/7.4 standalone, Management CLI, artefatos WAR/EAR e debug Java remoto. Java 8, `javax.*` e Hibernate 5.3 quando aplicável são regras do alvo de migração. | [JBoss](../guias/tools/jboss.md), [contrato técnico](../especificacoes/planejamento-copilot.md) |
| Agentes e instruções | Prompts Markdown para Copilot/DevSquad; skill comum e helpers declarados para Copilot e Codex. O cliente oferece modelo, ferramentas e delegação; o harness fornece procedimentos e contexto. | [Orientação](../guias/orientacao-migracao.md), [prompts](../../.github/prompts), [papéis](../../.agents/skills/orientar-migracao/references/papeis.md) |
| Planejamento macro | Motor puro em PowerShell calcula sprints de 14 dias, capacidade por papel, dependências, janelas e limites. Contexto, dados, Markdown e validação ficam sob `.harness/sprints/`, com revisões preservadas. | [Motor](../../scripts/HarnessSprintSimulation.ps1), [orquestração](../../scripts/HarnessSprintPlanning.psm1), [contrato](../especificacoes/planejamento-sprints.md) |
| Verificação do harness | Scripts de teste PowerShell e testes Node de contrato, configuração, integração e ciclo de vida do MCP. | [Testes](../../tests), [testes MCP](../../mcp/issues/tests) |

Node executa o adaptador MCP; Java executa aplicações e ferramentas Java. Trocar a linguagem do harness não muda o alvo das aplicações. Git é ferramenta de desenvolvimento e fonte informativa, não coordenador de frentes de migração.

### 4.2. Decisões implementadas que permanecem

| Decisão consolidada | Consequência arquitetural | Fonte normativa |
| --- | --- | --- |
| Preparar contexto e acionar o agente são etapas diferentes. | Recibos e prompts existem independentemente do cliente; preparar não envia nem executa o pedido. | [ADR-0001](../adr/0001-contexto-copilot.md), atualizada pela ADR-0005 |
| Evolução do harness e corretiva de aplicação têm ciclos e destinos próprios. | `tasks/` pertence ao produto; `PlanPath`/`TodoPath` pertencem à solicitação da aplicação. | [ADR-0002](../adr/0002-separacao-harness-e-migracao-progressiva.md) |
| Git é informativo na migração. | Branch/HEAD divergentes não invalidam contexto automaticamente; gestão e integração pertencem ao desenvolvedor. A conveniência de criar branch exige sua escolha explícita. | [ADR-0004](../adr/0004-git-informativo-sem-controle-de-branches.md), que substitui o controle da [ADR-0003](../adr/0003-projeto-branch-e-concorrencia-da-migracao.md) |
| Registro atual concentra as escolhas; planejamento aceita MTA ou evidências. | Retomada usa vínculos e origem, nunca recência; mudança de base tem regras explícitas e preserva `Previous`. | [ADR-0005](../adr/0005-planejamento-orientado-pelo-registro.md) |
| Categoria, projeto e issue delimitam os dossiês. | Sequências de priorização separadas; fichas e anexos consolidados sustentam uma proposta identificável. | [ADR-0006](../adr/0006-categorias-e-dossie-por-issue.md) |
| Compartilhar preserva identidade e origem. | Importação exige associação ao `Source` local, hashes, destinos livres e cadeia `ImportedFrom`; não concede GO ou aceite. | [ADR-0007](../adr/0007-compartilhamento-de-contextos.md) |
| MCP é uma entrada opcional de leitura. | As três consultas não marcam exame, não alteram decisões e não substituem conferência do código. | [Contrato de consultas](../especificacoes/consultas-issues.md) |
| Cronograma macro passa por validação determinística. | B0 e inclusões históricas são preservadas; `Previous` vincula revisões e `atual.json` só aponta para uma publicação consistente. Limites consideram fases consumidas; falhas de prazo/capacidade e riscos têm justificativas calculadas. | [Contrato de sprints](../especificacoes/planejamento-sprints.md) |

Essas decisões sustentam os contratos operacionais e a continuidade do trabalho. A evolução preserva decisões e evidências históricas; homologações pendentes permanecem no [acompanhamento do harness](../../tasks/todo.md).

## 5. Arquitetura de comportamento

### 5.1. Matriz completa das Run Tasks da baseline

A jornada operacional parte da configuração do ambiente, passa pelo diagnóstico e planejamento e chega à implementação, verificação e operação da aplicação. O [cheat sheet das Run Tasks](cheat-sheet-run-tasks.md) reúne a matriz completa da baseline, com domínio/subdomínio, efeitos, relação com agentes e referências de implementação e uso.

### 5.2. Fluxos e autoridade

| Momento | Regra determinística do harness | Trabalho humano ou assistido |
| --- | --- | --- |
| Descobrir e orientar | Resolver projeto, perfil e vínculos; expor apenas capacidades disponíveis. | Orientador recupera o estado e indica uma próxima ação. |
| Investigar | Coletar fatos e evidências com origem, recorte e limites. | Especialistas interpretam código, riscos e comportamento; registram hipóteses como hipóteses. |
| Propor | Preparar solicitação e destinos; validar identidades e integridade. | Humano ou agente autorizado elabora ranking/plano; recomendação não escolhe pelo desenvolvedor. |
| Autorizar | Conferir referência da decisão humana para a mesma solicitação e escopo. | Desenvolvedor concede GO; habilitar ferramenta ou responder uma pergunta não equivale a GO. |
| Executar | Validar entradas, runtime, efeitos e destinos; acompanhar processo e registrar resultado. | Desenvolvedor ou executor autorizado aplica a mudança delimitada. |
| Verificar e aceitar | Produzir resultados reproduzíveis e expor pendências. | Revisão humana aceita ou pede retrabalho. Teste aprovado não decide aceite ou resolução global. |

No alvo, estado da **solicitação**, estado da **execução técnica** e **decisões humanas** permanecem separados. `SUCCEEDED` de um processo significa sucesso técnico daquela operação. Uma proposta nova não herda silenciosamente o GO da anterior. O modo manual usa os mesmos artefatos e critérios do assistido.

## 6. DDD estratégico: limites do domínio e capacidades

### 6.1. Negócio da aplicação e domínio do harness

O domínio do produto é **conduzir trabalho de engenharia com contexto, decisão e evidência**. Suas regras de valor incluem delimitar solicitações, preservar decisões e permitir continuidade verificável. Já regras como elegibilidade de crédito, cálculo de preço ou aprovação de um pedido pertencem à aplicação analisada. O harness pode coletar e relacionar exemplos, testes e descrições dessas regras; sua interpretação precisa da validação dos responsáveis pelo negócio.

Build, serialização, resolução de caminhos, indexação e inicialização de processos são mecanismos de engenharia. A regra “esta alteração exige revisão do escopo aprovado” pertence ao domínio do harness; a regra “compilar este projeto em Java 8” pertence ao perfil JBoss; executar `mvn.cmd` pertence ao adaptador Maven. Essa separação evita transformar conhecimento de uma tecnologia em regra universal.

Domínio e subdomínio organizam problemas e responsabilidades; **bounded context** delimita um modelo e seu vocabulário; **capacidade** descreve um resultado acionável; **plugin** implementa integrações; **perfil** compõe capacidades e políticas para um objetivo. Nenhum desses conceitos exige um microserviço. A referência conceitual é o [DDD Reference, de Eric Evans](https://www.domainlanguage.com/ddd/reference/); a decomposição abaixo é uma decisão deste projeto.

A evolução do harness adota **DDD de forma pragmática**: a complexidade e o valor do problema orientam o investimento em modelagem. Compreender o trabalho e delimitar responsabilidades permite concentrar esse esforço nos modelos que protegem decisões relevantes. A distinção entre desenho estratégico — linguagem, subdomínios, contextos e relações — e tático — agregados e regras do modelo — está fundamentada em [Domain-Driven Design Distilled, de Vaughn Vernon, capítulos 2–6](https://www.informit.com/store/domain-driven-design-distilled-9780134434988), publicado pela Addison-Wesley. O monólito modular e os recortes propostos são escolhas do harness para aplicar esses fundamentos.

A **linguagem ubíqua** deve ser construída com quem conhece o trabalho e aparecer nos diálogos, casos de uso e código dentro de cada contexto, como explica Vernon em [How To Do DDD](https://www.informit.com/articles/article.aspx?p=1944876&seqNum=3). No harness, termos como solicitação, evidência, proposta, GO e aceite precisam manter significados explícitos; nas aplicações, o vocabulário continua sendo validado com seus especialistas de negócio. A adoção tática segue as invariantes da seção 7.2, sem transformar cada script ou integração em um agregado.

### 6.2. Mapa proposto

Os IDs HAR/SRC/OBJ/DEP/JBS/CHG preservam o catálogo anterior. A primeira coluna define os nomes canônicos dos domínios usados na matriz, no menu e na seleção de especialistas; após a barra estão os subdomínios. A classificação é relativa ao valor do harness: **central** diferencia o produto; **suporte** atende necessidades específicas; **genérico** usa soluções amplamente disponíveis.

| Domínio / subdomínios | Contexto responsável e classificação | Capacidades e situação |
| --- | --- | --- |
| Trabalho / descoberta, objetivo, triagem, proposta, reconciliação, retomada, revisão e continuidade | **Trabalho**, central | OBJ-02 e parte de CHG-02/03. Fluxo JBoss existente; generalização por perfil proposta. |
| Evidências / coleta, origem, consolidação, comparação, intercâmbio e retenção | **Evidências**, central | HAR-03 e parte de SRC-06. Recibos, dossiês e ZIP existentes; contrato transversal a extrair. |
| Execução / catálogo, configuração, ambiente, perfis e acompanhamento | **Execução**, suporte; processos/arquivos são mecanismos genéricos | HAR-01/02/04. Scripts e MCP existentes; catálogo comum e composição de perfis propostos. |
| Diagnóstico / preparação, análise, acompanhamento, histórico, apresentação e ingestão de apontamentos | **Diagnóstico**, suporte | OBJ-01. MTA e Sonar existentes; outros analisadores e normalização compartilhada propostos. |
| Compreensão de código / localização, sintaxe, semântica, relações e seleção de contexto | **Compreensão**, suporte | SRC-01 a SRC-06 / CORE-01. Busca dos clientes disponível; índice próprio e coletores ainda propostos. |
| Dependências / inventário, compatibilidade e verificações | **Dependências**, suporte | DEP-01 a DEP-03 / COMP-01. POM e build oferecem base; inventário resolvido e parecer por alvo ainda são incrementos. |
| Plataforma / configuração, publicação, reversão, ciclo do runtime, diagnóstico e acesso administrativo | **Plataforma**, suporte | JBS-01 a JBS-05 / SERV-01 tratam evolução da configuração. Start/deploy/rollback/debug existentes não comprovam essas capacidades futuras. |
| Mudança e qualidade / execução assistida, transformação, build e testes, análise de qualidade, cobertura e aceite | **Mudança**, central na decisão; adaptadores de verificação são suporte | CHG-01 a CHG-03. Implementação assistida/build/Sonar existentes; OpenRewrite integrado e perfis de cobertura propostos. |
| Planejamento de portfólio / escopo, calendário, capacidade e cenários | **Portfólio**, suporte | MACRO-01 integrada: contexto/prompt, calendário, capacidade, cenários e validação determinística. Homologação corporativa pendente; visão macro não autoriza lotes. |

**Relações entre contextos:** Trabalho referencia Evidências por identidade e revisão; Diagnóstico e Compreensão publicam fatos com proveniência; Execução fornece resultados técnicos; Mudança consome o escopo autorizado e devolve verificações; Portfólio consome resumos e estimativas, sem reescrever decisões por issue. Adaptadores MTA/Sonar/JDT funcionam como camadas de tradução: formatos dos fornecedores não se tornam o modelo interno de Trabalho. Relações ocorrem por APIs de módulos e referências, com um responsável por cada escrita.

Perfis não são novos bounded contexts automaticamente. `quarkus-desenvolvimento` e `quarkus-migracao` reutilizam capacidades, mas selecionam procedimentos e critérios diferentes. Cobertura é uma capacidade transversal: pode compor um perfil JBoss ou Quarkus, evitando duplicar toda a arquitetura para cada combinação.

## 7. Arquitetura estrutural e DDD tático

### 7.1. Monólito modular com portas e adaptadores

| Parte | Responsabilidade | Dependência permitida |
| --- | --- | --- |
| Núcleo de domínio | Solicitações, escopo, decisões, vínculos, evidências e regras de continuidade. | Tipos e funções do próprio domínio; sem IDE, SDK de IA ou processo externo. |
| Serviços de aplicação | Casos de uso: preparar, retomar, consultar, executar e registrar resultado. Coordenam regras e portas. | Domínio e contratos de portas. |
| Composição | Resolver perfil, catálogo, versões, ferramentas instaladas e políticas; conectar implementações. | Contratos e adaptadores selecionados. |
| Adaptadores de entrada | CLI, menu, MCP, VS Code e IntelliJ convertem interação em requisições explícitas. | API dos casos de uso; sem regra de negócio exclusiva da interface. |
| Adaptadores de saída | Arquivos, processos, Maven, MTA, Sonar, EAP, JDT e clientes de IA. | Portas públicas; formatos externos ficam encapsulados. |
| Pacotes de perfil | Manifesto, políticas, guias, modelos, procedimentos e contribuições de capacidades/agentes. | Contratos públicos do núcleo e plugins compatíveis. |

É a aplicação do padrão [ports and adapters, de Alistair Cockburn](https://alistair.cockburn.us/hexagonal-architecture/). A direção das dependências protege as regras internas. O desenho inicial usa módulos no mesmo repositório e uma linha de releases; não exige broker, servidor remoto, contêiner ou publicação independente de cada pacote.

A organização lógica proposta distribui essas responsabilidades entre núcleo, contratos, adaptadores, plugins e perfis:

```text
src/core/                 modelos e casos de uso por contexto
src/contracts/            portas e esquemas públicos versionados
src/adapters/             arquivos, processos, CLI, menu, MCP, IDEs e clientes
plugins/                  maven, mta, sonar, eap, java-analysis, quarkus
profiles/                 manifestos, políticas, guias e papéis por objetivo
doc/core/                 regras e guias transversais
doc/arquitetura/           visão consolidada
doc/adr/                  decisões e sua evolução
tests/                    contratos, fixtures e equivalência
```

### 7.2. Modelos e invariantes

| Modelo proposto | Regra e limite de consistência |
| --- | --- |
| `WorkRequest` — agregado | Identifica objetivo, projeto, perfil resolvido, escopo, base e vínculos. Aceita transições coerentes; não incorpora catálogo completo, logs ou todos os lotes. |
| `EvidenceBundle` — agregado | Fecha um conjunto de referências/hashes e limitações. Uma revisão publicada é imutável; índices editáveis de novos anexos ficam separados. |
| `Execution` — agregado | Identifica operação, entradas, efeitos, runtime, resultado e artefatos. Sucesso técnico não muda decisões humanas. |
| `HumanDecision` — registro associado ao trabalho | Preserva decisão, origem e alcance sobre solicitação/escopo. Texto gerado por agente não constitui assinatura ou nova autorização humana. |
| Objetos de valor | `ProjectRef`, `SourceRef`, `Scope`, `EvidenceRef`, `ProfileRef`, `CapabilityId` e hashes evitam confundir identidades, caminhos e versões. |
| Políticas e serviços de domínio | Regras de retomada, suficiência declarada e aplicação de decisões; políticas tecnológicas vêm do perfil, sem enfraquecer invariantes comuns. |

Usar agregados onde há invariantes; parsers e utilitários permanecem funções simples. Interfaces de persistência existem nos limites desses modelos, sem um repositório genérico para cada JSON. O núcleo não exige ORM, event sourcing ou hierarquias de classes.

Portas iniciais: catálogo/perfis, armazenamento de solicitações/evidências, execução de ferramentas, consulta de código e apresentação/cliente de agentes. Escrita local usa validação, publicação atômica quando suportada e conferência de revisão/hash para evitar sobrescrita concorrente. Locks protegem operações do mesmo armazenamento local; não representam coordenação distribuída ou gestão de branches.

### 7.3. Contrato acionável das capacidades

Uma capacidade publicada declara ID/versão, domínio/subdomínio, descrição, esquemas de entrada/saída, pré-condições, efeitos, permissões, runtimes, limites, documentação e responsável técnico. Disponibilidade significa **declarada + implementação instalada + configuração válida + pré-condições atendidas**. O menu pode mostrar uma capacidade indisponível com motivo; agentes recebem o recorte pertinente e realmente utilizável.

Requisições transportam projeto, perfil resolvido, capacidade, entradas, referência de contexto e autorização aplicável. Respostas distinguem sucesso, entrada faltante, indisponibilidade, conflito, falha, cancelamento e resultado parcial; incluem diagnóstico, proveniência, cobertura e artefatos. Para operações longas, retornam um identificador de execução e permitem acompanhar/cancelar. Cancelamento só termina após confirmação dos subprocessos; efeitos parciais ficam registrados.

Esses contratos novos não renomeiam retroativamente os envelopes atuais: o MCP de issues mantém `Status`, `Provenance`, `Paging` e demais campos. Adaptadores de compatibilidade preservam a API até uma migração explicitamente versionada.

Um plugin TypeScript confiável pode ser carregado no processo. Ferramentas Java e outras CLIs usam adaptador de processo com argumentos tipados e protocolo estruturado, sem exigir um servidor MCP para cada ferramenta. O manifesto não aceita comandos arbitrários fornecidos pelo modelo. Saída de terceiros é validada; logs são separados do canal de protocolo; diretório, variáveis, timeouts e término de processos pertencem ao executor. Particularidades de `.cmd`/`.bat` precisam de tratamento explícito no Windows, conforme a [API de processos do Node](https://nodejs.org/api/child_process.html).

## 8. Núcleo, perfis e configuração

### 8.1. Composição e propriedade

`harness.local.json` passa a conter somente configuração transversal e **referências**: projetos, diretório de estado, limites gerais, seleção de perfil e clientes. Instalações EAP, alvos Java, MTA, scanner, regras Sonar e ferramentas específicas ficam na configuração do perfil ou do plugin por ele referenciado. Configuração compartilhada de Maven/Java pode ser referenciada por vários perfis, sem copiar instalações ou caches.

O **manifesto versionado do perfil** define capacidades, plugins compatíveis, políticas, guias e papéis. O **arquivo local do perfil** vincula instalações e opções da máquina. Selecionar um perfil não instala ferramentas, amplia permissões, troca a base histórica ou concede autorização. Uma solicitação registra IDs/versões/hashes da composição usada; retomadas mantêm essa composição até uma atualização explícita.

Exemplo de formato alvo do núcleo — **proposto, ainda não aceito pelos scripts atuais**. Caminhos relativos resolvem a partir do arquivo que os declara:

```json
{
  "schemaVersion": 2,
  "statePath": "../.harness",
  "projects": [{ "id": "servico-a", "source": "../../servico-a" }],
  "defaultProfile": "jboss-migracao",
  "profiles": [
    { "id": "jboss-migracao", "configPath": "profiles/jboss-migracao.local.json" },
    { "id": "quarkus-desenvolvimento", "configPath": "profiles/quarkus-desenvolvimento.local.json" }
  ],
  "execution": { "maxParallel": 2 },
  "agentClient": { "id": "codex", "configPath": "clients/codex.local.json" }
}
```

Exemplo do arquivo local `config/profiles/jboss-migracao.local.json`. As versões identificam o futuro catálogo do harness; não são versões atualmente publicadas:

```json
{
  "schemaVersion": 1,
  "profile": { "id": "jboss-migracao", "version": "1.0.0" },
  "objective": "migration",
  "target": { "runtime": "eap", "version": "7.4", "java": "8", "namespace": "javax" },
  "capabilities": ["migration.plan", "maven.build", "sonar.analyze", "eap.deploy", "java.coverage"],
  "plugins": [
    { "id": "maven", "configPath": "../tools/java-build.local.json" },
    { "id": "mta", "configPath": "../tools/mta.local.json" },
    { "id": "sonar", "configPath": "../tools/sonar.local.json" },
    { "id": "eap", "configPath": "../tools/eap.local.json" },
    { "id": "jacoco", "configPath": "../tools/coverage.local.json" }
  ]
}
```

O resolvedor valida a configuração contra o manifesto instalado. A lista local pode restringir capacidades ou habilitar opcionais permitidas pelo perfil, mas não introduzir operações desconhecidas nem sobrepor invariantes do núcleo. Defaults versionados, configuração local e parâmetros da operação têm precedência documentada por campo; conflitos de alvo/versão são erros, sem mesclagem silenciosa. Segredos são referências ao mecanismo seguro do ambiente, não conteúdo dos JSON ou prompts.

### 8.2. Perfis previstos

| Perfil | Composição e limites |
| --- | --- |
| Migração JBoss | Extrair o comportamento existente: EAP, Java 8/javax, MTA ou evidências, Maven, Sonar e continuidade por issue. |
| Desenvolvimento Quarkus | Selecionar JDK/BOM/extensões, build/testes, modo de desenvolvimento e procedimentos de entrega compatíveis com o projeto. |
| Migração Quarkus | Acrescentar par origem/destino, guias e receitas aplicáveis, comparação e revisão de alterações. |
| Cobertura de código | Compor coleta e interpretação de cobertura com JBoss ou Quarkus; separar testes unitários, integração e recorte medido. Não duplicar os adaptadores Maven/JaCoCo. |

Perfis Quarkus e cobertura dedicada são propostas. A [CLI Quarkus](https://quarkus.io/guides/cli-tooling/) e o [guia de testes](https://quarkus.io/guides/getting-started-testing/) fornecem pontos de integração; a versão e os critérios efetivos serão definidos por perfil. A atual política JaCoCo do recorte JBoss não se torna automaticamente uma política universal.

A migração da configuração v1 deve apresentar o mapeamento e os destinos, preservar o original e validar o comportamento antes de ativar v2. `mta.profile` e `sonar.profiles` mantêm seus significados dentro dos plugins; não são reinterpretados como a nova lista `profiles`. Settings Maven opcionais continuam `null` por padrão, usando a configuração da máquina. Não criar mirrors, repositórios ou cópias de cache para facilitar a conversão.

## 9. Desenvolvedor, IDEs, agentes e contexto

### 9.1. Uma capacidade, várias entradas

O catálogo alimenta um menu **perfil → domínio → subdomínio → capacidade** com busca e atalhos. Perfil/projeto já resolvidos não são perguntados novamente. Exemplo: “Migração JBoss / Mudança e qualidade / Cobertura / Medir recorte” explica entradas, efeitos, pré-condições, saída e guia antes da execução. O mesmo ID tem comando CLI não interativo e, quando pertinente, ferramenta MCP. Menu e CLI funcionam sem IA.

No VS Code, tarefas e uma futura extensão traduzem seleção e progresso. No IntelliJ, o primeiro adaptador usa [External Tools](https://www.jetbrains.com/help/idea/configuring-third-party-tools.html), passando projeto, configuração e argumentos para a CLI; menu dedicado e plugin são incrementos de experiência. O suporte de [Tasks do VS Code](https://code.visualstudio.com/docs/debugtest/tasks) é outra forma de acionar processos, não uma dependência do núcleo. Configuração de debug da aplicação permanece específica da IDE.

A [proposta de extensão VS Code](../features/engineering-harness-vscode.md) contribui para distribuição e experiência de uso. A evolução prioriza CLI e contratos como base executável, permitindo que o VSIX distribua e apresente capacidades também acessíveis por outros clientes. A adoção dessa direção depende da revisão da ADR-0008; a especificação histórica permanece como referência da proposta original.

### 9.2. Orquestração por papéis

| Papel lógico | Responsabilidade e contexto mínimo |
| --- | --- |
| Orientador/orquestrador | Recuperar objetivo, perfil, solicitação e etapa; selecionar a próxima capacidade ou especialista. Usa mapa do catálogo e resumos referenciados, não o repositório inteiro. |
| Especialista de domínio | Tratar uma pergunta que cruza capacidades do mesmo domínio, como impacto ou qualidade. Recebe recorte, critérios e evidências pertinentes. |
| Especialista de subdomínio/capacidade | Aplicar procedimento delimitado, como dependências Maven ou semântica Java. Recebe somente entradas necessárias e retorna fatos, fontes, lacunas e recomendação. |
| Executor de mudança | Aplicar apenas o escopo autorizado com ferramentas compatíveis e produzir evidências. É distinto do orientador de leitura. |
| Revisor | Confrontar resultado, critérios e evidências; apontar falhas sem conceder aceite humano. |

Esses são papéis reutilizáveis, não uma obrigação de criar um agente para cada nó do menu. A delegação é sob demanda, limitada por orçamento de contexto, profundidade e permissões do cliente. Subagente recebe objetivo, fontes, destinos permitidos e formato de resposta; retorna um resumo com referências. Falha ou ausência de delegação fica explícita. Trabalho paralelo de escrita exige recortes sem conflito; o harness não gerencia branches ou coordenação de equipes.

O orientador atual permanece leitor. Se uma evolução permitir que o orquestrador também inicie operações, o modo executor deve ser explícito, com a mesma autorização exigida na CLI; disponibilidade de uma tool não amplia seu papel. Essa separação preserva a [skill de orientação](../../.agents/skills/orientar-migracao/SKILL.md).

| Cliente selecionável | Base atual e adaptação proposta |
| --- | --- |
| GitHub Copilot + DevSquad | Prompts e helpers existentes no VS Code. O adaptador verifica agentes/ferramentas realmente instalados e aplica o procedimento no cliente; nomes DevSquad não são APIs internas do núcleo. [Subagentes no VS Code](https://code.visualstudio.com/docs/agents/run/subagents). |
| Codex + `using-agent-skills` | Skill/helper já disponíveis; a coleção SDLC depende da instalação do usuário. Adaptador resolve skills e papéis autorizados, sem fixar modelo. [Skills](https://learn.chatgpt.com/docs/build-skills), [subagentes](https://learn.chatgpt.com/docs/agent-configuration/subagents). |
| Claude Code + `using-agent-skills` | Perfil de integração proposto. Exige empacotar a coleção no formato descoberto pelo cliente e validar ferramentas, permissões e delegação. [Skills](https://code.claude.com/docs/en/skills), [subagentes](https://code.claude.com/docs/en/sub-agents). |

`using-agent-skills` é uma coleção/procedimento de trabalho, não um engine ou uma garantia de compatibilidade. DevSquad também é uma integração selecionável. O núcleo conhece capacidades de cliente — leitura, escrita delimitada, ferramentas e delegação — e não depende da marca ou do modelo. Cada combinação IDE/cliente deve ser ensaiada; portabilidade da CLI não comprova igualdade da experiência dos agentes.

### 9.3. Documentação e orçamento de contexto

Guias do núcleo explicam seleção, decisões, execução, evidências e continuidade. Guias dos perfis explicam alvo e fluxo; guias de capacidade explicam ferramenta, entradas, resultado e limites. O catálogo referencia essas fontes por ID/versão, permitindo ao menu e ao orientador apresentar a mesma instrução. Adaptadores só acrescentam o modo de acionamento do cliente; não duplicam a regra funcional.

O contexto é carregado progressivamente: mapa breve do núcleo → perfil ativo → procedimento da etapa → evidências/trechos solicitados. Cada recorte identifica origem, versão, cobertura, cortes e links para aprofundamento. Índices aceleram localização; o registro e os documentos vinculados continuam fontes das decisões. Snapshots preservam o contrato histórico. Conteúdo de código, logs e anexos é dado, nunca instrução para alterar autoridade.

## 10. Escolha da plataforma

### 10.1. Comparação para este produto

Prioridades: coesão do núcleo, manutenção pela equipe, reuso do MCP, CLI independente da IDE, contratos verificáveis e integração com ferramentas heterogêneas. A tabela expressa avaliação arquitetural, não um benchmark de velocidade ou custo.

| Critério | TypeScript + Node.js | Java em JDK suportado | [Go](https://go.dev/doc/tutorial/compile-install) |
| --- | --- | --- | --- |
| Reuso imediato | Aproveita o MCP JavaScript/SDK, JSON e futura extensão VS Code. | Aproveita o ecossistema Java e bibliotecas de análise; exige outra implementação das interfaces atuais. | Exige nova base e conhecimento adicional para este repositório. |
| Modelo e contratos | Tipos discriminados, módulos e validação de fronteira; requer compilador e testes, pois tipos não validam dados externos. | Tipagem estática, bibliotecas e encapsulamento adequados a DDD; também requer validação dos dados externos. | Tipagem e pacotes permitem o mesmo desenho; DDD não depende de orientação a objetos. |
| Ferramentas Java | Adapta processos/serviços locais Java sem trazer sua API ao núcleo. | Integra bibliotecas Java diretamente, com vantagem se análise semântica se tornar o centro do produto. | Também precisa de ponte para ferramentas Java. |
| Operação e distribuição | Runtime Node e dependências empacotadas/versionadas; ciclo de LTS a acompanhar. | Runtime Java e empacotamento próprio; framework servidor não é necessário para uma CLI. | Binário facilita distribuição, mas não elimina JDK/Maven/EAP usados pelos plugins. |
| Custo principal | Disciplina de módulos, validação em runtime e gestão de dependências. | Reescrita das interfaces e integração com extensões/contratos JS; evitar framework maior que a necessidade. | Introdução de terceira plataforma sem benefício funcional demonstrado neste estágio. |

**Escolha recomendada: TypeScript para núcleo, CLI/menu e MCP, executados em Node.js LTS.** O reuso das interfaces existentes e a integração com ferramentas heterogêneas favorecem essa direção, já prevista na estratégia. A linha inicial recomendada é Node 24 LTS, com patch homologado e acompanhamento do ciclo de suporte; em 09/10/2026 a [tabela oficial](https://nodejs.org/en/about/previous-releases) identifica 24 como LTS e 26 como Current. A adoção dessa linha requer a atualização e validação dos pacotes durante a modernização.

Compilar/verificar TypeScript em modo estrito e distribuir JavaScript ESM com dependências fixadas. Execução direta de `.ts` pelo Node não substitui verificação de tipos, conforme a [documentação oficial](https://nodejs.org/api/typescript.html). Manter esquemas de fronteira e testes de contrato; o [SDK MCP TypeScript](https://github.com/modelcontextprotocol/typescript-sdk) é uma integração, não o framework do domínio.

**Java é a escolha complementar para análise especializada**, não um fallback oculto: JDT e ferramentas existentes rodam com seu próprio runtime. Java também é uma alternativa viável para o núcleo — há [SDK MCP Java](https://github.com/modelcontextprotocol/java-sdk). Reabrir essa decisão se um piloto demonstrar que predominam bibliotecas Java embutidas, ou se manutenção/distribuição Node forem impeditivas. Hoje não há evidência que justifique uma segunda implementação do núcleo.

O piloto avalia também a manutenção de uma capacidade pela equipe: localizar a regra, alterar o contrato, testar e diagnosticar uma falha. Essa experiência permite verificar a familiaridade com TypeScript e Java e o custo de sustentar a plataforma escolhida.

Novos plugins usam TypeScript quando o trabalho é orquestrar I/O e interpretar contratos; usam Java quando dependem de APIs Java; preservam PowerShell para integração Windows enquanto ela for necessária. Escolher linguagem por responsabilidade, sem versões paralelas da mesma regra de domínio.

## 11. Compreensão e indexação Java independente de IDE

### 11.1. Base de análise e alternativas

O [estudo CORE-01](../../tasks/plan.md#exploracao-java-opcional-e-transversal) prioriza JDT, enquanto o catálogo SRC-03 explora JavaParser/Symbol Solver como alternativa. A necessidade de consultas semânticas independentes de IDE conduz à recomendação de **Eclipse JDT como base Java, com JDT Language Server executado fora da IDE e JDT Core para extração sintática quando necessária**. O adaptador do harness será o cliente; não dependerá de extensões VS Code, índices privados do IntelliJ ou comandos da interface Eclipse.

| Opção open source | Adequação e limites | Decisão proposta |
| --- | --- | --- |
| Eclipse JDT LS — EPL-2.0 | Servidor LSP executável pela CLI; oferece referências, navegação e hierarquias, com suporte Maven/Gradle. Requer runtime Java 21+; esse runtime é separado do Java da aplicação, incluindo projetos Java 8. [Projeto oficial](https://github.com/eclipse-jdtls/eclipse.jdt.ls). | Primeiro piloto de consulta semântica, com instância e área de dados próprias do harness. |
| Eclipse JDT Core — EPL-2.0 | `ASTParser` produz AST e bindings com ambiente/classpath configurados. A API não equivale, sozinha, a um índice persistente completo. [API](https://help.eclipse.org/latest/topic/org.eclipse.jdt.doc.isv/reference/api/org/eclipse/jdt/core/dom/ASTParser.html), [projeto](https://github.com/eclipse-jdt/eclipse.jdt.core). | Coletor Java complementar para fatos sintáticos não expostos pelo LSP, compartilhando o ambiente resolvido. |
| JavaParser + Symbol Solver | Biblioteca para AST e resolução de declarações/tipos. Exige construir integração de projeto, busca de referências e persistência. [Projeto e licenças](https://github.com/javaparser/javaparser). | Alternativa delimitada se o piloto JDT não atender uma necessidade; evitar manter dois motores por padrão. |
| `scip-java` — Apache-2.0 | Gera índice SCIP independente de IDE a partir do build. A documentação atual não suporta Java 8 e informa efeitos como limpeza/compilação. [Uso e compatibilidade](https://github.com/scip-code/scip-java/blob/main/docs/getting-started.md), [licença](https://github.com/scip-code/scip-java). | Não adotar como indexador padrão do primeiro perfil EAP/Java 8. Reavaliar para perfis modernos que necessitem índice transportável. |

LSP atende consultas interativas; [SCIP](https://github.com/scip-code/scip) é um formato de índice para navegação e relações. Nenhum deles é um modelo de comportamento de negócio ou substitui uma AST completa. O protocolo interno do harness deve expor a pergunta e os fatos necessários, preservando a possibilidade de trocar o provedor.

### 11.2. Contrato e operação do índice

O serviço `SourceAnalysis` oferece consultas de símbolos, definição, referências, hierarquia, estrutura e recortes relacionados. O consumidor informa `Source`, revisão dos arquivos, módulos e objetivo; não precisa fornecer MTA, EAP ou um lote de migração. JBoss, Quarkus, investigação de defeitos, impacto, revisão arquitetural e seleção de testes podem reutilizar os mesmos fatos.

Entradas de indexação incluem raízes de fonte, fontes geradas, nível Java, dependências resolvidas, perfis de build e opções relevantes. Cada resultado registra provedor/versão, identidade do símbolo, arquivo/intervalo, relações, hash dos insumos, cobertura e símbolos não resolvidos. Distinguir `COMPLETO_NO_ESCOPO`, `PARCIAL`, `DESATUALIZADO` e `FALHOU`; resultado vazio só comprova ausência dentro da cobertura declarada.

O índice privado do JDT é cache reconstruível. Fatos selecionados e suas referências são materializados em JSON versionado no armazenamento de evidências; não copiar o índice privado da IDE como prova portátil. A chave de validade inclui conteúdo, classpath, perfis e versão do coletor. Alterações nesses insumos invalidam o recorte afetado; Git observado ajuda a localizar a revisão, mas não é gate. Paginação, limites de texto e seleção por símbolo evitam enviar AST/repositório inteiros ao modelo.

Inicializar/importar um projeto no analisador pode escrever cache, resolver dependências e ativar mecanismos de build/processamento de anotações. Separar **preparar/atualizar índice**, com efeitos declarados e autorização pertinente, de **consultar índice pronto**. Não rotular toda indexação como leitura, instalar dependências ou executar o build implicitamente durante uma consulta. Falta de classpath resulta em análise parcial explícita, não em conclusões semânticas completas.

Uma chamada estática não comprova execução; reflexão, CDI/EJB, proxies, geração e configuração externa deixam lacunas. Fatos técnicos devem ser relacionados a cenários, testes e observações de runtime para discutir comportamento. Limites de negócio são hipóteses a validar, não clusters inferidos automaticamente de pacotes.

**Aceite do piloto:** consultar o mesmo projeto fora de qualquer IDE, via CLI e MCP; verificar sobrecarga/herança, reactor Maven, Java 8, fontes geradas, dependência ausente e alteração após indexação; distinguir lacunas dinâmicas; medir tempo de preparo/consulta, memória, cobertura e volume de contexto. A prova precisa demonstrar utilidade para ao menos dois objetivos, como impacto de migração e seleção de testes. A homologação do JDT permanece condicionada a esses resultados.

## 12. Capacidades arquiteturais e critérios de qualidade

As capacidades arquiteturais sustentam as funcionalidades do produto e orientam sua evolução. Independência de IDE, rastreabilidade, confiabilidade e eficiência de contexto precisam ser demonstradas em cenários verificáveis.

| Propriedade | Mecanismo proposto | Evidência para aceitar a evolução |
| --- | --- | --- |
| Independência de IDE e IA | Casos de uso compartilhados, CLI/menu e adaptadores finos. | Mesmo caso e resultado sem IDE, no VS Code e no IntelliJ; operação manual sem agente. |
| Coesão e baixo acoplamento | Limites de contextos, portas explícitas e perfis declarativos. | Testes de dependências impedem imports de IDE/SDK no domínio; segundo perfil sem condicionais tecnológicas no núcleo. |
| Rastreabilidade e continuidade | Identidade, snapshots, hashes e referências de decisão. | Retomada local/importada preserva origem, histórico e autoridade; conflitos não são sobrescritos. |
| Confiabilidade de execução | Validação, limites, cancelamento e resultado parcial. | Fixtures de timeout/falha/cancelamento não deixam sucesso fictício ou subprocesso sem acompanhamento. |
| Segurança de ferramentas | Efeitos e permissões explícitos, validação de fronteira, proteção de caminhos e segredos. | Entradas inválidas, paths fora do escopo e dados de evidência não executam comandos nem ampliam acesso. |
| Evolutividade | Contratos versionados, plugins substituíveis e migração de configuração. | Compatibilidade com recibos legados e troca de adaptador sem mudar a regra funcional. |
| Eficiência de contexto | Consulta sob demanda, paginação, orçamento e retorno referenciado. | Medir contexto enviado, acerto e retrabalho em casos equivalentes; não usar bytes como prova de tokens economizados. |
| Observabilidade | IDs de solicitação/execução/capacidade, duração, diagnóstico e artefatos. | Falha localizável sem ler logs de todas as ferramentas; credenciais ausentes dos registros. |
| Operabilidade | Menu por capacidade, diagnóstico do perfil e instalação versionada. | Desenvolvedor executa/retoma a operação e compreende o resultado sem conhecer nomes de agentes. |

Nenhum ganho de desempenho, custo ou qualidade é declarado sem medição. Critérios técnicos não substituem a revisão funcional e o aceite humano.

## 13. Modernização incremental

A modernização parte dos contratos e ferramentas existentes e extrai uma capacidade por vez. Cada incremento precisa preservar o comportamento conhecido e demonstrar o benefício da nova estrutura antes de ampliar seu uso para outros perfis e clientes.

| Incremento | Resultado verificável |
| --- | --- |
| Direção arquitetural | Revisar a ADR-0008 e alinhar o escopo dos incrementos aos contratos e capacidades disponíveis. |
| Contratos e primeira capacidade | Tipar o MCP existente e extrair uma consulta para o núcleo; comparar entradas, resultados, erros, hashes e paginação com as fixtures PowerShell. |
| CLI/menu e perfil JBoss | Executar essa capacidade pelos mesmos contratos, com configuração núcleo/perfil e compatibilidade v1. Demonstrar terminal e IntelliJ sem exigir extensão própria. |
| Regras e ferramentas por capacidade | Migrar preparo/continuidade e adaptadores em recortes coerentes, preservando PowerShell até equivalência. Incluir escrita e falhas parciais nas verificações. |
| Compreensão Java | Realizar o piloto JDT da seção 11; conectar fatos ao contexto por objetivo, sem tornar indexação pré-requisito universal. |
| Segundo perfil e terceiro cliente | Demonstrar reuso com Quarkus ou cobertura e validar Claude Code, mantendo as integrações existentes. Escolher o recorte por necessidade real. |

Uma capacidade passa de proposta a implementada quando código, contrato, guia e verificações correspondentes estão disponíveis; homologação e aceite mantêm seus critérios próprios. A retirada de um caminho PowerShell depende da equivalência funcional e da migração dos consumidores. O produto será distribuído com versões e dependências definidas, referenciando as instalações corporativas de JDK/Maven/MTA/EAP sem duplicá-las.

## 14. Fontes e precedência

As fontes oficiais sustentam as características das ferramentas e os fundamentos de arquitetura. Versões e suporte têm como referência 09/10/2026 e precisam ser reconferidos nos pilotos. A decomposição em contextos, a plataforma e a composição por perfis formam a direção proposta na ADR-0008; os contratos vigentes continuam orientando a operação.

| Fonte consolidada | Papel nesta arquitetura |
| --- | --- |
| [AGENTS.md](../../AGENTS.md) e [ADRs 0001–0007](../adr) | Contratos vigentes e evolução das decisões; ADR-0003 é histórica nos pontos substituídos. |
| [Estratégia](../estrategia/estrategia-harness_.md) e [conciliação](../estrategia/conciliacao-evolucao-harness.md) | Direção, base reaproveitável e limites das propostas anteriores. |
| [Catálogo de domínios e capacidades](../features/evolucao-harness-dominios-capacidades-priorizacao.md) | IDs e recortes HAR/SRC/OBJ/DEP/JBS/CHG que orientam a expansão das capacidades. |
| [Contrato de planejamento](../especificacoes/planejamento-copilot.md), [consultas](../especificacoes/consultas-issues.md) e [guia do desenvolvedor](../guias/harness-migracao-desenvolvedor.md) | Comportamento implementado, invariantes e operação. |
| [MACRO-01](../features/planejamento-macro-sprints.md) e [contrato de sprints](../especificacoes/planejamento-sprints.md) | Capacidade integrada à base operacional; cronograma, revisões e justificativas determinísticas. |
| [Extensão VS Code](../features/engineering-harness-vscode.md) e [estudo CORE-01](../../tasks/plan.md#exploracao-java-opcional-e-transversal) | Propostas e estudos reconciliados, com estado de entrega explicitado. |

Mudanças de regra exigem decisão registrada e atualização dos contratos afetados. Esse vínculo mantém arquitetura, procedimentos operacionais e histórico coerentes durante a evolução.

## Anexo A — Fundamentos de harness engineering

Harness engineering organiza a colaboração entre pessoas e agentes de programação. O agente recebe contexto sobre o objetivo, a estrutura do sistema e as decisões que deve respeitar; depois de atuar, recebe evidências que orientam a próxima correção. Essa relação entre orientação antecipada (*feedforward*) e retorno (*feedback*) é desenvolvida por Birgitta Böckeler em [Harness engineering for coding agent users](https://martinfowler.com/articles/harness-engineering.html), de 02/04/2026, e apresentada por Luca Mezzalira em [What's Happening in Software Architecture — O’Reilly](https://learning.oreilly.com/videos/whats-happening-in/0642572416683/), episódio de [22/09/2026](https://www.oreilly.com/videos/whats-happening-in/0642572416683/).

![Diagrama de harness engineering: conhecimento arquitetural e orientações alimentam o agente; código e verificações formam o ciclo de retorno.](../estrategia/imagens/04-luca-mezzalira-harness.png)

*Figura A.1 — Orientação arquitetural e ciclo de retorno ao agente. Fonte: Luca Mezzalira, O’Reilly, 22/09/2026.*

O ciclo começa na compreensão do domínio. Arquitetos e especialistas identificam os subdomínios, seu papel no produto e as características arquiteturais necessárias. A classificação em centrais, genéricos e de suporte ajuda a direcionar o investimento, mas pode mudar conforme o negócio evolui. Um subdomínio genérico pode tornar-se central, exigindo a revisão de suas responsabilidades e de seu desenho. Os fundamentos de DDD de Evans e Vernon, apresentados na seção 6.1, sustentam essa análise.

As escolhas ganham continuidade quando seus motivos e concessões ficam registrados em ADRs. Guias, skills e arquivos como `AGENTS.md` tornam esse conhecimento acessível ao agente antes da execução. A arquitetura passa, assim, a orientar o trabalho cotidiano: o agente encontra critérios para tomar decisões coerentes com o domínio e os limites da solicitação.

Depois da produção de código, testes, análise estática, verificações de arquitetura e segurança e informações de runtime mostram os efeitos da mudança. Esses sinais alimentam o ciclo de correção. Como distingue Böckeler, verificações computacionais e avaliações inferenciais cumprem papéis diferentes: resultados determinísticos constituem evidências identificáveis, enquanto interpretações e revisões por IA precisam explicitar seus limites.

Na arquitetura proposta, núcleo e perfis organizam essas orientações e verificações em capacidades acionáveis. O orientador seleciona os recursos e especialistas pertinentes ao objetivo, e cada execução devolve evidências para a continuidade do trabalho. As pessoas aperfeiçoam esse sistema à medida que aprendem com seus resultados, preservando a responsabilidade pelas decisões de negócio, pelo GO e pelo aceite.
