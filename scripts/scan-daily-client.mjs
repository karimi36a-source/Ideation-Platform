// M16.16: run after a successful production build. Never print matched content.
import {existsSync,readdirSync,readFileSync} from 'node:fs';
import {dirname,join,resolve} from 'node:path';
import ts from 'typescript';
const root=resolve(import.meta.dirname,'..');
for(const name of ['.env','.env.local','.env.production','.env.production.local','.env.test.local'])if(existsSync(join(root,name)))process.loadEnvFile(join(root,name));
const secrets=Object.entries(process.env).filter(([key,value])=>!key.startsWith('NEXT_PUBLIC_')&&/(SECRET|SERVICE_ROLE|PASSWORD|TOKEN|API_KEY|DATABASE_URL)/i.test(key)&&value&&value.length>=8).map(([,value])=>value);
let failed=Object.keys(process.env).some(key=>/^NEXT_PUBLIC_.*DAILY.*(?:KEY|SECRET|TOKEN|CREDENTIAL)/i.test(key)),count=0;
function walk(dir,visit){for(const entry of readdirSync(dir,{withFileTypes:true})){const file=join(dir,entry.name);if(entry.isDirectory())walk(file,visit);else visit(file);}}
const output=join(root,'.next/static');if(!existsSync(output))throw Error('Production client output missing');
walk(output,file=>{count++;const text=readFileSync(file,'utf8');if(file.endsWith('.map')||secrets.some(secret=>text.includes(secret))||/DAILY_API_KEY|DailyLiveClassroomProvider|createLiveClassroomProvider|api\.daily\.co\/v1|m168_mock_server_secret/.test(text))failed=true;});
const sources=new Map();
for(const folder of ['app','components','features','hooks','lib'])if(existsSync(join(root,folder)))walk(join(root,folder),file=>{if(/\.[jt]sx?$/.test(file))sources.set(file,readFileSync(file,'utf8'));});
function localImport(from,specifier){const base=specifier.startsWith('@/')?join(root,specifier.slice(2)):specifier.startsWith('.')?resolve(dirname(from),specifier):null;return base&&[base,...['.ts','.tsx','.js','.jsx','/index.ts','/index.tsx'].map(ext=>base+ext)].find(file=>sources.has(file));}
const visited=new Set();
function visit(file){
 if(visited.has(file))return;visited.add(file);const text=sources.get(file);
 // Server Action imports compile to RPC stubs; emitted client code is scanned above.
 if(/^\s*['"]use server['"]/.test(text))return;
 if(/DAILY_API_KEY|api\.daily\.co\/v1/.test(text))failed=true;
 const parsed=ts.createSourceFile(file,text,ts.ScriptTarget.Latest,true);
 for(const statement of parsed.statements){
  if(!ts.isImportDeclaration(statement)&&!ts.isExportDeclaration(statement))continue;
  if(statement.isTypeOnly||statement.importClause?.isTypeOnly||!statement.moduleSpecifier||!ts.isStringLiteral(statement.moduleSpecifier))continue;
  const bindings=statement.importClause?.namedBindings;
  if(!statement.importClause?.name&&bindings&&ts.isNamedImports(bindings)&&bindings.elements.every(item=>item.isTypeOnly))continue;
  const next=localImport(file,statement.moduleSpecifier.text);if(next)visit(next);
 }
}
for(const [file,text] of sources){
 if(/^\s*['"]use client['"]/.test(text))visit(file);
 if(/DAILY_API_KEY|api\.daily\.co\/v1/.test(text)&&!text.match(/import\s*['"]server-only['"]/))failed=true;
 if(/NEXT_PUBLIC_\w*DAILY\w*(?:KEY|SECRET|TOKEN|CREDENTIAL)/i.test(text))failed=true;
}
console.log(`M16.16 Daily management credential/client-import/source-map scan ${failed?'FAIL':'PASS'} (${count} client files)`);
process.exitCode=failed?1:0;
