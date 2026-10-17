# Plano do agente: evolucao do harness

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
