# Compartilhar analise ou planejamento entre colegas

[Voltar ao fluxo do desenvolvedor](../harness-migracao-desenvolvedor.md).

Use **Terminal > Run Task > Planejamento: compartilhar contexto** para exportar
um ponto estavel em ZIP ou importar o pacote recebido. O menu pede a operacao,
o contexto e o arquivo. Na importacao, associe cada projeto de origem ao projeto
local do workspace. Essa associacao e explicita, mesmo quando o artifactId coincide.

## Qual ponto compartilhar

| Ponto escolhido | Conteudo do pacote | Continuidade do colega |
| --- | --- | --- |
| Priorizacao concluida | Categoria, base inicial, cobertura, ranking, fichas examinadas, registros, anexos referenciados, cadeia Previous e MTA com input/rules/output | Continuar a mesma categoria ou escolher uma ficha no registro e planejar a issue |
| Plano/to-do de uma issue | Contexto, ficha, plano, to-do, prompt, evidencias consolidadas e revisoes anteriores da mesma issue | Revisar escopo/GO e implementar manualmente ou com agente, comparando com o codigo local |

O pacote de analise exige priorizacao v4 concluida e diagnostico completo dos
projetos do escopo. O de planejamento exige LayoutVersion=2, CONSOLIDATED e o par
plano/to-do presente. Arquivos presentes nao comprovam revisao ou GO humano.
Recibos antigos continuam legiveis, mas precisam de um novo preparo compativel
para entrar neste formato de compartilhamento. Uma cadeia legada nao e truncada.

O ZIP de analise leva snapshot de codigo e regras do MTA. O de plano leva somente
o recorte consolidado, sem exigir a pasta MTA completa para implementar.
Revise os anexos e use o canal de compartilhamento aprovado pela sua equipe.
Configuracao da maquina, settings Maven, caches e permissoes nao sao coletados.
O filtro de nomes de credenciais nao substitui a revisao do conteudo dos anexos.

## Na maquina de quem recebe

1. Atualize o harness para a mesma versao usada na origem e abra um workspace
   salvo com o codigo dos projetos locais. Configure as ferramentas desta maquina.
2. Execute **Planejamento: compartilhar contexto**, escolha **Importar**, informe
   o ZIP e associe cada Source ao projeto local correspondente. O importador nao
   clona, substitui ou altera o codigo da aplicacao.
3. Confira o `ContextPath` devolvido, o registro e os documentos locais.
   Os originais recebidos ficam byte a byte em
   `.harness/importacoes/<PackageId>/original/`, junto do manifesto. As copias
   operacionais seguem os destinos normais de planejamento/priorizacao e possuem
   `ImportedFrom`. O indice de projetos e atualizado; se `IndexStatus=PENDING`,
   execute **Workspace: atualizar indice dos projetos**.
4. Informe o contexto ao orientador: “Recebi este contexto: `<ContextPath>`.
   Confira a etapa e indique o proximo passo para continuar.” No Codex, use
   `$orientar-migracao`; no Copilot, `migracao_helper`.

**Se recebeu analise:** pode continuar a sequencia pela tarefa de priorizacao,
mantendo categoria e base inicial. Para planejar, marque ANALISAR AGORA na issue
escolhida, mantenha a referencia da ficha/anexos e use **Planejamento: planejar**.

**Se recebeu plano:** **Planejamento: planejar** retoma a proposta existente sem
consultar a pasta MTA original. Confira o alcance do GO recebido e os pontos do
codigo atual antes de executar. O orientador ajuda na revisao, na execucao manual
ou assistida e no aceite; importar nao concede GO nem comprova corretiva local.

Novos anexos, outra origem ou contrato/template diferente impedem reutilizar
silenciosamente o plano importado. Reavaliar o recorte MTA exige sua origem
registrada: obtenha o diagnostico completo ou uma nova proposta do colega.
Nao converta MTA em EVIDENCIAS apenas porque a pasta original esta indisponivel.
Copias consolidadas sao historicas; os anexos atuais ficam no indice editavel da issue.

## Conflitos e limites

- A primeira importacao exige destinos livres para os registros/recibos envolvidos.
  Mesmo um registro vazio ja existente gera conflito: confira o estado ou use
  outro checkout/workspace de ensaio. Nao apague trabalho para contornar o aviso.
- Reimportar o mesmo ZIP com o mesmo mapeamento reutiliza a importacao e preserva
  edicoes locais. Outro conteudo para o mesmo PackageId ou RequestId ja existente
  e recusado. Esta entrega nao faz mesclagem incremental de pacotes.
- Hashes verificam integridade e a cadeia interna, nao autenticam o remetente.
  Pacotes com arquivos adulterados, caminhos invalidos, links/junctions, papeis
  desconhecidos ou artefatos fora do recorte sao recusados.
- Limites: 20.000 entradas, 512 MiB por arquivo e 2 GiB descompactados. Se exceder,
  reduza o escopo da analise ou compartilhe o plano consolidado da issue.
- O indice de origem e uma referencia historica. O indice operacional e gerado
  com os projetos locais. Lacunas declaradas em `Missing` continuam lacunas.
- Caminhos de codigo e dados dentro de anexos/snapshots podem ser historicos.
  Use os indices locais, o caminho relativo e o simbolo para conferir o Source.

## Uso explicito pela CLI

Exportacao (o destino ZIP precisa ser novo e sua pasta deve existir):

```powershell
.\scripts\compartilhar-contexto.ps1 -WorkspacePath .\jboss-mta-harness.local.code-workspace `
  -Action Export -ContextPath 'C:\origem\contexto-issue.json' -PackagePath 'C:\troca\issue.zip'
```

Crie `sources.json` com os caminhos de origem encontrados no manifesto e os
projetos locais ja declarados no workspace:

```json
{ "C:/origem/meu-servico": "D:/trabalho/meu-servico" }
```

Valide sem gravar e, depois, repita sem `-Preview` para importar:

```powershell
.\scripts\compartilhar-contexto.ps1 -WorkspacePath .\jboss-mta-harness.local.code-workspace `
  -Action Import -PackagePath 'C:\troca\issue.zip' -SourceMapPath .\sources.json -Preview -OutputFormat Json
```

`READY` significa que a pre-validacao passou; `IMPORTED` informa importacao nova
ou reutilizada. A escrita ainda pode falhar por permissao, concorrencia ou disco;
falhas antes da publicacao removem somente os arquivos/diretorios criados pela
chamada. A atualizacao do indice e informada separadamente.

## Ensaio em pequena escala

Na maquina de trabalho, conclua uma fatia de 10% de uma categoria, exporte a
analise e importe em outra raiz com fontes locais. Confira que continuar exclui
as examinadas sem mudar o total inicial. Escolha uma ficha recebida, produza seu
plano/to-do, exporte o plano e importe em um terceiro ambiente de ensaio. Confira
leitura, links e preparo de implementacao sem o MTA original. Reimporte o mesmo
ZIP apos uma nota local no plano e confira que a nota permanece. Esse roteiro
nao exige executar a corretiva nem concede aceite sobre a aplicacao.
