# Plano do agente: evolucao do harness

Registros datados preservam decisoes e ensaios da epoca. Regras substituidas nao
voltam a ser exigencias: o guia e os contratos atuais orientam o uso. Pendencias
tecnicas reais permanecem nos checklists correspondentes.

## Revisao dos fluxos do guia e README - 2026-10-01

Evolucao documental na branch harness/revisao-fluxos-guia, de main 3feee18.
Conferir roteiro contra tarefas/menus e contratos: configuracao, build/MTA local
ou recebido, registro opcional, planejamento/revisao, implementacao, Sonar e limpeza.
Concentrar alternativas numa tabela de caminhos do guia; README permanece enxuto.
Corrigir descricao da pasta de evidencias, manutencao sem MTA, historico somente
com documentos gerados e alcance da limpeza externa. Sem novos documentos,
mudancas de comportamento, fontes de aplicacao ou reescrita de dados locais.
Validar links locais/ancoras, JSON da tarefa e diff; ensaio Copilot continua separado.

## Delegacao na manutencao do registro - 2026-10-01

Evolucao do harness em harness/delegacao-registro-migracao, de main ad4923b.
Pedido: permitir que o DevSquad escolha o melhor subagente disponivel para ajudar
na reconciliacao, sem fixar um especialista nem tornar a delegacao obrigatoria.
Plugin local conferido: condutor possui agent e catalogo de especialistas; suas
rotinas padrao excedem a manutencao e precisam receber os limites desta operacao.
Subagente le/busca entradas autorizadas e devolve proposta por ID; nao escreve,
subdelega ou executa ferramentas externas. Condutor confere e grava somente
MigrationPath; conflitos humanos permanecem explicitos. Sem lotes, fontes ou GO.
Alinhar prompt, contrato, ADR existente e guia; preservar solicitacoes anteriores.
Validar geracao com Test-MigrationRegister e Test-Planning; ensaio de obediencia
do Copilot permanece separado dos testes de scripts.

## Abertura automatica do editor - 2026-10-01

Evolucao do harness na branch harness/abertura-editor-prompt, de main 9dae3cc.
Relato: contexto salvo, mas Code.exe --reuse-window apresentou Database IO error
e o prompt nao abriu. A CLI instalada bin/code.cmd executa cli.js e encaminha a
abertura; teste real com o prompt existente retornou 0 e o desenvolvedor confirmou
que abriu na janela existente. A funcao corrigida tambem retornou 0 no PS 5.1.
Reproduzir tambem o codigo de erro ignorado pelo preparador. Centralizar abertura
na CLI da mesma instalacao, preservando editores explicitos e os arquivos salvos.
Conferir codigo de saida e testar caminhos com espacos, multiplos documentos,
editor/CLI ausente e falha. Sem limpar cache, fechar VS Code ou alterar perfis.
Nao declarar resolvida a causa interna do armazenamento apenas pelo retorno da CLI.

## Clareza do fluxo de planejamento - 2026-10-01

Evolucao do harness na branch harness/clareza-fluxo-planejamento, derivada de main
ccadc22. Preencher objetivo editavel com as issues ANALISAR AGORA. Explicar no menu,
na saida da tarefa, no README e no guia que a opcao 1 e o fluxo usual e tambem atualiza o
catalogo; a opcao 2 atualiza somente o registro, com prompt de reconciliacao opcional.
Manter selecao explicita, lote consistente, destinos de escrita e GO/aceite separados.
Validar com os testes existentes de planejamento e tarefas e revisao do diff.
Nao reescrever prompts/recibos historicos. Correcao da abertura do editor segue pendente.

## Proposta: registro por projeto e planejamento dirigido por issues - 2026-10-01

Estado: implementacao concluida e validada nos scripts; ensaio Copilot pendente.
Branch harness/analise-prompts-por-issue, a partir de main a3c9ac7.
Publicacao solicitada em 2026-10-01. Commit funcional e2a9cf4; preservar registros,
evidencias, configuracao local e rodadas externas durante a organizacao Git.
Ensaio manual localizou migracao.md, prompt e recibo gravados, mas a abertura via
Code.exe --reuse-window exibiu service_worker_storage / Database IO error.
A causa do editor ainda nao foi confirmada; testar a CLI bin/code.cmd e tratar
falhas de abertura sem perder o contexto sao pendencias separadas da geracao.
A analise abaixo preserva a proposta de origem; o contrato atual esta em
doc/especificacoes/planejamento-copilot.md, sem novos documentos de orientacao.
Skills utilizadas: using-agent-skills, spec-driven-development e documentation-and-adrs. O agente Copilot
customizado continua pendente; primeiro simplificar o fluxo e os prompts.

### Objetivo e diagnostico

O desenvolvedor escolhe issues a tratar, adiar ou excluir do escopo da migracao,
mantem andamento e observacoes em um documento local por projeto e o fornece ao
planejador. O mesmo prompt atende proposta inicial e atualizacao de plano anterior.
Evidencias complementares podem existir desde o inicio, sem obrigar uma revisao.

Base visual local: .harness/evidencias/mta_simtr-api-corporativo.jpeg. O print
mostra 15 entradas de issues, Hardcoded IP Address com 18 e hibernate4-00039 com
138 ocorrencias; nao mostra todas as entradas. O total 193 foi informado pelo
desenvolvedor, nao conferido no YAML corporativo. Nao gerar catalogo completo
nem corretivas SIMTR a partir desta imagem. Exemplo YAML local examinado apenas
para estrutura: violations, identificador da regra, description, category e incidents.

Diagnostico do fluxo atual: planejar-lotes tem 614 linhas; revisar-lote tem 180 e
exige ler o primeiro. EvidenceIndexPath so e aceito em revisar-lote, que exige
Previous. O modelo de evidencias exige lote existente e repete passos de revisao.
O contexto util aparece ao final; delegacao, estados, POMs e conferencias repetem
regras. Simplificar exige ajustar preparador, contratos e testes, nao so encurtar texto.

### Registro local por projeto

Nome proposto: .harness/projetos/<nome>__<chave>/migracao.md, acompanhado de
evidencias/LEIA-ME.md. Reusar a convencao de identidade do projeto; homonimos nao
compartilham pasta. Considerar a raiz Maven selecionada, incluindo o reactor;
nao criar um registro por modulo implicitamente. Se um repositorio tiver raizes
independentes, explicitar a unidade selecionada. Nomes ainda sujeitos a revisao.

Ao importar/preparar o projeto, garantir a pasta e o documento sem sobrescrever
conteudo. Antes de selecionar MTA, estado AGUARDANDO MTA, sem inventar issues.
Preencher o catalogo com a rodada explicitamente escolhida, local ou recebida.
Hoje nao existe observador de inclusoes manuais pelo VS Code: cobrir a geracao
do workspace e a descoberta do projeto na proxima tarefa, sem criar extensao.
Reexecucao deve ser idempotente. Remover projeto do workspace nao apaga seu registro.

### Quando criar e como atualizar migracao.md

Separar catalogacao mecanica de interpretacao das evidencias. Nao depender de
LLM para contar ocorrencias ou inventariar regras que ja existem no output.yaml.
Nao tornar manutencao do registro uma etapa obrigatoria repetida a cada plano.

| Momento | Acao proposta | Resultado |
| --- | --- | --- |
| Projeto importado/preparado | Harness garante pasta, legenda e estrutura, somente se ausentes | migracao.md em AGUARDANDO MTA; sem agente e sem rodada presumida |
| Primeiro MTA selecionado, inclusive recebido | Harness extrai catalogo e registra origem/RunId; usuario pode revisar diretamente | Issues reais, contagens e categoria; decisoes A DEFINIR e andamento NAO ANALISADA |
| Registro existente + novo MTA escolhido | Harness calcula novas/persistentes/nao reencontradas e atualiza dados objetivos preservando campos humanos | Catalogo reconciliado; desaparecimento nao significa correcao |
| Novas evidencias ou observacoes, com ou sem novo MTA | Humano edita ou aciona um unico prompt de manutencao do registro | Atualiza somente conclusoes/andamento sustentados e observacoes pertinentes |
| Planejamento solicitado | Prompt de planejamento le o registro, as escolhas e o plano anterior opcional | Um lote; manutencao do registro nao precisa ser executada novamente |

Proposta de prompt: manter-migracao, com a mesma entrada para criar/completar ou
atualizar. Nao criar prompts separados gerar-migracao, revisar-migracao e
reconciliar-migracao. A criacao da estrutura/catalogo cabe ao harness; o prompt
completa a analise quando solicitado. Se o arquivo ja existir, atualizar por
ID da issue e preservar texto humano; nunca gerar novamente por cima dele.
Se faltar, usar estrutura/catalogo preparados como base, sem inferir status.

Entradas: projeto/destino explicitos, migracao.md existente quando houver,
catalogo/rodada MTA selecionada, LEIA-ME de evidencias opcional e direcionamento
do desenvolvedor. Atualizacao apenas por evidencias reutiliza a referencia MTA
existente, sem exigir novo scan. Primeiro preenchimento de issues MTA requer
os dados da rodada; apenas um print permite registrar observacao parcial.
Aceitar documento trazido de colega como base explicitamente escolhida, conferindo
projeto e IDs; caminho da origem nao precisa existir. Nao substituir automaticamente
um registro local diferente: apresentar conflitos para conciliacao manual.

```text
## Direcionamento do desenvolvedor
Objetivo e observacoes desta atualizacao:

## Entradas e destino
Projeto e registro: <caminho literal de migracao.md>
Documento-base: <o proprio registro ou arquivo existente escolhido>
MTA/catalogo: <referencia selecionada; manter a existente se nao mudou>
Evidencias: <LEIA-ME opcional>
Decisoes vigentes: <referencias explicitas>

Crie ou atualize o registro com os dados fornecidos, preservando decisoes humanas.
Relacione cada mudanca de andamento a evidencia; explicite duvidas e conflitos.
Nao planeje lotes, execute corretivas ou conceda GO/aceite. Grave apenas no destino.
Informe resumidamente o que mudou, o que foi preservado e o que ficou pendente.
```

O prompt de manutencao pode escrever somente migracao.md selecionado; o documento
recebido, MTA, evidencias e planos anteriores permanecem entradas preservadas.
Nao criar um ciclo manutencao -> planejamento -> manutencao para a mesma analise.
Planejador/executor podem registrar o andamento decorrente de seu proprio trabalho
nas linhas autorizadas, sem chamar novamente o mantenedor; isso exige a ampliacao
delimitada de seus contratos descrita abaixo. Preparacao nunca envia prompt sozinha.
Reutilizar o menu de preparacao existente para escolher manter registro ou planejar;
nomes de operacao/tarefa ficam para implementacao, sem uma tarefa por projeto.
Reconciliacao repetida das mesmas entradas nao duplica linhas/notas nem rebaixa
status. Nova evidencia conflitante preserva o registro anterior como referencia,
explicita a divergencia e nao escolhe silenciosamente uma versao dos fatos.

