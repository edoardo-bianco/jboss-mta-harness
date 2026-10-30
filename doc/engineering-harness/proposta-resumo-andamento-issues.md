# Proposta: resumo do andamento das issues

Data: 30/10/2026. Estado: organizacao aprovada pelo desenvolvedor, com complemento
de coerencia documental e orientacao; plano tecnico detalhado. Trabalho pausado
a pedido do desenvolvedor, com consolidacao documental e implementacao nao iniciada.
Este documento descreve uma evolucao do harness; nao altera o contrato vigente
nem o andamento de qualquer aplicacao. Plano e acompanhamento em
[tasks/plan.md](../../tasks/plan.md) e [tasks/todo.md](../../tasks/todo.md).

## Objetivo e decisoes confirmadas

Mostrar, por projeto e categoria, quantas issues estao em cada etapa do trabalho,
em numeros absolutos e percentuais. O desenvolvedor deve conseguir identificar
as corretivas que aguardam verificacoes e as que receberam aceite humano.

Escolhas confirmadas pelo desenvolvedor nesta conversa:

- Acrescentar EM ANALISE, EM IMPLEMENTACAO e CONCLUIDA aos cinco estados atuais.
- CONCLUIDA exige verificacoes e aceite humano explicito.
- Usar todas as issues registradas da categoria como denominador, inclusive
  adiadas, fora do escopo e nao reencontradas; essas condicoes nao sao conclusao.
- Permitir que o agente principal registre resultados comprovados na ficha,
  nas tarefas e em migracao.md, atualizando os resumos ao revisar evidencias.

O desenvolvedor aprovou a apresentacao, a regra de cobertura parcial e a forma
de atualizacao para detalhar a implementacao. Acrescentou como requisito deixar
README, guia do desenvolvedor, explicacoes/legendas de todos os indicadores e
agentes de orientacao coerentes com o processo de acompanhamento. Essa coerencia
integra o aceite da funcionalidade. O plano tecnico esta em tasks/plan.md;
nenhum registro real deve ser modificado como parte da implementacao do harness.

## Fontes e comportamento existente

O [modelo do registro](../modelos/migracao.template.md) tem oito colunas.
Decisao, Andamento e Presenca sao campos distintos. A
[legenda atual](../modelos/orientacao-registro.template.md) define NAO ANALISADA,
ANALISADA, PLANEJADA, IMPLEMENTADA e VERIFICADA. O
[modelo da ficha](../modelos/ficha-issue.template.md) remete decisao/andamento ao
registro; criar ou preencher uma ficha nao muda esse campo automaticamente.

[HarnessProjectDocuments.ps1](../../scripts/HarnessProjectDocuments.ps1) le as
linhas do registro e publica documentos do projeto. Hoje conta cadastro/presenca,
sem agrupar andamento. [HarnessProjectIndex.psm1](../../scripts/HarnessProjectIndex.psm1)
apresenta totais MTA e manuais e usa os modelos dos indices.

O [prompt de implementacao](../../.github/prompts/implementar-lote.prompt.md)
permite ao condutor registrar andamento/evidencias em MigrationPath explicito.
O [prompt de revisao do resultado](../../.github/prompts/revisar-resultado.prompt.md)
atual somente le e orienta, e proibe escrever. A permissao documental confirmada
acima exige alterar expressamente esse prompt e o
[contrato](../contratos/fluxo-migracao.md), preservando os helpers leitores.

## Significado proposto dos estados

| Andamento | Condicao para registrar |
| --- | --- |
| NAO ANALISADA | Ainda sem analise registrada no fluxo da migracao. |
| EM ANALISE | Exame efetivamente iniciado, com achados ou lacunas registrados; analise ainda incompleta. |
| ANALISADA | Analise documentada, com aplicabilidade, alcance e limites; proposta ainda nao concluida. |
| PLANEJADA | Proposta e tarefas prontas para o recorte; o GO continua sendo uma declaracao separada. |
| EM IMPLEMENTACAO | Corretiva autorizada iniciada; ha trabalho de implementacao por concluir. |
| IMPLEMENTADA | Corretiva aplicada no codigo local no recorte declarado; verificacoes necessarias ainda pendentes. |
| VERIFICADA | Criterios tecnicos aplicaveis atendidos com evidencias; aceite humano ainda pendente. |
| CONCLUIDA | Verificacoes atendidas e aceite humano explicito do resultado/escopo, referenciado no registro. |

