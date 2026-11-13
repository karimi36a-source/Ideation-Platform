import {expect,it,vi} from 'vitest';
import {readFileSync,readdirSync,existsSync} from 'node:fs';
import path from 'node:path';
import ts from 'typescript';
vi.mock('server-only',()=>({}));
import {OpenAiResponsesProvider} from '@/features/ai/providers/openai-responses';
import type {AiProvider,AiGenerateInput} from '@/features/ai/provider';
const input:AiGenerateInput={modelProfile:'AI_STANDARD',instructions:'FICI rules',input:'Selected content'};
const config={apiKey:'mock-private-credential',models:{AI_STANDARD:'test-model'}};
const body={id:'resp_test',status:'completed',output:[{type:'message',role:'assistant',content:[{type:'output_text',text:'Hello'}]}],usage:{input_tokens:12,output_tokens:3},private_field:'must not return'};
const schema={type:'object',properties:{answer:{type:'string'}},required:['answer'],additionalProperties:false};
function setup(value:unknown=body,status=200){const transport=vi.fn<typeof fetch>().mockResolvedValue(new Response(JSON.stringify(value),{status}));return {transport,provider:new OpenAiResponsesProvider(config,transport)};}
it('normalizes text, safe references, usage, latency and status without raw fields',async()=>{
 const {provider,transport}=setup();const result=await provider.generate(input);
 expect(result).toMatchObject({success:true,text:'Hello',structured:null,reference:{provider:'openai',responseId:'resp_test'},usage:{inputUsage:12,outputUsage:3},error:null});
 expect(result.latencyMs).toBeGreaterThanOrEqual(0);expect(JSON.stringify(result)).not.toMatch(/must not return|mock-private/);
 const [url,request]=transport.mock.calls[0];expect(url).toBe('https://api.openai.com/v1/responses');expect(request).toMatchObject({redirect:'error',cache:'no-store'});
 expect(JSON.parse(request!.body as string)).toEqual({model:'test-model',instructions:input.instructions,input:input.input,store:false,stream:false});
});
it('transports structured intent and normalizes JSON without implementing output policy',async()=>{
 const {provider,transport}=setup({...body,output:[{type:'message',role:'assistant',content:[{type:'output_text',text:'{"answer":"yes"}'}]}]});
 expect((await provider.generate({...input,outputSchema:schema,metadata:{operation:'GENERATE_STRUCTURED'}})).structured).toEqual({answer:'yes'});
 expect(JSON.parse(transport.mock.calls[0][1]!.body as string).text.format).toEqual({type:'json_schema',name:'fici_output',schema,strict:true});
});
it.each([[401,'AUTHENTICATION'],[403,'AUTHENTICATION'],[429,'RATE_LIMIT'],[408,'TIMEOUT'],[504,'TIMEOUT'],[503,'UNAVAILABLE'],[400,'CONFIGURATION'],[404,'CONFIGURATION'],[422,'CONFIGURATION'],[418,'UNKNOWN']])('normalizes HTTP %s without reading its error body',async(status,code)=>{
 const {provider}=setup({},Number(status));
 const result=await provider.generate(input);expect(result.error?.code).toBe(code);expect(result.success).toBe(false);expect(result.text).toBeNull();
});
it.each([null,{}, {...body,id:'private path'}, {...body,usage:{input_tokens:-1,output_tokens:2}}, {...body,output:[]}, {...body,output:[{type:'message',role:'user',content:[{type:'output_text',text:'not assistant'}]}]}])('rejects malformed provider response',async value=>{expect((await setup(value).provider.generate(input)).error?.code).toBe('MALFORMED_RESPONSE');});
it('handles malformed JSON response',async()=>{const transport=vi.fn<typeof fetch>().mockResolvedValue(new Response('not JSON'));expect((await new OpenAiResponsesProvider(config,transport).generate(input)).error?.code).toBe('MALFORMED_RESPONSE');});
it('rejects malformed structured output',async()=>{expect((await setup().provider.generate({...input,outputSchema:schema})).error?.code).toBe('MALFORMED_RESPONSE');});
it('preserves unknown usage as null',async()=>{expect((await setup({...body,usage:null}).provider.generate(input)).usage).toEqual({inputUsage:null,outputUsage:null});});
it.each(['incomplete','failed','cancelled'])('never treats %s as success',async status=>{expect((await setup({...body,status}).provider.generate(input)).success).toBe(false);});
it('normalizes refusal without returning provider refusal text',async()=>{const r=await setup({...body,output:[{type:'message',role:'assistant',content:[{type:'refusal',refusal:'private raw refusal'}]}]}).provider.generate(input);expect(r.error?.code).toBe('REFUSED');expect(JSON.stringify(r)).not.toContain('private raw');});
it.each([new TypeError('secret network details'),new Error('private path and key')])('sanitizes thrown errors',async error=>{const transport=vi.fn<typeof fetch>().mockRejectedValue(error);const r=await new OpenAiResponsesProvider(config,transport).generate(input);expect(r.error?.code).toBe(error instanceof TypeError?'NETWORK':'UNKNOWN');expect(JSON.stringify(r)).not.toMatch(/secret network|private path/);});
it('times out transport even when signal is ignored',async()=>{const transport=vi.fn<typeof fetch>().mockImplementation(()=>new Promise(()=>{}));const r=await new OpenAiResponsesProvider({...config,timeoutMs:5},transport).generate(input);expect(r.error).toEqual({code:'TIMEOUT',retryable:true});expect(transport.mock.calls[0][1]!.signal!.aborted).toBe(true);});
it.each(['apiKey','endpoint','model','userId','workspaceId','context','timeoutMs'])('rejects caller override %s without transport',async key=>{const {provider,transport}=setup();expect((await provider.generate({...input,[key]:'spoof'})).error?.code).toBe('INVALID_INPUT');expect(transport).not.toHaveBeenCalled();});
it('rejects private metadata and malformed schemas',async()=>{const {provider,transport}=setup();for(const value of [{...input,metadata:{userId:'private'}},{...input,outputSchema:{type:'invalid'}},{...input,modelProfile:'model-name'}])expect((await provider.generate(value as AiGenerateInput)).error?.code).toBe('INVALID_INPUT');expect(transport).not.toHaveBeenCalled();});
it.each([{}, {...config,apiKey:''},{...config,endpoint:'https://untrusted.example'},{...config,models:{}},{...config,timeoutMs:0}])('fails closed on missing/invalid server configuration',async value=>{const transport=vi.fn<typeof fetch>();expect((await new OpenAiResponsesProvider(value,transport).generate(input)).error?.code).toBe('CONFIGURATION');expect(transport).not.toHaveBeenCalled();});
it('allows a replacement provider through the same business contract',async()=>{const replacement:AiProvider={generate:async()=>({success:true,text:'mock',structured:null,usage:{inputUsage:null,outputUsage:null},latencyMs:0,reference:null,error:null})};const consumer=(provider:AiProvider)=>provider.generate(input);expect((await consumer(replacement)).text).toBe('mock');expect(readFileSync('features/ai/provider.ts','utf8')).not.toMatch(/openai|api\.openai|responses\/|test-model/i);});
it('keeps privileged execution outside every transitive client import graph',()=>{
 const roots=['app','components','features','lib'];
 const files:string[]=[];function walk(dir:string){if(!existsSync(dir))return;for(const item of readdirSync(dir,{withFileTypes:true})){const p=path.join(dir,item.name);if(item.isDirectory())walk(p);else if(/\.[cm]?[jt]sx?$/.test(p))files.push(path.resolve(p));}}roots.forEach(walk);
 function visit(file:string,seen:Set<string>){if(seen.has(file))return;seen.add(file);const source=readFileSync(file,'utf8');if(/^\s*['\" ]use server['\" ]/m.test(source))return;expect(source,file).not.toMatch(/import\s*['"]server-only['"]|api\.openai\.com|from\s*['"]openai(?:\/|['"])/);
 for(const imp of ts.createSourceFile(file,source,ts.ScriptTarget.Latest,true).statements){if(!ts.isImportDeclaration(imp)||!ts.isStringLiteral(imp.moduleSpecifier)||imp.importClause?.isTypeOnly)continue;if(imp.importClause?.namedBindings&&ts.isNamedImports(imp.importClause.namedBindings)&&!imp.importClause.name&&imp.importClause.namedBindings.elements.every(e=>e.isTypeOnly))continue;const s=imp.moduleSpecifier.text;if(!s.startsWith('.')&&!s.startsWith('@/'))continue;const base=s.startsWith('@/')?path.resolve(s.slice(2)):path.resolve(path.dirname(file),s);const resolved=['','.ts','.tsx','.js','/index.ts','/index.tsx'].map(x=>base+x).find(x=>files.includes(x));if(resolved)visit(resolved,seen);}}
 for(const file of files)if(/^\s*['"]use client['"]/m.test(readFileSync(file,'utf8')))visit(file,new Set());
 expect(readFileSync('features/ai/providers/openai-responses.ts','utf8')).toMatch(/^import 'server-only';/);
});



