# Proposta: perfis de preparo EAP 7.4

Data: 03/11/2026. Estado: especificacao aprovada, implementacao solicitada pelo
desenvolvedor. Evolucao do harness conforme a
[ADR-0002](../adr/0002-separacao-harness-e-migracao-progressiva.md).
Checkpoint em [plan.md](../../tasks/plan.md) e [todo.md](../../tasks/todo.md).

## Objetivo e decisoes confirmadas

Preparar configuracoes distintas na mesma instalacao local EAP 7.4.11, escolhendo
um perfil em preparo.json. Os scripts pertencem ao harness; nomes de aplicacoes
sao dados da configuracao. Primeiro uso: simtr-api e simtr-outsourcing-api.

Confirmado pelo desenvolvedor:

- Alternar um perfil ativo por vez; nao executar ambos simultaneamente.
- Manter os drivers, modulos e JARs ja migrados do simtr-api.
- Separar as pastas de deployments dos perfis.
- Separar template, valores reais/ficticios, JVM e consolidado do outsourcing.
- Usar o inventario fornecido e os valores locais, sem inventar configuracao.
- A maquina de trabalho ja executa o SIMTR e recebeu ajustes conforme suas
  instalacoes. Esses caminhos, valores e ajustes sao a referencia da atualizacao.

A atualizacao sera incremental: preservar o SIMTR instalado e acrescentar o
outsourcing. Proposta ajustada apos esse esclarecimento: conservar o scanner do
SIMTR em standalone/deployments e usar standalone/deployments-outsourcing para
o outsourcing. Sao pastas irmas, sem mover os WARs do SIMTR ou colocar um perfil
dentro da pasta escaneada pelo outro.

## Fontes e comportamento atual

O [modelo atual](../estrategia-migracao-ambientes-jboss-eap-7.4/jboss-eap7.4-configuracao/modelos/preparo.example.json)
usa schemaVersion=1 e uma combinacao de entradas/saida. O
[parser](../estrategia-migracao-ambientes-jboss-eap-7.4/jboss-eap7.4-configuracao/scripts/Eap74Inputs.ps1)
resolve caminhos relativos ao JSON e exige cobertura exata dos tokens.
O [preparo/iniciador](../estrategia-migracao-ambientes-jboss-eap-7.4/jboss-eap7.4-configuracao/scripts/Eap74Preparation.psm1)
gera XML e bin/standalone.conf.bat compartilhado, exige servidor parado e aplica
somente com -Aplicar. O iniciador ja seleciona standaloneConfig pelo argumento -c;
sua conferencia atual de JVM verifica marcacao/JDK, insuficiente para distinguir
opcoes de perfis diferentes.

O [runtime do harness](../../scripts/HarnessJbossRuntime.psm1) usa
eap.eap74.standaloneConfig da configuracao local do workspace. O
[deploy](../../scripts/HarnessJboss.psm1) envia o WAR pela CLI, nao pelo scanner.
Essas tarefas hoje nao leem preparo.json. Documentar o alinhamento de XML/portas
no workspace, sem prometer sincronizacao automatica inexistente nem criar uma
Run Task por aplicacao. Separar scanners nao isola deployments gerenciados pela
CLI, logs, dados internos ou configuracao JVM.

Fontes privadas sob a pasta de estrategia indicada pelo desenvolvedor:

| Fonte | Uso |
| --- | --- |
| jboss-eap7.1-configuracao/inventario-configuracoes-eap71-out.md | Escopo de propriedades/recursos do outsourcing em DES; caminhos Linux e placeholders nao sao valores locais. |
| jboss-eap7.1-configuracao/standalone-full-local.xml | Valores locais existentes; recursos de outras aplicacoes nao serao copiados integralmente. |
| jboss-eap7.4-configuracao/templates/standalone.xml | Base adaptada para 7.4 do SIMTR. |
| jboss-eap7.4-configuracao/valores/valores-local.properties | Valores disponiveis nesta maquina; nao substituem ajustes posteriores da maquina de trabalho. |
| jboss-eap7.4-configuracao/modulos/modulos.json e modulos/jars/ | Manifesto/JARs compartilhados; preservar os descritores corrigidos e validados no trabalho. |
| jboss-eap7.4-configuracao/jvm/opcoes.txt e preparo.json | Referencia local; destinos e ajustes efetivos devem vir da maquina de trabalho ao atualizar. |

Comparacao em memoria das 49 propriedades de sistema do inventario outsourcing:
38 presentes no XML local 7.1 e no 7.4 atual tem valores iguais. Oito adicionais
existem no 7.4 atual: simtr_sso_client_secret_internet, cpf_generico_sinda,
simtr.keystore.mtr.alias, simtr.keystore.mtr.secret, http.numTentativasRetry,
http.waitTentativasRetry, simtr_documento_validacao_limite_score_autenticidade e
feature_novos_campos_identidade_fiscal. Tres especificas estao no XML local 7.1:
url.simtr.outsourcing.api, simtr.outsourcing.resource.sso.filter e
url.gestao.documento. Valores reais nao sao publicados neste documento.

