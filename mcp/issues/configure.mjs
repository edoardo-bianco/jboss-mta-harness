import { existsSync, readFileSync, writeFileSync, mkdirSync, realpathSync, lstatSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { isDeepStrictEqual } from 'node:util';
import { parse as parseToml } from 'smol-toml';
import { harnessRoot } from './bridge.mjs';

const names=['auditar_base','listar_issues','obter_issue'];
function assertNoLinks(file) {
  for (let current=file; ; current=path.dirname(current)) {
    if (existsSync(current) && lstatSync(current).isSymbolicLink()) throw new Error('Configuracao nao segue links/junctions: '+file);
    if (current===path.dirname(current)) break;
  }
}

// Somente configuracao do projeto. O executavel e escolhido ao chamar este script.
export function configureClients(root,nodePath) {
  const entry=path.join(root,'mcp/issues/server.mjs');
  const config=path.join(root,'config/mcp.local.json');
  const codex=path.join(root,'.codex/config.toml');
  const vscode=path.join(root,'.vscode/mcp.json');
  for (const file of [config,codex,vscode]) assertNoLinks(file);
  const server={type:'stdio',command:nodePath,args:[entry],env:{HARNESS_MCP_CONFIG:config}};
  const section='\n[mcp_servers.harnessIssues]\n'+
    `command = ${JSON.stringify(nodePath)}\nargs = [${JSON.stringify(entry)}]\n`+
    'startup_timeout_sec = 20\ntool_timeout_sec = 130\n'+
    `enabled_tools = ${JSON.stringify(names)}\n`+
    `[mcp_servers.harnessIssues.env]\nHARNESS_MCP_CONFIG = ${JSON.stringify(config)}\n`;
  const oldCodex=existsSync(codex) ? readFileSync(codex,'utf8') : '';
  if (/harnessIssues/.test(oldCodex) && !oldCodex.includes(section.trim())) {
    throw new Error('harnessIssues ja configurado no Codex com valores diferentes; revise a secao existente.');
  }
  const newCodex=oldCodex.includes(section.trim()) ? oldCodex : oldCodex+section;
  try { parseToml(newCodex.replace(/^\uFEFF/,''),{integersAsBigInt:'asNeeded'}); }
  catch { throw new Error('Configuracao TOML nao permite acrescentar harnessIssues dessa forma. Arquivos preservados; revise a tabela mcp_servers manualmente.'); }
  let json=existsSync(vscode) ? JSON.parse(readFileSync(vscode,'utf8').replace(/^\uFEFF/,'')) : {};
  if (!json || Array.isArray(json) || typeof json!=='object' || (json.servers && (typeof json.servers!=='object' || Array.isArray(json.servers)))) {
    throw new Error('mcp.json exige objeto servers. Arquivo preservado.');
  }
  json.servers ??= {};
  if (json.servers.harnessIssues && !isDeepStrictEqual(json.servers.harnessIssues,server)) {
    throw new Error('harnessIssues ja configurado no VS Code com valores diferentes; revise a entrada existente.');
  }
  json.servers.harnessIssues=server;
  const outputs=[[codex,newCodex],[vscode,JSON.stringify(json,null,2)+'\n']];
  if (!existsSync(config)) outputs.push([config,JSON.stringify({allowedRoots:['.'],timeoutMs:60000},null,2)+'\n']);
  // Todos os conflitos sao detectados antes da primeira gravacao.
  for (const [file,content] of outputs) {
    mkdirSync(path.dirname(file),{recursive:true});
    if (!existsSync(file) || readFileSync(file,'utf8')!==content) writeFileSync(file,content,'utf8');
  }
  return {codex,vscode,config,nodePath};
}

if (process.argv[1] && path.resolve(process.argv[1])===fileURLToPath(import.meta.url)) {
  if (process.platform!=='win32' || Number(process.versions.node.split('.')[0])<20) {
    throw new Error('Use Windows com Node 20 ou superior. A CLI PowerShell permanece disponivel.');
  }
  const result=configureClients(harnessRoot,realpathSync(process.execPath));
  console.log(JSON.stringify(result,null,2));
  console.log('Inclua as pastas de fontes e MTA em allowedRoots de config/mcp.local.json. Reinicie os clientes e confira as tres tools.');
}
