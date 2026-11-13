import assert from "node:assert/strict";
import {readFileSync,readdirSync} from "node:fs";
import {join,relative,resolve} from "node:path";
import {fileURLToPath} from "node:url";
import ts from "typescript";

/** Structural boundary guard, not an AI implementation or source classifier. */
export function scanEvidenceCreationPaths(root){
 const references=[];let inserts=0;let rpcCalls=0;let patentRpcCalls=0;
 function visit(directory){for(const item of readdirSync(directory,{withFileTypes:true})){
  const file=join(directory,item.name);if(item.isDirectory()){visit(file);continue;}
  if(!/\.(?:ts|tsx|mjs|mts|sql)$/.test(item.name))continue;
  const path=relative(root,file).replaceAll("\\","/");const text=readFileSync(file,"utf8");
  const matches=/linkPatentToEvidence\b|link_patent_to_evidence\b|createEvidence\b|create_evidence\b|insert\s+into\s+(?:public\.)?["']?evidence\b/i.test(text);
  if(matches)references.push({path,category:path.startsWith("tests/")||path.startsWith("scripts/")?"test/validation":path.startsWith("supabase/")?"migration":(path.startsWith("features/evidence/")||path==="features/patents/evidence.ts"||path==="features/patents/workspace-actions.ts")?"approved Evidence implementation":path==="lib/db/database.types.ts"?"typed RPC contract":"unexpected"});
  if(path.startsWith("supabase/migrations/")){
   const writes=[...text.matchAll(/insert\s+into\s+(?:public\.)?"?evidence"?\s*\(/gi)];inserts+=writes.length;
   if(writes.length)assert(["supabase/migrations/20261011020000_create_evidence_rpc.sql","supabase/migrations/20261011120000_patent_evidence.sql"].includes(path),`Unexpected Evidence insert: ${path}`);
  }
  if(!/^(?:features|lib|app)\//.test(path))continue;
  const source=ts.createSourceFile(path,text,ts.ScriptTarget.Latest,true,path.endsWith("tsx")?ts.ScriptKind.TSX:ts.ScriptKind.TS);
  function inspect(node){
   if(ts.isCallExpression(node)&&ts.isPropertyAccessExpression(node.expression)){
    const method=node.expression.name.text;const argument=node.arguments[0];
    if(method==="rpc"&&argument&&ts.isStringLiteral(argument)&&argument.text==="link_patent_to_evidence"){patentRpcCalls++;assert.equal(path,"features/patents/evidence.ts",`Unexpected Patent Evidence RPC: ${path}`);}
    if(method==="rpc"&&argument&&ts.isStringLiteral(argument)&&argument.text==="create_evidence"){
     rpcCalls++;assert.equal(path,"features/evidence/create.ts",`Generic save invokes Evidence RPC: ${path}`);
    }
    if(method==="from"&&argument&&ts.isStringLiteral(argument)&&argument.text==="evidence"){
     let chain=node;while(chain.parent&&(ts.isPropertyAccessExpression(chain.parent)||ts.isCallExpression(chain.parent)))chain=chain.parent;
     assert(!/\.(?:insert|upsert)\s*\(/.test(chain.getText(source)),`Direct client Evidence insert: ${path}`);
    }
   }
   ts.forEachChild(node,inspect);
  }
  inspect(source);
 }}
 for(const directory of ["features","lib","app","supabase/migrations","scripts","tests"])visit(join(root,directory));
 assert.equal(inserts,2,"Exactly the two approved source-backed production SQL Evidence inserts");
 assert.equal(patentRpcCalls,1,"Exactly one explicit Patent Evidence transport");
 assert.equal(rpcCalls,1,"Exactly one explicit server creation transport");
 assert.deepEqual(references.filter(r=>r.category==="unexpected"),[],"Unexpected Evidence creation reference");
 console.log(JSON.stringify({references,inserts,rpcCalls,patentRpcCalls}));
 console.log("M12.5 repository Evidence creation-path scan PASS (two approved source-backed RPCs/inserts; no generic routing)");
 return references;
}
if(process.argv[1]&&resolve(process.argv[1])===fileURLToPath(import.meta.url))scanEvidenceCreationPaths(fileURLToPath(new URL("../",import.meta.url)));
