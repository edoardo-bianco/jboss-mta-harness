import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, writeFileSync, readFileSync, existsSync } from 'node:fs';
import path from 'node:path';
import { parse as parseToml } from 'smol-toml';
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
  assert.deepEqual(parseToml(saved).mcp_servers.harnessIssues.enabled_tools,
    ['auditar_base','listar_issues','obter_issue']);
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

test('configuracao MCP referencia workspace e harness sem copiar as pastas',()=>{
  const root=mkdtempSync(path.join(harnessRoot,'.harness/tests/mcp-sources-'));
  const workspace=path.join(root,'projetos.code-workspace'), harnessConfig=path.join(root,'harness.json');
  writeFileSync(workspace,JSON.stringify({folders:[{path:'.'}]}));
  writeFileSync(harnessConfig,JSON.stringify({schemaVersion:1,mta:{runsPath:null}}));
  const config=path.join(root,'mcp.json');
  writeFileSync(config,JSON.stringify({root,allowedRoots:[root],workspacePath:workspace,harnessConfigPath:harnessConfig}));
  const settings=loadSettings(config);
  assert.equal(settings.workspacePath,workspace);
  assert.equal(settings.harnessConfigPath,harnessConfig);
  assert.deepEqual(settings.allowedRoots,[root]);
  writeFileSync(config,JSON.stringify({root,allowedRoots:[root],workspacePath:workspace+'-ausente'}));
  assert.throws(()=>loadSettings(config),/workspacePath.*encontrad/i);
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

test('configurador vincula os arquivos locais existentes e migra lista fixa preservando excecoes',()=>{
  const root=mkdtempSync(path.join(harnessRoot,'.harness/tests/mcp-workspace-config-'));
  mkdirSync(path.join(root,'config'));
  const workspace=path.join(root,'jboss-mta-harness.local.code-workspace');
  const harnessConfig=path.join(root,'config/harness.local.json');
  writeFileSync(workspace,JSON.stringify({folders:[{path:'.'}]}));
  writeFileSync(harnessConfig,JSON.stringify({schemaVersion:1,mta:{runsPath:null}}));
  const file=path.join(root,'config/mcp.local.json');
  writeFileSync(file,JSON.stringify({allowedRoots:['.','../anexos'],timeoutMs:45000}));
  const result=configureClients(root,process.execPath);
  const configured=JSON.parse(readFileSync(file,'utf8'));
  assert.equal(configured.workspacePath,'jboss-mta-harness.local.code-workspace');
  assert.equal(configured.harnessConfigPath,'config/harness.local.json');
  assert.deepEqual(configured.allowedRoots,['.','../anexos']);
  assert.equal(configured.timeoutMs,45000);
  assert.equal(result.workspacePath,workspace);
  assert.equal(result.harnessConfigPath,harnessConfig);
  const before=readFileSync(file,'utf8');
  configureClients(root,process.execPath);
  assert.equal(readFileSync(file,'utf8'),before);
});

test('configurador preserva workspace personalizado e falha antes de gravar quando referencia e invalida',()=>{
  const root=mkdtempSync(path.join(harnessRoot,'.harness/tests/mcp-custom-workspace-'));
  mkdirSync(path.join(root,'config'));
  const custom=path.join(root,'outro.code-workspace');
  writeFileSync(custom,JSON.stringify({folders:[]}));
  writeFileSync(path.join(root,'jboss-mta-harness.local.code-workspace'),JSON.stringify({folders:[]}));
  const config=path.join(root,'config/mcp.local.json');
  writeFileSync(config,JSON.stringify({allowedRoots:['.'],workspacePath:'outro.code-workspace'}));
  configureClients(root,process.execPath);
  assert.equal(JSON.parse(readFileSync(config,'utf8')).workspacePath,'outro.code-workspace');
  const client=path.join(root,'.codex/config.toml'), before=readFileSync(client,'utf8');
  const invalid=JSON.stringify({allowedRoots:['.'],workspacePath:'nao-existe.code-workspace'});
  writeFileSync(config,invalid);
  assert.throws(()=>configureClients(root,process.execPath),/workspacePath.*encontrad/i);
  assert.equal(readFileSync(client,'utf8'),before);
  assert.equal(readFileSync(config,'utf8'),invalid);
});
