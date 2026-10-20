# Conversão descartável dos registros existentes

**Estado:** prévia, aplicação, validação e descarte implementados em Windows
PowerShell 5.1 e verificados em fixtures. Aceite humano integrado pendente.
**Revisão:** 20/10/2026. **Destino:** `tools/transicao/README.md`.

**Prioridade:** parte da simplificação que precede modernização e novas
funcionalidades. Dependências, riscos e
verificações estão no [plano](../../tasks/historico/plan-ate-2026-10-17.md#simplificacao-prioritaria-por-projeto---2026-10-10)
e no [checklist](../../tasks/historico/todo-ate-2026-10-17.md#simplificacao-prioritaria-por-projeto---2026-10-10).

## 1. Responsabilidade

Converter os registros legados para o contrato de [organização simplificada por projeto](../../doc/engineering-harness/02-system-design.md#estado-local). Esse contrato define identidade pelo `project.artifactId`, caminhos, estados e leitura de MTA; o conversor o utiliza, sem manter uma segunda versão dessas regras.

O utilitário será executado diretamente e poderá ser removido após a transição. O núcleo permanente não o importa, não o executa automaticamente e não depende de mapas de conversão. O script pode chamar os serviços permanentes de publicação e validação; a dependência existe apenas nessa direção.

Receber trabalho de um colega no layout corrente não é conversão: basta copiar os arquivos e usar a reconciliação comum, conforme a especificação principal. Este utilitário não substitui nem mantém as antigas funções de importação/exportação.

## 2. Interface

Script: [Converter-RegistrosProjeto.ps1](Converter-RegistrosProjeto.ps1).

| Parâmetro | Finalidade |
| --- | --- |
| `-Workspace` | Raiz que contém os dados do harness. |
| `-Pom` | Caminho do POM que define o projeto de destino. O `artifactId` é lido desse POM; não existe parâmetro de nome alternativo. |
| `-Modo Previa` | Padrão: inventariar e mostrar o resultado proposto, sem escrever dados ou remover origens. |
| `-SourceLegado` | Associação explícita quando o Source dos registros difere do diretório do POM local, por exemplo após relocalização. Não infere associação por apelido ou artifactId. |
| `-Registro` | Caminho do registro escolhido quando há mais de um para o Source. |
| `-Contexto` | Caminho do contexto escolhido quando os vínculos não determinam um plano único. Não corrige cadeia inconsistente. |
| `-Formato Texto\|Json` | Saída no terminal; Texto é o padrão. Nenhum relatório ou mapa é gravado pelo utilitário. |
| `-Modo Aplicar` | Consolidar as escolhas e publicar pelo núcleo permanente. Preserva originais e recusa sobrescrever conteúdo diferente no destino. |
| `-Modo Validar` | Conferir somente o projeto corrente, sem ler legado nem reaplicar conversão. Retorna `VALIDO` ou `PENDENTE`, com diagnósticos no terminal. |
| `-Modo Limpar` | Sem seleção, mostrar arquivos elegíveis e motivos, sem escrita. Com seleção explícita, revalidar e descartar somente esses arquivos. |
| `-Descartar` | Lista de arquivos individuais apresentados pela prévia de Limpar; diretórios e raízes compartilhadas são recusados. Exclusivo de Limpar. |
| `-Confirmacao` | `LIMPAR` confirma descarte; `RECUPERAR` trata uma interrupção anterior. Outro texto cancela. Obrigatório para execução em JSON; no terminal, a confirmação pode ser solicitada interativamente. Exclusivo de Limpar. |
| `-MtaDiretorio` | Origem explícita quando os vínculos não determinam um conjunto MTA único. Origem externa permanece no local. |
| `-PrioritizacaoContexto` | Contextos escolhidos para consolidar categorias e escopos; não apaga examinadas anteriores. |
| `-BuildResultado`, `-SonarResultado`, `-SonarTentativa` | Escolhas explícitas para resolver ambiguidades dos diagnósticos; uma tentativa falha não substitui o último conjunto utilizável. |
| `-Participantes` | Associação temporária `SourceLegado -> Pom`. Cada valor também pode conter `Pom`, `Registro`, `Contexto` e `MtaDiretorio`; todos devem refletir as mesmas escolhas nas conversões individuais. |
| `-Sprints` | Lista de escolhas com `Contexto`, `Cenario` funcional e `MestrePom` participante. O mestre publica; os demais recebem links. |

Os modos são operações do mesmo utilitário descartável. A execução sem modo continua somente leitura:

```powershell
powershell.exe -NoProfile -File tools/transicao/Converter-RegistrosProjeto.ps1 -Workspace C:\harness -Pom C:\fontes\aplicacao\pom.xml
```

A prévia mostra associação, decisões por issue, candidatos, destinos propostos,
referências e pendências. Registro e plano são selecionados por Source e vínculos
explícitos; `Previous` segue até a ponta única. Datas de arquivos não participam
da escolha. Um vínculo atual quebrado, ciclo ou documento de outra solicitação
fica pendente; não é substituído por um plano histórico.

O cadastro legado `planning/<artifactId>/issues/project.json`, contendo somente
`ArtifactId`, `Project` e `Source` como textos não vazios, é reconhecido como
associação. O artifactId deve corresponder ao POM e o Source à origem selecionada
(ou ao `SourceLegado` explícito em uma relocalização). Campos adicionais ou
identidades divergentes exigem conferência; não são descartados silenciosamente.
A aplicação preserva o original e associa o POM em `projeto.json` corrente.

Quando não há contexto de planejamento nem referência quebrada a um plano,
a prévia mostra `Plano: SEM_PLANO`. Nesse caso não se informa `-Contexto` e a
conversão não cria plano, tarefas ou prompt de planejamento. Planos existentes
continuam exigindo vínculo ou seleção explícita; referências quebradas permanecem
pendentes. Uma origem que não pôde ser interpretada bloqueia a aplicação, pois
não permite determinar seu Source com segurança; erro de leitura em planning
também impede declarar `SEM_PLANO`. Priorização, sprints e demais evidências
mantêm suas próprias escolhas e verificações, mesmo em um projeto sem plano.

Um contexto já preparado pode apontar `PlanPath` e `TodoPath` ainda não escritos.
A prévia informa `Planning.DocumentsState` (JSON) ou `Documentos do plano`
(texto): `AUSENTES`, `PRESENTES` ou `INCOMPLETOS`. Isso descreve a disponibilidade
do par, sem comprovar que a proposta foi concluída. Ambos ausentes permitem
converter contexto, prompt, fichas e evidências existentes, mantendo os destinos
futuros no contexto e a revisão pendente. Não são criados plano nem tarefas
fictícios. O contexto ainda exige vínculo ou escolha por `-Contexto`.

Um único documento existente, diretório no lugar de arquivo ou trabalho diferente
no destino interrompe a aplicação. Links humanos para documentos ausentes
continuam sendo lacunas; a ausência do par não comprova que nada se perdeu.
`Validar` aceita o preparo íntegro sem o par, exige o prompt e continua verificando
as referências. Índices e fontes gerados só oferecem links para os documentos
publicados. Os originais são preservados.

Manifestos e resultados MTA copiados para as evidências do plano são tratados
como cópias diagnósticas quando os anexos declaram sua origem sob o `Run` e o
Source é único e consistente. Continuam visíveis na prévia como anexos; a
conversão usa a fonte MTA direta e preserva as cópias antigas. O nome
`manifest.json` ou `result.json`, sozinho, não determina esse papel.

Declarações `CONCLUIDA` no registro e nos snapshots embutidos aparecem como
`DECLARADA_A_CONFERIR`. O legado não fornece resultado estruturado que comprove
a comparação executada: recibo, hash e declaração isolada não elegem uma base
reconciliada. A prévia mantém `PRELIMINAR` e expõe as fontes para conferência humana.

Priorização, sprints e diagnósticos aparecem como candidatos na prévia. Aplicar
exige resolver as ambiguidades e informar os participantes e cenários necessários.
A lista de descarte contém apenas candidatos e não autoriza remoção.

Exemplo de escolhas em uma sessão PowerShell, depois de conferir a prévia:

```powershell
$participantes = @{
    'C:\fontes-antigas\api' = @{ Pom = 'C:\fontes\api\pom.xml'; Contexto = 'C:\harness\.harness\planning\api\context.json' }
    'C:\fontes-antigas\backend' = 'C:\fontes\backend\pom.xml'
}
$cenarios = @(@{ Contexto = 'C:\harness\.harness\sprints\<planejamento>\revisoes\<revisao>\contexto.json'; Cenario = 'migracao'; MestrePom = 'C:\fontes\backend\pom.xml' })
& .\tools\transicao\Converter-RegistrosProjeto.ps1 -Workspace C:\harness -Pom C:\fontes\backend\pom.xml -SourceLegado C:\fontes-antigas\backend -Modo Aplicar -Participantes $participantes -Sprints $cenarios
```

Substitua os caminhos pelos candidatos conferidos. Para priorização multiprojeto,
converta os participantes em ordem decrescente dos nomes Maven: anexos humanos
compartilhados têm proprietário estável e o mestre só atesta cobertura quando
as fichas e seus anexos estão disponíveis. Cada chamada escreve somente no
projeto escolhido. As associações acima existem apenas durante a chamada.

### Acompanhar vários projetos, um por vez

O bloco abaixo executa a prévia de cada projeto e mantém um quadro em memória.
Informe as pastas e as escolhas conferidas antes de executá-lo. Ele ordena pelos
artifactIds do POM, em ordem ordinal decrescente. `A` aplica e valida; `V` apenas
valida o destino; Enter deixa para depois; `S` encerra. Nenhum descarte é chamado.
Falhas exibem o motivo e preservam o status de aplicação separado da validação.
As escolhas compartilhadas de sprints precisam ser iguais em todas as chamadas;
deixá-las vazias não ignora sprints legadas: o conversor exige sua resolução.

```powershell
# Acompanhamento sequencial da conversao
$ErrorActionPreference = 'Stop'
$raizHarness = 'C:\desenvolvimento\repositorio\harness-ambiente\jboss-mta-harness'
$raizFontes = 'C:\desenvolvimento\repositorio\jboss-7-jdk8'
$pastas = @(
    'SIMTR-api', 'SIMTR-Outsourcing-api', 'SIMTR-arquitetura-common',
    'SIMTR-arquiteturajee7', 'SIMTR-arquitetura-util', 'SIMTR-caixa-permissao',
    'SIMTR-caixa-verificapdf', 'SIMTR-keycloak', 'SIMTR-parent-all-jee7',
    'SIMTR-sicli-api', 'SIMTR-siecm-api', 'SIMTR-siiso-api',
    'SIMTR-sipes-api', 'SIMTR-siric-api'
)
$conversor = Join-Path $raizHarness 'tools\transicao\Converter-RegistrosProjeto.ps1'
Import-Module (Join-Path $raizHarness 'scripts\HarnessProject.psm1') -DisableNameChecking
$participantes = @{}
$porProjeto = @{}
$falhasIdentidade = @()
foreach ($pasta in $pastas) {
    try {
        $source = Join-Path $raizFontes $pasta
        $projeto = Get-HarnessProjectReference $raizHarness (Join-Path $source 'pom.xml')
        if ($porProjeto.ContainsKey($projeto.Name)) { throw "artifactId duplicado: $($projeto.Name)" }
        $participantes[$source] = @{ Pom = $projeto.Pom }
        $porProjeto[$projeto.Name] = $source
    } catch {
        $falhasIdentidade += [pscustomobject]@{ Pasta=$pasta; Motivo=$_.Exception.Message }
    }
}
if ($falhasIdentidade.Count) {
    $falhasIdentidade | Format-List | Out-Host
    throw 'Resolva os POMs acima antes de converter o escopo compartilhado. Nada foi aplicado.'
}

# Contexto de preparo confirmado para a SIMTR-api.
$sourceApi = Join-Path $raizFontes 'SIMTR-api'
$participantes[$sourceApi].Contexto = Join-Path $raizHarness '.harness\planning\simtr-parent\issues\hardcode__f6b4c3b3d9fb\p_171d6de849a2\contexto-simtr-parent-hardcoded-ip-add-f6b4c3.json'

# Acrescente escolhas somente depois de conferir os candidatos, por exemplo:
# $participantes[$sourceApi].BuildResultado = 'caminho conferido do result.json'
# Outros campos: Registro, MtaDiretorio, PrioritizacaoContexto,
# SonarResultado e SonarTentativa. Contextos dos demais projetos: Contexto.
$cenarios = @()
# Cada entrada de $cenarios exige Contexto, Cenario e MestrePom conferidos.

[string[]]$ordem = @($porProjeto.Keys)
[Array]::Sort($ordem, [StringComparer]::Ordinal)
[Array]::Reverse($ordem)
$status = @{}
foreach ($nome in $ordem) {
    $status[$nome] = [pscustomobject]@{
        Projeto=$nome; Etapa='AGUARDANDO'; Conversao='NAO_APLICADA'
        Validacao='NAO_EXECUTADA'; Motivo=''
    }
}
$numero = 0
foreach ($nome in $ordem) {
    $numero++
    $linha = $status[$nome]
    $etapa = 'PREVIA'
    $parametros = @{ Workspace=$raizHarness; Pom=$participantes[$porProjeto[$nome]].Pom }
    foreach ($campo in @('Registro','Contexto','MtaDiretorio','PrioritizacaoContexto',
                        'BuildResultado','SonarResultado','SonarTentativa')) {
        if ($participantes[$porProjeto[$nome]].ContainsKey($campo)) {
            $parametros[$campo] = $participantes[$porProjeto[$nome]][$campo]
        }
    }
    Write-Progress -Activity 'Conversao por projeto' -Status "$numero/$($ordem.Count): $nome" -PercentComplete (100 * ($numero-1) / $ordem.Count)
    try {
        $previa = $null
        Write-Host "`n[$numero/$($ordem.Count)] $nome"
        try {
            $previa = & $conversor @parametros -Modo Previa -Formato Json | ConvertFrom-Json
            $linha.Etapa = 'PREVIA'
            Write-Host "Contexto: $($previa.Planning.Selection); documentos: $($previa.Planning.DocumentsState)"
            foreach ($pendencia in $previa.Pending) { Write-Host "PENDENTE: $pendencia" }
        } catch {
            $linha.Etapa = 'PREVIA FALHOU'
            $linha.Motivo = $_.Exception.Message
            Write-Host "Previa indisponivel: $($linha.Motivo)" -ForegroundColor Yellow
        }
        $acao = (Read-Host 'A aplicar e validar; V validar; Enter pular; S sair').Trim().ToUpperInvariant()
        if ($acao -eq 'S') { break }
        if ($acao -eq 'A') {
            if (-not $previa) { throw 'Resolva a falha da previa antes de aplicar; V continua disponivel.' }
            $etapa = 'APLICAR'
            $resultado = & $conversor @parametros -Participantes $participantes -Sprints $cenarios -Modo Aplicar -Formato Json | ConvertFrom-Json
            $linha.Conversao = $resultado.Status
            foreach ($aviso in $resultado.Diagnostics) { Write-Host "CONFERIR: $aviso" }
        }
        if ($acao -in @('A','V')) {
            $etapa = 'VALIDAR'
            $validacao = & $conversor -Workspace $raizHarness -Pom $parametros.Pom -Modo Validar -Formato Json | ConvertFrom-Json
            $linha.Validacao = $validacao.Status
            $linha.Motivo = $validacao.Diagnostics -join '; '
            $linha.Etapa = 'CONFERIDO'
            foreach ($aviso in $validacao.Diagnostics) { Write-Host "PENDENTE: $aviso" }
        }
    } catch {
        $linha.Etapa = "$etapa FALHOU"
        $linha.Motivo = $_.Exception.Message
        Write-Host "$etapa interrompido: $($linha.Motivo)" -ForegroundColor Yellow
    }
    $ordem | ForEach-Object { $status[$_] } | Format-Table Projeto, Etapa, Conversao, Validacao -AutoSize | Out-Host
    if ((Read-Host 'Enter para o proximo projeto; S para sair') -eq 'S') { break }
}
Write-Progress -Activity 'Conversao por projeto' -Completed
$ordem | ForEach-Object { $status[$_] } | Format-Table Projeto, Etapa, Conversao, Validacao -AutoSize
# Para rever os motivos completos nesta sessao:
# $ordem | ForEach-Object { $status[$_] } | Format-List
```

Sprints preservam as premissas da revisão escolhida e o cálculo comprovado pelo
ponteiro legado, em arquivos separados. O resultado fica `CONVERTED`, com revisão
pendente. Cadeia calculada sem ponteiro comprovável exige conciliação; não é
convertida como cenário inicial. B0, inclusões acumuladas e consumo de fases não
são reconstruídos do registro atual.

Depois de aplicar, `-Modo Validar` usa somente `-Workspace` e `-Pom`. Confere
identidades, pares de documentos, cobertura, baseline e referências correntes,
inclusive anexos das fichas de parceiros atestadas pelo ranking. Não recupera
publicações pendentes nem modifica arquivos. `VALIDO` informa integridade
operacional: não confirma decisões humanas, reconciliação, GO ou aceite. Referências
ausentes e dependências legadas resultam em `PENDENTE`, sem reparo automático.

O inventário lê as famílias legadas conhecidas sob `.harness`, exclui originais
de pacotes e projetos já identificados por `projeto.json`, e recusa links/junctions.
Publicação pendente no destino é recusada sem recuperação. Os testes usam
fixtures sintéticas e comparam caminhos, bytes e datas dos arquivos antes/depois;
nenhuma conversão ou limpeza de dados reais faz parte desta implementação.

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

`Aplicar` não apaga originais. `Limpar` recompõe a conversão somente em memória e
confere a equivalência com o destino corrente. Use as mesmas escolhas de origem,
contexto, participantes e cenários usadas na aplicação. Trabalho posterior no
destino ou originais alterados impedem o descarte automático; não sobrescreva
esse trabalho para contornar a recusa.

Primeiro execute `-Modo Limpar` sem `-Descartar` para obter a prévia. Depois
informe somente os arquivos conferidos em `-Descartar` e confirme `LIMPAR`.
Em uma sessão PowerShell, a lista pode ser passada como array:

```powershell
& .\tools\transicao\Converter-RegistrosProjeto.ps1 -Workspace C:\harness -Pom C:\fontes\aplicacao\pom.xml -Modo Limpar
# Substitua pelos caminhos individuais elegíveis da prévia:
$selecionados = @('C:\harness\.harness\planning\legado\plano.md')
& .\tools\transicao\Converter-RegistrosProjeto.ps1 -Workspace C:\harness -Pom C:\fontes\aplicacao\pom.xml -Modo Limpar -Descartar $selecionados -Confirmacao LIMPAR -Formato Json
```

A seleção é conferida novamente depois da confirmação. Fontes, origens MTA,
projetos correntes, originais de pacotes e diretórios são preservados. Referências
de outro projeto ou consumidor desconhecido, inclusive notas recebidas e links
transitivos, impedem descartar a folha. Alterações concorrentes cancelam a escrita.
Nenhum mapa de descarte permanece como requisito do projeto convertido.

Interrupção pode deixar `RECUPERACAO_PENDENTE`. A prévia continua somente leitura.
Com journal, repita exatamente os arquivos exibidos e use `-Confirmacao RECUPERAR`
para restaurar a transação. Sem journal, omita `-Descartar`: a recuperação retira
somente o estágio técnico e preserva os originais no estado em que estão.
`RECUPERADO` não inicia novo descarte. Depois, confira novamente a prévia.
Repetir uma seleção inteiramente ausente retorna `SEM_RESIDUOS` se o destino
continuar válido; não inclui arquivos novos. Ausência parcial sem journal é recusada.

A limpeza corrente pela tarefa **Workspace: limpar execucoes** é separada:
limita-se aos resíduos temporários de build/MTA/Sonar e à opção própria de backups
temporários. Ela não elimina o legado nem os documentos correntes da migração.

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
