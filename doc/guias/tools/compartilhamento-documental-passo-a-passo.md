# Passo a passo: compartilhar documentos no simtr-doc

Roteiro para o coordenador e os desenvolvedores compartilharem os documentos
de **todos os projetos Java locais adicionados ao harness**. Somente o conteudo
documental selecionado da `.harness` vai ao `simtr-doc`; codigo-fonte, POMs e
relatorios MTA permanecem em suas localizacoes atuais.

**Situacao: procedimento para adocao e ensaio pela equipe.** Este roteiro usa
copia seletiva, Git e a reconciliacao existente. Sua publicacao no harness nao
comprova publicacao dos dados no `simtr-doc` nem ensaio entre desenvolvedores.

[Guia do desenvolvedor](../harness-migracao-desenvolvedor.md) |
[Proposta e regras de selecao](compartilhamento-documental-git.md) |
[Copia e reconciliacao](compartilhamento-contextos.md) |
[Modelo de .gitignore](../../modelos/compartilhamento-documental.gitignore)

## Como usar este roteiro

Execute uma etapa por vez na maquina de trabalho. Substitua os campos entre
colchetes nos prompts pelos caminhos e referencias reais. Se mudar de conversa,
forneca tambem o inventario ou diff revisado que o prompt mencionar.

Os prompts de leitura podem ser usados no agente de sua escolha. Para copiar,
publicar ou executar um prompt preparado, use o agente principal/executor.
No Copilot, use **Executar Prompt** no arquivo preparado, com `devsquad` quando
disponivel; sem esse perfil, use Agent conforme o
[encaminhamento de execucao](../orientacao-migracao.md#passar-da-orientacao-para-a-execucao).
`migracao_helper` permanece orientador. Ler este guia nao autoriza executar seus
prompts, copiar dados ou publicar no Git.

| Etapa | Quem faz | Entrega a conferir |
| --- | --- | --- |
| [1. Locais e conteudo](#1-locais-e-conteudo) | Coordenador | Origem local e destino corporativo definidos |
| [2. Inventario](#2-inventariar-todos-os-projetos) | Coordenador | Projetos, documentos, anexos e lacunas |
| [3. Copia documental](#3-preparar-a-primeira-copia-documental) | Coordenador | Branch e conjunto local revisavel |
| [4. Conferencia do Git](#4-conferir-o-que-sera-publicado) | Coordenador ou dev | Lista rastreada e diff staged conferidos |
| [5. Publicacao](#5-publicar-a-base-revisada) | Coordenador ou dev | Commit, branch e PR no simtr-doc |
| [6. Recebimento](#6-receber-a-base-em-outra-maquina) | Cada dev | Documentos reconciliados com suas fontes locais |
| [7. Ensaio entre dois devs](#7-ensaiar-com-dois-desenvolvedores) | Equipe | Preservacao e conflitos conferidos em copias de teste |
| [8. Contribuicao](#8-preparar-a-contribuicao-do-desenvolvedor) | Cada dev | Recorte documental revisado e PR |
| [9. Consolidacao](#9-reconciliar-contribuicoes-e-publicar-o-consolidado) | Coordenador | Consolidado revisado para novo recebimento |

## 1. Locais e conteudo

Exemplo de organizacao; ajuste os caminhos a sua maquina:

```text
C:\desenvolvimento\repositorio\jboss-mta-harness\
  .harness\projetos\<artifactId>\       trabalho local

C:\desenvolvimento\repositorio\simtr-doc-sync\
  .harness-jbosseap7.4\                 copia documental no repo simtr-doc
    .gitignore
    README.md
    projetos\<artifactId>\

Projetos Java: continuam nos repositorios de codigo locais.
MTA: continua na origem externa configurada, por exemplo C:\mta-runs.
```

`simtr-doc-sync` e apenas o nome de exemplo do clone. Um clone existente do
`simtr-doc` tambem serve. Confira a URL corporativa de clonagem, a branch
principal real e quem integra as contribuicoes. Nao cadastre `simtr-doc` como
projeto Maven no harness.

O conteudo selecionado de `.harness/projetos/` vai para
`.harness-jbosseap7.4/projetos/`, preservando a estrutura relativa. Nao crie
outra `.harness` dentro do destino.

| Compartilhar quando existir e fizer parte da selecao | Manter local |
| --- | --- |
| `migracao.md` | Codigo-fonte, POMs e relatorios MTA |
| Fichas, inclusive de issues manuais | `projeto.json` e configuracao de maquina |
| Par `contexto.json` / `priorizacao.md` de cada categoria/escopo | Indices derivados e prompts gerados |
| Contexto, plano e tarefas do planejamento corrente | Operacoes, builds, diagnosticos e sprints |
| `evidencias/LEIA-ME.md` e anexos selecionados individualmente | Servidores, WAR/EAR/JAR, temporarios, recebidos e backups |
| `reconciliado/resultado.md`, quando existir | Credenciais e demais arquivos privados nao documentais |

Os caminhos completos permitidos e as exclusoes estao na
[selecao documental](compartilhamento-documental-git.md#3-o-que-entra-no-repositorio-documental).
Para fundamentar build, teste ou Sonar, selecione a evidencia documental
necessaria em `evidencias/`, com origem e limites, sem copiar o estado operacional.

Preserve os JSON de contexto como produzidos. Eles conservam base, quota e
continuidade; nao substitua caminhos em massa. A reconciliacao realinha as
referencias no destinatario. A mesma pasta MTA em duas maquinas nao comprova
que ambas tem o mesmo diagnostico.

Voce pode continuar trabalhando antes da primeira publicacao. Nao precisa
terminar a priorizacao nem criar planos para compartilhar uma analise parcial.
Durante a copia, mantenha o conjunto selecionado estavel; retome as tarefas
que o regravam depois da conferencia. O Git documental guarda somente as
versoes efetivamente commitadas, sem recuperar documentos ja sobrescritos.

## 2. Inventariar todos os projetos

Abra o workspace salvo do harness na maquina corporativa e envie:

```text
Quero inventariar a primeira base documental para compartilhar no simtr-doc.

Escopo: TODOS os projetos Java locais ja adicionados ao meu harness.

Identifique os projetos pelas pastas de aplicacao do workspace salvo e pelas
associacoes em .harness/projetos/*/projeto.json. Confira os POMs locais e use
o artifactId literal. Relate diferencas entre workspace e associacoes,
associacoes ausentes, divergencias, colisoes ou projetos sem POM como lacunas.
Nao invente aliases nem altere associacoes para completar o inventario.

Leia:
- doc/guias/tools/compartilhamento-documental-git.md
- doc/modelos/compartilhamento-documental.gitignore

O compartilhamento abrange exclusivamente os documentos selecionados da
.harness, destinados a .harness-jbosseap7.4/projetos/ no simtr-doc.
Codigo-fonte, POMs e relatorios MTA sao apenas referencias de consulta
e nao devem integrar a copia.

Examine somente em leitura e entregue, por projeto:
1. ArtifactId, POM e Source local.
2. Arquivos existentes que entrariam no compartilhamento.
3. Arquivos que devem permanecer locais.
4. Anexos referenciados que precisam de inclusao explicita.
5. Arquivos ou fontes referenciados que estao ausentes.
6. Conferencia dos pares contexto/ranking e dos participantes de
   priorizacoes multiprojeto, incluindo dependencias fora do inventario.
7. Estado parcial ou completo declarado nos documentos, sem inferir conclusao.
8. Referencias que dependerao do Source/MTA do destinatario.

Preserve fatias parciais, decisoes, fichas e propostas correntes.
Nao copie, altere ou exclua arquivos. Nao regenere indices/contextos
e nao publique no Git. Nao exponha credenciais ou conteudo sensivel dos anexos.
Entregue o inventario no chat, com caminhos documentais relativos.
```

**Confira antes de continuar:**

- Todos os projetos esperados aparecem, inclusive os que ainda nao tem documentos
  compartilhaveis. Lacunas de identidade precisam ser esclarecidas antes da copia.
- Cada priorizacao selecionada tem o par `contexto.json` / `priorizacao.md`.
- O mestre multiprojeto e os registros, fichas e anexos pertinentes dos demais
  participantes estao identificados; nenhuma cobertura depende de ficha isolada.
- Anexos ausentes e referencias externas estao visiveis.
- Nenhum plano, resultado, exame ou aceite foi inventado para preencher lacunas.

Se quiser apoio em outra conversa, envie esse inventario e suas lacunas.
Nao e necessario enviar a `.harness` inteira, os relatorios MTA ou os anexos.

## 3. Preparar a primeira copia documental

Depois de revisar o inventario, informe o clone corporativo do `simtr-doc`.
Se nao houver clone, forneca a URL de clonagem do repositorio inteiro. O
[procedimento Git](compartilhamento-documental-git.md#5-coordenador-preparar-a-primeira-base)
inclui a opcao de sparse-checkout. Preserve trabalho existente no clone.

Envie ao agente executor:

```text
Quero preparar localmente a primeira base documental do simtr-doc,
conforme o inventario revisado fornecido nesta conversa.

Repositorio documental local: [CAMINHO DO CLONE DO SIMTR-DOC].
URL corporativa, se for necessario clonar: [URL].
Escopo: todos os projetos Java identificados no inventario.

Leia doc/guias/tools/compartilhamento-documental-git.md.

Confira repositorio, remotos, branch principal e trabalho local existente.
Prepare uma branch documental docs/base-jboss-eap74 a partir da principal
atualizada. Se ela ja existir, confira seu conteudo antes de retoma-la.
Nao troque a branch de checkout usado por outro agente; use outro checkout.
Preserve alteracoes existentes e nao use force, reset ou descarte.
Pergunte somente por informacao essencial ainda ausente.

Prepare .harness-jbosseap7.4/ nesse clone:
- instale doc/modelos/compartilhamento-documental.gitignore como
  .harness-jbosseap7.4/.gitignore;
- se ja houver regras no destino, preserve-as e apresente diferencas;
- confira se regras do repositorio ignoram a pasta pai;
- copie somente os documentos selecionados no inventario;
- preserve artifactIds, categorias, escopos e nomes das pastas;
- preserve o conteudo de contexto/ranking e suas referencias;
- inclua os anexos revisados com excecoes individuais no .gitignore;
- prepare um README com projetos, escopo, lacunas e orientacao de recebimento.

Se documentos mudaram desde o inventario, confira novamente sua selecao
e consistencia antes da copia. Se houver documento divergente no destino,
apresente a diferenca antes de sobrescrever.

Nao altere a .harness de origem, codigo-fonte, POMs ou MTA.
Nao copie a .harness inteira nem crie documentos de migracao ausentes.
Nao faca commit, push ou PR nesta etapa.
Entregue a lista efetivamente copiada, diferencas e pendencias.
```

**Confira:** destino corporativo correto, estrutura relativa preservada,
origem intacta, pares contexto/ranking presentes e lacunas descritas no README.
Nao deve haver copia adicional da `.harness` inteira nem sobrescrita silenciosa.

Se um arquivo esperado continuar ignorado, use `git check-ignore -v` com seu
caminho para localizar a regra. O `.gitignore` interno nao reabre uma pasta pai
ignorada. Revise a excecao no nivel correto; nao use `git add -f` para contornar
o filtro nem altere o `.gitignore` do harness para publicar seus dados.

## 4. Conferir o que sera publicado

No PowerShell, ajuste o caminho do clone e confira a selecao:

```powershell
$repoDocumental = 'C:\desenvolvimento\repositorio\simtr-doc-sync'

git -C $repoDocumental status --short
git -C $repoDocumental ls-files -- .harness-jbosseap7.4
git -C $repoDocumental add -- .harness-jbosseap7.4
git -C $repoDocumental diff --cached --name-status
git -C $repoDocumental diff --cached
git -C $repoDocumental diff --cached --check
```

`add` prepara os arquivos para o commit; nenhum comando acima envia dados ao
remoto. `diff --cached` mostra o proximo commit inteiro, inclusive arquivos de
outras frentes ja staged. `ls-files` mostra os arquivos rastreados na area,
inclusive os anteriores: `.gitignore` nao remove arquivos ja rastreados.

Peca a revisao:

```text
Revise a primeira base documental preparada no simtr-doc.
Repositorio: [CAMINHO DO CLONE].

Compare o inventario revisado com os arquivos em .harness-jbosseap7.4,
os arquivos ja rastreados pelo Git nessa area e o diff staged completo.

Confira:
1. Somente os documentos previstos e anexos revisados estao incluidos.
2. Nao ha codigo, POMs, relatorios MTA, binarios, configuracao de maquina
   ou credenciais.
3. Contexto/ranking, fichas e participantes multiprojeto estao coerentes.
4. Nenhuma decisao, quota, cobertura ou proposta foi alterada pela copia.
5. Links entre documentos copiados tem destinos existentes.
6. Referencias externas e documentos omitidos estao identificados como limites.
7. Nao ha remocoes inesperadas nem arquivos staged de outros trabalhos.

Nao altere arquivos nem publique. Nao exponha valores sensiveis encontrados;
aponte o arquivo e o problema.
Entregue achados concretos e o resultado da conferencia.
```

**Confira:** lista e conteudo completos do diff, anexos revisados e ausencia de
arquivos de outras frentes. Se houver trabalho alheio staged, separe a entrega
antes do commit, preservando as alteracoes. Remocao de documento exige decisao
explicita; ausencia na contribuicao nao significa excluir do consolidado.

Links a codigo, MTA ou guias/indices omitidos podem depender da maquina de quem
recebe e nao abrir no navegador do `simtr-doc`. Registre o limite; nao reescreva
os contextos nem copie essas fontes para fazer o link abrir no repositorio.

## 5. Publicar a base revisada

Depois de conferir conteudo, destinatario e diff, envie:

```text
A base documental e o diff foram revisados.

Publique somente essa entrega no repositorio corporativo simtr-doc,
no clone [CAMINHO], usando a branch documental [BRANCH].

Confira se o diff continua igual ao revisado.
Faca commit, push da branch e abra o PR para a principal real do repositorio.
Nao faca merge automatico.

Na descricao do PR, informe projetos incluidos, documentos/anexos,
estado parcial das analises, lacunas, dependencias de Source/MTA
e verificacoes realizadas.

Nao inclua arquivos de outros trabalhos, nao publique no repositorio
do harness e nao altere os documentos operacionais da origem.
Entregue branch, commit, link do PR e lista de arquivos publicados.
```

Se o cliente nao puder abrir PR na plataforma corporativa, use a interface
habitual da equipe com o titulo e descricao preparados. Nao trate push da
branch como abertura ou integracao do PR.

**Confira no PR:** repositorio corporativo, branch de destino, arquivos e diff
iguais aos revisados, analises parciais e lacunas descritas. A equipe revisa e
integra pelo fluxo habitual. A mera existencia deste guia nao autoriza publicar
dados; o pedido acima pertence a esta etapa, depois da conferencia concreta.

## 6. Receber a base em outra maquina

Cada dev usa seu harness atualizado, workspace salvo e POMs/Source locais.
Disponibilize o MTA necessario separadamente; ele nao vem no `simtr-doc`.
Nao adote o `projeto.json` do colega. Confira a associacao local e suas fontes.

Para cada projeto a receber:

1. Obtenha a base revisada em um clone separado do `simtr-doc`.
2. Confira a associacao local. Se ainda nao houver registro, use
   **Workspace: atualizar indice dos projetos** e confira o resultado.
3. Execute **Planejamento: atualizar registro de migracao**.
4. Informe o motivo: `Receber a base documental compartilhada no simtr-doc`.
5. Selecione a pasta recebida **do projeto**, por exemplo:

   ```text
   C:\desenvolvimento\repositorio\simtr-doc-sync\.harness-jbosseap7.4\projetos\<artifactId>
   ```

6. Execute o prompt gerado no agente executor. No Copilot, use
   **Executar Prompt**; ao encaminhar por chat, use a mensagem abaixo.

```text
Execute o prompt preparado em:
[CAMINHO EXATO DO PROMPT GERADO].

Siga o contrato e os destinos indicados pelo prompt.
Compare a base documental recebida com documentos, codigo e evidencias locais.
Use a publicacao protegida prevista no fluxo de reconciliacao.

Preserve escolhas humanas, trabalho local e contribuicoes divergentes.
Confira base inicial, quota, examinadas e o par contexto/ranking.
Realinhe referencias conforme as associacoes locais.
Mantenha conflitos nao resolvidos explicitos.

Nao execute corretivas, build, deploy ou novas analises.
Nao transforme decisoes recebidas em GO ou aceite local.
Entregue conclusao, documentos afetados, conflitos e lacunas restantes.
```

**Confira depois da execucao:**

- `reconciliado/resultado.md` descreve a comparacao, fontes e pendencias reais.
- Notas, decisoes e evidencias locais foram preservadas; a origem externa
  permanece intacta.
- Links e contextos usam as associacoes locais pertinentes.
- Base inicial, quota e TODAS as examinadas, inclusive sem recomendacao,
  foram conferidas; divergencias estao explicitas.
- As fichas/anexos dos participantes foram recebidos e seus POMs associados
  antes de adotar a cobertura do mestre multiprojeto.
- A fatia parcial continua no mesmo escopo/categoria/quota. Retome o prompt
  existente ou `Continue` sem novo percentual quando precisar regravar o preparo.
  Nao use `Recreate` apenas por receber arquivos. Issues manuais seguem na
  categoria `manual`, separadas das quotas MTA.

Preparar o prompt ou atualizar o indice sozinho nao conclui a reconciliacao.
MTA ausente permanece como lacuna, sem troca silenciosa para EVIDENCIAS.
Copiar documentos nao integra codigo nem transfere GO ou aceite de outro dev.

## 7. Ensaiar com dois desenvolvedores

Antes de ampliar o uso, facam um ensaio com projetos sinteticos e copias de
teste fora dos workspaces operacionais. Nao insiram decisoes ficticias nos
registros reais nem publiquem os dados de teste na base documental da equipe.

1. Os dois devs recebem a mesma base de teste, contendo fichas, anexos e
   contexto/ranking.
2. Cada um acrescenta uma nota diferente em sua propria copia de teste.
3. Um dev prepara sua contribuicao; o outro a recebe pela reconciliacao.
4. Confiram que as duas notas, fichas e anexos foram preservados.
5. Repitam com uma divergencia intencional no mesmo registro.
6. Confiram que o conflito permanece visivel ate uma decisao explicita, com
   cobertura, quota e escolhas preservadas.

Para preparar o ensaio com apoio do agente:

```text
Quero preparar o ensaio de compartilhamento com dois desenvolvedores.
Leia a etapa 7 de
doc/guias/tools/compartilhamento-documental-passo-a-passo.md
e o ensaio em pequena escala de doc/guias/tools/compartilhamento-contextos.md.

Proponha as entradas sinteticas e a sequencia para cada participante,
em raizes de teste fora dos workspaces operacionais.
Cubra notas distintas, conflito no mesmo registro, fichas/anexos,
par contexto/ranking, quota e examinadas, inclusive sem recomendacao.

Entregue caminhos de teste propostos, acoes humanas e resultados esperados.
Nesta etapa, nao altere dados reais, nao execute ferramentas de migracao
e nao publique dados de teste no simtr-doc.
```

**Resultado a registrar:** participantes, cenario executado, preservacao
observada, conflito observado/resolvido e lacunas. Um roteiro proposto nao
equivale a ensaio executado. O ensaio nao exige aplicar corretivas na aplicacao.

## 8. Preparar a contribuicao do desenvolvedor

Cada dev continua a analise e o planejamento em sua `.harness` local. A
primeira base abrange todos os projetos escolhidos; cada contribuicao leva
somente o recorte trabalhado e as dependencias documentais necessarias.

```text
Quero preparar uma contribuicao documental para o simtr-doc.

Repositorio documental: [CAMINHO].
Recorte trabalhado: [PROJETOS / ISSUES / CATEGORIAS / ESCOPOS].
Base compartilhada utilizada: [REFERENCIA CONHECIDA].

Leia doc/guias/tools/compartilhamento-documental-git.md.

Crie uma branch documental a partir da base compartilhada utilizada,
preservando trabalho existente e sem trocar checkout usado por outro agente.
Selecione os documentos existentes do recorte e suas dependencias necessarias,
incluindo pares contexto/ranking e participantes multiprojeto pertinentes.

Prepare a copia em .harness-jbosseap7.4, preservando o trabalho local.
Nao copie projetos alheios ao recorte, codigo, POMs, MTA ou dados operacionais.
Nao exclua documentos apenas porque estao ausentes na contribuicao.
Nao sobrescreva divergencias sem apresenta-las.
Confira anexos e excecoes individuais no .gitignore.

Entregue a lista de alteracoes e um texto de PR com issues examinadas,
resultados, documentos alterados, pendencias, conflitos, origem e limites
das evidencias. Prepare a entrega para revisao, sem commit ou push nesta etapa.
```

**Confira:** a branch parte da base usada pelo dev, o recorte esta explicito,
as dependencias de cobertura estao incluidas e nao ha remocoes implicitas.
Repita a [conferencia do Git](#4-conferir-o-que-sera-publicado) e a
[publicacao](#5-publicar-a-base-revisada), usando a branch desta contribuicao.

## 9. Reconciliar contribuicoes e publicar o consolidado

O coordenador recebe cada contribuicao sobre seu estado local mais recente.
Git mescla texto; ausencia de conflito textual nao comprova coerencia das
decisoes, da cobertura ou da proposta corrente.

1. Preserve a contribuicao em outro checkout ou pasta externa.
2. No harness habitual, execute **Planejamento: atualizar registro de migracao**
   para os projetos envolvidos, informando motivo e pasta recebida de cada projeto.
3. Execute o prompt preparado, como na [etapa 6](#6-receber-a-base-em-outra-maquina).
4. Confira registro, contexto/ranking, fichas, anexos e proposta. O registro
   recebido exige mesclagem revisada; contexto/ranking recebem decisao coerente.
5. Preserve conflitos nao resolvidos e contribuições separadas. Dois planos
   divergentes do mesmo projeto nao viram automaticamente dois lotes correntes.
   Mudancas no alcance da proposta exigem revisar o GO aplicavel.
6. Prepare uma branch de consolidacao a partir da principal atual do `simtr-doc`.
   Copie para ela somente o resultado documental reconciliado e revisado.
7. Repita as etapas de conferencia e publicacao, citando a contribuicao examinada.

Depois da reconciliacao, use este prompt para preparar a entrega:

```text
Quero preparar a publicacao do consolidado documental revisado.

Repositorio simtr-doc: [CAMINHO].
Contribuicao examinada: [BRANCH OU PR].
Projetos reconciliados: [PROJETOS].
Resultados de reconciliacao: [CAMINHOS].

Leia doc/guias/tools/compartilhamento-documental-git.md.
Confira as conclusoes, decisoes por arquivo e pendencias informadas.
Prepare uma branch documental a partir da principal atual do simtr-doc,
preservando trabalhos e contribuicoes existentes.

Copie somente os documentos reconciliados e revisados da .harness local
para .harness-jbosseap7.4, com os anexos selecionados e o filtro documental.
Preserve conflitos ainda abertos; nao escolha pelo humano nem apague
contribuicoes para produzir uma conclusao artificial.

Nao faca merge direto da contribuicao por ela estar sem conflito no Git.
Nao copie codigo, POMs, MTA ou estado operacional.
Entregue diff e proposta de descricao do PR, citando a contribuicao examinada.
Nao faca commit ou push nesta etapa.
```

**Confira:** o diff corresponde ao resultado revisado, preserva decisoes e
evidencias, identifica conflitos restantes e nao reaplica documentos antigos
por cima do consolidado. Se o PR do consolidado substituir o PR do dev,
encerre o original referenciando a integracao, sem integra-lo novamente.

Os colegas recebem o novo consolidado repetindo a etapa 6. O coordenador recebe
a proxima contribuicao sobre o estado atualizado. Codigo corrigido continua
sendo integrado no repositorio da aplicacao pelo fluxo da equipe.

## Resultado e retomada

Para retomar, localize a ultima entrega concreta: inventario, copia local,
diff revisado, PR publicado ou conclusao de reconciliacao. Continue na etapa
correspondente, preservando escolhas e documentos existentes.

A primeira acao e o inventario da etapa 2. O resultado verificavel da primeira
publicacao e o commit/PR com os arquivos revisados; o do recebimento e a
conclusao de reconciliacao com preservacao, fontes e pendencias conferidas.

Este roteiro nao instala exportador ou sincronizador automatico e nao exige
mover a `.harness` operacional. O ensaio da equipe e a publicacao de seus dados
continuam acoes distintas da entrega desta documentacao.
