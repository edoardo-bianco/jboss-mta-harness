# Validacao da configuracao de desenvolvimento

Atualizacao: 22/10/2026. Escopo confirmado pelo desenvolvedor: revisar os
arquivos de configuracao fornecidos, preparar os ajustes e manter o local
alinhado ao DES 7.1 onde uma mudanca nao seja necessaria. A construcao da imagem,
a pipeline Azure DevOps e os manifests/operacao OKD sao de outra equipe.
Nao solicitar esses arquivos como precondicao para concluir nossas correcoes.

Decisao de 23/10/2026: a analise e validacao de DES permanecem pendentes para
retomada posterior. O desenvolvedor autorizou commit, push e PR das correcoes
do harness (modulos, arquivos externos, restart e logs) separadamente. Essa
entrega nao encerra os achados abaixo nem comprova execucao ou aceite em DES.

O [roteiro generico de DES](../jboss-eap7.4-configuracao/des.md) descreve a
entrega e os pontos de conferencia de cada responsavel. Esta pasta registra
o caso ja auditado; a segunda aplicacao ainda sera fornecida e tera exame proprio.

## Base examinada e limites

Para `simtr-api`, as fontes privadas sao:

- `jboss-eap7.1-configuracao/inventario-configuracoes-eap71-des.md`: trechos do
  repositorio de configuracao (F1, linhas 43 a 887), incluindo XML DES no bloco
  67 a 775, e trechos da aplicacao (F2, a partir da linha 891).
- `jboss-eap7.1-configuracao/standalone-full-local.xml`: referencia local antiga,
  que nao deve ser confundida com o XML original de DES.
- `jboss-eap7.4-configuracao/templates/standalone.xml`: candidato compartilhado.
- `jboss-eap7.4-referencias/standalone-des.conf` e mapeamento historico: proposta
  Linux, ainda sem evidencia de execucao na imagem.
- `jboss-eap7.4-configuracao-des/simtr-api/AUDITORIA-EAP71-EAP74.md`: evidencias,
  comparacoes e referencias tecnicas completas na estrutura privada fornecida.

Os caminhos acima sao relativos a raiz privada da estrategia, fora do Git.
Este registro nao copia valores reais, XML renderizado nem arquivos de segredo.
A comparacao preservou as 78 associacoes de propriedades de sistema e tokens.
O candidato tem 96 tokens contra 97 na origem: retirou `__ORACLE_JDBC_DRIVER__`.
Essa diferenca e uma decisao pendente, nao prova de equivalencia completa.

Na maquina de trabalho ja foram confirmados boot normal EAP 7.4.11, driver
Oracle 19.22, datasource vinculado e teste de conexao com `success`/`true`.
Isso valida aquele recorte local. Deploy/fluxos da aplicacao e execucao em DES
ainda nao tem evidencia de aceite neste registro.

## Pendencias sobre os arquivos que estao no nosso escopo

