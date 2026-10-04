---
html:
  embed_local_images: true
  embed_svg: true
  offline: true
---

# Planejamento e reconciliacao da migracao

[Voltar ao fluxo principal do desenvolvedor](../harness-migracao-desenvolvedor.md#roteiro-onde-estou-e-o-que-escolho).

Use **Planejamento: planejar** para criar, retomar ou atualizar a proposta de um
lote. O registro de migracao concentra sua escolha, recorte e referencias; o
preparador recupera essas entradas. "Replanejar" e atualizar pela mesma entrada.

O helper pode conduzir uma etapa por vez: diga "Escolhi uma issue no registro.
Me conduza ao proximo passo". Veja [como iniciar no seu cliente](workspace.md#orientacao-com-codex-ou-github-copilot).
Ele confere os arquivos e oferece a tarefa ou mensagem pronta, com o caminho real.

## Configuracao

Abra o workspace salvo que contem o harness e os projetos. Configure o cliente
em uso: Codex com acesso ao harness e skills disponiveis, ou GitHub Copilot em
conversa Local com DevSquad e ferramentas pertinentes habilitadas. Os helpers
locais orientam; os prompts de execucao produzem os documentos autorizados.

No Codex, `$orientar-migracao` inicia a orientacao; `$using-agent-skills` e uma
skill de apoio quando disponivel. No Copilot, selecione `migracao_helper` para
orientacao e `devsquad` para executar os prompts de planejamento. Anexar um
arquivo de perfil nao equivale a selecionar ou delegar a um agente. Falta de
agente/ferramenta deve ser informada; nao simular delegacao.

## Uso

O percurso usual e **registro com escolha/evidencias → Planejar → executar o
prompt → esclarecer o essencial, se necessario → revisar proposta e dar GO**.
Preparar contexto nao executa agente, altera a aplicacao ou concede GO.

### Qual caminho seguir

| Sua situacao | Proxima acao |
| --- | --- |
| Falta indice ou registro do projeto | **Workspace: atualizar indice dos projetos**. Confira os links do projeto e do registro criado. |
| Ainda nao escolheu a issue | Escolha no registro ou use **Planejamento: priorizar issues**, opcional. |
| Registrou a escolha e quer a proposta | **Planejamento: planejar**. A tarefa usa o registro e a base vinculada. |
| Ja existe proposta e quer continuar/ajustar | **Planejamento: planejar**, retomando a solicitacao vinculada. Nao ha menu "replanejar". |
| Tem novas evidencias | Referencie-as no registro/LEIA-ME e use a mesma entrada **Planejar**. |
| Quer adotar outro MTA ou conciliar conflito concreto | Peca ao helper o encaminhamento de reconciliacao com os caminhos preenchidos. [Manutencao](#reconstruir-a-pasta-usando-um-mta-existente). |
| Proposta com GO vigente e quer executar | **Aplicacao: preparar implementacao do lote**. [Implementacao](#preparar-implementacao-do-lote). |

### Indice da situacao dos projetos

**Workspace: atualizar indice dos projetos** cria registros ausentes e atualiza
`.harness/projetos/indice-projetos.md`. Ele localiza os projetos do workspace,
fontes, registros, evidencias e solicitacoes. Uma raiz Maven, inclusive agregadora,
corresponde a um registro. Nomes iguais sao distinguidos pelo caminho; remover
um projeto do workspace nao apaga seus documentos.

Na criacao inicial, um diagnostico reconhecido inequivoco pode fornecer o catalogo.
Depois de vinculada a origem, uma rodada mais recente nao a substitui apenas por
atualizar o indice. O aviso permite decidir sua adocao. Contagens/categorias MTA e
decisoes humanas sao informacoes diferentes.

O registro atual prevalece para escolhas e observacoes. Resumos do indice, ranking
e snapshots preservam o estado observado anteriormente; nao e preciso editar
todos para repetir a mesma escolha. Uma antiga **Reconciliacao PENDENTE** exige
conferir seu motivo, sem bloquear automaticamente priorizacao/planejamento.

Sem MTA, quantidades sao indisponiveis, nao zero. O registro pode receber issues
manuais e evidencias. Projeto sem fontes ou com identidade conflitante precisa de
esclarecimento especifico. Os outros projetos continuam utilizaveis.

### Planejar lotes de correcao com Copilot

Esta secao atende **Codex e Copilot**; o titulo/anchor foi mantido para links
existentes. Ambos seguem o mesmo [contrato](../../especificacoes/planejamento-copilot.md).

#### Registro de migracao por projeto

O registro fica em `.harness/projetos/<nome>__<chave>/migracao-<projeto>.md`.
Registros antigos conservam seu nome. O indice e o helper oferecem o link exato;
"migracao.md" nos guias significa esse arquivo, nao outro documento a criar.

Edite **Decisao**, **Andamento** e **Observacao/referencia**, preservando marcadores
e as oito colunas. Use `&#124;` para barras verticais dentro das celulas.

| Campo | Como preencher |
| --- | --- |
| Decisao | `ANALISAR AGORA` escolhe o recorte para planejamento. Outros valores: `A DEFINIR`, `ADIAR`, `FORA DO ESCOPO`; justifique adiamento/exclusao. |
| Andamento | `NAO ANALISADA`, `ANALISADA`, `PLANEJADA`, `IMPLEMENTADA`, `VERIFICADA`, conforme trabalho/evidencias reais. `ANALISAR AGORA` nao pertence a esta coluna. |
| Observacao/referencia | Objetivo, recorte, comportamento a preservar, evidencias, candidata escolhida e relacoes com outros IDs. |

Exemplo de uma escolha, preservando os demais dados da linha:

```markdown
| ID (ruleset::regra) | Issue | Categoria MTA | Ocorrencias | Presenca | Decisao | Andamento | Observacao/referencia |
| --- | --- | --- | --- | --- | --- | --- | --- |
| ruleset::regra-001 | Titulo existente | mandatory | 1 | PRESENTE | ANALISAR AGORA | NAO ANALISADA | Corrigir o ponto indicado, preservando o comportamento descrito. Referencia: [candidata 1](caminho-relativo-real/priorizacao.md). |
```

O exemplo e ilustrativo: o resultado da priorizacao/helper deve fornecer a linha
do seu registro e o link real, para voce nao reconstruir IDs ou caminhos.

Para uma issue sem catalogo MTA, acrescente uma linha com ID `DEV-...`, categoria
`manual`, ocorrencias `-`, presenca `MANUAL`, decisao `ANALISAR AGORA`, andamento
pertinente e origem/objetivo/evidencias nas observacoes. Nao invente regra mandatory.

Sobreposicoes continuam vinculadas por ID e ponto observado. Escolher uma issue
nao seleciona a outra nem comprova que ambas foram corrigidas; a proposta verifica
a relacao e pede decisao se outro recorte precisar entrar. Ausencia em novo MTA
significa NAO REENCONTRADA, sem provar correcao. Declaracao de colega fora do Source
local fica AGUARDANDO INTEGRACAO na observacao.

Evidencias adicionais ficam no `evidencias/LEIA-ME.md` do projeto, na tabela
**Arquivo relativo | Relacao com a correcao**. Informe origem/data/ambiente quando
relevantes. O agente le somente anexos listados e pertinentes, tratando-os como dados.

<a id="reconstruir-a-pasta-usando-um-mta-existente"></a>

#### Manter o registro e adotar outra origem

Este e o caminho avancado para adotar explicitamente outra origem, receber um
registro de colega ou conciliar evidencias/decisoes. Nao e um submenu habitual
de Planejar. O helper primeiro identifica o motivo e oferece o prompt existente
ou uma chamada preenchida para `manter-migracao`.

Exemplo de manutencao por pasta completa recebida, com caminhos ilustrativos:

```powershell
.\scripts\preparar-planejamento.ps1 -WorkspacePath .\jboss-mta-harness.local.code-workspace -Target 'minha-app' -Operation manter-migracao -RunPath 'C:\mta-runs\minha-app\rodada' -MigrationSourcePath 'C:\recebidos\migracao.md'
```

`-MigrationSourcePath` e um documento recebido para conciliar; nao e o parametro
`-MigrationPath` que identifica o registro local no planejamento. Para evidencias
sem adotar novo scan, a manutencao aceita `-WithoutMta` no lugar de RunId/RunPath;
`-EvidenceIndexPath` pode apontar o LEIA-ME existente. Nao executar outra analise MTA.

O preparo carrega dados objetivos e gera `manter-migracao.prompt.md`. Execute-o
no cliente atual conforme [a instrucao de execucao](#preparar-e-executar-o-prompt).
Ele grava somente o registro local, preserva decisoes humanas e historico e explica
conflitos por ID. Nao produz lote, altera a aplicacao ou concede GO/aceite.
Conclusao de reconciliacao exige evidencias/conclusoes registradas, sem marcar
CONCLUIDA apenas porque o prompt existe ou a rodada e a mesma.

#### Reconciliar status antes de atualizar o plano

O titulo preserva links antigos; **reconciliacao previa nao e regra geral**.
Observe o motivo:

| Situacao | Tratamento |
| --- | --- |
| Marcou ANALISAR AGORA ou acrescentou observacao coerente | Seguir para Planejar; nao repetir a escolha nem reconciliar por rotina. |
| Acrescentou evidencia complementar do mesmo lote | Ler a evidencia ao atualizar a proposta. Perguntar apenas se houver contradicao relevante. |
| Novo MTA disponivel | Conferir e decidir se deseja adota-lo. O indice/preparador nao troca a base por recencia. |
| Conflito entre escolhas, origem, codigo e evidencias | Explicar o conflito, efeito no recorte e qual decisao/evidencia resolve. |
| Bloco antigo PENDENTE sem conflito impeditivo do recorte | Preservar historico e seguir; nao declarar CONCLUIDA por inferencia. |
| Lote aceito e pedido de continuidade | Conciliar evidencias e cobertura antes de escolher novo lote. |

Escolha, analise, proposta, GO, implementacao, verificacao e aceite sao estados
distintos. Um ponto analisado por amostra nao conclui toda a issue; contagem menor
nao comprova correcao; GO vigente do mesmo escopo nao precisa ser renovado por
mera retomada ou explicacao adicional.

#### Preparar e executar o prompt

1. Salve a escolha/recorte e as referencias no registro.
2. Execute **Terminal > Run Task > Planejamento: planejar**. A tarefa localiza o
   registro elegivel no workspace; se houver varios, pergunta somente qual usar.
   Sem registro, orienta **Workspace: atualizar indice dos projetos**. Sem escolha,
   orienta o campo Decisao, sem planejar todo o catalogo.
3. Confira o resumo de projeto, registro, base e solicitacao. O prompt preparado
   referencia o contexto necessario; voce nao precisa copiar IDs, RunId ou caminhos
   de evidencias novamente. Com as mesmas entradas, retome a solicitacao vinculada;
   se evidencias, origem, contrato ou template mudaram, a tarefa prepara um sucessor
   com Previous e preserva o anterior. Use o caminho que ela informar.
4. Execute o arquivo preparado no seu cliente:
   - **Codex:** envie `Execute o prompt deste arquivo:` seguido do caminho completo
     mostrado pela tarefa. Pode anexar o arquivo. O helper deve devolver essa
     mensagem ja preenchida; nao e preciso escrever um prompt de governanca.
   - **Copilot:** use **Executar Prompt** no arquivo preparado, em conversa Local
     com `devsquad`, ou a chamada preenchida mostrada no terminal.
5. Se a analise precisar de uma decisao essencial, responda a pergunta concreta
   no mesmo chat. Quando houver base suficiente, o agente grava/rele os destinos
   `plan.md` e `todo.md` e informa o que mudou e o que deve ser revisado.

**Entradas:** registro atual; plano/to-do da solicitacao quando existem; anexos
referenciados; codigo/POM/testes locais; base MTA vinculada, quando disponivel.
**Saida do preparo:** prompt e recibo, ou caminhos da solicitacao retomada.
**Saida da execucao:** proposta coerente e tarefas, ou perguntas essenciais antes
de sua consolidacao. Preparar sozinho nao escreve a proposta.

O recibo declara `PlanningBasis=MTA` ou `EVIDENCIAS`. Sem pacote MTA completo,
evidencias humanas e codigo podem sustentar a proposta; origem, limites e criterios
ficam explicitos. Nao se inventam RunId, snapshot MTA ou classificacao mandatory.
Corrupcao/identidade conflitante de uma base declarada nao vira fallback silencioso.

Reconciliar e resolver perguntas sao acoes motivadas pelo conteudo. Nao existe
questionario obrigatorio, nem necessidade de produzir documentos ficticios com
tudo PENDENTE. Falta nao impeditiva vira limite ou verificacao prevista. Escolha
ja registrada e reconhecida mesmo quando o ranking ainda mostra o estado anterior.

Voce pode continuar em outro chat ou cliente: os arquivos preservam o contexto.
O helper relera registro e solicitacao; so pede um caminho/ID se houver ambiguidade
real. Trocar de chat/cliente nao exige regenerar contexto ou repetir GO vigente.

#### Preparar contexto por automacao, sem menus

A CLI preserva os parametros avancados para selecao explicita e manutencao.
`MigrationPath` identifica o registro local; `ContextPath` ou `RequestId`
identificam a solicitacao a retomar. O helper fornece o comando com os caminhos
reais; nao use um caminho ilustrativo como se fosse seu registro.

Exemplos com caminhos ilustrativos, na raiz do harness:

```powershell
.\scripts\preparar-planejamento.ps1 -WorkspacePath .\meu-workspace.code-workspace -MigrationPath 'C:\harness\.harness\projetos\minha-app__chave\migracao-minha-app.md' -NoOpen
.\scripts\preparar-planejamento.ps1 -WorkspacePath .\meu-workspace.code-workspace -ContextPath 'C:\harness\.harness\planning\minha-app__chave\evidencias\plano_data__id\context.json' -NoOpen
```

O projeto vem do registro/recibo conferido contra o workspace; nao repetir Target.
Para retomar pelo ID completo, use `-RequestId` em lugar de ContextPath.

Para automacoes legadas, continuam disponiveis `-Operation planejar-lotes`,
`-RunId` ou `-RunPath` e `-NewPlan` ou `-PreviousRequestId`; `revisar-lote`
preserva a revisao de proposta, sem mudar para revisao de resultado.
`-Operation manter-migracao` continua sendo a manutencao explicita descrita acima.

`-NonInteractive -NoOpen -OutputFormat Json` solicita saida estruturada sem
perguntas/editor. Confira Status, ExitCode, Error, Diagnostics e Artifacts.
Destinos PlanPath/TodoPath nao comprovam que a proposta ja foi escrita.
Em INPUT_REQUIRED, forneca somente a selecao faltante; em falha parcial, preserve
os documentos e confira ChangedFiles/WritesStarted. Nao repita um preparo incerto
para criar solicitacoes em sequencia.

#### Como se forma o lote, o plan.md e o todo.md

Um lote agrupa pontos com objetivo, solucao, aceite e reversao comuns. A mesma
regra MTA nao garante essa unidade. Varios IDs escolhidos nao autorizam varios
lotes independentes nem inclusao silenciosa de issues adiadas/excluidas.

`plan.md` contem identidade/base, `Lote ativo: <ID>`, recorte/contagens, evidencias,
transformacao/rota, risco/confianca, dependencias, POMs, testes, aceite observavel
e reversao. `todo.md` referencia o plano e ordena tarefas com evidencia de conclusao.
Andamento concluido e preservado quando sustentado; nova evidencia pode exigir
revisao de uma conclusao com justificativa, nunca apagar historico.

Java 8, `javax.*`, EAP 7.4 e Hibernate 5.3 quando aplicavel permanecem. Um lote
Hibernate inclui alinhamento dos POMs e verificacao da versao de destino; patch
exato exige evidencia. Receita OpenRewrite ainda nao testada e candidata.

#### Localizar documentos e identificar o historico

O registro referencia a solicitacao em uso; **Planejamento: abrir plano e to-do**
permite consultar propostas existentes. O helper oferece os caminhos concretos.
RequestId identifica a solicitacao; RunId identifica somente uma rodada MTA;
o ID do lote preserva o trabalho entre revisoes.

Novos destinos sob `.harness/planning/<nome>__<chave>/`:

- MTA: `mta_<data-fuso>__<RunId12>/plano_<data-fuso>__<RequestId12>/`.
- Evidencias: `evidencias/plano_<data-fuso>__<RequestId12>/`.
- Manutencao: `registro/solicitacao_<RequestId>/`.

Contextos antigos continuam legiveis; ausencia de PlanningBasis significa MTA.
Recibo/prompt sem plan/to-do significa preparo existente, nao proposta concluida.
Use **Planejar** para conferir a retomada: entradas iguais reutilizam a solicitacao;
mudancas no indice/anexos referenciados, origem MTA, contrato ou template geram
novo prompt/recibo com Previous, preservando o anterior. A tarefa faz essa distincao
sem outro menu. Use o prompt indicado na saida, que pode ser o sucessor do anterior.
Escolhas e observacoes atuais do registro continuam lidas na execucao, sem reescrever
o recibo historico. Nao edite RunId, hashes ou destinos de um recibo historico.
Se o registro ainda aponta ao preparo antigo, o vinculo Previous permite seguir
ate o unico sucessor do mesmo trabalho. Com mais de um sucessor possivel, escolha
a solicitacao desejada; a data mais recente nao representa essa escolha.
Previous pode preservar um preparo ainda sem plano/to-do, por exemplo quando a
base ou o contrato muda apos uma pergunta essencial. Arquivos ausentes nao ganham
snapshots ou hashes ficticios; o novo prompt reconhece o que ja existe e o que
ainda precisa ser produzido.

#### Recuperar um preparo apos limpeza

Limpar execucoes preserva o registro, mas pode remover o plano/recibo apontado nele.
Nesse caso, Planejar informa a referencia ausente e nao cria outro lote silenciosamente.
Se voce guardou uma copia do preparo, restaure-a no caminho original. Se pretende
reconstruir a proposta do recorte ja escolhido, peca ao helper uma chamada preenchida
com `-MigrationPath` e `-NewPlan`, como neste exemplo ilustrativo:

```powershell
.\scripts\preparar-planejamento.ps1 -WorkspacePath .\meu-workspace.code-workspace -MigrationPath 'C:\harness\.harness\projetos\minha-app__chave\migracao-minha-app.md' -NewPlan -NoOpen
```

Isso cria outra solicitacao usando a base do registro, sem inventar Previous para
um recibo apagado ou recuperar GO/aceite perdido. Preserve a referencia antiga como
historico; ao executar o novo prompt, informe que esta reconstruindo a proposta.
Se a origem MTA tambem foi removida, resolva essa falta por manutencao explicita.

#### Compartilhar o MTA e planejar em outra maquina

Preserve a pasta completa: manifest.json, result.json, input, rules e output.
O destino pode ter caminho diferente; MtaOrigin preserva Project/Source/RunId
historicos, AnalysisSource aponta ao snapshot recebido e Source ao codigo local.
Nao renomeie identidades internas para coincidir com o checkout atual.

Vincule a origem explicitamente pelo [caminho de manutencao](#reconstruir-a-pasta-usando-um-mta-existente).
Depois use **Planejar**, que recupera o vinculo. Apenas HTML/trechos recebidos podem
ser usados como evidencias limitadas, sem alegar integridade de uma rodada completa.
Diferencas de POM/codigo geram alertas de aplicabilidade; branches/caminhos diferentes
nao sao gates. Novo MTA e recomendado quando o diagnostico estiver desatualizado.

#### Revisao manual do plano e do to-do

Confira recorte, comportamento esperado, dependencias, risco, testes, reversao
e lacunas reais. Para ajustar, registre o direcionamento ou responda no chat e
continue pela entrada **Planejar** e pelo prompt indicado na saida. Nao regenere os dois documentos
apenas para corrigir omissoes. Mudanca de escopo exige rever a autorizacao;
esclarecimento dentro do escopo mantem GO valido.

#### Revisar um lote com evidencias complementares

**Planejamento: criar pasta de evidencias** abre o indice do projeto.
Acrescente arquivos pertinentes ao LEIA-ME e explique sua relacao com o recorte.
O planejamento le essas referencias e o registro atual; nao varre caches/logs.
Uma evidencia complementar nao obriga reconciliacao separada. Execute **Planejar**:
se o indice/anexos referenciados mudaram, a tarefa emite novo recibo com Previous;
se as entradas continuam iguais, retoma o existente. O desenvolvedor nao precisa
escolher entre preparar e replanejar nem repetir projeto, rodada ou recorte.

Pedido suficiente ao helper: "Acrescentei evidencias no registro. Quero revisar
o planejamento existente". Ele localiza a solicitacao e orienta a proxima acao.
O preparo preserva a base anterior por Previous quando precisa atualiza-la. Respostas essenciais
sao incorporadas ao plano; nao precisam ser transcritas em todos os documentos.

#### Da proposta revisada a execucao e ao aceite

Registre a decisao uma vez no plano; o to-do referencia essa secao:

```text
Responsavel:
GO humano: PENDENTE
Pendencias dispensadas como precondicao: nenhuma
Aceite do resultado: AVALIAR APOS VERIFICACOES
```

Preencha seu nome e autorizacao do escopo revisado. GO nao e aceite do resultado.
Se dispensar uma precondicao, indique qual; verificacao ainda nao realizada nao
vira concluida. A retomada do mesmo escopo respeita GO ja vigente.

A corretiva deve ter testes unitarios de regressao/erros e report JaCoCo do recorte:
**meta de 85% de linhas**. Abaixo gera warning e nao reprova o build por percentual;
falhas reais de compilacao/testes continuam falhas. Cobertura global nao prova o
recorte; Sonar global e politica separada. Conferir WAR e comportamento no EAP 7.4
quando possivel, com roteiro funcional pertinente e evidencias observadas.

Sonar e novo MTA comparavel sao checklist nao bloqueante; ausencia limita as
conclusoes, sem provar resolucao/globalidade. O humano avalia as evidencias para
aceite. Novo lote exige aceite do atual e pedido de continuidade.

#### Preparar implementacao do lote

Antes de planejar, marque ao menos uma issue `ANALISAR AGORA` no registro do
projeto escolhido, inclusive `DEV-...` com origem e evidencias quando necessario.
`NAO ANALISADA`/`ANALISADA` seguem para planejamento; `PLANEJADA` para revisao
do plano e `IMPLEMENTADA`/`VERIFICADA` para verificacao do resultado. Para reabrir
uma etapa, indique explicitamente os IDs e a finalidade. Objetivo generico nao
seleciona todo o catalogo. Se faltarem ponto de codigo ou recomendacao MTA,
forneca o trecho/relatorio solicitado; mantenha evidencias pertinentes no LEIA-ME.

1. Salve o GO no plano da solicitacao escolhida. Execute **Aplicacao:
   preparar implementacao do lote**, confirme workspace/projeto e selecione a
   solicitacao com os dois arquivos. Enter vazio, q ou selecao invalida cancelam.
2. Escolha explicitamente **1** para criar `lote/<ID-do-lote>`, **2** para usar a
   branch atual ou **3** para criar uma branch com nome completo informado.
   Enter/q cancela essa etapa, mantendo o prompt salvo sem abrir o editor.
3. Confira `implementar-lote_<id12>.prompt.md`: fixa recibo/plano/to-do e hashes,
   sem criar outro planejamento ou acionar o agente. A task nao interpreta Markdown
   como aprovacao; essa verificacao cabe ao agente e ao desenvolvedor.
   O prompt incorpora copias do plano/to-do e referencia registro e evidencias;
   arquivos/hashes continuam conferidos antes da corretiva. O mesmo preparo salva
   `revisar-resultado_<id12>.prompt.md`, cujo caminho aparece na task e no prompt.
4. No Copilot, use **Executar Prompt** em conversa Local com **devsquad** e
   `devsquad.implement`, com as ferramentas pertinentes disponiveis. No Codex,
   envie `Execute o prompt deste arquivo:` com o caminho mostrado; o agente principal
   usa skills e apoio de execucao compativeis, sem converter helpers em executores.
5. O condutor confere contexto, GO, alcance e precondicoes nao dispensadas,
   delega apenas o lote autorizado e registra resultados nos mesmos PlanPath/TodoPath.
   Confira diff, comandos, verificacoes e pendencias antes de dar aceite humano.

Depois da corretiva, execute o arquivo `revisar-resultado_<id12>.prompt.md`
indicado no preparo, informando evidencias no LEIA-ME. Ele le os documentos atuais,
analisa criterios e orienta o que falta; nao executa comandos ou altera arquivos.
`revisar-lote` continua revisao da proposta, para contextos antigos.

Forneca log/exit code do [build e testes](maven.md), report JaCoCo do recorte,
[Sonar](sonar.md) e MTA comparavel quando possivel, sem fabricar baseline ANTES.
Para runtime, informe ambiente EAP 7.4, artefato/hash, recibo e logs de deploy.
O roteiro funcional deve identificar precondicoes/dados, tela/endpoint/operacao,
passos, resultado esperado/observado, casos negativos/regressao e evidencias.
Use somente ambiente autorizado; se indisponivel, registre pendencia. O humano
avalia resultado e limites antes do aceite; sucesso do build nao prova resolucao.

Mantenha `Lote ativo: <ID>` igual no inicio dos dois documentos; `ID do lote:`
tambem e aceito. Sem ID confiavel ou com divergencia, o menu oferece somente 2/3.
Na opcao 3, informe o nome completo, por exemplo `lote/ajuste-cache`; nao ha prefixo
automatico. Se a criacao falhar (nome invalido/existente), o menu informa e oferece
2/3 novamente; nao sobrescreve nem seleciona automaticamente uma branch existente.

A criacao parte do HEAD exibido da aplicacao e afeta todo o checkout, inclusive
quando Source e um modulo. Confira se outro agente usa esse checkout. A tarefa
preserva alteracoes/indice, sem force/reset/stash, commit, push ou upstream.
Opcao 2 funciona sem exigir nome padrao, mesmo com HEAD destacado ou Git indisponivel.
Mudanca dos documentos ou do Git exibido durante a escolha interrompe a criacao
para nova decisao. Criar branch nao concede GO; o Copilot nao recebe permissao
para gerir branches, publicar, escrever memoria ou abrir outro lote.

Se editar plano/to-do depois do preparo, prepare implementacao novamente para
fixar a versao atual; escolha 2 se a branch ja foi criada. Na retomada parcial,
use os documentos atualizados da mesma solicitacao: trabalho existente deve ser
conferido e GO valido do mesmo escopo preservado. Operacoes externas como
MTA/Sonar, rede e EAP/deploy exigem autorizacao para destino/finalidade;
constar como criterio futuro nao e autorizacao de execucao.

Pela CLI:

```powershell
powershell.exe -NoProfile -File .\scripts\preparar-implementacao.ps1 -WorkspacePath .\jboss-mta-harness.local.code-workspace -SelectTarget
```

`-RequestId <id-completo>` seleciona a solicitacao; `-EditorPath <editor>` abre
o prompt. `-NoOpen` suprime a abertura, mantendo a decisao explicita de branch.
Falha do editor preserva o arquivo salvo. Limpar planejamento remove esses prompts.
