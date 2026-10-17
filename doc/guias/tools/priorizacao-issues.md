---
html:
  embed_local_images: true
  embed_svg: true
  offline: true
---

# Priorizacao de issues: pre-planejamento entre projetos

[Voltar ao guia do desenvolvedor](../harness-migracao-desenvolvedor.md#4-conferir-o-registro-e-escolher-prioridades).

A priorizacao compara uma fatia de issues elegiveis entre os projetos do escopo
escolhido. Recomenda por risco, repetibilidade e alcance; voce escolhe o problema
a trabalhar. Cada examinada recebe ficha, inclusive quando nao ha recomendacao.

## Orientacao com o helper

No Codex, use `$orientar-migracao`; no Copilot, `migracao_helper`.

```text
Quero comparar as issues mandatory destes projetos antes de escolher um lote.
Confira a priorizacao corrente, sua cobertura e lacunas; oriente a proxima fatia.
```

O helper le registro, ranking e fichas; nao marca exame nem escreve resultados.
O executor do prompt ou o desenvolvedor realiza a analise com fontes e codigo.

## Configuracao

### Entradas e escopo

Use workspace salvo com os projetos Maven e a origem MTA associada a cada POM.
O indice geral em `.harness/indices/projetos.md` leva aos registros e conjuntos
correntes. Categoria e conjunto de participantes delimitam a cobertura.
`mandatory`, `optional`, `potential` e outras categorias recebidas permanecem
separadas. Fonte ausente fica como lacuna; a configuracao nao concede permissao
de leitura a um caminho que o cliente de IA bloqueia.

MCP e Node sao opcionais. O executor pode ler registro, contexto, relatorio MTA
e codigo diretamente. Se usar [consultas de issues](consultas-issues.md), respeite
paginacao/limites e cite o que examinou. Consultar nao registra exame ou decisao.

## Uso

### Uso manual pela Run Task

1. Execute **Planejamento: priorizar issues** e escolha a categoria.
2. Com cobertura existente, escolha **recriar** ou **progredir**. Recriar redefine
   a base/cobertura explicitamente e preserva fichas/notas; progredir exclui todas
   as examinadas do mesmo escopo/categoria, recomendadas ou nao.
3. Para uma nova fatia, informe **0,01% a 100,00%**, com ate duas casas decimais.
   O preparo pendente retoma a mesma quota e universo. Enter/q cancela.
4. Confira projetos, fontes, lacunas e os caminhos exibidos. A tarefa prepara
   contexto/prompt; ainda nao analisa nem escolhe candidatas.
5. No Codex, envie **Execute o prompt deste arquivo:** seguido do caminho real.
   No Copilot, abra o prompt e use **Executar Prompt** com perfil compativel.
   Tambem e possivel realizar o exame e preencher os mesmos documentos manualmente.
6. Revise ranking/fichas, suas fontes e motivos. O condutor atualiza o indice
   derivado ao concluir; o preparador confere o conjunto na proxima execucao.

Exemplo de CLI, na raiz do harness:

```powershell
.\scripts\preparar-priorizacao.ps1 -WorkspacePath .\meu-workspace.code-workspace -Category mandatory -Percentage 10 -Mode Recreate -NoOpen
```

Para progredir, use `-Mode Continue -Percentage 10`; para retomar a fatia pendente,
`-Mode Continue`. `-Scope` informa um nome funcional para o escopo quando
necessario. Nao e ID de execucao nem autoriza trocar silenciosamente participantes.
Automacao pode usar `-NoOpen -OutputFormat Json`, sem Interactive/EditorPath.
`EXHAUSTED` significa que nao restam novas elegiveis da base, sem apagar cobertura.

### Fatias e continuidade

O total inicial conta issues distintas por projeto + identificador funcional,
nao ocorrencias. A quota arredonda para cima e se limita ao disponivel.
Com 200 issues, cada 10% corresponde a 20; nao e 10% do restante.
Cada examinada aparece com posicao ou **SEM POSICAO**, motivo e link de ficha.
Mencao/sobreposicao nao comprova exame da outra issue.

A publicacao conserva **todas as examinadas**: 20 anteriores mais 15 novas
resultam em 35 no ranking/indice corrente. Todas as 35 sao excluidas do proximo
avanco. O bloco estruturado do ranking conserva cobertura; o desenvolvedor
escolhe pelo registro e nao precisa editar JSON para selecionar a issue.

| Fatia com base de 44 e percentual de 20% | Novas | Acumulado |
| --- | ---: | ---: |
| 1 | 9 | 9/44 |
| 2 | 9 | 18/44 |
| 3 | 9 | 27/44 |
| 4 | 9 | 36/44 |
| 5 | 8 | 44/44 |

Concluir exige a quota de novas examinadas alem das anteriores, com fichas e
motivos validos. Parcial permanece `IN_PROGRESS` no mesmo destino e conserva
universo/quota. Nao reduzir a quota para declarar conclusao.
100% examinadas nao significa todas corrigidas ou aceitas.

Um MTA novo pode atualizar elegibilidade, fontes e lacunas, preservando a base
inicial. Novas issues fora dela ficam em `OutsideBaseline` ate recriacao explicita.
Retirada da elegibilidade nao conta como exame nem resolucao. `EXHAUSTED` pode
ocorrer antes de 100% de cobertura; explique a diferenca. Outro escopo/categoria
mantem conjunto proprio; nao misture denominadores.

### Incidentes e fontes diretas

<a id="incidentes-preparados-para-leitura"></a>
<a id="acesso-a-rodada-externa"></a>

As fichas guardam o essencial e links ao relatorio MTA, codigo/POM, configuracao
e anexos. O detalhe e lido na origem; nao ha paginas de incidentes copiadas por
preparo. Origem externa exige acesso pelo cliente. Negativa/indisponibilidade
preserva o parcial e explicita a lacuna, sem fingir que o exame ocorreu.
Use a associacao do projeto para localizar o MTA; nao escolha outra origem
silenciosamente quando a selecionada estiver indisponivel.

### Como avaliar a lista

Cada posicao deve ser sustentada por amostras locais, risco, repetibilidade,
alcance e confianca. Volume de ocorrencias nao equivale ao numero de alteracoes.
Fonte nao lida e apenas referencia indicada. Potencial de automacao e hipotese
ate verificacao; a escolha e o GO continuam humanos.

### Indice automatico das priorizacoes

No projeto mestre, o conjunto fica em:

```text
atual/priorizacao/<categoria>/escopos/<escopo>/
  contexto.json
  priorizacao.md
  indice.md
  priorizar-issues.prompt.md
```

Cada participante guarda suas fichas em
`atual/priorizacao/<categoria>/issues/<issue>/ficha.md`. Os indices geral e dos
participantes apontam ao mesmo conjunto mestre, sem duplicar a cobertura.
Navegue pelos links; os nomes funcionais sao codificados quando necessario
para o Windows. O mestre padrao e o primeiro artifactId na ordenacao ordinal.

O indice e derivado, preserva notas fora dos blocos gerenciados e pode ser
reconstruido. Ele nao decide a proxima issue, nao comprova exame ou aceite e nao
revoga escolhas atuais no registro. Para compartilhar, copie a estrutura e as
referencias conforme o [guia entre colegas](compartilhamento-contextos.md).

<a id="continuar-rodadas-anteriores-a-esta-correcao"></a>
Dados antigos usam o [conversor separado](../../../tools/transicao/README.md)
com selecao explicita. O fluxo corrente nao depende deles para continuar.

### Planejar e implementar manualmente a partir da priorizacao

Cada issue examinada, **recomendada ou SEM POSICAO**, deve ter uma ficha que permita
seguir manualmente para investigacao, planejamento e implementacao, sem depender
de outro agente ou do historico do chat. **SEM POSICAO nao significa descartada.**
O relatorio comeca com uma tabela curta: **Prioridade | Projeto | Issue |
Avaliacao | Motivo / proxima acao**. Clique no titulo da issue para abrir a ficha.
A tabela resume; as evidencias e orientacoes ficam na ficha, sem repetir a analise.
Para levar ficha e anexos ao plano/to-do padronizados por issue, siga o
[dossie por issue e passagem entre colegas](planejamento-migracao.md#dossie-por-issue-e-passagem-entre-colegas).

#### Como ler a ficha

O titulo identifica o **projeto e o problema**, por exemplo, "Aplicacao exemplo -
Conferir o recurso de email no servidor". A ficha tem quatro blocos:

| Informacao | Conteudo esperado |
| --- | --- |
| O que encontramos | Comportamento atual/esperado, achado/recomendacao MTA, ponto no codigo com link e amostra/total. Separar fato, hipotese e nao verificado; ocorrencias MTA nao sao quantidade de alteracoes. |
| Por que recebeu essa avaliacao | Evidencia que sustenta a prioridade ou impede recomendar, risco, confianca, repetibilidade e potencial condicional. Dizer qual informacao falta e por que afeta a corretiva. |
| Como prosseguir | Inspecoes/comparacoes em ordem, resultado que confirma/afasta a hipotese e evidencia a guardar; direcao candidata, dependencias/consumidores, decisoes, verificacao observavel e reversao. Se a solucao ainda nao puder ser definida, indicar o que obter primeiro. |
| Referencias e registro | Links com titulo para documentacao do projeto/oficial (secao e versao pertinentes), registro e indice de evidencias. Distinguir fontes consultadas das apenas indicadas. ID completo para localizar a linha exata e link para a origem MTA do projeto. |

Voce navega por nomes e links. `Source` identifica o codigo local; o identificador
funcional da issue permite localizar a regra no registro e no MTA. Nao ha ID de
execucao ou hash a informar para continuar.
O relatorio usa nomes descritivos na leitura principal e informa a origem comum
uma vez por projeto. O bloco JSON ao final controla a continuidade automaticamente;
nao e necessario edita-lo para escolher uma issue.

**Exemplo ficticio de apresentacao, sem diagnostico de projeto real:**

| Prioridade | Projeto | Issue | Avaliacao | Motivo / proxima acao |
| --- | --- | --- | --- | --- |
| SEM POSICAO | Aplicacao exemplo | Conferir o recurso de email no servidor | Aplicabilidade a confirmar | Falta a configuracao do recurso no destino; conferir o nome usado pela aplicacao. |

**Aplicacao exemplo - Conferir o recurso de email no servidor**

- **O que encontramos:** neste exemplo, foi lida uma chamada JNDI em
  `ServicoEmail.enviar`, que procura `java:jboss/mail/expresso`. A regra alerta para
  nomes dependentes do servidor. Amostra: 1/1 achado; o recurso no destino nao foi
  conferido. O comportamento esperado e localizar o recurso correto e enviar email.
- **Por que recebeu essa avaliacao:** o nome observado, sozinho, nao demonstra
  incompatibilidade. Confianca baixa na necessidade de mudanca; risco ainda nao
  determinado porque o servidor nao foi conferido. Repetibilidade e ganho nao
  demonstrados. Por isso nao ha recomendacao de renomear a chamada.
- **Como prosseguir:** identificar a biblioteca efetivamente usada e comparar
  o nome procurado com o recurso configurado no servidor de destino. Guardar os
  trechos e a versao, sem credenciais. Se houver divergencia, decidir se a corretiva
  pertence a aplicacao ou a configuracao. Validar a localizacao do recurso e o envio
  em ambiente de teste; preservar a configuracao anterior para reversao.
- **Referencias e registro:** na ficha real, este bloco traz links para o ponto
  lido, achado MTA, secao pertinente da documentacao de email/JNDI da versao alvo,
  registro e indice de evidencias. Se uma fonte nao foi acessada, isso fica expresso;
  nao se substitui uma referencia ausente por um link inventado.

Uma issue recomendada tambem precisa desses elementos: sua posicao nao substitui
o diagnostico, as referencias nem as verificacoes. Lacunas de uma analise parcial
continuam explicitas; a ficha indica como completa-las antes de decidir a corretiva.

#### Continuar o trabalho manual

Guarde as evidencias pertinentes na area do projeto e referencie-as em
`evidencias/LEIA-ME.md` ou no registro. Voce pode escolher `ANALISAR AGORA` e seguir
para **Planejamento: planejar** mesmo sem recomendacao da IA. A corretiva do lote
tambem pode ser implementada manualmente: registre mudancas, cobertura e verificacoes
para revisao/aceite. Recomendacao da IA nao e requisito para a escolha humana.
Para planejar sem agente, prepare o contexto do lote pela tarefa e use a ficha
para redigir o plano e o to-do nos destinos `PlanPath`/`TodoPath` desse contexto,
seguindo o [contrato de planejamento](../../contratos/fluxo-migracao.md#planejamento-de-um-lote).
Defina recorte, comportamento esperado, solucao, dependencias, aceite e reversao;
complete as lacunas essenciais antes de aprovar e implementar. O roteiro e a
documentacao de referencia servem tanto ao trabalho humano quanto ao assistido.
Para redefinir a base/cobertura, use recriar explicitamente. Progredir continua
reservado a issues ainda nao examinadas da base inicial. O helper pode orientar a
investigacao da issue explicitamente indicada a partir da ficha e dos arquivos.

### Levar uma candidata ao planejamento

1. Abra o **link ao registro** fornecido na candidata. O resultado deve trazer
   IDs exatos e uma sugestao da **linha completa**, preservando as oito colunas.
   Coloque `ANALISAR AGORA` em **Decisao**; **Andamento** reflete o trabalho real.
2. Nas observacoes, registre recorte e referencia da ficha da issue, usando o link
   preparado. Se houver sobreposicao, preserve a relacao entre os IDs; escolher
   uma issue nao inclui nem declara resolvida outra automaticamente. O helper
   explica a conveniencia de cada escolha, que continua sendo sua.
3. Se precisar complementar a ficha, use **Planejamento: criar pasta de evidencias**
   para listar os anexos da issue e a relacao de cada um com a corretiva.
4. Execute **Planejamento: planejar**. A tarefa recupera escolha, referencias e
   base do registro. Nao repita a intencao no prompt nem atualize manualmente o
   ranking so para retirar "Escolha PENDENTE": esse trecho e historico, e a decisao
   atual esta no registro. Pode dizer ao helper apenas "Escolhi a issue; me conduza".
5. Para elaborar com IA, execute o prompt preparado e esclareca perguntas essenciais.
   Para elaborar manualmente, siga [o roteiro da ficha](#continuar-o-trabalho-manual)
   nos mesmos destinos do contexto. Nas duas formas, revalide o recorte e revise a
   proposta antes do GO. A posicao na lista nao autoriza planejar todas as candidatas.

O fluxo segue no [guia de planejamento](planejamento-migracao.md). Na futura
corretiva, a meta continua **85% de cobertura unitaria da parte corrigida via
JaCoCo**; abaixo da meta gera warning e nao bloqueia o build por si so.

### Validacao manual

Confira tarefa, categoria/escopo, quota fixa, cobertura acumulada e links de
todas as fichas, inclusive SEM POSICAO. Compare registro e codigo; preparar ou
executar priorizacao nao deve alterar escolhas nem criar plano/tarefas.
Verifique no cliente a leitura das fontes e a passagem ao planejamento somente
apos sua escolha. Testes dos scripts nao demonstram qualidade da recomendacao
ou delegacao nativa. Preserve notas manuais ao reconstruir os indices.

## Resultado e proximo passo

Revise `priorizacao.md`, fontes, quota, cobertura efetiva e lacunas. Escolha a
candidata e siga [como levar a escolha ao planejamento](#levar-uma-candidata-ao-planejamento).
Se quiser outra fatia, use [continuidade](#fatias-e-continuidade): preservar a base
ou recriar depende das entradas e da sua escolha. Ranking nao altera decisoes
no registro, nao cria lote e nao concede GO.
