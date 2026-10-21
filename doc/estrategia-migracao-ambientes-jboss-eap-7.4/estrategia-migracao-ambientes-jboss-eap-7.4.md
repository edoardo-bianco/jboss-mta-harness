# Estratégia de migração dos ambientes — JBoss EAP 7.1 para 7.4

**Revisão:** 1.4 — 19/10/2026  
**Escopo:** preparação do ambiente local Windows e do novo DES  
**Documento de execução:** [Guia operacional — Windows e DES](guia-operacional-jboss-eap-7.4-windows-des.md)  
**Matriz de compatibilidade:** EAP 7.1 → 7.4 com Java 8, Hibernate e cliente SSO. O documento citado originalmente não está disponível neste repositório; esta referência permanece como lacuna.

## 1. Resumo executivo

Preparar o JBoss EAP 7.4 em instalações independentes do EAP 7.1, preservando Java 8, as aplicações WAR/EAR, os contratos JNDI, o acesso ao Oracle e a integração cliente com Keycloak/Red Hat SSO.

A configuração será desenvolvida em uma nova branch do repositório de configurações, derivada da referência efetivamente utilizada pelo DES atual. O EAP 7.1 continuará disponível durante a validação. A aprovação local será uma etapa de preparação, não um substituto dos testes no novo DES.

**Decisão central:** partir da configuração fornecida pelo EAP 7.4 — o `standalone-full.xml`, ou o arquivo que a imagem de destino efetivamente usa no boot (a confirmar, seção 6.2) — e reconstruir as customizações necessárias a partir de evidências do EAP 7.1. Não transportar integralmente a instalação antiga nem fazer substituição automática de namespaces no XML.

**Runtime do DES:** o DES atual roda a imagem `7.1.0-mscore-fonts`; o novo DES será montado pela esteira do Azure DevOps com a imagem `7.4.11-openjdk8` e executado em OKD/OpenShift. Por decisão vigente, a imagem permanece em 7.4.11 por enquanto, e o ambiente local acompanha esse update e a linha de JDK da imagem (seção 3.3).

A entrega será um conjunto rastreável: configuração versionada, identificação dos binários, parâmetros de ambiente, referências aos segredos, procedimento de provisionamento e evidências de testes. Somente o XML não representa o ambiente completo.

## 2. Premissas e limites

### 2.1. Informações já confirmadas

| Aspecto | Diretriz |
|---|---|
| Origem | JBoss EAP 7.1 (Java EE 7), modo standalone |
| Perfil utilizado | `standalone-full.xml` |
| Destino | JBoss EAP 7.4 local e novo DES |
| Java | Manter JDK 8; registrar fornecedor e atualização exatos; acompanhar o ciclo de vida (3.1) |
| Aplicações | Preservar WAR/EAR e `javax.*`; intervenção mínima |
| Persistência | Oracle, com configuração efetiva a inventariar; a matriz do EAP 7.4 lista Oracle 19c com JDBC 19.3 [R1] |
| Autenticação | Aplicações clientes de Keycloak/RH SSO; servidor de identidade externo |
| Configuração do DES | Mantida em repositório de configuração; coleta manual a partir dele, sem scripts no servidor de origem |
| Runtime do DES atual | Container com a imagem `7.1.0-mscore-fonts`, que acrescenta as fontes Microsoft; versão e patch exatos do EAP a confirmar |
| Runtime do novo DES | Imagem `7.4.11-openjdk8` (EAP 7.4 Update 11), montada pela esteira do Azure DevOps e executada em OKD/OpenShift; versão mantida por enquanto (3.3) |
| Máquina local | Windows corporativo, PowerShell 5.x, sem depender de privilégios administrativos |
| Versionamento | Configurações já mantidas em branch; criar uma linha específica para EAP 7.4 |
| Ferramentas | Reutilizar VS Code, Git, JBoss CLI e capacidades existentes do Harness Engineering |

**Precisão de plataforma:** a aplicação pode continuar utilizando APIs Java EE 7 (plataforma do EAP 7.1) e `javax.*`, mas o EAP 7.4 implementa Jakarta EE 8. Isso não significa migrar os imports para `jakarta.*`; essa mudança pertence às gerações posteriores da plataforma. A matriz do EAP 7.4 contempla Java 8, condicionada à combinação de JVM, sistema operacional e suporte aplicável. [R1][R2]

