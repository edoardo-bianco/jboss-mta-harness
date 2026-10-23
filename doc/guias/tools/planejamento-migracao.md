---
html:
  embed_local_images: true
  embed_svg: true
  offline: true
---

# Planejamento e reconciliacao da migracao

[Voltar ao fluxo principal](../harness-migracao-desenvolvedor.md#roteiro-onde-estou-e-o-que-escolho).

Use **Planejamento: planejar** para criar, retomar ou atualizar a proposta do lote
atual. O registro concentra sua escolha e as evidencias; o preparo recupera essas
entradas e aponta documentos em caminhos fixos do projeto.

## Orientacao com o helper

No Codex, use `$orientar-migracao`; no Copilot, `migracao_helper`.

```text
Quero continuar o lote atual do projeto meu-servico. Consulte seu indice,
registro, plano e ultimas evidencias. Indique uma proxima acao com o link certo.
```

O helper localiza os arquivos, recupera escolhas existentes e pergunta somente
o essencial ausente. Ele continua leitor: redigir proposta, executar corretivas,
dar GO e aceitar resultado pertencem a etapas distintas.

### Dossie por issue e passagem entre colegas

Fichas pertencem ao projeto/categoria/issue. Plano e tarefas pertencem ao lote
corrente do projeto; o recorte identifica quais issues estao sendo trabalhadas.
Outra frente independente usa outra raiz. Exemplo de organizacao:

```text
.harness/projetos/meu-servico/
  projeto.json
  indice.md
  migracao.md
  evidencias/LEIA-ME.md
  atual/planejamento/
    contexto.json
    planejar-lotes.prompt.md
    plano.md
    tarefas.md
  atual/priorizacao/<categoria>/issues/<issue>/ficha.md
  reconciliado/resultado.md
```

`meu-servico` e o artifactId literal do POM selecionado. O harness codifica os
nomes de categoria/issue quando necessario para o sistema de arquivos; navegue
pelos links. Nao e necessario montar nomes tecnicos ou interpretar hashes.
Uma ficha guarda achados essenciais, referencias e roteiro; o detalhe MTA fica
no relatorio original. Anexos humanos continuam na origem referenciada.

Compartilhe por [copia da estrutura do projeto](compartilhamento-contextos.md).
Uma ficha permite investigar; plano e tarefas permitem revisar a proposta.
Confira Source local, fontes e alcance do GO antes de implementar o recebido.

## Configuracao

Use workspace salvo com os projetos Maven e suas ferramentas configuradas.
Se faltar registro, execute **Workspace: atualizar indice dos projetos**.
O indice geral `.harness/indices/projetos.md` abre o indice de cada projeto,
que leva ao registro, diagnosticos, fichas e plano. Settings Maven opcionais
permanecem null; valem os padroes da maquina.

## Uso

### Qual caminho seguir

| Situacao | Proxima acao |
| --- | --- |
| Ainda nao escolhi o problema | Conferir registro ou usar [priorizacao opcional](priorizacao-issues.md) |
| Escolha e evidencias registradas | **Planejamento: planejar** |
| Quero consultar proposta existente | **Planejamento: abrir plano e to-do** |
| Novas evidencias coerentes com o lote | Atualizar referencias e usar **Planejamento: planejar** |
| Conflito, contribuicao recebida ou nova comparacao necessaria | **Planejamento: atualizar registro de migracao**, com motivo |
| Proposta revisada e GO para o escopo | **Aplicacao: preparar implementacao do lote** |

### Indice da situacao dos projetos

O indice e navegacao derivada; o registro guarda a decisao humana. Atualizar o
indice preserva escolhas e notas. Links preferem HTML do MTA, resumo Sonar,
log do build e orientacoes Markdown. A ultima tentativa e o ultimo diagnostico
utilizavel aparecem separados; falha recente nao atualiza por si so o diagnostico
anterior. Fonte indisponivel e lacuna, nao sucesso.

O indice geral apresenta tabela resumida com links, contagens MTA por categoria,
cobertura dos totais, ultimas tentativas e documentos existentes. O quadro de
totais separa issues e ocorrencias por categoria, somando somente os projetos com
MTA utilizavel. A mesma regra em dois projetos conta duas issues. Ausencia de MTA
fica como lacuna; preparo sem plano/tarefas continua identificado como preparo.
O formato vem de [indice-projetos.template.md](../../modelos/indice-projetos.template.md).

Uma falha ao gravar associacao ou documentos locais aparece como `Atualizacao
local pendente`; ela nao retira dos totais o MTA valido e legivel que foi lido.
Os links apontam o relatorio efetivamente consultado e os documentos existentes,
que podem estar desatualizados. A limpeza repete bloqueios transitorios do
Windows de forma limitada. Se persistir, libere o diretorio em uso e repita a
tarefa; nao apague material de recuperacao. Publicacao realmente interrompida
exige recuperacao consistente e preserva conflitos com edicoes humanas.

O indice de cada projeto localiza POM/Source, registro e documentos correntes.
Objetivo/limites e escolhas ficam em migracao.md; analise e direcao da corretiva
ficam na ficha. O detalhe original do MTA e aberto pelo link ao relatorio.
Essa [divisao entre documentos](../../modelos/README.md#informacao-em-um-so-lugar)
mantem o resumo util sem repetir catalogos, decisoes ou analises em varios lugares.

Os prompts preparados vinculam os modelos obrigatorios de plano, tarefas e ficha.
O agente deve le-los e preencher as secoes apos examinar as fontes, preservando
decisoes anteriores. Consulte o [inventario de saidas e consumidores](../../modelos/README.md).

### Planejar lotes de correcao com Copilot

O mesmo procedimento vale no Codex e no preenchimento manual.

#### Registro de migracao por projeto

<a id="orientar-registro-e-escolha"></a>

Abra `migracao.md` pelo indice. Marque **ANALISAR AGORA** em **Decisao**, preserve
**Andamento** como retrato do trabalho real e descreva o recorte nas observacoes.
Conserve as colunas existentes e os links de ficha/evidencias. A mesma regra em
dois projetos continua sendo dois achados independentes.

O registro traz uma legenda padrao de decisao, andamento, presenca e referencias,
com links para o guia e o modelo da ficha. Atualizar o indice atualiza esse bloco
de orientacao, preservando escolhas e texto humano fora dele.

**Quando a ficha e criada:** ao examinar efetivamente uma issue na priorizacao
ou no planejamento, pelo executor do prompt ou pelo desenvolvedor. Gerar o indice
ou preparar o prompt nao preenche fichas. Quem planeja diretamente uma issue
tambem cria/atualiza a mesma ficha, sem exigir priorizacao anterior. A ficha ja
existente e reutilizada, conforme o [roteiro de preenchimento](priorizacao-issues.md#como-ler-a-ficha).

Problemas sem MTA podem ser registrados como issues manuais `DEV-...`, com titulo,
evidencias e limites. O identificador funcional permite reconhecer o problema;
nao e um ID de execucao. A base **EVIDENCIAS** usa somente o que foi fornecido.
Base **MTA** referencia o relatorio atual, sem fabricar snapshot, RunId ou copia
consolidada. Indisponibilidade do relatorio nao troca a base automaticamente.

Use **Planejamento: criar pasta de evidencias** para abrir
`evidencias/LEIA-ME.md`. Na tabela, informe Issue, Arquivo e Relacao; `*` indica
evidencia geral. O contexto inclui linhas das issues escolhidas e referencias
gerais, preservando lacunas de arquivos ainda indisponiveis.

#### Registrar uma issue manual

Uma issue manual e um achado real de log, teste ou conferencia local, sem regra
MTA. Ela participa do registro, da contagem, da priorizacao da categoria
`manual` e do planejamento/implementacao. O ID `DEV-...` e generico: nao ha
tratamento especial para uma aplicacao ou um problema especifico.

O executor deve reutilizar uma issue existente para o mesmo problema e conferir
`projeto.json`, POM/Source, `migracao.md` e evidencias. O helper apenas orienta.

**Cadastro integrado.** Na raiz do harness, use a API em vez de montar a pasta
e a linha da tabela manualmente:

```powershell
Import-Module .\scripts\HarnessProject.psm1 -Force -DisableNameChecking
Import-Module .\scripts\HarnessIssues.psm1 -Force -DisableNameChecking
$projeto = Get-HarnessProjectStorage -Root (Get-Location).Path -Pom 'C:\repositorios\minha-aplicacao\pom.xml'
Register-HarnessManualIssue -Project $projeto -Id 'DEV-EXEMPLO-01' -Title 'Falha observada no deploy'
```

O cadastro publica a ficha inicial e a linha do registro juntos. Usa categoria
`manual`, ocorrencias `-`, presenca `MANUAL`, decisao `A DEFINIR` e andamento
`NAO ANALISADA`. Repetir preserva analise, titulo e escolhas existentes.
A ficha inicial exige exame e preenchimento pelo executor; criar arquivo nao e
analisar. O indice do projeto mostra as contagens de cadastro, separadas entre
manuais, MTA presentes e nao reencontradas. Essas contagens nao comprovam resolucao.

Use `-LocalPaths` e `-EvidencePaths` para os caminhos relativos pertinentes.
`LocalPaths` parte do Source; `EvidencePaths` parte de `evidencias/`, sem
repetir esse prefixo. A API nao coleta nem inventa logs. Guarde o original em
`evidencias/` e relacione Issue, Arquivo e Relacao no `LEIA-ME.md`.
Identifique origem, estado ANTES/DEPOIS e limites. Horario do evento nao comprova
horario da coleta; texto fornecido pelo desenvolvedor deve ser identificado assim.

**Pastas legiveis para todas as fichas.** O ID completo permanece no bloco
`ficha:identidade`; o nome da pasta serve para navegacao. Exemplos:

- `DEV-SWAGGER-JACKSON-01` usa `manual/issues/DEV-SWAGGER-JACKSON-01/ficha.md`.
- `eap7/weblogic/tests/data::hibernate4-00039` usa
  `mandatory/issues/eap7-weblogic-tests-data--hibernate4-00039/ficha.md`.

O gerador transforma separadores/caracteres inadequados em nomes legiveis;
nao trunca nem acrescenta hashes. Confere colisoes sem diferenciar caixa no
Windows e considera o caminho completo, inclusive a area de publicacao
temporaria. Caminho longo ou colisao interrompe a operacao com os destinos/IDs
a conferir; use raiz mais curta quando necessario. Nao invente sufixo ou alias.
A identidade e lida da ficha, nunca reconstruida a partir do nome simplificado.

Obtenha o caminho por `Get-HarnessIssuePath -Project $projeto -Category manual
-Id 'DEV-EXEMPLO-01'` e gere links por `Get-HarnessSourceLink`, passando caminhos
literais. Pastas antigas codificadas continuam sendo reconhecidas; nao crie
uma segunda ficha para substituir uma analise existente.

**Reparo de uma manual antiga.** Depois de atualizar o harness, use o mesmo POM
e ID. A primeira chamada so informa os arquivos que mudariam:

```powershell
Repair-HarnessManualIssue -Project $projeto -Id 'DEV-EXEMPLO-01'
Repair-HarnessManualIssue -Project $projeto -Id 'DEV-EXEMPLO-01' -Apply
```

O reparo transfere a ficha e seus arquivos da pasta antiga para a legivel,
corrige os links nos documentos correntes do projeto e os caminhos do contexto
de planejamento. Preserva o ID, analise, escolhas, pendencias e bytes dos logs.
Nao altera material recebido, codigo, MTA, build ou deploy. Destino divergente,
inclusive um `ficha.md` vazio criado no lugar errado, e recusado antes da escrita.
Compare os arquivos; se o destino contiver apenas um rascunho descartavel,
preserve-o em `.harness/backups-temporarios/<atividade>/` com seu caminho
relativo antes de repetir. Nunca sobrescreva outra analise para resolver um link.
Referencias em outros projetos ou repositorios precisam de conferencia propria.

Confira separadamente o destino no filesystem e o clique no preview usado pelo
desenvolvedor. Sem acesso ao editor, declare o clique pendente. Nao alegue que
`Test-Path` comprova o comportamento do preview nem atribua falha a cache sem evidencia.

**Priorizacao e planejamento.** Selecione categoria `manual` para comparar os
achados manuais com base no registro, fichas, codigo e evidencias, sem exigir MTA.
As categorias MTA conservam seus proprios conjuntos; uma manual nao vira
`mandatory`. A contagem atual cresce no cadastro, mas `InitialTotal` e a quota
de uma fatia iniciada permanecem fixos. Novas issues entram nessa base mediante
`Recreate` explicito. `Continue` conserva base, quota e examinadas registradas.

Para planejar a propria issue manual, marque `ANALISAR AGORA` no registro e use
**Planejamento: planejar**, com base **EVIDENCIAS** quando apenas manuais forem
selecionadas. O plano considera ID, achado, ficha, evidencias e escolhas; define
corretiva, verificacoes e aceite. Implementacao exige GO; verificacoes e aceite
continuam separados.

**Reiniciar a priorizacao.** Quando o humano escolher comecar novamente, use
`Recreate` com o percentual/categoria/escopo escolhidos. Reinicia base e cobertura,
mas preserva fichas/notas e registro. Nao apague toda a `.harness`.
Fichas antigas podem ser reaproveitadas apos releitura; sua existencia nao conta
como exame na nova fatia. Para retomar sem reiniciar, use `Continue` sem novo
percentual em `IN_PROGRESS`. Veja [fatias e continuidade](priorizacao-issues.md#fatias-e-continuidade).

Prompt de reparo para o executor (substitua os campos):

```text
Repare a issue manual [ID] do projeto [artifactId], usando o harness atualizado.
Leia AGENTS.md, Registrar uma issue manual no guia, projeto.json, migracao.md,
a ficha completa e evidencias/LEIA-ME.md. Nao criar outra analise nem mudar o ID.

Confirme que HarnessIssues.psm1 oferece Repair-HarnessManualIssue. Se nao
oferecer, informe a versao ausente; nao improvise renomeacao em versao antiga.

Localize a ficha pela identidade. Compare a pasta antiga e a legivel.
Se a legivel contiver exclusivamente ficha.md vazio ou somente "# ficha",
sem identidade nem conteudo util, autorizo mover esse rascunho para
.harness/backups-temporarios/reparo-ficha-manual/, preservando o caminho
relativo. Confira os caminhos absolutos; nao sobrescreva backup existente.
Se houver outro conteudo, preserve ambas e relate o conflito.

Use Repair-HarnessManualIssue primeiro sem Apply e confira a previa;
depois aplique o reparo autorizado. Preserve analise, registro/escolhas,
log original e indice de evidencias. Confira EvidencePaths relativos a evidencias/.
Atualize o indice e verifique que o registro aponta para a ficha completa
na pasta legivel. Confira o clique no preview; se nao tiver acesso, declare pendente.
Nao use testes de filesystem como prova de clique no editor.

A recriacao da priorizacao foi permitida, mas exige identificar a categoria,
escopo e percentual escolhidos. Informe os preparos existentes e os parametros
para Recreate; nao execute o exame nem invente escolhas ausentes.
Nao execute corretivas, deploy ou MTA, nem atribua GO/aceite.
Relate arquivos alterados, preservacao verificada e pendencias.
```

#### Manter o registro e adotar outra origem

<a id="reconstruir-a-pasta-usando-um-mta-existente"></a>
<a id="reconciliar-status-antes-de-atualizar-o-plano"></a>
<a id="orientar-reconciliacao-e-continuidade"></a>

Use **Planejamento: atualizar registro de migracao** quando houver motivo
concreto: comparar diagnostico novo, conciliar contribuicao recebida ou resolver
contradicao entre registro, evidencias e proposta. A tarefa prepara referencias
e prompt, com pasta recebida opcional; nao altera suas escolhas nem conclui a
comparacao. O executor confere as fontes e publica conclusao/pendencias em
`reconciliado/resultado.md`, preservando decisoes humanas e conflitos.

A origem MTA consultavel vem da associacao do projeto; confira sua configuracao
e o relatorio encontrado. Uma analise mais recente atualiza a fonte consultavel,
mas nao comprova resolucao nem muda o escopo autorizado. Nao e preciso reconciliar
apenas porque o registro diz PENDENTE ou porque a branch mudou. Sem comparacao
suficiente, a proposta explicita seu carater preliminar.

#### Preparar e executar o prompt

<a id="orientar-planejamento-e-go"></a>

1. Registre escolha/recorte e referencias. Execute **Planejamento: planejar**.
2. A tarefa resolve o projeto; havendo ambiguidade real, escolha o registro.
   Ela prepara `contexto.json` e `planejar-lotes.prompt.md`. Plano e tarefas sao
   escritos pelo executor ou pelo desenvolvedor, nos destinos informados.
3. No Codex, envie **Execute o prompt deste arquivo: `<caminho real exibido>`**.
   No Copilot, abra o arquivo e use **Executar Prompt** com o perfil compativel.
   O preparo nao executa o agente.
4. Esclareca somente lacunas que mudem escopo, solucao ou aceite. O executor
   preserva o rascunho e o lote, sem inventar uma proposta completa enquanto
   faltar decisao essencial.
5. Revise plano/tarefas e decida o GO. A existencia dos arquivos nao o concede.

Retomar usa os mesmos caminhos, preservando texto humano. Mudanca conhecida de
escopo, base ou referencias pede revisao da proposta e do alcance do GO.
Um arquivo pode mudar no mesmo caminho: releia a evidencia e o codigo pertinente.
Nao existe cadeia de solicitacoes a reconstruir para continuar.

#### Montar as referencias manualmente

O desenvolvedor tambem pode escrever a parte dinamica do pedido no chat ou num
arquivo Markdown. Use nomes e links reais; o agente consulta os guias/contratos
locais conforme a etapa. Exemplo para preencher:

```text
Projeto: meu-servico; pasta: <caminho real do projeto no harness>.
Objetivo: revisar o lote atual com as novas evidencias.
Registro: <link de migracao.md>. Plano/tarefas: <links correntes>.
Evidencias: ultimo build, MTA atual, ultimo resultado Sonar e <anexo escolhido>.
Restricao: manter Java 8, javax e EAP 7.4; preservar o recorte registrado.
Confira quais arquivos sustentam essas referencias, suas datas e lacunas.
Distinga tentativa que falhou de diagnostico utilizavel; nao escolha GO por data.
```

Esse texto e uma entrada humana, sem exigir a criacao manual de contexto JSON,
ID tecnico ou hash. O agente localiza os documentos correntes e cita o que leu;
se houver varios projetos/fontes possiveis, esclarece somente essa ambiguidade.
Operacoes automatizadas continuam usando o contexto produzido pelas tarefas.
Para redigir manualmente plano/tarefas, use os mesmos destinos e o
[contrato](../../contratos/fluxo-migracao.md#planejamento-de-um-lote).

#### Preparar contexto por automacao, sem menus

```powershell
.\scripts\preparar-planejamento.ps1 -WorkspacePath .\meu-workspace.code-workspace `
  -MigrationPath .\.harness\projetos\meu-servico\migracao.md -NonInteractive -NoOpen
```

Tambem e possivel informar o `ContextPath` corrente. `-OutputFormat Json` exige
`-NonInteractive -NoOpen`. A operacao `revisar-lote` e compatibilidade para a mesma
entrada; IDs de solicitacao/rodada e selecao por data nao fazem parte dessa CLI.

#### Como se forma o lote, o plan.md e o todo.md

Um lote consistente por projeto, com cobertura parcial explicita. O plano tem
nove secoes: identificacao/origem; objetivo/escopo; evidencias/premissas;
alteracoes; dependencias/ordem; passos E1/E2; verificacoes/aceite; riscos/reversao;
decisoes humanas. As tarefas cobrem preparacao, implementacao, verificacoes,
evidencias dos resultados e revisao/aceite, vinculadas aos passos do plano.
Secoes nao aplicaveis recebem justificativa. Use `plano.md` e `tarefas.md` locais;
`tasks/` pertence exclusivamente a evolucao do harness.

#### Localizar documentos e identificar o historico

<a id="recuperar-um-preparo-apos-limpeza"></a>

Abra o indice do projeto ou **Planejamento: abrir plano e to-do**. Os destinos
correntes funcionam mesmo com MTA indisponivel. Notas e decisoes humanas permanecem
nos documentos; o harness guarda somente o estado corrente e a ultima conclusao
de conciliacao. A limpeza corrente preserva esses arquivos. O conversor legado
foi retirado. Para inicio novo, configure a origem MTA externa e atualize o
indice; o relatorio nao recupera decisoes, fichas ou planos humanos antigos.

#### Compartilhar o MTA e planejar em outra maquina

Compartilhe a pasta completa do relatorio, incluindo `index.html`, `output.js`
e os recursos usados pelas paginas HTML, e associe sua
origem ao projeto local. Confira o codigo/POM atual para avaliar aplicabilidade;
diferencas de caminho ou branch nao provam incompatibilidade. O detalhe exige
acesso ao relatorio. Para fichas, planos e evidencias humanas, siga a
[copia entre colegas](compartilhamento-contextos.md).

#### Revisao manual do plano e do to-do

<a id="revisar-um-lote-com-evidencias-complementares"></a>

Confira objetivo, arquivos/simbolos, compatibilidade Java 8/javax/EAP 7.4 e
Hibernate 5.3 quando aplicavel, dependencias, verificacoes observaveis e reversao.
Links devem abrir fontes reais; lacunas permanecem explicitas. Nova evidencia
entra por referencia, seguida de revisao do impacto no lote atual.

#### Da proposta revisada a execucao e ao aceite

<a id="orientar-verificacoes-e-aceite"></a>

Proposta, revisao/GO humano, execucao autorizada, verificacoes e aceite humano
sao etapas separadas. Registre a decisao e seu escopo. Build/testes aprovados
nao aceitam a corretiva. Sonar e novo MTA sao checklist nao bloqueante; falta de
comparacao continua pendente. A meta de cobertura unitaria da parte corrigida e
85% via JaCoCo, com warning abaixo da meta. Falhas reais de teste/build exigem
tratamento. Proximo lote so depois da corretiva, verificacoes, aceite e pedido
de continuidade; ausencia de uma issue no MTA nao demonstra resolucao global.

#### Preparar implementacao do lote

<a id="orientar-implementacao"></a>

Use **Aplicacao: preparar implementacao do lote**. Confira plano/tarefas atuais,
alcance do GO e trabalho ja feito. A tarefa oferece escolha explicita de branch:
criar/usar `lote/<ID-do-lote>`, continuar na atual ou nome manual. Sem padrao e
sem push; essa escolha nao concede GO. Gestao Git continua com o desenvolvedor.

Execute o prompt de implementacao no cliente escolhido com autorizacao para o
escopo. O orientador continua leitor. O executor registra mudancas, cobertura,
testes e lacunas nos documentos correntes. Para revisar resultado, consulte os
guias de [build](maven.md), [Sonar](sonar.md), [MTA](mta.md) e [JBoss](jboss.md)
conforme os criterios do lote, preservando as evidencias e a decisao humana.

## Resultado e proximo passo

Confira o plano, tarefas, fontes e a decisao que falta. Se a proposta estiver
pronta, revise o GO; se executada, confira verificacoes e aceite. O indice
localiza os documentos atuais para retomar em outro chat ou cliente.
