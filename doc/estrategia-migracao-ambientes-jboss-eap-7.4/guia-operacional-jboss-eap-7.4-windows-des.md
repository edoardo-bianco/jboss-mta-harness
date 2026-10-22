# Guia operacional — JBoss EAP 7.4 no Windows e no novo DES

> Para o preparo repetivel atual com scripts versionados, use
> [jboss-eap7.4-configuracao](jboss-eap7.4-configuracao/README.md), inclusive sem helper.
> Este documento preserva o inventario e as decisoes do ambiente DES/CP11.
> A escolha de outro cumulativo segue o [roteiro de patches](jboss-eap7.4-configuracao/patches.md);
> referencias antigas a CP11/ELS abaixo nao escolhem o patch de uma nova instalacao.

**Revisão:** 1.4 — 19/10/2026  
**Estratégia:** [Migração dos ambientes EAP 7.1 → 7.4](estrategia-migracao-ambientes-jboss-eap-7.4.md)  
**Tecnologia preservada:** Java 8, `standalone-full.xml`, Oracle, WAR/EAR com `javax.*` e cliente Keycloak/RH SSO.  
**Runtime do DES:** imagem atual `7.1.0-mscore-fonts` → imagem de destino `7.4.11-openjdk8`, montada pela esteira do Azure DevOps e executada em OKD/OpenShift.

## 1. Como executar este guia

O procedimento local utiliza PowerShell 5.x e os scripts `.bat` oficiais. Os comandos apresentados são instruções para execução pelo responsável no ambiente autorizado; não foram executados contra sua máquina ou seus servidores.

Os nomes de branch, datasource, módulos e caminhos são exemplos até a análise dos arquivos reais. Substituir os valores identificados antes de executar. Não usar credenciais ou endpoints de PRD nos exemplos locais.

**Fluxo:** coletar as configurações do 7.1 (seção 2) → criar branch → obter binários → instalar → aplicar patches → configurar módulos/integrações → testar localmente → versionar → provisionar e testar o novo DES.

Os comandos administrativos deste guia devem apontar para o EAP 7.4 local ou para o novo DES autorizado. No EAP 7.1 de DES/PRD, a coleta é manual, a partir do repositório de configuração e das informações dos responsáveis. Não executar scripts de coleta, configuração, patch, reload ou shutdown na origem.

Se uma etapa falhar, interromper a sequência, registrar a mensagem e corrigir a causa. Em programas externos, como `git` e `jboss-cli.bat`, conferir também `$LASTEXITCODE` e o resultado da operação; `$ErrorActionPreference` sozinho não trata todos os erros desses programas no PowerShell 5.

## 2. Configurações do EAP 7.1 a coletar

Esta seção lista, item a item, o que coletar do EAP 7.1 para servir de base à reconstrução do EAP 7.4: primeiro no ambiente local, depois no novo DES. **No DES, a configuração do JBoss é mantida no repositório de configuração. A coleta é manual, feita a partir desse repositório, da esteira e das informações fornecidas pelos responsáveis.** Não executar scripts de coleta nem comandos administrativos no servidor de origem.

Os IDs (`ORG-01`, `DS-01` etc.) identificam cada item no inventário e são referenciados nas seções seguintes.

### 2.1. Fontes e regras da coleta

| Fonte | O que fornece | Responsável |
|---|---|---|
| Repositório de configuração (branch e commit implantados no DES 7.1) | `standalone-full.xml`, templates/scripts da esteira, `module.xml`, propriedades e parâmetros versionados | Responsável pelo repositório + DevOps |
| Esteira do DES 7.1 | Variáveis por ambiente, substituições, ordem de aplicação, referência dos segredos e forma de deploy | DevOps |
| Esteira do Azure DevOps e definição da imagem `7.1.0-mscore-fonts` | Versão e patch do EAP, JDK, imagem base, fontes, variáveis do deployment no OKD, Route e proxy (ESTEIRA-09 a ESTEIRA-14) | Equipe da esteira |
| Repositório da aplicação e artefato de referência | Descritores, bibliotecas empacotadas, nomes JNDI e propriedades lidas pelo código | Desenvolvimento |
| PRD 7.1 (complementar) | Somente diferenças estruturais relevantes frente ao DES | Responsável autorizado |
| EAP 7.1 local (quando existir) | O que já funciona na máquina do desenvolvedor | Desenvolvedor |

Regras:

1. Registrar a **fonte** de cada item: repositório, caminho, linha e commit, ou o responsável que informou o dado. Item sem fonte fica pendente.
2. **Não coletar segredos.** Registrar apenas a referência: nome da variável, expressão `${VAULT::...}`, entrada de credential store ou chave do cofre da esteira.
3. Marcar o que **varia por ambiente** (URLs, hosts, portas, caminhos, dimensionamento). Esses itens viram parâmetros no 7.4.
4. Não presumir que o valor do XML é o executado. Se a esteira substitui variáveis ou aplica scripts após o boot, coletar também a regra de substituição e o valor de DES, sem segredos.
5. Alterações feitas diretamente no servidor DES, fora do repositório, precisam ser declaradas pelo DevOps. Sem essa confirmação, registrar o risco.
6. Atributos que não aparecem no XML usam o padrão da versão. Coletar o que está **explicitamente definido**; não copiar padrões do 7.1 para o 7.4.

### 2.2. Identificação da origem

| ID | Item a coletar | Observação |
|---|---|---|
| ORG-01 | Repositório, branch e **commit** implantado no DES 7.1; caminho dos arquivos | Origem da nova branch (seção 3) |
| ORG-02 | Versão do EAP 7.1 e patch cumulativo aplicado | Normalmente fora do repositório; obter do registro do ambiente |
| ORG-03 | JDK: fornecedor, update do Java 8 e arquitetura | Referência para o JDK 8 do 7.4 |
| ORG-04 | Execução no OKD/OpenShift: projeto/namespace, deployment, réplicas e imagem em uso (hoje `7.1.0-mscore-fonts`) | Referência para o deployment do novo DES (seção 16) |
| ORG-05 | Arquivo de configuração usado no boot (`-c` ou `--server-config`) e modo standalone | Confirmar que é `standalone-full.xml` |
| ORG-06 | Mecanismo da esteira: XML pronto, template com variáveis ou scripts CLI; ordem de execução | Define a fonte de verdade (estratégia, 4.4) |
| ORG-07 | Artefatos implantados: nome, versão, `runtime-name`, context-root e forma de deploy | Seções 14 e 16 |
| ORG-08 | Namespace raiz do XML (`<server xmlns="urn:jboss:domain:...">`) | Identifica a versão do modelo; não editar namespaces |
| ORG-09 | Imagem atual do DES (`7.1.0-mscore-fonts`): digest, imagem base, definição de build, pacotes adicionados (fontes) e como o XML do repositório entra na imagem | Confirma ORG-02 e ORG-05; mostra o que o 7.4 também precisa ter |
| ORG-10 | Imagem de destino (`7.4.11-openjdk8`): digest, imagem base (oficial Red Hat para OpenShift ou montada a partir do ZIP), arquivo de configuração usado no boot, scripts de entrada, variáveis, JDK e fontes | Define o baseline do ambiente local (seção 4.5) |

### 2.3. Inicialização e JVM

Fonte: no DES 7.1 em container, as opções da JVM vêm das variáveis do deployment no OKD, da definição da imagem (por exemplo, `JAVA_OPTS` ou variáveis de memória) e dos parâmetros da esteira (ESTEIRA-09 a ESTEIRA-11). Coletar `bin/standalone.conf` apenas se a imagem o customizar. No EAP 7.1 local, usar `standalone.conf.bat`.

| ID | Item a coletar | Uso no 7.4 |
|---|---|---|
| JVM-01 | `JAVA_HOME` ou caminho do Java usado pelo processo | Referência; o 7.4 usará o JDK 8 aprovado |
| JVM-02 | Memória: `-Xms`, `-Xmx`, `-XX:MetaspaceSize`, `-XX:MaxMetaspaceSize` | DES: parâmetro; local: dimensionar para a máquina |
| JVM-03 | GC e diagnóstico: coletor, log de GC, `-XX:+HeapDumpOnOutOfMemoryError` e caminhos | Caminhos por ambiente |
| JVM-04 | Regionais: `-Duser.timezone`, `-Dfile.encoding`, `-Duser.language`, `-Duser.country` | **Manter iguais** no local e no DES; afetam datas e acentuação |
| JVM-05 | Rede: `-b`, `-bmanagement`, `-Djboss.bind.address*`, `-Djboss.socket.binding.port-offset`, `-Djava.net.preferIPv4Stack` | Local: 127.0.0.1 e offset 100; DES: definido por DevOps |
| JVM-06 | Identidade: `-Djboss.node.name`, `-Djboss.tx.node.id`, `-Djboss.server.name` | Valores **novos**, distintos do 7.1 |
| JVM-07 | Diretórios: `-Djboss.server.base.dir`, `config.dir`, `log.dir`, `data.dir`, `temp.dir`; `JBOSS_MODULEPATH` | Diretórios próprios do 7.4; nunca compartilhar com o 7.1 |
| JVM-08 | TLS e saída: `-Djavax.net.ssl.trustStore` (caminho e tipo, sem senha), `-Dhttp.proxyHost`, `-Dhttps.proxyHost`, `-Dhttp.nonProxyHosts` | Truststore do projeto por ambiente; não alterar `cacerts` global |
| JVM-09 | Agentes e classloading: `-javaagent`, `-Djboss.modules.system.pkgs`, `-Xbootclasspath` | Confirmar versão compatível com EAP 7.4 antes de habilitar |
| JVM-10 | Propriedades da aplicação passadas por `-D` ou por arquivo `-P` | Ver XML-02; segredos só por referência |
| JVM-11 | Outras opções, como `-secmgr` ou `-Djava.security.manager` | Avaliar caso a caso |

### 2.4. `standalone-full.xml`: itens por bloco

Percorrer o XML do repositório **bloco a bloco**. Para cada recurso, registrar nome, atributos definidos e referências a outros recursos (socket bindings, módulos, domínios de segurança, datasources).

**Atenção ao DES em container:** o XML do repositório pode não ser a configuração completa. Scripts de entrada da imagem, variáveis de ambiente do deployment e scripts CLI da esteira podem criar ou alterar recursos no boot, como datasources, filas e propriedades. Imagens derivadas da imagem oficial Red Hat para OpenShift costumam fazer isso. Coletar também essas fontes (ESTEIRA-06, ESTEIRA-09 e ESTEIRA-10) e registrar cada recurso gerado com o mesmo ID da tabela correspondente, indicando a origem "variável" ou "script".

#### Elementos do servidor

| ID | Elemento | Coletar |
|---|---|---|
| XML-01 | `<extensions>` | Todas as `extension module=`. Destacar extensões não nativas, como `org.keycloak.keycloak-adapter-subsystem` ou `org.keycloak.keycloak-saml-adapter-subsystem` |
| XML-02 | `<system-properties>` | Nome e valor ou referência de cada propriedade; marcar variáveis por ambiente e segredos |
| XML-03 | `<vault>` | Existência e caminhos (keystore e diretório de arquivos), sem senha ou salt; atributos que usam `${VAULT::...}` |
| XML-04 | `<management>` → `<security-realms>` | Cada realm: autenticação/autorização (properties, LDAP, local, truststore) e `server-identities` (keystore: caminho e alias) |
| XML-05 | `<management>` → `<management-interfaces>`, `<access-control>`, `<audit-log>` | Realm usado, socket binding, console habilitado, provider (`simple` ou `rbac`) e mapeamento de papéis |
| XML-06 | `<management>` → `<outbound-connections>` | Conexões LDAP: URL e usuário de bind; senha só por referência |
| XML-07 | `<interfaces>` | Cada interface e seu critério (`inet-address` com expressão e padrão, `any-address`, `nic`) |
| XML-08 | `<socket-binding-group>` | `default-interface`, `port-offset` e todo `socket-binding` customizado ou com porta fixa |
| XML-09 | `<outbound-socket-binding>` | Destinos externos (SMTP, EJB remoto, broker externo, LDAP): host e porta por ambiente |
| XML-10 | `<deployments>` e `<deployment-overlays>` | Se o XML registra deployments ou overlays: nome, `runtime-name`, habilitado e arquivos substituídos |
| XML-11 | `<subsystem xmlns="...">` em `<profile>` | Família e versão de cada subsistema; comparar com a base do 7.4 na seção 8 |

