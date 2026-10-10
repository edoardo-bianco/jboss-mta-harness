# Organização simplificada por projeto

**Estado:** especificação para implementação no harness atual, em Windows PowerShell 5.1.  
**Revisão:** 10/10/2026. **Destino:** `doc/features/organizacao-simplificada-por-projeto.md`.

**Prioridade definida pelo desenvolvedor em 10/10/2026:** entregar esta simplificação
e a transição dos registros antes de modernizar o harness ou acrescentar outras
funcionalidades. Esta entrega incorpora os requisitos e o
[plano de viabilidade e implementação](../../tasks/plan.md#simplificacao-prioritaria-por-projeto---2026-10-10);
o comportamento ainda não foi implementado. O
[checklist](../../tasks/todo.md#simplificacao-prioritaria-por-projeto---2026-10-10)
separa preparação concluída de execução futura.

## 1. Objetivo e limites

Organizar o trabalho pelo projeto Maven, com caminhos previsíveis e somente o estado atual e a última base reconciliada. Cada publicação substitui o conteúdo anterior. O desenvolvedor escolhe o projeto e a operação; o harness resolve os arquivos.

Este documento é a fonte única das regras permanentes de identidade, armazenamento, leitura de MTA e manutenção. A [conversão dos registros existentes](conversao-descartavel-dos-registros.md) é um utilitário separado e descartável. Node, LangGraph e integração com IntelliJ pertencem à modernização posterior.

Não manter histórico, pastas por execução, arquivos de revisões, backups permanentes ou cadeias de apontadores. Hash, GUID, RunId e RequestId deixam de ser requisitos para localizar, reconhecer ou retomar o trabalho. Identificadores funcionais de issues e regras continuam válidos; conteúdo bruto de ferramentas e referências Git informativas não precisam ser apagados.

**Esclarecimento do desenvolvedor:** retirar os recibos e os rastreamentos que
dificultam encontrar informações. Não substituir esses mecanismos por novos
manifestos, selos, mapas permanentes ou históricos com outro nome. O contexto
corrente informa escopo e caminhos; não funciona como recibo imutável. Decisões,
GO, aceite e pendências continuam legíveis nos documentos correntes. Os arquivos
transitórios de recuperação de escrita não participam da navegação do desenvolvedor.

## 2. Identidade: o nome vem do POM

O nome do projeto e de sua pasta será exatamente o `project.artifactId` do `pom.xml` selecionado:

`<artifactId>simtr-api</artifactId>` → `.harness/projetos/simtr-api/`.

Ler o filho `artifactId` diretamente sob `project`, respeitando o namespace XML. Não usar o primeiro `artifactId` encontrado no documento: ele pode pertencer ao `parent`, a uma dependência ou a um plugin. Não usar `name`, nome do repositório, nome da pasta do clone ou um apelido informado no cadastro.

| Situação | Regra |
| --- | --- |
| Projeto com vários módulos | O POM selecionado define o escopo. Ao selecionar o agregador, usar seu `artifactId`; os módulos permanecem escopos internos. Um módulo só vira projeto separado quando seu próprio POM for selecionado para gestão independente. |
| Mesmo projeto em outro caminho | Atualizar a associação ao POM; não criar outro projeto. |
| Checkouts simultâneos | Manter um checkout ativo por projeto em cada raiz de dados do harness. Trabalho paralelo independente usa outra raiz, conservando o mesmo nome. |
| Mesmo `artifactId` em projetos distintos | Informar colisão e impedir mesclagem/sobrescrita. Corrigir a associação ou usar raízes de dados distintas; não acrescentar hash, contador, `groupId` ou apelido ao nome. |
| POM ausente, XML inválido ou nome não resolvido | Explicar o problema e solicitar o POM correto. Não criar identidade alternativa. |
| Nome incompatível com pasta no Windows | Informar a incompatibilidade, sem sanitizar silenciosamente ou mudar o POM. |
| Alteração do `artifactId` | Exigir realinhamento explícito da pasta administrada e de seus links; não criar projeto vazio nem renomear fontes automaticamente. |

O `artifactId` não é globalmente único; as coordenadas Maven incluem também `groupId`. A verificação de colisão protege os dados sem transformar as coordenadas em uma nova convenção de pastas. [M1]

## 3. Estrutura e responsabilidade dos dados

Todos os registros administrados pelo harness pertencem a `.harness/projetos/<artifactId>/`. Fora dessa área ficam os índices gerais, em `.harness/indices/`, e os componentes compartilhados do produto, como ferramentas e configuração de instalação.

| Caminho relativo ao projeto | Responsabilidade |
| --- | --- |
| `projeto.json` | Associação ao POM e configuração das origens externas. |
| `indice.md` | Visão derivada do projeto, com links estáveis e situação atual. |
| `migracao.md` | Registro das decisões humanas; preservar seu conteúdo manual. |
| `atual/diagnosticos/` | Últimos resultados administrados localmente, como Sonar e, opcionalmente, MTA. |
| `atual/build/` | Resultado e logs da última tentativa de build. |
| `atual/priorizacao/<categoria>/` | Priorização corrente, cobertura e dossiês por chave funcional de issue. |
| `atual/planejamento/` | Plano, tarefas e contexto correntes. |
| `atual/sprints/<cenario>/` | Um conjunto corrente por cenário funcional, sem versões do mesmo cenário. |
| `atual/operacao.json` | Última situação por operação, com data e erro quando houver; sem lista de execuções. |
| `reconciliado/` | Resultado da última reconciliação e pendências; sem reproduzir o MTA nem duplicar fichas, planos e registro humano. |
| `evidencias/` | Anexos humanos necessários ao trabalho corrente. |
| `recebido/` | Material de um colega aguardando leitura e reconciliação; área temporária, não um terceiro estado ou histórico. |
| `temporarios/` | Área transitória de preparação e recuperação de escrita. |

Criar apenas áreas utilizadas. `atual` e `reconciliado` são os próprios destinos dos arquivos, não aliases para revisões escondidas. Usar nomes estáveis, como `plano.md`, `tarefas.md` e `contexto.json`.

O POM é a fonte do nome; `projeto.json` guarda a associação, sem outro campo editável de nome ou identidade técnica. Exemplo de configuração mínima proposta:

```json
{
  "pom": "D:/Fontes/simtr-api/pom.xml",
  "mta": {
    "diretorio": "D:/RelatoriosMTA/simtr-api"
  }
}
```

Caminhos de configuração podem ser absolutos ou relativos à raiz do workspace que contém `.harness`; nunca relativos ao diretório corrente do terminal. Links entre documentos administrados são relativos ao arquivo que os contém. O resolvedor central faz essa distinção.

Não replicar fontes de verdade: o relatório MTA permanece na origem; cada ficha contém somente as informações essenciais de sua issue; decisões são editadas no registro humano; planos e tarefas têm seus próprios arquivos correntes. Índices apontam para esses documentos. `reconciliado` registra apenas o resultado da última conciliação, sem criar outra base de issues ou uma réplica de `atual`.

## 4. Atual, reconciliação e continuidade

| Operação | Comportamento |
| --- | --- |
| Consultar diagnóstico | Ler o último resultado utilizável na origem da ferramenta. Informar falhas recentes conhecidas. |
| Continuar trabalho | Abrir plano e tarefas correntes, usando a base reconciliada disponível. |
| Trabalhar sem reconciliação anterior | Permitir proposta com as evidências disponíveis, identificada como preliminar. |
| Reconciliar | Confrontar diagnósticos, material recebido, decisões humanas e trabalho corrente; atualizar os documentos afetados e substituir a base reconciliada. |
| Executar corretiva | Usar o plano corrente, verificando se a autorização ainda vale para seu conteúdo e escopo. |

Um diagnóstico novo não altera silenciosamente a reconciliação nem concede GO. Comparar os dados relevantes com as fichas, decisões e trabalho corrente e sinalizar pendências quando houver diferenças; a data do arquivo, sozinha, não comprova equivalência, reconciliação ou aprovação. Mudanças de decisões, plano ou escopo também exigem reavaliar as autorizações afetadas. Preservar a semântica existente de MTA/EVIDENCIAS, proposta, GO e aceite.

Um relatório utilizável pode conter problemas e gates reprovados. Falha de geração não substitui um diagnóstico completo por dados parciais; registrar a falha na situação da operação. Para build, apresentar a última tentativa, inclusive quando ela falhar.

A continuidade está nas informações essenciais das fichas, nas decisões de `migracao.md` e no plano corrente. Não depende de preservar o MTA anterior nem de gerar um arquivo intermediário com seus dados. Se o relatório anterior for apagado, seu detalhamento completo deixa de estar disponível; os links passam a apontar para o MTA atual durante as operações normais de atualização.

## 5. MTA: leitura direta na pasta configurada

O MTA pode permanecer na pasta em que foi gerado, inclusive fora do harness. Configurar `mta.diretorio` uma vez por projeto. Trocar ou acrescentar um relatório nessa pasta não exige importação, adoção, cadastro ou conversão.

A pasta externa configurada é a única origem consultada. Sem configuração externa, usar o destino interno padrão `atual/diagnosticos/mta/`. Não misturar as duas origens nem recorrer silenciosamente ao destino interno quando a pasta externa estiver indisponível.

### Descoberta e seleção

Todos os consumidores usam o mesmo resolvedor, com estas regras:

1. Reconhecer conjuntos completos dos formatos MTA suportados na pasta configurada e em suas subpastas. Não tratar HTMLs, JSONs e assets do mesmo conjunto como relatórios independentes, nem buscar fora dessa origem.
2. Havendo um conjunto utilizável, lê-lo diretamente. Havendo vários, escolher a maior data de geração válida disponível no relatório; para o candidato sem essa data, usar a última modificação de seu arquivo de entrada reconhecido. Comparar as datas na mesma referência de fuso horário.
3. Em empate, selecionar o primeiro caminho relativo em ordenação ordinal e informar o selecionado. Esse desempate garante repetibilidade, não comprova qual análise ocorreu depois.
4. Se o candidato mais recente estiver incompleto, ilegível ou em formato incompatível, informar o motivo e identificar o anterior utilizável, caso exibido. Distinguir também pasta inacessível, pasta vazia e relatório de outra aplicação.
5. Ler os dados necessários uma vez por operação. Regravação externa detectada durante a leitura exige repetir a leitura ou interromper com diagnóstico; nunca publicar o conjunto parcialmente lido.

A associação da pasta ao projeto basta para descobrir os candidatos. Não exigir recibo, manifest do harness, hash, RunId, índice prévio, `active-mta` ou igualdade com o caminho absoluto do clone usado na análise. Se o conteúdo identificar inequivocamente outra aplicação fora do escopo selecionado, informar a divergência e não incorporá-la silenciosamente.

Não copiar, mover, espelhar ou manter cache persistente do relatório externo. A limpeza normal do harness não altera sua origem. Ler e tratar os dados necessários em memória durante a operação, sem persistir outra representação completa ou normalizada do MTA.

### Priorização, fichas e links

Preparar priorização, fichas ou planejamento não gera um novo arquivo MTA: nem cópia do relatório, nem extrato em Markdown, JSON ou outro formato intermediário. O relatório original é a fonte do detalhamento.

| Documento | Conteúdo e referência |
| --- | --- |
| Priorização | Lista e campos necessários à ordenação, com links para as fichas; sem repetir seus detalhes. |
| Ficha da issue | Identificação funcional, resumo do problema, localização relevante, impacto e encaminhamento essencial; link para o detalhe correspondente no MTA ou, quando não houver, para a entrada do relatório. |
| `migracao.md` | Decisões, situação e encaminhamentos, com links para a ficha e para o MTA atual; sem reproduzir o diagnóstico. |
| Contexto do agente | Escopo e caminhos dos documentos e do MTA; sem criar um arquivo auxiliar com a reprodução de seus dados. |

As fichas não transcrevem todas as ocorrências, trechos de código ou recomendações extensas do relatório. O conteúdo completo continua acessível pelo link. Dados resumidos usados para ordenar ou calcular trabalho são derivados para essa finalidade, não um segundo relatório.

**Navegação até a fonte:** fichas, planos e demais documentos de detalhe devem
incluir um link junto de cada referência a relatório, código-fonte, POM,
configuração ou evidência. Um nome de arquivo ou ID em texto simples não basta.
O link aponta diretamente ao arquivo original ou ao detalhe existente no relatório;
linha e símbolo podem complementar a localização. Para código da aplicação, usar
o Source local associado ao POM, sem depender do snapshot do clone de outra máquina.
Preservar localização informada pelo diagnóstico e distinguir o arquivo local
conferido de um candidato ainda não verificado. Se a fonte estiver indisponível,
indicar essa condição e sua localização conhecida, sem fabricar destino ou âncora.
Relocalização e reconciliação regeneram os links gerenciados para as fontes locais,
preservando texto manual. Validar abertura em caminhos com espaços e acentos.

Gerar links Markdown para o relatório na origem. Não exigir um arquivo redirecionador, cópia local ou comando exclusivo de uma IDE para abri-lo. Usar links relativos quando aplicáveis e o formato de caminho externo compatível com o ambiente.

O resolvedor identifica o MTA atual; preparar priorização, atualizar fichas/índices ou reconciliar atualiza os links gerenciados, inclusive em `migracao.md`, preservando o texto humano. Não há edição manual de caminhos por execução. Ao receber arquivos de um colega, regenerar esses links para a origem local configurada.

Se o novo MTA não contiver um detalhe antes referenciado, manter a ficha e indicar a ausência; oferecer o link para a entrada do relatório atual. Não inventar âncora nem concluir automaticamente que a issue foi resolvida. Rotular os links como “MTA atual” para não confundir a consulta atual com uma evidência histórica.

## 6. Implementação e manutenção

Centralizar em um módulo pequeno a leitura da identidade Maven, resolução dos caminhos, descoberta do MTA, publicação e reconstrução dos índices. Cada capacidade mantém suas regras de negócio e usa esse módulo comum. Não duplicar resolvedores em scripts, menus ou interfaces.

### Superfícies a adaptar

| Superfície | Alteração |
| --- | --- |
| Scripts, módulos, schemas e contratos | Usar projeto e caminhos fixos; remover navegação por execuções, revisões e cadeias `Previous`/`ImportedFrom`. |
| Planos, tarefas, prompts, índices e documentos | Usar fichas essenciais e links para o MTA na origem; remover arquivos intermediários que reproduzem o relatório e preservar conteúdo humano. |
| Run Tasks, menus e geração do workspace | Encaminhar POM/projeto e operação para a mesma lógica. |
| Sprints, reconciliação e limpeza | Consumir o estado corrente e, quando houver, os arquivos recebidos, sem reconstruir o layout legado. |
| Importação e exportação existentes | Remover tarefas, comandos, contratos de pacote e dependências; compartilhar por cópia e usar a reconciliação comum. |
| Exemplos, fixtures, testes e ADRs afetadas | Expressar o mesmo contrato e retirar instruções incompatíveis. |

Inventariar referências a `RunId`, `RequestId`, `PlanningId`, `RevisionId`, `Previous`, `ImportedFrom`, `p_`, `solicitacao_`, `active-mta`, `last-*` e raízes antigas. Não fazer substituição textual cega. `PlanPath`, `TodoPath` e `ContextPath` podem continuar como saídas de caminhos canônicos; IDs de issues, dados de ferramentas e referências Git informativas permanecem quando úteis.

A lista inicial de componentes a conferir inclui [Harness.psm1](../../scripts/Harness.psm1),
[HarnessProjectIndex.psm1](../../scripts/HarnessProjectIndex.psm1),
[HarnessPlanning.psm1](../../scripts/HarnessPlanning.psm1),
[HarnessIssuePlanning.ps1](../../scripts/HarnessIssuePlanning.ps1),
[HarnessBuild.psm1](../../scripts/HarnessBuild.psm1),
[HarnessCleanup.psm1](../../scripts/HarnessCleanup.psm1) e as famílias
[HarnessPrioritization](../../scripts/HarnessPrioritization.psm1),
[HarnessSprint](../../scripts/HarnessSprintPlanning.psm1),
[HarnessTransfer](../../scripts/HarnessTransfer.psm1) e
[HarnessSonar](../../scripts/HarnessSonar.psm1). Essa lista orienta o inventário,
não substitui a inspeção do código vigente. Na família HarnessTransfer, retirar
os fluxos de importação/exportação e seus chamadores; conservar apenas eventual
lógica de comparação útil à reconciliação comum, sem manter uma camada de
transferência com outro nome.

### Publicação e recuperação

Preparar e validar os resultados antes de substituir os arquivos correntes. Serializar escritas por projeto e impedir que uma operação consuma uma publicação incompleta. Uma execução deve usar uma base consistente do início ao fim.

Uma troca de vários arquivos não é presumida atômica. Em falha, recuperar um conjunto completo antes de liberar o projeto. Material de recuperação existe apenas em `temporarios/` durante a escrita ou sua recuperação; removê-lo após o sucesso. Não expô-lo como versão consultável.

Regenerar índices após publicação válida. Índice ausente ou desatualizado não impede reconhecer um projeto nem ler seu MTA. Arquivo canônico ausente deve produzir diagnóstico específico, sem procurar caminhos legados. Manter somente evidências ainda necessárias ao estado corrente ou reconciliado.

### Sprints

Cenários multiprojeto têm um único registro mestre sob um dos projetos Maven participantes, escolhido como coordenador. Os demais projetos e os índices apenas apontam para ele. Não criar projeto fictício sem POM. Preservar capacidade, dependências e baseline vigente do cenário, sem cadeia de revisões.

### Compartilhamento por cópia e reconciliação

Eliminar as funções próprias de importação e exportação. Os arquivos correntes do projeto são o material compartilhável, sem formato de pacote, manifest, recibo ou cadastro de transferência.

O colega copia a pasta do projeto ou os documentos necessários pelo mecanismo habitual de arquivos. Compartilhar planos, tarefas, registros, base reconciliada e evidências pertinentes; índices gerais, temporários e material recebido pendente não fazem parte do trabalho a transmitir.

| Situação no destino | Procedimento |
| --- | --- |
| Projeto ainda sem trabalho local | Copiar para `.harness/projetos/<artifactId>/`, associar o POM local e conferir as origens externas. Regenerar o índice pela operação normal. |
| Projeto com trabalho local | Colocar o conjunto recebido em `.harness/projetos/<artifactId>/recebido/`, preservando sua organização interna. Não copiar por cima de `atual` ou de `migracao.md`. |
| Material já disponível em outra pasta | A mesma reconciliação pode ler essa pasta diretamente, sem exigir uma cópia intermediária em `recebido/`. |

A operação existente de reconciliação lê o material de origem, compara com o trabalho local e apresenta diferenças relevantes. Conteúdo equivalente não gera duplicação; divergências de decisões, status ou escopo são resolvidas antes de atualizar os arquivos afetados. Não escolher o trabalho do colega apenas porque tem data mais recente. Identificadores funcionais das issues continuam sendo usados para reconhecer o mesmo problema.

Preservar as associações locais ao POM e ao MTA. Configurações com caminhos da máquina do colega não substituem as locais automaticamente. O MTA bruto continua em sua origem configurada, sem cópia exigida pelo compartilhamento.

Após reconciliar, atualizar os arquivos correntes, substituir a única base reconciliada e regenerar índices. A cópia não transfere GO automaticamente. O material aceito ou descartado sai de `recebido/`; enquanto houver conflito pendente, permanece ali. A pasta externa usada como origem não é apagada pela reconciliação.

Não criar uma tarefa de importação para executar esse fluxo. Usar a reconciliação comum com uma pasta de origem opcional, sem identificador de transferência ou cadeia de versões.

## 7. Entrega e aceite

Implementar conforme o `AGENTS.md` vigente no repositório. Primeiro fechar o contrato comum; depois adaptar produtores, consumidores e documentação. Validar um projeto novo e, separadamente, um projeto convertido. O núcleo não pode importar código do conversor nem manter fallback para o legado.

**Limpeza e orientação são parte obrigatória da entrega.** Depois da adaptação e
da conversão validada, retirar dependências operacionais superadas e atualizar os
[guias](../guias/harness-migracao-desenvolvedor.md), a
[skill do orientador Codex](../../.agents/skills/orientar-migracao/SKILL.md), os
[helpers Copilot](../../.github/agents/migracao_helper.agent.md),
[prompts](../../.github/prompts/) e [instruções do repositório](../../AGENTS.md).
Todos devem usar projeto, arquivos correntes e links diretos, sem orientar busca
de recibos/rodadas ou reconstrução de cadeias. Remover tarefas e exemplos obsoletos;
preservar decisões humanas e documentação histórica identificada como tal.
O orientador continua leitor e entrega uma próxima ação com caminho/link pronto,
sem conceder GO nem aceite. Conferir o fluxo nos dois clientes antes da conclusão.

| Cenário de verificação | Resultado exigido |
| --- | --- |
| POM com `parent`, dependências e módulos | Pasta com o `project.artifactId` do POM selecionado; nenhum nome obtido de outro elemento. |
| Mesmo nome em projetos distintos ou checkouts concorrentes | Conflito diagnosticado, sem sobrescrita, mistura ou sufixo automático. |
| Segunda publicação e segunda reconciliação | Substituição nos mesmos destinos; somente atual e último reconciliado, sem versões ou backups permanentes. |
| MTA já existente em pasta externa | Consulta e priorização funcionam sem cópia, registro de execução ou conversor. |
| Preparar priorização, fichas e contexto | Nenhum novo arquivo de dados MTA é criado; fichas contêm apenas o essencial e links abrem o relatório na origem. |
| Ler um documento de detalhe | Cada referência tem link direto para a fonte/arquivo; abertura do MTA, fonte local e anexo é conferida. Fonte indisponível é sinalizada, sem caminho ou âncora inventados. |
| Fichas e `migracao.md` após troca de MTA | Links gerenciados são atualizados nas operações normais; detalhe ausente é informado, sem perda de texto humano ou resolução automática da issue. |
| Novo MTA na mesma pasta e remoção do anterior | Novo resultado reconhecido e links atualizados sem edição manual; fichas, decisões e plano continuam legíveis sem um extrato MTA persistido. |
| Vários MTAs, empate, candidato incompleto e origem indisponível | Seleção comum e reproduzível; diagnóstico específico, sem fallback oculto. |
| Diagnóstico ou plano alterado | Pendências de reconciliação e autorizações afetadas são explicitadas. |
| Falha durante publicação ou leitura externa | Nenhum resultado parcial liberado; recuperação consistente e limpeza dos temporários. |
| Índices apagados ou desatualizados | Reconstrução a partir dos projetos, sem restabelecer controles por execução. |
| Conversor, funções antigas de transferência e controles legados indisponíveis | Consulta, planejamento, reconciliação, sprints e compartilhamento por cópia continuam funcionando. |
| Arquivos de um colega em `recebido/` ou pasta externa | A reconciliação comum lê e compara sem pacote, manifest ou tarefa de importação; trabalho local não é sobrescrito pela cópia. |
| Mesmo material recebido novamente | Nenhuma duplicação de issues ou documentos; diferenças reais são explicitadas. |
| Material recebido de outra máquina | Caminhos locais do POM e do MTA preservados; autorizações reavaliadas quando necessário. |
| Reconciliação concluída e limpeza | `recebido/` não acumula histórico; conflitos pendentes e origens externas permanecem intactos. |
| Windows PowerShell 5.1 | Fluxos válidos com caminhos contendo espaços e acentos. |
| Limpeza, guias e agente orientador | Nenhuma dependência operacional de recibos ou instrução obsoleta permanece; Codex e Copilot encontram trabalho corrente e fontes por links diretos, mantendo GO/aceite separados. |

A conclusão exige remover dependências operacionais antigas em todos os arquivos ativos, não apenas mudar os nomes das pastas.

## 8. Referências e alcance da revisão

Esta revisão audita as duas especificações e sua consistência com as decisões do usuário. Não certifica a implementação nem uma revisão atual do código na `main`.

- **[M1]** [Apache Maven — POM Reference](https://maven.apache.org/pom.html#Maven_Coordinates): distinção entre `artifactId`, `groupId`, herança e agregação. A convenção de pastas e o tratamento de colisões acima são decisões deste harness.
- [Arquitetura do harness](https://github.com/edoardo-bianco/jboss-mta-harness/blob/main/doc/arquitetura/arquitetura-harness.md) e [AGENTS.md](https://github.com/edoardo-bianco/jboss-mta-harness/blob/main/AGENTS.md): conferir durante a implementação.
- ADRs de alinhamento: [planejamento](https://github.com/edoardo-bianco/jboss-mta-harness/blob/main/doc/adr/0005-planejamento-orientado-pelo-registro.md), [dossiês](https://github.com/edoardo-bianco/jboss-mta-harness/blob/main/doc/adr/0006-categorias-e-dossie-por-issue.md), [compartilhamento](https://github.com/edoardo-bianco/jboss-mta-harness/blob/main/doc/adr/0007-compartilhamento-de-contextos.md) e [modernização](https://github.com/edoardo-bianco/jboss-mta-harness/blob/main/doc/adr/0008-nucleo-perfis-e-plataforma-do-harness.md).

