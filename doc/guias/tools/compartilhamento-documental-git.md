# Compartilhar documentos da migracao em um repositorio Git

**Proposta de procedimento manual para revisao — 23/10/2026.** Usa copia seletiva,
Git e a reconciliacao existente. Ainda nao foi executada no `simtr-doc` da equipe.
Nao cria exportador, tarefa de sincronizacao ou selecao automatica de perfis.

[Voltar ao guia do desenvolvedor](../harness-migracao-desenvolvedor.md) |
[Contrato de copia e reconciliacao](compartilhamento-contextos.md).

## 1. Continuar trabalhando antes de compartilhar

Voce pode continuar priorizando, analisando, planejando e corrigindo issues no
harness atual. A `.harness` operacional permanece onde esta. A publicacao copia
os documentos selecionados para outro checkout; nao move nem limpa a origem.
O trabalho produzido antes da primeira publicacao pode integrar a base depois.

Essa continuidade depende de preservar os documentos correntes. O harness nao
reconstroi versoes antigas ja sobrescritas: registre conclusoes em fichas,
registro e evidencias nomeadas, e preserve o ANTES antes de substituir uma
evidencia. Prompts gerados podem ser regravados. O historico do `simtr-doc` passa
a guardar as versoes que forem efetivamente commitadas; o Git da ferramenta
ignora a `.harness` e nao funciona como backup desses dados.

Nao precisa encerrar a priorizacao ou todas as issues para compartilhar. Uma
fatia em andamento pode ser entregue como parcial, com seu contexto, ranking,
fichas e lacunas. Ficha criada nao comprova exame, correcao ou aceite.
Codigo corrigido continua no repositorio da aplicacao; copiar sua documentacao
nao integra esse codigo no checkout do colega.

## 2. Pastas e responsabilidades

Exemplo na maquina de cada participante:

```text
C:\desenvolvimento\repositorio\jboss-mta-harness\
  .harness\projetos\simtr-parent\       # trabalho local
C:\desenvolvimento\repositorio\simtr-doc-sync\
  .harness-jbosseap7.4\                 # copia documental no repo simtr-doc
    .gitignore
    projetos\simtr-parent\
C:\mta-runs\                           # MTA externo, organizacao atual
```

Copie o conteudo selecionado de `.harness/projetos/` para
`.harness-jbosseap7.4/projetos/`, sem adicionar outra `.harness` dentro dela.
Preserve artifactId, categorias, escopos e nomes codificados das pastas de issue.
`simtr-doc` e o repositorio documental, nao um projeto Maven a cadastrar no harness.

O coordenador prepara a base, confere contribuicoes e publica o consolidado
revisado. Cada dev usa seu harness e codigo local, recebe a base e entrega sua
contribuicao. A equipe define quem integra cada recorte; a pasta compartilhada
e o mutex local do harness nao coordenam edicoes entre maquinas.

O repositorio documental pode estar no Azure Repos ou GitHub corporativo;
nenhum fork da ferramenta e necessario. Cada maquina continua obtendo o harness
da origem que ja utiliza. Outros perfis, como Quarkus, ficam fora deste procedimento.

## 3. O que entra no repositorio documental

Caminhos abaixo sao relativos a `.harness-jbosseap7.4/`. Copie somente arquivos
existentes e pertinentes ao escopo, sem criar planos ou resultados ficticios.

- `projetos/<artifactId>/migracao.md`: decisoes, andamento e observacoes.
- `projetos/<artifactId>/atual/priorizacao/<categoria>/issues/<issue>/ficha.md`:
  analise e referencias, inclusive issues manuais DEV-....
- `projetos/<artifactId>/atual/priorizacao/<categoria>/escopos/<escopo>/contexto.json`
  **junto com** `priorizacao.md`: base, quota, candidatas e examinadas da fatia.
  Nao descarte o JSON nem recrie a priorizacao para fazer a copia.
- `projetos/<artifactId>/atual/planejamento/contexto.json`, `plano.md` e
  `tarefas.md`, quando existirem: proposta corrente, alcance e pendencias.
- `projetos/<artifactId>/evidencias/LEIA-ME.md` e os anexos selecionados, liberados
  individualmente no `.gitignore`: fundamentos das conclusoes compartilhadas.
- `projetos/<artifactId>/reconciliado/resultado.md`, quando existir: referencia
  da comparacao anterior. O recebimento produz sua propria conclusao local.
- `.gitignore` e um `README.md` opcional na raiz compartilhada: escopo,
  participantes, orientacoes e lacunas de acesso da equipe.

