# Plano do agente: evolucao do harness

## Horario local no menu de planejamento - 2026-09-28

Bug observado: ultima elegivel e historico MTA exibem UTC, enquanto pastas e
historico de planos usam horario local com fuso. Branch harness/horario-planejamento
a partir de main 78235c3. Reutilizar Format-HarnessDate nas duas mensagens;
manter datas/ordenacao/recibos em UTC. Testar exibicao e selecao no Test-Planning.


## Tarefa de evidencias e percurso de feedback - 2026-09-28

Pedido: criar estrutura por projeto via Run Task e explicar feedback -> build/MTA
novo -> evidencias -> contexto com Previous -> revisar-lote -> revisao humana.
Branch harness/tarefa-evidencias derivada de main 5f27366. Reutilizar selecao de
projeto, chave de pasta e formatacao de data. Criar somente pasta nova e LEIA-ME
com identidade/instrucoes, sem hashes de arquivos, MTA ou lote escolhido sozinho.
Atualizar modelo, guia, catalogo de tarefas e especificacao. Testar entrada real,
isolamento, repeticao sem sobrescrita, cancelamento e abertura do indice.

Implementado com entrada criar-pasta-evidencias.ps1 e modelo reutilizavel do guia.
Test-EvidenceFolder passou em PowerShell 5.1: selecao/cancelamento reais, caminhos
com espacos, homonimos isolados, repeticao preservada e editor simulado.
Test-TaskInputs passou com 14 tarefas. Guia e indice explicam o ciclo completo,
incluindo feedback documental sem novo MTA, Previous e GO/aceite separados.
Nenhum MTA, corretiva ou revisao Copilot foi executado nesta entrega.


## Evidencias complementares e revisao de lote - 2026-09-28

Pedido autorizado: guia, pasta por projeto/data e prompt separado de revisao;
sem hashes de arquivos adicionais. Branch harness/evidencias-revisao a partir
de main 46ce43c. Contrato em doc/especificacoes/planejamento-copilot.md.
Manter planejar-lotes e preparacao existentes; revisar-lote usa prompt preparado
com Previous e indice LEIA-ME das evidencias. Criar modelo de indice e pasta
local para migracao-cache-antes, sem inventar resultados. Validar ferramentas,
links, contrato de caminhos e limpeza preservando a nova area. Ensaio Copilot
fica com o operador; nao alterar plano/to-do da aplicacao nesta entrega.

Entrega implementada: revisar-lote, modelo do indice e secao operacional no guia.
Pasta local criada em .harness/evidencias/migracao-cache-antes__97a5fc995901/
evidencias_2026-09-28_16-10-43-0300/, somente LEIA-ME.md sem resultados inventados.
Verificado: ferramentas iguais ao prompt inicial, 23 links locais existentes,
git diff --check e preview real de limpeza -All sem a area evidencias.
Git confirma indice local ignorado. Template inicial, gerador e limpeza sem diff.
Revisao documental conferiu Previous, destinos, ausencia de hashes adicionais,
delegacao unica, limites e separacao entre precondicoes e validacoes posteriores.
Ensaio no Copilot permanece pendente; nao houve execucao de corretivas nesta entrega.

## Revisao manual documentada - 2026-09-28

Detalhar no guia o ciclo do desenvolvedor: abrir proposta, registrar observacoes,
salvar antes do novo contexto, selecionar Previous e revisar os novos documentos
do mesmo lote antes do GO. README mantem resumo e apenas aponta para essa secao.
Retomada de harness/consistencia-planejamento, alinhada a main 9a4ddce; escopo
somente documental, sem editar planos locais da aplicacao. Conferir o fluxo com
Select-MtaPreviousPlanning/New-MtaPlanningContextCore e validar links/ancoras.

## Consistencia da revisao de planos - 2026-09-28

Pedido: evitar que revisoes acrescentem orientacoes novas e preservem contradicoes
ativas em outras secoes. Evolucao do harness na branch harness/consistencia-planejamento,
derivada de main d8bce9a. Atualizar o template e o guia: substituir orientacoes
incompativeis, conferir documentos completos e distinguir precondicoes/GO de
verificacoes posteriores/aceite, incluindo baseline antes de qualquer alteracao.
Validar propagacao pelo teste existente de planejamento, revisar o diff e integrar.
Nao alterar o plano da aplicacao nem prompts/recibos ja preparados. O operador
gerara novo contexto vinculado ao atual para ensaiar o contrato no DevSquad.

