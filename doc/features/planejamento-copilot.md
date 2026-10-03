---
html:
  embed_local_images: true
  embed_svg: true
  offline: true
---

# Historico: preparar planejamento com evidencia MTA

Registro dos ensaios de 26 a 28/09/2026. Estados e pendencias abaixo pertencem
aquelas datas; nao sao instrucoes atuais nem pendencias a renovar. Para uso,
consulte o [guia do desenvolvedor](../guias/harness-migracao-desenvolvedor.md);
para trabalho atual, consulte o [to-do](../../tasks/todo.md).

Status na epoca: implementada e validada nos scripts; ensaio de leitura/proposta no Copilot
relatado pelo desenvolvedor em 2026-09-26. Refinamento aprovado: distinguir
premissas confirmadas do destino, evidencias e verificacoes pendentes.

Em 2026-09-27, ensaio com devsquad confirmou gravacao de plan.md e todo.md na
solicitacao 6901b92111044988ad778f7411c1dba7, conferidos com as evidencias locais.
Retomada em nova conversa e reconciliacao apos novo MTA continuam pendentes.
A primeira tentativa parou por falta de delegacao; a segunda concluiu sem ela,
com indisponibilidade de uma skill relatada. Nao comprova estabilidade entre tentativas.

Em 2026-09-28, novo ensaio na rodada 391c4a60505440fdb26d4b6419bfa643
terminou sem gravacao: o condutor recusou autoria direta e o prompt proibia
delegacao. Ajuste: habilitar agent, delegar a elaboracao a devsquad.plan com
skills e contrato MTA explicito, e centralizar a persistencia no condutor.
Nao altera o plugin; evita subdelegacao e artefatos do fluxo generico em docs/.
Validacao do comportamento desse ajuste no Copilot: PENDENTE do novo ensaio.

Em 2026-09-28, o desenvolvedor solicitou remover o controle de branches.
Cadastro, gate e tarefa de conferencia foram retirados. Git permanece informativo;
identidade do projeto e integridade MTA continuam verificadas. A ADR-0004 define
a transicao, preservando propostas/recibos antigos e GO separado.

Problema: escolher entre varios projetos e rodadas exige preencher caminhos
manualmente antes de pedir uma proposta ao Copilot.

Entrega: tarefa que oferece a ultima rodada valida do projeto ou uma rodada
historica, permite vincular proposta anterior e prepara contexto com identidade
e hashes. O desenvolvedor inicia o agente, que persiste plano/tarefas de um lote
por objetivo e permite continuidade progressiva, sem planejar todo o MTA.

Novas solicitacoes mostram nome do projeto, data MTA e data de preparacao nas
pastas, com IDs abreviados e identidade completa no recibo. A tarefa de abrir
plano/to-do permite selecionar por projeto e datas e preserva o historico antigo.

Escopo desta evolucao: selecao, contexto, acionamento explicito e contrato de
proposta persistida com complexidade e rotas de correcao. Os testes locais validam
preparacao e vinculos; gravacao foi observada no ensaio acima e retomada ainda
exige novo ensaio. Implementar as corretivas e automatizar o ciclo
OpenRewrite/Sonar/EAP ficam fora desta entrega.

Aceite funcional: [especificacao](../especificacoes/planejamento-copilot.md).
Decisao de integracao: [ADR-0001](../adr/0001-contexto-copilot.md).
Execucao corrente do agente: [plano](../../tasks/plan.md) e [to-do](../../tasks/todo.md).