O modelo permite esses caminhos; ele nao prova completude nem decide quais
projetos entram. Confira os anexos referenciados por `EvidencePaths`, pelo indice
de evidencias e pelos documentos. Um log nomeado de falha de deploy pode ser
evidencia: ele nao exige copiar WAR, servidor ou todo o historico de operacoes.
Arquivos adicionais duraveis podem ser colocados em `evidencias/`, referenciados
e incluidos explicitamente. Fonte indisponivel deve permanecer como lacuna.

Em priorizacao multiprojeto, inclua o par contexto/ranking do mestre e as fichas,
registros e evidencias pertinentes dos demais participantes. Uma ficha isolada
nao reconstitui a cobertura. Receba as fichas/anexos dos participantes antes de
adotar a cobertura do mestre; todos precisam estar associados aos POMs locais.

### O que fica local

Ficam fora deste recorte: `projeto.json`, indices derivados, prompts gerados,
`atual/operacao.json`, `atual/build/`, `atual/diagnosticos/`, `atual/sprints/`,
`atual/planejamento/reconciliacao.json`, `temporarios/`, `recebido/`, estado de servidores,
backups e fixtures. WAR/EAR/JAR e produtos de build/deploy nao sao anexos deste
procedimento. Configuracoes de maquina e credenciais tambem nao entram.
Os relatorios MTA completos continuam em `C:\mta-runs`, fora desta copia.

Para sustentar uma conclusao baseada em build, teste ou Sonar, guarde somente a
evidencia documental necessaria em `evidencias/`, com origem e limites claros.
Um resultado do colega nao comprova execucao local nem integracao do codigo.
Omitir o historico operacional nao autoriza declarar verificacao sem evidencia.

### Caminhos locais e links

Os JSON de continuidade ainda contem referencias locais. Preserve-os como
produzidos: nao substitua `.harness` por `.harness-jbosseap7.4` dentro do conteudo,
nao altere IDs e nao tente torna-los executaveis no repositorio documental.
A reconciliacao realinha referencias com o POM/Source/MTA do destinatario.

Links entre documentos copiados conservam a estrutura relativa; links a codigo,
MTA, indices/prompts omitidos ou guias da ferramenta podem nao abrir no navegador
do repositorio. Os indices e prompts locais sao reconstruidos pelas operacoes
pertinentes. O indice sozinho nao realinha um contexto recebido.
Mesmo caminho `C:\mta-runs` em duas maquinas nao comprova mesmo diagnostico.

## 4. Modelo de .gitignore e conferencias antes de publicar

Use o [modelo de selecao documental](../../modelos/compartilhamento-documental.gitignore)
em `simtr-doc/.harness-jbosseap7.4/.gitignore`. Se ja existir arquivo nesse destino,
mescle as regras de forma revisada. O modelo atua somente nessa subpasta, sem
substituir o `.gitignore` geral do repositorio existente.

Se uma regra do repositorio ignorar a pasta `.harness-jbosseap7.4/` inteira,
revise uma excecao no nivel dessa regra: um `.gitignore` interno nao reabre um
diretorio pai ignorado. Use `git check-ignore -v` com um arquivo esperado para
localizar a regra. O `.gitignore` do repositorio da ferramenta permanece como esta.

O modelo ignora arquivos por padrao e libera os caminhos da secao 3. Para cada
anexo escolhido, acrescente uma excecao com caminho literal, por exemplo:

```gitignore
!/projetos/simtr-parent/evidencias/deploy-eap-7.4.11/simtr-api-deploy-falha.log
```

Essa linha e um exemplo; confira o anexo antes de publica-lo. Preserve o log
original local; se uma copia exigir retirada de dados sensiveis, identifique-a
como copia tratada e registre essa limitacao. Nao libere todos os `.log` ou JSON
indiscriminadamente. Evite `git add -f`, pois ele contorna o filtro.

O `.gitignore` nao copia arquivos nem remove arquivos ja rastreados. Se a pasta
ja tiver conteudo no Git, confira tambem `git ls-files`: excluir algo dessa
selecao futura exige revisar sua retirada do indice, preservando o arquivo local.
Nao use sincronizacao com exclusao automatica, nem copia da `.harness` inteira.
Remocoes documentais exigem decisao explicita; ausencia na contribuicao nao
significa que o arquivo deve ser apagado do consolidado.

## 5. Coordenador: preparar a primeira base

1. Confirme a URL de clonagem do **repositorio inteiro**, a branch principal real
   e o destino `.harness-jbosseap7.4/`. Use uma pasta de clone separada do harness.
   Um clone completo existente tambem serve; preserve seu trabalho pendente.
