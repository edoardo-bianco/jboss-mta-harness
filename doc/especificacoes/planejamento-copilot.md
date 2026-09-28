# Planejamento de corretivas pelo Copilot

Contrato aprovado em 2026-09-26. Define o comportamento do harness; instrucoes de
uso estao no [guia do desenvolvedor](../guias/harness-migracao-desenvolvedor.md#planejar-lotes-de-correcao-com-copilot).

## Objetivo e limites

O harness prepara evidencia selecionada pelo desenvolvedor. O GitHub Copilot,
acionado explicitamente no VS Code, produz a proposta de corretivas. O desenvolvedor
controla revisao, escolha do lote e autorizacao de implementacao posterior.

Sempre preservar fontes, configuracao e rodadas. Nunca executar corretivas,
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
Dados Git/runtime ausentes ficam PENDENTES na proposta; identidade/destinos
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

O contrato de projeto/branch e concorrencia esta na
[ADR-0003](../adr/0003-projeto-branch-e-concorrencia-da-migracao.md). O prompt exige
identidade Git e responsavel nos documentos, com origem/estado da evidencia,
conferencia atual antes de executar/retomar e reconciliacao apos mudancas de HEAD
ou integracao. Lote ativo e por frente; outras frentes sao isoladas e coordenadas.
Os novos contextos registram `Git` coletado na preparacao e `MtaGit` opcional,
proveniente do manifesto historico. `Policy` e declarada pelo operador; `VERIFIED`
indica coleta, nao GO. Contextos antigos sem Git permanecem consultaveis.
A tarefa `Planejamento: conferir Git do lote` compara estado atual com a baseline
do contexto e a politica por Source; divergencias, referencias ausentes, conflitos,
HEAD destacado e alteracoes locais resultam em exit 1. Nao ha fetch nem alteracao
de branches. Abertura dos documentos mostra pendencias sem impedir consulta.
Conferencia e pontual e nao substitui aceite humano ou coordenacao da equipe.

- Projetos vem do workspace salvo, inclusive agregadores Maven; nenhum cadastro
  adicional e necessario. Reutilizar identidade e validacao do harness.
- Novas analises ficam em `.harness/runs/<nome>__<chave12>/mta_<data-fuso>__<RunId12>/`
  e builds em `.harness/builds/<nome>__<chave12>/build_<data-fuso>__<RunId12>/`.
  Mesma convencao do planejamento; instantes CreatedAtUtc/StartedAtUtc e IDs
  completos nos recibos. Estruturas internas do MTA permanecem intactas.
  Leitores MTA aceitam tambem `<Project>/<RunId>`, sem mover historico; usam
  identidades completas e fonte do manifesto. RunId duplicado e recusado.
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

## Implementacao e verificacao

PowerShell 5.1 em `scripts/`, tarefa em `.vscode/tasks.json`, testes com fixtures em
`tests/`. Seguir o padrao existente: `#requires -Version 5.1`, parametros nomeados,
`Set-StrictMode -Version Latest`, mensagens em portugues e `Resolve-HarnessPath`.
Nao alterar ExecutionPolicy nem adicionar dependencias.

```powershell
powershell.exe -NoProfile -File .\tests\Test-Planning.ps1
powershell.exe -NoProfile -File .\tests\Test-TaskInputs.ps1
git diff --check
```

Testar isolamento de projetos, ordenacao, historico, cancelamento, evidencia
ausente/divergente, preservacao de arquivos e contexto fixo. A prova visual exige
executar o prompt no Copilot Local e conferir leitura/proposta; testes PowerShell
nao substituem esse ensaio. Escrita dos documentos, retomada e reconciliacao de
rodadas tambem exigem ensaio no cliente. Nao afirmar conclusao visual sem evidencia.
