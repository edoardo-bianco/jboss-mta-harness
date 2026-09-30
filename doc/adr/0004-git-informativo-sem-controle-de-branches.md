# ADR-0004: Git informativo, sem controle de branches no harness

Status: aceita pelo desenvolvedor em 2026-09-28.
Substitui os requisitos de cadastro e bloqueio Git da ADR-0003. Preserva a
separacao entre evolucao do harness e corretivas da aplicacao da ADR-0002.

## Contexto

O cadastro de principal/migracao/trabalho, responsavel e coordenacao tornou o
ensaio complexo. A troca de branch ou um commit apenas do harness gerava novas
pendencias e solicitacoes, mesmo com os fontes da aplicacao inalterados.
O desenvolvedor pediu eliminar esse controle e assumir a gestao das branches.

## Decisao

- O desenvolvedor escolhe/cria/seleciona a branch e pode informa-la ao agente.
  Nao ha cadastro de politica, responsavel ou coordenacao no harness.
- Build, MTA e contexto continuam registrando observacao Git quando disponivel:
  raiz/modulo, branch, commit, data e estado local. Ausencia de Git, HEAD destacado,
  alteracoes locais ou diferencas de branch/HEAD nao sao gates do harness.
- Remover a tarefa e o script de conferencia Git, seus menus e funcoes de politica.
  Preparar contexto e abrir documentos nao exigem essa etapa.
- Nao inferir invalidade de uma rodada MTA pela diferenca de commit. Conferir
  conteudo relevante (fontes, POMs, configuracoes) para decidir aplicabilidade.
  Mudancas tecnicas relevantes podem exigir reanalise; troca de branch ou commit
  sem mudanca relevante nao exige novo MTA/contexto nem reconciliacao Git formal.
- Git atual e origem historica da rodada continuam separados. Nao reescrever
  manifesto ou recibo para atribuir o commit atual a uma analise antiga.
- Preservar identidade Project/Source/RunId/RequestId, hashes das evidencias e
  destinos de escrita. Essas verificacoes protegem o projeto e o historico MTA.
- GO para corretivas, verificacoes tecnicas e aceite humano continuam separados.
  Remover gates Git nao autoriza corretivas, descartar trabalho ou aprovar resultados.

## Complemento: criacao local opcional na implementacao - 2026-09-30

Pedido explicito do desenvolvedor: a tarefa Aplicacao: preparar implementacao do
lote oferece uma decisao antes de abrir o prompt: 1 criar e usar lote/<ID-do-lote>,
2 continuar na branch atual, 3 criar e usar nome informado. Nenhuma opcao padrao;
Enter/q cancela. Sem ID unico e igual nos metadados do plano/to-do, oferecer 2/3.
Essa conveniencia nao restaura o cadastro, papeis ou gates removidos nesta ADR.

Criar significa executar git switch --no-track -c com o nome validado e HEAD
exibido do repositorio da aplicacao, mesmo que Source seja um modulo. Revalidar
documentos e estado exibido antes de mudar Git; nunca sobrescrever branch existente,
forcar, fazer stash/reset/commit/push, integrar ou executar corretiva nesta tarefa.
Branch atual, HEAD destacado, estado local ou Git indisponivel nao impedem a
escolha 2. Falha na criacao e erro da operacao solicitada, nao gate de migracao.
Se Git recusar a criacao, informar o erro e oferecer 2/3 na mesma execucao.
O desenvolvedor confere uso exclusivo do checkout; o harness nao coordena agentes.

O prompt ja salvo permanece se a etapa Git for cancelada/falhar; o editor nao abre.
Recibos e evidencias historicos nao sao reescritos. GO e aceite humano continuam
separados; criar uma branch nao aprova o lote. O agente Copilot nao passa a ter
autorizacao para gerir branches: esta excecao pertence apenas a escolha na Run Task.

## Compatibilidade e operacao

`gitPolicies` em configuracoes antigas fica ignorado. Nao remover configuracao
local nem reescrever contextos, prompts e planos antigos automaticamente.
Campos antigos Policy/MainHead/MigrationHead/MainInMigration/MigrationInWork
sao apenas historicos; ausencia deles nao vira tarefa ou bloqueio nos novos planos.
Ao continuar proposta antiga, encerrar nos documentos novos somente as tarefas
do mecanismo removido como SUPERADAS pela ADR-0004, sem alegar que foram executadas.
Manter pendencias tecnicas reais e o ID do lote, sem alterar documentos anteriores.

Usar prompt novo uma vez para adotar este contrato. Depois, trocar de branch
nao exige preparar outra solicitacao. O desenvolvedor informa onde quer trabalhar.
Gestao de branches, conflitos, integracao e coordenacao fica com o desenvolvedor.
As regras de branch exclusiva e revisao para evoluir o proprio harness permanecem.

## Verificacao

Testar coleta sem politica, configuracao legada ignorada/preservada, preparo sem
menu Git e abertura sem gate. Manter testes de isolamento por projeto, integridade
MTA e preservacao de contextos antigos. Obediencia do agente requer ensaio no cliente.
