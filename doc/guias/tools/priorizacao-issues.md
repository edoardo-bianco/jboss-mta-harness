---
html:
  embed_local_images: true
  embed_svg: true
  offline: true
---

# Priorizacao de issues: pre-planejamento entre projetos

Use esta etapa opcional para escolher uma corretiva mandatory equilibrando
risco, repetibilidade da solucao e alcance no codigo. A saida e uma lista de
recomendacoes sustentadas por evidencias e amostras, a partir de uma **fatia de
0,01% a 100,00% das issues elegiveis**, calculada sobre o total inicial fixo.
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
Uma reconciliacao antiga PENDENTE nao e pre-requisito generico para esta etapa;
o agente confere o motivo e registra o impacto real nas candidatas.

Entram por padrao issues `mandatory`, `PRESENTE`, com decisao `A DEFINIR` ou
`ANALISAR AGORA` e andamento `NAO ANALISADA` ou `ANALISADA`. Issues adiadas, fora
do escopo ou ja planejadas/implementadas/verificadas exigem pedido explicito por
projeto/ID e recorte para reconsideracao. Issues `DEV-...` exigem pedido expresso,
sem inventar classificacao MTA. Lotes ativos e decisoes anteriores sao preservados.

## Uso manual pela Run Task

1. Salve o workspace e abra **Terminal > Run Task > Planejamento: priorizar issues**.
2. Se houver priorizacao anterior, escolha **1 recriar** ou **2 progredir**.
   Recriar inicia nova base, preservando o historico; progredir exclui as issues
   ja propostas na sequencia. Um preparo ainda sem resultado e retomado.
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
Interactive/EditorPath. Top/SelectTop foram substituidos; contextos antigos exigem
recriacao. Status EXHAUSTED indica que nao ha novas elegiveis e nenhum arquivo foi criado.

### Fatias e continuidade

O total inicial conta issues por **projeto/Source + ID completo**, nao ocorrencias.
Com 200 issues, cada avanco de 10% examina ate 20 issues ainda disponiveis;
nao calcula 10% do restante.
Arredonda para cima e limita ao disponivel: com duas issues, 0,01% resulta em uma
e 100% em duas. A lista informa percentual solicitado, quota e cobertura efetiva.
O agente pode recomendar menos que a quota por lacunas ou sobreposicoes.

Apenas IDs explicitamente propostos sao excluidos dos proximos avancos. Issues
examinadas sem recomendacao continuam disponiveis; citacao/overlap nao e proposta.
O prompt grava no proprio ranking um bloco estruturado com IDs examinados/propostos.
O preparador valida esse resultado; arquivo incompleto nao equivale a fatia concluida.
100% de issues examinadas nao significa todas as ocorrencias corrigidas/validadas.

Mudancas de projetos, origem MTA/catalogo ou evidencias exigem recriar a base.
Decisoes humanas atuais filtram as disponiveis, sem mudar o denominador da sequencia.
Projetos com diagnostico indisponivel aparecem como lacunas, fora dessa base.

## Orientacao pelos helpers

No Codex, comece pela skill:

```text
$orientar-migracao Quero comparar issues mandatory dos projetos deste workspace
antes de escolher uma. Oriente a priorizacao por risco, repetibilidade e alcance.
```

No Copilot, selecione **migracao_helper** e faca o mesmo pedido. Veja a
[entrada e selecao dos helpers](workspace.md#orientacao-com-codex-ou-github-copilot).
O orquestrador pode consultar `migracao_planejamento_helper` para a comparacao
e `migracao_impacto_helper` para amostras das candidatas. Um pedido curto basta;
informe o workspace/contexto somente se o helper nao puder distingui-lo pelos
arquivos. Na retomada ele localiza a solicitacao vinculada, sem escolher por recencia.

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

Pode haver menos recomendacoes que issues examinadas quando a evidencia nao sustenta mais.
Projetos ausentes e issues excluidas/nao analisadas continuam visiveis. Agrupar
uma oportunidade comum nao cria um lote entre projetos. Java 8, `javax.*`,
EAP 7.4 e Hibernate 5.3, quando aplicavel, continuam sendo os alvos.

Cada solicitacao fica em `.harness/priorizacao/<RequestId>/`, com `context.json`,
prompt preparado e, depois da execucao pelo agente, `priorizacao.md`. O recibo
preserva snapshots do indice/registros, caminhos e hashes das entradas.
Mudancas relevantes posteriores precisam ser explicitadas na analise; snapshot
nao equivale ao estado atual. A limpeza de execucoes preserva essa pasta.

## Levar uma candidata ao planejamento

1. Abra o **link ao registro** fornecido na candidata. O resultado deve trazer
   IDs exatos e uma sugestao da **linha completa**, preservando as oito colunas.
   Coloque `ANALISAR AGORA` em **Decisao**; **Andamento** reflete o trabalho real.
2. Nas observacoes, registre recorte e referencia da candidata, usando o link
   preparado. Se houver sobreposicao, preserve a relacao entre os IDs; escolher
   uma issue nao inclui nem declara resolvida outra automaticamente. O helper
   explica a conveniencia de cada escolha, que continua sendo sua.
3. Execute **Planejamento: planejar**. A tarefa recupera escolha, referencias e
   base do registro. Nao repita a intencao no prompt nem atualize manualmente o
   ranking so para retirar "Escolha PENDENTE": esse trecho e historico, e a decisao
   atual esta no registro. Pode dizer ao helper apenas "Escolhi a issue; me conduza".
4. Execute o prompt preparado, esclareca perguntas essenciais quando houver e
   revise a proposta antes de decidir o GO. O planejamento revalida o recorte escolhido;
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