## Roteiro resumido no README - 2026-09-28

Pedido: apresentar o caminho operacional no README e remeter aos detalhes do guia.
Escopo documental: limpeza opcional, clean install, MTA, preparo de contexto,
execucao do prompt e revisao. Distinguir inicio independente de continuidade e
preparo de execucao do agente; preservar GO separado. Branch harness/readme-roteiro
derivada de main af79b9f, sem novo worktree. Conferir tarefas e links/ancoras antes
de integrar na principal e retornar a main_jboss_eap74.

## Simplificacao Git solicitada — 2026-09-28

Pedido: eliminar o controle de branches do harness e deixar a escolha/gestao
com o desenvolvedor. Branch harness/git-informativo derivada da main 71a3918,
em worktree isolado; checkout do operador em corretiva/cache-hib-001 preservado.

Remover cadastro gitPolicies, gate de prontidao Git e Run Task de conferencia.
Manter coleta informativa de repositorio/modulo, branch, commit e estado local,
sem exigir responsavel, coordenacao, branch principal/migracao ou novo contexto
apenas por trocar branch/HEAD. Politicas antigas ficam ignoradas; recibos e
planos historicos permanecem intactos. Manter integridade/identidade MTA, escopo
de escrita, GO separado e verificacoes tecnicas. Mudanca de codigo relevante
exige avaliar aplicabilidade dos achados; diferenca Git isolada nao bloqueia.

Atualizar scripts, prompt, instrucoes, ADR e guia, com testes para ausencia de
menu/gate, coleta sem politica e compatibilidade com historico. Integrar a
mudanca validada nas mains e na branch limpa do ensaio, sem mudar sua selecao.
Preparar contexto atualizado vinculado ao plano atual para destravar o ensaio.

Validacao concluida: 11 testes Test-*.ps1 em Windows PowerShell 5.1, incluindo
configuracao gitPolicies invalida/duplicada ignorada, preparo sem menu Git,
abertura/continuidade de recibo com politica antiga e preservacao do historico.
52 links/ancoras locais conferidos; diff sem erros. Revisao de codigo/contrato
sem consumidores remanescentes das funcoes removidas. A configuracao local nao
precisa ser limpa: a politica antiga e ignorada. Copilot ainda requer ensaio
do contrato atualizado; testes nao comprovam comportamento do modelo.

Entrega implementada em 101c57b e integrada por fast-forward em main,
main_jboss_eap74, harness/devsquad-planejamento e corretiva/cache-hib-001.
Contexto e450f0ea38ec440f84e6daf001be1051 preparado com o prompt atualizado,
mesmo MTA 391c4a60505440fdb26d4b6419bfa643 e Previous 31a8ff4cb3854db18ed3c67452d667e6.
O Copilot deve continuar CACHE-HIB-001 nos novos destinos, preservando o historico
e marcando exigencias Git antigas como superadas. Conferidos os hashes dos 14
arquivos locais protegidos, todos preservados; nenhum diff nos exemplos.
O ensaio do prompt novo no Copilot permanece com o operador. Avancos de HEAD
apenas para registrar esta entrega nao exigem outro contexto.


## Delegacao de planejamento DevSquad — 2026-09-28

Pedido autorizado: corrigir o conflito entre o condutor devsquad e o prompt que
proibia delegacao, preservando skills e escrita exclusiva de PlanPath/TodoPath.
Base: main em d8b4b04, checkout limpo; branch harness/devsquad-planejamento em
worktree isolado. Checkout da migracao permanece em main_jboss_eap74.

Usar o condutor nativo devsquad e uma delegacao delimitada a devsquad.plan.
O especialista devolve os dois documentos em memoria; o condutor valida destinos,
grava e rele os arquivos. Adaptar explicitamente o fluxo generico do plugin:
sem docs/, ADRs adicionais, board, terminal, implementacao ou subdelegacao.
As skills pertinentes continuam disponiveis por leitura, com relato de uso.
Nao modificar o plugin instalado nem as solicitacoes historicas.

Validar ferramentas no prompt gerado, identidade e preservacao dos documentos
anteriores em Test-Planning; conferir catalogo em Test-TaskInputs e revisar diff.
Depois de revisado, integrar explicitamente main -> main_jboss_eap74 e preparar
nova solicitacao com o template atualizado para o ensaio do desenvolvedor.
O MTA 391c4a60505440fdb26d4b6419bfa643 continua historico de d8b4b04;
mudanca apenas no harness exige registrar a diferenca de HEAD, sem reatribuir a rodada.
Aceite do comportamento no Copilot: PENDENTE do ensaio; testes locais validam
preparacao/contrato, nao execucao de subagentes ou obediencia ao escopo.