### 2.2. Informações ainda a levantar

Não foram recebidos os arquivos reais, a estrutura do repositório de configuração ou os parâmetros da esteira. Portanto, ainda não estão definidos:

- Branch e commit de origem, caminhos dos arquivos e possíveis alterações no servidor fora do repositório.
- Patch atual do EAP 7.1; aceite formal do risco de manter a 7.4.11 e prazo de atualização (seção 3.3).
- Versões do Oracle, do JDBC e do adaptador SSO; utilização de datasource comum ou XA; protocolo OIDC ou SAML.
- Imagem base da `7.4.11-openjdk8` (oficial Red Hat para OpenShift ou montada a partir do ZIP), arquivo de configuração usado no boot e presença das fontes Microsoft. Essas informações estão na esteira do Azure DevOps e foram solicitadas à equipe responsável (guia operacional, seção 4.6).
- Rede, armazenamento, segredos e comportamento da esteira no OKD/OpenShift (mesma seção 4.6).
- Recursos adicionais efetivamente utilizados, como JMS, JAX-WS, módulos customizados e arquivos externos.

Esses pontos serão resolvidos por inventário e validação, não por suposições. O presente documento define a estratégia; não declara que um ambiente já foi instalado ou homologado.

### 2.3. Fora do escopo

Não incluir mudança de linguagem/framework, conversão para Spring Boot ou Quarkus, atualização para EAP 8, troca para `jakarta.*`, alteração de regras de negócio ou migração do servidor SSO. Não impor mudança de infraestrutura ao DES apenas para executar esta migração.

## 3. Baseline, downloads e manutenção

### 3.1. Controle de suporte e acesso

A manutenção regular do EAP 7 terminou em **30/06/2025**. O acesso aos patches ELS exige a assinatura adicional correspondente. Ter uma conta Red Hat Developer não comprova, por si só, esse direito de acesso. A equipe deverá confirmar os direitos associados à conta e à organização antes de escolher o baseline corporativo. [R3]

Na consulta de **19/10/2026** (página atualizada pela Red Hat em 06/10/2026), o calendário oficial lista **Update 25 (ELS), de 06/08/2026**, e uma **correção individual posterior, de 15/09/2026**, relacionada a Artemis/Jackson. Assim, “último cumulativo” não equivale necessariamente a “todas as correções aplicáveis”. Revalidar o portal e os requisitos da errata no momento do download. [R4]

**Java 8 tem prazo próprio.** O suporte completo do Red Hat build of OpenJDK 8 termina em **30/11/2026**; a fase ELS-1, até 31/12/2032, exige direito ELS próprio. A Red Hat limita o suporte de OpenJDK às builds da própria Red Hat. [R1][R20] Em 08/09/2026, a política de ciclo de vida registrou a extensão das fases ELS-1 e ELS-2 do EAP 7 para acompanhar o ciclo do OpenJDK 8; as datas vigentes devem ser lidas na página oficial no momento da decisão. [R19] Manter Java 8 exige, portanto, confirmar os direitos de suporte do EAP **e** do JDK.

**Cliente SSO.** A manutenção da família RH-SSO 7.x terminou em 30/06/2025. Confirmar o enquadramento de suporte do adaptador escolhido para o EAP 7.4 e sua interoperabilidade com o servidor de identidade em uso, sem colocar esse servidor no escopo da migração. [R8][R23]

A falta de acesso não autoriza obter pacotes por canais não oficiais. Nesse caso, registrar o impedimento e solicitar à equipe responsável pelo contrato o acesso ou o fornecimento dos artefatos por um canal corporativo autorizado. Não tratar uma versão antiga acessível como baseline atualizada sem registrar essa limitação.

### 3.2. Manifesto do ambiente

Cada candidato a implantação deverá identificar:

| Componente | Registro obrigatório |
|---|---|
| Origem | Versão e patch do EAP 7.1 de DES e commit de configuração que serviu de base |
| EAP | Distribuição de origem, versão resultante, patch cumulativo e correções individuais |
| JVM | Fornecedor (build suportada), Java 8, atualização e arquitetura |
| Oracle | Versão do banco, driver, nome do módulo, arquivos complementares e hashes |
| SSO | Produto/versão do adaptador, protocolo e variante de integração |
| Configuração | Repositório, branch, commit e arquivo utilizado |
| Ambiente | Perfil de parâmetros, mecanismo de segredos, rede e recursos persistentes |
| Aplicação | Artefato, versão e hash do WAR/EAR |
| DES | Imagem (nome, tag e digest), imagem base, arquivo de configuração no boot e fontes incluídas |

