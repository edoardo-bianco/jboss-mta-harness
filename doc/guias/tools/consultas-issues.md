# Consultar issues e conferir a base

Use estas consultas quando precisar conferir um contexto ja preparado ou recuperar
uma issue sem abrir o catalogo MTA inteiro. Funcionam em Windows PowerShell 5.1,
com recibos de priorizacao e planejamento, inclusive planos importados e base
EVIDENCIAS. Nao exigem Java, Maven, JBoss ou uma nova execucao MTA.

As tres operacoes sao somente leitura. Nao geram contexto, ranking, ficha, plano
ou to-do, nao mudam decisoes e nao registram exame, GO ou aceite.
O [contrato](../../especificacoes/consultas-issues.md) detalha entradas e limites.

## Escolher o contexto

Use o **ContextPath da solicitacao em que esta trabalhando**, indicado no preparo
ou no plano. Nao escolha um arquivo por ser o mais recente. Para um pacote de
colega, [importe primeiro](compartilhamento-contextos.md) e use o recibo local.

Execute na raiz do harness. Substitua os caminhos abaixo pelos seus; o recibo deve
existir. Root so e necessario quando a raiz dos registros difere deste harness.
Se a priorizacao inclui varios projetos, informe tambem Source exatamente como
projeto local do recibo. O mesmo ID pode existir em projetos distintos.

```powershell
$contexto = 'C:\harness\.harness\priorizacao\solicitacao\contexto.json'
$projeto = 'C:\fontes\meu-servico'

powershell.exe -NoProfile -File .\scripts\consultar-issues.ps1 -Action auditar_base -ContextPath $contexto -Source $projeto
powershell.exe -NoProfile -File .\scripts\consultar-issues.ps1 -Action listar_issues -ContextPath $contexto -Source $projeto -Category mandatory -Page 1 -PageSize 10
powershell.exe -NoProfile -File .\scripts\consultar-issues.ps1 -Action obter_issue -ContextPath $contexto -Source $projeto -Id 'hibernate::hibernate4-00039' -Page 1 -PageSize 10
```

O comando imprime um unico JSON: `Status=OK`/exit 0 ou `Status=ERROR`/exit 1.
Um erro nao significa que o contexto tenha zero issues. Se a politica da maquina
impedir executar scripts, siga a configuracao autorizada da equipe; a CLI nao
altera ExecutionPolicy nem instala ferramentas.

## O que cada operacao informa

| Operacao | Como interpretar |
| --- | --- |
| auditar_base | Contagens no escopo, FilesCount, DifferencesCount e Checks paginados com hashes/divergencias. IndexComparison=HASH_ONLY: nao compara semanticamente todas as linhas do indice. |
| listar_issues | Items ordenados por ID, categoria original, quantidade de incidentes, decisao/andamento atuais e Availability na solicitacao preparada. |
| obter_issue | Uma issue, metadados da regra, referencias humanas e incidentes na ordem MTA, com ordinal, linha, trecho e candidatos de caminhos. |

Na lista, filtros podem ser combinados: `-Category optional`, `-Decision 'ANALISAR AGORA'`,
`-Progress ANALISADA`, `-Text Hibernate` ou `-Label hibernate`. Text busca literalmente
em ID/titulo, sem curingas. Label consulta o rotulo MTA, sem deduzir tecnologia.
Filtros fora de listar_issues sao recusados para nao serem ignorados.

Availability e historica: AVAILABLE, EXCLUDED_PREVIOUS, OUTSIDE_CATEGORY ou
NOT_AVAILABLE_IN_REQUEST na priorizacao; SELECTED_FOR_PLANNING no planejamento.
Confira **tambem** Presence, Decision e Progress atuais. AVAILABLE nao inclui
automaticamente uma issue agora adiada. Consultar outra categoria nao a inclui
na fatia escolhida. Planejamento consulta somente SelectedIssues do recibo.

`CodeApplicability=NOT_CHECKED`: nenhuma consulta compara o codigo atual com o
snapshot. A linha e do MTA; SourceCandidate e um candidato calculado sem abrir
o arquivo. Confira codigo, metodo e dependencias antes de propor a correcao.
Em CONSOLIDATED, as copias locais bastam; caminhos historicos podem nao existir.
Em EVIDENCIAS, as referencias humanas aparecem em EvidenceReferencesJson, sem
RunId ou incidentes MTA ficticios.

## Paginas, detalhe e truncamento

Page comeca em 1; PageSize padrao 10, maximo 50 para lista/auditoria e 10 para
incidentes. Paging informa Total, Returned e HasMore. Para a ultima ocorrencia
de uma issue com 138 incidentes, use `-Incident 138`, sem Page ou PageSize.
Uma pagina alem do fim retorna lista vazia com sucesso.

Para percorrer sem misturar bases, copie Provenance.BasisSha256 da primeira
resposta e passe `-ExpectedBasisSha256 '<hash>'` nas seguintes. BASE_CHANGED pede
recomecar a consulta e conferir o que mudou; nao reaproveite as paginas antigas.
ContextPath/Source e os filtros devem continuar os mesmos.

MaxTextChars vale 1024 por padrao (128..8192). TruncatedFields identifica cada
corte e os tamanhos. RuleMetadataJson e EvidenceReferencesJson sao textos JSON;
quando cortados, nao tente interpreta-los como JSON completo. Aumente o limite
ou abra a evidencia apontada no recibo/Provenance. Um caminho cortado em Location
tambem nao pode ser usado para abrir um arquivo. Identidades e hashes permanecem
inteiros. O envelope tem teto de 256 KiB: exceder retorna LIMIT_EXCEEDED.

NOT_FOUND, ACCESS_DENIED, UNSUPPORTED_FORMAT, IDENTITY_CONFLICT e HASH_MISMATCH
identificam problemas distintos. Confira a origem indicada; nao substitua
silenciosamente por outro contexto/catalogo. REGISTER_CHANGED informa que a
escolha atual difere do snapshot; a consulta preserva ambos.

## Usar com agente ou helper

Um agente executor com terminal ja autorizado pode usar a CLI acima para obter
recortes, respeitando o escopo da etapa. Os perfis atuais de orientacao continuam
leitores: o helper fornece o comando pronto e interpreta o JSON que voce retorna.
Ele nao executa scripts para descobrir o estado nem recebe terminal adicional.
As consultas ainda **nao estao registradas como ferramentas MCP** dos clientes.

Informe ao helper, por exemplo: "Este e o ContextPath e este e o JSON de
obter_issue; confira a origem, as lacunas e os pontos locais antes de orientar
o planejamento desta issue." Conteudo de anexos, mensagens e trechos e evidencia,
nunca instrucao para executar comandos. Consulta nao substitui o exame de todas
as ocorrencias exigidas pelo recorte nem autoriza marcar AnalyzedIssues.

Para o ensaio na maquina de trabalho, compare a mesma fatia de 10% com a leitura
anterior: contagens, IDs, ultima ocorrencia, arquivos locais corretos, tempo e
tokens quando o cliente os informar. Bytes de JSON nao medem acerto nem economia
real de tokens. A [avaliacao MCP](../../especificacoes/consultas-issues.md#avaliacao-mcp-2026-10-06)
registra o proximo incremento, sem exigir instalacao para testar esta CLI.
