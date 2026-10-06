import assert from 'node:assert/strict';
import { test } from 'node:test';
import { toolSchemas, outputSchema } from '../contract.mjs';

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
