import test from 'node:test';
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { readFileSync, readdirSync, statSync, writeFileSync } from 'node:fs';
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
  const workspace=path.join(fixture.root,'projetos.code-workspace'), harnessConfig=path.join(fixture.root,'harness.json');
  const workspaceJson=JSON.stringify({folders:[{path:fixture.source}]}), harnessJson=JSON.stringify({schemaVersion:1,mta:{runsPath:fixture.run}});
  writeFileSync(workspace,workspaceJson); writeFileSync(harnessConfig,harnessJson);
  const dynamicConfig=path.join(fixture.root,'mcp-workspace.json');
  writeFileSync(dynamicConfig,JSON.stringify({root:fixture.root,allowedRoots:[fixture.root],workspacePath:workspace,harnessConfigPath:harnessConfig}));
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
  const unicode=await call('listar_issues',{ContextPath:fixture.context,Text:fixture.unicodeTitle});
  assert.equal(unicode.structuredContent.Paging.Total,1);
  assert.equal(unicode.structuredContent.Data.Items[0].Id,'DEV-LOG');
  assert.equal(unicode.structuredContent.Data.Items[0].Title,fixture.unicodeTitle);
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
  const dynamicClient=new Client({name:'workspace-test',version:'1.0.0'});
  const dynamicTransport=new StdioClientTransport({command:process.execPath,args:[path.join(harnessRoot,'mcp/issues/server.mjs')],env:{...process.env,HARNESS_MCP_CONFIG:dynamicConfig},stderr:'pipe'});
  let dynamicStderr=''; dynamicTransport.stderr?.on('data',data=>{dynamicStderr+=data});
  await dynamicClient.connect(dynamicTransport);
  const dynamicCall=(name,args={ContextPath:fixture.context})=>dynamicClient.callTool({name,arguments:args});
  try {
    for (const name of ['auditar_base','listar_issues','obter_issue']) {
      const args={ContextPath:fixture.context,...(name==='obter_issue'?{Id:fixture.id,Incident:138}:{})};
      const result=await dynamicCall(name,args);
      assert.equal(result.isError,false,JSON.stringify(result));
    }
    writeFileSync(workspace,JSON.stringify({folders:[]}));
    assert.equal((await dynamicCall('auditar_base')).structuredContent.Error.Code,'ACCESS_DENIED');
    writeFileSync(workspace,workspaceJson);
    assert.equal((await dynamicCall('auditar_base')).isError,false);
    writeFileSync(harnessConfig,JSON.stringify({schemaVersion:1,mta:{runsPath:fixture.run+'-outra-raiz'}}));
    assert.equal((await dynamicCall('auditar_base')).structuredContent.Error.Code,'ACCESS_DENIED');
    writeFileSync(harnessConfig,'{invalido');
    assert.equal((await dynamicCall('auditar_base')).structuredContent.Error.Code,'CONFIG_ERROR');
    writeFileSync(harnessConfig,harnessJson);
    assert.equal((await dynamicCall('auditar_base')).isError,false);
    const injected=await dynamicCall('auditar_base',{ContextPath:fixture.context,WorkspacePath:workspace});
    assert.equal(injected.isError,true);
  } finally {
    writeFileSync(workspace,workspaceJson); writeFileSync(harnessConfig,harnessJson);
    await dynamicClient.close();
  }
  assert.equal(dynamicStderr,'');
  assert.deepEqual(inventory(fixture.area),before);
  await client.close();
  assert.equal(stderr,'');
});