Local e DES deverão usar os mesmos componentes lógicos e versões aprovadas. Caminhos, dimensionamento, endpoints e forma de iniciar o processo serão específicos de cada ambiente.

### 3.3. Baseline definido pela imagem de destino

A imagem `7.4.11-openjdk8` corresponde ao **Update 11, de 25/05/2023**. Depois dele vieram os Updates 12 a 23 (o último em 14/07/2025), os Updates ELS 24 e 25 e a correção de 15/09/2026. [R4] O ambiente local deve usar o mesmo update da imagem; caso contrário, deixa de antecipar o DES.

Como a migração exige regressão completa, a versão deve ser decidida **antes** da validação:

| Opção | Consequência |
|---|---|
| Atualizar a imagem para a versão-alvo (mínimo 7.4.23 sem ELS; 7.4.25 mais a correção com ELS) e alinhar o local | Uma única regressão no baseline final. A imagem oficial EAP 7.4 + OpenJDK 8 aparece como *Deprecated*, com tag mais recente 7.4.23; versão superior com Java 8 em container provavelmente exige imagem própria [R24] |
| Manter a 7.4.11 e alinhar o local | Paridade imediata com a esteira, com exposição a mais de três anos de correções ausentes. Exige aceite formal do risco e prazo de atualização; a troca posterior de update exige nova regressão |

A recomendação é a primeira opção, se o DevOps puder atualizar a imagem dentro da janela da migração. A decisão e o responsável pelo aceite entram no manifesto.

**Decisão vigente (19/10/2026): manter a imagem `7.4.11-openjdk8` por enquanto.** Consequências:

- O ambiente local é montado em 7.4.11 (ZIP 7.4.0 + Update 11).
- O aceite do risco precisa ser formalizado, com responsável, e o prazo de atualização definido com a equipe da esteira (ESTEIRA-20 no guia operacional).
- Antes de promover além do DES, reavaliar a atualização; qualquer troca de update repete a regressão.

## 4. Estratégia Git: nova branch, sem reorganização desnecessária

### 4.1. Origem correta

Identificar a branch utilizada pela esteira do DES EAP 7.1 e registrar seu commit. Como a configuração do DES é mantida no repositório e não haverá coleta por script no servidor, confirmar com DevOps que esse commit, somado aos parâmetros e às transformações da esteira, corresponde ao que está implantado.

Alterações feitas diretamente no servidor, fora do repositório, devem ser declaradas pelo DevOps, registradas e avaliadas. Nem toda diferença é defeito: algumas podem resultar de substituição de variáveis, geração de configuração ou registros de deployment.

### 4.2. Branch de trabalho

Nome proposto: `feat/jboss-eap-7.4-config`.

Criar a branch a partir da referência confirmada do EAP 7.1. **Manter, inicialmente, os caminhos já utilizados no repositório.** A configuração 7.4 evolui nesses caminhos na nova branch; a configuração 7.1 permanece preservada na branch de origem e no commit de referência.

Não é obrigatório criar pastas paralelas `eap71/` e `eap74/`, nem duplicar configurações completas para cada ambiente. Essa reorganização somente se justifica caso a esteira precise consumir ambas as versões a partir de uma mesma branch.

Não renomear ou mover arquivos originais como parte desta documentação. Revisar com DevOps os gatilhos antes do primeiro push: criar uma branch não deve provocar implantação involuntária.

### 4.3. Implantação e integração

A esteira do novo DES deverá selecionar explicitamente o commit da configuração EAP 7.4 e o runtime correspondente. A esteira do DES EAP 7.1 não será redirecionada automaticamente.

O destino do Pull Request deverá respeitar essa separação. **Não integrar sobre a linha que alimenta o EAP 7.1 enquanto isso substituir inadvertidamente sua configuração.** Usar revisão na linha de migração ou destino autorizado até a decisão de transição.

Correções urgentes feitas no EAP 7.1 durante a coexistência serão avaliadas para reaplicação no 7.4. Não fazer merges cegos dos XMLs entre as versões.

### 4.4. Fonte de verdade

