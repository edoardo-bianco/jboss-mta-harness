import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, writeFileSync, readFileSync, existsSync } from 'node:fs';
import path from 'node:path';
import { configureClients } from '../configure.mjs';
import { harnessRoot } from '../bridge.mjs';

test('configuracao local preserva outros servidores, e idempotente e recusa conflito',()=>{
  const root=mkdtempSync(path.join(harnessRoot,'.harness/tests/mcp-config-'));
  mkdirSync(path.join(root,'.codex')); mkdirSync(path.join(root,'.vscode'));
  const codex=path.join(root,'.codex/config.toml'), copilot=path.join(root,'.vscode/mcp.json');
  const original='[mcp_servers.outro]\ncommand = "outro.exe"\n';
  writeFileSync(codex,original);
  writeFileSync(copilot,JSON.stringify({servers:{outro:{command:'outro.exe'}},inputs:[]}));
  configureClients(root,process.execPath);
  assert.ok(readFileSync(codex,'utf8').startsWith(original));
  const json=JSON.parse(readFileSync(copilot,'utf8'));
  assert.equal(json.servers.outro.command,'outro.exe');
  assert.deepEqual(json.inputs,[]);
  assert.equal(json.servers.harnessIssues.command,process.execPath);
  const saved=readFileSync(codex,'utf8');
  configureClients(root,process.execPath);
  assert.equal(readFileSync(codex,'utf8'),saved);
  json.servers.harnessIssues.command='custom.exe'; writeFileSync(copilot,JSON.stringify(json));
  assert.throws(()=>configureClients(root,process.execPath),/harnessIssues/);
  assert.equal(readFileSync(codex,'utf8'),saved);
  assert.ok(existsSync(path.join(root,'config/mcp.local.json')));
});
