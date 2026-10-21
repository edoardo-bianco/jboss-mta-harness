# To-do do agente: evolucao do harness

## Execucao da priorizacao sem retorno ao preparo - 21/10/2026

- [x] Conferir relato, fontes e papel indevidamente assumido pelo executor.
- [x] Isolar evolucao em branch derivada de main, preservando checkout operacional.
- [x] Delimitar skill de orientacao e preservar helpers leitores nos tres clientes.
- [x] Explicitar devsquad orquestrador, delegacao e consolidacao da fatia.
- [x] Alinhar execucao por cliente, using-agent-skills e fallback Agent.
- [x] Validar geracao/links/adaptadores, revisar diff e registrar limites.
- [ ] Ensaio nativo na maquina de trabalho: selecao, delegacao e 9/44 examinadas.

Verificacao: cinco suites pelo runner isolado em Windows PowerShell 5.1 passaram:
ClaudeAdapter, Prioritization, CurrentPromptLinks, OutputTemplates e
PrioritizationProgress. Conferidos 113 links locais nos Markdown alterados, sem
destinos ausentes; `git diff --check` passou. Revisao independente nao encontrou
bloqueadores. Nenhum dado real, perfil externo ou checkout operacional alterado.

Limites: essas suites verificam contratos/geracao e preservacao, nao comportamento
do modelo ou seletor Copilot. `agent: devsquad` ja existia antes deste ajuste.
O cliente precisa reconhecer o perfil e executar o prompt nativamente em Local;
o relato "Copilot e com Agent" nao identifica definitivamente o tipo de sessao.
Sem devsquad, fallback documentado para Agent e manual: nao ha lista condicional
no campo agent. Nos demais clientes, skill ausente nao impede o agente principal.
O validador `quick_validate.py` da skill-creator foi tentado, mas nao executou por
ausencia de PyYAML; frontmatter/ponteiro/perfis foram conferidos por ClaudeAdapter
e revisao. Nao instalar dependencias globais apenas para essa validacao.

Para adotar o texto na maquina de trabalho apos integrar/atualizar o harness,
retomar o preparo pendente (`-Mode Continue`, sem percentual) regrava o prompt
e conserva base/quota. Nao recriar nem progredir para outra fatia por causa do loop.
Commit, push e abertura de PR para main autorizados pelo desenvolvedor em
21/10/2026. Ensaio nativo permanece pendente; integracao segue pela revisao da PR.

## Nome curto para priorizacao - 21/10/2026

- [x] Reproduzir o limite do escopo automatico com 14 projetos sinteticos.
- [x] Usar priorizacao como padrao, mantendo participantes no contexto.
- [x] Preservar continuidade antiga, Scope explicito, categorias e contribuicoes humanas.
- [x] Provar recusa de ambiguidade e de troca silenciosa dos participantes.
- [x] Atualizar ADR/guia e concluir regressao isolada e revisao.

Validacao: Test-PrioritizationDefaultScope reproduziu antes da correcao o mesmo
erro de chave funcional acima de 160 caracteres. Depois, passaram pelo runner
isolado as 8 suites: PrioritizationDefaultScope, Prioritization,
PrioritizationCategories, PrioritizationProgress, PrioritizationIndex,
PrioritizationIncidents, ReconciliationPrioritization e OutputTemplates.
Teste novo escrito por agente independente; revisao separada nao encontrou
bloqueadores. Mutacao que permitia escolher silenciosamente entre dois escopos
foi detectada pelo teste de ambiguidade; fonte restaurada byte a byte.
Nenhum dado real alterado. Desenvolvedor autorizou commit, push e abertura da PR
para main em 21/10/2026; alinhamento da maquina de trabalho segue apos o merge.

