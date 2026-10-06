---
html:
  embed_local_images: true
  embed_svg: true
  offline: true
---

# SonarQube: configuracao e uso

[Voltar ao fluxo principal do desenvolvedor](../harness-migracao-desenvolvedor.md#roteiro-onde-estou-e-o-que-escolho).

Coleta de qualidade em servidor local ou corporativo. Os comandos partem da raiz
do harness. Build e cobertura continuam no [fluxo Maven Java 8](maven.md#build-maven-da-aplicacao-com-java-8).

**No fluxo principal:** colete a referencia ANTES na
[etapa 2](../harness-migracao-desenvolvedor.md#2-escolher-o-projeto-e-fazer-o-build)
e confira a qualidade DEPOIS na
[etapa 7](../harness-migracao-desenvolvedor.md#7-verificar-e-aceitar-o-resultado).
Ao terminar, volte a etapa correspondente com as evidencias e pendencias;
o resultado do Sonar compoe a revisao do lote e nao concede aceite humano.

Navegacao: [orientacao com o helper](#orientacao-com-o-helper) ·
[configuracao](#configuracao) · [uso](#uso) · [resultado e proximo passo](#resultado-e-proximo-passo).

Use **Terminal > Run Task > Aplicacao: analisar SonarQube**, da pasta `harness`.
A mesma tarefa atende ao servidor Docker local e ao corporativo: o endpoint
muda no JSON local. O harness nao instala/inicia Docker, cria projetos no Sonar
nem altera a politica de qualidade do servidor.

## Orientacao com o helper

No Codex, ative `$orientar-migracao`; no Copilot, selecione `migracao_helper`.
Veja [como iniciar e retomar a orientacao](../orientacao-migracao.md#iniciar-no-codex-ou-no-copilot).

```text
Quero coletar a referencia Sonar ANTES da corretiva do projeto X.
Confira a configuracao e o contexto disponiveis e me oriente na proxima acao,
com as evidencias que preciso guardar. Nao vou enviar credenciais ao chat.
```

Depois da corretiva:

```text
Quero comparar os resultados Sonar do projeto X antes e depois do lote atual.
Confira as evidencias disponiveis, sua comparabilidade e as pendencias.
Me oriente na proxima verificacao, separando criterios do harness e Quality Gate.
```

**Resultado esperado:** orientacao para coleta/consulta autorizada ou leitura dos
resultados existentes, com lacunas explicitas. Sem baseline, o helper nao inventa
comparacao. Token e informado no terminal apropriado, nunca no pedido ao helper.

## Configuracao

### Configurar uma vez por maquina

Execute **Workspace: configurar caminhos**. A tarefa cria o JSON pelo modelo
ou acrescenta os campos Sonar ausentes ao JSON existente, preservando os valores
ja informados. Confira o bloco no nivel raiz de `config/harness.local.json`,
ao lado de `tools` e `mta`. Exemplo preenchido para Docker local:

```json
"sonar": {
  "serverUrl": "http://localhost:9000",
  "scannerJdkHome": "C:/ferramentas/jdk-21",
  "scannerVersion": "5.8.0.7211",
  "ceTimeoutSeconds": 300,
  "profiles": []
}
```

| Campo | Padrao no modelo | O que conferir na maquina do desenvolvedor |
| --- | --- | --- |
| `serverUrl` | `null` | Preencher localhost:9000 para Docker local ou URL HTTPS final do Sonar corporativo. |
| `scannerJdkHome` | `null` | Preencher caminho do JDK instalado e compativel com scanner/servidor. |
| `scannerVersion` | `5.8.0.7211` | Versao fixa do plugin Maven; confirmar homologacao e acesso ao repositorio Maven corporativo. |
| `ceTimeoutSeconds` | `300` | Tempo maximo de espera pelo processamento no servidor, em segundos. |
| `profiles` | `[]` | Informar os perfis Maven necessarios, coerentes com o build. |

Campos existentes, inclusive valores `null`, nao sao substituidos automaticamente.
O token e solicitado na execucao e nunca faz parte desses valores padrao.

O caminho do JDK e um exemplo. No trabalho, use a URL HTTPS e eventual caminho
base corporativo, por exemplo `https://sonar.empresa/sonarqube`. HTTP e aceito
somente em loopback (localhost/127.0.0.1) para o Docker local. Nao use URLs com
credenciais, query string ou fragmento. Certificados continuam sendo validados;
cadeias/proxy corporativos devem ser configurados pela rotina aprovada da equipe
no Windows e no JDK. Redirecionamentos das APIs sao recusados; use a URL final.

Use uma versao fixa **5.x** homologada para seu servidor. O exemplo fixa
5.8.0.7211, sem afirmar que seja a ultima versao. Escolha o JDK conforme a
matriz de compatibilidade do scanner e do servidor usados pela equipe.

Scanner e servidor sao componentes diferentes; suas versoes nao precisam ser
iguais, mas precisam ser compativeis. Para listar os scanners baixados no cache
Maven padrao, use no PowerShell:

```powershell
Get-ChildItem "$env:USERPROFILE/.m2/repository/org/sonarsource/scanner/maven/sonar-maven-plugin" -Directory
```

Se a empresa configura outro repositorio local, consulte esse caminho. A presenca
do JAR so confirma download; `sonar.scannerVersion` escolhe qual sera executado.
Se ausente, o Maven tenta baixa-lo pelos repositorios configurados, sem enviar
uma analise nesse download isolado. A tarefa registra versoes de scanner e servidor
separadamente. Confirme a versao corporativa e a
[matriz de compatibilidade](https://docs.sonarsource.com/sonarqube-server/analyzing-source-code/scanners/scanner-environment/general-requirements)
antes de escolher o scanner para o trabalho.

O scanner usa `sonar.scannerJdkHome`, sem baixar outro JRE. A aplicacao continua
com `tools.applicationJdk8Home`, enviado como `sonar.java.jdkHome`. Maven e settings
vêm de `tools.applicationMavenHome` e `tools.applicationMavenSettingsPath`.
Settings opcional permanece `null`, usando a configuracao normal da maquina.
O scanner baixa dependencias/plugins pelos repositorios normais; nao ha Maven
offline forcado, mirror ou cache adicional criado pelo harness.

Se o build depende de perfis, informe os mesmos nomes em `sonar.profiles`.
O scan e uma invocacao Maven separada, em outro JDK: confira perfis ativados por
JDK e resolucao de dependencias. Opcoes especificas de cobertura/exclusoes ficam
na configuracao normal aprovada do projeto/Sonar, nao em parametros arbitrarios
do harness. Nao e preciso regenerar o workspace para mudar esse bloco.
JSON antigo sem `sonar` continua servindo para build/MTA. Para incluir os padroes,
abra **Workspace: configurar caminhos**; o scan apenas valida a configuracao.

## Uso

### Executar e consultar

1. Execute o build/testes Java 8 do **mesmo estado** a analisar. Para multimodulo,
   use `clean install` no agregador quando necessario. O scan nao recompila a
   aplicacao nem verifica automaticamente se os binarios sao atuais.
2. Para cobertura, gere previamente o XML JaCoCo com a configuracao aprovada
   do projeto e confira sua importacao no Sonar. O scanner nao gera cobertura.
3. Execute **Aplicacao: analisar SonarQube**; confirme workspace e projeto.
4. Informe a **chave exata do projeto existente no Sonar**. Ela e diferente da
   identidade interna do workspace e nao e inferida pelo nome da pasta.
5. Informe branch Sonar somente se a edicao do servidor suportar. Enter usa a
   principal configurada no Sonar; nenhuma branch Git e criada/trocada automaticamente.
6. Escolha **1 ANTES** ou **2 DEPOIS**. E identificacao declarada pelo operador,
   nao prova de que a corretiva foi ou nao aplicada. ANTES deve ser coletado e
   preservado antes das alteracoes exigidas pelo plano.
7. Informe o caminho do `result.json` de uma coleta **ANTES** para comparar
   o total de issues. Enter deixa a comparacao **PENDING**; nao escolhe a mais
   recente automaticamente. Na primeira coleta ANTES, use Enter.
8. Digite o token na entrada oculta do terminal. Precisa permitir analise do
   projeto e leitura das APIs usadas (incluindo Browse conforme a politica).
   Nao coloque token em JSON, POM, argumentos ou conversa com o agente.
9. Aguarde Maven e processamento no servidor. Abra o caminho `RESUMO.md` exibido
   no terminal ou o `DashboardUrl` do resultado.

O token e temporario em `SONAR_TOKEN` do processo de execucao; o ambiente anterior
e restaurado ao terminar. A tarefa nao o envia como argumento e nao grava log
bruto do scanner. A saida no terminal mascara o token. Nao habilite debug ou
logging externo que capture o ambiente do processo; o harness nao controla
plugins Maven, hooks ou configuracoes externas do projeto.

O resultado fica em:

```text
.harness/sonar/<nome>__<chave>/sonar_<data-hora-fuso>__<id>/
  result.json
  inputs.json
  report-task.txt
  quality-gate.json
  measures.json
  criteria.json
  RESUMO.md
```

Gate/metricas so existem quando a coleta correspondente foi concluida. O scanner
pode manter arquivos internos em `scanner-work`; eles nao sao evidencias para
anexar ao Copilot. `inputs.json` registra hashes dos arquivos de entrada, sem
copiar os fontes, e nao comprova atualidade dos binarios, testes ou cobertura.
Git e apenas informativo. Mudancas nas entradas durante o scan invalidam a coleta.

| Campo | Significado |
| --- | --- |
| ScannerExitCode | Saida do Maven; zero nao confirma o processamento nem o Gate. |
| AnalysisStatus | SUCCESS somente depois de CE confirmar task, projeto e analysisId. |
| QualityGateStatus | Resultado do servidor para aquele analysisId; ERROR e reprovacao. |
| MetricsStatus | MATCHED somente com analise atual conferida antes/depois da leitura e sem fila concorrente observada. |
| MissingMetrics | Metricas nao retornadas; ausencia nao e zero nem conformidade. |
| CriteriaStatus | PASS, WARN, FAIL ou UNVERIFIED para os criterios locais descritos abaixo. |
| BaselineComparison | COMPARED quando comparou totais com o ANTES selecionado; PENDING sem comparacao disponivel. |
| Status | SUCCEEDED com coleta concluida, Gate OK e criterios PASS/WARN; QUALITY_GATE_FAILED com Gate ERROR; CRITERIA_FAILED com criterio reprovado; FAILED/UNVERIFIED nos demais casos. |
| InputsStatus | STABLE quando os hashes de entrada coincidem antes/depois do scan. |

Exit code da tarefa: 0 para SUCCEEDED, 2 para QUALITY_GATE_FAILED/CRITERIA_FAILED e 1 para
falha/coleta nao verificada. O timeout limita a espera pelo processamento CE;
timeout nao cancela uma analise ja enviada. APIs tem timeout de transporte.
O Maven usa sua rotina normal e pode ser interrompido pelo operador no terminal.
Nao rode outros scans do mesmo projeto/branch durante a coleta. A API de metricas
nao recebe analysisId: a conferencia antes/depois reduz mistura de analises,
mas nao constitui snapshot transacional do servidor.

### Criterios do harness e comparacao

O resumo apresenta os valores e motivos; `criteria.json` preserva a avaliacao,
vinculada ao analysisId. A politica acordada para esta tarefa e:

| Criterio | Resultado |
| --- | --- |
| Issues Blocker ou High acima de zero | FAIL: reprova. |
| Cobertura global menor que 85% | WARN: aviso, sem reprovar. Exatamente 85% atende. |
| Total de issues maior que o ANTES selecionado | WARN: aviso com a diferenca numerica. |
| Metrica necessaria ausente/invalida | UNVERIFIED; nao assume zero ou aprovacao. |

As severidades usam as metricas MQR `software_quality_blocker_issues` e
`software_quality_high_issues`. Critical no modo Standard nao substitui High.
Se o servidor nao disponibilizar essas metricas, a avaliacao fica UNVERIFIED.
Um Blocker/High comprovado sempre reprova, mesmo se faltar outra metrica.
Ver [definicoes oficiais das metricas](https://docs.sonarsource.com/sonarqube-community-build/user-guide/code-metrics/metrics-definition).

O Quality Gate do servidor continua independente. Pode reprovar por uma condicao
de cobertura propria, mesmo quando o harness a classifica como aviso. A tarefa
nao muda o Gate, os Quality Profiles nem as regras corporativas.

O baseline deve estar em `.harness/sonar` deste harness, com processamento
concluido, metricas vinculadas e entradas estaveis, declarado ANTES e anterior
a nova coleta. Conferem-se Project/Source, servidor/versao, chave/branch Sonar,
scanner, JDK da aplicacao, settings e perfis Maven registrados. Divergencias
recusam a comparacao; branch/HEAD Git nao sao criterios de bloqueio.
Os arquivos anteriores permanecem intactos. Coletas antigas com `violations`
podem fornecer o total, mesmo sem a nova avaliacao de severidades.

Sem baseline, os criterios disponiveis sao avaliados e a comparacao permanece
PENDING. A diferenca usa `violations` (total de issues, incluindo todos os estados),
nao `new_violations`, que depende da definicao de New Code no servidor.
Uma contagem igual/menor nao prova ausencia de issues novas: outras podem ter sido
resolvidas. A equivalencia de regras, exclusoes, conteudo dos settings e Quality
Profiles exige conferencia do desenvolvedor; esta e uma comparacao numerica.

`SUCCEEDED` nao aprova o lote. Duplicacao e outros requisitos do plano precisam
de avaliacao propria, assim como GO/aceite humano. A tarefa nao exporta a lista
completa de issues nem altera os planos da aplicacao.

### Usar como evidencia na revisao

Preserve a coleta ANTES. A tarefa sempre cria outro RunId/pasta; a limpeza atual
de MTA/build/planejamento **preserva `.harness/sonar`**, inclusive seus baselines.
As coletas sao locais e nao acompanham clone/pull.

Pela task **Planejamento: criar pasta de evidencias**, organize copias dos JSONs
pertinentes e do resumo, listando cada arquivo real no LEIA-ME. Registre servidor,
chave/branch, analysisId, data de coleta, estado dos fontes, configuracao relevante
e limitacoes. Data de copia nao substitui data de coleta. Nao copie logs brutos,
settings privados, credenciais ou scanner-work. Vincule as evidencias a issue
escolhida e use **Planejamento: planejar**, que recupera a solicitacao pelo registro.
Em contexto local, entradas alteradas geram revisao com Previous; em plano
importado, exigem reavaliacao explicita. O agente le os resultados referenciados.
Siga o [roteiro de reconciliacao e atualizacao do plano](planejamento-migracao.md#reconciliar-status-antes-de-atualizar-o-plano)
para alinhar registro, cobertura e proposta com essas evidencias.

### Origem e verificacao

O transporte HTTP, validacao de report-task e espera CE foram adaptados de
`jboss-eap-copilot-harness-template/scripts/SonarApi.psm1`, com seus testes HTTP
locais. A coleta por analysisId e conferencia da analise atual reaproveitam a
abordagem de `SonarAnalysis.psm1`. Nao foram importados controles Git, caches
dedicados, exigencia offline ou contratos de build daquele template.

Referencias: [SonarScanner for Maven](https://docs.sonarsource.com/sonarqube-server/analyzing-source-code/scanners/sonarscanner-for-maven),
[requisitos do scanner](https://docs.sonarsource.com/sonarqube-community-build/analyzing-source-code/scanners/scanner-environment/general-requirements)
e Web API disponivel em `/web_api` no proprio servidor. Sao usadas APIs
`system/status`, `components/show`, `ce/task`, `ce/component`,
`project_analyses/search`, `qualitygates/project_status` e `measures/component`.
Se a versao/politica corporativa nao oferecer uma dessas APIs, a coleta permanece
FAILED/UNVERIFIED; nao ha fallback silencioso para metricas de outra analise.

Testes: `tests/Test-Sonar.ps1` (Maven/API simulados), `tests/Test-SonarCriteria.ps1`,
`tests/Test-SonarConfig.ps1` e `tests/Test-SonarApi.ps1`
(HTTP real em loopback com token sintetico). Nao equivalem a homologacao no
Sonar Docker ou corporativo do operador.

## Resultado e proximo passo

Confira identidade da analise, resumo, criterios e limitacoes. Preserve a origem
ANTES para uma comparacao futura ou relacione ANTES/DEPOIS quando comparaveis.
Leve as evidencias a [revisao do lote](planejamento-migracao.md#revisar-um-lote-com-evidencias-complementares)
e as pendencias ao [aceite humano](planejamento-migracao.md#da-proposta-revisada-a-execucao-e-ao-aceite).
Coleta ou comparacao ausente permanece explicita; resultado Sonar nao concede GO
ou aceite, nem substitui testes do recorte e verificacao funcional.
