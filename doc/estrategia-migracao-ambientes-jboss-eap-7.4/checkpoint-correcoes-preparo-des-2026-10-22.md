# Checkpoint: correcoes do preparo, operacao JBoss e validacao DES

Encerramento solicitado pelo desenvolvedor em 22/10/2026; retomar em 23/10.
Classificacao: evolucao do harness. Trabalho local preservado na branch
`harness/roteiro-des-eap74`, HEAD `88a41e4`. Sem commit, push ou nova PR.
Arquivos novos de implementacao/testes/documentacao foram marcados com
`git add --intent-to-add` para entrar nas copias do runner; nao estao commitados.
Este checkpoint foi acrescentado depois dos testes.

## Entregas locais prontas para revisao final

- Gerador de modulos: schema `module:1.9` sem atributo `slot`; slot personalizado
  incorporado ao nome do modulo. Pastas, JARs, hashes e dependencias preservados.
- Preparo: campo opcional `files`, com `source` relativo ao preparo.json e
  `target` relativo a `standalone/configuration`. Consolida/aplica arquivos
  privados, preserva identicos, recusa divergentes e faz rollback de falhas.
  Configuracoes sem esse campo continuam funcionando. Nao ha sobrescrita forcada.
- Gerenciador: Restart/RestartDebug e tarefa unica para EAP escolhido/Todos.
  Mesmo lock durante stop/start; parada nao confirmada impede novo start;
  resultado informa fase. Reutiliza verificacoes de identidade e portas.
- Logs: script `scripts/acompanhar-log-jboss.ps1` e tarefa unica, EAP/Todos,
  tail e UTF-8 incremental; aguarda arquivo ausente, acompanha rotacao e
  truncamento. Leitura sem bloquear escrita/renomeacao do log.
- Guias de restart/logs, teste de conexao apos start e
  [atualizacao da maquina de trabalho](jboss-eap7.4-configuracao/atualizacao-maquina-trabalho.md).
- [Registro de pendencias DES](jboss-eap7.4-configuracao-des/README.md), com
  fontes fornecidas, decisoes abertas, responsabilidade e impacto local.

As novas tarefas estao em `.vscode/tasks.json`; nao exigem mudanca no gerador
de workspace. Scripts devem chegar pela atualizacao Git do harness, nunca por
sobrescrita a partir da copia privada de conferencia.

## Verificacoes concluidas

Sete suites passaram em copia temporaria, pelo `tests/Invoke-HarnessTests.ps1`:
Eap74Preparation, JbossRestart, JbossLogs, JbossRuntime, JbossAllServers, Jboss
e TaskInputs. Preparo e logs tambem passaram em PS7 pela chamada interna das
suites. Cobertura inclui arquivos externos ausentes/divergentes, destinos
invalidos, preservacao e rollback; restart sob lock e falhas de stop/start;
menus/Todos; logs com UTF-8 parcial, rotacao/truncamento; cancelamento das tasks.

Eap74ModuleLoading passou separadamente com o JDK 8 e JBoss Modules locais,
carregando uma classe sintetica nos slots main e legado. Antes da correcao,
o mesmo carregador confirmou o erro de atributo slot. Nenhum servidor iniciado.
O teste exige HARNESS_TEST_EAP74_HOME e HARNESS_TEST_JDK8_HOME explicitos e
tambem usa a copia temporaria do runner.

Sintaxe de 15 arquivos PowerShell, JSONs e 53 destinos de links locais foram
conferidos. `git diff --check` com configuracao normal passou antes dos ultimos
ajustes documentais. Concluir essa checagem na retomada, incluindo este
checkpoint. Nao usar override `core.autocrlf=false`: isso produziu diagnosticos
de CRLF como whitespace, sem alterar os arquivos ou a configuracao do Git.

Limites: fronteiras de processos/rede dos testes operacionais sao simuladas.
Restart/logs em servidor real, Ctrl+C no acompanhamento real e fluxos da
aplicacao ainda dependem do ensaio do desenvolvedor. As suites nao devem ser
reexecutadas no checkout operacional nem repetidas sem mudanca ou falha nova.

## Estado da maquina de trabalho e configuracoes privadas

O desenvolvedor informou alinhamento com a main remota anterior a estas
correcoes. Segundo boot recebido confirmou EAP 7.4.11/CP11, Oracle 19.22/ojdbc8,
datasource vinculado e portas 8180/10090. Teste simtrPU retornou success/true.
Isso nao comprova consultas, transacoes ou o funcionamento da aplicacao.

Continuam pendentes: confirmacao da copia/uso do keystore, fontes Jasper apos
deploy, integracoes e valores ficticios restantes, datas/fuso com o JDK 8u112
informado, e evidencia funcional da aplicacao. Nao salvar valores reais nos
registros. O agente nao copiou keystores nem alterou JBoss, JDK, XML, valores ou
pastas privadas. Nao aplicar novamente o gerador antigo, que recria o slot
invalido. A atualizacao orientada depende da entrega da revisao corrigida.