Conferencia complementar solicitada: indice geral, indice de categoria/escopo,
templates e consumidores das etapas seguintes compativeis. Passaram mais 5
suites isoladas: IssuePlanning, CurrentPromptLinks, ProjectNavigation,
IssueQueries e SprintSources (13 suites no total). Planejamento reutiliza a
ficha por projeto/categoria/issue; consultas/reconciliacao leem Scope do contexto.
Auditoria independente de orientacoes confirmou skill, helpers Codex/Copilot,
guias e prompts sem dependencia do antigo nome concatenado. Templates continuam
obrigatorios e fornecem os indices, ranking, fichas e orientacao para o registro.
Nenhum ajuste adicional de runtime ou instrucao foi necessario nesta conferencia.

## Totais do indice por categoria - 21/10/2026

- [x] Reproduzir ausencia de totais por categoria no resumo.
- [x] Atualizar template, gerador e guias com totais de issues/ocorrencias por categoria.
- [x] Conferir soma entre projetos, cobertura parcial, categorias livres e casos sem dados.
- [x] Executar regressao isolada e revisar diff, preservacao e limites.
- [x] Restaurar orientacao padrao do registro e preenchimento da ficha sem duplicar MTA.
- [x] Excluir paginas da aplicacao em input/ da descoberta de relatorios da rodada.
- [x] Tolerar bloqueio transitorio de diretorios na limpeza, preservando erros persistentes.
- [x] Conferir diferenca com o indice legado: 42 + 2 mandatory do siric = 44; total 92 + 5 = 97 issues, 2981 + 532 = 3513 ocorrencias.
- [x] Manter MTA valido nos totais quando atualizacao local falhar, com aviso separado e recuperacao protegida.

Validacao: 22 suites passaram por Invoke-HarnessTests.ps1 em copias temporarias
isoladas (TEMP/TMP=C:\Temp), incluindo bloqueios reais Win32 transitorios e
persistentes. Cobertura: ProjectMta, ProjectIndex, ProjectNavigation,
ProjectIndexSummary, ProjectIndexExternalMta, ProjectIndexAvailability,
ProjectDocuments, OutputTemplates, ProjectRecovery, ProjectPublicationLocks,
ProjectPublication, ProjectConcurrency, ProjectReadOnly, ProjectStorage,
ProjectTemporaryRemoval, ReconciliationSources, ReconciliationConflicts,
Reconciliation, Planning, PlanningReassociation, PrioritizationIndex e
PrioritizationProgress (prefixo Test-, extensao .ps1).

Duas mutacoes detectadas: excluir MTA apos falha local derruba a verificacao
de 5 issues/532 ocorrencias; comparar orientacao gerada como conteudo humano
derruba equivalencia da reconciliacao. Codigo restaurado byte a byte depois
dos experimentos. Conferidas 111 referencias locais nos documentos alterados;
git diff --check sem erros. Revisao independente estatica encerrada sem
Critical/Required pendentes, incluindo journal real e troca concorrente da
associacao protegida ate a publicacao dos documentos.

Limites: os relatorios reais e o processo que bloqueou a pasta na maquina de
trabalho nao estao acessiveis nesta sessao. Os totais 97/3513 e mandatory 44/351
foram conferidos nos dois indices enviados pelo desenvolvedor. Nenhum MTA,
registro ou codigo de aplicacao real foi alterado. Corretiva na branch
harness/indice-totais-categorias. O desenvolvedor autorizou commit, push e PR
para main apos a validacao; merge permanece uma etapa posterior.

## Auditoria independente do checkpoint - 21/10/2026

- [x] Revisar documentacao, orientadores e runtime com tres revisores independentes.
- [x] Executar 12 suites pelo runner isolado e uma mutacao detectada.
- [x] Conferir 610 referencias e 415 ancoras locais; registrar destinos antigos ausentes.
- [x] Consolidar [parecer e reproducoes](auditoria-indice-mta-externo.md).
- [x] A1/P2: corrigir publicacao parcial de MTA se a associacao falhar.
- [x] A2/P2: preservar diagnostico interno utilizavel no indice com raiz externa vazia.
- [x] A3/P3: explicitar excecao MTA no principio de armazenamento do system design.