Preservar o mecanismo já utilizado pelo repositório. Caso a esteira consuma `standalone-full.xml`, esse arquivo revisado será a configuração canônica. Scripts CLI registrarão a receita de construção e alterações controladas; não deverão competir com o XML como uma segunda configuração independente.

Caso a esteira já gere o XML por scripts/templates, manter os geradores como fonte de verdade e tratar o XML como saída. **A promoção deverá ter uma única origem declarada.** Não aplicar indiscriminadamente scripts de criação sobre um XML que já contém os mesmos recursos.

## 5. Inventário orientado a dependências

### 5.1. Referências

**DES** será a referência principal de execução e integração. **PRD** será uma referência complementar para identificar diferenças importantes, não uma fonte de credenciais, dados ou endereços a transportar para desenvolvimento. O **EAP 7.1 local** permitirá verificar o que já funciona na máquina.

A coleta é **manual e explícita**: no DES, a configuração do JBoss está no repositório de configuração, e não serão executados scripts de coleta no servidor de origem. Coletar do repositório, da esteira e dos responsáveis a identificação da origem, a inicialização/JVM, cada bloco do `standalone-full.xml`, módulos, arquivos externos, descritores da aplicação e itens operacionais. A lista completa, com IDs rastreáveis e o destino de cada item no 7.4 local e no DES, está na seção 2 do guia operacional.

### 5.2. O que significa “subsistema necessário”

Um subsistema presente no XML não prova que a aplicação o utiliza. Sua ausência em uma leitura sem permissão também não prova que ele inexiste. A decisão deverá cruzar:

1. Recursos configurados no servidor e diferenças frente à distribuição original.
2. Referências no WAR/EAR, descritores, código e bibliotecas.
3. Comportamento observado em inicialização e testes representativos.

Distinguir três operações: **configurar um subsistema nativo**, **instalar uma extensão/adaptador externo** e **provisionar um módulo de biblioteca**. Oracle JDBC, por exemplo, não exige um “subsistema Oracle”: utiliza o subsistema `datasources` e um driver. [R5][R6]

### 5.3. Decisões por área

| Área | Orientação de migração |
|---|---|
| Perfil full | Manter a base full do 7.4; não fazer uma redução de subsistemas durante a primeira validação |
| Datasources/JCA/transações | Preservar JNDI, modalidade XA ou não XA, contratos e recuperação |
| Driver Oracle | Provisionar a versão aprovada, sem substituir bibliotecas internas do EAP |
| SSO/segurança | Identificar o mecanismo efetivo e instalar somente o adaptador compatível necessário |
| Undertow, EJB, CDI, JPA, JAX-RS | Manter a base do destino; analisar customizações e dependências da aplicação |
| JMS | Confirmar filas, tópicos, MDBs, factories e persistência; não assumir uso apenas por ser full |
| JAX-WS/JNDI/JMX | Preservar integrações comprovadas e seus contratos |
| Logs, propriedades, TLS e arquivos | Adaptar por ambiente sem transportar segredos ou dados operacionais |

Classificar cada customização como **reproduzir**, **adaptar**, **parametrizar**, **não transportar com justificativa** ou **pendente de investigação**. A ausência de evidência não autoriza excluir um recurso potencialmente necessário.

### 5.4. Oracle e SSO

Para módulos próprios, utilizar a área de módulos customizados, como `EAP_HOME/modules/com/oracle/main`, preservando o identificador real do módulo quando necessário. Não usar a árvore de módulos nativos do produto como destino padrão de bibliotecas próprias. [R6]

A presença de `keycloak.json` no WAR **não demonstra que o adaptador de servidor é dispensável**. É necessário verificar `web.xml`, `jboss-web.xml`, dependências, subsistema e mecanismo de autenticação. A integração poderá utilizar um adaptador no EAP, um filtro empacotado, SAML ou apenas bibliotecas clientes para chamadas ao SSO. A variante será escolhida após o inventário. [R7]

Não migrar toda a segurança para Elytron por conveniência. O EAP 7.1 já possui Elytron, e a origem pode usar o subsistema `security` legado, o `elytron` ou ambos. A documentação do RH-SSO 7.6 permite o adaptador legado (não Elytron) no EAP 7.1 ou superior e exige a variante Elytron apenas com JDK 17, fora deste escopo. Portanto, **preservar a variante encontrada no inventário**; tratar mudanças como decisões explícitas, com teste de autenticação e autorização. Também não presumir que “último Keycloak” seja o adaptador adequado ao EAP 7.4. [R7][R8]