Essa comparacao identifica origem; nao comprova credenciais, servicos ou
equivalencia funcional. Conferir outros recursos antes de fechar o novo template.
Conservar o JNDI java:jboss/datasources/simtr-ds, pool simtrPU, driver ojdbc8,
modulo com.oracle.ojdbc8/ojdbc8-19.22.0.0.jar e modulo
net.sf.jasperreports.fonts/jasperreports-fonts-6.16.0.jar da configuracao migrada.
Nao restaurar registros Oracle legados apenas por constarem no inventario.

## Interface proposta

Preservar schemaVersion=1 e os comandos atuais. Acrescentar schemaVersion=2 com
profiles e parametro -Perfil nos scripts de preparo/inicio. Com profiles,
selecao explicita obrigatoria; nome ausente/desconhecido informa as opcoes.

Campos comuns na raiz: eapHome, jdkHome, expectedVersion, modules, files,
portOffset e logSql. Cada perfil declara standaloneConfig, template, values,
jvmOptions e output. Sem sobrescrita dos campos comuns nesta primeira versao.
Resolver caminhos relativos ao preparo.json e gerar um perfil por chamada.

Fragmento proposto para integrar ao preparo.json existente (nao substitui o
arquivo completo nem seus caminhos/valores locais):

```json
{
  "schemaVersion": 2,
  "profiles": {
    "simtr": {
      "standaloneConfig": "standalone-okd.xml",
      "template": "templates/standalone.xml",
      "values": "valores/valores-local.properties",
      "jvmOptions": "jvm/opcoes.txt",
      "output": "../jboss-eap7.4-consolidado/simtr-api/local"
    },
    "outsourcing": {
      "standaloneConfig": "standalone-outsourcing.xml",
      "template": "templates/standalone-outsourcing.xml",
      "values": "valores/valores-local-outsourcing.properties",
      "jvmOptions": "jvm/opcoes-outsourcing.txt",
      "output": "../jboss-eap7.4-consolidado/simtr-outsourcing-api/local"
    }
  }
}
```

standalone-okd.xml e o nome encontrado nas entradas atuais desta maquina; se a
maquina de trabalho usa outro, preservar seu nome. Consolidado fica fora das
entradas, EAP e JDK; o caminho efetivo deve manter a raiz escolhida pelo usuario.
Nao mover/apagar o consolidado anterior ao adotar a organizacao por aplicacao.

## Arquivos e operacao

Acrescentar na pasta privada jboss-eap7.4-configuracao:

```text
templates/standalone-outsourcing.xml
valores/valores-local-outsourcing.properties
valores/valores-local-ficticios-outsourcing.properties
jvm/opcoes-outsourcing.txt
```

Usar a grafia outsourcing nos novos arquivos (o pedido inicial escreveu
outsorucing). Os arquivos existentes do SIMTR, JARs e manifesto permanecem.
Exemplo ficticio deve estar identificado e separado dos valores ativos; nunca
copiar segredos para exemplos. Documentar a origem das entradas reais e perguntar
quando houver lacunas. A JVM inicial reaproveita escolhas locais conhecidas;
ajustes efetivos no trabalho precisam ser preservados, inclusive timezone quando
configurado. Nao importar agentes/caminhos Linux do inventario por suposicao.

Os XMLs instalados ficam em standalone/configuration. O iniciador passa -c com
o standaloneConfig do perfil escolhido. O scanner outsourcing usa
path="deployments-outsourcing" relativo a jboss.server.base.dir; o SIMTR conserva
seu scanner atual. Nao mover, apagar ou implantar WARs automaticamente.

Distinguir preparacao/aplicacao de inicio/alternancia:

- Preparar publica apenas o consolidado selecionado; aplicar publica o perfil
  explicitamente solicitado no EAP parado, indicando arquivos compartilhados.
- Iniciar perfil ja instalado seleciona XML/JVM sem regenerar o XML nem perder
  registros de deployment feitos pela CLI. A troca exige parada anterior.
- JVM v2 em bin/eap74-preparo-<nome-do-xml-sem-extensao>.conf.bat, selecionada por
  STANDALONE_CONF; JVM global v1 preservada. Inicio normal/debug resolve a mesma
  associacao generica. Iniciador do preparo verifica opcoes/JDK instalados;
  divergencia exige revisar/aplicar, sem iniciar com opcoes incorretas.
- Reaplicar template sobre XML alterado pelo runtime exige tratar a diferenca
  explicitamente: v2 recusa XML divergente por padrao. -SubstituirXml permite
  substituicao deliberada junto com -Aplicar, apos conferencia e preservacao dos
  registros relevantes pelo desenvolvedor. Inicio nunca usa essa operacao.

Logs e dados internos continuam compartilhados. Nao introduzir segunda
instalacao, portas adicionais ou gerenciamento de instancias simultaneas.

## Atualizacao da maquina de trabalho

