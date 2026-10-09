# Contrato executavel do planejamento por sprints

SchemaVersion=1, Purpose=sprint-planning. Requisitos e criterios de aceite:
[MACRO-01](../features/planejamento-macro-sprints.md). Uso pelo desenvolvedor:
[Run Task e prompt](../guias/tools/planejamento-sprints.md). O JSON preparado e
os templates WorkTemplate/StaffingTemplate em contexto.json fornecem a estrutura
para o executor; nao e necessario montar arquivos de entrada manualmente.

## Entradas do executor

| Campo | Contrato |
| --- | --- |
| PlanningId / RevisionId | Identidades imutaveis do contexto. |
| State | RASCUNHO, PROPOSTA ou REVISADO; nao significa GO. |
| ScopeCategories | mandatory; adicionar optional somente com ScopeDecision humana. |
| Constraints | Datas ISO YYYY-MM-DD: SprintStartDate, ProductionDeadline, ReferenceDate. Limites inteiros nao negativos: MaxPreparationSprints, MaxImplementationSprints, MaxTestSprints, MaxTotalSprints opcional, MaxDevelopers. null significa desconhecido. |
| Team | WorkWeek usa numeros de DayOfWeek (domingo=0, segunda=1, sabado=6); Holidays datas ISO. RolesAreDistinct confirma que devs, arquiteto e DevOps sao pessoas distintas; acumulo de papeis exige redistribuicao explicita, nunca capacidade duplicada. |
| Team.Staffing | Uma entrada por Sprint (numero a partir de 1), Developers ate o teto, DeveloperAvailability/ArchitectAvailability/DevOpsAvailability de 0 a 1, ReservePercent de 0 a 100, AbsenceDays por Dev/Architect/DevOps em dias-pessoa. Sem entrada nao se presume equipe disponivel. Arquiteto e DevOps limitados a uma pessoa cada. |
| Baseline | Id B0, Known fornecido pelo preparo, Issues por Source/Id. Antes da formacao, Issues coincide com todas as categorias selecionadas do contexto. BaselineFrozen=true na validacao fixa identidades e denominador; rascunho com Known=false pode completar a base numa revisao. |
| Baseline.Accepted | Source, Id, Evidence e AcceptedBy comprovados. Nao inferir aceite de status ou desaparecimento no MTA. |
| Changes | New, Reopened e Excluded separados; nao reduzem N0. Toda issue atual do recorte deve constar em B0 ou New. Inclusoes ja validadas permanecem em New mesmo se desaparecerem do registro; retirada exige Excluded explicita. Mudancas exigem Reason e Evidence humanas. |
| Work | Macroatividades com identidades unicas, fases, dependencias e estimativas conforme abaixo. |
| EvidenceReview | Reviewed booleano e Reason descrevem reexame das estimativas quando InputChanges apontar alteracoes. |
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

O executor nao escreve Simulation, EstimateEvidence, validacao.json, atual.json,
preparo.json ou o bloco Markdown entre sprints:inicio/fim. A tarefa calcula e
preserva narrativa fora do bloco. EstimateEvidence captura hashes das referencias
usadas para estimar; caminhos inexistentes/invalidos mantem NAO_AVALIAVEL.
Referencias externas permanecem referencias: sua presenca nao prova leitura.

Toda revisao preserva a anterior por Previous e lista InputChanges. A cadeia pode
conter rascunhos: B0 formada vem do ancestral validado, nao da data do arquivo.
Inicio publicado permanece fixo; ReferenceDate nao retrocede. Sprints encerradas
mantem sua previsao historica; a nova previsao usa capacidade e esforco restantes.
Limites de fase incluem sprints ja consumidas, inclusive a sprint em andamento;
ConsumedPhaseSprints preserva esse consumo entre revisoes sucessivas. Min/Max
variam o esforco futuro sobre o mesmo passado Reference publicado. Historico
anterior sem FirstWorkDate conta conservadoramente a fase da sprint iniciada.
Remaining nao e descontado novamente do esforco historico. Marcos com esforco
zero nao consomem uma sprint de fase, mas respeitam precedencias e janelas.
Alteracao explicita de projetos exige motivo; novas issues ficam em Changes.New
quando B0 ja foi formada. Retomar nao inclui projetos novos automaticamente.

Validacao estrutural pode resultar em NAO_AVALIAVEL: nao confundir VALIDATED com
CABE_NAS_PREMISSAS. Outras classificacoes: EM_RISCO e NAO_CABE. A publicacao usa
lock, confere hashes e atualiza o ponteiro somente apos gravar dados, Markdown e
validacao consistentes. Se falhar a troca do ponteiro, a mesma acao pode recuperar
a publicacao sem recalcular nem reescrever o historico validado.

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

Revisoes publicadas nao sao editadas no lugar. Se houver contribuicao manual,
preserve-a numa revisao com motivo. Campos calculados editados sao recusados,
sem sobrescrita silenciosa. Os hashes detectam inconsistencias; nao substituem
controle de acesso ou assinatura digital. O plano e uma proposta de cronograma,
sem GO de corretiva, aceite de migracao ou dispensa de politicas corporativas.
