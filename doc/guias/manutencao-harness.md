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

O adaptador MCP fica em `mcp/issues`, com SDK e lockfile versionados. Para
desenvolve-lo, use checkout separado, fora das pastas abertas no workspace de
migracao. Nele, instale as dependencias com `npm.cmd ci --prefix mcp/issues --ignore-scripts`
e rode `npm.cmd test --prefix mcp/issues` usando Node >=20 no Windows.
Os testes usam Windows PowerShell 5.1 e fixtures em `.harness/tests` desse checkout, sem MTA/JBoss
reais. Cobrem stdio, paridade, configuracao, limites e ciclo de vida dos filhos.
`tests/Test-IssueQueryRoots.ps1` cobre a restricao opcional de caminhos do nucleo.
`tests/Test-PlanningWithoutMcp.ps1` executa as regressoes de categorias e plano
por projeto com Node/npm/npx ausentes do PATH e configuracao MCP indisponivel.
O [guia de consultas](tools/consultas-issues.md) explica instalacao e alternativa CLI.

Scripts, tarefas, prompts, skills/perfis, exemplo de configuracao, workspace inicial,
testes e documentacao entram no Git. Aplicacoes e playgrounds ficam fora do harness;
o workspace inicial contem somente o harness. `config/harness.local.json`, o workspace
gerado e `.harness/` sao locais e ignorados. O clone no trabalho pede os caminhos
dessa maquina, sem carregar caminhos pessoais. Adicione suas aplicacoes ao workspace
conforme o [guia de workspace](tools/workspace.md).

