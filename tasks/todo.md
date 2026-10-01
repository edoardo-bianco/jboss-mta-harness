# To-do do agente: evolucao do harness

Registros datados preservam decisoes e ensaios da epoca. Regras substituidas nao
voltam a ser exigencias: o guia e os contratos atuais orientam o uso. Pendencias
tecnicas reais permanecem nos checklists correspondentes.

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
- [ ] Ensaiar no Copilot Local: no maximo duas chamadas, par persistido/releitura,
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
- [ ] Diagnosticar bloqueio de arquivo na fixture Test-Mta antes de declarar regressao completa.

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
- [ ] Operador: ensaiar Executar Prompt, delegacao e corretiva autorizada no Copilot.

## Criterios Sonar e padroes de configuracao - 2026-09-29

- [x] Confirmar Blocker/High reprovando; cobertura <85% e aumento de issues como avisos.
- [x] Implementar avaliacao separada do Gate e resumo com motivos/valores.
- [x] Comparar baseline ANTES explicitamente selecionado, preservando historico.
- [x] Acrescentar padroes Sonar ausentes ao abrir configuracao, mantendo overrides.
- [x] Documentar padroes, compatibilidade, metricas MQR e limites da comparacao.
- [x] Concluir testes de criterios, configuracao, regressao e revisao local.
  Sonar simulado, 52 verificacoes HTTP, tasks, build-config, workspace e limpeza
  passaram. Sintaxe e diff conferidos; entrega local sem push.
- [ ] Operador: ensaiar novos criterios no servidor real; nao equivale a GO.

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
