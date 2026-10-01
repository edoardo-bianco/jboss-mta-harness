# ADR-0003: vincular a migracao ao projeto, branch e estado do codigo

Status: historica; aceita em 2026-09-27, com requisitos de cadastro, papeis,
coordenacao obrigatoria e bloqueios Git substituidos pela ADR-0004 em 2026-09-28.

Atualizacao em 2026-09-28: os requisitos de cadastro, papeis, coordenacao obrigatoria
e bloqueios por Git deste texto foram substituidos pela
[ADR-0004](0004-git-informativo-sem-controle-de-branches.md). O texto abaixo
preserva a decisao historica; nao usar seus gates no fluxo atual.

## Contexto

Um workspace pode conter varios projetos e repositorios. A selecao de uma pasta
nao fixa sua branch nem o estado do codigo: o mesmo checkout pode mudar entre
planejamento e execucao. Alem disso, evolutivas continuam na branch principal
enquanto varios desenvolvedores podem corrigir a migracao EAP 7.4 em paralelo.

## Decisao

### Identidade de cada ciclo

Vincular proposta, to-do, autorizacao, execucao, verificacoes e aceite ao projeto
selecionado. Registrar nos documentos de corretivas:

- Project e Source do contexto, raiz Git efetiva e caminho do modulo dentro dela;
  identidade compartilhavel do repositorio, sem credenciais, para distinguir clones.
- Branch principal e branch de integracao da migracao definidas pelo desenvolvedor.
  Exemplos: `develop` -> `develop_jboss_eap74` ou `main` -> `main_jboss_eap74`.
  Sao exemplos, nao nomes fixos nem inferidos da branch do harness.
- Branch de trabalho autorizada, checkout/worktree, commit HEAD observado e estado
  das alteracoes locais; commits de referencia da principal e da migracao, com data
  e origem da verificacao. Referencia local antiga nao comprova alinhamento remoto.
- RequestId, RunId, lote, responsavel, escopo e referencia de coordenacao da equipe;
  commits/artefatos efetivamente validados e decisoes humanas correspondentes.

Source pode ser um modulo: conferir a raiz Git que realmente o contem. Pastas
homonimas, modulos do mesmo repositorio e clones distintos nao sao intercambiaveis.
Os exemplos dentro deste harness compartilham seu repositorio Git; nao inventar
um repositorio independente para cada exemplo nem trocar a branch do harness
automaticamente. Um MTA de outro projeto nunca e a base deste ciclo.

### Branch de migracao e verificacao antes de continuar

As corretivas pertencem a branch de migracao do projeto, separada da principal.
Antes de aplicar ou retomar uma corretiva, e novamente antes de validar/integrar,
conferir no checkout de Source a raiz Git, branch ativa, HEAD, alteracoes locais,
conflitos/operacoes Git pendentes e alinhamento com as referencias acordadas.
Nao usar o diretorio corrente do terminal ou a branch do harness como substituto.

Branch diferente da autorizada, HEAD destacado, repositorio divergente, conflito
ou alteracoes locais sem autoria/escopo esclarecidos impedem a execucao. Preservar
o trabalho existente e explicar a divergencia; nao trocar branch, limpar arquivos
ou reaplicar o lote automaticamente. Alteracoes conhecidas do proprio lote devem
ser identificadas, sem exigir uma arvore limpa durante toda a implementacao.

Mesmo na branch correta, HEAD diferente exige avaliar o diff e reconciliar o plano
antes de continuar. O GO identifica lote, branch e base revisada. Mudancas que
alterem escopo, risco, transformacao ou criterios exigem nova revisao humana;
validacoes anteriores nao aprovam automaticamente o novo estado integrado.

### Evolutivas e corretivas em paralelo

Manter a branch de migracao alinhada a principal em pontos de integracao explicitos,
antes de retomar lotes e antes do aceite da versao integrada. Registrar quais commits
da principal foram incorporados. Integrar conforme o fluxo da equipe, preservando
historico compartilhado, resolvendo conflitos e repetindo as verificacoes afetadas.
Este contrato nao autoriza merge, rebase, push ou reescrita de historico por si so.

