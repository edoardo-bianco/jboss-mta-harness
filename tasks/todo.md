# To-do do agente: evolucao do harness

## Guia Node 24 na maquina de trabalho - 2026-10-07

- [x] Conferir raiz/branch/HEAD e criar harness/guia-node24 da main d198ad4 limpa.
- [x] Conferir distribuicao oficial e recuperar caminho/versoes informados.
- [x] Atualizar guia: Node 24.21.0, pasta node-24, verificacao e comandos MCP.
- [x] Revisar links, sintaxe dos quatro blocos PowerShell, quatro comandos com o
  caminho informado e diff; salvar incremento documental em commit local.
- [x] Registrar relato de execucao: Node v24.21.0 e npm 11.19.0 na maquina de trabalho.
- [ ] Continuar ensaio humano: instalar dependencias, configurar clientes e chamar
  auditar_base, listar_issues e obter_issue; versoes exibidas nao encerram esse teste.

## Guia de instalacao Node e apoio do helper - 2026-10-06

- [x] Conferir checkout limpo e localizar guia e instrucoes comuns dos helpers.
- [x] Detalhar ZIP/pasta fixa e vincular configuracao nos guias de entrada.
- [x] Alinhar skill/papel de preparo para orientar Node/MCP sem exigir migracao.
- [x] Conferir 382 links, comandos, 18 perfis/prompts e skill; salvar incremento
  documental em commit local, mantendo pendente o ensaio na maquina de trabalho.

## Auditoria de coerencia da entrega - 2026-10-06

- [x] Conferir raiz/branch/HEAD e registrar escopo da auditoria.
- [x] Confrontar codigo e configuracao MCP com contrato/guia.
- [x] Auditar README, guias, instrucoes gerais, skill, agentes e prompts por etapa.
- [x] Corrigir quatro achados: referencias de guias nos prompts copiados, leitura
  duplicada de incidentes, TOML inline invalidado e configuracao ausente silenciosa.
- [x] Validar: seis testes MCP Node20 PASS, preparadores sem MCP PASS, 18 perfis/prompts,
  380 links, tarefas/comandos e skill; revisoes independentes sem bloqueadores.
- [x] Registrar conclusao e limites no plano; separar corretivas e documentos em
  commits locais na branch de trabalho.

## Consultas MCP nas fases com agentes - 2026-10-06

- [x] Confirmar forma de exposicao: usuario escolheu MCP para Codex e Copilot.
- [x] Conferir checkout e fontes oficiais; registrar fronteiras de leitura e fases.
- [x] Testar e implementar raizes permitidas no nucleo de leitura; selecao
  multi-projeto corrigida por teste RED/GREEN e oito regressoes PASS.
- [x] Implementar SDK/stdio, schemas restritos e subprocesso fixo via JSON stdin.
- [x] Validar discovery, chamadas, paridade, erros, caminho Unicode e espacos,
  timeout/cancelamento e espera pelo termino do filho no Node20.20.2.
- [x] Configurar clientes localmente e alinhar fases, prompts, helpers, skill e guias;
  Codex CLI reconhece configuracao; 18 perfis/prompts e 409 links conferidos.
- [x] Comprovar preparadores sem Node/npm/npx e sem configuracao MCP; agentes
  continuam pelo fluxo anterior, sem exigir consultas manuais/JSON copiado.
- [x] Rodar regressao e revisao independente sem bloqueadores; npm audit sem
  vulnerabilidades. Incrementos salvos em commits locais na branch de trabalho.
- [ ] Homologar descoberta e uso pelos agentes no cliente da maquina de trabalho.

## Corretiva deploy Windows legado - 2026-10-06

- [x] Preservar consultas e criar branch isolada da main com PR #11 integrado.
- [x] Localizar tratamento de caminho absoluto na CLI antiga.
- [x] Reproduzir falha e corrigir deploy/rollback com caminho nativo e espacos.
- [x] Conferir parser real sem servidor e executar regressao dirigida: 4 scripts PASS.
- [x] Alinhar guia e revisar: sintaxe/diff OK, revisao independente sem bloqueadores.
- [x] Salvar commit isolado da corretiva.
- [ ] Validar deploy SIMTR-api no EAP 7.0 da maquina de trabalho.

## Corretiva prioritaria EAP 7.0 - 2026-10-06

- [x] Preservar consultas em andamento e criar checkout/branch da corretiva.
- [x] Localizar recusa de Version 7.0 na opcao eap71.
- [x] Reproduzir por teste e ajustar deteccao/identidade sem aceitar outras versoes.
- [x] Conferir CLI 7.0, start/status/stop, menu e documentacao.
- [x] Rodar regressao JBoss, revisar e salvar commit isolado: 10 scripts PASS;
  sintaxe/diff conferidos e revisao independente sem bloqueadores.
- [ ] Validar start/estado/stop no EAP 7.0 real da maquina de trabalho.

## Consultas de issues - implementacao 2026-10-06

- [x] Confirmar main limpa/PR #10 e criar harness/consultas-issues.
- [x] Recuperar proposta e mapear reuso, limites e capacidades relacionadas.
- [x] Trazer corretivas dos PRs #11/#12 da main (fcee604), preservando trabalho parcial.
- [x] Definir contrato e escrever testes de leitura/auditoria antes do codigo.
- [x] Validar nucleo para priorizacao: lista/detalhe, filtros, 138 incidentes,
  ordinal, truncamento, escolhas atuais, identidade, hashes e ausencia de escrita.
- [x] Implementar listagem/detalhe paginados, filtros e CLI JSON somente leitura.
- [x] Cobrir consolidado/importado, identidade, hashes, falhas e preservacao.
- [x] Corrigir achados da revisao: UNC, caminhos lexicais, teto de resposta e indices por ID.
- [x] Alinhar guias/prompts/helper e avaliar adaptador MCP nas fontes oficiais.
- [x] Executar regressao dirigida e revisao independente: 10 scripts PASS,
  376 links, sintaxe/skill/diff OK; salvar incrementos em commits locais.
- [x] Implementar adaptador MCP no incremento acima; homologacao nativa corporativa
  permanece separada do teste de integracao via SDK.
- [ ] Comparar no cliente a mesma fatia de 10%: omissoes, tempo e tokens reais.

## Revisao de documentacao e orientacao - 2026-10-06

- [x] Conferir raiz, branch, HEAD e estado limpo; retomar eead84b.
- [x] Ler skills pertinentes e mapear divergencias com o fluxo implementado.
- [x] Alinhar README, guia principal e guias de etapas, preservando ancoras.
- [x] Simplificar skill/papeis e alinhar instrucoes dos clientes sem ampliar poderes.
- [x] Validar links, comandos/tarefas e skill; ensaiar cenarios de orientacao.
  401 links, 25 tarefas, 22 referencias a scripts, 12 perfis e 3 cenarios aprovados.
- [x] Revisar diff, registrar limites da verificacao e salvar commit documental.
- [ ] Validar descoberta/delegacao nativa nos clientes e ensaio de 10% na maquina
  de trabalho; os cenarios de leitura nao comprovam essa homologacao.

## Exportacao/importacao - implementacao 2026-10-06

- [x] Retomar main integrada/limpa e confirmar proxima entrega com o humano.
- [x] Criar harness/exportacao-importacao e registrar contrato/aceite do incremento.
- [x] Testar e implementar ZIP versionado, inventario/hashes e exportacao do plano.
- [x] Testar importacao em outra raiz, Source explicito, derivados e originais preservados.
- [x] Tratar preview, conflito, reimportacao e validacao de caminhos/limites/integridade.
- [x] Exportar/importar priorizacao concluida com cadeia, categoria, cobertura e MTA.
- [x] Comprovar continuidade e passagem de ficha recebida ao planejamento.
- [x] Integrar CLI/Run Task, orientador, contrato e guias sem duplicar fluxos.
- [x] Rodar regressao dirigida, revisao independente e registrar limites do ensaio.
- [x] Corrigir achados da revisao: vinculos/caminhos, origem congelada, historico,
  links relativos, hashes Previous e rollback de arquivos/diretorios novos.
- [x] Windows PowerShell 5.1: 20 scripts PASS; sintaxe, diff e 262 links locais OK.
  Logs em .harness/tests/entrega2-20261006/; fixtures nao versionadas.
- [ ] Ensaiar na maquina de trabalho: exportar analise de 10%, importar em outra
  raiz, continuar categoria, planejar uma ficha e compartilhar seu plano.
- [x] Integrar/publicar esta entrega: PR #10 aceita e integrada em 0e74925.
  Consultas retomadas acima; engineering-harness-vscode.md continua adiado.

## Categorias, planejamento por issue e portabilidade - proposta 2026-10-06

Status: **Entrega 1 implementada localmente**, conforme autorizacao posterior do desenvolvedor. Ensaio humano na maquina de trabalho pendente.
Prioridade e criterios detalhados na secao de mesma data em tasks/plan.md.

- [x] Conferir raiz, branch, HEAD e alteracoes locais; preservar proposta anterior.
- [x] Localizar filtro mandatory, continuidade, fichas, leitura de referencias
  pelo planejamento e limites da portabilidade existente.
- [x] Consolidar entrega 1 com categorias separadas, compatibilidade e passagem
  da ficha ao plano/to-do por issue ou recorte coerente.
- [x] Registrar roteiro de teste na maquina de trabalho e seus limites.
- [x] Delimitar exportacao/importacao por etapa como entrega posterior; preservar
  a proposta de auditar_base/listar_issues/obter_issue e a avaliacao futura de MCP.
- [x] Conferir diff, referencias citadas e preservacao do historico documental.
- [x] Registrar ferramentas/MCP como ultima etapa e mapear encaixe inicial
  nas capacidades ja documentadas em doc/features/ e na conciliacao existente.
- [x] Refinar entrada por ficha e anexos da issue, fluxo do desenvolvedor,
  saidas e atualizacao do planejamento com evidencias novas.
- [x] Incluir limpeza e alinhamento do orientador, perfis dos clientes, prompts
  e guias no aceite da primeira entrega, com cinco cenarios de clareza.
- [x] Refinar pastas e nomes por projeto + issue, fichas separadas por projeto
  mesmo com regra igual e contexto consolidado para implementar sem MTA original.
- [x] Registrar passagem entre colegas como cenario principal: analise/proposta
  de A, execucao manual ou por agente de B e apoio do orientador em cada etapa.
- [ ] ADIADO por pedido humano: avaliar doc/features/engineering-harness-vscode.md
  e conciliar com as capacidades existentes somente em retomada futura.
  Documento adicionado pelo desenvolvedor; conteudo nao examinado nesta etapa.

Entrega 1 - implementacao e validacao local:

- [x] Criar fixtures/testes de categorias e continuidade, incluindo historico v2/v3.
- [x] Parametrizar categoria e isolar base, SequenceId, Previous e cobertura;
  manter exclusao das examinadas por Source + ID dentro da sequencia.
- [x] Atualizar CLI/menu/contexto/prompt/resposta na Run Task existente, com
  cancelamento e escolha preservada na retomada; testar entrada nao interativa.
- [x] Definir layout versionado projeto/issues/issue/solicitacao e nomes de
  ficha/contexto/plan/todo identificaveis; preservar leitura de nomes/layouts legados.
- [x] Adaptar historico, referencias, indice, abertura, implementacao e limpeza
  aos destinos declarados, sem renomear arquivos historicos.
- [x] Evoluir novas priorizacoes para ranking + fichas individuais por projeto/issue;
  validar FichaPaths e testar mesma regra em projetos distintos com dados separados.
- [x] Estender a operacao de evidencias existente para pasta/LEIA-ME por issue,
  com identidade, nomes seguros e preservacao dos anexos/indices legados.
- [x] Resolver ficha e indice de anexos da issue como entradas explicitas do
  planejamento; preservar ancora, Source/ID e associacoes dos anexos compartilhados.
- [x] Comprovar categorias optional/potential independentes e passagem de optional
  com ficha e anexos ao planejamento; testar isolamento de outra issue,
  ausencia/ambiguidade e referencia incorreta.
- [x] Testar retomada sem duplicar e novo anexo gerando revisao com Previous;
  preservar recibos/propostas anteriores e explicitar conflitos com a ficha.
- [x] Explicitar plano legivel para execucao manual ou agente, com recorte,
  dependencias, passos, verificacoes, reversao e GO/aceite separados.
- [x] Consolidar ficha/extratos MTA/anexos utilizados por solicitacao, com origem,
  cobertura e hashes; manter referencias ao codigo por caminho relativo/simbolo/trecho.
- [x] Definir modo explicito de execucao com evidencias consolidadas; adaptar
  validacao/prompts e testar origem MTA indisponivel sem fallback silencioso.
- [x] Comprovar falha de derivado ausente/alterado, independencia do caminho
  historico e preservacao das exigencias de recibos legados de base MTA.
- [x] Alinhar skill comum de orientacao e papeis a categoria/ficha/anexos;
  conferir perfis Codex/Copilot, mantendo regras comuns e helper leitor.
- [x] Simplificar guias central, orientacao, priorizacao, planejamento e modelo
  de evidencias: termos unicos, passos claros e referencias sem duplicacao.
- [x] Alinhar contrato, prompts, Run Tasks e entradas vigentes atingidas;
  preservar recibos/documentos historicos e atualizar somente novos preparos.
- [x] Conferir concordancia entre guia e orientador: escolha de categoria, ficha
  escolhida, novo anexo, revisao do plano e passagem a execucao manual/assistida.
- [x] Ensaiar colega recebendo analise ou plano de outro: orientador identifica
  etapa, lacunas e Source local; distingue executor manual/agente e nao implementa.
- [x] Executar regressao dirigida no Windows PowerShell 5.1 e revisar a entrega.
- [x] Registrar escolha humana de iniciar do zero na maquina de trabalho e
  alinhar roteiro de reinicio completo no guia de workspace.
- [x] Preparar entrega revisada para commit/push e PR para main, autorizados pelo humano.
- [ ] Atualizar o harness na maquina de trabalho apos receber a entrega por Git.
- [ ] Reiniciar a .harness de ensaio nessa maquina; preservar configuracao,
  workspace, fontes e MTA externo. Reconstruir indice/registros e conferir origem.
- [ ] Ensaiar mandatory -> optional/potential -> retomar mandatory na maquina
  de trabalho, iniciando com 10%; conferir denominadores, exclusoes, ficha/anexos e plano da issue
  escolhida, incluindo atualizacao posterior de evidencia.
- [ ] Registrar avaliacao humana da primeira entrega antes de avancar.

Depois do ensaio:

- [ ] Detalhar pacote de priorizacao e pacote de planejamento: manifesto,
  fechamento das referencias, identidade/origem, hashes e estado da etapa.
- [ ] Definir importacao com mapeamento de Source/caminhos, preservacao do
  historico, indice local, reimportacao e conciliacao de conflitos.
- [ ] Implementar exportacao/importacao e testar em duas raizes distintas, com
  A analisando/planejando e B implementando sem acesso ao MTA original quando
  houver contexto consolidado suficiente; devolucao nao implica integracao/aceite.
- [ ] Por ultimo, apos exportacao/importacao e a conciliacao documental, retomar
  contrato das consultas auditar_base/listar_issues/obter_issue e avaliar MCP
  em incremento proprio, reaproveitando as capacidades existentes.

Implementacao, testes locais e revisao independente executados. A passagem entre
colegas foi conferida por fixtures e revisao documental de cinco cenarios; ensaio
nativo do orientador e teste corporativo continuam pendentes. Export/import,
ferramentas/MCP e engineering-harness-vscode.md permanecem adiados.
O quick_validate.py da skill nao executou por ausencia de PyYAML; frontmatter e
referencias foram conferidos diretamente, sem instalar dependencias na maquina.

Validacao local em 2026-10-06: 39 scripts de teste PASS e Test-JbossReal SKIP
(servidor real nao solicitado), em Windows PowerShell 5.1. Inclui regressao de
categorias/historico, dossie por issue, anexos, preparacao de implementacao sem
o MTA original e rejeicao de evidencia consolidada alterada. Test-BuildCoverage
validou JaCoCo com JDK 8/Maven reais. Relatorio e logs locais em
`.harness/tests/entrega1-20261006/suite.json`; 264 links documentais conferidos
sem erro em `links.json` da mesma pasta. `git diff --check` sem erros.
Modelo comum confirmado no contrato e no prompt: nove secoes de plano, cinco
de to-do, tarefas ligadas a E1/E2 e justificativa para secoes nao aplicaveis.
Publicacao da branch `harness/tools-analise-issues` autorizada: commit de todo o
conteudo pendente e PR para main, sem merge nesta etapa. Por pedido posterior,
incluir tambem `doc/features/engineering-harness-vscode.md` como foi fornecido;
seu conteudo continua sem analise ou planejamento nesta entrega.

## Ferramentas para analise de issues e pre-planejamento - retomada 2026-10-05

Ordem revista pela proposta de 2026-10-06 acima. Itens abaixo permanecem backlog
das ferramentas; nao sao o primeiro incremento atual.

- [x] Conferir componentes existentes e registrar analise inicial em tasks/plan.md.
- [ ] Na retomada, delimitar auditar_base, listar_issues e obter_issue; definir
  entradas, saidas, paginacao, proveniencia e erros sem duplicar o parser existente.
- [ ] Definir acesso/autorizacao das origens do contexto e avaliar o adaptador MCP
  local, com configuracao compativel com os clientes usados pelo desenvolvedor.
- [ ] Planejar regressao de contagens/IDs, detalhes de incidentes, paginas, hashes,
  caminho historico, acesso negado, arquivo ausente e formato nao suportado.
- [ ] Implementar e testar o incremento quando o trabalho for retomado; revisar
  integracao com prompts e Run Tasks, mantendo classificacao tecnica separada
  da categoria MTA e sem consumir cobertura pela mera consulta.
- [ ] Avaliar depois comparar_ocorrencias, inspecionar_dependencias e
  validar_priorizacao conforme os resultados do primeiro incremento.

Somente documentacao salva nesta etapa; nenhuma ferramenta nova implementada,
nenhuma instalacao MCP ou mudanca de permissoes. Commit/PR deste trabalho ainda
nao realizados. Para continuar, ler a secao correspondente de tasks/plan.md.

## Regeneracao com pastas sem nome - 2026-10-05

