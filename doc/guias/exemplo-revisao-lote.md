# Exemplo: revisar plano e to-do com evidencias

Roteiro para demonstrar a revisao documental de um lote existente, preservando
o historico. Usa `migracao-cache-antes` como exemplo. O resultado esperado e um
novo `plan.md` e `todo.md`, com feedback incorporado e **PROPOSTA - NAO APROVADA**.
Nao ha aplicacao de corretivas, GO ou aceite do resultado neste roteiro.

## Antes da demonstracao

Na maquina da apresentacao, confira o workspace local, os caminhos das ferramentas
e a disponibilidade do Copilot Local com `devsquad` e `devsquad.plan`.
Configuracao local, workspace gerado e `.harness/` **nao acompanham o clone/pull**.
Os IDs e caminhos da sua maquina sao os que valem; nao copie IDs deste exemplo.

Se ja houver build, rodada MTA pertinente e plano/to-do salvos nessa maquina,
comece no passo 1 abaixo. Nao limpe as execucoes nem repita build/MTA apenas
para mudar observacoes ou revisar os documentos.

Se houver somente o clone, prepare antes da apresentacao o
[workspace e o ciclo inicial](../../README.md#comecar): build Java 8, MTA,
**Planejamento: preparar contexto para Copilot > 1. Planejar lote**, sem anterior
para a primeira proposta, e execucao do prompt. Espere o agente gravar os dois
documentos. O preparo sozinho nao cria plan.md/to-do. Essa coleta inicial exige
tempo e ferramentas da maquina; nao e uma revisao pronta trazida pelo Git.

## 1. Abrir a proposta e identificar Previous

Execute **Planejamento: abrir plano e to-do** e escolha `migracao-cache-antes`.
Escolha a proposta pelo projeto, datas e **Solicitacao**. Confira o ID do lote e
o `RequestId` no cabecalho. No ensaio de origem, o lote foi `HIB-CACHE-001`.
Use esse nome abaixo somente se for o lote efetivamente salvo na sua proposta.

- `RequestId` identifica a proposta; **Solicitacao** no menu mostra esse valor.
- `RunId` identifica o MTA; o ID do lote identifica o trabalho preservado entre revisoes.
- **Planejado** e o horario de preparo do contexto, nao a ultima edicao do plano.
- Na proxima preparacao, escolha a opcao numerica da proposta que acabou de abrir.
  A task preenche `Previous.RequestId` automaticamente. Nao edite o recibo.

## 2. Salvar o feedback nos documentos atuais

No fim do `plan.md`, acrescente uma secao como esta. Informe a data real da sua
revisao e adapte os pontos ao conteudo observado; preserve edicoes existentes.

```markdown
## Observacoes do desenvolvedor - revisao pendente

Revisar o mesmo lote, sem GO e sem aplicar corretivas:

1. O teste agrega miss/hit depois de consultar duas regioes. Exigir
   verificacoes sequenciais: consulta padrao com miss=1/hit=0;
   consulta nomeada seguinte com totais miss=1/hit=1. Preservar
   cache desativado e contrato HTTP. Ajustar a afirmacao de cobertura.
2. Separar precondicoes tecnicas/baseline, GO, implementacao,
   verificacoes do artefato corrigido e aceite. Build/WAR/runtime
   da corretiva sao posteriores a implementacao autorizada.
3. Comparar a rota interna sugerida pelo MTA com
   Cache.evictDefaultQueryRegion(), justificando a escolha e
   mantendo compatibilidade nao comprovada como pendente.
4. Incorporar o resultado do build anterior como evidencia do estado
   ANTES; nao trata-lo como validacao da corretiva ou do EAP 7.4.

Atualizar todas as secoes afetadas do plano e do to-do, preservando
criterios de aceite, ID do lote e PROPOSTA - NAO APROVADA.
```

No `todo.md`, acrescente as tarefas documentais correspondentes:

```markdown
## Observacoes do desenvolvedor - revisao pendente

- [ ] Rever criterio sequencial por regiao e afirmacoes de cobertura.
- [ ] Separar precondicoes, GO, implementacao, verificacoes e aceite.
- [ ] Comparar as APIs candidatas e explicitar compatibilidade pendente.
- [ ] Incorporar o build ANTES com origem e limites, sem concluir
  tarefas de validacao da corretiva.
```

Salve ambos antes de preparar o contexto. Nao marque tarefas de implementacao
como concluidas por ter escrito o feedback. Depois de vincular esses arquivos
como Previous, preserve essa versao.

## 3. Criar e preencher as evidencias

Execute **Planejamento: criar pasta de evidencias** para o mesmo projeto.
Se uma pasta pertinente ja estiver preenchida, reabra seu LEIA-ME e reutilize-a.
A task cria a estrutura; a copia dos arquivos e manual.

Copie o `result.json` do build ANTES para a pasta criada com o nome
`build-antes-result.json`. Complete o ID do lote e o objetivo no LEIA-ME:

> Revisar a proposta com as observacoes do desenvolvedor e o resultado do build
> anterior a corretiva, mantendo pendentes as verificacoes do artefato corrigido.

Substitua a tabela vazia e a frase "Nenhum arquivo listado ainda" por uma linha
com os dados **reais** do seu arquivo. Abaixo esta um exemplo preenchido baseado
no ensaio de origem; data, RunId e versoes devem ser conferidos na sua coleta:

| Arquivo relativo | Origem e data de coleta (com fuso) | Ambiente e artefato/versao | O que ajuda a verificar / limitacoes |
| --- | --- | --- | --- |
| build-antes-result.json | Resultado da tarefa Aplicacao: build Maven (Java 8). Inicio em 2026-09-28 17:03:49 -03:00; RunId 3b692d6e86fa48a4a817dcbdfdc7efa1. | migracao-cache-antes, estado ANTES. Java 1.8.0_504; Maven 3.9.16; SettingsPath null; clean install. | Verificar se existe build anterior bem-sucedido sob Java 8. Registra SUCCEEDED/ExitCode 0. Nao comprova corretiva, Hibernate 5.3, WAR corrigido, runtime EAP 7.4 ou Sonar. Nao concede GO. |

O arquivo da primeira coluna deve existir na mesma pasta com esse nome exato.
A pergunta que a evidencia ajuda a responder fica na ultima coluna; nao precisa
de secao separada. Observacoes e limites podem complementar a tabela sem repetir
tudo. A data da coleta e a execucao original do build, nao o dia em que voce o copiou.
Preserve a data de organizacao da pasta em seu campo proprio. Nao gere hashes nem
copie logs brutos; o relatorio MTA ja sera referenciado pelo contexto.

## 4. Preparar o prompt de revisao

Execute **Planejamento: preparar contexto para Copilot**, da pasta `harness`:

1. Selecione o mesmo projeto.
2. Escolha **2. Revisar lote (/revisar-lote)**.
3. Selecione a rodada MTA pertinente. Enter usa a ultima elegivel mostrada;
   se nao for a desejada, use **h** para escolher no historico.
4. Escolha a **Solicitacao** correspondente ao RequestId do passo 1. Digite
   o numero da opcao. Previous e obrigatorio nesse modo; Enter nao inicia independente.
5. Cole o caminho completo do LEIA-ME preenchido no passo 3.

Confira no terminal: **Operacao: revisar-lote**, **Planejamento anterior vinculado**,
**Indice de evidencias** e o caminho do novo **revisar-lote.prompt.md**.
Uma nova solicitacao recebe outro RequestId; o lote e o historico continuam.

## 5. Executar e conferir a revisao

No `revisar-lote.prompt.md` aberto pela task, use **Executar Prompt** em nova
conversa **Copilot Local** com **devsquad**. Alternativamente, copie a chamada
`/revisar-lote` completa que o terminal ja preencheu com os dois caminhos.
Execute uma dessas alternativas; nao execute tambem `planejar-lotes`.
O arquivo `planejar-lotes.prompt.md` da nova pasta e somente o contexto-base
usado pelo revisor nesse percurso.

Aguarde a conclusao. Depois execute **Planejamento: abrir plano e to-do** e
selecione a nova solicitacao pelo ID mostrado no preparo. Confira:

- Mesmo projeto e lote; Previous aponta para a proposta com feedback.
- Cada observacao atendida ou justificada nos dois documentos, sem contradicoes
  entre resumo, premissas, tarefas e criterios de aceite.
- Evidencias citadas com seus limites; build ANTES nao conclui teste da corretiva.
- Requisitos preservados: neste lote, baseline Sonar antes das alteracoes e
  Quality Gate registrado e aprovado segundo a politica aplicavel.
- Documentos anteriores preservados e estado **PROPOSTA - NAO APROVADA**.

Para omissao na entrega recem-gerada, ainda nao usada como Previous de outra
solicitacao, peca na mesma conversa a correcao somente dos dois destinos atuais
e releitura integral. Nao precisa gerar outro contexto por esse ajuste.

## Encerrar a demonstracao

Mostre a proposta anterior, a revisada e o indice. Explique: "O feedback e as
evidencias produziram uma revisao rastreavel; a aplicacao ainda nao foi corrigida."
Precondicoes tecnicas e GO precedem a implementacao; verificacoes e aceite humano
do resultado vem depois. Nao limpe o historico para encerrar a apresentacao.

**Como prosseguir depois:** reunir versao/API do EAP, dependencias e baseline
Sonar; incorporar as evidencias ao mesmo lote; registrar GO para a proposta
concreta; solicitar implementacao separada; executar verificacoes; obter aceite
humano. O [percurso apos a revisao](harness-migracao-desenvolvedor.md#da-proposta-revisada-a-execucao-e-ao-aceite)
detalha cada etapa e distingue Run Tasks disponiveis de coletas/operacoes da equipe.

No ensaio de 29/09/2026 foram conferidos preparo, persistencia e ajustes dos
documentos, com mesma rodada MTA e proposta anterior preservada. A delegacao foi
relatada pelo operador. Uma chamada "Read memory" nao teve conteudo/efeito
verificavel; a limitacao ficou registrada, sem presumir conformidade integral.
Revisao com MTA novo, corretivas, validacao EAP/Sonar, GO e aceite **nao foram
demonstrados por esse ensaio**. O fluxo com nova rodada esta descrito no
[guia completo](harness-migracao-desenvolvedor.md#percurso-de-feedback-com-nova-rodada-mta).
