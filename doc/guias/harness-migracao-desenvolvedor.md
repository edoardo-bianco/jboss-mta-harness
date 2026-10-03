---
html:
  embed_local_images: true
  embed_svg: true
  offline: true
---

# Guia do desenvolvedor: harness de migracao

O **JBoss MTA Harness** e um ambiente de trabalho no VS Code que organiza a
migracao de aplicacoes JBoss EAP 7.1 para EAP 7.4, com Java 8 e `javax.*`.
Seu objetivo e ajudar o desenvolvedor a transformar diagnosticos em corretivas
delimitadas, implementadas e verificadas, com apoio do GitHub Copilot e controle
humano sobre o escopo e o resultado.

Aqui, **harness** significa o conjunto de mecanismos que prepara, orienta e
verifica esse trabalho: scripts, tarefas da IDE, configuracao, instrucoes,
prompts e registros de evidencias. Ele conecta analise MTA, build Maven, SonarQube,
planejamento com Copilot/DevSquad e operacao do JBoss. Com isso, voce pode investigar
achados, escolher prioridades, preparar um lote de correcao, implementar o escopo
autorizado, testar e depurar a aplicacao e retomar a migracao preservando o historico.

O ciclo combina **preparacao do contexto (feedforward)** — codigo, diagnostico,
restricoes, decisoes e criterios de aceite — com **retorno das verificacoes
(feedback)** — diff, build, testes, analises e resultados no servidor. Esses
resultados orientam o retrabalho ou a proxima decisao. O valor buscado e reduzir
perda de contexto e repeticao de trabalho, mantendo visivel o que foi verificado
e o que continua pendente.

**Voce escolhe o projeto, define prioridades, revisa o plano, autoriza a
implementacao e aceita o resultado.** O Copilot apoia o raciocinio e a execucao
autorizada; as ferramentas produzem evidencias. Preparar um prompt nao executa
o agente, e sucesso de build ou reducao de achados nao concede aceite.
Branches e integracoes continuam sob responsabilidade da equipe.

A [estrategia do harness](../estrategia/estrategia-harness_.md) explica a evolucao
pretendida para outras tecnologias, IDEs e etapas do ciclo de desenvolvimento.
Quarkus, IntelliJ, novos adaptadores de IA e um nucleo compartilhado sao propostas
de evolucao. O fluxo disponivel neste guia e o de migracao JBoss no VS Code.

## Como usar este guia

**Este guia explica o percurso completo:** o papel de cada ferramenta, quando
ela participa e qual resultado permite continuar. Cada etapa destaca o guia
que a detalha. Configuracao, menus, comandos e alternativas de execucao ficam
nesse guia especifico. Nao e necessario ler todos os guias antes de comecar.