- [x] Conferir estado e criar branch de bugfix a partir de main.
- [x] Reproduzir o erro com pastas sem name no Windows PowerShell 5.1.
- [x] Corrigir regeneracao e preservar imports, aliases, settings e backups.
- [x] Validar regressao, Run Task local e revisar o resultado.

RED reproduziu exatamente PropertyNotFound em Where-Object name, Harness.psm1:205.
GREEN com correspondencia por nome opcional e caminho normalizado. Test-Workspace,
Test-JbossWorkspace e Test-BuildConfig PASS em Windows PowerShell 5.1. A chamada
real scripts/gerar-workspace.ps1 tambem terminou com exit code 0 neste checkout.
Revisao independente apontou rejeicao indevida de pasta UNC extra: regressao
adicionada, RED observado e GREEN apos preservar caminhos extras nao gerenciados.
A revisao do agente foi interrompida por limite de uso; conferencia final do diff
feita pelo condutor. Sem acesso ao workspace da maquina de trabalho; reproducao
com fixture do formato valido path-only, sem dados corporativos.
Publicacao solicitada pelo desenvolvedor apos a validacao: commit/push da branch
e PR para main. Sem merge ou novo alinhamento das principais nesta etapa.

## Acesso de leitura a raiz MTA no workspace - 2026-10-05

- [x] Conferir branch/estado e chave/escopo no manifesto oficial do Copilot.
- [x] Testar geracao a partir de mta.runsPath e preservacao da lista humana.
- [x] Aplicar ao workspace local e documentar como alterar/remover o acesso.
- [x] Validar e revisar o incremento; preservar limite do ensaio nativo pendente.

RED: Test-Workspace falhou por ausencia da permissao da raiz MTA. GREEN apos
inicializacao no gerador; Test-Workspace, Test-JbossWorkspace e Test-BuildConfig
PASS em Windows PowerShell 5.1. Workspace local validado como JSON com somente
C:/mta-runs na lista adicional. Guias explicam escopo local, outra maquina,
edicao/revogacao e preservacao da lista pelo gerador. Configuracao local ignorada
no Git; gerador e guias sao versionados. Leitura nativa Copilot continua pendente.
Revisao independente sem bloqueadores; git diff --check sem erros. Evidencia em
`.harness/tests/incidentes-mta-20261005/workspace-read-access.json`.

## Recuperacao dos incidentes MTA na priorizacao - 2026-10-05

- [x] Conferir diagnostico, raiz/HEAD/estado e criar branch propria a partir de main.
- [x] Reproduzir perda dos detalhes na preparacao com teste falhando.
- [x] Preparar incidentes paginados, caminhos candidatos seguros e hashes.
- [x] Orientar permissao externa, leitura literal e continuidade sem cobertura ficticia.
- [x] Validar regressao/suite, revisar e registrar evidencias e limites.
- [ ] Ensaio nativo na maquina afetada: ler URI/linha/mensagem/trecho apos permissao;
  recusa preserva parcial e nao consome quota. Nao inferir este ensaio dos testes.

Windows PowerShell 5.1: suite de 38 scripts, 37 PASS e 1 SKIP do ensaio real
JBoss; resumo/logs em `.harness/tests/incidentes-mta-20261005/suite.json`.
Regressao RED antes da implementacao por falta de IncidentEvidence, depois GREEN:
138 incidentes em 14 paginas, sem perda/duplicacao, campos ausentes explicitos,
hashes, retomada/recriacao e preservacao das entradas. Revisao independente apontou
fallback excessivo de URI com /input/: novo RED com dependencia/rodada distinta,
correcao exige raiz conhecida ou estrutura historica com identidade da rodada.
Regressao reexecutada apos esse ajuste: PASS; revisao confirmou o achado resolvido,
sem outro bloqueador. Resultado adicional em `regressao-pos-revisao.json` nessa area.
Git diff --check sem erros. Integracoes automatizadas usam fixtures/doubles;
build/cobertura usam JDK/Maven configurados. Sem MTA corporativo ou ensaio nativo
Copilot nesta maquina. A leitura externa e retomada dependem da autorizacao real
do cliente; guia documenta acesso somente de leitura por pasta e reteste Recreate
para fatias antigas concluidas com falha operacional.

## Cobertura progressiva da priorizacao - 2026-10-05

- [x] Identificar causa e conferir raiz/main/HEAD/estado limpo; criar branch propria.
- [x] Reproduzir repeticao de examinadas sem proposta e caso 44/20% em teste.
- [x] Implementar progresso por examinadas e compatibilidade com resultados v2.
- [x] Exigir quota completa nos resultados novos e relatorio de todas as examinadas.
- [x] Harmonizar contrato, prompt, guias e orientacao dos helpers, incluindo ficha
  de evidencias/referencias/roteiro manual para TODAS as examinadas.
- [x] Validar suite, revisar diff e registrar resultados/limites.
- [x] Revisar autonomia pelo README/guia, encaminhamento do helper e formato
  legivel das fichas; conferir links e preparo apos alteracao do template.
- [ ] Reproduzir falha eventual do DevSquad na maquina afetada quando houver erro.
  Investigacao adiada pelo desenvolvedor: perfis locais conferidos, mas mensagem
  da falha indisponivel. Prompt passa a registrar apoio real e erro; guia indica
  diagnostico sem alterar plugin ou ampliar permissoes.

Validacao em Windows PowerShell 5.1: 37 scripts, 36 PASS e 1 SKIP explicito
do ensaio real JBoss. Regressao falhou antes da correcao ao repetir examinadas
sem proposta; depois passou com 44/20% em 9+9+9+9+8, rodada sem recomendacao,
historico v2 com sobreposicao/parcial, quota v3 e retirada humana apos preparo.
Revisao independente identificou dois ajustes incorporados: retirada pos-preparo
sem cobertura ficticia e delimitacao das instrucoes DevSquad ao Copilot.
236 links locais conferidos em 14 Markdown; git diff --check sem erros.
Evidencias em `.harness/tests/priorizacao-cobertura-20261005/suite.json` e
`links.json`. Teste de cobertura usa JDK/Maven configurados e fixture local;
demais integracoes usam os doubles existentes. Sem novo ensaio nativo Copilot:
a qualidade das fichas/referencias geradas ainda deve ser conferida no cliente.
Recibos/rankings da maquina de trabalho nao foram regravados; a continuacao v2
foi validada com fixtures sinteticas. Estas verificacoes precedem a publicacao.

Revisao de autonomia/legibilidade: guia existente atualizado, README e roteiro
principal com entrada sem helper, planejamento/implementacao manuais explicitos.
Ficha em quatro blocos, tabela curta, exemplo ficticio e IDs preservados nas
referencias/JSON/linha copiavel. Helper encaminha conforme intencao manual ou
assistida. Revisao independente encontrou um encaminhamento residual para chat
na revisao manual; corrigido e conferido, sem outros achados materiais.
Apos essas alteracoes, Test-Prioritization.ps1 e Test-PrioritizationProgress.ps1
passaram em Windows PowerShell 5.1; 267 links/ancoras locais em 15 Markdown validos
(excluidos exemplos em blocos de codigo), em `links-legibilidade.json` na area
de evidencias acima. Diff sem erros de whitespace. Conferencia estatica do helper
e formato; a qualidade do relatorio produzido no cliente permanece por ensaiar.

Publicacao e alinhamento solicitados pelo mantenedor: commit/push, PR para main
e fast-forward de main_jboss_eap74. Conferencia previa: principais locais/remotas
em `4cf9335`, nenhum PR aberto e regra de main ativa, com excecao do mantenedor
somente por PR. Registrar o resultado em
`.harness/tests/priorizacao-cobertura-20261005/encerramento.json`, apos conferir
merge, igualdade das refs locais/remotas, conteudo revisado e checkout limpo.

## Guia proprio de orientacao e padrao por etapa - 2026-10-05

- [x] Conferir raiz, branch, HEAD e estado limpo; mapear secoes e referencias.
- [x] Criar guia central e ligar README, desenvolvedor e Workspace.
- [x] Padronizar os sete guias operacionais, com exemplos por etapa e resultado esperado.
- [x] Atualizar mapa da skill e convencao de manutencao; preservar links antigos.
- [x] Validar links/ancoras, oito etapas, limites dos helpers e revisao documental.

Verificacao: 14 documentos, 346 links/ancoras locais validos e 151 ancoras
anteriores dos guias preservadas; sete guias com as quatro secoes padrao e
oito etapas no mapa central. Revisao independente sem achados materiais.
`git diff --check` sem erros. Evidencia local em
`.harness/tests/guias-orientacao-20261005/validacao-documental.json`.
Sem execucao de runtime ou novo aceite de descoberta/delegacao nas extensoes.
O mapa da skill mudou somente as referencias; scripts/permissoes preservados.

Publicacao e alinhamento solicitados pelo mantenedor: commit/push, PR para main
e fast-forward de main_jboss_eap74. Conferencia previa: checkout limpo, principais
em `95dff4a`, nenhum PR aberto e regra de main ativa, com excecao somente por PR.
Registrar o encerramento em `.harness/tests/guias-orientacao-20261005/encerramento.json`,
apos conferir merge, refs locais/remotas, conteudo revisado e limpeza da branch.

## Publicacao e alinhamento da conciliacao - 2026-10-05

- [x] Confirmar pedido do mantenedor, checkout limpo e principais locais/remotas
  em `d48cf6a`; nenhum PR aberto e somente este worktree.
- [x] Revisar `082f581` e `287f6fb`: apenas documentacao, revisoes independentes
  sem achados; links/ancoras conferidos e diff sem erros de espacos indevidos
  (quebras Markdown do documento recebido preservadas).
- [x] Conferir regra ativa: PR, aprovacao/CODEOWNERS e excecao administrativa
  somente por PR; sem liberacao de push direto em main.

Sequencia autorizada: publicar o PR, conferir a revisao exata, integrar, alinhar
as principais e remover a branch integrada. Evidencia final local prevista em
`.harness/tests/integracao-capacidades-20261005/encerramento.json`.
Esta integracao documental nao concede aceite de migracao nem de pilotos futuros.

## Referencia explicita a orientacao no guia principal - 2026-10-05

- [x] Conferir raiz, branch e estado limpo em `082f581`; comparar o guia principal
  com o passo a passo de Workspace.
- [x] Explicar skill, papel do helper, entradas Codex/Copilot e primeiro pedido;
  destacar o guia especifico e preservar orientacao, execucao e decisao humana.
- [x] Revisar diff e conferir links/ancoras dos documentos alterados: 107
  referencias locais validas nos tres documentos; `git diff --check` sem erros.

## Conciliacao das evolucoes futuras - 2026-10-05

