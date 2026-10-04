---
html:
  embed_local_images: true
  embed_svg: true
  offline: true
---

# Priorizacao de issues: pre-planejamento entre projetos

Use esta etapa opcional para escolher uma corretiva mandatory equilibrando
risco, repetibilidade da solucao e alcance no codigo. A saida e uma lista de
**ate 5 candidatas por padrao, ou ate 10**, sustentada por evidencias e amostras.
Voce escolhe qual levar ao planejamento. Quem ja escolheu a issue pode seguir
direto ao [planejamento do lote](planejamento-migracao.md#planejar-lotes-de-correcao-com-copilot).

## Entradas e escopo

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
altera prioridades ou atualiza o indice.

Entram por padrao issues `mandatory`, `PRESENTE`, com decisao `A DEFINIR` ou
`ANALISAR AGORA` e andamento `NAO ANALISADA` ou `ANALISADA`. Issues adiadas, fora
do escopo ou ja planejadas/implementadas/verificadas exigem pedido explicito por
projeto/ID e recorte para reconsideracao. Issues `DEV-...` exigem pedido expresso,
sem inventar classificacao MTA. Lotes ativos e decisoes anteriores sao preservados.

## Uso manual pela Run Task

1. Salve o workspace e abra **Terminal > Run Task > Planejamento: priorizar issues**.
2. Escolha **5** ou **10**; Enter usa 5 e **q** cancela sem preparar arquivos.
3. Confira os projetos e os avisos no terminal. A tarefa mostra os caminhos reais
   do contexto, prompt e destino da lista, e abre `priorizar-issues.prompt.md`.
4. Acrescente preferencias ou restricoes no campo **Direcionamento do desenvolvedor**,
   por exemplo evitar alteracoes de contrato publico ou enfatizar uma aplicacao.
   Execute o prompt preparado no Chat do Copilot. Ele usa o agente padrao e nao
   depende do DevSquad.
5. Alternativamente, no Codex, anexe o prompt preparado e peca: "Leia e execute
   este prompt de priorizacao usando o contexto indicado nele". A autorizacao
   abrange salvar a lista no destino informado pelo contexto.
6. Revise `priorizacao.md`, suas fontes, lacunas e justificativas antes de escolher.

A tarefa **prepara** o contexto; a analise e a escrita ocorrem quando voce
executa o prompt. Use o `context.json` cuja localizacao a tarefa mostrou;
o prompt ja contem essa referencia, sem precisar preencher caminho ficticio.

Pelo terminal na raiz do harness, substituindo o nome pelo workspace que salvou:

```powershell
powershell.exe -NoProfile -File .\scripts\preparar-priorizacao.ps1 -WorkspacePath .\meu-workspace.code-workspace -Top 10 -NoOpen
```

`-Top` aceita inteiros de 5 a 10; `-SelectTop` oferece o menu. Para automacao,
combine `-NoOpen -OutputFormat Json` com WorkspacePath ou ConfigPath explicito;
nao use menu nem EditorPath nessa modalidade.

## Orientacao pelos helpers

No Codex, comece pela skill:

```text
$orientar-migracao Quero comparar issues mandatory dos projetos deste workspace
antes de escolher uma. Oriente a priorizacao por risco, repetibilidade e alcance.
```

No Copilot, selecione **migracao_helper** e faca o mesmo pedido. Veja a
[entrada e selecao dos helpers](workspace.md#orientacao-com-codex-ou-github-copilot).
O orquestrador pode consultar `migracao_planejamento_helper` para a comparacao
e `migracao_impacto_helper` para amostras das candidatas. Informe o workspace;
na retomada, anexe o contexto ou a lista da solicitacao que deseja revisar.

Os helpers explicam a tarefa, examinam evidencias e recomendam no chat. Para
salvar a lista, execute separadamente o prompt preparado conforme o procedimento
acima. Nenhum helper escolhe sua prioridade, concede GO ou inicia corretivas.

## Como avaliar a lista

A analise comeca pelos registros e aprofunda as candidatas promissoras no MTA,
nas regras/recomendacoes e no codigo atual. Amostras devem representar variacoes
de uso, modulos, projetos e dependencias, incluindo casos adversos. A lista
declara pontos lidos, amostra/total e o que permanece nao analisado.
Se faltar localizacao ou solucao no relatorio MTA, deve pedir essa evidencia.

| Criterio | O que conferir |
| --- | --- |
| Risco | Mudanca de comportamento/API, dependencias e runtime, testes possiveis e reversao. Desconhecido nao significa baixo risco. |
| Repetibilidade | Transformacao e precondicoes comuns confirmadas nas amostras; igualdade do ID da regra nao comprova a mesma solucao. |
| Alcance | Ocorrencias MTA separadas dos pontos de alteracao deduplicados, com arquivos/modulos e contagem por projeto. |
| Potencial | Reducao condicional, sem dupla contagem, promessa de resolucao ou extrapolacao da amostra para todos os usos. |
| Confianca | Qualidade e atualidade das evidencias, separada do risco. |

Pode haver menos de cinco candidatas quando a evidencia nao sustenta mais.
Projetos ausentes e issues excluidas/nao analisadas continuam visiveis. Agrupar
uma oportunidade comum nao cria um lote entre projetos. Java 8, `javax.*`,
EAP 7.4 e Hibernate 5.3, quando aplicavel, continuam sendo os alvos.

Cada solicitacao fica em `.harness/priorizacao/<RequestId>/`, com `context.json`,
prompt preparado e, depois da execucao pelo agente, `priorizacao.md`. O recibo
preserva snapshots do indice/registros, caminhos e hashes das entradas.
Mudancas relevantes posteriores precisam ser explicitadas na analise; snapshot
nao equivale ao estado atual. A limpeza de execucoes preserva essa pasta.

## Levar uma candidata ao planejamento

1. Escolha **projeto, IDs e recorte**. No `migracao.md` desse projeto, registre
   `ANALISAR AGORA` para a issue escolhida e o motivo/recorte conforme o registro.
2. Referencie a lista e a candidata no registro ou no indice de evidencias
   `evidencias/LEIA-ME.md` do projeto, usando o caminho real mostrado pela tarefa.
3. Prepare o contexto de planejamento habitual. No direcionamento do prompt,
   explicite a escolha e suas lacunas. Exemplo: "Planejar a issue que marquei
   ANALISAR AGORA neste projeto; usar a lista referenciada no registro e limitar
   a proposta aos modulos indicados".
4. Revise a proposta e decida o GO. O planejamento revalida o recorte escolhido;
   a posicao na lista nao autoriza planejamento de todas as candidatas.

O fluxo segue no [guia de planejamento](planejamento-migracao.md). Na futura
corretiva, a meta continua **85% de cobertura unitaria da parte corrigida via
JaCoCo**; abaixo da meta gera warning e nao bloqueia o build por si so.

## Validacao manual

Confira no seu cliente: descoberta da tarefa; orientacao/delegacao dos helpers;
contexto contendo apenas os projetos do workspace; rodada vinculada ao registro;
tratamento de lacunas/conflitos; amostras e contagens da lista; e passagem ao
planejamento somente apos sua escolha explicita. Compare indice, registros,
fontes e planos antes/depois: a priorizacao so deve produzir contexto/prompt e
lista da solicitacao. Preparacao automatizada testada nao comprova a qualidade
da recomendacao nem a integracao nativa do chat.

Voltar ao [roteiro do desenvolvedor](../harness-migracao-desenvolvedor.md#4-conferir-o-registro-e-escolher-prioridades).