Uma issue ocupa apenas um estado no resumo. Iniciar uma Run Task, preparar um
prompt, criar uma ficha, receber codigo ou obter build verde nao promove estado.
AGUARDANDO INTEGRACAO permanece na observacao quando a corretiva nao esta no
Source local. Falha de verificacao deve ficar explicita nas evidencias e no
resumo de pendencias, sem promover a issue a VERIFICADA.

Cobertura parcial exige observacao e referencia ao recorte/fase. Implementar ou
aceitar um recorte nao fecha automaticamente a issue inteira. Antes de CONCLUIDA,
o condutor confere se todo o escopo aplicavel da issue foi atendido; se restar
trabalho, registra a cobertura e a etapa ainda pendente. Isso precisa ficar
explicito nas instrucoes comuns aos tres clientes.

ADIAR e FORA DO ESCOPO permanecem decisoes. NAO REENCONTRADA permanece presenca.
Nao somar esses indicadores como se fossem etapas adicionais, nem conta-los como
corretivas concluidas. GO, aceite e conclusao de reconciliacao tambem nao sao
estados intercambiaveis da issue. Resultado reaberto exige registrar motivo e
alcance da revisao, preservando o aceite anterior.

## Contagem e percentuais

Fonte do andamento: linhas do bloco de issues de migracao.md, identificadas por
Project/Id. A ficha sustenta o estado com analise e evidencias; nao se torna uma
segunda fonte editavel de status. O gerador nao interpreta prosa para inferir
que uma implementacao ou um teste aconteceu.

Para cada projeto/categoria: percentual = quantidade no estado / total de issues
registradas daquela categoria * 100. Exibir quantidade e percentual com duas
casas, sem ponderar por ocorrencias, tarefas, arquivos ou esforco. O percentual
de fechamento e CONCLUIDA / total; nao criar uma media de progresso entre etapas.
O denominador e corrente e pode crescer com novos registros. A base InitialTotal
da priorizacao continua fixa ate Recreate explicito.

A mesma regra em dois projetos conta duas issues. No consolidado do workspace,
somar quantidades e denominadores; nao fazer media dos percentuais dos projetos.
Manuais humanas e categoria MTA homonima continuam distintas, como no indice
atual. Manter os totais do diagnostico MTA separados dos totais do registro:
issues nao reencontradas continuam no acompanhamento do trabalho.

Estado vazio/desconhecido aparece como lacuna de classificacao, com quantidade
e referencia as linhas, sem converter para NAO ANALISADA ou CONCLUIDA. Continua
no denominador quando a linha puder ser lida com identidade valida. Registro
ausente, invalido ou duplicado gera indisponibilidade/aviso, nunca zero inventado.
Categoria conhecida com total zero mostra quantidade zero e percentual sem base
(traco). Consolidacao parcial informa quais projetos foram lidos. Arredondamentos
podem fazer a soma dos percentuais diferir ligeiramente de 100%.

Os contadores descrevem o andamento registrado. A conferencia semantica das
evidencias e do aceite pertence ao condutor; existencia de link ou arquivo nao
constitui prova automatica. Divergencias encontradas pedem revisao documentada.

## Apresentacao proposta

Usar um calculo comum e tres apresentacoes derivadas:

| Local | Apresentacao |
| --- | --- |
| Fim de migracao.md | Bloco gerenciado de resumo por categoria/estado, com quantidade, percentual, total da categoria e limites. Preservar notas humanas fora do bloco. |
| Inicio de indice.md do projeto | Mesmo resumo, antes dos links de trabalho/evidencias, com acesso ao registro e as referencias das issues. |
| Dashboard .harness/indices/projetos.md | Coluna compacta de andamento por categoria na linha do projeto; quadro consolidado por categoria/estado abaixo da tabela de projetos. |

No dashboard, mostrar somente estados com quantidade positiva, acompanhados do
total e de um link ao detalhamento. No projeto e no fim do registro, apresentar
os oito estados em ordem de trabalho. Decisoes de adiamento/exclusao e presenca
nao reencontrada aparecem como indicadores separados, com aviso de sobreposicao.
Informar quando o resumo foi calculado; a data nao comprova atualidade do codigo.

Exemplo ilustrativo, sem representar as contagens atuais do workspace:

| Categoria | Total | Em analise | Implementadas: verificar | Concluidas |
| --- | --- | --- | --- | --- |
| manual | 18 | 6 (33,33%) | 9 (50,00%) | 3 (16,67%) |

