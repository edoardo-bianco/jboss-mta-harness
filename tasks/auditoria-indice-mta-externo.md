# Auditoria independente do checkpoint indice/MTA externo

Data: 21/10/2026. Escopo: evolucao do harness, conforme ADR-0002.

Checkpoint auditado: 87a8725c1dd3b9b880f7d1db908a0c97ec87bc09, branch
harness/indice-mta-externo, checkout C:/Temp/harness-indice-mta.
Comparacao: eb44383..87a8725 (tres commits). O checkout estava limpo e alinhado
ao remoto no inicio. O checkout operacional original nao foi alterado.

**Parecer inicial em 87a8725: corrigir os dois achados P2 antes de considerar o checkpoint pronto
para a PR.** Ha tambem uma contradicao documental P3. Os orientadores estao
alinhados no recorte inspecionado, com limites de validacao comportamental
descritos abaixo.

Corretivas posteriores concluidas; veja a secao final deste parecer.

## Metodo e independencia

Aplicadas as skills using-agent-skills e code-review-and-quality.
Tres revisores com contexto separado examinaram documentacao, orientadores e
runtime/testes. O condutor consolidou os achados, verificou navegacao e executou
regressao em copia isolada. A validacao anterior em tasks nao foi tomada como
prova de ausencia de defeitos.

Foram cruzados README, AGENTS, ADR-0002/0009, contratos, guias, desenho do
Engineering Harness, skill/papeis, adaptadores Codex/Copilot/Claude Code,
prompts, templates, consumidores e testes. Historico e propostas futuras
foram distinguidos de instrucoes correntes.

## Achados que exigem ajuste

### A1 — P2: uma falha da associacao deixa a rodada MTA externa publicada

Fonte: [Publish-MtaExternalReport](../scripts/HarnessMtaExternalPublication.ps1),
linhas 38-40; tratamento em [Invoke-MtaAnalysis](../scripts/HarnessMtaExecution.ps1).

A funcao move a saida para a pasta datada antes de publicar projeto.json.
Se a gravacao da associacao falhar, a operacao termina como FAILED, mas a
rodada permanece fora da area de preparo. Uma atualizacao posterior do indice
pode descobrir e adotar essa rodada, apesar da falha de publicacao.

Reproducao independente: executar a funcao real em fixture temporaria, com
dependencias de acesso substituidas em memoria, e injetar uma excecao em
Publish-HarnessProjectFiles durante a primeira associacao. A excecao foi
observada e index.html permaneceu no destino externo datado.

Impacto: publicacao parcial e possibilidade de trocar o diagnostico corrente
apos uma operacao declarada falha. Pode ocorrer com falha de I/O, bloqueio de
arquivo ou alteracao concorrente na associacao.

Correcao recomendada: coordenar a publicacao externa e a associacao para que
uma falha nao deixe uma rodada elegivel para adocao automatica; preservar as
alteracoes concorrentes. Acrescentar teste com falha depois do move. O caso
existente de concorrencia em Test-Mta falha antes desse ponto.

### A2 — P2: raiz externa configurada oculta diagnostico interno valido no indice

Fonte: [Read-ProjectIndexMta](../scripts/HarnessProjectIndex.psm1), linhas 14-21.
Contrato: [ADR-0009](../doc/adr/0009-estado-corrente-por-projeto.md), compatibilidade
de leitura dos diagnosticos internos anteriores.

Cenario: projeto com mta.diretorio vazio, diagnostico interno historico valido e
mta.runsPath configurado, mas sem relatorio externo para a pasta Source.
O indice so considera o diagnostico interno quando runsPath nao esta configurado;
nesse cenario tenta exclusivamente a origem externa indisponivel.

Reproducao independente com funcoes reais e relatorio sintetico: a leitura por
Read-HarnessProjectMta encontrou o index.html interno; Read-ProjectIndexMta
lancou erro de origem MTA indisponivel. O indice resultante apresenta ausencia
e deixa de oferecer o link do diagnostico ainda utilizavel.

Impacto: configurar a saida obrigatoria para a proxima analise prejudica a
navegacao e a cobertura do indice antes de existir um substituto valido.
O arquivo historico nao e apagado, mas os leitores passam a divergir.

