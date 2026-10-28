# To-do do agente: evolucao do harness

## Execucao manual e fases do lote — 28/10/2026

- [x] Conferir base/estado local e criar branch em worktree separado.
- [x] Confirmar execucao manual por padrao com o desenvolvedor.
- [x] Alinhar prompts de planejamento/implementacao, modelos, contrato e guia.
- [x] Conferir parada/retomada, cobertura por fases, escolhas existentes e GO unico.
- [x] Validar preparadores/modelos/links em copia isolada e revisar diff.
- [x] Registrar resultados e limites da entrega.

PASS na versao final pelo tests/Invoke-HarnessTests.ps1, em copia temporaria
descartada: Test-OutputTemplates, Test-Implementation, Test-CurrentPromptLinks e
Test-IssuePlanning. Conferem consumo/vinculos dos modelos, preparo, preservacao
de notas/decisoes, repeticao e links; nao comprovam obediencia do modelo.

Revisao documental: nove secoes do plano e cinco do to-do, placeholders e blocos
de fontes preservados. Conferidos os casos de uma issue, varias sem escolha,
escolha existente, fases com verificacao pendente, excecao humana e GO vigente.
Removida a proibicao ambigua de outra fase, mantendo a restricao a outros lotes
e fluxos de publicacao. Corpo comum explicito para Copilot/Codex/Claude Code.
git diff --check sem erros; nao foram alterados scripts nem criados testes textuais.

Ao concluir o preparo, o checkout habitual permaneceu em main limpo e as
alteracoes ficaram locais no worktree
C:/Users/edoar/AppData/Local/Temp/harness-modo-execucao-e-fases, branch
harness/modo-execucao-e-fases, sem commit/push/integracao. Prompts e documentos
reais de migracao nao foram regravados. Adocao em lote existente exige revisao
do plano/to-do e novo preparo do prompt de implementacao, conforme o guia.
Ensaio nativo no cliente permanece nao realizado; nenhum build/deploy/teste
de aplicacao, release ou operacao de servidor foi executado nesta entrega.

Retomada de publicacao — 28/10/2026:

- [x] Receber autorizacao para commit/push e pedido de parar antes do PR.
- [x] Conferir branch, HEAD, origem, oito arquivos do escopo e diff sem erros.
- [ ] Retomar em 29/10/2026 a abertura/revisao do PR para main com o desenvolvedor.
- [ ] Ao final, conferir integracao e trabalho pendente antes de limpar o worktree.

Commit/push desta retomada usam a branch acima. Preservar o worktree e parar
apos o push; PR, integracao e limpeza nao pertencem a esta etapa. As quatro
suites ja passaram na versao final dos prompts; nesta retomada foram alteradas
somente estas notas de acompanhamento, sem necessidade de repetir as suites.

## Publicacao das issues e evidencias — 24/10/2026

- [x] Receber autorizacao explicita para commit, push e PR para main.
- [x] Revisar o conjunto final e confirmar a base igual a origin/main (2467171).
- [x] Conferir 14 Markdown: 281 links locais, 154 ancoras, quatro exemplos PowerShell e 21 linhas de tabelas; parser de sete arquivos PowerShell, frontmatter e diff sem erros.

As 13 suites isoladas descritas abaixo passaram. A publicacao inclui somente
harness, testes e documentacao; o checkout operacional e os dados reais foram
preservados. Ensaio nativo dos prompts e da rede corporativa continua pendente.
Os registros anteriores de ausencia de commit/push/PR sao historicos.

## Criar ou revisar qualquer issue com evidencias — complemento de 24/10/2026

- [x] Confirmar projeto na tarefa e problema/ID/evidencias no chat.
- [x] Incluir evidencias ja presentes na sessao e logs de execucao do servidor.
- [x] Generalizar prompt/guia para MTA e manual preservando identidade e decisoes.
- [x] Preparar tarefa unica e prompt por projeto, preservando notas e contexto.
- [x] Validar CLI/cancelamento/preservacao e documentacao em copia isolada.
- [x] Registrar em AGENTS a regra para Copilot, Codex e Claude Code; orientar execucao do mesmo contrato e limites por cliente.

- [x] Acrescentar exemplos ao orientador por situacao e entrada/passagem por cliente no roteiro de issues; referenciar pelo guia de orientacao.
- [x] Conferir links/ancoras, exemplos e diff deste complemento documental.
Complemento documental PASS: quatro Markdown, 70 links locais, 48 ancoras,
um exemplo PowerShell e 21 linhas de tabelas conferidos; diff --check sem erros.
Exemplos revisados contra a skill comum e a passagem de cliente existente.
Sem mudanca de runtime ou nova execucao de suites; nenhum prompt de migracao
foi executado. Alteracoes permanecem na mesma branch, sem commit/push/PR.

- [x] Tornar explicita a busca previa e a confirmacao humana de issues possivelmente correspondentes.
- [x] Reforcar modelos, sustentacao dos fatos e roteiro de pesquisa oficial sem acesso web.
- [x] Perguntar antes de acionar auditor independente, preservando decisao e limites por cliente.
- [x] Conferir contrato, exemplos, navegacao e diff deste complemento.

Complemento de qualidade PASS: oito Markdown, 89 links locais, 30 ancoras,
quatro exemplos PowerShell e 21 linhas de tabelas; frontmatter, parser e
diff --check sem erros. Revisao de coerencia contra modelos de ficha/evidencias,
API de cadastro e fluxo de publicacao: busca previa com confirmacao de candidatas,
proposta revisavel, pergunta sobre auditoria, resultado/recusa explicitos e
reconferencia de correspondencias se o registro mudar antes de publicar.

Confirmacao humana final: perguntar se deseja auditoria independente; ela nao e
automatica. Nao houve delegacao/auditoria independente nesta manutencao nem
cadastro real. Alteracoes desta etapa sao instrucionais/documentais, sem mudanca
de runtime; suites anteriores nao demonstram obediencia do modelo. Ensaio nativo
permanece na maquina de trabalho. Sem commit/push/PR.

RED: Test-IssuePrompt falhou pela ausencia da entrada preparar-issue. Apos a
implementacao, PASS para projeto selecionado, links/contexto reais, heranca do
cabecalho, preservacao das notas/registro/Source, repeticao sem mudanca e falha
sem escrita para registro ausente/invalido. Test-TaskInputs passou com 27 tarefas
e cancelamento da nova entrada preservando os arquivos da fixture.

Apos ampliar para os tres clientes: Test-IssuePrompt, Test-CurrentPromptLinks e
Test-ClaudeAdapter PASS pelo runner isolado. Somados aos resultados da primeira
etapa, 13 suites distintas aprovadas. Revisao final: 13 Markdown, 234 links locais,
115 ancoras, quatro exemplos PowerShell e 21 linhas de tabelas; parser de sete
arquivos PowerShell, frontmatter e diff --check sem erros.

Guia unico issues-e-evidencias e prompt criar-revisar-issue substituem os nomes
manuais propostos antes da publicacao. Tarefa prepara/abre o arquivo; usuario
executa no chat atual para reaproveitar evidencias acessiveis. Regra e exemplos
explicitam origem, recorte preservado de log mutavel, hipoteses e pesquisa oficial
pendente, sem inferir historico compartilhado, ferramentas, GO ou acesso de rede.

Limite: nao houve execucao nativa desses prompts no Copilot/Codex/Claude Code nem
ensaio de rede corporativa. Suites provam preparo/contratos/adaptadores, nao
comportamento de modelos. Checkout operacional continua main limpa; somente o
worktree harness/indice-e-investigacao-manual foi alterado. Sem commit/push/PR.

## Issues manuais: indice e investigacao — 24/10/2026

