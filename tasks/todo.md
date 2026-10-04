# To-do do agente: evolucao do harness

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

Trabalho pausado a pedido do desenvolvedor. Continuar pelo
[registro de retomada e diagnostico](plan.md#retomada-apos-a-pausa-de-2026-10-03),
na branch `harness/backlog-agente-orientacao`, sem reiniciar as entregas prontas.

- [ ] Isolar os hooks do DevSquad e confirmar resposta do Copilot em conversa padrao.
- [ ] Retomar teste leitor do `migracao_helper` no Copilot, conferindo fontes e ausencia de escrita.
- [x] Confirmar descoberta de `orientar-migracao` no Codex do VS Code: desenvolvedor informou que ja aparece.
- [ ] Validar orientacao e delegacao no Codex com a skill ja disponivel.
- [ ] Completar VAL-01 nos dois clientes antes dos executores. Testes simulados nao substituem essa validacao.

## Backlog vigente

| ID | Estado / ordem | Proxima entrega |
| --- | --- | --- |
| SDLC-01 | Concluida | Preparo de planejamento/reconciliacao por CLI com escolhas explicitas, validacao antes de escrita e saida estruturada. |
| SDLC-02 | Concluida | Skill compartilhada de orientacao pelo estado efetivo e pelos guias. |
| SDLC-03 | Implementada; aguarda VAL-01 | Orquestrador helper e helpers de preparo, reconciliacao, planejamento, impacto e implementacao; humano executor nos dois clientes. |
| SDLC-04 | Apos SDLC-03 / VAL-01 | Orquestrador executor e especialista de preparo; modo delegado e retorno ao humano. |
| SDLC-05 | Apos SDLC-04 | Executores das demais etapas, reutilizando os helpers ja entregues; consumir matriz COMP-01 e coleta Java opcional. |
| SDLC-06 | Conforme necessidade | Adequar uma acao existente por vez: branch explicita, Sonar assistido, build/MTA/JBoss e limpeza. |
| COMP-01 | Capacidade solicitada | Coletor deterministico das dependencias Maven e prompt especifico de matriz por projeto: compatibilidade, fontes, pendencias e acao recomendada, sem alterar POM. |
| CORE-01 | Piloto opcional transversal | Navegacao/coleta de contexto Java para compreensao pelo desenvolvedor e apoio ao SDLC, independente de MTA/engine. |
| SERV-01 | Capacidade solicitada; validar rota primeiro | Migrar configuracao/subsistemas e inventariar drivers, modulos e recursos necessarios; ferramenta oficial/CLI e prompt/helper com evidencias, acoes e validacao no destino isolado. |
| VAL-01 | Iniciada; chat Copilot com falha, em pausa | Descoberta da skill confirmada no Codex; isolar falha dos hooks DevSquad no Copilot e validar orientacao/delegacao nos dois clientes pelo mesmo contexto, capacidades presentes/ausentes/inadequadas e ausencia de efeitos operacionais; casos do plano. |
| VAL-02 | Ensaio operacional existente pendente | Prompts Copilot: reconciliacao/delegacao, issues, persistencia, retomada, GO, implementacao e continuidade com Previous/novo MTA. |
| VAL-03 | Ensaio Sonar real pendente | Criterios Blocker/High, avisos de cobertura e comparacao com baseline, separados do Quality Gate. |
| DEC-01 | Decisao futura | Decidir preparo de deploy com servidor parado; deploy atual exige servidor ativo. |
| EVO-01 | Futuro, apos priorizacao | Demais fatias da estrategia: nucleo, Node.js/TypeScript, IntelliJ, Quarkus, outros engines e entrega/operacao. |

Criterios, dependencias e arquivos por fatia estao na
[sequencia de implementacao](plan.md#sequencia-e-verificacao). COMP-01 e independente
do explorador CORE-01; ambos fornecem evidencias, sem ampliar ferramentas do
planejador atual. SERV-01 nao e deploy offline nem autorizacao para migrar o EAP
local. Os prompts existentes seguem Copilot/DevSquad ate adaptacao e ensaio Codex.

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