Verificado: Test-Planning.ps1 e Test-TaskInputs.ps1 passaram em Windows
PowerShell 5.1, sem alterar ExecutionPolicy. O teste de ferramentas falhou antes
do ajuste e passou com agent habilitado. Worktree movido para temporario curto
por limite de caminhos do PowerShell 5.1; checkout de migracao preservado.
Revisao do contrato/diff: delegacao de um nivel, perfis proprios tratados como
limites comportamentais, defaults do plugin adaptados explicitamente.
Os nove arquivos da aplicacao registrados no manifesto MTA mantem os hashes.
Foram encontrados plan.md/todo.md na solicitacao 8288c85ebd61476381fa7dfbcb7fe841;
preserva-los e vincular a nova solicitacao a ela, mantendo o lote existente.
Esses arquivos nao comprovam o ensaio da nova delegacao.

Integracao local concluida: ajuste 7851782 levado por fast-forward a main e
depois a main_jboss_eap74. Checkout da migracao mantido limpo nessa branch.
O desenvolvedor repetira a tarefa de preparar contexto no VS Code, selecionando
o MTA 391c4a605054 e a proposta anterior 8288c85ebd61. O novo contexto registrara
o HEAD atual e preservara MtaGit da rodada; nao reutilizar o prompt antigo para
testar a delegacao nova. Encerrar o ensaio apos persistir e conferir os dois
documentos; branch de lote, conferencia Git e GO continuam etapas posteriores.

## Ponto de retomada — 2026-09-27

Sessao encerrada a pedido do desenvolvedor. Antes deste registro, main e
main_jboss_eap74 estavam limpas, publicadas e alinhadas em f61798d. As branches
lote/cache-hib-001 e harness/separacao-branches foram removidas local/remotamente
apos confirmar integracao completa. Este registro usa harness/ponto-retomada
e deve ser integrado/publicado nas duas bases, retornando o checkout a EAP 7.4.

Entregue: fluxo progressivo na base integrada, solicitacao da branch de lote pelo
planejador depois da proposta, branch propria para evoluir o harness, guia Git/
TortoiseGit adaptado e ligado ao guia do desenvolvedor. Validacoes: Test-Planning.ps1,
14 links locais, diff --check e revisao estatica independente aprovados na entrega.
Nenhuma corretiva da aplicacao foi aplicada nesta etapa; nao houve GO de execucao.

Retomar com o desenvolvedor, passo a passo, aguardando o resultado de cada etapa:

1. Conferir checkout limpo em main_jboss_eap74 e referencias atualizadas. Abrir
   jboss-mta-harness.local.code-workspace; projeto migracao-cache-antes.
2. Executar Aplicacao: build Maven (Java 8), escolhendo clean install.
3. Executar novo MTA completo dessa base e conferir SUCCEEDED/integridade/relatorio.
4. Preparar contexto com essa rodada. Sem lote definido, Enter deixa a politica
   Git pendente para proposta preliminar; nao inventar branch de trabalho.
5. Executar o prompt atualizado no Copilot/devsquad. O agente grava somente
   plan.md/todo.md e solicita a criacao da branch apos delimitar o lote.
6. Depois da criacao confirmada pelo desenvolvedor, cadastrar a frente, preparar
   contexto vinculado, conferir Git e obter GO antes de executar a corretiva.

O build 4f313156cb544767bce0e1410dfe15b3 e MTA 5cc84cfbfee345d1a1ae043ebdfec115
sao historicos anteriores a essa base; nao atribuir a eles o HEAD/branch atual.
Solicitacoes antigas citadas abaixo podem ter sido apagadas pela limpeza autorizada;
nao reutilizar seus caminhos sem verificar existencia e identidade.
Configuracao local, workspace e .harness sao ignorados pelo Git: o commit deste
ponto preserva documentacao/codigo versionados, nao e backup desses dados locais.
Java/Maven continuam separados entre MTA e build, com settings opcionais null
e repositorio Maven padrao da maquina. Sonar/deploy/servidor continuam backlog.

Qualquer nova evolucao do harness deve comecar em harness/<objetivo> a partir
da main, preservando o checkout da migracao. Apos cada lote aceito e integrado,
novo build/MTA da base EAP 7.4 orienta a proposta seguinte.

