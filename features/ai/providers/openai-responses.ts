import 'server-only';
import {z} from 'zod';
import {aiUsageModelProfileSchema} from '../usage-schema';
import {aiGenerateInputSchema,type AiGenerateInput,type AiProvider,type AiProviderResult,type AiProviderErrorCode} from '../provider';

const configSchema=z.strictObject({apiKey:z.string().trim().min(1),models:z.partialRecord(aiUsageModelProfileSchema,z.string().regex(/^[a-zA-Z0-9._:-]+$/)),timeoutMs:z.number().int().min(1).max(300000).default(60000)});
const count=z.number().int().nonnegative().max(Number.MAX_SAFE_INTEGER);
const responseSchema=z.object({id:z.string().regex(/^resp_[a-zA-Z0-9_-]{1,200}$/),status:z.enum(['completed','incomplete','failed','cancelled','queued','in_progress']),error:z.unknown().optional(),output:z.array(z.object({type:z.string(),role:z.string().optional(),content:z.array(z.discriminatedUnion('type',[
 z.object({type:z.literal('output_text'),text:z.string()}),z.object({type:z.literal('refusal'),refusal:z.string()}),
])).optional()})),usage:z.object({input_tokens:count,output_tokens:count}).nullable().optional()});

/** Server construction only. No endpoint override, routing, retries, logging or persistence.
 * Transport follows https://developers.openai.com/api/docs/guides/structured-outputs?api-mode=responses
 * Model mapping is supplied by trusted configuration, not generate() callers.
 */
export class OpenAiResponsesProvider implements AiProvider {
 #config:ReturnType<typeof configSchema.safeParse>;
 constructor(config:unknown,private readonly transport:typeof fetch=fetch){this.#config=configSchema.safeParse(config);}
 async generate(input:AiGenerateInput):Promise<AiProviderResult>{
  const started=performance.now();
  const base=():AiProviderResult=>({success:false,text:null,structured:null,usage:{inputUsage:null,outputUsage:null},latencyMs:Math.max(0,Math.round(performance.now()-started)),reference:null,error:null});
  const fail=(code:AiProviderErrorCode,retryable=false):AiProviderResult=>({...base(),error:{code,retryable}});
  const parsed=aiGenerateInputSchema.safeParse(input);
  if(!parsed.success)return fail('INVALID_INPUT');
  if(!this.#config.success)return fail('CONFIGURATION');
  const data=parsed.data,config=this.#config.data,model=config.models[data.modelProfile];
  if(!model)return fail('CONFIGURATION');
  const controller=new AbortController();
  let timer:ReturnType<typeof setTimeout>|undefined;
  try{
   // Race also bounds injected transports that fail to honor AbortSignal.
   const work=async():Promise<AiProviderResult>=>{
    const response=await this.transport('https://api.openai.com/v1/responses',{method:'POST',redirect:'error',cache:'no-store',signal:controller.signal,headers:{Authorization:`Bearer ${config.apiKey}`,'Content-Type':'application/json'},body:JSON.stringify({model,instructions:data.instructions,input:data.input,store:false,stream:false,...(data.metadata?{metadata:data.metadata}:{}),...(data.outputSchema?{text:{format:{type:'json_schema',name:'fici_output',schema:data.outputSchema,strict:true}}}:{})})});
    if(!response.ok){
     // Never read, log or forward provider error bodies or headers.
     if(response.status===401||response.status===403)return fail('AUTHENTICATION');
     if(response.status===429)return fail('RATE_LIMIT',true);
     if(response.status===408||response.status===504)return fail('TIMEOUT',true);
     if(response.status>=500)return fail('UNAVAILABLE',true);
     if(response.status===400||response.status===404||response.status===422)return fail('CONFIGURATION');
     return fail('UNKNOWN');
    }
    let raw:unknown;
    try{raw=await response.json();}catch{return fail('MALFORMED_RESPONSE');}
    const decoded=responseSchema.safeParse(raw);
    if(!decoded.success)return fail('MALFORMED_RESPONSE');
    const result=decoded.data;
    const normalized={...base(),reference:{provider:'openai',responseId:result.id},usage:{inputUsage:result.usage?.input_tokens??null,outputUsage:result.usage?.output_tokens??null}};
    if(result.status!=='completed'||result.error)return {...normalized,error:{code:result.status==='incomplete'?'INCOMPLETE':'UNAVAILABLE',retryable:result.status!=='incomplete'}};
    const messages=result.output.filter(item=>item.type==='message');
    if(messages.some(item=>item.role!=='assistant'||!item.content))return fail('MALFORMED_RESPONSE');
    const content=messages.flatMap(item=>item.content??[]);
    if(content.some(item=>item.type==='refusal'))return {...normalized,error:{code:'REFUSED',retryable:false}};
    const text=content.filter(item=>item.type==='output_text').map(item=>item.text).join('');
    if(!text)return fail('MALFORMED_RESPONSE');
    let structured:unknown=null;
    if(data.outputSchema){try{structured=JSON.parse(text);}catch{return fail('MALFORMED_RESPONSE');}}
    // Parsing transports JSON; schema conformance/output policy belongs to M14.12.
    return {...normalized,success:true,text,structured};
   };
   return await Promise.race([work(),new Promise<AiProviderResult>(resolve=>{timer=setTimeout(()=>{controller.abort();resolve(fail('TIMEOUT',true));},config.timeoutMs);})]);
  }catch(error){
   if(controller.signal.aborted)return fail('TIMEOUT',true);
   if(error instanceof TypeError)return fail('NETWORK',true);
   return fail('UNKNOWN');
  }finally{if(timer)clearTimeout(timer);}
 }
}


