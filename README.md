# JBoss MTA Harness

Repo independente para executar MTA pelo VS Code. Scripts, tarefas, exemplo de configuracao e testes estao aqui. **Este README e o unico guia.** JDKs, Maven, MTA, JBoss e repositorios das aplicacoes ficam nas suas pastas e sao indicados no JSON local.

## Clonar e comecar

```powershell
git clone https://github.com/edoardo-bianco/jboss-mta-harness.git
```

1. Abra a pasta clonada `jboss-mta-harness` no VS Code (**File > Open Folder**).
2. Execute **Terminal > Run Task > Workspace: configurar caminhos**. A tarefa cria e abre `config/harness.local.json`, sem sobrescrever uma configuracao existente.
3. Preencha os caminhos das ferramentas ja instaladas, `repositories` e `activeProject`; salve.
4. Execute **Workspace: gerar workspace**. Abra `jboss-mta-harness.local.code-workspace` em **File > Open Workspace from File** para visualizar o harness e os repositorios cadastrados.
5. Execute **MTA: conferir ambiente**. Deve mostrar `OK`, o projeto, os caminhos e `Targets: eap7 | Modo: full`.
6. Execute **MTA: executar analise**. Aguarde o resultado JSON com `Status: SUCCEEDED` e `ExitCode: 0`. Depois execute **MTA: abrir ultimo relatorio**.

Ao abrir a pasta/workspace, a conferencia automatica abre o JSON se estiver incompleto. O VS Code pode pedir para permitir tarefas automaticas; a tarefa manual de configuracao funciona independentemente dessa permissao. Nenhuma analise comeca automaticamente.

## Tarefa e script correspondente

| Run Task | Arquivo em `scripts/` |
| --- | --- |
| **MTA: executar analise** | **`executar-mta.ps1`** |
| MTA: abrir ultimo relatorio | `abrir-relatorio-mta.ps1` |
| MTA: conferir ambiente | `conferir-ambiente.ps1` |
| Workspace: configurar caminhos | `configurar-caminhos.ps1` |
| Workspace: gerar workspace | `gerar-workspace.ps1` |
| Workspace: conferir configuracao ao abrir | `conferir-ambiente.ps1 -AoAbrir` |

Execucao direta, na pasta deste repo:

```powershell
powershell.exe -NoProfile -File .\scripts\executar-mta.ps1
```

## Planejar lotes de correcao com Copilot

Depois do MTA, use o [prompt planejar-lotes](.github/prompts/planejar-lotes.prompt.md). Ele orienta a leitura das evidencias e a proposta no chat; a implementacao depende da revisao e autorizacao do desenvolvedor.