Escopo: [plano desta entrega](plan.md#conciliacao-das-evolucoes-futuras---2026-10-05).

- [x] Conferir raiz, main `d48cf6a` e estado local; preservar a proposta recebida
  e criar `harness/conciliacao-evolucao-capacidades`.
- [x] Comparar catalogo, backlog vigente, estrategia e ADRs, incluindo entregas
  posteriores a baseline da proposta.
- [x] Registrar correspondencias, escopos superados e propostas adicionais.
- [x] Atualizar referencias e separar retomadas historicas de pendencias atuais.
- [x] Revisar documentos e validar links, IDs e preservacao do texto original.

Prazo, prioridade e piloto permanecem a definir pelo desenvolvedor. Esta entrega
nao implementa capacidades nem encerra VAL-01/02/03 por revisao documental.

Verificacao: 8 documentos, 136 links/ancoras locais validos; 23 capacidades
relacionadas uma vez na matriz e 23 prioridades escolhidas ainda `A definir`.
Revisao independente sem achados materiais; sem execucao de runtime nesta entrega.
Texto recebido preservado, exceto a nota de incorporacao: ao retirar essa nota e
normalizar finais de linha, o SHA-256 confere com o original
`be1195f7b168e48d4ddd7a40296a7ef7ef5b25cb43de13e476c30754b57c4a13`.
Quebras Markdown com dois espacos do documento recebido foram preservadas.

## Integracao e limpeza apos PR 2 - 2026-10-05

- [x] Confirmar PR 2 integrado, main protegida e CODEOWNERS presente na base.
- [x] Conciliar plan/to-do ao incorporar main na branch de priorizacao.
- [x] Validar a base integrada: Test-Prioritization, Test-PrioritizationProgress,
  Test-Workspace e Test-TaskInputs passaram; sintaxe e 230 links locais validos.
- [x] Mantenedor aprovar o merge do [PR 3](https://github.com/edoardo-bianco/jboss-mta-harness/pull/3),
  o alinhamento de main_jboss_eap74 e a limpeza: autorizacao explicita no chat.
- [x] Remover branches locais/remotas ja integradas de licenca e backlog, e o
  worktree limpo da licenca, apos conferir ancestralidade e ausencia de pendencias.

Encerramento autorizado: integrar PR 3 por merge, avancar main_jboss_eap74 a main,
retornar o checkout a main e remover a branch integrada de priorizacao. Conferir
refs locais/remotas, unico worktree, protecao e status limpo; evidencia final em
.harness/tests/integracao-priorizacao-20261005/encerramento.json. Nenhum dado local
de ferramentas nem o playground externo entra nessa limpeza Git.

Revisao da conciliacao: runtime identico ao commit 5f7cfdd; apenas licenca,
CODEOWNERS e documentacao recebidos de main. Conflitos limitados a plan/to-do,
consolidados sem descartar evidencias de nenhuma entrega. A revisao independente
anterior permanece aplicavel. Logs em .harness/tests/integracao-priorizacao-20261005/.

## Playground externo e priorizacao percentual - 2026-10-05

Escopo autorizado no [plano](plan.md#playground-externo-e-priorizacao-percentual---2026-10-05).
O preparo anterior do ensaio 02 foi substituido pelo reinicio sem historico do playground.

- [x] EXT-01: workspace/config sem exemplos; fixtures independentes. Verificar
  Test-Workspace e Test-TaskInputs; nenhuma ferramenta local alterada.
- [x] PCT-01: percentual validado, inventario por Source/ID e quota arredondada.
  Verificar Test-Prioritization, incluindo 0,01/100,00 e valores invalidos.
- [x] PCT-02: recriar/progredir/retomar, base fixa e exclusao acumulada de propostas.
  Verificar sequencia 200/10%, arquivos incompletos, ambiguidade e isolamento.
- [x] PCT-03: menu/CLI, prompt, contrato, instrucoes e guias coerentes. Verificar
  testes de entrada real, JSON, editor, cancelamento e links afetados.
- [x] EXT-02: mover antes, remover depois e zerar dados locais desses playgrounds.
  Verificar inventario de caminhos, hashes dos fontes e ausencia de vinculos ativos.
- [x] VAL-02: revisao de codigo/documentos e regressao final; registrar evidencias.
  Novo ensaio nativo e novas analises da aplicacao ficam para apos sua importacao.
- [x] DOC-03: conferir README, guia de pre-planejamento, skill comum e perfis;
  corrigir lacunas de exemplos externos, encaminhamento e manutencao. Verificar
  links, quick_validate da skill e diff documental, sem alterar runtime.

Complemento documental: README e guia de manutencao deixaram de anunciar exemplos
internos; skill comum agora distingue recriacao de priorizacao da revisao de plano,
orienta percentual/base fixa e importacao externa. Guia de pre-planejamento e papeis
reconferidos; seis perfis de cada cliente reutilizam a skill e suas referencias.
228 destinos de links locais, seis perfis TOML, quick_validate.py e diff aprovados.
O validador usou o Python instalado e PyYAML isolado pelo uv; nenhuma dependencia
foi adicionada ao harness. Nenhum teste de runtime repetido nesta mudanca documental.

Licenca e protecao foram integradas pelo mantenedor no
[PR 2](https://github.com/edoardo-bianco/jboss-mta-harness/pull/2), merge 0921b6e,
com regras remotas ativas (24499809) e CODEOWNERS na main. A evolucao percentual
segue em PR separado; a conciliacao atual preserva ambos os resultados.

Validacao em 2026-10-05: 36 scripts Test-*.ps1 passaram em Windows PowerShell 5.1;
Test-JbossReal foi SKIP (exige RunReal, nao acionado). A primeira chamada generica
de Test-BuildCoverage omitiu parametros obrigatorios; a chamada corrigida encontrou
bloqueio de rede do sandbox. Reexecucao autorizada com JDK/Maven da maquina passou:
20% JaCoCo gera warning sem reprovar; falhas intencionais de teste/compilacao mantem
exit de erro. Nenhum build/MTA novo foi feito no playground externo.

Evidencias locais: .harness/tests/validacao-percentual-20261005-080325/results-final.json
(preserva referencia a tentativa inicial) e .harness/tests/coverage-178e86d32cf74ece8172a05d4222c7d9/.
Sintaxe dos scripts/testes, 142 destinos de links locais e git diff --check passaram.
Revisao independente de codigo e documentos sem bloqueantes; testes adicionais
cobrem pontas ambiguas, sucessor unico, Source/ID, ranking ancestral alterado e
arrays invalidos. Precisao textual de EXHAUSTED e de issues disponiveis corrigida.

Movimentacao conferiu SHA-256 identico dos nove arquivos versionados de ANTES no
destino C:/desenvolvimento/repositorio/migracao-cache-antes. DEPOIS e target antigo
removidos. Dados locais do playground removidos: builds/runs, registros/indices,
arquivo local do ensaio 01 e C:/mta-runs/migracao-cache-antes. Planning/priorizacao
ativos estavam vazios. Config/workspace locais ficaram sem exemplos; ferramentas
e configuracoes de servidor preservadas. Nenhum novo registro/indice foi criado;
o desenvolvedor importara o playground e iniciara a nova analise.

## Licenca MIT e protecao de main - 2026-10-05

- [x] Conferir MIT da referencia, conta administradora, branch e visibilidade.
- [x] Preparar LICENSE em nome de Edoardo Bianco, CODEOWNERS e documentacao.
- [x] Validar texto da licenca, referencias e diff: MIT identica a referencia,
  alterando apenas ano/titular; 68 destinos de links locais validos.
- [x] Ativar e conferir regras de main e excecao administrativa somente via PR.
  Ruleset 24499809 ativo; API confirma main protected=true, sem alterar seu SHA.
- [x] Mantenedor revisar e integrar o PR da licenca/CODEOWNERS: PR 2, merge 0921b6e.

Sem mudanca de runtime, sem novos testes de aplicacao. CODEOWNERS agora esta na
main; o merge foi realizado pelo mantenedor e confirmado na API.

## Validacao para integracao nas principais - 2026-10-04

Commit e push autorizados pelo desenvolvedor em main e main_jboss_eap74, nesta
ordem de integracao. Fetch confirmou ambas em de59750, ancestrais de 4ff6c68,
com nove commits exclusivos da branch harness/backlog-agente-orientacao e
nenhum exclusivo das principais. Um checkout, preservado na branch de trabalho.

- [x] Revisao independente do diff documental: relato e discussao arquivados
  integralmente, links/ancoras preservados, sem achados impeditivos.
- [x] Conferir SHA-256 dos 34 arquivos arquivados e 25 entradas preservadas.
- [x] Reexecutar Test-PlanningEvidence, Test-Implementation e Test-TaskInputs:
  PASS em Windows PowerShell 5.1, com ExecutionPolicy Bypass somente no processo.
- [x] Conferir git diff --check e ausencia de alteracoes em exemplos entre as
  principais e a entrega; .harness e configuracao local continuam fora do commit.

As auditorias anteriores dos scripts permanecem registradas abaixo. A entrega
mantem SIM-14/VAL-01 e E02-P01 abertos, sem inferir ensaio nativo, corretiva ou
aceite da aplicacao. A recomendacao historica de aguardar o ensaio foi sucedida
pelo pedido atual de integracao; as pendencias tecnicas/documentais continuam visiveis.

## Ensaio 02: fluxo simplificado - 2026-10-04

Estado historico: PREPARADO PARA INICIAR em 2026-10-04; substituido em 2026-10-05
pelo reinicio do playground externo, descrito no inicio deste arquivo. Nenhuma
resposta dos clientes foi avaliada nesta rodada.
Base: 4ff6c68, publicada em origin/harness/backlog-agente-orientacao.
Workspace: jboss-mta-harness.local.code-workspace. Clientes: Codex e GitHub Copilot.

O ensaio 01 esta encerrado e sua coleta foi
[arquivada](ensaio-helper-01-historico.md); ENS-01 a ENS-17 continuam como
rastreabilidade das corretivas, sem serem pendencias de implementacao novamente.
Esta rodada verifica SIM-14/VAL-01 sobre o fluxo corrigido. Resultados anteriores
nao contam automaticamente como aprovacao da nova rodada.

- [x] Arquivar o relato e a discussao do ensaio 01, mantendo os links de retomada.
- [x] Conferir base publicada e inventariar os artefatos locais anteriores.
- [x] Reiniciar pela priorizacao, restaurando os registros sem escolhas do ensaio 01.
- [ ] Codex: pedido curto recupera contexto e orienta somente a proxima acao.
- [ ] Copilot: mesmo pedido produz orientacao equivalente no cliente correto.
- [ ] Conferir escolha/Decisao versus Andamento e sobreposicao sem selecao automatica.
- [ ] Conferir Planejar sem menus redundantes e retomada sem repetir escolhas.
- [ ] Conferir perguntas essenciais e uso de evidencias, sem PENDENTE generico.
- [ ] Validar apoio real dos helpers quando pertinente, preservando papel leitor.
- [ ] Consolidar resultados/ajustes antes de iniciar executores novos.

Estado inicial conferido: migracao-cache-antes tem duas issues mandatory, ambas
A DEFINIR / NAO ANALISADA, com observacoes vazias. Origem preservada: RunId
161c1bd4ce7a4da78641091c58557e44. migracao-cache-depois permanece AGUARDANDO MTA.
Indice regenerado com os registros atuais. Nenhum ranking, prompt ou plano antigo
permanece em .harness/priorizacao/ ou .harness/planning/.

Historico local permanente: .harness/ensaios/ensaio-01-2026-10-04/, com LEIA-ME.md
e inventario.json. Conferidos SHA-256 dos 34 arquivos arquivados e das 25 entradas
preservadas (arquivos versionados dos exemplos, configuracao/workspace e cinco
artefatos MTA). Arquivo historico e recibos preservados byte a byte; caminhos
absolutos antigos registram a origem, nao a localizacao atual do arquivo.
Builds e rodadas anteriores continuam como evidencias de entrada, sem contar como
execucao/aceite do ensaio 02. Nao houve corretiva ou nova execucao da aplicacao.

Primeira mensagem no novo chat Codex, no workspace do ensaio:

```text
$orientar-migracao Quero iniciar pela priorizacao de issues mandatory dos projetos deste workspace. Me conduza uma etapa por vez.
```

O desenvolvedor retorna a resposta do helper antes da proxima etapa. O pedido curto
testa a recuperacao de contexto sem exigir caminhos, IDs ou instrucoes adicionais.

Achado de preparacao E02-P01 (scripts/HarnessProjectIndex.psm1:408): em Como
interpretar o indice, o texto gerado ainda
diz que a tarefa carrega o ultimo MTA e prepara/reutiliza prompts. Contradiz o
cabecalho e o comportamento atual, que preservam registros existentes e nao
preparam reconciliacao automaticamente. Corretiva textual a tratar na consolidacao;
nao e resultado de execucao de Codex/Copilot nem motivo para reconciliar o registro.

Registro de eventos dos clientes: usar E02-01, E02-02 etc., anotando cliente, pedido curto,
resposta/arquivo/log realmente fornecido, comportamento esperado, observado e ajuste.
Ainda nao ha eventos de execucao nesta rodada. Preparar contexto nao e executar o
agente; encerrar este ensaio nao concede GO ou aceite de corretiva da aplicacao.

## Auditoria documental e risco de integracao - 2026-10-04

- [x] Auditar README, guias, contrato, ADRs, prompts, skill e perfis em dois recortes
  independentes; conferir tarefas visiveis e comparar com os scripts.
- [x] Corrigir os sete achados dos revisores e obter reconferencia dos trechos.
- [x] Conferir precedencia da ADR-0005 nas ADRs anteriores e atualizar panorama dos
  dois clientes nos documentos de estrategia e testes no guia de manutencao.
- [x] Validar links locais, JSON das tarefas, diff e testes pertinentes.
- [x] Consultar o remoto somente em leitura e registrar limites/recomendacao abaixo.

Achados corrigidos sobre a base 2c6b6e6:

| Achado | Correcao |
| --- | --- |
| Descricao da tarefa de indice prometia adotar o ultimo MTA e impunha prompts pendentes | Descricao alinhada a criacao/localizacao, escolhas/origem preservadas e avisos. |
| Pos-limpeza ainda mandava escolher menu p | Guia usa registro; distingue restauracao de preparo e reconstrucao explicita com NewPlan, sem recuperar GO/aceite perdido. |
| Tarefa/terminal de implementacao orientavam apenas Copilot | Mensagem pronta para Codex e instrucao especifica do Copilot, preservando GO. |
| Saida da configuracao omitia planejamento por evidencias | Dois encaminhamentos diretos para registrar issue/evidencias e Planejar. |
| Contrato mandava manter todo aceite PENDENTE | Preservar aceite vigente do mesmo resultado; resultado alterado exige avaliacao. |
| Edicao de evidencias e edicao de plan/to-do/GO tinham mesmo encaminhamento | Base alterada volta a Planejar/Previous; documentos/GO com base vigente atualizam preparo de implementacao. |
| Contrato impunha delegacao, templates admitiam apoio indisponivel | Delegacao condicionada a disponibilidade/compatibilidade, com conducao direta no escopo autorizado. |

Auditoria_guias e auditoria_codigo confirmaram as respectivas correcoes sem novos
achados nos trechos; nao executaram ferramentas da aplicacao. O README e a jornada
principal ja distinguiam escolha, proposta, GO, execucao e aceite. A recuperacao
apos limpeza ganhou instrucoes especificas porque os links antigos podem continuar
no registro mesmo apos excluir os recibos; nada foi apagado dos registros reais.

Verificacoes novas desta auditoria: 317 links locais em 38 Markdown de README,
AGENTS, doc, .agents e .github, sem destino/ancora ausente; links externos nao foram
revalidados. Test-TaskInputs, Test-Implementation e Test-PlanningEvidence: PASS em
Windows PowerShell 5.1 com ExecutionPolicy Bypass apenas no processo de teste.
git diff --check sem erros. As 13 suites da entrega anterior continuam registradas
na secao seguinte; nao foram todas repetidas para alteracoes de texto/encaminhamento.

Estado Git observado antes das corretivas documentais: main e main_jboss_eap74
locais e remotas em de5975096d0848b91b0d45aad00d291787a89bb3; HEAD 2c6b6e6 com oito
commits exclusivos e zero commits exclusivos das principais. Consulta real:
git ls-remote --heads origin; remoto so possui aquelas duas branches. Um worktree,
na branch do harness. Diff de exemplos entre principais e HEAD vazio; .harness,
config/harness.local.json e workspace local nao sao versionados.

Risco de conflito Git baixo no estado observado: principais podem avancar sem
reescrever historico. Isso nao comprova comportamento dos clientes nem autoriza
integracao. Recomenda-se publicar primeiro a branch de trabalho, concluir o ensaio
nativo e integrar a evolucao aceita em main; depois, etapa explicita para EAP 7.4.
Consultar novamente o remoto antes da integracao e recusar divergencia em vez de
forcar branches. Nenhum push, merge, reset ou alinhamento foi executado nesta auditoria.

## Simplificacao da conducao da migracao - 2026-10-04

Ensaio interrompido a pedido do desenvolvedor para consolidar os ajustes antes de
prosseguir. Implementacao SIM-01 a SIM-13 realizada; novo ensaio nativo fica para
o desenvolvedor apos a auditoria e regressao desta entrega.
Detalhes, dependencias, arquivos, aceite e verificacoes no
[plano de simplificacao](plan.md#plano-consolidado-simplificar-a-conducao-da-migracao---2026-10-04).
Preservar a branch harness/backlog-agente-orientacao e os artefatos do ensaio.

Rastreabilidade: 14 entregas entre plano/checklist e 17 achados registrados.
Scripts, templates, helpers e guias foram ajustados. Verificacoes desta implementacao
estao registradas abaixo; sucesso de testes nao substitui o ensaio nativo.

- [x] Consolidar ENS-01 a ENS-17 e conferir o fluxo atual no codigo, sem executar
  o planejamento da aplicacao nem alterar scripts, prompts, guias ou perfis.
- [x] Definir entrada direta Planejamento: planejar; registro ausente direciona
  Workspace: atualizar indice dos projetos. Reconciliacao exige motivo concreto.
- [x] Planejar base por evidencias sem pacote MTA completo e perguntas essenciais
  antes de concluir proposta/to-do, preservando escolha humana e GO separado.
- [x] SIM-01: unificar contrato, ADR complementar e instrucoes comuns.
- [x] SIM-02: resolver registro, identidade, escolha e referencias antes do preparo.
- [x] SIM-03: preparar pela origem MTA registrada, sem trocar catalogo ou repetir escolhas.
- [x] SIM-04: preparar contexto por evidencias, sem inventar rodada/categoria MTA.
- [x] SIM-05: adaptar historico, retomada e fases seguintes aos dois modos de contexto.
- [x] SIM-06: alinhar indice/manutencao e avisos; impedir troca implicita de base.
- [x] Marco A: conferir compatibilidade MTA/legados e percurso por evidencias.
- [x] SIM-07: entregar Planejamento: planejar sem menu de operacoes; pedir registro
  somente quando houver ambiguidade real; fornecer encaminhamento pronto se faltar preparo.
- [x] SIM-08: adequar planejamento/reconciliacao/revisao a perguntas essenciais e
  retomada da mesma solicitacao, sem pendencias genericas ou proposta ficticia.
- [x] SIM-09: adaptar acionamento ao cliente e ranking com links/instrucoes de escolha.
- [x] SIM-10: alinhar prompts de implementacao/revisao, evidencias funcionais e JaCoCo 85%.
- [x] SIM-11: orientar uma etapa por vez com helper, contexto recuperado e caminho pronto.
- [x] SIM-12: corrigir README, guia do desenvolvedor e guia de planejamento.
- [x] SIM-13: harmonizar guias de workspace/helper, priorizacao e MTA.
- [x] Marco B: conferir coerencia entre entrada, scripts, prompts, helpers e guias.
- [ ] SIM-14: executar regressao pertinente e retestar manualmente nos dois clientes;
  concluir VAL-01 antes de novos executores SDLC-04/05.
  Implementacao e verificacoes automatizadas realizadas; comportamento/delegacao
  no Codex e no Copilot ainda requerem o novo ensaio acompanhado.

Rastreabilidade dos achados (cada SIM tem aceite/testes no plano):

| Achados | Entregas principais |
| --- | --- |
| ENS-01, ENS-10 | SIM-07, SIM-11, SIM-12, SIM-14: proxima acao unica e retomada curta. |
| ENS-02, ENS-12 | SIM-01, SIM-06, SIM-08, SIM-11: reconciliacao por necessidade concreta. |
| ENS-03, ENS-05, ENS-07, ENS-11 | SIM-09, SIM-11, SIM-13, SIM-14: cliente, acionamento e apoio real. |
| ENS-04, ENS-06 | SIM-04, SIM-06, SIM-09: lacunas proporcionais e avisos por projeto. |
| ENS-08, ENS-09 | SIM-02, SIM-09, SIM-13: escolha por campo e vinculo entre issues. |
| ENS-13, ENS-14 | SIM-02 a SIM-07: registro como entrada, origem estavel e compatibilidade. |
| ENS-15 | SIM-01, SIM-08, SIM-10 a SIM-14: governanca assistida e documentos coerentes. |
| ENS-16 | SIM-01, SIM-04, SIM-05, SIM-08, SIM-10: evidencias e perguntas antes da proposta. |
| ENS-17 | SIM-06, SIM-07, SIM-11, SIM-12: somente Planejar na entrada habitual. |

### Implementacao e auditoria da simplificacao

Entrada habitual entregue: **Planejamento: planejar**, sem selecao repetida de
operacao ou rodada. Um registro elegivel e resolvido automaticamente; varios exigem
uma escolha. Registro ausente direciona a atualizar o indice. A base vinculada e
preservada; MTA novo exige manutencao explicita. Evidencias sem rodada usam contexto
EVIDENCIAS, inclusive nas fases seguintes, sem inventar metadados MTA.

Preparos iguais sao reutilizados. Mudanca de origem, evidencias, contrato ou template
produz sucessor com Previous, inclusive se a base anterior ainda nao tinha plano.
Referencias antigas seguem essa linhagem; bifurcacoes reais exigem escolha. Prompts
pedem somente decisoes essenciais antes da proposta, e helpers entregam uma proxima
acao pronta no cliente atual. A escolha atual prevalece sobre o PENDENTE historico.

Auditoria independente por auditoria_codigo, em leitura, seguida de corretivas:
lock da carga inicial; registro vazio inicialmente criado pela configuracao; origem
MTA malformada/ambigua; links com %20; identidade do registro no recibo; Previous
incompleto; vinculos das issues escolhidas; atualizacao de contrato/template.
Reauditoria acrescentou retomada explicita idempotente e paridade de validacao
PreviousRequestId/NewPlan na CLI JSON; ambos corrigidos com testes. A reabertura de
IMPLEMENTADA/VERIFICADA preserva andamento e exige direcao humana na execucao,
sem um bloqueio de preparo que obrigue falsificar o status.

Verificacoes desta entrega: 13 suites PASS em Windows PowerShell 5.1, fixtures .harness/tests:

- Test-PlanningEvidence: MTA vinculado versus mais recente; EVIDENCIAS; retomada
  implicita/explicita; Previous; hashes; conflitos; identidade; lock; reabertura;
  instrucoes dos dois clientes, entrada CLI real e resposta JSON sem escrita quando
  reutilizada; varios registros, referencias de issues adiadas e seletores conflitantes: PASS.
- Test-Planning, Test-PlanningPortable, Test-PlanningCli, Test-MigrationRegister,
  Test-Prioritization, Test-Implementation e Test-ImplementationBranch: PASS.
- Test-ProjectIndex, Test-ExternalMtaDiscovery, Test-TaskInputs, Test-Workspace e
  Test-Cleanup: PASS; limpeza inclui planejamento EVIDENCIAS e preserva origens externas.
- Comando: powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests/Test-<nome>.ps1.
  Bypass limitado ao processo do teste, sem alterar a politica da maquina.
- Sintaxe PowerShell dos 18 scripts alterados, formatos TOML/frontmatter, referencias
  locais e git diff --check conferidos. quick_validate.py da skill continua sem
  PyYAML; nenhuma dependencia instalada para esse validador auxiliar.

O codigo de build/cobertura nao foi alterado; a politica JaCoCo 85% com aviso foi
preservada nos templates. Test-BuildCoverage nao foi repetido nesta entrega.
Nao foram executados agentes de planejamento/corretiva sobre a aplicacao real,
build/deploy da aplicacao, nem alterado o DevSquad instalado ou artefatos do ensaio.
SIM-14/VAL-01 continuam abertos somente para o novo ensaio humano no Codex/Copilot:
uma etapa por vez, retomada curta, acionamento correto, perguntas pertinentes e
delegacao real quando necessaria. A cobertura de ENS-01 a ENS-17 nao e declaracao
de que os dois clientes ja foram validados depois destas alteracoes.

## Pre-planejamento: priorizar issues - 2026-10-04

- [x] Preparar contexto multi-projeto sem modificar indice/registros/evidencias.
- [x] Entregar prompt top 5..10 por risco, repetibilidade, alcance e confianca.
- [x] Integrar Run Task, helpers, guia especifico e entrada no guia do desenvolvedor.
- [x] Testar isolamento, historico, identidades, lacunas e regressao; revisar diff.
  Test-Prioritization, Test-MigrationRegister, Test-ProjectIndex, Test-Planning,
  Test-PlanningPortable, Test-PlanningCli, Test-TaskInputs e Test-Workspace
  passaram em Windows PowerShell 5.1. TOML e referencias locais conferidos;
  frontmatter da skill preservado e corpo revisado. quick_validate.py nao executou
  por ausencia de PyYAML; nenhuma dependencia instalada para esse check auxiliar.
- [ ] Validar manualmente priorizacao e passagem da escolha humana ao planejamento.
  Usar o [guia especifico](../doc/guias/tools/priorizacao-issues.md#validacao-manual),
  incluindo qualidade das amostras/contagens e delegacao real dos helpers.

### Ensaio acompanhado do helper no Codex - 2026-10-04

Rodada encerrada; coleta ENS-01 a ENS-17 e discussoes preservadas no
[historico do ensaio 01](ensaio-helper-01-historico.md). As corretivas e sua auditoria
foram entregues; o novo ensaio confere o comportamento nos clientes atualizados.
A validacao nativa completa e o aceite da aplicacao nao foram inferidos do encerramento.

## Ajuste dos prompts ao contexto preparado - 2026-10-04

- [x] Conferir branch harness/backlog-agente-orientacao, HEAD 39c96b8 e checkout limpo.
- [x] Ajustar selecao por issue/etapa, indice, evidencias e recomendacao MTA.
- [x] Consolidar plano/to-do e preparar revisao do resultado sem nova Run Task.
- [x] Definir JaCoCo 85% do recorte corrigido com aviso, separado do Sonar global.
- [x] Alinhar guias e validar geradores, preservacao/retomada e diff.
  Test-Planning, Test-Implementation, Test-PlanningCli, Test-PlanningPortable,
  Test-ProjectIndex, Test-ImplementationBranch e Test-TaskInputs passaram em
  Windows PowerShell 5.1. Test-BuildCoverage real passou com meta 85%, cobertura
  20%/aviso/exit 0 e falhas intencionais de teste/compilacao preservadas.
  Evidencias: .harness/tests/coverage-5bba2f1f4a9a4b1a905bcd7c69953c43.
  Restricao de rede inicial resolvida pela execucao autorizada fora do sandbox;
  Maven/cache/settings da maquina preservados. Revisao do diff sem bloqueantes.
- [ ] Validar manualmente prompts e helpers/delegacao nos clientes apos esta entrega.

## Trabalho atual: backlog e squad de migracao - 2026-10-03

- [x] Reconciliar backlog com entregas posteriores e preservar historico.
- [x] Revisar quatro prompts; corrigir uso do contrato preservado em revisar-lote.
- [x] Consolidar modos, papeis, acoes, matriz por projeto e capacidades opcionais.
- [x] Conferir proposta com ADRs/contrato/estrategia e fontes oficiais pertinentes.
- [x] Validar consolidacao final, referencias e limites com revisao independente.
- [x] Entregar SDLC-01: CLI sem menus, validacao previa, JSON e rastreio protegido por lock.
- [x] Confirmar prioridade: ferramentas atuais, depois squad completa de helpers, antes dos executores.
- [x] Entregar SDLC-02: skill compartilhada de orientacao, guias de uso e ensaios de leitura do contexto.
- [x] Implementar SDLC-03: orquestrador e cinco helpers com entradas Codex/Copilot e metodo comum.
- [ ] Concluir VAL-01: descoberta e delegacao nativas nas duas extensoes antes dos executores.

Decisoes, responsabilidades, fontes e verificacoes ficam no
[plano consolidado](plan.md#trabalho-atual-backlog-e-squad-de-migracao---2026-10-03).
Este arquivo concentra estado e ordem das entregas; os guias mantem os procedimentos.
Os perfis da squad helper estao no repositorio; validacao nas extensoes, executores,
novos coletores e preparo automatizado de servidor permanecem pendentes.

### Ponto de retomada - 2026-10-04

Registro historico: o ensaio 02 estava preparado em 04/10. O playground foi
externalizado e reiniciado em 05/10; o estado atual das pendencias esta no
[backlog vigente](#backlog-vigente) e na [conciliacao](../doc/estrategia/conciliacao-evolucao-harness.md).
Simplificacao SIM-01 a SIM-13 implementada e auditada; SIM-14/VAL-01 sao verificados
na nova rodada, mantendo o ensaio 01 arquivado.
Os ajustes anteriores de prompts/priorizacao ja foram implementados; preservar
essas entregas. O [registro de retomada e diagnostico](plan.md#retomada-apos-a-pausa-de-2026-10-03)
permanece historico. A branch `harness/backlog-agente-orientacao` foi integrada e
removida; nao e destino de retomada. A validacao nativa permanece pendente.

- [x] Atualizar diagnostico pelo relato humano: Copilot aparentemente voltou apos desativar o MCP do Azure; causa exata nao confirmada. Investigar novamente se a falha reaparecer, sem exigir isolamento previo do DevSquad.
- [ ] Retestar orientacao do `migracao_helper` no Copilot apos SIM-11/13, conferindo fontes e ausencia de escrita; o chat ja respondeu no evento 9.
- [x] Confirmar descoberta de `orientar-migracao` no Codex do VS Code: desenvolvedor informou que ja aparece.
- [ ] Retestar orientacao e validar delegacao no Codex com a skill ja disponivel apos SIM-11/13; reconhecimento da escolha observado no evento 10.
- [ ] Completar VAL-01 nos dois clientes antes dos executores. Testes simulados nao substituem essa validacao.

## Backlog vigente

Conciliado em 2026-10-05 com o [catalogo de capacidades](../doc/features/evolucao-harness-dominios-capacidades-priorizacao.md).
A [matriz de correspondencias](../doc/estrategia/conciliacao-evolucao-harness.md)
relaciona todas as frentes e as 23 capacidades, incluindo sobreposicoes e lacunas
ja atendidas. IDs anteriores permanecem rastreaveis; capacidades detalham demandas,
sem duplicar entregas. Novas prioridades, datas e pilotos continuam a definir.
As dependencias de validacao ja registradas permanecem; nao fixam uma ordem global.

| ID | Estado / ordem | Proxima entrega |
| --- | --- | --- |
| SIM-01 a SIM-14 | SIM-01 a SIM-13 implementadas; regressao PASS | Novo ensaio nativo SIM-14/VAL-01 nos dois clientes antes de novos executores. |
| SDLC-01 | Concluida | Preparo de planejamento/reconciliacao por CLI com escolhas explicitas, validacao antes de escrita e saida estruturada. |
| SDLC-02 | Concluida | Skill compartilhada de orientacao pelo estado efetivo e pelos guias. |
| SDLC-03 | Implementada; aguarda VAL-01 | Orquestrador helper e helpers de preparo, reconciliacao, planejamento, impacto e implementacao; inclui orientacao da priorizacao entre projetos. Humano executor nos dois clientes. |
| SDLC-04 | Apos SDLC-03 / VAL-01 | Orquestrador executor e especialista de preparo; modo delegado e retorno ao humano. |
| SDLC-05 | Apos SDLC-04 | Executores das demais etapas, reutilizando os helpers ja entregues; consumir matriz COMP-01 e coleta Java opcional. |
| SDLC-06 | Conforme necessidade | Adequar uma acao existente por vez: branch explicita, Sonar assistido, build/MTA/JBoss e limpeza. |
| COMP-01 | Capacidade solicitada; detalhada por DEP-01/02 | Coletor deterministico Maven e matriz por projeto: compatibilidade, fontes, pendencias e acao recomendada, sem alterar POM. DEP-03 e extensao a avaliar separadamente. |
| CORE-01 | Piloto opcional transversal; detalhado por SRC | Navegacao/coleta de contexto Java independente de MTA/engine, principalmente SRC-01/03/06. SRC-02/04/05 ampliam opcoes, sem se tornarem requisitos do primeiro piloto. Adaptador ainda a escolher. |
| SERV-01 | Capacidade solicitada; detalhada por JBS-01..05 | Inventario, rota comprovada, assistencia, transformacao de configuracao e validacao no destino isolado. Reutilizar operacoes existentes; nao duplicar a demanda nem declarar rota 7.1 direta suportada. |
| VAL-01 | Ensaio parcial interrompido para simplificacao; eventos 9/10 | Uso da skill e reconhecimento da escolha demonstrados no material trazido pelo desenvolvedor; reconciliacao primeiro sem conflito apontado nos dois clientes, Codex direcionou execucao ao Copilot. Delegacao ainda nao validada. Retestar em SIM-14: orientacao/delegacao, capacidades presentes/ausentes/inadequadas e ausencia de efeitos operacionais; casos do plano. |
| VAL-02 | Ensaio operacional existente pendente | Prompts Copilot: reconciliacao/delegacao, issues, persistencia, retomada, GO, implementacao e continuidade com Previous/novo MTA. |
| VAL-03 | Ensaio Sonar real pendente | Criterios Blocker/High, avisos de cobertura e comparacao com baseline, separados do Quality Gate. |
| DEC-01 | Decisao futura | Decidir preparo de deploy com servidor parado; deploy atual exige servidor ativo. |
| EVO-01 | Futuro, apos priorizacao | Demais fatias da estrategia: nucleo, Node.js/TypeScript, IntelliJ, Quarkus, outros engines e entrega/operacao. Relacionar HAR-04 e demais propostas novas do catalogo, sem considerar todos os incrementos ja aprovados. |

Criterios, dependencias e arquivos por fatia estao na
[sequencia de implementacao](plan.md#sequencia-e-verificacao). COMP-01 e independente
do explorador CORE-01; ambos fornecem evidencias, sem ampliar ferramentas do
planejador atual. SERV-01 nao e deploy offline nem autorizacao para migrar o EAP
local. A orientacao e a entrada pelo registro ja contemplam Codex e Copilot,
conforme ADR-0005; isso nao comprova delegacao/execucao nativa. VAL-01/02 preservam
os ensaios ainda necessarios. O item VAL-02 concluido na secao de priorizacao
percentual e uma verificacao daquela entrega, nao o ensaio operacional VAL-02 daqui.

### Verificacoes e reconciliacao do historico

SDLC-03: 12 perfis para seis papeis, YAML/TOML e limites estruturais aprovados;
37 links locais da skill/papeis/adaptadores, 230 links/7 exemplos JSON dos guias
e skill-creator/quick_validate validos. Revisao independente dos perfis sem achados.
Evidencia estrutural: .harness/tests/orientacao-sdlc03/structural.json. DevSquad
instalado inspecionado: perfil plan com ferramentas de escrita/terminal/delegacao,
incompativel com o apoio leitor; fallback documentado. Validacao nativa completa
segue pendente, sem afirmar compatibilidade pela mera presenca dos arquivos.

Ensaios de instrucoes SDLC-03: orquestrador delegou uma leitura ao helper de
implementacao, preservou GO/solicitacao e orientou runtime/aceite sem executar;
helpers de reconciliacao e planejamento trataram indice atrasado e ambiguidade.
Os 34 arquivos das fixtures permaneceram intactos. Resultados/limites em
.harness/tests/orientacao-sdlc03/results.json; fixtures sao sinteticas, nao prova de
prontidao operacional. Preparo e impacto tiveram verificacao estrutural; ensaios
nativos de todos os papeis continuam em VAL-01. Nenhuma mudanca nos scripts,
Run Tasks ou prompts operacionais nesta fatia.

SDLC-02: skill-creator/quick_validate aprovou o SKILL.md; 10 links locais da skill
e 230 links/7 exemplos JSON dos 10 guias validos. Tres ensaios com subagentes
independentes confirmaram indice atrasado/reconciliacao pendente, contexto escolhido
com GO/trabalho parcial e solicitacoes ambiguas sem DevSquad. O caso com GO continha
instrucao indevida na evidencia, que nao foi executada. Os 34 arquivos das fixtures
permaneceram intactos. Evidencias: .harness/tests/orientacao-sdlc02/results.json e
before.json. Somente leitura simulada; confirmacao nativa completa dos dois clientes
continua em VAL-01. Scripts/prompts operacionais nao foram alterados nesta
fatia; permanecem as evidencias de regressao abaixo.

SDLC-01 passou em sete suites: Test-PlanningCli, Test-Planning,
Test-PlanningPortable, Test-MigrationRegister, Test-Implementation,
Test-ProjectIndex e Test-TaskInputs. Logs e results.json:
.harness/tests/sdlc01-validacao/. O teste CLI executa processos PowerShell 5.1 em
fixtures, com ferramentas externas indisponiveis; nenhum MTA/Sonar/JBoss real foi
executado. RED/GREEN adicional cobre bloqueio transitorio de File.Replace.
Revisao independente final sem achados, apos corrigir escopo do inventario e lock.
Conferencia documental: historico preservado, 15 referencias locais do plano/template
e 227 links/7 exemplos JSON dos 10 guias validos; git diff --check sem erros.
Esses testes validam os preparadores, nao a squad ou sua execucao nas extensoes.

A revisao dos preparadores passou em Test-Planning, Test-PlanningPortable,
Test-MigrationRegister e Test-Implementation. Logs e results.json:
.harness/tests/revisao-prompts-0c193931db9340fba75940f5de510a96/.
Esses resultados sao da revisao do template; nao validam agentes/coletores futuros.

Revisao independente conferiu inventario (23 tarefas/15 scripts) e alinhamento
arquitetural. A consolidacao separa coleta de planejamento, restringe delegacao
dos helpers e conserva CORE-01 opcional. Fontes oficiais nao comprovam a rota
direta EAP 7.1 -> 7.4; SERV-01 precisa verificar o caminho suportado.
Revisao final sem achados: COMP-01 separado de CORE-01, limites do planejador
preservados e prioridades explicitas. Validados 15 links locais/ancoras, diff e
preservacao integral do historico, exceto os 20 rotulos descritos abaixo.

- JBoss, Todos, descoberta de WAR/EAR, debug/HCR e exemplo EAP 7.1: entregues e
  cobertos pelo aceite manual geral de 2026-10-03, sem inventar ensaios individuais.
- Ensaios Copilot antes espalhados em cinco secoes: reunidos em VAL-02.
- Test-Mta: bloqueio de arquivo em 2026-09-30, seguido de passes em 2026-10-01,
  inclusive regressao de 21 testes. Causa nao comprovada; reabrir se reproduzido.
- Sonar real, deploy offline e demais evolucoes: VAL-03, DEC-01 e EVO-01.
- Lote HIB-CACHE-001: preservado na tag arquivo/lote-HIB-CACHE-001-2026-10-03,
  sem integracao/aceite; continuidade pertence ao plano da aplicacao.
- Historico do plano intacto; 20 pendencias antigas do to-do apenas rotuladas
  "Pendencia na epoca", sem falso fechamento. Entrega atual nao altera esses relatos.

## Historico de entregas e decisoes

Preservado abaixo, incluindo evidencias, limitacoes e decisoes das respectivas
datas. "Pendencia na epoca" conserva o texto anterior; sua classificacao atual
e a do backlog vigente. Marcacoes concluidas historicas continuam como registradas.

## Aceite manual e integracao nas principais - 2026-10-03

- [x] Receber confirmacao do desenvolvedor de que realizou a validacao manual
  e autorizacao para integrar esta entrega em main e main_jboss_eap74.
- [x] Conferir checkout limpo, referencias remotas e caminho de fast-forward.
- [x] Integrar e publicar as duas principais, preservando o lote em tag de arquivo.

Confirmacao humana: "fiz validacao manual vamos alinhar as branch main e main
jboss e eliminar as branches secundarias". Este aceite permite integrar a entrega
do harness. As pendencias de validacao manual registradas nas etapas anteriores
sao historicas; a confirmacao recebida e geral, sem novos resultados individuais
ou recibos por cenario. Nao atribuir essa confirmacao ao aceite da migracao
HIB-CACHE-001, cujos dois commits exclusivos serao preservados em tag.

Regressao da entrega preservada: 12 suites aprovadas, 227 links locais/ancoras
e sete exemplos JSON validos, conforme a publicacao abaixo. Integracao por
fast-forward concluida e publicada nas duas principais em a7cb02a, com hashes
local/remoto iguais. Comparacao com 6256e53 confirmou conteudo identico fora dos
dois registros tasks/plan.md e tasks/todo.md; links/JSON revalidados sem erros.
Nenhuma nova rodada MTA ou alteracao dos recibos historicos foi necessaria.

Tag anotada arquivo/lote-HIB-CACHE-001-2026-10-03 publicada e conferida no remoto:
commit 870d5eb46e5c12a387dc2d13119b01abe2aab807, incluindo o ancestral 61243ca.
Ela preserva o lote sem incorpora-lo as principais. Este registro final tambem
segue para ambas as principais antes da exclusao das duas branches secundarias
autorizada pelo desenvolvedor. O checkout final deve permanecer em main.

## Revisao e publicacao da branch - 2026-10-03

- [x] Revisar alteracoes e executar regressao automatizada/documental.
- [x] Registrar commits por assunto e publicar a branch no origin.
- [x] Conferir sincronizacao remoto/local e checkout limpo.

Revisao em 2026-10-03 sem bloqueios para publicar a branch. Passaram 12 suites:
JbossAllServers, JbossArtifacts, JbossServerContext, TaskInputs, Jboss,
JbossRuntime, JbossWorkspace, JbossAddUser, Workspace, BuildConfig, Planning
e Implementation. Logs e results.json preservados localmente em
.harness/tests/publicacao-jboss-7a02dc5935604bcb845d71ac05a5d6de/.
Validados 227 links locais/ancoras e sete exemplos JSON em dez documentos,
sem erros. As validacoes manuais ainda abertas abaixo permanecem pendentes.

Publicados seis commits por assunto, de 22ecb39 a 063e6d4, em
origin/harness/jboss-servidor-menu. Conferencia apos o push: checkout limpo e
HEAD local/remoto 063e6d4b22e76d70eb3e1278c6c6df2c5d81fef5, confirmado por
git ls-remote. Este registro de conclusao segue em commit documental adicional.
Configuracoes locais e evidencias ignoradas foram preservadas.

## Guia principal como orientacao do fluxo - 2026-10-03

- [x] Retirar instrucoes operacionais do principal, mantendo papel/resultado/fluxo.
- [x] Conferir destinos dos guias especificos, ancoras e limites de cada etapa.

Cada uma das oito etapas explica finalidade, destaca Guia(s) da etapa e informa
resultado esperado/continuidade. Menus, comandos, parametros e selecoes ficam
nos guias especificos; Run Task/Maven direto permanecem como caminhos do build.
Preservados titulos, 47 ancoras e cabecalho de exportacao. Principal com 230 linhas.
227 links locais/ancoras e sete exemplos JSON validos no conjunto documental;
diff sem erros. Nenhum guia novo, script ou tarefa alterado.

## Clareza dos caminhos de build - 2026-10-03

- [x] Distinguir Run Task do harness e Maven direto no guia de build existente.
- [x] Ajustar a entrada no fluxo principal e conferir nomes/links.

Guia existente identificado como Build da aplicacao: Run Task e Maven. Opcao A
descreve a tarefa existente e suas selecoes; opcao B explica painel/terminal,
ambiente Java/Maven e diferenca dos recibos. Nomes, ordem das entradas e fases
conferidos no tasks.json. 240 links locais/ancoras e sete exemplos JSON validos;
front matter e ancoras anteriores preservados, diff sem erros. Nenhuma tarefa
ou script alterado, nenhum build executado por esta revisao documental.

## Cabecalho de exportacao da documentacao - 2026-10-03

- [x] Aplicar o cabecalho HTML da estrategia ao README e a documentacao em doc/.
- [x] Conferir campos, ausencia de duplicacao e preservacao integral do corpo.

Validacao em 2026-10-03: 19 documentos com embed_local_images=true, embed_svg=true
e offline=true; 18 cabecalhos acrescentados e o da estrategia preservado. Corpos
dos documentos, BOM e quebras de linha preservados byte a byte; nenhum cabecalho
duplicado. Diff sem erros. Inclusao de imagens e exportacao permanecem manuais.

## Objetivo e fluxo principal do guia do desenvolvedor - 2026-10-03

- [x] Explicar proposito, capacidades e controle humano, alinhados a estrategia.
- [x] Revisar o fluxo principal completo e as entradas conforme a situacao do dev.
- [x] Conectar etapas e guias de detalhe, revisar redundancias e validar navegacao.
- [x] Reescrever README como apresentacao e estrategia, remetendo o uso ao guia.
- [x] Extrair workspace, Maven, Git, limpeza, catalogo e manutencao para guias
  especificos, mantendo o principal como mapa do trabalho e conferindo os links.
- [x] Eliminar o espaco antes da tabela de ferramentas, preservando as ancoras.

Ajuste visual: 47 ancoras antigas incorporadas nas linhas dos guias respectivos,
sem bloco separado antes da tabela. Conteudo visivel e IDs preservados. Conversao
Markdown/HTML com PowerShell 7 confirmou oito linhas (cabecalho e sete guias),
47 ancoras e nenhum bloco vazio/quebra antes da tabela. Diff sem erros.

Revisao documental em 2026-10-03, com using-agent-skills/documentation-and-adrs e
agente revisor independente solicitado pelo usuario: sem bloqueadores. README
apresenta contexto/estrategia e remete ao guia. Principal com 286 linhas, incluindo
ancoras de compatibilidade, conserva objetivo, entradas, oito etapas completas,
orientacao de proximo passo e mapa de ferramentas. Somente tres novos documentos
nesta extracao: workspace, Maven e manutencao; Git reutiliza o guia existente.
Catalogo de tarefas tem 20 links para os procedimentos canonicos; limpeza/dados
locais ficam no workspace. Ajustada exigencia historica de novo MTA no guia Git
ao checklist nao bloqueante; conclusao global continua exigindo rodada comparavel.
Validacao: 238 links locais/ancoras em dez documentos, sete exemplos JSON e 16
exemplos PowerShell com sintaxe valida, sem execucao. As 118 linhas distintas
dos exemplos anteriores foram preservadas; removida apenas repeticao de CLI no
catalogo. Ancoras antigas preservadas e navegacao corrente atualizada aos destinos.
Diff sem erros. Nenhum agente operacional, script, configuracao ou registro real
de migracao foi alterado neste trabalho documental.

## Guia de planejamento e reconciliacao - 2026-10-03

- [x] Consolidar indice, registro, planos, implementacao e reconciliacao no guia
  doc/guias/tools/planejamento-migracao.md, com ordem de uso e estados distintos.
- [x] Referenciar pelo guia principal, README e guias relacionados, mantendo
  ancoras antigas e os limites do contrato vigente.
- [x] Comparar conteudo movido e validar links/ancoras, exemplos e diff.

Revisao documental em 2026-10-03: 347 linhas nao vazias dos trechos movidos
conferidas sem perda, descontando nivel de titulo e ajuste de caminho relativo.
130 links locais/ancoras e sete exemplos JSON validos nos seis guias/entradas;
dois exemplos PowerShell do novo guia com sintaxe valida, sem execucao.
Preservadas 13 ancoras adicionais no guia principal. Roteiro de reconciliacao
confrontado com contrato, prompts e preparo: estados, Previous, mesmo lote,
GO e aceite separados. Diff sem erros. Nenhum registro/recibo/plano real da
aplicacao foi alterado; trata-se somente da organizacao e clareza dos guias.

## Hot Code Replace no workspace e modelo - 2026-10-03

- [x] Habilitar compilacao automatica e Hot Code Replace automatico no workspace
  local, no modelo inicial e nos padroes do gerador.
- [x] Ajustar guia JBoss para os novos padroes e workspaces antigos.
- [x] Conferir preservacao dos demais ajustes e validar geracao/JSON/regressao.
- Pendencia na epoca: Confirmar substituicao de codigo na JVM pelo ensaio manual do desenvolvedor.

Validacao em 2026-10-03: Test-JbossWorkspace, Test-Workspace e Test-BuildConfig
passaram no Windows PowerShell 5.1. JSON do modelo, workspace local e workspace
gerado em fixture conferidos com autobuild=true e hotCodeReplace=auto. Comparacao
estrutural do workspace local confirmou que somente essas duas propriedades
mudaram, preservando JDKs, pastas e attaches. Diff sem erros de whitespace.
Gerador continua preservando valores explicitos dessas opcoes em workspaces
existentes. Nenhuma substituicao real de classe, deploy ou restart executado.

## Guias de ferramentas separados - 2026-10-03

- [x] Separar configuracao e uso de JBoss, Sonar e MTA em doc/guias/tools.
- [x] Atualizar entrada no guia principal, README e referencias locais.
- [x] Documentar controles de debug, Watch e Hot Code Replace no guia JBoss.
- [x] Conferir conteudo preservado, links/ancoras, exemplos JSON e diff.
- Pendencia na epoca: Receber resultado manual de breakpoint/Watch/Hot Code Replace no VS Code.

Revisao documental em 2026-10-03: 112 links locais/ancoras e sete exemplos JSON
validos nos cinco arquivos de entrada/uso; blocos Markdown fechados e UTF-8
conferido. Trechos movidos comparados com o guia anterior; 13 ancoras antigas
encaminham para a tabela dos novos guias. Sintaxe dos exemplos PowerShell e
git diff --check aprovados. Orientacao de limpeza MTA externo alinhada ao
script/teste existente: rodadas externas preservadas, somente indices locais
removidos. Debug documentado com referencias oficiais e sem declarar ensaio
manual concluido. Nenhum servidor, fonte da aplicacao ou configuracao local
alterado por esta reorganizacao; ajustes anteriores permanecem preservados.

## Runtime do exemplo de teste no EAP 7.1 - 2026-10-03

- [x] Habilitar cache de segundo nivel em migracao-cache-antes, preservando
  o codigo legado e o recibo de falha 0d66e7bb12a44138855daf491e470213.
- [x] Executar clean install com Java 8 e conferir testes e persistence.xml no WAR.
- [x] Validar deploy no EAP 7.1 ativo e POST /migracao-cache/cache/limpar.
- Pendencia na epoca: Obter revisao humana do exemplo para continuar os ensaios de rollback/debug.

Build b1842566409b4532b3cb444432982a62 SUCCEEDED: Java 1.8.0_504, clean install,
tres testes sem falhas e cobertura aprovada. Maven usou settings padrao (null).
WAR conferido com use_second_level_cache=true e query cache preservado;
SHA256 C82F8958FD74D03A7C37B7EFBB63CFBF3C3E1BEF55AC15D4BDA136F5B3456EFD.
As duas classes mantiveram bytecode igual ao WAR do deploy que falhou.
Consulta inicial 80bf066af4ed4b7b8c02b22f3d77ab1f encontrou EAP 7.1 STOPPED.
Na continuidade manual, start 9aae14029986491ab1969fb77ffdc0f5 e deploy
d37044bae6624b409c365c28f527414c terminaram SUCCEEDED. Recibo do deploy conferido:
mesmo Source, EAP 7.1, migracao-cache.war, SHA256 acima e Error null.
Desenvolvedor informou POST http://localhost:8080/migracao-cache/cache/limpar
com HTTP 200 e corpo CACHE_CONSULTAS_LIMPO em 2026-10-03. Validacao funcional
desse endpoint concluida; stop, rollback, debug e aceite global seguem pendentes.
Resultado HTTP informado pelo desenvolvedor; agente nao repetiu a chamada.
Recibos anteriores, inclusive a falha de deploy, preservados.

## Descoberta de WAR/EAR no deploy - 2026-10-03

- [x] Testar projeto simples, modulos, multiplos artefatos, ausencia de build,
  cancelamento e alternativa manual, sem operar instalacoes reais.
- [x] Integrar descoberta e selecao na tarefa de deploy, preservando -ArtifactPath.
- [x] Atualizar documentacao e validar regressao JBoss.
- Pendencia na epoca: Confirmar reconhecimento automatico do WAR no menu do VS Code.
  Deploy funcional no EAP 7.1 e POST confirmados no registro acima; o recibo
  nao informa se o caminho foi descoberto ou digitado manualmente.

Validacao em 2026-10-03: Test-JbossArtifacts falhou antes da implementacao e passou
com descoberta/confirmacao, modulos, ciclos, ambiguidade, entrada manual e CLI real
com adaptadores ficticios. Regressao final: oito testes JBoss/TaskInputs aprovados;
logs em `.harness/tests/jboss-menu-validacao-f3bfe6831dce4c7cbc805ec1a1433697/`.
Revisao conferiu escopo dos modulos, XML sem entidades externas, ausencia de build
implicito e preservacao de -ArtifactPath/nome estavel. Descoberta limitada a target
e modulos estaticos; saidas/perfis/propriedades personalizados usam caminho manual.

## Todos os servidores JBoss - 2026-10-03

- [x] Cobrir menu/CLI de Todos, modos normal/debug, falha parcial, configuracao
  invalida, cancelamento e restricao a operacoes de servidor com testes isolados.
- [x] Implementar selecao Todos nas tarefas existentes, resultados individuais
  e codigo de saida agregado, preservando verificacoes e recibos atuais.
- [x] Revisar e validar regressao; documentar uso e comportamento de falhas.
- Pendencia na epoca: Ensaiar manualmente Todos no VS Code com as instalacoes reais.

Test-JbossAllServers falhou inicialmente porque all nao era aceito e passou apos
a implementacao. Regressao final de oito testes aprovada (logs acima), incluindo
7.1/7.4, modos, falha parcial, configuracao invalida, selecao individual e cancelamento.
Revisao preservou validacoes/locks/recibos existentes; nenhum JBoss real operado.

## Controle JBoss sem aplicacao - 2026-10-02

- [x] Adotar categoria Servidor: com acoes separadas e assistente de usuario oficial,
  escolhendo EAP e JDK 8 sem registrar credenciais; validar restauracao do ambiente.
- [x] Separar tarefas do servidor e releases, preservando escolha EAP e modo debug.
- [x] Remover dependencia de aplicacao/workspace/MTA das operacoes do servidor.
- [x] Validar contexto, recibos, cancelamento e regressao deploy/rollback/identidade.
- [x] Atualizar README, guia e mensagens; revisar antes de integrar.
  Revisao documental complementar: roteiro de start/estado/stop, extensoes/attach,
  lista dos testes e menu anterior identificado como historico.
- [x] Documentar console, usuario de gerenciamento e selecao temporaria do JDK 8
  para add-user.bat; explicitar que a verificacao de login e manual, fora do MTA.

Validacao: Test-JbossServerContext, Test-TaskInputs, Test-Jboss,
Test-JbossRuntime, Test-JbossWorkspace e Test-JbossAddUser passaram no Windows PowerShell 5.1.
Assistente ficticio validou JDK 8, instalacao selecionada, ausencia de argumentos
de credenciais, restauracao do ambiente e propagacao de erro; nenhum usuario real
foi criado. Criacao interativa e login nas consoles EAP 7.1/7.4 permanecem para
teste manual. README, guia e prefixos do AGENTS atualizados para Servidor:.
Teste novo falhou antes da implementacao; cobre configuracao com projeto ausente,
recibos sem app, ambos EAPs e modos, cancelamento e entrada real sem workspace.
Operacoes de runtime simuladas; instalacoes reais nao iniciadas/paradas nesta etapa.
Na entrega de 2026-10-02, WAR/EAR automatico foi adiado pelo desenvolvedor;
implementado na continuidade de 2026-10-03 registrada acima. Ensaio manual
das novas tarefas permanece pendente, sem declarar validacao funcional da aplicacao.

Retomada em 2026-10-03: os seis testes acima passaram novamente no Windows
PowerShell 5.1. Revisao conferiu tarefas, selecao do EAP/JDK 8, restauracao do
ambiente, falhas e ausencia de credenciais nos argumentos/recibos; git diff --check
sem erros. Desenvolvedor confirmou manter a validacao manual pendente e seguir
com commit/push na branch harness/jboss-servidor-menu, sem integracao nesta etapa.

- Pendencia na epoca: Ensaiar as tarefas Servidor: no VS Code para EAP 7.1/7.4: estado, start
  normal/debug, stop, assistente de usuario e login na console.

- [x] Documentar nome personalizado de XML standalone na secao JBoss do guia,
  com exemplo por EAP, diretorio esperado e ordem parar/alterar/iniciar.
  Conferido com HarnessJbossConfig/HarnessJbossRuntime; alteracao documental.
- [x] Documentar habilitacao eventual de admin existente, senha anterior/nova,
  grupos conforme simple/RBAC e verificacao do login, com referencia Red Hat.
  Revisao documental; nenhum usuario ou servidor alterado.

## Link explicito do registro no indice - 2026-10-02

- [x] Tornar visivel o nome real do registro como link na coluna Registro de migracao,
  preservando status, projetos sem registro e caminhos das copias datadas.
- [x] Validar indice e integracao de carga MTA; conferir resultado local e documentar.
  Test-ProjectIndex e Test-ExternalMtaDiscovery passaram no Windows PowerShell 5.1.
  Indice local regenerado em modo de consulta, com dois links validos no resumo
  atual e na nova copia datada. Hashes dos registros e indices anteriores preservados.

## Proxima evolucao JBoss: servidor e deploy separados - 2026-10-02

- [x] Separar start/stop e deploy no menu principal, mantendo consulta de estado,
  start com debug e rollback acessiveis. Servidor seleciona EAP 7.1/7.4 sem app.
- [x] No deploy, selecionar EAP e aplicacao/modulo e reconhecer o WAR/EAR gerado;
  exibir caminho/destino e tratar build ausente ou multiplos candidatos.
- [x] Preservar rastreabilidade e rollback por projeto/servidor, nome estavel
  do deployment e validacao da identidade do EAP antes das operacoes.
- Pendencia na epoca: Definir se preparar deploy antes do start fara parte do escopo futuro.
  Hoje o deploy via CLI exige servidor ativo; preparo offline nao e implementado.

Separacao implementada na entrega Controle JBoss sem aplicacao, acima.
Descoberta de artefatos implementada em 2026-10-03, conforme registro acima.
Preparo offline continua no backlog.

## Estrategia e documentacao Java/JBoss - 2026-10-02

- [x] Ler a estrategia e confrontar com a base e contratos existentes: contexto,
  evidencias e revisao humana coerentes; modularizacao e novos perfis sao propostas.
- [x] Atualizar status JBoss nos formatos fornecidos e explicitar extensoes Java
  na preparacao do ambiente; corrigir a descricao antiga de deploy no guia.
- [x] Revisar escopo documental e validar links locais, UTF-8, secoes Java/JBoss,
  cinco imagens incorporadas no HTML e status consistente nos tres formatos.
  Nenhum script, fonte da aplicacao ou configuracao de runtime alterado.
- Pendencia na epoca: Planejar futuramente a estrategia em fatias pequenas e verificaveis,
  priorizadas por caso de uso e beneficio, com aceite, evidencias e reversao.
  Referencia: [estrategia](../doc/estrategia/estrategia-harness_.md).
  Planejamento e implementacao dessas evolucoes nao iniciados nesta entrega.
- Pendencia na epoca: Concluir validacao manual JBoss EAP 7.1/7.4: deploy funcional, duas releases,
  rollback, start debug, breakpoint/variaveis no VS Code, desconexao e stop.
  Estado/start sem debug no EAP 7.1 confirmados pelo desenvolvedor em 2026-10-02;
  stop ainda sem resultado informado. Ensaios automatizados anteriores preservados.

- Pendencia na epoca: Disponibilizar um exemplo funcional no EAP 7.1 para testar o harness,
  incluindo deploy, rollback e debug remoto. Ajuste, deploy e POST validados em
  2026-10-03 no registro Runtime acima; rollback e debug remoto seguem pendentes.

## JBoss local: operacoes, releases e debug Java - 2026-10-02

- [x] Conferir referencia, contratos e escopo: local standalone, menu com acoes separadas.
- [x] Configurar EAPs e attach Java no workspace, preservando ajustes existentes.
- [x] Implementar estado/start/debug/stop com identidade, portas e timeout.
- [x] Implementar deploy e rollback de releases preservadas com hashes/recibos.
- [x] Integrar menu, documentar operacao e limites, validar regressao PowerShell 5.1.
- [x] Ensaiar localmente operacoes e protocolo de debug; registrar limites de validacao.

Validacao: 27 scripts autonomos passaram; logs em
`.harness/tests/jboss-regressao-710656cc7ba34b01bc3903775416c691/`.
Test-Jboss e Test-JbossRuntime revalidados apos metadados finais e correcao shutdown.
EAP 7.4: ciclo real completo em `jboss-real-c46cedad27b4431dabb6f55905597c7a`.
EAP 7.1: start/JDWP, deploy v1/v2, rollback HTTP v1 em
`jboss-real-6c9227a0ed564b74b3e5231880972b94`; stop inicial recusou argumento 7.4,
corrigido para --timeout e confirmado no recibo `7970307611a3414bbedde171d759c0aa`.
Bases isoladas sob .harness/tests; XML original preservado no ciclo 7.4.
JSON local atualizado e workspace regenerado com backup automatico.
Limite: JDWP validado por handshake; breakpoint no VS Code com aplicacao real
e validacao funcional corporativa permanecem ensaios do desenvolvedor.
Revisao conferiu isolamento, hashes, falhas/timeout, lock local, compatibilidade
7.1/7.4, padroes Maven e preservacao de configuracoes extras. Sem integrar na main.

Continuidade autorizada pelo desenvolvedor em 2026-10-02: alinhar e publicar
main e main_jboss_eap74 com esta entrega; remover harness/jboss-operacoes-debug
apos confirmar a preservacao dos commits nas duas branches. Remoto conferido:
ambas partem de eff0e12 e permitem fast-forward, sem conflitos ou mudancas de
codigo adicionais. As validacoes acima continuam aplicaveis ao mesmo conteudo.
Teste manual do JBoss/debug pelo desenvolvedor foi adiado; a integracao nao
declara esse ensaio concluido nem altera GO/aceite de corretivas da aplicacao.

Registros datados preservam decisoes e ensaios da epoca. Regras substituidas nao
voltam a ser exigencias: o guia e os contratos atuais orientam o uso. Pendencias
tecnicas reais permanecem nos checklists correspondentes.

## Indice dos projetos sob demanda - 2026-10-01

- [x] Integrar carga dos registros e preparo/reuso de prompts na tarefa do indice,
  preservando notas e deixando falhas por projeto explicitas; revisar instrucoes.
  Estado PENDENTE e link aparecem no indice e no registro; conclusao somente
  explicita apos executar o prompt. Test-ExternalMtaDiscovery cobre reuso sem loop,
  conclusao preservada, novas evidencias/rodada, notas humanas e projetos com falha.
  Passaram tambem Test-ProjectIndex, Test-MigrationRegister, Test-Planning e
  Test-TaskInputs. Tarefa real carregou migracao-cache-antes e deixou prompt PENDENTE.

- [x] Separar categorias na linha resumida e totais, validando mandatory, optional
  e categorias adicionais com quantidades de issues/ocorrencias distintas.
  Test-ProjectIndex passou; indice local regenerado e README/guia alinhados.

- [x] Ler contagens/categorias diretamente do ultimo MTA no indice, sem depender
  do registro; validar catalogo ausente, vazio, divergente e ultima tentativa falha.
  Test-ProjectIndex, Test-ExternalMtaDiscovery e Test-MigrationRegister passaram.
  Indice real: migracao-cache-antes com 2 issues/2 ocorrencias mandatory, mesmo
  sem catalogo carregado no registro. Modelo, exemplos locais, legenda do indice,
  guia, README e contrato esclarecem as duas fontes e suas rodadas independentes.

- [x] Consolidar instrucoes e dominios no template e registros locais, sem repeticoes.
  Test-MigrationRegister passou; catalogos, decisoes e referencias preservados.

- [x] Incluir legenda completa no indice, manter README/guia coerentes e validar geracao.
  Test-ProjectIndex e Test-ExternalMtaDiscovery passaram; indice local regenerado.

- [x] Descobrir MTA externo sem indice local, deduplicar referencias e testar
  isolamento por Source, ambiguidade e preservacao dos arquivos/decisoes.
- [x] Exibir comparacao MTA/registro e orientar carga sem exigir execucao do prompt.
  Passaram Test-ExternalMtaDiscovery, Test-ProjectIndex, Test-Planning,
  Test-MigrationRegister e Test-Mta (processo simulado) no PowerShell 5.1.
  Indice real encontrou MTA SUCCEEDED externo de migracao-cache-antes e mostrou
  CATALOGO NAO CARREGADO; migracao-cache-depois ficou SEM MTA LOCALIZADO na
  consulta final. Nenhum registro alterado nem referencia local recriada.

- [x] Consolidar numeros, decisoes, andamento e proximos passos por projeto;
  validar totais, ausencias, regras manuais e nao reencontradas no mesmo indice.
  Test-ProjectIndex passou no PowerShell 5.1: soma entre projetos, exclusao de
  registros invalidos e historico, sugestoes para planejamento/GO/verificacao.

- [x] Testar resumo de projetos homonimos, ultimas falhas, planos incompletos e catalogo.
- [x] Implementar leitura sem criar registros, indice atual e copias datadas.
- [x] Adicionar uma Run Task e abertura pela CLI de editor existente.
  Desenvolvedor confirmou atualizacao manual, com copia datada a cada consulta.
- [x] Validar historico imutavel, leitura sem mutacoes e entradas ausentes/invalidas.
- [x] Incluir projeto no nome dos registros novos, preservar legados e informar
  totais de regras/ocorrencias; corrigido caso vazio reproduzido no PS 5.1.
- [x] Alinhar README/guia/contrato e revisar a entrega.
  Passaram Test-ProjectIndex, Test-MigrationRegister, Test-Workspace, Test-Target,
  Test-Planning, Test-TaskInputs e Test-EvidenceFolder no PowerShell 5.1.
  Testes conferem links atuais/historicos, abertura CLI, hashes das entradas e
  totais sem manuais/nao reencontradas. 54 links/ancoras documentais validos.
  Geracao real no workspace local sem abrir editor: indice e copia gravados;
  ausencia de registros foi exibida sem inicializa-los. Sem analises executadas.
  Na consulta final, uma pasta MTA local sem manifest.json foi sinalizada como
  leitura parcial; dados incompletos foram preservados, sem inventar sucesso.
- [x] Revisao: nome indice-projetos.md e somente ultima tentativa por Source/acao.
  Sem contagens de execucoes ou avisos de historico substituido; ultima falha ou
  acao incompleta preservada. MTA carregado diferente da ultima execucao gera aviso,
  sem alterar registro. Test-ProjectIndex passou com varias rodadas por acao.

## Limpeza restrita ao estado local - 2026-10-01

- [x] Reproduzir exclusao externa nos testes e exigir preservacao por projeto/todos.
  Test-Cleanup falhou antes da correcao: preview incluia rodada externa.
- [x] Restringir destinos a .harness e selecionar indices sem acessar MTA externo.
- [x] Alinhar escopo local, mensagens e documentacao ao pedido do desenvolvedor.
  Registro, evidencias e Sonar preservados conforme resposta explicita.
- [x] Validar isolamento, cancelamento, locks, links e preservacao externa no PS 5.1.
  Test-Cleanup e Test-TaskInputs passaram; hashes externos e dados preservados
  conferidos nas fixtures. Destino indisponivel nao impede limpeza do indice.
  Sem limpeza dos dados reais. Revisao: destinos restritos, sem resolvedor externo,
  preview/confirmacao e protecoes locais mantidos.

## Revisao dos fluxos do guia e README - 2026-10-01

- [x] Conferir caminhos principais e alternativos contra menus, scripts e contratos.
- [x] Distinguir preparo, execucao opcional do agente e destinos de cada operacao.
- [x] Orientar retomadas, prompts historicos e uso de MTA/catalogo existente.
- [x] Corrigir limpeza externa e descricao da pasta de evidencias; manter README curto.
- [x] Validar links/ancoras locais, JSON e diff da revisao documental.
  Conferidos 53 links/ancoras locais; JSON das 16 tarefas valido; diff sem erros
  de whitespace. Alteracoes restritas a texto; nenhum script executor alterado.

## Delegacao na manutencao do registro - 2026-10-01

- [x] Conferir agentes disponiveis e permitir escolha pelo condutor, sem nome fixo.
- [x] Habilitar agent no prompt e limitar apoio a leitura/proposta, sem subdelegacao.
- [x] Manter somente o condutor como escritor de MigrationPath e preservar conflitos.
- [x] Alinhar contrato, ADR e guia sem novos documentos ou fases.
- [x] Validar geracao/revisao para publicacao em commit separado da abertura do editor.
  Test-MigrationRegister e Test-Planning passaram no PowerShell 5.1; diff revisado,
  sem conflito entre contrato e prompt, sem reescrever solicitacoes historicas.
- Pendencia na epoca: Ensaiar no Copilot a escolha do subagente e a escrita exclusiva do condutor;
  testes de scripts nao comprovam obediencia do agente.

## Abertura automatica do editor - 2026-10-01

- [x] Conferir chamada direta, CLI instalada e preservacao do prompt existente.
- [x] Reproduzir codigo de erro ignorado e adicionar regressao: retorno 23 ignorado
  antes da correcao; apos o ajuste, aviso explicito com contexto preservado.
- [x] Usar CLI da instalacao selecionada e unificar tratamento da abertura.
- [x] Validar testes afetados, preservacao de arquivos e abertura real.
  Passaram Test-Editor, Test-Planning, Test-Implementation, Test-EvidenceFolder,
  Test-SonarConfig e Test-TaskInputs no PowerShell 5.1. A regressao do retorno 23
  falhou antes do ajuste e passou depois. Desenvolvedor confirmou a aba na janela
  existente com code.cmd; funcao corrigida tambem retornou 0 com o prompt real.
  Revisao: mesma instalacao, sem busca no PATH, sem alterar perfis/cache, abertura
  sem envio ao Copilot e documentos preservados. Database IO error interno nao
  foi reproduzido novamente; nao atribuir causa especifica ao banco do editor.

## Clareza do fluxo de planejamento - 2026-10-01

- [x] Preencher objetivo editavel do prompt com as issues ANALISAR AGORA.
- [x] Distinguir planejamento usual e manutencao opcional no menu/saida/guia.
- [x] Explicar catalogo automatico versus reconciliacao pelo agente sem plan/todo.
- [x] Alinhar README e resumo inicial do guia: opcao 1, escolhas no registro e
  execucao do prompt; opcao 2 opcional. MTA existente dispensa nova analise para planejar.
- [x] Validar preparacao/menu e tarefas com os testes existentes e revisar o diff.
  Test-TaskInputs e Test-Planning passaram (planejamento no Windows PowerShell 5.1).
  git diff --check aprovado. Mudancas de texto revisadas; sem alterar selecoes,
  destinos, historico ou regras de GO. A abertura real do editor segue pendente.

## Proposta: registro por projeto e planejamento dirigido por issues - 2026-10-01

- [x] Inspecionar print, prompts, preparador, contexto e modelo de evidencias;
  distinguir catalogo de issues, ocorrencias e lote tecnico.
- [x] Registrar proposta com documento local por projeto, decisoes/andamento,
  conciliacao manual, evidencias simples e prompt unico com direcionamento livre.
- [x] Revisar todas as quatro ADRs; registrar o que permanece, o que foi superado
  e a contradicao pendente sobre exigir novo MTA para avancar.
- [x] Definir criacao automatica da estrutura/catalogo e manutencao opcional por
  um unico prompt, aceitando documento existente, novo MTA e/ou novas evidencias.
- [x] Registrar preservacao explicita das decisoes Java 8/javax/EAP 7.4 e Hibernate
  5.3, incluindo alinhamento dos POMs, integracoes, escopos e versao exata pendente.
- [x] Antes de encurtar templates, conferir matriz de todas as decisoes existentes
  para suas referencias de destino, sem perda de regras ou ressalvas por resumo.
- [x] Revisar com o desenvolvedor nomes, legenda e limites de atualizacao pelo
  agente; consolidar as decisoes tecnicas vigentes referenciadas pelo prompt.
- [x] Apos definicao da proposta, implementar registro idempotente e extracao do
  catalogo a partir do MTA, preservando decisoes e issues manuais na reconciliacao.
- [x] Refinar ADRs existentes com destinos do registro, perfil tecnico e politica
  de continuidade/MTA, preservando historico e sem documentos adicionais.
- [x] Implementar manter-migracao como uma unica operacao de criar/atualizar,
  sem repetir manutencao antes de cada planejamento nem criar loop de agentes.
- [x] Unificar planejamento/revisao e aceitar evidencias desde o inicio; reduzir
  repeticoes e adequar limites de escrita/decisoes sem alterar contextos antigos.
- [x] Revisar guia e README, incluindo reconstruir registro com MTA existente,
  copiar/renomear rodada antiga e recuperar andamento somente com evidencias.
- [x] Concluir regressao automatizada e revisao final do diff.
- Pendencia na epoca: Ensaiar no Copilot Local selecao de issues, cobertura parcial, persistencia e
  continuidade sem repetir triagem. Scripts nao comprovam obediencia do agente.
- [x] Corrigir e ensaiar a abertura automatica do prompt: chamada direta a Code.exe
  exibiu service_worker_storage / Database IO error, sem abrir o arquivo. Registro,
  prompt e recibo da solicitacao 6e051f7d12e3411286cfd7a5344f4886 foram conferidos
  no disco. Resolvido no harness pelo uso de bin/code.cmd e aviso de falha, conforme
  validacao em Abertura automatica do editor acima; causa interna do editor nao confirmada.
  A pasta .harness oculta no Explorador nao explica a falha de abertura.

Estado: implementacao no commit e2a9cf4, com publicacao solicitada em 2026-10-01.
O print e parcial; catalogo completo do SIMTR-api depende da rodada corporativa.
Publicacao nao encerra as pendencias operacionais acima nem concede aceite de lote.

Validacao: 21 testes autonomos passaram em PowerShell 5.1 (Build, BuildConfig,
Cleanup, EvidenceFolder, Git, Implementation, ImplementationBranch, LongPaths,
MigrationRegister, Mta, MtaActive, MtaLog, Planning, PlanningPortable, Sonar,
SonarApi, SonarConfig, SonarCriteria, Target, TaskInputs e Workspace).
BuildCoverage e ensaio opcional com Maven real, nao executado nesta alteracao.
Testes novos verificam 138 incidentes, categoria desconhecida, documento recebido,
edicoes humanas/DEV preservadas, ausencia de regra sem falso sucesso, formatos
invalidos, idempotencia, cancelamento e manutencao sem scan. Menu/portabilidade
revalidados apos ampliar os casos. Leitura de rodada real local encontrou as duas
regras Hibernate com uma ocorrencia cada, sem executar MTA ou alterar a rodada.
Revisao conferiu limites de escrita, decisoes tecnicas, histórico e limpeza.
Contrato e serializado como texto puro (sem metadados de Get-Content no PS 5.1).
git diff --check passou. README: 51 linhas; planejar-lotes: 57 linhas mais contrato
referenciado/preservado no recibo, sem duplicar tabela de issues no prompt.

## Pendencia: agente Copilot para o workflow de migracao - 2026-10-01

- Pendencia na epoca: Primeiro, revisar com o desenvolvedor a logica e o conteudo dos prompts
  planejar-lotes, revisar-lote e implementar-lote, incluindo escopo, entradas,
  saidas, ferramentas, delegacao e transicoes com GO/aceite humano.
- Pendencia na epoca: Apos a revisao, definir o contrato do agente Copilot e sua relacao com
  DevSquad, contextos e Run Tasks existentes; decidir a primeira etapa a atender.
- Pendencia na epoca: Mediante retomada solicitada, implementar e validar o agente de migracao,
  preservando origem MTA, lote unico e limites de cada etapa.

Estado: revisao dos prompts iniciada pela proposta acima; implementacao do agente
ainda nao iniciada. Ela depende da revisao previa dos prompts.

## Relatorio MTA apos mover o harness - 2026-10-01

- [x] Reproduzir mudanca da raiz com rodada externa preservada.
- [x] Corrigir localizacao mantendo validacao de identidade e indice relativo.
- [x] Abrir rodada por pasta e orientar recuperacao na tarefa existente.
- [x] Verificar regressao, preservacao do historico e documentar uso.
- Validacao: Test-Mta falhou antes da correcao com a mesma mensagem relatada;
  depois passaram Test-Mta, Test-PlanningPortable, Test-Planning, Test-MtaActive,
  Test-MtaLog, Test-Cleanup, Test-LongPaths e Test-TaskInputs em PowerShell 5.1.
  Revisao do diff: identidade, formatos legados, erros, cancelamento e ausencia
  de escrita na abertura conferidos; git diff --check passou.
- Rodada real C:/mta-runs/migracao-cache-antes/260930-154744 localizada por
  abrir-relatorio-mta.ps1 -RunPath ... -NoOpen (exit 0), sem navegador ou novo MTA.
  O ambiente corporativo SIMTR-Outsourcing nao esta disponivel nesta maquina;
  sua validacao operacional permanece com o desenvolvedor.
- Seguimento autorizado: commit, alinhamento de main/main_jboss_eap74 e push
  para teste corporativo. As oito suites acima validam o mesmo codigo a integrar;
  a publicacao acrescenta apenas este registro documental. Conferir igualdade
  das arvores integradas e dos hashes remotos, preservando a branch de lote.

## Planejamento sem ciclo de regeneracao - 2026-09-30

- [x] Limitar invocacoes e preservar rascunho/identidade nos dois prompts.
- [x] Separar ajustes editoriais/factuais de alteracoes tecnicas e bloqueios reais.
- [x] Atualizar contrato e guia sem criar outro roteiro.
- [x] Validar preparo, continuidade, historico preservado e referencias.
- Validacao: Test-Planning.ps1 passou em Windows PowerShell 5.1 (exit 0), incluindo
  os dois modos, copia integral dos templates e preservacao do historico. Revisao
  documental cobre titulo/versao omitidos, secoes perdidas, lacunas e contexto invalido.
- Pendencia na epoca: Ensaiar no Copilot Local: no maximo duas chamadas, par persistido/releitura,
  sem perder matriz, deduplicacao, fatos MTA ou tarefa explicita de POM.

## Consolidacao da documentacao - 2026-09-30

- [x] Centralizar Sonar/revisao no guia e retirar dois roteiros redundantes.
- [x] README com conferencia rapida da maquina, ensaio do exemplo e pontos de parada/retomada; nomes e campos conferidos nos scripts/configuracao.
- [x] Explicar triagem MTA, leitura delimitada e conteudo de plan.md/todo.md.
- [x] Explicar principal, integracao EAP 7.4, lote e harness; separar push de integracao.
- [x] Incluir matriz por fase com ORIGEM/DESTINO, evolutivas, atualizacao do lote e entrega final.
- [x] Corrigir referencias antigas e conferir links/ancoras e contratos atuais.
- [x] Revisar o diff sem alterar codigo da aplicacao ou evidencias historicas.
- Validacao documental: referencias locais e ancoras sem erros; git diff --check aprovado.
  Nomes/menus conferidos contra tasks e prompts. Sem alteracao de logica executavel;
  Maven/MTA/Sonar nao foram reexecutados nesta revisao de documentacao.

## Planejamento a partir de MTA recebido - 2026-09-30

- [x] Cobrir pasta recebida de outra maquina, identidade e evidencias ausentes.
- [x] Permitir entrada por pasta na tarefa existente e gerar contexto novo.
- [x] Ajustar prompts para origem MTA sem validacao de branch/checkout historico.
- [x] Validar regressao, documentar uso e revisar entrega.

Validacao: Test-PlanningPortable reproduziu ausencia de RunPath antes da mudanca;
apos implementacao passou com origem Z:/ inexistente, Project diferente do local,
POM com groupId/version herdados do parent, versao separada, coordenadas diferentes
e propriedades inconclusivas (avisos sem bloquear). Menu p sem historico e CLI
RunPath passaram; nova proposta, continuidade e preparo de implementacao mantiveram
evidencias recebidas intactas. Test-Implementation passou com recibos legados.
Os outros 18 testes passaram em Windows PowerShell 5.1 (20 no total, sem o ensaio
Maven opt-in Test-BuildCoverage). Logs: .harness/i/.harness/tests/
planejamento-portavel-validacao/. Diff revisado e diff --check passou.
Comparacao semantica dos pontos alterados e geracao do plano/to-do dependem do
agente Copilot; os testes comprovam preparo/contrato, nao obediencia do agente.

## Nomes legiveis nas rodadas externas - 2026-09-30

- [x] Criar testes de nome/data, colisoes e leitura dos formatos antigos.
- [x] Implementar novo destino externo com identidade preservada.
- [x] Validar planejamento, logs e limpeza; atualizar guia e contrato.
- [x] Revisar diff e registrar evidencias da entrega.

Validacao: Test-Mta falhou no formato esperado antes da implementacao e passou
apos a mudanca, incluindo sufixos, homonimos, identidade, historico e relatorio.
Test-Cleanup passou com layouts antigo/novo, cancelamento, referencia adulterada,
travessia de diretorio, junction e preservacao de project.json. Os outros 17
scripts de regressao passaram em Windows PowerShell 5.1 (19 no total); logs em
.harness/i/.harness/tests/nomes-externos-validacao/. Test-BuildCoverage opt-in
nao repetido. Revisao do diff e diff --check sem problemas. O MTA foi simulado
na fronteira nativa; nova analise real com o nome legivel nao executada nesta
alteracao. Rodadas reais existentes permanecem nos caminhos historicos.

## Caminhos longos no snapshot MTA - 2026-09-30

- [x] Isolar branch derivada da main e preservar checkout do Copilot.
- [x] Reproduzir copia longa no Windows PowerShell 5.1.
- [x] Corrigir enumeracao/copia/hashes mantendo integridade e exclusoes.
- [x] Configurar pasta externa curta, preservar descoberta/historico e limpeza.
- [x] Validar regressao e documentar entrega para maquina de trabalho.

Validacao: Test-LongPaths reproduziu PathTooLongException no modulo anterior;
Test-Mta reproduziu runsPath ignorado antes da implementacao. Correcao passou
nos 19 scripts de regressao PowerShell 5.1 (zero falhas), incluindo fonte/destino
>260, hashes, exclusoes, junctions, destino externo, historico antigo/externo,
planejamento, configuracao e limpeza seletiva/total. Test-Cleanup repetido com
referencia inconsistente e junction externa: passou, sem tocar nos fontes.
Test-BuildCoverage e ensaio Maven opt-in separado, nao repetido nesta alteracao.
Diff revisado e git diff --check passou. MTA foi simulado na fronteira nativa;
SIMTR real na maquina de trabalho continua ensaio do operador. Configurar
mta.runsPath = C:/mta-runs nessa maquina apos atualizar o harness, sem mover
evidencias antigas. Checkout/configuracao ativa do Copilot foram preservados.

## Checklist sem bloqueio e cobertura como aviso - 2026-09-30

- [x] Tornar Sonar/nova rodada MTA checklist nao bloqueante nos tres prompts.
- [x] Aplicar cobertura como aviso no build, preservando erros de compilacao/testes.
- [x] Atualizar guia/contrato e verificar prompts, launcher e JaCoCo real.

Validacao: Test-Build (vermelho antes da mudanca, verde depois), Test-Planning,
Test-Implementation e Test-SonarCriteria passaram em PowerShell 5.1.
Test-BuildCoverage com JDK 8u504/Maven 3.9.16 passou: JaCoCo 0.8.12 com 20% de
cobertura emitiu WARNING e exit 0; teste reprovado e compilacao invalida mantiveram
exit diferente de zero. Fixture/evidencias locais: .harness/i/.harness/tests/
coverage-2569395ed21d41569dada0f73e6f17ea/. Diff revisado e git diff --check passou.
Obediencia do Copilot ao checklist ainda requer ensaio no cliente. POM/fontes e
documentos ja gerados da aplicacao nao foram alterados por esta evolucao.

## POM alinhado ao Hibernate do EAP 7.4 - 2026-09-30

- [x] Conferir raiz/branch/HEAD e isolar evolucao do lote ativo.
- [x] Exigir alinhamento do POM no plano e tarefa explicita no to-do.
- [x] Preservar essa entrega na revisao e na execucao com dispensa de precondicoes.
- [x] Atualizar guia/contrato e validar geracao de prompts e diff.

Validacao: Test-Planning.ps1 e Test-Implementation.ps1 passaram em PowerShell 5.1;
git diff --check passou. A obediencia do agente ao novo contrato requer ensaio
no Copilot. Prompts/planos ja gerados e checkout do lote ativo foram preservados.

## GO simples e dispensa explicita de precondicoes - 2026-09-30

- [x] Retomar branch do harness e identificar checkout do lote em uso.
- [x] Corrigir precedencia da decisao humana e reconciliacao no prompt.
- [x] Incluir bloco simples de GO nos modelos de plano/to-do e no guia.
- [x] Validar geracao/preservacao, revisar cenarios e registrar limites do ensaio.

  Test-Implementation, Test-Planning e Test-TaskInputs passaram em PowerShell 5.1.
  Geracao propaga o template completo e preserva documentos/evidencias; 47 links/
  ancoras e diff conferidos. Revisados: GO pendente, GO simples, dispensa geral,
  dispensa seletiva, estado antigo superado e conflito/revogacao vigentes.
  Nenhuma verificacao sem evidencia vira concluida. Interpretacao pelo Copilot
  permanece ensaio manual; nao foi executada corretiva nesta evolucao do harness.
  Plano/to-do locais ja estao sendo atualizados pelo Copilot e foram preservados.

## Escolha explicita da branch na implementacao - 2026-09-30

- [x] Confirmar tres escolhas e fallback manual/atual quando ID ausente.
- [x] Testar extracao do ID, menus e criacao Git em repositorios ficticios.
- [x] Integrar escolha na tarefa existente sem alterar a coleta Git informativa.
- [x] Atualizar contrato, guia e ADR com a excecao autorizada.
- [x] Revisar e validar regressao, sintaxe e preservacao das evidencias.

  Testes de implementacao/branch, Git, planejamento e tasks passaram, incluindo
  fallback 2/3 na mesma execucao apos erro de nome automatico/manual. Regressao:
  17 de 18 scripts passaram; Test-Mta falhou por input/pom.xml em uso por outro
  processo, inclusive na repeticao isolada. Test-Mta e Harness.psm1 sem alteracoes.
  67 links/ancoras, sintaxe e diff conferidos; 622 arquivos de configuracao/evidencias
  locais com hashes registrados para conferir preservacao na integracao.
- Pendencia na epoca: Diagnosticar bloqueio de arquivo na fixture Test-Mta antes de declarar regressao completa.

## Preparar implementacao do lote pelo DevSquad - 2026-09-30

- [x] Conferir checkout, isolar branch e confirmar abertura manual do prompt.
- [x] Testar preparo a partir do par de documentos, identidade, hashes e preservacao.
- [x] Implementar geracao, entrada e Run Task unica com selecao existente.
- [x] Definir prompt DevSquad com GO, escopo, verificacoes e aceite separados.
- [x] Atualizar guia/contrato e validar regressao, sintaxe, links e diff.
  Os 17 scripts Test-*.ps1 passaram em Windows PowerShell 5.1, incluindo entrada
  real e editor simulado. Test-Mta teve uma falha de arquivo em uso na fixture;
  repeticao isolada passou. 67 links/ancoras, sintaxe e diff conferidos.
  Worktree encurtado para .harness/i apos limite de caminho no teste de planejamento.
  Revisao local concluida; testes nao acionaram DevSquad nem corretivas reais.
- Pendencia na epoca: Operador: ensaiar Executar Prompt, delegacao e corretiva autorizada no Copilot.

## Criterios Sonar e padroes de configuracao - 2026-09-29

- [x] Confirmar Blocker/High reprovando; cobertura <85% e aumento de issues como avisos.
- [x] Implementar avaliacao separada do Gate e resumo com motivos/valores.
- [x] Comparar baseline ANTES explicitamente selecionado, preservando historico.
- [x] Acrescentar padroes Sonar ausentes ao abrir configuracao, mantendo overrides.
- [x] Documentar padroes, compatibilidade, metricas MQR e limites da comparacao.
- [x] Concluir testes de criterios, configuracao, regressao e revisao local.
  Sonar simulado, 52 verificacoes HTTP, tasks, build-config, workspace e limpeza
  passaram. Sintaxe e diff conferidos; entrega local sem push.
- Pendencia na epoca: Operador: ensaiar novos criterios no servidor real; nao equivale a GO.

## Integracao SonarQube - 2026-09-29

- [x] Recuperar contratos pertinentes do template anterior e documentacao oficial.
- [x] Testar configuracao, envio Maven, CE, gate, metricas e protecao do token.
- [x] Implementar tarefa unica, entrada oculta e resultados por projeto/data/ID.
- [x] Atualizar guia/configuracao e explicar baseline, cobertura e limites.
- [x] Validar regressao e revisar antes de entregar na branch do harness.
  Sonar simulado, 52 verificacoes HTTP e regressao build/config/workspace/target/
  tasks/limpeza passaram em PowerShell 5.1. Sem scan ou token reais.
- [x] Ensaio real com servidor/token do operador (nao equivale a GO da aplicacao).
  RunId 9bdf2bed884f47ebaa7a0f9ab861f8ce, 2026-09-29: scanner/CE sucesso,
  Gate OK, cobertura 100%, 2 issues; novas severidades/criterios ainda nao coletados.

## Consolidacao do guia para demonstracao - 2026-09-29

- [x] Consolidar opcoes 1/2, Previous e correcao da revisao no guia.
- [x] Criar exemplo limpo com feedback, LEIA-ME preenchido e roteiro de demonstracao.
- [x] Explicar continuidade: evidencias/precondicoes, GO, execucao separada,
  verificacoes e aceite; distinguir tasks disponiveis de atividades externas.
- [x] Conferir links/ancoras, tarefas, limites do ensaio e diff.
  55 links/ancoras locais conferidos; tarefas e prompts citados existem.
  Integracao/publicacao desta entrega ficam registradas no trace local e no Git.

## Preparo explicito de revisao - 2026-09-29

- [x] Reproduzir a falta de modo de revisao nos testes de planejamento.
- [x] Acrescentar selecao na task existente, Previous obrigatorio e indice explicito.
- [x] Gerar/abrir prompt de revisao e chamada /revisar-lote com caminhos reais.
- [x] Atualizar guia, modelo e contrato, incluindo identificacao de Previous.
- [x] Validar os fluxos e revisar o diff; registrar entrega na branch do harness.
  Test-Planning, Test-TaskInputs e Test-EvidenceFolder passaram em PowerShell 5.1;
  34 links locais e diff conferidos. Execucao do agente no Copilot nao simulada.
- [x] Integrar a entrega revisada na principal e, em etapa explicita, na integracao EAP 7.4.
  Commit 34992f8 integrado localmente por fast-forward em main e main_jboss_eap74.
  Checkout do ensaio mantido na mesma branch; exemplos sem diff. Sem push nesta entrega.

## Situacao do ensaio e pendencias - 2026-09-29

O trace local referenciado em [plan.md](plan.md#consolidacao-do-guia-para-demonstracao---2026-09-29)
e a fonte unica do diario. Referencias antigas abaixo sao historicas; nao
reiniciar o ensaio nem reutilizar solicitacoes apagadas.

- [x] Proposta inicial com MTA 13e178eb9c804e5e97a9190dbdd36816 produzida;
  plan.md/to-do e estado PROPOSTA - NAO APROVADA conferidos no disco.
- [x] Revisao com feedback, Previous e build ANTES produzida; quatro pontos e
  ajustes documentais conferidos nos dois destinos, anteriores preservados.
  Delegacao relatada pelo operador; leitura de memoria nao verificada permanece
  como limitacao explicita. Isso nao comprova conformidade integral das leituras.
- Pendencia na epoca: Operador: ensaiar continuidade com novo MTA e Previous do ciclo atual;
  conferir reconciliacao tecnica e pendencias. Outro lote somente apos aceite
  do atual e pedido explicito. Corretivas e seus testes pertencem ao plano da aplicacao.
- [x] Consolidar aprendizados confirmados do percurso documental no guia e exemplo,
  preservando limites. Consolidacao de nova rodada/execucao/aceite depende de
  ensaios futuros; nao foram declarados concluidos.

## Backlog futuro - ainda requer planejamento

- Retomado em Integracao SonarQube acima: scanner Maven local com servidor
  corporativo ou Docker. Validacao integrada real permanece explicita nessa entrega.
- [x] Planejar release/deploy para JBoss EAP 7.1 e 7.4, destinos confirmados pelo
  desenvolvedor em 2026-09-28 e configurados em tools.eap71Home/tools.eap74Home
  no JSON local. Detalhar selecao do servidor, artefato, implantacao e rollback;
  as corretivas de migracao continuam destinadas ao EAP 7.4.
- [x] Planejar start/stop e consulta de estado do JBoss, coordenados com o deploy.
  Implementado e ensaiado em JBoss local: operacoes, releases e debug Java (2026-10-02),
  com menu de acoes separadas conforme escolha do desenvolvedor.

Classificar futuras operacoes nos prefixos da etapa definidos em AGENTS.md.
Detalhar contratos e criterios quando solicitadas; este backlog nao autoriza execucao.

## Historico de entregas e ensaios

Os registros seguintes preservam o que foi pedido/feito em cada data. Controles
Git da ADR-0003 e tarefas de retomada de solicitacoes anteriores ao reinicio estao
SUPERADOS, sem serem contabilizados como testes executados. Quantidades antigas
de Run Tasks e instrucoes de entregas passadas nao substituem o catalogo atual.
As pendencias vigentes estao exclusivamente nas duas secoes acima.

## Horario local no menu de planejamento - 2026-09-28

- [x] Corrigir ultima elegivel/historico, atualizar guia e validar Test-Planning.
  Regressao reproduzida antes da correcao; suite passou em PowerShell 5.1 apos
  reutilizar Format-HarnessDate. Recibos e ordem das rodadas preservados.


## Tarefa de evidencias e percurso de feedback - 2026-09-28

- [x] Criar tarefa por projeto e LEIA-ME com identidade e instrucoes.
- [x] Documentar percurso completo de feedback com MTA novo e Previous.
- [x] Validar criacao, isolamento, cancelamento, repeticao e catalogo; revisar.
  Test-EvidenceFolder e Test-TaskInputs passaram em PowerShell 5.1; editor simulado.


## Evidencias complementares e revisao de lote - 2026-09-28

- [x] Registrar contrato: prompt separado, indice e area local, sem hashes adicionais.
- [x] Criar prompt de revisao, modelo de indice, pasta do ensaio e guia operacional.
- [x] Verificar ferramentas, 23 links locais e preview de limpeza -All; revisar.
- Ensaio com evidencias consolidado em Pendencias atuais; implementacao concluida,
  validacao no Copilot ainda nao declarada concluida.

## Revisao manual documentada - 2026-09-28

- [x] Documentar observacoes manuais, salvamento, Previous, revisao e GO no guia;
  manter o README resumido com link direto para a nova secao.
- [x] Conferir contrato de selecao/hashes, links e diff antes da integracao.
  Fluxo conferido com o script; 14 links/ancoras do README validos e diff sem
  erros de whitespace. Apenas documentacao; nenhum script ou plano local alterado.

## Consistencia da revisao de planos - 2026-09-28

- [x] Ajustar template e guia para substituir instrucoes incompativeis e conferir
  consistencia integral, com precondicoes/GO separados de verificacoes/aceite.
- [x] Validar geracao do prompt e preservacao do historico; revisar antes de integrar.
  Test-Planning passou em Windows PowerShell 5.1: template propagado, destinos e
  historico preservados. Diff revisado e sem erros de whitespace. A consistencia
  semantica do texto produzido pelo modelo depende do ensaio do operador abaixo.
- SUPERADO pelo reinicio: retomada de ddd2954b81a3 / RC-MTA-f1f0d80b-001.
  A verificacao de consistencia permanece no ensaio atual, sem exigir esses arquivos.

## Roteiro resumido no README - 2026-09-28

- [x] Acrescentar sequencia curta das Run Tasks e links para os detalhes do guia.
- [x] Conferir nomes de tarefas, links/ancoras e diff antes da integracao.
  14 links locais (incluindo ancoras) e 8 referencias a tarefas validados;
  git diff --check sem erros. Alteracao somente documental.

## Git informativo, sem controle de branches — 2026-09-28

- [x] Conferir checkout e criar harness/git-informativo em worktree isolado.
- [x] Remover cadastro/gate e tarefa Git; preservar coleta informativa.
- [x] Alinhar prompt, instrucoes, ADR e guia ao fluxo decidido pelo desenvolvedor.
- [x] Testar ausencia de menus/bloqueios, historico e integridade MTA; revisar.
  Os 11 testes Test-*.ps1 passaram em PowerShell 5.1; 52 links/ancoras locais
  conferidos e git diff --check sem erros. Test-Git falhou antes da remocao
  da politica e passou depois. Revisao confirmou ausencia de consumidores do gate.
- [x] Integrar a entrega e preparar contexto vinculado sem modificar o plano antigo.
  Implementacao 101c57b nas mains, apoio e branch atual corretiva/cache-hib-001.
  Nova solicitacao e450f0ea38ec vinculada a 31a8ff4cb385, mesmo MTA.
  Hashes dos 14 arquivos protegidos preservados; exemplos sem alteracoes.
- SUPERADO pelo reinicio: continuidade da solicitacao antiga CACHE-HIB-001.
  Ausencia de gates Git e preservacao de pendencias sao verificadas no ciclo atual.


## Delegacao delimitada no DevSquad — 2026-09-28

- [x] Conferir Git e criar harness/devsquad-planejamento a partir da main em
  worktree separado, preservando o checkout da migracao.
- [x] Habilitar delegacao ao planejador e definir contrato de retorno/gravacao.
- [x] Atualizar guia e especificacao, incluindo ferramentas proprias dos subagentes.
- [x] Validar preparacao, historico e tarefas; revisar antes da integracao.
  Test-Planning e Test-TaskInputs passaram em Windows PowerShell 5.1. Contrato
  revisado; ensaio de subagentes no cliente continua separado e pendente.
- [x] Integrar o ajuste 7851782 por fast-forward na main e depois na
  main_jboss_eap74, preservando o checkout da migracao e as solicitacoes antigas.
- SUPERADO pelo reinicio: pedido de vincular MTA 391c4a605054 a 8288c85ebd61.
  Verificacao de delegacao e persistencia consolidada em Pendencias atuais.

## Retomada da sessao — 2026-09-27

Registro historico, substituido pelo ponto atual de 2026-09-28 no inicio deste
documento e do plano. Nao repetir o roteiro antigo nem reutilizar seus contextos.
Tarefas da aplicacao continuam somente nos PlanPath/TodoPath do contexto selecionado.

## Entregas concluidas

- [x] Criar harness/separacao-branches a partir da main antes de registrar a
  regra de branch exclusiva para alteracoes do harness, preservando o trabalho local.
- [x] Alinhar AGENTS.md, Copilot, ADR-0002 e guia com a separacao de branches.

- [x] Validar e publicar guia/prompt nas branches main e main_jboss_eap74;
  remover a branch antecipada lote/cache-hib-001 e deixar checkout na integracao.
  Commit 74fca9b publicado nas duas branches por fast-forward; lote local/remoto
  removido sem commits exclusivos. Test-Planning.ps1 passou, 14 links locais
  conferidos e revisao estatica independente sem correcoes requeridas.
- [x] Orientar o planejador a solicitar a branch apos persistir a proposta,
  sem executar Git; exigir novo contexto/conferencia e GO para a corretiva.
- [x] Adaptar o guia fornecido de Git/TortoiseGit e vincular ao fluxo principal ->
  EAP 7.4, lote -> EAP 7.4 e migracao validada -> principal/release/PRD.

- [x] Esclarecer no guia a ordem MTA -> proposta -> branch do lote -> GO,
  as escolhas no menu e o retorno a base EAP 7.4 integrada para novo MTA antes
  do proximo lote. Registrar limites diante de commits concorrentes.
- [x] Explicitar nova analise completa da base integrada apos commits de colegas,
  sem combinar relatorios individuais nem apagar o historico para reanalisar.

## Concluido: consolidacao Git do harness

- [x] Revisar entrega, executar 11 testes e conferir remoto/arquivos ignorados.
  Revisao estatica independente sem bloqueantes; 56 links locais conferidos.
  Configuracao local, workspace local e .harness ignorados; exemplos sem alteracoes.
- [x] Consolidar commits na main e fazer push; criar/publicar main_jboss_eap74
  e lote/cache-hib-001, mantendo o checkout do lote limpo.
  Implementacao ee1f199 e documentacao 48cd359 integradas por fast-forward;
  main e ambas as branches publicadas em origin, sem force. Corretivas nao aplicadas.
- [x] Ensaio real apos defaults Maven: build 4f313156cb544767bce0e1410dfe15b3
  e MTA 5cc84cfbfee345d1a1ae043ebdfec115 bem-sucedidos; relatorio aberto pelo usuario.

- [x] Completar no guia o mapa das pastas .harness: conteudo, criacao sob demanda,
  arquivos de controle e destinos externos (fontes, target e repositorio Maven).

## Concluido: padroes Maven da maquina

- [x] Remover settings especifico do harness no JSON local e workspace.
- [x] Registrar regra de configuracao minima em AGENTS.md/guia e validar defaults.
  Test-BuildConfig passou; settings global da maquina nao redefine localRepository
  e nao existe settings do usuario. Cache antigo movido, sem copia, para
  backups-temporarios/maven-ensaio (14.103 arquivos); Maven padrao nao foi alterado.
- [x] Ajustar limpeza para caminhos longos do cache arquivado; Test-Cleanup passou
  com arquivo >260 caracteres, cancelamento, junction e isolamento. Sem novo build/MTA.

## Concluido: backups temporarios em um unico local

- [x] Registrar convencao unica para agentes e no guia.
- [x] Acrescentar opcao 3 de backups temporarios na tarefa existente; Test-Cleanup
  passou com menu real, preview, cancelamento, junction e isolamento dos escopos.
- [x] Reunir seis arquivos avulsos restantes em backups-temporarios, com hashes
  preservados. Remover pom-depois-backups, pom-eap74-backups e fixtures .harness/tests
  conforme pedidos explicitos. Configuracao, workspace, settings Maven e POMs
  atuais conferidos por hash e preservados. Tests sera recriada nos proximos testes.

## Entrega: limpeza de execucoes, corretiva Git e guia do desenvolvedor

- [x] Implementar limpeza com preview/confirmacao, projeto ou todos, caminhos
  contidos, recusa de links e bloqueio de execucao concorrente. Test-Cleanup.ps1.
- [x] Integrar `Workspace: limpar execucoes`, proteger preparacao de contexto
  durante limpeza e documentar limites. Test-TaskInputs.ps1 e Test-Planning.ps1.
- [x] Confirmar escopo: automacao Git do harness e menu de limpeza por projeto/todos.
- [x] Coletar Git nos novos recibos, cadastrar papeis das branches por Source e
  conferir identidade/estado/alinhamento local antes de executar/retomar.
- [x] Manter README resumido e mover operacao para o guia do desenvolvedor,
  incluindo branches, decisoes dos menus, consulta e limpeza. Atualizar ADR/contrato.
- [x] Verificar Test-Git, Test-Cleanup, Test-Planning, Test-Mta, Test-Build e
  Test-TaskInputs; sintaxe PowerShell, 56 links/ancoras e diff sem erros.
- SUPERADO pela ADR-0004: ensaio de cadastro de branches/conferencia Git removido
  do escopo; nao reimplementar nem marcar como verificacao executada.
- [x] Ensaio de limpeza real pelo menu confirmado pelo desenvolvedor: opcao 2,
  confirmacao LIMPAR e oito caminhos removidos. Novos testes usaram fixtures.

## Concluido: padrao de nomes para MTA e builds

Escopo e aceite no [plano atual](plan.md). Implementacao autorizada em 2026-09-27;
preservar historico e nao criar comandos de exportacao.

Regra transversal: preservar as 12 Run Tasks atuais, classificadas por prefixo
Workspace:, Aplicacao:, MTA: e Planejamento:. Reutilizar selecoes/parametros;
nao criar tarefas por projeto, rodada, arquivo ou formato de armazenamento.

- [x] 1. Reutilizar convencao de nome/chave/data no modulo comum, preservando
  o formato atual de planejamento. Verificar Test-Planning.ps1.
- [x] 2. Atualizar descoberta de rodadas, ultimo relatorio, MTA ativo, logs e
  selecao para planejamento, aceitando formatos antigo/novo. Depende de 1;
  verificar Test-MtaLog.ps1, Test-MtaActive.ps1 e Test-Planning.ps1.
- [x] 3. Adotar novas pastas na gravacao MTA, preservando snapshot, argumentos,
  hashes e vinculos. Depende de 2; verificar Test-Mta.ps1 e Test-Planning.ps1.
- [x] 4. Adotar a mesma convencao em builds, preservando RunId, logs, resultado
  e lock. Depende de 1, apos 3; verificar Test-Build.ps1 e Test-BuildConfig.ps1.
- [x] 5. Atualizar guia/especificacao existentes e conferir copia completa do
  relatorio HTML fora do repositorio. Depende de 3 e 4; executar nove testes e
  ensaio de consulta. Conferir prefixos, labels unicos e catalogo sem novas tarefas
  em Test-TaskInputs.ps1. Compartilhamento sem publicar/enviar automaticamente.

Verificacao em 2026-09-27: nove testes passaram, usando Maven/MTA simulados;
historico antigo/novo, identidades divergentes, ambiguidade, datas e tarefas
conferidos. Plano/to-do reais acessiveis no caminho antigo; quatro hashes MTA
conferem com o recibo original. Documentacao atualizada e copia completa do HTML
fora do repositorio com 23 hashes identicos. O desenvolvedor confirmou depois a
navegacao do relatorio original e da copia externa da nova rodada, e a abertura
dos dois documentos pela tarefa no VS Code. Etapa 5 concluida por ensaio manual
relatado, complementando os testes automatizados. Corretivas nao aplicadas.

## Ajuste atual: persistir orientacoes do ensaio no template

- [x] Incorporar continuidade do mesmo lote ainda nao aplicado/aprovado, usando
  seu ID historico; manter escrita nos destinos atuais e preservar o anterior.
- [x] Corrigir origem da versao MTA, comparacao de argumentos, limite da evidencia
  dependencies.yaml e referencia a pastas antigas/novas no template.
- [x] Verificar a preparacao pelo Test-Planning.ps1. Preservar o prompt/recibo
  real 8b54d7ca896d4d5ca5b255fbfcb7b4a5; nao criar outra solicitacao real.
  Resultado: teste passou e git diff --check sem erros de whitespace.

Ensaio manual relatado: build 5c8fb48f6c884af68b44d2d8dea41691 e MTA
db4a1abd43b04997bffac947242dfd87 concluidos com sucesso; monitor interno exibiu
resultado final; relatorio original e copia externa abriram e foram conferidos.
Copilot gravou a proposta vinculada, mantendo CACHE-HIB-001 nao aprovado. Leitura
local confirmou documentos e hashes das evidencias/historico preservados. Revisao
de precisao enviada pelo operador ao Copilot e conferida nos arquivos: versao
em result.json, opcoes equivalentes com caminhos diferentes e dependencias MTA
sem alegar resolucao Maven atual validada. Abertura dos dois documentos pela
tarefa confirmada pelo operador para a solicitacao das 15:34:11.

## Historico: backlog registrado durante a reestruturacao

Sonar, deploy/release e operacao do servidor foram mantidos no Backlog futuro
no inicio deste arquivo, sem duplicar tarefas abertas. A convencao continua por
projeto/data/hora/ID, com selecoes de ambiente e sem tarefas por servidor/projeto.

## Historico e pendencias anteriores

- [x] Selecao e validacao de rodadas (modulo + teste).
  Aceite: projetos isolados, ultima elegivel, historico, cancelamento e recusas.
  Verificacao: Test-Planning.ps1 passou neste incremento.
- [x] Preparacao de contexto e entrada PowerShell (depende da selecao).
  Aceite: RunId fixo, solicitacao unica e preservacao de fontes/evidencias.
  Verificacao: teste ampliado passou com menus reais e ferramentas ausentes.
- [x] Integracao e documentacao (depende da preparacao).
  Aceite: tarefa fornece workspace/editor; prompt define complexidade e rotas;
  README orienta uso e categorias de documentacao possuem finalidades distintas.
  Verificacao: Test-TaskInputs.ps1, links e revisao do diff aprovados.
- [x] Verificacao dos scripts e evidencias (depende da integracao).
  Aceite: suite Test-*.ps1 e preparacao com rodada real sem executar MTA.
  Resultado: nove scripts passaram. Rodada real b8913bad9ab84c2499d8e69fdad58a21
  preparada, hashes das evidencias e workspace preservados. Editor verificado
  com substituto que captura argumentos, sem acionar Copilot.
- [x] Ensaio de leitura/proposta relatado pelo desenvolvedor: executar prompt no Copilot Local,
  conferir ferramentas, projeto/RunId, leituras e proposta rastreavel.
  Evidencia: resposta compartilhada da rodada b8913bad9ab84c2499d8e69fdad58a21,
  com leituras, deduplicacao e proposta. A forma de abertura na interface nao foi registrada.
- [x] Separar premissas confirmadas, evidencias e pendencias no contexto/prompt.
  Aceite: Hibernate 5.3 e premissa do destino; API candidata e runtime efetivo
  continuam sujeitos a validacao. Nao presumir que toda aplicacao utiliza Hibernate.
- [x] Exigir conferencia de POMs/dependencias por lote, com referencias, ajustes,
  estado e pendencias para executar; leitura nao equivale a resolucao/build validados.
- [x] Validar novo contexto e atualizar documentacao existente.
  Verificacao: Test-Planning.ps1, preparacao da mesma rodada e preservacao dos prompts antigos.
  Resultado: teste passou; contexto df18301211f44a5cbbe50b03f52c8701 preparado;
  hashes das evidencias e solicitacoes anteriores preservados.
- [x] Conferir a resposta do Copilot ao novo contexto: premissas separadas de
  verificacoes e analise de POMs/dependencias por lote. Resposta compartilhada
  pelo desenvolvedor conferida com POM, fonte, regras e resultado da rodada.
  Atende ao planejamento preliminar; ainda ha pendencias de resolucao/runtime.
  Pontos da revisao: explicitar ajuste da propriedade hibernate.version no lote,
  separar o que foi conferido das pendencias e limitar buscas aos YAML autorizados
  em vez de output/**, que tambem contem logs.
- [x] Persistencia das corretivas: PlanPath/TodoPath exclusivos por solicitacao;
  teste de isolamento e preservacao de documentos anteriores.
- [x] Rastreabilidade entre rodadas: recibo com hashes, menu de proposta anterior,
  identidades separadas, recusas de evidencia alterada e cruzamento entre projetos.
- [x] Contrato progressivo: um lote ativo por objetivo, leitura delimitada,
  cobertura parcial, escrita de plan/todo e retomada sem planejamento global.
- [x] Ajustes da revisao: POM explicito, estados por verificacao e buscas YAML.
- [x] Verificar scripts/contexto real e documentar fluxo sem misturar tasks/.
  Resultado: nove scripts Test-*.ps1 passaram, incluindo escolha/cancelamento
  reais do menu anterior e vinculo de RunIds diferentes. Contexto real
  5ac3c123bfca4001aeb3728ec9efb778 preparado para b8913bad9ab84c2499d8e69fdad58a21;
  hashes dos quatro artefatos MTA, documentos anteriores e workspace preservados.
- [x] Registrar ADR-0002 e alinhar instrucoes de agentes/Copilot, prompt e guia:
  trabalhos separados, lote unico, verificacoes automaticas e revisoes humanas,
  continuidade com novo MTA ate a conclusao verificada. Conferir links e preparacao.
  Verificacao em 2026-09-27: Test-Planning.ps1 passou em PowerShell 5.1 fora do
  sandbox, sem alterar ExecutionPolicy; 21 links locais conferidos e diff sem
  erros de whitespace. Comportamento no Copilot segue pendente dos ensaios abaixo.
- [x] Registrar e verificar ADR-0003, prompt e instrucoes: projeto/repositorio,
  branch/HEAD, alinhamento com a principal e um lote por frente coordenada.
  Verificacao em 2026-09-27: Test-Planning.ps1 passou; 27 links locais conferidos
  e git diff --check sem erros. Isso valida a preparacao, nao a conferencia Git
  automatica nem o comportamento do Copilot em trabalho concorrente.
- [x] Organizar pastas de planejamento por projeto/datas/IDs e abrir plano/to-do
  pela tarefa, preservando historico e testando selecao, isolamento e abertura.
  Verificacao em 2026-09-27: nove scripts Test-*.ps1 passaram e diff sem erros
  de whitespace. Planejamento cobre os dois formatos, datas/fuso, rotulos renomeados,
  projetos homonimos, destino divergente, abertura/cancelamento pela entrada real
  com editor simulado e hashes dos documentos preservados. A nova entrada localizou
  plan/todo reais de 6901b92111044988ad778f7411c1dba7 com -NoOpen. Historico real
  permaneceu no lugar; novos contextos adotam nomes legiveis. Sem novo MTA/Copilot.
- [x] Automatizar coleta e conferencia Git conforme ADR-0003; entrega acima.
  Conferencia retorna exit 1 para pendencias. Execucao de corretivas ainda e etapa
  separada; nao ha monitoramento continuo, fetch ou aceite seletivo de diff local.
- [x] Configurar devsquad e uso delimitado de skills de SDLC no template;
  validar geracao e preparar contexto atualizado com o MTA existente.
  Verificacao: Test-Planning.ps1 e git diff --check passaram. Solicitacao real
  7abd202ccbda431c96416d2b6bbf3cf4 preparada para a rodada
  b8913bad9ab84c2499d8e69fdad58a21 de migracao-cache-antes; template e hashes MTA
  conferidos. Plan/todo aguardam o agente. Integracao no Copilot ainda nao ensaiada.
- [x] Ensaio de planejamento/gravação no Copilot com devsquad, relatado pelo
  desenvolvedor e conferido nos arquivos em 2026-09-27. Solicitacao
  6901b92111044988ad778f7411c1dba7, rodada b8913bad9ab84c2499d8e69fdad58a21:
  plan.md e todo.md identificam um lote CACHE-HIB-001, proposta nao aprovada,
  POM/dependencias, cobertura parcial, pendencias Git/runtime e revisoes humanas.
  Hashes das quatro evidencias conferidos e sete arquivos relevantes iguais ao
  snapshot MTA; nenhuma corretiva aplicada nesses arquivos. Skills relatadas:
  complexity-analysis, documentation-style e test-discipline. A primeira tentativa
  parou por falta de delegacao; a segunda concluiu sem delegar. Skill
  planning-and-task-breakdown indisponivel no caminho tentado. Busca em rules/**
  deve ser restringida aos YAML pertinentes nos proximos ensaios.
- SUPERADO pelo reinicio: retomada de 6901b92111044988ad778f7411c1dba7.
  A orientacao antiga "sem delegar" foi substituida pelo contrato devsquad.plan.
  Retomada e reconciliacao com novo MTA estao consolidadas em Pendencias atuais.
