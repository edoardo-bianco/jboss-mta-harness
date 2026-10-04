---
name: revisar-lote
description: Compatibilidade com contextos antigos; revisao usa o mesmo contrato de planejar-lotes.
argument-hint: Informe o contexto preparado anteriormente e o indice de evidencias.
agent: devsquad
tools: ['agent', 'read/readFile', 'search/listDirectory', 'search/fileSearch', 'search/textSearch', 'edit/createFile', 'edit/editFiles']
---

## Direcionamento do desenvolvedor

Objetivo e observacoes da revisao:

## Trabalho solicitado

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