| Sua situacao | Por onde entrar |
| --- | --- |
| Primeiro uso, ensaio ou configuracao de outra maquina | [1. Preparar o ambiente](#1-preparar-o-ambiente). Os dois exemplos acompanham o clone. |
| Workspace pronto e projeto a analisar | [2. Escolher o projeto e fazer o build](#2-escolher-o-projeto-e-fazer-o-build). |
| MTA ja executado ou pasta completa recebida de um colega | [3. Obter ou reutilizar o diagnostico MTA](#3-obter-ou-reutilizar-o-diagnostico-mta); nao repetir a analise apenas para planejar. |
| Retomada de um projeto ou consulta das pendencias | [4. Conferir o registro e escolher prioridades](#4-conferir-o-registro-e-escolher-prioridades); localizar o plano existente antes de gerar outro. |
| Proposta pronta, ainda em revisao ou sem GO | [5. Planejar e revisar um lote](#5-planejar-e-revisar-um-lote). |
| Plano revisado com GO, inclusive implementacao parcial | [6. Implementar o lote autorizado](#6-implementar-o-lote-autorizado). |
| Corretiva pronta para conferir | [7. Verificar e aceitar o resultado](#7-verificar-e-aceitar-o-resultado). |
| Novo MTA, novas evidencias ou lote aceito para continuar | [8. Reconciliar e decidir a continuidade](#8-reconciliar-e-decidir-a-continuidade). |
| Somente uma operacao, como iniciar JBoss, depurar ou analisar Sonar | [Guias de ferramentas](#guias-de-ferramentas); essas operacoes tambem podem ser usadas separadamente. |
| Preciso de ajuda para identificar a etapa e o proximo passo | [Orientacao com Codex ou GitHub Copilot](tools/workspace.md#orientacao-com-codex-ou-github-copilot); a skill consulta o contexto existente e indica o guia da etapa. |

O fluxo pertence ao projeto e ao codigo em analise. O workspace pode reunir
varias aplicacoes; as evidencias e decisoes continuam vinculadas a cada uma.
O guia de workspace explica a configuracao do ambiente e a selecao dos projetos.

## Roteiro: onde estou e o que escolho

O ciclo principal e **preparar ambiente e diagnostico → escolher prioridades →
planejar → revisar e dar GO → implementar → verificar e aceitar → reconciliar**.
Em cada frente, trabalhe um lote consistente por vez. Ajustes e novas evidencias
podem levar de volta a uma etapa anterior; os caminhos especificos ficam nos
guias de detalhe.

### 1. Preparar o ambiente

O **workspace** reune o harness, os projetos da aplicacao e as configuracoes
locais da IDE e das ferramentas. E o ponto de entrada para ensaiar com os exemplos
ou trabalhar com repositorios corporativos.

**Guia da etapa:** [Workspace: configuracao e uso](tools/workspace.md).
Ele cobre primeira configuracao, projetos, ajustes da IDE e dados locais, e
encaminha a configuracao propria de cada ferramenta.

**Resultado esperado e continuidade:** ambiente pronto e projeto identificado.
A etapa 2 prepara uma nova analise; quem ja possui MTA pertinente pode seguir
para a etapa 3.

### 2. Escolher o projeto e fazer o build

O **build da aplicacao** usa Maven para compilar, executar os testes definidos
no projeto e produzir o artefato. Ha dois caminhos disponiveis: a Run Task do
harness e o Maven pelo painel da IDE ou terminal. Eles atendem a mesma etapa,
com configuracoes e registros de execucao distintos.

**Guia da etapa:** [Build da aplicacao: Run Task e Maven](tools/maven.md).
Ele explica os dois caminhos, a selecao de projeto/modulo, as fases e a leitura
do resultado.

**Resultado esperado e continuidade:** build bem-sucedido e conhecimento dos
testes efetivamente executados. Isso prepara a analise da etapa 3; falhas de
compilacao/testes precisam de tratamento. Build e MTA sao operacoes separadas.

### 3. Obter ou reutilizar o diagnostico MTA

O **MTA** identifica pontos de atencao para a migracao e preserva o codigo
analisado e seus resultados. Uma rodada existente ou recebida pode alimentar
o planejamento, desde que sua aplicabilidade ao codigo local seja conferida.

**Guias da etapa:** [MTA: configuracao e uso](tools/mta.md), para produzir e
consultar o diagnostico; [Planejamento: MTA existente ou recebido](tools/planejamento-migracao.md#compartilhar-o-mta-e-planejar-em-outra-maquina),
para reutilizar uma rodada. Esse segundo caminho dispensa repetir a analise
apenas para preparar uma proposta.

**Resultado esperado e continuidade:** diagnostico identificado, com divergencias
e limites conhecidos. A etapa 4 transforma esses achados em prioridades.

### 4. Conferir o registro e escolher prioridades

A ferramenta de **planejamento e reconciliacao** oferece um indice da situacao
dos projetos e um registro de migracao por projeto. O indice resume evidencias
e pendencias; o registro preserva decisoes, prioridades e andamento.
O desenvolvedor decide o que merece analise agora e o que fica para depois.

**Guia da etapa:** [Planejamento: indice, registro e caminhos de retomada](tools/planejamento-migracao.md#qual-caminho-seguir).
Ele explica como consultar o historico, interpretar os estados e atualizar o registro.

**Resultado esperado e continuidade:** prioridades e pendencias compreendidas.
A etapa 5 produz ou revisa a proposta. Um lote existente com GO valido para
o escopo atual pode retomar a etapa 6.

### 5. Planejar e revisar um lote

O **planejamento com Copilot/DevSquad** relaciona diagnostico, codigo, prioridades
e evidencias para propor um lote consistente de corretivas. Plano e to-do
delimitam escopo, cobertura, verificacoes e criterios de aceite.
A revisao humana decide se a proposta esta pronta para receber GO.

**Guia da etapa:** [Planejamento: proposta, revisao e GO](tools/planejamento-migracao.md#planejar-lotes-de-correcao-com-copilot).
Ele detalha o preparo do contexto, a execucao do prompt e a revisao do mesmo lote.

**Resultado esperado e continuidade:** proposta revisada e decisao humana
registrada. O GO autoriza a etapa 6; sem ele, a proposta permanece em revisao.
Preparar documentos nao autoriza corretivas, e GO nao e aceite do resultado.

### 6. Implementar o lote autorizado

O **preparo da implementacao** vincula o plano aprovado a um prompt de execucao.
A implementacao assistida aplica o escopo autorizado e registra o realizado
e o pendente. Preparar esse prompt e executa-lo sao momentos distintos.
A escolha da base de codigo e a gestao Git pertencem ao desenvolvedor.

**Guias da etapa:** [Planejamento: implementacao e retomada](tools/planejamento-migracao.md#preparar-implementacao-do-lote)
e [Git: base de trabalho e branches](diagnostico-branches-git-tortoisegit.md#branches-e-conferencia-git).
Eles detalham o inicio e a retomada parcial do lote, preservando o trabalho existente.

**Resultado esperado e continuidade:** corretiva delimitada e andamento
rastreavel para as verificacoes da etapa 7. Mudanca de escopo volta a revisao
da etapa 5.

### 7. Verificar e aceitar o resultado

As ferramentas fornecem evidencias complementares: **Maven** verifica build e
testes; **JBoss** permite observar e depurar a aplicacao no servidor; **SonarQube**
avalia qualidade; **MTA** apoia a comparacao do diagnostico de migracao.
A revisao humana considera essas evidencias, o diff e os criterios do lote.

**Guias da etapa:** [Build e testes](tools/maven.md),
[JBoss: execucao e debug](tools/jboss.md), [SonarQube: qualidade e comparacao](tools/sonar.md)
e [MTA: nova analise](tools/mta.md).
O [guia de planejamento](tools/planejamento-migracao.md#da-proposta-revisada-a-execucao-e-ao-aceite)
explica o registro das evidencias, pendencias e aceite.

**Resultado esperado e continuidade:** resultado avaliado e decisao de aceite
ou retrabalho. Sonar e novo MTA sao checklist nao bloqueante; ausencia permanece
pendente, enquanto falhas de compilacao/testes continuam sendo falhas.
Retrabalho permanece no lote atual. A integracao do lote aceito segue o
[fluxo Git da equipe](diagnostico-branches-git-tortoisegit.md), com revalidacao
do codigo integrado; a etapa 8 trata da continuidade.

### 8. Reconciliar e decidir a continuidade

A **reconciliacao** relaciona novo MTA, evidencias e resultados de integracao
com o registro e o plano existentes. Ela preserva decisoes e historico e torna
visiveis a cobertura parcial, os conflitos e o trabalho ainda pendente.

**Guia da etapa:** [Planejamento: reconciliacao e atualizacao do plano](tools/planejamento-migracao.md#reconciliar-status-antes-de-atualizar-o-plano).
Ele distingue atualizar somente o registro, revisar o lote atual e preparar
a continuidade apos aceite.

**Resultado esperado e continuidade:** situacao atual consistente e proxima
decisao clara. A revisao do mesmo lote volta a etapa 5; o proximo lote retorna
a triagem da etapa 4 depois do aceite do atual e do pedido de continuidade.
Sem novo MTA comparavel, a comparacao permanece pendente.

Um lote aceito ou um achado ausente no relatorio nao conclui a migracao inteira.
O encerramento exige reconciliar o escopo acumulado com a rodada final comparavel,
concluir suas verificacoes e obter aceite humano final, com as pendencias resolvidas.

## Orientar o proximo passo

Para retomar o trabalho, sozinho ou com apoio de um agente, confirme quatro pontos:
**projeto e caminho dos fontes; objetivo atual; evidencias e pendencias; lote,
GO e aceite existentes**. Use a [entrada correspondente](#como-usar-este-guia)
e escolha a operacao que produz a proxima saida esperada do roteiro.

Os guias abaixo sao a referencia operacional para desenvolvedor e agentes:
descrevem entradas, comandos, resultados e limites de cada ferramenta. O agente
pode usa-los para recomendar o proximo passo com base nas evidencias disponiveis;
a decisao humana continua nos pontos do fluxo. Um conjunto de agentes orientadores
e uma evolucao pretendida, sem orquestracao autonoma implementada por estes guias.

## Guias de ferramentas

Esta tabela e uma consulta por ferramenta. O [roteiro acima](#roteiro-onde-estou-e-o-que-escolho)
explica quando cada uma participa; os guias vinculados concentram a configuracao
e os procedimentos. Cada guia tambem indica o retorno ao fluxo principal.

| Guia | Quando abrir | Configuracao e operacao |
| --- | --- | --- |
| <a id="comecar-na-maquina-de-trabalho"></a><a id="extensoes-java-no-vs-code"></a><a id="escolher-o-projeto-em-cada-tarefa"></a><a id="ensaiar-e-depois-usar-os-projetos-corporativos"></a><a id="configuracao-da-maquina"></a><a id="duas-opcoes-para-configurar-o-workspace"></a><a id="opcao-a-editar-o-json-local-e-gerar-novamente"></a><a id="opcao-b-configurar-o-workspace-manualmente"></a><a id="limpar-execucoes-locais"></a><a id="pastas-locais-e-backups-temporarios"></a><a id="tarefa-e-script-correspondente"></a>[Workspace](tools/workspace.md) | Preparar ou ajustar o ambiente; selecionar projetos. | [Configuracao](tools/workspace.md#configuracao), [uso](tools/workspace.md#uso), [limpeza e dados locais](tools/workspace.md#limpar-execucoes-locais), [catalogo de tarefas](tools/workspace.md#tarefa-e-script-correspondente). |
| <a id="build-maven-da-aplicacao-com-java-8"></a><a id="usar-a-extensao-maven-padrao-do-vs-code"></a>[Build da aplicacao](tools/maven.md) | Executar a Run Task de build ou usar Maven direto; etapas 2 e 7. | [Configuracao](tools/maven.md#configuracao), [Run Task do harness](tools/maven.md#opcao-a-run-task-do-harness), [painel Maven/terminal](tools/maven.md#opcao-b-maven-direto). |
| <a id="analise-e-resultados"></a><a id="acompanhar-a-analise-mta"></a>[MTA](tools/mta.md) | Produzir diagnostico ou reanalisar; etapas 3 e 7. | [Instalacao/perfil](tools/mta.md#configuracao), [analise, relatorios e logs](tools/mta.md#uso). |
| <a id="qual-caminho-seguir"></a><a id="planejar-lotes-de-correcao-com-copilot"></a><a id="registro-de-migracao-por-projeto"></a><a id="reconstruir-a-pasta-usando-um-mta-existente"></a><a id="preparar-e-executar-o-prompt"></a><a id="como-se-forma-o-lote-o-planmd-e-o-todomd"></a><a id="localizar-documentos-e-identificar-o-historico"></a><a id="compartilhar-o-mta-e-planejar-em-outra-maquina"></a><a id="revisao-manual-do-plano-e-do-to-do"></a><a id="revisar-um-lote-com-evidencias-complementares"></a><a id="da-proposta-revisada-a-execucao-e-ao-aceite"></a><a id="preparar-implementacao-do-lote"></a><a id="indice-da-situacao-dos-projetos"></a>[Planejamento e reconciliacao](tools/planejamento-migracao.md) | Triar, planejar, implementar e reconciliar; etapas 4 a 8. | [Copilot e entradas](tools/planejamento-migracao.md#configuracao), [caminhos conforme a situacao](tools/planejamento-migracao.md#qual-caminho-seguir). |
| <a id="jboss-local-releases-e-debug-java"></a><a id="console-administrativa-e-usuario-de-gerenciamento"></a><a id="testar-o-controle-do-servidor-sem-deploy"></a><a id="deploy-e-rollback"></a><a id="debug-java-no-vs-code"></a>[JBoss](tools/jboss.md) | Executar e depurar a aplicacao; etapas 2 e 7. | [Instalacoes, portas, XML e usuarios](tools/jboss.md#configuracao), [servidor/deploy/rollback](tools/jboss.md#uso), [debug e Hot Code Replace](tools/jboss.md#debug-java-no-vs-code). |
| <a id="sonarqube-local-ou-corporativo"></a><a id="configurar-uma-vez-por-maquina"></a><a id="executar-e-consultar"></a><a id="criterios-do-harness-e-comparacao"></a><a id="usar-como-evidencia-na-revisao"></a><a id="origem-e-verificacao"></a>[SonarQube](tools/sonar.md) | Coletar e comparar qualidade; etapas 2 e 7. | [Servidor/scanner](tools/sonar.md#configuracao), [analise e evidencias](tools/sonar.md#uso). |
| <a id="branches-e-conferencia-git"></a><a id="estrutura-de-branches-ao-longo-da-migracao"></a><a id="matriz-de-origem-e-destino-por-fase"></a><a id="branch-exclusiva-para-alterar-o-harness"></a><a id="historico-e-transicao"></a>[Git e integracao](diagnostico-branches-git-tortoisegit.md) | Escolher base, revisar branches e integrar pelo fluxo da equipe; etapas 6 a 8. | [Branches e responsabilidades](diagnostico-branches-git-tortoisegit.md#branches-e-conferencia-git), [comparacao Git/TortoiseGit](diagnostico-branches-git-tortoisegit.md#escolher-a-direcao-da-comparacao). |

<a id="o-que-acompanha-o-clone"></a><a id="documentacao-e-evolucao-do-harness"></a><a id="testar-os-scripts-do-harness"></a>Para alterar a propria ferramenta, siga [Manutencao do harness](manutencao-harness.md).
Esse trabalho tem plano e testes separados das corretivas da aplicacao.
A [estrategia](../estrategia/estrategia-harness_.md) apresenta a direcao de evolucao;
o [contrato de planejamento](../especificacoes/planejamento-copilot.md) define as
regras vigentes para o trabalho assistido.
