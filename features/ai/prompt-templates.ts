import 'server-only';
import {isDeepStrictEqual} from 'node:util';
import {AuthorizationError,getAuthorizationContext} from '@/lib/auth/authorization';
import {createServerSupabaseClient} from '@/lib/db/server';
import {activateAiPromptTemplateSchema,aiPromptTemplateSchema,createAiPromptTemplateSchema,type AiPromptTemplate} from './prompt-template-schema';
function fail(error:unknown):never{throw new AuthorizationError(error instanceof AuthorizationError&&['AUTH_REQUIRED','VALIDATION_ERROR'].includes(error.code)?error.code:'FORBIDDEN');}
function checkError(error:{code?:string}|null){if(error)throw new AuthorizationError(['22023','22P02','23514'].includes(error.code??'')?'VALIDATION_ERROR':'FORBIDDEN');}
export async function createAiPromptTemplate(input:unknown):Promise<AiPromptTemplate>{try{
 const actor=await getAuthorizationContext();const parsed=createAiPromptTemplateSchema.safeParse(input);
 if(!parsed.success)throw new AuthorizationError('VALIDATION_ERROR');
 const db=await createServerSupabaseClient();const result=await db.rpc('create_ai_prompt_template',{input:parsed.data});
 checkError(result.error);const row=aiPromptTemplateSchema.safeParse(result.data);
 if((await getAuthorizationContext()).userId!==actor.userId||!row.success||row.data.created_by!==actor.userId||row.data.role_code!==parsed.data.roleCode||row.data.activity_type!==parsed.data.activityType||row.data.status!=='inactive'||row.data.system_instruction!==parsed.data.systemInstruction||row.data.task_template!==parsed.data.taskTemplate||!isDeepStrictEqual(row.data.output_schema,parsed.data.outputSchema))throw new AuthorizationError('FORBIDDEN');
 return row.data;
}catch(error){return fail(error);}}
export async function setAiPromptTemplateActive(input:unknown):Promise<AiPromptTemplate>{try{
 const actor=await getAuthorizationContext();const parsed=activateAiPromptTemplateSchema.safeParse(input);
 if(!parsed.success)throw new AuthorizationError('VALIDATION_ERROR');
 const db=await createServerSupabaseClient();const result=await db.rpc('set_ai_prompt_template_active',{target_template:parsed.data.templateId,activate:parsed.data.active});
 checkError(result.error);const row=aiPromptTemplateSchema.safeParse(result.data);
 if((await getAuthorizationContext()).userId!==actor.userId||!row.success||row.data.id!==parsed.data.templateId||row.data.status!==(parsed.data.active?'active':'inactive'))throw new AuthorizationError('FORBIDDEN');
 return row.data;
}catch(error){return fail(error);}}
export async function seedAiPromptTemplates():Promise<number>{try{
 const actor=await getAuthorizationContext();const db=await createServerSupabaseClient();const result=await db.rpc('seed_ai_prompt_templates');checkError(result.error);
 const count=result.data;
 if((await getAuthorizationContext()).userId!==actor.userId||typeof count!=='number'||!Number.isInteger(count)||count<0||count>8)throw new AuthorizationError('FORBIDDEN');
 return count;
}catch(error){return fail(error);}}
