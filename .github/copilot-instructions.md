# Escopo do Copilot

Siga [AGENTS.md](../AGENTS.md), a
[ADR-0002](../doc/adr/0002-separacao-harness-e-migracao-progressiva.md) e a
[ADR-0009](../doc/adr/0009-estado-corrente-por-projeto.md).

Evolucao do harness usa tasks/plan.md e tasks/todo.md, em branch harness/<objetivo>
derivada da principal, com checkout conferido, validacao/revisao antes de integrar.
Migracao usa os destinos PlanPath/TodoPath correntes do projeto. Nao misture
evolucao do harness com corretivas da aplicacao.

Testes PowerShell do harness usam `tests/Invoke-HarnessTests.ps1 -Test Test-Nome.ps1`:
copia temporaria fora do workspace operacional, sem configuracao pessoal e com
descarte das fixtures ao terminar. Nao executar suites diretamente no checkout de
migracao. Testes Node/ensaios reais usam checkout separado. Registrar resumo em
tasks/; exportar logs somente quando necessario e explicitamente escolhido.

Project e o artifactId literal do POM. projeto.json associa POM/Source local e
mta.diretorio; indices em .harness/indices/projetos.md e no projeto localizam
trabalho/evidencias. Registro atual concentra escolhas; indice/ranking nao as
substitui. Use links a HTML/Markdown/log existentes para navegar.
Referencias manuais em Markdown/chat podem indicar o diagnostico atual ou ultimo
build, conferindo origem/conteudo. Ultima tentativa pode diferir do diagnostico
utilizavel. Nao exigir ID de execucao/hash; prompts gerados podem ser regravados.

Planejamento: planejar cria, retoma ou revisa um lote consistente por projeto
nos mesmos destinos atuais, com fichas proprias por issue. Contexto mutavel nao
e recibo; nao ha Previous, snapshots ou copia consolidada obrigatorios.
NeedsReview aponta mudancas conhecidas; caminhos iguais nao provam conteudo igual.
Pergunte apenas o essencial para escopo/solucao/aceite e preserve rascunhos.
PENDENTE historico nao e bloqueio generico. Proposta nova fica nao aprovada.

Priorizacao opcional usa categoria/escopo e fatia de 0,01%..100,00% sobre B0 fixa.
Progredir exclui todas as examinadas acumuladas por Project/Id, com ou sem
recomendacao; recriar e explicito. Cada examinada tem ficha, posicao/motivo e
referencias. Mencao nao e exame e falha operacional nao consome quota.
Preservar cobertura acumulada, categorias/escopos e notas humanas nos indices.
Nao escolher pelo humano, alterar registro, planejar ou implementar nessa etapa.

MCP harnessIssues e opcional e somente leitura conforme o
[guia por etapa](../doc/guias/tools/consultas-issues.md#consultas-por-etapa).
Resposta valida/paginada dispensa releitura dos mesmos incidentes; conferir codigo
local continua necessario. Sem MCP/Node, seguir pelos arquivos sem JSON copiado.
Consulta nao marca exame, GO ou aceite; helpers permanecem leitores/orientadores.

MTA usa relatorio/catalogo original, sem executar output.js nem copiar incidentes.
EVIDENCIAS usa entradas humanas reais, sem inventar MTA/categoria. Ausencia de
origem e lacuna, sem fallback. doc/ e base local por busca/leitura com citacao;
nao afirmar RAG semantico implementado.

Compartilhar segue o [guia de copia](../doc/guias/tools/compartilhamento-contextos.md).
Nao ha tarefa ZIP. Associar POM local e reconciliar contextos copiados; trabalho
local exige recebido/ ou pasta externa, sem sobrescrita. Atualizar indice nao
substitui reconciliacao. GO/aceite recebidos nao se transferem automaticamente.
Planejamento: atualizar registro de migracao prepara comparacao de diagnostico,
codigo, decisoes e material recebido opcional. O executor publica registro,
documentos afetados, indice e ultima conclusao pela API protegida; helpers nao
publicam. Somente local ainda considera MTA. Preparar nao comprova reconciliacao.

Siga o [contrato](../doc/especificacoes/planejamento-copilot.md): Java 8/javax,
EAP 7.4 e Hibernate 5.3 quando aplicavel. O planejamento escreve plano/tarefas,
fichas examinadas e andamento/cobertura/referencias pertinentes, preservando
escolhas humanas; limpar aviso tecnico NeedsReview nao concede GO.

Ciclo: proposta, revisao/GO, execucao autorizada, verificacoes e aceite humano.
GO claro aplicavel nao e pedido novamente; mudanca de escopo/solucao/aceite pede
revisao do alcance sem apagar a decisao. Preparacao, arquivos e testes nao
concedem GO. Dispensa de precondicao nao dispensa entrega ou verificacao.
Aplicacao: preparar implementacao do lote prepara implementar-lote/revisar-resultado.
Executor confere GO e limita-se ao lote; nao infere commit/push/PR, escrita no
harness, operacao externa ou proximo lote. Usar apoio real compativel disponivel,
sem simular delegacao ou trocar cliente. Revisao de resultado e somente leitura.

Git e informativo conforme a [ADR-0004](../doc/adr/0004-git-informativo-sem-controle-de-branches.md).
Branch/HEAD diferentes nao exigem novo contexto por si so; conferir codigo.
Branches/integracao pertencem ao desenvolvedor, inclusive escolha opcional no
preparo de implementacao. Aceite e continuidade pedida precedem proximo lote.
MTA/Sonar comparaveis sao checklist nao bloqueante; registrar limites e nao
declarar conclusao global sem evidencia. Sonar baixado nao prova Source local.

<!-- mermaid-ai-skills:start -->
## Mermaid Diagrams

When the user asks to create, edit, or visualize a diagram, follow the
instructions in `.github/instructions/mermaid.instructions.md`.
<!-- mermaid-ai-skills:end -->