Os demais estados teriam zero nesse exemplo. Cada valor permite chegar ao
registro e identificar as issues que compoem o grupo; nao basta um numero sem
rastreabilidade. O layout final deve ser conferido no preview Markdown usado
pelo desenvolvedor, especialmente na tabela geral com varias categorias.

## Quando a ficha e o registro mudam

1. No exame efetivo, o executor registra achados/fontes/lacunas na ficha.
   Nas etapas autorizadas a escrever o registro, atualiza o Andamento conforme
   o trabalho comprovado. A priorizacao isolada continua sem alterar migracao.md;
   sua ficha alimenta o planejamento/reconciliacao, que confere o estado.
2. Na implementacao, o condutor registra o que foi aplicado e o recorte nas
   tarefas, vincula a evidencia na ficha e atualiza a linha da issue.
3. Ao receber resultados de build/testes/deploy, o agente principal confere os
   criterios e registra resultado observado, origem/ambiente, cobertura e
   pendencias. Pode atualizar ficha, tarefas, registro e resumos nos destinos
   existentes, sem executar operacoes externas por causa dessa permissao.
4. No aceite humano explicito, registra a declaracao e seu alcance no documento
   do lote, referencia-a no registro e marca somente as issues abrangidas como
   CONCLUIDA, apos conferir a cobertura aplicavel.
5. Depois de uma atualizacao documental autorizada, recalcula os resumos pelo
   mesmo componente. Atualizacao apenas de links/formatacao nao promove estado.
   Edicao manual direta exige executar Workspace: atualizar indice dos projetos
   para reconstruir os derivados; nao propor observador automatico de arquivos.

Proposta para a ficha: acrescentar uma secao de acompanhamento com etapa/recorte,
resultado observado, evidencia, pendencia e referencia ao aceite quando existir.
Preservar o achado original e as evidencias ANTES. Nao duplicar o plano inteiro
nem manter outro campo autoritativo de Andamento na ficha.

A atualizacao automatica dos resumos apos escrita deve usar o registro publicado,
sem selecionar novo MTA ou reconciliar decisoes como efeito colateral. A Run Task
existente continua podendo reconstruir tudo conforme seu contrato. Reutilizar
publicacao protegida por projeto e preservar edicao concorrente. Falha ao
atualizar o dashboard deve ser informada como resumo pendente; nao declarar os
tres destinos sincronizados quando somente o projeto foi publicado.

## Areas afetadas e convencoes

PowerShell 5.1 e Markdown, reutilizando as APIs e os modelos atuais, sem nova
dependencia ou Run Task. O codigo comum usa funcoes Verb-Noun e objetos de dados,
como o leitor existente:

```powershell
$rows=@(Read-ProjectDecisionRows $Text)
```

Modelos previstos: indice-projetos, indice-projeto, migracao,
orientacao-registro e ficha-issue em doc/modelos/. O gerador deve consumir esses
modelos tanto em novos documentos quanto na atualizacao dos existentes.
Scripts afetados incluem HarnessProjectDocuments.ps1, HarnessProjectIndex.psm1
e os caminhos de cadastro/publicacao/reconciliacao pertinentes. Conferir tambem
os consumidores que filtram Andamento para admitir EM ANALISE sem perder uma
retomada ou tornar corretiva implementada candidata nova.

Prompts e contrato devem explicitar os momentos de registro e a permissao
documental do principal na revisao de resultado, com procedimento comum para
Codex, Copilot e Claude Code. Helpers/revisores auxiliares continuam leitores.
O detalhamento tecnico e sua sequencia estao em tasks/plan.md e tasks/todo.md.

## Coerencia documental e orientacao exigidas

Requisito acrescentado pelo desenvolvedor apos aprovar a organizacao:

