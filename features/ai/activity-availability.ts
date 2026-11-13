import 'server-only';
import {z} from 'zod';
import {isDeepStrictEqual} from 'node:util';
import {getAuthorizationContext} from '@/lib/auth/authorization';
import {createServerSupabaseClient} from '@/lib/db/server';
import {aiPromptRoleSchema} from './prompt-template-schema';
import {listAiTaskDefinitions,type AiTaskType} from './task-registry';
const inputSchema=z.strictObject({activityInstanceId:z.uuid(),projectId:z.uuid(),workspaceId:z.uuid(),requestedTaskType:z.string().optional()});
const aiConfiguration=z.object({enabled:z.literal(true),allowed_tasks:z.array(z.string()).optional(),independent_work_required:z.boolean().optional(),requires_revealed_pool:z.boolean().optional()});
const stateSchema=z.object({project_id:z.uuid(),workspace_id:z.uuid(),status:z.string(),definition_status:z.string(),method_type:z.string(),ai_role_code:z.string().nullable(),configuration:z.record(z.string(),z.json()).nullable(),current_ai:z.json().nullable(),current_role:z.string().nullable(),current_method:z.string(),independent_work_satisfied:z.boolean(),revealed_pool_satisfied:z.boolean()});
export type AiAvailabilityReason='ACTIVITY_ACCESS_DENIED'|'INVALID_CONTEXT'|'PROJECT_ACCESS_DENIED'|'WORKSPACE_ACCESS_DENIED'|'AI_NOT_ENABLED'|'AI_ROLE_INVALID'|'TASK_NOT_ALLOWED'|'INDEPENDENT_WORK_REQUIRED'|'PRIVATE_BEFORE_REVEAL'|'ACTIVITY_STATE_BLOCKED'|'USAGE_LIMIT_REACHED';
export type AiAvailability=Readonly<{available:boolean;aiRole:z.infer<typeof aiPromptRoleSchema>|null;allowedTasks:readonly AiTaskType[];reasonCode:AiAvailabilityReason|null}>;
export type AiUsagePolicy=(scope:Readonly<{actorId:string;activityInstanceId:string;projectId:string;workspaceId:string}>)=>Promise<boolean>;
const deny=(reasonCode:AiAvailabilityReason):AiAvailability=>({available:false,aiRole:null,allowedTasks:[],reasonCode});
/** Server composition only. Hook is never accepted from request data. Availability
 * is read-only eligibility, never a reusable authorization capability. */
export function createActivityAiAvailabilityResolver(usagePolicy:AiUsagePolicy=async()=>true){
 return async function getActivityAiAvailability(input:unknown):Promise<AiAvailability>{
  const parsed=inputSchema.safeParse(input);if(!parsed.success)return deny('INVALID_CONTEXT');
  try{
   const actor=await getAuthorizationContext(),db=await createServerSupabaseClient(),v=parsed.data;
   const read=async()=>{const r=await db.rpc('resolve_activity_ai_configuration',{target_instance:v.activityInstanceId});return r.error?null:stateSchema.safeParse(r.data);};
   const loaded=await read();if(!loaded||!loaded.success)return deny('ACTIVITY_ACCESS_DENIED');
   const s=loaded.data;
   if(s.project_id!==v.projectId)return deny('PROJECT_ACCESS_DENIED');
   if(s.workspace_id!==v.workspaceId)return deny('WORKSPACE_ACCESS_DENIED');
   if(s.definition_status!=='active')return deny('ACTIVITY_STATE_BLOCKED');
   const frozen=aiConfiguration.safeParse(s.configuration?.ai),current=aiConfiguration.safeParse(s.current_ai);
   if(!frozen.success||!current.success)return deny('AI_NOT_ENABLED');
   const role=aiPromptRoleSchema.safeParse(s.ai_role_code);
   if(!role.success||s.current_role!==role.data||s.current_method!==s.method_type)return deny('AI_ROLE_INVALID');
   const candidates=listAiTaskDefinitions().filter(t=>t.allowedRole===role.data&&t.templateActivityType===s.method_type);
   const subsets=[frozen.data.allowed_tasks,current.data.allowed_tasks].filter((x):x is string[]=>x!==undefined);
   if(subsets.some(xs=>xs.some(x=>!candidates.some(t=>t.taskType===x))))return deny('TASK_NOT_ALLOWED');
   const tasks=candidates.filter(t=>subsets.every(xs=>xs.includes(t.taskType))).map(t=>t.taskType);
   if(!tasks.length||(v.requestedTaskType!==undefined&&!tasks.some(t=>t===v.requestedTaskType)))return deny('TASK_NOT_ALLOWED');
   if((frozen.data.independent_work_required||current.data.independent_work_required)&&!s.independent_work_satisfied)return deny('INDEPENDENT_WORK_REQUIRED');
   if((frozen.data.requires_revealed_pool||current.data.requires_revealed_pool)&&!s.revealed_pool_satisfied)return deny('PRIVATE_BEFORE_REVEAL');
   if(!['active','revision_requested'].includes(s.status))return deny('ACTIVITY_STATE_BLOCKED');
   if(!await usagePolicy(Object.freeze({actorId:actor.userId,...v})))return deny('USAGE_LIMIT_REACHED');
   const refreshed=await getAuthorizationContext(),after=await read();
   if(refreshed.userId!==actor.userId||!after||!after.success||!isDeepStrictEqual(after.data,s))return deny('ACTIVITY_ACCESS_DENIED');
   return {available:true,aiRole:role.data,allowedTasks:tasks,reasonCode:null};
  }catch{return deny('ACTIVITY_ACCESS_DENIED');}
 };
}
export const getActivityAiAvailability=createActivityAiAvailabilityResolver();