Auditoria concluida no checkpoint 87a8725. Doze suites passaram, mas os
dois cenarios P2 nao estavam cobertos e foram reproduzidos separadamente.
Orientadores alinhados no recorte estatico; consumo real dos modelos por agente
e descoberta/delegacao nativa permanecem limites. Apenas registros em tasks
alterados na auditoria inicial. Corretivas concluidas na etapa registrada abaixo; PR nao aberta.

## Tabela resumida e template do indice - 21/10/2026

- [x] Reproduzir ausencia do resumo e implementar tabela Markdown com links.
- [x] Consumir templates versionados; inventariar produtores e vincular modelos aos prompts.
- [x] Validar contagens, lacunas, links e preservacao em copia isolada.
- [x] Concluir revisao da retirada e preparar descricao da PR para main, sem merge.



**Verificacao em 21/10/2026:** 19 suites distintas aprovadas via runner isolado,
Windows PowerShell 5.1 e TMP/TEMP em C:\Temp somente no processo:
ProjectIndexSummary, ProjectIndexExternalMta, ProjectIndex, OutputTemplates,
ProjectDocuments, PrioritizationIndex, CurrentPromptLinks, Planning,
EvidenceFolder, Reconciliation, ReconciliationSources, ReconciliationPrioritization,
ReconciliationConflicts, PlanningPortable, PlanningReassociation, PlanningEvidence,
ProjectNavigation, PrioritizationProgress e PrioritizationCategories.

O teste do resumo primeiro comprovou a ausencia da tabela. O teste dos modelos
primeiro comprovou a ausencia de template corrente; depois passou comprovando
consumo real por alteracao do modelo apenas na copia de teste. Durante a ampliacao,
um erro de sintaxe na propria suite OutputTemplates foi corrigido e sua execucao
isolada passou; as outras 12 suites daquela rodada passaram. A mutacao que ocultava
a ultima tentativa falha foi detectada, com restauracao byte a byte.
Conferidos 23 scripts por parser e 557 destinos locais e 346 ancoras Markdown; diff --check passou.
Busca de dependencias ativas do conversor retirado nao encontrou consumidores.
Nao houve execucao de agente de migracao real, MTA real, conversao ou alteracao
dos dados operacionais. Inventario em [doc/modelos](../doc/modelos/README.md).

**Entrega:** [descricao da PR](pr-indice-mta-externo.md) preparada para main;
revisao humana, abertura da PR e integracao permanecem etapas separadas.

**Roteiro na maquina de trabalho:** atualizar esta branch, conferir mta.runsPath
externo e executar Workspace: atualizar indice dos projetos. Abrir a tabela em
.harness/indices/projetos.md; para os modelos dos agentes, preparar novamente a
etapa desejada e abrir os links em Modelos de saida obrigatorios. No resultado de
priorizacao, seguir Proximo passo para escolher ID/recorte em migracao.md. Nao
limpar nem converter o estado real para ensaiar esta entrega.


## Retirada da conversao legada - 20/10/2026

- [x] Retirar utilitario tools/transicao, fixture e suites exclusivas.
- [x] Alinhar guias, contratos, skill e papeis de orientacao ao inicio corrente.
- [x] Verificar dependencias e validar fluxo corrente sem o conversor.
- [x] Retirada em commit separado 4f67c95; revisao final retomada em 21/10.
- [ ] Revisao humana e integracao.

**Checkpoint de 20/10/2026, pausa pedida pelo desenvolvedor:** trabalho na branch
`harness/indice-mta-externo`, worktree `C:\Temp\harness-indice-mta`.
MTA externo e associacao automatica registrados em `b20af92`; retirada do
conversor registrada no commit seguinte. Main nao foi alterada nem houve merge.
Depois da retirada, passaram em copia isolada: Test-ProjectIndexExternalMta,
Test-Planning, Test-PrioritizationIndex, Test-Cleanup e Test-ClaudeAdapter.
Busca por dependencias do utilitario fora do historico nao encontrou consumidores;
git diff --check passou. Nenhum dado real ou relatorio externo foi alterado.

