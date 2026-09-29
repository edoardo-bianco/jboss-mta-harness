# SonarQube local ou corporativo

Use **Terminal > Run Task > Aplicacao: analisar SonarQube**, da pasta `harness`.
A mesma tarefa atende ao servidor Docker local e ao corporativo: o endpoint
muda no JSON local. O harness nao instala/inicia Docker, cria projetos no Sonar
nem altera a politica de qualidade do servidor.

## Configurar uma vez por maquina

Em **Workspace: configurar caminhos**, acrescente este bloco no nivel raiz de
`config/harness.local.json`, ao lado de `tools` e `mta`:

```json
"sonar": {
  "serverUrl": "http://localhost:9000",
  "scannerJdkHome": "C:/ferramentas/jdk-21",
  "scannerVersion": "5.8.0.7211",
  "ceTimeoutSeconds": 300,
  "profiles": []
}
```

O caminho do JDK e um exemplo. No trabalho, use a URL HTTPS e eventual caminho
base corporativo, por exemplo `https://sonar.empresa/sonarqube`. HTTP e aceito
somente em loopback (localhost/127.0.0.1) para o Docker local. Nao use URLs com
credenciais, query string ou fragmento. Certificados continuam sendo validados;
cadeias/proxy corporativos devem ser configurados pela rotina aprovada da equipe
no Windows e no JDK. Redirecionamentos das APIs sao recusados; use a URL final.

Use uma versao fixa **5.x** do SonarScanner for Maven homologada para seu
servidor. O exemplo fixa 5.8.0.7211; nao e afirmacao de ultima versao. O template
anterior desta maquina tinha 5.8.0.7211, JDK 25 e localhost:9000: essas sao
referencias locais recuperadas, nao requisitos nem configuracoes corporativas.
JDK 21 ou superior e necessario nos servidores atuais; JDK 17 serve somente
quando ainda suportado pela combinacao de scanner/servidor da equipe.

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
JSON antigo sem `sonar` continua servindo para build/MTA; a nova tarefa orienta
adicionar o bloco e nao reescreve configuracao existente automaticamente.

## Executar e consultar

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
7. Digite o token na entrada oculta do terminal. Precisa permitir analise do
   projeto e leitura das APIs usadas (incluindo Browse conforme a politica).
   Nao coloque token em JSON, POM, argumentos ou conversa com o agente.
8. Aguarde Maven e processamento no servidor. Abra o caminho `RESUMO.md` exibido
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
| Status | SUCCEEDED com coleta concluida e Gate OK; QUALITY_GATE_FAILED com Gate ERROR; FAILED/UNVERIFIED nos demais casos. |
| InputsStatus | STABLE quando os hashes de entrada coincidem antes/depois do scan. |

Exit code da tarefa: 0 para SUCCEEDED, 2 para QUALITY_GATE_FAILED e 1 para
falha/coleta nao verificada. O timeout limita a espera pelo processamento CE;
timeout nao cancela uma analise ja enviada. APIs tem timeout de transporte.
O Maven usa sua rotina normal e pode ser interrompido pelo operador no terminal.
Nao rode outros scans do mesmo projeto/branch durante a coleta. A API de metricas
nao recebe analysisId: a conferencia antes/depois reduz mistura de analises,
mas nao constitui snapshot transacional do servidor.

`SUCCEEDED` nao aprova automaticamente os criterios do lote: cobertura,
duplicacao, severidades e issues novas devem ser avaliadas contra o plano.
Nao ha comparacao automatica ANTES/DEPOIS, exportacao completa de issues,
verificacao da equivalencia dos Quality Profiles/settings entre coletas ou
GO/aceite. O campo new_violations usa a definicao de New Code do servidor,
nao uma diferenca calculada contra um baseline local escolhido.

## Usar como evidencia na revisao

Preserve a coleta ANTES. A tarefa sempre cria outro RunId/pasta; a limpeza atual
de MTA/build/planejamento **preserva `.harness/sonar`**, inclusive seus baselines.
As coletas sao locais e nao acompanham clone/pull.

Pela task **Planejamento: criar pasta de evidencias**, organize copias dos JSONs
pertinentes e do resumo, listando cada arquivo real no LEIA-ME. Registre servidor,
chave/branch, analysisId, data de coleta, estado dos fontes, configuracao relevante
e limitacoes. Data de copia nao substitui data de coleta. Nao copie logs brutos,
settings privados, credenciais ou scanner-work. Depois prepare **2. Revisar lote**
com Previous e esse LEIA-ME. O agente de planejamento apenas le os resultados.

## Origem e verificacao

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

Testes: `tests/Test-Sonar.ps1` (Maven/API simulados) e `tests/Test-SonarApi.ps1`
(HTTP real em loopback com token sintetico). Nao equivalem a homologacao no
Sonar Docker ou corporativo do operador.