Enquanto a revisao nao chega a maquina de trabalho, acompanhar deploy em outro
PowerShell na raiz do harness:

```powershell
$config = Get-Content '.\config\harness.local.json' -Raw | ConvertFrom-Json
$log = Join-Path $config.tools.eap74Home 'standalone\log\server.log'
Get-Content -LiteralPath $log -Tail 100 -Wait -Encoding UTF8
```

Ctrl+C encerra apenas a leitura. Para conferir memoria do inicio legado,
examinar -Xms/-Xmx/MaxMetaspaceSize no standalone.conf.bat e eventuais overrides
da configuracao de execucao da IDE; nao inferir memoria efetiva so pelo arquivo.

## Escopo de DES confirmado pelo desenvolvedor

Nosso escopo e a configuracao ja fornecida. Imagem, pipeline Azure DevOps,
entrypoint, manifests e operacao OKD sao responsabilidade de outra equipe.
Nao voltar a pedir esses arquivos como precondicao para nossas correcoes.
Confirmacoes de consumo/execucao ficam explicitadas para essa equipe, sem
declarar DES validado pelo teste local.

As decisoes abertas incluem driver JDBC parametrizado/literal, keepalive EJB
100 ms versus 60 s, Keycloak/interface nativa, READ_TIMEOUT remoto, caches e
JVM Linux/agentes. A recomendacao continua preservar o comportamento 7.1
compativel; nenhum desses ajustes foi aplicado ao template privado. Local/DES
devem usar a mesma revisao de template por aplicacao. Segunda aplicacao ainda
nao fornecida. Detalhes e ordem estao no registro DES acima.

## Sequencia para retomar

1. Ler este checkpoint, conferir branch/HEAD/estado local e preservar o diff.
2. Concluir revisao documental/navegacao e diff --check com a configuracao Git
   vigente. Revisao de codigo ja feita; repetir suites apenas se houver mudancas
   ou preocupacoes novas. Nao iniciar servidores como verificacao automatica.
3. Preparar commit/push/PR quando solicitado e orientar atualizacao via Git
   depois da integracao. Nao tratar a branch local como main ja publicada.
4. Conferir atualizacao na maquina de trabalho pelo roteiro: preservar entradas,
   reconciliar descritores, declarar arquivos privados se desejado e aplicar
   com servidor parado; depois boot, banco e validacao funcional.
5. Retomar os pontos DES um a um, comecando por EJB e JDBC. Para cada decisao,
   registrar arquivo/revisao, necessidade de atualizar o local e teste esperado.

Referencias de andamento: [plan](../../tasks/plan.md) e [todo](../../tasks/todo.md).

## Conferencia da retomada — 23/10/2026

Raiz, branch `harness/roteiro-des-eap74` e HEAD `88a41e4` conferidos. O diff
preserva as entregas registradas; indice sem conteudo staged e checkpoint novo
ainda nao rastreado naquele momento. Ate esta conferencia, nenhum commit/push
ou operacao de servidor havia sido realizado na retomada.

Conferencia documental/navegacao concluida: 67 links locais e 26 ancoras nos
oito Markdown alterados/novos. Uma ancora foi conferida no elemento HTML
explicito do guia de orientacao; nao e link quebrado. `git diff --check` passou
com a configuracao normal; checkpoint novo conferido separadamente, sem erros
de whitespace. Avisos de conversao futura LF/CRLF nao indicam falha de conteudo.
Nenhuma mudanca de codigo ou preocupacao nova que exija repetir as suites.

Os itens antigos de arquivos externos/restart/logs em tasks/ sao historicos;
o bloco de estado atual ja registra sua implementacao. Nao reabrir essas
entregas ao contar pendencias. Continuam pendentes a publicacao da revisao e
o ensaio real de restart/logs, keystore, Jasper/fontes, datas/fuso, integracoes
e fluxos da aplicacao na maquina de trabalho.

A verificacao de DES continua aberta: dez achados catalogados (DES-01 a
DES-10), mais verificacoes complementares. Sao pontos com partes documentais
ja examinadas e decisoes/confirmacoes ainda abertas, nao dez corretivas do
harness. O registro DES separa arquivos do nosso escopo de consumo/execucao
pela outra equipe (DES-08 e partes de DES-01/02/05/06/07). Retomar decisoes por
EJB e JDBC, indicando impacto no local. Nenhum template privado foi alterado;
boot/conexao locais nao comprovam validacao funcional nem execucao em DES.

## Decisao de publicacao — 23/10/2026

O desenvolvedor autorizou um commit, push da branch e abertura de PR para main
com as correcoes implementadas de modulos, arquivos externos, restart e logs,
testes e orientacoes de atualizacao. A analise de desenvolvimento/DES fica
explicitamente para etapa posterior, conforme o registro DES. Nao foi
solicitado merge nem alteracao da configuracao privada ou operacao do JBoss.
O ensaio operacional local e o aceite de DES permanecem pendentes.
