---
html:
  embed_local_images: true
  embed_svg: true
  offline: true
---

# Priorizacao de issues: pre-planejamento entre projetos

Use esta etapa opcional para comparar corretivas da categoria escolhida, equilibrando
risco, repetibilidade da solucao e alcance no codigo. A saida e um relatorio de
todas as issues examinadas, com recomendacoes, motivos e fichas de continuidade
manual sustentadas por evidencias e amostras, a partir de uma **fatia de
0,01% a 100,00% das issues elegiveis**, calculada sobre o total inicial fixo.
Voce escolhe qual levar ao planejamento. Quem ja escolheu a issue pode seguir
direto ao [planejamento do lote](planejamento-migracao.md#planejar-lotes-de-correcao-com-copilot).

Navegacao: [orientacao com o helper](#orientacao-com-o-helper) ·
[configuracao](#configuracao) · [uso](#uso) · [resultado e proximo passo](#resultado-e-proximo-passo).

<a id="orientacao-pelos-helpers"></a>

## Orientacao com o helper

No Codex, ative `$orientar-migracao`; no Copilot, selecione `migracao_helper`.
Veja [como iniciar e retomar a orientacao](../orientacao-migracao.md#iniciar-no-codex-ou-no-copilot).

```text
Quero comparar issues mandatory dos projetos deste workspace antes de escolher uma.
Gostaria de examinar uma fatia de 10%. Confira se existe priorizacao anterior e
me oriente na retomada ou na escolha entre recriar e progredir, considerando risco,
repetibilidade e alcance.
```

**Resultado esperado:** orientacao para preparar/retomar a fatia e a mensagem
para executar o prompt no cliente atual. O helper pode examinar evidencias e
recomendar no chat, com apoio de planejamento/impacto quando pertinente. A lista
so e salva ao executar separadamente o prompt; a escolha da candidata e sua.
Na retomada, o helper localiza a solicitacao vinculada, sem escolher por recencia.

## Configuracao

### Entradas e escopo

O preparador usa o indice existente `.harness/projetos/indice-projetos.md`, os
`migracao.md` dos projetos selecionados e as rodadas MTA referenciadas nesses
registros. Nao escolhe a rodada mais recente. `Source` e o codigo local;
`MtaOrigin/RunId` preservam a origem, inclusive de outra maquina. O snapshot
`input/` permite conferir o que foi analisado.

Pela Run Task, entram as pastas Maven do workspace salvo, incluindo agregadores.
Outros projetos citados no indice ficam fora. Pelo terminal sem WorkspacePath,
entram os projetos da configuracao informada. Ajuste o workspace ou use uma
configuracao com os projetos desejados para delimitar o conjunto.

O indice precisa existir; se necessario, execute antes
[Workspace: atualizar indice dos projetos](planejamento-migracao.md#indice-da-situacao-dos-projetos).
Registros ou evidencias ausentes/conflitantes aparecem como lacunas por projeto;
os projetos utilizaveis podem continuar. O preparador nao inicializa registros,
altera prioridades ou atualiza o indice dos projetos.
Uma reconciliacao antiga PENDENTE nao e pre-requisito generico para esta etapa;
o agente confere o motivo e registra o impacto real nas candidatas.

Entram issues da categoria escolhida, `PRESENTE`, com decisao `A DEFINIR` ou
`ANALISAR AGORA` e andamento `NAO ANALISADA` ou `ANALISADA`. Issues adiadas, fora
do escopo ou ja planejadas/implementadas/verificadas exigem pedido explicito por
projeto/ID e recorte para reconsideracao. Issues `DEV-...` exigem pedido expresso,
sem inventar classificacao MTA. Lotes ativos e decisoes anteriores sao preservados.

## Uso

### Uso manual pela Run Task

1. Salve o workspace e abra **Terminal > Run Task > Planejamento: priorizar issues**.
   Escolha a categoria recebida no catalogo: `mandatory`, `optional`, `potential`
   ou outra. Cada categoria tem sequencia e cobertura separadas. Voltar a mandatory
   permite progredir sua propria sequencia, sem consumir examinadas de optional.
2. Se houver priorizacao anterior, escolha **1 recriar** ou **2 progredir**.
   Recriar inicia nova base, preservando o historico; progredir exclui as issues
   ja examinadas na sequencia, com ou sem recomendacao. Um preparo ainda sem
   resultado e retomado quando suas instrucoes continuam atuais.
   Para uma nova fatia, informe **0,01 a 100,00**, com virgula ou ponto e ate duas
   casas; `%` e opcional. **q** ou Enter cancela sem preparar arquivos.
3. Confira os projetos e os avisos no terminal. A tarefa mostra os caminhos reais
   do contexto, prompt e destino da lista, e abre `priorizar-issues.prompt.md`.
4. Preferencias/restricoes sao opcionais. O prompt ja contem objetivo, limites e
   contexto; nao precisa escrever instrucoes adicionais de governanca.
5. Execute no cliente atual: no **Copilot**, use **Executar Prompt**, com DevSquad
   e apoio compativel de planejamento. No **Codex**, envie **Execute o prompt deste
   arquivo:** seguido do caminho completo exibido no terminal, ou anexe o arquivo.
   O helper deve fornecer a mensagem preenchida. O agente principal aplica skills
   e subagentes disponiveis; o front matter do Copilot nao seleciona agente no Codex.
6. Revise `priorizacao.md`, suas fontes, lacunas e justificativas antes de escolher.
   Confira tambem o apoio efetivamente usado e eventuais erros. Se houver falha
   de chamada, siga [o diagnostico de subagentes](../orientacao-migracao.md#se-a-chamada-de-subagente-falhar).

A tarefa **prepara** o contexto; a analise e a escrita ocorrem quando voce
executa o prompt. Use o `context.json` cuja localizacao a tarefa mostrou;
o prompt ja contem essa referencia, sem precisar preencher caminho ficticio.
Voce pode executar em novo chat e depois pedir orientacao ali mesmo. O helper
recupera os arquivos; nao e obrigatorio voltar ao chat anterior ou regenerar contexto.

Pelo terminal na raiz do harness, substituindo o nome pelo workspace que salvou:

```powershell
powershell.exe -NoProfile -File .\scripts\preparar-priorizacao.ps1 -WorkspacePath .\meu-workspace.code-workspace -Percentage 10 -Mode Recreate -NoOpen
```

`-Interactive` oferece os menus. Para avancar, use `-Mode Continue -Percentage 10`;
para retomar preparo ainda sem resultado, `-Mode Continue` basta. Se houver varias
frentes, informe `-PreviousRequestId` com o ID desejado; nao ha escolha por recencia.
Uma referencia antiga segue seu unico sucessor. Para automacao, combine
`-NoOpen -OutputFormat Json` com WorkspacePath ou ConfigPath explicito, sem
Interactive/EditorPath. Top/SelectTop foram substituidos; contextos anteriores ao percentual exigem
recriacao. Status EXHAUSTED indica que nao ha novas elegiveis e nenhum arquivo foi criado.

### Fatias e continuidade

O total inicial conta issues por **projeto/Source + ID completo**, nao ocorrencias.
Com 200 issues, cada avanco de 10% examina 20 issues ainda disponiveis;
nao calcula 10% do restante.
Arredonda para cima e limita ao disponivel: com duas issues, 0,01% resulta em uma
e 100% em duas. A lista informa percentual solicitado, quota e cobertura efetiva.
O agente pode recomendar menos que a quota por lacunas ou sobreposicoes.

Todos os IDs explicitamente examinados sao excluidos dos proximos avancos,
inclusive os sem recomendacao. Cada um aparece na tabela com posicao ou
**SEM POSICAO**, motivo concreto e evidencia necessaria. Continuam pendentes de
investigacao/corretiva quando cabivel; sair da fila de triagem nao resolve a issue.
Citacao/overlap de outra issue nao comprova exame dessa outra.
O prompt grava no proprio ranking um bloco estruturado com IDs examinados/propostos.
O preparador valida esse resultado. Nos novos recibos (SchemaVersion=4), COMPLETED
exige exatamente a quota em AnalyzedIssues; uma analise parcial fica IN_PROGRESS
e deve ser completada no mesmo arquivo. ProposedIssues pode estar vazio.
100% de issues examinadas nao significa todas as ocorrencias corrigidas/validadas.

Exemplo com base inalterada de **44 issues e 20%**:

| Rodada | Novas examinadas | Cobertura acumulada | Ainda nao examinadas |
| --- | ---: | ---: | ---: |
| 1 | 9 | 9/44 | 35 |
| 2 | 9 | 18/44 | 26 |
| 3 | 9 | 27/44 | 17 |
| 4 | 9 | 36/44 | 8 |
| 5 | 8 | 44/44 | 0 |

Isso vale mesmo com uma ou nenhuma recomendacao por rodada. A cobertura usa a
uniao distinta de examinadas anteriores e atuais, nao a quantidade recomendada.
O resultado liga os relatorios anteriores; as lacunas permanecem nesses documentos.

Mudancas de projetos, origem MTA/catalogo ou evidencias exigem recriar a base.
Decisoes humanas atuais filtram as disponiveis, sem mudar o denominador da sequencia.
Se retirar uma issue antes de examina-la, ela nao conta como examinada; EXHAUSTED
pode significar que nao ha novas elegiveis, mesmo sem cobertura de toda a base.
Se a retirada ocorrer depois do preparo, o agente substitui a issue por outra
elegivel de AvailableIssues. Se faltarem issues para completar a quota, preserva
o parcial em IN_PROGRESS e orienta recriar para refletir a nova selecao.
Projetos com diagnostico indisponivel aparecem como lacunas, fora dessa base.

### Continuar rodadas anteriores a esta correcao

Depois de atualizar o harness, use **2 progredir** para aproveitar rankings
concluidos em SchemaVersion=2. O novo preparo desconta a uniao de AnalyzedIssues
desses resultados, inclusive sem recomendacao; repeticoes antigas contam uma vez.
Mantem SequenceId, base e arquivos anteriores, criando o proximo recibo na versao 3.
Nao apague `.harness` nem edite recibos/hashes para adotar a correcao.

Se a primeira rodada examinou nove e recomendou uma, a proxima tera 35 disponiveis
e quota nove. Se duas rodadas antigas repetiram oito e cobriram dez IDs distintos,
restarao 34: o progresso real e dez, nao dezoito. Um resultado antigo parcial conta
somente os IDs que declarou examinados.

Um prompt antigo ainda pendente preserva seu contrato. Pode conclui-lo pelo arquivo
original e depois progredir; para usar imediatamente as instrucoes novas, escolha
recriar, sabendo que isso inicia outra base. A tarefa nao substitui silenciosamente
prompts antigos. Contextos Top anteriores ao percentual exigem recriacao.

### Incidentes preparados para leitura

A tarefa prepara, junto ao recibo, `Mta.IncidentEvidence.IndexPath` por projeto.
Esse indice liga cada issue disponivel a paginas de ate dez incidentes, com
URI original, linha, mensagem/recomendacao, trecho e caminhos candidatos no
snapshot e no Source atual. Todos os incidentes sao preservados; preparar as
paginas nao significa que o agente leu todos ou confirmou aplicabilidade.
`Files` registra os caminhos/hashes dos derivados. Retomada os confere; recriar
produz outra solicitacao e preserva os anteriores. `UNAVAILABLE` traz o erro de
extracao; sem resposta MCP suficiente, exige conferir os artefatos originais.
Nao significa zero achados.

Com [MCP disponivel](consultas-issues.md#consultas-por-etapa), o agente recupera os
incidentes por obter_issue, confere base/projeto, hashes, paginas e truncamentos.
Uma resposta suficiente dispensa abrir novamente o indice/paginas dos mesmos
incidentes. Codigo local e evidencias adicionais necessarias continuam exigidos.
Sem MCP, o agente abre os caminhos literalmente, inclusive em `.harness`, normalmente
ignorada pelas buscas. O MTA pode preservar URI da maquina/pasta antiga: o trecho
relativo a `input` aponta candidatos em `AnalysisSource` e `Source`. Conferir
arquivo/metodo/conteudo antes de usar a linha antiga. Referencias externas ou
ambiguas ficam explicitas, sem procurar indiscriminadamente em caches.

Se uma execucao antiga concluiu a fatia com falhas de leitura, escolha **recriar**
apos atualizar o harness. Progredir continuaria excluindo as issues ja declaradas
em `AnalyzedIssues`; recriar permite reexamina-las com as paginas de incidentes e
o prompt atualizado, preservando o recibo e o ranking antigos como historico.

### Acesso a rodada externa

Quando o agente precisar ler o MTA fora das pastas ja autorizadas, deve solicitar
permissao de leitura para `Mta.Run` e indicar os arquivos necessarios. Uma
autorizacao vigente para a raiz MTA inclui suas rodadas e nao precisa ser pedida
novamente. Apos a concessao, deve
tentar novamente o caminho literal e confirmar a leitura, inclusive pelo apoio
quando ele precisar do arquivo. A leitura efetiva depende de o cliente reconhecer
e aplicar essa permissao.

O workspace gerado inicializa o acesso de leitura com `mta.runsPath`, preservando
listas que o desenvolvedor ja definiu. Para usar `C:/mta-runs` em todas as rodadas
deste workspace, a propriedade em `settings` e:

```json
"github.copilot.chat.additionalReadAccessPaths": [
  "C:/mta-runs"
]
```

Veja [como aplicar, alterar ou revogar no workspace](workspace.md#acesso-do-copilot-a-pasta-mta),
incluindo a diferenca de nome entre a referencia do VS Code e o manifesto atual
do Copilot. Se a pasta nao estiver autorizada, aprove a solicitacao apresentada
pela ferramenta, quando disponivel, ou configure a pasta no workspace.
Se a configuracao nao estiver disponivel ou houver politica corporativa impeditiva,
informar versao, caminho, ferramenta e erro para ajustar o acesso suportado. Nao
habilitar aprovacao global, editar configuracao pelo prompt ou trocar de ferramenta
para contornar uma negativa. No Codex, usar a aprovacao/escalacao real da sessao
quando necessaria e permitida. Concessao no chat nao substitui a permissao tecnica.

Sem acesso essencial, o ranking permanece `IN_PROGRESS`; as issues cujo exame foi
impedido nao entram em `AnalyzedIssues`. O agente retoma depois da autorizacao.
Isso difere de uma issue efetivamente examinada que ficou `SEM POSICAO` por uma
incerteza tecnica. Nao exigir que o humano extraia trechos que o agente ja pode ler.

### Como avaliar a lista

A analise comeca pelos registros e aprofunda as candidatas promissoras no MTA,
nas regras/recomendacoes e no codigo atual. Amostras devem representar variacoes
de uso, modulos, projetos e dependencias, incluindo casos adversos. A lista
declara pontos lidos, amostra/total e o que permanece nao analisado.
Se faltar localizacao ou solucao apos a leitura efetiva do relatorio MTA, deve
pedir essa evidencia. Busca vazia, arquivo externo ou resposta truncada exigem
recuperar o acesso/leitura primeiro.

| Criterio | O que conferir |
| --- | --- |
| Risco | Mudanca de comportamento/API, dependencias e runtime, testes possiveis e reversao. Desconhecido nao significa baixo risco. |
| Repetibilidade | Transformacao e precondicoes comuns confirmadas nas amostras; igualdade do ID da regra nao comprova a mesma solucao. |
| Alcance | Ocorrencias MTA separadas dos pontos de alteracao deduplicados, com arquivos/modulos e contagem por projeto. |
| Potencial | Reducao condicional, sem dupla contagem, promessa de resolucao ou extrapolacao da amostra para todos os usos. |
| Confianca | Qualidade e atualidade das evidencias, separada do risco. |

Pode haver menos recomendacoes que issues examinadas quando a evidencia nao sustenta mais.
Todas as examinadas precisam ter uma linha e uma ficha para continuidade manual,
inclusive as recomendadas, conforme o roteiro abaixo.
Projetos ausentes e issues excluidas/nao analisadas continuam visiveis. Agrupar
uma oportunidade comum nao cria um lote entre projetos. Java 8, `javax.*`,
EAP 7.4 e Hibernate 5.3, quando aplicavel, continuam sendo os alvos.

Cada solicitacao fica em `.harness/priorizacao/<RequestId>/`, com `context.json`,
prompt preparado e, depois da execucao pelo agente, `priorizacao.md`. O recibo
preserva snapshots do indice/registros, caminhos e hashes das entradas.
Nos novos recibos, Category separa as sequencias e FichaPaths declara arquivos
individuais por projeto/issue, sob `.harness/planning/<artifactId>/issues/`.

### Indice automatico das priorizacoes

O arquivo `.harness/priorizacao/indice-priorizacao.md` segue o
[template de referencia](../../modelos/indice-priorizacao.template.md): sequencia
ativa, tabela de fatias, cobertura acumulada, substituidas e proximo passo.
Cada escopo/categoria conserva seus projetos, denominador e sequencia.

Na mesma tarefa **Planejamento: priorizar issues**, o preparo cria/atualiza esse
indice e mostra o caminho. A nova fatia aparece como **PENDENTE**, sem exame
inventado. Ao terminar, o prompt atualiza a linha e a cobertura, identificando
**conferencia do executor; a conferir pelo preparador**. Na proxima execucao da
tarefa, inclusive retomada ou esgotamento, o preparador reconcilia os resultados
com os validadores de quota, fichas e vinculos. Nao ha task adicional nem watcher:
se Continue recusar um resultado parcial/invalido, o indice tambem recebe esse
diagnostico, sem criar outra fatia. O preparo usa gravacao atomica e detecta
edicoes concorrentes observadas antes da substituicao, preservando as notas.
Gravar um ranking manualmente, fora do prompt, nao dispara um script.

So resultados completos e consistentes entram na tabela de fatias concluidas.
IN_PROGRESS, fichas ausentes e conflitos aparecem nas pendencias. A cobertura
conta Source/Id distintos das fatias completas, inclusive examinadas sem proposta.
No exemplo de 44 issues a 20%, as cinco fatias de 9+9+9+9+8 chegam a 44/44;
isso indica exame, nao correcao ou aceite. Esse 20% nao e o ganho de IA de sprints.

Recreate no mesmo escopo/categoria preserva os resultados anteriores como
substituidos e inicia outra base; referencias a outro escopo nao o substituem.
Continue acompanha a cadeia. Multiplas pontas ficam explicitas, sem escolher
pela data. Um indice manual existente permanece literalmente antes do bloco
automatico, identificado como historico. Notas humanas devem ficar fora dos
marcadores `priorizacao:indice:inicio/fim`; marcadores invalidos sao diagnosticados.

Prompts ja preparados antes desta evolucao conservam o contrato antigo. Seus
resultados entram na reconciliacao do preparador, mas o agente so escreve o indice
quando PrioritizationIndexPath estiver declarado no contexto novo. Nao edite
recibos antigos para acrescentar esse campo.

Ao importar uma analise compartilhada, os caminhos do indice/template passam
para a raiz local nos recibos derivados. O indice agregado da origem nao e
copiado sobre o local; a proxima priorizacao o reconcilia pelas fatias recebidas.
O agente cria fichas somente das examinadas; o ranking aponta para esses arquivos.
Mesmo ID em projetos diferentes mantem fichas distintas, com contexto suficiente
para compartilhar cada uma. Contextos v2/v3 continuam mandatory e conservam layout.

Uma analise v4 concluida pode ser exportada por **Planejamento: compartilhar
contexto**. O pacote leva a cadeia da categoria e o diagnostico para continuar a
sequencia ou planejar uma ficha em outro workspace. Veja o
[roteiro de exportacao/importacao](compartilhamento-contextos.md).
CLI aceita `-Category optional` (ou outra recebida); omitida, preserva mandatory.
Ao passar PreviousRequestId sem Category, a categoria daquela sequencia e retomada.
Mudancas relevantes posteriores precisam ser explicitadas na analise; snapshot
nao equivale ao estado atual. A limpeza de execucoes preserva essa pasta.

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

Voce nao precisa decorar IDs nem interpretar hashes. `Source` identifica a pasta
do projeto; `ID` identifica a regra; `RunId` identifica a rodada MTA. Esses valores
sao preservados nas referencias tecnicas e nos trechos para copiar ao registro.
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
seguindo o [contrato de planejamento](../../especificacoes/planejamento-copilot.md#planejamento-de-um-lote).
Defina recorte, comportamento esperado, solucao, dependencias, aceite e reversao;
complete as lacunas essenciais antes de aprovar e implementar. O roteiro e a
documentacao de referencia servem tanto ao trabalho humano quanto ao assistido.
Para reavaliar a priorizacao com uma nova base/evidencias, use recriar; progredir
continua reservado a issues ainda nao examinadas. O helper pode orientar a
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

Confira no seu cliente: descoberta da tarefa; orientacao/delegacao dos helpers;
contexto contendo apenas os projetos do workspace; rodada vinculada ao registro;
tratamento de lacunas/conflitos; amostras e contagens da lista; e passagem ao
planejamento somente apos sua escolha explicita. Confira se cada linha abre uma
ficha com titulo compreensivel, evidencia da avaliacao e proxima acao manual concreta,
inclusive SEM POSICAO. Compare indice, registros,
fontes e planos antes/depois: o preparo produz contexto/prompt e paginas de
incidentes e reconcilia o indice de priorizacao; a execucao do prompt escreve
ranking/fichas e atualiza esse indice nos destinos declarados. Confira no indice
a distincao entre conferencia do executor e do preparador, as pendencias e a
preservacao de notas manuais. O indice dos projetos e os registros permanecem
inalterados. O helper permanece leitor. Teste acesso externo
concedido e negado: leitura deve retomar apos concessao; negativa preserva parcial
sem consumir quota. Preparacao automatizada testada nao comprova a qualidade
da recomendacao nem a integracao nativa do chat.

Voltar ao [roteiro do desenvolvedor](../harness-migracao-desenvolvedor.md#4-conferir-o-registro-e-escolher-prioridades).

## Resultado e proximo passo

Revise `priorizacao.md`, fontes, quota, cobertura efetiva e lacunas. Escolha a
candidata e siga [como levar a escolha ao planejamento](#levar-uma-candidata-ao-planejamento).
Se quiser outra fatia, use [continuidade](#fatias-e-continuidade): preservar a base
ou recriar depende das entradas e da sua escolha. Ranking nao altera decisoes
no registro, nao cria lote e nao concede GO.
