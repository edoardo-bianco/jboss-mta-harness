# Engineering Harness — plano tático e implementação

**Documento 3 de 3 · Revisão de 19/10/2026 · Decisões tecnológicas, incrementos, verificação e auditoria**

**Direção:** [Estratégia e arquitetura](01-estrategia-e-arquitetura.md) · **Contratos:** [System design](02-system-design.md)

## 1. Objetivo e responsabilidade deste documento

Transformar a arquitetura em incrementos executáveis sem reescrever a base inteira, reconstruir a simplificação já adotada ou transformar o harness em um framework genérico de agentes.

A definição do produto pertence ao documento 1. Os contratos e o layout pertencem ao documento 2. Este documento registra escolhas, critérios de implementação e uma revisão crítica final. O estado das entregas continua no acompanhamento canônico do repositório, como `tasks/plan.md` e `tasks/todo.md`; esta proposta não é um segundo backlog de status.

Este conjunto foi incorporado ao repositório em 17/10/2026, substituindo `doc/arquitetura/`, `doc/especificacoes/`, `doc/features/` e `doc/estrategia/` (seção 8). A baseline `6566bb8` já inclui a parte JBoss do incremento A e o adaptador assistido Claude Code; os contratos mínimos, os demais incrementos e a integração programática continuam propostos. Implementação, ensaio e aceite são estados distintos, acompanhados em `tasks/`. Esta revisão documental não instala ferramentas nem homologa integrações.

## 2. Escolhas tecnológicas e seus compromissos

### 2.1. Runtime: Node.js 24 LTS