O vault legado continua disponível no EAP 7.4, mas está depreciado; a Red Hat indica o credential store como substituto. Se a origem usa vault, mantê-lo na primeira migração é aceitável; a troca deve ser uma decisão registrada. [R22]

### 5.5. Automação da migração do servidor

A reconstrução controlada é o caminho principal. O guia da JBoss Server Migration Tool distribuída no EAP 7.4 documenta EAP 6.4 e 7.3 como origens; **EAP 7.1 → 7.4 não é um caminho documentado dessa ferramenta**. Um caminho automatizado alternativo exigirá confirmação da versão e do suporte aplicável. [R9]

O Patching and Upgrading Guide descreve o upgrade entre versões menores copiando `standalone/` para a nova instalação e **comparando e atualizando os arquivos de configuração** com os da nova versão, sem sobrescrever `bin/`, e revisando módulos customizados e `welcome-content`. [R11] Esta estratégia faz a mesma comparação no sentido inverso: parte da configuração do 7.4 e reaplica somente as customizações comprovadas do 7.1. O resultado é rastreável item a item e não transporta `data/`, `tmp/` ou `log/`.

O Migration Guide do 7.4 foi escrito principalmente para origem EAP 6. Para origem 7.1, considerar as listas de funcionalidades depreciadas e sem suporte das versões 7.2, 7.3 e 7.4, as orientações sobre timers e transações pendentes e as mudanças de aplicação, como Hibernate 5.1 → 5.3, já tratadas na matriz de compatibilidade do projeto. [R2][R21][R22]

MTA analisa a aplicação; não instala o driver, não configura o cliente SSO e não provisiona o novo DES. Essas atividades permanecem nesta frente de ambiente.

## 6. Preparação local e construção do novo DES

### 6.1. Local Windows

Instalar por ZIP em pasta gravável, separada da origem. Selecionar explicitamente o JDK 8 para o processo do EAP e do CLI. Não depender do Java padrão do terminal nem alterar a configuração das ferramentas de análise que usam outros JDKs.

Primeiro validar a distribuição limpa e atualizada em modo administrativo. Depois provisionar módulos, segurança e recursos. Somente então iniciar os serviços de aplicação e implantar o WAR/EAR. O procedimento detalhado está no guia operacional. [R10]

Windows 11 será o ambiente local informado pelo usuário. **Não afirmar que a validação nessa máquina comprova uma configuração oficialmente testada para DES**: a matriz consultada enumera combinações específicas, incluindo Windows Server. A combinação real do DES precisa de verificação própria. [R1]

O local espelha a imagem de destino: mesmo update do EAP (hoje, 7.4.11) e mesma linha de JDK. Ainda assim, o Windows difere do container Linux em pontos que o teste local não cobre: fontes (o Windows já tem as fontes Microsoft que a imagem `7.1.0-mscore-fonts` precisou acrescentar), codificação e fuso horário padrão da JVM, caminhos que diferenciam maiúsculas e minúsculas e limites de memória do container. Esses pontos são validados no DES.

### 6.2. Novo DES

O novo DES será montado pela esteira do Azure DevOps com a imagem `7.4.11-openjdk8` e executado em OKD/OpenShift. As informações sobre a imagem e a execução que só a esteira conhece estão listadas nas solicitações da seção 4.6 do guia operacional. Não transportar a pasta Windows nem aplicar um patch manual dentro de um pod em execução como processo definitivo; mudar de update significa reconstruir ou trocar a imagem.

Registrar o digest da imagem, incorporar os módulos e configurações pelo mecanismo da esteira e validar Java 8, fontes, armazenamento, permissões e suporte da combinação. Não presumir que uma imagem do EAP 7.4 use Java 8 apenas pela tag.

**Fontes.** A imagem atual do 7.1 acrescenta as fontes Microsoft, o que indica dependência de relatórios, PDFs ou imagens. Se a `7.4.11-openjdk8` não as incluir, será necessária uma imagem derivada, montada como a do 7.1. A verificação foi solicitada à esteira (ESTEIRA-07 e ESTEIRA-09).

