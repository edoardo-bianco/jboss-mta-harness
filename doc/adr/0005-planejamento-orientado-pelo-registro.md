---
html:
  embed_local_images: true
  embed_svg: true
  offline: true
---

# ADR-0005: planejamento orientado pelo registro de migracao

Status: aceita pelo desenvolvedor em 2026-10-04.
Complementa as ADRs 0001, 0002 e 0004. Substitui a obrigatoriedade de selecionar
operacao, projeto e rodada a cada planejamento, de partir sempre de um pacote
MTA completo e de reconciliar previamente apenas por um estado PENDENTE.
Preserva separacao harness/aplicacao, integridade, escopo humano, GO e aceite.

## Contexto

O ensaio mostrou repeticao da escolha entre registro, menu, ranking e prompt.
Os helpers encontravam a issue marcada, mas orientavam reconciliacao sem conflito
concreto e devolviam varios passos ou comandos do outro cliente. Preparar o plano
podia escolher uma rodada mais recente que a vinculada ao registro. Uma escolha
ja feita continuava apresentada como PENDENTE em documentos derivados.

O registro e o indice ja oferecem identidade e referencias. O desenvolvedor deve
poder escolher uma corretiva, acrescentar evidencias e pedir planejamento com
orientacao suficiente para tomar decisoes, inclusive sem pacote MTA completo.

## Decisao

- A entrada habitual e **Planejamento: planejar**, para proposta inicial, retomada
  ou atualizacao. Replanejar e um comportamento dessa entrada, sem menu proprio.
- O registro atual concentra escolhas, recorte, observacoes e referencias. O
  indice localiza registros; snapshots e ranking documentam a origem da analise.
  Nenhum resumo antigo revoga uma escolha atual ou concede GO.
- Resolver registro/contexto explicitamente informado ou o unico candidato
  elegivel do workspace. Perguntar somente em ambiguidade real, sem eleger todos
  os projetos, o plano mais recente ou o arquivo ativo do editor.
- Se faltar registro, orientar **Workspace: atualizar indice dos projetos**.
  Criacao inicial pode aproveitar MTA reconhecido inequivoco. Atualizar indice
  nao substitui por recencia uma origem ja vinculada. Planejar nao recarrega catalogo.
- Contextos declaram **PlanningBasis=MTA|EVIDENCIAS**. MTA preserva origem, RunId,
  snapshot e integridade. EVIDENCIAS preserva o que foi fornecido e seus limites,
  sem fabricar RunId, resultado MTA ou categoria mandatory para issue manual.
  Um conflito/corrupcao MTA exige esclarecimento, nunca fallback silencioso.
- Com origem, evidencias referenciadas, contrato e template iguais, continuar a
  solicitacao vinculada, inclusive prompt ainda sem plano. Mudanca nessas entradas
  produz novo recibo com Previous; recibos, snapshots e propostas anteriores ficam
  preservados. Escolhas/observacoes atuais sao lidas na execucao. Links antigos
  seguem Previous ate um unico sucessor; bifurcacoes exigem escolha, nunca recencia.
- O agente pergunta somente o essencial que impeça uma proposta coerente antes
  de consolidar plan.md/todo.md. Incertezas nao impeditivas ficam como limites ou
  verificacoes. Respostas ja presentes no registro nao sao pedidas novamente.
- Reconciliacao trata motivos concretos: nova origem/catalogo, conflitos entre
  decisoes/evidencias ou conciliacao solicitada. Permanece disponivel em
  manter-migracao; nao e ritual previo ao planejamento nem conclusao automatica.
  A adocao explicita de novo MTA possui a tarefa **Planejamento: atualizar registro
  de migracao**, com previa e confirmacao da origem. Ela reutiliza manter-migracao;
  nao acrescenta selecao de rodada ao Planejar habitual.
- Helpers leem contexto e oferecem uma proxima acao com caminho/mensagem pronta
  para o cliente atual. Codex usa skills/subagentes disponiveis; Copilot usa seus
  perfis locais e DevSquad nas etapas de execucao pertinentes. A skill nao comprova
  delegacao, e o helper nao grava ou executa por ter descoberto a proxima etapa.
- PENDENTE identifica trabalho real. Escolha feita no registro nao exige atualizar
  ranking e indice manualmente; GO vigente do mesmo escopo permanece valido.
  Mudanca de escopo exige revisao da autorizacao; aceite do resultado e separado.

## Alternativas e consequencias

Manter menus sucessivos e exigir repetir contexto foi rejeitado pela duplicacao
e risco de escolher outra origem. Escolher automaticamente a ultima rodada ou
todos os projetos tambem foi rejeitado: recencia nao representa intencao humana.

Remover apenas o menu seria insuficiente. Historico, implementacao, indice,
limpeza, prompts, helpers e guias devem reconhecer ambas as bases. Contextos
antigos sem PlanningBasis continuam MTA. CLI avancada e manutencao explicita
permanecem compativeis; artefatos historicos nao sao reescritos pela atualizacao.

Planejamento por evidencias permite avancar com diagnostico parcial, mas nao
certifica compatibilidade ou conclusao global. A revisao precisa distinguir fatos,
declaracoes, limites e validacoes futuras. Perguntas excessivas tambem geram custo;
somente as que mudam escopo, solucao ou aceite devem interromper a proposta.

## Verificacao

Testar selecao unica/ambigua, registro ausente, origem vinculada diferente da mais
recente, retomada sem duplicar solicitacao, nova base com Previous, evidencias sem
MTA, integridade e isolamento dos destinos, documentos legados e implementacao.
Ensaiar nos dois clientes a orientacao de uma etapa, campos Decisao/Andamento,
handoff pronto, perguntas essenciais, sobreposicoes e ausencia de gates artificiais.
Testes automatizados nao comprovam descoberta/delegacao nativa nem qualidade da IA.

Contrato: [fluxo de migracao assistida](../especificacoes/planejamento-copilot.md).
Uso: [planejamento](../guias/tools/planejamento-migracao.md).