## Regra de trabalho: branch exclusiva do harness

Por solicitacao do desenvolvedor, novas alteracoes do harness usam
`harness/<objetivo>` a partir da principal, com revisao/validacao antes de integrar.
Registrar em AGENTS.md, instrucoes do Copilot, ADR-0002 e guia. Este complemento
foi iniciado em `harness/separacao-branches`, preservando os registros locais
da entrega anterior, integrado/publicado em f61798d e alinhado a EAP 7.4.
A branch temporaria foi removida apos confirmar sua integracao.

## Entrega atual: iniciar pela base de integracao

Consolidar guia e prompt em main e main_jboss_eap74, publicar e remover a branch
lote/cache-hib-001 local/remota somente apos confirmar ausencia de commits
exclusivos e de outro checkout em uso. Deixar checkout limpo em main_jboss_eap74.
O planejador solicita a criacao da branch depois de definir e gravar a proposta;
nao cria branches nem aplica corretivas. Validar geracao pelo Test-Planning.ps1.
Esta decisao substitui a criacao antecipada da branch registrada no historico abaixo.
Incorporar o guia fornecido de Git/TortoiseGit como referencia adaptada em doc/guias,
ligada ao guia do desenvolvedor nos tres sentidos de integracao. Preservar o
original externo e distinguir diagnostico, integracao, validacao e deploy em PRD.

Concluido em 2026-09-27: entrega 74fca9b publicada nas duas branches, branch de
lote removida local/remotamente sem commits exclusivos, checkout na integracao.
Test-Planning.ps1 passou; links e diff conferidos, revisao estatica aprovada.
Proxima atividade do desenvolvedor: novo build/MTA da base integrada e proposta.

## Esclarecimento do fluxo de branches no guia

Documentar diagnostico inicial na base de migracao antes de conhecer o lote,
criacao da branch apos a proposta e retorno a integracao EAP 7.4 entre lotes.
O MTA do estado integrado orienta o proximo lote; preservar identidade historica,
conferencia Git, coordenacao paralela e revisoes humanas. Alteracao documental.
Exigir nova rodada completa no commit integrado para o proximo lote; relatorios
de commits individuais nao substituem essa evidencia. Preservar historicos.

## Historico: consolidar main e preparar branches do ensaio

Pedido do desenvolvedor: main limpa, commit/push das evolucoes do harness e branches
separadas para integracao EAP 7.4 e lote. Revisar alteracoes, executar os 11 testes,
conferir remoto e arquivos ignorados, consolidar commits em main e publicar.
Criar `main_jboss_eap74` a partir dessa main e `lote/cache-hib-001` a partir dela;
publicar sem force e deixar checkout na branch do lote. Nao aplicar corretivas.
As branches pertencem ao repositorio inteiro; neste ensaio os exemplos compartilham
o Git do harness. Configuracao local, workspace local e .harness ficam fora do Git.
O cadastro de papeis/responsavel continua no menu do desenvolvedor, depois da criacao.

Concluido em 2026-09-27: 11 testes passaram, revisao estatica independente sem
bloqueantes e links locais conferidos. Commits ee1f199 (implementacao) e 48cd359
(documentacao) integrados por fast-forward e publicados na main. Branches
main_jboss_eap74 e lote/cache-hib-001 criadas e publicadas a partir dessa base.
Seis pastas antigas de rodadas vazias removidas; MTA atual preservado.

## Ajuste atual: respeitar configuracao padrao das ferramentas

Pedido: manter somente os complementos necessarios ao harness, sem reinventar
padroes como repositorio Maven. Remover overrides de settings da configuracao
local e workspace; defaults ja sao null no exemplo. Registrar convencao e testar
geracao sem override. Conferir configuracao Maven da maquina antes de concluir.
O cache antigo nao deve ser confundido com a configuracao ativa apos a troca.

Concluido: JSON/workspace sem overrides de settings; configuracao da maquina
conferida. Test-BuildConfig passou. Cache antigo movido para backups-temporarios,
sem copiar/mesclar com .m2. Test-Cleanup validou tambem caminhos >260 caracteres.
Novo ensaio real confirmado: build 4f313156cb544767bce0e1410dfe15b3 e MTA
5cc84cfbfee345d1a1ae043ebdfec115 concluidos com sucesso, com relatorio aberto.