- [x] Fechar investigacao/cadastro, pesquisa pendente e formato do indice com o desenvolvedor.
- [x] Conferir main limpa e criar branch em worktree separado.
- [x] Reproduzir ausencia das manuais no indice geral com teste isolado.
- [x] Incluir resumo/categoria/totais manuais e cobertura de registros, preservando MTA.
- [x] Criar prompt de investigacao/cadastro/revisao com fontes oficiais e lacunas.
- [x] Orientar navegacao, pesquisa web e continuidade para priorizar/planejar.
- [x] Validar suites, navegacao, parser e diff; registrar resultados e limites.

Validacao concluida em copia temporaria pelo runner oficial: 11 suites PASS:
ProjectIndexManual, ProjectIndexSummary, ProjectIndexAvailability, ProjectIndex,
ProjectDocuments, ProjectNavigation, ManualPrioritization, IssuePlanning,
PlanningEvidence, CurrentPromptLinks e ClaudeAdapter.

RED inicial reproduziu a ausencia das manuais no resumo. Novo caso tambem
reproduziu a ambiguidade de uma categoria MTA chamada manual; exibicao agora
distingue manual (MTA), mantendo as identidades e contagens de origem.
Teste de preservacao considera a normalizacao de quebras de linha que ja ocorre
ao atualizar as linhas MTA; texto humano, identidade, ficha e vinculos preservados.
Mutacao temporaria da condicao de cobertura parcial foi rejeitada pelo teste;
gerador restaurado e teste novamente PASS, sem backup ou dados operacionais.

Conferencia documental: 12 Markdown, 226 links locais, 113 ancoras, tres exemplos
PowerShell e 16 linhas de tabelas do novo roteiro, sem erros. Parser dos quatro
arquivos PowerShell, frontmatter do prompt e git diff --check aprovados.
Revisao de contagens/origens, cobertura parcial, publicacao protegida e permissao
web concluida. Sem novas dependencias ou mudanca das ferramentas dos helpers.

Limites: nao houve execucao nativa do prompt no Copilot nem validacao de acesso
web na rede corporativa. O roteiro inclui o teste de ferramenta/URL para aquela
maquina. As oito manuais mencionadas pelo desenvolvedor sao relato da maquina
corporativa, nao uma contagem verificada neste checkout. Trabalho permanece
no worktree separado; checkout operacional e seus dados nao foram regenerados.
Sem commit, push ou PR desta entrega.

## Passo a passo do compartilhamento documental — 24/10/2026

- [x] Conferir raiz, main, HEAD, worktrees e estado limpo; criar branch de documentacao.
- [x] Criar roteiro completo com prompts e verificacoes para todos os projetos locais.
- [x] Explicitar selecao documental e continuidade, sem copiar codigo/POM/MTA.
- [x] Ligar README, guia do desenvolvedor e guias de compartilhamento ao roteiro.
- [x] Conferir links/ancoras, estrutura, exemplos PowerShell e diff; registrar resultados.

Verificacao documental: sete Markdown conferidos, 203 links locais e 116 ancoras
validos; quatro blocos PowerShell analisados pelo parser sem executar comandos.
Cercas balanceadas, 19 linhas de tabelas do novo roteiro com colunas coerentes,
whitespace/newline do arquivo novo e git diff --check sem erros. Revisao do
conteudo contra os guias de selecao/copia/reconciliacao, preservando escopo,
GO/aceite, cobertura e limites do ensaio. Suites de runtime nao executadas:
alteracao exclusivamente documental. Sem commit/push nesta entrega.

Confirmacoes humanas desta conversa: priorizacao funcionando e fichas conferidas
na maquina corporativa. Considerar esses relatos na retomada, sem inferir
ensaio de compartilhamento, contagem examinada ou validacao de outros clientes.
O roteiro permanece para adocao/ensaio pela equipe; nenhum dado real copiado
ou publicado no simtr-doc por esta entrega documental.

Complemento de orientacao pelos helpers:

- [x] Conferir que Codex, Copilot e Claude usam skill/papeis comuns.
- [x] Vincular explicitamente compartilhamento documental na skill e nos papeis de preparo/reconciliacao; alinhar descricao do ponteiro Claude.
- [x] Acrescentar exemplo de pedido no guia de orientacao, preservando o papel leitor.
- [x] Conferir frontmatter/referencias da skill, navegacao e adaptadores em copia isolada; registrar resultados e limites.

PASS: Test-ClaudeAdapter.ps1 pelo runner oficial em copia temporaria descartada,
conferindo os adaptadores Codex/Copilot/Claude, ponteiros comuns, identidade e
perfil leitor. Navegacao ampliada: 11 Markdown, 297 links locais, 175 ancoras,
quatro exemplos PowerShell analisados e nenhuma falha. Revisao das instrucoes
preserva escopo, cliente e passagem ao executor, sem duplicar o procedimento.
quick_validate.py nao iniciou por falta de PyYAML (ModuleNotFoundError: yaml);
nenhuma dependencia instalada. O frontmatter foi conferido pela suite existente.
Sem ensaio nativo nesta entrega; disponibilidade na maquina corporativa depende
de receber a versao atualizada. Novo guia adicionado ao Git para integrar a copia
de teste, sem commit/push.

Em 24/10/2026, o desenvolvedor autorizou commit, push e PR desta entrega para
main. Os registros de ausencia de publicacao acima descrevem a preparacao e
validacao anteriores a essa autorizacao. Nenhum dado real do simtr-doc integra
esta entrega.

## Settings locais do VS Code — 23/10/2026

- [x] Conferir main, estado local e ausencia de rastreamento de settings.json.
- [x] Criar branch de manutencao e adicionar regra restrita ao arquivo local.
- [x] Conferir regra de ignore, preservacao de tasks/launch e diff final.

git check-ignore confirmou a regra especifica para settings.json; tasks.json,
launch.json e extensions.json permanecem fora dela. Diff sem erros. Nenhum
arquivo local de configuracao foi alterado ou removido. Commit e push
autorizados pelo usuario em 23/10/2026.

## Consolidacao para publicacao — 23/10/2026

- [x] Registrar autorizacao de commit/push e manter compartilhamento como proposta.
- [x] Preservar as entregas em commits separados.
- [x] Reunir as duas frentes no checkout habitual, preservando ambos os registros.
- [x] Alinhar o guia de compartilhamento com pastas legiveis e categoria manual.
- [x] Conferir conjunto documental e preparar branch consolidada para o push autorizado.

Conferencia conjunta: 16 Markdowns, 287 links locais, 148 ancoras e 19
exemplos PowerShell aprovados. Diff sem erros e sem dados da .harness.
Scripts, testes, instrucoes e contratos funcionais identicos ao commit f7ea32c,
validado nas 14 suites; consolidacao alterou somente documentacao/acompanhamento.
O guia permanece proposta e a revisao/ensaio da equipe continua pendente.

## Fichas legiveis e issues manuais — 23/10/2026

- [x] Preservar proposta documental em outra branch e criar checkout separado.
- [x] Registrar mudanca de escopo: todas as fichas, reinicio da priorizacao permitido.
- [x] Escrever teste inicial; RED por ausencia do cadastro integrado.
- [x] Implementar nomes legiveis, limites de caminho e recusa de colisoes.
- [x] Cadastrar manual e atualizar registro/total sem inventar analise.
- [x] Permitir priorizacao manual com base fixa e evidencia explicita.
- [x] Reparar somente ficha manual antiga, com previa e preservacao.
- [x] Atualizar contratos, guias e orientacao ao Copilot; fornecer prompt de reparo.
- [x] Validar regressao e revisar diff; registrar resultados e limites.

Validacao final: 14 suites passaram pelo runner isolado: ReadableIssueFolders,
ManualPrioritization, FunctionalLinks, ProjectStorage, ProjectDocuments,
ProjectNavigation, MigrationRegister, PrioritizationProgress, IssuePlanning,
PlanningEvidence, PlanningPortable, ReconciliationSources,
ReconciliationPrioritization e ReconciliationLegacyFolders.

