# Plano do agente: evolucao do harness

## Links de fichas e registro de issues manuais — 23/10/2026

Branch `harness/links-issues-manuais`, derivada da main `a29137d`, inicialmente
limpa. Pedido: corrigir definitivamente os links de pastas funcionais com `%`
e orientar o Copilot a registrar/reparar issues manuais coerentemente.
O caso informado pertence a outra maquina; nenhum registro real sera alterado aqui.

Preservar a codificacao canonica de pastas e os IDs DEV-... da ADR-0009.
Reproduzir a falha de navegacao antes da correcao; gerar URI de arquivo a partir
do caminho literal e reutilizar a conversao nos leitores/realinhadores pertinentes.
Conferir destino real, caracteres especiais, fontes e continuidade em testes
isolados, incluindo Windows PowerShell 5.1 e PowerShell 7 quando disponivel.

Documentar criacao de ficha manual, log e indice de evidencias, linha do registro,
links escapados, limites de ANALISADA e preservacao na atualizacao do indice.
Explicitar que DEV-* nao integra a fatia percentual MTA e que IN_PROGRESS retoma
a mesma quota sem recriar. Fornecer prompt para reparar a maquina de trabalho
depois de receber a correcao, sem renomear IDs nem reiniciar a analise.

Implementacao e documentacao concluidas. Dez suites pertinentes passaram em
copia temporaria pelo runner; links testados em PS5.1/PS7, consumidores de
planejamento/reconciliacao em PS5.1. Revisao independente e navegacao documental
sem impedimentos. Detalhes de RED/GREEN e limites em tasks/todo.md.
O reparo dos documentos reais na maquina de trabalho depende de receber esta
corretiva e seguir o prompt publicado no guia; nao foi executado neste checkout.

Em 23/10, o desenvolvedor autorizou commit, push desta branch e abertura de PR
para main. A publicacao inclui a corretiva, testes e orientacoes; o reparo dos
documentos reais na maquina de trabalho permanece posterior a atualizacao.

Frente anterior: PR #46 integrado em `a29137d`; main alinhada e branch do guia
de fork removida local/remotamente.

## Fork do harness na conta da empresa — 23/10/2026

Branch `harness/guia-fork-empresa`, derivada da main `bb9ebe8`, com arvore limpa.
Pedido: documentar o fork na conta GitHub usada na empresa, mantendo aplicacoes
e pipelines no Azure DevOps; usar somente a denominacao generica empresa.
Incluir caminho por terminal com GitHub CLI (`gh`) para criar o fork e Git para
clonar, ajustar remotos e sincronizar; manter rota explicita sem gh, com criacao
do fork pelo navegador e operacoes locais somente por Git.

Criar guia em doc/guias/tools/, acessivel pelo README, guia do desenvolvedor,
workspace e guia de orientacao. Skill comum e papel de preparo encaminham ao
mesmo guia, sem duplicar comandos nem executar operacoes pelo helper.
Cobrir clone novo/existente, origin/upstream, preservacao dos dados locais,
atualizacao sem force e divergencias/permissoes. Validar links, exemplos e diff;
nenhum fork, autenticacao ou remoto real sera alterado por esta entrega.

Entrega documental concluida, incluindo abertura direta do original publico
com a conta da empresa e rota sem gh. Evidencias e limite do validador de skill
registrados em tasks/todo.md. Em 23/10, o desenvolvedor autorizou commit,
push da branch e abertura de PR para main desta entrega documental.

Frente anterior: PR #45 integrado em `bb9ebe8`, main alinhada e branch de origem
removida local/remotamente em 23/10. Analise DES e ensaio operacional permanecem
pendentes. O texto de retomada abaixo registra o estado anterior a publicacao.

Retomada em 23/10/2026 apos a pausa solicitada pelo desenvolvedor em 22/10. Ver
[checkpoint de preparo/operacao e DES](../doc/estrategia-migracao-ambientes-jboss-eap-7.4/checkpoint-correcoes-preparo-des-2026-10-22.md).
Alteracoes locais preservadas; commit/push/PR autorizados em 23/10, sem operacao de servidor.
Conferencia documental e de navegacao concluida, com branch/HEAD confirmados e
diff --check sem erros. Permanecem publicacao, ensaio funcional local e decisoes
de configuracao/validacao DES; resultados automaticos anteriores nao os encerram.

