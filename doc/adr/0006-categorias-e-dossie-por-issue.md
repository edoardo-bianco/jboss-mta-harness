# ADR-0006: categorias e dossie por issue

Status: aceita para implementacao; ensaio humano na maquina de trabalho pendente.
Data: 2026-10-06.

## Contexto

A priorizacao era limitada a mandatory. O ranking concentrava as fichas e o
planejamento usava nomes genericos por lote. O desenvolvedor precisa continuar
categorias separadamente e entregar a outro colega o contexto de uma issue para
implementacao manual ou assistida, com evidencias ja processadas.

## Decisao

SchemaVersion=4 da priorizacao declara Category e destinos FichaPaths por Source/Id.
Base, cobertura e continuidade pertencem a categoria/escopo; v2/v3 continuam
mandatory. Ranking resume; cada ficha examinada e independente por projeto,
inclusive para a mesma regra. Previous protege ranking e fichas com hashes.

Novos planejamentos de uma issue usam LayoutVersion=2. A pasta do projeto usa
artifactId do POM raiz, conforme escolha humana; Source continua identificando o
codigo local. O nome inicial e preservado mesmo apos mudanca do POM. Conflito de
artifactId entre Sources nao mistura dossies. Fichas, contexto, plano e to-do tem
nomes identificaveis; partes longas sao abreviadas para o Windows PowerShell 5.1.
Layouts/nomes historicos permanecem legiveis.

O indice editavel de anexos pertence a issue. Cada preparo consolida ficha,
entradas humanas e, em MTA, detalhes completos da regra/incidentes e proveniencia
em copias com hashes. EvidenceMode=CONSOLIDATED permite preparar implementacao
sem a pasta MTA original; nao troca PlanningBasis nem elimina a conferencia do
codigo atual. Originais de recibos legados continuam obrigatorios. Exportacao,
importacao e remapeamento entre maquinas ficam para a entrega seguinte.

PlanPath e TodoPath seguem modelos fixos do contrato, com tarefas vinculadas a
passos do plano. Quem recebe apenas analise precisa planejar antes de executar;
quem recebe proposta confere GO/escopo. O orientador continua leitor em ambos os
casos. Criacao de arquivos e verificacoes automaticas nao concedem GO ou aceite.

## Consequencias

Copias por solicitacao ocupam mais disco, mas preservam as entradas de uma revisao
e evitam exigir MTA original na implementacao. A limpeza de execucoes preserva
dossies por issue. Novos anexos exigem novo preparo com Previous, sem apagar o
anterior. Criar/revisar recortes MTA ainda exige a origem registrada; lacunas e
comparacao MTA posterior permanecem explicitas.

O contrato operacional esta em [planejamento-copilot](../especificacoes/planejamento-copilot.md).
O [guia](../guias/tools/planejamento-migracao.md#dossie-por-issue-e-passagem-entre-colegas)
explica a passagem entre colegas. Esta decisao complementa as ADRs 0002, 0004 e 0005.
