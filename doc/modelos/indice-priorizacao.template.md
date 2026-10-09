<!-- Template de referencia para a proxima entrega de indice automatico.
     Baseado no formato fornecido pelo desenvolvedor em 09/10/2026.
     Repetir o bloco de categoria quando houver sequencias de categorias distintas.
     Vincular sequencia e fatias pelos recibos; nao escolher pela recencia do arquivo.
     Substituir placeholders e repetir somente linhas correspondentes a recibos reais.
     A integracao ao fluxo de priorizacao ainda esta pendente em tasks/plan.md. -->

# Índice de priorização de issues

Categoria: {{Category}} | Sequência vigente: `{{SequenceId}}` | Base inicial: {{InitialIssueCount}} issues | Percentual por fatia: {{SlicePercent}}%

Atualizado em: {{UpdatedAtUtc}} (UTC). Índice gerado automaticamente a partir dos recibos e resultados de priorização.

## Sequência ativa ({{Category}})

| Ordem | Solicitação | Modo | Data (UTC) | Issues examinadas | Projetos da fatia | Propostas | Priorização | Contexto |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| {{OrderAndCurrentLabel}} | `{{RequestIdShort}}` | {{Mode}} | {{PreparedAtUtc}} | {{AnalyzedIssueCount}} | {{ProjectLabels}} | {{ProposalCount}} | [priorizacao.md]({{RankingRelativePath}}) | [context.json]({{ContextRelativePath}}) |

Cobertura acumulada: {{UniqueAnalyzedIssueCount}} de {{InitialIssueCount}} issues examinadas ({{CoveragePercent}}%). Isso não significa corrigidas, validadas ou aceitas.

## Substituída (não vigente)

| Solicitação | Modo | Data (UTC) | Observação | Priorização |
| --- | --- | --- | --- | --- |
| `{{SupersededRequestIdShort}}` | {{SupersededMode}} | {{SupersededPreparedAtUtc}} | Substituída pelo Recreate `{{ReplacingSequenceIdShort}}` | [priorizacao.md]({{SupersededRankingRelativePath}}) |

## Próximo passo

Escolher as issues no registro de cada projeto (Decisão `ANALISAR AGORA`) e executar **Planejamento: planejar**.

<!-- Regras de preenchimento:
     SequenceId identifica a raiz vigente; a linha marcada atual identifica sua ultima fatia vinculada.
     UniqueAnalyzedIssueCount conta Source/Id distintos efetivamente examinados na cadeia vigente.
     Percentual da fatia nao e ganho de IA e nao representa percentual de issues corrigidas.
     N/A indica denominador desconhecido/zero; nao inventar cobertura ou propostas faltantes.
     Sem sequencia substituida, informar explicitamente que nao ha, sem criar linha ficticia.
     Preserve sequencias substituidas e categorias; gere links relativos ao indice de destino.
     So publicar fatia concluida consistentemente; cancelamento/falha nao implica novo exame. -->
