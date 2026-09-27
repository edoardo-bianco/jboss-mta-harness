# Instrucoes para agentes neste repositorio

Antes de planejar ou editar, identifique se o pedido e **evolucao do harness** ou
**migracao de uma aplicacao**. Siga a
[ADR-0002](doc/adr/0002-separacao-harness-e-migracao-progressiva.md).
Para projeto, branch e trabalho paralelo, siga tambem a
[ADR-0003](doc/adr/0003-projeto-branch-e-concorrencia-da-migracao.md).

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
  `MTA:` e `Planejamento:`. Reutilize tarefas e menus/parametros existentes;
  nao crie uma entrada por projeto, rodada, arquivo, formato ou funcao auxiliar.
  Uma nova tarefa deve representar uma operacao distinta e necessaria ao usuario.
- Migracao usa `PlanPath` e `TodoPath` do contexto selecionado, sob
  `.harness/planning/`, na pasta da solicitacao identificada pelo recibo. Nunca use `tasks/` do harness
  para corretivas da aplicacao, nem altere o harness como parte de um lote.
- Vincule cada ciclo a Project/Source, repositorio/modulo, branch principal,
  branch de migracao, branch de trabalho autorizada, HEAD, estado local e responsavel.
  Antes de executar/retomar, confira esses dados no repositorio da aplicacao.
  Branch divergente bloqueia a execucao; HEAD alterado exige reconciliar o plano.
  Nao use a branch do harness como identidade de outro projeto do workspace.
- Planeje um unico lote consistente por frente de trabalho, mesmo com milhares de achados MTA.
  Registre cobertura parcial; deixe a identificacao do proximo lote para depois
  da corretiva, verificacoes e aceite humano do atual, mediante continuidade pedida.
- Separe proposta, revisao/GO humano, execucao autorizada, verificacoes automaticas
  e revisao/aceite humano do resultado. Use a nova rodada MTA e o historico para
  reconciliar resultados antes do proximo lote; nunca trate pendencia como sucesso.
- O prompt `planejar-lotes` so grava os dois documentos de corretivas. Aplicar o
  lote exige etapa autorizada separadamente. Nao infira permissao de execucao ou
  aceite a partir da existencia de arquivos, ferramentas ou resultados de testes.
- Corretivas paralelas usam frentes isoladas e coordenadas, integradas na branch
  de migracao. Registre alinhamento com a principal e revalide o estado integrado.
  .harness e local: nao e lock compartilhado. Sem evidencia Git, registre PENDENTE.
  O harness coleta Git nos novos recibos; `Planejamento: conferir Git do lote`
  compara o checkout atual com o planejamento e a politica declarada. Exige
  conferencia antes da execucao; resultado Git nao substitui GO nem aceite.

Consulte o [guia do desenvolvedor](doc/guias/harness-migracao-desenvolvedor.md)
para uso e os documentos de `doc/` para contratos
e decisoes. Preserve alteracoes locais e evidencias historicas.
