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
e o esquema de autenticacao das APIs e do scanner ficam no JSON local. O harness nao
instala/inicia Docker, cria projetos no Sonar nem altera a politica de qualidade
do servidor.

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
  "apiAuthScheme": "Bearer",
  "scannerJdkHome": "C:/ferramentas/jdk-21",
  "scannerVersion": "5.8.0.7211",
  "ceTimeoutSeconds": 300,
  "profiles": []
}
```

| Campo | Padrao no modelo | O que conferir na maquina do desenvolvedor |
| --- | --- | --- |
| `serverUrl` | `null` | Preencher localhost:9000 para Docker local ou URL HTTPS final do Sonar corporativo. |
| `apiAuthScheme` | `Bearer` | Opcional: `Bearer` ou `Basic`, aplicado nas APIs e no scanner Maven. Ausencia preserva Bearer; para SonarQube 9.9, use Basic. |
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
para o scanner, siga o [preparo integrado do certificado publico](#certificado-publico-do-sonar-corporativo).
As APIs PowerShell usam a confianca do Windows. Redirecionamentos das APIs sao
recusados; use a URL final. Proxy so deve ser configurado se exigido pelo ambiente.

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

### Exemplo corporativo no SonarQube 9.9

No `config/harness.local.json` da maquina de trabalho, atualize somente o bloco
`sonar`, preservando os outros blocos. Exemplo para scanner em JDK 17; ajuste
o caminho para a pasta realmente instalada. A coleta completa ainda deve ser
validada no servidor corporativo:

```json
"sonar": {
  "serverUrl": "https://sonar-esteira.apps.produtos4.caixa",
  "apiAuthScheme": "Basic",
  "scannerJdkHome": "C:\\desenvolvimento\\Java\\jdk-17.0.15+6",
  "scannerVersion": "5.5.0.6356",
  "ceTimeoutSeconds": 300,
  "profiles": []
}
```

O projeto continua compilando/testando com Java 8. O
[ambiente de analise do SonarQube 9.9](https://docs.sonarsource.com/sonarqube-server/9.9/analyzing-source-code/scanner-environment)
documenta Java 11 ou 17; neste harness, use Java 17 para esse servidor. Escolher
um plugin antigo que inicie em Java 8 nao torna o motor de analise 9.9 compativel
com Java 8. No log corporativo fornecido pelo operador em 2026-10-08, a combinacao
5.5.0.6356/JDK 17 enviou o relatorio ao servidor 9.9.5.90363; a coleta posterior
do harness falhou, conforme o [diagnostico abaixo](#envio-concluido-e-falha-na-coleta-local).
Isso comprova o envio nessa execucao, sem homologar toda a coleta ou trocar o
padrao 5.8.0.7211 do modelo de configuracao.
O sucesso de outro servidor com Java 25 continua valido para aquele ambiente;
nao altere o JDK do Sonar local ja validado apenas por causa deste exemplo.

Os caminhos ja configurados em `tools` continuam sendo usados: Java da aplicacao
em `C:\desenvolvimento\Java\jdk1.8.0_112`, Maven em
`C:\desenvolvimento\apache-maven-3.9.12` e o override de settings informado pelo
operador em `C:\desenvolvimento\apache-maven-3.9.12\conf\settings.xml`. Esse
override atende a este ambiente; nas demais maquinas, o padrao continua `null`.

1. Ative a conexao/DNS corporativo que permite acessar esse servidor.
2. Substitua `NOME-DO-PROJETO` pelo nome da pasta da sua aplicacao. Confira que
   `C:\desenvolvimento\repositorio\jboss-7-jdk8\NOME-DO-PROJETO` esta entre as
   pastas do workspace e execute o build/testes conforme o roteiro abaixo.
3. Execute **Aplicacao: analisar SonarQube** e selecione esse projeto. Se faltar
   o truststore, a tarefa oferece o [preparo do certificado](#certificado-publico-do-sonar-corporativo)
   antes de pedir o token ou iniciar a analise.
4. Informe a chave do seu projeto no SonarQube, representada neste exemplo por
   `CHAVE-DO-PROJETO`, e, no campo de branch Sonar, **develop**.
   Use a chave exata cadastrada no Sonar; ela pode diferir do nome da pasta.
   Chave e branch sao entradas da tarefa, nao campos adicionais do bloco `sonar`.
5. Escolha ANTES/DEPOIS e eventual baseline conforme a coleta pretendida.
   Informe o valor do token somente na entrada oculta do terminal.
6. Confira `ApiAuthScheme: Basic`, `ScannerAuthScheme: Basic`, `ScannerJavaHome`
   apontando para JDK 17, `ProjectKey` com a chave informada e
   `BranchName: develop` no novo `result.json`; acompanhe tambem `Stage`,
   `ScannerExitCode`, `AnalysisStatus` e os criterios no resumo.

Basic envia o token como usuario e senha vazia, conforme a
[Web API do SonarQube 9.9](https://docs.sonarsource.com/sonarqube-server/9.9/extension-guide/web-api).
O teste relatado neste ambiente confirmou HTTP 200 com Basic nas consultas de
projeto com/sem develop; Bearer retornou HTTP 401. Isso comprova a autenticacao
de leitura, mas nao a permissao de enviar analises nem a compatibilidade do scanner.
As metricas MQR podem estar ausentes no 9.9; nesse caso os criterios permanecem
UNVERIFIED, conforme a politica abaixo, mesmo depois de corrigida a autenticacao.

`apiAuthScheme` escolhe a autenticacao das consultas do harness, incluindo CE,
Gate e metricas, e do processo scanner Maven. Em Bearer, o scanner recebe
`SONAR_TOKEN`. Em Basic, recebe `sonar.login` com o token e `sonar.password`
vazio por `SONAR_SCANNER_JSON_PARAMS`, somente no ambiente temporario do processo,
sem `SONAR_TOKEN` concorrente. A [implementacao oficial](https://github.com/SonarSource/sonar-scanner-java-library/blob/4.1.2.1663/lib/src/main/java/org/sonarsource/scanner/lib/internal/http/ScannerHttpClient.java)
prioriza Bearer quando existe `sonar.token`; por isso o isolamento e necessario.
O campo `ScannerAuthScheme` registra a escolha, nao comprova autenticacao bem-sucedida.
Nao ha troca automatica de esquema apos falha. Para continuar no Sonar local,
preserve sua URL/JDK e `Bearer`; configuracoes sem esse campo mantem o mesmo
comportamento. Campo presente com valor vazio, null ou diferente dos dois modos
e recusado antes da execucao.

No Windows PowerShell 5.1, `\u0026` no JSON representa `&`. A URL
`/dashboard?id=CHAVE-DO-PROJETO\u0026branch=develop` vira
`/dashboard?id=CHAVE-DO-PROJETO&branch=develop` ao ler o JSON e equivale a
`/dashboard?branch=develop&id=CHAVE-DO-PROJETO`. Esse escape nao exige trocar a URL
do servidor nem remover a branch. Use o link do resumo ou o valor ja lido com
`ConvertFrom-Json`.

### Certificado publico do Sonar corporativo

O erro `SSLHandshakeException: The certificate chain is not trusted`, acompanhado
de `PKIX path building failed`, indica que o Java nao conseguiu estabelecer uma
cadeia de confianca. No caso relatado, o plugin ja havia iniciado e o log dizia
`No active proxy detected`. O `curl.exe` com Schannel funcionava no Windows;
isso nao comprova que o scanner Java consiga validar a mesma cadeia.

O procedimento abaixo prepara o **certificado publico do servidor** no truststore
do scanner. A validacao TLS continua ativa. Ele nao instala chave privada,
nao muda o `cacerts` do JDK, o repositorio Windows ou o Java 8 da aplicacao.
Para distribuir uma CA corporativa em vez do certificado do servidor, siga a
rotina aprovada pela equipe de infraestrutura. Certificados intermediarios
ausentes na cadeia servida tambem devem ser corrigidos pela equipe do servidor.

**Na tarefa habitual, sem copiar script:**

1. Execute **Aplicacao: analisar SonarQube**. Em HTTPS, se nao existir
   `truststore.p12`, aparece `Certificado Sonar`. Escolha **c** para preparar o
   certificado corporativo. Enter continua usando a confianca Windows/JDK;
   `q` cancela. HTTP local dispensa esta etapa.
2. O script usa o `keytool.exe` do JDK configurado em `sonar.scannerJdkHome`
   para obter o certificado por conexao direta e apresentar titular, emissor,
   validade e SHA-256. Cada chamada ao keytool tem limite de 30 segundos.
3. Confira a impressao SHA-256 com a equipe responsavel ou outra fonte corporativa
   confiavel e cole o valor confirmado. Copiar apenas o valor recem-obtido do
   servidor nao e uma verificacao independente de identidade. Enter ou valor
   diferente cancela, preservando o truststore e sem iniciar a analise.
4. O script cria o PKCS12 ou acrescenta o certificado ao arquivo existente,
   mantendo as outras entradas. Depois segue para as entradas e o token da analise.

**Destino por usuario:** `%USERPROFILE%\.sonar\ssl\truststore.p12`, senha
padrao `changeit`, contendo certificados publicos. Quando `SONAR_USER_HOME`
estiver definido, usa `<SONAR_USER_HOME>\ssl\truststore.p12`; o caminho deve
ser absoluto. O scanner Maven 5.x reconhece esse destino padrao. O token Sonar
nao e gravado nele. O preparo deixa apenas o truststore e seu arquivo `.lock`
de coordenacao; os arquivos temporarios da importacao sao removidos.

**Nao reinstala em toda execucao:** se o arquivo ja existe, a tarefa o reutiliza
sem buscar ou importar certificados. Isso nao prova que contenha o certificado
do endpoint atual; o scanner ainda verifica TLS durante a conexao. Se o preparo
for solicitado explicitamente, um certificado identico preserva o arquivo;
um certificado novo e acrescentado, sem excluir os anteriores. Falha do keytool
ou senha diferente de `changeit` interrompe a operacao sem substituir o original.

**Renovacao, outro servidor ou preparo isolado:** a importacao do certificado do
servidor pode precisar ser repetida quando ele for renovado. Para solicitar o
preparo mesmo com truststore existente e continuar a analise, execute da raiz:

```powershell
.\scripts\analisar-sonar.ps1 -PrepareCertificate
```

Para preparar somente o certificado, sem selecionar projeto nem enviar fontes,
este e o script de apoio. Ele chama a **mesma implementacao** da tarefa e usa os
valores locais ja preenchidos, sem manter outra receita de importacao:

```powershell
Import-Module .\scripts\HarnessSonarCertificate.psm1 -Force
$sonar = (Get-Content .\config\harness.local.json -Raw | ConvertFrom-Json).sonar
Initialize-HarnessSonarCertificate -ServerUrl $sonar.serverUrl `
    -ScannerJdkHome $sonar.scannerJdkHome -PrepareCertificate
```

