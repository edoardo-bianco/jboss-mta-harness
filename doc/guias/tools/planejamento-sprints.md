---
html:
  embed_local_images: true
  embed_svg: true
  offline: true
---

# Planejamento da migracao por sprints

[Voltar ao guia do desenvolvedor](../harness-migracao-desenvolvedor.md).

Use **Terminal > Run Task > Planejamento: planejar sprints**, da pasta `harness`,
para preparar, retomar, revisar e validar a visao macro de um ou mais projetos.
O resultado relaciona restricoes, equipe e trabalho restante a sprints de
14 dias. Ele referencia registros, fichas e planos de corretiva existentes.
O planejamento de cada lote continua em **Planejamento: planejar**, com revisao,
GO e aceite separados.

## Orientacao com o helper

No Codex, ative `$orientar-migracao`; no Copilot, use `migracao_helper`.

```text
Quero planejar a migracao por sprints para todos os projetos do workspace.
Confira o que ja esta registrado e me indique a tarefa e a proxima acao.
Se houver um cenario vinculado, quero recuperar suas restricoes e lacunas.
```

Para retomar, indique o planejamento/revisao ou seu `contexto.json` quando o
helper ainda nao tiver essa referencia. Ele recupera os arquivos e entrega a
mensagem com o caminho real. O helper nao executa a tarefa, nao preenche os
arquivos e nao valida o cronograma. A elaboracao ocorre no executor do prompt
ou manualmente nos mesmos destinos.

## Configuracao

Salve o workspace com as pastas de aplicacao desejadas. A descoberta reutiliza
os projetos reconhecidos pelo harness, incluindo agregadores Maven; nao inclui
toda pasta arbitraria nem procura projetos fora do workspace escolhido.
O indice dos projetos, os registros e as fichas alimentam o contexto, com
planos/evidencias vinculados. O recorte inicial considera mandatory pendentes;
o prompt pergunta se voce quer incluir tambem optional. As referencias podem
reunir outras categorias para conferir essa escolha, sem inclui-las automaticamente.
Nao ha filtro por ANALISAR AGORA, andamento ou issues ainda nao examinadas.
ADIAR/FORA DO ESCOPO permanecem como decisoes explicitas; ficha ausente e lacuna.
Projetos sem essas fontes permanecem no escopo confirmado com suas lacunas.

