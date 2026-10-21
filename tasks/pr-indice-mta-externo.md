# Manter MTA externo e padronizar os documentos de migracao

Base: main. Branch: harness/indice-mta-externo. Descricao preparada para revisao; sem merge.

O indice passa a reconhecer os relatorios sob mta.runsPath pela pasta Source,
preservando origens explicitamente escolhidas. Novas analises exigem raiz externa
e publicam somente o diagnostico validado, sem substituir relatorios anteriores.
O conversor legado e suas suites exclusivas foram retirados; o inicio corrente
parte do indice e do MTA externo configurado.

O indice geral recupera a tabela resumida Markdown com links para projeto/POM,
MTA, ultimas tentativas e documentos existentes. Contagens por categoria e totais
informam cobertura; MTA indisponivel nao aparece como zero nem como sucesso.

Templates versionados passam a ser consumidos pelos geradores de registro,
indices, ranking, evidencias e reconciliacao. Prompts de priorizacao,
planejamento e reconciliacao vinculam os modelos obrigatorios, inclusive ao
recriar prompts de material recebido. Ficha e detalhe da issue usam um modelo
comum por projeto/categoria/issue. O ranking e os indices repetem a mesma
orientacao para o humano marcar ANALISAR AGORA, informar o recorte e seguir
Planejamento: planejar. Decisoes, GO, aceite e texto humano existente permanecem
sob as regras correntes.

## Verificacao

- Checkpoint anterior: 19 suites de MTA/indice/acesso e ClaudeAdapter aprovadas;
  apos a retirada, ProjectIndexExternalMta, Planning, PrioritizationIndex,
  Cleanup e ClaudeAdapter aprovadas.
- Incremento de 21/10: 19 suites distintas aprovadas pelo runner isolado em
  Windows PowerShell 5.1; detalhadas em [tasks/todo.md](todo.md).
- Testes alteram templates somente na copia descartavel e comprovam consumo
  pelo gerador, links dos modelos nos prompts, preservacao de decisoes/fontes,
  contagens, lacunas e progresso acumulado.
- Mutacao que ocultava a ultima tentativa falha detectada; arquivo restaurado
  byte a byte. Sintaxe de 23 scripts e 557 destinos locais e 346 ancoras Markdown conferidos.
- Sem referencia ativa ao utilitario retirado; git diff --check aprovado.

## Uso e limites

Configurar mta.runsPath e executar Workspace: atualizar indice dos projetos.
Abrir .harness/indices/projetos.md em preview Markdown. Novos preparos de
priorizacao/planejamento recebem os links dos templates; revisar as saidas do
agente conforme os modelos. Nao foi executado um agente de migracao real para
homologar sua aderencia ao formato.

O [inventario dos modelos](../doc/modelos/README.md) identifica cada produtor.
Nenhum dado real, relatorio externo ou codigo de aplicacao foi alterado nesta
validacao. Nenhum merge ou conversao foi executado.
