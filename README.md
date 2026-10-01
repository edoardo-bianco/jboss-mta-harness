# JBoss MTA Harness

Build Maven Java 8, analise MTA, SonarQube e migracao assistida por Copilot/DevSquad.
Destino: EAP 7.4, preservando Java 8 e `javax.*`. O
[guia do desenvolvedor](doc/guias/harness-migracao-desenvolvedor.md) concentra as instrucoes.

## Comecar

1. Abra `iniciar-harness.code-workspace` no VS Code.
2. Em **Terminal > Run Task**, pasta **harness**, execute **Workspace: configurar caminhos**.
   Preencha JDK 8/Maven da aplicacao e distribuicao completa MTA/JDK compativel.
   O ensaio usa MTA 8.2.1/JDK 25. Settings opcionais ficam `null`, usando os padroes da maquina.
3. Execute **Workspace: gerar workspace** e abra `jboss-mta-harness.local.code-workspace`.
4. Use **MTA: conferir ambiente**; escolha `migracao-cache-antes` para o primeiro ensaio.

Para projetos corporativos, use **File > Add Folder to Workspace** e salve.
A primeira tarefa reconhece o projeto e cria seu registro local. Nao precisa gerar
workspace novamente a cada uso. Copilot deve estar autenticado em sessao Local,
com DevSquad disponivel; o harness nao instala ferramentas.

## Fluxo de trabalho

| Etapa | Tarefa/acao |
| --- | --- |
| Construir | **Aplicacao: build Maven (Java 8)**, `clean install`; conferir sucesso. |
| Analisar | **MTA: executar analise**, depois **MTA: abrir ultimo relatorio**. |
| Preparar planejamento | **Planejamento: preparar contexto para Copilot > 1. Planejar ou atualizar lote**; escolher MTA e plano anterior, se houver. O harness atualiza o catalogo no `migracao.md` quando disponivel no MTA e prepara o prompt. |
| Escolher issues | No `migracao.md`, marcar ANALISAR AGORA nas issues desejadas e salvar. Nao precisa preparar outro contexto por essa edicao. |
| Gerar proposta | O prompt ja direciona as issues ANALISAR AGORA; edite o objetivo somente se necessario. Use **Executar Prompt** no Copilot e confira `plan.md` e `todo.md`. |
| Implementar | Dar GO no plano, usar **Aplicacao: preparar implementacao do lote** e executar o prompt. Rever resultados e dar aceite separadamente. |

`migracao.md` fica em `.harness/projetos/<nome>__<chave>/`, com
`evidencias/LEIA-ME.md`. Selecione ANALISAR AGORA, ADIAR ou FORA DO ESCOPO;
andamento e cobertura ficam separados. A opcao **2. Atualizar somente migracao.md**
e opcional: com MTA selecionado, atualiza o catalogo disponivel; com ou sem novo MTA,
prepara ajuda do Copilot para reconciliar o registro, sem plan/todo. Nao precisa
executar esse prompt para apenas carregar o catalogo. Para retomadas e outros caminhos,
consulte [qual fluxo seguir](doc/guias/harness-migracao-desenvolvedor.md#qual-caminho-seguir).
Java 8/javax e as decisoes Hibernate permanecem no
[contrato existente](doc/especificacoes/planejamento-copilot.md).

**Ja tem MTA?** Comece em Preparar planejamento; reutilize pelo historico ou informe a pasta completa com **p**.
Pode copiar/renomear uma rodada antiga para `C:/mta-runs/<projeto>/AAMMDD-HHMMSS`,
sem editar seus arquivos. Isso nao a cadastra como ultimo relatorio.
Veja [reconstrucao do registro](doc/guias/harness-migracao-desenvolvedor.md#reconstruir-a-pasta-usando-um-mta-existente):
o MTA recupera issues/contagens; status anteriores exigem registro ou evidencias.

Sonar e novo MTA sao checklist nao bloqueante. Cobertura abaixo de 85% gera aviso;
falhas de compilacao/testes continuam falhas. GO nao concede aceite do resultado.
Configuracao, workspace gerado e `.harness/` sao locais e nao acompanham clone/pull.

Para detalhes: [configuracao](doc/guias/harness-migracao-desenvolvedor.md#configuracao-da-maquina),
[GO/aceite](doc/guias/harness-migracao-desenvolvedor.md#da-proposta-revisada-a-execucao-e-ao-aceite),
[Sonar](doc/guias/harness-migracao-desenvolvedor.md#sonarqube-local-ou-corporativo).
Para evoluir o harness: [AGENTS.md](AGENTS.md), [ADRs](doc/adr/) e [tarefas](tasks/todo.md).
