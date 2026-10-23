# Atualizar a maquina de trabalho apos o ensaio inicial

Este roteiro acompanha as correcoes de 22/10/2026. Use-o **depois de integrar e
obter pelo Git a revisao corrigida do harness**. A existencia deste documento
na branch de trabalho nao significa que a main remota ja contenha as mudancas.
Nao copie `conferencia-harness/` por cima do repositorio.

## 1. Atualizar somente o codigo

Na raiz do harness, confira a branch e alteracoes locais antes de atualizar
pela rotina Git da equipe. Preserve `config/harness.local.json` e as entradas
de `C:\desenvolvimento\jboss-eap7.4-configuracao`. Nao substitua propriedades,
JVM, template ou caminhos preenchidos na maquina por exemplos do repositorio.

Depois da atualizacao, devem estar disponiveis:

- `Servidor: reiniciar JBoss`, com modo normal/debug e servidor/Todos;
- `Servidor: acompanhar logs`, tambem com servidor/Todos;
- `scripts/acompanhar-log-jboss.ps1`;
- gerador de modulos corrigido e campo opcional `files` do preparo.

Essas tarefas ficam em `.vscode/tasks.json` do harness. Nao e preciso recriar
o workspace para atualizar os scripts ou mudar `eap74Home`: a configuracao e
lida a cada acao. Se as tarefas nao aparecerem, recarregue a janela do VS Code
e confira se a pasta do harness atualizado faz parte do workspace aberto.

Restart/logs nao exigem novo preparo. Reiniciar usa XML, JVM, modulos e arquivos
que ja estao instalados; nao aplica mudancas da pasta privada.

## 2. Corrigir ou conferir modulos existentes

O gerador antigo escrevia `slot="main"` com schema `module:1.9`, rejeitado pelo
JBoss Modules. A correcao retira esse atributo. Para slots personalizados,
usa `name="nome:slot"`; as pastas continuam iguais. Nao troca JARs, hashes,
dependencias ou nomes de drivers.

No ensaio, o segundo boot confirmou o driver Oracle 19.22 e o datasource;
o teste de conexao retornou `success`/`true`. Isso dispensa repetir o diagnostico
do primeiro boot, mas ainda e preciso conferir o modulo Jasper e as fontes
quando a aplicacao for usada.

**Pare o EAP antes de preparar.** Confira os `module.xml` Oracle e Jasper no
servidor. Para o slot main, o inicio deve ter a forma:

```xml
<module xmlns="urn:jboss:module:1.9" name="com.oracle.ojdbc8">
```

Se ja houve ajuste manual, o novo preparo so prossegue se os arquivos forem
identicos aos gerados, inclusive formatacao. Se houver divergencia, preserve
os arquivos e compare o manifesto privado, os JARs e os descritores. Nao apague
o modulo, nao mude hashes para contornar a verificacao e nao use um `force`.
Concilie a diferenca confirmada com o servidor parado; depois repita o preparo.
Uma instalacao incompleta tambem exige analise antes da retomada.

O consolidado antigo intacto pode ser regenerado. Se foi editado manualmente,
escolha outra pasta `output` no JSON e preserve a anterior para comparacao.
Nao altere `.eap-preparo.json` nem copie arquivos manualmente para dentro dele.

## 3. Tornar repetivel a copia do keystore

Se o arquivo ja foi copiado manualmente para o EAP, mantenha-o e confira sua
origem. Para os preparos seguintes, coloque a copia autorizada em:

```text
C:\desenvolvimento\jboss-eap7.4-configuracao\arquivos\simtr-keystore.jceks
```

Acrescente ao `preparo.json`, preservando os outros campos:

```json
"files": [
  {"source": "arquivos/simtr-keystore.jceks", "target": "simtr-keystore.jceks"}
]
```

O destino sera `standalone/configuration/simtr-keystore.jceks`, dentro de
`eapHome` e do consolidado. Origem e destino identicos sao aceitos e preservam
as datas; bytes diferentes interrompem a operacao. Nenhum segredo e preenchido
automaticamente. Use a [secao de arquivos externos](README.md#31-incluir-keystores-e-outros-arquivos-privados)
para acrescentar outros arquivos. Sem `files`, o preparo permanece como antes.

## 4. Aplicar e verificar

Na raiz do harness, com o EAP parado:

```powershell
$scripts = Join-Path (Get-Location) 'doc/estrategia-migracao-ambientes-jboss-eap-7.4/jboss-eap7.4-configuracao/scripts'
$configuracao = 'C:\desenvolvimento\jboss-eap7.4-configuracao\preparo.json'
& "$scripts/preparar-eap74.ps1" -Configuracao $configuracao
# Depois de conferir o consolidado em privado:
& "$scripts/preparar-eap74.ps1" -Configuracao $configuracao -Aplicar
```

Confira XML gerado, modulos e arquivos declarados, e os caminhos/offset iguais
no preparo e no harness. Inicie, acompanhe o log e confira boot sem erros.
Repita o [teste de banco](../../guias/tools/jboss.md#testar-conexao-com-o-banco-apos-o-start)
quando aplicar mudanca de configuracao; depois valide o deploy e os fluxos da
aplicacao, incluindo fontes, keystore e integracoes usadas. Restart interrompe
todas as aplicacoes da instancia; Ctrl+C no acompanhamento de logs nao para o EAP.

## 5. Atualizacoes ainda condicionadas a revisao de DES

O template compartilhado ainda tem [pendencias de configuracao](../jboss-eap7.4-configuracao-des/README.md).
Nao ha alteracao automatica do template, valores, JDK ou patch neste conjunto.
Quando um item for resolvido, registrar: arquivo/revisao de origem, mudanca
necessaria no local (ou motivo de dispensa), comando e verificacao esperada.
Mudanca de template exige alinhar sua entrada privada e regenerar/aplicar
parado. Mudanca somente de imagem/pipeline/OKD cabe a equipe responsavel e
nao implica alterar o Windows por si so.