Testes reproduziram antes da corretiva a ausencia do cadastro integrado, a
aceitacao de identidade divergente no reparo, a mistura de fontes MTA/manual
e a reconciliacao de ficha legada recebida sem equivalente local. Os casos
passaram depois dos ajustes. Cobertura inclui repeticao do cadastro, preservacao
de escolhas/analise/log, destino divergente ou vazio, colisoes, tamanho do caminho,
base fixa no Continue e inclusao de novos achados no Recreate.

Revisao independente concluida sem novos achados impeditivos. Conferidos 11
Markdowns, 112 links locais, 40 ancoras e quatro exemplos PowerShell; parser dos
16 arquivos PowerShell alterados e diff --check HEAD sem erros.

Limites: nomes legiveis sao usados nas novas fichas; fichas antigas continuam
aceitas pelos leitores. Reparo pontual manual tem previa e aplicacao explicita;
nao houve conversao geral nem alteracao de dados da maquina da empresa. Recriar
a priorizacao preserva fichas e notas existentes. O clique na previa Markdown
do editor corporativo precisa ser validado naquela maquina; testes de caminhos
nao substituem essa verificacao. Prompt de reparo consta no guia de planejamento.
Commit e push autorizados em 23/10 para consolidacao. Proposta documental segue preservada
em harness/compartilhamento-documental-git, no checkout original.

## Compartilhamento documental por Git — 23/10/2026

- [x] Conferir main limpa e criar branch de documentacao; identificar pedido como evolucao do harness.
- [x] Conferir contrato de copia/reconciliacao e distinguir contexto de continuidade de dados operacionais.
- [x] Escrever lista de inclusao/exclusao e procedimento do coordenador/devs, com continuidade do trabalho atual.
- [x] Preparar modelo de .gitignore limitado a .harness-jbosseap7.4, sem alterar o Git operacional.
- [x] Ligar a proposta pelo README, guia do desenvolvedor e compartilhamento existente.
- [x] Validar selecao com Git em pasta sintetica, exemplos PowerShell, links e diff; registrar limites.

Entregues doc/guias/tools/compartilhamento-documental-git.md e
doc/modelos/compartilhamento-documental.gitignore. Proposta para revisao, sem
alterar o contrato/runtime: caminhos compartilhados, exclusoes, anexos explicitos,
base inicial, contribuicoes separadas, reconciliacao no harness habitual e
publicacao do consolidado. Inclui pedido de inventario somente leitura para
conferir os arquivos reais na maquina de trabalho antes da copia.

Validacao em repositorios Git sinteticos no TEMP: 50 verificacoes PASS, com
13 arquivos documentais staged apos liberar um anexo; WAR, configuracao local,
operacoes, temporarios e prompts/indices derivados excluidos. Regras restritas
a subpasta, preservando outras areas do repositorio; sparse-checkout de pasta
nova e existente conferido. Fixtures removidas com alvo absoluto verificado.
Nao houve acesso a remoto nem ensaio de clone parcial via servidor.

Sete Markdown conferidos: 197 links locais, 116 ancoras e 15 blocos PowerShell
analisados pelo parser, sem executar os exemplos. Revisao confrontou o recorte
com o leitor de contribuicoes, os contratos correntes e a documentacao Git.
Suites do runtime nao repetidas: alteracao exclusivamente documental/modelo.

Limites: nenhum dado real exportado, nenhuma configuracao local modificada e
nenhum acesso ao simtr-doc da empresa. A lista real de arquivos, permissao de
publicacao e ensaio entre dois devs dependem da revisao na maquina de trabalho.
Versoes antigas ja sobrescritas nao sao recuperadas por este procedimento.
Commit e push autorizados em 23/10 para consolidar a documentacao com as fichas. A adocao do compartilhamento e o envio de dados ao simtr-doc continuam pendentes de revisao.

## Links de fichas e registro de issues manuais — 23/10/2026

- [x] Conferir raiz/main/HEAD e criar branch de manutencao preservando o checkout.
- [x] Localizar a codificacao de pastas, a interpretacao dos links e os contratos de preservacao/retomada.
- [x] Reproduzir a navegacao quebrada em teste isolado antes de corrigir o gerador.
- [x] Corrigir geracao/leitura de URI sem mudar IDs, nomes de pastas ou limites de acesso.
- [x] Orientar Copilot/executor e helpers sobre registro manual, evidencias e conferência dos links.
- [x] Documentar prompt de reparo e instrucao de retomada da fatia parcial na maquina de trabalho.
- [x] Validar regressao pertinente, navegacao documental e revisao final; registrar limites.
- [x] Registrar autorizacao de 23/10 para commit, push da branch e PR para main.

RED confirmado antes da corretiva: cinco casos de navegacao falharam no PS7,
incluindo a pasta literal `%44...` interpretada como `D...`. A correcao constroi
URI file explicita a partir dos segmentos literais; preserva o escape ao gerar
links relativos e ao resolver/remapear referencias no planejamento/reconciliacao.

GREEN pelo runner isolado: FunctionalLinks, ProjectStorage, ProjectDocuments,
ProjectNavigation, MigrationRegister, PrioritizationProgress, PlanningEvidence,
PlanningPortable, ReconciliationSources e ReconciliationPrioritization.
FunctionalLinks cobre sete casos de URI em PS5.1 e PS7, mais tres consumidores
em PS5.1. Uma primeira execucao GREEN falhou pelo import de HarnessPlanning no
filho PS7; o teste foi ajustado ao runtime suportado e repetido com PASS, sem
relaxar o guard de producao. As demais nove suites passaram na mesma rodada.

Revisao independente sem achados impeditivos. Conferidos dez Markdown alterados,
113 links locais, 40 ancoras e tres blocos PowerShell (parser, sem executar os
exemplos), sem falhas. Diff e diff staged sem erros de whitespace. Frontmatter
da skill preservado; somente a orientacao do corpo foi ampliada.

Limites: a ficha e o log informados estao na outra maquina e nao foram alterados
nem validados aqui. Atualizar o harness naquela maquina e executar o prompt de
reparo sao passos posteriores; indice preserva observacoes humanas e nao repara
seus links automaticamente. Nenhum registro real, MTA, servidor ou configuracao
privada foi alterado. Commit, push da branch e PR desta corretiva autorizados
em 23/10; o merge e a atualizacao/reparo na maquina de trabalho ficam posteriores.

## Fork do harness na conta da empresa — 23/10/2026

- [x] Conferir main/estado local e criar branch propria para a documentacao.
- [x] Escrever guia generico de fork, remotos e atualizacao por gh/Git, com rota sem gh: navegador para criar o fork e Git para as etapas locais.
- [x] Ligar README, guia do desenvolvedor, workspace, orientacao e fontes comuns dos helpers.
- [x] Conferir navegacao, exemplos, limites do orientador e diff; registrar evidencias e limites.
- [x] Registrar autorizacao de 23/10 para commit, push da branch e PR para main desta entrega documental.

Validacao documental em 23/10: nove arquivos revisados, 358 links locais e
248 ancoras conferidos, 12 blocos PowerShell analisados pelo parser sem executar
os comandos, nenhuma falha. Frontmatter da skill preservado; adaptadores de
Codex, Copilot e Claude ja consultam a skill comum e o papel de preparo.
Exemplos confrontados com documentacao oficial Git/GitHub/gh; diff sem erros
de whitespace. O quick_validate.py da skill-creator nao iniciou a validacao
por ausencia de PyYAML (ModuleNotFoundError: yaml); nenhuma dependencia instalada.
Suites funcionais nao executadas nesta entrega exclusivamente documental.
O procedimento documentado nao foi executado: nenhum fork criado e nenhuma
autenticacao ou URL de remoto alterada. A publicacao autorizada se limita a
esta branch do harness; analise DES e ensaio operacional permanecem pendentes.

Encerramento de 22/10/2026 a pedido do desenvolvedor: ver
[checkpoint e sequencia de retomada](../doc/estrategia-migracao-ambientes-jboss-eap-7.4/checkpoint-correcoes-preparo-des-2026-10-22.md).