**Retomar em 21/10:** conferir branch/HEAD/estado neste worktree; concluir revisao
da retirada e dos textos, incluindo links e coerencia do desenho; avaliar apenas
verificacoes adicionais justificadas; preparar PR para main e entregar o roteiro
de uso na maquina de trabalho. Nao executar conversao nem restaurar automaticamente
o ZIP antigo. O checkout original `C:\desenvolvimento\repositorio\jboss-mta-harness`
permanece na branch `harness/conversao-log-etapas` com alteracoes locais de logging
anteriores, preservadas e fora desta entrega; nao trocar/resetar esse checkout.

As entregas de conversao abaixo sao historicas; o utilitario deixa de integrar
o produto por escolha do desenvolvedor. Nenhum dado real foi apagado por esta
mudanca. Relatorios MTA externos nao recuperam decisoes/fichas humanas antigas.

## Indice com MTA externo configurado - 20/10/2026

- [x] Reproduzir raiz externa ignorada com projetos de nomes distintos do artifactId.
- [x] Associar pasta Source, selecionar ultimo diagnostico e preservar escolhas.
- [x] Exigir saida externa nas novas analises e preservar ultimo diagnostico em falha.
- [x] Cobrir falhas, ambiguidade, leitura externa e concorrencia; alinhar guias/skill/papeis.
- [x] Executar suites isoladas e revisao independente; preparar entrega.
- [ ] Revisao humana e integracao.

**Verificacao:** 19 suites passaram em copia isolada com Windows PowerShell 5.1:
Mta, ProjectIndexExternalMta, ProjectIndex, ProjectMta, ProjectDocuments,
ProjectNavigation, ProjectPublication, ProjectRecovery, ProjectConcurrency,
ProjectReadOnly, ProjectStorage, ProjectTemporaryRemoval, MtaActive, MtaLog,
ExternalMtaDiscovery, SonarConfig, Workspace, McpRoots e PrioritizationIndex.
Testes novos primeiro reproduziram raiz ignorada, saida interna e perda da
associacao anterior em falha; depois passaram. Revisao independente apontou a
associacao antecipada e limpeza incompleta; ambos corrigidos e aprovados na
revisao final. Teste adicional de nome Source reservado reproduziu acesso a area
transitoria e passou apos recusa explicita. Nenhum MTA real executado.
Test-ClaudeAdapter tambem passou apos alinhamento da skill e dos papeis comuns
dos agentes Codex/Copilot/Claude Code.

## Conversao de preparo sem proposta - 20/10/2026

