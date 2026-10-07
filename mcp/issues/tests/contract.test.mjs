import assert from 'node:assert/strict';
import { test } from 'node:test';
import { readFileSync } from 'node:fs';
import { toolSchemas, outputSchema } from '../contract.mjs';

test('agentes e prompts Copilot selecionam as tres consultas pelos nomes do VS Code', () => {
  // VS Code normaliza o nome do servidor para minusculas e compara referencias
  // de tools com igualdade exata; o prefixo harnessIssues/ nao corresponde.
  const expected = Object.keys(toolSchemas).map(name => `harnessissues/${name}`).sort();
  const agents = ['migracao_helper', 'migracao_preparo_helper', 'migracao_reconciliacao_helper',
    'migracao_planejamento_helper', 'migracao_impacto_helper', 'migracao_implementacao_helper'];
  const prompts = ['priorizar-issues', 'planejar-lotes', 'revisar-lote', 'implementar-lote',
    'revisar-resultado', 'manter-migracao'];
  const files = [...agents.map(name => `agents/${name}.agent.md`),
    ...prompts.map(name => `prompts/${name}.prompt.md`)];
  for (const file of files) {
    const text = readFileSync(new URL(`../../../.github/${file}`, import.meta.url), 'utf8');
    const frontmatter = /^---\r?\n([\s\S]*?)\r?\n---/.exec(text)?.[1];
    const toolLine = /^tools: \[(.*)\]\r?$/m.exec(frontmatter)?.[1];
    assert.ok(toolLine, `${file}: lista de tools ausente`);
    const tools = [...toolLine.matchAll(/['"]([^'"]+)['"]/g)].map(match => match[1]);
    const queries = tools.filter(name => name.toLowerCase().startsWith('harnessissues/'));
    assert.deepEqual(queries.sort(), expected, `${file}: referencias MCP nao resolvidas pelo VS Code`);
  }
});

test('somente as tres consultas e argumentos delimitados', () => {
  assert.deepEqual(Object.keys(toolSchemas), ['auditar_base', 'listar_issues', 'obter_issue']);
  assert.equal(toolSchemas.listar_issues.safeParse({ ContextPath: 'C:/contexto.json' }).success, true);
  for (const extra of [{ Root: 'C:/' }, { AllowedRoots: ['C:/'] }, { Command: 'whoami' }, { PageSize: 51 }]) {
    assert.equal(toolSchemas.listar_issues.safeParse({ ContextPath: 'C:/contexto.json', ...extra }).success, false);
  }
  assert.equal(toolSchemas.obter_issue.safeParse({ ContextPath: 'C:/contexto.json', Id: 'regra', Incident: 1, Page: 1 }).success, false);
  assert.equal(toolSchemas.obter_issue.safeParse({ ContextPath: 'C:/contexto.json', Id: 'regra', PageSize: 11 }).success, false);
  assert.equal(toolSchemas.auditar_base.safeParse({ ContextPath: 'C:/contexto.json', Text: 'x' }).success, false);
  assert.equal(outputSchema.safeParse({ Status: 'OK', Data: {} }).success, false);
});
