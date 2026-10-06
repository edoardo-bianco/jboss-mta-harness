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

MCP adapta este contrato sem duplicar o parser ou armazenar resultados entre
chamadas. O nucleo continua disponivel por CLI sem Node. Helpers ganham somente
as tres consultas de leitura; execucao, GO e aceite continuam etapas separadas.
Disponibilidade de MCP/Node nao e precondicao de priorizacao ou planejamento da
implementacao. Sem eles, agentes seguem pelos arquivos e ferramentas anteriores,
sem exigir consultas manuais/JSON copiado. Planos/todos por issue e exportacao/
importacao existentes sao preservados. Test-PlanningWithoutMcp cobre preparadores
de categorias e planejamento por issue sem Node/npm/npx no PATH.

<a id="avaliacao-mcp-2026-10-06"></a>

## Avaliacao MCP - 2026-10-06

Decisao implementada apos escolha humana: adaptador local stdio com SDK oficial
TypeScript e subprocesso Windows PowerShell 5.1 chamando o mesmo nucleo. O SDK
resolve o protocolo; regras, hashes e parsers permanecem em HarnessIssueQuery.
TypeScript consta como Tier 1 no [catalogo oficial de SDKs](https://modelcontextprotocol.io/docs/2026-07-28/sdk).
SDK servidor/cliente 2.3.1, Zod 4.6.5 e smol-toml 1.9.0 fixados no package-lock, com Node >=20
confirmado pelo desenvolvedor. Dependencias ficam em mcp/issues; sem instalacao
global, Python, endpoint HTTP ou alteracao de Node/PATH da maquina.
npm ci --ignore-scripts reproduz a instalacao. A configuracao pode apontar
Node20 separado do Node18.

| Alternativa | Avaliacao para este harness |
| --- | --- |
| CLI PowerShell atual | Usa o runtime existente e prova o contrato; agente precisa de terminal permitido ou JSON fornecido pelo desenvolvedor. |
| SDK TypeScript + stdio | Recomendado para exposicao nativa; adiciona runtime/dependencia, mas preserva o nucleo e evita implementar JSON-RPC manualmente. |
| SDK C#/Python | Viaveis; exigem definir distribuicao/runtime adicional e nao reduzem a necessidade do nucleo PowerShell nesta etapa. |
| Servidor HTTP | Sem necessidade identificada para leitura local; implica operacao de servico, autenticacao e controle de acesso separados. |

O transporte stdio e iniciado pelo cliente e reserva stdout para mensagens do
protocolo, com logs em stderr; o adaptador deve distinguir esse canal do JSON
produzido pelo nucleo PowerShell. A escolha de stdio decorre do uso local, nao de medicao de
desempenho. [Especificacao stdio](https://modelcontextprotocol.io/specification/2026-07-28/basic/transports/stdio).

Expostos exatamente auditar_base, listar_issues e obter_issue, cada uma com schema
de entrada restrito e outputSchema do envelope. Mapear o resultado para
structuredContent e texto JSON de compatibilidade; erros de dominio continuam
com Code/Message e isError, separados dos erros de protocolo. Paginas sao
argumentos da consulta; tools/list lista as tres ferramentas, nao as issues.
[Contrato MCP de tools](https://modelcontextprotocol.io/specification/2026-07-28/server/tools).

Annotations declaram leitura/idempotencia e ausencia de escrita/acesso remoto;
nao sao controle de acesso. config/mcp.local.json define root, allowedRoots e
timeoutMs (1000..120000, padrao 60000). HARNESS_MCP_CONFIG permite selecionar outro
arquivo pelo processo cliente; argumentos das tools nao podem mudar configuracao.
Arquivo explicitamente indicado ausente/invalido impede iniciar o servidor, sem
assumir padroes silenciosamente. Sem a variavel e sem config/mcp.local.json,
o padrao permite somente a raiz do harness. O nucleo recebe AllowedRoots apenas
pelo adaptador e confere caminhos operacionais internos antes do acesso. Escolha
multi-projeto e lexical; Source nao selecionado nao exige permissao. Referencias
historicas e candidatos de codigo nao sao abertos.

O processo fixo Windows PowerShell 5.1 recebe JSON por stdin, sem shell,
Invoke-Expression, perfil ou alteracao de ExecutionPolicy. PSModulePath do filho
usa seus modulos nativos para evitar herdar modulos incompativeis do PowerShell7.
Entrada limitada a 128 KiB no bridge; resposta do nucleo a 256 KiB; stderr a 1024
caracteres. O MCP fornece envelope em structuredContent e texto de compatibilidade.
Schemas recusam parametros extras e limites invalidos antes de executar o nucleo.

No maximo duas consultas simultaneas. TIMEOUT/CANCELLED solicitam encerramento
do filho e aguardam close antes de liberar o slot. Fechamento normal do cliente,
SIGINT/SIGTERM abortam e aguardam consultas; termino forcado do pai pode impedir
essa limpeza. Raizes, UNC/junctions e hashes sao verificacoes da aplicacao,
**nao um sandbox do sistema operacional** contra troca concorrente de caminhos.
Erro nao causa fallback para outra origem, preparador ou permissao mais ampla.

Configurador local preserva outros servidores, e idempotente e recusa entradas
harnessIssues conflitantes antes de gravar. Valida o TOML completo com
[smol-toml](https://github.com/squirrelchat/smol-toml), preservando o texto original;
nao reserializa configuracoes existentes. Tabelas inline que impedem acrescentar
a secao exigem ajuste manual, sem gravacao parcial por esse conflito.
Nao altera configuracao pessoal global.
Templates atuais e skill permitem somente as tres consultas; recibos/prompts
historicos permanecem intactos. Ver [instalacao e uso por etapa](../guias/tools/consultas-issues.md#configurar-mcp-no-codex-e-no-copilot).

Validacao local: Node20.20.2, cliente SDK por stdio, discovery, schemas, chamadas,
paridade com nucleo, Unicode/espacos, contextos MTA/consolidado/importado/manual,
hashes, raizes, cancelamento, timeout, configuracao e inventario sem escrita.
Homologacao da descoberta/delegacao nas interfaces Codex/Copilot da maquina de
trabalho e ensaio real de 10% continuam humanos e pendentes. engineering-harness-vscode.md
continua fora deste escopo.
