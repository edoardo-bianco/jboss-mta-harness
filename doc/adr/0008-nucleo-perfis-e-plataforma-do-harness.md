# ADR-0008: núcleo, perfis e plataforma do Engineering Harness

Status: proposta para revisão do desenvolvedor; não implementada por esta entrega.
Data: 2026-10-09.

## Contexto

O harness JBoss reúne automação, contexto e evidências, mas concentra configuração
tecnológica e interação Windows/VS Code. A evolução solicitada precisa atender
outros objetivos e perfis, manter operação humana e agentes selecionáveis e
reduzir acoplamento a IDE, cliente de IA e analisador Java. A
[arquitetura consolidada](../arquitetura/arquitetura-harness.md) registra baseline,
matriz funcional, alternativas, fontes e critérios de verificação.

## Decisão proposta

1. Organizar o produto como monólito modular local, com DDD pragmático e portas e
   adaptadores. Regras de trabalho, decisão e evidência ficam no núcleo; mecanismos
   de execução e regras tecnológicas permanecem em seus módulos e perfis.
2. Usar TypeScript/Node.js LTS no núcleo, CLI/menu e MCP. Java atende ferramentas
   especializadas de análise Java; PowerShell permanece durante a transição e
   onde houver necessidade específica. Uma regra tem uma implementação canônica.
3. Compor capacidades por perfis versionados, incluindo ferramentas, políticas,
   guias e papéis de agentes. `harness.local.json` contém configuração transversal
   e referências; configurações tecnológicas ficam nos perfis/plugins.
4. Expor os mesmos casos de uso ao terminal, menu, VS Code, IntelliJ e MCP. A CLI
   é a base executável; a futura extensão VS Code é um adaptador de experiência e
   distribuição. Isso refina a prioridade da proposta `engineering-harness-vscode`,
   ainda não implementada, sem apagar seu histórico.
5. Manter orientador e executor como papéis distintos. Copilot/DevSquad, Codex e
   Claude Code são adaptadores selecionáveis; delegação depende de capacidades e
   permissões reais. Guias e contexto são carregados conforme a etapa e o perfil.
6. Escolher a família Eclipse JDT para o primeiro piloto Java independente de IDE:
   JDT LS para consultas semânticas e JDT Core quando for necessária extração AST.
   JavaParser permanece alternativa delimitada. SCIP é opção futura de índice
   transportável; a compatibilidade atual do scip-java não atende Java 8.

## Alternativas e consequências

Java também oferece plataforma e SDK MCP adequados, mas reescrever o núcleo e
interfaces atuais nessa linguagem não traz benefício demonstrado para este
recorte. Go melhora opções de distribuição, com custo de uma plataforma nova e
sem eliminar dependências Java. TypeScript reaproveita o MCP existente e a direção
estratégica; exige verificação de tipos, validação em runtime e manutenção da
distribuição Node. A comparação completa está na arquitetura, seção 10.

Perfis e contratos aumentam a disciplina de composição, mas evitam replicar regras
por ferramenta ou IDE. Não introduzir microserviços, broker ou framework genérico
de plugins sem demanda. JDT exige runtime e armazenamento próprios; seu piloto
deve medir cobertura/custo e separar efeitos de indexação das consultas prontas.

Permanecem os contratos vigentes das ADRs anteriores, consideradas suas
substituições e complementos; os controles Git da ADR-0003 foram superados pela
ADR-0004. GO, execução, verificações e aceite permanecem distintos; Git da aplicação
é informativo; origem, recibos e decisões históricas são preservados. Aceitar esta
ADR não homologa as ferramentas nem autoriza todas as implementações ou corretivas
de aplicação.

## Verificação

Aplicar os critérios das seções 11–13 da arquitetura: equivalência com contratos
atuais, operação fora de IDE e IA, configuração v1 preservada, segundo perfil sem
vazamento tecnológico para o núcleo, indexação Java 8 com limites explícitos e
ensaios dos clientes. A implementação de sprints permanece em sua frente; seu
estado de entrega deve ser reconciliado quando ela for integrada na main.
