---
html:
  embed_local_images: true
  embed_svg: true
  offline: true
---

# GitHub na empresa: fork e atualizacao do harness

[Voltar ao guia do desenvolvedor](../harness-migracao-desenvolvedor.md#1-preparar-o-ambiente).

Use este roteiro para manter um fork do harness na sua conta GitHub usada na
empresa e receber as mudancas do repositorio original. As aplicacoes continuam
no Azure Repos, com seus branches, PRs e pipelines. O workspace do VS Code reune
as pastas locais desses repositorios independentes.

| Repositorio | Onde fica | Remotos no respectivo clone |
| --- | --- | --- |
| Harness original | GitHub do mantenedor | `upstream` no clone do harness |
| Seu fork do harness | Sua conta GitHub da empresa | `origin` no clone do harness |
| Aplicacoes | Azure Repos da equipe | Remotos existentes de cada aplicacao, sem alteracao |

Git faz clone, configuracao de remotos e atualizacao. Para criar o vinculo de
fork no GitHub pelo terminal, use tambem a GitHub CLI (`gh`). Criar outro
repositorio e enviar arquivos com Git, sozinho, nao registra esse vinculo.

Navegacao: [orientacao](#orientacao-com-o-helper) · [configuracao](#configuracao) ·
[com gh](#criar-o-fork-pelo-terminal) · [sem gh](#criar-o-fork-sem-gh) · [clone existente](#aproveitar-o-clone-existente) ·
[atualizar](#receber-atualizacoes-do-original) · [resultado](#resultado-e-proximo-passo).

## Orientacao com o helper

Ative `$orientar-migracao` no Codex ou selecione `migracao_helper` no cliente,
conforme o [guia de orientacao](../orientacao-migracao.md#iniciar-no-codex-ou-no-copilot).

```text
Quero manter o harness na minha conta GitHub da empresa e receber atualizacoes
do original. As aplicacoes continuam no Azure Repos.
Leia doc/guias/tools/github-empresa.md.
Meu usuario da empresa e [usuario]. Ja tenho [fork/clone/workspace ou nenhum].
Prefiro o terminal com gh e Git. Oriente uma etapa por vez, preservando meus
arquivos locais e os remotos das aplicacoes. Nao execute as operacoes por mim.
```

Se nao usar `gh`, substitua a preferencia por: "Quero criar o fork pelo navegador
e usar somente Git no terminal depois disso".

O helper identifica a etapa ja concluida, indica o comando ou a tela pertinente
e o resultado a conferir. Nao exige projeto, MTA ou registro de migracao para
esse preparo. Nao cria fork, autentica contas, troca remotos ou executa fetch,
pull e push; o desenvolvedor executa. Credenciais nao pertencem ao chat.

## Configuracao

Os exemplos usam PowerShell e contas no mesmo host `github.com`. Tenha Git e,
para criar o fork pelo terminal, [GitHub CLI](https://cli.github.com/) disponiveis
pelo procedimento da empresa. Com Git somente, crie o fork pelo navegador e
continue pelas etapas de clone e atualizacao.

| Como deseja criar o fork | Caminho |
| --- | --- |
| Pelo terminal, com gh | [Conferir a conta da CLI](#conferir-a-conta-usada-pela-cli) e [criar o fork](#criar-o-fork-pelo-terminal) |
| Sem gh | [Criar o fork no navegador](#criar-o-fork-sem-gh); clone, remotos e atualizacoes usam somente Git |

O original e publico, portanto seu fork tambem sera publico. Contas Enterprise
Managed Users nao podem fazer fork de repositorios externos a sua enterprise.
Se o destino for outro servidor GitHub ou a politica da empresa impedir o fork,
este roteiro nao se aplica diretamente; confirme a forma permitida com o
administrador. Fontes: [regras dos forks](https://docs.github.com/en/pull-requests/reference/forks)
e [contas gerenciadas](https://docs.github.com/en/enterprise-cloud@latest/admin/managing-iam/understanding-iam-for-enterprises/abilities-and-restrictions-of-managed-user-accounts).

Na sessao PowerShell em que seguira o roteiro, substitua somente o usuario:

```powershell
$usuarioEmpresa = 'SEU-USUARIO-EMPRESA'
$repositorioOrigem = 'edoardo-bianco/jboss-mta-harness'
$urlOrigem = "https://github.com/$repositorioOrigem.git"
$urlFork = "https://github.com/$usuarioEmpresa/jboss-mta-harness.git"
```

Os comandos pressupõem esse nome para o fork; ajuste a URL se escolher outro.
Execute cada bloco na ordem da etapa escolhida. Se houver erro, resolva-o antes
de continuar; os blocos sao instrucoes manuais, nao um script de automacao.

### Conferir a conta usada pela CLI

Esta secao pertence somente a rota com `gh`. Na rota sem essa ferramenta,
va direto a [criacao pelo navegador](#criar-o-fork-sem-gh).

```powershell
git --version
gh --version
gh auth status --hostname github.com
```

Se a conta da empresa ainda nao estiver autenticada:

```powershell
gh auth login --hostname github.com --git-protocol https --web
```

Conclua o login no navegador com a conta da empresa. Se ela ja estiver salva,
mas outra conta estiver ativa, selecione-a:

```powershell
gh auth switch --hostname github.com --user $usuarioEmpresa
```

Antes de criar o fork, confira o login efetivo:

```powershell
gh api --hostname github.com user --jq .login
```

O resultado deve ser o usuario escolhido. Se for diferente, corrija a sessao
antes de prosseguir. O Git pode usar credenciais de seu proprio gerenciador;
confirme a conta da empresa quando ele solicitar autenticacao. `git config
user.name` e `user.email` definem autoria de commits, nao fazem login. Preserve
a autenticacao existente do Azure Repos. Referencias: [login](https://cli.github.com/manual/gh_auth_login),
[estado da autenticacao](https://cli.github.com/manual/gh_auth_status) e
[selecao de conta](https://cli.github.com/manual/gh_auth_switch).

## Uso

### Criar o fork pelo terminal

Com a conta confirmada, execute uma vez:

```powershell
gh repo fork "https://github.com/$repositorioOrigem" --default-branch-only --clone=false --remote=false
gh repo view "$usuarioEmpresa/jboss-mta-harness" --json nameWithOwner,isFork,parent,url
```

Confira o proprietario, `isFork: true` e o original no campo `parent`. O fork
sera criado na conta autenticada; nao use `--org` para este caso. Os flags
evitam criar um clone ou alterar remotos locais nesta etapa. Se o fork ja
existir, confira sua origem e reutilize-o. Fonte: [gh repo fork](https://cli.github.com/manual/gh_repo_fork).

Com o fork conferido, escolha [clone novo](#criar-um-clone-novo) ou
[clone existente](#aproveitar-o-clone-existente).

### Criar o fork sem gh

Use o navegador uma vez para criar o fork; nao precisa instalar ou autenticar
a GitHub CLI. Depois, todas as etapas locais deste guia usam somente Git.

1. Entre no GitHub com sua conta da empresa.
2. Na barra de enderecos do navegador, abra `https://github.com/edoardo-bianco/jboss-mta-harness`, ou use o [link do repositorio original](https://github.com/edoardo-bianco/jboss-mta-harness). Ele e publico e pode ser aberto enquanto voce esta conectado com a conta da empresa; nao precisa entrar na conta pessoal.
3. No repositorio original, clique em **Fork**.
4. Em **Owner**, escolha seu usuario da empresa e mantenha `jboss-mta-harness` como nome.
5. Marque **Copy the main branch only** e confirme em **Create fork**.

Confira que o endereco tem seu usuario e que o GitHub indica **forked from
edoardo-bianco/jboss-mta-harness**. O original continua na conta pessoal; o fork
fica na conta da empresa. O fork cria um novo repositorio na conta;
nao e enviado para dentro de outro repositorio existente. Se ja existe, confira
e reutilize-o. [Procedimento do GitHub](https://docs.github.com/en/pull-requests/how-tos/work-with-forks/fork-a-repo).

No PowerShell, defina as [variaveis de configuracao](#configuracao) com o mesmo
usuario do navegador. O Git usara sua autenticacao HTTPS habitual quando
necessario. Nao execute os blocos `gh auth` ou `gh repo` da rota anterior.

Depois escolha apenas uma das duas rotas locais abaixo.

### Criar um clone novo

Em uma pasta de repositorios permitida, sem outra pasta `jboss-mta-harness`:

```powershell
git clone $urlFork jboss-mta-harness
Set-Location jboss-mta-harness
git remote add upstream $urlOrigem
git remote -v
```

O `origin` deve apontar ao seu fork e o `upstream` ao original. Configure esta
maquina pelo [guia de workspace](workspace.md#comecar-na-maquina-de-trabalho).
O clone nao traz `config/harness.local.json`, workspace local nem `.harness/`.
Nao copie configuracao pessoal de outra maquina sem revisar caminhos e ferramentas.

### Aproveitar o clone existente

Se ja usa o harness na empresa, mantenha a pasta e seus dados. Abra um terminal
**na raiz do harness**, e nao na pasta de uma aplicacao, e confira:

```powershell
git rev-parse --show-toplevel
git status --short
git remote -v
```

O bloco seguinte vale quando `origin` aponta ao original, nao existe remoto
`upstream` e a branch local `main` existe. Renomear o remoto preserva a URL
anterior; o novo `origin` aponta ao fork ja criado:

```powershell
git remote rename origin upstream
git remote add origin $urlFork
git fetch origin
git branch --set-upstream-to=origin/main main
git remote -v
```

Se `origin` ja aponta ao fork e `upstream` ao original, pule essa troca.
Se algum nome aponta a outro destino, confira a finalidade antes de altera-lo;
nao remova remotos existentes para fazer o exemplo passar. A troca de remotos
nao regrava `config/harness.local.json`, workspace local ou `.harness/`.
Mantenha tambem as entradas privadas do JBoss onde estao. A atualizacao dos
arquivos versionados ocorre na proxima etapa. [Referencia Git: remotos](https://git-scm.com/docs/git-remote).

### Receber atualizacoes do original

O fork nao recebe automaticamente cada mudanca do original. Na raiz do clone
do harness, confira o trabalho local e a branch atual:

```powershell
git status --short
git branch --show-current
```

Se houver alteracoes locais versionadas ou trabalho em andamento nesse checkout,
preserve/conclua esse trabalho antes de trocar de branch. Nao use descarte ou
limpeza para viabilizar a atualizacao. Com o checkout liberado e limpo:

```powershell
git switch main
git fetch origin
git merge --ff-only origin/main
git fetch upstream
git log --oneline main..upstream/main
```

Confira as mudancas que serao recebidas. Depois aplique-as localmente e publique
essa mesma main no seu fork:

```powershell
git merge --ff-only upstream/main
git push origin main
git fetch origin
git status -sb
git rev-parse main origin/main upstream/main
```

Quando o fork apenas acompanha o original, os tres commits devem coincidir
apos essa sequencia. O push tem como destino `origin`, seu fork. O Azure Repos
nao participa dessas operacoes. Se `--ff-only` recusar por divergencia, preserve
os commits e revise a integracao em branch propria/PR; nao use force ou reset.
Se a main do fork for protegida, siga o PR exigido pelo repositorio.
Fontes: [sincronizar forks](https://docs.github.com/en/pull-requests/how-tos/work-with-forks/syncing-a-fork)
e [fast-forward no Git](https://git-scm.com/docs/git-merge#Documentation/git-merge.txt---ff-only).

**Alternativa web:** no seu fork, use **Sync fork > Update branch**. Isso atualiza
o GitHub. Para trazer o resultado ao clone local limpo, execute `git switch main`
e `git pull --ff-only origin main`. Se houver conflitos ou commits proprios,
revise-os conforme a mensagem do GitHub/Git. [Referencia Git: pull](https://git-scm.com/docs/git-pull).

### Continuar com as aplicacoes no Azure Repos

Mantenha os clones das aplicacoes fora do clone do harness e adicione-os ao
workspace com **File > Add Folder to Workspace...**. Uma organizacao possivel:

```text
repositorios/
  jboss-mta-harness/     # GitHub: origin=fork, upstream=original
  aplicacao-a/           # Azure Repos: remotos existentes
  aplicacao-b/           # Azure Repos: remotos existentes
```

Na aplicacao, commits/PRs seguem o Azure DevOps e o fluxo da equipe. Na ferramenta,
mudancas seguem o repositorio do harness. Se precisar evolui-lo, use branch
`harness/<objetivo>` e o [guia de manutencao](../manutencao-harness.md). Manter
a main do fork acompanhando o original simplifica as proximas atualizacoes.

Nenhuma mudanca de pipeline e necessaria apenas para trocar a origem do clone
do harness. Configuracao privada, credenciais, fontes de aplicacoes e evidencias
locais continuam separadas do codigo versionado da ferramenta. A organizacao
do workspace esta no [guia de projetos](workspace.md#escolher-o-projeto-em-cada-tarefa).

## Resultado e proximo passo

Confira o fork na conta correta, a origem indicada pelo GitHub e os remotos do
clone do harness. Apos sincronizar, confira estado/commits e continue abrindo o
mesmo workspace local. O fork nao compartilha automaticamente as evidencias
da `.harness/`; para isso, siga o [guia de copia](compartilhamento-contextos.md).

Se o fork corporativo nao estiver disponivel e a necessidade for compartilhar
os documentos da migracao, revise o [procedimento documental por Git](compartilhamento-documental-git.md).
Ele usa uma pasta do repositorio existente da equipe, inclusive no Azure Repos,
e mantem a ferramenta na origem atual, com copia seletiva e reconciliacao.

Atualizar o harness nao aplica configuracoes no JBoss nem valida a migracao.
Para primeira instalacao, volte ao [preparo da maquina](workspace.md#comecar-na-maquina-de-trabalho);
para uso corrente, retome a [etapa da aplicacao](../harness-migracao-desenvolvedor.md#como-usar-este-guia).
