import * as z from 'zod/v4';

const text = z.string().min(1).max(8192);
const common = {
  ContextPath: text.describe('Recibo de priorizacao ou planejamento explicitamente selecionado; nunca escolher por recencia.'),
  Source: text.optional().describe('Projeto local; obrigatorio se o recibo inclui varios projetos.'),
  ExpectedBasisSha256: z.string().regex(/^[a-fA-F0-9]{64}$/).optional(),
  Page: z.number().int().min(1).max(2147483647).optional(),
  PageSize: z.number().int().min(1).max(50).optional(),
  MaxTextChars: z.number().int().min(128).max(8192).optional(),
};

export const toolSchemas = {
  auditar_base: z.strictObject(common),
  listar_issues: z.strictObject({ ...common, Category: text.optional(), Decision: text.optional(), Progress: text.optional(), Text: text.optional(), Label: text.optional() }),
  obter_issue: z.strictObject({ ...common, Id: text, PageSize: z.number().int().min(1).max(10).optional(), Incident: z.number().int().min(1).max(2147483647).optional() })
    .refine(args => args.Incident === undefined || (args.Page === undefined && args.PageSize === undefined), 'Incident nao permite Page/PageSize.'),
};

export const descriptions = {
  auditar_base: 'Confere identidade, hashes e divergencias da base selecionada. Somente leitura; nao confere codigo atual nem concede GO/aceite.',
  listar_issues: 'Lista issues com filtros e paginas. Availability e do preparo; decisoes e andamento sao atuais. Consulta nao marca exame/cobertura.',
  obter_issue: 'Recupera uma issue e incidentes paginados/por ordinal. Caminhos e linhas sao candidatos do diagnostico; conferir codigo atual. Nao prova resolucao.',
};

export const outputSchema = z.object({
  SchemaVersion: z.literal(1), Action: z.string().nullable(), Status: z.enum(['OK', 'ERROR']), ReadOnly: z.literal(true),
  Provenance: z.record(z.string(), z.unknown()).nullable(), Data: z.record(z.string(), z.unknown()).nullable(),
  Paging: z.record(z.string(), z.unknown()).nullable(), Diagnostics: z.array(z.string()),
  Error: z.object({ Code: z.string(), Message: z.string() }).passthrough().nullable(),
});

export function queryError(action, code, message) {
  return { SchemaVersion: 1, Action: action, Status: 'ERROR', ReadOnly: true, Provenance: null, Data: null, Paging: null, Diagnostics: [], Error: { Code: code, Message: message.slice(0,1024) } };
}