| Superficie | Conteudo exigido |
| --- | --- |
| README e guia do desenvolvedor | Onde acompanhar, tabela dos oito estados, formula/base dos percentuais, passagem entre ficha/registro/resumos e proxima acao. |
| Dashboard, indice do projeto e fim do registro | Mesma legenda completa dos estados e significados, base da contagem, data de calculo, limites e links de rastreabilidade. |
| Modelos e seus geradores | Legenda compartilhada incorporada tanto ao criar quanto ao atualizar os documentos; nenhum resumo sem explicacao. |
| Guias de planejamento, issues, priorizacao, workspace e tarefas | Atualizar o procedimento vigente e referencias, preservando a diferenca entre exame, escolha, implementacao, verificacao e aceite. |
| Contrato, instrucoes gerais e prompts | Remover contradicoes sobre a escrita documental do principal na revisao; manter limites de escopo, operacoes externas e helpers leitores. |
| Skill orientar-migracao, papeis e guia de orientacao | Ler o registro e as evidencias por tras do contador, explicar estado/percentual e encaminhar o passo correto no cliente atual. |
| Adaptadores Codex, Copilot e Claude Code | Consumir a mesma skill e legenda; conferir se alguma instrucao local contradiz o fluxo, sem ampliar ferramentas/permissoes. |

A legenda deve explicar tambem por que ADIAR/FORA DO ESCOPO e NAO REENCONTRADA
nao sao conclusao, por que VERIFICADA ainda aguarda aceite, como cobertura parcial
aparece e por que indisponibilidade nao e zero. Pode ser recolhida em um bloco
de detalhes para preservar a leitura compacta do dashboard, mas deve estar no
documento que publica os indicadores, e nao apenas em um link externo.

O orientador deve distinguir: resumo desatualizado pede reconstruir derivados;
evidencia nova ainda nao registrada pede ao principal analisar/registrar;
conflito real entre estado, evidencia e decisao pede reconciliacao. Nao orientar
novo lote, nova analise MTA ou reconciliacao integral apenas por indice antigo.
Em IMPLEMENTADA, orientar verificacoes concretas; em VERIFICADA, orientar aceite
humano; em CONCLUIDA, conferir alcance e pedido de continuidade antes de outro lote.
Ele nao altera status, executa a tarefa nem concede aceite por conta propria.

Documentacao historica e propostas antigas conservam seu contexto. Revisar
instrucoes correntes que os usuarios e agentes realmente consomem; nao fazer
substituicao global que altere o sentido de outros usos de CONCLUIDA, de revisao
somente leitura ou de status de ferramentas.

## Verificacao prevista e limites

Testes PowerShell em copia temporaria pelo runner existente. Comandos previstos,
a partir do checkout isolado da evolucao, apos adicionar novos arquivos ao Git:

```powershell
.\tests\Invoke-HarnessTests.ps1 -Test Test-ProjectIndexSummary.ps1,Test-ProjectIndexManual.ps1,Test-MigrationRegister.ps1,Test-OutputTemplates.ps1
git diff --check
```

Acrescentar cobertura de comportamento nas suites pertinentes: oito estados,
multiplas categorias/projetos, identidade sem duplicacao, percentuais e total
zero, estados desconhecidos, leitura parcial, preservacao de decisoes/aceites,
recorte parcial, repeticao sem acumular e concordancia dos tres resumos. Validar
publicacao/conflitos e os fluxos afetados com suites adicionais quando houver
mudanca nesses caminhos. Conferir o preview e os links dos documentos gerados.
Teste textual nao demonstra que agentes obedecem ao fluxo; esse limite permanece.

Sempre preservar as oito colunas, evidencias, notas humanas e identidades. Exigir
direcionamento para conflitos de estado, mudanca de escopo/aceite ou fechamento
sem sustentacao. Nao editar registros reais para demonstrar contadores, executar
corretivas, criar GO/aceite ou declarar resolucao pelo desaparecimento no MTA.

Aceite da funcionalidade: os tres resumos concordam com o mesmo registro, cada
total e rastreavel, lacunas ficam visiveis e o fluxo documental mantem andamento
e evidencias coerentes. README, guias, modelos, prompts e orientadores devem
ensinar o mesmo ciclo, e todo documento que publica indicadores inclui sua legenda.
Nesta etapa foram feitas apenas leitura, especificacao e planejamento;
nenhum script, modelo executavel ou registro de aplicacao foi alterado.

## Aprovacao e proxima etapa

Organizacao, cobertura parcial e atualizacao aprovadas em 30/10/2026, com o
complemento documental acima. O plano tecnico detalhado aguarda revisao para
iniciar a implementacao, sem repetir as escolhas funcionais ja aprovadas.

Pausa solicitada em 30/10/2026: consolidar esta especificacao e o plano/tarefas
na branch harness/resumo-andamento-issues. Na retomada, partir do checkpoint em
tasks/plan.md, preservar as decisoes confirmadas e revisar o plano tecnico antes
de iniciar A1. A pausa nao altera o escopo aprovado nem conclui a funcionalidade.
