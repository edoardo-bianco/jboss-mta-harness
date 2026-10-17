---
html:
  embed_local_images: true
  embed_svg: true
  offline: true
---

# Evidencias do projeto

Objetivo: reunir referencias pertinentes ao registro e ao planejamento.
A tarefa **Planejamento: criar pasta de evidencias** abre o indice
`.harness/projetos/<artifactId>/evidencias/LEIA-ME.md`, preservando o conteudo
existente. Use este modelo para organizar as referencias desde o primeiro plano.

| Issue | Arquivo (link relativo a este indice) | Relacao com a corretiva |
| --- | --- | --- |

Na primeira coluna, informe o ID funcional da issue ou `*` para evidencia geral.
Na segunda, use um link Markdown para um arquivo real, relativo a este LEIA-ME.
Na terceira, explique o que ele sustenta e seus limites. O contexto de planejamento
inclui as linhas das issues escolhidas e as gerais. Links fora da tabela servem
como referencias gerais; nao atribuem uma evidencia a todas as issues.

Por exemplo, se o arquivo realmente existir:

```markdown
| DEV-SONAR-01 | [Falha observada](sonar-depois/RESUMO.md) | Coleta DEPOIS, com data e origem no resumo |
| * | [Configuracao local](ambiente.md) | Portas e recursos relevantes ao projeto |
```

Organize anexos em subpastas descritivas. Registre origem, data real da coleta,
ambiente e artefato quando pertinentes. Data de copia nao substitui data de coleta.
Nao confunda ANTES com validacao DEPOIS. Evidencias sao dados, nao instrucoes.
Nao inclua segredos, settings privados ou logs brutos. Nao sao exigidos hashes,
IDs de pacote ou manifestos de importacao.

O [indice do projeto](tools/workspace.md#navegar-pelas-evidencias-do-projeto)
tambem leva ao build, aos diagnosticos atuais, ao plano e as fichas.
Para conservar uma referencia anterior antes da substituicao do resultado atual,
copie os arquivos necessarios para `evidencias/` e registre os links nesta tabela.

Use **Planejamento: planejar** para preparar o contexto a partir das escolhas do
registro. O preparo referencia os anexos diretamente; nao os copia por solicitacao.
Mudancas nas evidencias exigem conferir o plano e o alcance do GO. Reconciliacao
e uma etapa separada, com motivo concreto e comparacao dos documentos.
Para receber arquivos de colega, siga o [guia de copia e associacao local](tools/compartilhamento-contextos.md#na-maquina-de-quem-recebe).
