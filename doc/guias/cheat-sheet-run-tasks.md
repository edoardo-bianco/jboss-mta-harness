---
html:
  embed_local_images: true
  embed_svg: true
  offline: true
---

# Cheat sheet — Run Tasks do harness

**Data:** 15/10/2026. **Escopo:** operações do harness de migração JBoss.
**Referência operacional:** estado corrente por projeto da [ADR-0009](../adr/0009-estado-corrente-por-projeto.md). Validação técnica registrada no [plano](../../tasks/historico/plan-ate-2026-10-17.md); aceite integrado humano separado.

## Consulta rápida

A jornada operacional parte da configuração do ambiente, passa pelo diagnóstico e planejamento e chega à implementação, verificação e operação da aplicação. As **25 entradas** de [`.vscode/tasks.json`](../../.vscode/tasks.json) oferecem essas ações. A matriz mantém seus nomes operacionais e propõe a organização por domínio/subdomínio. **D** executa uma operação determinística; **P** prepara material para acionamento explícito posterior do agente. Uma tarefa pode combinar P e D em ações diferentes. O acionamento do agente de codificação permanece uma ação explícita do desenvolvedor.

| Run Task | Domínio / subdomínio | Funcionalidade disponível e efeito principal | Agente | Implementação / guia |
| --- | --- | --- | --- | --- |
| `Workspace: configurar caminhos` | Execução / configuração | Configurar ferramentas e integrações locais, com procedimentos de preparo e certificado quando aplicáveis. | D | [configurar-caminhos.ps1](../../scripts/configurar-caminhos.ps1), [workspace](tools/workspace.md) |
| `Workspace: gerar workspace` | Execução / ambiente | Gerar workspace local e recursos de integração; preservar personalizações e backups próprios do gerador. | D | [gerar-workspace.ps1](../../scripts/gerar-workspace.ps1) |
| `Workspace: conferir configuracao ao abrir` | Execução / ambiente | Conferir configuração na abertura e encaminhar ajustes; não é uma consulta genericamente sem escrita. | D | [conferir-ambiente.ps1](../../scripts/conferir-ambiente.ps1) |
| `Workspace: atualizar indice dos projetos` | Trabalho / descoberta | Associar projetos ao POM, inicializar registros e reconstruir links dos documentos e evidências correntes; preservar decisões humanas. | D | [atualizar-indice-projetos.ps1](../../scripts/atualizar-indice-projetos.ps1) |
| `Workspace: limpar execucoes` | Evidências / retenção | Limpar resíduos temporários e backups selecionados; preservar trabalho corrente, evidências e origens externas. Descarte legado tem procedimento separado. | D | [limpar-execucoes.ps1](../../scripts/limpar-execucoes.ps1) |
| `MTA: conferir ambiente` | Diagnóstico / preparação | Verificar ferramentas, configuração e projeto selecionado antes da análise. | D | [conferir-ambiente.ps1](../../scripts/conferir-ambiente.ps1), [MTA](tools/mta.md) |
| `MTA: executar analise` | Diagnóstico / análise | Executar MTA no projeto escolhido e publicar diagnóstico corrente; manter última tentativa/log separados do último relatório utilizável. | D | [executar-mta.ps1](../../scripts/executar-mta.ps1) |
| `MTA: acompanhar log da analise` | Diagnóstico / acompanhamento | Acompanhar o log corrente da última tentativa do projeto. | D | [acompanhar-log-mta.ps1](../../scripts/acompanhar-log-mta.ps1) |
| `MTA: acompanhar atividade interna` | Diagnóstico / acompanhamento | Exibir o log interno corrente do projeto. | D | [acompanhar-log-mta.ps1](../../scripts/acompanhar-log-mta.ps1) |
| `MTA: abrir ultimo relatorio` | Diagnóstico / apresentação | Abrir o relatório utilizável na origem configurada; atualizar o registro exige reconciliação explícita. | D | [abrir-relatorio-mta.ps1](../../scripts/abrir-relatorio-mta.ps1) |
| `Planejamento: planejar sprints` | Planejamento de portfólio / escopo, calendário e capacidade | Novo/Retomar/Revisar prepara o cenário corrente dos projetos; Validar calcula cronograma, prazo, capacidade e fases, preservando baseline e consumo. | P: `planejar-sprints` + D: validação | [preparar-sprints.ps1](../../scripts/preparar-sprints.ps1), [guia](tools/planejamento-sprints.md), [contrato](../contratos/planejamento-sprints.md) |
| `Planejamento: priorizar issues` | Trabalho / triagem | Selecionar categoria, projetos e fatia; recriar/progredir/retomar o conjunto corrente; preparar ranking cumulativo e fichas. | P: `priorizar-issues` | [preparar-priorizacao.ps1](../../scripts/preparar-priorizacao.ps1), [guia](tools/priorizacao-issues.md) |
| `Planejamento: planejar` | Trabalho / proposta | Criar, retomar ou atualizar preparo a partir do registro, ficha e anexos; agente ou humano elabora um lote. | P: `planejar-lotes` | [preparar-planejamento.ps1](../../scripts/preparar-planejamento.ps1), [guia](tools/planejamento-migracao.md) |
| `Planejamento: atualizar registro de migracao` | Trabalho / reconciliação | Preparar comparação de fontes locais e arquivos recebidos opcionais; o agente revisa e publica a conclusão, sem inferir resolução ou transferir GO. | P: `manter-migracao` | [preparar-planejamento.ps1](../../scripts/preparar-planejamento.ps1) |
| `Planejamento: criar pasta de evidencias` | Evidências / coleta | Criar ou localizar evidencias/LEIA-ME.md do projeto; relacionar arquivos a issues ou ao projeto. | D | [criar-pasta-evidencias.ps1](../../scripts/criar-pasta-evidencias.ps1) |
| `Planejamento: abrir plano e to-do` | Trabalho / retomada | Abrir plano e tarefas correntes do projeto; presença dos arquivos não comprova GO. | D | [abrir-planejamento.ps1](../../scripts/abrir-planejamento.ps1) |
| `Aplicacao: preparar implementacao do lote` | Mudança e qualidade / execução assistida | Preparar prompts de implementação e revisão do resultado; oferecer escolha explícita de branch, sem aplicar corretivas. | P: `implementar-lote` e `revisar-resultado` | [preparar-implementacao.ps1](../../scripts/preparar-implementacao.ps1) |
| `Aplicacao: build Maven (Java 8)` | Mudança e qualidade / build e testes | Executar fases delimitadas como `clean install`, `clean verify`, `test` e `package`; registrar resultado, testes/cobertura disponíveis e falhas. | D | [construir-aplicacao.ps1](../../scripts/construir-aplicacao.ps1), [Maven](tools/maven.md) |
| `Aplicacao: analisar SonarQube` | Mudança e qualidade / análise de qualidade | Executar scanner, rever diagnóstico ou baixar a última análise concluída do projeto/branch, inclusive da pipeline; consultar Gate, métricas/issues e registrar decisões locais. | D | [analisar-sonar.ps1](../../scripts/analisar-sonar.ps1), [Sonar](tools/sonar.md) |
| `Aplicacao: deploy no JBoss` | Plataforma / publicação | Selecionar aplicação/servidor e publicar artefato, substituindo o WAR/EAR implantado; guarda somente o último deploy. Reverter é fazer deploy de um WAR anterior. | D | [gerenciar-jboss.ps1](../../scripts/gerenciar-jboss.ps1), [JBoss](tools/jboss.md) |
| `Servidor: iniciar JBoss` | Plataforma / ciclo do runtime | Escolher inicialização normal ou debug e instalação configurada. | D | [gerenciar-jboss.ps1](../../scripts/gerenciar-jboss.ps1) |
| `Servidor: parar JBoss` | Plataforma / ciclo do runtime | Parar a instalação escolhida com controle do processo. | D | [gerenciar-jboss.ps1](../../scripts/gerenciar-jboss.ps1) |
| `Servidor: consultar estado JBoss` | Plataforma / diagnóstico | Consultar instalação/processo e produzir estado/contexto; não pressupor ausência de escrita. | D | [gerenciar-jboss.ps1](../../scripts/gerenciar-jboss.ps1) |
| `Servidor: criar usuario JBoss` | Plataforma / acesso administrativo | Acionar o procedimento de criação do usuário no servidor selecionado. | D | [gerenciar-jboss.ps1](../../scripts/gerenciar-jboss.ps1) |

