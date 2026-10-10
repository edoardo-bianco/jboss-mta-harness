# ADR-0009 — Estado corrente por projeto, sem recibos

Estado: implementação autorizada em 10/10/2026, em andamento na branch do harness.
A substituição operacional das regras antigas depende da integração dos consumidores
e dos critérios de aceite da [feature](../features/organizacao-simplificada-por-projeto.md).

## Decisão

O desenvolvedor precisa localizar decisões, fontes e trabalho corrente pelo projeto.
Recibos, cadeias de execução e extratos duplicados dificultam essa tarefa. Adotamos
o `project.artifactId` literal do POM selecionado e os destinos fixos da feature.
O módulo [HarnessProject](../../scripts/HarnessProject.psm1) centraliza identidade,
links, leitura direta e publicação. O estado corrente não depende de IDs técnicos.

- MTA suportado neste incremento: relatório estático com `index.html` e `output.js`
  contendo a atribuição JSON `window["apps"]`, uma aplicação e seus `rulesets`.
  Não executar JavaScript. Usar `generatedAt` válido com fuso quando disponível;
  senão, mtime UTC de `index.html`. Desempatar por caminho ordinal. Regravação
  detectada interrompe a operação. Outros formatos exigem suporte e testes próprios.
- Chaves funcionais como `ruleset::regra` usam codificação percentual UTF-8 reversível
  para pastas. Maiúsculas são codificadas para impedir colisões no Windows. Não
  truncar nem substituir por hash. Categoria e escopo funcional separam cobertura;
  fichas pertencem ao projeto e à categoria, sem repetir a mesma ficha por escopo.
- Cada escopo de priorização conserva somente total inicial, issues examinadas e
  proposta corrente. A chave de uma issue é o projeto associado ao POM mais seu ID
  funcional. Mencionar uma issue não a marca examinada. Recriar é escolha explícita.
- Plano e tarefas são correntes, um lote por projeto. Mudanças de escopo/solução
  exigem revisão do GO. Preparar contexto, importar por cópia, testar e encontrar
  arquivos não concedem autorização. GO e aceite são declarações humanas legíveis.
- `reconciliado` contém conclusão, diferenças e pendências da última comparação.
  Não contém cópia integral de diagnósticos, fichas ou planos. Sem comparação
  suficiente, a proposta é preliminar; ausência no MTA atual não prova resolução.
- Sprints multiprojeto têm um único mestre em um participante Maven real. Índices
  dos demais participantes são derivados e reconstruíveis. Preservar baseline,
  capacidade e consumo de fases no cenário corrente, sem cadeia de revisões.
- Escrita usa exclusão por projeto e recuperação transitória. Antes de liberar
  leitores, concluir ou desfazer todo o conjunto. Cada arquivo é substituído
  atomicamente; o conjunto usa instrução transitória de recuperação. Não há
  transação distribuída com editores externos: conflitos preservam contribuições
  e exigem conciliação. O mutex não é registro de identidade nem fica em disco.

## Consequências e transição

Detalhes antigos deixam de estar disponíveis quando a origem antiga é removida.
As fichas conservam o essencial e links ao MTA atual e ao código local. Toda
referência de detalhe deve ser navegável; fonte ausente é uma lacuna explícita.

Esta decisão substitui, quando a integração estiver concluída, as exigências de
recibos/cadeias das [ADR-0004](0004-git-informativo-sem-controle-de-branches.md),
[ADR-0005](0005-planejamento-orientado-pelo-registro.md) e
[ADR-0006](0006-categorias-e-dossie-por-issue.md), e o empacotamento da
[ADR-0007](0007-compartilhamento-de-contextos.md). Mantém Git informativo,
planejamento pelo registro, categorias, exame de evidências e decisões humanas.
A separação da [ADR-0002](0002-separacao-harness-e-migracao-progressiva.md) permanece.

A [conversão](../features/conversao-descartavel-dos-registros.md) é descartável e
separada. O runtime não a importa nem procura legado. Originais reais só serão
limpos após seleção explícita e validação; os testes usam dados sintéticos.
Modernização e novas capacidades continuam posteriores a esta entrega.

## Verificação inicial

[Identidade](../../tests/Test-ProjectStorage.ps1),
[publicação](../../tests/Test-ProjectPublication.ps1),
[interrupção e recuperação](../../tests/Test-ProjectRecovery.ps1) e
[MTA direto](../../tests/Test-ProjectMta.ps1) exercitam o núcleo em PowerShell 5.1.
Essas provas não equivalem à conclusão dos fluxos listados no
[checklist](../../tasks/todo.md#simplificacao-prioritaria-por-projeto---2026-10-10).
