# Plano do agente: evolucao do harness

## Execucao da priorizacao sem retorno ao preparo - 21/10/2026

Branch `harness/execucao-priorizacao-sem-loop`, derivada de `main` em `2b41664`,
no checkout isolado C:\Temp\harness-indice-mta. Relato da maquina de trabalho:
mesmo com devsquad selecionado, o executor carregou orientar-migracao, assumiu
somente leitura e pediu novamente a execucao do mesmo prompt. Base relatada:
44 mandatory, fatia de 20% (9 issues), ainda sem exame. Nao reproduzido no cliente.

Corrigir a aplicabilidade da skill antes das regras de leitura, preservando os
perfis helpers. Execucao explicitamente pedida ao executor deve produzir as
saidas do prompt; carregar a skill nao o transforma em helper. No Copilot,
`devsquad` e o orquestrador: delega analises delimitadas e consolida fichas,
ranking e indices. Nos demais clientes, o agente principal usa
`using-agent-skills` quando disponivel; sem o recurso, segue no agente padrao.
Nao instalar/substituir o perfil externo devsquad nem inventar fallback YAML.

Conferir selecao nativa por `agent: devsquad`, limites do cliente e encaminhamento
para Agent se o perfil nao existir. Alinhar prompt, skill/ponteiro, papeis, guias
e mensagem de preparo. Preservar quota, contexto, templates, escolhas humanas e
o papel leitor dos helpers; nao executar a migracao real nesta maquina.

Verificar geracao, metadados, links e limites dos adaptadores em suites isoladas,
com revisao independente. Separar essas provas do ensaio nativo de selecao e
delegacao no Copilot, que depende da maquina de trabalho.