Os programas precisam estar instalados/extraidos nessa maquina; o harness nao os
instala nem altera ExecutionPolicy. As tarefas usam Windows PowerShell 5.1 e
configuram Java/Maven apenas no processo correspondente. Para a distribuicao
completa do MTA, `KANTRA_DIR`, regras e JDK do analisador, siga o
[guia MTA](tools/mta.md#instalacao-e-caminhos).

## Documentacao e evolucao do harness

### Contribuicoes via pull request

Alteracoes destinadas a `main` passam por pull request. A regra de protecao exige
uma aprovacao e revisao do responsavel definido em [.github/CODEOWNERS](../../.github/CODEOWNERS):
`@edoardo-bianco` para todos os arquivos, incluindo o proprio CODEOWNERS. Novas
alteracoes no PR invalidam aprovacoes anteriores. Push direto, force push e exclusao
de `main` ficam bloqueados. A configuracao remota pode ser conferida em
[Rules do repositorio](https://github.com/edoardo-bianco/jboss-mta-harness/rules).

O administrador tem excecao **somente via PR**, para revisar e fazer merge manual
quando for o autor: o GitHub nao permite aprovar o proprio PR. A excecao nao libera
push direto. No momento da configuracao, o unico administrador e `edoardo-bianco`;
adicionar outro administrador tambem concede essa excecao a ele. Agentes preparam
a alteracao e o PR; a decisao de aprovacao/merge pertence ao mantenedor.

O GitHub usa CODEOWNERS da branch base; a exigencia do revisor nominal passa a
valer quando esse arquivo estiver em `main`. Consulte as regras oficiais de
[CODEOWNERS](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/about-code-owners)
e de [excecao somente via PR](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/creating-rulesets-for-a-repository).

### Fontes e responsabilidades

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
| `doc/guias/` | Fluxo do desenvolvedor, [orientacao com Claude Code, Codex ou Copilot](orientacao-migracao.md), [comparacao de branches](diagnostico-branches-git-tortoisegit.md) e [modelo de evidencias](modelo-evidencias-complementares.md). |
| `doc/guias/tools/` | Configuracao e uso de [workspace](tools/workspace.md), [Maven](tools/maven.md), [MTA](tools/mta.md), [priorizacao](tools/priorizacao-issues.md), [planejamento/reconciliacao](tools/planejamento-migracao.md), [compartilhamento](tools/compartilhamento-contextos.md), [JBoss](tools/jboss.md) e [SonarQube](tools/sonar.md). |
| `doc/engineering-harness/` | Evolucao do produto: [estrategia e arquitetura](../engineering-harness/01-estrategia-e-arquitetura.md), [system design](../engineering-harness/02-system-design.md) e [plano tatico](../engineering-harness/03-plano-tatico-e-implementacao.md), com o catalogo de capacidades no anexo A. Distingue a base atual das propostas. |
| `doc/adr/` | Decisoes e justificativas, como [contexto local e acionamento do Copilot](../adr/0001-contexto-copilot.md). |
| `doc/contratos/` | Regras seguidas pelas tarefas e agentes ao migrar uma aplicacao: [fluxo de migracao](../contratos/fluxo-migracao.md), [planejamento por sprints](../contratos/planejamento-sprints.md) e [consultas de issues](../contratos/consultas-issues.md). |
| `tasks/` | [Plano](../../tasks/plan.md) e [to-do](../../tasks/todo.md) do agente de codificacao para a evolucao atual do harness. |

Crie documentos apenas quando houver conteudo proprio: atualizar o guia responsavel pela etapa em vez de duplicar seu roteiro nem repetir o checklist de trabalho em uma especificacao. Os prompts em `.github/prompts/` sao instrucoes operacionais do agente; `.harness/` guarda artefatos locais de execucao. O plano do agente que evolui o harness e separado das propostas de corretivas das aplicacoes.

### Padrao dos guias operacionais

Os guias operacionais de `tools/` usam o mesmo cabecalho de exportacao e uma abertura
curta: finalidade, etapa do fluxo, link de retorno ao desenvolvedor e navegacao.
Preserve a ordem das secoes principais abaixo; detalhes proprios ficam em subsecoes.

| Secao | Conteudo |
| --- | --- |
| Orientacao com o helper | Link para o guia central, entrada Claude Code/Codex/Copilot, pedido de exemplo em bloco `text` e **Resultado esperado**. Um pedido por etapa quando o guia cobre varias. |
| Configuracao | Entradas, ambiente e preparo necessario. Referenciar configuracao comum no Workspace. |
| Uso | Run Tasks, escolhas e procedimentos da etapa, com limites e verificacoes pertinentes. |
| Resultado e proximo passo | Evidencia a conferir, pendencias possiveis e link para continuar o fluxo. |

O [guia de orientacao](orientacao-migracao.md) concentra descoberta, selecao de
cliente, retomada, papeis e passagem para execucao. Exemplos especificos ficam
nos guias das etapas, ligados pelo mapa central. Pedidos de orientacao nao mandam
o helper executar tarefas, gravar planos, conceder GO ou aceitar resultados.
Use `projeto X` como exemplo substituivel; evite IDs/caminhos ficticios de recibos.
Ao mover secoes, atualize os links de entrada e preserve ancoras antigas como
encaminhamento, incluindo referencias historicas e links salvos pelo desenvolvedor.

## Testar os scripts do harness

Esta secao e para quem altera o proprio harness. Estes testes verificam seus
scripts e nao precisam ser executados para usar o ambiente no dia a dia.
Para verificar uma corretiva da aplicacao, siga a
[etapa 7 do roteiro](harness-migracao-desenvolvedor.md#7-verificar-e-aceitar-o-resultado).

JBoss: `tests/Test-Jboss.ps1`, `tests/Test-JbossRuntime.ps1`,
`tests/Test-JbossWorkspace.ps1`, `tests/Test-JbossServerContext.ps1`,
`tests/Test-JbossAllServers.ps1`, `tests/Test-JbossArtifacts.ps1`, `tests/Test-JbossAddUser.ps1` e
`tests/Test-TaskInputs.ps1` verificam deploy com substituicao e somente o ultimo, identidade/estados,
timeouts, preservacao do workspace, tarefas separadas e controle sem aplicacao.
Todos e validado via menu/CLI, incluindo falhas parciais, configuracao invalida,
resultado por EAP e cancelamento. Descoberta cobre modulos, ambiguidade, ausencia de
build, entrada manual e a entrada real do deploy com adaptadores ficticios.
O teste de usuario usa assistente ficticio para conferir JDK 8, selecao da
instalacao, restauracao do ambiente e propagacao de falhas; nao cria usuarios.
Operacoes de runtime sao simuladas; entradas reais usam cancelamento ou instalacoes
ficticias para nao iniciar/parar servidores da maquina. Ensaio opt-in:
`powershell.exe -NoProfile -File tests/Test-JbossReal.ps1 -RunReal -Eap eap74`
(ou `eap71`). Usa base isolada em `.harness/tests`, HTTP 8280, gerenciamento 10190
e debug 8790: start/JDWP, deploy v1/v2/v1 com substituicao confirmada por HTTP e stop. Exige as
instalacoes locais configuradas e portas livres. Nao executa breakpoint no VS Code.

Os demais testes PowerShell usam o executor isolado. Ele copia os arquivos
versionados com o conteudo corrente (incluindo edicoes ainda nao commitadas) para
uma pasta temporaria fora do checkout. Novos arquivos devem ser adicionados ao
Git com `git add` antes da execucao. Configuracao pessoal e `.harness` nao sao
copiadas. Execute apenas as suites afetadas, por exemplo:

```powershell
powershell.exe -NoProfile -File .\tests\Invoke-HarnessTests.ps1 -Test Test-Planning.ps1,Test-ProjectNavigation.ps1
```

Cada suite usa Windows PowerShell 5.1. Fixtures e logs temporarios sao removidos
apos sucesso ou falha; falhas sao mostradas no terminal e resultam em exit 1.
Por padrao, o workspace original fica sem residuos. Registre o resumo em tasks/.
Para guardar logs por necessidade concreta, informe `-ResultsPath <pasta>`; isso
exporta apenas logs e resultado.json, nunca os projetos artificiais.

Nao execute `Test-*.ps1` diretamente no workspace de migracao: extensoes Java
podem descobrir os POMs artificiais e disparar builds. Testes Node e ensaios com
ferramentas reais devem ocorrer em checkout separado, fora das pastas abertas
no VS Code. Os comandos diretos desses ensaios, abaixo e acima, sao para esse
checkout separado e exigem os parametros e a configuracao reais apropriados.

| Area | Suites e verificacao |
| --- | --- |
| Armazenamento por projeto | `Test-ProjectStorage`, `Publication`, `Recovery`, `Concurrency` e `ReadOnly`: identidade Maven, destinos, publicacao, exclusividade e recuperacao. Os nomes completos possuem prefixo `Test-Project` e extensao `.ps1`. |
| Indices e navegacao | `Test-ProjectIndex.ps1`, `Test-ProjectNavigation.ps1` e `Test-ProjectDocuments.ps1`: links existentes, operacoes/diagnosticos, texto humano e documentos correntes. |
| Planejamento | `Test-Planning.ps1`, `Test-PlanningEvidence.ps1`, `Test-PlanningCli.ps1` e `Test-IssuePlanning.ps1`: registro, escopo, fontes diretas, base MTA/EVIDENCIAS, fichas, lacunas e destinos. |
| Copia e reconciliacao | `Test-PlanningPortable.ps1`, `Test-PlanningReassociation.ps1` e suites `Test-Reconciliation*.ps1`: POM local, copia direta/pasta recebida, conflitos, mesclagem por decisao e realinhamento. Nao existe mais teste ou operacao de pacote ZIP. |
| Priorizacao | `Test-Prioritization.ps1`, `Progress`, `Categories`, `Incidents` e `Index`: categoria/escopo, B0 fixa, quota, examinadas acumuladas, fichas e indice derivado. Os nomes completos possuem prefixo `Test-Prioritization` e extensao `.ps1`. |
| Implementacao | `Test-Implementation.ps1` e `Test-ImplementationBranch.ps1`: preparo corrente e escolha explicita de branch em repositorios ficticios; nao executam corretivas nem concedem GO. |
| Sprints | Suites `Test-Sprint*.ps1`: fontes, cenario/mestre, estimativas, baseline, consumo, validacao, publicacao e prompts. Nao aprovam compromisso humano de prazo. |
| MTA | `Test-Mta.ps1`, `Test-MtaLog.ps1`, `Test-MtaActive.ps1`, `Test-ProjectMta.ps1` e `Test-ExternalMtaDiscovery.ps1`: produtor simulado, leitura direta e acompanhamento da operacao/ultimo log, sem rodada historica no runtime. |
| Build | `Test-Build.ps1` e `Test-BuildConfig.ps1`: ferramentas separadas, Java 8, ultima tentativa, falhas e restauracao do ambiente. |
| Sonar | `Test-Sonar.ps1`, `Test-SonarDownload.ps1`, `Test-SonarCriteria.ps1`, `Test-SonarIssues.ps1` e `Test-SonarReview.ps1`: scan/download simulados, origem, comparacao, criterios e parecer corrente. Launcher/certificado/API possuem suites proprias; API usa HTTP real somente em loopback. |
| Workspace e entradas | `Test-Workspace.ps1`, `Test-Target.ps1`, `Test-TaskInputs.ps1`, `Test-Editor.ps1` e `Test-EvidenceFolder.ps1`: configuracao, selecao, Explorer, argumentos reais, cancelamento, editor simulado e indice de evidencias. |
| Consultas | Suites `Test-IssueQuer*.ps1`, `Test-McpRoots.ps1` e testes Node de `mcp/issues`: somente leitura, paginas, limites, origens correntes e permissoes. |
| Conversao e limpeza | Suites `Test-Conversion*.ps1`, `Test-Cleanup.ps1` e `Test-ProjectTemporaryRemoval.ps1`: previa/aplicacao/validacao/limpeza em fixtures, sem conversao ou limpeza dos registros reais. |
| Transicao integrada | `Test-TransitionWorkflow.ps1`: converter, descartar o legado selecionado, ler o projeto corrente e reconciliar contribuicao divergente no mesmo projeto; preservar notas, origem externa, GO pendente e links. |

Testes simulados nao comprovam que uma aba abriu no VS Code, que o cliente
descobriu/delegou helpers ou que uma corretiva foi aceita. A qualidade do ranking
e a orientacao nativa seguem para a [validacao manual](tools/priorizacao-issues.md#validacao-manual).
A conversao deve permanecer independente do runtime corrente; o fluxo usual nao
procura recibos antigos nem depende de arquivos do conversor.

Para ensaiar cobertura com Maven real, execute em uma linha:

```powershell
powershell.exe -NoProfile -File .\tests\Test-BuildCoverage.ps1 -Jdk8Home <caminho-do-jdk8> -MavenHome <caminho-do-maven>
```

Esse ensaio usa fixture isolada e settings/dependencias padrao da maquina.
Cobertura baixa gera aviso/exit 0; teste reprovado e compilacao falha continuam
falhando. Nao executa Sonar nem MTA. Mantenha os ensaios com ferramentas reais
separados da regressao automatica e confira os parametros de cada suite.

## Resultado e proximo passo

Registre as alteracoes e verificacoes em `tasks/plan.md` e `tasks/todo.md`,
revise o diff e siga o fluxo da equipe para integrar a evolucao do harness.
Isso nao concede GO nem aceite de corretivas das aplicacoes. Para retomar uma
migracao, volte ao [guia do desenvolvedor](harness-migracao-desenvolvedor.md#como-usar-este-guia).
