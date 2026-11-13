import {z} from 'zod';
import {activityMethodSchema} from '@/features/activities/schema';
export const aiPromptRoleSchema=z.enum(['STRUCTURED_CREATIVITY_ASSISTANT','BRAINSTORMING_FACILITATOR','SYSTEM_STRUCTURE_ANALYST','PATENT_RESEARCH_ASSISTANT','COMPARATIVE_CRITICAL_ANALYST','CRITICAL_REVIEWER']);
export const aiPromptTemplateStatusSchema=z.enum(['inactive','active']);
const activities={STRUCTURED_CREATIVITY_ASSISTANT:['scamper'],BRAINSTORMING_FACILITATOR:['brainstorming','problem_storming'],SYSTEM_STRUCTURE_ANALYST:['affinity','mind_map'],PATENT_RESEARCH_ASSISTANT:['patent_research'],COMPARATIVE_CRITICAL_ANALYST:['comparison'],CRITICAL_REVIEWER:['review']} as const;
export function isAiPromptPairAllowed(role:z.infer<typeof aiPromptRoleSchema>,activity:z.infer<typeof activityMethodSchema>):boolean{return (activities[role] as readonly string[]).includes(activity);}
const text=z.string().refine(v=>v.trim().length>0&&v.length<=32000);
// Strict, bounded JSON Schema subset matching PostgreSQL. No remote $ref or
// executable/provider configuration. This parser never authorizes management.
function validSchema(value:unknown,root=true,depth=0):boolean{
 if(depth>12||!value||typeof value!=='object'||Array.isArray(value))return false;
 const s=value as Record<string,unknown>,kind=s.type;
 if(typeof kind!=='string'||!['object','array','string','number','integer','boolean','null'].includes(kind)||(root&&kind!=='object'))return false;
 if(Object.keys(s).some(k=>!['type','description','properties','required','additionalProperties','items','enum','const','$schema'].includes(k)))return false;
 if('$schema'in s&&(!root||s.$schema!=='https://json-schema.org/draft/2020-12/schema'))return false;
 if('description'in s&&typeof s.description!=='string')return false;
 if(['object','array'].includes(kind)&&('enum'in s||'const'in s))return false;
 if(kind==='object'){
  if(!s.properties||typeof s.properties!=='object'||Array.isArray(s.properties)||s.additionalProperties!==false||'items'in s)return false;
  if(Object.entries(s.properties).some(([k,v])=>!k.trim()||!validSchema(v,false,depth+1)))return false;
  if('required'in s&&(!Array.isArray(s.required)||s.required.some(k=>typeof k!=='string'||!Object.hasOwn(s.properties as object,k))||new Set(s.required).size!==s.required.length))return false;
 }else if(kind==='array'){
  if(!validSchema(s.items,false,depth+1)||['properties','required','additionalProperties'].some(k=>k in s))return false;
 }else if(['properties','required','additionalProperties','items'].some(k=>k in s))return false;
 const matches=(v:unknown)=>kind==='null'?v===null:kind==='array'?Array.isArray(v):kind==='object'?v!==null&&typeof v==='object'&&!Array.isArray(v):kind==='integer'?typeof v==='number'&&Number.isInteger(v):typeof v===kind;
 if('enum'in s&&(!Array.isArray(s.enum)||!s.enum.length||!s.enum.every(matches)))return false;
 if('const'in s&&(!matches(s.const)||('enum'in s&&!(s.enum as unknown[]).some(v=>JSON.stringify(v)===JSON.stringify(s.const)))))return false;
 return true;
}
export const aiPromptOutputSchema=z.record(z.string(),z.json()).refine(v=>JSON.stringify(v).length<=32000&&validSchema(v),'Invalid bounded structured output schema');
export const createAiPromptTemplateSchema=z.strictObject({roleCode:aiPromptRoleSchema,activityType:activityMethodSchema,systemInstruction:text,taskTemplate:text,outputSchema:aiPromptOutputSchema})
 .refine(v=>isAiPromptPairAllowed(v.roleCode,v.activityType),'Unsupported role/activity pair');
export const activateAiPromptTemplateSchema=z.strictObject({templateId:z.uuid(),active:z.boolean()});
export const aiPromptTemplateSchema=z.strictObject({id:z.uuid(),role_code:aiPromptRoleSchema,activity_type:activityMethodSchema,version:z.number().int().positive().max(2147483647),system_instruction:text,task_template:text,output_schema:aiPromptOutputSchema,status:aiPromptTemplateStatusSchema,created_by:z.uuid(),created_at:z.iso.datetime({offset:true})})
 .refine(v=>isAiPromptPairAllowed(v.role_code,v.activity_type),'Unsupported role/activity pair');
export type AiPromptTemplate=z.infer<typeof aiPromptTemplateSchema>;
export type CreateAiPromptTemplateInput=z.infer<typeof createAiPromptTemplateSchema>;
