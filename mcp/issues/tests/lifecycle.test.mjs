import test from 'node:test';
import assert from 'node:assert/strict';
import { EventEmitter } from 'node:events';
import { PassThrough } from 'node:stream';
import { runQuery } from '../bridge.mjs';

test('cancelamento so libera a consulta depois de close do filho', async()=>{
  const child=new EventEmitter();
  child.pid=123; child.stdin=new PassThrough(); child.stdout=new PassThrough(); child.stderr=new PassThrough();
  let killed=0, completed=false;
  child.kill=()=>{killed++; return true};
  const controller=new AbortController();
  const pending=runQuery({root:'C:/fixture',allowedRoots:['C:/fixture'],timeoutMs:1000},'auditar_base',{},controller.signal,()=>child);
  pending.then(()=>{completed=true});
  controller.abort();
  await new Promise(resolve=>setImmediate(resolve));
  assert.equal(killed,1);
  assert.equal(completed,false);
  child.emit('close',null);
  assert.equal((await pending).Error.Code,'CANCELLED');
});
