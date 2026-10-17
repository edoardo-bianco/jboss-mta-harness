# Plano do agente: evolucao do harness

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
- Claude Code passa a ser o cliente principal; Codex e Copilot continuam suportados.
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
