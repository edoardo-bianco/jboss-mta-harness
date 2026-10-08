# Feature MACRO-01 — Planejamento sintético da migração por sprints

**Versão:** 2.0 — consolidação de requisitos em 08/10/2026.  
**Projeto:** [jboss-mta-harness](https://github.com/edoardo-bianco/jboss-mta-harness).  
**Destino:** atualizar `doc/features/planejamento-macro-sprints.md`, preservando uma única feature.  
**Base conferida:** `main`, commit [`745a8e64c75fa9a5ac4d356f6705dee93865503b`](https://github.com/edoardo-bianco/jboss-mta-harness/commit/745a8e64c75fa9a5ac4d356f6705dee93865503b), com o PR #21 integrado.  
**Situação:** especificação para implementação futura pelo Codex. A consulta dessa base confirmou a proposta documental; a Run Task de sprints ainda não está implementada. Esta consolidação detalha a proposta para a próxima implementação.

## 1. Objetivo e encaixe na estratégia

Adicionar a Run Task **`Planejamento: planejar sprints`** para reunir o contexto da migração, coletar as restrições de calendário e equipe e preparar um prompt. Ao executar esse prompt no cliente escolhido, o agente preenche ou revisa um **planejamento macro sintético**, com escopo, linha do tempo, sprints, marcos, percentuais previstos e comprovados e objetivo de HU por sprint.

O harness já reúne diagnóstico, registros, priorização, fichas e planos de corretiva. A nova capacidade conecta essas evidências às perguntas de gestão: **o que cabe no período, com qual equipe, quais entregas esperar ao fim de cada sprint e o que ameaça a implantação em produção?** O agente interpreta o contexto e propõe agrupamentos e estimativas; os scripts calculam datas, capacidade, totais e consistência. A revisão atualiza a previsão a partir de novas informações, preservando a referência anterior.

O resultado principal é um Markdown de leitura rápida. Detalhes de issues, estimativas e evidências permanecem nos documentos vinculados e nos dados estruturados do planejamento. A feature complementa o planejamento progressivo por issue; não antecipa planos detalhados para todos os lotes nem substitui os registros existentes.

### 1.1. Base existente e incremento solicitado

| Base confirmada na `main` | Consolidação desta feature |
| --- | --- |
| Proposta MACRO-01, contexto/prompt por cliente, estimativas, reservas e diagrama temporal | Especificar comportamento, entradas, saídas, template e critérios de aceite para implementação. |
| `Planejamento: planejar` para um lote e documentos `PlanPath`/`TodoPath` | Criar operação macro distinta, que apenas referencia os planos de corretiva. |
| Índice de projetos e registros de migração | Reutilizar identidade, decisões, andamento e referências de um ou mais projetos selecionados. |
| Copilot/DevSquad e Codex, com helpers orientadores | Encaminhar o mesmo contrato de planejamento macro para um executor com capacidade de escrever seus entregáveis. |
| Recibos, evidências consolidadas e histórico | Registrar entradas, revisão anterior, hipóteses e mudanças do cronograma. |

Esta versão preserva o refinamento integrado pelo PR #21 e acrescenta: sprints de duas semanas; máximos separados de preparação, implementação e testes; data limite de produção; teto de desenvolvedores mais um arquiteto e um DevOps; migração da configuração JBoss; marco e objetivo de HU por sprint; e template reutilizável com reconciliação.

## 2. Experiência de uso

1. O usuário executa **Terminal → Run Task → `Planejamento: planejar sprints`**.
2. A tarefa recupera o escopo já selecionado ou oferece **Todos os projetos do workspace** e **Escolher projetos**. Mostra o escopo concreto para conferência, conforme a seção 2.2. Com planejamento anterior inequivocamente vinculado, oferece **revisar o existente** ou **criar cenário separado**. Não escolhe arquivo pela data de modificação.
3. Reutiliza os parâmetros conhecidos e pergunta apenas informações ausentes ou que o usuário deseja alterar. Mostra um resumo editável de calendário, limites, equipe e escopo.
4. Prepara recibo/contexto, calendário e prompt com caminhos reais. Abre o prompt e informa como executá-lo no cliente escolhido. A preparação não executa o agente automaticamente.
5. O agente lê as fontes, propõe ou revisa a distribuição, preenche o template e salva Markdown e dados estruturados nos destinos recebidos. Se faltar dado essencial, preserva um rascunho com a lacuna precisa.
6. A validação determinística confere datas, capacidade, dependências, contagens e saídas. O resultado apresenta proposta, premissas, impedimentos e diferenças em relação à revisão anterior.
7. Ao chegar nova evidência ou mudar uma restrição, o usuário usa **a mesma Run Task**. O agente reconcilia o plano, em vez de começar outro cronograma sem vínculo.

O fluxo também deve funcionar com elaboração manual nos mesmos destinos. Não criar uma tarefa por projeto, fase, sprint, formato ou ação auxiliar. A operação não agenda execuções futuras, abre HUs em sistemas externos ou implanta aplicações.

### 2.1. Relação com o helper e os clientes

O usuário pode pedir ao `migracao_helper`: “prepare/revise o planejamento de sprints com este contexto”. O helper identifica o procedimento, recupera as referências e entrega o encaminhamento pronto. **O resultado esperado é o arquivo preenchido pelo executor do prompt, não apenas orientação no chat.**

Na base consultada, `migracao_helper` e a skill `orientar-migracao` são leitores/orientadores. O prompt `planejar-lotes` já usa um perfil separado com ferramentas de escrita. Reutilizar esse padrão para `planejar-sprints`, sem conceder ao helper permissão geral de execução.

| Cliente | Comportamento esperado |
| --- | --- |
| GitHub Copilot/DevSquad | Preparar prompt com perfil disponível de planejamento e escrita. Usar `devsquad.plan` somente se as capacidades reais forem suficientes; o nome do perfil, sozinho, não comprova isso. Permitir encaminhamento explícito a outro executor compatível. |
| Codex | Preparar mensagem com o papel de planejamento macro e os mesmos arquivos/limites. Aproveitar `using-agent-skills`, se disponível, para descobrir skills pertinentes; a skill não é um agente e não é dependência obrigatória. |
| Perfil ou skill indisponível | Informar a limitação e manter contexto utilizável por executor disponível ou preenchimento manual. Não simular delegação, escrita ou execução. |

A implementação deve atualizar o encaminhamento dos helpers e comprovar o fluxo em cada cliente. Alterações de instruções e perfis pertencem à implementação da feature; executar um prompt de planejamento não concede GO para corretivas ou aceite de resultados.

### 2.2. Incluir todos os projetos

**Complemento solicitado pelo desenvolvedor em 08/10/2026:** permitir selecionar todos os projetos de uma vez. A opção **Todos os projetos do workspace** reutiliza a descoberta de projetos de aplicação do workspace salvo, incluindo agregadores Maven/`packaging=pom` reconhecidos como projetos. Não inclui toda pasta arbitrária nem varre repositórios externos ao workspace. A opção **Escolher projetos** permite delimitar um subconjunto.

Mostrar nomes, Sources, quantidade de projetos e disponibilidade dos registros/evidências antes de preparar o contexto, permitindo ajustar o escopo. Projetos sem registro, MTA, priorização, ficha, plano ou estimativa ficam identificados com suas lacunas; não são removidos silenciosamente nem recebem zero issues/esforço por ausência de dados. O usuário pode mantê-los no rascunho para refinamento ou excluí-los explicitamente. Continuam valendo as regras de base por evidências e de viabilidade não avaliável quando faltarem dados essenciais.

Persistir o modo de seleção e a lista concreta de identidades/Source usada, sem duplicar o mesmo projeto. Retomar preserva essa lista: adicionar um projeto ao workspace não amplia automaticamente o planejamento anterior. Para atualizar o conjunto de todos os projetos, usar a mesma Run Task e registrar a mudança de escopo na revisão. O helper deve reconhecer o pedido explícito de todos os projetos e encaminhar para essa opção, sem pedir seleção individual repetida nem assumir esse escopo em pedidos que não o indiquem.

## 3. Entradas e fontes de verdade

### 3.1. Parâmetros do planejamento

Os nomes abaixo definem o contrato lógico; o Codex deve adaptá-los às convenções existentes, sem duplicar configurações equivalentes.

| Entrada | Regra |
| --- | --- |
| Escopo e projetos | Seleção explícita de todos os projetos do workspace ou de um subconjunto, com lista concreta de identidades/Source e registros; objetivo da migração, origem, destino e exclusões. Reutilizar o escopo salvo na retomada. Nunca inferir todos apenas por estarem no workspace. |
| `SprintStartDate` | Dia de início da Sprint 1, informado pelo usuário. Persistir como `YYYY-MM-DD`; apresentar como `DD/MM/AAAA`. |
| `SprintLengthDays` | **14 dias corridos, fixos no MVP solicitado.** O calendário útil determina capacidade, não a duração da sprint. |
| `MaxPreparationSprints` | Máximo de sprints com trabalho de preparação de ambiente. Inteiro ≥ 0. |
| `MaxImplementationSprints` | Máximo de sprints com implementação da migração. Inteiro ≥ 0. |
| `MaxTestSprints` | Máximo de sprints com campanha de testes integrados/homologação. Inteiro ≥ 0. Não limita testes de cada corretiva. |
| `ProductionDeadline` | Data máxima inclusiva de implantação em produção. Diferenciar da data prevista, que será calculada/proposta. |
| `MaxTotalSprints` | Limite total adicional, quando já informado pelo usuário. Opcional se início e prazo já delimitarem o horizonte. Preparação, implementação, testes e implantação compartilham esse limite. |
| `MaxDevelopers` | Teto de desenvolvedores simultâneos. Informar a quantidade planejada por sprint, sempre ≤ teto. |
| Arquiteto e DevOps | **Um arquiteto e um DevOps**, adicionais ao teto de desenvolvedores, cada um com sua disponibilidade. Não presumir dedicação integral. |
| Dedicação e calendário | Disponibilidade por papel/sprint, dias úteis, feriados/ausências conhecidos e reservas. Reutilizar dados anteriores; premissas não confirmadas ficam identificadas. |
| Implantação | Janela ou duração necessária, esforço por papel, dependências e eventual congelamento. Reservar capacidade dentro do horizonte. Sem essa informação, a previsão de produção é condicional. |
| Estimativas | Esforço restante, unidade, faixa, origem, hipótese e confiança por macroatividade/agrupamento. Preservar estimativas humanas vigentes. |
| Política de prioridade | Decisões humanas, criticidade, dependências e regra de desempate. Categoria MTA não determina automaticamente prioridade. |
| Data de referência | Momento do acompanhamento: separa realizado, sprint em curso e previsão futura. |

Não exigir uma sequência longa de perguntas: oferecer valores anteriores e ajustes por exceção. O mínimo para um cenário com datas é início, três limites por fase, prazo de produção e equipe; capacidade/estimativas ausentes podem produzir rascunho, mas impedem afirmar viabilidade. Sem início, conservar a possibilidade já proposta de um rascunho relativo “Sprint 1..N”; ele não demonstra atendimento à data de produção. Valor zero para uma fase exige evidência de que está atendida ou justificativa de inaplicabilidade.

### 3.2. Contexto reaproveitado

| Fonte | Uso no planejamento |
| --- | --- |
| `ProjectIndexPath` | Localizar projetos e documentos. Na base atual, o índice é `.harness/projetos/indice-projetos.md`. |
| `MigrationPath` de cada projeto | Recuperar escopo, decisões humanas, categorias e andamento. Usar o caminho autoritativo, inclusive nomes legados. |
| Priorização e fichas | Aproveitar análise, cobertura, risco, repetibilidade, dependências e referências existentes. Ranking antigo não substitui a decisão atual do registro. |
| `PlanPath` e `TodoPath` vinculados | Identificar objetivo, esforço remanescente e tarefas em curso. Existência do plano ou checkbox isolado não comprova conclusão aceita. |
| Anexos e resultados | Reutilizar build, testes, MTA, Sonar e evidências funcionais disponíveis. Registrar ausência e comparabilidade. |
| Configuração JBoss e implantação | Referenciar inventário, guia/parecer de migração de servidor, ambientes, esteira, dependências externas e janela de produção. |
| Planejamento macro anterior | Preservar baseline, decisões, objetivos, comentários, compromissos explicitamente registrados e histórico de revisões. |

Preservar `Project`, `Source`, `Source/ID`, `RequestId`, `PlanningBasis`, `MtaOrigin`, `RunId` quando existentes, referências consolidadas e hashes das entradas efetivamente utilizadas. Em `PlanningBasis=EVIDENCIAS`, não inventar rodada, categoria ou contagem MTA. Múltiplos projetos podem ter bases diferentes, declaradas individualmente.

Ler o conteúdo pertinente, não apenas os títulos. Não exigir pacote MTA original quando o contexto consolidado já autoriza e permite a leitura. MCP é opcional; arquivos devem sustentar o fluxo sem novos servidores, instalações ou consultas manuais obrigatórias. Consultas paginadas devem ter cobertura declarada: uma página não representa o total.

Conflitos entre fontes ficam explícitos. O índice localiza; o registro mantém decisões; evidências sustentam resultados. Não sobrescrever decisão humana com inferência do agente. A aplicação preserva seu perfil técnico vigente — por exemplo, Java 8/`javax`/EAP 7.4 — sem adotar outra plataforma por conveniência de planejamento.

## 4. Regras para um cronograma coerente

### 4.1. Calendário, fases e prazo

Para a sprint `n`, com datas inclusivas:

```text
inicio(n) = inicio(1) + 14 × (n − 1) dias
fim(n)    = inicio(n) + 13 dias
```

Sprints consecutivas não se sobrepõem nem deixam lacunas artificiais. Feriados reduzem capacidade e não deslocam a cadência. Validar datas reais e rejeitar prazo anterior ao início.

**Os máximos por fase são tetos, não duração obrigatória e não parcelas automaticamente somáveis.** Uma sprint pode conter preparação e implementação, desde que haja capacidade e dependências satisfeitas. Cada sprint com esforço de uma fase conta uma vez para o limite dessa fase, mesmo com vários projetos. Classificar explicitamente o esforço por fase para impedir ocultar preparação como implementação ou testes finais como reserva genérica.

Testes de corretiva, revisão e integração acompanham a implementação. `MaxTestSprints` controla a campanha integrada/homologação. A migração de configuração JBoss deve ter fase e dependências explícitas; o trabalho compartilhado entre aplicações é contado uma vez, com referências a todos os beneficiários.

A produção pode ocorrer dentro de uma sprint ou numa janela posterior à última sprint completa. Se a data limite cair no meio de uma sprint, manter a sprint de 14 dias e mostrar o corte do prazo: somente os dias até a implantação contam para entregas necessárias à produção. Nunca atribuir capacidade integral a esse trecho nem inventar uma sprint menor. Dias posteriores ao prazo não podem sustentar a previsão de entrega no prazo.

Quando houver `MaxTotalSprints`, toda atividade, inclusive implantação, deve terminar dentro da interseção entre esse horizonte e `ProductionDeadline`. Sem limite total adicional, usar início/prazo para delimitar o calendário. Uma janela entre o fim da última sprint planejada e o prazo deve aparecer com capacidade própria; não pode ser trabalho escondido.

### 4.2. Capacidade por papel

Usar no MVP **dias-pessoa por papel** para relacionar calendário e esforço. Se o projeto possui outra unidade, preservar a informação original e obter uma estimativa comparável; não converter automaticamente pontos MTA ou story points em dias.

```text
capacidade_bruta(papel, sprint) = soma da disponibilidade diária das pessoas do papel
capacidade_liquida             = capacidade_bruta − reservas não alocadas como atividade
carga(papel, sprint)           = soma do esforço restante alocado ao papel na sprint
restrição                     = carga ≤ capacidade_liquida, em cada papel e sprint
```

Exemplo aritmético: 2 devs × 10 dias úteis × 80% = 16 dias-pessoa de desenvolvimento; 1 arquiteto a 50% = 5; 1 DevOps a 50% = 5. São três capacidades separadas. A fórmula calcula disponibilidade, não produtividade nem número de issues resolvidas.

Ausências são descontadas uma única vez. Revisão, testes, integração, retrabalho e implantação podem ser esforço explícito ou reserva, sem dupla contagem. A reserva não pode esconder carga técnica conhecida. Se a mesma pessoa acumular papéis, registrar a restrição compartilhada e não somar duas disponibilidades integrais.

O teto de desenvolvedores não significa equipe disponível em todas as sprints. Não transformar arquiteto ou DevOps em dev adicional sem alocação explícita que consuma sua capacidade. Se homologação depender de área externa, declarar responsável/dependência e disponibilidade conhecida; não inventar testadores ou capacidade de negócio.

### 4.3. Estimar e distribuir

1. Reaproveitar estimativas existentes que sejam comparáveis e estimar somente o trabalho restante.
2. Agrupar por objetivo técnico, dependências e entrega verificável. Compartilhar categoria/regra não prova esforço igual nem autoriza um único lote para projetos distintos.
3. Quando necessário, o agente propõe faixa mínima/referência/máxima de esforço por papel, com fonte e hipótese. Selecionar qual valor sustenta o cenário e testar a sensibilidade ao limite superior. A classificação de confiança é qualitativa, sem probabilidades inventadas.
4. Sem evidência suficiente, marcar **a estimar** e indicar refinamento/piloto necessário. Não usar esforço zero nem repartir issues igualmente pelas sprints.
5. Respeitar precedências, competências, compromissos vigentes e limites. Dependência no meio da sprint exige datas/ordem que comprovem o paralelismo; sem isso, adotar alocação conservadora.
6. Issue maior que uma sprint deve ser decomposta em trabalho executável ou distribuída com continuidade explícita. Conta como concluída apenas quando os critérios completos forem atendidos.
7. Exibir escopo alocado, bloqueado, não estimado e fora do horizonte, com motivo. Descrever o gargalo real — inclusive arquiteto ou DevOps — e opções para decisão.

Manter estados distintos de **elaboração** (`RASCUNHO`, `PROPOSTA`, `REVISADO`) e **viabilidade** (`NAO_AVALIAVEL`, `CABE_NAS_PREMISSAS`, `EM_RISCO`, `NAO_CABE`). `CABE_NAS_PREMISSAS` exige esforço, dependências, limites e capacidade compatíveis; não representa compromisso aprovado. Sem estimativas relevantes, usar `NAO_AVALIAVEL`. Conflito demonstrado com prazo/capacidade exige `NAO_CABE`; risco por faixa ou dependência ainda incerta exige explicação.

### 4.4. Percentuais, marcos e conclusão

Fixar a baseline `B0`: conjunto identificado de **issues únicas** do escopo inicial e `N0 = |B0|`, com fonte, categoria, situação inicial e data de captura. Preservar identidade `Source/ID`; mesma regra em projetos distintos não é uma única issue. Não misturar contagem de incidentes, regras, issues examinadas e issues concluídas.

```text
previsto_acumulado(s)  = 100 × issues de B0 previstas concluídas até s / N0
realizado_acumulado(t) = 100 × issues de B0 comprovadamente concluídas em t / N0
```

Incluir no acumulado as conclusões anteriores ao início, claramente identificadas. Contar cada issue uma vez, na conclusão prevista ou comprovada, sem crédito fracionário por atravessar sprints. Metas são derivadas de IDs/agrupamentos estimados; se o usuário solicitar “20% na Sprint 1”, tratar como meta desejada e verificar viabilidade. Se `N0=0` ou desconhecido, apresentar percentual **N/A**, não 0% ou 100%.

Conclusão comprovada depende de evidências e aceite conforme o contrato vigente; não pode decorrer da alocação, criação de documento, exame ou desaparecimento isolado do achado. Exibir resultados técnicos e comparações pendentes quando relevantes. “100% das issues” não encerra automaticamente configuração, testes, homologação e implantação.

Novas issues, reaberturas e exclusões são mostradas separadamente. Manter o denominador original e apresentar também o escopo atual com sua composição. Falso positivo ou exclusão justificada não vira corretiva concluída. Reabertura reduz o realizado da visão atual sem reescrever percentuais de revisões históricas. Rebaseline exige escolha explícita e vínculo à baseline anterior.

Além dos percentuais, cada sprint precisa de **um marco principal observável**, por exemplo: “20 de 100 issues concluídas com aceite e configuração EAP validada em DES”. Se o marco tiver duas condições, ambas precisam de evidência. Previsão de marco não significa marco atingido.

## 5. Template do planejamento entregue ao usuário

O template deve ser reutilizável e conter apenas o necessário ao acompanhamento. Usar aproximadamente 5–8 macroatividades, uma linha por sprint e um parágrafo curto de objetivo de HU por sprint. Referenciar os detalhes em vez de transcrever catálogos ou checklists. Para poucos sprints, buscar leitura de cerca de duas páginas, sem impor tamanho que elimine informação necessária.

O [template separado](../modelos/planejamento-sprints.template.md) é a fonte única do contrato editorial do Markdown gerado. Substituir os campos e repetir somente as linhas/blocos necessários. O agente deve preencher a narrativa e os objetivos; os números e datas vêm dos dados validados.

Cada sprint tem um objetivo principal de HU. Se houver entregas independentes, admitir HUs adicionais em linhas curtas, sem forçar vários projetos numa única HU. IDs corporativos só aparecem se fornecidos; usar rótulo local como `HU proposta S1` enquanto não houver cadastro real. HU é o formato de comunicação solicitado; não pressupõe criação em Azure DevOps ou ServiceNow.

### 5.1. Exemplo ilustrativo de distribuição

**Exemplo fictício, não estimativa do projeto:** início em 19/10/2026; preparação ≤ 1 sprint; implementação ≤ 3; testes integrados ≤ 1; produção até 18/12/2026. Baseline de 100 issues, nenhuma concluída inicialmente; até 2 devs, 1 arquiteto e 1 DevOps. Percentuais abaixo são metas demonstrativas, condicionadas à estimativa e capacidade que ainda precisariam ser preenchidas.

| Período | Distribuição macro e marco proposto | Meta acumulada |
| --- | --- | --- |
| S1 — 19/10–01/11 | Preparação + primeira fatia; ambiente disponível, configuração JBoss inicial validada e 20 issues aceitas | 20/100 = 20% |
| S2 — 02/11–15/11 | Implementação; concluir agrupamentos prioritários e validar integrações correspondentes | 60/100 = 60% |
| S3 — 16/11–29/11 | Implementação; completar corretivas e configuração, com evidências para iniciar campanha final | 100/100 = 100% |
| S4 — 30/11–13/12 | Testes integrados/homologação; evidências funcionais e pendências impeditivas tratadas | 100/100 mantidos se não houver reabertura |
| Janela — 14/12–18/12 | Implantação, verificações e reserva operacional, com capacidade calculada para esses dias | Marco de produção, independente da contagem de issues |

Preparação e implementação se sobrepõem na S1; isso consome uma sprint de cada limite. A campanha final não elimina os testes nas S1–S3. A janela de produção está no horizonte e exige esforço e disponibilidade próprios. Reaberturas podem exigir capacidade de implementação adicional e tornar os limites inviáveis; não escondê-las em “testes”. O exemplo não usa um `MaxTotalSprints` adicional de quatro, pois isso terminaria o horizonte em 13/12.

Exemplo de texto da primeira HU: **“Disponibilizar o ambiente de migração e validar a primeira fatia da aplicação no EAP de destino, incluindo a configuração necessária, para comprovar o fluxo de build, deploy e testes e calibrar o esforço das próximas sprints. O marco proposto é atingir 20 issues concluídas com evidências e aceite, além do ambiente operacional.”**

## 6. Contrato de artefatos e arquitetura da implementação

### 6.1. Separação de responsabilidades

| Componente | Responsabilidade |
| --- | --- |
| Run Task / entrada PowerShell | Selecionar/reutilizar escopo, coletar restrições, validar entradas e preparar contexto/prompt. |
| Módulo determinístico | Gerar calendário e capacidades; validar alocações, precedências, limites, identidade e percentuais; produzir diagnósticos reproduzíveis. |
| Agente de planejamento | Interpretar documentos, propor estimativas fundamentadas e agrupamentos, preencher narrativa/HUs, explicar riscos e reconciliar mudanças. |
| Template | Padronizar a visão sintética e links. |
| Recibo e dados estruturados | Preservar entradas, hipóteses, IDs, fontes, revisões e alocações utilizadas nos cálculos. |

Aplicar portas e adaptadores de forma simples: cálculo e validação independentes do cliente de IA; coleta reutilizando os módulos do harness; adaptação de prompt por cliente. Não criar framework novo, banco de dados, serviço, dependência de Node/MCP ou extensão VS Code como pré-requisito. Manter Windows PowerShell 5.1 e o padrão atual de tarefas `type: process`, parâmetros separados e caminhos com espaços.

As regras numéricas devem ser verificadas por código. Não prometer que duas execuções do LLM produzirão a mesma estimativa; exigir que **os mesmos dados estruturados produzam os mesmos cálculos e diagnósticos**. A saída do agente é uma proposta validável, não autoridade para alterar os limites.

### 6.2. Caminhos propostos

Reutilizar convenções equivalentes se o repositório evoluir antes da implementação. Os destinos do recibo são autoritativos.

```text
doc/features/planejamento-macro-sprints.md       # esta feature, já existente
doc/modelos/planejamento-sprints.template.md      # template desta especificação
.github/prompts/planejar-sprints.prompt.md        # novo prompt
scripts/preparar-sprints.ps1                     # nova entrada da operação
scripts/HarnessSprintPlanning.psm1              # regras e preparação

.harness/sprints/<PlanningId>/
  atual.json                                   # ponteiro explícito da revisão validada
  revisoes/<RevisionId>/
    contexto.json                              # entradas, fontes, hashes e contrato
    planejar-sprints.prompt.md                  # prompt preparado para o cliente
    planejamento-sprints.md                    # visão sintética preenchida
    planejamento-sprints.json                  # dados e alocações
    validacao.json                             # diagnósticos determinísticos
```

Não reutilizar `PlanPath`/`TodoPath` de uma corretiva como destino macro. Usar campos próprios: `SprintPlanPath`, `SprintDataPath` e `ValidationPath`. As referências aos planos de issues são entradas de leitura. Preservar artefatos oficiais de sprints nas rotinas de limpeza, sem colocá-los em pastas de backups temporários.

### 6.3. Campos mínimos dos dados estruturados

| Grupo | Conteúdo |
| --- | --- |
| Identidade | `SchemaVersion`, `Purpose=sprint-planning`, `PlanningId`, `RevisionId`, `Previous`, cenário, estado e data de referência. |
| Fontes | Modo de seleção e lista concreta de projetos/Source, caminhos exatos, hashes, base MTA/evidências por projeto, cobertura, lacunas e conflitos. |
| Restrições | Início, 14 dias, máximos por fase, prazo de produção, limite total quando presente, janela/duração de implantação e calendário. |
| Equipe | Teto de devs; 1 arquiteto; 1 DevOps; pessoas/quantidades alocadas, dedicação, ausências, reservas e restrições compartilhadas. |
| Baseline | ID, data, conjunto de issues únicas, categorias, total inicial, conclusões iniciais e mudanças posteriores de escopo. |
| Trabalho | ID de macroatividade/agrupamento, fase, projetos/Source/IDs, esforço restante por papel e faixa, fonte, confiança, dependências e critério de conclusão. |
| Sprints | ID, datas, capacidade por papel, alocações, objetivos/HUs propostas, marcos e conclusões previstas por ID. |
| Acompanhamento | Realizado com fonte/evidência, reaberturas, exclusões justificadas, trabalho fora do prazo e questões a decidir. |
| Revisão | Motivo, alterações de parâmetros/alocação, impacto em metas/prazo, decisões humanas preservadas e conteúdo editorial. |

JSON e Markdown devem representar a mesma revisão. O agente pode propor números no JSON, mas a validação recalcula totais e acusa divergências. Preservar contribuições manuais do Markdown; mudança manual em campo calculado exige reconciliação explícita, sem adotá-la silenciosamente como fato nem apagar o comentário.

### 6.4. Prompt-base para gerar ou revisar o plano

```text
Operação: planejar-sprints.
Use ContextPath=<caminho real>, TemplatePath=<caminho real> e
Previous=<referência explícita ou ausente>.

Leia o contrato recebido e as fontes pertinentes do escopo selecionado:
índice, registros atuais, priorização, fichas, planos/to-dos e evidências.
Recupere as decisões já informadas. Pergunte apenas lacunas essenciais.

Elabore ou reconcilie o planejamento macro em sprints de 14 dias, respeitando
início, limites por fase, teto de devs, um arquiteto, um DevOps, dedicação,
dependências, testes e a data máxima de produção.

Proponha estimativas fundamentadas, sem converter pontos MTA em tempo.
Preencha escopo, linha do tempo, marcos, metas e objetivo de HU por sprint.
Separe previsto de comprovado e preserve a baseline e a revisão anterior.
Mostre o que não cabe, o que não foi estimado e o que depende de decisão.

Grave SprintPlanPath e SprintDataPath do contexto. Solicite/use a validação
prevista no fluxo real do cliente; não declare validação sem resultado.
Não escreva nos registros, planos/to-dos de corretiva, código ou configuração
dos servidores. Não execute corretivas ou implantação.

Ao terminar, apresente os caminhos gravados, a viabilidade, as principais
mudanças e as decisões necessárias. Rascunho não é planejamento validado.
```

A geração do prompt usa os valores já coletados; o usuário não precisa copiá-los novamente. Instruções de escrita são limites de atuação, não uma sandbox técnica por diretório. Não adicionar terminal irrestrito a perfis de planejamento somente para contornar a validação: disponibilizar o validador no fluxo autorizado ou orientar sua execução manual pela mesma operação.

## 7. Reconciliação e histórico

Revisar a partir de um motivo concreto: novas issues/evidências, conclusão ou reabertura, alteração de estimativa, equipe, dedicação, janela, prazo ou decisão de escopo. Troca de branch/HEAD isolada não é motivo; preservar Git informativo e não coletá-lo como gate no planejamento da aplicação.

1. Resolver explicitamente o planejamento e sua revisão vinculada. Havendo múltiplos candidatos, pedir escolha.
2. Ler a versão anterior e as fontes atuais pertinentes; comparar identidade, conteúdo/hashes e parâmetros.
3. Atualizar fatos somente com evidência. Preservar as decisões humanas e expor conflitos, sem escolher a versão mais recente por conveniência.
4. Congelar a história das sprints encerradas. Mostrar reaberturas no acompanhamento atual. Na sprint em curso, descontar dias já transcorridos e usar esforço restante, preservando realizado e trabalho em andamento.
5. Replanejar o restante; mudança no objetivo da sprint em curso ou em marco acordado deve ser destacada para revisão, não aplicada como compromisso aceito.
6. Gerar revisão sucessora com `Previous`, causa e diferenças. Cenário alternativo recebe identidade própria e não substitui silenciosamente o cenário principal.
7. Validar e atualizar `atual.json` somente após gravação consistente dos artefatos. Falha, cancelamento ou validação inconsistente preservam o ponteiro anterior e identificam o rascunho incompleto.

Mesmas entradas e mesma solicitação retomam o trabalho sem duplicar revisões automaticamente. Uma nova simulação intencional é permitida e registra o motivo. Não reescrever revisões anteriores nem criar outra baseline implicitamente. Detectar alteração concorrente antes de substituir um rascunho; preservar a edição do usuário e pedir conciliação apenas quando houver conflito real.

## 8. Escopo de implementação e critérios de aceite

### 8.1. Entrega incremental

| Incremento | Resultado utilizável |
| --- | --- |
| 1 — Coleta e template | Uma Run Task; entradas reutilizáveis; contexto/prompt por cliente; template e rascunho com referências reais. |
| 2 — Simulação consistente | Datas, limites, capacidade por papel, estimativas, alocações, linha do tempo, percentuais e diagnósticos verificáveis. |
| 3 — Acompanhamento | Revisão vinculada, previsto × realizado, mudanças de escopo, preservação de decisões e retomada sem duplicação. |

Os incrementos organizam a implementação; não reduzem o aceite completo da feature. Nenhum incremento deve declarar disponível a simulação se apenas o prompt estiver pronto.

### 8.2. Cenários verificáveis

| ID | Cenário | Resultado esperado |
| --- | --- | --- |
| AC-01 | Executar a tarefa com contexto conhecido | Reutiliza projetos, escolhas e parâmetros; pergunta somente lacunas e ajustes. |
| AC-02 | Informar início e sprints de duas semanas | Calcula datas inclusivas exatas, incluindo virada de mês/ano; feriados afetam capacidade, não duração. |
| AC-03 | Sobrepor preparação e implementação | Conta a sprint em ambos os limites, respeita precedências e não duplica capacidade. |
| AC-04 | Prazo no meio de uma sprint ou janela após a última sprint completa | Expõe o corte/janela e calcula apenas capacidade disponível até o prazo; respeita também limite total quando informado. |
| AC-05 | Variar devs por sprint e dedicação dos três papéis | Respeita teto de devs e capacidade separada; identifica gargalo de arquiteto/DevOps e sobreposição de papéis. |
| AC-06 | Faltar esforço, disponibilidade ou dependência relevante | Mantém lacuna e rascunho/viabilidade não avaliável; não converte issues/pontos MTA em produtividade. |
| AC-07 | Demandar mais trabalho que prazo ou capacidade permitem | Mostra excedente/violação, classifica e oferece opções; não aumenta limites nem remove escopo automaticamente. |
| AC-08 | Baseline com mesma regra em projetos distintos e issue que atravessa sprints | Preserva identidades e conta cada issue uma vez, no encerramento; mostra base/categoria e percentuais corretos. |
| AC-09 | Total zero/desconhecido, novas issues, reabertura e falso positivo | Usa N/A quando necessário; preserva baseline; distingue mudança de escopo de conclusão comprovada. |
| AC-10 | Preencher o planejamento | Entrega escopo, timeline, marco principal e objetivo de HU por sprint, capacidade, produção e links reais de índice/registro/plano/to-do. |
| AC-11 | Planejar JBoss | Inclui configuração, ambiente, evidências de validação e dependências de implantação, além da correção de código. |
| AC-12 | Revisar com nova evidência/equipe | Preserva decisões e história, usa esforço/capacidade restantes, grava `Previous` e resume diferenças. |
| AC-13 | Reexecutar sem mudança ou cancelar/falhar | Retoma a solicitação; não duplica indevidamente, não apaga histórico nem publica revisão inconsistente como atual. |
| AC-14 | Usar Copilot e Codex, com/sem MCP/perfil opcional | Mesmo contrato e saída; comprova capacidade do executor, sem exigir instalação nem fabricar delegação. |
| AC-15 | Inspecionar efeitos do planejamento | Nenhuma corretiva, escrita em registro/plano/to-do de issue, marcação de GO/aceite ou implantação como efeito da simulação. |
| AC-16 | Limpeza, edição manual e caminhos Windows com espaços | Preserva planos oficiais e comentários; trata conflitos de edição; tarefas funcionam em PowerShell 5.1. |
| AC-17 | Selecionar todos os projetos, ajustar um subconjunto e retomar após mudança no workspace | Inclui todos os projetos de aplicação reconhecidos, inclusive agregadores, sem duplicar identidades; mostra escopo e lacunas sem omissão/zeros fictícios. Persiste a lista escolhida e só altera o escopo anterior por escolha explícita, com histórico. |

Testar especialmente regras de calendário, capacidade, identidade/percentuais e reconciliação com fixtures pequenas. Fazer um ensaio ponta a ponta em cada cliente com o mesmo escopo. Testes determinísticos não comprovam obediência do agente; os ensaios verificam leitura, preenchimento, destinos e limites reais. Não repetir suites alheias à mudança sem risco concreto.

## 9. Encaminhamento para o Codex que implementa o harness

Ao receber este documento:

1. Atualize a leitura da `main` e confira `AGENTS.md`, contrato e ADRs vigentes. Use esta consolidação para atualizar **a feature MACRO-01 existente**, sem criar proposta concorrente.
2. Identifique mudanças já implementadas desde o commit de referência. Preserve trabalho local. Para editar o harness, crie/retome `harness/<objetivo>` conforme a regra vigente; não implemente diretamente na principal.
3. Registre o recorte em `tasks/plan.md` e `tasks/todo.md`. Esses arquivos acompanham a evolução do harness, não as sprints das aplicações.
4. Reutilize coleta, seleção, recibos e resolução de caminhos dos módulos atuais. Confirme os nomes propostos e registre ajustes de contrato antes de usá-los.
5. Implemente tarefa, template, prompt, cálculo/validação e revisão; atualize helpers, guia do desenvolvedor e montagem/distribuição das tarefas onde aplicável. Preserve o fluxo detalhado de corretivas.
6. Demonstre o cenário ilustrativo com estimativas de fixture explícitas e depois um recorte real. Registre quais critérios passaram e quais dependem de ensaio no Windows/cliente do desenvolvedor.

**Mensagem de encaminhamento sugerida:**

> Consolide a feature `doc/features/planejamento-macro-sprints.md` com este documento e use-a como especificação da MACRO-01. Confira o que já existe na `main`, siga `AGENTS.md` e registre o plano de implementação nos arquivos do harness. A capacidade deve coletar restrições por Run Task, preparar contexto/prompt para Copilot ou Codex e permitir ao agente preencher e revisar o planejamento sintético. Preserve os máximos por fase, a equipe, o prazo de produção, a baseline de issues e os documentos de corretiva. Na etapa autorizada de implementação, avance por incrementos utilizáveis e valide os critérios de aceite.

## 10. Referências e limites

**Base do projeto conferida em 08/10/2026**, no commit acima. Os links relativos abaixo são resolvidos quando este arquivo estiver em `doc/features/`:

- [Estratégia do harness](../estrategia/estrategia-harness_.md) e [conciliação das evoluções](../estrategia/conciliacao-evolucao-harness.md).
- [Contrato de migração assistida](../especificacoes/planejamento-copilot.md).
- [ADR-0002 — separação harness/aplicação](../adr/0002-separacao-harness-e-migracao-progressiva.md), [ADR-0004 — Git informativo](../adr/0004-git-informativo-sem-controle-de-branches.md) e [ADR-0005 — planejamento pelo registro](../adr/0005-planejamento-orientado-pelo-registro.md).
- [Guia de planejamento](../guias/tools/planejamento-migracao.md) e [migração da configuração JBoss](../guias/tools/migracao-configuracao-jboss.md).
- [Skill comum de orientação](../../.agents/skills/orientar-migracao/SKILL.md), [helper principal](../../.github/agents/migracao_helper.agent.md) e [prompt de planejamento de lote](../../.github/prompts/planejar-lotes.prompt.md).
- [Backlog MACRO-01](../../tasks/todo.md#backlog-vigente).

**Documentação oficial consultada em 08/10/2026:**

- Microsoft, [Tasks no VS Code](https://code.visualstudio.com/docs/debugtest/tasks): integração de ferramentas externas e tarefas por processo.
- Microsoft, [Variables Reference](https://code.visualstudio.com/docs/reference/variables-reference): entradas `promptString`, `pickString` e `command`. A coleta pode aproveitar o terminal interativo já usado pelo harness; não exige assistente visual novo.
- Schwaber e Sutherland, [Scrum Guide](https://scrumguides.org/scrum-guide.html): objetivo da sprint, planejamento com capacidade e adaptação com evidências. O guia não prescreve sprint de duas semanas, dias-pessoa, percentuais de issues ou fases de migração; essas são escolhas deste requisito.

O cronograma apoia decisões de migração. A separação por papéis é uma simulação de capacidade e não uma definição de papéis formais de Scrum. As regras de fase não transferem toda a qualidade para o fim do trabalho. Datas, percentuais e viabilidade só podem ser afirmados nas condições e evidências registradas.
