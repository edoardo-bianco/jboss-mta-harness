---
name: revisar-resultado
description: Analisa evidencias da corretiva e orienta verificacoes e aceite humano.
argument-hint: Use o prompt preparado junto da implementacao e informe as evidencias.
agent: devsquad
tools: ['agent', 'read/readFile', 'search/listDirectory', 'search/fileSearch', 'search/textSearch']
---

## Direcionamento do desenvolvedor

Evidencias, observacoes e limitacoes da verificacao:

## Trabalho solicitado

Leia o JSON final, ContextPath, PlanPath/TodoPath atuais, MigrationPath e
EvidenceIndexPath quando presentes. Confira Project/Source/RequestId e lote;
PlanningBasis ausente no legado significa MTA. Confira RunId/origem quando a base
for MTA; EVIDENCIAS usa EvidenceInputs e nao exige artefatos ou rodada inexistentes.
Sem contexto explicito, solicite o arquivo preparado; nao busque o mais recente.
Leia DeveloperGuidePath para tarefas e procedimentos, quando existente.
Use ContractSnapshot preservado. As copias PlanSnapshot/TodoSnapshot e hashes sao
historicos do preparo; mudancas de andamento esperadas nao exigem novo preparo.
Conflito de identidade, escopo ou criterio exige esclarecimento. Nao conceda GO/aceite.
Confira ProjectIndexPath quando existente, sem tomar resumo como prova de resolucao.
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
- Sonar ANTES quando existente e DEPOIS: recibos, issues/severidades, comparacao
  e Quality Gate separado. Nao fabricar baseline; checklist nao bloqueante.
- Novo MTA comparavel quando possivel: rodada, perfil, pontos persistentes/novos/
  nao reencontrados e limites. Ausencia limita a comparacao, sem afirmar desaparecimento
  nem transformar diagnostico complementar em bloqueio global.
- Deploy no JBoss EAP 7.4 quando possivel e pertinente: servidor/ambiente autorizado,
  artefato/hash, recibo, status e logs relevantes. Ausencia de ambiente fica explicita.

Derive do codigo e do plano um roteiro funcional da parte corrigida: precondicoes,
dados de teste sem segredos, passos concretos (endpoint/tela/operacao), resultado
esperado, casos negativos/regressao, resultado observado e evidencia a guardar.
Se faltar contrato funcional ou acesso ao ambiente, solicite direcionamento especifico.
Oriente uso do LEIA-ME das evidencias com origem/data/ambiente e relacao por issue.
Nao execute build, Sonar, MTA ou deploy; esta etapa analisa e orienta o desenvolvedor.
Nao altere arquivos, integre, publique, escolha outro lote ou declare conclusao global.
Informe criterios atendidos, falhas, pendencias e o que fornecer antes do aceite humano.
Use PENDENTE apenas para acao concreta ainda necessaria ao criterio escolhido;
nao solicite repetir aceite vigente, escolhas ou evidencias ja comprovadas.
