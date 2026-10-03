---
html:
  embed_local_images: true
  embed_svg: true
  offline: true
---

# Manutencao do harness

[Voltar ao guia do desenvolvedor](harness-migracao-desenvolvedor.md#guias-de-ferramentas).

Este guia e para quem altera scripts, prompts, configuracao, tarefas ou
documentacao do proprio harness. Para usar o ambiente na migracao de uma
aplicacao, siga o [fluxo principal](harness-migracao-desenvolvedor.md#roteiro-onde-estou-e-o-que-escolho).
As regras de contribuicao estao em [AGENTS.md](../../AGENTS.md); a branch de
evolucao segue a [orientacao Git](diagnostico-branches-git-tortoisegit.md#branch-exclusiva-para-alterar-o-harness).

Navegacao: [conteudo do repositorio](#o-que-acompanha-o-clone) ·
[documentacao e escopos](#documentacao-e-evolucao-do-harness) ·
[testes dos scripts](#testar-os-scripts-do-harness).

## O que acompanha o clone

Scripts, tarefas, prompts, exemplo de configuracao, workspace inicial, dois projetos de demonstracao, testes e documentacao entram no Git. `config/harness.local.json`, o workspace gerado e `.harness/` sao locais e ignorados. O clone no trabalho pede os caminhos dessa maquina, sem carregar caminhos pessoais. **Este repo nao depende de outro harness nem dos checkouts locais usados para criar os exemplos.**

Os programas precisam estar instalados/extraidos nessa maquina; o harness nao os
instala nem altera ExecutionPolicy. As tarefas usam Windows PowerShell 5.1 e
configuram Java/Maven apenas no processo correspondente. Para a distribuicao
completa do MTA, `KANTRA_DIR`, regras e JDK do analisador, siga o
[guia MTA](tools/mta.md#instalacao-e-caminhos).

## Documentacao e evolucao do harness

A [ADR-0002](../adr/0002-separacao-harness-e-migracao-progressiva.md) estabelece a
separacao entre **evoluir o harness** (scripts, prompts, Run Tasks e documentacao,
com plano/to-do em `tasks/`) e **migrar uma aplicacao** (lotes progressivos, com
plano/to-do nos destinos do contexto). [AGENTS.md](../../AGENTS.md) e as
[instrucoes do Copilot](../../.github/copilot-instructions.md) levam essa regra aos agentes.

O [README](../../README.md) apresenta contexto e estrategia. O
[guia do desenvolvedor](harness-migracao-desenvolvedor.md) conduz o fluxo geral;
os guias de ferramentas detalham configuracao e uso. Este guia trata da manutencao
do harness. Os demais documentos possuem finalidades distintas:

| Local | Conteudo |
| --- | --- |
| `doc/guias/` | Fluxo do desenvolvedor, [comparacao de branches](diagnostico-branches-git-tortoisegit.md) e [modelo de evidencias](modelo-evidencias-complementares.md). |
| `doc/guias/tools/` | Configuracao e uso de [workspace](tools/workspace.md), [Maven](tools/maven.md), [MTA](tools/mta.md), [planejamento/reconciliacao](tools/planejamento-migracao.md), [JBoss](tools/jboss.md) e [SonarQube](tools/sonar.md). |
| `doc/estrategia/` | [Objetivos, fundamentos e evolucao proposta do harness](../estrategia/estrategia-harness_.md); distingue a base atual dos pilotos futuros. |
| `doc/adr/` | Decisoes e justificativas, como [contexto local e acionamento do Copilot](../adr/0001-contexto-copilot.md). |
| `doc/especificacoes/` | Contratos duradouros do harness e criterios verificaveis, como [planejamento Copilot](../especificacoes/planejamento-copilot.md). |
| `doc/features/` | Registro historico dos primeiros ensaios, explicitamente datado; nao e outro guia de uso nem fonte de pendencias atuais. |
| `tasks/` | [Plano](../../tasks/plan.md) e [to-do](../../tasks/todo.md) do agente de codificacao para a evolucao atual do harness. |

Crie documentos apenas quando houver conteudo proprio: atualizar o guia responsavel pela etapa em vez de duplicar seu roteiro nem repetir o checklist de trabalho em uma especificacao. Os prompts em `.github/prompts/` sao instrucoes operacionais do agente; `.harness/` guarda artefatos locais de execucao. O plano do agente que evolui o harness e separado das propostas de corretivas das aplicacoes.

## Testar os scripts do harness

Esta secao e para quem altera o proprio harness. Estes testes verificam seus
scripts e nao precisam ser executados para usar o ambiente no dia a dia.
Para verificar uma corretiva da aplicacao, siga a
[etapa 7 do roteiro](harness-migracao-desenvolvedor.md#7-verificar-e-aceitar-o-resultado).

JBoss: `tests/Test-Jboss.ps1`, `tests/Test-JbossRuntime.ps1`,
`tests/Test-JbossWorkspace.ps1`, `tests/Test-JbossServerContext.ps1`,
`tests/Test-JbossAllServers.ps1`, `tests/Test-JbossArtifacts.ps1`, `tests/Test-JbossAddUser.ps1` e
`tests/Test-TaskInputs.ps1` verificam releases/rollback, identidade/estados,
timeouts, preservacao do workspace, tarefas separadas e controle sem aplicacao.
Todos e validado via menu/CLI, incluindo falhas parciais, configuracao invalida,
recibos por EAP e cancelamento. Descoberta cobre modulos, ambiguidade, ausencia de
build, entrada manual e a entrada real do deploy com adaptadores ficticios.
O teste de usuario usa assistente ficticio para conferir JDK 8, selecao da
instalacao, restauracao do ambiente e propagacao de falhas; nao cria usuarios.
Operacoes de runtime sao simuladas; entradas reais usam cancelamento ou instalacoes
ficticias para nao iniciar/parar servidores da maquina. Ensaio opt-in:
`powershell.exe -NoProfile -File tests/Test-JbossReal.ps1 -RunReal -Eap eap74`
(ou `eap71`). Usa base isolada em `.harness/tests`, HTTP 8280, gerenciamento 10190
e debug 8790: start/JDWP, deploy v1/v2 com HTTP, rollback HTTP e stop. Exige as
instalacoes locais configuradas e portas livres. Nao executa breakpoint no VS Code.

Para Git e limpeza, execute `powershell.exe -NoProfile -File .\tests\Test-Git.ps1`
e `powershell.exe -NoProfile -File .\tests\Test-Cleanup.ps1`. Usam repositorios e
historicos de teste em `.harness/tests/`; nao trocam a branch nem apagam historicos
reais do desenvolvedor.

Para testar o planejamento, execute `powershell.exe -NoProfile -File .\tests\Test-Planning.ps1`. Verifica selecao de rodadas, isolamento por projeto, evidencia invalida, contexto fixo, pastas legiveis e compatibilidade com o historico antigo. Testa abertura de plano/to-do com editor simulado e cancelamento pela entrada real, sem iniciar Maven, MTA ou Copilot.

`tests/Test-PlanningPortable.ps1` verifica MTA recebido de outra maquina, alertas
do POM e continuidade sem indice local. `tests/Test-LongPaths.ps1` verifica copia,
hashes e armazenamento externo em fixtures de caminhos longos.

Para testar o preparo de implementacao, execute `powershell.exe -NoProfile -File .\tests\Test-Implementation.ps1`.
Verifica identidade/destinos/hashes, preservacao do historico, menus, cancelamento
e abertura simulada do editor. Nao executa corretivas nem comprova o GO ou a
delegacao no Copilot; esse ensaio permanece separado dos testes de scripts.

`powershell.exe -NoProfile -File .\tests\Test-ImplementationBranch.ps1` verifica
as tres escolhas e o fallback, com criacao de branches somente em repositorios
ficticios: nomes invalidos/existentes, cancelamento, HEAD destacado e preservacao
de arquivos/indice. Nao altera branches da aplicacao real.

Para testar configuracao e analise: execute `powershell.exe -NoProfile -File .\tests\Test-Workspace.ps1` e `powershell.exe -NoProfile -File .\tests\Test-Mta.ps1`. Criam fixtures em `.harness/tests/`; o segundo simula a chamada ao processo MTA.

Para testar o build e sua configuracao: execute `powershell.exe -NoProfile -File .\tests\Test-Build.ps1` e `powershell.exe -NoProfile -File .\tests\Test-BuildConfig.ps1`. Verificam ferramentas separadas, Java 8, falhas, restauracao do ambiente e geracao do workspace, com chamadas de build simuladas.

Para ensaiar cobertura com Maven real, execute `powershell.exe -NoProfile -File
.\tests\Test-BuildCoverage.ps1 -Jdk8Home <caminho-do-jdk8> -MavenHome <caminho-do-maven>`
em uma linha. O ensaio usa fixture isolada em `.harness/tests/`, dependencias e
settings padrao da maquina: cobertura baixa gera aviso/exit 0, enquanto teste
reprovado e erro de compilacao continuam falhando. Nao executa Sonar nem MTA.

Para testar o acompanhamento e o historico, execute `powershell.exe -NoProfile -File .\tests\Test-MtaLog.ps1`. Usa logs ficticios e verifica novas linhas durante a leitura e selecao de rodadas anteriores, sem executar MTA. `powershell.exe -NoProfile -File .\tests\Test-MtaActive.ps1` verifica a deteccao da analise ativa sem selecao de projeto e recusa registros antigos e builds como fonte de observabilidade MTA.

Para testar a selecao dos projetos do workspace, execute `powershell.exe -NoProfile -File .\tests\Test-Target.ps1`. Verifica o menu, packaging pom, padrao opcional, projetos homonimos, adicao/renomeacao e preservacao do JSON/workspace.

Para testar os argumentos das tarefas, execute `powershell.exe -NoProfile -File .\tests\Test-TaskInputs.ps1`. Verifica as entradas suportadas e executa o script real de build ate o menu, com caminho de workspace contendo espacos; cancela antes de iniciar Maven.

Para testar o registro, execute `powershell.exe -NoProfile -File .\tests\Test-MigrationRegister.ps1`.
`tests/Test-ProjectIndex.ps1` verifica resumo por Source, ultimas falhas, ausencias,
MTA externo, documentos incompletos, links e preservacao de entradas/historico.

Para testar a abertura no editor, execute `powershell.exe -NoProfile -File .\tests\Test-Editor.ps1`.
Verifica a CLI da instalacao selecionada, argumentos e falhas com editor simulado;
nao comprova que uma aba apareceu no VS Code real.

Para testar a pasta de evidencias, execute `powershell.exe -NoProfile -File .\tests\Test-EvidenceFolder.ps1`.
Verifica selecao/cancelamento pela entrada real, isolamento de projetos homonimos,
repeticao sem sobrescrita e abertura do LEIA-ME em editor simulado, sem MTA/Copilot.

## Resultado e proximo passo

Registre as alteracoes e verificacoes em `tasks/plan.md` e `tasks/todo.md`,
revise o diff e siga o fluxo da equipe para integrar a evolucao do harness.
Isso nao concede GO nem aceite de corretivas das aplicacoes. Para retomar uma
migracao, volte ao [guia do desenvolvedor](harness-migracao-desenvolvedor.md#como-usar-este-guia).
