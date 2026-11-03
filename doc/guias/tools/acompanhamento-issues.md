# Acompanhar andamento das issues

Abra `.harness/indices/projetos.md`, o `indice.md` do projeto ou o fim de
`migracao.md`. Os tres mostram quantidades e percentuais do Andamento registrado,
com a mesma [legenda](../../modelos/legenda-andamento.template.md). O registro e
a fonte do estado; a ficha sustenta o achado, o recorte e as evidencias.

## Interpretar e conferir

Cada percentual divide a quantidade no estado pelo total corrente registrado
da origem/categoria. Exemplo: 6 EM ANALISE, 9 IMPLEMENTADA e 3 CONCLUIDA em 18
issues manuais representam 33,33%, 50,00% e 16,67%. Fechamento e apenas 3/18;
nao existe media de progresso entre etapas. No workspace, somam-se quantidades
e denominadores dos projetos, nunca seus percentuais.

Use os IDs de cada grupo para localizar suas linhas e seguir Ficha/evidencias.
ADIAR, FORA DO ESCOPO e NAO REENCONTRADA continuam no denominador e aparecem
separados, com sobreposicao possivel. Registro indisponivel nao vale zero; o
consolidado informa os projetos lidos. Estado desconhecido/vazio e lacuna a
esclarecer, sem traducao automatica. Categoria manual do MTA tem origem distinta.
Contagem MTA e contagem do registro podem diferir; InitialTotal da priorizacao
nao muda com o resumo. Data do calculo nao comprova atualidade do codigo.

## Registrar o trabalho e o aceite

1. No exame, documente achados, aplicabilidade, fontes e lacunas na ficha. Em
   planejamento/reconciliacao autorizados, registre EM ANALISE enquanto faltar
   exame, ANALISADA quando documentado e PLANEJADA com proposta/tarefas prontas.
   Cadastro, revisao isolada da ficha e priorizacao nao promovem Andamento.
2. Com GO vigente, registre EM IMPLEMENTACAO ao iniciar a corretiva e IMPLEMENTADA
   ao aplica-la no Source local. Identifique issue, fase e recorte nas tarefas e
   na secao de acompanhamento da ficha, preservando achado e evidencias ANTES.
3. Ao receber resultados, o agente principal confere criterios, origem/ambiente,
   resultado observado, cobertura e pendencias. Registra-os na ficha/tarefas e
   em migracao.md; pode usar revisar-resultado para essa escrita documental.
   Falhas e testes pendentes impedem VERIFICADA. Build verde isolado nao basta.
4. VERIFICADA exige criterios tecnicos aplicaveis atendidos. Para CONCLUIDA,
   registre a declaracao humana de aceite e seu alcance na secao 9 do plano,
   referencie-a nas tarefas/registro e confira todo o escopo aplicavel da issue.
   Recorte aceito com trabalho restante nao fecha a issue inteira. Reabertura
   documenta motivo/alcance e preserva o aceite anterior.
5. Recalcule os resumos depois da escrita autorizada. Helpers continuam leitores;
   GO, aceite, operacoes manuais, integracao e continuidade permanecem separados.

## Recalcular sem selecionar outro MTA

O agente principal usa a API abaixo depois de publicar documentos com Expected
(texto/bytes lidos). Execute a partir do harness; `$context` deve ser o contexto
ja conhecido do workspace completo: Root e Projects com os caminhos Source em
`path`. Nao construa um escopo reduzido nem adivinhe pastas por recencia.

```powershell
Import-Module .\scripts\HarnessProject.psm1 -DisableNameChecking
$resumo = Update-HarnessIssueProgress -Context $context
$resumo.Synchronized
$resumo.Warnings
```

A API so le registros correntes e atualiza blocos/contadores derivados, preservando
associacao e fontes MTA. Nao executa analises nem muda estados. Registro e indice
do projeto usam publicacao protegida; dashboard e uma publicacao separada.
`Synchronized=false` exige informar os destinos/avisos pendentes, preservando
o que ja foi publicado. Conflito preserva a contribuicao concorrente; releia
antes de repetir. Contexto ausente ou escopo diferente do dashboard nao autoriza
declarar os tres destinos sincronizados.

Register-HarnessManualIssue e Complete-HarnessReconciliation atualizam os resumos
locais na mesma publicacao. Aceitam `-Context $context` para recalcular tambem o
workspace depois da publicacao; confira DashboardPending e Warnings/Diagnostics.
Sem Context, o dashboard fica explicitamente pendente. Nao passe o contexto.json
de planejamento como se fosse o contexto do workspace: sao objetos diferentes.

Apos edicao manual, use **Workspace: atualizar indice dos projetos**. Essa tarefa
mantem seu fluxo normal de descoberta MTA e reconstrucao; o recalculo documental
acima nao seleciona outro diagnostico. Nao ha tarefa nova nem watcher. Indice
antigo, por si so, nao exige reconciliacao, novo MTA ou proximo lote.

## Orientar a proxima acao

IMPLEMENTADA pede verificacoes concretas do plano; VERIFICADA pede aceite humano;
CONCLUIDA pede conferir alcance e pedido de continuidade antes de outro lote.
Resumo antigo pede reconstruir derivados; evidencia nova ainda nao registrada
pede ao principal analisar/registrar; conflito entre estado, evidencia e decisao
pede reconciliacao. Falha de teste e cobertura parcial ficam visiveis. O helper
explica a fonte e encaminha uma acao no cliente atual, sem escrever nem conceder GO.