1. Atualizar os scripts pelo Git quando a evolucao estiver revisada e integrada.
   Compatibilidade v1 permite continuar usando o preparo atual do SIMTR.
2. Acrescentar os novos arquivos privados do outsourcing. Nao copiar a pasta
   inteira por cima da que recebeu ajustes na maquina de trabalho.
3. Incorporar profiles ao preparo.json preservando EAP, JDK, patch, modulos,
   arquivos externos, portas, valores e opcoes JVM efetivamente usados ali.
4. Conferir as entradas outsourcing contra as fontes e ajustes dessa maquina;
   gerar somente seu consolidado. Isso nao reaplica o SIMTR.
5. Na aplicacao autorizada, parar o EAP, conferir diferencas e instalar o novo
   XML. Modulos identicos sao reutilizados; divergencias nao sao sobrescritas
   a forca. JVM compartilhada exige conferencia antes de qualquer substituicao.
6. Iniciar com o XML escolhido, alinhar a configuracao local do harness e
   verificar boot/driver/datasource antes do deploy e dos testes funcionais.

Nao reinstalar nem reaplicar o patch do EAP como parte dessa atualizacao. Nao
reaplicar o XML SIMTR para habilitar outsourcing. Atualizacao dos scripts e
copia de entradas nao significam aplicacao no servidor nem aceite operacional.

## Comandos, estrutura e estilo

Interface proposta: -Perfil ainda nao existe. Exemplo na raiz do harness, usando
o caminho privado efetivo da maquina de trabalho:

```powershell
$preparoScripts = Join-Path (Get-Location) 'doc/estrategia-migracao-ambientes-jboss-eap-7.4/jboss-eap7.4-configuracao/scripts'
$preparoConfig = 'C:/desenvolvimento/jboss-eap7.4-configuracao/preparo.json'
& "$preparoScripts/preparar-eap74.ps1" -Configuracao $preparoConfig -Perfil outsourcing
# Aplicacao explicita, com EAP parado:
& "$preparoScripts/preparar-eap74.ps1" -Configuracao $preparoConfig -Perfil outsourcing -Aplicar
& "$preparoScripts/iniciar-eap74-local.ps1" -Configuracao $preparoConfig -Perfil outsourcing
```

Scripts/modelos/guia ficam na pasta canonica
doc/estrategia-migracao-ambientes-jboss-eap-7.4/jboss-eap7.4-configuracao/;
testes em tests/ e direcao em doc/engineering-harness/. Nao manter copias de
scripts na pasta privada como outra fonte de manutencao.

PowerShell 5.1 compativel; parametros publicos em portugues, funcoes internas
em ingles e validacoes antes da escrita. Padrao existente a estender:

```powershell
[CmdletBinding()]
param([Parameter(Mandatory)][string]$Configuracao,[switch]$Aplicar,[switch]$LogSql)
$ErrorActionPreference='Stop'
Import-Module "$PSScriptRoot/Eap74Preparation.psm1" -Force -DisableNameChecking
Invoke-EapPreparation -ConfigPath $Configuracao -Apply:$Aplicar -LogSql:$LogSql
```

## Verificacao e conclusao

Testes com dados sinteticos e nomes neutros de perfis: compatibilidade v1;
selecao v2; erros antes de escrita; colisoes de XML/saida; saidas nao sobrepostas;
preservacao do outro perfil; modulos identicos/divergentes; scanners separados;
XML/JVM corretos; preservacao de deployments CLI; falhas durante publicacao;
servidor ativo; inicio normal/debug e preservacao de configuracao humana.
Conferir cobertura exata dos tokens e XML privado sem imprimir valores.

Suites de manutencao pelo runner isolado, com novos arquivos adicionados ao Git:

```powershell
& ./tests/Invoke-HarnessTests.ps1 -Test Test-Eap74Preparation.ps1,Test-Eap74ModuleLoading.ps1,Test-JbossRuntime.ps1,Test-JbossLegacyLauncher.ps1
git diff --check
```

Sempre preservar fontes privadas, ajustes da maquina de trabalho, drivers/modulos
atuais, schema legado e controles de publicacao. Perguntar por valor sem fonte,
divergencia de significado ou mudanca adicional de comportamento. Nunca
versionar segredos, limpar dados para demonstracao, forcar modulos divergentes
ou inserir condicoes por nome SIMTR nos scripts.

Concluir quando os dois conjuntos estiverem coerentes com suas fontes, a
selecao generica estiver verificada, a alternancia preservar deployments e o
roteiro de atualizacao estiver pronto. XML valido nao comprova boot, conexao,
SSO, keystore ou funcoes da aplicacao; registrar evidencias e limites reais.
Nesta etapa documental nenhum servidor ou arquivo privado e alterado.

## Aprovacao e continuidade

As escolhas de uso foram respondidas e o desenho foi aprovado com pedido de
implementacao e atualizacao da pasta privada/README/guia. O plano tecnico consta
em tasks/plan.md. A conferencia detalhada dos recursos pode revelar lacunas;
elas serao apresentadas com sua origem, sem preencher valores por suposicao.