Os comandos `keytool -printcert`, `-importcert` e `-list`, com preparo temporario
e preservacao do arquivo existente, estao em
[HarnessSonarCertificate.psm1](../../../scripts/HarnessSonarCertificate.psm1).
Nao apague um truststore funcional para repetir o preparo. A remocao de entradas
antigas ou a manutencao de truststore com senha/politica propria pertence ao
procedimento da equipe; a tarefa nao remove certificados automaticamente.

**Conferencia:** na proxima analise, o scanner deve superar a conexao HTTPS sem
`SSLHandshakeException`. Se surgir HTTP 401/403, conferir autenticacao/permissao;
isso e outra etapa. Se o erro TLS for das APIs PowerShell, este PKCS12 nao altera
a confianca do Windows. `sonar.scanner.skipSystemTruststore=true` apenas evita a
leitura dos certificados do sistema; nao desabilita a verificacao nem resolve,
por si so, uma cadeia nao confiavel.

**Fontes tecnicas:** [TLS nos scanners Sonar](https://docs.sonarsource.com/sonarqube-server/2025.5/analyzing-source-code/scanners/scanner-environment/manage-tls-certificates),
[parametros de truststore](https://docs.sonarsource.com/sonarqube-server/2025.2/analyzing-source-code/analysis-parameters)
e [keytool do Java 17](https://docs.oracle.com/en/java/javase/17/docs/specs/man/keytool.html).
O [roteiro por maquina](workspace.md#preparar-as-maquinas-dos-colegas) e o ponto
de passagem para colegas; o helper deve orientar por esta secao, sem executar
a importacao, pedir token no chat ou declarar o certificado confiavel por conta propria.

### Envio concluido e falha na coleta local

No log corporativo fornecido em 2026-10-08, o scanner retornou exit 0, o POST
`api/ce/submit` retornou HTTP 200 e houve `ANALYSIS SUCCESSFUL`/`BUILD SUCCESS`.
O `report-task.txt` identificou `ceTaskId=AaEbbLMHsmCUpOwSB4P2` e
`branch=develop`. Apesar disso, o harness terminou com `Stage=COMPUTE_ENGINE`,
`TaskId=null` e `AnalysisStatus=UNVERIFIED`.

A causa reproduzida nos testes locais foi o leitor antigo rejeitar o campo
`branch` do recibo, antes da consulta CE. O leitor corrigido aceita esse campo
opcional, confere a branch selecionada e preserva as verificacoes de servidor,
projeto e task. Recibos antigos sem `branch` continuam aceitos; a resposta CE
continua sendo conferida. Este erro posterior ao envio nao pede reinstalar o
certificado, trocar o goal Maven nem aumentar o timeout CE.

| Evidencia | O que comprova |
| --- | --- |
| `Analysis report generated` | Relatorio local produzido; ainda falta envio. |
| `Analysis report uploaded`, POST 200 e scanner exit 0 | Servidor recebeu o relatorio; o processamento CE pode continuar. |
| Task CE `SUCCESS` com `analysisId` correspondente | Processamento daquela analise concluido. |
| Gate/metricas coletados e vinculados | Coleta do harness conferida, sujeita aos criterios e a revisao humana. |

O dashboard atualiza depois que o servidor processa o relatorio. Ver o resultado
no dashboard e coerente com envio bem-sucedido, mesmo se a coleta local falhou.
Modulos `SKIPPED` no resumo do goal agregador, isoladamente, nao provam que seus
fontes foram omitidos. Preserve o `result.json` FAILED e o recibo historico;
nao os marque como aprovados. A versao corrigida vale para novas coletas e nao
reprocessa automaticamente aquela execucao. Antes de recomendar outro scan,
confira a task recebida e identifique qual evidencia ainda falta.

### Scanner inicia em Java 17, mas ocorre timeout de conexao

Se o terminal mostra `sonar:5.8.0.7211:sonar`, `Java 17` e depois
`Failed to query server version ... HTTP connect timed out`, o plugin iniciou
e falhou ao conectar ao servidor antes da analise. `SKIPPED` nos modulos e
consequencia dessa falha no agregador, nao evidencia de incompatibilidade Java 8.
O aviso `parent.relativePath` do POM e outro assunto; ele nao explica esse timeout.

`ServerVersion` preenchido com `Stage=SCAN` indica que as APIs PowerShell ja
responderam, enquanto o processo Java falhou. Conferir proxy/PAC, DNS/enderecos
e acesso do processo Java. Nao aumentar `ceTimeoutSeconds`: ele limita a espera
pelo processamento de um relatorio ja enviado, nao essa conexao inicial.
Um erro TLS como `PKIX` exigiria outra investigacao; timeout nao comprova isso.

A biblioteca tenta `/api/v2/analysis/version` primeiro. Em servidor antigo, uma
resposta HTTP de erro permite consultar `/api/server/version`; um timeout de
conexao nao segue esse caminho. O teste local com plugin real verificou essa
sequencia diante de 404, sem executar o motor nem homologar o servidor corporativo.

Para identificar o proxy efetivo do PowerShell, sem credenciais:

```powershell
$destino = [Uri]'https://sonar-esteira.apps.produtos4.caixa'
$proxy = [Net.WebRequest]::DefaultWebProxy
if ($null -eq $proxy -or $proxy.IsBypassed($destino)) {
    'PowerShell: acesso direto para esse destino'
} else {
    $rota = $proxy.GetProxy($destino)
    [pscustomobject]@{ ProxyHost=$rota.DnsSafeHost; ProxyPort=$rota.Port }
}
Test-NetConnection -ComputerName $destino.DnsSafeHost -Port 443
```

O teste TCP mede acesso direto; ele pode falhar mesmo quando o PowerShell acessa
por proxy. Se o ambiente realmente exigir proxy, o scanner Maven 5.x possui
`SONAR_SCANNER_PROXY_HOST` e `SONAR_SCANNER_PROXY_PORT`, conforme os
[parametros oficiais](https://docs.sonarsource.com/sonarqube-server/analyzing-source-code/analysis-parameters/parameters-not-settable-in-ui#proxy).
Use somente a rota efetiva do ambiente, sem inventar hosts/portas, persistir
senhas ou mudar settings/certificados para contornar a falha.

### Capturar log detalhado do plugin

O diagnostico esta temporariamente habilitado no harness: Maven recebe `-e -X`
e o scanner recebe `sonar.verbose=true` e `sonar.log.level=DEBUG`. Vale tambem
para a Run Task existente. `-e` exibe a cadeia de excecoes e `-X` habilita debug
do Maven, conforme a [referencia Maven](https://maven.apache.org/ref/3.9.12/maven-embedder/cli.html).
As propriedades Sonar seguem a [referencia de logs](https://docs.sonarsource.com/sonarqube-server/analyzing-source-code/analysis-parameters/parameters-not-settable-in-ui#analysis-logging).

Para salvar a saida, execute no terminal PowerShell, na raiz do harness:

```powershell
$pastaLog = '.harness\ensaios\sonar-timeout'
New-Item -ItemType Directory -Force -Path $pastaLog | Out-Null
$log = Join-Path $pastaLog ("scanner-{0}.log" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))

powershell.exe -NoProfile -File .\scripts\analisar-sonar.ps1 -SelectTarget 2>&1 |
    Tee-Object -FilePath $log

Write-Host "Log salvo em: $log"
```

Responda as escolhas usuais e informe o token somente na entrada oculta. O log
passa pela redacao do launcher para o token Sonar, inclusive Basic/JSON, mas
debug Maven pode exibir outras propriedades/credenciais do ambiente ou projeto.
Revise antes de compartilhar. Para este timeout, preserve o trecho de consulta
da versao ate o erro final, incluindo todos os `Caused by`. O `result.json`
continua registrando a etapa/resultado; ele nao substitui esse log do terminal.

Manter build Java 8 e scanner corporativo Java 17. Depois do diagnostico, avaliar
em nova alteracao a retirada de `-e -X` e o retorno a `sonar.verbose=false` e
`sonar.log.level=INFO` em `scripts/HarnessSonar.psm1`. Nenhuma nova Run Task ou
mudanca de configuracao local e necessaria para esta captura.

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

O token fica somente no ambiente temporario de execucao, conforme o esquema
descrito acima; o ambiente anterior e restaurado inclusive em falhas. A tarefa
nao o envia como argumento e nao grava log
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
| ApiAuthScheme | Esquema usado nas consultas do harness: Bearer ou Basic; nao contem credencial. |
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
