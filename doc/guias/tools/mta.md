---
html:
  embed_local_images: true
  embed_svg: true
  offline: true
---

# MTA: configuracao e uso

[Voltar ao fluxo principal do desenvolvedor](../harness-migracao-desenvolvedor.md#roteiro-onde-estou-e-o-que-escolho).

Analise de migracao com distribuicao Windows do MTA, acompanhamento e leitura
dos resultados. Os comandos partem da raiz do harness. Para usar uma analise ja
recebida no planejamento, siga o [fluxo de MTA recebido](planejamento-migracao.md#compartilhar-o-mta-e-planejar-em-outra-maquina).

**No fluxo principal:** este guia detalha o diagnostico da
[etapa 3](../harness-migracao-desenvolvedor.md#3-obter-ou-reutilizar-o-diagnostico-mta).
Com a analise conferida, siga para [registro e prioridades na etapa 4](../harness-migracao-desenvolvedor.md#4-conferir-o-registro-e-escolher-prioridades).
Se for uma nova analise de um trabalho em andamento, volte a
[reconciliacao da etapa 8](../harness-migracao-desenvolvedor.md#8-reconciliar-e-decidir-a-continuidade).

Navegacao: [orientacao com o helper](#orientacao-com-o-helper) ·
[configuracao](#configuracao) · [uso](#uso) · [resultado e proximo passo](#resultado-e-proximo-passo).

## Orientacao com o helper

No Codex, ative `$orientar-migracao`; no Copilot, selecione `migracao_helper`.
Veja [como iniciar e retomar a orientacao](../orientacao-migracao.md#iniciar-no-codex-ou-no-copilot).

```text
Quero obter ou reutilizar o diagnostico MTA do projeto X.
Confira o registro, o build e as evidencias disponiveis e me oriente no proximo
passo, preservando a origem ja vinculada e indicando as lacunas.
```

**Resultado esperado:** orientacao para consultar o diagnostico corrente, adotar
explicitamente outra origem ou preparar uma nova analise quando necessaria.
O helper fornece tarefa/caminho reais; voce executa a operacao. Se estiver
reavaliando uma corretiva, informe o lote e peca a verificacao da comparabilidade.

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
    "rulesPath": null,
    "runsPath": "C:/mta-runs",
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
| `mta.runsPath` | Raiz externa obrigatoria para novas analises, por exemplo `C:/mta-runs`. O indice tambem usa essa raiz para associar relatorios existentes por pasta Source. |
| `mta.profile` | `"eap71-to-eap74-java8"`: origem EAP 7.1, destino EAP 7.4, Java 8 e `javax.*`. |
| `mta.sources`, `mta.targets`, `mta.mode` | Mantenha `[]`, `["eap7"]` e `"full"`. O harness recusa desvios desse perfil. |

### Perfil de migracao e regras

**Origem/destino da migracao e filtros do MTA sao coisas distintas.** A CLI 8.2.1 ensaiada nao oferece target `eap7.4`. Usamos `eap7`, incluindo as regras Hibernate 5.1 para 5.3: no arquivo instalado `eap7/116-hibernate51-53.windup.yaml`, elas tem source `hibernate`/`hibernate5.1-` e target `eap7`. Acrescentar `--source eap7.1` excluiria essas regras. `sources: []` e intencional: nao envia `--source`. A selecao por rotulos e descrita no [guia de regras do Kantra](https://github.com/konveyor/kantra/blob/main/docs/rules-quickstart.md).

Preservamos `full`, `--run-local`, todas as regras YAML da pasta Java (sem fixtures de teste), `--enable-default-rulesets=false` e ausencia de `--json-output`. O perfil identifica o objetivo; nao reescreve regras nem transforma o conjunto amplo `eap7` em cobertura exata do EAP 7.4. O Copilot/desenvolvedor deve triar a aplicabilidade por versao e dependencia; o corrigido sera validado no EAP 7.4. Nao converter `javax.*` para `jakarta.*` nem trocar o target para `eap8`.

JSONs locais anteriores, sem `profile` e `sources`, recebem esses valores em memoria; caminhos permanecem inalterados. A configuracao define perfil, origem/destino e filtros da analise corrente. Atualizar a distribuicao ou `rulesPath` exige conferir novamente a comparabilidade com o baseline: o nome do perfil sozinho nao garante regras identicas.

### Origem MTA e caminhos

<a id="pasta-de-rodadas-e-caminhos-longos"></a>

A raiz dos relatorios e `mta.runsPath` em `config/harness.local.json`, por exemplo
`C:/mta-runs`. Novas analises exigem esse caminho fora do harness e das fontes;
sem ele, a tarefa orienta configurar e nao inicia a ferramenta.

**Workspace: atualizar indice dos projetos** procura em
`<runsPath>/<nome-da-pasta-Source>/` e, havendo MTA valido, preenche
`mta.diretorio` em `.harness/projetos/<artifactId>/projeto.json`.
Por exemplo, Source `.../SIMTR-api` com artifactId `simtr-parent` usa
`C:/mta-runs/SIMTR-api`; a associacao aponta a pasta da aplicacao, nao a rodada
datada. Funciona tambem para indices ja criados com `diretorio: null`.
Nomes de pasta Source repetidos no escopo, pasta ausente e conjunto invalido
ficam explicitos nos limites da leitura. Nao se pesquisa outra aplicacao.

Uma origem explicita ja preenchida e preservada. Para gerar novas analises,
ela deve coincidir com `runsPath` mais a pasta Source; divergencia pede conferir
a associacao. Origem explicita indisponivel permanece uma lacuna, sem fallback
para outro relatorio.

Enquanto `mta.diretorio` estiver null, o indice procura um conjunto externo valido.
Se essa descoberta falhar, conserva a leitura do diagnostico interno antigo,
quando disponivel, e registra o motivo como lacuna explicita. Configurar
`mta.runsPath` sozinho nao descarta esse historico: a associacao so e preenchida
apos encontrar um conjunto externo valido. Novas analises sempre usam a raiz externa.

O leitor reconhece a pasta de relatorio estatico com `index.html` e `output.js`
contendo uma aplicacao e seus rulesets. Na origem configurada, escolhe o
diagnostico pela data de geracao valida com fuso ou pela modificacao de
`index.html`, com desempate ordinal de caminho. Arquivo indisponivel/invalido
e lacuna; nao escolhe outra origem silenciosamente. Recencia do diagnostico
nao altera decisoes, escopo ou GO.

A Run Task de analise publica uma nova pasta datada nessa origem e associa
automaticamente o projeto. Relatorios anteriores permanecem intactos; atualizar
o indice encontra o ultimo diagnostico valido sem cadastro de rodada. Use raiz
curta quando ferramentas externas tiverem restricoes de comprimento. A limpeza
corrente preserva os relatorios externos.

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

O resultado utilizavel fica em
`<runsPath>/<nome-da-pasta-Source>/<yyMMdd-HHmmss-fff>/`; o relatorio produzido
pelo harness abre em `static-report/index.html`. O sufixo inclui milissegundos;
colisao nunca sobrescreve um conjunto existente. A saida em preparo fica em
`<runsPath>/.harness-mta-em-preparo/<temporario>/`, fora da pasta consultada pelo
indice, e so se torna visivel como rodada apos sucesso e validacao.
Se a associacao falhar na publicacao, a tarefa tenta retirar a rodada para a
area de preparo. Se o sistema de arquivos tambem impedir essa retirada, informa
as duas falhas e o caminho preservado; conserva tambem a area de preparo para
conferencia. Confira esses diretorios antes de atualizar o indice.

A navegacao, registro, fichas, priorizacao, planos/tarefas e evidencias continuam
em `.harness/projetos/<artifactId>/`. A ultima tentativa tem `mta-console.log` e,
quando disponivel, `mta-interno.log` em `atual/diagnosticos/`. A situacao da
operacao e o link para o MTA externo ficam legiveis no indice do projeto.

A analise usa copias temporarias de fontes/regras para isolar alteracoes do
analisador. Esses arquivos sao retirados ao terminar; nao formam snapshots
permanentes nem requisitos para planejar. Fonte ou regra alterada durante a
operacao interrompe a publicacao. Falha preserva o ultimo diagnostico completo.
A saida externa em preparo e removida ao terminar; se o processo for encerrado
abruptamente, pode permanecer nessa area, sem entrar na selecao do ultimo MTA.
`SUCCEEDED` comprova a execucao/verificacoes locais, nao homologacao EAP 7.4.

### Abrir e compartilhar relatorios

Use **MTA: abrir ultimo relatorio** ou o link **MTA atual** no indice do projeto.
A tarefa informa quando o diagnostico disponivel antecede uma tentativa que falhou.
Para apenas consultar o caminho:

```powershell
.\scripts\abrir-relatorio-mta.ps1 -WorkspacePath .\meu-workspace.code-workspace -SelectTarget -NoOpen
```

Compartilhe a pasta completa do relatorio, preservando os recursos HTML, e
associe a origem ao projeto local em `projeto.json`. Nao ha importador ZIP.
Abrir o HTML diretamente permite visualizar o material; planejar tambem exige
conferir sua aplicabilidade ao codigo local. Quando necessario comparar novo
diagnostico com decisoes/trabalho corrente, use **Planejamento: atualizar registro
de migracao** com motivo concreto.

Trechos ou outras evidencias humanas podem sustentar base EVIDENCIAS, com limites
explicitos; relatorio ausente nao muda automaticamente uma proposta de base MTA.

### Acompanhar a analise MTA

**MTA: acompanhar log da analise** seleciona o projeto e consulta o log corrente.
Durante a execucao, acompanha o log temporario; ao terminar, usa a ultima tentativa.
Mostra situacao/caminho, as ultimas 40 linhas e alteracoes enquanto houver analise
em andamento. `Ctrl+C` encerra somente o leitor. Sem log, informa a lacuna.

**MTA: acompanhar atividade interna** usa a mesma selecao com `-Detalhado`.
Consulta a cada cinco segundos ate quatro linhas resumidas, lendo no maximo
16 KiB por vez. Silencio ou log atualizado nao certificam travamento/progresso.
`-Once` faz uma consulta; nenhuma dessas entradas inicia/cancela MTA.

```powershell
.\scripts\acompanhar-log-mta.ps1 -WorkspacePath .\meu-workspace.code-workspace -SelectTarget -Once
```

Os logs tambem estao acessiveis pelo indice do projeto. Nao existe selecao de
execucoes anteriores por ID no fluxo corrente.

## Resultado e proximo passo

Confira ultima tentativa, origem, projeto, diagnostico utilizavel e lacunas.
Compare com as decisoes e o codigo atual pelo
[fluxo de manutencao](planejamento-migracao.md#reconstruir-a-pasta-usando-um-mta-existente)
quando houver motivo concreto.
Depois siga para [registro e prioridades](planejamento-migracao.md#registro-de-migracao-por-projeto).
Se estiver verificando um lote, registre a comparacao possivel e suas limitacoes;
nao reencontrar um achado nao comprova sozinho sua resolucao nem concede aceite.
