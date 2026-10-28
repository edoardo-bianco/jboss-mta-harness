# Plano do lote: {{Batch}}

## 1. Identificacao e situacao

{{IdentityAndStatus}}

## 2. Contexto, fontes e diagnostico

{{ContextAndFindings}}

## 3. Objetivo e escopo

{{Scope}}

## 4. Solucao por arquivo, classe e metodo

{{Solution}}

## 5. Dependencias e ordem

<!-- Registrar a escolha humana para varias issues: juntas, uma fase por issue ou fases agrupadas. Perguntar somente se ainda ausente. Identificar fases, issues, passos E1/E2, dependencias e condicao de passagem ate cobrir todo o lote, preservando IDs existentes. Fases nao criam novos lotes/branches/GO automaticamente. -->
{{Dependencies}}

**Execucao manual por padrao:** build, release/publicacao quando prevista, deploy,
verificacoes e testes locais ou contra servidor ficam com o desenvolvedor.
O agente para, indica a Run Task/comando, diretorio/ambiente, entradas sem segredos,
resultado esperado e evidencia a devolver; aguarda o retorno, analisa, registra
e so entao segue. Falha ou retorno insuficiente mantem a etapa pendente.
Leituras locais de artefatos/logs/evidencias ja gerados e escrita autorizada de
codigo/testes continuam com o executor. Excecoes exigem atribuicao humana explicita
da operacao ao agente, com alcance/destino/finalidade; preservar decisoes existentes.

## 6. Passos manuais

<!-- Cada E identifica issue/fase, responsavel pela acao, entrada, acao, saida e verificacao. Explicitar os pontos de parada manual e a evidencia exigida para retomar. Preservar numeracao e trabalho comprovado; escrever teste e executa-lo sao tarefas distintas. -->
{{Steps}}

## 7. Verificacoes e criterios de aceite

{{Verification}}

## 8. Riscos e reversao

{{RisksAndRollback}}

## 9. Revisao, GO, execucao e aceite

<!-- GO, alcance e dispensas ficam aqui; o to-do referencia esta secao. Registrar decisao humana sem inventar autorizacao. GO vigente pode cobrir todas as fases; mudanca de alcance exige revisao, preservando o texto anterior. Aceite do lote permanece separado das verificacoes por fase. -->
{{HumanDecisions}}

<!-- planejamento:fontes:inicio -->
{{Sources}}
<!-- planejamento:fontes:fim -->
