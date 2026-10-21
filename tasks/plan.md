# Plano do agente: evolucao do harness

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
