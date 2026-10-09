# Índice de priorização de issues

Recibos preparados até: {{PreparedThroughUtc}} (UTC). Conferência: {{Verification}}.
Este bloco é derivado dos recibos e resultados; conteúdo manual externo permanece como histórico.
O índice localiza os arquivos. A continuidade é determinada por Previous/SequenceId, nunca pela data.

{{Sequences}}

## Substituída (não vigente)

Somente vínculos explícitos de Recreate substituem sequências; uma categoria ou um escopo diferente não substitui os demais.

| Solicitação | Modo | Data (UTC) | Observação | Priorização |
| --- | --- | --- | --- | --- |
{{SupersededRows}}

{{SupersededNote}}

## Próximo passo

Concluir as fatias pendentes pelo prompt já preparado. Após a análise, escolher as issues no registro de cada projeto (Decisão `ANALISAR AGORA`) e executar **Planejamento: planejar**.
O percentual da fatia não é ganho de IA nem percentual de correções. Exame não concede GO ou aceite.

<!-- modelo:sequencia:inicio -->
## Sequência {{SequenceState}} ({{Category}})

Categoria: {{Category}} | Sequência: `{{SequenceId}}` | Base inicial: {{InitialIssueCount}} issues | Percentual da última fatia: {{SlicePercent}}%

Escopo: {{ScopeLabels}}.

| Ordem | Solicitação | Modo | Data (UTC) | Issues examinadas | Projetos da fatia | Propostas | Priorização | Contexto |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
{{CompletedRows}}

Cobertura acumulada conferida: {{UniqueAnalyzedIssueCount}} de {{InitialIssueCount}} issues examinadas ({{CoveragePercent}}%). Isso não significa corrigidas, validadas ou aceitas.

### Pendências e diagnósticos

{{PendingRows}}
<!-- modelo:sequencia:fim -->