## Ajuste atual: reunir backups temporarios

Pedido: evitar pastas avulsas de exercicios/ajustes sob .harness. Usar somente
`.harness/backups-temporarios/<atividade>/` quando uma copia temporaria for
necessaria; reunir backups existentes e registrar a regra em AGENTS.md.
Reutilizar Workspace: limpar execucoes com opcao exclusiva para esses backups,
preview e confirmacao. Manter a limpeza de execucoes com o escopo atual.
Backups automaticos do workspace continuam em workspace-backups, usados pelo
gerador; cache Maven e fixtures de testes conservam suas finalidades.
Verificar isolamento, cancelamento, links/junctions e menu na fixture Test-Cleanup.
Conferir hashes ao mover apenas os backups temporarios identificados.

Concluido: regra e guia atualizados, opcao 3 implementada e Test-Cleanup passou.
Seis arquivos centralizados com hashes preservados; dois backups POM e fixtures
removidos por pedido explicito. Maven/cache e workspace-backups preservados.

## Nova entrega: reiniciar ensaios e reduzir verificacoes manuais

Pedido de 2026-09-27: adicionar uma unica tarefa `Workspace: limpar execucoes`.
Preparar menu para um projeto ou todos, listar caminhos e exigir confirmacao
local antes de remover runs (inclui relatorios), builds e planning (inclui
prompts/planos/to-dos), com ponteiros relacionados. Preservar configuracao,
workspace, fontes, Git, templates, Maven/cache e backups. Nao apagar copias
externas de relatorios nem target/ da aplicacao. Bloquear durante build/MTA ou
preparacao de contexto. Orientar encerrar Copilot antes de limpar: nao ha lock
compartilhado com o agente. Validar paths absolutos contidos nas areas permitidas
e recusar links/junctions antes da primeira remocao.

O desenvolvedor confirmou: a corretiva e a automacao Git do harness, nao o lote
CACHE-HIB-001. Confirmou tambem menu de limpeza por projeto ou todos.
Incrementos: limpeza isolada; integracao da tarefa/locks; coleta Git nos recibos;
cadastro dos papeis das branches por Source; conferencia atual contra o planejamento.
O catalogo passa de 12 para 14 tarefas, com uma Workspace de limpeza e uma
Planejamento de conferencia Git. Nao ha tarefa por projeto ou tipo de artefato.

Pedido adicional: manter README como entrada resumida e concentrar passo a passo,
decisoes dos menus e significado das branches no guia do desenvolvedor em doc/guias.
Preservar instrucoes manuais incorporadas ao template; nao regravar contextos antigos.

Verificacao: Test-Cleanup.ps1, Test-TaskInputs.ps1 e Test-Planning.ps1; preservar
arquivos sentinela de configuracao, cache, fontes e outro projeto. Executar a
limpeza real pelo menu com destinos visiveis e confirmacao LIMPAR; nao usar evidencias
reais como fixture de teste. O encerramento da conversa Copilot fica a cargo do
desenvolvedor, pois o harness nao controla o agente externo.

Verificado em 2026-09-27: Test-Git, Test-Cleanup, Test-Planning, Test-Mta, Test-Build
e Test-TaskInputs passaram. Git inclui cadastro/cancelamento sem troca de branch,
preservacao de outros projetos, HEAD alterado e arquivos nao rastreados. Limpeza
inclui junction, locks MTA/planejamento e ponteiro de outro Source com mesmo nome
legado. Sintaxe PowerShell e 56 links/ancoras locais conferidos; diff sem erros.
Nao houve limpeza real ou troca de branch do desenvolvedor. A verificacao Git
permanece conservadora com alteracoes locais e comprova apenas referencias locais.

## Historico: nomes legiveis para artefatos

Estado: REESTRUTURACAO IMPLEMENTADA E VALIDADA em 2026-09-27, incluindo ensaio visual relatado pelo desenvolvedor.
Este plano evolui o harness. Planos de corretivas continuam nos destinos dos contextos.
Historico e pendencias anteriores preservados em [todo.md](todo.md).

## Objetivo e escopo

Estender aos novos artefatos MTA e build a convencao ja implementada nos
planejamentos: nome do projeto, data/hora com fuso e identificador curto. Facilitar
localizacao e compartilhamento de relatorios, preservando identidade e historico.

Manter as tres areas existentes, sem criar outra arvore ou duplicar documentos:

