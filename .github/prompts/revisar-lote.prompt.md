---
name: revisar-lote
description: Revisa a proposta corrente pelo mesmo contrato de planejar-lotes.
agent: devsquad
tools: ['agent', 'read/readFile', 'search/listDirectory', 'search/fileSearch', 'search/textSearch', 'edit/createFile', 'edit/editFiles', 'harnessissues/auditar_base', 'harnessissues/listar_issues', 'harnessissues/obter_issue']
---

Use a entrada Planejamento: planejar e o ContextPath corrente informado.
Leia o prompt planejar-lotes.prompt.md no mesmo diretorio e siga seu contrato
para revisar o lote existente. Preserve tarefas, texto e declaracoes humanas;
mudanca de escopo/solucao/aceite exige revisao do GO. Nao buscar recibos,
sucessores ou copias consolidadas, nem conceder GO/aceite ou executar corretivas.