**Escolha proposta:** Node.js 24 LTS como primeira linha de homologação do núcleo. Na consulta de 16/10/2026, o projeto Node identifica 24 e 22 como LTS e 26 como Current. Fixar o patch aprovado na distribuição, em vez de depender de `latest` na execução. A política de suporte deverá ser revista quando uma release do harness for preparada. [O3](#fonte-o3)

**Justificativa:** o produto precisa coordenar arquivos, contratos e processos locais, e a base já possui integração Node no MCP. Não há benefício demonstrado em introduzir um servidor Java/Quarkus para esse núcleo. Java continua apropriado às ferramentas especializadas; PowerShell permanece onde seu uso já resolve uma necessidade real.

**Compromisso:** Node não elimina runtimes externos, shims Windows, limitações de filesystem ou homologação corporativa. Um pacote compilado pode ser distribuído para execução em diretório do usuário, mas o executável e suas dependências continuam sujeitos à aprovação do ambiente.

### 2.2. Linguagem e módulos: TypeScript compilado, ESM e composição explícita

**Escolha proposta:** TypeScript com verificações estritas, compilação para JavaScript ESM e imports que funcionem no runtime escolhido. O processo de build deve verificar tipos; não depender apenas da execução direta de `.ts`. A documentação do Node esclarece que remoção de tipos não substitui type checking, e o TypeScript oferece o modo `strict`. [O4](#fonte-o4) [O22](#fonte-o22)

Usar módulos simples e injeção explícita de dependências na composição. Não adicionar framework de servidor, contêiner de DI ou mecanismo genérico de descoberta dinâmica para realizar três ou quatro integrações iniciais.

Os módulos podem ficar no mesmo repositório e seguir uma release coordenada. Separar publicação de pacotes apenas quando um contrato e seu consumidor externo demonstrarem essa necessidade. A independência da implementação é comprovada por testes de contrato, não pelo número de repositórios.

### 2.3. Contratos: JSON Schema e validação na fronteira

**Escolha proposta:** JSON Schema 2020-12 para contratos públicos, com Ajv configurado para esse draft na validação do runtime. O projeto Ajv documenta suporte específico a 2020-12 e alerta que drafts anteriores não podem ser misturados na mesma instância. [O6](#fonte-o6) [O7](#fonte-o7)

Manter uma definição canônica de cada esquema. Tipos TypeScript são auxiliares e devem ter teste de correspondência com os esquemas; não criar uma segunda definição manual divergente para CLI, MCP e provedor. O SDK MCP permanece na fronteira do protocolo. Se a API selecionada exigir conversão de esquema, demonstrar a equivalência no piloto; não acrescentar outro modelo de domínio para satisfazer o SDK.

Validar pedidos e resultados sem coerções silenciosas, resolução remota arbitrária de esquemas ou execução de conteúdo do manifesto. Bloquear extensões de contrato não permitidas. Semântica, autorização e efeitos continuam sendo regras do harness, não propriedades garantidas pelo JSON Schema.

**Alternativa considerada:** manter Zod como fonte canônica de todos os contratos. Pode reduzir mudanças na fronteira MCP existente, mas exigiria disciplina para publicar contratos externos e tratar implementações que não usam TypeScript. A proposta privilegia um contrato interoperável; o primeiro piloto deve demonstrar que o custo adicional de validação e integração permanece pequeno.

### 2.4. Execução: processos locais e wrappers reaproveitados

**Escolha proposta:** executor Node com `node:child_process`, ambiente por processo e protocolo estruturado. Reutilizar wrappers PowerShell 5.1 onde forem necessários ao launcher Windows ou à transição. Não converter tudo antes de obter valor.

O código de build da baseline `6566bb8` já trata fases permitidas, JDK efetivo, logs e código de saída e publica a última tentativa em `atual/build/` com a situação em `operacao.json`, sem `RunId` ou pasta por execução. Durante uma chamada integral desse fluxo, o PowerShell continua sendo o único responsável pelo lock e pela publicação. O incremento B separa execução e publicação para cumprir o contrato `process-json` do documento 2; uma ponte que apenas chama o fluxo legado não conclui essa prova. [R4](#fonte-r4)

O tratamento de `.cmd`, cancelamento e descendentes precisa de testes Windows específicos. `shell: false` é uma preferência para executáveis compatíveis, não uma solução universal para `mvn.cmd`. [O5](#fonte-o5)

### 2.5. Persistência: arquivos correntes, sem banco adicional

**Escolha proposta:** JSON para dados estruturados, Markdown para conteúdo humano e diretórios canônicos da simplificação. Reutilizar mecanismos de publicação recuperável e desenvolver somente as lacunas necessárias ao processo Node. Não introduzir SQLite, event store, snapshots permanentes ou índice que se torne fonte de identidade.

A gravação precisa suportar recuperação de uma publicação interrompida, mas o material de recuperação é transitório. Não confundir simplificação de retenção com sobrescrita insegura. A transação lógica entre vários arquivos é um mecanismo do produto e exige teste de falha; não vem pronta de uma chamada de filesystem. [O16](#fonte-o16)

### 2.6. Interfaces: CLI primeiro, IDEs finas, MCP opcional

**Escolha proposta:** CLI compilada como referência; VS Code Run Tasks e IntelliJ External Tools locais no primeiro piloto de interfaces. Uma extensão própria é posterior. [O11](#fonte-o11) [O18](#fonte-o18)

Para MCP, utilizar o SDK TypeScript oficial e `stdio`, reaproveitando a integração existente quando compatível. Fixar a versão efetiva de dependências no lockfile e testar os clientes. A versão do SDK registrada na `main` não deve ser assumida como a versão mais recente ou como suporte automaticamente homologado. [R5](#fonte-r5) [O19](#fonte-o19)

Não criar um servidor MCP por ferramenta, não substituir CLI por MCP e não expor execução de shell genérica. A primeira superfície MCP continua de consulta. Ferramentas de mutação dependem do contrato de autoridade e da prova descritos no documento 2.

### 2.7. Coding agents: entrega assistida antes de automação ampla

**Decisão do desenvolvedor em 19/10/2026:** **Codex e GitHub Copilot são os agentes principais; Claude Code é secundário**. A prioridade orienta os pilotos, preservando a arquitetura independente de agente e os adaptadores existentes. Começar com contexto preparado e acionamento humano e validar depois uma única integração programática documentada. [O13](#fonte-o13) [O14](#fonte-o14) [O24](#fonte-o24)

**Codex** é o candidato inicial à primeira integração programática, por essa prioridade: `codex exec`, eventos JSONL com `--json` e resposta final com `--output-schema`. O adaptador deve distinguir os eventos da resposta final e convertê-la ao envelope do harness, mantendo permissões e escopo explícitos. A documentação confirma a interface; instalação, autenticação e execução Windows continuam condições do piloto. [O13](#fonte-o13)

**Claude Code** permanece alternativa secundária por `claude -p`. Seu modo `--bare` exige contexto, MCP e autenticação fornecidos de forma compatível, pois não carrega automaticamente os artefatos do projeto/usuário. O suporte nativo Windows e a assinatura do binário não alteram a prioridade definida pelo desenvolvedor nem comprovam homologação local. [O24](#fonte-o24) [O26](#fonte-o26)

No ambiente corporativo informado, **não considerar Copilot CLI automaticamente compatível com PowerShell 5.1**: a documentação exige PowerShell 6 ou superior no Windows. Isso não invalida o Copilot na IDE ou a entrega assistida. Manter a restrição explícita e não exigir atualização do shell para viabilizar a arquitetura. [O15](#fonte-o15)

A escolha do primeiro cliente programático depende da instalação realmente autorizada, de testes de permissão/cancelamento e da coleta de resultado. Não começar criando um framework próprio de agentes, nem fazer de um SDK de LLM uma dependência do núcleo.

**Engines candidatos por perfil**, a avaliar em pilotos próprios:

| Engine | Perfil | O que está documentado | Condição a testar |
| --- | --- | --- | --- |
| GitHub Copilot app modernization | Modernização e atualização de JDK/frameworks | Avaliação, plano revisável antes das alterações, receitas OpenRewrite e correção iterativa por agente; destinos Java 8, 11, 17, 21 e 25; exige plano Copilot pago e VS Code 1.101+. [O27](#fonte-o27) | Plano gerado tratado como proposta; GO e verificações continuam no harness. |
| AWS Transform custom | Transformações personalizadas | Workflows com contexto adicional e comandos de validação; Windows/PowerShell com exceções; Node.js 22+, Git e acesso ao serviço. [O31](#fonte-o31) | Os workflows criam commits de checkpoint, em conflito com o Git informativo do contrato; avaliar execução isolada com devolução de diff. O catálogo pronto mira Spring Boot, não EAP 7.4. |

### 2.8. Distribuição e testes

**Escolha proposta:** build reprodutível do pacote, `package-lock.json`, instalação controlada e execução direta do JavaScript compilado. `npm ci` usa o lockfile e rejeita divergências relevantes com `package.json`; não garante, sozinho, cadeia de suprimentos confiável ou instalação sem rede. Dependências devem estar disponíveis pelo canal corporativo aprovado. [O20](#fonte-o20)

O pacote pode declarar `bin` para conveniência, mas não exigir instalação global. Não executar `npx` com resolução/download implícitos em tarefas do harness. [O17](#fonte-o17)

Usar inicialmente o test runner do Node para contratos e módulos extraídos e conservar as suítes PowerShell existentes. O runner nativo fornece mecanismos de teste; a cobertura dos cenários do produto depende das fixtures implementadas. [O21](#fonte-o21)

### 2.9. Compreensão de código Java: estudo adiado

**Problema registrado:** a integração do Serena não foi concluída no Windows corporativo porque o executável distribuído não tem assinatura de código. Não contornar a política de execução para viabilizá-lo.

**Alternativa recomendada para o piloto:** o **Eclipse JDT Language Server** como motor Java único, consumido de duas formas:

| Consumo | Como | Limites |
| --- | --- | --- |
| Pelo harness, como capacidade | JDT LS executado fora da IDE pela CLI, com instância e área de dados próprias, expondo consultas por objetivo para qualquer cliente (inclusive via MCP). [O32](#fonte-o32) | Separar **preparar índice** (efeitos de build e cache declarados) de **consultar índice pronto**. |
| Pelo cliente secundário, em avaliação opcional | Plugin oficial **`jdtls-lsp`** do marketplace da Anthropic no Claude Code: navegação por símbolo (definição, referências, hierarquia) e diagnósticos após cada edição. O plugin só configura o servidor; o `jdtls` é instalado à parte e precisa estar no `PATH`. [O25](#fonte-o25) | Funciona em sessões de terminal, não em sessões na nuvem. Indexação consome memória. Não é pré-requisito dos fluxos Codex/Copilot. |

O JDT LS é uma aplicação Java executada pelo JDK instalado, sem executável nativo próprio a assinar; isso reduz o risco que bloqueou o Serena, mas a política corporativa de execução ainda precisa ser conferida no piloto. Ele exige um JDK moderno (21+) **separado** do Java da aplicação; analisar projetos Java 8 continua possível.

| Alternativa | Decisão |
| --- | --- |
| JDT Core (`ASTParser`) | Coletor complementar para fatos sintáticos; não é índice persistente completo. |
| JavaParser + Symbol Solver | Alternativa delimitada se o piloto JDT não atender; evitar dois motores por padrão. |
| `scip-java` | Não adotar no perfil JBoss: não suporta Java 8 e aciona compilação/limpeza. |
| Serena | Reavaliar somente se houver distribuição assinada aceita pela política corporativa. |

Uma chamada estática não comprova execução: reflexão, CDI/EJB, proxies, geração e configuração externa deixam lacunas. Resultados distinguem cobertura completa no escopo, parcial, desatualizada e falha; resultado vazio só comprova ausência dentro da cobertura declarada.

**Aceite do piloto:** consultar o projeto pela CLI e disponibilizar o resultado a um dos agentes principais pelo contrato comum; verificar sobrecarga/herança, reactor Maven, Java 8, fontes geradas, dependência ausente e alteração após indexação; medir tempo de preparo/consulta, memória e volume de contexto; demonstrar utilidade para ao menos dois objetivos, como impacto de migração e investigação de defeito. A comparação com o plugin Claude Code é opcional e não condiciona o aceite do piloto principal.

## 3. O que não adotar neste ciclo

Não adicionar plataformas externas de observabilidade, banco de dados, contêiner obrigatório, daemon de orquestração, broker, marketplace, workflow engine genérico ou indexação semântica global como pré-requisito.

Não reintroduzir importação/exportação, cópias/extratos MTA, pastas por execução, IDs de navegação ou `reconciliado` como backup. Não tornar o conversor de dados uma dependência permanente.

Também não exigir uma nova instalação JDT para provar a independência básica de IDE. A CLI deve ser neutra; uma capacidade semântica pode continuar dependente de um adaptador específico e aparecer indisponível em outra combinação. O piloto JDT da seção 2.9 é decisão própria, não efeito automático de rodar Node no IntelliJ.

## 4. Situação da baseline (`main` `6566bb8`)

A conciliação documental com o checkout foi atualizada em 19/10/2026. A baseline inclui as PRs #31 a #35; as entregas técnicas abaixo não substituem os ensaios e aceites pendentes em `tasks/todo.md`:

| Requisito | Situação |
| --- | --- |
| Identidade por `artifactId`, `atual`, `reconciliado`, `recebido`, `temporarios`, `operacao.json` | Presente. |
| MTA na origem configurada, seleção por `generatedAt` com fuso ou data de modificação | Presente. |
| Build sem `RunId` ou pasta por execução | Presente. |
| Hashes de concorrência transitórios, sem identidade de execução | Presente; não criam recibos ou caminhos de retomada. Identificadores nativos das ferramentas mantêm suas funções. |
| Mestre de sprints em projeto participante | Presente. |
| Origem EAP 7.0 ou 7.1 | Presente pela chave `eap71`; README e guia central já descrevem ambas as origens. |
| Estado JBoss por projeto/servidor, sem GUID ou hash | Presente desde 17/10/2026 (incremento A): `servidores/<servidor>/` e `projetos/<artifactId>/atual/jboss/<servidor>/ultimo-deploy.json`; deploy substitui o WAR, sem rollback. A pasta legada `.harness/jboss/` é removida manualmente. |
| Backups do workspace com nomes legíveis | **Lacuna menor**: `.harness/workspace-backups/<GUID>.code-workspace`. |
| Orientação em Codex, GitHub Copilot e Claude Code | Artefatos presentes; a PR #35 acrescentou o adaptador Claude Code. Prioridade atual: Codex/Copilot principais e Claude Code secundário. A integração programática continua proposta. |

Nenhum arquivo da aplicação, diagnóstico externo ou trabalho local deve ser movido, renomeado ou eliminado para corrigir as lacunas sem operação de conversão explícita.

## 5. Incrementos de implementação

A ordem abaixo é uma proposta por dependências e provas de valor, sem estimativa de prazo ou autorização implícita. Detalhar apenas o próximo incremento no backlog canônico.

### Incremento A — Contratos mínimos e armazenamento JBoss

**Escopo:** fixar vocabulário, envelope de capacidade e regras de disponibilidade sobre a simplificação já entregue. Alinhar o estado JBoss ao princípio de armazenamento do documento 2: servidor em `servidores/<servidor>/`, deploy em `projetos/<artifactId>/atual/jboss/<servidor>/ultimo-deploy.json`, sem GUID ou hash; nomes legíveis para backups do workspace.

**Decisões do desenvolvedor (17/10/2026):** guardar somente a última operação e o último deploy; o deploy sempre substitui o WAR implantado no JBoss pelo novo, mesmo quando o atual não foi implantado pelo harness; a Run Task `Aplicacao: rollback no JBoss` é retirada (reverter é fazer deploy de um WAR anterior escolhido pelo desenvolvedor). Parte JBoss implementada em 17/10/2026 (branch `harness/jboss-estado-corrente`); contratos mínimos e backups do workspace permanecem.

**Entrega:**

- Contratos canônicos de perfil, capacidade, pedido e resultado em JSON Schema 2020-12, com versões, estados, efeitos, limites e bases dos caminhos. Definir a correspondência dos estados legados e a resolução da fonte humana do GO, sem outro registro de autorização.
- Regras de disponibilidade e fixtures para versão incompatível, provedor ausente, entrada/saída inválida, artefato ausente e divergência de código de saída. São entregas do incremento, não uma biblioteca já disponível nesta revisão.
- Produtores e consumidores JBoss ajustados (`HarnessJboss*`, `gerenciar-jboss.ps1`, Run Tasks e guia), retirada do rollback e fixtures: parte já implementada. A remoção da pasta legada `.harness/jboss/` exige seleção explícita, sem conversor.
- Nomes legíveis para novos backups do workspace, preservando os existentes até eventual seleção explícita de conversão/limpeza.

**Aceite dos contratos:** fixtures válidas aceitas e inválidas recusadas sem coerção; versões incompatíveis e capacidades indisponíveis têm motivo explícito; caminhos são resolvidos pela base de cada campo; estados legados têm uma única correspondência; GO é lido do plano aplicável, sem inferência ou nova confirmação de decisão inequívoca. O incremento B usa esses contratos e comprova a publicação única após validar a saída do provedor.

**Aceite de armazenamento:** nenhuma nova pasta/arquivo operacional nomeado por identificador de execução; segunda operação e segundo deploy substituem o resultado corrente; deploy sobre deployment externo ou alterado substitui o WAR e confirma status e conteúdo depois do envio; falha não é declarada sucesso; novos backups têm nomes legíveis; o caminho principal não depende do conversor ou de operações de importação/exportação. Ensaios e aceite humano da parte JBoss permanecem no acompanhamento canônico.

### Incremento B — Uma capacidade externa real pela CLI

**Escopo:** extrair `maven.build` como prova vertical, usando provedor de processo separado do núcleo. Reutilizar o launcher existente, separando execução de publicação conforme o documento 2, seção 6; acrescentar configuração/diagnóstico estritamente necessários.

**Entrega:** CLI mínima, contrato validado, provedor real e testes. O provedor não pode importar módulos privados do núcleo nem receber comandos arbitrários.

**Aceite:** build permitido, fase inválida, JDK incompatível, falha, timeout e cancelamento têm resultados explícitos. Duas execuções publicam nos mesmos destinos de `atual/build/`. O núcleo publica uma única vez após validar resultado e artefatos transitórios; saída inválida preserva o resultado/log anterior e registra a tentativa inválida na situação da operação, enquanto falha válida de build publica a última tentativa. Alterar a localização instalada do provedor pela configuração aprovada não exige mudança no domínio. Semântica de build permanece equivalente; retenção preserva a baseline simplificada.

**Limite:** não criar todos os perfis e adaptadores durante essa prova. A publicação consistente já é requisito do piloto, não um refinamento a deixar para depois.

### Incremento C — Mesma capacidade no terminal e nas duas IDEs

**Escopo:** configurar Run Task e External Tool para a CLI existente, sem criar plugins de IDE.

**Entrega:** instruções e configuração mínima gerenciada, com parâmetros explícitos e preservação das configurações do usuário.

**Aceite:** mesmo perfil, parâmetros e projeto produzem resultados funcionalmente equivalentes. Diferenças de interface, horários e caminhos locais são previstas. Validar Windows, espaços, acentos, erro do executável e diretório de trabalho incorreto. A execução não depende do chat ou de uma IDE aberta.

### Incremento D — Uma tarefa híbrida com controle humano

**Escopo:** preparar contexto para uma issue real a partir dos documentos correntes e do MTA na origem, entregar ao coding agent escolhido e receber uma proposta por acionamento assistido. Ligar depois a uma alteração delimitada e às verificações existentes.

**Entrega:** tarefa simples com etapas e retornos claros; não um runtime de agentes novo.

**Aceite:** o fluxo pode ser conduzido manualmente. Preparar não equivale a enviar; enviar não equivale a receber; plano não equivale a GO; sucesso técnico não equivale a aceite. Nenhum arquivo auxiliar reproduz o MTA. Mudança de escopo ou evidência insuficiente interrompe a progressão e pede decisão.

### Incremento E — MCP opcional sobre casos de uso já existentes

**Escopo:** expor consultas pertinentes do catálogo, estado e evidências, reaproveitando e migrando compatibilidade da ponte atual.

**Entrega:** um adaptador MCP local, com protocolo correto, sem HTTP obrigatório e sem tornar MCP condição para as outras interfaces.

**Aceite:** cliente inicia/encerra a sessão, saídas estruturadas permanecem válidas, logs não contaminam `stdout`, concorrência e cancelamento têm limites e desabilitar MCP não altera o modo determinístico. Não expor GO, shell livre ou recursão de agentes.

**Sequenciamento:** a base já possui consultas MCP. Reutilizar o que estiver pronto; esta etapa cobre somente as lacunas do novo contrato, não a criação de outro servidor paralelo para a mesma função.

### Incremento F — Automação de um agente e prova de segundo perfil

Os pilotos iniciais de agente e SDLC Quarkus são separáveis. Migração Quarkus, cobertura e modernização são extensões delimitadas após essas provas, conforme a prioridade escolhida.

**Piloto de agente:** partir de `codex exec`, sujeito à instalação realmente aprovada, e testar autenticação, permissões, efeitos, eventos/resposta final, interrupção e rede. Codex e GitHub Copilot são os agentes principais; Claude Code é secundário. Uma falha não dispara outro cliente automaticamente. Manter entrega assistida como modo de operação quando a automação não estiver disponível; GitHub Copilot pela IDE continua caminho principal.

**Piloto de SDLC Quarkus (perfil Desenvolvimento Quarkus):** conduzir **um defeito ou uma melhoria fora de qualquer migração**, com **Java 17 ou superior, incluindo Java 25**, conforme a versão Quarkus. O mesmo núcleo deve relacionar demanda, decisão, alteração e validação, reutilizando a capacidade de build e as ferramentas do projeto: CLI Quarkus para extensões, build e modo de desenvolvimento; testes da aplicação e do artefato (`@QuarkusIntegrationTest`). Aceite: nenhum pré-requisito de MTA, Java 8 ou `javax` no fluxo. [O23](#fonte-o23)

**Piloto de Migração Quarkus:** posterior ao piloto de SDLC; acrescenta par origem/destino de versões, guias e atualização por OpenRewrite, documentada como experimental e parcial e executada somente na etapa autorizada de alteração. A equivalência precisa ser demonstrada no projeto escolhido. [O33](#fonte-o33)

**Cobertura de código:** compor a capacidade transversal com um dos perfis acima (JBoss ou Quarkus), separando testes unitários, de integração e recorte medido; não duplicar os adaptadores Maven/JaCoCo nem tornar a política JaCoCo do recorte JBoss universal.

**Piloto de perfil de modernização:** avaliar o GitHub Copilot app modernization em um recorte delimitado, comparando o plano gerado com o contrato do harness (proposta → GO → execução → verificação → aceite) e registrando o que foi alterado por receita e por agente. [O27](#fonte-o27)

**Aceite conjunto da arquitetura:** trocar perfil não introduz condicionais tecnológicas no núcleo; trocar agente não altera autoridade, layout ou significado da evidência. O primeiro sucesso não autoriza migração ampla de todos os scripts.

## 6. Regras de implementação para tech lead e desenvolvedores

Cada incremento deve ter um caso de uso, efeito esperado, entradas/saídas, restrições, amostra de referência e teste que demonstre a lacuna antes da alteração. Implementar a menor mudança que complete a prova vertical.

Preservar PowerShell enquanto ele for o produtor canônico da capacidade. Na ponte transitória do build, o adaptador Node chama a operação completa sem copiar a regra, duplicar seu lock ou republicar suas saídas. Para entregar o provedor do incremento B, extrair o launcher e suas verificações de modo que a publicação fique exclusivamente no núcleo após validação. Demonstrar equivalência e ajustar os consumidores para a mesma implementação; não manter dois produtores normativos para o mesmo resultado.

A comparação deve separar **semântica preservada** de **comportamento deliberadamente substituído**. Exemplo: fases Maven e falhas precisam continuar corretas; pastas históricas não precisam ser reproduzidas, pois foram removidas pela decisão de simplificação.

As mudanças nas aplicações têm escopo e autorização próprios. Atualizar código do harness não autoriza corrigir POMs, dependências, configurações JBoss ou fontes dos projetos usados como amostra.

Revisão técnica deve observar dependências de módulos, validação das fronteiras, efeitos e caminhos de falha. DevOps e responsáveis corporativos apoiam distribuição, certificados e instalações aprovadas; isso não cria um serviço central novo.

<a id="verificacao"></a>
## 7. Matriz de verificação e critérios de aceite

Os critérios abaixo orientam testes de implementação. Não representam testes do produto executados nesta entrega documental.

| Área | Prova exigida |
| --- | --- |
| Identidade | POM com parent e módulos; colisão de `artifactId`; nome Windows inválido; nenhum alias ou sufixo silencioso. |
| Estado corrente | Segunda execução e reconciliação substituem destinos fixos; nenhum histórico oculto, extrato MTA ou cópia de `atual` em `reconciliado`. |
| Origem MTA | Um/vários relatórios, empate, conjunto incompleto, pasta vazia/inacessível e aplicação divergente; sem fallback oculto ou alteração da origem. |
| Links e conteúdo humano | Troca do MTA atualiza referências gerenciadas, preserva decisões e não inventa âncoras ou resolução da issue ausente. |
| Compartilhamento | Material equivalente não duplica; conflito fica explícito; POM/MTA locais preservados; copiar não transfere GO. |
| Publicação | Falha antes, durante e depois da substituição; reinício recupera conjunto consistente; temporários não viram versões permanentes. |
| Concorrência | Duas CLIs ou CLI+MCP não publicam simultaneamente no mesmo projeto; espera humana não mantém lock; alteração externa é detectada no limite implementado. |
| Contrato externo | Entrada inválida, versão incompatível, provedor ausente, saída JSON inválida, artefato ausente e código de saída divergente. |
| Execução Windows | `.cmd`, caminhos com espaços/acentos, ambiente por processo, timeout e término dos descendentes sem sucesso fictício. |
| Segurança de argumentos | Metacaracteres, caminhos fora do escopo, manifesto não confiável, segredo no log e comando arbitrário são tratados conforme a política. |
| Autoridade | Agente não concede GO; alteração de plano/escopo invalida confirmação aplicável; ausência de superfície humana não libera escrita. |
| Modo manual | Tarefa útil sem LLM, sem MCP e sem IDE; saídas permitem conferência humana. |
| Agente | Contexto preparado sem envio automático; retorno ausente/parcial é informado; cliente indisponível não é substituído sem decisão. |
| MCP | Negociação compatível, `stdout` limpo, ciclo de vida, catálogo limitado e nenhuma anotação de leitura em operação que escreve. |
| IDEs | Terminal, VS Code e IntelliJ executam o mesmo contrato, sem sobrescrever configuração não gerenciada. |
| Segundo perfil | Reuso sem Java 8/`javax`/MTA obrigatórios no núcleo e sem mudar a identidade dos resultados. |
| Conversão | Prévia/aplicação/validação/limpeza separadas; fontes e relatórios externos intactos; runtime funciona com conversor removido. |
| Atualização do produto | Versão incompatível não reinterpreta dados; configurações preservadas; dependências efetivas e versões conhecidas. |

**Critério de avanço:** código, contrato, testes, guia e evidências do incremento são coerentes. Homologação corporativa e aceite humano são registros próprios, não inferidos de testes simulados. Um teste que verifica somente o código de saída não comprova comportamento funcional.

## 8. Consolidação documental executada

Em 17/10/2026, por decisão do desenvolvedor, este conjunto passou a ficar em **`doc/engineering-harness/`**, e as regras que tarefas e agentes seguem ao migrar uma aplicação passaram a ficar em **`doc/contratos/`**. As pastas anteriores foram retiradas; seu conteúdo permanece no histórico do Git.

| Artefato anterior | Destino |
| --- | --- |
| `doc/estrategia/estrategia-harness_.md` e versão `_mmd` | Documento 1: origem, fundamentos, horizontes, SDLC e modernização. Imagens em `imagens/`. |
| `doc/estrategia/conciliacao-evolucao-harness.md` | Documento 3 e [anexo A](#anexo-a). |
| `doc/arquitetura/arquitetura-harness.md` | Documentos 1 e 2; estudo Java na seção 2.9. |
| `doc/arquitetura/cheat-sheet-run-tasks.*` | `doc/guias/cheat-sheet-run-tasks.*`. |
| `doc/especificacoes/planejamento-copilot.md` | `doc/contratos/fluxo-migracao.md`. |
| `doc/especificacoes/planejamento-sprints.md` e `doc/features/planejamento-macro-sprints.md` | `doc/contratos/planejamento-sprints.md`, com as regras de cronograma da feature. |
| `doc/especificacoes/consultas-issues.md` | `doc/contratos/consultas-issues.md`. |
| `doc/features/organizacao-simplificada-por-projeto.md` | Regra executável na ADR-0009; desenho no documento 2, seção 9. |
| `doc/features/conversao-descartavel-dos-registros.md` | `tools/transicao/README.md`, junto do utilitário descartável. |
| `doc/features/evolucao-harness-dominios-capacidades-priorizacao.md` | [Anexo A](#anexo-a). |
| `doc/features/engineering-harness-vscode.md` | Incremento C e seção 2.6: extensão própria é evolução posterior de experiência. |
| `doc/features/planejamento-copilot.md` | Descartado: já era histórico. |
| ADR-0008 | Mantida como registro histórico, com nota de refinamento por este conjunto. |
| `tasks/plan.md` e `tasks/todo.md` | Único acompanhamento da implementação; este conjunto não mantém lista de status. |

## 9. Riscos que condicionam a execução

**Binários sem assinatura e política corporativa.** O Serena não integrou por falta de assinatura do executável Windows. Cada nova ferramenta precisa de distribuição aceita pela política de execução; não contornar bloqueios para viabilizar um piloto.

**Controle fora do harness.** Processo ou agente com os mesmos privilégios pode agir fora dos adaptadores. O desenho aplica regras onde controla a execução, mas não promete isolamento do sistema operacional. Sem homologação do cliente, manter entrega assistida. [O10](#fonte-o10)

**Capacidade externa com efeitos não declarados.** Validar JSON não garante comportamento do código. Aceitar somente implementações confiáveis, com instalação aprovada e ensaio de efeitos, falhas e atualização.

**Concorrência e publicação no Windows.** Portabilidade da linguagem não elimina semântica de arquivos abertos, shims e subprocessos. A prova Windows faz parte do núcleo mínimo, não fica adiada para o fim.

**Simplicidade degradada pela extensão.** Cada novo componente deve reduzir uma duplicação ou resolver uma lacuna demonstrada. Um novo perfil não deve gerar novas raízes históricas, banco de estado ou cópias de relatórios.

**Perda intencional de detalhamento antigo.** A política sem histórico impede replay completo depois da substituição de evidências externas. Não apresentar o produto como repositório de auditoria histórica ou de retenção regulatória.

**Dependências de ambiente.** Serviços corporativos, rede, autenticação e versões continuam requisitos de cada capacidade. “Local” não significa “sem dependência externa” nem “sem autorização corporativa”.

## 10. Catálogo único de fontes

As referências externas foram consultadas em 16/10/2026 e revisadas em 17/10/2026; O13 foi reconferida em 19/10/2026 para o piloto Codex. Documentação oficial comprova características das ferramentas, não a integração pronta no harness. Arquitetura e decisões do produto são propostas fundamentadas nessas características. R1, R2, R3, R5, R7 e R8 preservam versões históricas em `5dd8fb3`; R0 identifica a baseline examinada, R4 aponta para o build local e R6 para o acompanhamento corrente.

### Fontes do repositório e decisões adotadas

<a id="fonte-r0"></a>
**R0 — Baseline examinada em 19/10/2026.** `main` em `6566bb81d6f10914ad072f4dfec90cb3809b0cee`, merge da PR #35. Inclui a simplificação da PR #31 (`5c8d582`), a consolidação documental, o estado JBoss corrente da PR #34 e a orientação Claude Code da PR #35. A revisão atual altera documentação nessa base; não declara novos ensaios de runtime ou aceite humano.

<a id="fonte-r1"></a>
**R1 — Estratégia anterior do produto.** [Visão estratégica e tática](https://github.com/edoardo-bianco/jboss-mta-harness/blob/5dd8fb385240060f3207b9d3958f9238de19f30e/doc/estrategia/estrategia-harness_.md). Direção por núcleo, perfis, engines, IDEs, SDLC e modernização.

<a id="fonte-r2"></a>
**R2 — Arquitetura anterior.** [Arquitetura do Engineering Harness](https://github.com/edoardo-bianco/jboss-mta-harness/blob/5dd8fb385240060f3207b9d3958f9238de19f30e/doc/arquitetura/arquitetura-harness.md). Base operacional e proposta de núcleo/perfis. Suas exigências de retenção precisam ser conciliadas com S1.

<a id="fonte-r3"></a>
**R3 — Apresentação da base.** [README](https://github.com/edoardo-bianco/jboss-mta-harness/blob/5dd8fb385240060f3207b9d3958f9238de19f30e/README.md). Escopo JBoss, ferramentas e limites das evoluções descritas.

<a id="fonte-r4"></a>
**R4 — Implementação de build.** [HarnessBuild.psm1](../../scripts/HarnessBuild.psm1). Verificações de Java/Maven, fases, logs e publicação da última tentativa em `atual/build/`. A versão de `5dd8fb3` ainda criava pastas por execução.

<a id="fonte-r5"></a>
**R5 — Amostra de implementação MCP.** [Servidor de consultas](https://github.com/edoardo-bianco/jboss-mta-harness/blob/5dd8fb385240060f3207b9d3958f9238de19f30e/mcp/issues/server.mjs). Registro de ferramentas, ponte de consulta, cancelamento e transporte `stdio`.

<a id="fonte-r6"></a>
**R6 — Acompanhamento corrente de entregas.** [tasks/todo.md](../../tasks/todo.md). Distingue integração, documentação e pendências de ensaio/homologação. Resultados anteriores continuam identificados por entrega; não são convertidos em testes executados nesta revisão.

<a id="fonte-r7"></a>
**R7 — Catálogo de capacidades.** [Domínios, capacidades e priorização](https://github.com/edoardo-bianco/jboss-mta-harness/blob/5dd8fb385240060f3207b9d3958f9238de19f30e/doc/features/evolucao-harness-dominios-capacidades-priorizacao.md). IDs e recortes HAR/SRC/OBJ/DEP/JBS/CHG; não comprova entrega de todas as capacidades.

<a id="fonte-r8"></a>
**R8 — Decisão arquitetural em proposta.** [ADR-0008](https://github.com/edoardo-bianco/jboss-mta-harness/blob/5dd8fb385240060f3207b9d3958f9238de19f30e/doc/adr/0008-nucleo-perfis-e-plataforma-do-harness.md). Documento de 09/10/2026, explicitamente proposto e não implementado por aquela entrega. Esta consolidação o refina.

<a id="fonte-s1"></a>
**S1 — Organização simplificada por projeto.** Especificação de 10/10/2026, implementada na `main` e normatizada pela [ADR-0009](../adr/0009-estado-corrente-por-projeto.md). Texto original: [organizacao-simplificada-por-projeto.md em `5c8d582`](https://github.com/edoardo-bianco/jboss-mta-harness/blob/5c8d58265d82134def2ce6cac5c17ca2d80e1899/doc/features/organizacao-simplificada-por-projeto.md). Define identidade por POM, `atual`, último `reconciliado`, MTA na origem, fichas essenciais, compartilhamento por cópia e recuperação transitória.

<a id="fonte-s2"></a>
**S2 — Conversor descartável.** [tools/transicao/README.md](../../tools/transicao/README.md), especificação de 10/10/2026 mantida junto do utilitário. Define transição separada, sem dependência permanente no núcleo e com aplicação/limpeza distintas.

### Documentação oficial e fontes primárias

<a id="fonte-o1"></a>
**O1 — Ports and Adapters.** [Alistair Cockburn — Hexagonal Architecture](https://alistair.cockburn.us/hexagonal-architecture). Fonte primária do padrão; não prescreve o número de módulos deste produto.

<a id="fonte-o2"></a>
**O2 — Harness engineering.** [Birgitta Böckeler — Harness engineering for coding agent users](https://martinfowler.com/articles/harness-engineering.html). Fonte primária sobre feedforward, feedback e direção humana; não é uma norma ou certificação de ferramenta.

<a id="fonte-o3"></a>
**O3 — Ciclo de versões Node.** [Node.js — Releases](https://nodejs.org/en/about/previous-releases). Base para a escolha da linha LTS; versões efetivas devem ser fixadas por release homologada.

<a id="fonte-o4"></a>
**O4 — TypeScript no runtime Node.** [Node.js 24 — Modules: TypeScript](https://nodejs.org/docs/latest-v24.x/api/typescript.html). Limites da execução/remoção de tipos, distintos da checagem estática.

<a id="fonte-o5"></a>
**O5 — Execução de processos.** [Node.js 24 — Child process](https://nodejs.org/docs/latest-v24.x/api/child_process.html). APIs de subprocesso, ambiente, sinais e particularidades de `.cmd`/`.bat`.

<a id="fonte-o6"></a>
**O6 — Contratos interoperáveis.** [JSON Schema — Draft 2020-12](https://json-schema.org/draft/2020-12). Linguagem de esquemas, não mecanismo de autorização.

<a id="fonte-o7"></a>
**O7 — Validação JSON.** [Ajv — JSON Schema](https://ajv.js.org/json-schema.html). Suporte aos drafts e escolha da implementação para 2020-12.

<a id="fonte-o8"></a>
**O8 — MCP local.** [MCP — Transporte stdio, revisão 2026-07-28](https://modelcontextprotocol.io/specification/2026-07-28/basic/transports/stdio). Comunicação com subprocesso do cliente e separação dos canais.

<a id="fonte-o9"></a>
**O9 — Ferramentas e controle humano.** [MCP — Tools](https://modelcontextprotocol.io/specification/2026-07-28/server/tools). Contratos de ferramentas e orientações para manter controle humano.

<a id="fonte-o10"></a>
**O10 — Fronteira de confiança local.** [MCP — Local Server Security](https://modelcontextprotocol.io/docs/2026-07-28/tutorials/security/local-server-security). Riscos de execução local e domínio de confiança compartilhado.

<a id="fonte-o11"></a>
**O11 — Integração VS Code.** [Visual Studio Code — Tasks](https://code.visualstudio.com/docs/debugtest/tasks). Acionamento de ferramentas e processos pela IDE.

<a id="fonte-o12"></a>
**O12 — Identidade e escopo Maven.** [Apache Maven — POM Reference](https://maven.apache.org/pom.html). Coordenadas, herança e módulos; a convenção de diretórios do harness é decisão própria.

<a id="fonte-o13"></a>
**O13 — Codex programático.** [OpenAI — Non-interactive mode](https://learn.chatgpt.com/docs/non-interactive-mode), reconferida em 19/10/2026. `codex exec`, eventos JSONL por `--json` e resposta final estruturada por `--output-schema`; compatibilidade local e políticas dependem de teste.

<a id="fonte-o14"></a>
**O14 — Copilot programático.** [GitHub — Copilot CLI programmatic reference](https://docs.github.com/en/copilot/reference/copilot-cli-reference/cli-programmatic-reference). Interface e parâmetros do modo programático, não equivalência com a extensão da IDE.

<a id="fonte-o15"></a>
**O15 — Requisitos Copilot CLI.** [GitHub — Installing GitHub Copilot CLI](https://docs.github.com/copilot/how-tos/set-up/install-copilot-cli). Inclui requisito PowerShell 6+ no Windows e condições de acesso.

<a id="fonte-o16"></a>
**O16 — Operações de arquivos.** [Node.js — File system](https://nodejs.org/api/fs.html). Primitivas de arquivo; a recuperação de publicação de vários arquivos precisa de protocolo próprio.

<a id="fonte-o17"></a>
**O17 — Distribuição CLI.** [npm — package.json / bin](https://docs.npmjs.com/cli/v11/configuring-npm/package-json/#bin). Declaração de comandos do pacote.

<a id="fonte-o18"></a>
**O18 — Integração IntelliJ.** [JetBrains — External tools](https://www.jetbrains.com/help/idea/configuring-third-party-tools.html). Ferramentas externas locais e macros da IDE.

<a id="fonte-o19"></a>
**O19 — SDKs MCP.** [Model Context Protocol — SDKs](https://modelcontextprotocol.io/docs/2026-07-28/sdk). Implementações oficiais; versão escolhida deve ser validada com o cliente.

<a id="fonte-o20"></a>
**O20 — Instalação a partir de lockfile.** [npm — npm ci](https://docs.npmjs.com/cli/v11/commands/npm-ci/). Comportamento de instalação e verificação de consistência das dependências.

<a id="fonte-o21"></a>
**O21 — Testes Node.** [Node.js 24 — Test runner](https://nodejs.org/docs/latest-v24.x/api/test.html). Infraestrutura de testes proposta para contratos e módulos extraídos.

<a id="fonte-o22"></a>
**O22 — Checagem TypeScript.** [TypeScript — strict](https://www.typescriptlang.org/tsconfig/strict.html). Família de verificações estáticas estritas.

<a id="fonte-o23"></a>
**O23 — Futuro perfil Quarkus.** [Quarkus — CLI tooling](https://quarkus.io/guides/cli-tooling/) e [testes](https://quarkus.io/guides/getting-started-testing/). Extensões, build, modo de desenvolvimento e `@QuarkusIntegrationTest`; não comprova integração entregue no harness.

<a id="fonte-o24"></a>
**O24 — Claude Code programático.** [Claude Code — Run Claude Code programmatically](https://code.claude.com/docs/en/headless). `claude -p`, `--output-format json`, `--json-schema`, `--allowedTools`, modos de permissão e `--bare`.

<a id="fonte-o25"></a>
**O25 — Inteligência de código no Claude Code.** [Claude Code — Code intelligence plugins](https://code.claude.com/docs/en/plugins/code-intelligence). Plugin oficial `jdtls-lsp`; servidor instalado à parte; somente sessões de terminal.

<a id="fonte-o26"></a>
**O26 — Instalação do Claude Code.** [Claude Code — Advanced setup](https://code.claude.com/docs/en/setup). Windows 10 1809+, PowerShell ou CMD nativos, Git for Windows opcional e binário Windows assinado por "Anthropic, PBC".

<a id="fonte-o27"></a>
**O27 — GitHub Copilot app modernization.** [Microsoft Learn — Java upgrade overview](https://learn.microsoft.com/en-us/java/upgrade/overview), [quickstart](https://learn.microsoft.com/java/upgrade/quickstart-upgrade) e [anúncio de disponibilidade geral](https://github.blog/changelog/2025-09-22-github-copilot-app-modernization-is-now-generally-available-for-java-and-net). Avaliação, plano revisável, OpenRewrite e correção por agente; destinos Java 8, 11, 17, 21 e 25. A documentação Microsoft ainda rotula partes como preview.

<a id="fonte-o28"></a>
**O28 — Origem da reflexão estratégica.** [Luca Mezzalira — What's Happening in Software Architecture, O'Reilly, 22/09/2026](https://www.oreilly.com/videos/whats-happening-in/0642572416683/). Velocidade, SDLC, programas que acionam LLMs e feedforward/feedback; figuras 1–4 do documento 1.

<a id="fonte-o29"></a>
**O29 — Sensores e feedback.** [Birgitta Böckeler e Chris Ford — Harness engineering: agent feedback and AI coding sensors, Thoughtworks](https://www.thoughtworks.com/en-br/insights/blog/generative-ai/harness-engineering-agent-feedback-exploring-ai-coding-sensors). Devolução de resultados ao agente.

<a id="fonte-o30"></a>
**O30 — Desenvolvimento seguro.** [NIST SP 800-218 — SSDF](https://csrc.nist.gov/pubs/sp/800/218/final). Referência para revisar controles; não é certificação do harness.

<a id="fonte-o31"></a>
**O31 — AWS Transform custom.** [Workflows](https://docs.aws.amazon.com/transform/latest/userguide/custom-workflows.html), [instalação](https://docs.aws.amazon.com/transform/latest/userguide/custom-get-started.html) e [catálogo](https://docs.aws.amazon.com/transform/latest/userguide/transform-aws-customs.html). Requisitos, commits de checkpoint e transformações prontas.

<a id="fonte-o32"></a>
**O32 — Eclipse JDT Language Server.** [Projeto oficial](https://github.com/eclipse-jdtls/eclipse.jdt.ls), EPL-2.0. Servidor LSP executável fora da IDE, com suporte Maven/Gradle e runtime Java 21+.

<a id="fonte-o33"></a>
**O33 — Atualização Quarkus.** [Quarkus — Update Quarkus](https://quarkus.io/guides/update-quarkus/). Automação OpenRewrite experimental e limitada; revisão de guias, diffs, build e testes.

<a id="fonte-o34"></a>
**O34 — DDD pragmático.** [Vaughn Vernon — How To Do DDD](https://www.informit.com/articles/article.aspx?p=1944876&seqNum=3). Linguagem ubíqua construída com quem conhece o trabalho.

<a id="fonte-o35"></a>
**O35 — Uso responsável de agentes.** [GitHub — Responsible use of Copilot agents](https://docs.github.com/en/copilot/responsible-use/agents). Escopo claro, revisão e limites de atuação.

<a id="auditoria"></a>
## 11. Auditoria final: clareza, viabilidade e consistência

### 11.1. Método, alcance e independência

A revisão foi feita em segunda passagem, depois da redação, usando critérios de clareza, consistência entre documentos, viabilidade técnica, segurança e fidelidade à simplificação. Houve também verificações automatizadas dos exemplos e das referências internas.

**Limite de independência:** a revisão foi realizada pelo mesmo assistente, não por outro revisor humano ou modelo independente. Os critérios foram separados da redação, mas isso não constitui independência de autoria. A conferência de 19/10/2026 leu código/contratos e validou documentos; não executou builds, servidores, fluxos de migração ou testes corporativos. Este parecer avalia a proposta documental; não certifica implementação, segurança operacional ou homologação.

### 11.2. Achados e tratamento

| Achado | Risco identificado | Tratamento na consolidação | Situação residual |
| --- | --- | --- | --- |
| A01 — Baseline local não acessível | Declarar a simplificação como código verificado ou repetir trabalho já realizado. | Simplificação conferida em 17/10; baseline atualizada para `6566bb8` em 19/10 (seção 4). | Contratos mínimos e backups do workspace no incremento A; ensaios/aceites JBoss em `tasks/`. |
| A02 — Contradição sobre histórico | Reintroduzir snapshots, IDs de execução, importadores ou uma réplica de `atual` com outro nome. | Precedência de S1/S2; destinos correntes reais, último resultado de reconciliação, MTA na origem e conversor descartável. | Testes de segunda publicação e ausência de dependências legadas são necessários. |
| A03 — Versão do produto confundida com execução | A extensibilidade recriar histórico operacional como requisito de rastreabilidade. | Versões pertencem a contratos, perfis, provedores e ferramentas; metadados das operações permanecem apenas no estado corrente. | Perda de replay histórico é uma escolha explícita, não uma capacidade omitida por acidente. |
| A04 — Autorização aparente | Tratar `approved: true`, anotações MCP ou edição por agente como decisão humana confiável. | Decisão canônica do perfil, validação do escopo e confirmação pela superfície humana; MCP inicial de leitura. | Não há isolamento contra um agente com os mesmos privilégios que atua fora do harness. |
| A05 — Processo externo confundido com sandbox | Presumir que contrato JSON impede comportamento não declarado de plugins e builds. | Provedores confiáveis, efeitos explícitos, entradas restritas e declaração do limite de proteção. | Homologação do provedor e das permissões continua necessária. |
| A06 — Compatibilidade Windows presumida | Planejar Copilot CLI para PowerShell 5.1 ou supor término de todos os processos ao cancelar. | Requisito oficial PowerShell 6+ destacado; entrega assistida/IDE mantida; cancelamento confirmado pelo provedor. | Versão instalada, políticas corporativas e subprocessos exigem ensaio Windows. |
| A07 — Publicação tratada como transação pronta | Liberar estado parcial ou manter backups permanentes como solução implícita. | Preparação validada, exclusão mútua local e recuperação transitória; nenhuma atomicidade de vários arquivos presumida. | Falhas, arquivos abertos e interrupção abrupta devem ser testados. |
| A08 — Generalização artificial de build | Esconder fases Maven em uma capacidade apresentada como universal para Java. | Exemplo padronizado como `maven.build`, reutilizável pelos perfis que utilizam Maven. Outro sistema de build exige equivalência demonstrada ou contrato distinto. | O esquema completo de resultado/envelope será implementado no primeiro incremento. |
| A09 — Fluxo recursivo ou bloqueado | Agente chamar MCP que reinicia o mesmo agente, ou esperar o humano mantendo lock. | Um coordenador por fluxo, tarefas delimitadas e liberação de lock durante espera. | Ensaiar interrupção, retomada e alteração concorrente do plano. |
| A10 — Documentação concorrente | Manter três definições do produto e duplicar regras, fontes e backlog. | Direção no documento 1; desenho no 2; decisões, critérios, fontes e auditoria no 3. Consolidação executada na seção 8. | Regras vigentes permanecem em ADR-0009/contratos; status das entregas em `tasks/`. |

Os achados marcados como tratados referem-se ao **desenho e à redação**. Nenhum deles é apresentado como defeito de runtime corrigido nesta entrega.

### 11.3. Resultado das verificações documentais

As verificações documentais foram atualizadas em 19/10/2026. O resumo datado e os totais ficam em [tasks/todo.md](../../tasks/todo.md#consistencia-documental-e-agentes-principais---19102026); não reutilizar as contagens da revisão de 16/10 como se descrevessem o conjunto atual.

| Verificação | Resultado e limite |
| --- | --- |
| Definição central | Preservada literalmente, em uma única ocorrência canônica no conjunto. |
| Links internos | Arquivos de destino, imagens e âncoras conferidos no conjunto corrente; resumo da coleta em `tasks/todo.md`. |
| Fontes externas | Catálogo recontado, distinguindo referências históricas GitHub de fontes oficiais/primárias. O13 reconferida para o piloto Codex; as demais consultas preservam as datas declaradas. A verificação local não certifica disponibilidade de todas as páginas externas. |
| Exemplos JSON | Cinco blocos analisados sintaticamente, sem erro. São exemplos de design, não um SDK executável. |
| Esquema de entrada do build | A revisão original registrou sete casos com JSON Schema Draft 2020-12. Em 19/10 foram conferidas a sintaxe e a preservação dos cinco exemplos em relação à baseline; a validação de esquema não foi repetida. |
| Markdown | Blocos de código balanceados e nenhuma marca de preenchimento pendente identificada. |
| Diagrama | Fluxo de alteração com IA opcional, GO antes da execução e aceite posterior; a ilustração anterior está identificada como histórica. |
| Repetição literal | A revisão inicial de 16/10 não encontrou parágrafos idênticos acima de 180 caracteres, desconsiderando código e tabelas. Esse resultado histórico não elimina sobreposição semântica intencional de invariantes. |

A validação original do esquema foi feita com a biblioteca Python `jsonschema` no ambiente de elaboração; essa biblioteca não está disponível no ambiente da revisão de 19/10. A prova original verifica o exemplo interoperável; **não prova** a futura implementação Ajv/TypeScript, a resistência do launcher a injeção, a autenticidade da autorização ou a execução correta de Maven.

### 11.4. Avaliação de clareza e viabilidade

**Clareza:** a definição central orienta o conjunto, e a matriz de situação separa existente, informado e proposto. Capacidade, provedor, perfil e tarefa possuem papéis distintos. “Local” não é usado como sinônimo de offline, e “determinístico” não significa ausência de efeitos ou de revisão humana.

**Viabilidade:** a proposta utiliza mecanismos documentados para CLI Node, processos externos, contratos JSON, tarefas de IDE e MCP local. Começa por uma fatia vertical verificável e conserva ferramentas existentes. Não depende de framework de agentes, serviço central ou conversão completa de PowerShell antes de produzir valor. A documentação dos fornecedores fundamenta os mecanismos, não comprova a compatibilidade de todas as combinações.

**Simplicidade:** a retenção permanece limitada ao estado corrente e à última reconciliação; índices são derivados; MTA não é duplicado; compartilhamento é cópia com reconciliação. O catálogo não vira marketplace e a tarefa não exige motor BPM. Capacidades futuras só justificam novas abstrações quando demonstram variação real.

**Ressalvas:** faltam os ensaios de contratos completos, escrita/recuperação, concorrência, processos Windows e cliente de IA selecionado. O perfil JBoss atende origem EAP 7.0 ou 7.1 pela mesma chave de instalação; não há migração funcional certificada aqui.

### 11.5. Parecer final

A proposta é **coerente como direção arquitetural e tecnicamente fundamentada para implementação incremental**. Com o armazenamento JBoss implementado, o próximo passo é concluir os contratos mínimos e os nomes legíveis dos backups do incremento A, mantendo seus ensaios/aceites no acompanhamento canônico. Depois, provar `maven.build` como capacidade externa pela CLI e pelas interfaces escolhidas, preservando estado corrente e autoridade humana.

O avanço para automação agêntica de escrita depende de evidência dos controles reais do cliente e do ambiente. Enquanto essa prova não existir, a entrega assistida e as operações determinísticas continuam sendo o caminho válido. A conclusão desta revisão documental não concede GO para alterações de aplicações, implantação ou homologação corporativa.

### 11.6. Revisão de 17/10/2026

Registro histórico da auditoria no repositório, com conferência do código da `main` `5c8d582` e de fontes oficiais. Mesmo limite de independência da seção 11.1. A revisão de 19/10 atualiza a baseline e a prioridade dos agentes sem atribuir essas decisões à revisão anterior.

| Achado | Tratamento |
| --- | --- |
| A11 — Baseline anterior à PR #31 | Situação real descrita na seção 4 e no documento 1, seção 3; R0, R4, S1 e S2 atualizados. |
| A12 — Build descrito com `RunId` | Corrigido: a `main` publica a última tentativa em `atual/build/`. |
| A13 — Estado JBoss fora do princípio de armazenamento | Layout-alvo no documento 2, seção 9.1; decisões de 17/10 (somente o último, deploy substitui, sem rollback); incremento A. |
| A14 — Duas fontes normativas para o estado | ADR-0009 e `doc/contratos/` são donos das regras executáveis; o documento 2 aponta para eles. |
| A15 — Clientes e engines incompletos | Proposta independente do agente; Claude Code e GitHub Copilot como referência; Copilot app modernization e AWS Transform como candidatos (seção 2.7). |
| A16 — Compreensão Java sem decisão registrada | Seção 2.9: JDT LS via plugin `jdtls-lsp` e via CLI; Serena condicionado a distribuição assinada. |
| A17 — Java 8 tratado como geral | Restrito ao perfil JBoss; Quarkus com Java 17+, incluindo 25. |
| A18 — Origem EAP divergente | Perfil JBoss atende 7.0 ou 7.1. |
| A19 — Fundamentos e catálogo fora do conjunto | Origem e fundamentos no documento 1, seção 2; catálogo no anexo A. |
| A20 — Perfis previstos reduzidos a um "Quarkus" genérico | Restaurados os perfis da arquitetura anterior: Desenvolvimento Quarkus (SDLC sem migração), Migração Quarkus e Cobertura de código transversal (documento 1, seção 6; incremento F). |

Fontes verificadas nesta revisão: O8 (revisão 2026-07-28 do transporte `stdio`), O13, O15 (PowerShell 6+), O24–O27.

### 11.7. Revisão de consistência de 19/10/2026

Os seis achados foram tratados no desenho: GO na seção humana do plano; bases explícitas para cada caminho; separação entre publicação do build legado e contrato do provedor; baseline `6566bb8` com entregas e pendências distintas; figura com IA opcional e GO/aceite separados; entregas e aceite dos contratos mínimos no incremento A. As subseções 2.8/2.9 foram ordenadas e a coleta documental foi atualizada.

Por decisão do desenvolvedor, Codex e GitHub Copilot passam a ser principais e Claude Code secundário, substituindo a prioridade registrada em 17/10. O piloto programático parte de Codex, e o plugin JDT LS do Claude Code torna-se uma avaliação opcional. Isso não altera as permissões dos helpers nem comprova homologação dos clientes. A tentativa de consultar `codex exec --help` nesta máquina foi bloqueada pela política de execução de scripts; O13 fundamenta a interface proposta, e o ensaio nativo permanece pendente.

<a id="anexo-a"></a>
## Anexo A — Catálogo de capacidades e priorização

Os IDs preservam o catálogo de 05/10/2026. Várias capacidades ampliam mecanismos existentes; a coluna de prioridade é decisão do responsável e nenhuma sugestão representa compromisso. Escala: **P1** próximo ciclo, **P2** ciclo posterior, **P3** evolução, **Adiar**.

| ID | Capacidade | Sugestão | Prioridade escolhida | Pré-requisitos principais |
| --- | --- | --- | --- | --- |
| HAR-01 | Ampliar catálogo/instruções existentes | P1, apenas lacunas | A definir | Revisar mecanismos existentes |
| HAR-02 | Estender executor e runtimes existentes | P1, apenas lacunas | A definir | HAR-01 |
| HAR-03 | Enriquecer evidências e validade | P1, apenas lacunas | A definir | HAR-02 |
| HAR-04 | Explicitar contratos e separar perfis | P1, contrato mínimo; extração posterior | A definir | HAR-01/03; preservar fluxo EAP |
| SRC-01 | Busca textual | P1 | A definir | HAR-02/03 |
| SRC-02 | Busca estrutural | P2 | A definir | HAR-02/03 |
| SRC-03 | Símbolos e referências Java | P2 | A definir | HAR-02/03; DEP-01 conforme projeto; piloto da seção 2.9 |
| SRC-04 | Relações arquiteturais | P3 | A definir | HAR-02/03; bytecode |
| SRC-05 | Fluxo de dados | P3 | A definir | HAR-02/03 |
| SRC-06 | Contexto por objetivo | P1, versão mínima | A definir | HAR-03; seleção de contexto |
| OBJ-01 | Ampliar ingestão de apontamentos | P1, aproveitar MTA existente | A definir | HAR-03; relatório real |
| OBJ-02 | Enriquecer investigação e lote existente | P1 | A definir | HAR-01/02/03; HAR-04 para entrada sem MTA |
| DEP-01 | Completar inventário Maven efetivo | P1 | A definir | HAR-02/03 |
| DEP-02 | Parecer de compatibilidade com alvo | P1, recorte piloto | A definir | DEP-01; documentação aplicável |
| DEP-03 | Convergência e vulnerabilidades | P2 | A definir | DEP-01 |
| JBS-01 | Inventário JBoss | P1 | A definir | HAR-02/03 |
| JBS-02 | Caminho e plano de migração | P1 | A definir | JBS-01; documentação aplicável |
| JBS-03 | Transformação de configuração | P2 | A definir | JBS-02 |
| JBS-04 | Assistência ao desenvolvedor | P1, versão mínima | A definir | JBS-01; JBS-02 para alterações |
| JBS-05 | Validação do destino | P1, fluxo piloto | A definir | JBS-02; configuração candidata |
| CHG-01 | Receitas OpenRewrite | P2 | A definir | OBJ-02; HAR-02/03 |
| CHG-02 | Correção contextual pelo agente | P1, reutilizar existente | A definir | OBJ-02; HAR-03 |
| CHG-03 | Ampliar validação e encerramento existentes | P1, apenas lacunas | A definir | Plano, mudança e HAR-02/03 |

**Como escolher o próximo incremento:** avaliar cobertura atual, lacuna, problema concreto que resolve agora, frequência de uso, risco que reduz, esforço incremental, pré-requisitos e facilidade de comprovar valor. Estimar esforço somente depois de verificar o repositório. Não é necessário concluir todas as sugestões P1: selecionar um fluxo vertical pequeno e implementar só as capacidades necessárias a ele.

| Piloto | Recorte | Capacidades | Evidência de valor |
| --- | --- | --- | --- |
| A — Dependência para o destino | Um módulo e uma dependência relevante para EAP 7.4. | DEP-01/02 e lacunas HAR. | POM efetivo e árvore rastreáveis; recomendação ou lacuna explícita com fonte oficial. |
| B — Configuração JBoss assistida | Um standalone e os recursos usados pelo módulo, começando por driver/datasource. | JBS-01/02/04/05; JBS-03 depois. | Inventário, matriz origem/destino e configuração candidata validada. |
| C — Contexto para uma issue | Um apontamento MTA ou Sonar já disponível. | SRC-01/06, OBJ-01/02 e lacunas HAR; SRC-03 se necessário. | Recorte suficiente para investigar/corrigir; cobertura e validações registradas. |
| D — Refatoração DDD delimitada | Um caso de uso com regras confirmadas, fora do lote de migração mínima. | HAR-04, OBJ-02, SRC-01/03/06 e CHG-02/03. | Hipótese de responsabilidades confirmada e comportamento verificado. |
| E — Investigação de segurança | Um achado Fortify real, com caminho e contexto disponíveis. | Adaptador OBJ-01; SRC-01/03 e SRC-05 quando trouxer valor. | Caminho investigado, correção justificada e revalidação no analisador original. |

**Sugestão de primeira escolha:** piloto A, por ampliar a comparação estática de POM existente e produzir decisão verificável sem exigir grafo de código; se a configuração do servidor for o bloqueio imediato, piloto B. **Critério para expandir:** o piloto demonstrou que as evidências permitem retomar o trabalho, identificar lacunas e verificar a correção.

O texto completo de cada ficha de capacidade permanece no histórico do Git: [catálogo em `5c8d582`](https://github.com/edoardo-bianco/jboss-mta-harness/blob/5c8d58265d82134def2ce6cac5c17ca2d80e1899/doc/features/evolucao-harness-dominios-capacidades-priorizacao.md).