- [x] Preservar correcoes, evidencias e pendencias em checkpoint, sem publicar.
- [x] Em 23/10, concluir conferencia documental/diff depois do checkpoint:
  67 links locais e 26 ancoras conferidos nos oito Markdown alterados/novos;
  diff --check sem erros. Suites anteriores preservadas, sem repeticao.

## Correcoes autorizadas e validacao DES — estado atual, 23/10/2026

- [x] Retomar branch de evolucao e preservar os documentos pendentes; nenhum dado real copiado para o Git.
- [x] Corrigir descritores module:1.9 e comprovar carregamento real de main/slot personalizado, com Java 8/JBoss Modules locais e classe sintetica, sem boot do EAP.
- [x] Implementar files opcional no preparo: origens privadas, destinos em standalone/configuration, hashes no consolidado, identicos preservados, divergencias recusadas.
- [x] Implementar Restart/RestartDebug no gerenciador e tarefa unica, lock continuo, stop confirmado antes do start, modo e selecao Todos.
- [x] Implementar script/tarefa de logs: EAP ou Todos, tail, UTF-8 incremental, arquivo ausente/rotacao/truncamento e leitura sem bloquear escrita.
- [x] Documentar operacao e roteiro explicito de atualizacao da maquina de trabalho, preservando configuracao privada e Git como origem dos scripts.
- [x] Consolidar pendencias DES em pasta explicita; imagem/pipeline/OKD classificados como responsabilidade externa, sem bloquear nossas correcoes.
- [x] Concluir regressao final, navegacao e revisao do diff; resultados abaixo.
- [x] Registrar autorizacao de 23/10 para commit, push e PR das quatro entregas; analise de DES permanece para etapa posterior.
- [x] PR #45 integrado pelo desenvolvedor em `bb9ebe8`; main alinhada e branch local/remota removida em 23/10.
- [ ] Na maquina de trabalho, atualizar via Git apos integracao, conferir modulos/arquivos privados e ensaiar restart/logs; validacao da aplicacao ainda depende do desenvolvedor.
- [ ] Retomar posteriormente a analise de desenvolvimento/DES e resolver os itens no registro especifico, indicando por item a atualizacao local necessaria. Template privado permanece inalterado; esta pendencia nao condiciona a publicacao das quatro entregas.

Os registros historicos abaixo descrevem as etapas anteriores a esta autorizacao.
Demandas antes adiadas de arquivos externos/restart/logs agora estao implementadas
nesta branch; o estado de entrega/validacao corrente e o deste bloco.

Verificacao final PASS pelo runner isolado: Eap74Preparation, JbossRestart,
JbossLogs, JbossRuntime, JbossAllServers, Jboss e TaskInputs. Preparo e leitor de
logs tambem exercitados em PS7 pela respectiva suite. Rollback de falha no
segundo arquivo externo restaurou servidor/consolidado sinteticos. Restart
preservou o lock, interrompeu antes do start em falha de stop e registrou fase
de falha; entradas reais das tasks cancelaram antes de operar servidores.

Teste adicional Eap74ModuleLoading passou com JDK 8 e JBoss Modules da instalacao
local: main e slot legado carregaram classe sintetica. O erro antigo foi
reproduzido antes da correcao. Ferramentas reais somente lidas/executadas no
checkout temporario; nenhum JBoss iniciado, parado, reiniciado ou alterado.
Sintaxe de 15 arquivos PowerShell, JSONs alterados, 53 links locais e diff --check
passaram. Revisao final do diff sem bloqueadores identificados. Testes de
processo/rede sao simulados; uso real de restart/logs e da aplicacao na maquina
de trabalho continua no ensaio do desenvolvedor. Ctrl+C durante acompanhamento
real nao foi ensaiado pelo agente. Sem commit/push, sem atualizacao da pasta privada.

## Execucao da priorizacao sem retorno ao preparo - 21/10/2026

- [x] Conferir relato, fontes e papel indevidamente assumido pelo executor.
- [x] Isolar evolucao em branch derivada de main, preservando checkout operacional.
- [x] Delimitar skill de orientacao e preservar helpers leitores nos tres clientes.
- [x] Explicitar devsquad orquestrador, delegacao e consolidacao da fatia.
- [x] Alinhar execucao por cliente, using-agent-skills e fallback Agent.
- [x] Validar geracao/links/adaptadores, revisar diff e registrar limites.
- [ ] Ensaio nativo na maquina de trabalho: selecao, delegacao e 9/44 examinadas.

Verificacao: cinco suites pelo runner isolado em Windows PowerShell 5.1 passaram:
ClaudeAdapter, Prioritization, CurrentPromptLinks, OutputTemplates e
PrioritizationProgress. Conferidos 113 links locais nos Markdown alterados, sem
destinos ausentes; `git diff --check` passou. Revisao independente nao encontrou
bloqueadores. Nenhum dado real, perfil externo ou checkout operacional alterado.

Limites: essas suites verificam contratos/geracao e preservacao, nao comportamento
do modelo ou seletor Copilot. `agent: devsquad` ja existia antes deste ajuste.
O cliente precisa reconhecer o perfil e executar o prompt nativamente em Local;
o relato "Copilot e com Agent" nao identifica definitivamente o tipo de sessao.
Sem devsquad, fallback documentado para Agent e manual: nao ha lista condicional
no campo agent. Nos demais clientes, skill ausente nao impede o agente principal.
O validador `quick_validate.py` da skill-creator foi tentado, mas nao executou por
ausencia de PyYAML; frontmatter/ponteiro/perfis foram conferidos por ClaudeAdapter
e revisao. Nao instalar dependencias globais apenas para essa validacao.

Para adotar o texto na maquina de trabalho apos integrar/atualizar o harness,
retomar o preparo pendente (`-Mode Continue`, sem percentual) regrava o prompt
e conserva base/quota. Nao recriar nem progredir para outra fatia por causa do loop.
Commit, push e abertura de PR para main autorizados pelo desenvolvedor em
21/10/2026. Ensaio nativo permanece pendente; integracao segue pela revisao da PR.

## Nome curto para priorizacao - 21/10/2026

- [x] Reproduzir o limite do escopo automatico com 14 projetos sinteticos.
- [x] Usar priorizacao como padrao, mantendo participantes no contexto.
- [x] Preservar continuidade antiga, Scope explicito, categorias e contribuicoes humanas.
- [x] Provar recusa de ambiguidade e de troca silenciosa dos participantes.
- [x] Atualizar ADR/guia e concluir regressao isolada e revisao.

Validacao: Test-PrioritizationDefaultScope reproduziu antes da correcao o mesmo
erro de chave funcional acima de 160 caracteres. Depois, passaram pelo runner
isolado as 8 suites: PrioritizationDefaultScope, Prioritization,
PrioritizationCategories, PrioritizationProgress, PrioritizationIndex,
PrioritizationIncidents, ReconciliationPrioritization e OutputTemplates.
Teste novo escrito por agente independente; revisao separada nao encontrou
bloqueadores. Mutacao que permitia escolher silenciosamente entre dois escopos
foi detectada pelo teste de ambiguidade; fonte restaurada byte a byte.
Nenhum dado real alterado. Desenvolvedor autorizou commit, push e abertura da PR
para main em 21/10/2026; alinhamento da maquina de trabalho segue apos o merge.

Conferencia complementar solicitada: indice geral, indice de categoria/escopo,
templates e consumidores das etapas seguintes compativeis. Passaram mais 5
suites isoladas: IssuePlanning, CurrentPromptLinks, ProjectNavigation,
IssueQueries e SprintSources (13 suites no total). Planejamento reutiliza a
ficha por projeto/categoria/issue; consultas/reconciliacao leem Scope do contexto.
Auditoria independente de orientacoes confirmou skill, helpers Codex/Copilot,
guias e prompts sem dependencia do antigo nome concatenado. Templates continuam
obrigatorios e fornecem os indices, ranking, fichas e orientacao para o registro.
Nenhum ajuste adicional de runtime ou instrucao foi necessario nesta conferencia.

## Totais do indice por categoria - 21/10/2026

