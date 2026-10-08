# Planejamento da migração — {{escopo}}

**Revisão:** {{ID}} · **Data de referência:** {{data}} · **Estado:** {{estado}}  
**Viabilidade:** {{classificação e motivo em uma frase}}  
**Revisão anterior:** {{link ou primeira versão}}

## Escopo e resultado esperado

<Um parágrafo: aplicações/módulos, plataforma de origem e destino, resultado
da migração e exclusões relevantes.>

| Restrição | Planejamento |
| --- | --- |
| Período | {{início}} a {{prazo máximo de produção}}; sprints de 14 dias |
| Limites | Preparação ≤ {{P}}; implementação ≤ {{I}}; testes integrados ≤ {{T}}; total {{limite, se informado}} |
| Equipe | Até {{D}} devs + 1 arquiteto + 1 DevOps; dedicação {{resumo}} |
| Base de issues | {{N0}} iniciais, {{concluídas iniciais}}; {{novas/reabertas/excluídas}}; total atual {{N}} |
| Produção | Prevista {{data ou não definida}}; limite {{data}}; janela {{período}}; margem {{dias}} |
| Premissas críticas | {{calendário, estimativas e dependências que condicionam a previsão}} |

## Linha do tempo

<Inserir Gantt Mermaid com datas confirmadas e marcos. Manter a matriz abaixo
como leitura independente do suporte a Mermaid. Sem datas, usar apenas S1..Sn.>

| Macroatividade | S1 {{datas}} | S2 {{datas}} | … | Produção {{janela}} |
| --- | --- | --- | --- | --- |
| Preparar ambientes e esteira | {{trabalho/marco}} | {{…}} | {{…}} | {{…}} |
| Migrar configuração JBoss | {{trabalho/marco}} | {{…}} | {{…}} | {{…}} |
| Corrigir issues e dependências | {{agrupamento}} | {{…}} | {{…}} | {{…}} |
| Integrar e validar corretivas | {{validação}} | {{…}} | {{…}} | {{…}} |
| Testes integrados/homologação | {{…}} | {{…}} | {{…}} | {{…}} |
| Preparar e executar implantação | {{…}} | {{…}} | {{…}} | {{marco}} |

## Sprints, metas e capacidade

Percentuais sobre a baseline {{ID, N0}}; previsto e realizado são acumulados.
Carga/capacidade em dias-pessoa: Dev · Arq · Ops.

| Sprint/período | Entrega e marco principal | Previsto: issues / % | Realizado na data de referência | Carga / capacidade por papel |
| --- | --- | --- | --- | --- |
| S1 — {{início–fim}} | {{marco verificável}} | {{n/N0; %}} | {{n/N0; % ou ainda não aferido}} | Dev {{a/b}}; Arq {{c/d}}; Ops {{e/f}} |
| S2 — {{início–fim}} | {{marco verificável}} | {{n/N0; %}} | {{…}} | {{…}} |

## Objetivo da HU por sprint

### S1 — {{título da HU principal}}

**Objetivo:** <resultado técnico e benefício esperado em 2–3 frases, incluindo
o recorte da migração>. **Aceite resumido:** {{evidência necessária para o marco}}.
**Referências:** {{projeto, agrupamento/IDs e links de ficha, plano e to-do existentes}}.

### S2 — {{título da HU principal}}

**Objetivo:** {{resultado e benefício}}. **Aceite resumido:** {{evidência}}.
**Referências:** {{links existentes; para plano ainda não elaborado, “a detalhar”}}.

## Impedimentos e decisões

| Ponto | Impacto no marco/prazo | Decisão ou ação necessária |
| --- | --- | --- |
| {{risco, sobrecarga, dependência ou lacuna}} | {{efeito concreto}} | {{decisão/papel responsável}} |

**Fora do horizonte / a estimar:** {{resumo e link para a relação completa}}.
**Mudanças desta revisão:** {{até cinco mudanças relevantes, causa e impacto}}.

## Documentos de referência

- [Índice dos projetos]({{ProjectIndexPath}}).
- [Registro da migração — projeto]({{MigrationPath}}).
- [Priorização/fichas]({{caminho existente}}).
- [Plano da issue/agrupamento]({{PlanPath}}) e [to-do]({{TodoPath}}).
- [Configuração JBoss / testes / implantação]({{documentos existentes}}).
- [Dados do planejamento]({{SprintDataPath}}) e [revisão anterior]({{Previous}}).
