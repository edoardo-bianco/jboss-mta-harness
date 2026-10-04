---
name: implementar-lote
description: Implementa somente o lote com GO humano vigente e registra verificacoes reais.
argument-hint: Use o prompt de implementacao preparado para o plano/to-do aprovados.
agent: devsquad
tools: ['agent', 'read/readFile', 'read/problems', 'search/changes', 'search/listDirectory', 'search/fileSearch', 'search/textSearch', 'search/usages', 'edit/createFile', 'edit/editFiles', 'execute/runInTerminal', 'execute/getTerminalOutput']
---

## Direcionamento do desenvolvedor

Observacoes para a execucao do lote aprovado:

## Trabalho solicitado

Leia o bloco JSON final e ContextPath, PlanPath e TodoPath integralmente.
PlanSnapshot/TodoSnapshot consolidam os documentos no preparo; confira os arquivos
pelos hashes antes de usar essas copias. Leia MigrationPath atual e EvidenceIndexPath
quando informados; ProjectIndexPath e referencia informativa quando existente.
Antes de editar, explicite lote/IDs, tarefas pendentes, arquivos, transformacao,
GO/dispensas, precondicoes, comandos, testes e criterios de aceite do plano.
Direcionamento humano ausente para comportamento/API/ambiente ambiguo exige
pergunta especifica; nao complete o escopo por inferencia.
Leia ContractSnapshot do bloco de implementacao, copia de ContractPath;
em prompts antigos sem essa copia, use
doc/especificacoes/planejamento-copilot.md do harness. Respeite especialmente
Decisoes tecnicas vigentes, Execucao autorizada e GO e Verificacoes e continuidade.
Confira identidades, Purpose, destinos e hashes ContextSha256, PlanSha256,
TodoSha256 e EvidenceHashes por ferramenta real antes da primeira escrita.
Divergencia exige outro preparo; nao infira aprovacao de hashes ou arquivos.

Identifique GO humano vigente, responsavel e alcance das dispensas no plano.
To-do novo referencia essa decisao; documentos antigos podem registra-la em ambos.
Nao exigir GO duplicado nem nova autorizacao quando inequivoca. Dispensa previa
nao elimina entrega, evidencia ou aceite. Esclareca somente conflitos reais.
Preparar este prompt nao concede GO. Sem GO valido, nao altere a aplicacao.

Confira pontos locais contra MTA, evidencias pertinentes e diff; preserve trabalho.
Git e informativo; nao criar/trocar branch nem repetir escolha feita na tarefa.
Delegue via agent a devsquad.implement, [CONDUCTOR] e [LANG: pt-BR], com caminhos,
contrato integral, GO/dispensas, precondicoes vigentes, escopo, evidencias e comandos.
Especialista le documentos; validadores/revisores somente leem, um escritor por arquivo.
Nao chamar finalize/refine/sprint, board, outra fase ou lote. Informe agente/skills usados.

Execute incrementalmente tarefas pendentes e testes pertinentes. Lote Hibernate exige
POMs de compilacao/testes alinhados ao ORM 5.3 do destino, patch comprovado; build 5.1
nao valida 5.3. Lacuna no plano exige decisao de escopo, sem ampliar GO.
Crie/ajuste testes unitarios do comportamento corrigido, incluindo regressao e erros.
Meta minima de referencia: 85% de linhas no recorte corrigido, via relatorio JaCoCo.
Identifique classes/metodos, linhas cobertas/perdidas, percentual e caminho do report;
se o report nao permitir esse recorte, declare a limitacao, sem usar o total como prova.
Abaixo de 85% gera WARNING, sem bloquear build; report ausente fica PENDENTE.
Use -Djacoco.haltOnFailure=false, sem ignorar testes ou falhas de compilacao.
MTA/Sonar/rede/EAP/deploy exigem autorizacao explicita de destino/finalidade.
Nao sobrescrever baseline ANTES nem executar commit, push, merge, PR ou mensagens.

Executor altera somente Source conforme GO. Condutor registra resultados em
PlanPath/TodoPath e, se explicito no recibo, andamento/cobertura/evidencias das issues
do lote em MigrationPath; preserve catalogo e decisoes humanas. Nao editar harness,
recibos, Previous, snapshots, regras, memoria ou documentos paralelos.
Registre comandos reais, resultados e limitacoes, sem marcar pendencias como sucesso.
Releia os documentos, confira diff contra GO, informe links e mantenha ACEITE HUMANO
PENDENTE. Nao integre, publique, escolha proximo lote ou declare conclusao global.
Oriente a revisao do resultado pelo ResultReviewPromptPath preparado, quando presente,
com evidencias reais e roteiro funcional especifico da parte corrigida.