**Arquivo de configuração da imagem.** A origem da imagem ainda não é conhecida (ESTEIRA-02 e ESTEIRA-05). Se ela deriva da imagem oficial da Red Hat para OpenShift, inicia com `standalone-openshift.xml`, configurado por variáveis de ambiente e scripts de entrada. Nesse caso, a premissa do perfil full e a fonte de verdade da configuração (seção 4.4) precisam ser reconciliadas com o DevOps. A Red Hat informa ainda que um `standalone-openshift.xml` do EAP 7.1 precisa ser modificado antes de ser usado com o 7.4. [R25] Em 19/10/2026, o catálogo Red Hat exibia a imagem `jboss-eap-7/eap74-openjdk8-openshift-rhel8` como **Deprecated**, com tag mais recente 7.4.23, abaixo do Update 25. Usar essa base exige decisão registrada sobre baseline e suporte. [R24]

A configuração lógica será a mesma validada localmente, com parâmetros próprios para DES. Boot, atualização e empacotamento seguem a esteira de imagem do destino; a instalação ZIP local serve para espelhar versão e configuração, não para gerar o runtime do DES. ZIP e imagem não são intercambiáveis. [R11]

Na coleta do DES 7.1, considerar que a imagem e a esteira podem gerar ou alterar configuração no boot (variáveis de ambiente e scripts), além do XML do repositório. Essas fontes também entram no inventário (guia operacional, seção 2.4).

### 6.3. Coexistência segura

Separar portas, identificação dos nós (inclusive o `node-identifier` de transações, sobretudo com XA no mesmo Oracle), arquivos de runtime, logs, transaction logs, journals JMS e dados de timers. O deslocamento de portas resolve apenas colisões de rede.

Antes de executar os dois ambientes, controlar consumidores de filas, jobs agendados, EJB timers, envio de mensagens e gravações no banco. Dois servidores apontando para as mesmas integrações podem processar trabalho real em duplicidade.

O novo ambiente iniciará com integrações de teste autorizadas ou funcionalidades ativas de maneira controlada. Não compartilhar volumes de runtime entre 7.1 e 7.4. Não copiar `standalone/data`, journals ou transações de PRD para a máquina local.

## 7. Segurança e parametrização

Separar configuração estrutural, parâmetros de ambiente e segredos. O repositório deverá conter a estrutura e referências, não senhas, tokens, client secrets, chaves privadas, arquivos de credential store ou hashes de usuários.

Reutilizar o mecanismo corporativo de segredos, sem introduzir uma troca geral de segurança apenas por causa da migração. Avaliar credential store quando pertinente ao atributo e ao mecanismo utilizado, sem presumir suporte idêntico em todos os subsistemas.

O ambiente local não deverá usar credenciais de PRD. Acesso de gerenciamento deve permanecer restrito; alterações remotas ocorrerão somente pelos canais aprovados.

Antes de compartilhar configurações, sanitizar cópias e manter substituições consistentes entre arquivos e ambientes. Por exemplo, o mesmo JNDI anonimizado deverá manter a mesma identificação no XML e nos descritores. Também revisar comentários, URLs com credenciais, certificados, arquivos externos e relatórios.

## 8. Etapas, responsáveis e critérios de aprovação

| Etapa | Responsabilidade principal | Condição para avançar |
|---|---|---|
| Inventário e baseline | Arquitetura + DevOps | Configurações e versões identificadas; dúvidas registradas |
| Imagem e esteira | Equipe da esteira (Azure DevOps) | ESTEIRA-01 a 09 respondidas antes do ambiente local; ESTEIRA-10 a 20 antes do novo DES |
| Branch e esteira | DevOps + responsável pelo repositório | Referência correta e nenhuma implantação involuntária |
| Runtime local | Arquitetura/desenvolvimento | JDK, cumulativo e correções verificados; boot limpo |
| Integrações | Desenvolvimento + DBA + equipe SSO | Oracle, segurança e serviços necessários testados |
| Aplicação local | Desenvolvimento + testes | Deploy e fluxos mínimos executados, ou impedimentos classificados |
| Novo DES | DevOps + arquitetura | Provisionamento reproduzido a partir do commit aprovado |
| Aceite DES | Desenvolvimento + testes + responsáveis pelas integrações | Regressão, isolamento operacional e reversão aprovados |

