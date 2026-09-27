# Diagnostico de branches com Git e TortoiseGit

Adaptado do guia `guia_diagnostico_diferencas_develop_feature_tortoisegit.md`
fornecido pelo desenvolvedor em 2026-09-27. Esta versao relaciona o diagnostico
ao [fluxo do harness](harness-migracao-desenvolvedor.md#branches-e-conferencia-git).
O original permanece no local de origem. Este procedimento compara conteudo e
historico; integracao, resolucao de conflitos e publicacao seguem a revisao e o
fluxo Git da equipe. Comparar branches nao autoriza merge nem deploy.

## Escolher a direcao da comparacao

Use **DESTINO** para a branch que recebera alteracoes e **ORIGEM** para a que as
fornece. Os exemplos usam `main`; na equipe, substitua por `develop` e
`develop_jboss_eap74` quando esses forem os nomes acordados.

| Momento | DESTINO | ORIGEM | O que revisar |
| --- | --- | --- | --- |
| Trazer evolutivas para a migracao | `origin/main_jboss_eap74` | `origin/main` | Novidades da principal e impacto nas corretivas ja integradas. |
| Integrar um lote aprovado | `origin/main_jboss_eap74` | `origin/lote/cache-hib-001` | Somente o escopo aprovado e suas dependencias/testes. |
| Entregar a migracao validada | `origin/main` | `origin/main_jboss_eap74` | Conjunto final de corretivas, alinhamento com evolutivas e evidencias da release. |

A branch do lote e um exemplo: ela so existe depois de definida a proposta e
criada pelo desenvolvedor. Use referencia local para trabalho ainda nao publicado
e registre essa escolha; `origin/...` representa apenas o estado obtido no ultimo
fetch. Nao compare um projeto usando as branches do repositorio do harness.

## Preparar o diagnostico

Na raiz Git da aplicacao, confira o checkout e atualize as referencias remotas:

```powershell
git status --short --branch
git fetch origin --tags
```

Preserve alteracoes locais. Fetch atualiza referencias/objetos e nao integra
automaticamente a branch atual. Se falhar, nao considere os dados remotos atuais.
Veja a [documentacao de fetch](https://git-scm.com/docs/git-fetch).

No PowerShell, selecione **um par** da tabela. Exemplo: trazer a principal para EAP 7.4.

```powershell
$branchDestino = 'origin/main_jboss_eap74'
$branchOrigem = 'origin/main'
git rev-parse --show-toplevel
git rev-parse $branchDestino
git rev-parse $branchOrigem
```

Registre repositorio, referencias, os dois hashes e data da consulta na revisao
do lote/PR. Se uma referencia nao existir, esclareca o nome/publicacao antes de
prosseguir. Nao crie branches apenas para conseguir executar uma comparacao.

## Comparar conteudo e historico

Execute com o par escolhido:

```powershell
git diff --name-status "${branchDestino}...${branchOrigem}"
git diff --stat "${branchDestino}...${branchOrigem}"
git diff "${branchDestino}...${branchOrigem}"
git log --oneline "${branchDestino}..${branchOrigem}"
git diff --name-status $branchDestino $branchOrigem
git log --left-right --graph --oneline "${branchDestino}...${branchOrigem}"
```

| Comparacao | Interpretacao |
| --- | --- |
| `git diff DESTINO...ORIGEM` | Mudancas da origem desde o ancestral comum. A ordem importa. |
| `git diff DESTINO ORIGEM` | Diferencas entre os dois conteudos atuais. Equivale a `git diff DESTINO..ORIGEM`. |
| `git log DESTINO..ORIGEM` | Commits alcancaveis na origem e ausentes do historico do destino. |
| `git log --left-right DESTINO...ORIGEM` | Commits exclusivos: `<` no destino, `>` na origem. |

Os tres pontos possuem significados diferentes em diff e log. O diff desde o
ancestral comum ajuda a revisar a proposta; nao simula o resultado do merge nem
garante ausencia de conflitos. Confira [git diff](https://git-scm.com/docs/git-diff)
e [git log](https://git-scm.com/docs/git-log).

Na lista de arquivos, `M` indica modificacao, `A` adicao, `D` exclusao e `R`
renomeacao detectada. Revise especialmente POMs, versoes, configuracoes e arquivos
compartilhados entre lotes. Diff direto vazio significa conteudo igual nos dois
snapshots; nao comprova igualdade de historico, testes aprovados ou aceite.

Depois da integracao, um diff direto ainda pode mostrar diferencas porque o
destino recebeu outras alteracoes. Com squash/cherry-pick, commits podem continuar
aparecendo como exclusivos apesar de suas mudancas terem sido incorporadas.
Investigue conteudo e historico juntos; nao reaplique uma corretiva apenas pela
contagem de commits nem exija que a migracao fique identica a principal enquanto
ainda contem corretivas pendentes de entrega.

## Investigar visualmente no TortoiseGit

1. No repositorio da aplicacao, abra **TortoiseGit > Browse References**.
2. Selecione as duas referencias do par escolhido, por exemplo
   `refs/remotes/origin/main_jboss_eap74` e `refs/remotes/origin/main`.
3. Use a comparacao das duas referencias e confira quais revisoes ocupam cada
   lado. Essa comparacao direta mostra os estados finais; nao presuma que equivale
   ao diff de tres pontos desde o ancestral comum.
4. Abra os arquivos relevantes para comparacao linha a linha. A ferramenta pode
   ser TortoiseGitMerge ou outra configurada pelo desenvolvedor.
5. Use **Show Log** para autores, commits e arquivos. Selecione duas revisoes e
   use **Compare revisions** para comparar seus conteudos.
6. Use **Revision Graph** para entender divergencias e integracoes. O grafo ajuda
   a explicar o historico; o diff confirma o conteudo efetivo.

Referencias: [Browse All Refs](https://tortoisegit.org/docs/tortoisegit/tgit-dug-browse-ref.html)
e [Viewing Differences](https://tortoisegit.org/docs/tortoisegit/tgit-dug-diff.html).
Os nomes dos menus podem variar com idioma e versao instalada.

## Aplicar o diagnostico nos tres momentos do fluxo

**Principal para EAP 7.4:** revise as evolutivas, coordene impactos e integre pelo
fluxo aprovado da equipe. No checkout atualizado da migracao, execute build,
testes e novo MTA completo. Reconcile os lotes afetados antes de retoma-los.

**Lote para EAP 7.4:** confira o diff contra o escopo aprovado, evidencias e revisao
humana. Depois de integrar, revalide o commit resultante, incluindo novo MTA.
Relatorios de commits individuais nao substituem o relatorio da base integrada.
O proximo lote parte dessa base, apos aceite e pedido de continuidade.

**EAP 7.4 para principal e producao:** conclua a cobertura e obtenha aceite humano
final da migracao. Antes do PR final, confira novas evolutivas da principal e
revalide sua incorporacao na migracao. Revise e integre conforme a politica da
equipe; valide o commit resultante na principal. Identifique release/tag e artefato
aprovados, ambiente EAP 7.4 de destino e procedimento de rollback antes da
autorizacao de implantacao. Merge nao significa deploy: promover o artefato e
uma etapa separada. Este harness ainda nao automatiza release/deploy em PRD.

Para comparar uma release identificada, use uma tag existente como ORIGEM:

```powershell
git diff --name-status origin/main v1.2.0
```

`v1.2.0` e ilustrativa. Registre a tag/commit e a identidade do artefato realmente
testado; igualdade de codigo por si so nao comprova equivalencia do binario.

## Registro minimo da revisao

- Projeto/repositorio, modulo, destino/origem, hashes e data.
- Arquivos, commits e diferencas de comportamento identificados.
- Sobreposicoes com outras frentes e decisoes de resolucao.
- PR/decisao humana, commit integrado e evidencias de verificacao desse estado.
- Para release: artefato, destino, aceite e rollback identificados.

O agente `planejar-lotes` nao executa os comandos deste guia. O desenvolvedor ou
a etapa autorizada de execucao coleta as evidencias e disponibiliza seus caminhos
ao planejador, sem substituir os recibos historicos do harness.