Correcao recomendada: manter o diagnostico historico utilizavel enquanto
nenhuma origem externa valida for associada e explicitar a lacuna externa.
Preservar a regra que impede fallback quando mta.diretorio ja foi escolhido
explicitamente. Cobrir historico + raiz externa vazia + primeira tentativa
ausente ou falha em teste de indice.

### A3 — P3: principio de armazenamento contradiz a excecao MTA

Fonte: [System design](../doc/engineering-harness/02-system-design.md), linha 314,
em contraste com a linha 370 do mesmo documento.

O principio ainda diz que carimbo de data nao aparece em caminhos e que uma nova
execucao substitui o conteudo corrente. A secao MTA exige pastas externas datadas
e preservacao das anteriores.

Correcao recomendada: limitar o principio aos documentos e estado corrente da
.harness e declarar a excecao dos relatorios MTA externos. O documento de
estrategia ja recebeu ajuste equivalente. Nao foi encontrado bloqueio operacional
adicional na documentacao examinada.

## Orientadores e templates

Skill, papeis e 18 adaptadores dos tres clientes estao coerentes quanto a:

- MTA externo, identidade pelo artifactId e associacao pela pasta Source.
- Inicio pelo indice e retirada do conversor legado.
- Sincronizacao do indice distinta de reconciliacao tecnica.
- Helpers leitores e passagem explicita ao executor.
- Preservacao de decisoes, GO aplicavel e separacao de aceite.
- ANALISAR AGORA separado do Andamento.
- Ficha unica por projeto/categoria/issue e progressao cumulativa.
- Leitura obrigatoria dos templates e preservacao do texto humano.

O [inventario de modelos](../doc/modelos/README.md) identifica consumidores;
geradores automaticos foram exercitados. Os prompts vinculam os modelos
obrigatorios, inclusive na reconciliacao.

**Lacuna P3 de cobertura:** [Test-ClaudeAdapter](../tests/Test-ClaudeAdapter.ps1),
linhas 17-42, compara inventario dos tres clientes, mas verifica ferramentas,
restricoes e subdelegacao estruturalmente apenas no Claude. Estender a verificacao
a Codex e Copilot reduziria o risco de divergencia futura. Nao foi encontrada
divergencia atual nesses perfis.

**Limite comportamental:** [Test-OutputTemplates](../tests/Test-OutputTemplates.ps1)
comprova consumo pelos produtores e referencias/instrucoes nos prompts.
Isso nao comprova que um agente real leu e preencheu o modelo. Descoberta,
delegacao e uma retomada preservando texto humano ainda precisam de ensaio
nativo nos clientes; esta auditoria nao o executou.

## Verificacoes executadas nesta auditoria

Doze suites passaram pelo runner oficial, em copia descartavel, com
Windows PowerShell 5.1 e TEMP/TMP em C:/Temp somente no processo:

- Test-ProjectIndexSummary, Test-ProjectIndexExternalMta, Test-OutputTemplates.
- Test-CurrentPromptLinks, Test-ClaudeAdapter, Test-TaskInputs.
- Test-MigrationTask, Test-TestIsolation, Test-Mta.
- Test-ReconciliationSources, Test-PrioritizationProgress, Test-PrioritizationIndex.

Mutacao independente: inverter a condicao de associacao explicita em
Read-ProjectIndexMta, somente em copia descartavel do checkpoint.
Test-ProjectIndexExternalMta falhou na verificacao da raiz externa.
O arquivo da copia foi restaurado byte a byte e as copias removidas.
O checkout auditado permaneceu inalterado durante o experimento.

Navegacao: 77 arquivos Markdown fora de tasks, 610 referencias locais e
415 ancoras locais examinadas. Nenhuma ancora ausente. Seis destinos inexistentes:
quatro exemplos/modelos destinados a ser preenchidos e duas referencias antigas
a uma matriz ausente, nos guias de estrategia EAP abaixo. Nenhum link novo
quebrado nem consumidor ativo do conversor removido encontrado.

