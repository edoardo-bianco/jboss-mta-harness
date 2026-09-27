# To-do do agente: evolucao do harness

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
- [ ] Ensaio do desenvolvedor no VS Code: escolhas de branches e conferencia Git.
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

## Backlog: planejar somente depois da reestruturacao

Dependencia: concluir e validar as etapas 1 a 5 do plano atual. Estes itens sao
pedidos de planejamento futuro, nao tarefas de implementacao ou execucao agora.

- [ ] Planejar qualidade com scanner Maven local e selecao de Sonar corporativo
  ou Sonar em Docker, considerando referencias dos outros projetos quando disponiveis.
- [ ] Depois, planejar release/deploy da aplicacao em JBoss EAP 7.1 ou 7.0;
  confirmar destinos ao detalhar, preservando o fluxo de migracao para EAP 7.4.
- [ ] Planejar start/stop e consulta de estado do servidor JBoss, coordenados com o deploy.

Categorias futuras: Qualidade:, Deploy: e Servidor:. Aplicar a convencao
de artefatos por projeto/data/hora/ID e selecoes por ambiente, sem proliferar
Run Tasks por servidor ou projeto. Detalhes e criterios de aceite serao definidos
nos respectivos planos futuros.

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
- [ ] Ensaio de retomada no Copilot com devsquad em nova conversa: usar a mesma
  solicitacao 6901b92111044988ad778f7411c1dba7, preservar CACHE-HIB-001 e os dois
  destinos, completar apenas lacunas sem delegar ou aplicar corretivas.
- [ ] Ensaio no Copilot apos novo MTA: escolher proposta anterior, reconciliar
  resultados/validacoes e propor proximo lote somente por pedido explicito.
