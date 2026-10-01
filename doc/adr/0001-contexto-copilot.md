# ADR-0001: contexto local e acionamento explicito do Copilot

Status: aceita no fluxo aprovado em 2026-09-26.

## Contexto

O harness ja possui tarefas PowerShell e um prompt de leitura. O desenvolvedor
precisa escolher evidencia de varios projetos e controlar quando o agente atua.

## Decisao

Preparar um arquivo de prompt local por solicitacao, com copia das instrucoes
versionadas e referencia fixa a uma rodada MTA. Usar o acionamento documentado
do VS Code e manter o envio sob controle do desenvolvedor.

## Alternativas e consequencias

Preencher caminhos manualmente continua como alternativa, mas deixa de ser o
caminho principal. Uma extensao propria ou uma API de envio acrescentariam
dependencias e manutencao sem necessidade demonstrada para esta etapa.

A copia preserva as instrucoes de uma solicitacao mesmo quando o template evolui;
somente o template e mantido manualmente. Os arquivos gerados sao locais e
ignorados pelo Git. O botao de execucao e as ferramentas dependem do cliente;
o ensaio visual continua necessario, com alternativa pelo comando no chat.

Referencia: [arquivos de prompt do VS Code](https://code.visualstudio.com/docs/agent-customization/prompt-files).

## Refinamento: planos progressivos e continuidade

Por solicitacao do desenvolvedor, os resultados passam a ser persistidos em
plan.md e todo.md locais da solicitacao, separados de tasks/ do harness. Um unico
lote ativo evita detalhar milhares de corretivas antes de haver evidencia de
execucao. Retomar a mesma rodada atualiza esses documentos; mudar a base MTA gera
nova solicitacao com referencia explicita a anterior, preservando historico.

Um recibo context.json registra identidades e hashes das evidencias. A selecao
anterior e do desenvolvedor; nao se presume que o arquivo mais recente representa
o lote aceito. O agente reconcilia rodadas e resultados antes de propor outro lote.

Habilitamos criacao/edicao de arquivos para os dois resultados, sem terminal.
Os limites de paths sao instrucoes do prompt e revisao do desenvolvedor, nao uma
sandbox de escrita por pasta. A execucao das corretivas permanece outra etapa.

## Refinamento: registro por projeto e prompt unico - 2026-10-01

Implementacao solicitada pelo desenvolvedor. Cada raiz Maven recebe registro local
migracao.md e indice de evidencias sob .harness/projetos; a criacao e idempotente.
O catalogo usa a rodada explicitamente selecionada, inclusive antiga ou recebida;
nao depende de executar outro MTA. Categorias/contagens vem dos dados do relatorio,
nao de inferencia do agente. Decisoes e andamento sao campos independentes.

planejar-lotes atende proposta inicial e atualizacao, com plano anterior e evidencias
opcionais. manter-migracao e uma operacao opcional do mesmo menu para conciliar
registro existente/recebido, novo MTA e/ou evidencias, sem loop obrigatorio de prompts.
O recibo preserva o retrato do registro usado no preparo; o registro permanece mutavel.
A decisao humana fica no plano, referenciada pelo to-do; formatos antigos continuam legiveis.

Os templates curtos referenciam o contrato tecnico existente em
[planejamento-copilot](../especificacoes/planejamento-copilot.md); novas decisoes sao
mantidas ali e nas ADRs, sem criar documentos paralelos. Recibos novos guardam
copia desse contrato; o caminho original continua como referencia. Prompts e recibos
historicos nao sao reescritos. Preparacao nunca envia o pedido ao agente.

manter-migracao pode escrever somente MigrationPath. O condutor DevSquad pode
escolher um subagente disponivel para leitura e proposta de reconciliacao, sem
nome fixo. Esse apoio nao escreve nem subdelega; o condutor confere e grava o
registro, preservando decisoes humanas. Delegar e opcional e nao inicia outras fases.
Planejador/executor podem registrar andamento, cobertura e evidencia das issues
do trabalho autorizado nesse
destino explicito; escolhas humanas, outras issues e catalogo ficam preservados.
Isso amplia os dois destinos anteriores de forma delimitada, sem autorizar escrita
geral em .harness, fontes no planejamento ou GO/aceite pelo agente.