- [Estrategia EAP](../doc/estrategia-migracao-ambientes-jboss-eap-7.4/estrategia-migracao-ambientes-jboss-eap-7.4.md), linha 6.
- [Guia operacional EAP](../doc/estrategia-migracao-ambientes-jboss-eap-7.4/guia-operacional-jboss-eap-7.4-windows-des.md), linha 1098.

Os dois links antigos devem ser regularizados em manutencao documental; nao
foram introduzidos por este checkpoint. O exemplo JSON do guia MTA tambem pode
incluir runsPath para ficar completo; a tabela e a explicacao ja informam
corretamente sua obrigatoriedade.

## Limites e encaminhamento

Suites verdes nao cobrem os cenarios A1/A2, confirmados pelas reproducoes
independentes. As fixtures dessas reproducoes foram removidas apos verificacao
de identidade/caminho. Nao foram usados dados reais, MTA real, clientes nativos,
links HTTP ou teste de ponta a ponta da migracao.

A auditoria inicial registrou os achados sem implementar corretivas, abrir PR,
fazer merge ou publicar alteracoes. As corretivas autorizadas posteriormente
e suas verificacoes estao registradas na secao seguinte.


## Corretivas verificadas - 21/10/2026

A1, A2 e A3 corrigidos nesta branch apos autorizacao do desenvolvedor.

- A1: falha na associacao retira somente a rodada nova para a area de preparo.
  A publicacao local continua responsavel por preservar a associacao e edicoes
  concorrentes. Se a retirada tambem falhar, ambos os erros e o caminho sao
  informados; o objeto transitorio de preparo impede a limpeza automatica desse
  material. A flag nao e persistida. Conferencia manual continua necessaria
  diante dessa falha dupla; nao se promete atomicidade com o filesystem indisponivel.
- A2: enquanto nao houver mta.diretorio escolhido, descoberta externa sem conjunto
  utilizavel conserva o diagnostico interno valido, com aviso nos indices geral
  e do projeto. A associacao e conferida novamente sob protecao de acesso.
  Origem explicitamente escolhida indisponivel continua sem fallback.
- A3: o principio do system design delimita estado corrente e a excecao dos
  relatorios externos datados. Guia MTA atualizado com runsPath, historico e
  tratamento da falha dupla.
- Cobertura estrutural estendida para Codex/Copilot, incluindo perfil leitor,
  sandbox e limites de delegacao conforme o cliente.
- Os dois links antigos da matriz indisponivel foram substituidos pela
  identificacao textual com lacuna explicita; nenhum conteudo foi inventado.

Provas RED/GREEN: os testes de publicacao e indice falharam antes das respectivas
correcoes. A verificacao adicional de limpeza na falha dupla tambem falhou antes
de introduzir a preservacao transitoria do preparo, e passou depois.

Treze suites distintas aprovadas pelo runner oficial isolado em PowerShell 5.1:
Test-MtaExternalPublication, Test-ProjectIndexExternalMta, Test-Mta,
Test-ProjectIndex, Test-ProjectIndexSummary, Test-ProjectMta,
Test-ProjectDocuments, Test-ProjectNavigation, Test-ProjectPublication,
Test-ProjectRecovery, Test-ProjectConcurrency, Test-ExternalMtaDiscovery e
Test-ClaudeAdapter. Durante a ampliacao, corrigida enumeracao de array do
ConvertFrom-Json em PS5.1 no teste do adaptador; uma tentativa capturou o teste
de publicacao entre gravacoes, e a execucao final do arquivo completo passou.

Uma mutacao da condicao de leitura historica, aplicada somente em copia
descartavel, foi detectada por Test-ProjectIndexExternalMta. A copia foi
restaurada byte a byte e removida. Revisao independente do runtime terminou
sem bloqueios, incluindo a sinalizacao transitoria da falha dupla.

Navegacao final: 608 referencias locais em 77 Markdown fora de tasks e 415
ancoras. Sem destinos ativos ausentes; os quatro destinos de exemplo/template
continuam intencionalmente relativos ao documento futuro. JSON de exemplo
valido, parser dos cinco PowerShell alterados e diff --check aprovados.

Os achados funcionais e documentais acima estao encerrados. Permanecem os
limites de ensaio nativo e consumo efetivo dos templates por agentes reais.
Nenhum dado real, analise MTA real ou codigo de aplicacao foi alterado.
