import {readFileSync,readdirSync} from 'node:fs';
import {join,relative} from 'node:path';
import {expect,it} from 'vitest';
import ts from 'typescript';
const root=process.cwd();
function files(dir:string):string[]{return readdirSync(dir,{withFileTypes:true}).flatMap(e=>e.isDirectory()?files(join(dir,e.name)):/\.(ts|tsx|sql)$/.test(e.name)?[join(dir,e.name)]:[]);}
const production=[...files(join(root,'features')),...files(join(root,'app')),...files(join(root,'lib'))];
const deferred=/(compare.*patent|patent.*compar|noveltyScore|patentabilityScore|infringementOpinion|freedomToOperateConclusion)/i;
// Generic AI execution is accepted from M14.11; the Patent domain remains
// prohibited from calling it (separate outbound-boundary assertion below).
it('M12.17 has no production patent-comparison implementation, call, or route',()=>{
 const found:string[]=[];
 for(const file of production){
  const path=relative(root,file).replaceAll('\\','/');const source=ts.createSourceFile(path,readFileSync(file,'utf8'),ts.ScriptTarget.Latest,true,file.endsWith('tsx')?ts.ScriptKind.TSX:ts.ScriptKind.TS);
  const visit=(node:ts.Node)=>{if(ts.isIdentifier(node)&&deferred.test(node.text))found.push(path+':'+node.text);ts.forEachChild(node,visit);};visit(source);
  expect(path).not.toMatch(/(?:patent.*compar|compar.*patent)/i);
 }
 expect(found).toEqual([]);
});
it('M12.17 has no comparison persistence or comparison/generation RPC; M14.1 only adds AI result storage',()=>{
 for(const file of files(join(root,'supabase/migrations')))expect(readFileSync(file,'utf8')).not.toMatch(/create\s+(?:unlogged\s+)?table\s+(?:if\s+not\s+exists\s+)?(?:public\.)?["']?patent_comparisons\b/i);
 const types=readFileSync(join(root,'lib/db/database.types.ts'),'utf8');expect(types).not.toMatch(/\b(?:patent_comparisons|compare_patent_with_project|comparePatentWithProject|run_ai_task)\s*:/);
});
it('M12.17 Patent domain has only accepted user-scoped RPCs and no outbound comparison provider',()=>{
 const rpcs:string[]=[];const outbound:string[]=[];
 for(const file of files(join(root,'features/patents'))){
  const source=ts.createSourceFile(file,readFileSync(file,'utf8'),ts.ScriptTarget.Latest,true,file.endsWith('tsx')?ts.ScriptKind.TSX:ts.ScriptKind.TS);
  const visit=(node:ts.Node)=>{
   if(ts.isCallExpression(node)){
    if(ts.isIdentifier(node.expression)&&['fetch','runAiTask'].includes(node.expression.text))outbound.push(node.expression.text);
    if(ts.isPropertyAccessExpression(node.expression)){
     if(['fetch','generateText','generateContent'].includes(node.expression.name.text))outbound.push(node.expression.getText(source));
     if(node.expression.name.text==='rpc'&&node.arguments[0]&&ts.isStringLiteral(node.arguments[0]))rpcs.push(node.arguments[0].text);
    }
   }
   if(ts.isImportDeclaration(node)&&ts.isStringLiteral(node.moduleSpecifier)&&/openai|anthropic|generative-ai|^ai$/.test(node.moduleSpecifier.text))outbound.push(node.moduleSpecifier.text);
   ts.forEachChild(node,visit);
  };visit(source);
 }
 expect(outbound).toEqual([]);
 expect([...new Set(rpcs)].sort()).toEqual(['can_read_development_project','create_patent_record','create_patent_search_log','link_patent_to_evidence','save_patent_reading_framework']);
});