[Escopo](plan.md#conversao-de-preparo-sem-proposta---20102026).

- [x] Reproduzir preparo sem proposta em fixture isolada.
- [x] Preservar contexto/prompt/fichas sem criar plano/tarefas; expor disponibilidade.
- [x] Alinhar indice e validacao; recusar pares incompletos e preservar lacunas.
- [x] Executar regressao, mutacao e revisao; documentar resultados.
- [x] Preparar script de acompanhamento individual para entrega no chat e no guia.
- [ ] Revisao humana e integracao na principal.

**Verificacao em 20/10/2026:** 30 suites `Test-Conversion*.ps1` passaram em
Windows PowerShell 5.1 via `Invoke-HarnessTests.ps1`, com TMP/TEMP em `C:\Temp`
somente no processo e copia descartada pelo runner. O novo teste primeiro
reproduziu a exigencia indevida de plano ausente e depois a incorporacao indevida
de proposta local anterior a conversao. Ambos foram corrigidos.
Cobertos preparo EVIDENCIAS/MTA, preservacao de fichas/anexos/decisoes/originais,
pares incompletos, diretorios indevidos, links ausentes e repeticao equivalente.
Mutacao da condicao do par foi detectada; arquivo restaurado byte a byte antes
da regressao completa. Revisao independente sem achados restantes.

O script sequencial no guia teve sintaxe conferida e ensaio com dubles em memoria:
conversao e validacao com estados separados, falha ao aplicar, validacao mesmo
com previa indisponivel, pausas e inventario completo de falhas de POM antes
de qualquer aplicacao. Nenhum projeto real foi convertido ou limpo.

## Conversao de associacao legada sem plano - 20/10/2026

[Escopo](plan.md#conversao-de-associacao-legada-sem-plano---20102026).

- [x] Reproduzir o caso informado em fixture isolada antes da corretiva.
- [x] Validar associacao legada e distinguir ausencia de plano de vinculo quebrado.
- [x] Conferir preservacao, repeticao e descarte explicito, incluindo outro projeto com plano.
- [x] Reproduzir e corrigir classificacao duplicada das copias MTA declaradas nos anexos.
- [x] Bloquear publicacao com origem corrompida; nao declarar ausencia de plano por falha de leitura.
- [x] Executar suites de conversao, revisar diff e documentar o resultado.
- [x] Revisao humana e integracao na principal (PR #38, merge `dd38d6e`, confirmado pelo desenvolvedor).

**Verificacao em 20/10/2026:** 29 suites `Test-Conversion*.ps1` aprovadas em
Windows PowerShell 5.1 pelo runner isolado. Na rodada final, 26 passaram e tres
atingiram o limite de caminho na raiz temporaria padrao; essas tres
(`EvidenceScopes`, `MultiProject`, `SharedEvidence`) passaram ao repetir com
TMP e TEMP apontando para `C:\Temp` apenas no processo. Uma primeira rodada
tambem detectou a mudanca da mensagem de ambiguidade; a mensagem compativel
foi preservada e `ParticipantMta` passou na rodada final.

As novas fixtures falharam antes das respectivas correcoes. Mutacao que
desabilitou a validacao de Source foi detectada pelo teste e revertida.
Revisao independente da associacao, falhas de leitura, publicacao/descarte
e copias MTA terminou sem achados pendentes; `git diff --check` passou.
Nenhum dado real de aplicacao foi convertido ou removido. Na maquina de
trabalho, a origem declarada no contexto SIMTR-api e as escolhas de
planejamento/diagnosticos/priorizacao/sprints ainda precisam ser conferidas.

## Consistencia documental e agentes principais - 19/10/2026

[Escopo e decisao](plan.md#consistencia-documental-e-agentes-principais---19102026).

- [x] Corrigir os seis achados e os ajustes editoriais nos tres documentos.
- [x] Alinhar Codex e GitHub Copilot como principais; Claude Code secundario.
- [x] Conferir links/ancoras, sintaxe/preservacao dos exemplos JSON, diagrama e diff.
- [ ] Revisao humana e integracao na principal.

**Verificacao em 19/10/2026:** 106 referencias locais nos tres documentos e 27
referencias recebidas de outros Markdown versionados, sem arquivos/ancoras
ausentes. Links dos dois arquivos tasks tambem conferidos. Cinco blocos JSON
validos e identicos a baseline `6566bb8`; cercas balanceadas e fluxo Mermaid
revisado por leitura. Catalogo: 47 URLs externas distintas, sendo sete do
repositorio e 40 fontes oficiais/primarias. `git diff --check`: PASS.

**Limites:** testes de runtime nao executados nesta alteracao documental.
Validacao JSON Schema original mantida como historica; nao repetida porque
`jsonschema` nao esta instalado. Ajuda local `codex exec --help` bloqueada pela
politica de scripts; interface conferida na fonte oficial O13, sem alterar a
politica da maquina ou declarar o piloto homologado.

## Adaptador Claude Code - 17/10/2026

[Escopo](plan.md#adaptador-claude-code---17102026).

- [x] Seis helpers em `.claude/agents/` com perfil leitor e delegacao restrita ao condutor.
- [x] Ponteiro `.claude/skills/orientar-migracao/SKILL.md` (descoberta confirmada nesta sessao do Claude Code).
- [x] Skill comum e papeis com encaminhamento Claude Code.
- [x] Configurador MCP grava `.mcp.json`; `.gitignore` e copias de teste atualizados.
- [x] Guias, README e documento 1 atualizados.
- [x] `Test-ClaudeAdapter`, `Test-CurrentPromptLinks`, `Test-Implementation`, `Test-TestIsolation`: PASS. Node: 10/10 em checkout separado.
- [ ] `integration.test.mjs` nao executado: caminho do checkout temporario excedeu o limite do harness; repetir em raiz curta.
- [ ] Ensaio nativo: `claude --agent migracao_helper`, delegacao a um helper, `/orientar-migracao` e consultas MCP aprovadas em `/mcp`.
- [ ] Revisao humana e aceite.

## Estado JBoss corrente - 17/10/2026

[Escopo e decisoes](plan.md#estado-jboss-corrente---17102026).

- [x] Servidor em `.harness/servidores/<eap>/` com somente a ultima operacao e o ultimo start.
- [x] Deploy substitui o WAR (gerenciado, externo ou nao gerenciado) e guarda somente `atual/jboss/<eap>/ultimo-deploy.json`.
- [x] Retirar rollback: Run Task, acao, `-ReleaseId`, funcoes e testes.
- [x] Indice do projeto e `operacao.json` mostram o ultimo deploy.
- [x] Guias, cheat sheet, AGENTS.md e documentos do Engineering Harness atualizados.
- [x] Suites JBoss, Run Tasks, navegacao, armazenamento e build: PASS (runner isolado; ensaio real opt-in nao executado).
- [ ] Ensaio real na maquina de trabalho: start, deploy v1/v2/v1 com HTTP e stop (`Test-JbossReal.ps1 -RunReal`).
- [x] Pasta legada `.harness/jboss/` removida nesta maquina a pedido do desenvolvedor (recibos, logs e 4 copias de WAR; 298 KB).
- [ ] Revisao humana e aceite.

## Consolidacao documental do Engineering Harness - 17/10/2026

[Escopo e decisoes](plan.md#consolidacao-documental-do-engineering-harness---17102026).

- [x] Criar `doc/contratos/` (fluxo-migracao, planejamento-sprints com regras de cronograma, consultas-issues).
- [x] Criar `doc/engineering-harness/` com os tres documentos e imagens (imagem com nome em hash renomeada).
- [x] Corrigir a situacao real da `main` (`5c8d582`) e incorporar decisoes de 17/10/2026.
- [x] Incorporar o material reaproveitado (fundamentos, horizontes, catalogo no anexo A, estudo Java).
- [x] Mover cheat sheet para `doc/guias/` e conversor para `tools/transicao/README.md`.
- [x] Remover `doc/arquitetura/`, `doc/especificacoes/`, `doc/features/` e `doc/estrategia/`.
- [x] Reapontar consumidores: AGENTS.md, instrucoes, skill, prompts, scripts, testes, guias, ADRs e README.
- [x] Verificar links: 60 arquivos, somente os dois links-modelo do template de sprints (destino gerado).
- [x] Suites afetadas pelo runner isolado: 11 PASS; `Test-IssueQueries.ps1` FAIL, falha preexistente na `main` `5c8d582` (conferida em worktree separado).
- [ ] Revisao humana e aceite da consolidacao.
- [ ] Corretiva separada: `Test-IssueQueries.ps1` falha em "Truncamento silencioso ou ausente." (mensagem de incidente esperada com 128 caracteres e um campo truncado).
- [x] Incremento seguinte: armazenamento JBoss por projeto/servidor (ver secao "Estado JBoss corrente").


## Corretivas verificadas da auditoria - 21/10/2026

- [x] Reproduzir A1/A2 antes das correcoes e verificar GREEN.
- [x] Preservar preparo quando falhar tambem a retirada; provar falha antes e sucesso depois.
- [x] Ampliar verificacoes estruturais dos adaptadores Codex/Copilot.
- [x] Corrigir principio documental, exemplo runsPath e referencias locais indisponiveis.
- [x] Aprovar 13 suites isoladas, mutacao detectada, navegacao e revisao independente.

Resultado e limites em [corretivas do parecer](auditoria-indice-mta-externo.md#corretivas-verificadas---21102026).
Os ensaios nativos dos agentes permanecem fora desta verificacao; nenhuma
migracao real, abertura de PR ou integracao foi executada.
