import test from 'node:test';
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { readFileSync, readdirSync, statSync } from 'node:fs';
import { createHash } from 'node:crypto';
import path from 'node:path';
import { Client } from '@modelcontextprotocol/client';
import { StdioClientTransport } from '@modelcontextprotocol/client/stdio';
import { harnessRoot, loadSettings, runQuery } from '../bridge.mjs';

const powershell=path.join(process.env.SystemRoot,'System32/WindowsPowerShell/v1.0/powershell.exe');
function inventory(root) {
  return Object.fromEntries(readdirSync(root,{recursive:true}).sort().filter(file=>statSync(path.join(root,file)).isFile())
    .map(file=>[file,createHash('sha256').update(readFileSync(path.join(root,file))).digest('hex')]));
}

test('SDK stdio: tres consultas, paridade, limites, cancelamento e nenhuma escrita', {timeout:180000}, async t => {
  const fixture=JSON.parse(execFileSync(powershell,['-NoProfile','-File',path.join(harnessRoot,'mcp/issues/tests/fixture.ps1')],{encoding:'utf8',env:{...process.env,PSModulePath:path.join(path.dirname(powershell),'Modules')},timeout:90000,maxBuffer:1024*1024}));
  const before=inventory(fixture.area);
  const settings=loadSettings(fixture.settings);
  const transport=new StdioClientTransport({command:process.execPath,args:[path.join(harnessRoot,'mcp/issues/server.mjs')],env:{...process.env,HARNESS_MCP_CONFIG:fixture.settings},stderr:'pipe'});
  let stderr=''; transport.stderr?.on('data',data=>{stderr+=data});
  const client=new Client({name:'harness-test',version:'1.0.0'});
  try { await client.connect(transport); } catch(error) { throw new Error(`${error.message}: ${stderr}`); }
  t.after(async()=>client.close());
  const call=(name,args)=>client.callTool({name,arguments:args});
  const tools=await client.listTools();
  assert.deepEqual(tools.tools.map(tool=>tool.name).sort(),['auditar_base','listar_issues','obter_issue']);
  assert.ok(tools.tools.every(tool=>tool.annotations.readOnlyHint && !tool.annotations.destructiveHint));

  const detail=await call('obter_issue',{ContextPath:fixture.plan,Id:fixture.id,Incident:138});
  assert.equal(detail.isError,false,JSON.stringify(detail));
  assert.deepEqual(detail.structuredContent,fixture.baseline);
  assert.deepEqual(JSON.parse(detail.content[0].text),detail.structuredContent);
  const audit=await call('auditar_base',{ContextPath:fixture.context});
  assert.equal(audit.isError,false,JSON.stringify(audit));
  const list=await call('listar_issues',{ContextPath:fixture.context,Text:'Hibernate'});
  assert.equal(list.isError,false,JSON.stringify(list));
  assert.ok(list.structuredContent.Paging.Total>0);
  const literal=await call('listar_issues',{ContextPath:fixture.context,Text:'ação "$(Write-Output atacado)"'});
  assert.equal(literal.isError,false,JSON.stringify(literal));
  assert.equal(literal.structuredContent.Paging.Total,0);
  const invalid=await call('auditar_base',{ContextPath:fixture.context,Root:fixture.root});
  assert.equal(invalid.isError,true);
  const denied=await call('auditar_base',{ContextPath:fixture.area+'-externo/contexto.json'});
  assert.equal(denied.structuredContent.Error.Code,'ACCESS_DENIED');
  const changed=await call('obter_issue',{ContextPath:fixture.plan,Id:fixture.id,ExpectedBasisSha256:'0'.repeat(64)});
  assert.equal(changed.structuredContent.Error.Code,'BASE_CHANGED');

  for (const [root,context,id] of [[fixture.manualRoot,fixture.manualPlan,'DEV-LOG'],[fixture.importRoot,fixture.importPlan,fixture.id]]) {
    const result=await runQuery({...settings,root},'obter_issue',{ContextPath:context,Id:id});
    assert.equal(result.Status,'OK',JSON.stringify(result));
  }
  const timeout=await runQuery({...settings,timeoutMs:1},'auditar_base',{ContextPath:fixture.context});
  assert.equal(timeout.Error.Code,'TIMEOUT');
  const controller=new AbortController();
  const pending=runQuery(settings,'auditar_base',{ContextPath:fixture.context},controller.signal);
  controller.abort();
  assert.equal((await pending).Error.Code,'CANCELLED');
  assert.deepEqual(inventory(fixture.area),before);
  await client.close();
  assert.equal(stderr,'');
});