- [x] Reproduzir ausencia de totais por categoria no resumo.
- [x] Atualizar template, gerador e guias com totais de issues/ocorrencias por categoria.
- [x] Conferir soma entre projetos, cobertura parcial, categorias livres e casos sem dados.
- [x] Executar regressao isolada e revisar diff, preservacao e limites.
- [x] Restaurar orientacao padrao do registro e preenchimento da ficha sem duplicar MTA.
- [x] Excluir paginas da aplicacao em input/ da descoberta de relatorios da rodada.
- [x] Tolerar bloqueio transitorio de diretorios na limpeza, preservando erros persistentes.
- [x] Conferir diferenca com o indice legado: 42 + 2 mandatory do siric = 44; total 92 + 5 = 97 issues, 2981 + 532 = 3513 ocorrencias.
- [x] Manter MTA valido nos totais quando atualizacao local falhar, com aviso separado e recuperacao protegida.

Validacao: 22 suites passaram por Invoke-HarnessTests.ps1 em copias temporarias
isoladas (TEMP/TMP=C:\Temp), incluindo bloqueios reais Win32 transitorios e
persistentes. Cobertura: ProjectMta, ProjectIndex, ProjectNavigation,
ProjectIndexSummary, ProjectIndexExternalMta, ProjectIndexAvailability,
ProjectDocuments, OutputTemplates, ProjectRecovery, ProjectPublicationLocks,
ProjectPublication, ProjectConcurrency, ProjectReadOnly, ProjectStorage,
ProjectTemporaryRemoval, ReconciliationSources, ReconciliationConflicts,
Reconciliation, Planning, PlanningReassociation, PrioritizationIndex e
PrioritizationProgress (prefixo Test-, extensao .ps1).

Duas mutacoes detectadas: excluir MTA apos falha local derruba a verificacao
de 5 issues/532 ocorrencias; comparar orientacao gerada como conteudo humano
derruba equivalencia da reconciliacao. Codigo restaurado byte a byte depois
dos experimentos. Conferidas 111 referencias locais nos documentos alterados;
git diff --check sem erros. Revisao independente estatica encerrada sem
Critical/Required pendentes, incluindo journal real e troca concorrente da
associacao protegida ate a publicacao dos documentos.

Limites: os relatorios reais e o processo que bloqueou a pasta na maquina de
trabalho nao estao acessiveis nesta sessao. Os totais 97/3513 e mandatory 44/351
foram conferidos nos dois indices enviados pelo desenvolvedor. Nenhum MTA,
registro ou codigo de aplicacao real foi alterado. Corretiva na branch
harness/indice-totais-categorias. O desenvolvedor autorizou commit, push e PR
para main apos a validacao; merge permanece uma etapa posterior.

## Auditoria independente do checkpoint - 21/10/2026

- [x] Revisar documentacao, orientadores e runtime com tres revisores independentes.
- [x] Executar 12 suites pelo runner isolado e uma mutacao detectada.
- [x] Conferir 610 referencias e 415 ancoras locais; registrar destinos antigos ausentes.
- [x] Consolidar [parecer e reproducoes](auditoria-indice-mta-externo.md).
- [x] A1/P2: corrigir publicacao parcial de MTA se a associacao falhar.
- [x] A2/P2: preservar diagnostico interno utilizavel no indice com raiz externa vazia.
- [x] A3/P3: explicitar excecao MTA no principio de armazenamento do system design.

Auditoria concluida no checkpoint 87a8725. Doze suites passaram, mas os
dois cenarios P2 nao estavam cobertos e foram reproduzidos separadamente.
Orientadores alinhados no recorte estatico; consumo real dos modelos por agente
e descoberta/delegacao nativa permanecem limites. Apenas registros em tasks
alterados na auditoria inicial. Corretivas concluidas na etapa registrada abaixo; PR nao aberta.

## Tabela resumida e template do indice - 21/10/2026

- [x] Reproduzir ausencia do resumo e implementar tabela Markdown com links.
- [x] Consumir templates versionados; inventariar produtores e vincular modelos aos prompts.
- [x] Validar contagens, lacunas, links e preservacao em copia isolada.
- [x] Concluir revisao da retirada e preparar descricao da PR para main, sem merge.



**Verificacao em 21/10/2026:** 19 suites distintas aprovadas via runner isolado,
Windows PowerShell 5.1 e TMP/TEMP em C:\Temp somente no processo:
ProjectIndexSummary, ProjectIndexExternalMta, ProjectIndex, OutputTemplates,
ProjectDocuments, PrioritizationIndex, CurrentPromptLinks, Planning,
EvidenceFolder, Reconciliation, ReconciliationSources, ReconciliationPrioritization,
ReconciliationConflicts, PlanningPortable, PlanningReassociation, PlanningEvidence,
ProjectNavigation, PrioritizationProgress e PrioritizationCategories.

O teste do resumo primeiro comprovou a ausencia da tabela. O teste dos modelos
primeiro comprovou a ausencia de template corrente; depois passou comprovando
consumo real por alteracao do modelo apenas na copia de teste. Durante a ampliacao,
um erro de sintaxe na propria suite OutputTemplates foi corrigido e sua execucao
isolada passou; as outras 12 suites daquela rodada passaram. A mutacao que ocultava
a ultima tentativa falha foi detectada, com restauracao byte a byte.
Conferidos 23 scripts por parser e 557 destinos locais e 346 ancoras Markdown; diff --check passou.
Busca de dependencias ativas do conversor retirado nao encontrou consumidores.
Nao houve execucao de agente de migracao real, MTA real, conversao ou alteracao
dos dados operacionais. Inventario em [doc/modelos](../doc/modelos/README.md).

**Entrega:** [descricao da PR](pr-indice-mta-externo.md) preparada para main;
revisao humana, abertura da PR e integracao permanecem etapas separadas.

**Roteiro na maquina de trabalho:** atualizar esta branch, conferir mta.runsPath
externo e executar Workspace: atualizar indice dos projetos. Abrir a tabela em
.harness/indices/projetos.md; para os modelos dos agentes, preparar novamente a
etapa desejada e abrir os links em Modelos de saida obrigatorios. No resultado de
priorizacao, seguir Proximo passo para escolher ID/recorte em migracao.md. Nao
limpar nem converter o estado real para ensaiar esta entrega.


## Retirada da conversao legada - 20/10/2026

- [x] Retirar utilitario tools/transicao, fixture e suites exclusivas.
- [x] Alinhar guias, contratos, skill e papeis de orientacao ao inicio corrente.
- [x] Verificar dependencias e validar fluxo corrente sem o conversor.
- [x] Retirada em commit separado 4f67c95; revisao final retomada em 21/10.
- [ ] Revisao humana e integracao.

**Checkpoint de 20/10/2026, pausa pedida pelo desenvolvedor:** trabalho na branch
`harness/indice-mta-externo`, worktree `C:\Temp\harness-indice-mta`.
MTA externo e associacao automatica registrados em `b20af92`; retirada do
conversor registrada no commit seguinte. Main nao foi alterada nem houve merge.
Depois da retirada, passaram em copia isolada: Test-ProjectIndexExternalMta,
Test-Planning, Test-PrioritizationIndex, Test-Cleanup e Test-ClaudeAdapter.
Busca por dependencias do utilitario fora do historico nao encontrou consumidores;
git diff --check passou. Nenhum dado real ou relatorio externo foi alterado.

**Retomar em 21/10:** conferir branch/HEAD/estado neste worktree; concluir revisao
da retirada e dos textos, incluindo links e coerencia do desenho; avaliar apenas
verificacoes adicionais justificadas; preparar PR para main e entregar o roteiro
de uso na maquina de trabalho. Nao executar conversao nem restaurar automaticamente
o ZIP antigo. O checkout original `C:\desenvolvimento\repositorio\jboss-mta-harness`
permanece na branch `harness/conversao-log-etapas` com alteracoes locais de logging
anteriores, preservadas e fora desta entrega; nao trocar/resetar esse checkout.

