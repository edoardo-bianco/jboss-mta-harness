# Manter MTA externo e padronizar os documentos de migracao

Base: main. Branch: harness/indice-mta-externo. Descricao preparada para revisao.

O indice reconhece os relatorios sob mta.runsPath pela pasta Source, preservando
origens explicitamente escolhidas. Novas analises exigem raiz externa e publicam
diagnosticos validados em pastas datadas, conservando os anteriores. Quando a
descoberta externa ainda nao tem resultado utilizavel e nenhuma origem foi
escolhida, o indice mantem o diagnostico interno historico e mostra a lacuna.

A publicacao retira a rodada nova se a associacao falhar, preservando edicoes
concorrentes. Se o filesystem impedir tambem a retirada, informa ambos os erros
e preserva rodada/preparo para conferencia manual antes de atualizar o indice.

O conversor legado e suas suites exclusivas foram retirados. O inicio corrente
parte do indice e do MTA externo configurado. A tabela resumida Markdown oferece
links para projeto/POM, MTA, tentativas e documentos. Contagens por categoria e
totais informam cobertura; ausencia nao aparece como zero nem como sucesso.

Templates versionados sao consumidos pelos geradores de registro, indices,
ranking, evidencias e reconciliacao. Prompts vinculam os modelos obrigatorios,
inclusive na reconciliacao de material recebido. Ficha e detalhe da issue usam
o mesmo modelo por projeto/categoria/issue. Ranking e indices oferecem a mesma
orientacao para marcar ANALISAR AGORA, informar recorte e seguir Planejamento:
planejar. Decisoes, andamento, GO, aceite e texto humano sao preservados.

README, contratos, guias, desenho e orientadores foram revisados independentemente.
O exemplo MTA inclui runsPath, o principio de armazenamento explica a excecao
das pastas externas datadas e referencias antigas indisponiveis ficam como lacunas.
A verificacao dos perfis leitores e de delegacao agora cobre os tres clientes.

## Verificacao

- Testes de regressao reproduziram as duas falhas antes das correcoes.
- Treze suites das corretivas passaram pelo runner isolado em PowerShell 5.1:
  MtaExternalPublication, ProjectIndexExternalMta, Mta, ProjectIndex,
  ProjectIndexSummary, ProjectMta, ProjectDocuments, ProjectNavigation,
  ProjectPublication, ProjectRecovery, ProjectConcurrency, ExternalMtaDiscovery
  e ClaudeAdapter.
- Suites anteriores de templates, priorizacao, planejamento, evidencias e
  reconciliacao tambem aprovadas; detalhes em [tasks/todo.md](todo.md).
- Mutacao isolada detectada; parser dos cinco PowerShell alterados, JSON de
  exemplo, 608 referencias locais e 415 ancoras conferidos; diff --check aprovado.
- [Auditoria e corretivas](auditoria-indice-mta-externo.md) registram reproducoes,
  revisao independente e limites.

## Uso e limites

Configurar mta.runsPath e executar Workspace: atualizar indice dos projetos.
Abrir .harness/indices/projetos.md em preview Markdown. Os preparos de
priorizacao/planejamento vinculam os templates do [inventario](../doc/modelos/README.md).

As verificacoes usam fixtures descartaveis. Nao homologam aderencia de agentes
reais aos templates nem descoberta/delegacao nas extensoes nativas. Falha dupla
de associacao/retirada exige conferencia manual; a mensagem indica o material.

Nenhum dado real, relatorio externo de aplicacao ou codigo de aplicacao foi
alterado. Nenhum merge ou conversao foi executado.
