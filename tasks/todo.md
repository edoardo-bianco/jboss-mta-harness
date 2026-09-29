# To-do do agente: evolucao do harness

## Integracao SonarQube - 2026-09-29

- [x] Recuperar contratos pertinentes do template anterior e documentacao oficial.
- [x] Testar configuracao, envio Maven, CE, gate, metricas e protecao do token.
- [x] Implementar tarefa unica, entrada oculta e resultados por projeto/data/ID.
- [x] Atualizar guia/configuracao e explicar baseline, cobertura e limites.
- [x] Validar regressao e revisar antes de entregar na branch do harness.
  Sonar simulado, 52 verificacoes HTTP e regressao build/config/workspace/target/
  tasks/limpeza passaram em PowerShell 5.1. Sem scan ou token reais.
- [ ] Ensaio real com servidor/token do operador (nao equivale a GO da aplicacao).

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
- [ ] Operador: ensaiar continuidade com novo MTA e Previous do ciclo atual;
  conferir reconciliacao tecnica e pendencias. Outro lote somente apos aceite
  do atual e pedido explicito. Corretivas e seus testes pertencem ao plano da aplicacao.
- [x] Consolidar aprendizados confirmados do percurso documental no guia e exemplo,
  preservando limites. Consolidacao de nova rodada/execucao/aceite depende de
  ensaios futuros; nao foram declarados concluidos.

## Backlog futuro - ainda requer planejamento

- Retomado em Integracao SonarQube acima: scanner Maven local com servidor
  corporativo ou Docker. Validacao integrada real permanece explicita nessa entrega.
- [ ] Planejar release/deploy para JBoss EAP 7.1 e 7.4, destinos confirmados pelo
  desenvolvedor em 2026-09-28 e configurados em tools.eap71Home/tools.eap74Home
  no JSON local. Detalhar selecao do servidor, artefato, implantacao e rollback;
  as corretivas de migracao continuam destinadas ao EAP 7.4.
- [ ] Planejar start/stop e consulta de estado do JBoss, coordenados com o deploy.

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