2. Para obter somente essa area em uma pasta nova, pode usar:

   ```powershell
   git clone --filter=blob:none --sparse "URL_REMOTA_DO_SIMTR_DOC" "C:\desenvolvimento\repositorio\simtr-doc-sync"
   git -C "C:\desenvolvimento\repositorio\simtr-doc-sync" sparse-checkout set --cone .harness-jbosseap7.4
   git -C "C:\desenvolvimento\repositorio\simtr-doc-sync" switch -c docs/base-jboss-eap74
   ```

   `--filter` depende do servidor; o sparse-checkout seleciona o que aparece no
   disco e mantem tambem arquivos da raiz/ancestrais. Nao remapeia a `.harness`
   operacional. Se a pasta compartilhada ainda nao existir, crie-a localmente
   e adicione os documentos; o Git nao publica diretorios vazios.
3. Instale o modelo da secao 4, escolha os projetos e copie somente o conjunto
   documental descrito na secao 3. Durante essa copia, nao deixe tarefas/agentes
   regravando o mesmo conjunto. Retome o trabalho local depois da conferencia.
4. Confira o par contexto/ranking, fichas referenciadas e anexos. Identifique
   analises parciais, lacunas, origem MTA e codigo de referencia no README ou
   descricao do PR. Nao invente rodada, validacao ou aceite para completar a base.
5. Confira o que sera versionado, no checkout documental:

   ```powershell
   git -C "C:\desenvolvimento\repositorio\simtr-doc-sync" status --short
   git -C "C:\desenvolvimento\repositorio\simtr-doc-sync" add -- .harness-jbosseap7.4
   git -C "C:\desenvolvimento\repositorio\simtr-doc-sync" diff --cached --name-status
   git -C "C:\desenvolvimento\repositorio\simtr-doc-sync" diff --cached
   git -C "C:\desenvolvimento\repositorio\simtr-doc-sync" ls-files -- .harness-jbosseap7.4
   ```

   `diff --cached` mostra as alteracoes do proximo commit; `ls-files` mostra o
   conjunto rastreado nessa area, incluindo arquivos anteriores. Revise o diff
   completo: arquivos de outros trabalhos eventualmente staged nao fazem parte
   desta publicacao. Nada foi enviado ao remoto por esses comandos.
6. Apos revisar conteudo e destinatario, faca commit, push da branch e PR no
   `simtr-doc`, pelo fluxo habitual da equipe. Nao publique esses documentos no
   repositorio pessoal da ferramenta. O restante do `simtr-doc` e preservado.

Nao basta copiar um modelo para saber o que foi enviado: o resultado verificavel
e a lista/diff do commit publicado e os arquivos da branch remota correspondente.

## 6. Desenvolvedores: receber, continuar e contribuir

1. Obtenha a base documental revisada em um checkout separado. Configure o harness
   normalmente com os POMs/Source locais e o MTA externo. Para projeto sem registro,
   use **Workspace: atualizar indice dos projetos**. Nao adote o `projeto.json`
   de outra maquina nem cadastre `simtr-doc` como aplicacao.
2. No seu harness, use **Planejamento: atualizar registro de migracao** e indique
   a pasta recebida **do projeto**, por exemplo:
   `C:\desenvolvimento\repositorio\simtr-doc-sync\.harness-jbosseap7.4\projetos\simtr-parent`.
   Essa origem externa evita copiar por cima da `.harness` que ja tem trabalho.
3. Execute o prompt preparado no agente executor, ou faca a revisao pelo fluxo
   documentado. O helper orienta; preparar o prompt nao conclui a reconciliacao.
   Confira decisoes, cobertura e fontes; mantenha conflitos pendentes. A base
   MTA exige a origem configurada; sua ausencia nao autoriza fallback silencioso.
4. Confira o indice e os documentos locais resultantes. Para uma fatia interrompida,
   preserve escopo, categoria e quota: retome o prompt existente, ou `Continue`
   sem novo percentual quando precisar regravar o preparo. Nao use `Recreate`
   apenas por ter recebido arquivos. Issues DEV-* permanecem fora da quota MTA.
5. Continue a analise/planejamento local. Escolhas, GO e aceite mantem seus limites;
   trabalho concluido pelo colega nao comprova que a corretiva esta no seu Source.
6. Para entregar, crie uma branch documental a partir da base compartilhada usada,
   copie os documentos do recorte e confira o mesmo diff da secao 5. Informe
   issues examinadas, resultado, pendencias e origem da contribuicao no PR.
   Nao copie arquivos de projetos alheios ao recorte nem use espelhamento com exclusao.

