# Auditoria e retomada do preparo local EAP 7.4 — 21/10/2026

Estado em 21/10: auditoria estatica concluida. Entrega e empacotamento posteriores registrados nas secoes de 22/10 ao final; ensaios operacionais continuam pendentes.
Registro solicitado pelo desenvolvedor para retomar em 22/10/2026.

## Objetivo e limite deste checkpoint

Preparar o JBoss EAP local 7.4 considerando a configuração anterior, o candidato
7.4, o mapeamento recebido e a documentação do harness. A auditoria foi somente
leitura: nenhum script de instalação/inicialização ou CLI foi executado, nenhum
servidor foi iniciado e nenhum arquivo de configuração foi alterado.

Este registro preserva achados e propostas; não declara validação funcional,
paridade com DES ou autorização de implantação. O pedido mais recente foi salvar
os achados. Retomar pelas correções abaixo quando o desenvolvedor pedir continuidade.

## Fontes e localização

- [Material externo 7.1](<C:/Users/edoar/OneDrive/Documents/Edoardo/00_Business_edoardo/00_Software_Architecture/00 Modernizacao_MTR/30_harness-engineering-artigo/estrategia-migracao-ambientes-jboss-eap-7.4/jboss-eap7.1-configuracao/>): `standalone-full-local.xml` e `inventario-configuracoes-eap71-des.md`.
- [Material externo 7.4](<C:/Users/edoar/OneDrive/Documents/Edoardo/00_Business_edoardo/00_Software_Architecture/00 Modernizacao_MTR/30_harness-engineering-artigo/estrategia-migracao-ambientes-jboss-eap-7.4/jboss-eap7.4-configuracao/>): `standalone-okd.xml`, `standalone.conf`, launcher, instalador, arquivos de valores e pendência de atualização do guia.
- [Mapeamento auditado](<C:/Users/edoar/OneDrive/Documents/Edoardo/00_Business_edoardo/00_Software_Architecture/00 Modernizacao_MTR/30_harness-engineering-artigo/estrategia-migracao-ambientes-jboss-eap-7.4/jboss-eap7.4-referencias/mapeamento-eap71-des-eap74.md>).
- [Instalação local](<C:/desenvolvimento/servidores/jboss-eap-7.4/>).
- [Estratégia](estrategia-migracao-ambientes-jboss-eap-7.4.md), [guia Windows/DES](guia-operacional-jboss-eap-7.4-windows-des.md), [manifesto](manifesto-ambiente-local-jboss-eap-7.4.yaml) e [verificador](verificar-manifesto-eap74.ps1).
- [Guia de migração da configuração](../guias/tools/migracao-configuracao-jboss.md) e [runtime JBoss do harness](../../scripts/HarnessJbossRuntime.psm1).

Os caminhos externos identificam esta máquina; sua existência em outra máquina
precisa ser conferida. As linhas citadas abaixo correspondem à leitura de
21/10/2026 e podem mudar. Não há valores de credenciais neste registro.

## Estado comprovado na auditoria

| Item | Evidência e limite |
| --- | --- |
| Instalação EAP | `version.txt`: 7.4.11.GA; `.installation/JBoss EAP.conf`: `jboss-eap-7.4.11.CP`. |
| JDK | `C:/desenvolvimento/java/jdk8u504-b01/release`: Eclipse Adoptium 1.8.0_504, amd64, JDK; corresponde ao manifesto local. |
| Configuração instalada | Arquivos padrão; `standalone.xml` e `standalone-full.xml` têm apenas ExampleDS/H2. `standalone-okd.xml` ainda ausente. |
| Módulos e aplicações | Diretório `modules` apenas com `system`; módulos customizados Oracle/JasperReports ausentes; deployments apenas com README. |
| Processo | Nenhum processo Java JBoss nem listener 10090/8180 encontrado no momento da consulta. Revalidar antes de qualquer escrita. |
| Logs locais | Boot/patch e parada em 20/10; não comprovam a execução do candidato auditado. A validação administrativa declarada no mapeamento não foi reproduzida nesta auditoria. |
| Substituição de tokens | Cada arquivo de valores tem 96 chaves únicas, correspondentes aos 96 tokens do template; sem faltas, duplicações ou extras. |
| Propriedades XML | Origem local: 73; candidato: 78 = 62 comuns + 16 novas, com 11 retiradas. Os 62 valores comuns são idênticos após renderização em memória com o arquivo real. |
| Sintaxe | XMLs renderizados em memória bem formados, sem tokens restantes; ambos os scripts passaram pelo parser PowerShell. Isso não valida modelo administrativo ou runtime. |
| Documentos compartilhados | Manifesto, verificador, instruções do patch e roteiro de replicação têm conteúdo idêntico nas duas pastas comparadas. |