```text
.harness/
  runs/<nome>__<chave12>/mta_<data-fuso>__<RunId12>/
    manifest.json, result.json, console.log, input/, rules/, output/
  builds/<nome>__<chave12>/build_<data-fuso>__<RunId12>/
    result.json, console.log
  planning/<nome>__<chave12>/mta_<data-fuso>__<RunId12>/
    plano_<data-fuso>__<RequestId12>/
      context.json, planejar-lotes.prompt.md, plan.md, todo.md
```

Nome sanitizado e limitado a 24 caracteres; chave estavel de 12 caracteres por
identidade do projeto. Reutilizar a convencao atual do planejamento. Os IDs
completos permanecem nos recibos; o build ja usa RunId, sem introduzir BuildId.
Usar o mesmo instante no nome e no recibo: CreatedAtUtc para MTA, StartedAtUtc
para build e PreparedAtUtc para planejamento. Pasta mostra horario local e fuso
(`2026-09-27_14-30-00-0300`); recibos conservam UTC.

Todos os arquivos de uma execucao ficam dentro dela: relatorio HTML e seus assets,
achados YAML, logs, snapshots, regras e resultados. Manter os nomes internos
produzidos pelas ferramentas. Artefatos Maven em target/ permanecem na aplicacao.
Configuracao local, locks e ponteiros active/last mantem suas funcoes e localizacao.

Pastas antigas nao serao movidas, renomeadas nem regravadas. A descoberta deve
aceitar ambos os formatos, conferir Project/Source/RunId completos e preservar
hashes, caminhos de contextos existentes e vinculos Previous. Nao deduzir RunId
do nome da pasta nem considerar nomes amigaveis como prova de identidade.

Fora do escopo: automatizar branches/Git, alterar corretivas, gerar novos tipos
de relatorio, criar comandos de exportacao/ZIP, publicar/enviar arquivos ou mudar
o fluxo de aprovacao. Compartilhamento sera orientado no guia existente.

## Etapas e criterios de aceite

### Regra transversal: Run Tasks por etapa

Manter os prefixos existentes em todos os labels:

| Prefixo | Responsabilidade |
| --- | --- |
| `Workspace:` | Configurar caminhos, gerar workspace e conferir sua configuracao |
| `Aplicacao:` | Build Maven da aplicacao |
| `MTA:` | Conferir ambiente MTA, executar analise, acompanhar/consultar logs e abrir relatorio |
| `Planejamento:` | Preparar contexto e abrir plano/to-do |

Esta entrega reutiliza as 12 tarefas atuais; a mudanca dos caminhos nao cria novas
entradas. Projeto, rodada, data e formato antigo/novo sao selecoes/parametros das
tarefas existentes, nao tarefas separadas. Funcoes auxiliares dos scripts nao
viram Run Tasks. Preservar labels, referencias e comportamento de selecao usados
pelos testes. A classificacao e feita pelo prefixo da etapa no nome da tarefa.

Na verificacao final, conferir prefixos, labels unicos e ausencia de crescimento
do catalogo nesta entrega, junto ao teste Test-TaskInputs.ps1.

### 1. Reutilizar a convencao de nomes

- Trabalho: disponibilizar no modulo comum as pequenas funcoes de nome/chave/data
  hoje usadas pelo planejamento, sem criar um novo framework ou modulo.
- Aceite: planejamento continua gerando o mesmo formato; datas/fuso consistentes,
  homonimos isolados, IDs completos preservados e colisao sem sobrescrita.
- Verificacao: Test-Planning.ps1, incluindo nomes longos e caminhos com espacos.
- Dependencias: nenhuma. Arquivos: Harness.psm1, HarnessPlanning.psm1,
  Test-Planning.ps1. Porte: pequeno, tres arquivos.

### 2. Preparar leitura de MTA nos dois formatos

- Trabalho: localizar rodadas por identidade e manifesto, antes de mudar a escrita.
  Atualizar ultimo relatorio, analise ativa, historico/log e selecao para planejamento.
- Aceite: formatos antigos/novos coexistem; -RunId continua recebendo o ID completo;
  active-mta.json e last-*.json encontram a rodada correta; builds nao sao confundidos
  com MTA. Rotulo renomeado nao perde historico; ambiguidade/divergencia e recusada.
- Verificacao: Test-MtaLog.ps1, Test-MtaActive.ps1 e Test-Planning.ps1; fixtures mistas,
  falhas/execucoes incompletas, registro ativo antigo, cancelamento e isolamento.
