<details>
<summary>Legenda e limites do andamento</summary>

| Andamento | Condicao para registrar |
| --- | --- |
| NAO ANALISADA | Ainda sem analise registrada no fluxo da migracao. |
| EM ANALISE | Exame iniciado, com achados ou lacunas registrados; analise incompleta. |
| ANALISADA | Analise documentada com aplicabilidade, alcance e limites; proposta ainda nao concluida. |
| PLANEJADA | Proposta e tarefas prontas para o recorte; GO e uma declaracao separada. |
| EM IMPLEMENTACAO | Corretiva autorizada iniciada; implementacao por concluir. |
| IMPLEMENTADA | Corretiva aplicada no codigo local no recorte declarado; verificacoes pendentes. |
| VERIFICADA | Criterios tecnicos aplicaveis atendidos com evidencias; aceite humano pendente. |
| CONCLUIDA | Verificacoes atendidas e aceite humano explicito do resultado e de todo o escopo aplicavel da issue, referenciado no registro. |

Fonte: Andamento em migracao.md. Percentual = quantidade no estado / total corrente
registrado da origem/categoria * 100, com duas casas. Inclui adiadas, fora do
escopo e nao reencontradas. Nao mede ocorrencias, esforco nem media de etapas.
No consolidado, somam-se quantidades e denominadores; nao percentuais. A mesma
regra em dois projetos conta duas issues. Arredondamentos podem diferir de 100%.
A base InitialTotal da priorizacao permanece fixa ate Recreate explicito.

ADIAR/FORA DO ESCOPO sao decisoes e NAO REENCONTRADA e presenca: podem sobrepor
estados, nao sao conclusao. Origem manual e MTA permanecem distintas, inclusive
na categoria manual. Totais do registro e do diagnostico MTA podem diferir.
Estado vazio/desconhecido e lacuna; ausencia ou leitura invalida nao e zero.
Zero conhecido tem percentual sem base (-). Os IDs em cada grupo permitem
conferir suas linhas no registro e seguir os links de ficha/evidencias.

Preparar prompt, cadastrar ficha, receber codigo ou obter build verde nao promove
estado. Conferir evidencias e aceite cabe ao condutor. Cobertura parcial exige
recorte/fase e pendencias na observacao; aceite de recorte nao conclui a issue
inteira. VERIFICADA ainda aguarda aceite; CONCLUIDA nao conclui a migracao global.
AGUARDANDO INTEGRACAO fica na observacao enquanto a corretiva estiver fora do
Source local. Falha de teste impede VERIFICADA; reabertura preserva o aceite
anterior e registra motivo/alcance. Data de calculo nao comprova atualidade do
codigo. Apos edicao manual, use Workspace: atualizar indice dos projetos.

</details>
