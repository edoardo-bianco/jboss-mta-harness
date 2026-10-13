# Conversão descartável dos registros existentes

**Estado:** S20 implementada: prévia somente leitura em Windows PowerShell 5.1.
Aplicação/validação e limpeza permanecem em S21/S23.
**Revisão:** 13/10/2026. **Destino:** `doc/features/conversao-descartavel-dos-registros.md`.

**Prioridade:** parte da simplificação que precede modernização e novas
funcionalidades. Dependências, riscos e
verificações estão no [plano](../../tasks/plan.md#simplificacao-prioritaria-por-projeto---2026-10-10)
e no [checklist](../../tasks/todo.md#simplificacao-prioritaria-por-projeto---2026-10-10).

## 1. Responsabilidade

Converter os registros legados para o contrato de [organização simplificada por projeto](organizacao-simplificada-por-projeto.md). Esse contrato define identidade pelo `project.artifactId`, caminhos, estados e leitura de MTA; o conversor o utiliza, sem manter uma segunda versão dessas regras.

O utilitário será executado diretamente e poderá ser removido após a transição. O núcleo permanente não o importa, não o executa automaticamente e não depende de mapas de conversão. O script pode chamar os serviços permanentes de publicação e validação; a dependência existe apenas nessa direção.

Receber trabalho de um colega no layout corrente não é conversão: basta copiar os arquivos e usar a reconciliação comum, conforme a especificação principal. Este utilitário não substitui nem mantém as antigas funções de importação/exportação.

## 2. Interface

Script: [Converter-RegistrosProjeto.ps1](../../tools/transicao/Converter-RegistrosProjeto.ps1).

| Parâmetro | Finalidade |
| --- | --- |
| `-Workspace` | Raiz que contém os dados do harness. |
| `-Pom` | Caminho do POM que define o projeto de destino. O `artifactId` é lido desse POM; não existe parâmetro de nome alternativo. |
| `-Modo Previa` | Padrão: inventariar e mostrar o resultado proposto, sem escrever dados ou remover origens. |
| `-SourceLegado` | Associação explícita quando o Source dos registros difere do diretório do POM local, por exemplo após relocalização. Não infere associação por apelido ou artifactId. |
| `-Registro` | Caminho do registro escolhido quando há mais de um para o Source. |
| `-Contexto` | Caminho do contexto escolhido quando os vínculos não determinam um plano único. Não corrige cadeia inconsistente. |
| `-Formato Texto\|Json` | Saída no terminal; Texto é o padrão. Nenhum relatório ou mapa é gravado pelo utilitário. |
| `-Modo Aplicar` | Previsto em S21: preparar, validar e publicar a conversão. Ainda recusado. |
| `-Modo Validar` | Previsto em S21: verificar conteúdo, referências e independência do legado. Ainda recusado. |
| `-Modo Limpar` | Previsto em S23: descartar somente resíduos selecionados após validação. Ainda recusado. |

Os modos são operações do mesmo utilitário descartável. Somente `Previa` está entregue:

```powershell
powershell.exe -NoProfile -File tools/transicao/Converter-RegistrosProjeto.ps1 -Workspace C:\harness -Pom C:\fontes\aplicacao\pom.xml
```

A prévia mostra associação, decisões por issue, candidatos, destinos propostos,
referências e pendências. Registro e plano são selecionados por Source e vínculos
explícitos; `Previous` segue até a ponta única. Datas de arquivos não participam
da escolha. Um vínculo atual quebrado, ciclo ou documento de outra solicitação
fica pendente; não é substituído por um plano histórico.

Declarações `CONCLUIDA` no registro e nos snapshots embutidos aparecem como
`DECLARADA_A_CONFERIR`. O legado não fornece resultado estruturado que comprove
a comparação executada: recibo, hash e declaração isolada não elegem uma base
reconciliada. A prévia mantém `PRELIMINAR` e expõe as fontes para conferência humana.

Priorização, sprints e diagnósticos aparecem como candidatos, com referências e
destinos conhecidos. Consolidar cobertura, escolher o conjunto de diagnóstico
aplicável e definir mestre/nome funcional de sprint permanecem pendências
explícitas para S21. A lista de descarte contém apenas arquivos candidatos e
não autoriza remoção. As regras de transformação e publicação abaixo continuam
sendo critérios de S21/S23.

O inventário lê as famílias legadas conhecidas sob `.harness`, exclui originais
de pacotes e projetos já identificados por `projeto.json`, e recusa links/junctions.
Publicação pendente no destino é recusada sem recuperação. Os testes usam
fixtures sintéticas e comparam caminhos, bytes e datas dos arquivos antes/depois;
nenhuma conversão ou limpeza de dados reais faz parte da entrega S20.

## 3. Seleção e transformação

A prévia associa os registros existentes ao POM selecionado e identifica o conjunto corrente e a última reconciliação comprovável. Mostra origens, destinos, decisões preservadas, referências reescritas, conflitos e escopo de descarte.

Usar os vínculos do legado para determinar qual plano estava em uso e qual base foi reconciliada. A data mais recente de um arquivo não comprova reconciliação, validade ou autorização. Conflitos de associação ou conteúdo precisam ser resolvidos antes da aplicação. Sem reconciliação demonstrável, publicar apenas o estado atual como preliminar.

| Conteúdo legado | Conversão |
| --- | --- |
| Nome livre ou chave técnica de projeto | Associar ao POM e ao destino pelo `artifactId`, sem criar alias persistente. |
| Registro de migração e evidências humanas | Preservar conteúdo manual; ajustar somente referências operacionais necessárias. |
| Planos, tarefas, contextos, priorização e dossiês | Consolidar o conjunto em uso nos destinos correntes, preservando cobertura das issues. |
| Última base reconciliada | Preservar o resultado e as pendências da conciliação; manter informações essenciais nas fichas, sem gerar outra base de issues ou extrato MTA. |
| Cenários de sprints | Preservar baseline, capacidade e dependências; realocar o registro mestre para um projeto Maven participante quando necessário. |
| MTA externo | Preservar a pasta de origem e transportar sua configuração. Leitura e seleção pertencem ao resolvedor permanente. |
| Diagnósticos locais administrados pelo harness | Levar somente o último conjunto utilizável aplicável ao novo contrato. |
| Cópias e extratos MTA gerados para priorização/fichas | Substituir por links ao relatório na origem e resumo essencial na ficha; retirar as dependências dos extratos e incluí-los no descarte autorizado. |
| Dados legados recebidos por importação/exportação | Consolidar o conteúdo necessário nos arquivos correntes, retirando dependências de pacotes, recibos e cadeias de transferência. |
| Índices gerados | Reconstruir a partir do resultado convertido. |

Reescrever links Markdown e campos estruturados segundo os formatos conhecidos, incluindo links das fichas e de `migracao.md` para o MTA atual na origem. Resolver cadeias antigas durante a conversão, consolidando o conteúdo necessário. Não fazer substituição global de strings nem apagar identificadores funcionais, texto humano ou referências Git úteis.

Nos documentos de detalhe convertidos, cada referência a diagnóstico, fonte,
POM, configuração ou evidência deve oferecer link direto ao arquivo correspondente.
Conferir destinos locais e sinalizar os indisponíveis; não perpetuar links ao
snapshot antigo nem criar arquivos redirecionadores para substituir recibos.

Não modificar binários ou recibos selados como se continuassem sendo os originais. Se houver transformação necessária, produzir a representação do contrato novo. Alterações de conteúdo ou escopo não herdam GO automaticamente.

O destino recebe somente os dados correntes previstos no contrato. Relatórios MTA externos, código-fonte e arquivos de outros projetos não são copiados, movidos ou excluídos pela conversão. Mapas e relatório de conferência são temporários e não participam do funcionamento do projeto convertido.

## 4. Aplicação, recuperação e descarte

1. Conferir POM, associação das origens, ausência de colisão e exclusividade de escrita no projeto.
2. Preparar o conjunto convertido em área temporária, preservando os originais.
3. Validar formatos, links, decisões, cobertura de issues e baseline dos cenários.
4. Publicar pelo mecanismo permanente e regenerar os índices.
5. Executar a validação com os controles legados inacessíveis, mantendo acessível a origem MTA externa configurada.
6. Apresentar o resultado e os resíduos elegíveis para descarte.

Falha anterior à publicação não altera os registros ativos. Falha durante a publicação usa a recuperação definida no contrato permanente. Reexecutar sobre destino equivalente não duplica dados; se houver trabalho novo no destino, apresentar o conflito e não sobrescrevê-lo.

`Aplicar` não apaga originais. `Limpar` revalida o destino e remove apenas o material legado explicitamente selecionado para descarte, mais os temporários de conferência e recuperação. Caminhos que abranjam fontes, origem MTA externa, dados novos ou registros de outros projetos não podem entrar nesse descarte. Não remover indiscriminadamente uma raiz compartilhada de registros.

A limpeza encerra a transição sem incorporar arquivo histórico ou backup ao projeto novo. O pacote do conversor pode então ser removido; não é necessário executá-lo novamente para reconhecer novos relatórios MTA.

## 5. Aceite específico da conversão

Os critérios permanentes estão na especificação principal. Para este utilitário, verificar adicionalmente:

- [ ] A prévia não altera arquivos; o destino é derivado do POM, incluindo os casos de agregador e módulo.
- [ ] Decisões humanas, cobertura e baseline são preservadas; reconciliação e autorização não são inventadas.
- [ ] Links e campos operacionais convertidos resolvem sem mapas, IDs de execução ou caminhos legados.
- [ ] Documentos de detalhe permitem abrir diretamente o MTA, os fontes locais e os anexos referenciados; referências indisponíveis são explícitas.
- [ ] O MTA externo permanece intacto; um relatório novo na mesma pasta é reconhecido pelo núcleo sem nova conversão.
- [ ] Priorização e fichas convertidas dispensam cópias ou extratos MTA; fichas e `migracao.md` apontam para o relatório na origem.
- [ ] Falha é recuperável; reexecução não duplica dados nem sobrescreve trabalho posterior.
- [ ] Aplicação e descarte são distintos; limpeza não alcança fontes, relatórios externos ou outros projetos.
- [ ] Com conversor removido e controles legados indisponíveis, o projeto opera conforme o contrato permanente, inclusive ao reconciliar arquivos copiados de um colega sem funções de importação/exportação.

O teste final é continuar o trabalho usando apenas o projeto convertido e suas origens configuradas. Qualquer dependência de mapa ou registro técnico antigo impede concluir a conversão.
