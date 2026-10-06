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
Filtros em outra operacao e Id fora de obter_issue retornam INVALID_INPUT.
Page inicia em 1; PageSize padrao 10, maximo 50 para lista/auditoria e 10 para incidentes.
`Incident` seleciona um ordinal (1..Total) em obter_issue, sem misturar paginacao.
Lista e ordenada por Id ordinal; incidentes preservam a ordem original. Resposta
informa Total, Returned, Page, PageSize e HasMore; nunca indica exame realizado.

Auditoria pagina Checks (FILE_HASH ou DIFFERENCE), com FilesCount e
DifferencesCount totais. Availability reflete a solicitacao, nao a elegibilidade
atual: Presence/Decision/Progress devem ser conferidos separadamente. Planejamento
restringe contagens as issues selecionadas e informa tambem RegisterTotalIssues.

Texto de evidencia tem limite explicito MaxTextChars (padrao 1024, 128..8192).
TruncatedFields e tamanhos originais indicam cortes; Provenance aponta o arquivo
completo. Nao deduplicar ocorrencias. Labels/links/metadados extensos tambem
declaram limitacao. RuleMetadataJson e EvidenceReferencesJson sao strings;
se cortadas, nao constituem JSON completo. LineNumber e inteiro nao negativo ou
nulo. Location e lexical, sem I/O nos candidatos locais/historicos; seus cortes
tambem sao declarados. Identidades/hashes nao sao truncados. O envelope inteiro,
inclusive erros e diagnosticos, tem teto UTF-8 de 256 KiB; excesso retorna
LIMIT_EXCEEDED sem dados/proveniencia parciais. Erros de argumentos da CLI limitam
Message a 1024 caracteres e declaram MessageTruncated/MessageOriginalLength.
Respostas vazias e pagina alem do fim sao distintas de erro.

## Resposta e erros

Envelope: SchemaVersion, Action, Status (OK/ERROR), ReadOnly, Provenance, Data,
Paging, Diagnostics e Error. Erro contem Code e Message; nao retorna dados
parciais como sucesso quando a origem/integridade esta invalida. Fonte ausente,
acesso negado, formato desconhecido, identidade conflitante e hash alterado sao
distintos. Nao executar JavaScript, comandos de anexos nem seguir links de rede.
Arquivos de entrada exigem raiz local absoluta, sem UNC/junctions, e ate 64 MiB
por arquivo. O limite nao transforma hash em assinatura/autenticacao da origem.
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

<a id="avaliacao-mcp-2026-10-06"></a>

## Avaliacao MCP - 2026-10-06

Proposta para o proximo incremento: adaptador local stdio com SDK oficial
TypeScript e subprocesso Windows PowerShell 5.1 chamando o mesmo nucleo. O SDK
resolve o protocolo; regras, hashes e parsers permanecem em HarnessIssueQuery.
TypeScript consta como Tier 1 no [catalogo oficial de SDKs](https://modelcontextprotocol.io/docs/2026-07-28/sdk).
A escolha de SDK/versao/runtime deve ser fixada e homologada nos clientes ao
implementar; nenhum pacote Node/Python/.NET adicional e necessario nesta entrega.

| Alternativa | Avaliacao para este harness |
| --- | --- |
| CLI PowerShell atual | Usa o runtime existente e prova o contrato; agente precisa de terminal permitido ou JSON fornecido pelo desenvolvedor. |
| SDK TypeScript + stdio | Recomendado para exposicao nativa; adiciona runtime/dependencia, mas preserva o nucleo e evita implementar JSON-RPC manualmente. |
| SDK C#/Python | Viaveis; exigem definir distribuicao/runtime adicional e nao reduzem a necessidade do nucleo PowerShell nesta etapa. |
| Servidor HTTP | Sem necessidade identificada para leitura local; implica operacao de servico, autenticacao e controle de acesso separados. |

O transporte stdio e iniciado pelo cliente e reserva stdout para mensagens do
protocolo, com logs em stderr; o adaptador deve distinguir esse canal do JSON
produzido pela CLI. A proposta de stdio decorre do uso local, nao de medicao de
desempenho. [Especificacao stdio](https://modelcontextprotocol.io/specification/2026-07-28/basic/transports/stdio).

Expor exatamente auditar_base, listar_issues e obter_issue, cada uma com schema
de entrada restrito e outputSchema do envelope. Mapear o resultado para
structuredContent e texto JSON de compatibilidade; erros de dominio continuam
com Code/Message e isError, separados dos erros de protocolo. Paginas sao
argumentos da consulta; tools/list lista as tres ferramentas, nao as issues.
[Contrato MCP de tools](https://modelcontextprotocol.io/specification/2026-07-28/server/tools).

Marcar a natureza de leitura nas annotations suportadas pelo SDK/versao adotados,
sem tratar essa declaracao como controle de acesso. Root e raizes permitidas
devem ser configuracao local do servidor; nao permitir que argumentos ampliem
essas raizes. O adaptador precisa validar tambem os caminhos internos do recibo,
executar sem shell/Invoke-Expression, impor timeout/cancelamento e nao elevar
permissoes. O nucleo atual aceita caminhos locais explicitos e **nao e um sandbox
de raizes**. Por isso nao basta publicar a CLI como servidor.

Antes de disponibilizar MCP: fixar SDK/versoes compativeis com Codex/Copilot reais,
validar Unicode/espacos, quoting e erros do subprocesso, comparar CLI/MCP para os
mesmos recibos, testar raizes permitidas e cancelamento, conferir descoberta
nativa e o ensaio de 10%. Nao escrever configuracao MCP nos clientes nem ampliar
tools dos helpers ate a entrega do adaptador. engineering-harness-vscode.md
continua fora deste escopo.