Uma linha por issue/regra, agrupavel por categoria; nao uma linha por ocorrencia
nem uma unica linha para toda a categoria mandatory. Catalogar todas as issues
e diferente de analisar todos os fontes ou planejar todos os lotes.
Extrair mecanicamente do MTA selecionado, sem interpretar YAML por regex fragil.
Identificar por ruleset + ruleID dentro da rodada; titulo/numero da linha nao e chave.
Preservar categoria, quantidade bruta e RunId. Separar contagem MTA, cobertura
analisada e pontos de alteracao deduplicados. Categorias/labels nao provam sozinhas
aplicabilidade ao destino; conferir a regra, o uso local e as decisoes da migracao.

Conteudo minimo do documento: objetivo e legenda curta; projeto e rodada de
referencia; tabela de issues; decisoes/observacoes do desenvolvedor; referencias
as decisoes tecnicas vigentes, evidencias e planos. Evitar outro cadastro/board.
Tabela proposta: ID | Issue | Categoria MTA | Ocorrencias | Decisao | Andamento |
Observacao/referencia. Campo de decisao e andamento independentes:

- Decisao: A DEFINIR, ANALISAR AGORA, ADIAR ou FORA DO ESCOPO.
- Andamento: NAO ANALISADA, ANALISADA, PLANEJADA, IMPLEMENTADA ou VERIFICADA.
- Cobertura parcial aparece explicitamente com recorte/quantidade conhecida;
  analisar 20/138 nao marca a issue inteira analisada nem as demais resolvidas.
- ADIAR preserva a pendencia. FORA DO ESCOPO exige justificativa humana; nao
  equivale a falso positivo, correcao ou conclusao de toda a migracao.
- Implementada por colega e ainda nao integrada: registrar declaracao, referencia
  e AGUARDANDO INTEGRACAO na observacao; nao marcar implementada no Source local.
- IMPLEMENTADA exige evidencia da alteracao; VERIFICADA exige verificacoes reais
  para a cobertura declarada. Nenhum desses estados concede aceite humano.
- Issues adicionais do desenvolvedor usam ID local DEV-..., origem e justificativa;
  nao inventar ruleID ou contagem MTA. Preserva-las nas proximas reconciliacoes.

Edicao manual e via agente devem preservar decisoes humanas. Atualizacoes do agente
se limitam as linhas do trabalho autorizado, com referencia ao plano/evidencia;
nao excluir issue, decidir fora de escopo ou inventar GO/aceite pelo desenvolvedor.
Entre colegas, conciliacao manual por IDs e referencias. Sem locks, responsaveis
cadastrados, coordenacao Git ou sincronizacao automatica. Divergencia fica explicita,
sem assumir que o arquivo mais recente prevalece. Caminhos de outra maquina sao
referencias historicas, nao requisito para reconhecer o projeto/issue.

Nova rodada: atualizar catalogo/contagens, preservar decisoes e vinculos, adicionar
issues novas e sinalizar nao reencontradas sem declarar resolucao. Mudanca da regra,
perfil ou abrangencia exige conferir comparabilidade. Registro e mutavel; MTA,
recibos e documentos anteriores continuam historicos. Nao copiar rodadas para
a pasta do projeto nem regravar manifestos. Vincular cada plano ao RunId e ao
recorte/decisoes usados naquela solicitacao, sem criar um segundo board.

### Prompt curto e unico para planejamento

Manter uma entrada para analisar/planejar: recebe registro, MTA selecionado,
plano anterior opcional e indice de evidencias opcional. Retomada usa o plano
atual ou Previous explicito e altera apenas pontos afetados; nao repete triagem.
Novo lote so apos aceite do atual e pedido de continuidade. Selecionar varias
issues nao autoriza detalhar varios lotes: verificar causa/solucao/aceite comuns,
propor um recorte se forem independentes e registrar restante fora deste lote.
Dependencia em issue adiada/excluida e apresentada como decisao necessaria;
nao incluir silenciosamente nem esconder a dependencia. Sem selecao, usar um
objetivo inequivoco do pedido ou apresentar recomendacao curta para escolha.

Formato proposto do corpo, depois do frontmatter:

```text
## Direcionamento do desenvolvedor
Objetivo desta rodada:
Observacoes ou mudancas em relacao ao registro/plano:

## Entradas e destinos (preenchidos pelo harness)
Registro de migracao: <caminho>
Contexto MTA: <caminho do recibo com rodada e origem>
Plano anterior: <referencia opcional>
Evidencias: <LEIA-ME opcional>
Decisoes vigentes: <referencias explicitas e pertinentes>
Saidas: <PlanPath e TodoPath>

## Trabalho solicitado
Leia o direcionamento, o registro e as decisoes referenciadas.
Analise somente as issues selecionadas e os pontos pertinentes do codigo local.
Crie ou atualize um lote coerente, preservando o plano anterior e as decisoes.
Registre proposta, tarefas, evidencias e pendencias nos destinos indicados.
Encerre com o que mudou e o que depende do desenvolvedor, sem executar corretivas.
```

Registro concentra escolhas persistentes; secao livre do prompt concentra o pedido
da rodada. Nao repetir a tabela de issues no prompt. Mudanca explicita solicitada
pelo humano deve aparecer no resultado/registro; conflito ambiguo exige pergunta
pontual. Comentario livre nao revoga implicitamente uma ADR nem concede GO.
Referencias devem ser exatas e legiveis, nao "siga todas as ADRs". As ADRs 0001/0002
tratam do fluxo e a 0004 substitui controles Git da 0003. Elas nao concentram todas
as premissas tecnicas atualmente embutidas nos prompts: antes de reduzir, consolidar
as decisoes vigentes de Java 8/javax/EAP 7.4 e Hibernate quando pertinente em fonte
curta e unica. Nao obrigar o agente a percorrer historico superado para descobrir
o contrato atual; conferir conflitos ja existentes sobre nova rodada MTA e gates.
Mover repeticoes para varios arquivos sem reduzir leitura nao atende ao objetivo.

### Revisao das quatro ADRs existentes - 2026-10-01

Revisao documental de todas as ADRs do repositorio, sem aprovar implicitamente
a arquitetura proposta nem declarar o registro/prompts novos implementados.

| ADR | Manter | Ajuste ou ponto a decidir |
| --- | --- | --- |
| 0001 - contexto local | Acionamento explicito, MTA fixado, recibo e historico por solicitacao | Distinguir registro mutavel por projeto de plano por solicitacao; novo contrato deve permitir destino literal do registro na manutencao |
| 0002 - separacao e ciclo | Harness separado da aplicacao, lote coerente, GO e aceite distintos | Corrigir referencias Git ja superadas; catalogo global nao e planejamento global. Resolver texto que exige novo MTA antes de avancar versus checklist nao bloqueante |
| 0003 - controles Git antigos | Justificativas historicas e limites de evidencias | Identificar status historico/superado no inicio; nao carregar como instrucao atual nem renovar cadastro/papeis/gates |
| 0004 - Git informativo e MTA portavel | Sem gates Git, origem MTA separada do projeto local, escolha local explicita de branch | Aplicar ao registro recebido e a conciliacao manual; nao transformar migracao.md em lock ou controle de equipe |

Os ajustes sobre Git abaixo das notas historicas da ADR-0002 sao alinhamento ao
que a ADR-0004 ja decidiu; nao restauram nem criam politica nova. As demais
alteracoes foram consolidadas como refinamentos nas ADRs existentes, preservando
seu historico, conforme pedido de nao criar novos documentos. O prompt aponta ao contrato.
As ADRs atuais nao sao catalogo suficiente das decisoes tecnicas da migracao:
consolidar perfil EAP 7.1 -> EAP 7.4/Java 8/javax e premissas Hibernate pertinentes,
sem transformar versao exata do servidor desconhecida em fato confirmado.

Ponto normativo em aberto: o guia e os prompts atuais tratam reexecucao MTA/Sonar
como checklist nao bloqueante, mas a ADR-0002 ainda exige novo MTA no passo 6.
Recomendacao para consolidacao: atualizar planejamento/registro com evidencias
disponiveis e registrar comparacao MTA pendente; nunca afirmar desaparecimento de
achados ou conclusao global sem evidencia. Isso nao elimina aceite do lote nem
autoriza proximo lote automaticamente. Registrar decisao antes de mudar esse gate.

### Preservacao das decisoes tecnicas dos prompts

Reforco explicito do desenvolvedor: simplificar o texto nao autoriza remover ou
reabrir decisoes ja tomadas. Antes de substituir os prompts, conferir uma matriz
de origem -> decisao preservada -> referencia vigente de destino; nenhuma regra
pode desaparecer por resumo. Manter os templates atuais ate a consolidacao.

Preservar integralmente, inclusive as ressalvas que distinguem premissa de evidencia:

- Java 8, APIs javax.*, arquitetura Java EE, empacotamento, contratos e comportamento.
- Destino do codigo corrigido somente EAP 7.4; EAP 7.1 e referencia historica.
  Nao exigir retrocompatibilidade nem o mesmo WAR nos dois servidores.
- Nao converter imports javax.* para jakarta.* nem ampliar o alvo para EAP 8 ou
  Jakarta EE 9+. Precisao terminologica: Jakarta EE 8 ainda usa javax.*; a troca
  de namespace ocorre em Jakarta EE 9. A intencao e preservar javax, nao rejeitar
  a denominacao Jakarta EE 8 compativel com o destino ja escolhido.
- Hibernate ORM 5.3 e premissa do perfil EAP 7.4; nao reabrir 5.1 versus 5.3.
  Isso nao prova uso de Hibernate pela aplicacao, modulo carregado ou patch exato
  instalado. Conferir uso, dependencias, empacotamento e configuracao pertinentes.
- Para lote Hibernate, alinhar POMs de compilacao e teste ao destino e entrega
  explicita do lote. Localizar propriedade/parent/BOM, core, integracoes como
  hibernate-ehcache, transitivas e perfis; nao reduzir a tarefa a "se necessario".
- Manter versao exata pendente ate evidencia do modulo/patch do servidor; nao
  copiar versao de exemplo. Preservar provided para Hibernate do servidor e test
  para provedores exclusivos dos testes; nao embutir Hibernate no WAR como atalho
  nem adicionar Hibernate onde nao e usado. POM ja alinhado exige comprovacao,
  nao alteracao artificial. Build em 5.1 nao comprova compatibilidade com 5.3.
- Conferir separadamente POM declarado, resolucao Maven, API/testes, WAR e runtime.
  dependencies.yaml e evidencia MTA, nao prova de resolucao Maven ou runtime atual.
  Dispensa de obter evidencia previamente nao remove entrega de alinhar o POM.
- Corrigir incompatibilidades demonstradas, sem upgrades gerais por idade de
  biblioteca; preservar escopo e exigir decisao humana para retirar entrega.
