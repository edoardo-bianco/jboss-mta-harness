# Planejamento de corretivas pelo Copilot

Contrato aprovado em 2026-09-26. Define o comportamento do harness; instrucoes de
uso estao no [guia do desenvolvedor](../guias/harness-migracao-desenvolvedor.md#planejar-lotes-de-correcao-com-copilot).

## Objetivo e limites

O harness prepara evidencia selecionada pelo desenvolvedor. O GitHub Copilot,
acionado explicitamente no VS Code, produz a proposta de corretivas. O desenvolvedor
controla revisao, escolha do lote e autorizacao de implementacao posterior.

Na preparacao de prompts, preservar fontes, configuracao e rodadas. Nunca executar corretivas,
Maven/MTA ou enviar mensagens ao agente durante a preparacao. Commit/push exigem
pedido explicito. Nao ampliar o escopo a outros projetos para completar evidencias.

## Separacao de trabalhos e continuidade

A [ADR-0002](../adr/0002-separacao-harness-e-migracao-progressiva.md) define os dois
trabalhos: evolucao do harness (inclusive prompts e Run Tasks) em tasks/ e migracao
da aplicacao em PlanPath/TodoPath. O prompt deve distinguir esses escopos e prever
no to-do revisao/GO humano antes da execucao e revisao/aceite humano apos as verificacoes.

Mesmo com milhares de ocorrencias, identificar e planejar apenas um lote consistente.
O proximo so e identificado apos verificacoes e aceite do atual, mediante pedido,
com reconciliacao da nova rodada e historico. Falhas/pendencias impeditivas exigem
retrabalho. Conclusao global requer cobertura acumulada reconciliada, nenhuma
ocorrencia/verificacao pendente no escopo e aceite humano final. A preparacao do
contexto e o prompt de planejamento nao automatizam a execucao desse ciclo.

## Requisitos observaveis

O template seleciona `agent: devsquad`, disponibilizado pelo plugin DevSquad no
Copilot do desenvolvedor. Usar skills de SDLC pertinentes ao planejamento e relatar
as efetivamente lidas; indisponibilidade deve ser explicita. O prompt habilita
`agent` para uma delegacao a `devsquad.plan`, alem de leitura/busca e edicao.
Preparar contexto copia essa configuracao; nao instala nem verifica o plugin no cliente.

O condutor valida o recibo e repassa ao especialista identidade, caminhos literais,
evidencias autorizadas e contrato completo do prompt. O planejador usa as skills
para elaborar os dois documentos em memoria e retorna `[CREATE]`/`[EDIT]`;
somente o condutor grava e rele PlanPath/TodoPath apos conferir o retorno.
O pedido de planejamento ja autoriza essa persistencia, nunca a implementacao.
Dados de runtime ausentes ficam PENDENTES na proposta; identidade/destinos
divergentes impedem escrita. Retorno incompleto ou falha parcial deve ser explicito.

Esse modo adapta os defaults do plugin: contexto MTA substitui descoberta de
spec/envisioning, destinos do recibo substituem docs/ e tasks.md, e o planejador
analisa diretamente sem subdelegacao. Nao criar ADRs/diagramas/board, executar
terminal/web/Git/testes ou avancar para outras fases. Os especialistas podem ter
ferramentas proprias: esses limites sao comportamentais, nao isolamento tecnico.
Ausencia de agent/devsquad.plan deve ser detectada antes da triagem; nao simular
delegacao ou persistencia. O ensaio Local deve comprovar invocacao do especialista,
skills relatadas, somente dois documentos escritos e releitura antes de concluir.
Testes de preparacao nao comprovam obediencia do modelo ou integracao do plugin.

A [ADR-0004](../adr/0004-git-informativo-sem-controle-de-branches.md) substitui
os gates Git da ADR-0003. O desenvolvedor escolhe a branch; o harness apenas coleta
Git informativo. Nao ha cadastro de politica, responsavel ou coordenacao, tarefa
de conferencia ou bloqueio por ausencia/diferenca de branch/HEAD/estado local.
`gitPolicies` legadas sao ignoradas sem reescrever configuracoes ou recibos.
Novos contextos mantem Git/MtaGit distintos e deixam de gerar Policy e alinhamentos.
Contextos antigos com/sem esses campos continuam validos para consulta/continuidade.
`VERIFIED` confirma coleta, nao GO; `UNAVAILABLE` nao bloqueia a preparacao.
Abertura de planos nao consulta um gate Git. Projeto, integridade MTA e destinos
permanecem verificados. A aplicabilidade depende do conteudo tecnico relevante,
nao da igualdade do nome da branch ou do commit. Nao exigir novo contexto apenas
por trocar de branch; o desenvolvedor informa sua escolha ao agente.

- Projetos vem do workspace salvo, inclusive agregadores Maven; nenhum cadastro
  adicional e necessario. Reutilizar identidade e validacao do harness.
- Novas analises ficam em `.harness/runs/<nome>__<chave12>/mta_<data-fuso>__<RunId12>/`
  e builds em `.harness/builds/<nome>__<chave12>/build_<data-fuso>__<RunId12>/`.
  Mesma convencao do planejamento; instantes CreatedAtUtc/StartedAtUtc e IDs
  completos nos recibos. Estruturas internas do MTA permanecem intactas.
  Leitores MTA aceitam tambem `<Project>/<RunId>`, sem mover historico; usam
  identidades completas e fonte do manifesto. RunId duplicado e recusado.
  Com mta.runsPath configurado, novas rodadas usam `<runsPath>/p__<chave12>/<RunId>/`;
  location.json no indice local preserva descoberta de logs/relatorio/planejamento
  apos mudanca da configuracao, sem mover evidencias existentes. O manifesto
  externo deve corresponder a identidade, fonte e referencia local. Limpeza
  inclui somente rodadas externas registradas e validadas, nunca a raiz externa.
  Compartilhamento usa copia completa de static-report para consulta, conforme
  o guia do desenvolvedor; nao substitui caminhos/evidencias dos contextos existentes.
- Oferecer a ultima rodada elegivel do projeto; permitir historico por data UTC,
  status e RunId. Mostrar tentativa mais recente indisponivel; cancelar sem gerar.
- Elegibilidade exige identidade de manifesto/resultado/fonte consistente,
  SUCCEEDED/exit 0, integridade historica confirmada, nenhum arquivo inesperado,
  achados, dependencias, relatorio HTML e pasta de regras disponiveis.
- Revalidar antes de gerar. Cada solicitacao produz prompt e recibo context.json
  sob `.harness/planning/<nome>__<chave>/mta_<data-fuso>__<RunId12>/plano_<data-fuso>__<RequestId12>/`,
  sem sobrescrever historico. Nome do projeto sanitizado e limitado a 24 caracteres;
  chave estavel de 12 caracteres derivada da identidade do projeto. Datas locais
  distinguem inicio MTA e preparacao, com deslocamento UTC explicito; IDs completos
  e instantes UTC permanecem no recibo. Rotulo nao substitui identidade/fonte.
  O recibo registra hashes SHA-256 de manifest.json, result.json, output.yaml e
  dependencies.yaml, e define PlanPath/TodoPath na mesma pasta. Somente o Copilot
  escreve os dois resultados; o harness nao cria planos de corretivas ficticios.
- Descobrir tambem o formato anterior `<Project>/<RunId>/<RequestId>`, sem mover
  arquivos nem alterar recibos/vinculos. Mudanca de rotulo do projeto nao deve perder
  seu historico. Conferir identidade completa, fonte e caminhos registrados nos
  dois formatos antes de listar/abrir ou vincular uma proposta anterior.
- A tarefa `Planejamento: abrir plano e to-do` seleciona projeto e documentos
  existentes pela data de preparacao e data MTA, com fuso e IDs visiveis. Abre apenas
  os dois arquivos no editor fornecido, sem gerar contexto, enviar ao agente ou
  alterar documentos. Cancelamento e ausencia de ambos os arquivos nao abrem editor.
- Permitir escolher proposta anterior persistida do mesmo projeto, sem selecao
  implicita por recencia. Conferir identidade/caminhos e hashes das evidencias
  anteriores; registrar sua identidade e hashes de contexto/plano/tarefas.
  A nova solicitacao fixa o novo RunId e preserva a antiga. Presenca de arquivos
  permite seleciona-los, mas nao comprova aprovacao ou validacao de um lote.
- Copiar o prompt versionado vigente e acrescentar contexto explicitamente
  vinculado ao RunId, com caminhos de evidencias e raiz real. Registrar hash do
  prompt de origem. Nova rodada nao muda solicitacao preparada anteriormente.
- Abrir no editor fornecido pela tarefa, sem envio automatico. Se abertura falhar,
  informar o arquivo salvo e alternativa pelo chat. Nenhuma extensao nova.
- Afirmar que os fontes atuais ainda nao foram verificados; o agente deve comparar
  os trechos pertinentes com a evidencia historica antes de concluir aplicabilidade.
- Separar premissas confirmadas do destino, evidencias observadas e verificacoes
  pendentes. Hibernate ORM 5.3 fornecido pelo EAP 7.4 e premissa do perfil, sem
  presumir uso por toda aplicacao nem inspecao do ambiente instalado. Versao exata,
  uso efetivo e API/comportamento candidatos exigem evidencia. Divergencias devem
  ser expostas para esclarecimento, sem descartar a premissa ou a evidencia.
- Proposta do Copilot inclui evidencias, dependencias, lote ativo, complexidade e
  justificativa, risco/confianca, precondicoes, rota e criterios de validacao. Regras
  detalhadas vivem somente no [prompt](../../.github/prompts/planejar-lotes.prompt.md).
- Cada lote exige verificacao dos POMs/dependencias relevantes, incluindo origem
  e resolucao de versoes, escopos, heranca/BOMs/perfis, transitivas, consumidores
  e impacto na compilacao/testes/empacotamento/runtime. Declarar estado, evidencias,
  ajustes e pendencias que impedem executar. Evidencia ausente permite proposta
  preliminar, nunca uma afirmacao de compatibilidade ou build/testes aprovados.
- Planejamento progressivo por objetivo: um lote ativo, leitura delimitada e
  cobertura parcial rastreavel. Nao exigir enumeracao/detalhamento de todo o MTA.
  Retomada na mesma rodada le e atualiza somente PlanPath/TodoPath. Nova rodada
  permite reconciliar com Previous antes de propor outro lote, mediante pedido.
- O plan.md identifica solicitacao, projeto, rodada, referencia anterior, objetivo,
  proposta e historico; todo.md referencia o plano e tarefas do lote ativo. Ambos
  sao separados de tasks/ do harness. Ferramentas de escrita nao restringem paths
  tecnicamente; o prompt delimita as duas saidas e exige releitura apos gravar.
- Estados de POM declarado, resolucao, API/testes, empacotamento e runtime sao
  separados. Ajustes de POM ja demonstrados devem ser explicitos. Buscas em output
  limitam-se a output.yaml/dependencies.yaml; nao abrangem logs.

## Revisao com evidencias complementares

Pedido do desenvolvedor em 2026-09-28: manter planejamento inicial simples e
oferecer revisao documental do mesmo lote com MTA e outros resultados fornecidos.
O prompt separado `revisar-lote` recebe o caminho do prompt preparado e o de um
indice de evidencias; reutiliza o contrato desse contexto e exige Previous com
plano/to-do do lote existente.

Evolucao de 2026-09-29: a mesma task de preparo oferece selecao explicita entre
planejar-lotes e revisar-lote, sem nova entrada no catalogo. O modo revisar-lote
exige Previous de proposta persistida e caminho explicito para LEIA-ME.md existente.
Selecao vazia/cancelada, proposta ausente e indice ausente nao criam solicitacao.
Nao escolher indice ou proposta pela recencia. A tarefa verifica existencia do
indice; verificacao de Project/Source/lote/conteudo permanece com o revisor.

Preservar o contexto-base planejar-lotes.prompt.md e gerar tambem uma copia do
contrato revisar-lote.prompt.md com ContextPromptPath/EvidenceIndexPath explicitos.
Abrir o prompt de revisao e exibir somente a chamada /revisar-lote com ambos os
caminhos. Registrar Operation e EvidenceIndexPath no recibo de revisao; os hashes
existentes de MTA/Previous e PromptSha256 do template-base mantem sua semantica.
Nao criar hashes para o indice/arquivos adicionais nem editar evidencias ou Previous.
Executar Prompt deve receber os dois caminhos sem depender de memoria do chat.

CLI: -SelectOperation ativa o menu usado pela task; -Operation revisar-lote e
-EvidenceIndexPath permitem selecao por parametros, com -PreviousRequestId.
Sem selecao de operacao, preservar o padrao planejar-lotes dos consumidores atuais.
-NewPlan nao e compativel com revisao. Contextos historicos continuam utilizaveis
com a chamada manual de /revisar-lote e indice explicito; nao exigir regeneracao.

A tarefa Planejamento: criar pasta de evidencias reutiliza selecao de projeto
do workspace, identidade, chave de pasta e data do harness. Cria somente pasta
nova e LEIA-ME.md baseado no modelo do guia, com Project/Label/Source/data e
instrucoes de feedback, build/MTA, Previous e revisar-lote. ID do lote e objetivo
ficam para o desenvolvedor; nao selecionar plano/MTA por recencia. Nao exigir
rodada previa para criar a pasta. Cancelar selecao nao cria arquivos. Repeticao
preserva pastas existentes; sufixo aleatorio evita colisoes, sem hashes de arquivos.
Abertura no editor e opcional; falha de abertura informa o indice salvo.

O operador guarda arquivos em `.harness/evidencias/<nome>__<chave12>/evidencias_<data-fuso>__<id12>/`
e descreve projeto/fonte, data, ambiente, artefato/versao e finalidade em LEIA-ME.md.
O indice delimita os arquivos autorizados para leitura. Metadados desconhecidos
sao lacunas, nao valores inventados. O agente nao coleta nem edita essas evidencias.
Esses arquivos nao recebem hashes, assinatura ou verificacao automatica de
integridade. Nao integram o snapshot MTA nem EvidenceHashes; identidade, hashes MTA,
hashes dos documentos anteriores e destinos do contexto continuam como existentes.
Limpeza de execucoes preserva evidencias complementares. A pasta e local/ignorada
pelo Git, nao e criada pelo clone e nao e backup temporario.

DevSquad repassa ao devsquad.plan os caminhos, limites e pedido de revisao.
O planejador compara novas evidencias com o MTA e a proposta, distingue dados
observados/declarados/pendentes e retorna apenas PlanPath/TodoPath atualizados.
Preservar ID do lote e historico; manter alteracoes de proposta nao aprovadas.
Mudanca de escopo/abordagem exige nova revisao/GO. Evidencia conflitante nao
autoriza reescrever MTA nem descartar premissas sem esclarecimento.

Aceite desta entrega: guia com estrutura e exemplo, modelo reutilizavel de indice,
pasta local do ensaio, prompt separado com as mesmas ferramentas/limites, leitura
dos contratos e links verificados. O ensaio DevSquad deve demonstrar leitura
delimitada e revisao consistente, sem escrita fora dos dois destinos. Testes
estruturais nao comprovam comportamento do modelo. Nenhuma corretiva nesta entrega.

## Preparo da execucao autorizada

Evolucao solicitada e fluxo de abertura confirmado em 2026-09-30: uma tarefa
distinta, Aplicacao: preparar implementacao do lote, seleciona os documentos
existentes pelo projeto/RequestId e abre um prompt para Executar Prompt no Copilot.
Nao envia mensagem automaticamente nem executa corretiva pelo PowerShell.

Reutilizar Get-MtaPlanningHistory/Select-MtaPreviousPlanning; exigir par completo,
identidade Project/Source/RunId/RequestId e destinos do recibo. Revalidar a rodada
e os quatro EvidenceHashes antes de gerar. Usar planning.lock contra preparacao
ou limpeza concorrente. Nao bloquear por Git ou exigir nova rodada por HEAD.

Gravar implementar-lote_<id12>.prompt.md na mesma solicitacao, sempre novo arquivo,
sem mudar context.json, plan.md, todo.md, Previous ou as evidencias. O bloco de
dados inclui caminhos literais, identidade, PreparedAtUtc, ContextSha256,
PlanSha256, TodoSha256 e TemplateSha256. Escapar delimitadores Markdown nos dados.
O agente confere hashes antes da primeira escrita; alteracao posterior ao preparo
exige novo prompt, nao novo RequestId de planejamento. Hashes fixam versao, nao GO.

O template separado implementar-lote habilita agent, leitura/busca, edicao e
terminal, conforme as ferramentas do plugin instalado. Exige GO humano explicito
do lote/solicitacao; precondicoes continuam exigidas salvo dispensa humana explicita.
Presenca/checkbox/texto de exemplo nao concedem autorizacao. GO curto com responsavel
e referencia a este plano/to-do e suficiente quando identidade/escopo sao inequivocos;
data e opcional. Planejamento e revisao incluem nos dois documentos um bloco editavel
com Responsavel vazio, GO humano PENDENTE, Pendencias dispensadas como precondicao
nenhuma e Aceite do resultado PENDENTE. Nao preencher aprovacao pelo humano.

O operador pode dispensar todas as precondicoes listadas ou somente IDs/descricoes
especificos. GO generico nao dispensa nada; lista seletiva mantem as demais exigidas.
Decisao expressa que substitui exigencias anteriores prevalece sobre estado antigo
PROPOSTA - NAO APROVADA e proibicoes historicas. Nao confundir texto superado com
contradicao humana vigente; ordem no arquivo/mtime nao prova precedencia. Decisao
ambigua, revogada ou conflitante e precondicao impeditiva nao dispensada exigem
esclarecimento pontual; nao afirmar ausencia de GO quando a questao e seu alcance.
Depois das conferencias, condutor encaminha GO/dispensas ao especialista e workers
sem regravar os documentos antes da conferencia deles. Ao registrar os resultados,
concilia estado/resumo/tarefas nos documentos atuais e preserva historico.
Essa conciliacao autorizada na mesma execucao nao exige regenerar prompt; mudanca
externa apos preparo continua sujeita aos hashes. Pendencias dispensadas como
precondicao ficam pendentes de verificacao, sem [x] ficticio ou aceite automatico.
Dispensa nao amplia escopo, nao comprova qualidade/compatibilidade e nao remove
identidade, integridade das evidencias ou autorizacao para operacoes externas.
O condutor passa contrato completo ao devsquad.implement; workers validate,
execute, verify e review recebem os mesmos limites. PlanPath/TodoPath substituem
tasks.md/spec/board; nao invocar finalize nem publicar, manipular Git ou memoria.
O executor edita somente o escopo aprovado em Source; o condutor registra resultados
nos dois documentos atuais. Preservar trabalho local, criterios e historico.

Verificacoes exigem comandos/resultados reais; ambiente ausente e falhas permanecem
pendentes. Coletas/operacoes externas exigem autorizacao explicita, sem inferir
permissao de um criterio de aceite futuro. GO e aceite continuam separados;
encerrar com aceite humano pendente, sem proximo lote automatico. O contrato e
comportamental, nao isolamento tecnico das ferramentas do especialista.

Test-Implementation cobre geracao, identidade, hashes, repeticao, cancelamento,
falhas e editor simulado. Test-TaskInputs confere a tarefa e seus argumentos.
O ensaio de GO/delegacao/edicao pelo DevSquad no Copilot e uma verificacao separada;
testes PowerShell nao comprovam comportamento do modelo.

Complemento de 2026-09-30: depois de salvar o prompt e antes de abri-lo, exigir
escolha explicita 1 criar/usar lote/<ID>, 2 continuar na atual, 3 criar/usar nome
manual. Sem padrao; Enter/q cancela, preservando o prompt salvo sem abrir editor.
O helper HarnessImplementation le Lote ativo: ou ID do lote: fora de blocos de
codigo, exigindo ID unico, valido e igual nos dois documentos. Ausencia/divergencia
oferece apenas 2/3. Nome manual e completo/literal, sem prefixo implicito.
Se Git recusar o nome/criacao, exibir o erro e oferecer 2/3 novamente, sem
reexecutar a tarefa nem sobrescrever branch existente.

A mutacao Git ocorre somente apos 1/3, no repositorio de Source, a partir do HEAD
exibido, com git switch --no-track -c; validar nome sem expansoes como @{-1},
reconferir hashes dos documentos e raiz/HEAD/branch observados. Nao substituir
branches existentes nem forcar, fazer stash/reset, commit/push ou definir upstream.
Escolha 2 e somente leitura e nao exige Git/HEAD disponiveis. Excecao autorizada
na ADR-0004; agente Copilot continua sem gerir branches. Test-ImplementationBranch
usa repositorios reais ficticios para validar menus, isolamento e preservacao.

## Implementacao e verificacao

Sonar (baseline/coleta/comparacao) e reexecucao MTA pertencem ao checklist nao
bloqueante do desenvolvedor nos dois documentos. Ausencia dessas verificacoes
nao bloqueia GO, implementacao, entrega ou submissao ao aceite e nao exige dispensa
individual. Preservar [ ]/PENDENTE e limites das evidencias; aceite e decisao humana.
Isso nao elimina o contexto/MTA de origem nem suas conferencias de integridade.
Cobertura <85% gera aviso; nao reprova build. O launcher solicita ao JaCoCo
check -Djacoco.haltOnFailure=false; preservar testes/relatorios e falhas reais.
POM com gate explicito que sobrepoe a propriedade exige ajuste aprovado no projeto,
nao mascaramento do exit code. Outros plugins de cobertura requerem configuracao
equivalente no escopo do lote. Resultados Sonar existentes mantem Blocker/High
reprovados na avaliacao; avisos e falta de coleta nao viram bloqueio automatico.

Para lotes Hibernate no perfil EAP 7.4, planejar-lotes e revisar-lote devem exigir
POMs alinhados ao Hibernate ORM 5.3 do destino como entrega de implementacao,
com tarefa explicita no to-do separada da confirmacao da versao exata. Identificar
propriedade/parent/BOM, Core/integracoes de teste, escopos e evidencia do modulo/
patch do servidor. Sem evidencia, manter versao exata pendente, sem hardcode global.
Verificar versao efetivamente resolvida no build, clean install Java 8, cobertura
e WAR. Testes em 5.1 nao comprovam o alvo 5.3. Dispensa de precondicoes nao retira
essa entrega; retirada exige decisao explicita de escopo. Implementar-lote deve
relatar tarefa faltante ou versao indefinida, sem encerrar por sucesso parcial.

PowerShell 5.1 em `scripts/`, tarefa em `.vscode/tasks.json`, testes com fixtures em
`tests/`. Seguir o padrao existente: `#requires -Version 5.1`, parametros nomeados,
`Set-StrictMode -Version Latest`, mensagens em portugues e `Resolve-HarnessPath`.
Nao alterar ExecutionPolicy nem adicionar dependencias.

```powershell
powershell.exe -NoProfile -File .\tests\Test-Planning.ps1
powershell.exe -NoProfile -File .\tests\Test-Implementation.ps1
powershell.exe -NoProfile -File .\tests\Test-TaskInputs.ps1
powershell.exe -NoProfile -File .\tests\Test-EvidenceFolder.ps1
git diff --check
```

Testar isolamento de projetos, ordenacao, historico, cancelamento, evidencia
ausente/divergente, preservacao de arquivos e contexto fixo. A prova visual exige
executar o prompt no Copilot Local e conferir leitura/proposta; testes PowerShell
nao substituem esse ensaio. Escrita dos documentos, retomada e reconciliacao de
rodadas tambem exigem ensaio no cliente. Nao afirmar conclusao visual sem evidencia.
