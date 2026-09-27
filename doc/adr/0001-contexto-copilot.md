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
