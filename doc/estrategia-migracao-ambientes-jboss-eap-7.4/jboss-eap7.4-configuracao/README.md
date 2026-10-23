# Configurar e repetir o preparo do JBoss EAP 7.4

Este e o roteiro manual, com ou sem helper, para Windows, PowerShell 5.1 ou 7,
EAP 7.4 standalone e JDK 8. Os scripts recebem um **template ja adequado ao EAP
7.4**: nao convertem automaticamente configuracoes 7.1, nem instalam o produto,
aplicam patch ou fazem deployment. Para transformar a origem, consulte o
[roteiro de migracao da configuracao](../../guias/tools/migracao-configuracao-jboss.md).

O preparo consolida XML, configuracao JVM, modulos e arquivos externos declarados; `-Aplicar` publica esse
conjunto no EAP escolhido. O inicio usa os arquivos ja instalados. Script e
harness chamam o `standalone.bat` oficial e o mesmo `bin/standalone.conf.bat`.

Para DES com imagem construida pelo Azure DevOps e executada no OKD, use o
[roteiro de DES](des.md). Local e DES devem consumir a mesma revisao do template
7.4 por aplicacao; valores, provisionamento e inicializacao seguem cada ambiente.

## 1. Separar codigo e dados de cada ambiente

No repositorio ficam este roteiro, [scripts](scripts/), [modelos](modelos/) e
[exemplos ficticios](exemplos/). Dados reais ficam em pasta privada escolhida
pelo desenvolvedor, fora do Git; use armazenamento/sincronizacao autorizado
pela organizacao. O XML gerado tambem contem valores reais.

Estrutura sugerida (todos os caminhos sao configuraveis):

```text
C:\desenvolvimento\jboss-eap7.4-configuracao\
  preparo.json
  templates\standalone.xml
  valores\valores-local.properties
  modulos\modulos.json
  modulos\jars\driver.jar
  jvm\opcoes.txt
  arquivos\aplicacao.jceks                           # opcional, privado
C:\desenvolvimento\jboss-eap7.4-consolidado\local\       # output, exclusivo do gerador
C:\desenvolvimento\servidores\jboss-eap-7.4\           # eapHome, produto instalado
C:\desenvolvimento\java\jdk8\                         # jdkHome
```

A pasta privada reune entradas e orientacao do ambiente. Execute os
scripts diretamente do harness, informando `-Configuracao` com o caminho de
`preparo.json`; nao precisa copiar scripts nem criar encaminhadores nessa pasta.
O JSON nao depende de `harnessRoot`. O ZIP de transporte deve extrair somente
`jboss-eap7.4-configuracao/`; alinhe o repositorio do harness pelo Git.
Uma copia opcional em `conferencia-harness/` serve apenas para comparacao e pode
ser apagada inteira: os comandos usam os scripts do repositorio, sem fallback
para essa copia. JBoss/JDK continuam nas instalacoes indicadas pelo JSON.

Copie os modelos para a pasta privada e ajuste os caminhos. Caminhos relativos
em `preparo.json` partem da pasta desse JSON; caminhos de JAR e settings Maven
partem da pasta de `modulos.json`. Espacos sao aceitos. Para os caminhos usados
no BAT e opcoes JVM, nao use aspas literais nem `%`, `!`, `^`, `&`, `|`, `<`, `>`.
Nao copie configuracao pessoal de outra maquina sem revisar caminhos e JDK.

| Campo de preparo.json | Preenchimento |
| --- | --- |
| `schemaVersion` | `1` |
| `eapHome`, `jdkHome` | Diretorios da instalacao EAP e do JDK 8 |
| `expectedVersion` | Versao escolhida e verificada, ex. `7.4.11.GA`; nao significa patch recomendado |
| `standaloneConfig` | Nome simples, ex. `standalone-local.xml`, usado tambem no harness |
| `template`, `values` | XML 7.4 com tokens e arquivo de valores |
| `modules` | Manifesto dos modulos adicionais; `modules: []` se nao houver |
| `files` | Lista opcional de arquivos externos, descrita na secao 3.1; omitir ou usar `[]` se nao houver |
| `jvmOptions` | Arquivo UTF-8, uma opcao JVM completa por linha |
| `output` | Pasta exclusiva do consolidado, separada das entradas/EAP/JDK |
| `portOffset` | Inteiro, ex. `100`: HTTP padrao 8180, management padrao 10090 |
| `logSql` | `false` por padrao; detalhes na secao 5 |

Antes do preparo, instale EAP/JDK e confira a versao pelo [roteiro de patches](patches.md).
O script confere `version.txt` e `release` do JDK; isso nao substitui `patch info`,
a matriz de suporte, a conferencia dos pacotes ou o teste de boot.

