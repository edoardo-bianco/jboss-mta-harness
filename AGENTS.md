# Instrucoes para agentes neste repositorio

Antes de planejar ou editar, identifique se o pedido e **evolucao do harness** ou
**migracao de uma aplicacao**. Siga a
[ADR-0002](doc/adr/0002-separacao-harness-e-migracao-progressiva.md).
Para identidade do projeto e Git informativo, siga a
[ADR-0004](doc/adr/0004-git-informativo-sem-controle-de-branches.md), que substitui
o controle de branches da ADR-0003.
Para a entrada unica de planejamento orientada pelo registro, siga a
[ADR-0005](doc/adr/0005-planejamento-orientado-pelo-registro.md).
Para categorias e dossies padronizados por issue, siga a
[ADR-0006](doc/adr/0006-categorias-e-dossie-por-issue.md).

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
- Pre-planejamento opcional `priorizar-issues` compara projetos do escopo escolhido
  e examina fatia de 0,01%..100,00% das issues elegiveis do total inicial fixo,
  recomendando por risco/repetibilidade/alcance, sem escolher pelo humano.
  Com historico, perguntar recriar ou progredir; progresso exclui todas as examinadas
  anteriores por Source/ID (AnalyzedIssues), com ou sem proposta. Cada examinada
  recebe linha com posicao ou motivo e ficha de evidencias/referencias/roteiro
  para planejamento e corretiva manual. Mencao/sobreposicao nao comprova exame.
  Categoria escolhida separa as sequencias (mandatory, optional, potential ou
  outra recebida). Recibos v2/v3 permanecem mandatory; novos v4 declaram Category.
  Seu contexto fica em `.harness/priorizacao/`; escreve `RankingPath` e as fichas
  das examinadas em `FichaPaths` por Source/ID, sem
  planos/to-dos, alteracao dos registros ou GO. Depois da escolha humana, segue
  planejamento de um lote. Helpers so orientam/revisam no chat. Siga o contrato.
- Migracao usa `PlanPath` e `TodoPath` do contexto selecionado, sob
  `.harness/planning/`, na pasta da solicitacao identificada pelo recibo. Nunca use `tasks/` do harness
  para corretivas da aplicacao, nem altere o harness como parte de um lote.
- Novos contextos LayoutVersion=2 separam projeto/issue e usam nomes identificaveis
  para ficha/contexto/plan/todo; preserve nomes e recibos legados. Ficha e anexos
  entram no plano da issue; outra issue/projeto mantem documentos proprios.
  EvidenceMode=CONSOLIDATED valida as copias em Consolidated.Files, sem exigir
  acesso ao MTA original. PlanningBasis, MtaOrigin/RunId e hashes preservam origem;
  Source atual ainda exige conferencia de conteudo. Nao aplicar fallback silencioso
  aos recibos antigos nem inferir resolucao MTA sem comparacao. Limpeza preserva
  os dossies em planning/<projeto>/issues, inclusive fichas e anexos oficiais.
- A entrada habitual e `Planejamento: planejar`: cria, retoma ou atualiza a proposta
  a partir do registro. Nao exigir selecao repetida de operacao/projeto/MTA nem
  copiar novamente escolhas para o prompt. Registro ausente direciona a
  `Workspace: atualizar indice dos projetos`; varios candidatos exigem escolha
  somente do registro/frente. Indice localiza; registro atual concentra a decisao.
  Planejar nao recarrega catalogo nem elege rodada/plano por recencia.
- Contexto declara `PlanningBasis=MTA|EVIDENCIAS`. Evidencias humanas podem
  sustentar planejamento sem pacote MTA completo, sem inventar RunId, snapshot,
  categoria ou resultado MTA. Contextos antigos sem o campo continuam MTA.
  Corrupcao/conflito de origem exige esclarecimento, sem fallback silencioso.
  Origem/evidencias/contrato/template iguais retomam a solicitacao vinculada;
  mudancas nessas entradas produzem novo recibo com Previous e preservam o anterior.
  Escolhas/observacoes atuais sao lidas sem reescrever historico. Referencia antiga
  segue Previous ate o unico sucessor; varios sucessores exigem escolha, nao recencia.
- Antes da proposta completa, perguntar somente o essencial ainda ausente que
  afete escopo, solucao ou aceite; preservar rascunho/ID, sem par plan/to-do ficticio.
  Reconciliacao exige motivo concreto. Estado PENDENTE historico nao bloqueia
  planejamento por si so nem autoriza marcar CONCLUIDA. Escolha ja registrada
  nao fica pendente em razao de ranking/indice antigos. Helpers orientam uma
  etapa com caminho e mensagem prontos para o cliente atual; continuam leitores.
- Vincule cada ciclo a Project/Source e as evidencias/saidas da solicitacao.
  Para MTA recebido, MtaOrigin preserva a origem e RunId; AnalysisSource e o
  snapshot e Source e o projeto local. Caminhos/branches podem diferir.
  Identidade Maven e diferencas de codigo geram alertas, sem bloquear a proposta;
  conferir pontos locais e recomendar novo MTA se o diagnostico estiver desatualizado.
  Planejamento com base MTA referencia MtaOrigin/RunId; com EVIDENCIAS, referencia
  as entradas realmente fornecidas. Nao coletar Git do checkout local no planejamento.
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
