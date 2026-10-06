import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, writeFileSync, readFileSync, existsSync } from 'node:fs';
import path from 'node:path';
import { configureClients } from '../configure.mjs';
import { harnessRoot, loadSettings } from '../bridge.mjs';

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

test('configuracao explicita ausente nao assume raizes padrao',()=>{
  const root=mkdtempSync(path.join(harnessRoot,'.harness/tests/mcp-missing-'));
  assert.throws(()=>loadSettings(path.join(root,'ausente.json')),/configuracao.*encontrad/i);
});

test('TOML inline existente e preservado quando nao pode receber nova tabela',()=>{
  const root=mkdtempSync(path.join(harnessRoot,'.harness/tests/mcp-inline-'));
  mkdirSync(path.join(root,'.codex'));
  const file=path.join(root,'.codex/config.toml');
  const original='mcp_servers = { outro = { command = "outro.exe" } }\n';
  writeFileSync(file,original);
  assert.throws(()=>configureClients(root,process.execPath),/TOML/);
  assert.equal(readFileSync(file,'utf8'),original);
  assert.equal(existsSync(path.join(root,'.vscode/mcp.json')),false);
  assert.equal(existsSync(path.join(root,'config/mcp.local.json')),false);
});
