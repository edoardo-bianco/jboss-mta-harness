# JBoss MTA Harness

Harness para build Maven Java 8, analise MTA, coleta SonarQube e planejamento e
implementacao assistidos por Copilot/DevSquad, sob controle do desenvolvedor.
O perfil de migracao e EAP 7.1 para EAP 7.4, preservando Java 8 e `javax.*`.
O **[guia do desenvolvedor](doc/guias/harness-migracao-desenvolvedor.md)** concentra
as instrucoes completas; abaixo esta o percurso rapido com o exemplo incluido.

## Comecar

Tenha Git, VS Code, Windows PowerShell 5.1, JDK 8 da aplicacao, Maven e a distribuicao
Windows completa do MTA, com seu JDK compativel. O ensaio usa MTA 8.2.1/JDK 25.
Para executar os prompts, tenha Copilot autenticado em sessao Local e o plugin
DevSquad disponivel. O harness nao instala essas ferramentas.

1. No clone, abra `iniciar-harness.code-workspace` no VS Code.
2. Em **Terminal > Run Task**, escolha as tarefas da pasta **harness**.
   Execute **Workspace: configurar caminhos** e preencha `config/harness.local.json`
   conforme a conferencia abaixo. Mantenha os dois projetos de exemplo para o ensaio.
3. Salve, execute **Workspace: gerar workspace** e abra
   `jboss-mta-harness.local.code-workspace` em **File > Open Workspace from File**.
4. Execute **MTA: conferir ambiente**, confirme esse workspace e selecione
   `migracao-cache-antes`. Confira `OK`, projeto, fonte, perfil
   `eap71-to-eap74-java8`, target `eap7` e modo `full`.

**Ja configurou?** Abra diretamente o workspace local. Nao precisa gerar novamente
antes de cada execucao. Se a conferencia falhar, corrija o JSON e repita-a.

## Conferencia rapida da maquina

No JSON local, use caminhos reais desta maquina com `/` ou `\\`. Os campos `Home`
recebem a pasta da instalacao; `mtaExecutable` recebe o caminho do arquivo executavel.

| Conferir | Campos e valor esperado |
| --- | --- |
| Build da aplicacao | `tools.applicationJdk8Home`: JDK 8; `tools.applicationMavenHome`: Maven com `bin/mvn.cmd`. |
| Analisador | `tools.mtaExecutable`: `windows-mta-cli.exe` na distribuicao completa; `tools.mtaJdkHome`: JDK do MTA; `tools.mavenHome`: Maven usado pelo MTA, podendo ser a mesma instalacao do build. |
| Regras | `mta.rulesPath: null` usa `rulesets/java` da distribuicao; preserve `sources: []`, `targets: ["eap7"]` e `mode: "full"`. |
| Rodadas externas | Recomenda-se `mta.runsPath: "C:/mta-runs"`, pasta dedicada com permissao de escrita, fora do harness e dos projetos. `null` mantem as rodadas dentro de `.harness/runs`. |
| Settings Maven | `tools.mavenSettingsPath` e `tools.applicationMavenSettingsPath`: `null` usa os padroes da maquina; informe outro caminho somente para settings aprovado pela equipe. |
| Etapas posteriores | Caminhos EAP e configuracao Sonar podem ficar sem preencher no primeiro ciclo build/MTA/planejamento. Configure-os quando for usar essas etapas; nunca grave token no JSON. |

