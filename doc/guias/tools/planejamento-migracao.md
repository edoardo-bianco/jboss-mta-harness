---
html:
  embed_local_images: true
  embed_svg: true
  offline: true
---

# Planejamento e reconciliacao da migracao

[Voltar ao fluxo principal do desenvolvedor](../harness-migracao-desenvolvedor.md#roteiro-onde-estou-e-o-que-escolho).

Guia da ferramenta de planejamento do harness: indice dos projetos, registro
`migracao-<projeto>.md` (ou `migracao.md` legado), proposta de lote, preparo
da implementacao e reconciliacao com novo MTA ou evidencias. Todos os comandos
partem da raiz do harness. As tarefas preparam entradas e prompts; o desenvolvedor
executa os prompts e confere os documentos produzidos.

**No fluxo principal:** este guia detalha as
[etapas 4 a 8](../harness-migracao-desenvolvedor.md#4-conferir-o-registro-e-escolher-prioridades):
triagem, proposta, GO, implementacao, aceite e reconciliacao.
Use [Qual caminho seguir](#qual-caminho-seguir) para escolher a operacao conforme
a situacao. Durante a verificacao, siga as ferramentas indicadas na
[etapa 7 do guia principal](../harness-migracao-desenvolvedor.md#7-verificar-e-aceitar-o-resultado);
para decidir a continuidade, retorne a
[etapa 8](../harness-migracao-desenvolvedor.md#8-reconciliar-e-decidir-a-continuidade).

Navegacao: [configuracao](#configuracao) · [uso](#uso) ·
[indice](#indice-da-situacao-dos-projetos) · [registro](#registro-de-migracao-por-projeto) ·
[reconciliacao](#reconciliar-status-antes-de-atualizar-o-plano) ·
[plano e to-do](#preparar-e-executar-o-prompt) ·
[implementacao](#preparar-implementacao-do-lote) · [GO e aceite](#da-proposta-revisada-a-execucao-e-ao-aceite).

## Configuracao

Abra o workspace local com os projetos Maven e use as tarefas da pasta
`harness`. A [selecao de projeto](workspace.md#escolher-o-projeto-em-cada-tarefa)
define Source; confirme o caminho mesmo quando dois projetos tem o mesmo nome.
Nao e preciso criar outro JSON para esse fluxo.

Para executar os prompts, mantenha Copilot autenticado em sessao **Local**,
com DevSquad disponivel. Planejamento usa `devsquad.plan`; implementacao usa
`devsquad.implement`. Leitura, edicao e ferramentas de apoio seguem os limites
do [contrato vigente](../../especificacoes/planejamento-copilot.md).
Gerar/abrir um prompt nao o executa nem concede autorizacao para outra fase.

O [guia MTA](mta.md) orienta analise e relatorios; o [guia Sonar](sonar.md)
orienta coleta de qualidade; o [guia JBoss](jboss.md) orienta validacao de runtime.
Os recibos/evidencias dessas ferramentas podem ser entradas do planejamento.
Usar MTA existente ou recebido dispensa repetir a analise apenas para preparar
uma proposta. O registro e o historico ficam locais em `.harness/`.

## Uso

A ordem usual e **indice → registro e reconciliacao → proposta plan/to-do →
GO → preparo e execucao da implementacao → verificacoes e aceite**.
Novo MTA/evidencias podem atualizar o mesmo lote; outro lote so vem depois de
aceite e pedido de continuidade. O plano da implementacao e a proposta em
`plan.md`/`todo.md`; **Aplicacao: preparar implementacao do lote** prepara
o prompt para executar o plano escolhido, sem gerar outra proposta.

### Qual caminho seguir

Na tarefa **Planejamento: preparar contexto para Copilot**, **1** prepara um lote
e **2** cuida somente do registro. Gerar ou abrir um prompt nao o executa no Copilot.

| Situacao | Caminho e ponto de parada |
| --- | --- |
| Primeiro lote, com MTA novo ou ja existente | Opcao **1**; selecionar a rodada (ou **p** para pasta recebida), salvar ANALISAR AGORA e executar o prompt. [Passo a passo](#preparar-e-executar-o-prompt). |
| Quero carregar os MTA reconhecidos de todos os projetos | **Workspace: atualizar indice dos projetos** carrega os registros possiveis e prepara prompts. Execute os que aparecerem PENDENTES. [Indice](#indice-da-situacao-dos-projetos). |
| Quero escolher outra rodada ou reconciliar registro de colega/evidencias | Opcao **2**, com MTA ou **2: somente registro/evidencias existentes**; executar o prompt para concluir a reconciliacao. Apenas migracao.md muda; nao produz lote. [Entradas e limites](#reconstruir-a-pasta-usando-um-mta-existente). |
| So mudei as prioridades no migracao.md antes de planejar | Salvar o registro e usar o prompt ja preparado; nao gerar outra solicitacao. |
| Quero completar ou corrigir a proposta atual | Pedir o ajuste na mesma conversa e nos mesmos documentos. Para uma revisao separada, opcao **1**, selecionando a proposta como Previous. [Revisao](#revisao-manual-do-plano-e-do-to-do). |
| Tenho novo MTA para um lote em andamento | Opcao **1**, selecionar o novo MTA e o plano anterior; reconciliar o lote existente. Nao alterar o RunId do recibo antigo. [Evidencias e revisao](#revisar-um-lote-com-evidencias-complementares). |
| Tenho GO ou preciso retomar implementacao parcial | Usar **Aplicacao: preparar implementacao do lote**, com os documentos atuais; escolher branch atual se ja criada. [Implementacao e retomada](#preparar-implementacao-do-lote). |
| Terminei o lote e quero avancar | Conferir resultados, registrar aceite humano e pedir continuidade. Preparar opcao **1** com a proposta anterior e evidencias; proximo lote somente apos aceite. [GO e aceite](#da-proposta-revisada-a-execucao-e-ao-aceite). |

### Indice da situacao dos projetos

Execute **Terminal > Run Task > Workspace: atualizar indice dos projetos** e
informe o workspace em uso. Nao ha escolha de projeto: a consulta abrange todos
os projetos Maven desse workspace, distinguindo nomes iguais pelo caminho Source.
Sem workspace pela CLI, usa os projetos cadastrados no JSON local.

A tarefa abre `.harness/projetos/indice-projetos.md` e salva uma copia datada em `indices/`.
Na tabela de resumo, a coluna **Registro de migracao** mostra o nome do arquivo
clicavel (`migracao-<projeto>.md` ou `migracao.md` legado), com o status ao lado.
Clique nesse nome para consultar detalhes, decisoes e evidencias do projeto.
Quando o registro ainda nao existe, a coluna mostra **NAO GERADO**, sem link.

Antes do resumo, carrega/recalcula os registros possiveis a partir da ultima rodada
reconhecida de cada projeto e prepara prompts manter-migracao. Preserva decisoes,
andamento, texto livre, issues manuais e evidencias. Nao altera os relatorios MTA.
Falha recente, ambiguidade, catalogo invalido ou integridade nao confirmada deixa
o registro preservado e a causa visivel; os demais projetos continuam sendo tratados.
Nao substitui uma falha recente por sucesso antigo. Projetos sem MTA nao recebem
catalogo inventado. Para outra rodada/origem, use a selecao explicita no preparo.

**Execute no Copilot cada prompt indicado como PENDENTE.** A coluna Reconciliacao
e a secao homonima do migracao.md mostram estado e link. Catalogo atualizado e
MESMA RODADA nao significam reconciliacao concluida. Depois de executar o prompt,
registrar conclusoes e resolver conflitos, Estado pode ser marcado CONCLUIDA;
a tarefa nao o faz automaticamente. Isso nao concede GO/aceite da migracao.
Repetir a tarefa reutiliza o prompt vinculado se rodada/catalogo, indice de evidencias,
contrato e modelo forem iguais; anotacoes atuais sao lidas no registro. Uma conclusao
registrada nao dispara outro prompt. Nova rodada/contexto inicia nova pendencia.

O indice e a selecao MTA no preparo tambem consultam `mta.runsPath`, mesmo sem
referencias em `.harness/runs` depois da limpeza. Use a estrutura
`<pasta externa>/<projeto>/<rodada completa>`; formatos antigos e novos sao lidos
pelo manifesto, sem renomear arquivos. A associacao automatica exige Source igual
ao caminho local. Para MTA de outra maquina/caminho, use **p** no preparo: nomes
iguais nao sao suficientes para associar automaticamente. Copias em pastas distintas
com o mesmo RunId sao ambiguas e exigem conferencia; referencias a mesma pasta
nao duplicam a rodada.

A coluna **MTA x registro** deixa visivel a diferenca entre encontrar um relatorio
e carregar seu catalogo:

O proprio relatorio inclui a secao **Como interpretar o indice**, com a legenda
abaixo e a acao indicada para cada estado, sem precisar abrir este guia.

| Indicacao | Significado e acao |
| --- | --- |
| CATALOGO NAO CARREGADO | Nao foi possivel carregar o registro. Confira Atualizacao do registro e Limites da leitura; os numeros MTA podem estar disponiveis mesmo assim. |
| MESMA RODADA | RunId encontrado e carregado coincidem; nao e validacao de conteudo, codigo ou aceite. |
| RODADA DIFERENTE | Conferir RunIds e o motivo da carga nao concluida nos detalhes. |
| ULTIMA TENTATIVA FAILED (ou outro estado sem sucesso) | Conferir a tentativa; nao substituir o catalogo por resultado com falha. |
| SEM MTA LOCALIZADO / COMPARACAO INDISPONIVEL | Conferir pasta configurada, origem e limites da leitura; nao significa que nunca houve MTA. |

Copiar um relatorio e executar **Atualizar indice dos projetos** carrega o MTA
reconhecido no registro e deixa o prompt pronto. A execucao desse prompt e uma
etapa separada e necessaria para concluir a reconciliacao.

No inicio, uma linha por projeto consolida as ultimas acoes, o registro, as issues
e ocorrencias MTA, decisoes, andamento e proximos passos sugeridos. **Numeros e
categorias sao lidos diretamente do ultimo MTA**, mesmo sem migracao.md ou com
registro desatualizado. Nao precisa preparar contexto para ver esse resumo.
Categorias aparecem na linha resumida, nos totais gerais e nos detalhes. Cada par
indica issues / ocorrencias (ex.: mandatory: 2 / 138); categorias adicionais do MTA
sao preservadas. Essa classificacao nao e a prioridade de execucao do desenvolvedor.
Os totais informam quantos catalogos
MTA foram contabilizados; tentativa com falha, ambiguidade ou catalogo ausente/ilegivel
fica indisponivel, sem usar outra rodada ou o registro como substituto. Catalogo
valido vazio mostra zero. Issues sao regras por projeto: a mesma regra em dois
projetos conta duas vezes. Ocorrencias sao os pontos MTA.
**Decisoes e andamento vem do registro**, que pode usar outra rodada (confira MTA x
registro); contam issues presentes e manuais, excluindo nao reencontradas. Nao some
essas duas dimensoes da mesma issue. Manuais nao entram no total MTA.
As sugestoes usam os registros atuais para orientar a conferencia de falhas,
carga do MTA, prioridades, planejamento, GO ou verificacao; nao executam essas etapas.
IMPLEMENTADA/VERIFICADA pode ter cobertura parcial e nao comprova migracao concluida.

Mostra somente a ultima tentativa de cada acao por projeto, com datas, IDs
e links, sem contar ou listar historico. Uma falha recente nao e substituida pelo
ultimo sucesso; avisos de rodadas comprovadamente anteriores ficam fora. Sem
data/identidade suficiente para determinar a ultima, informa leitura parcial. Planejamento
distingue contexto preparado, documentos incompletos e plano/to-do presentes.
Mostra tambem o ultimo preparo de manutencao do registro, separadamente. O registro mostra catalogo carregado
ou aguardando MTA, contagens, escolhas e andamento por issue.

Execute novamente apos novas rodadas ou edicoes manuais/pelo agente; nao ha
atualizacao continua. A tarefa cria registros ausentes quando ha MTA valido e
prepara prompts; nao executa agente, build ou analise, nao concede GO/aceite e
nao comprova que os resultados valem para o codigo atual.
Leitura invalida/inacessivel aparece como limite; SEM REGISTRO nao significa que
nunca executou. Apos limpar indices MTA locais, a referencia carregada no registro
continua visivel, mas nao substitui um recibo de execucao disponivel.
Se o RunId carregado no registro difere do ultimo MTA registrado, o indice avisa.
Categorias/contagens **no migracao.md** sao sincronizadas pela tarefa do indice,
preservando decisoes. A selecao manual no preparo continua disponivel para outra
rodada/origem; a proxima atualizacao geral volta a usar a ultima rodada reconhecida.
No proprio registro, o rodape continua refletindo a rodada carregada, excluindo
manuais e nao reencontradas. Por isso seus totais podem diferir dos numeros do indice.

Cada copia guarda os textos/contagens consultados naquele momento; links continuam
apontando para os arquivos originais e podem deixar de funcionar se forem apagados.
Nao e backup das evidencias nem do codigo. Indice e historico sao locais, ficam
fora do Git e sao preservados pela limpeza de execucoes. Se houver tarefas/agentes
alterando arquivos durante a consulta, repita ao terminar para obter nova fotografia.

### Planejar lotes de correcao com Copilot

O registro do projeto concentra escolhas; o plano detalha um unico lote. A Run Task
prepara os arquivos e **voce executa o prompt** no Copilot. Preparacao nao concede
GO nem aplica corretivas. Os planos da aplicacao ficam em .harness/planning/;
tasks/ pertence a evolucao do harness.

#### Registro de migracao por projeto

Ao gerar o workspace ou executar a primeira tarefa apos adicionar um projeto,
o harness cria, sem sobrescrever:

```text
.harness/projetos/<nome>__<chave>/
  migracao-<projeto>.md
  evidencias/LEIA-ME.md
```

A chave identifica a raiz local, inclusive agregadores Maven; modulos nao recebem
registros separados implicitamente. Rotulos iguais em raizes diferentes ficam
separados. Alterar o nome no Explorer ou alternar entre configuracao e workspace
nao duplica a pasta. Remover o projeto do workspace nao apaga seu registro.

O nome novo inclui o rotulo seguro do projeto para distinguir abas no editor.
Arquivos ja existentes, inclusive migracao.md, mantem o caminho. Neste guia e nos
prompts, migracao.md significa o registro indicado por MigrationPath no contexto;
nao renomeie um registro usado por solicitacoes antigas.

Antes do MTA, o documento fica AGUARDANDO MTA. Ao escolher uma rodada, recebe uma
linha por issue (ruleset::regra), com titulo, categoria e numero de ocorrencias.
Os dados vem de output/static-report/output.js, lido como JSON sem executar JavaScript.
O harness nao inventa as demais issues a partir de um print parcial.
Formato nao suportado e informado. Rodada antiga sem output.js continua utilizavel
no planejamento, mas nao preenche o catalogo automaticamente.
O rodape mostra o total de issues/regras e de ocorrencias da rodada carregada.
Issues manuais e NAO REENCONTRADA ficam fora desses totais. Em registros anteriores,
selecione o MTA novamente no preparo para atualizar o rodape; nao precisa novo scan.

Novos registros incluem **Como usar este registro**, com significados e valores
por campo; registros existentes preservam seu texto ao atualizar o MTA.
Edite as escolhas no migracao.md; mantenha as oito colunas e os marcadores da tabela:

| Campo | Uso |
| --- | --- |
| Decisao | A DEFINIR, ANALISAR AGORA, ADIAR ou FORA DO ESCOPO, com justificativa humana. |
| Andamento | NAO ANALISADA, ANALISADA, PLANEJADA, IMPLEMENTADA ou VERIFICADA. |
| Observacao/referencia | Cobertura parcial, motivo, plano/evidencia e declaracoes de colegas. |
| Presenca | PRESENTE na rodada selecionada; NAO REENCONTRADA preserva a ultima contagem, sem afirmar correcao. |

Analisar 20 de 138 ocorrencias nao conclui toda a issue. Correcao de colega ainda
ausente no codigo local fica AGUARDANDO INTEGRACAO na observacao, com referencia.
Issues adicionais usam ID DEV-..., categoria manual, contagem - e presenca MANUAL.
Para escrever barra vertical dentro de celula, use &#124;.
Nenhum status concede GO ou aceite. Entre desenvolvedores, a conciliacao e manual;
arquivo mais recente nao vence automaticamente um conflito.

#### Reconstruir a pasta usando um MTA existente

Nao precisa repetir a analise. Se pretende planejar um lote agora, use diretamente
a opcao 1 descrita abaixo: ela tambem cria/atualiza o registro a partir do MTA.
Para somente reconstruir ou atualizar o registro, sem planejar:

1. Use **Planejamento: preparar contexto para Copilot > 2. Atualizar somente migracao.md**.
2. Escolha **1: selecionar MTA**. Use Enter para a ultima elegivel, **h** para o
   historico ou **p** para informar a pasta completa da rodada.
3. Confira o caminho do migracao.md exibido. A pasta foi criada e o catalogo carregado
   quando disponivel no formato MTA suportado; caso contrario, confira o aviso.
   Escolhas, observacoes e issues manuais existentes foram preservadas.
4. Para recuperar andamento, forneca registro anterior ou planos/evidencias pertinentes
   e execute manter-migracao. Somente o MTA inicializa A DEFINIR/NAO ANALISADA;
   ele nao comprova analise, implementacao ou verificacao realizadas anteriormente.

O catalogo ja esta carregado, mas a reconciliacao fica PENDENTE. Execute
manter-migracao no Copilot para interpretar evidencias e reconciliar decisoes/andamento
somente no migracao.md, sem gerar plan.md/todo.md. Gerar o prompt nao executa essa etapa.

Para usar essa ajuda, confira as entradas e o direcionamento no arquivo
manter-migracao.prompt.md aberto, e use **Executar Prompt** em conversa Copilot
Local com **devsquad**. Ao terminar, revise o migracao.md no caminho informado.
Se depois quiser planejar, siga a opcao 1.

Ao executar manter-migracao, o DevSquad pode escolher um subagente para ajudar na
leitura e reconciliacao. Esse apoio e opcional e somente devolve uma proposta;
o condutor confere as evidencias e grava apenas migracao.md. Conflitos humanos
permanecem para sua decisao. Nenhum dos agentes planeja lotes ou altera a aplicacao.

Para receber um registro de colega, use o parametro MigrationSourcePath abaixo.
O arquivo recebido e entrada; o destino continua sendo o migracao.md local.
Conflitos ficam visiveis para conciliacao, sem substituir decisoes silenciosamente.

```powershell
.\scripts\preparar-planejamento.ps1 -WorkspacePath .\jboss-mta-harness.local.code-workspace -SelectTarget -Operation manter-migracao -RunPath "C:\mta-runs\SIMTR-api\260930-154744" -MigrationSourcePath "C:\recebidos\migracao.md"
```

Para atualizar somente observacoes/evidencias, escolha **2: somente registro/evidencias
existentes**, sem selecionar outro scan. Pela CLI, use -WithoutMta no lugar de
-RunPath. Pode informar -EvidenceIndexPath para um LEIA-ME existente fora da pasta
padrao. Planos anteriores podem ser referenciados nesse indice como evidencias;
o mantenedor nao os altera. Uma reconciliacao CONCLUIDA nao precisa ser repetida
antes de cada planejamento; execute novamente quando houver nova pendencia/contexto.

#### Reconciliar status antes de atualizar o plano

Use este roteiro quando chegar outro MTA, houver novas evidencias ou o registro
precisar refletir o trabalho ja feito antes de atualizar a proposta:

1. Confira o projeto e o Source local. Identifique a rodada selecionada pelo
   RunId e a proposta anterior pelo RequestId; preserve os recibos e snapshots.
   MTA recebido de outra maquina entra por **p**, sem trocar sua identidade.
2. Liste novas evidencias em `evidencias/LEIA-ME.md`, com arquivo relativo,
   relacao com a correcao e origem/data/ambiente pertinentes. Inclua planos ou
   registro de colega quando forem necessarios para recuperar andamento.
3. Para alinhar somente o registro, use **2. Atualizar somente migracao.md**:
   selecione o novo MTA ou **2: somente registro/evidencias existentes**.
   Execute o prompt `manter-migracao` e revise as mudancas; preparar o contexto
   apenas carrega dados objetivos e deixa a reconciliacao PENDENTE.
4. Confira cada dimensao na tabela abaixo. Preserve decisoes humanas, cobertura
   parcial e conflitos visiveis. Sem evidencia suficiente, registre a pendencia;
   nao promova andamento nem marque reconciliacao CONCLUIDA por uma contagem menor.
5. Para atualizar o plano, use **1. Planejar ou atualizar lote**, selecione a
   rodada pertinente e a proposta anterior em **Previous**. Execute o prompt
   para reconciliar o mesmo lote, mantendo seu ID e o trabalho ja realizado.
   Se chegou novo MTA, prepare novo contexto; nao edite RunId de recibo antigo.
6. Confira a coerencia entre `migracao.md`, `plan.md` e `todo.md`: escopo,
   cobertura, verificacoes feitas/pendentes e decisoes humanas. Depois atualize
   o indice para refletir os documentos atuais. Nova proposta/revisao de escopo
   exige revisao humana, sem herdar GO automaticamente.

A etapa 3 e para quem precisa reconciliar o registro separadamente. Se o registro
ja esta consistente ou o objetivo imediato e atualizar o lote, pode usar a opcao 1
diretamente; nao existe ciclo obrigatorio de manter-migracao antes de todo plano.
Nessa opcao, o agente atualiza somente andamento/cobertura/referencias das issues
trabalhadas no registro, sem substituir as decisoes humanas. Concluir esse plano
nao equivale a concluir um prompt separado de reconciliacao que ainda esteja pendente.

| Dimensao | Como conferir consistencia |
| --- | --- |
| Catalogo e presenca MTA | Vincular contagens a rodada; distinguir PRESENTE, NAO REENCONTRADA e MANUAL. Ausencia no novo relatorio nao comprova correcao. |
| Decisao | ANALISAR AGORA, ADIAR e FORA DO ESCOPO representam escolhas humanas; novo MTA nao as redefine. A DEFINIR exige triagem. |
| Andamento e cobertura | PLANEJADA, IMPLEMENTADA ou VERIFICADA precisam de referencias e recorte. Uma amostra nao conclui todas as ocorrencias; nova rodada exige conferir a abrangencia, sem rebaixar ou confirmar estados automaticamente. |
| Reconciliacao | PENDENTE enquanto o prompt nao for executado ou houver conflitos. CONCLUIDA exige conclusao registrada apos tratar as entradas e resolver conflitos; MESMA RODADA nao substitui isso. |
| Plano e to-do | Mesmo Lote ativo; tarefas concluidas sustentadas por evidencias e pendencias atuais explicitas. Reutilizar Previous preserva historico, nao concede aprovacao. |
| GO e aceite | GO autoriza execucao do escopo; aceite avalia o resultado. Nenhuma contagem, estado de issue ou reconciliacao concede essas decisoes. |

Se mudou apenas feedback ou evidencia, reutilize a rodada pertinente. Para ajuste
da entrega atual na mesma conversa, use os mesmos destinos; nao regenere documentos
sem necessidade. Para revisao separada, selecione Previous. Se alterou plano/to-do
apos preparar a implementacao, prepare o prompt de implementacao novamente para
fixar a versao atual, mantendo a branch ja escolhida quando aplicavel.

#### Preparar e executar o prompt

1. Use **Planejamento: preparar contexto para Copilot > 1. Planejar ou atualizar lote**.
   Escolha projeto e MTA: Enter ultima elegivel, h historico, p pasta completa, q cancela.
2. Se houver proposta anterior, selecione-a para atualizar o mesmo lote; Enter inicia
   independente. Previous nao concede GO nem transfere aprovacao.
3. Abra o migracao.md no caminho exibido, marque ANALISAR AGORA nas issues desejadas
   e salve. A preparacao ja preencheu/atualizou o catalogo quando disponivel no MTA;
   escolhas existentes foram preservadas. Editar o registro nao exige novo preparo.
4. O objetivo padrao do prompt e planejar um lote a partir das issues ANALISAR AGORA.
   Altere **Direcionamento do desenvolvedor** somente se quiser outro objetivo ou
   acrescentar observacoes; nao precisa repetir as escolhas do registro.
   Confira o contexto ao final: caminhos, rodada e destinos. O recibo guarda o
   registro no momento do preparo e a copia do contrato tecnico; o registro segue editavel.
5. Use **Executar Prompt** em nova conversa **Copilot Local** com devsquad ou a
   chamada /planejar-lotes mostrada no terminal. O condutor delega a devsquad.plan,
   grava/rele o plano/to-do e registra andamento/cobertura das issues trabalhadas.
6. Abra os resultados com **Planejamento: abrir plano e to-do** e revise.

O plugin deve disponibilizar devsquad, devsquad.plan e skills pertinentes.
Confira **Chat: Open Customizations** e **Configure Tools**: subagente
(agent/runSubagent), leitura/busca e edicao. O harness nao instala o plugin.
Se .harness estiver oculta, abra o caminho exibido com Ctrl+P. Ausencia na busca
nao prova ausencia do arquivo. Resposta apenas no chat nao substitui a proposta salva.

A abertura usa bin/code.cmd da mesma instalacao indicada pela tarefa (code-insiders.cmd
no Insiders), com --reuse-window. O terminal informa a CLI usada e eventuais falhas;
os arquivos ja preparados permanecem salvos. Se a aba nao aparecer, use Ctrl+O com
o caminho exibido, sem preparar outra solicitacao nem limpar o cache do editor.

O prompt [planejar-lotes](../../../.github/prompts/planejar-lotes.prompt.md) atende inicio
e revisao; revisar-lote permanece para contextos antigos. Nao ha segundo prompt
obrigatorio nem ciclo de manutencao/planejamento repetido. Na retomada, preserve
ID e trabalho feito. O limite e uma elaboracao e uma correcao tecnica consolidada
pelo especialista; forma/fatos conferidos sao ajustados pelo condutor. Sem terceiro
ciclo de regeneracao. Os testes de scripts nao comprovam obediencia do Copilot.

Planejamento nao executa terminal, Git, Maven, MTA, Sonar, web ou corretivas.
Limites sao instrucoes comportamentais, nao sandbox tecnica dos subagentes.
O contrato unico esta na [especificacao existente](../../especificacoes/planejamento-copilot.md).

#### Como se forma o lote, o plan.md e o todo.md

O agente aprofunda somente as issues escolhidas e pontos relacionados. Varias issues
so formam um lote com causa/solucao, aceite e reversao comuns. Dependencia em issue
adiada/excluida exige decisao; sem selecao clara, o agente recomenda e pede escolha.
Categoria mandatory nao transforma todo o relatorio em um lote.

O agente confere regras MTA, snapshot input e pontos correspondentes no Source,
POMs, consumidores, testes e configuracoes relevantes. Distingue contagem bruta,
cobertura analisada e alteracoes deduplicadas. Justifica rota assistida/OpenRewrite/
combinada, riscos, testes e pendencias sem inventar resultados.

| Documento | Conteudo |
| --- | --- |
| migracao.md | Escolhas/andamento por issue, cobertura e referencias. Nao substitui o plano tecnico. |
| plan.md | Identidade, Lote ativo, proposta, POM/dependencias, escopo, verificacoes, reversao, historico e decisao humana. |
| todo.md | Mesmo Lote ativo, link para plano/decisao e tarefas com evidencia de conclusao. Sem repetir a analise. |

Java 8, javax.* e EAP 7.4 permanecem; nao migrar para jakarta.*. Lote Hibernate inclui
alinhar compilacao/testes ao ORM 5.3; patch exato depende de evidencia do destino.
Conferir propriedade/parent/BOM, integracoes e escopos provided/test, sem embutir
Hibernate no WAR. Build em 5.1 nao comprova 5.3; dispensa previa nao elimina a entrega.

#### Localizar documentos e identificar o historico

**Planejamento: abrir plano e to-do** lista propostas salvas, pelo projeto/datas/IDs.
RunId identifica MTA; RequestId identifica solicitacao; Previous aponta a anterior.
Lote ativo identifica o trabalho mantido entre revisoes, independentemente do RunId.

Solicitacoes ficam em
`.harness/planning/<nome>__<chave>/mta_<data-fuso>__<RunId12>/plano_<data-fuso>__<RequestId12>/`.
Ali ficam prompt, context.json e, apos o agente, plan.md/todo.md. Manutencao do
registro usa `registro/solicitacao_<id>` sob a pasta de planejamento do projeto e nao aparece
como lote no menu. Formatos historicos continuam legiveis, sem renomeacao.
Novos preparos usam o contrato atualizado; nao e preciso repetir MTA para isso.

O historico de propostas so lista solicitacoes com **plan.md e todo.md** existentes.
Se apenas preparou o contexto, abra o prompt pelo caminho exibido e execute-o no
Copilot; ainda nao ha proposta para abrir ou selecionar como Previous.

#### Compartilhar o MTA e planejar em outra maquina

Para consulta visual, copie output/static-report inteira; somente index.html nao
basta. Para registro/planejamento, envie a rodada completa: manifest.json, result.json,
input, rules e output. O destinatario seleciona projeto local e usa **p** no menu.
Nao e necessario copiar toda .harness ou igualar caminhos/branches das maquinas.

Pode copiar uma rodada antiga para `C:/mta-runs/<projeto>/AAMMDD-HHMMSS` e renomear
apenas a pasta, usando data/hora original. Nao altere RunId, datas ou caminhos dos
manifestos/resultados. Informe a copia por p/RunPath; renomear nao a cadastra como
ultimo relatorio. Preserve a pasta original enquanto planos antigos a referenciarem.
O snapshot contem fontes; confira o conteudo e os destinatarios do compartilhamento.

MtaOrigin preserva identidade/Source/RunId da origem; AnalysisSource e o input atual
da rodada e Source e o projeto local. Diferencas Maven/codigo geram alertas; o agente
confere aplicabilidade e recomenda novo MTA se necessario, sem bloquear por caminho/Git.
Analise sem sucesso/integridade ou rodada incompleta continuam erros de entrada.
A pasta recebida nao e copiada/importada nem apagada pela limpeza de rodadas locais.

#### Revisao manual do plano e do to-do

Para completar a entrega atual, peca ajuste na mesma conversa/destinos; nao precisa
refazer task, build ou MTA. Para registrar uma revisao separada, salve observacoes
no plano, prepare contexto escolhendo-o como Previous e execute planejar-lotes.
Preencha somente o que mudou no direcionamento; preserve ID, historico e pendencias.
Nova proposta/revisao de escopo nao herda GO automaticamente. Nao edite recibos/MTA.

#### Revisar um lote com evidencias complementares

Use **Planejamento: criar pasta de evidencias** para abrir o indice do projeto.
Repetir a tarefa reabre o mesmo indice, preservando seu conteudo. Liste arquivos
relativos e sua relacao com a correcao; nao precisa de lote anterior.

| Arquivo relativo | Relacao com a correcao |
| --- | --- |
| build-antes-result.json | Resultado ANTES; informar origem/data quando conhecidos. Nao comprova testes DEPOIS ou runtime. |

O indice padrao ja entra no preparo. Indice antigo/externo usa -EvidenceIndexPath.
O [modelo existente](../modelo-evidencias-complementares.md) serve como referencia
para preenchimento manual. Nao exige formulario/hashes adicionais; o agente le
somente os arquivos listados. Preserve evidencias ja usadas e dê nomes distintos
a novos resultados. Pastas antigas .harness/evidencias continuam preservadas.

Se ha novo MTA, selecione-o junto com Previous. Compare persistentes, novas,
nao reencontradas e inconclusivas; nao altere o RunId de contexto ja preparado.
Se mudou somente feedback/evidencia, reutilize a rodada pertinente.

#### Da proposta revisada a execucao e ao aceite

GO autoriza implementar; aceite aprova o resultado depois. Novos planos trazem uma
unica secao **Decisao humana** no plan.md; todo.md aponta para ela:

```text
Responsavel:
GO humano: PENDENTE
Pendencias dispensadas como precondicao: nenhuma.
Aceite do resultado: PENDENTE.
```

Preencha nome e GO com "autorizo implementar este plano e seu to-do". Data opcional.
GO generico mantem precondicoes; para dispensa, identifique quais ou escreva
"todas as precondicoes listadas". Verificacoes ausentes continuam pendentes.
Documentos antigos com decisao nos dois arquivos continuam aceitos, sem exigir
preencher GO duplicado. O agente nao responde pelo humano.

Sonar ANTES/DEPOIS e novo MTA sao checklist nao bloqueante; nao precisam de dispensa.
Nao fabricar baseline ANTES depois da corretiva. Cobertura meta 85% gera aviso;
falha de compilacao/testes continua falha. Confira diff, build Java 8, dependencias,
WAR e runtime EAP 7.4, distinguindo realizado de pendente. O desenvolvedor decide
aceite com esses limites visiveis. Proximo lote exige aceite e pedido de continuidade;
sem novo MTA, comparacao fica pendente, sem afirmar conclusao global.

#### Preparar implementacao do lote

1. Salve o GO no plano da solicitacao escolhida. Execute **Aplicacao:
   preparar implementacao do lote**, confirme workspace/projeto e selecione a
   solicitacao com os dois arquivos. Enter vazio, q ou selecao invalida cancelam.
2. Escolha explicitamente **1** para criar `lote/<ID-do-lote>`, **2** para usar a
   branch atual ou **3** para criar uma branch com nome completo informado.
   Enter/q cancela essa etapa, mantendo o prompt salvo sem abrir o editor.
3. Confira `implementar-lote_<id12>.prompt.md`: fixa recibo/plano/to-do e hashes,
   sem criar outro planejamento ou acionar Copilot. A task nao interpreta Markdown
   como aprovacao; essa verificacao cabe ao agente e ao desenvolvedor.
4. Use **Executar Prompt** em nova conversa Local com **devsquad**, com
   `devsquad.implement`, leitura, edicao, terminal e ferramenta de subagente disponiveis.
   A alternativa `/implementar-lote` preenchida aparece no terminal.
5. O condutor confere contexto, GO, alcance e precondicoes nao dispensadas,
   delega apenas o lote autorizado e registra resultados nos mesmos PlanPath/TodoPath.
   Confira diff, comandos, verificacoes e pendencias antes de dar aceite humano.

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