Nao e necessario instalar Node/MCP ou uma skill para usar o fluxo por arquivos.
Para o prompt, use um executor que possa ler as entradas e editar os dois
entregaveis. No Codex, use o agente principal em nova conversa no mesmo workspace,
fora do helper, conforme a [passagem para execucao](../orientacao-migracao.md#passar-da-orientacao-para-a-execucao).
No Copilot, o prompt declara `devsquad`; confirme um perfil compativel disponivel.
Sem executor, o preenchimento manual mantem os mesmos arquivos e a validacao.

## Uso

### Primeira execucao

1. Execute **Planejamento: planejar sprints** e escolha **Novo cenario**.
2. Selecione **Todos os projetos do workspace** ou **Subconjunto**. Confira a
   previa de nomes/Sources e lacunas antes de confirmar o escopo.
3. Confirme o escopo e suas lacunas. A tarefa prepara as referencias/contexto;
   datas, equipe, prazo e limites sao perguntados pelo prompt executado.
4. Abra o prompt preparado pelo caminho exibido. No Codex, envie ao agente
   principal: **Execute o prompt deste arquivo: `<caminho real>`**. No Copilot,
   abra o arquivo e use **Executar Prompt** com o executor declarado.
5. No prompt, escolha se inclui optional alem de mandatory e informe somente
   as restricoes ainda ausentes: inicio, prazo de
   producao, maximos de sprints por fase, eventual limite total e teto de devs.
   Recupere valores anteriores na retomada. Uma resposta ausente fica como lacuna,
   sem assumir zero/data. Confira disponibilidade, calendario e ReferenceDate
   (data da fotografia do trabalho restante), estimativas e
   narrativa. Execute a mesma tarefa e escolha
   **Validar e gerar cronograma** para a revisao selecionada.
6. Leia `validacao.json` e `planejamento-sprints.md`: lacunas, gargalos, limites
   e premissas precisam estar explicitos antes de considerar a previsao.

O preparo gera uma entrada com restricoes/estimativas ainda nulas e um Markdown de
rascunho. Preparar nao executa o agente. O prompt preenche estimativas e
macroatividades no JSON e a narrativa no Markdown; o calculador gera os numeros,
tabelas, matriz e Gantt na etapa de validacao.

### Escolher a acao da mesma tarefa

| Acao | Quando usar | Resultado a conferir |
| --- | --- | --- |
| Novo cenario | Primeira visao, outro conjunto de projetos ou alternativa independente solicitada pelo humano. | Novo PlanningId, escopo concreto e restricoes/lacunas. |
| Retomar | Continuar o preenchimento da revisao escolhida com as mesmas entradas. | Mesmos destinos e escolhas preservadas. |
| Revisar | Mudaram fontes, restricoes, equipe ou o escopo, com motivo concreto. | Novo RevisionId, motivo e referencia anterior preservada. |
| Validar e gerar cronograma | JSON e narrativa estao preenchidos ou voce quer conferir as lacunas atuais. | Calculos/diagnosticos, validacao.json e blocos calculados atualizados. |

Escolha o cenario/revisao pelo vinculo ou pela lista apresentada; a tarefa nao
elege um arquivo pela data de modificacao. Retomar conserva a lista concreta
de Sources: adicionar uma pasta ao workspace nao amplia o cenario anterior.
Revisar pergunta se deseja manter essa lista ou atualizar a selecao de projetos.
Atualizar exige escolher Todos/Subconjunto, conferir a previa e confirmar
PREPARAR, com motivo da revisao. B0 congelada permanece fixa; inclusoes
posteriores ficam separadas em Changes.New.
Mudanca de fonte exige revisar, sem editar hashes do contexto para aceita-la.
Depois que validacao.json existir, a revisao validada e preservada. Para mudar
seus dados ou narrativa, escolha Revisar e informe o motivo. Retomar pode
consultar os arquivos; editar uma revisao ja validada faz a tarefa rejeitar
a republicacao, preservando os resultados anteriores.

### Arquivos e preenchimento manual

Cada revisao usa os caminhos informados pelo preparo:

```text
.harness/sprints/<PlanningId>/
  atual.json
  revisoes/<RevisionId>/
    contexto.json
    preparo.json
    planejamento-sprints.json
    planejamento-sprints.md
    planejar-sprints.prompt.md
    validacao.json
```

`preparo.json` vincula o hash do contexto; preserve esse selo junto ao recibo.
`atual.json` e o ponteiro da revisao consistente; ele so e atualizado pela
validacao apropriada. `validacao.json` e produzido pelo calculador. Essas saidas
nao substituem uma decisao humana. Uma validacao estrutural pode publicar um
rascunho `NAO_AVALIAVEL`; isso nao declara que o prazo cabe. Os arquivos locais
nao acompanham clone/pull.

O contexto declara ContextPath, PromptPath, SprintDataPath, SprintPlanPath,
ValidationPath e Previous. Projects identifica cada projeto/Source, registro,
base, origem, issues, lacunas e candidatos de planejamento/priorizacao.
References lista caminhos, hashes, disponibilidade e tipo das fontes usadas.
Essas referencias sao somente leitura; nao altere o contexto para adicionar
chaves ou aceitar uma fonte modificada.

Leia o JSON inicial, WorkTemplate do contexto e o
[contrato dos dados](../../especificacoes/planejamento-sprints.md) como formato de preenchimento:
mantenha os nomes e tipos dos campos prontos. Work registra macroatividades e estimativas restantes por
papel; Team registra disponibilidade; Constraints registra restricoes informadas.
Cada atividade referencia Source/Id, dependencias, fase, prioridade, faixa de
esforco, origem, confianca, premissas e aceite. Dados ausentes ficam a estimar,
sem conversao automatica de pontos MTA ou quantidade de issues em dias.
Use StaffingTemplate para Team.Staffing, uma linha por sprint, e confirme
Team.RolesAreDistinct conforme as pessoas disponiveis; null nao significa
que ha capacidades independentes confirmadas.

O agente ou autor manual edita somente dados proprios autorizados e narrativa.
Preserve contexto, escopo/referencias/hashes, baseline B0 apos seu congelamento
confirmado na validacao, arquivos anteriores e
os marcadores `<!-- sprints:inicio -->` e `<!-- sprints:fim -->` no Markdown.
O trecho entre esses marcadores e atualizado somente pelo renderizador; fora
dele, o texto editorial pode ser completado. Os blocos calculados sao atualizados pela
validacao. Nao substitua dados humanos por inferencia nem preencha resultados
calculados manualmente para aparentar viabilidade.

Se JSON e Markdown manualmente editados divergirem, concilie explicitamente
antes de validar. O JSON fornece os dados do calculo; a narrativa explica
objetivos, premissas e decisoes, sem contradizer esses dados. Erro nao autoriza
reescrever historico nem trocar a base de modo silencioso.

### Equipe, limites e estimativas

Sprints duram 14 dias corridos; capacidade usa dias-pessoa uteis por papel.
O teto de desenvolvedores nao representa disponibilidade integral. Um arquiteto
e um DevOps sao adicionais ao teto e tem capacidades proprias. Preencha
disponibilidade, reservas e ausencias/calendario conforme os campos prontos.
DeveloperAvailability, ArchitectAvailability e DevOpsAvailability usam fracao
de 0 a 1: `0.8` significa 80%. ReservePercent usa percentual de 0 a 100; `20`
reserva 20% da capacidade. AbsenceDays informa dias-pessoa por papel.
Essas ausencias sao distribuidas uniformemente nos dias uteis restantes da
sprint; datas sem expediente entram em Holidays. WorkWeek segue DayOfWeek:
domingo=0, segunda=1, ate sabado=6.
O MVP calcula papeis distintos. Se uma pessoa acumular papeis, declare a lacuna
e concilie a disponibilidade antes de avaliar viabilidade; nao some duas
disponibilidades integrais como se fossem pessoas diferentes.

O inicio de sprints ja publicado fica fixo; outro calendario exige Novo cenario.
ReferenceDate nao retrocede nas revisoes, e sprints ja encerradas permanecem
como historico. Os maximos por fase contam sprints com trabalho daquela fase; nao sao duracoes
obrigatorias nem parcelas automaticamente somaveis. TEST representa a campanha
integrada/homologacao; testes de cada corretiva acompanham seu trabalho.
Configuracao JBoss/subsystems do destino, integracao, testes e implantacao requerem fase e dependencias
explicitas. Uma janela de producao ou congelamento deve estar representada nos
dados; premissa desconhecida permanece visivel.

O motor aloca trabalho diariamente por prioridade e Id, respeitando as
capacidades de cada papel. Uma atividade usa seus papeis proporcionalmente no
mesmo periodo; sequencias internas precisam de atividades/dependencias distintas.
DependsOn libera o trabalho no dia seguinte ao termino da dependencia. Fases
nao impõem ordem automaticamente. Essa simulacao nao busca o melhor cronograma
possivel; um resultado que nao cabe pede revisar premissas e alternativas.

Sem estimativas, calendario ou restricoes essenciais, a viabilidade fica
`NAO_AVALIAVEL`. Esforco zero requer fundamento de inaplicabilidade/trabalho
ja atendido; nao substitui desconhecido. Faixas Min/Reference/Max documentam
incerteza e precisam de fonte/premissa, sem probabilidades inventadas.

Arquivos adicionais fornecidos pelo desenvolvedor podem fundamentar as faixas
em Work.References e EstimateSource. O executor precisa le-los e registrar fonte,
confianca, premissas e motivo de qualquer mudanca, incluindo impacto em
dependencias, risco e prazo. Caminho inexistente ou nao lido nao e evidencia.
Na validacao, EstimateEvidence captura os caminhos/hashes usados; preserve essa
saida. Se as fontes mudarem, Revisar permite comparar as referencias anteriores,
atuais e InputChanges. Uma EvidenceReview pendente exige comparacao e
justificativa antes de afirmar viabilidade, preservando a revisao anterior.

### Baseline, progresso e revisao

Antes do congelamento de B0, o prompt registra ScopeCategories como mandatory
ou mandatory + optional, conforme a escolha humana registrada em ScopeDecision
(obrigatoria para incluir optional), e forma Baseline.Issues
com as identidades Source/Id correspondentes de Projects.Issues. Baseline.Known
e informado pelo preparo conforme a disponibilidade/validade dos registros;
o agente nao altera esse campo por inferencia. A primeira validacao com denominador conhecido declara
BaselineFrozen=true e fixa esse conjunto e seu denominador; inclusoes posteriores ficam
em Changes.New, sem alterar a referencia inicial.
Baseline.Accepted exige evidencia e quem concedeu o aceite. Checkbox, teste aprovado ou
desaparecimento no MTA nao comprova conclusao aceita. Novas, reabertas e excluidas
ficam separadas em Changes, sem reescrever B0 para melhorar o percentual.
Confirme esses dados conforme o formato suportado antes de comparar previsoes
e realizado; uma contagem agregada nao prova resolucao de todas as ocorrencias.
Todas as pendentes do recorte devem estar em Work, mesmo a estimar; Unscheduled
e a saida calculada das nao alocadas e seus motivos, sem exclusao silenciosa.

Uma revisao nova preserva a anterior e declara motivo e impacto. O calculo
explicita escopo nao estimado, bloqueado ou fora do horizonte. Se faltarem
evidencias para comparar, registre a limitacao; nao declare recuperacao do prazo
ou conclusao global por reduzir o catalogo.

## Resultado e proximo passo

Confira a classificacao e os diagnosticos da validacao, a carga por papel, os
marcos e a data de producao nas premissas usadas. Cronograma consistente e uma
previsao tecnica: nao concede GO para lotes, aceite ou autorizacao de deploy.

| Viabilidade | Leitura |
| --- | --- |
| CABE_NAS_PREMISSAS | A simulacao de referencia e a faixa superior cabem nas entradas usadas. |
| EM_RISCO | A referencia cabe, mas a faixa superior nao confirma a entrega. |
| NAO_CABE | A simulacao nao aloca todo o trabalho nos limites informados; revise alternativas. |
| NAO_AVALIAVEL | Lacunas impedem avaliar o conjunto; complete/revise os dados indicados. |

O Gantt destaca as sprints que recebem trabalho de cada atividade; a barra nao
significa ocupacao continua de todos os dias. Confira as cargas e conclusoes nas
tabelas. Se o resultado calculado exigir ajustar objetivos/HUs ou outra parte
editorial, use Revisar antes de editar a revisao publicada e valide a nova revisao.
Lacunas e conflitos exigem completar a revisao ou criar revisao com motivo
pela mesma tarefa. Para detalhar a corretiva escolhida, volte ao
[planejamento por issue](planejamento-migracao.md#qual-caminho-seguir).

O [template editorial](../../modelos/planejamento-sprints.template.md) mantem a
forma da visao sintetica. A [feature MACRO-01](../../features/planejamento-macro-sprints.md)
registra requisitos e limites da capacidade; este guia concentra o uso cotidiano.
