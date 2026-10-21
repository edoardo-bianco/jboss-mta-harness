# ADR-0009 — Estado corrente por projeto, sem recibos

Estado: implementação autorizada em 10/10/2026; produtores, consumidores e
instruções alinhados ao fluxo corrente na branch do harness. Regressão integrada
e aceite humano são acompanhados no [plano](../../tasks/historico/plan-ate-2026-10-17.md).
Esta ADR rege a operação desta versão; integração na principal e aceite da
[feature](../engineering-harness/02-system-design.md#estado-local) permanecem separados.

## Decisão

O desenvolvedor precisa localizar decisões, fontes e trabalho corrente pelo projeto.
Recibos, cadeias de execução e extratos duplicados dificultam essa tarefa. Adotamos
o `project.artifactId` literal do POM selecionado e os destinos fixos da feature.
O módulo [HarnessProject](../../scripts/HarnessProject.psm1) centraliza identidade,
links, leitura direta e publicação. O estado corrente não depende de IDs técnicos.

- MTA suportado neste incremento: relatório estático com `index.html` e `output.js`
  contendo a atribuição JSON `window["apps"]`, uma aplicação e seus `rulesets`.
  Não executar JavaScript. Usar `generatedAt` válido com fuso quando disponível;
  senão, mtime UTC de `index.html`. Desempatar por caminho ordinal. Regravação
  detectada interrompe a operação. Outros formatos exigem suporte e testes próprios.
- Chaves funcionais como `ruleset::regra` usam codificação percentual UTF-8 reversível
  para pastas. Maiúsculas são codificadas para impedir colisões no Windows. Não
  truncar nem substituir por hash. Categoria e escopo funcional separam cobertura;
  fichas pertencem ao projeto e à categoria, sem repetir a mesma ficha por escopo.
- Cada escopo de priorização conserva somente total inicial, issues examinadas e
  proposta corrente. A chave de uma issue é o projeto associado ao POM mais seu ID
  funcional. Mencionar uma issue não a marca examinada. Recriar é escolha explícita.
- Plano e tarefas são correntes, um lote por projeto. Mudanças de escopo/solução
  exigem revisão do GO. Preparar contexto, importar por cópia, testar e encontrar
  arquivos não concedem autorização. GO e aceite são declarações humanas legíveis.
- `reconciliado` contém conclusão, diferenças e pendências da última comparação.
  Não contém cópia integral de diagnósticos, fichas ou planos. Sem comparação
  suficiente, a proposta é preliminar; ausência no MTA atual não prova resolução.
- Sprints multiprojeto têm um único mestre em um participante Maven real. Índices
  dos demais participantes são derivados e reconstruíveis. Preservar baseline,
  capacidade e consumo de fases no cenário corrente, sem cadeia de revisões.
- Escrita usa exclusão por projeto e recuperação transitória. Antes de liberar
  leitores, concluir ou desfazer todo o conjunto. Cada arquivo é substituído
  atomicamente; o conjunto usa instrução transitória de recuperação. Não há
  transação distribuída com editores externos: conflitos preservam contribuições
  e exigem conciliação. O mutex não é registro de identidade nem fica em disco.

## Consequências e transição

### Saida MTA externa (ajuste solicitado em 20/10/2026)

Novas analises usam obrigatoriamente `mta.runsPath`, fora do harness e das fontes.
Sem raiz configurada, orientar a configuracao antes de iniciar. A organizacao e
`<raiz>/<nome-da-pasta-Source>/<data-com-milissegundos>/`, preservando relatorios
anteriores. A saida transitoria tambem fica na raiz externa, separada da pasta
da aplicacao; publicar somente o conjunto validado, sem sobrescrever rodada.

O indice associa automaticamente a pasta Source quando `mta.diretorio` ainda e
null e existe um conjunto valido. Preserva origens explicitas e acusa nomes de
pasta ambiguos. A execucao tambem associa a origem, exigindo coerencia com a
raiz configurada. O leitor existente seleciona o ultimo diagnostico valido nessa
origem, sem copiar relatorios nem ampliar acesso a toda a raiz global.
Diagnostico interno antigo permanece legivel por compatibilidade; nao e destino
de novas analises. Navegacao/documentos/logs seguem na .harness por artifactId.

### Priorizacao corrente (S10/S11a)

O escopo padrao de novos conjuntos e `priorizacao`. Os artifactIds ficam no
contexto, ordenados ordinalmente; o primeiro participante Maven guarda o conjunto.
`Scope` permite outro nome funcional curto. O mesmo nome nao pode ser reassociado
silenciosamente a participantes diferentes no mesmo mestre; outro conjunto de
participantes exige outro `Scope` quando o destino ja estiver ocupado.
Conjuntos anteriores cujo escopo juntava os artifactIds com `|` sao reencontrados
ao omitir `Scope`, preservando caminhos, notas e cobertura. Se o conjunto anterior
e `priorizacao` coexistirem, a escolha explicita de `Scope` resolve a ambiguidade.
Os caminhos sao `atual/priorizacao/<categoria>/escopos/<escopo>/contexto.json`,
`priorizacao.md`, `indice.md` e `priorizar-issues.prompt.md`. A ficha de cada
participante fica em `atual/priorizacao/<categoria>/issues/<issue>/ficha.md`.
Escopo/categoria/issue usam a codificacao reversivel acima. Nao ha pasta por execucao.

O contexto conserva as identidades da base inicial, as excluidas e as candidatas
da fatia pendente. O bloco `priorizacao:resultado:inicio/fim` do ranking conserva
TODAS as examinadas com Project, Id, Position (inteiro ou null) e Reason. Concluir
exige exatamente a quota de novas examinadas alem das excluidas, cada uma com ficha
valida. 20 anteriores mais 15 novas publicam 35, inclusive sem recomendacao. O
indice derivado aponta todas as fichas; existencia de arquivo nao comprova exame.
Retomada parcial preserva universo/quota; novas candidatas aguardam a proxima fatia.
Recriar zera cobertura explicitamente, preservando fichas e anotacoes externas aos
blocos. MTA novo conserva base inicial; novas issues ficam fora dela ate recriacao.

Fichas mantem resumo, roteiro e referencias diretas. `LocalPaths` e `EvidencePaths`
sao caminhos relativos conferidos, respectivamente a Source e evidencias do
projeto. O bloco de fontes e regenerado no preparo ou ao atualizar indices, sem
alterar o texto humano. Caminho ausente e issue nao reencontrada sao lacunas, nao
resolucao. Relocalizar exige associacao explicita do projeto ao POM atual.

### Planejamento corrente (S11b/S12/S12b)

O preparo parte das escolhas ANALISAR AGORA em migracao.md e publica somente
`atual/planejamento/contexto.json` e `planejar-lotes.prompt.md`. Plano e tarefas
ficam em `plano.md` e `tarefas.md` nessa mesma pasta; o preparo nao fabrica a
proposta. Retomar preserva o texto humano e atualiza blocos gerenciados de fontes
nos documentos existentes, nas fichas e no indice do projeto, em uma publicacao.

O contexto guarda escopo funcional e referencias diretas, com base MTA ou
EVIDENCIAS. Nao ha RequestId, Previous, snapshot, hashes de entradas nem copias
consolidadas. O produtor de `apontamentos-mta.json` e seu validador foram retirados.
As consultas opcionais tambem leem diretamente contexto/registro/MTA correntes,
sem `Consolidated.MtaIssuePath` ou outro extrato. S11b/S15 concluidas nesse recorte.

Mudancas conhecidas de escopo/base/referencias sinalizam NeedsReview/ReviewReasons,
preservando plano, tarefas e GO humano anterior. Esses avisos nao concedem nem
renovam GO. Arquivos podem mudar no mesmo caminho: o condutor deve reler fontes e
codigo, comparar com a proposta e pedir revisao humana quando mudar seu alcance.
Sem ultima reconciliacao disponivel, a proposta e preliminar. Origem MTA invalida
nao muda automaticamente a base; abrir plano/tarefas independe dessa origem.

Evidencias usam links em `evidencias/LEIA-ME.md`, nas observacoes do registro e
nas fichas. A tabela do indice tem Issue, Arquivo e Relacao; somente linhas das
issues escolhidas e linhas gerais (`*`) entram no contexto. Links fora da tabela
sao referencias gerais. Indice explicitamente escolhido permanece associado
mesmo ausente; a retomada conserva a lacuna. Nao copiar anexos ou texto integral
do MTA. Fichas ausentes permanecem a elaborar ate exame efetivo pelo condutor.

Implementacao usa plano/tarefas correntes e exige conferencia humana do alcance
do GO. Consultas usam exclusividade somente leitura e recusam recuperacao pendente;
hashes de paginacao sao transitorios, sem se tornarem requisitos de retomada.
Falhas de acesso nao selecionam silenciosamente outro relatorio. Sprints tambem
usam fontes correntes; nenhum desses consumidores procura solicitacao antiga.
Compartilhamento por pacote foi retirado em S22. O fluxo usa copia de documentos,
associacao ao POM local e reconciliacao, sem importador/exportador ZIP.

### Reconciliacao e navegacao correntes (S13)

`Planejamento: atualizar registro de migracao` prepara o contexto corrente sem
alterar decisoes nem concluir a comparacao. A revisao usa estado transitorio e
publica a ultima conclusao em `reconciliado/resultado.md`, com fontes e pendencias.
Diagnosticos Sonar, operacao corrente, documentos e fontes examinados recebem
protecao contra alteracoes concorrentes; esses controles nao viram recibos.

Copiar arquivos nao transfere GO. A conciliacao decide por arquivo, preserva a
origem externa e retira da pasta recebido somente itens explicitamente resolvidos.
Material equivalente nao duplica; conflito preserva contribuicoes. Associar o
POM local permite realinhar fontes/contextos, incluindo base EVIDENCIAS. Mudancas
de Source/POM e de referencia MTA exigem revisao da proposta e do alcance do GO,
mesmo quando os totais de issues permanecem iguais.

Fontes do plano, tarefas e indice preservam fichas, anexos e texto humano. Links
de navegacao preferem documentos legiveis existentes: relatorio HTML do MTA,
RESUMO.md do Sonar, console.log do build e orientacoes Markdown de planejamento
e priorizacao. A situacao da operacao aparece no indice e e publicada com seus
dados estruturados. JSON/output.js continuam servindo aos consumidores tecnicos.

Revisao final de S13 concluida em 12/10/2026; provas em
[fontes da reconciliacao](../../tests/Test-ReconciliationSources.ps1),
[portabilidade](../../tests/Test-PlanningPortable.ps1),
[reassociacao](../../tests/Test-PlanningReassociation.ps1) e
[navegacao](../../tests/Test-ProjectNavigation.ps1), alem das suites registradas no
[plano](../../tasks/historico/plan-ate-2026-10-17.md#retomada-de-12102026). Fixtures sinteticas nao substituem
ensaio humano integrado nem o aceite da simplificacao completa.

### Sprints correntes (S16)

Cenario funcional tem unico mestre Maven participante, com contexto, premissas,
plano e ultimo resultado no mesmo destino. Resultado conserva B0 fixada quando
conhecida, inclusoes acumuladas e Simulation com calendario/consumo de fases;
nao duplica todas as entradas nem exige revisoes, selo ou ponteiro. Relocalizacao
preserva Project/Id. Preparo/falha nao apagam o calculo anterior, apresentado
como ultimo calculo, sem validar edicoes posteriores por sua mera existencia.

Exclusividade transitoria comum protege descoberta e indices; publicacao do
projeto troca plano/resultado juntos. Textos lidos e hashes de concorrencia
ficam somente em memoria. Indices participantes podem reconstruir seus links
sem recalcular o mestre. Provas em Test-SprintWorkflow, Test-SprintLifecycle e
Test-SprintConcurrency; contrato em planejamento-sprints.md.

S19 concluida em 13/10/2026: prompts correntes com fontes diretas por projeto,
indice geral, contrato/ADR/guia e lacunas explicitas. Preservam cabecalhos atuais,
notas e destinos; optional pode entrar por decisao humana depois de B0 fixada,
com inclusoes separadas. Test-SprintPrompts e Test-SprintWorkflow conferem links
e repeticao de preparo/revisao/validacao sem snapshots ou revisoes extras.
Revisao de resultado permanece somente leitura. Ensaio humano integrado e aceite
da simplificacao continuam em S28.

### Navegacao, compartilhamento e instrucao (S22-S27)

O modelo inicial e o gerador de workspace mostram .harness no Explorer,
preservando configuracao Java e demais escolhas locais. A entrada e
.harness/indices/projetos.md, seguida do indice.md do projeto.
Links existentes abrem evidencias/LEIA-ME.md, plano/tarefas, fichas, relatorios e
logs. Ultima tentativa e ultimo diagnostico utilizavel permanecem distintos.
Atualizar o indice reconstroi a navegacao apos novas saidas ou arquivos copiados.

Importador/exportador ZIP e sua tarefa foram retirados; contribuicoes seguem
copia e reconciliacao por arquivo, inclusive priorizacao cumulativa multiprojeto.
Limpeza corrente atua em residuos temporarios/backups selecionados. O utilitario
de conversao/descarte legado foi retirado por escolha do desenvolvedor em
20/10/2026; inicio novo parte dos relatorios MTA externos e dos indices correntes.

Guias, contratos, skill e perfis Codex/Copilot usam documentos correntes.
Referencias manuais por projeto/objetivo/evidencias sao aceitas; prompts gerados
podem ser regravados. doc/ e base local por busca/leitura, sem RAG semantico.
Os helpers permanecem leitores; proposta, GO e aceite continuam separados.

A tarefa Sonar tambem baixa a ultima analise concluida do servidor para o
projeto/branch, inclusive da pipeline. Nao executa scanner nem confere igualdade
com o Source local. Origem/data reais e limites acompanham o diagnostico;
coleta incompleta preserva o anterior. Detalhes no [guia Sonar](../guias/tools/sonar.md).

### Demais consumidores

Detalhes antigos deixam de estar disponíveis quando a origem antiga é removida.
As fichas conservam o essencial e links ao MTA atual e ao código local. Toda
referência de detalhe deve ser navegável; fonte ausente é uma lacuna explícita.

Esta decisão substitui no fluxo corrente as exigências de
recibos/cadeias das [ADR-0004](0004-git-informativo-sem-controle-de-branches.md),
[ADR-0005](0005-planejamento-orientado-pelo-registro.md) e
[ADR-0006](0006-categorias-e-dossie-por-issue.md), e o empacotamento da
[ADR-0007](0007-compartilhamento-de-contextos.md). Mantém Git informativo,
planejamento pelo registro, categorias, exame de evidências e decisões humanas.
A separação da [ADR-0002](0002-separacao-harness-e-migracao-progressiva.md) permanece.

A conversão foi entregue como utilitário descartável separado e retirada em
20/10/2026. O runtime não depende dela nem procura legado. Esta retirada não
apaga originais reais nem transfere decisões antigas para o estado novo;
relatórios externos são reutilizados pela associação do projeto.
Modernização e novas capacidades continuam posteriores a esta entrega.

## Verificação inicial

[Identidade](../../tests/Test-ProjectStorage.ps1),
[publicação](../../tests/Test-ProjectPublication.ps1),
[interrupção e recuperação](../../tests/Test-ProjectRecovery.ps1) e
[MTA direto](../../tests/Test-ProjectMta.ps1) exercitam o núcleo em PowerShell 5.1.
Essas provas não equivalem à conclusão dos fluxos listados no
[checklist](../../tasks/historico/todo-ate-2026-10-17.md#simplificacao-prioritaria-por-projeto---2026-10-10).
