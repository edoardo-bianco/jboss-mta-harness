# ADR-0007: compartilhamento de contextos com origem preservada

Status: implementada; ensaio humano na maquina de trabalho pendente.
Data: 2026-10-06.

## Contexto

Quem analisa pode ser diferente de quem planeja ou implementa. Copiar pastas com
caminhos absolutos nao torna os recibos operacionais em outro workspace. A
[ADR-0006](0006-categorias-e-dossie-por-issue.md) consolidou as evidencias por issue;
agora e necessario transportar pontos estaveis sem sobrescrever historico local.

## Decisao

Uma operacao `Planejamento: compartilhar contexto` exporta/importa ZIP com
SchemaVersion=1, PackageId, inventario SHA-256 e lacunas. Ha dois tipos: analise
concluida v4, incluindo cadeia da sequencia e MTA completo para continuar; e
planejamento LayoutVersion=2 de uma issue, com proposta e evidencias consolidadas.
Nao ha acoplamento a servidor MCP ou novo processo de implementacao.

A importacao exige SourceMap explicito para projetos do workspace. Preserva
originais byte a byte e materializa copias operacionais com ImportedFrom,
RequestId preservado e caminhos locais. MtaOrigin.Project/Source/RunId continuam
sendo a identidade do diagnostico recebido. Cada ancestral conserva sua propria
base; hashes da cadeia recebida sao conferidos antes de recalcular os derivados.

O manifesto e dado nao confiavel: limites, caminhos, papeis e vinculos ao recibo
sao validados antes de escrever. A publicacao do recibo de importacao e protegida
pelo lock local ja existente. Falha remove apenas arquivos e diretorios novos
vazios; atualizacao do indice e pos-processamento com resultado proprio.

Nenhum destino existente e sobrescrito. Reimportacao identica e idempotente;
conflitos de registro, RequestId, conteudo ou SourceMap exigem conciliacao humana.
Nao implementar mesclagem de pacotes nesta entrega.

## Consequencias

Plano consolidado recebido permite retomar a proposta e preparar implementacao
sem MTA original. Mudanca de origem, anexos ou contrato/template exige reavaliacao,
sem fallback silencioso. Analise recebida leva o diagnostico necessario a nova
priorizacao e planejamento. Copias e snapshots aumentam o tamanho do pacote.

GO, execucao e aceite recebidos permanecem evidencias da origem; o desenvolvedor
confere seu alcance sobre o codigo local. O importador nao integra corretivas,
controla branches, instala ferramentas nem copia configuracao da maquina.

O [guia operacional](../guias/tools/compartilhamento-contextos.md) detalha os
limites, o uso manual/assistido e o ensaio entre maquinas.