- Dependencias: 1. Arquivos: Harness.psm1, HarnessPlanning.psm1,
  acompanhar-log-mta.ps1, Test-MtaLog.ps1, Test-MtaActive.ps1. Porte: medio.

Checkpoint: os leitores reconhecem ambos os formatos com os testes existentes
passando; so entao a geracao de MTA pode adotar os novos caminhos.

### 3. Gravar novas rodadas MTA com nomes legiveis

- Trabalho: New-MtaSnapshot cria a nova pasta e usa seus caminhos reais nos argumentos,
  manifesto, resultado e acompanhamento. Planejamento continua vinculado ao RunId.
- Aceite: snapshot, logs, regras e relatorio permanecem juntos; execucao/abertura e
  acompanhamento funcionam; criar novo contexto a partir da rodada nova ou antiga
  preserva evidencias e vinculos. Caminhos internos do relatorio ficam intactos.
- Verificacao: Test-Mta.ps1 e Test-Planning.ps1; regressao dos leitores da etapa 2;
  tamanho realista de caminhos incluindo arquivos aninhados do snapshot.
- Dependencias: 2. Arquivos: Harness.psm1, Test-Mta.ps1, Test-Planning.ps1.
  Porte: pequeno, tres arquivos.

### 4. Gravar builds com a mesma convencao

- Trabalho: usar nome/chave do projeto e StartedAtUtc na pasta de build; preservar
  os caminhos LogPath/ResultPath retornados e o contrato de RunId.
- Aceite: builds com sucesso ou falha guardam resultado/log na pasta legivel;
  execucoes no mesmo segundo sao distintas e nao sobrescrevem historico; lock e
  separacao MTA/build continuam corretos. Builds antigos permanecem no lugar.
- Verificacao: Test-Build.ps1 e Test-BuildConfig.ps1 com fixtures isoladas,
  nomes repetidos, caminhos com espacos e falha do processo.
- Dependencias: 1; executar apos 3 nesta entrega. Arquivos: HarnessBuild.psm1,
  Test-Build.ps1. Porte: pequeno, dois arquivos.

### 5. Documentar localizacao e validar compartilhamento do HTML

- Trabalho: atualizar README e a especificacao existente de planejamento com os
  novos caminhos. Orientar compartilhar uma copia de output/static-report completa,
  com nome externo identificando projeto/data/ID, preservando sua estrutura interna.
- Aceite: copiar apenas index.html nao e a orientacao; assets, api e arquivos JS
  acompanham o HTML. Conferir a copia fora do repositorio, incluindo navegacao e
  carregamento dos dados; registrar limitacoes reais em vez de prometer portabilidade.
  A copia para consulta nao substitui a rodada original nem seus recibos/vinculos.
- Verificacao: nove testes Test-*.ps1; conferir o historico real existente sem altera-lo;
  Test-TaskInputs.ps1 tambem verifica prefixos/labels e preservacao das 12 tarefas;
  ensaio de abertura da copia HTML e dos caminhos exibidos nas tarefas no VS Code.
- Dependencias: 3 e 4. Arquivos: README.md, doc/especificacoes/planejamento-copilot.md,
  tests/Test-TaskInputs.ps1, tasks/plan.md e tasks/todo.md. Porte: medio, cinco arquivos.

Checkpoint final: mesma convencao nas tres areas, consumidores funcionando com
historico misto e relatorio copiado consultavel. Mostrar caminhos e resultados ao
desenvolvedor; nao executar novo MTA real somente para renomear o historico.

## Verificacao da implementacao em 2026-09-27

- Etapas 1 a 4 implementadas; as novas gravacoes MTA/build usam os nomes legiveis.
  Historico misto, rotulo renomeado, IDs completos, identidade/fonte divergente,
  duplicidade de RunId e ponteiros de ultimo relatorio/analise ativa verificados.
- Nove scripts Test-*.ps1 passaram em Windows PowerShell 5.1, com processos
  Maven/MTA simulados. Mantidas as 12 Run Tasks, com prefixos e labels unicos.
- Rodada real b8913bad9ab84c2499d8e69fdad58a21 localizada e elegivel; quatro hashes
  conferem com o recibo do Copilot. Ultimo relatorio e plan/todo reais continuam
  acessiveis nos caminhos antigos, sem mover ou regravar historico.
