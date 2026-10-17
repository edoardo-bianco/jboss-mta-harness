# Contrato executavel do planejamento por sprints

SchemaVersion=1, Purpose=current-sprint-planning. Regras do cronograma na
[secao final](#regras-do-cronograma). Uso pelo desenvolvedor:
[Run Task e prompt](../guias/tools/planejamento-sprints.md). O JSON preparado e
os templates WorkTemplate/StaffingTemplate em contexto.json fornecem a estrutura
para o executor; nao e necessario montar arquivos de entrada manualmente.

## Entradas do executor

| Campo | Contrato |
| --- | --- |
| Scenario / MasterProject | Nome funcional do cenario e artifactId do participante que guarda o unico conjunto corrente. Sem identidades de execucao/revisao. |
| State | RASCUNHO, PROPOSTA ou REVISADO; nao significa GO. |
| ScopeCategories | mandatory; adicionar optional somente com ScopeDecision humana. |
| Constraints | Datas ISO YYYY-MM-DD: SprintStartDate, ProductionDeadline, ReferenceDate. Limites inteiros nao negativos: MaxPreparationSprints, MaxImplementationSprints, MaxTestSprints, MaxTotalSprints opcional, MaxDevelopers. null significa desconhecido. |
| Constraints.UnboundedPhases | Array opcional PREPARATION, IMPLEMENTATION, TEST, sem duplicatas. Declara decisao humana de nao impor teto adicional as fases listadas, cujo Max...Sprints deve ser null. Ausente/vazio conserva null como desconhecido; teto numerico e fase sem teto simultaneos sao erro. MaxTotalSprints=null ja significa ausencia de teto total adicional. |
| Estimation.AiDeveloperReductionPercent | Percentual de reducao do esforco de Dev informado pelo humano, de 0 a 100; null significa nao informado. Sem padrao de produtividade. So afeta atividades AiAssisted=true. |
| Team | WorkWeek usa numeros de DayOfWeek (domingo=0, segunda=1, sabado=6); Holidays datas ISO. RolesAreDistinct confirma que devs, arquiteto e DevOps sao pessoas distintas; acumulo de papeis exige redistribuicao explicita, nunca capacidade duplicada. |
| Team.Staffing | Uma entrada por Sprint (numero a partir de 1), Developers ate o teto, DeveloperAvailability/ArchitectAvailability/DevOpsAvailability de 0 a 1, ReservePercent de 0 a 100, AbsenceDays por Dev/Architect/DevOps em dias-pessoa. Sem entrada nao se presume equipe disponivel. Arquiteto e DevOps limitados a uma pessoa cada. |
| Baseline | Id B0, Known fornecido pelo preparo, Issues por Project/Id com Source local associado. Antes da formacao, Issues coincide com todas as categorias selecionadas nos registros correntes. Resultado com Known=true fixa identidades e denominador; Known=false permite completar a base no mesmo cenario. Relocalizar Source preserva Project/Id. |
| Baseline.Accepted | Source, Id, Evidence e AcceptedBy comprovados. Nao inferir aceite de status ou desaparecimento no MTA. |
| Changes | New, Reopened e Excluded separados; nao reduzem N0. Toda issue atual do recorte deve constar em B0 ou New. Inclusoes ja validadas permanecem em New mesmo se desaparecerem do registro; retirada exige Excluded explicita. Mudancas exigem Reason e Evidence humanas. |
| Work | Macroatividades com identidades unicas, fases, dependencias e estimativas conforme abaixo. |
| EvidenceReview | Reviewed booleano e Reason descrevem conferencia das fontes atuais e premissas usadas para estimar. Ausencia dessa conferencia deixa NAO_AVALIAVEL. Nao e selo ou autorizacao. |
| Assumptions / Decisions | Premissas e decisoes legiveis, com origem humana ou proposta identificada. |

Work.Issues, Accepted, Reopened e Excluded referenciam somente B0 ou New, sem
duplicatas em cada lista. Work nao aloca issues excluidas. New respeita as
categorias escolhidas; optional exige ScopeDecision, inclusive apos formar B0.
Baseline.Known, Team.RolesAreDistinct e EvidenceReview.Reviewed aceitam booleanos
reais ou null, nunca strings/numeros convertidos implicitamente.

Cada Work usa Id, Title, Phase (PREPARATION, IMPLEMENTATION, TEST, DEPLOYMENT),
Priority numerica (menor primeiro), DependsOn (IDs de Work), Issues (Source/Id),
Effort, EstimateSource, Confidence, Assumptions, NotBefore, Deadline, Acceptance,
References (caminhos/URLs em strings) e Remaining. Effort possui Dev, Architect e
DevOps, cada um com Min, Reference, Max em dias-pessoa: 0 <= Min <= Reference <=
Max. Zero exige certeza de ausencia de trabalho; null deixa lacuna. Remaining=true
declara estimativa de trabalho restante; conclusao comprovada permanece nas
evidencias. Testes de corretiva entram na propria atividade; TEST e campanha
integrada/homologacao. A janela de implantacao usa NotBefore/Deadline da atividade
DEPLOYMENT. O motor nao converte pontos MTA ou numero de issues em produtividade.

Work.AllocationMode aceita ASAP (padrao legado, primeira capacidade disponivel)
ou DISTRIBUTED, que exige NotBefore e Deadline. DISTRIBUTED reparte o esforco
restante pelos dias uteis ainda disponiveis ate o Deadline da atividade, sem
comprimir essa janela pelo prazo de producao ou limite total. A parcela diaria
respeita capacidade, prioridades, papeis proporcionais, dependencias e fases;
saldo adiado disputa os proximos dias da janela. Nao garante ocupacao uniforme
quando ha bloqueios. Acompanhamento recorrente exige janela real e esse modo
explicito; nao e inferido pelo titulo. Todo trabalho requerido ainda precisa
concluir ate a producao; suporte simultaneo nao exige dependencia artificial.

Work.AiAssisted e booleano (ausente/null/false nao aplica ganho). Effort.Dev
guarda SEMPRE a faixa restante antes do desconto de IA. Para AiAssisted=true,
o motor usa `Effort.Dev * (1 - AiDeveloperReductionPercent / 100)` nas tres faixas,
uma unica vez, sem mutar a entrada. Percentual ausente deixa lacuna identificada
por atividade; esforco desconhecido continua null mesmo com 100%. Arq/DevOps,
calendario, disponibilidade, prazos e dependencias nao recebem desconto.
Estimativas que ja incluam ganho exigem conciliar sua base antes de aplicar o
parametro, sem inferir um valor original. Registre hipotese e origem humana em
Decisions/Assumptions/EstimateSource; nao e economia realizada. Numa revisao,
informe restante antes do ganho; sprints encerradas nao sao recalculadas.

Exemplo de estimativa de **fixture**, sem servir de padrao de produtividade:

```json
{
  "Id": "preparar-jboss",
  "Title": "Preparar configuracao JBoss e subsistemas",
  "Phase": "PREPARATION",
  "Priority": 1,
  "DependsOn": [],
  "Issues": [],
  "Effort": {
    "Dev": {"Min": 1, "Reference": 2, "Max": 3},
    "Architect": {"Min": 1, "Reference": 1, "Max": 2},
    "DevOps": {"Min": 1, "Reference": 2, "Max": 3}
  },
  "EstimateSource": "Exemplo didatico; substituir por evidencia examinada",
  "Confidence": "baixa",
  "Assumptions": ["Equipe com pessoas distintas por papel"],
  "NotBefore": null,
  "Deadline": null,
  "Acceptance": "Configuracao revisada e ambiente validado",
  "References": [],
  "Remaining": true
}
```

## Saidas e revisao

O cenario ocupa `atual/sprints/<cenario>/` no mestre: `contexto.json` informa
participantes e caminhos; `planejamento-sprints.json` guarda premissas/estimativas
editaveis; `plano.md` apresenta o cronograma e conserva narrativa humana fora de
sprints:inicio/fim. Os indices dos participantes apontam ao mesmo plano mestre.
Retirar o mestre exige conciliar sua transferencia ou escolher outro cenario;
nao se cria outro mestre implicitamente.

O executor nao escreve `resultado.json` nem o bloco calculado. A tarefa publica
plano e resultado juntos. O resultado guarda somente o ultimo calculo: Simulation,
B0 fixada quando conhecida, inclusoes acumuladas e datas de inicio/referencia.
Simulation fica somente nesse resultado, sem copia integral das entradas.
EstimateEvidence informa caminho/status das referencias examinadas; hashes e
textos usados para detectar edicao concorrente permanecem em memoria.
Caminhos inexistentes/invalidos usados para estimar mantem NAO_AVALIAVEL.
Referencias externas permanecem referencias: sua presenca nao prova leitura.
Diretorios nao sao arquivos de evidencia; use os arquivos efetivamente lidos.

Simulation.EffortAdjustments explicita Id, ReductionPercent, OriginalDev e
EffectiveDev (Min/Reference/Max). O Markdown mostra essas faixas e sua diferenca.
Simulation.Sprints.Activities registra DailyAllocations (Date e Effort por papel),
FirstWorkDate, LastWorkDate e CompletionDate (null enquanto parcial), com Completed.
Marcos de esforco zero podem concluir sem carga diaria. Gantt usa apenas dias
com carga, separados nas lacunas de calendario, e marco de conclusao prevista;
fim da barra e exclusivo. Historico legado sem DailyAllocations permanece na
matriz, sem barras diarias inventadas. A tabela compara janelas humanas e
conclusoes; trabalho nao alocado permanece no escopo, sem equivaler a exclusao.

O template editorial e aplicado no preparo inicial; revisoes conservam a narrativa
anterior fora do bloco calculado. O executor concilia textos obsoletos na nova
revisao, separando decisoes, propostas e pendencias. Nao duplica viabilidade,
previsoes ou percentuais fora do bloco; assim o calculo nao deixa estados
editoriais contraditorios por atualizacao parcial.

PromptPath e ReviewPromptPath ficam nos destinos correntes. Preparar atualiza
orientacoes/fontes gerenciadas e preserva notas externas a esses blocos. Nao ha
preparo.json, selo, copia de contrato imutavel ou cadeia de revisoes. O prompt de
resultado analisa em somente leitura, sem conceder GO ou substituir a tarefa.
Os prompts oferecem links ao contrato/ADR/guia atuais, indice geral e fontes
por participante, incluindo codigo, POM, registro, fichas e anexos disponiveis.
Fontes indisponiveis aparecem como lacunas; o codigo local continua navegavel
mesmo sem registro/indice. O contrato corrente e a ADR prevalecem sobre exemplos
historicos dos guias; seus arquivos sao referenciados, sem copias operacionais.
Repetir a validacao com as mesmas entradas produz os mesmos numeros e documentos.
Preparar ou falhar na validacao conserva o ultimo resultado. O plano o identifica
como ultimo calculo: sua existencia nao valida edicoes posteriores nas entradas.

Revisar atualiza o mesmo conjunto corrente; B0 formada e as inclusoes acumuladas
vem do ultimo resultado calculado. Nao dependem de revisoes anteriores ou datas
de arquivos. Leitura e publicacao detectam alteracoes durante a operacao; o
condutor confere mudancas de conteudo entre operacoes sem recibos de hashes.
Inicio publicado permanece fixo; ReferenceDate nao retrocede. Sprints encerradas
mantem sua previsao historica; a nova previsao usa capacidade e esforco restantes.
Limites de fase incluem sprints ja consumidas, inclusive a sprint em andamento;
ConsumedPhaseSprints preserva esse consumo no resultado corrente. Min/Max
variam o esforco futuro sobre o mesmo passado Reference publicado. Historico
anterior sem FirstWorkDate conta conservadoramente a fase da sprint iniciada.
Remaining nao e descontado novamente do esforco historico. Marcos com esforco
zero nao consomem uma sprint de fase, mas respeitam precedencias e janelas.
Alteracao explicita de projetos exige motivo; novas issues ficam em Changes.New
quando B0 ja foi formada. Retomar nao inclui projetos novos automaticamente.

Validacao estrutural pode resultar em NAO_AVALIAVEL: nao confundir VALIDATED com
CABE_NAS_PREMISSAS. Outras classificacoes: EM_RISCO e NAO_CABE. Um mutex transitorio
comum serializa descoberta, preparo, validacao e indices de sprints; a publicacao
recuperavel do projeto troca o conjunto completo. Falha conserva/restaura o ultimo
resultado e seu Markdown. Indices podem ser reconstruidos sem recalcular o mestre.

ProductionDeadline e obrigatorio para comprovar viabilidade de producao, mesmo
com MaxTotalSprints. Sem inicio, um MaxTotalSprints explicito permite rascunho
relativo Sprint 1..N, sem datas ou capacidade presumidas. Sem prazo ou outra
entrada essencial, a saida nao afirma producao prevista.

A tarefa valida deterministicamente o retorno do agente contra os prazos,
janelas, capacidade, dependencias e limites informados. Unscheduled apresenta
Reason calculada, RemainingEffort por papel e BlockingDependencies para trabalho
nao alocado. Os motivos identificam horizonte, fase esgotada e restricoes
encontradas; a simulacao gulosa nao prova impossibilidade de toda alternativa.
Markdown reproduz os motivos do JSON, compara limites e consumo historico e
mostra movimentos e composicao atual do escopo sem alterar B0. Justificativa
textual do agente nao substitui a validacao nem autoriza aumentar o prazo.

Premissas e narrativa sao editadas no lugar; o bloco calculado e regenerado pela
tarefa. Preserve contribuicoes humanas fora de seus marcadores. Simulation nas
entradas editaveis e recusada; resultado nao e uma area de edicao humana.
Controles transitorios detectam edicoes concorrentes, sem funcionarem como
controle de acesso ou assinatura digital. O plano e uma proposta de cronograma,
sem GO de corretiva, aceite de migracao ou dispensa de politicas corporativas.

## Regras do cronograma

Regras herdadas da feature MACRO-01 (08-09/10/2026). Os campos acima prevalecem
sobre nomes ilustrativos; destinos e continuidade seguem a ADR-0009, sem
PlanningId, RevisionId, Previous ou ponteiros de revisao.

### Calendario, fases e prazo

Sprints de 14 dias corridos, datas inclusivas:
`inicio(n) = inicio(1) + 14 x (n - 1)` e `fim(n) = inicio(n) + 13`. Sprints
consecutivas nao se sobrepoem nem deixam lacunas. Feriados reduzem capacidade e
nao deslocam a cadencia. Prazo anterior ao inicio e rejeitado.

Os maximos por fase sao tetos, nao duracao obrigatoria nem parcelas somaveis.
Uma sprint pode conter preparacao e implementacao se houver capacidade e
dependencias satisfeitas; cada sprint com esforco de uma fase conta uma vez para
o limite dessa fase, mesmo com varios projetos. Testes de corretiva acompanham a
implementacao; MaxTestSprints controla a campanha integrada/homologacao. A
migracao de configuracao JBoss tem fase e dependencias explicitas; trabalho
compartilhado entre aplicacoes conta uma vez, com referencia aos beneficiarios.

Se o prazo de producao cair no meio de uma sprint, a sprint mantem 14 dias e o
corte aparece: somente os dias ate a implantacao contam para entregas
necessarias a producao, sem capacidade integral nem sprint menor inventada. Com
MaxTotalSprints, toda atividade, inclusive implantacao, termina na intersecao
desse horizonte com ProductionDeadline. Janela entre a ultima sprint e o prazo
aparece com capacidade propria, nunca como trabalho escondido.

### Capacidade por papel

Unidade: dias-pessoa por papel. Outra unidade do projeto e preservada e exige
estimativa comparavel; pontos MTA ou story points nao viram dias.

```text
capacidade_bruta(papel, sprint) = soma da disponibilidade diaria das pessoas do papel
capacidade_liquida             = capacidade_bruta - reservas nao alocadas como atividade
carga(papel, sprint)           = soma do esforco restante alocado ao papel na sprint
restricao                      = carga <= capacidade_liquida, em cada papel e sprint
```

Exemplo aritmetico: 2 devs x 10 dias uteis x 80% = 16 dias-pessoa; 1 arquiteto a
50% = 5; 1 DevOps a 50% = 5. Sao tres capacidades separadas; a formula calcula
disponibilidade, nao produtividade. Ausencias sao descontadas uma vez. Reserva
nao esconde carga tecnica conhecida. Acumulo de papeis pela mesma pessoa registra
a restricao compartilhada, sem somar disponibilidades integrais. O teto de devs
nao significa equipe disponivel em todas as sprints; arquiteto ou DevOps nao
viram dev adicional sem alocacao explicita. Homologacao por area externa declara
responsavel e disponibilidade conhecida, sem inventar testadores.

### Estimar e distribuir

1. Reaproveitar estimativas comparaveis e estimar somente o trabalho restante.
2. Agrupar por objetivo tecnico, dependencias e entrega verificavel; mesma
   categoria/regra nao prova esforco igual nem autoriza lote unico entre projetos.
3. Propor faixa minima/referencia/maxima por papel, com fonte e hipotese, e
   testar a sensibilidade ao limite superior. Confianca e qualitativa.
4. Sem evidencia suficiente, marcar "a estimar" e indicar refinamento; nunca
   esforco zero nem reparticao igual de issues pelas sprints.
5. Dependencia no meio da sprint exige datas/ordem que comprovem paralelismo;
   sem isso, alocacao conservadora.
6. Issue maior que uma sprint e decomposta ou distribuida com continuidade
   explicita; so conta como concluida com os criterios completos atendidos.
7. Exibir escopo alocado, bloqueado, nao estimado e fora do horizonte, com motivo
   e o gargalo real, inclusive arquiteto ou DevOps.

Estados de elaboracao (RASCUNHO, PROPOSTA, REVISADO) e de viabilidade
(NAO_AVALIAVEL, CABE_NAS_PREMISSAS, EM_RISCO, NAO_CABE) sao distintos.
CABE_NAS_PREMISSAS exige esforco, dependencias, limites e capacidade compativeis
e nao representa compromisso aprovado.

### Percentuais, marcos e conclusao

B0 e o conjunto de issues unicas do escopo inicial e `N0 = |B0|`, com fonte,
categoria, situacao inicial e data de captura. Mesma regra em projetos distintos
nao e uma unica issue; incidentes, regras, examinadas e concluidas nao se misturam.

```text
previsto_acumulado(s)  = 100 x issues de B0 previstas concluidas ate s / N0
realizado_acumulado(t) = 100 x issues de B0 comprovadamente concluidas em t / N0
```

Cada issue conta uma vez, na conclusao prevista ou comprovada, sem credito
fracionario. Meta pedida pelo usuario ("20% na Sprint 1") e verificada quanto a
viabilidade. N0 zero ou desconhecido apresenta N/A. Conclusao comprovada depende
de evidencias e aceite do [fluxo de migracao](fluxo-migracao.md); alocacao,
documento, exame ou desaparecimento do achado nao bastam. "100% das issues" nao
encerra configuracao, testes, homologacao e implantacao. Novas issues,
reaberturas e exclusoes aparecem separadas, sem alterar N0; falso positivo nao
vira corretiva concluida.

Cada sprint tem um marco principal observavel (por exemplo, "20 de 100 issues
concluidas com aceite e configuracao EAP validada em DES"); previsao de marco nao
e marco atingido.

### Template do plano

O [template](../modelos/planejamento-sprints.template.md) e a fonte unica do
contrato editorial: cerca de 5-8 macroatividades, uma linha por sprint e um
paragrafo de objetivo de HU por sprint, referenciando detalhes em vez de
transcreve-los. Numeros e datas vem dos dados validados; o agente preenche
narrativa e objetivos. IDs corporativos de HU so aparecem se fornecidos; usar
rotulo local como `HU proposta S1`. HU nao pressupoe cadastro em sistema externo.