Decisao de entrega em 23/10: publicar as correcoes de modulos, arquivos externos,
restart e logs em um commit e PR para main. A analise de desenvolvimento/DES
permanece para trabalho posterior, registrada separadamente; nao condiciona
esta publicacao nem recebe aceite por ela. Revisao/merge do PR e ensaio real
na maquina de trabalho continuam etapas distintas.

## Correcoes do preparo/operacao e escopo DES — 22/10/2026

Pedido "vamos preparar as correcoes" autoriza implementar as evolucoes antes
registradas: descritores dos modulos, arquivos externos, restart e logs.
Branch retomada `harness/roteiro-des-eap74`, HEAD inicial `88a41e4`; preservar
documentacao pendente e entradas privadas. Classificacao: evolucao do harness.

Implementado: schema module:1.9 sem atributo slot (slot personalizado na
identidade), campo opcional files com source/target relativo a configuration,
preservacao/interrupcao em divergencia e rollback; Restart/RestartDebug sob o
lock existente; tarefa/script de leitura de logs por EAP/Todos com rotacao.
Os scripts continuam no Git. Nenhum servidor ou arquivo privado foi alterado.

Guia de banco permanece no guia JBoss. Acrescentados operacao e
[atualizacao da maquina de trabalho](../doc/estrategia-migracao-ambientes-jboss-eap-7.4/jboss-eap7.4-configuracao/atualizacao-maquina-trabalho.md),
com entradas opcionais, tratamento dos modulos corrigidos manualmente e
distincao entre atualizar codigo e reaplicar preparo. Tarefas pertencem a
.vscode/tasks.json do harness; nao foi necessario alterar o gerador de workspace.

Escopo DES esclarecido pelo desenvolvedor: o material de configuracao ja foi
fornecido; imagem, pipeline Azure DevOps e manifests/operacao OKD nao sao nossa
responsabilidade. Revisar configuracao sem bloquear por esses arquivos.
[Registro DES](../doc/estrategia-migracao-ambientes-jboss-eap-7.4/jboss-eap7.4-configuracao-des/README.md)
separa os achados dos arquivos de confirmacoes externas e identifica impacto
local. Template privado nao alterado: decisoes JDBC/EJB/seguranca/caches/JVM
continuam abertas para revisao item a item, como solicitado anteriormente.

Verificacao concluida: defeito de slot reproduzido no carregador real; corrigido,
main e slot personalizado carregaram classe Java sintetica. Sete suites de
regressao passaram pelo runner isolado, incluindo rollback dos arquivos
externos, preparo/logs em PS5.1 e PS7, restart, runtime, Todos, deploy simulado
e entradas reais das tarefas. Sintaxe, JSON, 53 links locais e diff --check
passaram. Resultados e limites em todo.md. Sem commit/push; ensaio operacional
na maquina de trabalho e decisoes do template DES continuam pendentes.

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

## Checkpoint documental do preparo EAP 7.4 local - 21/10/2026

Pedido: salvar a auditoria para retomada em 22/10, sem executar as correcoes.
Branch `harness/auditoria-preparo-eap74`, criada da main em `d0ba820`.
Persistir achados, fontes, limites e sequencia no
[checkpoint EAP 7.4](../doc/estrategia-migracao-ambientes-jboss-eap-7.4/auditoria-preparo-local-eap74-2026-10-21.md).
Este incremento e documental; configuracoes externas, segredos, instalacao JBoss
e aplicacoes permanecem fora das alteracoes. A retomada operacional esta no
checkpoint, sem criar lote de corretivas de aplicacao em tasks/.

## Preparo reutilizavel EAP 7.4 - 22/10/2026

Implementacao autorizada apos auditoria por perguntas. Retomar a branch atual,
preservando o checkpoint e as alteracoes locais. Scripts, modelos e roteiro manual
ficam em doc/estrategia-migracao-ambientes-jboss-eap-7.4/jboss-eap7.4-configuracao/.
O guia do desenvolvedor e o helper apontam para esse roteiro, sem duplica-lo.

