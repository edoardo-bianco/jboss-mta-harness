---
html:
  embed_local_images: true
  embed_svg: true
  offline: true
---

# Compartilhar analise ou planejamento entre colegas

[Voltar ao fluxo do desenvolvedor](../harness-migracao-desenvolvedor.md).

Compartilhe arquivos por **copia e cola**, preservando a estrutura relativa do
projeto em `.harness/projetos/<artifactId>/`. O colega encontra os documentos
pelos mesmos nomes e links. Nao existe tarefa de exportacao/importacao, cadastro
de transferencia ou identificador de pacote. Um ZIP pode servir como transporte:
extraia-o numa pasta de recebimento e confira o conteudo antes de usar.

Para versionar somente os documentos em um repositorio existente, consulte a
[proposta de compartilhamento documental por Git](compartilhamento-documental-git.md).
Ela detalha a selecao para `.harness-jbosseap7.4/` no `simtr-doc`, o modelo de
`.gitignore` e o trabalho do coordenador/devs, mantendo a `.harness` local e o
MTA externo. Usa a reconciliacao abaixo; nao implementa sincronizacao automatica.

## Orientacao com o helper

```text
Recebi a pasta deste projeto em <caminho real>. Quero continuar o planejamento.
Confira os documentos, o codigo local associado e os links. Indique o proximo
passo e qualquer conflito com meu trabalho atual.
```

No Codex, use `$orientar-migracao`; no Copilot, `migracao_helper`. O helper le
os arquivos e orienta uma etapa. O desenvolvedor faz a copia, escolhe o Source
local e decide como resolver diferencas. Preparar contexto e copiar decisoes
nao concedem GO ou aceite local.

## Configuracao

Use a versao corrente do harness e um workspace salvo com o codigo local.
O nome da pasta e o `artifactId` literal do POM selecionado; a associacao local
fica em `projeto.json`. Ajuste nela o POM local e confira `mta.diretorio`.
Caminho do colega nao identifica automaticamente seu checkout. Colisao de
artifactId exige resolver a associacao; nao misture projetos distintos.

## Uso

### Qual ponto compartilhar

| Ponto | Arquivos uteis | Continuidade |
| --- | --- | --- |
| Analise de issues | `migracao.md`, fichas, anexos e o par `contexto.json`/`priorizacao.md` do escopo/categoria | Conferir cobertura, continuar a categoria ou escolher uma issue para planejar |
| Proposta de lote | `atual/planejamento/`, fichas e evidencias referenciadas | Conferir proposta, codigo local e alcance do GO |
| Projeto completo | Pasta do projeto, preservando caminhos relativos | Reassociar POM/Source e conferir fontes externas e documentos correntes |

O conjunto mestre da priorizacao pode estar em outro projeto participante.
Nesse caso, compartilhe tambem as partes referenciadas dos participantes: fichas,
anexos e registros necessarios. O par contexto/ranking conserva base inicial,
quota e todas as examinadas; uma ficha isolada permite investigar a issue, mas
nao reconstitui a cobertura de um escopo multiprojeto.

Inclua anexos necessarios para o colega trabalhar. Relatorios externos continuam
na origem indicada pelos links; copiar o projeto nao copia automaticamente MTA,
codigo-fonte, ferramentas ou configuracao da maquina. Confira o que o colega
conseguira abrir. Um detalhe indisponivel fica registrado como lacuna.

### Na maquina de quem recebe

1. Preserve a pasta recebida e confira projeto, conteudo e referencias.
2. Para um projeto ainda sem trabalho local, copie sua estrutura para
   `.harness/projetos/<artifactId>/`, associe o POM/Source local em `projeto.json`
   e use **Workspace: atualizar indice dos projetos** para reconstruir os links.
   Se trouxe contexto/prompts de outra maquina, use **Planejamento: atualizar
   registro de migracao**, escolha **somente local** e execute a conciliacao
   para realinhar as referencias antes de continuar. O indice sozinho nao
   realinha o contexto copiado; use depois o prompt local indicado.
