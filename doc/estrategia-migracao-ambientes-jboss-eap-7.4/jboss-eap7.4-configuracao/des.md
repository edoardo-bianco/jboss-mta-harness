# Preparo de DES: imagem pela esteira e execucao no OKD

Roteiro generico para EAP 7.4, Java 8 e APIs `javax.*`, com imagem construida
pela esteira Azure DevOps. A aplicacao fornece seu inventario e seu repositorio
de configuracao. Dados reais e decisoes especificas ficam na pasta privada de
DES, separados do [preparo Windows](README.md).

**Responsabilidades:** nossa entrega cobre os arquivos fornecidos, sua revisao
e instrucoes de uso. Imagem, pipeline e manifests/operacao OKD pertencem a outra
equipe. As etapas de plataforma abaixo sao referencias para essa equipe;
ausencia desses arquivos nao bloqueia a correcao do harness nem a revisao da
configuracao recebida. As pendencias do caso atual estao no
[registro de validacao de desenvolvimento](../jboss-eap7.4-configuracao-des/README.md).

## 1. Um template por aplicacao, dois conjuntos de valores

O objetivo e manter **um unico template standalone EAP 7.4 por aplicacao**,
versionado no repositorio de configuracao e usado no local e em DES. Os valores
variam por ambiente. A configuracao original de DES 7.1 e a referencia funcional:
preservar recursos e comportamento compativeis; justificar cada alteracao.

O Windows usa propriedades privadas e os scripts do harness. DES usa o mecanismo
existente da esteira para resolver os mesmos tokens. O XML renderizado nao deve
ser versionado. O nome/caminho de boot pode depender da imagem; isso nao autoriza
manter uma segunda copia do template com conteudo funcional diferente.

| Elemento | Regra de alinhamento |
| --- | --- |
| Template, nomes de recursos, JNDI, loggers e contratos | Mesma revisao nos dois ambientes |
| Endpoints, credenciais, tamanhos de pool, caminhos e portas | Valores por ambiente, com origem identificada |
| Modulos/JARs | Mesmos contratos e versoes aprovadas; origem Maven/local nao altera o binario esperado |
| JVM | Windows usa `standalone.conf.bat`; imagem usa seu launcher/variaveis Linux; comparar opcoes efetivas |
| Certificados, fontes e agentes | Provisionamento proprio de cada plataforma, com diferencas justificadas |
| Log SQL local | Opcao sobre o XML gerado; nao criar outro template nem ativar TRACE em DES por heranca |

Para cada diferenca frente a DES 7.1, registrar: fonte, comportamento anterior,
necessidade da mudanca, efeito no local, efeito em DES e verificacao. Um default
novo do EAP nao e, sozinho, justificativa para descartar um valor explicito antigo.
Igualdade do template tambem nao comprova igualdade da configuracao em execucao.
Comparar tambem expressoes `${...}`, atributos literais, recursos removidos e
defaults omitidos; contar apenas tokens `__...__` nao demonstra equivalencia.

## 2. Identificar a origem antes de modificar o repositorio de configuracao

1. Obter branch/commit de configuracao realmente usado pelo DES 7.1, versao/hash
   do artefato e referencia da imagem. Uma copia em inventario e evidencia do
   conteudo coletado, nao prova de qual revisao esta implantada.
2. Separar arquivos do repositorio de configuracao, arquivos da aplicacao,
   scripts da esteira e recursos da imagem. Nomes iguais em repositorios
   diferentes nao significam que a esteira consuma ambos da mesma forma.
3. Conferir ordem de download, renderizacao, copia, CLI offline, boot e deploy.
   Registrar quem produz cada arquivo e qual etapa pode modifica-lo depois.
4. Preparar a linha 7.4 a partir da referencia confirmada, preservando o 7.1
   e os caminhos do repositorio. O procedimento Git esta no
   [guia operacional, secao 3](../guia-operacional-jboss-eap-7.4-windows-des.md).

O roteiro nao pressupoe acesso administrativo ao servidor antigo. Usar o
material fornecido, o repositorio, a esteira e evidencias dos responsaveis.

## 3. Fechar o contrato da imagem

Registrar antes da primeira construcao utilizavel:

| Item | Evidencia necessaria |
| --- | --- |
| Runtime | Receita/imagem base, digest, EAP/update real, fornecedor/atualizacao do JDK 8 |
| Entrada | Launcher/entrypoint, XML selecionado, destino dos arquivos do repositorio |
| Renderizacao | Origem dos valores, escape XML, tokens ausentes, ordem das substituicoes |
| JVM | Precedencia entre arquivo, `JAVA_OPTS` e outras variaveis; limites de memoria e fuso |
| Extensoes | Modulos, dependencias, agentes, certificados, fontes e permissoes Linux |
| Operacao | Deploy, Service/Route/TLS, probes, replicas, volumes, timers e consumidores |