## 2. Preparar o XML e preencher propriedades

Use como base o perfil do EAP 7.4 escolhido (por exemplo `standalone-full.xml`)
ou o template 7.4 ja revisado da equipe. Confira extensoes, subsistemas,
datasources/drivers, modulos globais, seguranca, mensageria, paths, interfaces
e socket bindings. A copia de um XML 7.1 nao comprova compatibilidade.

Os tokens aceitos sao `__NOME__`, com letras, numeros, `_` ou `.`. Exemplo:

```xml
<property name="servico.endpoint" value="__SERVICO_ENDPOINT__"/>
```

No arquivo de valores: `__SERVICO_ENDPOINT__=http://localhost:8081/exemplo`.
Use texto UTF-8, uma chave por linha, comentarios com `#`. O primeiro `=` separa
chave/valor; os demais fazem parte do valor. Nao adicione aspas ao redor do valor
e nao escape `&` como `&amp;`: o gerador faz o escape XML uma unica vez.
Nao ha interpolacao de variaveis, continuacao de linha nem interpretacao de
escapes Java `.properties`. Valor vazio e permitido somente quando intencional.
Chaves duplicadas, ausentes ou sem token correspondente interrompem o preparo.

Para conferir contra DES, localize o token no template e leia **o nome real do
recurso/propriedade que o usa**. Procure esse nome no XML efetivo de DES e nos
valores fornecidos pela esteira/secret autorizado. Uma expressao `${nome}` ou
um token no XML original nao e o valor efetivo. Copie manualmente o valor
correto para a chave local, ajustando apenas o que o ambiente local exige.
Registre pendencias por nome, nunca por segredo. Nao deduza nomes apenas
convertendo os tokens para minusculas: pontos e sublinhados podem diferir.

O [arquivo ficticio](exemplos/valores-local-ficticios.properties) demonstra o
formato. `ficticio`, URLs de exemplo e numeros provisorios nao comprovam
configuracao funcional. Mantenha a lista de itens ainda nao conferidos junto
aos dados privados do ambiente, sem colocar os valores reais neste roteiro.

## 3. Declarar os modulos: Maven ou pasta local