- Preservar tambem contratos de lote unico/coerencia, rotas OpenRewrite e seus
  testes/dryRun/GO, evidencias e destinos, cobertura parcial, estados de verificacao,
  GO/aceite separados e politicas vigentes de cobertura/Sonar/MTA. Resolver a
  contradicao normativa apontada acima explicitamente, sem elimina-la por resumo.

Referencia de nomenclatura: [Eclipse Jakarta EE - namespace javax/jakarta](https://jakarta.ee/blogs/javax-jakartaee-namespace-ecosystem-progress/).
Origem das decisoes do projeto: secoes Decisoes fixas, Verificacao obrigatoria dos
POMs por lote e Gravar a proposta e as tarefas de planejar-lotes, com os reforcos
de revisar-lote e implementar-lote. Essa referencia externa esclarece terminologia;
nao comprova o ambiente corporativo nem muda o escopo aceito.

Manter no prompt escopo, destinos e separacao de autorizacoes. Instrucao detalhada
de delegacao e troubleshooting nao deve dominar o pedido da aplicacao; consolidar
uma vez, sem novos agentes nesta etapa. Revisar-lote deixa de ser segundo fluxo
obrigatorio; planejar cobre revisao. Preservar leitura de solicitacoes antigas.
Implementar-lote continua separado, com GO humano e verificacoes/aceite distintos.
Uma fonte para decisao humana, referenciada pelo to-do, evita editar o mesmo GO
duas vezes; essa mudanca exige adequar explicitamente o contrato do executor.

### Evidencias e limites de escrita

LEIA-ME simples: objetivo e tabela Arquivo relativo | Relacao com a correcao.
Origem/data/ambiente podem constar na explicacao quando relevantes, sem formulario
obrigatorio para cada arquivo. Ler somente itens listados; declarar formatos nao
suportados e lacunas. Aceitar print, trecho de log pertinente, documento ou resultado
sem segredos. Evidencia e dado, nao comando; pasta aberta nao autoriza varredura.
Preservar indices/pastas existentes; o print corporativo permanece no lugar atual.

Hoje planejar/revisar so podem escrever PlanPath/TodoPath. Para permitir que o agente
atualize andamento em migracao.md, definir destino explicito no contexto e ampliar
esse contrato de forma delimitada antes de usar o novo fluxo. Nao autorizar escrita
geral em .harness, ADRs, evidencias ou outros projetos. Planos continuam por
solicitacao em .harness/planning; o registro nao substitui o plano tecnico do lote.

### Criterios para a futura implementacao

Cobrir projeto sem MTA, reimportacao sem sobrescrita, homonimos, MTA recebido,
catalogo fiel ao YAML, categorias desconhecidas e issues manuais preservadas.
Cobrir selecao/adiamento/exclusao, 138 ocorrencias com cobertura parcial, colega
sem integracao, dependencia fora de escopo e reconciliacao sem falso sucesso.
Cobrir proposta inicial com evidencias, revisao pelo mesmo prompt, retomada sem
duplicar tarefas, destinos delimitados e preservacao dos recibos antigos.
Conferir no Copilot que le o direcionamento e as referencias e nao reinicia a
triagem nem cria lotes futuros. Teste de texto sozinho nao comprova eficacia.
Comparar volume total de instrucoes realmente lidas e repeticoes com a base atual.

Arquivos afetados no futuro: templates de planejamento/revisao/implementacao,
HarnessPlanning.psm1, preparador, geracao do workspace e modelo de evidencias;
contratos/ADRs/guia e testes correspondentes. Manter PowerShell 5.1 e padroes
existentes. Comandos de verificacao previstos: powershell.exe -NoProfile -File
tests/Test-Planning.ps1, tests/Test-PlanningPortable.ps1, tests/Test-Workspace.ps1,
tests/Test-EvidenceFolder.ps1 e tests/Test-Implementation.ps1 (cada arquivo em
invocacao separada), novos testes do registro e git diff --check.
Implementado: registro idempotente por raiz local, catalogo do JSON do relatorio
static-report/output.js (sem interpretar YAML por regex ou executar JS), preservacao
de decisoes/andamento e issues DEV, sinalizacao de nao reencontradas, manter-migracao
com documento-base/evidencias, planejamento/revisao unificados e historico preservado.
Evidencias ficam junto ao registro; menu e tarefas existentes reutilizados.
ContractSnapshot guarda texto puro do contrato usado no preparo.

| Origem das decisoes nos prompts anteriores | Destino no contrato existente |
| --- | --- |
| Decisoes fixas, POMs, reforcos Hibernate | Decisoes tecnicas vigentes: javax/Java 8/EAP 7.4, ORM 5.3, patch comprovado, alinhamento obrigatorio e escopos |
| Identidade, recibos, snapshot, Git e continuidade | Contexto, identidade e continuidade; ADR-0004 |
| Triagem, deduplicacao, complexidade, rotas e receitas | Planejamento de um lote |
| Delegacao delimitada, duas chamadas, persistencia e historico | Planejamento de um lote e prompt curto |
| Evidencias e cobertura parcial | Registro e evidencias |
| GO, dispensas, integridade, delegacao e limites de execucao | Execucao autorizada e GO |
| Sonar/MTA nao bloqueantes, cobertura 85%, aceite e conclusao global | Verificacoes e continuidade; ADR-0002 passo 6 harmonizado |

Mudancas deliberadas: selecao por issue, registro como saida delimitada, GO no
plano referenciado pelo to-do, revisao no mesmo prompt, evidencias desde o inicio
e manutencao opcional sem novo scan. Guia revisado e README enxugado, sem nova
ADR/guia/spec. Sem nova analise MTA ou corretiva SIMTR.

## Pendencia: agente Copilot para o workflow de migracao - 2026-10-01

Registrar como evolucao futura do harness. Antes de implementar o agente,
o desenvolvedor quer revisar a logica e o conteudo dos prompts planejar-lotes,
revisar-lote e implementar-lote. Essa revisao e a prioridade e deve orientar
o contrato do futuro agente. A analise foi iniciada na proposta acima; a alteracao
dos prompts e a implementacao do agente continuam pendentes.

Depois da revisao, definir o agente customizado do GitHub Copilot para o fluxo
de migracao, integrado aos contextos e tarefas existentes. Avaliar agente proprio
ou condutor com especialistas DevSquad e a separacao de ferramentas por etapa.
A sugestao de comecar pelo planejamento permanece candidata, nao decisao tomada.
Preservar lote unico, identidade/origem MTA (inclusive rodadas recebidas), destinos
PlanPath/TodoPath e separacao entre proposta, GO humano, implementacao autorizada,
verificacoes e aceite humano. Retomar a implementacao mediante pedido posterior.

## Relatorio MTA apos mover o harness - 2026-10-01

Evolucao em harness/relatorio-mta-portavel, derivada de main 310faf8.
Reproduzir perda da referencia externa ao mudar a raiz do harness. Validar a
identidade e a parte do indice sob .harness/runs sem exigir a raiz historica.
Permitir abrir rodada completa por caminho, inclusive recebida de colega, na
tarefa existente. Preservar manifestos, resultados e referencias historicas.
Cobrir formatos externos antigo/novo, erros de identidade, historico local e
abertura por pasta sem cadastro. Validar em Windows PowerShell 5.1.
Publicacao autorizada pelo desenvolvedor: registrar a correcao validada, integrar
por fast-forward em main e depois main_jboss_eap74, publicar ambas e conferir
os hashes remotos. Preservar a branch de lote e as evidencias historicas.

## Planejamento sem ciclo de regeneracao - 2026-09-30

Evolucao do harness em harness/planejamento-sem-loop, derivada de main 04d5937,
com worktree isolado. O ensaio Copilot da solicitacao 07ad43178a49 chamou o
planejador repetidamente, perdeu partes conferidas e terminou sem plan/to-do.
Fixar uma elaboracao e no maximo uma correcao consolidada por execucao; preservar
o rascunho e o ID do lote; permitir normalizacao editorial/factual pelo condutor,
sem alterar escolhas tecnicas ou autoria humana. Correcao retorna trechos, nao
regenera o par. Lacunas verificaveis viram pendencias, sem aceitar contradicoes.
Aplicar o mesmo contrato em planejar-lotes/revisar-lote e explicar no guia atual.
Validar preparo dos prompts, preservacao do historico e links. Comportamento do
Copilot exige novo ensaio real; testes dos scripts nao provam obediencia do agente.
Nao alterar solicitacoes historicas, evidencias, aplicacao ou plugin DevSquad.

## Consolidacao da documentacao - 2026-09-30

Evolucao do harness na branch harness/documentacao-consolidada, em worktree separado.
Centralizar o uso no guia do desenvolvedor, incluindo Sonar, revisao e formacao de
um unico lote a partir do MTA. Enxugar o README e retirar roteiros redundantes.
Preservar o diagnostico de branches separado, o modelo usado pela Run Task,
os contratos tecnicos, ADRs e historico de evidencias. Corrigir instrucoes antigas
sobre Git, pasta externa, MTA recebido e checklist nao bloqueante.
Validar referencias, ancoras, menus e coerencia com os prompts/scripts atuais.
Nao alterar aplicacoes, prompts preparados nem resultados de rodadas.
Publicacao autorizada pelo desenvolvedor: apos revisao documental, integrar por
fast-forward em main e main_jboss_eap74, publicar ambas e confirmar os hashes
remotos antes de remover branches auxiliares ja incorporadas. Preservar a branch
lote/HIB-CACHE-001, com corretiva exclusiva, e os artefatos locais dos worktrees.

## Planejamento a partir de MTA recebido - 2026-09-30

Evolucao em harness/planejamento-portavel, derivada de main 2ecc997 no worktree
.harness/i. Aceitar a pasta de uma rodada completa diretamente na tarefa existente,
sem cadastro/importacao, copia de evidencias ou dependencia da maquina de origem.
Preservar RunId e manifesto originais; criar nova solicitacao local de planejamento.
Validar coerencia dos arquivos da rodada, sem vinculo de branch/commit/checkout
de origem. Documentar a origem MTA nos documentos e separar os caminhos recebidos
dos caminhos historicos contidos nos recibos. Preservar GO e aceite separados.
Refinamento do desenvolvedor: projeto local tem o mesmo nome, nao a mesma raiz.
Usar snapshot como base e codigo local para conferir os pontos a alterar.
Comparar groupId:artifactId do POM raiz (incluindo parent), version separada;
divergencia/inconclusao e apenas alerta, sem bloquear proposta. Recomendar novo
MTA quando o trecho local tiver mudado, continuando a analise dos demais pontos.

## Nomes legiveis nas rodadas externas - 2026-09-30

Retomar harness/caminhos-longos em .harness/i, alinhada a main 9c789ab.
Manter mta.runsPath externo; novas rodadas em <nome-projeto>/yyMMdd-HHmmss/.
Usar sufixos numericos para homonimos e instantes repetidos, sem sobrescrever.
Preservar RunId interno e hashes, indices locais e leitura do layout externo
anterior. Identificar a origem em project.json e manifest.json; nao mover
evidencias antigas. Testar criacao, colisoes, historico, planejamento e limpeza.

## Caminhos longos no snapshot MTA - 2026-09-30

Evolucao isolada em harness/caminhos-longos, derivada de main 5c3b27a no worktree
.harness/i; preservar checkout do lote em uso pelo Copilot. Reproduzir em PS 5.1
a falha de copia de arquivos Java com caminho de destino acima de MAX_PATH.
Opcao escolhida pelo desenvolvedor: mta.runsPath = C:/mta-runs, pasta externa
com p__<chave12>/<RunId>/ para encurtar a entrada do MTA/Java. Null preserva o
padrao local. Manter referencias location.json no historico local, sem mover
rodadas anteriores; adaptar descoberta e limpeza para os dois formatos.
Cobrir enumeracao, copia e SHA-256 com caminhos estendidos, sem renomear os
arquivos da aplicacao nem alterar configuracao global do Windows. Manter
exclusoes, recusas de links/junctions e deteccao de alteracoes. Validar fixtures
com destino e fonte longos e reactor parent, depois documentar limite do ensaio.

## Checklist sem bloqueio e cobertura como aviso - 2026-09-30

Pedido do desenvolvedor: coleta Sonar e reexecucao MTA sao checklist informativo,
sem impedir implementar/entregar o lote ou exigir dispensa individual. Preservar
pendencias/evidencias, GO e aceite separados. Cobertura abaixo de 85% deve alertar,
sem reprovar build; falhas reais de compilacao/testes continuam falhas.
Atualizar prompts/guia/contrato e o launcher Maven com jacoco.haltOnFailure=false,
sem editar POM/testes do checkout da aplicacao em uso. Validar contrato do launcher
e comportamento JaCoCo real em fixture isolada, alem da propagacao dos prompts.

## POM alinhado ao Hibernate do EAP 7.4 - 2026-09-30

Evolucao dos prompts em harness/implementar-lote, derivada de main a549a15,
no worktree .harness/i. Nao editar POM, testes ou documentos do lote em andamento.
Tornar obrigatorio no plano/to-do de lote Hibernate o alinhamento do classpath
de compilacao/teste ao Hibernate ORM 5.3 fornecido pelo EAP 7.4 de destino.
Separar entrega de implementacao (alinhar POM) de precondicao (confirmar versao).
Sem evidencia, a versao exata fica pendente, mas a tarefa nao desaparece por
dispensa de precondicoes. Nao fixar a versao do servidor deste ensaio no template
global; seguir propriedade/parent/BOM e preservar escopos provided/test e caches.
Conferir plano/revisao/implementacao, guia e contrato; testar propagacao nos prompts.

## GO simples e dispensa explicita de precondicoes - 2026-09-30

Evolucao do harness em harness/implementar-lote, retomada de main b6ad314 no
worktree .harness/i. Checkout do lote esta em uso pelo Copilot: preservar branch,
fontes, documentos locais e prompts preparados; nao integrar nele nesta etapa.
Corrigir o contrato de implementacao para reconhecer decisao humana vigente,
inclusive GO curto que referencia o proprio plano/to-do e dispensa explicita de
todas ou de algumas precondicoes. Nao inferir dispensa de GO generico, checkbox,
exemplo ou mera ordem no arquivo. Resolver textos antigos expressamente superados
sem pedir novamente a mesma aprovacao; conflito real ou dispensa ambigua exige
esclarecimento. Preservar identidade/hashes, escopo, historico e aceite separado.
Planejamento/revisao passam a entregar bloco de decisao PENDENTE pronto para o
operador preencher, com responsavel, GO e pendencias dispensadas. Documentar
formas normal, geral e seletiva e manter verificacoes nao realizadas pendentes.
Validar propagacao/preservacao no gerador, revisar cenarios semanticos, executar
testes de implementacao e planejamento; ensaio do modelo permanece manual.

## Escolha explicita da branch na implementacao - 2026-09-30

Retomar harness/implementar-lote, alinhada a main 2f288e0, no worktree .harness/i.
Pedido: na tarefa existente, oferecer 1 criar/usar lote/<ID>, 2 usar a branch
atual, 3 criar/usar nome informado. Sem padrao: Enter/q cancela. Criar significa
branch local nova a partir do HEAD atual da aplicacao e seleciona-la; sem push,
reset, stash, force, cadastro de papeis ou nova politica Git.

Obter ID apenas de Lote ativo: <ID> ou ID do lote: <ID>, igual e unico no plano
e no to-do, fora de blocos de exemplo. Sem ID confiavel, oferecer somente 2/3.
Nome manual e literal, validado pelo Git; branch existente nao e sobrescrita
nem selecionada automaticamente. Revalidar documentos e estado observado antes
da mutacao. Falha do Git oferece novamente 2/3 na mesma execucao. A escolha atual
(2) nao exige Git disponivel nem HEAD/branch especificos.

Preparo valida evidencias e salva prompt antes da escolha; cancelar/falhar deixa
o prompt preservado, sem abrir o editor. GO continua sendo decisao separada.
Helper proprio da implementacao, sem alterar a coleta informativa HarnessGit.
Atualizar AGENTS/ADR/guia para a excecao explicitamente pedida pelo desenvolvedor.
Testar menus e Git real em fixtures: criacao automatica/manual, branch atual,
ID ausente/divergente, nomes invalidos/existentes, cancelamento e preservacao de
HEAD, indice e alteracoes locais. Regressao de implementacao, Git, planejamento
e tasks; sintaxe e diff. Nao criar branch de lote real durante os testes.

Validacao: cinco testes diretamente afetados passaram. Regressao: 17/18 scripts
passaram; Test-Mta falhou duas vezes por input/pom.xml da fixture em uso por outro
processo. Codigo MTA/teste inalterados; diagnostico segue pendente no to-do.
67 links/ancoras locais, sintaxe e diff conferidos. Criacao testada somente em
repositorios ficticios; ensaio Copilot real continua separado.

## Preparar implementacao do lote pelo DevSquad - 2026-09-30

Pedido: priorizar uma Run Task de implementacao antes do backlog de deploy/servidor.
Branch harness/implementar-lote, derivada de main e0671ea em worktree isolado.
Fluxo confirmado: selecionar plano/to-do existentes, abrir prompt e o operador
usar Executar Prompt no Copilot Local. Nao enviar mensagens automaticamente.

Criar Aplicacao: preparar implementacao do lote e prompt implementar-lote.
Reutilizar selecao por projeto/RequestId e validar identidade, destinos e hashes
MTA antes de preparar. Gravar somente um novo prompt na solicitacao selecionada,
com caminhos literais, data e hashes do contexto/plano/to-do; preservar os anteriores.
Preparacao nao interpreta Markdown como autorizacao nem concede GO. O agente
confere a versao dos documentos, precondicoes e GO humano explicito antes de editar.

Delegar ao devsquad.implement instalado, passando contrato completo e adaptando
defaults de tasks.md, board, memoria e Git ao harness. Permitir workers delimitados
de validacao, execucao, verificacao e revisao; nao finalizar com PR/commit/push.
Escrita somente no Source para o escopo aprovado e nos PlanPath/TodoPath atuais.
Preservar historico, pendencias, evidencias e trabalho local. Verificacoes reais
nao concedem aceite nem iniciam outro lote. Ferramentas do plugin nao sao sandbox.

Incrementos: contrato/teste de preparo; geracao e entrada/task; guia e regressao.
PowerShell 5.1 e convencoes existentes, sem dependencias ou mudanca de ExecutionPolicy.
Verificar Test-Implementation.ps1, Test-Planning.ps1, Test-TaskInputs.ps1 e limpeza;
conferir links, sintaxe e diff. Ensaio de delegacao/edicao no Copilot fica explicito
como pendente do operador; nao executar corretiva real nesta entrega do harness.

Validacao concluida: 17 scripts Test-*.ps1 passaram em PowerShell 5.1; teste novo
com formatos antigo/atual, hashes, recusas, repeticao, menus, cancelamento e editor
simulado. Test-Planning exigiu encurtar o worktree para .harness/i por MAX_PATH.
Test-Mta falhou uma vez por arquivo de fixture em uso e passou na repeticao isolada.
67 links/ancoras locais, sintaxe e diff conferidos; revisao local sem bloqueantes.
Acionamento/delegacao/implementacao no Copilot permanece pendente de ensaio real.

## Criterios Sonar e padroes de configuracao - 2026-09-29

Continuar em harness/sonar, worktree isolado, a partir de main 8bbda20.
Pedido confirmado: Blocker/High acima de zero reprovam; cobertura global abaixo
de 85% e aumento do total de issues sao avisos. Gate do servidor independente.
Consultar metricas MQR sem mapear Critical para High. Ausencia/invalidez permanece
UNVERIFIED; nenhuma mudanca nos planos/criterios historicos da aplicacao.

Comparar violations com result.json ANTES explicitamente escolhido; conferir
identidade/configuracao e preservar historico. Sem baseline, comparacao PENDING.
Exportar criteria.json e resumo legivel, sem GO. Comparacao numerica nao comprova
equivalencia de regras/perfis/exclusoes nem ausencia de novas issues.

Workspace: configurar caminhos deve incluir campos Sonar ausentes no JSON local,
com scannerVersion 5.8.0.7211, timeout 300, profiles [] e URL/JDK a preencher.
Preservar overrides existentes. Documentar cada padrao e o que conferir no trabalho.

Ensaio real anterior informado pelo operador e measures.json local conferido:
RunId 9bdf2bed884f47ebaa7a0f9ab861f8ce, 2026-09-29 13:26:34 -03:00,
Sonar local 26.7.0.124771, scanner 5.8.0.7211, Gate OK, cobertura 100%, violations 2.
Essa coleta nao continha contagem High nem avaliava os novos criterios. Preservar.
Validar limites, dados ausentes, baseline incompativel, avisos versus falhas e
configuracao antiga; revisar e integrar localmente sem push, conforme pedido.

Validacao concluida: criterios e preenchimento de configuracao reproduziram
as lacunas antes da implementacao e passaram depois. Fluxo Sonar simulado passou
com High reprovando mesmo com Gate OK, avisos sem falha, MQR indisponivel e
recusa de 11 baselines incompatíveis antes de iniciar scanner. Passaram tambem
52 verificacoes HTTP, tasks, build-config, workspace e limpeza; sintaxe e diff
conferidos. Revisao local concluida; novo scan real fica para o operador.

## Integracao SonarQube - 2026-09-29

Retomar a pendencia Sonar por pedido explicito: uma Run Task de analise Maven
para servidor local Docker ou corporativo. Branch harness/sonar derivada de main
025f3ff em worktree isolado; nao aplicar corretivas nem alterar o ensaio.

Configurar sonar.serverUrl, scannerJdkHome, scannerVersion fixa e timeout no JSON.
Reutilizar projeto do workspace e Maven/settings da aplicacao. Solicitar chave
Sonar e branch opcional por execucao (sem cadastro Git); ANTES/DEPOIS e declaracao
do operador. Token por Read-Host -AsSecureString, somente no ambiente temporario
do processo; nunca em argumentos, JSON ou logs. Scanner em JDK proprio, Java 8
referenciado por sonar.java.jdkHome; build/testes devem existir antes da coleta.

Adaptar SonarApi do template anterior: URL validada, sem redirecionamento de
credencial, CE vinculado a task/projeto e Quality Gate por analysisId. Exportar
metricas somente se a analise ainda for a atual antes/depois da consulta; concorrencia
ou ausencia fica UNVERIFIED. Sem comparacao automatica ANTES/DEPOIS ou GO.
Guardar recibo, metadados, metricas, gate e resumo por projeto/data/RunId em
.harness/sonar, preservado pela limpeza existente. Registrar fontes/configuracao
e Git informativo. Nao importar gates Git nem caches/settings proprios do template.

Validar com Maven/API simulados: sucesso, gate reprovado, erros, concorrencia,
timeout, isolamento de projeto, restauracao do ambiente e ausencia de token.
Conferir contratos existentes de build/config/workspace/tasks/limpeza. Documentar
limites de cobertura, baseline, autenticacao e APIs corporativas. Ensaio real
depende do servidor, JDK e token do operador; nao inventar resultado integrado.

Implementacao e revisao local concluidas: 52 verificacoes HTTP em loopback,
scanner/Maven simulados (incluindo wrapper nativo com token sintetico), falhas,
Gate reprovado e corrida antes/depois da consulta de metricas. Regressao de build,
configuracao antiga, workspace, selecao, tasks e limpeza passou em PowerShell 5.1.
Limpeza preserva o baseline Sonar. Nenhum scan real foi enviado nesta entrega;
token e compatibilidade corporativa continuam dependendo do operador.

## Consolidacao do guia para demonstracao - 2026-09-29

Pedido do desenvolvedor: consolidar o ensaio documental e explicar a continuidade
ate GO, execucao, verificacoes e aceite para demonstracao em outra maquina.
Branch harness/guia-revisao-demonstracao a partir de main 51bb8bb, no worktree
isolado existente; checkout do ensaio preservado em main_jboss_eap74.

Fonte da consolidacao: TRACE-ENSAIO.md local indicado abaixo, eventos 01 a 24.
Publicar instrucoes reutilizaveis no guia e exemplo limpo, sem copiar o diario
ou evidencias locais para o Git. Distinguir as duas opcoes de preparo, Previous,
preenchimento do LEIA-ME e correcao documental na mesma solicitacao. Explicar
maquina com historico versus clone sem .harness e os limites de Sonar/deploy.

Proposta inicial e revisao com mesma rodada foram produzidas e conferidas; os
ajustes documentais solicitados foram atendidos. Leitura de memoria permanece
nao verificada. Revisao com MTA novo, implementacao, verificacoes e GO/aceite nao
foram realizados no ensaio. Pendencias tecnicas ficam nos documentos da aplicacao.
Validar links/ancoras, tarefas citadas e diff; integrar e disponibilizar a
documentacao para a maquina da apresentacao, sem repetir build/MTA.
Conferencia documental concluida: 55 links/ancoras locais, catalogo de tarefas,
prompts existentes e diff sem erros. Mudanca somente de documentacao; suites
PowerShell e build/MTA nao repetidos. Integracao/publicacao registradas no trace.

## Preparo explicito de revisao - 2026-09-29

O ensaio mostrou que o terminal recomenda /planejar-lotes mesmo quando o operador
precisa de /revisar-lote com Previous e evidencias. Evolucao do harness separada
do lote HIB-CACHE-001, sem GO de corretivas. Branch harness/preparar-revisao,
derivada de main f1d6b06, em worktree isolado; checkout do ensaio preservado.

Reutilizar a task Planejamento: preparar contexto para Copilot com selecao explicita
entre planejar-lotes e revisar-lote. Revisao exige proposta anterior salva e indice
LEIA-ME existente, prepara prompt de revisao com ambos os caminhos e mostra somente
a chamada adequada. Preservar o prompt-base/contexto, historico, hashes MTA/Previous
e ausencia de hashes das evidencias complementares. CLI sem selecao continua com
o comportamento de planejamento; permitir selecao explicita por parametro.

Validar cancelamento/entradas incompletas sem criar solicitacoes, fluxo real da
task, prompt aberto no editor, comandos exibidos e preservacao de documentos.
Atualizar guia, modelo do indice e contrato. Revisar antes de integrar; entrega
na integracao EAP 7.4 e etapa explicita posterior. Contexto da6aa1af0eae do ensaio
permanece utilizavel com /revisar-lote e indice explicitos, sem repetir build/MTA.

Implementacao revisada: menu na task existente (14 tarefas mantidas), revisao com
Previous/indice obrigatorios, prompt executavel especifico e chamada completa no
terminal. Test-Planning, Test-TaskInputs e Test-EvidenceFolder passaram em Windows
PowerShell 5.1; 34 links locais e git diff --check conferidos. Testes cobrem menus,
CLI, cancelamento, indice ausente, proposta ausente, preservacao e editor simulado.
Foi usado mapeamento temporario de caminho curto para os testes no worktree;
nao houve mudanca de ExecutionPolicy. Ensaio do prompt no Copilot segue pendente.
Entrega 34992f8 integrada localmente por fast-forward na main e depois em
main_jboss_eap74, preservando a branch do checkout do operador e sem diff nos
exemplos. Sem publicacao remota nesta entrega. O trace local registra o aprendizado
incorporado e a continuidade da revisao da aplicacao, ainda sem GO.

## Ponto atual do ensaio - 2026-09-28

Registro historico do ponto de 28/09. A consolidacao de 29/09 acima e o trace
local registram o estado posterior; nao repetir a preparacao inicial abaixo.

Coleta unica autorizada pelo desenvolvedor em 2026-09-28: consultar/atualizar
`.harness/ensaios/migracao-cache-antes__97a5fc995901/ensaio_2026-09-28_20-31-22-0300/TRACE-ENSAIO.md`
a cada marco. O trace local reune resultados relatados/conferidos, decisoes,
dificuldades e aprendizados para consolidacao posterior no guia. Nao acompanha
o clone; nao duplicar a narrativa em outros documentos. Planos de corretivas e
recibos continuam em seus destinos proprios. Proxima acao segue abaixo.

Manutencao documental autorizada: consolidar pendencias, preservar historico e
marcar controles removidos/retomadas antigas como SUPERADOS. Branch
harness/atualizar-pendencias a partir de main 6fa8b2b. Nenhuma alteracao em
.harness, fontes, prompts ou configuracao faz parte desta manutencao.

O desenvolvedor reiniciou o ciclo e informou limpeza concluida (5 caminhos).
Resultados compartilhados nesta conversa, sem nova execucao nesta manutencao:

- Build clean install Java 8 SUCCEEDED: 3b692d6e86fa48a4a817dcbdfdc7efa1.
- MTA 8.2.1 SUCCEEDED, integridade registrada: 13e178eb9c804e5e97a9190dbdd36816,
  de 2026-09-28 17:05:53 -03:00 (20:05:53 UTC), projeto migracao-cache-antes.

Proximo passo: concluir preparacao com essa rodada e iniciar planejamento
independente (Previous null); o novo RequestId ainda nao foi informado.
Conferir no Copilot delegacao a devsquad.plan, plan/todo e proposta nao aprovada.
Depois, ensaiar feedback/evidencias via revisar-lote e continuidade com novo MTA,
sempre escolhendo a proposta do ciclo atual em Previous. Nao buscar nem exigir
solicitacoes antigas citadas abaixo. GO/aceite e tarefas de corretivas ficam nos
documentos da aplicacao, separados deste plano do harness.

Escopo recente implementado ate 6fa8b2b: planejamento/delegacao, Git informativo,
feedback e revisao, tarefa de evidencias, guia e horario local. Pendencias atuais
e backlog Sonar/deploy/servidor estao consolidados no inicio de [todo.md](todo.md).
Destinos de deploy confirmados pelo desenvolvedor em 2026-09-28: JBoss EAP 7.1
e 7.4, conforme tools.eap71Home/tools.eap74Home no JSON local (campos conferidos).
O planejamento futuro reutiliza essa configuracao para selecao do servidor e
controle de estado/start/stop; nao reabre escolha de versoes nem inclui EAP 7.0.
Isso nao exige que o artefato corrigido para EAP 7.4 funcione tambem no EAP 7.1.
Validacao da limpeza concluida: diff sem erros, links locais existentes e itens
abertos somente nas secoes atuais/backlog, sem checkboxes pendentes no historico.
A coleta do ensaio acrescentou a consolidacao posterior no guia como pendencia.
Build/MTA e testes de scripts nao repetidos por ser ajuste documental.

## Historico de evolucao do harness

As secoes abaixo registram decisoes e entregas nas respectivas datas; titulos
antigos como "atual", "ajuste" ou "retomada" pertencem aquele momento. A ADR-0004
supera o controle de branches da ADR-0003. Cadastro, conferencia Git obrigatoria,
quantidades antigas de tarefas e IDs de contextos anteriores nao sao requisitos
do ensaio atual. Preservar esse historico nao significa renovar tarefas removidas.

## Horario local no menu de planejamento - 2026-09-28

Bug observado: ultima elegivel e historico MTA exibem UTC, enquanto pastas e
historico de planos usam horario local com fuso. Branch harness/horario-planejamento
a partir de main 78235c3. Reutilizar Format-HarnessDate nas duas mensagens;
manter datas/ordenacao/recibos em UTC. Testar exibicao e selecao no Test-Planning.


## Tarefa de evidencias e percurso de feedback - 2026-09-28

Pedido: criar estrutura por projeto via Run Task e explicar feedback -> build/MTA
novo -> evidencias -> contexto com Previous -> revisar-lote -> revisao humana.
Branch harness/tarefa-evidencias derivada de main 5f27366. Reutilizar selecao de
projeto, chave de pasta e formatacao de data. Criar somente pasta nova e LEIA-ME
com identidade/instrucoes, sem hashes de arquivos, MTA ou lote escolhido sozinho.
Atualizar modelo, guia, catalogo de tarefas e especificacao. Testar entrada real,
isolamento, repeticao sem sobrescrita, cancelamento e abertura do indice.

Implementado com entrada criar-pasta-evidencias.ps1 e modelo reutilizavel do guia.
Test-EvidenceFolder passou em PowerShell 5.1: selecao/cancelamento reais, caminhos
com espacos, homonimos isolados, repeticao preservada e editor simulado.
Test-TaskInputs passou com 14 tarefas. Guia e indice explicam o ciclo completo,
incluindo feedback documental sem novo MTA, Previous e GO/aceite separados.
Nenhum MTA, corretiva ou revisao Copilot foi executado nesta entrega.


## Evidencias complementares e revisao de lote - 2026-09-28

Pedido autorizado: guia, pasta por projeto/data e prompt separado de revisao;
sem hashes de arquivos adicionais. Branch harness/evidencias-revisao a partir
de main 46ce43c. Contrato em doc/especificacoes/planejamento-copilot.md.
Manter planejar-lotes e preparacao existentes; revisar-lote usa prompt preparado
com Previous e indice LEIA-ME das evidencias. Criar modelo de indice e pasta
local para migracao-cache-antes, sem inventar resultados. Validar ferramentas,
links, contrato de caminhos e limpeza preservando a nova area. Ensaio Copilot
fica com o operador; nao alterar plano/to-do da aplicacao nesta entrega.

Entrega implementada: revisar-lote, modelo do indice e secao operacional no guia.
Pasta local criada em .harness/evidencias/migracao-cache-antes__97a5fc995901/
evidencias_2026-09-28_16-10-43-0300/, somente LEIA-ME.md sem resultados inventados.
Verificado: ferramentas iguais ao prompt inicial, 23 links locais existentes,
git diff --check e preview real de limpeza -All sem a area evidencias.
Git confirma indice local ignorado. Template inicial, gerador e limpeza sem diff.
Revisao documental conferiu Previous, destinos, ausencia de hashes adicionais,
delegacao unica, limites e separacao entre precondicoes e validacoes posteriores.
Ensaio no Copilot permanece pendente; nao houve execucao de corretivas nesta entrega.

## Revisao manual documentada - 2026-09-28

Detalhar no guia o ciclo do desenvolvedor: abrir proposta, registrar observacoes,
salvar antes do novo contexto, selecionar Previous e revisar os novos documentos
do mesmo lote antes do GO. README mantem resumo e apenas aponta para essa secao.
Retomada de harness/consistencia-planejamento, alinhada a main 9a4ddce; escopo
somente documental, sem editar planos locais da aplicacao. Conferir o fluxo com
Select-MtaPreviousPlanning/New-MtaPlanningContextCore e validar links/ancoras.

## Consistencia da revisao de planos - 2026-09-28

Pedido: evitar que revisoes acrescentem orientacoes novas e preservem contradicoes
ativas em outras secoes. Evolucao do harness na branch harness/consistencia-planejamento,
derivada de main d8bce9a. Atualizar o template e o guia: substituir orientacoes
incompativeis, conferir documentos completos e distinguir precondicoes/GO de
verificacoes posteriores/aceite, incluindo baseline antes de qualquer alteracao.
Validar propagacao pelo teste existente de planejamento, revisar o diff e integrar.
Nao alterar o plano da aplicacao nem prompts/recibos ja preparados. O operador
gerara novo contexto vinculado ao atual para ensaiar o contrato no DevSquad.

## Roteiro resumido no README - 2026-09-28

Pedido: apresentar o caminho operacional no README e remeter aos detalhes do guia.
Escopo documental: limpeza opcional, clean install, MTA, preparo de contexto,
execucao do prompt e revisao. Distinguir inicio independente de continuidade e
preparo de execucao do agente; preservar GO separado. Branch harness/readme-roteiro
derivada de main af79b9f, sem novo worktree. Conferir tarefas e links/ancoras antes
de integrar na principal e retornar a main_jboss_eap74.

## Simplificacao Git solicitada — 2026-09-28

Pedido: eliminar o controle de branches do harness e deixar a escolha/gestao
com o desenvolvedor. Branch harness/git-informativo derivada da main 71a3918,
em worktree isolado; checkout do operador em corretiva/cache-hib-001 preservado.

Remover cadastro gitPolicies, gate de prontidao Git e Run Task de conferencia.
Manter coleta informativa de repositorio/modulo, branch, commit e estado local,
sem exigir responsavel, coordenacao, branch principal/migracao ou novo contexto
apenas por trocar branch/HEAD. Politicas antigas ficam ignoradas; recibos e
planos historicos permanecem intactos. Manter integridade/identidade MTA, escopo
de escrita, GO separado e verificacoes tecnicas. Mudanca de codigo relevante
exige avaliar aplicabilidade dos achados; diferenca Git isolada nao bloqueia.

Atualizar scripts, prompt, instrucoes, ADR e guia, com testes para ausencia de
menu/gate, coleta sem politica e compatibilidade com historico. Integrar a
mudanca validada nas mains e na branch limpa do ensaio, sem mudar sua selecao.
Preparar contexto atualizado vinculado ao plano atual para destravar o ensaio.

Validacao concluida: 11 testes Test-*.ps1 em Windows PowerShell 5.1, incluindo
configuracao gitPolicies invalida/duplicada ignorada, preparo sem menu Git,
abertura/continuidade de recibo com politica antiga e preservacao do historico.
52 links/ancoras locais conferidos; diff sem erros. Revisao de codigo/contrato
sem consumidores remanescentes das funcoes removidas. A configuracao local nao
precisa ser limpa: a politica antiga e ignorada. Copilot ainda requer ensaio
do contrato atualizado; testes nao comprovam comportamento do modelo.

Entrega implementada em 101c57b e integrada por fast-forward em main,
main_jboss_eap74, harness/devsquad-planejamento e corretiva/cache-hib-001.
Contexto e450f0ea38ec440f84e6daf001be1051 preparado com o prompt atualizado,
mesmo MTA 391c4a60505440fdb26d4b6419bfa643 e Previous 31a8ff4cb3854db18ed3c67452d667e6.
O Copilot deve continuar CACHE-HIB-001 nos novos destinos, preservando o historico
e marcando exigencias Git antigas como superadas. Conferidos os hashes dos 14
arquivos locais protegidos, todos preservados; nenhum diff nos exemplos.
O ensaio do prompt novo no Copilot permanece com o operador. Avancos de HEAD
apenas para registrar esta entrega nao exigem outro contexto.


## Delegacao de planejamento DevSquad — 2026-09-28

Pedido autorizado: corrigir o conflito entre o condutor devsquad e o prompt que
proibia delegacao, preservando skills e escrita exclusiva de PlanPath/TodoPath.
Base: main em d8b4b04, checkout limpo; branch harness/devsquad-planejamento em
worktree isolado. Checkout da migracao permanece em main_jboss_eap74.

Usar o condutor nativo devsquad e uma delegacao delimitada a devsquad.plan.
O especialista devolve os dois documentos em memoria; o condutor valida destinos,
grava e rele os arquivos. Adaptar explicitamente o fluxo generico do plugin:
sem docs/, ADRs adicionais, board, terminal, implementacao ou subdelegacao.
As skills pertinentes continuam disponiveis por leitura, com relato de uso.
Nao modificar o plugin instalado nem as solicitacoes historicas.

Validar ferramentas no prompt gerado, identidade e preservacao dos documentos
anteriores em Test-Planning; conferir catalogo em Test-TaskInputs e revisar diff.
Depois de revisado, integrar explicitamente main -> main_jboss_eap74 e preparar
nova solicitacao com o template atualizado para o ensaio do desenvolvedor.
O MTA 391c4a60505440fdb26d4b6419bfa643 continua historico de d8b4b04;
mudanca apenas no harness exige registrar a diferenca de HEAD, sem reatribuir a rodada.
Aceite do comportamento no Copilot: PENDENTE do ensaio; testes locais validam
preparacao/contrato, nao execucao de subagentes ou obediencia ao escopo.

Verificado: Test-Planning.ps1 e Test-TaskInputs.ps1 passaram em Windows
PowerShell 5.1, sem alterar ExecutionPolicy. O teste de ferramentas falhou antes
do ajuste e passou com agent habilitado. Worktree movido para temporario curto
por limite de caminhos do PowerShell 5.1; checkout de migracao preservado.
Revisao do contrato/diff: delegacao de um nivel, perfis proprios tratados como
limites comportamentais, defaults do plugin adaptados explicitamente.
Os nove arquivos da aplicacao registrados no manifesto MTA mantem os hashes.
Foram encontrados plan.md/todo.md na solicitacao 8288c85ebd61476381fa7dfbcb7fe841;
preserva-los e vincular a nova solicitacao a ela, mantendo o lote existente.
Esses arquivos nao comprovam o ensaio da nova delegacao.

Integracao local concluida: ajuste 7851782 levado por fast-forward a main e
depois a main_jboss_eap74. Checkout da migracao mantido limpo nessa branch.
O desenvolvedor repetira a tarefa de preparar contexto no VS Code, selecionando
o MTA 391c4a605054 e a proposta anterior 8288c85ebd61. O novo contexto registrara
o HEAD atual e preservara MtaGit da rodada; nao reutilizar o prompt antigo para
testar a delegacao nova. Encerrar o ensaio apos persistir e conferir os dois
documentos. Atualizacao: cadastro/conferencia Git foram SUPERADOS pela ADR-0004;
GO humano continua necessario. A retomada especifica acima foi superada pelo
reinicio do ensaio e nao deve ser executada com os antigos IDs.

## Ponto de retomada — 2026-09-27

SUPERADO pelo ponto atual de 2026-09-28 no inicio deste arquivo. Registro historico.

Sessao encerrada a pedido do desenvolvedor. Antes deste registro, main e
main_jboss_eap74 estavam limpas, publicadas e alinhadas em f61798d. As branches
lote/cache-hib-001 e harness/separacao-branches foram removidas local/remotamente
apos confirmar integracao completa. Este registro usa harness/ponto-retomada
e deve ser integrado/publicado nas duas bases, retornando o checkout a EAP 7.4.

Entregue: fluxo progressivo na base integrada, solicitacao da branch de lote pelo
planejador depois da proposta, branch propria para evoluir o harness, guia Git/
TortoiseGit adaptado e ligado ao guia do desenvolvedor. Validacoes: Test-Planning.ps1,
14 links locais, diff --check e revisao estatica independente aprovados na entrega.
Nenhuma corretiva da aplicacao foi aplicada nesta etapa; nao houve GO de execucao.

O roteiro daquela data previa build, MTA, proposta e cadastro/conferencia Git
antes da corretiva. As etapas de controle Git foram removidas pela ADR-0004;
seguir agora o ponto atual e o guia, mantendo somente GO e validacoes tecnicas.

O build 4f313156cb544767bce0e1410dfe15b3 e MTA 5cc84cfbfee345d1a1ae043ebdfec115
sao historicos anteriores a essa base; nao atribuir a eles o HEAD/branch atual.
Solicitacoes antigas citadas abaixo podem ter sido apagadas pela limpeza autorizada;
nao reutilizar seus caminhos sem verificar existencia e identidade.
Configuracao local, workspace e .harness sao ignorados pelo Git: o commit deste
ponto preserva documentacao/codigo versionados, nao e backup desses dados locais.
Java/Maven continuam separados entre MTA e build, com settings opcionais null
e repositorio Maven padrao da maquina. Sonar/deploy/servidor continuam backlog.

Qualquer nova evolucao do harness deve comecar em harness/<objetivo> a partir
da main, preservando o checkout da migracao. Apos cada lote aceito e integrado,
novo build/MTA da base EAP 7.4 orienta a proposta seguinte.

## Regra de trabalho: branch exclusiva do harness

Por solicitacao do desenvolvedor, novas alteracoes do harness usam
`harness/<objetivo>` a partir da principal, com revisao/validacao antes de integrar.
Registrar em AGENTS.md, instrucoes do Copilot, ADR-0002 e guia. Este complemento
foi iniciado em `harness/separacao-branches`, preservando os registros locais
da entrega anterior, integrado/publicado em f61798d e alinhado a EAP 7.4.
A branch temporaria foi removida apos confirmar sua integracao.

## Entrega atual: iniciar pela base de integracao

Consolidar guia e prompt em main e main_jboss_eap74, publicar e remover a branch
lote/cache-hib-001 local/remota somente apos confirmar ausencia de commits
exclusivos e de outro checkout em uso. Deixar checkout limpo em main_jboss_eap74.
O planejador solicita a criacao da branch depois de definir e gravar a proposta;
nao cria branches nem aplica corretivas. Validar geracao pelo Test-Planning.ps1.
Esta decisao substitui a criacao antecipada da branch registrada no historico abaixo.
Incorporar o guia fornecido de Git/TortoiseGit como referencia adaptada em doc/guias,
ligada ao guia do desenvolvedor nos tres sentidos de integracao. Preservar o
original externo e distinguir diagnostico, integracao, validacao e deploy em PRD.

Concluido em 2026-09-27: entrega 74fca9b publicada nas duas branches, branch de
lote removida local/remotamente sem commits exclusivos, checkout na integracao.
Test-Planning.ps1 passou; links e diff conferidos, revisao estatica aprovada.
Proxima atividade do desenvolvedor: novo build/MTA da base integrada e proposta.

## Esclarecimento do fluxo de branches no guia

Documentar diagnostico inicial na base de migracao antes de conhecer o lote,
criacao da branch apos a proposta e retorno a integracao EAP 7.4 entre lotes.
O MTA do estado integrado orienta o proximo lote; preservar identidade historica,
conferencia Git, coordenacao paralela e revisoes humanas. Alteracao documental.
Exigir nova rodada completa no commit integrado para o proximo lote; relatorios
de commits individuais nao substituem essa evidencia. Preservar historicos.

## Historico: consolidar main e preparar branches do ensaio

Pedido do desenvolvedor: main limpa, commit/push das evolucoes do harness e branches
separadas para integracao EAP 7.4 e lote. Revisar alteracoes, executar os 11 testes,
conferir remoto e arquivos ignorados, consolidar commits em main e publicar.
Criar `main_jboss_eap74` a partir dessa main e `lote/cache-hib-001` a partir dela;
publicar sem force e deixar checkout na branch do lote. Nao aplicar corretivas.
As branches pertencem ao repositorio inteiro; neste ensaio os exemplos compartilham
o Git do harness. Configuracao local, workspace local e .harness ficam fora do Git.
O cadastro de papeis/responsavel continua no menu do desenvolvedor, depois da criacao.

Concluido em 2026-09-27: 11 testes passaram, revisao estatica independente sem
bloqueantes e links locais conferidos. Commits ee1f199 (implementacao) e 48cd359
(documentacao) integrados por fast-forward e publicados na main. Branches
main_jboss_eap74 e lote/cache-hib-001 criadas e publicadas a partir dessa base.
Seis pastas antigas de rodadas vazias removidas; MTA atual preservado.

## Ajuste atual: respeitar configuracao padrao das ferramentas

Pedido: manter somente os complementos necessarios ao harness, sem reinventar
padroes como repositorio Maven. Remover overrides de settings da configuracao
local e workspace; defaults ja sao null no exemplo. Registrar convencao e testar
geracao sem override. Conferir configuracao Maven da maquina antes de concluir.
O cache antigo nao deve ser confundido com a configuracao ativa apos a troca.

Concluido: JSON/workspace sem overrides de settings; configuracao da maquina
conferida. Test-BuildConfig passou. Cache antigo movido para backups-temporarios,
sem copiar/mesclar com .m2. Test-Cleanup validou tambem caminhos >260 caracteres.
Novo ensaio real confirmado: build 4f313156cb544767bce0e1410dfe15b3 e MTA
5cc84cfbfee345d1a1ae043ebdfec115 concluidos com sucesso, com relatorio aberto.

## Ajuste atual: reunir backups temporarios

Pedido: evitar pastas avulsas de exercicios/ajustes sob .harness. Usar somente
`.harness/backups-temporarios/<atividade>/` quando uma copia temporaria for
necessaria; reunir backups existentes e registrar a regra em AGENTS.md.
Reutilizar Workspace: limpar execucoes com opcao exclusiva para esses backups,
preview e confirmacao. Manter a limpeza de execucoes com o escopo atual.
Backups automaticos do workspace continuam em workspace-backups, usados pelo
gerador; cache Maven e fixtures de testes conservam suas finalidades.
Verificar isolamento, cancelamento, links/junctions e menu na fixture Test-Cleanup.
Conferir hashes ao mover apenas os backups temporarios identificados.

Concluido: regra e guia atualizados, opcao 3 implementada e Test-Cleanup passou.
Seis arquivos centralizados com hashes preservados; dois backups POM e fixtures
removidos por pedido explicito. Maven/cache e workspace-backups preservados.

## Nova entrega: reiniciar ensaios e reduzir verificacoes manuais

Pedido de 2026-09-27: adicionar uma unica tarefa `Workspace: limpar execucoes`.
Preparar menu para um projeto ou todos, listar caminhos e exigir confirmacao
local antes de remover runs (inclui relatorios), builds e planning (inclui
prompts/planos/to-dos), com ponteiros relacionados. Preservar configuracao,
workspace, fontes, Git, templates, Maven/cache e backups. Nao apagar copias
externas de relatorios nem target/ da aplicacao. Bloquear durante build/MTA ou
preparacao de contexto. Orientar encerrar Copilot antes de limpar: nao ha lock
compartilhado com o agente. Validar paths absolutos contidos nas areas permitidas
e recusar links/junctions antes da primeira remocao.

O desenvolvedor confirmou: a corretiva e a automacao Git do harness, nao o lote
CACHE-HIB-001. Confirmou tambem menu de limpeza por projeto ou todos.
Incrementos: limpeza isolada; integracao da tarefa/locks; coleta Git nos recibos;
cadastro dos papeis das branches por Source; conferencia atual contra o planejamento.
O catalogo passa de 12 para 14 tarefas, com uma Workspace de limpeza e uma
Planejamento de conferencia Git. Nao ha tarefa por projeto ou tipo de artefato.

Pedido adicional: manter README como entrada resumida e concentrar passo a passo,
decisoes dos menus e significado das branches no guia do desenvolvedor em doc/guias.
Preservar instrucoes manuais incorporadas ao template; nao regravar contextos antigos.

Verificacao: Test-Cleanup.ps1, Test-TaskInputs.ps1 e Test-Planning.ps1; preservar
arquivos sentinela de configuracao, cache, fontes e outro projeto. Executar a
limpeza real pelo menu com destinos visiveis e confirmacao LIMPAR; nao usar evidencias
reais como fixture de teste. O encerramento da conversa Copilot fica a cargo do
desenvolvedor, pois o harness nao controla o agente externo.

Verificado em 2026-09-27: Test-Git, Test-Cleanup, Test-Planning, Test-Mta, Test-Build
e Test-TaskInputs passaram. Git inclui cadastro/cancelamento sem troca de branch,
preservacao de outros projetos, HEAD alterado e arquivos nao rastreados. Limpeza
inclui junction, locks MTA/planejamento e ponteiro de outro Source com mesmo nome
legado. Sintaxe PowerShell e 56 links/ancoras locais conferidos; diff sem erros.
Nao houve limpeza real ou troca de branch do desenvolvedor. A verificacao Git
permanece conservadora com alteracoes locais e comprova apenas referencias locais.

## Historico: nomes legiveis para artefatos

Estado: REESTRUTURACAO IMPLEMENTADA E VALIDADA em 2026-09-27, incluindo ensaio visual relatado pelo desenvolvedor.
Este plano evolui o harness. Planos de corretivas continuam nos destinos dos contextos.
Historico e pendencias anteriores preservados em [todo.md](todo.md).

## Objetivo e escopo

Estender aos novos artefatos MTA e build a convencao ja implementada nos
planejamentos: nome do projeto, data/hora com fuso e identificador curto. Facilitar
localizacao e compartilhamento de relatorios, preservando identidade e historico.

Manter as tres areas existentes, sem criar outra arvore ou duplicar documentos:

```text
.harness/
  runs/<nome>__<chave12>/mta_<data-fuso>__<RunId12>/
    manifest.json, result.json, console.log, input/, rules/, output/
  builds/<nome>__<chave12>/build_<data-fuso>__<RunId12>/
    result.json, console.log
  planning/<nome>__<chave12>/mta_<data-fuso>__<RunId12>/
    plano_<data-fuso>__<RequestId12>/
      context.json, planejar-lotes.prompt.md, plan.md, todo.md
```

Nome sanitizado e limitado a 24 caracteres; chave estavel de 12 caracteres por
identidade do projeto. Reutilizar a convencao atual do planejamento. Os IDs
completos permanecem nos recibos; o build ja usa RunId, sem introduzir BuildId.
Usar o mesmo instante no nome e no recibo: CreatedAtUtc para MTA, StartedAtUtc
para build e PreparedAtUtc para planejamento. Pasta mostra horario local e fuso
(`2026-09-27_14-30-00-0300`); recibos conservam UTC.

Todos os arquivos de uma execucao ficam dentro dela: relatorio HTML e seus assets,
achados YAML, logs, snapshots, regras e resultados. Manter os nomes internos
produzidos pelas ferramentas. Artefatos Maven em target/ permanecem na aplicacao.
Configuracao local, locks e ponteiros active/last mantem suas funcoes e localizacao.

Pastas antigas nao serao movidas, renomeadas nem regravadas. A descoberta deve
aceitar ambos os formatos, conferir Project/Source/RunId completos e preservar
hashes, caminhos de contextos existentes e vinculos Previous. Nao deduzir RunId
do nome da pasta nem considerar nomes amigaveis como prova de identidade.

Fora do escopo: automatizar branches/Git, alterar corretivas, gerar novos tipos
de relatorio, criar comandos de exportacao/ZIP, publicar/enviar arquivos ou mudar
o fluxo de aprovacao. Compartilhamento sera orientado no guia existente.

## Etapas e criterios de aceite

### Regra transversal: Run Tasks por etapa

Manter os prefixos existentes em todos os labels:

| Prefixo | Responsabilidade |
| --- | --- |
| `Workspace:` | Configurar caminhos, gerar workspace e conferir sua configuracao |
| `Aplicacao:` | Build Maven da aplicacao |
| `MTA:` | Conferir ambiente MTA, executar analise, acompanhar/consultar logs e abrir relatorio |
| `Planejamento:` | Preparar contexto e abrir plano/to-do |

Esta entrega reutiliza as 12 tarefas atuais; a mudanca dos caminhos nao cria novas
entradas. Projeto, rodada, data e formato antigo/novo sao selecoes/parametros das
tarefas existentes, nao tarefas separadas. Funcoes auxiliares dos scripts nao
viram Run Tasks. Preservar labels, referencias e comportamento de selecao usados
pelos testes. A classificacao e feita pelo prefixo da etapa no nome da tarefa.

Na verificacao final, conferir prefixos, labels unicos e ausencia de crescimento
do catalogo nesta entrega, junto ao teste Test-TaskInputs.ps1.

### 1. Reutilizar a convencao de nomes

- Trabalho: disponibilizar no modulo comum as pequenas funcoes de nome/chave/data
  hoje usadas pelo planejamento, sem criar um novo framework ou modulo.
- Aceite: planejamento continua gerando o mesmo formato; datas/fuso consistentes,
  homonimos isolados, IDs completos preservados e colisao sem sobrescrita.
- Verificacao: Test-Planning.ps1, incluindo nomes longos e caminhos com espacos.
- Dependencias: nenhuma. Arquivos: Harness.psm1, HarnessPlanning.psm1,
  Test-Planning.ps1. Porte: pequeno, tres arquivos.

### 2. Preparar leitura de MTA nos dois formatos

- Trabalho: localizar rodadas por identidade e manifesto, antes de mudar a escrita.
  Atualizar ultimo relatorio, analise ativa, historico/log e selecao para planejamento.
- Aceite: formatos antigos/novos coexistem; -RunId continua recebendo o ID completo;
  active-mta.json e last-*.json encontram a rodada correta; builds nao sao confundidos
  com MTA. Rotulo renomeado nao perde historico; ambiguidade/divergencia e recusada.
- Verificacao: Test-MtaLog.ps1, Test-MtaActive.ps1 e Test-Planning.ps1; fixtures mistas,
  falhas/execucoes incompletas, registro ativo antigo, cancelamento e isolamento.
- Dependencias: 1. Arquivos: Harness.psm1, HarnessPlanning.psm1,
  acompanhar-log-mta.ps1, Test-MtaLog.ps1, Test-MtaActive.ps1. Porte: medio.

Checkpoint: os leitores reconhecem ambos os formatos com os testes existentes
passando; so entao a geracao de MTA pode adotar os novos caminhos.

### 3. Gravar novas rodadas MTA com nomes legiveis

- Trabalho: New-MtaSnapshot cria a nova pasta e usa seus caminhos reais nos argumentos,
  manifesto, resultado e acompanhamento. Planejamento continua vinculado ao RunId.
- Aceite: snapshot, logs, regras e relatorio permanecem juntos; execucao/abertura e
  acompanhamento funcionam; criar novo contexto a partir da rodada nova ou antiga
  preserva evidencias e vinculos. Caminhos internos do relatorio ficam intactos.
- Verificacao: Test-Mta.ps1 e Test-Planning.ps1; regressao dos leitores da etapa 2;
  tamanho realista de caminhos incluindo arquivos aninhados do snapshot.
- Dependencias: 2. Arquivos: Harness.psm1, Test-Mta.ps1, Test-Planning.ps1.
  Porte: pequeno, tres arquivos.

### 4. Gravar builds com a mesma convencao

- Trabalho: usar nome/chave do projeto e StartedAtUtc na pasta de build; preservar
  os caminhos LogPath/ResultPath retornados e o contrato de RunId.
- Aceite: builds com sucesso ou falha guardam resultado/log na pasta legivel;
  execucoes no mesmo segundo sao distintas e nao sobrescrevem historico; lock e
  separacao MTA/build continuam corretos. Builds antigos permanecem no lugar.
- Verificacao: Test-Build.ps1 e Test-BuildConfig.ps1 com fixtures isoladas,
  nomes repetidos, caminhos com espacos e falha do processo.
- Dependencias: 1; executar apos 3 nesta entrega. Arquivos: HarnessBuild.psm1,
  Test-Build.ps1. Porte: pequeno, dois arquivos.

### 5. Documentar localizacao e validar compartilhamento do HTML

- Trabalho: atualizar README e a especificacao existente de planejamento com os
  novos caminhos. Orientar compartilhar uma copia de output/static-report completa,
  com nome externo identificando projeto/data/ID, preservando sua estrutura interna.
- Aceite: copiar apenas index.html nao e a orientacao; assets, api e arquivos JS
  acompanham o HTML. Conferir a copia fora do repositorio, incluindo navegacao e
  carregamento dos dados; registrar limitacoes reais em vez de prometer portabilidade.
  A copia para consulta nao substitui a rodada original nem seus recibos/vinculos.
- Verificacao: nove testes Test-*.ps1; conferir o historico real existente sem altera-lo;
  Test-TaskInputs.ps1 tambem verifica prefixos/labels e preservacao das 12 tarefas;
  ensaio de abertura da copia HTML e dos caminhos exibidos nas tarefas no VS Code.
- Dependencias: 3 e 4. Arquivos: README.md, doc/especificacoes/planejamento-copilot.md,
  tests/Test-TaskInputs.ps1, tasks/plan.md e tasks/todo.md. Porte: medio, cinco arquivos.

Checkpoint final: mesma convencao nas tres areas, consumidores funcionando com
historico misto e relatorio copiado consultavel. Mostrar caminhos e resultados ao
desenvolvedor; nao executar novo MTA real somente para renomear o historico.

## Verificacao da implementacao em 2026-09-27

- Etapas 1 a 4 implementadas; as novas gravacoes MTA/build usam os nomes legiveis.
  Historico misto, rotulo renomeado, IDs completos, identidade/fonte divergente,
  duplicidade de RunId e ponteiros de ultimo relatorio/analise ativa verificados.
- Nove scripts Test-*.ps1 passaram em Windows PowerShell 5.1, com processos
  Maven/MTA simulados. Mantidas as 12 Run Tasks, com prefixos e labels unicos.
- Rodada real b8913bad9ab84c2499d8e69fdad58a21 localizada e elegivel; quatro hashes
  conferem com o recibo do Copilot. Ultimo relatorio e plan/todo reais continuam
  acessiveis nos caminhos antigos, sem mover ou regravar historico.
- README/especificacao atualizados. Copia completa de static-report fora do repo:
  23 arquivos com hashes identicos. Caminho de ensaio:
  `C:/Users/edoar/AppData/Local/Temp/harness-share-525e401b/migracao-cache-antes_2026-09-26_09-55-07-0300__b8913bad9ab84/index.html`.
- Ensaio visual concluido pelo desenvolvedor: relatorio original da rodada
  db4a1abd43b04997bffac947242dfd87 e copia externa abriram e foram conferidos;
  a tarefa de abrir plano/to-do listou historico antigo/novo e abriu ambos os
  documentos da solicitacao 8b54d7ca896d4d5ca5b255fbfcb7b4a5. Etapa 5 concluida.
  A verificacao visual foi relatada pelo operador, nao observada por automacao.

No ensaio guiado, o desenvolvedor executou build real
5c8fb48f6c884af68b44d2d8dea41691 e a rodada MTA acima, ambos SUCCEEDED/exit 0.
O monitor interno exibiu o resultado final. Corretivas continuam sem GO/aceite;
nao foram feitos commit ou push pelo agente nesta entrega.

## Ajustes do prompt apos ensaio do Copilot

Em 2026-09-27, incorporar ao template de planejar-lotes a orientacao dada no chat
para revisar o mesmo lote ainda nao aplicado/aprovado, com ID obtido do historico,
preservando os documentos anteriores. Persistir tambem as correcoes de precisao:
versao MTA em Result.Version, equivalencia de opcoes sem ocultar diferencas de
caminhos nos argumentos, dependencies.yaml como evidencia MTA e nao resolucao
Maven atual comprovada. Atualizar a referencia aos formatos de pastas.

Preservar prompts/recibos ja preparados; a solicitacao das 15:34:11 continua sendo
a solicitacao ativa e recebeu o ajuste pelo chat do Copilot. Novas preparacoes
herdam o template atualizado. Verificar com Test-Planning.ps1, sem preparar outro
contexto real nem editar os documentos de corretivas em nome do Copilot.

## Evolucoes futuras: planejar depois da reestruturacao

Registrar como backlog, sem iniciar detalhamento ou implementacao nesta entrega.
Depois de concluir e validar a reestruturacao, planejar as etapas nesta ordem:

1. **Qualidade / Sonar:** scanner executado localmente via Maven, com selecao de
   servidor Sonar corporativo ou Sonar instalado em Docker. Recuperar as praticas
   dos outros projetos quando essas referencias forem disponibilizadas; definir
   configuracao, credenciais, resultados e criterio de qualidade no plano futuro.
2. **Deploy / release:** preparar e implantar a release da aplicacao no JBoss
   EAP 7.1 ou EAP 7.4, conforme destino selecionado, usando tools.eap71Home e
   tools.eap74Home do JSON local. Correcao confirmada pelo desenvolvedor em
   2026-09-28: a referencia anterior a EAP 7.0 estava incorreta. Detalhar selecao,
   rastreabilidade do artefato, verificacao e rollback; a migracao tem EAP 7.4
   como destino, sem exigir o mesmo WAR nos dois servidores.
3. **Servidor:** planejar start, stop e consulta de estado do JBoss no ambiente
   selecionado, incluindo a ordem necessaria para o deploy e sua verificacao.

Prever categorias de Run Tasks `Qualidade:`, `Deploy:` e `Servidor:` nesses planos
futuros, com menus/parametros para projeto, servidor e ambiente. A restricao de
12 tarefas vale para a reestruturacao atual; futuras operacoes distintas poderao
ter tarefas proprias agrupadas por etapa, sem duplicar entradas por destino.

As futuras evidencias deverao seguir a convencao de projeto/data/hora/ID e manter
vinculo com repositorio, branch/commit, ambiente e execucao. Definir seus contratos
quando cada etapa for planejada. Este registro nao autoriza analises Sonar,
criacao de containers, deploys ou start/stop de servicos agora.

## Riscos ja identificados

- Leitores reconstruem atualmente caminhos pelo ID, inclusive analise ativa e
  ultimo sucesso: atualizar leitores antes de alterar produtores.
- Windows PowerShell 5.1 ja apresentou limite de caminho nos testes de planejamento:
  manter nomes curtos e testar tambem a profundidade de snapshots/relatorios MTA.
- Rotulos podem mudar e horarios locais podem diferir entre maquinas: usar identidade
  completa e datas UTC dos recibos para vincular e ordenar, sem recalcular pastas antigas.
- O HTML real referencia ./assets/, ./output.js e outros arquivos locais: validar
  a pasta completa copiada antes de considerar o compartilhamento comprovado.

Preservar alteracoes locais; sem commit/push e sem aplicar corretivas da aplicacao.