Nao basta copiar somente o executavel MTA: preserve os componentes da distribuicao.
Nao e necessario alterar `JAVA_HOME`/PATH global. **Conferir ambiente valida os
caminhos exigidos pelo MTA e mostra os configurados para a aplicacao; nao executa
build, scan ou teste do servidor.** O build confirma o Java 8 efetivo e o Maven;
a analise confirma o funcionamento do MTA. Veja o
[exemplo completo de configuracao](doc/guias/harness-migracao-desenvolvedor.md#configuracao-da-maquina).

## Ensaio rapido: migracao-cache-antes

Use **Terminal > Run Task**, pasta **harness**. Quando solicitado, confirme
`jboss-mta-harness.local.code-workspace` e escolha **migracao-cache-antes pelo nome
e caminho**, pois o numero pode variar. Mantenha o mesmo projeto nas etapas.

| Passo | Acao | Como conferir |
| --- | --- | --- |
| 1. Construir | **Aplicacao: build Maven (Java 8)**; escolha `clean install`. | `Status: SUCCEEDED`, `ExitCode: 0` e Java 8. Se falhar, corrija antes de analisar. |
| 2. Analisar | **MTA: executar analise**. | `SUCCEEDED`, exit 0, integridade confirmada e `UnexpectedAddedFiles` vazio. Guarde o RunId e os caminhos exibidos. |
| 3. Consultar | **MTA: abrir ultimo relatorio**. | Abre o HTML da ultima rodada concluida; confira o projeto e o caminho da rodada. |
| 4. Preparar proposta | **Planejamento: preparar contexto para Copilot > 1. Planejar lote**. Confira o RunId e use Enter para a ultima elegivel; na escolha do anterior, Enter inicia independente. | Abre `planejar-lotes.prompt.md` com os destinos do plano/to-do. Ainda nao aciona o agente. |
| 5. Gerar o plano | No arquivo aberto, use **Executar Prompt**, em nova conversa Copilot Local com **devsquad**. Sugestao: "Planeje somente a corretiva da limpeza do cache de consultas". | Chamada a `devsquad.plan`, gravacao e releitura de `plan.md` e `todo.md`, com um unico lote. |
| 6. Revisar | **Planejamento: abrir plano e to-do**; escolha a solicitacao gerada. | Confira escopo, POM/dependencias, tarefas e pendencias. Para somente ensaiar o planejamento, termine aqui. |
| 7. Implementar, quando autorizado | Registre o GO humano e execute **Aplicacao: preparar implementacao do lote**. Escolha criar `lote/<ID>`, usar a branch atual ou informar outro nome; depois execute o prompt no Copilot. | Corretiva limitada ao lote, verificacoes e pendencias registradas; aceite humano separado. Criar branch parte do HEAD atual e nao integra nem publica mudancas. |

Sonar e nova rodada MTA ficam no checklist do desenvolvedor, sem bloquear a
implementacao por estarem pendentes. Cobertura abaixo de 85% gera aviso; falhas
de compilacao/testes continuam falhando. GO autoriza implementar, nao aprova o resultado.

**Ja tem um MTA pertinente?** Nao precisa repeti-lo so para gerar outra proposta.
Na etapa 4, use Enter para a ultima elegivel, **h** para o historico ou **p** para
uma pasta completa recebida de outra maquina. Confira a aplicabilidade aos fontes
locais. Para continuar/revisar um lote existente, selecione seu planejamento
anterior; Enter independente nao vincula esse historico.

## Continuar pelo guia

- [Formacao do lote e leitura delimitada do codigo](doc/guias/harness-migracao-desenvolvedor.md#como-se-forma-o-lote-o-planmd-e-o-todomd)
- [Branches: estrategia e matriz origem/destino](doc/guias/harness-migracao-desenvolvedor.md#matriz-de-origem-e-destino-por-fase) e [diagnostico Git/TortoiseGit](doc/guias/diagnostico-branches-git-tortoisegit.md)
- [Revisao com evidencias](doc/guias/harness-migracao-desenvolvedor.md#revisar-um-lote-com-evidencias-complementares), [GO e aceite](doc/guias/harness-migracao-desenvolvedor.md#da-proposta-revisada-a-execucao-e-ao-aceite) e [implementacao](doc/guias/harness-migracao-desenvolvedor.md#preparar-implementacao-do-lote)
- [MTA compartilhado](doc/guias/harness-migracao-desenvolvedor.md#compartilhar-o-mta-e-planejar-em-outra-maquina), [SonarQube](doc/guias/harness-migracao-desenvolvedor.md#sonarqube-local-ou-corporativo) e [limpeza opcional](doc/guias/harness-migracao-desenvolvedor.md#limpar-execucoes-para-repetir-o-ensaio)

Configuracao pessoal, workspace gerado e `.harness/` sao locais e nao acompanham
clone/pull. Os exemplos acompanham o repositorio. Adicione projetos corporativos
com **File > Add Folder to Workspace** e salve; nao precisa regenerar o workspace.

Para evoluir o harness: [AGENTS.md](AGENTS.md), [decisoes](doc/adr/),
[contrato](doc/especificacoes/planejamento-copilot.md), [tarefas](tasks/todo.md) e
[testes dos scripts](doc/guias/harness-migracao-desenvolvedor.md#testar-os-scripts-do-harness).