Os menus dessas tarefas concentram suas variantes; não há uma tarefa por projeto, arquivo ou função auxiliar. As opções completas permanecem nos guias vinculados. Debug por attach é uma configuração de depuração da IDE, não uma Run Task adicional. As consultas `auditar_base`, `listar_issues` e `obter_issue` têm MCP/CLI próprios e também não são entradas desse inventário.

No workspace, abra `.harness/indices/projetos.md` e siga o link do projeto para `indice.md`. Ele reúne registro, plano, tarefas, fichas, evidências, diagnósticos e logs existentes. Após copiar arquivos ou gerar novas saídas, use **Workspace: atualizar indice dos projetos** para reconstruir os links. Para compartilhar, copie as pastas conforme o [guia](tools/compartilhamento-contextos.md); não há tarefa de importar/exportar ZIP.

## Planejamento por sprints

A [MACRO-01](../contratos/planejamento-sprints.md#regras-do-cronograma) amplia a visão por issue para escopo, calendário e capacidade de trabalho. A tarefa seleciona os projetos; o prompt reúne as datas, o prazo, a equipe e as estimativas ainda ausentes. Depois do preenchimento, **Validar e gerar cronograma**, na mesma tarefa, produz JSON e Markdown com tabelas, matriz e Gantt. O [guia](tools/planejamento-sprints.md) concentra o procedimento completo; o [template](../modelos/planejamento-sprints.template.md) orienta a narrativa.

O cálculo confere prazos e limites, incluindo fases já consumidas. `NAO_CABE` e `EM_RISCO` mostram motivos calculados e esforço não alocado, inclusive na faixa superior; `NAO_AVALIAVEL` explicita dados essenciais ausentes. Retomar e Revisar usam o mesmo cenário corrente e preservam o trabalho humano; Revisar registra o motivo e pede reavaliação. O cronograma não concede GO de lote, aceite da migração ou autorização de implantação. A capacidade foi integrada e testada localmente; homologação corporativa permanece pendente.

## Referências

A [arquitetura do harness](../engineering-harness/01-estrategia-e-arquitetura.md) apresenta os fluxos, os limites de autoridade e a evolução por capacidades. O [guia do desenvolvedor](harness-migracao-desenvolvedor.md) detalha a operação cotidiana. Os links de implementação e guias da matriz apontam para arquivos do repositório.