1. Identifique a pasta da rodada mostrada no terminal: `.harness/runs/<projeto>/<id>/`. Nao misture rodadas ou baselines diferentes.
2. Abra e anexe ao chat versoes revisadas de `manifest.json`, `result.json`, `output/output.yaml` e `output/dependencies.yaml`, com POMs, fontes/testes e regras dos achados relevantes. Os arquivos locais podem ser abertos pelo caminho completo mesmo quando `.harness` estiver oculto no Explorer. Arvore Maven, conteudo do WAR, modulos EAP e Sonar ANTES entram quando disponiveis; sua ausencia deve constar como pendencia. Nao anexar credenciais, settings privados ou logs brutos.
3. No Copilot Local, use `/planejar-lotes` e informe projeto e rodada. Se o cliente/DevSquad nao reconhecer prompts, cole o corpo do arquivo no chat em modo de leitura e anexe as mesmas evidencias. A descoberta automatica depende da versao/cliente; esse fallback mantem o processo utilizavel. [Formato de prompts do VS Code](https://code.visualstudio.com/docs/agent-customization/prompt-files).
4. Revise a triagem, a matriz de dependencias e a tabela de lotes. Escolha apenas o primeiro lote para detalhar e decidir a rota. A proposta pode ser feita por humano usando os mesmos criterios.

**Lote de correcao** e uma convencao deste projeto: ocorrencias correlacionadas com objetivo, solucao, aceite e reversao comuns. Mesma regra MTA nao basta para agrupar. Nao ha relacao obrigatoria de um apontamento = um lote = uma receita; preservar IDs e evidencias historicas chamados de "fatia".

O agente avalia receita OpenRewrite existente, composicao YAML/Refaster, receita Java propria ou ajuste especifico/combinado. Ausencia de receita pronta nao prova impossibilidade: considerar tipos/classpath, viabilidade, custo e reuso. Receita candidata precisa de testes, `dryRun`, revisao do patch e GO antes do `run`. Essa etapa prepara somente o plano; nao instala ou executa OpenRewrite. [Receitas](https://docs.openrewrite.org/concepts-and-explanations/recipes) e [dryRun/run](https://docs.openrewrite.org/reference/rewrite-maven-plugin).

Preservar Java 8, `javax.*`, arquitetura, contratos e baselines. **O corrigido sera testado somente no EAP 7.4; EAP 7.1 e referencia historica, sem exigir retrocompatibilidade.** Sonar e criterios de qualidade permanecem no plano de validacao; ausencia de Sonar nao bloqueia a proposta preliminar nem equivale a conformidade. Nao ha aceite, alteracao de codigo, commit/push ou proximo lote automaticos. Este prompt nao implementa Start/Stop/Deploy nem comprova o ciclo integrado.

## Configuracao da maquina

O exemplo versionado e `config/harness.example.json`; a tarefa cria dele o seu `config/harness.local.json`. Use caminhos reais com `/` ou `\\`, sem variaveis como `%JAVA_HOME%`. Caminhos relativos partem da pasta deste repo.

| Campo | Preencher com |
| --- | --- |
| `repositories` | Lista como `[{"name":"sistema-a","path":"C:/repos/sistema-a"}]`. Pastas externas ao harness; selecione a raiz Maven com `pom.xml` e seus modulos. |
| `activeProject` | O `name` do unico repositorio que sera analisado, por exemplo `"sistema-a"`. |
| `tools.mtaExecutable` | Caminho completo do `windows-mta-cli.exe` instalado. |
| `tools.mtaJdkHome` | Pasta do JDK do analisador. O ensaio local utilizou JDK 25. |
| `tools.mavenHome` | Pasta do Maven, que contem `bin/mvn.cmd`. |
| `tools.mavenSettingsPath` | Opcional: `settings.xml` aprovado para repositorios/proxy. Nunca coloque credenciais neste JSON. |
| `tools.applicationJdk8Home` | Opcional nesta etapa: pasta do JDK 8, configurada no workspace para a aplicacao. |
| `tools.eap71Home`, `tools.eap74Home` | Opcionais: pastas dos JBoss ja extraidos, reservadas para a etapa de runtime. |
| `mta.rulesPath` | `null` usa `rulesets/java` ao lado da CLI; preencha se as regras Java estiverem em outra pasta. |
| `mta.targets`, `mta.mode` | Mantenha `["eap7"]` e `"full"` para o preset ensaiado. |

**Trocar projeto:** altere `activeProject`, salve e execute MTA. **Adicionar repositorios ou mudar paths de ferramentas:** ajuste o JSON, gere e reabra o workspace. A lista de pastas vem do JSON; alteracoes feitas somente na interface sao substituidas na proxima geracao, com backup em `.harness/workspace-backups/`. Uma biblioteca visivel nao e compilada nem analisada automaticamente junto com outro repo.

## O que acompanha o clone

Scripts, tarefas, exemplo de configuracao, testes e este README entram no Git. `config/harness.local.json`, o workspace gerado e `.harness/` sao locais e ignorados. O clone no trabalho pede os caminhos dessa maquina, sem carregar caminhos pessoais. **Este repo nao depende de outro harness.**

Os programas precisam estar instalados/extraidos nessa maquina. Para o MTA Windows usado aqui, preserve a distribuicao completa em `%USERPROFILE%\.kantra`, incluindo CLI, regras e componentes Java. Extraia manualmente os ZIPs aprovados ainda pendentes. Nao ha instalacao automatica nem alteracao de ExecutionPolicy.

As tarefas usam Windows PowerShell 5.1. Java e Maven sao configurados somente no processo da analise, a partir do JSON: nao precisa ajustar `JAVA_HOME` ou PATH global. O JDK do MTA nao muda o Java 8/POM da aplicacao. Combinacao ensaiada: MTA 8.2.1, JDK 25 e Maven 3.9.16. A analise completa pode acessar os repositorios Maven definidos nos settings.

## Analise e resultados

Preservamos `eap7`, `full`, `--run-local`, regras Java explicitas e `--enable-default-rulesets=false`, sem filtro `--source` e sem `--json-output`. Essa CLI nao oferece `eap7.4`; o conjunto eap7 inclui Hibernate 5.1 para 5.3. Nao substituir por eap8. Atualizar a distribuicao/regras exige conferir novamente a comparabilidade.

Cada rodada fica em `.harness/runs/<projeto>/<id>/`, com copia do reactor e das regras, `manifest.json` (argumentos/hashes), `console.log`, `result.json` e `output/static-report/index.html`. Excluimos `.git`, `.harness`, `.scannerwork`, `node_modules` e pastas Maven `target`; preservamos `.mvn` e os modulos. Modulos/pais externos precisam estar disponiveis no Maven ou incluidos na raiz escolhida. Links/junctions nao sao suportados. As fontes originais e as regras sao conferidas depois da execucao.

Uma falha nao substitui o ultimo relatorio concluido do projeto. `SUCCEEDED` confirma a execucao e as verificacoes locais, nao a homologacao no EAP 7.4. Sonar, build e deploy ficam para etapas posteriores.

Para testar somente o harness: execute `powershell.exe -NoProfile -File .\tests\Test-Workspace.ps1` e `powershell.exe -NoProfile -File .\tests\Test-Mta.ps1`. Criam fixtures em `.harness/tests/`; o segundo simula a chamada ao processo MTA.
