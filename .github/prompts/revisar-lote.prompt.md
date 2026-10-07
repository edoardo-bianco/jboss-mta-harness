---
name: revisar-lote
description: Compatibilidade com contextos antigos; revisao usa o mesmo contrato de planejar-lotes.
argument-hint: Informe o contexto preparado anteriormente e o indice de evidencias.
agent: devsquad
tools: ['agent', 'read/readFile', 'search/listDirectory', 'search/fileSearch', 'search/textSearch', 'edit/createFile', 'edit/editFiles', "harnessissues/auditar_base", "harnessissues/listar_issues", "harnessissues/obter_issue"]
---

## Direcionamento do desenvolvedor

Objetivo e observacoes da revisao:

## Trabalho solicitado

MCP e opcional. Se indisponivel, execute esta etapa pelo fluxo existente, lendo
diretamente contexto, evidencias e codigo com as ferramentas habituais autorizadas.
Nao exija instalar Node/MCP, executar consultas manuais ou copiar JSON para continuar.

Quando MCP harnessIssues estiver exposto, use auditar_base/obter_issue com o
ContextPath do planejamento vinculado a esta etapa, conforme o
guia `doc/guias/tools/consultas-issues.md`, secao Consultas por etapa, localizado
na raiz do harness e nao na pasta deste prompt preparado.
As respostas recuperam evidencias do diagnostico; nao comprovam codigo corrigido,
GO ou aceite. Confira identidade, paginas/hashes e codigo local. Sem MCP,
continue pelos arquivos e permissoes ja autorizadas; nao amplie poderes de helpers.

Leia ContextPromptPath e EvidenceIndexPath da selecao explicita ao final.
ContextPromptPath aponta o prompt-base preparado: leia suas instrucoes e o
ContextPath indicado nele. Confira identidades/destinos e use ContractSnapshot
desse recibo, sem substituir as copias pelo template ou contrato atuais.
Somente se o recibo historico nao tiver ContractSnapshot, use
doc/especificacoes/planejamento-copilot.md do harness.
Execute a revisao na solicitacao desse contexto, preservando Previous como
entrada historica; nao invoque outro prompt nem reinicie a triagem.
Preserve ID, cobertura, historico e decisoes; altere apenas pontos afetados.
Novos preparos usam planejar-lotes para proposta inicial e atualizacao.
Planejamento: planejar e a entrada unica; nao apresente menu ou tarefa replanejar.
Confira a escolha atual em MigrationPath, a base MTA ou EVIDENCIAS do recibo e as
respostas ja fornecidas. Ausencia de PlanningBasis em recibo legado significa MTA.
PLANEJADA retoma o plano vinculado, sem regredir Andamento. Preserve GO vigente
no mesmo escopo; GO de Previous nao autoriza proposta nova ou ampliacao do recorte.
Nao exija repetir escolhas nem reconciliar marca historica sem conflito concreto.
Se faltar decisao essencial para uma proposta coerente, pergunte e preserve o
rascunho antes de concluir plan.md/todo.md. Retome esta solicitacao com a resposta.
Nao grave documentos ficticios para cumprir uma obrigacao de escrita.
Mantenha proposta, GO, execucao e aceite separados; nao aplique corretivas.