## Achados e correções propostas

### A1 — Inicialização divergente entre harness, launcher e manifesto

Evidências: `config/harness.local.json:49` seleciona `standalone.xml` para EAP 7.4;
manifesto, linha 35, informa `standalone-full.xml`; launcher, linhas 59 e 79,
prepara/inicia `standalone-okd.xml`.

O `Start-JbossProcess` em `HarnessJbossRuntime.psm1:129` não chama o launcher
externo, limpa `STANDALONE_CONF` e não define as opções Java que ele compõe.
`JAVA_OPTS` pode ser herdado do ambiente. Em um terminal limpo, não presumir as
mesmas opções de heap, GC, encoding, fuso e identidade de nó.

Correção proposta: distinguir perfil full de arquivo efetivo de boot; escolher
um contrato de inicialização e alinhar configuração local, manifesto e opções
JVM. O `standalone.conf` recebido é Linux/DES, não a configuração do Windows.
Conferir a [documentação oficial de inicialização](https://docs.redhat.com/en/documentation/red_hat_jboss_enterprise_application_platform/7.4/html/configuration_guide/starting_and_stopping_jboss_eap).

### A2 — Launcher grava antes da proteção contra servidor ativo

Evidência: `iniciar-eap74-local.ps1:59–67`. `WriteAllText` ocorre na linha 60;
`-SomenteGerar` retorna em 62; a verificação de portas só ocorre em 65.
Uma nova chamada pode substituir a configuração persistida antes de recusar o
start; `-SomenteGerar` ignora essa verificação. Defeito demonstrado por leitura
do fluxo, sem reprodução no servidor real.

Correção proposta: verificar servidor/destino antes de qualquer escrita ativa,
validar o XML preparado e publicar somente o resultado completo. A geração para
inspeção também deve preservar a configuração ativa.

### A3 — Download interrompido deixa módulo parcial e impede nova tentativa

Evidência: `instalar-modulos-eap74.ps1:24–34`. A pasta definitiva é criada antes
do download; falha de rede deixa pasta/JAR parcial, sem `module.xml`. A próxima
chamada recusa a pasta existente. Há limpeza apenas para SHA-1 divergente.

Correção proposta: baixar e verificar em área temporária delimitada, publicar
depois e preservar módulos preexistentes. Verificar retomada após falha sem
usar a instalação operacional como fixture.

### A4 — Valores funcionais incompletos e guarda incoerente com o guia

Evidência: `valores-local.properties:96–111` mantém 16 valores fictícios na seção
de revisão; mapeamento, linhas 503–515, reconhece a lacuna. Os arquivos
classificados como contendo dados reais estão no OneDrive, embora o launcher,
linha 10, e o mapeamento, linha 407, orientem guardá-los fora de Git/OneDrive.
Não foram verificadas sincronização, exposição ou validade desses valores.

Correção proposta: separar exemplos fictícios de valores reais locais; revisar
as 16 entradas e referências de truststore/proxy/fuso antes do teste funcional.
Não copiar segredos para o repositório, para este relatório ou para logs.

### A5 — Driver efetivo do DES tratado como comprovado por inferência

Evidência: mapeamento, linhas 114–118. A instalação de `com.oracle.ojdbc8` pela
esteira não demonstra qual valor substitui o token do driver no datasource da
origem. O inventário também não comprova todos os módulos da imagem.

Correção proposta: separar origem ainda não confirmada de escolha explícita de
`ojdbc8` para o destino. Confirmar o valor pela configuração da esteira/responsável
e registrar compatibilidade/testes do destino. Não foi constatado que a escolha
de `ojdbc8` esteja errada.

### A6 — Manifesto e critérios de conclusão não identificam todo o candidato

Evidências: manifesto, linhas 10–39, ainda tem origem, driver, SSO e WAR pendentes;
mapeamento, linha 534, afirma que não há pendências bloqueantes para A/B, mas
ORG-07 afeta B5 (linha 542), há versões divergentes do artefato (linha 140) e
fuso dependente de ESTEIRA-11 (linhas 213–217).

Correção proposta: distinguir instalação/patch, validação estrutural, teste
funcional local e comparação com DES. Identificar template, arquivo de boot,
valores por referência sem segredos, driver, disposição SSO e WAR versão/hash.
Registrar fuso confirmado ou limite do teste. `FALHA=0` no verificador do
manifesto não comprova boot/deploy: ele verifica existência do perfil, não sua
configuração efetiva em execução. A atualização do guia já está reconhecida em
`pendencia-atualizar-guia-operacional.md` e continua pendente.

## Decisões preservadas e limites conhecidos

- Candidato específico do SIMTR-api: nove datasources viram um (`simtrPU`, JNDI
  `java:jboss/datasources/simtr-ds`), também referenciado em `default-bindings`.
  Não é réplica de todo o antigo servidor compartilhado.
- Remoções de outros datasources, domínios, módulos antigos, gerenciamento nativo
  e listener HTTPS estão documentadas no mapeamento, especialmente 523–531.
- Oracle `com.oracle.ojdbc8` e fontes `net.sf.jasperreports.fonts` são coerentes
  entre template e instalador. Permanecem mail `expresso`, filas ExpiryQueue/DLQ
  e fábrica JMS XA.
- Remover a extensão Keycloak residual e não instalar adaptador é decisão
  documentada. Conferir descritores/dependências do WAR e autenticação antes de
  confirmar aplicabilidade; não instalar adaptador apenas por hábito.
- HTTP ainda referencia redirecionamento HTTPS, sem listener HTTPS local.
  Funcionalidades que exijam transporte seguro precisam de validação específica.
- Agentes de monitoramento e bootclasspath do Linux/DES não foram testados em
  conjunto. Boot Windows sem agentes não comprova a configuração futura da imagem.

## Sequência de retomada

1. Reler este checkpoint e conferir mudanças nas fontes e no servidor desde a
   auditoria. Preservar configurações/evidências existentes.
2. Corrigir A2/A3 nos scripts de preparo e verificar os cenários de falha em
   ambiente isolado. Definir onde manter suas versões corrigidas, sem transportar
   os arquivos sensíveis para o harness.
3. Alinhar arquivo de boot/JVM/manifesto (A1/A6); registrar escolha do driver e
   lacuna da origem (A5). Atualizar as orientações afetadas.
4. Instalar os dois módulos verificados, preparar valores locais conforme A4 e
   gerar a configuração com servidor parado. Inspecionar o resultado sem expor
   valores sensíveis.
5. Validar modelo administrativo e depois boot normal; guardar evidências
   legíveis, mensagens de erro e limitações. Parser XML não substitui essas etapas.
6. Na máquina com aplicação e acessos necessários, fixar WAR versão/hash e testar
   Oracle, autenticação, integrações, relatórios/fontes e comportamento de datas.
7. Atualizar manifesto e este registro com resultados reais; separar pendências
   do ensaio local da comprovação de equivalência com DES.

Primeira retomada sugerida: corrigir A2/A3 e decidir o alinhamento A1, antes de
executar os scripts contra `C:/desenvolvimento/servidores/jboss-eap-7.4`.

## Controle documental

Checkpoint salvo na branch `harness/auditoria-preparo-eap74`, criada da `main`
em `d0ba820d75b6dac50a4f71589dac5c7f21c428a9`. Esse identificador registra apenas
a base documental do harness; não constitui precondição Git da migração.
As únicas alterações desta etapa são este documento e os ponteiros em tasks/.
Implementação das correções, boot, deploy e testes funcionais continuam pendentes.

## Retomada autorizada e entrega de preparo — 22/10/2026

O desenvolvedor auditou as escolhas no chat e autorizou proceder. A evolucao
permanece na branch `harness/auditoria-preparo-eap74`, sem commit ou push.
O estado acima descreve o checkpoint original; esta secao registra a entrega
posterior, sem atribuir aos testes sinteticos um resultado operacional.

A referencia corrente e o [roteiro reutilizavel](jboss-eap7.4-configuracao/README.md),
com scripts/modelos versionados e [patches 7.4.XX](jboss-eap7.4-configuracao/patches.md).
Guia do desenvolvedor e helper apontam para ela. O preparo recebe entradas
privadas, aceita Maven ou JAR local, gera consolidado e publica com `-Aplicar`.
Exige servidor parado inclusive ao gerar; o inicio usa XML/JVM ja instalados.

| Achado | Resultado desta entrega | Conferencia operacional restante |
| --- | --- | --- |
| A1 | Mesmo XML, JDK, offset e standalone.conf.bat definidos para script/harness | Aplicar o candidato parado e alinhar os quatro campos de harness.local.json; conferir ambos os boots |
| A2 | Guarda antes de escrita e rechecagem antes de publicar; XML validado antes do destino | Ensaio real com os valores conferidos |
| A3 | Modulos completos em area temporaria, hashes, repeticao sem regravar identicos; divergentes/incompletos preservados | Conferir procedencia dos JARs e instalar o candidato |
| A4 | Orientacao manual dos 16 itens na pasta privada, com nomes reais de propriedades | Preencher/conferir contra DES; nenhum valor inventado ou substituido |
| A5 | Candidato Oracle/Jasper declarado em manifestos Maven/local, sem alegar equivalencia com DES | Obter evidencia do driver/JAR efetivo de DES |
| A6 | Roteiro manual, helper e documentos privados alinhados; instrucoes antigas identificadas como historico | Registrar JDK/patch, fuso, WAR e resultados funcionais efetivamente verificados |

Na pasta externa indicada, foram adaptados 11 arquivos de orientacao,
encaminhamento e configuracao, incluindo `preparo-local.json`, manifestos
Maven/local e opcoes JVM. Os dois arquivos de propriedades, `standalone-okd.xml`
e `standalone.conf` foram conferidos por SHA-256 antes/depois e preservados byte
a byte. Os caminhos ficam configuraveis e a saida sugerida fica fora da pasta
sincronizada. Os 16 valores pendentes continuam pendentes (14 marcados e dois
numeros). Nao foram baixados/copiados JARs nem alterada a instalacao JBoss.

Validacao das entradas reais **somente em memoria**, sem exibir conteudo:
96 tokens preenchidos; XML normal e com LogSql bem formados; JVM preparada.
Isso nao valida semantica do modelo EAP nem conexoes/integracoes.

Verificacoes pelo executor `tests/Invoke-HarnessTests.ps1`, em copia temporaria:

- `Test-Eap74Preparation.ps1`: PASS em PowerShell 5.1 e 7; inclui servidor ativo,
  erros de consulta, rechecagem, XML/escape, LogSql, hashes, Maven parcial,
  modulos identicos/divergentes/incompletos, saida humana preservada, rollback
  de publicacao e launcher batch sintetico com caminhos contendo espacos.
- `Test-JbossRuntime.ps1`, `Test-CurrentPromptLinks.ps1` e
  `Test-ClaudeAdapter.ps1`: PASS.
- Referencias locais e `git diff --check`: conferidos.

Nao houve boot, deploy ou patch real nesta entrega. CP11 permanece instalado;
outro cumulativo exige escolha e evidencia conforme Red Hat. A matriz consultada
mantem pendente a comprovacao formal da combinacao Temurin 8/Windows do ensaio.
Proximo passo operacional: completar as entradas privadas, conferir procedencia
dos modulos e seguir o roteiro de consolidacao/aplicacao com o alvo parado.

## Organizacao final e ZIP para a maquina de trabalho — 22/10/2026

Por escolha posterior do desenvolvedor, os encaminhadores foram retirados e
o JSON passou a se chamar preparo.json, sem harnessRoot. O uso e direto pelos
scripts do harness. O layout externo agora e templates/, valores/, modulos/
e jvm/. O template passou a templates/standalone.xml; o nome de saida no servidor
continua standalone-okd.xml. As referencias a nomes antigos acima sao historicas.

O guia especifico GUIA-SIMTR-LOCAL.md fica na pasta privada, com a sequencia
completa e os 16 itens a conferir. README.md indica a entrada. O exemplo ficticio
permanece em valores/, separado do arquivo ativo. standalone.conf Linux,
mapeamento e pendencias anteriores foram movidos para a pasta irma
jboss-eap7.4-referencias, preservados byte a byte e excluidos do pacote.

Os JARs Oracle 19.22.0.0 e JasperReports Fonts 6.16.0 foram obtidos pelo Maven da
maquina, usando os defaults, e conferidos contra os SHA1 declarados no inventario.
Estao em modulos/jars/. O manifesto local modulos/modulos.json e o padrao do
pacote; modulos/modulos-maven.json continua como alternativa explicita.
A origem/versao efetiva de DES ainda precisa de evidencia.

A primeira versao do ZIP externo preparo-jboss-eap7.4-maquina-trabalho.zip
continha 23 arquivos (6,39 MiB), comparados por SHA256, com as entradas privadas
e o diretorio generico de preparo sob repositorio/jboss-mta-harness/doc/.
Essa versao foi substituida pela escolha registrada abaixo. O pacote inclui
valores privados e permanece fora do Git; nao inclui JDK, instalacao JBoss nem WAR.

Validacao apos a reorganizacao: XML normal/LogSql e JVM em memoria, caminhos,
hashes dos dois JARs e preservacao dos arquivos realocados. Nenhum preparo foi
aplicado ao servidor, nenhum boot/deploy/patch executado e nenhum valor real
preenchido automaticamente. O consolidado configurado sera gerado em
C:\desenvolvimento\jboss-eap7.4-consolidado\local, fora das entradas.

## Repositorio como fonte dos scripts — 22/10/2026

O desenvolvedor escolheu alinhar os scripts pelo Git do harness, preservando
o repositorio como fonte oficial. O ZIP foi substituido no mesmo caminho e
agora contem 18 arquivos (6,38 MiB), todos sob jboss-eap7.4-configuracao/.
Extrair em C:\desenvolvimento nao grava no checkout do harness.

A subpasta privada conferencia-harness/ contem um README e copias identicas
dos seis scripts, apenas para comparacao. Pode ser apagada inteira; nenhum
comando de execucao ou campo do preparo.json depende dela. O guia privado
e o roteiro generico indicam os scripts no repositorio, sem fallback para a
copia. Nenhum script do checkout foi sobrescrito por esta reorganizacao.

Verificacao: SHA256 de cada entrada do ZIP comparado com sua origem, copias
dos seis scripts conferidas e nove entradas privadas preservadas byte a byte.
Documentos de entrada e guia SIMTR atualizados. Nenhuma configuracao foi
aplicada ao EAP. As alteracoes do harness continuam locais na branch
harness/auditoria-preparo-eap74, sem commit/push; sua disponibilizacao pelo
Git deve preceder a atualizacao na maquina de trabalho.