Testar inicialmente o artefato de referência, quando seu uso no novo ambiente for seguro, para separar defeitos de configuração de incompatibilidades da aplicação. **Falha no WAR original é evidência de diagnóstico, não prova automática de ambiente mal configurado.** A homologação funcional poderá depender das correções de aplicação já planejadas.

Distinguir três marcos: **runtime preparado**, **integrações validadas** e **aplicação homologada**. Não registrar um como se significasse os demais.

## 9. Reversão e operação

Reverter uma branch não reverte o ambiente inteiro. Preservar o runtime anterior, aplicações, parâmetros, segredos referenciados, configuração implantada e mecanismo de roteamento.

Separar a reversão do patch, a reversão da configuração e a retomada do EAP 7.1. A decisão deverá considerar dados gravados, mensagens processadas, transações e sessões existentes. Nenhuma rotina deste plano apagará automaticamente esses dados.

Antes de uma mudança de patch, produzir backup consistente e registrar o estado anterior. A opção de reset de configuração em um rollback de patch pode descartar alterações posteriores; sua escolha deverá ser explícita. [R11]

A troca definitiva de ambiente dependerá da validação do retorno operacional, não apenas de um comando Git.

## 10. Relação com o Harness Engineering

Reutilizar as capacidades existentes de inventário, execução local e coleta de evidências. O harness poderá invocar as etapas do guia por Run Tasks, sem se tornar uma fonte paralela de configuração.

A IA poderá auxiliar na comparação, classificação de diferenças e proposta de CLI. O fluxo deverá manter revisão humana, execução controlada e retorno dos testes. Não autorizar alterações autônomas em DES/PRD ou publicação de material sensível.

Registrar status e impedimentos no acompanhamento de migração já utilizado, com links para configurações, relatórios e evidências. Evitar copiar integralmente relatórios MTA ou repetir inventários em vários documentos. Esta entrega não implementa nem modifica o harness.

## 11. Entregáveis e próximo conjunto de entradas

A entrega deverá conter configuração EAP 7.4 na branch própria, manifesto de versões, inventário de customizações, procedimento operacional, evidências e plano de reversão.

Para transformar os exemplos em uma configuração específica, preencher o inventário da seção 2 do guia operacional a partir do repositório de configuração do DES: identificação da origem, inicialização e parâmetros da esteira, blocos do `standalone-full.xml`, `module.xml` e identificação do JDBC, cliente SSO, arquivos externos, descritores da aplicação e itens operacionais. PRD e o EAP 7.1 local entram apenas como comparação. Não é necessário compartilhar o JBoss inteiro, os JARs corporativos ou os segredos.

**Resultado esperado:** o novo DES deve ser reconstruível a partir de versões e configurações aprovadas, sem depender da cópia informal da instalação de um desenvolvedor e sem comprometer a continuidade do EAP 7.1.

## Referências oficiais

Fontes verificadas em 19/10/2026. Os identificadores são compartilhados com o guia operacional: o mesmo número indica a mesma fonte. Páginas de download e erratas podem exigir autenticação e assinatura. Acesso a um link não comprova direito ao pacote.