Edite [modulos.example.json](modelos/modulos.example.json). Cada modulo declara
`name`, `slot`, `dependencies` (nomes de modulos JBoss) e `artifacts`.
O caminho de destino e `modules/<nome dividido por pontos>/<slot>`.
O gerador produz `module.xml` com `resource-root` para cada JAR.
Com schema `module:1.9`, nao escreve atributo `slot`: o slot padrao usa o nome
simples, e um slot personalizado usa `name="nome:slot"`. A pasta continua sendo
`modules/<nome>/<slot>`. Veja a [orientacao Red Hat sobre slots](https://access.redhat.com/solutions/185243).
Declare todas as dependencias necessarias: a copia Maven **nao resolve/transfere
dependencias transitivas** para o modulo.

Escolha a origem de cada artefato explicitamente:

- `source: "maven"`: `coordinates: "grupo:artefato:versao[:jar[:classifier]]"`.
  Usa `mvn.cmd` no PATH (ou `maven.executable` configurado), cache e settings
  normais da maquina. `maven.settings` fica `null`, salvo arquivo corporativo
  explicitamente fornecido. Nao cria repositorio, mirror, POM ou cache paralelo.
- `source: "file"`: `path: "jars/driver.jar"`. Coloque ali o JAR obtido de fonte
  autorizada; funciona sem Maven/rede. Nao ha fallback silencioso entre origens.

Informe exatamente um `sha256` ou `sha1`. Prefira SHA-256 conferido com a fonte;
SHA-1 atende inventarios legados e nao substitui procedencia. Para registrar o
arquivo local: `Get-FileHash -LiteralPath 'C:\...\driver.jar' -Algorithm SHA256`.
Hash calculado sozinho identifica bytes, mas nao autentica o fornecedor.
Nomes de JAR devem terminar em `.jar` e nao conter espacos.
O modelo contem hashes a preencher e nao pode ser usado como instalacao real.

Depois de instalar o modulo, o template precisa referencia-lo onde aplicavel
(driver JDBC, datasource, modulo global etc.). Instalar JAR nao comprova o
driver efetivamente usado pela aplicacao. Confira nome, versao, origem, hash e
associacao no XML/servidor. O mecanismo Maven usa o
[goal oficial dependency:copy](https://maven.apache.org/plugins/maven-dependency-plugin/copy-mojo.html),
fixado em `3.8.1` nos scripts.

### 3.1. Incluir keystores e outros arquivos privados

Crie `arquivos/` na pasta privada somente se precisar desses arquivos. Coloque
ali os arquivos obtidos da origem autorizada, sem alterar seu formato. Declare
em `preparo.json`, por exemplo:

```json
"files": [
  {"source": "arquivos/aplicacao.jceks", "target": "aplicacao.jceks"},
  {"source": "arquivos/integracao.properties", "target": "integracoes/integracao.properties"}
]
```

`source` parte da pasta do JSON (ou e um caminho absoluto externo ao EAP e ao
consolidado). `target` e **relativo a `standalone/configuration`**, no consolidado
e no servidor. Para o arquivo `simtr-keystore.jceks` do ensaio, use esse nome
nos dois campos e mantenha a propriedade XML apontando a
`${jboss.server.config.dir}/simtr-keystore.jceks`. Nao e o `cacerts` do JDK nem
o `application.keystore` de TLS do servidor.

O script copia bytes, inclui o hash no manifesto e nao extrai senhas nem valida
aliases internos. Confira separadamente os aliases e o uso pela aplicacao.
Arquivo ausente, destino duplicado/invalido, link, ou arquivo instalado com
bytes diferentes interrompe o preparo. Arquivo identico conserva suas datas.
Nao ha substituicao forcada: para trocar um keystore existente, concilie as
copias e planeje sua substituicao com o servidor parado. Retirar uma entrada da
lista nao apaga o arquivo ja instalado no EAP.

Destinos aceitam subpastas simples; nao aceitam caminhos absolutos, `..`, nomes
reservados Windows, o XML gerado, `standalone*.xml`, historico XML nem
`logging.properties`. Arquivos entram somente em `standalone/configuration`;
JARs continuam no manifesto de modulos, e opcoes JVM em `jvmOptions`.
Configuracoes existentes sem `files` continuam funcionando.

## 4. Definir a JVM compartilhada

Copie [opcoes.example.txt](modelos/opcoes.example.txt) e ajuste heap, metaspace,
timezone e propriedades necessarias. Uma opcao inteira por linha, sem aspas;
`#` inicia comentario. Inclua explicitamente as opcoes que o ambiente precisa.
O preparo preserva o texto original de `standalone.conf.bat`, limpa heranca de
JAVA_OPTS/variaveis de injecao Java e aplica o JDK e a lista escolhida ao final.
Em nova geracao, substitui somente os blocos gerenciados anteriores.

Nao transponha `standalone.conf` Linux literalmente: caminhos, agentes APM,
truststores, bootclasspath e bibliotecas dos overlays dependem da maquina e do
patch. Resolva essas escolhas antes de usar o arquivo JVM. Senhas em `-D...`
podem aparecer na linha de comando/banner; prefira o mecanismo de segredos
adequado ao recurso e nao publique o banner com credenciais.

## 5. Parar, consolidar e aplicar

Pare o servidor pela tarefa existente ou pelo procedimento administrativo da
equipe. **Mesmo gerar sem aplicar exige servidor parado.** A verificacao le
processos Windows e portas HTTP/management padrao com offset, antes de gerar
e novamente antes de publicar. Falha de consulta ou Java sem visibilidade
impede o preparo. Nao inicie manualmente o servidor durante a operacao; nao
execute dois preparos simultaneos no mesmo destino.

Em um PowerShell aberto na raiz do repositorio:

```powershell
$scripts = Join-Path (Get-Location) 'doc/estrategia-migracao-ambientes-jboss-eap-7.4/jboss-eap7.4-configuracao/scripts'
$configuracao = 'C:\desenvolvimento\jboss-eap7.4-configuracao\preparo.json'
& "$scripts/preparar-eap74.ps1" -Configuracao $configuracao
# Conferir o consolidado em privado. Para publicar no servidor parado:
& "$scripts/preparar-eap74.ps1" -Configuracao $configuracao -Aplicar
```

O primeiro comando deixa o EAP inalterado. O segundo refaz as validacoes e
publica os arquivos completos. Nao copie a pasta inteira sobre o EAP por conta
propria: use `-Aplicar` para respeitar as verificacoes de compatibilidade.
Arquivos temporarios ficam ao lado de `output` e sao retirados ao terminar.
O manifesto `.eap-preparo.json` identifica os arquivos da saida. Nao o edite.

Se o modulo existente tiver exatamente os mesmos JARs e `module.xml` (comparacao
de bytes), ele e mantido, inclusive suas datas. Diferenca, arquivo extra ou
instalacao incompleta interrompe **antes de mudar os arquivos do servidor**.
Isso pode ocorrer com um `module.xml` antigo de formatacao diferente: compare
manualmente e decida como reconciliar; nao ha `force`, limpeza nem substituicao
automatica. Download/valores/XML invalidos preservam servidor e consolidado.
Saida desconhecida, editada ou com arquivos extras tambem e preservada: escolha
outra pasta `output` e mantenha a anterior para analise.

Para diagnostico Hibernate local, configure `logSql: true` ou acrescente
`-LogSql` ao preparo (e a `-Aplicar`, se executar em dois passos). O gerador
ajusta `org.hibernate.SQL=DEBUG` e `org.hibernate.type.descriptor.sql=TRACE`,
sem duplicar loggers nem alterar o template. TRACE pode registrar valores de
parametros: use dados autorizados e desligue apos diagnosticar. O handler
CONSOLE com nivel INFO pode esconder essas mensagens; confira o nivel/filtro
dos handlers e `server.log`. `logSql: false` conserva os niveis do template;
para desligar, regenere com template sem DEBUG/TRACE e aplique parado.

## 6. Iniciar pelo script ou pelo harness

```powershell
& "$scripts/iniciar-eap74-local.ps1" -Configuracao $configuracao -AdminOnly
# Apos conferir e parar o admin-only, iniciar normalmente:
& "$scripts/iniciar-eap74-local.ps1" -Configuracao $configuracao
```

O inicio nao gera XML nem instala modulos. Usa bind local `127.0.0.1`, o offset
configurado e a JVM compartilhada; bloqueia se o alvo/portas ja estiverem ativos.
Alterar entradas requer novo preparo com o servidor parado.

Para a outra forma de inicio, apos aplicar, ajuste **somente estes campos** do
seu `config/harness.local.json`, preservando as demais escolhas:

```json
{
  "tools": {
    "applicationJdk8Home": "C:/desenvolvimento/java/jdk8",
    "eap74Home": "C:/desenvolvimento/servidores/jboss-eap-7.4"
  },
  "eap": {
    "eap74": {"standaloneConfig": "standalone-local.xml", "portOffset": 100}
  }
}
```

Use os mesmos `jdkHome`, `eapHome`, `standaloneConfig` e `portOffset` do preparo.
Execute `Servidor: iniciar JBoss` escolhendo EAP 7.4, conforme o [guia JBoss](../../guias/tools/jboss.md).
O modo debug e uma escolha adicional do harness. Nao inicie as duas formas ao
mesmo tempo. O arquivo nativo compartilhado tambem afeta outras inicializacoes
standalone dessa instalacao; para JVMs independentes, use instalacoes separadas.

## 7. Verificar e repetir na maquina de trabalho

Para atualizar uma instalacao ja ensaiada, siga o
[roteiro de atualizacao da maquina de trabalho](atualizacao-maquina-trabalho.md).
Ele distingue atualizar o harness via Git de aplicar novamente as entradas privadas.

Depois do start normal, execute o [teste de conexao com o banco pela CLI](../../guias/tools/jboss.md#testar-conexao-com-o-banco-apos-o-start)
antes do deploy. O roteiro usa `preparo.json`, permite ajustar a porta e o
pool-name do datasource e mostra o resultado esperado (`success` e `true`).
Nao exige aplicacao implantada; a validacao funcional continua apos o deploy.

Registre versao/patch/JDK, arquivos escolhidos e resultados sem valores secretos.
Confira boot sem erros, XML realmente selecionado, carregamento dos modulos,
datasources/conexoes e integracoes exigidas. Admin-only e XML bem formado nao
comprovam funcionamento da aplicacao; valide depois o artefato correto e os
fluxos necessarios. Testes sinteticos dos scripts nao substituem esse ensaio.

Na outra maquina: obtenha o mesmo codigo, instale EAP/JDK/patch escolhido,
copie as entradas privadas por meio autorizado, revise caminhos e valores de
DES, escolha Maven ou JAR local, pare o alvo, gere, confira, aplique, alinhe os
quatro campos do harness e teste ambas as formas de inicio. Mantenha no registro
as pendencias que dependem da equipe; nao preencha com suposicoes.

## Orientacao pelo helper

```text
Quero configurar um JBoss EAP 7.4 usando um template 7.4 ja revisado.
Leia doc/estrategia-migracao-ambientes-jboss-eap-7.4/jboss-eap7.4-configuracao/README.md.
Meu preparo.json esta em [caminho privado]. Ja conclui [etapas].
Oriente uma etapa por vez: entradas, modulos Maven ou locais, arquivos externos, valores, JVM,
LogSql, consolidacao, aplicacao e inicio pelo script/harness.
Nao exiba valores secretos; indique comando, resultado esperado e pendencias.
```

O helper orienta; o desenvolvedor executa os comandos. Nao exige nome de
aplicacao, MTA ou registro de migracao para esse preparo de servidor. Para trocar
patch, usa [patches.md](patches.md) e pede somente a escolha ainda ausente.
