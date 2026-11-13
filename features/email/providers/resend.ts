import 'server-only';
import {z} from 'zod';
import {emailSendSchema,type EmailProvider,type EmailSendInput,type EmailResult,type EmailErrorCode} from '../provider';
import {createEmailTemplateRegistry,type EmailTemplateDefinition} from '../templates';
const origin=z.string().refine(value=>{try{const u=new URL(value);return u.origin===value&&!u.username&&!u.password&&(u.protocol==='https:'||(u.protocol==='http:'&&['localhost','127.0.0.1','[::1]'].includes(u.hostname)));}catch{return false;}});
const configuration=z.strictObject({apiKey:z.string().trim().min(1).refine(v=>!/[\r\n]/.test(v)),from:z.email().max(254),siteOrigin:origin,timeoutMs:z.number().int().min(1).max(60000).default(10000)});
const responseSchema=z.object({id:z.uuid()});
/** Official POST /emails transport only. No endpoint override, provider SDK,
 * logging, retries, domain imports, database access or delivery policy.
 * https://resend.com/docs/api-reference/emails/send-email */
export class ResendEmailProvider implements EmailProvider {
 #configuration:ReturnType<typeof configuration.safeParse>;
 #render:ReturnType<typeof createEmailTemplateRegistry>|null=null;
 #transport:typeof fetch;
 constructor(config:unknown,templates:readonly EmailTemplateDefinition[],transport:typeof fetch=fetch){
  this.#configuration=configuration.safeParse(config);this.#transport=transport;
  try{this.#render=createEmailTemplateRegistry(templates);}catch{/* Invalid trusted configuration fails closed on send. */}
 }
 async send(input:EmailSendInput):Promise<EmailResult>{
  const fail=(code:EmailErrorCode,retryable=false):EmailResult=>({success:false,error:{code,message:'Email delivery unavailable.',retryable}});
  const parsed=emailSendSchema.safeParse(input);if(!parsed.success)return fail('INVALID_INPUT');
  if(!this.#configuration.success||!this.#render)return fail('CONFIGURATION');
  const config=this.#configuration.data,controller=new AbortController();let timer:ReturnType<typeof setTimeout>|undefined;
  try{
   const rendered=this.#render(parsed.data.template,parsed.data.variables);if(!rendered)return fail('INVALID_INPUT');
   const text=rendered.text+(rendered.relativePath?'\n\n'+new URL(rendered.relativePath,config.siteOrigin).href:'');
   const payload={from:config.from,to:[parsed.data.to],subject:rendered.subject,text};
   // Never allow a configured credential to escape through reflected input,
   // trusted rendering, envelope fields, idempotency headers, or a response ID.
   if(JSON.stringify(parsed.data).includes(config.apiKey)||JSON.stringify(payload).includes(config.apiKey))return fail('INVALID_INPUT');
   const work=async():Promise<EmailResult>=>{
    const response=await this.#transport('https://api.resend.com/emails',{method:'POST',redirect:'error',cache:'no-store',signal:controller.signal,headers:{Authorization:'Bearer '+config.apiKey,'Content-Type':'application/json',...(parsed.data.idempotencyKey?{'Idempotency-Key':parsed.data.idempotencyKey}:{})},body:JSON.stringify(payload)});
    if(!response.ok){
     // Do not inspect provider error bodies, headers or diagnostic messages.
     if(response.status===401||response.status===403)return fail('AUTHENTICATION');
     if(response.status===429)return fail('RATE_LIMIT',true);
     if(response.status===408||response.status===504)return fail('TIMEOUT',true);
     if(response.status===409)return fail('CONFLICT');
     return response.status>=500?fail('UNAVAILABLE',true):fail('REJECTED');
    }
    let data:unknown;try{data=await response.json();}catch{return fail('MALFORMED_RESPONSE');}
    const result=responseSchema.safeParse(data);if(!result.success||result.data.id.includes(config.apiKey))return fail('MALFORMED_RESPONSE');
    return {success:true,messageId:result.data.id};
   };
   return await Promise.race([work(),new Promise<EmailResult>(resolve=>{timer=setTimeout(()=>{controller.abort();resolve(fail('TIMEOUT',true));},config.timeoutMs);})]);
  }catch(error){return controller.signal.aborted?fail('TIMEOUT',true):error instanceof TypeError?fail('NETWORK',true):fail('UNKNOWN');}
  finally{if(timer)clearTimeout(timer);}
 }
}