#### Subsistemas de integração e dados

| ID | Subsistema / elemento | Coletar |
|---|---|---|
| DS-01 | `datasources` → `<datasource>` e `<xa-datasource>` | `pool-name`, `jndi-name`, `enabled`, `jta`, `use-java-context`, `statistics-enabled`, `<connection-url>` ou `<xa-datasource-property>`, `<driver>`, `<transaction-isolation>`, `<new-connection-sql>`, `<connection-property>` |
| DS-02 | Pool (`<pool>` ou `<xa-pool>`) | `<min-pool-size>`, `<max-pool-size>`, `<prefill>`, `<use-strict-min>`, `<flush-strategy>`; no XA, `<is-same-rm-override>`, `<pad-xid>`, `<wrap-xa-resource>` |
| DS-03 | Credenciais (`<security>`) | `<user-name>` e a origem da senha: literal, `${VAULT::...}`, `<security-domain>` ou `<credential-reference>`. Nunca o valor |
| DS-04 | Validação (`<validation>`) | `<valid-connection-checker>`, `<check-valid-connection-sql>`, `<validate-on-match>`, `<background-validation>`, `<background-validation-millis>`, `<stale-connection-checker>`, `<exception-sorter>` |
| DS-05 | `<timeout>` e `<statement>` | `<blocking-timeout-millis>`, `<idle-timeout-minutes>`, `<query-timeout>`, `<set-tx-query-timeout>`, `<allocation-retry>`, `<prepared-statement-cache-size>`, `<share-prepared-statements>` |
| DS-06 | Recuperação XA (`<recovery>`) | `no-recovery` e `<recover-credential>` (por referência) |
| DS-07 | `<drivers>` | Nome, `module`, `<driver-class>`, `<xa-datasource-class>`; versão do JDBC no módulo (MOD-02) |
| TX-01 | `transactions` | `node-identifier`, `process-id` (uuid ou socket), `default-timeout`, `statistics-enabled`, object store (`path`, `relative-to`) ou store JDBC/journal |
| JMS-01 | `messaging-activemq` → `<server>` | Nome, `persistence-enabled`, `security-enabled`, diretórios do journal, bindings, paging e large messages; cluster/HA, se existir |
| JMS-02 | `<jms-queue>` e `<jms-topic>` | Nome, `entries` (JNDI), `durable`, `selector` |
| JMS-03 | `<connection-factory>` e `<pooled-connection-factory>` | `entries`, conectores, `transaction`, `ha`, usuário (senha por referência) e parâmetros de consumo |
| JMS-04 | `<address-setting>` e `<security-setting>` | DLQ, expiry, `max-delivery-attempts`, `redelivery-delay`, `max-size-bytes`, `address-full-policy`; papéis por endereço |
| JMS-05 | Conectividade | Acceptors, connectors, `remote-connector`, `jms-bridge`, `bridge`, `divert` e brokers externos |
| RA-01 | `resource-adapters` | Cada adaptador: `archive` ou `module`, `transaction-support`, `config-property`, `connection-definitions` (JNDI, pool, segurança) e `admin-objects` |
| JCA-01 | `jca` | `archive-validation`, `bean-validation`, `cached-connection-manager` (`debug`, `error`), work managers e threads alterados |
| MAIL-01 | `mail` | Cada `mail-session`: `jndi-name`, `from`, `debug`; servidor SMTP (socket binding, TLS/SSL, usuário; senha por referência) |
| NAM-01 | `naming` → `<bindings>` | `simple` (nome, valor, tipo), `lookup`, `object-factory` (módulo, classe, ambiente), `external-context` |
| REM-01 | `remoting` | Conectores, `http-connector` e conexões de saída para EJB remoto: destino, usuário e realm |
| WS-01 | `webservices` | `wsdl-host`, `wsdl-port`, `wsdl-secure-port`, `modify-wsdl-address`, `wsdl-uri-scheme`, `endpoint-config` e `client-config` (handlers e propriedades) |
| BAT-01 | `batch-jberet` | `default-job-repository` (in-memory ou JDBC + datasource), `default-thread-pool`, `security-domain` |

#### Subsistemas de web, EJB e plataforma

| ID | Subsistema / elemento | Coletar |
|---|---|---|
| WEB-01 | `undertow` (atributos do subsistema) | `default-server`, `default-virtual-host`, `default-servlet-container`, `default-security-domain`, `statistics-enabled` |
| WEB-02 | Listeners | `http-listener`, `https-listener`, `ajp-listener`: socket binding, `redirect-socket`, `proxy-address-forwarding`, `max-post-size`, `max-parameters`, `max-headers`, timeouts, `enable-http2`, `certificate-forwarding`; no HTTPS, `security-realm` ou `ssl-context`, protocolos e cifras |
| WEB-03 | `<host>` | Nome, `alias`, `default-web-module`, `<location>`, `<filter-ref>`, `<access-log>` (padrão, diretório, prefixo, rotação), `<single-sign-on>` |
| WEB-04 | `<servlet-container>` | `default-session-timeout`, `default-encoding`, `use-listener-encoding`, `<jsp-config>`, `<session-cookie>` (nome, `secure`, `http-only`, domínio, caminho), `<persistent-sessions>`, `<websockets>`, `<mime-mappings>`, `<welcome-files>`, `proactive-authentication`, `stack-trace-on-error`, `directory-listing` |
| WEB-05 | `<handlers>` e `<filters>` | Handlers `file` e `reverse-proxy`; filtros `response-header`, `request-limit`, `gzip`, `error-page`, `custom-filter` (módulo e classe), `expression-filter`, `rewrite` |
| WEB-06 | `<application-security-domains>` (Undertow) | Mapeamento do domínio da aplicação para o Elytron, quando existir |
| EJB-01 | `ejb3` (padrões) | Pools padrão de SLSB e MDB (`bean-instance-pool-ref`), adaptador padrão de MDB (`resource-adapter-ref`), cache de SFSB, `default-security-domain`, `default-missing-method-permissions-deny-access`, `in-vm-remote-interface-invocation`, `statistics` |
| EJB-02 | `ejb3` → pools, caches e threads | `strict-max-pool` (tamanhos e timeouts), caches e passivação, `thread-pools` (async, timer, remote) |
| EJB-03 | `ejb3` → `<timer-service>` | `thread-pool-name`, `default-data-store`; `file-data-store` (caminho) ou `database-data-store` (datasource e partição) |
| EJB-04 | `ejb3` → remoto e segurança | `<remote>` (conector) e `<application-security-domains>` |
| EE-01 | `ee` | `<global-modules>`, `<ear-subdeployments-isolated>`, `<spec-descriptor-property-replacement>`, `<jboss-descriptor-property-replacement>`, `<annotation-property-replacement>` |
| EE-02 | `ee` → `<concurrent>` e `<default-bindings>` | Context services, managed executors, scheduled executors, thread factories e bindings padrão |
| LOG-01 | `logging` → níveis | `<root-logger>` (nível e handlers), cada `<logger category=...>`, `add-logging-api-dependencies`, `use-deployment-logging-config` |
| LOG-02 | `logging` → handlers e formatos | `console-handler`, `periodic-rotating-file-handler`, `size-rotating-file-handler`, `async-handler`, `custom-handler` (módulo e classe), arquivo (`path`, `relative-to`), rotação e padrão de formatação |
| INF-01 | `infinispan` | Cache containers e caches customizados (nome, JNDI, expiração, tamanho); alterações em `web`, `ejb` e `hibernate` |
| JPA-01 | `jpa` | `default-datasource`, `default-extended-persistence-inheritance` |
| PLT-01 | Demais subsistemas | `io` (workers, buffer pools), `request-controller`, `jsf` (`default-jsf-impl-slot`), `weld`, `bean-validation`, `jmx`, `iiop-openjdk`, `security-manager` (permissões), `deployment-scanner` (`path`, `scan-interval`, `auto-deploy-*`, `deployment-timeout`), `singleton`, `sar`: somente valores alterados |

#### Subsistemas de segurança e SSO

| ID | Subsistema / elemento | Coletar |
|---|---|---|
| SEC-01 | `security` (legado) → `<security-domain>` | Nome, `cache-type`, `<login-module>` (código, flag, módulo, nomes das `module-option`; valores sensíveis por referência), `<authorization>`, `<mapping>`, `<jsse>` |
| SEC-02 | `security` → uso | Domínios referenciados pela aplicação (`jboss-web.xml`, `jboss-ejb3.xml`) e por datasources; `elytron-integration`; uso de `SecureIdentityLoginModule` para senhas |
| ELY-01 | `elytron` → domínios e realms | `security-domain`, realms (`properties`, `filesystem`, `ldap`, `jdbc`, `token`, `key-store`, `custom-realm` com módulo e classe), mappers e decoders |
| ELY-02 | `elytron` → autenticação | `http-authentication-factory`, `sasl-authentication-factory`, configuração de mecanismos e fábricas customizadas |
| ELY-03 | `elytron` → TLS e credenciais | `key-store` (caminho, tipo; `credential-reference` por referência), `key-manager`, `trust-manager`, `server-ssl-context`, `client-ssl-context`, `credential-store` (caminho, tipo), `dir-context` |
| SSO-01 | `keycloak` (OIDC) | `<realm>` e cada `<secure-deployment>`: nome do deployment, `realm`, `resource`, `auth-server-url`, `ssl-required`, `bearer-only`, `public-client`, `principal-attribute`, `use-resource-role-mappings`, `enable-cors`, `truststore`, `disable-trust-manager`; `credential` só por referência |
| SSO-02 | `keycloak-saml` | `<secure-deployment>`, `<SP>` (entity ID, políticas), chaves (caminho e alias) e `<IDP>` (entity ID, URLs, validação de assinatura) |
| SSO-03 | Variante do adaptador | Domínio no subsistema `security` com login module do Keycloak indica a variante legada. Recursos do Keycloak no `elytron` (por exemplo, `custom-realm` e fábrica de mecanismo HTTP) e `application-security-domain` indicam a variante Elytron. Confirmar com o script do pacote (seção 11) |

### 2.5. Outros arquivos e insumos

| ID | Item | Coletar | Observação |
|---|---|---|---|
| MOD-01 | Módulos fora de `modules/system/layers/base` | Nome, slot, caminho, `module.xml` completo, JARs com versão e origem no repositório de artefatos | Incluir `modules/system/add-ons` (ex.: adaptador SSO) e camadas declaradas em `modules/layers.conf` |
| MOD-02 | Driver Oracle | Arquivo, versão completa, nome do módulo e bibliotecas complementares (wallet, ONS, UCP) | Seção 9 |
| MOD-03 | Adaptador SSO | Produto, versão, pacote e script usado (legado, Elytron ou SAML) | Seção 11 |
| FILE-01 | Arquivos de propriedades referenciados | Caminho, finalidade, chaves e valores não secretos; quem lê (servidor ou aplicação) | Estrutura versionada; valores por ambiente |
| FILE-02 | Usuários e papéis em properties (`application-*.properties`, `mgmt-*.properties`) | Somente existência, realm/domínio que usa e nomes de papéis necessários | Não copiar usuários nem hashes; criar contas de teste no destino |
| FILE-03 | Keystores e truststores | Caminho, tipo, alias, finalidade, emissor e validade | Nunca copiar chaves privadas entre ambientes |
| FILE-04 | Diretórios externos | Uploads, relatórios, templates, áreas de troca: caminho, permissões e volume | Criar equivalentes com dados de teste |
| FILE-05 | Customizações do JDK | CAs adicionadas ao `cacerts`, mudanças em `java.security`, JARs em `jre/lib/ext` | Reproduzir por truststore/configuração do projeto |
| FILE-06 | Outros arquivos alterados do EAP | `bin/jboss-cli.xml`, `welcome-content/`, scripts customizados em `bin/` | O guia oficial de upgrade cita módulos customizados e `welcome-content` [R11] |
| FILE-07 | Fontes do sistema | Fontes instaladas na imagem `7.1.0-mscore-fonts`, funcionalidades que dependem delas (relatórios, PDF, imagens, gráficos) e nomes de fonte usados pela aplicação | O Windows já tem as fontes Microsoft: o teste local não comprova o DES |
| PIPE-01 | Esteira | Variáveis por ambiente (nome e origem), regras de substituição, scripts CLI pós-boot, comando de deploy e health checks | Segredos apenas por referência |

