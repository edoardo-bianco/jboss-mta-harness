import { McpServer } from '@modelcontextprotocol/server';
import { StdioServerTransport } from '@modelcontextprotocol/server/stdio';
import { descriptions, toolSchemas, outputSchema, queryError } from './contract.mjs';
import { loadSettings, runQuery } from './bridge.mjs';

const settings=loadSettings(process.env.HARNESS_MCP_CONFIG);
const server=new McpServer({ name: 'harnessIssues', version: '1.0.0' });
const active=new Map();
let closing=false;
for (const [name,inputSchema] of Object.entries(toolSchemas)) {
  server.registerTool(name, {
    description: descriptions[name], inputSchema, outputSchema,
    annotations: { readOnlyHint: true, destructiveHint: false, idempotentHint: true, openWorldHint: false },
  }, async (args, context) => {
    const controller=new AbortController();
    const cancel=() => controller.abort();
    const signal=context.mcpReq.signal;
    signal.addEventListener('abort',cancel,{once:true});
    if (signal.aborted) cancel();
    let result;
    try {
      if (closing) result=queryError(name,'CANCELLED','Servidor encerrando.');
      else if (active.size>=2) result=queryError(name,'BUSY','Duas consultas em andamento; aguarde antes de repetir.');
      else {
        const pending=runQuery(settings,name,args,controller.signal);
        active.set(controller,pending);
        result=await pending;
      }
    } finally { active.delete(controller); signal.removeEventListener('abort',cancel); }
    return { structuredContent: result, content: [{type:'text',text:JSON.stringify(result)}], isError: result.Status==='ERROR' };
  });
}
await server.connect(new StdioServerTransport());
async function shutdown() {
  if (closing) return;
  closing=true;
  for (const controller of active.keys()) controller.abort();
  await Promise.allSettled(active.values());
  await server.close();
  process.stdin.pause();
}
server.server.onclose=shutdown;
process.stdin.on('end',shutdown);
process.on('SIGINT',shutdown);
process.on('SIGTERM',shutdown);
