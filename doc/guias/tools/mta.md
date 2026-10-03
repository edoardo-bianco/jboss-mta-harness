---
html:
  embed_local_images: true
  embed_svg: true
  offline: true
---

# MTA: configuracao e uso

[Voltar ao fluxo principal do desenvolvedor](../harness-migracao-desenvolvedor.md#roteiro-onde-estou-e-o-que-escolho).

Analise de migracao com distribuicao Windows do MTA, acompanhamento e leitura
dos resultados. Os comandos partem da raiz do harness. Para usar uma rodada ja
recebida no planejamento, siga o [fluxo de MTA recebido](planejamento-migracao.md#compartilhar-o-mta-e-planejar-em-outra-maquina).

**No fluxo principal:** este guia detalha o diagnostico da
[etapa 3](../harness-migracao-desenvolvedor.md#3-obter-ou-reutilizar-o-diagnostico-mta).
Com a rodada conferida, siga para [registro e prioridades na etapa 4](../harness-migracao-desenvolvedor.md#4-conferir-o-registro-e-escolher-prioridades).
Se for uma nova analise de um trabalho em andamento, volte a
[reconciliacao da etapa 8](../harness-migracao-desenvolvedor.md#8-reconciliar-e-decidir-a-continuidade).

Navegacao: [configuracao](#configuracao) · [pasta das rodadas](#pasta-de-rodadas-e-caminhos-longos) ·
[uso](#uso) · [resultados](#analise-e-resultados) · [logs](#acompanhar-a-analise-mta).

## Configuracao

### Instalacao e caminhos

Os programas precisam estar instalados/extraidos nessa maquina. **O MTA pode ficar em qualquer pasta local permitida pela empresa; `.kantra` nao e obrigatorio.** Extraia a distribuicao Windows completa nessa pasta, preservando CLI, `java-external-provider.exe`, `jdtls/`, `rulesets/`, `static-report/` e os demais arquivos do ZIP. Nao basta mover so o executavel. Nao ha instalacao automatica nem alteracao de ExecutionPolicy.

Por exemplo, se a pasta permitida for `D:/ferramentas/mta`, informe `"D:/ferramentas/mta/windows-mta-cli.exe"` em `tools.mtaExecutable`. Com `mta.rulesPath: null`, as regras virao de `D:/ferramentas/mta/rulesets/java`. O harness define `KANTRA_DIR` com a pasta do executavel somente no processo da analise e restaura o valor anterior ao terminar, inclusive em caso de falha. Nao precisa configurar essa variavel globalmente. **MTA: conferir ambiente** mostra a pasta efetiva e confere a presenca dos componentes essenciais. [Resolucao da pasta pelo Kantra](https://github.com/konveyor/kantra/blob/main/pkg/util/util.go).

As tarefas usam Windows PowerShell 5.1. Java e Maven sao configurados somente no processo da analise, a partir do JSON: nao precisa ajustar `JAVA_HOME` ou PATH global. O JDK do MTA nao muda o Java 8/POM da aplicacao. Combinacao ensaiada: MTA 8.2.1, JDK 25 e Maven 3.9.16. A analise completa pode acessar os repositorios Maven definidos nos settings.

Em **Workspace: configurar caminhos**, preencha os campos abaixo em
`config/harness.local.json`. Sao trechos dos blocos existentes: preserve os
campos `application*`, EAP, Sonar e demais valores. Caminhos sao ilustrativos;
settings opcionais ficam `null` para usar os padroes Maven da maquina.

```json
{
  "tools": {
    "mtaExecutable": "D:/ferramentas/mta/windows-mta-cli.exe",
    "mtaJdkHome": "D:/ferramentas/jdk-25",
    "mavenHome": "D:/ferramentas/apache-maven",
    "mavenSettingsPath": null
  },
  "mta": {
    "profile": "eap71-to-eap74-java8",
    "runsPath": null,
    "rulesPath": null,
    "sources": [],
    "targets": ["eap7"],
    "mode": "full"
  }
}
```

| Campo | Preencher com |
| --- | --- |
| `tools.mtaExecutable` | Caminho completo do `windows-mta-cli.exe` dentro da distribuicao completa. Essa pasta tambem define onde o MTA busca seus componentes. |
| `tools.mtaJdkHome` | Pasta do JDK do analisador. O ensaio local utilizou JDK 25. |
| `tools.mavenHome` | Maven usado pelo MTA, com `bin/mvn.cmd`. |
| `tools.mavenSettingsPath` | Opcional: `settings.xml` aprovado para o MTA. Nunca coloque credenciais neste JSON. |
| `mta.rulesPath` | `null` usa `rulesets/java` ao lado da CLI; preencha se as regras Java estiverem em outra pasta. |
| `mta.runsPath` | Pasta dedicada externa para novas rodadas, por exemplo `"C:/mta-runs"`. `null`/ausente mantem `.harness/runs`. |
| `mta.profile` | `"eap71-to-eap74-java8"`: origem EAP 7.1, destino EAP 7.4, Java 8 e `javax.*`. |
| `mta.sources`, `mta.targets`, `mta.mode` | Mantenha `[]`, `["eap7"]` e `"full"`. O harness recusa desvios desse perfil. |

### Perfil de migracao e regras

**Origem/destino da migracao e filtros do MTA sao coisas distintas.** A CLI 8.2.1 ensaiada nao oferece target `eap7.4`. Usamos `eap7`, incluindo as regras Hibernate 5.1 para 5.3: no arquivo instalado `eap7/116-hibernate51-53.windup.yaml`, elas tem source `hibernate`/`hibernate5.1-` e target `eap7`. Acrescentar `--source eap7.1` excluiria essas regras. `sources: []` e intencional: nao envia `--source`. A selecao por rotulos e descrita no [guia de regras do Kantra](https://github.com/konveyor/kantra/blob/main/docs/rules-quickstart.md).

Preservamos `full`, `--run-local`, todas as regras YAML da pasta Java (sem fixtures de teste), `--enable-default-rulesets=false` e ausencia de `--json-output`. O perfil identifica o objetivo; nao reescreve regras nem transforma o conjunto amplo `eap7` em cobertura exata do EAP 7.4. O Copilot/desenvolvedor deve triar a aplicabilidade por versao e dependencia; o corrigido sera validado no EAP 7.4. Nao converter `javax.*` para `jakarta.*` nem trocar o target para `eap8`.

JSONs locais anteriores, sem `profile` e `sources`, recebem esses valores em memoria; caminhos permanecem inalterados. As novas rodadas registram perfil, origem/destino e filtros no manifesto, alem dos argumentos e hashes das regras. Atualizar a distribuicao ou `rulesPath` exige conferir novamente a comparabilidade com o baseline: o nome do perfil sozinho nao garante regras identicas.

### Pasta de rodadas e caminhos longos

**Pasta curta externa para projetos com caminhos longos:** em **Workspace:
configurar caminhos**, acrescente/ajuste somente `runsPath` no bloco `mta` de
`config/harness.local.json`, preservando os outros campos:

```json
"runsPath": "C:/mta-runs"
```

Salve e execute novamente **MTA: executar analise**. Nao precisa mover o harness
nem alterar o workspace. A pasta precisa permitir escrita ao seu usuario e ficar
fora do harness e dos projetos. Novas rodadas usam
`C:/mta-runs/<nome-projeto>/yyMMdd-HHmmss/`, por exemplo
`C:/mta-runs/SIMTR-Outsourcing-api/260930-151210/`, com `input`, `rules`, `output`,
logs e recibos. A data/hora usa o horario local; o instante UTC e o RunId completo
continuam no manifesto. Horarios repetidos recebem `-2`, `-3` etc., sem sobrescrever.
O nome do projeto usa o rotulo do workspace/configuracao, com caracteres seguros
e limite de 64 caracteres. Nomes iguais de projetos/fontes diferentes recebem
sufixos numericos. `project.json` na pasta do projeto identifica `Label`, `Project`
e `Source`; `manifest.json` em cada rodada registra tambem o Git observado.
Nomes dos fontes e estrutura dos modulos sao preservados. A pasta local da rodada
guarda `location.json`, incluindo o caminho relativo do destino externo.
Logs, relatorio e planejamento resolvem essa referencia, inclusive apos trocar
`runsPath` ou voltar a null. Historico existente nao e movido nem reescrito.
Rodadas externas anteriores em `p__<chave12>/<RunId>/` continuam acessiveis.
**Workspace: limpar execucoes** preserva toda a pasta externa, suas rodadas e
`project.json`; remove somente indices e ponteiros selecionados sob `.harness`.
Sem esses indices, use a pasta completa da rodada, conforme o roteiro de abertura
abaixo. Veja os [limites da limpeza](workspace.md#limpar-execucoes-locais).
Ao mover o harness, leve tambem `.harness/`: os indices continuam validos se a
aplicacao e a pasta externa permanecerem no lugar. A raiz antiga em `IndexPath`
e historica; projeto, fonte, RunId e trecho do indice sob `.harness/runs` continuam
conferidos. Nao e necessario reexecutar MTA ou editar os manifestos.

## Uso

### Conferir ambiente e executar analise

1. Abra o workspace local. Em **Terminal > Run Task**, use as tarefas da pasta
   **harness**; confirme o workspace e o projeto/fontes no terminal.
2. Execute **MTA: conferir ambiente**. Confira caminhos, perfil
   `eap71-to-eap74-java8`, target `eap7`, modo `full` e ausencia de filtro source.
   Corrija o JSON se houver falha. Conferir ambiente nao executa build ou analise.
3. Execute **Aplicacao: build Maven (Java 8)** no mesmo projeto/modulo, usando
   `clean install` no primeiro ensaio. Aguarde `SUCCEEDED` e `ExitCode: 0`.
   O MTA nao inicia o build nem verifica automaticamente seu sucesso.
4. Execute **MTA: executar analise** uma vez, com as mesmas fontes. Acompanhe pelo
   terminal ou pelas tarefas de logs abaixo. Confira o JSON final: `SUCCEEDED`,
   exit code zero e verificacoes de integridade verdadeiras.
5. Use **MTA: abrir ultimo relatorio** e confira o HTML. Para continuar, volte a
   [etapa 4: registro e prioridades](../harness-migracao-desenvolvedor.md#4-conferir-o-registro-e-escolher-prioridades).
   Se esta reanalisando um lote em andamento, siga a
   [etapa 8: reconciliacao](../harness-migracao-desenvolvedor.md#8-reconciliar-e-decidir-a-continuidade).

Ao alterar fontes, POMs ou configuracao de build, reconstrua antes da proxima
analise. Para escolher agregadores/modulos e adicionar projetos, consulte a
[selecao de projeto](workspace.md#escolher-o-projeto-em-cada-tarefa).
A conferencia automatica ao abrir o workspace nao inicia MTA; sem alvo padrao,
use a conferencia manual.

```powershell
powershell.exe -NoProfile -File .\scripts\conferir-ambiente.ps1 -WorkspacePath .\jboss-mta-harness.local.code-workspace -SelectTarget
powershell.exe -NoProfile -File .\scripts\construir-aplicacao.ps1 -WorkspacePath .\jboss-mta-harness.local.code-workspace -SelectTarget -Goals "clean install"
# Somente apos o build concluir com sucesso:
powershell.exe -NoProfile -File .\scripts\executar-mta.ps1 -WorkspacePath .\jboss-mta-harness.local.code-workspace -SelectTarget
```

### Analise e resultados

Sem `mta.runsPath`, cada nova rodada fica em `.harness/runs/<nome>__<chave12>/mta_<data-fuso>__<RunId12>/`, com copia do reactor e das regras, `manifest.json` (argumentos/hashes), `console.log`, `result.json` e `output/static-report/index.html`. A pasta usa o instante CreatedAtUtc do manifesto convertido para horario local com fuso; o ID completo permanece nos recibos. Excluimos `.git`, `.harness`, `.scannerwork`, `node_modules` e pastas Maven `target`; preservamos `.mvn` e os modulos. Modulos/pais externos precisam estar disponiveis no Maven ou incluidos na raiz escolhida. Links/junctions nao sao suportados. As fontes originais e as regras sao conferidas depois da execucao.

O snapshot usa caminhos estendidos internamente para enumerar/copiar/calcular
SHA-256 acima de 260 caracteres no PowerShell 5.1; manifestos e comandos MTA
mantem caminhos normais. A pasta externa curta tambem reduz o caminho recebido
pelo MTA/Java. Isso nao certifica todos os limites das ferramentas externas:
confira `Status`, exit code e integridade na nova rodada real do projeto.

Rodadas antigas em `.harness/runs/<Project>/<RunId>/` continuam acessiveis nas
mesmas tarefas. O harness le ambos os formatos, inclusive ultimo relatorio,
analise ativa, logs e planejamento. Confere projeto/fonte e ID completo no
manifesto; mudar o rotulo do projeto nao perde o historico. Copias com o mesmo
RunId dentro da area de rodadas sao recusadas como ambiguas.

Uma falha nao substitui o ultimo relatorio concluido do projeto. `SUCCEEDED` confirma a execucao e as verificacoes locais, nao a homologacao no EAP 7.4. Sonar e deploy complementam o ciclo nos momentos indicados no roteiro principal.

### Abrir e compartilhar relatorios

Se os indices nao estiverem disponiveis, ou a rodada vier de um colega, preserve
a **pasta completa da rodada**. A tarefa **MTA: abrir ultimo relatorio**, quando
nao consegue localizar o ultimo relatorio, pede essa pasta (Enter/q cancela).
Tambem e possivel abrir diretamente, mesmo sem configuracao/cadastro local:

```powershell
.\scripts\abrir-relatorio-mta.ps1 -RunPath 'C:\mta-runs\SIMTR-Outsourcing-api\260930-154744'
```

O caminho acima e ilustrativo: informe a pasta que contem `manifest.json`,
`result.json`, `input`, `rules` e `output`. O leitor confere resultado, identidade
interna e evidencias e abre `output/static-report/index.html` na localizacao atual.
Nao altera origem, indices nem ultimo sucesso local. Para planejar a partir dessa
rodada, use a opcao `p` da tarefa de planejamento. Nao basta copiar so o HTML;
para compartilhar apenas a visualizacao, envie `static-report` inteira e abra
seu `index.html` diretamente no navegador.

### Acompanhar a analise MTA

**Acompanhar a execucao atual:** o terminal de **MTA: executar analise** ja mostra a saida. Para abrir um leitor separado, aguarde a mensagem `Rodada` e execute **MTA: acompanhar log da analise**. Ela se vincula automaticamente a analise MTA em execucao neste harness, sem pedir projeto ou workspace; mostra projeto, fontes, RunId e caminho do log. Exibe as ultimas 40 linhas e acompanha novas linhas dessa rodada. `Ctrl+C` encerra somente o leitor. Ele fica nessa rodada e nao muda para outra automaticamente; encerre-o ao concluir e confira o JSON final no terminal original. Se encontrar o resultado ao abrir, mostra-o e encerra. Sem MTA ativo, informa que nao ha analise em execucao; um build ou registro antigo nao conta como analise ativa. Se o log ainda nao existir, informa a situacao sem abrir um log antigo.

**Consultar uma execucao anterior:** execute **MTA: consultar log de execucao anterior**, confirme o workspace e escolha o projeto. Depois escolha a rodada na lista, que mostra data/hora local com fuso, resultado e RunId, da mais recente para a mais antiga. A ordem usa o instante do manifesto, nao a data de copia da pasta. A tarefa exibe o resultado salvo, o caminho do `console.log` e suas ultimas 40 linhas, sem executar MTA nem seguir novas linhas. `SEM RESULTADO` indica ausencia de recibo, nao comprova que a rodada esteja em execucao. Para ler tudo, abra o arquivo pelo caminho exibido. Builds Maven ficam em `.harness/builds/` e nao aparecem nesse historico MTA.

Para escolher uma rodada explicitamente, use `powershell.exe -NoProfile -File .\scripts\acompanhar-log-mta.ps1 -WorkspacePath .\jboss-mta-harness.local.code-workspace -SelectTarget -RunId <id>`. Adicione `-Once` para mostrar somente as ultimas linhas, sem esperar. O leitor nao inicia/cancela MTA nem altera arquivos; nao acompanha os logs internos do JDT.

**Console sem novas mensagens:** use **MTA: acompanhar atividade interna**. No mesmo script, `-Active -Detalhado` identifica a analise em execucao e consulta `.metadata/.log` da rodada a cada 5 segundos, mostrando horario/idade da ultima gravacao e ate quatro linhas resumidas de mensagens/classes/consultas. Le no maximo 16 KiB por consulta e reabre o arquivo para tolerar rotacao, sem despejar o log inteiro. Nao altera o nivel de log nem a analise. Encerra ao encontrar `result.json` legivel ou com `Ctrl+C`; acrescente `-Once` para fazer apenas uma consulta. Logs atualizados indicam atividade, nao porcentagem/progresso garantido; silencio sozinho tambem nao comprova travamento. Esta visao usa o formato JDT observado na CLI ensaiada e pode ficar indisponivel em outra versao.