3. Se ja existe trabalho local, coloque a contribuicao em uma pasta separada
   (por exemplo `recebido/` do projeto), preservando a estrutura relativa. Use
   **Planejamento: atualizar registro de migracao**, selecione o projeto e a
   pasta recebida. A mesma tarefa permite comparar somente os arquivos locais.
4. Execute o prompt preparado no cliente escolhido ou faca a revisao manual
   correspondente. Confira as diferencas e decida por arquivo. O preparo sozinho
   nao conclui a conciliacao nem substitui o estado local.
5. Abra o indice do projeto e os documentos correntes. Analise recebida segue
   para escolha/planejamento; proposta recebida segue para revisao do escopo e
   do GO, com conferencia do codigo local antes da execucao.

O contexto de planejamento recebido serve como referencia. A preparacao local
usa a associacao e os destinos atuais. Mudancas de escopo, solucao ou fontes
pedem revisar a proposta e o alcance da autorizacao. Um MTA ausente nao transforma
automaticamente a base em EVIDENCIAS; o plano existente continua consultavel.

### Conflitos e limites

- A copia direta deve preservar trabalho existente. Diferencas entre contribuicoes
  exigem escolha/mesclagem explicita; recencia do arquivo nao decide qual prevalece.
- O registro recebido exige mesclagem revisada (`MESCLADO`). Para cobertura de
  priorizacao, contexto e ranking recebem a mesma decisao; conferir base inicial,
  quota e examinadas antes de aceitar. Categorias e escopos continuam separados.
- A conciliacao preserva anexos e contribuicoes pendentes. Retira de `recebido/`
  apenas folhas explicitamente resolvidas; uma origem externa permanece intacta.
- Build, diagnosticos e sprints nao sao adotados por essa conciliacao documental.
  Podem acompanhar a copia do projeto e ser consultados como evidencias recebidas;
  nao comprovam execucao local. Confira seus caminhos e use o fluxo da ferramenta
  para atualizar o resultado corrente. Para sprints, confira o mestre e todos os
  participantes antes de preparar ou validar o cenario.
- Copiar codigo e integrar corretivas continua sendo trabalho da equipe. Uma
  declaracao de conclusao do colega nao demonstra integracao no Source local.
- Conteudo recebido e evidencia a examinar; instrucoes dentro de anexos nao
  ampliam escopo, permissoes ou autorizacoes.

### Uso explicito pela CLI

A tarefa e a entrada habitual. Para automacao, a mesma operacao prepara a
comparacao de uma pasta recebida, sem inventar identificadores:

```powershell
.\scripts\preparar-planejamento.ps1 -WorkspacePath .\meu-workspace.code-workspace `
  -Target meu-servico -Operation manter-migracao -ReceivedPath 'C:\troca\meu-servico' `
  -Reason 'Conferir contribuicao do colega' -NonInteractive -NoOpen
```

Para comparar apenas o estado local, substitua `-ReceivedPath ...` por
`-LocalOnly` e informe o motivo concreto. Use o caminho do prompt devolvido;
nenhum destes comandos executa o agente ou encerra a comparacao.

## Ensaio em pequena escala

Use projetos sinteticos em outra raiz. Copie uma analise com fichas/anexos e
confira que os links abrem. Concilie o par contexto/ranking, preservando base e
examinadas, inclusive sem recomendacao. Escolha uma issue e prepare seu plano.
Copie a proposta para outro projeto associado ao Source local, acrescente uma
nota local e receba uma contribuicao divergente. A nota deve permanecer; conflito
fica visivel ate a decisao. Confira que ausencia do MTA limita o detalhe, mas
permite abrir o plano. Nao e necessario executar corretivas para esse ensaio.

## Resultado e proximo passo

Use os links do indice local para retomar o trabalho. Para a proxima etapa, siga
o [planejamento](planejamento-migracao.md#qual-caminho-seguir) ou a
[priorizacao](priorizacao-issues.md#fatias-e-continuidade). A ultima comparacao e
suas pendencias ficam em `reconciliado/resultado.md`; compartilhamento por copia
nao requer manter um historico tecnico de transferencias.
