---
html:
  embed_local_images: true
  embed_svg: true
  offline: true
---

# Cheat sheet — Run Tasks do harness

**Data:** 09/10/2026. **Escopo:** operações do harness de migração JBoss.
**Baseline operacional:** `main` em `17f80c22084dd26437eda3bd106698dcacc8a33e`, após a integração de sprints pela [PR #26](https://github.com/edoardo-bianco/jboss-mta-harness/pull/26).

## Consulta rápida

A jornada operacional parte da configuração do ambiente, passa pelo diagnóstico e planejamento e chega à implementação, verificação e operação da aplicação. As **27 entradas** de [`.vscode/tasks.json`](../../.vscode/tasks.json) oferecem essas ações. A matriz mantém seus nomes operacionais e propõe a organização por domínio/subdomínio. **D** executa uma operação determinística; **P** prepara material para acionamento explícito posterior do agente. Uma tarefa pode combinar P e D em ações diferentes. O acionamento do agente de codificação permanece uma ação explícita do desenvolvedor.

| Run Task | Domínio / subdomínio | Funcionalidade disponível e efeito principal | Agente | Implementação / guia |
| --- | --- | --- | --- | --- |
| `Workspace: configurar caminhos` | Execução / configuração | Configurar ferramentas e integrações locais, com procedimentos de preparo e certificado quando aplicáveis. | D | [configurar-caminhos.ps1](../../scripts/configurar-caminhos.ps1), [workspace](../guias/tools/workspace.md) |
| `Workspace: gerar workspace` | Execução / ambiente | Gerar workspace local e recursos de integração; preservar personalizações e backups próprios do gerador. | D | [gerar-workspace.ps1](../../scripts/gerar-workspace.ps1) |
| `Workspace: conferir configuracao ao abrir` | Execução / ambiente | Conferir configuração na abertura e encaminhar ajustes; não é uma consulta genericamente sem escrita. | D | [conferir-ambiente.ps1](../../scripts/conferir-ambiente.ps1) |
| `Workspace: atualizar indice dos projetos` | Trabalho / descoberta | Localizar projetos e registros; inicializar registros conforme as entradas disponíveis, sem substituir origem por recência. | D | [atualizar-indice-projetos.ps1](../../scripts/atualizar-indice-projetos.ps1) |
| `Workspace: limpar execucoes` | Evidências / retenção | Selecionar limpeza de execuções e temporários; preservar dossiês oficiais e vínculos protegidos pelo contrato. | D | [limpar-execucoes.ps1](../../scripts/limpar-execucoes.ps1) |
| `MTA: conferir ambiente` | Diagnóstico / preparação | Verificar ferramentas, configuração e projeto selecionado antes da análise. | D | [conferir-ambiente.ps1](../../scripts/conferir-ambiente.ps1), [MTA](../guias/tools/mta.md) |
| `MTA: executar analise` | Diagnóstico / análise | Executar MTA no escopo escolhido; produzir snapshot, diagnóstico, logs e recibos. | D | [executar-mta.ps1](../../scripts/executar-mta.ps1) |
| `MTA: acompanhar log da analise` | Diagnóstico / acompanhamento | Acompanhar log da execução ativa. | D | [acompanhar-log-mta.ps1](../../scripts/acompanhar-log-mta.ps1) |
| `MTA: acompanhar atividade interna` | Diagnóstico / acompanhamento | Exibir acompanhamento detalhado da execução ativa. | D | [acompanhar-log-mta.ps1](../../scripts/acompanhar-log-mta.ps1) |
| `MTA: consultar log de execucao anterior` | Diagnóstico / histórico | Selecionar projeto/execução e consultar seu log. | D | [acompanhar-log-mta.ps1](../../scripts/acompanhar-log-mta.ps1) |
| `MTA: abrir ultimo relatorio` | Diagnóstico / apresentação | Abrir relatório para consulta; essa conveniência não adota a rodada no planejamento. | D | [abrir-relatorio-mta.ps1](../../scripts/abrir-relatorio-mta.ps1) |
| `Planejamento: planejar sprints` | Planejamento de portfólio / escopo, calendário e capacidade | Novo/Retomar/Revisar prepara contexto macro dos projetos; Validar calcula cronograma, prazo, capacidade, fases e cenários, preservando histórico. | P: `planejar-sprints` + D: validação | [preparar-sprints.ps1](../../scripts/preparar-sprints.ps1), [guia](../guias/tools/planejamento-sprints.md), [contrato](../especificacoes/planejamento-sprints.md) |
| `Planejamento: priorizar issues` | Trabalho / triagem | Selecionar categoria, projetos e fatia; recriar/progredir/retomar conforme histórico; preparar contexto para ranking e fichas. | P: `priorizar-issues` | [preparar-priorizacao.ps1](../../scripts/preparar-priorizacao.ps1), [guia](../guias/tools/priorizacao-issues.md) |
| `Planejamento: planejar` | Trabalho / proposta | Criar, retomar ou atualizar preparo a partir do registro, ficha e anexos; agente ou humano elabora um lote. | P: `planejar-lotes` | [preparar-planejamento.ps1](../../scripts/preparar-planejamento.ps1), [guia](../guias/tools/planejamento-migracao.md) |
| `Planejamento: atualizar registro de migracao` | Trabalho / reconciliação | Apresentar origem atual/nova, exigir `ADOTAR` e preparar a reconciliação; adoção não prova resolução das issues. | P: `manter-migracao` | [preparar-planejamento.ps1](../../scripts/preparar-planejamento.ps1) |
| `Planejamento: criar pasta de evidencias` | Evidências / coleta | Criar ou localizar índice de evidências do projeto; vincular ao dossiê da issue quando identificada. | D | [criar-pasta-evidencias.ps1](../../scripts/criar-pasta-evidencias.ps1) |
| `Planejamento: abrir plano e to-do` | Trabalho / retomada | Localizar e abrir os documentos vinculados; presença dos arquivos não comprova GO. | D | [abrir-planejamento.ps1](../../scripts/abrir-planejamento.ps1) |
| `Planejamento: compartilhar contexto` | Evidências / intercâmbio | Exportar análise concluída ou proposta por issue; importar ZIP com associação aos projetos locais e preservação dos originais. | D | [compartilhar-contexto.ps1](../../scripts/compartilhar-contexto.ps1), [guia](../guias/tools/compartilhamento-contextos.md) |
| `Aplicacao: preparar implementacao do lote` | Mudança e qualidade / execução assistida | Preparar prompts de implementação e revisão do resultado; oferecer escolha explícita de branch, sem aplicar corretivas. | P: `implementar-lote` e `revisar-resultado` | [preparar-implementacao.ps1](../../scripts/preparar-implementacao.ps1) |
| `Aplicacao: build Maven (Java 8)` | Mudança e qualidade / build e testes | Executar fases delimitadas como `clean install`, `clean verify`, `test` e `package`; registrar resultado, testes/cobertura disponíveis e falhas. | D | [construir-aplicacao.ps1](../../scripts/construir-aplicacao.ps1), [Maven](../guias/tools/maven.md) |
| `Aplicacao: analisar SonarQube` | Mudança e qualidade / análise de qualidade | Executar análise ANTES/DEPOIS ou rever coleta existente; consultar Gate, métricas/issues e registrar decisões locais sobre critérios. | D | [analisar-sonar.ps1](../../scripts/analisar-sonar.ps1), [Sonar](../guias/tools/sonar.md) |
| `Aplicacao: deploy no JBoss` | Plataforma / publicação | Selecionar aplicação/servidor e publicar artefato, com recibo e histórico de releases. | D | [gerenciar-jboss.ps1](../../scripts/gerenciar-jboss.ps1), [JBoss](../guias/tools/jboss.md) |
| `Aplicacao: rollback no JBoss` | Plataforma / reversão | Retornar ao artefato selecionado no histórico; não restaura automaticamente configuração, banco ou dados. | D | [gerenciar-jboss.ps1](../../scripts/gerenciar-jboss.ps1) |
| `Servidor: iniciar JBoss` | Plataforma / ciclo do runtime | Escolher inicialização normal ou debug e instalação configurada. | D | [gerenciar-jboss.ps1](../../scripts/gerenciar-jboss.ps1) |
| `Servidor: parar JBoss` | Plataforma / ciclo do runtime | Parar a instalação escolhida com controle do processo. | D | [gerenciar-jboss.ps1](../../scripts/gerenciar-jboss.ps1) |
| `Servidor: consultar estado JBoss` | Plataforma / diagnóstico | Consultar instalação/processo e produzir estado/contexto; não pressupor ausência de escrita. | D | [gerenciar-jboss.ps1](../../scripts/gerenciar-jboss.ps1) |
| `Servidor: criar usuario JBoss` | Plataforma / acesso administrativo | Acionar o procedimento de criação do usuário no servidor selecionado. | D | [gerenciar-jboss.ps1](../../scripts/gerenciar-jboss.ps1) |

Os menus dessas tarefas concentram suas variantes; não há uma tarefa por projeto, arquivo ou função auxiliar. As opções completas permanecem nos guias vinculados. Debug por attach é uma configuração de depuração da IDE, não uma Run Task adicional. As consultas `auditar_base`, `listar_issues` e `obter_issue` têm MCP/CLI próprios e também não são entradas desse inventário.

## Planejamento por sprints

A [MACRO-01](../features/planejamento-macro-sprints.md) amplia a visão por issue para escopo, calendário e capacidade de trabalho. A tarefa seleciona os projetos; o prompt reúne as datas, o prazo, a equipe e as estimativas ainda ausentes. Depois do preenchimento, **Validar e gerar cronograma**, na mesma tarefa, produz JSON e Markdown com tabelas, matriz e Gantt. O [guia](../guias/tools/planejamento-sprints.md) concentra o procedimento completo; o [template](../modelos/planejamento-sprints.template.md) orienta a narrativa.

O cálculo confere prazos e limites, incluindo fases já consumidas. `NAO_CABE` e `EM_RISCO` mostram motivos calculados e esforço não alocado, inclusive na faixa superior; `NAO_AVALIAVEL` explicita dados essenciais ausentes. Retomar preserva o contexto; Revisar exige motivo e conserva a revisão anterior. O cronograma não concede GO de lote, aceite da migração ou autorização de implantação. A capacidade foi integrada e testada localmente; homologação corporativa permanece pendente.

## Referências

A [arquitetura do harness](arquitetura-harness.md#5-arquitetura-de-comportamento) apresenta os fluxos, os limites de autoridade e a evolução por capacidades. O [guia do desenvolvedor](../guias/harness-migracao-desenvolvedor.md) detalha a operação cotidiana. Os links de implementação e guias da matriz apontam para arquivos do repositório.
