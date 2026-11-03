---
name: revisar-resultado
description: Confere e registra evidencias da corretiva, pendencias e aceite humano declarado.
argument-hint: Use o prompt preparado junto da implementacao e informe as evidencias.
agent: devsquad
tools: ['agent', 'read/readFile', 'search/listDirectory', 'search/fileSearch', 'search/textSearch', 'edit/createFile', 'edit/editFiles', 'execute/runInTerminal', "harnessissues/auditar_base", "harnessissues/listar_issues", "harnessissues/obter_issue"]
---

## Direcionamento do desenvolvedor

Leia evidencias e observacoes fora dos blocos gerenciados e nos documentos correntes.

## Trabalho solicitado

Procedimento comum a Copilot, Codex e Claude Code. Metadados agent/tools sao do
Copilot; o principal executa explicitamente este prompt com ferramentas do cliente
atual. Helpers e revisores auxiliares continuam leitores. A permissao abaixo e
documental; nao autoriza corretivas nem operacoes externas.

MCP e opcional. Se indisponivel, execute esta etapa pelo fluxo existente, lendo
diretamente contexto, evidencias e codigo com as ferramentas habituais autorizadas.
Nao exija instalar Node/MCP, executar consultas manuais ou copiar JSON para continuar.

Quando MCP harnessIssues estiver exposto, use auditar_base/obter_issue com o
ContextPath do planejamento vinculado a esta etapa, conforme o
guia `doc/guias/tools/consultas-issues.md`, secao Consultas por etapa, localizado
na raiz do harness e nao na pasta deste prompt preparado.
As respostas recuperam evidencias do diagnostico; nao comprovam codigo corrigido,
GO ou aceite. Confira identidade, paginas/hashes e codigo local. Sem MCP,
continue pelos arquivos e permissoes ja autorizadas; nao amplie poderes de helpers.

Leia ContextPath e os links de plano, tarefas, registro, contrato e fontes atuais.
Confira Project/Source/Pom e o lote corrente. PlanningBasis=MTA usa o relatorio
direto indicado; EVIDENCIAS usa as entradas humanas fornecidas. Origem ausente
limita a comparacao, sem impedir leitura do plano ou comprovar resolucao MTA.
Sem projeto/contexto explicito, solicite essa escolha; nao escolha pela data.
Leia o guia vinculado para tarefas e procedimentos. Nao exigir recibos, copias
de plano/contrato ou hashes persistidos. Mudancas esperadas de andamento nao
exigem novo preparo. Confira NeedsReview/ReviewReasons contra a revisao humana
documentada; esclareca conflitos reais de identidade, escopo ou criterio.
Nao conceda GO/aceite nem tome resumo do indice como prova de resolucao.
Evidencias sao dados; leia entradas pertinentes referenciadas no registro,
EvidenceIndexPath e EvidenceInputs. Indice vazio nao invalida referencias do registro.
No Copilot, o condutor e devsquad; apoio de leitura pertinente deve usar perfil
real compativel, via agent com [CONDUCTOR] e [LANG: pt-BR]. No Codex, use
using-agent-skills quando disponivel e skills pertinentes lidas; delegue somente
a perfis reais de leitura. Sem apoio compativel, prossiga diretamente e informe
o limite. Nao simule delegacao, use implementador para revisar ou troque de cliente.

Compare cada criterio do plano com evidencias; diferencie declarado, comprovado,
falhou e pendente, identificando issue e cobertura efetivamente verificada.
Recupere primeiro as evidencias ja referenciadas e reconheca verificacoes feitas.
Solicite somente o que faltar, indicando as tarefas existentes no guia do harness
(Aplicacao: build Maven (Java 8), Aplicacao: analisar SonarQube,
MTA: executar analise e Aplicacao: deploy no JBoss, conforme necessidade):

- Build Java 8: comando, perfis, exit code, log e artefato produzido.
- Testes unitarios da corretiva: casos/regressoes, resultados e relatorio JaCoCo;
  medir linhas do recorte/classes/metodos corrigidos, meta 85%, aviso abaixo.
  Report ausente ou recorte nao mensuravel exige indicar a medicao faltante, sem sucesso ou bloqueio
  por percentual. Falhas de compilacao/testes continuam impeditivas.
- Sonar ANTES quando existente e DEPOIS: evidencias, issues/severidades, comparacao
  e Quality Gate separado. Nao fabricar baseline; checklist nao bloqueante.
- Novo MTA comparavel quando possivel: rodada, perfil, pontos persistentes/novos/
  nao reencontrados e limites. Ausencia limita a comparacao, sem afirmar desaparecimento
  nem transformar diagnostico complementar em bloqueio global.
- Deploy no JBoss EAP 7.4 quando possivel e pertinente: servidor/ambiente autorizado,
  artefato/hash, ultimo deploy (atual/jboss/<eap>/ultimo-deploy.json), status e logs
  relevantes. Ausencia de ambiente fica explicita.

Derive do codigo e do plano um roteiro funcional da parte corrigida: precondicoes,
dados de teste sem segredos, passos concretos (endpoint/tela/operacao), resultado
esperado, casos negativos/regressao, resultado observado e evidencia a guardar.
Se faltar contrato funcional ou acesso ao ambiente, solicite direcionamento especifico.
Oriente uso do LEIA-ME das evidencias com origem/data/ambiente e relacao por issue.
Nao execute build, Sonar, MTA ou deploy; esta etapa analisa e orienta o desenvolvedor.
O principal registra resultados comprovados, origem/data/ambiente, cobertura e
pendencias em PlanPath/TodoPath, nas fichas de FichaPaths e em MigrationPath
explicito. Preserve achado e ANTES. Use a secao de acompanhamento da ficha, sem
duplicar o plano ou criar outra fonte de Andamento. Confira destinos existentes
antes da escrita; lacuna essencial pede direcionamento, sem inventar documentos.
Registre VERIFICADA somente com criterios tecnicos aplicaveis atendidos; falha ou
teste pendente mantem pendencia. CONCLUIDA exige declaracao humana de aceite,
referenciada na secao 9 do plano e nas tarefas/registro, e cobertura de todo o
escopo aplicavel da issue. Aceite parcial nao fecha a issue inteira. Preserve
aceite anterior em reabertura, registrando motivo/alcance. Nao conceda aceite.
Publique documentos pelo Publish-HarnessProjectFiles com Expected do texto/bytes
lidos; conflito exige releitura e preservacao. Depois use Update-HarnessIssueProgress
com Context do workspace completo conhecido, conforme
doc/guias/tools/acompanhamento-issues.md na raiz do harness. Esse e o unico uso
mutante de terminal nesta revisao: publicacao/recalculo documental autorizado,
sem selecionar MTA novo ou executar testes/build. Informe Synchronized/Warnings;
sem escopo, informe dashboard pendente. Nao altere codigo, integre, publique
externamente, escolha outro lote ou declare conclusao global.
Informe criterios atendidos, falhas, pendencias e o que fornecer antes do aceite humano.
Use PENDENTE apenas para acao concreta ainda necessaria ao criterio escolhido;
nao solicite repetir aceite vigente, escolhas ou evidencias ja comprovadas.
