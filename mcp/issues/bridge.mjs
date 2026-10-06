import { spawn } from 'node:child_process';
import { readFileSync, existsSync, lstatSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import * as z from 'zod/v4';
import { outputSchema, queryError } from './contract.mjs';

export const harnessRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const bridgePath = path.join(harnessRoot, 'scripts/invocar-consulta-mcp.ps1');
const settingsSchema = z.strictObject({ root: z.string().min(1).optional(), allowedRoots: z.array(z.string().min(1)).min(1).max(100), timeoutMs: z.number().int().min(1000).max(120000).default(60000) });

export function loadSettings(configPath) {
  if (configPath !== undefined && !existsSync(configPath)) throw new Error('Arquivo de configuracao MCP nao encontrado: '+configPath);
  configPath ??= path.join(harnessRoot, 'config/mcp.local.json');
  const settings = settingsSchema.parse(existsSync(configPath) ? JSON.parse(readFileSync(configPath,'utf8').replace(/^\uFEFF/,'')) : { allowedRoots: [harnessRoot] });
  const root = path.resolve(harnessRoot, settings.root ?? '.');
  const allowedRoots = [root,...settings.allowedRoots.map(value => path.resolve(harnessRoot, value))];
  for (const root of allowedRoots) {
    if (!/^[A-Za-z]:[\\/]/.test(root) || root.slice(2).includes(':')) throw new Error('Raizes MCP devem ser caminhos locais, sem UNC/ADS.');
    for (let current=root; ; current=path.dirname(current)) {
      if (existsSync(current) && lstatSync(current).isSymbolicLink()) throw new Error('Raizes MCP nao podem conter junctions/links.');
      if (current === path.dirname(current)) break;
    }
  }
  // A raiz de dados e confiavel, configurada pelo desenvolvedor, nunca por uma tool.
  return { root, allowedRoots: [...new Set(allowedRoots)], timeoutMs: settings.timeoutMs };
}

export function runQuery(settings, action, args, signal, spawnProcess=spawn) {
  if (signal?.aborted) return Promise.resolve(queryError(action, 'CANCELLED', 'Consulta cancelada.'));
  return new Promise(resolve => {
    const executable = path.join(process.env.SystemRoot ?? 'C:\\Windows', 'System32/WindowsPowerShell/v1.0/powershell.exe');
    const env={...process.env,PSModulePath:path.join(path.dirname(executable),'Modules')};
    const child = spawnProcess(executable, ['-NoProfile','-NonInteractive','-File',bridgePath], { shell: false, windowsHide: true, cwd: harnessRoot, env, stdio: ['pipe','pipe','pipe'] });
    let stdout='', stderr='', size=0, completed=false, terminalResult=null;
    const finish = result => {
      if (completed) return;
      completed=true; clearTimeout(timer); signal?.removeEventListener('abort', cancel);
      resolve(result);
    };
    const stop = (code,message) => {
      if (terminalResult || completed) return;
      terminalResult=queryError(action,code,message);
      clearTimeout(timer);
      if (!child.kill() && child.exitCode === null && child.signalCode === null) {
        terminalResult=queryError(action,'RUNTIME_ERROR','Nao foi possivel encerrar o subprocesso; aguardando sua saida.');
      }
      // O slot permanece ocupado ate close: kill nao comprova encerramento.
    };
    const cancel = () => stop('CANCELLED','Consulta cancelada.');
    const timer = setTimeout(() => stop('TIMEOUT','Consulta excedeu o tempo configurado.'), settings.timeoutMs);
    signal?.addEventListener('abort',cancel,{once:true});
    if (signal?.aborted) cancel();
    child.stdout.setEncoding('utf8'); child.stderr.setEncoding('utf8');
    child.stdout.on('data', data => {
      size+=Buffer.byteLength(data,'utf8');
      if (size>256*1024+2) stop('LIMIT_EXCEEDED','Resposta do subprocesso excedeu o limite.');
      else stdout+=data;
    });
    child.stderr.on('data', data => { if (stderr.length<1024) stderr=(stderr+data).slice(0,1024); });
    child.on('error', () => {
      terminalResult=queryError(action,'RUNTIME_ERROR','Falha ao iniciar ou encerrar Windows PowerShell 5.1.');
      if (!child.pid) finish(terminalResult);
    });
    child.stdin.on('error', () => {}); // Falha de processo e informada por error/close.
    child.on('close', code => {
      if (completed) return;
      if (terminalResult) { finish(terminalResult); return; }
      try {
        const result=outputSchema.parse(JSON.parse(stdout));
        if ((result.Status==='OK' && code!==0) || (result.Status==='ERROR' && code!==1)) throw new Error('Exit code divergente');
        finish(result);
      } catch { finish(queryError(action,'RUNTIME_ERROR',stderr || 'Subprocesso nao retornou JSON valido. Confira politica de scripts e instalacao do harness.')); }
    });
    child.stdin.end(JSON.stringify({ Action: action, Root: settings.root, AllowedRoots: settings.allowedRoots, Arguments: args }), 'utf8');
  });
}