Entregar preparo configuravel por ambiente: template e valores privados, JVM
compartilhada pelo launcher/harness, modulos Maven ou JAR local, consolidado e
publicacao explicita. Exigir servidor parado inclusive somente gerar. Preservar
modulo identico; recusar divergente/incompleto. LogSql altera apenas XML gerado.
Nao instalar patch nem aplicar configuracao ao servidor operacional nesta etapa.

Ordem: testes isolados de falha/preservacao; scripts e modelos; guia de patch
7.4.XX com fontes Red Hat, Java 8/Jakarta EE 8/javax; referencias do helper;
adaptacao da pasta externa com valores existentes preservados; revisao final.
As 16 entradas DES, fornecedor JDK, eventual patch novo e testes funcionais
continuam pendentes, sem bloquear testes sinteticos. CP11 segue base observada.
Origem do driver DES permanece por confirmar; instalar modulo nao comprova uso.
Validar com Invoke-HarnessTests.ps1, sem dados reais nas fixtures ou no Git.
## Entrega do preparo reutilizavel — 22/10/2026

Concluida a implementacao autorizada na branch de auditoria: scripts e modelos
genericos, roteiro manual, procedimento de patch com fontes Red Hat e referencias
no guia/helper. Pasta externa adaptada para consumir o codigo versionado; quatro
entradas privadas preservadas byte a byte. Validacao em memoria dos 96 tokens,
XML normal/LogSql e JVM, sem expor valores.

Testes isolados PASS: preparo em PowerShell 5.1/7, runtime JBoss, referencias
e adapter Claude. Revisao conferiu preservacao em falhas, defaults Maven da
maquina, limites do launcher e ausencia de valores reais nos novos modelos.
Detalhes e pendencias no [checkpoint](../doc/estrategia-migracao-ambientes-jboss-eap-7.4/auditoria-preparo-local-eap74-2026-10-21.md).
Nao houve aplicacao ao EAP, boot, deploy, patch, commit ou push.

## Organizacao e transporte do preparo — 22/10/2026

Pedido posterior: pasta OneDrive enxuta, padronizada e guia especifico SIMTR;
ZIP para extrair em C:\desenvolvimento, chamando scripts diretamente no harness.
Concluido: entradas relativas ao preparo.json, referencias antigas separadas,
JARs locais conferidos e alternativa Maven, README/guia na pasta privada e
pacote inicial com 23 arquivos verificados por SHA256, substituido pela decisao
abaixo. JBoss/JDK/WAR nao incluidos.
Validacao em memoria apos mover; valores e JVM preservados. Sem boot, aplicacao
ao servidor, commit ou push. Detalhes no checkpoint EAP 7.4.

Escolha final: o repositorio alinhado pelo Git e a fonte oficial dos scripts.
ZIP atualizado com 18 arquivos e somente a raiz jboss-eap7.4-configuracao/;
conferencia-harness/ guarda seis scripts identicos apenas para comparacao e
pode ser apagada. Guia e configuracao usam os scripts do repositorio. SHA256
conferido em todas as entradas; nove entradas privadas preservadas byte a byte.
Disponibilizar as alteracoes pelo Git continua pendente; nao houve commit/push.

## Roteiro DES e alinhamento com o local — 22/10/2026

O preparo anterior foi integrado pelo PR #44; os registros de ausencia de
commit/push acima descrevem etapas anteriores. Nova frente documental na branch
harness/roteiro-des-eap74, derivada da main apos o merge.

Auditar o inventario privado DES 7.1 e as referencias historicas; preparar uma
pasta privada explicita de DES, com recorte por aplicacao. A primeira aplicacao
usa imagem construida pela esteira Azure DevOps e executada no OKD. O EAP local
7.4 Update 11 serve ao ensaio. O desenvolvedor confirmou template 7.4 unico por
aplicacao para local/DES, valores por ambiente e preservacao do comportamento
7.1 quando compativel. Avaliar o impacto local de cada mudanca.