Para imagens que seguem o contrato oficial EAP/OpenShift, a Red Hat documenta
`standalone-openshift.xml`, scripts de inicializacao e personalizacao em
`configuration/`. Conferir a receita efetiva antes de aplicar essas convencoes
a uma imagem corporativa. Fonte: [referencia de imagens EAP 7.4](https://docs.redhat.com/en/documentation/red_hat_jboss_enterprise_application_platform/7.4/html/getting_started_with_jboss_eap_for_openshift_container_platform/reference_information).

Nesse contrato, a documentacao distingue `JAVA_OPTS_APPEND` de `JAVA_OPTS`:
sobrescrever este ultimo pode suprimir defaults. Isso exige inspecionar o launcher
e a JVM efetiva; nao basta copiar um `standalone.conf` Linux.
Fonte: [variaveis JVM EAP/OpenShift](https://docs.redhat.com/en/documentation/red_hat_jboss_enterprise_application_platform/7.4/html-single/getting_started_with_jboss_eap_for_openshift_online/getting_started_with_jboss_eap_for_openshift_online).

A documentacao citada descreve OpenShift; nao comprova suporte formal da
combinacao concreta de OKD, imagem, JDK e update. Registrar essa verificacao.

## 4. Preparar e revisar os candidatos

1. Revisar o template 7.4 contra DES 7.1. Conservar tokens e recursos compativeis;
   separar adaptacoes do modelo 7.4 de remocoes opcionais. Nao converter XML
   apenas trocando namespaces. Consulte o [guia de migracao](../../guias/tools/migracao-configuracao-jboss.md).
2. Revisar scripts CLI e manifestos nos repositorios que realmente os possuem.
   Modulos preexistentes divergentes/incompletos devem interromper o preparo,
   preservando evidencia. Nao assumir que o guard do script Windows protege
   automaticamente scripts da esteira.
3. Definir opcoes JVM, fontes, truststores e agentes para a imagem real. Caminhos
   fixos para JARs de logging precisam ser revistos a cada update; existencia no
   Windows nao comprova o caminho nem a necessidade no container.
4. Preencher valores de DES no mecanismo autorizado. O arquivo de valores local
   nao e a fonte de segredos do container. Registrar nomes/origens, nunca valores,
   nos documentos compartilhados.
5. Alinhar o local com a mesma revisao do template. A configuracao `template` do
   `preparo.json` pode apontar ao arquivo no checkout do repositorio de configuracao.
   Para aplicar qualquer ajuste local, parar o servidor e seguir o [roteiro](README.md).

Troca de update em DES deve resultar em nova imagem pela esteira e nova
validacao. Nao usar um patch aplicado manualmente ao pod como entrega reproduzivel.
O procedimento ZIP/installer local esta em [patches](patches.md); a receita da
imagem precisa definir sua propria forma aprovada de incorporar o update.

## 5. Construir, ensaiar e comparar

1. Construir um candidato identificado pelo commit, digest e artefato. Preparar
   o filesystem da imagem antes de iniciar o servidor, sem alterar pods ativos.
2. Validar XML final sem tokens pendentes, modulos completos, JVM e permissoes.
   Configuracao gerada por entrypoint/CLI deve ser comparada com a renderizacao
   do mesmo template. Diferenca funcional inesperada reprova o alinhamento.
3. Implantar no destino 7.4 separado do 7.1. Definir identidades e persistencia
   proprias; controlar jobs/consumidores e efeitos no banco durante coexistencia.
4. Conferir boot, datasource, SSO, integrações, mail/JMS usados, relatorios/fontes,
   proxy/TLS/Route, probes, logs, memoria, fuso e reinicio. Usar o mesmo artefato
   da comparacao local, registrando diferencas de plataforma.
5. Registrar resultado e reversao por imagem/configuracao/artefato; efeitos em
   dados e mensagens exigem tratamento separado. Submeter a revisao e aceite.

## 6. Repetir para outra aplicacao

Manter uma pasta privada por aplicacao, com origem, auditoria, roteiro, pendencias
e evidencias proprias. Reutilizar este procedimento e os scripts genericos;
nao herdar datasource, driver, SSO, tokens, agente ou decisoes da primeira aplicacao.
Se varias aplicacoes compartilharem uma imagem/servidor, conferir o contrato
conjunto antes de remover um recurso usado por qualquer participante.
