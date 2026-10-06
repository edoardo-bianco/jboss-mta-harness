# Contrato de consultas de issues (SchemaVersion 1)

Evolucao do harness: tres consultas de leitura para recuperar evidencias sem
improvisar parsers. Reutilizam os leitores existentes; nao sao preparadores nem
executores. Fichas, planos, decisoes, cobertura e GO permanecem sob o fluxo atual.

## Entrada e identidade

`Invoke-HarnessIssueQuery` e `scripts/consultar-issues.ps1` recebem `Action`
(`auditar_base`, `listar_issues`, `obter_issue`) e `ContextPath`. `Root` e a raiz
do harness (padrao: pai de scripts), para resolver seus registros. Nao leem
configuracao de toolchains, nao escolhem contexto por recencia e nao gravam cache.
ContextPath deve identificar o proprio recibo. Source deve pertencer ao contexto;
se ha mais de um projeto, ausencia de Source retorna INPUT_REQUIRED.

Recibos de priorizacao v2/v3 usam mandatory; v4 usa Category. Consultas podem
mostrar outras categorias do mesmo catalogo, distinguindo fora da sequencia.
Planejamento restringe-se a SelectedIssues, inclusive issues manuais. Legado
sem PlanningBasis continua MTA. Base EVIDENCIAS nao recebe rodada/incidentes
inventados. CONSOLIDATED usa somente copias locais validadas para detalhes MTA;
caminhos de origem sao historicos. Contextos desconhecidos sao recusados.

O registro atual fornece decisao/andamento. Diferencas do snapshot sao declaradas,
sem sobrescrever escolhas. Origem MTA divergente exige esclarecimento. Indice e
localizador: ausencia/alteracao e diagnostico, nao revoga escolha nem autoriza
regeneracao. Nao se presume que a consulta conferiu todas as linhas do indice.

## Operacoes

| Action | Resultado |
| --- | --- |
| auditar_base | Identidade, hashes dos artefatos referenciados e contagens do catalogo/registro no escopo; divergencias com caminho e motivo. Nao confere aplicabilidade nem autentica a origem. |
| listar_issues | Resumos por Source + Id, categoria original, numero de incidentes, decisao/andamento atuais, disponibilidade na solicitacao e motivo de exclusao. |
| obter_issue | Uma issue por Id exato: metadados da regra e incidentes com ordinal, URI, linha do snapshot, mensagem, trecho e candidatos de caminhos locais. Candidato nao prova existencia, equivalencia nem resolucao. |

Listagem aceita Category, Decision, Progress e Text (busca literal em Id/titulo),
e Label (rotulo explicito do MTA, sem inferir tecnologia pelo titulo).
Page inicia em 1; PageSize padrao 10, maximo 50 para lista e 10 para incidentes.
`Incident` seleciona um ordinal (1..Total) em obter_issue, sem misturar paginacao.
Lista e ordenada por Id ordinal; incidentes preservam a ordem original. Resposta
informa Total, Returned, Page, PageSize e HasMore; nunca indica exame realizado.

Texto de evidencia tem limite explicito MaxTextChars (padrao 1024, 128..8192).
TruncatedFields e tamanhos originais indicam cortes; Provenance aponta o arquivo
completo. Nao deduplicar ocorrencias. Labels/links/metadados extensos tambem
declaram limitacao. Respostas vazias e pagina alem do fim sao distintas de erro.

## Resposta e erros

Envelope: SchemaVersion, Action, Status (OK/ERROR), ReadOnly, Provenance, Data,
Paging, Diagnostics e Error. Erro contem Code e Message; nao retorna dados
parciais como sucesso quando a origem/integridade esta invalida. Fonte ausente,
acesso negado, formato desconhecido, identidade conflitante e hash alterado sao
distintos. Nao executar JavaScript, comandos de anexos nem seguir links de rede.
Uma falha nao significa zero issues.

Provenance identifica ContextPath/RequestId/Source, PlanningBasis, EvidenceMode,
RunId/MtaOrigin quando existem, CatalogPath ou copia consolidada e hashes lidos.
BasisSha256 identifica contexto + evidencia consultada + registro atual.
ExpectedBasisSha256 opcional impede juntar paginas de bases diferentes.
Mudancas observadas durante a leitura falham como BASE_CHANGED. Consulta nao
concede autorizacao para executar o prompt e nao declara a solicitacao vigente
apenas porque seus arquivos existem.

CLI imprime um unico JSON; exit 0 em OK e 1 em ERROR. Parametros invalidos
tambem produzem ERROR/INVALID_INPUT. Funcoes internas nao abrem editor, nao fazem
menus e nao inicializam registros. Permissoes do processo continuam valendo;
origem negada nao pode ser contornada por outro transporte.

## Verificacao e adaptacao

Testar contagens/IDs, 138 ocorrencias, paginas e ordinal final, multi-projeto,
categorias, registros atuais, copia consolidada/importada, truncamento,
origem/hash divergentes, formato desconhecido, acesso negado e ausencia.
Inventario/hashes antes e depois demonstram leitura sem escrita; consulta sobre
caminho inexistente nao cria .harness. Comparacao de bytes em fixture mede apenas
volume de resposta. Economia de tokens/acerto exige ensaio no cliente.

MCP deve apenas adaptar este contrato, sem duplicar parser, armazenar estado ou
ampliar permissoes. Avaliacao de transporte/runtime pertence a esta entrega;
instalacao e homologacao do adaptador permanecem em incremento proprio.
