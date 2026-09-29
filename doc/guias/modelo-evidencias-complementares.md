# Evidencias complementares do lote

Este indice acompanha a pasta criada por Planejamento: criar pasta de evidencias.
Tambem pode ser copiado manualmente como LEIA-ME.md. Confira os campos preenchidos
e complete os restantes com os valores do contexto/plano selecionados.
Metadados desconhecidos podem ficar PENDENTES. Nao registre hashes.

- Project: PREENCHER
- Nome do projeto (Label): PREENCHER
- Source (raiz da aplicacao): PREENCHER
- ID do lote existente: PREENCHER
- Data de organizacao desta pasta, com fuso: PREENCHER

## Objetivo da revisao

Descreva o que deve ser revisto no plano/to-do e quais duvidas precisam ser resolvidas.
Referencie observacoes do desenvolvedor nos documentos, se houver.
Observacoes sao pedidos de revisao; nao representam GO, aceite ou testes realizados.

## Como usar esta pasta

1. Preencha o ID do lote existente e o objetivo da revisao. A criacao da pasta
   escolhe somente o projeto; nao seleciona rodada MTA nem planejamento anterior.
2. Copie manualmente para esta pasta os arquivos pertinentes e liste-os na tabela
   abaixo. Nao precisa copiar o relatorio MTA: ele sera lido pelo contexto preparado.
3. Registre e salve seu feedback no plan.md/to-do existente, na secao Observacoes
   do desenvolvedor - revisao pendente. Preserve identidade e historico.
4. Para reavaliar com MTA novo, execute Aplicacao: build Maven (Java 8), escolha
   clean install e, apos sucesso, MTA: executar analise para o mesmo projeto.
   Espere SUCCEEDED. Se mudou somente o feedback documental, pode reutilizar a
   rodada existente; arquivos adicionais por si so nao exigem repetir MTA.
5. Execute Planejamento: preparar contexto para Copilot. Escolha o projeto,
   2. Revisar lote, a rodada pertinente e o planejamento anterior que contem seu
   feedback. A Solicitacao do menu deve corresponder ao RequestId do plano que
   deseja revisar. Informe o caminho deste LEIA-ME e confira Previous no contexto.
6. Em nova conversa Copilot Local com devsquad, execute o revisar-lote.prompt.md
   aberto pela task ou copie a chamada /revisar-lote exibida no terminal, ja com
   os dois caminhos. Para contextos antigos, use o comando abaixo com caminhos
   absolutos reais. Execute somente revisar-lote nesta etapa.
7. Revise os novos PlanPath/TodoPath: mesmo lote, feedback atendido ou justificado,
   evidencias consideradas e tarefas consistentes. Os anteriores ficam preservados.
   A proposta revisada depende do seu GO; aplicar corretivas e uma etapa separada.

```text
/revisar-lote Use o contexto de "CAMINHO_ABSOLUTO/planejar-lotes.prompt.md"
e as evidencias listadas em "CAMINHO_ABSOLUTO/LEIA-ME.md".
Reavalie o mesmo lote com o MTA selecionado, o plano/to-do de Previous, minhas
observacoes e estas evidencias. Preserve ID e historico. Explique as mudancas e
pendencias e atualize ambos os documentos. Nao aplique corretivas nem conceda GO.
```

Se a pasta estiver oculta no VS Code, abra este arquivo pelo caminho completo com
Ctrl+P. Use a pasta indicada no terminal no Explorer do Windows para copiar arquivos.
Executar novamente a tarefa cria outra pasta; para completar esta, reabra este indice.

## Arquivos autorizados para leitura

Liste somente arquivos reais dentro desta pasta, com caminho relativo, sem curingas.
Inclua exportacoes/trechos pertinentes sem credenciais ou logs brutos. Origem pode
ser ferramenta, documento ou observacao manual: diferencie essas situacoes.
Data de coleta e diferente da data de copia para esta pasta. Indique o artefato,
versao/configuracao ou estado analisado quando conhecido; commit e opcional.

| Arquivo relativo | Origem e data de coleta (com fuso) | Ambiente e artefato/versao | O que ajuda a verificar / limitacoes |
| --- | --- | --- | --- |

Nenhum arquivo listado ainda. Adicione linhas reais antes de solicitar sua leitura.

## Observacoes e limites

Registre lacunas, divergencias e resultados declarados sem comprovante.
Os arquivos adicionais nao integram o snapshot MTA e nao possuem hashes ou
verificacao automatica de integridade. Preserve esta pasta depois de usada em uma
revisao; para novos resultados, crie outra pasta datada. A limpeza de execucoes
preserva esta area, mas pode apagar os planejamentos e rodadas que a referenciam.
