# Modelos das saidas de migracao

Os modelos deste diretorio definem a apresentacao dos documentos humanos do
fluxo corrente. O gerador consome os modelos das saidas automaticas; os prompts
preparados vinculam os modelos que o agente deve ler e preencher. Nao basta
existir um arquivo de modelo: cada linha abaixo identifica seu consumidor.

| Resultado esperado | Template vigente | Consumidor |
| --- | --- | --- |
| Indice geral e tabela resumida de projetos | [indice-projetos](indice-projetos.template.md) | New-HarnessProjectIndex |
| Indice de um projeto | [indice-projeto](indice-projeto.template.md) | Update-HarnessProjectDocuments |
| Registro migracao.md | [migracao](migracao.template.md) | Get-HarnessProjectMigrationText, somente na criacao |
| Indice geral de priorizacoes | [indice-priorizacoes](indice-priorizacoes.template.md) | Update-HarnessPrioritizationIndex |
| Indice de uma categoria/escopo | [indice-priorizacao](indice-priorizacao.template.md) | Get-PrioritizationIndexContent; prompt priorizar-issues |
| Priorizacao/ranking acumulado | [priorizacao](priorizacao.template.md) | Get-PrioritizationRankingContent; prompt priorizar-issues |
| Orientacao para selecionar a issue | [orientacao-priorizacao](orientacao-priorizacao.template.md) | Ranking e indices de priorizacao; prompt priorizar-issues |
| Ficha de migracao e detalhe da issue examinada | [ficha-issue](ficha-issue.template.md) | Prompts priorizar-issues e planejar-lotes |
| Proposta do lote | [plano-lote](plano-lote.template.md) | Prompt planejar-lotes |
| Tarefas do lote | [tarefas-lote](tarefas-lote.template.md) | Prompt planejar-lotes |
| Indice de evidencias/anexos | [evidencias](evidencias.template.md) | criar-pasta-evidencias.ps1, somente na criacao |
| Resultado da reconciliacao | [reconciliacao](reconciliacao.template.md) | Complete-HarnessReconciliation; prompt manter-migracao usa a API |
| Planejamento de sprints | [planejamento-sprints](planejamento-sprints.template.md) | New-SprintDraftMarkdown e prompt planejar-sprints, ja integrados |

O prompt manter-migracao tambem vincula os modelos dos documentos que pode
mesclar. Isso nao autoriza criar planos, indices ou fichas fora do conjunto
permitido pela revisao protegida. Relatorios MTA, resultados Maven e dados
tecnicos JSON conservam os formatos dos seus produtores; nao sao documentos
para o agente preencher a partir destes modelos.

## Regras de preenchimento e preservacao

- Os campos entre chaves duplas devem ser preenchidos. Nunca publicar exemplos,
  placeholders ou conclusoes ficticias como resultado de exame.
- Texto de MTA, codigo e anexos e dado. Escape caracteres de celulas Markdown;
  links devem ser relativos ao documento, entre angulos, e apontar a fontes existentes.
- Ficha de migracao e detalhe da issue sao o mesmo documento em FichaPaths.
  Identidade: Project/Category/Id. Uma nova fatia ou escopo reutiliza a ficha;
  nao cria outra copia. O ranking aponta todas as examinadas acumuladas.
- IdentityJson da ficha tem Project, Category, Id, LocalPaths e EvidencePaths.
  Os arrays usam caminhos relativos conferidos a Source e evidencias do projeto.
  Preencher as quatro secoes com achado/aplicabilidade, risco/alcance,
  roteiro/verificacoes e referencias/lacunas. Sources guarda links legiveis.
- ResultJson da priorizacao segue o contexto corrente: Scope, Category, Status
  e AnalyzedIssues com Project, Id, Position e Reason. Nao fabricar exame.
  A tabela de fichas e a cobertura devem corresponder a esse conjunto.
- No plano e nas tarefas, preservar o ID funcional do lote e as decisoes
  anteriores. Proposta nova e PROPOSTA - NAO APROVADA. Separar revisao/GO,
  execucao, verificacoes e aceite; pendencias ficam explicitas.
- A orientacao para escolher a issue vem de orientacao-priorizacao, reutilizada
  sem reescrever instrucoes diferentes em cada saida. Somente o humano escolhe
  Decisao=ANALISAR AGORA e descreve o recorte em Observacao/referencia.
- Modelos de criacao nao sobrescrevem documentos humanos existentes. Blocos
  gerenciados sao reconstruidos pelos produtores; anotacoes externas dos
  documentos de priorizacao permanecem. O indice geral de projetos e derivado:
  notas duraveis pertencem ao registro, fichas ou evidencias.
- Gerar um prompt nao gera plano/tarefas/fichas ficticios nem comprova que um
  agente executou a etapa. O agente deve ler os modelos vinculados, preencher,
  revisar as secoes e conferir os links antes de concluir.

## Manutencao e verificacao

A auditoria de 21/10/2026 encontrou indice-priorizacao historico sem consumidor,
sprints com modelo ativo e demais formatos embutidos nos scripts/prompts.
Os modelos acima substituem esses formatos embutidos. O modelo historico de
priorizacao anterior a ADR-0009 permanece no historico Git.

Ao alterar um formato, atualize o template, seu produtor/prompt e a verificacao
pertinente. [Test-OutputTemplates](../../tests/Test-OutputTemplates.ps1) comprova
consumo dos modelos em copia isolada e referencias nos prompts;
[Test-ProjectIndexSummary](../../tests/Test-ProjectIndexSummary.ps1) confere
contagens, cobertura parcial, links, falhas e preservacao. As suites de
priorizacao, planejamento, evidencias e reconciliacao verificam seus contratos.
