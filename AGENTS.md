# Instrucoes para agentes neste repositorio

Antes de planejar ou editar, identifique se o pedido e **evolucao do harness** ou
**migracao de uma aplicacao**. Siga a
[ADR-0002](doc/adr/0002-separacao-harness-e-migracao-progressiva.md).
Para identidade do projeto e Git informativo, siga a
[ADR-0004](doc/adr/0004-git-informativo-sem-controle-de-branches.md), que substitui
o controle de branches da ADR-0003.

- Evolucao do harness inclui scripts, prompts, preparacao de contexto, Run Tasks,
  configuracao, testes e documentacao. Use `tasks/plan.md` e `tasks/todo.md`.
- Antes de alterar o harness, crie ou retome uma branch `harness/<objetivo>`
  derivada da principal do repositorio do harness. Nao implemente essas mudancas
  diretamente em main/develop, na integracao EAP 7.4 ou em branches de lote.
  Confira raiz, branch, HEAD e estado local; preserve trabalho pendente.
  Revise e valide antes de integrar na principal. No ensaio em repositorio unico,
  leve a evolucao aceita da principal para a integracao EAP 7.4 em etapa explicita
  e atualize as evidencias afetadas. Prefira checkout/worktree separado se houver
  migracao em andamento; nao troque a branch de um checkout usado por outro agente.
- Preserve os padroes das ferramentas. O harness adiciona somente configuracao
  necessaria ao fluxo; nao crie repositorio Maven, mirrors ou settings proprios
  por conveniencia do ensaio. Por padrao, settings opcionais ficam null e o Maven
  usa a configuracao da maquina. Overrides exigem necessidade explicita, como
  settings corporativo informado pelo desenvolvedor. Nao duplique caches.
- Evite criar backups temporarios sem necessidade. Quando indispensaveis para
  exercicios/ajustes, use somente `.harness/backups-temporarios/<atividade>/`,
  com nomes descritivos e caminhos relativos dos arquivos preservados. Nao crie
  pastas `*-backups`, `*-backup` ou copias avulsas na raiz de `.harness/`.
  Essa area pode ser limpa pela opcao 3 de `Workspace: limpar execucoes`;
  nao coloque nela configuracao ativa, evidencias oficiais ou material permanente.
  Backups automaticos do gerador ficam em `.harness/workspace-backups/`;
  fixtures ficam em `.harness/tests/`. Nao misture essas finalidades.
- Classifique Run Tasks por etapa usando os prefixos `Workspace:`, `Aplicacao:`,
  `Servidor:`, `MTA:` e `Planejamento:`. Reutilize tarefas e menus/parametros existentes;
  nao crie uma entrada por projeto, rodada, arquivo, formato ou funcao auxiliar.
  Uma nova tarefa deve representar uma operacao distinta e necessaria ao usuario.
- Migracao usa `PlanPath` e `TodoPath` do contexto selecionado, sob
  `.harness/planning/`, na pasta da solicitacao identificada pelo recibo. Nunca use `tasks/` do harness
  para corretivas da aplicacao, nem altere o harness como parte de um lote.
- Vincule cada ciclo a Project/Source e as evidencias/saidas da solicitacao.
  Para MTA recebido, MtaOrigin preserva a origem e RunId; AnalysisSource e o
  snapshot e Source e o projeto local. Caminhos/branches podem diferir.
  Identidade Maven e diferencas de codigo geram alertas, sem bloquear a proposta;
  conferir pontos locais e recomendar novo MTA se o diagnostico estiver desatualizado.
  Planejamento referencia MtaOrigin/RunId, sem coletar Git do checkout local.
  Git e informativo: registre branch/commit observados quando disponiveis.
  O desenvolvedor escolhe e informa a branch de trabalho; o harness nao cadastra
  papeis, responsavel ou coordenacao, nem bloqueia por branch/HEAD/estado local.
  Nao exigir novo contexto ou reconciliacao Git apenas por essas diferencas.
  Confira conteudo relevante da aplicacao para avaliar se o MTA ainda se aplica.
- Excecao explicita de conveniencia: ao preparar implementacao, o desenvolvedor
  escolhe criar/usar uma branch local lote/<ID>, continuar na atual ou criar/usar
  nome manual. Somente a escolha explicita autoriza essa operacao no checkout
  selecionado. Sem padrao, force, push ou cadastro; isso nao concede GO ou aceite.
- Planeje um unico lote consistente por frente de trabalho, mesmo com milhares de achados MTA.
  Registre cobertura parcial; deixe a identificacao do proximo lote para depois
  da corretiva, verificacoes e aceite humano do atual, mediante continuidade pedida.
- Separe proposta, revisao/GO humano, execucao autorizada, verificacoes automaticas
  e revisao/aceite humano do resultado. Reconcilie evidencias e historico antes do
  proximo lote; nova rodada MTA/Sonar sao checklist nao bloqueante. Comparacao
  ausente fica pendente, sem declarar resolucao ou conclusao global.
- Siga o [contrato vigente](doc/especificacoes/planejamento-copilot.md), inclusive
  Java 8/javax/EAP 7.4 e Hibernate 5.3 quando aplicavel. `planejar-lotes` cria ou
  atualiza um lote; `revisar-lote` permanece para compatibilidade.
  Escreva PlanPath/TodoPath e, se MigrationPath estiver explicito, apenas andamento,
  cobertura e referencias das issues trabalhadas, preservando decisoes humanas.
  `manter-migracao` so escreve MigrationPath, sem planejar ou aplicar corretivas.
  Aplicar o lote exige etapa autorizada separadamente. Nao infira execucao ou
  aceite da existencia de arquivos, ferramentas ou resultados de testes.
- Gestao de branches, integracao e coordenacao de frentes pertencem ao desenvolvedor.
  .harness e local: nao e lock compartilhado. Politicas Git antigas sao historicas,
  nao pendencias a renovar. Preserve trabalho local e revalide o codigo integrado
  conforme os criterios do lote. GO e aceite humano continuam separados.

Consulte o [guia do desenvolvedor](doc/guias/harness-migracao-desenvolvedor.md)
para uso e os documentos de `doc/` para contratos
e decisoes. Preserve alteracoes locais e evidencias historicas.