### 2.6. Aplicação: descritores e uso de recursos

Fonte: repositório da aplicação e artefato de referência (WAR/EAR). O objetivo é ligar cada recurso do servidor a um uso concreto.

| ID | Arquivo ou evidência | Coletar |
|---|---|---|
| APP-01 | `web.xml` | `login-config` (`auth-method`, inclusive `KEYCLOAK` ou `KEYCLOAK-SAML`), `security-constraint`, `security-role`, `session-config`, filtros, `context-param` (inclusive RESTEasy), `resource-ref` e `resource-env-ref` |
| APP-02 | `jboss-web.xml` | `context-root`, `security-domain`, `virtual-host` e mapeamentos JNDI |
| APP-03 | `jboss-deployment-structure.xml` e `MANIFEST.MF` (`Dependencies:`) | Módulos importados e excluídos, `exclude-subsystems`, isolamento de subdeployments |
| APP-04 | `persistence.xml` | Unidades, `jta-data-source`, provider e propriedades Hibernate (dialeto, cache, `hbm2ddl`, `jboss.as.jpa.providerModule`) |
| APP-05 | `ejb-jar.xml`, `jboss-ejb3.xml` e anotações | MDBs (destino, `resourceAdapter`, ativação), domínio de segurança, pools, `@Schedule` e uso de `TimerService` |
| APP-06 | `keycloak.json` ou `keycloak-saml.xml` | Realm, cliente, URL do SSO e modo do cliente; segredo só por referência |
| APP-07 | `*-ds.xml`, `*-jms.xml`, `ironjacamar.xml` no artefato | Recursos definidos pela própria aplicação |
| APP-08 | `application.xml`, `jboss-app.xml`, `beans.xml`, `jboss-webservices.xml`, `jboss-client.xml` | Módulos e context-roots do EAR, CDI, handlers de web services e cliente remoto |
| APP-09 | Bibliotecas em `WEB-INF/lib` e `lib/` do EAR | Nome e versão; destacar as que o EAP já fornece (Hibernate, RESTEasy, Jackson, Keycloak, APIs Java EE, logging) |
| APP-10 | Código | Nomes JNDI em lookups e `@Resource`, unidades em `@PersistenceContext`, chaves de `System.getProperty` e endpoints externos |

### 2.7. Operação e dados (sem copiar dados)

| ID | Item | Coletar com o responsável |
|---|---|---|
| OPS-01 | Timers EJB persistentes | Se há timers criados por programa (não só `@Schedule`) e se a aplicação os recria. O Migration Guide orienta revisar `data/timer-service-data` antes de migrar [R2] |
| OPS-02 | Transações | Uso de XA, usuário de recuperação e política para transações pendentes no 7.1 |
| OPS-03 | Filas e consumidores | Filas consumidas/produzidas pelo DES 7.1 e como evitar consumo duplicado pelo 7.4 |
| OPS-04 | Jobs e rotinas | Batch, timers e agendadores internos ou externos que acionam a aplicação |
| OPS-05 | Entrada de tráfego | DNS, proxy/balanceador, AJP ou HTTP, cabeçalhos `X-Forwarded-*`, terminação TLS, sessão aderente |
| OPS-06 | Observabilidade | Coleta e retenção de logs, APM, health checks e alertas |
| OPS-07 | Integrações de saída | Endpoints, certificados e regras de firewall necessários a partir do novo DES |

Os diretórios `standalone/data`, `standalone/tmp` e `standalone/log` do 7.1 **não** são coletados nem copiados.

### 2.8. Do item coletado ao EAP 7.4

| Itens | EAP 7.4 local | Novo DES |
|---|---|---|
| ORG, JVM | JDK 8 aprovado, regionais iguais aos do container de DES, offset 100 e identidade local (seções 5 e 7) | Parâmetros da esteira; identidade e diretórios novos (seção 16) |
| ORG-09, ORG-10, FILE-07 | Mesmo update do EAP e mesma linha de JDK da imagem de destino (seção 4.5) | Imagem identificada por digest; fontes incluídas na imagem ou em imagem derivada |
| XML-01 a XML-11 | Reaplicar na base do 7.4 somente as customizações; interfaces locais (seção 8) | Rede e destinos de DES |
| DS, TX, MOD-02 | Módulo e datasource (seções 9 e 10) | URL e credenciais pelo mecanismo de segredos; `node-identifier` distinto do 7.1 |
| JMS, RA, MAIL, NAM, REM, WS, BAT | Mesmos nomes JNDI, apontando para destinos de teste ou isolados (seção 12) | Destinos de DES isolados do 7.1; consumidores habilitados de forma controlada |
| WEB, EJB, EE, LOG, INF, JPA, PLT | Reproduzir os valores alterados com caminhos locais (seção 12) | Caminhos, retenção e dimensionamento de DES |
| SEC, ELY, SSO, MOD-03 | Manter a variante encontrada (legado ou Elytron) e instalar o adaptador compatível (seção 11) | Realm, cliente, URLs e callbacks de DES com a equipe SSO |
| MOD-01, FILE | Módulos aprovados, estrutura de arquivos e dados de teste; truststore do projeto | Mesmos binários; volumes, permissões e certificados de DES |
| APP | Deploy do artefato de referência e testes (seção 14) | Mesmo artefato, testado no destino real |
| OPS, PIPE | Controle de jobs e consumidores durante os testes | Isolamento, roteamento, observabilidade e reversão |

### 2.9. Registro e conclusão da coleta

Registrar no inventário já utilizado pelo projeto, uma linha por recurso. Os exemplos abaixo são ilustrativos:

| ID | Fonte | Valor sanitizado ou referência | Varia por ambiente | Decisão | 7.4 local | DES |
|---|---|---|---|---|---|---|
| DS-01 | `config/standalone-full.xml:120@abc1234` | Exemplo: `AppDS`, `java:/jdbc/AppDS`, não XA | URL e usuário | Reproduzir | Seção 10, banco de teste | Parâmetro da esteira |
| JMS-02 | Mesmo arquivo, linha 410 | Exemplo: fila `Pedidos`, `java:/jms/queue/Pedidos` | Não | Reproduzir se confirmada | Broker local | Broker isolado do 7.1 |
| SSO-01 | Mesmo arquivo, linha 530 | Exemplo: `app.war`, realm `R1`, confidencial, segredo em `SSO_SECRET` | URL e segredo | Adaptar | Cliente de teste | Cliente de DES |

Decisões possíveis: **reproduzir**, **adaptar**, **parametrizar**, **não transportar com justificativa** ou **pendente de investigação**. A ausência de evidência não autoriza excluir um recurso potencialmente necessário.

**A coleta está concluída quando todos os blocos do XML e todos os itens das seções 2.2 a 2.7 tiverem sido revisados**, mesmo que a decisão seja "não se aplica". Full não significa que todas as funcionalidades sejam usadas: um subsistema sem customização e sem uso comprovado mantém a configuração padrão do 7.4.

### 2.10. Pontos de atenção na passagem 7.1 → 7.4

- A JBoss Server Migration Tool do 7.4 documenta EAP 6.4 e 7.3 como origens. Para o 7.1, o caminho é a reconstrução guiada por este inventário. [R9]
- O Migration Guide do 7.4 foi escrito principalmente para origem EAP 6. Para origem 7.1, conferir os itens coletados com as listas de funcionalidades depreciadas e sem suporte das versões 7.2, 7.3 e 7.4. [R2][R22]
- O Hibernate passa da linha 5.1 para a 5.3. Revisar APP-04 e as consultas da aplicação conforme a matriz de compatibilidade do projeto. [R21]
- O EAP 7.1 já possui Elytron. A origem pode usar o subsistema `security` legado, o `elytron` ou ambos. Preservar o mecanismo encontrado, salvo decisão explícita.
- O vault legado (XML-03) continua disponível no 7.4, mas está depreciado. Substituí-lo por credential store é uma decisão separada. [R22]
- A matriz de configurações suportadas do 7.4 lista Oracle 19c com Oracle JDBC 19.3. Registrar outra combinação como diferença. [R1]
- Os namespaces dos subsistemas mudam entre as versões. Reaplicar recursos e atributos no modelo do 7.4. Não copiar blocos inteiros do XML 7.1 nem editar números de namespace.

## 3. Criar a branch de configuração EAP 7.4

Antes do primeiro push, confirmar com DevOps os gatilhos de CI/CD. O repositório de configurações não deve ser presumido como sendo o repositório do harness.

No clone local correto, com alterações pendentes já resolvidas:

```powershell
$ErrorActionPreference = 'Stop'
$BranchOrigem = 'SUBSTITUIR_PELA_BRANCH_CONFIG_EAP71'
$BranchDestino = 'feat/jboss-eap-7.4-config'

if ($BranchOrigem -like 'SUBSTITUIR*') {
    throw 'Defina a branch real que representa o DES EAP 7.1.'
}

$status = git status --porcelain
if ($LASTEXITCODE -ne 0) { throw 'Falha ao consultar o repositorio Git.' }
if ($status) { throw 'O clone tem alteracoes pendentes. Resolva antes de continuar.' }

git fetch origin
if ($LASTEXITCODE -ne 0) { throw 'Falha no fetch.' }

$CommitOrigem = git rev-parse --verify "origin/$BranchOrigem"
if ($LASTEXITCODE -ne 0) { throw 'Branch de origem nao encontrada no remote origin.' }

# --no-track evita associar a nova branch ao upstream antigo.
git checkout --no-track -b $BranchDestino "origin/$BranchOrigem"
if ($LASTEXITCODE -ne 0) { throw 'A nova branch nao foi criada.' }

Write-Host "Commit de referencia da origem: $CommitOrigem"
git status --short --branch
```

Registrar o commit no acompanhamento da migração; ele deve coincidir com ORG-01 da seção 2. Não usar `reset --hard`, não forçar push e não sobrescrever uma branch que já exista. Se a branch já tiver sido criada, conferir sua origem e continuar nela conforme o fluxo normal do time.

Manter os caminhos atuais do repositório. Não criar uma segunda organização de arquivos apenas por causa deste guia. Preservar o EAP 7.1 na branch/commit de referência e preparar o EAP 7.4 na nova linha.

## 4. Baixar os pacotes oficiais

### 4.1. Links de entrada