Entregas: roteiro generico des.md no repositorio; README, auditoria com fontes
e roteiro especifico na pasta privada. Conferir links, cobertura das entradas
e preservacao dos arquivos existentes. Nao alterar servidor, esteira ou template
durante esta auditoria; registrar propostas e lacunas de evidencia. A segunda
aplicacao sera examinada quando o desenvolvedor fornecer seu material.

Entrega documental concluida: [roteiro generico](../doc/estrategia-migracao-ambientes-jboss-eap-7.4/jboss-eap7.4-configuracao/des.md)
e tres documentos na pasta privada jboss-eap7.4-configuracao-des/, com recorte
da primeira aplicacao. Comparacao conserva 78 associacoes propriedade/token;
isso nao comprova equivalencia dos demais recursos. Dez achados e matriz de
defaults registram diferencas, efeitos no local e verificacoes necessarias.
Conferidos 31 links locais em cinco documentos e preservacao dos 24 arquivos
preexistentes. Sem alteracoes de template, valores, servidor ou esteira.
Permanecem pendentes a referencia realmente implantada, evidencias da imagem,
decisoes tecnicas do template compartilhado e material da segunda aplicacao.
Esta entrega esta na branch documental, ainda sem commit/push.

### Ensaio atual na maquina de trabalho — decisao de 22/10/2026

O desenvolvedor esta testando a versao ja entregue e decidiu prosseguir com o
ensaio local, resolvendo depois os achados um por um. A revisao final para DES
nao bloqueia esse ensaio do candidato atual. Preparo/aplicacao continuam com
servidor parado; resultados dependentes de valores provisorios ficam delimitados.
A base disponivel aqui e o PR #44 (88a41e4). O desenvolvedor confirmou que
alinhou a maquina de trabalho com a main remota. O hash exato, ajustes privados
e resultados nao foram informados; nao inferir esses dados do alinhamento Git.

Manter no roteiro privado DES, secao "Ensaio atual na maquina de trabalho e
proximas atualizacoes", o impacto de cada decisao: arquivos/trechos, necessidade
de atualizar o local (ou nao), origem Git/privada, passos, parada e testes.
Distinguir preparada/disponibilizada de aplicada/verificada pelo desenvolvedor.
Preservar ajustes privados realizados durante os testes; nao sobrepor ZIP antigo.
Esta auditoria ainda nao emitiu atualizacao operacional para a maquina de trabalho.

### Falha de entrada no ensaio da maquina de trabalho — 22/10/2026

Desenvolvedor executou preparo sem -Aplicar e recebeu "Linha de valores
invalida: 100". Diagnostico: chave OUTSOURCING_SSO_CLIENT_SECRET sem separador
igual no arquivo de propriedades. O numero indica a linha, nao portOffset.
Reproduzido com dados sinteticos usando copia de Eap74Inputs.ps1 em pasta
temporaria externa: linha invalida falha; valor sintetico e vazio sao aceitos
pelo parser. Vazio aceito sintaticamente nao comprova validade funcional.
New-EapXml falha antes da geracao/publicacao, preservando consolidado e servidor.