| Item | O que falta decidir/verificar | Efeito possivel na maquina de trabalho |
| --- | --- | --- |
| DES-01: origem | Usar o XML DES de F1 como referencia; nao incorporar os 9 datasources do XML local como requisitos de DES. Comparacao documental feita; revisao realmente implantada cabe ao responsavel pelo ambiente | Nenhuma troca de valores locais por valores de outro ambiente |
| DES-02: manifestos e CLI | Separar os arquivos F1/F2: Jasper aparece em deployments no primeiro conjunto; o segundo tambem instala modulos e agente. Revisar nomes, destinos e evitar instrucoes duplicadas no pacote de configuracao; consumo/ordem efetiva e confirmacao externa | Somente se mudar modulo/JAR aprovado; nao copiar agente Linux para Windows |
| DES-03: JDBC | Origem parametriza driver e declara oracle/com.oracle.jdbc e ojdbc8/com.oracle.ojdbc8; candidato fixa ojdbc8. Revisar se conservar o token e necessario e qual contrato de modulo deve permanecer | Possivel retorno do token no template/propriedades; Oracle local funcional deve ser preservado ate decisao |
| DES-04: pool EJB | Origem usa 64 threads/100 ms; candidato 64/60 s. Recomendacao: conservar 100 ms, pois nao foi demonstrada necessidade de alterar; revisar e ensaiar a correcao no template comum | Atualizar template, regenerar/aplicar parado e conferir boot/fluxos EJB |
| DES-05: Keycloak e gerenciamento | Verificar referencias que justifiquem retirar extensao Keycloak e native-interface/9999. A ausencia de subsistema Keycloak nao basta para provar desuso | Eventual ajuste no template/modulos; validar SSO e acessos. Metodo de deploy da plataforma fica com a outra equipe |
| DES-06: JVM Linux | Revisar os 11 tokens, agentes, truststore/proxy e condicional JAVA_OPTS no arquivo fornecido; documentar nomes/origens esperados. Precedencia do launcher e confirmacao externa | Preservar opcoes Windows ja escolhidas; alterar apenas requisitos comuns confirmados |
| DES-07: logging bootstrap | Rever caminhos/versionamento dos JARs do candidato Linux junto com o update/contrato dos agentes. Presenca dos JARs no CP11 local nao valida imagem | Nao adicionar bootclasspath/agentes ao local por copia automatica |
| DES-09: EJB remoto | Resolver retirada de READ_TIMEOUT `${prop.remoting-connector.read.timeout:20}`: compatibilidade, unidade, referencia e uso. Separar de connector-ref/connectors | Possivel ajuste do template; ensaiar chamadas remotas quando usadas |
| DES-10: caches | Conferir retirada dos caches persistent web/ejb e do default-cache local-query do Hibernate; revisar referencias e adaptacoes de modelo | Possivel ajuste comum; validar sessoes/stateful/cache conforme uso real |
| Complementares | Conferir cabecalhos HTTP, JPA/default-binding, endpoint remoting, expresso-smtp versus mail-smtp e referencias/permitidos-negados de Elytron | Atualizar apenas diferencas justificadas; testar integracoes usadas |

DES-04 e recomendacao de preservacao, nao diagnostico de desempenho. A unidade
configurada mudou, mas o efeito depende do pool e de threads nao core. As
[referencias EJB 7.4](https://docs.redhat.com/en/documentation/red_hat_jboss_enterprise_application_platform/7.4/html/developing_jakarta_enterprise_beans_applications/reference_material)
documentam keepalive; a recomendacao ainda precisa ser aplicada e verificada.

## Confirmacoes da outra equipe, sem bloquear nosso preparo

DES-08 abrange revisao implantada, imagem/digest, entrypoint, renderizacao final,
versao/update/JDK, precedencia JVM, pipeline e recursos OKD. A equipe responsavel
confere esses pontos ao consumir o pacote. Tambem confirma quais manifestos/CLI
usa (DES-02), o metodo de deploy (parte de DES-05) e os caminhos/parametros
efetivos da JVM e agentes (partes de DES-06/07).

Esses itens nao sao implementacao pendente do harness. Mantemos a entrega de
configuracao revisavel com pressupostos explicitos, sem afirmar que a plataforma
ou os fluxos de DES foram validados. Nao exigimos acesso a Dockerfile, YAML ou
cluster para trabalhar nos arquivos que ja recebemos.

## Ordem de retomada e criterio de encerramento

1. Resolver DES-04 e DES-03 no template fornecido, registrando decisao e motivo.
2. Revisar referencias de seguranca/Keycloak, EJB remoto e caches (DES-05/09/10).
3. Fechar manifestos/CLI, tokens e JVM Linux no pacote de configuracao; listar
   as confirmacoes de consumo que cabem a outra equipe.
4. Para cada ajuste aprovado, indicar arquivo/revisao, necessidade de atualizar
   o local, passos e verificacao. Usar o
   [roteiro de atualizacao local](../jboss-eap7.4-configuracao/atualizacao-maquina-trabalho.md).
5. Entregar a configuracao revisada e a lista de testes aplicaveis: boot,
   datasource, deploy, SSO, fontes, keystore, mail/JMS e demais recursos usados.
   Distinguir evidencia local recebida de validacao de DES pela equipe executora.

Nenhum ajuste do template privado foi aplicado por este conjunto de correcoes
do harness. O criterio da nossa entrega e fechar a revisao dos arquivos e suas
decisoes, preservar o modelo repetivel e explicitar os testes/confirmacoes de
destino. Nao declarar todo o ambiente DES validado apenas com o ensaio local.
