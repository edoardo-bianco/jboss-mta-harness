---
html:
  embed_local_images: true
  embed_svg: true
  offline: true
---

# Build da aplicacao: Run Task e Maven

[Voltar ao fluxo principal](../harness-migracao-desenvolvedor.md#roteiro-onde-estou-e-o-que-escolho).

<a id="maven-configuracao-e-uso"></a>O build da aplicacao pode ser executado por
**dois caminhos, ambos usando Maven**:

| Caminho | Como iniciar | Configuracao e resultado |
| --- | --- | --- |
| **A. Run Task do harness — recomendado para este fluxo** | **Terminal > Run Task > Aplicacao: build Maven (Java 8)** | Usa Java/Maven do JSON local, oferece selecao de projeto e grava log/recibo do harness. |
| **B. Maven direto** | Painel **MAVEN** do VS Code ou comando `mvn` no terminal da aplicacao. | Usa o ambiente da extensao/terminal; confira Java 8 e Maven. Nao gera o recibo de build do harness. |

Escolha um dos caminhos para cada build. A extensao Maven e opcional para usar
a Run Task. Este guia cobre o build antes da analise na
[etapa 2](../harness-migracao-desenvolvedor.md#2-escolher-o-projeto-e-fazer-o-build)
e nas verificacoes da [etapa 7](../harness-migracao-desenvolvedor.md#7-verificar-e-aceitar-o-resultado).
Os comandos das tarefas partem da raiz do harness; o executor atua no projeto
selecionado. Para criar o workspace ou adicionar projetos, use o
[guia do workspace](workspace.md).

Navegacao: [configuracao](#configuracao) · [A: Run Task](#opcao-a-run-task-do-harness) ·
[B: Maven direto](#opcao-b-maven-direto) · [continuar](#resultado-e-proximo-passo).

## Configuracao

Preencha `tools.applicationJdk8Home`, `tools.applicationMavenHome` e, se necessario,
`tools.applicationMavenSettingsPath`. Os campos `mavenHome`/`mavenSettingsPath` continuam
exclusivos do MTA. Para usar a mesma versao por enquanto, informe o mesmo caminho nos
dois campos Maven; nao e preciso duplicar a instalacao. JSON antigo continua funcionando
na leitura da configuracao MTA; para seguir o fluxo completo, preencha tambem os campos do build.

O [JSON comum](workspace.md#configuracao-da-maquina) e as
[opcoes de sincronizacao da IDE](workspace.md#duas-opcoes-para-configurar-o-workspace)
ficam no guia do workspace. Mantenha os settings Maven padrao da maquina, salvo
necessidade corporativa explicita.

## Uso

### Opcao A: Run Task do harness

<a id="build-maven-da-aplicacao-com-java-8"></a>**Conclua o build do alvo antes de executar MTA.** Escolha o mesmo projeto do workspace nas duas tarefas. Se escolher um POM agregador, o build inclui seu reactor. Para analisar apenas um modulo, adicione a pasta desse modulo ao workspace e selecione-o; pais e dependencias de outros modulos devem estar disponiveis no repositorio Maven. Quando necessario, execute primeiro `clean install` no agregador para disponibiliza-los, depois construa e analise o modulo escolhido.

1. No VS Code, abra **Terminal > Run Task** e escolha **Aplicacao: build Maven (Java 8)**, da pasta `harness`.
2. Confirme o arquivo de workspace em uso, normalmente `jboss-mta-harness.local.code-workspace`.
3. Na lista de fases Maven, escolha **clean install** para preparar a analise MTA.
4. No terminal que abrir, escolha o numero do projeto/modulo e confira o caminho exibido.
5. Aguarde **Status: SUCCEEDED** e **ExitCode: 0**. Confira os testes executados e os caminhos de `console.log`/`result.json`.

A tarefa tambem
oferece `clean verify`, `clean package`, `test`, `package`, `verify`, `install` e `clean`
para outras operacoes; `clean` sozinho nao atende a etapa de build anterior ao MTA.
A tarefa mostra projeto, caminhos, versoes e log. Para chamar **essa mesma
operacao do harness pelo terminal**, opcionalmente use o comando abaixo a partir
da raiz do harness. Ele tem as mesmas selecoes e registros da Run Task:

```powershell
powershell.exe -NoProfile -File .\scripts\construir-aplicacao.ps1 -WorkspacePath .\jboss-mta-harness.local.code-workspace -SelectTarget -Goals "clean install"
```

O padrao da tarefa e do script sem `-Goals` continua sendo `clean verify`; para seguir a preparacao descrita neste guia, selecione ou informe `clean install`. `clean` remove as saidas conforme o POM;
`install` percorre o ciclo ate instalar o artefato no repositorio Maven local.
Veja o [ciclo oficial do Maven](https://maven.apache.org/guides/introduction/introduction-to-the-lifecycle.html).
O harness passa `-Djacoco.haltOnFailure=false`: cobertura abaixo da meta de referencia
de 85% de linhas do recorte corrigido (classes/metodos identificados no report JaCoCo)
gera aviso, sem quebrar o build. Testes, instrumentacao e relatorios continuam
ativos; erros de compilacao e testes reprovados continuam retornando falha.
Report ausente ou recorte nao mensuravel fica pendente; cobertura total nao prova
o recorte. A cobertura global do Sonar segue politica separada de 85%.
Se o POM fixar `haltOnFailure=true` ou outro plugin impuser um gate, ajuste essa
configuracao no escopo aprovado do projeto; a task nao edita o POM nem mascara erros.
Ao configurar JaCoCo no POM, preserve os limites e use `haltOnFailure=false`,
conforme a [documentacao do JaCoCo check](https://www.jacoco.org/jacoco/trunk/doc/check-mojo.html).
Esta entrada aceita as fases acima (tambem `validate`/`compile`, com `clean` opcional),
sem linha de shell, flags avulsas ou goals arbitrarios de plugins. Perfis, plugins,
toolchains e `.mvn` existentes continuam sendo configuracao da aplicacao e precisam
estar revisados. Um toolchain ou compilador externo declarado no projeto pode selecionar
outro JDK: a conferencia do launcher nao certifica todo o bytecode produzido.

O executor usa `applicationJdk8Home` e `applicationMavenHome` somente no processo,
confere Java 8 e Maven 3 antes das fases e restaura o ambiente ao terminar. Opcoes
Java/Maven herdadas do terminal e scripts pessoais mavenrc nao sao usados; configuracao
versionada `.mvn` e settings declarados permanecem aplicaveis. O build ocorre na raiz
do projeto ativo, incluindo seu reactor. Nao execute outra IDE/CLI escrevendo nesse
projeto; a tarefa compartilha o lock do MTA deste harness.

Log e recibo ficam em `.harness/builds/<nome>__<chave12>/build_<data-fuso>__<RunId12>/console.log` e `result.json`.
O nome usa a data/hora de inicio do recibo e o fuso local; o RunId completo permanece
no JSON. Builds anteriores continuam nos caminhos originais.
O codigo de falha do Maven e propagado. `SUCCEEDED` significa Maven exit 0 para as
fases escolhidas; `clean` sozinho, testes desabilitados no POM ou ausencia de testes
nao comprovam teste/cobertura. Esta tarefa nao produz manifesto Sonar nem homologa EAP.
Depois de trocar o Maven/settings da aplicacao no JSON do harness, siga a opcao A para
sincronizar a IDE; se preferir editar a IDE diretamente, siga a opcao B em
[Duas opcoes para configurar o workspace](workspace.md#duas-opcoes-para-configurar-o-workspace).
A tarefa de build le o JSON novamente em cada execucao.

### Opcao B: Maven direto

Este caminho executa o Maven pela extensao ou pelo terminal da aplicacao.
Use o mesmo projeto/POM que sera selecionado no MTA e conclua o build antes da
analise. A extensao e o comando `mvn` nao chamam o executor do harness nem geram
seu `result.json`; confira a saida do Maven e os relatorios no `target` do projeto.

#### Usar a extensao Maven padrao do VS Code

Abra `jboss-mta-harness.local.code-workspace`. O gerador configura o `JAVA_HOME` do
terminal Maven em `maven.terminal.customEnv`, a partir de `applicationJdk8Home`, e
`maven.terminal.useJavaHome: false`. Configura tambem `maven.settingsFile` com
`applicationMavenSettingsPath` e `maven.executable.path` com o Maven da aplicacao.
O Java do servico da IDE (`java.jdt.ls.java.home`) continua separado do Java do build.
Esses valores sao atualizados sempre que voce gera novamente o workspace.

Depois de alterar/gerar o workspace, feche os terminais Maven antigos ja encerrados
e abra um novo; nao interrompa uma execucao em andamento. No painel **MAVEN**, clique
com o botao direito no projeto desejado, escolha **Execute Commands...** e digite
`--version`, sem `mvn`. Confira Java 1.8 e o Maven configurado. Depois use a mesma
opcao com `-Djacoco.haltOnFailure=false clean install` e aguarde `BUILD SUCCESS` antes de executar MTA. A propriedade mantem o tratamento de cobertura usado pela Run Task. Confira que o POM selecionado corresponde ao projeto que voce escolhera na tarefa MTA. A extensao usa o POM selecionado
e nao passa pelo lock/recibo da tarefa do harness: execute uma operacao por vez.
Configuracoes particulares de pasta podem sobrescrever as do workspace.
Referencia: [configuracao da extensao Maven](https://github.com/microsoft/vscode-maven#additional-configurations).

#### Usar o terminal da aplicacao

Abra um terminal na **pasta do projeto que contem o `pom.xml`**. Confira
`mvn --version`: deve mostrar o Java 8 e o Maven pretendidos. A configuracao do
JSON do harness nao e aplicada automaticamente a um terminal comum.
Depois execute `mvn -Djacoco.haltOnFailure=false clean install` e aguarde
`BUILD SUCCESS`. A propriedade mantem o tratamento de cobertura usado pela
Run Task; falhas de compilacao/testes continuam sendo falhas.

## Resultado e proximo passo

Confira status, exit code, log e testes executados. Falha de compilacao ou teste
pede correcao antes de seguir. Depois de sucesso, avance para
[MTA na etapa 3](../harness-migracao-desenvolvedor.md#3-obter-ou-reutilizar-o-diagnostico-mta)
ou, se estiver validando uma corretiva, continue as
[verificacoes da etapa 7](../harness-migracao-desenvolvedor.md#7-verificar-e-aceitar-o-resultado).
Build bem-sucedido comprova as fases executadas; o aceite do lote e outra decisao.