- README/especificacao atualizados. Copia completa de static-report fora do repo:
  23 arquivos com hashes identicos. Caminho de ensaio:
  `C:/Users/edoar/AppData/Local/Temp/harness-share-525e401b/migracao-cache-antes_2026-09-26_09-55-07-0300__b8913bad9ab84/index.html`.
- Ensaio visual concluido pelo desenvolvedor: relatorio original da rodada
  db4a1abd43b04997bffac947242dfd87 e copia externa abriram e foram conferidos;
  a tarefa de abrir plano/to-do listou historico antigo/novo e abriu ambos os
  documentos da solicitacao 8b54d7ca896d4d5ca5b255fbfcb7b4a5. Etapa 5 concluida.
  A verificacao visual foi relatada pelo operador, nao observada por automacao.

No ensaio guiado, o desenvolvedor executou build real
5c8fb48f6c884af68b44d2d8dea41691 e a rodada MTA acima, ambos SUCCEEDED/exit 0.
O monitor interno exibiu o resultado final. Corretivas continuam sem GO/aceite;
nao foram feitos commit ou push pelo agente nesta entrega.

## Ajustes do prompt apos ensaio do Copilot

Em 2026-09-27, incorporar ao template de planejar-lotes a orientacao dada no chat
para revisar o mesmo lote ainda nao aplicado/aprovado, com ID obtido do historico,
preservando os documentos anteriores. Persistir tambem as correcoes de precisao:
versao MTA em Result.Version, equivalencia de opcoes sem ocultar diferencas de
caminhos nos argumentos, dependencies.yaml como evidencia MTA e nao resolucao
Maven atual comprovada. Atualizar a referencia aos formatos de pastas.

Preservar prompts/recibos ja preparados; a solicitacao das 15:34:11 continua sendo
a solicitacao ativa e recebeu o ajuste pelo chat do Copilot. Novas preparacoes
herdam o template atualizado. Verificar com Test-Planning.ps1, sem preparar outro
contexto real nem editar os documentos de corretivas em nome do Copilot.

## Evolucoes futuras: planejar depois da reestruturacao

Registrar como backlog, sem iniciar detalhamento ou implementacao nesta entrega.
Depois de concluir e validar a reestruturacao, planejar as etapas nesta ordem:

1. **Qualidade / Sonar:** scanner executado localmente via Maven, com selecao de
   servidor Sonar corporativo ou Sonar instalado em Docker. Recuperar as praticas
   dos outros projetos quando essas referencias forem disponibilizadas; definir
   configuracao, credenciais, resultados e criterio de qualidade no plano futuro.
2. **Deploy / release:** preparar e implantar a release da aplicacao no JBoss
   EAP 7.1 ou EAP 7.0, conforme destino selecionado. Confirmar versoes e ambientes
   ao detalhar esta etapa, sem substituir o destino EAP 7.4 do fluxo de migracao
   existente. Planejar rastreabilidade do artefato, verificacao e rollback.
3. **Servidor:** planejar start, stop e consulta de estado do JBoss no ambiente
   selecionado, incluindo a ordem necessaria para o deploy e sua verificacao.

Prever categorias de Run Tasks `Qualidade:`, `Deploy:` e `Servidor:` nesses planos
futuros, com menus/parametros para projeto, servidor e ambiente. A restricao de
12 tarefas vale para a reestruturacao atual; futuras operacoes distintas poderao
ter tarefas proprias agrupadas por etapa, sem duplicar entradas por destino.

As futuras evidencias deverao seguir a convencao de projeto/data/hora/ID e manter
vinculo com repositorio, branch/commit, ambiente e execucao. Definir seus contratos
quando cada etapa for planejada. Este registro nao autoriza analises Sonar,
criacao de containers, deploys ou start/stop de servicos agora.

## Riscos ja identificados

- Leitores reconstruem atualmente caminhos pelo ID, inclusive analise ativa e
  ultimo sucesso: atualizar leitores antes de alterar produtores.
- Windows PowerShell 5.1 ja apresentou limite de caminho nos testes de planejamento:
  manter nomes curtos e testar tambem a profundidade de snapshots/relatorios MTA.
- Rotulos podem mudar e horarios locais podem diferir entre maquinas: usar identidade
  completa e datas UTC dos recibos para vincular e ordenar, sem recalcular pastas antigas.
- O HTML real referencia ./assets/, ./output.js e outros arquivos locais: validar
  a pasta completa copiada antes de considerar o compartilhamento comprovado.

Preservar alteracoes locais; sem commit/push e sem aplicar corretivas da aplicacao.