As entregas de conversao abaixo sao historicas; o utilitario deixa de integrar
o produto por escolha do desenvolvedor. Nenhum dado real foi apagado por esta
mudanca. Relatorios MTA externos nao recuperam decisoes/fichas humanas antigas.

## Indice com MTA externo configurado - 20/10/2026

- [x] Reproduzir raiz externa ignorada com projetos de nomes distintos do artifactId.
- [x] Associar pasta Source, selecionar ultimo diagnostico e preservar escolhas.
- [x] Exigir saida externa nas novas analises e preservar ultimo diagnostico em falha.
- [x] Cobrir falhas, ambiguidade, leitura externa e concorrencia; alinhar guias/skill/papeis.
- [x] Executar suites isoladas e revisao independente; preparar entrega.
- [ ] Revisao humana e integracao.

**Verificacao:** 19 suites passaram em copia isolada com Windows PowerShell 5.1:
Mta, ProjectIndexExternalMta, ProjectIndex, ProjectMta, ProjectDocuments,
ProjectNavigation, ProjectPublication, ProjectRecovery, ProjectConcurrency,
ProjectReadOnly, ProjectStorage, ProjectTemporaryRemoval, MtaActive, MtaLog,
ExternalMtaDiscovery, SonarConfig, Workspace, McpRoots e PrioritizationIndex.
Testes novos primeiro reproduziram raiz ignorada, saida interna e perda da
associacao anterior em falha; depois passaram. Revisao independente apontou a
associacao antecipada e limpeza incompleta; ambos corrigidos e aprovados na
revisao final. Teste adicional de nome Source reservado reproduziu acesso a area
transitoria e passou apos recusa explicita. Nenhum MTA real executado.
Test-ClaudeAdapter tambem passou apos alinhamento da skill e dos papeis comuns
dos agentes Codex/Copilot/Claude Code.

## Conversao de preparo sem proposta - 20/10/2026