| Finalidade | Link oficial |
|---|---|
| EAP no programa Developer | [Download JBoss EAP](https://developers.redhat.com/products/eap/download) |
| Distribuições e patches | [Red Hat Customer Portal — Downloads](https://access.redhat.com/downloads) |
| Verificar atualizações do EAP 7 | [Maintenance Schedule](https://access.redhat.com/articles/2332721) |
| Entender o acesso ELS | [Como baixar patches ELS do EAP 7.4](https://access.redhat.com/solutions/7134413) |
| Área ELS indicada pela Red Hat em 15/10/2026 | [EAP 7.4 ELS — seleção 7.4.25](https://access.redhat.com/downloads/content/1023/ver=/middleware---7/7.4.25/x86_64/product-software) |
| JDK 8 para Windows | [Red Hat build of OpenJDK](https://developers.redhat.com/products/openjdk/download) |
| Driver Oracle | [JDBC e bibliotecas complementares](https://www.oracle.com/database/technologies/appdev/jdbc-downloads.html) |
| Adaptadores SSO | [Produto Red Hat Single Sign-On](https://access.redhat.com/products/single-sign-on/) |

Não utilizar JBoss AS comunitário, WildFly, EAP 8, versão beta ou EAP XP como substitutos do EAP 7.4 deste projeto. A página Developer reúne vários produtos/versões: selecionar o item correto. [R10][R12]

### 4.2. Distribuição ZIP do EAP

1. Entrar com a conta Red Hat Developer/Customer Portal no navegador.
2. Na página Developer, localizar **7.4.0 → Zip File → Application Platform**. Alternativamente, no Customer Portal: Downloads → Red Hat JBoss Enterprise Application Platform → versão 7.4 → distribuição ZIP 7.4.0.
3. Baixar o arquivo correspondente a `jboss-eap-7.4.0.zip`, sem confundir com Installer, Source Code, Maven Repository, Quickstarts ou Patch.
4. Registrar o nome exato, a origem e o checksum publicado. Se o portal oferecer outro pacote completo da mesma linha, confirmar sua versão inicial antes de aplicar patches.

A instalação por arquivo é documentada pela Red Hat e requer acesso de leitura/escrita ao diretório. Não exige instalar um serviço Windows para utilização local. [R10][R12]

### 4.3. Cumulativo e correções posteriores

Selecionar no portal o **patch management ZIP** do cumulativo definido na seção 4.5. **Decisão vigente: Update 11**, para espelhar a imagem `7.4.11-openjdk8`. O cumulativo não deve ser extraído por cima do servidor; será aplicado pelo CLI. As informações abaixo sobre o Update 25 servem à decisão de atualização futura.

Na verificação de 19/10/2026 (página atualizada pela Red Hat em 06/10/2026), o calendário listava Update 25 em 06/08/2026 e uma correção individual posterior em 15/09/2026, para CVEs de Artemis e Jackson. Conferir o calendário novamente, abrir as notas/erratas e verificar dependências, pacote correto e instruções antes do download. As notas completas dessas correções exigem acesso de assinante; não foram verificadas em uma sessão autenticada da sua conta. [R4]

O acesso ELS exige assinatura adicional. A conta Developer não garante esse acesso. A ausência do pacote na conta deverá ser tratada com o administrador do contrato Red Hat, não contornada com downloads de terceiros. [R3]

**Registrar separadamente:** último cumulativo publicado, correções posteriores aplicáveis e conjunto efetivamente aprovado/disponível para o projeto. Não fixar automaticamente a versão exibida neste documento como “latest” permanente.

### 4.4. JDK, JDBC e SSO

Para Java, manter um **JDK 8 x64 aprovado**, não apenas JRE. A página oficial de OpenJDK disponibiliza pacote Windows em ZIP. Registrar a atualização utilizada; não assumir que qualquer distribuição Java 8 tenha o mesmo enquadramento de suporte: a Red Hat limita o suporte de OpenJDK às builds da própria Red Hat. O suporte completo do Red Hat build of OpenJDK 8 termina em **30/11/2026**; depois disso, atualizações dependem de direito ELS próprio. [R1][R13][R20]

Para Oracle, obter o driver aprovado no repositório corporativo ou no fornecedor. `ojdbc8.jar` identifica uma família de artefatos, não sua versão completa. A escolha depende da combinação entre JDK, banco e suporte. A Oracle documenta a consulta de versão com `java -jar ojdbc8.jar`. [R14]

O pacote do adaptador SSO será escolhido depois de identificar o mecanismo atual. Não baixar um servidor Keycloak para resolver a integração cliente. A matriz de RH SSO relaciona adaptadores para EAP 7.4, mas isso não elimina a necessidade de validar a versão do servidor de identidade e o ciclo de suporte do conjunto. [R8]

### 4.5. Alinhar o baseline local à imagem do DES

O DES atual roda a imagem `7.1.0-mscore-fonts`. O novo DES será montado pela esteira do Azure com a imagem **`7.4.11-openjdk8`**. O ambiente local deve usar **o mesmo update do EAP e a mesma linha de JDK da imagem de destino**; caso contrário, o teste local deixa de antecipar o DES.

| Item | Imagem de destino | Ambiente local equivalente |
|---|---|---|
| EAP | 7.4.11 (Update 11, de 25/05/2023) | ZIP 7.4.0 + patch cumulativo do Update 11 (seção 7.3) |
| Java | OpenJDK 8 da imagem (fornecedor e atualização a confirmar em ORG-10) | Red Hat build of OpenJDK 8, na mesma atualização quando possível |
| Configuração de boot | Arquivo e scripts de entrada usados pela imagem (ORG-10) | Mesma referência de comparação na seção 8 |
| SO e fontes | Linux, com as fontes que a imagem incluir | Windows, que já tem as fontes Microsoft (FILE-07) |

**Defasagem da 7.4.11.** Depois do Update 11 vieram os Updates 12 a 23 (o último em 14/07/2025), os Updates ELS 24 e 25 e a correção de 15/09/2026. [R4] Como a migração exige regressão completa, decidir a versão **antes** da validação:

- **Preferível:** o DevOps eleva a imagem de destino para a versão-alvo — no mínimo 7.4.23 sem ELS, ou 7.4.25 mais a correção com ELS — e o local acompanha. A imagem oficial EAP 7.4 + OpenJDK 8 aparece como *Deprecated* no catálogo, com tag mais recente 7.4.23; versão superior com Java 8 em container provavelmente exige imagem própria. [R24]
- **Se a imagem não puder mudar agora:** montar o local em 7.4.11 e registrar no manifesto o risco, quem aceitou e o prazo de atualização. Trocar de update depois exige nova regressão.

**Decisão vigente (19/10/2026): a imagem de destino continua `7.4.11-openjdk8` por enquanto.** O ambiente local será montado em 7.4.11 (ZIP 7.4.0 + Update 11). Ficam pendentes o registro formal do aceite do risco, com responsável, e o prazo de atualização (ESTEIRA-20).

**Configuração usada pela imagem.** Se a `7.4.11-openjdk8` deriva da imagem oficial da Red Hat para OpenShift (a confirmar em ESTEIRA-02), ela inicia pelo `openshift-launch.sh` com o arquivo `standalone-openshift.xml`, configurado por variáveis de ambiente e scripts como `postconfigure.sh`. Nesse caso, reconciliar com o DevOps a premissa do perfil full (comparar com XML-11) e a fonte de verdade da configuração. A Red Hat também informa que um `standalone-openshift.xml` do EAP 7.1 precisa ser modificado antes de ser usado com o 7.4. [R25]

**Pendências (ORG-10):** imagem base, arquivo de configuração no boot e fontes da imagem 7.4 estão na esteira do Azure DevOps e foram incluídos nas solicitações da seção 4.6. O cluster de destino é OKD/OpenShift.

### 4.6. Solicitações à equipe da esteira (Azure DevOps)

A imagem do novo DES é definida na esteira do Azure DevOps, e algumas informações só a equipe da esteira pode fornecer. Pedir as respostas citando os IDs abaixo, como **arquivos ou trechos sem segredos** (Dockerfile, YAML da esteira, manifestos do OKD) ou como **resultado de verificação na imagem 7.4.11**. Para a imagem atual do 7.1, pedir apenas definições e arquivos, sem executar comandos no DES em uso.

#### Antes de montar o ambiente local

| ID | Solicitação | Evidência esperada | Uso |
|---|---|---|---|
| ESTEIRA-01 | Referência completa da imagem de destino | `registro/repositório:7.4.11-openjdk8@sha256:...` | Manifesto. A tag pode ser sobrescrita; o digest não |
| ESTEIRA-02 | Definição de build da `7.4.11-openjdk8` | Dockerfile/Containerfile, BuildConfig ou YAML da esteira, com a linha `FROM` | Saber se deriva da imagem oficial Red Hat para OpenShift (por exemplo, `jboss-eap-7/eap74-openjdk8-openshift-rhel8`) ou do ZIP |
| ESTEIRA-03 | Versão do EAP e patches na imagem | `product-version` e `patch info` no container, ou labels da imagem base | Confirmar que é de fato o Update 11 (seção 4.5) |
| ESTEIRA-04 | JDK da imagem | Resultado de `java -version` e caminho do Java | Mesma atualização no local; enquadramento de suporte |
| ESTEIRA-05 | Inicialização do servidor | Entrypoint/CMD, script de boot (por exemplo, `openshift-launch.sh`) e arquivo de configuração usado (`standalone-openshift.xml`, `standalone-full.xml` ou outro) | Base de comparação (seção 8) e premissa do perfil full |
| ESTEIRA-06 | Como a configuração chega ao servidor | XML copiado no build, ConfigMap, variáveis de ambiente, scripts (`postconfigure.sh`, CLI de extensão) e ordem de aplicação | Fonte de verdade (estratégia, 4.4); onde aplicar os itens da seção 2 |
| ESTEIRA-07 | Fontes na imagem 7.4.11 | Lista das fontes instaladas (por exemplo, resultado de `fc-list`) e trecho do build que as instala | FILE-07; decidir se é preciso imagem derivada |
| ESTEIRA-08 | Componentes adicionados à imagem | Módulos (driver Oracle, adaptador SSO, bibliotecas corporativas), versões e origem | MOD-01 a MOD-03; evitar instalação duplicada |
| ESTEIRA-09 | As mesmas definições para a imagem atual `7.1.0-mscore-fonts` | Dockerfile/YAML com `FROM`, pacote de fontes instalado e como o `standalone-full.xml` do repositório entra na imagem | ORG-09; mostra o que o 7.4 precisa reproduzir |

#### Antes de provisionar o novo DES no OKD

| ID | Solicitação | Evidência esperada | Uso |
|---|---|---|---|
| ESTEIRA-10 | Variáveis de ambiente do deployment 7.1 e previstas para o 7.4 | Nomes, origem (variável da esteira, Secret, ConfigMap) e valores não secretos | PIPE-01, JVM-10 |
| ESTEIRA-11 | JVM no container | `JAVA_OPTS` e variáveis de memória da imagem, `TZ`, encoding e locale | JVM-02 e JVM-04; mesmos regionais no local |
| ESTEIRA-12 | Recursos do pod | Requests e limits de CPU e memória; número de réplicas | Dimensionamento e heap |
| ESTEIRA-13 | Persistência | Volumes (PVC) e caminhos de dados, logs, transaction logs, journal JMS e timers; volumes exclusivos para o 7.4 | Isolamento (OPS-01 a OPS-03) |
| ESTEIRA-14 | Rede | Service, Route (host e tipo de TLS), portas e cabeçalhos `X-Forwarded-*` | OPS-05; callbacks do SSO |
| ESTEIRA-15 | Probes | Liveness e readiness: endpoint, porta e tempos | Boot e disponibilidade do 7.4 |
| ESTEIRA-16 | Deploy da aplicação | Se o WAR/EAR entra no build da imagem ou em runtime; origem e versão do artefato | ORG-07; seção 14 |
| ESTEIRA-17 | Separação e gatilhos | Namespace/projeto do novo DES separado do 7.1; gatilhos por branch/commit; garantia de que `feat/jboss-eap-7.4-config` não dispara o 7.1 | Estratégia, seção 4 |
| ESTEIRA-18 | Logs e observabilidade | Destino dos logs (stdout ou arquivo), coleta, retenção e agentes de APM | OPS-06, JVM-09 |
| ESTEIRA-19 | Reversão | Como voltar à imagem e à configuração anteriores; retenção de imagens e tags | Seção 17 |
| ESTEIRA-20 | Atualização da imagem | Viabilidade e prazo para 7.4.23 (ou 7.4.25 com ELS) e a base a usar, já que a imagem oficial OpenJDK 8 está *Deprecated* | Decisão de versão (seção 4.5) |

Registrar cada resposta no inventário da seção 2 com o ID correspondente. A resposta "não sabemos" também é registrada, como pendência com responsável. As respostas não devem conter senhas, tokens nem chaves.

## 5. Preparar diretórios e a sessão Windows

Utilizar uma pasta gravável aprovada. A estrutura abaixo é apenas local e não exige reorganizar o repositório ou mover a instalação 7.1:

```text
C:\dev\eap74\
  downloads\
  runtimes\
  backups\
  coleta-restrita\
  trabalho\
  evidencias\
```

No PowerShell, definir as variáveis. Repetir este bloco nos terminais usados pelo guia, pois as variáveis não são compartilhadas automaticamente entre eles:

```powershell
$ErrorActionPreference = 'Stop'
$Raiz = 'C:\dev\eap74'
$Downloads = Join-Path $Raiz 'downloads'
$Runtimes = Join-Path $Raiz 'runtimes'
$Eap74 = Join-Path $Runtimes 'jboss-eap-7.4'
$Cli74 = Join-Path $Eap74 'bin\jboss-cli.bat'
$Controller74 = '127.0.0.1:10090'
$Jdk8 = 'C:\CAMINHO_APROVADO\jdk8'

foreach ($pasta in @('downloads', 'runtimes', 'backups',
                    'coleta-restrita', 'trabalho', 'evidencias')) {
    New-Item -ItemType Directory -Path (Join-Path $Raiz $pasta) -Force |
        Out-Null
}

if (-not (Test-Path -LiteralPath "$Jdk8\bin\java.exe")) {
    throw 'Ajuste $Jdk8 para um JDK 8 instalado e aprovado.'
}

$env:JAVA_HOME = $Jdk8
$env:JAVA = Join-Path $Jdk8 'bin\java.exe'
$env:JBOSS_HOME = $Eap74
$env:NOPAUSE = 'true'
$env:PATH = "$Jdk8\bin;$env:PATH"

& "$Jdk8\bin\java.exe" -version
& "$Jdk8\bin\javac.exe" -version
```

Conferir retorno `1.8.x`, fornecedor e arquitetura. Revisar variáveis herdadas como `JAVA_OPTS` e `JBOSS_MODULEPATH`, além de `standalone.conf.bat`: elas não devem redirecionar o processo ao Java ou aos módulos do EAP 7.1.

`NOPAUSE` evita que `jboss-cli.bat` e `standalone.bat` aguardem uma tecla ao terminar, o que travaria execuções com `--file`. Quando `JBOSS_HOME` está definido, os scripts `.bat` usam esse valor mesmo que sejam chamados de outra instalação; apenas exibem um aviso. Por isso, não reutilizar um terminal preparado para o 7.4 para operar o EAP 7.1 local, e vice-versa.

Não alterar o Java global do Windows, as configurações do MTA ou as de outras ferramentas. Não utilizar `ExecutionPolicy Bypass`, desabilitar proteção corporativa ou instalar serviço para contornar bloqueios. Os comandos podem ser executados no terminal autorizado; scripts persistentes devem seguir a política da máquina.

## 6. Conferir integridade e instalar o ZIP

Exemplo de verificação, usando o SHA-256 informado pelo portal para o arquivo específico:

```powershell
$ZipEap = Join-Path $Downloads 'jboss-eap-7.4.0.zip'
$ShaEsperado = 'SUBSTITUIR_PELO_SHA256_OFICIAL_DESTE_ARQUIVO'

if ($ShaEsperado -notmatch '^[A-Fa-f0-9]{64}$') {
    throw 'Informe o SHA-256 oficial antes da instalacao.'
}
$ShaObtido = (Get-FileHash -LiteralPath $ZipEap -Algorithm SHA256).Hash
if ($ShaObtido -ne $ShaEsperado) {
    throw 'Checksum divergente. Nao extrair nem executar o pacote.'
}
if (Test-Path -LiteralPath $Eap74) {
    throw 'O destino ja existe. Nao sobreponha uma instalacao anterior.'
}

Expand-Archive -LiteralPath $ZipEap -DestinationPath $Runtimes
if (-not (Test-Path -LiteralPath $Cli74)) {
    throw 'Verifique a estrutura extraida e ajuste $Eap74.'
}
```

Repetir a conferência com o algoritmo/checksum publicado para os demais pacotes. Um hash calculado localmente sem referência confiável serve à rastreabilidade, mas não autentica a origem do arquivo.

**Não copiar o XML nem os módulos do EAP 7.1.** Conferir a existência de `bin\standalone.bat`, `bin\jboss-cli.bat` e `standalone\configuration\standalone-full.xml` no novo diretório.

## 7. Aplicar os patches no EAP 7.4 local

### 7.1. Backup com o servidor parado

Antes do primeiro patch, o servidor ainda não deverá ter sido iniciado. Para atualizações futuras, primeiro desligá-lo de forma controlada.

```powershell
$Backup = Join-Path $Raiz ('backups\eap74-pre-patch-' +
                         (Get-Date -Format 'yyyyMMdd-HHmmss'))
Copy-Item -LiteralPath $Eap74 -Destination $Backup -Recurse -Force
```

O backup abrange a instalação completa, inclusive metadados de patch, configuração e overlays. Proteger seu acesso, pois backups posteriores podem conter segredos. Não apagar manualmente `.installation` ou overlays de módulos.

### 7.2. Terminal A: iniciar somente administração

```powershell
& "$Eap74\bin\standalone.bat" `
    '--server-config=standalone-full.xml' `
    '--admin-only' `
    '-b=127.0.0.1' `
    '-bmanagement=127.0.0.1' `
    '-Djboss.socket.binding.port-offset=100' `
    '-Djboss.node.name=eap74-local' `
    '-Djboss.tx.node.id=eap74-local'
```

O modo administrativo permite configurar o servidor sem iniciar os serviços normais de aplicação. O `port-offset` evita as portas padrão do EAP 7.1 local, mas deve ser conferido quando houver bindings customizados ou portas fixas (XML-08). [R10][R17]

No exemplo padrão, gerenciamento será `127.0.0.1:10090`; HTTP normal será 8180 quando o servidor for iniciado sem `--admin-only`. HTTPS 8543 só será útil se o listener e o TLS estiverem configurados.

### 7.3. Terminal B: aplicar o cumulativo

Reexecutar as variáveis da seção 5 no Terminal B e conectar **explicitamente ao destino**:

```powershell
& $Cli74 --connect "--controller=$Controller74"
```

No CLI:

```text
:read-attribute(name=product-version)
/core-service=server-environment:read-resource(include-runtime=true)
patch info
patch history
```

Confirmar versão **7.4**, diretório da instalação nova e contexto local. Só então executar, substituindo o nome pelo cumulativo definido na seção 4.5 (com a imagem atual de DES, o do Update 11):

```text
patch apply "C:/dev/eap74/downloads/PATCH_CUMULATIVO_APROVADO.zip"
```

Não usar `--override-all` para ignorar conflitos. Um conflito precisa de diagnóstico antes de prosseguir. Ao concluir com sucesso:

```text
shutdown
```

Reiniciar no Terminal A com o mesmo comando administrativo e reconectar no Terminal B:

```text
patch info
patch history
:read-attribute(name=product-version)
```

Comparar `product-version` e o identificador exibido em `patch info` com o update da imagem de destino (seção 4.5) e registrar ambos no manifesto.

Os cumulativos não exigem aplicar todas as atualizações intermediárias. Isso não dispensa os pré-requisitos de correções individuais ou de componentes adicionais. A efetivação do patch requer reinicialização; o guia oficial usa `shutdown --restart=true`, e o reinício manual acima tem o mesmo efeito, permitindo acompanhar o console no Terminal A. Em caso de conflito, consultar `patch --help` e diagnosticar antes de usar qualquer opção de sobrescrita. [R11]

### 7.4. Correção individual, quando aplicável

A correção de 15/09/2026 pressupõe o Update 25. Com o baseline 7.4.11 da imagem atual, esta etapa não se aplica.

Após validar o cumulativo, conferir as instruções e o baseline exigido pela errata da correção individual. Criar novo backup consistente antes da alteração.

Aplicar o pacote aprovado pelo mesmo mecanismo de patch, reiniciar e registrar novamente `patch info` e `patch history`. Não aplicar automaticamente uma correção baseada apenas na data; sua aplicabilidade e dependências precisam ser confirmadas nas notas.

Guardar evidências antes/depois, nomes e hashes dos pacotes, IDs de patch e decisões. Não executar limpeza de histórico enquanto a possibilidade de reversão for necessária.

Para futuras atualizações do 7.4, repetir este ciclo em um candidato isolado: consultar → aprovar → baixar → verificar → fazer backup → aplicar → reiniciar → testar → atualizar manifesto → promover. Não atualizar o EAP automaticamente a cada inicialização.

## 8. Preparar a configuração-base do destino

Após a atualização, parar o servidor e preservar uma cópia do `standalone-full.xml` ainda sem customizações no diretório de trabalho restrito.

```powershell
Copy-Item -LiteralPath "$Eap74\standalone\configuration\standalone-full.xml" `
    -Destination (Join-Path $Raiz 'trabalho\standalone-full-base-eap74.xml')
```

Se houver uma cópia anterior, não a sobrescrever sem registrar a mudança de baseline. Trabalhar no `standalone-full.xml` do novo runtime, mantendo a referência da distribuição para comparação.

**Subsistemas nativos não são baixados um a um.** A distribuição já contém os componentes da plataforma; a configuração determina os recursos utilizados. Para extensões externas, instalar os binários compatíveis antes de referenciá-los no XML. Para bibliotecas customizadas, provisionar módulos próprios. [R5][R6]

Não editar o XML no disco enquanto o servidor estiver em execução. Usar CLI com o servidor iniciado, ou editar/provisionar os arquivos com o processo parado.

Para inspecionar o modelo do destino, utilizar:

```text
:read-children-names(child-type=subsystem)
:read-children-names(child-type=extension)
/subsystem=datasources:read-resource-description(recursive=true,operations=true)
```

`read-resource-description` descreve atributos e operações da versão instalada. Consultar o recurso específico antes de reaplicar atributos antigos. Um XML bem formado não comprova compatibilidade com o modelo do EAP.

Comparar a lista de subsistemas do 7.4 com a lista coletada em XML-11. Um subsistema do 7.1 ausente na base do 7.4 exige decisão registrada: extensão a instalar (por exemplo, adaptador SSO), recurso removido ou item sem uso. Subsistemas que só existem no 7.4, como `health` e `metrics`, permanecem com a configuração padrão. Em seguida, reaplicar sobre esta base somente os itens da seção 2 classificados como **reproduzir**, **adaptar** ou **parametrizar**.

## 9. Instalar o driver Oracle como módulo

### 9.1. Identificar o driver real

Partir de MOD-02 e DS-07 da seção 2. Registrar nome de módulo, slot, arquivo JDBC, versão, checksum e bibliotecas complementares. O nome `ojdbc8.jar` não basta. A matriz do EAP 7.4 lista Oracle 19c com Oracle JDBC 19.3 [R1]. Exemplo de consulta de versão:

```powershell
& "$Jdk8\bin\java.exe" -jar 'C:\CAMINHO_APROVADO\ojdbc8.jar'
```

A consulta acima é documentada pela Oracle. Para drivers que não a suportem, examinar o manifesto/identificação oficial do artefato. Não atualizar o driver somente porque existe um mais novo: selecionar uma versão compatível com Java 8, banco e requisitos de suporte. [R14]

### 9.2. Provisionar os arquivos com o EAP 7.4 parado

Exemplo para módulo `com.oracle`; preservar o identificador real quando ele for um contrato da aplicação:

```text
EAP_HOME/
  modules/
    com/
      oracle/
        main/
          module.xml
          ojdbc8.jar
```

```powershell
$ModuloOracle = Join-Path $Eap74 'modules\com\oracle\main'
if (Test-Path -LiteralPath $ModuloOracle) {
    throw 'Modulo ja existe. Compare a versao antes de substituir.'
}
New-Item -ItemType Directory -Path $ModuloOracle -Force | Out-Null
Copy-Item -LiteralPath 'C:\CAMINHO_APROVADO\ojdbc8.jar' `
    -Destination $ModuloOracle
```

Criar `module.xml`. Exemplo mínimo a validar para o JDBC escolhido:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<module xmlns="urn:jboss:module:1.1" name="com.oracle">
    <resources>
        <resource-root path="ojdbc8.jar"/>
    </resources>
    <dependencies>
        <module name="javax.api"/>
        <module name="javax.transaction.api"/>
    </dependencies>
</module>
```

Esse exemplo não contempla automaticamente wallets, OCI, FAN, UCP ou bibliotecas corporativas. Havendo tais dependências, adaptar o módulo conforme o inventário e a documentação da versão aprovada.

A Red Hat orienta manter módulos próprios fora da árvore nativa `modules/system`. O comando `module add` é Technology Preview; por isso, este guia usa provisionamento explícito dos arquivos, reproduzível também na esteira. Não copiar toda a pasta `modules` do EAP 7.1. [R6]

## 10. Configurar e testar o datasource Oracle

### 10.1. Preparar os valores do processo local

Identificar antes se a origem usa datasource comum ou XA. Os exemplos seguintes são **não XA** e não devem substituir um datasource XA existente.

Para um teste local autorizado, a aplicação pode receber parâmetros por expressões de ambiente. No **Terminal A, antes de iniciar o servidor**, informar os valores de DES/teste autorizados:

```powershell
$env:APP_DB_URL = Read-Host 'URL JDBC do ambiente de teste autorizado'
$env:APP_DB_USER = Read-Host 'Usuario Oracle de teste'
$segredo = Read-Host 'Senha Oracle de teste' -AsSecureString
$ponteiro = [IntPtr]::Zero
try {
    $ponteiro = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($segredo)
    $env:APP_DB_PASSWORD =
        [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ponteiro)
}
finally {
    if ($ponteiro -ne [IntPtr]::Zero) {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ponteiro)
    }
    if ($null -ne $segredo) { $segredo.Dispose() }
}
```

Este exemplo evita gravar a senha no documento ou no histórico de comandos. **Não transforma a variável de ambiente em cofre**: o segredo permanece em memória/ambiente e pode ser acessível a processos autorizados. Usar somente quando permitido pela política corporativa. Para DES, utilizar o mecanismo aprovado de injeção de segredos.

Iniciar novamente o EAP 7.4 em modo administrativo no mesmo Terminal A. Um terminal novo precisará receber os valores novamente. O CLI no Terminal B não precisa receber a senha.

O EAP admite expressões como `${env.APP_DB_URL}` em atributos que suportam expressions. Verificar isso no modelo; não habilitar resolução antecipada de valores no CLI para esses exemplos. [R15][R18]

### 10.2. Registrar o driver

No CLI conectado ao EAP 7.4:

```text
/subsystem=datasources/jdbc-driver=oracle:read-resource
```

Se o recurso estiver realmente ausente, e não houver erro de permissão/conexão:

```text
/subsystem=datasources/jdbc-driver=oracle:add(driver-name=oracle,driver-module-name=com.oracle,driver-class-name=oracle.jdbc.OracleDriver,driver-xa-datasource-class-name=oracle.jdbc.xa.client.OracleXADataSource)
```

Se existir, comparar antes de alterar. O registro da classe XA do driver não converte um datasource comum em XA.

### 10.3. Criar o datasource de aplicação

Ajustar `AppDS` e `java:/jdbc/AppDS` para os nomes reais esperados pela aplicação. No CLI, preservando literalmente `${...}`:

```text
/subsystem=datasources/data-source=AppDS:read-resource
```

Somente para recurso novo:

```text
/subsystem=datasources/data-source=AppDS:add(jndi-name="java:/jdbc/AppDS",driver-name=oracle,connection-url="${env.APP_DB_URL}",user-name="${env.APP_DB_USER}",password="${env.APP_DB_PASSWORD}",jta=true,enabled=false)
```

Esse é um esqueleto de provisionamento, não a configuração final do seu datasource. Reproduzir, conforme DS-01 a DS-06, pool, timeout, isolamento, validação de conexões, exception sorter e propriedades que façam parte do contrato atual. Não copiar o dimensionamento de PRD para o notebook.

Se houver datasource XA, usar `xa-data-source`, preservar propriedades XA e recuperação, e envolver o DBA para validar as permissões necessárias. Não trocar XA por transação local para simplificar o boot. [R5]

### 10.4. Validar no momento correto

O teste real de conexão ocorrerá depois do boot normal, na seção 13. O modo administrativo não comprova conectividade dos serviços de runtime.

Para um recurso existente, preferir mudanças explícitas com `write-attribute` em vez de remover/recriar. Scripts de provisionamento devem distinguir recurso ausente, existente compatível e existente divergente. Os exemplos `add` deste guia são de primeira criação, não uma automação idempotente completa.

## 11. Preparar o cliente Keycloak/Red Hat SSO

### 11.1. Identificar a integração antes de instalar

Conferir o conjunto, não um arquivo isolado:

| Evidência | Consequência para a preparação |
|---|---|
| Subsistema `keycloak` e/ou autenticação `KEYCLOAK` no WAR | Investigar adaptador OIDC do servidor |
| Subsistema `keycloak-saml`, configuração SAML ou mecanismo equivalente | Utilizar o caminho SAML, não o script OIDC |
| `keycloak.json` no WAR | Indica configuração do cliente; não prova que o adaptador do EAP seja dispensável |
| Filtro de autenticação e bibliotecas empacotadas | Verificar o adaptador de aplicação e suas dependências |
| Apenas bibliotecas admin/client para chamar o SSO | Não instalar um subsistema por causa do nome da dependência |

Registrar versão/produto do SSO, protocolo, versão do adaptador, variante legada/Elytron, modo do cliente, forma de obter credenciais, mapeamento de roles e truststore (SSO-01 a SSO-03, MOD-03, APP-01 e APP-06). O servidor de identidade continua externo.

A documentação do RH-SSO 7.6 permite usar o adaptador legado (não Elytron) no EAP 7.1 ou superior; a variante Elytron é exigida com JDK 17, fora deste escopo. Como o EAP 7.1 já possui Elytron, a origem pode usar qualquer das duas: **preservar a variante identificada em SSO-03**, salvo decisão explícita. A escolha concreta depende do pacote e do conjunto suportado. [R7][R8]

### 11.2. Instalar o ZIP de adaptador aprovado

Quando o inventário confirmar a necessidade de adaptador do servidor:

1. Obter o pacote **de adaptador EAP 7** compatível (no RH-SSO 7.6, `rh-sso-7.6.x-eap7-adapter.zip`), no canal autorizado. Não utilizar o ZIP do servidor SSO.
2. Verificar checksum e instruções da versão selecionada.
3. Parar o EAP 7.4 e fazer um novo backup completo.
4. Conferir a estrutura interna do ZIP e confirmar o diretório de extração previsto pelo fornecedor.
5. Extrair na instalação de destino, conforme o procedimento do adaptador.

Exemplo, somente para pacote cujo conteúdo deve ser aplicado à raiz do EAP:

```powershell
$AdapterZip = 'C:\CAMINHO_APROVADO\PACOTE_ADAPTADOR_EAP7.zip'
& "$Jdk8\bin\jar.exe" tf $AdapterZip
if ($LASTEXITCODE -ne 0) { throw 'Nao foi possivel listar o pacote do adaptador.' }
```

Após validar a estrutura, o destino e o backup, executar a extração:

```powershell
Expand-Archive -LiteralPath $AdapterZip -DestinationPath $Eap74 -Force
Get-ChildItem -LiteralPath "$Eap74\bin" -Filter '*adapter*.cli' |
    Select-Object Name
```

O `-Force` acima pertence à instalação controlada do pacote oficial, não autoriza sobrescrever a instalação com módulos antigos. Não copiar `org/keycloak` da origem indiscriminadamente.

### 11.3. Executar o script correspondente no perfil correto

Inspecionar o arquivo CLI fornecido pelo pacote antes de executar. Conferir se ele contém `connect`, `embed-server`, configuração de perfil ou outras instruções que mudem o destino da conexão.

Para um **script online** compatível, iniciar o EAP 7.4 novamente em modo administrativo com `standalone-full.xml` e executar pelo CLI explicitamente conectado a `127.0.0.1:10090`.

Exemplo condicional para adaptador **OIDC legado**, se `adapter-install.cli` existir no pacote e suas instruções confirmarem esse uso:

```powershell
$ScriptAdaptador = Join-Path $Eap74 'bin\adapter-install.cli'
if (-not (Test-Path -LiteralPath $ScriptAdaptador)) {
    throw 'Selecione o script correto do pacote. Nao substitua por outro ao acaso.'
}
Get-Content -LiteralPath $ScriptAdaptador
```

Após a inspeção, confirmar que o destino está em modo administrativo com `standalone-full.xml` e executar em uma etapa separada:

```powershell
& $Cli74 --connect "--controller=$Controller74" "--file=$ScriptAdaptador"
if ($LASTEXITCODE -ne 0) { throw 'Falha na configuracao do adaptador.' }
```

O pacote poderá oferecer `adapter-elytron-install.cli` para a variante Elytron ou scripts específicos de SAML. Esses arquivos não são intercambiáveis. Preservar a variante escolhida no manifesto. [R7]

**Cuidado com scripts offline:** um `embed-server` sem indicação de arquivo usa `standalone.xml`. Como este projeto utiliza full, um script offline deve ser inspecionado e, se necessário, adaptado em uma cópia revisada para iniciar explicitamente:

```text
embed-server --server-config=standalone-full.xml --std-out=echo
```

Preservar o restante do script oficial. Usar essa modalidade com o processo externo do EAP parado e sem `--connect`. Não executar o comando isolado como se ele instalasse o adaptador: ele apenas seleciona o servidor/configuração a administrar. O guia oficial explica o modo embutido e o perfil padrão. [R16]

Alguns scripts offline do projeto Keycloak declaram `embed-server --server-config=${server.config:standalone.xml}`. Nesse caso, em vez de editar a cópia, é possível informar `-Dserver.config=standalone-full.xml` na chamada do CLI, que aceita propriedades `-D`. Confirmar a linha no script do pacote real antes de usar essa alternativa. [R18]

### 11.4. Recriar a configuração do cliente

Após a instalação, verificar os subsistemas efetivamente disponibilizados e reaplicar os recursos identificados na origem, adaptados ao ambiente. Não inventar `secure-deployment` quando a aplicação já fornece a configuração pelo mecanismo correto; também não presumir que copiar `keycloak.json` finalize a integração.

Conferir nome de deployment, realm, identificação do cliente, endereço do SSO, modo bearer-only/público/confidencial, roles e requisitos TLS. Preservar os contratos da aplicação e não copiar client secrets de PRD.

A mudança de host/porta exige revisar callbacks/redirect URIs, origins e URLs públicas pertinentes com a equipe SSO. Solicitar ajustes controlados apenas para o cliente de teste autorizado. Não ampliar redirects para `*` nem desabilitar validação de certificados para contornar problemas.

Reiniciar após alterações que exijam reload/restart e conferir os logs. A homologação do SSO será por login/token e autorização, não apenas pela existência do subsistema.

## 12. Configurar os demais recursos necessários

Reaplicar somente customizações identificadas na seção 2: propriedades e rede (XML-02, XML-07 a XML-09), JMS (JMS-01 a JMS-05), resource adapters e JCA (RA-01, JCA-01), mail (MAIL-01), naming (NAM-01), remoting (REM-01), web services (WS-01), batch (BAT-01), Undertow (WEB-01 a WEB-06), EJB e timers (EJB-01 a EJB-04), EE (EE-01, EE-02), logging (LOG-01, LOG-02), Infinispan (INF-01), JPA (JPA-01), demais subsistemas (PLT-01), segurança (SEC, ELY), arquivos externos e TLS (FILE-01 a FILE-05).

Para cada alteração, registrar o ID de origem, o recurso de destino, a justificativa e o comando/arquivo aplicado. Utilizar a descrição do modelo do EAP 7.4 para validar os atributos. Não substituir JARs internos de Hibernate, RESTEasy ou outras bibliotecas do servidor por cópias trazidas do EAP 7.1.

Arquivos externos precisam existir nos caminhos utilizados pelo processo e ter permissões adequadas. Um valor como `C:\...` não deve ser promovido para DES Linux. Para certificados, verificar finalidade, cadeia, validade e senha por mecanismo autorizado; não compartilhar chaves privadas nem alterar globalmente `cacerts` como solução automática.

Antes de iniciar normalmente, revisar as atividades com efeitos externos: consumidores JMS, jobs, EJB timers, e-mails e gravações. Utilizar recursos de teste isolados ou habilitação controlada. Não copiar diretórios de dados, journals ou transaction logs da origem para “completar” a configuração.

## 13. Validar o runtime e as integrações locais

### 13.1. Boot normal, sem deploy da aplicação

Parar o processo administrativo com `shutdown`. No Terminal A, com os parâmetros e segredos locais necessários já definidos, iniciar sem `--admin-only`:

```powershell
& "$Eap74\bin\standalone.bat" `
    '--server-config=standalone-full.xml' `
    '-b=127.0.0.1' `
    '-bmanagement=127.0.0.1' `
    '-Djboss.socket.binding.port-offset=100' `
    '-Djboss.node.name=eap74-local' `
    '-Djboss.tx.node.id=eap74-local'
```

Acrescentar a esse comando, ou ao `standalone.conf.bat`, `-Dfile.encoding` e `-Duser.timezone` com os valores do container de DES (JVM-04). No Windows, o Java 8 usa a codificação do sistema (normalmente Cp1252) como padrão. Sem esse ajuste, diferenças de acentuação e de horário podem aparecer só no DES ou só no local.

Conectar o CLI do destino no Terminal B e conferir:

```text
:read-attribute(name=product-version)
:read-attribute(name=server-state)
:read-attribute(name=running-mode)
/core-service=server-environment:read-resource(include-runtime=true)
patch info
/subsystem=datasources:installed-drivers-list
```

Esperar modo normal e estado operacional, além de versão e diretórios corretos. A condição `running` sozinha não comprova ausência de serviços com falha. Conferir também o log de inicialização e as operações de validação.

No PowerShell:

```powershell
Get-Content -LiteralPath "$Eap74\standalone\log\server.log" -Tail 200
```

Caso a autenticação local do CLI não esteja disponível, utilizar uma conta de gerenciamento autorizada. Para criar uma conta exclusivamente local, usar o utilitário interativo `bin\add-user.bat`, sem passar a senha na linha de comando. Não copiar usuários de gerenciamento de PRD.

### 13.2. Habilitar e testar o datasource

Para o exemplo da seção 10, no CLI:

```text
/subsystem=datasources/data-source=AppDS:enable
```

Se a resposta exigir reload, executar `reload` no **destino local**, reconectar e verificar o estado. Então:

```text
/subsystem=datasources/data-source=AppDS:test-connection-in-pool
```

Para um datasource XA realmente configurado:

```text
/subsystem=datasources/xa-data-source=NOME_XA_REAL:test-connection-in-pool
```

A conexão bem-sucedida valida uma parte da infraestrutura. Ainda faltam permissões funcionais, comportamento transacional, recuperação e consultas/operações da aplicação.

### 13.3. Congelar o candidato de configuração

Depois da validação de infraestrutura, parar o EAP e registrar a configuração candidata antes do deploy do WAR/EAR. Copiar o XML preparado para o caminho correspondente **na nova branch**, depois de revisar placeholders, segredos e diferenças frente à base.

Se o XML é a fonte de verdade do repositório, não exportar indiscriminadamente o arquivo de runtime depois do deploy: ele pode conter referências a conteúdos de implantação locais. Manter a configuração do servidor e a implantação da aplicação como etapas distintas, salvo mecanismo corporativo já existente e documentado.

## 14. Implantar a aplicação e executar os testes

Reiniciar o destino normalmente. Utilizar o artefato de referência autorizado e registrar seu hash. No CLI:

```text
deploy-info
deploy "C:/ARTEFATOS_AUTORIZADOS/APLICACAO.war"
deploy-info
```

Para EAR, usar o arquivo correspondente. Não usar `--force` na primeira implantação; uma substituição deve ser uma ação deliberada. Preservar nome/contexto do deployment quando ele fizer parte da configuração SSO ou de integrações. Para atualizar uma aplicação já implantada, seguir o procedimento aprovado do projeto.

Executar os testes em dados de desenvolvimento autorizados:

| Frente | Evidência mínima |
|---|---|
| Inicialização | Deploy sem serviços obrigatórios ausentes e log analisado |
| Oracle | Leitura, escrita autorizada e commit/rollback representativos |
| JNDI | Lookups esperados resolvidos |
| SSO | Login ou token no fluxo real, acesso permitido/negado por perfil e expiração/renovação aplicáveis |
| JMS | Produção/consumo controlados, sem disputa com consumidores legados |
| JAX-WS/HTTP | Integrações utilizadas, endpoints e TLS |
| Operação | Jobs e timers habilitados de forma controlada, logs e reinicialização |
| Fontes e relatórios | Relatórios, PDFs e imagens gerados com as fontes esperadas. No Windows a evidência é parcial; a prova vale no DES (FILE-07) |
| Regressão | Cenários críticos definidos pela equipe |

Se o WAR original falhar, classificar a causa: ambiente, biblioteca empacotada, API/comportamento incompatível ou integração. Não atribuir toda falha à configuração. Vincular o problema à issue de migração correspondente.

Ao encerrar o uso local, parar o EAP e remover variáveis sensíveis da sessão:

```powershell
Remove-Item Env:APP_DB_PASSWORD -ErrorAction SilentlyContinue
```

A limpeza deve ocorrer depois de parar o processo que recebeu o segredo. Backups e logs continuam exigindo proteção própria.

## 15. Versionar e publicar o candidato

Revisar os arquivos alterados, sem adicionar a instalação do JBoss ao Git. Binários, backups, configuração bruta de PRD, arquivos privados e diretórios de runtime permanecem fora do repositório.

No clone de configuração:

```powershell
git status --short --branch
git diff --check
git diff --stat
git diff
```

Depois da revisão, adicionar **somente os caminhos identificados**, criar commit e publicar na nova branch. Não utilizar `git add .` para incluir toda a pasta de trabalho sem inspeção. O push deve ocorrer após conferir que não acionará o ambiente EAP 7.1.

Exemplo de publicação de uma branch já revisada e com commit criado:

```powershell
git push --set-upstream origin feat/jboss-eap-7.4-config
if ($LASTEXITCODE -ne 0) { throw 'A publicacao da branch falhou.' }
```

Atualizar o manifesto na documentação existente. Exemplo de conteúdo, não de dados já conhecidos:

```yaml
baseline:
  data_verificacao: "AAAA-MM-DD"
  origem_eap71: "VERSAO + PATCH (ORG-02) + COMMIT_CONFIG (ORG-01)"
  inventario_eap71: "LINK_INTERNO_DO_INVENTARIO_DA_SECAO_2"
  eap_distribuicao: "PREENCHER"
  eap_versao_resultante: "PREENCHER"
  cumulativo_id: "PREENCHER"
  correcoes_individuais: [] # Preencher ou justificar nenhuma aplicavel.
  jdk: "FORNECEDOR + JAVA_8_UPDATE + ARQUITETURA"
  oracle_driver: "VERSAO + MODULO + HASH"
  sso_adapter: "PRODUTO + VERSAO + PROTOCOLO + VARIANTE"
  configuracao_commit: "SHA_DO_COMMIT_APROVADO"
  perfil: "standalone-full.xml"
  artefato_aplicacao: "REFERENCIA + VERSAO + HASH"
  parametros_ambiente: "REFERENCIA_SEM_SEGREDOS"
  mecanismo_segredos: "REFERENCIA_SEM_VALORES"
  des_runtime_ou_imagem: "IMAGEM:TAG@DIGEST (hoje: 7.4.11-openjdk8)"
  des_imagem_base: "OFICIAL_RED_HAT_OPENSHIFT_OU_ZIP + ARQUIVO_DE_CONFIGURACAO_NO_BOOT"
  fontes_imagem: "PACOTE/FONTES INCLUIDAS (ref.: 7.1.0-mscore-fonts)"
  decisao_versao_imagem: "MANTER_7.4.11 (vigente) + ACEITE_DO_RISCO + PRAZO_DE_ATUALIZACAO"
  evidencias: "LINK_INTERNO_AUTORIZADO"
```

Registrar separadamente os hashes de cada pacote, sem valores fictícios de confirmação. Não deixar `PREENCHER` em um candidato promovido.

No Pull Request, informar origem, baseline, diferenças relevantes, testes, pendências, rollback e destinatário correto. Não integrar na branch consumida pelo EAP 7.1 enquanto isso alterar sua execução.

## 16. Provisionar o novo ambiente DES

### 16.1. Fechar os parâmetros com DevOps

Antes da execução, preencher os dados reais do novo ambiente. Os valores de DES dos itens marcados como "varia por ambiente" na seção 2 são a entrada principal desta tabela.

| Item | Decisão necessária |
|---|---|
| Inventário 7.1 | Itens da seção 2 com decisão registrada e valor de DES definido (sem segredos) |
| Respostas da esteira | ESTEIRA-01 a ESTEIRA-20 respondidas ou registradas como pendência com responsável (seção 4.6) |
| Runtime | Imagem `7.4.11-openjdk8` montada pela esteira do Azure DevOps (decisão vigente da seção 4.5): digest, imagem base e responsável |
| Plataforma | OKD/OpenShift: projeto/namespace, arquitetura e combinação suportada |
| Java | OpenJDK 8 da imagem: fornecedor e atualização efetivamente utilizados |
| Fontes | Fontes Microsoft presentes na imagem 7.4 ou em imagem derivada, como na `7.1.0-mscore-fonts` (FILE-07) |
| Configuração | Repositório, commit aprovado, caminho e método de aplicação |
| Aplicação | Origem do WAR/EAR e mecanismo de deploy |
| Rede | DNS, rota, interfaces, portas, certificados, proxies e firewall |
| Oracle | Instância/serviço autorizado, credenciais de DES e limites de conexão |
| SSO | Cliente/realm de DES, endpoints, URLs externas e callbacks autorizados |
| Persistência | Caminhos/volumes exclusivos, transaction logs, timers e JMS |
| Operação | Recursos de CPU/memória, logs, probes e consumidores/jobs |
| Reversão | Versões anteriores, execução, responsáveis e condição de retorno |

Não presumir detalhes do cluster, hosts ou variáveis de pipeline que ainda não foram confirmados. A operação remota seguirá a esteira existente do Azure, com estes dados preenchidos.

### 16.2. Sequência operacional para DES

1. **Separar o destino.** Criar/provisionar o novo ambiente sem substituir o DES EAP 7.1. Confirmar identidade, namespace/host e permissões.
2. **Selecionar o runtime aprovado.** Usar a imagem definida na seção 4.5 (hoje, `7.4.11-openjdk8`), identificada por digest, com Java 8 e fontes confirmados. Mudar de update significa reconstruir ou trocar a imagem pela esteira, não aplicar patch no container. [R11]
3. **Obter o commit aprovado.** A execução deve registrar o SHA resolvido, não apenas o nome mutável da branch.
4. **Provisionar módulos e adaptadores.** Obter binários aprovados do repositório corporativo e conferir versões/hashes. Não copiar a pasta Windows do desenvolvedor.
5. **Aplicar a configuração canônica.** Respeitar o mecanismo do repositório: XML pronto ou scripts/templates. Não aplicar receitas de criação duas vezes.
6. **Injetar parâmetros e segredos.** Usar valores próprios de DES e o mecanismo de proteção aprovado. Ajustar paths, JVM, rede, DNS, TLS e SSO conforme os itens JVM, XML, SSO, FILE e PIPE da seção 2.
7. **Garantir isolamento.** Separar dados de runtime e controlar jobs/consumidores (OPS-01 a OPS-04). Usar `node-identifier` e `jboss.node.name` distintos do 7.1. Não compartilhar journals ou transaction stores com o 7.1.
8. **Validar infraestrutura.** Conferir versão, patch, arquivo de configuração efetivo, módulos, fontes, logs, datasource, endpoints e permissões. Verificar também o resultado efetivo dos scripts de entrada da imagem, que podem gerar ou alterar a configuração.
9. **Implantar e testar a aplicação.** Executar a mesma matriz funcional, incluindo acesso pela URL real do novo DES, autenticação e integrações.
10. **Registrar e aprovar.** Vincular commit, artefato, runtime, configuração efetiva sanitizada, evidências e pendências ao acompanhamento da migração.

Como o DES roda em imagem, a esteira deverá verificar o runtime realmente executado. **Não presumir Java 8 pela tag “EAP 7.4” e não aplicar patches manualmente em pods como procedimento de entrega.** O ajuste da imagem precisa preservar a premissa ou provocar uma decisão explícita, não uma troca silenciosa de JDK.

Em 19/10/2026, o catálogo Red Hat exibia a imagem `jboss-eap-7/eap74-openjdk8-openshift-rhel8` como **Deprecated**, com tag mais recente 7.4.23, abaixo do Update 25. Se essa for a base cogitada, registrar a decisão sobre baseline e suporte com DevOps e arquitetura. [R24]

Os health checks serão os definidos para esse ambiente/aplicação. Não presumir caminhos de Quarkus, probes já existentes ou endpoint de saúde habilitado só porque o servidor iniciou.

### 16.3. Comparação local × DES

Conferir igualdade de versões do EAP (mesmo update da imagem), JDK, JDBC, adaptador e artefato. Validar o mesmo contrato de recursos e diferenças intencionais de parâmetros. Registrar divergências de SO, imagem e JVM que exijam testes adicionais.

Sucesso local não comprova sucesso em DES. Fontes, codificação e fuso horário padrão, DNS, proxy reverso, TLS, permissões de filesystem, case sensitivity, limites de memória do container, credenciais e callbacks devem ser testados no destino real.

## 17. Reversão

### 17.1. Patch EAP 7.4

Consultar `patch history` para obter o identificador real. Antes de qualquer reversão, parar alterações concorrentes, fazer backup consistente e avaliar se a configuração posterior ao patch precisa ser preservada.

Sintaxe oficial, **somente após escolher conscientemente o reset**:

```text
patch rollback --patch-id=ID_REAL_DO_PATCH --reset-configuration=TRUE
```

`TRUE` restaura configuração anterior ao patch e pode descartar alterações posteriores; `FALSE` preserva a configuração, que pode não ser compatível com o binário revertido. Não trocar o valor sem análise. Reiniciar e conferir `patch info`. [R11]

Em caso de dúvida, preferir restaurar um candidato isolado a partir de backup/baseline conhecido para teste, em vez de improvisar sobre o ambiente compartilhado. Não apagar histórico de patches para liberar espaço durante a validação.

### 17.2. Configuração ou ambiente

Para retornar a uma configuração anterior, selecionar o commit e runtime compatíveis, reaplicar parâmetros/segredos autorizados e revalidar a aplicação.

Para retomar o DES EAP 7.1, utilizar a instância e a esteira preservadas. Avaliar dados gravados, mensagens consumidas, jobs, sessões e transações antes de redirecionar tráfego ou reativar consumidores. Trocar a branch não desfaz efeitos externos.

Não excluir `standalone/data`, transaction logs ou journals para “resolver” falhas de migração. Qualquer tratamento desses dados exige um procedimento específico dos responsáveis.

## 18. Diagnóstico e critérios de conclusão

### 18.1. Falhas frequentes

| Sintoma | Verificação prioritária |
|---|---|
| CLI conecta no servidor errado | `--controller`, `JBOSS_HOME` do terminal, `product-version` e `server-environment` antes de alterações |
| `jboss-cli.bat --file` parece travado ao final | `NOPAUSE` não definido: o script aguarda uma tecla (seção 5) |
| Datas, horários ou acentuação diferentes do 7.1 | `user.timezone`, `file.encoding` e locale (JVM-04) |
| Erro de namespace/subsistema | Perfil correto, modelo do 7.4 e extensão instalada; não editar a versão do namespace arbitrariamente |
| Módulo não encontrado | Nome/slot, diretório, `module.xml`, JAR e dependências |
| Driver registrado, conexão falha | DNS/rede, URL, credenciais, serviço Oracle, TLS/wallet e compatibilidade do driver |
| Expressão não resolvida | Variável definida no processo que inicia o EAP e suporte do atributo a expressions |
| Erro SSO/loop de redirecionamento | Adaptador, deployment, realm/cliente, URL externa, callback, proxy e TLS |
| Patch com conflito | Binários alterados, adaptadores/one-offs e pré-requisitos; não ignorar validações |
| Dois ambientes interferem entre si | Filas, jobs, timers, banco, IDs de nó e diretórios persistentes, além de portas |
| Funciona localmente, falha em DES | Runtime real, parâmetros da esteira, paths, permissões, rede e segredos |
| Relatório, PDF ou imagem com fonte trocada ou erro de fonte só no DES | Fontes ausentes na imagem 7.4 (FILE-07, ORG-10) |
| Local e DES com comportamentos diferentes do servidor | Update do EAP diferente entre o local e a imagem (seção 4.5) |

### 18.2. Checklist final

- [ ] Branch nova e commit de origem registrados; esteira do EAP 7.1 preservada.
- [ ] Itens da seção 2 coletados do repositório de configuração, com fonte e decisão registradas; segredos apenas por referência.
- [ ] JDK 8 e pacotes oficiais identificados, com acesso/assinatura verificados.
- [ ] Cumulativo e correções individuais aplicáveis avaliados; instalação resultante registrada.
- [ ] Local no mesmo update e linha de JDK da imagem de DES; decisão sobre a versão da imagem registrada (seção 4.5).
- [ ] Solicitações à esteira (seção 4.6) respondidas e registradas no inventário.
- [ ] Imagem de DES identificada por digest, com Java 8, arquivo de configuração e fontes confirmados.
- [ ] Base full do EAP 7.4 utilizada, sem cópia indiscriminada da origem.
- [ ] Driver Oracle, datasource e modalidade transacional validados.
- [ ] Cliente SSO identificado e testado no mecanismo correto.
- [ ] Recursos externos e atividades automáticas controlados.
- [ ] Configuração versionada sem segredos; aplicação e runtime rastreáveis.
- [ ] Testes locais executados e impedimentos classificados.
- [ ] Novo DES provisionado pelo mecanismo aprovado e testes próprios concluídos.
- [ ] Reversão documentada e validada com os responsáveis.

Para uso pelo Harness Engineering, mapear estas etapas às Run Tasks já existentes. Priorizar tarefas separadas de inventário, início administrativo, CLI, início normal, validação e parada. Não criar uma tarefa que faça download de “latest”, patch, deploy e acesso remoto sem pontos de revisão.

## Referências oficiais

Consulta em 19/10/2026. Os identificadores são compartilhados com o documento de estratégia: o mesmo número indica a mesma fonte. Os links de errata/download podem exigir login e assinatura; esta documentação não acessou sua conta.

- **[R1]** [EAP 7 — Supported Configurations](https://access.redhat.com/articles/2026253). Seção EAP 7.4: JVMs, sistemas operacionais e Oracle 19c com JDBC 19.3.
- **[R2]** [EAP 7.4 — Preparação para migração](https://docs.redhat.com/en/documentation/red_hat_jboss_enterprise_application_platform/7.4/html/migration_guide/prepare_for_migration): listas de funcionalidades depreciadas por versão e revisão de timers e transações.
- **[R3]** [Acesso e download de patches ELS](https://access.redhat.com/solutions/7134413).
- **[R4]** [Maintenance Schedule](https://access.redhat.com/articles/2332721); [Update 25](https://access.redhat.com/articles/7137600); [correção individual para Update 25](https://access.redhat.com/articles/7148114).
- **[R5]** [EAP 7.4 — Datasource Management, incluindo exemplos Oracle e XA](https://docs.redhat.com/en/documentation/red_hat_jboss_enterprise_application_platform/7.4/html/configuration_guide/datasource_management).
- **[R6]** [EAP 7.4 — Class Loading e módulos customizados](https://docs.redhat.com/en/documentation/red_hat_jboss_enterprise_application_platform/7.4/html/configuration_guide/overview_of_class_loading_and_modules).
- **[R7]** [RH SSO 7.6 — instalação dos adaptadores OIDC/SAML e configuração de clientes](https://docs.redhat.com/en/documentation/red_hat_single_sign-on/7.6/html-single/securing_applications_and_services_guide/index).
- **[R8]** [RH SSO — Supported Configurations](https://access.redhat.com/articles/2342861).
- **[R9]** [EAP 7.4 — JBoss Server Migration Tool](https://docs.redhat.com/en/documentation/red_hat_jboss_enterprise_application_platform/7.4/html-single/using_the_jboss_server_migration_tool/index): origens documentadas EAP 6.4 e 7.3.
- **[R10]** [Instalação por ZIP](https://docs.redhat.com/en/documentation/red_hat_jboss_enterprise_application_platform/7.4/html/installation_guide/assembly-archive-installation-of-jboss-eap_default); [início, parada e modo administrativo](https://docs.redhat.com/en/documentation/red_hat_jboss_enterprise_application_platform/7.4/html/configuration_guide/starting_and_stopping_jboss_eap).
- **[R11]** [Patching and Upgrading Guide](https://docs.redhat.com/en/documentation/red_hat_jboss_enterprise_application_platform/7.4/html-single/patching_and_upgrading_guide/index): aplicação e rollback de patches; upgrade entre versões menores.
- **[R12]** [Red Hat Developer — pacotes do EAP](https://developers.redhat.com/products/eap/download).
- **[R13]** [Red Hat build of OpenJDK — downloads](https://developers.redhat.com/products/openjdk/download).
- **[R14]** [Oracle JDBC — downloads e identificação de versão](https://www.oracle.com/database/technologies/appdev/jdbc-downloads.html).
- **[R15]** [EAP 7.4 — Management, modelo e expressões](https://docs.redhat.com/en/documentation/red_hat_jboss_enterprise_application_platform/7.4/html/configuration_guide/jboss_eap_management).
- **[R16]** [EAP 7.4 — Embedded Server para configuração offline](https://docs.redhat.com/en/documentation/red_hat_jboss_enterprise_application_platform/7.4/html/management_cli_guide/running_embedded_server).
- **[R17]** [EAP 7.4 — Network and Port Configuration](https://docs.redhat.com/en/documentation/red_hat_jboss_enterprise_application_platform/7.4/html/configuration_guide/network_and_port_configuration).
- **[R18]** [EAP 7.4 — configuração do CLI e resolução de propriedades](https://docs.redhat.com/en/documentation/red_hat_jboss_enterprise_application_platform/7.4/html/management_cli_guide/config_management_cli).
- **[R20]** [Red Hat build of OpenJDK — Life Cycle and Support Policy](https://access.redhat.com/articles/1299013): OpenJDK 8 com suporte completo até 30/11/2026.
- **[R21]** [EAP 7.4 — Application Migration Changes](https://docs.redhat.com/en/documentation/red_hat_jboss_enterprise_application_platform/7.4/html/migration_guide/application_migration_changes): Hibernate 5.1 → 5.3. A matriz de compatibilidade do projeto (EAP 7.1 → 7.4 com Java 8, Hibernate e cliente SSO), citada originalmente, não está disponível neste repositório; essa referência permanece como lacuna.
- **[R22]** [EAP 7.4.0 Release Notes](https://docs.redhat.com/en/documentation/red_hat_jboss_enterprise_application_platform/7.4/html-single/7.4.0_release_notes/index): funcionalidades depreciadas, inclusive o vault legado.
- **[R24]** [Red Hat Ecosystem Catalog — JBoss EAP 7.4 with OpenJDK8](https://catalog.redhat.com/en/software/containers/jboss-eap-7/eap74-openjdk8-openshift-rhel8/64524bfbd0d670cbd3ee9a57).
- **[R25]** [EAP 7.4 — Getting Started with JBoss EAP for OpenShift Container Platform](https://docs.redhat.com/en/documentation/red_hat_jboss_enterprise_application_platform/7.4/html-single/getting_started_with_jboss_eap_for_openshift_container_platform/index): `openshift-launch.sh`, `standalone-openshift.xml` e scripts de configuração da imagem.

## Histórico de revisões

| Revisão | Data | Alterações |
|---|---|---|
| 1.0 | 15/10/2026 | Versão inicial |
| 1.1 | 19/10/2026 | Origem corrigida para EAP 7.1; seção 2 reescrita como lista explícita de configurações a coletar do repositório de configuração, sem scripts na origem; `NOPAUSE` e `JBOSS_HOME` no Windows; variante do adaptador SSO; ciclo de vida do OpenJDK 8; imagem Java 8 depreciada; fontes revalidadas |
| 1.2 | 19/10/2026 | Imagens do DES registradas (`7.1.0-mscore-fonts` → `7.4.11-openjdk8`, esteira do Azure); nova seção 4.5 com baseline local alinhado à imagem e decisão de versão; itens ORG-09, ORG-10 e FILE-07 (fontes); codificação e fuso do container no boot local; testes, diagnóstico e checklist ajustados |
| 1.3 | 19/10/2026 | Cluster confirmado como OKD/OpenShift; decisão vigente de manter a imagem 7.4.11; nova seção 4.6 com as solicitações à equipe da esteira (ESTEIRA-01 a ESTEIRA-20) |
| 1.4 | 19/10/2026 | Seção 2 alinhada ao DES em container: fontes da coleta (esteira e imagem), ORG-04, origem das opções da JVM e alerta sobre configuração gerada no boot; seção 4.3 apontando para o Update 11 |