Para trabalho paralelo, cada desenvolvedor usa checkout/worktree proprio e uma
branch de lote derivada da branch de migracao, explicitamente registrada como
branch de trabalho autorizada. Exemplo: `develop_jboss_eap74_lote_cache` integra
depois em `develop_jboss_eap74`. As corretivas nao vao diretamente para `develop`.
Em trabalho individual, a propria branch de migracao pode ser a branch de trabalho.

"Um lote ativo" significa um por frente de trabalho (projeto, branch de trabalho,
checkout e responsavel). Outras frentes podem ter lotes delimitados e coordenados,
sem exigir planejamento global antecipado. Antes de iniciar, registrar responsavel,
ocorrencias/arquivos, dependencias e sobreposicoes em referencia compartilhada da
equipe. A escolha do mecanismo cabe a equipe; arquivos locais em .harness nao sao
um lock nem informam o que outros desenvolvedores estao fazendo. Sobreposicoes
exigem coordenacao antes de editar, especialmente POMs e dependencias comuns.

### Reconciliacao e aceite

Apos integrar evolutivas ou corretivas de outra frente, comparar o estado atual
com a base do lote: algo pode ja estar resolvido, conflitar ou exigir outra solucao.
Nao reaplicar patches por haver tarefas abertas. Reexecutar build/testes e demais
verificacoes pertinentes, gerar novo MTA comparavel do estado integrado e vincular
as evidencias ao commit/artefato validado. Aceite de uma branch de lote nao equivale
ao aceite da branch de migracao depois da integracao.

Uma rodada historica pode ter sido produzida na principal ou em branch de lote.
Ela serve como baseline identificada, nunca como prova do checkout atual. Confirmar
origem e diferencas antes de usa-la; sem proveniencia suficiente, registrar pendencia
e obter nova evidencia. Nao atribuir retrospectivamente o HEAD atual a um MTA antigo.

Retomar a mesma frente preserva os documentos do contexto. Nova frente ou nova
base MTA exige solicitacao propria e vinculo anterior explicito, sem compartilhar
arquivos editaveis entre agentes. A conclusao global e avaliada na branch de
migracao integrada, reconciliada com a referencia acordada da principal, com todos
os lotes incorporados, evidencias atualizadas e aceite humano final.

### Estado da implementacao

O harness atual isola Project/Source/RunId/RequestId e verifica hashes das evidencias.
Desde 2026-09-27, coleta Git nos novos manifestos MTA, resultados de build e
contextos de planejamento. O menu registra papeis das branches por Source no JSON
local. A tarefa `Planejamento: conferir Git do lote` compara checkout, branch,
HEAD, estado local e politica com o contexto e verifica alinhamento local.
Retorna exit 1 quando ha pendencias; alteracoes locais mantem o bloqueio nesta
versao, que ainda nao registra aceite seletivo de diffs. Nao faz fetch ou integracao.
O prompt continua sem terminal: distingue Git observado no recibo, politica
declarada e origem MTA historica opcional. A execucao deve acionar a conferencia
atual e respeitar seu resultado; nao ha aplicador de corretivas nem monitoramento
continuo que impeca edicoes externas. GO/aceite humano e coordenacao remota
permanecem obrigatorios. Consulte o [guia](../guias/harness-migracao-desenvolvedor.md#branches-e-conferencia-git).

## Alternativas e consequencias

Usar somente o nome do projeto ou da branch permitiria retomar um plano sobre
outro estado do codigo. Usar a principal para as corretivas misturaria entregas.
Usar um checkout compartilhado entre desenvolvedores permitiria alteracoes
concorrentes de arquivos e branch. Essas alternativas foram rejeitadas.

Identidade e coordenacao explicitas acrescentam registro e verificacoes, mas permitem
preservar evolutivas e corretivas paralelas e rastrear qual versao foi aceita.
Esta decisao complementa e delimita o lote ativo da
[ADR-0002](0002-separacao-harness-e-migracao-progressiva.md).