[Escopo](plan.md#conversao-de-preparo-sem-proposta---20102026).

- [x] Reproduzir preparo sem proposta em fixture isolada.
- [x] Preservar contexto/prompt/fichas sem criar plano/tarefas; expor disponibilidade.
- [x] Alinhar indice e validacao; recusar pares incompletos e preservar lacunas.
- [x] Executar regressao, mutacao e revisao; documentar resultados.
- [x] Preparar script de acompanhamento individual para entrega no chat e no guia.
- [ ] Revisao humana e integracao na principal.

**Verificacao em 20/10/2026:** 30 suites `Test-Conversion*.ps1` passaram em
Windows PowerShell 5.1 via `Invoke-HarnessTests.ps1`, com TMP/TEMP em `C:\Temp`
somente no processo e copia descartada pelo runner. O novo teste primeiro
reproduziu a exigencia indevida de plano ausente e depois a incorporacao indevida
de proposta local anterior a conversao. Ambos foram corrigidos.
Cobertos preparo EVIDENCIAS/MTA, preservacao de fichas/anexos/decisoes/originais,
pares incompletos, diretorios indevidos, links ausentes e repeticao equivalente.
Mutacao da condicao do par foi detectada; arquivo restaurado byte a byte antes
da regressao completa. Revisao independente sem achados restantes.

O script sequencial no guia teve sintaxe conferida e ensaio com dubles em memoria:
conversao e validacao com estados separados, falha ao aplicar, validacao mesmo
com previa indisponivel, pausas e inventario completo de falhas de POM antes
de qualquer aplicacao. Nenhum projeto real foi convertido ou limpo.

## Conversao de associacao legada sem plano - 20/10/2026

[Escopo](plan.md#conversao-de-associacao-legada-sem-plano---20102026).

- [x] Reproduzir o caso informado em fixture isolada antes da corretiva.
- [x] Validar associacao legada e distinguir ausencia de plano de vinculo quebrado.
- [x] Conferir preservacao, repeticao e descarte explicito, incluindo outro projeto com plano.
- [x] Reproduzir e corrigir classificacao duplicada das copias MTA declaradas nos anexos.
- [x] Bloquear publicacao com origem corrompida; nao declarar ausencia de plano por falha de leitura.
- [x] Executar suites de conversao, revisar diff e documentar o resultado.
- [x] Revisao humana e integracao na principal (PR #38, merge `dd38d6e`, confirmado pelo desenvolvedor).

**Verificacao em 20/10/2026:** 29 suites `Test-Conversion*.ps1` aprovadas em
Windows PowerShell 5.1 pelo runner isolado. Na rodada final, 26 passaram e tres
atingiram o limite de caminho na raiz temporaria padrao; essas tres
(`EvidenceScopes`, `MultiProject`, `SharedEvidence`) passaram ao repetir com
TMP e TEMP apontando para `C:\Temp` apenas no processo. Uma primeira rodada
tambem detectou a mudanca da mensagem de ambiguidade; a mensagem compativel
foi preservada e `ParticipantMta` passou na rodada final.

As novas fixtures falharam antes das respectivas correcoes. Mutacao que
desabilitou a validacao de Source foi detectada pelo teste e revertida.
Revisao independente da associacao, falhas de leitura, publicacao/descarte
e copias MTA terminou sem achados pendentes; `git diff --check` passou.
Nenhum dado real de aplicacao foi convertido ou removido. Na maquina de
trabalho, a origem declarada no contexto SIMTR-api e as escolhas de
planejamento/diagnosticos/priorizacao/sprints ainda precisam ser conferidas.

## Consistencia documental e agentes principais - 19/10/2026

[Escopo e decisao](plan.md#consistencia-documental-e-agentes-principais---19102026).

- [x] Corrigir os seis achados e os ajustes editoriais nos tres documentos.
- [x] Alinhar Codex e GitHub Copilot como principais; Claude Code secundario.
- [x] Conferir links/ancoras, sintaxe/preservacao dos exemplos JSON, diagrama e diff.
- [ ] Revisao humana e integracao na principal.

**Verificacao em 19/10/2026:** 106 referencias locais nos tres documentos e 27
referencias recebidas de outros Markdown versionados, sem arquivos/ancoras
ausentes. Links dos dois arquivos tasks tambem conferidos. Cinco blocos JSON
validos e identicos a baseline `6566bb8`; cercas balanceadas e fluxo Mermaid
revisado por leitura. Catalogo: 47 URLs externas distintas, sendo sete do
repositorio e 40 fontes oficiais/primarias. `git diff --check`: PASS.

**Limites:** testes de runtime nao executados nesta alteracao documental.
Validacao JSON Schema original mantida como historica; nao repetida porque
`jsonschema` nao esta instalado. Ajuda local `codex exec --help` bloqueada pela
politica de scripts; interface conferida na fonte oficial O13, sem alterar a
politica da maquina ou declarar o piloto homologado.

## Adaptador Claude Code - 17/10/2026

[Escopo](plan.md#adaptador-claude-code---17102026).

- [x] Seis helpers em `.claude/agents/` com perfil leitor e delegacao restrita ao condutor.
- [x] Ponteiro `.claude/skills/orientar-migracao/SKILL.md` (descoberta confirmada nesta sessao do Claude Code).
- [x] Skill comum e papeis com encaminhamento Claude Code.
- [x] Configurador MCP grava `.mcp.json`; `.gitignore` e copias de teste atualizados.
- [x] Guias, README e documento 1 atualizados.
- [x] `Test-ClaudeAdapter`, `Test-CurrentPromptLinks`, `Test-Implementation`, `Test-TestIsolation`: PASS. Node: 10/10 em checkout separado.
- [ ] `integration.test.mjs` nao executado: caminho do checkout temporario excedeu o limite do harness; repetir em raiz curta.
- [ ] Ensaio nativo: `claude --agent migracao_helper`, delegacao a um helper, `/orientar-migracao` e consultas MCP aprovadas em `/mcp`.
- [ ] Revisao humana e aceite.

## Estado JBoss corrente - 17/10/2026

[Escopo e decisoes](plan.md#estado-jboss-corrente---17102026).

- [x] Servidor em `.harness/servidores/<eap>/` com somente a ultima operacao e o ultimo start.
- [x] Deploy substitui o WAR (gerenciado, externo ou nao gerenciado) e guarda somente `atual/jboss/<eap>/ultimo-deploy.json`.
- [x] Retirar rollback: Run Task, acao, `-ReleaseId`, funcoes e testes.
- [x] Indice do projeto e `operacao.json` mostram o ultimo deploy.
- [x] Guias, cheat sheet, AGENTS.md e documentos do Engineering Harness atualizados.
- [x] Suites JBoss, Run Tasks, navegacao, armazenamento e build: PASS (runner isolado; ensaio real opt-in nao executado).
- [ ] Ensaio real na maquina de trabalho: start, deploy v1/v2/v1 com HTTP e stop (`Test-JbossReal.ps1 -RunReal`).
- [x] Pasta legada `.harness/jboss/` removida nesta maquina a pedido do desenvolvedor (recibos, logs e 4 copias de WAR; 298 KB).
- [ ] Revisao humana e aceite.

## Consolidacao documental do Engineering Harness - 17/10/2026

[Escopo e decisoes](plan.md#consolidacao-documental-do-engineering-harness---17102026).

- [x] Criar `doc/contratos/` (fluxo-migracao, planejamento-sprints com regras de cronograma, consultas-issues).
- [x] Criar `doc/engineering-harness/` com os tres documentos e imagens (imagem com nome em hash renomeada).
- [x] Corrigir a situacao real da `main` (`5c8d582`) e incorporar decisoes de 17/10/2026.
- [x] Incorporar o material reaproveitado (fundamentos, horizontes, catalogo no anexo A, estudo Java).
- [x] Mover cheat sheet para `doc/guias/` e conversor para `tools/transicao/README.md`.
- [x] Remover `doc/arquitetura/`, `doc/especificacoes/`, `doc/features/` e `doc/estrategia/`.
- [x] Reapontar consumidores: AGENTS.md, instrucoes, skill, prompts, scripts, testes, guias, ADRs e README.
- [x] Verificar links: 60 arquivos, somente os dois links-modelo do template de sprints (destino gerado).
- [x] Suites afetadas pelo runner isolado: 11 PASS; `Test-IssueQueries.ps1` FAIL, falha preexistente na `main` `5c8d582` (conferida em worktree separado).
- [ ] Revisao humana e aceite da consolidacao.
- [ ] Corretiva separada: `Test-IssueQueries.ps1` falha em "Truncamento silencioso ou ausente." (mensagem de incidente esperada com 128 caracteres e um campo truncado).
- [x] Incremento seguinte: armazenamento JBoss por projeto/servidor (ver secao "Estado JBoss corrente").


## Corretivas verificadas da auditoria - 21/10/2026

- [x] Reproduzir A1/A2 antes das correcoes e verificar GREEN.
- [x] Preservar preparo quando falhar tambem a retirada; provar falha antes e sucesso depois.
- [x] Ampliar verificacoes estruturais dos adaptadores Codex/Copilot.
- [x] Corrigir principio documental, exemplo runsPath e referencias locais indisponiveis.
- [x] Aprovar 13 suites isoladas, mutacao detectada, navegacao e revisao independente.

Resultado e limites em [corretivas do parecer](auditoria-indice-mta-externo.md#corretivas-verificadas---21102026).
Os ensaios nativos dos agentes permanecem fora desta verificacao; nenhuma
migracao real, abertura de PR ou integracao foi executada.

## Retomada do preparo EAP 7.4 local - 21/10/2026

- [x] Auditar fontes externas 7.1/7.4, mapeamento, documentacao e instalacao local, somente leitura.
- [x] Salvar [achados e sequencia de retomada](../doc/estrategia-migracao-ambientes-jboss-eap-7.4/auditoria-preparo-local-eap74-2026-10-21.md), sem valores sensiveis.
- [x] Retomar pelo checkpoint apos autorizacao; scripts/documentacao entregues em 22/10, ensaios operacionais separados abaixo.

Este registro apenas localiza a auditoria; nao concede GO de implementacao,
deploy ou aceite funcional.

## Preparo reutilizavel EAP 7.4 - 22/10/2026

- [x] Auditar por perguntas e fechar o escopo com o desenvolvedor.
- [x] Criar testes de preservacao, repeticao, renderizacao e falhas em copia isolada.
- [x] Implementar scripts genericos, modelos e inicializacao com JVM compartilhada.
- [x] Publicar roteiro manual e patch parametrizado; apontar guia/helper para ele.
- [x] Adaptar entradas e instrucoes da pasta externa, preservando valores reais.
- [x] Validar, revisar e registrar limites; sem aplicar ao JBoss operacional.

Entrega e evidencias no [checkpoint atualizado](../doc/estrategia-migracao-ambientes-jboss-eap-7.4/auditoria-preparo-local-eap74-2026-10-21.md#retomada-autorizada-e-entrega-de-preparo--22102026).
PASS: preparo (PowerShell 5.1/7), runtime JBoss, referencias de prompts e adapter
Claude, sempre via executor isolado. Sem commit/push; novos arquivos no indice
para integrar a copia de teste. Dados privados conferidos em memoria, sem saida
de valores. Permanecem para uso operacional: os 16 itens de DES, procedencia de
JARs, aplicacao do consolidado/alinhamento local do harness e validacao funcional.

## Pacote da maquina de trabalho — 22/10/2026

- [x] Padronizar a pasta externa com entradas relativas e scripts diretos do harness.
- [x] Retirar encaminhadores; preservar referencias antigas fora da pasta de execucao.
- [x] Incluir guia completo especifico SIMTR e exemplo ficticio separado dos valores ativos.
- [x] Obter/conferir os dois JARs e deixar modo local por padrao, mantendo alternativa Maven.
- [x] Atualizar ZIP externo para extrair somente jboss-eap7.4-configuracao/ em C:\desenvolvimento; verificar os 18 arquivos por SHA256.
- [x] Manter seis scripts em conferencia-harness/ como copia opcional removivel; executar somente a versao do repositorio alinhada pelo Git.
- [x] Atualizar guia privado e roteiro generico; preservar as nove entradas privadas byte a byte.
- [x] Validar em memoria caminhos/XML/LogSql/JVM e hashes apos a reorganizacao.

Pendencias operacionais permanecem: disponibilizar esta versao do harness pelo
Git (alteracoes ainda sem commit/push), conferir os 16 itens com DES, JDK/patch
instalados no trabalho, aplicar o consolidado parado, alinhar o harness e testar
a aplicacao. Nenhum dado privado foi levado ao Git.

## Roteiro DES e impacto no local — 22/10/2026

O PR #44 ja foi integrado; pendencia de publicacao Git do preparo anterior resolvida.

- [x] Identificar as fontes distintas: template DES no inventario, XML local e candidato 7.4.
- [x] Comparar propriedades/tokens e recursos; registrar alteracoes sem necessidade comprovada.
- [x] Confirmar com o desenvolvedor Azure DevOps/OKD, template unico e preservacao do comportamento 7.1.
- [x] Gravar roteiro generico e pasta privada DES com auditoria e passos da primeira aplicacao.
- [x] Conferir links e preservacao das entradas existentes.
- [ ] Confirmar revisao implantada, contrato da imagem/esteira e decisoes que afetam o template compartilhado.
- [ ] Auditar a segunda aplicacao quando seu material for fornecido.

Esta frente prepara documentacao; nao concede aceite operacional nem executa
alteracoes na configuracao da aplicacao, no JBoss local ou em DES.

Entregues: [roteiro generico DES](../doc/estrategia-migracao-ambientes-jboss-eap-7.4/jboss-eap7.4-configuracao/des.md)
e pasta privada jboss-eap7.4-configuracao-des/ com README e auditoria/roteiro
da primeira aplicacao. Dez achados e matriz complementar de defaults; driver,
keepalive/timeout EJB, caches, seguranca e contrato da imagem exigem revisao
antes de aplicar o template compartilhado. Nenhum XML ou valor foi alterado.
PASS: cinco documentos, 31 links locais, fences/tabela e separacao de dados
privados; 24 arquivos preexistentes preservados por comparacao SHA256 na
criacao da pasta; git diff --check. Suites nao executadas: alteracoes documentais.
Alteracoes desta frente locais, sem commit/push.

### Acompanhamento da maquina de trabalho — 22/10/2026

- [x] Registrar a escolha de prosseguir com o ensaio local da versao entregue, antes da resolucao individual dos achados DES.
- [x] Registrar confirmacao do desenvolvedor: maquina de trabalho alinhada com a main remota.
- [ ] Receber ajustes privados realizados e resultados do ensaio; hash exato ainda nao informado, sem bloquear o ensaio.
- [ ] Para cada achado resolvido, registrar no roteiro privado necessidade (ou dispensa) de atualizacao local, arquivos, origem, passos e testes.
- [ ] Acompanhar aplicacao/verificacao de cada atualizacao necessaria na maquina de trabalho, somente com evidencia ou relato do desenvolvedor.

Nenhuma nova versao dos scripts foi publicada nesta frente; preservar os
preenchimentos feitos na outra maquina e acompanhar o ajuste manual dos
descritores registrado abaixo.

- [x] Diagnosticar e reproduzir isoladamente a falha da linha 100 com dados sinteticos: chave de propriedade sem igual; nenhum defeito de parser demonstrado.
- [x] Identificar fuso escrito com acentos; orientar America/Sao_Paulo literal.
- [x] Conferir as saidas enviadas da maquina de trabalho: propriedade antes sem igual agora renderizada e fuso America/Sao_Paulo sem acentos no BAT.
- [x] Receber resultado do primeiro boot: EAP 7.4.11/CP11, XML/JVM/portas esperados; inicializacao com erros no modulo Oracle, sem aceite funcional.
- [x] Confirmar segundo boot sem ERROR no log recebido (17:16): WFLYSRV0025, driver Oracle 19.22/ojdbc8 iniciado e datasource vinculado; HTTP 8180/gerenciamento 10090.
- [x] Receber resultado de simtrPU:test-connection-in-pool: outcome=success e result=[true], executado pelo desenvolvedor no EAP 7.4/gerenciamento 10090; conexao confirmada, sem comprovar consultas da aplicacao.
- [x] Documentar teste de conexao apos start no guia JBoss e referenciar no roteiro de preparo EAP 7.4: comando, ajustes por ambiente, resultado esperado e limites antes do deploy.
- [x] Explicar os avisos da CLI e ajustar comando do guia para informar bin/jboss-cli.xml por jboss.cli.config; aviso de cliente nao modular pode permanecer sem invalidar o teste.
- [ ] Conferir versao/base de fusos do JDK informado como 8u112 antes do aceite dos testes de datas; nao e a causa da falha de propriedades.

Os ajustes de propriedade/fuso sao nas entradas privadas da maquina de trabalho
e dispensam nova versao dos scripts. O defeito posterior no descritor exige
correcao do gerador. Segundo boot comprovado pelo log; verificacao funcional
permanece pendente.

- [x] Revisar XML/BAT/manifesto enviados: referencias Oracle/Jasper, logSql e JVM coerentes com as entradas informadas; sem salvar valores reais.
- [x] Comparar SHA256 dos dois JARs do pacote de origem com os hashes informados no manifesto: coincidentes. Bytes remotos e module.xml remoto nao examinados diretamente.
- [ ] Validar funcoes que dependem dos tres valores ainda ficticios e do keystore (segredo MTR preenchido, validade pendente); conferir relatorios/fontes apos deploy.

### Arquivos externos no preparo — discutir junto com os outros ajustes

- [x] Registrar localizacao do keystore no servidor legado e escolha de copia manual neste ensaio; arquivo nao recebido nem copiado pelo agente.
- [ ] Confirmar copia manual no alvo 7.4.11 e verificacao das entradas; nao presumir sucesso apenas pela localizacao.
- [ ] Revisar proposta generica de pasta privada arquivos/ e mapeamento opcional de uma ou mais origens para destinos relativos a eapHome.
- [ ] Apos fechar a proposta, implementar consolidacao/aplicacao com preservacao de arquivos identicos, interrupcao em divergencias e verificacoes isoladas de falha/publicacao.
- [ ] Atualizar guia/helper e registrar exatamente o que atualizar via Git e na pasta privada da maquina de trabalho.

Estado: demanda futura, sem implementacao autorizada nesta etapa. O script
atual nao copia arquivos externos adicionais; manter a copia manual fora do
consolidado, preservando seu manifesto.

### Acompanhar logs JBoss — junto com os proximos ajustes

- [x] Registrar pedido de PS1 no harness e tarefa unica `Servidor: acompanhar logs`, com EAP 7.1, EAP 7.4 ou Todos; implementacao adiada pelo desenvolvedor.
- [ ] Implementar script reutilizando configuracao e selecao de servidores; exibir ultimas linhas, novas mensagens e origem quando acompanhar ambos.
- [ ] Tratar log ausente/rotacao e Ctrl+C, encerrando apenas os leitores e preservando servidores e arquivos.
- [ ] Integrar a tarefa ao gerador de workspace e ao guia JBoss; verificar em copia isolada e indicar como atualizar o harness/workspace na maquina de trabalho.

Estado: somente demanda registrada; o acompanhamento atual continua pelo
comando PowerShell informado no chat. Retomar junto com arquivos externos e
demais ajustes pendentes do preparo/operacao JBoss.

### Defeito no descritor dos modulos — primeiro boot da maquina de trabalho

- [x] Identificar geracao invalida de schema module:1.9 com slot="main"; module.xml remoto enviado confirma o defeito.
- [x] Reproduzir falha de parsing com slot e aceitacao do descritor sem slot no JBoss Modules local, em TEMP isolado, sem iniciar/alterar servidor.
- [x] Confirmar carregamento Oracle e boot normal no segundo log da maquina de trabalho; erro de modulo do primeiro boot ausente.
- [ ] Confirmar descritor Jasper corrigido e uso das fontes apos deploy; conexao Oracle ja confirmada no acompanhamento acima.
- [ ] Corrigir gerador e acrescentar verificacao com carregador real, cobrindo main e slot personalizado; testes anteriores nao detectaram incompatibilidade de schema.
- [ ] Definir atualizacao via Git e tratamento explicito dos modulos/consolidado existentes, preservando a interrupcao em divergencias inesperadas.
- [ ] Conferir DNS SMTP separadamente e manter pendente a validacao do keystore da aplicacao; aviso de application.keystore nao se refere ao JCEKS.

Estado: segundo boot normal comprovado pelo log recebido; correcao dos scripts
e verificacoes da aplicacao pendentes; teste de conexao confirmado com success/true.
Nao reexecutar o preparo atual apos ajuste manual dos descritores: geracao antiga
permanece invalida e a comparacao com o servidor pode interromper por divergencia.

### Reiniciar JBoss — junto com os proximos ajustes

- [x] Registrar necessidade de Restart e conferir comportamento atual: Start mantem instancia RUNNING; reinicio manual exige Parar e depois Iniciar.
- [x] Documentar reinicio manual, efeito sobre aplicacoes e comportamento normal/debug no guia JBoss.
- [ ] Implementar tarefa unica `Servidor: reiniciar JBoss` e acao no gerenciador existente, com selecao de servidor/Todos e modo normal/debug.
- [ ] Manter lock por servidor durante stop/start, aguardar encerramento e impedir novo start se stop falhar; preservar verificacoes de identidade/portas e informar a fase do resultado.
- [ ] Verificar em copia isolada: instancia ativa/parada, stop com falha/timeout, concorrencia, portas ocupadas, debug e Todos; atualizar guia e instrucoes para maquina de trabalho.

Estado: evolucao futura; nenhuma acao Restart implementada ou executada agora.
