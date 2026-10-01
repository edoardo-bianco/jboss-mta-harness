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
Use o contexto desse arquivo e o contrato atual de planejar-lotes do harness,
incluindo doc/especificacoes/planejamento-copilot.md. Execute a revisao nesta
mesma solicitacao; nao invoque outro prompt nem reinicie a triagem.
Preserve ID, cobertura, historico e decisoes; altere apenas pontos afetados.
Novos preparos usam planejar-lotes para proposta inicial e atualizacao.
Mantenha proposta, GO, execucao e aceite separados; nao aplique corretivas.
