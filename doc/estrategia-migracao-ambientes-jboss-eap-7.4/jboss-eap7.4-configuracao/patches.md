# Atualizar EAP 7.4 para outro patch mantendo Java 8 e EE 8

Referencia conferida em 22/10/2026. `7.4.11.GA` e o estado local registrado;
nao e indicacao de patch mais recente. Este roteiro nao escolhe nem aplica um
novo patch automaticamente. Use o numero **XX** aprovado para o ambiente e
registre a versao, pacote, checksum oficial e evidencias da escolha.

## Escolher o candidato

EAP 7.4 implementa Jakarta EE 8. A troca de nome Java EE/Jakarta EE nesta
geracao nao exige trocar imports para `jakarta.*`; preservar as APIs `javax.*`
faz parte desta migracao. Nao confundir com a transicao de namespaces EE 9+.
Fontes: [padroes suportados](https://access.redhat.com/articles/113373) e
[Migration Guide 7.4](https://docs.redhat.com/en/documentation/red_hat_jboss_enterprise_application_platform/7.4/pdf/migration_guide/Red_Hat_JBoss_Enterprise_Application_Platform-7.4-Migration_Guide-en-US.pdf).

Confira a combinacao **EAP/patch + fornecedor/versao do JDK 8 + sistema operacional**
na [matriz Red Hat](https://access.redhat.com/articles/2026253), incluindo suas
notas. Nao escolha Java 11/17 apenas porque um patch tambem os suporta. A matriz
lista Java 8 para combinacoes especificas; Adoptium aparece com 11/17, nao 8,
nas linhas EAP 7.4 consultadas. O Temurin 8 usado no ensaio local tem, portanto,
uma lacuna de comprovacao de suporte formal; boot funcional nao resolve essa
pendencia nem comprova cobertura de qualquer Windows de desenvolvimento.

Leia as release notes/errata do **XX** escolhido: problemas conhecidos, mudancas
de configuracao, drivers, seguranca e correcoes individuais. Registre tambem a
versao Hibernate fornecida e confirme a restricao Hibernate 5.3 quando aplicavel.
Nao substitua bibliotecas do produto por versoes comunitarias para ajustar o patch.

A manutencao regular de EAP 7 terminou em 30/06/2025; patches ELS publicados desde
novembro/2025 exigem conta com add-on ELS ativo. A pagina de downloads ELS e
separada. A antiga orientacao local de ignorar ELS valia para obter o CP11;
nao deve excluir automaticamente um candidato atual.
Fonte: [como obter patches EAP 7.4 ELS](https://access.redhat.com/solutions/7134413).

## Aplicar em instalacao ZIP/installer Windows

O mecanismo abaixo e para ZIP/installer. RPM segue outro procedimento; uma
imagem/container deve ser reconstruida pelo processo da equipe. Patches sao
cumulativos, dispensando intermediarios. Antes de aplicar ou reverter, guarde
backup completo da instalacao, configuracoes e deployments. Preserve o historico
de patch e seus overlays: `ageout-history` reduz possibilidades de rollback.
Fonte: [Patching and Upgrading Guide 7.4](https://docs.redhat.com/en/documentation/red_hat_jboss_enterprise_application_platform/7.4/html/patching_and_upgrading_guide/assembly-patching-jboss-eap_default).

1. Obtenha o ZIP oficial do XX pelo portal, confira checksum/procedencia e anote
   URL/errata. Nao descompacte o patch dentro do servidor.
2. Pare o alvo e confirme que o `EAP_HOME` e o da instalacao pretendida. Guarde
   o backup fora dessa instalacao, com acesso adequado aos dados reais.
3. Abra a CLI **dessa instalacao**, sem conectar a outro servidor. O exemplo
   oficial Windows de aplicacao offline esta nas
   [notas do CP12](https://access.redhat.com/articles/6999118); CP12 e apenas
   exemplo da sintaxe, nao uma recomendacao de destino.

```powershell
$eapDestino = 'C:\servidores\jboss-eap-7.4'
$env:JAVA_HOME = 'C:\java\jdk8'
& "$eapDestino\bin\jboss-cli.bat"
```

Na CLI interativa, registre o antes e aplique o arquivo escolhido (substituir XX
e o caminho; coloque o caminho entre aspas se contiver espacos):

```text
patch info
patch history
patch apply C:\pacotes\jboss-eap-7.4.XX-patch.zip
patch info
patch history
quit
```

Confira `outcome`, versao resultante e ID cumulativo. Em conflito, interrompa
e compare os arquivos; nao use override global por conveniencia. O procedimento
oficial de patch e a verificacao por `patch info` estao no
[guia Red Hat](https://docs.redhat.com/en/documentation/red_hat_jboss_enterprise_application_platform/7.4/html/patching_and_upgrading_guide/assembly-patching-jboss-eap_default).

## Revalidar o ambiente preparado

Somente apos confirmar o patch, atualize `expectedVersion` no `preparo.json`.
Compare template e arquivo JVM com a nova distribuicao; reveja referencias
absolutas a JARs/overlays e agentes. Preserve as entradas reais, gere outro
consolidado, confira e aplique com o alvo parado conforme o [roteiro](README.md).

Registre evidencias: `patch info/history` antes/depois, JDK efetivo, boot com XML
selecionado, datasources/driver efetivo, seguranca, mensageria, fontes/relatorios,
integracoes e fluxos da aplicacao. Compare com o baseline CP11. Atualize o
manifesto do ambiente com fatos observados, sem marcar pendencias como resolvidas
apenas porque o patch instalou. Esses criterios sao do nosso preparo/migracao.

## Reverter se o candidato falhar

Consulte `patch history` e escolha o ID exato. Na CLI:

```text
patch rollback --patch-id=ID_DO_PATCH --reset-configuration=true
```

`true` restaura configuracoes anteriores ao patch e perde alteracoes posteriores;
`false` conserva essas alteracoes e pode exigir correcao manual para iniciar.
Escolha conscientemente, com backup; nao trate rollback como desinstalador geral.
Depois confira `patch info`, alinhe `expectedVersion` e repita as verificacoes.
Fonte: [rollback oficial](https://docs.redhat.com/en/documentation/red_hat_jboss_enterprise_application_platform/7.4/html/patching_and_upgrading_guide/assembly-patching-jboss-eap_default).