Outra correcao de entrada: identificador JVM America/Sao_Paulo deve ser literal,
sem acentos. Nao exige atualizacao dos scripts. Aplicacao das correcoes e nova
execucao na maquina de trabalho ainda aguardam relato do desenvolvedor.
Configuracao informada usa standalone-okd.xml, offset 100, logSql=true e caminho
JDK jdk1.8.0_112. Conferir versao real/base de fusos antes de aceitar testes de
datas: esse update antigo pode conservar regras brasileiras de horario de verao.
Fontes: [Java 8 TimeZone](https://docs.oracle.com/javase/8/docs/api/java/util/TimeZone.html),
[IANA](https://data.iana.org/time-zones/tzdb/zone1970.tab),
[Oracle tzdata 2019b](https://linux.oracle.com/errata/ELBA-2019-1703.html).
Valores reais recebidos no chat nao foram copiados para arquivos ou fixtures.

Revisao das saidas recebidas em seguida: XML renderizado, BAT e manifesto de seis
arquivos coerentes com o preparo informado. Correcao da propriedade sem igual
observada no XML e identificador de fuso corrigido no BAT. Referencias do driver
Oracle e modulo global Jasper alinhadas ao manifesto original. SHA256 informados
para os dois JARs coincidem com os arquivos do pacote de origem; nao houve leitura
dos bytes remotos nem dos module.xml daquela maquina. XML/BAT nao persistidos.

Quatro itens continuam ficticios: segredo de outsourcing, segredo SSO internet,
segredo do alias MTR e token Portal Empreendedor. Permanecem pendentes keystore,
base de fusos/JDK e ensaios funcionais. Console DEBUG filtra parametros SQL TRACE;
FILE sem nivel explicito usa default ALL, a confirmar em server.log no ensaio.
Modulo global net.sf.jasperreports.fonts preserva a referencia DES, slot main;
funcionamento das fontes depende de deploy/relatorio. Achados DES anteriores,
incluindo keepalive EJB 60 s e ausencia de READ_TIMEOUT, continuam adiados por
escolha do desenvolvedor. Aplicacao/boot ainda nao comprovados; sem alteracao
de scripts ou entradas privadas durante esta revisao.

### Arquivos externos do servidor — proposta para discutir, 22/10/2026

O desenvolvedor localizou o keystore da aplicacao sob standalone/configuration
da instalacao legada em pasta jboss-eap-7.0. O nome da pasta nao comprova a versao
real do runtime; o harness aceita 7.0/7.1 na chave eap71. Decisao atual: copiar
manualmente o arquivo para standalone/configuration do alvo EAP 7.4.11,
preservando origem e destino preexistente. Copia/aliases/senhas ainda nao
comprovados por resultado. A referencia a EAP 7.7 foi interpretada pelo contexto
como o alvo 7.4.11 ja informado, sem alterar a restricao de migracao.

Demanda futura do preparo generico: uma pasta privada arquivos/ com um ou mais
keystores, truststores, propriedades ou outros arquivos necessarios ao servidor.
Propor mapeamento configuravel origem/destino relativo a eapHome, separado dos
arquivos gerados (XML/JVM/modulos), com lista opcional para preservar o uso atual.
Sem nomes de aplicacao fixos nos scripts. Material sensivel continua privado;
somente scripts, formato e exemplos ficticios acompanham o repositorio.

Comportamento proposto, a revisar junto com os demais ajustes: servidor parado;
geracao integra os arquivos ao consolidado e manifesto; -Aplicar copia binarios
sem transformar conteudo, valida caminhos e impede colisoes com saidas geradas.
Arquivo identico no alvo e preservado; divergencia interrompe e preserva para
analise, conforme a direcao de preparo ja escolhida. Falhas nao devem deixar
publicacao parcial. Atualizar guia/helper genericos e o acompanhamento da
maquina de trabalho com arquivos, obtencao via Git e passos de reaplicacao.
Nao implementar agora: usuario pediu registrar para discutir depois; uso atual
segue com copia manual. O keystore nao deve ser acrescentado manualmente dentro
do consolidado gerado, pois isso invalida a verificacao do manifesto corrente.

### Acompanhamento de logs JBoss — evolucao futura, 22/10/2026

Pedido do desenvolvedor: transformar o acompanhamento manual de server.log em
script PowerShell versionado no harness e uma unica Run Task
`Servidor: acompanhar logs`, com escolha de EAP 7.1, EAP 7.4 ou Todos,
reutilizando a selecao de servidores existente. Tratar junto com os demais
ajustes pendentes; registrar agora e implementar depois.

Proposta: `scripts/acompanhar-log-jboss.ps1`, lendo os caminhos atuais de
`config/harness.local.json`, sem caminho fixo nem dependencia de aplicacao.
Exibir as ultimas linhas e acompanhar novas mensagens; ao selecionar Todos,
identificar o servidor de cada mensagem. Ctrl+C encerra somente os leitores.
Informar claramente arquivos ainda ausentes, sem iniciar/parar o JBoss nem
alterar seus logs. Detalhar tratamento de rotacao na implementacao.

Entrega futura inclui tarefa no gerador de workspace, guia de operacao JBoss,
verificacoes isoladas e instrucoes de atualizacao na maquina de trabalho.
Por enquanto permanece valido o comando Get-Content -Tail 100 -Wait informado
no chat; nenhum script ou tarefa de acompanhamento JBoss foi criado nesta etapa.

### Falha do modulo Oracle no primeiro boot — 22/10/2026

Log enviado da maquina de trabalho comprova EAP 7.4.11/CP11, Java 8u112,
standalone-okd.xml, offset 100, HTTP 8180 e gerenciamento 10090. O processo
iniciou com erros (WFLYSRV0026): WFLYJCA0041 ao carregar com.oracle.ojdbc8,
seguido de dependencias ausentes do datasource. Nao ha boot limpo nem teste de
conexao aprovado. A presenca do JAR foi relatada; o module.xml enviado confirma
schema urn:jboss:module:1.9 junto com atributo slot="main".

Defeito confirmado no gerador Eap74Modules.ps1: emite essa combinacao invalida
para todos os modulos. Atributo slot nao e aceito nesse schema; para main,
manter o nome do modulo e retirar o atributo. Reproducao minima em pasta TEMP
isolada, usando -deptree do jboss-modules.jar da instalacao local EAP 7.4:
com slot ocorreu ModuleLoadException; sem slot o descritor foi aceito.
O relatorio de arvore tambem mostrou java.base nao encontrado; o ensaio foi de
parsing do descritor, sem iniciar servidor nem validar o driver/datasource.
Fixture removida; nenhum arquivo do JBoss foi alterado pelo agente.
Referencia: [Red Hat, slots e schemas de modulos](https://access.redhat.com/solutions/185243).

Orientacao imediata: parar EAP 7.4 e retirar slot="main" dos module.xml Oracle e
Jasper gerados, preservando nomes, JARs e dependencias; reiniciar e conferir
driver, datasource e ausencia de erros de boot. Resultado ainda pendente.
Correcao duravel deve ajustar o gerador, cobrir main e slots personalizados com
carregador real e orientar transicao de modulos existentes sem sobrescrita
silenciosa. A versao atual do preparo pode rejeitar os descritores corrigidos
por divergencia: nao reexecuta-la como remedio para esta falha. Nao editar o
consolidado/manifesto manualmente. Scripts continuam sem mudancas nesta etapa.

Avisos independentes: host SMTP nao resolvido; application.keystore ausente com
geracao automatica prevista (arquivo diferente de simtr-keystore.jceks);
deprecacoes de seguranca nao explicam a falha do driver. No XML mais recente,
segredo MTR deixou de ser ficticio, mas sua validade nao foi comprovada; tres
outros valores continuam ficticios. Valores reais e log integral nao persistidos.

### Segundo boot da maquina de trabalho — 22/10/2026, 17:16

Novo log enviado pelo desenvolvedor confirma boot sem ERROR no trecho recebido:
WFLYSRV0025, EAP 7.4.11/CP11 iniciado em 10464 ms, driver Oracle 19.22 carregado
(WFLYJCA0004), servico ojdbc8 iniciado (WFLYJCA0018) e datasource vinculado em
java:jboss/datasources/simtr-ds (WFLYJCA0001). HTTP 8180 e gerenciamento 10090.
A falha de carregamento Oracle do primeiro boot deixou de ocorrer neste ensaio.
Isso atualiza a pendencia anterior de boot, sem comprovar conexao ao banco.

Aplicacao ainda nao implantada, conforme relato. Proxima verificacao orientada:
/subsystem=datasources/data-source=simtrPU:test-connection-in-pool pela CLI no
gerenciamento 10090, usando Java do preparo. Esperado outcome=success e result
contendo true; resultado ainda nao recebido. Boot nao comprova uso do Jasper,
keystore da aplicacao, consultas/permissoes funcionais nem aceite da migracao.
Persistem avisos de application.keystore e deprecacao de seguranca; aviso SMTP
nao aparece neste trecho, o que nao comprova envio de e-mail funcional.
Gerador continua sem correcao; publicar ajuste e orientar atualizacao da maquina
de trabalho permanecem pendentes. Apenas resumo sem valores sensiveis persistido.

### Teste de conexao documentado apos o start — 22/10/2026

Pedido atendido no [guia JBoss](../doc/guias/tools/jboss.md#testar-conexao-com-o-banco-apos-o-start):
teste CLI test-connection-in-pool antes do deploy, usando Java/CLI do preparo,
porta de gerenciamento e pool-name ajustaveis. Inclui precondicao de boot normal,
resultado success/true, diagnostico inicial de falhas e limite da verificacao.
O roteiro reutilizavel EAP 7.4 referencia essa secao na verificacao pos-start.
Alteracao documental; resultado real de conexao na maquina de trabalho continua
pendente. Nenhum comando de conexao foi executado pelo agente.
Verificacao PASS: sintaxe do bloco PowerShell, secao antes do deploy, referencia
e ancora do preparo, 20 destinos locais dos dois guias e git diff --check.

### Reinicio do JBoss — evolucao futura, 22/10/2026

Pedido do desenvolvedor: acrescentar Restart junto com os ajustes pendentes.
Estado atual conferido em gerenciar-jboss.ps1, HarnessJbossRuntime.psm1 e
HarnessJboss.psm1: ha Start/StartDebug/Stop/Status, sem Restart. Start em RUNNING
com identidade confirmada retorna o processo existente; nao reinicia nem muda
seu modo. Instancia sem gerenciamento, identidade divergente ou portas ocupadas
impedem iniciar outra. Stop aguarda saida do processo e estado STOPPED, sem force.
O guia JBoss agora explica o reinicio manual por Parar seguido de Iniciar.

Proposta para implementar depois: tarefa unica `Servidor: reiniciar JBoss`,
reutilizando gerenciar-jboss.ps1, selecao EAP 7.0/7.1, EAP 7.4 ou Todos e escolha
normal/debug. Reutilizar as funcoes existentes de stop/start, mantendo um unico
lock por servidor durante toda a sequencia: conferir identidade, shutdown,
aguardar STOPPED, conferir portas, iniciar e aguardar RUNNING. Se ja estiver
STOPPED, iniciar no modo escolhido. Falha/timeout no stop impede start daquela
instancia; preservar processo/logs e informar a fase da falha. Nao forcar kill,
repreparar XML/modulos ou alterar configuracoes como efeito do restart.

Todos deve processar uma instancia por vez, com resumo por servidor e falhas
explicitas, conforme as operacoes atuais. Nao criar tarefa por versao ou modo.
Verificar sequencia/lock, stop com falha, portas ocupadas, modos normal/debug e
selecao Todos em copia isolada; documentar atualizacao na maquina de trabalho.
Estado: demanda registrada, sem implementacao ou operacao de servidor nesta etapa.

### Conexao Oracle confirmada e avisos da CLI — 22/10/2026

Desenvolvedor executou test-connection-in-pool para simtrPU no gerenciamento
127.0.0.1:10090 usando Java/CLI do preparo e enviou outcome=success/result=[true].
A conexao do datasource esta confirmada nesse ensaio; nao comprova consultas,
permissoes nas tabelas, transacoes nem uso pela aplicacao ainda nao implantada.

Dois avisos acompanhavam a resposta: jboss-cli.xml nao localizado (cliente usou
padroes) e cliente CLI nao modular sem comandos adicionais de extensoes. Nao
sao erros do datasource ou repeticao da falha de modulo Oracle. Guia ajustado
para passar -Djboss.cli.config com o arquivo bin/jboss-cli.xml antes de -jar,
como o runtime do harness ja faz; aviso de modo nao modular pode permanecer.
Referencia: [Red Hat EAP 7.4 — Management CLI Guide](https://docs.redhat.com/en/documentation/red_hat_jboss_enterprise_application_platform/7.4/html-single/management_cli_guide/index).
Somente documentacao/registros alterados; nenhuma conexao ou mudanca no JBoss
executada pelo agente. Resultado foi fornecido pelo desenvolvedor.