- **[R1]** [EAP 7 — Supported Configurations](https://access.redhat.com/articles/2026253). Seção EAP 7.4: JVMs, sistemas operacionais e Oracle 19c com JDBC 19.3.
- **[R2]** [EAP 7.4 — Preparação para migração](https://docs.redhat.com/en/documentation/red_hat_jboss_enterprise_application_platform/7.4/html/migration_guide/prepare_for_migration) e [mudança de namespace na migração para EAP 8](https://docs.redhat.com/en/documentation/red_hat_jboss_enterprise_application_platform/8.0/html/migration_guide/application-migration-from-jakarta-ee-8-to-ee-10_default).
- **[R3]** [Como obter os patches ELS do EAP 7.4](https://access.redhat.com/solutions/7134413).
- **[R4]** [Calendário de manutenção do EAP 7](https://access.redhat.com/articles/2332721); [Update 25](https://access.redhat.com/articles/7137600); [correção individual posterior para Update 25](https://access.redhat.com/articles/7148114).
- **[R5]** [EAP 7.4 — Datasource Management](https://docs.redhat.com/en/documentation/red_hat_jboss_enterprise_application_platform/7.4/html/configuration_guide/datasource_management).
- **[R6]** [EAP 7.4 — Class Loading e módulos](https://docs.redhat.com/en/documentation/red_hat_jboss_enterprise_application_platform/7.4/html/configuration_guide/overview_of_class_loading_and_modules).
- **[R7]** [RH SSO 7.6 — Securing Applications and Services](https://docs.redhat.com/en/documentation/red_hat_single_sign-on/7.6/html-single/securing_applications_and_services_guide/index).
- **[R8]** [RH SSO — Supported Configurations](https://access.redhat.com/articles/2342861).
- **[R9]** [EAP 7.4 — JBoss Server Migration Tool](https://docs.redhat.com/en/documentation/red_hat_jboss_enterprise_application_platform/7.4/html-single/using_the_jboss_server_migration_tool/index).
- **[R10]** [Instalação por arquivo ZIP](https://docs.redhat.com/en/documentation/red_hat_jboss_enterprise_application_platform/7.4/html/installation_guide/assembly-archive-installation-of-jboss-eap_default) e [inicialização e modo administrativo](https://docs.redhat.com/en/documentation/red_hat_jboss_enterprise_application_platform/7.4/html/configuration_guide/starting_and_stopping_jboss_eap).
- **[R11]** [EAP 7.4 — Patching and Upgrading Guide](https://docs.redhat.com/en/documentation/red_hat_jboss_enterprise_application_platform/7.4/html-single/patching_and_upgrading_guide/index): aplicação e rollback de patches; upgrade entre versões menores.
- **[R19]** [Política de ciclo de vida dos produtos de Application Services](https://access.redhat.com/support/policy/updates/jboss_notes) e [disponibilidade do ELS do EAP 7](https://access.redhat.com/articles/7116565).
- **[R20]** [Red Hat build of OpenJDK — Life Cycle and Support Policy](https://access.redhat.com/articles/1299013).
- **[R21]** [EAP 7.4 — Application Migration Changes](https://docs.redhat.com/en/documentation/red_hat_jboss_enterprise_application_platform/7.4/html/migration_guide/application_migration_changes): Hibernate 5.1 → 5.3.
- **[R22]** [EAP 7.4.0 Release Notes](https://docs.redhat.com/en/documentation/red_hat_jboss_enterprise_application_platform/7.4/html-single/7.4.0_release_notes/index): funcionalidades depreciadas, inclusive o vault legado.
- **[R23]** [RH-SSO 7 — fim do suporte completo e da manutenção](https://access.redhat.com/articles/5252391) (conteúdo integral para assinantes).
- **[R24]** [Red Hat Ecosystem Catalog — JBoss EAP 7.4 with OpenJDK8](https://catalog.redhat.com/en/software/containers/jboss-eap-7/eap74-openjdk8-openshift-rhel8/64524bfbd0d670cbd3ee9a57).
- **[R25]** [EAP 7.4 — Getting Started with JBoss EAP for OpenShift Container Platform](https://docs.redhat.com/en/documentation/red_hat_jboss_enterprise_application_platform/7.4/html-single/getting_started_with_jboss_eap_for_openshift_container_platform/index): `openshift-launch.sh`, `standalone-openshift.xml` e scripts de configuração da imagem.

## Histórico de revisões

| Revisão | Data | Alterações |
|---|---|---|
| 1.0 | 15/10/2026 | Versão inicial |
| 1.1 | 19/10/2026 | Origem corrigida para EAP 7.1, em linha com a matriz de compatibilidade do projeto; coleta manual a partir do repositório de configuração; ciclo de vida do OpenJDK 8 e do RH-SSO 7; procedimento oficial de upgrade entre versões menores; variante do adaptador SSO; vault depreciado; imagem Java 8 depreciada; fontes revalidadas |
| 1.2 | 19/10/2026 | Imagens do DES registradas (`7.1.0-mscore-fonts` → `7.4.11-openjdk8`, esteira do Azure); seção 3.3 com baseline definido pela imagem e decisão de versão; local espelhando a imagem; fontes e arquivo de configuração da imagem; pendências de imagem base e cluster |
| 1.3 | 19/10/2026 | Cluster confirmado como OKD/OpenShift; decisão vigente de manter a 7.4.11; pendências de imagem encaminhadas à equipe da esteira (guia, seção 4.6); responsabilidade da esteira nas etapas |
| 1.4 | 19/10/2026 | Seção 6.2 alinhada ao DES em container: papel da instalação ZIP local e configuração gerada no boot como fonte da coleta |
