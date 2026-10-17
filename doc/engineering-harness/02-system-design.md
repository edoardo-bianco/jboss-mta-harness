# Engineering Harness — system design

**Documento 2 de 3 · Revisão de 17/10/2026 · Contratos e desenho propostos, não APIs já implementadas**

**Direção e baseline:** [Estratégia e arquitetura](01-estrategia-e-arquitetura.md) · **Tecnologia, implementação e fontes:** [Plano tático](03-plano-tatico-e-implementacao.md)

## 1. Escopo do desenho

Este documento especifica como realizar a [definição central do produto](01-estrategia-e-arquitetura.md#1-mensagem-central): composição local de capacidades, configuração das instalações, execução por CLI/IDE/MCP e participação opcional de coding agents.

Os nomes de comandos, arquivos novos, campos e interfaces apresentados como exemplos são contratos propostos. Não devem ser copiados sobre a configuração atual esperando compatibilidade automática. As estruturas já definidas pela simplificação dos dados são preservadas; somente os elementos necessários à evolução são acrescentados.

**Regras executáveis vigentes.** O que as tarefas e os agentes seguem hoje ao migrar uma aplicação está na [ADR-0009](../adr/0009-estado-corrente-por-projeto.md) e em [`doc/contratos/`](../contratos/): [fluxo de migração](../contratos/fluxo-migracao.md), [planejamento por sprints](../contratos/planejamento-sprints.md) e [consultas de issues](../contratos/consultas-issues.md). Este documento descreve o desenho e aponta para essas regras; quando um contrato proposto aqui for implementado, a regra executável correspondente é atualizada no contrato, não duplicada.

## 2. Topologia local e dependências

```text
Processo CLI/menu                    Processo MCP opcional
(iniciado pelo desenvolvedor)        (iniciado pelo cliente, por stdio)
          |                                      |
          +-------- API de casos de uso ----------+
                             |
          Perfil + catálogo + políticas + estado corrente
                             |
                       Executor comum
                  /            |             \
           Módulo TS     Provedor externo   Adaptador de agente
                         Node/Java/PS        assistido ou invocável
                             |
                Ferramentas instaladas na máquina
```

CLI e MCP podem ser processos distintos carregando os mesmos módulos. Compartilham o estado do projeto por serviços de arquivos e controle de escrita, não por um servidor residente. O MCP não executa subprocessos por conta própria: chama os mesmos casos de uso do runtime.

No primeiro produto, organizar código em módulos de um repositório e uma release coordenada. Uma capacidade externa deve poder ser desenvolvida e testada separadamente; isso não obriga a publicar todos os módulos em pacotes independentes.

| Módulo lógico | Responsabilidade | Dependência permitida |
| --- | --- | --- |
| `core/work` | Objetivo, escopo, decisões e continuidade corrente. | Tipos e regras do domínio. |
| `core/evidence` | Referências, limitações e resultado da reconciliação. | Tipos do domínio; não leitores MTA. |
| `application` | Configurar, preparar, executar, verificar e reconciliar. | Núcleo e portas públicas. |
| `contracts` | Esquemas e interfaces de capacidades, perfis e resultados. | Tipos independentes de IDE e fornecedor de IA. |
| `composition` | Resolver perfil, implementações e instalações aprovadas. | Contratos e registro confiável. |
| `adapters` | CLI, arquivos, processos, MCP, IDEs e clientes de IA. | Portas; formatos externos ficam nesta fronteira. |
| `profiles` / `providers` | Procedimentos e realizações tecnológicas. | Contratos públicos; sem acesso aos detalhes privados do núcleo. |

Não criar uma interface para cada função auxiliar. As portas iniciais cobrem resolução de capacidades/ambiente, leitura e publicação do estado, execução e interação com o humano/agente. Novas portas exigem uma variação concreta ou um limite de teste relevante. [O1](03-plano-tatico-e-implementacao.md#fonte-o1)

## 3. Composição: perfil, capacidade, provedor e tarefa

Uma **capacidade** define o resultado. O **provedor** realiza esse resultado. O **perfil** seleciona capacidades e políticas. A **tarefa** coordena passos e decisões. A configuração local associa essa composição a instalações reais.

Exemplo: `maven.build` é reutilizável. Um provedor Maven executa o build; o perfil JBoss resolve Java 8 e as verificações da migração; o perfil Quarkus resolve o JDK e a plataforma pertinentes. Trocar o provedor não altera a identidade pública da capacidade quando o contrato continua equivalente. O ID `maven.build` é tecnológico de propósito: as fases Maven não são apresentadas como contrato universal de build Java. Um futuro executor Gradle exige capacidade própria ou uma abstração comum cuja equivalência tenha sido demonstrada.

### 3.1. Resolução e disponibilidade

A resolução deve verificar, nesta ordem: manifesto conhecido, versão do contrato suportada, implementação instalada e aprovada, configuração válida, pré-condições presentes, compatibilidade com a tarefa e autorização necessária.

**Disponível não significa autorizado.** O menu pode listar uma capacidade indisponível com seu motivo. O agente recebe apenas o recorte pertinente ao trabalho e permitido naquela sessão. Uma capacidade declarada no perfil, mas sem provedor compatível, não é substituída silenciosamente.

Conflitos de versão ou de política são erros explicáveis. Configuração local pode restringir recursos e escolher entre implementações permitidas; não pode ampliar por si só as invariantes do núcleo. O agente não pode fornecer um manifesto ou um caminho de executável arbitrário no pedido de execução.

### 3.2. Perfil versionado

Exemplo mínimo de manifesto de perfil, separado dos caminhos da máquina:

```json
{
  "schemaVersion": "1.0",
  "id": "jboss-migracao",
  "version": "1.0.0",
  "capabilities": ["project.inspect", "context.prepare", "maven.build"],
  "tasks": ["migration.prepare-plan"],
  "policies": {
    "sourceMutation": "human-approval",
    "agentOptional": true,
    "operationalRetention": "current-and-last-reconciliation"
  }
}
```

O perfil completo acrescenta alvos, guias, procedimentos, critérios e requisitos dos provedores usados. A lista acima é ilustrativa e não corresponde ao inventário completo do perfil existente.

Não introduzir uma hierarquia aberta de herança entre perfis. Começar por composição explícita. Capacidades tecnológicas compartilhadas são referenciadas, não copiadas; combinações incompatíveis devem ser recusadas na resolução.

## 4. Configuração e instalações locais

Separar três responsabilidades:

| Camada | Conteúdo | Dono da alteração |
| --- | --- | --- |
| Produto/perfil versionado | Contratos, capacidades permitidas, políticas e referências. | Manutenção do harness. |
| Ambiente local | Caminhos das ferramentas, clientes, certificados e opções aprovadas. | Desenvolvedor, conforme política corporativa. |
| Projeto | Associação ao POM/fonte, perfil selecionado e origens dos diagnósticos. | Configuração do trabalho local. |

Reaproveitar `config/harness.local.json`, a configuração local já usada pelo harness. Não criar um segundo cadastro de instalações. Referências ao catálogo local evitam repetir os caminhos do Maven e dos JDKs em cada perfil.

**Precedência proposta:** valores permitidos pelo contrato → defaults do perfil → configuração local validada → parâmetros permitidos da tarefa. Restrições não são sobrescritas por essa precedência. Um alvo incompatível exige correção explícita, não mesclagem silenciosa.

Para os dados e configurações do workspace, preservar a regra da simplificação: caminhos relativos são resolvidos pela raiz do workspace que contém `.harness`, nunca pelo diretório corrente do terminal. Links Markdown são relativos ao documento que os contém. Caminhos de recursos internos de um pacote são relativos à raiz desse pacote e pertencem a outro namespace. Essa distinção precisa de funções e testes explícitos. [S1](03-plano-tatico-e-implementacao.md#fonte-s1)

### 4.1. Diagnóstico de ambiente

A operação de diagnóstico confere a existência das instalações configuradas e, com permissão, consulta versões. Deve mostrar runtime do harness, runtime de cada ferramenta e runtime da aplicação separadamente. O JDK usado pelo MTA, pelo scanner ou pelo JDT Language Server pode ser diferente do JDK do build.

| Runtime | Perfil JBoss | Perfil Quarkus |
| --- | --- | --- |
| Aplicação (build e execução) | Java 8, `javax.*`, EAP 7.0/7.1 de origem e EAP 7.4 de destino. | Java 17 ou superior, incluindo Java 25, conforme a versão Quarkus escolhida e o JDK homologado. |
| Ferramentas | MTA, Sonar e analisadores com seus próprios requisitos. | Quarkus CLI/Maven e analisadores com seus próprios requisitos. |
| Harness | PowerShell 5.1 hoje; Node LTS no núcleo proposto. | Igual. |

A descoberta é uma conveniência, não uma instalação: candidatos encontrados no `PATH` ou em locais permitidos são apresentados para confirmação. Nenhum download, atualização, alteração de variável global, certificado, política de execução ou configuração do projeto acontece sem operação específica autorizada.

Pacotes externos continuam sujeitos às restrições corporativas. Ser JavaScript não torna um pacote automaticamente aprovado nem contorna bloqueios de execução.

### 4.2. Identidade do projeto

No perfil Maven, ler exatamente `project.artifactId` do POM selecionado, respeitando o namespace XML. Não usar o primeiro `artifactId` do arquivo, pois pode pertencer ao `parent`. A identidade entregue ao núcleo não precisa torná-lo conhecedor do XML Maven. [S1](03-plano-tatico-e-implementacao.md#fonte-s1) [O12](03-plano-tatico-e-implementacao.md#fonte-o12)

Manter o nome exato da pasta. Colisões de `artifactId`, nomes inválidos para Windows e POM não resolvido produzem diagnóstico, não sufixos, aliases ou alteração silenciosa do POM. Um agregador representa seu escopo; um módulo só é cadastrado separadamente quando selecionado para gestão independente. Checkouts simultâneos do mesmo nome usam raízes de dados distintas.

A identidade de futuros projetos não Maven será resolvida por seu perfil. Não criar agora um projeto fictício ou um fallback por nome de pasta.

<a id="contrato-capacidade"></a>
## 5. Contrato público de capacidade

### 5.1. Informação obrigatória

| Grupo | Conteúdo do contrato |
| --- | --- |
| Identidade | ID funcional, versão do contrato, descrição, resultado e limites. |
| Entrada/saída | Esquemas públicos e regras semânticas adicionais. |
| Requisitos | Ferramentas, runtimes, configuração e condições de disponibilidade. |
| Efeitos | Leituras, escritas, execução de código, rede e alterações de runtime possíveis. |
| Controle | Duração limitada, cancelamento, possibilidade de repetição e restrições de concorrência. |
| Contexto | Projeto, perfil resolvido, escopo e referências necessárias. |
| Evidência | Origem, resultado observado, cobertura, limitações e artefatos. |

Contrato, pacote do provedor e ferramenta têm versões distintas. O ID de uma capacidade não é um identificador de execução. Alterações incompatíveis exigem nova versão do contrato e teste dos consumidores; dados correntes não são reinterpretados silenciosamente.

JSON Schema é o formato interoperável proposto. Tipos TypeScript ajudam a implementação, mas não validam automaticamente entradas recebidas por arquivos ou processos. [O4](03-plano-tatico-e-implementacao.md#fonte-o4) [O6](03-plano-tatico-e-implementacao.md#fonte-o6)

### 5.2. Exemplo de descrição

O esquema abaixo valida apenas os parâmetros específicos. Projeto, escopo, ambiente e autoridade são resolvidos e conferidos pelo executor comum.

```json
{
  "id": "maven.build",
  "contractVersion": "1.0.0",
  "description": "Executar a fase Maven permitida e informar seu resultado técnico.",
  "inputSchema": {
    "$schema": "https://json-schema.org/draft/2020-12/schema",
    "type": "object",
    "additionalProperties": false,
    "required": ["phase"],
    "properties": {
      "phase": {
        "type": "string",
        "enum": ["validate", "compile", "test", "package", "verify"]
      }
    }
  },
  "effects": ["read-project", "write-build-output", "execute-project-code"],
  "networkPolicy": "environment-policy",
  "toolRequirements": ["java", "maven"],
  "execution": {
    "timeoutRequired": true,
    "cancellation": "provider-confirmed",
    "retry": "explicit-only"
  },
  "limits": ["Sucesso do processo nao comprova aceite funcional."]
}
```

O exemplo descreve um recorte: a publicação efetiva da capacidade também exige esquema de saída, configuração de limites e verificações semânticas. Não classificar build como operação puramente de leitura. Um projeto pode executar plugins, testes e processos e utilizar rede. O executor limita o que consegue controlar; o manifesto declara efeitos, mas não prova que código de terceiros os respeitará.

### 5.3. Vinculação a uma implementação externa

A vinculação fica no registro confiável de provedores, não na entrada gerada pelo agente:

```json
{
  "capabilityId": "maven.build",
  "contractVersion": "1.0.0",
  "provider": {
    "id": "maven-process",
    "version": "1.0.0",
    "mode": "process-json",
    "runtimeRef": "node-harness",
    "entrypoint": "providers/maven/dist/provider.js"
  }
}
```

`entrypoint` é relativo à instalação aprovada desse provedor. A aplicação não escolhe livremente esse arquivo. O pacote pode estar fora do repositório; resolve-se sua raiz instalada e valida-se o caminho antes da execução.

Duas modalidades bastam inicialmente: módulo confiável no processo e processo externo. O primeiro facilita compartilhamento; o segundo permite linguagens e ciclos de vida distintos. **Processo filho não é sandbox:** normalmente conserva permissões do usuário que o iniciou.

### 5.4. Pedido e resultado

Exemplo de pedido público. Ele solicita uma ação; não concede autorização:

```json
{
  "schemaVersion": "1.0",
  "project": "minha-api",
  "profile": "jboss-migracao",
  "capability": "maven.build",
  "input": { "phase": "verify" }
}
```

O executor resolve os diretórios e o ambiente local, valida o escopo e só depois chama o provedor. Não confiar em campos como `approved: true` enviados por um cliente de IA.

Exemplo de resultado corrente de uma tentativa que falhou:

```json
{
  "schemaVersion": "1.0",
  "capability": "maven.build",
  "executionStatus": "failed",
  "exitCode": 1,
  "summary": "A fase verify falhou; consultar o log e os relatorios de teste.",
  "artifacts": [
    { "kind": "log", "path": "atual/build/console.log" }
  ],
  "verification": {
    "status": "failed",
    "scope": "Fase Maven solicitada; nao representa validacao funcional completa."
  },
  "limitations": [],
  "humanAcceptance": "not-evaluated"
}
```

Caminhos de artefatos do resultado publicado são relativos à pasta administrada do projeto. O provedor entrega arquivos na área transitória autorizada; o núcleo valida os destinos e publica no caminho final. O provedor não reescreve `migracao.md` nem altera a decisão humana. Schemas completos de envelope e resultado, além do esquema de entrada exemplificado, são entregas do primeiro incremento; estes exemplos não constituem uma biblioteca executável pronta.

O envelope comum distingue sucesso técnico, falha, cancelamento confirmado, resultado parcial, entrada necessária, indisponibilidade, conflito e espera por humano. Saída malformada, ausência de artefato obrigatório ou divergência entre código de saída e resultado tornam a execução inválida. Nenhum estado técnico concede aceite. Os nomes definitivos e sua tradução para contratos legados devem ser fixados no primeiro incremento, sem criar dois estados concorrentes para o mesmo fato.

## 6. Execução de processos e protocolo externo

Para o primeiro contrato `process-json`, uma invocação usa um processo e um pedido JSON UTF-8; o provedor retorna um único resultado JSON no `stdout` e encerra. Logs, inclusive a saída textual da ferramenta interna, são encaminhados ao `stderr` e aos artefatos definidos. O canal estruturado não pode conter banners ou mensagens de depuração. Esse é um contrato do harness, diferente do JSON-RPC do MCP.

O executor controla diretório, argumentos, ambiente permitido, entrada padrão, timeout, tamanho máximo de saída e encerramento. Valores de limite pertencem à configuração validada por capacidade, não a defaults ilimitados. Não montar uma linha de shell com texto produzido pelo modelo. Usar processo e argumentos estruturados quando o executável permitir. No Windows, `.cmd` e `.bat` exigem launcher específico e tratamento cuidadoso; a API Node documenta essa diferença. [O5](03-plano-tatico-e-implementacao.md#fonte-o5)

No piloto Maven, é aceitável conservar o wrapper PowerShell 5.1 aprovado para chamar `mvn.cmd`. Na `main` atual, `HarnessBuild.psm1` já publica a última tentativa em `atual/build/console.log` e a situação em `operacao.json`, sem `RunId` ou pasta por build; o adaptador Node pode chamá-lo durante a transição. [R4](03-plano-tatico-e-implementacao.md#fonte-r4)

Não alterar `process.env` globalmente para alternar JDKs entre operações concorrentes. Compor o ambiente de cada processo filho e preservar a configuração da máquina. Redigir logs com remoção de segredos e sem publicar todo o ambiente.

### 6.1. Cancelamento e execução longa

O retorno de uma solicitação de cancelamento não comprova encerramento. O adaptador deve confirmar a saída do processo e, quando aplicável, dos descendentes. Se isso não puder ser demonstrado na combinação Windows/ferramenta, informar resultado parcial e exigir conferência, em vez de declarar cancelamento completo.

A execução normal permanece em primeiro plano, com progresso e cancelamento. Não introduzir jobs residentes ou um agendador. Quando o cliente ou processo terminar abruptamente, a próxima consulta identifica a situação corrente como interrompida ou indeterminada; não repete automaticamente uma operação de escrita.

JBoss e modos de desenvolvimento podem ter processos deliberadamente duradouros. Essas capacidades precisam de contrato próprio de iniciar, consultar e parar, reutilizando a integração existente. Encerrar o processo CLI não deve ser confundido com parar o servidor da aplicação.

## 7. Tarefas determinísticas, assistidas e híbridas

Uma tarefa contém passos nomeados, entradas, capacidades necessárias, dependências, condições de parada e pontos humanos. Usar coordenação explícita em código ou definições simples. Não criar uma linguagem genérica de workflows antes de aparecer uma necessidade comprovada.

Exemplo de tarefa híbrida do perfil JBoss:

```text
Selecionar issue e objetivo
  -> resolver diagnostico e documentos correntes
  -> preparar contexto por referencia
  -> elaborar proposta: desenvolvedor ou agente selecionado
  -> revisar escopo e criterios
  -> obter GO humano aplicavel
  -> executar alteracao autorizada
  -> executar verificacoes do perfil
  -> apresentar evidencia, pendencias e recomendacao
  -> aceitar ou voltar a uma etapa permitida
```

A etapa de LLM pode interpretar ou propor; uma receita determinística pode alterar código; uma tarefa “sem IA” também pode produzir efeitos importantes. O tipo da tarefa não determina seu nível de permissão.

Manter condições de término explícitas: orçamento de tempo/chamadas quando disponíveis, ausência de progresso, falta de evidência, ferramenta indisponível, falha técnica ou mudança de escopo. Uma repetição não recebe autoridade maior. Não estimar tokens a partir de bytes nem inventar custo quando o cliente não o fornecer.

### 7.1. Um coordenador por fluxo

Quando o harness chama o agente, o harness coordena os passos externos e o agente recebe uma etapa delimitada. Quando o agente chama o MCP, o cliente coordena a interação, mas cada caso de uso do harness aplica suas próprias regras.

Evitar a recursão `agente -> MCP -> mesmo agente -> MCP`. No primeiro MCP, não expor uma ferramenta genérica de iniciar agentes ou executar qualquer tarefa composta. Expor consultas e capacidades delimitadas. Não manter lock de escrita enquanto se espera uma resposta humana ou uma sessão de IA; revalidar o estado antes da publicação posterior.

## 8. Contrato de contexto e feedback

O contexto contém objetivo, projeto, perfil/versão, escopo, restrições, referências, procedimento, critérios, lacunas e limites da coleta. O arquivo persistido pode ser um manifesto de referências. O conteúdo transitório enviado a um agente deve ser o mínimo necessário à pergunta; não persistir um extrato MTA para alimentar o modelo.

A capacidade declara o que examinou e o que não examinou. Uma consulta por texto não vira análise semântica; uma referência não resolvida não vira ausência de dependência; uma recomendação de versão não comprova suporte.

O feedback relaciona quatro elementos: **critério esperado, resultado observado, evidência e decisão pendente**. Build e testes respondem por seus recortes. Revisão humana confirma comportamento, impacto e aceite. Melhorias de prompt, perfil ou sensor são propostas no trabalho de evolução do produto; o runtime não altera suas regras automaticamente.

<a id="estado-local"></a>
## 9. Estado local, evidências e simplificação

Esta seção descreve a organização implementada na `main` pela ADR-0009, que continua sendo a regra executável. Não acrescenta um modelo de event sourcing, pastas por execução ou histórico de versões. [S1](03-plano-tatico-e-implementacao.md#fonte-s1)

**Princípio:** cada pasta nomeia o projeto ou o servidor e a função do conteúdo, e uma pessoa entende o que encontra sem abrir arquivos auxiliares. `RunId`, GUID, hash ou carimbo de data não aparecem em caminhos. Uma nova execução substitui o conteúdo corrente da mesma função.

### 9.1. Estrutura canônica

```text
.harness/
  indices/                             # derivados, reconstruiveis
  projetos/
    <artifactId>/
      projeto.json                     # associacoes e origens locais
      indice.md                        # navegacao derivada
      migracao.md                      # apenas no perfil JBoss
      atual/
        diagnosticos/                  # ultimos resultados locais utilizaveis
        build/                         # ultima tentativa, inclusive falha
        priorizacao/<categoria>/       # fichas essenciais do perfil JBoss
        planejamento/                  # plano.md, tarefas.md, contexto.json
        sprints/<cenario>/             # conjunto corrente por cenario funcional
        jboss/<servidor>/              # ultimo-deploy.json (sem copia do WAR)
        operacao.json                  # ultima situacao por operacao, sem lista
      reconciliado/                    # ultimo resultado e pendencias, nao replica
      evidencias/                      # anexos humanos pertinentes
      recebido/                        # entrada temporaria para reconciliacao
      temporarios/                     # preparo e recuperacao transitórios
  servidores/
    <servidor>/                        # eap71 (EAP 7.0/7.1), eap74
      ultima-operacao.json             # resultado da ultima operacao de servidor
      ultimo-start/                    # logs do ultimo start, renovados por novo start
```

**Implementado em 17/10/2026.** Antes, o estado JBoss ficava em `.harness/jboss/<eap>__<hash>/operations|releases/<GUID>/`, fora do projeto e com uma pasta por execução; essa área não é mais lida nem escrita. No layout atual: o que é do servidor (iniciar, parar, consultar, criar usuário) fica em `servidores/<servidor>/`, porque vários projetos podem usar a mesma instalação; o que é da aplicação (deploy) fica no projeto.

**Decisões do desenvolvedor (17/10/2026):**

- **Somente o último.** Cada área JBoss guarda apenas a última operação e o último deploy; uma nova execução substitui o conteúdo anterior. Não há histórico de releases.
- **Deploy substitui o WAR do JBoss.** O deploy sempre envia o novo WAR com o mesmo nome estável e substitui o que estiver implantado (`--force`), inclusive quando o deployment atual não foi implantado pelo harness ou foi alterado externamente. É uma escolha explícita de simplicidade: o harness não protege contra sobrescrever um WAR implantado por fora. O resultado continua conferindo status e conteúdo do deployment depois do envio.
- **Sem rollback gerenciado.** A Run Task `Aplicacao: rollback no JBoss` é retirada. Reverter é fazer deploy de um WAR anterior escolhido pelo desenvolvedor (outro build ou caminho manual). Banco, configuração do servidor e efeitos externos nunca foram revertidos pelo harness.

Criar somente as áreas usadas. `atual` e `reconciliado` são destinos reais, não aliases para versões escondidas. As áreas de priorização, migração e MTA são realizações do perfil JBoss; não se tornam obrigatórias em todos os perfis.

Não exigir `RunId`, `RequestId`, GUID ou hash para localizar e retomar o projeto. IDs funcionais de issues e capacidades continuam válidos. Identificadores voláteis de uma chamada de protocolo podem existir em memória, sem gerar hierarquia de armazenamento ou cadeia de navegação.

### 9.2. Fontes de verdade

| Informação | Fonte canônica |
| --- | --- |
| Nome Maven | POM selecionado. |
| Associação local e origem de diagnóstico | `projeto.json`, interpretado pelo perfil. |
| Detalhamento MTA | Relatório na origem configurada. |
| Resumo de uma issue | Ficha essencial do perfil. |
| Decisões da migração | Conteúdo humano de `migracao.md`. |
| Plano e passos | Arquivos correntes de planejamento. |
| Reconciliação | Último resultado e pendências em `reconciliado/`. |
| Navegação | Índices derivados; não autorizam nem substituem os documentos. |

Sem configuração MTA externa, usar `atual/diagnosticos/mta/`. Com origem externa configurada, não misturar fontes ou fazer fallback silencioso para a pasta interna. O harness não copia, move, espelha ou mantém cache persistente do MTA externo.

### 9.3. Leitura do MTA e continuidade

Um único resolvedor do perfil atende priorização, fichas, planejamento e reconciliação. Ele reconhece conjuntos completos dos formatos suportados, agrupa seus assets e seleciona candidatos dentro da origem configurada.

A regra existente usa data de geração válida e, na ausência, modificação do arquivo de entrada reconhecido, com fuso normalizado. Empates usam ordem ordinal do caminho relativo, informando a seleção. Um candidato recente incompleto ou incompatível é diagnosticado; eventual anterior utilizável é identificado como tal, nunca apresentado silenciosamente como análise nova. Ler os dados pertinentes uma vez por operação; regravação externa detectada requer nova leitura ou interrupção. [S1](03-plano-tatico-e-implementacao.md#fonte-s1)

As fichas contêm somente identificação funcional, resumo, localização, impacto e encaminhamento. Fichas e `migracao.md` apontam para o **MTA atual**. Atualizações normais regeneram links gerenciados e preservam texto humano. Se um detalhe desaparecer, conservar a ficha, indicar ausência e apontar para a entrada do relatório; não concluir que a issue foi resolvida.

Um novo diagnóstico não concede GO nem atualiza sozinho a reconciliação. É possível preparar proposta preliminar sem reconciliação anterior. A continuidade depende do conteúdo essencial, das decisões e do plano, não de preservar o relatório anterior.

### 9.4. Última tentativa e último diagnóstico utilizável

Para build, a consulta mostra a última tentativa, mesmo falha. Para diagnósticos, falha de geração não substitui um conjunto completo por arquivos parciais. A situação da operação registra a tentativa malsucedida e informa a idade/limitação do resultado ainda utilizável. Essa diferença é intencional; “último” não tem o mesmo significado para todos os artefatos.

### 9.5. Reconciliação e compartilhamento

Compartilhar significa copiar arquivos pelo mecanismo habitual. Se já existe trabalho local, receber em `recebido/` ou indicar uma pasta externa para a mesma operação de reconciliação. Não sobrescrever `atual` ou `migracao.md` por simples cópia.

Comparar decisões, escopo, situação e evidências relevantes. Material equivalente não gera duplicação; conflito exige resolução antes de atualizar os documentos afetados. Não escolher a versão do colega apenas pela data. Preservar as associações locais ao POM/MTA; cópia não transfere GO.

Depois da reconciliação, substituir apenas o resultado corrente e a última base reconciliada, regenerar índices e retirar de `recebido/` o material resolvido. Conflitos pendentes permanecem. Uma origem externa não é apagada. Não criar comando de importação, exportação, manifest de transferência ou cadeia `ImportedFrom` com outro nome.

### 9.6. Escrita consistente e recuperação

Serializar publicação por projeto com lock local de curta duração. Preparar arquivos em `temporarios/`, validar formatos e referências e conferir novamente que os documentos relevantes não mudaram. Uma aprovação não permanece válida depois de mudança material do plano ou do escopo.

A publicação de vários arquivos **não é presumida atômica**. O mecanismo deve manter informações de recuperação somente na área transitória, restaurar ou completar um conjunto consistente após falha e bloquear novas publicações até concluir essa recuperação. Remover o material transitório depois do sucesso; ele não vira revisão consultável. A API de arquivos oferece primitivas, mas o protocolo de consistência é responsabilidade do harness. [O16](03-plano-tatico-e-implementacao.md#fonte-o16)

Locks do harness não impedem edição por outro programa. Orientar o desenvolvedor a não editar os mesmos documentos durante a publicação e detectar alterações pertinentes antes do commit local. Não prometer transação distribuída ou isolamento contra processos externos que não cooperam.

Cenários de sprints multiprojeto mantêm um registro mestre em um projeto participante, com referências dos demais. Não criar projeto fictício, duplicar cenários por consumidor ou restabelecer cadeia de revisões. [S1](03-plano-tatico-e-implementacao.md#fonte-s1)

<a id="autoridade"></a>
## 10. Autoridade humana e fronteira de confiança

O controle tem três perguntas independentes: a capacidade está disponível? A operação é permitida nesse contexto? Existe a decisão humana necessária para os efeitos propostos?

O runtime verifica essas condições antes de chamar o provedor. Uma porta de decisão lê o registro canônico definido pelo perfil — `migracao.md` no piloto JBoss — sem criar uma segunda fonte de autorização ou impor esse documento a Quarkus e outros perfis. Selecionar perfil, instalar ferramenta, aprovar um prompt no cliente ou receber `approved=true` não substitui a autorização de uma alteração delimitada.

No primeiro fluxo híbrido, a confirmação é solicitada ao desenvolvedor pela interface local. Vincular a decisão ao projeto, perfil, conteúdo relevante do plano, escopo e efeitos apresentados, sem construir uma cadeia histórica de hashes. Comparações de conteúdo podem ocorrer em memória. Se esses elementos mudarem, ou se a continuidade de uma sessão de alteração não puder ser comprovada, solicitar nova decisão.

O MCP inicial não expõe uma operação para o agente conceder GO. Uma solicitação de escrita sem autorização verificável retorna necessidade de interação humana; não fica lendo confirmação no `stdin` reservado ao protocolo. A ampliação do MCP para mutação exige uma superfície de confirmação confiável e testes próprios. A recomendação de manter humanos no controle consta da especificação, mas não é automaticamente aplicada pelo protocolo. [O9](03-plano-tatico-e-implementacao.md#fonte-o9)

### 10.1. O que o harness não garante sozinho

Um agente ou plugin com as mesmas permissões do usuário pode acessar arquivos ou executar ferramentas fora dos adaptadores. Um manifesto, um processo filho ou um arquivo de decisão não constitui isolamento de segurança. A documentação de segurança local do MCP explicita a fronteira de confiança compartilhada entre cliente e servidor `stdio`. [O10](03-plano-tatico-e-implementacao.md#fonte-o10)

Consequentemente, a proteção prática depende também de componentes confiáveis, permissões nativas do coding agent e controles corporativos. Sem uma combinação homologada, manter a etapa assistida/manual e não anunciar execução autônoma confinada. Inspeção de diff detecta efeitos; não os impede retroativamente.

Não aceitar comandos livres, carregar plugins indicados por conteúdo do projeto, herdar segredos indiscriminadamente, exportar código por padrão ou modificar políticas do Windows. Normalizar caminhos, conferir raízes permitidas e tratar links simbólicos/junctions; registrar limitações de qualquer controle que não seja efetivamente implementado.

## 11. Integração com coding agents

O adaptador de agente declara modos efetivamente suportados: entrega assistida de contexto, sessão interativa, execução programática, retorno estruturado, cancelamento, controle de ferramentas e consulta de resultados. A detecção depende de cliente, versão, instalação, autenticação e política corporativa.

| Modo | Comportamento | Quando encerrar a etapa |
| --- | --- | --- |
| Entrega assistida | Preparar documentos/referências; desenvolvedor abre o cliente e envia o pedido. | Contexto preparado não é resposta produzida. |
| CLI programática | Chamar interface documentada, com limites e retorno validado. | Somente após obter e conferir o resultado. |
| Agente consumidor de MCP | Expor capacidades permitidas; cliente solicita operações. | Cada chamada respeita o contrato e a autoridade do harness. |

**Clientes de referência: Claude Code e GitHub Copilot.** A proposta é independente da tecnologia agêntica; os adaptadores registram o que cada cliente oferece de fato, sem tornar um deles requisito do núcleo. Codex permanece suportado pelos artefatos existentes.

| Cliente | O que está documentado | Observação para o harness |
| --- | --- | --- |
| Claude Code | Modo programático `claude -p`, com `--output-format json`, `--json-schema`, `--allowedTools` e modos de permissão; `--bare` para execução reproduzível sem carregar hooks, plugins e `CLAUDE.md` da máquina. Executa nativamente em PowerShell ou CMD no Windows, com binário assinado pela Anthropic; extensões para VS Code e JetBrains. [O24](03-plano-tatico-e-implementacao.md#fonte-o24) [O26](03-plano-tatico-e-implementacao.md#fonte-o26) | Candidato à primeira integração programática. Plugins oficiais de inteligência de código (LSP) dão navegação por símbolo e diagnósticos após edições. [O25](03-plano-tatico-e-implementacao.md#fonte-o25) |
| GitHub Copilot | Extensões de IDE com perfis e prompts; Copilot CLI com modo programático. [O14](03-plano-tatico-e-implementacao.md#fonte-o14) | O Copilot CLI exige PowerShell 6 ou superior no Windows; com a baseline corporativa em PowerShell 5.1, não é executor programático homologado. A extensão da IDE e a entrega assistida permanecem caminhos válidos. [O15](03-plano-tatico-e-implementacao.md#fonte-o15) |
| Codex | `codex exec` para uso não interativo. [O13](03-plano-tatico-e-implementacao.md#fonte-o13) | Mantido nos perfis e skills existentes. |

Documentação de modo programático estabelece possibilidade técnica, não equivalência operacional entre clientes ou com as extensões das IDEs. O adaptador testa a versão instalada e não escolhe flags permissivas para fazer o cenário passar; não alterar o ambiente para contornar restrições corporativas.

Escolher um cliente não escolhe automaticamente o modelo. Políticas de rede, custo e dados também precisam ser conhecidas. Logs e respostas são coletados apenas quando disponíveis; resultados incompletos não são preenchidos por suposição.

## 12. CLI, IDEs e MCP

### 12.1. CLI como entrada de referência

Comandos ilustrativos a implementar, não comandos já existentes:

```text
harness doctor --workspace D:/Trabalho
harness capabilities --project minha-api --profile jboss-migracao
harness run maven.build --project minha-api --phase verify
harness task migration.prepare-plan --project minha-api
harness reconcile --project minha-api --source D:/MaterialRecebido/minha-api
harness mcp --workspace D:/Trabalho
```

A configuração resolve o workspace quando omitido. Evitar repetir perguntas sobre projeto/perfil já conhecidos. A saída humana explica ação, efeito, resultado e próximo passo; uma opção estruturada utiliza o mesmo envelope. Entrada inválida, conflito, falha técnica e falta de autorização não retornam sucesso.

A distribuição pode declarar um `bin` npm, mas deve também permitir chamada direta por `node.exe` ao JavaScript compilado. Não exigir instalação global nem `npx` com download implícito. O mecanismo `bin` é documentado pelo npm; a política de distribuição é escolha deste produto. [O17](03-plano-tatico-e-implementacao.md#fonte-o17)

### 12.2. IDEs como adaptadores finos

No VS Code, começar com Run Tasks do tipo `process`. No IntelliJ, usar External Tools locais, configurando programa, argumentos e diretório de trabalho. As duas ferramentas documentam essas formas de acionamento. [O11](03-plano-tatico-e-implementacao.md#fonte-o11) [O18](03-plano-tatico-e-implementacao.md#fonte-o18)

Configuração conceitual comum: programa `node.exe` aprovado; primeiro argumento é o caminho do `dist/cli.js` instalado; os demais identificam operação e workspace. No IntelliJ, macros como `$ProjectFileDir$` pertencem ao adaptador da IDE, não ao núcleo. Validar caminhos com espaços e acentos na máquina real.

Não sobrescrever arquivos de configuração do usuário. Uma futura ação de configuração deve apresentar a diferença e atualizar somente entradas gerenciadas. Debug da aplicação e consultas semânticas da IDE continuam integrações próprias; rodar uma CLI no IntelliJ não disponibiliza automaticamente o JDT LS mantido pelo VS Code.

### 12.3. MCP opcional

A `main` já contém servidor MCP de consultas (SDK `@modelcontextprotocol/server` 2.3.1, Zod e ponte PowerShell, `node >= 20`), cujo contrato está em [consultas de issues](../contratos/consultas-issues.md). Preservar compatibilidade onde aplicável e substituir a ponte apenas na capacidade extraída. Não publicar uma nova API incompatível usando silenciosamente os mesmos nomes. A revisão 2026-07-28 do protocolo troca o handshake `initialize` por descoberta (`server/discover`); a compatibilidade entre SDK e clientes selecionados entra nos testes do incremento MCP. [R5](03-plano-tatico-e-implementacao.md#fonte-r5) [O8](03-plano-tatico-e-implementacao.md#fonte-o8)

Usar SDK oficial na fronteira e transporte `stdio`, com `stdout` exclusivamente para protocolo. A sessão é iniciada e encerrada pelo cliente; não há HTTP ou porta de rede obrigatórios. Protocolos e versões suportados devem ser negociados e testados com os clientes selecionados. [O8](03-plano-tatico-e-implementacao.md#fonte-o8) [O19](03-plano-tatico-e-implementacao.md#fonte-o19)

Inicialmente, expor consultas de catálogo, estado e evidências, respeitando os efeitos reais. Uma capacidade que gera arquivos, mesmo sem modificar fontes, não é anotada falsamente como somente leitura. Cada ferramenta pública tem esquema e finalidade; não oferecer `runShell(command)`.

## 13. Atualização, observabilidade mínima e prova do desenho

Registrar nas saídas correntes a versão efetiva do perfil/provedor/ferramenta, duração, resultado e limites úteis. Esses metadados apoiam diagnóstico e comparação do ensaio; não produzem um histórico por execução. Custos e tokens ausentes permanecem não disponíveis.

Atualizar o pacote instalado não altera dados, configurações ou decisões da aplicação automaticamente. Esquema incompatível preserva os dados e pede migração explícita. A conversão do layout legado permanece um utilitário separado, com prévia, aplicação, validação e limpeza distintas; o runtime novo não depende dele. [S2](03-plano-tatico-e-implementacao.md#fonte-s2)

A prova mínima é uma capacidade externa real, invocada pela CLI e pelas duas IDEs, com configuração inválida, sucesso, falha, cancelamento e segunda publicação nos mesmos destinos. Uma consulta da mesma base deve funcionar por MCP opcional. Uma tarefa híbrida deve preparar contexto, receber decisão humana e produzir feedback sem converter a opinião do agente em validação.

A [matriz de testes e o plano de implementação](03-plano-tatico-e-implementacao.md#verificacao) transformam esse desenho em critérios de aceite. Sem esses ensaios, o resultado permanece arquitetura proposta.