Implementacao e revisao local concluidas; cinco suites e navegacao passaram
conforme todo.md. Confirmado na documentacao e no codigo atual do VS Code:
`agent` e um nome unico; a execucao procura esse perfil antes de submeter o
prompt. Nao ha fallback condicional definido no cabecalho. Manter selecao nativa
de devsquad e alternativa manual Agent, sem criar extensao ou perfil substituto.
Fontes: [prompt files](https://code.visualstudio.com/docs/agent-customization/prompt-files)
e [ChatWidget, _applyPromptMetadata/_switchToAgentByName](https://github.com/microsoft/vscode/blob/main/src/vs/workbench/contrib/chat/browser/widget/chatWidget.ts).
Selecao efetiva, delegacao e producao das nove fichas reais ainda requerem ensaio
no Copilot da maquina de trabalho; nao foram simuladas como resultado obtido.

## Nome curto para priorizacao - 21/10/2026

Branch harness/priorizacao-escopo-curto, derivada de main cbe4f8a, no checkout
isolado C:\Temp\harness-indice-mta. Falha relatada somente na maquina de trabalho:
Planejamento: priorizar issues rejeita a chave funcional apos escolher mandatory.
O escopo automatico concatena os 14 artifactIds enviados: 210 caracteres,
236 depois da codificacao percentual, acima do limite de componente de 160.
Encurtar a raiz nao corrige esse limite do nome.

Decisao explicita do desenvolvedor: usar priorizacao como nome padrao fixo.
Participantes completos permanecem no contexto e categorias continuam separadas.
Preservar Scope explicito e conjuntos antigos existentes, sem renomear fichas,
perder examinadas/notas ou reassociar o mesmo conjunto a participantes diferentes.
Havendo conjunto antigo e novo para a mesma selecao, exigir a escolha do escopo.

Reproduzir com fixtures sinteticas pelo runner isolado antes de corrigir.
Validar 14 participantes, continuidade, categorias, Scope explicito,
compatibilidade e conflitos; alinhar ADR-0009 e guia. Nenhum dado real sera usado.

Implementacao concluida e validada conforme tasks/todo.md: 8 suites isoladas
passaram, revisao independente sem bloqueadores e mutacao detectada/restaurada.
Conferencia complementar dos indices/templates e consumidores concluida: mais
5 suites passaram (13 no total), com auditoria independente de guias e helpers.
Publicacao Git autorizada pelo desenvolvedor em 21/10/2026: commit, push da
branch e PR para main. Integracao e atualizacao da maquina de trabalho seguem
apos o merge da PR.

## Totais do indice por categoria - 21/10/2026

Branch `harness/indice-totais-categorias`, derivada de `main` em `57b38d8`,
no checkout separado C:\Temp\harness-indice-mta.

Pedido: o indice geral mostra categorias por projeto, mas falta essa separacao
nos totais. Acrescentar tabela no template consumido pelo gerador, somando issues
e ocorrencias por categoria nos MTA utilizaveis do escopo. A mesma regra em dois
projetos conta duas vezes; nomes das categorias e cobertura parcial permanecem
explicitos. Ausencia de diagnostico nao equivale a zero issues.

Verificar primeiro a falha no teste do resumo, depois soma entre projetos,
categorias livres, diagnostico vazio, ausencia de MTA, escopo vazio e repeticao.
Rodar suites pertinentes pelo runner isolado; nao alterar dados reais nem a main.

Escopo esclarecido: manter informacao util em um lugar definido, com templates
comuns e links. Registro guarda escolhas/progresso; ficha guarda analise/roteiro;
MTA conserva detalhe original. Restaurar legenda concisa do registro, modelo de
preenchimento da ficha e link ao Source, preservando texto humano. Fichas surgem
no exame efetivo, nao na criacao do indice/preparo.

Resultado enviado da maquina de trabalho: 12/14 MTA, 92 issues e 2981 ocorrencias;
mandatory 42/347, optional 22/2600, potential 28/34. parent-all-jee7 sem conjunto
utilizavel; siric-api excluido por bloqueio do diretorio temporarios. O indice
legado enviado depois confirma siric-api com 5/532: mandatory 2/4 e optional
3/528. Totais esperados para os mesmos relatorios: 97/3513, mandatory 44/351,
optional 25/3128 e potential 28/34, com cobertura 13/14. A lembranca de 47
mandatory nao e sustentada pelo legado fornecido.
Corrigir exclusao de input/ quando a rodada possui output/ e repeticao limitada
da limpeza sob sharing violation, sem silenciar bloqueio persistente.
Separar leitura do MTA da atualizacao local: falha ao salvar associacao ou
documentos fica como Atualizacao local pendente, sem retirar o diagnostico
valido da contagem. Leitura sob mutex aceita somente estado confirmado, sem
journal de recuperacao; publicacao realmente incompleta continua protegida.

Apos validacao e revisao independente, o desenvolvedor autorizou commit, push
e abertura da PR para main. Publicar esta branch sem executar merge.

## Auditoria independente do checkpoint - 21/10/2026

Pedido: validar coerencia do todo entre README, doc, guias, templates,
geradores e agente de orientacao, usando using-agent-skills.
Auditar 87a8725 contra eb44383 no checkout separado, com revisores independentes,
regressao isolada e parecer rastreavel. Registrar achados sem misturar corretivas
com a auditoria. Resultado: [parecer](auditoria-indice-mta-externo.md).
Dois achados P2 exigem corretiva antes da PR; um P3 documental e lacunas de
validacao tambem ficaram registrados.

## Tabela resumida e template do indice - 21/10/2026

Retomada na branch harness/indice-mta-externo, no checkout C:\Temp\harness-indice-mta.
Pedido confirmado: tabela resumida Markdown com links, sem Excel. O indice geral
corrente tinha apenas uma lista; o resumo antigo consta no historico de 01/10.
Criar template versionado consumido pelo gerador, com MTA/data, issues/ocorrencias
por categoria, ultimas tentativas e documentos existentes. Totais informam cobertura;
ausencia nao vira zero e preparo nao vira proposta. Preservar fontes/decisoes.
Validar com fixtures pelo runner isolado; concluir revisao da retirada do conversor
e preparar descricao da PR, sem merge nem alteracao de dados reais.


Escopo ampliado pelo desenvolvedor nesta sessao: verificar cada resultado humano
esperado e assegurar uso do template pelo gerador ou pelo agente via prompt.
Inventariados indice geral/projeto, registro, indices de priorizacao, ranking,
orientacao para selecionar a issue, ficha/detalhe, plano/tarefas, evidencias e
reconciliacao. Sprints ja consumia modelo. O antigo indice-priorizacao era
historico e sem consumidor; foi substituido pelo modelo corrente.
A orientacao padronizada deve ligar ao migracao.md, explicar ANALISAR AGORA,
Observacao/referencia e Planejamento: planejar, sem escolher pelo humano.
Fichas permanecem unicas por projeto/categoria/issue, sem copias por fatia.
Validar consumo real alterando templates somente na copia de teste; prompts
preparados precisam vincular os modelos inclusive apos reconciliacao/realocacao.

## Retirada da conversao legada - 20/10/2026

Pedido explicito: iniciar pelo layout corrente e pelos relatorios MTA externos,
sem converter o estado antigo. Na branch harness/indice-mta-externo, retirar
tools/transicao e fixtures/suites exclusivas da conversao em commit separado.
Alinhar guias, contratos e orientador para iniciar pelo indice; preservar o
historico das entregas anteriores, indicando que o utilitario foi retirado.
Verificar ausencia de dependencias no runtime e executar as suites correntes
pertinentes em copia isolada, sem limpar ou converter dados reais.
Pausa solicitada em 20/10/2026: salvar os dois commits na branch remota, sem merge.
A retomada e os resultados estao no topo de tasks/todo.md. Revisao final da
retirada e preparacao da PR ficam para a proxima sessao.

## Indice com MTA externo configurado - 20/10/2026

Branch `harness/indice-mta-externo`, checkout separado da conversao, a partir de
`main` em `eb44383`. Pedido: usar `mta.runsPath` informado na configuracao para
todos os projetos, reconhecendo a ultima analise em raiz/nome-da-pasta-Source.
Associar a pasta da aplicacao em projeto.json, sem fixar a rodada datada.
Preservar origens explicitas e diagnosticos internos; informar ausencia,
ambiguidade e relatorio invalido sem procurar outra aplicacao. Ler fontes
externas sem copia. Verificar com fixtures isoladas antes/depois da mudanca,
regressao de indice/MTA/acesso e revisao independente.

Escopo esclarecido: novas analises tambem devem usar sempre a raiz externa
configurada. Sem mta.runsPath, interromper antes de executar e orientar a
configuracao. Preparar saida em area externa transitoria; publicar pasta datada
somente apos sucesso e validacao. Preservar relatorios anteriores, associar
automaticamente a pasta Source e manter logs operacionais no projeto. Leitura
de MTA antigo interno continua compativel; novas saidas internas sao retiradas.

## Conversao de preparo sem proposta - 20/10/2026

Branch `harness/conversao-preparo-sem-proposta`, derivada da `main` em `dd38d6e`.

**Caso confirmado:** SIMTR-api (`simtr-parent`) tem contexto MTA, prompt, fichas
individuais e indice de evidencias; plano e tarefas foram apenas enderecados,
nunca escritos. O conversor exige esses documentos e interrompe a aplicacao.

**Entrega:** preservar o preparo e seus documentos existentes sem fabricar
proposta. Mostrar na previa a disponibilidade do par plano/tarefas; aceitar
ambos ausentes e manter recusa de par incompleto, origens invalidas e conflitos.
Indice deve apontar apenas documentos publicados. Referencias humanas a
documentos ausentes continuam lacunas, sem inferir GO, aceite ou recuperacao.
Validacao deve reconhecer o preparo corrente sem proposta.

**Verificacao:** reproduzir a falha antes da corretiva, testar preservacao das
fichas/anexos, repeticao, validacao, previa de descarte e casos negativos pelo
runner isolado. Revisar diff e testar mutacao de uma condicao. Nenhuma conversao
ou limpeza de dados reais.

**Orientacao solicitada:** fornecer no chat um script para percorrer projetos
individualmente, exibir status e pausar entre conversoes; escolhas de contexto,
diagnosticos, participantes e sprints permanecem explicitas.

**Resultado:** implementacao e 30 suites de conversao aprovadas em copia isolada.
O preparo conserva contexto/prompt/fichas/evidencias, sem criar a proposta.
Documentos locais no destino tambem impedem aplicar esse preparo; as ausencias
sao verificadas novamente na publicacao. Script sequencial documentado e ensaiado
com dubles em memoria. Revisao independente e mutacao concluidas; integracao
humana pendente. Detalhes no checklist.

## Conversao de associacao legada sem plano - 20/10/2026

Branch `harness/conversao-associacao-sem-plano`, derivada da `main` em `8193668`.

**Pedido:** corrigir o caso observado na maquina de trabalho, em que
`planning/arquiteturajee7/issues/project.json` contem apenas ArtifactId, Project
e Source, sem contexto/plano/tarefas. O inventario o classifica como PLANNING
desconhecido e exige escolher um contexto inexistente.

**Entrega:** reconhecer somente a associacao legada de formato conhecido,
conferindo artifactId/POM, Source e caminho; representar ausencia de plano
sem fabricar documentos; manter recusa de metadados desconhecidos, identidades
divergentes, planos ambiguos e vinculos quebrados. Originais preservados;
descarte continua explicito e condicionado a equivalencia.

**Caso adicional informado:** SIMTR-api tem artifactId `simtr-parent`, contexto
de plano candidato e manifesto MTA copiado em `evidencias/`. Reconhecer essas
copias pela proveniencia declarada nos anexos e pelo Source unico, sem repetir
a classificacao de PLANNING desconhecido. O nome do arquivo nao basta.
Nao escolher automaticamente o plano candidato nem os builds/Sonar/sprints.

**Achado de revisao:** falha de leitura do inventario nao pode comprovar
ausencia de plano. Manter origem nao interpretada visivel e bloquear publicacao
parcial, inclusive quando existe outro plano valido vinculado.

**Verificacao:** reproduzir a falha em fixture; testar previa, aplicacao,
validacao, repeticao e previa de descarte. Conferir outra aplicacao sintetica
com plano existente, copias MTA com proveniencia e origens corrompidas.
Executar as suites de conversao pelo runner isolado.
Nao converter nem limpar os dados reais da maquina de trabalho.

## Consistencia documental e agentes principais - 19/10/2026

Branch `harness/consistencia-engineering-harness`, derivada da `main` em `6566bb8`.

**Objetivo:** resolver os seis achados da revisao de `doc/engineering-harness/`
e os ajustes editoriais, preservando ADR-0009 e contratos como fontes normativas.

**Decisao do desenvolvedor:** Codex e GitHub Copilot sao os agentes principais;
Claude Code e secundario. Esta decisao substitui a prioridade registrada em
17/10/2026, mantendo os tres adaptadores e a independencia do nucleo.

**Entrega:** alinhar fonte do GO, bases dos caminhos, responsabilidade pela
publicacao do build, baseline e entregas, diagrama com IA opcional e aceite do
incremento A. Atualizar prioridade dos clientes e piloto programatico, ordenar
as subsecoes e conferir as referencias da auditoria. O PNG anterior permanece
identificado como ilustracao historica; o fluxo corrente usa Mermaid editavel.

**Verificacao:** leitura cruzada com contrato/codigo, links e ancoras Markdown,
sintaxe/preservacao dos exemplos JSON e do esquema de entrada, revisao do
diagrama e `git diff --check`.
Alteracao documental; ensaios de runtime e homologacoes anteriores mantem seu estado.

## Adaptador Claude Code - 17/10/2026

Branch `harness/adaptador-claude-code`, derivada da `main` em `4c27442`.

**Objetivo:** a orientacao da migracao funcionar no Claude Code como no Copilot e
no Codex, reaproveitando a skill comum e os papeis, sem duplicar regras.

**Entrega:**

- `.claude/agents/`: os seis helpers, com Read, Grep, Glob e as tres consultas MCP;
  somente `migracao_helper` delega, com `Agent(...)` limitado aos cinco helpers
  (imposto pelo cliente quando iniciado por `claude --agent migracao_helper`).
- `.claude/skills/orientar-migracao/SKILL.md`: ponteiro para a skill comum.
- Skill comum e papeis: encaminhamento e delegacao no Claude Code.
- `mcp/issues/configure.mjs`: grava `harnessIssues` tambem em `.mcp.json`
  (ignorado pelo Git, excluido das copias de teste), com as mesmas protecoes.
- Guias de orientacao, consultas MCP, desenvolvedor, workspace e manutencao; README;
  documento 1 do Engineering Harness.

**Verificacao:** `Test-ClaudeAdapter.ps1` (paridade, perfil leitor, delegacao,
ponteiro), suites de prompts/implementacao/isolamento, testes Node de
configuracao/contrato/ciclo de vida em checkout separado. Ensaio nativo no Claude
Code permanece com o desenvolvedor.

## Estado JBoss corrente - 17/10/2026

Branch `harness/jboss-estado-corrente`, derivada da `main` em `4c27442`.
Incremento A do [plano tatico](../doc/engineering-harness/03-plano-tatico-e-implementacao.md), parte JBoss.

**Decisoes do desenvolvedor:** guardar somente o ultimo; o deploy sempre substitui
o WAR implantado, inclusive deployment externo ou nao gerenciado, sem confirmacao;
retirar a Run Task `Aplicacao: rollback no JBoss`.

**Entrega:**

- Servidor em `.harness/servidores/<eap71|eap74>/`: `ultima-operacao.json` e
  `ultimo-start/` (logs renovados somente por novo start). Sem hash do caminho.
- Deploy por projeto em `atual/jboss/<eap>/ultimo-deploy.json`, publicado com a
  situacao `jboss-<eap>` em `operacao.json` e link no indice do projeto.
- WAR de origem aberto somente para leitura durante conferencia e envio; sem copia.
- `Invoke-HarnessJbossRelease`/`Get-HarnessJbossReleases` substituidos por
  `Invoke-HarnessJbossDeploy`; `-ReleaseId` e opcao de menu removidos.
- Pasta legada `.harness/jboss/` nao e lida nem escrita; remocao manual documentada.

**Fora do escopo:** backups do workspace com GUID; contratos minimos do incremento A.

**Verificacao:** suites JBoss (exceto ensaio real opt-in), Run Tasks, navegacao,
armazenamento e build pelo runner isolado; links Markdown.

## Consolidacao documental do Engineering Harness - 17/10/2026

Branch `harness/consolidar-documentacao`, derivada da `main` em `5c8d582`.

**Objetivo:** substituir `doc/arquitetura/`, `doc/especificacoes/`, `doc/features/`
e `doc/estrategia/` por dois conjuntos com finalidades distintas:

- `doc/engineering-harness/`: evolucao do produto, em tres documentos fornecidos
  pelo desenvolvedor (estrategia e arquitetura, system design, plano tatico).
- `doc/contratos/`: regras seguidas pelas tarefas e agentes ao migrar uma
  aplicacao (fluxo de migracao, planejamento por sprints, consultas de issues).

**Decisoes do desenvolvedor (17/10/2026):**

- Os tres documentos sao a referencia principal; corrigir a situacao descrita
  para a `main` real (`5c8d582`), sem baseline anterior a PR #31.
- Decisao historica, substituida em 19/10/2026: Claude Code seria o cliente principal.
  A prioridade vigente e Codex e GitHub Copilot como principais, Claude Code secundario.
- Perfil de modernizacao considera GitHub Copilot app modernization (Azure).
- Serena nao integrou no Windows (executavel sem assinatura); avaliar o plugin
  oficial `jdtls-lsp` do Claude Code e o JDT LS como alternativa de indexacao.
- Java 8 somente no perfil JBoss; perfil Quarkus considera Java 17+, incluindo 25.
- Origem JBoss: EAP 7.0 ou 7.1 (chave `eap71`), destino EAP 7.4.
- Principio de armazenamento: pastas por projeto e por funcao, navegaveis e
  legiveis, sem RunId, GUID ou hash em caminhos.
- Destinos aprovados: catalogo de capacidades como anexo do plano tatico;
  conversor em `tools/transicao/README.md`; cheat sheet em `doc/guias/`;
  `features/planejamento-copilot.md` descartado (historico no Git).

**Premissa adotada:** ADR-0009 e `doc/contratos/` continuam donos das regras
executaveis; o system design descreve e aponta para eles.

**Fora do escopo:** alterar o armazenamento JBoss (`.harness/jboss/<eap>__<hash>/
operations|releases/<GUID>`). Fica registrado como incremento seguinte, em branch
propria. Decisoes do desenvolvedor (17/10/2026): guardar somente o ultimo; o deploy
sempre substitui o WAR implantado no JBoss, inclusive deployment nao gerenciado,
sem pedir confirmacao; retirar a Run Task `Aplicacao: rollback no JBoss`.

**Verificacao:** links Markdown internos; nenhuma referencia restante as pastas
removidas; suites afetadas pelo runner isolado (sprints, consultas, prompts).

## Corretivas da auditoria independente - 21/10/2026

Pedido autorizado: corrigir A1/A2 e a contradicao A3 registrada no parecer.
Criar primeiro provas de regressao para publicacao externa/associacao e leitura
do historico com raiz externa configurada; corrigir em incrementos e preservar
escolhas explicitas, decisoes humanas, concorrencia e diagnosticos anteriores.
Validar pelo runner isolado, revisar independentemente e atualizar parecer/PR.
Dados reais e checkout operacional original permanecem fora desta etapa.

Corretivas concluidas e revisadas: A1/A2/A3, cobertura estrutural dos adaptadores e ajustes documentais. Ver resultados em todo.md e no parecer.