## 7. Coordenador: reconciliar contribuicoes e publicar o consolidado

1. Preserve a contribuicao do dev em outro checkout ou pasta externa. Nao troque
   sua base local pela contribuicao nem faca merge automatico so porque o Git nao
   apontou conflitos. Git mescla texto; registro e cobertura exigem conferencia.
2. Use seu harness habitual com o estado local mais recente, os Sources e MTA
   correspondentes. Execute a mesma tarefa de reconciliacao, escolhendo a pasta
   do projeto da contribuicao. Confirme os participantes antes de adotar o mestre
   de uma priorizacao multiprojeto.
3. Revise o resultado por arquivo. Preserve escolhas humanas e evidencias; registro
   recebido exige mesclagem revisada. Contexto/ranking devem ter decisao coerente,
   com base inicial, quota e examinadas conferidas. Uma divergencia nao resolvida
   permanece identificada, sem forcar uma conclusao para publicar.
4. Para o mesmo projeto existe um lote corrente. Dois planos divergentes nao viram
   automaticamente dois lotes ativos: preserve as contribuicoes separadas ate
   decidir a proposta corrente e revisar o alcance do GO.
5. Copie os documentos reconciliados para uma branch de integracao documental
   baseada na principal atual do `simtr-doc`. Confira seu diff e publique o PR do
   consolidado, citando a contribuicao examinada. Se esse PR substituir o PR do
   dev, encerre a contribuicao referenciando a integracao, sem integra-la novamente
   por cima do resultado revisado.
6. Receba a proxima contribuicao sobre esse estado atualizado. Os devs recebem
   o novo consolidado pelo passo 2 da secao 6, preservando seu trabalho local.

O consolidado e o conjunto documental revisado nos mesmos caminhos, nao um novo
JSON agregado. A reconciliacao nao executa build, deploy, MTA ou corretivas, nem
transfere aceite. Resolucao do conflito documental e integracao do codigo sao
verificacoes distintas. O fluxo completo esta no [guia de copia](compartilhamento-contextos.md#conflitos-e-limites).

## 8. O que revisar antes de iniciar com a equipe

- Destino corporativo, nome `.harness-jbosseap7.4`, participantes e responsavel
  pela integracao documental; URLs e permissoes reais ainda nao foram examinadas.
- Projetos/categorias/escopos da primeira base, pares contexto/ranking e anexos
  que entram; conferir exclusoes com o modelo e com o diff real.
- POMs e diagnosticos acessiveis em cada maquina, com lacunas registradas.
- Um recebimento de teste com dois devs: alteracoes distintas e divergencia
  intencional no mesmo registro, verificando preservacao do local, da quota,
  das fichas/anexos e das escolhas. Esse ensaio de equipe ainda esta pendente.

Para obter a lista concreta na maquina de trabalho, use este pedido no Copilot
ou no agente de sua escolha, informando o escopo quando ainda nao estiver claro:

```text
Leia doc/guias/tools/compartilhamento-documental-git.md e o modelo de .gitignore
referenciado. Quero conferir a futura base documental no simtr-doc.
Examine somente os projetos do escopo informado na .harness local.
Liste os caminhos existentes que entrariam, os que ficariam locais e os anexos
referenciados que precisam de inclusao explicita ou estao ausentes.
Confira os pares contexto/ranking e os participantes da priorizacao; preserve
fatia parcial, decisoes, fichas e proposta corrente. Indique lacunas e referencias
que dependerao do Source/MTA do destinatario.
Nao copie, mova, exclua, altere arquivos ou publique no Git. Nao regenere indices
ou contextos. Entregue a lista para revisao, sem considerar a mera existencia
dos documentos como exame concluido, GO ou aceite.
```

Depois dessa revisao, a primeira base pode ser publicada sem interromper a
migracao. Para cada entrega, confira o conjunto estavel e retome o trabalho
local; nao e necessario esperar uma futura externalizacao da `.harness`.

## Referencias

- [Estado corrente e identidade](../../adr/0009-estado-corrente-por-projeto.md).
- [Priorizacao e continuidade](priorizacao-issues.md#fatias-e-continuidade).
- [Git sparse-checkout](https://git-scm.com/docs/git-sparse-checkout) e
  [clone parcial](https://git-scm.com/docs/git-clone).
- [.gitignore e arquivos ja rastreados](https://git-scm.com/docs/gitignore).
- [Criar repositorio no Azure Repos](https://learn.microsoft.com/en-us/azure/devops/repos/git/create-new-repo?view=azure-devops).
