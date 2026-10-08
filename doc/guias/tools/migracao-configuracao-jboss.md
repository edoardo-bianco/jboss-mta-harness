---
html:
  embed_local_images: true
  embed_svg: true
  offline: true
---

# Migracao da configuracao JBoss para EAP 7.4

[Voltar ao guia do desenvolvedor](../harness-migracao-desenvolvedor.md#1-preparar-o-ambiente).
Para operar uma instalacao pronta, use o [guia JBoss](jboss.md).

Este guia prepara a migracao da **configuracao do servidor**: XML ativo, modulos,
drivers, seguranca, mensageria e recursos externos. As corretivas da aplicacao
seguem seu proprio plano, com Java 8 e `javax.*`. A atividade de servidor sera
planejada para a proxima sprint; este roteiro nao executa a migracao.

A automacao de inventario/transformacao ainda e proposta **JBS-01 a JBS-05** no
[catalogo de configuracao JBoss](../../features/evolucao-harness-dominios-capacidades-priorizacao.md#9-domínio-migração-da-configuração-jboss-eap).
Hoje o desenvolvedor pode usar a ferramenta oficial com orientacao do helper,
apos conferir o caminho aplicavel. Nao existe uma Run Task de migracao automatica.

## Orientacao com o helper

No Codex, ative `$orientar-migracao`; no Copilot, selecione `migracao_helper`.
O [guia de orientacao](../orientacao-migracao.md) explica a entrada nos clientes.

```text
Quero preparar a migracao da configuracao do JBoss para EAP 7.4 na proxima sprint.
Leia doc/guias/tools/migracao-configuracao-jboss.md e me guie uma etapa por vez.
Origem: [versao/patch e caminho]. Destino: [versao/patch e caminho].
Modo: [standalone ou domain]. Ja tenho: [inventario, XML ativo ou relatorios].
Indique a fonte Red Hat, o proximo passo e a evidencia esperada.
```

O helper aproveita os caminhos e evidencias informados, aponta o que falta e
orienta a acao a ser executada pelo desenvolvedor. Nao instala, transforma XML,
aciona a ferramenta nem concede aceite. Nao e necessario possuir MTA para iniciar
o inventario do servidor; remova credenciais dos arquivos/trechos compartilhados.

## Inventario e escolha da ferramenta

Registre versoes/patches, JDK, metodo de instalacao, standalone/domain, XML
realmente usado, parametros de inicializacao, modulos/drivers, datasources,
seguranca/SSO, mensageria, certificados, portas e caminhos externos. Inclua
ajustes de `standalone.conf.bat` ou equivalente. O XML sozinho nao comprova o
inventario completo. O helper deve distinguir recurso encontrado de recurso
efetivamente necessario a aplicacao.

A ferramenta oficial e o **JBoss Server Migration Tool**, distribuido com o EAP
de destino. A Red Hat recomenda a versao incluida no produto para migrar a EAP
7.4: veja a [introducao oficial](https://docs.redhat.com/en/documentation/red_hat_jboss_enterprise_application_platform/7.4/html/using_the_jboss_server_migration_tool/migration_introduction).
Confira a distribuicao/patch homologado pela equipe e o launcher existente em
`<EAP74_HOME>/bin`; nao substitua automaticamente pelo projeto comunitario.

**Conferencia especifica para 7.1 → 7.4:** o catalogo registra divergencia entre
a cobertura geral do Migration Guide e a lista 6.4/7.3 do guia especifico da
ferramenta. Confirme a aplicabilidade ao par exato na documentacao da distribuicao
ou com o suporte Red Hat antes de executar; nao presuma salto direto suportado
nem invente uma sequencia intermediaria. Registre a referencia e a versao da
ferramenta escolhida. O helper deve deixar essa verificacao pendente enquanto
nao houver evidencia suficiente.

## Ensaio, verificacao e retorno

1. Defina recorte e recuperacao por recurso. Preserve a origem e prepare destino
   limpo/atualizado conforme os [pre-requisitos oficiais](https://docs.redhat.com/en/documentation/red_hat_jboss_enterprise_application_platform/7.4/html/using_the_jboss_server_migration_tool/server_migration_tool_server_prerequisites).
   Registre onde estao as copias necessarias e as evidencias do ensaio.
2. Com origem/destino parados e o caminho de migracao confirmado, siga a
   [execucao oficial](https://docs.redhat.com/en/documentation/red_hat_jboss_enterprise_application_platform/7.4/html/using_the_jboss_server_migration_tool/running_the_server_migration_tool).
   Escolha as configuracoes do recorte em modo interativo. O helper deve adaptar
   o comando ao launcher, sistema operacional e caminhos realmente instalados,
   explicando que o destino sera modificado; nao executar em ambiente ativo.
3. Guarde logs/relatorios e compare configuracoes, modulos e recursos. Para cada
   componente, registre origem, equivalente no destino, acao, dependencia externa,
   referencia e evidencia. Remocoes e pendencias precisam ficar visiveis.
4. Valide inicializacao, conexoes, autenticacao, mensageria e fluxos da aplicacao.
   Use o [guia JBoss](jboss.md) para start/deploy/debug quando a instalacao estiver
   pronta. Sucesso da ferramenta nao comprova funcionamento de todos os recursos.
5. Submeta resultado, lacunas e recuperacao a revisao humana. Registre a evidencia
   no contexto da aplicacao e retorne a
   [verificacao e aceite](../harness-migracao-desenvolvedor.md#7-verificar-e-aceitar-o-resultado).

O rollback de deploy do harness restaura artefatos/releases, sem restaurar XML,
modulos, drivers ou dados do servidor. Migracao de dados persistidos exige
tratamento proprio. No harness, backups temporarios indispensaveis seguem
[AGENTS.md](../../../AGENTS.md); evidencias oficiais nao ficam nessa area de limpeza.
